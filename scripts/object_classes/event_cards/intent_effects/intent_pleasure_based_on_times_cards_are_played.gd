@tool
extends EffectIntent
class_name Intent_PleasureBasedOnTimesCardsArePlayed

@export var card_ids: Array[String]
@export var pleasure_per_play: int
@export var start_counter_at_one: bool = true

func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var pleasure_context: EffectContext = EffectContext.new()
	var counter: int = 0
	if start_counter_at_one:
		counter += 1
	for card_id in card_ids:
		var times_played_this_turn: int = _game_state.encounter_report.get_times_card_has_been_played_in_round(_game_state.current_round,card_id)
		counter += times_played_this_turn
		
	var pleasure_total: int = counter*pleasure_per_play
	pleasure_context.damage_amount = pleasure_total

	return pleasure_context

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_PLEASUREBASEDONTIMESCARDSAREPLAYED_TEMPLATE"),
		{"pleasure_per_play": str(pleasure_per_play), "card_names": _card_names()})

### Explicit "Player" since targeting_intent=PLAYER always means the player, regardless of which
### side owns the surrounding status/passive - see DealDamageEffect's own self-targeted override.
func get_self_targeted_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_PLEASUREBASEDONTIMESCARDSAREPLAYED_SELF_TEMPLATE"),
		{"pleasure_per_play": str(pleasure_per_play), "card_names": _card_names()})

func _card_names() -> String:
	var names: Array[String] = []
	for id in card_ids:
		var card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id.get(id, null)
		names.append(card_def.get_card_name() if card_def else "?")
	return DescriptionBuilder.join_with_and(names)
