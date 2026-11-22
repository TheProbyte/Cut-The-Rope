class_name Drain
extends Area2D

signal droplet_drained(droplet: Droplet)

var width: float = 86.0
var _time: float = 0.0
var _triggered: bool = false


func configure(cfg: Dictionary) -> void:
	var pos_arr: Array = cfg.get("pos", [360, 1080])
	position = Vector2(float(pos_arr[0]), float(pos_arr[1]))
	width = float(cfg.get("width", 86.0))

	collision_layer = 16
	collision_mask = 8
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 28.0)
	shape.shape = rect
	add_child(shape)

	body_entered.connect(_on_body_entered)
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if _triggered:
		return
	if body is Droplet and (body as Droplet).active:
		_triggered = true
		droplet_drained.emit(body as Droplet)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var hw := width * 0.5
	var rim := Rect2(-hw - 8.0, -15.0, width + 16.0, 30.0)
	Art.draw_rrect(self, Rect2(rim.position + Vector2(2, 5), rim.size), 12.0, Color(0.10, 0.10, 0.12, 0.18))
	Art.draw_rrect_grad(self, rim, 12.0, Color(0.70, 0.40, 0.34), Color(0.48, 0.22, 0.20))
	# danger glow
	var pulse := 0.45 + 0.35 * sin(_time * 4.5)
	Art.draw_rrect_outline(self, rim.grow(2.0), 14.0, Color(1.0, 0.42, 0.32, pulse * 0.8), 2.4)
	# dark swirling hole
	var pit := Rect2(-hw, -9.0, width, 18.0)
	Art.draw_rrect_grad(self, pit, 8.0, Color(0.06, 0.07, 0.10), Color(0.16, 0.18, 0.24))
	for k in range(3):
		var a0 := -_time * (3.0 + float(k)) + float(k) * 2.1
		var rx := hw * (0.75 - float(k) * 0.2)
		var pts := PackedVector2Array()
		for i in range(8):
			var a := a0 + float(i) * 0.25
			pts.append(Vector2(cos(a) * rx, sin(a) * 6.0 * (0.8 - float(k) * 0.2)))
		draw_polyline(pts, Color(0.30, 0.48, 0.62, 0.55 - float(k) * 0.12), 1.8, true)
	# grate bars over the hole
	var x := -hw + 10.0
	while x < hw - 6.0:
		draw_line(Vector2(x, -8.0), Vector2(x, 8.0), Color(0.36, 0.34, 0.38), 3.0, true)
		draw_line(Vector2(x - 1.0, -8.0), Vector2(x - 1.0, 8.0), Color(0.64, 0.62, 0.66, 0.6), 1.0)
		x += 14.0
	draw_line(Vector2(-hw - 4.0, -13.0), Vector2(hw + 4.0, -13.0), Color(1.0, 0.70, 0.60, 0.55), 2.0, true)
