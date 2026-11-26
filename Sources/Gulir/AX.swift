import AppKit
import ApplicationServices

/// Pembungkus kecil untuk macOS Accessibility API.
enum AX {
    static func isTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    static func copy(_ el: AXUIElement, _ attr: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(el, attr as CFString, &value)
        return err == .success ? value : nil
    }

    static func element(_ el: AXUIElement, _ attr: String) -> AXUIElement? {
        guard let v = copy(el, attr), CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return (v as! AXUIElement)
    }

    static func string(_ el: AXUIElement, _ attr: String) -> String? {
        copy(el, attr) as? String
    }

    static func bool(_ el: AXUIElement, _ attr: String) -> Bool? {
        copy(el, attr) as? Bool
    }

    static func windows(of app: AXUIElement) -> [AXUIElement] {
        (copy(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
    }

    static func isSettable(_ el: AXUIElement, _ attr: String) -> Bool {
        var settable: DarwinBoolean = false
        let err = AXUIElementIsAttributeSettable(el, attr as CFString, &settable)
        return err == .success && settable.boolValue
    }

    /// Frame dalam koordinat AX (titik asal di kiri-atas layar utama).
    static func frame(_ el: AXUIElement) -> CGRect? {
        guard let p = copy(el, kAXPositionAttribute), let s = copy(el, kAXSizeAttribute) else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(p as! AXValue, .cgPoint, &point)
        AXValueGetValue(s as! AXValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }

    static func setFrame(_ el: AXUIElement, _ rect: CGRect) {
        if let current = frame(el),
           abs(current.minX - rect.minX) < 1, abs(current.minY - rect.minY) < 1,
           abs(current.width - rect.width) < 1, abs(current.height - rect.height) < 1 {
            return // sudah di posisi yang benar
        }

        // Beberapa app (mis. Chrome) menganimasikan resize kalau
        // AXEnhancedUserInterface aktif — matikan sebentar supaya cepat.
        var pid: pid_t = 0
        AXUIElementGetPid(el, &pid)
        let app = AXUIElementCreateApplication(pid)
        let enhanced = bool(app, "AXEnhancedUserInterface") == true
        if enhanced {
            AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse)
        }
        defer {
            if enhanced {
                AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
            }
        }

        var point = rect.origin
        var size = rect.size
        guard let pv = AXValueCreate(.cgPoint, &point), let sv = AXValueCreate(.cgSize, &size) else { return }
        // Ukuran → posisi → ukuran lagi: trik umum supaya macOS tidak
        // memotong ukuran saat jendela dipindah melewati tepi layar.
        AXUIElementSetAttributeValue(el, kAXSizeAttribute as CFString, sv)
        AXUIElementSetAttributeValue(el, kAXPositionAttribute as CFString, pv)
        AXUIElementSetAttributeValue(el, kAXSizeAttribute as CFString, sv)
    }
}
