@tool
extends TriggerCondition
class_name TriggerCondition_OnEventCardPlayedNTimes

@export var card_ids: Array[String] = []
@export var required_count: int
@export var trigger_on_n_or_higher: bool = false

func is_condition_met(
	input_context: EffectContext,game_state: GameState,_save_game_state: SaveGameState,owner_of_trigger: TargetEntity) -> bool:
	
	
	if not input_context.played_event_card:
		return false
	
	var event_card_instance: EventCardInstance = input_context.event_card_instance
	var card_id: String = event_card_instance.card_id
	
	if card_id not in card_ids:
		return false
	
	var play_count: int = game_state.encounter_report.get_times_card_has_been_played(card_id)	
	
	if play_count < required_count:
		return false
	
	if play_count == required_count:
		return true
	
	return play_count > required_count and trigger_on_n_or_higher

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_pluralized_template(
		required_count, "TRIGGERCONDITION_ONEVENTCARDPLAYEDNTIMES_TEMPLATE_SINGULAR",
		"TRIGGERCONDITION_ONEVENTCARDPLAYEDNTIMES_TEMPLATE",
		{"card_names": _card_names(card_ids), "count": str(required_count)})
