extends Node
class_name EntityRegistry

### This node tracks which target (opponent, player) is represented by which visual node.
@export var main_game: Node

var entity_to_control_node: Dictionary[String,Node] = {} #opponent_id, "player",card_instance -> node

func register_entity(entity_id: String, control_node: Node) -> void:
	entity_to_control_node[entity_id] = control_node

### expected_node, when given, guards against a stale/late unregister call clobbering a
### fresher registration under the same entity_id (e.g. a card discarded and almost
### immediately redrawn/re-registered before the old node's unregister call runs) - the entry
### is only erased if it still points at the caller's own node.
func unregister_entity(entity_id: String, expected_node: Node = null) -> void:
	if expected_node and entity_to_control_node.get(entity_id) != expected_node:
		return
	entity_to_control_node.erase(entity_id)

### Defensive: a stale/freed Node here means something freed a registered node without
### unregistering it first (see unregister_entity's expected_node guard above for hardening
### the write side against the most likely cause). Rather than crash the caller with Godot's
### "Trying to return a previously freed instance", clean up the dangling entry here and
### return null like any other unregistered id.
func get_control_node(entity_id: String) -> Node:
	if entity_id not in entity_to_control_node:
		return null
	var node: Node = entity_to_control_node[entity_id]
	if not is_instance_valid(node):
		entity_to_control_node.erase(entity_id)
		return null
	return node

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
