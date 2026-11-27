import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let wm = WindowManager()
    private var statusItem: NSStatusItem!
    private var statusLine: NSMenuItem!
    private var toggleItem: NSMenuItem!
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        if AX.isTrusted(prompt: true) {
            wm.start()
        } else {
            // Tunggu sampai user mengizinkan di System Settings
            permissionTimer = Timer.scheduledTimer(timeInterval: 1, target: self,
                                                   selector: #selector(checkPermission),
                                                   userInfo: nil, repeats: true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        wm.restoreAll() // jangan tinggalkan jendela "terparkir" di luar layar
    }

    @objc private func checkPermission() {
        guard AX.isTrusted(prompt: false) else { return }
        permissionTimer?.invalidate()
        permissionTimer = nil
        wm.start()
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.split.3x1",
                                   accessibilityDescription: "Gulir")
        }

        let menu = NSMenu()
        menu.delegate = self

        statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)

        toggleItem = item("Matikan tiling", #selector(toggleTiling))
        menu.addItem(toggleItem)
        menu.addItem(item("Rapikan ulang", #selector(retile)))
        menu.addItem(.separator())

        let shortcuts = [
            "⌃⌥ H / L  atau  ← / →   pindah fokus",
            "⌃⌥⇧ H / L  atau  ← / →   pindah kolom",
            "⌥ + swipe 2 jari kiri / kanan   pindah fokus",
            "⌃⌥ R   ganti lebar (⅓ · ½ · ⅔ · penuh)",
            "⌃⌥ F   lebar penuh / kembali",
            "⌃⌥ C   tengahkan kolom",
            "⌃⌥ T   nyalakan / matikan",
        ]
        for line in shortcuts {
            let i = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            i.isEnabled = false
            menu.addItem(i)
        }

        menu.addItem(.separator())
        menu.addItem(item("Buka pengaturan Accessibility…", #selector(openAccessibility)))
        menu.addItem(item("Keluar Gulir", #selector(quit)))
        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self
        return i
    }

    func menuWillOpen(_ menu: NSMenu) {
        if !AX.isTrusted(prompt: false) {
            statusLine.title = "⚠︎ Butuh izin Accessibility"
        } else if wm.isEnabled {
            statusLine.title = "Aktif · \(wm.columnCount) jendela"
        } else {
            statusLine.title = "Nonaktif"
        }
        toggleItem.title = wm.isEnabled ? "Matikan tiling" : "Nyalakan tiling"
    }

    @objc private func toggleTiling() { wm.toggleEnabled() }
    @objc private func retile() { wm.retile() }

    @objc private func openAccessibility() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
