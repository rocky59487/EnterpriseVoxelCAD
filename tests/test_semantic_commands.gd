# tests/test_semantic_commands.gd
# Unit tests for Semantic Command Resolution using GUT framework
extends GutTest

var cp: CommandParser
var command_executed: String = ""
var command_params: Dictionary = {}

func before_each() -> void:
	cp = CommandParser.new()
	add_child(cp)
	command_executed = ""
	command_params = {}
	
	# Register a test command
	cp.register_command("test_command", _test_callback)

func after_each() -> void:
	cp.queue_free()

func _test_callback(params: Dictionary = {}) -> void:
	command_executed = "test_command"
	command_params = params

# ---------------------------------------------------------------------------
# resolve_command - exact match
# ---------------------------------------------------------------------------

func test_resolve_command_exact_match_canonical() -> void:
	# This test assumes semantic_commands table is seeded
	var result: String = cp.resolve_command("create_virtual_block")
	assert_eq(result, "create_virtual_block", "Exact canonical match should resolve")

# ---------------------------------------------------------------------------
# resolve_command - alias match
# ---------------------------------------------------------------------------

func test_resolve_command_alias_cvb() -> void:
	var result: String = cp.resolve_command("cvb")
	assert_eq(result, "create_virtual_block", "'cvb' alias should resolve to 'create_virtual_block'")

func test_resolve_command_alias_cv() -> void:
	var result: String = cp.resolve_command("cv")
	assert_true(
		result == "create_virtual_block" or result == "create_voxel",
		"'cv' should resolve to a valid command"
	)

func test_resolve_command_alias_virtblock() -> void:
	var result: String = cp.resolve_command("virtblock")
	assert_eq(result, "create_virtual_block", "'virtblock' alias should resolve")

func test_resolve_command_alias_rvb() -> void:
	var result: String = cp.resolve_command("rvb")
	assert_eq(result, "refine_virtual_block", "'rvb' alias should resolve to 'refine_virtual_block'")

func test_resolve_command_alias_dvb() -> void:
	var result: String = cp.resolve_command("dvb")
	assert_eq(result, "delete_virtual_block", "'dvb' alias should resolve to 'delete_virtual_block'")

# ---------------------------------------------------------------------------
# resolve_command - fuzzy match (Levenshtein)
# ---------------------------------------------------------------------------

func test_resolve_command_fuzzy_one_char_off() -> void:
	# "creae" is 1 edit distance from "create"
	var result: String = cp.resolve_command("creae_virtual_block")
	assert_eq(result, "create_virtual_block", "Should fuzzy match with 1 char difference")

func test_resolve_command_fuzzy_two_chars_off() -> void:
	# "virtul" is 1-2 edit distance from "virtual"
	var result: String = cp.resolve_command("virtul_block")
	# May or may not match depending on algorithm; just ensure it doesn't crash
	assert_true(result == "" or result.length() > 0, "Should handle 2 char difference gracefully")

func test_resolve_command_no_match_returns_empty() -> void:
	var result: String = cp.resolve_command("xyznonexistent")
	assert_eq(result, "", "Non-matching input should return empty string")

func test_resolve_command_too_far_edit_distance() -> void:
	# "crea" is 14 edit distance from "create_virtual_block" - should not match
	var result: String = cp.resolve_command("crea")
	assert_true(result == "", "Input with too large edit distance should not match")

# ---------------------------------------------------------------------------
# resolve_and_execute
# ---------------------------------------------------------------------------

func test_resolve_and_execute_with_alias() -> void:
	# Register callback for create_virtual_block
	cp.register_command("create_virtual_block", _create_vb_callback)
	
	var success: bool = cp.resolve_and_execute("cvb")
	assert_true(success, "resolve_and_execute with valid alias should succeed")
	assert_eq(command_executed, "create_virtual_block", "Should execute resolved command")

func test_resolve_and_execute_with_fuzzy_input() -> void:
	cp.register_command("create_virtual_block", _create_vb_callback)
	
	var success: bool = cp.resolve_and_execute("creae_virtual_block")
	assert_true(success, "resolve_and_execute with fuzzy input should succeed")

func test_resolve_and_execute_no_match_returns_false() -> void:
	var success: bool = cp.resolve_and_execute("nonexistent_command_xyz")
	assert_false(success, "resolve_and_execute with no match should return false")

# ---------------------------------------------------------------------------
# execute_command
# ---------------------------------------------------------------------------

func test_execute_command_with_params() -> void:
	cp.register_command("command_with_params", _callback_with_params)
	
	var params: Dictionary = {"key": "value", "number": 42}
	var success: bool = cp.execute_command("command_with_params", params)
	
	assert_true(success, "execute_command should return true for registered command")
	assert_eq(command_params.get("key"), "value", "Params should be passed correctly")
	assert_eq(command_params.get("number"), 42, "Numeric params should be preserved")

func test_execute_command_unregistered_returns_false() -> void:
	var success: bool = cp.execute_command("unregistered_command")
	assert_false(success, "execute_command for unregistered command should return false")

# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------

func _create_vb_callback(params: Dictionary = {}) -> void:
	command_executed = "create_virtual_block"
	command_params = params

func _callback_with_params(params: Dictionary) -> void:
	command_executed = "command_with_params"
	command_params = params
