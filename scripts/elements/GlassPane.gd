class_name GlassPane
extends StaticBody2D

signal shattered_impact(pos: Vector2)

var length: float = 160.0
var thickness: float = 14.0
var shattered: bool = false

var _time: float = 0.0
var _collider: CollisionShape2D
var _detector: Area2D
var _overlapping: Array[Droplet] = []
var _shards: Array[Dictionary] = []
var _flash: float = 0.0


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

	collision_layer = 4
	collision_mask = 0

	_collider = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length, thickness)
	_collider.shape = rect
	add_child(_collider)

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
	shattered_impact.emit(global_position)
	_flash = 1.0

	if droplet.linear_velocity.length() < 90.0:
		droplet.linear_velocity += Vector2(0.0, 95.0)

	var count := clampi(int(length / 13.0), 10, 18)
	for i in range(count):
		var t := (float(i) / float(count - 1)) - 0.5
		var local_x := t * length
		_shards.append({
			"pos": Vector2(local_x, randf_range(-4.0, 4.0)),
			"vel": Vector2(randf_range(-135.0, 135.0), randf_range(-65.0, 150.0)).rotated(-rotation),
			"rot": randf_range(0.0, TAU),
			"vrot": randf_range(-11.0, 11.0),
			"size": randf_range(6.5, 12.5),
			"life": randf_range(0.60, 0.92),
			"max_life": 0.92,
		})
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if not shattered:
		queue_redraw()
		return
	_flash = maxf(0.0, _flash - delta * 5.0)
	if _shards.is_empty() and _flash <= 0.0:
		queue_redraw()
		return
	var grav := Vector2(0.0, 540.0).rotated(-rotation)
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
	var half := Vector2(length * 0.5, thickness * 0.5)
	if not shattered:
		var rect := Rect2(-half, Vector2(length, thickness))
		var sh := rect
		sh.position += Vector2(2.0, 6.0).rotated(-rotation)
		Art.draw_rrect(self, sh, 4.0, Color(0.10, 0.26, 0.30, 0.12))
		Art.draw_glow(self, Vector2.ZERO, half.x * 0.9, Color(0.75, 0.96, 1.0, 0.18))
		Art.draw_rrect_grad(self, rect, 4.0, Color(0.86, 0.98, 1.0, 0.70), Color(0.58, 0.86, 0.94, 0.62))
		draw_rect(Rect2(-half.x + 4.0, -half.y + 2.0, length - 8.0, thickness * 0.3), Color(1, 1, 1, 0.55))
		var gx := -half.x + 20.0
		while gx < half.x - 14.0:
			draw_line(Vector2(gx, -half.y + 2.0), Vector2(gx - 7.0, half.y - 2.0), Color(1, 1, 1, 0.65), 2.2, true)
			draw_line(Vector2(gx + 6.0, -half.y + 3.0), Vector2(gx + 2.0, half.y - 3.0), Color(1, 1, 1, 0.35), 1.2, true)
			gx += 34.0
		var glint_x := lerpf(-half.x - 20.0, half.x + 20.0, fmod(_time * 0.4, 1.4) / 1.4)
		if absf(glint_x) < half.x - 10.0:
			draw_line(Vector2(glint_x, -half.y + 1.0), Vector2(glint_x - 10.0, half.y - 1.0), Color(1, 1, 1, 0.85), 5.0, true)
		Art.draw_rrect_outline(self, rect, 4.0, Color(0.30, 0.66, 0.80, 0.95), 2.2)
		for sx: float in [-1.0, 1.0]:
			var clamp := Rect2(Vector2(sx * half.x - (9.0 if sx > 0 else 0.0), -half.y - 3.0), Vector2(9.0, thickness + 6.0))
			Art.draw_rrect(self, clamp, 3.0, Color(0.50, 0.60, 0.62))
			draw_circle(clamp.get_center(), 1.8, Color(0.86, 0.92, 0.94))
	else:
		if _flash > 0.0:
			Art.draw_glow(self, Vector2.ZERO, half.x * 1.4, Color(0.9, 1.0, 1.0, _flash * 0.8))
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
			draw_polyline(Art.closed(tri), Color(1.0, 1.0, 1.0, 0.85 * a), 1.3, true)
			if int(sz * 10.0) % 3 == 0:
				Art.draw_sparkle(self, p, sz * 0.7 * a, Color(1, 1, 1, a))
