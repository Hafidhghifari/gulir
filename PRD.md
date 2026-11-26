# PRD — Gulir

## 1. Ringkasan
Gulir adalah window manager open-source untuk macOS dengan model **scrolling tiling**:
jendela disusun sebagai kolom di strip horizontal tanpa batas, sehingga membuka jendela baru
tidak pernah mengecilkan jendela lain. Navigasi utamanya keyboard; layar menggeser
strip ke kolom yang sedang fokus.

## 2. Masalah
- Tiling window manager klasik (bagi layar jadi grid) membuat setiap jendela makin sempit
  saat jumlahnya bertambah. Di laptop 13–14", tiga jendela saja sudah terlalu sempit.
- Window manager macOS biasa (snapping seperti Rectangle) tetap mengandalkan jendela
  bertumpuk, sehingga user sering kehilangan jendela dan banyak pakai Cmd-Tab / Mission Control.
- Model scrolling (niri di Linux, PaperWM) menyelesaikan dua masalah ini, tapi pilihan
  native untuk macOS yang open-source masih sedikit.

## 3. Target pengguna
- **Utama:** developer & power user di MacBook (layar tunggal) yang terbiasa dengan keyboard
  dan sering membuka 4–10 jendela sekaligus (editor, terminal, browser, dokumentasi).
- **Sekunder:** pengguna monitor ultrawide yang ingin kolom dengan lebar tetap.

## 4. Tujuan
| Tujuan | Ukuran keberhasilan |
|---|---|
| Kolom tidak pernah menyempit otomatis | Membuka jendela ke-N tidak mengubah lebar kolom lain (bisa diuji) |
| Navigasi terasa instan | Shortcut → jendela pindah < 100 ms pada 10 jendela |
| Aman | Tidak ada jendela yang tertinggal di luar layar setelah Quit / toggle off |
| Ringan | CPU idle < 1 %, memori < 50 MB |
| Mudah dipasang | Unduh .dmg dari GitHub Releases → jalan dalam < 2 menit |

## 5. Bukan tujuan (non-goals)
- Tidak memodifikasi SIP, kernel extension, atau menyuntik kode ke app lain.
- Bukan pengganti penuh yabai/AeroSpace (tidak ada BSP/grid tiling).
- Tidak ada fitur berbayar, lisensi, atau telemetri.
- Tidak menyalin nama, merek, aset, atau teks dari produk komersial yang menginspirasi.

## 6. Fitur & milestone

### v0.1 — Prototipe (sudah ditulis, belum diverifikasi)
- Strip kolom di layar utama, jendela baru disisipkan di kanan kolom aktif
- Shortcut: fokus kiri/kanan, pindah kolom, siklus lebar (⅓·½·⅔·penuh), lebar penuh, tengahkan, toggle
- Mengikuti fokus dari klik mouse / Cmd-Tab
- Menu bar: status, toggle, rapikan ulang, daftar shortcut, keluar
- Melewati jendela ukuran-tetap, full screen, dan yang di-minimize
- `build.sh` → .app + .dmg

### v0.2 — Fondasi yang solid
- Build bersih + CI GitHub Actions (`swift build`, `swift test`)
- Pisahkan `GulirCore` (layout murni) + unit test
- Ganti polling dengan `AXObserver` (window created/destroyed/focused), sisakan polling lambat sebagai jaring pengaman
- Jendela yang disembunyikan/di-minimize tetap mengingat posisinya di strip

### v0.3 — Multi-layar & Spaces
- Satu strip per layar; shortcut kirim jendela ke layar berikutnya
- Layout terpisah per Space
- Opsi mengecualikan layar tertentu dari tiling

### v0.4 — Kenyamanan
- Kolom bertumpuk (2+ jendela vertikal dalam satu kolom)
- Aturan per-app (selalu melayang / lebar default)
- File konfigurasi (`~/.config/gulir/config.toml`) + shortcut yang bisa diubah
- Animasi geser yang halus (opsional)
- Indikator posisi strip di menu bar

### v0.5 — Siap rilis publik
- Gestur trackpad 3 jari untuk menggeser strip
- Launch at login
- Rilis bertanda tangan Developer ID + notarisasi (butuh Apple Developer Program)
- Pembaruan otomatis via Sparkle

## 7. Pengalaman pengguna utama
1. User membuka Gulir.dmg → seret ke Applications → buka.
2. macOS meminta izin Accessibility; menu bar menampilkan "⚠︎ Butuh izin Accessibility" sampai diizinkan.
3. Begitu diizinkan, semua jendela di layar utama langsung tersusun jadi kolom (urutan kiri→kanan dipertahankan).
4. User bekerja dengan ⌃⌥H/L; membuka jendela baru selalu muncul di sebelah kanan jendela yang sedang dipakai.
5. Quit → semua jendela kembali ke dalam layar.

## 8. Risiko
| Risiko | Dampak | Mitigasi |
|---|---|---|
| macOS 14+ membatasi aktivasi app dari background | Fokus kadang tidak pindah | Kombinasi AXRaise + AXFrontmost; dokumentasikan; evaluasi private API sebagai opsi terisolasi |
| macOS menolak jendela keluar layar sepenuhnya | Sisa jendela terlihat di tepi | Parkir dengan sisa 1 px; evaluasi menyembunyikan di sudut seperti AeroSpace |
| App tertentu lambat merespons AX | Lag / main thread macet | Messaging timeout 0,3 dtk; nanti pindahkan AX ke background queue |
| Izin Accessibility hilang tiap build ulang (ad-hoc signing) | Pengalaman developer buruk | Signing dengan sertifikat Apple Development yang tetap |
| Bentrok shortcut dengan Rectangle/Magnet | Shortcut tidak jalan | Deteksi kegagalan registrasi; tampilkan peringatan di menu |

## 9. Pertanyaan terbuka
- Arah default jendela baru: kanan kolom aktif (sekarang) atau ujung strip?
- Saat kolom aktif ditutup, fokus pindah ke kiri atau kanan?
- Perlu dukungan Intel Mac? (Sekarang: ya, tidak ada kode khusus arsitektur.)
