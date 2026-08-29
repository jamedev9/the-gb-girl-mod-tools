extends CardInstance
class_name EventCardInstance

var card_id: String
var permanence: CardPermanence
var entity_id: String

### Cardstate: Where in the resolution pipeline is the card instance?
### This is purely data. Visual state is controlled by the EventCard node
enum CardState {
	IN_DRAW_PILE,
	SPAWNED, #Reward and award cards
	IN_HAND,
	RESOLVING,
	IN_DISCARD_PILE,
	EXILED # Removed from the game
}
var card_state: CardState
var previous_hand_index: int

### Voluntary per-instance discard timer, independent of permanence. Checked and
### decremented once per end-of-turn sweep (EventCardManager._process_end_of_turn_card_expiry_).
### -1 = no timer - this card is never auto-discarded by the timer system.
###  0 = discarded at the very next end-of-turn sweep.
### >0 = survives that many additional end-of-turn sweeps before being discarded.
var turns_until_discard: int = -1

func card_requires_targeted_opponent() -> bool:
	var card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[card_id]
	return card_def.card_requires_targeted_opponent()


func card_targets_opponent_with_action() -> bool:
	var card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[card_id]
	return card_def.card_targets_opponent_with_action()

func required_actions_are_active_on_opponents(game_state: GameState) -> bool:
	var card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[card_id]
	return card_def.required_actions_are_active_on_opponents(game_state)

#
func get_opponents_with_one_of_required_actions(game_state: GameState) -> Array[String]:
	var card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[card_id]
	return card_def.get_opponents_with_one_of_required_actions(game_state)


func get_effect_intents() -> Array[EffectAndTargetIntent]:
	var card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[card_id]
	return card_def.get_effect_intents()
