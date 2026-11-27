import CoreGraphics

/// Perhitungan posisi kolom di strip. Murni: tidak memanggil AX/AppKit,
/// supaya bisa di-unit-test (lihat DESIGN.md §4).
public enum LayoutEngine {
    public enum Side: Equatable {
        case left, right
    }

    public enum Placement: Equatable {
        /// Kolom terlihat (penuh atau sebagian) di layar.
        case visible(CGRect)
        /// Kolom sepenuhnya di luar layar; diparkir di tepi dengan sisa 1 px.
        case parked(Side, CGRect)

        public var frame: CGRect {
            switch self {
            case .visible(let r), .parked(_, let r): return r
            }
        }
    }

    public struct Result: Equatable {
        public let placements: [Placement]
        public let scroll: CGFloat
    }

    public static func columnWidth(_ fraction: CGFloat, areaWidth: CGFloat, gap: CGFloat) -> CGFloat {
        (areaWidth - gap) * fraction - gap
    }

    /// - Parameters:
    ///   - fractions: lebar relatif tiap kolom, urut kiri→kanan.
    ///   - focus: indeks kolom aktif.
    ///   - scroll: posisi kiri viewport dalam koordinat strip (dari layout sebelumnya).
    ///   - area: area layar yang bisa dipakai, koordinat AX.
    ///   - center: tengahkan kolom aktif alih-alih geser seminimal mungkin.
    public static func layout(fractions: [CGFloat], focus: Int, scroll: CGFloat,
                              area: CGRect, gap: CGFloat, center: Bool = false) -> Result {
        guard !fractions.isEmpty else { return Result(placements: [], scroll: scroll) }
        let focus = max(0, min(focus, fractions.count - 1))

        let widths = fractions.map { columnWidth($0, areaWidth: area.width, gap: gap) }
        var xs: [CGFloat] = []
        var x: CGFloat = 0
        for w in widths {
            xs.append(x)
            x += w + gap
        }

        // Geser strip secukupnya supaya kolom fokus terlihat penuh
        var scroll = scroll
        let fx = xs[focus], fw = widths[focus]
        if center {
            scroll = fx + fw / 2 - area.width / 2
        } else {
            if fx - scroll < gap { scroll = fx - gap }
            if fx + fw - scroll > area.width - gap { scroll = fx + fw - area.width + gap }
        }
        scroll = clampScroll(scroll, stripWidth: xs[xs.count - 1] + widths[widths.count - 1],
                             areaWidth: area.width, gap: gap)

        let y = area.minY + gap
        let h = area.height - 2 * gap
        let placements: [Placement] = widths.indices.map { i in
            let w = widths[i]
            let sx = area.minX + xs[i] - scroll
            if sx + w <= area.minX {
                return .parked(.left, CGRect(x: parkedX(.left, width: w, area: area), y: y, width: w, height: h))
            }
            if sx >= area.maxX {
                return .parked(.right, CGRect(x: parkedX(.right, width: w, area: area), y: y, width: w, height: h))
            }
            return .visible(CGRect(x: sx, y: y, width: w, height: h))
        }
        return Result(placements: placements, scroll: scroll)
    }

    /// Jangan sisakan ruang kosong di ujung strip: kolom pertama paling jauh mulai di `gap`
    /// dari tepi kiri, dan kolom terakhir tidak pernah berhenti di tengah layar
    /// kalau masih ada kolom lain yang bisa ditampilkan.
    static func clampScroll(_ scroll: CGFloat, stripWidth: CGFloat, areaWidth: CGFloat, gap: CGFloat) -> CGFloat {
        let minScroll = -gap
        let maxScroll = max(minScroll, stripWidth - areaWidth + gap)
        return min(max(scroll, minScroll), maxScroll)
    }

    /// Posisi x jendela yang diparkir, dengan sisa 1 px di layar (macOS tidak mengizinkan
    /// jendela hilang total). Pakai lebar jendela yang *sebenarnya*: app yang menolak
    /// dikecilkan (mis. WhatsApp, lebar minimum 800) akan menyembul kalau dihitung dari lebar kolom.
    public static func parkedX(_ side: Side, width: CGFloat, area: CGRect) -> CGFloat {
        switch side {
        case .left: return area.minX - width + 1
        case .right: return area.maxX - 1
        }
    }
}
