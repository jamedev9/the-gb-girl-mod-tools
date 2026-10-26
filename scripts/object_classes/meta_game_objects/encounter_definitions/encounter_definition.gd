@tool
extends ModExportable
class_name EncounterDefinition

@export_category("Map node properties")
@export var unlock_conditions: Array[UnlockCondition]
@export var branch_index: int
@export var rewards_granted_by_clearing: Array[String] #Reward Definition IDs
@export var map_region_id: String

@export_category("Encounter info")
@export var encounter_id: String
@export var encounter_display_name: String
@export var encounter_description: String
@export var encounter_picture: Texture2D
@export var encounter_music: AudioStream
### One of the game's soundtracks by id (MusicTrack.track_id), used when encounter_music is empty: lets a mod use the
### game's music without its files. Read the music through get_encounter_music().
@export var music_track_id: String = ""

@export var opponents_in_encounter_reserves: Dictionary[String,int] = {
	#"avg_joe":3,
	#"wingman": 2,
	#"long_john": 3
}

@export var min_simultaneous_opponents: int
### Highest number of opponents that can be active at once. 0 = not set: the game's default is used
### (GameState.max_simultaneous_opponents). Any value above 0 replaces it for this encounter.
@export var max_simultaneous_opponents: int = 0

### Passive IDs the player gets for this encounter only, at its start. They are never added to the save,
### so they disappear when the encounter ends (e.g. "gloryhole", which blinds the player).
@export var temporary_player_passives: Array[String] = []

@export var fixed_spawn_order: Dictionary[int,String] = {} # int (spawn number) -> opponent_type_id

@export var event_cards_starting_hand: Dictionary[String,int] = {
	#"invert_outgoing_damage":1,
	#"player_dubs_damage": 1,
}

@export var forbid_all_summons: bool = false
@export var forbidden_ally_summons: Array[String] = [] #ID of opponent type. Use for lore or challenge reasons

### Set by AutoloadDatabase on encounters loaded from a mod's JSON. The name and description are shown as written
### instead of going through tr() (see EventCardDefinition.is_modded). A mod encounter is only played from a mod map,
### never from the main game's map. @export_storage (stored, not shown in the Inspector) so duplicate() keeps it: an
### encounter is played as a copy (MainCardgame), which would otherwise show translation keys. The hand-written
### to_json_dict() never writes it.
@export_storage var is_modded: bool = false

func get_encounter_name() -> String:
	if is_modded:
		return encounter_display_name
	return tr("ENCOUNTERDEFINITION_"+encounter_id.to_upper()+"_ENCOUNTER_DISPLAY_NAME")
func get_encounter_description() -> String:
	if is_modded:
		return encounter_description
	return tr("ENCOUNTERDEFINITION_"+encounter_id.to_upper()+"_ENCOUNTER_DESCRIPTION")

### The encounter's own music file, else the registered track music_track_id names (null when neither is there).
func get_encounter_music() -> AudioStream:
	if encounter_music:
		return encounter_music
	if music_track_id == "":
		return null
	var track: MusicTrack = AutoloadDatabase.get_music_track(music_track_id)
	if track == null:
		return null
	return track.stream

func get_translation_entries() -> Array[Dictionary]:
	if is_modded:
		return [] ### Mod text is shown as written, and must not be written into game.csv by the editor's auto-localization.
	var prefix: String = "ENCOUNTERDEFINITION_"+encounter_id.to_upper()
	return [
		{"key": prefix+"_ENCOUNTER_DISPLAY_NAME", "text": encounter_display_name},
		{"key": prefix+"_ENCOUNTER_DESCRIPTION", "text": encounter_description},
	]

#region Mod export
func get_mod_export_subfolder() -> String:
	return "encounters"

func get_file_reference_fields() -> Dictionary:
	return {"encounter_picture": "images", "encounter_music": "music"}

### Hand-written rather than the generic ModExportable default because encounter_picture/encounter_music are file
### references (see get_file_reference_fields()). Everything else is plain data or ids (opponent types, cards,
### passives, rewards, the map region), which may name base-game or mod content alike. The unlock conditions use
### their own generic to_json_dict().
func to_json_dict() -> Dictionary:
	var condition_dicts: Array = []
	for condition in unlock_conditions:
		if condition:
			condition_dicts.append(condition.to_json_dict())
	### JSON object keys can only be strings: the spawn numbers are written as text and read back as ints.
	var spawn_order: Dictionary = {}
	for spawn_number in fixed_spawn_order.keys():
		spawn_order[str(spawn_number)] = fixed_spawn_order[spawn_number]

	return {
		"_class": get_script().get_global_name(),
		"encounter_id": encounter_id,
		"encounter_display_name": encounter_display_name,
		"encounter_description": encounter_description,
		"encounter_picture": ModExportable.resolve_to_res_path(encounter_picture.resource_path) if encounter_picture else "",
		"encounter_music": ModExportable.resolve_to_res_path(encounter_music.resource_path) if encounter_music else "",
		"music_track_id": music_track_id,
		"unlock_conditions": condition_dicts,
		"branch_index": branch_index,
		"rewards_granted_by_clearing": rewards_granted_by_clearing.duplicate(),
		"map_region_id": map_region_id,
		"opponents_in_encounter_reserves": opponents_in_encounter_reserves.duplicate(),
		"min_simultaneous_opponents": min_simultaneous_opponents,
		"max_simultaneous_opponents": max_simultaneous_opponents,
		"temporary_player_passives": temporary_player_passives.duplicate(),
		"fixed_spawn_order": spawn_order,
		"event_cards_starting_hand": event_cards_starting_hand.duplicate(),
		"forbid_all_summons": forbid_all_summons,
		"forbidden_ally_summons": forbidden_ally_summons.duplicate(),
	}

### mod_root_path: the mod's own folder (user://mods/<mod>); the picture and music are read from the subfolders
### get_file_reference_fields() names. JSON gives every number as a float, so the ints are cast here. The typed
### dictionaries are filled in place (a plain Dictionary can't be assigned to them).
static func from_json_dict(data: Dictionary, mod_root_path: String = "") -> EncounterDefinition:
	var encounter_def: EncounterDefinition = EncounterDefinition.new()
	encounter_def.encounter_id = str(data.get("encounter_id", ""))
	encounter_def.encounter_display_name = str(data.get("encounter_display_name", ""))
	encounter_def.encounter_description = str(data.get("encounter_description", ""))
	encounter_def.music_track_id = str(data.get("music_track_id", ""))
	encounter_def.branch_index = int(data.get("branch_index", 0))
	encounter_def.map_region_id = str(data.get("map_region_id", ""))
	encounter_def.min_simultaneous_opponents = int(data.get("min_simultaneous_opponents", 0))
	encounter_def.max_simultaneous_opponents = int(data.get("max_simultaneous_opponents", 0))
	encounter_def.forbid_all_summons = bool(data.get("forbid_all_summons", false))

	for reward_id in data.get("rewards_granted_by_clearing", []):
		encounter_def.rewards_granted_by_clearing.append(str(reward_id))
	for passive_id in data.get("temporary_player_passives", []):
		encounter_def.temporary_player_passives.append(str(passive_id))
	for opponent_type_id in data.get("forbidden_ally_summons", []):
		encounter_def.forbidden_ally_summons.append(str(opponent_type_id))

	var reserves: Dictionary = data.get("opponents_in_encounter_reserves", {})
	for opponent_type_id in reserves.keys():
		encounter_def.opponents_in_encounter_reserves[str(opponent_type_id)] = int(reserves[opponent_type_id])
	var spawn_order: Dictionary = data.get("fixed_spawn_order", {})
	for spawn_number in spawn_order.keys():
		encounter_def.fixed_spawn_order[int(spawn_number)] = str(spawn_order[spawn_number])
	var starting_hand: Dictionary = data.get("event_cards_starting_hand", {})
	for card_id in starting_hand.keys():
		encounter_def.event_cards_starting_hand[str(card_id)] = int(starting_hand[card_id])

	for condition_data in data.get("unlock_conditions", []):
		var condition: UnlockCondition = ModdableResourceRegistry.instantiate(condition_data) as UnlockCondition
		if condition:
			encounter_def.unlock_conditions.append(condition)

	var file_folders: Dictionary = encounter_def.get_file_reference_fields()
	var picture_file_name: String = data.get("encounter_picture", "")
	if picture_file_name != "" and mod_root_path != "":
		encounter_def.encounter_picture = Utils.load_texture_from_path(mod_root_path.path_join(file_folders["encounter_picture"]).path_join(picture_file_name))
	var music_file_name: String = data.get("encounter_music", "")
	if music_file_name != "" and mod_root_path != "":
		encounter_def.encounter_music = Utils.load_audio_stream_from_path(mod_root_path.path_join(file_folders["encounter_music"]).path_join(music_file_name))

	return encounter_def
#endregion
