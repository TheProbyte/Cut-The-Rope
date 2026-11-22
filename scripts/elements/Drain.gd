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
	var rim := Rect2(-hw - 6.0, -14.0, width + 12.0, 28.0)
	var pit := Rect2(-hw, -9.0, width, 18.0)

	# Outer warning terracotta/iron rim
	draw_rect(rim, Color(0.52, 0.24, 0.22))
	draw_rect(rim, Color(0.86, 0.36, 0.28, 0.9), false, 2.4)

	# Dark recessed drain opening
	draw_rect(pit, Color(0.14, 0.14, 0.17))

	# Animated subtle danger bars & suction shimmer
	var bar_step := 14.0
	var x := -hw + 10.0
	while x < hw - 6.0:
		draw_line(Vector2(x, -8.0), Vector2(x, 8.0), Color(0.32, 0.30, 0.34), 2.5)
		x += bar_step

	var pulse := 0.45 + 0.35 * sin(_time * 4.5)
	draw_line(Vector2(-hw + 4.0, -13.0), Vector2(hw - 4.0, -13.0), Color(0.98, 0.44, 0.34, pulse), 2.2)
