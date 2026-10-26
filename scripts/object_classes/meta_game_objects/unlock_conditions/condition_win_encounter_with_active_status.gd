@tool
extends UnlockCondition
class_name Condition_WinEncounterWithActiveStatus

### Report: win the encounter while the player has the given status when it ends (EncounterReport.active_player_statuses_at_end_of_game,
### recorded at the same moment as the active passives). Condition_WinEncounterWithStatusStacks asks for a number of stacks.
### Unlike a passive, a status is not something the player owns, so the condition is never hidden from the player.

@export var encounter_id: String
@export var status_id: String

func is_judged_on_a_single_run() -> bool:
	return true

func is_condition_met(_save_game_state: SaveGameState,encounter_report: EncounterReport) -> bool:
	if not encounter_report:
		return false
	if encounter_report.encounter_def.encounter_id != encounter_id:
		return false
	if not encounter_report.player_won:
		return false
	return encounter_report.get_status_stacks_at_end_of_game(status_id) >= get_required_stacks()

### How many stacks of the status the player must have at the end: any (1 or more) here.
func get_required_stacks() -> int:
	return 1

func _build_description_segments(_save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	return _template("UI_UNLOCK_CONDITION_WIN_WITH_STATUS",
		{"encounter": _encounter_name(encounter_id), "status": _term_link("STATUS", status_id)})
