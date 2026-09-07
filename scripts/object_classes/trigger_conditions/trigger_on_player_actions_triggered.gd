@tool
extends TriggerCondition
class_name TriggerCondition_OnPlayerActionsTriggered

@export var action_ids: Array[String]

func is_condition_met(
	input_context: EffectContext,
	_game_state: GameState
	,_save_game_state: SaveGameState,
	_owner_of_trigger: TargetEntity) -> bool:
		
	#if input_context.effect_origin is not PlayerAction:
		##print("Did not take damage from player action")
		#return false
			
	if input_context.effect_origin is not ApplyEffectOfPlayerAction:
		#print("Effect is not applyeffectofplayeraction")
		return false	
	if input_context.effect_origin.player_action_id not in action_ids:
		#print("Id of effect origin is not in actions. Action: %s"%input_context.player_action_id)
		return false
	### damage_phase is NOT a reliable extra check here - it gets overwritten to INCOMING
	### whenever the target has any active status effect (see the MODIFY phase in
	### effect_context_manager.gd), unrelated to whether this action is actually resolving.
	#print("Found context with ApplyEffectOfPlayerAction as effect origin.")
	return true

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("TRIGGERCONDITION_ONPLAYERACTIONSTRIGGERED_TEMPLATE"), {"action_names": _action_names(action_ids)})
