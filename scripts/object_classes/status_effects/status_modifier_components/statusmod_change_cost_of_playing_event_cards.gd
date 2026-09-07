@tool
extends StatusModifierComponent
class_name Status_ChangeCostOfPlayingEventCards

@export var all_cards: bool = false
@export var card_ids: Array[String]
@export var energy_delta: int = 0

func modify_context(_effect_context: EffectContext) -> void:
	pass

func get_list_of_cards() -> Array[String]:
	return card_ids

## Overridden by Status_ChangeCostOfPlayingEventCardsPerPlay to compute the delta dynamically
## from play count instead of returning a fixed energy_delta.
func get_energy_delta(_game_state: GameState) -> int:
	return energy_delta

### Overridden by Status_ChangeCostOfCardsUsingActions to describe "cards that use {action_names}"
### instead of listing card ids directly.
func _cost_subject() -> String:
	if all_cards:
		return tr("STATUS_CHANGECOSTOFPLAYINGEVENTCARDS_SUBJECT_ANY")
	return tr("STATUS_CHANGECOSTOFPLAYINGEVENTCARDS_SUBJECT_TEMPLATE").format({"card_names": _card_names(card_ids)})

func get_description_segments() -> Array[DescriptionSegment]:
	var subject: String = _cost_subject()
	var key: String = "STATUS_CHANGECOSTOFPLAYINGEVENTCARDS_INCREASE_TEMPLATE" if energy_delta > 0 else "STATUS_CHANGECOSTOFPLAYINGEVENTCARDS_DECREASE_TEMPLATE"
	return DescriptionBuilder.parse_template(tr(key), {"subject": subject, "amount": str(abs(energy_delta))})

