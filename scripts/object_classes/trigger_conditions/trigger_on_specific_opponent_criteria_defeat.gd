@tool
extends TriggerCondition
class_name TriggerCondition_OnSpecificOpponentCriteriaDefeated

@export var passive_ids: Array[String] = []
@export var status_effect_ids: Array[String] = []
@export var opponent_type_ids: Array[String] = []

func is_condition_met(
	input_context: EffectContext,game_state: GameState,_save_game_state: SaveGameState,owner_of_trigger: TargetEntity) -> bool:
		if input_context.opponent_with_id_was_defeated == "":
			return false
		
		var defeated_opponent: OpponentInstance = game_state.get_opponent_instance(input_context.opponent_with_id_was_defeated)
		
		if not passive_ids.is_empty(): ### Check only if the definition has listed passives.
			var opponent_passives: Array[String] = defeated_opponent.opponent_type.passive_effects
			for passive_id in passive_ids:
				if passive_id not in opponent_passives:
					return false
		
		if not status_effect_ids.is_empty():
			#print("Found condition asking for statuses.")
			var opponent_statuses := defeated_opponent.status_effects
			for status_id in status_effect_ids:
				#print("Checking status %s"%status_id)
				if status_id not in opponent_statuses.keys():
					#print("Opponent does not have this status. Current opponent status dict keys: %s"%opponent_statuses.keys())
					return false
		
		if not opponent_type_ids.is_empty():
			if defeated_opponent.opponent_type.opponent_type_id not in opponent_type_ids:
				#print("Defeated opponent does not have a mathcing opponent ID type")
				return false
		
		#print("Found that defeated opponent matches all criteria, returning condition %s true"%trigger_condition_id)
		return true

### Builds one clause per non-empty criteria category ("is a {type}", "has {passive/status}"),
### AND-joined - falls back to the plain "a Partner is defeated" phrasing (shared with
### TriggerCondition_OnOpponentDefeat) if somehow none of the three lists are populated. Uses "a
### defeated {OPPONENT}", not "the" - this describes a general rule ("whenever a Partner matching
### these criteria is defeated, ..."), not a narration of one already-known specific individual.
func get_description_segments() -> Array[DescriptionSegment]:
	var clause_strings: Array[String] = []
	if not opponent_type_ids.is_empty():
		var type_names: Array[String] = []
		for id in opponent_type_ids:
			var opponent_type: OpponentType = AutoloadDatabase.opponent_types.get(id, null)
			type_names.append(opponent_type.get_opponent_type_name() if opponent_type else "?")
		clause_strings.append(tr("TRIGGERCONDITION_ONSPECIFICOPPONENTCRITERIADEFEATED_TYPE_CLAUSE").format(
			{"names": DescriptionBuilder.join_with_and(type_names, true)}))
	if not passive_ids.is_empty() or not status_effect_ids.is_empty():
		clause_strings.append(tr("TRIGGERCONDITION_ONSPECIFICOPPONENTCRITERIADEFEATED_EFFECT_CLAUSE").format(
			{"names": _effect_names(status_effect_ids, passive_ids, true)}))
	if clause_strings.is_empty():
		return DescriptionBuilder.parse_template(tr("TRIGGERCONDITION_ONOPPONENTDEFEAT_TEMPLATE"))
	return DescriptionBuilder.parse_template(
		tr("TRIGGERCONDITION_ONSPECIFICOPPONENTCRITERIADEFEATED_TEMPLATE"),
		{"clauses": DescriptionBuilder.join_with_and(clause_strings)})
