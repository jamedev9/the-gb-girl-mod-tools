extends GameManager
class_name SoundManager

const GAME_TITLE: String = "The Gangbang Girl"
const DEVELOPER: String = "gb_girl_dev"
const COPYRIGHT: String = "2026"

@export var max_volume: float = 0.0
@export var sound_effect_dict: Dictionary[SoundEffects,AudioStreamsForSoundEffect]
@export var menu_music_track: AudioStream

enum AudioBuses {MASTER, MUSIC, SOUND_EFFECTS, LOOPING_TRACKS}

enum SoundEffects {
	BUTTON_PRESS,
	CARD_DRAW,
	CARD_DISCARD,
	CARD_SHUFFLE,
	### Player action starts:
	VAGINAL_START,
	ANAL_START,
	BLOWJOB_START,
	HANDJOB_START,
	### Encounter occurences:
	PLAYER_TAKES_DAMAGE,
	OPPONENT_TAKES_DAMAGE,
	PLAYER_ORGASMS,
	OPPONENT_ORGASMS,
	CUM_INSIDE,
	CUM_OUTSIDE,
	EVENT_CARD_STARTS_RESOLVING,
	EVENT_CARD_START_DRAGGING,
	EVENT_CARD_END_DRAGGING,
	OPPONENT_CARD_MOVING,
	ACTION_CARD_START_DRAGGING,
	ACTION_CARD_END_DRAGGING,
	ENCOUNTER_START,
	PLAYER_WON_ENCOUNTER,
	PLAYER_LOST_ENCOUNTER,
	PLAYER_TURN_START,
	OPPONENT_TURN_START,
	### Append-only past this point: this enum is serialized by ordinal in .tres files,
	### so existing values must never be reordered or removed.
	NONE,
}

enum Thresholds {
	LOW,
	MEDIUM,
	HIGH
}

@export var threshold_values: Dictionary[Thresholds,float] = {
	Thresholds.LOW:0,
	Thresholds.MEDIUM:33,
	Thresholds.HIGH:66
}
const FADE_DURATION: float = 1.5
const MUSIC_VOLUME_DB_DELTA: float = -5
const MENU_MUSIC_VOLUME_DB_DELTA: float = -5
var last_noted_threshold: Thresholds = Thresholds.LOW
var is_player_sucking_cock: bool = false
var is_player_getting_fucked_in_pussy: bool = false
var is_player_getting_fucked_in_ass: bool = false

### Append-only: serialized by ordinal in .tres files, existing values must never move.
enum LoopingCategory {BREATHING,BLOWJOB,VAGINAL,ANAL,HANDJOB_RIGHT,HANDJOB_LEFT,NONE}
@export var audio_tracks: Dictionary[LoopingCategory,CategoryTracks]
@export var looping_tracks_volume_adjustment: Dictionary[LoopingCategory,float]

var stream_list: Dictionary[String, AudioStreamPlayer] = {}
var fading_out: Array[AudioStreamPlayer] = []

#region Sound settings:
func update_volume_for_audio_server(bus_index: int,new_volume_percentage: float) -> void:
	var volume_in_db: float = linear_to_db(new_volume_percentage/100)
	AudioServer.set_bus_volume_db(bus_index,volume_in_db)

#region Music:
func play_encounter_music(encounter_def: EncounterDefinition) -> void:
	play_audio(encounter_def.encounter_music,
	"encounter_music",AudioBuses.MUSIC,
	FADE_DURATION,
	MUSIC_VOLUME_DB_DELTA)

func end_encounter_music() -> void:
	end_audio("encounter_music")

func play_menu_music() -> void:
	play_audio(menu_music_track,
	"menu_music",AudioBuses.MUSIC,
	FADE_DURATION,
	MUSIC_VOLUME_DB_DELTA+MENU_MUSIC_VOLUME_DB_DELTA)

func end_menu_music() -> void:
	end_audio("menu_music")

#region Soundtracks:
### Starting soundtracks:
func play_audio(
	audio: AudioStream, audio_id: String, bus_name: AudioBuses,
	fade_duration: float = FADE_DURATION,
	max_volume_delta: float = 0.0) -> void:
	if not audio:
		return
	if audio_id in stream_list:
		#push_error("Trying to play audio, but id %s is already registered as an audiostream."%audio_id)
		return
	var audio_player: AudioStreamPlayer = AudioStreamPlayer.new()
	audio_player.bus = get_bus_name(bus_name)
	audio_player.autoplay = true
	audio_player.volume_db = -80.0
	stream_list[audio_id] = audio_player
	audio_player.stream = audio
	if not audio:
		return
	self.add_child(audio_player)
	match audio.get_class():
		"AudioStreamMP3":
			audio_player.stream.loop = true
		"AudioStreamWAV":
			audio_player.stream.loop_mode = AudioStreamWAV.LoopMode.LOOP_FORWARD
	audio_player.play()
	_fade_in_audio(audio_player,fade_duration,max_volume_delta)


func get_bus_name(bus_enum: AudioBuses) -> String:
	return AudioServer.get_bus_name(bus_enum)

func _fade_in_audio(
	audio_player: AudioStreamPlayer,
	fade_duration: float = FADE_DURATION,
	max_volume_delta: float = 0.0) -> void:
	var fade_in_tween: Tween = audio_player.create_tween()
	fade_in_tween.tween_property(
		audio_player,"volume_db",max_volume+max_volume_delta,fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	

func end_audio(audio_id: String,fade_duration: float = FADE_DURATION) -> void:
	if audio_id not in stream_list:
		return
	var audio_player: AudioStreamPlayer = stream_list[audio_id]
	stream_list.erase(audio_id)
	fading_out.append(audio_player)
	var fade_out_tween: Tween = audio_player.create_tween()
	fade_out_tween.tween_property(
		audio_player,"volume_db",-80.0,fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade_out_tween.finished
	fading_out.erase(audio_player)
	if is_instance_valid(audio_player):
		audio_player.queue_free()


#region Sound Effects:
func play_sound_effect(
	effect: SoundEffects,
	volume_delta: float = 0.0,
	audio_bus: String = "Sound Effects") -> void:
	if not effect:
		return
	var audio: AudioStream = get_audio_stream_for_effect(effect)
	play_sound_effect_audio(audio,volume_delta,audio_bus)
	
func play_sound_effect_audio(
	audio: AudioStream,
	volume_delta: float = 0.0,
	audio_bus: String = "Sound Effects") -> void:
	var audio_player: AudioStreamPlayer = AudioStreamPlayer.new()
	self.add_child(audio_player)
	audio_player.volume_db = max_volume + volume_delta
	audio_player.stream = audio
	audio_player.bus = audio_bus
	audio_player.play()
	await audio_player.finished
	audio_player.queue_free()

func get_audio_stream_for_effect(effect: SoundEffects) -> AudioStream:
	return sound_effect_dict[effect].get_random_stream()

func _ready() -> void:
	main_game.meta_game.state_manager.connect("state_changed",Callable(main_game.energy_system,"_on_new_state"))

#region Actions:
### Methods called by animations when actions are assigned and retracted:
func start_soundtrack_for_player_action(action_id: String) -> void:
	var category: LoopingCategory = get_category_for_player_action(action_id)
	_handle_state_change_for_action_start(action_id)
	if category == LoopingCategory.NONE:
		return
	_fade_in_track(category,last_noted_threshold)
	#_start_state_dependent_audio_tracks()

func end_soundtrack_for_player_action(action_id: String) -> void:
	#print("Running end_soundtrack_for_player_action for %s"%action_id)
	var category: LoopingCategory = get_category_for_player_action(action_id)
	_handle_state_change_for_action_end(action_id)
	if category == LoopingCategory.NONE:
		return
	_fade_out_old_tracks(category)
	#_end_state_dependent_audio_tracks()

func update_current_threshold(current_player_pleasure: int) -> void:
	var normalized_pleasure: float = get_normalized_current_pleasure(current_player_pleasure)
	var new_threshold: Thresholds = get_threshold_level_for_value(normalized_pleasure)
	if new_threshold == last_noted_threshold:
		return
	#print("updating looping tracks as threshold has changed")
	update_threshold_levels_for_looping_tracks(new_threshold)
	last_noted_threshold = new_threshold

func update_threshold_levels_for_looping_tracks(new_threshold: Thresholds) -> void:
	for category in LoopingCategory.values():
		if category_is_not_currently_playing(category):
			return
		_fade_out_old_tracks(category)
		_fade_in_track(category,new_threshold)

func category_is_not_currently_playing(category: LoopingCategory) -> bool:
	var category_string: String = LoopingCategory.keys()[category]
	for track_id in stream_list.keys():
		if category_string in track_id:
			return false
	return true

func get_category_for_player_action(action_id:String) -> LoopingCategory:
	if action_id not in AutoloadDatabase.player_actions_by_id.keys():
		return LoopingCategory.NONE
	return AutoloadDatabase.player_actions_by_id[action_id].looping_sound_category

func _handle_state_change_for_action_start(action_id: String) -> void:
	if action_id == "bj":
		is_player_sucking_cock = true
	if action_id == "anal":
		is_player_getting_fucked_in_ass = true
	if action_id == "vaginal":
		is_player_getting_fucked_in_pussy = true

func _handle_state_change_for_action_end(action_id: String) -> void:
	if action_id == "bj":
		is_player_sucking_cock = false
	if action_id == "anal":
		is_player_getting_fucked_in_ass = false
	if action_id == "vaginal":
		is_player_getting_fucked_in_pussy = false

func _start_state_dependent_audio_tracks() -> void:
	if not category_should_be_silent(LoopingCategory.BREATHING):
		_fade_in_track(LoopingCategory.BREATHING,last_noted_threshold)

func _end_state_dependent_audio_tracks() -> void:
	if category_should_be_silent(LoopingCategory.BREATHING):
		_fade_out_track(LoopingCategory.BREATHING,last_noted_threshold)
	pass

#region Old system:
### Followup methods:
func play_sound_for_action_start(action_id: String) -> void:
	#print("Running play_sound_for_action_start")
	if action_id not in AutoloadDatabase.player_actions_by_id.keys():
		return
	var sound_effect: SoundEffects = AutoloadDatabase.player_actions_by_id[action_id].start_sound_effect
	if sound_effect == SoundEffects.NONE:
		return
	play_sound_effect(sound_effect)

# Looping soundtracks:
func end_looping_tracks() -> void:
	var tracks_to_end: Array[String]
	for audio_id in stream_list.keys():
		var audio_player: AudioStreamPlayer = stream_list[audio_id]
		if audio_player.bus != "Master":
			tracks_to_end.append(audio_id)
	
	for audio_id in tracks_to_end:
		end_audio(audio_id)


func get_normalized_current_pleasure(current_player_pleasure: int) -> float:
	var player_stats: Dictionary = main_game.game_state.get_player_stats()
	var max_pleasure: int = player_stats["damage_threshold"]
	var normalized_pleasure: float = float(current_player_pleasure*100/max_pleasure)
	return normalized_pleasure

func get_value_for_threshold(key: Thresholds) -> float:
	return threshold_values[key]

func get_threshold_level_for_value(value: float) -> Thresholds:
	var return_value: Thresholds = Thresholds.LOW
	for key in threshold_values.keys():
		var threshold_value = get_value_for_threshold(key)
		if value > threshold_value:
			return_value = key
			continue
		if value < threshold_value:
			return return_value
	return return_value

func threshold_changed(threshold: Thresholds) -> bool:
	return threshold != last_noted_threshold

func get_id_string_for_track(category: LoopingCategory,threshold: Thresholds) -> String:
	return LoopingCategory.keys()[category]+"_"+Thresholds.keys()[threshold]

func _fade_out_old_tracks(category: LoopingCategory) -> void:
	var category_string: String = LoopingCategory.keys()[category]
	for audio_id in stream_list.keys():
		if category_string in audio_id:
			end_audio(audio_id)


func _fade_in_track(category: LoopingCategory,threshold: Thresholds) -> void:
	var track_id: String = get_id_string_for_track(category,threshold)
	var audio_track: AudioStream = get_audio_track(category,threshold)
	var volume_db_adjustment: float = get_volume_adjustment_for_category(category)
	play_audio(audio_track,track_id,AudioBuses.LOOPING_TRACKS,FADE_DURATION,volume_db_adjustment)
	
func get_volume_adjustment_for_category(category: LoopingCategory) -> float:
	if category not in looping_tracks_volume_adjustment.keys():
		return 0.0
	return looping_tracks_volume_adjustment[category]


func get_audio_track(category:LoopingCategory,threshold: Thresholds) -> AudioStream:
	if category_should_be_silent(category):
		return null
	if category not in audio_tracks.keys():
		return null
	var category_tracks: CategoryTracks = audio_tracks[category]
	return category_tracks.get_track_for_threshold(threshold)

func category_should_be_silent(category: LoopingCategory) -> bool:
	match category:
		LoopingCategory.BREATHING:
			if is_player_sucking_cock:
				return true
			if not is_player_getting_fucked_in_ass and not is_player_getting_fucked_in_pussy:
				return true
			return false
		LoopingCategory.VAGINAL:
			if not is_player_getting_fucked_in_pussy:
				return true
		LoopingCategory.ANAL:
			if not is_player_getting_fucked_in_ass:
				return true
	return false

func _fade_out_track(category: LoopingCategory,threshold: Thresholds) -> void:
	var track_id: String = get_id_string_for_track(category,threshold)
	end_audio(track_id,FADE_DURATION)

#endregion
#region Opponent orgasms
func play_opponent_orgasm_effect(cum_sound_effect: SoundEffects) -> void:
	play_sound_effect(SoundEffects.OPPONENT_ORGASMS,0.0,"Male Orgasms")
	play_sound_effect(cum_sound_effect,0.0,"Male Orgasms")


#endregion 
#region Event cards

func play_sounds_effects_for_event_card_resolution(event_card_def: EventCardDefinition) -> void:
	var sounds_effects_to_play: Array[AudioStream] = event_card_def.get_sound_effects_to_play_on_resoluion()
	for audio in sounds_effects_to_play:
		play_sound_effect_audio(audio)

#region State transitions:

func mute_cardgame_sounds() -> void:
	var sex_sounds_index: int = AudioServer.get_bus_index("Sound Effects")
	update_volume_for_audio_server(sex_sounds_index,0)


func unmute_cardgame_sounds() -> void:
	var sex_sounds_index: int = AudioServer.get_bus_index("Sound Effects")
	#var volume: float = main_game.meta_game.save_game_state.get_value_for_setting("Sound Effects")
	var volume: float = main_game.settings_manager.get_value_for_setting("Sound Effects")
	update_volume_for_audio_server(sex_sounds_index,volume)
