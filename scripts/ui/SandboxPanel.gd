class_name SandboxPanel
extends CanvasLayer

const LocScript = preload("res://scripts/systems/Loc.gd")

var root_control: Control
var panel: PanelContainer
var drag_header: PanelContainer
var min_btn: Button
var body_wrapper: VBoxContainer
var body_scroll: ScrollContainer
var body_vbox: VBoxContainer
var status_label: Label
var players_vbox: VBoxContainer

# Toggle buttons that reflect live state
var god_mode_btn: Button
var inf_stamina_btn: Button
var inf_battery_btn: Button
var no_sanity_btn: Button
var freeze_lampor_btn: Button
var pause_clock_btn: Button
var fog_btn: Button
var speed_buttons: Dictionary = {}

var is_dragging: bool = false
var is_minimized: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var _roster_refresh_timer: float = 0.0
var _last_roster_signature: String = ""

func _ready() -> void:
	layer = 118
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	root_control.visible = false
	if SignalBus.has_signal("multiplayer_room_updated"):
		SignalBus.multiplayer_room_updated.connect(_on_room_updated)
	get_viewport().size_changed.connect(_fit_and_clamp_panel)

func _on_room_updated(_room: Dictionary, _players: Array) -> void:
	if root_control and root_control.visible:
		_refresh_players_list(true)
		_fit_and_clamp_panel()

func _process(delta: float) -> void:
	if not root_control or not root_control.visible:
		return
	if not GameManager.is_sandbox_owner_active():
		_force_close()
		return
	_roster_refresh_timer += delta
	if _roster_refresh_timer >= 0.5:
		_roster_refresh_timer = 0.0
		_refresh_players_list(false)
		_refresh_toggle_states()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.ctrl_pressed and (ke.keycode == KEY_F5 or ke.physical_keycode == KEY_F5):
			if GameManager.is_sandbox_owner_active():
				toggle_panel()
				get_viewport().set_input_as_handled()
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

func _force_close() -> void:
	var was_visible: bool = root_control != null and root_control.visible
	is_dragging = false
	if root_control:
		root_control.visible = false
	if was_visible:
		if SignalBus.has_signal("sandbox_panel_toggled"):
			SignalBus.sandbox_panel_toggled.emit(false)
		_restore_mouse_mode_if_playing()

func toggle_panel() -> void:
	if not root_control:
		return
	if not GameManager.is_sandbox_owner_active():
		_force_close()
		return
	var next_open: bool = not root_control.visible
	root_control.visible = next_open
	if SignalBus.has_signal("sandbox_panel_toggled"):
		SignalBus.sandbox_panel_toggled.emit(next_open)
	if next_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_panel_state()
		_fit_and_clamp_panel()
		HorrorTheme.animate_surface_enter(panel)
	else:
		is_dragging = false
		_restore_mouse_mode_if_playing()

func _toggle_minimize() -> void:
	is_minimized = not is_minimized
	if body_wrapper:
		body_wrapper.visible = not is_minimized
	if min_btn:
		min_btn.text = "+" if is_minimized else "–"
	_fit_and_clamp_panel()

func _fit_and_clamp_panel() -> void:
	if not panel:
		return
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	if view_size.x <= 0.0:
		view_size = Vector2(1280.0, 720.0)
	var panel_w: float = clampf(view_size.x - 16.0, 268.0, 340.0)
	panel.custom_minimum_size = Vector2(panel_w, 0.0)
	if body_scroll and body_vbox:
		var inner_w: float = maxf(230.0, panel_w - 22.0)
		body_vbox.custom_minimum_size.x = inner_w
		var content_h: float = body_vbox.get_combined_minimum_size().y + 4.0
		var max_scroll_h: float = maxf(130.0, view_size.y - 120.0)
		body_scroll.custom_minimum_size = Vector2(inner_w, minf(content_h, max_scroll_h))
	panel.reset_size()
	panel.size = Vector2(panel_w, panel.get_combined_minimum_size().y)
	_move_panel_to(panel.position)
	call_deferred("_deferred_fit_panel", panel_w)

func _deferred_fit_panel(panel_w: float) -> void:
	if not is_instance_valid(panel):
		return
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	if view_size.y <= 0.0:
		view_size = Vector2(1280.0, 720.0)
	if body_scroll and body_vbox:
		var inner_w: float = maxf(230.0, panel_w - 22.0)
		var content_h: float = body_vbox.get_combined_minimum_size().y + 4.0
		var max_scroll_h: float = maxf(130.0, view_size.y - 120.0)
		body_scroll.custom_minimum_size = Vector2(inner_w, minf(content_h, max_scroll_h))
	panel.reset_size()
	panel.size = Vector2(panel_w, panel.get_combined_minimum_size().y)
	_move_panel_to(panel.position)

func _restore_mouse_mode_if_playing() -> void:
	var touch: bool = DisplayServer.is_touchscreen_available() or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	if GameManager.is_in_active_gameplay() and not get_tree().paused and not touch:
		var player := GameManager.player_character as PlayerController
		if player and not player.is_inventory_open and not player.is_caught:
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
	root_control.name = "SandboxPanelRoot"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	panel = PanelContainer.new()
	panel.name = "SandboxDraggablePanel"
	panel.position = Vector2(16.0, 88.0)
	panel.custom_minimum_size = Vector2(330.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override(
		"panel",
		HorrorTheme.make_minimal_panel_style(
			Color(0.086, 0.045, 0.043, 0.95),
			HorrorTheme.RELIC_BRASS,
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
	title.text = "SANDBOX OWNER [CTRL+F5]"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HorrorTheme.style_label(title, "label-lg", HorrorTheme.RELIC_BRASS, 10)
	header_row.add_child(title)

	min_btn = _make_sb_btn("–", "ghost", 26.0)
	min_btn.pressed.connect(_toggle_minimize)
	header_row.add_child(min_btn)

	var close_btn := _make_sb_btn("X", "danger", 26.0)
	close_btn.pressed.connect(toggle_panel)
	header_row.add_child(close_btn)

	body_wrapper = VBoxContainer.new()
	body_wrapper.add_theme_constant_override("separation", 5)
	main_vbox.add_child(body_wrapper)

	body_scroll = ScrollContainer.new()
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body_scroll.follow_focus = true
	body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HorrorTheme.style_scroll_container(body_scroll)
	body_wrapper.add_child(body_scroll)

	body_vbox = VBoxContainer.new()
	body_vbox.add_theme_constant_override("separation", 5)
	body_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.add_child(body_vbox)

	# 1. Pemain
	body_vbox.add_child(_make_section_label("PEMAIN"))
	var row_p1 := _make_row()
	god_mode_btn = _make_sb_btn("God Mode: OFF", "secondary")
	god_mode_btn.pressed.connect(func() -> void:
		var next_val: bool = not GameManager.admin_god_mode
		GameManager.apply_sandbox_command("god_mode", {"enabled": next_val}, true)
		_refresh_panel_state()
		_set_status("God Mode: %s" % ("ON" if GameManager.admin_god_mode else "OFF"))
	)
	row_p1.add_child(god_mode_btn)

	inf_stamina_btn = _make_sb_btn("Stamina Tak Terbatas: OFF", "secondary")
	inf_stamina_btn.pressed.connect(func() -> void:
		var next_val: bool = not GameManager.sandbox_infinite_stamina
		GameManager.apply_sandbox_command("infinite_stamina", {"enabled": next_val}, true)
		_refresh_panel_state()
		_set_status("Stamina Tak Terbatas: %s" % ("ON" if GameManager.sandbox_infinite_stamina else "OFF"))
	)
	row_p1.add_child(inf_stamina_btn)

	var row_p2 := _make_row()
	inf_battery_btn = _make_sb_btn("Baterai Tak Terbatas: OFF", "secondary")
	inf_battery_btn.pressed.connect(func() -> void:
		var next_val: bool = not GameManager.sandbox_infinite_battery
		GameManager.apply_sandbox_command("infinite_battery", {"enabled": next_val}, true)
		_refresh_panel_state()
		_set_status("Baterai Tak Terbatas: %s" % ("ON" if GameManager.sandbox_infinite_battery else "OFF"))
	)
	row_p2.add_child(inf_battery_btn)

	no_sanity_btn = _make_sb_btn("Tanpa Drain Waras: OFF", "secondary")
	no_sanity_btn.pressed.connect(func() -> void:
		var next_val: bool = not GameManager.sandbox_no_sanity_drain
		GameManager.apply_sandbox_command("no_sanity_drain", {"enabled": next_val}, true)
		_refresh_panel_state()
		_set_status("Tanpa Drain Waras: %s" % ("ON" if GameManager.sandbox_no_sanity_drain else "OFF"))
	)
	row_p2.add_child(no_sanity_btn)

	var row_p3 := _make_row()
	var refill_btn := _make_sb_btn("Isi Stat 100%", "primary")
	refill_btn.pressed.connect(func() -> void:
		GameManager.apply_sandbox_command("refill_stats", {}, true)
		_set_status("Waras, Stamina & Senter diisi 100%.")
	)
	row_p3.add_child(refill_btn)

	var row_speed := _make_row()
	var spd_lbl := Label.new()
	spd_lbl.text = "Kecepatan Gerak:"
	HorrorTheme.style_label(spd_lbl, "label-sm", HorrorTheme.ON_SURFACE, 10)
	row_speed.add_child(spd_lbl)
	for spd_val: float in [1.0, 1.5, 2.0]:
		var key: String = "1x" if is_equal_approx(spd_val, 1.0) else ("1.5x" if is_equal_approx(spd_val, 1.5) else "2x")
		var sbtn := _make_sb_btn(key, "secondary", 42.0)
		sbtn.pressed.connect(func() -> void:
			GameManager.apply_sandbox_command("speed_multiplier", {"value": spd_val}, true)
			_refresh_panel_state()
			_set_status("Kecepatan Gerak: %s" % key)
		)
		row_speed.add_child(sbtn)
		speed_buttons[key] = sbtn

	# 2. Lampor AI
	body_vbox.add_child(_make_section_label("LAMPOR AI"))
	var row_l1 := _make_row()
	freeze_lampor_btn = _make_sb_btn("Bekukan Lampor: OFF", "secondary")
	freeze_lampor_btn.pressed.connect(func() -> void:
		var next_val: bool = not GameManager.sandbox_freeze_lampor
		GameManager.apply_sandbox_command("freeze_lampor", {"enabled": next_val}, true)
		_refresh_panel_state()
		_set_status("Bekukan Lampor: %s" % ("ON" if GameManager.sandbox_freeze_lampor else "OFF"))
	)
	row_l1.add_child(freeze_lampor_btn)

	var descend_btn := _make_sb_btn("Turunkan Lampor", "secondary")
	descend_btn.pressed.connect(func() -> void:
		GameManager.apply_sandbox_command("descend_lampor", {}, true)
		_set_status("Lampor diturunkan ke desa.")
	)
	row_l1.add_child(descend_btn)

	var row_l2 := _make_row()
	var repel_btn := _make_sb_btn("Usir Lampor (Repel)", "secondary")
	repel_btn.pressed.connect(func() -> void:
		GameManager.apply_sandbox_command("repel_lampor", {"duration": 8.0}, true)
		_set_status("Lampor dipukul mundur (Repel).")
	)
	row_l2.add_child(repel_btn)

	var push_btn := _make_sb_btn("Jauhkan Lampor", "secondary")
	push_btn.pressed.connect(func() -> void:
		GameManager.apply_sandbox_command("push_lampor_away", {}, true)
		_set_status("Lampor dijauhkan ke ujung desa.")
	)
	row_l2.add_child(push_btn)

	var row_l3 := _make_row()
	var pull_btn := _make_sb_btn("Tarik Lampor ke Sekitar", "secondary")
	pull_btn.pressed.connect(func() -> void:
		GameManager.apply_sandbox_command("pull_lampor_near", {}, true)
		_set_status("Lampor ditarik mendekati area.")
	)
	row_l3.add_child(pull_btn)

	# 3. Waktu & Babak
	body_vbox.add_child(_make_section_label("WAKTU & BABAK"))
	var row_t1 := _make_row()
	pause_clock_btn = _make_sb_btn("Jeda Jam: OFF", "secondary")
	pause_clock_btn.pressed.connect(func() -> void:
		var next_val: bool = not GameManager.sandbox_pause_clock
		GameManager.apply_sandbox_command("pause_clock", {"enabled": next_val}, true)
		_refresh_panel_state()
		_set_status("Jeda Jam: %s" % ("ON" if GameManager.sandbox_pause_clock else "OFF"))
	)
	row_t1.add_child(pause_clock_btn)

	var row_acts := _make_row()
	for act_i: int in [1, 2, 3]:
		var act_btn := _make_sb_btn("Babak %d" % act_i, "secondary")
		act_btn.pressed.connect(func() -> void:
			GameManager.apply_sandbox_command("jump_act", {"act": act_i}, true)
			_set_status("Lompat ke Babak %d." % act_i)
		)
		row_acts.add_child(act_btn)

	var row_times := _make_row()
	var time_presets: Array[Dictionary] = [
		{"label": "01:00", "h": 1, "m": 0},
		{"label": "02:30", "h": 2, "m": 30},
		{"label": "04:00", "h": 4, "m": 0},
		{"label": "04:55", "h": 4, "m": 55}
	]
	for tp: Dictionary in time_presets:
		var t_btn := _make_sb_btn(str(tp["label"]), "secondary")
		var th: int = int(tp["h"])
		var tm: int = int(tp["m"])
		var tlabel: String = str(tp["label"])
		t_btn.pressed.connect(func() -> void:
			GameManager.apply_sandbox_command("set_time", {"hour": th, "minute": tm}, true)
			_set_status("Jam diatur ke %s WIB." % tlabel)
		)
		row_times.add_child(t_btn)

	var row_out := _make_row()
	var win_btn := _make_sb_btn("Menang Instan", "primary")
	win_btn.pressed.connect(func() -> void:
		_force_close()
		GameManager.apply_sandbox_command("instant_win", {}, true)
	)
	row_out.add_child(win_btn)

	var lose_btn := _make_sb_btn("Kalah Instan", "danger")
	lose_btn.pressed.connect(func() -> void:
		_force_close()
		GameManager.apply_sandbox_command("instant_lose", {}, true)
	)
	row_out.add_child(lose_btn)

	# 4. Dunia & Item
	body_vbox.add_child(_make_section_label("DUNIA & ITEM"))
	var row_w1 := _make_row()
	var torches_btn := _make_sb_btn("Nyalakan 5 Obor", "secondary")
	torches_btn.pressed.connect(func() -> void:
		GameManager.apply_sandbox_command("light_all_torches", {}, true)
		_set_status("5 Obor dinyalakan.")
	)
	row_w1.add_child(torches_btn)

	var doors_btn := _make_sb_btn("Barikade 3 Pintu", "secondary")
	doors_btn.pressed.connect(func() -> void:
		GameManager.apply_sandbox_command("barricade_doors", {}, true)
		_set_status("3 Pintu dibarikade.")
	)
	row_w1.add_child(doors_btn)

	var row_w2 := _make_row()
	var ritual_btn := _make_sb_btn("4 Benda Ritual", "secondary")
	ritual_btn.pressed.connect(func() -> void:
		GameManager.apply_sandbox_command("collect_ritual_items", {}, true)
		_set_status("4 Benda Ritual terkumpul.")
	)
	row_w2.add_child(ritual_btn)

	var items_btn := _make_sb_btn("+Semua Item", "secondary")
	items_btn.pressed.connect(func() -> void:
		GameManager.apply_sandbox_command("give_all_items", {}, true)
		_set_status("Semua item ditambahkan ke tas.")
	)
	row_w2.add_child(items_btn)

	var row_w3 := _make_row()
	var tp_btn := _make_sb_btn("Teleport ke Tungku", "secondary")
	tp_btn.pressed.connect(func() -> void:
		GameManager.apply_sandbox_command("teleport_altar", {}, false)
		_set_status("Teleport ke Tungku Balai Desa.")
	)
	row_w3.add_child(tp_btn)

	fog_btn = _make_sb_btn("Kabut Malam: ON", "secondary")
	fog_btn.pressed.connect(func() -> void:
		var next_val: bool = not GameManager.sandbox_fog_enabled
		GameManager.apply_sandbox_command("toggle_fog", {"enabled": next_val}, true)
		_refresh_panel_state()
		_set_status("Kabut Malam: %s" % ("ON" if GameManager.sandbox_fog_enabled else "OFF"))
	)
	row_w3.add_child(fog_btn)

	# 5. Pemain di Room
	body_vbox.add_child(_make_section_label("PEMAIN DI ROOM"))
	players_vbox = VBoxContainer.new()
	players_vbox.add_theme_constant_override("separation", 4)
	body_vbox.add_child(players_vbox)

	status_label = Label.new()
	status_label.text = "Seret header untuk geser · [–] perkecil"
	status_label.custom_minimum_size.x = 260.0
	status_label.clip_text = true
	HorrorTheme.style_label(status_label, "mono-sm", HorrorTheme.RELIC_BRASS, 9)
	body_wrapper.add_child(status_label)

func _make_section_label(txt: String) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	HorrorTheme.style_label(lbl, "label-lg", HorrorTheme.PRIMARY, 9)
	return lbl

func _make_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	body_vbox.add_child(row)
	return row

func _make_sb_btn(txt: String, variant: String = "secondary", min_w: float = 0.0) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(min_w, 28.0)
	if min_w <= 0.0:
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.clip_text = true
	HorrorTheme.style_button(btn, variant, 9, true)
	for st_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb: StyleBoxFlat = btn.get_theme_stylebox(st_name) as StyleBoxFlat
		if sb:
			var cp := sb.duplicate() as StyleBoxFlat
			cp.content_margin_left = 6.0
			cp.content_margin_right = 6.0
			cp.content_margin_top = 4.0
			cp.content_margin_bottom = 4.0
			btn.add_theme_stylebox_override(st_name, cp)
	return btn

func _refresh_panel_state() -> void:
	_refresh_toggle_states()
	_refresh_players_list(true)

func _refresh_toggle_states() -> void:
	if god_mode_btn:
		god_mode_btn.text = "God Mode: ON" if GameManager.admin_god_mode else "God Mode: OFF"
		HorrorTheme.style_button(god_mode_btn, "primary" if GameManager.admin_god_mode else "secondary", 9, true)
	if inf_stamina_btn:
		inf_stamina_btn.text = "Stamina Tak Terbatas: ON" if GameManager.sandbox_infinite_stamina else "Stamina Tak Terbatas: OFF"
		HorrorTheme.style_button(inf_stamina_btn, "primary" if GameManager.sandbox_infinite_stamina else "secondary", 9, true)
	if inf_battery_btn:
		inf_battery_btn.text = "Baterai Tak Terbatas: ON" if GameManager.sandbox_infinite_battery else "Baterai Tak Terbatas: OFF"
		HorrorTheme.style_button(inf_battery_btn, "primary" if GameManager.sandbox_infinite_battery else "secondary", 9, true)
	if no_sanity_btn:
		no_sanity_btn.text = "Tanpa Drain Waras: ON" if GameManager.sandbox_no_sanity_drain else "Tanpa Drain Waras: OFF"
		HorrorTheme.style_button(no_sanity_btn, "primary" if GameManager.sandbox_no_sanity_drain else "secondary", 9, true)
	if freeze_lampor_btn:
		freeze_lampor_btn.text = "Bekukan Lampor: ON" if GameManager.sandbox_freeze_lampor else "Bekukan Lampor: OFF"
		HorrorTheme.style_button(freeze_lampor_btn, "primary" if GameManager.sandbox_freeze_lampor else "secondary", 9, true)
	if pause_clock_btn:
		pause_clock_btn.text = "Jeda Jam: ON" if GameManager.sandbox_pause_clock else "Jeda Jam: OFF"
		HorrorTheme.style_button(pause_clock_btn, "primary" if GameManager.sandbox_pause_clock else "secondary", 9, true)
	if fog_btn:
		fog_btn.text = "Kabut Malam: ON" if GameManager.sandbox_fog_enabled else "Kabut Malam: OFF"
		HorrorTheme.style_button(fog_btn, "primary" if GameManager.sandbox_fog_enabled else "secondary", 9, true)
	var spd: float = GameManager.sandbox_speed_multiplier
	for key: String in speed_buttons.keys():
		var btn: Button = speed_buttons[key] as Button
		if not is_instance_valid(btn):
			continue
		var target_val: float = 1.0 if key == "1x" else (1.5 if key == "1.5x" else 2.0)
		var active: bool = is_equal_approx(spd, target_val)
		HorrorTheme.style_button(btn, "primary" if active else "secondary", 9, true)

func _refresh_players_list(force: bool = false) -> void:
	if not is_instance_valid(players_vbox):
		return
	var mp: Variant = GameManager.get_multiplayer_manager()
	if mp == null:
		return
	var host_id: String = str(mp.current_room.get("hostUserId", ""))
	var sig_parts: PackedStringArray = PackedStringArray()
	for p_var: Variant in mp.room_players:
		if p_var is Dictionary:
			var p: Dictionary = p_var as Dictionary
			var uid: String = str(p.get("userId", p.get("id", "")))
			var uname: String = str(p.get("username", "Pemain"))
			var ps: Variant = p.get("playerState", {})
			var san: int = int(round(float(ps.get("sanity", 100)) if ps is Dictionary else float(p.get("sanity", 100))))
			sig_parts.append("%s:%s:%d" % [uid, uname, san])
	var sig: String = "|".join(sig_parts)
	if not force and sig == _last_roster_signature:
		return
	_last_roster_signature = sig

	for child: Node in players_vbox.get_children():
		players_vbox.remove_child(child)
		child.queue_free()

	if mp.room_players.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Belum ada pemain terhubung."
		HorrorTheme.style_label(empty_lbl, "label-sm", HorrorTheme.TEXT_MUTED, 9)
		players_vbox.add_child(empty_lbl)
		return

	for p_var: Variant in mp.room_players:
		if not (p_var is Dictionary):
			continue
		var p: Dictionary = p_var as Dictionary
		var uid: String = str(p.get("userId", p.get("id", "")))
		var uname: String = str(p.get("username", "Pemain"))
		var is_host: bool = bool(p.get("isHost", false)) or (not host_id.is_empty() and uid == host_id)
		var ps: Variant = p.get("playerState", {})
		var sanity_pct: int = clampi(int(round(float(ps.get("sanity", 100)) if ps is Dictionary else float(p.get("sanity", 100)))), 0, 100)

		var p_row := HBoxContainer.new()
		p_row.add_theme_constant_override("separation", 4)
		players_vbox.add_child(p_row)

		var p_lbl := Label.new()
		p_lbl.text = "%s%s · %d%%" % [uname, " [HOST]" if is_host else "", sanity_pct]
		p_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p_lbl.clip_text = true
		HorrorTheme.style_label(p_lbl, "mono-sm", HorrorTheme.RELIC_BRASS if is_host else HorrorTheme.ON_SURFACE, 9)
		p_row.add_child(p_lbl)

		if not is_host and not uid.is_empty():
			var kick_btn := _make_sb_btn("Kick", "danger", 44.0)
			kick_btn.pressed.connect(func() -> void:
				_kick_peer(uid, uname)
			)
			p_row.add_child(kick_btn)

func _kick_peer(target_uid: String, target_name: String) -> void:
	_set_status("Mengeluarkan %s..." % target_name)
	var mp: Variant = GameManager.get_multiplayer_manager()
	if mp == null:
		_set_status("Layanan multiplayer tidak tersedia.")
		return
	var res: Dictionary = await mp.kick_player(target_uid)
	if bool(res.get("ok", false)):
		_set_status("%s dikeluarkan dari room." % target_name)
		_refresh_players_list(true)
	else:
		_set_status(str(res.get("message", "Gagal mengeluarkan pemain.")))

func _set_status(msg: String) -> void:
	if status_label:
		status_label.text = msg
