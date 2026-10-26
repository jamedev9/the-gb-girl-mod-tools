@tool
extends ModExportable
class_name CardsToAddIntent

@export var event_card_id: String
@export var permanence: CardInstance.CardPermanence
@export var number_to_add: int = 1
### Adding to the hand only: no more copies than this end up in the hand. Ignored when adding to the deck.
@export var max_number_in_hand: int = 1
### Optional: gives added cards a voluntary end-of-turn discard timer
### (see EventCardInstance.turns_until_discard). -1 (default) = no timer,
### unchanged behavior for every already-authored CardFlowEffect resource.
@export var turns_until_discard: int = -1
