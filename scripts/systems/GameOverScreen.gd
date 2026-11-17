class_name GameOverScreen
extends Control

@onready var retry_btn: Button = $VBoxContainer/RetryButton
@onready var menu_btn: Button = $VBoxContainer/MenuButton
@onready var reason_label: Label = $TitleBox/ReasonLabel
@onready var title_label: Label = $TitleBox/Title
@onready var title_box: VBoxContainer = $TitleBox
@onready var buttons_box: VBoxContainer = $VBoxContainer

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	reason_label.text = GameManager.last_death_reason if GameManager.last_death_reason != "" else "Malam ini belum menjadi milikmu."
	var lower_reason: String = reason_label.text.to_lower()
	if lower_reason.contains("keranda") or lower_reason.contains("ditarik"):
		title_label.text = "DITELAN KERANDA LAMPOR"
	elif lower_reason.contains("fajar"):
		title_label.text = "FAJAR TAK MENYELAMATKANMU"
	else:
		title_label.text = "JIWAMU TELAH HANCUR"
	retry_btn.pressed.connect(func() -> void: GameManager.start_new_game(GameManager.selected_difficulty))
	menu_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn"))
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()

func _apply_layout() -> void:
	var view_size: Vector2 = get_viewport_rect().size
	var compact: bool = view_size.x < 700.0
	title_box.anchor_left = 0.07
	title_box.anchor_right = 0.93
	title_box.anchor_top = 0.13
	title_box.anchor_bottom = 0.46
	title_box.offset_left = 0.0
	title_box.offset_right = 0.0
	title_box.offset_top = 0.0
	title_box.offset_bottom = 0.0
	title_label.add_theme_font_size_override("font_size", 32 if compact else 46)
	reason_label.add_theme_font_size_override("font_size", 15 if compact else 18)
	buttons_box.anchor_left = 0.5
	buttons_box.anchor_right = 0.5
	buttons_box.anchor_top = 0.64
	buttons_box.anchor_bottom = 0.64
	buttons_box.offset_left = -minf(150.0, (view_size.x - 36.0) * 0.5)
	buttons_box.offset_right = minf(150.0, (view_size.x - 36.0) * 0.5)
	buttons_box.offset_top = 0.0
	buttons_box.offset_bottom = 125.0
	buttons_box.custom_minimum_size.x = minf(300.0, view_size.x - 36.0)
