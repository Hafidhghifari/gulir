## Pasang
1. Unduh **Gulir.dmg** di bawah, buka, lalu seret **Gulir** ke folder **Applications**.
2. Buka Gulir dan izinkan di **System Settings → Privacy & Security → Accessibility**.

## Peringatan "unidentified developer" / "damaged"
Build ini hanya ditandatangani ad-hoc (belum Developer ID + notarisasi), jadi macOS akan
memblokirnya saat pertama dibuka. Pilih salah satu:
- Klik kanan **Gulir.app** → **Open** → **Open**, atau
- Jalankan di Terminal: `xattr -dr com.apple.quarantine /Applications/Gulir.app`

> Ini pre-release prototipe. Kalau ada jendela yang tertinggal di luar layar, keluar dari Gulir
> lewat menu bar (**Keluar Gulir**) untuk mengembalikan semua jendela.
