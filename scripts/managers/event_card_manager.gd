extends GameManager
class_name EventCardManager

const GAME_TITLE: String = "The Gangbang Girl"
const DEVELOPER: String = "gb_girl_dev"
const COPYRIGHT: String = "2026"

const CARD_DRAW_DELAY: float = 0.2

signal event_card_deck_is_empty
signal card_was_drawn(event_card_instance:EventCardInstance)

var card_instance_counter: int = 1

#region Queries:
func get_no_of_cards_in_hand(game_state:GameState,card_id: String) -> int:
	var count: int = 0
	for card_instance in game_state.event_cards_hand:
		if card_instance.card_id == card_id:
			count += 1
	return count

#endregion


#region Mutate state: Only main can call
# Deck convention:
# - End of array = top of deck
# - pop_back() draws
# - append() adds to top
func _add_card_instances_to_start_deck_(game_state: GameState) -> void:
	for event_card_id in game_state.event_cards_starting_deck.keys():
		for i in game_state.event_cards_starting_deck[event_card_id]:
			var card_def: EventCardDefinition = AutoloadDatabase.get_event_card_def_by_id(event_card_id)
			var permanence: CardInstance.CardPermanence
			match card_def.once_per_game:
				true:
					permanence = CardInstance.CardPermanence.ONCE_PER_GAME
				false:
					permanence = CardInstance.CardPermanence.PERMANENT
			if not card_def.always_in_opening_hand:
				var new_card_instance: EventCardInstance = _create_new_event_card_instance(
					game_state,event_card_id,permanence)
				_add_card_to_deck_(game_state,new_card_instance)
			else:
				if event_card_id not in game_state.event_cards_starting_hand.keys():
					game_state.event_cards_starting_hand[event_card_id] = 1
				else:
					game_state.event_cards_starting_hand[event_card_id] += 1
			
func _add_card_instances_to_opening_hand_(game_state: GameState) -> void:
	for event_card_id in game_state.event_cards_starting_hand.keys():
		for i in game_state.event_cards_starting_hand[event_card_id]:
			var card_def: EventCardDefinition = AutoloadDatabase.get_event_card_def_by_id(event_card_id)
			var permanence: CardInstance.CardPermanence
			match card_def.once_per_game:
				true:
					permanence = CardInstance.CardPermanence.ONCE_PER_GAME
				false:
					permanence = CardInstance.CardPermanence.PERMANENT
			
			var new_card_instance: EventCardInstance = _create_new_event_card_instance(
				game_state,	event_card_id,permanence)
			new_card_instance.card_state = EventCardInstance.CardState.IN_HAND
			_add_single_card_to_hand_(game_state,new_card_instance)
				
			var fragment: LogFragment = LogFragment.make_new_log_fragment(
			"player_drew_an_event_card_from_deck",
			{"event_card_instance":new_card_instance,"card_type_id":new_card_instance.card_id},
			[LogFragment.LogTags.EVENT_CARD_ADDED_TO_HAND],
			null,true)
			main_game.request_adding_fragment_to_log(fragment)
			

func _shuffle_deck_(game_state:GameState) -> void:
	game_state.event_cards_deck.shuffle()
	var log_fragment: LogFragment = LogFragment.make_new_log_fragment(
		"event_card_deck_shuffled",
		{},
		[LogFragment.LogTags.EVENT_CARD_DECK_SHUFFLED]
	)
	main_game.request_adding_fragment_to_log(log_fragment)


func _draw_to_hand_size_(game_state:GameState) -> void:
	var nr_cards_in_hand: int = game_state.event_cards_hand.size()
	var hand_size: int = game_state.opening_hand_size
	var nr_temporary_cards: int = 0
	for card in game_state.event_cards_hand:
		if card.permanence == CardInstance.CardPermanence.TEMPORARY:
			nr_temporary_cards +=1
	var missing_cards: int = hand_size-nr_cards_in_hand+nr_temporary_cards
	_draw_n_cards_(game_state,missing_cards)
	
func _draw_n_cards_(game_state: GameState, n: int) -> void:
	for i in range(0,n):
		_draw_card_(game_state)

func _draw_card_(game_state: GameState) -> void:
	if game_state.event_cards_deck.size() == 0:
		emit_signal("event_card_deck_is_empty")
	var event_card_instance: EventCardInstance = game_state.event_cards_deck.back()
	if not event_card_instance:
		return
	if event_card_instance.card_state != EventCardInstance.CardState.IN_DRAW_PILE:
		push_error("Trying to play card %s, but it has wrong has wrong CardState: %s"%[
			event_card_instance.entity_id,
			EventCardInstance.CardState.keys()[event_card_instance.card_state]])
		return
	game_state.event_cards_hand.append(event_card_instance)
	game_state.event_cards_deck.erase(event_card_instance)
	event_card_instance.card_state = EventCardInstance.CardState.IN_HAND
	emit_signal("card_was_drawn",event_card_instance)
	var log_fragment: LogFragment = LogFragment.make_new_log_fragment(
		"player_drew_an_event_card_from_deck",
		{"event_card_instance":event_card_instance,"card_type_id":event_card_instance.card_id},
		[LogFragment.LogTags.PLAYER_DREW_EVENT_CARD,LogFragment.LogTags.EVENT_CARD_ADDED_TO_HAND],
		null,true
	)
	main_game.request_adding_fragment_to_log(log_fragment)


func _shuffle_discard_into_bottom_of_deck_(game_state: GameState) -> void:
	#print("Before shuffle")
	#debug_check_all_event_cards(game_state)
	var cards_to_add: Array[EventCardInstance] = game_state.event_cards_discard.duplicate()
	cards_to_add.shuffle()
	for card_instance in cards_to_add:
		if card_instance_is_permanent(card_instance):
			_add_card_to_deck_(game_state,card_instance)
	#print("before empty discard:")
	#debug_check_all_event_cards(game_state)
	_empty_discard_pile_(game_state)
	#print("after empty discard")
	#debug_check_all_event_cards(game_state)
	main_game.sound_manager.play_sound_effect(SoundManager.SoundEffects.CARD_SHUFFLE)

func _discard_n_cards_randomly_(game_state:GameState, effect_context: EffectContext) -> void:
	var nr_of_cards: int = effect_context.discard_n_randomly
	var card_causing_discard_effect: EventCardInstance = effect_context.event_card_instance
	var hand: Array = game_state.event_cards_hand
	if hand.is_empty() or nr_of_cards <= 0:
		return
	
	var cards_that_can_be_discarded: Array = []
	for card_instance in hand:
		if card_instance == card_causing_discard_effect:
			continue
		if card_instance.is_immune_to_random_discard():
			continue
		cards_that_can_be_discarded.append(card_instance)

	var max_cards_that_can_be_discarded: int = cards_that_can_be_discarded.size() #Hand size minus the resolving card, minus any cards immune to random discard
	
	var discard_count: int = min(nr_of_cards, max_cards_that_can_be_discarded)
	var discard_list: Array[EventCardInstance] = []
	
	for i in discard_count:
		var random_index: int = randi_range(0, cards_that_can_be_discarded.size() - 1)
		var card_instance: EventCardInstance = cards_that_can_be_discarded[random_index]
		discard_list.append(card_instance)
		cards_that_can_be_discarded.erase(card_instance)
	
	for card in discard_list:
		_discard_card_(game_state,card)

func _discard_entire_hand_(game_state:GameState, effect_context: EffectContext) -> void:
	var card_causing_discard_effect: EventCardInstance = effect_context.event_card_instance
	var hand: Array = game_state.event_cards_hand.duplicate()
	for card_instance in hand:
		if card_instance == card_causing_discard_effect:
			continue
		_discard_card_(game_state,card_instance)

func _empty_discard_pile_(game_state: GameState) -> void:
	game_state.event_cards_discard.clear()
	
func _add_cards_to_hand_(game_state: GameState, cards: Array[EventCardInstance]) -> void:
	for card_instance in cards:
		_add_single_card_to_hand_(game_state,card_instance)

func _add_single_card_to_hand_(game_state: GameState, event_card_instance: EventCardInstance) -> void:
	game_state.event_cards_hand.append(event_card_instance)
	event_card_instance.card_state = EventCardInstance.CardState.IN_HAND
	main_game.request_drawing_event_card(event_card_instance)
	#main_game.floating_player_event_cards.draw_card(event_card_instance)
	var fragment: LogFragment = LogFragment.make_new_log_fragment(
		"event_card_added_to_players_hand",
		{"event_card_instance":event_card_instance,"card_type_id":event_card_instance.card_id},
		[LogFragment.LogTags.EVENT_CARD_ADDED_TO_HAND],
		null,true)
	main_game.request_adding_fragment_to_log(fragment)
	#await main_game._step_delay(game_state)

func _add_multiple_cards_to_deck_(game_state: GameState, cards: Array[EventCardInstance]) -> void:
	for card_instance in cards:
		_add_card_to_deck_(game_state,card_instance)

func _should_return_card_to_deck(game_state: GameState, card_instance: EventCardInstance) -> bool:
	if card_instance.permanence == CardInstance.CardPermanence.PERMANENT:
		return true
	if card_instance.permanence == CardInstance.CardPermanence.ONCE_PER_GAME:
		if not game_state.encounter_report:
			return false
		return card_instance.card_id not in game_state.encounter_report.get_played_event_cards().keys()
	return false

func _add_card_to_deck_(game_state: GameState, card_instance: EventCardInstance) -> void:
	if not _should_return_card_to_deck(game_state, card_instance):
		return
	game_state.event_cards_deck.append(card_instance)
	card_instance.card_state = EventCardInstance.CardState.IN_DRAW_PILE
	var fragment: LogFragment = LogFragment.make_new_log_fragment(
		"event_card_added_to_deck",
		{"card_instance":card_instance,"card_id":card_instance.card_id},
		[LogFragment.LogTags.EVENT_CARD_ADDED_TO_DECK])
	main_game.request_adding_fragment_to_log(fragment)

#func _add_card_to_deck_(game_state: GameState, card_instance: EventCardInstance) -> void:
	#if card_instance_is_permanent(card_instance):
		#game_state.event_cards_deck.append(card_instance)
		#card_instance.card_state = EventCardInstance.CardState.IN_DRAW_PILE
		#var fragment: LogFragment = LogFragment.make_new_log_fragment(
			#"event_card_added_to_deck",
			#{"card_instance":card_instance,"card_id":card_instance.card_id},
			#[LogFragment.LogTags.EVENT_CARD_ADDED_TO_DECK])
		#main_game.request_adding_fragment_to_log(fragment)

func _discard_card_(game_state: GameState, card_instance: EventCardInstance) -> void:
	### This method is for discard-effects. For played cards, use only _move_card_from_hand_to_discard_()
	var event_card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[card_instance.card_id]
	_move_card_from_hand_to_discard_(game_state,card_instance)
	var fragment: LogFragment = LogFragment.make_new_log_fragment(
		"player_discarded_event_card",
		{"event_card_def":event_card_def,"card_type_id":event_card_def.card_type_id,
		"card_instance_entity_id":card_instance.entity_id,
		"event_card_instance":card_instance},
		[LogFragment.LogTags.EVENT_CARD_DISCARDED],
		null,true)
	main_game.request_adding_fragment_to_log(fragment)

func _move_card_from_hand_to_discard_(game_state: GameState, card_instance: EventCardInstance) -> void:
	if card_instance.card_state == EventCardInstance.CardState.RESOLVING:
		push_error("Attempted to discard resolving card: %s" % card_instance.entity_id)
		return
	card_instance.card_state = EventCardInstance.CardState.IN_DISCARD_PILE
	game_state.event_cards_hand.erase(card_instance)
	game_state.event_cards_discard.append(card_instance)
	if card_instance.permanence != CardInstance.CardPermanence.PERMANENT and card_instance.permanence != CardInstance.CardPermanence.ONCE_PER_GAME:
		#print("Erasing card %s that is not permanent or once per game "%card_instance.card_id)
		game_state.event_cards_discard.erase(card_instance)
	
	if card_instance.permanence != CardInstance.CardPermanence.ONCE_PER_GAME:
		#print("Discarding card %s that is not once per game, leaving it in the dicsard pile."%card_instance.card_id)
		return
	if card_instance.card_id in game_state.encounter_report.get_played_event_cards().keys():
		#print("Erasing card %s from discard pile."%card_instance.card_id)
		game_state.event_cards_discard.erase(card_instance)


### Replaces the old hardcoded "discard TEMPORARY-permanence cards" sweep with a
### general per-instance timer (EventCardInstance.turns_until_discard), so any card
### type can opt into end-of-turn expiry with its own duration - not just one fixed
### permanence category. The TEMPORARY check is kept alongside it as a safety net
### for any card that still relies on permanence alone rather than the timer.
func _process_end_of_turn_card_expiry_(game_state: GameState) -> void:
	var cards_to_discard: Array[EventCardInstance] = []
	for card_instance in game_state.event_cards_hand:
		if card_instance.permanence == CardInstance.CardPermanence.TEMPORARY:
			cards_to_discard.append(card_instance)
			continue
		if card_instance.turns_until_discard < 0:
			continue
		if card_instance.turns_until_discard == 0:
			cards_to_discard.append(card_instance)
		else:
			card_instance.turns_until_discard -= 1
	for card in cards_to_discard:
		_discard_card_(game_state,card)


#endregion
func _create_new_event_card_instance(
	game_state: GameState,
	card_id: String,
	permanence: CardInstance.CardPermanence,
	turns_until_discard: int = -1) -> EventCardInstance:
	var card_instance: EventCardInstance = EventCardInstance.new()
	card_instance.card_id = card_id
	card_instance.permanence = permanence
	card_instance.entity_id = card_id+str(card_instance_counter)
	card_instance.turns_until_discard = turns_until_discard
	card_instance_counter += 1
	game_state.register_event_card_instance(card_instance)
	return card_instance

#func _create_new_event_card_instance(card_id: String,permanence: CardInstance.CardPermanence) -> EventCardInstance:
	#var card_instance: EventCardInstance = EventCardInstance.new()
	#card_instance.card_id = card_id
	#card_instance.permanence = permanence
	#card_instance.entity_id = card_id+str(card_instance_counter)
	#card_instance_counter += 1
	#return card_instance

#region Validation functions:

func card_instance_is_in_players_hand(game_state: GameState, event_card_instance: EventCardInstance) -> bool:
	return event_card_instance in game_state.event_cards_hand

func card_instance_is_permanent(card_instance: EventCardInstance) -> bool:
	return card_instance.permanence == CardInstance.CardPermanence.PERMANENT

#endregion

func clear_missing_cards(game_state: GameState) -> void:
	var null_values: Array = []
	for i in game_state.event_cards_hand.size():
		if game_state.event_cards_hand == null:
			#print("Found null card instance at index %s"%i)
			null_values.append(game_state.event_cards_hand[i])

	for value in null_values:
		game_state.event_cards_hand.erase(value)


#endregion
#region Action Combo Cards
func get_valid_combos_based_on_active_actions(
	active_action_ids: Array[String]) -> Array[ComboEventCardDefinition]:
	var valid_combos: Array[ComboEventCardDefinition] = []
	
	for card_id in AutoloadDatabase.event_cards_by_id.keys():
		var card_definition = AutoloadDatabase.event_cards_by_id[card_id]
		if card_definition is not ComboEventCardDefinition:
			continue
	#for combo_definition in game_state.combo_definitions:
		var active_actions_match_combo: bool = true
		for required_action_id in card_definition.required_action_ids:
			if required_action_id not in active_action_ids:
				active_actions_match_combo = false
				break
		if active_actions_match_combo:
			valid_combos.append(card_definition)
	return valid_combos

func sort_combos_by_priority(_game_state: GameState,valid_combos: Array[ComboEventCardDefinition]) -> Array[ComboEventCardDefinition]:
	var priority_sorted_valid_combos: Array[ComboEventCardDefinition] = valid_combos
	#push_error("sort_combos_by_priority")
	priority_sorted_valid_combos.sort_custom(func(a, b):
		if a.priority != b.priority:
			return a.priority > b.priority
		return a.required_action_ids.size() > b.required_action_ids.size()
	)
	return priority_sorted_valid_combos

func remove_overlapping_combos(_game_state: GameState,priority_sorted_valid_combos:Array[ComboEventCardDefinition]) -> Array[ComboEventCardDefinition]:
	var non_overlapping_combos: Array[ComboEventCardDefinition] = []
	var consumed_actions: Dictionary = {}
	
	for combo in priority_sorted_valid_combos:
		var conflicts: bool = false
		for required_action_id in combo.required_action_ids:
			if consumed_actions.has(required_action_id):
				conflicts = true
				break
		if conflicts:
			continue
		non_overlapping_combos.append(combo)
		for required_action_id in combo.required_action_ids:
			consumed_actions[required_action_id] = true
	
	return non_overlapping_combos

func _add_combo_cards_to_hand_(game_state: GameState,valid_combos_without_overlap: Array[ComboEventCardDefinition]) -> void:
	for combo in valid_combos_without_overlap:
		var combo_card_id = combo.card_type_id
		if not combo_card_id or combo_card_id == "":
			return
		var new_card_instance: EventCardInstance = _create_new_event_card_instance(
			game_state,combo_card_id,CardInstance.CardPermanence.TEMPORARY,0
		)
		_add_single_card_to_hand_(game_state,new_card_instance)
		
		var log_fragment: LogFragment = LogFragment.make_new_log_fragment(
		"combo_card_added_to_hand",
		{"event_card_instance":new_card_instance,"card_type_id":new_card_instance.card_id},
		[LogFragment.LogTags.PLAYER_DREW_EVENT_CARD,LogFragment.LogTags.EVENT_CARD_ADDED_TO_HAND],
		null,true
	)
		main_game.request_adding_fragment_to_log(log_fragment)


#endregion
#region Reward cards:
func _add_reward_cards_for_defeat_with_player_action(game_state:GameState,action:PlayerAction,opponent_id: String) -> void:
	if action.action_id not in game_state.reward_cards_from_actions.keys():
		return
	var reward_card_id: String = game_state.reward_cards_from_actions[action.action_id]
	var reward_card_instance: EventCardInstance = _create_new_event_card_instance(
		game_state,reward_card_id,CardInstance.CardPermanence.REWARD,0)
	_add_single_card_to_hand_(game_state,reward_card_instance)
	_log_adding_reward_card_to_hand(reward_card_id,reward_card_instance,opponent_id,action.action_id)

func _log_adding_reward_card_to_hand(reward_card_id: String,reward_card_instance: EventCardInstance,
opponent_id: String, action: String = "", event_card_id: String = ""):
	var log_fragment: LogFragment = LogFragment.make_new_log_fragment(
		"reward_card_added_to_hand",
		{"event_card_instance":reward_card_instance,"card_type_id":reward_card_id,
		"player_action": action, "opponent_id":opponent_id,"event_card_id":event_card_id},
		[LogFragment.LogTags.PLAYER_DREW_EVENT_CARD,LogFragment.LogTags.EVENT_CARD_ADDED_TO_HAND],
		null,true
	)
	main_game.request_adding_fragment_to_log(log_fragment)

func _add_reward_cards_for_defeat_with_event_card(game_state: GameState,opponent_id: String, event_card_id: String) -> void:
	var event_card_def: EventCardDefinition = AutoloadDatabase.get_event_card_def_by_id(event_card_id)
	if event_card_def.reward_cards_from_defeat.is_empty():
		return
	for reward_card_id in event_card_def.reward_cards_from_defeat:
		var reward_card_instance: EventCardInstance = _create_new_event_card_instance(
			game_state,reward_card_id,CardInstance.CardPermanence.REWARD,0)
		_add_single_card_to_hand_(game_state,reward_card_instance)
		_log_adding_reward_card_to_hand(reward_card_id,reward_card_instance,opponent_id,"",event_card_id)

func _add_temporary_cards_to_encounter_report(game_state: GameState) -> void:
	for card_instance in game_state.event_cards_hand:
		if card_instance.permanence != CardInstance.CardPermanence.PERMANENT:
			var card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[card_instance.card_id]
			game_state.record_event_card_played(card_def)
			_discard_card_(game_state,card_instance)

#endregion
#region Orgasm cards:
func _handle_player_HP_reduction_(game_state: GameState) -> void:
	_add_orgasm_reward_card_to_players_hand(game_state)

func _add_orgasm_reward_card_to_players_hand(game_state: GameState) -> void:
	var reward_card_id: String = _get_orgasm_reward_card_id()
	var reward_card_instance: EventCardInstance = _create_new_event_card_instance(
		game_state,reward_card_id,CardInstance.CardPermanence.TEMPORARY,0)
	_add_single_card_to_hand_(game_state,reward_card_instance)
	_log_adding_reward_card_from_orgasm(game_state,reward_card_instance)

func _get_orgasm_reward_card_id() -> String:
	return main_game.meta_game.save_game_state.get_current_orgasm_card_id()
	
func _log_adding_reward_card_from_orgasm(_game_state: GameState,reward_card_instance: EventCardInstance) -> void:
	var log_fragment: LogFragment = LogFragment.make_new_log_fragment(
		"orgasm_card_added_to_hand",
		{"event_card_instance":reward_card_instance,"card_type_id":reward_card_instance.card_id,
		"reason":"orgasm"},
		[LogFragment.LogTags.PLAYER_DREW_EVENT_CARD,LogFragment.LogTags.EVENT_CARD_ADDED_TO_HAND],
		null,true
	)
	main_game.request_adding_fragment_to_log(log_fragment)

#func _add_reward_cards_for_defeat_with_player_action(game_state:GameState,action:PlayerAction,opponent_id: String) -> void:
	#if action.action_id not in game_state.reward_cards_from_actions.keys():
		#return
	#var reward_card_id: String = game_state.reward_cards_from_actions[action.action_id]
	#var reward_card_instance: EventCardInstance = _create_new_event_card_instance(
		#reward_card_id,CardInstance.CardPermanence.REWARD)
	#_add_single_card_to_hand_(game_state,reward_card_instance)
	#_log_adding_reward_card_to_hand(reward_card_id,reward_card_instance,opponent_id,action.action_id)
	
#endregion
