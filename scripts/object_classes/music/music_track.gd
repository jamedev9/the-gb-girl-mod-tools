extends Resource
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
