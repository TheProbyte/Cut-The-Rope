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
	var pulse := 0.72 + 0.28 * sin(_time * 5.2)

	# Warm radiant glow above burner
	draw_rect(Rect2(-hw, -22.0, width, 20.0), Color(1.0, 0.34, 0.14, 0.22 * pulse))

	# Cast-iron stove base
	var base := Rect2(-hw - 6.0, -10.0, width + 12.0, 24.0)
	draw_rect(Rect2(-hw - 4.0, -6.0, width + 12.0, 24.0), Color(0.10, 0.10, 0.12, 0.22))
	draw_rect(base, Color(0.22, 0.22, 0.25))
	draw_rect(Rect2(-hw - 6.0, -10.0, width + 12.0, 6.0), Color(0.36, 0.36, 0.40))
	draw_rect(base, Color(0.12, 0.12, 0.15), false, 2.2)

	# Glowing crimson-orange heating coil bars on top
	var coil_y := -11.0
	draw_line(Vector2(-hw + 4.0, coil_y), Vector2(hw - 4.0, coil_y), Color(1.0, 0.26, 0.10, 0.95), 6.0, true)
	draw_line(Vector2(-hw + 8.0, coil_y - 1.0), Vector2(hw - 8.0, coil_y - 1.0), Color(1.0, 0.76, 0.30, pulse), 2.8, true)

	# Tiny burner indicator knob
	draw_circle(Vector2(hw - 10.0, 3.0), 4.0, Color(1.0, 0.36, 0.18, pulse))

	# Rising wavy heat lines
	for i in range(3):
		var hx := lerpf(-hw * 0.55, hw * 0.55, float(i) / 2.0)
		var pts := PackedVector2Array()
		for k in range(5):
			var fy := -18.0 - float(k) * 8.0
			var fx := hx + sin(_time * 6.0 + float(k) * 1.1 + float(i) * 2.0) * 4.0
			pts.append(Vector2(fx, fy))
		draw_polyline(pts, Color(1.0, 0.52, 0.22, 0.42 * pulse), 2.0, true)

	# Sizzle steam puffs on fail
	for p in _puffs:
		var a: float = clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
		draw_circle(p["pos"], float(p["r"]) * (1.2 - 0.3 * a), Color(1.0, 0.96, 0.94, a * 0.85))
