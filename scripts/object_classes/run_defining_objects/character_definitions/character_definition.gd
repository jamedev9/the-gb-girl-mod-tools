@tool
extends ModExportable
class_name CharacterDefinition

@export var character_id: String = ""
@export var character_name: String = "" # Flavour
@export var character_class_name: String = "" # Flavour
@export_range(18,100,1) var character_age: int
@export_file("*.png", "*.jpg", "*.jpeg") var portrait_image_path: String
#@export var portrait_image_path: String
#@export var video_participant_tags: Array[String] = [] # NEW: must match VideoClip.ParticipantTags
@export var video_participant_tags: Array[VideoClip.ParticipantTags] = [] # Since we are letting modders use this, they can use the enum and not use strings.
@export var starting_passives: Array[String] = []
@export var starting_actions: Array[String] = []
@export var starting_reward_cards_for_actions: Dictionary[String, Array] = {} #ActionID, array of EventCardIDs
@export var extra_starting_cards: Dictionary[String,int] = {} # card_id, count
@export var minimum_deck_size: int = 20
@export_range(0,5,1) var starting_orgasms: int = 2
@export_range(1,500,1) var starting_max_pleasure: int = 100
@export_range(0,50,1) var starting_max_energy: int = 10
@export var starting_ally_card: String = ""
@export var starting_orgasm_card: String = ""

var is_modded: bool = false

func apply_to_save_game(save_game_state: SaveGameState) -> void:
	if character_name:
		save_game_state.set_player_character_name(character_name)
	
	if character_class_name:
		save_game_state.set_character_class(character_class_name)
	
	if character_age:
		save_game_state.set_player_age(character_age)
	
	if portrait_image_path:
		save_game_state.character_portrait_path = portrait_image_path
	
	if not starting_actions.is_empty():
		save_game_state.remove_all_player_actions()
		for action in starting_actions:
			save_game_state.add_new_player_action(action)
	
	for passive_id in starting_passives:
		save_game_state.give_player_passive(passive_id, true)

	if not extra_starting_cards.keys().is_empty():
		save_game_state.give_player_cards(extra_starting_cards)
	
	if not starting_reward_cards_for_actions.is_empty():
		for action_id in starting_reward_cards_for_actions.keys():
			for card_id in starting_reward_cards_for_actions[action_id]:
				save_game_state.unlock_reward_card_for_action(card_id,action_id)
	
	if minimum_deck_size:
		save_game_state.set_min_deck_size(minimum_deck_size)
	
	if not video_participant_tags.is_empty():
		save_game_state.add_video_particpant_tags_from_string_array(video_participant_tags)
	
	if starting_orgasms:
		save_game_state.player["hp"] = starting_orgasms

	if starting_max_pleasure:
		save_game_state.player["damage_threshold"] = starting_max_pleasure

	if starting_max_energy:
		save_game_state.player["max_energy"] = starting_max_energy

	if starting_ally_card != "":
		save_game_state.give_player_new_ally_card(starting_ally_card,true)

	if starting_orgasm_card != "":
		save_game_state.clear_all_orgasm_cards()
		save_game_state.unlock_orgasm_card(starting_orgasm_card)
		save_game_state.set_current_orgasm_card(starting_orgasm_card)

func get_reward_cards_for_action(action_id: String) -> Array:
	if action_id not in starting_reward_cards_for_actions.keys():
		return []
	return starting_reward_cards_for_actions[action_id]

func get_mod_export_subfolder() -> String:
	return "characters"

func get_file_reference_fields() -> Dictionary:
	return {"portrait_image_path": "images"}

func get_starting_orgasm_count() -> int:
	return self.starting_orgasms

func get_starting_pleasure_max() -> int:
	return self.starting_max_pleasure

func to_json_dict() -> Dictionary:
	print(portrait_image_path)
	return {
		"character_id": character_id,
		"character_class_name": character_class_name,
		"character_name": character_name,
		"character_age": character_age,
		"portrait_image_path": _resolve_to_res_path(portrait_image_path) , #.get_file(), ### store filename only
		"video_participant_tags": VideoClip._convert_participant_tags_to_string(video_participant_tags,character_id),
		"starting_passives": starting_passives,
		"starting_actions": starting_actions,
		"extra_starting_cards": extra_starting_cards,
		"starting_orgasms": starting_orgasms,
		"starting_max_pleasure": starting_max_pleasure,
		"starting_max_energy": starting_max_energy,
		"starting_ally_card": starting_ally_card,
		"starting_orgasm_card": starting_orgasm_card,
		"minimum_deck_size":minimum_deck_size,
		"starting_reward_cards_for_actions":starting_reward_cards_for_actions
		
	}

static func _resolve_to_res_path(path: String) -> String:
	if path.begins_with("uid://"):
		var uid: int = ResourceUID.text_to_id(path)
		if ResourceUID.has_id(uid):
			return ResourceUID.get_id_path(uid)
		push_warning("Could not resolve uid path: %s" % path)
		return ""
	return path

static func from_json_dict(data: Dictionary, mod_folder_path: String = "") -> CharacterDefinition:
	var character_def := CharacterDefinition.new()
	character_def.character_id = data.get("character_id", "")
	character_def.character_class_name = data.get("character_class_name", "")
	character_def.character_name = data.get("character_name", "")
	character_def.character_age = int(data.get("character_age", 18))
	#character_def.video_participant_tags = VideoClip._convert_participant_tags_to_string(
	#VideoClip._parse_moddable_participant_tags(data.get("video_participant_tags", []), character_def.character_id),character_def.character_id
#)
	character_def.video_participant_tags = VideoClip._parse_moddable_participant_tags(data.get("video_participant_tags", []), data.get("character_id",""))
	character_def.starting_passives = _to_string_array(data.get("starting_passives", []))
	character_def.starting_actions = _to_string_array(data.get("starting_actions", []))
	character_def.extra_starting_cards = _to_string_int_dict(data.get("extra_starting_cards", {}))
	character_def.starting_orgasms = int(data.get("starting_orgasms", 0))
	character_def.starting_max_pleasure = int(data.get("starting_max_pleasure", 0))
	character_def.starting_max_energy = int(data.get("starting_max_energy", 0))
	character_def.starting_ally_card = data.get("starting_ally_card", "")
	character_def.starting_orgasm_card = data.get("starting_orgasm_card", "")
	character_def.minimum_deck_size = data.get("minimum_deck_size",SaveGameState.get_default_min_deck_size())
	character_def.starting_reward_cards_for_actions = _to_string_array_dict(data.get("starting_reward_cards_for_actions",{}))
	
	var portrait_file_name: String = data.get("portrait_image_path", "")
	if portrait_file_name != "" and mod_folder_path != "":
		character_def.portrait_image_path = mod_folder_path.path_join(portrait_file_name)
	else:
		character_def.portrait_image_path = portrait_file_name

	return character_def

static func _to_string_array(raw: Array) -> Array[String]:
	var result: Array[String] = []
	for entry in raw:
		result.append(str(entry))
	return result

static func _to_string_int_dict(raw: Dictionary) -> Dictionary[String,int]:
	var result: Dictionary[String,int] = {}
	for key in raw.keys():
		result[str(key)] = int(raw[key])
	return result

static func _to_string_array_dict(raw: Dictionary) -> Dictionary[String, Array]:
	var result: Dictionary[String, Array] = {}
	for key in raw.keys():
		result[str(key)] = Array(raw[key])
	return result
