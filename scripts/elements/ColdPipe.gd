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

	# Cold blue aura
	var pulse := 0.8 + sin(_time * 3.0) * 0.2
	draw_rect(Rect2(-half - Vector2(5, 6), Vector2(length + 10, radius * 2.0 + 12)), Color(0.45, 0.84, 1.0, 0.18 * pulse))

	# Drop shadow
	draw_rect(Rect2(-half + Vector2(3, 5), Vector2(length, radius * 2.0)), Color(0.10, 0.22, 0.30, 0.20))

	# Metallic blue-steel pipe body
	draw_rect(rect, Color(0.32, 0.62, 0.78))
	draw_rect(Rect2(-half.x, -half.y + 3.0, length, radius * 0.65), Color(0.76, 0.94, 1.0, 0.68))
	draw_rect(Rect2(-half.x, half.y - radius * 0.45, length, radius * 0.45), Color(0.20, 0.42, 0.56, 0.55))
	draw_rect(rect, Color(0.18, 0.38, 0.52), false, 2.2)

	# Flanged end caps
	for sx: float in [-1.0, 1.0]:
		var fx: float = sx * half.x - 5.0
		draw_rect(Rect2(fx, -half.y - 4.0, 10.0, radius * 2.0 + 8.0), Color(0.48, 0.74, 0.86))
		draw_rect(Rect2(fx, -half.y - 4.0, 10.0, radius * 2.0 + 8.0), Color(0.18, 0.38, 0.52), false, 2.0)

	# Tiny condensation beads hanging under pipe
	var step := 36.0
	var x := -half.x + 24.0
	while x < half.x - 18.0:
		var drip := sin(_time * 2.8 + x * 0.1) * 1.5
		draw_circle(Vector2(x, half.y + 3.0 + drip), 3.0, Color(0.55, 0.90, 1.0, 0.85))
		x += step
