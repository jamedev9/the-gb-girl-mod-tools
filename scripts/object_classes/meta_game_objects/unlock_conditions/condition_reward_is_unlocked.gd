@tool
extends UnlockCondition
class_name Condition_RewardIsUnlocked

@export var reward_id: String

func is_condition_met(save_game_state: SaveGameState,_encounter_report: EncounterReport) -> bool:
	return save_game_state.is_reward_unlocked(reward_id)

func _build_description_segments(_save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	var required_reward: RewardDefinition = AutoloadDatabase.get_unlock_reward_definition(reward_id)
	var reward_name: String = required_reward.get_reward_name() if required_reward else reward_id
	return _template("UI_UNLOCK_CONDITION_REWARD_UNLOCKED", {"reward": _name_emphasis(reward_name)})
