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
		title_label.text = "⚰️ DITELAN KERANDA LAMPOR"
	elif lower_reason.contains("fajar"):
		title_label.text = "🌑 FAJAR TAK MENYELAMATKANMU"
	else:
		title_label.text = "☠️ JIWAMU TELAH HANCUR"
	_style_horror_button(retry_btn, true)
	_style_horror_button(menu_btn, false)
	retry_btn.pressed.connect(func() -> void: GameManager.start_new_game(GameManager.selected_difficulty))
	menu_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn"))
	var reward_label := Label.new()
	reward_label.text = "🪙 +%d Koin Emas  ·  Total: %d" % [GameManager.last_run_coin_reward, GameManager.coins]
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_label.add_theme_font_size_override("font_size", 15)
	reward_label.add_theme_color_override("font_color", Color(0.94, 0.72, 0.42, 1.0))
	title_box.add_child(reward_label)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()

func _style_horror_button(btn: Button, primary: bool) -> void:
	if not btn:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.40, 0.04, 0.06, 0.96) if primary else Color(0.08, 0.03, 0.04, 0.96)
	normal.border_color = Color(0.78, 0.12, 0.14, 1.0) if primary else Color(0.45, 0.10, 0.12, 0.95)
	normal.border_width_left = 3
	normal.border_width_right = 3
	normal.border_width_top = 1
	normal.border_width_bottom = 2
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.58, 0.07, 0.10, 1.0) if primary else Color(0.22, 0.05, 0.07, 1.0)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", hover)

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
