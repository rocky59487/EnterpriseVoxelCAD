## CommandParser.gd
## Semantic command engine with fuzzy resolution.
## Resolves abbreviated, misspelled, or aliased commands to canonical names.
## Used by the agent engine and UI for natural command input.

class_name CommandParser
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal command_executed(canonical_name: String, success: bool)
signal command_resolution_failed(input: String)

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------
var _command_callbacks: Dictionary = {}  # canonical_name -> Callable
var _semantic_cache: Dictionary = {}     # alias -> canonical_name cache

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	_load_semantic_commands_from_db()

# ---------------------------------------------------------------------------
# PUBLIC API - Command Registration
# ---------------------------------------------------------------------------
## Registers a callback for a canonical command name.
func register_command(canonical_name: String, callback: Callable) -> void:
	_command_callbacks[canonical_name] = callback

## Unregisters a command.
func unregister_command(canonical_name: String) -> void:
	_command_callbacks.erase(canonical_name)

# ---------------------------------------------------------------------------
# PUBLIC API - Command Resolution & Execution
# ---------------------------------------------------------------------------
## Resolves fuzzy input to a canonical command name.
## Returns empty string if no match found.
func resolve_command(input: String) -> String:
	input = input.strip_edges().to_lower()
	
	# Check cache first
	if _semantic_cache.has(input):
		return _semantic_cache[input]
	
	# Try exact match on canonical name
	var canonical: String = Database.get_semantic_command_canonical(input)
	if canonical != "":
		_semantic_cache[input] = canonical
		return canonical
	
	# Try alias match
	canonical = Database.get_semantic_command_by_alias(input)
	if canonical != "":
		_semantic_cache[input] = canonical
		return canonical
	
	# Fuzzy match: Levenshtein distance on canonical names
	var candidates: Array = Database.get_all_enabled_semantic_commands()
	var best_match: String = ""
	var best_distance: int = 999
	
	for candidate in candidates:
		var distance: int = _levenshtein_distance(input, candidate)
		if distance < best_distance and distance <= 2:  # Allow up to 2 character difference
			best_distance = distance
			best_match = candidate
	
	if best_match != "":
		_semantic_cache[input] = best_match
		return best_match
	
	return ""

## Executes a command by canonical name with optional parameters.
## Returns true if successful, false if command not found or callback failed.
func execute_command(canonical_name: String, params: Dictionary = {}) -> bool:
	if not _command_callbacks.has(canonical_name):
		push_error("CommandParser: No callback registered for '%s'" % canonical_name)
		return false
	
	var callback: Callable = _command_callbacks[canonical_name]
	var success: bool = false
	
	# Try to call with params, handle both dict and positional args
	if params.is_empty():
		success = true
		if callback.is_valid():
			callback.call()
	else:
		success = true
		if callback.is_valid():
			callback.call(params)
	
	emit_signal("command_executed", canonical_name, success)
	TelemetryService.record_event("command_executed", {"canonical": canonical_name, "success": success})
	
	return success

## Convenience method: resolve and execute in one step.
func resolve_and_execute(input: String, params: Dictionary = {}) -> bool:
	var canonical: String = resolve_command(input)
	if canonical == "":
		emit_signal("command_resolution_failed", input)
		TelemetryService.record_event("command_resolution_failed", {"input": input})
		return false
	
	return execute_command(canonical, params)

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------
func _load_semantic_commands_from_db() -> void:
	# Semantic commands are loaded from database by Database singleton on startup
	pass

## Computes the Levenshtein (edit) distance between two strings.
func _levenshtein_distance(s1: String, s2: String) -> int:
	var m: int = s1.length()
	var n: int = s2.length()
	
	# Create distance matrix
	var dp: Array = []
	for i in range(m + 1):
		var row: Array = []
		for j in range(n + 1):
			row.append(0)
		dp.append(row)
	
	# Initialize base cases
	for i in range(m + 1):
		dp[i][0] = i
	for j in range(n + 1):
		dp[0][j] = j
	
	# Fill matrix
	for i in range(1, m + 1):
		for j in range(1, n + 1):
			if s1[i - 1] == s2[j - 1]:
				dp[i][j] = dp[i - 1][j - 1]
			else:
				dp[i][j] = 1 + mini(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1])
	
	return dp[m][n]
