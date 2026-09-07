extends UnlockCondition
class_name Condition_LifetimeOrgasmCount

@export var required_count: int

func is_condition_met(save_game_state: SaveGameState,_encounter_report: EncounterReport) -> bool:
	return save_game_state.get_lifetime_orgasms() >= required_count
