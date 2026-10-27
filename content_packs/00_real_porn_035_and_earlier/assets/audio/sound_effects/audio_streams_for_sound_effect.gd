@tool
extends ModExportable
class_name AudioStreamsForSoundEffect

### A sound effect: one of its streams is picked at random each time it plays. Registered content
### (AutoloadDatabase.sound_effects_by_id); event cards name it by sound_effect_id (EventCardDefinition.sound_effect_ids).
### The SoundManager's own sounds (sound_effect_dict, set in the game scenes) are engine settings and still hold the resources.
@export var sound_effect_id: String = ""
@export var audio_streams: Array[AudioStream] = []

### True for a sound effect loaded from a mod. @export_storage so duplicate() keeps it; never written to JSON.
@export_storage var is_modded: bool = false

func get_random_stream() -> AudioStream:
	#if audio_streams.is_empty():
		#return null
	var random_index: int = randi_range(0,audio_streams.size()-1)
	return audio_streams[random_index]

#region Mod export
func get_mod_export_subfolder() -> String:
	return "sound_effects"

### Each stream is a file, copied into the mod's sounds/ folder.
func get_array_file_reference_fields() -> Dictionary:
	return {"audio_streams": {"file_key": "file", "subfolder": "sounds"}}

### Hand-written: the streams are files, written as [{"file": path}, ...] (see get_array_file_reference_fields()).
func to_json_dict() -> Dictionary:
	var stream_entries: Array = []
	for stream in audio_streams:
		if stream:
			stream_entries.append({"file": ModExportable.resolve_to_res_path(stream.resource_path, resource_path)})
	return {
		"_class": get_script().get_global_name(),
		"sound_effect_id": sound_effect_id,
		"audio_streams": stream_entries,
	}

### mod_root_path: the mod's own folder (user://mods/<mod>); the streams are read from its sounds/ folder (.ogg/.mp3/.wav).
static func from_json_dict(data: Dictionary, mod_root_path: String = "") -> AudioStreamsForSoundEffect:
	var sound_effect: AudioStreamsForSoundEffect = AudioStreamsForSoundEffect.new()
	sound_effect.sound_effect_id = str(data.get("sound_effect_id", ""))
	for entry in data.get("audio_streams", []):
		var file_name: String = str(entry.get("file", "")) if entry is Dictionary else ""
		if file_name == "" or mod_root_path == "":
			continue
		var stream: AudioStream = Utils.load_audio_stream_from_path(mod_root_path.path_join("sounds").path_join(file_name))
		if stream:
			sound_effect.audio_streams.append(stream)
	return sound_effect
#endregion
