# Lampor – Redeem dan Pembaruan

## Mengatur kode redeem

Edit `scripts/systems/RedemptionCodes.gd`. Setiap key pada `CODES` adalah kode yang diketik pemain. Field `type` mendukung:

- `coins`: menambahkan koin emas (`quantity`).
- `lives`: menambahkan nyawa tambahan (`quantity`).
- `item`: menambahkan item ke persediaan berikutnya (`item_id` dapat berupa `jamu` atau `baterai`).

Kode dinormalisasi menjadi huruf kapital dan dicatat di `user://lampor_save.json`, sehingga satu kode hanya bisa diklaim sekali per data save lokal. Ini bukan sistem akun/server: menghapus data save atau berpindah perangkat dapat mengatur ulang catatan klaim.

## Pembaruan dari GitHub

Updater memeriksa commit terbaru branch `main` pada `Reyofficial77/lampor` dan dapat mengunduh arsip ZIP commit tersebut. Pengaturan **Unduh paket update otomatis** hanya mengaktifkan unduhan otomatis setelah versi lebih baru terdeteksi.

Arsip yang tersedia dari repository saat ini adalah source project Godot, bukan installer/binary game. Karena itu, game tidak menimpa executable yang sedang berjalan. Tombol update membuka arsip yang sudah diunduh untuk dipasang secara manual. Pemasangan otomatis penuh memerlukan paket export per platform (Windows/Linux/macOS/Android), nomor versi/build, dan mekanisme patcher/installer yang sesuai platform.


## Pemecahan masalah updater (HTTP 0)

HTTP 0 berarti aplikasi tidak menerima status HTTP dari server. Versi ini menampilkan jenis kegagalan transport (DNS, koneksi, TLS, timeout) dan mencoba endpoint feed GitHub sebagai jalur cadangan. Unduhan arsip menggunakan host codeload GitHub secara langsung.

Untuk APK Android, buka **Project → Export → Android → Permissions**, aktifkan izin **INTERNET**, lalu ekspor ulang APK. APK yang sudah diekspor tanpa izin ini tidak dapat diperbaiki hanya dengan mengganti skrip atau mengunduh update source. Tanpa izin ini, Godot memblokir koneksi jaringan. Pastikan perangkat juga memiliki koneksi internet, DNS yang berfungsi, dan tanggal/waktu otomatis.

## Autosave dan lanjutkan permainan

Progress sesi aktif disimpan otomatis setiap 5 detik ke `user://lampor_run.json`. Penyimpanan juga dipicu ketika aplikasi kehilangan fokus, aplikasi meminta ditutup, Android menerima tombol Back, atau aplikasi masuk ke background. File checkpoint ditulis melalui file sementara dan cadangan agar save sebelumnya bisa dipulihkan jika penulisan terputus. Pada menu utama, tombol **LANJUTKAN PERMAINAN** muncul ketika ada autosave yang valid. Memulai permainan baru menghapus checkpoint sebelumnya; menang atau kalah juga menghapus checkpoint agar sesi lama tidak bisa terbuka kembali.

Checkpoint mencakup babak/waktu, objektif, obor, pintu, pickup dunia, posisi dan status pemain, posisi/status AI Lampor, kewarasan, stamina, baterai senter, inventaris, serta progres tungku. Saat melanjutkan, pemain yang sebelumnya bersembunyi ditempatkan di titik keluar tempat persembunyian agar tidak terkunci dalam animasi/sekuens tersembunyi.
