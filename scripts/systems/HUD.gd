class_name HUD
extends CanvasLayer

const INVENTORY_SLOT_UI_SCRIPT = preload("res://scripts/ui/InventorySlotUI.gd")
const TUTORIAL_OVERLAY_SCRIPT = preload("res://scripts/systems/TutorialOverlay.gd")
const HORROR_TITLE_FONT: Font = preload("res://assets/fonts/HorrorTitle.ttf")

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
var pause_settings_container: CenterContainer
var pause_settings_scroll: ScrollContainer
var pause_graphics_option: OptionButton
var _pause_drag_scrolling: bool = false
var _pause_drag_start_y: float = 0.0
var _pause_drag_last_y: float = 0.0
var _pause_drag_moved: bool = false
var _pause_drag_button: BaseButton = null
var objective_texts: Dictionary = {}
var mission_panel: PanelContainer
var mission_title: Label
var mission_body: Label
var mission_tween: Tween
var dialog_panel: PanelContainer
var exit_confirm_overlay: ColorRect
var exit_panel: PanelContainer
var mobile_editor_active: bool = false
var editor_touch_index: int = -1
var editor_drag_target: Control = null
var editor_drag_offset: Vector2 = Vector2.ZERO
var editor_hint_label: Label
var editor_done_button: Button
var descent_camera_tween: Tween
var descent_cutscene_overlay: Control = null
var bottom_left_panel: PanelContainer = null
var last_synced_battery_pct: int = -1

# Inventory Overlay Nodes
var inventory_overlay: ColorRect
var inventory_modal_panel: PanelContainer
var inventory_storage_slots: Array = []
var inventory_hotbar_slots: Array = []
var selected_swap_slot: int = -1
var cached_inventory_slots: Array = []
var hud_bag_button: Button = null

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
	_style_horror_hud_containers()
	_style_pause_and_dialogs()
	_build_jumpscare_face()
	_build_dialog_label()
	_build_mission_card()
	_build_exit_confirm()
	_build_desktop_hints()
	_build_inventory_overlay()
	_build_hud_bag_button()
	if TUTORIAL_OVERLAY_SCRIPT:
		add_child(TUTORIAL_OVERLAY_SCRIPT.new())
	_initialize_objectives_immediate()
	SettingsManager.call_deferred("_apply_brightness_overlay")
	if is_instance_valid(GameManager.player_character):
		SignalBus.flashlight_battery_changed.emit(GameManager.player_character.flashlight_battery, 100.0)
		var player_node: PlayerController = GameManager.player_character as PlayerController
		if player_node and player_node.inventory_system:
			_on_inventory_updated(player_node.inventory_system.slots)
			_on_item_equipped(player_node.inventory_system.active_slot, player_node.inventory_system.get_equipped_item())
	act_banner.visible = false
	pause_menu.visible = false
	barricade_dialog.visible = false

	# Setup Pause buttons
	resume_button.pressed.connect(toggle_pause)
	exit_button.text = "Kembali ke Menu Utama"
	exit_button.pressed.connect(_show_exit_confirm)
	settings_button.text = "Pengaturan"
	settings_button.pressed.connect(_open_pause_settings)
	_build_pause_settings_panel()
	_layout_pause_settings_panel()

	# Setup Barricade buttons
	confirm_barricade_btn.pressed.connect(_on_confirm_barricade)
	cancel_barricade_btn.pressed.connect(_on_cancel_barricade)

	get_viewport().size_changed.connect(_apply_mobile_hud_layout)
	get_viewport().size_changed.connect(_layout_pause_settings_panel)
	call_deferred("_connect_player")
	call_deferred("_setup_mobile_controls")
	call_deferred("_apply_mobile_hud_layout")
	get_viewport().size_changed.connect(_apply_overlay_layouts)
	call_deferred("_apply_overlay_layouts")

func _style_horror_hud_containers() -> void:
	var touch: bool = _is_touch_device()
	var tl_vbox: VBoxContainer = top_left.get_node_or_null("VBox") as VBoxContainer
	var tl_sep: Control = top_left.get_node_or_null("VBox/HSeparator") as Control

	clock_label.add_theme_font_size_override("font_size", 20 if touch else 28)
	clock_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.80, 1.0))
	clock_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	clock_label.add_theme_constant_override("outline_size", 5)

	act_label.add_theme_font_size_override("font_size", 14 if touch else 19)
	act_label.add_theme_color_override("font_color", Color(0.95, 0.70, 0.28, 1.0))
	act_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	act_label.add_theme_constant_override("outline_size", 4)

	if tl_sep:
		tl_sep.visible = true
		var sep_style := StyleBoxFlat.new()
		sep_style.bg_color = Color(0.72, 0.16, 0.18, 0.88)
		sep_style.content_margin_top = 1.0
		sep_style.content_margin_bottom = 1.0
		tl_sep.add_theme_stylebox_override("separator", sep_style)
		if tl_vbox and objectives_container:
			tl_vbox.move_child(clock_label, 0)
			tl_vbox.move_child(act_label, 1)
			tl_vbox.move_child(tl_sep, 2)
			tl_vbox.move_child(objectives_container, 3)

	bottom_right.visible = false
	sanity_val.visible = true
	stamina_val.visible = true
	battery_val.visible = true

	var stats_vbox: VBoxContainer = bottom_left.get_node_or_null("VBox") as VBoxContainer
	if stats_vbox:
		stats_vbox.add_theme_constant_override("separation", 5)
		for container_name: String in ["SanityContainer", "StaminaContainer", "BatteryContainer"]:
			var row: HBoxContainer = stats_vbox.get_node_or_null(container_name) as HBoxContainer
			if row:
				row.add_theme_constant_override("separation", 6)
				var row_label: Label = row.get_child(0) as Label
				var row_bar: ProgressBar = row.get_child(1) as ProgressBar
				var row_val: Label = row.get_child(2) as Label
				if row_label:
					row_label.custom_minimum_size.x = 68.0
					row_label.add_theme_font_size_override("font_size", 11 if touch else 13)
					row_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
					row_label.add_theme_constant_override("outline_size", 3)
				if row_bar:
					row_bar.custom_minimum_size = Vector2(84.0, 11.0) if touch else Vector2(135.0, 13.0)
				if row_val:
					row_val.visible = true
					row_val.custom_minimum_size.x = 38.0
					row_val.add_theme_font_size_override("font_size", 10 if touch else 12)
					row_val.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
					row_val.add_theme_constant_override("outline_size", 3)

	stare_warning.add_theme_font_override("font", HORROR_TITLE_FONT)
	stare_warning.add_theme_font_size_override("font_size", 17)
	var pause_title: Label = pause_menu.get_node_or_null("Center/Panel/VBox/Title") as Label
	if pause_title:
		HorrorTheme.style_label(pause_title, "headline-md", HorrorTheme.PRIMARY, 20)

	if not touch:
		slots_container.add_theme_constant_override("separation", 8)
		bottom_center.offset_left = -228.0
		bottom_center.offset_right = 228.0
		bottom_center.offset_top = -94.0
		bottom_center.offset_bottom = -14.0

	for i: int in range(slots_container.get_child_count()):
		var slot_node: Node = slots_container.get_child(i)
		if slot_node is PanelContainer:
			var panel: PanelContainer = slot_node as PanelContainer
			var slot_dim: Vector2 = Vector2(62.0, 62.0) if touch else Vector2(80.0, 80.0)
			panel.custom_minimum_size = slot_dim
			panel.size = slot_dim
			panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_apply_slot_horror_style(panel, i == 0)
			var vbox: VBoxContainer = panel.get_node_or_null("VBox") as VBoxContainer
			if vbox:
				vbox.add_theme_constant_override("separation", 1)
			var item_lbl: Label = panel.get_node_or_null("VBox/ItemName") as Label
			if item_lbl:
				item_lbl.clip_text = true
				item_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				item_lbl.max_lines_visible = 2
				item_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				item_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				item_lbl.custom_minimum_size = Vector2(54.0, 22.0) if touch else Vector2(72.0, 26.0)
				HorrorTheme.style_label(item_lbl, "label-sm", HorrorTheme.ON_SURFACE, 8 if touch else 10)
			var key_lbl: Label = panel.get_node_or_null("VBox/Key") as Label
			if key_lbl:
				HorrorTheme.style_label(key_lbl, "mono-sm", HorrorTheme.PRIMARY if i == 0 else HorrorTheme.OUTLINE, 8 if touch else 9)
			var qty_lbl: Label = panel.get_node_or_null("VBox/Qty") as Label
			if qty_lbl:
				HorrorTheme.style_label(qty_lbl, "mono-sm", HorrorTheme.RELIC_BRASS, 8 if touch else 9)

func _apply_slot_horror_style(panel: PanelContainer, is_active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(HorrorTheme.SECONDARY_CONTAINER.r, HorrorTheme.SECONDARY_CONTAINER.g, HorrorTheme.SECONDARY_CONTAINER.b, 0.94) if is_active else Color(HorrorTheme.SURFACE_LOWEST.r, HorrorTheme.SURFACE_LOWEST.g, HorrorTheme.SURFACE_LOWEST.b, 0.90)
	style.border_color = HorrorTheme.ACCENT if is_active else HorrorTheme.OUTLINE_VARIANT
	style.set_border_width_all(2 if is_active else 1)
	if not is_active:
		style.border_width_bottom = 2
	style.set_corner_radius_all(2)
	style.shadow_color = Color(HorrorTheme.SCRIM.r, HorrorTheme.SCRIM.g, HorrorTheme.SCRIM.b, 0.65)
	style.shadow_size = 6 if is_active else 3
	style.content_margin_left = 3.0
	style.content_margin_right = 3.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	panel.add_theme_stylebox_override("panel", style)
	panel.modulate = Color.WHITE
	HorrorTheme.attach_corner_ornaments(
		panel,
		HorrorTheme.PRIMARY if is_active else Color(HorrorTheme.OUTLINE_VARIANT.r, HorrorTheme.OUTLINE_VARIANT.g, HorrorTheme.OUTLINE_VARIANT.b, 0.55),
		7.0 if is_active else 5.0,
		1.5 if is_active else 1.0,
		3.0,
		is_active
	)
	var key_lbl: Label = panel.get_node_or_null("VBox/Key") as Label
	if key_lbl:
		key_lbl.add_theme_color_override("font_color", HorrorTheme.PRIMARY if is_active else HorrorTheme.OUTLINE)
	var item_lbl: Label = panel.get_node_or_null("VBox/ItemName") as Label
	if item_lbl:
		var is_empty: bool = item_lbl.text == "[Kosong]" or item_lbl.text.is_empty()
		if is_empty:
			item_lbl.add_theme_color_override("font_color", Color(HorrorTheme.OUTLINE.r, HorrorTheme.OUTLINE.g, HorrorTheme.OUTLINE.b, 0.72))
		else:
			item_lbl.add_theme_color_override("font_color", HorrorTheme.ON_PRIMARY_CONTAINER if is_active else HorrorTheme.ON_SURFACE)
	var qty_lbl: Label = panel.get_node_or_null("VBox/Qty") as Label
	if qty_lbl:
		qty_lbl.add_theme_color_override("font_color", HorrorTheme.PRIMARY if is_active else HorrorTheme.RELIC_BRASS)

func _initialize_objectives_immediate() -> void:
	var time_str: String = "%02d:%02d" % [GameManager.current_hour, GameManager.current_minute]
	clock_label.text = time_str + " WIB"
	clock_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.80, 1.0))
	act_label.text = GameManager.get_current_act_title()
	act_label.add_theme_color_override("font_color", Color(0.95, 0.70, 0.28, 1.0))
	_populate_current_act_objectives()

func _populate_current_act_objectives() -> void:
	for obj: Dictionary in GameManager.get_current_objectives_data():
		_on_objective_updated(
			str(obj.get("id", "")),
			str(obj.get("text", "")),
			int(obj.get("current", 0)),
			int(obj.get("required", 1)),
			bool(obj.get("completed", false))
		)

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
	if event.is_action_pressed("toggle_inventory") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_TAB or event.keycode == KEY_B or event.keycode == KEY_I)):
		if not pause_menu.visible and not barricade_dialog.visible and GameManager.current_state == GameManager.GameState.PLAYING:
			toggle_inventory()
			return

	if event.is_action_pressed("pause"):
		if exit_confirm_overlay and exit_confirm_overlay.visible:
			exit_confirm_overlay.visible = false
			if pause_menu.visible:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _is_touch_device() else Input.MOUSE_MODE_CAPTURED
		elif pause_settings_container and pause_settings_container.visible:
			_pause_settings_container_hide()
			pause_menu.get_node("Center").visible = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif barricade_dialog.visible:
			_close_barricade_dialog()
		elif inventory_overlay and inventory_overlay.visible:
			toggle_inventory()
		else:
			toggle_pause()

func toggle_pause() -> void:
	if descent_cutscene_overlay and is_instance_valid(descent_cutscene_overlay) and descent_cutscene_overlay.visible:
		return
	if mobile_editor_active:
		_finish_mobile_editor()
	if inventory_overlay and inventory_overlay.visible:
		toggle_inventory()
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
		GameManager.save_active_run()
		joystick_vector = Vector2.ZERO
		var player: PlayerController = GameManager.player_character as PlayerController
		if player:
			player.set_virtual_move(Vector2.ZERO)
			player.set_virtual_sprint(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var pause_panel: Control = pause_menu.get_node_or_null("Center/Panel") as Control
		if pause_panel:
			HorrorTheme.animate_surface_enter(pause_panel)
	else:
		if pause_settings_container:
			pause_settings_container.visible = false
		pause_menu.get_node("Center").visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _is_touch_device() else Input.MOUSE_MODE_CAPTURED

func _style_pause_and_dialogs() -> void:
	var dim_overlay: ColorRect = pause_menu.get_node_or_null("DimOverlay") as ColorRect
	if dim_overlay:
		dim_overlay.color = Color(HorrorTheme.SCRIM.r, HorrorTheme.SCRIM.g, HorrorTheme.SCRIM.b, 0.65)
	var pause_panel: PanelContainer = pause_menu.get_node_or_null("Center/Panel") as PanelContainer
	if pause_panel:
		pause_panel.add_theme_stylebox_override("panel", HorrorTheme.make_panel_style(HorrorTheme.SURFACE, HorrorTheme.OUTLINE_VARIANT, 4, 2, 24, 22))
		HorrorTheme.attach_corner_ornaments(pause_panel, HorrorTheme.ACCENT, 12.0, 1.8, 5.0, true)
	var pause_vbox: VBoxContainer = pause_menu.get_node_or_null("Center/Panel/VBox") as VBoxContainer
	if pause_vbox:
		pause_vbox.add_theme_constant_override("separation", 12)
	var pause_sep: HSeparator = pause_menu.get_node_or_null("Center/Panel/VBox/HSeparator") as HSeparator
	if pause_sep:
		var sep_s := StyleBoxFlat.new()
		sep_s.bg_color = HorrorTheme.PRIMARY_CONTAINER
		sep_s.content_margin_top = 1.0
		pause_sep.add_theme_stylebox_override("separator", sep_s)
	if resume_button:
		resume_button.text = "LANJUTKAN PERMAINAN [ESC]"
		HorrorTheme.style_button(resume_button, "primary", 13, true)
	if settings_button:
		settings_button.text = "PENGATURAN"
		HorrorTheme.style_button(settings_button, "secondary", 13, true)
	if exit_button:
		exit_button.text = "KEMBALI KE MENU UTAMA"
		HorrorTheme.style_button(exit_button, "danger", 13, true)

	if barricade_dialog:
		barricade_dialog.add_theme_stylebox_override("panel", HorrorTheme.make_panel_style(HorrorTheme.SURFACE, HorrorTheme.ACCENT, 4, 2))
		HorrorTheme.attach_corner_ornaments(barricade_dialog, HorrorTheme.PRIMARY, 12.0, 1.8, 5.0, true)
		var b_title: Label = barricade_dialog.get_node_or_null("Margin/VBox/Title") as Label
		if b_title:
			HorrorTheme.style_label(b_title, "headline-md", HorrorTheme.PRIMARY, 17)
		var b_msg: Label = barricade_dialog.get_node_or_null("Margin/VBox/Message") as Label
		if b_msg:
			HorrorTheme.style_label(b_msg, "body-md", HorrorTheme.ON_SURFACE, 14)
		if confirm_barricade_btn:
			confirm_barricade_btn.text = "TETAP PALANG PINTU"
			HorrorTheme.style_button(confirm_barricade_btn, "primary", 13, true)
		if cancel_barricade_btn:
			cancel_barricade_btn.text = "BATAL"
			HorrorTheme.style_button(cancel_barricade_btn, "secondary", 13, true)

func _build_pause_settings_panel() -> void:
	pause_settings_container = CenterContainer.new()
	pause_settings_container.name = "PauseSettingsContainer"
	pause_settings_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_settings_container.offset_left = 0.0
	pause_settings_container.offset_top = 0.0
	pause_settings_container.offset_right = 0.0
	pause_settings_container.offset_bottom = 0.0
	pause_settings_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_settings_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pause_settings_container.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_settings_container.visible = false
	pause_settings_container.z_index = 20
	pause_settings_container.z_as_relative = false
	self.add_child(pause_settings_container)
	pause_settings_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_settings_container.z_index = 1000
	pause_settings_panel = PanelContainer.new()
	pause_settings_panel.name = "PauseSettingsPanel"
	pause_settings_panel.custom_minimum_size = Vector2(460.0, 460.0)
	pause_settings_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pause_settings_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pause_settings_panel.add_theme_stylebox_override("panel", HorrorTheme.make_panel_style(HorrorTheme.SURFACE, HorrorTheme.OUTLINE_VARIANT, 4, 2))
	HorrorTheme.attach_corner_ornaments(pause_settings_panel, HorrorTheme.ACCENT, 12.0, 1.8, 5.0, true)
	pause_settings_container.add_child(pause_settings_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	pause_settings_panel.add_child(margin)
	pause_settings_scroll = ScrollContainer.new()
	pause_settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pause_settings_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	HorrorTheme.style_scroll_container(pause_settings_scroll)
	margin.add_child(pause_settings_scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_settings_scroll.add_child(box)
	var title := Label.new()
	title.text = "PENGATURAN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HorrorTheme.style_label(title, "headline-md", HorrorTheme.ON_SURFACE, 20)
	box.add_child(title)
	box.add_child(HorrorTheme.create_ritual_divider("◆", HorrorTheme.ACCENT))
	_add_pause_slider(box, "Sensitivitas Mouse", SettingsManager.mouse_sensitivity * 100.0, 25.0, 200.0, func(v: float) -> void: SettingsManager.set_mouse_sensitivity(v / 100.0))
	_add_pause_slider(box, "Sensitivitas Kamera", SettingsManager.camera_sensitivity * 100.0, 25.0, 200.0, func(v: float) -> void: SettingsManager.set_camera_sensitivity(v / 100.0))
	_add_pause_slider(box, "Kecerahan", SettingsManager.brightness * 100.0, 50.0, 150.0, func(v: float) -> void: SettingsManager.set_brightness(v / 100.0))
	var quality := OptionButton.new()
	pause_graphics_option = quality
	quality.add_item("Grafik: Otomatis (Perangkat)")
	quality.add_item("Grafik: Low")
	quality.add_item("Grafik: Medium")
	quality.add_item("Grafik: High")
	quality.select({"auto": 0, "low": 1, "medium": 2, "high": 3}.get(SettingsManager.graphics_quality, 0))
	quality.tooltip_text = "Otomatis menggunakan preset %s berdasarkan perangkat ini" % SettingsManager.recommended_graphics_quality.capitalize()
	quality.item_selected.connect(func(index: int) -> void: SettingsManager.set_graphics_quality(["auto", "low", "medium", "high"][index]))
	HorrorTheme.style_option_button(quality)
	box.add_child(quality)
	var auto_update := CheckButton.new()
	auto_update.text = "Unduh update otomatis"
	auto_update.button_pressed = SettingsManager.auto_update
	auto_update.toggled.connect(SettingsManager.set_auto_update)
	HorrorTheme.style_check_button(auto_update)
	box.add_child(auto_update)
	if _is_touch_device():
		_add_pause_slider(box, "Ukuran tombol mobile", SettingsManager.mobile_button_scale * 100.0, 75.0, 150.0, func(v: float) -> void:
			SettingsManager.set_mobile_button_scale(v / 100.0)
			_layout_touch_controls()
		)
		_add_pause_slider(box, "Ukuran joystick", SettingsManager.mobile_joystick_scale * 100.0, 80.0, 140.0, func(v: float) -> void:
			SettingsManager.set_mobile_joystick_scale(v / 100.0)
			_layout_touch_controls()
		)
		var editor_button := Button.new()
		editor_button.text = "EDITOR POSISI TOMBOL MOBILE"
		editor_button.custom_minimum_size.y = 42.0
		HorrorTheme.style_button(editor_button, "secondary", 12, true)
		editor_button.pressed.connect(_start_mobile_editor)
		box.add_child(editor_button)
		var reset_layout := Button.new()
		reset_layout.text = "RESET TATA LETAK MOBILE"
		HorrorTheme.style_button(reset_layout, "ghost", 12, true)
		reset_layout.pressed.connect(func() -> void:
			SettingsManager.reset_mobile_control_layout()
			_layout_touch_controls()
		)
		box.add_child(reset_layout)
	var close := Button.new()
	close.text = "KEMBALI KE JEDA"
	close.custom_minimum_size.y = 42.0
	HorrorTheme.style_button(close, "primary", 13, true)
	close.pressed.connect(func() -> void:
		_pause_settings_container_hide()
		pause_menu.get_node("Center").visible = true
	)
	box.add_child(close)

func _pause_settings_container_hide() -> void:
	if pause_settings_container:
		pause_settings_container.visible = false

func _layout_pause_settings_panel() -> void:
	if not pause_settings_panel or not pause_settings_scroll or not pause_settings_container:
		return
	pause_settings_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_width: float = maxf(180.0, minf(460.0, view_size.x - 24.0))
	var panel_height: float = maxf(220.0, minf(560.0, view_size.y - 24.0))
	var panel_size := Vector2(panel_width, panel_height)
	pause_settings_panel.custom_minimum_size = panel_size
	pause_settings_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pause_settings_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pause_settings_scroll.custom_minimum_size = Vector2(panel_width - 36.0, maxf(180.0, panel_height - 82.0))

func _add_pause_slider(parent: VBoxContainer, caption: String, initial: float, minimum: float, maximum: float, callback: Callable) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = "%s: %d%%" % [caption, int(round(initial))]
	HorrorTheme.style_label(label, "label-sm", HorrorTheme.ON_SURFACE, 13)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 5.0
	slider.value = initial
	HorrorTheme.style_slider(slider)
	slider.value_changed.connect(func(value: float) -> void:
		label.text = "%s: %d%%" % [caption, int(round(value))]
		callback.call(value)
	)
	row.add_child(slider)
	parent.add_child(row)

func _open_pause_settings() -> void:
	pause_menu.get_node("Center").visible = false
	if pause_settings_container:
		pause_settings_container.visible = true
		pause_settings_container.move_to_front()
		pause_settings_container.z_index = 1000
		_layout_pause_settings_panel()
		HorrorTheme.animate_surface_enter(pause_settings_panel)
		call_deferred("_finish_open_pause_settings")

func _finish_open_pause_settings() -> void:
	if not is_instance_valid(pause_settings_container) or not pause_menu.visible:
		return
	pause_menu.get_node("Center").visible = false
	pause_settings_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_settings_container.offset_left = 0.0
	pause_settings_container.offset_top = 0.0
	pause_settings_container.offset_right = 0.0
	pause_settings_container.offset_bottom = 0.0
	pause_settings_container.z_index = 1000
	pause_settings_container.visible = true
	_layout_pause_settings_panel()

func _on_main_menu_pressed() -> void:
	GameManager.save_active_run()
	if mobile_editor_active:
		_finish_mobile_editor()
	if desktop_hint_panel:
		desktop_hint_panel.visible = false
	if exit_confirm_overlay:
		exit_confirm_overlay.visible = false
	barricade_dialog.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.current_state = GameManager.GameState.MENU
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _on_barricade_warning(door_node: Node, player_node: Node) -> void:
	pending_barricade_door = door_node
	pending_barricade_player = player_node
	barricade_dialog.visible = true
	HorrorTheme.animate_surface_enter(barricade_dialog)
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
	var door_node: Node = pending_barricade_door
	var player_node: Node = pending_barricade_player
	# Tutup dialog & lepaskan pause terlebih dahulu agar jika pintu ini adalah
	# barikade ke-3 yang memicu transisi Babak II & cutscene Lampor, SceneTree sudah tidak paused.
	_close_barricade_dialog()
	if door_node and is_instance_valid(door_node):
		if door_node.has_method("confirm_barricade"):
			door_node.confirm_barricade(player_node)

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
	dialog_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

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
	mission_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mission_panel.add_child(box)
	mission_title = Label.new()
	mission_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_title.add_theme_font_override("font", HORROR_TITLE_FONT)
	mission_title.add_theme_font_size_override("font_size", 18)
	mission_title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	mission_title.add_theme_constant_override("outline_size", 4)
	box.add_child(mission_title)
	var heading := Label.new()
	heading.text = "MISI"
	heading.visible = false
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", Color(0.85, 0.7, 0.4, 1.0))
	heading.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	heading.add_theme_constant_override("outline_size", 4)
	box.add_child(heading)
	mission_body = Label.new()
	mission_body.visible = false
	mission_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_body.add_theme_font_size_override("font_size", 17)
	mission_body.add_theme_color_override("font_color", Color(0.95, 0.93, 0.9, 1.0))
	mission_body.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	mission_body.add_theme_constant_override("outline_size", 4)
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
	if descent_cutscene_overlay and is_instance_valid(descent_cutscene_overlay):
		return
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
	mission_tween.tween_property(mission_panel, "modulate:a", 1.0, 0.25)
	mission_tween.tween_interval(2.4)
	mission_tween.tween_property(mission_panel, "modulate:a", 0.0, 0.5)
	mission_tween.tween_callback(func() -> void: mission_panel.visible = false)

func _make_exit_button(text_value: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HorrorTheme.style_button(button, "primary" if primary else "secondary", 13, true)
	return button

func _build_exit_confirm() -> void:
	exit_confirm_overlay = ColorRect.new()
	exit_confirm_overlay.name = "ExitConfirmOverlay"
	exit_confirm_overlay.color = Color(HorrorTheme.SCRIM.r, HorrorTheme.SCRIM.g, HorrorTheme.SCRIM.b, 0.88)
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
	exit_panel.add_theme_stylebox_override("panel", HorrorTheme.make_panel_style(HorrorTheme.SURFACE, HorrorTheme.OUTLINE_VARIANT, 4, 2, 24, 22))
	HorrorTheme.attach_corner_ornaments(exit_panel, HorrorTheme.ACCENT, 12.0, 1.8, 5.0, true)
	center.add_child(exit_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	exit_panel.add_child(box)
	var title := Label.new()
	title.text = "KEMBALI KE MENU UTAMA?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HorrorTheme.style_label(title, "headline-md", HorrorTheme.PRIMARY, 19)
	box.add_child(title)
	box.add_child(HorrorTheme.create_ritual_divider("◆", HorrorTheme.ACCENT))
	var message := Label.new()
	message.text = "Yakin ingin kembali ke menu utama?\nProgres tersimpan otomatis setiap 5 detik dan dapat dilanjutkan dari menu utama."
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.custom_minimum_size.x = 360.0
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	HorrorTheme.style_label(message, "body-md", HorrorTheme.ON_SURFACE, 14)
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
	var confirm := _make_exit_button("YA, KE MENU UTAMA", true)
	confirm.pressed.connect(_on_main_menu_pressed)
	buttons.add_child(confirm)

func _show_exit_confirm() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_apply_overlay_layouts()
	exit_confirm_overlay.visible = true
	HorrorTheme.animate_surface_enter(exit_panel)

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
	if inventory_modal_panel:
		var slot_dim: float = clampf((minf(view_size.y, 720.0) - 196.0) / 4.2, 44.0, 62.0)
		var slot_vec := Vector2(slot_dim, slot_dim)
		for s_node: Variant in inventory_storage_slots:
			if s_node is PanelContainer:
				(s_node as PanelContainer).custom_minimum_size = slot_vec
		for h_node: Variant in inventory_hotbar_slots:
			if h_node is PanelContainer:
				(h_node as PanelContainer).custom_minimum_size = slot_vec
		var panel_w: float = minf(maxf(380.0, slot_dim * 5.0 + 68.0), view_size.x - 24.0)
		inventory_modal_panel.custom_minimum_size = Vector2(panel_w, 0.0)
		inventory_modal_panel.reset_size()

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

	var run_button := _make_touch_button("run")
	run_button.button_down.connect(_on_touch_run_down)
	run_button.button_up.connect(_on_touch_run_up)
	var interact_button := _make_touch_button("interact")
	interact_button.pressed.connect(_on_touch_interact)
	var flashlight_button := _make_touch_button("flashlight")
	flashlight_button.pressed.connect(_on_touch_flashlight)
	var pause_button := _make_touch_button("pause")
	pause_button.pressed.connect(toggle_pause)
	var bag_button := _make_touch_button("bag")
	bag_button.pressed.connect(toggle_inventory)
	touch_buttons.append(run_button)
	touch_buttons.append(interact_button)
	touch_buttons.append(flashlight_button)
	touch_buttons.append(pause_button)
	touch_buttons.append(bag_button)
	for button: Button in touch_buttons:
		touch_root.add_child(button)
	get_viewport().size_changed.connect(_layout_touch_controls)
	_layout_touch_controls()

func _make_touch_button(icon_id: String) -> Button:
	var button := Button.new()
	button.text = ""
	button.set_meta("touch_icon", icon_id)
	button.focus_mode = Control.FOCUS_NONE
	var is_utility: bool = icon_id in ["pause", "bag"]

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(HorrorTheme.SURFACE_LOW.r, HorrorTheme.SURFACE_LOW.g, HorrorTheme.SURFACE_LOW.b, 0.86) if is_utility else Color(HorrorTheme.SURFACE.r, HorrorTheme.SURFACE.g, HorrorTheme.SURFACE.b, 0.86)
	normal.border_color = HorrorTheme.OUTLINE if is_utility else HorrorTheme.ACCENT
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	normal.shadow_color = Color(HorrorTheme.SCRIM.r, HorrorTheme.SCRIM.g, HorrorTheme.SCRIM.b, 0.65)
	normal.shadow_size = 5

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(HorrorTheme.PRIMARY_CONTAINER.r, HorrorTheme.PRIMARY_CONTAINER.g, HorrorTheme.PRIMARY_CONTAINER.b, 0.96)
	pressed.border_color = HorrorTheme.PRIMARY
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", pressed)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)
	HorrorTheme.attach_corner_ornaments(
		button,
		HorrorTheme.ON_SURFACE_VARIANT if is_utility else HorrorTheme.PRIMARY,
		6.0,
		1.4,
		3.0,
		false
	)
	button.draw.connect(_draw_touch_button_icon.bind(button, icon_id))
	return button

func _draw_touch_button_icon(btn: Button, icon_id: String) -> void:
	if not is_instance_valid(btn):
		return
	var s: Vector2 = btn.size
	var c: Vector2 = s * 0.5
	var u: float = minf(s.x, s.y)
	var col: Color = HorrorTheme.ON_PRIMARY_CONTAINER if btn.button_pressed else HorrorTheme.ON_SURFACE
	var accent_col: Color = HorrorTheme.PRIMARY
	var w: float = maxf(2.0, u * 0.045)

	match icon_id:
		"run":
			# Ikon siluet pelari + garis kecepatan (tanpa huruf/emoji)
			btn.draw_circle(c + Vector2(u * 0.09, -u * 0.22), u * 0.065, col)
			btn.draw_line(c + Vector2(u * 0.06, -u * 0.14), c + Vector2(-u * 0.05, u * 0.05), col, w * 1.15)
			btn.draw_line(c + Vector2(u * 0.03, -u * 0.11), c + Vector2(u * 0.19, -u * 0.05), col, w)
			btn.draw_line(c + Vector2(u * 0.19, -u * 0.05), c + Vector2(u * 0.24, -u * 0.15), col, w)
			btn.draw_line(c + Vector2(u * 0.03, -u * 0.11), c + Vector2(-u * 0.15, -u * 0.07), col, w)
			btn.draw_line(c + Vector2(-u * 0.05, u * 0.05), c + Vector2(u * 0.14, u * 0.12), col, w * 1.1)
			btn.draw_line(c + Vector2(u * 0.14, u * 0.12), c + Vector2(u * 0.09, u * 0.26), col, w)
			btn.draw_line(c + Vector2(-u * 0.05, u * 0.05), c + Vector2(-u * 0.20, u * 0.21), col, w * 1.1)
			btn.draw_line(c + Vector2(-u * 0.28, -u * 0.16), c + Vector2(-u * 0.14, -u * 0.16), accent_col, w * 0.85)
			btn.draw_line(c + Vector2(-u * 0.30, -u * 0.02), c + Vector2(-u * 0.18, -u * 0.02), accent_col, w * 0.85)
		"interact":
			# Ikon telapak tangan meraih / interaksi
			var palm := Rect2(c + Vector2(-u * 0.13, -u * 0.02), Vector2(u * 0.26, u * 0.22))
			btn.draw_rect(palm, col, true)
			for i: int in range(4):
				var fx: float = -u * 0.11 + float(i) * (u * 0.072)
				var fh: float = u * (0.19 if (i == 1 or i == 2) else 0.15)
				btn.draw_line(c + Vector2(fx, -u * 0.02), c + Vector2(fx, -u * 0.02 - fh), col, w * 1.1)
			btn.draw_line(c + Vector2(-u * 0.13, u * 0.08), c + Vector2(-u * 0.23, -u * 0.02), col, w * 1.15)
			btn.draw_arc(c, u * 0.33, -0.45, 0.45, 10, accent_col, w * 0.8, true)
			btn.draw_arc(c, u * 0.33, PI - 0.45, PI + 0.45, 10, accent_col, w * 0.8, true)
		"flashlight":
			# Ikon senter + berkas sorot cahaya
			var handle := Rect2(c + Vector2(-u * 0.28, -u * 0.07), Vector2(u * 0.22, u * 0.14))
			btn.draw_rect(handle, col, true)
			var head_poly := PackedVector2Array([
				c + Vector2(-u * 0.06, -u * 0.07),
				c + Vector2(u * 0.05, -u * 0.14),
				c + Vector2(u * 0.05, u * 0.14),
				c + Vector2(-u * 0.06, u * 0.07)
			])
			btn.draw_colored_polygon(head_poly, col)
			btn.draw_line(c + Vector2(u * 0.10, -u * 0.10), c + Vector2(u * 0.28, -u * 0.20), accent_col, w)
			btn.draw_line(c + Vector2(u * 0.11, 0.0), c + Vector2(u * 0.30, 0.0), accent_col, w)
			btn.draw_line(c + Vector2(u * 0.10, u * 0.10), c + Vector2(u * 0.28, u * 0.20), accent_col, w)
		"pause":
			# Ikon dua bilah jeda geometris
			var bar_w: float = u * 0.10
			var bar_h: float = u * 0.38
			btn.draw_rect(Rect2(c.x - u * 0.14, c.y - bar_h * 0.5, bar_w, bar_h), col, true)
			btn.draw_rect(Rect2(c.x + u * 0.04, c.y - bar_h * 0.5, bar_w, bar_h), col, true)
		"bag":
			# Ikon tas bekal (satchel) dengan tutup & gesper
			var bag_rect := Rect2(c + Vector2(-u * 0.22, -u * 0.12), Vector2(u * 0.44, u * 0.34))
			btn.draw_rect(bag_rect, col, false, w)
			btn.draw_arc(c + Vector2(0.0, -u * 0.12), u * 0.11, PI, TAU, 12, col, w, true)
			btn.draw_line(c + Vector2(-u * 0.22, u * 0.01), c + Vector2(u * 0.22, u * 0.01), col, w * 0.9)
			btn.draw_rect(Rect2(c + Vector2(-u * 0.05, -u * 0.03), Vector2(u * 0.10, u * 0.10)), accent_col, true)
		"done":
			# Ikon centang selesai
			var pts := PackedVector2Array([
				c + Vector2(-u * 0.20, u * 0.02),
				c + Vector2(-u * 0.05, u * 0.17),
				c + Vector2(u * 0.22, -u * 0.15)
			])
			btn.draw_polyline(pts, col, w * 1.4, true)

func _layout_touch_controls() -> void:
	if not touch_controls_enabled or not joystick_base:
		return
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var compact: bool = view_size.x < 700.0
	var joystick_size: float = (134.0 if compact else 154.0) * SettingsManager.mobile_joystick_scale
	var button_size: float = (62.0 if compact else 72.0) * SettingsManager.mobile_button_scale
	var util_size: float = (48.0 if compact else 52.0) * SettingsManager.mobile_button_scale
	var default_joystick_position := Vector2(28.0, view_size.y - joystick_size - 78.0)
	if SettingsManager.mobile_joystick_position.x >= 0.0:
		joystick_base.position = SettingsManager.mobile_joystick_position * view_size
	else:
		joystick_base.position = default_joystick_position
	joystick_base.size = Vector2(joystick_size, joystick_size)
	joystick_base.position.x = clampf(joystick_base.position.x, 12.0, maxf(12.0, view_size.x * 0.35 - joystick_size))
	joystick_base.position.y = clampf(joystick_base.position.y, 180.0, maxf(180.0, view_size.y - joystick_size - 16.0))

	var btn_gap: float = 20.0
	var x_right: float = view_size.x - button_size - 22.0
	var x_left: float = x_right - button_size - btn_gap
	var y_bottom: float = view_size.y - button_size - 82.0
	var y_top: float = y_bottom - button_size - btn_gap

	var stats_width: float = clampf(view_size.x * 0.24, 198.0, 236.0)
	var bag_x: float = view_size.x - stats_width - 26.0 - util_size
	var pause_x: float = bag_x - util_size - 14.0
	var defaults: Array[Vector2] = [
		Vector2(x_right, y_top),     # 0: run
		Vector2(x_right, y_bottom),  # 1: interact
		Vector2(x_left, y_bottom),   # 2: flashlight
		Vector2(pause_x, 16.0),      # 3: pause
		Vector2(bag_x, 16.0)         # 4: bag
	]
	var stats_forbidden := Rect2(view_size.x - stats_width - 18.0, 8.0, stats_width + 18.0, 94.0)
	var saved_positions: Array = SettingsManager.mobile_button_positions
	for i: int in range(touch_buttons.size()):
		var button: Button = touch_buttons[i]
		var target_size: Vector2 = Vector2(util_size, util_size) if i >= 3 else Vector2(button_size, button_size)
		button.size = target_size
		var button_position: Vector2 = defaults[i]
		if saved_positions.size() == touch_buttons.size() and saved_positions[i] is Vector2:
			var candidate: Vector2 = saved_positions[i] * view_size
			var candidate_rect := Rect2(candidate, target_size)
			if not stats_forbidden.intersects(candidate_rect):
				button_position = candidate
		button.position = Vector2(
			clampf(button_position.x, 8.0, maxf(8.0, view_size.x - button.size.x - 8.0)),
			clampf(button_position.y, 8.0, maxf(8.0, view_size.y - button.size.y - 8.0))
		)
		button.queue_redraw()

	for i: int in range(touch_buttons.size()):
		var rect_i := Rect2(touch_buttons[i].position - Vector2(4.0, 4.0), touch_buttons[i].size + Vector2(8.0, 8.0))
		for j: int in range(i):
			var rect_j := Rect2(touch_buttons[j].position - Vector2(4.0, 4.0), touch_buttons[j].size + Vector2(8.0, 8.0))
			if rect_i.intersects(rect_j):
				touch_buttons[i].position = defaults[i]
				break

	if editor_done_button:
		editor_done_button.position = Vector2(view_size.x - 142.0, 124.0)

func _apply_mobile_hud_layout() -> void:
	if not _is_touch_device():
		return
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var tl_width: float = clampf(view_size.x * 0.34, 260.0, 350.0)
	top_left.offset_left = 12.0
	top_left.offset_top = 12.0
	top_left.offset_right = 12.0 + tl_width
	top_left.offset_bottom = 280.0
	clock_label.add_theme_font_size_override("font_size", 20)
	act_label.add_theme_font_size_override("font_size", 14)
	for objective: Node in objectives_container.get_children():
		if objective is Label:
			var obj_lbl: Label = objective as Label
			obj_lbl.add_theme_font_size_override("font_size", 11)
			obj_lbl.custom_minimum_size.x = tl_width - 16.0
	bottom_left.anchor_left = 1.0
	bottom_left.anchor_right = 1.0
	bottom_left.anchor_top = 0.0
	bottom_left.anchor_bottom = 0.0
	bottom_left.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bottom_left.grow_vertical = Control.GROW_DIRECTION_END
	var stats_width: float = clampf(view_size.x * 0.24, 198.0, 236.0)
	bottom_left.offset_left = -stats_width - 12.0
	bottom_left.offset_top = 12.0
	bottom_left.offset_right = -12.0
	bottom_left.offset_bottom = 94.0
	bottom_left.scale = Vector2.ONE
	var stats_vbox: VBoxContainer = (bottom_left_panel.get_node("VBox") if bottom_left_panel else bottom_left.get_node("VBox")) as VBoxContainer
	stats_vbox.add_theme_constant_override("separation", 5)
	for container_name: String in ["SanityContainer", "StaminaContainer", "BatteryContainer"]:
		var row: HBoxContainer = stats_vbox.get_node(container_name) as HBoxContainer
		row.add_theme_constant_override("separation", 5)
		var row_label: Label = row.get_child(0) as Label
		var row_bar: ProgressBar = row.get_child(1) as ProgressBar
		var row_value: Label = row.get_child(2) as Label
		row_label.custom_minimum_size.x = 68.0
		row_label.add_theme_font_size_override("font_size", 11)
		row_bar.custom_minimum_size = Vector2(84.0, 11.0)
		row_value.visible = true
		row_value.custom_minimum_size.x = 34.0
		row_value.add_theme_font_size_override("font_size", 10)
	bottom_right.visible = false
	var slot_gap: float = 6.0
	slots_container.add_theme_constant_override("separation", int(slot_gap))
	var slot_size: Vector2 = Vector2(62.0, 62.0)
	for slot: Node in slots_container.get_children():
		var panel: PanelContainer = slot as PanelContainer
		panel.custom_minimum_size = slot_size
		panel.size = slot_size
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var item_lbl: Label = panel.get_node_or_null("VBox/ItemName") as Label
		if item_lbl:
			item_lbl.clip_text = true
			item_lbl.custom_minimum_size = Vector2(54.0, 22.0)
			item_lbl.max_lines_visible = 2
			item_lbl.add_theme_font_size_override("font_size", 8)
		var key_lbl: Label = panel.get_node_or_null("VBox/Key") as Label
		if key_lbl:
			key_lbl.add_theme_font_size_override("font_size", 8)
		var qty_lbl: Label = panel.get_node_or_null("VBox/Qty") as Label
		if qty_lbl:
			qty_lbl.add_theme_font_size_override("font_size", 8)
	var slot_count: int = slots_container.get_child_count()
	var inventory_width: float = slot_size.x * float(slot_count) + slot_gap * float(maxi(0, slot_count - 1)) + 16.0
	bottom_center.offset_left = -inventory_width * 0.5
	bottom_center.offset_top = -(slot_size.y + 16.0)
	bottom_center.offset_right = inventory_width * 0.5
	bottom_center.offset_bottom = -12.0
	if dialog_label:
		dialog_label.add_theme_font_size_override("font_size", 16)

func _build_desktop_hints() -> void:
	if _is_touch_device():
		return
	desktop_hint_panel = PanelContainer.new()
	desktop_hint_panel.name = "DesktopHintPanel"
	desktop_hint_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	desktop_hint_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	desktop_hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	desktop_hint_panel.offset_right = -24.0
	desktop_hint_panel.offset_bottom = -16.0
	desktop_hint_panel.offset_left = -390.0
	desktop_hint_panel.offset_top = -68.0
	desktop_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desktop_hint_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(desktop_hint_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desktop_hint_panel.add_child(vbox)

	var row1 := HBoxContainer.new()
	row1.alignment = BoxContainer.ALIGNMENT_END
	row1.add_theme_constant_override("separation", 12)
	row1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(row1)
	_add_gta_key_hint(row1, "WASD", "GERAK", false)
	_add_gta_key_hint(row1, "SHIFT", "LARI", false)
	_add_gta_key_hint(row1, "E", "INTERAKSI", true)
	_add_gta_key_hint(row1, "F", "SENTER", true)

	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_END
	row2.add_theme_constant_override("separation", 12)
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(row2)
	_add_gta_key_hint(row2, "1-5", "SLOT", false)
	_add_gta_key_hint(row2, "TAB", "TAS", true)
	_add_gta_key_hint(row2, "G", "BUANG", false)
	_add_gta_key_hint(row2, "ESC", "JEDA", false)

func _add_gta_key_hint(parent_row: HBoxContainer, key_text: String, action_text: String, is_accent: bool) -> void:
	var item := HBoxContainer.new()
	item.alignment = BoxContainer.ALIGNMENT_CENTER
	item.add_theme_constant_override("separation", 5)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent_row.add_child(item)

	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(HorrorTheme.PRIMARY_CONTAINER.r, HorrorTheme.PRIMARY_CONTAINER.g, HorrorTheme.PRIMARY_CONTAINER.b, 0.92) if is_accent else Color(HorrorTheme.SURFACE_HIGH.r, HorrorTheme.SURFACE_HIGH.g, HorrorTheme.SURFACE_HIGH.b, 0.90)
	b_style.border_color = HorrorTheme.ACCENT if is_accent else HorrorTheme.OUTLINE
	b_style.set_border_width_all(1)
	b_style.set_corner_radius_all(3)
	b_style.content_margin_left = 6.0
	b_style.content_margin_right = 6.0
	b_style.content_margin_top = 1.0
	b_style.content_margin_bottom = 1.0
	badge.add_theme_stylebox_override("panel", b_style)
	item.add_child(badge)

	var key_lbl := Label.new()
	key_lbl.text = key_text
	key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HorrorTheme.style_label(key_lbl, "mono-sm", HorrorTheme.ON_PRIMARY_CONTAINER if is_accent else HorrorTheme.PRIMARY, 10)
	badge.add_child(key_lbl)

	var act_lbl := Label.new()
	act_lbl.text = action_text
	act_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HorrorTheme.style_label(act_lbl, "label-sm", HorrorTheme.ON_SURFACE, 10)
	act_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	act_lbl.add_theme_constant_override("outline_size", 3)
	item.add_child(act_lbl)

func _draw_virtual_joystick() -> void:
	if not joystick_base:
		return
	var center: Vector2 = joystick_base.size * 0.5
	var radius: float = joystick_base.size.x * 0.43
	joystick_base.draw_circle(center, radius, Color(HorrorTheme.SURFACE_LOWEST.r, HorrorTheme.SURFACE_LOWEST.g, HorrorTheme.SURFACE_LOWEST.b, 0.72))
	joystick_base.draw_arc(center, radius, 0.0, TAU, 48, Color(HorrorTheme.ACCENT.r, HorrorTheme.ACCENT.g, HorrorTheme.ACCENT.b, 0.85), 2.0, true)
	joystick_base.draw_arc(center, radius * 0.74, 0.0, TAU, 8, Color(HorrorTheme.OUTLINE_VARIANT.r, HorrorTheme.OUTLINE_VARIANT.g, HorrorTheme.OUTLINE_VARIANT.b, 0.65), 1.4, true)
	for i: int in range(4):
		var a: float = float(i) * PI * 0.5
		var dir := Vector2(cos(a), sin(a))
		joystick_base.draw_line(center + dir * (radius * 0.76), center + dir * (radius * 0.96), Color(HorrorTheme.PRIMARY.r, HorrorTheme.PRIMARY.g, HorrorTheme.PRIMARY.b, 0.55), 2.0)
	var knob_center: Vector2 = center + joystick_vector * radius * 0.68
	joystick_base.draw_circle(knob_center, radius * 0.36, Color(HorrorTheme.SECONDARY_CONTAINER.r, HorrorTheme.SECONDARY_CONTAINER.g, HorrorTheme.SECONDARY_CONTAINER.b, 0.92))
	joystick_base.draw_arc(knob_center, radius * 0.36, 0.0, TAU, 36, Color(HorrorTheme.PRIMARY.r, HorrorTheme.PRIMARY.g, HorrorTheme.PRIMARY.b, 0.92), 2.0, true)

func _input(event: InputEvent) -> void:
	if mobile_editor_active:
		_handle_mobile_editor_input(event)
		return
	if pause_settings_container and pause_settings_container.visible and pause_settings_scroll:
		if _handle_pause_settings_scroll_input(event):
			return
	_pause_drag_scrolling = false
	_pause_drag_moved = false
	_pause_drag_button = null
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

func _handle_pause_settings_scroll_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN) and mb.pressed:
			if pause_graphics_option and pause_graphics_option.get_popup().visible:
				return false
			if pause_settings_scroll.get_global_rect().has_point(mb.position):
				var step: int = -48 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 48
				pause_settings_scroll.scroll_vertical = maxi(0, pause_settings_scroll.scroll_vertical + step)
				get_viewport().set_input_as_handled()
				return true
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and pause_settings_scroll.get_global_rect().has_point(mb.position):
				var hovered: Control = get_viewport().gui_get_hovered_control()
				if hovered is HSlider or hovered is VScrollBar or hovered is HScrollBar or hovered is LineEdit or hovered is TextEdit or hovered is OptionButton:
					return false
				_pause_drag_scrolling = true
				_pause_drag_start_y = mb.position.y
				_pause_drag_last_y = mb.position.y
				_pause_drag_moved = false
				_pause_drag_button = hovered as BaseButton
				return false
			elif not mb.pressed and _pause_drag_scrolling:
				var was_dragged: bool = _pause_drag_moved
				_pause_drag_scrolling = false
				_pause_drag_moved = false
				_pause_drag_button = null
				if was_dragged:
					get_viewport().set_input_as_handled()
					return true
	elif event is InputEventMouseMotion and _pause_drag_scrolling:
		var mm := event as InputEventMouseMotion
		if not _pause_drag_moved and absf(mm.position.y - _pause_drag_start_y) > 8.0:
			_pause_drag_moved = true
			if is_instance_valid(_pause_drag_button):
				var was_disabled: bool = _pause_drag_button.disabled
				_pause_drag_button.disabled = true
				_pause_drag_button.disabled = was_disabled
				_pause_drag_button = null
		if _pause_drag_moved:
			var delta_y: float = mm.position.y - _pause_drag_last_y
			pause_settings_scroll.scroll_vertical = maxi(0, pause_settings_scroll.scroll_vertical - int(round(delta_y)))
			get_viewport().set_input_as_handled()
			_pause_drag_last_y = mm.position.y
			return true
		_pause_drag_last_y = mm.position.y
	return false

func _handle_mobile_editor_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			editor_touch_index = touch.index
			editor_drag_target = null
			if joystick_base and joystick_base.get_global_rect().has_point(touch.position):
				editor_drag_target = joystick_base
			else:
				for button: Button in touch_buttons:
					if button.get_global_rect().has_point(touch.position):
						editor_drag_target = button
						break
			if editor_drag_target:
				editor_drag_offset = touch.position - editor_drag_target.global_position
		else:
			if touch.index == editor_touch_index:
				editor_touch_index = -1
				editor_drag_target = null
				_save_mobile_control_layout()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == editor_touch_index and is_instance_valid(editor_drag_target):
			var view_size: Vector2 = get_viewport().get_visible_rect().size
			var next_position: Vector2 = drag.position - editor_drag_offset
			editor_drag_target.position = Vector2(
				clampf(next_position.x, 8.0, maxf(8.0, view_size.x - editor_drag_target.size.x - 8.0)),
				clampf(next_position.y, 8.0, maxf(8.0, view_size.y - editor_drag_target.size.y - 8.0))
			)
			if editor_drag_target == joystick_base:
				joystick_base.queue_redraw()

func _start_mobile_editor() -> void:
	if not touch_controls_enabled or mobile_editor_active:
		return
	mobile_editor_active = true
	_pause_settings_container_hide()
	pause_menu.get_node("Center").visible = false
	touch_root.visible = true
	touch_root.z_index = 20
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for button: Button in touch_buttons:
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	editor_hint_label = Label.new()
	editor_hint_label.text = "SERET JOYSTICK DAN TOMBOL KE POSISI YANG DIINGINKAN"
	editor_hint_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	editor_hint_label.offset_left = 12.0
	editor_hint_label.offset_top = 14.0
	editor_hint_label.offset_right = -150.0
	editor_hint_label.offset_bottom = 48.0
	editor_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HorrorTheme.style_label(editor_hint_label, "label-lg", HorrorTheme.PRIMARY, 12)
	editor_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_root.add_child(editor_hint_label)
	editor_done_button = _make_touch_button("done")
	editor_done_button.position = Vector2(get_viewport().get_visible_rect().size.x - 94.0, 86.0)
	editor_done_button.size = Vector2(64.0, 52.0)
	editor_done_button.mouse_filter = Control.MOUSE_FILTER_STOP
	editor_done_button.pressed.connect(_finish_mobile_editor)
	touch_root.add_child(editor_done_button)

func _finish_mobile_editor() -> void:
	if not mobile_editor_active:
		return
	_save_mobile_control_layout()
	mobile_editor_active = false
	editor_touch_index = -1
	editor_drag_target = null
	if is_instance_valid(editor_hint_label):
		editor_hint_label.queue_free()
	if is_instance_valid(editor_done_button):
		editor_done_button.queue_free()
	editor_hint_label = null
	editor_done_button = null
	if touch_root:
		touch_root.z_index = 1
		touch_root.visible = false
	if joystick_base:
		joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for button: Button in touch_buttons:
		button.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_menu.get_node("Center").visible = true

func _save_mobile_control_layout() -> void:
	if not touch_controls_enabled or not joystick_base:
		return
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var normalized_buttons: Array = []
	for button: Button in touch_buttons:
		normalized_buttons.append(Vector2(button.position.x / view_size.x, button.position.y / view_size.y))
	SettingsManager.set_mobile_control_layout(Vector2(joystick_base.position.x / view_size.x, joystick_base.position.y / view_size.y), normalized_buttons)

func _update_virtual_joystick(screen_position: Vector2) -> void:
	if not joystick_base:
		return
	var local_position: Vector2 = screen_position - joystick_base.global_position
	var center: Vector2 = joystick_base.size * 0.5
	var radius: float = joystick_base.size.x * 0.38
	var offset: Vector2 = (local_position - center).limit_length(radius)
	joystick_vector = Vector2(offset.x / radius, offset.y / radius)
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
	
	var fear: float = 1.0 - clampf(current / maxf(1.0, max_val), 0.0, 1.0)
	var dizzy: float = clampf((fear - 0.30) / 0.70, 0.0, 1.0)
	if post_process_rect:
		post_process_rect.visible = true
	if post_process_material:
		post_process_material.set_shader_parameter("vignette_intensity", lerp(0.35, 1.25, fear))
		post_process_material.set_shader_parameter("aberration_amount", lerp(0.001, 0.016, fear))
		post_process_material.set_shader_parameter("pulse_intensity", fear)
		post_process_material.set_shader_parameter("dizzy_intensity", dizzy)

func _on_stamina_changed(current: float, max_val: float) -> void:
	stamina_bar.max_value = max_val
	stamina_bar.value = current
	stamina_val.text = "%d%%" % int((current / max_val) * 100.0)

func _on_battery_changed(current: float, max_val: float) -> void:
	battery_bar.max_value = max_val
	battery_bar.value = current
	var pct: int = int(round((current / max_val) * 100.0))
	battery_val.text = "%d%%" % pct
	var player: PlayerController = GameManager.player_character as PlayerController
	if player and player.inventory_system:
		for item: Dictionary in player.inventory_system.slots:
			if item.get("id", "") == "flashlight":
				item["battery"] = current
		if pct != last_synced_battery_pct:
			last_synced_battery_pct = pct
			SignalBus.inventory_updated.emit(player.inventory_system.slots)

func _on_noise_made(level: float, _pos: Vector3) -> void:
	noise_bar.value = max(noise_bar.value, level * 100.0)

func _on_time_tick(time_str: String, _h: int, _m: int) -> void:
	clock_label.text = time_str + " WIB"

func _on_act_started(num: int, title: String) -> void:
	act_label.text = title
	for child: Node in objectives_container.get_children():
		child.queue_free()
	objective_labels.clear()
	objective_texts.clear()
	_populate_current_act_objectives()
	if num == 2 and not GameManager.is_resuming_saved_run:
		if mission_tween and mission_tween.is_running():
			mission_tween.kill()
		if mission_panel:
			mission_panel.visible = false
		_play_lampor_descent_cutscene()
	else:
		_show_act_banner(num, title)

func _play_lampor_descent_cutscene() -> void:
	var player: PlayerController = GameManager.player_character as PlayerController
	if not is_instance_valid(player) or not player.camera:
		return
	var lampor: LamporStateMachine = get_tree().current_scene.find_child("LamporAI", true, false) as LamporStateMachine
	if not lampor:
		return

	if inventory_overlay and inventory_overlay.visible:
		inventory_overlay.visible = false
		selected_swap_slot = -1
		player.is_inventory_open = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _is_touch_device() else Input.MOUSE_MODE_CAPTURED

	lampor.trigger_descent(true)

	if descent_camera_tween and descent_camera_tween.is_running():
		descent_camera_tween.kill()
	if is_instance_valid(descent_cutscene_overlay):
		descent_cutscene_overlay.queue_free()
		descent_cutscene_overlay = null

	if mission_tween and mission_tween.is_running():
		mission_tween.kill()
	if mission_panel:
		mission_panel.visible = false
	if touch_root:
		touch_root.visible = false
	if desktop_hint_panel:
		desktop_hint_panel.visible = false
	if hud_bag_button:
		hud_bag_button.visible = false
	stare_warning.visible = false
	interaction_label.text = ""
	var crosshair: Control = get_node_or_null("CenterContainer/Crosshair") as Control
	if crosshair:
		crosshair.visible = false

	player.camera.current = false
	player.set_virtual_move(Vector2.ZERO)
	player.set_virtual_sprint(false)
	player.velocity = Vector3.ZERO
	if player.has_method("prepare_for_cutscene"):
		player.prepare_for_cutscene()
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)

	descent_cutscene_overlay = Control.new()
	descent_cutscene_overlay.name = "DescentCutsceneOverlay"
	descent_cutscene_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	descent_cutscene_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	descent_cutscene_overlay.z_index = 18
	add_child(descent_cutscene_overlay)

	var title_lbl := Label.new()
	title_lbl.name = "CutsceneTitle"
	title_lbl.text = "BABAK II: KERANDA LAMPOR TURUN KE DESA"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.anchor_left = 0.05
	title_lbl.anchor_top = 0.03
	title_lbl.anchor_right = 0.95
	title_lbl.anchor_bottom = 0.14
	title_lbl.add_theme_font_override("font", HORROR_TITLE_FONT)
	title_lbl.add_theme_font_size_override("font_size", 16 if _is_touch_device() else 20)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2, 1.0))
	title_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	title_lbl.add_theme_constant_override("outline_size", 5)
	descent_cutscene_overlay.add_child(title_lbl)

	var subtitle_lbl := Label.new()
	subtitle_lbl.name = "CutsceneSubtitle"
	subtitle_lbl.text = "Lampor mendarat dari langit malam... Bersiaplah, Lampor langsung mengejarmu!"
	subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_lbl.anchor_left = 0.05
	subtitle_lbl.anchor_top = 0.84
	subtitle_lbl.anchor_right = 0.95
	subtitle_lbl.anchor_bottom = 0.96
	subtitle_lbl.add_theme_font_size_override("font_size", 15 if _is_touch_device() else 19)
	subtitle_lbl.add_theme_color_override("font_color", Color(0.96, 0.88, 0.72, 1.0))
	subtitle_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	subtitle_lbl.add_theme_constant_override("outline_size", 4)
	descent_cutscene_overlay.add_child(subtitle_lbl)

	var cutscene_camera := Camera3D.new()
	cutscene_camera.name = "LamporDescentCamera"
	cutscene_camera.fov = maxf(player.camera.fov, 68.0)

	var fill_light := OmniLight3D.new()
	fill_light.name = "CutsceneFillLight"
	fill_light.omni_range = 24.0
	fill_light.light_energy = 2.0
	fill_light.light_color = Color(0.65, 0.95, 0.75)
	cutscene_camera.add_child(fill_light)

	get_tree().current_scene.add_child(cutscene_camera)

	var target_pos: Vector3 = lampor.descend_target
	var to_player: Vector3 = player.global_position - target_pos
	to_player.y = 0.0
	var view_dir: Vector3 = to_player.normalized() if to_player.length_squared() > 0.01 else Vector3(0.0, 0.0, 1.0)
	var side_dir: Vector3 = view_dir.cross(Vector3.UP).normalized()
	var cam_start: Vector3 = target_pos + view_dir * 12.5 + side_dir * 3.8 + Vector3(0.0, 7.2, 0.0)
	var cam_end: Vector3 = target_pos + view_dir * 6.5 - side_dir * 1.4 + Vector3(0.0, 2.3, 0.0)

	cutscene_camera.global_position = cam_start
	var initial_focus: Vector3 = lampor.global_position + Vector3(0.0, 0.15, 0.0)
	if cutscene_camera.global_position.distance_squared_to(initial_focus) > 0.05:
		cutscene_camera.look_at(initial_focus, Vector3.UP)
	cutscene_camera.current = true
	AudioManager.play_sound("lampor_roar", 1.0)

	descent_camera_tween = create_tween()
	descent_camera_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	descent_camera_tween.tween_method(func(progress: float) -> void:
		if not is_instance_valid(cutscene_camera) or not is_instance_valid(lampor):
			return
		cutscene_camera.global_position = cam_start.lerp(cam_end, ease(progress, -1.6))
		var focus_pos: Vector3 = lampor.global_position + Vector3(0.0, 0.15, 0.0)
		if cutscene_camera.global_position.distance_squared_to(focus_pos) > 0.05:
			cutscene_camera.look_at(focus_pos, Vector3.UP)
	, 0.0, 1.0, LamporStateMachine.DESCENT_DURATION)
	descent_camera_tween.tween_callback(func() -> void:
		if is_instance_valid(player):
			player.camera.current = true
			player.set_physics_process(true)
			player.set_process_unhandled_input(true)
		if is_instance_valid(crosshair):
			crosshair.visible = true
		if touch_root and _is_touch_device() and not get_tree().paused:
			touch_root.visible = true
		if desktop_hint_panel and not _is_touch_device() and not get_tree().paused:
			desktop_hint_panel.visible = true
		if hud_bag_button:
			hud_bag_button.visible = true
		if is_instance_valid(cutscene_camera):
			cutscene_camera.queue_free()
		if is_instance_valid(descent_cutscene_overlay):
			descent_cutscene_overlay.queue_free()
			descent_cutscene_overlay = null
		if is_instance_valid(lampor) and lampor.current_state != LamporStateMachine.State.CHASE and lampor.current_state != LamporStateMachine.State.BANISHED:
			if lampor.descent_tween and lampor.descent_tween.is_running():
				lampor.descent_tween.kill()
			lampor.global_position = lampor.descend_target
			lampor.is_descending = false
			if lampor.collision_shape:
				lampor.collision_shape.disabled = false
			lampor.chase_cooldown = 0.0
			lampor.chase_timer = 0.0
			lampor.lost_sight_timer = -3.0
			lampor._set_state(LamporStateMachine.State.CHASE)
			SignalBus.lampor_state_changed.emit("CHASE")
		_on_dialog_requested("LAMPOR TELAH TURUN DAN MENGEJARMU! Lari atau sembunyi di dalam rumah!", 4.5)
	)

func _show_act_banner(num: int, _title: String) -> void:
	if banner_tween:
		banner_tween.kill()

	# Banner lama digantikan kartu misi (teks banner dipakai sebagai judul kartu)
	act_banner.visible = false
	act_banner.modulate.a = 0.0

	match num:
		1:
			act_banner.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
			act_banner.text = "BABAK I: PERTAHANAN AWAL (01.00 WIB)"
		2:
			act_banner.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
			act_banner.text = "BABAK II: LAMPOR TURUN KE DESA"
			AudioManager.play_sound("lampor_roar", 1.0)
		3:
			act_banner.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1))
			act_banner.text = "BABAK III: KLIMAKS PEMBAKARAN"
			AudioManager.play_sound("lampor_roar", 2.0)

	_show_mission_card(num, act_banner.text)

func _on_objective_updated(id: String, text: String, current: int, required: int, is_completed: bool) -> void:
	var label: Label = null
	var touch: bool = _is_touch_device()
	if objective_labels.has(id) and is_instance_valid(objective_labels[id]):
		label = objective_labels[id]
	else:
		label = Label.new()
		label.add_theme_font_size_override("font_size", 11 if touch else 14)
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
		label.add_theme_constant_override("outline_size", 3)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var view_w: float = get_viewport().get_visible_rect().size.x
		var tl_w: float = clampf(view_w * 0.34, 260.0, 350.0) if touch else 380.0
		label.custom_minimum_size.x = tl_w - 16.0
		objectives_container.add_child(label)
		objective_labels[id] = label
		
	var status_icon: String = "[Selesai]" if is_completed else "◆"
	var progress_str: String = " (%d/%d)" % [current, required] if required > 1 else ""
	label.text = "%s %s%s" % [status_icon, text, progress_str]
	label.modulate = Color(0.6, 1.0, 0.6) if is_completed else Color(1.0, 1.0, 1.0)
	objective_texts[id] = label.text
	_refresh_mission_card()

func _on_inventory_updated(slots: Array) -> void:
	cached_inventory_slots = slots
	var player: PlayerController = GameManager.player_character as PlayerController
	var active_slot_idx: int = player.inventory_system.active_slot if (player and player.inventory_system) else 0
	for i in range(min(slots.size(), slots_container.get_child_count())):
		var slot_panel: PanelContainer = slots_container.get_child(i) as PanelContainer
		var label: Label = slot_panel.get_node("VBox/ItemName") as Label
		var qty_label: Label = slot_panel.get_node("VBox/Qty") as Label
		var is_active: bool = (i == active_slot_idx)
		
		var item: Dictionary = slots[i]
		if item.is_empty():
			label.text = "[Kosong]"
			label.add_theme_color_override("font_color", Color(HorrorTheme.OUTLINE.r, HorrorTheme.OUTLINE.g, HorrorTheme.OUTLINE.b, 0.72))
			qty_label.text = ""
		else:
			label.text = item.get("name", "")
			label.add_theme_color_override("font_color", HorrorTheme.ON_PRIMARY_CONTAINER if is_active else HorrorTheme.ON_SURFACE)
			if item.get("id", "") == "flashlight":
				qty_label.text = "%d%%" % int(round(float(item.get("battery", 0.0))))
			elif item.has("quantity") and item["quantity"] > 1:
				qty_label.text = "x" + str(item["quantity"])
			elif item.has("battery"):
				qty_label.text = "%d%%" % int(item["battery"])
			else:
				qty_label.text = ""
	if inventory_overlay and inventory_overlay.visible:
		_refresh_inventory_ui()

func _on_item_equipped(slot_index: int, _item: Dictionary) -> void:
	for i in range(slots_container.get_child_count()):
		var slot_panel: PanelContainer = slots_container.get_child(i) as PanelContainer
		_apply_slot_horror_style(slot_panel, i == slot_index)
	if inventory_overlay and inventory_overlay.visible:
		_refresh_inventory_ui()

func _on_lampor_stare(intensity: float) -> void:
	if intensity > 0.4:
		stare_warning.visible = true
		stare_warning.text = "JANGAN MENATAP LANGSUNG! ALIHKAN PANDANGANMU!"
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
	if inventory_overlay and inventory_overlay.visible:
		toggle_inventory()
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

func _build_hud_bag_button() -> void:
	return

func _build_inventory_overlay() -> void:
	inventory_overlay = ColorRect.new()
	inventory_overlay.name = "InventoryOverlay"
	inventory_overlay.color = Color(HorrorTheme.SCRIM.r, HorrorTheme.SCRIM.g, HorrorTheme.SCRIM.b, 0.62)
	inventory_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_overlay.z_index = 25
	inventory_overlay.visible = false
	add_child(inventory_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	inventory_overlay.add_child(center)

	inventory_modal_panel = PanelContainer.new()
	inventory_modal_panel.name = "InventoryModalPanel"
	inventory_modal_panel.custom_minimum_size = Vector2(410.0, 0.0)
	inventory_modal_panel.add_theme_stylebox_override(
		"panel",
		HorrorTheme.make_panel_style(
			Color(HorrorTheme.SURFACE.r, HorrorTheme.SURFACE.g, HorrorTheme.SURFACE.b, 0.94),
			HorrorTheme.OUTLINE_VARIANT,
			4,
			2,
			16,
			12
		)
	)
	HorrorTheme.attach_corner_ornaments(inventory_modal_panel, HorrorTheme.ACCENT, 12.0, 1.8, 5.0, true)
	center.add_child(inventory_modal_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 7)
	inventory_modal_panel.add_child(main_vbox)

	var header_strip := PanelContainer.new()
	header_strip.add_theme_stylebox_override(
		"panel",
		HorrorTheme.make_chip_style(HorrorTheme.SURFACE_LOWEST, HorrorTheme.OUTLINE_VARIANT, 3, 12, 6)
	)
	main_vbox.add_child(header_strip)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header_strip.add_child(header)

	var title_lbl := Label.new()
	title_lbl.text = "◆  TAS BEKAL & INVENTARIS"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HorrorTheme.style_label(title_lbl, "headline-md", HorrorTheme.ON_SURFACE, 16)
	header.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "TUTUP [TAB]"
	close_btn.custom_minimum_size = Vector2(114.0, 32.0)
	HorrorTheme.style_button(close_btn, "secondary", 11, true)
	close_btn.pressed.connect(toggle_inventory)
	header.add_child(close_btn)

	var storage_lbl := Label.new()
	storage_lbl.text = "PENYIMPANAN TAS  ·  15 SLOT"
	HorrorTheme.style_label(storage_lbl, "label-lg", HorrorTheme.PRIMARY, 11)
	main_vbox.add_child(storage_lbl)

	var storage_grid := GridContainer.new()
	storage_grid.columns = 5
	storage_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	storage_grid.add_theme_constant_override("h_separation", 6)
	storage_grid.add_theme_constant_override("v_separation", 6)
	main_vbox.add_child(storage_grid)

	inventory_storage_slots.clear()
	for i in range(15):
		var slot_idx: int = InventorySystem.HOTBAR_SLOTS + i
		var slot_ui: PanelContainer = INVENTORY_SLOT_UI_SCRIPT.new()
		slot_ui.setup(slot_idx, false, "")
		slot_ui.slot_dropped.connect(_on_inventory_slot_dropped)
		slot_ui.slot_clicked.connect(_on_inventory_slot_clicked)
		storage_grid.add_child(slot_ui)
		inventory_storage_slots.append(slot_ui)

	main_vbox.add_child(HorrorTheme.create_ritual_divider("◆", HorrorTheme.PRIMARY_CONTAINER))

	var hotbar_lbl := Label.new()
	hotbar_lbl.text = "HOTBAR CEPAT  ·  5 SLOT"
	HorrorTheme.style_label(hotbar_lbl, "label-lg", HorrorTheme.SECONDARY, 11)
	main_vbox.add_child(hotbar_lbl)

	var hotbar_grid := GridContainer.new()
	hotbar_grid.columns = 5
	hotbar_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hotbar_grid.add_theme_constant_override("h_separation", 6)
	hotbar_grid.add_theme_constant_override("v_separation", 6)
	main_vbox.add_child(hotbar_grid)

	inventory_hotbar_slots.clear()
	for i in range(InventorySystem.HOTBAR_SLOTS):
		var slot_ui: PanelContainer = INVENTORY_SLOT_UI_SCRIPT.new()
		slot_ui.setup(i, true, "[%d]" % (i + 1))
		slot_ui.slot_dropped.connect(_on_inventory_slot_dropped)
		slot_ui.slot_clicked.connect(_on_inventory_slot_clicked)
		hotbar_grid.add_child(slot_ui)
		inventory_hotbar_slots.append(slot_ui)

	var hint_chip := PanelContainer.new()
	hint_chip.add_theme_stylebox_override(
		"panel",
		HorrorTheme.make_chip_style(HorrorTheme.SURFACE_LOW, HorrorTheme.OUTLINE_VARIANT, 3, 10, 6)
	)
	main_vbox.add_child(hint_chip)

	var hint_lbl := Label.new()
	hint_lbl.text = "Tarik & taruh (atau ketuk dua slot) untuk menukar barang antara tas dan hotbar."
	hint_lbl.custom_minimum_size.x = 340.0
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	HorrorTheme.style_label(hint_lbl, "label-sm", HorrorTheme.ON_SURFACE_VARIANT, 10)
	hint_chip.add_child(hint_lbl)

func toggle_inventory() -> void:
	if descent_cutscene_overlay and is_instance_valid(descent_cutscene_overlay) and descent_cutscene_overlay.visible:
		return
	if pause_menu.visible or barricade_dialog.visible:
		return
	if GameManager.death_sequence_active or GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if not inventory_overlay:
		return

	var is_open: bool = not inventory_overlay.visible
	inventory_overlay.visible = is_open
	selected_swap_slot = -1

	var player: PlayerController = GameManager.player_character as PlayerController
	if is_open:
		_refresh_inventory_ui()
		HorrorTheme.animate_surface_enter(inventory_modal_panel)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if player:
			player.is_inventory_open = true
			player.set_virtual_move(Vector2.ZERO)
			player.set_virtual_sprint(false)
	else:
		if player:
			player.is_inventory_open = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _is_touch_device() else Input.MOUSE_MODE_CAPTURED

func _refresh_inventory_ui() -> void:
	var player: PlayerController = GameManager.player_character as PlayerController
	var current_slots: Array = cached_inventory_slots
	var active_slot_idx: int = 0
	if player and player.inventory_system:
		current_slots = player.inventory_system.slots
		active_slot_idx = player.inventory_system.active_slot
	cached_inventory_slots = current_slots

	for i in range(inventory_hotbar_slots.size()):
		var slot_idx: int = i
		var data: Dictionary = current_slots[slot_idx] if slot_idx < current_slots.size() else {}
		inventory_hotbar_slots[i].update_slot(data, slot_idx == active_slot_idx)
		inventory_hotbar_slots[i].set_selected(slot_idx == selected_swap_slot)

	for i in range(inventory_storage_slots.size()):
		var slot_idx: int = InventorySystem.HOTBAR_SLOTS + i
		var data: Dictionary = current_slots[slot_idx] if slot_idx < current_slots.size() else {}
		inventory_storage_slots[i].update_slot(data, false)
		inventory_storage_slots[i].set_selected(slot_idx == selected_swap_slot)

func _update_slot_selections() -> void:
	for i in range(inventory_hotbar_slots.size()):
		inventory_hotbar_slots[i].set_selected(i == selected_swap_slot)
	for i in range(inventory_storage_slots.size()):
		var slot_idx: int = InventorySystem.HOTBAR_SLOTS + i
		inventory_storage_slots[i].set_selected(slot_idx == selected_swap_slot)

func _on_inventory_slot_dropped(from_slot: int, to_slot: int) -> void:
	var player: PlayerController = GameManager.player_character as PlayerController
	if not player or not player.inventory_system:
		return
	var success: bool = player.inventory_system.move_or_swap_slots(from_slot, to_slot)
	if success:
		AudioManager.play_sound("item_pickup", -4.0, 1.1)
	selected_swap_slot = -1
	_refresh_inventory_ui()

func _on_inventory_slot_clicked(slot_idx: int) -> void:
	var player: PlayerController = GameManager.player_character as PlayerController
	if not player or not player.inventory_system:
		return
	if selected_swap_slot == -1:
		if slot_idx >= 0 and slot_idx < player.inventory_system.slots.size():
			if not player.inventory_system.slots[slot_idx].is_empty():
				selected_swap_slot = slot_idx
				_update_slot_selections()
	else:
		if selected_swap_slot == slot_idx:
			selected_swap_slot = -1
			_update_slot_selections()
		else:
			var from_slot: int = selected_swap_slot
			selected_swap_slot = -1
			var success: bool = player.inventory_system.move_or_swap_slots(from_slot, slot_idx)
			if success:
				AudioManager.play_sound("item_pickup", -4.0, 1.1)
			_refresh_inventory_ui()
