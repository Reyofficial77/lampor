class_name VictoryScreen
extends Control

const HORROR_TITLE_FONT: Font = preload("res://assets/fonts/HorrorTitle.ttf")

@onready var background: ColorRect = $Background
@onready var replay_btn: Button = $VBoxContainer/ReplayButton
@onready var menu_btn: Button = $VBoxContainer/MenuButton
@onready var title_label: Label = $TitleBox/Title
@onready var subtitle_label: Label = $TitleBox/SubTitle
@onready var title_box: VBoxContainer = $TitleBox
@onready var buttons_box: VBoxContainer = $VBoxContainer

var dawn_backdrop: Control
var anim_time: float = 0.0
var eyebrow_label: Label
var reward_panel: PanelContainer
var reward_label: Label

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if background:
		background.color = Color(0.08, 0.07, 0.04, 1.0)

	dawn_backdrop = Control.new()
	dawn_backdrop.name = "DawnBackdrop"
	dawn_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dawn_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dawn_backdrop.draw.connect(_draw_dawn_backdrop)
	add_child(dawn_backdrop)
	move_child(dawn_backdrop, 1)

	eyebrow_label = Label.new()
	eyebrow_label.text = "── ◆  PUKUL 05.00 PAGI  ·  KUTUKAN DESA TERPUTUS  ◆ ──"
	eyebrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HorrorTheme.style_label(eyebrow_label, "label-lg", Color(0.92, 0.76, 0.36, 0.92), 12)
	title_box.add_child(eyebrow_label)
	title_box.move_child(eyebrow_label, 0)

	if title_label:
		title_label.add_theme_font_override("font", HORROR_TITLE_FONT)
		title_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32, 1.0))
		title_label.add_theme_color_override("font_outline_color", Color(0.28, 0.17, 0.02, 1.0))
		title_label.add_theme_constant_override("outline_size", 10)
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if subtitle_label:
		HorrorTheme.style_label(subtitle_label, "body-lg", Color(0.92, 0.90, 0.84, 1.0), 17)
		subtitle_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 0.9))
		subtitle_label.add_theme_constant_override("outline_size", 3)
		subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var gold_div := HorrorTheme.create_ritual_divider("◆", Color(0.86, 0.68, 0.24, 0.75))
	title_box.add_child(gold_div)

	reward_panel = PanelContainer.new()
	reward_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var r_style := StyleBoxFlat.new()
	r_style.bg_color = Color(0.16, 0.12, 0.05, 0.88)
	r_style.border_color = Color(0.86, 0.68, 0.24, 0.85)
	r_style.set_border_width_all(1)
	r_style.set_corner_radius_all(3)
	r_style.content_margin_left = 18.0
	r_style.content_margin_right = 18.0
	r_style.content_margin_top = 7.0
	r_style.content_margin_bottom = 7.0
	reward_panel.add_theme_stylebox_override("panel", r_style)
	title_box.add_child(reward_panel)

	reward_label = Label.new()
	reward_label.text = "+%d Koin Emas  ·  Total: %d" % [GameManager.last_run_coin_reward, GameManager.coins]
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HorrorTheme.style_label(reward_label, "mono-sm", Color(0.96, 0.80, 0.38, 1.0), 15)
	reward_panel.add_child(reward_label)

	_style_horror_button(replay_btn, true)
	_style_horror_button(menu_btn, false)
	replay_btn.pressed.connect(func() -> void:
		AudioManager.stop_ending_audio()
		GameManager.start_new_game(GameManager.selected_difficulty)
	)
	menu_btn.pressed.connect(func() -> void:
		AudioManager.stop_ending_audio()
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	)

	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	HorrorTheme.animate_surface_enter(title_box)
	HorrorTheme.animate_surface_enter(buttons_box)

func _process(delta: float) -> void:
	anim_time += delta
	if dawn_backdrop:
		dawn_backdrop.queue_redraw()
	if title_label:
		var glow: float = 0.5 + 0.5 * sin(anim_time * 1.8)
		title_label.modulate = Color(1.0, lerpf(0.94, 1.0, glow), lerpf(0.88, 1.0, glow), 1.0)

func _draw_dawn_backdrop() -> void:
	if not dawn_backdrop:
		return
	var s: Vector2 = dawn_backdrop.size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	var c := Vector2(s.x * 0.5, s.y * 0.24)
	var pulse: float = 0.5 + 0.5 * sin(anim_time * 1.5)

	# Pendar sinar fajar hangat di balik judul
	dawn_backdrop.draw_circle(c, minf(s.x, s.y) * 0.58, Color(0.42, 0.28, 0.08, 0.14 + pulse * 0.03))
	dawn_backdrop.draw_circle(c, minf(s.x, s.y) * 0.34, Color(0.76, 0.56, 0.16, 0.10 + pulse * 0.03))

	# Partikel abu emas keranda yang terbakar naik perlahan
	for i: int in range(22):
		var seed_f: float = float(i) * 31.7
		var px: float = fmod(seed_f * 29.0 + sin(anim_time * 0.7 + seed_f) * 22.0, s.x)
		var py: float = s.y - fmod(anim_time * (14.0 + float(i % 5) * 4.0) + seed_f * 17.0, s.y)
		var col := Color(0.95, 0.78, 0.32, 0.28) if i % 2 == 0 else Color(0.88, 0.62, 0.22, 0.18)
		dawn_backdrop.draw_circle(Vector2(px, py), 1.5 + float(i % 2), col)

	# Bingkai tipis keemasan dengan ornamen sudut
	var frame_rect := Rect2(16.0, 16.0, s.x - 32.0, s.y - 32.0)
	dawn_backdrop.draw_rect(frame_rect, Color(0.86, 0.68, 0.24, 0.24), false, 1.0)
	var arm: float = 18.0
	var corner_col := Color(0.92, 0.74, 0.28, 0.62)
	for pt: Vector2 in [frame_rect.position, Vector2(frame_rect.end.x, frame_rect.position.y), Vector2(frame_rect.position.x, frame_rect.end.y), frame_rect.end]:
		var dx: float = arm if pt.x == frame_rect.position.x else -arm
		var dy: float = arm if pt.y == frame_rect.position.y else -arm
		dawn_backdrop.draw_line(pt, pt + Vector2(dx, 0.0), corner_col, 2.0)
		dawn_backdrop.draw_line(pt, pt + Vector2(0.0, dy), corner_col, 2.0)

func _style_horror_button(btn: Button, primary: bool) -> void:
	if not btn:
		return
	btn.add_theme_font_override("font", HorrorTheme.get_serif_font(2, true))
	btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86, 1.0) if primary else Color(0.92, 0.88, 0.78, 1.0))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.68, 1.0))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.38, 0.24, 0.06, 0.96) if primary else Color(0.08, 0.05, 0.04, 0.96)
	normal.border_color = Color(0.86, 0.68, 0.24, 1.0) if primary else Color(0.48, 0.36, 0.18, 0.95)
	normal.border_width_left = 3
	normal.border_width_right = 3
	normal.border_width_top = 1
	normal.border_width_bottom = 2
	normal.set_corner_radius_all(4)
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	normal.shadow_size = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.54, 0.36, 0.09, 1.0) if primary else Color(0.20, 0.12, 0.08, 1.0)
	hover.border_color = Color(0.98, 0.82, 0.36, 1.0) if primary else Color(0.76, 0.58, 0.24, 1.0)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", hover)
	HorrorTheme.attach_corner_ornaments(btn, Color(0.96, 0.78, 0.32, 0.85) if primary else Color(0.62, 0.48, 0.24, 0.65), 6.0, 1.3, 3.0, false)

func _apply_layout() -> void:
	var view_size: Vector2 = get_viewport_rect().size
	var compact: bool = view_size.x < 700.0
	var short_screen: bool = view_size.y < 520.0
	title_box.anchor_left = 0.06
	title_box.anchor_right = 0.94
	title_box.anchor_top = 0.10 if short_screen else 0.14
	title_box.anchor_bottom = 0.56
	title_box.offset_left = 0.0
	title_box.offset_right = 0.0
	title_box.offset_top = 0.0
	title_box.offset_bottom = 0.0
	title_box.add_theme_constant_override("separation", 8 if short_screen else 14)
	if eyebrow_label:
		eyebrow_label.visible = not short_screen
	title_label.add_theme_font_size_override("font_size", 22 if short_screen else (26 if compact else 38))
	subtitle_label.add_theme_font_size_override("font_size", 13 if short_screen else (14 if compact else 17))
	buttons_box.anchor_left = 0.5
	buttons_box.anchor_right = 0.5
	buttons_box.anchor_top = 0.65 if short_screen else 0.66
	buttons_box.anchor_bottom = 0.65 if short_screen else 0.66
	var half_w: float = minf(160.0, (view_size.x - 36.0) * 0.5)
	buttons_box.offset_left = -half_w
	buttons_box.offset_right = half_w
	buttons_box.offset_top = 0.0
	buttons_box.offset_bottom = 125.0
	buttons_box.custom_minimum_size.x = half_w * 2.0
	if dawn_backdrop:
		dawn_backdrop.queue_redraw()
