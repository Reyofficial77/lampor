class_name VictoryScreen
extends Control

@onready var replay_btn: Button = $VBoxContainer/ReplayButton
@onready var menu_btn: Button = $VBoxContainer/MenuButton
@onready var title_label: Label = $TitleBox/Title
@onready var subtitle_label: Label = $TitleBox/SubTitle
@onready var title_box: VBoxContainer = $TitleBox
@onready var buttons_box: VBoxContainer = $VBoxContainer

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	var reward_label := Label.new()
	reward_label.text = "🪙 +%d Koin Emas  ·  Total: %d" % [GameManager.last_run_coin_reward, GameManager.coins]
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.add_theme_font_size_override("font_size", 16)
	reward_label.add_theme_color_override("font_color", Color(0.94, 0.78, 0.38, 1.0))
	title_box.add_child(reward_label)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()

func _style_horror_button(btn: Button, primary: bool) -> void:
	if not btn:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.38, 0.24, 0.06, 0.96) if primary else Color(0.08, 0.05, 0.04, 0.96)
	normal.border_color = Color(0.86, 0.68, 0.24, 1.0) if primary else Color(0.48, 0.36, 0.18, 0.95)
	normal.border_width_left = 3
	normal.border_width_right = 3
	normal.border_width_top = 1
	normal.border_width_bottom = 2
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.54, 0.36, 0.09, 1.0) if primary else Color(0.20, 0.12, 0.08, 1.0)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", hover)

func _apply_layout() -> void:
	var view_size: Vector2 = get_viewport_rect().size
	var compact: bool = view_size.x < 700.0
	title_box.anchor_left = 0.06
	title_box.anchor_right = 0.94
	title_box.anchor_top = 0.16
	title_box.anchor_bottom = 0.53
	title_box.offset_left = 0.0
	title_box.offset_right = 0.0
	title_box.offset_top = 0.0
	title_box.offset_bottom = 0.0
	title_label.add_theme_font_size_override("font_size", 30 if compact else 46)
	subtitle_label.add_theme_font_size_override("font_size", 14 if compact else 18)
	buttons_box.anchor_left = 0.5
	buttons_box.anchor_right = 0.5
	buttons_box.anchor_top = 0.66
	buttons_box.anchor_bottom = 0.66
	buttons_box.offset_left = -minf(150.0, (view_size.x - 36.0) * 0.5)
	buttons_box.offset_right = minf(150.0, (view_size.x - 36.0) * 0.5)
	buttons_box.offset_top = 0.0
	buttons_box.offset_bottom = 125.0
	buttons_box.custom_minimum_size.x = minf(300.0, view_size.x - 36.0)
