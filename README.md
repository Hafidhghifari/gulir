# Gulir — scrolling tiling window manager mini untuk macOS

Semua jendela di layar utama disusun jadi **kolom-kolom berjajar ke samping**.
Buka jendela baru → muncul di kanan kolom aktif, jendela lain **tidak mengecil**.
Layar bertindak seperti "jendela pandang" yang menggeser strip ke kolom yang sedang fokus.

## Unduh
**[⬇ Unduh Gulir.dmg (v0.1.1, pre-release)](https://github.com/Hafidhghifari/gulir/releases/download/v0.1.1/Gulir.dmg)**
· [semua rilis](https://github.com/Hafidhghifari/gulir/releases)

> Universal: jalan di Mac Apple silicon maupun Intel, macOS 13 ke atas.

Buka DMG-nya, seret **Gulir** ke **Applications**, lalu buka dari Applications.
Karena belum dinotarisasi, macOS akan memblokirnya saat pertama dibuka. Klik kanan **Gulir.app** → **Open** → **Open**,
atau jalankan `xattr -dr com.apple.quarantine /Applications/Gulir.app`.

## Syarat
- macOS 13 (Ventura) atau lebih baru — Intel maupun Apple silicon
- Xcode Command Line Tools: `xcode-select --install` (hanya untuk build sendiri)

## Build sendiri jadi .dmg
```bash
cd Gulir
chmod +x build.sh
./build.sh
```
Hasilnya `build/Gulir.app` dan `build/Gulir.dmg`. Buka DMG-nya, seret Gulir ke Applications, lalu buka dari Applications.

> DMG ini ditandatangani ad-hoc: aman dipakai di Mac kamu sendiri.
> Kalau dikirim ke Mac orang lain, macOS akan memblokirnya ("tidak bisa diverifikasi").
> Supaya bisa dibagikan tanpa peringatan, perlu Apple Developer Program ($99/tahun),
> tanda tangan Developer ID, dan notarisasi.
Saat pertama dibuka, macOS akan minta izin **Accessibility**:
System Settings → Privacy & Security → Accessibility → nyalakan **Gulir**.
Gulir otomatis mulai bekerja begitu izin diberikan (tidak perlu restart).

> Setiap kali kamu build ulang, macOS bisa menganggapnya app berbeda.
> Kalau shortcut tiba-tiba tidak bekerja: hapus Gulir dari daftar Accessibility (tombol −), lalu tambahkan lagi.

## Shortcut
| Shortcut | Fungsi |
|---|---|
| ⌃⌥ H / L atau ⌃⌥ ← / → | Pindah fokus ke kolom kiri / kanan |
| ⌃⌥⇧ H / L atau ⌃⌥⇧ ← / → | Pindahkan kolom ke kiri / kanan |
| ⌥ + swipe 2 jari kiri / kanan (trackpad) | Pindah fokus ke kolom kiri / kanan |
| ⌃⌥ R | Ganti lebar kolom: ⅓ → ½ → ⅔ → penuh |
| ⌃⌥ F | Lebar penuh / kembali ke lebar sebelumnya |
| ⌃⌥ C | Tengahkan kolom aktif |
| ⌃⌥ T | Nyalakan / matikan tiling |

Klik jendela pakai mouse atau Cmd-Tab juga menggeser strip ke jendela itu.
Selama ⌥ ditahan, scroll 2 jari dipakai Gulir (tidak sampai ke app di bawah kursor); tanpa ⌥, scroll berjalan normal.

## Mengubah pengaturan
Di `Sources/Gulir/WindowManager.swift`, bagian atas class:
`gap` (jarak antar jendela), `presets` (pilihan lebar), `defaultFraction` (lebar jendela baru).
Shortcut ada di fungsi `registerHotKeys()`.

## Batasan prototipe ini
- Hanya layar utama; monitor lain dibiarkan apa adanya.
- Spaces tidak punya layout terpisah.
- Belum ada gestur trackpad, animasi, kolom bertumpuk/tab, atau aturan per-app.
- Jendela dengan ukuran tetap (mis. Kalkulator) dan mode full screen dibiarkan melayang.
- Bentrok dengan Rectangle/Magnet (mereka juga pakai ⌃⌥ + panah) — matikan salah satu.
- Ganti fokus antar-app kadang tidak "nyangkut" di macOS 14+ karena aturan aktivasi Apple.

## Kalau ada yang kacau
Pilih **Keluar Gulir** dari ikon menu bar — semua jendela dikembalikan ke tengah layar.
Kalau Gulir di-force-quit, jendela bisa tertinggal di tepi layar: buka lagi Gulir lalu Keluar,
atau pakai Window → Zoom / Mission Control untuk mengambilnya.
