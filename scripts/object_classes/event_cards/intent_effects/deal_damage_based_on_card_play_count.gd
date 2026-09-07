@tool
extends EffectIntent
class_name DealDamageBasedOnCardPlayCount

@export var card_ids: Array[String] = []
@export var damage_per_play: int
## If > 0, the count used for scaling wraps back to 1 after reaching this value
## (e.g. cycle_length = 5 gives 1,2,3,4,5,1,2,3... across repeated plays instead of climbing forever).
@export var cycle_length: int = 0

func create_intent_context(game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	var play_count: int = game_state.encounter_report.get_times_cards_have_been_played(card_ids)
	var effective_count: int = play_count
	if cycle_length > 0:
		effective_count = ((play_count - 1) % cycle_length) + 1

	context.damage_phase = DamageSystem.DamagePhase.OUTGOING
	context.damage_amount = damage_per_play * effective_count

	return context
