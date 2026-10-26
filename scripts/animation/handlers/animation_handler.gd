extends Resource
class_name AnimationHandler

func play_animation(
	_fragment: LogFragment, 
	_entity_registry: EntityRegistry,
	_animation_speed: float) -> void:
	#print("Animating fragment with message: %s"%fragment.message_key)
	pass


### Global position effect numbers spawn from. A player action resolving on a card that
### returns the card itself as its source node (the rework card) spawns at its action art.
func get_source_position_for_effect(fragment: LogFragment, source_node: Control) -> Vector2:
	if source_node is OpponentCard and fragment.context.source is PlayerEntity:
		return source_node.get_action_source_position()
	return source_node.global_position + 0.5*source_node.size

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
					### The target is the opponent the action is on, unless the action's effect targets the
					### player: then the opponent it is on is carried in dropped_on_opponent.
					var opponent_with_action: String = fragment.context.dropped_on_opponent
					if fragment.context.target is OpponentEntity:
						opponent_with_action = fragment.context.target.opponent_id
					var opponent_card: OpponentCard = entity_registry.get_control_node(opponent_with_action)
					if not opponent_card:
						source_node = entity_registry.get_control_node("player")
					else:
						source_node = opponent_card.get_action_source_node()
			OpponentEntity:
				#print("Returning that source is opponent id: %s"%source.opponent_id)
				source_node = entity_registry.get_control_node(source.opponent_id)
	return source_node
