extends Node

const SAVE_PATH := "user://drip_save.json"

signal progress_changed

var _data: Dictionary = {
	"stars": {},
	"completed": {},
	"music_enabled": true,
	"sfx_enabled": true,
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


func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_data, "\t"))
	file.close()


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
		return true
	var prev_level: Dictionary = LevelRegistry.get_level_meta(world_id, index - 1)
	if prev_level.is_empty():
		return false
	return is_completed(String(prev_level.get("id", "")))


func get_world_stars(world_id: String) -> Vector2i:
	var levels: Array = LevelRegistry.get_world_levels(world_id)
	var earned := 0
	for lvl in levels:
		earned += get_stars(String(lvl.get("id", "")))
	return Vector2i(earned, levels.size() * 3)


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
