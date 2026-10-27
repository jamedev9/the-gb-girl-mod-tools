extends Cardgame_UI_Element
class_name FloatingPlayerHand
### This node owns the Event Card nodes.

@export var card_controller: Control = self

@export var card_scene: PackedScene = load("res://scenes/main_cardgame/event_cards/event_card.tscn")

@export var event_card_width: float = 230
@export var event_card_height: float = 325
### How far a targeted card (dragged with the arrow, so it stays in the hand) pops up when it starts resolving. It waits up
### there, and so do the copies played with it (Ctrl).
@export var targeted_card_resolve_lift: float = 200.0

### Ctrl drag: the copies played with the dragged card wait in a queue under it (see the "Play every copy (Ctrl)" region).
@export_group("Play every copy (Ctrl)")
### Where the first card waiting in the queue sits relative to the card above it (right and down), so the stack fans out
### diagonally. The cards after it sit closer and closer (see queued_card_one_pixel_from).
@export var queued_card_offset: Vector2 = Vector2(4.0, 10.0)
### From this card in the queue on (1 = the first card under the top one), each card sits only 1 px from the one above it.
### Before it the gap shrinks from queued_card_offset a little less each card (geometrically, per axis), so a long stack
### stays compact instead of running off in a straight line.
@export var queued_card_one_pixel_from: int = 10
### How long the copies take to fly to their place in the queue.
@export var queued_card_move_duration: float = 0.3
@export_group("")

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
	_forget_freed_group_hovered_cards()
	for card in cards_in_hand:
		if card.animation_state == EventCard.AnimationState.DRAWING:
			continue
		if card in group_hovered_cards:
			_pose_group_hovered_card(card) # stays lifted, at its new spot
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
				_forget_stored_mouse_filters(card)
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
	_update_group_hover() # with Ctrl held, the copies now follow the dragged card
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
	group_hovered_cards.clear()
	_drag_group_play = null
	_resolution_queues.clear()
	_stored_mouse_filters.clear()



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
		### Normally finished by the handler of the dragged card above; this only catches a drag whose card was lost on the way.
		_finish_group_play(null, Vector2.ZERO)

func _handle_event_card_that_was_arrow_targeting(event_card: EventCard) -> void:
	_clear_hovered_card()
	_clear_dragged_card()
	main_game.sound_manager.play_sound_effect(SoundManager.SoundEffects.EVENT_CARD_END_DRAGGING)
	event_card.change_animation_state(EventCard.AnimationState.RESOLVING)
	_finish_group_play(event_card, _get_targeted_card_waiting_position(event_card))
	await _wait_for_event_card_resolution(event_card)

### Where a targeted card (dragged with the arrow, so it never left the hand) waits while it resolves: targeted_card_resolve_lift
### above where it is. Subclasses that also reshape it (_settle_card_into_waiting_pose) return where it ends up.
func _get_targeted_card_waiting_position(event_card: EventCard) -> Vector2:
	return event_card.position + Vector2(0.0, -targeted_card_resolve_lift)

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
		_finish_group_play(event_card, resting_drop_position)

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

### Awaited by the "card starts resolving" animation just before its flash. A copy waiting in the queue under a played card
### (Ctrl drag) resolves right where it is; any other card settles into its waiting pose (_settle_card_into_waiting_pose).
func settle_card_before_resolving(event_card: EventCard) -> void:
	if _is_card_queued_under_another(event_card):
		return
	await _settle_card_into_waiting_pose(event_card)

### Moves the card into the pose it waits in while it resolves: a targeted card pops up to _get_targeted_card_waiting_position()
### (a Ctrl queue under it was placed from that spot, so an override must end there too). The extra z keeps it above any
### hovered card in the hand (a card topping a queue keeps the queue's higher z). The tween is visual only; the wait is a
### timer, so the animation queue can't hang.
func _settle_card_into_waiting_pose(event_card: EventCard) -> void:
	if not _is_targeted_card_waiting_to_resolve(event_card):
		return
	var duration: float = hover_tween_duration * main_game.meta_game.get_animation_speed()
	event_card.z_index = maxi(event_card.z_index, hover_z_index + 1)
	event_card.tween_to_position(_get_targeted_card_waiting_position(event_card), duration)
	await get_tree().create_timer(duration).timeout

func _is_targeted_card_waiting_to_resolve(event_card: EventCard) -> bool:
	if not is_instance_valid(event_card):
		return false
	if not event_card.event_card_instance.card_requires_targeted_opponent():
		return false
	return event_card.animation_state == EventCard.AnimationState.RESOLVING

#region STUFF THAT WORKS WELL:
func _clear_cards_not_in_hand(game_state:GameState) -> void:
	var cards_to_clear: Array[EventCard] = []
	var cards_in_hand: Array[EventCardInstance] = game_state.event_cards_hand
	for child in card_controller.get_children():
		if child is EventCard:
			if child.event_card_instance not in cards_in_hand:
				cards_to_clear.append(child)
	
	for event_card in cards_to_clear:
		_forget_stored_mouse_filters(event_card)
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
	if hovered_card in group_hovered_cards:
		### Still lifted as a copy of the dragged card (Ctrl is held during a drag).
		var group_card: EventCard = hovered_card as EventCard
		hovered_card = null
		_pose_group_hovered_card(group_card)
		return
	#print("Running _restore_hovered_card. Hovered card: %s"%hovered_card.event_card_instance.entity_id)
	var target_position: Vector2 = card_rest_positions[hovered_card.event_card_instance.entity_id]
	var animation_duration: float = hover_tween_duration*main_game.meta_game.get_animation_speed()
	hovered_card.tween_to_position(target_position,animation_duration)
	hovered_card.z_index = 0
	hovered_card = null


#region Play every copy (Ctrl)
### While Ctrl is held, the other cards of the hovered card's type (of the dragged card's, during a drag) are hovered along
### with it; pressing or releasing Ctrl at any time lifts or lowers them. The copies lifted when the dragged card is dropped
### are played after it (EventCardGroupPlay, MainCardgame._event_card_dropped): the ones that were played fly to where it
### waits and queue up under it, the next one to resolve on top. They move only that once: each resolves where it landed
### (settle_card_before_resolving). Copies that weren't played go back into the hand.

### Above a hovered card (hover_z_index) and above a targeted card waiting to resolve (hover_z_index + 1).
const QUEUED_CARD_TOP_Z_INDEX: int = 200

### The copies hovered along with hovered_card or dragged_card (never that card itself).
var group_hovered_cards: Array[EventCard] = []
### During a drag with copies lifted: the dragged card and those copies, also set on the main game. Null otherwise.
var _drag_group_play: EventCardGroupPlay = null

### Cards resolving one after another from the same spot: the card on top resolves first.
class ResolutionQueue:
	var top_position: Vector2
	var cards: Array[EventCard] = []

var _resolution_queues: Array = [] # ResolutionQueue

static func is_play_every_copy_key_held() -> bool:
	return Input.is_key_pressed(KEY_CTRL)

func _process(_delta: float) -> void:
	_update_group_hover()

func _update_group_hover() -> void:
	_set_group_hovered_cards(_get_cards_to_group_hover())
	_update_drag_group_play()

func _get_cards_to_group_hover() -> Array[EventCard]:
	var cards: Array[EventCard] = []
	if not is_play_every_copy_key_held():
		return cards
	### During a drag the copies follow the dragged card (nothing is hovered then), otherwise the hovered card.
	var focus_card: EventCard = null
	if is_instance_valid(dragged_card):
		focus_card = dragged_card
	elif is_instance_valid(hovered_card):
		focus_card = hovered_card as EventCard
		if focus_card != null and focus_card.animation_state != EventCard.AnimationState.IN_HAND:
			return cards
	if focus_card == null:
		return cards
	if not main_game.game_state or not main_game.game_state.player_can_input():
		return cards
	return _get_copies_in_hand(focus_card)

### During a drag, the main game always knows the copies lifted right now: those are played if the card is dropped now.
func _update_drag_group_play() -> void:
	var copies: Array[EventCardInstance] = []
	if is_instance_valid(dragged_card):
		for card in group_hovered_cards:
			copies.append(card.event_card_instance)
	if copies.is_empty():
		_set_drag_group_play(null)
		return
	if _drag_group_play != null and _drag_group_play.dragged_card == dragged_card.event_card_instance \
			and _drag_group_play.copies == copies:
		return
	var group_play: EventCardGroupPlay = EventCardGroupPlay.new()
	group_play.dragged_card = dragged_card.event_card_instance
	group_play.copies = copies
	_set_drag_group_play(group_play)

### How many cards dropping card_instance would play right now, for the previews (pleasure bars, Energy cost, the card's own
### numbers): 1, or while copies are lifted with it (Ctrl), the card plus as many copies as the player's current Energy pays for at
### the card's current cost, like MainCardgame._play_copies_of_dropped_card(), which stops at the first copy it can't pay. Energy a
### card gives back is not counted (decided 2026-10-27). Never below 1: a card the player can't pay shows what one card does, as
### without Ctrl. card_instance may be any of the lifted cards (the one under the mouse can be a lifted copy).
func get_play_count(card_instance: EventCardInstance) -> int:
	_forget_freed_group_hovered_cards()
	if group_hovered_cards.is_empty() or not card_instance or not _is_card_in_lifted_group(card_instance):
		return 1
	var card_count: int = group_hovered_cards.size() + 1
	var game_state: GameState = main_game.game_state
	var cost: int = EventCardDefinition.get_energy_cost_of_playing_card(game_state, card_instance.card_id)
	if cost <= 0:
		return card_count
	var affordable_count: int = floori(float(PlayerEntity.new(game_state).get_player_energy()) / float(cost))
	return clampi(affordable_count, 1, card_count)

### get_play_count() from the running game's hand, for code that only has the main game: 1 without a hand. The main game is checked
### by its properties, never by naming its class: this script is in the mod-tools export, which leaves the main game out.
static func get_play_count_in_game(main_game: Node, card_instance: EventCardInstance) -> int:
	if not is_instance_valid(main_game) or not ("entity_registry" in main_game) or not main_game.entity_registry:
		return 1
	var hand: FloatingPlayerHand = main_game.entity_registry.get_control_node("event_card_hand") as FloatingPlayerHand
	if hand == null:
		return 1
	return hand.get_play_count(card_instance)

### The card being dragged, or the hovered one, or one of the copies lifted with it.
func _is_card_in_lifted_group(card_instance: EventCardInstance) -> bool:
	var focus_card: Control = dragged_card if is_instance_valid(dragged_card) else hovered_card
	if is_instance_valid(focus_card) and focus_card is EventCard and focus_card.event_card_instance == card_instance:
		return true
	for card in group_hovered_cards:
		if card.event_card_instance == card_instance:
			return true
	return false

func _set_drag_group_play(group_play: EventCardGroupPlay) -> void:
	if group_play == _drag_group_play:
		return
	_drag_group_play = group_play
	if "event_card_group_play" in main_game: ### not "is MainCardgame": see get_play_count_in_game()
		main_game.event_card_group_play = group_play

### The other cards of card's type resting in the hand that could be dragged, left to right (the node order is the layout order).
func _get_copies_in_hand(card: EventCard) -> Array[EventCard]:
	var copies: Array[EventCard] = []
	for child in card_controller.get_children():
		var other_card: EventCard = child as EventCard
		if other_card == null or other_card == card or other_card.is_queued_for_deletion():
			continue
		if other_card.animation_state != EventCard.AnimationState.IN_HAND or other_card.all_actions_are_disabled:
			continue
		if not other_card.event_card_instance or other_card.event_card_instance.card_id != card.event_card_instance.card_id:
			continue
		if not card_rest_positions.has(other_card.event_card_instance.entity_id):
			continue
		copies.append(other_card)
	return copies

func _set_group_hovered_cards(cards: Array[EventCard]) -> void:
	_forget_freed_group_hovered_cards()
	if cards == group_hovered_cards:
		return
	var previous_cards: Array[EventCard] = group_hovered_cards
	group_hovered_cards = cards
	for card in previous_cards:
		if card not in cards and card != hovered_card and card != dragged_card:
			_unpose_group_hovered_card(card)
	for card in cards:
		if card not in previous_cards:
			_pose_group_hovered_card(card)

### A card can be freed while lifted (it left the hand). Read by index into an untyped variable: a freed object must never be
### assigned to an EventCard-typed one.
func _forget_freed_group_hovered_cards() -> void:
	var valid_cards: Array[EventCard] = []
	for i in group_hovered_cards.size():
		var card: Variant = group_hovered_cards[i]
		if is_instance_valid(card):
			valid_cards.append(card)
	if valid_cards.size() != group_hovered_cards.size():
		group_hovered_cards = valid_cards

### Lifted like the hovered card, just under it. Subclasses pose it like their hovered card.
func _pose_group_hovered_card(card: EventCard) -> void:
	var id: String = card.event_card_instance.entity_id
	if not card_rest_positions.has(id):
		return
	card.z_index = hover_z_index - 1
	card.tween_to_position(card_rest_positions[id] + Vector2(0, hover_raise_y), hover_tween_duration)

func _unpose_group_hovered_card(card: EventCard) -> void:
	if card.animation_state != EventCard.AnimationState.IN_HAND:
		return
	card.z_index = 0
	var id: String = card.event_card_instance.entity_id
	if card_rest_positions.has(id):
		card.tween_to_position(card_rest_positions[id], hover_tween_duration * main_game.meta_game.get_animation_speed())

### Called when the drag ends, after the drop (which already played the cards). lead_card is the dragged card (null if it was
### lost) and waiting_position the spot it waits at while it resolves (this node's coordinates). The copies that were played
### queue up under it; the others go back into the hand.
func _finish_group_play(lead_card: EventCard, waiting_position: Vector2) -> void:
	var group_play: EventCardGroupPlay = _drag_group_play
	if group_play == null:
		return
	_set_drag_group_play(null)
	_forget_freed_group_hovered_cards()
	var copies: Array[EventCard] = []
	copies.append_array(group_hovered_cards)
	group_hovered_cards.clear()
	var queued_cards: Array[EventCard] = []
	if is_instance_valid(lead_card):
		for played_copy in group_play.played_copies:
			for card in copies:
				if card.event_card_instance == played_copy:
					queued_cards.append(card)
	for card in copies:
		if card not in queued_cards:
			_unpose_group_hovered_card(card)
	if queued_cards.is_empty():
		return
	_queue_cards_under_card(lead_card, waiting_position, queued_cards)
	_shift_cards_in_hand_to_correct_position() # the hand closes the gaps they left

func _queue_cards_under_card(lead_card: EventCard, top_position: Vector2, cards: Array[EventCard]) -> void:
	_forget_finished_resolution_queues()
	var queue: ResolutionQueue = ResolutionQueue.new()
	queue.top_position = top_position
	queue.cards.append(lead_card)
	queue.cards.append_array(cards)
	_resolution_queues.append(queue)
	for card in cards:
		disable_mouse_interaction(card)
		card.change_animation_state(EventCard.AnimationState.RESOLVING)
	_place_queued_cards(queue)

### True for a copy waiting under the card it was played with (not for that card itself).
func _is_card_queued_under_another(event_card: EventCard) -> bool:
	_forget_finished_resolution_queues()
	for i in _resolution_queues.size():
		var queue: ResolutionQueue = _resolution_queues[i]
		if queue.cards.find(event_card) > 0:
			return true
	return false

### The copies fly to their place in the stack once and stay there until they resolve. The dragged card on top is already
### on its way to its spot (or is settled there by settle_card_before_resolving), so only its z changes.
func _place_queued_cards(queue: ResolutionQueue) -> void:
	var duration: float = queued_card_move_duration * main_game.meta_game.get_animation_speed()
	for i in queue.cards.size():
		if not is_instance_valid(queue.cards[i]):
			continue
		var card: EventCard = queue.cards[i]
		card.z_index = QUEUED_CARD_TOP_Z_INDEX - i # each card in front of the ones under it
		if i == 0:
			continue
		_pose_card_in_queue(card, queue.top_position + _get_queued_card_offset(i), duration)

### Where the card_number-th card under the top one sits relative to it: the sum of the gaps above it.
func _get_queued_card_offset(card_number: int) -> Vector2:
	var offset: Vector2 = Vector2.ZERO
	for gap_number in range(1, card_number + 1):
		offset += Vector2(_get_queued_card_gap(queued_card_offset.x, gap_number), _get_queued_card_gap(queued_card_offset.y, gap_number))
	return offset

### The gap_number-th gap along one axis: first_gap for the first, 1 px from queued_card_one_pixel_from on, and in between
### first_gap times the same ratio each card, chosen so it reaches exactly 1 px there. A gap of 1 px or less never shrinks.
func _get_queued_card_gap(first_gap: float, gap_number: int) -> float:
	var gap_size: float = absf(first_gap)
	if gap_size <= 1.0:
		return first_gap
	if gap_number >= queued_card_one_pixel_from:
		return signf(first_gap)
	var ratio: float = pow(1.0 / gap_size, 1.0 / float(queued_card_one_pixel_from - 1))
	return signf(first_gap) * gap_size * pow(ratio, gap_number - 1)

### Subclasses also reset the card's rotation and scale.
func _pose_card_in_queue(card: EventCard, target_position: Vector2, duration: float) -> void:
	card.tween_to_position_and_return_tween(target_position, duration)

### Drops the queues whose cards have all resolved. A resolved card is freed once it reached the discard pile, so the cards
### are read by index into an untyped variable (see _forget_freed_group_hovered_cards).
func _forget_finished_resolution_queues() -> void:
	var waiting_queues: Array = []
	for i in _resolution_queues.size():
		var queue: ResolutionQueue = _resolution_queues[i]
		for card_index in queue.cards.size():
			var card: Variant = queue.cards[card_index]
			if is_instance_valid(card) and card.animation_state == EventCard.AnimationState.RESOLVING:
				waiting_queues.append(queue)
				break
	_resolution_queues = waiting_queues
#endregion


#region Enabling/disabling interaction for resolving/resolved cards.
### Per card (entity id), since several can be disabled at once (a Ctrl drag): node path -> its mouse filter.
var _stored_mouse_filters: Dictionary = {}

func disable_mouse_interaction(event_card: EventCard) -> void:
	var stored_filters: Dictionary = {}
	_store_and_disable_mouse_filters(event_card, stored_filters)
	_stored_mouse_filters[event_card.event_card_instance.entity_id] = stored_filters

func restore_mouse_interaction(event_card: EventCard) -> void:
	var entity_id: String = event_card.event_card_instance.entity_id
	_restore_mouse_filters(event_card, _stored_mouse_filters.get(entity_id, {}))
	_stored_mouse_filters.erase(entity_id)

func _forget_stored_mouse_filters(event_card: EventCard) -> void:
	if event_card.event_card_instance:
		_stored_mouse_filters.erase(event_card.event_card_instance.entity_id)

func _store_and_disable_mouse_filters(node: Node, stored_filters: Dictionary) -> void:
	if node is Control:
		stored_filters[node.get_path()] = node.mouse_filter
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_store_and_disable_mouse_filters(child, stored_filters)

func _restore_mouse_filters(node: Node, stored_filters: Dictionary) -> void:
	if node is Control:
		var path = node.get_path()
		if stored_filters.has(path):
			node.mouse_filter = stored_filters[path]
	for child in node.get_children():
		_restore_mouse_filters(child, stored_filters)
