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

#region Seen videos (unlocks them in the video gallery):
### Holds VideoClip.get_seen_video_key() strings. Untyped - typed arrays break JSON round-trips.
var seen_videos: Array = []

func is_video_seen(video_key: String) -> bool:
	return video_key in seen_videos

func mark_video_as_seen(video_key: String) -> void:
	if video_key in seen_videos:
		return
	seen_videos.append(video_key)

#endregion

#region Video unlock points (spent in the video gallery to unlock a video the player has not seen):
### One point per won encounter (SaveSystem.add_video_unlock_points()); 1 point unlocks 1 video, which is simply marked as seen.
var video_unlock_points: int = 0

### True when the file this was loaded from had no video_unlock_points at all, i.e. it was written before the points existed. The
### player then gets one point for every win already in their saves, once (SaveSystem._grant_video_points_for_earlier_wins_if_needed()).
var _video_points_not_granted_yet: bool = false

func needs_video_points_for_earlier_wins() -> bool:
	return _video_points_not_granted_yet

func set_video_unlock_points_for_earlier_wins(points: int) -> void:
	video_unlock_points = maxi(points, 0)
	_video_points_not_granted_yet = false

func add_video_unlock_points(amount: int) -> void:
	video_unlock_points = maxi(video_unlock_points + amount, 0)

### Spends 1 point to unlock the video. False (and nothing changes) if it is already unlocked or there is no point to spend.
func spend_video_unlock_point_on(video_key: String) -> bool:
	if video_key == "" or is_video_seen(video_key):
		return false
	if video_unlock_points < 1:
		return false
	video_unlock_points -= 1
	mark_video_as_seen(video_key)
	return true

#endregion

#region Code typed in the video gallery:
### The code that unlocked the whole gallery, as it was typed and accepted ("" = none). Only kept here: the gallery itself checks it every time it
### opens, so a code that a later build switches off stops working there. An older build drops this key when it re-saves the file.
var gallery_unlock_code: String = ""

#endregion

#region Methods for saving:
func to_dict() -> Dictionary:
	return {
		"progression_version": SaveSystem.get_current_game_version(),
		"unlocked_characters": unlocked_characters,
		"seen_videos": seen_videos,
		"video_unlock_points": video_unlock_points,
		"gallery_unlock_code": gallery_unlock_code,
	}

func from_dict(data: Dictionary) -> void:
	progression_version = data.get("progression_version", _default_progression_version)
	unlocked_characters = data.get("unlocked_characters", _default_unlocked_characters.duplicate(true))
	seen_videos = data.get("seen_videos", [])
	_video_points_not_granted_yet = not data.has("video_unlock_points")
	video_unlock_points = maxi(int(data.get("video_unlock_points", 0)), 0) ### JSON numbers come back as floats.
	gallery_unlock_code = str(data.get("gallery_unlock_code", ""))

#endregion

func _retroactively_add_missing_features_() -> void:
	### Called by SaveSystem when loading, to add new features to old progression files.
	pass
