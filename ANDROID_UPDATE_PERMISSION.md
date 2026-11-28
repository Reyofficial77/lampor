# Izin Android (Internet & Mikrofon) untuk Lampor

## Izin Mikrofon untuk Voice Chat (.apk)

Di Godot 4 (Preset **Android > Permissions**), izin mikrofon tidak dinamai "Microphone", melainkan:
- **Custom Permissions** (`permissions/custom_permissions`): `android.permission.RECORD_AUDIO`, `android.permission.MODIFY_AUDIO_SETTINGS`
- **Record Audio** (`permissions/record_audio=true`)
- **Modify Audio Settings** (`permissions/modify_audio_settings=true`)

Penting: Patch auto-update `.pck` (`update.pck`) **tidak** dapat mengubah `AndroidManifest.xml` di dalam `.apk` yang sudah terpasang. Jika APK sebelumnya diekspor sebelum izin `RECORD_AUDIO` aktif, opsi "Izinkan mengakses mikrofon" tidak akan muncul di Pengaturan Aplikasi Android maupun di pop-up sistem sampai APK diekspor ulang dari preset Android terbaru dan dipasang ulang di HP.

## Izin Internet untuk Updater

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
