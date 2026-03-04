## VoxelManager.gd

# ---------------------------------------------------------------------------
# Virtual Block API (Schema v2)
# ---------------------------------------------------------------------------
## Emitted when a virtual block is created.
signal virtual_block_created(virtual_block_id: int, positions: Array)

## Emitted when a virtual block is modified.
signal virtual_block_refined(virtual_block_id: int, operations: Array)

## Emitted when a virtual block is deleted.
signal virtual_block_deleted(virtual_block_id: int)

## Counter for generating unique virtual block IDs.
var _next_virtual_block_id: int = 1

## Map of virtual_block_id -> Array of Vector3i positions.
var _virtual_blocks: Dictionary = {}

## Creates a virtual block from an array of voxel positions.
## Returns the new virtual_block_id.
func create_virtual_block(positions: Array[Vector3i], material_id: int, layer_id: int) -> int:
	var vb_id: int = _next_virtual_block_id
	_next_virtual_block_id += 1
	
	# Create all voxels
	for pos: Vector3i in positions:
		create_voxel(pos, material_id, layer_id)
		# Register in structure_tags via Database
		Database.insert_structure_tag(_current_project_id, pos, vb_id, 0)
	
	# Store virtual block mapping
	_virtual_blocks[vb_id] = positions.duplicate()
	
	emit_signal("virtual_block_created", vb_id, positions)
	TelemetryService.record_event("virtual_block_created", {"vb_id": vb_id, "count": positions.size()})
	
	return vb_id

## Refines a virtual block by applying a list of operations.
## Each operation is a dict: {"op": "add"|"delete", "position": Vector3i}
func refine_virtual_block(virtual_block_id: int, operations: Array[Dictionary]) -> void:
	if not _virtual_blocks.has(virtual_block_id):
		push_error("refine_virtual_block: virtual_block_id %d not found" % virtual_block_id)
		return
	
	var positions: Array = _virtual_blocks[virtual_block_id]
	
	for op: Dictionary in operations:
		var operation: String = op.get("op", "")
		var pos: Vector3i = op.get("position", Vector3i.ZERO)
		
		if operation == "add":
			if not positions.has(pos):
				positions.append(pos)
				# Get material/layer from existing context or defaults
				var existing = get_voxel(pos)
				var mat_id = existing.get("material_id", 1)
				var layer = existing.get("layer_id", 1)
				create_voxel(pos, mat_id, layer)
				Database.insert_structure_tag(_current_project_id, pos, virtual_block_id, 0)
		
		elif operation == "delete":
			if positions.has(pos):
				positions.erase(pos)
			delete_voxel(pos)
			Database.delete_structure_tag_by_position(_current_project_id, pos)
	
	_virtual_blocks[virtual_block_id] = positions
	
	emit_signal("virtual_block_refined", virtual_block_id, operations)
	TelemetryService.record_event("virtual_block_refined", {"vb_id": virtual_block_id, "ops": operations.size()})

## Deletes a virtual block and all its voxels.
func delete_virtual_block(virtual_block_id: int) -> void:
	if not _virtual_blocks.has(virtual_block_id):
		push_error("delete_virtual_block: virtual_block_id %d not found" % virtual_block_id)
		return
	
	var positions: Array = _virtual_blocks[virtual_block_id]
	
	# Delete all voxels
	for pos: Vector3i in positions:
		delete_voxel(pos)
		Database.delete_structure_tag_by_position(_current_project_id, pos)
	
	_virtual_blocks.erase(virtual_block_id)
	
	emit_signal("virtual_block_deleted", virtual_block_id)
	TelemetryService.record_event("virtual_block_deleted", {"vb_id": virtual_block_id})

## Returns the list of positions for a virtual block, or empty array if not found.
func get_virtual_block_positions(virtual_block_id: int) -> Array[Vector3i]:
	return _virtual_blocks.get(virtual_block_id, [])

## Returns the virtual_block_id for a voxel position, or -1 if not in any virtual block.
func get_virtual_block_for_voxel(position: Vector3i) -> int:
	return Database.get_virtual_block_for_voxel(_current_project_id, position)

## Called when a single voxel is deleted (e.g., by user) to sync structure_tags.
func _on_voxel_deleted_external(position: Vector3i) -> void:
	var vb_id: int = get_virtual_block_for_voxel(position)
	if vb_id >= 0 and _virtual_blocks.has(vb_id):
		var positions: Array = _virtual_blocks[vb_id]
		if positions.has(position):
			positions.erase(position)
			if positions.is_empty():
				_virtual_blocks.erase(vb_id)
	Database.delete_structure_tag_by_position(_current_project_id, position)
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
