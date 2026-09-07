@tool
extends EffectIntent
class_name CardFlowEffect

@export var cards_to_draw: int
@export var discard_n_randomly: int
@export var discard_hand: bool = false
@export var shuffle_deck: bool = false
#@export var add_cards_to_hand: Array[EventCardInstance] 
@export var add_cards_to_hand: Array[CardsToAddIntent]
@export var add_cards_to_deck: Array[CardsToAddIntent]

func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	_insert_card_flow_into_context_(context)
	return context

### Card flow only ever affects the player's own hand/deck, so no targeting phrase is needed
### (see EffectIntent.description_includes_targeting()). A single CardFlowEffect can combine
### several of draw/discard/shuffle/add-to-hand/add-to-deck at once, so each active piece
### becomes its own clause; exactly two clauses read better joined with "then" ("Draw 2 cards,
### then Discard 1 card at random.") than a bare comma, mirroring
### EffectAndTargetIntent.describe_all()'s two-sentence case - three or more still read fine
### as a plain comma list.
func get_description_segments() -> Array[DescriptionSegment]:
	var clauses: Array = []
	if cards_to_draw > 0:
		clauses.append(DescriptionBuilder.parse_pluralized_template(
			cards_to_draw, "EFFECTINTENT_CARDFLOWEFFECT_DRAW_TEMPLATE_SINGULAR",
			"EFFECTINTENT_CARDFLOWEFFECT_DRAW_TEMPLATE", {"count": str(cards_to_draw)}))
	if discard_n_randomly > 0:
		clauses.append(DescriptionBuilder.parse_pluralized_template(
			discard_n_randomly, "EFFECTINTENT_CARDFLOWEFFECT_DISCARD_TEMPLATE_SINGULAR",
			"EFFECTINTENT_CARDFLOWEFFECT_DISCARD_TEMPLATE", {"count": str(discard_n_randomly)}))
	if discard_hand:
		clauses.append(DescriptionBuilder.parse_template(tr("EFFECTINTENT_CARDFLOWEFFECT_DISCARD_HAND_TEMPLATE")))
	if shuffle_deck:
		clauses.append(DescriptionBuilder.parse_template(tr("EFFECTINTENT_CARDFLOWEFFECT_SHUFFLE_TEMPLATE")))
	for entry in add_cards_to_hand:
		clauses.append(_describe_card_to_add(entry, "EFFECTINTENT_CARDFLOWEFFECT_ADD_TO_HAND_TEMPLATE",
			"EFFECTINTENT_CARDFLOWEFFECT_ADD_TO_HAND_WITH_DURATION_TEMPLATE"))
	for entry in add_cards_to_deck:
		clauses.append(_describe_card_to_add(entry, "EFFECTINTENT_CARDFLOWEFFECT_ADD_TO_DECK_TEMPLATE",
			"EFFECTINTENT_CARDFLOWEFFECT_ADD_TO_DECK_WITH_DURATION_TEMPLATE"))

	var combined: Array[DescriptionSegment] = []
	for i in range(clauses.size()):
		if i > 0:
			if clauses.size() == 2:
				combined.append(DescriptionSegment.text_segment(", %s " % tr("EFFECTANDTARGETINTENT_THEN_JOINER")))
			else:
				combined.append(DescriptionSegment.text_segment(", "))
		combined.append_array(clauses[i])
	return combined

func _describe_card_to_add(entry: CardsToAddIntent, plain_key: String, with_duration_key: String) -> Array[DescriptionSegment]:
	var card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id.get(entry.event_card_id, null)
	var card_name: String = card_def.get_card_name() if card_def else "?"
	if entry.turns_until_discard >= 0:
		return DescriptionBuilder.parse_template(tr(with_duration_key), {
			"count": str(entry.number_to_add), "card_name": card_name,
			"turns": str(entry.turns_until_discard)})
	return DescriptionBuilder.parse_template(tr(plain_key),
		{"count": str(entry.number_to_add), "card_name": card_name})

func description_includes_targeting(
		_targeting_intent: TargetingSystem.TargetingMode, _targeting_rules: Array[TargetingRule]) -> bool:
	return false

func _insert_card_flow_into_context_(context: EffectContext) -> void:
	context.card_flow_effect = true
	if not context.cards_to_draw:
		context.cards_to_draw = cards_to_draw
	else:
		context.cards_to_draw += cards_to_draw
	
	if not context.discard_n_randomly:
		context.discard_n_randomly = discard_n_randomly
	else:
		context.discard_n_randomly += discard_n_randomly

	if discard_hand:
		context.discard_hand = true

	context.shuffle_deck = shuffle_deck
	
	if not context.add_cards_to_hand:
		context.add_cards_to_hand = add_cards_to_hand.duplicate()
	else:
		context.add_cards_to_hand.append_array(add_cards_to_hand)
	if not context.add_cards_to_deck:
		context.add_cards_to_deck = add_cards_to_deck.duplicate()
	else:
		context.add_cards_to_deck.append_array(add_cards_to_deck)

#func _insert_card_flow_into_context_(context: EffectContext) -> void:
	#context.card_flow_effect = true
	#if not context.cards_to_draw:
		#context.cards_to_draw = cards_to_draw
	#else:
		#context.cards_to_draw += cards_to_draw
	#
	#if not context.discard_n_randomly:
		#context.discard_n_randomly = discard_n_randomly
	#else:
		#context.discard_n_randomly += discard_n_randomly
		#
	#context.shuffle_deck = shuffle_deck
	#
	#if not context.add_cards_to_hand:
		#context.add_cards_to_hand = add_cards_to_hand
	#else:
		#context.add_cards_to_hand.append_array(add_cards_to_hand)
#
	#if not context.add_cards_to_deck:
		#context.add_cards_to_deck = add_cards_to_deck
	#else:
		#context.add_cards_to_deck.append_array(add_cards_to_deck)
