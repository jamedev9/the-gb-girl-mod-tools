@tool
extends StatusModifierComponent
class_name PreventMovingActionsToTarget

@export var all_actions: bool = false
@export var action_ids: Array[String]

func modify_context(effect_context: EffectContext) -> void:
	#print("PreventMovingActionsToTarget:")
	if not effect_context.moving_player_action:
		#print("Effect context is not moving player action")
		return
	if all_actions:
		effect_context.target_is_immune_to_action = true
		#print("All actions were chosen, setting immune to true")
		return
	if effect_context.player_action_id in action_ids:
		effect_context.target_is_immune_to_action = true
		#print("One of the chosen actions was moved, setting immune to true")
		return
	#if effect_context.player_action_id

func get_description_segments() -> Array[DescriptionSegment]:
	if all_actions:
		return DescriptionBuilder.parse_template(tr("PREVENTMOVINGACTIONSTOTARGET_ALL_TEMPLATE"))
	return DescriptionBuilder.parse_template(
		tr("PREVENTMOVINGACTIONSTOTARGET_TEMPLATE"), {"action_names": _action_names(action_ids)})
