extends Resource
class_name AnimationHandler

func play_animation(
	_fragment: LogFragment, 
	_entity_registry: EntityRegistry,
	_animation_speed: float) -> void:
	#print("Animating fragment with message: %s"%fragment.message_key)
	pass


func get_source_node_for_effect(fragment: LogFragment,entity_registry: EntityRegistry) -> Control:
	var event_card_node: EventCard = null
	if fragment.context.event_card_causing_effect:
		var event_card_instance: EventCardInstance = fragment.context.event_card_causing_effect
		event_card_node = entity_registry.get_control_node(event_card_instance.entity_id)

	var source: TargetEntity = fragment.context.source
	var source_node: Control
	
	if event_card_node:
		source_node = event_card_node
		return source_node
		
	if not event_card_node:
		match source.get_script():
			PlayerEntity:
				if fragment.context.effect_origin is not PlayerAction:
					source_node = entity_registry.get_control_node("player")
				else:
					var opponent_with_action: String = fragment.context.target.opponent_id
					var opponent_card: OpponentCard = entity_registry.get_control_node(opponent_with_action)
					if not opponent_card:
						source_node = entity_registry.get_control_node("player")
					else:
						source_node = opponent_card.player_action_video
			OpponentEntity:
				#print("Returning that source is opponent id: %s"%source.opponent_id)
				source_node = entity_registry.get_control_node(source.opponent_id)
	return source_node
