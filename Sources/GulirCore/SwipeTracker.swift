import CoreGraphics

/// Mengubah rangkaian event scroll trackpad menjadi langkah fokus kiri/kanan.
/// Murni (tanpa CGEventTap), supaya bisa di-unit-test.
public struct SwipeTracker {
    public enum Phase: Equatable {
        case began, changed, ended
    }

    /// Arah perpindahan fokus.
    public enum Step: Equatable {
        case left, right
    }

    public let threshold: CGFloat
    private var accumulated: CGFloat = 0

    /// - Parameter threshold: jarak geser horizontal (pt) untuk satu langkah kolom.
    public init(threshold: CGFloat) {
        self.threshold = threshold
    }

    /// - Parameters:
    ///   - deltaX: delta horizontal dalam pt. Negatif = konten bergeser ke kiri
    ///     (dengan natural scrolling: jari ke kiri) → tampilkan kolom di kanan.
    ///   - deltaY: delta vertikal; event yang dominan vertikal diabaikan.
    public mutating func feed(deltaX: CGFloat, deltaY: CGFloat, phase: Phase) -> [Step] {
        switch phase {
        case .began:
            accumulated = 0
        case .ended:
            accumulated = 0
            return []
        case .changed:
            break
        }
        guard abs(deltaX) > abs(deltaY) else { return [] }

        accumulated += deltaX
        var steps: [Step] = []
        while abs(accumulated) >= threshold {
            if accumulated < 0 {
                steps.append(.right)
                accumulated += threshold
            } else {
                steps.append(.left)
                accumulated -= threshold
            }
        }
        return steps
    }
}
