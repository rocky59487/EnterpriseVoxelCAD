## VoxelProperties.gd
## Extensible voxel properties container to prevent API breakage when adding new properties.
## All voxel operations should use this class instead of individual parameters.
class_name VoxelProperties
extends Resource

# Core properties
var material_id: int = 0
var layer_id: int = 0

# Virtual block properties
var virtual_block_id: int = -1       # -1 = non-virtual block
var structure_level: String = ""     # "main" / "sub" / "deco" / ""

# Voxel engine properties
var edge_type: String = "default"    # "line" / "arc" / "default"
var edge_profile: Dictionary = {}    # { "x+": "arc", "y-": "line" }

# Agent engine properties
var agent_id: int = -1               # -1 = no agent assigned

# Extension slot - any engine can add custom data here
var extra: Dictionary = {}           # Fully open extension slot


func _init(mat: int = 0, layer: int = 0) -> void:
	material_id = mat
	layer_id = layer


## Creates a copy of this VoxelProperties
func duplicate() -> VoxelProperties:
	var copy := VoxelProperties.new()
	copy.material_id = material_id
	copy.layer_id = layer_id
	copy.virtual_block_id = virtual_block_id
	copy.structure_level = structure_level
	copy.edge_type = edge_type
	copy.edge_profile = edge_profile.duplicate()
	copy.agent_id = agent_id
	copy.extra = extra.duplicate()
	return copy


## Serializes to Dictionary for storage/transmission
func serialize() -> Dictionary:
	return {
		"material_id": material_id,
		"layer_id": layer_id,
		"virtual_block_id": virtual_block_id,
		"structure_level": structure_level,
		"edge_type": edge_type,
		"edge_profile": edge_profile,
		"agent_id": agent_id,
		"extra": extra
	}


## Deserializes from Dictionary
func deserialize(data: Dictionary) -> void:
	material_id = data.get("material_id", 0)
	layer_id = data.get("layer_id", 0)
	virtual_block_id = data.get("virtual_block_id", -1)
	structure_level = data.get("structure_level", "")
	edge_type = data.get("edge_type", "default")
	edge_profile = data.get("edge_profile", {})
	agent_id = data.get("agent_id", -1)
	extra = data.get("extra", {})
