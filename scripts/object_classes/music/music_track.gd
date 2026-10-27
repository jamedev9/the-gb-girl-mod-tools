@tool
extends ModExportable
class_name MusicTrack

### One soundtrack of the game, registered by AutoloadDatabase (music_tracks_by_id) from any content pack, so content can
### name the music by id instead of by file: a mod encounter's EncounterDefinition.music_track_id picks one of these.
### The game's own tracks are in content_packs/00_real_porn_035_and_earlier/music_tracks/.

### Unique id other content names the track by. Never change it once a mod could be using it.
@export var track_id: String
@export var stream: AudioStream
### Optional, as credited by the track's source (the game's tracks: taken from their file names).
@export var track_name: String = ""
@export var artist: String = ""

### True for a track loaded from a mod. @export_storage so duplicate() keeps it; never written to JSON.
@export_storage var is_modded: bool = false

#region Mod export
func get_mod_export_subfolder() -> String:
	return "music_tracks"

func get_file_reference_fields() -> Dictionary:
	return {"stream": "music"}

### Hand-written: stream is a file (copied into the mod's music/ folder, see get_file_reference_fields()).
func to_json_dict() -> Dictionary:
	return {
		"_class": get_script().get_global_name(),
		"track_id": track_id,
		"track_name": track_name,
		"artist": artist,
		"stream": ModExportable.resolve_to_res_path(stream.resource_path, resource_path) if stream else "",
	}

### mod_root_path: the mod's own folder (user://mods/<mod>); the stream is read from its music/ folder (.ogg/.mp3/.wav).
static func from_json_dict(data: Dictionary, mod_root_path: String = "") -> MusicTrack:
	var track: MusicTrack = MusicTrack.new()
	track.track_id = str(data.get("track_id", ""))
	track.track_name = str(data.get("track_name", ""))
	track.artist = str(data.get("artist", ""))
	var stream_file_name: String = str(data.get("stream", ""))
	if stream_file_name != "" and mod_root_path != "":
		track.stream = Utils.load_audio_stream_from_path(mod_root_path.path_join("music").path_join(stream_file_name))
	return track
#endregion
