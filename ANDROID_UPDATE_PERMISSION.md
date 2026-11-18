# Izin Internet Android untuk updater Lampor

HTTP 0 pada updater bukan status HTTP dari GitHub. Artinya aplikasi tidak menerima respons HTTP. Pada APK Android, penyebab umum adalah permission INTERNET tidak ikut dimasukkan ke manifest.

Sebelum mengekspor APK/AAB di Godot 4:

1. Buka **Project > Export** dan pilih preset **Android**.
2. Buka bagian **Permissions**.
3. Aktifkan **INTERNET** (pada beberapa versi Godot tampil sebagai `Internet`).
4. Ekspor ulang APK/AAB dan pasang ulang build tersebut.
5. Pastikan perangkat memiliki koneksi internet, tanggal/waktu otomatis, dan tidak memblokir GitHub melalui VPN, Private DNS, firewall, atau ad blocker.

Updater memeriksa GitHub API, lalu mencoba Atom feed sebagai fallback. Paket source ZIP diunduh dari codeload.github.com. Ini mengunduh source, bukan mengganti executable yang sedang berjalan; pemasangan binary otomatis membutuhkan sistem distribusi/release khusus per platform.

## Autosave

GameManager menyimpan checkpoint setiap 5 detik ketika permainan aktif. Checkpoint juga dipaksa saat pause, aplikasi masuk background, tombol keluar, dan permintaan tutup aplikasi. Save memakai file sementara dan backup untuk mengurangi risiko korupsi. Dari menu utama, gunakan **LANJUTKAN PERMAINAN** untuk memulihkan sesi terakhir.
