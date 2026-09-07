@tool
extends TriggerCondition
class_name TriggerCondition_OnEventCardPlayed

@export var trigger_on_all_cards: bool = false
@export var card_ids: Array[String] = []

func is_condition_met(
	input_context: EffectContext,_game_state: GameState,_save_game_state: SaveGameState,owner_of_trigger: TargetEntity) -> bool:
	
	if not input_context.played_event_card:
		return false
	
	if trigger_on_all_cards:
		return true
	
	if input_context.event_card_instance.card_id in card_ids:
		return true

	return false

func get_description_segments() -> Array[DescriptionSegment]:
	if trigger_on_all_cards:
		return DescriptionBuilder.parse_template(tr("TRIGGERCONDITION_ONEVENTCARDPLAYED_ANY_TEMPLATE"))
	return DescriptionBuilder.parse_template(
		tr("TRIGGERCONDITION_ONEVENTCARDPLAYED_TEMPLATE"), {"card_names": _card_names(card_ids)})
