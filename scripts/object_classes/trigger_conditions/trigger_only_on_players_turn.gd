@tool
extends TriggerCondition
class_name TriggerCondition_OnlyOnPlayersTurn


func is_condition_met(
	_input_context: EffectContext,game_state: GameState,_save_game_state: SaveGameState,_owner_of_trigger: TargetEntity) -> bool:
	return game_state.it_is_players_turn()

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(tr("TRIGGERCONDITION_ONLYONPLAYERSTURN_TEMPLATE"))
