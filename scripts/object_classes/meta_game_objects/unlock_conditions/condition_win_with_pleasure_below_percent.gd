@tool
extends UnlockCondition
class_name Condition_WinWithPleasureBelowPercent

### Report: win the encounter without the player's Pleasure ever going above max_peak_percent of their
### maximum. Needs EncounterReport.highest_player_pleasure_percent, recorded whenever the player gains
### Pleasure (an orgasm counts as 100% or more, so values below 100 also mean no orgasms).

@export var encounter_id: String
@export_range(1, 100, 1) var max_peak_percent: int = 50

func is_judged_on_a_single_run() -> bool:
	return true

func is_condition_met(_save_game_state: SaveGameState,encounter_report: EncounterReport) -> bool:
	if not encounter_report:
		return false
	if not encounter_report.player_won:
		return false
	if encounter_report.encounter_def.encounter_id != encounter_id:
		return false
	return encounter_report.highest_player_pleasure_percent <= float(max_peak_percent)

### Lowest peak in a winning run of this encounter so far, from SaveGameState.encounter_records.
func get_progress_style() -> ProgressStyle:
	return ProgressStyle.BEST_LOWER

func get_progress_current(save_game_state: SaveGameState) -> int:
	return save_game_state.get_encounter_record(encounter_id,SaveGameState.RECORD_LOWEST_PEAK_PLEASURE_PERCENT,-1)

func format_best_value(best_value: int) -> String:
	return "%d%%" % best_value

func _build_description_segments(_save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	return _template("UI_UNLOCK_CONDITION_WIN_BELOW_PLEASURE_PERCENT", {
		"encounter": _encounter_name(encounter_id), "percent": DescriptionSegment.emphasis_segment("%d%%" % max_peak_percent)})
