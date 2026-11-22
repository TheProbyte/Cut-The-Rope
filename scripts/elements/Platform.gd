class_name Platform
extends StaticBody2D

var length: float = 200.0
var thickness: float = 22.0
var style: String = "wood"
var theme_name: String = "greenhouse"


func configure(cfg: Dictionary, p_theme: String = "greenhouse") -> void:
	theme_name = p_theme
	thickness = float(cfg.get("thickness", 22.0))
	style = String(cfg.get("style", "wood"))
	if cfg.has("from") and cfg.has("to"):
		var a := Vector2(float(cfg["from"][0]), float(cfg["from"][1]))
		var b := Vector2(float(cfg["to"][0]), float(cfg["to"][1]))
		position = (a + b) * 0.5
		var diff := b - a
		length = maxf(16.0, diff.length())
		rotation = diff.angle()
	else:
		var pos_arr: Array = cfg.get("pos", [360, 640])
		var size_arr: Array = cfg.get("size", [200, 22])
		position = Vector2(float(pos_arr[0]), float(pos_arr[1]))
		length = float(size_arr[0])
		thickness = float(size_arr[1])
		rotation = deg_to_rad(float(cfg.get("rotation", 0.0)))

	collision_layer = 1
	collision_mask = 0
	var mat := PhysicsMaterial.new()
	mat.friction = 0.04
	mat.bounce = 0.1
	physics_material_override = mat

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length, thickness)
	shape.shape = rect
	add_child(shape)
	queue_redraw()


func _shadow_offset() -> Vector2:
	return Vector2(3.0, 7.0).rotated(-rotation)


func _draw() -> void:
	var half := Vector2(length * 0.5, thickness * 0.5)
	var rect := Rect2(-half, Vector2(length, thickness))
	var rad := minf(thickness * 0.42, 9.0)
	var sh := rect
	sh.position += _shadow_offset()
	Art.draw_rrect(self, sh, rad, Color(0.10, 0.16, 0.10, 0.16))
	Art.draw_rrect(self, sh.grow(2.0), rad + 2.0, Color(0.10, 0.16, 0.10, 0.06))

	match style:
		"roof":
			_draw_roof(rect, rad, half)
		"stone":
			_draw_stone(rect, rad, half)
		_:
			_draw_wood(rect, rad, half)


func _draw_wood(rect: Rect2, rad: float, half: Vector2) -> void:
	var k := theme_name == "kitchen"
	var top := Color(0.93, 0.74, 0.50) if k else Color(0.84, 0.62, 0.40)
	var bot := Color(0.74, 0.52, 0.30) if k else Color(0.62, 0.42, 0.24)
	var rim := Color(0.42, 0.26, 0.13)
	Art.draw_rrect_grad(self, rect, rad, top, bot)
	# top bevel light + bottom lip
	Art.draw_rrect(self, Rect2(rect.position + Vector2(3, 2), Vector2(length - 6, thickness * 0.28)), rad * 0.6, Color(1.0, 0.92, 0.74, 0.45))
	draw_rect(Rect2(-half.x + rad, half.y - thickness * 0.22, length - rad * 2.0, thickness * 0.18), Color(0.40, 0.24, 0.10, 0.22))
	# wavy grain
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x * 13.0 + position.y * 7.0)
	var grain := Color(0.48, 0.30, 0.15, 0.35)
	for row in range(2):
		var gy := lerpf(-half.y * 0.35, half.y * 0.35, float(row))
		var gx := -half.x + rng.randf_range(10.0, 30.0)
		while gx < half.x - 24.0:
			var seg := rng.randf_range(18.0, 40.0)
			var pts := PackedVector2Array()
			for i in range(5):
				var t := float(i) / 4.0
				pts.append(Vector2(gx + seg * t, gy + sin(t * PI * 2.0 + gx) * 1.2))
			draw_polyline(pts, grain, 1.4, true)
			gx += seg + rng.randf_range(16.0, 36.0)
	if length > 90.0 and thickness >= 18.0:
		var kx := rng.randf_range(-half.x * 0.5, half.x * 0.5)
		Art.draw_ellipse(self, Vector2(kx, 1), 4.5, 2.6, Color(0.46, 0.28, 0.14, 0.45), 14)
	Art.draw_rrect_outline(self, rect, rad, rim, 2.4)
	if length >= 52.0:
		for sx: float in [-1.0, 1.0]:
			var nail := Vector2(sx * (half.x - 10.0), 0.0)
			draw_circle(nail, 3.0, Color(0.52, 0.40, 0.28))
			draw_circle(nail + Vector2(-0.8, -0.8), 1.4, Color(0.94, 0.84, 0.66))
	# greenhouse moss / kitchen nothing
	if theme_name == "greenhouse" and absf(rotation) < 0.5 and length >= 110.0:
		for mx in [-half.x + 26.0, half.x * 0.35]:
			var tuft := Vector2(mx, -half.y)
			for i in range(3):
				Art.draw_ellipse(self, tuft + Vector2(float(i) * 6.0 - 6.0, -1.0), 4.2, 3.0, Color(0.42, 0.74, 0.38, 0.9), 10)
			Art.draw_ellipse(self, tuft + Vector2(9.0, -5.0), 3.2, 5.5, Color(0.50, 0.82, 0.44, 0.9), 10)


func _draw_stone(rect: Rect2, rad: float, half: Vector2) -> void:
	if theme_name == "kitchen":
		Art.draw_rrect_grad(self, rect, rad, Color(0.95, 0.96, 0.93), Color(0.78, 0.82, 0.78))
		Art.draw_rrect(self, Rect2(rect.position + Vector2(3, 2), Vector2(length - 6, thickness * 0.3)), rad * 0.6, Color(1, 1, 1, 0.6))
		var tx := -half.x + 34.0
		while tx < half.x - 12.0:
			draw_line(Vector2(tx, -half.y + 3), Vector2(tx, half.y - 3), Color(0.62, 0.70, 0.64, 0.55), 1.8)
			tx += 34.0
		Art.draw_rrect_outline(self, rect, rad, Color(0.40, 0.48, 0.44), 2.3)
	else:
		Art.draw_rrect_grad(self, rect, rad, Color(0.70, 0.76, 0.72), Color(0.50, 0.56, 0.53))
		Art.draw_rrect(self, Rect2(rect.position + Vector2(3, 2), Vector2(length - 6, thickness * 0.3)), rad * 0.6, Color(0.88, 0.92, 0.88, 0.5))
		var rng := RandomNumberGenerator.new()
		rng.seed = int(position.x * 11.0 + position.y * 5.0)
		var sx := -half.x + rng.randf_range(18.0, 40.0)
		while sx < half.x - 16.0:
			Art.draw_ellipse(self, Vector2(sx, rng.randf_range(-2.0, 3.0)), rng.randf_range(3.0, 6.0), rng.randf_range(1.8, 3.0), Color(0.40, 0.46, 0.43, 0.35), 12)
			sx += rng.randf_range(26.0, 48.0)
		Art.draw_rrect_outline(self, rect, rad, Color(0.28, 0.34, 0.31), 2.3)
		# moss caps along the top edge
		var mx := -half.x + 8.0
		while mx < half.x - 8.0:
			var w := rng.randf_range(10.0, 22.0)
			Art.draw_ellipse(self, Vector2(mx + w * 0.5, -half.y + 1.0), w * 0.5, 3.4, Color(0.44, 0.72, 0.40, 0.85), 12)
			mx += w + rng.randf_range(14.0, 40.0)


func _draw_roof(rect: Rect2, rad: float, half: Vector2) -> void:
	var k := theme_name == "kitchen"
	var frame := Color(0.66, 0.52, 0.38) if k else Color(0.30, 0.52, 0.46)
	Art.draw_rrect_grad(self, rect, rad, Color(0.90, 0.98, 1.0, 0.85), Color(0.70, 0.88, 0.90, 0.85))
	Art.draw_rrect(self, Rect2(rect.position + Vector2(3, 2), Vector2(length - 6, thickness * 0.34)), rad * 0.6, Color(1, 1, 1, 0.7))
	var step := 46.0
	var x := -half.x + step
	while x < half.x - 10.0:
		draw_line(Vector2(x, -half.y + 1), Vector2(x, half.y - 1), Color(frame.r, frame.g, frame.b, 0.7), 2.4)
		draw_line(Vector2(x - 16, -half.y + 3), Vector2(x - 22, half.y - 3), Color(1, 1, 1, 0.7), 2.0, true)
		x += step
	Art.draw_rrect_outline(self, rect, rad, frame, 2.6)
