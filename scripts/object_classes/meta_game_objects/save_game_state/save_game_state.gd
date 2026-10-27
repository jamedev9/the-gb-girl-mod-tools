extends Resource
class_name SaveGameState

### Emitted when something that makes the player stronger changes - a stat reward (increase_player_stats()) or
### an upgrade of a player action's effects or triggers (set_progressed_effect_intents(),
### set_progressed_triggered_components()) - so things derived from the
### player's strength, currently the encounter difficulty estimate, refresh right then instead of polling.
### reason says what changed: "stats_reward" or "action_progression".
signal player_power_changed(reason: String)

var _default_game_version: String = "0.0.0"
var game_version: String = _default_game_version



var PROTOTYPE_STARTER_PASSIVES: Array = [
	"birth_control",
	"fertile"
]

### Full Rework mode takes the list from its ContentSet instead (so a passive that isn't carried
### over, like "fertile" and the pregnancy chain behind it, is never handed to a new player).
var PLAYER_STARTER_PASSIVES: Array = _get_starter_passive_ids()

func _get_starter_passive_ids() -> Array:
	if PlayModeSettings.current != PlayModeSettings.Mode.FULL_REWORK:
		return PROTOTYPE_STARTER_PASSIVES.duplicate(true)
	var content_set: ContentSet = AutoloadDatabase.get_active_content_set()
	var starter_passive_ids: Array = [] ### Plain Array, not the set's Array[String] - typed arrays break save JSON round-trips.
	if content_set:
		starter_passive_ids.append_array(content_set.starter_passive_ids)
	return starter_passive_ids

var PROTOTYPE_STARTER_DECK: Dictionary = {
	"apply_weak": 3,
	"gain_ironskin": 1,
	"apply_target_guide": 3,
	"apply_burn": 3,
	"discard_two_draw_two": 2,
	"take_a_breather": 2,
	"draw_three":2,
	"kiss_neck": 2,
	"thats_so_good": 2
}

### Full Rework mode takes its starter deck from the ContentSet, so it can be changed without
### touching the prototype's.
var DEFAULT_STARTER_DECK: Dictionary = _get_starter_deck()

func _get_starter_deck() -> Dictionary:
	if PlayModeSettings.current != PlayModeSettings.Mode.FULL_REWORK:
		return PROTOTYPE_STARTER_DECK.duplicate(true)
	var content_set: ContentSet = AutoloadDatabase.get_active_content_set()
	var starter_deck: Dictionary = {} ### Plain Dictionary, not the set's Dictionary[String,int] - typed containers break save JSON round-trips.
	if content_set:
		for card_id in content_set.starter_deck.keys():
			starter_deck[card_id] = content_set.starter_deck[card_id]
	return starter_deck

var DEFAULT_CURRENT_BUILD: Dictionary ={
	"event_cards_deck": DEFAULT_STARTER_DECK.duplicate(true),
	"summon_ally_card": "",
	"reward_cards_from_actions": {},
	"current_orgasm_card_id": "orgasm_muscle_spasm",
	"build_passives": PLAYER_STARTER_PASSIVES.duplicate(true)
}

func _retroactively_add_missing_features_() -> void:
	### Called by meta game to add new features when loading old saves.
	_restore_set_aside_cards()
	_restore_set_aside_actions()
	_restore_set_aside_passives()
	_give_player_missing_passives()
	_add_default_passives_()
	_add_default_passives_to_all_builds()
	_remove_virgin_passive_if_vaginal_is_used()
	_remove_unowned_passives_from_saved_builds()
	_convert_deck_presets_to_build_presets()
	_migrate_ally_cards_out_of_decks()
	unlock_action_rewards_already_achieved()
	_restore_lost_action_progress()
	_apply_analqueen_max_pleasure_buff()
	_add_missing_edging_threshold()
	_set_aside_cards_that_are_not_installed()
	_set_aside_actions_that_are_not_installed()
	_set_aside_passives_that_are_not_installed()

#region Cards that aren't installed (a disabled or removed mod's)
### Every card id the save holds whose card isn't registered (its mod is disabled or removed) is moved out of the lists the
### game reads into set_aside_cards, so nothing that reads cards can trip over it (the card view stopped showing any card).
### When the card is installed again, the next load puts it back where it was. Runs on every load: the restore first in
### _retroactively_add_missing_features_() (so the migrations see every card), the setting aside last.
### Each entry: {"where": ..., "card_id": ..., and "count" / "build" ("" = the current build) / "action_id" /
### "replaced_with" (what a selected slot was set to instead) where it applies}. Untyped and JSON-safe like all save data.
var set_aside_cards: Array = []

const _BUILD_CURRENT: String = ""

func _is_card_installed(card_id: String) -> bool:
	return AutoloadDatabase.get_event_card_def_by_id(card_id) != null

func _set_aside_cards_that_are_not_installed() -> void:
	for card_id in owned_event_cards.keys():
		if not _is_card_installed(card_id):
			set_aside_cards.append({"where": "owned", "card_id": card_id, "count": owned_event_cards[card_id]})
			owned_event_cards.erase(card_id)
	for card_id in orgams_cards_unlocked.duplicate():
		if not _is_card_installed(card_id):
			set_aside_cards.append({"where": "orgasm_card", "card_id": card_id})
			orgams_cards_unlocked.erase(card_id)
	for card_id in owned_ally_cards.duplicate():
		if not _is_card_installed(card_id):
			set_aside_cards.append({"where": "ally_card", "card_id": card_id})
			owned_ally_cards.erase(card_id)
	for action_id in reward_cards_unlocked_for_actions.keys():
		for card_id in reward_cards_unlocked_for_actions[action_id].duplicate():
			if not _is_card_installed(card_id):
				set_aside_cards.append({"where": "action_reward_card", "card_id": card_id, "action_id": action_id})
				reward_cards_unlocked_for_actions[action_id].erase(card_id)
	for action_id in reward_cards_from_actions.keys():
		var selected_card_id: String = reward_cards_from_actions[action_id]
		if _is_card_installed(selected_card_id):
			continue
		var replacement: String = ""
		for card_id in get_reward_cards_for_action(action_id):
			if _is_card_installed(card_id):
				replacement = card_id
				break
		set_aside_cards.append({"where": "selected_action_reward_card", "card_id": selected_card_id, "action_id": action_id, "replaced_with": replacement})
		if replacement == "":
			reward_cards_from_actions.erase(action_id)
		else:
			reward_cards_from_actions[action_id] = replacement
	_set_aside_build_cards(current_build, _BUILD_CURRENT)
	for build_name in saved_builds.keys():
		_set_aside_build_cards(saved_builds[build_name], build_name)

func _set_aside_build_cards(build: Dictionary, build_name: String) -> void:
	var deck: Dictionary = build.get("event_cards_deck", {})
	for card_id in deck.keys():
		if not _is_card_installed(card_id):
			set_aside_cards.append({"where": "build_deck", "card_id": card_id, "count": deck[card_id], "build": build_name})
			deck.erase(card_id)
	var ally_card_id: String = build.get("summon_ally_card", "")
	if ally_card_id != "" and not _is_card_installed(ally_card_id):
		set_aside_cards.append({"where": "build_ally_card", "card_id": ally_card_id, "build": build_name, "replaced_with": ""})
		build["summon_ally_card"] = ""
	var orgasm_card_id: String = build.get("current_orgasm_card_id", "")
	if orgasm_card_id != "" and not _is_card_installed(orgasm_card_id):
		set_aside_cards.append({"where": "build_orgasm_card", "card_id": orgasm_card_id, "build": build_name, "replaced_with": get_default_orgasm_card()})
		build["current_orgasm_card_id"] = get_default_orgasm_card()

### Puts back every set-aside card that is installed again. A selected slot (ally, Orgasm Card, an Action's reward card)
### only gets its card back if it still holds what it was set to meanwhile: a choice the player made since then wins.
### A card whose build preset was deleted meanwhile is dropped.
func _restore_set_aside_cards() -> void:
	var still_set_aside: Array = []
	for entry in set_aside_cards:
		var card_id: String = str(entry.get("card_id", ""))
		if not _is_card_installed(card_id):
			still_set_aside.append(entry)
			continue
		var build: Dictionary = _get_build_for_set_aside_entry(entry)
		match str(entry.get("where", "")):
			"owned":
				owned_event_cards[card_id] = int(owned_event_cards.get(card_id, 0)) + int(entry.get("count", 1))
			"orgasm_card":
				unlock_orgasm_card(card_id)
			"ally_card":
				if card_id not in owned_ally_cards:
					owned_ally_cards.append(card_id)
			"action_reward_card":
				var action_id: String = str(entry.get("action_id", ""))
				if action_id not in reward_cards_unlocked_for_actions.keys():
					reward_cards_unlocked_for_actions[action_id] = []
				if card_id not in reward_cards_unlocked_for_actions[action_id]:
					reward_cards_unlocked_for_actions[action_id].append(card_id)
			"selected_action_reward_card":
				var action_id: String = str(entry.get("action_id", ""))
				if str(reward_cards_from_actions.get(action_id, "")) == str(entry.get("replaced_with", "")):
					reward_cards_from_actions[action_id] = card_id
			"build_deck":
				if not build.is_empty():
					if not build.has("event_cards_deck"):
						build["event_cards_deck"] = {}
					var deck: Dictionary = build["event_cards_deck"]
					deck[card_id] = int(deck.get(card_id, 0)) + int(entry.get("count", 1))
			"build_ally_card":
				if not build.is_empty() and str(build.get("summon_ally_card", "")) == str(entry.get("replaced_with", "")):
					build["summon_ally_card"] = card_id
			"build_orgasm_card":
				if not build.is_empty() and str(build.get("current_orgasm_card_id", "")) == str(entry.get("replaced_with", "")):
					build["current_orgasm_card_id"] = card_id
	set_aside_cards = still_set_aside

### Actions of a disabled or removed mod, set aside like cards (set_aside_cards): moved out of owned_player_actions /
### currently_used_player_actions on every load, put back when the Action is installed again. Each entry:
### {"where": "owned" / "used", "action_id": ...}. Untyped and JSON-safe like all save data. The other places a save names an
### Action (its progress, its Reward Cards, its stats) are keyed by the id and only read for Actions the player has, so
### they are kept as they are.
var set_aside_actions: Array = []

func _is_action_installed(action_id: String) -> bool:
	return AutoloadDatabase.player_actions_by_id.has(action_id)

func _set_aside_actions_that_are_not_installed() -> void:
	for action_id in owned_player_actions.duplicate():
		if not _is_action_installed(action_id):
			set_aside_actions.append({"where": "owned", "action_id": action_id})
			owned_player_actions.erase(action_id)
	for action_id in currently_used_player_actions.duplicate():
		if not _is_action_installed(action_id):
			set_aside_actions.append({"where": "used", "action_id": action_id})
			currently_used_player_actions.erase(action_id)

func _restore_set_aside_actions() -> void:
	var still_set_aside: Array = []
	for entry in set_aside_actions:
		var action_id: String = str(entry.get("action_id", ""))
		if not _is_action_installed(action_id):
			still_set_aside.append(entry)
			continue
		var target_list: Array = owned_player_actions if str(entry.get("where", "")) == "owned" else currently_used_player_actions
		if action_id not in target_list:
			target_list.append(action_id)
	set_aside_actions = still_set_aside

### Passives of a disabled or removed mod, set aside like cards and Actions: moved out of player_owned_passives and every
### build's build_passives on every load, put back when the passive is installed again (a build preset deleted meanwhile is
### skipped). Each entry: {"where": "owned" / "build", "passive_id": ..., "build": ("" = the current build)}.
var set_aside_passives: Array = []

func _is_passive_installed(passive_id: String) -> bool:
	return AutoloadDatabase.passive_effect_definitions.has(passive_id)

func _set_aside_passives_that_are_not_installed() -> void:
	for passive_id in player_owned_passives.duplicate():
		if not _is_passive_installed(passive_id):
			set_aside_passives.append({"where": "owned", "passive_id": passive_id})
			player_owned_passives.erase(passive_id)
	_set_aside_build_passives(current_build, _BUILD_CURRENT)
	for build_name in saved_builds.keys():
		_set_aside_build_passives(saved_builds[build_name], build_name)

func _set_aside_build_passives(build: Dictionary, build_name: String) -> void:
	var build_passives: Array = build.get("build_passives", [])
	for passive_id in build_passives.duplicate():
		if not _is_passive_installed(passive_id):
			set_aside_passives.append({"where": "build", "passive_id": passive_id, "build": build_name})
			build_passives.erase(passive_id)

func _restore_set_aside_passives() -> void:
	var still_set_aside: Array = []
	for entry in set_aside_passives:
		var passive_id: String = str(entry.get("passive_id", ""))
		if not _is_passive_installed(passive_id):
			still_set_aside.append(entry)
			continue
		if str(entry.get("where", "")) == "owned":
			if passive_id not in player_owned_passives:
				player_owned_passives.append(passive_id)
			continue
		var build: Dictionary = _get_build_for_set_aside_entry(entry)
		if build.is_empty():
			continue
		if not build.has("build_passives"):
			build["build_passives"] = []
		if passive_id not in build["build_passives"]:
			build["build_passives"].append(passive_id)
	set_aside_passives = still_set_aside

### The build a set-aside entry belongs to; empty when it was a preset that has been deleted since.
func _get_build_for_set_aside_entry(entry: Dictionary) -> Dictionary:
	var build_name: String = str(entry.get("build", _BUILD_CURRENT))
	if build_name == _BUILD_CURRENT:
		return current_build
	return saved_builds.get(build_name, {})
#endregion

var retroactive_migrations_applied: Dictionary = {} ### migration ID (String) -> true, once applied

func _migration_already_applied(migration_id: String) -> bool:
	return migration_id in retroactive_migrations_applied.keys()

func _mark_migration_applied(migration_id: String) -> void:
	retroactive_migrations_applied[migration_id] = true

func _apply_analqueen_max_pleasure_buff() -> void:
	### Anal Queen's starting_max_pleasure was raised from 60 to 80 in 0.3.6. Saves made on
	### 0.3.5 or earlier that already picked her locked in the old, lower value - give them
	### the missing +20 once.
	var migration_id: String = "analqueen_max_pleasure_buff_0_3_6"
	if _migration_already_applied(migration_id):
		return
	if get_character_class() != "Anal Queen":
		return
	if Utils.compare_versions(game_version, "0.3.5") == Utils.VersionComparison.AFTER:
		return
	player["damage_threshold"] += 20
	_mark_migration_applied(migration_id)

func _add_missing_edging_threshold() -> void:
	### Saves from before Edging have no edging_threshold in their player stats (from_dict() takes the saved
	### dictionary as it is). get_edging_threshold() already falls back to the default; this writes it into the save.
	if not player.has("edging_threshold"):
		player["edging_threshold"] = EdgingRules.DEFAULT_THRESHOLD

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
			var passive_def: PassiveEffectDefinition = AutoloadDatabase.get_passive_effect_def(passive_id)
			if passive_def != null and passive_def.toggleable_by_player:
				continue ### The build's own choice wins - only non-toggleable passives are back-filled (same rule as give_player_passive).
			add_passive_to_build(build_name,passive_id)

func _remove_unowned_passives_from_saved_builds() -> void:
	### A passive the player no longer owns (e.g. pregnant_1 after giving birth) must not linger in saved builds -
	### selecting such a build would put it back in the active build.
	for build_name in get_saved_build_presets().keys():
		var build: Dictionary = get_saved_build_presets()[build_name]
		if "build_passives" not in build.keys():
			continue
		for passive_id in build["build_passives"].duplicate():
			if passive_id not in player_owned_passives:
				build["build_passives"].erase(passive_id)

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
			"build_passives": PLAYER_STARTER_PASSIVES.duplicate(true)
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

var auto_add_new_cards_to_deck: bool = true
func set_auto_add_new_cards_to_deck(enabled: bool) -> void:
	auto_add_new_cards_to_deck = enabled

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
		
		if not auto_add_new_cards_to_deck:
			continue
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
	"edging_threshold": EdgingRules.DEFAULT_THRESHOLD, # share of max pleasure (0..1), see EdgingRules
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
	player_power_changed.emit("stats_reward")

### The permanent edging threshold, as a share of max pleasure (0..1, see EdgingRules). This is what rewards change;
### an effect that only lowers it for one encounter edits the encounter's GameState copy instead (GameState.set_edging_threshold()).
func get_edging_threshold() -> float:
	return EdgingRules.clamp_threshold(float(player.get("edging_threshold", EdgingRules.DEFAULT_THRESHOLD)))

func set_edging_threshold(new_threshold: float) -> void:
	player["edging_threshold"] = EdgingRules.clamp_threshold(new_threshold)

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

func remove_passive_from_all_saved_builds(passive_id: String) -> void:
	for build_name in get_saved_build_presets().keys():
		var build: Dictionary = get_saved_build_presets()[build_name]
		if "build_passives" in build.keys():
			build["build_passives"].erase(passive_id)

func remove_passive_from_player(passive_id: String) -> void:
	if passive_id in current_build["build_passives"]:
		current_build["build_passives"].erase(passive_id)
	if passive_id in player_owned_passives:
		player_owned_passives.erase(passive_id)
	remove_passive_from_all_saved_builds(passive_id)

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
	
### A passive that isn't in the game (e.g. it came from a mod that is now disabled) counts as hidden,
### so the displays skip it. Its id stays in the save, so re-enabling the mod brings it back.
func passive_is_hidden_from_player(passive_id: String) -> bool:
	var passive_def: PassiveEffectDefinition = AutoloadDatabase.get_passive_effect_def(passive_id)
	if passive_def == null:
		return true
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

func get_owned_player_actions() -> Array:
	return owned_player_actions

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

#region Progressed player actions:
### Per-save progression of a PlayerAction's effects (Phase C of the player-action rework).
### action_id -> Array of EffectAndTargetIntent.to_json_dict() dicts, i.e. the action's FULL
### effect_intents list as progressed - a snapshot of everything the action does, not a delta. Only
### the effects are saved (not the whole PlayerAction: its Texture2D/ArtPart/reward-card fields
### aren't serializable by the generic serializer and never change per save anyway).
###
### An action with no entry here is simply "unprogressed" and follows its disk template, so balance
### patches reach it; once an entry exists it's frozen against changes to the template's effects.
### Untyped on purpose (see CLAUDE.md's typed-array-vs-JSON rule); stored as raw dicts and rebuilt
### lazily because rebuilding needs AutoloadDatabase loaded (ApplyStatusEffect resolves its status
### by id) and a save can be loaded before that finishes.
var player_action_progress: Dictionary = {}

### The same for a PlayerAction's triggered_components (its reactions while active): action_id -> Array of
### StatusTriggeredComponent.to_json_dict() dicts, the action's FULL list as progressed. Kept apart from
### player_action_progress on purpose: effects and triggers progress independently (an action with only one
### of the two progressed still follows its disk template for the other), and saves written before actions
### had triggers need no migration. Same rules otherwise: no entry = follows the template, untyped, rebuilt lazily.
var player_action_trigger_progress: Dictionary = {}

### action_id -> PlayerAction rebuilt from player_action_progress / player_action_trigger_progress. Not saved.
var _effective_player_action_cache: Dictionary = {}

### The PlayerAction as THIS save sees it: the disk template, or - if its effects or triggers have been
### progressed - a copy of it with the saved effect_intents / triggered_components swapped in. Use this (not
### AutoloadDatabase.get_player_action_by_id) anywhere the action's EFFECTS or TRIGGERS matter; static fields
### (name, costs, art, sounds, reward cards) are identical either way. Still a PlayerAction with the
### same action_id, so everything keyed on `effect_origin is PlayerAction` keeps working.
func get_effective_player_action(action_id: String) -> PlayerAction:
	var template: PlayerAction = AutoloadDatabase.get_player_action_by_id(action_id)
	if not template or not has_progressed_player_action(action_id):
		return template
	if _effective_player_action_cache.has(action_id):
		return _effective_player_action_cache[action_id]
	var effective: PlayerAction = template.duplicate() as PlayerAction
	if player_action_progress.has(action_id):
		var saved_intents: Array = player_action_progress[action_id]
		var intents: Array[EffectAndTargetIntent] = []
		for intent_dict in saved_intents:
			if intent_dict is Dictionary:
				var intent: ModExportable = ModdableResourceRegistry.instantiate(intent_dict)
				if intent is EffectAndTargetIntent:
					intents.append(intent)
		if intents.size() != saved_intents.size():
			### Never hand out a half-rebuilt action - an intent silently missing changes what the action does.
			push_warning("Could not rebuild all saved effects for player action '%s' - using its template instead." % action_id)
			return template
		effective.effect_intents = intents
	if player_action_trigger_progress.has(action_id):
		var saved_components: Array = player_action_trigger_progress[action_id]
		var components: Array[StatusTriggeredComponent] = []
		for component_dict in saved_components:
			if component_dict is Dictionary:
				var component: ModExportable = ModdableResourceRegistry.instantiate(component_dict)
				if component is StatusTriggeredComponent:
					components.append(component)
		if components.size() != saved_components.size():
			### Same reason as above - a trigger silently missing changes when the action fires.
			push_warning("Could not rebuild all saved triggers for player action '%s' - using its template instead." % action_id)
			return template
		effective.triggered_components = components
	_effective_player_action_cache[action_id] = effective
	return effective

func has_progressed_player_action(action_id: String) -> bool:
	return player_action_progress.has(action_id) or player_action_trigger_progress.has(action_id)

### Deep copies of the action's current effects (progressed or template) that are safe to edit -
### never edit get_effective_player_action()'s own intents, they're shared with the template/cache.
### Edit the copies, then hand them to set_progressed_effect_intents().
func get_effect_intents_copy_for_progression(action_id: String) -> Array[EffectAndTargetIntent]:
	var copies: Array[EffectAndTargetIntent] = []
	var action: PlayerAction = get_effective_player_action(action_id)
	if not action:
		return copies
	for intent in action.effect_intents:
		var copy: ModExportable = ModdableResourceRegistry.instantiate(intent.to_json_dict())
		if copy is EffectAndTargetIntent:
			copies.append(copy)
	return copies

### announce_change = false lets a reward that progresses several actions at once announce the change once,
### when it is done (announce_player_power_changed()), instead of once per action.
func set_progressed_effect_intents(action_id: String, intents: Array[EffectAndTargetIntent], announce_change: bool = true) -> void:
	if action_id not in AutoloadDatabase.player_actions_by_id.keys():
		push_error("Tried to progress non-existing player action: %s"%action_id)
		return
	var serialized: Array = []
	for intent in intents:
		serialized.append(intent.to_json_dict())
	player_action_progress[action_id] = serialized
	_effective_player_action_cache.erase(action_id)
	if announce_change:
		player_power_changed.emit("action_progression")

### Deep copies of the action's current triggers (progressed or template) that are safe to edit - the
### triggered_components counterpart of get_effect_intents_copy_for_progression(), same rules.
func get_triggered_components_copy_for_progression(action_id: String) -> Array[StatusTriggeredComponent]:
	var copies: Array[StatusTriggeredComponent] = []
	var action: PlayerAction = get_effective_player_action(action_id)
	if not action:
		return copies
	for component in action.triggered_components:
		var copy: ModExportable = ModdableResourceRegistry.instantiate(component.to_json_dict())
		if copy is StatusTriggeredComponent:
			copies.append(copy)
	return copies

### Stores `components` as the action's whole list of triggers for this save (frozen against changes to the
### template's triggers from then on), leaving its effects exactly as they were. See
### set_progressed_effect_intents() for announce_change.
func set_progressed_triggered_components(action_id: String, components: Array[StatusTriggeredComponent], announce_change: bool = true) -> void:
	if action_id not in AutoloadDatabase.player_actions_by_id.keys():
		push_error("Tried to progress non-existing player action: %s"%action_id)
		return
	var serialized: Array = []
	for component in components:
		serialized.append(component.to_json_dict())
	player_action_trigger_progress[action_id] = serialized
	_effective_player_action_cache.erase(action_id)
	if announce_change:
		player_power_changed.emit("action_progression")

### Undoes both kinds of progression: the action goes back to its disk template.
func reset_player_action_progress(action_id: String) -> void:
	player_action_progress.erase(action_id)
	player_action_trigger_progress.erase(action_id)
	_effective_player_action_cache.erase(action_id)
	player_power_changed.emit("action_progression")

func announce_player_power_changed(reason: String) -> void:
	player_power_changed.emit(reason)

#region Restoring action upgrades an older build threw away:
### reward id -> how many times that reward's effect on the player actions (RewardDefinition.changes_player_action_progress())
### has been applied to this save's player_action_progress / player_action_trigger_progress.
### Why it exists: builds from before player_action_progress existed (0.4.2 and older) write only the save keys they know, so
### loading a save there and letting it re-save drops the upgrades - while rewards_unlocked (a key they do know) still says the
### rewards were earned, so they can't be earned again. This ledger is dropped by those builds together with the upgrades, so on
### load whatever rewards_unlocked holds beyond the ledger is applied again (_restore_lost_action_progress()).
### Untyped on purpose (JSON round trip). Anything that undoes progression for good (like reset_player_action_progress()) must
### take the matching entries out of it too, or the undone upgrade is not rebuilt.
var action_progress_rewards_applied: Dictionary = {}

### False when the file this save was loaded from had no action_progress_rewards_applied key at all (see from_dict()).
var _action_progress_ledger_was_saved: bool = true

### Applies the reward to this save and notes it in the ledger when it changes the player actions. Every reward the game
### hands out goes through here instead of calling reward_def.apply_reward() itself, or its upgrade can't be rebuilt.
func apply_reward_and_record(reward_def: RewardDefinition) -> void:
	reward_def.apply_reward(self)
	if reward_def.changes_player_action_progress():
		increase_value_in_dictionary(action_progress_rewards_applied, reward_def.reward_id, 1)

### Part of the load migrations. Brings player_action_progress back in line with the rewards the save says were earned.
func _restore_lost_action_progress() -> void:
	if not _action_progress_ledger_was_saved:
		_action_progress_ledger_was_saved = true
		if not player_action_progress.is_empty() or not player_action_trigger_progress.is_empty():
			### Written by 0.4.3 / 0.4.4: they keep the upgrades but never knew the ledger, so every reward earned so far
			### is already in them. Replaying would double them.
			_note_all_earned_action_progress_rewards_as_applied()
			return
	var nr_of_rewards_reapplied: int = 0
	for reward_id in rewards_unlocked.keys():
		var reward_def: RewardDefinition = AutoloadDatabase.get_unlock_reward_definition(reward_id)
		if reward_def == null or not reward_def.changes_player_action_progress():
			continue
		var nr_of_times_missing: int = int(rewards_unlocked[reward_id]) - int(action_progress_rewards_applied.get(reward_id, 0))
		for _repeat in range(nr_of_times_missing):
			apply_reward_and_record(reward_def)
			nr_of_rewards_reapplied += 1
	if nr_of_rewards_reapplied > 0:
		print("Restored %d action upgrade reward(s) that an older version of the game had dropped from this save." % nr_of_rewards_reapplied)

func _note_all_earned_action_progress_rewards_as_applied() -> void:
	for reward_id in rewards_unlocked.keys():
		var reward_def: RewardDefinition = AutoloadDatabase.get_unlock_reward_definition(reward_id)
		if reward_def != null and reward_def.changes_player_action_progress():
			action_progress_rewards_applied[reward_id] = int(rewards_unlocked[reward_id])
#endregion
#endregion

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

### A reward's run conditions (UnlockCondition.is_judged_on_a_single_run()) can only be met at the moment a run ends, while the rest
### of the reward (clear 5 Office encounters, ...) may only be met earlier or later. So once ONE run has met all of a reward's run
### conditions together, that is remembered here and the reward only waits for its other conditions (RewardDefinition.are_all_conditions_met()).
### Kept in condition_tracking under "run_conditions_met:<reward id>": a free-form dictionary every older build writes back untouched,
### unlike a new save key (see action_progress_rewards_applied). Nothing is credited for runs made before this existed.
const RUN_CONDITIONS_MET_KEY_PREFIX: String = "run_conditions_met:"
func remember_run_conditions_met(reward_id: String) -> void:
	if reward_id == "":
		return
	condition_tracking[RUN_CONDITIONS_MET_KEY_PREFIX + reward_id] = true
func has_met_run_conditions(reward_id: String) -> bool:
	if reward_id == "":
		return false
	return condition_tracking.get(RUN_CONDITIONS_MET_KEY_PREFIX + reward_id, false) == true

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

##region Player customization
#region Player customization
var character_portrait_path: String = ""

var LEGACY_ASSET_PREFIX: String = "res://assets"
var NEW_CONTENT_PACK_ASSET_PREFIX: String = "res://content_packs/00_real_porn_035_and_earlier/assets"
var DEFAULT_PORTRAIT_PATH: String = "res://content_packs/00_real_porn_035_and_earlier/assets/player_profile_pics/emily.jpeg"

func change_portrait_path(new_path: String) -> void:
	character_portrait_path = new_path

func get_character_portrait() -> Texture2D:
	var resolved_path: String = _resolve_portrait_path(character_portrait_path)
	return Utils.load_texture_from_path(resolved_path, load(DEFAULT_PORTRAIT_PATH))

func _resolve_portrait_path(path: String) -> String:
	if path.begins_with(LEGACY_ASSET_PREFIX):
		return path.replace(LEGACY_ASSET_PREFIX, NEW_CONTENT_PACK_ASSET_PREFIX)
	return path


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

### Best results per encounter, kept so unlock conditions that depend on a single winning run can show the
### player how close they are (see UnlockCondition.get_progress_current()). encounter ID -> {record key: number}.
### Only filled by winning runs, and only from the version that added it: results from earlier runs are not
### known. Untyped on purpose (JSON round trip), so numbers come back as floats - read through
### get_encounter_record().
var encounter_records: Dictionary = {}

### The report of the encounter the player is in the middle of. NOT part of the save: it is only set on the
### temporary copy of the save that the in-encounter rewards panel builds (RewardsForActiveEncounter), so the
### progress counters of encounter conditions can show how the current run is going (e.g. "1/2" cards played)
### instead of the best earlier result. See UnlockCondition.get_in_progress_report().
var in_progress_encounter_report: EncounterReport = null

const RECORD_BEST_SIMULTANEOUS_CUM: String = "best_simultaneous_cum" ### highest = best
const RECORD_MOST_ORGASMS: String = "most_orgasms" ### highest = best
const RECORD_FEWEST_ORGASMS: String = "fewest_orgasms" ### lowest = best
const RECORD_FASTEST_WIN_TURN: String = "fastest_win_turn" ### lowest = best
const RECORD_MOST_CARDS_IN_ONE_TURN: String = "most_cards_in_one_turn" ### highest = best
const RECORD_LOWEST_PEAK_PLEASURE_PERCENT: String = "lowest_peak_pleasure_percent" ### lowest = best
const RECORD_MOST_DEFEATS_BY_SOURCE_PREFIX: String = "most_defeats_by_source_" ### + DefeatSourceKind, highest = best

static func get_defeats_by_source_record_key(kind: EncounterReport.DefeatSourceKind) -> String:
	return RECORD_MOST_DEFEATS_BY_SOURCE_PREFIX + str(int(kind))

### The stored best result, or default_value if no winning run has recorded one.
func get_encounter_record(encounter_id: String, record_key: String, default_value: int = -1) -> int:
	if encounter_id not in encounter_records.keys():
		return default_value
	var records: Dictionary = encounter_records[encounter_id]
	if record_key not in records.keys():
		return default_value
	return int(records[record_key])

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
#region Selected map
### The map shown in the overworld (AutoloadDatabase.MAIN_MAP_ID or a mod map's map_id, see MetaGame.select_map()).
### Kept as saved even while its mod is disabled (AutoloadDatabase.set_active_map() falls back to the main map), so the
### choice comes back when the mod does. Older builds drop the key: the save then opens on the main map.
var selected_map_id: String = ""
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
		"player_action_progress":player_action_progress,
		"player_action_trigger_progress":player_action_trigger_progress,
		"action_progress_rewards_applied":action_progress_rewards_applied,
		"rewards_unlocked":rewards_unlocked,
		"reward_cards_unlocked_for_actions":reward_cards_unlocked_for_actions,
		"reward_cards_from_actions":reward_cards_from_actions,
		"action_stats":action_stats,
		"player": player,
		"min_deck_size":min_deck_size,
		"auto_add_new_cards_to_deck":auto_add_new_cards_to_deck,
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
		"encounter_records": encounter_records,
		"current_build": current_build,
		"saved_builds": saved_builds,
		"selected_character_id": selected_character_id,
		"character_class_name":character_class_name,
		"character_video_particpatipant_tags":character_video_particpatipant_tags,
		"triggered_effects_tracking":triggered_effects_tracking,
		"rewards_unlocked_during_last_encounter":rewards_unlocked_during_last_encounter,
		"owned_ally_cards":owned_ally_cards,
		"retroactive_migrations_applied":retroactive_migrations_applied,
		"selected_map_id":selected_map_id,
		"set_aside_cards":set_aside_cards,
		"set_aside_actions":set_aside_actions,
		"set_aside_passives":set_aside_passives,
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
	player_action_progress = data.get("player_action_progress", {})
	player_action_trigger_progress = data.get("player_action_trigger_progress", {})
	action_progress_rewards_applied = data.get("action_progress_rewards_applied", {})
	_action_progress_ledger_was_saved = data.has("action_progress_rewards_applied")
	_effective_player_action_cache.clear()
	rewards_unlocked = data.get("rewards_unlocked", {})
	reward_cards_unlocked_for_actions = data.get("reward_cards_unlocked_for_actions", {})
	reward_cards_from_actions = data.get("reward_cards_from_actions", {})
	action_stats = data.get("action_stats", {})
	player = data.get("player", _default_player.duplicate(true))
	min_deck_size = data.get("min_deck_size", _default_min_deck_size)
	auto_add_new_cards_to_deck = data.get("auto_add_new_cards_to_deck", true)
	game_version = data.get("game_version",_default_game_version)
	custom_encounter_state = data.get("custom_encounter_state",{})
	selected_map_id = str(data.get("selected_map_id", ""))
	set_aside_cards = data.get("set_aside_cards", [])
	set_aside_actions = data.get("set_aside_actions", [])
	set_aside_passives = data.get("set_aside_passives", [])
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
	encounter_records = data.get("encounter_records",{})
	current_build = data.get("current_build",DEFAULT_CURRENT_BUILD.duplicate(true))
	saved_builds = data.get("saved_builds",{"Starter Build":DEFAULT_CURRENT_BUILD.duplicate(true)})
	selected_character_id = data.get("selected_character_id","emily")
	character_class_name = data.get("character_class_name","College Slut")
	character_video_particpatipant_tags = data.get("character_video_particpatipant_tags",[])
	triggered_effects_tracking = data.get("triggered_effects_tracking",{})
	rewards_unlocked_during_last_encounter = data.get("rewards_unlocked_during_last_encounter",[])
	owned_ally_cards = data.get("owned_ally_cards",[])
	retroactive_migrations_applied = data.get("retroactive_migrations_applied",{})
	
#region Handling encounter reports:
func apply_encounter_report(report: EncounterReport) -> void:
	_apply_encounters_completed(report)
	_apply_opponents_defeated(report)
	_apply_event_cards_played(report)
	_apply_action_usage_stats(report)
	_apply_orgasms_achieved(report)
	_apply_opponents_defeated_simultaneously(report)
	_apply_encounter_records(report)

### Updates the best results of the encounter this report is for. Winning runs only: every condition that
### uses these requires a win.
func _apply_encounter_records(report: EncounterReport) -> void:
	if not report.player_won or not report.encounter_def:
		return
	var encounter_id: String = report.encounter_def.encounter_id
	if encounter_id == "":
		return
	if encounter_id not in encounter_records.keys():
		encounter_records[encounter_id] = {}
	var records: Dictionary = encounter_records[encounter_id]
	_raise_record(records,RECORD_BEST_SIMULTANEOUS_CUM,report.get_max_opponents_defeated_in_one_turn())
	_raise_record(records,RECORD_MOST_ORGASMS,report.orgasms_achieved)
	_lower_record(records,RECORD_FEWEST_ORGASMS,report.orgasms_achieved)
	_lower_record(records,RECORD_FASTEST_WIN_TURN,report.final_round_number)
	_raise_record(records,RECORD_MOST_CARDS_IN_ONE_TURN,report.get_most_cards_played_in_one_turn())
	_lower_record(records,RECORD_LOWEST_PEAK_PLEASURE_PERCENT,int(ceil(report.highest_player_pleasure_percent)))
	for kind in EncounterReport.DefeatSourceKind.values():
		_raise_record(records,get_defeats_by_source_record_key(kind),report.get_nr_of_defeats_by_source(kind))

func _raise_record(records: Dictionary, record_key: String, value: int) -> void:
	if record_key not in records.keys() or value > int(records[record_key]):
		records[record_key] = value

func _lower_record(records: Dictionary, record_key: String, value: int) -> void:
	if record_key not in records.keys() or value < int(records[record_key]):
		records[record_key] = value

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
