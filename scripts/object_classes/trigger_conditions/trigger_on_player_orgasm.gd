@tool
extends TriggerCondition
class_name TriggerCondition_OnPlayerOrgasm

func is_condition_met(
	input_context: EffectContext,
	_game_state: GameState
	,_save_game_state: SaveGameState,
	_owner_of_trigger: TargetEntity) -> bool:
		
	return input_context.player_orgasmed

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(tr("TRIGGERCONDITION_ONPLAYERORGASM_TEMPLATE"))
