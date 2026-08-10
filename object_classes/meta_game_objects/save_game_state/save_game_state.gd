extends Resource
class_name SaveGameState

var _default_game_version: String = "0.0.0"
var game_version: String = _default_game_version



var PLAYER_STARTER_PASSIVES: Array = [
	"birth_control",
	"fertile"
]

var DEFAULT_STARTER_DECK: Dictionary = {
	"apply_weak": 3,
	"gain_ironskin": 1,
	"apply_target_guide": 3,
	"apply_burn": 3,
	#"faithless_looting": 2,
	"discard_two_draw_two": 2,
	#"drink_break": 2,
	"take_a_breather": 2,
	"draw_three":2,
	"kiss_neck": 2,
	"thats_so_good": 2
}

var DEFAULT_CURRENT_BUILD: Dictionary ={
	"event_cards_deck": DEFAULT_STARTER_DECK.duplicate(true),
	"summon_ally_card": "",
	"reward_cards_from_actions": {},
	"current_orgasm_card_id": "orgasm_muscle_spasm",
	"build_passives": PLAYER_STARTER_PASSIVES.duplicate(true)
}

func _retroactively_add_missing_features_() -> void:
	### Called by meta game to add new features when loading old saves.
	_give_player_missing_passives()
	_add_default_passives_()
	_add_default_passives_to_all_builds()
	_remove_virgin_passive_if_vaginal_is_used()
	_convert_deck_presets_to_build_presets()
	_migrate_ally_cards_out_of_decks()
	unlock_action_rewards_already_achieved()
	
func _migrate_ally_cards_out_of_decks() -> void:
	_strip_ally_cards_from_deck(current_build["event_cards_deck"])
	for build_name in saved_builds.keys():
		_strip_ally_cards_from_deck(saved_builds[build_name]["event_cards_deck"])

func _strip_ally_cards_from_deck(deck: Dictionary) -> void:
	for card_id in deck.keys().duplicate():
		var card_def: EventCardDefinition = AutoloadDatabase.get_event_card_def_by_id(card_id)
		if card_def and card_def.category == EventCardDefinition.CardCategory.SUMMON_ALLY:
			give_player_new_ally_card(card_id)
			deck.erase(card_id)
	
func _add_default_passives_() -> void:
	for passive_id in PLAYER_STARTER_PASSIVES.duplicate(true):
		if passive_id in player_owned_passives:
			continue
		give_player_passive(passive_id,true)

func _add_default_passives_to_all_builds() -> void:
	for build_name in get_saved_build_presets().keys():
		for passive_id in PLAYER_STARTER_PASSIVES.duplicate(true):
			add_passive_to_build(build_name,passive_id)

func add_passive_to_build(build_name: String,passive_id: String) -> void:
	var build: Dictionary = get_saved_build_presets()[build_name]
	if passive_id not in build["build_passives"]:
		build["build_passives"].append(passive_id)

func  _give_player_missing_passives() -> void:
	for passive_id in current_build["build_passives"]:
		#if passive_id not in player_owned_passives:
		give_player_passive(passive_id,false)
	for reward in rewards_unlocked.keys():
		#if reward not in AutoloadDatabase.unlock_rewards.keys():
			#continue
		var reward_def: RewardDefinition = AutoloadDatabase.get_unlock_reward_definition(reward)
		if reward_def is Reward_GivePlayerPassive:
			give_player_passive(reward_def.passive_id,false)

func _remove_virgin_passive_if_vaginal_is_used() -> void:
	if "virgin" not in get_player_owned_passives():
		return
	var guys_defeated_with_vagial: int = get_opponents_defeated_by_action("vaginal")
	if guys_defeated_with_vagial > 0:
		remove_passive_from_player("virgin")

func _convert_deck_presets_to_build_presets() -> void:
	print("Running _convert_deck_presets_to_build_presets")
	if event_card_deck_presets.is_empty():
		print("No presets")
		return
	for deck_preset_name in event_card_deck_presets.keys():
		if deck_preset_name in get_saved_build_presets().keys():
			print("Found that deck name %s is already in builds"%deck_preset_name)
			continue
		var deck_preset: Dictionary = event_card_deck_presets[deck_preset_name]
		save_build_preset(deck_preset_name,{
			"event_cards_deck": deck_preset,
			"summon_ally_card": "",
			"reward_cards_from_actions": {},
			"current_orgasm_card_id": "orgasm_muscle_spasm",
			"build_passives": []
		})

func unlock_action_rewards_already_achieved() -> void:
	var newly_unlocked_action_rewards: Array[String] = get_newly_unlocked_action_rewards()
	var not_previously_unlocked: Array[String] = newly_unlocked_action_rewards.duplicate(true)
	
	for reward in newly_unlocked_action_rewards:
		if reward in rewards_unlocked.keys():
			not_previously_unlocked.erase(reward)
	for reward in not_previously_unlocked:
		add_newly_unlocked_rewards([reward])
		rewards_unlocked[reward] = 1

func get_newly_unlocked_action_rewards() -> Array[String]:
	var newly_unlocked_action_rewards: Array[String] = []
	var checked_progressions: Array[ActionProgressionDefinition] = []
	for action_id in owned_player_actions:
		var action_progression: ActionProgressionDefinition = AutoloadDatabase.get_action_progression_def(action_id)
		if not action_progression or action_progression in checked_progressions:
			continue
		checked_progressions.append(action_progression)
		for reward_id in action_progression.get_rewards_that_should_be_unlocked(self):
			if reward_id not in newly_unlocked_action_rewards:
				newly_unlocked_action_rewards.append(reward_id)
	return newly_unlocked_action_rewards

func get_opponents_defeated_for_next_reward_for_action(action_id: String) -> int:
	var progression_for_action: ActionProgressionDefinition = AutoloadDatabase.get_action_progression_def(action_id)
	if not progression_for_action:
		return 0
	var current_count_for_progression: int = progression_for_action.get_current_count_for_reward(self)
	return current_count_for_progression

var rewards_unlocked_during_last_encounter: Array = []

func get_newly_unlocked_rewards() -> Array[String]:
	var rewards: Array[String] = []
	rewards.append_array(get_newly_unlocked_action_rewards())
	rewards.append_array(rewards_unlocked_during_last_encounter)
	return rewards

var encounters_completed: Dictionary = {} #encoutner ID, times cleared
func get_completed_encounter_ids() -> Array:
	return encounters_completed.keys()
func is_encounter_completed(encounter_id: String) -> bool:
	return encounter_id in encounters_completed.keys()
func get_total_nr_of_encounters_completed() -> int:
	var count: int = 0
	for encounter_id in encounters_completed.keys():
		count += encounters_completed[encounter_id]
	return count
var encounter_unlocked: Dictionary = {}
var opponents_defeated: Dictionary = {}
func get_nr_of_defeated_opponents() -> int:
	var count := 0
	for opponent_type_id in opponents_defeated:
		var value = opponents_defeated[opponent_type_id]
		count += value
	return count


var event_cards_played: Dictionary = {}
#endregion
#region Event card deck:


var owned_event_cards: Dictionary = DEFAULT_STARTER_DECK.duplicate()

var _default_min_deck_size: int = 20
var min_deck_size: int = _default_min_deck_size
func set_min_deck_size(size: int) -> void:
	min_deck_size = size
func get_min_deck_size() -> int:
	return min_deck_size
static func get_default_min_deck_size() -> int:
	var empty_save_game = SaveGameState.new()
	return empty_save_game._default_min_deck_size

func get_owned_event_cards() -> Dictionary:
	return owned_event_cards

func get_current_deck() -> Dictionary:
	return current_build["event_cards_deck"]

func get_current_deck_size() -> int:
	var count: int = 0
	var event_cards_deck: Dictionary =  get_current_deck()
	for card_id in event_cards_deck.keys():
		count += event_cards_deck[card_id]
	return count

func reset_event_card_deck() -> void:
	current_build["event_cards_deck"] = DEFAULT_STARTER_DECK.duplicate(true)

func deck_is_too_small() -> bool:
	return get_current_deck_size() < min_deck_size

func change_event_deck_card_count(event_card_id: String,delta: int) -> void:
	var current_card_count: int = 0
	if event_card_id in current_build["event_cards_deck"].keys():
		current_card_count = current_build["event_cards_deck"][event_card_id]
	var max_card_count: int = self.owned_event_cards[event_card_id]
	if delta > 0:
		if current_card_count + delta > max_card_count:
			return
		if event_card_id in current_build["event_cards_deck"].keys():
			current_build["event_cards_deck"][event_card_id] += delta
		else:
			current_build["event_cards_deck"][event_card_id] = delta
	if delta < 0:
		if current_card_count + delta < 0:
			return
		var new_value: int = current_card_count + delta
		current_build["event_cards_deck"][event_card_id] = new_value

func get_count_of_card_in_current_deck(event_card_id: String) -> int:
	if event_card_id not in get_current_deck().keys():
		return 0
	return get_current_deck()[event_card_id]
	
func set_count_of_card_in_current_deck(event_card_id: String, count: int) -> void:
	get_current_deck()[event_card_id] = count

func zero_out_current_event_card_deck() -> void:
	current_build["event_cards_deck"] = {}

func give_player_cards(cards_to_give: Dictionary[String,int]) -> void:
	for card_id in cards_to_give.keys():
		if card_id not in owned_event_cards:
			owned_event_cards[card_id] = cards_to_give[card_id]
		else:
			owned_event_cards[card_id] += cards_to_give[card_id]
		
		if card_id not in get_current_deck():
			get_current_deck()[card_id] = cards_to_give[card_id]
		else:
			get_current_deck()[card_id] += cards_to_give[card_id]

#region Deck presets: DEPRECATED
var event_card_deck_presets: Dictionary = {} # String, Dict: Name of dict then dict of cards
#
func save_current_deck_as_preset(deck_name: String) -> void:
	save_deck_preset(deck_name,self.event_cards_deck)

func save_deck_preset(deck_name: String, card_deck: Dictionary) -> void:
	event_card_deck_presets[deck_name] = card_deck.duplicate(true)

func get_saved_deck_presets() -> Dictionary:
	return event_card_deck_presets
	
func select_deck_preset(deck_name: String) -> void:
	var deck_preset: Dictionary = event_card_deck_presets[deck_name]
	current_build["event_cards_deck"] = deck_preset.duplicate(true)
	
func delete_deck_preset(deck_name: String) -> void:
	event_card_deck_presets.erase(deck_name)


#endregion
#region Player stats:
var _default_player: Dictionary = {
	"hp": 2,
	"damage_threshold": 100,
	"max_energy":10,
	"passive_effects": PLAYER_STARTER_PASSIVES.duplicate(true) # list of passive ID's
}
func get_default_player_stat(stat: String):
	if stat in _default_player.keys():
		return _default_player[stat]
	else:
		return null

var player: Dictionary = _default_player.duplicate(true)

func increase_player_stats(stats_delta: Dictionary[String, int]) -> void:
	player["hp"] += stats_delta["hp_increase"]
	player["damage_threshold"] += stats_delta["damage_threshold_increase"]
	player["max_energy"] += stats_delta["max_energy_increase"]

#endregion
#region Player passives:


var player_owned_passives: Array = PLAYER_STARTER_PASSIVES.duplicate(true) # Array of passive ID strings. These are all the player owns.

func get_player_owned_passives() -> Array:
	return player_owned_passives

func get_active_player_passives() -> Array:
	if "build_passives" not in current_build.keys():
		return []
	return current_build["build_passives"]

func give_player_passive(passive_id: String,starts_active: bool = true) -> void:
	if passive_id not in AutoloadDatabase.passive_effect_definitions.keys():
		#push_error("Tried to give player non-existent passive: %s" % passive_id)
		return
	if passive_id not in player_owned_passives:
		player_owned_passives.append(passive_id)
	if starts_active and passive_id not in current_build["build_passives"]:
		current_build["build_passives"].append(passive_id)
	var passive_def: PassiveEffectDefinition = AutoloadDatabase.get_passive_effect_def(passive_id)
	if not passive_def.toggleable_by_player:
		add_passive_to_all_saved_builds(passive_id)

func add_passive_to_all_saved_builds(passive_id: String) -> void:
	for build_name in get_saved_build_presets().keys():
		add_passive_to_build(build_name,passive_id)

func remove_passive_from_player(passive_id: String) -> void:
	if passive_id in current_build["build_passives"]:
		current_build["build_passives"].erase(passive_id)
	if passive_id in player_owned_passives:
		player_owned_passives.erase(passive_id)

func change_state_of_player_passive(passive_id: String, new_state: bool) -> void:
	if not player_owns_passive(passive_id):
		#print("Player does not own passive!")
		return
	if new_state:
		if passive_id not in current_build["build_passives"]:
			current_build["build_passives"].append(passive_id)
	else:
		if passive_id in current_build["build_passives"]:
			current_build["build_passives"].erase(passive_id)
	
func passive_is_hidden_from_player(passive_id: String) -> bool:
	var passive_def: PassiveEffectDefinition = AutoloadDatabase.get_passive_effect_def(passive_id)
	return passive_def.hidden_from_player

func player_owns_passive(passive_id: String) -> bool:
	return passive_id in player_owned_passives

func passive_is_active_on_player(passive_id: String) -> bool:
	if passive_id in current_build["build_passives"]:
		return true
	return false
	
#endregion
#region Player actions:
var default_owned_player_actions: Array = ["bj","vaginal"]
var owned_player_actions: Array = ["bj","vaginal"]
var currently_used_player_actions: Array = ["bj","vaginal"]

func remove_all_player_actions() -> void: ### Only really used in start of new game
	owned_player_actions.clear()
	currently_used_player_actions.clear()

func add_new_player_action(action_id: String) -> void:
	if action_id not in AutoloadDatabase.player_actions_by_id.keys():
		return
	if action_id not in owned_player_actions:
		owned_player_actions.append(action_id)
	if action_id not in currently_used_player_actions:
		currently_used_player_actions.append(action_id)
var reward_cards_unlocked_for_actions: Dictionary #ActionID, array of EventCardIDs
var reward_cards_from_actions: Dictionary #ActionID, EventCardID
func unlock_reward_card_for_action(reward_card_id: String, action_id:String) -> void:
	if reward_card_id not in AutoloadDatabase.event_cards_by_id.keys():
		push_error("Tried to assign non-existing reward card id: %s"%reward_card_id)
		return
	if action_id not in AutoloadDatabase.player_actions_by_id.keys():
		push_error("Tried to assign reward card to non existent player action: %s"%action_id)
		return
	if action_id not in reward_cards_unlocked_for_actions.keys():
		reward_cards_unlocked_for_actions[action_id] = []
	if reward_card_id not in reward_cards_unlocked_for_actions[action_id]:
		reward_cards_unlocked_for_actions[action_id].append(reward_card_id)
	
	if action_id not in reward_cards_from_actions.keys():
		reward_cards_from_actions[action_id] = reward_card_id
	elif reward_cards_from_actions[action_id] not in reward_cards_unlocked_for_actions[action_id]:
		reward_cards_from_actions[action_id] = reward_card_id

func  get_reward_cards_for_action(action_card_id: String)  -> Array:
	if action_card_id not in reward_cards_unlocked_for_actions.keys():
		return []
	return reward_cards_unlocked_for_actions[action_card_id]
func set_reward_card_for_action(action_id: String, reward_card_id: String) -> void:
	if reward_card_id not in get_reward_cards_for_action(action_id):
		push_error("Asked to change reward card for action %s to card %s, but that card is not unlocked for that action."%[action_id,reward_card_id])
		return
	reward_cards_from_actions[action_id] = reward_card_id

var action_stats: Dictionary #ActionID, Dictionary[{opponent_type_id:{}]
func get_opponents_defeated_by_action(action_id:String) -> int:
	if action_id not in action_stats.keys():
		return 0
	var count: int = 0
	for opponent_type_id in action_stats[action_id]:
		count += action_stats[action_id][opponent_type_id]["nr_defeated"]
	return count
func get_defeated_opponents_with_passive(passive_id: String) -> int:
	var count: int = 0
	for opponent_type_id in opponents_defeated.keys():
		var opponent_type: OpponentType = AutoloadDatabase.opponent_types[opponent_type_id]
		if passive_id in opponent_type.passive_effects:
			count += opponents_defeated[opponent_type_id]
	return count
#endregion
#region Orgasms:
### Orgasm cards:
var orgams_cards_unlocked: Array = ["orgasm_muscle_spasm"]
func get_default_orgasm_card() -> String:
	return "orgasm_muscle_spasm"
#var current_orgasm_card_id: String = "orgasm_muscle_spasm"
func clear_all_orgasm_cards() -> void:
	orgams_cards_unlocked.clear()
func unlock_orgasm_card(orgasm_card_id: String) -> void:
	if orgasm_card_id not in orgams_cards_unlocked:
		orgams_cards_unlocked.append(orgasm_card_id)
func set_current_orgasm_card(orgasm_card_id: String) -> void:
	if orgasm_card_id not in get_owned_orgasm_cards():
		return
	current_build["current_orgasm_card_id"] = orgasm_card_id
	#current_orgasm_card_id = orgasm_card_id
func get_current_orgasm_card_id() -> String:
	return current_build["current_orgasm_card_id"]
	#return current_orgasm_card_id
func get_owned_orgasm_cards() -> Array:
	return orgams_cards_unlocked

### Orgasm tracking:
var orgasms_lifetime: int = 0
func record_new_orgasms(new_orgasms: int) -> void:
	orgasms_lifetime += new_orgasms
func get_lifetime_orgasms() -> int:
	return orgasms_lifetime

#endregion
#region Reward unlocks:
var rewards_unlocked: Dictionary #Reward ID, times granted
#var unlocked_rewards: Array = [] #Strings for IDs
func add_reward_id_to_unlock_rewards(reward_id: String) -> void:
	increase_value_in_dictionary(rewards_unlocked,reward_id,1)
	#unlocked_rewards.append(reward_id)
func is_reward_unlocked(reward_id: String) -> bool:
	#return reward_id in unlocked_rewards
	return reward_id in rewards_unlocked.keys()
var rewards_unlocked_but_not_displayed: Array = []
func add_newly_unlocked_rewards(rewards_ids: Array) -> void:
	for reward in rewards_ids:
		if reward in rewards_unlocked_but_not_displayed:
			continue
		rewards_unlocked_but_not_displayed.append(reward)
	#rewards_unlocked_but_not_displayed.append_array(rewards_ids)
func empty_newly_unlocked_rewards() -> void:
	rewards_unlocked_but_not_displayed.clear()

func get_next_reward_id_for_action(action_id: String) -> String:
	if action_id not in owned_player_actions:
		return ""
	var reward_id: String = AutoloadDatabase.get_next_reward_for_action(self,action_id)
	
	return reward_id
	

#endregion
#region Custom encounter:
var custom_encounter_state: Dictionary = {}

#endregion
#region Tutorial:
#var tutorial_stages_completed: Array = []
#func record_tutorial_stage_completed(stage_id: String) -> void:
	#if stage_id not in tutorial_stages_completed:
		#tutorial_stages_completed.append(stage_id)
#func get_tutorial_stages_completed() -> Array:
	#return tutorial_stages_completed
#region
var most_guys_cumming_in_one_turn: int = 0
#endregion

#region Player customization
var character_portrait_path: String = ""
func change_portrait_path(new_path: String) -> void:
	character_portrait_path = new_path
	
func get_character_portrait() -> Texture2D:
	if "res://" in character_portrait_path:
		return Utils.load_asset(character_portrait_path)
	if character_portrait_path == "":
		return load("res://assets/player_profile_pics/emily.jpeg")
	if not FileAccess.file_exists(character_portrait_path):
		push_error("Portrait file not found at path: %s" % character_portrait_path)
		return load("res://assets/player_profile_pics/emily.jpeg")
	var image := Image.load_from_file(character_portrait_path)
	return ImageTexture.create_from_image(image)

var player_character_name: String = "Emily"
func set_player_character_name(new_name: String) -> void:
	player_character_name = new_name
func get_player_character_name() -> String:
	return player_character_name

var player_age: int = 18
func set_player_age(new_age: int) -> void:
	player_age = new_age
func get_player_age() -> int:
	return player_age
func get_minimum_age() -> int:
	return 18

#endregion
var condition_tracking: Dictionary = {} ### ID of condition, Variant to track

#region Defining builds:
var current_build: Dictionary = DEFAULT_CURRENT_BUILD.duplicate(true)

var saved_builds: Dictionary = {"Starter Build":DEFAULT_CURRENT_BUILD.duplicate(true)} # name of build (string), Build Dict (see current_build)

func save_current_build_as_preset(build_name: String) -> void:
	save_build_preset(build_name,self.current_build)

func save_build_preset(build_name: String, build: Dictionary) -> void:
	#print("Saving build preset named: %s"%build_name)
	saved_builds[build_name] = build.duplicate(true)

func get_saved_build_presets() -> Dictionary:
	return saved_builds
	
func select_build_preset(build_name: String) -> void:
	var build_preset: Dictionary = saved_builds[build_name]
	current_build = build_preset.duplicate(true)
	
func delete_build_preset(build_name: String) -> void:
	saved_builds.erase(build_name)

#endregion
#region Summon ally:
var owned_ally_cards: Array = [] ### Summon ally card IDs

func give_player_new_ally_card(ally_card_id: String,set_as_active: bool = false) -> void:
	if ally_card_id in owned_ally_cards:
		return
	owned_ally_cards.append(ally_card_id)
	if set_as_active:
		current_build["summon_ally_card"] = ally_card_id

func get_current_ally_card() -> String:
	return current_build["summon_ally_card"]

func get_current_ally_type() -> String:
	var current_ally_card_id: String = current_build["summon_ally_card"]
	return get_ally_card_from_id(current_ally_card_id)

static func get_ally_card_from_id(ally_card_id: String) -> String:
	if ally_card_id == "":
		return ""
	var ally_card_type: EventCardDefinition = AutoloadDatabase.get_event_card_def_by_id(ally_card_id)
	if not ally_card_type:
		return ""
	var ally_opponent_type_id: String = ally_card_type.get_summoned_ally_opponent_type_id()
	return ally_opponent_type_id

func get_owned_summon_cards() -> Array:
	return owned_ally_cards
	#var owned_summons: Array[String] = []
	#for card_id in get_owned_event_cards().keys():
		#var card_def: EventCardDefinition = AutoloadDatabase.get_event_card_def_by_id(card_id)
		#if card_def.category != EventCardDefinition.CardCategory.SUMMON_ALLY:
			#continue
		#owned_summons.append(card_id)
	#return owned_summons

func change_current_ally_card(card_id: String) -> void:
	#if card_id not in get_owned_event_cards().keys():
		#return
	#_remove_all_ally_summon_cards_from_deck()
	#_add_ally_summon_card_to_deck(card_id)
	_set_card_as_current_ally_card(card_id)

func _remove_all_ally_summon_cards_from_deck() -> void:
	for card_id in get_current_deck().keys():
		var card_def: EventCardDefinition = AutoloadDatabase.get_event_card_def_by_id(card_id)
		if card_def.category == EventCardDefinition.CardCategory.SUMMON_ALLY:
			set_count_of_card_in_current_deck(card_id,0)

func _add_ally_summon_card_to_deck(card_id: String) -> void:
	if card_id == "":
		return
	set_count_of_card_in_current_deck(card_id,1)
func _set_card_as_current_ally_card(card_id: String) -> void:
	current_build["summon_ally_card"] = card_id

#endregion
#region Character Definitions:
var selected_character_id: String = "emily"
var character_class_name: String = "College Slut"
func set_character_class(given_class_name: String) -> void:
	character_class_name = given_class_name
func get_character_class() -> String:
	return character_class_name
func get_default_character_class_name() -> String:
	return "College Slut"
var character_video_particpatipant_tags: Array = []

func add_video_particpant_tags_from_string_array(video_participant_tags: Array[VideoClip.ParticipantTags]) -> void:
	#var parsed_enum_values: Array[VideoClip.ParticipantTags] = VideoClip._parse_participant_tags(video_participant_tags, selected_character_id)
	var canonical_strings: Array[String] = VideoClip._convert_participant_tags_to_string(video_participant_tags, selected_character_id)
	character_video_particpatipant_tags = canonical_strings.duplicate() ### store as plain Array, not typed

func get_player_video_participant_tags() -> Array[VideoClip.ParticipantTags]:
	return VideoClip._parse_participant_tags(character_video_particpatipant_tags, selected_character_id)

func swap_state_of_participant_tag(tag: VideoClip.ParticipantTags) -> void:
	var tag_name: String = VideoClip.ParticipantTags.keys()[tag]
	if tag_name in character_video_particpatipant_tags:
		character_video_particpatipant_tags.erase(tag_name)
	else:
		character_video_particpatipant_tags.append(tag_name)

#endregion
#region Tracking triggered effects:
var triggered_effects_tracking: Dictionary = {} # ID of effect - nr of times triggered
func record_triggering_of_component(triggered_component: StatusTriggeredComponent) -> void:
	#print("Recording triggering of component: %s"%triggered_component.trigger_component_id)
	if triggered_component.trigger_component_id not in triggered_effects_tracking.keys():
		triggered_effects_tracking[triggered_component.trigger_component_id] = 0
	
	triggered_effects_tracking[triggered_component.trigger_component_id] += 1
	#print("Nr of times triggered: %s"%triggered_effects_tracking[triggered_component.trigger_component_id])

func get_times_trigger_has_triggered(trigger_id_to_check: String) -> int:
	if trigger_id_to_check not in triggered_effects_tracking.keys():
		return 0
	return triggered_effects_tracking[trigger_id_to_check]

func reset_trigger_counter_for_id(trigger_id_to_check: String) -> void:
	triggered_effects_tracking[trigger_id_to_check] = 0

func get_children_birthed() -> int:
	var pregnancy_tigger_string: String = "pregnancy_give_birth"
	if pregnancy_tigger_string not in triggered_effects_tracking.keys():
		return 0
	return get_times_trigger_has_triggered(pregnancy_tigger_string)

#endregion
#region Methods for saving:
func to_dict() -> Dictionary:
	return {
		"encounters_completed": encounters_completed,
		"opponents_defeated": opponents_defeated,
		"event_cards_played": event_cards_played,
		"owned_event_cards":owned_event_cards,
		#"event_cards_deck":event_cards_deck,
		"owned_player_actions":owned_player_actions,
		"currently_used_player_actions":currently_used_player_actions,
		"rewards_unlocked":rewards_unlocked,
		"reward_cards_unlocked_for_actions":reward_cards_unlocked_for_actions,
		"reward_cards_from_actions":reward_cards_from_actions,
		"action_stats":action_stats,
		"player": player,
		"min_deck_size":min_deck_size,
		"game_version": SaveSystem.get_current_game_version(),
		"custom_encounter_state": custom_encounter_state,
		"orgasms_lifetime": orgasms_lifetime,
		"orgams_cards_unlocked": orgams_cards_unlocked,
		"most_guys_cumming_in_one_turn":most_guys_cumming_in_one_turn,
		#"current_orgasm_card_id": current_orgasm_card_id,
		"event_card_deck_presets": event_card_deck_presets,
		"character_portrait_path": character_portrait_path,
		"player_character_name":player_character_name,
		"player_age": player_age,
		"player_owned_passives": player_owned_passives,
		"condition_tracking": condition_tracking,
		"current_build": current_build,
		"saved_builds": saved_builds,
		"selected_character_id": selected_character_id,
		"character_class_name":character_class_name,
		"character_video_particpatipant_tags":character_video_particpatipant_tags,
		"triggered_effects_tracking":triggered_effects_tracking,
		"rewards_unlocked_during_last_encounter":rewards_unlocked_during_last_encounter,
		"owned_ally_cards":owned_ally_cards
		#"tutorial_stages_completed":tutorial_stages_completed
	}


func from_dict(data: Dictionary) -> void:
	encounters_completed = data.get("encounters_completed", {})
	opponents_defeated = data.get("opponents_defeated", {})
	event_cards_played = data.get("event_cards_played", {})
	owned_event_cards = data.get("owned_event_cards", DEFAULT_STARTER_DECK.duplicate(true))
	#event_cards_deck = data.get("event_cards_deck", DEFAULT_STARTER_DECK.duplicate(true))
	owned_player_actions = data.get("owned_player_actions", [])
	currently_used_player_actions = data.get("currently_used_player_actions", [])
	rewards_unlocked = data.get("rewards_unlocked", {})
	reward_cards_unlocked_for_actions = data.get("reward_cards_unlocked_for_actions", {})
	reward_cards_from_actions = data.get("reward_cards_from_actions", {})
	action_stats = data.get("action_stats", {})
	player = data.get("player", _default_player.duplicate(true))
	min_deck_size = data.get("min_deck_size", _default_min_deck_size)
	game_version = data.get("game_version",_default_game_version)
	custom_encounter_state = data.get("custom_encounter_state",{})
	orgasms_lifetime = data.get("orgasms_lifetime",0)
	orgams_cards_unlocked = data.get("orgams_cards_unlocked",["orgasm_muscle_spasm"])
	most_guys_cumming_in_one_turn = data.get("most_guys_cumming_in_one_turn",0)
	#current_orgasm_card_id = data.get("current_orgasm_card_id","orgasm_muscle_spasm")
	event_card_deck_presets = data.get("event_card_deck_presets",{})
	character_portrait_path = data.get("character_portrait_path","")
	player_character_name = data.get("player_character_name","Emily")
	player_age = data.get("player_age",18)
	player_owned_passives = data.get("player_owned_passives",PLAYER_STARTER_PASSIVES.duplicate(true))
	condition_tracking = data.get("condition_tracking",{})
	current_build = data.get("current_build",DEFAULT_CURRENT_BUILD.duplicate(true))
	saved_builds = data.get("saved_builds",{"Starter Build":DEFAULT_CURRENT_BUILD.duplicate(true)})
	selected_character_id = data.get("selected_character_id","emily")
	character_class_name = data.get("character_class_name","College Slut")
	character_video_particpatipant_tags = data.get("character_video_particpatipant_tags",[])
	triggered_effects_tracking = data.get("triggered_effects_tracking",{})
	rewards_unlocked_during_last_encounter = data.get("rewards_unlocked_during_last_encounter",[])
	owned_ally_cards = data.get("owned_ally_cards",[])
	
#region Handling encounter reports:
func apply_encounter_report(report: EncounterReport) -> void:
	_apply_encounters_completed(report)
	_apply_opponents_defeated(report)
	_apply_event_cards_played(report)
	_apply_action_usage_stats(report)
	_apply_orgasms_achieved(report)
	_apply_opponents_defeated_simultaneously(report)
	
func increase_value_in_dictionary(dict: Dictionary,key: String,delta: int) -> void:
	if key not in dict.keys():
		dict[key] = delta
	else:
		dict[key] += delta

func _apply_encounters_completed(report: EncounterReport) -> void:
	if not report.player_won:
		return
	var encounter_id: String = report.encounter_def.encounter_id
	increase_value_in_dictionary(encounters_completed,encounter_id,1)
	
func _apply_opponents_defeated(report: EncounterReport) -> void:
	var new_defeat_dict: Dictionary[String, int] = report.opponents_defeated
	for opponent_type_id in new_defeat_dict.keys():
		increase_value_in_dictionary(opponents_defeated,opponent_type_id,new_defeat_dict[opponent_type_id])
	
func _apply_event_cards_played(report: EncounterReport) -> void:
	var new_cards_played_dict: Dictionary[String, int] = report.event_cards_played
	for card_id in new_cards_played_dict.keys():
		increase_value_in_dictionary(event_cards_played,card_id,new_cards_played_dict[card_id])

func _apply_action_usage_stats(report: EncounterReport) -> void:
	for action_id in report.action_usage.keys():
		if action_id not in action_stats.keys():
			action_stats[action_id] = {}
		var action_usage_stat_from_report: ActionUsageStats = report.action_usage[action_id]
		for opponent_type_id in action_usage_stat_from_report.damage_dealt_by_opponent_type:
			if opponent_type_id not in action_stats[action_id].keys():
				action_stats[action_id][opponent_type_id] = {"damage_dealt":0,"nr_defeated":0}
			var damage: int = action_usage_stat_from_report.damage_dealt_by_opponent_type[opponent_type_id]
			increase_value_in_dictionary(action_stats[action_id][opponent_type_id],"damage_dealt",damage)
		for opponent_type_id in action_usage_stat_from_report.opponents_defeated_by_type:
			if opponent_type_id not in action_stats[action_id].keys():
				action_stats[action_id][opponent_type_id] = {"damage_dealt":0,"nr_defeated":0}
			var nr_defeated: int = action_usage_stat_from_report.opponents_defeated_by_type[opponent_type_id]
			increase_value_in_dictionary(action_stats[action_id][opponent_type_id],"nr_defeated",nr_defeated)
	
func _apply_orgasms_achieved(report: EncounterReport) -> void:
	orgasms_lifetime += report.orgasms_achieved

func _apply_opponents_defeated_simultaneously(report: EncounterReport) -> void:
	var highest_nr_simultaneous: int = report.get_max_opponents_defeated_in_one_turn()
	if highest_nr_simultaneous > self.most_guys_cumming_in_one_turn:
		most_guys_cumming_in_one_turn = highest_nr_simultaneous
