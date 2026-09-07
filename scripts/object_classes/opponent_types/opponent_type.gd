extends Resource
class_name OpponentType

### Variables
@export var opponent_type_id: String
@export var opponent_type_name: String
@export var summonable_ally: bool = false

@export var picture: Texture2D
@export var video_particpant_tags: Array[VideoClip.ParticipantTags]
@export var name_lists: Array[NameList] = []
@export var card_color: Color = Color(0.286, 0.714, 1.0, 1.0)

@export var max_damage: int
@export var orgasms_before_defeat: int = 1

@export var available_actions: Array[OpponentActionDefinition]
@export var action_strategy: OpponentActionStrategy
 
@export var passive_effects: Array[String] # IDs of passive effects.

func get_opponent_type_name() -> String:
	return tr("OPPONENTTYPE_"+opponent_type_id.to_upper()+"_OPPONENT_TYPE_NAME")

func get_translation_entries() -> Array[Dictionary]:
	return [
		{"key": "OPPONENTTYPE_"+opponent_type_id.to_upper()+"_OPPONENT_TYPE_NAME", "text": opponent_type_name},
	]


func get_random_name() -> String:
	if name_lists.is_empty():
		return ""
	var available_names: Array[String] = []
	for list in name_lists:
		available_names.append_array(list.names)
	
	return Utils.get_random_item(available_names)

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
