@tool
extends EffectIntent
class_name DealDamageBasedOnCardPlayCount

@export var card_ids: Array[String] = []
@export var damage_per_play: int
## If > 0, the count used for scaling wraps back to 1 after reaching this value
## (e.g. cycle_length = 5 gives 1,2,3,4,5,1,2,3... across repeated plays instead of climbing forever).
@export var cycle_length: int = 0

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "DealDamageBasedOnCardPlayCount"
	d["card_ids"] = card_ids
	d["damage_per_play"] = damage_per_play
	d["cycle_length"] = cycle_length
	return d

static func from_json_dict(data: Dictionary) -> DealDamageBasedOnCardPlayCount:
	var e := DealDamageBasedOnCardPlayCount.new()
	e.intent_effect_id = data.get("intent_effect_id", "")
	var ids: Array[String] = []
	for id in data.get("card_ids", []):
		ids.append(str(id))
	e.card_ids = ids
	e.damage_per_play = int(data.get("damage_per_play", 0))
	e.cycle_length = int(data.get("cycle_length", 0))
	return e

## Sums the play count across every tracked card, so any of them advances the same combo count.
static func get_current_count(game_state: GameState, card_ids: Array[String]) -> int:
	var total: int = 0
	for id in card_ids:
		total += game_state.encounter_report.get_times_card_has_been_played(id)
	return total

func create_intent_context(game_state: GameState, _intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	var play_count: int = DealDamageBasedOnCardPlayCount.get_current_count(game_state, card_ids)
	var effective_count: int = play_count
	if cycle_length > 0:
		effective_count = ((play_count - 1) % cycle_length) + 1

	context.damage_phase = DamageSystem.DamagePhase.OUTGOING
	context.damage_amount = damage_per_play * effective_count

	return context
