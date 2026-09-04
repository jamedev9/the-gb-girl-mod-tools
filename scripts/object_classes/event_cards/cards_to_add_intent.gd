@tool
extends Resource
class_name CardsToAddIntent

@export var event_card_id: String
@export var permanence: CardInstance.CardPermanence
@export var number_to_add: int = 1
@export var max_number_in_hand: int = 1
### Optional: gives added cards a voluntary end-of-turn discard timer
### (see EventCardInstance.turns_until_discard). -1 (default) = no timer,
### unchanged behavior for every already-authored CardFlowEffect resource.
@export var turns_until_discard: int = -1

func to_json_dict() -> Dictionary:
	return {
		"event_card_id": event_card_id,
		"permanence": CardInstance.CardPermanence.keys()[permanence],
		"number_to_add": number_to_add,
		"max_number_in_hand": max_number_in_hand,
		"turns_until_discard": turns_until_discard,
	}

static func from_json_dict(data: Dictionary) -> CardsToAddIntent:
	var intent := CardsToAddIntent.new()
	intent.event_card_id = data.get("event_card_id", "")
	var permanence_name: String = data.get("permanence", "")
	var matched_key: String = ModExportable.find_case_insensitive_enum_key(CardInstance.CardPermanence.keys(), permanence_name)
	if matched_key != "":
		intent.permanence = CardInstance.CardPermanence[matched_key]
	intent.number_to_add = int(data.get("number_to_add", 1))
	intent.max_number_in_hand = int(data.get("max_number_in_hand", 1))
	intent.turns_until_discard = int(data.get("turns_until_discard", -1))
	return intent
