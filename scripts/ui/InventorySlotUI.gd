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
	custom_minimum_size = Vector2(72, 72)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_apply_normal_style()

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 1)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	if not p_key_text.is_empty():
		key_label = Label.new()
		key_label.name = "Key"
		key_label.text = p_key_text
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		HorrorTheme.style_label(key_label, "mono-sm", HorrorTheme.OUTLINE, 9)
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(key_label)

	name_label = Label.new()
	name_label.name = "ItemName"
	name_label.text = "[Kosong]"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_text = true
	name_label.max_lines_visible = 2
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size = Vector2(62, 24)
	HorrorTheme.style_label(name_label, "label-sm", HorrorTheme.OUTLINE, 10)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	qty_label = Label.new()
	qty_label.name = "Qty"
	qty_label.text = ""
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HorrorTheme.style_label(qty_label, "mono-sm", HorrorTheme.SECONDARY, 9)
	qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(qty_label)

	_refresh_visual_state()

func update_slot(data: Dictionary, equipped: bool = false) -> void:
	item_data = data
	is_equipped = equipped

	if not name_label or not qty_label:
		return

	if item_data.is_empty():
		name_label.text = "[Kosong]"
		qty_label.text = ""
	else:
		name_label.text = str(item_data.get("name", ""))
		if item_data.has("quantity") and int(item_data["quantity"]) > 1:
			qty_label.text = "x" + str(item_data["quantity"])
		elif item_data.has("battery"):
			qty_label.text = "%d%%" % int(round(float(item_data["battery"])))
		else:
			qty_label.text = ""

	_refresh_visual_state()

func set_selected(selected: bool) -> void:
	is_selected_for_swap = selected
	_refresh_visual_state()

func _apply_normal_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(HorrorTheme.SURFACE_LOWEST.r, HorrorTheme.SURFACE_LOWEST.g, HorrorTheme.SURFACE_LOWEST.b, 0.92)
	style.border_color = HorrorTheme.OUTLINE_VARIANT
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 3.0
	style.content_margin_right = 3.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	add_theme_stylebox_override("panel", style)

func _refresh_visual_state() -> void:
	var style: StyleBoxFlat = get_theme_stylebox("panel") as StyleBoxFlat
	if not style:
		return
	style = style.duplicate() as StyleBoxFlat

	var ornament_col := Color(HorrorTheme.OUTLINE_VARIANT.r, HorrorTheme.OUTLINE_VARIANT.g, HorrorTheme.OUTLINE_VARIANT.b, 0.45)
	var show_diamond: bool = false

	if is_selected_for_swap:
		style.bg_color = Color(HorrorTheme.PRIMARY_CONTAINER.r, HorrorTheme.PRIMARY_CONTAINER.g, HorrorTheme.PRIMARY_CONTAINER.b, 0.96)
		style.border_color = HorrorTheme.PRIMARY
		style.set_border_width_all(2)
		ornament_col = HorrorTheme.PRIMARY
		show_diamond = true
		if name_label:
			name_label.add_theme_color_override("font_color", HorrorTheme.ON_PRIMARY_CONTAINER)
		if qty_label:
			qty_label.add_theme_color_override("font_color", HorrorTheme.PRIMARY)
		if key_label:
			key_label.add_theme_color_override("font_color", HorrorTheme.PRIMARY)
	elif is_hotbar and is_equipped:
		style.bg_color = Color(HorrorTheme.SECONDARY_CONTAINER.r, HorrorTheme.SECONDARY_CONTAINER.g, HorrorTheme.SECONDARY_CONTAINER.b, 0.95)
		style.border_color = HorrorTheme.ACCENT
		style.set_border_width_all(2)
		ornament_col = HorrorTheme.PRIMARY
		show_diamond = true
		if name_label:
			name_label.add_theme_color_override("font_color", HorrorTheme.ON_PRIMARY_CONTAINER if not item_data.is_empty() else HorrorTheme.ON_SURFACE_VARIANT)
		if qty_label:
			qty_label.add_theme_color_override("font_color", HorrorTheme.PRIMARY)
		if key_label:
			key_label.add_theme_color_override("font_color", HorrorTheme.PRIMARY)
	elif item_data.is_empty():
		style.bg_color = Color(HorrorTheme.SURFACE_LOWEST.r, HorrorTheme.SURFACE_LOWEST.g, HorrorTheme.SURFACE_LOWEST.b, 0.88)
		style.border_color = Color(HorrorTheme.OUTLINE_VARIANT.r, HorrorTheme.OUTLINE_VARIANT.g, HorrorTheme.OUTLINE_VARIANT.b, 0.65)
		style.set_border_width_all(1)
		ornament_col = Color(HorrorTheme.OUTLINE_VARIANT.r, HorrorTheme.OUTLINE_VARIANT.g, HorrorTheme.OUTLINE_VARIANT.b, 0.35)
		if name_label:
			name_label.add_theme_color_override("font_color", Color(HorrorTheme.OUTLINE.r, HorrorTheme.OUTLINE.g, HorrorTheme.OUTLINE.b, 0.72))
		if qty_label:
			qty_label.add_theme_color_override("font_color", HorrorTheme.OUTLINE)
		if key_label:
			key_label.add_theme_color_override("font_color", HorrorTheme.OUTLINE)
	else:
		style.bg_color = Color(HorrorTheme.SURFACE_LOW.r, HorrorTheme.SURFACE_LOW.g, HorrorTheme.SURFACE_LOW.b, 0.96)
		style.border_color = HorrorTheme.OUTLINE
		style.set_border_width_all(1)
		style.border_width_bottom = 2
		ornament_col = HorrorTheme.ACCENT
		if name_label:
			name_label.add_theme_color_override("font_color", HorrorTheme.ON_SURFACE)
		if qty_label:
			qty_label.add_theme_color_override("font_color", HorrorTheme.RELIC_BRASS)
		if key_label:
			key_label.add_theme_color_override("font_color", HorrorTheme.SECONDARY)

	add_theme_stylebox_override("panel", style)
	HorrorTheme.attach_corner_ornaments(self, ornament_col, 7.0, 1.4, 3.0, show_diamond)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_data.is_empty():
		return null

	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(92, 54)
	var p_style := HorrorTheme.make_panel_style(HorrorTheme.SURFACE, HorrorTheme.ACCENT, 3, 2, 8, 6)
	preview.add_theme_stylebox_override("panel", p_style)
	HorrorTheme.attach_corner_ornaments(preview, HorrorTheme.PRIMARY, 7.0, 1.4, 3.0, false)

	var pvbox := VBoxContainer.new()
	pvbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pvbox.add_theme_constant_override("separation", 2)
	var plabel := Label.new()
	plabel.text = str(item_data.get("name", ""))
	plabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HorrorTheme.style_label(plabel, "label-sm", HorrorTheme.ON_PRIMARY_CONTAINER, 11)
	pvbox.add_child(plabel)

	if item_data.has("quantity") and int(item_data["quantity"]) > 1:
		var pq := Label.new()
		pq.text = "x%d" % int(item_data["quantity"])
		pq.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		HorrorTheme.style_label(pq, "mono-sm", HorrorTheme.PRIMARY, 10)
		pvbox.add_child(pq)
	elif item_data.has("battery"):
		var pb := Label.new()
		pb.text = "%d%%" % int(round(float(item_data["battery"])))
		pb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		HorrorTheme.style_label(pb, "mono-sm", HorrorTheme.RELIC_BRASS, 10)
		pvbox.add_child(pb)

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
