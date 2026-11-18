# Izin Internet Android untuk updater Lampor

HTTP 0 pada updater bukan status HTTP dari GitHub. Artinya aplikasi tidak menerima respons HTTP. Pada APK Android, penyebab umum adalah permission INTERNET tidak ikut dimasukkan ke manifest.

Sebelum mengekspor APK/AAB di Godot 4:

1. Buka **Project > Export** dan pilih preset **Android**.
2. Buka bagian **Permissions**.
3. Aktifkan **INTERNET** (pada beberapa versi Godot tampil sebagai `Internet`).
4. Ekspor ulang APK/AAB dan pasang ulang build tersebut.
5. Pastikan perangkat memiliki koneksi internet, tanggal/waktu otomatis, dan tidak memblokir GitHub melalui VPN, Private DNS, firewall, atau ad blocker.

Updater memeriksa GitHub API, lalu mencoba Atom feed sebagai fallback. Source diunduh secara internal, diekstrak ke direktori data privat aplikasi, dan arsip sementara dihapus. Android tidak mengizinkan aplikasi menimpa APK/PCK yang sedang berjalan. Untuk menerapkan update ke instalasi Android, repository perlu menerbitkan APK/AAB release dan aplikasi perlu memakai alur pemasangan Android yang sesuai (atau distribusi melalui Play Store).

## Autosave

GameManager menyimpan checkpoint setiap 5 detik ketika permainan aktif. Checkpoint juga dipaksa saat pause, aplikasi masuk background, tombol keluar, dan permintaan tutup aplikasi. Save memakai file sementara dan backup untuk mengurangi risiko korupsi. Dari menu utama, gunakan **LANJUTKAN PERMAINAN** untuk memulihkan sesi terakhir.
