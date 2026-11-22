extends Node

const WORLDS_MANIFEST := "res://data/levels/worlds.json"

var _worlds: Array = []
var _levels_by_world: Dictionary = {}
var _level_cache: Dictionary = {}


func _ready() -> void:
	_load_manifest()


func _load_manifest() -> void:
	_worlds.clear()
	_levels_by_world.clear()
	_level_cache.clear()
	if not FileAccess.file_exists(WORLDS_MANIFEST):
		push_error("Missing worlds manifest: " + WORLDS_MANIFEST)
		return
	var file := FileAccess.open(WORLDS_MANIFEST, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid worlds manifest JSON")
		return
	var worlds_arr: Variant = parsed.get("worlds", [])
	if typeof(worlds_arr) != TYPE_ARRAY:
		return
	for w in worlds_arr:
		if typeof(w) != TYPE_DICTIONARY:
			continue
		var world_id: String = String(w.get("id", ""))
		_worlds.append(w)
		var level_metas: Array = []
		var paths: Array = w.get("levels", [])
		for idx in range(paths.size()):
			var level_path: String = String(paths[idx])
			var data := load_level_file(level_path)
			if not data.is_empty():
				data["_path"] = level_path
				data["_index"] = idx
				data["_world_id"] = world_id
				level_metas.append(data)
		_levels_by_world[world_id] = level_metas


func load_level_file(path: String) -> Dictionary:
	if _level_cache.has(path):
		return (_level_cache[path] as Dictionary).duplicate(true)
	if not FileAccess.file_exists(path):
		push_error("Level file missing: " + path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON in level: " + path)
		return {}
	_level_cache[path] = parsed
	return (parsed as Dictionary).duplicate(true)


func get_worlds() -> Array:
	return _worlds


func get_world_levels(world_id: String) -> Array:
	return _levels_by_world.get(world_id, [])


func get_level_meta(world_id: String, index: int) -> Dictionary:
	var levels: Array = get_world_levels(world_id)
	if index < 0 or index >= levels.size():
		return {}
	return (levels[index] as Dictionary).duplicate(true)


func get_level_count(world_id: String) -> int:
	return get_world_levels(world_id).size()


func get_world(world_id: String) -> Dictionary:
	for w in _worlds:
		if String(w.get("id", "")) == world_id:
			return w
	return {}


func get_world_index(world_id: String) -> int:
	for i in range(_worlds.size()):
		if String(_worlds[i].get("id", "")) == world_id:
			return i
	return -1


## Global 1-based level number across all worlds (Greenhouse 1-10, Kitchen 11-20, ...).
func get_display_number(world_id: String, index: int) -> int:
	var offset := 0
	for w in _worlds:
		var wid := String(w.get("id", ""))
		if wid == world_id:
			break
		offset += get_level_count(wid)
	return offset + index + 1


## Returns {"world": id, "index": i} for the level after the given one, or {} at the very end.
func get_next_level(world_id: String, index: int) -> Dictionary:
	if index + 1 < get_level_count(world_id):
		return {"world": world_id, "index": index + 1}
	var wi := get_world_index(world_id)
	for j in range(wi + 1, _worlds.size()):
		var wid := String(_worlds[j].get("id", ""))
		if get_level_count(wid) > 0:
			return {"world": wid, "index": 0}
	return {}


func get_total_level_count() -> int:
	var n := 0
	for w in _worlds:
		n += get_level_count(String(w.get("id", "")))
	return n
