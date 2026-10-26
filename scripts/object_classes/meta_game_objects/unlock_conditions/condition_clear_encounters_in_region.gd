@tool
extends UnlockCondition
class_name Condition_ClearEncountersInRegion

### Progression (save game): clear different encounters of one map region.
### required_count = how many different encounters of the region must be cleared. 0 = ALL of them.
### "All" counts every encounter that is in the region right now, so it asks for more as the game grows: new
### encounters added to the region later make this unlock take longer for players who have not got it yet.
### Use a fixed required_count where that is not wanted. Encounters excluded from releases (the test
### encounter) never count.

@export var region_id: String
@export var required_count: int = 0

### The map whose encounters count: the main map (AutoloadDatabase.MAIN_MAP_ID) unless AutoloadDatabase set it to a mod
### map's id, for a condition on that mod map's node. Never the map the player happens to be looking at: a base-game
### reward must not unlock by clearing a mod map's few encounters of the region. Not an @export (set on load, never saved).
var counted_map_id: String = ""

func is_condition_met(save_game_state: SaveGameState,_encounter_report: EncounterReport) -> bool:
	var required: int = get_progress_required(save_game_state)
	if required <= 0:
		return false
	return get_progress_current(save_game_state) >= required

func get_progress_style() -> ProgressStyle:
	return ProgressStyle.COUNT_UP

### Encounters of the region the player has cleared at least once.
func get_progress_current(save_game_state: SaveGameState) -> int:
	var cleared: int = 0
	for encounter_id in get_encounter_ids_in_region():
		if save_game_state.is_encounter_completed(encounter_id):
			cleared += 1
	return cleared

func get_progress_required(_save_game_state: SaveGameState) -> int:
	if required_count > 0:
		return required_count
	return get_encounter_ids_in_region().size()

func get_encounter_ids_in_region() -> Array[String]:
	var encounter_ids: Array[String] = []
	for encounter_id in AutoloadDatabase.encounter_definitions.keys():
		if encounter_id in AutoloadDatabase.EXCLUDED_ENCOUNTER_IDS_IN_RELEASE:
			continue
		### Only the encounters on the counted map (Full Rework registers every encounter; mod encounters are registered in
		### both modes but are never on the main map).
		if not AutoloadDatabase.is_encounter_on_given_map(encounter_id, counted_map_id):
			continue
		if AutoloadDatabase.encounter_definitions[encounter_id].map_region_id == region_id:
			encounter_ids.append(encounter_id)
	return encounter_ids

func _build_description_segments(_save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	var region_def: MapRegionDefinition = AutoloadDatabase.get_map_region_by_id(region_id)
	var region_segment: DescriptionSegment = _name_emphasis(region_def.get_region_name() if region_def else region_id)
	if required_count > 0:
		return _template("UI_UNLOCK_CONDITION_CLEAR_IN_REGION", {"count": _number(required_count), "region": region_segment}, required_count)
	return _template("UI_UNLOCK_CONDITION_CLEAR_ALL_IN_REGION", {"region": region_segment})
