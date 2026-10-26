@tool
extends UnlockCondition
class_name Condition_WinWithAtMostNOrgasms

### Report: win the encounter while the player had at most max_orgasms orgasms (0 = never orgasmed).
### The inverse of Condition_OrgasmNTimesAndWinEncounter.

@export var encounter_id: String
@export var max_orgasms: int = 0

func is_judged_on_a_single_run() -> bool:
	return true

func is_condition_met(_save_game_state: SaveGameState,encounter_report: EncounterReport) -> bool:
	if not encounter_report:
		return false
	if not encounter_report.player_won:
		return false
	if encounter_report.encounter_def.encounter_id != encounter_id:
		return false
	return encounter_report.orgasms_achieved <= max_orgasms

### Fewest orgasms in a winning run of this encounter so far, from SaveGameState.encounter_records.
func get_progress_style() -> ProgressStyle:
	return ProgressStyle.BEST_LOWER

func get_progress_current(save_game_state: SaveGameState) -> int:
	return save_game_state.get_encounter_record(encounter_id,SaveGameState.RECORD_FEWEST_ORGASMS,-1)

func _build_description_segments(_save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	if max_orgasms <= 0:
		return _template("UI_UNLOCK_CONDITION_WIN_WITHOUT_ORGASM", {"encounter": _encounter_name(encounter_id)})
	return _template("UI_UNLOCK_CONDITION_WIN_WITH_AT_MOST_ORGASMS",
		{"encounter": _encounter_name(encounter_id), "count": _number(max_orgasms)}, max_orgasms)
