# DESIGN — arsitektur teknis Gulir

## 1. Gambaran besar
```
┌─────────────┐   shortcut    ┌──────────────────┐   setFrame / raise   ┌──────────────┐
│ HotKeys     │ ────────────▶ │ WindowManager    │ ───────────────────▶ │ AX (wrapper) │──▶ app lain
│ (Carbon)    │               │  state + aksi    │ ◀─────────────────── │              │
└─────────────┘               │  sync loop       │   daftar jendela,    └──────────────┘
┌─────────────┐   menu        │  layout()        │   frame, fokus
│ AppDelegate │ ────────────▶ └──────────────────┘
│ (menu bar)  │                        ▲ Timer 0,5 dtk (v0.1) → AXObserver (v0.2)
└─────────────┘
```
Satu proses, satu thread (main). Tidak ada daemon terpisah, IPC, atau jaringan.

## 2. Model data
```swift
struct WindowRef { el: AXUIElement; pid: pid_t }   // identitas via CFEqual/CFHash
struct Column    { win: WindowRef; fraction: CGFloat; previousFraction: CGFloat? }

WindowManager:
  columns: [Column]   // urutan kiri→kanan di strip
  focus:   Int        // indeks kolom aktif
  scroll:  CGFloat    // posisi kiri viewport dalam koordinat strip
```
`fraction` = lebar relatif terhadap lebar area layar yang bisa dipakai, bukan piksel,
supaya layout tetap benar saat resolusi berubah atau Dock disembunyikan.

## 3. Sistem koordinat
- **AX / CGWindow:** titik asal di kiri-atas layar utama, sumbu y ke bawah.
- **NSScreen:** titik asal di kiri-bawah layar utama, sumbu y ke atas.
- Konversi: `axY = primaryScreen.frame.maxY - nsRect.maxY`.
- **Koordinat strip:** x = 0 di tepi kiri kolom pertama; tidak bergantung layar.

## 4. Algoritma layout
Input: `widths[]`, `gap`, `area` (visibleFrame layar dalam koordinat AX), `focus`, `scroll`.
```
colWidth(f) = (area.width − gap) · f − gap      // f=1 → mengisi layar dengan gap di dua sisi
x[0] = 0;  x[i+1] = x[i] + w[i] + gap

// viewport minimal-geser: hanya bergeser secukupnya supaya kolom fokus terlihat penuh
if x[f] − scroll < gap                 → scroll = x[f] − gap
if x[f] + w[f] − scroll > area.w − gap → scroll = x[f] + w[f] − area.w + gap
// mode center: scroll = x[f] + w[f]/2 − area.w/2

// jangan sisakan ruang kosong di ujung strip (mis. setelah kolom paling kanan ditutup)
scroll = clamp(scroll, −gap, max(−gap, x[n−1] + w[n−1] − area.w + gap))

screenX[i] = area.minX + x[i] − scroll
jika seluruhnya di kiri layar  → parkir di area.minX − lebarAktual + 1
jika seluruhnya di kanan layar → parkir di area.maxX − 1
```
`lebarAktual` dibaca ulang dari jendela setelah di-resize: app dengan lebar minimum
(mis. WhatsApp) menolak dikecilkan, dan kalau dihitung dari lebar kolom sisanya menyembul.
Karena clamp, ⌃⌥C pada kolom pertama/terakhir tidak menengahkan (strip tidak digeser melewati ujungnya).
Implementasi: `Sources/GulirCore/LayoutEngine.swift`, test: `Tests/GulirCoreTests/`.
Properti yang harus dijaga (dan jadi unit test):
- Lebar kolom tidak pernah berubah karena jumlah kolom berubah.
- Kolom fokus selalu terlihat penuh (kecuali lebih lebar dari layar).
- Pindah fokus ke kolom yang sudah terlihat penuh → `scroll` tidak berubah.
- Dua kolom ½ mengisi layar tepat dengan gap yang sama di semua sisi.
- Tidak ada ruang kosong di ujung strip selama total lebar kolom ≥ lebar layar.

## 5. Sinkronisasi (sync loop)
Setiap tick (0,5 dtk) atau saat dipaksa:
1. **Discover**: untuk setiap app `.regular` yang tidak di-hide → `kAXWindowsAttribute`,
   ambil yang subrole `AXStandardWindow`, tidak minimized, tidak full screen, dan ukurannya bisa diubah.
2. **Remove**: kolom yang jendelanya hilang dibuang; fokus dipertahankan pada jendela yang sama bila masih ada.
3. **Insert**: jendela baru di layar utama → disisipkan di `focus + 1`, lalu jadi fokus.
   Pada start pertama, urutan diambil dari posisi x saat ini.
4. **Track focus**: jendela fokus milik app frontmost → jadikan `focus`.
   Diabaikan selama 0,8 dtk setelah Gulir sendiri memindahkan fokus (mencegah race dengan aktivasi async).
5. `layout()` hanya dipanggil bila ada perubahan, supaya tidak melawan user yang sedang menggeser jendela.

**Rencana v0.2:** pasang `AXObserver` per app untuk `kAXWindowCreated`, `kAXUIElementDestroyed`,
`kAXFocusedWindowChanged`, `kAXWindowMiniaturized`, ditambah notifikasi `NSWorkspace`
(launch/terminate/activate/hide). Polling tetap ada, diperlambat jadi 2–3 dtk, sebagai jaring pengaman.

## 6. Menggerakkan jendela
`AX.setFrame`: lewati jika frame sudah sama (±1 px); matikan sementara `AXEnhancedUserInterface`
(kalau tidak, Chrome/Electron menganimasikan resize); set size → position → size.

## 7. Fokus
`AXFrontmost` pada app + `AXMain` + `AXRaise` pada jendela + `NSRunningApplication.activate`.
Di macOS 14+ aktivasi kooperatif bisa menolak ini. Kalau terbukti bermasalah, opsi berikutnya
adalah private API SkyLight yang diisolasi di `PrivateAPI.swift` dengan feature flag (lihat aturan di AGENTS.md).

## 8. Shortcut
Carbon `RegisterEventHotKey`: tidak butuh izin Input Monitoring, didukung sampai macOS terbaru,
dan gagal secara eksplisit kalau kombinasi sudah dipakai app lain. Kekurangannya: tidak bisa
menangkap gestur atau tombol modifier saja; untuk itu (v0.5) perlu `CGEventTap` + izin tambahan.

**Gestur trackpad (⌥ + swipe 2 jari):** `TrackpadSwipe` memasang `CGEventTap` aktif untuk event
`scrollWheel` (cukup izin Accessibility). Keputusan diambil sekali di awal gestur (fase *began*): kalau
hanya ⌥ yang ditahan dan tiling aktif, seluruh gestur termasuk momentum-nya ditelan; selain itu event
diteruskan apa adanya. Delta horizontal diubah jadi langkah fokus oleh `GulirCore.SwipeTracker`
(murni, di-unit-test). Langkahnya diskret (satu kolom per ~80 pt), bukan mengikuti jari, karena memindahkan
jendela app lain lewat AX terlalu lambat untuk animasi per frame. Swipe 3 jari tidak dipakai: tidak ada API publik.

## 9. Keputusan desain
| Keputusan | Alternatif | Alasan |
|---|---|---|
| Swift + AppKit, satu proses | Rust engine + UI Swift | Lebih sederhana untuk satu developer; performa cukup |
| Polling dulu | AXObserver langsung | Lebih cepat untuk prototipe; ditingkatkan di v0.2 |
| Hanya API publik | SkyLight private API | Tetap jalan setelah update macOS, aman untuk portofolio |
| `fraction`, bukan piksel | Lebar piksel tetap | Tahan terhadap perubahan resolusi/Dock |
| Parkir jendela di tepi (1 px) | Sembunyikan di sudut layar | Paling sederhana; dievaluasi ulang di v0.3 |

## 10. Rencana testability (v0.2)
Pisahkan target SwiftPM:
```
Sources/GulirCore/   LayoutEngine.swift   // fungsi murni: (columns, focus, scroll, area, gap) → (frames, scroll)
                     StripState.swift     // insert/remove/move/focus tanpa AX
Sources/Gulir/       app (AX, AppKit, HotKeys) memakai GulirCore
Tests/GulirCoreTests/
```
`WindowManager` hanya menerjemahkan hasil `GulirCore` ke panggilan AX. Semua properti di §4 jadi XCTest.

## 11. Rilis
- `build.sh` → `.app` + `.dmg` (ad-hoc signed, untuk dipakai sendiri).
- GitHub Actions di `macos-latest`: build + test di setiap PR; saat tag `v*`, buat .dmg dan unggah ke Releases.
- Untuk distribusi publik tanpa peringatan Gatekeeper: Developer ID + `notarytool` (butuh akun berbayar).
