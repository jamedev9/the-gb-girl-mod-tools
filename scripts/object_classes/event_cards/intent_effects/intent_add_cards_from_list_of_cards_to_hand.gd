@tool
extends CardFlowEffect
class_name Intent_AddCardsFromListOfCardsToHand

@export var number_of_cards: int = 0
@export var cards_and_weights: Dictionary[CardsToAddIntent,float] = {}  # Card Intent, weight of each card type being chosen

func create_intent_context(_game_state: GameState, _intent_context: EffectContext) -> EffectContext:
	var cards_to_hand_context: EffectContext = EffectContext.new()
	_insert_card_flow_into_context_(cards_to_hand_context)
	
	var total_weight: float = 0.0
	for card_intent in cards_and_weights.keys():
		total_weight += cards_and_weights[card_intent]
	
	if total_weight <= 0.0:
		push_error("cards_and_weights has no valid weights, cannot select cards")
		cards_to_hand_context.add_cards_to_hand.append_array(cards_and_weights.keys())
		return cards_to_hand_context
	
	var cards_to_add: Array[CardsToAddIntent] = []
	for i in range(number_of_cards):
		var selected_intent: CardsToAddIntent = _select_weighted_card_id(total_weight)
		if not selected_intent:
			continue
		cards_to_add.append(selected_intent)
	cards_to_hand_context.add_cards_to_hand.append_array(cards_to_add)
	return cards_to_hand_context


func _select_weighted_card_id(total_weight: float) -> CardsToAddIntent:
	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	for card_edd_intent in cards_and_weights.keys():
		cumulative += cards_and_weights[card_edd_intent]
		if roll < cumulative:
			return card_edd_intent
	return null

### Overrides CardFlowEffect's own get_description_segments() - the actual card(s) added are
### chosen randomly at resolution time (see create_intent_context() above), so the static
### add_cards_to_hand field CardFlowEffect's version reads from is never populated here and
### would render empty. Describes the pool of possible cards instead: "Add a random card from
### Sweet Pain or Grit Your Teeth to your hand." Doesn't weight-average or mention per-card
### duration/permanence - this is meant to read as a simple "here's what's possible" summary,
### not a precise breakdown of a system a player can't meaningfully influence anyway.
func get_description_segments() -> Array[DescriptionSegment]:
	var names: Array[String] = []
	for card_intent in cards_and_weights.keys():
		var card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id.get(card_intent.event_card_id, null)
		names.append(card_def.get_card_name() if card_def else "?")
	return DescriptionBuilder.parse_pluralized_template(
		number_of_cards,
		"EFFECTINTENT_ADDCARDSFROMLISTOFCARDSTOHAND_TEMPLATE_SINGULAR",
		"EFFECTINTENT_ADDCARDSFROMLISTOFCARDSTOHAND_TEMPLATE",
		{"count": str(number_of_cards), "card_names": DescriptionBuilder.join_with_and(names, true)})
