class_name FateCardOverlay
extends Control

const FATE_CARD_SYSTEM = preload("res://scripts/systems/FateCardSystem.gd")
const LocScript = preload("res://scripts/systems/Loc.gd")

signal overlay_opened()
signal overlay_closed(chosen_card: Dictionary)

const CHOICE_TIME_LIMIT_SEC: float = 10.0
const MP_AUTO_RESUME_DELAY_SEC: float = 1.8

enum Phase { INACTIVE, WAITING_CHOICE, ANIMATING, WAITING_OTHERS, READY_CONTINUE }

var _phase: Phase = Phase.INACTIVE
var _act_num: int = 1
var _current_pair: Dictionary = {}
var _chosen_side: String = ""
var _chosen_card: Dictionary = {}
var _prev_paused: bool = false
var _paused_tree_by_overlay: bool = false
var _prev_inventory_open: bool = false
var _flip_tween: Tween = null
var _texture_cache: Dictionary = {}
var _choice_time_left: float = CHOICE_TIME_LIMIT_SEC
var _auto_selected: bool = false
var _mp_auto_resume_left: float = -1.0
var _is_mp_waiting_barrier: bool = false

var _backdrop: ColorRect
var _center_wrap: CenterContainer
var _main_vbox: VBoxContainer
var _divider_label: Label
var _title_label: Label
var _subtitle_label: Label
var _timer_box: VBoxContainer
var _timer_label: Label
var _timer_bar: ProgressBar
var _cards_row: HBoxContainer
var _wait_status_label: Label
var _continue_btn: Button
var _slots: Dictionary = {}

func _ready() -> void:
	name = "FateCardOverlay"
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 25
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_build_ui()
	get_viewport().size_changed.connect(_apply_layout)
	SettingsManager.language_changed.connect(_on_language_changed)
	if SignalBus.has_signal("fate_card_round_status_changed"):
		SignalBus.fate_card_round_status_changed.connect(_on_fate_round_status_changed)

func _exit_tree() -> void:
	if _flip_tween and _flip_tween.is_running():
		_flip_tween.kill()
	if _paused_tree_by_overlay and is_inside_tree():
		get_tree().paused = _prev_paused
		_paused_tree_by_overlay = false

func is_open() -> bool:
	return visible and _phase != Phase.INACTIVE

func _is_touch_device() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios")

func _load_card_texture(res_path: String) -> Texture2D:
	if res_path.is_empty():
		return null
	if _texture_cache.has(res_path):
		return _texture_cache[res_path] as Texture2D
	var tex: Texture2D = null
	if ResourceLoader.exists(res_path):
		tex = ResourceLoader.load(res_path) as Texture2D
	elif FileAccess.file_exists(res_path):
		var global_path: String = ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(global_path):
			var img: Image = Image.load_from_file(global_path)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	_texture_cache[res_path] = tex
	return tex

func _make_timer_bar_style(bg_col: Color, border_col: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg_col
	if border_col.a > 0.01:
		st.border_color = border_col
		st.set_border_width_all(1)
	st.set_corner_radius_all(3)
	return st

func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = Color(0.032, 0.014, 0.016, 0.90)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_center_wrap = CenterContainer.new()
	_center_wrap.name = "CenterWrap"
	_center_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center_wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_center_wrap)

	_main_vbox = VBoxContainer.new()
	_main_vbox.name = "MainVBox"
	_main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_main_vbox.add_theme_constant_override("separation", 10)
	_main_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_center_wrap.add_child(_main_vbox)

	var divider: HBoxContainer = HorrorTheme.create_ritual_divider("◆ TAKDIR MALAM ◆", HorrorTheme.RELIC_BRASS)
	if divider.get_child_count() >= 2 and divider.get_child(1) is Label:
		_divider_label = divider.get_child(1) as Label
	_main_vbox.add_child(divider)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	HorrorTheme.style_label(_title_label, "headline-lg", HorrorTheme.ON_PRIMARY_CONTAINER, 24)
	_main_vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	HorrorTheme.style_label(_subtitle_label, "body-md", HorrorTheme.ON_SURFACE_VARIANT, 14)
	_main_vbox.add_child(_subtitle_label)

	_timer_box = VBoxContainer.new()
	_timer_box.name = "TimerBox"
	_timer_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_timer_box.add_theme_constant_override("separation", 4)
	_timer_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_timer_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_vbox.add_child(_timer_box)

	_timer_label = Label.new()
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HorrorTheme.style_label(_timer_label, "mono-sm", HorrorTheme.RELIC_BRASS, 12)
	_timer_box.add_child(_timer_label)

	_timer_bar = ProgressBar.new()
	_timer_bar.name = "ChoiceTimerBar"
	_timer_bar.min_value = 0.0
	_timer_bar.max_value = CHOICE_TIME_LIMIT_SEC
	_timer_bar.value = CHOICE_TIME_LIMIT_SEC
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(300.0, 9.0)
	_timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_bar.add_theme_stylebox_override("background", _make_timer_bar_style(Color(0.08, 0.035, 0.038, 0.92), HorrorTheme.OUTLINE_VARIANT))
	_timer_bar.add_theme_stylebox_override("fill", _make_timer_bar_style(HorrorTheme.RELIC_BRASS))
	_timer_box.add_child(_timer_bar)

	_cards_row = HBoxContainer.new()
	_cards_row.name = "CardsRow"
	_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_row.add_theme_constant_override("separation", 30)
	_cards_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_main_vbox.add_child(_cards_row)

	_slots["left"] = _create_card_slot("left")
	_slots["right"] = _create_card_slot("right")
	_cards_row.add_child(_slots["left"]["holder"] as Control)
	_cards_row.add_child(_slots["right"]["holder"] as Control)

	_wait_status_label = Label.new()
	_wait_status_label.name = "WaitStatusLabel"
	_wait_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wait_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wait_status_label.visible = false
	_wait_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HorrorTheme.style_label(_wait_status_label, "body-md", HorrorTheme.RELIC_BRASS, 13)
	_main_vbox.add_child(_wait_status_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_main_vbox.add_child(btn_row)

	_continue_btn = Button.new()
	_continue_btn.name = "ContinueButton"
	_continue_btn.custom_minimum_size = Vector2(240.0, 44.0)
	HorrorTheme.style_button(_continue_btn, "primary", 13, true)
	_continue_btn.pressed.connect(close_overlay)
	btn_row.add_child(_continue_btn)

func _create_card_slot(side: String) -> Dictionary:
	var holder := Control.new()
	holder.name = "CardHolder_" + side
	holder.custom_minimum_size = Vector2(240.0, 360.0)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_PASS

	var panel := PanelContainer.new()
	panel.name = "CardPanel_" + side
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.add_theme_stylebox_override("panel", _make_card_panel_style(Color(0.11, 0.05, 0.055, 0.98), HorrorTheme.RELIC_BRASS, 2, 10, 10))
	HorrorTheme.attach_corner_ornaments(panel, HorrorTheme.RELIC_BRASS, 10.0, 1.5, 5.0, true)
	holder.add_child(panel)

	var face_stack := Control.new()
	face_stack.name = "FaceStack"
	face_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	face_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	face_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(face_stack)

	# --- Face Down View ---
	var face_down := Control.new()
	face_down.name = "FaceDown"
	face_down.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face_down.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_stack.add_child(face_down)

	var back_fallback := ColorRect.new()
	back_fallback.name = "BackFallback"
	back_fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back_fallback.color = Color(0.085, 0.035, 0.042, 1.0)
	back_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_down.add_child(back_fallback)

	var back_fallback_vbox := VBoxContainer.new()
	back_fallback_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back_fallback_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	back_fallback_vbox.add_theme_constant_override("separation", 8)
	back_fallback_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_fallback.add_child(back_fallback_vbox)

	var back_sigil := Label.new()
	back_sigil.text = "◆\n?"
	back_sigil.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HorrorTheme.style_label(back_sigil, "headline-lg", HorrorTheme.RELIC_BRASS, 34)
	back_sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_fallback_vbox.add_child(back_sigil)

	var back_sub := Label.new()
	back_sub.text = "KARTU TAKDIR"
	back_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HorrorTheme.style_label(back_sub, "label-lg", HorrorTheme.PRIMARY, 12)
	back_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_fallback_vbox.add_child(back_sub)

	var back_tex := TextureRect.new()
	back_tex.name = "BackTexture"
	back_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	back_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_down.add_child(back_tex)

	var hotkey_wrap := MarginContainer.new()
	hotkey_wrap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hotkey_wrap.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hotkey_wrap.add_theme_constant_override("margin_left", 10)
	hotkey_wrap.add_theme_constant_override("margin_right", 10)
	hotkey_wrap.add_theme_constant_override("margin_bottom", 8)
	hotkey_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_down.add_child(hotkey_wrap)

	var hotkey_pill := PanelContainer.new()
	hotkey_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hotkey_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hotkey_pill.add_theme_stylebox_override("panel", HorrorTheme.make_chip_style(Color(0.06, 0.025, 0.03, 0.92), HorrorTheme.RELIC_BRASS, 3, 10, 4))
	hotkey_wrap.add_child(hotkey_pill)

	var hotkey_lbl := Label.new()
	hotkey_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotkey_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HorrorTheme.style_label(hotkey_lbl, "mono-sm", HorrorTheme.RELIC_BRASS, 11)
	hotkey_pill.add_child(hotkey_lbl)

	# --- Face Up View ---
	var face_up := VBoxContainer.new()
	face_up.name = "FaceUp"
	face_up.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face_up.add_theme_constant_override("separation", 6)
	face_up.visible = false
	face_up.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_stack.add_child(face_up)

	var status_lbl := Label.new()
	status_lbl.name = "StatusLabel"
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HorrorTheme.style_label(status_lbl, "mono-sm", HorrorTheme.RELIC_BRASS, 10)
	face_up.add_child(status_lbl)

	var art_frame := PanelContainer.new()
	art_frame.name = "ArtFrame"
	art_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art_frame.clip_contents = true
	art_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_frame.add_theme_stylebox_override("panel", HorrorTheme.make_minimal_panel_style(Color(0.05, 0.022, 0.026, 1.0), HorrorTheme.BORDER_SUBTLE, 2, 2, 2))
	face_up.add_child(art_frame)

	var art_stack := Control.new()
	art_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_frame.add_child(art_stack)

	var art_fallback := ColorRect.new()
	art_fallback.name = "ArtFallback"
	art_fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art_fallback.color = Color(0.16, 0.05, 0.06, 1.0)
	art_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_stack.add_child(art_fallback)

	var art_fallback_lbl := Label.new()
	art_fallback_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art_fallback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_fallback_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	art_fallback_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HorrorTheme.style_label(art_fallback_lbl, "headline-lg", HorrorTheme.RELIC_BRASS, 40)
	art_fallback.add_child(art_fallback_lbl)

	var art_tex := TextureRect.new()
	art_tex.name = "ArtTexture"
	art_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_stack.add_child(art_tex)

	var badge_pill := PanelContainer.new()
	badge_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_up.add_child(badge_pill)

	var badge_lbl := Label.new()
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HorrorTheme.style_label(badge_lbl, "label-lg", HorrorTheme.ON_PRIMARY_CONTAINER, 10)
	badge_pill.add_child(badge_lbl)

	var name_lbl := Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HorrorTheme.style_label(name_lbl, "title-lg", HorrorTheme.ON_SURFACE, 15)
	face_up.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(0.0, 40.0)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HorrorTheme.style_label(desc_lbl, "body-md", HorrorTheme.ON_SURFACE_VARIANT, 12)
	face_up.add_child(desc_lbl)

	panel.gui_input.connect(_on_slot_gui_input.bind(side))
	panel.mouse_entered.connect(_on_slot_hover.bind(side, true))
	panel.mouse_exited.connect(_on_slot_hover.bind(side, false))

	return {
		"side": side,
		"holder": holder,
		"panel": panel,
		"face_down": face_down,
		"back_tex": back_tex,
		"back_fallback": back_fallback,
		"back_sub": back_sub,
		"hotkey_lbl": hotkey_lbl,
		"face_up": face_up,
		"status_lbl": status_lbl,
		"art_frame": art_frame,
		"art_tex": art_tex,
		"art_fallback": art_fallback,
		"art_fallback_lbl": art_fallback_lbl,
		"badge_pill": badge_pill,
		"badge_lbl": badge_lbl,
		"name_lbl": name_lbl,
		"desc_lbl": desc_lbl
	}

func _make_card_panel_style(bg_col: Color, border_col: Color, border_w: int, pad_h: int, pad_v: int, glow_size: int = 8) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg_col
	st.border_color = border_col
	st.set_border_width_all(border_w)
	st.set_corner_radius_all(6)
	st.content_margin_left = float(pad_h)
	st.content_margin_right = float(pad_h)
	st.content_margin_top = float(pad_v)
	st.content_margin_bottom = float(pad_v)
	st.shadow_color = Color(border_col.r, border_col.g, border_col.b, 0.35)
	st.shadow_size = glow_size
	return st

func open_choice(act_num: int, pair: Dictionary) -> bool:
	var left_raw: Variant = pair.get("left", {})
	var right_raw: Variant = pair.get("right", {})
	if not (left_raw is Dictionary) or not (right_raw is Dictionary):
		return false
	var left_card: Dictionary = left_raw as Dictionary
	var right_card: Dictionary = right_raw as Dictionary
	if left_card.is_empty() or right_card.is_empty():
		return false

	if _flip_tween and _flip_tween.is_running():
		_flip_tween.kill()

	_act_num = act_num
	_current_pair = {"pairing": str(pair.get("pairing", "")), "left": left_card.duplicate(true), "right": right_card.duplicate(true)}
	_chosen_side = ""
	_chosen_card = {}
	_choice_time_left = CHOICE_TIME_LIMIT_SEC
	_auto_selected = false
	_mp_auto_resume_left = -1.0
	_phase = Phase.WAITING_CHOICE

	GameManager.begin_fate_card_selection(act_num)
	_is_mp_waiting_barrier = GameManager.is_multiplayer_fate_barrier_needed(act_num)

	_reset_slot_face_down(_slots["left"], "left")
	_reset_slot_face_down(_slots["right"], "right")
	if _timer_box:
		_timer_box.visible = true
	if _wait_status_label:
		_wait_status_label.visible = false
	_update_timer_ui()
	_refresh_header_and_button_texts()

	var player: PlayerController = GameManager.player_character as PlayerController
	if player:
		_prev_inventory_open = player.is_inventory_open
		player.is_inventory_open = true
		player.release_all_held_inputs()

	_prev_paused = get_tree().paused
	var mp: Variant = GameManager.get_multiplayer_manager()
	if mp == null or not mp.is_online_session:
		get_tree().paused = true
		_paused_tree_by_overlay = true
	else:
		_paused_tree_by_overlay = false

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_apply_layout()
	call_deferred("_sync_pivots")
	HorrorTheme.animate_surface_enter(_main_vbox)
	overlay_opened.emit()
	return true

func _process(delta: float) -> void:
	if not is_open():
		return
	if _phase == Phase.WAITING_CHOICE:
		_choice_time_left = maxf(0.0, _choice_time_left - maxf(0.0, delta))
		_update_timer_ui()
		if _choice_time_left <= 0.0:
			var auto_side: String = "left" if (randi() % 2 == 0) else "right"
			_select_side(auto_side, true)
	elif _phase == Phase.WAITING_OTHERS:
		_refresh_waiting_others_status()
		if GameManager.are_all_players_fate_ready(_act_num):
			_enter_ready_continue()
	elif _phase == Phase.READY_CONTINUE and _is_mp_waiting_barrier and _mp_auto_resume_left > 0.0:
		_mp_auto_resume_left = maxf(0.0, _mp_auto_resume_left - maxf(0.0, delta))
		_refresh_header_and_button_texts()
		if _mp_auto_resume_left <= 0.0:
			close_overlay()

func _update_timer_ui() -> void:
	if not is_instance_valid(_timer_label) or not is_instance_valid(_timer_bar):
		return
	var secs_left: int = maxi(0, ceili(_choice_time_left))
	var urgent: bool = _choice_time_left <= 3.0
	var bar_col: Color = Color("e84a42") if urgent else HorrorTheme.RELIC_BRASS
	_timer_label.text = LocScript.pick(
		"Waktu memilih: %d detik (otomatis jika habis)" % secs_left,
		"Time to choose: %ds (auto-pick on timeout)" % secs_left
	)
	_timer_label.add_theme_color_override("font_color", bar_col)
	_timer_bar.value = clampf(_choice_time_left, 0.0, CHOICE_TIME_LIMIT_SEC)
	_timer_bar.add_theme_stylebox_override("fill", _make_timer_bar_style(bar_col))

func _reset_slot_face_down(slot: Dictionary, side: String) -> void:
	var panel: PanelContainer = slot["panel"] as PanelContainer
	panel.scale = Vector2.ONE
	panel.modulate = Color.WHITE
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.add_theme_stylebox_override("panel", _make_card_panel_style(Color(0.10, 0.045, 0.05, 0.98), HorrorTheme.RELIC_BRASS, 2, 10, 10, 8))
	HorrorTheme.attach_corner_ornaments(panel, HorrorTheme.RELIC_BRASS, 10.0, 1.5, 5.0, true)

	(slot["face_down"] as Control).visible = true
	(slot["face_up"] as Control).visible = false

	var back_tex_res: Texture2D = _load_card_texture(FATE_CARD_SYSTEM.CARD_BACK_PATH)
	var back_tex: TextureRect = slot["back_tex"] as TextureRect
	var back_fallback: ColorRect = slot["back_fallback"] as ColorRect
	if back_tex_res != null:
		back_tex.texture = back_tex_res
		back_tex.visible = true
		back_fallback.visible = false
	else:
		back_tex.texture = null
		back_tex.visible = false
		back_fallback.visible = true

	var hotkey_lbl: Label = slot["hotkey_lbl"] as Label
	if side == "left":
		hotkey_lbl.text = LocScript.pick("[A / KIRI]", "[A / LEFT]")
	else:
		hotkey_lbl.text = LocScript.pick("[D / KANAN]", "[D / RIGHT]")

	var back_sub: Label = slot["back_sub"] as Label
	back_sub.text = LocScript.pick("KARTU TAKDIR", "FATE CARD")

func _refresh_header_and_button_texts() -> void:
	if is_instance_valid(_divider_label):
		_divider_label.text = LocScript.pick("◆ TAKDIR MALAM ◆", "◆ FATE OF THE NIGHT ◆")
	if not _title_label or not _subtitle_label or not _continue_btn:
		return
	_title_label.text = LocScript.pick(
		"BABAK %d · PILIHAN TAKDIR" % _act_num,
		"ACT %d · FATE'S CHOICE" % _act_num
	)
	match _phase:
		Phase.WAITING_CHOICE:
			_subtitle_label.text = LocScript.pick(
				"Pilih satu kartu: Kiri atau Kanan",
				"Choose one card: Left or Right"
			)
			_continue_btn.disabled = true
			_continue_btn.modulate.a = 0.35
			_continue_btn.text = LocScript.pick("PILIH KARTU DULU", "CHOOSE A CARD")
		Phase.ANIMATING:
			if _chosen_card.is_empty():
				_subtitle_label.text = LocScript.pick(
					"Waktu habis — memilih kartu secara otomatis..." if _auto_selected else "Membuka takdir pilihanmu...",
					"Time's up — auto-selecting a card..." if _auto_selected else "Revealing your chosen fate..."
				)
			else:
				var prefix: String = LocScript.pick("[OTOMATIS] ", "[AUTO] ") if _auto_selected else ""
				_subtitle_label.text = "%s%s — %s" % [
					prefix,
					FATE_CARD_SYSTEM.get_card_title(_chosen_card),
					FATE_CARD_SYSTEM.get_card_description(_chosen_card)
				]
			_continue_btn.disabled = true
			_continue_btn.modulate.a = 0.35
			_continue_btn.text = LocScript.pick("MEMBUKA KARTU...", "REVEALING...")
		Phase.WAITING_OTHERS:
			if not _chosen_card.is_empty():
				var prefix_w: String = LocScript.pick("[OTOMATIS] ", "[AUTO] ") if _auto_selected else ""
				_subtitle_label.text = "%s%s — %s" % [
					prefix_w,
					FATE_CARD_SYSTEM.get_card_title(_chosen_card),
					FATE_CARD_SYSTEM.get_card_description(_chosen_card)
				]
			_continue_btn.disabled = true
			_continue_btn.modulate.a = 0.40
			_continue_btn.text = LocScript.pick("MENUNGGU PEMAIN LAIN...", "WAITING FOR PLAYERS...")
		Phase.READY_CONTINUE:
			if not _chosen_card.is_empty():
				var prefix_r: String = LocScript.pick("[OTOMATIS] ", "[AUTO] ") if _auto_selected else ""
				_subtitle_label.text = "%s%s — %s" % [
					prefix_r,
					FATE_CARD_SYSTEM.get_card_title(_chosen_card),
					FATE_CARD_SYSTEM.get_card_description(_chosen_card)
				]
			_continue_btn.disabled = false
			_continue_btn.modulate.a = 1.0
			if _is_mp_waiting_barrier and _mp_auto_resume_left > 0.0:
				var rem_s: int = maxi(1, ceili(_mp_auto_resume_left))
				_continue_btn.text = LocScript.pick(
					"SEMUA SIAP · LANJUT (%d)" % rem_s,
					"ALL READY · CONTINUE (%d)" % rem_s
				)
			else:
				_continue_btn.text = LocScript.pick(
					"LANJUTKAN" if _is_touch_device() else "LANJUTKAN [ENTER / SPASI]",
					"CONTINUE" if _is_touch_device() else "CONTINUE [ENTER / SPACE]"
				)

func _on_language_changed(_lang: String) -> void:
	if not is_open():
		return
	_update_timer_ui()
	_refresh_header_and_button_texts()
	if _phase == Phase.WAITING_OTHERS:
		_refresh_waiting_others_status()
	if _phase == Phase.WAITING_CHOICE:
		_reset_slot_face_down(_slots["left"], "left")
		_reset_slot_face_down(_slots["right"], "right")
	elif not _chosen_side.is_empty():
		var other_side: String = "right" if _chosen_side == "left" else "left"
		var chosen_card: Dictionary = _current_pair.get(_chosen_side, {}) as Dictionary
		var other_card: Dictionary = _current_pair.get(other_side, {}) as Dictionary
		if (_slots[_chosen_side]["face_up"] as Control).visible:
			_populate_face_up_texts(_slots[_chosen_side], chosen_card, true)
		if (_slots[other_side]["face_up"] as Control).visible:
			_populate_face_up_texts(_slots[other_side], other_card, false)

func _on_slot_hover(side: String, hovered: bool) -> void:
	if _phase != Phase.WAITING_CHOICE:
		return
	var slot: Dictionary = _slots[side]
	var panel: PanelContainer = slot["panel"] as PanelContainer
	panel.pivot_offset = panel.size * 0.5
	var tw := panel.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2(1.04, 1.04) if hovered else Vector2.ONE, 0.14)
	var border_col: Color = HorrorTheme.PRIMARY if hovered else HorrorTheme.RELIC_BRASS
	panel.add_theme_stylebox_override("panel", _make_card_panel_style(Color(0.14 if hovered else 0.10, 0.055 if hovered else 0.045, 0.06 if hovered else 0.05, 0.98), border_col, 2, 10, 10, 14 if hovered else 8))
	HorrorTheme.attach_corner_ornaments(panel, border_col, 10.0, 1.5, 5.0, true)

func _on_slot_gui_input(event: InputEvent, side: String) -> void:
	if _phase != Phase.WAITING_CHOICE:
		return
	var pressed: bool = false
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		pressed = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if pressed:
		_select_side(side, false)
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo:
			var kc: Key = ke.keycode
			if _phase == Phase.WAITING_CHOICE:
				if kc == KEY_A or kc == KEY_LEFT or ke.is_action_pressed("move_left"):
					_select_side("left", false)
					get_viewport().set_input_as_handled()
					return
				if kc == KEY_D or kc == KEY_RIGHT or ke.is_action_pressed("move_right"):
					_select_side("right", false)
					get_viewport().set_input_as_handled()
					return
			elif _phase == Phase.READY_CONTINUE:
				if kc in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
					close_overlay()
					get_viewport().set_input_as_handled()
					return
			if kc == KEY_ESCAPE or ke.is_action_pressed("pause") or ke.is_action_pressed("toggle_inventory"):
				get_viewport().set_input_as_handled()
				return

func _sync_pivots() -> void:
	for side_key: String in ["left", "right"]:
		var panel: PanelContainer = _slots[side_key]["panel"] as PanelContainer
		if is_instance_valid(panel):
			panel.pivot_offset = panel.size * 0.5

func _select_side(side: String, was_auto: bool = false) -> void:
	if _phase != Phase.WAITING_CHOICE:
		return
	_phase = Phase.ANIMATING
	_auto_selected = was_auto
	_chosen_side = side
	if _timer_box:
		_timer_box.visible = false

	var other_side: String = "right" if side == "left" else "left"
	var chosen_slot: Dictionary = _slots[side]
	var other_slot: Dictionary = _slots[other_side]
	var chosen_card: Dictionary = (_current_pair.get(side, {}) as Dictionary).duplicate(true)
	var other_card: Dictionary = (_current_pair.get(other_side, {}) as Dictionary).duplicate(true)
	_chosen_card = chosen_card

	var chosen_panel: PanelContainer = chosen_slot["panel"] as PanelContainer
	var other_panel: PanelContainer = other_slot["panel"] as PanelContainer
	chosen_panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
	other_panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
	chosen_panel.scale = Vector2.ONE
	other_panel.scale = Vector2.ONE
	chosen_panel.pivot_offset = chosen_panel.size * 0.5
	other_panel.pivot_offset = other_panel.size * 0.5

	_refresh_header_and_button_texts()

	if _flip_tween and _flip_tween.is_running():
		_flip_tween.kill()
	_flip_tween = create_tween()
	_flip_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	# 1. Putar & buka kartu pilihan pemain terlebih dahulu
	_flip_tween.tween_property(chosen_panel, "scale:x", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_flip_tween.tween_callback(func() -> void:
		_reveal_card_slot(chosen_slot, chosen_card, true)
		var is_blessing: bool = str(chosen_card.get("type", "curse")) == "blessing"
		AudioManager.play_sound("victory_chime" if is_blessing else "game_over_sting", -3.0)
		GameManager.apply_fate_card(chosen_card)
		_refresh_header_and_button_texts()
	)
	_flip_tween.tween_property(chosen_panel, "scale:x", 1.0, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 2. ~0.65 detik kemudian, buka kartu di sebelahnya yang tidak dipilih
	_flip_tween.tween_interval(0.65)
	_flip_tween.tween_property(other_panel, "scale:x", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_flip_tween.tween_callback(func() -> void:
		_reveal_card_slot(other_slot, other_card, false)
		AudioManager.play_sound("item_pickup", -8.0, 0.92)
	)
	_flip_tween.tween_property(other_panel, "scale:x", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 3. Tandai pilihan selesai & cek apakah perlu menunggu pemain lain
	_flip_tween.tween_callback(_finish_reveal_sequence)

func _finish_reveal_sequence() -> void:
	if not is_open():
		return
	GameManager.mark_local_fate_card_chosen(_act_num, _chosen_card)
	_is_mp_waiting_barrier = GameManager.is_multiplayer_fate_barrier_needed(_act_num)
	if _is_mp_waiting_barrier and not GameManager.are_all_players_fate_ready(_act_num):
		_phase = Phase.WAITING_OTHERS
		_refresh_header_and_button_texts()
		_refresh_waiting_others_status()
	else:
		_enter_ready_continue()

func complete_reveal_immediately() -> void:
	if not is_open() or _phase != Phase.ANIMATING or _chosen_side.is_empty():
		return
	if _flip_tween and _flip_tween.is_running():
		_flip_tween.kill()
	_flip_tween = null
	var other_side: String = "right" if _chosen_side == "left" else "left"
	var chosen_slot: Dictionary = _slots[_chosen_side]
	var other_slot: Dictionary = _slots[other_side]
	var chosen_card: Dictionary = (_current_pair.get(_chosen_side, {}) as Dictionary).duplicate(true)
	var other_card: Dictionary = (_current_pair.get(other_side, {}) as Dictionary).duplicate(true)
	_chosen_card = chosen_card
	var chosen_panel: PanelContainer = chosen_slot["panel"] as PanelContainer
	var other_panel: PanelContainer = other_slot["panel"] as PanelContainer
	chosen_panel.scale = Vector2.ONE
	other_panel.scale = Vector2.ONE
	if not (chosen_slot["face_up"] as Control).visible:
		_reveal_card_slot(chosen_slot, chosen_card, true)
		GameManager.apply_fate_card(chosen_card)
	if not (other_slot["face_up"] as Control).visible:
		_reveal_card_slot(other_slot, other_card, false)
	_finish_reveal_sequence()

func _refresh_waiting_others_status() -> void:
	if not is_instance_valid(_wait_status_label):
		return
	var st: Dictionary = GameManager.get_fate_round_status(_act_num)
	var chosen_cnt: int = int(st.get("chosen_count", 1))
	var total_cnt: int = maxi(1, int(st.get("total_count", 1)))
	var pending_raw: Variant = st.get("pending_names", [])
	var pending_names: Array[String] = []
	if pending_raw is Array:
		for nm: Variant in (pending_raw as Array):
			var s: String = str(nm).strip_edges()
			if not s.is_empty():
				pending_names.append(s)
	var pending_txt: String = ""
	if not pending_names.is_empty():
		pending_txt = " (" + ", ".join(pending_names) + ")"
	_wait_status_label.text = LocScript.pick(
		"Menunggu pemain lain memilih kartu (%d/%d)%s..." % [chosen_cnt, total_cnt, pending_txt],
		"Waiting for other players to choose (%d/%d)%s..." % [chosen_cnt, total_cnt, pending_txt]
	)
	_wait_status_label.visible = true

func _on_fate_round_status_changed(act_num: int, _chosen_count: int, _total_count: int, all_chosen: bool, _pending_names: Array) -> void:
	if not is_open() or act_num != _act_num:
		return
	if _phase == Phase.WAITING_OTHERS:
		_refresh_waiting_others_status()
		if all_chosen or GameManager.are_all_players_fate_ready(_act_num):
			_enter_ready_continue()

func _enter_ready_continue() -> void:
	_phase = Phase.READY_CONTINUE
	if _wait_status_label:
		_wait_status_label.visible = false
	_is_mp_waiting_barrier = GameManager.is_multiplayer_fate_barrier_needed(_act_num)
	_mp_auto_resume_left = MP_AUTO_RESUME_DELAY_SEC if _is_mp_waiting_barrier else -1.0
	_refresh_header_and_button_texts()
	if is_instance_valid(_continue_btn):
		_continue_btn.call_deferred("grab_focus")

func _reveal_card_slot(slot: Dictionary, card: Dictionary, is_chosen: bool) -> void:
	(slot["face_down"] as Control).visible = false
	(slot["face_up"] as Control).visible = true

	var panel: PanelContainer = slot["panel"] as PanelContainer
	var is_blessing: bool = str(card.get("type", "curse")) == "blessing"

	var glow_border: Color = Color("ecc067") if is_blessing else Color("e03c3c")
	var dim_border: Color = Color(HorrorTheme.RELIC_BRASS.r, HorrorTheme.RELIC_BRASS.g, HorrorTheme.RELIC_BRASS.b, 0.55) if is_blessing else Color(HorrorTheme.ACCENT.r, HorrorTheme.ACCENT.g, HorrorTheme.ACCENT.b, 0.55)
	var bg_col: Color = Color(0.08, 0.11, 0.085, 0.98) if is_blessing else Color(0.14, 0.04, 0.045, 0.98)

	if is_chosen:
		panel.modulate = Color.WHITE
		panel.add_theme_stylebox_override("panel", _make_card_panel_style(bg_col, glow_border, 3, 10, 10, 18))
		HorrorTheme.attach_corner_ornaments(panel, glow_border, 12.0, 2.0, 5.0, true)
	else:
		panel.modulate = Color(0.76, 0.72, 0.74, 0.90)
		panel.add_theme_stylebox_override("panel", _make_card_panel_style(bg_col, dim_border, 1, 10, 10, 4))
		HorrorTheme.attach_corner_ornaments(panel, dim_border, 8.0, 1.2, 5.0, false)

	var img_path: String = str(card.get("image_path", ""))
	var art_res: Texture2D = _load_card_texture(img_path)
	var art_tex: TextureRect = slot["art_tex"] as TextureRect
	var art_fallback: ColorRect = slot["art_fallback"] as ColorRect
	var art_fallback_lbl: Label = slot["art_fallback_lbl"] as Label

	if art_res != null:
		art_tex.texture = art_res
		art_tex.visible = true
		art_fallback.visible = false
	else:
		art_tex.texture = null
		art_tex.visible = false
		art_fallback.visible = true
		art_fallback.color = Color(0.09, 0.17, 0.11, 1.0) if is_blessing else Color(0.20, 0.04, 0.05, 1.0)
		art_fallback_lbl.text = "✦" if is_blessing else "☠"
		art_fallback_lbl.add_theme_color_override("font_color", HorrorTheme.RELIC_BRASS if is_blessing else HorrorTheme.ACCENT)

	var badge_pill: PanelContainer = slot["badge_pill"] as PanelContainer
	if is_blessing:
		badge_pill.add_theme_stylebox_override("panel", HorrorTheme.make_chip_style(Color(0.11, 0.22, 0.13, 0.96), HorrorTheme.RELIC_BRASS, 3, 10, 3))
	else:
		badge_pill.add_theme_stylebox_override("panel", HorrorTheme.make_chip_style(Color(0.32, 0.06, 0.07, 0.96), HorrorTheme.ACCENT, 3, 10, 3))

	_populate_face_up_texts(slot, card, is_chosen)

func _populate_face_up_texts(slot: Dictionary, card: Dictionary, is_chosen: bool) -> void:
	var is_blessing: bool = str(card.get("type", "curse")) == "blessing"
	var status_lbl: Label = slot["status_lbl"] as Label
	if is_chosen:
		status_lbl.text = LocScript.pick("✦ TERPILIH ✦", "✦ CHOSEN ✦")
		status_lbl.add_theme_color_override("font_color", Color("f2cb72") if is_blessing else Color("ff8078"))
	else:
		status_lbl.text = LocScript.pick("KARTU DI SEBELAHNYA", "OTHER CARD")
		status_lbl.add_theme_color_override("font_color", HorrorTheme.TEXT_MUTED)

	var badge_lbl: Label = slot["badge_lbl"] as Label
	badge_lbl.text = FATE_CARD_SYSTEM.get_card_type_label(card)
	badge_lbl.add_theme_color_override("font_color", Color("f5d788") if is_blessing else HorrorTheme.ON_PRIMARY_CONTAINER)

	var name_lbl: Label = slot["name_lbl"] as Label
	name_lbl.text = FATE_CARD_SYSTEM.get_card_title(card)

	var desc_lbl: Label = slot["desc_lbl"] as Label
	desc_lbl.text = FATE_CARD_SYSTEM.get_card_description(card)

func close_overlay() -> void:
	if not is_open() or _phase != Phase.READY_CONTINUE:
		return
	if _flip_tween and _flip_tween.is_running():
		_flip_tween.kill()
	_flip_tween = null
	_mp_auto_resume_left = -1.0

	visible = false
	_phase = Phase.INACTIVE
	GameManager.finish_local_fate_card_overlay(_act_num)

	var player: PlayerController = GameManager.player_character as PlayerController
	if player:
		player.is_inventory_open = _prev_inventory_open
		player.release_all_held_inputs()

	if _paused_tree_by_overlay:
		get_tree().paused = _prev_paused
		_paused_tree_by_overlay = false

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _is_touch_device() else Input.MOUSE_MODE_CAPTURED
	var chosen_copy: Dictionary = _chosen_card.duplicate(true)
	overlay_closed.emit(chosen_copy)

func force_close() -> void:
	if _flip_tween and _flip_tween.is_running():
		_flip_tween.kill()
	_flip_tween = null
	_mp_auto_resume_left = -1.0
	visible = false
	_phase = Phase.INACTIVE
	GameManager.finish_local_fate_card_overlay(_act_num)
	var player: PlayerController = GameManager.player_character as PlayerController
	if player:
		player.is_inventory_open = false
	if _paused_tree_by_overlay and is_inside_tree():
		get_tree().paused = false
		_paused_tree_by_overlay = false

func _apply_layout() -> void:
	if not is_inside_tree() or not _main_vbox:
		return
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	if view_size.x <= 0.0:
		view_size = Vector2(1280.0, 720.0)
	var compact: bool = view_size.x < 720.0 or view_size.y < 540.0

	var card_w: float = clampf((view_size.x - (52.0 if compact else 140.0)) * 0.44, 148.0, 265.0)
	var card_h: float = clampf(view_size.y - (210.0 if compact else 270.0), 190.0, 365.0)
	var row_gap: int = 14 if compact else 32

	_main_vbox.add_theme_constant_override("separation", 6 if compact else 10)
	_cards_row.add_theme_constant_override("separation", row_gap)

	if _title_label:
		_title_label.custom_minimum_size.x = minf(view_size.x - 32.0, 700.0)
		_title_label.add_theme_font_size_override("font_size", 17 if compact else 24)
	if _subtitle_label:
		_subtitle_label.custom_minimum_size.x = minf(view_size.x - 32.0, 700.0)
		_subtitle_label.add_theme_font_size_override("font_size", 12 if compact else 14)
	if _timer_label:
		_timer_label.add_theme_font_size_override("font_size", 10 if compact else 12)
	if _timer_bar:
		_timer_bar.custom_minimum_size = Vector2(minf(340.0, view_size.x - 64.0), 8.0 if compact else 10.0)
	if _wait_status_label:
		_wait_status_label.custom_minimum_size.x = minf(view_size.x - 32.0, 680.0)
		_wait_status_label.add_theme_font_size_override("font_size", 11 if compact else 13)
	if _continue_btn:
		_continue_btn.custom_minimum_size = Vector2(minf(280.0, view_size.x - 48.0), 38.0 if compact else 44.0)
		_continue_btn.add_theme_font_size_override("font_size", 12 if compact else 13)

	for side_key: String in ["left", "right"]:
		var slot: Dictionary = _slots[side_key]
		var holder: Control = slot["holder"] as Control
		var panel: PanelContainer = slot["panel"] as PanelContainer
		holder.custom_minimum_size = Vector2(card_w, card_h)
		holder.size = Vector2(card_w, card_h)
		panel.pivot_offset = Vector2(card_w * 0.5, card_h * 0.5)
		(slot["name_lbl"] as Label).add_theme_font_size_override("font_size", 12 if compact else 15)
		var desc_lbl: Label = slot["desc_lbl"] as Label
		desc_lbl.add_theme_font_size_override("font_size", 10 if compact else 12)
		desc_lbl.custom_minimum_size.y = 32.0 if compact else 42.0
		(slot["hotkey_lbl"] as Label).add_theme_font_size_override("font_size", 10 if compact else 11)
		(slot["badge_lbl"] as Label).add_theme_font_size_override("font_size", 9 if compact else 10)
		(slot["status_lbl"] as Label).add_theme_font_size_override("font_size", 9 if compact else 10)
