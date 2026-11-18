# Menyiapkan GitHub agar full-sync updater aktif

Updater lokal sudah mendukung sinkronisasi tree penuh, tetapi branch `main` harus berisi implementasi updater yang sama. Pada pemeriksaan terakhir, file updater di `main` masih versi lama dan `FIX_NOTES.md` belum ada. Updater sengaja menolak paket tersebut agar tidak menimpa dirinya sendiri dengan updater lama.

Commit seluruh isi proyek Lampor yang memang ingin dipakai pemain ke branch `main`, termasuk setidaknya:

- `scripts/autoload/UpdateManager.gd`
- `scripts/systems/MainMenu.gd`
- `FIX_NOTES.md`
- `project.godot`
- seluruh scene, script, audio, tekstur, ikon, dan file pendukung yang ingin tetap ada di game.

Jangan hanya commit dua file updater jika perubahan game lain dari proyek lokal juga harus dipertahankan. Karena updater bekerja dengan sinkronisasi penuh, file lokal apa pun yang tidak terdapat di commit GitHub akan dihapus (kecuali isi `.git` dan `.godot`). Setiap commit berikutnya wajib memperbarui `FIX_NOTES.md` dengan catatan Markdown untuk pemain dan jangan menghapus file tersebut dari branch `main`.

## Aturan sinkronisasi

- Updater mengunduh arsip commit branch `main`, lalu menyalin seluruh file proyek dari arsip.
- File proyek lokal yang tidak ada di commit remote akan dihapus.
- Hanya folder `.git` dan `.godot` yang dikecualikan.
- Backup dibuat di direktori data aplikasi (`user://updates/backups`), bukan di folder proyek.
- Update hanya diterapkan langsung saat `res://` adalah folder source yang dapat ditulis. APK/EXE hasil ekspor membutuhkan installer/paket rilis platform; updater source tidak dapat menulis ulang APK/PCK aktif.
