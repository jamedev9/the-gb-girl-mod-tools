extends Cardgame_UI_Element
class_name OpponentsContainer

#@export var card_container: OpponentGridController
@export var card_container: EllipticalCardContainer
@export var opponent_card_scene: PackedScene = preload("res://scenes/main_cardgame/opponents/opponent_card_healthbar_v2.tscn")
@export var summon_ally_card_scene: PackedScene

var currently_focused_card: OpponentCard = null
var hover_order: Array[OpponentCard] = []
var action_getting_dragged: String = ""
var action_dragged_from_opponent_card: OpponentCard = null

const HOVER_INCREMENT: int = 2
const HOVER_SCALE: float = 1.05
const hover_z_index: int = 100
const hover_tween_duration: float = 0.15
const DROP_AWAIT_DELAY: float = 0.5

signal opponent_card_signals_action_card_was_moved(action_id: String,opponent_id: String)
signal event_card_was_dropped_in_opponents_container(event_card_instance: EventCardInstance,empty_string:String)
signal opponent_card_signals_event_card_was_dropped(event_card_instance: EventCardInstance,opponent_id: String)
signal opponent_card_signals_action_dropped_without_target(action_id: String,opponent_card: OpponentCard)
signal added_missing_opponent_cards

func _ready() -> void:
	super._ready()
	#main_game.connect("finished_playing_fragment_animations",Callable(self,"_on_fragment_animations_finished"))

func reflow_opponent_cards() -> void:
	card_container._reflow_cards()

func _on_fragment_animations_finished() -> void:
	card_container._reflow_cards()

func update_class_specific_displays(game_state: GameState) -> void:
	await _clear_defeated_opponents(game_state)
	_add_missing_opponent_cards(game_state)
	_update_display_on_cards(game_state)
	CombatProfiler.note_active_opponent_count(game_state.get_currently_active_opponents().size())
	
func _clear_defeated_opponents(game_state: GameState) -> void:
	for child in card_container.get_children():
		if child is OpponentCard:
			if not main_game.opponent_manager.opponent_id_is_valid(game_state, child.opponent_id):
				card_container.remove_opponent_card(child)
				child.free_and_unregister()
	await card_container._reflow_cards()

### Applies what the player can currently see (Status_BlindPlayer) to every card. Synchronous and
### independent of update_class_specific_displays(), which awaits card movement first.
func refresh_player_blindness(game_state: GameState) -> void:
	if not is_instance_valid(card_container):
		return
	for child in card_container.get_children():
		if child is OpponentCard:
			child.refresh_player_blindness(game_state)

func _add_missing_opponent_cards(game_state: GameState) -> void:
	if game_state.get_currently_active_opponents().size() == 0:
		emit_signal("added_missing_opponent_cards")
		return
	for opponent_id in game_state.get_currently_active_opponents():
		if not _opponent_is_already_displayed(opponent_id):
			_add_card_for_opponent(game_state, opponent_id)
	await card_container._reflow_cards()
	emit_signal("added_missing_opponent_cards")
	
func _opponent_is_already_displayed(opponent_id: String) -> bool:
	for child in card_container.get_children():
		if child is OpponentCard:
			if child.opponent_id == opponent_id:
				return true
	return false
	
func _add_card_for_opponent(game_state:GameState,opponent_id: String) -> void:
	var opponent_type: OpponentType = game_state.get_active_opponent_type(opponent_id)
	var new_card_instance: OpponentCard
	if opponent_type.summonable_ally:
		new_card_instance = summon_ally_card_scene.instantiate()
	else:
		new_card_instance = opponent_card_scene.instantiate()
	card_container.insert_new_opponent_card(new_card_instance)
	new_card_instance.display_opponent(game_state,opponent_id)
	new_card_instance.connect("action_card_dropped", Callable(self,"_relay_action_card_moved_to_opponent"))
	new_card_instance.connect("event_card_dropped",Callable(self,"_relay_event_card_dropped_on_opponent"))
	new_card_instance.connect("action_began_dragging",Callable(self,"_on_action_dragged_from_opponent"))
	new_card_instance.connect("hovered", Callable(self,"_card_hovered"))
	new_card_instance.connect("unhovered", Callable(self,"_card_unhovered"))
	focus_on_card(new_card_instance)
	

func _update_display_on_cards(game_state:GameState) -> void:
	CombatProfiler.begin_timer("update_display_on_all_cards")
	var opponent_card_count: int = 0
	for child in card_container.get_children():
		if child is OpponentCard:
			child.update_opponent_display(game_state)
			opponent_card_count += 1
	CombatProfiler.end_timer("update_display_on_all_cards", "UI_REBUILD",
		"opponent_cards=%d" % opponent_card_count)

func _relay_action_card_moved_to_opponent(action_id: String,opponent_card: OpponentCard):
	### Check if card was simply moved and dropped onto the same opponent:
	if action_id == opponent_card.active_player_action_id:
		return
	var opponent_id: String = opponent_card.opponent_id
	emit_signal("opponent_card_signals_action_card_was_moved",action_id,opponent_id)

func _relay_event_card_dropped_on_opponent(event_card_instance: EventCardInstance, opponent_id: String):
	emit_signal("opponent_card_signals_event_card_was_dropped",event_card_instance,opponent_id)
	
#region Drag and drop: Handle event cards
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data:
		return false
	if data is EventCard:
		return true
	return false
		
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is EventCard:
		emit_signal("event_card_was_dropped_in_opponents_container",data.event_card_instance,"")

#endregion 

func _on_action_dragged_from_opponent(action_id: String, opponent_card: OpponentCard) -> void:
	action_getting_dragged = action_id
	action_dragged_from_opponent_card = opponent_card

func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END:
		return
	if action_dragged_from_opponent_card == null:
		return
	
	#await _action_drop_timer_delay()
	
	if not _action_is_assigned_to_new_opponent(): # Action has been moved but not to an opponent
		_signal_to_have_action_card_returned_to_hand()
	_clear_dragging_states()

func _action_drop_timer_delay() -> void:
	var timer: Timer = Timer.new()
	add_child(timer)
	timer.autostart = true
	timer.start(DROP_AWAIT_DELAY*main_game.settings_manager.get_animation_speed())
	await timer.timeout

func _action_is_assigned_to_new_opponent() -> bool:
	var opponent_with_action: String = main_game.game_state.get_opponent_with_action(action_getting_dragged)
	if not action_dragged_from_opponent_card:
		return false
	if opponent_with_action == action_dragged_from_opponent_card.opponent_id:
		return false 
	if opponent_with_action != "":
		return true 
	return false

func _signal_to_have_action_card_returned_to_hand() -> void:
	emit_signal("opponent_card_signals_action_dropped_without_target",action_getting_dragged,action_dragged_from_opponent_card)

func _clear_dragging_states() -> void:
	action_getting_dragged = ""
	action_dragged_from_opponent_card = null

func _on_elliptical_card_container_request_opponent_card_moving_sound_effect() -> void:
	main_game.sound_manager.play_sound_effect(SoundManager.SoundEffects.OPPONENT_CARD_MOVING)

#region Hovering:
func _card_hovered(opponent_card: OpponentCard) -> void:
	focus_on_card(opponent_card)
	
#func focus_on_card(opponent_card: OpponentCard) -> void:
	#_unfocus_current_focused_card()
	#currently_focused_card = opponent_card
	#hover_order.erase(opponent_card)
	#hover_order.append(opponent_card)
	#_update_z_indices()
	#AnimationHelper_ScaleNodeWithTween.scale_node(
		#opponent_card,Vector2(HOVER_SCALE,HOVER_SCALE),hover_tween_duration)

func focus_on_card(opponent_card: OpponentCard) -> void:
	_unfocus_current_focused_card()
	currently_focused_card = opponent_card
	hover_order.erase(opponent_card)
	hover_order.append(opponent_card)
	_update_z_indices()
	opponent_card.get_parent().move_child(opponent_card, -1) # Move to top of tree order too
	AnimationHelper_ScaleNodeWithTween.scale_node(
		opponent_card, Vector2(HOVER_SCALE, HOVER_SCALE), hover_tween_duration)

func _unfocus_current_focused_card() -> void:
	if not currently_focused_card:
		return
	_unfocus_card(currently_focused_card)

func _card_unhovered(opponent_card: OpponentCard) -> void:
	_unfocus_card(opponent_card)
	
func _unfocus_card(opponent_card: OpponentCard) -> void:
	if opponent_card != currently_focused_card:
		return
	if not opponent_card:
		return
	currently_focused_card = null
	AnimationHelper_ScaleNodeWithTween.scale_node(
		opponent_card,Vector2.ONE,hover_tween_duration)

func _update_z_indices() -> void:
	for i in hover_order.size():
		if not hover_order[i]:
			continue
		hover_order[i].z_index = i

func reset_hovering() -> void:
	hover_order.clear()

#endregion

func get_energy_upkeep_for_visuals() -> int:
	var upkeep: int = 0
	for card in card_container.get_children():
		if card is OpponentCard:
			var assigned_action_id: String = card.active_player_action_id
			var assigned_action: PlayerAction = AutoloadDatabase.get_player_action_by_id(assigned_action_id)
			if not assigned_action:
				continue
			upkeep += assigned_action.energy_per_round
	
	return upkeep	
	
