@tool
extends ModExportable
class_name TriggerCondition

@export var trigger_condition_id: String

func is_condition_met(
	input_context: EffectContext,
	game_state: GameState
	,save_game_state: SaveGameState,
	owner_of_trigger: TargetEntity) -> bool:
		### Overwritten by child classes.
		return false

### Generic description support (see DescriptionBuilder). Base fallback for any condition that
### hasn't been given a real description yet - same bracketed-placeholder convention as
### EffectIntent.get_description_segments().
func get_description_segments() -> Array[DescriptionSegment]:
	return [DescriptionSegment.text_segment("[%s]" % get_script().get_global_name())]

### Shared id-list-to-name-list resolution for subclass descriptions - avoids repeating the same
### AutoloadDatabase lookup + DescriptionBuilder.join_with_and() in every subclass. use_or
### defaults true since almost every id list here is "any one of these" membership-check
### semantics (see e.g. TriggerCondition_OnlyIfTargetHasOneOfListedPlayerActions's own name).
static func _action_names(action_ids: Array[String], use_or: bool = true) -> String:
	var names: Array[String] = []
	for id in action_ids:
		var action_def: PlayerAction = AutoloadDatabase.get_player_action_by_id(id)
		names.append(action_def.get_action_name() if action_def else "?")
	return DescriptionBuilder.join_with_and(names, use_or)

static func _card_names(card_ids: Array[String], use_or: bool = true) -> String:
	var names: Array[String] = []
	for id in card_ids:
		var card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id.get(id, null)
		names.append(card_def.get_card_name() if card_def else "?")
	return DescriptionBuilder.join_with_and(names, use_or)

static func _effect_names(status_ids: Array[String], passive_ids: Array[String], use_or: bool = true) -> String:
	var names: Array[String] = []
	for id in status_ids:
		var status_def: StatusEffectDefinition = AutoloadDatabase.status_effects_by_id.get(id, null)
		names.append(status_def.get_effect_name() if status_def else "?")
	for id in passive_ids:
		var passive_def: PassiveEffectDefinition = AutoloadDatabase.passive_effect_definitions.get(id, null)
		names.append(passive_def.get_effect_name() if passive_def else "?")
	return DescriptionBuilder.join_with_and(names, use_or)

### Joins a list of TriggerConditions into one "when" clause with and/or (based on
### only_require_one) - shared by StatusTriggeredComponent.get_when_description_segments() and
### OpponentActionDefinition.get_description_segments(), which have the exact same
### trigger_conditions/only_require_one_condition shape and the same and/all-vs-or/any-one
### semantics. An empty list shouldn't happen for real content (both callers' own
### should-this-trigger logic treats an empty list as "never"), so this is a bracketed
### placeholder rather than silently returning nothing.
static func describe_conditions(conditions: Array[TriggerCondition], only_require_one: bool) -> Array[DescriptionSegment]:
	if conditions.is_empty():
		return [DescriptionSegment.text_segment("[no trigger conditions]")]
	var condition_segment_lists: Array = []
	for condition in conditions:
		condition_segment_lists.append(condition.get_description_segments())
	var conjunction: String = TranslationServer.translate(
		"STATUSTRIGGEREDCOMPONENT_OR_JOINER" if only_require_one else "STATUSTRIGGEREDCOMPONENT_AND_JOINER")
	return DescriptionBuilder.join_segment_lists_with_conjunction(condition_segment_lists, conjunction)
