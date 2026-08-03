extends Resource
class_name PictureList

@export var id: String

@export var pictures: Array[Texture2D]

func get_random_picture() -> Texture2D:
	return Utils.get_random_item(pictures)
