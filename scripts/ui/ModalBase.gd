class_name ModalBase
extends CanvasLayer
## Shared modal scaffolding: dimmed backdrop + springy card with a ribbon title.

var _dim: ColorRect
var _center: CenterContainer
var _card: PanelContainer
var _content: VBoxContainer
var _ribbon: Ribbon
var _closing: bool = false


class Ribbon extends Control:
	var text: String = ""
	var color: Color = Color(0.30, 0.72, 0.44)
	var wiggle: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 70)

	func _process(delta: float) -> void:
		wiggle += delta
		queue_redraw()

	func _draw() -> void:
		var w := minf(size.x + 60.0, 520.0)
		var c := Vector2(size.x * 0.5, 30.0)
		var h := 64.0
		var body := Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h)
		var dark := color.darkened(0.35)
		# folded tails
		for s: float in [-1.0, 1.0]:
			var x0 := c.x + s * (w * 0.5 - 6.0)
			var tail := PackedVector2Array([
				Vector2(x0, c.y - h * 0.3), Vector2(x0 + s * 48.0, c.y - h * 0.3 + 8.0),
				Vector2(x0 + s * 34.0, c.y + h * 0.25 + 4.0), Vector2(x0 + s * 48.0, c.y + h * 0.5 + 12.0),
				Vector2(x0, c.y + h * 0.5 + 12.0),
			])
			draw_colored_polygon(tail, dark)
		Art.draw_rrect(self, Rect2(body.position + Vector2(0, 6), body.size), 14.0, dark.darkened(0.2))
		Art.draw_rrect_grad(self, body, 14.0, color.lightened(0.15), color)
		draw_rect(Rect2(body.position.x + 14, body.position.y + 6, body.size.x - 28, 5), Color(1, 1, 1, 0.3))
		var f := UIThemeHelper.get_display_font()
		if f != null:
			var fs := 46
			var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var p := Vector2(c.x - tw * 0.5, c.y + fs * 0.36)
			draw_string_outline(f, p + Vector2(0, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, dark.darkened(0.3))
			draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, dark)
			draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.06, 0.12, 0.09, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_build_backdrop()
	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", -34)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.add_child(holder)
	_ribbon = Ribbon.new()
	_ribbon.z_index = 1
	holder.add_child(_ribbon)
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(540, 0)
	_card.add_theme_stylebox_override("panel", UIThemeHelper.make_card_style())
	holder.add_child(_card)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 18)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_child(_content)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 26)
	_content.add_child(spacer)
	_build_content()


## Override: extra layers between the dim and the card.
func _build_backdrop() -> void:
	pass


## Override: fill _content.
func _build_content() -> void:
	pass


func _open(title: String, ribbon_color: Color) -> void:
	_closing = false
	_ribbon.text = title
	_ribbon.color = ribbon_color
	visible = true
	AudioManager.play_sfx("ui_open", 1.0, -6.0)
	_dim.modulate.a = 0.0
	var holder := _card.get_parent() as Control
	holder.pivot_offset = holder.size * 0.5
	holder.scale = Vector2(0.75, 0.75)
	holder.modulate.a = 0.0
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(_dim, "modulate:a", 1.0, 0.25)
	tw.tween_property(holder, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "modulate:a", 1.0, 0.18)
	# re-center pivot once the layout settles
	await get_tree().process_frame
	holder.pivot_offset = holder.size * 0.5


func close_modal() -> void:
	if not visible or _closing:
		return
	_closing = true
	var holder := _card.get_parent() as Control
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(_dim, "modulate:a", 0.0, 0.18)
	tw.tween_property(holder, "scale", Vector2(0.85, 0.85), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(holder, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(func():
		visible = false
		_closing = false
	)


func hide_now() -> void:
	visible = false
	_closing = false


func _row(sep: int = 14) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.add_theme_constant_override("separation", sep)
	return r


func _primary_button(text: String, icon: String, color: Color, height: float = 82.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIThemeHelper.style_primary(b, color, 32, 28)
	if icon != "":
		var ic := UIIcon.new()
		ic.kind = icon
		ic.custom_minimum_size = Vector2(44, 44)
		ic.anchor_left = 1.0
		ic.anchor_right = 1.0
		ic.anchor_top = 0.5
		ic.anchor_bottom = 0.5
		ic.offset_left = -64.0
		ic.offset_right = -20.0
		ic.offset_top = -25.0
		ic.offset_bottom = 19.0
		b.add_child(ic)
	return b
