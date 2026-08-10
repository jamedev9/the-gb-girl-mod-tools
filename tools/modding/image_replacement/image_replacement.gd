@tool
extends Resource
class_name ImageReplacement

enum ReplacementType {
	EVENT_CARD_IMAGE,
	ACTION_CARD_IMAGE,
	OPPONENT_TYPE_IMAGE,
}

@export var replacement_type: ReplacementType
@export var target_id: String = ""
@export_file("*.png", "*.jpg", "*.jpeg") var image_path: String = ""
