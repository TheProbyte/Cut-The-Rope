class_name TransitionLayer
extends CanvasLayer
## Liquid iris transition between screens/levels. One instance lives in Main;
## anything can trigger it through the static `run()` helper.

const TRANSITION_SHADER := preload("res://assets/shaders/screen_transition.gdshader")

static var _instance: TransitionLayer = null

var _rect: ColorRect
var _mat: ShaderMaterial
var _logo: Control
var _busy: bool = false
var _progress: float = 0.0
var _art := DropletArt.new()


class Logo extends Control:
	var owner_layer: TransitionLayer

	func _draw() -> void:
		owner_layer._draw_logo(self)


## Run a transition: close the iris (towards `center`, in viewport pixels),
## call `mid_callback` while covered, then open again.
static func run(mid_callback: Callable, curtain_color: Color = Color(0.15, 0.55, 0.70), center: Vector2 = Vector2(-1, -1), fast: bool = false) -> void:
	if _instance == null or not is_instance_valid(_instance):
		mid_callback.call()
		return
	_instance.transition_to(mid_callback, curtain_color, fast, center)


func _ready() -> void:
	_instance = self
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = TRANSITION_SHADER
	_mat.set_shader_parameter("progress", 0.0)
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)

	_logo = Logo.new()
	_logo.owner_layer = self
	_logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.visible = false
	add_child(_logo)


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func is_busy() -> bool:
	return _busy


func transition_to(mid_callback: Callable, curtain_color: Color = Color(0.15, 0.55, 0.70), fast: bool = false, center: Vector2 = Vector2(-1, -1)) -> void:
	if _busy:
		return
	_busy = true
	var vp_size := get_viewport().get_visible_rect().size
	var c := center if center.x >= 0.0 else vp_size * 0.5
	_mat.set_shader_parameter("center", Vector2(c.x / vp_size.x, c.y / vp_size.y))
	_mat.set_shader_parameter("aspect", vp_size.x / vp_size.y)
	_mat.set_shader_parameter("curtain_color", curtain_color)
	_rect.visible = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_logo.visible = not fast
	_art.state = 0
	_art.prev_state = 0
	_art.morph = 1.0
	var close_dur := 0.16 if fast else 0.34
	var open_dur := 0.22 if fast else 0.42

	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_method(_set_progress, 0.0, 1.0, close_dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		# Re-center the opening iris on the screen middle for a calm reveal.
		_mat.set_shader_parameter("center", Vector2(0.5, 0.5))
		mid_callback.call()
	)
	tw.tween_interval(0.06 if fast else 0.14)
	tw.tween_method(_set_progress, 1.0, 0.0, open_dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_rect.visible = false
		_logo.visible = false
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_busy = false
	)


func _set_progress(v: float) -> void:
	_progress = v
	_mat.set_shader_parameter("progress", v)
	_logo.queue_redraw()


func _process(delta: float) -> void:
	if _logo.visible:
		_art.advance(delta)
		_logo.queue_redraw()


func _draw_logo(ci: Control) -> void:
	var a := clampf((_progress - 0.75) / 0.25, 0.0, 1.0)
	if a <= 0.0:
		return
	var c := ci.size * 0.5
	var bounce := absf(sin(_art.time * 5.0)) * 18.0
	Art.draw_ellipse(ci, c + Vector2(0, 46), 30.0 - bounce * 0.4, 7.0, Color(0, 0, 0, 0.16 * a))
	_art.alpha = a
	_art.size = 1.7
	_art.pop = 1.0
	_art.squish = 0.12 if bounce < 3.0 else -0.04
	_art.velocity = Vector2.ZERO
	_art.mood = "happy"
	_art.draw(ci, c + Vector2(0, -bounce))
