class_name TransitionLayer
extends CanvasLayer

const TRANSITION_SHADER := preload("res://assets/shaders/screen_transition.gdshader")

var _rect: ColorRect
var _mat: ShaderMaterial
var _busy: bool = false


func _ready() -> void:
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


func transition_to(mid_callback: Callable, curtain_color: Color = Color(0.16, 0.52, 0.68, 1.0), fast: bool = false) -> void:
	if _busy:
		mid_callback.call()
		return
	_busy = true
	_rect.visible = true
	_mat.set_shader_parameter("curtain_color", curtain_color)
	var half_dur := 0.14 if fast else 0.24

	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_method(_set_progress, 0.0, 1.0, half_dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		mid_callback.call()
	)
	tw.tween_method(_set_progress, 1.0, 0.0, half_dur + 0.06).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_rect.visible = false
		_busy = false
	)


func _set_progress(v: float) -> void:
	_mat.set_shader_parameter("progress", v)
