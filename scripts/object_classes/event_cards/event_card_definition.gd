@tool
extends ModExportable
class_name EventCardDefinition

@export var card_type_id: String
@export var card_name: String
@export var description: String
@export var card_picture: Texture2D

enum CardCategory {
	CUCK, #related to the BF path. Focused on healing effects
	SEX_TOYS, #items. focused on buffs/debuffs
	CREATIVITY, #foucsed on card draw/cycling effects,
	DEPRAVITY, #focused on extreme sexual acts, giving extra pleasure to opponents
	REWARD,
	COMBO,
	PROBLEM,
	ORGASM_REWARD,
	NEEDS, # focused on player orgasms and pleasure,
	DIRTY_TALK,
	SUMMON_ALLY # Only one can be active in the deck at a time
}
@export var category: CardCategory

@export var once_per_game: bool = false
@export var always_in_opening_hand: bool = false

@export var energy_cost: int

@export var effect_intents: Array[EffectAndTargetIntent]

@export var video_action_tags: Array[VideoClip.ActionTags] = []
@export var video_participant_tags: Array[VideoClip.ParticipantTags] = []

@export var sound_effects: Array[AudioStreamsForSoundEffect] # Multiple effects are played at the same time

const MAX_ENERGY_COST: int = 100
#@export var reward_cards_from_defeat: Array[String] = []

var resoruce_type_string: String = "EVENTCARDDEFINITION_"

#region Localization:
func get_card_name() -> String:
	var key_string: String = _get_card_name_translation_key_string()
	return tr(key_string)

func get_card_description() -> String:
	var key_string:String = _get_description_key_string()
	return tr(key_string)

func _get_description_key_string() -> String:
	return resoruce_type_string+_get_name_string()+"_DESCRIPTION"

func _get_card_name_translation_key_string() -> String:
	var name_string: String = _get_name_string()
	var key_string: String = resoruce_type_string+name_string+"_CARD_NAME"
	return key_string

func _get_name_string() -> String:
	return card_type_id.to_upper()

func get_translation_entries() -> Array[Dictionary]:
	return [
		{"key": _get_card_name_translation_key_string(), "text": card_name},
		{"key": _get_description_key_string(), "text": description},
	]


func card_requires_targeted_opponent() -> bool:
	for effect_intent in effect_intents:
		if effect_intent.targeting_intent == TargetingSystem.TargetingMode.SINGLE_OPPONENT:
			return true
	return false

### Combo/Orgasm cards are earned through play and meant to stick around - never let a random
### discard effect take them.
func is_immune_to_random_discard() -> bool:
	return category == CardCategory.COMBO or category == CardCategory.ORGASM_REWARD

func get_sound_effects_to_play_on_resoluion() -> Array[AudioStream]:
	var streams: Array[AudioStream] = []
	for list in sound_effects:
		streams.append(list.get_random_stream())
	return streams

func get_actions_triggered_by_card() -> Array[String]: #id of player actions
	var actions: Array[String] = []
	for intent_and_effect in effect_intents:
		var effect = intent_and_effect.effect_intent
		match effect.get_script():
			ApplyEffectOfPlayerAction:
				actions.append(effect.player_action_id)
	return actions

func are_all_relevant_player_actions_disabled(game_state:GameState) -> bool:
	var required_actions: Array[String] = get_actions_triggered_by_card()
	if required_actions.is_empty():
		return false
	var disabled_actions: Array[String] = []
	var player_statuses = game_state.get_player_statuses()
	for active_status in player_statuses:
		var status_def: StatusEffectDefinition = AutoloadDatabase.status_effects_by_id[active_status]
		for component in status_def.status_effect_components:
			if component is not Status_DisablePlayerActions:
				continue 
			for action in required_actions:
				if action in component.disabled_action_ids:
					disabled_actions.append(action)
					
	return required_actions == disabled_actions

func get_summoned_ally_opponent_type_id() -> String:
	if self.category != CardCategory.SUMMON_ALLY:
		return ""
	for intent in effect_intents:
		if intent.effect_intent is Intent_SummonOpponent:
			return intent.effect_intent.opponent_type_id
	return ""

func card_cant_target_opponent_with_action() -> bool:
	for effect_intent in effect_intents:
		if effect_intent.targeting_intent == TargetingSystem.TargetingMode.RULE_BASED:
			for rule in effect_intent.targeting_rules:
				if rule.get_script() == TargetsHaveOneOfSeveralActionsAssigned:
					return true
	return false

static func get_energy_cost_of_playing_card(game_state: GameState,card_id: String) -> int:
	var event_card_def: EventCardDefinition = AutoloadDatabase.get_event_card_def_by_id(card_id)
	var base_cost: int = event_card_def.energy_cost
	return clamp(base_cost + get_event_card_energy_mod_from_player_effects(game_state,event_card_def),0,MAX_ENERGY_COST)

static func get_event_card_energy_mod_from_player_effects(
	game_state: GameState,event_card_def: EventCardDefinition) -> int:
	var return_count: int = 0
	var player_statuses = game_state.get_player_statuses()
	for active_status in player_statuses:
		var status_def: StatusEffectDefinition = AutoloadDatabase.status_effects_by_id[active_status]
		for component in status_def.get_modifier_components():
			if component is not Status_ChangeCostOfPlayingEventCards:
				#print("component is not ChangeCostOfPlayingCards")
				continue 
			if component.all_cards:
				return_count += component.get_energy_delta(game_state)
				continue
			for card_id in component.get_list_of_cards():
				#print("Found passive modifying event card energy: %s"%component.status_modifier_component_id)
				if card_id == event_card_def.card_type_id:
					return_count += component.get_energy_delta(game_state)
				
	var player_passives = game_state.get_active_player_passives()
	for passive_id in player_passives:
		#print("Checking passive %s"%passive_id)
		var passive_def: PassiveEffectDefinition = AutoloadDatabase.get_passive_effect_def(passive_id)
		for component in passive_def.get_modifier_components():
			#print("Found component: %s"%component.status_modifer_component_id)
			if component is not Status_ChangeCostOfPlayingEventCards:
				#print("component is not ChangeCostOfPlayingCards")
				continue 
			if component.all_cards:
				return_count += component.get_energy_delta(game_state)
				continue
			for card_id in component.get_list_of_cards():
				#print("Found passive modifying event card energy: %s"%component.status_modifier_component_id)
				if card_id == event_card_def.card_type_id:
					return_count += component.get_energy_delta(game_state)
	
	#print("Returning modifying count: %s"%return_count)
	return return_count

func card_targets_opponent_with_action() -> bool:
	for effect_intent in effect_intents:
		if effect_intent.targeting_intent == TargetingSystem.TargetingMode.RULE_BASED:
			for rule in effect_intent.targeting_rules:
				if rule.get_script() == TargetsHaveOneOfSeveralActionsAssigned:
					return true
	return false

func required_actions_are_active_on_opponents(game_state: GameState) -> bool:
	for effect_intent in effect_intents:
		if effect_intent.targeting_intent == TargetingSystem.TargetingMode.RULE_BASED:
			for rule in effect_intent.targeting_rules:
				if rule is TargetsHaveOneOfSeveralActionsAssigned:	
					var action_ids = rule.action_ids
					for action in action_ids:
						if action not in game_state.actions_assigned_to_opponents.keys():
							return false
	return true
	
func get_opponents_with_one_of_required_actions(game_state: GameState) -> Array[String]:
	var opponents_with_actions: Array[String] = [] ### ZZZZ
	for effect_intent in effect_intents:
		if effect_intent.targeting_intent == TargetingSystem.TargetingMode.RULE_BASED:
			for rule in effect_intent.targeting_rules:
				if rule is TargetsHaveOneOfSeveralActionsAssigned:	
					var action_ids = rule.action_ids
					for action in action_ids:
						var opponent_id: String = game_state.get_opponent_with_action(action)
						if opponent_id != "":
							opponents_with_actions.append(opponent_id)
	return opponents_with_actions

func get_effect_intents() -> Array[EffectAndTargetIntent]:
	return effect_intents

func get_mod_export_subfolder() -> String:
	return "event_cards"

func get_file_reference_fields() -> Dictionary:
	return {"card_picture": "images"}

### Hand-written rather than the generic ModExportable default because card_picture: Texture2D
### is a file reference, not embeddable data - see get_file_reference_fields() above.
func to_json_dict() -> Dictionary:
	var intent_dicts: Array = []
	for intent in effect_intents:
		intent_dicts.append(intent.to_json_dict())

	var result: Dictionary = {
		"_class": get_script().get_global_name(),
		"card_type_id": card_type_id,
		"card_name": card_name,
		"description": description,
		"card_picture": ModExportable.resolve_to_res_path(card_picture.resource_path) if card_picture else "",
		"category": CardCategory.keys()[category],
		"once_per_game": once_per_game,
		"always_in_opening_hand": always_in_opening_hand,
		"energy_cost": energy_cost,
		"effect_intents": intent_dicts,
	}
	if self is ComboEventCardDefinition:
		var combo_self := self as ComboEventCardDefinition
		result["required_action_ids"] = combo_self.required_action_ids
		result["priority"] = combo_self.priority
	return result

### Reconstructs the correct subclass (EventCardDefinition, RewardEventCardDefinition, or
### OrgasmEventCardDefinition) from the "_class" tag written by to_json_dict() above - same tag
### convention as everything else in ModExportable, just dispatched by hand here since this class
### needs file-reference handling the generic path (ModdableResourceRegistry.instantiate(), which
### always calls the generic populate_from_json_dict()) can't provide.
static func from_json_dict(data: Dictionary, mod_folder_path: String = "") -> EventCardDefinition:
	var card_def: EventCardDefinition
	match data.get("_class", "EventCardDefinition"):
		"OrgasmEventCardDefinition":
			card_def = OrgasmEventCardDefinition.new()
		"RewardEventCardDefinition":
			card_def = RewardEventCardDefinition.new()
		"ComboEventCardDefinition":
			card_def = ComboEventCardDefinition.new()
		"ProblemEventCardDefinition":
			card_def = ProblemEventCardDefinition.new()
		_:
			card_def = EventCardDefinition.new()
	card_def.card_type_id = data.get("card_type_id", "")
	card_def.card_name = data.get("card_name", "")
	card_def.description = data.get("description", "")
	card_def.once_per_game = data.get("once_per_game", false)
	card_def.always_in_opening_hand = data.get("always_in_opening_hand", false)
	card_def.energy_cost = int(data.get("energy_cost", 0))

	var category_name: String = data.get("category", "")
	var matched_category_key: String = ModExportable.find_case_insensitive_enum_key(CardCategory.keys(), category_name)
	if matched_category_key != "":
		card_def.category = CardCategory[matched_category_key]

	var picture_file_name: String = data.get("card_picture", "")
	if picture_file_name != "" and mod_folder_path != "":
		card_def.card_picture = Utils.load_texture_from_path(mod_folder_path.path_join(picture_file_name))

	for intent_data in data.get("effect_intents", []):
		var intent: EffectAndTargetIntent = ModdableResourceRegistry.instantiate(intent_data) as EffectAndTargetIntent
		if intent:
			card_def.effect_intents.append(intent)

	if card_def is ComboEventCardDefinition:
		var combo_def := card_def as ComboEventCardDefinition
		var ids: Array[String] = []
		for id in data.get("required_action_ids", []):
			ids.append(str(id))
		combo_def.required_action_ids = ids
		combo_def.priority = int(data.get("priority", 0))

	return card_def
