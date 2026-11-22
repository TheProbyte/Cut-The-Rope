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


func _draw() -> void:
	var half := Vector2(length * 0.5, thickness * 0.5)
	var body_rect := Rect2(-half, Vector2(length, thickness))
	var shadow_rect := Rect2(-half + Vector2(3.5, 6.0), Vector2(length, thickness))

	draw_rect(shadow_rect, Color(0.10, 0.18, 0.12, 0.18))

	match style:
		"roof":
			# Sunlit conservatory glass or kitchen copper hood beam
			var base := Color(0.84, 0.90, 0.88, 0.88) if theme_name == "kitchen" else Color(0.76, 0.92, 0.88, 0.88)
			var rim := Color(0.52, 0.44, 0.36) if theme_name == "kitchen" else Color(0.30, 0.52, 0.46)
			draw_rect(body_rect, base)
			draw_rect(Rect2(-half, Vector2(length, thickness * 0.38)), Color(1.0, 1.0, 1.0, 0.55))
			draw_rect(body_rect, rim, false, 2.5)
			var step := 46.0
			var x := -half.x + step
			while x < half.x - 10.0:
				draw_line(Vector2(x, -half.y), Vector2(x, half.y), rim * Color(1, 1, 1, 0.65), 2.0)
				x += step
		"stone":
			if theme_name == "kitchen":
				# Cream & sage ceramic counter divider
				draw_rect(body_rect, Color(0.84, 0.87, 0.82))
				draw_rect(Rect2(-half, Vector2(length, thickness * 0.32)), Color(0.96, 0.98, 0.94, 0.72))
				draw_rect(Rect2(-half.x, half.y - thickness * 0.25, length, thickness * 0.25), Color(0.64, 0.69, 0.64, 0.55))
				var tx := -half.x + 36.0
				while tx < half.x - 14.0:
					draw_line(Vector2(tx, -half.y + 2), Vector2(tx, half.y - 2), Color(0.66, 0.72, 0.66, 0.6), 1.8)
					tx += 36.0
				draw_rect(body_rect, Color(0.46, 0.52, 0.47), false, 2.2)
			else:
				# Mossy slate greenhouse wall
				draw_rect(body_rect, Color(0.55, 0.61, 0.58))
				draw_rect(Rect2(-half, Vector2(length, thickness * 0.32)), Color(0.72, 0.78, 0.74, 0.55))
				draw_rect(Rect2(-half.x, half.y - thickness * 0.25, length, thickness * 0.25), Color(0.38, 0.44, 0.41, 0.55))
				draw_rect(body_rect, Color(0.32, 0.38, 0.35), false, 2.2)
		_:
			# Cozy warm cedar (Greenhouse) or honey oak butcher-block (Kitchen)
			var wood_base := Color(0.78, 0.58, 0.36) if theme_name == "kitchen" else Color(0.69, 0.49, 0.30)
			var wood_hi := Color(0.92, 0.76, 0.54, 0.75) if theme_name == "kitchen" else Color(0.84, 0.66, 0.45, 0.70)
			var wood_lo := Color(0.56, 0.38, 0.21, 0.55) if theme_name == "kitchen" else Color(0.48, 0.31, 0.17, 0.58)
			var wood_rim := Color(0.44, 0.28, 0.14)
			draw_rect(body_rect, wood_base)
			draw_rect(Rect2(-half, Vector2(length, thickness * 0.34)), wood_hi)
			draw_rect(Rect2(Vector2(-half.x, half.y - thickness * 0.26), Vector2(length, thickness * 0.26)), wood_lo)
			var gx := -half.x + 26.0
			while gx < half.x - 20.0:
				draw_line(Vector2(gx, -half.y * 0.15), Vector2(gx + 22.0, -half.y * 0.15), wood_lo, 1.6)
				gx += 44.0
			draw_rect(body_rect, wood_rim, false, 2.3)
			if length >= 52.0:
				var rivet := Color(0.90, 0.74, 0.42)
				draw_circle(Vector2(-half.x + 11.0, 0.0), 3.3, rivet)
				draw_circle(Vector2(half.x - 11.0, 0.0), 3.3, rivet)
				# Tiny decorative greenhouse sprout on horizontal-ish wooden benches
				if theme_name == "greenhouse" and absf(rotation) < 0.45 and length >= 110.0:
					var mx := -half.x + 30.0
					draw_circle(Vector2(mx, -half.y - 2.0), 4.2, Color(0.42, 0.76, 0.38, 0.85))
					draw_circle(Vector2(mx + 6.0, -half.y - 1.5), 3.2, Color(0.52, 0.84, 0.44, 0.85))
