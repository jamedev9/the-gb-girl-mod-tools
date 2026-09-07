@tool
extends ModExportable
class_name VideoClip

enum ActionTags {
	BLOWJOB,
	DEEPTHROAT,
	HANDJOB,
	VAGINAL,
	ANAL,
	STANDING,
	VAGINAL_SPITROAST,
	BLOWBANG,
	CUM_IN_MOUTH,
	SWALLOW_CUM,
	CUMSHOT,
	DOUBLE_PENETRATION,
	AIRTIGHT,
	FIVE_ON_ONE,
	BALL_LICKING,
	BUKKAKE,
	FEMALE_ORGASM,
	CALL_BOYFRIEND,
	VAGINAL_CREAMPIE,
	ANAL_CREAMPIE,
	SQUIRTING,
	CUNNILINGUS,
	PRONE_BONE,
	ANAL_SPITROAST,
	DOUBLE_FEMALE_BLOWJOB,
	FEMALE_CUNNILINGUS,
	DOUBLE_ANAL,
	DOUBLE_VAGINAL,
	BOUND_SPITROAST,	
	FEMALE_KISSING,
	KISSING_PENIS,
	TITJOB,
	RIMJOB,
	FEMALE_TWO_GIRLS_VAGINAL,
	FEMALE_TWO_GIRLS_SPITROAST,
	GARGLE_CUM,
	FOOTJOB
	
	
}

enum ParticipantTags {
	BBC,
	BLONDE,
	REDHEAD,
	BRUNETTE,
	BLACK_HAIR,
	CUM_COVERED,
	GLASSES,
	CUCK_BOYFRIEND,
	WHITE_MAN,
	JAPANESE_MAN,
	ASIAN_WOMAN
}

enum ParticipantCategory {
	WOMAN_APPEARANCE,
	MAN_APPEARANCE,
	MISC
}

const PARTICIPANT_TAG_CATEGORIES: Dictionary = {
	ParticipantTags.BLONDE: ParticipantCategory.WOMAN_APPEARANCE,
	ParticipantTags.REDHEAD: ParticipantCategory.WOMAN_APPEARANCE,
	ParticipantTags.BRUNETTE: ParticipantCategory.WOMAN_APPEARANCE,
	ParticipantTags.BLACK_HAIR: ParticipantCategory.WOMAN_APPEARANCE,
	ParticipantTags.ASIAN_WOMAN: ParticipantCategory.WOMAN_APPEARANCE,
	
	ParticipantTags.BBC: ParticipantCategory.MAN_APPEARANCE,
	ParticipantTags.WHITE_MAN: ParticipantCategory.MAN_APPEARANCE,
	ParticipantTags.JAPANESE_MAN: ParticipantCategory.MAN_APPEARANCE,
	
	ParticipantTags.GLASSES: ParticipantCategory.MISC,
	ParticipantTags.CUM_COVERED: ParticipantCategory.MISC,
	ParticipantTags.CUCK_BOYFRIEND: ParticipantCategory.MISC,
}

static func get_category_for_tag(tag: VideoClip.ParticipantTags) -> ParticipantCategory:
	if PARTICIPANT_TAG_CATEGORIES.has(tag):
		return PARTICIPANT_TAG_CATEGORIES[tag]
	push_warning("Participant tag %s has no category assigned, defaulting to MISC." % tag)
	return ParticipantCategory.MISC

const MODDABLE_PARTICIPANT_TAGS: Array[String] = [ ### These the only ones that can be assigned to characters
	"BLONDE",
	"REDHEAD",
	"BRUNETTE",
	"BLACK_HAIR",
	"ASIAN_WOMAN"
]

### Formats GDE GoZen (the video player as of the video_playback_optimization branch) can
### actually load - checked what's compiled into the library directly, not guessed. Keep
### this filter string in sync with GlobalVideoPlayerSystem.SUPPORTED_MOD_VIDEO_EXTENSIONS
### (video_player_system.gd) - @export_file's filter has to be a compile-time constant
### string, so it can't be derived from that array automatically.
@export_file("*.ogv", "*.mp4", "*.m4v", "*.mov", "*.mkv", "*.webm", "*.avi") var video_file: String = "" ## Path to the video file. Played via the GDE GoZen video addon's playback node (see opponent_card.gd), which takes a raw path rather than a VideoStream resource.
@export var action_tags: Array[ActionTags]
@export var participant_tags: Array[ParticipantTags]
@export var weight: float = 1

func get_mod_export_subfolder() -> String:
	return "videos"

func get_file_reference_fields() -> Dictionary:
	return {"video_file": "videos"}

func to_json_dict() -> Dictionary:
	return {
		"video_file": video_file,
		"action_tags": VideoClip._convert_action_tags_to_string(action_tags),
		"participant_tags": VideoClip._convert_participant_tags_to_string(participant_tags, resource_path),
		"weight": weight,
	}

static func from_json_dict(data: Dictionary, mod_folder_path: String = "") -> VideoClip:
	var clip := VideoClip.new()
	var video_file_name: String = data.get("video_file", "")
	if video_file_name != "" and mod_folder_path != "":
		clip.video_file = mod_folder_path.path_join(video_file_name)
	clip.action_tags = VideoClip._parse_action_tags(data.get("action_tags", []), clip.resource_path)
	clip.participant_tags = VideoClip._parse_moddable_participant_tags(data.get("participant_tags", []), "video_clip")
	clip.weight = float(data.get("weight", 1.0))
	return clip

static func _convert_action_tags_to_string(tag_values: Array[VideoClip.ActionTags]) -> Array[String]:
	var canonical_keys: Array = VideoClip.ActionTags.keys()
	var parsed_tag_names: Array[String] = []
	for enum_value in tag_values:
		parsed_tag_names.append(canonical_keys[enum_value])
	return parsed_tag_names

static func _parse_action_tags(tag_names: Array, clip_file_name: String) -> Array[VideoClip.ActionTags]:
	### Call to turn a string array into tags
	var parsed: Array[VideoClip.ActionTags] = []
	for tag_name in tag_names:
		if tag_name is not String:
			push_warning("Non-string action tag found in clip '%s', skipping tag." % clip_file_name)
			continue
		var matched_key: String = find_case_insensitive_enum_key(VideoClip.ActionTags.keys(), tag_name)
		if matched_key != "":
			parsed.append(VideoClip.ActionTags[matched_key])
		else:
			push_warning("Unknown action tag '%s' in clip '%s', skipping tag." % [tag_name, clip_file_name])
	return parsed

static func _parse_participant_tags(tag_names: Array, clip_file_name: String) -> Array[VideoClip.ParticipantTags]:
	### Call to turn a string array into tags
	var parsed: Array[VideoClip.ParticipantTags] = []
	for tag_name in tag_names:
		if tag_name is not String:
			push_warning("Non-string participant tag found in clip '%s', skipping tag." % clip_file_name)
			continue
		var matched_key: String = find_case_insensitive_enum_key(VideoClip.ParticipantTags.keys(), tag_name)
		if matched_key != "":
			parsed.append(VideoClip.ParticipantTags[matched_key])
		else:
			push_warning("Unknown participant tag '%s' in clip '%s', skipping tag." % [tag_name, clip_file_name])
	return parsed
	

static func _convert_participant_tags_to_string(tag_values: Array[VideoClip.ParticipantTags], _character_id: String) -> Array[String]:
	### Call this to convert already-parsed enum tag values into strings for saving as json
	var canonical_keys: Array = VideoClip.ParticipantTags.keys()
	var parsed_tag_names: Array[String] = []
	for enum_value in tag_values:
		parsed_tag_names.append(canonical_keys[enum_value])
	return parsed_tag_names

static func _get_video_participant_tags_for_entity(entity: TargetEntity,save_game_state: SaveGameState) -> Array[VideoClip.ParticipantTags]:
	var tags: Array[VideoClip.ParticipantTags] = []
	if not entity:
		return tags
	if entity is OpponentEntity:
		var opponent_data = entity.get_data()
		if opponent_data and opponent_data.opponent_type:
			tags.append_array(opponent_data.opponent_type.video_particpant_tags)
	if entity is PlayerEntity:
		tags.append_array(save_game_state.get_player_video_participant_tags())
		
	return tags

static func _get_participant_tags_from_context(context: EffectContext,save_game_state: SaveGameState) -> Array[VideoClip.ParticipantTags]:
	var tags: Array[VideoClip.ParticipantTags] = []
	if not context:
		return tags
	tags.append_array(VideoClip._get_video_participant_tags_for_entity(context.source,save_game_state))
	tags.append_array(VideoClip._get_video_participant_tags_for_entity(context.target,save_game_state))
	return tags

static func _parse_moddable_participant_tags(tag_names: Array, character_id: String) -> Array[VideoClip.ParticipantTags]:
	var parsed: Array[VideoClip.ParticipantTags] = []
	for tag_name in tag_names:
		if tag_name is not String:
			push_warning("Non-string participant tag found for '%s', skipping tag." % character_id)
			continue
		var matched_key: String = find_case_insensitive_enum_key(VideoClip.ParticipantTags.keys(), tag_name)
		if matched_key == "":
			push_warning("Unknown participant tag '%s' for '%s', skipping tag." % [tag_name, character_id])
			continue
		if matched_key not in MODDABLE_PARTICIPANT_TAGS:
			push_warning("Participant tag '%s' for '%s' is not moddable, skipping tag." % [tag_name, character_id])
			continue
		parsed.append(VideoClip.ParticipantTags[matched_key])
	return parsed
