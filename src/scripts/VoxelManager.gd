## VoxelManager.gd
## PUBLIC INTERFACE - DO NOT MODIFY SIGNATURES (AI-0 owned)
##
## Singleton: VoxelManager
## Manages all voxel CRUD operations, chunk allocation, and mesh generation dispatch.
## All voxel mutations must go through this class.

class_name VoxelManager
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when a voxel is created.
signal voxel_created(position: Vector3i, material_id: int, layer_id: int)

## Emitted when a voxel is deleted.
signal voxel_deleted(position: Vector3i)

## Emitted when a chunk mesh has been regenerated.
signal chunk_mesh_updated(chunk_id: Vector3i)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const CHUNK_SIZE: int = 32
const MAX_VOXELS_PER_CHUNK: int = CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _current_project_id: int = -1
## In-memory voxel store: position -> {material_id, layer_id}
var _voxels: Dictionary = {}
var _dirty_chunks: Dictionary = {}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	pass

# ---------------------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------------------

## Sets the active project. Must be called before voxel operations.
func set_project(project_id: int) -> void:
	_current_project_id = project_id
	_voxels.clear()
	_dirty_chunks.clear()

## Creates a voxel at the given position with material and layer.
## Overwrites any existing voxel at that position.
func create_voxel(position: Vector3i, material_id: int, layer_id: int) -> void:
	_voxels[position] = {"material_id": material_id, "layer_id": layer_id}
	_mark_chunk_dirty(position)
	TelemetryService.record_event("voxel_created", {"pos": str(position)})
	emit_signal("voxel_created", position, material_id, layer_id)

## Deletes a voxel at the given position. Does nothing if no voxel exists.
func delete_voxel(position: Vector3i) -> void:
	if not _voxels.has(position):
		return
	_voxels.erase(position)
	_mark_chunk_dirty(position)
	emit_signal("voxel_deleted", position)

## Returns true if a voxel exists at the given position.
func has_voxel(position: Vector3i) -> bool:
	return _voxels.has(position)

## Returns the voxel data dict {material_id, layer_id} or empty dict.
func get_voxel(position: Vector3i) -> Dictionary:
	return _voxels.get(position, {})

## Returns the chunk coordinate that contains the given voxel position.
func get_chunk_coord(position: Vector3i) -> Vector3i:
	return Vector3i(
		floor(float(position.x) / CHUNK_SIZE),
		floor(float(position.y) / CHUNK_SIZE),
		floor(float(position.z) / CHUNK_SIZE)
	)

## Returns a Dictionary of all voxels within a given chunk.
## Key: Vector3i position, Value: voxel data dict.
func get_chunk(chunk_coord: Vector3i) -> Dictionary:
	var result: Dictionary = {}
	var base: Vector3i = chunk_coord * CHUNK_SIZE
	for pos: Vector3i in _voxels.keys():
		if get_chunk_coord(pos) == chunk_coord:
			result[pos] = _voxels[pos]
	return result

## Requests mesh generation for a chunk via the GDExtension VoxelMesher.
## Returns the generated Mesh, or null if extension is not loaded.
func generate_mesh_for_chunk(chunk_coord: Vector3i) -> Mesh:
	var chunk_data: Dictionary = get_chunk(chunk_coord)
	# GDExtension integration point:
	# var mesher = VoxelMesher.new()
	# return mesher.generate_greedy_mesh(chunk_data)
	_dirty_chunks.erase(chunk_coord)
	emit_signal("chunk_mesh_updated", chunk_coord)
	return null

## Returns all dirty chunk coords that need mesh regeneration.
func get_dirty_chunks() -> Array:
	return _dirty_chunks.keys()

## Saves all dirty chunks to the database.
func flush_to_database() -> void:
	for coord: Vector3i in get_dirty_chunks():
		var chunk_data: Dictionary = get_chunk(coord)
		var packed: PackedByteArray = _serialize_chunk(chunk_data)
		Database.save_chunk(_current_project_id, coord, packed)
	_dirty_chunks.clear()

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _mark_chunk_dirty(voxel_pos: Vector3i) -> void:
	var coord: Vector3i = get_chunk_coord(voxel_pos)
	_dirty_chunks[coord] = true

func _serialize_chunk(chunk_data: Dictionary) -> PackedByteArray:
	## Placeholder: serialize chunk to bytes for DB storage.
	## TODO: implement compression (LZ4 / ZSTD)
	return PackedByteArray()
