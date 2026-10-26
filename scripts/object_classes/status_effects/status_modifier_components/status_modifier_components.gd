@tool
extends ModExportable
class_name StatusModifierComponent

@export var status_modifer_component_id: String

func modify_context(_effect_context: EffectContext) -> void:
	pass

### True when the effect's source and target are the same entity (the player giving themselves pleasure, an opponent
### hurting itself). Compared by WHO they are (get_tracker_key()), not by object: the targeting code often builds a fresh
### entity object for the same player or opponent, so an object comparison can miss a self-directed hit.
static func is_self_directed(context: EffectContext) -> bool:
	if context.source == null or context.target == null:
		return false
	return context.source.get_tracker_key() == context.target.get_tracker_key()

### Scales a damage multiplier with the stack count of the status running the modifier (opt-in via a
### component's scale_with_stacks export; pass context.modifier_effect_stacks). Multiplicative, the same as
### if the status had been applied once per stack: two statuses of x0.5 give x0.25, so x0.5 is x0.25 at 2
### stacks and x0.125 at 3, and x1.5 is x2.25 at 2 stacks. (An inversion, x-1, cancels itself on even stacks.)
static func scale_multiplier_by_stacks(multiplier: float, stacks: int) -> float:
	if stacks <= 1:
		return multiplier
	return pow(multiplier, stacks)

### Additive counterpart of scale_multiplier_by_stacks(): every stack adds the same share of the base amount, so +25% per
### stack is x1.25 at 1 stack, x1.5 at 2 and x1.75 at 3 (multiplicative would be x1.25, x1.5625, x1.953). Never below 0.
### pass context.modifier_effect_stacks.
static func get_additive_multiplier_for_stacks(increase_per_stack: float, stacks: int) -> float:
	return maxf(1.0 + increase_per_stack * float(maxi(stacks, 1)), 0.0)

### Generic description support (see DescriptionBuilder). Base fallback for any modifier that
### hasn't been given a real description yet - same bracketed-placeholder convention as
### EffectIntent.get_description_segments(), an obvious coverage-gap marker rather than silently
### showing nothing.
func get_description_segments() -> Array[DescriptionSegment]:
	return [DescriptionSegment.text_segment("[%s]" % get_script().get_global_name())]

### The same description for a status that has this many stacks right now (0 = not known): a modifier whose strength depends on
### the stacks overrides this to show what it comes to at that count. Everything else describes itself as usual.
func get_description_segments_for_stacks(_stacks: int) -> Array[DescriptionSegment]:
	return get_description_segments()

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
