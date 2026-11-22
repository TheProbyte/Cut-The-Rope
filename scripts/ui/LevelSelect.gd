class_name LevelSelect
extends Node2D
## World map: levels as badges along a growing vine; swipe or tab between worlds.

signal level_selected(world_id: String, level_index: int, from_pos: Vector2)
signal back_pressed

var active_world: String = "greenhouse"

var _bg: WorldBackground
var _frame: Control
var _map: MapView
var _title: Label
var _subtitle: Label
var _badge_label: Label
var _tab_row: HBoxContainer
var _tab_buttons: Dictionary = {}
var _locked_card: PanelContainer
var _locked_label: Label
var _press_pos: Vector2 = Vector2.INF
var _switching: bool = false


class LevelNode extends Control:
	var number: int = 1
	var title: String = ""
	var stars: int = 0
	var unlocked: bool = false
	var completed: bool = false
	var current: bool = false
	var accent: Color = Color(0.30, 0.70, 0.44)
	var finale: bool = false
	var t: float = 0.0
	var art := DropletArt.new()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.size = 0.8

	func _process(delta: float) -> void:
		t += delta
		art.advance(delta)
		if current or completed:
			queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, 62.0)
		var r := 54.0 if finale else 48.0
		var pressed_off := 0.0
		var btn := get_parent() as BaseButton
		if btn != null and btn.button_pressed:
			pressed_off = 4.0
		if current:
			var pulse := 0.5 + 0.5 * sin(t * 4.0)
			draw_arc(c, r + 10.0 + pulse * 6.0, 0.0, TAU, 48, Color(1, 1, 1, 0.75 - pulse * 0.4), 5.0, true)
			Art.draw_glow(self, c, r * 2.2, Color(1.0, 0.95, 0.7, 0.45))
		Art.draw_ellipse(self, c + Vector2(0, 8), r, r * 0.96, Color(0.08, 0.14, 0.10, 0.22))
		var face := Color(0.80, 0.84, 0.80)
		var lip := Color(0.62, 0.68, 0.64)
		if unlocked:
			face = accent
			lip = accent.darkened(0.32)
		var cc := c + Vector2(0, pressed_off)
		Art.draw_ellipse(self, cc + Vector2(0, 6 - pressed_off), r, r * 0.96, lip)
		var disc := Art.ellipse_points(cc, r, r * 0.96, 40)
		draw_polygon(disc, Art.vgrad_colors(disc, face.lightened(0.22), face))
		Art.draw_ellipse(self, cc + Vector2(-r * 0.32, -r * 0.42), r * 0.34, r * 0.16, Color(1, 1, 1, 0.35))
		if finale and unlocked:
			for i in range(8):
				var a := TAU * float(i) / 8.0 + t * 0.3
				Art.draw_ellipse(self, cc + Vector2.from_angle(a) * (r + 6.0), 9.0, 9.0, Color(1.0, 0.80, 0.30, 0.9))
		var f := UIThemeHelper.get_display_font()
		if unlocked and f != null:
			var txt := str(number)
			var fs := 46 if number < 10 else 40
			var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var p := cc + Vector2(-w * 0.5, fs * 0.36)
			draw_string_outline(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 9, lip.darkened(0.2))
			draw_string(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		elif not unlocked:
			_draw_lock(cc)
		# stars arc
		if unlocked:
			for i in range(3):
				var a := PI * 0.5 + (float(i) - 1.0) * 0.55
				var sp := c + Vector2.from_angle(a) * (r + 6.0) + Vector2(0, 4)
				Art.draw_sun(self, sp, 14.0 if i != 1 else 16.0, 0.0, i < stars)
		if current:
			var hop := absf(sin(t * 3.4)) * 16.0
			art.squish = 0.15 if hop < 2.0 else -0.05
			art.draw(self, c + Vector2(0, -r - 30.0 - hop))
		if title != "" and f != null:
			var bf := UIThemeHelper.get_body_font()
			var fs2 := 18
			var w2 := bf.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
			var tp := Vector2(c.x - w2 * 0.5, c.y + r + 44.0)
			var tc := Color(0.22, 0.34, 0.26) if unlocked else Color(0.46, 0.52, 0.48, 0.8)
			draw_string_outline(bf, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, 6, Color(1, 1, 1, 0.85))
			draw_string(bf, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, tc)

	func _draw_lock(c: Vector2) -> void:
		var col := Color(0.52, 0.58, 0.54)
		draw_arc(c + Vector2(0, -6), 11.0, PI, TAU, 16, col, 6.0, true)
		draw_line(c + Vector2(-11, -6), c + Vector2(-11, 0), col, 6.0)
		draw_line(c + Vector2(11, -6), c + Vector2(11, 0), col, 6.0)
		Art.draw_rrect(self, Rect2(c + Vector2(-16, -2), Vector2(32, 24)), 6.0, col)
		draw_circle(c + Vector2(0, 8), 3.5, Color(0.80, 0.84, 0.80))


class MapView extends Control:
	var points: Array[Vector2] = []
	var done: Array[bool] = []
	var accent: Color = Color(0.30, 0.70, 0.44)
	var t: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _curve(a: Vector2, b: Vector2, steps: int = 18) -> PackedVector2Array:
		var mid := (a + b) * 0.5
		var bend := Vector2.ZERO
		if absf(a.y - b.y) > 20.0:
			bend = Vector2((1.0 if a.x > 360.0 else -1.0) * 70.0, 0)
		else:
			bend = Vector2(0, -24)
		var ctrl := mid + bend
		var pts := PackedVector2Array()
		for i in range(steps + 1):
			var s := float(i) / float(steps)
			pts.append(a.lerp(ctrl, s).lerp(ctrl.lerp(b, s), s))
		return pts

	func _draw() -> void:
		for i in range(points.size() - 1):
			var pts := _curve(points[i] + Vector2(0, 62), points[i + 1] + Vector2(0, 62))
			if done[i]:
				draw_polyline(pts, Color(0.10, 0.20, 0.12, 0.15), 14.0, true)
				draw_polyline(pts, Art.LEAF_DEEP, 11.0, true)
				draw_polyline(pts, Art.LEAF, 6.0, true)
				for k in range(3, pts.size() - 3, 5):
					var dir := (pts[k + 1] - pts[k]).normalized()
					var side := 1.0 if k % 2 == 0 else -1.0
					var sway := sin(t * 2.0 + float(k)) * 0.2
					var leaf_dir := dir.rotated(side * (1.0 + sway))
					var base := pts[k]
					var lp := PackedVector2Array([base, base + leaf_dir * 9 + leaf_dir.orthogonal() * 6, base + leaf_dir * 20, base + leaf_dir * 9 - leaf_dir.orthogonal() * 6])
					draw_colored_polygon(lp, Art.LEAF_LIGHT)
					draw_polyline(Art.closed(lp), Art.LEAF_DEEP, 1.2, true)
			else:
				for k in range(0, pts.size(), 2):
					draw_circle(pts[k], 4.0, Color(1, 1, 1, 0.75))
					draw_circle(pts[k], 2.6, Color(0.56, 0.64, 0.58, 0.7))


func _ready() -> void:
	var cam := Camera2D.new()
	cam.position = Vector2(360, 640)
	add_child(cam)
	cam.make_current()
	_bg = WorldBackground.new()
	add_child(_bg)
	_build_ui()
	_select_world(active_world, 0)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 6
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	_frame = Control.new()
	_frame.set_anchors_preset(Control.PRESET_CENTER)
	_frame.offset_left = -360
	_frame.offset_right = 360
	_frame.offset_top = -640
	_frame.offset_bottom = 640
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_frame)

	_map = MapView.new()
	_map.position = Vector2.ZERO
	_map.size = Vector2(720, 1280)
	_frame.add_child(_map)

	_locked_card = PanelContainer.new()
	_locked_card.add_theme_stylebox_override("panel", UIThemeHelper.make_card_style(28))
	_locked_card.position = Vector2(110, 560)
	_locked_card.custom_minimum_size = Vector2(500, 0)
	_frame.add_child(_locked_card)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	_locked_card.add_child(lv)
	var lock_icon := UIIcon.new()
	lock_icon.kind = "lock"
	lock_icon.color = Color(0.52, 0.60, 0.56)
	lock_icon.custom_minimum_size = Vector2(0, 64)
	lv.add_child(lock_icon)
	_locked_label = UIThemeHelper.make_label("", 24, UIThemeHelper.C_INK, false)
	_locked_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(_locked_label)

	# Header (hugs the real top edge)
	var header := VBoxContainer.new()
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 20
	header.offset_right = -20
	header.offset_top = UIThemeHelper.safe_top(get_viewport()) + 16
	header.add_theme_constant_override("separation", 14)
	root.add_child(header)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	header.add_child(top)
	var back_btn := UIThemeHelper.make_icon_button("back", UIThemeHelper.C_SAGE, 68)
	back_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_back")
		back_pressed.emit()
	)
	top.add_child(back_btn)
	var tcol := VBoxContainer.new()
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tcol.add_theme_constant_override("separation", -6)
	tcol.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(tcol)
	_title = UIThemeHelper.make_label("GREENHOUSE", 38, UIThemeHelper.C_INK, true, HORIZONTAL_ALIGNMENT_LEFT)
	_title.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	_title.add_theme_constant_override("outline_size", 8)
	tcol.add_child(_title)
	_subtitle = UIThemeHelper.make_label("", 18, Color(0.36, 0.48, 0.40), false, HORIZONTAL_ALIGNMENT_LEFT)
	_subtitle.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.8))
	_subtitle.add_theme_constant_override("outline_size", 5)
	tcol.add_child(_subtitle)
	var badge := PanelContainer.new()
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(Color(1.0, 0.985, 0.95, 0.94), Color(0.84, 0.88, 0.80), 22, 0, 4))
	top.add_child(badge)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 4)
	badge.add_child(brow)
	var sun := UIIcon.new()
	sun.kind = "star"
	sun.shadow = false
	sun.custom_minimum_size = Vector2(34, 34)
	brow.add_child(sun)
	_badge_label = UIThemeHelper.make_label("0/30", 24, Color(0.80, 0.50, 0.08))
	brow.add_child(_badge_label)

	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", 12)
	header.add_child(_tab_row)
	var worlds := LevelRegistry.get_worlds()
	for i in range(worlds.size()):
		var w: Dictionary = worlds[i]
		var w_id := String(w.get("id", ""))
		var tab := Button.new()
		tab.text = String(w.get("name", "World")).to_upper()
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size = Vector2(0, 60)
		var captured := w_id
		tab.pressed.connect(func():
			if captured == active_world:
				return
			AudioManager.play_sfx("ui_tap")
			var dir := 1 if LevelRegistry.get_world_index(captured) > LevelRegistry.get_world_index(active_world) else -1
			_select_world(captured, dir)
		)
		_tab_row.add_child(tab)
		_tab_buttons[w_id] = tab


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_press_pos = mb.position
		elif _press_pos != Vector2.INF:
			var d := mb.position - _press_pos
			_press_pos = Vector2.INF
			if absf(d.x) > 140.0 and absf(d.y) < 100.0:
				var wi := LevelRegistry.get_world_index(active_world) + (1 if d.x < 0 else -1)
				var worlds := LevelRegistry.get_worlds()
				if wi >= 0 and wi < worlds.size():
					AudioManager.play_sfx("ui_whoosh", 1.2, -8.0)
					_select_world(String(worlds[wi].get("id", "")), 1 if d.x < 0 else -1)


func _node_positions(count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var per_row := 3
	var rows := int(ceil(float(count) / float(per_row)))
	var top := 330.0
	var spacing := minf(240.0, 900.0 / maxf(1.0, float(rows)))
	var xs := [150.0, 360.0, 570.0]
	for i in range(count):
		var row := i / per_row
		var col := i % per_row
		if row % 2 == 1:
			col = per_row - 1 - col
		var x: float = xs[col]
		var remaining := count - row * per_row
		if remaining == 1:
			x = 360.0
		out.append(Vector2(x, top + float(row) * spacing + (12.0 if col == 1 else 0.0)))
	return out


func _select_world(world_id: String, slide_dir: int) -> void:
	if _switching:
		return
	if slide_dir != 0:
		_switching = true
		var tw := _map.create_tween()
		tw.set_parallel(true)
		tw.tween_property(_map, "position:x", -slide_dir * 720.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(_map, "modulate:a", 0.0, 0.2)
		tw.chain().tween_callback(func():
			_populate(world_id)
			_map.position.x = slide_dir * 720.0
			var tw2 := _map.create_tween()
			tw2.set_parallel(true)
			tw2.tween_property(_map, "position:x", 0.0, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw2.tween_property(_map, "modulate:a", 1.0, 0.2)
			tw2.chain().tween_callback(func(): _switching = false)
		)
	else:
		_populate(world_id)
		for i in range(_map.get_child_count()):
			UIThemeHelper.pop_in(_map.get_child(i) as Control, 0.05 + float(i) * 0.035, 0.4, 0.4)


func _populate(world_id: String) -> void:
	active_world = world_id
	_bg.set_theme(world_id)
	var world := LevelRegistry.get_world(world_id)
	var accent := WorldBackground.accent_color(world_id)
	var world_open := SaveManager.is_world_unlocked(world_id)
	if world_open:
		SaveManager.mark_world_seen(world_id)
	_title.text = String(world.get("name", "World")).to_upper()
	_subtitle.text = String(world.get("subtitle", ""))
	var ws := SaveManager.get_world_stars(world_id)
	_badge_label.text = "%d/%d" % [ws.x, ws.y]

	for wid: String in _tab_buttons.keys():
		var btn: Button = _tab_buttons[wid]
		var sel := wid == active_world
		var col := WorldBackground.accent_color(wid) if sel else Color(1.0, 0.985, 0.95)
		var txt := Color.WHITE if sel else Color(0.36, 0.46, 0.40)
		UIThemeHelper.style_button(btn, col, col.lightened(0.05), col.darkened(0.06), txt, 24, 22)
		var open := SaveManager.is_world_unlocked(wid)
		var wname := String(LevelRegistry.get_world(wid).get("name", "")).to_upper()
		btn.text = wname if open else wname + "  (locked)"
		if open and not SaveManager.has_seen_world(wid):
			btn.text = wname + "  · NEW!"

	for c in _map.get_children():
		c.queue_free()
	var levels := LevelRegistry.get_world_levels(world_id)
	var pts := _node_positions(levels.size())
	var next_unfinished := -1
	for i in range(levels.size()):
		if SaveManager.is_level_unlocked(world_id, i) and not SaveManager.is_completed(String(levels[i].get("id", ""))):
			next_unfinished = i
			break
	_map.points = pts
	_map.accent = accent
	_map.done.clear()
	for i in range(levels.size()):
		var lvl: Dictionary = levels[i]
		var lvl_id := String(lvl.get("id", ""))
		var unlocked := SaveManager.is_level_unlocked(world_id, i)
		_map.done.append(SaveManager.is_completed(lvl_id))

		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		for k in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			btn.add_theme_stylebox_override(k, StyleBoxEmpty.new())
		btn.size = Vector2(200, 180)
		btn.position = pts[i] - Vector2(100, 0)
		btn.disabled = not unlocked
		_map.add_child(btn)
		var node := LevelNode.new()
		node.set_anchors_preset(Control.PRESET_FULL_RECT)
		node.number = LevelRegistry.get_display_number(world_id, i)
		node.title = String(lvl.get("title", ""))
		node.stars = SaveManager.get_stars(lvl_id)
		node.unlocked = unlocked
		node.completed = SaveManager.is_completed(lvl_id)
		node.current = i == next_unfinished
		node.accent = accent
		node.finale = i == levels.size() - 1
		btn.add_child(node)
		btn.button_down.connect(func(): node.queue_redraw())
		btn.button_up.connect(func(): node.queue_redraw())
		var idx := i
		btn.pressed.connect(func():
			AudioManager.play_sfx("ui_tap")
			SaveManager.haptic(10)
			level_selected.emit(world_id, idx, btn.get_global_rect().position + Vector2(100, 62))
		)
		if not unlocked:
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.queue_redraw()

	_locked_card.visible = not world_open
	if not world_open:
		var wi := LevelRegistry.get_world_index(world_id)
		var prev := String(LevelRegistry.get_worlds()[wi - 1].get("name", "")) if wi > 0 else ""
		_locked_label.text = "Water the final seedling in %s to open the %s!" % [prev, String(world.get("name", ""))]
