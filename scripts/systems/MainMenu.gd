class_name MainMenu
extends Control

const GAME_VERSION: String = "v1.2.8"
const FALLBACK_REDEEM_CODES: Dictionary = {
	"LAMPORGIFT": {"type": "coins", "quantity": 2500, "description": "hadiah untuk kalian!"}
}

var horror_backdrop: Control
var menu_anim_time: float = 0.0
var menu_anchor: Control
var main_content: VBoxContainer
var title_label: Label
var subtitle_label: Label
var title_rule: ColorRect
var stats_label: Label
var top_right_bar: HBoxContainer
var version_label: Label
var copyright_label: Label
var exit_button: Button
var continue_button: Button
var modal_overlays: Array[ColorRect] = []
var modal_panels: Array[PanelContainer] = []
var difficulty_buttons: Array[Button] = []
var warning_overlay: ColorRect
var warning_panel: PanelContainer
var difficulty_overlay: ColorRect
var difficulty_panel: PanelContainer
var settings_overlay: ColorRect
var settings_panel: PanelContainer
var credits_overlay: ColorRect
var credits_panel: PanelContainer
var shop_overlay: ColorRect
var shop_panel: PanelContainer
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
var update_restart_panel: PanelContainer
var update_restart_status: Label
var nightmare_button: Button
var nightmare_lock_label: Label
var volume_slider: HSlider
var fullscreen_button: Button
var settings_scroll: ScrollContainer
var settings_tab_btn: Button
var guide_tab_btn: Button
var settings_tab_box: VBoxContainer
var guide_tab_box: VBoxContainer
var shop_scroll: ScrollContainer
var mouse_sensitivity_slider: HSlider
var camera_sensitivity_slider: HSlider
var brightness_slider: HSlider
var mouse_sensitivity_value: Label
var camera_sensitivity_value: Label
var brightness_value: Label
var volume_value: Label
var graphics_option: OptionButton
var start_button: Button

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_sync_pck_resources()
	GameManager.current_state = GameManager.GameState.MENU
	_build_menu()
	UpdateManager.update_available.connect(_on_update_available)
	UpdateManager.update_installed.connect(_on_update_installed)
	UpdateManager.update_failed.connect(_on_update_failed)
	UpdateManager.up_to_date.connect(_on_update_up_to_date)
	UpdateManager.fix_notes_updated.connect(_on_fix_notes_updated)
	get_viewport().size_changed.connect(_apply_layout)
	if main_content:
		main_content.minimum_size_changed.connect(_sync_menu_anchor_position)
	_apply_layout()
	call_deferred("_apply_layout")
	HorrorTheme.animate_surface_enter(menu_anchor)
	if start_button:
		start_button.call_deferred("grab_focus")
	call_deferred("_check_for_game_updates")

func _process(delta: float) -> void:
	menu_anim_time += delta
	if horror_backdrop:
		horror_backdrop.queue_redraw()

func _build_menu() -> void:
	var background := ColorRect.new()
	background.color = HorrorTheme.BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	horror_backdrop = Control.new()
	horror_backdrop.name = "HorrorBackdrop"
	horror_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	horror_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	horror_backdrop.draw.connect(_draw_horror_backdrop)
	add_child(horror_backdrop)

	menu_anchor = Control.new()
	menu_anchor.name = "MenuAnchor"
	menu_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu_anchor)

	main_content = VBoxContainer.new()
	main_content.name = "MainContent"
	main_content.alignment = BoxContainer.ALIGNMENT_CENTER
	main_content.add_theme_constant_override("separation", 10)
	main_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_anchor.add_child(main_content)

	var header_block := VBoxContainer.new()
	header_block.add_theme_constant_override("separation", 3)
	header_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_content.add_child(header_block)

	title_label = _make_label("LAMPOR", 52, HorrorTheme.ACCENT, HORIZONTAL_ALIGNMENT_LEFT, "display")
	title_label.add_theme_constant_override("outline_size", 8)
	title_label.add_theme_color_override("font_outline_color", HorrorTheme.SCRIM)
	header_block.add_child(title_label)

	subtitle_label = _make_label("MALAM JAHANAM", 13, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "label-lg")
	header_block.add_child(subtitle_label)

	title_rule = ColorRect.new()
	title_rule.color = Color(HorrorTheme.ACCENT.r, HorrorTheme.ACCENT.g, HorrorTheme.ACCENT.b, 0.55)
	title_rule.custom_minimum_size = Vector2(180.0, 1.0)
	title_rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_block.add_child(title_rule)

	stats_label = _make_label("", 12, HorrorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT, "mono-sm")
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_content.add_child(stats_label)
	_refresh_currency_display()

	var menu_buttons := VBoxContainer.new()
	menu_buttons.name = "MenuButtons"
	menu_buttons.add_theme_constant_override("separation", 4)
	main_content.add_child(menu_buttons)

	var has_save: bool = GameManager.has_saved_run()
	continue_button = _make_nav_button("LANJUTKAN MALAM", true)
	continue_button.visible = has_save
	continue_button.pressed.connect(_on_continue_pressed)
	menu_buttons.add_child(continue_button)

	start_button = _make_nav_button("MULAI PERMAINAN", not has_save)
	start_button.pressed.connect(func() -> void: _open_modal(warning_overlay, warning_panel))
	menu_buttons.add_child(start_button)

	var shop_button := _make_nav_button("TOKO BEKAL")
	shop_button.pressed.connect(func() -> void:
		_refresh_shop_display()
		_open_modal(shop_overlay, shop_panel)
	)
	menu_buttons.add_child(shop_button)

	var settings_button := _make_nav_button("PENGATURAN & PANDUAN")
	settings_button.pressed.connect(func() -> void:
		_select_settings_tab(0)
		_open_modal(settings_overlay, settings_panel)
	)
	menu_buttons.add_child(settings_button)

	fix_notes_button = _make_nav_button("CATATAN PEMBARUAN")
	fix_notes_button.pressed.connect(_show_fix_notes)
	menu_buttons.add_child(fix_notes_button)

	var credits_button := _make_nav_button("HAK CIPTA")
	credits_button.pressed.connect(func() -> void: _open_modal(credits_overlay, credits_panel))
	menu_buttons.add_child(credits_button)

	top_right_bar = HBoxContainer.new()
	top_right_bar.name = "TopRightBar"
	top_right_bar.alignment = BoxContainer.ALIGNMENT_END
	top_right_bar.add_theme_constant_override("separation", 12)
	top_right_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(top_right_bar)

	update_button = Button.new()
	update_button.text = "UPDATE TERSEDIA"
	update_button.visible = false
	update_button.custom_minimum_size = Vector2(0.0, 36.0)
	HorrorTheme.style_button(update_button, "primary", 11, true)
	update_button.pressed.connect(_on_update_button_pressed)
	top_right_bar.add_child(update_button)

	version_label = _make_label(GAME_VERSION, 12, HorrorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_RIGHT, "mono-sm")
	top_right_bar.add_child(version_label)

	copyright_label = _make_label("© 2026 AstraDev", 11, HorrorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT, "label-sm")
	copyright_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	add_child(copyright_label)

	exit_button = Button.new()
	exit_button.text = "KELUAR"
	HorrorTheme.style_button(exit_button, "ghost", 12, true)
	exit_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	exit_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	exit_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	exit_button.custom_minimum_size = Vector2(104.0, 44.0)
	exit_button.pressed.connect(func() -> void: get_tree().quit())
	add_child(exit_button)

	_build_warning_modal()
	_build_difficulty_modal()
	_build_settings_modal()
	_build_shop_modal()
	_build_credits_modal()
	_build_fix_notes_modal()
	_build_update_restart_modal()

func _open_modal(overlay: ColorRect, panel: PanelContainer) -> void:
	if not overlay:
		return
	overlay.visible = true
	overlay.move_to_front()
	if panel:
		HorrorTheme.animate_surface_enter(panel)
	var first_btn: Button = _find_first_focusable_button(panel)
	if first_btn:
		first_btn.call_deferred("grab_focus")

func _close_topmost_modal() -> bool:
	for i in range(modal_overlays.size() - 1, -1, -1):
		var ov: ColorRect = modal_overlays[i]
		if is_instance_valid(ov) and ov.visible:
			ov.visible = false
			if start_button:
				start_button.call_deferred("grab_focus")
			return true
	return false

func _find_first_focusable_button(root: Node) -> Button:
	if root == null:
		return null
	for child: Node in root.get_children():
		if child is Button and child.visible and not (child as Button).disabled:
			return child as Button
		var nested: Button = _find_first_focusable_button(child)
		if nested != null:
			return nested
	return null

func _build_warning_modal() -> void:
	var modal: Dictionary = _create_modal("PERINGATAN KONTEN")
	warning_overlay = modal["overlay"] as ColorRect
	warning_panel = modal["panel"] as PanelContainer
	var body: VBoxContainer = modal["body"] as VBoxContainer

	var warning := _make_label(
		"Permainan ini mengandung jumpscare mendadak, suara keras, kilatan cahaya, dan visual horor.\n\nAtur volume pada tingkat yang nyaman dan hentikan permainan bila merasa tidak nyaman.",
		15,
		HorrorTheme.ON_SURFACE,
		HORIZONTAL_ALIGNMENT_LEFT,
		"body-lg"
	)
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(warning)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(buttons)

	var back := _make_button("KEMBALI", false, "ghost")
	back.pressed.connect(func() -> void: warning_overlay.visible = false)
	buttons.add_child(back)

	var cont_btn := _make_button("SAYA MENGERTI", true)
	cont_btn.pressed.connect(func() -> void:
		warning_overlay.visible = false
		_update_nightmare_status()
		_open_modal(difficulty_overlay, difficulty_panel)
	)
	buttons.add_child(cont_btn)

func _build_difficulty_modal() -> void:
	var modal: Dictionary = _create_modal("PILIH TINGKAT KESULITAN")
	difficulty_overlay = modal["overlay"] as ColorRect
	difficulty_panel = modal["panel"] as PanelContainer
	var body: VBoxContainer = modal["body"] as VBoxContainer
	var hint := _make_label("Selesaikan ritual sebelum pukul 05.00 WIB. Tingkat lebih tinggi mempercepat malam dan perburuan Lampor.", 13, HorrorTheme.ON_SURFACE_VARIANT, HORIZONTAL_ALIGNMENT_LEFT, "body-md")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(hint)
	difficulty_buttons.clear()

	var tutorial_btn := _make_button("TUTORIAL PEMULA  ·  Panduan Interaktif (Easy)", false, "ghost")
	tutorial_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	tutorial_btn.pressed.connect(func() -> void:
		for overlay: ColorRect in modal_overlays:
			overlay.visible = false
		if GameManager.has_method("start_tutorial_game"):
			GameManager.start_tutorial_game()
		else:
			GameManager.start_new_game(GameManager.Difficulty.EASY)
	)
	body.add_child(tutorial_btn)
	difficulty_buttons.append(tutorial_btn)

	body.add_child(HorrorTheme.make_hairline_divider())

	var easy := _make_button("EASY  ·  Malam Sunyi (1 mnt = 4,5 dtk)")
	easy.alignment = HORIZONTAL_ALIGNMENT_LEFT
	easy.pressed.connect(func() -> void: _start_with_difficulty(GameManager.Difficulty.EASY))
	body.add_child(easy)
	difficulty_buttons.append(easy)

	var normal := _make_button("NORMAL  ·  Malam Keramat (1 mnt = 3 dtk)")
	normal.alignment = HORIZONTAL_ALIGNMENT_LEFT
	normal.pressed.connect(func() -> void: _start_with_difficulty(GameManager.Difficulty.NORMAL))
	body.add_child(normal)
	difficulty_buttons.append(normal)

	var hard := _make_button("HARD  ·  Malam Jahanam (1 mnt = 1 dtk)")
	hard.alignment = HORIZONTAL_ALIGNMENT_LEFT
	hard.pressed.connect(func() -> void: _start_with_difficulty(GameManager.Difficulty.HARD))
	body.add_child(hard)
	difficulty_buttons.append(hard)

	nightmare_button = _make_button("NIGHTMARE  ·  Kutukan Keranda (1 mnt = 0,5 dtk)", true)
	nightmare_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	nightmare_button.pressed.connect(func() -> void: _start_with_difficulty(GameManager.Difficulty.NIGHTMARE))
	body.add_child(nightmare_button)
	difficulty_buttons.append(nightmare_button)

	nightmare_lock_label = _make_label("", 12, HorrorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT, "label-sm")
	nightmare_lock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(nightmare_lock_label)

	var back := _make_button("KEMBALI", false, "ghost")
	back.pressed.connect(func() -> void: difficulty_overlay.visible = false)
	body.add_child(back)
	difficulty_buttons.append(back)

func _build_settings_modal() -> void:
	var modal: Dictionary = _create_modal("PENGATURAN & PANDUAN")
	settings_overlay = modal["overlay"] as ColorRect
	settings_panel = modal["panel"] as PanelContainer
	var body: VBoxContainer = modal["body"] as VBoxContainer

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	body.add_child(tab_row)

	settings_tab_btn = _make_button("PENGATURAN", true)
	settings_tab_btn.custom_minimum_size.y = 40.0
	settings_tab_btn.pressed.connect(func() -> void: _select_settings_tab(0))
	tab_row.add_child(settings_tab_btn)

	guide_tab_btn = _make_button("PANDUAN BERMAIN", false, "ghost")
	guide_tab_btn.custom_minimum_size.y = 40.0
	guide_tab_btn.pressed.connect(func() -> void: _select_settings_tab(1))
	tab_row.add_child(guide_tab_btn)

	settings_scroll = ScrollContainer.new()
	settings_scroll.custom_minimum_size = Vector2(0, 290)
	settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	HorrorTheme.style_scroll_container(settings_scroll)
	body.add_child(settings_scroll)

	var settings_margin := MarginContainer.new()
	settings_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	settings_margin.add_theme_constant_override("margin_right", 10)
	settings_scroll.add_child(settings_margin)

	var tab_stack := VBoxContainer.new()
	tab_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_stack.mouse_filter = Control.MOUSE_FILTER_PASS
	settings_margin.add_child(tab_stack)

	settings_tab_box = VBoxContainer.new()
	settings_tab_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_tab_box.mouse_filter = Control.MOUSE_FILTER_PASS
	settings_tab_box.add_theme_constant_override("separation", 10)
	tab_stack.add_child(settings_tab_box)

	var initial_volume: float = clampf(db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0, 0.0, 100.0)
	volume_slider = _add_slider_setting(settings_tab_box, "Volume", initial_volume, 0.0, 100.0, 1.0, _on_volume_changed)
	mouse_sensitivity_slider = _add_slider_setting(settings_tab_box, "Sensitivitas Mouse", SettingsManager.mouse_sensitivity * 100.0, 25.0, 200.0, 5.0, _on_mouse_sensitivity_changed)
	camera_sensitivity_slider = _add_slider_setting(settings_tab_box, "Sensitivitas Kamera", SettingsManager.camera_sensitivity * 100.0, 25.0, 200.0, 5.0, _on_camera_sensitivity_changed)
	var sensitivity_note := _make_label("Mouse untuk desktop · Kamera untuk geser layar sentuh", 11, HorrorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT, "label-sm")
	settings_tab_box.add_child(sensitivity_note)
	brightness_slider = _add_slider_setting(settings_tab_box, "Kecerahan", SettingsManager.brightness * 100.0, 50.0, 150.0, 5.0, _on_brightness_changed)

	var graphics_row := HBoxContainer.new()
	var graphics_label := _make_label("Grafik", 13, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "body-md")
	graphics_label.custom_minimum_size.x = 132.0
	graphics_row.add_child(graphics_label)
	graphics_option = OptionButton.new()
	graphics_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphics_option.custom_minimum_size.y = 40.0
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
	HorrorTheme.style_option_button(graphics_option)
	graphics_row.add_child(graphics_option)
	settings_tab_box.add_child(graphics_row)

	fullscreen_button = _make_button("GANTI MODE LAYAR")
	fullscreen_button.pressed.connect(_toggle_fullscreen)
	settings_tab_box.add_child(fullscreen_button)

	settings_tab_box.add_child(HorrorTheme.make_hairline_divider())

	auto_update_check = CheckButton.new()
	auto_update_check.text = "Unduh & pasang update otomatis"
	auto_update_check.custom_minimum_size.y = 42.0
	auto_update_check.button_pressed = SettingsManager.auto_update
	auto_update_check.toggled.connect(SettingsManager.set_auto_update)
	HorrorTheme.style_check_button(auto_update_check)
	settings_tab_box.add_child(auto_update_check)

	update_check_button = _make_button("PERIKSA PEMBARUAN GAME")
	update_check_button.pressed.connect(func() -> void:
		update_check_button.text = "MEMERIKSA PEMBARUAN..."
		update_status_label.text = "Menghubungi GitHub..."
		UpdateManager.check_for_updates(true)
	)
	settings_tab_box.add_child(update_check_button)

	update_status_label = _make_label("Pembaruan diperiksa melalui branch main GitHub.", 11, HorrorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT, "label-sm")
	update_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_tab_box.add_child(update_status_label)

	settings_tab_box.add_child(HorrorTheme.make_hairline_divider())

	var redeem_title := _make_label("KODE REDEEM", 13, HorrorTheme.PRIMARY, HORIZONTAL_ALIGNMENT_LEFT, "label-lg")
	settings_tab_box.add_child(redeem_title)
	var redeem_row := HBoxContainer.new()
	redeem_row.add_theme_constant_override("separation", 8)
	redeem_input = LineEdit.new()
	redeem_input.placeholder_text = "Masukkan kode redeem"
	redeem_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	redeem_input.custom_minimum_size.y = 44.0
	redeem_input.max_length = 32
	HorrorTheme.style_line_edit(redeem_input)
	redeem_row.add_child(redeem_input)
	var redeem_button := _make_button("TUKAR", true)
	redeem_button.custom_minimum_size = Vector2(96.0, 44.0)
	redeem_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	redeem_button.pressed.connect(_on_redeem_pressed)
	redeem_row.add_child(redeem_button)
	settings_tab_box.add_child(redeem_row)

	redeem_result_label = _make_label("Setiap kode hanya dapat digunakan sekali pada save ini.", 11, HorrorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT, "label-sm")
	redeem_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_tab_box.add_child(redeem_result_label)

	guide_tab_box = VBoxContainer.new()
	guide_tab_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_tab_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_tab_box.visible = false
	tab_stack.add_child(guide_tab_box)

	var guide := RichTextLabel.new()
	guide.bbcode_enabled = true
	guide.fit_content = true
	guide.scroll_active = false
	guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide.add_theme_font_override("normal_font", HorrorTheme.get_body_font())
	guide.add_theme_font_override("bold_font", HorrorTheme.get_serif_font(1, true))
	guide.add_theme_color_override("default_color", HorrorTheme.ON_SURFACE)
	guide.add_theme_font_size_override("normal_font_size", 14)
	guide.add_theme_font_size_override("bold_font_size", 14)
	guide.add_theme_constant_override("line_separation", 6)
	guide.text = "[color=#ffb4ac][b]TUJUAN PERMAINAN[/b][/color]\nBertahan mulai pukul 01.00 WIB hingga ritual tuntas sebelum pukul 05.00 WIB. Nyalakan 5 obor, amankan 3 pintu rumah, kumpulkan 4 benda ritual, lalu bakar semuanya di tungku balai desa. Bila pukul 05.00 WIB tiba sebelum tuntas, Lampor akan langsung melahapmu.\n\n[color=#ffb4ac][b]KONTROL DESKTOP[/b][/color]\n• W, A, S, D: Bergerak\n• Mouse: Melihat ke sekitar\n• Shift: Berlari\n• E: Interaksi, nyalakan obor, palang pintu, sembunyi, & pakai Jamu/Baterai/Kentongan\n• F: Senter\n• 1-5: Pilih slot hotbar\n• Tab / B: Buka tas inventori (15 slot)\n• G: Jatuhkan barang\n• Esc: Jeda permainan\n\n[color=#ffb4ac][b]KONTROL MOBILE[/b][/color]\nGunakan joystick kiri untuk bergerak, geser sisi kanan layar untuk menoleh, dan sentuh tombol aksi di layar untuk lari, interaksi (ikon Tangan), senter, tas, serta jeda.\n\n[color=#ffb4ac][b]MENGHADAPI LAMPOR[/b][/color]\n• Jangan menatap langsung keranda Lampor; segera palingkan pandangan.\n• Saat lonceng mendekat, matikan senter dan bersembunyilah di rumah atau lemari.\n• Pukul Kentongan [E] untuk mengusir kejaran Lampor selama 5 detik (sekali pakai, maks. 5).\n• Area obor yang menyala membantu memulihkan kewarasan.\n• Mode Nightmare terbuka setelah 5 kemenangan."
	guide_tab_box.add_child(guide)

	var close := _make_button("TUTUP", false, "ghost")
	close.pressed.connect(func() -> void: settings_overlay.visible = false)
	body.add_child(close)

func _select_settings_tab(tab_idx: int) -> void:
	var show_settings: bool = (tab_idx == 0)
	if settings_tab_box:
		settings_tab_box.visible = show_settings
	if guide_tab_box:
		guide_tab_box.visible = not show_settings
	if settings_tab_btn:
		HorrorTheme.style_button(settings_tab_btn, "primary" if show_settings else "ghost", 12, true)
	if guide_tab_btn:
		HorrorTheme.style_button(guide_tab_btn, "primary" if not show_settings else "ghost", 12, true)
	if settings_scroll:
		settings_scroll.scroll_vertical = 0

func _add_slider_setting(parent: VBoxContainer, title_text: String, initial_value: float, min_value: float, max_value: float, step_value: float, callback: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var title := _make_label(title_text, 13, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "body-md")
	title.custom_minimum_size.x = 132.0
	row.add_child(title)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step_value
	slider.value = initial_value
	slider.custom_minimum_size.y = 28.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	HorrorTheme.style_slider(slider)
	var value_label := _make_label("%d%%" % int(round(initial_value)), 12, HorrorTheme.SECONDARY, HORIZONTAL_ALIGNMENT_RIGHT, "mono-sm")
	value_label.custom_minimum_size.x = 46.0
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
	var modal: Dictionary = _create_modal("TOKO BEKAL")
	shop_overlay = modal["overlay"] as ColorRect
	shop_panel = modal["panel"] as PanelContainer
	var body: VBoxContainer = modal["body"] as VBoxContainer

	shop_balance_label = _make_label("Koin Emas: %d" % GameManager.coins, 12, HorrorTheme.RELIC_BRASS, HORIZONTAL_ALIGNMENT_LEFT, "mono-sm")
	shop_balance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(shop_balance_label)

	shop_scroll = ScrollContainer.new()
	shop_scroll.custom_minimum_size = Vector2(0.0, 270.0)
	shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	HorrorTheme.style_scroll_container(shop_scroll)
	body.add_child(shop_scroll)

	var shop_margin := MarginContainer.new()
	shop_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	shop_margin.add_theme_constant_override("margin_right", 10)
	shop_scroll.add_child(shop_margin)

	var offers := VBoxContainer.new()
	offers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offers.mouse_filter = Control.MOUSE_FILTER_PASS
	offers.add_theme_constant_override("separation", 2)
	shop_margin.add_child(offers)

	_add_shop_offer(offers, "Jamu Tolak Bala x1", "Pulihkan 45 kewarasan dan seluruh stamina.", "30 Koin", "jamu", 1)
	_add_shop_offer(offers, "Jamu Tolak Bala x3", "Persediaan jamu tiga kali pakai.", "90 Koin", "jamu", 3)
	_add_shop_offer(offers, "Baterai Senter x1", "Isi ulang 50% daya senter.", "20 Koin", "baterai", 1)
	_add_shop_offer(offers, "Kentongan x1", "Usir kejaran Lampor selama 5 detik (1x pakai).", "50 Koin", "kentongan", 1)
	_add_shop_offer(offers, "Nyawa Tambahan x1", "Bangkit sekali di titik awal saat terbunuh.", "80 Koin", "extra_life", 1)
	_add_shop_offer(offers, "Nyawa Tambahan x2", "Dua kesempatan bangkit tambahan.", "150 Koin", "extra_life", 2)
	_add_shop_offer(offers, "Nyawa Tambahan x3", "Tiga kesempatan bangkit tambahan.", "210 Koin", "extra_life", 3)

	shop_result_label = _make_label("Batas simpan: maks. 5 item & 5 nyawa tambahan.", 11, HorrorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT, "label-sm")
	shop_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(shop_result_label)

	var close := _make_button("TUTUP", false, "ghost")
	close.pressed.connect(func() -> void: shop_overlay.visible = false)
	body.add_child(close)

func _add_shop_offer(parent: VBoxContainer, title_text: String, description: String, price_text: String, item_id: String, quantity: int) -> void:
	if parent.get_child_count() > 0:
		parent.add_child(HorrorTheme.make_hairline_divider(Color(HorrorTheme.OUTLINE_VARIANT.r, HorrorTheme.OUTLINE_VARIANT.g, HorrorTheme.OUTLINE_VARIANT.b, 0.35)))

	var row_pad := MarginContainer.new()
	row_pad.mouse_filter = Control.MOUSE_FILTER_PASS
	row_pad.add_theme_constant_override("margin_top", 8)
	row_pad.add_theme_constant_override("margin_bottom", 8)
	parent.add_child(row_pad)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 12)
	row_pad.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var heading := _make_label(title_text, 14, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "title-lg")
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(heading)

	var detail := _make_label(description, 12, HorrorTheme.ON_SURFACE_VARIANT, HORIZONTAL_ALIGNMENT_LEFT, "label-sm")
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(detail)

	var buy := Button.new()
	buy.text = price_text
	buy.custom_minimum_size = Vector2(98.0, 44.0)
	buy.size_flags_horizontal = Control.SIZE_SHRINK_END
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	HorrorTheme.style_button(buy, "primary", 12, true)
	buy.pressed.connect(func() -> void: _purchase_shop_item(item_id, quantity))
	row.add_child(buy)

func _refresh_currency_display() -> void:
	if stats_label:
		stats_label.text = "%d Kemenangan  ·  %d Koin  ·  %d Nyawa" % [GameManager.total_wins, GameManager.coins, GameManager.extra_lives]

func _refresh_shop_display() -> void:
	if shop_balance_label:
		shop_balance_label.text = "Koin: %d  ·  Nyawa: %d/%d  ·  Jamu: %d/%d  ·  Baterai: %d/%d  ·  Kentongan: %d/%d" % [
			GameManager.coins,
			GameManager.extra_lives,
			GameManager.MAX_EXTRA_LIVES,
			GameManager.item_stash.get("jamu", 0),
			GameManager.MAX_SHOP_ITEM_QTY,
			GameManager.item_stash.get("baterai", 0),
			GameManager.MAX_SHOP_ITEM_QTY,
			GameManager.item_stash.get("kentongan", 0),
			GameManager.MAX_SHOP_ITEM_QTY
		]

func _purchase_shop_item(item_id: String, quantity: int) -> void:
	var result: Dictionary = GameManager.purchase_shop_item(item_id, quantity)
	shop_result_label.text = str(result.get("message", "Transaksi gagal."))
	shop_result_label.add_theme_color_override("font_color", HorrorTheme.SUCCESS_SAGE if bool(result.get("success", false)) else HorrorTheme.ERROR)
	_refresh_shop_display()
	_refresh_currency_display()

func _sync_pck_resources() -> void:
	if not bool(UpdateManager.get("pck_loaded_this_session")):
		return
	var codes_path: String = "res://scripts/systems/RedemptionCodes.gd"
	if ResourceLoader.exists(codes_path):
		var fresh_codes: Resource = ResourceLoader.load(codes_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if fresh_codes:
			var gdc_path: String = codes_path.get_basename() + ".gdc"
			if ResourceLoader.exists(gdc_path):
				fresh_codes.take_over_path(gdc_path)
			fresh_codes.take_over_path(codes_path)

func _normalize_redeem_code(raw_code: String) -> String:
	var upper: String = raw_code.strip_edges().to_upper()
	var cleaned: String = ""
	for i: int in range(upper.length()):
		var ch_code: int = upper.unicode_at(i)
		if (ch_code >= 65 and ch_code <= 90) or (ch_code >= 48 and ch_code <= 57):
			cleaned += upper[i]
	return cleaned

func _on_redeem_pressed() -> void:
	var normalized: String = _normalize_redeem_code(redeem_input.text)
	var result: Dictionary = GameManager.redeem_code(normalized)
	if not bool(result.get("success", false)) and not normalized.is_empty() and not GameManager.redeemed_codes.has(normalized):
		var reward: Dictionary = {}
		var codes_script: Variant = ResourceLoader.load("res://scripts/systems/RedemptionCodes.gd", "", ResourceLoader.CACHE_MODE_IGNORE)
		if codes_script:
			reward = codes_script.get_reward(normalized)
		if reward.is_empty() and FALLBACK_REDEEM_CODES.has(normalized):
			reward = (FALLBACK_REDEEM_CODES[normalized] as Dictionary).duplicate(true)
		if not reward.is_empty():
			GameManager.apply_reward(reward)
			GameManager.redeemed_codes.append(normalized)
			GameManager.save_game_data()
			result = {"success": true, "message": "Berhasil menukarkan kode: %s." % str(reward.get("description", "Hadiah diterima"))}
	redeem_result_label.text = str(result.get("message", "Kode gagal diproses."))
	redeem_result_label.add_theme_color_override("font_color", HorrorTheme.SUCCESS_SAGE if bool(result.get("success", false)) else HorrorTheme.ERROR)
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
		update_status_label.text = "Update %s berhasil diterapkan. Mulai ulang permainan agar seluruh perubahan dimuat." % commit_sha.substr(0, 10)
		update_button.tooltip_text = "Proyek sudah sama dengan commit %s" % commit_sha.substr(0, 10)
		_show_update_restart_prompt(commit_sha)
	else:
		update_status_label.text = "Paket source %s sudah diekstrak ke penyimpanan aplikasi, tetapi belum dapat mengganti APK/PCK yang sedang berjalan." % commit_sha.substr(0, 10)
		update_button.tooltip_text = "Source hasil ekstrak: %s" % destination_path

func _build_update_restart_modal() -> void:
	var modal: Dictionary = _create_modal("PEMBARUAN SIAP")
	update_restart_overlay = modal["overlay"] as ColorRect
	update_restart_panel = modal["panel"] as PanelContainer
	var body: VBoxContainer = modal["body"] as VBoxContainer
	var explanation := _make_label("Semua perubahan terbaru sudah siap diterapkan. Mulai ulang permainan sekarang agar skrip, scene, dan aset terbaru dimuat. Progres disimpan otomatis.", 14, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "body-md")
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(explanation)
	update_restart_status = _make_label("Disarankan: mulai ulang sekarang.", 12, HorrorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT, "mono-sm")
	update_restart_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(update_restart_status)
	var restart_label: String = "MUAT ULANG HALAMAN" if OS.has_feature("web") else ("TUTUP GAME UNTUK MENERAPKAN" if OS.has_feature("android") else "MULAI ULANG SEKARANG")
	var restart := _make_button(restart_label, true)
	restart.pressed.connect(_restart_after_update)
	body.add_child(restart)
	var later := _make_button("NANTI", false, "ghost")
	later.pressed.connect(func() -> void:
		update_restart_overlay.visible = false
		update_status_label.text = "Pembaruan siap. Muat ulang halaman untuk menerapkan." if OS.has_feature("web") else "Pembaruan siap. Tutup permainan lalu buka kembali Lampor."
	)
	body.add_child(later)

func _show_update_restart_prompt(commit_sha: String) -> void:
	if update_restart_overlay == null:
		return
	if OS.has_feature("web"):
		update_restart_status.text = "Commit terpasang: %s · Muat ulang halaman untuk menerapkan." % commit_sha.substr(0, 10)
	elif OS.has_feature("android"):
		update_restart_status.text = "Commit terpasang: %s · Tutup game lalu buka kembali." % commit_sha.substr(0, 10)
	else:
		update_restart_status.text = "Commit terpasang: %s · Mulai ulang disarankan." % commit_sha.substr(0, 10)
	_open_modal(update_restart_overlay, update_restart_panel)

func _restart_after_update() -> void:
	if update_restart_status:
		update_restart_status.text = "Menyimpan progres dan memulai ulang..."
	GameManager.save_active_run()
	GameManager.save_game_data()
	if OS.has_feature("web"):
		if Engine.has_singleton("JavaScriptBridge"):
			var js: Object = Engine.get_singleton("JavaScriptBridge")
			js.call("eval", "(function(){var r=function(){window.location.reload();};try{if(typeof FS!=='undefined'&&FS.syncfs){FS.syncfs(false,function(){setTimeout(r,150);});setTimeout(r,1200);return;}}catch(e){}setTimeout(r,450);})();")
		return
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
			update_restart_status.text = "Tidak dapat memulai ulang otomatis. Tutup lalu buka kembali Lampor secara manual."
		return
	get_tree().quit()

func _on_update_failed(message: String) -> void:
	if update_button:
		update_button.disabled = false
		update_button.visible = not UpdateManager.is_git_working_copy()
		update_button.text = "COBA UPDATE LAGI"
		update_button.tooltip_text = message
	if update_check_button:
		update_check_button.text = "PERIKSA PEMBARUAN GAME"
	if update_status_label:
		update_status_label.text = message

func _on_update_button_pressed() -> void:
	update_button.disabled = true
	update_button.text = "MENGUNDUH..."
	UpdateManager.download_update()

func _build_fix_notes_modal() -> void:
	_ensure_markdown_regexes()
	var modal: Dictionary = _create_modal("CATATAN PEMBARUAN")
	fix_notes_overlay = modal["overlay"] as ColorRect
	fix_notes_panel = modal["panel"] as PanelContainer
	var body: VBoxContainer = modal["body"] as VBoxContainer
	fix_notes_hint_label = _make_label("Catatan perubahan dari FIX_NOTES.md pada versi game saat ini.", 12, HorrorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT, "label-sm")
	fix_notes_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(fix_notes_hint_label)

	fix_notes_scroll = ScrollContainer.new()
	fix_notes_scroll.custom_minimum_size = Vector2(0, 340)
	fix_notes_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fix_notes_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fix_notes_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	fix_notes_scroll.get_v_scroll_bar().value_changed.connect(_on_fix_notes_scroll_value_changed)
	HorrorTheme.style_scroll_container(fix_notes_scroll)
	body.add_child(fix_notes_scroll)

	var notes_margin := MarginContainer.new()
	notes_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notes_margin.add_theme_constant_override("margin_left", 2)
	notes_margin.add_theme_constant_override("margin_right", 12)
	notes_margin.add_theme_constant_override("margin_top", 4)
	notes_margin.add_theme_constant_override("margin_bottom", 6)
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
	fix_notes_view.add_theme_font_override("normal_font", HorrorTheme.get_body_font())
	fix_notes_view.add_theme_font_override("bold_font", HorrorTheme.get_serif_font(1, true))
	fix_notes_view.add_theme_font_override("mono_font", HorrorTheme.get_mono_font())
	fix_notes_view.add_theme_color_override("default_color", HorrorTheme.ON_SURFACE)
	fix_notes_view.add_theme_font_size_override("normal_font_size", 14)
	fix_notes_view.add_theme_font_size_override("bold_font_size", 14)
	fix_notes_view.add_theme_font_size_override("italics_font_size", 14)
	fix_notes_view.add_theme_font_size_override("mono_font_size", 12)
	fix_notes_view.add_theme_constant_override("line_separation", 7)
	notes_column.add_child(fix_notes_view)

	fix_notes_more_label = _make_label("Gulir ke bawah untuk memuat catatan versi sebelumnya...", 12, HorrorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER, "label-sm")
	fix_notes_more_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fix_notes_more_label.visible = false
	notes_column.add_child(fix_notes_more_label)

	var close := _make_button("TUTUP", false, "ghost")
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
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_ESCAPE:
			if graphics_option and graphics_option.get_popup().visible:
				return
			if _close_topmost_modal():
				get_viewport().set_input_as_handled()
				return

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
	_open_modal(fix_notes_overlay, fix_notes_panel)
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
				output.append("[bgcolor=#1d100f][color=#f7ddda][code] " + "\n".join(code_lines).replace("[", "[lb]").replace("]", "[rb]") + " [/code][/color][/bgcolor]")
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
			var table_row: String = "  [color=#a98e8b]|[/color]  ".join(rendered_cells)
			if not in_table:
				output.append("[b][color=#ffb4ac]" + table_row + "[/color][/b]")
				in_table = true
			else:
				output.append(table_row)
			continue
		else:
			in_table = false
		if trimmed in ["---", "***", "___"]:
			output.append("[font_size=8] [/font_size]")
			continue
		if trimmed.begins_with("### "):
			if output.size() > 0:
				output.append("[font_size=6] [/font_size]")
			output.append("[font_size=15][b][color=#e1bebb]" + _markdown_inline(trimmed.substr(4)) + "[/color][/b][/font_size]")
		elif trimmed.begins_with("## "):
			if output.size() > 0:
				output.append("[font_size=12] [/font_size]")
			output.append("[font_size=18][b][color=#ffb4ac]" + _markdown_inline(trimmed.substr(3)) + "[/color][/b][/font_size]")
		elif trimmed.begins_with("# "):
			if output.size() > 0:
				output.append("[font_size=10] [/font_size]")
			output.append("[font_size=20][b][color=#ffedea]" + _markdown_inline(trimmed.substr(2)) + "[/color][/b][/font_size]")
		elif trimmed.begins_with("> "):
			output.append("[color=#d5bdbb][i]|  " + _markdown_inline(trimmed.substr(2)) + "[/i][/color]")
		elif trimmed.begins_with("- [ ] ") or trimmed.begins_with("* [ ] "):
			output.append("[color=#d4433c][ ][/color]  " + _markdown_inline(trimmed.substr(6)))
		elif trimmed.begins_with("- [x] ") or trimmed.begins_with("- [X] ") or trimmed.begins_with("* [x] ") or trimmed.begins_with("* [X] "):
			output.append("[color=#86ba8c][x][/color]  " + _markdown_inline(trimmed.substr(6)))
		elif trimmed.begins_with("- ") or trimmed.begins_with("* ") or trimmed.begins_with("+ "):
			var indent_level: int = mini(leading_spaces / 2, 2)
			if indent_level == 0:
				if output.size() > 0 and not output[output.size() - 1].ends_with("[/font_size]"):
					output.append("[font_size=5] [/font_size]")
				output.append("[color=#ffb4ac]•[/color]  " + _markdown_inline(trimmed.substr(2)))
			else:
				var pad: String = "    ".repeat(indent_level)
				output.append(pad + "[color=#a98e8b]·[/color]  " + _markdown_inline(trimmed.substr(2)))
		else:
			var matched: RegExMatch = _rx_numbered.search(trimmed)
			if matched:
				output.append("[color=#ffb4ac]" + matched.get_string(1) + ".[/color]  " + _markdown_inline(matched.get_string(2)))
			else:
				output.append(_markdown_inline(line))
	if in_code_block:
		output.append("[bgcolor=#1d100f][color=#f7ddda][code] " + "\n".join(code_lines).replace("[", "[lb]").replace("]", "[rb]") + " [/code][/color][/bgcolor]")
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
		code_tokens.append("[bgcolor=#261817][color=#ffb4ac][code] %s [/code][/color][/bgcolor]" % raw_code)
		result = result.substr(0, m.get_start()) + token + result.substr(m.get_end())
	result = _rx_links.sub(result, "[url=$2][color=#e1bebb]$1[/color][/url]", true)
	result = _rx_bold.sub(result, "[b]$1[/b]", true)
	result = _rx_strike.sub(result, "[s]$1[/s]", true)
	result = _rx_italic.sub(result, "[i]$1[/i]", true)
	for i in range(code_tokens.size()):
		result = result.replace("\u0001CODE_%d\u0001" % i, code_tokens[i])
	return result

func _build_credits_modal() -> void:
	var modal: Dictionary = _create_modal("HAK CIPTA")
	credits_overlay = modal["overlay"] as ColorRect
	credits_panel = modal["panel"] as PanelContainer
	var body: VBoxContainer = modal["body"] as VBoxContainer

	var title_copy := _make_label("LAMPOR: Malam Jahanam", 17, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "title-lg")
	body.add_child(title_copy)

	var copy := _make_label(
		"© 2026 AstraDev. Seluruh hak cipta dilindungi.\nKarya fiksi survival horror yang terinspirasi dari folklor Indonesia.",
		14,
		HorrorTheme.ON_SURFACE_VARIANT,
		HORIZONTAL_ALIGNMENT_LEFT,
		"body-md"
	)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(copy)

	var close := _make_button("TUTUP", false, "ghost")
	close.pressed.connect(func() -> void: credits_overlay.visible = false)
	body.add_child(close)

func _create_modal(title_text: String) -> Dictionary:
	var overlay := ColorRect.new()
	overlay.color = Color(HorrorTheme.SCRIM_DARK.r, HorrorTheme.SCRIM_DARK.g, HorrorTheme.SCRIM_DARK.b, 0.78)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	panel.add_child(body)

	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 8)
	body.add_child(header_box)

	var title := _make_label(title_text, 19, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "headline-md")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_box.add_child(title)

	header_box.add_child(HorrorTheme.make_hairline_divider())

	modal_overlays.append(overlay)
	modal_panels.append(panel)
	return {"overlay": overlay, "panel": panel, "body": body}

func _make_label(text_value: String, font_size: int, color: Color, alignment: int, role: String = "body-md") -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	HorrorTheme.style_label(label, role, color, font_size)
	return label

func _draw_horror_backdrop() -> void:
	if not horror_backdrop:
		return
	var s: Vector2 = horror_backdrop.size
	if s.x <= 0.0 or s.y <= 0.0:
		return

	var narrow: bool = s.x < 700.0
	var sky_cx: float = s.x * (0.62 if narrow else 0.74)
	var sky_cy: float = s.y * (0.20 if narrow else 0.36)

	# Lingkaran segel ritual samar di langit kanan agar Lampor tetap menonjol tanpa ramai
	var seal_r: float = minf(s.x, s.y) * 0.28
	var seal_rot: float = menu_anim_time * 0.05
	var seal_center := Vector2(sky_cx, sky_cy)
	horror_backdrop.draw_arc(seal_center, seal_r, 0.0, TAU, 56, Color(HorrorTheme.SECONDARY_CONTAINER.r, HorrorTheme.SECONDARY_CONTAINER.g, HorrorTheme.SECONDARY_CONTAINER.b, 0.16), 1.2, true)
	horror_backdrop.draw_arc(seal_center, seal_r * 0.86, 0.0, TAU, 48, Color(HorrorTheme.OUTLINE_VARIANT.r, HorrorTheme.OUTLINE_VARIANT.g, HorrorTheme.OUTLINE_VARIANT.b, 0.12), 1.0, true)
	for i: int in range(8):
		var a: float = seal_rot + float(i) * (TAU / 8.0)
		var p1 := seal_center + Vector2(cos(a), sin(a)) * (seal_r * 0.84)
		var p2 := seal_center + Vector2(cos(a), sin(a)) * (seal_r * 1.03)
		horror_backdrop.draw_line(p1, p2, Color(HorrorTheme.ACCENT.r, HorrorTheme.ACCENT.g, HorrorTheme.ACCENT.b, 0.14), 1.2)

	# Bulan darah redup di langit kanan-tengah
	var moon_pos := Vector2(s.x * (0.40 if narrow else 0.54), s.y * (0.16 if narrow else 0.23))
	var moon_r: float = minf(s.x, s.y) * 0.095
	horror_backdrop.draw_circle(moon_pos, moon_r * 2.4, Color(HorrorTheme.SECONDARY_CONTAINER.r, HorrorTheme.SECONDARY_CONTAINER.g, HorrorTheme.SECONDARY_CONTAINER.b, 0.14))
	horror_backdrop.draw_circle(moon_pos, moon_r * 1.45, Color(HorrorTheme.PRIMARY_CONTAINER.r, HorrorTheme.PRIMARY_CONTAINER.g, HorrorTheme.PRIMARY_CONTAINER.b, 0.18))
	horror_backdrop.draw_circle(moon_pos, moon_r, Color(HorrorTheme.ACCENT.r, HorrorTheme.ACCENT.g, HorrorTheme.ACCENT.b, 0.30))

	# Keranda hijau Lampor melayang di kabut sisi kanan (terbuka penuh tanpa tertutup kartu menu)
	var float_x: float = s.x * (0.76 if narrow else 0.77) + sin(menu_anim_time * 0.65) * 14.0
	var float_y: float = s.y * (0.20 if narrow else 0.35) + cos(menu_anim_time * 1.35) * 8.0
	var kw: float = minf(s.x, s.y) * (0.20 if narrow else 0.19)
	var kh: float = kw * 0.44
	horror_backdrop.draw_circle(Vector2(float_x, float_y), kw * 0.95, Color(HorrorTheme.KERANDA_GLOW.r, HorrorTheme.KERANDA_GLOW.g, HorrorTheme.KERANDA_GLOW.b, 0.16))
	horror_backdrop.draw_rect(Rect2(float_x - kw * 0.72, float_y + kh * 0.36, kw * 1.44, 3.0), Color(HorrorTheme.OUTLINE.r, HorrorTheme.OUTLINE.g, HorrorTheme.OUTLINE.b, 0.48))
	var keranda_poly := PackedVector2Array([
		Vector2(float_x - kw * 0.50, float_y + kh * 0.36),
		Vector2(float_x - kw * 0.50, float_y - kh * 0.12),
		Vector2(float_x - kw * 0.38, float_y - kh * 0.46),
		Vector2(float_x + kw * 0.38, float_y - kh * 0.46),
		Vector2(float_x + kw * 0.50, float_y - kh * 0.12),
		Vector2(float_x + kw * 0.50, float_y + kh * 0.36)
	])
	horror_backdrop.draw_colored_polygon(keranda_poly, Color(HorrorTheme.KERANDA_GLOW.r, HorrorTheme.KERANDA_GLOW.g, HorrorTheme.KERANDA_GLOW.b, 0.78))
	horror_backdrop.draw_rect(Rect2(float_x - kw * 0.50, float_y + kh * 0.22, kw, 3.0), Color(HorrorTheme.RELIC_BRASS.r, HorrorTheme.RELIC_BRASS.g, HorrorTheme.RELIC_BRASS.b, 0.65))
	var eye_alpha: float = 0.55 + 0.40 * sin(menu_anim_time * 3.8)
	horror_backdrop.draw_circle(Vector2(float_x - kw * 0.36, float_y + kh * 0.04), 3.0, Color(HorrorTheme.ACCENT.r, HorrorTheme.ACCENT.g, HorrorTheme.ACCENT.b, eye_alpha))
	horror_backdrop.draw_circle(Vector2(float_x - kw * 0.28, float_y + kh * 0.04), 3.0, Color(HorrorTheme.ACCENT.r, HorrorTheme.ACCENT.g, HorrorTheme.ACCENT.b, eye_alpha))

	# Siluet atap desa & nisan di cakrawala
	var horizon_y: float = s.y * 0.86
	horror_backdrop.draw_rect(Rect2(0.0, horizon_y, s.x, s.y - horizon_y), Color(HorrorTheme.SURFACE_DIM.r, HorrorTheme.SURFACE_DIM.g, HorrorTheme.SURFACE_DIM.b, 0.96))
	var roof_right := PackedVector2Array([
		Vector2(s.x * 0.52, horizon_y),
		Vector2(s.x * 0.57, horizon_y - 42.0),
		Vector2(s.x * 0.66, horizon_y - 42.0),
		Vector2(s.x * 0.71, horizon_y)
	])
	horror_backdrop.draw_colored_polygon(roof_right, Color(HorrorTheme.SURFACE_LOWEST.r, HorrorTheme.SURFACE_LOWEST.g, HorrorTheme.SURFACE_LOWEST.b, 0.96))
	for i: int in range(5):
		var tx: float = s.x * 0.75 + float(i) * 32.0
		var th: float = 20.0 + float(i % 2) * 8.0
		horror_backdrop.draw_rect(Rect2(tx, horizon_y - th, 10.0, th), Color(HorrorTheme.SURFACE.r, HorrorTheme.SURFACE.g, HorrorTheme.SURFACE.b, 0.92))

	# Kabut malam tipis merayap di atas cakrawala
	for i: int in range(4):
		var mist_y: float = horizon_y - 24.0 + float(i) * 9.0
		var mist_x: float = fmod(menu_anim_time * (10.0 + float(i) * 3.5) + float(i) * 210.0, s.x + 280.0) - 280.0
		horror_backdrop.draw_rect(Rect2(mist_x, mist_y, 320.0, 12.0), Color(HorrorTheme.SECONDARY_CONTAINER.r, HorrorTheme.SECONDARY_CONTAINER.g, HorrorTheme.SECONDARY_CONTAINER.b, 0.11))

	# Bara halus melayang
	for i: int in range(12):
		var seed_f: float = float(i) * 43.17
		var px: float = fmod(seed_f * 29.0 + sin(menu_anim_time * 0.75 + seed_f) * 22.0, s.x)
		var py: float = s.y - fmod(menu_anim_time * (14.0 + float(i % 4) * 4.5) + seed_f * 19.0, s.y)
		var ember_col: Color = Color(HorrorTheme.ACCENT.r, HorrorTheme.ACCENT.g, HorrorTheme.ACCENT.b, 0.26) if (i % 3 != 0) else Color(HorrorTheme.KERANDA_GLOW.r, HorrorTheme.KERANDA_GLOW.g, HorrorTheme.KERANDA_GLOW.b, 0.24)
		horror_backdrop.draw_circle(Vector2(px, py), 1.6 + float(i % 2) * 0.6, ember_col)

	# Scrim sisi kiri untuk menjamin keterbacaan tipografi menu di atas latar belakang
	var scrim_w: float = s.x if narrow else s.x * 0.52
	var steps: int = 8
	for step_idx: int in range(steps):
		var t0: float = float(step_idx) / float(steps)
		var t1: float = float(step_idx + 1) / float(steps)
		var band_a: float = lerpf(0.76, 0.0, t0 * t0) if not narrow else 0.52
		var band_x: float = t0 * scrim_w
		var band_w: float = (t1 - t0) * scrim_w + 1.0
		horror_backdrop.draw_rect(Rect2(band_x, 0.0, band_w, s.y), Color(HorrorTheme.SCRIM_DARK.r, HorrorTheme.SCRIM_DARK.g, HorrorTheme.SCRIM_DARK.b, band_a))

func _make_nav_button(text_value: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HorrorTheme.style_button(button, "nav_primary" if primary else "nav", 14, true)
	return button

func _make_button(text_value: String, primary: bool = false, variant_override: String = "") -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var variant: String = variant_override if not variant_override.is_empty() else ("primary" if primary else "secondary")
	HorrorTheme.style_button(button, variant, 13, true)
	return button

func _panel_style() -> StyleBoxFlat:
	return HorrorTheme.make_minimal_panel_style(Color(0.086, 0.045, 0.043, 0.96), HorrorTheme.BORDER_INTERACTIVE, 2, 24, 22)

func _apply_layout() -> void:
	var view_size: Vector2 = get_viewport_rect().size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		view_size = Vector2(1280.0, 720.0)
	var narrow: bool = view_size.x < 700.0
	var short_screen: bool = view_size.y < 520.0

	var left_pad: float = 24.0 if narrow else (34.0 if short_screen else 64.0)
	var col_w: float = clampf(view_size.x - left_pad * 2.0, 260.0, 340.0) if narrow else clampf(view_size.x * 0.34, 280.0, 360.0)

	title_label.add_theme_font_size_override("font_size", 30 if short_screen else (38 if narrow else 52))
	subtitle_label.add_theme_font_size_override("font_size", 11 if short_screen else 13)
	if stats_label:
		stats_label.visible = not (short_screen and view_size.y < 380.0)
		stats_label.add_theme_font_size_override("font_size", 11 if narrow or short_screen else 12)
	main_content.add_theme_constant_override("separation", 6 if short_screen else 10)

	var menu_buttons: VBoxContainer = main_content.get_node("MenuButtons") as VBoxContainer
	menu_buttons.add_theme_constant_override("separation", 2 if short_screen else 4)
	var btn_h: float = 34.0 if (short_screen and view_size.y < 430.0 and continue_button and continue_button.visible) else (36.0 if (short_screen and view_size.y < 430.0) else 44.0)
	for button: Node in menu_buttons.get_children():
		if button is Button:
			var b: Button = button as Button
			b.custom_minimum_size.y = btn_h
			b.add_theme_font_size_override("font_size", 12 if short_screen else 14)

	main_content.custom_minimum_size = Vector2(col_w, 0.0)
	main_content.reset_size()
	_sync_menu_anchor_position()

	for d_btn: Button in difficulty_buttons:
		if is_instance_valid(d_btn):
			d_btn.custom_minimum_size.y = 38.0 if short_screen else 44.0

	if top_right_bar:
		var tr_margin: float = 16.0 if narrow or short_screen else 24.0
		top_right_bar.offset_right = -tr_margin
		top_right_bar.offset_top = tr_margin
		top_right_bar.offset_left = -320.0
		top_right_bar.offset_bottom = tr_margin + 40.0

	if copyright_label:
		var bl_margin: float = 16.0 if narrow or short_screen else 24.0
		copyright_label.offset_left = bl_margin
		copyright_label.offset_bottom = -bl_margin
		copyright_label.offset_top = -(bl_margin + 20.0)
		copyright_label.offset_right = minf(view_size.x - 140.0, 260.0)
		copyright_label.text = "© 2026 AstraDev" if narrow else "© 2026 AstraDev. All rights reserved."

	if exit_button:
		var br_margin: float = 14.0 if narrow or short_screen else 20.0
		exit_button.custom_minimum_size = Vector2(96.0, 44.0)
		exit_button.offset_right = -br_margin
		exit_button.offset_left = -(br_margin + 104.0)
		exit_button.offset_bottom = -br_margin
		exit_button.offset_top = -(br_margin + 44.0)

	for panel: PanelContainer in modal_panels:
		if panel == fix_notes_panel:
			panel.custom_minimum_size = Vector2(maxf(290.0, minf(680.0, view_size.x - 32.0)), panel.custom_minimum_size.y)
		else:
			panel.custom_minimum_size = Vector2(maxf(280.0, minf(500.0, view_size.x - 28.0)), panel.custom_minimum_size.y)
	if settings_scroll:
		settings_scroll.custom_minimum_size.y = maxf(130.0, minf(310.0, view_size.y - 250.0))
	if shop_scroll:
		shop_scroll.custom_minimum_size.y = maxf(140.0, minf(310.0, view_size.y - 260.0))
	if fix_notes_scroll:
		fix_notes_scroll.custom_minimum_size.y = maxf(160.0, minf(450.0, view_size.y - 200.0))
	_sync_menu_anchor_position()
	if horror_backdrop:
		horror_backdrop.queue_redraw()

func _sync_menu_anchor_position() -> void:
	if not menu_anchor or not main_content:
		return
	var view_size: Vector2 = get_viewport_rect().size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		view_size = Vector2(1280.0, 720.0)
	var narrow: bool = view_size.x < 700.0
	var short_screen: bool = view_size.y < 520.0
	var left_pad: float = 24.0 if narrow else (34.0 if short_screen else 64.0)
	var col_w: float = clampf(view_size.x - left_pad * 2.0, 260.0, 340.0) if narrow else clampf(view_size.x * 0.34, 280.0, 360.0)
	var content_h: float = main_content.get_combined_minimum_size().y
	var footer_clear: float = 44.0 if short_screen else (66.0 if narrow else 68.0)
	var min_top: float = 16.0 if short_screen else 36.0
	var avail_h: float = maxf(content_h, view_size.y - footer_clear)
	var max_top: float = maxf(min_top, view_size.y - content_h - footer_clear)
	var top_y: float = clampf((avail_h - content_h) * 0.44, min_top, max_top)
	menu_anchor.position = Vector2(left_pad, top_y)
	menu_anchor.size = Vector2(col_w, content_h)
	main_content.size = Vector2(col_w, content_h)

func _update_nightmare_status() -> void:
	var unlocked: bool = GameManager.is_nightmare_unlocked()
	nightmare_button.disabled = not unlocked
	nightmare_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if unlocked else Control.CURSOR_ARROW
	if unlocked:
		nightmare_lock_label.text = "Nightmare terbuka. Semoga beruntung."
		nightmare_lock_label.add_theme_color_override("font_color", HorrorTheme.PRIMARY)
	else:
		var remaining: int = 5 - GameManager.total_wins
		nightmare_lock_label.text = "Terkunci: butuh %d kemenangan lagi (%d/5)." % [remaining, GameManager.total_wins]
		nightmare_lock_label.add_theme_color_override("font_color", HorrorTheme.TEXT_MUTED)

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
