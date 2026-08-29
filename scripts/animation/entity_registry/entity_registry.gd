extends Node
class_name EntityRegistry

### This node tracks which target (opponent, player) is represented by which visual node.
@export var main_game: Node

var entity_to_control_node: Dictionary[String,Node] = {} #opponent_id, "player",card_instance -> node

func register_entity(entity_id: String, control_node: Node) -> void:
	entity_to_control_node[entity_id] = control_node

func unregister_entity(entity_id: String) -> void:
	entity_to_control_node.erase(entity_id)

func get_control_node(entity_id: String) -> Node:
	if entity_id in entity_to_control_node.keys():
		return entity_to_control_node.get(entity_id)
	return null

func register_dict_of_entities(dict: Dictionary[String,Node]) -> void:
	for key in dict.keys():
		register_entity(key,dict[key])
	

func reset_registry() -> void:
	entity_to_control_node.clear()
	#register_entity("main_game",main_game)
	#register_entity("cardgame_ui",main_game.card_game_controler)
	#register_entity("player",main_game.player_stat_display)
	#register_entity("discard_pile",main_game.discard_pile)
	#register_entity("draw_pile",main_game.draw_pile)
	#register_entity("event_card_hand",main_game.floating_player_event_cards)
	#register_entity("action_card_hand",main_game.floating_player_action_cards)
	#register_entity("new_turn_phase_splash",main_game.new_turn_phase_splash)
	#register_entity("popup_controller",main_game.popup_controller)
	#register_entity("sound_manager",main_game.sound_manager)
	#register_entity("player_status_effects_display",main_game.player_status_effects_display)
	#register_entity("opponents_container",main_game.opponents_container)
	#register_entity("remaining_opponents_counter",main_game.remaining_opponents_counter)
	#register_entity("end_turn_button",main_game.end_turn_button)
