class_name PauseModal
extends ModalBase

signal resumed
signal restarted
signal level_select_requested

var _subtitle: Label
var _music_btn: Button
var _sfx_btn: Button
var _haptic_btn: Button


func _build_content() -> void:
	_subtitle = UIThemeHelper.make_label("", 24, Color(0.40, 0.54, 0.46))
	_content.add_child(_subtitle)

	var resume_btn := _primary_button("RESUME", "play", UIThemeHelper.C_GREEN, 88)
	resume_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		resumed.emit()
	)
	_content.add_child(resume_btn)

	var row := _row()
	_content.add_child(row)
	var restart_btn := _primary_button("RESTART", "", UIThemeHelper.C_ORANGE, 70)
	restart_btn.add_theme_font_size_override("font_size", 24)
	restart_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_tap")
		restarted.emit()
	)
	row.add_child(restart_btn)
	var levels_btn := _primary_button("LEVELS", "", UIThemeHelper.C_BLUE, 70)
	levels_btn.add_theme_font_size_override("font_size", 24)
	levels_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_back")
		level_select_requested.emit()
	)
	row.add_child(levels_btn)

	var toggles := _row(22)
	_content.add_child(toggles)
	_music_btn = UIThemeHelper.make_icon_button("music", UIThemeHelper.C_SAGE, 68)
	_music_btn.pressed.connect(func():
		AudioManager.toggle_music()
		AudioManager.play_sfx("ui_tap")
		_refresh_toggles()
	)
	toggles.add_child(_music_btn)
	_sfx_btn = UIThemeHelper.make_icon_button("sfx", UIThemeHelper.C_SAGE, 68)
	_sfx_btn.pressed.connect(func():
		AudioManager.toggle_sfx()
		AudioManager.play_sfx("ui_tap")
		_refresh_toggles()
	)
	toggles.add_child(_sfx_btn)
	_haptic_btn = UIThemeHelper.make_icon_button("haptics", UIThemeHelper.C_SAGE, 68)
	_haptic_btn.pressed.connect(func():
		SaveManager.toggle_haptics()
		AudioManager.play_sfx("ui_tap")
		SaveManager.haptic(30)
		_refresh_toggles()
	)
	toggles.add_child(_haptic_btn)
	_refresh_toggles()


func open_modal(display_number: int = 0, title: String = "") -> void:
	_subtitle.text = "Level %d  ·  %s" % [display_number, title] if display_number > 0 else ""
	_refresh_toggles()
	_open("PAUSED", Color(0.36, 0.62, 0.50))


func _refresh_toggles() -> void:
	_set_toggle(_music_btn, "music", SaveManager.is_music_enabled())
	_set_toggle(_sfx_btn, "sfx", SaveManager.is_sfx_enabled())
	_set_toggle(_haptic_btn, "haptics", SaveManager.is_haptics_enabled())


static func _set_toggle(btn: Button, kind: String, on: bool) -> void:
	UIThemeHelper.set_icon(btn, kind if on else kind + "_off")
	var col := UIThemeHelper.C_SAGE if on else UIThemeHelper.C_MUTED
	UIThemeHelper.style_button(btn, col, col.lightened(0.08), col.darkened(0.06), Color.WHITE, 20, 34)
