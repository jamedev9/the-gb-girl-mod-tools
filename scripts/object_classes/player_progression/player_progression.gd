extends Resource
class_name PlayerProgression

var _default_progression_version: String = "0.0.0"
var progression_version: String = _default_progression_version

#region Unlocked characters:
var _default_unlocked_characters: Array = [
	"default"
]
var unlocked_characters: Array = _default_unlocked_characters.duplicate(true)

func get_unlocked_characters() -> Array:
	return unlocked_characters

func is_character_unlocked(character_id: String) -> bool:
	return character_id in unlocked_characters

func unlock_character(character_id: String) -> void:
	if character_id in unlocked_characters:
		return
	unlocked_characters.append(character_id)

func lock_character(character_id: String) -> void:
	if character_id not in unlocked_characters:
		return
	unlocked_characters.erase(character_id)

#endregion

#region Methods for saving:
func to_dict() -> Dictionary:
	return {
		"progression_version": SaveSystem.get_current_game_version(),
		"unlocked_characters": unlocked_characters,
	}

func from_dict(data: Dictionary) -> void:
	progression_version = data.get("progression_version", _default_progression_version)
	unlocked_characters = data.get("unlocked_characters", _default_unlocked_characters.duplicate(true))

#endregion

func _retroactively_add_missing_features_() -> void:
	### Called by SaveSystem when loading, to add new features to old progression files.
	pass
