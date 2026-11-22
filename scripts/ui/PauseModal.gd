class_name PauseModal
extends CanvasLayer

signal resumed
signal restarted
signal level_select_requested

var _card: PanelContainer
var _music_btn: Button
var _sfx_btn: Button


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.14, 0.10, 0.56)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(476, 460)
	_card.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(
		Color(0.99, 0.98, 0.94),
		Color(0.44, 0.66, 0.48),
		30,
		3,
		7
	))
	center.add_child(_card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIThemeHelper.apply_display_font(title, 44, Color(0.18, 0.36, 0.24))
	vbox.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = "RESUME"
	resume_btn.custom_minimum_size = Vector2(0, 68)
	UIThemeHelper.style_button(resume_btn, Color(0.28, 0.72, 0.44), Color(0.35, 0.78, 0.50), Color(0.22, 0.60, 0.36), Color.WHITE, 26, 20)
	resume_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		resumed.emit()
	)
	vbox.add_child(resume_btn)

	var restart_btn := Button.new()
	restart_btn.text = "RESTART LEVEL"
	restart_btn.custom_minimum_size = Vector2(0, 62)
	UIThemeHelper.style_button(restart_btn, Color(0.88, 0.58, 0.26), Color(0.94, 0.65, 0.34), Color(0.76, 0.46, 0.18), Color.WHITE, 24, 18)
	restart_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		restarted.emit()
	)
	vbox.add_child(restart_btn)

	var audio_row := HBoxContainer.new()
	audio_row.add_theme_constant_override("separation", 14)
	vbox.add_child(audio_row)

	_music_btn = Button.new()
	_music_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_music_btn.custom_minimum_size = Vector2(0, 56)
	_music_btn.pressed.connect(func():
		AudioManager.toggle_music()
		AudioManager.play_sfx("ui_tap")
		_refresh_audio_buttons()
	)
	audio_row.add_child(_music_btn)

	_sfx_btn = Button.new()
	_sfx_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sfx_btn.custom_minimum_size = Vector2(0, 56)
	_sfx_btn.pressed.connect(func():
		AudioManager.toggle_sfx()
		AudioManager.play_sfx("ui_tap")
		_refresh_audio_buttons()
	)
	audio_row.add_child(_sfx_btn)

	var levels_btn := Button.new()
	levels_btn.text = "LEVEL SELECT"
	levels_btn.custom_minimum_size = Vector2(0, 58)
	UIThemeHelper.style_button(levels_btn, Color(0.42, 0.62, 0.54), Color(0.50, 0.70, 0.62), Color(0.34, 0.52, 0.45), Color.WHITE, 22, 18)
	levels_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		level_select_requested.emit()
	)
	vbox.add_child(levels_btn)

	_refresh_audio_buttons()


func open_modal() -> void:
	_refresh_audio_buttons()
	visible = true
	_card.pivot_offset = _card.custom_minimum_size * 0.5
	_card.scale = Vector2(0.78, 0.78)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh_audio_buttons() -> void:
	var m_on := SaveManager.is_music_enabled()
	_music_btn.text = "MUSIC: ON" if m_on else "MUSIC: OFF"
	UIThemeHelper.style_button(
		_music_btn,
		Color(0.24, 0.64, 0.78) if m_on else Color(0.62, 0.68, 0.66),
		Color(0.30, 0.70, 0.84) if m_on else Color(0.68, 0.74, 0.72),
		Color(0.18, 0.54, 0.66),
		Color.WHITE,
		20,
		16
	)
	var s_on := SaveManager.is_sfx_enabled()
	_sfx_btn.text = "SFX: ON" if s_on else "SFX: OFF"
	UIThemeHelper.style_button(
		_sfx_btn,
		Color(0.24, 0.64, 0.78) if s_on else Color(0.62, 0.68, 0.66),
		Color(0.30, 0.70, 0.84) if s_on else Color(0.68, 0.74, 0.72),
		Color(0.18, 0.54, 0.66),
		Color.WHITE,
		20,
		16
	)
