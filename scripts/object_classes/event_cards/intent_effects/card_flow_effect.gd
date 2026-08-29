extends EffectIntent
class_name CardFlowEffect

@export var cards_to_draw: int
@export var discard_n_randomly: int
@export var shuffle_deck: bool = false
#@export var add_cards_to_hand: Array[EventCardInstance] 
@export var add_cards_to_hand: Array[CardsToAddIntent]
@export var add_cards_to_deck: Array[CardsToAddIntent]

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
