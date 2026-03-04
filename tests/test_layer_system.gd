# tests/test_layer_system.gd
# Unit tests for LayerSystem using GUT framework
extends GutTest

var ls: LayerSystem

func before_each() -> void:
  ls = LayerSystem.new()
  add_child(ls)

func after_each() -> void:
  ls.queue_free()

# ---------------------------------------------------------------------------
# create_layer
# ---------------------------------------------------------------------------

func test_create_layer_returns_positive_id() -> void:
  var layer_id: int = ls.create_layer(1, "Foundation", Color.RED)
  assert_gt(layer_id, 0, "create_layer should return a positive layer ID")

func test_create_layer_unique_ids() -> void:
  var id1: int = ls.create_layer(1, "Layer A", Color.RED)
  var id2: int = ls.create_layer(1, "Layer B", Color.BLUE)
  assert_ne(id1, id2, "Two layers should have different IDs")

# ---------------------------------------------------------------------------
# set_layer_visibility
# ---------------------------------------------------------------------------

func test_set_layer_visibility_true() -> void:
  var layer_id: int = ls.create_layer(1, "Wall", Color.GREEN)
  ls.set_layer_visibility(layer_id, true)
  # Signal emitted - no crash is a pass
  pass_test("set_layer_visibility(true) should not crash")

func test_set_layer_visibility_false() -> void:
  var layer_id: int = ls.create_layer(1, "Wall", Color.GREEN)
  ls.set_layer_visibility(layer_id, false)
  pass_test("set_layer_visibility(false) should not crash")

# ---------------------------------------------------------------------------
# get_layers_for_project
# ---------------------------------------------------------------------------

func test_get_layers_for_project_returns_array() -> void:
  ls.create_layer(1, "L1", Color.WHITE)
  ls.create_layer(1, "L2", Color.BLACK)
  var layers: Array = ls.get_layers_for_project(1)
  assert_typeof(layers, TYPE_ARRAY, "get_layers_for_project should return an Array")

func test_get_layers_for_project_count() -> void:
  ls.create_layer(2, "Alpha", Color.WHITE)
  ls.create_layer(2, "Beta",  Color.BLACK)
  var layers: Array = ls.get_layers_for_project(2)
  assert_gte(layers.size(), 2, "Should return at least the 2 created layers")

func test_get_layers_for_nonexistent_project_returns_empty() -> void:
  var layers: Array = ls.get_layers_for_project(9999)
  assert_eq(layers.size(), 0, "Non-existent project should return empty array")
