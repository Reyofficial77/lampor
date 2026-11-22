class_name TutorialOverlay
extends Control

const LocScript = preload("res://scripts/systems/Loc.gd")

var card: PanelContainer
var content_box: VBoxContainer
var step_badge: Label
var title_label: Label
var body_label: Label
var goal_label: Label
var next_btn: Button
var min_btn: Button
var skip_btn: Button

var current_step: int = 1
const TOTAL_STEPS: int = 7
var spawn_pos: Vector3 = Vector3.ZERO
var spawn_recorded: bool = false
var initial_item_total: int = -1
var dismissed: bool = false
var is_minimized: bool = false

func _ready() -> void:
	name = "TutorialOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 6
	_build_ui()

	SignalBus.inventory_updated.connect(_on_inventory_updated)
	SignalBus.torch_lit.connect(_on_torch_lit)
	SignalBus.act_started.connect(_on_act_started)
	SignalBus.ritual_item_collected.connect(_on_ritual_item_collected)
	SettingsManager.language_changed.connect(func(_l: String) -> void: _refresh_step_content())
	SettingsManager.keybinds_changed.connect(func() -> void: _refresh_step_content())
	get_viewport().size_changed.connect(_apply_layout)
	_refresh_step_content()

func _build_ui() -> void:
	card = PanelContainer.new()
	card.name = "TutorialCard"
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_theme_stylebox_override(
		"panel",
		HorrorTheme.make_minimal_panel_style(
			Color(0.08, 0.042, 0.04, 0.84),
			HorrorTheme.BORDER_INTERACTIVE,
			2,
			12,
			9
		)
	)
	add_child(card)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 5)
	outer_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(outer_vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 5)
	outer_vbox.add_child(top_row)

	step_badge = Label.new()
	step_badge.text = "TUTORIAL · 1/7"
	step_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HorrorTheme.style_label(step_badge, "mono-sm", HorrorTheme.PRIMARY, 10)
	top_row.add_child(step_badge)

	min_btn = Button.new()
	min_btn.text = "-"
	min_btn.tooltip_text = "Perkecil / perbesar panduan"
	min_btn.custom_minimum_size = Vector2(32.0, 30.0)
	HorrorTheme.style_button(min_btn, "ghost", 12, false)
	min_btn.pressed.connect(_toggle_minimize)
	top_row.add_child(min_btn)

	next_btn = Button.new()
	next_btn.text = "LANJUT"
	next_btn.custom_minimum_size = Vector2(64.0, 30.0)
	HorrorTheme.style_button(next_btn, "secondary", 10, true)
	next_btn.pressed.connect(_on_next_pressed)
	top_row.add_child(next_btn)

	skip_btn = Button.new()
	skip_btn.text = LocScript.pick("TUTUP", "CLOSE")
	skip_btn.custom_minimum_size = Vector2(56.0, 30.0)
	HorrorTheme.style_button(skip_btn, "ghost", 10, true)
	skip_btn.pressed.connect(_on_skip_pressed)
	top_row.add_child(skip_btn)

	content_box = VBoxContainer.new()
	content_box.add_theme_constant_override("separation", 4)
	content_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer_vbox.add_child(content_box)

	content_box.add_child(HorrorTheme.make_hairline_divider(Color(HorrorTheme.OUTLINE_VARIANT.r, HorrorTheme.OUTLINE_VARIANT.g, HorrorTheme.OUTLINE_VARIANT.b, 0.45)))

	title_label = Label.new()
	title_label.custom_minimum_size.x = 320.0
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	HorrorTheme.style_label(title_label, "title-lg", HorrorTheme.ON_SURFACE, 12)
	content_box.add_child(title_label)

	body_label = Label.new()
	body_label.custom_minimum_size.x = 320.0
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	HorrorTheme.style_label(body_label, "body-md", HorrorTheme.ON_SURFACE_VARIANT, 11)
	content_box.add_child(body_label)

	goal_label = Label.new()
	goal_label.custom_minimum_size.x = 320.0
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	HorrorTheme.style_label(goal_label, "label-sm", HorrorTheme.RELIC_BRASS, 11)
	content_box.add_child(goal_label)

func _toggle_minimize() -> void:
	is_minimized = not is_minimized
	if content_box:
		content_box.visible = not is_minimized
	if min_btn:
		min_btn.text = "+" if is_minimized else "-"
	_apply_layout()

func _is_touch() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("android") or OS.has_feature("ios")

func _apply_layout() -> void:
	if not card:
		return
	var view_size: Vector2 = get_viewport_rect().size
	if view_size.x <= 0.0:
		view_size = Vector2(1280.0, 720.0)
	var touch: bool = _is_touch()
	var compact: bool = view_size.x < 750.0
	var card_w: float = clampf(view_size.x * (0.30 if touch else 0.31), 240.0, 360.0)
	var btn_h: float = 44.0 if touch else 30.0
	if min_btn:
		min_btn.custom_minimum_size = Vector2(44.0 if touch else 32.0, btn_h)
	if next_btn:
		next_btn.custom_minimum_size = Vector2(64.0, btn_h)
	if skip_btn:
		skip_btn.custom_minimum_size = Vector2(56.0, btn_h)

	var x_pos: float = (view_size.x - card_w) * 0.5
	if touch:
		var left_safe: float = clampf(view_size.x * 0.34, 250.0, 340.0) + 12.0
		var right_safe: float = view_size.x - clampf(view_size.x * 0.24, 198.0, 236.0) - 12.0
		if right_safe - left_safe >= 220.0:
			card_w = minf(card_w, right_safe - left_safe)
			x_pos = left_safe + (right_safe - left_safe - card_w) * 0.5

	var inner_w: float = maxf(180.0, card_w - 24.0)
	if title_label:
		title_label.custom_minimum_size.x = inner_w
	if body_label:
		body_label.custom_minimum_size.x = inner_w
	if goal_label:
		goal_label.custom_minimum_size.x = inner_w - 14.0

	card.custom_minimum_size = Vector2(card_w, 0.0)
	card.reset_size()
	card.size = Vector2(card_w, card.get_combined_minimum_size().y)
	card.position = Vector2(x_pos, 10.0 if compact else 12.0)
	call_deferred("_deferred_shrink_card", card_w, x_pos, 10.0 if compact else 12.0)

func _deferred_shrink_card(card_w: float, x_pos: float, y_pos: float) -> void:
	if not is_instance_valid(card):
		return
	card.reset_size()
	card.size = Vector2(card_w, card.get_combined_minimum_size().y)
	card.position = Vector2(x_pos, y_pos)

func _process(_delta: float) -> void:
	if dismissed or not GameManager.is_tutorial_mode:
		visible = false
		return

	var hud_node: Node = get_parent()
	var hide_for_modal: bool = get_tree().paused
	if hud_node:
		var inv_ov: Control = hud_node.get("inventory_overlay") as Control
		var cut_ov: Control = hud_node.get("descent_cutscene_overlay") as Control
		var bar_ov: Control = hud_node.get("barricade_dialog") as Control
		if (inv_ov and inv_ov.visible) or (cut_ov and is_instance_valid(cut_ov) and cut_ov.visible) or (bar_ov and bar_ov.visible):
			hide_for_modal = true
	visible = not hide_for_modal
	if not visible:
		return

	var player := GameManager.player_character as PlayerController
	if player and not spawn_recorded:
		spawn_pos = player.global_position
		spawn_recorded = true

	if current_step == 1 and player and spawn_recorded:
		if player.global_position.distance_to(spawn_pos) > 2.4:
			_advance_to_step(2)
	elif current_step == 3 and GameManager.torches_lit >= 1:
		_advance_to_step(4)
	elif current_step == 4 and GameManager.doors_barricaded >= 1:
		_advance_to_step(5)
	elif current_step < 6 and GameManager.current_act >= GameManager.Act.BABAK_2:
		_advance_to_step(6)
	elif current_step == 6 and (GameManager.current_act >= GameManager.Act.BABAK_3 or GameManager.get_ritual_item_count() >= GameManager.TOTAL_RITUAL_ITEMS):
		_advance_to_step(7)
	elif current_step == 7 and GameManager.furnace_burning:
		GameManager.mark_tutorial_completed()
		goal_label.text = "Target: Bertahanlah %d detik hingga pembakaran ritual selesai." % int(GameManager.furnace_total_time)

func _count_total_inventory_items(slots: Array) -> int:
	var total: int = 0
	for s: Variant in slots:
		if s is Dictionary and not (s as Dictionary).is_empty():
			total += int((s as Dictionary).get("quantity", 1))
	return total

func _on_inventory_updated(slots: Array) -> void:
	if dismissed or not GameManager.is_tutorial_mode:
		return
	var count: int = _count_total_inventory_items(slots)
	if initial_item_total < 0:
		initial_item_total = count
		return
	if current_step == 2 and count > initial_item_total:
		_advance_to_step(3)

func _on_torch_lit(_id: int, _total: int, _req: int) -> void:
	if dismissed or not GameManager.is_tutorial_mode:
		return
	if current_step == 3:
		_advance_to_step(4)
	else:
		_refresh_step_content()

func _on_act_started(act_num: int, _title: String) -> void:
	if dismissed or not GameManager.is_tutorial_mode:
		return
	if act_num == 2 and current_step < 6:
		_advance_to_step(6)
	elif act_num == 3 and current_step < 7:
		_advance_to_step(7)

func _on_ritual_item_collected(_name: String, count: int, total: int) -> void:
	if dismissed or not GameManager.is_tutorial_mode:
		return
	if count >= total and current_step < 7:
		_advance_to_step(7)
	else:
		_refresh_step_content()

func _on_next_pressed() -> void:
	if current_step < TOTAL_STEPS:
		_advance_to_step(current_step + 1)
	else:
		_on_skip_pressed()

func _on_skip_pressed() -> void:
	GameManager.mark_tutorial_completed()
	dismissed = true
	visible = false

func _advance_to_step(step: int) -> void:
	current_step = clampi(step, 1, TOTAL_STEPS)
	if current_step >= TOTAL_STEPS:
		GameManager.mark_tutorial_completed()
	_refresh_step_content()
	HorrorTheme.animate_surface_enter(card)

func _refresh_step_content() -> void:
	if not step_badge or not title_label or not body_label or not goal_label:
		return
	var touch: bool = _is_touch()
	var move_k: String = SettingsManager.get_move_keys_summary()
	var sprint_k: String = SettingsManager.get_action_key_text("sprint")
	var flash_k: String = SettingsManager.get_action_key_text("flashlight")
	var act_k: String = SettingsManager.get_action_key_text("interact")
	var slot_k: String = "%s-%s" % [SettingsManager.get_action_key_text("slot_1"), SettingsManager.get_action_key_text("slot_5")]
	if min_btn:
		min_btn.tooltip_text = LocScript.pick("Perkecil / perbesar panduan", "Collapse / expand guide")
	if skip_btn:
		skip_btn.text = LocScript.pick("TUTUP", "CLOSE")
	step_badge.text = "TUTORIAL · %d/%d" % [current_step, TOTAL_STEPS]
	next_btn.text = LocScript.pick("SELESAI" if current_step == TOTAL_STEPS else "LANJUT", "FINISH" if current_step == TOTAL_STEPS else "NEXT")

	match current_step:
		1:
			title_label.text = LocScript.pick("1. Pergerakan & Senter", "1. Movement & Flashlight")
			body_label.text = LocScript.pick(
				"Joystick kiri untuk jalan, ikon Lari untuk sprint, dan ikon Senter untuk lampu." if touch else "[%s] untuk jalan, [%s] untuk lari, [Mouse] menoleh, dan [%s] menyalakan Senter." % [move_k, sprint_k, flash_k],
				"Left joystick to walk, Sprint icon to run, and Flashlight icon for light." if touch else "[%s] to move, [%s] to sprint, [Mouse] to look around, and [%s] for Flashlight." % [move_k, sprint_k, flash_k]
			)
			goal_label.text = LocScript.pick("Target: Berjalanlah beberapa langkah di jalan desa.", "Goal: Take a few steps along the village road.")
		2:
			title_label.text = LocScript.pick("2. Ambil & Pakai Barang [%s]" % act_k, "2. Pick Up & Use Items [%s]" % act_k)
			body_label.text = LocScript.pick(
				"Ketuk ikon Tangan untuk semua interaksi: ambil barang, buka pintu, sembunyi, atau minum Jamu yang dipilih di hotbar." if touch else "Tekan [%s] untuk semua interaksi: ambil barang, buka pintu, sembunyi, atau minum Jamu/Baterai di hotbar [%s]." % [act_k, slot_k],
				"Tap the Hand icon for all interactions: loot items, open doors, hide, or drink elixirs from your hotbar." if touch else "Press [%s] to interact: pick up items, open doors, hide, or use Elixir/Battery on hotbar [%s]." % [act_k, slot_k]
			)
			goal_label.text = LocScript.pick("Target: Ambil 1 barang di sekitar desa (Minyak / Papan).", "Goal: Pick up 1 supply item around the village (Kerosene / Planks).")
		3:
			title_label.text = LocScript.pick("3. Nyalakan 5 Obor Penolak Bala", "3. Light 5 Repellent Torches")
			body_label.text = LocScript.pick(
				"Bawa Minyak Tanah & Korek, dekati obor padam di pinggir jalan, lalu tekan [%s]. Cahaya obor memulihkan Waras." % act_k,
				"Carry Kerosene & Matches, approach an unlit roadside torch, then press [%s]. Torchlight restores Sanity." % act_k
			)
			goal_label.text = LocScript.pick("Target: Nyalakan Obor Penolak Bala (%d/5)." % GameManager.torches_lit, "Goal: Light Repellent Torches (%d/5)." % GameManager.torches_lit)
		4:
			title_label.text = LocScript.pick("4. Barikade 3 Pintu & Lemari Sembunyi", "4. Barricade 3 Doors & Closet Hiding")
			body_label.text = LocScript.pick(
				"Pilih Papan & Paku di hotbar, berdiri di luar pintu rumah yang tertutup, lalu tekan [%s]. Di dalam rumah ada Lemari untuk bersembunyi." % act_k,
				"Equip Planks & Nails, stand outside a closed house door, and press [%s]. Inside houses you can hide in closets." % act_k
			)
			goal_label.text = LocScript.pick("Target: Palang Pintu Rumah (%d/3)." % GameManager.doors_barricaded, "Goal: Barricade House Doors (%d/3)." % GameManager.doors_barricaded)
		5:
			title_label.text = LocScript.pick("5. Selesaikan Pertahanan Babak I", "5. Finish Act I Defense")
			body_label.text = LocScript.pick(
				"Selesaikan 5 Obor dan 3 Barikade Pintu sebelum 02.30 WIB untuk memulai Babak II.",
				"Complete 5 Torches and 3 Barricaded Doors before 02:30 WIB to begin Act II."
			)
			goal_label.text = LocScript.pick("Target: Obor %d/5  ·  Barikade Pintu %d/3." % [GameManager.torches_lit, GameManager.doors_barricaded], "Goal: Torches %d/5  ·  Door Barricades %d/3." % [GameManager.torches_lit, GameManager.doors_barricaded])
		6:
			title_label.text = LocScript.pick("6. Jangan Menatap Lampor", "6. Never Stare at Lampor")
			body_label.text = LocScript.pick(
				"Dilarang menatap Keranda Hijau Lampor. Saat lonceng dekat, palingkan pandangan, matikan senter [%s], dan sembunyi sambil mencari 4 Benda Ritual." % flash_k,
				"Never look directly at Lampor's green coffin. When bells ring close, look away, turn off flashlight [%s], and hide while seeking 4 Ritual Relics." % flash_k
			)
			goal_label.text = LocScript.pick("Target: Kumpulkan 4 Benda Ritual (%d/4) tanpa menatap Lampor." % GameManager.get_ritual_item_count(), "Goal: Collect 4 Ritual Relics (%d/4) safely." % GameManager.get_ritual_item_count())
		7:
			title_label.text = LocScript.pick("7. Bakar di Tungku Sebelum 05.00 WIB", "7. Burn at Furnace Before 05:00 WIB")
			body_label.text = LocScript.pick(
				"Bakar 4 Benda Ritual di Tungku Balai Desa [%s] dan bertahan %d detik sebelum pukul 05.00 WIB tiba." % [act_k, int(GameManager.furnace_total_time)],
				"Burn 4 Ritual Relics in the Village Hall Furnace [%s] and survive %d seconds before 05:00 WIB." % [act_k, int(GameManager.furnace_total_time)]
			)
			goal_label.text = LocScript.pick("Target: Bakar Benda Ritual di Tungku Balai Desa dengan [%s]." % act_k, "Goal: Burn the Ritual Relics at the Village Hall Furnace with [%s]." % act_k)
	_apply_layout()
