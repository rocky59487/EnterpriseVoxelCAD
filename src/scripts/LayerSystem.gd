## LayerSystem.gd
## PUBLIC INTERFACE - DO NOT MODIFY SIGNATURES (AI-0 owned)
##
## Singleton: LayerSystem
## Manages editor layers for voxel organization, visibility, and locking.

class_name LayerSystem
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal layer_created(layer_id: int, name: String)
signal layer_visibility_changed(layer_id: int, visible: bool)
signal layer_locked_changed(layer_id: int, locked: bool)

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _current_project_id: int = -1
## In-memory layer cache: layer_id -> {name, mask, visible, locked, source_type}
var _layers: Dictionary = {}
var _next_id: int = 1

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	pass

func set_project(project_id: int) -> void:
	_current_project_id = project_id
	_layers.clear()
	_next_id = 1
	_load_layers_from_db()

# ---------------------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------------------

## Creates a new layer. Returns the new layer id.
func create_layer(name: String, mask: int) -> int:
	var layer_id: int = Database.create_layer(_current_project_id, name, mask)
	if layer_id < 0:
		layer_id = _next_id
		_next_id += 1
	_layers[layer_id] = {
		"name": name,
		"mask": mask,
		"visible": true,
		"locked": false,
		"source_type": "human"
	}
	emit_signal("layer_created", layer_id, name)
	return layer_id

## Sets visibility of a layer by id.
func set_layer_visibility(id: int, visible: bool) -> void:
	if not _layers.has(id):
		push_error("LayerSystem: layer id %d not found" % id)
		return
	_layers[id]["visible"] = visible
	Database.set_layer_visibility(id, visible)
	emit_signal("layer_visibility_changed", id, visible)

## Sets locked state of a layer by id.
func set_layer_locked(id: int, locked: bool) -> void:
	if not _layers.has(id):
		push_error("LayerSystem: layer id %d not found" % id)
		return
	_layers[id]["locked"] = locked
	emit_signal("layer_locked_changed", id, locked)

## Returns all layers for the current project as an Array of Dictionaries.
## Each dict has keys: id, name, mask, visible, locked, source_type.
func get_layers_for_project(project_id: int) -> Array:
	if project_id != _current_project_id:
		return Database.list_layers(project_id)
	var result: Array = []
	for id: int in _layers.keys():
		var layer: Dictionary = _layers[id].duplicate()
		layer["id"] = id
		result.append(layer)
	return result

## Returns a single layer dict by id, or empty dict if not found.
func get_layer(id: int) -> Dictionary:
	if not _layers.has(id):
		return {}
	var layer: Dictionary = _layers[id].duplicate()
	layer["id"] = id
	return layer

## Returns true if the layer is visible.
func is_layer_visible(id: int) -> bool:
	return _layers.get(id, {}).get("visible", true)

## Returns true if the layer is locked.
func is_layer_locked(id: int) -> bool:
	return _layers.get(id, {}).get("locked", false)

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _load_layers_from_db() -> void:
	var db_layers: Array = Database.list_layers(_current_project_id)
	for layer: Dictionary in db_layers:
		var id: int = layer.get("id", _next_id)
		_layers[id] = layer
		if id >= _next_id:
			_next_id = id + 1
