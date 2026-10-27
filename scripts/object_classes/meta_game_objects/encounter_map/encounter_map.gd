@tool
extends ModExportable
class_name EncounterMap

### An overworld map drawn from hand-placed nodes: which encounters are on it, where they are, and what unlocks each of
### them (see EncounterMapNode). The rework's main map (Full Rework, set as ContentSet.encounter_map) carries its
### encounters over into the rework, so they need no content set entry, and its nodes replace the encounters' own
### unlock_conditions. Mods add maps of their own (JSON, see to_json_dict()), which the player picks in the overworld
### map's dropdown in either mode (AutoloadDatabase.set_active_map()).
### Shared class (not in the rework folder) so AutoloadDatabase/ContentSet can name it; the rework's map file itself
### lives in the rework folder.

### A mod map's id: the save remembers the chosen map by it. Unused on the main map (AutoloadDatabase.MAIN_MAP_ID).
@export var map_id: String = "":
	set(value):
		map_id = value
		emit_changed()
### The name in the map dropdown, shown as written (mod text). Unused on the main map.
@export var map_name: String = "":
	set(value):
		map_name = value
		emit_changed()

### Keyed by the node's encounter id. The key is only a label for the inspector, like ContentSet's sections:
### AutoloadDatabase warns when it doesn't match the encounter's real id. Setting it emits `changed` (the Encounter Map
### editor tab redraws on it).
@export var nodes: Dictionary[String, EncounterMapNode] = {}:
	set(value):
		nodes = value
		emit_changed()

func get_node_for_encounter(encounter_id: String) -> EncounterMapNode:
	var map_node: EncounterMapNode = nodes.get(encounter_id, null)
	if map_node and map_node.get_encounter_id() == encounter_id:
		return map_node
	### The key doesn't match (warned about on load): look through the nodes instead.
	for candidate: EncounterMapNode in nodes.values():
		if candidate and candidate.get_encounter_id() == encounter_id:
			return candidate
	return null

func get_map_name() -> String:
	if map_name != "":
		return map_name
	return map_id

#region Mod export
func get_mod_export_subfolder() -> String:
	return "maps"

### Called by ModConfig before exporting: a mod map needs an id (the save remembers the chosen map by it), and every
### node needs an encounter.
func validate(errors: Array[String]) -> bool:
	if map_id == "":
		errors.append("Encounter map '%s' has no map_id." % resource_path)
	for key: String in nodes.keys():
		var map_node: EncounterMapNode = nodes[key]
		if map_node == null or map_node.get_encounter_id() == "":
			errors.append("Encounter map '%s': the node '%s' has no encounter." % [resource_path, key])
	return errors.is_empty()

### Hand-written: the nodes are written as a list (each names its own encounter, see EncounterMapNode.to_json_dict()).
func to_json_dict() -> Dictionary:
	var node_dicts: Array = []
	for map_node: EncounterMapNode in nodes.values():
		if map_node:
			node_dicts.append(map_node.to_json_dict())
	return {
		"_class": get_script().get_global_name(),
		"map_id": map_id,
		"map_name": map_name,
		"nodes": node_dicts,
	}

### Nodes without an encounter id, and a second node for the same encounter, are left out with a warning.
static func from_json_dict(data: Dictionary) -> EncounterMap:
	var map: EncounterMap = EncounterMap.new()
	map.map_id = str(data.get("map_id", ""))
	map.map_name = str(data.get("map_name", ""))
	for node_data in data.get("nodes", []):
		if typeof(node_data) != TYPE_DICTIONARY:
			continue
		var map_node: EncounterMapNode = EncounterMapNode.from_json_dict(node_data)
		var encounter_id: String = map_node.get_encounter_id()
		if encounter_id == "":
			push_warning("Encounter map '%s': a node without an encounter_id was left out." % map.map_id)
			continue
		if map.nodes.has(encounter_id):
			push_warning("Encounter map '%s': '%s' is on the map twice; the second node was left out." % [map.map_id, encounter_id])
			continue
		map.nodes[encounter_id] = map_node
	return map
#endregion
