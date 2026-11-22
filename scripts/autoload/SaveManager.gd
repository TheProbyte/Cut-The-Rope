extends Node

const SAVE_PATH := "user://drip_save.json"

signal progress_changed

var _data: Dictionary = {
	"stars": {},
	"completed": {},
	"music_enabled": true,
	"sfx_enabled": true,
	"haptics_enabled": true,
	"seen_worlds": {},
}


func _ready() -> void:
	load_save()


func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		if parsed.has("stars") and typeof(parsed["stars"]) == TYPE_DICTIONARY:
			_data["stars"] = parsed["stars"]
		if parsed.has("completed") and typeof(parsed["completed"]) == TYPE_DICTIONARY:
			_data["completed"] = parsed["completed"]
		if parsed.has("music_enabled"):
			_data["music_enabled"] = bool(parsed["music_enabled"])
		if parsed.has("sfx_enabled"):
			_data["sfx_enabled"] = bool(parsed["sfx_enabled"])
		if parsed.has("haptics_enabled"):
			_data["haptics_enabled"] = bool(parsed["haptics_enabled"])
		if parsed.has("seen_worlds") and typeof(parsed["seen_worlds"]) == TYPE_DICTIONARY:
			_data["seen_worlds"] = parsed["seen_worlds"]


func save_data() -> void:
	# Write to a temp file first so a crash mid-write can't corrupt progress.
	var tmp_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_data, "\t"))
	file.close()
	DirAccess.rename_absolute(tmp_path, SAVE_PATH)


func record_completion(level_id: String, stars_earned: int) -> void:
	var clamped: int = clampi(stars_earned, 0, 3)
	var prev: int = get_stars(level_id)
	_data["completed"][level_id] = true
	if clamped > prev:
		_data["stars"][level_id] = clamped
	elif not _data["stars"].has(level_id):
		_data["stars"][level_id] = clamped
	save_data()
	progress_changed.emit()


func get_stars(level_id: String) -> int:
	return int(_data["stars"].get(level_id, 0))


func is_completed(level_id: String) -> bool:
	return bool(_data["completed"].get(level_id, false))


func is_level_unlocked(world_id: String, index: int) -> bool:
	if index <= 0:
		return is_world_unlocked(world_id)
	var prev_level: Dictionary = LevelRegistry.get_level_meta(world_id, index - 1)
	if prev_level.is_empty():
		return false
	return is_completed(String(prev_level.get("id", "")))


## A world opens once the previous world's final level is complete.
## Worlds the player already has progress in always stay open.
func is_world_unlocked(world_id: String) -> bool:
	var worlds := LevelRegistry.get_worlds()
	for i in range(worlds.size()):
		if String(worlds[i].get("id", "")) != world_id:
			continue
		if i == 0:
			return true
		for lvl in LevelRegistry.get_world_levels(world_id):
			if is_completed(String(lvl.get("id", ""))):
				return true
		var prev_id := String(worlds[i - 1].get("id", ""))
		var prev_levels := LevelRegistry.get_world_levels(prev_id)
		if prev_levels.is_empty():
			return true
		return is_completed(String(prev_levels[prev_levels.size() - 1].get("id", "")))
	return false


func is_world_complete(world_id: String) -> bool:
	for lvl in LevelRegistry.get_world_levels(world_id):
		if not is_completed(String(lvl.get("id", ""))):
			return false
	return true


## Returns {"world": id, "index": i} for the first unfinished unlocked level, or {} if all done.
func get_next_unfinished() -> Dictionary:
	for w in LevelRegistry.get_worlds():
		var wid := String(w.get("id", ""))
		if not is_world_unlocked(wid):
			continue
		var levels := LevelRegistry.get_world_levels(wid)
		for i in range(levels.size()):
			if not is_completed(String(levels[i].get("id", ""))):
				return {"world": wid, "index": i}
	return {}


func has_seen_world(world_id: String) -> bool:
	return bool(_data["seen_worlds"].get(world_id, false))


func mark_world_seen(world_id: String) -> void:
	if has_seen_world(world_id):
		return
	_data["seen_worlds"][world_id] = true
	save_data()


func get_world_stars(world_id: String) -> Vector2i:
	var levels: Array = LevelRegistry.get_world_levels(world_id)
	var earned := 0
	for lvl in levels:
		earned += get_stars(String(lvl.get("id", "")))
	return Vector2i(earned, levels.size() * 3)


func get_total_stars() -> Vector2i:
	var earned := 0
	var total := 0
	for w in LevelRegistry.get_worlds():
		var ws := get_world_stars(String(w.get("id", "")))
		earned += ws.x
		total += ws.y
	return Vector2i(earned, total)


func is_music_enabled() -> bool:
	return bool(_data.get("music_enabled", true))


func is_sfx_enabled() -> bool:
	return bool(_data.get("sfx_enabled", true))


func set_music_enabled(enabled: bool) -> void:
	_data["music_enabled"] = enabled
	save_data()


func set_sfx_enabled(enabled: bool) -> void:
	_data["sfx_enabled"] = enabled
	save_data()


func is_haptics_enabled() -> bool:
	return bool(_data.get("haptics_enabled", true))


func toggle_haptics() -> bool:
	_data["haptics_enabled"] = not is_haptics_enabled()
	save_data()
	return is_haptics_enabled()


func haptic(ms: int) -> void:
	if is_haptics_enabled() and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


## Wipes level progress (keeps audio/haptics preferences).
func reset_progress() -> void:
	_data["stars"] = {}
	_data["completed"] = {}
	_data["seen_worlds"] = {}
	save_data()
	progress_changed.emit()
