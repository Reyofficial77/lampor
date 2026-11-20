# LAMPOR v1.2.2

## v1.2.2

- **Perbaikan Tampilan `FIX_NOTES.md` pada Export APK & EXE (Sinkron Commit Terbaru)**:
  - Menambahkan pengunduh langsung `FIX_NOTES.md` dari commit terbaru repository GitHub (`raw.githubusercontent.com`) yang otomatis menyimpan cache ke `user://lampor_fix_notes.md` sehingga APK Android maupun EXE Windows hasil export selalu menampilkan `FIX_NOTES.md` dari commit terbaru tanpa perlu menimpa paket APK/PCK.
  - Menyematkan salinan cadangan `FIX_NOTES.md` langsung di dalam bytecode skrip serta menambahkan preset export Android (`include_filter="FIX_NOTES.md,*.md"` & permission `INTERNET`) agar catatan pembaruan tetap tampil meski perangkat sedang offline.
  - Mencegah `auto_update` menimpa working tree `.git` lokal secara otomatis saat diuji di dalam Godot Editor sebelum commit di-push.
- **Fast-Forward Otomatis ke 02.30 WIB & Transisi Langsung Babak II**:
  - Ketika seluruh misi Babak I (5 Obor Penolak Bala & 3 Barikade Pintu Rumah) selesai sebelum waktu menunjukkan pukul 02.30 WIB, jam permainan langsung dipercepat (fast-forward) ke **02.30 WIB** dan Babak II langsung dimulai beserta turunnya Lampor ke desa.
  - Memperbaiki urutan penutupan dialog konfirmasi barikade dari dalam rumah agar transisi Babak II dan cutscene turunnya Lampor tidak terhambat status pause.
- **Perbaikan Bug Gagal Masuk In-Game di Mobile**:
  - Memperbaiki kegagalan pemuatan `VillageMap.tscn` di perangkat mobile setelah memilih tingkat kesulitan akibat tekstur 3D (`wood_albedo.png`, `bamboo_albedo.png`, `cloth_green.png`) yang terimpor eksklusif ke format desktop `s3tc_bptc`.
  - Mengubah seluruh `.import` tekstur ke mode lossless `.ctex` lintas-platform (`compress/mode=0`, `detect_3d/compress_to=0`) serta mengaktifkan `textures/vram_compression/import_etc2_astc=true`.
- **Tampilan Objektif Langsung Muncul di Kiri Atas**:
  - Daftar objektif malam kini langsung diinisialisasi dan ditampilkan di panel kiri atas sejak frame pertama memasuki in-game serta diperbarui lebih dulu sebelum banner/kartu babak ditampilkan.
- **Tata Letak UI Mobile Lebih Rapi & Anti-Berdempetan**:
  - Menata ulang posisi panel status (`Waras`, `Stamina`, `Senter`) di sudut kanan atas dan memindahkan tombol `Ⅱ` (Jeda) serta `TAS` ke sisi kiri panel status agar tidak saling bertabrakan.
  - Membatasi ukuran slot hotbar (`clip_contents`) dan pemotongan teks nama item panjang agar hotbar tidak melebar menabrak joystick maupun tombol aksi kanan.
- **Visual UI Nuansa Horor & Model Lampor Keranda Hijau Realistis**:
  - Menambahkan latar belakang horor beranimasi di Menu Utama serta memperbarui palet visual seluruh layar menu dan HUD.
  - Merombak model 3D Lampor menjadi keranda jenazah hijau sungguhan lengkap dengan batang pikulan tandu panjang, 4 kaki keranda, lengkungan kurung batang, lipatan kain beludru hijau, bordir kaligrafi Arab emas, rumbai-rumbai emas di keempat sisi, dan celah tirai depan dengan siluet kain kafan serta mata merah menyala.

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
