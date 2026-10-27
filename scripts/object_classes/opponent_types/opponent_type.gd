@tool
extends ModExportable
class_name OpponentType

### Variables
@export var opponent_type_id: String
@export var opponent_type_name: String
@export var summonable_ally: bool = false

### Internal note on what this type is supposed to look like (read off the prototype picture). Used to
### choose appearances/hairstyles; never shown to the player, so it is not localized.
@export_multiline var visual_description: String = ""

@export var picture: Texture2D
@export var appearance_variations: Array[OpponentAppearance] = []
@export var video_particpant_tags: Array[VideoClip.ParticipantTags]
### Name lists only this type uses, embedded in its file (no id). Lists shared with other types: name_list_ids.
@export var name_lists: Array[NameList] = []
### Shared name lists by NameList.name_list_id (registered content, moddable). Names come from both fields together.
@export var name_list_ids: Array[String] = []
@export var card_color: Color = Color(0.286, 0.714, 1.0, 1.0)

@export var max_damage: int
@export var orgasms_before_defeat: int = 1

### The Moves this type can make, by opponent_action_id. The order counts: the sequential strategies go through it.
@export var available_action_ids: Array[String] = []
@export var action_strategy: OpponentActionStrategy

@export var passive_effects: Array[String] # IDs of passive effects.

### True for a type loaded from a mod: its name is shown as written, never through tr(). @export_storage (stored, not shown
### in the Inspector) so duplicate() keeps it. The hand-written to_json_dict() never writes it.
@export_storage var is_modded: bool = false

func _validate_property(property: Dictionary) -> void:
	ContentIdSuggestions.apply_to_array_property(property, "available_action_ids", "OpponentActionDefinition", "opponent_action_id")
	ContentIdSuggestions.apply_to_array_property(property, "name_list_ids", "NameList", "name_list_id")

### The registered Moves of available_action_ids, in order. An id that isn't registered (its mod is gone) is left out.
func get_available_actions() -> Array[OpponentActionDefinition]:
	var actions: Array[OpponentActionDefinition] = []
	for action_id in available_action_ids:
		var action: OpponentActionDefinition = AutoloadDatabase.opponent_actions.get(action_id, null)
		if action == null:
			push_warning("Opponent type '%s' names the Move '%s', which isn't registered." % [opponent_type_id, action_id])
			continue
		actions.append(action)
	return actions

func get_opponent_type_name() -> String:
	if is_modded:
		return opponent_type_name
	return tr("OPPONENTTYPE_"+opponent_type_id.to_upper()+"_OPPONENT_TYPE_NAME")

func get_translation_entries() -> Array[Dictionary]:
	if is_modded:
		return [] ### Mod text is shown as written, and must not be written into game.csv by the editor's auto-localization.
	return [
		{"key": "OPPONENTTYPE_"+opponent_type_id.to_upper()+"_OPPONENT_TYPE_NAME", "text": opponent_type_name},
	]


### A random name from the embedded name_lists and the registered lists of name_list_ids together ("" when there is none).
### A list id that isn't registered (its mod is gone) is left out.
func get_random_name() -> String:
	var available_names: Array[String] = []
	for list in name_lists:
		if list:
			available_names.append_array(list.names)
	for list_id in name_list_ids:
		var shared_list: NameList = AutoloadDatabase.name_lists_by_id.get(list_id, null)
		if shared_list:
			available_names.append_array(shared_list.names)
	if available_names.is_empty():
		return ""
	return Utils.get_random_item(available_names)

func get_random_appearance() -> OpponentAppearance:
	if appearance_variations.is_empty():
		return null
	return appearance_variations.pick_random()

func get_cock_picture() -> Texture2D:
	var list_id: String = ""
	if VideoClip.ParticipantTags.BBC in video_particpant_tags:
		list_id = "bbc"
	if VideoClip.ParticipantTags.WHITE_MAN in video_particpant_tags:
		list_id = "white_big"
	if VideoClip.ParticipantTags.JAPANESE_MAN in video_particpant_tags:
		list_id = "white_big" ### TODO: Find pics for this
	if opponent_type_id == "cuck_bf_caged":
		list_id = "cuck_cage"
	if opponent_type_id == "cuck_bf":
		list_id = "white_small"
	if opponent_type_id == "secret_society_master_of_ceremonies":
		list_id = "master_of_ceremonies"
	if opponent_type_id == "female_flight_attendant":
		list_id = "flight_attendant_clothes"
	
	if list_id == "":
		list_id = "default_picture"
		
	return AutoloadDatabase.get_picture_list(list_id).get_random_picture()	

func get_opponent_color() -> Color:
	return card_color

#region Mod export
func get_mod_export_subfolder() -> String:
	return "opponent_types"

func get_file_reference_fields() -> Dictionary:
	return {"picture": "images"}

### Hand-written rather than the generic ModExportable default because picture: Texture2D is a file reference (see
### get_file_reference_fields()). Moves, passives and shared name lists are ids; the embedded name lists are written as one
### "names" list; the participant tags by name, the colour as HTML, the strategy through the registry. Left out:
### appearance_variations (the rework's layered art is not moddable yet: a mod type shows its picture) and
### visual_description (an internal note).
func to_json_dict() -> Dictionary:
	var tag_names: Array = []
	for tag in video_particpant_tags:
		tag_names.append(VideoClip.ParticipantTags.keys()[tag])
	var own_names: Array = []
	for list in name_lists:
		if list:
			own_names.append_array(list.names)

	return {
		"_class": get_script().get_global_name(),
		"opponent_type_id": opponent_type_id,
		"opponent_type_name": opponent_type_name,
		"summonable_ally": summonable_ally,
		"picture": ModExportable.resolve_to_res_path(picture.resource_path, resource_path) if picture else "",
		"video_participant_tags": tag_names,
		"names": own_names,
		"name_list_ids": Array(name_list_ids),
		"card_color": card_color.to_html(true),
		"max_damage": max_damage,
		"orgasms_before_defeat": orgasms_before_defeat,
		"available_action_ids": Array(available_action_ids),
		"action_strategy": action_strategy.to_json_dict() if action_strategy else {},
		"passive_effects": Array(passive_effects),
	}

### mod_folder_path: the mod's images folder (resolves picture, see get_file_reference_fields()). A missing or unknown
### strategy becomes Strategy_SelectRandomAction (every Partner needs one to pick its Moves).
static func from_json_dict(data: Dictionary, mod_folder_path: String = "") -> OpponentType:
	var opponent_type: OpponentType = OpponentType.new()
	opponent_type.opponent_type_id = str(data.get("opponent_type_id", ""))
	opponent_type.opponent_type_name = str(data.get("opponent_type_name", ""))
	opponent_type.summonable_ally = bool(data.get("summonable_ally", false))
	opponent_type.max_damage = int(data.get("max_damage", 0))
	opponent_type.orgasms_before_defeat = int(data.get("orgasms_before_defeat", 1))
	opponent_type.card_color = Color.from_string(str(data.get("card_color", "")), opponent_type.card_color)

	for tag_name in data.get("video_participant_tags", []):
		var tag_key: String = ModExportable.find_case_insensitive_enum_key(VideoClip.ParticipantTags.keys(), str(tag_name))
		if tag_key != "":
			opponent_type.video_particpant_tags.append(VideoClip.ParticipantTags[tag_key])

	var own_names: Array = data.get("names", [])
	if not own_names.is_empty():
		var own_list: NameList = NameList.new()
		for given_name in own_names:
			own_list.names.append(str(given_name))
		opponent_type.name_lists.append(own_list)
	for list_id in data.get("name_list_ids", []):
		opponent_type.name_list_ids.append(str(list_id))
	for action_id in data.get("available_action_ids", []):
		opponent_type.available_action_ids.append(str(action_id))
	for passive_id in data.get("passive_effects", []):
		opponent_type.passive_effects.append(str(passive_id))

	var strategy_data: Dictionary = data.get("action_strategy", {})
	if not strategy_data.is_empty():
		opponent_type.action_strategy = ModdableResourceRegistry.instantiate(strategy_data) as OpponentActionStrategy
	if opponent_type.action_strategy == null:
		opponent_type.action_strategy = Strategy_SelectRandomAction.new()

	var picture_file_name: String = data.get("picture", "")
	if picture_file_name != "" and mod_folder_path != "":
		opponent_type.picture = Utils.load_texture_from_path(mod_folder_path.path_join(picture_file_name))

	return opponent_type
#endregion
