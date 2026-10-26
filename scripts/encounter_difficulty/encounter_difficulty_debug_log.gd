extends RefCounted
class_name EncounterDifficultyDebugLog

### Debug only (EncounterDifficultyService creates it only when OS.is_debug_build()): writes
### encounter_difficulty_log.txt so the difficulty estimate's behaviour can be judged from a play session -
### mainly how often it recalculates and how far the ratings move each time. In the editor the file goes to
### res://debug_output/ (gitignored), in a debug export to user://debug_output/. One section ("#N") per event,
### with the time since the run started. Written line by line and flushed, so the file is complete even if the
### game is stopped or crashes. Overwritten when a run starts.

const LOG_FILE_NAME: String = "encounter_difficulty_log.txt"

var _file: FileAccess
var _started_msec: int = 0
var _event_number: int = 0

func _init() -> void:
	var directory_path: String = "res://debug_output" if OS.has_feature("editor") else "user://debug_output"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory_path))
	_file = FileAccess.open(directory_path + "/" + LOG_FILE_NAME, FileAccess.WRITE)
	if not _file:
		push_warning("EncounterDifficultyDebugLog: could not open %s in %s" % [LOG_FILE_NAME, directory_path])
		return
	_started_msec = Time.get_ticks_msec()
	print("[EncounterDifficultyDebugLog] Writing %s to %s" % [LOG_FILE_NAME, ProjectSettings.globalize_path(directory_path)])
	_write_line("=== Encounter difficulty log. Run started %s ===" % Time.get_datetime_string_from_system())

func get_seconds_since_start() -> float:
	return float(Time.get_ticks_msec() - _started_msec) / 1000.0

func write_event(title: String, lines: Array[String]) -> void:
	if not _file:
		return
	_event_number += 1
	_write_line("")
	_write_line("[%8.2fs] #%d %s" % [get_seconds_since_start(), _event_number, title])
	for line in lines:
		_write_line("    " + line)

func _write_line(line: String) -> void:
	_file.store_line(line)
	_file.flush()
