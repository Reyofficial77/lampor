class_name MainMenu
extends Control

const GAME_VERSION: String = "v1.2.5"
const HORROR_TITLE_FONT: Font = preload("res://assets/fonts/HorrorTitle.ttf")
const ACCENT: Color = Color(0.76, 0.10, 0.12, 1.0)
const ACCENT_GOLD: Color = Color(0.84, 0.68, 0.34, 1.0)
const TEXT_MAIN: Color = Color(0.94, 0.90, 0.85, 1.0)
const TEXT_MUTED: Color = Color(0.68, 0.60, 0.58, 1.0)

var horror_backdrop: Control
var menu_anim_time: float = 0.0
var main_center: CenterContainer
var main_card: PanelContainer
var main_card_margin: MarginContainer
var main_content: VBoxContainer
var ritual_header_label: Label
var title_label: Label
var subtitle_label: Label
var version_label: Label
var copyright_label: Label
var exit_button: Button
var continue_button: Button
var modal_overlays: Array[ColorRect] = []
var modal_panels: Array[PanelContainer] = []
var difficulty_buttons: Array[Button] = []
var warning_overlay: ColorRect
var difficulty_overlay: ColorRect
var settings_overlay: ColorRect
var credits_overlay: ColorRect
var shop_overlay: ColorRect
var currency_label: Label
var shop_balance_label: Label
var shop_result_label: Label
var redeem_input: LineEdit
var redeem_result_label: Label
var auto_update_check: CheckButton
var update_button: Button
var update_check_button: Button
var update_status_label: Label
var fix_notes_button: Button
var fix_notes_overlay: ColorRect
var fix_notes_panel: PanelContainer
var fix_notes_scroll: ScrollContainer
var fix_notes_view: RichTextLabel
var fix_notes_more_label: Label
var fix_notes_hint_label: Label
var fix_notes_sections: Array[String] = []
var fix_notes_loaded_sections: int = 0
var fix_notes_rendered_markdown: String = ""
var _active_drag_scroll: ScrollContainer = null
var _drag_start_y: float = 0.0
var _drag_last_y: float = 0.0
var _drag_moved: bool = false
var _drag_pressed_button: BaseButton = null
var _rx_table_sep: RegEx
var _rx_numbered: RegEx
var _rx_inline_code: RegEx
var _rx_links: RegEx
var _rx_bold: RegEx
var _rx_strike: RegEx
var _rx_italic: RegEx
var update_restart_overlay: ColorRect
var update_restart_status: Label
var nightmare_button: Button
var nightmare_lock_label: Label
var volume_slider: HSlider
var fullscreen_button: Button
var settings_scroll: ScrollContainer
var shop_scroll: ScrollContainer
var mouse_sensitivity_slider: HSlider
var camera_sensitivity_slider: HSlider
var brightness_slider: HSlider
var mouse_sensitivity_value: Label
var camera_sensitivity_value: Label
var brightness_value: Label
var volume_value: Label
var graphics_option: OptionButton

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.current_state = GameManager.GameState.MENU
	_build_menu()
	UpdateManager.update_available.connect(_on_update_available)
	UpdateManager.update_installed.connect(_on_update_installed)
	UpdateManager.update_failed.connect(_on_update_failed)
	UpdateManager.up_to_date.connect(_on_update_up_to_date)
	UpdateManager.fix_notes_updated.connect(_on_fix_notes_updated)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	call_deferred("_check_for_game_updates")

func _process(delta: float) -> void:
	menu_anim_time += delta
	if horror_backdrop:
		horror_backdrop.queue_redraw()
	if title_label:
		var pulse: float = 0.5 + 0.5 * sin(menu_anim_time * 2.2)
		var flicker: float = 0.92 if sin(menu_anim_time * 17.0) > -0.85 else 0.72
		title_label.modulate = Color(1.0, lerpf(0.88, 1.0, pulse) * flicker, lerpf(0.88, 1.0, pulse) * flicker, 1.0)

func _build_menu() -> void:
	var background := ColorRect.new()
	background.color = Color(0.012, 0.008, 0.014, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	horror_backdrop = Control.new()
	horror_backdrop.name = "HorrorBackdrop"
	horror_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	horror_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	horror_backdrop.draw.connect(_draw_horror_backdrop)
	add_child(horror_backdrop)

	var top_glow := ColorRect.new()
	top_glow.color = Color(0.45, 0.04, 0.06, 0.55)
	top_glow.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_glow.offset_bottom = 3.0
	top_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_glow)

	var bottom_glow := ColorRect.new()
	bottom_glow.color = Color(0.32, 0.03, 0.05, 0.45)
	bottom_glow.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_glow.offset_top = -2.0
	bottom_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_glow)

	main_center = CenterContainer.new()
	main_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(main_center)

	main_card = PanelContainer.new()
	main_card.name = "MainHorrorCard"
	var card_style := _panel_style()
	card_style.bg_color = Color(0.022, 0.012, 0.016, 0.86)
	card_style.border_color = Color(0.52, 0.10, 0.12, 0.92)
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 3
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.78)
	card_style.shadow_size = 16
	main_card.add_theme_stylebox_override("panel", card_style)
	main_center.add_child(main_card)

	main_card_margin = MarginContainer.new()
	main_card_margin.add_theme_constant_override("margin_left", 24)
	main_card_margin.add_theme_constant_override("margin_right", 24)
	main_card_margin.add_theme_constant_override("margin_top", 18)
	main_card_margin.add_theme_constant_override("margin_bottom", 18)
	main_card.add_child(main_card_margin)

	main_content = VBoxContainer.new()
	main_content.alignment = BoxContainer.ALIGNMENT_CENTER
	main_content.add_theme_constant_override("separation", 10)
	main_content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_card_margin.add_child(main_content)

	ritual_header_label = _make_label("KUTUKAN DESA TERKUTUK", 11, Color(0.76, 0.24, 0.24, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
	main_content.add_child(ritual_header_label)

	title_label = _make_label("LAMPOR", 46, Color(0.86, 0.12, 0.14, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	title_label.add_theme_font_override("font", HORROR_TITLE_FONT)
	title_label.add_theme_constant_override("outline_size", 12)
	title_label.add_theme_color_override("font_outline_color", Color(0.03, 0.0, 0.0, 1.0))
	main_content.add_child(title_label)

	subtitle_label = _make_label("MALAM JAHANAM\n\"Jangan menatap keranda hijau yang melintas di balik kabut.\"", 15, TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	main_content.add_child(subtitle_label)

	var divider := HSeparator.new()
	var div_style := StyleBoxFlat.new()
	div_style.bg_color = Color(0.46, 0.10, 0.12, 0.75)
	div_style.content_margin_top = 1
	div_style.content_margin_bottom = 1
	divider.add_theme_stylebox_override("separator", div_style)
	main_content.add_child(divider)

	var wins_label := _make_label("", 13, Color(0.84, 0.68, 0.36, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	wins_label.name = "WinsLabel"
	wins_label.text = "Malam Terlewati: %d Kemenangan" % GameManager.total_wins
	main_content.add_child(wins_label)
	currency_label = _make_label("Koin Emas: %d   ·   Nyawa Cadangan: %d" % [GameManager.coins, GameManager.extra_lives], 13, Color(0.92, 0.76, 0.42, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	currency_label.name = "CurrencyLabel"
	main_content.add_child(currency_label)

	var menu_buttons := VBoxContainer.new()
	menu_buttons.name = "MenuButtons"
	menu_buttons.add_theme_constant_override("separation", 8)
	main_content.add_child(menu_buttons)
	continue_button = _make_button("LANJUTKAN MALAM TERSIMPAN", true)
	continue_button.visible = GameManager.has_saved_run()
	continue_button.pressed.connect(_on_continue_pressed)
	menu_buttons.add_child(continue_button)
	var start_button := _make_button("MULAI PERMAINAN", true)
	start_button.pressed.connect(func() -> void: warning_overlay.visible = true)
	menu_buttons.add_child(start_button)
	var shop_button := _make_button("TOKO BEKAL RITUAL")
	shop_button.pressed.connect(func() -> void:
		_refresh_shop_display()
		shop_overlay.visible = true
	)
	menu_buttons.add_child(shop_button)
	var settings_button := _make_button("PENGATURAN & PANDUAN")
	settings_button.pressed.connect(func() -> void: settings_overlay.visible = true)
	menu_buttons.add_child(settings_button)
	fix_notes_button = _make_button("CATATAN PEMBARUAN")
	fix_notes_button.pressed.connect(_show_fix_notes)
	menu_buttons.add_child(fix_notes_button)
	var credits_button := _make_button("HAK CIPTA")
	credits_button.pressed.connect(func() -> void: credits_overlay.visible = true)
	menu_buttons.add_child(credits_button)

	update_button = _make_button("UPDATE TERSEDIA", true)
	update_button.visible = false
	update_button.custom_minimum_size = Vector2(190.0, 40.0)
	update_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	update_button.offset_left = 18.0
	update_button.offset_top = 16.0
	update_button.offset_right = 210.0
	update_button.offset_bottom = 58.0
	update_button.add_theme_font_size_override("font_size", 12)
	update_button.pressed.connect(_on_update_button_pressed)
	add_child(update_button)

	version_label = _make_label(GAME_VERSION, 13, TEXT_MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	version_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	version_label.offset_left = -120
	version_label.offset_top = 20
	version_label.offset_right = -24
	version_label.offset_bottom = 46
	add_child(version_label)

	copyright_label = _make_label("© 2026 AstraDev. All rights reserved.", 12, TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	copyright_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	copyright_label.offset_left = 24
	copyright_label.offset_top = -42
	copyright_label.offset_right = 360
	copyright_label.offset_bottom = -18
	add_child(copyright_label)

	exit_button = _make_button("KELUAR PERMAINAN")
	exit_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	exit_button.offset_left = -190
	exit_button.offset_top = -62
	exit_button.offset_right = -24
	exit_button.offset_bottom = -18
	exit_button.custom_minimum_size = Vector2(166, 44)
	exit_button.pressed.connect(func() -> void: get_tree().quit())
	add_child(exit_button)

	_build_warning_modal()
	_build_difficulty_modal()
	_build_settings_modal()
	_build_shop_modal()
	_build_credits_modal()
	_build_fix_notes_modal()
	_build_update_restart_modal()

func _build_warning_modal() -> void:
	var modal: Dictionary = _create_modal("PERINGATAN JUMPSCARE")
	warning_overlay = modal["overlay"] as ColorRect
	var body: VBoxContainer = modal["body"] as VBoxContainer
	var warning := _make_label("Permainan ini mengandung jumpscare mendadak, suara keras, kilatan cahaya, dan visual horor.\n\nPastikan volume nyaman dan hentikan permainan bila merasa tidak nyaman.", 15, TEXT_MAIN, HORIZONTAL_ALIGNMENT_CENTER)
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(warning)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	body.add_child(buttons)
	var back := _make_button("KEMBALI")
	back.pressed.connect(func() -> void: warning_overlay.visible = false)
	buttons.add_child(back)
	var continue_button := _make_button("SAYA MENGERTI", true)
	continue_button.pressed.connect(func() -> void:
		warning_overlay.visible = false
		_update_nightmare_status()
		difficulty_overlay.visible = true
	)
	buttons.add_child(continue_button)

func _build_difficulty_modal() -> void:
	var modal: Dictionary = _create_modal("PILIH TINGKAT KESULITAN")
	difficulty_overlay = modal["overlay"] as ColorRect
	var body: VBoxContainer = modal["body"] as VBoxContainer
	var hint := _make_label("Semakin tinggi tingkat kutukan, semakin cepat malam berlalu dan semakin beringas Lampor memburu.", 12, TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(hint)
	difficulty_buttons.clear()
	var easy := _make_button("EASY  ·  Malam Sunyi (1 mnt = 4,5 dtk)")
	easy.pressed.connect(func() -> void: _start_with_difficulty(GameManager.Difficulty.EASY))
	body.add_child(easy)
	difficulty_buttons.append(easy)
	var normal := _make_button("NORMAL  ·  Malam Keramat (1 mnt = 3 dtk)")
	normal.pressed.connect(func() -> void: _start_with_difficulty(GameManager.Difficulty.NORMAL))
	body.add_child(normal)
	difficulty_buttons.append(normal)
	var hard := _make_button("HARD  ·  Malam Jahanam (1 mnt = 1 dtk)")
	hard.pressed.connect(func() -> void: _start_with_difficulty(GameManager.Difficulty.HARD))
	body.add_child(hard)
	difficulty_buttons.append(hard)
	nightmare_button = _make_button("NIGHTMARE  ·  Kutukan Keranda (1 mnt = 0,5 dtk)", true)
	nightmare_button.pressed.connect(func() -> void: _start_with_difficulty(GameManager.Difficulty.NIGHTMARE))
	body.add_child(nightmare_button)
	difficulty_buttons.append(nightmare_button)
	nightmare_lock_label = _make_label("", 12, TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	nightmare_lock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(nightmare_lock_label)
	var back := _make_button("KEMBALI")
	back.pressed.connect(func() -> void: difficulty_overlay.visible = false)
	body.add_child(back)
	difficulty_buttons.append(back)

func _build_settings_modal() -> void:
	var modal: Dictionary = _create_modal("PENGATURAN & PANDUAN")
	settings_overlay = modal["overlay"] as ColorRect
	var body: VBoxContainer = modal["body"] as VBoxContainer
	settings_scroll = ScrollContainer.new()
	settings_scroll.custom_minimum_size = Vector2(0, 280)
	settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(settings_scroll)
	var settings_margin := MarginContainer.new()
	settings_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	settings_margin.add_theme_constant_override("margin_right", 12)
	settings_scroll.add_child(settings_margin)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_theme_constant_override("separation", 10)
	settings_margin.add_child(content)

	var initial_volume: float = clampf(db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0, 0.0, 100.0)
	volume_slider = _add_slider_setting(content, "Volume", initial_volume, 0.0, 100.0, 1.0, _on_volume_changed)

	mouse_sensitivity_slider = _add_slider_setting(content, "Sensitivitas Mouse", SettingsManager.mouse_sensitivity * 100.0, 25.0, 200.0, 5.0, _on_mouse_sensitivity_changed)
	camera_sensitivity_slider = _add_slider_setting(content, "Sensitivitas Kamera", SettingsManager.camera_sensitivity * 100.0, 25.0, 200.0, 5.0, _on_camera_sensitivity_changed)
	var sensitivity_note := _make_label("Mouse untuk desktop · Kamera untuk geser layar sentuh", 11, TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(sensitivity_note)
	brightness_slider = _add_slider_setting(content, "Kecerahan", SettingsManager.brightness * 100.0, 50.0, 150.0, 5.0, _on_brightness_changed)

	var graphics_row := HBoxContainer.new()
	var graphics_label := _make_label("Grafik", 13, TEXT_MAIN, HORIZONTAL_ALIGNMENT_LEFT)
	graphics_label.custom_minimum_size.x = 132.0
	graphics_row.add_child(graphics_label)
	graphics_option = OptionButton.new()
	graphics_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphics_option.add_item("Otomatis (Perangkat)")
	graphics_option.add_item("Low")
	graphics_option.add_item("Medium")
	graphics_option.add_item("High")
	graphics_option.tooltip_text = "Otomatis menggunakan preset %s berdasarkan perangkat ini" % SettingsManager.recommended_graphics_quality.capitalize()
	match SettingsManager.graphics_quality:
		"auto": graphics_option.select(0)
		"low": graphics_option.select(1)
		"medium": graphics_option.select(2)
		"high": graphics_option.select(3)
		_: graphics_option.select(0)
	graphics_option.item_selected.connect(_on_graphics_quality_selected)
	graphics_row.add_child(graphics_option)
	content.add_child(graphics_row)

	auto_update_check = CheckButton.new()
	auto_update_check.text = "Unduh & pasang update otomatis"
	auto_update_check.button_pressed = SettingsManager.auto_update
	auto_update_check.toggled.connect(SettingsManager.set_auto_update)
	content.add_child(auto_update_check)
	update_check_button = _make_button("PERIKSA PEMBARUAN GAME")
	update_check_button.pressed.connect(func() -> void:
		update_check_button.text = "MEMERIKSA PEMBARUAN..."
		update_status_label.text = "Menghubungi GitHub..."
		UpdateManager.check_for_updates(true)
	)
	content.add_child(update_check_button)
	update_status_label = _make_label("Pembaruan diperiksa melalui commit branch main GitHub.", 11, TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	update_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(update_status_label)

	var redeem_title := _make_label("KODE REDEEM", 15, Color(0.85, 0.25, 0.25, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(redeem_title)
	var redeem_row := HBoxContainer.new()
	redeem_input = LineEdit.new()
	redeem_input.placeholder_text = "Masukkan kode redeem"
	redeem_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	redeem_input.max_length = 32
	redeem_row.add_child(redeem_input)
	var redeem_button := _make_button("TUKAR")
	redeem_button.custom_minimum_size = Vector2(92.0, 42.0)
	redeem_button.pressed.connect(_on_redeem_pressed)
	redeem_row.add_child(redeem_button)
	content.add_child(redeem_row)
	redeem_result_label = _make_label("Setiap kode hanya dapat digunakan sekali pada save ini.", 11, TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	redeem_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(redeem_result_label)

	fullscreen_button = _make_button("GANTI MODE LAYAR")
	fullscreen_button.pressed.connect(_toggle_fullscreen)
	content.add_child(fullscreen_button)

	var guide_title := _make_label("PANDUAN BERMAIN", 15, Color(0.85, 0.25, 0.25, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(guide_title)
	var guide := RichTextLabel.new()
	guide.bbcode_enabled = true
	guide.fit_content = true
	guide.scroll_active = false
	guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide.custom_minimum_size = Vector2(0, 330)
	guide.text = "[color=#d9b76c][b]TUJUAN PERMAINAN[/b][/color]\nBertahan dari pukul 01.00 hingga fajar. Nyalakan 5 obor, amankan 3 pintu rumah, kumpulkan 4 benda ritual, lalu bakar semuanya di tungku balai desa. Bertahanlah sampai ritual selesai.\n\n[color=#d9b76c][b]KONTROL DESKTOP[/b][/color]\n• W, A, S, D: Bergerak\n• Mouse: Melihat ke sekitar\n• Shift: Berlari\n• E: Berinteraksi, mengambil barang, membuka pintu, dan bersembunyi\n• F: Menyalakan/mematikan senter\n• 1–5: Memilih slot hotbar\n• Tab / B: Membuka/menutup tas inventori (15 slot) & drag-and-drop barang\n• Enter / Space: Menggunakan barang\n• G: Menjatuhkan barang\n• Esc: Jeda permainan\n\n[color=#d9b76c][b]KONTROL MOBILE[/b][/color]\nGunakan joystick kiri untuk bergerak dan geser sisi kanan layar untuk melihat sekitar. Tombol di sisi kanan digunakan untuk berlari, berinteraksi, menyalakan senter, menggunakan barang, dan jeda. Sentuh slot inventaris untuk memilih barang, atau tekan tombol TAS untuk membuka sistem inventori.\n\n[color=#e66a68][b]CARA MENGHINDARI LAMPOR[/b][/color]\n• Jangan menatap langsung ke Lampor. Segera alihkan pandangan.\n• Saat lonceng terdengar dekat, matikan senter dan cari tempat bersembunyi.\n• Rumah dan area obor dapat membantu melindungimu.\n• Simpan jamu untuk memulihkan kewarasan dan stamina.\n• Nightmare terbuka setelah 5 kemenangan."
	content.add_child(guide)

	var close := _make_button("TUTUP")
	close.pressed.connect(func() -> void: settings_overlay.visible = false)
	body.add_child(close)

func _add_slider_setting(parent: VBoxContainer, title_text: String, initial_value: float, min_value: float, max_value: float, step_value: float, callback: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var title := _make_label(title_text, 13, TEXT_MAIN, HORIZONTAL_ALIGNMENT_LEFT)
	title.custom_minimum_size.x = 132.0
	row.add_child(title)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step_value
	slider.value = initial_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := _make_label("%d%%" % int(round(initial_value)), 12, TEXT_MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	value_label.custom_minimum_size.x = 42.0
	row.add_child(slider)
	row.add_child(value_label)
	parent.add_child(row)
	if title_text == "Volume":
		volume_value = value_label
	elif title_text == "Sensitivitas Mouse":
		mouse_sensitivity_value = value_label
	elif title_text == "Sensitivitas Kamera":
		camera_sensitivity_value = value_label
	elif title_text == "Kecerahan":
		brightness_value = value_label
	slider.value_changed.connect(callback)
	return slider


func _build_shop_modal() -> void:
	var modal: Dictionary = _create_modal("TOKO ITEM")
	shop_overlay = modal["overlay"] as ColorRect
	var body: VBoxContainer = modal["body"] as VBoxContainer
	shop_balance_label = _make_label("Koin Emas: %d" % GameManager.coins, 15, Color(0.9, 0.76, 0.42, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(shop_balance_label)
	shop_scroll = ScrollContainer.new()
	shop_scroll.custom_minimum_size = Vector2(0.0, 270.0)
	shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(shop_scroll)
	var shop_margin := MarginContainer.new()
	shop_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	shop_margin.add_theme_constant_override("margin_right", 12)
	shop_scroll.add_child(shop_margin)
	var offers := VBoxContainer.new()
	offers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offers.mouse_filter = Control.MOUSE_FILTER_PASS
	offers.add_theme_constant_override("separation", 8)
	shop_margin.add_child(offers)
	_add_shop_offer(offers, "Jamu Tolak Bala x1", "Memulihkan 45 kewarasan dan seluruh stamina.", "30 koin", "jamu", 1)
	_add_shop_offer(offers, "Jamu Tolak Bala x3", "Persediaan jamu untuk tiga kali pemakaian.", "90 koin", "jamu", 3)
	_add_shop_offer(offers, "Baterai Senter x1", "Mengisi ulang 50% daya senter saat digunakan.", "20 koin", "baterai", 1)
	_add_shop_offer(offers, "Nyawa Tambahan x1", "Bangkit sekali di titik awal saat terbunuh.", "80 koin", "extra_life", 1)
	_add_shop_offer(offers, "Nyawa Tambahan x2", "Dua kesempatan bangkit tambahan.", "150 koin", "extra_life", 2)
	_add_shop_offer(offers, "Nyawa Tambahan x3", "Tiga kesempatan bangkit tambahan.", "210 koin", "extra_life", 3)
	shop_result_label = _make_label("Batas pembelian: maksimal 5 per item & 5 nyawa tambahan. Jamu dapat di-stack hingga 10 di hotbar.", 11, TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	shop_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(shop_result_label)
	var close := _make_button("TUTUP")
	close.pressed.connect(func() -> void: shop_overlay.visible = false)
	body.add_child(close)

func _add_shop_offer(parent: VBoxContainer, title_text: String, description: String, price_text: String, item_id: String, quantity: int) -> void:
	var offer := PanelContainer.new()
	offer.mouse_filter = Control.MOUSE_FILTER_PASS
	offer.add_theme_stylebox_override("panel", _panel_style())
	parent.add_child(offer)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	offer.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)
	var heading := _make_label(title_text, 14, TEXT_MAIN, HORIZONTAL_ALIGNMENT_LEFT)
	column.add_child(heading)
	var detail := _make_label(description, 11, TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(detail)
	var buy := _make_button("BELI · " + price_text, true)
	buy.custom_minimum_size.y = 40.0
	buy.pressed.connect(func() -> void: _purchase_shop_item(item_id, quantity))
	column.add_child(buy)

func _refresh_currency_display() -> void:
	if currency_label:
		currency_label.text = "Koin Emas: %d   ·   Nyawa Cadangan: %d" % [GameManager.coins, GameManager.extra_lives]
	if main_content and is_instance_valid(main_content):
		var wins: Label = main_content.get_node_or_null("WinsLabel") as Label
		if wins:
			wins.text = "Malam Terlewati: %d Kemenangan" % GameManager.total_wins

func _refresh_shop_display() -> void:
	if shop_balance_label:
		shop_balance_label.text = "Koin: %d  ·  Nyawa: %d/%d  ·  Jamu: %d/%d  ·  Baterai: %d/%d" % [
			GameManager.coins,
			GameManager.extra_lives,
			GameManager.MAX_EXTRA_LIVES,
			GameManager.item_stash.get("jamu", 0),
			GameManager.MAX_SHOP_ITEM_QTY,
			GameManager.item_stash.get("baterai", 0),
			GameManager.MAX_SHOP_ITEM_QTY
		]

func _purchase_shop_item(item_id: String, quantity: int) -> void:
	var result: Dictionary = GameManager.purchase_shop_item(item_id, quantity)
	shop_result_label.text = str(result.get("message", "Transaksi gagal."))
	shop_result_label.add_theme_color_override("font_color", Color(0.55, 0.88, 0.58, 1.0) if bool(result.get("success", false)) else Color(0.95, 0.48, 0.45, 1.0))
	_refresh_shop_display()
	_refresh_currency_display()

func _on_redeem_pressed() -> void:
	var result: Dictionary = GameManager.redeem_code(redeem_input.text)
	redeem_result_label.text = str(result.get("message", "Kode gagal diproses."))
	redeem_result_label.add_theme_color_override("font_color", Color(0.55, 0.88, 0.58, 1.0) if bool(result.get("success", false)) else Color(0.95, 0.48, 0.45, 1.0))
	if bool(result.get("success", false)):
		redeem_input.clear()
	_refresh_currency_display()
	_refresh_shop_display()

func _on_continue_pressed() -> void:
	for overlay: ColorRect in modal_overlays:
		overlay.visible = false
	if GameManager.has_saved_run():
		GameManager.resume_saved_game()
	else:
		if continue_button:
			continue_button.visible = false

func _check_for_game_updates() -> void:
	UpdateManager.check_for_updates()

func _on_update_available(commit_sha: String, commit_message: String) -> void:
	update_button.disabled = false
	update_check_button.text = "PERIKSA PEMBARUAN GAME"
	if UpdateManager.is_git_working_copy():
		update_button.visible = false
		update_status_label.text = "Mode Developer (Git/Editor): Commit GitHub %s (%s). Gunakan git pull/push agar perubahan lokal tidak tertimpa." % [commit_sha.substr(0, 10), commit_message]
		return
	update_button.visible = not UpdateManager.is_update_processed()
	update_button.text = "PASANG PEMBARUAN"
	update_button.tooltip_text = commit_message
	if UpdateManager.is_update_processed():
		update_status_label.text = "Commit %s sudah terpasang." % commit_sha.substr(0, 10)
	else:
		update_status_label.text = "Commit terbaru %s: %s" % [commit_sha.substr(0, 10), commit_message]

func _on_update_up_to_date(commit_sha: String) -> void:
	update_check_button.text = "PERIKSA PEMBARUAN GAME"
	update_status_label.text = "Game sudah sama dengan commit terbaru (%s)." % commit_sha.substr(0, 10)
	update_button.visible = false

func _on_update_installed(destination_path: String, commit_sha: String, applied_to_project: bool) -> void:
	update_button.disabled = false
	update_button.visible = false
	update_check_button.text = "PERIKSA PEMBARUAN GAME"
	if applied_to_project:
		update_status_label.text = "Update %s berhasil diterapkan. Mulai ulang permainan agar semua skrip, resource, file baru, dan penghapusan dimuat sepenuhnya." % commit_sha.substr(0, 10)
		update_button.tooltip_text = "Proyek sudah sama dengan commit %s" % commit_sha.substr(0, 10)
		_show_update_restart_prompt(commit_sha)
	else:
		update_status_label.text = "Paket source %s sudah diekstrak ke penyimpanan aplikasi, tetapi belum dapat mengganti APK/PCK yang sedang berjalan. Gunakan build rilis platform terbaru untuk menerapkan perubahan." % commit_sha.substr(0, 10)
		update_button.tooltip_text = "Source hasil ekstrak: %s" % destination_path

func _build_update_restart_modal() -> void:
	var modal: Dictionary = _create_modal("PEMBARUAN BERHASIL")
	update_restart_overlay = modal["overlay"] as ColorRect
	var body: VBoxContainer = modal["body"] as VBoxContainer
	var explanation := _make_label("Semua perubahan terbaru dari repository sudah siap diterapkan. Mulai ulang permainan sekarang agar semua skrip, scene, dan resource terbaru dimuat sepenuhnya. Progress permainan akan disimpan sebelum dimulai ulang.", 14, TEXT_MAIN, HORIZONTAL_ALIGNMENT_CENTER)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(explanation)
	update_restart_status = _make_label("Disarankan: mulai ulang sekarang.", 12, TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	update_restart_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(update_restart_status)
	var restart_label: String = "TUTUP GAME UNTUK MENERAPKAN" if OS.has_feature("android") else "MULAI ULANG SEKARANG"
	var restart := _make_button(restart_label, true)
	restart.pressed.connect(_restart_after_update)
	body.add_child(restart)
	var later := _make_button("NANTI, SAYA MULAI ULANG MANUAL")
	later.pressed.connect(func() -> void:
		update_restart_overlay.visible = false
		update_status_label.text = "Pembaruan sudah siap. Tutup permainan lalu buka kembali Lampor untuk memuat seluruh perubahan."
	)
	body.add_child(later)

func _show_update_restart_prompt(commit_sha: String) -> void:
	if update_restart_overlay == null:
		return
	if OS.has_feature("android"):
		update_restart_status.text = "Commit terpasang: %s · Tutup game lalu buka kembali untuk menerapkan patch." % commit_sha.substr(0, 10)
	else:
		update_restart_status.text = "Commit terpasang: %s · Mulai ulang disarankan." % commit_sha.substr(0, 10)
	update_restart_overlay.visible = true
	update_restart_overlay.move_to_front()

func _restart_after_update() -> void:
	if update_restart_status:
		update_restart_status.text = "Menyimpan progress dan memulai ulang..."
	GameManager.save_active_run()
	GameManager.save_game_data()
	if OS.has_feature("android"):
		get_tree().quit()
		return
	var executable_path: String = OS.get_executable_path()
	var args: PackedStringArray = PackedStringArray()
	if UpdateManager.is_source_sync_mode():
		args.append("--path")
		args.append(ProjectSettings.globalize_path("res://"))
	var process_id: int = OS.create_process(executable_path, args)
	if process_id <= 0:
		if update_restart_status:
			update_restart_status.text = "Permainan tidak dapat dimulai ulang otomatis. Tutup game, lalu buka kembali Lampor secara manual. Progress sudah disimpan."
		return
	get_tree().quit()

func _on_update_failed(message: String) -> void:
	if update_button:
		update_button.disabled = false
		update_button.visible = not UpdateManager.is_git_working_copy()
		update_button.text = "UPDATE GAGAL · COBA LAGI"
		update_button.tooltip_text = message
	if update_check_button:
		update_check_button.text = "PERIKSA PEMBARUAN GAME"
	if update_status_label:
		update_status_label.text = message

func _on_update_button_pressed() -> void:
	update_button.disabled = true
	update_button.text = "MENGUNDUH & MEMASANG..."
	UpdateManager.download_update()


func _build_fix_notes_modal() -> void:
	_ensure_markdown_regexes()
	var modal: Dictionary = _create_modal("CATATAN PEMBARUAN")
	fix_notes_overlay = modal["overlay"] as ColorRect
	fix_notes_panel = modal["panel"] as PanelContainer
	var body: VBoxContainer = modal["body"] as VBoxContainer
	fix_notes_hint_label = _make_label("Catatan perubahan dari FIX_NOTES.md pada versi game & commit terbaru repository.", 11, TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	fix_notes_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(fix_notes_hint_label)
	fix_notes_scroll = ScrollContainer.new()
	fix_notes_scroll.custom_minimum_size = Vector2(0, 340)
	fix_notes_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fix_notes_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fix_notes_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	fix_notes_scroll.get_v_scroll_bar().value_changed.connect(_on_fix_notes_scroll_value_changed)
	body.add_child(fix_notes_scroll)
	var notes_margin := MarginContainer.new()
	notes_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notes_margin.add_theme_constant_override("margin_left", 4)
	notes_margin.add_theme_constant_override("margin_right", 14)
	notes_margin.add_theme_constant_override("margin_top", 4)
	notes_margin.add_theme_constant_override("margin_bottom", 8)
	fix_notes_scroll.add_child(notes_margin)
	var notes_column := VBoxContainer.new()
	notes_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notes_column.add_theme_constant_override("separation", 10)
	notes_margin.add_child(notes_column)
	fix_notes_view = RichTextLabel.new()
	fix_notes_view.bbcode_enabled = true
	fix_notes_view.fit_content = true
	fix_notes_view.scroll_active = false
	fix_notes_view.selection_enabled = false
	fix_notes_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fix_notes_view.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fix_notes_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fix_notes_view.custom_minimum_size = Vector2(0, 120)
	fix_notes_view.add_theme_color_override("default_color", TEXT_MAIN)
	fix_notes_view.add_theme_font_size_override("normal_font_size", 14)
	fix_notes_view.add_theme_font_size_override("bold_font_size", 14)
	fix_notes_view.add_theme_font_size_override("italics_font_size", 14)
	fix_notes_view.add_theme_font_size_override("mono_font_size", 12)
	fix_notes_view.add_theme_constant_override("line_separation", 9)
	notes_column.add_child(fix_notes_view)
	fix_notes_more_label = _make_label("Gulir ke bawah untuk memuat catatan versi sebelumnya...", 12, TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	fix_notes_more_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fix_notes_more_label.visible = false
	notes_column.add_child(fix_notes_more_label)
	var close := _make_button("TUTUP")
	close.pressed.connect(func() -> void: fix_notes_overlay.visible = false)
	body.add_child(close)

func _ensure_markdown_regexes() -> void:
	if _rx_inline_code != null:
		return
	_rx_table_sep = RegEx.new()
	_rx_table_sep.compile("^:?-{3,}:?$")
	_rx_numbered = RegEx.new()
	_rx_numbered.compile("^(\\d+)\\.\\s+(.+)$")
	_rx_inline_code = RegEx.new()
	_rx_inline_code.compile("`([^`]+)`")
	_rx_links = RegEx.new()
	_rx_links.compile("\\[([^\\]]+)\\]\\((https?://[^)]+)\\)")
	_rx_bold = RegEx.new()
	_rx_bold.compile("\\*\\*(.+?)\\*\\*")
	_rx_strike = RegEx.new()
	_rx_strike.compile("~~(.+?)~~")
	_rx_italic = RegEx.new()
	_rx_italic.compile("(?<!\\*)\\*([^*]+)\\*(?!\\*)")

func _split_fix_notes_sections(markdown: String) -> Array[String]:
	var sections: Array[String] = []
	var header_lines := PackedStringArray()
	var current_lines := PackedStringArray()
	var seen_first_version: bool = false
	for line in markdown.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("## "):
			if not seen_first_version:
				seen_first_version = true
				for h in header_lines:
					current_lines.append(h)
				header_lines.clear()
				current_lines.append(line)
			else:
				sections.append("\n".join(current_lines))
				current_lines.clear()
				current_lines.append(line)
		else:
			if not seen_first_version:
				header_lines.append(line)
			else:
				current_lines.append(line)
	if not current_lines.is_empty():
		sections.append("\n".join(current_lines))
	elif not header_lines.is_empty():
		sections.append("\n".join(header_lines))
	return sections

func _render_initial_fix_notes(markdown: String) -> void:
	if markdown == fix_notes_rendered_markdown and fix_notes_loaded_sections > 0:
		return
	fix_notes_rendered_markdown = markdown
	fix_notes_sections = _split_fix_notes_sections(markdown)
	fix_notes_loaded_sections = 0
	fix_notes_view.clear()
	if not fix_notes_sections.is_empty():
		fix_notes_view.parse_bbcode(_markdown_to_bbcode(fix_notes_sections[0]))
		fix_notes_loaded_sections = 1
	if fix_notes_more_label:
		fix_notes_more_label.visible = (fix_notes_loaded_sections < fix_notes_sections.size())
	if fix_notes_scroll:
		fix_notes_scroll.scroll_vertical = 0

func _load_next_fix_notes_section() -> void:
	if fix_notes_loaded_sections >= fix_notes_sections.size():
		if fix_notes_more_label:
			fix_notes_more_label.visible = false
		return
	var next_bbcode: String = _markdown_to_bbcode(fix_notes_sections[fix_notes_loaded_sections])
	fix_notes_view.append_text("\n" + next_bbcode)
	fix_notes_loaded_sections += 1
	if fix_notes_more_label:
		fix_notes_more_label.visible = (fix_notes_loaded_sections < fix_notes_sections.size())

func _on_fix_notes_scroll_value_changed(_value: float) -> void:
	if fix_notes_loaded_sections >= fix_notes_sections.size() or fix_notes_scroll == null:
		return
	var vbar: VScrollBar = fix_notes_scroll.get_v_scroll_bar()
	if vbar and (vbar.value + fix_notes_scroll.size.y >= vbar.max_value - 120.0):
		_load_next_fix_notes_section()

func _get_active_scroll_container() -> ScrollContainer:
	if fix_notes_overlay and fix_notes_overlay.visible and fix_notes_scroll:
		return fix_notes_scroll
	if settings_overlay and settings_overlay.visible and settings_scroll:
		return settings_scroll
	if shop_overlay and shop_overlay.visible and shop_scroll:
		return shop_scroll
	return null

func _is_scroll_drag_blocked_control(control: Control) -> bool:
	return control is HSlider or control is VScrollBar or control is HScrollBar or control is LineEdit or control is TextEdit or control is OptionButton

func _input(event: InputEvent) -> void:
	var active_scroll: ScrollContainer = _get_active_scroll_container()
	if active_scroll == null:
		_active_drag_scroll = null
		_drag_moved = false
		_drag_pressed_button = null
		return
	var vbar: VScrollBar = active_scroll.get_v_scroll_bar()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN) and mb.pressed:
			if graphics_option and graphics_option.get_popup().visible:
				return
			if active_scroll.get_global_rect().has_point(mb.position):
				var step: int = -48 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 48
				active_scroll.scroll_vertical = maxi(0, active_scroll.scroll_vertical + step)
				if active_scroll == fix_notes_scroll and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					if fix_notes_loaded_sections < fix_notes_sections.size() and vbar and vbar.max_value <= fix_notes_scroll.size.y + 8.0:
						_load_next_fix_notes_section()
				get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if active_scroll.get_global_rect().has_point(mb.position):
					var hovered: Control = get_viewport().gui_get_hovered_control()
					if _is_scroll_drag_blocked_control(hovered):
						return
					_active_drag_scroll = active_scroll
					_drag_start_y = mb.position.y
					_drag_last_y = mb.position.y
					_drag_moved = false
					_drag_pressed_button = hovered as BaseButton
			elif _active_drag_scroll != null:
				var was_dragged: bool = _drag_moved
				_active_drag_scroll = null
				_drag_moved = false
				_drag_pressed_button = null
				if was_dragged:
					get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _active_drag_scroll != null:
		var mm := event as InputEventMouseMotion
		if not _drag_moved and absf(mm.position.y - _drag_start_y) > 8.0:
			_drag_moved = true
			if is_instance_valid(_drag_pressed_button):
				var was_disabled: bool = _drag_pressed_button.disabled
				_drag_pressed_button.disabled = true
				_drag_pressed_button.disabled = was_disabled
				_drag_pressed_button = null
		if _drag_moved:
			var delta_y: float = mm.position.y - _drag_last_y
			_active_drag_scroll.scroll_vertical = maxi(0, _active_drag_scroll.scroll_vertical - int(round(delta_y)))
			if _active_drag_scroll == fix_notes_scroll and delta_y < -2.0:
				if fix_notes_loaded_sections < fix_notes_sections.size() and vbar and vbar.max_value <= fix_notes_scroll.size.y + 8.0:
					_load_next_fix_notes_section()
			get_viewport().set_input_as_handled()
		_drag_last_y = mm.position.y
	elif event is InputEventScreenDrag and active_scroll == fix_notes_scroll:
		var sd := event as InputEventScreenDrag
		if sd.relative.y < -2.0 and fix_notes_loaded_sections < fix_notes_sections.size() and vbar and vbar.max_value <= fix_notes_scroll.size.y + 8.0:
			_load_next_fix_notes_section()

func _show_fix_notes() -> void:
	if fix_notes_view == null:
		return
	var markdown: String = UpdateManager.get_fix_notes_markdown()
	if markdown.strip_edges().is_empty():
		markdown = "# Catatan Pembaruan\n\nBelum ada catatan untuk versi ini."
	_render_initial_fix_notes(markdown)
	fix_notes_overlay.visible = true
	UpdateManager.fetch_latest_fix_notes(true)

func _on_fix_notes_updated(markdown: String, commit_sha: String) -> void:
	if fix_notes_hint_label and not commit_sha.is_empty():
		var short_ref: String = commit_sha.substr(0, 10) if commit_sha.length() > 10 else commit_sha
		fix_notes_hint_label.text = "Menampilkan FIX_NOTES.md terbaru dari repository (%s)." % short_ref
	if fix_notes_view and fix_notes_overlay and fix_notes_overlay.visible:
		var clean_md: String = UpdateManager.get_fix_notes_markdown()
		if clean_md.strip_edges().is_empty():
			clean_md = markdown
		_render_initial_fix_notes(clean_md)

func _markdown_to_bbcode(markdown: String) -> String:
	var output := PackedStringArray()
	var in_code_block: bool = false
	var in_table: bool = false
	var code_lines := PackedStringArray()
	for line in markdown.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
		if line.strip_edges().begins_with("```"):
			if in_code_block:
				output.append("[bgcolor=#171418][color=#e8dddd][code] " + "\n".join(code_lines).replace("[", "[lb]").replace("]", "[rb]") + " [/code][/color][/bgcolor]")
				output.append("[font_size=6] [/font_size]")
				code_lines.clear()
				in_code_block = false
			else:
				in_code_block = true
				code_lines.clear()
			continue
		if in_code_block:
			code_lines.append(line)
			continue
		var leading_spaces: int = line.length() - line.lstrip(" \t").length()
		var trimmed: String = line.strip_edges()
		if trimmed.is_empty():
			if output.size() > 0 and not output[output.size() - 1].is_empty():
				output.append("")
			in_table = false
			continue
		if trimmed.begins_with("|") and trimmed.count("|") >= 2:
			var cells: PackedStringArray = trimmed.trim_prefix("|").trim_suffix("|").split("|")
			var clean_cells := PackedStringArray()
			var separator_row: bool = true
			for cell in cells:
				var cell_text: String = cell.strip_edges()
				clean_cells.append(cell_text)
				if not _rx_table_sep.search(cell_text):
					separator_row = false
			if separator_row:
				continue
			var rendered_cells := PackedStringArray()
			for cell_text in clean_cells:
				rendered_cells.append(_markdown_inline(cell_text))
			var table_row: String = "  [color=#8e7779]│[/color]  ".join(rendered_cells)
			if not in_table:
				output.append("[b][color=#e58b8e]" + table_row + "[/color][/b]")
				in_table = true
			else:
				output.append(table_row)
			continue
		else:
			in_table = false
		if trimmed in ["---", "***", "___"]:
			output.append("[color=#74464a]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[/color]")
			continue
		if trimmed.begins_with("### "):
			if output.size() > 0:
				output.append("[font_size=6] [/font_size]")
			output.append("[font_size=16][b][color=#e58b8e]" + _markdown_inline(trimmed.substr(4)) + "[/color][/b][/font_size]")
		elif trimmed.begins_with("## "):
			if output.size() > 0:
				output.append("[font_size=10] [/font_size]")
			output.append("[font_size=19][b][color=#e89598]" + _markdown_inline(trimmed.substr(3)) + "[/color][/b][/font_size]")
			output.append("[color=#5a2d32]────────────────────────[/color]")
		elif trimmed.begins_with("# "):
			if output.size() > 0:
				output.append("[font_size=10] [/font_size]")
			output.append("[font_size=22][b][color=#f0a8aa]" + _markdown_inline(trimmed.substr(2)) + "[/color][/b][/font_size]")
		elif trimmed.begins_with("> "):
			output.append("[color=#b7a5a5][i]│  " + _markdown_inline(trimmed.substr(2)) + "[/i][/color]")
		elif trimmed.begins_with("- [ ] ") or trimmed.begins_with("* [ ] "):
			output.append("[color=#d77b80]☐[/color]  " + _markdown_inline(trimmed.substr(6)))
		elif trimmed.begins_with("- [x] ") or trimmed.begins_with("- [X] ") or trimmed.begins_with("* [x] ") or trimmed.begins_with("* [X] "):
			output.append("[color=#91c59a]☑[/color]  " + _markdown_inline(trimmed.substr(6)))
		elif trimmed.begins_with("- ") or trimmed.begins_with("* ") or trimmed.begins_with("+ "):
			var indent_level: int = mini(leading_spaces / 2, 2)
			if indent_level == 0:
				if output.size() > 0 and not output[output.size() - 1].ends_with("[/font_size]") and not output[output.size() - 1].begins_with("[color=#5a2d32]"):
					output.append("[font_size=6] [/font_size]")
				output.append("[color=#d77b80]◆[/color]  " + _markdown_inline(trimmed.substr(2)))
			else:
				var pad: String = "    ".repeat(indent_level)
				output.append(pad + "[color=#9c7b7e]•[/color]  " + _markdown_inline(trimmed.substr(2)))
		else:
			var matched: RegExMatch = _rx_numbered.search(trimmed)
			if matched:
				output.append("[color=#d77b80]" + matched.get_string(1) + ".[/color]  " + _markdown_inline(matched.get_string(2)))
			else:
				output.append(_markdown_inline(line))
	if in_code_block:
		output.append("[bgcolor=#171418][color=#e8dddd][code] " + "\n".join(code_lines).replace("[", "[lb]").replace("]", "[rb]") + " [/code][/color][/bgcolor]")
	return "\n".join(output)

func _markdown_inline(source: String) -> String:
	_ensure_markdown_regexes()
	var result: String = source
	var code_tokens: Array[String] = []
	var matches: Array[RegExMatch] = _rx_inline_code.search_all(result)
	for i in range(matches.size() - 1, -1, -1):
		var m: RegExMatch = matches[i]
		var raw_code: String = m.get_string(1).replace("[", "[lb]").replace("]", "[rb]")
		var token: String = "\u0001CODE_%d\u0001" % code_tokens.size()
		code_tokens.append("[bgcolor=#231b1f][color=#f6d29f][code] %s [/code][/color][/bgcolor]" % raw_code)
		result = result.substr(0, m.get_start()) + token + result.substr(m.get_end())
	result = _rx_links.sub(result, "[url=$2][color=#9ec5ff]$1[/color][/url]", true)
	result = _rx_bold.sub(result, "[b]$1[/b]", true)
	result = _rx_strike.sub(result, "[s]$1[/s]", true)
	result = _rx_italic.sub(result, "[i]$1[/i]", true)
	for i in range(code_tokens.size()):
		result = result.replace("\u0001CODE_%d\u0001" % i, code_tokens[i])
	return result

func _build_credits_modal() -> void:
	var modal: Dictionary = _create_modal("HAK CIPTA")
	credits_overlay = modal["overlay"] as ColorRect
	var body: VBoxContainer = modal["body"] as VBoxContainer
	var company := _make_label("LAMPOR", 22, Color(0.82, 0.18, 0.2, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	company.add_theme_font_override("font", HORROR_TITLE_FONT)
	body.add_child(company)
	var copy := _make_label("MALAM JAHANAM\n\n© 2026 AstraDev. Seluruh hak cipta dilindungi.\nDibuat sebagai karya fiksi horor yang terinspirasi dari folklore Indonesia.", 14, TEXT_MAIN, HORIZONTAL_ALIGNMENT_CENTER)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(copy)
	var close := _make_button("TUTUP")
	close.pressed.connect(func() -> void: credits_overlay.visible = false)
	body.add_child(close)

func _create_modal(title_text: String) -> Dictionary:
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.86)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)
	var title := _make_label(title_text, 17, Color(0.85, 0.25, 0.25, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_font_override("font", HORROR_TITLE_FONT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(title)
	modal_overlays.append(overlay)
	modal_panels.append(panel)
	return {"overlay": overlay, "panel": panel, "body": body}

func _make_label(text_value: String, font_size: int, color: Color, alignment: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _draw_horror_backdrop() -> void:
	if not horror_backdrop:
		return
	var s: Vector2 = horror_backdrop.size
	if s.x <= 0.0 or s.y <= 0.0:
		return

	var moon_pos := Vector2(s.x * 0.18, s.y * 0.22)
	var moon_r: float = minf(s.x, s.y) * 0.11
	horror_backdrop.draw_circle(moon_pos, moon_r * 2.4, Color(0.28, 0.02, 0.04, 0.12))
	horror_backdrop.draw_circle(moon_pos, moon_r * 1.5, Color(0.42, 0.04, 0.06, 0.18))
	horror_backdrop.draw_circle(moon_pos, moon_r, Color(0.58, 0.09, 0.09, 0.34))

	var float_x: float = s.x * 0.80 + sin(menu_anim_time * 0.7) * 18.0
	var float_y: float = s.y * 0.24 + cos(menu_anim_time * 1.4) * 9.0
	var kw: float = minf(s.x, s.y) * 0.18
	var kh: float = kw * 0.44
	horror_backdrop.draw_circle(Vector2(float_x, float_y), kw * 0.9, Color(0.03, 0.28, 0.11, 0.16))
	horror_backdrop.draw_rect(Rect2(float_x - kw * 0.72, float_y + kh * 0.36, kw * 1.44, 3.0), Color(0.35, 0.32, 0.28, 0.55))
	var keranda_poly := PackedVector2Array([
		Vector2(float_x - kw * 0.50, float_y + kh * 0.36),
		Vector2(float_x - kw * 0.50, float_y - kh * 0.12),
		Vector2(float_x - kw * 0.38, float_y - kh * 0.46),
		Vector2(float_x + kw * 0.38, float_y - kh * 0.46),
		Vector2(float_x + kw * 0.50, float_y - kh * 0.12),
		Vector2(float_x + kw * 0.50, float_y + kh * 0.36)
	])
	horror_backdrop.draw_colored_polygon(keranda_poly, Color(0.03, 0.24, 0.10, 0.78))
	horror_backdrop.draw_rect(Rect2(float_x - kw * 0.50, float_y + kh * 0.22, kw, 3.5), Color(0.85, 0.68, 0.20, 0.65))
	var eye_alpha: float = 0.55 + 0.40 * sin(menu_anim_time * 3.8)
	horror_backdrop.draw_circle(Vector2(float_x - kw * 0.36, float_y + kh * 0.04), 3.2, Color(1.0, 0.12, 0.10, eye_alpha))
	horror_backdrop.draw_circle(Vector2(float_x - kw * 0.28, float_y + kh * 0.04), 3.2, Color(1.0, 0.12, 0.10, eye_alpha))

	var horizon_y: float = s.y * 0.84
	horror_backdrop.draw_rect(Rect2(0.0, horizon_y, s.x, s.y - horizon_y), Color(0.008, 0.005, 0.009, 0.96))
	var roof_left := PackedVector2Array([
		Vector2(s.x * 0.04, horizon_y),
		Vector2(s.x * 0.09, horizon_y - 46.0),
		Vector2(s.x * 0.18, horizon_y - 46.0),
		Vector2(s.x * 0.23, horizon_y)
	])
	horror_backdrop.draw_colored_polygon(roof_left, Color(0.015, 0.01, 0.014, 0.92))
	for i: int in range(5):
		var tx: float = s.x * 0.74 + float(i) * 32.0
		var th: float = 22.0 + float(i % 2) * 7.0
		horror_backdrop.draw_rect(Rect2(tx, horizon_y - th, 11.0, th), Color(0.03, 0.02, 0.025, 0.9))

	for i: int in range(5):
		var mist_y: float = horizon_y - 24.0 + float(i) * 10.0
		var mist_x: float = fmod(menu_anim_time * (12.0 + float(i) * 4.0) + float(i) * 180.0, s.x + 260.0) - 260.0
		horror_backdrop.draw_rect(Rect2(mist_x, mist_y, 320.0, 14.0), Color(0.24, 0.03, 0.05, 0.08))

	for i: int in range(18):
		var seed_f: float = float(i) * 37.17
		var px: float = fmod(seed_f * 29.0 + sin(menu_anim_time * 0.9 + seed_f) * 26.0, s.x)
		var py: float = s.y - fmod(menu_anim_time * (16.0 + float(i % 5) * 5.0) + seed_f * 19.0, s.y)
		var ember_col: Color = Color(0.85, 0.15, 0.12, 0.32) if (i % 3 != 0) else Color(0.20, 0.72, 0.35, 0.24)
		horror_backdrop.draw_circle(Vector2(px, py), 1.8 + float(i % 2), ember_col)

	horror_backdrop.draw_rect(Rect2(0.0, 0.0, s.x, 28.0), Color(0.0, 0.0, 0.0, 0.55))
	horror_backdrop.draw_rect(Rect2(0.0, s.y - 28.0, s.x, 28.0), Color(0.0, 0.0, 0.0, 0.65))
	horror_backdrop.draw_rect(Rect2(0.0, 0.0, 24.0, s.y), Color(0.0, 0.0, 0.0, 0.45))
	horror_backdrop.draw_rect(Rect2(s.x - 24.0, 0.0, 24.0, s.y), Color(0.0, 0.0, 0.0, 0.45))

func _make_button(text_value: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 46)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", TEXT_MAIN if not primary else Color(1.0, 0.94, 0.88, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.86, 1.0))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.38, 0.38, 0.7))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.075, 0.035, 0.045, 0.96) if not primary else Color(0.38, 0.045, 0.065, 0.98)
	normal.border_width_left = 3
	normal.border_width_right = 3
	normal.border_width_top = 1
	normal.border_width_bottom = 2
	normal.border_color = Color(0.42, 0.10, 0.12, 0.95) if not primary else ACCENT
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	normal.shadow_size = 4
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.05, 0.07, 1.0) if not primary else Color(0.58, 0.07, 0.10, 1.0)
	hover.border_color = ACCENT_GOLD if primary else ACCENT
	var disabled_style := normal.duplicate() as StyleBoxFlat
	disabled_style.bg_color = Color(0.05, 0.04, 0.045, 0.75)
	disabled_style.border_color = Color(0.22, 0.14, 0.15, 0.6)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled_style)
	return button

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.028, 0.015, 0.020, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 3
	style.border_color = Color(0.48, 0.10, 0.12, 0.95)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.75)
	style.shadow_size = 12
	return style

func _apply_layout() -> void:
	var view_size: Vector2 = get_viewport_rect().size
	var narrow: bool = view_size.x < 700.0
	var short_screen: bool = view_size.y < 560.0
	title_label.add_theme_font_size_override("font_size", 28 if short_screen else (34 if narrow else 46))
	subtitle_label.add_theme_font_size_override("font_size", 11 if short_screen else (13 if narrow else 15))
	if ritual_header_label:
		ritual_header_label.visible = not short_screen
	main_content.add_theme_constant_override("separation", 6 if short_screen else 9)
	if main_card_margin:
		var h_pad: int = 16 if narrow else 26
		var v_pad: int = 12 if short_screen else 18
		main_card_margin.add_theme_constant_override("margin_left", h_pad)
		main_card_margin.add_theme_constant_override("margin_right", h_pad)
		main_card_margin.add_theme_constant_override("margin_top", v_pad)
		main_card_margin.add_theme_constant_override("margin_bottom", v_pad)
	var menu_buttons: VBoxContainer = main_content.get_node("MenuButtons") as VBoxContainer
	menu_buttons.add_theme_constant_override("separation", 5 if short_screen else 8)
	for button: Node in menu_buttons.get_children():
		(button as Button).custom_minimum_size.y = 38 if short_screen else 45
	for d_btn: Button in difficulty_buttons:
		if is_instance_valid(d_btn):
			d_btn.custom_minimum_size.y = 38 if short_screen else 45
	var wins_label: Label = main_content.get_node("WinsLabel") as Label
	wins_label.visible = not short_screen
	main_content.custom_minimum_size = Vector2(minf(420.0, view_size.x - 56.0), main_content.custom_minimum_size.y)
	copyright_label.offset_left = 16 if narrow else 24
	copyright_label.offset_top = -38 if narrow else -42
	copyright_label.offset_right = minf(view_size.x - 180.0, 360.0)
	copyright_label.text = "© 2026 AstraDev" if narrow else "© 2026 AstraDev. All rights reserved."
	copyright_label.add_theme_font_size_override("font_size", 10 if narrow else 12)
	exit_button.offset_left = -160 if narrow else -190
	exit_button.offset_top = -58 if narrow else -62
	exit_button.offset_right = -14 if narrow else -24
	exit_button.offset_bottom = -14 if narrow else -18
	exit_button.custom_minimum_size = Vector2(146 if narrow else 166, 42)
	if update_button:
		update_button.custom_minimum_size = Vector2(168.0 if narrow else 190.0, 38.0 if narrow else 42.0)
		update_button.offset_left = 10.0 if narrow else 18.0
		update_button.offset_top = 12.0 if narrow else 16.0
		update_button.offset_right = 178.0 if narrow else 210.0
		update_button.offset_bottom = 52.0 if narrow else 58.0
	version_label.offset_left = -94 if narrow else -120
	version_label.offset_top = 14 if narrow else 20
	version_label.offset_right = -14 if narrow else -24
	version_label.offset_bottom = 38 if narrow else 46
	for panel: PanelContainer in modal_panels:
		if panel == fix_notes_panel:
			panel.custom_minimum_size = Vector2(maxf(300.0, minf(720.0, view_size.x - 36.0)), panel.custom_minimum_size.y)
		else:
			panel.custom_minimum_size = Vector2(maxf(280.0, minf(520.0, view_size.x - 28.0)), panel.custom_minimum_size.y)
	if settings_scroll:
		settings_scroll.custom_minimum_size.y = maxf(120.0, minf(290.0, view_size.y - 310.0))
	if shop_scroll:
		shop_scroll.custom_minimum_size.y = maxf(140.0, minf(310.0, view_size.y - 290.0))
	if fix_notes_scroll:
		fix_notes_scroll.custom_minimum_size.y = maxf(170.0, minf(460.0, view_size.y - 210.0))
	if horror_backdrop:
		horror_backdrop.queue_redraw()

func _update_nightmare_status() -> void:
	var unlocked: bool = GameManager.is_nightmare_unlocked()
	nightmare_button.disabled = not unlocked
	if unlocked:
		nightmare_lock_label.text = "Nightmare terbuka. Semoga beruntung."
		nightmare_lock_label.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3, 1.0))
	else:
		var remaining: int = 5 - GameManager.total_wins
		nightmare_lock_label.text = "Terkunci — butuh %d kemenangan lagi (%d/5)." % [remaining, GameManager.total_wins]
		nightmare_lock_label.add_theme_color_override("font_color", TEXT_MUTED)

func _on_volume_changed(value: float) -> void:
	if volume_value:
		volume_value.text = "%d%%" % int(round(value))
	var bus_index: int = AudioServer.get_bus_index("Master")
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, value <= 0.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(value / 100.0, 0.001)))

func _on_mouse_sensitivity_changed(value: float) -> void:
	SettingsManager.set_mouse_sensitivity(value / 100.0)
	if mouse_sensitivity_value:
		mouse_sensitivity_value.text = "%d%%" % int(round(value))

func _on_camera_sensitivity_changed(value: float) -> void:
	SettingsManager.set_camera_sensitivity(value / 100.0)
	if camera_sensitivity_value:
		camera_sensitivity_value.text = "%d%%" % int(round(value))

func _on_brightness_changed(value: float) -> void:
	SettingsManager.set_brightness(value / 100.0)
	if brightness_value:
		brightness_value.text = "%d%%" % int(round(value))

func _on_graphics_quality_selected(index: int) -> void:
	var quality: String = ["auto", "low", "medium", "high"][clampi(index, 0, 3)]
	SettingsManager.set_graphics_quality(quality)

func _toggle_fullscreen() -> void:
	var mode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		fullscreen_button.text = "AKTIFKAN LAYAR PENUH"
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		fullscreen_button.text = "KEMBALI KE MODE JENDELA"

func _start_with_difficulty(diff: GameManager.Difficulty) -> void:
	for overlay: ColorRect in modal_overlays:
		overlay.visible = false
	GameManager.start_new_game(diff)
