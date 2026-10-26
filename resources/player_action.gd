extends Resource
class_name PlayerAction

@export var action_id: String
@export var action_name: String
@export var picture: Texture2D
@export var opponent_art_parts: Array[ArtPart] = [] ### Layers drawn over the reworked opponent card's visuals while active

@export var move_energy: int
@export var energy_per_round: int

### What this action does each round it's active on an opponent, same shape as
### OpponentActionDefinition/EventCardDefinition. Convention for authored actions: intents that act
### on the opponent the action is placed on use targeting_intent SINGLE_OPPONENT - an action's
### effects resolve against whichever opponent it's being triggered on (see
### MainCardgame._resolve_effects_of_player_action(), which supplies it as dropped_on_opponent), which
### isn't always the one it's assigned to (e.g. Double Vaginal triggers Vaginal on a different opponent).
@export var effect_intents: Array[EffectAndTargetIntent] = []

### Reactions while this action is active on an opponent (assigned to one), same shape as a passive/status's
### triggered components: when a trigger condition is met by an effect that just resolved, the component's
### effect_intents run (EffectContextManager._trigger_active_player_actions()). The source of such a reaction
### is the player. To make the action trigger itself, use an ApplyEffectOfPlayerAction intent for this
### action_id with the RULE_BASED targeting rule TargetsHaveOneOfSeveralActionsAssigned([action_id]).
### Read a save's version via SaveGameState.get_effective_player_action(): a save can have its own list.
@export var triggered_components: Array[StatusTriggeredComponent] = []

@export var event_cards_awarded_when_target_is_defeated: Array[EventCardDefinition]

@export var video_action_tags: Array[VideoClip.ActionTags] = []
@export var log_text_when_started: String = ""
@export var log_text_when_ended: String = ""

@export var looping_sound_category: SoundManager.LoopingCategory = SoundManager.LoopingCategory.NONE
@export var start_sound_effect: SoundManager.SoundEffects = SoundManager.SoundEffects.NONE

### The Pleasure number shown on the action card - derived from effect_intents the same way the
### opponent card derives its upcoming-action number, except Pleasure the action gives the player
### (a PLAYER-targeted intent) isn't part of it.
func get_displayed_damage() -> int:
	return EffectAndTargetIntent.sum_displayed_damage(effect_intents, true)

### Statuses shown as icons on the action card.
func get_displayed_statuses() -> Array[ApplyStatusEffect]:
	var statuses: Array[ApplyStatusEffect] = []
	for intent in effect_intents:
		if intent and intent.effect_intent is ApplyStatusEffect:
			statuses.append(intent.effect_intent)
	return statuses

### Generated description of everything this action does. What it does each
### round first, then a Triggers section ("When {condition}: {effect}.") if it reacts to anything.
func get_description_segments() -> Array[DescriptionSegment]:
	var segments: Array[DescriptionSegment] = EffectAndTargetIntent.describe_all(effect_intents)
	if triggered_components.is_empty():
		return segments
	var trigger_lines: Array = []
	for component in triggered_components:
		trigger_lines.append(EffectDefinition.trigger_line(component.get_when_description_segments(), component.effect_intents))
	if not segments.is_empty():
		segments.append(DescriptionSegment.text_segment("\n\n"))
	segments.append_array(EffectDefinition.tooltip_section("EFFECTDEFINITION_TRIGGERS_HEADER", trigger_lines))
	return segments

func get_action_name() -> String:
	return tr("PLAYERACTION_"+action_id.to_upper()+"_ACTION_NAME")

func get_log_text_when_started() -> String:
	return tr("PLAYERACTION_"+action_id.to_upper()+"_LOG_TEXT_WHEN_STARTED")

func get_translation_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = [
		{"key": "PLAYERACTION_"+action_id.to_upper()+"_ACTION_NAME", "text": action_name},
	]
	if log_text_when_started != "":
		entries.append({"key": "PLAYERACTION_"+action_id.to_upper()+"_LOG_TEXT_WHEN_STARTED", "text": log_text_when_started})
	return entries
