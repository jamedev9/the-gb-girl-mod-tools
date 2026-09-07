@tool
extends StatusModifierComponent
class_name Modifier_PreventApplyingStatusesToSpecificOpponentTypes

@export var opponent_type_ids: Array[String] = []

func modify_context(context: EffectContext) -> void:
	if context.target is not OpponentEntity:
		return
	var opponent_instance: OpponentInstance = context.target.get_data()
	if not opponent_instance:
		return
	
	var opponent_type: OpponentType = opponent_instance.opponent_type
	if opponent_type.opponent_type_id not in opponent_type_ids:
		return
	
	if not context.statuses_to_apply:
		return
		
	context.statuses_to_apply.clear()

### With an empty opponent_type_ids, modify_context() above always returns early - the
### component is a configured-but-inert no-op. Flag that plainly instead of rendering a
### malformed "...of the  type..." sentence with a blank name.
func get_description_segments() -> Array[DescriptionSegment]:
	if opponent_type_ids.is_empty():
		return [DescriptionSegment.text_segment("[%s - no opponent types set]" % get_script().get_global_name())]
	return DescriptionBuilder.parse_template(
		tr("MODIFIER_PREVENTAPPLYINGSTATUSESTOSPECIFICOPPONENTTYPES_TEMPLATE"),
		{"type_names": _opponent_type_names(opponent_type_ids)})

