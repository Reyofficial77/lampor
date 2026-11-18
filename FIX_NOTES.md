# LAMPOR v1.1.9

## Pembaruan sistem

- Updater kini menyinkronkan seluruh isi proyek dari commit terbaru branch `main`.
- File baru ditambahkan dan file yang berubah diperbarui otomatis.
- File serta folder yang sudah dihapus dari repository ikut dihapus dari proyek lokal.
- Direktori `.git` dan `.godot` tidak pernah disentuh updater.
- Backup dibuat sebelum sinkronisasi. Jika pemasangan gagal, file proyek dipulihkan.

## Catatan pembaruan

- Menu utama memiliki tombol **Catatan Pembaruan** untuk membaca `FIX_NOTES.md`.
- Tampilan catatan mendukung Markdown: heading, **bold**, *italic*, ~~strikethrough~~, link, daftar, blockquote, inline code, dan fenced code block.
- Setiap update harus menyertakan `FIX_NOTES.md` yang tidak kosong.

## Perilaku tombol update

- Tombol update hilang setelah commit berhasil diterapkan.
- Tombol muncul kembali hanya ketika GitHub memiliki commit yang lebih baru.
- Data save pemain tetap berada di `user://` dan tidak ikut dihapus oleh sinkronisasi proyek.

## Mulai ulang setelah update

- Setelah sinkronisasi repository berhasil, game menampilkan dialog yang meminta pemain memulai ulang permainan.
- Tombol **Mulai Ulang Sekarang** menyimpan progress dan mencoba menjalankan ulang proyek dengan executable Godot yang sama.
- Pemain juga dapat memilih mulai ulang manual nanti; pemberitahuan tetap menjelaskan bahwa sesi harus dibuka ulang agar seluruh skrip dan resource terbaru dimuat.
- Tombol update disembunyikan setelah commit berhasil diterapkan.
