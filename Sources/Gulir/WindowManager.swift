import AppKit
import ApplicationServices
import Carbon

struct WindowRef: Hashable {
    let el: AXUIElement
    let pid: pid_t

    static func == (a: WindowRef, b: WindowRef) -> Bool { CFEqual(a.el, b.el) }
    func hash(into hasher: inout Hasher) { hasher.combine(CFHash(el)) }
}

struct Column {
    let win: WindowRef
    var fraction: CGFloat            // lebar kolom relatif terhadap layar
    var previousFraction: CGFloat?   // untuk toggle lebar penuh
}

/// Inti "scrolling tiling": semua jendela jadi kolom di satu strip horizontal
/// yang lebih lebar dari layar. Layar = jendela pandang yang bergeser.
final class WindowManager: NSObject {
    private(set) var isEnabled = true
    var columnCount: Int { columns.count }

    private var columns: [Column] = []
    private var focus = 0
    private var scroll: CGFloat = 0
    private var timer: Timer?
    private var ignoreFocusUntil = Date.distantPast

    // Pengaturan — silakan ubah sesuai selera
    private let gap: CGFloat = 10
    private let presets: [CGFloat] = [1.0 / 3.0, 0.5, 2.0 / 3.0, 1.0]
    private let defaultFraction: CGFloat = 0.5
    private let pollInterval: TimeInterval = 0.5

    // MARK: - Mulai

    func start() {
        guard timer == nil else { return }
        registerHotKeys()
        timer = Timer.scheduledTimer(timeInterval: pollInterval, target: self,
                                     selector: #selector(tick), userInfo: nil, repeats: true)
        sync(forceLayout: true)
    }

    @objc private func tick() { sync(forceLayout: false) }

    private func registerHotKeys() {
        let base = UInt32(controlKey | optionKey)
        let shifted = base | UInt32(shiftKey)
        let hk = HotKeys.shared

        hk.register(kVK_ANSI_H, base) { [weak self] in self?.focusLeft() }
        hk.register(kVK_ANSI_L, base) { [weak self] in self?.focusRight() }
        hk.register(kVK_LeftArrow, base) { [weak self] in self?.focusLeft() }
        hk.register(kVK_RightArrow, base) { [weak self] in self?.focusRight() }

        hk.register(kVK_ANSI_H, shifted) { [weak self] in self?.moveLeft() }
        hk.register(kVK_ANSI_L, shifted) { [weak self] in self?.moveRight() }
        hk.register(kVK_LeftArrow, shifted) { [weak self] in self?.moveLeft() }
        hk.register(kVK_RightArrow, shifted) { [weak self] in self?.moveRight() }

        hk.register(kVK_ANSI_R, base) { [weak self] in self?.cycleWidth() }
        hk.register(kVK_ANSI_F, base) { [weak self] in self?.toggleFullWidth() }
        hk.register(kVK_ANSI_C, base) { [weak self] in self?.centerFocused() }
        hk.register(kVK_ANSI_T, base) { [weak self] in self?.toggleEnabled() }
    }

    // MARK: - Sinkronisasi dengan jendela yang ada

    private func sync(forceLayout: Bool) {
        guard isEnabled else { return }
        var changed = forceLayout
        let found = discoverWindows()
        let foundSet = Set(found)

        // 1. Buang jendela yang sudah ditutup / di-minimize / disembunyikan
        let focusedBefore = columns.indices.contains(focus) ? columns[focus].win : nil
        let countBefore = columns.count
        columns.removeAll { !foundSet.contains($0.win) }
        if columns.count != countBefore {
            changed = true
            if let f = focusedBefore, let idx = columns.firstIndex(where: { $0.win == f }) {
                focus = idx
            } else {
                focus = min(focus, max(columns.count - 1, 0))
            }
        }

        // 2. Tambahkan jendela baru (hanya yang ada di layar utama)
        let managed = Set(columns.map { $0.win })
        var fresh = found.filter { !managed.contains($0) && isOnPrimaryScreen($0) }
        if !fresh.isEmpty {
            changed = true
            if columns.isEmpty {
                // Pertama kali: pertahankan urutan kiri→kanan yang sekarang
                fresh.sort { (AX.frame($0.el)?.minX ?? 0) < (AX.frame($1.el)?.minX ?? 0) }
                columns = fresh.map { Column(win: $0, fraction: defaultFraction) }
                focus = 0
            } else {
                // Jendela baru muncul tepat di kanan kolom yang sedang fokus
                for w in fresh {
                    let at = min(focus + 1, columns.count)
                    columns.insert(Column(win: w, fraction: defaultFraction), at: at)
                    focus = at
                }
            }
        }

        // 3. Ikuti fokus kalau user klik jendela pakai mouse / Cmd-Tab
        if Date() > ignoreFocusUntil, let idx = indexOfFocusedWindow(), idx != focus {
            focus = idx
            changed = true
        }

        if changed { layout() }
    }

    private func discoverWindows() -> [WindowRef] {
        var result: [WindowRef] = []
        let myPid = ProcessInfo.processInfo.processIdentifier
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular && !app.isHidden && app.processIdentifier != myPid {
            let appEl = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(appEl, 0.3) // jangan macet kalau app hang
            for w in AX.windows(of: appEl) {
                guard AX.string(w, kAXSubroleAttribute) == kAXStandardWindowSubrole else { continue }
                if AX.bool(w, kAXMinimizedAttribute) == true { continue }
                if AX.bool(w, "AXFullScreen") == true { continue }
                if !AX.isSettable(w, kAXSizeAttribute) { continue } // jendela ukuran tetap → biarkan melayang
                result.append(WindowRef(el: w, pid: app.processIdentifier))
            }
        }
        return result
    }

    private func isOnPrimaryScreen(_ w: WindowRef) -> Bool {
        guard let f = AX.frame(w.el), let screen = NSScreen.screens.first else { return false }
        let primary = CGRect(origin: .zero, size: screen.frame.size)
        return primary.contains(CGPoint(x: f.midX, y: f.midY))
    }

    private func indexOfFocusedWindow() -> Int? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appEl, 0.3)
        guard let fw = AX.element(appEl, kAXFocusedWindowAttribute) else { return nil }
        let ref = WindowRef(el: fw, pid: app.processIdentifier)
        return columns.firstIndex { $0.win == ref }
    }

    // MARK: - Layout

    /// Area layar utama yang bisa dipakai (tanpa menu bar & Dock), dalam koordinat AX.
    private func usableArea() -> CGRect? {
        guard let screen = NSScreen.screens.first else { return nil }
        let full = screen.frame
        let vis = screen.visibleFrame
        return CGRect(x: vis.minX, y: full.maxY - vis.maxY, width: vis.width, height: vis.height)
    }

    private func columnWidth(_ fraction: CGFloat, in area: CGRect) -> CGFloat {
        (area.width - gap) * fraction - gap
    }

    private func layout(center: Bool = false) {
        guard isEnabled, !columns.isEmpty, let area = usableArea() else { return }
        focus = max(0, min(focus, columns.count - 1))

        // Posisi setiap kolom di strip (koordinat strip, mulai dari 0)
        let widths = columns.map { columnWidth($0.fraction, in: area) }
        var xs: [CGFloat] = []
        var x: CGFloat = 0
        for w in widths {
            xs.append(x)
            x += w + gap
        }

        // Geser strip secukupnya supaya kolom fokus terlihat penuh
        let fx = xs[focus], fw = widths[focus]
        if center {
            scroll = fx + fw / 2 - area.width / 2
        } else {
            if fx - scroll < gap { scroll = fx - gap }
            if fx + fw - scroll > area.width - gap { scroll = fx + fw - area.width + gap }
        }

        let y = area.minY + gap
        let h = area.height - 2 * gap
        for (i, col) in columns.enumerated() {
            let w = widths[i]
            var sx = area.minX + xs[i] - scroll
            // Jendela yang sepenuhnya di luar layar diparkir di tepi (sisa 1px),
            // karena macOS tidak mengizinkan jendela hilang total dari layar.
            if sx + w <= area.minX {
                sx = area.minX - w + 1
            } else if sx >= area.maxX {
                sx = area.maxX - 1
            }
            AX.setFrame(col.win.el, CGRect(x: sx, y: y, width: w, height: h))
        }
    }

    // MARK: - Aksi (dipanggil dari shortcut)

    func focusLeft() { focusColumn(focus - 1) }
    func focusRight() { focusColumn(focus + 1) }

    private func focusColumn(_ i: Int) {
        guard isEnabled, columns.indices.contains(i) else { return }
        focus = i
        layout()
        activate(columns[i].win)
    }

    func moveLeft() { moveColumn(by: -1) }
    func moveRight() { moveColumn(by: 1) }

    private func moveColumn(by delta: Int) {
        let target = focus + delta
        guard isEnabled, columns.indices.contains(focus), columns.indices.contains(target) else { return }
        columns.swapAt(focus, target)
        focus = target
        layout()
    }

    func cycleWidth() {
        guard isEnabled, columns.indices.contains(focus) else { return }
        let current = columns[focus].fraction
        let next = presets.first { $0 > current + 0.01 } ?? presets[0]
        columns[focus].fraction = next
        columns[focus].previousFraction = nil
        layout()
    }

    func toggleFullWidth() {
        guard isEnabled, columns.indices.contains(focus) else { return }
        if columns[focus].fraction >= 0.99 {
            columns[focus].fraction = columns[focus].previousFraction ?? defaultFraction
            columns[focus].previousFraction = nil
        } else {
            columns[focus].previousFraction = columns[focus].fraction
            columns[focus].fraction = 1.0
        }
        layout()
    }

    func centerFocused() {
        guard isEnabled else { return }
        layout(center: true)
    }

    func retile() {
        guard isEnabled else { return }
        sync(forceLayout: true)
    }

    func toggleEnabled() {
        if isEnabled {
            restoreAll()
            columns.removeAll()
            isEnabled = false
        } else {
            isEnabled = true
            scroll = 0
            sync(forceLayout: true)
        }
    }

    /// Kembalikan semua jendela ke dalam layar (dipakai saat dimatikan / keluar).
    func restoreAll() {
        guard let area = usableArea() else { return }
        let w = min(area.width * 0.6, area.width - 80)
        let h = min(area.height * 0.8, area.height - 80)
        for (i, col) in columns.enumerated() {
            let offset = CGFloat(i % 8) * 30
            AX.setFrame(col.win.el, CGRect(x: area.minX + 40 + offset, y: area.minY + 40 + offset,
                                           width: w, height: h))
        }
    }

    private func activate(_ w: WindowRef) {
        ignoreFocusUntil = Date().addingTimeInterval(0.8)
        let appEl = AXUIElementCreateApplication(w.pid)
        AXUIElementSetAttributeValue(appEl, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(w.el, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(w.el, kAXRaiseAction as CFString)
        NSRunningApplication(processIdentifier: w.pid)?.activate(options: [.activateIgnoringOtherApps])
    }
}
