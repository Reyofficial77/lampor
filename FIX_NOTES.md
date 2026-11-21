# LAMPOR v1.2.6

## v1.2.6

- **Desain Ulang Antarmuka Horor (`DESIGN.md`) & Penyempurnaan Victory Screen**:
  - Merombak tampilan Menu Utama (beserta modal Peringatan, Tingkat Kesulitan, Toko Bekal, Pengaturan, Catatan Pembaruan, Hak Cipta, dan Pembaruan), Layar Game Over, Menu Jeda, Pengaturan Jeda, Konfirmasi Keluar, serta Konfirmasi Barikade dengan palet horor obsidian hangus (`#170B0A`), merah darah kering (`#9E1B1B` / `#D4433C`), bingkai besi tua (`#59413E`), dan perkamen tulang (`#F7DDDA`) lengkap dengan latar ritual beranimasi serta ornamen siku sudut.
  - Memperbaiki margin kanan tombol `KELUAR PERMAINAN` di Menu Utama agar proporsional dan tidak menempel ke tepi layar.
  - Mempertahankan estetika fajar keemasan terbuka pada `VictoryScreen` (`FAJAR TELAH MENYINGSING`) dengan polesan pendar cahaya pagi, partikel bara emas, bingkai sudut tipis, dan lencana hadiah koin.
- **Pembaruan Slot Hotbar, Modal Tas Tanpa Scroll, Ikon Vektor Mobile, & Petunjuk Kontrol Desktop**:
  - Memperbarui desain visual 5 slot hotbar dan 15 slot tas (`5x3`) menjadi tablet relik persegi `1:1` dengan indikator status aktif, terpilih, dan kosong yang tegas, serta menghapus scrollbar pada modal Tas agar seluruh slot langsung terlihat ringkas.
  - Mengganti seluruh teks/huruf pada tombol sentuh mobile dengan ikon geometris vektor khusus (Berlari, Interaksi, Senter, Tas, dan Jeda) tanpa huruf maupun emoji.
  - Menambahkan baris petunjuk kontrol desktop bergaya minimalis (`[E] Interaksi / Pakai`, `[F] Senter`, `[Shift] Lari`, `[1-5] Slot`, `[Tab] Tas`, `[G] Buang`, `[Esc] Jeda`) di sudut kanan bawah HUD.
- **Penyatuan Interaksi & Penggunaan Barang ke Tombol `[E]`**:
  - Menghapus tombol `"PAKAI"` di mobile serta penggunaan item via `Enter`/`Space` di desktop; seluruh interaksi dunia (mengambil barang, menyalakan obor, membuka/membarikade pintu, bersembunyi di lemari, membakar di tungku) sekaligus penggunaan barang habis pakai di tangan (`Jamu Tolak Bala` & `Baterai Senter`) kini terpusat pada tombol **`[E]`** (desktop) dan tombol **Ikon Tangan** (mobile).
- **Model Karakter 3D Baru (`ordinaryMan.fbx`) & Animasi Pergerakan Lebih Realistis**:
  - Mengintegrasikan model karakter manusia 3D baru (`ordinaryMan.fbx`) lengkap dengan tekstur resolusi tinggi dan pemetaan kerangka tulang penuh.
  - Memperhalus animasi `idle` (napas & tumpuan berat badan alami), `walk`, dan `sprint` menggunakan interpolasi kubik multi-keyframe, inersia ayunan tangan saat menoleh, transisi mengangkat barang saat berganti slot hotbar, serta gerakan anatomis kedua lengan baik saat memegang barang maupun tangan kosong.
- **Konsekuensi Batas Waktu Pukul `05.00 WIB` & Penyesuaian Kecepatan Membakar per Mode**:
  - Ketika waktu mencapai pukul **05.00 WIB** pada tingkat kesulitan apa pun (`Easy`, `Normal`, `Hard`, maupun `Nightmare`) sebelum ritual pembakaran selesai, Keranda Lampor akan langsung melahap pemain secara otomatis (melewati nyawa cadangan) dan memicu Game Over.
  - Menyesuaikan durasi pembakaran benda ritual di Tungku Balai Desa secara proporsional dengan kecepatan waktu tiap mode (`Easy: 60 detik`, `Normal: 45 detik`, `Hard: 15 detik`, `Nightmare: 8 detik`) serta mempertahankan sisa waktu Babak II saat memasuki Babak III agar pemain di mode cepat tetap memiliki waktu yang adil sebelum pukul `05.00 WIB`.
- **Fitur Tutorial Interaktif untuk Pemain Baru (Mode Easy) & Batas Aman Koin**:
  - Menambahkan sistem tutorial langkah-demi-langkah (7 tahap) pada mode `Easy` bagi pemain yang baru pertama kali bermain (dan dapat diakses kapan saja melalui menu pilihan tingkat kesulitan), mencakup latihan pergerakan & senter, pengambilan bekal, penyalaan obor, barikade pintu, larangan menatap Lampor, pengumpulan 4 benda ritual, hingga pembakaran di Tungku Balai Desa dengan panel ringkas yang dapat diperkecil (`[–]`).
  - Menambahkan batas maksimum penyimpanan koin (`999.999.999`) untuk mencegah *integer overflow* (nilai koin menjadi negatif) saat menerima hadiah kemenangan atau kekalahan.

## v1.2.5

- **Perbaikan Tombol Keluar Menu Jeda (`Esc`) ke Main Menu**:
  - Menghubungkan opsi keluar pada menu jeda (`PauseMenu`) ke `_on_main_menu_pressed()` sehingga pemain kembali ke Menu Utama dengan menyimpan progres aktif terlebih dahulu, alih-alih langsung menutup aplikasi game.
  - Menekan `Esc` saat panel Pengaturan Jeda terbuka kini mengembalikan ke Menu Jeda terlebih dahulu.
- **Perbaikan Scroll & Pengaturan Menu Utama**:
  - Menambahkan dukungan scroll langsung (roda mouse, sentuh/swipe, dan klik-geser di area konten) pada menu **Pengaturan**, **Toko Item**, **Catatan Pembaruan**, dan **Pengaturan Jeda** tanpa harus menahan scrollbar.
  - Memuat catatan pembaruan versi sebelumnya secara bertahap saat digulir agar pembukaan **Catatan Pembaruan** bebas freeze, merapikan jarak baris serta kode inline, dan memperbarui judul modal **Hak Cipta** menjadi `LAMPOR`.
  - Menampilkan persentase pada slider **Volume** dan memastikan default kualitas grafik berada pada `Otomatis (Perangkat)`.
- **Suasana Horor Preset Grafik `Low` Setara `Medium` & Tetap Ringan**:
  - Mengaktifkan kembali kabut kedalaman (`fog_enabled = true`), menyelaraskan warna ambient (`0.11, 0.13, 0.19`) dan cahaya bulan (`0.55`) dengan preset `Medium`, serta menaikkan jarak render kamera (`cam.far = 90.0`) dan skala resolusi (`0.68`) agar desa tidak tampak polos atau terpotong hitam.
  - Menjaga `HorrorOverlay` tetap aktif dengan mode ringan (`fast_mode = 1.0`, tanpa *film grain* maupun *chromatic aberration* saat kewarasan normal) serta mempertahankan pendar `ItemLight` pada item tanpa bayangan (`shadow_enabled = false`), sementara MSAA, FXAA, dan seluruh shadow pass tetap nonaktif agar performa tetap ringan.

## v1.2.4

- **Sistem Auto-Update `.pck` Otomatis via GitHub Actions**:
  - Menambahkan workflow `.github/workflows/auto_pck.yml` untuk mengekspor `update.pck` dan `pck_manifest.json` secara otomatis ke release tag `latest-commit` setiap kali ada `push` ke branch `main`.
  - Memperbarui `UpdateManager.gd` agar build hasil ekspor (Windows EXE & Android APK) mengunduh dan menerapkan patch `update.pck` via `ProjectSettings.load_resource_pack` dengan staging aman (`update_pending.pck`), verifikasi header `GDPC`, penjaga anti-downgrade versi, serta pengecekan berkala otomatis.
  - Melindungi working copy `.git` dan Godot Editor agar tombol pembaruan tidak pernah menimpa perubahan lokal yang belum di-push ke GitHub.
  - Memindahkan `UpdateManager` ke posisi pertama di `[autoload]` agar patch `.pck` dimuat sebelum seluruh sistem dan scene utama berjalan, serta menyesuaikan alur restart pembaruan untuk EXE desktop dan Android.

## v1.2.3

- **Stabilitas Ukuran & Animasi Tangan FPP serta Genggaman Barang (`Hand.R`)**:
  - Mengunci orientasi torso (`Hips`, `Torso`, `Chest`, `Neck`, `Head`) pada sudut pandang First-Person (FPP) dan menyelaraskan `PlayerModel` dengan head-bobbing kamera agar tangan kanan tidak lagi membesar atau berubah ukuran saat berjalan, sprint, menoleh, maupun berinteraksi.
  - Memperbaiki animasi ayunan lengan agar tetap luwes saat diam, berjalan, sprint, dan berinteraksi dengan skala konstan proporsional pada `Hand.R`, tekukan jari yang rapi menggenggam barang (`Senter`, `Jamu Tolak Bala`, `Minyak Tanah & Korek`, `Papan & Paku`, dan `Baterai`), serta menjaga dada/jas tidak menutupi bagian bawah layar saat menunduk.
- **Perbaikan Sorotan Senter di Semua Preset Grafis**:
  - Memindahkan posisi `SpotLight3D` senter ke depan ujung senter genggam (`z = -0.38`) dan menonaktifkan `cast_shadow` pada `Suit_Body` serta prop genggam agar sorotan senter tidak terblokir bayangan tangan di preset `High`.
  - Menaikkan daya dan jangkauan sorot senter serta menyeimbangkan cahaya bulan dan ambient di preset grafis `Low` agar cahaya senter terlihat jelas menerangi jalan desa.
- **Penyeimbangan Kewarasan (Sanity) & Efek Pusing Tetap Aktif di Grafik Low**:
  - Memperlambat laju pengurasan kewarasan di kegelapan dan dalam rumah pada seluruh tingkat kesulitan (`Easy`, `Normal`, `Hard`, `Nightmare`) agar eksplorasi multi-babak lebih seimbang.
  - Menjaga `HorrorOverlay` tetap aktif ketika kewarasan menurun di preset grafis `Low` (tanpa film grain agar tetap ringan) lengkap dengan distorsi gelombang UV pusing (`dizzy_intensity`), chromatic aberration, vignette berdenyut, dan goyangan kamera halus saat kewarasan rendah.
- **Slot Hotbar & Tas Kotak Presisi 1:1**:
  - Memperbaiki tata letak dan pemotongan teks slot hotbar (`80x80` desktop / `62x62` mobile) serta slot modal tas (`72x72`) dengan sudut lebih tegas agar tetap berbentuk kotak persegi 1:1 meskipun berisi nama item yang panjang.

## v1.2.2

- **Tangan Asli Model 3D (`Hand.R`), Barang Sesuai Slot Hotbar, & Pencahayaan Grafik Low**:
  - Menghapus objek lengan FPP terpisah (`FPPRightArm`) sehingga hanya memakai tangan asli dari tulang `Skeleton3D` model karakter (`Suit.glb`) tanpa duplikasi lengan.
  - Menghubungkan `BoneAttachment3D` pada tulang `Hand.R` untuk memegang model 3D barang sesuai slot hotbar yang aktif (`Senter`, `Jamu Tolak Bala`, `Minyak Tanah & Korek`, `Papan & Paku`, atau `Baterai`), mematikan sorotan senter saat slot lain dipilih, serta membiarkan tangan turun kosong saat slot `[Kosong]` dipilih.
  - Memberikan lantai pancaran ambient tipis pada material tangan/jas agar tangan tetap terlihat saat ruangan gelap, sekaligus menaikkan cahaya bulan, subdivisi permukaan tanah (`32x32`), dan ambient lingkungan pada preset grafis `Low` agar desa tetap jelas tanpa mengorbankan performa.
- **Perbaikan Tangan FPP, Model Manusia Berjas Proporsional (`Suit.glb`), & Penyempurnaan Tata Letak HUD**:
  - Menghilangkan duplikasi tangan dan bagian torso yang menghalangi kamera FPP dengan memakai satu model manusia pria berjas proporsional CC0 (`Suit.glb`) yang diposisikan rapi di belakang bidang kamera (`z = +0.34`) beserta `AnimationLibrary` skeletal (`idle`, `walk`, `sprint`, `jump`, `fall`, `crouch`, `interact-right`, `pick-up`, `die`) dan satu lengan kanan pemegang senter di sudut kanan bawah.
  - Menyempurnakan desain kiri atas dengan **Jam sebagai Title (`28px`)**, **Babak sebagai H1 (`19px`)**, dan **garis pemisah horizontal (`HSeparator`)** merah horor menuju daftar misi (`◆`).
  - Mengembalikan angka persentase pada indikator **Waras**, **Stamina**, dan **Senter**, menambahkan bingkai tipis bernuansa horor pada progress bar, serta mengubah kelima slot hotbar menjadi **kotak persegi 1:1 (`76x76` desktop / `58x58` mobile)** dengan border merah-emas pada slot aktif.
- **Kamera FPP Penuh, Model Manusia Berjas, Item Ritual Babak II, Optimasi Low, & UI Minimalis**:
  - Mempertahankan sudut pandang First-Person Perspective (FPP) penuh dengan tampilan lengan kanan berjas yang memegang senter serta animasi tubuh saat bergerak, berinteraksi, bersembunyi, dan cutscene.
  - Menggunakan model karakter manusia Kenney CC0 (`character-suit.glb`) dengan setelan jas formal hitam, kemeja putih, dasi merah, dan manset putih yang ikut bergerak mengikuti animasi tulang `Skeleton3D`.
  - Memastikan 4 Benda Ritual baru muncul dan aktif saat Babak II dimulai (tersembunyi dan tidak dapat diinteraksi selama Babak I).
  - Mengoptimalkan preset grafis `Low` dengan menonaktifkan shader post-process layar penuh, shadow lampu utama/senter, lampu dinamis item pickup di tanah, dan kabut berat serta memangkas jarak render kamera (`far = 70.0`).
  - Menyederhanakan HUD agar jauh lebih bersih dan tidak ramai: menghapus kotak petunjuk desktop permanen, tombol melayang tas, bar kebisingan, angka persentase redundan, serta merampingkan daftar misi, bar status, hotbar, dan banner pergantian babak (`2.4` detik).
- **Tipografi Horor untuk Judul & Antarmuka Bersih Tanpa Emoji**:
  - Menerapkan font horor *Nosifer* (`assets/fonts/HorrorTitle.ttf`) pada seluruh judul (`Title`) di Menu Utama, HUD (judul babak, judul cutscene, judul kartu misi, judul jeda, judul inventori, peringatan tatapan), layar Game Over, dan layar Victory.
  - Menghapus penggunaan emoji berlebihan di tombol, prompt interaksi, daftar objektif, serta status HUD dan menggantinya dengan teks bersih agar nuansa horor lebih serius.
- **Perbaikan Misi Babak, Cutscene Bebas Pop-Up, UI Transparan, & Model 3D Player Beranimasi**:
  - Memperbaiki pop-up kartu babak (`MissionCard`) agar tidak muncul menutupi cutscene saat Lampor turun ke desa, serta menghapus kotak bar hitam pada overlay cutscene agar tampilan lebih bersih.
  - Mengembalikan pengelompokan misi per babak (Babak I hanya menampilkan 2 misi awal, Babak II misi ritual, Babak III klimaks pembakaran) serta mengunci pengambilan Benda Ritual selama masih di Babak I sehingga permainan tidak langsung melompat dari Babak I ke Babak III.
  - Menghapus seluruh background panel dan border pada UI permainan (kecuali hotbar dan inventori), termasuk panel status kiri bawah/kanan atas, kartu misi tengah, petunjuk kontrol desktop, garis pemisah misi, dan bingkai progress bar.
  - Menambahkan model karakter 3D CC0 dari Kenney.nl (`character-keeper.glb`) untuk Player lengkap dengan animasi otomatis (`idle`, `walk`, `sprint`, `jump`, `fall`, `crouch`, `interact-right`, `pick-up`, `die`) serta dukungan kamera Third-Person & First-Person (`[V]`).
- **Cutscene Sinematik Lampor Turun & Langsung Mengejar (3.8 Detik)**:
  - Menambahkan cutscene sinematik berdurasi **3.8 detik** saat Babak II dimulai ketika keranda hijau Lampor turun dari langit ke jalan desa di sekitar pemain.
  - Kamera cutscene mengikuti posisi keranda hijau Lampor secara dinamis di setiap frame lengkap dengan bar letterbox, cahaya sinematik, dan suara gemuruh/lonceng tanpa tertutup kartu misi.
  - Tepat saat cutscene berakhir, kendali kembali ke pemain dan Lampor langsung mengejar pemain (`State.CHASE`).
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
- **Perbaikan Nama Item Hotbar, Misi Lengkap (5 Misi), & Tampilan Transparan**:
  - Memperbaiki bug nama item di hotbar yang hilang akibat pengaturan pemotongan teks pada label di dalam `VBoxContainer`.
  - Menghilangkan background dan border pada daftar misi di kiri atas serta pada teks dialog narasi di bawah agar tampilan HUD lebih bersih.
  - Menampilkan seluruh **5 misi utama** sejak awal permainan di kiri atas (termasuk 3 misi lanjutan: mengumpulkan 4 benda ritual, membakar benda ritual di tungku balai desa, dan bertahan hidup hingga ritual selesai beserta hitungan detik langsung).
- **Tata Letak UI Mobile Lebih Rapi & Anti-Berdempetan**:
  - Menata ulang posisi panel status (`Waras`, `Stamina`, `Senter`) di sudut kanan atas dan memindahkan tombol `Ⅱ` (Jeda) serta `TAS` ke sisi kiri panel status agar tidak saling bertabrakan.
  - Mengatur pembungkus teks nama item slot hotbar (`autowrap_mode`) dengan ukuran minimum tetap agar nama item tetap tampil utuh dan hotbar tidak bertabrakan dengan joystick maupun tombol aksi kanan.
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
