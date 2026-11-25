extends Control

# Lencana Centang Biru Vektor (bukan emoji) untuk akun terverifikasi.
const BADGE_BLUE := Color(0.114, 0.608, 0.941, 1.0)
const BADGE_RING := Color(0.06, 0.44, 0.78, 0.92)
const BADGE_CHECK := Color(1.0, 1.0, 1.0, 1.0)

static var _tex_cache: Dictionary = {}

@export var badge_size: float = 15.0:
	set(value):
		badge_size = maxf(10.0, value)
		custom_minimum_size = Vector2(badge_size, badge_size)
		queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(badge_size, badge_size)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = "Akun Terverifikasi"

func _draw() -> void:
	var s: float = minf(size.x, size.y)
	if s <= 1.0:
		s = badge_size
	var center := size * 0.5
	var r_outer: float = s * 0.45

	# Bentuk segel bergerigi 8-lekuk khas verifikasi (tanpa emoji)
	var pts := PackedVector2Array()
	var steps: int = 32
	for i: int in range(steps):
		var a: float = (float(i) / float(steps)) * TAU
		var lobe: float = cos(a * 8.0) * (r_outer * 0.085)
		var r: float = r_outer * 0.92 + lobe
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, BADGE_BLUE)
	pts.append(pts[0])
	draw_polyline(pts, BADGE_RING, maxf(1.0, s * 0.055), true)

	# Centang putih tegas
	var check := PackedVector2Array([
		center + Vector2(-r_outer * 0.42, r_outer * 0.02),
		center + Vector2(-r_outer * 0.12, r_outer * 0.34),
		center + Vector2(r_outer * 0.46, -r_outer * 0.32)
	])
	draw_polyline(check, BADGE_CHECK, maxf(1.8, s * 0.17), true)

static func create_control(target_size: float = 15.0) -> Control:
	var badge := new()
	badge.badge_size = target_size
	return badge

static func get_texture(px: int = 32) -> ImageTexture:
	var clamped: int = clampi(px, 16, 64)
	if _tex_cache.has(clamped):
		return _tex_cache[clamped] as ImageTexture

	# Rasterisasi 2x supersampled untuk ketajaman ikon pada RichTextLabel dan 3D Sprite3D
	var ss: int = clamped * 2
	var img := Image.create(ss, ss, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var c := Vector2(float(ss) * 0.5, float(ss) * 0.5)
	var r_outer: float = float(ss) * 0.44

	for y: int in range(ss):
		for x: int in range(ss):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var dv: Vector2 = p - c
			var dist: float = dv.length()
			var ang: float = atan2(dv.y, dv.x)
			var seal_r: float = r_outer * 0.92 + cos(ang * 8.0) * (r_outer * 0.085)
			if dist <= seal_r + 1.0:
				var edge_a: float = clampf(seal_r + 0.6 - dist, 0.0, 1.0)
				var col: Color = BADGE_RING if dist > seal_r - (float(ss) * 0.04) else BADGE_BLUE
				col.a *= edge_a
				img.set_pixel(x, y, col)

	# Segmen garis centang putih (A -> B -> C)
	var a_pt: Vector2 = c + Vector2(-r_outer * 0.42, r_outer * 0.02)
	var b_pt: Vector2 = c + Vector2(-r_outer * 0.12, r_outer * 0.34)
	var c_pt: Vector2 = c + Vector2(r_outer * 0.46, -r_outer * 0.32)
	var stroke_r: float = maxf(1.5, float(ss) * 0.085)
	for y: int in range(ss):
		for x: int in range(ss):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var d1: float = _dist_point_segment(p, a_pt, b_pt)
			var d2: float = _dist_point_segment(p, b_pt, c_pt)
			var d: float = minf(d1, d2)
			if d <= stroke_r + 0.9:
				var w_a: float = clampf(stroke_r + 0.5 - d, 0.0, 1.0)
				var base: Color = img.get_pixel(x, y)
				img.set_pixel(x, y, base.lerp(BADGE_CHECK, w_a))

	img.resize(clamped, clamped, Image.INTERPOLATE_BILINEAR)
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[clamped] = tex
	return tex

static func _dist_point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq <= 0.0001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)
