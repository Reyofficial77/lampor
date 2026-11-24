class_name MainMenu
extends Control

const LocScript = preload("res://scripts/systems/Loc.gd")
const GAME_VERSION: String = "v1.3.0"
const FALLBACK_REDEEM_CODES: Dictionary = {
	"LAMPORGIFT": {"type": "coins", "quantity": 2500, "description": "hadiah untuk kalian!"},
	"FOREVERYONE": {"type": "coins", "quantity": 5000, "description": "Hadiah untuk semua pemain!", "description_en": "A gift for everyone!"},
	"LAMPORLOVER": {"type": "coins", "quantity": 10000, "description": "Hadiah spesial pecinta Lampor!", "description_en": "Special gift for Lampor fans!"}
}

var horror_backdrop: Control
var menu_anim_time: float = 0.0
var menu_anchor: Control
var main_content: VBoxContainer
var title_label: Label
var subtitle_label: Label
var title_rule: ColorRect
var stats_label: Label
var account_chip_panel: PanelContainer
var account_chip_label: Label
var top_right_bar: HBoxContainer
var top_account_chip: PanelContainer
var top_account_label: Label
var account_btn: Button
var version_label: Label
var copyright_label: Label
var exit_button: Button
var continue_button: Button
var modal_overlays: Array[ColorRect] = []
var modal_panels: Array[PanelContainer] = []
var difficulty_buttons: Array[Button] = []
var tutorial_button: Button
var tutorial_divider: Control
var warning_overlay: ColorRect
var warning_panel: PanelContainer
var mode_select_overlay: ColorRect
var mode_select_panel: PanelContainer
var mode_select_scroll: ScrollContainer
var mode_lock_box: PanelContainer
var mode_lock_label: Label
var mode_lock_login_btn: Button
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
var redeem_button: Button
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
var language_option: OptionButton
var character_option: OptionButton
var mode_character_option: OptionButton
var start_button: Button
var guide_rich_text: RichTextLabel
var _listening_keybind_action: String = ""
var _keybind_buttons: Dictionary = {}

# Akun LAMPOR & Gerbang Masuk (Force Login / Guest)
var account_overlay: ColorRect
var account_panel: PanelContainer
var account_title_label: Label
var account_scroll: ScrollContainer
var account_auth_section: VBoxContainer
var account_login_tab_btn: Button
var account_register_tab_btn: Button
var account_tab_index: int = 0
var account_username_input: LineEdit
var account_password_input: LineEdit
var account_confirm_row: VBoxContainer
var account_confirm_input: LineEdit
var account_submit_btn: Button
var account_status_label: Label
var account_profile_section: VBoxContainer
var account_profile_summary_label: Label
var account_sync_btn: Button
var account_logout_btn: Button
var server_settings_toggle_btn: Button
var server_settings_box: VBoxContainer
var server_url_input: LineEdit
var server_save_btn: Button
var server_test_btn: Button
var server_test_label: Label
var guest_section: VBoxContainer
var guest_btn: Button
var account_close_btn: Button
var _account_busy: bool = false
var _pending_online_mode_after_auth: String = ""

# Multiplayer / Sandbox Server Browser, Create Room, & Lobby
var mp_server_overlay: ColorRect
var mp_server_panel: PanelContainer
var mp_server_title_label: Label
var mp_server_status_label: Label
var mp_refresh_btn: Button
var mp_create_room_btn: Button
var mp_quick_join_row: BoxContainer
var room_code_input: LineEdit
var join_password_input: LineEdit
var mp_join_code_btn: Button
var mp_server_feedback_label: Label
var mp_rooms_scroll: ScrollContainer
var mp_rooms_list: VBoxContainer
var mp_mode_filter: String = "multiplayer"
var _mp_rooms_loading: bool = false
var _mp_last_rooms: Array = []

var room_password_overlay: ColorRect
var room_password_panel: PanelContainer
var room_password_room_label: Label
var room_password_input: LineEdit
var room_password_error_label: Label
var room_password_join_btn: Button
var _pending_join_room_id: String = ""

var create_room_overlay: ColorRect
var create_room_panel: PanelContainer
var create_room_scroll: ScrollContainer
var create_room_mode_badge: Label
var create_room_name_input: LineEdit
var create_room_password_input: LineEdit
var create_room_max_players_opt: OptionButton
var create_room_diff_opt: OptionButton
var create_room_shop_chk: CheckButton
var create_room_lampor_chk: CheckButton
var create_room_timescale_opt: OptionButton
var create_room_late_join_chk: CheckButton
var create_room_revive_chk: CheckButton
var create_room_status_label: Label
var create_room_submit_btn: Button

var room_lobby_overlay: ColorRect
var room_lobby_panel: PanelContainer
var lobby_scroll: ScrollContainer
var lobby_room_name_label: Label
var lobby_room_code_label: Label
var lobby_copy_code_btn: Button
var lobby_mode_badge_label: Label
var lobby_settings_summary_label: Label
var lobby_players_box: VBoxContainer
var lobby_chat_scroll: ScrollContainer
var lobby_chat_view: RichTextLabel
var lobby_chat_input: LineEdit
var lobby_chat_send_btn: Button
var lobby_status_label: Label
var lobby_actions_row: BoxContainer
var lobby_ready_btn: Button
var lobby_start_btn: Button
var lobby_leave_btn: Button
var _lobby_busy: bool = false
var _launching_online_game: bool = false
var _last_chat_count: int = -1
var _last_lobby_roster_sig: String = ""

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
	SettingsManager.keybinds_changed.connect(_on_settings_keybinds_changed)
	SettingsManager.character_model_changed.connect(_on_settings_character_model_changed)
	SignalBus.account_state_changed.connect(_on_account_state_changed)
	SignalBus.multiplayer_rooms_updated.connect(_on_multiplayer_rooms_updated)
	SignalBus.multiplayer_room_updated.connect(_on_multiplayer_room_updated)
	SignalBus.multiplayer_game_started.connect(_on_multiplayer_game_started)
	SignalBus.multiplayer_disconnected.connect(_on_multiplayer_disconnected)
	SignalBus.multiplayer_event_received.connect(_on_multiplayer_event_received)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	call_deferred("_apply_layout")
	HorrorTheme.animate_surface_enter(menu_anchor)
	if start_button:
		call_deferred("_focus_control_safely", start_button)
	call_deferred("_check_for_game_updates")
	if not AccountManager.account_gate_resolved:
		call_deferred("_run_initial_account_gate")
	else:
		_refresh_account_ui()

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
	main_content.minimum_size_changed.connect(_sync_menu_anchor_position)

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

	account_chip_panel = PanelContainer.new()
	account_chip_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	account_chip_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	account_chip_panel.add_theme_stylebox_override("panel", HorrorTheme.make_chip_style(HorrorTheme.SURFACE_LOWEST, HorrorTheme.OUTLINE_VARIANT, 2, 10, 5))
	account_chip_panel.gui_input.connect(_on_account_chip_gui_input)
	main_content.add_child(account_chip_panel)

	account_chip_label = _make_label("", 11, HorrorTheme.ON_SURFACE_VARIANT, HORIZONTAL_ALIGNMENT_LEFT, "mono-sm")
	account_chip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	account_chip_panel.add_child(account_chip_label)

	var menu_buttons := VBoxContainer.new()
	menu_buttons.name = "MenuButtons"
	menu_buttons.add_theme_constant_override("separation", 4)
	main_content.add_child(menu_buttons)

	var has_save: bool = GameManager.has_saved_run()
	continue_button = _make_nav_button(LocScript.pick("LANJUTKAN MALAM", "CONTINUE NIGHT"), true)
	continue_button.visible = has_save
	continue_button.pressed.connect(_on_continue_pressed)
	menu_buttons.add_child(continue_button)

	start_button = _make_nav_button(LocScript.pick("MULAI PERMAINAN", "START GAME"), not has_save)
	start_button.pressed.connect(func() -> void: _open_modal(warning_overlay, warning_panel))
	menu_buttons.add_child(start_button)

	var shop_button := _make_nav_button(LocScript.pick("TOKO BEKAL", "SUPPLY SHOP"))
	shop_button.pressed.connect(func() -> void:
		_refresh_shop_display()
		_open_modal(shop_overlay, shop_panel)
	)
	menu_buttons.add_child(shop_button)

	var settings_button := _make_nav_button(LocScript.pick("PENGATURAN & PANDUAN", "SETTINGS & GUIDE"))
	settings_button.pressed.connect(func() -> void:
		_select_settings_tab(0)
		_open_modal(settings_overlay, settings_panel)
	)
	menu_buttons.add_child(settings_button)

	fix_notes_button = _make_nav_button(LocScript.pick("CATATAN PEMBARUAN", "PATCH NOTES"))
	fix_notes_button.pressed.connect(_show_fix_notes)
	menu_buttons.add_child(fix_notes_button)

	var credits_button := _make_nav_button(LocScript.pick("HAK CIPTA", "CREDITS"))
	credits_button.pressed.connect(func() -> void: _open_modal(credits_overlay, credits_panel))
	menu_buttons.add_child(credits_button)

	top_right_bar = HBoxContainer.new()
	top_right_bar.name = "TopRightBar"
	top_right_bar.alignment = BoxContainer.ALIGNMENT_END
	top_right_bar.add_theme_constant_override("separation", 10)
	top_right_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(top_right_bar)

	top_account_chip = PanelContainer.new()
	top_account_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_account_chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	top_account_chip.add_theme_stylebox_override("panel", HorrorTheme.make_chip_style(HorrorTheme.SURFACE_LOWEST, HorrorTheme.OUTLINE_VARIANT, 2, 10, 6))
	top_account_chip.gui_input.connect(_on_account_chip_gui_input)
	top_right_bar.add_child(top_account_chip)

	top_account_label = _make_label("", 11, HorrorTheme.ON_SURFACE_VARIANT, HORIZONTAL_ALIGNMENT_CENTER, "mono-sm")
	top_account_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_account_chip.add_child(top_account_label)

	account_btn = Button.new()
	account_btn.text = LocScript.pick("AKUN / MASUK", "ACCOUNT / SIGN IN")
	account_btn.custom_minimum_size = Vector2(0.0, 36.0)
	HorrorTheme.style_button(account_btn, "secondary", 11, true)
	account_btn.pressed.connect(func() -> void: _open_account_modal(0))
	top_right_bar.add_child(account_btn)

	update_button = Button.new()
	update_button.text = LocScript.pick("UPDATE TERSEDIA", "UPDATE AVAILABLE")
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
	exit_button.text = LocScript.pick("KELUAR", "QUIT")
	HorrorTheme.style_button(exit_button, "ghost", 12, true)
	exit_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	exit_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	exit_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	exit_button.custom_minimum_size = Vector2(104.0, 44.0)
	exit_button.pressed.connect(func() -> void: get_tree().quit())
	add_child(exit_button)

	_build_warning_modal()
	_build_mode_select_modal()
	_build_difficulty_modal()
	_build_settings_modal()
	_build_shop_modal()
	_build_credits_modal()
	_build_fix_notes_modal()
	_build_update_restart_modal()
	_build_account_modal()
	_build_mp_server_modal()
	_build_room_password_modal()
	_build_create_room_modal()
	_build_room_lobby_modal()
	_refresh_account_ui()

func _open_modal(overlay: ColorRect, panel: PanelContainer) -> void:
	if not overlay:
		return
	overlay.visible = true
	overlay.move_to_front()
	if panel:
		HorrorTheme.animate_surface_enter(panel)
	var first_btn: Button = _find_first_focusable_button(panel)
	if first_btn:
		call_deferred("_focus_control_safely", first_btn)

func _focus_control_safely(ctrl: Control) -> void:
	if is_instance_valid(ctrl) and ctrl.is_inside_tree() and ctrl.is_visible_in_tree():
		ctrl.grab_focus()

func _get_topmost_visible_modal() -> ColorRect:
	var top_ov: ColorRect = null
	var top_idx: int = -1
	for ov: ColorRect in modal_overlays:
		if is_instance_valid(ov) and ov.visible:
			var idx: int = ov.get_index()
			if idx > top_idx:
				top_idx = idx
				top_ov = ov
	return top_ov

func _close_topmost_modal() -> bool:
	_cancel_keybind_listening()
	var top_ov: ColorRect = _get_topmost_visible_modal()
	if top_ov == null:
		return false
	if top_ov == account_overlay and not AccountManager.account_gate_resolved:
		return true
	if top_ov == room_lobby_overlay:
		_on_lobby_leave_pressed()
		return true
	if top_ov == create_room_overlay:
		create_room_overlay.visible = false
		_open_modal(mp_server_overlay, mp_server_panel)
		return true
	if top_ov == difficulty_overlay:
		difficulty_overlay.visible = false
		_reset_mode_select_lock_notice()
		_open_modal(mode_select_overlay, mode_select_panel)
		return true
	top_ov.visible = false
	if start_button:
		start_button.call_deferred("grab_focus")
	return true

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
	var modal: Dictionary = _create_modal(LocScript.pick("PERINGATAN KONTEN", "CONTENT WARNING"))
	warning_overlay = modal["overlay"] as ColorRect
	warning_panel = modal["panel"] as PanelContainer
	var body: VBoxContainer = modal["body"] as VBoxContainer

	var warning := _make_label(
		LocScript.pick(
			"Permainan ini mengandung jumpscare mendadak, suara keras, kilatan cahaya, dan visual horor.\n\nAtur volume pada tingkat yang nyaman dan hentikan permainan bila merasa tidak nyaman.",
			"This game features sudden jumpscares, loud audio, flashing lights, and horror visuals.\n\nPlease set your volume comfortably and stop playing if you feel unwell."
		),
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

	var back := _make_button(LocScript.pick("KEMBALI", "BACK"), false, "ghost")
	back.pressed.connect(func() -> void: warning_overlay.visible = false)
	buttons.add_child(back)

	var cont_btn := _make_button(LocScript.pick("SAYA MENGERTI", "I UNDERSTAND"), true)
	cont_btn.pressed.connect(func() -> void:
		warning_overlay.visible = false
		_reset_mode_select_lock_notice()
		_open_modal(mode_select_overlay, mode_select_panel)
	)
	buttons.add_child(cont_btn)

func _build_mode_select_modal() -> void:
	var modal: Dictionary = _create_modal(LocScript.pick("PILIH MODE PERMAINAN", "SELECT GAME MODE"))
	mode_select_overlay = modal["overlay"] as ColorRect
	mode_select_panel = modal["panel"] as PanelContainer
	var body: VBoxContainer = modal["body"] as VBoxContainer

	mode_select_scroll = ScrollContainer.new()
	mode_select_scroll.custom_minimum_size = Vector2(0.0, 260.0)
	mode_select_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mode_select_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	HorrorTheme.style_scroll_container(mode_select_scroll)
	body.add_child(mode_select_scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_right", 8)
	mode_select_scroll.add_child(margin)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	var intro := _make_label(
		LocScript.pick(
			"Tentukan cara menghadapi kutukan Lampor malam ini.",
			"Choose how you wish to face Lampor's curse tonight."
		),
		13, HorrorTheme.ON_SURFACE_VARIANT, HORIZONTAL_ALIGNMENT_LEFT, "body-md"
	)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(intro)

	var char_card := PanelContainer.new()
	char_card.mouse_filter = Control.MOUSE_FILTER_PASS
	char_card.add_theme_stylebox_override("panel", HorrorTheme.make_chip_style(HorrorTheme.SURFACE_LOW, HorrorTheme.BORDER_SUBTLE, 2, 12, 8))
	col.add_child(char_card)

	var mode_char_row := HBoxContainer.new()
	mode_char_row.mouse_filter = Control.MOUSE_FILTER_PASS
	mode_char_row.add_theme_constant_override("separation", 10)
	char_card.add_child(mode_char_row)

	var mode_char_lbl := _make_label(LocScript.pick("Karakter", "Character"), 13, HorrorTheme.PRIMARY, HORIZONTAL_ALIGNMENT_LEFT, "label-lg")
	mode_char_lbl.custom_minimum_size.x = 104.0
	mode_char_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_char_row.add_child(mode_char_lbl)

	mode_character_option = _create_character_option_button()
	mode_char_row.add_child(mode_character_option)

	var sp_btn := _make_mode_option_card(
		col,
		LocScript.pick("SINGLEPLAYER", "SINGLEPLAYER"),
		LocScript.pick(
			"Bertahan sendirian di desa. Mendukung Tutorial Pemula, autosave, & hadiah koin penuh.",
			"Survive alone in the village. Supports Beginner Tutorial, autosave, & full coin rewards."
		),
		true
	)
	sp_btn.pressed.connect(func() -> void:
		mode_select_overlay.visible = false
		_update_nightmare_status()
		_refresh_tutorial_button_visibility()
		_open_modal(difficulty_overlay, difficulty_panel)
	)

	var mp_btn := _make_mode_option_card(
		col,
		LocScript.pick("MULTIPLAYER MODE", "MULTIPLAYER MODE"),
		LocScript.pick(
			"Co-op online hingga 4 pemain. Buat room berpassword, atur item toko, & nyalakan obor bersama.",
			"Online co-op up to 4 players. Host password-locked rooms, configure shop items, & survive together."
		),
		false
	)
	mp_btn.pressed.connect(func() -> void: _on_mode_online_selected("multiplayer"))

	var sb_btn := _make_mode_option_card(
		col,
		LocScript.pick("SANDBOX MODE", "SANDBOX MODE"),
		LocScript.pick(
			"Mode bebas (1-4 pemain) tanpa skor peringkat. Pembuat room mendapat Panel Sandbox [Ctrl+F5] / mobile.",
			"Freeplay mode (1-4 players) unranked. Room host unlocks the Sandbox Panel [Ctrl+F5] / mobile."
		),
		false
	)
	sb_btn.pressed.connect(func() -> void: _on_mode_online_selected("sandbox"))

	mode_lock_box = PanelContainer.new()
	mode_lock_box.visible = false
	mode_lock_box.add_theme_stylebox_override("panel", HorrorTheme.make_chip_style(Color(0.20, 0.06, 0.06, 0.92), HorrorTheme.ACCENT, 2, 12, 10))
	col.add_child(mode_lock_box)

	var lock_col := VBoxContainer.new()
	lock_col.add_theme_constant_override("separation", 8)
	mode_lock_box.add_child(lock_col)

	mode_lock_label = _make_label("", 12, HorrorTheme.ERROR, HORIZONTAL_ALIGNMENT_LEFT, "body-md")
	mode_lock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_lock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_col.add_child(mode_lock_label)

	mode_lock_login_btn = _make_button(LocScript.pick("MASUK / BUAT AKUN", "SIGN IN / REGISTER"), true)
	mode_lock_login_btn.custom_minimum_size.y = 40.0
	mode_lock_login_btn.pressed.connect(func() -> void:
		mode_select_overlay.visible = false
		_open_account_modal(0)
	)
	lock_col.add_child(mode_lock_login_btn)

	var back := _make_button(LocScript.pick("KEMBALI", "BACK"), false, "ghost")
	back.pressed.connect(func() -> void: mode_select_overlay.visible = false)
	body.add_child(back)

func _make_mode_option_card(parent: VBoxContainer, heading_text: String, desc_text: String, is_primary: bool) -> Button:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_theme_stylebox_override("panel", HorrorTheme.make_chip_style(HorrorTheme.SURFACE_LOW, HorrorTheme.BORDER_SUBTLE, 2, 12, 10))
	parent.add_child(card)

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)

	var btn := _make_button(heading_text, is_primary)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(btn)

	var desc := _make_label(desc_text, 12, HorrorTheme.ON_SURFACE_VARIANT, HORIZONTAL_ALIGNMENT_LEFT, "label-sm")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(desc)
	return btn

func _reset_mode_select_lock_notice() -> void:
	_pending_online_mode_after_auth = ""
	if mode_lock_box:
		mode_lock_box.visible = false

func _on_mode_online_selected(target_mode: String) -> void:
	if not AccountManager.can_access_online_modes():
		_pending_online_mode_after_auth = target_mode
		if mode_lock_label:
			var mode_title: String = "SANDBOX MODE" if target_mode == "sandbox" else "MULTIPLAYER MODE"
			mode_lock_label.text = LocScript.pick(
				"%s terkunci untuk mode Guest / offline. Masuk atau buat akun LAMPOR terlebih dahulu untuk mengakses server." % mode_title,
				"%s is locked in Guest / offline mode. Sign in or create a LAMPOR account first to access online servers." % mode_title
			)
		if mode_lock_box:
			mode_lock_box.visible = true
		if mode_select_scroll:
			call_deferred("_scroll_to_bottom", mode_select_scroll)
		if mode_lock_login_btn:
			call_deferred("_focus_control_safely", mode_lock_login_btn)
		return
	_pending_online_mode_after_auth = ""
	if mode_lock_box:
		mode_lock_box.visible = false
	mode_select_overlay.visible = false
	_open_mp_server_modal(target_mode)

func _build_difficulty_modal() -> void:
	var modal: Dictionary = _create_modal(LocScript.pick("PILIH TINGKAT KESULITAN", "SELECT DIFFICULTY"))
	difficulty_overlay = modal["overlay"] as ColorRect
	difficulty_panel = modal["panel"] as PanelContainer
	var body: VBoxContainer = modal["body"] as VBoxContainer
	var hint := _make_label(
		LocScript.pick(
			"Selesaikan ritual sebelum pukul 05.00 WIB. Tingkat lebih tinggi mempercepat malam dan perburuan Lampor.",
			"Finish the ritual before 05:00 WIB. Higher difficulties accelerate the night and Lampor's hunt."
		),
		13, HorrorTheme.ON_SURFACE_VARIANT, HORIZONTAL_ALIGNMENT_LEFT, "body-md"
	)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(hint)
	difficulty_buttons.clear()

	tutorial_button = _make_button(LocScript.pick("TUTORIAL PEMULA  ·  Panduan Interaktif (Easy)", "BEGINNER TUTORIAL  ·  Interactive Guide (Easy)"), false, "ghost")
	tutorial_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	tutorial_button.pressed.connect(func() -> void:
		for overlay: ColorRect in modal_overlays:
			overlay.visible = false
		if MultiplayerManager.is_online_session:
			MultiplayerManager.reset_to_singleplayer()
		GameManager.is_sandbox_mode = false
		if GameManager.has_method("start_tutorial_game"):
			GameManager.start_tutorial_game()
		else:
			GameManager.start_new_game(GameManager.Difficulty.EASY)
	)
	body.add_child(tutorial_button)
	difficulty_buttons.append(tutorial_button)

	tutorial_divider = HorrorTheme.make_hairline_divider()
	body.add_child(tutorial_divider)
	_refresh_tutorial_button_visibility()

	var easy := _make_button(LocScript.pick("EASY  ·  Malam Sunyi (1 mnt = 4,5 dtk)", "EASY  ·  Quiet Night (1 min = 4.5s)"))
	easy.alignment = HORIZONTAL_ALIGNMENT_LEFT
	easy.pressed.connect(func() -> void: _start_with_difficulty(GameManager.Difficulty.EASY))
	body.add_child(easy)
	difficulty_buttons.append(easy)

	var normal := _make_button(LocScript.pick("NORMAL  ·  Malam Keramat (1 mnt = 3 dtk)", "NORMAL  ·  Sacred Night (1 min = 3s)"))
	normal.alignment = HORIZONTAL_ALIGNMENT_LEFT
	normal.pressed.connect(func() -> void: _start_with_difficulty(GameManager.Difficulty.NORMAL))
	body.add_child(normal)
	difficulty_buttons.append(normal)

	var hard := _make_button(LocScript.pick("HARD  ·  Malam Jahanam (1 mnt = 1 dtk)", "HARD  ·  Cursed Night (1 min = 1s)"))
	hard.alignment = HORIZONTAL_ALIGNMENT_LEFT
	hard.pressed.connect(func() -> void: _start_with_difficulty(GameManager.Difficulty.HARD))
	body.add_child(hard)
	difficulty_buttons.append(hard)

	nightmare_button = _make_button(LocScript.pick("NIGHTMARE  ·  Kutukan Keranda (1 mnt = 0,5 dtk)", "NIGHTMARE  ·  Coffin Curse (1 min = 0.5s)"), true)
	nightmare_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	nightmare_button.pressed.connect(func() -> void: _start_with_difficulty(GameManager.Difficulty.NIGHTMARE))
	body.add_child(nightmare_button)
	difficulty_buttons.append(nightmare_button)

	nightmare_lock_label = _make_label("", 12, HorrorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT, "label-sm")
	nightmare_lock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(nightmare_lock_label)

	var back := _make_button(LocScript.pick("KEMBALI", "BACK"), false, "ghost")
	back.pressed.connect(func() -> void:
		difficulty_overlay.visible = false
		_reset_mode_select_lock_notice()
		_open_modal(mode_select_overlay, mode_select_panel)
	)
	body.add_child(back)
	difficulty_buttons.append(back)

func _build_settings_modal() -> void:
	var modal: Dictionary = _create_modal(LocScript.pick("PENGATURAN & PANDUAN", "SETTINGS & GUIDE"))
	settings_overlay = modal["overlay"] as ColorRect
	settings_panel = modal["panel"] as PanelContainer
	var body: VBoxContainer = modal["body"] as VBoxContainer

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	body.add_child(tab_row)

	settings_tab_btn = _make_button(LocScript.pick("PENGATURAN", "SETTINGS"), true)
	settings_tab_btn.custom_minimum_size.y = 40.0
	settings_tab_btn.pressed.connect(func() -> void: _select_settings_tab(0))
	tab_row.add_child(settings_tab_btn)

	guide_tab_btn = _make_button(LocScript.pick("PANDUAN BERMAIN", "HOW TO PLAY"), false, "ghost")
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

	var lang_row := HBoxContainer.new()
	var lang_label := _make_label(LocScript.pick("Bahasa / Language", "Language"), 13, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "body-md")
	lang_label.custom_minimum_size.x = 132.0
	lang_row.add_child(lang_label)
	language_option = OptionButton.new()
	language_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_option.custom_minimum_size.y = 40.0
	language_option.add_item("Indonesia (ID)")
	language_option.add_item("English (EN-US)")
	language_option.select(1 if SettingsManager.is_en() else 0)
	language_option.item_selected.connect(_on_language_selected)
	HorrorTheme.style_option_button(language_option)
	lang_row.add_child(language_option)
	settings_tab_box.add_child(lang_row)

	var char_row := HBoxContainer.new()
	char_row.mouse_filter = Control.MOUSE_FILTER_PASS
	var char_label := _make_label(LocScript.pick("Karakter", "Character"), 13, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "body-md")
	char_label.custom_minimum_size.x = 132.0
	char_row.add_child(char_label)
	character_option = _create_character_option_button()
	char_row.add_child(character_option)
	settings_tab_box.add_child(char_row)

	var initial_volume: float = clampf(db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0, 0.0, 100.0)
	volume_slider = _add_slider_setting(settings_tab_box, LocScript.pick("Volume", "Volume"), initial_volume, 0.0, 100.0, 1.0, _on_volume_changed)
	mouse_sensitivity_slider = _add_slider_setting(settings_tab_box, LocScript.pick("Sensitivitas Mouse", "Mouse Sensitivity"), SettingsManager.mouse_sensitivity * 100.0, 25.0, 200.0, 5.0, _on_mouse_sensitivity_changed)
	camera_sensitivity_slider = _add_slider_setting(settings_tab_box, LocScript.pick("Sensitivitas Kamera", "Camera Sensitivity"), SettingsManager.camera_sensitivity * 100.0, 25.0, 200.0, 5.0, _on_camera_sensitivity_changed)
	var sensitivity_note := _make_label(
		LocScript.pick("Mouse untuk desktop · Kamera untuk geser layar sentuh", "Mouse for desktop · Camera for touch swipe"),
		11, HorrorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT, "label-sm"
	)
	settings_tab_box.add_child(sensitivity_note)
	brightness_slider = _add_slider_setting(settings_tab_box, LocScript.pick("Kecerahan", "Brightness"), SettingsManager.brightness * 100.0, 50.0, 150.0, 5.0, _on_brightness_changed)

	var graphics_row := HBoxContainer.new()
	var graphics_label := _make_label(LocScript.pick("Grafik", "Graphics"), 13, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "body-md")
	graphics_label.custom_minimum_size.x = 132.0
	graphics_row.add_child(graphics_label)
	graphics_option = OptionButton.new()
	graphics_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphics_option.custom_minimum_size.y = 40.0
	graphics_option.add_item(LocScript.pick("Otomatis (Perangkat)", "Auto (Device)"))
	graphics_option.add_item("Low")
	graphics_option.add_item("Medium")
	graphics_option.add_item("High")
	graphics_option.tooltip_text = LocScript.pick(
		"Otomatis menggunakan preset %s berdasarkan perangkat ini" % SettingsManager.recommended_graphics_quality.capitalize(),
		"Auto selects the %s preset for this device" % SettingsManager.recommended_graphics_quality.capitalize()
	)
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

	fullscreen_button = _make_button(LocScript.pick("GANTI MODE LAYAR", "TOGGLE FULLSCREEN"))
	fullscreen_button.pressed.connect(_toggle_fullscreen)
	settings_tab_box.add_child(fullscreen_button)

	settings_tab_box.add_child(HorrorTheme.make_hairline_divider())

	var keybinds_title := _make_label(LocScript.pick("PENGATURAN TOMBOL (KEYBINDS)", "KEYBINDINGS"), 13, HorrorTheme.PRIMARY, HORIZONTAL_ALIGNMENT_LEFT, "label-lg")
	settings_tab_box.add_child(keybinds_title)
	var keybinds_hint := _make_label(
		LocScript.pick("Klik tombol untuk mengganti tombol kontrol (Esc untuk batal).", "Click a binding to assign a new key or mouse button (Esc to cancel)."),
		11, HorrorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT, "label-sm"
	)
	keybinds_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_tab_box.add_child(keybinds_hint)

	_keybind_buttons.clear()
	for action: String in SettingsManager.REBINDABLE_ACTIONS:
		var k_row := HBoxContainer.new()
		k_row.mouse_filter = Control.MOUSE_FILTER_PASS
		k_row.add_theme_constant_override("separation", 8)
		var k_lbl := _make_label(LocScript.action_label(action), 12, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "body-md")
		k_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		k_row.add_child(k_lbl)
		var k_btn := _make_button(SettingsManager.get_action_key_text(action), false, "secondary")
		k_btn.custom_minimum_size = Vector2(118.0, 36.0)
		k_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		k_btn.pressed.connect(func() -> void: _begin_keybind_listen(action))
		k_row.add_child(k_btn)
		settings_tab_box.add_child(k_row)
		_keybind_buttons[action] = k_btn

	var reset_kb_btn := _make_button(LocScript.pick("RESET TOMBOL BAWAAN", "RESET DEFAULT KEYBINDS"), false, "ghost")
	reset_kb_btn.pressed.connect(func() -> void:
		_cancel_keybind_listening()
		SettingsManager.reset_keybinds()
		_refresh_keybind_buttons()
	)
	settings_tab_box.add_child(reset_kb_btn)

	settings_tab_box.add_child(HorrorTheme.make_hairline_divider())

	auto_update_check = CheckButton.new()
	auto_update_check.text = LocScript.pick("Unduh & pasang update otomatis", "Auto-download & install updates")
	auto_update_check.custom_minimum_size.y = 42.0
	auto_update_check.button_pressed = SettingsManager.auto_update
	auto_update_check.toggled.connect(SettingsManager.set_auto_update)
	HorrorTheme.style_check_button(auto_update_check)
	settings_tab_box.add_child(auto_update_check)

	update_check_button = _make_button(LocScript.pick("PERIKSA PEMBARUAN GAME", "CHECK FOR UPDATES"))
	update_check_button.pressed.connect(func() -> void:
		update_check_button.text = LocScript.pick("MEMERIKSA PEMBARUAN...", "CHECKING FOR UPDATES...")
		update_status_label.text = LocScript.pick("Menghubungi GitHub...", "Contacting GitHub...")
		UpdateManager.check_for_updates(true)
	)
	settings_tab_box.add_child(update_check_button)

	update_status_label = _make_label(
		LocScript.pick("Pembaruan diperiksa melalui branch main GitHub.", "Updates are checked from the GitHub main branch."),
		11, HorrorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT, "label-sm"
	)
	update_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_tab_box.add_child(update_status_label)

	settings_tab_box.add_child(HorrorTheme.make_hairline_divider())

	var redeem_title := _make_label(LocScript.pick("KODE REDEEM", "REDEEM CODE"), 13, HorrorTheme.PRIMARY, HORIZONTAL_ALIGNMENT_LEFT, "label-lg")
	settings_tab_box.add_child(redeem_title)
	var redeem_row := HBoxContainer.new()
	redeem_row.add_theme_constant_override("separation", 8)
	redeem_input = LineEdit.new()
	redeem_input.placeholder_text = LocScript.pick("Masukkan kode redeem", "Enter redeem code")
	redeem_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	redeem_input.custom_minimum_size.y = 44.0
	redeem_input.max_length = 32
	HorrorTheme.style_line_edit(redeem_input)
	redeem_row.add_child(redeem_input)
	redeem_button = _make_button(LocScript.pick("TUKAR", "REDEEM"), true)
	redeem_button.custom_minimum_size = Vector2(96.0, 44.0)
	redeem_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	redeem_button.pressed.connect(_on_redeem_pressed)
	redeem_row.add_child(redeem_button)
	settings_tab_box.add_child(redeem_row)

	redeem_result_label = _make_label(
		LocScript.pick("Setiap kode hanya dapat digunakan sekali pada save ini.", "Each code can only be redeemed once per save."),
		11, HorrorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT, "label-sm"
	)
	redeem_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_tab_box.add_child(redeem_result_label)

	guide_tab_box = VBoxContainer.new()
	guide_tab_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_tab_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_tab_box.visible = false
	tab_stack.add_child(guide_tab_box)

	var guide := RichTextLabel.new()
	guide_rich_text = guide
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
	guide.text = _build_guide_bbcode()
	guide_tab_box.add_child(guide)

	var close := _make_button(LocScript.pick("TUTUP", "CLOSE"), false, "ghost")
	close.pressed.connect(func() -> void:
		_cancel_keybind_listening()
		settings_overlay.visible = false
	)
	body.add_child(close)

func _build_guide_bbcode() -> String:
	var move_k: String = SettingsManager.get_move_keys_summary()
	var sprint_k: String = SettingsManager.get_action_key_text("sprint")
	var act_k: String = SettingsManager.get_action_key_text("interact")
	var flash_k: String = SettingsManager.get_action_key_text("flashlight")
	var bag_k: String = SettingsManager.get_action_key_text("toggle_inventory")
	var drop_k: String = SettingsManager.get_action_key_text("drop_item")
	var slot_k: String = "%s-%s" % [SettingsManager.get_action_key_text("slot_1"), SettingsManager.get_action_key_text("slot_5")]
	if LocScript.is_en():
		return "[color=#ffb4ac][b]OBJECTIVE[/b][/color]\nSurvive from 01:00 WIB until the ritual completes before 05:00 WIB. Light 5 torches, barricade 3 house doors, collect 4 ritual relics, and burn them all at the Village Hall furnace. If 05:00 WIB strikes before completion, Lampor devours your soul.\n\n[color=#ffb4ac][b]DESKTOP CONTROLS[/b][/color]\n• %s: Move\n• Mouse: Look around\n• %s: Sprint (Hold)\n• %s: Interact, light torches, barricade doors, hide, & use Herbal Elixir / Battery / Energy Drink / Kentongan\n• %s: Flashlight\n• %s: Select hotbar slot\n• %s: Toggle inventory bag (15 slots)\n• %s: Drop item\n• Esc: Pause game\n\n[color=#ffb4ac][b]MOBILE CONTROLS[/b][/color]\nUse the left joystick to move, swipe the right half to look, and tap action buttons to run, interact (Hand icon), toggle flashlight, open bag, or pause.\n\n[color=#ffb4ac][b]SURVIVING LAMPOR[/b][/color]\n• Never stare directly at Lampor's green coffin; look away immediately.\n• When bells chime nearby, kill your flashlight and hide inside houses or closets.\n• Strike Kentongan [%s] to repel Lampor's chase for 5 seconds (Supply Shop only, 1-time use, max 5).\n• Drink Energy Drink [%s] to lock 100%% stamina for 3 seconds (anti-spam cooldown).\n• Lit torch areas steadily restore your Sanity.\n• Nightmare mode unlocks after 5 victories." % [move_k, sprint_k, act_k, flash_k, slot_k, bag_k, drop_k, act_k, act_k]
	return "[color=#ffb4ac][b]TUJUAN PERMAINAN[/b][/color]\nBertahan mulai pukul 01.00 WIB hingga ritual tuntas sebelum pukul 05.00 WIB. Nyalakan 5 obor, amankan 3 pintu rumah, kumpulkan 4 benda ritual, lalu bakar semuanya di tungku balai desa. Bila pukul 05.00 WIB tiba sebelum tuntas, Lampor akan langsung melahapmu.\n\n[color=#ffb4ac][b]KONTROL DESKTOP[/b][/color]\n• %s: Bergerak\n• Mouse: Melihat ke sekitar\n• %s: Berlari (Tahan)\n• %s: Interaksi, nyalakan obor, palang pintu, sembunyi, & pakai Jamu/Baterai/Energy Drink/Kentongan\n• %s: Senter\n• %s: Pilih slot hotbar\n• %s: Buka tas inventori (15 slot)\n• %s: Jatuhkan barang\n• Esc: Jeda permainan\n\n[color=#ffb4ac][b]KONTROL MOBILE[/b][/color]\nGunakan joystick kiri untuk bergerak, geser sisi kanan layar untuk menoleh, dan sentuh tombol aksi di layar untuk lari, interaksi (ikon Tangan), senter, tas, serta jeda.\n\n[color=#ffb4ac][b]MENGHADAPI LAMPOR[/b][/color]\n• Jangan menatap langsung keranda Lampor; segera palingkan pandangan.\n• Saat lonceng mendekat, matikan senter dan bersembunyilah di rumah atau lemari.\n• Pukul Kentongan [%s] untuk mengusir kejaran Lampor selama 5 detik (hanya tersedia di Toko Bekal, 1x pakai, maks. 5).\n• Minum Energy Drink [%s] untuk mengunci stamina 100%% selama 3 detik (ada jeda anti-spam).\n• Area obor yang menyala membantu memulihkan kewarasan.\n• Mode Nightmare terbuka setelah 5 kemenangan." % [move_k, sprint_k, act_k, flash_k, slot_k, bag_k, drop_k, act_k, act_k]

func _create_character_option_button() -> OptionButton:
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.custom_minimum_size.y = 40.0
	opt.add_item(LocScript.pick("Laki-laki Dewasa", "Adult Male"))
	opt.add_item(LocScript.pick("Perempuan Dewasa", "Adult Female"))
	opt.select(1 if SettingsManager.normalize_character_model(SettingsManager.character_model) == "female" else 0)
	opt.item_selected.connect(_on_character_model_selected)
	HorrorTheme.style_option_button(opt)
	return opt

func _sync_character_option_buttons() -> void:
	var selected_idx: int = 1 if SettingsManager.normalize_character_model(SettingsManager.character_model) == "female" else 0
	for opt: OptionButton in [character_option, mode_character_option]:
		if is_instance_valid(opt) and opt.selected != selected_idx:
			opt.select(selected_idx)

func _on_character_model_selected(index: int) -> void:
	var target_model: String = "female" if index == 1 else "male"
	SettingsManager.set_character_model(target_model)
	_sync_character_option_buttons()

func _on_settings_character_model_changed(_model_id: String) -> void:
	_sync_character_option_buttons()

func _on_language_selected(index: int) -> void:
	var target_lang: String = "en_US" if index == 1 else "id"
	if target_lang != SettingsManager.language:
		SettingsManager.set_language(target_lang)
		_rebuild_for_language_change()

func _rebuild_for_language_change() -> void:
	_listening_keybind_action = ""
	_keybind_buttons.clear()
	modal_overlays.clear()
	modal_panels.clear()
	difficulty_buttons.clear()
	fix_notes_rendered_markdown = ""
	fix_notes_sections.clear()
	fix_notes_loaded_sections = 0
	_active_drag_scroll = null
	_drag_moved = false
	_drag_pressed_button = null
	_account_busy = false
	_lobby_busy = false
	_mp_rooms_loading = false
	_launching_online_game = false
	_pending_join_room_id = ""
	_pending_online_mode_after_auth = ""
	_last_lobby_roster_sig = ""
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_build_menu()
	_apply_layout()
	call_deferred("_apply_layout")
	_refresh_account_ui()
	_select_settings_tab(0)
	_open_modal(settings_overlay, settings_panel)

func _begin_keybind_listen(action: String) -> void:
	_listening_keybind_action = action
	_refresh_keybind_buttons()

func _cancel_keybind_listening() -> void:
	if _listening_keybind_action.is_empty():
		return
	_listening_keybind_action = ""
	_refresh_keybind_buttons()

func _on_settings_keybinds_changed() -> void:
	_refresh_keybind_buttons()
	if guide_rich_text:
		guide_rich_text.text = _build_guide_bbcode()

func _refresh_keybind_buttons() -> void:
	for action: String in _keybind_buttons.keys():
		var btn: Button = _keybind_buttons[action] as Button
		if not is_instance_valid(btn):
			continue
		if action == _listening_keybind_action:
			btn.text = LocScript.pick("TEKAN TOMBOL...", "PRESS KEY...")
			HorrorTheme.style_button(btn, "primary", 11, true)
		else:
			btn.text = SettingsManager.get_action_key_text(action)
			HorrorTheme.style_button(btn, "secondary", 11, true)
	if guide_rich_text:
		guide_rich_text.text = _build_guide_bbcode()

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
	elif title_text == "Sensitivitas Mouse" or title_text == "Mouse Sensitivity":
		mouse_sensitivity_value = value_label
	elif title_text == "Sensitivitas Kamera" or title_text == "Camera Sensitivity":
		camera_sensitivity_value = value_label
	elif title_text == "Kecerahan" or title_text == "Brightness":
		brightness_value = value_label
	slider.value_changed.connect(callback)
	return slider

func _build_shop_modal() -> void:
	var modal: Dictionary = _create_modal(LocScript.pick("TOKO BEKAL", "SUPPLY SHOP"))
	shop_overlay = modal["overlay"] as ColorRect
	shop_panel = modal["panel"] as PanelContainer
	var body: VBoxContainer = modal["body"] as VBoxContainer

	shop_balance_label = _make_label(LocScript.pick("Koin Emas: %d" % GameManager.coins, "Gold Coins: %d" % GameManager.coins), 12, HorrorTheme.RELIC_BRASS, HORIZONTAL_ALIGNMENT_LEFT, "mono-sm")
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

	var coin_unit: String = LocScript.pick("Koin", "Coins")
	_add_shop_offer(offers, LocScript.pick("Jamu Tolak Bala x1", "Herbal Elixir x1"), LocScript.pick("Pulihkan 45 kewarasan dan seluruh stamina.", "Restore 45 sanity and full stamina."), "30 %s" % coin_unit, "jamu", 1)
	_add_shop_offer(offers, LocScript.pick("Jamu Tolak Bala x3", "Herbal Elixir x3"), LocScript.pick("Persediaan jamu tiga kali pakai.", "Three-dose herbal supply."), "90 %s" % coin_unit, "jamu", 3)
	_add_shop_offer(offers, LocScript.pick("Baterai Senter x1", "Flashlight Battery x1"), LocScript.pick("Isi ulang 50% daya senter.", "Recharge 50% flashlight power."), "20 %s" % coin_unit, "baterai", 1)
	_add_shop_offer(offers, "Energy Drink x1", LocScript.pick("Stamina 100% penuh selama 3 detik (anti-spam).", "Locks 100% stamina for 3 seconds (anti-spam)."), "25 %s" % coin_unit, "energy_drink", 1)
	_add_shop_offer(offers, "Kentongan x1", LocScript.pick("Usir kejaran Lampor selama 5 detik (1x pakai).", "Repels Lampor's pursuit for 5 seconds (1 use)."), "250 %s" % coin_unit, "kentongan", 1)
	_add_shop_offer(offers, LocScript.pick("Nyawa Tambahan x1", "Extra Life x1"), LocScript.pick("Bangkit sekali di titik awal saat terbunuh.", "Revive once at village spawn when caught."), "80 %s" % coin_unit, "extra_life", 1)
	_add_shop_offer(offers, LocScript.pick("Nyawa Tambahan x2", "Extra Life x2"), LocScript.pick("Dua kesempatan bangkit tambahan.", "Two extra revival chances."), "150 %s" % coin_unit, "extra_life", 2)
	_add_shop_offer(offers, LocScript.pick("Nyawa Tambahan x3", "Extra Life x3"), LocScript.pick("Tiga kesempatan bangkit tambahan.", "Three extra revival chances."), "210 %s" % coin_unit, "extra_life", 3)

	shop_result_label = _make_label(LocScript.pick("Batas simpan: maks. 5 item & 5 nyawa tambahan.", "Storage limit: max 5 per item & 5 extra lives."), 11, HorrorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT, "label-sm")
	shop_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(shop_result_label)

	var close := _make_button(LocScript.pick("TUTUP", "CLOSE"), false, "ghost")
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
		stats_label.text = LocScript.pick(
			"%d Kemenangan  ·  %d Koin  ·  %d Nyawa" % [GameManager.total_wins, GameManager.coins, GameManager.extra_lives],
			"%d Wins  ·  %d Coins  ·  %d Lives" % [GameManager.total_wins, GameManager.coins, GameManager.extra_lives]
		)

func _refresh_shop_display() -> void:
	if shop_balance_label:
		shop_balance_label.text = LocScript.pick(
			"Koin: %d  ·  Nyawa: %d/%d  ·  Jamu: %d/%d  ·  Baterai: %d/%d  ·  Energy: %d/%d  ·  Kentongan: %d/%d" % [
				GameManager.coins,
				GameManager.extra_lives,
				GameManager.MAX_EXTRA_LIVES,
				GameManager.item_stash.get("jamu", 0),
				GameManager.MAX_SHOP_ITEM_QTY,
				GameManager.item_stash.get("baterai", 0),
				GameManager.MAX_SHOP_ITEM_QTY,
				GameManager.item_stash.get("energy_drink", 0),
				GameManager.MAX_SHOP_ITEM_QTY,
				GameManager.item_stash.get("kentongan", 0),
				GameManager.MAX_SHOP_ITEM_QTY
			],
			"Coins: %d  ·  Lives: %d/%d  ·  Elixir: %d/%d  ·  Battery: %d/%d  ·  Energy: %d/%d  ·  Kentongan: %d/%d" % [
				GameManager.coins,
				GameManager.extra_lives,
				GameManager.MAX_EXTRA_LIVES,
				GameManager.item_stash.get("jamu", 0),
				GameManager.MAX_SHOP_ITEM_QTY,
				GameManager.item_stash.get("baterai", 0),
				GameManager.MAX_SHOP_ITEM_QTY,
				GameManager.item_stash.get("energy_drink", 0),
				GameManager.MAX_SHOP_ITEM_QTY,
				GameManager.item_stash.get("kentongan", 0),
				GameManager.MAX_SHOP_ITEM_QTY
			]
		)

func _purchase_shop_item(item_id: String, quantity: int) -> void:
	var result: Dictionary = GameManager.purchase_shop_item(item_id, quantity)
	shop_result_label.text = str(result.get("message", LocScript.pick("Transaksi gagal.", "Transaction failed.")))
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
	if normalized.is_empty():
		redeem_result_label.text = LocScript.pick("Masukkan kode redeem terlebih dahulu.", "Enter a redeem code first.")
		redeem_result_label.add_theme_color_override("font_color", HorrorTheme.ERROR)
		return
	var result: Dictionary = {}
	if AccountManager.can_access_online_modes():
		if is_instance_valid(redeem_button):
			redeem_button.disabled = true
		redeem_result_label.text = LocScript.pick("Memeriksa kode redeem di server...", "Checking redeem code on server...")
		redeem_result_label.add_theme_color_override("font_color", HorrorTheme.ON_SURFACE_VARIANT)
		var cloud_res: Dictionary = await AccountManager.redeem_cloud_code(normalized)
		if not is_instance_valid(self) or not is_inside_tree():
			return
		if is_instance_valid(redeem_button):
			redeem_button.disabled = false
		if bool(cloud_res.get("ok", false)):
			var cloud_msg: String = str(cloud_res.get("message", ""))
			if cloud_msg.is_empty():
				var payload: Dictionary = _unwrap_payload(cloud_res)
				cloud_msg = str(payload.get("message", LocScript.pick("Kode redeem berhasil diklaim!", "Redeem code claimed!")))
			result = {"success": true, "message": cloud_msg}
		else:
			var status_code: int = int(cloud_res.get("status", 0))
			if status_code != 0 and status_code != 404:
				result = {"success": false, "message": _extract_error(cloud_res, "Kode redeem tidak dapat digunakan.", "Redeem code cannot be used.")}
	if result.is_empty():
		result = GameManager.redeem_code(normalized)
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
				var desc: String = str(reward.get("description_en", reward.get("description", "Reward claimed"))) if LocScript.is_en() else str(reward.get("description", "Hadiah diterima"))
				result = {"success": true, "message": LocScript.pick("Berhasil menukarkan kode: %s." % desc, "Redeemed code: %s." % desc)}
	redeem_result_label.text = str(result.get("message", LocScript.pick("Kode gagal diproses.", "Failed to process code.")))
	redeem_result_label.add_theme_color_override("font_color", HorrorTheme.SUCCESS_SAGE if bool(result.get("success", false)) else HorrorTheme.ERROR)
	if bool(result.get("success", false)):
		redeem_input.clear()
	_refresh_currency_display()
	_refresh_shop_display()

func _on_continue_pressed() -> void:
	for overlay: ColorRect in modal_overlays:
		overlay.visible = false
	if MultiplayerManager.is_online_session:
		MultiplayerManager.reset_to_singleplayer()
	GameManager.is_sandbox_mode = false
	if GameManager.has_saved_run():
		GameManager.resume_saved_game()
	else:
		if continue_button:
			continue_button.visible = false

func _check_for_game_updates() -> void:
	UpdateManager.check_for_updates()

func _on_update_available(commit_sha: String, commit_message: String) -> void:
	update_button.disabled = false
	update_check_button.text = LocScript.pick("PERIKSA PEMBARUAN GAME", "CHECK FOR UPDATES")
	if UpdateManager.is_git_working_copy():
		update_button.visible = false
		update_status_label.text = LocScript.pick(
			"Mode Developer (Git/Editor): Commit GitHub %s (%s). Gunakan git pull/push agar perubahan lokal tidak tertimpa." % [commit_sha.substr(0, 10), commit_message],
			"Developer Mode (Git/Editor): GitHub commit %s (%s). Use git pull/push so local edits aren't overwritten." % [commit_sha.substr(0, 10), commit_message]
		)
		return
	update_button.visible = not UpdateManager.is_update_processed()
	update_button.text = LocScript.pick("PASANG PEMBARUAN", "INSTALL UPDATE")
	update_button.tooltip_text = commit_message
	if UpdateManager.is_update_processed():
		update_status_label.text = LocScript.pick("Commit %s sudah terpasang." % commit_sha.substr(0, 10), "Commit %s is already installed." % commit_sha.substr(0, 10))
	else:
		update_status_label.text = LocScript.pick("Commit terbaru %s: %s" % [commit_sha.substr(0, 10), commit_message], "Latest commit %s: %s" % [commit_sha.substr(0, 10), commit_message])

func _on_update_up_to_date(commit_sha: String) -> void:
	update_check_button.text = LocScript.pick("PERIKSA PEMBARUAN GAME", "CHECK FOR UPDATES")
	update_status_label.text = LocScript.pick("Game sudah sama dengan commit terbaru (%s)." % commit_sha.substr(0, 10), "Game is up to date (%s)." % commit_sha.substr(0, 10))
	update_button.visible = false

func _on_update_installed(destination_path: String, commit_sha: String, applied_to_project: bool) -> void:
	update_button.disabled = false
	update_button.visible = false
	update_check_button.text = LocScript.pick("PERIKSA PEMBARUAN GAME", "CHECK FOR UPDATES")
	if applied_to_project:
		update_status_label.text = LocScript.pick(
			"Update %s berhasil diterapkan. Mulai ulang permainan agar seluruh perubahan dimuat." % commit_sha.substr(0, 10),
			"Update %s applied. Restart the game to load all changes." % commit_sha.substr(0, 10)
		)
		update_button.tooltip_text = LocScript.pick("Proyek sudah sama dengan commit %s" % commit_sha.substr(0, 10), "Project matches commit %s" % commit_sha.substr(0, 10))
		_show_update_restart_prompt(commit_sha)
	else:
		update_status_label.text = LocScript.pick(
			"Paket source %s sudah diekstrak ke penyimpanan aplikasi, tetapi belum dapat mengganti APK/PCK yang sedang berjalan." % commit_sha.substr(0, 10),
			"Source package %s was extracted, but cannot replace the running APK/PCK directly." % commit_sha.substr(0, 10)
		)
		update_button.tooltip_text = destination_path

func _build_update_restart_modal() -> void:
	var modal: Dictionary = _create_modal(LocScript.pick("PEMBARUAN SIAP", "UPDATE READY"))
	update_restart_overlay = modal["overlay"] as ColorRect
	update_restart_panel = modal["panel"] as PanelContainer
	var body: VBoxContainer = modal["body"] as VBoxContainer
	var explanation := _make_label(
		LocScript.pick(
			"Semua perubahan terbaru sudah siap diterapkan. Mulai ulang permainan sekarang agar skrip, scene, dan aset terbaru dimuat. Progres disimpan otomatis.",
			"All latest updates are ready. Restart now so new scripts, scenes, and assets load cleanly. Progress is saved automatically."
		),
		14, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "body-md"
	)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(explanation)
	update_restart_status = _make_label(LocScript.pick("Disarankan: mulai ulang sekarang.", "Recommended: restart now."), 12, HorrorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT, "mono-sm")
	update_restart_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(update_restart_status)
	var restart_label: String = LocScript.pick("MUAT ULANG HALAMAN", "RELOAD PAGE") if OS.has_feature("web") else (LocScript.pick("TUTUP GAME UNTUK MENERAPKAN", "CLOSE GAME TO APPLY") if OS.has_feature("android") else LocScript.pick("MULAI ULANG SEKARANG", "RESTART NOW"))
	var restart := _make_button(restart_label, true)
	restart.pressed.connect(_restart_after_update)
	body.add_child(restart)
	var later := _make_button(LocScript.pick("NANTI", "LATER"), false, "ghost")
	later.pressed.connect(func() -> void:
		update_restart_overlay.visible = false
		update_status_label.text = LocScript.pick("Pembaruan siap. Muat ulang halaman untuk menerapkan.", "Update ready. Reload the page to apply.") if OS.has_feature("web") else LocScript.pick("Pembaruan siap. Tutup permainan lalu buka kembali Lampor.", "Update ready. Close and reopen Lampor.")
	)
	body.add_child(later)

func _show_update_restart_prompt(commit_sha: String) -> void:
	if update_restart_overlay == null:
		return
	if OS.has_feature("web"):
		update_restart_status.text = LocScript.pick("Commit terpasang: %s · Muat ulang halaman untuk menerapkan." % commit_sha.substr(0, 10), "Installed commit: %s · Reload page to apply." % commit_sha.substr(0, 10))
	elif OS.has_feature("android"):
		update_restart_status.text = LocScript.pick("Commit terpasang: %s · Tutup game lalu buka kembali." % commit_sha.substr(0, 10), "Installed commit: %s · Close and reopen the game." % commit_sha.substr(0, 10))
	else:
		update_restart_status.text = LocScript.pick("Commit terpasang: %s · Mulai ulang disarankan." % commit_sha.substr(0, 10), "Installed commit: %s · Restart recommended." % commit_sha.substr(0, 10))
	_open_modal(update_restart_overlay, update_restart_panel)

func _restart_after_update() -> void:
	if update_restart_status:
		update_restart_status.text = LocScript.pick("Menyimpan progres dan memulai ulang...", "Saving progress and restarting...")
	if GameManager.has_method("prepare_for_update_restart"):
		GameManager.prepare_for_update_restart()
	else:
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
			update_restart_status.text = LocScript.pick("Tidak dapat memulai ulang otomatis. Tutup lalu buka kembali Lampor secara manual.", "Could not restart automatically. Please reopen Lampor manually.")
		return
	get_tree().quit()

func _on_update_failed(message: String) -> void:
	if update_button:
		update_button.disabled = false
		update_button.visible = not UpdateManager.is_git_working_copy()
		update_button.text = LocScript.pick("COBA UPDATE LAGI", "RETRY UPDATE")
		update_button.tooltip_text = message
	if update_check_button:
		update_check_button.text = LocScript.pick("PERIKSA PEMBARUAN GAME", "CHECK FOR UPDATES")
	if update_status_label:
		update_status_label.text = message

func _on_update_button_pressed() -> void:
	update_button.disabled = true
	update_button.text = LocScript.pick("MENGUNDUH...", "DOWNLOADING...")
	UpdateManager.download_update()

func _build_fix_notes_modal() -> void:
	_ensure_markdown_regexes()
	var modal: Dictionary = _create_modal(LocScript.pick("CATATAN PEMBARUAN", "PATCH NOTES"))
	fix_notes_overlay = modal["overlay"] as ColorRect
	fix_notes_panel = modal["panel"] as PanelContainer
	var body: VBoxContainer = modal["body"] as VBoxContainer
	fix_notes_hint_label = _make_label(
		LocScript.pick("Catatan perubahan dari FIX_NOTES.md pada versi game saat ini.", "Release notes from FIX_NOTES.md for the current version."),
		12, HorrorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT, "label-sm"
	)
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

	fix_notes_more_label = _make_label(
		LocScript.pick("Gulir ke bawah untuk memuat catatan versi sebelumnya...", "Scroll down to load earlier version notes..."),
		12, HorrorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER, "label-sm"
	)
	fix_notes_more_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fix_notes_more_label.visible = false
	notes_column.add_child(fix_notes_more_label)

	var close := _make_button(LocScript.pick("TUTUP", "CLOSE"), false, "ghost")
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
	if markdown == fix_notes_rendered_markdown and fix_notes_loaded_sections > 0 and fix_notes_view and not fix_notes_view.get_parsed_text().is_empty():
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
	var top_ov: ColorRect = _get_topmost_visible_modal()
	if top_ov == null:
		return null
	if top_ov == fix_notes_overlay and fix_notes_scroll:
		return fix_notes_scroll
	if top_ov == settings_overlay and settings_scroll:
		return settings_scroll
	if top_ov == shop_overlay and shop_scroll:
		return shop_scroll
	if top_ov == account_overlay and account_scroll:
		return account_scroll
	if top_ov == mode_select_overlay and mode_select_scroll:
		return mode_select_scroll
	if top_ov == mp_server_overlay and mp_rooms_scroll:
		return mp_rooms_scroll
	if top_ov == create_room_overlay and create_room_scroll:
		return create_room_scroll
	if top_ov == room_lobby_overlay:
		if lobby_chat_scroll and lobby_chat_scroll.visible and lobby_chat_scroll.get_global_rect().has_point(get_viewport().get_mouse_position()):
			return lobby_chat_scroll
		if lobby_scroll:
			return lobby_scroll
	return null

func _has_open_option_popup() -> bool:
	for opt: OptionButton in [graphics_option, language_option, character_option, mode_character_option, create_room_max_players_opt, create_room_diff_opt, create_room_timescale_opt]:
		if is_instance_valid(opt) and opt.get_popup().visible:
			return true
	return false

func _is_scroll_drag_blocked_control(control: Control) -> bool:
	return control is HSlider or control is VScrollBar or control is HScrollBar or control is LineEdit or control is TextEdit or control is OptionButton

func _input(event: InputEvent) -> void:
	if not _listening_keybind_action.is_empty():
		if event is InputEventKey:
			var kb_ke := event as InputEventKey
			if kb_ke.pressed and not kb_ke.echo:
				if kb_ke.keycode == KEY_ESCAPE:
					_cancel_keybind_listening()
				else:
					var action_name: String = _listening_keybind_action
					_listening_keybind_action = ""
					SettingsManager.rebind_action(action_name, kb_ke)
					_refresh_keybind_buttons()
				get_viewport().set_input_as_handled()
				return
		elif event is InputEventMouseButton:
			var kb_mb := event as InputEventMouseButton
			if kb_mb.pressed:
				if kb_mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
					var action_name: String = _listening_keybind_action
					_listening_keybind_action = ""
					SettingsManager.rebind_action(action_name, kb_mb)
					_refresh_keybind_buttons()
					get_viewport().set_input_as_handled()
					return
				elif kb_mb.button_index == MOUSE_BUTTON_LEFT:
					_cancel_keybind_listening()
		return

	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_ESCAPE:
			if _has_open_option_popup():
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
			if _has_open_option_popup():
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
		markdown = LocScript.pick(
			"# Catatan Pembaruan\n\nBelum ada catatan untuk versi ini.",
			"# Patch Notes\n\nNo release notes available for this version yet."
		)
	_render_initial_fix_notes(markdown)
	_open_modal(fix_notes_overlay, fix_notes_panel)
	UpdateManager.fetch_latest_fix_notes(true)

func _on_fix_notes_updated(markdown: String, commit_sha: String) -> void:
	if fix_notes_hint_label and not commit_sha.is_empty():
		var short_ref: String = commit_sha.substr(0, 10) if commit_sha.length() > 10 else commit_sha
		fix_notes_hint_label.text = LocScript.pick(
			"Menampilkan FIX_NOTES.md terbaru dari repository (%s)." % short_ref,
			"Showing latest FIX_NOTES.md from repository (%s)." % short_ref
		)
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
	var modal: Dictionary = _create_modal(LocScript.pick("HAK CIPTA", "CREDITS"))
	credits_overlay = modal["overlay"] as ColorRect
	credits_panel = modal["panel"] as PanelContainer
	var body: VBoxContainer = modal["body"] as VBoxContainer

	var title_copy := _make_label("LAMPOR: Malam Jahanam", 17, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "title-lg")
	body.add_child(title_copy)

	var copy := _make_label(
		LocScript.pick(
			"© 2026 AstraDev. Seluruh hak cipta dilindungi.\nKarya fiksi survival horror yang terinspirasi dari folklor Indonesia.",
			"© 2026 AstraDev. All rights reserved.\nA survival horror work of fiction inspired by Indonesian folklore."
		),
		14,
		HorrorTheme.ON_SURFACE_VARIANT,
		HORIZONTAL_ALIGNMENT_LEFT,
		"body-md"
	)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(copy)

	var close := _make_button(LocScript.pick("TUTUP", "CLOSE"), false, "ghost")
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
	return {"overlay": overlay, "panel": panel, "body": body, "title_label": title}

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
		var tr_margin: float = 14.0 if narrow or short_screen else 24.0
		top_right_bar.offset_right = -tr_margin
		top_right_bar.offset_top = tr_margin
		top_right_bar.offset_left = -minf(view_size.x - tr_margin * 2.0, 680.0)
		top_right_bar.offset_bottom = tr_margin + 40.0
	if top_account_chip:
		top_account_chip.visible = not narrow
	if account_btn:
		account_btn.custom_minimum_size.y = 34.0 if narrow or short_screen else 36.0
		account_btn.add_theme_font_size_override("font_size", 10 if narrow else 11)
	if mp_quick_join_row:
		mp_quick_join_row.vertical = narrow
	if lobby_actions_row:
		lobby_actions_row.vertical = narrow

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
		elif panel == mp_server_panel or panel == room_lobby_panel:
			panel.custom_minimum_size = Vector2(maxf(290.0, minf(640.0, view_size.x - 28.0)), panel.custom_minimum_size.y)
		elif panel == create_room_panel:
			panel.custom_minimum_size = Vector2(maxf(290.0, minf(560.0, view_size.x - 28.0)), panel.custom_minimum_size.y)
		elif panel == account_panel or panel == mode_select_panel:
			panel.custom_minimum_size = Vector2(maxf(280.0, minf(520.0, view_size.x - 28.0)), panel.custom_minimum_size.y)
		elif panel == room_password_panel:
			panel.custom_minimum_size = Vector2(maxf(280.0, minf(440.0, view_size.x - 28.0)), panel.custom_minimum_size.y)
		else:
			panel.custom_minimum_size = Vector2(maxf(280.0, minf(500.0, view_size.x - 28.0)), panel.custom_minimum_size.y)
	if settings_scroll:
		settings_scroll.custom_minimum_size.y = maxf(130.0, minf(310.0, view_size.y - 250.0))
	if shop_scroll:
		shop_scroll.custom_minimum_size.y = maxf(140.0, minf(310.0, view_size.y - 260.0))
	if fix_notes_scroll:
		fix_notes_scroll.custom_minimum_size.y = maxf(160.0, minf(450.0, view_size.y - 200.0))
	if account_scroll:
		account_scroll.custom_minimum_size.y = maxf(150.0, minf(400.0, view_size.y - 200.0))
	if mode_select_scroll:
		mode_select_scroll.custom_minimum_size.y = maxf(140.0, minf(360.0, view_size.y - 200.0))
	if mp_rooms_scroll:
		mp_rooms_scroll.custom_minimum_size.y = maxf(120.0, minf(270.0, view_size.y - (350.0 if narrow else 300.0)))
	if create_room_scroll:
		create_room_scroll.custom_minimum_size.y = maxf(150.0, minf(360.0, view_size.y - 220.0))
	if lobby_scroll:
		lobby_scroll.custom_minimum_size.y = maxf(140.0, minf(360.0, view_size.y - (265.0 if narrow else 235.0)))
	if lobby_chat_scroll:
		lobby_chat_scroll.custom_minimum_size.y = maxf(72.0, minf(125.0, view_size.y * 0.17))
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
	var min_top: float = 16.0 if short_screen else (58.0 if narrow else 36.0)
	var avail_h: float = maxf(content_h, view_size.y - footer_clear)
	var max_top: float = maxf(min_top, view_size.y - content_h - footer_clear)
	var top_y: float = clampf((avail_h - content_h) * 0.44, min_top, max_top)
	menu_anchor.position = Vector2(left_pad, top_y)
	menu_anchor.size = Vector2(col_w, content_h)
	main_content.size = Vector2(col_w, content_h)

func _refresh_tutorial_button_visibility() -> void:
	var show_tutorial: bool = not GameManager.tutorial_completed
	if is_instance_valid(tutorial_button):
		tutorial_button.visible = show_tutorial
	if is_instance_valid(tutorial_divider):
		tutorial_divider.visible = show_tutorial
	if is_instance_valid(difficulty_panel):
		difficulty_panel.reset_size()

func _update_nightmare_status() -> void:
	var unlocked: bool = GameManager.is_nightmare_unlocked()
	nightmare_button.disabled = not unlocked
	nightmare_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if unlocked else Control.CURSOR_ARROW
	if unlocked:
		nightmare_lock_label.text = LocScript.pick("Nightmare terbuka. Semoga beruntung.", "Nightmare unlocked. Good luck.")
		nightmare_lock_label.add_theme_color_override("font_color", HorrorTheme.PRIMARY)
	else:
		var remaining: int = 5 - GameManager.total_wins
		nightmare_lock_label.text = LocScript.pick(
			"Terkunci: butuh %d kemenangan lagi (%d/5)." % [remaining, GameManager.total_wins],
			"Locked: requires %d more wins (%d/5)." % [remaining, GameManager.total_wins]
		)
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
		fullscreen_button.text = LocScript.pick("AKTIFKAN LAYAR PENUH", "ENABLE FULLSCREEN")
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		fullscreen_button.text = LocScript.pick("KEMBALI KE MODE JENDELA", "SWITCH TO WINDOWED")

func _start_with_difficulty(diff: GameManager.Difficulty) -> void:
	for overlay: ColorRect in modal_overlays:
		overlay.visible = false
	if MultiplayerManager.is_online_session:
		MultiplayerManager.reset_to_singleplayer()
	GameManager.is_sandbox_mode = false
	GameManager.start_new_game(diff)

# ---------- Gerbang Akun LAMPOR (Force Login / Daftar / Guest) ----------

func _run_initial_account_gate() -> void:
	if AccountManager.account_gate_resolved:
		_refresh_account_ui()
		return
	if account_chip_label:
		account_chip_label.text = LocScript.pick("AKUN: MEMERIKSA SESI...", "ACCOUNT: CHECKING SESSION...")
	if top_account_label:
		top_account_label.text = LocScript.pick("MEMERIKSA...", "CHECKING...")
	var verified: bool = await AccountManager.verify_saved_session()
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_refresh_account_ui()
	_refresh_currency_display()
	_refresh_shop_display()
	_update_nightmare_status()
	_refresh_tutorial_button_visibility()
	if not verified and not AccountManager.can_access_online_modes() and not AccountManager.is_guest_mode:
		_open_account_modal(0)
		if not AccountManager.last_error.strip_edges().is_empty():
			_set_account_status(AccountManager.last_error, HorrorTheme.RELIC_BRASS)

func _on_account_chip_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_open_account_modal(0)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_open_account_modal(0)

func _build_account_modal() -> void:
	var modal: Dictionary = _create_modal(LocScript.pick("AKUN LAMPOR", "LAMPOR ACCOUNT"))
	account_overlay = modal["overlay"] as ColorRect
	account_panel = modal["panel"] as PanelContainer
	account_title_label = modal["title_label"] as Label
	var body: VBoxContainer = modal["body"] as VBoxContainer

	account_scroll = ScrollContainer.new()
	account_scroll.custom_minimum_size = Vector2(0.0, 320.0)
	account_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	account_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	HorrorTheme.style_scroll_container(account_scroll)
	body.add_child(account_scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_right", 8)
	account_scroll.add_child(margin)

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_PASS
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)

	account_auth_section = VBoxContainer.new()
	account_auth_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	account_auth_section.mouse_filter = Control.MOUSE_FILTER_PASS
	account_auth_section.add_theme_constant_override("separation", 10)
	stack.add_child(account_auth_section)

	var gate_desc := _make_label(
		LocScript.pick(
			"Masuk atau buat akun LAMPOR untuk menyimpan progres ke Neon DB serta membuka Multiplayer & Sandbox Mode.",
			"Sign in or create a LAMPOR account to sync progress to Neon DB and unlock Multiplayer & Sandbox Mode."
		),
		12, HorrorTheme.ON_SURFACE_VARIANT, HORIZONTAL_ALIGNMENT_LEFT, "body-md"
	)
	gate_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gate_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	account_auth_section.add_child(gate_desc)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	account_auth_section.add_child(tab_row)

	account_login_tab_btn = _make_button(LocScript.pick("MASUK (LOGIN)", "SIGN IN (LOGIN)"), true)
	account_login_tab_btn.custom_minimum_size.y = 40.0
	account_login_tab_btn.pressed.connect(func() -> void: _select_account_tab(0))
	tab_row.add_child(account_login_tab_btn)

	account_register_tab_btn = _make_button(LocScript.pick("BUAT AKUN (DAFTAR)", "CREATE ACCOUNT"), false, "ghost")
	account_register_tab_btn.custom_minimum_size.y = 40.0
	account_register_tab_btn.pressed.connect(func() -> void: _select_account_tab(1))
	tab_row.add_child(account_register_tab_btn)

	var uname_lbl := _make_label(LocScript.pick("Username (3-24 huruf, angka, _)", "Username (3-24 letters, digits, _)"), 12, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "label-sm")
	uname_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	account_auth_section.add_child(uname_lbl)

	account_username_input = LineEdit.new()
	account_username_input.placeholder_text = LocScript.pick("Contoh: Pemburu_01", "Example: Hunter_01")
	account_username_input.max_length = 24
	account_username_input.custom_minimum_size.y = 42.0
	HorrorTheme.style_line_edit(account_username_input)
	account_auth_section.add_child(account_username_input)

	var pwd_lbl := _make_label(LocScript.pick("Password (min. 8 karakter, huruf & angka)", "Password (min. 8 chars, letters & digits)"), 12, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "label-sm")
	pwd_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	account_auth_section.add_child(pwd_lbl)

	account_password_input = LineEdit.new()
	account_password_input.secret = true
	account_password_input.placeholder_text = LocScript.pick("Masukkan password...", "Enter password...")
	account_password_input.max_length = 72
	account_password_input.custom_minimum_size.y = 42.0
	HorrorTheme.style_line_edit(account_password_input)
	account_password_input.text_submitted.connect(func(_t: String) -> void:
		if account_tab_index == 0:
			_on_account_submit_pressed()
		elif account_confirm_input:
			account_confirm_input.grab_focus()
	)
	account_auth_section.add_child(account_password_input)

	account_confirm_row = VBoxContainer.new()
	account_confirm_row.visible = false
	account_confirm_row.add_theme_constant_override("separation", 6)
	account_auth_section.add_child(account_confirm_row)

	var confirm_lbl := _make_label(LocScript.pick("Konfirmasi Password", "Confirm Password"), 12, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "label-sm")
	confirm_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	account_confirm_row.add_child(confirm_lbl)

	account_confirm_input = LineEdit.new()
	account_confirm_input.secret = true
	account_confirm_input.placeholder_text = LocScript.pick("Ulangi password...", "Repeat password...")
	account_confirm_input.max_length = 72
	account_confirm_input.custom_minimum_size.y = 42.0
	HorrorTheme.style_line_edit(account_confirm_input)
	account_confirm_input.text_submitted.connect(func(_t: String) -> void: _on_account_submit_pressed())
	account_confirm_row.add_child(account_confirm_input)

	account_submit_btn = _make_button(LocScript.pick("MASUK", "SIGN IN"), true)
	account_submit_btn.pressed.connect(_on_account_submit_pressed)
	account_auth_section.add_child(account_submit_btn)

	account_profile_section = VBoxContainer.new()
	account_profile_section.visible = false
	account_profile_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	account_profile_section.mouse_filter = Control.MOUSE_FILTER_PASS
	account_profile_section.add_theme_constant_override("separation", 10)
	stack.add_child(account_profile_section)

	var profile_card := PanelContainer.new()
	profile_card.add_theme_stylebox_override("panel", HorrorTheme.make_chip_style(HorrorTheme.SURFACE_LOW, HorrorTheme.BORDER_SUBTLE, 2, 14, 12))
	account_profile_section.add_child(profile_card)

	account_profile_summary_label = _make_label("", 13, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "mono-sm")
	account_profile_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	account_profile_summary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	profile_card.add_child(account_profile_summary_label)

	var profile_btns := HBoxContainer.new()
	profile_btns.add_theme_constant_override("separation", 8)
	account_profile_section.add_child(profile_btns)

	account_sync_btn = _make_button(LocScript.pick("SINKRONKAN KE CLOUD", "SYNC TO CLOUD"), false, "secondary")
	account_sync_btn.pressed.connect(_on_account_sync_pressed)
	profile_btns.add_child(account_sync_btn)

	account_logout_btn = _make_button(LocScript.pick("KELUAR AKUN (LOGOUT)", "LOGOUT"), false, "danger")
	account_logout_btn.pressed.connect(_on_account_logout_pressed)
	profile_btns.add_child(account_logout_btn)

	account_status_label = _make_label("", 12, HorrorTheme.ON_SURFACE_VARIANT, HORIZONTAL_ALIGNMENT_LEFT, "label-sm")
	account_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	account_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	account_status_label.visible = false
	stack.add_child(account_status_label)

	stack.add_child(HorrorTheme.make_hairline_divider())

	server_settings_toggle_btn = _make_button(LocScript.pick("PENGATURAN SERVER ▸", "SERVER SETTINGS ▸"), false, "ghost")
	server_settings_toggle_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	server_settings_toggle_btn.custom_minimum_size.y = 36.0
	server_settings_toggle_btn.pressed.connect(_toggle_server_settings_box)
	stack.add_child(server_settings_toggle_btn)

	server_settings_box = VBoxContainer.new()
	server_settings_box.visible = false
	server_settings_box.add_theme_constant_override("separation", 8)
	stack.add_child(server_settings_box)

	var srv_url_lbl := _make_label(LocScript.pick("URL Server Vercel / Lokal", "Vercel / Local Server URL"), 11, HorrorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT, "label-sm")
	srv_url_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	server_settings_box.add_child(srv_url_lbl)

	server_url_input = LineEdit.new()
	server_url_input.text = SettingsManager.server_base_url
	server_url_input.placeholder_text = "https://lampor-website.vercel.app"
	server_url_input.custom_minimum_size.y = 40.0
	HorrorTheme.style_line_edit(server_url_input)
	server_settings_box.add_child(server_url_input)

	var srv_btn_row := HBoxContainer.new()
	srv_btn_row.add_theme_constant_override("separation", 8)
	server_settings_box.add_child(srv_btn_row)

	server_save_btn = _make_button(LocScript.pick("SIMPAN URL", "SAVE URL"), false, "secondary")
	server_save_btn.custom_minimum_size.y = 38.0
	server_save_btn.pressed.connect(_on_server_save_pressed)
	srv_btn_row.add_child(server_save_btn)

	server_test_btn = _make_button(LocScript.pick("TES KONEKSI", "TEST CONNECTION"), false, "secondary")
	server_test_btn.custom_minimum_size.y = 38.0
	server_test_btn.pressed.connect(_on_server_test_pressed)
	srv_btn_row.add_child(server_test_btn)

	server_test_label = _make_label("", 11, HorrorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT, "mono-sm")
	server_test_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	server_test_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	server_settings_box.add_child(server_test_label)

	guest_section = VBoxContainer.new()
	guest_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guest_section.add_theme_constant_override("separation", 8)
	stack.add_child(guest_section)

	guest_section.add_child(HorrorTheme.make_hairline_divider())

	var guest_notice := _make_label(
		LocScript.pick(
			"Mode Guest hanya dapat memainkan Singleplayer. Multiplayer & Sandbox terkunci.",
			"Guest Mode can only play Singleplayer. Multiplayer & Sandbox are locked."
		),
		12, HorrorTheme.RELIC_BRASS, HORIZONTAL_ALIGNMENT_LEFT, "label-sm"
	)
	guest_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guest_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guest_section.add_child(guest_notice)

	guest_btn = _make_button(LocScript.pick("LANJUT SEBAGAI GUEST", "CONTINUE AS GUEST"), false, "secondary")
	guest_btn.pressed.connect(_on_guest_pressed)
	guest_section.add_child(guest_btn)

	account_close_btn = _make_button(LocScript.pick("TUTUP", "CLOSE"), false, "ghost")
	account_close_btn.pressed.connect(func() -> void:
		if AccountManager.account_gate_resolved:
			account_overlay.visible = false
	)
	body.add_child(account_close_btn)

func _open_account_modal(tab_idx: int = 0) -> void:
	if server_url_input:
		server_url_input.text = SettingsManager.server_base_url
	_set_account_status("", HorrorTheme.ON_SURFACE_VARIANT)
	_select_account_tab(tab_idx)
	_refresh_account_ui()
	_open_modal(account_overlay, account_panel)
	if not AccountManager.can_access_online_modes() and account_username_input:
		call_deferred("_focus_control_safely", account_username_input)

func _select_account_tab(tab_idx: int) -> void:
	account_tab_index = clampi(tab_idx, 0, 1)
	var is_register: bool = (account_tab_index == 1)
	if account_confirm_row:
		account_confirm_row.visible = is_register
	if account_login_tab_btn:
		HorrorTheme.style_button(account_login_tab_btn, "primary" if not is_register else "ghost", 12, true)
	if account_register_tab_btn:
		HorrorTheme.style_button(account_register_tab_btn, "primary" if is_register else "ghost", 12, true)
	if account_submit_btn:
		account_submit_btn.text = LocScript.pick("BUAT AKUN", "CREATE ACCOUNT") if is_register else LocScript.pick("MASUK", "SIGN IN")
	_set_account_status("", HorrorTheme.ON_SURFACE_VARIANT)

func _toggle_server_settings_box() -> void:
	if not server_settings_box:
		return
	server_settings_box.visible = not server_settings_box.visible
	if server_settings_toggle_btn:
		server_settings_toggle_btn.text = LocScript.pick("PENGATURAN SERVER ▾", "SERVER SETTINGS ▾") if server_settings_box.visible else LocScript.pick("PENGATURAN SERVER ▸", "SERVER SETTINGS ▸")
	if server_settings_box.visible and account_scroll:
		call_deferred("_scroll_to_bottom", account_scroll)

func _scroll_to_bottom(sc: ScrollContainer) -> void:
	if not is_instance_valid(sc):
		return
	var vbar: VScrollBar = sc.get_v_scroll_bar()
	if vbar:
		sc.scroll_vertical = int(vbar.max_value)

func _set_account_status(msg: String, col: Color = HorrorTheme.ON_SURFACE_VARIANT) -> void:
	if not account_status_label:
		return
	account_status_label.text = msg
	account_status_label.visible = not msg.strip_edges().is_empty()
	account_status_label.add_theme_color_override("font_color", col)

func _set_account_busy(busy: bool) -> void:
	_account_busy = busy
	for btn: Button in [account_submit_btn, guest_btn, account_sync_btn, account_logout_btn, server_save_btn, server_test_btn, account_login_tab_btn, account_register_tab_btn]:
		if is_instance_valid(btn):
			btn.disabled = busy
			btn.mouse_default_cursor_shape = Control.CURSOR_ARROW if busy else Control.CURSOR_POINTING_HAND

func _refresh_account_ui() -> void:
	var logged_in: bool = AccountManager.can_access_online_modes()
	var is_guest: bool = AccountManager.is_guest_mode
	var chip_text: String = ""
	var chip_color: Color = HorrorTheme.TEXT_MUTED
	if logged_in:
		chip_text = LocScript.pick("AKUN: %s" % AccountManager.username, "ACCOUNT: %s" % AccountManager.username)
		chip_color = HorrorTheme.SUCCESS_SAGE
	elif is_guest:
		chip_text = "GUEST (OFFLINE)"
		chip_color = HorrorTheme.RELIC_BRASS
	else:
		chip_text = LocScript.pick("BELUM MASUK", "NOT SIGNED IN")
		chip_color = HorrorTheme.PRIMARY
	if account_chip_label:
		account_chip_label.text = chip_text
		account_chip_label.add_theme_color_override("font_color", chip_color)
	if top_account_label:
		top_account_label.text = chip_text
		top_account_label.add_theme_color_override("font_color", chip_color)
	if account_btn:
		account_btn.text = LocScript.pick("AKUN / PROFIL", "ACCOUNT / PROFILE") if logged_in else LocScript.pick("AKUN / MASUK", "ACCOUNT / SIGN IN")
	if account_auth_section:
		account_auth_section.visible = not logged_in
	if account_profile_section:
		account_profile_section.visible = logged_in
	if guest_section:
		guest_section.visible = not logged_in
	if account_close_btn:
		account_close_btn.visible = AccountManager.account_gate_resolved
	if account_title_label:
		if not AccountManager.account_gate_resolved:
			account_title_label.text = LocScript.pick("GERBANG AKUN LAMPOR", "LAMPOR ACCOUNT GATE")
		else:
			account_title_label.text = LocScript.pick("PROFIL AKUN LAMPOR", "LAMPOR ACCOUNT PROFILE") if logged_in else LocScript.pick("AKUN LAMPOR", "LAMPOR ACCOUNT")
	if logged_in and account_profile_summary_label:
		account_profile_summary_label.text = LocScript.pick(
			"Username    : %s\nRole        : %s\nTotal Win   : %d\nKoin Emas   : %d\nNyawa       : %d/%d" % [
				AccountManager.username,
				AccountManager.role.to_upper(),
				GameManager.total_wins,
				GameManager.coins,
				GameManager.extra_lives,
				GameManager.MAX_EXTRA_LIVES
			],
			"Username    : %s\nRole        : %s\nTotal Wins  : %d\nGold Coins  : %d\nExtra Lives : %d/%d" % [
				AccountManager.username,
				AccountManager.role.to_upper(),
				GameManager.total_wins,
				GameManager.coins,
				GameManager.extra_lives,
				GameManager.MAX_EXTRA_LIVES
			]
		)

func _on_account_state_changed() -> void:
	_refresh_account_ui()
	_refresh_currency_display()
	_refresh_shop_display()
	_update_nightmare_status()
	_refresh_tutorial_button_visibility()
	if AccountManager.can_access_online_modes() and mode_lock_box:
		mode_lock_box.visible = false

func _on_account_submit_pressed() -> void:
	if _account_busy:
		return
	var is_register: bool = (account_tab_index == 1)
	var uname: String = account_username_input.text.strip_edges() if account_username_input else ""
	var pwd: String = account_password_input.text if account_password_input else ""
	if is_register:
		var confirm_pwd: String = account_confirm_input.text if account_confirm_input else ""
		if pwd != confirm_pwd:
			_set_account_status(LocScript.pick("Konfirmasi password tidak cocok.", "Password confirmation does not match."), HorrorTheme.ERROR)
			return
	var validation_err: String = AccountManager.validate_credentials_format(uname, pwd, is_register)
	if not validation_err.is_empty():
		_set_account_status(validation_err, HorrorTheme.ERROR)
		return
	_set_account_busy(true)
	if is_register:
		_set_account_status(LocScript.pick("Memverifikasi anti-bot & menyimpan ke Neon DB...", "Verifying anti-bot challenge & saving to Neon DB..."), HorrorTheme.ON_SURFACE_VARIANT)
	else:
		_set_account_status(LocScript.pick("Memverifikasi anti-bot & masuk ke akun...", "Verifying anti-bot challenge & signing in..."), HorrorTheme.ON_SURFACE_VARIANT)
	var res: Dictionary
	if is_register:
		res = await AccountManager.register_account(uname, pwd)
	else:
		res = await AccountManager.login_account(uname, pwd)
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_set_account_busy(false)
	if bool(res.get("ok", false)):
		if account_password_input:
			account_password_input.clear()
		if account_confirm_input:
			account_confirm_input.clear()
		_set_account_status("", HorrorTheme.SUCCESS_SAGE)
		_refresh_currency_display()
		_refresh_shop_display()
		_refresh_account_ui()
		_update_nightmare_status()
		_refresh_tutorial_button_visibility()
		if account_overlay:
			account_overlay.visible = false
		if not _pending_online_mode_after_auth.is_empty():
			var target_mode: String = _pending_online_mode_after_auth
			_pending_online_mode_after_auth = ""
			_open_mp_server_modal(target_mode)
		elif start_button:
			call_deferred("_focus_control_safely", start_button)
	else:
		_set_account_status(_extract_error(res, "Autentikasi gagal. Periksa username/password atau koneksi server.", "Authentication failed. Check credentials or server connection."), HorrorTheme.ERROR)

func _on_guest_pressed() -> void:
	if _account_busy:
		return
	_pending_online_mode_after_auth = ""
	AccountManager.enter_guest_mode()
	_refresh_account_ui()
	_refresh_currency_display()
	if account_overlay:
		account_overlay.visible = false
	if start_button:
		call_deferred("_focus_control_safely", start_button)

func _on_account_sync_pressed() -> void:
	if _account_busy or not AccountManager.can_access_online_modes():
		return
	_set_account_busy(true)
	_set_account_status(LocScript.pick("Menyinkronkan progres ke Neon DB...", "Syncing progress to Neon DB..."), HorrorTheme.ON_SURFACE_VARIANT)
	await AccountManager.sync_profile_to_cloud()
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_set_account_busy(false)
	_refresh_account_ui()
	_refresh_currency_display()
	if AccountManager.last_error.is_empty():
		_set_account_status(LocScript.pick("Progres berhasil disinkronkan ke cloud.", "Progress synced to cloud."), HorrorTheme.SUCCESS_SAGE)
	else:
		_set_account_status(AccountManager.last_error, HorrorTheme.ERROR)

func _on_account_logout_pressed() -> void:
	if _account_busy:
		return
	_set_account_busy(true)
	_set_account_status(LocScript.pick("Keluar dari akun...", "Signing out..."), HorrorTheme.ON_SURFACE_VARIANT)
	await AccountManager.logout_account()
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_set_account_busy(false)
	if account_password_input:
		account_password_input.clear()
	if account_confirm_input:
		account_confirm_input.clear()
	_pending_online_mode_after_auth = ""
	_select_account_tab(0)
	_refresh_account_ui()
	_set_account_status(LocScript.pick("Kamu telah keluar. Masuk kembali atau pilih Mode Guest.", "Signed out. Sign in again or choose Guest Mode."), HorrorTheme.ON_SURFACE_VARIANT)

func _on_server_save_pressed() -> void:
	if not server_url_input:
		return
	var raw: String = server_url_input.text.strip_edges()
	var cleaned: String = SettingsManager.set_server_base_url(raw)
	if cleaned.is_empty():
		if server_test_label:
			server_test_label.text = LocScript.pick("URL server tidak valid. Harus diawali http:// atau https://.", "Invalid server URL. Must start with http:// or https://.")
			server_test_label.add_theme_color_override("font_color", HorrorTheme.ERROR)
		return
	AccountManager.server_base_url = cleaned
	server_url_input.text = cleaned
	if server_test_label:
		server_test_label.text = LocScript.pick("URL server disimpan: %s" % cleaned, "Server URL saved: %s" % cleaned)
		server_test_label.add_theme_color_override("font_color", HorrorTheme.SUCCESS_SAGE)

func _on_server_test_pressed() -> void:
	if _account_busy:
		return
	if server_url_input and not server_url_input.text.strip_edges().is_empty():
		var cleaned: String = SettingsManager.set_server_base_url(server_url_input.text)
		if cleaned.is_empty():
			if server_test_label:
				server_test_label.text = LocScript.pick("URL server tidak valid. Harus diawali http:// atau https://.", "Invalid server URL. Must start with http:// or https://.")
				server_test_label.add_theme_color_override("font_color", HorrorTheme.ERROR)
			return
		AccountManager.server_base_url = cleaned
		server_url_input.text = cleaned
	_set_account_busy(true)
	if server_test_label:
		server_test_label.text = LocScript.pick("Menguji koneksi ke %s..." % SettingsManager.server_base_url, "Testing connection to %s..." % SettingsManager.server_base_url)
		server_test_label.add_theme_color_override("font_color", HorrorTheme.ON_SURFACE_VARIANT)
	var res: Dictionary = await MultiplayerManager.check_server_health()
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_set_account_busy(false)
	if server_test_label:
		if bool(res.get("ok", false)):
			var data: Dictionary = _unwrap_payload(res)
			var ver: String = str(data.get("version", "1.3.0"))
			var db_ms: int = int(data.get("dbLatencyMs", 0))
			var maint: bool = bool(data.get("maintenanceMode", false))
			if maint:
				var m_msg: String = str(data.get("maintenanceMessage", ""))
				server_test_label.text = LocScript.pick("Server %s dalam MAINTENANCE (%s)" % [ver, m_msg], "Server %s in MAINTENANCE (%s)" % [ver, m_msg])
				server_test_label.add_theme_color_override("font_color", HorrorTheme.RELIC_BRASS)
			else:
				server_test_label.text = LocScript.pick("Terhubung! Versi %s · DB %d ms" % [ver, db_ms], "Connected! Version %s · DB %d ms" % [ver, db_ms])
				server_test_label.add_theme_color_override("font_color", HorrorTheme.SUCCESS_SAGE)
		else:
			server_test_label.text = _extract_error(res, "Gagal menghubungi server.", "Could not reach server.")
			server_test_label.add_theme_color_override("font_color", HorrorTheme.ERROR)

# ---------- Peramban Server Multiplayer & Sandbox ----------

func _build_mp_server_modal() -> void:
	var modal: Dictionary = _create_modal(LocScript.pick("MULTIPLAYER SERVER", "MULTIPLAYER SERVER"))
	mp_server_overlay = modal["overlay"] as ColorRect
	mp_server_panel = modal["panel"] as PanelContainer
	mp_server_title_label = modal["title_label"] as Label
	var body: VBoxContainer = modal["body"] as VBoxContainer

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	body.add_child(top_row)

	mp_server_status_label = _make_label(LocScript.pick("Server: Menghubungkan...", "Server: Connecting..."), 12, HorrorTheme.ON_SURFACE_VARIANT, HORIZONTAL_ALIGNMENT_LEFT, "mono-sm")
	mp_server_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_server_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top_row.add_child(mp_server_status_label)

	mp_refresh_btn = _make_button(LocScript.pick("SEGARKAN", "REFRESH"), false, "secondary")
	mp_refresh_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	mp_refresh_btn.custom_minimum_size = Vector2(98.0, 38.0)
	mp_refresh_btn.pressed.connect(_refresh_mp_server_and_rooms)
	top_row.add_child(mp_refresh_btn)

	mp_create_room_btn = _make_button(LocScript.pick("CREATE ROOM", "CREATE ROOM"), true)
	mp_create_room_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	mp_create_room_btn.custom_minimum_size = Vector2(126.0, 38.0)
	mp_create_room_btn.pressed.connect(_open_create_room_modal)
	top_row.add_child(mp_create_room_btn)

	mp_quick_join_row = BoxContainer.new()
	mp_quick_join_row.add_theme_constant_override("separation", 8)
	body.add_child(mp_quick_join_row)

	room_code_input = LineEdit.new()
	room_code_input.placeholder_text = LocScript.pick("Kode 6 huruf...", "6-char code...")
	room_code_input.max_length = 6
	room_code_input.custom_minimum_size = Vector2(115.0, 40.0)
	room_code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HorrorTheme.style_line_edit(room_code_input)
	mp_quick_join_row.add_child(room_code_input)

	join_password_input = LineEdit.new()
	join_password_input.secret = true
	join_password_input.placeholder_text = LocScript.pick("Password (opsional)", "Password (optional)")
	join_password_input.max_length = 48
	join_password_input.custom_minimum_size = Vector2(130.0, 40.0)
	join_password_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HorrorTheme.style_line_edit(join_password_input)
	join_password_input.text_submitted.connect(func(_t: String) -> void: _on_join_code_pressed())
	mp_quick_join_row.add_child(join_password_input)

	mp_join_code_btn = _make_button(LocScript.pick("GABUNG KODE", "JOIN CODE"), false, "secondary")
	mp_join_code_btn.custom_minimum_size = Vector2(122.0, 40.0)
	mp_join_code_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	mp_join_code_btn.pressed.connect(_on_join_code_pressed)
	mp_quick_join_row.add_child(mp_join_code_btn)

	mp_server_feedback_label = _make_label("", 12, HorrorTheme.ERROR, HORIZONTAL_ALIGNMENT_LEFT, "label-sm")
	mp_server_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mp_server_feedback_label.visible = false
	body.add_child(mp_server_feedback_label)

	mp_rooms_scroll = ScrollContainer.new()
	mp_rooms_scroll.custom_minimum_size = Vector2(0.0, 220.0)
	mp_rooms_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mp_rooms_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	HorrorTheme.style_scroll_container(mp_rooms_scroll)
	body.add_child(mp_rooms_scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_right", 8)
	mp_rooms_scroll.add_child(margin)

	mp_rooms_list = VBoxContainer.new()
	mp_rooms_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_rooms_list.mouse_filter = Control.MOUSE_FILTER_PASS
	mp_rooms_list.add_theme_constant_override("separation", 8)
	margin.add_child(mp_rooms_list)

	var back := _make_button(LocScript.pick("KEMBALI", "BACK"), false, "ghost")
	back.pressed.connect(func() -> void:
		mp_server_overlay.visible = false
		_reset_mode_select_lock_notice()
		_open_modal(mode_select_overlay, mode_select_panel)
	)
	body.add_child(back)

func _open_mp_server_modal(mode: String) -> void:
	mp_mode_filter = "sandbox" if mode == "sandbox" else "multiplayer"
	if mp_server_title_label:
		mp_server_title_label.text = LocScript.pick("SANDBOX SERVER", "SANDBOX SERVER") if mp_mode_filter == "sandbox" else LocScript.pick("MULTIPLAYER SERVER", "MULTIPLAYER SERVER")
	if room_code_input:
		room_code_input.clear()
	if join_password_input:
		join_password_input.clear()
	_set_mp_server_feedback("", HorrorTheme.ON_SURFACE_VARIANT)
	_open_modal(mp_server_overlay, mp_server_panel)
	_refresh_mp_server_and_rooms()

func _set_mp_server_feedback(msg: String, col: Color = HorrorTheme.ERROR) -> void:
	if not mp_server_feedback_label:
		return
	mp_server_feedback_label.text = msg
	mp_server_feedback_label.visible = not msg.strip_edges().is_empty()
	mp_server_feedback_label.add_theme_color_override("font_color", col)

func _refresh_mp_server_and_rooms() -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_mp_rooms_loading = true
	_render_mp_room_list([])
	if mp_refresh_btn:
		mp_refresh_btn.disabled = true
	if mp_server_status_label:
		mp_server_status_label.text = LocScript.pick("Server: Memeriksa...", "Server: Checking...")
		mp_server_status_label.add_theme_color_override("font_color", HorrorTheme.ON_SURFACE_VARIANT)

	var t0: int = Time.get_ticks_msec()
	var health_res: Dictionary = await MultiplayerManager.check_server_health()
	if not is_instance_valid(self) or not is_inside_tree():
		return
	var rtt: int = maxi(1, Time.get_ticks_msec() - t0)
	if mp_server_status_label:
		if bool(health_res.get("ok", false)):
			var hdata: Dictionary = _unwrap_payload(health_res)
			if bool(hdata.get("maintenanceMode", false)):
				mp_server_status_label.text = LocScript.pick("Server: MAINTENANCE (%s)" % str(hdata.get("maintenanceMessage", "")), "Server: MAINTENANCE (%s)" % str(hdata.get("maintenanceMessage", "")))
				mp_server_status_label.add_theme_color_override("font_color", HorrorTheme.RELIC_BRASS)
			else:
				mp_server_status_label.text = LocScript.pick("Server: Online (%d ms)" % rtt, "Server: Online (%d ms)" % rtt)
				mp_server_status_label.add_theme_color_override("font_color", HorrorTheme.SUCCESS_SAGE)
		else:
			mp_server_status_label.text = LocScript.pick("Server: Tidak Terjangkau", "Server: Unreachable")
			mp_server_status_label.add_theme_color_override("font_color", HorrorTheme.ERROR)

	var rooms_res: Dictionary = await MultiplayerManager.list_rooms(mp_mode_filter)
	if not is_instance_valid(self) or not is_inside_tree():
		return
	var was_loading: bool = _mp_rooms_loading
	_mp_rooms_loading = false
	if mp_refresh_btn:
		mp_refresh_btn.disabled = false
	if bool(rooms_res.get("ok", false)):
		if was_loading:
			var rdata: Dictionary = _unwrap_payload(rooms_res)
			var list_var: Variant = rdata.get("rooms", _mp_last_rooms)
			var rooms_arr: Array = list_var if list_var is Array else _mp_last_rooms
			_mp_last_rooms = rooms_arr
			_render_mp_room_list(rooms_arr)
	else:
		_render_mp_room_list([])
		_set_mp_server_feedback(_extract_error(rooms_res, "Gagal memuat daftar room.", "Failed to load room list."), HorrorTheme.ERROR)

func _on_multiplayer_rooms_updated(rooms: Array) -> void:
	_mp_last_rooms = rooms
	_mp_rooms_loading = false
	if mp_server_overlay and mp_server_overlay.visible:
		_render_mp_room_list(rooms)

func _render_mp_room_list(rooms: Array) -> void:
	if not is_instance_valid(mp_rooms_list):
		return
	for child: Node in mp_rooms_list.get_children():
		child.queue_free()
	if _mp_rooms_loading:
		var loading_lbl := _make_label(LocScript.pick("Memuat daftar room aktif...", "Loading active rooms..."), 13, HorrorTheme.ON_SURFACE_VARIANT, HORIZONTAL_ALIGNMENT_CENTER, "body-md")
		loading_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mp_rooms_list.add_child(loading_lbl)
		return
	var filtered: Array = []
	for item: Variant in rooms:
		if item is Dictionary:
			var r_mode: String = str((item as Dictionary).get("mode", mp_mode_filter))
			if r_mode == mp_mode_filter:
				filtered.append(item)
	if filtered.is_empty():
		var empty_lbl := _make_label(
			LocScript.pick(
				"Belum ada room aktif. Tekan CREATE ROOM untuk membuat room.",
				"No active rooms yet. Press CREATE ROOM to create a room."
			),
			13, HorrorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER, "body-md"
		)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mp_rooms_list.add_child(empty_lbl)
		return

	for room_var: Variant in filtered:
		var r: Dictionary = room_var as Dictionary
		var room_id: String = str(r.get("id", r.get("roomId", "")))
		var room_code: String = str(r.get("roomCode", r.get("code", "")))
		var room_name: String = str(r.get("name", "Room"))
		var host_name: String = str(r.get("hostUsername", r.get("host", "Host")))
		var p_count: int = int(r.get("playerCount", 1))
		var p_max: int = int(r.get("maxPlayers", 4))
		var has_pwd: bool = bool(r.get("hasPassword", false))
		var diff_str: String = str(r.get("difficulty", "normal")).to_upper()
		var can_shop: bool = bool(r.get("canUseShopItems", true))
		var status_str: String = str(r.get("status", "lobby"))
		var settings_dict: Dictionary = r.get("settings", {}) if r.get("settings") is Dictionary else {}
		var allow_late: bool = bool(r.get("allowLateJoin", settings_dict.get("allowLateJoin", false)))

		var card := PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.add_theme_stylebox_override("panel", HorrorTheme.make_chip_style(HorrorTheme.SURFACE_LOW, HorrorTheme.BORDER_SUBTLE, 2, 12, 10))
		mp_rooms_list.add_child(card)

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_theme_constant_override("separation", 3)
		row.add_child(info)

		var tags: String = ""
		if has_pwd:
			tags += "  [BERPASSWORD]" if not LocScript.is_en() else "  [PASSWORD]"
		if status_str == "playing":
			tags += "  [SEDANG MAIN]" if not LocScript.is_en() else "  [PLAYING]"

		var title_lbl := _make_label("%s%s" % [room_name, tags], 14, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "title-lg")
		title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(title_lbl)

		var shop_tag: String = "ON" if can_shop else "OFF"
		var meta_lbl := _make_label(
			LocScript.pick(
				"Host: %s  ·  Pemain: %d/%d  ·  %s  ·  Shop Item: %s%s" % [host_name, p_count, p_max, diff_str, shop_tag, ("  ·  Kode: " + room_code) if not room_code.is_empty() else ""],
				"Host: %s  ·  Players: %d/%d  ·  %s  ·  Shop Item: %s%s" % [host_name, p_count, p_max, diff_str, shop_tag, ("  ·  Code: " + room_code) if not room_code.is_empty() else ""]
			),
			11, HorrorTheme.ON_SURFACE_VARIANT, HORIZONTAL_ALIGNMENT_LEFT, "mono-sm"
		)
		meta_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		meta_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(meta_lbl)

		var is_full: bool = p_count >= p_max
		var locked_playing: bool = (status_str == "playing" and not allow_late)
		var join_btn_label: String = LocScript.pick("PENUH", "FULL") if is_full else (LocScript.pick("MAIN", "PLAYING") if locked_playing else LocScript.pick("GABUNG", "JOIN"))
		var join_btn := _make_button(join_btn_label, not is_full and not locked_playing)
		join_btn.custom_minimum_size = Vector2(92.0, 40.0)
		join_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		join_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		join_btn.disabled = is_full or locked_playing
		join_btn.pressed.connect(_on_room_join_pressed.bind(room_id, room_name, has_pwd))
		row.add_child(join_btn)

func _on_join_code_pressed() -> void:
	if not room_code_input:
		return
	var code: String = room_code_input.text.strip_edges().to_upper()
	if code.length() != 6:
		_set_mp_server_feedback(LocScript.pick("Masukkan kode room 6 karakter yang valid.", "Enter a valid 6-character room code."), HorrorTheme.ERROR)
		return
	var pwd: String = join_password_input.text if join_password_input else ""
	await _join_mp_room(code, pwd, false)

func _on_room_join_pressed(room_id: String, room_name: String, has_pwd: bool) -> void:
	if has_pwd:
		_pending_join_room_id = room_id
		if room_password_room_label:
			room_password_room_label.text = LocScript.pick("Masukkan password untuk room \"%s\":" % room_name, "Enter password for room \"%s\":" % room_name)
		if room_password_input:
			room_password_input.clear()
		if room_password_error_label:
			room_password_error_label.text = ""
			room_password_error_label.visible = false
		_open_modal(room_password_overlay, room_password_panel)
		if room_password_input:
			call_deferred("_focus_control_safely", room_password_input)
		return
	await _join_mp_room(room_id, "", false)

func _build_room_password_modal() -> void:
	var modal: Dictionary = _create_modal(LocScript.pick("PASSWORD ROOM", "ROOM PASSWORD"))
	room_password_overlay = modal["overlay"] as ColorRect
	room_password_panel = modal["panel"] as PanelContainer
	var body: VBoxContainer = modal["body"] as VBoxContainer

	room_password_room_label = _make_label("", 13, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "body-md")
	room_password_room_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(room_password_room_label)

	room_password_input = LineEdit.new()
	room_password_input.secret = true
	room_password_input.placeholder_text = LocScript.pick("Password room...", "Room password...")
	room_password_input.max_length = 48
	room_password_input.custom_minimum_size.y = 42.0
	HorrorTheme.style_line_edit(room_password_input)
	room_password_input.text_submitted.connect(func(_t: String) -> void:
		if not _pending_join_room_id.is_empty():
			_join_mp_room(_pending_join_room_id, room_password_input.text, true)
	)
	body.add_child(room_password_input)

	room_password_error_label = _make_label("", 12, HorrorTheme.ERROR, HORIZONTAL_ALIGNMENT_LEFT, "label-sm")
	room_password_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	room_password_error_label.visible = false
	body.add_child(room_password_error_label)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	body.add_child(btns)

	var cancel := _make_button(LocScript.pick("BATAL", "CANCEL"), false, "ghost")
	cancel.pressed.connect(func() -> void:
		_pending_join_room_id = ""
		room_password_overlay.visible = false
	)
	btns.add_child(cancel)

	room_password_join_btn = _make_button(LocScript.pick("MASUK ROOM", "JOIN ROOM"), true)
	room_password_join_btn.pressed.connect(func() -> void:
		if not _pending_join_room_id.is_empty():
			_join_mp_room(_pending_join_room_id, room_password_input.text, true)
	)
	btns.add_child(room_password_join_btn)

func _join_mp_room(room_id_or_code: String, password: String, from_pwd_modal: bool) -> void:
	if mp_join_code_btn:
		mp_join_code_btn.disabled = true
	if room_password_join_btn:
		room_password_join_btn.disabled = true
	_set_mp_server_feedback(LocScript.pick("Menghubungkan ke room...", "Joining room..."), HorrorTheme.ON_SURFACE_VARIANT)
	var res: Dictionary = await MultiplayerManager.join_room(room_id_or_code, password)
	if not is_instance_valid(self) or not is_inside_tree():
		return
	if mp_join_code_btn:
		mp_join_code_btn.disabled = false
	if room_password_join_btn:
		room_password_join_btn.disabled = false
	if bool(res.get("ok", false)):
		_pending_join_room_id = ""
		_set_mp_server_feedback("", HorrorTheme.ON_SURFACE_VARIANT)
		if room_password_overlay:
			room_password_overlay.visible = false
		if mp_server_overlay:
			mp_server_overlay.visible = false
		if _launching_online_game or str(MultiplayerManager.current_room.get("status", "")).to_lower() == "playing":
			return
		_open_room_lobby_modal()
	else:
		var err_msg: String = _extract_error(res, "Gagal masuk ke room.", "Failed to join room.")
		if from_pwd_modal and room_password_error_label:
			room_password_error_label.text = err_msg
			room_password_error_label.visible = true
		else:
			_set_mp_server_feedback(err_msg, HorrorTheme.ERROR)

# ---------- Buat Room (Create Room Modal) ----------

func _build_create_room_modal() -> void:
	var modal: Dictionary = _create_modal(LocScript.pick("CREATE ROOM", "CREATE ROOM"))
	create_room_overlay = modal["overlay"] as ColorRect
	create_room_panel = modal["panel"] as PanelContainer
	var body: VBoxContainer = modal["body"] as VBoxContainer

	create_room_mode_badge = _make_label("", 12, HorrorTheme.RELIC_BRASS, HORIZONTAL_ALIGNMENT_LEFT, "mono-sm")
	create_room_mode_badge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(create_room_mode_badge)

	create_room_scroll = ScrollContainer.new()
	create_room_scroll.custom_minimum_size = Vector2(0.0, 290.0)
	create_room_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	create_room_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	HorrorTheme.style_scroll_container(create_room_scroll)
	body.add_child(create_room_scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_right", 8)
	create_room_scroll.add_child(margin)

	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.mouse_filter = Control.MOUSE_FILTER_PASS
	form.add_theme_constant_override("separation", 10)
	margin.add_child(form)

	var name_lbl := _make_label(LocScript.pick("Nama Room *", "Room Name *"), 12, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "label-sm")
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	form.add_child(name_lbl)

	create_room_name_input = LineEdit.new()
	create_room_name_input.placeholder_text = LocScript.pick("Nama desa / room...", "Village / room name...")
	create_room_name_input.max_length = 40
	create_room_name_input.custom_minimum_size.y = 40.0
	HorrorTheme.style_line_edit(create_room_name_input)
	form.add_child(create_room_name_input)

	var pwd_lbl := _make_label(LocScript.pick("Password Room (Opsional)", "Room Password (Optional)"), 12, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "label-sm")
	pwd_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	form.add_child(pwd_lbl)

	create_room_password_input = LineEdit.new()
	create_room_password_input.secret = true
	create_room_password_input.placeholder_text = LocScript.pick("Kosongkan jika publik", "Leave empty for public")
	create_room_password_input.max_length = 48
	create_room_password_input.custom_minimum_size.y = 40.0
	HorrorTheme.style_line_edit(create_room_password_input)
	form.add_child(create_room_password_input)

	var max_row := HBoxContainer.new()
	max_row.add_theme_constant_override("separation", 8)
	form.add_child(max_row)
	var max_lbl := _make_label(LocScript.pick("Max Player (Maks 4)", "Max Players (Max 4)"), 12, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "body-md")
	max_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	max_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	max_row.add_child(max_lbl)
	create_room_max_players_opt = OptionButton.new()
	create_room_max_players_opt.custom_minimum_size = Vector2(190.0, 40.0)
	HorrorTheme.style_option_button(create_room_max_players_opt)
	max_row.add_child(create_room_max_players_opt)

	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 8)
	form.add_child(diff_row)
	var diff_lbl := _make_label(LocScript.pick("Tingkat Kesulitan", "Difficulty"), 12, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "body-md")
	diff_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diff_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diff_row.add_child(diff_lbl)
	create_room_diff_opt = OptionButton.new()
	create_room_diff_opt.custom_minimum_size = Vector2(190.0, 40.0)
	create_room_diff_opt.add_item("Easy")
	create_room_diff_opt.set_item_metadata(0, "easy")
	create_room_diff_opt.add_item("Normal")
	create_room_diff_opt.set_item_metadata(1, "normal")
	create_room_diff_opt.add_item("Hard")
	create_room_diff_opt.set_item_metadata(2, "hard")
	create_room_diff_opt.add_item("Nightmare")
	create_room_diff_opt.set_item_metadata(3, "nightmare")
	create_room_diff_opt.select(1)
	HorrorTheme.style_option_button(create_room_diff_opt)
	diff_row.add_child(create_room_diff_opt)

	create_room_shop_chk = CheckButton.new()
	create_room_shop_chk.text = LocScript.pick("Gunakan Item dari Toko", "Allow Shop Items")
	create_room_shop_chk.custom_minimum_size.y = 40.0
	create_room_shop_chk.button_pressed = true
	HorrorTheme.style_check_button(create_room_shop_chk)
	form.add_child(create_room_shop_chk)

	form.add_child(HorrorTheme.make_hairline_divider())

	var extra_title := _make_label(LocScript.pick("PENGATURAN ROOM TAMBAHAN", "ADDITIONAL ROOM SETTINGS"), 12, HorrorTheme.PRIMARY, HORIZONTAL_ALIGNMENT_LEFT, "label-lg")
	extra_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	form.add_child(extra_title)

	create_room_lampor_chk = CheckButton.new()
	create_room_lampor_chk.text = LocScript.pick("Aktifkan Lampor AI", "Enable Lampor AI")
	create_room_lampor_chk.custom_minimum_size.y = 40.0
	create_room_lampor_chk.button_pressed = true
	HorrorTheme.style_check_button(create_room_lampor_chk)
	form.add_child(create_room_lampor_chk)

	var ts_row := HBoxContainer.new()
	ts_row.add_theme_constant_override("separation", 8)
	form.add_child(ts_row)
	var ts_lbl := _make_label(LocScript.pick("Kecepatan Jam Malam", "Night Clock Speed"), 12, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "body-md")
	ts_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ts_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ts_row.add_child(ts_lbl)
	create_room_timescale_opt = OptionButton.new()
	create_room_timescale_opt.custom_minimum_size = Vector2(190.0, 40.0)
	create_room_timescale_opt.add_item(LocScript.pick("0.5x (Lambat)", "0.5x (Slow)"))
	create_room_timescale_opt.set_item_metadata(0, 0.5)
	create_room_timescale_opt.add_item(LocScript.pick("1.0x (Normal)", "1.0x (Normal)"))
	create_room_timescale_opt.set_item_metadata(1, 1.0)
	create_room_timescale_opt.add_item(LocScript.pick("1.5x (Cepat)", "1.5x (Fast)"))
	create_room_timescale_opt.set_item_metadata(2, 1.5)
	create_room_timescale_opt.add_item(LocScript.pick("2.0x (Kilat)", "2.0x (Turbo)"))
	create_room_timescale_opt.set_item_metadata(3, 2.0)
	create_room_timescale_opt.select(1)
	HorrorTheme.style_option_button(create_room_timescale_opt)
	ts_row.add_child(create_room_timescale_opt)

	create_room_late_join_chk = CheckButton.new()
	create_room_late_join_chk.text = LocScript.pick("Izinkan Gabung Saat Main", "Allow Join In-Progress")
	create_room_late_join_chk.custom_minimum_size.y = 40.0
	create_room_late_join_chk.button_pressed = false
	HorrorTheme.style_check_button(create_room_late_join_chk)
	form.add_child(create_room_late_join_chk)

	create_room_revive_chk = CheckButton.new()
	create_room_revive_chk.text = LocScript.pick("Bangkit Otomatis Rekan", "Auto-Revive Teammates")
	create_room_revive_chk.custom_minimum_size.y = 40.0
	create_room_revive_chk.button_pressed = true
	HorrorTheme.style_check_button(create_room_revive_chk)
	form.add_child(create_room_revive_chk)

	create_room_status_label = _make_label("", 12, HorrorTheme.ERROR, HORIZONTAL_ALIGNMENT_LEFT, "label-sm")
	create_room_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	create_room_status_label.visible = false
	body.add_child(create_room_status_label)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	body.add_child(btns)

	var cancel := _make_button(LocScript.pick("BATAL", "CANCEL"), false, "ghost")
	cancel.pressed.connect(func() -> void:
		create_room_overlay.visible = false
		_open_modal(mp_server_overlay, mp_server_panel)
	)
	btns.add_child(cancel)

	create_room_submit_btn = _make_button(LocScript.pick("BUAT & MASUK LOBBY", "CREATE & ENTER LOBBY"), true)
	create_room_submit_btn.pressed.connect(_on_create_room_submit_pressed)
	btns.add_child(create_room_submit_btn)

func _open_create_room_modal() -> void:
	if create_room_mode_badge:
		if mp_mode_filter == "sandbox":
			create_room_mode_badge.text = LocScript.pick("MODE: SANDBOX (Owner mendapat Sandbox Panel [Ctrl+F5] / mobile)", "MODE: SANDBOX (Owner gets Sandbox Panel [Ctrl+F5] / mobile)")
		else:
			create_room_mode_badge.text = LocScript.pick("MODE: MULTIPLAYER CO-OP", "MODE: MULTIPLAYER CO-OP")
	if create_room_name_input:
		var owner_name: String = AccountManager.username if not AccountManager.username.is_empty() else "Pemain"
		create_room_name_input.text = LocScript.pick("Desa %s" % owner_name, "%s's Village" % owner_name)
	if create_room_password_input:
		create_room_password_input.clear()
	if create_room_max_players_opt:
		create_room_max_players_opt.clear()
		if mp_mode_filter == "sandbox":
			create_room_max_players_opt.add_item(LocScript.pick("1 Pemain (Solo Sandbox)", "1 Player (Solo Sandbox)"))
			create_room_max_players_opt.set_item_metadata(0, 1)
			create_room_max_players_opt.add_item(LocScript.pick("2 Pemain", "2 Players"))
			create_room_max_players_opt.set_item_metadata(1, 2)
			create_room_max_players_opt.add_item(LocScript.pick("3 Pemain", "3 Players"))
			create_room_max_players_opt.set_item_metadata(2, 3)
			create_room_max_players_opt.add_item(LocScript.pick("4 Pemain", "4 Players"))
			create_room_max_players_opt.set_item_metadata(3, 4)
			create_room_max_players_opt.select(0)
		else:
			create_room_max_players_opt.add_item(LocScript.pick("2 Pemain", "2 Players"))
			create_room_max_players_opt.set_item_metadata(0, 2)
			create_room_max_players_opt.add_item(LocScript.pick("3 Pemain", "3 Players"))
			create_room_max_players_opt.set_item_metadata(1, 3)
			create_room_max_players_opt.add_item(LocScript.pick("4 Pemain", "4 Players"))
			create_room_max_players_opt.set_item_metadata(2, 4)
			create_room_max_players_opt.select(2)
	if create_room_diff_opt:
		create_room_diff_opt.select(1)
	if create_room_shop_chk:
		create_room_shop_chk.button_pressed = true
	if create_room_lampor_chk:
		create_room_lampor_chk.button_pressed = true
	if create_room_timescale_opt:
		create_room_timescale_opt.select(1)
	if create_room_late_join_chk:
		create_room_late_join_chk.button_pressed = false
	if create_room_revive_chk:
		create_room_revive_chk.button_pressed = true
	if create_room_status_label:
		create_room_status_label.text = ""
		create_room_status_label.visible = false
	if create_room_scroll:
		create_room_scroll.scroll_vertical = 0
	if mp_server_overlay:
		mp_server_overlay.visible = false
	_open_modal(create_room_overlay, create_room_panel)

func _on_create_room_submit_pressed() -> void:
	var rname: String = create_room_name_input.text.strip_edges() if create_room_name_input else ""
	if rname.length() < 2:
		if create_room_status_label:
			create_room_status_label.text = LocScript.pick("Nama room minimal 2 karakter.", "Room name must be at least 2 characters.")
			create_room_status_label.add_theme_color_override("font_color", HorrorTheme.ERROR)
			create_room_status_label.visible = true
		return
	var max_p: int = int(create_room_max_players_opt.get_selected_metadata()) if create_room_max_players_opt else 4
	var diff_str: String = str(create_room_diff_opt.get_selected_metadata()) if create_room_diff_opt else "normal"
	var ts_val: float = float(create_room_timescale_opt.get_selected_metadata()) if create_room_timescale_opt else 1.0
	var config: Dictionary = {
		"name": rname,
		"password": create_room_password_input.text if create_room_password_input else "",
		"mode": mp_mode_filter,
		"maxPlayers": clampi(max_p, 1, 4),
		"difficulty": diff_str,
		"canUseShopItems": create_room_shop_chk.button_pressed if create_room_shop_chk else true,
		"settings": {
			"lamporEnabled": create_room_lampor_chk.button_pressed if create_room_lampor_chk else true,
			"timeScale": ts_val,
			"allowLateJoin": create_room_late_join_chk.button_pressed if create_room_late_join_chk else false,
			"friendlyRevive": create_room_revive_chk.button_pressed if create_room_revive_chk else true
		}
	}
	if create_room_submit_btn:
		create_room_submit_btn.disabled = true
	if create_room_status_label:
		create_room_status_label.text = LocScript.pick("Membuat room di server...", "Creating room on server...")
		create_room_status_label.add_theme_color_override("font_color", HorrorTheme.ON_SURFACE_VARIANT)
		create_room_status_label.visible = true
	var res: Dictionary = await MultiplayerManager.create_room(config)
	if not is_instance_valid(self) or not is_inside_tree():
		return
	if create_room_submit_btn:
		create_room_submit_btn.disabled = false
	if bool(res.get("ok", false)):
		if create_room_overlay:
			create_room_overlay.visible = false
		if mp_server_overlay:
			mp_server_overlay.visible = false
		_open_room_lobby_modal()
	else:
		if create_room_status_label:
			create_room_status_label.text = _extract_error(res, "Gagal membuat room.", "Failed to create room.")
			create_room_status_label.add_theme_color_override("font_color", HorrorTheme.ERROR)
			create_room_status_label.visible = true

# ---------- Room Lobby Modal ----------

func _build_room_lobby_modal() -> void:
	var modal: Dictionary = _create_modal(LocScript.pick("ROOM LOBBY", "ROOM LOBBY"))
	room_lobby_overlay = modal["overlay"] as ColorRect
	room_lobby_panel = modal["panel"] as PanelContainer
	var body: VBoxContainer = modal["body"] as VBoxContainer

	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 8)
	body.add_child(head_row)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 2)
	head_row.add_child(title_col)

	lobby_room_name_label = _make_label("Room", 16, HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "title-lg")
	lobby_room_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_col.add_child(lobby_room_name_label)

	lobby_mode_badge_label = _make_label("MULTIPLAYER", 11, HorrorTheme.RELIC_BRASS, HORIZONTAL_ALIGNMENT_LEFT, "mono-sm")
	title_col.add_child(lobby_mode_badge_label)

	var code_col := HBoxContainer.new()
	code_col.add_theme_constant_override("separation", 6)
	code_col.size_flags_horizontal = Control.SIZE_SHRINK_END
	code_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head_row.add_child(code_col)

	var code_chip := PanelContainer.new()
	code_chip.add_theme_stylebox_override("panel", HorrorTheme.make_chip_style(HorrorTheme.SURFACE_LOWEST, HorrorTheme.OUTLINE_VARIANT, 2, 10, 6))
	code_col.add_child(code_chip)

	lobby_room_code_label = _make_label("KODE: ------", 12, HorrorTheme.PRIMARY, HORIZONTAL_ALIGNMENT_CENTER, "mono-sm")
	code_chip.add_child(lobby_room_code_label)

	lobby_copy_code_btn = _make_button(LocScript.pick("SALIN KODE", "COPY CODE"), false, "secondary")
	lobby_copy_code_btn.custom_minimum_size = Vector2(102.0, 34.0)
	lobby_copy_code_btn.pressed.connect(_on_lobby_copy_code_pressed)
	code_col.add_child(lobby_copy_code_btn)

	lobby_settings_summary_label = _make_label("", 11, HorrorTheme.ON_SURFACE_VARIANT, HORIZONTAL_ALIGNMENT_LEFT, "mono-sm")
	lobby_settings_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(lobby_settings_summary_label)

	lobby_scroll = ScrollContainer.new()
	lobby_scroll.custom_minimum_size = Vector2(0.0, 250.0)
	lobby_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lobby_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	HorrorTheme.style_scroll_container(lobby_scroll)
	body.add_child(lobby_scroll)

	var lobby_margin := MarginContainer.new()
	lobby_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	lobby_margin.add_theme_constant_override("margin_right", 8)
	lobby_scroll.add_child(lobby_margin)

	var lobby_inner := VBoxContainer.new()
	lobby_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_inner.mouse_filter = Control.MOUSE_FILTER_PASS
	lobby_inner.add_theme_constant_override("separation", 10)
	lobby_margin.add_child(lobby_inner)

	var roster_hdr := _make_label(LocScript.pick("DAFTAR PEMAIN (MAKS 4)", "PLAYER ROSTER (MAX 4)"), 12, HorrorTheme.PRIMARY, HORIZONTAL_ALIGNMENT_LEFT, "label-lg")
	roster_hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lobby_inner.add_child(roster_hdr)

	lobby_players_box = VBoxContainer.new()
	lobby_players_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_players_box.mouse_filter = Control.MOUSE_FILTER_PASS
	lobby_players_box.add_theme_constant_override("separation", 6)
	lobby_inner.add_child(lobby_players_box)

	lobby_inner.add_child(HorrorTheme.make_hairline_divider())

	var chat_hdr := _make_label(LocScript.pick("OBROLAN LOBI", "LOBBY CHAT"), 12, HorrorTheme.PRIMARY, HORIZONTAL_ALIGNMENT_LEFT, "label-lg")
	chat_hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lobby_inner.add_child(chat_hdr)

	var chat_frame := PanelContainer.new()
	chat_frame.add_theme_stylebox_override("panel", HorrorTheme.make_chip_style(HorrorTheme.SURFACE_LOWEST, HorrorTheme.BORDER_SUBTLE, 2, 10, 8))
	lobby_inner.add_child(chat_frame)

	lobby_chat_scroll = ScrollContainer.new()
	lobby_chat_scroll.custom_minimum_size = Vector2(0.0, 96.0)
	lobby_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	HorrorTheme.style_scroll_container(lobby_chat_scroll)
	chat_frame.add_child(lobby_chat_scroll)

	lobby_chat_view = RichTextLabel.new()
	lobby_chat_view.bbcode_enabled = true
	lobby_chat_view.fit_content = true
	lobby_chat_view.scroll_active = false
	lobby_chat_view.selection_enabled = false
	lobby_chat_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lobby_chat_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_chat_view.add_theme_font_override("normal_font", HorrorTheme.get_body_font())
	lobby_chat_view.add_theme_font_override("bold_font", HorrorTheme.get_serif_font(1, true))
	lobby_chat_view.add_theme_color_override("default_color", HorrorTheme.ON_SURFACE)
	lobby_chat_view.add_theme_font_size_override("normal_font_size", 12)
	lobby_chat_view.add_theme_font_size_override("bold_font_size", 12)
	lobby_chat_scroll.add_child(lobby_chat_view)

	var chat_input_row := HBoxContainer.new()
	chat_input_row.add_theme_constant_override("separation", 8)
	lobby_inner.add_child(chat_input_row)

	lobby_chat_input = LineEdit.new()
	lobby_chat_input.placeholder_text = LocScript.pick("Tulis pesan lobi...", "Write a lobby message...")
	lobby_chat_input.max_length = 200
	lobby_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_chat_input.custom_minimum_size.y = 38.0
	HorrorTheme.style_line_edit(lobby_chat_input)
	lobby_chat_input.text_submitted.connect(func(_t: String) -> void: _on_lobby_chat_send_pressed())
	chat_input_row.add_child(lobby_chat_input)

	lobby_chat_send_btn = _make_button(LocScript.pick("KIRIM", "SEND"), false, "secondary")
	lobby_chat_send_btn.custom_minimum_size = Vector2(88.0, 38.0)
	lobby_chat_send_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	lobby_chat_send_btn.pressed.connect(_on_lobby_chat_send_pressed)
	chat_input_row.add_child(lobby_chat_send_btn)

	lobby_status_label = _make_label("", 12, HorrorTheme.ON_SURFACE_VARIANT, HORIZONTAL_ALIGNMENT_LEFT, "label-sm")
	lobby_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_status_label.visible = false
	body.add_child(lobby_status_label)

	lobby_actions_row = BoxContainer.new()
	lobby_actions_row.add_theme_constant_override("separation", 8)
	body.add_child(lobby_actions_row)

	lobby_leave_btn = _make_button(LocScript.pick("KELUAR ROOM", "LEAVE ROOM"), false, "danger")
	lobby_leave_btn.pressed.connect(_on_lobby_leave_pressed)
	lobby_actions_row.add_child(lobby_leave_btn)

	lobby_ready_btn = _make_button(LocScript.pick("SIAP", "READY"), false, "secondary")
	lobby_ready_btn.pressed.connect(_on_lobby_ready_pressed)
	lobby_actions_row.add_child(lobby_ready_btn)

	lobby_start_btn = _make_button(LocScript.pick("MULAI PERMAINAN", "START GAME"), true)
	lobby_start_btn.pressed.connect(_on_lobby_start_pressed)
	lobby_actions_row.add_child(lobby_start_btn)

func _open_room_lobby_modal() -> void:
	_launching_online_game = false
	_lobby_busy = false
	_last_chat_count = -1
	_last_lobby_roster_sig = ""
	if lobby_status_label:
		lobby_status_label.text = ""
		lobby_status_label.visible = false
	_refresh_lobby_ui(MultiplayerManager.current_room, MultiplayerManager.room_players)
	_open_modal(room_lobby_overlay, room_lobby_panel)

func _on_multiplayer_room_updated(room: Dictionary, players: Array) -> void:
	if room_lobby_overlay and room_lobby_overlay.visible:
		_refresh_lobby_ui(room, players)

func _refresh_lobby_ui(room: Dictionary, players: Array) -> void:
	if not is_instance_valid(room_lobby_overlay):
		return
	var r_name: String = str(room.get("name", "Room"))
	var r_code: String = str(room.get("roomCode", room.get("code", "------")))
	var r_mode: String = str(room.get("mode", mp_mode_filter))
	var r_diff: String = str(room.get("difficulty", "normal")).to_upper()
	var r_max: int = int(room.get("maxPlayers", 4))
	var can_shop: bool = bool(room.get("canUseShopItems", true))
	var host_uid: String = str(room.get("hostUserId", ""))
	var settings_dict: Dictionary = room.get("settings", {}) if room.get("settings") is Dictionary else {}
	var lampor_on: bool = bool(settings_dict.get("lamporEnabled", true))
	var time_scale: float = float(settings_dict.get("timeScale", 1.0))
	var late_join: bool = bool(room.get("allowLateJoin", settings_dict.get("allowLateJoin", false)))
	var friendly_revive: bool = bool(settings_dict.get("friendlyRevive", true))

	if lobby_room_name_label:
		lobby_room_name_label.text = r_name
	if lobby_room_code_label:
		lobby_room_code_label.text = LocScript.pick("KODE: %s" % r_code, "CODE: %s" % r_code)
	if lobby_mode_badge_label:
		if r_mode == "sandbox":
			lobby_mode_badge_label.text = LocScript.pick("SANDBOX MODE  ·  Owner: [Ctrl+F5] / Tombol Mobile", "SANDBOX MODE  ·  Owner: [Ctrl+F5] / Mobile Button")
			lobby_mode_badge_label.add_theme_color_override("font_color", HorrorTheme.RELIC_BRASS)
		else:
			lobby_mode_badge_label.text = "MULTIPLAYER CO-OP"
			lobby_mode_badge_label.add_theme_color_override("font_color", HorrorTheme.PRIMARY)
	if lobby_settings_summary_label:
		lobby_settings_summary_label.text = LocScript.pick(
			"Kesulitan: %s · Pemain: %d/%d · Shop Item: %s · Lampor AI: %s · Jam: %.1fx · Gabung Telat: %s · Bangkit Rekan: %s" % [
				r_diff, players.size(), r_max,
				"ON" if can_shop else "OFF",
				"ON" if lampor_on else "OFF",
				time_scale,
				"ON" if late_join else "OFF",
				"ON" if friendly_revive else "OFF"
			],
			"Difficulty: %s · Players: %d/%d · Shop Item: %s · Lampor AI: %s · Clock: %.1fx · Late Join: %s · Auto-Revive: %s" % [
				r_diff, players.size(), r_max,
				"ON" if can_shop else "OFF",
				"ON" if lampor_on else "OFF",
				time_scale,
				"ON" if late_join else "OFF",
				"ON" if friendly_revive else "OFF"
			]
		)

	var my_ready: bool = false
	var sig_parts := PackedStringArray([str(r_max), "1" if MultiplayerManager.is_room_owner else "0"])
	for p_var: Variant in players:
		if not p_var is Dictionary:
			continue
		var p_s: Dictionary = p_var as Dictionary
		var uid_s: String = str(p_s.get("userId", p_s.get("id", "")))
		var uname_s: String = str(p_s.get("username", "Player"))
		var host_s: bool = bool(p_s.get("isHost", uid_s == host_uid))
		var ready_s: bool = bool(p_s.get("isReady", false))
		if uid_s == AccountManager.user_id:
			my_ready = ready_s
		sig_parts.append("%s|%s|%s|%s" % [uid_s, uname_s, "1" if host_s else "0", "1" if ready_s else "0"])
	var roster_sig: String = ";".join(sig_parts)

	if is_instance_valid(lobby_players_box) and roster_sig != _last_lobby_roster_sig:
		_last_lobby_roster_sig = roster_sig
		for child: Node in lobby_players_box.get_children():
			child.queue_free()
		for p_var: Variant in players:
			if not p_var is Dictionary:
				continue
			var p: Dictionary = p_var as Dictionary
			var uid: String = str(p.get("userId", p.get("id", "")))
			var uname: String = str(p.get("username", "Player"))
			var is_host: bool = bool(p.get("isHost", uid == host_uid))
			var is_ready: bool = bool(p.get("isReady", false))

			var slot_card := PanelContainer.new()
			slot_card.mouse_filter = Control.MOUSE_FILTER_PASS
			slot_card.add_theme_stylebox_override("panel", HorrorTheme.make_chip_style(HorrorTheme.SURFACE_LOW, HorrorTheme.BORDER_SUBTLE, 2, 10, 7))
			lobby_players_box.add_child(slot_card)

			var p_row := HBoxContainer.new()
			p_row.add_theme_constant_override("separation", 8)
			p_row.mouse_filter = Control.MOUSE_FILTER_PASS
			slot_card.add_child(p_row)

			var you_tag: String = LocScript.pick(" (Anda)", " (You)") if uid == AccountManager.user_id else ""
			var host_tag: String = "  [HOST]" if is_host else ""
			var p_name_lbl := _make_label("%s%s%s" % [uname, you_tag, host_tag], 13, HorrorTheme.RELIC_BRASS if is_host else HorrorTheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT, "body-md")
			p_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			p_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p_row.add_child(p_name_lbl)

			var ready_lbl := _make_label(
				LocScript.pick("[SIAP]", "[READY]") if is_ready else LocScript.pick("[MENUNGGU]", "[WAITING]"),
				11,
				HorrorTheme.SUCCESS_SAGE if is_ready else HorrorTheme.TEXT_MUTED,
				HORIZONTAL_ALIGNMENT_RIGHT,
				"mono-sm"
			)
			ready_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p_row.add_child(ready_lbl)

			if MultiplayerManager.is_room_owner and uid != AccountManager.user_id and not is_host:
				var kick_btn := _make_button("KICK", false, "danger")
				kick_btn.custom_minimum_size = Vector2(70.0, 30.0)
				kick_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
				kick_btn.pressed.connect(_on_lobby_kick_pressed.bind(uid))
				p_row.add_child(kick_btn)

		for _empty_i: int in range(maxi(0, r_max - players.size())):
			var empty_slot := PanelContainer.new()
			empty_slot.add_theme_stylebox_override("panel", HorrorTheme.make_chip_style(HorrorTheme.SURFACE_LOWEST, Color(HorrorTheme.OUTLINE_VARIANT.r, HorrorTheme.OUTLINE_VARIANT.g, HorrorTheme.OUTLINE_VARIANT.b, 0.35), 2, 10, 6))
			lobby_players_box.add_child(empty_slot)
			var empty_lbl := _make_label(LocScript.pick("Slot kosong — menunggu pemain bergabung...", "Empty slot — waiting for player..."), 11, HorrorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT, "label-sm")
			empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			empty_slot.add_child(empty_lbl)

	if lobby_ready_btn:
		lobby_ready_btn.text = LocScript.pick("BATAL SIAP", "CANCEL READY") if my_ready else LocScript.pick("SIAP", "READY")
		HorrorTheme.style_button(lobby_ready_btn, "secondary" if my_ready else "primary", 13, true)
	if lobby_start_btn:
		lobby_start_btn.visible = MultiplayerManager.is_room_owner
	_refresh_lobby_chat()

func _refresh_lobby_chat() -> void:
	if not is_instance_valid(lobby_chat_view):
		return
	var hist: Array[Dictionary] = MultiplayerManager.lobby_chat_history
	if hist.is_empty():
		lobby_chat_view.text = "[color=#a98e8b]%s[/color]" % LocScript.pick("Belum ada pesan. Sapa rekanmu di sini.", "No messages yet. Say hello to your teammates.")
		_last_chat_count = 0
		return
	var lines := PackedStringArray()
	for entry: Dictionary in hist:
		var sender: String = str(entry.get("sender", entry.get("sender_name", entry.get("username", "Pemain")))).replace("[", "[lb]").replace("]", "[rb]")
		var msg_text: String = str(entry.get("text", entry.get("message", ""))).replace("[", "[lb]").replace("]", "[rb]")
		lines.append("[color=#c99a5b][b]%s[/b][/color]: %s" % [sender, msg_text])
	lobby_chat_view.text = "\n".join(lines)
	if hist.size() != _last_chat_count:
		_last_chat_count = hist.size()
		if lobby_chat_scroll:
			call_deferred("_scroll_to_bottom", lobby_chat_scroll)

func _on_multiplayer_event_received(event_type: String, _payload: Dictionary, _sender_name: String) -> void:
	if event_type == "chat" and room_lobby_overlay and room_lobby_overlay.visible:
		_refresh_lobby_chat()

func _on_lobby_copy_code_pressed() -> void:
	var r_code: String = str(MultiplayerManager.current_room.get("roomCode", MultiplayerManager.current_room.get("code", "")))
	if r_code.is_empty():
		return
	DisplayServer.clipboard_set(r_code)
	if lobby_status_label:
		lobby_status_label.text = LocScript.pick("Kode room %s disalin ke clipboard!" % r_code, "Room code %s copied to clipboard!" % r_code)
		lobby_status_label.add_theme_color_override("font_color", HorrorTheme.SUCCESS_SAGE)
		lobby_status_label.visible = true

func _on_lobby_kick_pressed(target_uid: String) -> void:
	if _lobby_busy or not MultiplayerManager.is_room_owner:
		return
	_lobby_busy = true
	var res: Dictionary = await MultiplayerManager.kick_player(target_uid)
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_lobby_busy = false
	if not bool(res.get("ok", false)) and lobby_status_label:
		lobby_status_label.text = _extract_error(res, "Gagal mengeluarkan pemain.", "Failed to kick player.")
		lobby_status_label.add_theme_color_override("font_color", HorrorTheme.ERROR)
		lobby_status_label.visible = true

func _on_lobby_chat_send_pressed() -> void:
	if not lobby_chat_input:
		return
	var msg: String = lobby_chat_input.text.strip_edges()
	if msg.is_empty():
		return
	lobby_chat_input.clear()
	MultiplayerManager.send_chat_message(msg)
	_refresh_lobby_chat()

func _on_lobby_ready_pressed() -> void:
	if _lobby_busy:
		return
	var current_ready: bool = false
	for p_var: Variant in MultiplayerManager.room_players:
		if p_var is Dictionary and str((p_var as Dictionary).get("userId", "")) == AccountManager.user_id:
			current_ready = bool((p_var as Dictionary).get("isReady", false))
			break
	_lobby_busy = true
	if lobby_ready_btn:
		lobby_ready_btn.disabled = true
	var res: Dictionary = await MultiplayerManager.set_ready(not current_ready)
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_lobby_busy = false
	if lobby_ready_btn:
		lobby_ready_btn.disabled = false
	if not bool(res.get("ok", false)) and lobby_status_label:
		lobby_status_label.text = _extract_error(res, "Gagal mengubah status siap.", "Failed to update ready state.")
		lobby_status_label.add_theme_color_override("font_color", HorrorTheme.ERROR)
		lobby_status_label.visible = true

func _on_lobby_start_pressed() -> void:
	if _lobby_busy or _launching_online_game or not MultiplayerManager.is_room_owner:
		return
	_lobby_busy = true
	if lobby_start_btn:
		lobby_start_btn.disabled = true
	if lobby_status_label:
		lobby_status_label.text = LocScript.pick("Memulai permainan online...", "Starting online game...")
		lobby_status_label.add_theme_color_override("font_color", HorrorTheme.ON_SURFACE_VARIANT)
		lobby_status_label.visible = true
	var res: Dictionary = await MultiplayerManager.start_room_game()
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_lobby_busy = false
	if lobby_start_btn:
		lobby_start_btn.disabled = false
	if bool(res.get("ok", false)):
		var data: Dictionary = _unwrap_payload(res)
		var started_room: Dictionary = data.get("room", MultiplayerManager.current_room) if data.get("room") is Dictionary else MultiplayerManager.current_room
		if str(started_room.get("status", "")) == "playing" and not _launching_online_game:
			_on_multiplayer_game_started(started_room)
	elif lobby_status_label:
		lobby_status_label.text = _extract_error(res, "Gagal memulai permainan.", "Failed to start game.")
		lobby_status_label.add_theme_color_override("font_color", HorrorTheme.ERROR)
		lobby_status_label.visible = true

func _on_lobby_leave_pressed() -> void:
	if _lobby_busy:
		return
	_lobby_busy = true
	if lobby_leave_btn:
		lobby_leave_btn.disabled = true
	await MultiplayerManager.leave_room()
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_lobby_busy = false
	if lobby_leave_btn:
		lobby_leave_btn.disabled = false
	if room_lobby_overlay:
		room_lobby_overlay.visible = false
	_open_mp_server_modal(mp_mode_filter)

func _on_multiplayer_game_started(room: Dictionary) -> void:
	if _launching_online_game:
		return
	_launching_online_game = true
	for overlay: ColorRect in modal_overlays:
		if is_instance_valid(overlay):
			overlay.visible = false
	GameManager.start_online_room_game(room)

func _on_multiplayer_disconnected(reason: String) -> void:
	_lobby_busy = false
	_launching_online_game = false
	if room_lobby_overlay and room_lobby_overlay.visible:
		room_lobby_overlay.visible = false
		if AccountManager.can_access_online_modes():
			_open_mp_server_modal(mp_mode_filter)
			if not reason.strip_edges().is_empty():
				_set_mp_server_feedback(reason, HorrorTheme.ERROR)
		else:
			_open_account_modal(0)
			if not reason.strip_edges().is_empty():
				_set_account_status(reason, HorrorTheme.ERROR)

func _unwrap_payload(res: Dictionary) -> Dictionary:
	var inner: Variant = res.get("data", null)
	if inner is Dictionary and not (inner as Dictionary).is_empty():
		return inner as Dictionary
	return res

func _extract_error(res: Dictionary, fallback_id: String, fallback_en: String) -> String:
	var msg: String = str(res.get("message", "")).strip_edges()
	if msg.is_empty():
		var payload: Dictionary = _unwrap_payload(res)
		msg = str(payload.get("error", payload.get("message", ""))).strip_edges()
	if msg.is_empty():
		return LocScript.pick(fallback_id, fallback_en)
	return msg
