extends Node
class_name GlobalVideoPlayerSystem

@onready var database: VideoDatabase = _load_video_clips_into_database()

var video_clip_folder_path: String  = "res://resources/videos/video_clips/"

const MODS_DIR: String = "user://mods/"

var _imported_video_file_names: Dictionary = {} ### sanitized file name -> true, tracks dupes across all mods this load

func _load_video_clips_into_database() -> VideoDatabase:
	var new_database: VideoDatabase = VideoDatabase.new()
	var video_clips = Utils.load_resources_in_folder(video_clip_folder_path)
	new_database.video_clips.append_array(video_clips)
	var clips_from_mods = _load_mod_video_clips()
	new_database.video_clips.append_array(clips_from_mods)
	return new_database

func get_video_by_tags(
	required_action_tags: Array[VideoClip.ActionTags] = [],
	required_participant_tags: Array[VideoClip.ParticipantTags] = []) -> VideoClip:
		
	return database.get_random_clip(required_action_tags,required_participant_tags)

### Claude-induced modding, added 19.07.26

func _load_mod_video_clips() -> Array[VideoClip]:
	_imported_video_file_names.clear()
	var loaded_clips: Array[VideoClip] = []
	if not DirAccess.dir_exists_absolute(MODS_DIR):
		DirAccess.make_dir_recursive_absolute(MODS_DIR)
		#print("No mods folder found at %s, skipping mod video loading." % MODS_DIR)
		#return loaded_clips
	var mods_dir: DirAccess = DirAccess.open(MODS_DIR)
	mods_dir.list_dir_begin()
	var mod_folder_name: String = mods_dir.get_next()
	while mod_folder_name != "":
		if mods_dir.current_is_dir() and not mod_folder_name.begins_with("."):
			#print("Found mod folder: %s" % mod_folder_name)
			var clips_from_mod: Array[VideoClip] = _load_clips_from_mod_folder(MODS_DIR + mod_folder_name + "/videos/")
			#print("Loaded %s valid clip(s) from mod '%s'" % [clips_from_mod.size(), mod_folder_name])
			loaded_clips.append_array(clips_from_mod)
		mod_folder_name = mods_dir.get_next()
	mods_dir.list_dir_end()
	#print("Finished loading mods. Total mod clips loaded: %s" % loaded_clips.size())
	return loaded_clips

func _load_clips_from_mod_folder(videos_path: String) -> Array[VideoClip]:
	var clips: Array[VideoClip] = []
	if not DirAccess.dir_exists_absolute(videos_path):
		#print("No videos folder found at %s, skipping." % videos_path)
		return clips
	
	var json_file_names: Array[String] = _find_json_files_in_folder(videos_path)
	if json_file_names.is_empty():
		#print("No .json clip definition files found in %s" % videos_path)
		return clips
	
	for json_file_name in json_file_names:
		var json_path: String = videos_path + json_file_name
		#print("Reading clip definitions from: %s" % json_path)
		var clips_from_file: Array[VideoClip] = _load_clips_from_json_file(json_path, videos_path)
		#print("Loaded %s valid clip(s) from %s" % [clips_from_file.size(), json_file_name])
		clips.append_array(clips_from_file)
	
	return clips

func _find_json_files_in_folder(folder_path: String) -> Array[String]:
	var json_files: Array[String] = []
	var dir: DirAccess = DirAccess.open(folder_path)
	if not dir:
		push_warning("Could not open folder for scanning: %s" % folder_path)
		return json_files
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			json_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return json_files
	
func _load_clips_from_json_file(json_path: String, videos_path: String) -> Array[VideoClip]:
	var clips: Array[VideoClip] = []
	var json_text: String = FileAccess.get_file_as_string(json_path)
	var json := JSON.new()
	if json.parse(json_text) != OK:
		push_warning("Failed to parse JSON at %s" % json_path)
		return clips

	if json.data is Array:
		### Bundle format: many clips in one file, each entry uses "file" as the key
		var entries: Array = json.data
		for entry in entries:
			if entry is not Dictionary:
				push_warning("Skipping malformed clip entry (not an object) in %s" % json_path)
				continue
			var clip: VideoClip = _build_video_clip_from_json(entry, videos_path)
			if clip:
				clips.append(clip)
	elif json.data is Dictionary:
		### Single-clip format, exported by the mod tool, uses "video_file" as the key
		var clip: VideoClip = _build_video_clip_from_json(json.data, videos_path)
		if clip:
			clips.append(clip)
	else:
		push_warning("%s must contain either a JSON object (single clip) or a JSON array (multiple clips) at the top level." % json_path)

	return clips

func _build_video_clip_from_json(entry: Dictionary, videos_path: String) -> VideoClip:
	var raw_file_name: String = ""
	if entry.has("file"):
		raw_file_name = entry["file"]
	elif entry.has("video_file"):
		raw_file_name = entry["video_file"]
	else:
		push_warning("Mod clip entry missing 'file'/'video_file' field: %s" % JSON.stringify(entry))
		return null
	#print("Importing file name: %s" % raw_file_name)
	
	var sanitized_file_name: String = _sanitize_file_name(raw_file_name)
	if sanitized_file_name.is_empty():
		push_warning("Rejected unsafe or invalid file name: %s" % raw_file_name)
		return null
	#if sanitized_file_name != raw_file_name:
		#print("Sanitized file name from '%s' to '%s'" % [raw_file_name, sanitized_file_name])
	
	if not sanitized_file_name.ends_with(".ogv"):
		push_warning("Rejected clip '%s': only .ogv files are supported." % sanitized_file_name)
		return null

	if sanitized_file_name in _imported_video_file_names.keys():
		push_warning("Skipping duplicate video clip '%s' — a clip referencing this file was already imported." % sanitized_file_name)
		return null
	
	var video_path: String = videos_path + sanitized_file_name
	if not FileAccess.file_exists(video_path):
		push_warning("Mod video file not found: %s" % video_path)
		return null
	
	var video_stream: VideoStreamTheora = _load_external_ogv(video_path)
	if not video_stream:
		push_warning("Failed to load video stream for: %s" % video_path)
		return null
	
	var clip : VideoClip = VideoClip.new()
	clip.video_file = video_stream
	clip.action_tags = _parse_action_tags(entry.get("action_tags", []), sanitized_file_name)
	clip.participant_tags = _parse_participant_tags(entry.get("participant_tags", []), sanitized_file_name)
	clip.weight = _sanitize_weight(entry.get("weight", 1.0))

	_imported_video_file_names[sanitized_file_name] = true
	
	#print("Successfully imported clip: %s" % sanitized_file_name)
	return clip

func _load_external_ogv(path: String) -> VideoStreamTheora:
	if not path.ends_with(".ogv"):
		push_warning("Mod video must be .ogv format: %s" % path)
		return null
	var stream := VideoStreamTheora.new()
	stream.file = path
	return stream

func _sanitize_file_name(file_name: String) -> String:
	if file_name.is_empty():
		return ""
	# Reject path traversal and directory separators entirely
	if "/" in file_name or "\\" in file_name or ".." in file_name:
		return ""
	# Reject absolute-looking paths or drive letters
	if file_name.begins_with(":") or ":" in file_name:
		return ""
	# Only allow a safe character set: letters, numbers, underscore, hyphen, dot
	var regex := RegEx.new()
	regex.compile("^[a-zA-Z0-9_\\-\\.]+$")
	if not regex.search(file_name):
		return ""
	return file_name

func _parse_action_tags(tag_names: Array, clip_file_name: String) -> Array[VideoClip.ActionTags]:
	var parsed: Array[VideoClip.ActionTags] = []
	for tag_name in tag_names:
		if tag_name is not String:
			push_warning("Non-string action tag found in clip '%s', skipping tag." % clip_file_name)
			continue
		if VideoClip.ActionTags.has(tag_name):
			parsed.append(VideoClip.ActionTags[tag_name])
		else:
			push_warning("Unknown action tag '%s' in clip '%s', skipping tag." % [tag_name, clip_file_name])
	return parsed

func _parse_participant_tags(tag_names: Array, clip_file_name: String) -> Array[VideoClip.ParticipantTags]:
	var parsed: Array[VideoClip.ParticipantTags] = []
	for tag_name in tag_names:
		if tag_name is not String:
			push_warning("Non-string participant tag found in clip '%s', skipping tag." % clip_file_name)
			continue
		if VideoClip.ParticipantTags.has(tag_name):
			parsed.append(VideoClip.ParticipantTags[tag_name])
		else:
			push_warning("Unknown participant tag '%s' in clip '%s', skipping tag." % [tag_name, clip_file_name])
	return parsed

func _sanitize_weight(raw_weight) -> float:
	if raw_weight is not float and raw_weight is not int:
		push_warning("Invalid weight value, defaulting to 1.0")
		return 1.0
	var weight: float = float(raw_weight)
	if weight <= 0.0:
		push_warning("Weight must be positive, defaulting to 1.0")
		return 1.0
	if weight > 100.0:
		push_warning("Weight unreasonably high, clamping to 100.0")
		return 100.0
	return weight
#
