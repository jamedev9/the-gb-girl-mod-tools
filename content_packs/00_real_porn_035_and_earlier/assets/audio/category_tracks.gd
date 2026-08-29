extends Resource
class_name CategoryTracks

@export var tracks: Dictionary[SoundManager.Thresholds,AudioStream]

func get_track_for_threshold(threshold: SoundManager.Thresholds) -> AudioStream:
	return tracks[threshold]
