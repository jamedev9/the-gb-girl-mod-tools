@tool
extends EffectIntent
class_name CardFlowEffect

@export var cards_to_draw: int
@export var discard_n_randomly: int
@export var shuffle_deck: bool = false
#@export var add_cards_to_hand: Array[EventCardInstance]
@export var add_cards_to_hand: Array[CardsToAddIntent]
@export var add_cards_to_deck: Array[CardsToAddIntent]

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "CardFlowEffect"
	d["cards_to_draw"] = cards_to_draw
	d["discard_n_randomly"] = discard_n_randomly
	d["shuffle_deck"] = shuffle_deck
	var hand_dicts: Array = []
	for entry in add_cards_to_hand:
		hand_dicts.append(entry.to_json_dict())
	d["add_cards_to_hand"] = hand_dicts
	var deck_dicts: Array = []
	for entry in add_cards_to_deck:
		deck_dicts.append(entry.to_json_dict())
	d["add_cards_to_deck"] = deck_dicts
	return d

static func from_json_dict(data: Dictionary) -> CardFlowEffect:
	var e := CardFlowEffect.new()
	e.intent_effect_id = data.get("intent_effect_id", "")
	e.cards_to_draw = int(data.get("cards_to_draw", 0))
	e.discard_n_randomly = int(data.get("discard_n_randomly", 0))
	e.shuffle_deck = data.get("shuffle_deck", false)
	var hand: Array[CardsToAddIntent] = []
	for entry_data in data.get("add_cards_to_hand", []):
		hand.append(CardsToAddIntent.from_json_dict(entry_data))
	e.add_cards_to_hand = hand
	var deck: Array[CardsToAddIntent] = []
	for entry_data in data.get("add_cards_to_deck", []):
		deck.append(CardsToAddIntent.from_json_dict(entry_data))
	e.add_cards_to_deck = deck
	return e

func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	_insert_card_flow_into_context_(context)
	return context

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
