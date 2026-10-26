extends Cardgame_UI_Element
class_name FloatingPlayerHand
### This node owns the Event Card nodes.

@export var card_controller: Control = self

@export var card_scene: PackedScene = load("res://scenes/main_cardgame/event_cards/event_card.tscn")

@export var event_card_width: float = 230
@export var event_card_height: float = 325

var current_card_count: int 
var max_spacing := event_card_width
var min_spacing := event_card_width * 0.00001

var card_rest_positions: Dictionary[String,Vector2] = {} # card -> Vector2
var hovered_card: Control = null

var dragged_card: EventCard = null

const hover_raise_y: float = -30.0
const hover_z_index: int = 100
const hover_tween_duration: float = 0.15
const DURATION_OF_RETURN_ANIMATION: float = 0.5
const DRAG_RETURN_DELAY: float = 0.1
const DROP_MOVE_DURATION: float = 0.5

signal _request_drag_arrow_start_from_event_card(event_card: EventCard)

#func _ready() -> void:
	#if main_game is not MainCardgame:
		#_start_debug_mode()
#
#func _start_debug_mode() -> void:
	#### This method is used to simulate the game
	#pass

func _on_fragment_animations_finished() -> void:
	_shift_cards_in_hand_to_correct_position()


#region Rebuild: This node owns the card nodes and their rest positions.
func update_class_specific_displays(game_state: GameState) -> void:
	_clear_cards_not_in_hand(game_state)
	_make_unavailable_during_opponents_turn(game_state)
	
func _event_card_changed_state(event_card: EventCard) -> void:
	var state_changes_to_ignore: Array[EventCard.AnimationState] = [
		EventCard.AnimationState.NOT_DRAWN,
		EventCard.AnimationState.IN_DISCARD_PILE,
		EventCard.AnimationState.RESOLVING,
		EventCard.AnimationState.RESOLVED,
		]
	if event_card.animation_state in state_changes_to_ignore:
		return 
	if event_card.animation_state == EventCard.AnimationState.RESOLVING:
		card_rest_positions[event_card.event_card_instance.entity_id] = event_card.position
	
	_shift_cards_in_hand_to_correct_position()


func _shift_cards_in_hand_to_correct_position() -> void:
	###This method should be called every time the state of a card changes!
	_clear_cards_in_discard_pile()
	var cards_in_hand: Array[Node] = _get_cards_with_position_in_hand()
	_update_resting_positions_based_on_visible_cards(cards_in_hand)
	_animate_cards_in_hand_moving_to_rest_position(cards_in_hand)
	

func _update_resting_positions_based_on_visible_cards(cards_in_hand: Array[Node]) -> void:
	### This works, BUT: It reflects UI state, not true state.
	card_rest_positions.clear()
	var card_positions: Array[Vector2] = _calculate_card_positions(cards_in_hand.size())
	for i in cards_in_hand.size():
		card_rest_positions[cards_in_hand[i].event_card_instance.entity_id] = card_positions[i]

func _update_true_resting_positions(_cards_in_hand: Array[Node]) -> void:
	card_rest_positions.clear()
	### This method considers where cards are going to rest once all animations are finished.
	var cards_taking_space_in_hand: Array[EventCardInstance] = main_game.game_state.event_cards_hand
	var card_positions: Array[Vector2] = _calculate_card_positions(cards_taking_space_in_hand.size())
	for i in cards_taking_space_in_hand.size():
		card_rest_positions[cards_taking_space_in_hand[i].entity_id] = card_positions[i]

	
func _get_cards_with_position_in_hand() -> Array[Node]:
	#print("Running _get_cards_with_position_in_hand")
	var cards_in_hand: Array[Node] = []
	var states_to_move: Array = [
		EventCard.AnimationState.IN_HAND,
		EventCard.AnimationState.DISCARDING,
		EventCard.AnimationState.DRAWING,
		EventCard.AnimationState.FAILED_TO_RESOLVE
	]
	for card in card_controller.get_children():
		if card is not EventCard:
			continue
		if card.animation_state not in states_to_move:
			continue
		#print("Found card in hand: %s with state: %s"%[
			#card.event_card_instance.entity_id,
			#EventCard.AnimationState.keys()[card.animation_state]])
		cards_in_hand.append(card)
	return cards_in_hand

func _animate_cards_in_hand_moving_to_rest_position(cards_in_hand: Array[Node]) -> void:
	for card in cards_in_hand:
		if card.animation_state == EventCard.AnimationState.DRAWING:
			continue
		_animate_card_moving_to_resting_position(card)
	
func _animate_card_moving_to_resting_position(card_node: EventCard) -> void:
	if card_node.event_card_instance.entity_id not in card_rest_positions.keys():
		return
	var duration: float = DURATION_OF_RETURN_ANIMATION*main_game.meta_game.get_animation_speed()
	await card_node.tween_to_position(card_rest_positions[card_node.event_card_instance.entity_id],duration)

func _clear_cards_in_discard_pile() -> void:
	for card in card_controller.get_children():
		if card is EventCard:
			if card.animation_state == EventCard.AnimationState.IN_DISCARD_PILE:
				card.free_and_unregister()
				

# Drawing card: This means the card is added to the control node. It is inviisbile until drawn
func draw_card(card_instance:EventCardInstance):
	var card :EventCard = spawn_new_event_card_node(card_instance)
	card_controller.add_child(card)
	card.update_alignment_of_textbox()
	card.update_energy_cost(main_game.game_state)
	card.visible = false
	card.register_self_as_node_representing_event_card_instance(card_instance)
	

func spawn_new_event_card_node(card_instance: EventCardInstance) -> EventCard:
	var new_event_card: EventCard = card_scene.instantiate()
	new_event_card.display_event_card(card_instance)
	new_event_card.custom_minimum_size = Vector2(event_card_width,event_card_height)
	new_event_card.connect("hovered", Callable(self,"_event_card_hovered"))
	new_event_card.connect("unhovered", Callable(self,"_event_card_unhovered"))
	new_event_card.connect("animation_state_changed",Callable(self,"_event_card_changed_state"))
	new_event_card.connect("drag_started",Callable(self,"_new_card_getting_dragged"))
	return new_event_card

func _new_card_getting_dragged(event_card: EventCard) -> void:
	_clear_dragged_card()
	_clear_hovered_card()
	dragged_card = event_card
	disable_mouse_interaction(event_card)
	main_game.sound_manager.play_sound_effect(SoundManager.SoundEffects.EVENT_CARD_START_DRAGGING)
	### Drag Arrow:
	_start_dragging_arrow_from_card(event_card)
	
func _start_dragging_arrow_from_card(event_card: EventCard) -> void:
	emit_signal("_request_drag_arrow_start_from_event_card",event_card)

func _clear_dragged_card() -> void:
	dragged_card = null
	
func _clear_hovered_card() -> void:
	hovered_card = null
	
func get_local_rest_position_of_event_card(event_card: EventCard) -> Vector2:
	var id: String = event_card.event_card_instance.entity_id
	if not card_rest_positions.has(id):
		push_error(
			"Missing rest position for card %s. Known keys: %s"
			% [id, card_rest_positions.keys()]
		)
		return position
	return card_rest_positions[id]

func get_global_rest_position_of_event_card(event_card: EventCard) -> Vector2:
	var id: String = event_card.event_card_instance.entity_id
	if not card_rest_positions.has(id):
		push_error(
			"Missing rest position for card %s. Known keys: %s"
			% [id, card_rest_positions.keys()]
		)
		return global_position
	return card_rest_positions[id] + global_position

func _clear_old_cards() -> void:
	### This is ONLY CALLED when a new game is started.
	for child in card_controller.get_children():
		if child is EventCard:
			child.free_and_unregister()



func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		for event_card in card_controller.get_children():
			if not event_card:
				continue
			if event_card is not EventCard:
				continue
			#if event_card.animation_state != EventCard.AnimationState.DRAGGING and event_card.animation_state != EventCard.AnimationState.DRAGGING_ARROW:
				#continue
			if event_card.animation_state == EventCard.AnimationState.DRAGGING:
				_handle_event_card_that_was_dragging(event_card)
				continue
			if event_card.animation_state == EventCard.AnimationState.DRAGGING_ARROW:
				_handle_event_card_that_was_arrow_targeting(event_card)
				continue

func _handle_event_card_that_was_arrow_targeting(event_card: EventCard) -> void:
	_clear_hovered_card()
	_clear_dragged_card()
	main_game.sound_manager.play_sound_effect(SoundManager.SoundEffects.EVENT_CARD_END_DRAGGING)
	event_card.change_animation_state(EventCard.AnimationState.RESOLVING)
	await _wait_for_event_card_resolution(event_card)

func _handle_event_card_that_was_dragging(event_card: EventCard) -> void:
		_clear_hovered_card()
		_clear_dragged_card()
		main_game.sound_manager.play_sound_effect(SoundManager.SoundEffects.EVENT_CARD_END_DRAGGING)
		var dropped_position: Vector2 =  get_global_mouse_position()+event_card._drag_offset - self.global_position
		event_card.position = dropped_position
		var resting_drop_position: Vector2 = _get_drop_resting_position(event_card, dropped_position)
		if resting_drop_position != dropped_position:
			event_card.tween_to_position(resting_drop_position, DROP_MOVE_DURATION * main_game.meta_game.get_animation_speed())

		card_rest_positions[event_card.event_card_instance.entity_id] = resting_drop_position

		event_card.change_animation_state(EventCard.AnimationState.RESOLVING)
		event_card._drag_offset = Vector2(0,0)
		
		await _wait_for_event_card_resolution(event_card)

### Where a card dropped at dropped_position (local to this node) should end up while it resolves.
### The card is placed at dropped_position first and slides from there. Subclasses can move it aside.
func _get_drop_resting_position(_event_card: EventCard, dropped_position: Vector2) -> Vector2:
	return dropped_position

func _wait_for_event_card_resolution(event_card: EventCard) -> void:
	await get_tree().create_timer(DRAG_RETURN_DELAY).timeout
	if not is_instance_valid(event_card):
		return
	
	if event_card.event_card_instance in main_game.game_state.event_cards_hand:
		### Released over the hand = cancelled on purpose (see EventCardDropOverlay): no failure flash.
		if not event_card.get_meta(EventCardDropOverlay.CANCELLED_META, false):
			AnimationHelper_NodeFlasher._flash_nodes_red([event_card],1,1,0.2)
		event_card.remove_meta(EventCardDropOverlay.CANCELLED_META)
		event_card.change_animation_state(EventCard.AnimationState.FAILED_TO_RESOLVE)
		
		await get_tree().create_timer(DRAG_RETURN_DELAY).timeout
		if not is_instance_valid(event_card):
			return
		
		event_card.change_animation_state(EventCard.AnimationState.IN_HAND)
		restore_mouse_interaction(event_card)

### Awaited by the "card starts resolving" animation just before its flash. Subclasses can settle the
### card into its waiting pose here.
func settle_card_before_resolving(_event_card: EventCard) -> void:
	pass

#region STUFF THAT WORKS WELL:
func _clear_cards_not_in_hand(game_state:GameState) -> void:
	var cards_to_clear: Array[EventCard] = []
	var cards_in_hand: Array[EventCardInstance] = game_state.event_cards_hand
	for child in card_controller.get_children():
		if child is EventCard:
			if child.event_card_instance not in cards_in_hand:
				cards_to_clear.append(child)
	
	for event_card in cards_to_clear:
		event_card.free_and_unregister()
		
func _calculate_card_positions(nr_of_cards_in_hand: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if nr_of_cards_in_hand <= 0:
		return positions
	var spacing: float = clamp(
		(self.size.x - event_card_width) / max(1, nr_of_cards_in_hand - 1),
		min_spacing,
		max_spacing
	)
	var total_width: float = event_card_width
	if nr_of_cards_in_hand > 1:
		total_width += spacing * (nr_of_cards_in_hand - 1)
	var start_x: float = (self.size.x - total_width) * 0.5
	for i in range(nr_of_cards_in_hand):
		positions.append(Vector2(start_x + i * spacing, 0))

	return positions


#region Hovering-methods for event cards:
func _event_card_hovered(card_node: EventCard) -> void:
	#print("Running _event_card_hovered for card: %s"%card_node.event_card_instance.entity_id)
	if not main_game.game_state.player_can_input():
		#print("Card hovered, but player cant input")
		return
	if card_node.event_card_instance.entity_id not in card_rest_positions.keys():
		#print("Event card does not have a resting position")
		return 
	if card_node.animation_state != EventCard.AnimationState.IN_HAND:
		#print("Hovered card is not IN HAND, it is %s. Returning."%EventCard.AnimationState.keys()[card_node.animation_state])
		return
	if card_node.animation_state == EventCard.AnimationState.DRAGGING:
		return
	if card_node.animation_state == EventCard.AnimationState.DRAGGING_ARROW:
		return
	
	_restore_hovered_card()
	hovered_card = card_node
	card_node.z_index = hover_z_index
	
	var rest_position: Vector2 = card_rest_positions[card_node.event_card_instance.entity_id]
	var target_position: Vector2 = rest_position + Vector2(0, hover_raise_y)
	var animation_duration: float = hover_tween_duration#*main_game.meta_game.get_animation_speed()
	card_node.tween_to_position(target_position,animation_duration)


func _event_card_unhovered(card_node: EventCard) -> void:
	#print("Running _event_card_unhovered for card: %s"%card_node.event_card_instance.entity_id)
	if hovered_card != card_node:
		return
	if not main_game.game_state.it_is_players_turn():
		return
	if hovered_card.animation_state != EventCard.AnimationState.IN_HAND:
		return
	_restore_hovered_card()

func _restore_hovered_card()-> void:
	if hovered_card == null:
		return
	if hovered_card.event_card_instance.entity_id not in card_rest_positions.keys():
		return
	if not main_game.game_state.it_is_players_turn():
		return
	if hovered_card.animation_state != EventCard.AnimationState.IN_HAND:
		return
	#print("Running _restore_hovered_card. Hovered card: %s"%hovered_card.event_card_instance.entity_id)
	var target_position: Vector2 = card_rest_positions[hovered_card.event_card_instance.entity_id]
	var animation_duration: float = hover_tween_duration*main_game.meta_game.get_animation_speed()
	hovered_card.tween_to_position(target_position,animation_duration)
	hovered_card.z_index = 0
	hovered_card = null


#region Enabling/disabling interaction for resolving/resolved cards.
var _stored_mouse_filters: Dictionary = {}

func disable_mouse_interaction(event_card: EventCard) -> void:
	_store_and_disable_mouse_filters(event_card)

func restore_mouse_interaction(event_card: EventCard) -> void:
	_restore_mouse_filters(event_card)
	_stored_mouse_filters.clear()

func _store_and_disable_mouse_filters(node: Node) -> void:
	if node is Control:
		_stored_mouse_filters[node.get_path()] = node.mouse_filter
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_store_and_disable_mouse_filters(child)

func _restore_mouse_filters(node: Node) -> void:
	if node is Control:
		var path = node.get_path()
		if _stored_mouse_filters.has(path):
			node.mouse_filter = _stored_mouse_filters[path]
	for child in node.get_children():
		_restore_mouse_filters(child)
