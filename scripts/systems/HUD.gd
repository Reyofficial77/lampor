class_name HUD
extends CanvasLayer

const INVENTORY_SLOT_UI_SCRIPT = preload("res://scripts/ui/InventorySlotUI.gd")
const TUTORIAL_OVERLAY_SCRIPT = preload("res://scripts/systems/TutorialOverlay.gd")
const FATE_CARD_SYSTEM_SCRIPT = preload("res://scripts/systems/FateCardSystem.gd")
const FATE_CARD_OVERLAY_SCRIPT = preload("res://scripts/ui/FateCardOverlay.gd")
const HORROR_TITLE_FONT: Font = preload("res://assets/fonts/HorrorTitle.ttf")
const LocScript = preload("res://scripts/systems/Loc.gd")
const ProfanityFilterScript = preload("res://scripts/systems/ProfanityFilter.gd")
const VerifiedBadgeScript = preload("res://scripts/ui/VerifiedBadge.gd")

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
signal cutscene_finished(skipped: bool)

var descent_camera_tween: Tween
var descent_cutscene_overlay: Control = null
var active_cutscene_type: String = ""
var active_cutscene_camera: Camera3D = null
var active_cutscene_elapsed: float = 0.0
var active_cutscene_finish_cb: Callable = Callable()
var _cutscene_vfx_nodes: Array[Node] = []
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
var touch_run_button: Button = null
var sandbox_touch_btn: Button = null
var admin_touch_btn: Button = null
var mp_overlay_panel: PanelContainer = null
var mp_room_title_lbl: Label = null
var mp_room_meta_lbl: Label = null
var mp_announcement_panel: PanelContainer = null
var mp_announcement_lbl: Label = null
var mp_roster_vbox: VBoxContainer = null
var _mp_refresh_elapsed: float = 0.0
var _mp_last_sig: String = ""
var _last_sandbox_hint_active: bool = false
var _last_admin_hint_active: bool = false
var pause_admin_button: Button = null
var low_fear_tint: ColorRect = null
var _pause_settings_box: VBoxContainer = null
var _pause_language_option: OptionButton = null
var _pause_listening_keybind_action: String = ""
var _pause_keybind_buttons: Dictionary = {}
var _exit_confirm_title: Label = null
var _exit_confirm_msg: Label = null
var _exit_confirm_cancel: Button = null
var _exit_confirm_ok: Button = null
var _inv_title_lbl: Label = null
var _inv_close_btn: Button = null
var _inv_storage_lbl: Label = null
var _inv_hotbar_lbl: Label = null
var _inv_hint_lbl: Label = null
var fate_card_overlay: FATE_CARD_OVERLAY_SCRIPT = null
var fate_cards_strip: VBoxContainer = null
var _pending_fate_offers: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if post_process_rect and post_process_rect.material is ShaderMaterial:
		post_process_material = post_process_rect.material as ShaderMaterial

	low_fear_tint = ColorRect.new()
	low_fear_tint.name = "LowFearTint"
	low_fear_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	low_fear_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	low_fear_tint.color = Color(0.28, 0.02, 0.03, 0.0)
	low_fear_tint.visible = false
	add_child(low_fear_tint)
	move_child(low_fear_tint, 0)

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
	SignalBus.fate_card_applied.connect(_on_fate_card_applied)
	SignalBus.fate_cards_reset.connect(_on_fate_cards_reset)
	if SignalBus.has_signal("multiplayer_room_updated"):
		SignalBus.multiplayer_room_updated.connect(func(_r: Dictionary, _p: Array) -> void:
			_refresh_host_and_admin_controls()
			_refresh_online_room_overlay(true)
		)
	if SignalBus.has_signal("account_state_changed"):
		SignalBus.account_state_changed.connect(_refresh_host_and_admin_controls)
	SettingsManager.keybinds_changed.connect(_on_settings_keybinds_changed)
	SettingsManager.language_changed.connect(_on_language_changed)

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
	_build_online_room_overlay()
	_build_inventory_overlay()
	_build_hud_bag_button()
	_build_fate_cards_strip()
	_mount_fate_card_overlay()
	if TUTORIAL_OVERLAY_SCRIPT:
		add_child(TUTORIAL_OVERLAY_SCRIPT.new())
	_initialize_objectives_immediate()
	_refresh_fate_cards_strip()
	_refresh_localized_hud_texts()
	if not GameManager.is_resuming_saved_run and not GameManager.is_tutorial_mode and GameManager.current_act == GameManager.Act.BABAK_1 and not bool(GameManager.fate_cards_offered_acts.get(1, false)):
		_schedule_fate_card_offer(1, 0.5)
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
	call_deferred("_populate_desktop_hints")
	call_deferred("_refresh_online_room_overlay", true)

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

func is_cutscene_active() -> bool:
	return not active_cutscene_type.is_empty() or (is_instance_valid(descent_cutscene_overlay) and descent_cutscene_overlay.visible)

func is_fate_card_overlay_open() -> bool:
	return is_instance_valid(fate_card_overlay) and fate_card_overlay.is_open()

func _is_key_bound_to_gameplay(event: InputEventKey) -> bool:
	for action: String in SettingsManager.REBINDABLE_ACTIONS:
		if action != "toggle_inventory" and event.is_action(action):
			return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if is_cutscene_active() or is_fate_card_overlay_open():
		return
	var legacy_inv_key: bool = event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and ((event as InputEventKey).keycode == KEY_B or (event as InputEventKey).keycode == KEY_I) and not _is_key_bound_to_gameplay(event as InputEventKey)
	if event.is_action_pressed("toggle_inventory") or legacy_inv_key:
		if not pause_menu.visible and not barricade_dialog.visible and GameManager.current_state == GameManager.GameState.PLAYING:
			toggle_inventory()
			return

	if event.is_action_pressed("pause"):
		if not _pause_listening_keybind_action.is_empty():
			_cancel_pause_keybind_listening()
			return
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
	if is_cutscene_active() or is_fate_card_overlay_open():
		return
	_cancel_pause_keybind_listening()
	if mobile_editor_active:
		_finish_mobile_editor()
	if inventory_overlay and inventory_overlay.visible:
		toggle_inventory()
	# Jangan izinkan pemain membatalkan jeda paksa selama rangkaian jumpscare / ending.
	if GameManager.death_sequence_active or GameManager.victory_sequence_active:
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
	var player: PlayerController = GameManager.player_character as PlayerController
	if player:
		player.release_all_held_inputs()
	if is_paused:
		GameManager.save_active_run()
		joystick_vector = Vector2.ZERO
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if is_instance_valid(pause_admin_button):
			pause_admin_button.visible = GameManager.is_logged_in_admin()
		_apply_overlay_layouts()
		var pause_panel: Control = pause_menu.get_node_or_null("Center/Panel") as Control
		if pause_panel:
			pause_panel.reset_size()
			HorrorTheme.animate_surface_enter(pause_panel)
		if resume_button:
			resume_button.call_deferred("grab_focus")
	else:
		if pause_settings_container:
			pause_settings_container.visible = false
		pause_menu.get_node("Center").visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _is_touch_device() else Input.MOUSE_MODE_CAPTURED

func _style_pause_and_dialogs() -> void:
	var dim_overlay: ColorRect = pause_menu.get_node_or_null("DimOverlay") as ColorRect
	if dim_overlay:
		dim_overlay.color = Color(HorrorTheme.SCRIM_DARK.r, HorrorTheme.SCRIM_DARK.g, HorrorTheme.SCRIM_DARK.b, 0.72)
	var pause_panel: PanelContainer = pause_menu.get_node_or_null("Center/Panel") as PanelContainer
	if pause_panel:
		pause_panel.add_theme_stylebox_override("panel", HorrorTheme.make_minimal_panel_style(Color(0.086, 0.045, 0.043, 0.96), HorrorTheme.BORDER_INTERACTIVE, 2, 26, 24))
	var pause_vbox: VBoxContainer = pause_menu.get_node_or_null("Center/Panel/VBox") as VBoxContainer
	if pause_vbox:
		pause_vbox.add_theme_constant_override("separation", 12)
	var pause_sep: HSeparator = pause_menu.get_node_or_null("Center/Panel/VBox/HSeparator") as HSeparator
	if pause_sep:
		var sep_s := StyleBoxFlat.new()
		sep_s.bg_color = Color(HorrorTheme.OUTLINE_VARIANT.r, HorrorTheme.OUTLINE_VARIANT.g, HorrorTheme.OUTLINE_VARIANT.b, 0.55)
		sep_s.content_margin_top = 1.0
		pause_sep.add_theme_stylebox_override("separator", sep_s)
	var pause_title: Label = pause_menu.get_node_or_null("Center/Panel/VBox/Title") as Label
	if pause_title:
		HorrorTheme.style_label(pause_title, "headline-md", HorrorTheme.ON_SURFACE, 19)
	if resume_button:
		resume_button.text = "LANJUTKAN [ESC]"
		resume_button.custom_minimum_size.y = 44.0
		HorrorTheme.style_button(resume_button, "primary", 13, true)
	if settings_button:
		settings_button.text = "PENGATURAN"
		settings_button.custom_minimum_size.y = 44.0
		HorrorTheme.style_button(settings_button, "secondary", 13, true)
	if pause_vbox and pause_admin_button == null:
		pause_admin_button = Button.new()
		pause_admin_button.name = "AdminPanelButton"
		pause_admin_button.text = "ADMIN PANEL [ALT+F2]"
		pause_admin_button.custom_minimum_size.y = 44.0
		HorrorTheme.style_button(pause_admin_button, "primary", 12, true)
		pause_admin_button.pressed.connect(func() -> void: GameManager.toggle_admin_panel())
		pause_vbox.add_child(pause_admin_button)
		if exit_button and exit_button.get_parent() == pause_vbox:
			pause_vbox.move_child(pause_admin_button, exit_button.get_index())
		pause_admin_button.visible = GameManager.is_logged_in_admin()
	if exit_button:
		exit_button.text = "KEMBALI KE MENU UTAMA"
		exit_button.custom_minimum_size.y = 44.0
		HorrorTheme.style_button(exit_button, "ghost", 12, true)

	if barricade_dialog:
		barricade_dialog.add_theme_stylebox_override("panel", HorrorTheme.make_minimal_panel_style(Color(0.086, 0.045, 0.043, 0.96), HorrorTheme.ACCENT, 2, 24, 22))
		var b_title: Label = barricade_dialog.get_node_or_null("Margin/VBox/Title") as Label
		if b_title:
			HorrorTheme.style_label(b_title, "headline-md", HorrorTheme.PRIMARY, 17)
		var b_msg: Label = barricade_dialog.get_node_or_null("Margin/VBox/Message") as Label
		if b_msg:
			HorrorTheme.style_label(b_msg, "body-md", HorrorTheme.ON_SURFACE, 14)
		if confirm_barricade_btn:
			confirm_barricade_btn.text = "TETAP PALANG PINTU"
			confirm_barricade_btn.custom_minimum_size.y = 44.0
			HorrorTheme.style_button(confirm_barricade_btn, "primary", 13, true)
		if cancel_barricade_btn:
			cancel_barricade_btn.text = "BATAL"
			cancel_barricade_btn.custom_minimum_size.y = 44.0
			HorrorTheme.style_button(cancel_barricade_btn, "ghost", 13, true)

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
	pause_settings_panel.add_theme_stylebox_override("panel", HorrorTheme.make_minimal_panel_style(Color(0.086, 0.045, 0.043, 0.96), HorrorTheme.BORDER_INTERACTIVE, 2, 0, 0))
	pause_settings_container.add_child(pause_settings_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
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
	_pause_settings_box = box
	_populate_pause_settings_box()

func _populate_pause_settings_box() -> void:
	if not is_instance_valid(_pause_settings_box):
		return
	_pause_listening_keybind_action = ""
	_pause_keybind_buttons.clear()
	for child: Node in _pause_settings_box.get_children():
		_pause_settings_box.remove_child(child)
		child.queue_free()
	var box: VBoxContainer = _pause_settings_box
	var title := Label.new()
	title.text = LocScript.pick("PENGATURAN", "SETTINGS")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	HorrorTheme.style_label(title, "headline-md", HorrorTheme.ON_SURFACE, 19)
	box.add_child(title)
	box.add_child(HorrorTheme.make_hairline_divider())

	var lang_lbl := Label.new()
	lang_lbl.text = LocScript.pick("Bahasa / Language", "Language")
	HorrorTheme.style_label(lang_lbl, "label-sm", HorrorTheme.ON_SURFACE, 13)
	box.add_child(lang_lbl)
	var lang_opt := OptionButton.new()
	_pause_language_option = lang_opt
	lang_opt.custom_minimum_size.y = 42.0
	lang_opt.add_item("Indonesia (ID)")
	lang_opt.add_item("English (EN-US)")
	var pause_is_en: bool = SettingsManager.is_en() if SettingsManager.has_method("is_en") else LocScript.is_en()
	lang_opt.select(1 if pause_is_en else 0)
	lang_opt.item_selected.connect(func(index: int) -> void:
		var target_lang: String = "en_US" if index == 1 else "id"
		if SettingsManager.has_method("set_language"):
			SettingsManager.set_language(target_lang)
		else:
			LocScript.set_language(target_lang)
			_on_language_changed(target_lang)
	)
	HorrorTheme.style_option_button(lang_opt)
	box.add_child(lang_opt)

	_add_pause_slider(box, LocScript.pick("Sensitivitas Mouse", "Mouse Sensitivity"), SettingsManager.mouse_sensitivity * 100.0, 25.0, 200.0, func(v: float) -> void: SettingsManager.set_mouse_sensitivity(v / 100.0))
	_add_pause_slider(box, LocScript.pick("Sensitivitas Kamera", "Camera Sensitivity"), SettingsManager.camera_sensitivity * 100.0, 25.0, 200.0, func(v: float) -> void: SettingsManager.set_camera_sensitivity(v / 100.0))
	_add_pause_slider(box, LocScript.pick("Kecerahan", "Brightness"), SettingsManager.brightness * 100.0, 50.0, 150.0, func(v: float) -> void: SettingsManager.set_brightness(v / 100.0))
	var quality := OptionButton.new()
	pause_graphics_option = quality
	quality.custom_minimum_size.y = 44.0
	quality.add_item(LocScript.pick("Grafik: Otomatis (Perangkat)", "Graphics: Auto (Device)"))
	quality.add_item(LocScript.pick("Grafik: Low", "Graphics: Low"))
	quality.add_item(LocScript.pick("Grafik: Medium", "Graphics: Medium"))
	quality.add_item(LocScript.pick("Grafik: High", "Graphics: High"))
	quality.select({"auto": 0, "low": 1, "medium": 2, "high": 3}.get(SettingsManager.graphics_quality, 0))
	quality.tooltip_text = LocScript.pick(
		"Otomatis menggunakan preset %s berdasarkan perangkat ini" % SettingsManager.recommended_graphics_quality.capitalize(),
		"Auto uses %s preset based on this device" % SettingsManager.recommended_graphics_quality.capitalize()
	)
	quality.item_selected.connect(func(index: int) -> void: SettingsManager.set_graphics_quality(["auto", "low", "medium", "high"][index]))
	HorrorTheme.style_option_button(quality)
	box.add_child(quality)
	var auto_update := CheckButton.new()
	auto_update.text = LocScript.pick("Unduh update otomatis", "Auto-download updates")
	auto_update.custom_minimum_size.y = 44.0
	auto_update.button_pressed = SettingsManager.auto_update
	auto_update.toggled.connect(SettingsManager.set_auto_update)
	HorrorTheme.style_check_button(auto_update)
	box.add_child(auto_update)

	var pause_actions: Array = SettingsManager.get("REBINDABLE_ACTIONS") if "REBINDABLE_ACTIONS" in SettingsManager else []
	if not pause_actions.is_empty():
		box.add_child(HorrorTheme.make_hairline_divider())
		var kb_title := Label.new()
		kb_title.text = LocScript.pick("KEYBINDS (KLIK UNTUK UBAH)", "KEYBINDINGS (CLICK TO REBIND)")
		HorrorTheme.style_label(kb_title, "label-sm", HorrorTheme.PRIMARY, 12)
		box.add_child(kb_title)
		for action: String in pause_actions:
			var k_row := HBoxContainer.new()
			k_row.add_theme_constant_override("separation", 8)
			var k_lbl := Label.new()
			k_lbl.text = LocScript.action_label(action)
			k_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			HorrorTheme.style_label(k_lbl, "label-sm", HorrorTheme.ON_SURFACE, 12)
			k_row.add_child(k_lbl)
			var k_btn := Button.new()
			k_btn.text = SettingsManager.get_action_key_text(action) if SettingsManager.has_method("get_action_key_text") else action.to_upper()
			k_btn.custom_minimum_size = Vector2(108.0, 34.0)
			HorrorTheme.style_button(k_btn, "secondary", 11, true)
			k_btn.pressed.connect(func() -> void: _begin_pause_keybind_listen(action))
			k_row.add_child(k_btn)
			box.add_child(k_row)
			_pause_keybind_buttons[action] = k_btn
		var kb_reset := Button.new()
		kb_reset.text = LocScript.pick("RESET TOMBOL BAWAAN", "RESET DEFAULT KEYBINDS")
		kb_reset.custom_minimum_size.y = 38.0
		HorrorTheme.style_button(kb_reset, "ghost", 11, true)
		kb_reset.pressed.connect(func() -> void:
			_cancel_pause_keybind_listening()
			if SettingsManager.has_method("reset_keybinds"):
				SettingsManager.reset_keybinds()
			_refresh_pause_keybind_buttons()
		)
		box.add_child(kb_reset)

	if _is_touch_device():
		_add_pause_slider(box, LocScript.pick("Ukuran tombol mobile", "Mobile button size"), SettingsManager.mobile_button_scale * 100.0, 75.0, 150.0, func(v: float) -> void:
			SettingsManager.set_mobile_button_scale(v / 100.0)
			_layout_touch_controls()
		)
		_add_pause_slider(box, LocScript.pick("Ukuran joystick", "Joystick size"), SettingsManager.mobile_joystick_scale * 100.0, 80.0, 140.0, func(v: float) -> void:
			SettingsManager.set_mobile_joystick_scale(v / 100.0)
			_layout_touch_controls()
		)
		var editor_button := Button.new()
		editor_button.text = LocScript.pick("EDITOR POSISI TOMBOL MOBILE", "EDIT MOBILE BUTTON LAYOUT")
		editor_button.custom_minimum_size.y = 44.0
		HorrorTheme.style_button(editor_button, "secondary", 12, true)
		editor_button.pressed.connect(_start_mobile_editor)
		box.add_child(editor_button)
		var reset_layout := Button.new()
		reset_layout.text = LocScript.pick("RESET TATA LETAK MOBILE", "RESET MOBILE LAYOUT")
		reset_layout.custom_minimum_size.y = 44.0
		HorrorTheme.style_button(reset_layout, "ghost", 12, true)
		reset_layout.pressed.connect(func() -> void:
			SettingsManager.reset_mobile_control_layout()
			_layout_touch_controls()
		)
		box.add_child(reset_layout)
	var close := Button.new()
	close.text = LocScript.pick("KEMBALI KE JEDA", "BACK TO PAUSE")
	close.custom_minimum_size.y = 44.0
	HorrorTheme.style_button(close, "primary", 13, true)
	close.pressed.connect(func() -> void:
		_cancel_pause_keybind_listening()
		_pause_settings_container_hide()
		pause_menu.get_node("Center").visible = true
	)
	box.add_child(close)

func _begin_pause_keybind_listen(action: String) -> void:
	_pause_listening_keybind_action = action
	_refresh_pause_keybind_buttons()

func _cancel_pause_keybind_listening() -> void:
	if _pause_listening_keybind_action.is_empty():
		return
	_pause_listening_keybind_action = ""
	_refresh_pause_keybind_buttons()

func _refresh_pause_keybind_buttons() -> void:
	for action: String in _pause_keybind_buttons.keys():
		var btn: Button = _pause_keybind_buttons[action] as Button
		if not is_instance_valid(btn):
			continue
		if action == _pause_listening_keybind_action:
			btn.text = LocScript.pick("TEKAN TOMBOL...", "PRESS KEY...")
			HorrorTheme.style_button(btn, "primary", 11, true)
		else:
			btn.text = SettingsManager.get_action_key_text(action) if SettingsManager.has_method("get_action_key_text") else action.to_upper()
			HorrorTheme.style_button(btn, "secondary", 11, true)

func _pause_settings_container_hide() -> void:
	_cancel_pause_keybind_listening()
	if pause_settings_container:
		pause_settings_container.visible = false

func _layout_pause_settings_panel() -> void:
	if not pause_settings_panel or not pause_settings_scroll or not pause_settings_container:
		return
	pause_settings_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_width: float = maxf(180.0, minf(460.0, view_size.x - 24.0))
	var content_h: float = 400.0
	if pause_settings_scroll.get_child_count() > 0:
		var box_ctrl: Control = pause_settings_scroll.get_child(0) as Control
		if box_ctrl:
			content_h = maxf(200.0, box_ctrl.get_combined_minimum_size().y + 4.0)
	var max_scroll_h: float = maxf(160.0, view_size.y - 68.0)
	var scroll_h: float = minf(content_h, max_scroll_h)
	pause_settings_panel.custom_minimum_size = Vector2(panel_width, 0.0)
	pause_settings_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pause_settings_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pause_settings_scroll.custom_minimum_size = Vector2(panel_width - 44.0, scroll_h)
	pause_settings_panel.reset_size()

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

func _mp() -> Variant:
	return GameManager.get_multiplayer_manager()

func _on_main_menu_pressed() -> void:
	_confirm_exit_to_menu()

func _confirm_exit_to_menu() -> void:
	var mp: Variant = _mp()
	if mp != null and mp.is_online_session:
		mp.leave_room()
	else:
		GameManager.save_active_run()
	GameManager.is_sandbox_mode = false
	GameManager.admin_god_mode = false
	GameManager.reset_sandbox_flags()
	if GameManager.sandbox_panel and GameManager.sandbox_panel.has_method("_force_close"):
		GameManager.sandbox_panel.call("_force_close")
	if mobile_editor_active:
		_finish_mobile_editor()
	if desktop_hint_panel:
		desktop_hint_panel.visible = false
	if is_instance_valid(fate_card_overlay) and fate_card_overlay.is_open():
		fate_card_overlay.force_close()
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
	_apply_overlay_layouts()
	barricade_dialog.visible = true
	HorrorTheme.animate_surface_enter(barricade_dialog)
	if cancel_barricade_btn:
		cancel_barricade_btn.call_deferred("grab_focus")
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
	AudioManager.play_voice_for_dialog_text(text_value)
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
	if is_cutscene_active():
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
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HorrorTheme.style_button(button, "primary" if primary else "ghost", 13, true)
	return button

func _build_exit_confirm() -> void:
	exit_confirm_overlay = ColorRect.new()
	exit_confirm_overlay.name = "ExitConfirmOverlay"
	exit_confirm_overlay.color = Color(HorrorTheme.SCRIM_DARK.r, HorrorTheme.SCRIM_DARK.g, HorrorTheme.SCRIM_DARK.b, 0.82)
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
	exit_panel.add_theme_stylebox_override("panel", HorrorTheme.make_minimal_panel_style(Color(0.086, 0.045, 0.043, 0.96), HorrorTheme.BORDER_INTERACTIVE, 2, 26, 24))
	center.add_child(exit_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	exit_panel.add_child(box)
	var title := Label.new()
	_exit_confirm_title = title
	title.text = LocScript.pick("KEMBALI KE MENU UTAMA?", "RETURN TO MAIN MENU?")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	HorrorTheme.style_label(title, "headline-md", HorrorTheme.ON_SURFACE, 18)
	box.add_child(title)
	box.add_child(HorrorTheme.make_hairline_divider())
	var message := Label.new()
	_exit_confirm_msg = message
	message.text = LocScript.pick(
		"Yakin ingin kembali ke menu utama?\nProgres tersimpan otomatis setiap 5 detik dan dapat dilanjutkan nanti.",
		"Return to the main menu?\nProgress autosaves every 5 seconds and can be resumed later."
	)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	message.custom_minimum_size.x = 360.0
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	HorrorTheme.style_label(message, "body-md", HorrorTheme.ON_SURFACE_VARIANT, 14)
	box.add_child(message)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var cancel := _make_exit_button(LocScript.pick("BATAL", "CANCEL"), false)
	_exit_confirm_cancel = cancel
	cancel.pressed.connect(func() -> void:
		exit_confirm_overlay.visible = false
		if pause_menu.visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _is_touch_device() else Input.MOUSE_MODE_CAPTURED
	)
	buttons.add_child(cancel)
	var confirm := _make_exit_button(LocScript.pick("KE MENU UTAMA", "MAIN MENU"), true)
	_exit_confirm_ok = confirm
	confirm.pressed.connect(_on_main_menu_pressed)
	buttons.add_child(confirm)

func _show_exit_confirm() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _exit_confirm_msg:
		var mp: Variant = _mp()
		if mp != null and mp.is_online_session:
			_exit_confirm_msg.text = LocScript.pick(
				"Yakin ingin keluar dari room online dan kembali ke menu utama?",
				"Are you sure you want to leave the online room and return to the main menu?"
			)
		else:
			_exit_confirm_msg.text = LocScript.pick(
				"Yakin ingin kembali ke menu utama?\nProgres tersimpan otomatis setiap 5 detik dan dapat dilanjutkan nanti.",
				"Return to the main menu?\nProgress autosaves every 5 seconds and can be resumed later."
			)
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
	if barricade_dialog:
		var bar_w: float = minf(520.0, view_size.x - 28.0)
		barricade_dialog.offset_left = -bar_w * 0.5
		barricade_dialog.offset_right = bar_w * 0.5
	var pause_panel: PanelContainer = pause_menu.get_node_or_null("Center/Panel") as PanelContainer
	if pause_panel:
		pause_panel.custom_minimum_size = Vector2(minf(340.0, view_size.x - 32.0), 0.0)
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
	_apply_online_overlay_layout()

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
	touch_run_button = run_button
	run_button.button_down.connect(_on_touch_run_down)
	run_button.button_up.connect(_on_touch_run_up)
	run_button.mouse_exited.connect(_on_touch_run_up)
	run_button.focus_exited.connect(_on_touch_run_up)
	var interact_button := _make_touch_button("interact")
	interact_button.pressed.connect(_on_touch_interact)
	var flashlight_button := _make_touch_button("flashlight")
	flashlight_button.pressed.connect(_on_touch_flashlight)
	var pause_button := _make_touch_button("pause")
	pause_button.pressed.connect(toggle_pause)
	var bag_button := _make_touch_button("bag")
	bag_button.pressed.connect(toggle_inventory)
	sandbox_touch_btn = _make_touch_button("sandbox")
	sandbox_touch_btn.pressed.connect(func() -> void: GameManager.toggle_sandbox_panel())
	sandbox_touch_btn.visible = GameManager.is_sandbox_owner_active()
	admin_touch_btn = _make_touch_button("admin")
	admin_touch_btn.pressed.connect(func() -> void:
		if GameManager.is_logged_in_admin() and GameManager.admin_panel and GameManager.admin_panel.has_method("toggle_panel"):
			GameManager.admin_panel.call("toggle_panel")
	)
	admin_touch_btn.visible = GameManager.is_logged_in_admin()
	touch_buttons.append(run_button)
	touch_buttons.append(interact_button)
	touch_buttons.append(flashlight_button)
	touch_buttons.append(pause_button)
	touch_buttons.append(bag_button)
	touch_buttons.append(sandbox_touch_btn)
	touch_buttons.append(admin_touch_btn)
	for button: Button in touch_buttons:
		touch_root.add_child(button)
	get_viewport().size_changed.connect(_layout_touch_controls)
	_layout_touch_controls()

func _make_touch_button(icon_id: String) -> Button:
	var button := Button.new()
	button.text = ""
	button.set_meta("touch_icon", icon_id)
	button.focus_mode = Control.FOCUS_NONE
	var is_utility: bool = icon_id in ["pause", "bag", "sandbox", "admin"]
	var is_sandbox_btn: bool = icon_id in ["sandbox", "admin"]

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(HorrorTheme.SURFACE_LOW.r, HorrorTheme.SURFACE_LOW.g, HorrorTheme.SURFACE_LOW.b, 0.86) if is_utility else Color(HorrorTheme.SURFACE.r, HorrorTheme.SURFACE.g, HorrorTheme.SURFACE.b, 0.86)
	normal.border_color = HorrorTheme.RELIC_BRASS if is_sandbox_btn else (HorrorTheme.OUTLINE if is_utility else HorrorTheme.ACCENT)
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
		HorrorTheme.RELIC_BRASS if is_sandbox_btn else (HorrorTheme.ON_SURFACE_VARIANT if is_utility else HorrorTheme.PRIMARY),
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
		"sandbox":
			# Ikon panel slider sandbox (vektor murni tanpa huruf/emoji)
			var frame := Rect2(c + Vector2(-u * 0.24, -u * 0.21), Vector2(u * 0.48, u * 0.42))
			btn.draw_rect(frame, Color(col.r, col.g, col.b, 0.40), false, maxf(1.2, w * 0.72))
			var row_offsets: Array[float] = [-u * 0.11, 0.0, u * 0.11]
			var knob_x: Array[float] = [-u * 0.07, u * 0.09, -u * 0.09]
			for idx: int in range(3):
				var ry: float = c.y + row_offsets[idx]
				btn.draw_line(Vector2(c.x - u * 0.17, ry), Vector2(c.x + u * 0.17, ry), col, maxf(1.5, w * 0.85))
				btn.draw_circle(Vector2(c.x + knob_x[idx], ry), u * 0.055, HorrorTheme.RELIC_BRASS)
				btn.draw_arc(Vector2(c.x + knob_x[idx], ry), u * 0.055, 0.0, TAU, 16, col, maxf(1.0, w * 0.5), true)
		"admin":
			# Ikon perisai admin (vektor murni khusus akun admin)
			var shield := PackedVector2Array([
				c + Vector2(0.0, -u * 0.24),
				c + Vector2(u * 0.20, -u * 0.14),
				c + Vector2(u * 0.16, u * 0.10),
				c + Vector2(0.0, u * 0.26),
				c + Vector2(-u * 0.16, u * 0.10),
				c + Vector2(-u * 0.20, -u * 0.14)
			])
			btn.draw_colored_polygon(shield, Color(HorrorTheme.PRIMARY.r, HorrorTheme.PRIMARY.g, HorrorTheme.PRIMARY.b, 0.35))
			btn.draw_polyline(shield, HorrorTheme.RELIC_BRASS, maxf(1.6, w * 0.9), true)
			btn.draw_line(c + Vector2(0.0, -u * 0.10), c + Vector2(0.0, u * 0.10), col, maxf(1.5, w * 0.85))
			btn.draw_line(c + Vector2(-u * 0.09, 0.0), c + Vector2(u * 0.09, 0.0), col, maxf(1.5, w * 0.85))

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
	var sandbox_x: float = pause_x - util_size - 14.0
	var admin_x: float = sandbox_x - util_size - 14.0
	var defaults: Array[Vector2] = [
		Vector2(x_right, y_top),     # 0: run
		Vector2(x_right, y_bottom),  # 1: interact
		Vector2(x_left, y_bottom),   # 2: flashlight
		Vector2(pause_x, 16.0),      # 3: pause
		Vector2(bag_x, 16.0),        # 4: bag
		Vector2(sandbox_x, 16.0),    # 5: sandbox
		Vector2(admin_x, 16.0)       # 6: admin
	]
	var stats_forbidden := Rect2(view_size.x - stats_width - 18.0, 8.0, stats_width + 18.0, 94.0)
	var saved_positions: Array = SettingsManager.mobile_button_positions
	for i: int in range(touch_buttons.size()):
		var button: Button = touch_buttons[i]
		var target_size: Vector2 = Vector2(util_size, util_size) if i >= 3 else Vector2(button_size, button_size)
		button.size = target_size
		var button_position: Vector2 = defaults[i]
		if i < saved_positions.size() and saved_positions[i] is Vector2:
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
	if is_instance_valid(fate_cards_strip):
		fate_cards_strip.custom_minimum_size.x = tl_width - 16.0
		_refresh_fate_cards_strip()
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
	desktop_hint_panel.offset_left = -520.0
	desktop_hint_panel.offset_top = -68.0
	desktop_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desktop_hint_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(desktop_hint_panel)
	_populate_desktop_hints()

func _populate_desktop_hints() -> void:
	if not is_instance_valid(desktop_hint_panel):
		return
	for child: Node in desktop_hint_panel.get_children():
		desktop_hint_panel.remove_child(child)
		child.queue_free()

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desktop_hint_panel.add_child(vbox)

	var slot_range: String = "%s-%s" % [SettingsManager.get_action_key_text("slot_1"), SettingsManager.get_action_key_text("slot_5")]

	var row1 := HBoxContainer.new()
	row1.alignment = BoxContainer.ALIGNMENT_END
	row1.add_theme_constant_override("separation", 12)
	row1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(row1)
	_add_gta_key_hint(row1, SettingsManager.get_move_keys_summary(), LocScript.pick("GERAK", "MOVE"), false)
	_add_gta_key_hint(row1, SettingsManager.get_action_key_text("sprint"), LocScript.pick("LARI", "SPRINT"), false)
	_add_gta_key_hint(row1, SettingsManager.get_action_key_text("interact"), LocScript.pick("INTERAKSI", "INTERACT"), true)
	_add_gta_key_hint(row1, SettingsManager.get_action_key_text("flashlight"), LocScript.pick("SENTER", "LIGHT"), true)

	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_END
	row2.add_theme_constant_override("separation", 12)
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(row2)
	_add_gta_key_hint(row2, slot_range, LocScript.pick("SLOT", "SLOTS"), false)
	_add_gta_key_hint(row2, SettingsManager.get_action_key_text("toggle_inventory"), LocScript.pick("TAS", "BAG"), true)
	_add_gta_key_hint(row2, SettingsManager.get_action_key_text("drop_item"), LocScript.pick("BUANG", "DROP"), false)
	if GameManager.is_sandbox_owner_active():
		_add_gta_key_hint(row2, "Ctrl+F5", "Sandbox", true)
	if GameManager.is_logged_in_admin():
		_add_gta_key_hint(row2, "Alt+F2", "Admin", true)
	_add_gta_key_hint(row2, "ESC", LocScript.pick("JEDA", "PAUSE"), false)
	_last_sandbox_hint_active = GameManager.is_sandbox_owner_active()
	_last_admin_hint_active = GameManager.is_logged_in_admin()

func _build_online_room_overlay() -> void:
	mp_overlay_panel = PanelContainer.new()
	mp_overlay_panel.name = "OnlineRoomOverlay"
	mp_overlay_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mp_overlay_panel.z_index = 3
	mp_overlay_panel.add_theme_stylebox_override(
		"panel",
		HorrorTheme.make_minimal_panel_style(Color(0.06, 0.03, 0.032, 0.78), HorrorTheme.BORDER_SUBTLE, 2, 10, 8)
	)
	add_child(mp_overlay_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mp_overlay_panel.add_child(vbox)

	mp_room_title_lbl = Label.new()
	mp_room_title_lbl.clip_text = true
	mp_room_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HorrorTheme.style_label(mp_room_title_lbl, "label-lg", HorrorTheme.RELIC_BRASS, 11)
	vbox.add_child(mp_room_title_lbl)

	mp_room_meta_lbl = Label.new()
	mp_room_meta_lbl.clip_text = true
	mp_room_meta_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HorrorTheme.style_label(mp_room_meta_lbl, "mono-sm", HorrorTheme.ON_SURFACE_VARIANT, 10)
	vbox.add_child(mp_room_meta_lbl)

	mp_announcement_panel = PanelContainer.new()
	mp_announcement_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mp_announcement_panel.visible = false
	mp_announcement_panel.add_theme_stylebox_override(
		"panel",
		HorrorTheme.make_chip_style(Color(0.28, 0.07, 0.07, 0.88), HorrorTheme.ACCENT, 2, 6, 4)
	)
	vbox.add_child(mp_announcement_panel)

	mp_announcement_lbl = Label.new()
	mp_announcement_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mp_announcement_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HorrorTheme.style_label(mp_announcement_lbl, "label-sm", HorrorTheme.ON_PRIMARY_CONTAINER, 10)
	mp_announcement_panel.add_child(mp_announcement_lbl)

	vbox.add_child(HorrorTheme.make_hairline_divider())

	mp_roster_vbox = VBoxContainer.new()
	mp_roster_vbox.add_theme_constant_override("separation", 2)
	mp_roster_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(mp_roster_vbox)

	_apply_online_overlay_layout()
	_refresh_online_room_overlay(true)

func _apply_online_overlay_layout() -> void:
	if not is_instance_valid(mp_overlay_panel):
		return
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	if view_size.x <= 0.0:
		view_size = Vector2(1280.0, 720.0)
	var touch: bool = _is_touch_device()
	var panel_w: float = clampf(view_size.x * 0.24, 198.0, 236.0) if touch else 258.0
	var top_y: float = 104.0 if touch else 14.0
	mp_overlay_panel.anchor_left = 1.0
	mp_overlay_panel.anchor_right = 1.0
	mp_overlay_panel.anchor_top = 0.0
	mp_overlay_panel.anchor_bottom = 0.0
	mp_overlay_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	mp_overlay_panel.grow_vertical = Control.GROW_DIRECTION_END
	mp_overlay_panel.offset_left = -panel_w - (12.0 if touch else 14.0)
	mp_overlay_panel.offset_right = -(12.0 if touch else 14.0)
	mp_overlay_panel.offset_top = top_y
	mp_overlay_panel.offset_bottom = top_y + 10.0
	mp_overlay_panel.custom_minimum_size = Vector2(panel_w, 0.0)
	if mp_announcement_lbl:
		mp_announcement_lbl.custom_minimum_size.x = panel_w - 34.0

func _refresh_online_room_overlay(force: bool = false) -> void:
	if not is_instance_valid(mp_overlay_panel):
		return
	var mp: Variant = _mp()
	var active: bool = mp != null and mp.is_online_session and not is_cutscene_active()
	mp_overlay_panel.visible = active
	if not active:
		return

	var room: Dictionary = mp.current_room
	var mode_tag: String = "[SANDBOX]" if (GameManager.is_sandbox_mode or str(room.get("mode", "")) == "sandbox") else "[CO-OP]"
	var room_name: String = ProfanityFilterScript.censor(str(room.get("name", "Desa Lampor")))
	var room_code: String = str(room.get("roomCode", "------"))
	var ping_val: int = maxi(0, int(mp.ping_ms))
	var ann: String = ProfanityFilterScript.censor(str(mp.server_announcement).strip_edges())
	var host_id: String = str(room.get("hostUserId", "")).strip_edges().to_lower()

	if mp_room_meta_lbl:
		mp_room_meta_lbl.text = "Kode: %s  ·  %d ms" % [room_code, ping_val]

	var sig_parts: PackedStringArray = PackedStringArray([mode_tag, room_name, room_code, ann])
	for p_var: Variant in mp.room_players:
		if p_var is Dictionary:
			var p: Dictionary = p_var as Dictionary
			var uid: String = str(p.get("userId", p.get("id", "")))
			var uname: String = ProfanityFilterScript.censor(str(p.get("username", "Pemain")))
			var is_h: bool = bool(p.get("isHost", false)) or (not host_id.is_empty() and uid.to_lower() == host_id)
			var is_v: bool = bool(p.get("isVerified", false))
			var ps: Variant = p.get("playerState", {})
			var san: int = clampi(int(round(float(ps.get("sanity", 100)) if ps is Dictionary else float(p.get("sanity", 100)))), 0, 100)
			sig_parts.append("%s:%s:%s:%s:%d" % [uid, uname, "H" if is_h else "P", "V" if is_v else "N", san])
	var sig: String = "|".join(sig_parts)
	if not force and sig == _mp_last_sig:
		return
	_mp_last_sig = sig

	if mp_room_title_lbl:
		mp_room_title_lbl.text = "%s %s" % [mode_tag, room_name]
		HorrorTheme.style_label(mp_room_title_lbl, "label-lg", HorrorTheme.RELIC_BRASS if mode_tag == "[SANDBOX]" else HorrorTheme.PRIMARY, 11)

	if mp_announcement_panel and mp_announcement_lbl:
		mp_announcement_panel.visible = not ann.is_empty()
		mp_announcement_lbl.text = ann

	if mp_roster_vbox:
		for child: Node in mp_roster_vbox.get_children():
			mp_roster_vbox.remove_child(child)
			child.queue_free()
		for p_var: Variant in mp.room_players:
			if not (p_var is Dictionary):
				continue
			var p: Dictionary = p_var as Dictionary
			var uid: String = str(p.get("userId", p.get("id", "")))
			var uname: String = ProfanityFilterScript.censor(str(p.get("username", "Pemain")))
			var is_host: bool = bool(p.get("isHost", false)) or (not host_id.is_empty() and uid.to_lower() == host_id)
			var is_v_p: bool = bool(p.get("isVerified", false))
			var ps: Variant = p.get("playerState", {})
			var san: int = clampi(int(round(float(ps.get("sanity", 100)) if ps is Dictionary else float(p.get("sanity", 100)))), 0, 100)

			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mp_roster_vbox.add_child(row)

			var name_wrap := HBoxContainer.new()
			name_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_wrap.add_theme_constant_override("separation", 4)
			name_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(name_wrap)

			var name_lbl := Label.new()
			name_lbl.text = "%s%s" % [uname, " [HOST]" if is_host else ""]
			name_lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			name_lbl.clip_text = true
			name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			HorrorTheme.style_label(name_lbl, "label-sm", HorrorTheme.RELIC_BRASS if is_host else HorrorTheme.ON_SURFACE, 10)
			name_wrap.add_child(name_lbl)
			if is_v_p:
				name_wrap.add_child(VerifiedBadgeScript.create_control(12.0))

			var san_lbl := Label.new()
			san_lbl.text = "WARAS %d%%" % san
			san_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var san_col: Color = HorrorTheme.SUCCESS_SAGE if san >= 60 else (HorrorTheme.RELIC_BRASS if san >= 30 else HorrorTheme.ACCENT)
			HorrorTheme.style_label(san_lbl, "mono-sm", san_col, 10)
			row.add_child(san_lbl)
	mp_overlay_panel.reset_size()

func _on_settings_keybinds_changed() -> void:
	_populate_desktop_hints()
	_refresh_pause_keybind_buttons()
	if _inv_close_btn:
		_inv_close_btn.text = LocScript.pick("TUTUP [%s]" % SettingsManager.get_action_key_text("toggle_inventory"), "CLOSE [%s]" % SettingsManager.get_action_key_text("toggle_inventory"))
	var player: PlayerController = GameManager.player_character as PlayerController
	if player and player.interaction_ray:
		player.interaction_ray._update_prompt()

func _on_language_changed(_new_lang: String) -> void:
	_populate_pause_settings_box()
	_refresh_localized_hud_texts()
	_refresh_fate_cards_strip()
	_layout_pause_settings_panel()

func _refresh_localized_hud_texts() -> void:
	var stats_vbox: VBoxContainer = bottom_left.get_node_or_null("VBox") as VBoxContainer if bottom_left else null
	if stats_vbox:
		var s_lbl: Label = stats_vbox.get_node_or_null("SanityContainer").get_child(0) as Label if stats_vbox.has_node("SanityContainer") else null
		var st_lbl: Label = stats_vbox.get_node_or_null("StaminaContainer").get_child(0) as Label if stats_vbox.has_node("StaminaContainer") else null
		var b_lbl: Label = stats_vbox.get_node_or_null("BatteryContainer").get_child(0) as Label if stats_vbox.has_node("BatteryContainer") else null
		if s_lbl:
			s_lbl.text = LocScript.pick("Waras", "Sanity")
		if st_lbl:
			st_lbl.text = "Stamina"
		if b_lbl:
			b_lbl.text = LocScript.pick("Senter", "Light")
	if bottom_right:
		var br_lbl: Label = bottom_right.get_node_or_null("VBox/Label") as Label
		if br_lbl:
			br_lbl.text = LocScript.pick("Kebisingan Suara", "Noise Level")

	var pause_title: Label = pause_menu.get_node_or_null("Center/Panel/VBox/Title") as Label if pause_menu else null
	if pause_title:
		pause_title.text = LocScript.pick("PERMAINAN DIJEDA", "GAME PAUSED")
	if resume_button:
		resume_button.text = LocScript.pick("LANJUTKAN [ESC]", "RESUME [ESC]")
	if settings_button:
		settings_button.text = LocScript.pick("PENGATURAN", "SETTINGS")
	if exit_button:
		exit_button.text = LocScript.pick("KEMBALI KE MENU UTAMA", "RETURN TO MAIN MENU")

	if barricade_dialog:
		var b_title: Label = barricade_dialog.get_node_or_null("Margin/VBox/Title") as Label
		if b_title:
			b_title.text = LocScript.pick("PERINGATAN: KAMU DI DALAM RUMAH!", "WARNING: YOU ARE INSIDE THE HOUSE!")
		var b_msg: Label = barricade_dialog.get_node_or_null("Margin/VBox/Message") as Label
		if b_msg:
			b_msg.text = LocScript.pick(
				"Kamu sedang berada di DALAM rumah kayu ini!\n\nPintu yang dipalang tidak bisa dibuka dari luar. Kamu masih bisa membongkar palang dari dalam rumah (papan dikembalikan ke inventaris), tapi suara palu akan menarik perhatian Lampor.\n\nApakah kamu yakin ingin tetap memalang pintu ini dari dalam?",
				"You are currently INSIDE this wooden house!\n\nA barricaded door cannot be opened from outside. You can still dismantle it from inside (planks return to your bag), but hammering noises will alert Lampor.\n\nAre you sure you want to barricade this door from inside?"
			)
		if confirm_barricade_btn:
			confirm_barricade_btn.text = LocScript.pick("TETAP PALANG PINTU", "BARRICADE ANYWAY")
		if cancel_barricade_btn:
			cancel_barricade_btn.text = LocScript.pick("BATAL", "CANCEL")

	if _exit_confirm_title:
		_exit_confirm_title.text = LocScript.pick("KEMBALI KE MENU UTAMA?", "RETURN TO MAIN MENU?")
	if _exit_confirm_msg:
		_exit_confirm_msg.text = LocScript.pick(
			"Yakin ingin kembali ke menu utama?\nProgres tersimpan otomatis setiap 5 detik dan dapat dilanjutkan nanti.",
			"Return to the main menu?\nProgress autosaves every 5 seconds and can be resumed later."
		)
	if _exit_confirm_cancel:
		_exit_confirm_cancel.text = LocScript.pick("BATAL", "CANCEL")
	if _exit_confirm_ok:
		_exit_confirm_ok.text = LocScript.pick("KE MENU UTAMA", "MAIN MENU")

	if _inv_title_lbl:
		_inv_title_lbl.text = LocScript.pick("TAS BEKAL & INVENTARIS", "BACKPACK & INVENTORY")
	if _inv_close_btn:
		_inv_close_btn.text = LocScript.pick("TUTUP [%s]" % SettingsManager.get_action_key_text("toggle_inventory"), "CLOSE [%s]" % SettingsManager.get_action_key_text("toggle_inventory"))
	if _inv_storage_lbl:
		_inv_storage_lbl.text = LocScript.pick("TAS  ·  15 SLOT", "BAG  ·  15 SLOTS")
	if _inv_hotbar_lbl:
		_inv_hotbar_lbl.text = LocScript.pick("HOTBAR  ·  5 SLOT", "HOTBAR  ·  5 SLOTS")
	if _inv_hint_lbl:
		_inv_hint_lbl.text = LocScript.pick("Tarik atau ketuk dua slot untuk menukar barang.", "Drag or click two slots to swap items.")

	if stare_warning and stare_warning.visible:
		stare_warning.text = LocScript.pick("JANGAN MENATAP LANGSUNG! ALIHKAN PANDANGANMU!", "DO NOT STARE DIRECTLY! LOOK AWAY NOW!")

	if act_label:
		act_label.text = GameManager.get_current_act_title()
	_populate_desktop_hints()
	_on_inventory_updated(cached_inventory_slots)
	var player: PlayerController = GameManager.player_character as PlayerController
	if player and player.interaction_ray:
		player.interaction_ray._update_prompt()

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
	if not _pause_listening_keybind_action.is_empty():
		if event is InputEventKey:
			var kb_ke := event as InputEventKey
			if kb_ke.pressed and not kb_ke.echo:
				if kb_ke.keycode == KEY_ESCAPE:
					_cancel_pause_keybind_listening()
				else:
					var action_name: String = _pause_listening_keybind_action
					_pause_listening_keybind_action = ""
					SettingsManager.rebind_action(action_name, kb_ke)
					_refresh_pause_keybind_buttons()
				get_viewport().set_input_as_handled()
				return
		elif event is InputEventMouseButton:
			var kb_mb := event as InputEventMouseButton
			if kb_mb.pressed:
				if kb_mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
					var action_name: String = _pause_listening_keybind_action
					_pause_listening_keybind_action = ""
					SettingsManager.rebind_action(action_name, kb_mb)
					_refresh_pause_keybind_buttons()
					get_viewport().set_input_as_handled()
					return
				elif kb_mb.button_index == MOUSE_BUTTON_LEFT:
					_cancel_pause_keybind_listening()
		return
	if is_cutscene_active():
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE] and active_cutscene_elapsed >= 0.25:
				_skip_active_cutscene()
				get_viewport().set_input_as_handled()
		return
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
			if _pause_language_option and _pause_language_option.get_popup().visible:
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
					if button.visible and button.get_global_rect().has_point(touch.position):
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
	editor_hint_label.text = LocScript.pick("SERET JOYSTICK DAN TOMBOL KE POSISI YANG DIINGINKAN", "DRAG JOYSTICK AND BUTTONS TO PREFERRED POSITIONS")
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
		if button.visible and button.get_global_rect().has_point(screen_position):
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

func _refresh_host_and_admin_controls() -> void:
	var sb_active: bool = GameManager.is_sandbox_owner_active()
	var adm_active: bool = GameManager.is_logged_in_admin()
	var cut_active: bool = is_cutscene_active()
	if is_instance_valid(sandbox_touch_btn):
		sandbox_touch_btn.visible = sb_active and not cut_active
	if is_instance_valid(admin_touch_btn):
		admin_touch_btn.visible = adm_active and not cut_active
	if sb_active != _last_sandbox_hint_active or adm_active != _last_admin_hint_active:
		_populate_desktop_hints()

func _process(delta: float) -> void:
	if is_cutscene_active():
		active_cutscene_elapsed += delta
	var player: PlayerController = GameManager.player_character as PlayerController
	if player and player.virtual_sprint_pressed:
		if get_tree().paused or touch_root == null or not touch_root.visible or not is_instance_valid(touch_run_button) or not touch_run_button.button_pressed:
			player.set_virtual_sprint(false)
	if noise_bar.value > 0:
		noise_bar.value = move_toward(noise_bar.value, 0.0, delta * 1.5)
	_refresh_host_and_admin_controls()
	_mp_refresh_elapsed += delta
	if _mp_refresh_elapsed >= 0.25:
		_mp_refresh_elapsed = 0.0
		_refresh_online_room_overlay(false)

func _on_interaction_prompt_changed(text: String) -> void:
	interaction_label.text = text

func _on_sanity_changed(current: float, max_val: float) -> void:
	sanity_bar.max_value = max_val
	sanity_bar.value = current
	sanity_val.text = "%d%%" % int((current / max_val) * 100.0)
	
	var fear: float = 1.0 - clampf(current / maxf(1.0, max_val), 0.0, 1.0)
	var dizzy: float = clampf((fear - 0.30) / 0.70, 0.0, 1.0)
	var is_low_q: bool = (post_process_rect != null and bool(post_process_rect.get_meta("low_quality_mode", false))) or SettingsManager.get_effective_graphics_quality() == "low"
	if post_process_rect:
		post_process_rect.visible = not is_low_q
	if low_fear_tint:
		var tint_a: float = clampf((fear - 0.35) * 0.38, 0.0, 0.25) if is_low_q else 0.0
		low_fear_tint.visible = tint_a > 0.01
		low_fear_tint.color = Color(0.28, 0.02, 0.03, tint_a)
	if not is_low_q and post_process_material:
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
	if act_label:
		act_label.text = GameManager.get_current_act_title()

func _on_act_started(num: int, title: String) -> void:
	act_label.text = title
	for child: Node in objectives_container.get_children():
		child.queue_free()
	objective_labels.clear()
	objective_texts.clear()
	_populate_current_act_objectives()
	var mp: Variant = _mp()
	var lampor_enabled: bool = (mp == null) or (not mp.is_online_session) or bool(mp.get_room_setting("lamporEnabled", true))
	if num == 2 and not GameManager.is_resuming_saved_run and lampor_enabled:
		if mission_tween and mission_tween.is_running():
			mission_tween.kill()
		if mission_panel:
			mission_panel.visible = false
		_play_lampor_descent_cutscene()
		if not is_cutscene_active() and not GameManager.is_tutorial_mode and not bool(GameManager.fate_cards_offered_acts.get(2, false)):
			_schedule_fate_card_offer(2, 0.8)
	else:
		_show_act_banner(num, title)
		if not GameManager.is_resuming_saved_run and not GameManager.is_tutorial_mode and not bool(GameManager.fate_cards_offered_acts.get(num, false)):
			if num == 1:
				_schedule_fate_card_offer(1, 0.5)
			elif num == 2 or num == 3:
				_schedule_fate_card_offer(num, 0.8)

func _open_stage_xz(preferred_xz: Vector2) -> Vector2:
	var candidate := Vector2(clampf(preferred_xz.x, -26.0, 26.0), clampf(preferred_xz.y, -26.0, 26.0))
	var world_root: Node = get_tree().current_scene
	if world_root == null:
		return candidate
	var houses: Array[Node3D] = []
	for child: Node in world_root.get_children():
		if child is VillageHouse:
			houses.append(child as Node3D)
	for house: Node3D in houses:
		var hx: float = house.global_position.x
		var hz: float = house.global_position.z
		if absf(candidate.x - hx) < 6.4 and absf(candidate.y - hz) < 6.4:
			var push_x: float = hx + (-7.5 if candidate.x <= hx else 7.5)
			var push_z: float = hz + (-7.5 if candidate.y <= hz else 7.5)
			if absf(push_x) < absf(push_z):
				candidate.x = clampf(push_x, -26.0, 26.0)
			else:
				candidate.y = clampf(push_z, -26.0, 26.0)
	return candidate

func _begin_cutscene_ui(cutscene_type: String, overlay_name: String, title_text: String, title_color: Color, subtitle_text: String, hide_main_hud: bool) -> Dictionary:
	if is_cutscene_active():
		_finish_active_cutscene(true)

	var player: PlayerController = GameManager.player_character as PlayerController
	if inventory_overlay and inventory_overlay.visible:
		inventory_overlay.visible = false
		selected_swap_slot = -1
		if player:
			player.is_inventory_open = false
	if pause_menu:
		pause_menu.visible = false
	if pause_settings_container:
		pause_settings_container.visible = false
	if exit_confirm_overlay:
		exit_confirm_overlay.visible = false
	if barricade_dialog:
		barricade_dialog.visible = false
	if is_instance_valid(fate_card_overlay) and fate_card_overlay.is_open():
		fate_card_overlay.force_close()
	if mission_tween and mission_tween.is_running():
		mission_tween.kill()
	if mission_panel:
		mission_panel.visible = false
	if touch_root:
		touch_root.visible = false
	if desktop_hint_panel:
		desktop_hint_panel.visible = false
	if mp_overlay_panel:
		mp_overlay_panel.visible = false
	if hud_bag_button:
		hud_bag_button.visible = false
	if stare_warning:
		stare_warning.visible = false
	if jumpscare_tween and jumpscare_tween.is_running():
		jumpscare_tween.kill()
	if jumpscare_rect:
		jumpscare_rect.visible = false
	if interaction_label:
		interaction_label.text = ""
	var crosshair: Control = get_node_or_null("CenterContainer/Crosshair") as Control
	if crosshair:
		crosshair.visible = false
	if hide_main_hud:
		if top_left:
			top_left.visible = false
		if bottom_left:
			bottom_left.visible = false
		if bottom_center:
			bottom_center.visible = false

	if is_instance_valid(player):
		if player.camera:
			player.camera.current = false
		player.set_virtual_move(Vector2.ZERO)
		player.set_virtual_sprint(false)
		player.velocity = Vector3.ZERO
		if player.has_method("prepare_for_cutscene"):
			player.prepare_for_cutscene()
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)

	active_cutscene_type = cutscene_type
	active_cutscene_elapsed = 0.0
	active_cutscene_finish_cb = Callable()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	descent_cutscene_overlay = Control.new()
	descent_cutscene_overlay.name = overlay_name
	descent_cutscene_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	descent_cutscene_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	descent_cutscene_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	descent_cutscene_overlay.z_index = 30
	add_child(descent_cutscene_overlay)

	var top_bar := ColorRect.new()
	top_bar.color = Color(0.02, 0.01, 0.02, 0.80)
	top_bar.anchor_left = 0.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_bottom = 0.11
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	descent_cutscene_overlay.add_child(top_bar)

	var bot_bar := ColorRect.new()
	bot_bar.color = Color(0.02, 0.01, 0.02, 0.84)
	bot_bar.anchor_left = 0.0
	bot_bar.anchor_top = 0.85
	bot_bar.anchor_right = 1.0
	bot_bar.anchor_bottom = 1.0
	bot_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	descent_cutscene_overlay.add_child(bot_bar)

	var touch: bool = _is_touch_device()
	var title_lbl := Label.new()
	title_lbl.name = "CutsceneTitle"
	title_lbl.text = title_text
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.anchor_left = 0.18 if touch else 0.22
	title_lbl.anchor_top = 0.01
	title_lbl.anchor_right = 0.82 if touch else 0.78
	title_lbl.anchor_bottom = 0.11
	title_lbl.offset_left = 0.0
	title_lbl.offset_top = 0.0
	title_lbl.offset_right = 0.0
	title_lbl.offset_bottom = 0.0
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.add_theme_font_override("font", HORROR_TITLE_FONT)
	title_lbl.add_theme_font_size_override("font_size", 15 if touch else 19)
	title_lbl.add_theme_color_override("font_color", title_color)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	title_lbl.add_theme_constant_override("outline_size", 5)
	descent_cutscene_overlay.add_child(title_lbl)

	var subtitle_lbl := Label.new()
	subtitle_lbl.name = "CutsceneSubtitle"
	subtitle_lbl.text = subtitle_text
	subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_lbl.anchor_left = 0.05
	subtitle_lbl.anchor_top = 0.85
	subtitle_lbl.anchor_right = 0.95
	subtitle_lbl.anchor_bottom = 0.98
	subtitle_lbl.offset_left = 0.0
	subtitle_lbl.offset_top = 0.0
	subtitle_lbl.offset_right = 0.0
	subtitle_lbl.offset_bottom = 0.0
	subtitle_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_lbl.add_theme_font_size_override("font_size", 14 if touch else 18)
	subtitle_lbl.add_theme_color_override("font_color", Color(0.96, 0.88, 0.74, 1.0))
	subtitle_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	subtitle_lbl.add_theme_constant_override("outline_size", 4)
	descent_cutscene_overlay.add_child(subtitle_lbl)

	var skip_box := HBoxContainer.new()
	skip_box.name = "SkipContainer"
	skip_box.anchor_left = 0.82 if touch else 0.78
	skip_box.anchor_top = 0.018
	skip_box.anchor_right = 0.98
	skip_box.anchor_bottom = 0.095
	skip_box.alignment = BoxContainer.ALIGNMENT_END
	skip_box.add_theme_constant_override("separation", 8)
	skip_box.mouse_filter = Control.MOUSE_FILTER_PASS
	descent_cutscene_overlay.add_child(skip_box)

	if not touch:
		var skip_hint := Label.new()
		skip_hint.name = "SkipHint"
		skip_hint.text = LocScript.pick("[SPASI / ESC]", "[SPACE / ESC]")
		skip_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		HorrorTheme.style_label(skip_hint, "mono-sm", Color(0.82, 0.78, 0.72, 0.85), 11)
		skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skip_box.add_child(skip_hint)

	var skip_btn := Button.new()
	skip_btn.name = "SkipCutsceneButton"
	skip_btn.text = LocScript.pick("LEWATI >>", "SKIP >>")
	skip_btn.custom_minimum_size = Vector2(118.0, 40.0)
	skip_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	HorrorTheme.style_button(skip_btn, "secondary", 12, true)
	skip_btn.pressed.connect(_skip_active_cutscene)
	skip_box.add_child(skip_btn)

	var fade_rect := ColorRect.new()
	fade_rect.name = "FadeRect"
	fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	descent_cutscene_overlay.add_child(fade_rect)

	active_cutscene_camera = Camera3D.new()
	active_cutscene_camera.name = "ActiveCutsceneCamera"
	active_cutscene_camera.process_mode = Node.PROCESS_MODE_ALWAYS
	active_cutscene_camera.fov = maxf(player.camera.fov if (player and player.camera) else 68.0, 66.0)

	var fill_light := OmniLight3D.new()
	fill_light.name = "CutsceneFillLight"
	fill_light.omni_range = 28.0
	fill_light.light_energy = 2.0
	fill_light.light_color = Color(0.65, 0.95, 0.75)
	active_cutscene_camera.add_child(fill_light)

	if get_tree().current_scene:
		get_tree().current_scene.add_child(active_cutscene_camera)
	else:
		add_child(active_cutscene_camera)
	active_cutscene_camera.current = true

	return {
		"camera": active_cutscene_camera,
		"fill_light": fill_light,
		"fade_rect": fade_rect,
		"crosshair": crosshair
	}

func _skip_active_cutscene() -> void:
	if not is_cutscene_active():
		return
	_finish_active_cutscene(true)

func _finish_active_cutscene(skipped: bool) -> void:
	if active_cutscene_type.is_empty() and not is_instance_valid(descent_cutscene_overlay):
		return
	var finish_cb: Callable = active_cutscene_finish_cb
	active_cutscene_finish_cb = Callable()
	active_cutscene_type = ""
	if descent_camera_tween and descent_camera_tween.is_running():
		descent_camera_tween.kill()
	descent_camera_tween = null
	if finish_cb.is_valid():
		finish_cb.call(skipped)
	for vfx_node: Node in _cutscene_vfx_nodes:
		if is_instance_valid(vfx_node):
			vfx_node.queue_free()
	_cutscene_vfx_nodes.clear()
	if is_instance_valid(active_cutscene_camera):
		active_cutscene_camera.queue_free()
	active_cutscene_camera = null
	if is_instance_valid(descent_cutscene_overlay):
		descent_cutscene_overlay.queue_free()
	descent_cutscene_overlay = null
	_refresh_online_room_overlay(true)
	cutscene_finished.emit(skipped)

func _play_lampor_descent_cutscene() -> void:
	var player: PlayerController = GameManager.player_character as PlayerController
	if not is_instance_valid(player) or not player.camera:
		return
	var lampor: LamporStateMachine = get_tree().current_scene.find_child("LamporAI", true, false) as LamporStateMachine
	if not lampor:
		return

	var mp: Variant = _mp()
	if mp == null or not mp.is_online_session or mp.is_room_owner:
		lampor.trigger_descent(true)
	var ctx: Dictionary = _begin_cutscene_ui(
		"descent",
		"DescentCutsceneOverlay",
		LocScript.pick("BABAK II: KERANDA LAMPOR TURUN KE DESA", "ACT II: LAMPOR'S COFFIN DESCENDS"),
		Color(1.0, 0.25, 0.2, 1.0),
		LocScript.pick("Lampor mendarat dari langit malam... Bersiaplah, Lampor langsung mengejarmu!", "Lampor lands from the night sky... Brace yourself, the hunt begins now!"),
		false
	)
	AudioManager.play_voice_by_id("vo_cutscene_descent_sub_01")
	var cutscene_camera: Camera3D = ctx["camera"]
	var crosshair: Control = ctx["crosshair"]

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
	AudioManager.play_sound("lampor_roar", 1.0)

	active_cutscene_finish_cb = func(_skipped: bool) -> void:
		AudioManager.stop_sound("lampor_roar")
		if is_instance_valid(player):
			player.in_cutscene = false
			player.camera.current = true
			player.set_physics_process(true)
			player.set_process_unhandled_input(true)
			player._sync_hand_prop_visibility()
			player._sync_flashlight_state(true)
		if is_instance_valid(crosshair):
			crosshair.visible = true
		if touch_root and _is_touch_device() and not get_tree().paused:
			touch_root.visible = true
		if desktop_hint_panel and not _is_touch_device() and not get_tree().paused:
			desktop_hint_panel.visible = true
		if hud_bag_button:
			hud_bag_button.visible = true
		if not get_tree().paused:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _is_touch_device() else Input.MOUSE_MODE_CAPTURED
		var mp_cb: Variant = _mp()
		if (mp_cb == null or not mp_cb.is_online_session or mp_cb.is_room_owner) and is_instance_valid(lampor) and lampor.current_state != LamporStateMachine.State.CHASE and lampor.current_state != LamporStateMachine.State.BANISHED:
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
		if not GameManager.is_resuming_saved_run and not GameManager.is_tutorial_mode and not bool(GameManager.fate_cards_offered_acts.get(2, false)):
			call_deferred("_try_offer_fate_card", 2)

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
	descent_camera_tween.tween_callback(func() -> void: _finish_active_cutscene(false))

func play_victory_cutscene_and_wait() -> void:
	var lampor: LamporStateMachine = get_tree().current_scene.find_child("LamporAI", true, false) as LamporStateMachine
	var player: PlayerController = GameManager.player_character as PlayerController
	var ctx: Dictionary = _begin_cutscene_ui(
		"victory",
		"VictoryCutsceneOverlay",
		LocScript.pick("FAJAR MENYINGSING: KUTUKAN MUSNAH", "DAWN BREAKS: THE CURSE SHATTERS"),
		Color(1.0, 0.86, 0.35, 1.0),
		LocScript.pick("Cahaya langit menyambar dan menarik Keranda Lampor ke atas hingga lenyap!", "Heavenly light strikes down, pulling Lampor's coffin skyward until it vanishes!"),
		true
	)
	AudioManager.play_voice_by_id("vo_cutscene_victory_sub_01")
	var cutscene_camera: Camera3D = ctx["camera"]
	var fill_light: OmniLight3D = ctx["fill_light"]
	var fade_rect: ColorRect = ctx["fade_rect"]
	if fill_light:
		fill_light.light_color = Color(0.55, 0.95, 1.0)
		fill_light.light_energy = 2.6

	var pref_xz := Vector2(0.0, -7.0)
	if is_instance_valid(lampor) and lampor.current_state != LamporStateMachine.State.DORMANT_SKY:
		pref_xz = Vector2(lampor.global_position.x, lampor.global_position.z)
	elif is_instance_valid(player):
		pref_xz = Vector2(player.global_position.x, player.global_position.z - 8.0)
	var stage_xz: Vector2 = _open_stage_xz(pref_xz)

	var vfx_root := Node3D.new()
	vfx_root.name = "UfoBeamVFX"
	vfx_root.process_mode = Node.PROCESS_MODE_ALWAYS
	vfx_root.position = Vector3(stage_xz.x, 0.0, stage_xz.y)
	if get_tree().current_scene:
		get_tree().current_scene.add_child(vfx_root)
	_cutscene_vfx_nodes.append(vfx_root)

	var beam_inner_mat := StandardMaterial3D.new()
	beam_inner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_inner_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_inner_mat.albedo_color = Color(0.75, 0.98, 1.0, 0.0)

	var beam_outer_mat := StandardMaterial3D.new()
	beam_outer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_outer_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_outer_mat.albedo_color = Color(0.20, 0.88, 1.0, 0.0)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(1.0, 0.94, 0.65, 0.0)

	var disc_mat := StandardMaterial3D.new()
	disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc_mat.albedo_color = Color(0.85, 0.98, 1.0, 1.0)

	var beam_inner := MeshInstance3D.new()
	var inner_cyl := CylinderMesh.new()
	inner_cyl.top_radius = 1.15
	inner_cyl.bottom_radius = 2.0
	inner_cyl.height = 50.0
	beam_inner.mesh = inner_cyl
	beam_inner.material_override = beam_inner_mat
	beam_inner.position = Vector3(0.0, 25.0, 0.0)
	vfx_root.add_child(beam_inner)

	var beam_outer := MeshInstance3D.new()
	var outer_cyl := CylinderMesh.new()
	outer_cyl.top_radius = 2.1
	outer_cyl.bottom_radius = 3.8
	outer_cyl.height = 50.0
	beam_outer.mesh = outer_cyl
	beam_outer.material_override = beam_outer_mat
	beam_outer.position = Vector3(0.0, 25.0, 0.0)
	vfx_root.add_child(beam_outer)

	var ufo_disc := MeshInstance3D.new()
	var disc_cyl := CylinderMesh.new()
	disc_cyl.top_radius = 5.5
	disc_cyl.bottom_radius = 3.2
	disc_cyl.height = 1.4
	ufo_disc.mesh = disc_cyl
	ufo_disc.material_override = disc_mat
	ufo_disc.position = Vector3(0.0, 48.5, 0.0)
	vfx_root.add_child(ufo_disc)

	var beam_light := SpotLight3D.new()
	beam_light.position = Vector3(0.0, 38.0, 0.0)
	beam_light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	beam_light.light_color = Color(0.55, 0.95, 1.0)
	beam_light.light_energy = 12.0
	beam_light.spot_range = 48.0
	beam_light.spot_angle = 28.0
	vfx_root.add_child(beam_light)

	var energy_rings: Array[MeshInstance3D] = []
	for ri: int in range(4):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 1.75
		torus.outer_radius = 2.05
		ring.mesh = torus
		ring.material_override = ring_mat
		ring.position = Vector3(0.0, float(ri) * 10.0, 0.0)
		vfx_root.add_child(ring)
		energy_rings.append(ring)

	if is_instance_valid(lampor):
		if lampor.descent_tween and lampor.descent_tween.is_running():
			lampor.descent_tween.kill()
		lampor.is_descending = false
		lampor.is_catching = false
		lampor.visible = true
		lampor.current_state = LamporStateMachine.State.BANISHED
		lampor.global_position = Vector3(stage_xz.x, 2.3, stage_xz.y)
		if lampor.red_light:
			lampor.red_light.light_color = Color(0.35, 0.95, 1.0)
			lampor.red_light.light_energy = 6.0

	var cam_start := Vector3(stage_xz.x + 7.5, 2.0, stage_xz.y + 10.5)
	var cam_end := Vector3(stage_xz.x - 3.5, 1.4, stage_xz.y + 8.5)
	cutscene_camera.global_position = cam_start
	AudioManager.play_sound("ufo_beam", 0.0)
	AudioManager.play_sound("lampor_roar", 2.0, 1.25)

	active_cutscene_finish_cb = func(_skipped: bool) -> void:
		AudioManager.stop_sound("ufo_beam")
		AudioManager.stop_sound("lampor_roar")
		if is_instance_valid(lampor):
			lampor.visible = false

	descent_camera_tween = create_tween()
	descent_camera_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	descent_camera_tween.tween_method(func(progress: float) -> void:
		var beam_fade: float = clampf(progress / 0.16, 0.0, 1.0)
		if progress > 0.85:
			beam_fade *= clampf((1.0 - progress) / 0.15, 0.0, 1.0)
		beam_inner_mat.albedo_color.a = 0.42 * beam_fade
		beam_outer_mat.albedo_color.a = 0.18 * beam_fade
		ring_mat.albedo_color.a = 0.72 * beam_fade
		var pulse: float = 0.85 + 0.25 * sin(progress * TAU * 8.0)
		beam_inner.scale = Vector3(pulse * beam_fade, 1.0, pulse * beam_fade)
		beam_outer.scale = Vector3(beam_fade, 1.0, beam_fade)
		beam_light.light_energy = 14.0 * beam_fade

		for ri: int in range(energy_rings.size()):
			var ring_prog: float = fmod(progress * 3.2 + float(ri) * 0.25, 1.0)
			energy_rings[ri].position.y = lerpf(0.6, 46.5, ring_prog)
			var ring_scl: float = lerpf(1.25, 0.65, ring_prog)
			energy_rings[ri].scale = Vector3(ring_scl, 1.0, ring_scl)

		var target_focus := Vector3(stage_xz.x, 4.0, stage_xz.y)
		if is_instance_valid(lampor):
			var lift_prog: float = clampf((progress - 0.15) / 0.72, 0.0, 1.0)
			var cur_y: float = lerpf(2.3, 47.0, lift_prog * lift_prog)
			var wobble: float = sin(progress * 26.0) * (1.0 - lift_prog * 0.5) * 0.28
			lampor.global_position = Vector3(stage_xz.x + wobble * 0.4, cur_y, stage_xz.y)
			lampor.rotation.y += 0.09
			lampor.rotation.z = wobble * 0.35
			lampor.visible = (progress < 0.88)
			target_focus = Vector3(stage_xz.x, clampf(cur_y, 2.3, 28.0), stage_xz.y)

		if is_instance_valid(cutscene_camera):
			cutscene_camera.global_position = cam_start.lerp(cam_end, ease(progress, -1.4))
			if cutscene_camera.global_position.distance_squared_to(target_focus) > 0.05:
				cutscene_camera.look_at(target_focus, Vector3.UP)

		if is_instance_valid(fade_rect) and progress > 0.84:
			var f: float = clampf((progress - 0.84) / 0.16, 0.0, 1.0)
			fade_rect.color = Color(0.95, 0.85, 0.55, f * 0.92)
	, 0.0, 1.0, 4.8)
	descent_camera_tween.tween_callback(func() -> void: _finish_active_cutscene(false))
	await cutscene_finished

func play_death_cutscene_and_wait() -> void:
	var player: PlayerController = GameManager.player_character as PlayerController
	var lampor: LamporStateMachine = get_tree().current_scene.find_child("LamporAI", true, false) as LamporStateMachine

	if is_instance_valid(player) and player.is_hiding:
		player.exit_hiding()

	var pref_xz := Vector2(0.0, 6.0)
	if is_instance_valid(player):
		if player.is_inside_house and is_instance_valid(player.current_house):
			pref_xz = Vector2(player.current_house.global_position.x, player.current_house.global_position.z + 7.5)
		else:
			pref_xz = Vector2(player.global_position.x, player.global_position.z)
	var stage_xz: Vector2 = _open_stage_xz(pref_xz)

	var ctx: Dictionary = _begin_cutscene_ui(
		"death",
		"DeathCutsceneOverlay",
		LocScript.pick("DITANGKAP KERANDA LAMPOR", "CLAIMED BY LAMPOR'S COFFIN"),
		Color(1.0, 0.2, 0.18, 1.0),
		LocScript.pick("Lampor mengangkat tubuhmu dan membawamu pergi ke dalam kegelapan malam...", "Lampor hoists you skyward and carries you into the pitch-black night..."),
		true
	)
	AudioManager.play_voice_by_id("vo_cutscene_death_sub_01")
	var cutscene_camera: Camera3D = ctx["camera"]
	var fill_light: OmniLight3D = ctx["fill_light"]
	var fade_rect: ColorRect = ctx["fade_rect"]
	if fill_light:
		fill_light.light_color = Color(1.0, 0.45, 0.38)
		fill_light.light_energy = 2.4

	if is_instance_valid(player):
		player.visible = true
		if player.player_model:
			player.player_model.visible = true
			player.player_model.position = Vector3.ZERO
			player.player_model.rotation.y = PI
		player.global_position = Vector3(stage_xz.x, 0.1, stage_xz.y)
		if player.has_method("pose_abducted_dangle"):
			player.pose_abducted_dangle(0.0)

	var tether_root := Node3D.new()
	tether_root.name = "AbductionTetherVFX"
	tether_root.process_mode = Node.PROCESS_MODE_ALWAYS
	if get_tree().current_scene:
		get_tree().current_scene.add_child(tether_root)
	_cutscene_vfx_nodes.append(tether_root)

	var tether_mat := StandardMaterial3D.new()
	tether_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tether_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tether_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	tether_mat.albedo_color = Color(0.95, 0.14, 0.12, 0.0)

	var tether_mesh := MeshInstance3D.new()
	var tether_cyl := CylinderMesh.new()
	tether_cyl.top_radius = 0.55
	tether_cyl.bottom_radius = 0.95
	tether_cyl.height = 2.2
	tether_mesh.mesh = tether_cyl
	tether_mesh.material_override = tether_mat
	tether_root.add_child(tether_mesh)

	var lampor_start := Vector3(stage_xz.x - 4.0, 5.2, stage_xz.y - 5.5)
	var lampor_hover := Vector3(stage_xz.x, 2.5, stage_xz.y)
	var lampor_lift := Vector3(stage_xz.x, 3.6, stage_xz.y)
	var escape_dir := Vector3(0.58, 0.38, -0.72).normalized()
	var lampor_exit := lampor_lift + escape_dir * 44.0

	if is_instance_valid(lampor):
		if lampor.descent_tween and lampor.descent_tween.is_running():
			lampor.descent_tween.kill()
		lampor.is_descending = false
		lampor.is_catching = false
		lampor.visible = true
		lampor.global_position = lampor_start
		if lampor.red_light:
			lampor.red_light.light_color = Color(1.0, 0.14, 0.10)
			lampor.red_light.light_energy = 5.5
		lampor.safe_look_at(Vector3(stage_xz.x, lampor_start.y, stage_xz.y))

	var cam_pos_start := Vector3(stage_xz.x + 5.8, 1.8, stage_xz.y + 6.4)
	var cam_pos_end := Vector3(stage_xz.x + 2.8, 1.4, stage_xz.y + 8.8)
	cutscene_camera.global_position = cam_pos_start
	AudioManager.play_sound("lampor_roar", 2.0, 0.92)
	AudioManager.play_sound("lampor_bell", 1.0, 0.95)

	active_cutscene_finish_cb = func(_skipped: bool) -> void:
		AudioManager.stop_sound("lampor_roar")
		AudioManager.stop_sound("lampor_bell")

	descent_camera_tween = create_tween()
	descent_camera_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	descent_camera_tween.tween_method(func(progress: float) -> void:
		var cur_lampor_pos := lampor_hover
		var cur_player_pos := Vector3(stage_xz.x, 0.1, stage_xz.y)
		var tether_alpha: float = 0.0

		if progress < 0.24:
			# Fase 1: Lampor menyambar turun ke atas pemain
			var p1: float = clampf(progress / 0.24, 0.0, 1.0)
			cur_lampor_pos = lampor_start.lerp(lampor_hover, ease(p1, -1.6))
			cur_player_pos = Vector3(stage_xz.x, 0.1, stage_xz.y)
			tether_alpha = p1 * 0.28
		elif progress < 0.46:
			# Fase 2: Pemain diangkat ke udara di bawah keranda Lampor
			var p2: float = clampf((progress - 0.24) / 0.22, 0.0, 1.0)
			cur_lampor_pos = lampor_hover.lerp(lampor_lift, ease(p2, -1.3))
			cur_player_pos = Vector3(stage_xz.x, lerpf(0.1, cur_lampor_pos.y - 1.9, ease(p2, -1.2)), stage_xz.y)
			tether_alpha = 0.36
		else:
			# Fase 3: Lampor membawa pemain terbang menjauh ke langit malam
			var p3: float = clampf((progress - 0.46) / 0.54, 0.0, 1.0)
			cur_lampor_pos = lampor_lift.lerp(lampor_exit, p3 * p3 * 0.45 + p3 * 0.55)
			cur_player_pos = cur_lampor_pos + Vector3(0.0, -1.9, 0.0)
			tether_alpha = 0.32 * clampf(1.0 - p3 * 0.6, 0.1, 1.0)

		tether_mat.albedo_color.a = tether_alpha
		tether_root.global_position = cur_lampor_pos + Vector3(0.0, -1.1, 0.0)

		if is_instance_valid(lampor):
			lampor.global_position = cur_lampor_pos
			if progress >= 0.44:
				lampor.safe_look_at(lampor_exit)
			else:
				lampor.safe_look_at(cur_player_pos)

		if is_instance_valid(player):
			player.global_position = cur_player_pos
			player.rotation.y = sin(progress * 9.0) * 0.22
			if player.has_method("pose_abducted_dangle"):
				player.pose_abducted_dangle(progress * 4.0)

		if is_instance_valid(cutscene_camera):
			cutscene_camera.global_position = cam_pos_start.lerp(cam_pos_end, progress)
			var look_target: Vector3 = cur_lampor_pos.lerp(cur_player_pos, 0.45)
			if cutscene_camera.global_position.distance_squared_to(look_target) > 0.05:
				cutscene_camera.look_at(look_target, Vector3.UP)

		if is_instance_valid(fade_rect) and progress > 0.84:
			var f: float = clampf((progress - 0.84) / 0.16, 0.0, 1.0)
			fade_rect.color = Color(0.04, 0.0, 0.0, f)
	, 0.0, 1.0, 5.2)
	descent_camera_tween.tween_callback(func() -> void: _finish_active_cutscene(false))
	await cutscene_finished

func _show_act_banner(num: int, _title: String) -> void:
	if banner_tween:
		banner_tween.kill()

	# Banner lama digantikan kartu misi (teks banner dipakai sebagai judul kartu)
	act_banner.visible = false
	act_banner.modulate.a = 0.0

	match num:
		1:
			act_banner.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
			act_banner.text = LocScript.pick("BABAK I: PERTAHANAN AWAL (01.00 WIB)", "ACT I: EARLY DEFENSE (01:00 WIB)")
		2:
			act_banner.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
			act_banner.text = LocScript.pick("BABAK II: LAMPOR TURUN KE DESA", "ACT II: LAMPOR DESCENDS ON THE VILLAGE")
			AudioManager.play_sound("lampor_roar", 1.0)
		3:
			act_banner.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1))
			act_banner.text = LocScript.pick("BABAK III: KLIMAKS PEMBAKARAN", "ACT III: BURNING CLIMAX")
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
		
	var status_icon: String = LocScript.pick("[Selesai]", "[Done]") if is_completed else "◆"
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
			label.text = LocScript.pick("[Kosong]", "[Empty]")
			label.add_theme_color_override("font_color", Color(HorrorTheme.OUTLINE.r, HorrorTheme.OUTLINE.g, HorrorTheme.OUTLINE.b, 0.72))
			qty_label.text = ""
		else:
			var raw_id: String = str(item.get("id", ""))
			var raw_name: String = str(item.get("name", ""))
			label.text = LocScript.item_name(raw_id, raw_name) if not raw_id.is_empty() else raw_name
			label.add_theme_color_override("font_color", HorrorTheme.ON_PRIMARY_CONTAINER if is_active else HorrorTheme.ON_SURFACE)
			if raw_id == "flashlight":
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
		stare_warning.text = LocScript.pick("JANGAN MENATAP LANGSUNG! ALIHKAN PANDANGANMU!", "DO NOT STARE DIRECTLY! LOOK AWAY NOW!")
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
	inventory_overlay.color = Color(HorrorTheme.SCRIM_DARK.r, HorrorTheme.SCRIM_DARK.g, HorrorTheme.SCRIM_DARK.b, 0.68)
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
		HorrorTheme.make_minimal_panel_style(
			Color(0.086, 0.045, 0.043, 0.96),
			HorrorTheme.BORDER_INTERACTIVE,
			2,
			20,
			16
		)
	)
	center.add_child(inventory_modal_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 9)
	inventory_modal_panel.add_child(main_vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	main_vbox.add_child(header)

	var title_lbl := Label.new()
	_inv_title_lbl = title_lbl
	title_lbl.text = LocScript.pick("TAS BEKAL & INVENTARIS", "BACKPACK & INVENTORY")
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HorrorTheme.style_label(title_lbl, "headline-md", HorrorTheme.ON_SURFACE, 16)
	header.add_child(title_lbl)

	var close_btn := Button.new()
	_inv_close_btn = close_btn
	close_btn.text = LocScript.pick("TUTUP [%s]" % SettingsManager.get_action_key_text("toggle_inventory"), "CLOSE [%s]" % SettingsManager.get_action_key_text("toggle_inventory"))
	close_btn.custom_minimum_size = Vector2(114.0, 44.0)
	HorrorTheme.style_button(close_btn, "ghost", 11, true)
	close_btn.pressed.connect(toggle_inventory)
	header.add_child(close_btn)

	main_vbox.add_child(HorrorTheme.make_hairline_divider())

	var storage_lbl := Label.new()
	_inv_storage_lbl = storage_lbl
	storage_lbl.text = LocScript.pick("TAS  ·  15 SLOT", "BAG  ·  15 SLOTS")
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

	main_vbox.add_child(HorrorTheme.make_hairline_divider())

	var hotbar_lbl := Label.new()
	_inv_hotbar_lbl = hotbar_lbl
	hotbar_lbl.text = LocScript.pick("HOTBAR  ·  5 SLOT", "HOTBAR  ·  5 SLOTS")
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

	var hint_lbl := Label.new()
	_inv_hint_lbl = hint_lbl
	hint_lbl.text = LocScript.pick("Tarik atau ketuk dua slot untuk menukar barang.", "Drag or click two slots to swap items.")
	hint_lbl.custom_minimum_size.x = 340.0
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	HorrorTheme.style_label(hint_lbl, "label-sm", HorrorTheme.TEXT_MUTED, 11)
	main_vbox.add_child(hint_lbl)

func toggle_inventory() -> void:
	if descent_cutscene_overlay and is_instance_valid(descent_cutscene_overlay) and descent_cutscene_overlay.visible:
		return
	if is_fate_card_overlay_open():
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
			player.release_all_held_inputs()
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

func _build_fate_cards_strip() -> void:
	var tl_vbox: VBoxContainer = top_left.get_node_or_null("VBox") as VBoxContainer if top_left else null
	if not tl_vbox:
		return
	fate_cards_strip = VBoxContainer.new()
	fate_cards_strip.name = "FateCardsStrip"
	fate_cards_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fate_cards_strip.add_theme_constant_override("separation", 4)
	var touch: bool = _is_touch_device()
	var view_w: float = get_viewport().get_visible_rect().size.x
	var strip_w: float = (clampf(view_w * 0.34, 260.0, 350.0) - 16.0) if touch else 380.0
	fate_cards_strip.custom_minimum_size.x = strip_w
	fate_cards_strip.visible = false
	tl_vbox.add_child(fate_cards_strip)

func _refresh_fate_cards_strip() -> void:
	if not is_instance_valid(fate_cards_strip):
		return
	for child: Node in fate_cards_strip.get_children():
		fate_cards_strip.remove_child(child)
		child.queue_free()

	var cards: Array[Dictionary] = GameManager.active_fate_cards
	fate_cards_strip.visible = not cards.is_empty()
	if cards.is_empty():
		return

	var touch: bool = _is_touch_device()
	for card: Dictionary in cards:
		var is_blessing: bool = str(card.get("type", "curse")) == "blessing"
		var pill := PanelContainer.new()
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bg_col: Color = Color(0.08, 0.16, 0.10, 0.88) if is_blessing else Color(0.24, 0.05, 0.06, 0.90)
		var border_col: Color = HorrorTheme.RELIC_BRASS if is_blessing else HorrorTheme.ACCENT
		pill.add_theme_stylebox_override("panel", HorrorTheme.make_chip_style(bg_col, border_col, 3, 8, 5))
		var card_desc: String = FATE_CARD_SYSTEM_SCRIPT.get_card_description(card)
		pill.tooltip_text = card_desc

		var card_box := VBoxContainer.new()
		card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_box.add_theme_constant_override("separation", 2)
		pill.add_child(card_box)

		var lbl := Label.new()
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_prefix: String = "✦ " if is_blessing else "☠ "
		lbl.text = icon_prefix + FATE_CARD_SYSTEM_SCRIPT.get_card_title(card)
		var text_col: Color = Color("f2cb72") if is_blessing else HorrorTheme.PRIMARY
		HorrorTheme.style_label(lbl, "label-sm", text_col, 10 if touch else 11)
		lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
		lbl.add_theme_constant_override("outline_size", 2)
		card_box.add_child(lbl)

		if not card_desc.strip_edges().is_empty():
			var desc_lbl := Label.new()
			desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			desc_lbl.text = card_desc
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			HorrorTheme.style_label(desc_lbl, "body-sm", Color("e8dad6"), 9 if touch else 10)
			desc_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.90))
			desc_lbl.add_theme_constant_override("outline_size", 1)
			card_box.add_child(desc_lbl)

		fate_cards_strip.add_child(pill)

func _mount_fate_card_overlay() -> void:
	if fate_card_overlay == null and FATE_CARD_OVERLAY_SCRIPT != null:
		fate_card_overlay = FATE_CARD_OVERLAY_SCRIPT.new() as FATE_CARD_OVERLAY_SCRIPT
		if fate_card_overlay:
			fate_card_overlay.overlay_opened.connect(_on_fate_overlay_opened)
			fate_card_overlay.overlay_closed.connect(_on_fate_overlay_closed)
			add_child(fate_card_overlay)

func _schedule_fate_card_offer(act_num: int, delay_sec: float) -> void:
	if act_num < 1 or act_num > 3:
		return
	if GameManager.is_tutorial_mode or GameManager.is_resuming_saved_run:
		return
	if bool(GameManager.fate_cards_offered_acts.get(act_num, false)):
		return
	if bool(_pending_fate_offers.get(act_num, false)):
		return
	_pending_fate_offers[act_num] = true
	get_tree().create_timer(maxf(0.05, delay_sec), true, false, false).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		_try_offer_fate_card(act_num)
	)

func _try_offer_fate_card(act_num: int) -> void:
	_pending_fate_offers.erase(act_num)
	if not is_inside_tree():
		return
	if GameManager.is_tutorial_mode or GameManager.is_resuming_saved_run:
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if GameManager.death_sequence_active or GameManager.victory_sequence_active:
		return
	if bool(GameManager.fate_cards_offered_acts.get(act_num, false)):
		return
	if not is_instance_valid(fate_card_overlay):
		return
	var modal_blocking: bool = is_cutscene_active() \
		or is_fate_card_overlay_open() \
		or get_tree().paused \
		or (pause_menu and pause_menu.visible) \
		or (barricade_dialog and barricade_dialog.visible) \
		or (exit_confirm_overlay and exit_confirm_overlay.visible) \
		or (inventory_overlay and inventory_overlay.visible)
	if modal_blocking:
		_schedule_fate_card_offer(act_num, 0.35)
		return
	var pair: Dictionary = GameManager.request_fate_card_pair_for_act(act_num)
	if pair.is_empty():
		return
	fate_card_overlay.open_choice(act_num, pair)

func _on_fate_card_applied(_card_data: Dictionary) -> void:
	_refresh_fate_cards_strip()

func _on_fate_cards_reset() -> void:
	_pending_fate_offers.clear()
	if is_instance_valid(fate_card_overlay) and fate_card_overlay.is_open():
		fate_card_overlay.force_close()
	_refresh_fate_cards_strip()

func _on_fate_overlay_opened() -> void:
	joystick_vector = Vector2.ZERO
	if desktop_hint_panel:
		desktop_hint_panel.visible = false
	if touch_root:
		touch_root.visible = false

func _on_fate_overlay_closed(_chosen_card: Dictionary) -> void:
	_refresh_fate_cards_strip()
	if not get_tree().paused and not is_cutscene_active() and GameManager.current_state == GameManager.GameState.PLAYING:
		if touch_root and _is_touch_device():
			touch_root.visible = true
		if desktop_hint_panel and not _is_touch_device():
			desktop_hint_panel.visible = true
