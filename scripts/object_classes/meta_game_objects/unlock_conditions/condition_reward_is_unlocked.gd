extends UnlockCondition
class_name Condition_RewardIsUnlocked

@export var reward_id: String

func is_condition_met(save_game_state: SaveGameState,_encounter_report: EncounterReport) -> bool:
	return save_game_state.is_reward_unlocked(reward_id)
