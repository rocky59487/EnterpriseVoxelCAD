# tests/test_virtual_block.gd
# Unit tests for Virtual Block API using GUT framework
extends GutTest

var vm: VoxelManager

func before_each() -> void:
	vm = VoxelManager.new()
	add_child(vm)
	vm.set_project(1)  # Set a test project ID

func after_each() -> void:
	vm.queue_free()

# ---------------------------------------------------------------------------
# create_virtual_block
# ---------------------------------------------------------------------------

func test_create_virtual_block_returns_positive_id() -> void:
	var positions: Array[Vector3i] = [
		Vector3i(0, 0, 0),
		Vector3i(1, 0, 0),
		Vector3i(2, 0, 0)
	]
	var vb_id: int = vm.create_virtual_block(positions, 1, 1)
	assert_gt(vb_id, 0, "create_virtual_block should return a positive ID")

func test_create_virtual_block_creates_all_voxels() -> void:
	var positions: Array[Vector3i] = [
		Vector3i(5, 5, 5),
		Vector3i(6, 5, 5),
		Vector3i(7, 5, 5)
	]
	var vb_id: int = vm.create_virtual_block(positions, 2, 1)
	
	for pos: Vector3i in positions:
		assert_true(vm.has_voxel(pos), "Voxel at %s should exist after create_virtual_block" % str(pos))

func test_create_virtual_block_emits_signal() -> void:
	var positions: Array[Vector3i] = [Vector3i(0, 0, 0)]
	var signal_emitted: bool = false
	
	func _on_vb_created(vb_id: int, positions: Array): signal_emitted = true
	vm.virtual_block_created.connect(_on_vb_created)
	
	vm.create_virtual_block(positions, 1, 1)
	assert_true(signal_emitted, "virtual_block_created signal should be emitted")

# ---------------------------------------------------------------------------
# get_virtual_block_positions
# ---------------------------------------------------------------------------

func test_get_virtual_block_positions_returns_correct_array() -> void:
	var positions: Array[Vector3i] = [
		Vector3i(10, 10, 10),
		Vector3i(11, 10, 10)
	]
	var vb_id: int = vm.create_virtual_block(positions, 1, 1)
	
	var retrieved: Array[Vector3i] = vm.get_virtual_block_positions(vb_id)
	assert_eq(retrieved.size(), positions.size(), "Should return same number of positions")
	
	for pos: Vector3i in positions:
		assert_true(retrieved.has(pos), "Retrieved positions should contain all original positions")

func test_get_virtual_block_positions_for_nonexistent_returns_empty() -> void:
	var retrieved: Array[Vector3i] = vm.get_virtual_block_positions(9999)
	assert_eq(retrieved.size(), 0, "Non-existent virtual block should return empty array")

# ---------------------------------------------------------------------------
# refine_virtual_block
# ---------------------------------------------------------------------------

func test_refine_virtual_block_add_operation() -> void:
	var positions: Array[Vector3i] = [Vector3i(0, 0, 0)]
	var vb_id: int = vm.create_virtual_block(positions, 1, 1)
	
	var operations: Array[Dictionary] = [
		{"op": "add", "position": Vector3i(1, 0, 0)}
	]
	vm.refine_virtual_block(vb_id, operations)
	
	assert_true(vm.has_voxel(Vector3i(1, 0, 0)), "Add operation should create voxel")
	var retrieved: Array[Vector3i] = vm.get_virtual_block_positions(vb_id)
	assert_true(retrieved.has(Vector3i(1, 0, 0)), "Add operation should update virtual block positions")

func test_refine_virtual_block_delete_operation() -> void:
	var positions: Array[Vector3i] = [
		Vector3i(0, 0, 0),
		Vector3i(1, 0, 0)
	]
	var vb_id: int = vm.create_virtual_block(positions, 1, 1)
	
	var operations: Array[Dictionary] = [
		{"op": "delete", "position": Vector3i(0, 0, 0)}
	]
	vm.refine_virtual_block(vb_id, operations)
	
	assert_false(vm.has_voxel(Vector3i(0, 0, 0)), "Delete operation should remove voxel")
	var retrieved: Array[Vector3i] = vm.get_virtual_block_positions(vb_id)
	assert_false(retrieved.has(Vector3i(0, 0, 0)), "Delete operation should update virtual block positions")

func test_refine_virtual_block_emits_signal() -> void:
	var positions: Array[Vector3i] = [Vector3i(0, 0, 0)]
	var vb_id: int = vm.create_virtual_block(positions, 1, 1)
	var signal_emitted: bool = false
	
	func _on_vb_refined(vb_id: int, ops: Array): signal_emitted = true
	vm.virtual_block_refined.connect(_on_vb_refined)
	
	var operations: Array[Dictionary] = [{"op": "add", "position": Vector3i(1, 0, 0)}]
	vm.refine_virtual_block(vb_id, operations)
	
	assert_true(signal_emitted, "virtual_block_refined signal should be emitted")

# ---------------------------------------------------------------------------
# delete_virtual_block
# ---------------------------------------------------------------------------

func test_delete_virtual_block_removes_all_voxels() -> void:
	var positions: Array[Vector3i] = [
		Vector3i(3, 3, 3),
		Vector3i(4, 3, 3),
		Vector3i(5, 3, 3)
	]
	var vb_id: int = vm.create_virtual_block(positions, 1, 1)
	
	vm.delete_virtual_block(vb_id)
	
	for pos: Vector3i in positions:
		assert_false(vm.has_voxel(pos), "Delete should remove all voxels")

func test_delete_virtual_block_emits_signal() -> void:
	var positions: Array[Vector3i] = [Vector3i(0, 0, 0)]
	var vb_id: int = vm.create_virtual_block(positions, 1, 1)
	var signal_emitted: bool = false
	
	func _on_vb_deleted(vb_id: int): signal_emitted = true
	vm.virtual_block_deleted.connect(_on_vb_deleted)
	
	vm.delete_virtual_block(vb_id)
	
	assert_true(signal_emitted, "virtual_block_deleted signal should be emitted")

func test_delete_virtual_block_removes_mapping() -> void:
	var positions: Array[Vector3i] = [Vector3i(0, 0, 0)]
	var vb_id: int = vm.create_virtual_block(positions, 1, 1)
	
	vm.delete_virtual_block(vb_id)
	
	var retrieved: Array[Vector3i] = vm.get_virtual_block_positions(vb_id)
	assert_eq(retrieved.size(), 0, "Deleted virtual block should have no positions")
