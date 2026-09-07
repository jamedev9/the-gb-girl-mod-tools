@tool
extends TriggerCondition
class_name TriggerCondition_OnlyIfPlayerDoesNotHaveEffects

@export var status_ids: Array[String] = []
@export var passive_ids: Array[String] = []

func is_condition_met(
	_input_context: EffectContext,
	_game_state: GameState
	,_save_game_state: SaveGameState,
	_owner_of_trigger: TargetEntity) -> bool:
		
	var status_effects = _game_state.get_player_statuses()

	for status_id in status_effects:
		#print("Checking status id %s"%status_id)
		if status_id in status_ids:
			#print("Found status that should be exlucded, returning calse")
			return false
				
	var passive_effects = _save_game_state.get_active_player_passives()
	for passive in passive_effects:
		#print("Checking passive id %s"%passive)
		if passive in passive_ids:
			#print("Found passive that should be exlucded, returning calse")
			return false

	return true

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("TRIGGERCONDITION_ONLYIFPLAYERDOESNOTHAVEEFFECTS_TEMPLATE"),
		{"names": _effect_names(status_ids, passive_ids, true)})
