extends Resource
class_name EncounterReport

#region Variables
var encounter_def: EncounterDefinition
var player_won: bool = false
var player_lost: bool = false
var opponents_defeated: Dictionary[String,int] = {} #Opponent type name, number
var event_cards_played: Dictionary[String,int] = {} #Event card ID, number
var event_cards_played_per_turn: Dictionary[int,Dictionary] = {}
var action_usage: Dictionary[String,ActionUsageStats] = {} # Action ID
var orgasms_achieved: int = 0
var opponent_orgasms_caused: Dictionary[String,int] = {} #Opponent ID, number of orgasms caused
#var round_counter: int = 0
var final_round_number: int
var opponents_defeated_each_turn: Dictionary[int,int] #Turn #, count
var active_opponents_at_turn_end_log: Dictionary[int, Dictionary] # turn, active opponents
var reason_for_defeat: Dictionary = {} #Opponent ID, variant (effect context effect origin)
var active_player_passives_at_end_of_game: Array = []
### The statuses the player had when the encounter ended: status id -> stacks (a status that does not stack counts as 1).
### Plain values, no references. See record_active_player_statuses_at_end_of_game().
var active_player_statuses_at_end_of_game: Dictionary = {}

### What finished each defeated opponent: opponent ID -> {"kind": DefeatSourceKind, "id": String}. The id is the
### Action/Event Card/Status/Passive that did it (empty for OTHER). Kept as plain values, no references.
enum DefeatSourceKind {PLAYER_ACTION, EVENT_CARD, STATUS_EFFECT, PASSIVE, OTHER}
var defeat_sources: Dictionary = {}
### The highest the player's Pleasure got, as a percentage of their maximum (an orgasm counts as 100 or more).
var highest_player_pleasure_percent: float = 0.0

#endregion

#region Setting methods
func set_encounter_definition(given_encounter_def: EncounterDefinition,game_state: GameState) -> void:
	encounter_def = given_encounter_def
	_setup_action_usage(game_state)
func _setup_action_usage(game_state: GameState) -> void:
	for action_id in game_state.actions_available_in_encounter:
		action_usage[action_id] = ActionUsageStats.new()
		action_usage[action_id].action_id = action_id
		
func set_player_won() -> void:
	player_won = true
func set_player_lost() -> void:
	player_lost = true
func record_defeated_opponent(
	game_state: GameState,
	opponent_id: String,
	opponent_type: OpponentType,
	context: EffectContext,
	action_on_opponent: String) -> void:
	increment_opponents_defeated_this_turn(game_state)
	var opponent_type_id: String = opponent_type.opponent_type_id
	if opponent_type_id not in opponents_defeated.keys():
		opponents_defeated[opponent_type_id] = 1
	else:
		opponents_defeated[opponent_type_id] += 1
	if opponent_id not in defeat_sources.keys(): ### Let it be overwritten elsewhere if needed
		set_defeat_source(opponent_id,context)
	if opponent_id not in reason_for_defeat.keys(): ### Let it be overwritten elsewhere if needed
		reason_for_defeat[opponent_id] = context.effect_origin
	if game_state.opponent_was_defeated_by_player_action(opponent_id,action_on_opponent):
		#print("Recording defeat of %s with action %s"%[opponent_id,action_on_opponent])
		action_on_opponent = game_state.get_action_that_defeated_opponent(opponent_id)
		record_opponent_type_defeated_with_action(action_on_opponent,opponent_type.opponent_type_id)

func set_defeat_reason(opponent_id,effect_origin) -> void:
	reason_for_defeat[opponent_id] = effect_origin

### Remembers what finished this opponent, from the effect context that did the damage. Called when the
### damage lands (overwrites), and as a fallback when the defeat is recorded.
func set_defeat_source(opponent_id: String, context: EffectContext) -> void:
	if context == null:
		return
	defeat_sources[opponent_id] = _get_defeat_source_from_context(context)
	if OS.is_debug_build():
		var source: Dictionary = defeat_sources[opponent_id]
		print("EncounterReport: %s finished by %s '%s'" % [
			opponent_id,DefeatSourceKind.keys()[source["kind"]],source["id"]])

### Passives/statuses come first: a passive reacting to a card's damage carries the card too, but it is the
### passive that did the damage. "Trigger [action]" event cards count as the Action, since that is what resolves.
static func _get_defeat_source_from_context(context: EffectContext) -> Dictionary:
	if context.effect_origin is PlayerAction:
		return {"kind": DefeatSourceKind.PLAYER_ACTION, "id": context.id_of_effect_origin}
	if context.status_sending_context:
		return {"kind": DefeatSourceKind.STATUS_EFFECT, "id": context.status_sending_context.status_id}
	if context.passive_sending_context:
		return {"kind": DefeatSourceKind.PASSIVE, "id": context.passive_sending_context.passive_id}
	if context.event_card_causing_effect:
		return {"kind": DefeatSourceKind.EVENT_CARD, "id": context.event_card_causing_effect.card_id}
	return {"kind": DefeatSourceKind.OTHER, "id": ""}

### Number of defeated opponents finished by the given kind of source. If source_ids is not empty, only
### those specific Actions/Cards/Statuses/Passives count.
func get_nr_of_defeats_by_source(kind: DefeatSourceKind, source_ids: Array[String] = []) -> int:
	var count: int = 0
	for opponent_id in defeat_sources.keys():
		var source: Dictionary = defeat_sources[opponent_id]
		if source["kind"] != kind:
			continue
		if not source_ids.is_empty() and source["id"] not in source_ids:
			continue
		count += 1
	return count

### Called whenever the player gains Pleasure. current_pleasure is the value before any orgasm reset.
func record_player_pleasure(current_pleasure: int, max_pleasure: int) -> void:
	if max_pleasure <= 0:
		return
	var percent: float = 100.0 * float(current_pleasure) / float(max_pleasure)
	if percent > highest_player_pleasure_percent:
		highest_player_pleasure_percent = percent

func get_reason_for_defeat(opponent_id: String):
	if opponent_id in reason_for_defeat.keys():
		return reason_for_defeat[opponent_id]
	return  null

func increment_opponents_defeated_this_turn(game_state: GameState) -> void:
	if game_state.current_round not in opponents_defeated_each_turn.keys():
		opponents_defeated_each_turn[game_state.current_round] = 1
	else:
		opponents_defeated_each_turn[game_state.current_round] += 1

func record_event_card_played(event_card_def: EventCardDefinition,game_state: GameState) -> void:
	var event_card_id = event_card_def.card_type_id
	if event_card_id not in event_cards_played.keys():
		event_cards_played[event_card_id] = 1
	else:
		event_cards_played[event_card_id] += 1
	
	if game_state.current_round not in event_cards_played_per_turn.keys():
		event_cards_played_per_turn[game_state.current_round] = {}
	
	if event_card_id not in event_cards_played_per_turn[game_state.current_round].keys():
		event_cards_played_per_turn[game_state.current_round][event_card_id] = 1
	else:
		event_cards_played_per_turn[game_state.current_round][event_card_id] += 1

### action_usage only has the actions the player is using (see _setup_action_usage). An action the player isn't
### using can still resolve, e.g. an ally's Fluff move triggers Handjob - that is not the player using it, so it
### is left out of the report (it must not count against "only use X" conditions or add to the action's stats).
func record_damage_to_opponent(action_id: String,opponent_type_id: String, damage: int) -> void:
	if action_id not in action_usage.keys():
		return
	action_usage[action_id].record_damage_to_opponent(opponent_type_id,damage)
func record_opponent_type_defeated_with_action(action_id: String,opponent_type_id: String) -> void:
	if opponent_type_id == "":
		return
	if action_id not in action_usage.keys():
		return
	action_usage[action_id].record_opponent_type_defeated(opponent_type_id)

func record_new_orgasms(new_orgasm_increase: int) -> void:
	orgasms_achieved += new_orgasm_increase

func get_current_orgasm_count() -> int:
	return orgasms_achieved

func record_new_opponent_orgasms(opponent_id: String, new_orgasm_increase: int) -> void:
	if opponent_id not in opponent_orgasms_caused.keys():
		opponent_orgasms_caused[opponent_id] = 0
	opponent_orgasms_caused[opponent_id] += new_orgasm_increase

func get_orgasms_caused_for_opponent(opponent_id: String) -> int:
	return opponent_orgasms_caused.get(opponent_id, 0)

#func increment_turn_counter() -> void:
	#round_counter += 1

func record_active_opponents(game_state: GameState) -> void:
	active_opponents_at_turn_end_log[game_state.current_round] = game_state.get_currently_active_opponents()

func record_active_player_passives_at_end_of_game(game_state: GameState) -> void:
	active_player_passives_at_end_of_game = game_state.get_active_player_passives()

### A snapshot of the player's statuses as the encounter ends, with how many stacks of each (the same moment as the passives above).
func record_active_player_statuses_at_end_of_game(game_state: GameState) -> void:
	active_player_statuses_at_end_of_game = {}
	var player_statuses: Dictionary = game_state.get_player_statuses()
	for status_id in player_statuses.keys():
		active_player_statuses_at_end_of_game[status_id] = maxi(int(player_statuses[status_id].get("stacks",1)),1)

#endregion
#region Query methods
func get_defeated_opponents() -> Dictionary:
	return opponents_defeated
func get_total_nr_of_defeated_opponents() -> int:
	var count: int = 0
	for opponent_id in opponents_defeated.keys():
		count += opponents_defeated[opponent_id]
	return count
func get_played_event_cards() -> Dictionary:
	return event_cards_played
func get_times_card_has_been_played(card_id: String) -> int:
	if card_id not in event_cards_played:
		return 0
	return event_cards_played[card_id]

## Sums play counts across every tracked card, so any of them advances the same shared count.
func get_times_cards_have_been_played(card_ids: Array[String]) -> int:
	var total: int = 0
	for card_id in card_ids:
		total += get_times_card_has_been_played(card_id)
	return total

### How many stacks of the status the player had when the encounter ended, 0 if they did not have it.
func get_status_stacks_at_end_of_game(status_id: String) -> int:
	return int(active_player_statuses_at_end_of_game.get(status_id,0))

func get_times_card_has_been_played_in_round(round_nr: int, card_id: String) -> int:
	if round_nr not in event_cards_played_per_turn.keys():
		return 0
	if card_id not in event_cards_played_per_turn[round_nr].keys():
		return 0
	return event_cards_played_per_turn[round_nr][card_id]
	
### The most Event Cards played in any single turn.
func get_most_cards_played_in_one_turn() -> int:
	var most_cards: int = 0
	for turn in event_cards_played_per_turn.keys():
		var cards_this_turn: int = 0
		for card_id in event_cards_played_per_turn[turn].keys():
			cards_this_turn += event_cards_played_per_turn[turn][card_id]
		most_cards = maxi(most_cards, cards_this_turn)
	return most_cards

### True if some turn had at least min_cards Event Cards played in it, including every card in required_card_ids.
func has_turn_with_cards(min_cards: int, required_card_ids: Array[String] = []) -> bool:
	for turn in event_cards_played_per_turn.keys():
		var cards_this_turn: Dictionary = event_cards_played_per_turn[turn]
		var total: int = 0
		for card_id in cards_this_turn.keys():
			total += cards_this_turn[card_id]
		if total < min_cards:
			continue
		var has_all_required: bool = true
		for required_card_id in required_card_ids:
			if required_card_id not in cards_this_turn.keys():
				has_all_required = false
				break
		if has_all_required:
			return true
	return false

func get_nr_of_opponents_defeated_on_turn(turn: int) -> int:
	if opponents_defeated_each_turn.is_empty():
		return 0
	if turn not in opponents_defeated_each_turn.keys():
		return 0
	return opponents_defeated_each_turn[turn]

func get_max_opponents_defeated_in_one_turn() -> int:
	if opponents_defeated_each_turn.is_empty():
		return 0
	var max_defeated: int = 0
	for turn in opponents_defeated_each_turn:
		if opponents_defeated_each_turn[turn] > max_defeated:
			max_defeated = opponents_defeated_each_turn[turn]
	#print("Max # guys defeated in a turn: %s"%max_defeated)
	#print(opponents_defeated_each_turn)
	return max_defeated

func get_reason_for_game_over() -> String:
	if player_won and not player_lost:
		return "player_won"
	if player_lost and not player_won:
		return "player_lost"
	return "game_ended_inconclusively"

#endregion
#region Visuals:
#func get_image_of_player_after_encounter() -> Texture2D:
	#var possible_images: Array
	#var folder_path: String
	#if player_won:
		#folder_path = "res://resources/player_after_encounters/player_victory/"
	#if player_lost:
		#folder_path = "res://resources/player_after_encounters/player_defeat/"
	#possible_images = Utils.get_files_in_folder(folder_path,"g")
	#var victory_image: Texture2D = load(Utils.get_random_item(possible_images))
	#return victory_image

func get_image_of_player_after_encounter() -> Texture2D:
	var folder_path: String
	if player_won:
		folder_path = "res://resources/player_after_encounters/player_victory/"
	if player_lost:
		folder_path = "res://resources/player_after_encounters/player_defeat/"
	
	print("Attempting to load from: ", folder_path)
	Utils.debug_folder(folder_path)
	
	var possible_images: Array = Utils.get_files_in_folder(folder_path, "g")
	print("Files found after filtering: ", possible_images)
	
	if possible_images.is_empty():
		print("ERROR: No images found!")
		return null
	
	var chosen = Utils.get_random_item(possible_images)
	print("Attempting to load: ", chosen)
	
	var texture: Texture2D = load(chosen)
	if texture == null:
		print("ERROR: load() returned null for path: ", chosen)
	else:
		print("SUCCESS: Texture loaded fine.")
	
	return texture



#endregion
