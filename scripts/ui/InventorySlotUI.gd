class_name InventorySlotUI
extends PanelContainer

signal slot_drag_started(slot_index: int)
signal slot_dropped(from_index: int, to_index: int)
signal slot_clicked(slot_index: int)

var slot_index: int = 0
var item_data: Dictionary = {}
var is_hotbar: bool = false
var is_equipped: bool = false
var is_selected_for_swap: bool = false

var name_label: Label
var qty_label: Label
var key_label: Label

func setup(p_index: int, p_is_hotbar: bool = false, p_key_text: String = "") -> void:
	slot_index = p_index
	is_hotbar = p_is_hotbar
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(86, 58)

	# Buat StyleBox tersendiri agar dapat diwarnai per slot
	_apply_normal_style()

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	if not p_key_text.is_empty():
		key_label = Label.new()
		key_label.name = "Key"
		key_label.text = p_key_text
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.add_theme_font_size_override("font_size", 10)
		key_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5, 1.0))
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(key_label)

	name_label = Label.new()
	name_label.name = "ItemName"
	name_label.text = "[Kosong]"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	qty_label = Label.new()
	qty_label.name = "Qty"
	qty_label.text = ""
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_label.add_theme_font_size_override("font_size", 10)
	qty_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7, 1.0))
	qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(qty_label)

func update_slot(data: Dictionary, equipped: bool = false) -> void:
	item_data = data
	is_equipped = equipped

	if not name_label or not qty_label:
		return

	if item_data.is_empty():
		name_label.text = "[Kosong]"
		name_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 0.7))
		qty_label.text = ""
	else:
		name_label.text = str(item_data.get("name", ""))
		name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.9, 1.0))
		if item_data.has("quantity") and int(item_data["quantity"]) > 1:
			qty_label.text = "x" + str(item_data["quantity"])
		elif item_data.has("battery"):
			qty_label.text = "%d%%" % int(item_data["battery"])
		else:
			qty_label.text = ""

	_refresh_visual_state()

func set_selected(selected: bool) -> void:
	is_selected_for_swap = selected
	_refresh_visual_state()

func _apply_normal_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.88)
	style.border_color = Color(0.45, 0.45, 0.5, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	add_theme_stylebox_override("panel", style)

func _refresh_visual_state() -> void:
	var style: StyleBoxFlat = get_theme_stylebox("panel") as StyleBoxFlat
	if not style:
		return
	style = style.duplicate() as StyleBoxFlat

	if is_selected_for_swap:
		style.bg_color = Color(0.35, 0.28, 0.08, 0.95)
		style.border_color = Color(1.0, 0.85, 0.2, 1.0)
		style.set_border_width_all(2)
	elif is_hotbar and is_equipped:
		style.bg_color = Color(0.22, 0.22, 0.12, 0.92)
		style.border_color = Color(1.0, 0.88, 0.35, 1.0)
		style.set_border_width_all(2)
	elif item_data.is_empty():
		style.bg_color = Color(0.08, 0.08, 0.10, 0.75)
		style.border_color = Color(0.3, 0.3, 0.35, 0.6)
		style.set_border_width_all(1)
	else:
		style.bg_color = Color(0.14, 0.13, 0.16, 0.9)
		style.border_color = Color(0.55, 0.45, 0.45, 0.9)
		style.set_border_width_all(2)

	add_theme_stylebox_override("panel", style)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_data.is_empty():
		return null

	# Buat pratinjau kartu saat di-drag
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(86, 52)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.2, 0.08, 0.1, 0.95)
	p_style.border_color = Color(0.9, 0.35, 0.35, 1.0)
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(4)
	preview.add_theme_stylebox_override("panel", p_style)

	var pvbox := VBoxContainer.new()
	pvbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var plabel := Label.new()
	plabel.text = str(item_data.get("name", ""))
	plabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plabel.add_theme_font_size_override("font_size", 11)
	pvbox.add_child(plabel)

	if item_data.has("quantity") and int(item_data["quantity"]) > 1:
		var pq := Label.new()
		pq.text = "x%d" % int(item_data["quantity"])
		pq.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pq.add_theme_font_size_override("font_size", 10)
		pvbox.add_child(pq)

	preview.add_child(pvbox)
	set_drag_preview(preview)

	slot_drag_started.emit(slot_index)
	return {"from_slot": slot_index, "item": item_data}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("from_slot")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.has("from_slot"):
		slot_dropped.emit(int(data["from_slot"]), slot_index)

func _gui_input(event: InputEvent) -> void:
	var pressed: bool = false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		pressed = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		pressed = st.pressed
	if pressed:
		slot_clicked.emit(slot_index)
