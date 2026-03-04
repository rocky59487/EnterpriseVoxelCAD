## Database.gd

# ---------------------------------------------------------------------------
# Structure Tags API (Schema v2)
# ---------------------------------------------------------------------------
## Inserts a structure tag for a voxel.
func insert_structure_tag(project_id: int, position: Vector3i, virtual_block_id: int, structure_level: int = 0) -> bool:
	if not _ensure_connected():
		return false
	
	var chunk_result: Variant = _get_chunk_id_for_position(project_id, position)
	if chunk_result == null:
		# Chunk doesn't exist yet, create it first
		save_chunk(project_id, position, PackedByteArray())
		chunk_result = _get_chunk_id_for_position(project_id, position)
	
	if chunk_result == null:
		push_error("Database: Could not get chunk_id for position %s" % str(position))
		return false
	
	var chunk_id: int = chunk_result
	var voxel_index: int = _position_to_voxel_index(position)
	
	var sql: String = """
		INSERT INTO structure_tags (project_id, chunk_id, voxel_index, virtual_block_id, structure_level)
		VALUES (?, ?, ?, ?, ?)
		ON CONFLICT(chunk_id, voxel_index) DO UPDATE SET
			virtual_block_id = excluded.virtual_block_id,
			structure_level = excluded.structure_level
	"""
	
	var params: Array = [project_id, chunk_id, voxel_index, virtual_block_id, structure_level]
	return _execute(sql, params)

## Deletes a structure tag by position.
func delete_structure_tag_by_position(project_id: int, position: Vector3i) -> bool:
	if not _ensure_connected():
		return false
	
	var chunk_result: Variant = _get_chunk_id_for_position(project_id, position)
	if chunk_result == null:
		return true  # Nothing to delete
	
	var chunk_id: int = chunk_result
	var voxel_index: int = _position_to_voxel_index(position)
	
	var sql: String = "DELETE FROM structure_tags WHERE chunk_id = ? AND voxel_index = ?"
	return _execute(sql, [chunk_id, voxel_index])

## Returns the virtual_block_id for a voxel position, or -1 if not found.
func get_virtual_block_for_voxel(project_id: int, position: Vector3i) -> int:
	if not _ensure_connected():
		return -1
	
	var chunk_result: Variant = _get_chunk_id_for_position(project_id, position)
	if chunk_result == null:
		return -1
	
	var chunk_id: int = chunk_result
	var voxel_index: int = _position_to_voxel_index(position)
	
	var sql: String = "SELECT virtual_block_id FROM structure_tags WHERE chunk_id = ? AND voxel_index = ?"
	var result: Variant = _query_single(sql, [chunk_id, voxel_id])
	
	if result == null or result.is_empty():
		return -1
	
	return result.get("virtual_block_id", -1)

# ---------------------------------------------------------------------------
# Semantic Commands API (Schema v2)
# ---------------------------------------------------------------------------
## Returns the canonical name for a command by exact match on canonical_name.
func get_semantic_command_canonical(input: String) -> String:
	if not _ensure_connected():
		return ""
	
	var sql: String = "SELECT canonical_name FROM semantic_commands WHERE canonical_name = ? AND enabled = 1"
	var result: Variant = _query_single(sql, [input])
	
	if result == null or result.is_empty():
		return ""
	
	return result.get("canonical_name", "")

## Returns the canonical name by matching an alias.
func get_semantic_command_by_alias(input: String) -> String:
	if not _ensure_connected():
		return ""
	
	# Search for alias in comma-separated list
	var sql: String = """
		SELECT canonical_name FROM semantic_commands
		WHERE enabled = 1
		  AND (',' || aliases || ',' LIKE ? OR ',' || aliases || ',' LIKE ?)
	"""
	var result: Variant = _query_single(sql, ["%," + input + ",%", input + ",%"])
	
	if result == null or result.is_empty():
		return ""
	
	return result.get("canonical_name", "")

## Returns all enabled canonical command names.
func get_all_enabled_semantic_commands() -> Array:
	if not _ensure_connected():
		return []
	
	var sql: String = "SELECT canonical_name FROM semantic_commands WHERE enabled = 1"
	var results: Array = _query(sql, [])
	
	var names: Array = []
	for row in results:
		names.append(row.get("canonical_name", ""))
	
	return names

# ---------------------------------------------------------------------------
# Private helpers for structure tags
# ---------------------------------------------------------------------------
func _get_chunk_id_for_position(project_id: int, position: Vector3i) -> Variant:
	var chunk_coord: Vector3i = Vector3i(
		floor(float(position.x) / 32),
		floor(float(position.y) / 32),
		floor(float(position.z) / 32)
	)
	
	var sql: String = "SELECT id FROM voxel_chunks WHERE project_id = ? AND chunk_x = ? AND chunk_y = ? AND chunk_z = ?"
	var result: Variant = _query_single(sql, [project_id, chunk_coord.x, chunk_coord.y, chunk_coord.z])
	
	if result == null or result.is_empty():
		return null
	
	return result.get("id", null)

func _position_to_voxel_index(position: Vector3i) -> int:
	# Convert world position to local chunk index (0..31 for each axis)
	var lx: int = posmod(position.x, 32)
	var ly: int = posmod(position.y, 32)
	var lz: int = posmod(position.z, 32)
	# Linear index: x + y*32 + z*32*32
	return lx + ly * 32 + lz * 1024
## PUBLIC INTERFACE - DO NOT MODIFY SIGNATURES (AI-0 owned)
##
## Singleton: Database
## Provides the unified SQLite access facade for the entire application.
## All other modules MUST use this class to interact with persistent data.
## Direct SQL execution from other modules is STRICTLY FORBIDDEN.

class_name DatabaseService
extends Node

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const SCHEMA_VERSION: int = 1
const ENV_PATH: String = "user://.env"

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _db: Object = null  ## SQLite connection object (godot-sqlite plugin)
var _db_path: String = ""
var _is_connected: bool = false
var _encrypt: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_load_env()
	_connect_database()

## Loads configuration from .env file.
## Keys: DB_PATH, DB_ENCRYPT
func _load_env() -> void:
	if not FileAccess.file_exists(ENV_PATH):
		push_warning("Database: .env file not found at %s. Using defaults." % ENV_PATH)
		_db_path = "user://enterprise_voxel_cad.db"
		return
	var f: FileAccess = FileAccess.open(ENV_PATH, FileAccess.READ)
	while not f.eof_reached():
		var line: String = f.get_line().strip_edges()
		if line.begins_with("#") or line.is_empty():
			continue
		var parts: PackedStringArray = line.split("=", false, 1)
		if parts.size() == 2:
			match parts[0].strip_edges():
				"DB_PATH":
					_db_path = parts[1].strip_edges()
				"DB_ENCRYPT":
					_encrypt = parts[1].strip_edges().to_lower() == "true"
				_:
					pass
	f.close()

## Opens or creates the SQLite database.
## Enables WAL mode automatically.
## SQLCipher encryption hook: set _encrypt = true to activate (future).
func _connect_database() -> void:
	if _db_path.is_empty():
		_db_path = "user://enterprise_voxel_cad.db"
	# godot-sqlite plugin integration point:
	# _db = SQLite.new()
	# _db.path = _db_path
	# if _encrypt:
	#     _db.set_encryption_key(OS.get_environment("DB_KEY"))
	# _db.open_db()
	# _db.query("PRAGMA journal_mode=WAL;")
	# _is_connected = true
	push_warning("Database: godot-sqlite plugin not loaded. Operating in stub mode.")
	_is_connected = false

# ---------------------------------------------------------------------------
# PUBLIC API - Projects
# ---------------------------------------------------------------------------

## Returns project data as a Dictionary, or empty dict if not found.
func get_project(id: int) -> Dictionary:
	if not _is_connected:
		return {}
	# Stub: return _db.select_rows("projects", "id = %d" % id, ["*"])[0]
	return {}

## Saves a project record. Creates if id == -1, updates otherwise.
func save_project(data: Dictionary) -> int:
	if not _is_connected:
		return -1
	# Stub
	return -1

## Lists all projects. Returns Array of Dictionaries.
func list_projects() -> Array:
	if not _is_connected:
		return []
	return []

# ---------------------------------------------------------------------------
# PUBLIC API - Chunks
# ---------------------------------------------------------------------------

## Saves or updates a chunk. chunk_id is Vector3i, data is PackedByteArray.
func save_chunk(project_id: int, chunk_pos: Vector3i, data: PackedByteArray) -> bool:
	if not _is_connected:
		return false
	# Stub
	return false

## Loads a chunk by position. Returns PackedByteArray or empty if not found.
func load_chunk(project_id: int, chunk_pos: Vector3i) -> PackedByteArray:
	if not _is_connected:
		return PackedByteArray()
	return PackedByteArray()

## Returns all chunk positions for a given project.
func get_chunks_for_project(project_id: int) -> Array:
	if not _is_connected:
		return []
	return []

# ---------------------------------------------------------------------------
# PUBLIC API - Layers
# ---------------------------------------------------------------------------

## Returns all layers for a project as Array of Dictionaries.
func list_layers(project_id: int) -> Array:
	if not _is_connected:
		return []
	return []

## Creates a new layer. Returns the new layer id.
func create_layer(project_id: int, name: String, mask: int) -> int:
	if not _is_connected:
		return -1
	return -1

## Updates layer visibility flag.
func set_layer_visibility(layer_id: int, visible: bool) -> bool:
	if not _is_connected:
		return false
	return false

# ---------------------------------------------------------------------------
# PUBLIC API - Materials
# ---------------------------------------------------------------------------

## Returns all materials.
func list_materials() -> Array:
	if not _is_connected:
		return []
	return []

## Returns a single material by id.
func get_material(id: int) -> Dictionary:
	if not _is_connected:
		return {}
	return {}

# ---------------------------------------------------------------------------
# PUBLIC API - Undo Stack
# ---------------------------------------------------------------------------

## Pushes an operation onto the undo stack.
func push_undo_operation(project_id: int, operation: Dictionary) -> bool:
	if not _is_connected:
		return false
	return false

## Returns the top N undoable operations.
func get_undo_operations(project_id: int, limit: int = 50) -> Array:
	if not _is_connected:
		return []
	return []

# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

## Returns true if the database connection is active.
func is_connected_db() -> bool:
	return _is_connected

## Runs a raw query. RESTRICTED - only for internal migration use.
func _run_migration(sql: String) -> bool:
	if not _is_connected:
		return false
	# Stub
	return false
