class_name HotPlate
extends Area2D

signal droplet_sizzled(droplet: Droplet)

const HEAT_SHIMMER_SHADER := preload("res://assets/shaders/heat_shimmer.gdshader")

var width: float = 112.0
var _time: float = 0.0
var _triggered: bool = false
var _puffs: Array[Dictionary] = []


func configure(cfg: Dictionary) -> void:
	var pos_arr: Array = cfg.get("pos", [360, 1020])
	position = Vector2(float(pos_arr[0]), float(pos_arr[1]))
	width = float(cfg.get("width", 112.0))

	collision_layer = 16
	collision_mask = 8
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 26.0)
	shape.shape = rect
	add_child(shape)

	# Rising heat shimmer directly above burner
	var shimmer := ColorRect.new()
	shimmer.position = Vector2(-width * 0.48, -68.0)
	shimmer.size = Vector2(width * 0.96, 60.0)
	shimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = HEAT_SHIMMER_SHADER
	mat.set_shader_parameter("glow_color", Color(1.0, 0.36, 0.14, 0.24))
	mat.set_shader_parameter("speed", 4.5)
	shimmer.material = mat
	add_child(shimmer)

	body_entered.connect(_on_body_entered)
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if _triggered:
		return
	if body is Droplet:
		var d := body as Droplet
		if d.active and not d.soaked:
			_triggered = true
			for i in range(12):
				_puffs.append({
					"pos": Vector2(randf_range(-width * 0.3, width * 0.3), -10.0),
					"vel": Vector2(randf_range(-45, 45), randf_range(-130, -55)),
					"life": 0.55,
					"max_life": 0.55,
					"r": randf_range(6.0, 11.0),
				})
			droplet_sizzled.emit(d)


func _process(delta: float) -> void:
	_time += delta
	for i in range(_puffs.size() - 1, -1, -1):
		var p: Dictionary = _puffs[i]
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			_puffs.remove_at(i)
		else:
			p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
	queue_redraw()


func _draw() -> void:
	var hw := width * 0.5
	var pulse := 0.72 + 0.28 * sin(_time * 5.0)
	Art.draw_glow(self, Vector2(0, -14), hw * 1.2, Color(1.0, 0.40, 0.14, 0.40 * pulse))
	var base := Rect2(-hw - 8.0, -10.0, width + 16.0, 26.0)
	Art.draw_rrect(self, Rect2(base.position + Vector2(3, 6), base.size), 8.0, Color(0.08, 0.08, 0.10, 0.22))
	Art.draw_rrect_grad(self, base, 8.0, Color(0.40, 0.40, 0.44), Color(0.18, 0.18, 0.22))
	Art.draw_rrect_outline(self, base, 8.0, Color(0.10, 0.10, 0.12), 2.2)
	# glowing burner plate
	var plate := Rect2(-hw, -15.0, width, 9.0)
	Art.draw_rrect_grad(self, plate, 4.5, Color(1.0, 0.62, 0.30), Color(0.90, 0.20, 0.08))
	draw_line(Vector2(-hw + 8.0, -13.0), Vector2(hw - 8.0, -13.0), Color(1.0, 0.90, 0.60, pulse), 2.2, true)
	Art.draw_rrect_outline(self, plate, 4.5, Color(0.50, 0.10, 0.04), 1.8)
	# knobs
	for kx: float in [-hw + 6.0, hw - 6.0]:
		draw_circle(Vector2(kx, 5.0), 5.0, Color(0.86, 0.84, 0.80))
		draw_line(Vector2(kx, 5.0), Vector2(kx + 2.5, 1.5), Color(0.30, 0.30, 0.32), 2.0, true)
	draw_circle(Vector2(0, 5.0), 3.0, Color(1.0, 0.36, 0.18, pulse))
	# heat waves
	for i in range(3):
		var hx := lerpf(-hw * 0.55, hw * 0.55, float(i) / 2.0)
		var pts := PackedVector2Array()
		for k in range(6):
			pts.append(Vector2(hx + sin(_time * 6.0 + float(k) * 1.1 + float(i) * 2.0) * 4.0, -20.0 - float(k) * 8.0))
		draw_polyline(pts, Color(1.0, 0.52, 0.22, 0.45 * pulse), 2.2, true)
	for p in _puffs:
		var a: float = clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
		draw_circle(p["pos"], float(p["r"]) * (1.4 - 0.4 * a), Color(1.0, 0.98, 0.96, a * 0.85))
