@tool
extends TriggerCondition
class_name TriggerCondition_RetaliatePlayerAction

@export var actions_ids_to_retaliate: Array[String]

func is_condition_met(
	input_context: EffectContext,_game_state: GameState,_save_game_state: SaveGameState,owner_of_trigger: TargetEntity) -> bool:
	#print("Condition is: %s"%trigger_condition_id)
	if input_context.effect_origin is not PlayerAction:
		#print("Did not take damage from player action")
		return false
	if input_context.target.get_data() != owner_of_trigger.get_data():
		#print("Target is not owner of trigger")
		return false
	if input_context.id_of_effect_origin not in actions_ids_to_retaliate:
		#print("Id of effect origin is not in actions")
		return false
	if not input_context.damage_amount:
		#print("No damage")
		return false
	if input_context.damage_amount <= 0:
		#print("Damage is zero")
		return false
	return true

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("TRIGGERCONDITION_RETALIATEPLAYERACTION_TEMPLATE"), {"action_names": _action_names(actions_ids_to_retaliate)})
