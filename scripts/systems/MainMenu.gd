class_name MainMenu
extends Control

const GAME_VERSION: String = "v1.1.4"
const ACCENT: Color = Color(0.72, 0.12, 0.14, 1.0)
const TEXT_MAIN: Color = Color(0.93, 0.91, 0.88, 1.0)
const TEXT_MUTED: Color = Color(0.63, 0.61, 0.60, 1.0)

var main_center: CenterContainer
var main_content: VBoxContainer
var title_label: Label
var subtitle_label: Label
var version_label: Label
var copyright_label: Label
var exit_button: Button
var modal_overlays: Array[ColorRect] = []
var modal_panels: Array[PanelContainer] = []
var warning_overlay: ColorRect
var difficulty_overlay: ColorRect
var settings_overlay: ColorRect
var credits_overlay: ColorRect
var nightmare_button: Button
var nightmare_lock_label: Label
var volume_slider: HSlider
var fullscreen_button: Button
var settings_scroll: ScrollContainer
var mouse_sensitivity_slider: HSlider
var camera_sensitivity_slider: HSlider
var brightness_slider: HSlider
var mouse_sensitivity_value: Label
var camera_sensitivity_value: Label
var brightness_value: Label
var graphics_option: OptionButton

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.current_state = GameManager.GameState.MENU
	_build_menu()
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()

func _build_menu() -> void:
	var background := ColorRect.new()
	background.color = Color(0.018, 0.018, 0.025, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var top_glow := ColorRect.new()
	top_glow.color = Color(0.16, 0.025, 0.035, 0.32)
	top_glow.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_glow.offset_bottom = 2.0
	top_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_glow)

	main_center = CenterContainer.new()
	main_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(main_center)

	main_content = VBoxContainer.new()
	main_content.alignment = BoxContainer.ALIGNMENT_CENTER
	main_content.add_theme_constant_override("separation", 12)
	main_content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_center.add_child(main_content)

	title_label = _make_label("LAMPOR", 58, Color(0.78, 0.16, 0.18, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	title_label.add_theme_constant_override("outline_size", 10)
	title_label.add_theme_color_override("font_outline_color", Color(0.02, 0.0, 0.0, 1.0))
	main_content.add_child(title_label)

	subtitle_label = _make_label("MALAM JAHANAM\nJangan menatap keranda yang melintas.", 17, TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	main_content.add_child(subtitle_label)

	var wins_label := _make_label("", 13, Color(0.78, 0.67, 0.42, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	wins_label.name = "WinsLabel"
	wins_label.text = "Kemenangan tersimpan: %d" % GameManager.total_wins
	main_content.add_child(wins_label)

	var menu_buttons := VBoxContainer.new()
	menu_buttons.name = "MenuButtons"
	menu_buttons.add_theme_constant_override("separation", 10)
	main_content.add_child(menu_buttons)
	var start_button := _make_button("MULAI PERMAINAN", true)
	start_button.pressed.connect(func() -> void: warning_overlay.visible = true)
	menu_buttons.add_child(start_button)
	var settings_button := _make_button("PENGATURAN")
	settings_button.pressed.connect(func() -> void: settings_overlay.visible = true)
	menu_buttons.add_child(settings_button)
	var credits_button := _make_button("HAK CIPTA")
	credits_button.pressed.connect(func() -> void: credits_overlay.visible = true)
	menu_buttons.add_child(credits_button)

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
	_build_credits_modal()

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
	var hint := _make_label("Semakin tinggi kesulitan, semakin cepat waktu dan agresif Lampor.", 13, TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(hint)
	var easy := _make_button("EASY  ·  1 menit = 4,5 detik")
	easy.pressed.connect(func() -> void: _start_with_difficulty(GameManager.Difficulty.EASY))
	body.add_child(easy)
	var normal := _make_button("NORMAL  ·  1 menit = 3 detik")
	normal.pressed.connect(func() -> void: _start_with_difficulty(GameManager.Difficulty.NORMAL))
	body.add_child(normal)
	var hard := _make_button("HARD  ·  1 menit = 1 detik")
	hard.pressed.connect(func() -> void: _start_with_difficulty(GameManager.Difficulty.HARD))
	body.add_child(hard)
	nightmare_button = _make_button("NIGHTMARE  ·  1 menit = 0,5 detik", true)
	nightmare_button.pressed.connect(func() -> void: _start_with_difficulty(GameManager.Difficulty.NIGHTMARE))
	body.add_child(nightmare_button)
	nightmare_lock_label = _make_label("", 12, TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	nightmare_lock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(nightmare_lock_label)
	var back := _make_button("KEMBALI")
	back.pressed.connect(func() -> void: difficulty_overlay.visible = false)
	body.add_child(back)

func _build_settings_modal() -> void:
	var modal: Dictionary = _create_modal("PENGATURAN & PANDUAN")
	settings_overlay = modal["overlay"] as ColorRect
	var body: VBoxContainer = modal["body"] as VBoxContainer
	settings_scroll = ScrollContainer.new()
	settings_scroll.custom_minimum_size = Vector2(0, 280)
	settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(settings_scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	settings_scroll.add_child(content)

	var audio_row := HBoxContainer.new()
	var sound_label := _make_label("Volume", 13, TEXT_MAIN, HORIZONTAL_ALIGNMENT_LEFT)
	sound_label.custom_minimum_size.x = 132.0
	audio_row.add_child(sound_label)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.value = clampf(db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0, 0.0, 100.0)
	volume_slider.value_changed.connect(_on_volume_changed)
	audio_row.add_child(volume_slider)
	content.add_child(audio_row)

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
	graphics_option.item_selected.connect(_on_graphics_quality_selected)
	graphics_row.add_child(graphics_option)
	content.add_child(graphics_row)

	fullscreen_button = _make_button("GANTI MODE LAYAR")
	fullscreen_button.pressed.connect(_toggle_fullscreen)
	content.add_child(fullscreen_button)

	var guide_title := _make_label("PANDUAN BERMAIN", 15, Color(0.85, 0.25, 0.25, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(guide_title)
	var guide := RichTextLabel.new()
	guide.bbcode_enabled = true
	guide.fit_content = true
	guide.scroll_active = false
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide.custom_minimum_size = Vector2(0, 330)
	guide.text = "[color=#d9b76c][b]TUJUAN PERMAINAN[/b][/color]\nBertahan dari pukul 01.00 hingga fajar. Nyalakan 5 obor, amankan 3 pintu rumah, kumpulkan 4 benda ritual, lalu bakar semuanya di tungku balai desa. Bertahanlah sampai ritual selesai.\n\n[color=#d9b76c][b]KONTROL DESKTOP[/b][/color]\n• W, A, S, D: Bergerak\n• Mouse: Melihat ke sekitar\n• Shift: Berlari\n• E: Berinteraksi, mengambil barang, membuka pintu, dan bersembunyi\n• F: Menyalakan/mematikan senter\n• 1–4: Memilih slot barang\n• Enter / Space: Menggunakan barang\n• G: Menjatuhkan barang\n• Esc: Jeda permainan\n\n[color=#d9b76c][b]KONTROL MOBILE[/b][/color]\nGunakan joystick kiri untuk bergerak dan geser sisi kanan layar untuk melihat sekitar. Tombol di sisi kanan digunakan untuk berlari, berinteraksi, menyalakan senter, menggunakan barang, dan jeda. Sentuh slot inventaris untuk memilih barang.\n\n[color=#e66a68][b]CARA MENGHINDARI LAMPOR[/b][/color]\n• Jangan menatap langsung ke Lampor. Segera alihkan pandangan.\n• Saat lonceng terdengar dekat, matikan senter dan cari tempat bersembunyi.\n• Rumah dan area obor dapat membantu melindungimu.\n• Simpan jamu untuk memulihkan kewarasan dan stamina.\n• Nightmare terbuka setelah 5 kemenangan."
	content.add_child(guide)

	var close := _make_button("TUTUP")
	close.pressed.connect(func() -> void: settings_overlay.visible = false)
	body.add_child(close)

func _add_slider_setting(parent: VBoxContainer, title_text: String, initial_value: float, min_value: float, max_value: float, step_value: float, callback: Callable) -> HSlider:
	var row := HBoxContainer.new()
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
	if title_text == "Sensitivitas Mouse":
		mouse_sensitivity_value = value_label
	elif title_text == "Sensitivitas Kamera":
		camera_sensitivity_value = value_label
	elif title_text == "Kecerahan":
		brightness_value = value_label
	slider.value_changed.connect(callback)
	return slider

func _build_credits_modal() -> void:
	var modal: Dictionary = _create_modal("HAK CIPTA")
	credits_overlay = modal["overlay"] as ColorRect
	var body: VBoxContainer = modal["body"] as VBoxContainer
	var company := _make_label("ASTRADEV", 30, Color(0.82, 0.18, 0.2, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(company)
	var copy := _make_label("LAMPOR: MALAM JAHANAM\n\n© 2026 AstraDev. Seluruh hak cipta dilindungi.\nDibuat sebagai karya fiksi horor yang terinspirasi dari folklore Indonesia.", 14, TEXT_MAIN, HORIZONTAL_ALIGNMENT_CENTER)
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
	var title := _make_label(title_text, 21, Color(0.85, 0.25, 0.25, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
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

func _make_button(text_value: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", TEXT_MAIN)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.105, 0.11, 0.96) if not primary else Color(0.42, 0.065, 0.085, 1.0)
	normal.border_width_bottom = 2
	normal.border_color = Color(0.34, 0.09, 0.1, 1.0) if not primary else ACCENT
	normal.corner_radius_top_left = 5
	normal.corner_radius_top_right = 5
	normal.corner_radius_bottom_left = 5
	normal.corner_radius_bottom_right = 5
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.07, 0.085, 1.0) if not primary else Color(0.62, 0.09, 0.12, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	return button

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.04, 0.045, 0.98)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.border_color = Color(0.35, 0.11, 0.12, 0.95)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

func _apply_layout() -> void:
	var view_size: Vector2 = get_viewport_rect().size
	var narrow: bool = view_size.x < 700.0
	var short_screen: bool = view_size.y < 520.0
	title_label.add_theme_font_size_override("font_size", 36 if short_screen else (43 if narrow else 58))
	subtitle_label.add_theme_font_size_override("font_size", 12 if short_screen else (14 if narrow else 17))
	main_content.add_theme_constant_override("separation", 7 if short_screen else 12)
	var menu_buttons: VBoxContainer = main_content.get_node("MenuButtons") as VBoxContainer
	menu_buttons.add_theme_constant_override("separation", 6 if short_screen else 10)
	for button: Node in menu_buttons.get_children():
		(button as Button).custom_minimum_size.y = 40 if short_screen else 48
	var wins_label: Label = main_content.get_node("WinsLabel") as Label
	wins_label.visible = not short_screen
	main_content.custom_minimum_size = Vector2(minf(420.0, view_size.x - 42.0), main_content.custom_minimum_size.y)
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
	version_label.offset_left = -94 if narrow else -120
	version_label.offset_top = 14 if narrow else 20
	version_label.offset_right = -14 if narrow else -24
	version_label.offset_bottom = 38 if narrow else 46
	for panel: PanelContainer in modal_panels:
		panel.custom_minimum_size = Vector2(maxf(280.0, minf(540.0, view_size.x - 28.0)), panel.custom_minimum_size.y)
	if settings_scroll:
		settings_scroll.custom_minimum_size.y = maxf(120.0, minf(290.0, view_size.y - 310.0))

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
