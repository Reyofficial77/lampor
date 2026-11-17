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
