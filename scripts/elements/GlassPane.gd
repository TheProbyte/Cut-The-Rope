class_name GlassPane
extends StaticBody2D

var length: float = 160.0
var thickness: float = 14.0
var shattered: bool = false

var _collider: CollisionShape2D
var _detector: Area2D
var _overlapping: Array[Droplet] = []
var _shards: Array[Dictionary] = []


func configure(cfg: Dictionary) -> void:
	thickness = float(cfg.get("thickness", 14.0))
	if cfg.has("from") and cfg.has("to"):
		var a := Vector2(float(cfg["from"][0]), float(cfg["from"][1]))
		var b := Vector2(float(cfg["to"][0]), float(cfg["to"][1]))
		position = (a + b) * 0.5
		var diff := b - a
		length = maxf(28.0, diff.length())
		rotation = diff.angle()
	else:
		var pos_arr: Array = cfg.get("pos", [360, 640])
		position = Vector2(float(pos_arr[0]), float(pos_arr[1]))
		length = float(cfg.get("length", 160.0))
		rotation = deg_to_rad(float(cfg.get("rotation", 0.0)))

	# Layer 3: blocks all states until Ice shatters it
	collision_layer = 4
	collision_mask = 0

	_collider = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length, thickness)
	_collider.shape = rect
	add_child(_collider)

	# Expanded detector catches both fast Ice impacts AND Water resting on glass that freezes into Ice!
	_detector = Area2D.new()
	_detector.collision_layer = 16
	_detector.collision_mask = 8
	var det_shape := CollisionShape2D.new()
	var det_rect := RectangleShape2D.new()
	det_rect.size = Vector2(length + 8.0, thickness + 18.0)
	det_shape.shape = det_rect
	_detector.add_child(det_shape)
	add_child(_detector)

	_detector.body_entered.connect(_on_body_entered)
	_detector.body_exited.connect(_on_body_exited)
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if shattered:
		return
	if body is Droplet:
		var d := body as Droplet
		if not _overlapping.has(d):
			_overlapping.append(d)
		if d.is_ice():
			_shatter(d)


func _on_body_exited(body: Node) -> void:
	if body is Droplet:
		_overlapping.erase(body as Droplet)


func _physics_process(_delta: float) -> void:
	if shattered:
		return
	for d in _overlapping:
		if is_instance_valid(d) and d.active and d.is_ice():
			_shatter(d)
			break


func _shatter(droplet: Droplet) -> void:
	if shattered:
		return
	shattered = true
	_collider.set_deferred("disabled", true)
	_detector.set_deferred("monitoring", false)
	AudioManager.play_sfx("glass_shatter")

	# Give a gentle downward nudge if the ice cube was resting stationary on top of the pane
	if droplet.linear_velocity.length() < 90.0:
		droplet.linear_velocity += Vector2(0.0, 95.0)

	# Spawn crystalline glass shards
	var count := clampi(int(length / 16.0), 8, 16)
	for i in range(count):
		var t := (float(i) / float(count - 1)) - 0.5
		var local_x := t * length
		_shards.append({
			"pos": Vector2(local_x, randf_range(-4.0, 4.0)),
			"vel": Vector2(randf_range(-110.0, 110.0), randf_range(-40.0, 140.0)).rotated(-rotation),
			"rot": randf_range(0.0, TAU),
			"vrot": randf_range(-9.0, 9.0),
			"size": randf_range(6.0, 11.0),
			"life": randf_range(0.55, 0.85),
			"max_life": 0.85,
		})
	queue_redraw()


func _process(delta: float) -> void:
	if _shards.is_empty():
		return
	var grav := Vector2(0.0, 520.0).rotated(-rotation)
	for i in range(_shards.size() - 1, -1, -1):
		var s: Dictionary = _shards[i]
		s["life"] = float(s["life"]) - delta
		if float(s["life"]) <= 0.0:
			_shards.remove_at(i)
		else:
			var vel: Vector2 = (s["vel"] as Vector2) + grav * delta
			s["vel"] = vel
			s["pos"] = (s["pos"] as Vector2) + vel * delta
			s["rot"] = float(s["rot"]) + float(s["vrot"]) * delta
	queue_redraw()


func _draw() -> void:
	if not shattered:
		var half := Vector2(length * 0.5, thickness * 0.5)
		var rect := Rect2(-half, Vector2(length, thickness))
		# Translucent turquoise greenhouse glass
		draw_rect(rect, Color(0.68, 0.92, 0.96, 0.55))
		# Diagonal bright glare streaks
		var gx := -half.x + 18.0
		while gx < half.x - 14.0:
			draw_line(Vector2(gx, -half.y + 1.5), Vector2(gx - 8.0, half.y - 1.5), Color(1.0, 1.0, 1.0, 0.72), 2.5, true)
			gx += 32.0
		# Subtle crack-ready tint border
		draw_rect(rect, Color(0.45, 0.78, 0.86, 0.92), false, 2.2)
		# Small side mounting clips
		draw_rect(Rect2(-half.x - 2.0, -half.y - 2.0, 8.0, thickness + 4.0), Color(0.54, 0.62, 0.64))
		draw_rect(Rect2(half.x - 6.0, -half.y - 2.0, 8.0, thickness + 4.0), Color(0.54, 0.62, 0.64))
	else:
		for s in _shards:
			var a: float = clampf(float(s["life"]) / float(s["max_life"]), 0.0, 1.0)
			var p: Vector2 = s["pos"]
			var sz: float = s["size"]
			var r: float = s["rot"]
			var tri := PackedVector2Array([
				p + Vector2(sz, 0.0).rotated(r),
				p + Vector2(-sz * 0.6, sz * 0.65).rotated(r),
				p + Vector2(-sz * 0.5, -sz * 0.7).rotated(r),
			])
			draw_colored_polygon(tri, Color(0.76, 0.96, 1.0, 0.85 * a))
