extends Resource
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

#@export var reward_cards_from_defeat: Array[String] = []

func card_requires_targeted_opponent() -> bool:
	for effect_intent in effect_intents:
		if effect_intent.targeting_intent == TargetingSystem.TargetingMode.SINGLE_OPPONENT:
			return true
	return false

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
