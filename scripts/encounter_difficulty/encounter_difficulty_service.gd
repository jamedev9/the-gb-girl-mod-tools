extends RefCounted
class_name EncounterDifficultyService

### The runtime half of the encounter difficulty estimate (the offline half is EncounterDifficultyModel +
### tools/encounter_difficulty, which fill the EncounterDifficultyTable). Owned by MetaGame, which binds the
### save game here whenever one is loaded or created.
###
### Works in both tracks: the weights are one shared resource (EncounterDifficultyWeights.load_shared()), the
### table is the rework's (from the ContentSet) in Full Rework and the prototype's (EncounterDifficultyTable.
### load_prototype()) otherwise. Without a built table is_available() is false and every getter answers
### "unrated" (0). Nothing here touches the game otherwise.
###
### What it does: for the bound save it works out the player's output per turn and pleasure budget
### (EncounterDifficultyModel.get_player_inputs()), looks every encounter up in the table at that output
### and keeps "score (1.0-5.0) and stars (1-5)" per encounter in memory. It recalculates
###   - once when a save is bound (load / new game), and
###   - when the save says the player got stronger (SaveGameState.player_power_changed: a stat reward or an
###     action upgrade), and then only if an input actually changed.
### Never per frame or per query - the getters just read the cached result.
###
### Does nothing at all while EncounterDifficultySettings.ENABLED is false (the getters answer "unrated").
###
### In debug builds every event is written to debug_output/encounter_difficulty_log.txt (see
### EncounterDifficultyDebugLog).

const BIND_REASON: String = "bind"

var _weights: EncounterDifficultyWeights
var _table: EncounterDifficultyTable
var _save_game_state: SaveGameState
var _save_id: String = ""

### encounter_id -> {"score", "stars", "ratio", "expected", "spread", "turns"}. Untyped: nested containers.
var _results: Dictionary = {}
### The player inputs the cached results were calculated from (to skip recalculations that would change nothing).
var _last_inputs: Dictionary = {}

var _log: EncounterDifficultyDebugLog = null
var _bind_count: int = 0
var _recalculation_count: int = 0
var _skipped_count: int = 0
var _star_change_count: int = 0
var _last_calculation_seconds: float = -1.0

func _init() -> void:
	if EncounterDifficultySettings.ENABLED and OS.is_debug_build():
		_log = EncounterDifficultyDebugLog.new()

#region Public queries
func is_available() -> bool:
	return _weights != null and _table != null and _save_game_state != null

func has_difficulty(encounter_id: String) -> bool:
	return _results.has(encounter_id)

### 1.0 (easiest) to 5.0 (hardest) for the bound save's current stats; 0.0 = unrated.
func get_difficulty_score(encounter_id: String) -> float:
	if not _results.has(encounter_id):
		return 0.0
	var result: Dictionary = _results[encounter_id]
	return float(result["score"])

### The score rounded to whole stars, 1 to 5; 0 = unrated.
func get_difficulty_stars(encounter_id: String) -> int:
	if not _results.has(encounter_id):
		return 0
	var result: Dictionary = _results[encounter_id]
	return int(result["stars"])
#endregion

#region Binding and recalculating
### Call whenever MetaGame's save_game_state is replaced (a save was loaded, or a new game was created).
func bind_save_game(save_game_state: SaveGameState, save_id: String) -> void:
	if not EncounterDifficultySettings.ENABLED:
		return
	_disconnect_from_save()
	_save_game_state = save_game_state
	_save_id = save_id
	_results.clear()
	_last_inputs = {}
	if _save_game_state == null:
		return
	_bind_count += 1
	_load_data_if_needed()
	if not _save_game_state.player_power_changed.is_connected(_on_player_power_changed):
		_save_game_state.player_power_changed.connect(_on_player_power_changed)
	_recalculate(BIND_REASON)

func _disconnect_from_save() -> void:
	if _save_game_state == null or not is_instance_valid(_save_game_state):
		return
	if _save_game_state.player_power_changed.is_connected(_on_player_power_changed):
		_save_game_state.player_power_changed.disconnect(_on_player_power_changed)

func _load_data_if_needed() -> void:
	if _weights != null and _table != null:
		return
	if not AutoloadDatabase.is_content_loaded:
		return
	_weights = EncounterDifficultyWeights.load_shared()
	if PlayModeSettings.current == PlayModeSettings.Mode.FULL_REWORK:
		var content_set: ContentSet = AutoloadDatabase.get_active_content_set()
		if content_set != null:
			_table = content_set.encounter_difficulty_table
	else:
		_table = EncounterDifficultyTable.load_prototype()

func _on_player_power_changed(reason: String) -> void:
	_recalculate(reason)

func _recalculate(reason: String) -> void:
	_load_data_if_needed()
	if not is_available():
		_write_unavailable_log(reason)
		return
	var started_usec: int = Time.get_ticks_usec()
	var character_id: String = _save_game_state.selected_character_id
	var inputs: Dictionary = EncounterDifficultyModel.get_player_inputs(_save_game_state, _weights)
	inputs["character_id"] = character_id

	var is_bind: bool = reason == BIND_REASON
	if not is_bind and inputs.hash() == _last_inputs.hash():
		_skipped_count += 1
		_write_skipped_log(reason)
		return

	var previous_inputs: Dictionary = _last_inputs
	var previous_results: Dictionary = _results
	var new_results: Dictionary = {}
	var unrated_ids: Array[String] = []
	for encounter_id: String in AutoloadDatabase.encounter_definitions.keys():
		var sample: Dictionary = _table.sample(character_id, encounter_id, float(inputs["output"]))
		if sample.is_empty():
			unrated_ids.append(encounter_id)
			continue
		var expected: float = float(sample["mean"])
		var spread: float = float(sample["spread"])
		var ratio: float = (expected + _weights.spread_weight * spread) / float(inputs["budget"])
		var score: float = EncounterDifficultyModel.get_rating_score(ratio, _weights)
		new_results[encounter_id] = {
			"score": score,
			"stars": EncounterDifficultyModel.get_stars(score),
			"ratio": ratio,
			"expected": expected,
			"spread": spread,
			"turns": float(sample["turns"]),
		}
	_results = new_results
	_last_inputs = inputs
	if not is_bind:
		_recalculation_count += 1
	var elapsed_usec: int = Time.get_ticks_usec() - started_usec
	_write_recalculation_log(reason, previous_inputs, previous_results, unrated_ids, elapsed_usec)
#endregion

#region Debug log
func _write_unavailable_log(reason: String) -> void:
	if _log == null:
		return
	var why: String = "no save is bound"
	if _save_game_state != null:
		if _weights == null:
			why = "the shared weights resource could not be loaded (%s)" % EncounterDifficultyWeights.SHARED_RESOURCE_PATH
		elif _table == null:
			why = "this mode has no difficulty table resource (Full Rework: the ContentSet's encounter_difficulty_table; otherwise %s)" % EncounterDifficultyTable.PROTOTYPE_RESOURCE_PATH
	var lines: Array[String] = ["estimate unavailable: %s" % why]
	_log.write_event("UNAVAILABLE (%s)" % reason, lines)

func _write_skipped_log(reason: String) -> void:
	if _log == null:
		return
	var lines: Array[String] = [
		"nothing the estimate uses changed (pleasure bar, orgasm bank, energy, used actions' pleasure and upkeep) - ratings kept.",
		"session totals: %s" % _describe_totals(),
	]
	_log.write_event("SKIPPED (%s)" % reason, lines)

func _write_recalculation_log(
		reason: String, previous_inputs: Dictionary, previous_results: Dictionary,
		unrated_ids: Array[String], elapsed_usec: int) -> void:
	if _log == null:
		return
	var is_bind: bool = reason == BIND_REASON
	var inputs: Dictionary = _last_inputs
	var lines: Array[String] = []
	if is_bind:
		lines.append("save: %s | mode: %s | character: %s" % [
			_save_id, PlayModeSettings.Mode.keys()[PlayModeSettings.current], inputs["character_id"]])
		lines.append(_describe_table_state())
		if _table.uses_fallback_for(inputs["character_id"]):
			lines.append("character '%s' has no rows in the table - using the rows of '%s' (the table's fallback)" % [
				inputs["character_id"], _table.fallback_character_id])
	lines.append("player: pleasure bar %d, orgasm bank %d, max energy %d | used actions: %s" % [
		int(inputs["max_pleasure"]), int(inputs["orgasm_bank"]), int(inputs["max_energy"]), inputs["actions"]])
	lines.append("output %.1f pleasure/turn (actions %.1f + spare energy %.1f x %.1f) | budget %.0f pleasure" % [
		float(inputs["output"]), float(inputs["action_pleasure"]), float(inputs["spare_energy"]),
		_weights.spare_energy_pleasure_per_point, float(inputs["budget"])])
	if not is_bind:
		lines.append("changed: %s" % _describe_input_changes(previous_inputs, inputs))

	var star_changes: int = 0
	var largest_score_change: float = 0.0
	var encounter_ids: Array = _results.keys()
	encounter_ids.sort()
	for encounter_id: String in encounter_ids:
		var result: Dictionary = _results[encounter_id]
		var label: String = encounter_id.rpad(34)
		var detail: String = "ratio %.3f  expected %.0f +-%.0f pleasure over %.1f turns" % [
			float(result["ratio"]), float(result["expected"]), float(result["spread"]), float(result["turns"])]
		if is_bind or not previous_results.has(encounter_id):
			lines.append("%s score %.2f  stars %d  %s" % [label, float(result["score"]), int(result["stars"]), detail])
			continue
		var previous: Dictionary = previous_results[encounter_id]
		var score_change: float = float(result["score"]) - float(previous["score"])
		largest_score_change = maxf(largest_score_change, absf(score_change))
		var star_note: String = ""
		if int(result["stars"]) != int(previous["stars"]):
			star_changes += 1
			star_note = "  <-- STARS CHANGED"
		lines.append("%s score %.2f -> %.2f (%+.3f)  stars %d -> %d%s  %s" % [
			label, float(previous["score"]), float(result["score"]), score_change,
			int(previous["stars"]), int(result["stars"]), star_note, detail])
	_star_change_count += star_changes

	if not unrated_ids.is_empty() and is_bind:
		lines.append("unrated (no table row for character '%s'): %s" % [inputs["character_id"], ", ".join(unrated_ids)])
	if is_bind:
		lines.append("summary: %d rated, %d unrated | calculated in %.2f ms" % [
			_results.size(), unrated_ids.size(), float(elapsed_usec) / 1000.0])
	else:
		var since_previous: String = "first calculation since binding"
		if _last_calculation_seconds >= 0.0:
			since_previous = "%.1f s since the previous calculation" % (_log.get_seconds_since_start() - _last_calculation_seconds)
		lines.append("summary: %d rated, %d unrated | %d star change(s), largest score change %.3f | calculated in %.2f ms | %s" % [
			_results.size(), unrated_ids.size(), star_changes, largest_score_change,
			float(elapsed_usec) / 1000.0, since_previous])
	lines.append("session totals: %s" % _describe_totals())
	_last_calculation_seconds = _log.get_seconds_since_start()
	_log.write_event("BIND" if is_bind else "RECALCULATED (%s)" % reason, lines)

func _describe_totals() -> String:
	return "binds %d, recalculations %d, skipped (nothing changed) %d, star changes %d" % [
		_bind_count, _recalculation_count, _skipped_count, _star_change_count]

func _describe_table_state() -> String:
	if _table.is_empty():
		return "TABLE IS EMPTY - run the matching builder in tools/encounter_difficulty (F6) to fill it."
	var settings_note: String = "settings match the weights"
	if not _weights.is_table_settings_snapshot_current(_table.built_with_settings):
		settings_note = "WARNING: built with different 'Table:' settings than the weights have now - re-run the tool"
		push_warning("EncounterDifficultyService: the difficulty table is out of date - re-run its builder in tools/encounter_difficulty.")
	return "table: built %s, %d rows, output grid %.0f-%.0f (%d points), %s" % [
		_table.built_at, _table.entries.size(), _table.output_grid[0],
		_table.output_grid[_table.output_grid.size() - 1], _table.output_grid.size(), settings_note]

func _describe_input_changes(previous_inputs: Dictionary, inputs: Dictionary) -> String:
	var changes: Array[String] = []
	for key in ["max_pleasure", "orgasm_bank", "max_energy", "action_pleasure", "spare_energy", "output", "budget"]:
		if not is_equal_approx(float(previous_inputs.get(key, 0.0)), float(inputs[key])):
			changes.append("%s %s -> %s" % [key, _format_number(float(previous_inputs.get(key, 0.0))), _format_number(float(inputs[key]))])
	if previous_inputs.get("actions", "") != inputs["actions"]:
		changes.append("used actions changed")
	if changes.is_empty():
		return "(inputs differ in a field not listed here)"
	return ", ".join(changes)

func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(value))
	return "%.1f" % value
#endregion
