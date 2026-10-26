extends Cardgame_UI_Element
class_name FloatingPlayerActionCards

@export var card_controller: Control = self

@export var action_card_scene: PackedScene = preload("res://scenes/main_cardgame/player_actions/action_card.tscn")
													#res://scenes/main_cardgame/player_actions/action_card.tscn
@export var action_card_width: float = 125
@export var action_card_height: float = 145

@export var x_offset: float = 0

var current_card_count: int 
var max_spacing := action_card_height
var min_spacing := action_card_height * 0.35

var card_rest_positions: Dictionary = {} # action_id -> Vector2
var hovered_card: Control = null
var dragged_card: ActionCard = null
var hover_tween_duration: float = 0.15

@export var hover_shift_x: float = 30.0
@export var hover_z_index: int = 100

signal action_from_opponent_dropped_in_action_container(action_card: ActionCard)

const DRAG_RETURN_DELAY: float = 0.25
const WAIT_FOR_OTHER_OPPONENTS_CAPTURING_ACTION: float = 0.5

func _ready() -> void:
	super._ready()

func update_class_specific_displays(game_state: GameState) -> void:
	_make_unavailable_during_opponents_turn(game_state)
	_update_card_state_info(game_state)

func _initialize_for_new_encounter(game_state: GameState) -> void:
	_clear_old_cards()
	_add_action_cards_for_available_actions(game_state)
	_make_unavailable_during_opponents_turn(game_state)
	_update_card_state_info(game_state)

func _update_card_state_info(game_state: GameState) -> void:
	for child in card_controller.get_children():
		if child is ActionCard:
			child.show_if_disabled_by_status(game_state)

func _add_action_cards_for_available_actions(game_state:GameState) -> void:
	var active_actions: Array[String] = ActionManager.get_inactive_actions(game_state)
	if active_actions.is_empty():
		return
	var card_positions: Array[Vector2] = _calculate_card_positions(active_actions.size())
	for index in range(0,active_actions.size()):
		var _new_card: ActionCard = _add_card_for_action(active_actions[index],card_positions[index])

func _on_action_retracted_from_opponent(
	opponent_id: String,action_id: String,_cause_of_retraction: String = "") -> void:
	if opponent_id == "" or opponent_id == null:
		return
	var spawn_node: OpponentCard = main_game.entity_registry.get_control_node(opponent_id)
	if not is_instance_valid(spawn_node):
		return
	
	spawn_node.disable_dragging()
	spawn_node._display_active_player_action(null)
	spawn_node.hide_player_action_video()
	spawn_node.clear_active_player_action_id()
	#spawn_node.player_action_video.visible = false
	#spawn_node.active_player_action_id = ""
	
	var new_card_instance: ActionCard = _instantiate_new_action_card(action_id)
	var spawn_position: Vector2 = spawn_node.get_action_card_movement_location()
	new_card_instance.global_position = spawn_position
	new_card_instance.change_animation_state(ActionCard.AnimationState.FAILED_TO_RESOLVE)
	main_game.sound_manager.end_soundtrack_for_player_action(action_id)
	
	var target_rest_position: Vector2 = card_rest_positions.get(action_id, Vector2.ZERO) + self.global_position
	new_card_instance.request_signal_when_returned_to_position(target_rest_position)
	
	
	await new_card_instance.returned_to_hand
	if is_instance_valid(spawn_node):
		spawn_node.enable_dragging()

#func _on_action_retracted_from_opponent(
	#opponent_id: String,action_id: String,_cause_of_retraction: String = "") -> void:
	#if opponent_id == "" or opponent_id == null:
		#return
	#var new_card_instance: ActionCard = _instantiate_new_action_card(action_id)
	##card_controller.add_child(new_card_instance)
	#var spawn_node: OpponentCard = main_game.entity_registry.get_control_node(opponent_id)
	#if not spawn_node:
		#return	
	#spawn_node.disable_dragging()
	#var spawn_position: Vector2 = spawn_node.get_action_card_movement_location()
	#new_card_instance.global_position = spawn_position
#
	#new_card_instance.change_animation_state(ActionCard.AnimationState.FAILED_TO_RESOLVE)
	#main_game.sound_manager.end_soundtrack_for_player_action(action_id)
	#new_card_instance.request_signal_when_returned_to_position(card_rest_positions[action_id]+self.global_position)
	#if not new_card_instance:
		#if spawn_node:
			#spawn_node.enable_dragging()
		#return
	#
	#await new_card_instance.returned_to_hand
	#if spawn_node:
		#spawn_node.enable_dragging()
	

func _add_card_for_action(action_id: String, _position: Vector2) -> ActionCard:
	var new_card_instance: ActionCard = _instantiate_new_action_card(action_id)
	new_card_instance.position = _position
	card_rest_positions[new_card_instance.represented_action_id] = _position
	return new_card_instance

func _instantiate_new_action_card(action_id: String) -> ActionCard:
	var new_card_instance: ActionCard = action_card_scene.instantiate()
	card_controller.add_child(new_card_instance)
	new_card_instance.display_action(action_id)
	new_card_instance.register_card_in_entity_registry()
	new_card_instance.connect("hovered", Callable(self,"_action_card_hovered"))
	new_card_instance.connect("unhovered", Callable(self,"_action_card_unhovered"))
	new_card_instance.connect("_relay_another_action_card_dropped",Callable(self,"_relay_action_moved_from_opponent_to_actions"))
	new_card_instance.connect("drag_started", Callable(self,"_new_card_getting_dragged"))
	new_card_instance.connect("animation_state_changed",Callable(self,"_action_card_changed_state"))
	#print("NEW CARD:", action_id, " ", new_card_instance.get_instance_id())
	return new_card_instance


func _relay_action_moved_from_opponent_to_actions(action_card: ActionCard) -> void:
	emit_signal("action_from_opponent_dropped_in_action_container",action_card)

func _new_card_getting_dragged(action_card: ActionCard) -> void:
	_clear_dragged_card()
	_clear_hovered_card()
	dragged_card = action_card
	main_game.sound_manager.play_sound_effect(SoundManager.SoundEffects.ACTION_CARD_START_DRAGGING)
	
func _clear_dragged_card() -> void:
	dragged_card = null
	
func _clear_hovered_card() -> void:
	hovered_card = null

func _assign_action_to_opponent_card(action_id: String,opponent_id: String) -> void:
	### When intent context resolves moving card, this method is called to update the variable
	### represented on the action card of the opponent.
	var opponent_card: OpponentCard = main_game.entity_registry.get_control_node(opponent_id)
	opponent_card.active_player_action_id = action_id
	opponent_card._display_active_player_action(AutoloadDatabase.player_actions_by_id[action_id])
	
		
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is ActionCard:
		_relay_action_moved_from_opponent_to_actions(data)

func _action_card_changed_state(action_card: ActionCard) -> void:
	#print("Notified of _action_card_changed_state")
	var state_changes_to_ignore: Array[ActionCard.AnimationState] = [
		ActionCard.AnimationState.RESOLVING
		]
	if action_card.animation_state in state_changes_to_ignore:
		return 
	if action_card.animation_state == ActionCard.AnimationState.RESOLVING:
		card_rest_positions[action_card.represented_action_id] = action_card.position
	
	_shift_cards_in_hand_to_correct_position()

	if action_card.animation_state == ActionCard.AnimationState.FAILED_TO_RESOLVE:
		await _animate_card_moving_to_resting_position(action_card)
		#if not action_card:
			#return
		if not is_instance_valid(action_card):
			return
		action_card.change_animation_state(ActionCard.AnimationState.IN_HAND)

func _shift_cards_in_hand_to_correct_position() -> void:
	###This method should be called every time the state of a card changes!
	var cards_in_hand: Array[Node] = _get_cards_with_position_in_hand()
	_update_resting_positions_based_on_visible_cards(cards_in_hand)
	_animate_cards_in_hand_moving_to_rest_position(cards_in_hand)

func _update_resting_positions_based_on_visible_cards(cards_in_hand: Array[Node]) -> void:
	### This works, BUT: It reflects UI state, not true state.
	card_rest_positions.clear()
	var card_positions: Array[Vector2] = _calculate_card_positions(cards_in_hand.size())
	for i in cards_in_hand.size():
		card_rest_positions[cards_in_hand[i].represented_action_id] = card_positions[i]
	
func _get_cards_with_position_in_hand() -> Array[Node]:
	var cards_in_hand: Array[Node] = []
	var states_to_move: Array = [
		ActionCard.AnimationState.IN_HAND,
		ActionCard.AnimationState.FAILED_TO_RESOLVE
	]
	for card in card_controller.get_children():
		if card is not ActionCard:
			continue
		if card.animation_state not in states_to_move:
			continue

		cards_in_hand.append(card)
	return cards_in_hand

func _animate_cards_in_hand_moving_to_rest_position(cards_in_hand: Array[Node]) -> void:
	for card in cards_in_hand:
		_animate_card_moving_to_resting_position(card)
	#
	
func _animate_card_moving_to_resting_position(card_node: ActionCard) -> void:
	if card_node.represented_action_id not in card_rest_positions.keys():
		print("Could not find rest position for %s" %card_node.represented_action_id)
		#push_error("Could not find rest position for %s" %card_node.represented_action_id)
		return
	await AnimationHelper_NodeMover.move_node_with_tween(
		card_node,card_rest_positions[card_node.represented_action_id],0.5,"position")	

#endregion

func _calculate_card_positions(nr_of_cards_in_hand: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if nr_of_cards_in_hand <= 0:
		return positions
	var spacing: float = clamp(
		(self.size.y - action_card_height) / max(1, nr_of_cards_in_hand - 1),
		min_spacing,
		max_spacing
	)
	var total_height: float = action_card_height
	if nr_of_cards_in_hand > 1:
		total_height += spacing * (nr_of_cards_in_hand - 1)
	var start_y: float = (self.size.y - total_height) * 0.5
	for i in range(nr_of_cards_in_hand):
		positions.append(Vector2(x_offset,start_y + i * spacing))

	return positions
#
func _clear_old_cards() -> void:
	card_rest_positions.clear()
	for child in card_controller.get_children():
		if child is ActionCard:
			child.free_and_unregister()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		var states_to_ignore: Array[ActionCard.AnimationState] = [
			ActionCard.AnimationState.IN_HAND,
			ActionCard.AnimationState.RESOLVING,
			ActionCard.AnimationState.FAILED_TO_RESOLVE]
		for action_card in card_controller.get_children():
			if not is_instance_valid(action_card):
				continue
			if action_card is not ActionCard:
				continue
			if action_card.animation_state in states_to_ignore:
				continue
			action_card.global_position = get_global_mouse_position()+action_card._drag_offset
			main_game.sound_manager.play_sound_effect(SoundManager.SoundEffects.ACTION_CARD_END_DRAGGING)
			if action_card.animation_state != ActionCard.AnimationState.DRAGGING:
				continue
			
			action_card.change_animation_state(ActionCard.AnimationState.RESOLVING)
			action_card._drag_offset = Vector2(0,0)
			
			await get_tree().create_timer(DRAG_RETURN_DELAY).timeout
			if not is_instance_valid(action_card):
				continue
			
			if action_card.animation_state == ActionCard.AnimationState.RESOLVING:
				action_card.change_animation_state(ActionCard.AnimationState.FAILED_TO_RESOLVE)
				await get_tree().create_timer(DRAG_RETURN_DELAY).timeout
				if not is_instance_valid(action_card):
					continue
				action_card.change_animation_state(ActionCard.AnimationState.IN_HAND)

#func _notification(what: int) -> void:
	#if what == NOTIFICATION_DRAG_END:
		#var states_to_ignore: Array[ActionCard.AnimationState] = [
			#ActionCard.AnimationState.IN_HAND,
			#ActionCard.AnimationState.RESOLVING,
			#ActionCard.AnimationState.FAILED_TO_RESOLVE]
		#for action_card in card_controller.get_children():
			#if action_card is not ActionCard:
				#continue
			#if action_card.animation_state in states_to_ignore:
				## Notification always runs for all cards, so it needs to be supressed for certain states
				#continue
			#action_card.global_position = get_global_mouse_position()+action_card._drag_offset
			#main_game.sound_manager.play_sound_effect(SoundManager.SoundEffects.ACTION_CARD_END_DRAGGING)
			#if  action_card.animation_state != ActionCard.AnimationState.DRAGGING:
				#continue
			#
			#action_card.change_animation_state(ActionCard.AnimationState.RESOLVING)
			#
			#action_card._drag_offset = Vector2(0,0)
			#var timer: Timer = Timer.new()
			#action_card.add_child(timer)
			#timer.autostart = true
			#timer.start(DRAG_RETURN_DELAY)
			#await timer.timeout
			##if not action_card:
				##return
			#if action_card.animation_state == ActionCard.AnimationState.RESOLVING:
				#action_card.change_animation_state(ActionCard.AnimationState.FAILED_TO_RESOLVE)
				#var to_hand_timer: Timer = Timer.new()
				#action_card.add_child(to_hand_timer)
				#to_hand_timer.autostart = true
				#to_hand_timer.start(DRAG_RETURN_DELAY)
				#await to_hand_timer.timeout
				#action_card.change_animation_state(ActionCard.AnimationState.IN_HAND)


#region Hovering-methods for event cards:

func _action_card_hovered(card_node: ActionCard) -> void:
	if not main_game.game_state.player_can_input():
		return
	if hovered_card == ActionCard:
		return
	if not main_game.game_state.it_is_players_turn():
		return
	if card_node.animation_state != ActionCard.AnimationState.IN_HAND:
		#print("Hovered card is not IN HAND, returning.")
		return
	if card_node.animation_state == ActionCard.AnimationState.DRAGGING:
		return
	_restore_hovered_card()
	hovered_card = card_node
	card_node.z_index += hover_z_index
	
	if card_node.represented_action_id not in card_rest_positions.keys():
		return

	
	var rest_position: Vector2 = card_rest_positions[card_node.represented_action_id]
	var target_position: Vector2 = rest_position + Vector2(hover_shift_x,0)
	card_node.tween_to_position(target_position,hover_tween_duration)


func _action_card_unhovered(card_node: ActionCard) -> void:
	if hovered_card != card_node:
		return
	_restore_hovered_card()

func _restore_hovered_card()-> void:
	if hovered_card == null:
		return
	if hovered_card.represented_action_id not in card_rest_positions.keys():
		return
	if not main_game.game_state.it_is_players_turn():
		return

	var target_position: Vector2 = card_rest_positions[hovered_card.represented_action_id]
	hovered_card.z_index = 0
	hovered_card.tween_to_position(target_position,hover_tween_duration)
