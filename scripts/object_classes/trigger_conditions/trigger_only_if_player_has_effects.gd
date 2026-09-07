@tool
extends TriggerCondition
class_name TriggerCondition_OnlyIfPlayerHasEffects

@export var require_only_one: bool = false
@export var status_ids: Array[String] = []
@export var passive_ids: Array[String] = []

func is_condition_met(
	_input_context: EffectContext,
	_game_state: GameState
	,_save_game_state: SaveGameState,
	_owner_of_trigger: TargetEntity) -> bool:
	
	var required_nr_of_effects: int = status_ids.size() + passive_ids.size()
	var counted_effects: int = 0
	
	var status_effects = _game_state.get_player_statuses()
	for status_id in status_effects:
		if status_id in status_ids:
			counted_effects += 1

	var passive_effects = _save_game_state.get_active_player_passives()
	for passive in passive_effects:
		if passive in passive_ids:
			counted_effects += 1
	
	if require_only_one and required_nr_of_effects >= 1:
		return true

	return counted_effects >= required_nr_of_effects

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("TRIGGERCONDITION_ONLYIFPLAYERHASEFFECTS_TEMPLATE"),
		{"names": _effect_names(status_ids, passive_ids, require_only_one)})
