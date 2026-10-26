@tool
extends Resource
class_name EncounterDifficultyTable

### The pre-calculated half of the encounter difficulty estimate: for every character x encounter, how much
### pleasure the player is expected to take while clearing the encounter, sampled at a grid of player-output
### values (pleasure the player deals per turn). Written by tools/encounter_difficulty (F6) - never edit by
### hand. The runtime (EncounterDifficultyService) interpolates it for the current save's output.
### There are two: the rework's (kept in the ContentSet) and the prototype's (load_prototype()).

const PROTOTYPE_RESOURCE_PATH: String = "res://resources/encounter_difficulty/prototype_encounter_difficulty_table.tres"

### The table the prototype / DEFAULT mode uses. In shared resources/ (not a rework folder) so it ships in prototype builds.
static func load_prototype() -> EncounterDifficultyTable:
	if not ResourceLoader.exists(PROTOTYPE_RESOURCE_PATH):
		return null
	return load(PROTOTYPE_RESOURCE_PATH) as EncounterDifficultyTable

### Ascending player-output values every entry is sampled at.
@export var output_grid: PackedFloat32Array = PackedFloat32Array()
### "<character_id>/<encounter_id>" -> {"mean": PackedFloat32Array, "spread": PackedFloat32Array,
### "turns": PackedFloat32Array}, one value per output_grid point. Untyped on purpose (nested containers).
@export var entries: Dictionary = {}
### EncounterDifficultyWeights.get_table_settings_snapshot() at build time.
@export var built_with_settings: Dictionary = {}
@export var built_at: String = ""
### Character ids that are the same character under another id: alias -> id of the character that has the rows.
### The prototype's default character is "default", but a save that never picked one says "emily".
@export var character_aliases: Dictionary = {}
### The character whose rows stand in for a character that has none (a mod character; the builder skips those). The rows
### only describe which Moves a character's actions allow - the player's output and budget come from the save - so a stranger's
### rows are a fair approximation. Empty = no fallback, such a character is unrated.
@export var fallback_character_id: String = ""

static func make_key(character_id: String, encounter_id: String) -> String:
	return "%s/%s" % [character_id, encounter_id]

func is_empty() -> bool:
	return entries.is_empty() or output_grid.size() < 2

func set_entry(
		character_id: String, encounter_id: String,
		mean: PackedFloat32Array, spread: PackedFloat32Array, turns: PackedFloat32Array) -> void:
	entries[make_key(character_id, encounter_id)] = {"mean": mean, "spread": spread, "turns": turns}

func _resolve_character_id(character_id: String) -> String:
	return String(character_aliases.get(character_id, character_id))

func has_character(character_id: String) -> bool:
	var prefix: String = _resolve_character_id(character_id) + "/"
	for key in entries.keys():
		if String(key).begins_with(prefix):
			return true
	return false

func has_entry(character_id: String, encounter_id: String) -> bool:
	return not _find_entry(character_id, encounter_id).is_empty()

### True when this character has no rows of its own and the fallback character's are used instead.
func uses_fallback_for(character_id: String) -> bool:
	return fallback_character_id != "" and not has_character(character_id)

func _find_entry(character_id: String, encounter_id: String) -> Dictionary:
	var entry: Dictionary = entries.get(make_key(_resolve_character_id(character_id), encounter_id), {})
	if entry.is_empty() and fallback_character_id != "":
		entry = entries.get(make_key(fallback_character_id, encounter_id), {})
	return entry

### {"mean", "spread", "turns"} for the given player output, interpolated on a log scale between the two
### nearest grid points (clamped to the grid's ends). Empty when the character x encounter has no entry.
func sample(character_id: String, encounter_id: String, player_output: float) -> Dictionary:
	var entry: Dictionary = _find_entry(character_id, encounter_id)
	if entry.is_empty() or output_grid.size() < 2:
		return {}
	var output: float = maxf(player_output, 0.001)
	var last_index: int = output_grid.size() - 1
	if output <= output_grid[0]:
		return _pick_point(entry, 0, 0, 0.0)
	if output >= output_grid[last_index]:
		return _pick_point(entry, last_index, last_index, 0.0)
	var upper_index: int = 1
	while output_grid[upper_index] < output:
		upper_index += 1
	var lower_index: int = upper_index - 1
	var log_lower: float = log(output_grid[lower_index])
	var log_upper: float = log(output_grid[upper_index])
	var blend: float = (log(output) - log_lower) / (log_upper - log_lower)
	return _pick_point(entry, lower_index, upper_index, blend)

func _pick_point(entry: Dictionary, lower_index: int, upper_index: int, blend: float) -> Dictionary:
	var mean_values: PackedFloat32Array = entry["mean"]
	var spread_values: PackedFloat32Array = entry["spread"]
	var turn_values: PackedFloat32Array = entry["turns"]
	return {
		"mean": lerpf(mean_values[lower_index], mean_values[upper_index], blend),
		"spread": lerpf(spread_values[lower_index], spread_values[upper_index], blend),
		"turns": lerpf(turn_values[lower_index], turn_values[upper_index], blend),
	}
