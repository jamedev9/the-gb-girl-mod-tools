@tool
extends TriggerCondition
class_name TriggerCondition_OnCardsDiscarded

### Met by any effect that asks the player to discard one or more cards (CardFlowEffect's
### discard_n_randomly / discard_hand), once per effect: "Discard 1" followed by "Discard 3" as two
### separate effects is two triggers, however many cards each one ends up discarding.
### It reads the request, not the outcome, so it still fires when the hand turns out to be empty or every
### card is immune to random discard. Cards that leave the hand without such an effect (a temporary card
### expiring at end of turn) never go through an EffectContext and don't count.
func is_condition_met(
	input_context: EffectContext,_game_state: GameState,_save_game_state: SaveGameState,_owner_of_trigger: TargetEntity) -> bool:
	if not input_context.card_flow_effect:
		return false
	return input_context.discard_n_randomly > 0 or input_context.discard_hand

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(tr("TRIGGERCONDITION_ONCARDSDISCARDED_TEMPLATE"))
