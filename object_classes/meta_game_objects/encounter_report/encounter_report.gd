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
#var round_counter: int = 0
var final_round_number: int
var opponents_defeated_each_turn: Dictionary[int,int] #Turn #, count
var active_opponents_at_turn_end_log: Dictionary[int, Dictionary] # turn, active opponents
var reason_for_defeat: Dictionary = {} #Opponent ID, variant (effect context effect origin)
var active_player_passives_at_end_of_game: Array = []

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
	if opponent_id not in reason_for_defeat.keys(): ### Let it be overwritten elsewhere if needed
		reason_for_defeat[opponent_id] = context.effect_origin
	if game_state.opponent_was_defeated_by_player_action(opponent_id,action_on_opponent):
		#print("Recording defeat of %s with action %s"%[opponent_id,action_on_opponent])
		action_on_opponent = game_state.get_action_that_defeated_opponent(opponent_id)
		record_opponent_type_defeated_with_action(action_on_opponent,opponent_type.opponent_type_id)

func set_defeat_reason(opponent_id,effect_origin) -> void:
	reason_for_defeat[opponent_id] = effect_origin

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

func record_damage_to_opponent(action_id: String,opponent_type_id: String, damage: int) -> void:
	action_usage[action_id].record_damage_to_opponent(opponent_type_id,damage)
func record_opponent_type_defeated_with_action(action_id: String,opponent_type_id: String) -> void:
	if opponent_type_id == "":
		return
	
	action_usage[action_id].record_opponent_type_defeated(opponent_type_id)

func record_new_orgasms(new_orgasm_increase: int) -> void:
	orgasms_achieved += new_orgasm_increase

func get_current_orgasm_count() -> int:
	return orgasms_achieved

#func increment_turn_counter() -> void:
	#round_counter += 1

func record_active_opponents(game_state: GameState) -> void:
	active_opponents_at_turn_end_log[game_state.current_round] = game_state.get_currently_active_opponents()

func record_active_player_passives_at_end_of_game(game_state: GameState) -> void:
	active_player_passives_at_end_of_game = game_state.get_active_player_passives()

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

func get_times_card_has_been_played_in_round(round_nr: int, card_id: String) -> int:
	if round_nr not in event_cards_played_per_turn.keys():
		return 0
	if card_id not in event_cards_played_per_turn[round_nr].keys():
		return 0
	return event_cards_played_per_turn[round_nr][card_id]
	
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
