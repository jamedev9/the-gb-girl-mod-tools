@tool
extends ModExportable
class_name StatusModifierComponent

@export var status_modifer_component_id: String

func modify_context(_effect_context: EffectContext) -> void:
	pass

### Generic description support (see DescriptionBuilder). Base fallback for any modifier that
### hasn't been given a real description yet - same bracketed-placeholder convention as
### EffectIntent.get_description_segments(), an obvious coverage-gap marker rather than silently
### showing nothing.
func get_description_segments() -> Array[DescriptionSegment]:
	return [DescriptionSegment.text_segment("[%s]" % get_script().get_global_name())]

### Shared id-list-to-name-list resolution for subclass descriptions - avoids repeating the same
### AutoloadDatabase lookup + DescriptionBuilder.join_with_and() in every subclass. use_or
### defaults FALSE here (unlike TriggerCondition's equivalent helpers, which default true) -
### these describe a standing modifier that applies to every listed id at once ("your Blowjob
### and Vaginal deal more Pleasure"), not a single event that could match any one of them.
static func _action_names(action_ids: Array[String], use_or: bool = false) -> String:
	var names: Array[String] = []
	for id in action_ids:
		var action_def: PlayerAction = AutoloadDatabase.get_player_action_by_id(id)
		names.append(action_def.get_action_name() if action_def else "?")
	return DescriptionBuilder.join_with_and(names, use_or)

static func _card_names(card_ids: Array[String], use_or: bool = false) -> String:
	var names: Array[String] = []
	for id in card_ids:
		var card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id.get(id, null)
		names.append(card_def.get_card_name() if card_def else "?")
	return DescriptionBuilder.join_with_and(names, use_or)

static func _passive_names(passive_ids: Array[String], use_or: bool = false) -> String:
	var names: Array[String] = []
	for id in passive_ids:
		var passive_def: PassiveEffectDefinition = AutoloadDatabase.passive_effect_definitions.get(id, null)
		names.append(passive_def.get_effect_name() if passive_def else "?")
	return DescriptionBuilder.join_with_and(names, use_or)

static func _opponent_type_names(opponent_type_ids: Array[String], use_or: bool = false) -> String:
	var names: Array[String] = []
	for id in opponent_type_ids:
		var opponent_type: OpponentType = AutoloadDatabase.opponent_types.get(id, null)
		names.append(opponent_type.get_opponent_type_name() if opponent_type else "?")
	return DescriptionBuilder.join_with_and(names, use_or)

### "X deals"/"X and Y deal" - resolves the right verb form for a name list built from the
### helpers above, so a multi-name list doesn't read with a mismatched singular verb (the same
### class of bug flagged in Handjob/Handjobs - see effect_and_target_intent.gd's
### _pluralize_trailing_word()). singular_key/plural_key are translation keys for the bare verb
### ("deals"/"deal", "is"/"are").
static func _agreement_verb(count: int, singular_key: String, plural_key: String) -> String:
	return TranslationServer.translate(singular_key if count == 1 else plural_key)
