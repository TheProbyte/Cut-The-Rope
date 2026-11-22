class_name GreenhouseBackground
extends Node2D

const SUNBEAMS_SHADER := preload("res://assets/shaders/sunbeams.gdshader")
const PAPER_GRAIN_PATH := "res://assets/textures/paper_grain.png"

var theme_name: String = "greenhouse"

var _time: float = 0.0
var _motes: Array[Dictionary] = []
var _clouds: Array[Dictionary] = []
var _vines: Array[Dictionary] = []
var _sunbeam_rect: ColorRect
var _paper_rect: TextureRect


func set_theme(p_theme: String) -> void:
	theme_name = p_theme.to_lower()
	_update_shader_colors()
	queue_redraw()


func _ready() -> void:
	z_index = -20
	for i in range(22):
		_motes.append({
			"pos": Vector2(randf_range(34, 686), randf_range(115, 1180)),
			"speed": randf_range(7.0, 18.0),
			"phase": randf_range(0.0, TAU),
			"r": randf_range(2.2, 4.8),
		})
	for i in range(4):
		_clouds.append({
			"x": randf_range(40.0, 680.0),
			"y": randf_range(145.0, 340.0),
			"speed": randf_range(6.0, 13.0),
			"scale": randf_range(0.75, 1.25),
		})
	for x in [62.0, 185.0, 535.0, 658.0]:
		_vines.append({
			"x": x,
			"len": randf_range(95.0, 165.0),
			"phase": randf_range(0.0, TAU),
		})

	# Animated diagonal morning sunbeams (GLES3 shader)
	_sunbeam_rect = ColorRect.new()
	_sunbeam_rect.position = Vector2(14, 86)
	_sunbeam_rect.size = Vector2(692, 1180)
	_sunbeam_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sunbeam_rect.z_index = 1
	var mat := ShaderMaterial.new()
	mat.shader = SUNBEAMS_SHADER
	_sunbeam_rect.material = mat
	add_child(_sunbeam_rect)

	# Subtle cozy paper grain overlay
	if ResourceLoader.exists(PAPER_GRAIN_PATH):
		_paper_rect = TextureRect.new()
		_paper_rect.texture = load(PAPER_GRAIN_PATH)
		_paper_rect.stretch_mode = TextureRect.STRETCH_TILE
		_paper_rect.position = Vector2.ZERO
		_paper_rect.size = Vector2(720, 1280)
		_paper_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_paper_rect.modulate = Color(1, 1, 1, 0.45)
		_paper_rect.z_index = 2
		add_child(_paper_rect)

	_update_shader_colors()


func _update_shader_colors() -> void:
	if _sunbeam_rect == null or _sunbeam_rect.material == null:
		return
	var mat := _sunbeam_rect.material as ShaderMaterial
	if theme_name == "kitchen":
		mat.set_shader_parameter("ray_color", Color(1.0, 0.94, 0.74, 0.24))
	else:
		mat.set_shader_parameter("ray_color", Color(1.0, 0.98, 0.82, 0.22))


func _process(delta: float) -> void:
	_time += delta
	for m in _motes:
		var p: Vector2 = m["pos"]
		p.y -= float(m["speed"]) * delta
		p.x += sin(_time * 0.9 + float(m["phase"])) * 8.0 * delta
		if p.y < 100.0:
			p.y = 1200.0
			p.x = randf_range(34.0, 686.0)
		m["pos"] = p
	for c in _clouds:
		c["x"] = float(c["x"]) + float(c["speed"]) * delta
		if float(c["x"]) > 790.0:
			c["x"] = -90.0
	queue_redraw()


func _draw() -> void:
	if theme_name == "kitchen":
		_draw_kitchen()
	else:
		_draw_greenhouse()

	# Floating golden sunlit dust motes
	for m in _motes:
		var glow := 0.30 + 0.28 * sin(_time * 2.4 + float(m["phase"]))
		var r: float = m["r"]
		draw_circle(m["pos"], r * 2.1, Color(1.0, 0.96, 0.74, glow * 0.28))
		draw_circle(m["pos"], r, Color(1.0, 0.98, 0.84, glow))

	# Subtle soft warm vignette along outer edges
	draw_rect(Rect2(14.0, 86.0, 692.0, 26.0), Color(0.16, 0.24, 0.18, 0.08))
	draw_rect(Rect2(14.0, 1235.0, 692.0, 45.0), Color(0.14, 0.20, 0.14, 0.14))


func _draw_greenhouse() -> void:
	# Smooth 16-band pastel sunlit conservatory sky-to-sage gradient
	var top_col := Color(0.84, 0.95, 0.97)
	var mid_col := Color(0.95, 0.98, 0.90)
	var bot_col := Color(0.76, 0.89, 0.76)
	var bands := 16
	var bh := 1280.0 / float(bands)
	for i in range(bands):
		var t := float(i) / float(bands - 1)
		var col := top_col.lerp(mid_col, t * 2.0) if t < 0.5 else mid_col.lerp(bot_col, (t - 0.5) * 2.0)
		draw_rect(Rect2(0.0, float(i) * bh, 720.0, bh + 2.0), col)

	# Drifting soft clouds outside the conservatory glass
	for c in _clouds:
		var cp := Vector2(float(c["x"]), float(c["y"]))
		var sc: float = c["scale"]
		var col := Color(1.0, 1.0, 0.99, 0.58)
		draw_circle(cp, 26.0 * sc, col)
		draw_circle(cp + Vector2(-24.0, 8.0) * sc, 20.0 * sc, col)
		draw_circle(cp + Vector2(26.0, 7.0) * sc, 21.0 * sc, col)
		draw_circle(cp + Vector2(4.0, -10.0) * sc, 22.0 * sc, col)

	# Arched Victorian conservatory glass mullions
	var glass_tint := Color(1.0, 1.0, 1.0, 0.14)
	draw_rect(Rect2(14.0, 86.0, 692.0, 1194.0), glass_tint)
	var mullion_hi := Color(1.0, 1.0, 1.0, 0.62)
	var mullion_sh := Color(0.56, 0.72, 0.60, 0.42)
	for x in [120.0, 240.0, 360.0, 480.0, 600.0]:
		draw_line(Vector2(x, 86.0), Vector2(x, 1280.0), mullion_hi, 4.5)
		draw_line(Vector2(x + 2.5, 86.0), Vector2(x + 2.5, 1280.0), mullion_sh, 1.8)
	for y in [295.0, 540.0, 785.0, 1030.0]:
		draw_line(Vector2(14.0, y), Vector2(706.0, y), mullion_hi, 3.5)
		draw_line(Vector2(14.0, y + 2.0), Vector2(706.0, y + 2.0), mullion_sh, 1.5)
	# Subtle gothic arches across top bays
	for cx in [180.0, 300.0, 420.0, 540.0]:
		draw_arc(Vector2(cx, 295.0), 60.0, PI, TAU, 20, mullion_hi, 3.2, true)

	# Distant sunlit botanical silhouettes (soft depth)
	var bush_back := Color(0.56, 0.77, 0.58, 0.30)
	var bush_front := Color(0.46, 0.69, 0.49, 0.34)
	for b in [[68, 1180, 92], [175, 1215, 76], [285, 1235, 68], [440, 1230, 72], [565, 1210, 82], [662, 1175, 96]]:
		draw_circle(Vector2(b[0], b[1]), float(b[2]), bush_back)
	for b in [[34, 1225, 76], [132, 1248, 62], [608, 1242, 68], [688, 1220, 78]]:
		draw_circle(Vector2(b[0], b[1]), float(b[2]), bush_front)

	# Swaying hanging ivy vines from the upper conservatory eaves
	for v in _vines:
		var bx: float = v["x"]
		var vlen: float = v["len"]
		var ph: float = v["phase"]
		var sway := sin(_time * 1.4 + ph) * 9.0
		var pts := PackedVector2Array()
		var segs := 6
		for s in range(segs + 1):
			var frac := float(s) / float(segs)
			var px := bx + sway * (frac * frac) + sin(frac * 5.0 + ph) * 4.0
			var py := 92.0 + frac * vlen
			pts.append(Vector2(px, py))
			if s > 0:
				var side := -1.0 if s % 2 == 0 else 1.0
				var lp := Vector2(px + side * 9.0, py)
				draw_circle(lp, 6.2 - frac * 1.8, Color(0.42, 0.72, 0.44, 0.46))
		draw_polyline(pts, Color(0.32, 0.58, 0.34, 0.46), 2.4, true)

	# Cozy cedar conservatory side frames
	draw_rect(Rect2(0.0, 0.0, 15.0, 1280.0), Color(0.48, 0.34, 0.22))
	draw_rect(Rect2(11.0, 0.0, 4.0, 1280.0), Color(0.68, 0.52, 0.36, 0.65))
	draw_rect(Rect2(705.0, 0.0, 15.0, 1280.0), Color(0.48, 0.34, 0.22))
	draw_rect(Rect2(705.0, 0.0, 4.0, 1280.0), Color(0.68, 0.52, 0.36, 0.65))


func _draw_kitchen() -> void:
	# Warm cream-to-peach sunlit cottage kitchen wall gradient
	var top_col := Color(0.99, 0.96, 0.89)
	var mid_col := Color(0.97, 0.92, 0.83)
	var bot_col := Color(0.91, 0.84, 0.74)
	var bands := 14
	var bh := 1280.0 / float(bands)
	for i in range(bands):
		var t := float(i) / float(bands - 1)
		var col := top_col.lerp(mid_col, t * 2.0) if t < 0.5 else mid_col.lerp(bot_col, (t - 0.5) * 2.0)
		draw_rect(Rect2(0.0, float(i) * bh, 720.0, bh + 2.0), col)

	# Arched sunlit garden window in upper-center background
	var win_rect := Rect2(175.0, 175.0, 370.0, 290.0)
	draw_rect(win_rect, Color(0.83, 0.94, 0.97, 0.72))
	draw_circle(Vector2(360.0, 175.0), 185.0, Color(0.83, 0.94, 0.97, 0.72))
	# Drifting clouds visible inside kitchen window
	for c in _clouds:
		var cx: float = clampf(float(c["x"]), 210.0, 510.0)
		var cy: float = clampf(float(c["y"]), 150.0, 330.0)
		if float(c["x"]) > 185.0 and float(c["x"]) < 535.0:
			draw_circle(Vector2(cx, cy), 18.0, Color(1.0, 1.0, 1.0, 0.65))
			draw_circle(Vector2(cx + 16.0, cy + 4.0), 14.0, Color(1.0, 1.0, 1.0, 0.65))
	# Window sash & wooden frame
	var sash := Color(0.99, 0.97, 0.92, 0.88)
	draw_line(Vector2(360.0, 90.0), Vector2(360.0, 465.0), sash, 6.0)
	draw_line(Vector2(175.0, 295.0), Vector2(545.0, 295.0), sash, 6.0)
	draw_rect(win_rect, Color(0.76, 0.58, 0.40, 0.55), false, 6.0)
	draw_arc(Vector2(360.0, 175.0), 185.0, PI, TAU, 28, Color(0.76, 0.58, 0.40, 0.55), 6.0, true)
	# Cozy window sill
	draw_rect(Rect2(158.0, 462.0, 404.0, 14.0), Color(0.80, 0.62, 0.44, 0.65))

	# Cream & sage ceramic subway tile backsplash (lower half)
	var tile_top := 520.0
	var tile_h := 44.0
	var tile_w := 88.0
	var grout := Color(0.84, 0.78, 0.69, 0.45)
	var tile_tint := Color(0.95, 0.96, 0.90, 0.36)
	draw_rect(Rect2(14.0, tile_top, 692.0, 760.0), tile_tint)
	var row := 0
	var ty := tile_top
	while ty < 1280.0:
		draw_line(Vector2(14.0, ty), Vector2(706.0, ty), grout, 2.0)
		var offset := (tile_w * 0.5) if (row % 2 == 1) else 0.0
		var tx := 14.0 + offset
		while tx < 706.0:
			draw_line(Vector2(tx, ty), Vector2(tx, ty + tile_h), grout, 2.0)
			tx += tile_w
		ty += tile_h
		row += 1

	# Decorative copper rail & subtle hanging kitchen silhouettes
	draw_line(Vector2(45.0, 518.0), Vector2(675.0, 518.0), Color(0.78, 0.50, 0.32, 0.42), 5.0)
	for hx in [95.0, 625.0]:
		draw_line(Vector2(hx, 518.0), Vector2(hx, 558.0), Color(0.74, 0.48, 0.32, 0.32), 3.0)
		draw_circle(Vector2(hx, 578.0), 22.0, Color(0.78, 0.50, 0.34, 0.22))
		draw_circle(Vector2(hx, 578.0), 14.0, Color(0.90, 0.66, 0.46, 0.22))

	# Warm oak kitchen side trims
	draw_rect(Rect2(0.0, 0.0, 15.0, 1280.0), Color(0.56, 0.39, 0.25))
	draw_rect(Rect2(11.0, 0.0, 4.0, 1280.0), Color(0.82, 0.66, 0.46, 0.60))
	draw_rect(Rect2(705.0, 0.0, 15.0, 1280.0), Color(0.56, 0.39, 0.25))
	draw_rect(Rect2(705.0, 0.0, 4.0, 1280.0), Color(0.82, 0.66, 0.46, 0.60))
