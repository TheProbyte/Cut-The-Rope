class_name ColdPipe
extends StaticBody2D

var length: float = 140.0
var radius: float = 15.0
var _time: float = 0.0
var _halo: Area2D
var _overlapping: Array[Droplet] = []


func configure(cfg: Dictionary) -> void:
	radius = float(cfg.get("radius", 15.0))
	if cfg.has("from") and cfg.has("to"):
		var a := Vector2(float(cfg["from"][0]), float(cfg["from"][1]))
		var b := Vector2(float(cfg["to"][0]), float(cfg["to"][1]))
		position = (a + b) * 0.5
		var diff := b - a
		length = maxf(32.0, diff.length())
		rotation = diff.angle()
	else:
		var pos_arr: Array = cfg.get("pos", [360, 320])
		position = Vector2(float(pos_arr[0]), float(pos_arr[1]))
		length = float(cfg.get("length", 140.0))
		rotation = deg_to_rad(float(cfg.get("rotation", 0.0)))

	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length, radius * 2.0)
	shape.shape = rect
	add_child(shape)

	# Condensation halo: turns touching Steam back into Water!
	_halo = Area2D.new()
	_halo.collision_layer = 16
	_halo.collision_mask = 8
	var hshape := CollisionShape2D.new()
	var hrect := RectangleShape2D.new()
	hrect.size = Vector2(length + 18.0, radius * 2.0 + 24.0)
	hshape.shape = hrect
	_halo.add_child(hshape)
	add_child(_halo)

	_halo.body_entered.connect(_on_body_entered)
	_halo.body_exited.connect(_on_body_exited)
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if body is Droplet:
		var d := body as Droplet
		if not _overlapping.has(d):
			_overlapping.append(d)
		if d.is_steam():
			d.condense_to_water()


func _on_body_exited(body: Node) -> void:
	if body is Droplet:
		_overlapping.erase(body as Droplet)


func _physics_process(_delta: float) -> void:
	for d in _overlapping:
		if is_instance_valid(d) and d.active and d.is_steam():
			d.condense_to_water()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var half := Vector2(length * 0.5, radius)
	var rect := Rect2(-half, Vector2(length, radius * 2.0))
	var pulse := 0.8 + sin(_time * 2.6) * 0.2
	# icy aura
	Art.draw_rrect(self, rect.grow(10.0), radius + 10.0, Color(0.55, 0.88, 1.0, 0.10 * pulse))
	Art.draw_rrect(self, rect.grow(5.0), radius + 5.0, Color(0.55, 0.88, 1.0, 0.14 * pulse))
	var sh := rect
	sh.position += Vector2(3.0, 6.0).rotated(-rotation)
	Art.draw_rrect(self, sh, radius, Color(0.08, 0.20, 0.30, 0.18))
	# steel body
	Art.draw_rrect_grad(self, rect, radius, Color(0.62, 0.86, 0.96), Color(0.22, 0.50, 0.70))
	Art.draw_rrect(self, Rect2(-half.x + 6.0, -half.y + 3.0, length - 12.0, radius * 0.55), radius * 0.3, Color(1, 1, 1, 0.45))
	# frost crust along the top
	var fx := -half.x + 8.0
	var i := 0
	while fx < half.x - 8.0:
		var w := 9.0 + float((i * 7) % 5) * 2.0
		Art.draw_ellipse(self, Vector2(fx + w * 0.5, -half.y + 1.0), w * 0.55, 3.6, Color(0.95, 0.99, 1.0, 0.95), 12)
		fx += w
		i += 1
	Art.draw_rrect_outline(self, rect, radius, Color(0.14, 0.34, 0.50), 2.4)
	# flanges
	for sx: float in [-1.0, 1.0]:
		var fl := Rect2(Vector2(sx * half.x - 6.0, -half.y - 5.0), Vector2(12.0, radius * 2.0 + 10.0))
		Art.draw_rrect_grad(self, fl, 4.0, Color(0.72, 0.88, 0.96), Color(0.36, 0.60, 0.76))
		Art.draw_rrect_outline(self, fl, 4.0, Color(0.14, 0.34, 0.50), 2.0)
	# icicles + falling condensation
	var x := -half.x + 18.0
	var k := 0
	while x < half.x - 14.0:
		var ln := 6.0 + float((k * 5) % 4) * 2.5
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 3.5, half.y - 1.0), Vector2(x + 3.5, half.y - 1.0), Vector2(x, half.y + ln),
		]), Color(0.86, 0.97, 1.0, 0.95))
		var drip_t := fmod(_time * 0.7 + float(k) * 0.37, 1.0)
		draw_circle(Vector2(x, half.y + ln + drip_t * 18.0), 2.2 * (1.0 - drip_t), Color(0.55, 0.88, 1.0, 0.8 * (1.0 - drip_t)))
		x += 26.0
		k += 1
	# cold mist wisps
	for m in range(3):
		var t := fmod(_time * 0.35 + float(m) * 0.33, 1.0)
		var mx := lerpf(-half.x * 0.7, half.x * 0.7, float(m) / 2.0) + sin(_time + float(m)) * 6.0
		draw_circle(Vector2(mx, half.y + 10.0 + t * 26.0), 6.0 + t * 8.0, Color(0.85, 0.96, 1.0, 0.22 * (1.0 - t)))
