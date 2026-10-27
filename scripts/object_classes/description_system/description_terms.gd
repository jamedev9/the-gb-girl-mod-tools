extends RefCounted
class_name DescriptionTerms

### Builds the linkable game-term segments for description-system text: a NESTED DescriptionSegment per term, with the term's
### name as the label and the segments its tooltip shows (see Tooltip_DescriptionTerm).
###
### Hand-written texts (a status's or passive's description, a Move's description, ...) name these terms with prefixed tokens that
### DescriptionBuilder.parse_template() resolves through from_token():
###   {STATUS:denied}  {PASSIVE:birth_control}  {ACTION:vaginal}  {CARD:hold_the_tide}  {MOVE:some_opponent_action_id}
### (the id is the resource's own id). Keywords need no prefix: write {PLEASURE}.
###
### Which description a term's tooltip shows follows the same rule as the existing tooltips: the generated description, except for a
### secret effect (has_secret_description) or one with nothing to generate, which show the hand-written text (which can itself hold tokens).
### Player actions have no hand-written text, so their generated description always shows.
### An unknown id gives the id as plain text, so a typo never breaks a description (and shows up as a visible, link-less word).

### Terms being built right now ("STATUS:denied"): a description that names a term whose description names the first one again
### would otherwise build forever. The repeat is left as plain text.
static var _terms_in_progress: Array[String] = []

const KIND_STATUS: String = "STATUS"
const KIND_PASSIVE: String = "PASSIVE"
const KIND_ACTION: String = "ACTION"
const KIND_CARD: String = "CARD"
const KIND_MOVE: String = "MOVE"

### The segment for a {KIND:id} token (kind in any case). card_hints (card id -> CardInstance.CardPermanence, see
### card_permanence_hints()) is what a {CARD:id} token looks like in its tooltip; a card with no hint looks like a plain deck card.
static func from_token(kind: String, term_id: String, card_hints: Dictionary = {}) -> DescriptionSegment:
	match kind.to_upper():
		KIND_STATUS:
			var status_definition: StatusEffectDefinition = AutoloadDatabase.get_status_effect_by_id(term_id)
			if status_definition == null:
				return _unknown_term(kind, term_id)
			return status(status_definition)
		KIND_PASSIVE:
			var passive_definition: PassiveEffectDefinition = AutoloadDatabase.get_passive_effect_def(term_id)
			if passive_definition == null:
				return _unknown_term(kind, term_id)
			return passive(passive_definition)
		KIND_ACTION:
			var player_action: PlayerAction = AutoloadDatabase.get_player_action_by_id(term_id)
			if player_action == null:
				return _unknown_term(kind, term_id)
			return player_action_term(player_action)
		KIND_CARD:
			var event_card: EventCardDefinition = AutoloadDatabase.event_cards_by_id.get(term_id, null)
			if event_card == null:
				return _unknown_term(kind, term_id)
			return event_card_term(event_card, int(card_hints.get(term_id, CardInstance.CardPermanence.PERMANENT)))
		KIND_MOVE:
			var opponent_action: OpponentActionDefinition = AutoloadDatabase.get_opponent_action_by_id(term_id)
			if opponent_action == null:
				return _unknown_term(kind, term_id)
			return opponent_action_term(opponent_action)
	push_warning("DescriptionTerms: unknown term kind '%s' in token {%s:%s}" % [kind, kind, term_id])
	return DescriptionSegment.text_segment(term_id)

static func status(definition: StatusEffectDefinition) -> DescriptionSegment:
	var guard_key: String = KIND_STATUS + ":" + definition.status_id
	if not _start_building(guard_key):
		return DescriptionSegment.text_segment(definition.get_effect_name())
	var description: Array[DescriptionSegment]
	if _shows_generated_description(definition):
		description = definition.get_description_segments()
	else:
		description = definition.get_hand_written_description_segments()
	_finish_building(guard_key)
	return DescriptionSegment.nested_segment(definition.get_effect_name(), description)

static func passive(definition: PassiveEffectDefinition) -> DescriptionSegment:
	var guard_key: String = KIND_PASSIVE + ":" + definition.passive_id
	if not _start_building(guard_key):
		return DescriptionSegment.text_segment(definition.get_effect_name())
	var description: Array[DescriptionSegment]
	if _shows_generated_description(definition):
		description = definition.get_description_segments()
	else:
		description = definition.get_hand_written_description_segments()
	_finish_building(guard_key)
	return DescriptionSegment.nested_segment(definition.get_effect_name(), description)

### The template action; the rework log passes the save's effective one itself (through its own term links).
static func player_action_term(action: PlayerAction) -> DescriptionSegment:
	var guard_key: String = KIND_ACTION + ":" + action.action_id
	if not _start_building(guard_key):
		return DescriptionSegment.text_segment(action.get_action_name())
	var description: Array[DescriptionSegment] = action.get_description_segments()
	_finish_building(guard_key)
	return DescriptionSegment.nested_segment(action.get_action_name(), description)

static func opponent_action_term(action: OpponentActionDefinition) -> DescriptionSegment:
	var guard_key: String = KIND_MOVE + ":" + action.opponent_action_id
	if not _start_building(guard_key):
		return DescriptionSegment.text_segment(action.get_action_name())
	var description: Array[DescriptionSegment] = action.get_description_segments()
	_finish_building(guard_key)
	return DescriptionSegment.nested_segment(action.get_action_name(), description)

### permanence: how the card looks in its tooltip. An effect that hands the card out knows it (CardsToAddIntent.permanence).
static func event_card_term(
		definition: EventCardDefinition, permanence: int = CardInstance.CardPermanence.PERMANENT) -> DescriptionSegment:
	var guard_key: String = KIND_CARD + ":" + definition.card_type_id
	if not _start_building(guard_key):
		return DescriptionSegment.text_segment(definition.get_card_name())
	var description: Array[DescriptionSegment] = EffectAndTargetIntent.describe_all(definition.get_effect_intents())
	if description.is_empty():
		description = definition.get_card_description_segments()
	_finish_building(guard_key)
	### The tooltip shows the card itself (PopupController); the description is the text fallback.
	return DescriptionSegment.card_segment(definition.get_card_name(), definition.card_type_id, description, permanence)

### card id -> CardInstance.CardPermanence of every card the given effects (EffectAndTargetIntents) hand out, so a hand-written
### text that names such a card with {CARD:id} shows it the way the effect gives it (a support card, a problem card, a combo card...)
### without the permanence being written twice. The first effect to name a card wins.
static func card_permanence_hints(effect_intents: Array) -> Dictionary:
	var hints: Dictionary = {}
	for effect_and_target_intent in effect_intents:
		var card_flow: CardFlowEffect = (effect_and_target_intent as EffectAndTargetIntent).effect_intent as CardFlowEffect
		if card_flow == null:
			continue
		for entry in card_flow.add_cards_to_hand + card_flow.add_cards_to_deck:
			if not hints.has(entry.event_card_id):
				hints[entry.event_card_id] = entry.permanence
	return hints

### Same, for everything a status or passive does when it triggers or ticks.
static func card_permanence_hints_of_effect(definition: EffectDefinition) -> Dictionary:
	var effect_intents: Array = []
	for component in definition.get_triggered_components() + definition.get_ticking_components():
		effect_intents.append_array(component.effect_intents)
	return card_permanence_hints(effect_intents)

static func _shows_generated_description(definition: EffectDefinition) -> bool:
	return not definition.has_secret_description

### False when this term is already being built further up (see _terms_in_progress).
static func _start_building(guard_key: String) -> bool:
	if guard_key in _terms_in_progress:
		return false
	_terms_in_progress.append(guard_key)
	return true

static func _finish_building(guard_key: String) -> void:
	_terms_in_progress.erase(guard_key)

static func _unknown_term(kind: String, term_id: String) -> DescriptionSegment:
	push_warning("DescriptionTerms: no %s with id '%s'" % [kind.to_lower(), term_id])
	return DescriptionSegment.text_segment(term_id)
