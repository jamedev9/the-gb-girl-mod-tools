extends Resource
class_name AudioStreamsForSoundEffect

@export var audio_streams: Array[AudioStream] = []

func get_random_stream() -> AudioStream:
	#if audio_streams.is_empty():
		#return null
	var random_index: int = randi_range(0,audio_streams.size()-1)
	return audio_streams[random_index]
