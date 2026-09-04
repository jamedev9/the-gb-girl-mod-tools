@tool
extends TriggerCondition
class_name TriggerCondition_OnPlayerActionsTriggered

@export var action_ids: Array[String]

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "TriggerCondition_OnPlayerActionsTriggered"
	d["action_ids"] = action_ids
	return d

static func from_json_dict(data: Dictionary) -> TriggerCondition_OnPlayerActionsTriggered:
	var condition := TriggerCondition_OnPlayerActionsTriggered.new()
	condition.trigger_condition_id = data.get("trigger_condition_id", "")
	var ids: Array[String] = []
	for id in data.get("action_ids", []):
		ids.append(str(id))
	condition.action_ids = ids
	return condition

func is_condition_met(
	input_context: EffectContext,
	_game_state: GameState
	, _save_game_state: SaveGameState,
	_owner_of_trigger: TargetEntity) -> bool:

	# effect_origin is only ever an ApplyEffectOfPlayerAction when a player action is
	# actually resolving for real (once per round, from _resolve_effects_of_player_actions);
	# that alone is enough to identify a genuine resolution. damage_phase is NOT a reliable
	# extra check here: it defaults to OUTGOING (enum value 0) but gets overwritten to
	# INCOMING whenever the target happens to have any active status effect, which would
	# make this condition randomly fail for reasons unrelated to the action itself.
	if input_context.effect_origin is not ApplyEffectOfPlayerAction:

		return false
	if input_context.effect_origin.player_action_id not in action_ids:

		return false

	return true
