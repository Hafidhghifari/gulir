# AGENTS.md — panduan untuk coding agent

Gulir adalah **scrolling tiling window manager** untuk macOS (konsep mirip niri / PaperWM):
setiap jendela adalah kolom di sebuah strip horizontal yang lebih lebar dari layar,
dan layar bertindak sebagai viewport yang bergeser ke kolom yang sedang fokus.

Baca juga sebelum mengubah perilaku: `PRD.md` (apa & kenapa) dan `DESIGN.md` (bagaimana).

## Status saat ini
- v0.1 sudah lolos `swift build` dan `swift build -c release` tanpa error & warning
  (Swift 6.4, macOS 27.2), dan `./build.sh` menghasilkan .app + .dmg.
  Uji manual (lihat "Verifikasi") **belum** dilakukan.
- Hanya layar utama, polling tiap 0,5 detik, tanpa test.

## Perintah
```bash
swift build                 # build debug
swift build -c release      # build release
./build.sh                  # release + Gulir.app + build/Gulir.dmg (ad-hoc signed)
swift test                  # unit test (setelah target GulirCore ada, lihat DESIGN.md)
open build/Gulir.app        # jalankan
log stream --predicate 'process == "Gulir"'   # lihat NSLog
```

## Struktur
```
Package.swift
Sources/Gulir/
  main.swift            entry point, NSApplication (.accessory → tanpa ikon Dock)
  AppDelegate.swift     menu bar, alur izin Accessibility, terminate → restoreAll
  WindowManager.swift   state kolom, sync loop, layout, aksi shortcut
  AX.swift              pembungkus Accessibility API (baca/tulis frame, atribut)
  HotKeys.swift         shortcut global via Carbon RegisterEventHotKey
build.sh                build .app + .dmg
```

## Aturan wajib
1. **Jangan pernah meninggalkan jendela user di luar layar.** Setiap jalur keluar
   (Quit, toggle off, crash handler bila ditambahkan) harus memanggil `restoreAll()`.
2. **Hanya API publik.** Private API (SkyLight/CGS, `_AXUIElementGetWindow`, dsb.) hanya boleh
   dipakai jika disetujui user, diisolasi di satu file, dan punya fallback publik.
3. **Logika layout harus murni.** Perhitungan posisi kolom tidak boleh memanggil AX/AppKit,
   supaya bisa di-unit-test (lihat rencana `GulirCore` di DESIGN.md).
4. **Semua panggilan AX dianggap bisa gagal / lambat.** Selalu set messaging timeout,
   jangan force-unwrap hasil AX, jangan blokir main thread lebih dari ~50 ms per tick.
5. **Koordinat:** AX memakai titik asal kiri-atas layar utama; `NSScreen` memakai kiri-bawah.
   Konversi hanya di satu tempat (`usableArea()` / helper koordinat). Jangan campur.
6. Target **macOS 13+**, Swift tools 5.9, language mode Swift 5. Jangan naikkan tanpa alasan.
7. Jangan tambah dependency pihak ketiga tanpa bertanya. Pengecualian yang wajar: Sparkle (update).

## Gaya kode
- Swift standar, indentasi 4 spasi, `final class` secara default, `private` sebisa mungkin.
- Nama tipe/fungsi dalam bahasa Inggris; komentar & teks UI boleh bahasa Indonesia.
- Fungsi kecil dan bernama jelas; hindari singleton baru selain `HotKeys.shared`.

## Verifikasi sebelum menyatakan selesai
1. `swift build` bersih tanpa error. Warning baru harus dijelaskan.
2. `swift test` lulus (setelah ada test).
3. Uji manual minimal: buka 4+ jendela (Finder, Safari, Terminal, Notes) lalu cek:
   - jendela baru muncul di kanan kolom aktif, jendela lain tidak mengecil
   - ⌃⌥H/L menggeser strip dan fokus benar-benar berpindah
   - ⌃⌥R / ⌃⌥F / ⌃⌥C bekerja
   - tutup jendela di tengah → tidak ada celah
   - Quit → semua jendela kembali terlihat di layar
4. Catat hasil uji manual di deskripsi PR.

## Git
- Branch per fitur: `feat/…`, `fix/…`, `docs/…`.
- Conventional Commits: `feat: multi-monitor strip`, `fix: focus jump on app activate`.
- Jangan commit `build/`, `.build/`, atau file `.dmg`. Rilis .dmg lewat GitHub Releases.
