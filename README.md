# LAMPOR: Malam Jahanam

Game survival horror 3D bertema folklor Indonesia. Bertahan dari malam, selesaikan objektif setiap babak, kumpulkan benda ritual, lalu bakar semuanya di tungku sebelum fajar.

## Persyaratan

- Godot Engine **4.7** atau versi kompatibel yang mendukung fitur proyek ini.
- Renderer Forward+ (sesuai konfigurasi proyek).
- Windows, Linux, atau macOS yang dapat menjalankan Godot 4.

## Menjalankan dari Godot

1. Unduh atau clone repositori ini.
2. Buka Godot Project Manager.
3. Pilih **Import** lalu arahkan ke file `project.godot` di folder proyek.
4. Buka proyek dan tunggu Godot menyelesaikan impor aset.
5. Tekan **F6** untuk menjalankan scene aktif atau **F5** untuk menjalankan game dari menu utama.

## Menjalankan di Windows

Jalankan `Mainkan_Lampor.bat` dari folder proyek. Jika Godot tidak ditemukan, tambahkan Godot ke `PATH` atau sesuaikan lokasi executable pada file batch tersebut.

## Kontrol

### Desktop

| Aksi | Kontrol |
|---|---|
| Bergerak | `W`, `A`, `S`, `D` atau tombol panah |
| Lihat sekitar | Mouse |
| Berlari | `Shift` |
| Interaksi | `E` |
| Senter | `F` |
| Pilih item | `1`–`4` |
| Gunakan item | `Enter` / `Space` |
| Jatuhkan item | `G` |
| Jeda / tutup dialog | `Esc` |

### Mobile

Gunakan joystick virtual di sisi kiri untuk bergerak, area kanan layar untuk mengubah arah pandang, dan tombol aksi di sisi kanan untuk interaksi, senter, berlari, serta penggunaan item.

## Alur permainan

- **Babak I — Pertahanan Awal (01.00–02.30):** nyalakan lima obor penolak bala dan barikade tiga pintu rumah.
- **Babak II — Ritual Pemutus Kutukan (02.30–04.00):** hindari Lampor dan kumpulkan empat benda ritual: kemenyan, bunga tujuh rupa, keris pusaka, dan tanah kuburan.
- **Babak III — Klimaks Pembakaran (04.00–05.00):** bawa benda ritual ke tungku dan bertahan sampai proses pembakaran selesai.

Babak II dimulai berdasarkan jam permainan pada **02.30**, meskipun objektif Babak I selesai lebih awal atau belum selesai. Babak III dimulai setelah seluruh benda ritual terkumpul.

## Fitur

- Survival horror dengan AI Lampor, sistem kewarasan, stamina, senter, dan inventaris.
- Siklus waktu malam hingga fajar dan objektif berbasis babak.
- HUD adaptif untuk desktop dan layar sentuh.
- Kartu misi saat babak dimulai, dialog naratif yang menyesuaikan panjang teks, dan konfirmasi keluar dari permainan.
- Audio ambient, efek suara, jumpscare, dan audio ending.
- Pengaturan permainan dan penyimpanan jumlah kemenangan lokal.

## Struktur proyek

```text
assets/       Audio, tekstur, dan shader
scenes/       Scene pemain, dunia, entitas, item, dan UI
scripts/      Sistem permainan, AI, pemain, autoload, dan UI
project.godot Konfigurasi proyek Godot
```

## Catatan pengembangan

- Simpan perubahan scene dan script melalui Godot agar resource UID dan metadata impor tetap konsisten.
- Folder `.godot/` berisi cache editor lokal dan tidak diperlukan untuk distribusi source code.
- Pastikan file audio di `assets/audio/` tetap tersedia; khususnya `jumpscare.wav` digunakan ketika pemain dikalahkan oleh Lampor.

## Lisensi

Proyek ini didistribusikan di bawah lisensi MIT. Lihat file [`LICENSE`](LICENSE).
