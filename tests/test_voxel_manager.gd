# tests/test_voxel_manager.gd
# Unit tests for VoxelManager using GUT framework
extends GutTest

var vm: VoxelManager

func before_each() -> void:
  vm = VoxelManager.new()
  add_child(vm)

func after_each() -> void:
  vm.queue_free()

# ---------------------------------------------------------------------------
# create_voxel / has_voxel
# ---------------------------------------------------------------------------

func test_create_voxel_returns_true_on_success() -> void:
  var result: bool = vm.create_voxel(Vector3i(0, 0, 0), 1, 1)
  assert_true(result, "create_voxel should return true for a new position")

func test_has_voxel_after_create() -> void:
  vm.create_voxel(Vector3i(1, 2, 3), 1, 1)
  assert_true(vm.has_voxel(Vector3i(1, 2, 3)), "has_voxel should be true after creation")

func test_has_voxel_returns_false_for_empty() -> void:
  assert_false(vm.has_voxel(Vector3i(99, 99, 99)), "has_voxel should be false for uninitialised position")

func test_create_voxel_duplicate_returns_false() -> void:
  vm.create_voxel(Vector3i(0, 0, 0), 1, 1)
  var result: bool = vm.create_voxel(Vector3i(0, 0, 0), 2, 1)
  assert_false(result, "Duplicate create_voxel should return false")

# ---------------------------------------------------------------------------
# delete_voxel
# ---------------------------------------------------------------------------

func test_delete_voxel_returns_true() -> void:
  vm.create_voxel(Vector3i(5, 5, 5), 1, 1)
  assert_true(vm.delete_voxel(Vector3i(5, 5, 5)), "delete should return true when voxel exists")

func test_delete_voxel_removes_entry() -> void:
  vm.create_voxel(Vector3i(5, 5, 5), 1, 1)
  vm.delete_voxel(Vector3i(5, 5, 5))
  assert_false(vm.has_voxel(Vector3i(5, 5, 5)), "has_voxel should be false after deletion")

func test_delete_nonexistent_returns_false() -> void:
  assert_false(vm.delete_voxel(Vector3i(9, 9, 9)), "delete of nonexistent should return false")

# ---------------------------------------------------------------------------
# get_chunk
# ---------------------------------------------------------------------------

func test_get_chunk_returns_dict() -> void:
  vm.create_voxel(Vector3i(0, 0, 0), 1, 1)
  var chunk = vm.get_chunk(Vector3i(0, 0, 0))
  assert_not_null(chunk, "get_chunk should not return null")

func test_get_chunk_contains_voxel() -> void:
  vm.create_voxel(Vector3i(2, 3, 4), 2, 1)
  var chunk = vm.get_chunk(Vector3i(2, 3, 4))
  assert_true(chunk.has(Vector3i(2, 3, 4)), "chunk dict should contain the created voxel position")

# ---------------------------------------------------------------------------
# generate_mesh_for_chunk (smoke test - stub)
# ---------------------------------------------------------------------------

func test_generate_mesh_returns_non_null() -> void:
  vm.create_voxel(Vector3i(0, 0, 0), 1, 1)
  var mesh = vm.generate_mesh_for_chunk(Vector3i(0, 0, 0))
  assert_not_null(mesh, "generate_mesh_for_chunk must not return null")
