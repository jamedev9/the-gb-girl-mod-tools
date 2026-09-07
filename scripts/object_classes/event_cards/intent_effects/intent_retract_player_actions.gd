@tool
extends EffectIntent
class_name Intent_RetractPlayerActions

@export var retract_all: bool = false
@export var player_action_ids: Array[String]
### If non-empty (and retract_all is false), retracts every action currently in the
### encounter EXCEPT these - for "only X is allowed" cards that should still cover
### actions added after this resource was authored.
@export var allowed_action_ids: Array[String] = []

func create_intent_context(game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var retraction_array: Array = []
	if retract_all:
		retraction_array = game_state.get_player_actions_in_encounter()
	elif not allowed_action_ids.is_empty():
		for action_id in game_state.get_player_actions_in_encounter():
			if action_id not in allowed_action_ids:
				retraction_array.append(action_id)
	else:
		retraction_array = player_action_ids
	var retract_intent: EffectContext = EffectContext.new_retract_player_actions_intent(
		game_state,retraction_array,self,self.intent_effect_id)
	return retract_intent

func get_description_segments() -> Array[DescriptionSegment]:
	if retract_all:
		return DescriptionBuilder.parse_template(tr("EFFECTINTENT_RETRACTPLAYERACTIONS_ALL_TEMPLATE"))
	if not allowed_action_ids.is_empty():
		return DescriptionBuilder.parse_template(
			tr("EFFECTINTENT_RETRACTPLAYERACTIONS_EXCEPT_TEMPLATE"),
			{"action_names": _joined_action_names(allowed_action_ids)})
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_RETRACTPLAYERACTIONS_SPECIFIC_TEMPLATE"),
		{"action_names": _joined_action_names(player_action_ids)})

func _joined_action_names(ids: Array[String]) -> String:
	var names: Array[String] = []
	for id in ids:
		var action_def: PlayerAction = AutoloadDatabase.get_player_action_by_id(id)
		names.append(action_def.get_action_name() if action_def else "?")
	return DescriptionBuilder.join_with_and(names)

### Always retracts the player's own actions, never a targeted opponent.
func description_includes_targeting(
		_targeting_intent: TargetingSystem.TargetingMode, _targeting_rules: Array[TargetingRule]) -> bool:
	return false
