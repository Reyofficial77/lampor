class_name AdminPanel
extends CanvasLayer

# ==============================================================================
# KONFIGURASI PASSWORD ADMIN PANEL (Isi password rahasia Anda di bawah ini)
# ==============================================================================
const ADMIN_PASSWORD: String = "Astradev is the best!"

var root_control: Control
var panel: PanelContainer
var drag_header: PanelContainer
var auth_vbox: VBoxContainer
var password_input: LineEdit
var auth_error_label: Label
var body_scroll: ScrollContainer
var body_vbox: VBoxContainer
var ingame_section_box: VBoxContainer
var menu_only_notice: Label
var status_label: Label
var god_mode_btn: Button
var min_btn: Button
var coins_input: LineEdit
var wins_input: LineEdit
var is_authenticated: bool = false
var is_dragging: bool = false
var is_minimized: bool = false
var last_in_gameplay: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var _shortcut_latched: bool = false
var _last_toggle_msec: int = -1000

func _is_current_user_admin() -> bool:
	return GameManager.is_logged_in_admin()

func _ensure_input_action() -> void:
	if not InputMap.has_action("toggle_admin_panel"):
		InputMap.add_action("toggle_admin_panel")
		var alt_ev := InputEventKey.new()
		alt_ev.keycode = KEY_F2
		alt_ev.physical_keycode = KEY_F2
		alt_ev.alt_pressed = true
		InputMap.action_add_event("toggle_admin_panel", alt_ev)
		var ctrl_ev := InputEventKey.new()
		ctrl_ev.keycode = KEY_F2
		ctrl_ev.physical_keycode = KEY_F2
		ctrl_ev.ctrl_pressed = true
		InputMap.action_add_event("toggle_admin_panel", ctrl_ev)

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_input_action()
	_build_ui()
	root_control.visible = false
	SignalBus.account_state_changed.connect(_on_account_state_changed)
	if get_viewport():
		get_viewport().size_changed.connect(_fit_and_clamp_panel)

func _on_account_state_changed() -> void:
	if not _is_current_user_admin():
		is_authenticated = false
		close_panel()

func close_panel() -> void:
	is_dragging = false
	if root_control and root_control.visible:
		root_control.visible = false
		if password_input and password_input.has_focus():
			password_input.release_focus()
		if coins_input and coins_input.has_focus():
			coins_input.release_focus()
		if wins_input and wins_input.has_focus():
			wins_input.release_focus()
		_restore_mouse_mode_if_playing()

func _is_toggle_shortcut_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if not ke.pressed or ke.echo:
			return false
		if event.is_action_pressed("toggle_admin_panel", false, true):
			return true
		var is_f2: bool = (ke.keycode == KEY_F2 or ke.physical_keycode == KEY_F2 or ke.key_label == KEY_F2)
		if is_f2:
			var has_mod: bool = (
				ke.alt_pressed or ke.ctrl_pressed
				or Input.is_key_pressed(KEY_ALT) or Input.is_physical_key_pressed(KEY_ALT)
				or Input.is_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_CTRL)
			)
			if has_mod:
				return true
	elif event.is_action_pressed("toggle_admin_panel", false, true):
		return true
	return false

func _request_shortcut_toggle() -> void:
	if not _is_current_user_admin():
		if root_control and root_control.visible:
			is_authenticated = false
			close_panel()
		return
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_toggle_msec < 250:
		return
	_last_toggle_msec = now_msec
	_shortcut_latched = true
	toggle_panel()

func _process(_delta: float) -> void:
	var f2_down: bool = Input.is_key_pressed(KEY_F2) or Input.is_physical_key_pressed(KEY_F2)
	var mod_down: bool = (
		Input.is_key_pressed(KEY_ALT) or Input.is_physical_key_pressed(KEY_ALT)
		or Input.is_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_CTRL)
	)
	if f2_down and mod_down:
		if not _shortcut_latched:
			_shortcut_latched = true
			_request_shortcut_toggle()
	else:
		_shortcut_latched = false

	if not root_control or not root_control.visible:
		return
	if not _is_current_user_admin():
		is_authenticated = false
		close_panel()
		return
	var in_game: bool = GameManager.is_in_active_gameplay()
	if in_game != last_in_gameplay:
		last_in_gameplay = in_game
		_refresh_panel_state()
		_fit_and_clamp_panel()

func _unhandled_key_input(event: InputEvent) -> void:
	if _is_toggle_shortcut_event(event):
		_request_shortcut_toggle()
		if _is_current_user_admin() and get_viewport():
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if _is_toggle_shortcut_event(event):
		_request_shortcut_toggle()
		if _is_current_user_admin() and get_viewport():
			get_viewport().set_input_as_handled()
		return
	if not _is_current_user_admin():
		if root_control and root_control.visible:
			is_authenticated = false
			close_panel()
		return

	if not root_control or not root_control.visible:
		return

	if is_dragging:
		if event is InputEventMouseMotion:
			var mm := event as InputEventMouseMotion
			_move_panel_to(mm.position - drag_offset)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
				is_dragging = false
				get_viewport().set_input_as_handled()
		elif event is InputEventScreenDrag:
			var sd := event as InputEventScreenDrag
			_move_panel_to(sd.position - drag_offset)
			get_viewport().set_input_as_handled()
		elif event is InputEventScreenTouch:
			var st := event as InputEventScreenTouch
			if not st.pressed:
				is_dragging = false

func toggle_panel() -> void:
	if not root_control:
		return
	if not _is_current_user_admin():
		is_authenticated = false
		close_panel()
		return
	var next_open: bool = not root_control.visible
	if next_open:
		is_authenticated = true
		root_control.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		last_in_gameplay = GameManager.is_in_active_gameplay()
		_sync_auth_view()
		_refresh_panel_state()
		_fit_and_clamp_panel()
		HorrorTheme.animate_surface_enter(panel)
	else:
		close_panel()

func _sync_auth_view() -> void:
	if auth_vbox:
		auth_vbox.visible = not is_authenticated
	if min_btn:
		min_btn.visible = is_authenticated
	if body_scroll:
		body_scroll.visible = is_authenticated and not is_minimized
	if body_vbox:
		body_vbox.visible = is_authenticated and not is_minimized

func _on_password_submitted(_submitted_text: String = "") -> void:
	if not password_input:
		return
	var entered: String = password_input.text
	if entered == ADMIN_PASSWORD and not ADMIN_PASSWORD.is_empty():
		is_authenticated = true
		is_minimized = false
		if min_btn:
			min_btn.text = "–"
		password_input.clear()
		password_input.release_focus()
		if auth_error_label:
			auth_error_label.text = ""
			auth_error_label.visible = false
		_sync_auth_view()
		_refresh_panel_state()
		_fit_and_clamp_panel()
		_set_status("Akses dibuka untuk sesi permainan ini.")
	else:
		if auth_error_label:
			auth_error_label.text = "Password salah! Akses ditolak."
			auth_error_label.visible = true
		password_input.select_all()
		password_input.call_deferred("grab_focus")
		_fit_and_clamp_panel()

func _toggle_minimize() -> void:
	if not is_authenticated:
		return
	is_minimized = not is_minimized
	if body_scroll:
		body_scroll.visible = not is_minimized
	if body_vbox:
		body_vbox.visible = not is_minimized
	if min_btn:
		min_btn.text = "+" if is_minimized else "–"
	_fit_and_clamp_panel()

func _fit_and_clamp_panel() -> void:
	if not panel:
		return
	var view_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280.0, 720.0)
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		view_size = Vector2(1280.0, 720.0)
	var panel_w: float = minf(312.0, maxf(260.0, view_size.x - 16.0))
	var max_panel_h: float = maxf(180.0, view_size.y - 16.0)
	if body_scroll and body_scroll.visible and body_vbox:
		var header_h: float = drag_header.get_combined_minimum_size().y if drag_header else 34.0
		var max_scroll_h: float = maxf(100.0, max_panel_h - header_h - 32.0)
		var content_h: float = body_vbox.get_combined_minimum_size().y
		body_scroll.custom_minimum_size = Vector2(panel_w - 24.0, minf(content_h, max_scroll_h))
	panel.custom_minimum_size = Vector2(panel_w, 0.0)
	panel.reset_size()
	panel.size = Vector2(panel_w, minf(panel.get_combined_minimum_size().y, max_panel_h))
	_move_panel_to(panel.position)
	call_deferred("_deferred_fit_panel")

func _deferred_fit_panel() -> void:
	if not is_instance_valid(panel):
		return
	var view_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280.0, 720.0)
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		view_size = Vector2(1280.0, 720.0)
	var panel_w: float = minf(312.0, maxf(260.0, view_size.x - 16.0))
	var max_panel_h: float = maxf(180.0, view_size.y - 16.0)
	if body_scroll and body_scroll.visible and body_vbox:
		var header_h: float = drag_header.get_combined_minimum_size().y if drag_header else 34.0
		var max_scroll_h: float = maxf(100.0, max_panel_h - header_h - 32.0)
		var content_h: float = body_vbox.get_combined_minimum_size().y
		body_scroll.custom_minimum_size = Vector2(panel_w - 24.0, minf(content_h, max_scroll_h))
	panel.reset_size()
	panel.size = Vector2(panel_w, minf(panel.get_combined_minimum_size().y, max_panel_h))
	_move_panel_to(panel.position)

func _restore_mouse_mode_if_playing() -> void:
	var touch: bool = DisplayServer.is_touchscreen_available() or OS.has_feature("android") or OS.has_feature("ios")
	if GameManager.is_in_active_gameplay() and not get_tree().paused and not touch:
		var player := GameManager.player_character as PlayerController
		if player and not player.is_inventory_open:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _move_panel_to(target_pos: Vector2) -> void:
	if not panel:
		return
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	if view_size.x <= 0.0:
		view_size = Vector2(1280.0, 720.0)
	var psize: Vector2 = panel.size
	panel.position = Vector2(
		clampf(target_pos.x, 6.0, maxf(6.0, view_size.x - psize.x - 6.0)),
		clampf(target_pos.y, 6.0, maxf(6.0, view_size.y - psize.y - 6.0))
	)

func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				is_dragging = true
				drag_offset = mb.global_position - panel.global_position
			else:
				is_dragging = false
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			is_dragging = true
			drag_offset = st.position - panel.global_position
		else:
			is_dragging = false

func _build_ui() -> void:
	root_control = Control.new()
	root_control.name = "AdminPanelRoot"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	panel = PanelContainer.new()
	panel.name = "AdminDraggablePanel"
	panel.position = Vector2(960.0, 14.0)
	panel.custom_minimum_size = Vector2(300.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override(
		"panel",
		HorrorTheme.make_minimal_panel_style(
			Color(0.086, 0.045, 0.043, 0.94),
			HorrorTheme.BORDER_INTERACTIVE,
			2,
			10,
			8
		)
	)
	root_control.add_child(panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 5)
	panel.add_child(main_vbox)

	drag_header = PanelContainer.new()
	drag_header.mouse_filter = Control.MOUSE_FILTER_STOP
	drag_header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	drag_header.add_theme_stylebox_override(
		"panel",
		HorrorTheme.make_chip_style(HorrorTheme.SURFACE_LOWEST, HorrorTheme.BORDER_SUBTLE, 2, 8, 4)
	)
	drag_header.gui_input.connect(_on_header_gui_input)
	main_vbox.add_child(drag_header)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 5)
	header_row.mouse_filter = Control.MOUSE_FILTER_PASS
	drag_header.add_child(header_row)

	var title := Label.new()
	title.text = "ADMIN [ALT+F2]"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HorrorTheme.style_label(title, "label-lg", HorrorTheme.PRIMARY, 10)
	header_row.add_child(title)

	min_btn = _make_admin_btn("–", "ghost", 24.0)
	min_btn.pressed.connect(_toggle_minimize)
	header_row.add_child(min_btn)

	var close_btn := _make_admin_btn("X", "danger", 26.0)
	close_btn.pressed.connect(toggle_panel)
	header_row.add_child(close_btn)

	# Panel Verifikasi Password (Tampil jika belum autentikasi di sesi ini)
	auth_vbox = VBoxContainer.new()
	auth_vbox.add_theme_constant_override("separation", 5)
	main_vbox.add_child(auth_vbox)

	auth_vbox.add_child(_make_section_label("VERIFIKASI AKSES"))

	var auth_desc := Label.new()
	auth_desc.text = "Masukkan password untuk membuka panel:"
	auth_desc.custom_minimum_size.x = 276.0
	auth_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	HorrorTheme.style_label(auth_desc, "label-sm", HorrorTheme.ON_SURFACE_VARIANT, 10)
	auth_vbox.add_child(auth_desc)

	password_input = LineEdit.new()
	password_input.secret = true
	password_input.placeholder_text = "Masukkan password..."
	password_input.custom_minimum_size = Vector2(276.0, 26.0)
	HorrorTheme.style_line_edit(password_input)
	password_input.add_theme_font_size_override("font_size", 10)
	password_input.text_submitted.connect(_on_password_submitted)
	auth_vbox.add_child(password_input)

	auth_error_label = Label.new()
	auth_error_label.text = ""
	auth_error_label.visible = false
	auth_error_label.custom_minimum_size.x = 276.0
	auth_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	HorrorTheme.style_label(auth_error_label, "label-sm", HorrorTheme.ERROR, 9)
	auth_vbox.add_child(auth_error_label)

	var auth_btn_row := HBoxContainer.new()
	auth_btn_row.add_theme_constant_override("separation", 4)
	auth_vbox.add_child(auth_btn_row)

	var unlock_btn := _make_admin_btn("BUKA PANEL", "primary")
	unlock_btn.pressed.connect(func() -> void: _on_password_submitted(password_input.text))
	auth_btn_row.add_child(unlock_btn)

	var cancel_btn := _make_admin_btn("BATAL", "secondary")
	cancel_btn.pressed.connect(toggle_panel)
	auth_btn_row.add_child(cancel_btn)

	body_scroll = ScrollContainer.new()
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	HorrorTheme.style_scroll_container(body_scroll)
	main_vbox.add_child(body_scroll)

	body_vbox = VBoxContainer.new()
	body_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_vbox.add_theme_constant_override("separation", 4)
	body_scroll.add_child(body_vbox)

	# Bagian Khusus In-Game (Hanya tampil saat permainan dimulai di VillageMap)
	ingame_section_box = VBoxContainer.new()
	ingame_section_box.add_theme_constant_override("separation", 4)
	body_vbox.add_child(ingame_section_box)

	ingame_section_box.add_child(_make_section_label("HASIL & STATUS (IN-GAME)"))
	var row_outcome := HBoxContainer.new()
	row_outcome.add_theme_constant_override("separation", 4)
	ingame_section_box.add_child(row_outcome)

	var win_btn := _make_admin_btn("MENANG", "primary")
	win_btn.pressed.connect(func() -> void:
		if not GameManager.is_in_active_gameplay():
			_set_status("Hanya dapat digunakan saat di dalam permainan!")
			return
		root_control.visible = false
		GameManager.admin_instant_win()
	)
	row_outcome.add_child(win_btn)

	var lose_btn := _make_admin_btn("KALAH", "danger")
	lose_btn.pressed.connect(func() -> void:
		if not GameManager.is_in_active_gameplay():
			_set_status("Hanya dapat digunakan saat di dalam permainan!")
			return
		root_control.visible = false
		GameManager.admin_instant_lose()
	)
	row_outcome.add_child(lose_btn)

	var row_stats := HBoxContainer.new()
	row_stats.add_theme_constant_override("separation", 4)
	ingame_section_box.add_child(row_stats)

	god_mode_btn = _make_admin_btn("GOD MODE: OFF", "secondary")
	god_mode_btn.pressed.connect(func() -> void:
		if not GameManager.is_in_active_gameplay():
			_set_status("Mulai permainan terlebih dahulu!")
			return
		GameManager.admin_god_mode = not GameManager.admin_god_mode
		if GameManager.admin_god_mode:
			GameManager.admin_refill_player_stats()
		_refresh_panel_state()
		_set_status("God Mode: " + ("AKTIF" if GameManager.admin_god_mode else "OFF"))
	)
	row_stats.add_child(god_mode_btn)

	var refill_btn := _make_admin_btn("ISI STAT 100%", "secondary")
	refill_btn.pressed.connect(func() -> void:
		if not GameManager.is_in_active_gameplay():
			return
		GameManager.admin_refill_player_stats()
		_set_status("Waras, Stamina & Senter 100%.")
	)
	row_stats.add_child(refill_btn)

	ingame_section_box.add_child(_make_section_label("BABAK & WAKTU (IN-GAME)"))
	var row_acts := HBoxContainer.new()
	row_acts.add_theme_constant_override("separation", 4)
	ingame_section_box.add_child(row_acts)

	for act_i: int in [1, 2, 3]:
		var a_btn := _make_admin_btn("BABAK %d" % act_i, "secondary")
		a_btn.pressed.connect(func() -> void:
			if GameManager.admin_jump_to_act(act_i):
				_set_status("Lompat ke Babak %d." % act_i)
		)
		row_acts.add_child(a_btn)

	var row_time := HBoxContainer.new()
	row_time.add_theme_constant_override("separation", 4)
	ingame_section_box.add_child(row_time)

	var t458_btn := _make_admin_btn("04:58 WIB", "secondary")
	t458_btn.pressed.connect(func() -> void:
		if GameManager.admin_set_time(4, 58):
			_set_status("Waktu diatur ke 04:58 WIB.")
	)
	row_time.add_child(t458_btn)

	var t500_btn := _make_admin_btn("05:00 (LAHAP)", "danger")
	t500_btn.pressed.connect(func() -> void:
		if not GameManager.is_in_active_gameplay():
			return
		root_control.visible = false
		GameManager.admin_set_time(5, 0)
	)
	row_time.add_child(t500_btn)

	ingame_section_box.add_child(_make_section_label("MISI & BARANG (IN-GAME)"))
	var row_m1 := HBoxContainer.new()
	row_m1.add_theme_constant_override("separation", 4)
	ingame_section_box.add_child(row_m1)

	var obor_btn := _make_admin_btn("OBOR & PINTU", "secondary")
	obor_btn.pressed.connect(func() -> void:
		if not GameManager.is_in_active_gameplay():
			return
		GameManager.admin_complete_babak_1_objectives()
		_set_status("5 Obor & 3 Barikade selesai.")
	)
	row_m1.add_child(obor_btn)

	var ritual_btn := _make_admin_btn("4 RITUAL", "secondary")
	ritual_btn.pressed.connect(func() -> void:
		if not GameManager.is_in_active_gameplay():
			return
		GameManager.admin_collect_all_ritual_items()
		_set_status("4 Benda Ritual terkumpul.")
	)
	row_m1.add_child(ritual_btn)

	var row_m2 := HBoxContainer.new()
	row_m2.add_theme_constant_override("separation", 4)
	ingame_section_box.add_child(row_m2)

	var items_btn := _make_admin_btn("+SEMUA ITEM", "secondary")
	items_btn.pressed.connect(func() -> void:
		if not GameManager.is_in_active_gameplay():
			return
		GameManager.admin_give_all_items()
		_set_status("Semua barang ditambahkan ke tas.")
	)
	row_m2.add_child(items_btn)

	var tp_btn := _make_admin_btn("KE TUNGKU", "secondary")
	tp_btn.pressed.connect(func() -> void:
		if not GameManager.is_in_active_gameplay():
			return
		GameManager.admin_teleport_to_altar()
		_set_status("Teleport ke Tungku Balai Desa.")
	)
	row_m2.add_child(tp_btn)

	menu_only_notice = Label.new()
	menu_only_notice.text = "Di Main Menu hanya untuk Koin, Nyawa & Mode.\nMulai permainan untuk uji Menang/Kalah/Babak."
	menu_only_notice.custom_minimum_size.x = 276.0
	menu_only_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	HorrorTheme.style_label(menu_only_notice, "label-sm", HorrorTheme.ON_SURFACE_VARIANT, 10)
	body_vbox.add_child(menu_only_notice)

	# Bagian Koin, Nyawa & Mode (Tersedia di Main Menu maupun In-Game)
	body_vbox.add_child(_make_section_label("KOIN, NYAWA & MODE"))
	var row_coins := HBoxContainer.new()
	row_coins.add_theme_constant_override("separation", 4)
	body_vbox.add_child(row_coins)

	var coin_lbl := Label.new()
	coin_lbl.text = "Koin:"
	HorrorTheme.style_label(coin_lbl, "label-sm", HorrorTheme.ON_SURFACE, 10)
	row_coins.add_child(coin_lbl)

	coins_input = LineEdit.new()
	coins_input.max_length = 9
	coins_input.placeholder_text = "Maks 999999999"
	coins_input.text = str(GameManager.coins)
	coins_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coins_input.custom_minimum_size.y = 24.0
	HorrorTheme.style_line_edit(coins_input)
	coins_input.add_theme_font_size_override("font_size", 10)
	row_coins.add_child(coins_input)

	var apply_coins := func() -> void:
		var raw_c: String = coins_input.text.strip_edges()
		if not raw_c.is_valid_int():
			_set_status("Masukkan angka koin yang valid (0-%d)." % GameManager.MAX_COINS)
			return
		var parsed: int = clampi(int(raw_c.to_int()), 0, GameManager.MAX_COINS)
		GameManager.admin_set_coins(parsed)
		_refresh_panel_state()
		_notify_main_menu_refresh()
		_set_status("Koin: %d (Maks %d)" % [GameManager.coins, GameManager.MAX_COINS])
	coins_input.text_submitted.connect(func(_t: String) -> void: apply_coins.call())

	var set_coin_btn := _make_admin_btn("SET", "primary", 42.0)
	set_coin_btn.pressed.connect(apply_coins)
	row_coins.add_child(set_coin_btn)

	var add500_btn := _make_admin_btn("+500", "secondary", 46.0)
	add500_btn.pressed.connect(func() -> void:
		GameManager.admin_set_coins(GameManager.coins + 500)
		_refresh_panel_state()
		_notify_main_menu_refresh()
		_set_status("Koin: %d" % GameManager.coins)
	)
	row_coins.add_child(add500_btn)

	var row_wins := HBoxContainer.new()
	row_wins.add_theme_constant_override("separation", 4)
	body_vbox.add_child(row_wins)

	var wins_lbl := Label.new()
	wins_lbl.text = "Win:"
	HorrorTheme.style_label(wins_lbl, "label-sm", HorrorTheme.ON_SURFACE, 10)
	row_wins.add_child(wins_lbl)

	wins_input = LineEdit.new()
	wins_input.max_length = 6
	wins_input.placeholder_text = "Maks 999999"
	wins_input.text = str(GameManager.total_wins)
	wins_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wins_input.custom_minimum_size.y = 24.0
	HorrorTheme.style_line_edit(wins_input)
	wins_input.add_theme_font_size_override("font_size", 10)
	row_wins.add_child(wins_input)

	var apply_wins := func() -> void:
		var raw_w: String = wins_input.text.strip_edges()
		if not raw_w.is_valid_int():
			_set_status("Masukkan jumlah win yang valid (0-999999).")
			return
		var parsed_w: int = clampi(int(raw_w.to_int()), 0, 999999)
		GameManager.admin_set_total_wins(parsed_w)
		_refresh_panel_state()
		_notify_main_menu_refresh()
		_set_status("Total Win: %d" % GameManager.total_wins)
	wins_input.text_submitted.connect(func(_t: String) -> void: apply_wins.call())

	var set_win_btn := _make_admin_btn("SET", "primary", 42.0)
	set_win_btn.pressed.connect(apply_wins)
	row_wins.add_child(set_win_btn)

	var add1_win_btn := _make_admin_btn("+1", "secondary", 46.0)
	add1_win_btn.pressed.connect(func() -> void:
		GameManager.admin_set_total_wins(GameManager.total_wins + 1)
		_refresh_panel_state()
		_notify_main_menu_refresh()
		_set_status("Total Win: %d" % GameManager.total_wins)
	)
	row_wins.add_child(add1_win_btn)

	var row_lives := HBoxContainer.new()
	row_lives.add_theme_constant_override("separation", 4)
	body_vbox.add_child(row_lives)

	var lives_lbl := Label.new()
	lives_lbl.text = "Nyawa:"
	HorrorTheme.style_label(lives_lbl, "label-sm", HorrorTheme.ON_SURFACE, 10)
	row_lives.add_child(lives_lbl)

	for lv: int in [0, 1, 3, 5]:
		var l_btn := _make_admin_btn(str(lv), "secondary")
		l_btn.pressed.connect(func() -> void:
			GameManager.admin_set_extra_lives(lv)
			_notify_main_menu_refresh()
			_set_status("Nyawa Cadangan: %d" % GameManager.extra_lives)
		)
		row_lives.add_child(l_btn)

	var row_nm := HBoxContainer.new()
	row_nm.add_theme_constant_override("separation", 4)
	body_vbox.add_child(row_nm)

	var unlock_nm_btn := _make_admin_btn("BUKA NIGHTMARE", "primary")
	unlock_nm_btn.pressed.connect(func() -> void:
		GameManager.admin_set_total_wins(maxi(5, GameManager.total_wins))
		_refresh_panel_state()
		_notify_main_menu_refresh()
		_set_status("Nightmare terbuka (%d Win)." % GameManager.total_wins)
	)
	row_nm.add_child(unlock_nm_btn)

	var reset_nm_btn := _make_admin_btn("KUNCI NIGHTMARE", "secondary")
	reset_nm_btn.pressed.connect(func() -> void:
		GameManager.admin_set_total_wins(0)
		_refresh_panel_state()
		_notify_main_menu_refresh()
		_set_status("Nightmare dikunci (0 Win).")
	)
	row_nm.add_child(reset_nm_btn)

	var row_tut := HBoxContainer.new()
	row_tut.add_theme_constant_override("separation", 4)
	body_vbox.add_child(row_tut)

	var flag_tut_btn := _make_admin_btn("MODE PEMULA: ON", "secondary")
	flag_tut_btn.pressed.connect(func() -> void:
		GameManager.set_tutorial_completed_override(false)
		_notify_main_menu_refresh()
		_set_status("Tutorial Pemula aktif untuk permainan berikutnya.")
	)
	row_tut.add_child(flag_tut_btn)

	var skip_tut_btn := _make_admin_btn("MODE PEMULA: OFF", "ghost")
	skip_tut_btn.pressed.connect(func() -> void:
		GameManager.set_tutorial_completed_override(true)
		_notify_main_menu_refresh()
		_set_status("Tutorial Pemula dilewati (langsung pilih kesulitan).")
	)
	row_tut.add_child(skip_tut_btn)

	status_label = Label.new()
	status_label.text = "Seret header untuk geser · [–] perkecil"
	status_label.custom_minimum_size.x = 276.0
	status_label.clip_text = true
	HorrorTheme.style_label(status_label, "mono-sm", HorrorTheme.RELIC_BRASS, 9)
	body_vbox.add_child(status_label)

func _make_section_label(txt: String) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	HorrorTheme.style_label(lbl, "label-lg", HorrorTheme.PRIMARY, 9)
	return lbl

func _make_admin_btn(txt: String, variant: String = "secondary", min_w: float = 0.0) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(min_w, 24.0)
	if min_w <= 0.0:
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HorrorTheme.style_button(btn, variant, 9, true)
	for st_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb: StyleBoxFlat = btn.get_theme_stylebox(st_name) as StyleBoxFlat
		if sb:
			var cp := sb.duplicate() as StyleBoxFlat
			cp.content_margin_left = 6.0
			cp.content_margin_right = 6.0
			cp.content_margin_top = 3.0
			cp.content_margin_bottom = 3.0
			btn.add_theme_stylebox_override(st_name, cp)
	return btn

func _refresh_panel_state() -> void:
	var in_game: bool = GameManager.is_in_active_gameplay()
	if ingame_section_box:
		ingame_section_box.visible = in_game
	if menu_only_notice:
		menu_only_notice.visible = not in_game
	if god_mode_btn:
		god_mode_btn.text = "GOD MODE: ON" if GameManager.admin_god_mode else "GOD MODE: OFF"
		HorrorTheme.style_button(god_mode_btn, "primary" if GameManager.admin_god_mode else "secondary", 9, true)
	if coins_input:
		coins_input.text = str(GameManager.coins)
	if wins_input:
		wins_input.text = str(GameManager.total_wins)

func _set_status(msg: String) -> void:
	if status_label:
		status_label.text = msg

func _notify_main_menu_refresh() -> void:
	var current_sc: Node = get_tree().current_scene
	if current_sc and current_sc.has_method("_refresh_currency_display"):
		current_sc.call("_refresh_currency_display")
	if current_sc and current_sc.has_method("_refresh_shop_display"):
		current_sc.call("_refresh_shop_display")
	if current_sc and current_sc.has_method("_update_nightmare_status"):
		current_sc.call("_update_nightmare_status")
	if current_sc and current_sc.has_method("_refresh_tutorial_button_visibility"):
		current_sc.call("_refresh_tutorial_button_visibility")
