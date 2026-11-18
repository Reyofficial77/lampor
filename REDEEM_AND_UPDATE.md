# Lampor – Redeem dan Pembaruan

## Mengatur kode redeem

Edit `scripts/systems/RedemptionCodes.gd`. Setiap key pada `CODES` adalah kode yang diketik pemain. Field `type` mendukung:

- `coins`: menambahkan koin emas (`quantity`).
- `lives`: menambahkan nyawa tambahan (`quantity`).
- `item`: menambahkan item ke persediaan berikutnya (`item_id` dapat berupa `jamu` atau `baterai`).

Kode dinormalisasi menjadi huruf kapital dan dicatat di `user://lampor_save.json`, sehingga satu kode hanya bisa diklaim sekali per data save lokal. Ini bukan sistem akun/server: menghapus data save atau berpindah perangkat dapat mengatur ulang catatan klaim.

## Pembaruan source dari GitHub

Updater memeriksa commit terbaru branch `main` pada `Reyofficial77/lampor`. Ketika pemain memasang pembaruan, game mengunduh arsip commit ke penyimpanan sementara, memvalidasi ZIP, lalu menyinkronkan **seluruh isi folder proyek** mengikuti tree commit tersebut. File baru ditambahkan, file yang berubah ditimpa, dan file/folder yang tidak lagi ada pada repository dihapus. Satu-satunya direktori yang dikecualikan dari sinkronisasi adalah `.git` dan `.godot`. File data pemain tetap berada di `user://`, di luar direktori proyek.

Sebelum mengubah proyek, updater membuat backup seluruh file proyek selain isi `.git` dan `.godot`. Jika penghapusan atau penyalinan file gagal, updater membersihkan perubahan parsial dan memulihkan seluruh file dari backup. File ZIP sementara dihapus setelah pemasangan berhasil.

Setiap commit pembaruan wajib menyertakan `FIX_NOTES.md` yang tidak kosong. Catatan ini disimpan ke data lokal pemain dan ditampilkan melalui menu utama **CATATAN PEMBARUAN**. Markdown mendukung heading, tebal, miring, coret, tautan, daftar, kutipan, kode inline, dan fenced code block. Tombol **PASANG PEMBARUAN** disembunyikan setelah commit berhasil diterapkan; tombol muncul kembali hanya jika commit `main` lebih baru daripada commit yang tersimpan sebagai versi terpasang.

Pemasangan langsung hanya dapat dilakukan ketika game berjalan dari folder proyek source yang bisa ditulis (misalnya dijalankan melalui Godot Editor). APK Android dan executable desktop hasil ekspor tidak dapat menimpa isi APK/PCK yang sedang berjalan. Pada build hasil ekspor, updater menolak pemasangan source dan tidak menandainya sebagai update berhasil. Untuk update build terpasang dibutuhkan mekanisme installer/paket rilis sesuai platform.

**Penting untuk repository:** saat proyek ini diperiksa, branch `main` belum memiliki `FIX_NOTES.md` dan `scripts/autoload/UpdateManager.gd` di repository masih versi sebelum full-tree sync. Updater akan menolak commit tersebut agar proses update tidak mengganti updater baru dengan updater lama. Commit `UpdateManager.gd` versi full-sync dan `FIX_NOTES.md` ke branch `main` sebelum mengaktifkan sinkronisasi update dari repository.

## Pemecahan masalah updater (HTTP 0)

HTTP 0 berarti aplikasi tidak menerima status HTTP dari server. Updater menjelaskan kegagalan transport (DNS, koneksi, TLS, timeout), mencoba GitHub Atom sebagai jalur cadangan, dan mengunduh arsip melalui codeload GitHub. Untuk APK Android, aktifkan permission `INTERNET` di Android Export Preset lalu ekspor ulang APK.

## Autosave dan lanjutkan permainan

Progress sesi aktif disimpan otomatis setiap 5 detik ke `user://lampor_run.json`. Penyimpanan juga dipicu ketika aplikasi kehilangan fokus, aplikasi meminta ditutup, Android menerima tombol Back, atau aplikasi masuk ke background. File checkpoint ditulis melalui file sementara dan cadangan agar save sebelumnya bisa dipulihkan jika penulisan terputus. Pada menu utama, gunakan **LANJUTKAN PERMAINAN** untuk memulihkan sesi terakhir.

Checkpoint mencakup babak/waktu, objektif, obor, pintu, pickup dunia, posisi dan status pemain, posisi/status AI Lampor, kewarasan, stamina, baterai senter, inventaris, serta progres tungku. Saat melanjutkan, pemain yang sebelumnya bersembunyi ditempatkan di titik keluar tempat persembunyian agar tidak terkunci dalam animasi/sekuens tersembunyi.
