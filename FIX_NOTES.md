# LAMPOR v1.2.0

## v1.2.1

- Memperbaiki pengiriman misi setelah map dimuat dan transisi Babak II setelah objektif Babak I selesai.
- Menambahkan cutscene kamera saat Lampor turun, sinkronisasi baterai hotbar, dan jarak tombol mobile yang lebih lega.
- Mengurangi beban preset grafis rendah dan menyertakan FIX_NOTES.md dalam export.
- Memulihkan status updater setelah kegagalan agar pengguna dapat mencoba pemeriksaan lagi.

## Fitur Baru (Update)

- **Sistem Inventori Tas (15 Slot)**:
  - Ditambahkan ruang penyimpanan tas berisi 15 slot dengan tata letak 5 kolom ke kanan dan 3 baris ke bawah (5x3).
  - Dapat dibuka dan ditutup kapan saja selama permainan menggunakan tombol **Tab**, **B**, atau **I** di desktop, tombol `🎒 TAS [TAB]` di atas hotbar, atau tombol sentuh `TAS` di layar kontrol mobile.
- **Peningkatan Kapasitas Hotbar Menjadi 5 Slot**:
  - Hotbar ditingkatkan dari 4 slot menjadi **5 slot**.
  - Mendukung tombol angka **[1] - [5]** untuk memilih barang secara langsung, serta dukungan penuh input sentuh mobile.
- **Sistem Drag & Drop serta Tukar Tempat**:
  - Pemain dapat memindahkan barang dari inventori ke hotbar atau antar slot dengan cara drag & drop.
  - Jika slot hotbar tujuan sudah memiliki item, posisi item akan otomatis saling bertukar tempat (swap), persis seperti mekanisme inventori Minecraft.
  - Tersedia pula fitur tap/klik dua slot untuk memindahkan/menukar posisi item secara mudah di mouse maupun layar sentuh HP.

## Perbaikan & Penyesuaian (Fix)

- **Perbaikan Stacking Item Hotbar (Maks. 10 Stack)**:
  - Memperbaiki masalah Jamu Tolak Bala yang dibeli dalam jumlah banyak dari toko sehingga memenuhi slot-slot hotbar.
  - Kapasitas tumpukan (stack) untuk Jamu Tolak Bala dan item habis pakai di hotbar kini ditingkatkan hingga **maksimal 10** per slot. Seluruh jamu yang dibawa dari toko kini menumpuk rapi di slot yang sama.
- **Batas Kuantitas Item Toko & Nyawa (Maks. 5/Item)**:
  - Item yang dibeli di toko (seperti Jamu Tolak Bala dan Baterai Senter) memiliki batas persediaan dan penggunaan saat permainan maksimal **5 kuantitas per item**.
  - Batas maksimal untuk **nyawa tambahan** juga ditetapkan maksimal **5 nyawa**.
  - Antarmuka toko di menu utama kini menampilkan informasi kapasitas kuota dan mencegah pembelian yang melebihi batas.
- **Perbaikan Drop Item Bertumpuk**:
  - Menjatuhkan barang yang memiliki kuantitas lebih dari 1 kini hanya membuang 1 buah ke tanah dan mempertahankan sisa tumpukan di inventori/hotbar pemain.

## Catatan Pembaruan Sistem Sebelumnya

- Updater menyinkronkan seluruh isi proyek dari commit branch `main`.
- Data save pemain tetap aman di `user://` dan tidak terhapus oleh sinkronisasi proyek.
- Setelah pembaruan selesai diterapkan, permainan meminta konfirmasi untuk memulai ulang sesi.
