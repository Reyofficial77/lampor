class_name VictoryScreen
extends Control

const HORROR_TITLE_FONT: Font = preload("res://assets/fonts/HorrorTitle.ttf")
const LocScript = preload("res://scripts/systems/Loc.gd")

@onready var background: ColorRect = $Background
@onready var replay_btn: Button = $VBoxContainer/ReplayButton
@onready var menu_btn: Button = $VBoxContainer/MenuButton
@onready var title_label: Label = $TitleBox/Title
@onready var subtitle_label: Label = $TitleBox/SubTitle
@onready var title_box: VBoxContainer = $TitleBox
@onready var buttons_box: VBoxContainer = $VBoxContainer

var dawn_backdrop: Control
var anim_time: float = 0.0
var content_vbox: VBoxContainer
var time_label: Label
var rule_line: ColorRect
var reward_label: Label

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if background:
		background.color = Color("120e09")

	dawn_backdrop = Control.new()
	dawn_backdrop.name = "DawnBackdrop"
	dawn_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dawn_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dawn_backdrop.draw.connect(_draw_dawn_backdrop)
	add_child(dawn_backdrop)
	move_child(dawn_backdrop, 1)

	var center := CenterContainer.new()
	center.name = "DawnCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	content_vbox = VBoxContainer.new()
	content_vbox.name = "VictoryContent"
	content_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_theme_constant_override("separation", 16)
	center.add_child(content_vbox)

	title_box.reparent(content_vbox)
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.add_theme_constant_override("separation", 12)

	time_label = Label.new()
	time_label.text = "05:00 WIB"
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HorrorTheme.style_label(time_label, "mono-sm", Color("d9b86c"), 12)
	title_box.add_child(time_label)
	title_box.move_child(time_label, 0)

	if title_label:
		title_label.text = LocScript.pick("KUTUKAN TELAH BERAKHIR", "THE CURSE IS BROKEN")
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_override("font", HORROR_TITLE_FONT)
		title_label.add_theme_color_override("font_color", Color("f5d67a"))
		title_label.add_theme_color_override("font_outline_color", Color("241806"))
		title_label.add_theme_constant_override("outline_size", 6)
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	rule_line = ColorRect.new()
	rule_line.color = Color(0.86, 0.68, 0.24, 0.45)
	rule_line.custom_minimum_size = Vector2(110.0, 1.0)
	rule_line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(rule_line)
	title_box.move_child(rule_line, 2)

	if subtitle_label:
		subtitle_label.text = LocScript.pick("Fajar menyingsing. Benda keramat musnah dan Lampor pun lenyap.", "Dawn breaks at last. The cursed relics are burned and Lampor is banished.")
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		HorrorTheme.style_label(subtitle_label, "body-lg", Color("efe6d5"), 16)
		subtitle_label.add_theme_color_override("font_outline_color", Color("120c05"))
		subtitle_label.add_theme_constant_override("outline_size", 2)
		subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	AudioManager.play_voice_by_id("vo_ending_victory_sub_01")

	reward_label = Label.new()
	reward_label.text = LocScript.pick("+%d Koin Emas  ·  Total: %d" % [GameManager.last_run_coin_reward, GameManager.coins], "+%d Gold Coins  ·  Total: %d" % [GameManager.last_run_coin_reward, GameManager.coins])
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	HorrorTheme.style_label(reward_label, "mono-sm", Color("f5d67a"), 13)
	content_vbox.add_child(reward_label)

	buttons_box.reparent(content_vbox)
	buttons_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buttons_box.add_theme_constant_override("separation", 10)
	if replay_btn:
		replay_btn.text = LocScript.pick("MAIN LAGI", "PLAY AGAIN")
	if menu_btn:
		menu_btn.text = LocScript.pick("MENU UTAMA", "MAIN MENU")
	_style_dawn_button(replay_btn, true)
	_style_dawn_button(menu_btn, false)
	replay_btn.pressed.connect(func() -> void:
		GameManager.restart_current_game()
	)
	menu_btn.pressed.connect(func() -> void:
		GameManager.return_to_main_menu_from_ending()
	)

	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	HorrorTheme.animate_surface_enter(content_vbox)
	replay_btn.call_deferred("grab_focus")

func _process(delta: float) -> void:
	anim_time += delta
	if dawn_backdrop:
		dawn_backdrop.queue_redraw()

func _draw_dawn_backdrop() -> void:
	if not dawn_backdrop:
		return
	var s: Vector2 = dawn_backdrop.size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	var c := Vector2(s.x * 0.5, s.y * 0.28)
	var pulse: float = 0.5 + 0.5 * sin(anim_time * 1.2)

	# Pendar fajar lembut di balik judul
	dawn_backdrop.draw_circle(c, minf(s.x, s.y) * 0.56, Color(0.42, 0.28, 0.08, 0.12 + pulse * 0.02))
	dawn_backdrop.draw_circle(c, minf(s.x, s.y) * 0.30, Color(0.76, 0.56, 0.16, 0.08 + pulse * 0.02))

	# Abu emas tipis naik perlahan
	for i: int in range(10):
		var seed_f: float = float(i) * 41.7
		var px: float = fmod(seed_f * 29.0 + sin(anim_time * 0.6 + seed_f) * 18.0, s.x)
		var py: float = s.y - fmod(anim_time * (12.0 + float(i % 4) * 3.5) + seed_f * 17.0, s.y)
		dawn_backdrop.draw_circle(Vector2(px, py), 1.4 + float(i % 2) * 0.5, Color(0.95, 0.78, 0.32, 0.18))

func _style_dawn_button(btn: Button, primary: bool) -> void:
	if not btn:
		return
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_override("font", HorrorTheme.get_serif_font(2, true))
	btn.add_theme_font_size_override("font_size", 14 if primary else 13)
	btn.add_theme_color_override("font_color", Color("fff6e0") if primary else Color("d8ccb6"))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color("ffe7a3"))
	btn.add_theme_color_override("font_focus_color", Color.WHITE)

	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 16.0
	normal.content_margin_right = 16.0
	normal.content_margin_top = 10.0
	normal.content_margin_bottom = 10.0
	normal.shadow_size = 0
	if primary:
		normal.bg_color = Color("5e3d11")
		normal.border_color = Color("d9b25f")
		normal.set_border_width_all(1)
	else:
		normal.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		normal.set_border_width_all(0)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("7a5018") if primary else Color(0.20, 0.15, 0.09, 0.75)
	hover.border_color = Color("f5d67a") if primary else Color("a88a4f")
	hover.set_border_width_all(1)

	var focus := hover.duplicate() as StyleBoxFlat
	focus.border_color = Color("f5d67a")
	focus.set_border_width_all(2)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", focus)

func _apply_layout() -> void:
	var view_size: Vector2 = get_viewport_rect().size
	var compact: bool = view_size.x < 700.0
	var short_screen: bool = view_size.y < 520.0
	var max_text_w: float = clampf(view_size.x - 48.0, 260.0, 560.0)

	if content_vbox:
		content_vbox.add_theme_constant_override("separation", 10 if short_screen else 16)
	if time_label:
		time_label.visible = not (short_screen and view_size.y < 380.0)
	title_label.custom_minimum_size.x = max_text_w
	subtitle_label.custom_minimum_size.x = max_text_w
	title_label.add_theme_font_size_override("font_size", 22 if short_screen else (26 if compact else 36))
	subtitle_label.add_theme_font_size_override("font_size", 13 if short_screen else (14 if compact else 16))

	var btn_w: float = minf(260.0, max_text_w)
	replay_btn.custom_minimum_size = Vector2(btn_w, 44.0)
	menu_btn.custom_minimum_size = Vector2(btn_w, 44.0)
	if dawn_backdrop:
		dawn_backdrop.queue_redraw()
