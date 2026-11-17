class_name HUD
extends CanvasLayer

@onready var interaction_label: Label = $CenterContainer/InteractionLabel
@onready var act_banner: Label = $CenterContainer/ActBanner
@onready var clock_label: Label = $TopLeft/VBox/ClockLabel
@onready var act_label: Label = $TopLeft/VBox/ActLabel
@onready var objectives_container: VBoxContainer = $TopLeft/VBox/ObjectivesList

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
@onready var guide_button: Button = $PauseMenu/Center/Panel/VBox/GuideButton
@onready var menu_button: Button = $PauseMenu/Center/Panel/VBox/MenuButton
@onready var exit_button: Button = $PauseMenu/Center/Panel/VBox/ExitButton
@onready var pause_guide_panel: PanelContainer = $PauseMenu/PauseGuidePanel
@onready var close_guide_button: Button = $PauseMenu/PauseGuidePanel/Margin/VBox/CloseButton

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
	SignalBus.lampor_screamer_triggered.connect(_on_screamer)
	SignalBus.request_barricade_warning.connect(_on_barricade_warning)

	interaction_label.text = ""
	stare_warning.visible = false
	jumpscare_rect.visible = false
	_build_jumpscare_face()
	act_banner.visible = false
	pause_menu.visible = false
	pause_guide_panel.visible = false
	barricade_dialog.visible = false

	# Setup Pause buttons
	resume_button.pressed.connect(toggle_pause)
	menu_button.pressed.connect(_on_main_menu_pressed)
	exit_button.pressed.connect(func() -> void: get_tree().quit())
	guide_button.pressed.connect(func() -> void: pause_guide_panel.visible = true)
	close_guide_button.pressed.connect(func() -> void: pause_guide_panel.visible = false)

	# Setup Barricade buttons
	confirm_barricade_btn.pressed.connect(_on_confirm_barricade)
	cancel_barricade_btn.pressed.connect(_on_cancel_barricade)

	call_deferred("_connect_player")

func _connect_player() -> void:
	var player: PlayerController = GameManager.player_character as PlayerController
	if player and player.interaction_ray:
		player.interaction_ray.interaction_prompt_changed.connect(_on_interaction_prompt_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if barricade_dialog.visible:
			_close_barricade_dialog()
		else:
			toggle_pause()

func toggle_pause() -> void:
	if GameManager.current_state == GameManager.GameState.GAMEOVER or GameManager.current_state == GameManager.GameState.VICTORY:
		return
	if barricade_dialog.visible:
		return
	var is_paused: bool = not get_tree().paused
	get_tree().paused = is_paused
	pause_menu.visible = is_paused
	if is_paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		pause_guide_panel.visible = false

func _on_main_menu_pressed() -> void:
	barricade_dialog.visible = false
	get_tree().paused = false
	GameManager.current_state = GameManager.GameState.MENU
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _on_barricade_warning(door_node: Node, player_node: Node) -> void:
	pending_barricade_door = door_node
	pending_barricade_player = player_node
	barricade_dialog.visible = true
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
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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
	_show_act_banner(num, title)

func _show_act_banner(num: int, _title: String) -> void:
	if banner_tween:
		banner_tween.kill()

	act_banner.visible = true
	act_banner.modulate.a = 1.0

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

	banner_tween = create_tween()
	banner_tween.tween_interval(4.5)
	banner_tween.tween_property(act_banner, "modulate:a", 0.0, 1.2)
	banner_tween.tween_callback(func() -> void: act_banner.visible = false)

func _on_objective_updated(id: String, text: String, current: int, required: int, is_completed: bool) -> void:
	var label: Label = null
	if objective_labels.has(id):
		label = objective_labels[id]
	else:
		label = Label.new()
		label.add_theme_font_size_override("font_size", 16)
		objectives_container.add_child(label)
		objective_labels[id] = label
		
	var status_icon: String = "✅" if is_completed else "◻️"
	var progress_str: String = " (%d/%d)" % [current, required] if required > 1 else ""
	label.text = "%s %s%s" % [status_icon, text, progress_str]
	label.modulate = Color(0.6, 1.0, 0.6) if is_completed else Color(1, 1, 1)

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
