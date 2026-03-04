## TelemetryService.gd
## Singleton for recording telemetry events (analytics, debugging, audit trail).
## Used by VoxelManager, CommandParser, and other subsystems.

class_name TelemetryService
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal event_recorded(event_name: String, data: Dictionary)

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------
var _event_log: Array[Dictionary] = []
const MAX_LOG_SIZE: int = 10000

# ---------------------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------------------
## Records an event with optional metadata.
func record_event(event_name: String, data: Dictionary = {}) -> void:
	var event: Dictionary = {
		"timestamp": Time.get_unix_time_from_system(),
		"event_name": event_name,
		"data": data
	}
	
	_event_log.append(event)
	
	# Trim log if too large
	if _event_log.size() > MAX_LOG_SIZE:
		_event_log.pop_front()
	
	emit_signal("event_recorded", event_name, data)

## Returns the last N events from the log.
func get_recent_events(count: int = 100) -> Array[Dictionary]:
	var start: int = max(0, _event_log.size() - count)
	return _event_log.slice(start)

## Clears the event log.
func clear_log() -> void:
	_event_log.clear()

## Exports the event log to a JSON string.
func export_to_json() -> String:
	return JSON.stringify(_event_log, "\t")

## Returns statistics about recorded events.
func get_statistics() -> Dictionary:
	var stats: Dictionary = {}
	for event in _event_log:
		var name: String = event["event_name"]
		stats[name] = stats.get(name, 0) + 1
	return {
		"total_events": _event_log.size(),
		"by_event_type": stats
	}
