## StructuralAnalyzer.gd
## PUBLIC INTERFACE - DO NOT MODIFY SIGNATURES (AI-0 owned)
##
## Singleton: StructuralAnalyzer
## Encapsulates structural analysis: floating voxel detection and load-case execution.
## The LoadEngine AI will implement the actual algorithms by calling these stubs.

class_name StructuralAnalyzer
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when floating check completes. result: true = floating detected.
signal floating_check_completed(position: Vector3i, is_floating: bool)

## Emitted when a full load case analysis completes.
signal load_case_completed(case_id: int, results: Dictionary)

## Emitted when a structural warning is detected.
signal structural_warning(message: String, positions: Array)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const MAX_FLOOD_DEPTH: int = 512

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _analysis_queue: Array = []
var _is_running: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	pass

# ---------------------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------------------

## Asynchronously checks if the voxel at position is floating (not connected to ground).
## Result is emitted via floating_check_completed signal.
func check_floating_async(position: Vector3i) -> void:
	## TODO (LoadEngine AI): implement flood-fill connectivity check
	## For now, emit a stub result immediately.
	call_deferred("_stub_floating_result", position)

## Runs a full structural load case analysis.
## Results are stored in the DB and emitted via load_case_completed signal.
func run_full_load_case(case_id: int) -> void:
	## TODO (LoadEngine AI): implement FEA / static analysis
	## For now, emit a stub result.
	call_deferred("_stub_load_case_result", case_id)

## Returns a list of all currently floating voxel positions (synchronous, cached).
func get_floating_voxels() -> Array:
	## TODO (LoadEngine AI): implement cached floating detection
	return []

## Returns the structural score (0.0 - 1.0) for the current project.
## 1.0 = fully stable, 0.0 = critically unstable.
func get_structural_score() -> float:
	## TODO (LoadEngine AI): compute from materials and connectivity
	return 1.0

## Returns true if any structural issues exist in the current project.
func has_structural_issues() -> bool:
	return get_floating_voxels().size() > 0

# ---------------------------------------------------------------------------
# Private stubs (replaced by LoadEngine AI)
# ---------------------------------------------------------------------------

func _stub_floating_result(position: Vector3i) -> void:
	emit_signal("floating_check_completed", position, false)

func _stub_load_case_result(case_id: int) -> void:
	emit_signal("load_case_completed", case_id, {"status": "stub", "score": 1.0})
