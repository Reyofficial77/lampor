class_name HUD
extends CanvasLayer

@onready var interaction_label: Label = $CenterContainer/InteractionLabel
@onready var act_banner: Label = $CenterContainer/ActBanner
@onready var clock_label: Label = $TopLeft/VBox/ClockLabel
@onready var act_label: Label = $TopLeft/VBox/ActLabel
@onready var objectives_container: VBoxContainer = $TopLeft/VBox/ObjectivesList
@onready var top_left: MarginContainer = $TopLeft
@onready var bottom_left: MarginContainer = $BottomLeft
@onready var bottom_right: MarginContainer = $BottomRight
@onready var bottom_center: MarginContainer = $BottomCenter

@onready var sanity_bar: ProgressBar = $BottomLeft/VBox/SanityContainer/SanityBar
@onready var sanity_val: Label = $BottomLeft/VBox/SanityContainer/SanityVal
@onready var stamina_bar: ProgressBar = $BottomLeft/VBox/StaminaContainer/StaminaBar
@onready var stamina_val: Label = $BottomLeft/VBox/StaminaContainer/StaminaVal
@onready var battery_bar: ProgressBar = $BottomLeft/VBox/BatteryContainer/BatteryBar
@onready var battery_val: Label = $BottomLeft/VBox/BatteryContainer/BatteryVal
@onready var noise_bar: ProgressBar = $BottomRight/VBox/NoiseBar

@onready var slots_container: HBoxContainer = $BottomCenter/SlotsContainer
@onready var post_process_rect: ColorRect = $HorrorOverlay
@onready var stare_warning: Label = $CenterContainer/StareWarning
@onready var jumpscare_rect: ColorRect = $JumpscareOverlay

# Pause Menu Nodes
@onready var pause_menu: Control = $PauseMenu
@onready var resume_button: Button = $PauseMenu/Center/Panel/VBox/ResumeButton
@onready var settings_button: Button = $PauseMenu/Center/Panel/VBox/SettingsButton
@onready var exit_button: Button = $PauseMenu/Center/Panel/VBox/ExitButton

# Barricade Warning Dialog Nodes
@onready var barricade_dialog: PanelContainer = $BarricadeConfirmDialog
@onready var confirm_barricade_btn: Button = $BarricadeConfirmDialog/Margin/VBox/Buttons/ConfirmButton
@onready var cancel_barricade_btn: Button = $BarricadeConfirmDialog/Margin/VBox/Buttons/CancelButton

var pending_barricade_door: Node = null
var pending_barricade_player: Node = null

var objective_labels: Dictionary = {}
var post_process_material: ShaderMaterial = null
var banner_tween: Tween = null
var jumpscare_face: Control = null
var jumpscare_tween: Tween = null
var dialog_label: Label
var dialog_tween: Tween
var touch_controls_enabled: bool = false
var touch_root: Control
var joystick_base: Control
var joystick_vector: Vector2 = Vector2.ZERO
var joystick_touch_index: int = -1
var look_touch_index: int = -1
var touch_buttons: Array[Button] = []
var desktop_hint_panel: PanelContainer
var pause_settings_panel: PanelContainer
var objective_texts: Dictionary = {}
var mission_panel: PanelContainer
var mission_title: Label
var mission_body: Label
var mission_tween: Tween
var dialog_panel: PanelContainer
var exit_confirm_overlay: ColorRect
var exit_panel: PanelContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if post_process_rect and post_process_rect.material is ShaderMaterial:
		post_process_material = post_process_rect.material as ShaderMaterial

	# Connect signals
	SignalBus.player_sanity_changed.connect(_on_sanity_changed)
	SignalBus.player_stamina_changed.connect(_on_stamina_changed)
	SignalBus.flashlight_battery_changed.connect(_on_battery_changed)
	SignalBus.player_noise_made.connect(_on_noise_made)
	SignalBus.time_tick.connect(_on_time_tick)
	SignalBus.act_started.connect(_on_act_started)
	SignalBus.objective_updated.connect(_on_objective_updated)
	SignalBus.inventory_updated.connect(_on_inventory_updated)
	SignalBus.item_equipped.connect(_on_item_equipped)
	SignalBus.lampor_stare_detected.connect(_on_lampor_stare)
	SignalBus.dialog_requested.connect(_on_dialog_requested)
	SignalBus.request_barricade_warning.connect(_on_barricade_warning)

	interaction_label.text = ""
	stare_warning.visible = false
	jumpscare_rect.visible = false
	_build_jumpscare_face()
	_build_dialog_label()
	_build_mission_card()
	_build_exit_confirm()
	_build_desktop_hints()
	SettingsManager.call_deferred("_apply_brightness_overlay")
	act_banner.visible = false
	pause_menu.visible = false
	barricade_dialog.visible = false

	# Setup Pause buttons
	resume_button.pressed.connect(toggle_pause)
	exit_button.pressed.connect(_show_exit_confirm)
	settings_button.text = "Pengaturan"
	settings_button.pressed.connect(_open_pause_settings)
	_build_pause_settings_panel()

	# Setup Barricade buttons
	confirm_barricade_btn.pressed.connect(_on_confirm_barricade)
	cancel_barricade_btn.pressed.connect(_on_cancel_barricade)

	get_viewport().size_changed.connect(_apply_mobile_hud_layout)
	call_deferred("_connect_player")
	call_deferred("_setup_mobile_controls")
	call_deferred("_apply_mobile_hud_layout")
	get_viewport().size_changed.connect(_apply_overlay_layouts)
	call_deferred("_apply_overlay_layouts")

func _connect_player() -> void:
	var player: PlayerController = GameManager.player_character as PlayerController
	if player and player.interaction_ray:
		player.interaction_ray.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	for i: int in range(slots_container.get_child_count()):
		var slot: Control = slots_container.get_child(i) as Control
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		_set_children_mouse_ignore(slot)
		slot.gui_input.connect(_on_inventory_slot_input.bind(i))

func _set_children_mouse_ignore(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_ignore(child)

func _on_inventory_slot_input(event: InputEvent, slot_index: int) -> void:
	if get_tree().paused or GameManager.current_state != GameManager.GameState.PLAYING:
		return
	var pressed: bool = false
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		pressed = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	if pressed:
		var player: PlayerController = GameManager.player_character as PlayerController
		if player:
			player.touch_select_slot(slot_index)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if exit_confirm_overlay and exit_confirm_overlay.visible:
			exit_confirm_overlay.visible = false
			if pause_menu.visible:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _is_touch_device() else Input.MOUSE_MODE_CAPTURED
		elif barricade_dialog.visible:
			_close_barricade_dialog()
		else:
			toggle_pause()

func toggle_pause() -> void:
	# Jangan izinkan pemain membatalkan jeda paksa selama rangkaian jumpscare.
	if GameManager.death_sequence_active:
		return
	if GameManager.current_state == GameManager.GameState.GAMEOVER or GameManager.current_state == GameManager.GameState.VICTORY:
		return
	if barricade_dialog.visible:
		return
	if exit_confirm_overlay and exit_confirm_overlay.visible:
		return
	var is_paused: bool = not get_tree().paused
	get_tree().paused = is_paused
	pause_menu.visible = is_paused
	if desktop_hint_panel:
		desktop_hint_panel.visible = not is_paused
	if touch_root:
		touch_root.visible = not is_paused
	if is_paused:
		joystick_vector = Vector2.ZERO
		var player: PlayerController = GameManager.player_character as PlayerController
		if player:
			player.set_virtual_move(Vector2.ZERO)
			player.set_virtual_sprint(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if pause_settings_panel:
			pause_settings_panel.visible = false
		pause_menu.get_node("Center").visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _is_touch_device() else Input.MOUSE_MODE_CAPTURED

func _build_pause_settings_panel() -> void:
	pause_settings_panel = PanelContainer.new()
	pause_settings_panel.name = "PauseSettingsPanel"
	pause_settings_panel.visible = false
	pause_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_settings_panel.position = Vector2(-220.0, -190.0)
	pause_settings_panel.custom_minimum_size = Vector2(440.0, 380.0)
	pause_menu.add_child(pause_settings_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	pause_settings_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title := Label.new()
	title.text = "PENGATURAN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	_add_pause_slider(box, "Sensitivitas Mouse", SettingsManager.mouse_sensitivity * 100.0, 25.0, 200.0, func(v: float) -> void: SettingsManager.set_mouse_sensitivity(v / 100.0))
	_add_pause_slider(box, "Sensitivitas Kamera", SettingsManager.camera_sensitivity * 100.0, 25.0, 200.0, func(v: float) -> void: SettingsManager.set_camera_sensitivity(v / 100.0))
	_add_pause_slider(box, "Kecerahan", SettingsManager.brightness * 100.0, 50.0, 150.0, func(v: float) -> void: SettingsManager.set_brightness(v / 100.0))
	var quality := OptionButton.new()
	quality.add_item("Grafik: Otomatis (Perangkat)")
	quality.add_item("Grafik: Low")
	quality.add_item("Grafik: Medium")
	quality.add_item("Grafik: High")
	quality.select({"auto": 0, "low": 1, "medium": 2, "high": 3}.get(SettingsManager.graphics_quality, 0))
	quality.tooltip_text = "Otomatis menggunakan preset %s berdasarkan perangkat ini" % SettingsManager.recommended_graphics_quality.capitalize()
	quality.item_selected.connect(func(index: int) -> void: SettingsManager.set_graphics_quality(["auto", "low", "medium", "high"][index]))
	box.add_child(quality)
	var close := Button.new()
	close.text = "Kembali ke Jeda"
	close.pressed.connect(func() -> void:
		pause_settings_panel.visible = false
		pause_menu.get_node("Center").visible = true
	)
	box.add_child(close)

func _add_pause_slider(parent: VBoxContainer, caption: String, initial: float, minimum: float, maximum: float, callback: Callable) -> void:
	var row := VBoxContainer.new()
	var label := Label.new()
	label.text = "%s: %d%%" % [caption, int(round(initial))]
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 5.0
	slider.value = initial
	slider.value_changed.connect(func(value: float) -> void:
		label.text = "%s: %d%%" % [caption, int(round(value))]
		callback.call(value)
	)
	row.add_child(slider)
	parent.add_child(row)

func _open_pause_settings() -> void:
	pause_menu.get_node("Center").visible = false
	pause_settings_panel.visible = true

func _on_main_menu_pressed() -> void:
	if desktop_hint_panel:
		desktop_hint_panel.visible = false
	barricade_dialog.visible = false
	get_tree().paused = false
	GameManager.current_state = GameManager.GameState.MENU
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _on_barricade_warning(door_node: Node, player_node: Node) -> void:
	pending_barricade_door = door_node
	pending_barricade_player = player_node
	barricade_dialog.visible = true
	if touch_root:
		touch_root.visible = false
	var player: PlayerController = GameManager.player_character as PlayerController
	if player:
		player.set_virtual_move(Vector2.ZERO)
		player.set_virtual_sprint(false)
	joystick_vector = Vector2.ZERO
	# Game dijeda selama dialog terbuka supaya pemain tidak bisa jalan/diserang
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_confirm_barricade() -> void:
	if pending_barricade_door and is_instance_valid(pending_barricade_door):
		if pending_barricade_door.has_method("confirm_barricade"):
			pending_barricade_door.confirm_barricade(pending_barricade_player)
	_close_barricade_dialog()

func _on_cancel_barricade() -> void:
	_close_barricade_dialog()

func _close_barricade_dialog() -> void:
	pending_barricade_door = null
	pending_barricade_player = null
	barricade_dialog.visible = false
	if not pause_menu.visible:
		get_tree().paused = false
		if touch_root:
			touch_root.visible = GameManager.current_state == GameManager.GameState.PLAYING
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _is_touch_device() else Input.MOUSE_MODE_CAPTURED

func _make_overlay_style(alpha: float, h_margin: float, v_margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.026, 0.032, alpha)
	style.border_color = Color(0.55, 0.14, 0.16, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = h_margin
	style.content_margin_right = h_margin
	style.content_margin_top = v_margin
	style.content_margin_bottom = v_margin
	return style

func _build_dialog_label() -> void:
	# Dialog dibungkus panel yang tumbuh ke atas mengikuti panjang teks,
	# sehingga dialog panjang tidak terpotong atau tertutup elemen HUD lain.
	dialog_panel = PanelContainer.new()
	dialog_panel.name = "NarrativeDialogPanel"
	dialog_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dialog_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dialog_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dialog_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_panel.z_index = 5
	dialog_panel.modulate.a = 0.0
	dialog_panel.add_theme_stylebox_override("panel", _make_overlay_style(0.84, 14.0, 10.0))

	dialog_label = Label.new()
	dialog_label.name = "NarrativeDialog"
	dialog_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_label.add_theme_font_size_override("font_size", 21)
	dialog_label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.82, 1.0))
	dialog_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	dialog_label.add_theme_constant_override("outline_size", 4)
	dialog_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_panel.add_child(dialog_label)
	add_child(dialog_panel)

func _on_dialog_requested(text_value: String, duration: float) -> void:
	if not dialog_label or not dialog_panel:
		return
	if dialog_tween and dialog_tween.is_running():
		dialog_tween.kill()
	dialog_label.text = text_value
	dialog_panel.modulate.a = 0.0
	# Teks panjang diberi waktu baca lebih lama
	var hold: float = maxf(maxf(0.5, duration), float(text_value.length()) * 0.07)
	dialog_tween = create_tween()
	dialog_tween.tween_property(dialog_panel, "modulate:a", 1.0, 0.22)
	dialog_tween.tween_interval(hold)
	dialog_tween.tween_property(dialog_panel, "modulate:a", 0.0, 0.55)

func _build_mission_card() -> void:
	mission_panel = PanelContainer.new()
	mission_panel.name = "MissionCard"
	mission_panel.set_anchors_preset(Control.PRESET_CENTER)
	mission_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mission_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	mission_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mission_panel.z_index = 4
	mission_panel.visible = false
	mission_panel.add_theme_stylebox_override("panel", _make_overlay_style(0.88, 18.0, 14.0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mission_panel.add_child(box)
	mission_title = Label.new()
	mission_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_title.add_theme_font_size_override("font_size", 19)
	mission_title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	mission_title.add_theme_constant_override("outline_size", 4)
	box.add_child(mission_title)
	var separator := HSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(separator)
	var heading := Label.new()
	heading.text = "MISI"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", Color(0.85, 0.7, 0.4, 1.0))
	box.add_child(heading)
	mission_body = Label.new()
	mission_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_body.add_theme_font_size_override("font_size", 17)
	mission_body.add_theme_color_override("font_color", Color(0.95, 0.93, 0.9, 1.0))
	box.add_child(mission_body)
	add_child(mission_panel)

func _refresh_mission_card() -> void:
	if not mission_body:
		return
	var lines: PackedStringArray = PackedStringArray()
	for line: String in objective_texts.values():
		lines.append("• " + line)
	mission_body.text = "\n".join(lines) if not lines.is_empty() else "Misi sedang disiapkan..."

func _show_mission_card(num: int, banner_text: String) -> void:
	if not mission_panel:
		return
	if mission_tween:
		mission_tween.kill()
	mission_title.text = banner_text
	mission_title.add_theme_color_override("font_color", act_banner.get_theme_color("font_color"))
	_refresh_mission_card()
	_apply_overlay_layouts()
	mission_panel.modulate.a = 0.0
	mission_panel.visible = true
	mission_tween = create_tween()
	mission_tween.tween_property(mission_panel, "modulate:a", 1.0, 0.35)
	mission_tween.tween_interval(7.0)
	mission_tween.tween_property(mission_panel, "modulate:a", 0.0, 0.9)
	mission_tween.tween_callback(func() -> void: mission_panel.visible = false)

func _make_exit_button(text_value: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 48.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.42, 0.065, 0.085, 1.0) if primary else Color(0.14, 0.12, 0.13, 1.0)
	normal.border_color = Color(0.72, 0.12, 0.14, 1.0) if primary else Color(0.34, 0.09, 0.1, 1.0)
	normal.border_width_bottom = 2
	normal.set_corner_radius_all(5)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.62, 0.09, 0.12, 1.0) if primary else Color(0.24, 0.08, 0.09, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	return button

func _build_exit_confirm() -> void:
	exit_confirm_overlay = ColorRect.new()
	exit_confirm_overlay.name = "ExitConfirmOverlay"
	exit_confirm_overlay.color = Color(0.0, 0.0, 0.0, 0.82)
	exit_confirm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	exit_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	exit_confirm_overlay.z_index = 20
	exit_confirm_overlay.visible = false
	add_child(exit_confirm_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	exit_confirm_overlay.add_child(center)
	exit_panel = PanelContainer.new()
	exit_panel.custom_minimum_size = Vector2(440.0, 0.0)
	exit_panel.add_theme_stylebox_override("panel", _make_overlay_style(0.98, 22.0, 20.0))
	center.add_child(exit_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	exit_panel.add_child(box)
	var title := Label.new()
	title.text = "KELUAR DARI GAME?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color(0.85, 0.25, 0.25, 1.0))
	box.add_child(title)
	var message := Label.new()
	message.text = "Yakin ingin keluar dari game?\nProgres permainan yang sedang berjalan tidak akan disimpan."
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 15)
	box.add_child(message)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var cancel := _make_exit_button("BATAL", false)
	cancel.pressed.connect(func() -> void:
		exit_confirm_overlay.visible = false
		if pause_menu.visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _is_touch_device() else Input.MOUSE_MODE_CAPTURED
	)
	buttons.add_child(cancel)
	var confirm := _make_exit_button("YA, KELUAR", true)
	confirm.pressed.connect(func() -> void: get_tree().quit())
	buttons.add_child(confirm)

func _show_exit_confirm() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_apply_overlay_layouts()
	exit_confirm_overlay.visible = true

func _apply_overlay_layouts() -> void:
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var compact: bool = view_size.x < 700.0 or view_size.y < 520.0
	var touch: bool = _is_touch_device()
	if dialog_panel and dialog_label:
		# Sisakan ruang untuk joystick/tombol (HP) atau panel kontrol (desktop)
		var touch_margin: float = 340.0 if view_size.x >= 520.0 else 28.0
		var dialog_w: float = clampf(view_size.x - touch_margin, 240.0, 860.0) if touch else clampf(view_size.x - 640.0, 320.0, 860.0)
		var bottom_gap: float = 92.0 if touch else 120.0
		dialog_panel.offset_left = -dialog_w * 0.5
		dialog_panel.offset_right = dialog_w * 0.5
		dialog_panel.offset_bottom = -bottom_gap
		dialog_panel.offset_top = -bottom_gap - 20.0
		dialog_label.custom_minimum_size.x = dialog_w - 28.0
		dialog_label.add_theme_font_size_override("font_size", 15 if compact else 21)
	if mission_panel:
		var card_w: float = minf(view_size.x - 28.0, 600.0)
		mission_panel.offset_left = -card_w * 0.5
		mission_panel.offset_right = card_w * 0.5
		mission_panel.offset_top = -20.0
		mission_panel.offset_bottom = 20.0
		mission_title.custom_minimum_size.x = card_w - 36.0
		mission_body.custom_minimum_size.x = card_w - 36.0
		mission_title.add_theme_font_size_override("font_size", 14 if compact else 19)
		mission_body.add_theme_font_size_override("font_size", 12 if compact else 17)
	if exit_panel:
		exit_panel.custom_minimum_size.x = minf(440.0, view_size.x - 32.0)

func _is_touch_device() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios")

func _setup_mobile_controls() -> void:
	touch_controls_enabled = _is_touch_device()
	if not touch_controls_enabled:
		return
	touch_root = Control.new()
	touch_root.name = "MobileControls"
	touch_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(touch_root)
	joystick_base = Control.new()
	joystick_base.name = "VirtualJoystick"
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_base.draw.connect(_draw_virtual_joystick)
	touch_root.add_child(joystick_base)

	var run_button := _make_touch_button("LARI")
	run_button.button_down.connect(_on_touch_run_down)
	run_button.button_up.connect(_on_touch_run_up)
	var interact_button := _make_touch_button("E")
	interact_button.pressed.connect(_on_touch_interact)
	var flashlight_button := _make_touch_button("SENTER")
	flashlight_button.pressed.connect(_on_touch_flashlight)
	var use_button := _make_touch_button("PAKAI")
	use_button.pressed.connect(_on_touch_use)
	var pause_button := _make_touch_button("Ⅱ")
	pause_button.pressed.connect(toggle_pause)
	touch_buttons.append(run_button)
	touch_buttons.append(interact_button)
	touch_buttons.append(flashlight_button)
	touch_buttons.append(use_button)
	touch_buttons.append(pause_button)
	for button: Button in touch_buttons:
		touch_root.add_child(button)
	get_viewport().size_changed.connect(_layout_touch_controls)
	_layout_touch_controls()

func _make_touch_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color(1.0, 0.94, 0.9, 1.0))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.07, 0.08, 0.62)
	normal.border_color = Color(0.76, 0.2, 0.22, 0.8)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(34)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.46, 0.07, 0.09, 0.88)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", pressed)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)
	return button

func _layout_touch_controls() -> void:
	if not touch_controls_enabled or not joystick_base:
		return
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var compact: bool = view_size.x < 700.0
	var joystick_size: float = 142.0 if compact else 168.0
	var button_size: float = 66.0 if compact else 86.0
	joystick_base.position = Vector2(16.0, view_size.y - joystick_size - 24.0)
	joystick_base.size = Vector2(joystick_size, joystick_size)
	var x_right: float = view_size.x - button_size - 14.0
	var x_left: float = x_right - button_size - 10.0
	var y_bottom: float = view_size.y - button_size - 24.0
	var y_top: float = y_bottom - button_size - 10.0
	var positions: Array[Vector2] = [Vector2(x_left, y_top), Vector2(x_right, y_top), Vector2(x_left, y_bottom), Vector2(x_right, y_bottom), Vector2(view_size.x - 58.0, 16.0)]
	for i: int in range(touch_buttons.size()):
		var button: Button = touch_buttons[i]
		button.position = positions[i]
		button.size = Vector2(button_size, button_size)
		if i == 4:
			button.position = Vector2(view_size.x - 66.0, 14.0)
			button.size = Vector2(54.0, 54.0)

func _apply_mobile_hud_layout() -> void:
	if not _is_touch_device():
		return
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	top_left.offset_left = 12.0
	top_left.offset_top = 12.0
	top_left.offset_right = minf(view_size.x * 0.52, 420.0)
	top_left.offset_bottom = 208.0
	clock_label.add_theme_font_size_override("font_size", 18)
	act_label.add_theme_font_size_override("font_size", 12)
	for objective: Node in objectives_container.get_children():
		if objective is Label:
			(objective as Label).add_theme_font_size_override("font_size", 11)
	bottom_left.anchor_left = 1.0
	bottom_left.anchor_right = 1.0
	bottom_left.anchor_top = 0.0
	bottom_left.anchor_bottom = 0.0
	bottom_left.offset_left = -248.0
	bottom_left.offset_top = 72.0
	bottom_left.offset_right = -10.0
	bottom_left.offset_bottom = 178.0
	bottom_left.scale = Vector2(0.84, 0.84)
	var stats_vbox: VBoxContainer = bottom_left.get_node("VBox") as VBoxContainer
	stats_vbox.add_theme_constant_override("separation", 3)
	for container_name: String in ["SanityContainer", "StaminaContainer", "BatteryContainer"]:
		var row: HBoxContainer = bottom_left.get_node("VBox/" + container_name) as HBoxContainer
		var row_label: Label = row.get_child(0) as Label
		var row_bar: ProgressBar = row.get_child(1) as ProgressBar
		var row_value: Label = row.get_child(2) as Label
		row_label.custom_minimum_size.x = 62.0
		row_label.add_theme_font_size_override("font_size", 10)
		row_bar.custom_minimum_size = Vector2(105.0, 13.0)
		row_value.custom_minimum_size.x = 32.0
		row_value.add_theme_font_size_override("font_size", 9)
	bottom_right.visible = false
	slots_container.add_theme_constant_override("separation", 4)
	var slot_size: Vector2 = Vector2(76.0, 58.0) if view_size.x < 700.0 else Vector2(86.0, 64.0)
	for slot: Node in slots_container.get_children():
		var panel: PanelContainer = slot as PanelContainer
		panel.custom_minimum_size = slot_size
		for label: Node in panel.find_children("*", "Label", true, false):
			(label as Label).add_theme_font_size_override("font_size", 9)
	var inventory_width: float = slot_size.x * slots_container.get_child_count() + 12.0 + 24.0
	bottom_center.offset_left = -inventory_width * 0.5
	bottom_center.offset_top = -82.0
	bottom_center.offset_right = inventory_width * 0.5
	bottom_center.offset_bottom = -10.0
	if dialog_label:
		dialog_label.add_theme_font_size_override("font_size", 17)

func _build_desktop_hints() -> void:
	if _is_touch_device():
		return
	desktop_hint_panel = PanelContainer.new()
	desktop_hint_panel.name = "DesktopKeyHints"
	desktop_hint_panel.z_index = 2
	desktop_hint_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	desktop_hint_panel.offset_left = -282.0
	desktop_hint_panel.offset_top = -238.0
	desktop_hint_panel.offset_right = -22.0
	desktop_hint_panel.offset_bottom = -94.0
	desktop_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.022, 0.028, 0.78)
	panel_style.border_color = Color(0.48, 0.13, 0.15, 0.72)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(5)
	panel_style.content_margin_left = 12.0
	panel_style.content_margin_top = 8.0
	panel_style.content_margin_right = 12.0
	panel_style.content_margin_bottom = 8.0
	desktop_hint_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(desktop_hint_panel)
	var hint_column := VBoxContainer.new()
	hint_column.add_theme_constant_override("separation", 3)
	desktop_hint_panel.add_child(hint_column)
	var heading := Label.new()
	heading.text = "KONTROL DESKTOP"
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", Color(0.88, 0.55, 0.48, 1.0))
	hint_column.add_child(heading)
	var hints := Label.new()
	hints.text = "W A S D  ·  Bergerak     Mouse  ·  Lihat\nShift  ·  Berlari        E  ·  Interaksi\nF  ·  Senter            1–4  ·  Pilih item\nEnter / Space  ·  Gunakan item\nG  ·  Jatuhkan item      Esc  ·  Jeda"
	hints.add_theme_font_size_override("font_size", 11)
	hints.add_theme_color_override("font_color", Color(0.9, 0.88, 0.85, 0.94))
	hints.add_theme_constant_override("line_spacing", 2)
	hints.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_column.add_child(hints)

func _draw_virtual_joystick() -> void:
	if not joystick_base:
		return
	var center: Vector2 = joystick_base.size * 0.5
	var radius: float = joystick_base.size.x * 0.43
	joystick_base.draw_circle(center, radius, Color(0.02, 0.02, 0.025, 0.42))
	joystick_base.draw_arc(center, radius, 0.0, TAU, 48, Color(0.82, 0.72, 0.68, 0.6), 2.0, true)
	var knob_center: Vector2 = center + Vector2(joystick_vector.x, -joystick_vector.y) * radius * 0.68
	joystick_base.draw_circle(knob_center, radius * 0.38, Color(0.55, 0.12, 0.15, 0.76))
	joystick_base.draw_arc(knob_center, radius * 0.38, 0.0, TAU, 36, Color(0.95, 0.72, 0.68, 0.72), 2.0, true)

func _input(event: InputEvent) -> void:
	if not touch_controls_enabled or get_tree().paused or GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			if not joystick_base or not bottom_center:
				return
			if joystick_base.get_global_rect().has_point(touch.position):
				joystick_touch_index = touch.index
				_update_virtual_joystick(touch.position)
			elif not _is_over_touch_button(touch.position) and not bottom_center.get_global_rect().has_point(touch.position) and touch.position.x >= get_viewport().get_visible_rect().size.x * 0.38:
				look_touch_index = touch.index
		else:
			if touch.index == joystick_touch_index:
				joystick_touch_index = -1
				joystick_vector = Vector2.ZERO
				var player: PlayerController = GameManager.player_character as PlayerController
				if player:
					player.set_virtual_move(Vector2.ZERO)
				joystick_base.queue_redraw()
			if touch.index == look_touch_index:
				look_touch_index = -1
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == joystick_touch_index:
			_update_virtual_joystick(drag.position)
		elif drag.index == look_touch_index:
			var player: PlayerController = GameManager.player_character as PlayerController
			if player:
				player.apply_touch_look(drag.relative)

func _update_virtual_joystick(screen_position: Vector2) -> void:
	if not joystick_base:
		return
	var local_position: Vector2 = screen_position - joystick_base.global_position
	var center: Vector2 = joystick_base.size * 0.5
	var radius: float = joystick_base.size.x * 0.38
	var offset: Vector2 = (local_position - center).limit_length(radius)
	joystick_vector = Vector2(offset.x / radius, -offset.y / radius)
	var player: PlayerController = GameManager.player_character as PlayerController
	if player:
		player.set_virtual_move(joystick_vector)
	joystick_base.queue_redraw()

func _is_over_touch_button(screen_position: Vector2) -> bool:
	for button: Button in touch_buttons:
		if button.get_global_rect().has_point(screen_position):
			return true
	return false

func _on_touch_run_down() -> void:
	if get_tree().paused:
		return
	var player: PlayerController = GameManager.player_character as PlayerController
	if player:
		player.set_virtual_sprint(true)

func _on_touch_run_up() -> void:
	var player: PlayerController = GameManager.player_character as PlayerController
	if player:
		player.set_virtual_sprint(false)

func _on_touch_interact() -> void:
	if get_tree().paused:
		return
	var player: PlayerController = GameManager.player_character as PlayerController
	if player:
		player.touch_interact()

func _on_touch_flashlight() -> void:
	if get_tree().paused:
		return
	var player: PlayerController = GameManager.player_character as PlayerController
	if player:
		player.toggle_flashlight()

func _on_touch_use() -> void:
	if get_tree().paused:
		return
	var player: PlayerController = GameManager.player_character as PlayerController
	if player:
		player.touch_use_item()

func _process(delta: float) -> void:
	if noise_bar.value > 0:
		noise_bar.value = move_toward(noise_bar.value, 0.0, delta * 1.5)

func _on_interaction_prompt_changed(text: String) -> void:
	interaction_label.text = text

func _on_sanity_changed(current: float, max_val: float) -> void:
	sanity_bar.max_value = max_val
	sanity_bar.value = current
	sanity_val.text = "%d%%" % int((current / max_val) * 100.0)
	
	var fear: float = 1.0 - (current / max_val)
	if post_process_material:
		post_process_material.set_shader_parameter("vignette_intensity", lerp(0.35, 1.2, fear))
		post_process_material.set_shader_parameter("aberration_amount", lerp(0.001, 0.015, fear))
		post_process_material.set_shader_parameter("pulse_intensity", fear)

func _on_stamina_changed(current: float, max_val: float) -> void:
	stamina_bar.max_value = max_val
	stamina_bar.value = current
	stamina_val.text = "%d%%" % int((current / max_val) * 100.0)

func _on_battery_changed(current: float, max_val: float) -> void:
	battery_bar.max_value = max_val
	battery_bar.value = current
	battery_val.text = "%d%%" % int((current / max_val) * 100.0)

func _on_noise_made(level: float, _pos: Vector3) -> void:
	noise_bar.value = max(noise_bar.value, level * 100.0)

func _on_time_tick(time_str: String, _h: int, _m: int) -> void:
	var diff_name: String = GameManager.get_difficulty_name(GameManager.selected_difficulty)
	clock_label.text = "🕒 " + time_str + " WIB  [" + diff_name + "]"

func _on_act_started(num: int, title: String) -> void:
	act_label.text = title
	for child: Node in objectives_container.get_children():
		child.queue_free()
	objective_labels.clear()
	objective_texts.clear()
	# Bersihkan isi kartu sebelum objective_updated mengirim daftar babak baru.
	if mission_body:
		mission_body.text = "Memuat misi..."
	_show_act_banner(num, title)

func _show_act_banner(num: int, _title: String) -> void:
	if banner_tween:
		banner_tween.kill()

	# Banner lama digantikan kartu misi (teks banner dipakai sebagai judul kartu)
	act_banner.visible = false
	act_banner.modulate.a = 0.0

	match num:
		1:
			act_banner.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
			act_banner.text = "BABAK I: PERTAHANAN AWAL (01.00 WIB)\nNyalakan 5 Obor Penolak Bala & Barikade 3 Pintu Rumah!"
		2:
			act_banner.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
			act_banner.text = "⚠️ BABAK II: LAMPOR TURUN KE DESA! ⚠️\nKeranda terbang mulai berpatroli!\nJangan menatap langsung & matikan senter jika mendengar lonceng!"
			AudioManager.play_sound("lampor_roar", 1.0)
		3:
			act_banner.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1))
			act_banner.text = "🔥 BABAK III: KLIMAKS PEMBAKARAN! 🔥\nBakar semua benda ritual di Tungku Balai Desa & Bertahanlah!"
			AudioManager.play_sound("lampor_roar", 2.0)

	_show_mission_card(num, act_banner.text)

func _on_objective_updated(id: String, text: String, current: int, required: int, is_completed: bool) -> void:
	var label: Label = null
	if objective_labels.has(id):
		label = objective_labels[id]
	else:
		label = Label.new()
		label.add_theme_font_size_override("font_size", 16)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 240.0
		objectives_container.add_child(label)
		objective_labels[id] = label
		
	var status_icon: String = "✅" if is_completed else "◻️"
	var progress_str: String = " (%d/%d)" % [current, required] if required > 1 else ""
	label.text = "%s %s%s" % [status_icon, text, progress_str]
	label.modulate = Color(0.6, 1.0, 0.6) if is_completed else Color(1, 1, 1)
	objective_texts[id] = label.text
	_refresh_mission_card()

func _on_inventory_updated(slots: Array) -> void:
	for i in range(min(slots.size(), slots_container.get_child_count())):
		var slot_panel: PanelContainer = slots_container.get_child(i) as PanelContainer
		var label: Label = slot_panel.get_node("VBox/ItemName") as Label
		var qty_label: Label = slot_panel.get_node("VBox/Qty") as Label
		
		var item: Dictionary = slots[i]
		if item.is_empty():
			label.text = "[Kosong]"
			qty_label.text = ""
		else:
			label.text = item.get("name", "")
			if item.has("quantity") and item["quantity"] > 1:
				qty_label.text = "x" + str(item["quantity"])
			elif item.has("battery"):
				qty_label.text = "%d%%" % int(item["battery"])
			else:
				qty_label.text = ""

func _on_item_equipped(slot_index: int, _item: Dictionary) -> void:
	for i in range(slots_container.get_child_count()):
		var slot_panel: PanelContainer = slots_container.get_child(i) as PanelContainer
		if i == slot_index:
			slot_panel.modulate = Color(1.3, 1.3, 0.4)
		else:
			slot_panel.modulate = Color(1, 1, 1)

func _on_lampor_stare(intensity: float) -> void:
	if intensity > 0.4:
		stare_warning.visible = true
		stare_warning.text = "⚠️ JANGAN MENATAP LANGSUNG! ALIKAN PANDANGANMU! ⚠️"
	else:
		stare_warning.visible = false

func _build_jumpscare_face() -> void:
	# Wajah Lampor digambar lewat kode, jadi tidak butuh aset gambar tambahan
	jumpscare_rect.color = Color(0.3, 0.0, 0.0, 1.0)
	jumpscare_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jumpscare_face = Control.new()
	jumpscare_face.name = "LamporFace"
	jumpscare_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jumpscare_rect.add_child(jumpscare_face)
	jumpscare_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	jumpscare_face.draw.connect(_draw_jumpscare_face)

func _draw_jumpscare_face() -> void:
	var s: Vector2 = jumpscare_face.size
	var c: Vector2 = s * 0.5
	var u: float = min(s.x, s.y)

	# Wajah pucat memanjang
	var face_pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(48):
		var a: float = TAU * float(i) / 48.0
		face_pts.append(c + Vector2(cos(a) * u * 0.40, sin(a) * u * 0.58))
	jumpscare_face.draw_colored_polygon(face_pts, Color(0.80, 0.83, 0.76))

	# Rongga mata hitam dengan pupil merah menyala
	for side: float in [-1.0, 1.0]:
		var eye_pos: Vector2 = c + Vector2(side * u * 0.16, -u * 0.18)
		jumpscare_face.draw_circle(eye_pos, u * 0.11, Color(0.02, 0.0, 0.0))
		jumpscare_face.draw_circle(eye_pos, u * 0.035, Color(1.0, 0.1, 0.05))

	# Lubang hidung
	jumpscare_face.draw_circle(c + Vector2(-u * 0.03, u * 0.04), u * 0.012, Color(0.1, 0.05, 0.05))
	jumpscare_face.draw_circle(c + Vector2(u * 0.03, u * 0.04), u * 0.012, Color(0.1, 0.05, 0.05))

	# Mulut menganga
	var mouth_c: Vector2 = c + Vector2(0, u * 0.27)
	var mouth_pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(32):
		var a2: float = TAU * float(i) / 32.0
		mouth_pts.append(mouth_c + Vector2(cos(a2) * u * 0.20, sin(a2) * u * 0.14))
	jumpscare_face.draw_colored_polygon(mouth_pts, Color(0.05, 0.0, 0.0))

	# Gigi taring atas dan bawah
	for i: int in range(7):
		var tx: float = mouth_c.x - u * 0.16 + float(i) * u * 0.053
		var top_tri: PackedVector2Array = PackedVector2Array([
			Vector2(tx - u * 0.022, mouth_c.y - u * 0.115),
			Vector2(tx + u * 0.022, mouth_c.y - u * 0.115),
			Vector2(tx, mouth_c.y - u * 0.03)
		])
		jumpscare_face.draw_colored_polygon(top_tri, Color(0.95, 0.93, 0.82))
		var bot_tri: PackedVector2Array = PackedVector2Array([
			Vector2(tx - u * 0.022, mouth_c.y + u * 0.115),
			Vector2(tx + u * 0.022, mouth_c.y + u * 0.115),
			Vector2(tx, mouth_c.y + u * 0.03)
		])
		jumpscare_face.draw_colored_polygon(bot_tri, Color(0.95, 0.93, 0.82))

func _on_screamer() -> void:
	if desktop_hint_panel:
		desktop_hint_panel.visible = false
	if jumpscare_tween:
		jumpscare_tween.kill()
	jumpscare_rect.visible = true
	jumpscare_rect.modulate.a = 1.0
	if jumpscare_face:
		jumpscare_face.position = Vector2.ZERO
		jumpscare_face.queue_redraw()

	jumpscare_tween = create_tween()
	# Getaran layar yang cepat dan kasar
	for i: int in range(12):
		var shake: Vector2 = Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
		jumpscare_tween.tween_property(jumpscare_face, "position", shake, 0.04)
	jumpscare_tween.tween_property(jumpscare_face, "position", Vector2.ZERO, 0.02)
	jumpscare_tween.tween_interval(0.35)
	jumpscare_tween.tween_property(jumpscare_rect, "modulate:a", 0.0, 0.5)
	jumpscare_tween.tween_callback(func() -> void: jumpscare_rect.visible = false)
