@tool
extends ModExportable
class_name EncounterMapNode

### One encounter on the EncounterMap: where it is drawn and what unlocks it. An encounter opens when its lines are
### satisfied (line_requirement) AND every extra condition is met; a node without lines or conditions is open from
### the start.

enum LineRequirement {
	ALL, ## Every encounter in unlocked_by must be cleared.
	ANY, ## Clearing one of them is enough (paths that join up).
}

### Every field emits `changed` when set (from the Inspector, an undo, or the Encounter Map editor tab), so the tab
### redraws whatever changed it.
@export var encounter: EncounterDefinition:
	set(value):
		encounter = value
		emit_changed()
### Names the encounter by id when `encounter` isn't set: for an encounter that has no file where the map is made (a
### base-game encounter on a mod map, made in the mod tools). `encounter` wins when both are set. A map loaded from a
### mod's JSON only has this.
@export var encounter_id: String = "":
	set(value):
		encounter_id = value
		emit_changed()
### The node's centre on the map, in map pixels. Only the distances between nodes matter: the game moves the whole map
### so its top-left node sits at the map's margins.
@export var position: Vector2 = Vector2.ZERO:
	set(value):
		position = value
		emit_changed()
### The lines leading into this node: the ids of the encounters whose clearing unlocks it.
@export var unlocked_by: Array[String] = []:
	set(value):
		unlocked_by = value
		emit_changed()
@export var line_requirement: LineRequirement = LineRequirement.ALL:
	set(value):
		line_requirement = value
		emit_changed()
### The extra prerequisites, all of which must be met on top of the lines. In Full Rework these replace the
### encounter's own unlock_conditions.
@export var unlock_conditions: Array[UnlockCondition] = []:
	set(value):
		unlock_conditions = value
		emit_changed()

func get_encounter_id() -> String:
	if encounter == null:
		return encounter_id
	return encounter.encounter_id

### Everything the encounter needs to unlock, as conditions: one "Complete X" per line (ALL) or a single "Complete X or Y"
### (ANY), then the extra conditions. Both the unlock check (MetaGame) and the encounter description's list read this,
### so they always agree. The line conditions are made here on every call and never saved.
func get_unlock_requirements() -> Array[UnlockCondition]:
	var requirements: Array[UnlockCondition] = []
	if line_requirement == LineRequirement.ANY and not unlocked_by.is_empty():
		var any_cleared: Condition_AnyEncounterCleared = Condition_AnyEncounterCleared.new()
		any_cleared.encounter_ids = unlocked_by.duplicate()
		requirements.append(any_cleared)
	else:
		for encounter_id in unlocked_by:
			var cleared: Condition_IsEncounterCleared = Condition_IsEncounterCleared.new()
			cleared.encounter_id = encounter_id
			requirements.append(cleared)
	for condition in unlock_conditions:
		if condition:
			requirements.append(condition)
	return requirements

#region Mod export (written inside EncounterMap's JSON)
### Hand-written: the encounter is written as its id (it may be a base-game or another mod's encounter, looked up when
### the map is used), and the position as [x, y].
func to_json_dict() -> Dictionary:
	var condition_dicts: Array = []
	for condition in unlock_conditions:
		if condition:
			condition_dicts.append(condition.to_json_dict())
	return {
		"encounter_id": get_encounter_id(),
		"position": [position.x, position.y],
		"unlocked_by": unlocked_by.duplicate(),
		"line_requirement": LineRequirement.keys()[line_requirement],
		"unlock_conditions": condition_dicts,
	}

static func from_json_dict(data: Dictionary) -> EncounterMapNode:
	var map_node: EncounterMapNode = EncounterMapNode.new()
	map_node.encounter_id = str(data.get("encounter_id", ""))
	var position_data: Array = data.get("position", [0, 0])
	if position_data.size() >= 2:
		map_node.position = Vector2(float(position_data[0]), float(position_data[1]))
	var lines: Array[String] = []
	for source_id in data.get("unlocked_by", []):
		lines.append(str(source_id))
	map_node.unlocked_by = lines
	var requirement_key: String = ModExportable.find_case_insensitive_enum_key(LineRequirement.keys(), str(data.get("line_requirement", "ALL")))
	if requirement_key != "":
		map_node.line_requirement = LineRequirement[requirement_key]
	var conditions: Array[UnlockCondition] = []
	for condition_data in data.get("unlock_conditions", []):
		var condition: UnlockCondition = ModdableResourceRegistry.instantiate(condition_data) as UnlockCondition
		if condition:
			conditions.append(condition)
	map_node.unlock_conditions = conditions
	return map_node
#endregion
