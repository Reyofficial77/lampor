extends Node

signal update_available(commit_sha: String, commit_message: String)
signal update_installed(destination_path: String, commit_sha: String, applied_to_project: bool)
signal update_failed(message: String)
signal up_to_date(commit_sha: String)
signal fix_notes_updated(markdown: String, commit_sha: String)

const FULL_TREE_SYNC_VERSION: int = 1
const BUILD_COMMIT: String = "f3c66618e258b94072464dafee9d088c0afaf814"
const API_URL: String = "https://api.github.com/repos/Reyofficial77/lampor/commits/main"
const ATOM_URL: String = "https://github.com/Reyofficial77/lampor/commits/main.atom"
const ARCHIVE_URL: String = "https://codeload.github.com/Reyofficial77/lampor/zip/"
const RAW_FIX_NOTES_BASE_URL: String = "https://raw.githubusercontent.com/Reyofficial77/lampor/"
const UPDATE_CONFIG_PATH: String = "user://lampor_update.cfg"
const UPDATE_ROOT: String = "user://updates"
const FIX_NOTES_CACHE_PATH: String = "user://lampor_fix_notes.md"
const REQUIRED_UPDATE_FILES: PackedStringArray = ["project.godot", "scripts/autoload/UpdateManager.gd", "FIX_NOTES.md"]

const BUNDLED_FIX_NOTES: String = """# LAMPOR v1.2.3

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
- Setelah pembaruan selesai diterapkan, permainan meminta konfirmasi untuk memulai ulang sesi."""

var latest_commit: String = ""
var latest_message: String = ""
var installed_commit: String = BUILD_COMMIT
var remote_fix_notes_markdown: String = ""
var remote_fix_notes_commit: String = ""
var is_fetching_fix_notes: bool = false
var fix_notes_using_main_fallback: bool = false
var has_update: bool = false
var is_checking: bool = false
var is_downloading: bool = false
var using_atom_fallback: bool = false
var downloaded_path: String = ""
var last_error: String = ""
var api_request: HTTPRequest
var fallback_request: HTTPRequest
var download_request: HTTPRequest
var fix_notes_request: HTTPRequest

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	api_request = HTTPRequest.new()
	api_request.timeout = 45.0
	api_request.max_redirects = 12
	api_request.use_threads = true
	add_child(api_request)
	api_request.request_completed.connect(_on_api_request_completed)
	fallback_request = HTTPRequest.new()
	fallback_request.timeout = 45.0
	fallback_request.max_redirects = 12
	fallback_request.use_threads = true
	add_child(fallback_request)
	fallback_request.request_completed.connect(_on_atom_request_completed)
	download_request = HTTPRequest.new()
	download_request.timeout = 300.0
	download_request.max_redirects = 12
	download_request.use_threads = true
	add_child(download_request)
	download_request.request_completed.connect(_on_download_request_completed)
	fix_notes_request = HTTPRequest.new()
	fix_notes_request.timeout = 35.0
	fix_notes_request.max_redirects = 12
	fix_notes_request.use_threads = true
	add_child(fix_notes_request)
	fix_notes_request.request_completed.connect(_on_fix_notes_request_completed)
	_load_update_state()
	call_deferred("fetch_latest_fix_notes")

func _load_update_state() -> void:
	var config := ConfigFile.new()
	if config.load(UPDATE_CONFIG_PATH) == OK:
		installed_commit = str(config.get_value("update", "installed_commit", config.get_value("update", "processed_commit", BUILD_COMMIT)))
		remote_fix_notes_commit = str(config.get_value("update", "fix_notes_commit", ""))
	if FileAccess.file_exists(FIX_NOTES_CACHE_PATH):
		var cached_md: String = FileAccess.get_file_as_string(FIX_NOTES_CACHE_PATH)
		if not cached_md.strip_edges().is_empty():
			remote_fix_notes_markdown = cached_md

func _save_update_state() -> void:
	var config := ConfigFile.new()
	config.set_value("update", "installed_commit", installed_commit)
	config.set_value("update", "fix_notes_commit", remote_fix_notes_commit)
	config.save(UPDATE_CONFIG_PATH)

func check_for_updates(force: bool = false) -> void:
	if is_checking or is_downloading:
		return
	if not force and not has_update and not installed_commit.is_empty():
		return
	is_checking = true
	using_atom_fallback = false
	last_error = ""
	latest_commit = ""
	latest_message = ""
	var headers: PackedStringArray = ["User-Agent: Lampor-Game", "Accept: application/vnd.github+json", "X-GitHub-Api-Version: 2022-11-28"]
	var request_error: Error = api_request.request(API_URL, headers)
	if request_error != OK:
		_request_atom_fallback(HTTPRequest.RESULT_CANT_CONNECT)

func _request_atom_fallback(previous_result: int) -> void:
	using_atom_fallback = true
	var headers: PackedStringArray = ["User-Agent: Lampor-Game", "Accept: application/atom+xml"]
	var request_error: Error = fallback_request.request(ATOM_URL, headers)
	if request_error != OK:
		using_atom_fallback = false
		is_checking = false
		_fail(_format_network_error(previous_result, 0, "GitHub API dan jalur alternatif"))

func download_update() -> void:
	if is_downloading:
		return
	if latest_commit.is_empty():
		check_for_updates(true)
		return
	if not _can_write_project_source():
		_fail("Pemasangan sinkronisasi source hanya dapat dilakukan pada folder proyek Godot yang dapat ditulis. APK Android/EXE hasil ekspor tidak dapat mengubah isi APK/PCK yang sedang berjalan; jangan menandai update sebagai berhasil.")
		return
	if is_update_processed():
		up_to_date.emit(latest_commit)
		return
	var update_dir: String = ProjectSettings.globalize_path(UPDATE_ROOT)
	var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(update_dir)
	if make_dir_error != OK and make_dir_error != ERR_ALREADY_EXISTS:
		_fail("Folder sementara update tidak dapat dibuat (kode %d)." % make_dir_error)
		return
	downloaded_path = update_dir.path_join("lampor-%s.zip" % latest_commit.substr(0, 10))
	if FileAccess.file_exists(downloaded_path):
		DirAccess.remove_absolute(downloaded_path)
	download_request.download_file = downloaded_path
	var headers: PackedStringArray = ["User-Agent: Lampor-Game", "Accept: application/zip"]
	var request_error: Error = download_request.request(ARCHIVE_URL + latest_commit, headers)
	if request_error != OK:
		download_request.download_file = ""
		_fail("Tidak dapat memulai unduhan update (kode %d)." % request_error)
		return
	is_downloading = true

func _on_api_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_request_atom_fallback(result)
		return
	is_checking = false
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		_fail("Respons GitHub tidak valid (JSON tidak dapat dibaca).")
		return
	var commit_sha: String = str(parsed.get("sha", ""))
	var commit_data: Dictionary = parsed.get("commit", {})
	var commit_message: String = str(commit_data.get("message", "Pembaruan Lampor"))
	_handle_latest_commit(commit_sha, commit_message)

func _on_atom_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	using_atom_fallback = false
	is_checking = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_fail(_format_network_error(result, response_code, "jalur alternatif GitHub (Atom)"))
		return
	_parse_atom_response(body)

func _parse_atom_response(body: PackedByteArray) -> void:
	var feed_text: String = body.get_string_from_utf8()
	var sha_regex := RegEx.new()
	if sha_regex.compile("<id>[^<]*([0-9a-f]{40})</id>") != OK:
		_fail("Parser cadangan GitHub gagal disiapkan.")
		return
	var matches: Array[RegExMatch] = sha_regex.search_all(feed_text)
	if matches.is_empty():
		_fail("GitHub merespons, tetapi commit terbaru tidak ditemukan pada feed cadangan.")
		return
	var message: String = "Commit terbaru dari GitHub"
	var title_regex := RegEx.new()
	if title_regex.compile("(?s)<entry>.*?<title>(.*?)</title>") == OK:
		var title_match: RegExMatch = title_regex.search(feed_text)
		if title_match:
			message = title_match.get_string(1).strip_edges()
	_handle_latest_commit(matches[0].get_string(1), message)

func _handle_latest_commit(commit_sha: String, commit_message: String) -> void:
	latest_commit = commit_sha.strip_edges()
	latest_message = commit_message
	if latest_commit.is_empty():
		_fail("GitHub tidak mengembalikan identitas commit.")
		return
	# Selalu ambil FIX_NOTES.md dari commit terbaru agar APK/EXE juga menampilkan catatan commit terbaru.
	fetch_latest_fix_notes(true)
	has_update = latest_commit != installed_commit
	if has_update:
		update_available.emit(latest_commit, latest_message)
		if SettingsManager.auto_update and not _is_git_working_copy():
			download_update()
	else:
		up_to_date.emit(latest_commit)

func _is_git_working_copy() -> bool:
	if OS.has_feature("editor"):
		return true
	var root: String = ProjectSettings.globalize_path("res://")
	return DirAccess.dir_exists_absolute(root.path_join(".git"))

func fetch_latest_fix_notes(force: bool = false) -> void:
	if is_fetching_fix_notes or fix_notes_request == null:
		return
	var target_ref: String = latest_commit if not latest_commit.is_empty() else "main"
	if not force and not remote_fix_notes_markdown.is_empty() and remote_fix_notes_commit == target_ref:
		return
	is_fetching_fix_notes = true
	fix_notes_using_main_fallback = (target_ref == "main")
	var url: String = "%s%s/FIX_NOTES.md?t=%d" % [RAW_FIX_NOTES_BASE_URL, target_ref, int(Time.get_unix_time_from_system())]
	var headers: PackedStringArray = ["User-Agent: Lampor-Game", "Cache-Control: no-cache"]
	var err: Error = fix_notes_request.request(url, headers)
	if err != OK:
		is_fetching_fix_notes = false

func _on_fix_notes_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_fetching_fix_notes = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		if not fix_notes_using_main_fallback:
			fix_notes_using_main_fallback = true
			is_fetching_fix_notes = true
			var fallback_url: String = "%smain/FIX_NOTES.md?t=%d" % [RAW_FIX_NOTES_BASE_URL, int(Time.get_unix_time_from_system())]
			var headers: PackedStringArray = ["User-Agent: Lampor-Game", "Cache-Control: no-cache"]
			if fix_notes_request.request(fallback_url, headers) != OK:
				is_fetching_fix_notes = false
		return
	var text: String = body.get_string_from_utf8()
	if text.strip_edges().is_empty():
		return
	remote_fix_notes_markdown = text
	remote_fix_notes_commit = latest_commit if not latest_commit.is_empty() else "main"
	_write_absolute_file(ProjectSettings.globalize_path(FIX_NOTES_CACHE_PATH), text.to_utf8_buffer())
	_save_update_state()
	fix_notes_updated.emit(remote_fix_notes_markdown, remote_fix_notes_commit)

func _on_download_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	is_downloading = false
	download_request.download_file = ""
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200 or not FileAccess.file_exists(downloaded_path):
		if FileAccess.file_exists(downloaded_path):
			DirAccess.remove_absolute(downloaded_path)
		_fail(_format_network_error(result, response_code, "unduhan paket update"))
		return
	var archive_bytes: PackedByteArray = FileAccess.get_file_as_bytes(downloaded_path)
	if archive_bytes.size() < 4 or archive_bytes[0] != 0x50 or archive_bytes[1] != 0x4B:
		DirAccess.remove_absolute(downloaded_path)
		_fail("Server tidak mengirim arsip ZIP yang valid. Update dibatalkan.")
		return
	_install_update_archive()

func _install_update_archive() -> void:
	var staging_path: String = UPDATE_ROOT.path_join("staging-%s" % latest_commit.substr(0, 10))
	var staging_absolute: String = ProjectSettings.globalize_path(staging_path)
	_remove_directory_recursive(staging_absolute)
	var extract_result: Error = _extract_zip_safely(downloaded_path, staging_absolute)
	if extract_result != OK:
		_remove_directory_recursive(staging_absolute)
		_fail("Paket update tidak dapat diekstrak dengan aman (kode %d). Arsip proyek tidak diubah." % extract_result)
		return
	for required_path in REQUIRED_UPDATE_FILES:
		if not FileAccess.file_exists(staging_absolute.path_join(required_path)):
			_remove_directory_recursive(staging_absolute)
			_fail("Update ditolak: file wajib %s tidak ada di commit GitHub. Tambahkan FIX_NOTES.md dan updater sinkronisasi penuh ke branch main sebelum update dapat diterapkan." % required_path)
			return
	var staged_updater: String = FileAccess.get_file_as_string(staging_absolute.path_join("scripts/autoload/UpdateManager.gd"))
	if not staged_updater.contains("const FULL_TREE_SYNC_VERSION: int = 1") or not staged_updater.contains("func _apply_staged_project"):
		_remove_directory_recursive(staging_absolute)
		_fail("Update ditolak untuk mencegah updater rusak: branch main masih berisi updater versi lama. Commit UpdateManager.gd versi full-sync ini ke repository terlebih dahulu.")
		return
	var notes_text: String = FileAccess.get_file_as_string(staging_absolute.path_join("FIX_NOTES.md"))
	if notes_text.strip_edges().is_empty():
		_remove_directory_recursive(staging_absolute)
		_fail("Update ditolak: FIX_NOTES.md kosong. Setiap commit update wajib menyertakan catatan perubahan Markdown.")
		return
	var project_root: String = ProjectSettings.globalize_path("res://")
	if not _apply_staged_project(staging_absolute, project_root):
		_remove_directory_recursive(staging_absolute)
		return
	# Cache is outside the project tree so the repo mirror remains exact.
	_write_absolute_file(ProjectSettings.globalize_path(FIX_NOTES_CACHE_PATH), notes_text.to_utf8_buffer())
	_remove_directory_recursive(staging_absolute)
	if FileAccess.file_exists(downloaded_path):
		DirAccess.remove_absolute(downloaded_path)
	downloaded_path = ""
	installed_commit = latest_commit
	_save_update_state()
	has_update = false
	update_installed.emit(project_root, latest_commit, true)

func _extract_zip_safely(archive_path: String, destination_root: String) -> Error:
	var reader := ZIPReader.new()
	var open_error: Error = reader.open(archive_path)
	if open_error != OK:
		return open_error
	var entries: PackedStringArray = reader.get_files()
	var archive_prefix: String = ""
	for entry in entries:
		if entry.ends_with("/"):
			continue
		var parts: PackedStringArray = entry.split("/", false)
		if parts.size() > 1:
			archive_prefix = parts[0] + "/"
			break
	var found_manifest: bool = false
	var write_error: Error = DirAccess.make_dir_recursive_absolute(destination_root)
	if write_error != OK and write_error != ERR_ALREADY_EXISTS:
		reader.close()
		return write_error
	for entry in entries:
		var relative_path: String = entry
		if not archive_prefix.is_empty() and relative_path.begins_with(archive_prefix):
			relative_path = relative_path.substr(archive_prefix.length())
		if relative_path.is_empty():
			continue
		if relative_path.contains("\\") or relative_path.contains(":") or relative_path.begins_with("/"):
			write_error = ERR_INVALID_DATA
			break
		var segments: PackedStringArray = relative_path.split("/", false)
		if segments.has("..") or segments.has(".") or segments.has(""):
			write_error = ERR_INVALID_DATA
			break
		if segments.has(".git") or segments.has(".godot"):
			continue
		var target_path: String = destination_root.path_join(relative_path.trim_suffix("/"))
		if entry.ends_with("/"):
			var dir_error: Error = DirAccess.make_dir_recursive_absolute(target_path)
			if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
				write_error = dir_error
				break
			continue
		var bytes: PackedByteArray = reader.read_file(entry)
		if relative_path == "project.godot":
			found_manifest = true
		var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(target_path.get_base_dir())
		if make_dir_error != OK and make_dir_error != ERR_ALREADY_EXISTS:
			write_error = make_dir_error
			break
		var file := FileAccess.open(target_path, FileAccess.WRITE)
		if file == null:
			write_error = FileAccess.get_open_error()
			break
		file.store_buffer(bytes)
		var file_error: Error = file.get_error()
		file.close()
		if file_error != OK:
			write_error = file_error
			break
	reader.close()
	if write_error != OK:
		return write_error
	if not found_manifest:
		return ERR_FILE_NOT_FOUND
	return OK

func _can_write_project_source() -> bool:
	var root: String = ProjectSettings.globalize_path("res://")
	if not FileAccess.file_exists(root.path_join("project.godot")) or not DirAccess.dir_exists_absolute(root.path_join("scripts")):
		return false
	var probe_path: String = root.path_join(".lampor_update_write_test")
	var probe := FileAccess.open(probe_path, FileAccess.WRITE)
	if probe == null:
		return false
	probe.close()
	DirAccess.remove_absolute(probe_path)
	return true

func is_update_processed() -> bool:
	return not latest_commit.is_empty() and installed_commit == latest_commit

func _apply_staged_project(staging_root: String, project_root: String) -> bool:
	var incoming_files: Array[String] = []
	var original_files: Array[String] = []
	_collect_files_recursive(staging_root, "", incoming_files)
	_collect_files_recursive(project_root, "", original_files)
	incoming_files.sort()
	original_files.sort()
	var backup_root: String = OS.get_user_data_dir().path_join("updates/backups/%s" % latest_commit)
	_remove_directory_recursive(backup_root)
	for relative_path in original_files:
		var old_bytes: PackedByteArray = FileAccess.get_file_as_bytes(project_root.path_join(relative_path))
		if not _write_absolute_file(backup_root.path_join(relative_path), old_bytes):
			_fail("Backup gagal dibuat untuk %s. Tidak ada file proyek yang diubah." % relative_path)
			return false
	# Hapus seluruh file proyek lama kecuali isi .git dan .godot.
	for relative_path in original_files:
		var delete_error: Error = DirAccess.remove_absolute(project_root.path_join(relative_path))
		if delete_error != OK and delete_error != ERR_DOES_NOT_EXIST:
			_rollback_project(project_root, backup_root, original_files)
			_fail("Tidak dapat menghapus file lama %s (kode %d). Proyek dipulihkan dari backup." % [relative_path, delete_error])
			return false
	_remove_empty_directories_recursive(project_root)
	# Salin seluruh tree dari commit. Ini sekaligus menambahkan, mengubah, dan menyelaraskan file.
	for relative_path in incoming_files:
		var source_path: String = staging_root.path_join(relative_path)
		var target_path: String = project_root.path_join(relative_path)
		if not _write_absolute_file(target_path, FileAccess.get_file_as_bytes(source_path)):
			_rollback_project(project_root, backup_root, original_files)
			_fail("Gagal memasang %s. Semua file lama dipulihkan dari backup." % relative_path)
			return false
	return true

func _rollback_project(project_root: String, backup_root: String, original_files: Array[String]) -> void:
	var current_files: Array[String] = []
	_collect_files_recursive(project_root, "", current_files)
	for relative_path in current_files:
		DirAccess.remove_absolute(project_root.path_join(relative_path))
	_remove_empty_directories_recursive(project_root)
	for relative_path in original_files:
		var backup_path: String = backup_root.path_join(relative_path)
		if FileAccess.file_exists(backup_path):
			_write_absolute_file(project_root.path_join(relative_path), FileAccess.get_file_as_bytes(backup_path))

func _collect_files_recursive(directory_path: String, relative_prefix: String, output: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.include_hidden = true
	for file_name in directory.get_files():
		var relative_file: String = relative_prefix.path_join(file_name) if not relative_prefix.is_empty() else file_name
		var segments: PackedStringArray = relative_file.split("/", false)
		if segments.has(".git") or segments.has(".godot"):
			continue
		output.append(relative_file)
	for directory_name in directory.get_directories():
		if directory_name in [".git", ".godot"]:
			continue
		var child_relative: String = relative_prefix.path_join(directory_name) if not relative_prefix.is_empty() else directory_name
		_collect_files_recursive(directory_path.path_join(directory_name), child_relative, output)

func _remove_empty_directories_recursive(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.include_hidden = true
	for directory_name in directory.get_directories():
		if directory_name in [".git", ".godot"]:
			continue
		var child_path: String = directory_path.path_join(directory_name)
		_remove_empty_directories_recursive(child_path)
		var child := DirAccess.open(child_path)
		if child != null and child.get_files().is_empty() and child.get_directories().is_empty():
			DirAccess.remove_absolute(child_path)

func _write_absolute_file(path: String, bytes: PackedByteArray) -> bool:
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	var write_error: Error = file.get_error()
	file.close()
	return write_error == OK

func _remove_directory_recursive(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.include_hidden = true
	for file_name in directory.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	for directory_name in directory.get_directories():
		_remove_directory_recursive(path.path_join(directory_name))
	DirAccess.remove_absolute(path)

func get_fix_notes_markdown() -> String:
	# 1. Jika sedang di Editor / folder proyek lokal dan belum ada commit remote yang lebih baru,
	#    atau file lokal res://FIX_NOTES.md baru saja diedit lebih panjang dari cache remote:
	var local_notes: String = ""
	if FileAccess.file_exists("res://FIX_NOTES.md"):
		local_notes = FileAccess.get_file_as_string("res://FIX_NOTES.md")
	var cached_notes: String = ""
	if FileAccess.file_exists(FIX_NOTES_CACHE_PATH):
		cached_notes = FileAccess.get_file_as_string(FIX_NOTES_CACHE_PATH)

	# Pada APK/EXE hasil export, utamakan FIX_NOTES.md yang berhasil diunduh dari commit terbaru GitHub
	if not _can_write_project_source():
		if not remote_fix_notes_markdown.strip_edges().is_empty():
			return remote_fix_notes_markdown
		if not cached_notes.strip_edges().is_empty():
			return cached_notes
		if not local_notes.strip_edges().is_empty():
			return local_notes
		return BUNDLED_FIX_NOTES

	# Pada Editor / proyek lokal yang dapat ditulis:
	if not local_notes.strip_edges().is_empty():
		if not remote_fix_notes_markdown.strip_edges().is_empty() and has_update:
			return remote_fix_notes_markdown
		return local_notes
	if not remote_fix_notes_markdown.strip_edges().is_empty():
		return remote_fix_notes_markdown
	if not cached_notes.strip_edges().is_empty():
		return cached_notes
	return BUNDLED_FIX_NOTES

func _format_network_error(result: int, response_code: int, service: String) -> String:
	var detail: String = ""
	match result:
		HTTPRequest.RESULT_SUCCESS:
			detail = "Permintaan selesai, tetapi server mengembalikan HTTP %d." % response_code
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
			detail = "Transfer respons terpotong atau ukuran data tidak cocok."
		HTTPRequest.RESULT_CANT_CONNECT:
			detail = "Tidak dapat terhubung ke server (periksa internet, firewall, atau proxy)."
		HTTPRequest.RESULT_CANT_RESOLVE:
			detail = "Alamat server tidak dapat ditemukan oleh DNS."
		HTTPRequest.RESULT_CONNECTION_ERROR:
			detail = "Koneksi terputus sebelum transfer selesai."
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			detail = "Negosiasi TLS/sertifikat HTTPS gagal. Periksa tanggal perangkat dan sertifikat sistem."
		HTTPRequest.RESULT_NO_RESPONSE:
			detail = "Server tidak memberikan respons."
		HTTPRequest.RESULT_TIMEOUT:
			detail = "Koneksi melewati batas waktu."
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			detail = "Ukuran respons melebihi batas HTTPRequest."
		HTTPRequest.RESULT_REQUEST_FAILED:
			detail = "Permintaan jaringan gagal diproses oleh HTTPRequest."
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED:
			detail = "Respons server gagal dibuka/dekompresi."
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
			detail = "File sementara unduhan tidak dapat dibuka. Periksa ruang penyimpanan."
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			detail = "File unduhan gagal ditulis. Periksa ruang penyimpanan."
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			detail = "Server terlalu banyak mengalihkan permintaan."
		_:
			detail = "Kesalahan transport jaringan (kode %d)." % result
	var message: String = "%s gagal. %s" % [service, detail]
	if response_code == 0:
		message += " HTTP 0 bukan status GitHub; koneksi gagal sebelum menerima header HTTP."
	if OS.has_feature("android"):
		message += " Pastikan permission INTERNET aktif pada Android Export Preset."
	return message

func _fail(message: String) -> void:
	is_checking = false
	is_downloading = false
	using_atom_fallback = false
	if download_request:
		download_request.download_file = ""
	last_error = message
	update_failed.emit(message)
