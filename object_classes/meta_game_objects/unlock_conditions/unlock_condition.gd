extends Resource
class_name UnlockCondition

@export var unlock_condition_id: String
@export var description: String

func is_condition_met(_save_game_state: SaveGameState,_encounter_report: EncounterReport) -> bool:
	return false

func is_condition_hidden_from_player(_save_game_state: SaveGameState) -> bool:
	### Overwritten by child classes.
	### Specific conditions can be hidden from the player to hide secrets,
	### and to prevent them from being overloaded with information early on.
	return false
