extends Resource
class_name LogFragment

enum LogTags {
	ACTION_MOVED_TO_OPPONENT,
	ACTION_RETRACTED,
	OPPONENT_DEFEATED,
	OPPONENT_ORGASMED,
	ROUND_PROGRESSION,
	PLAYER_WON,
	PLAYER_LOST,
	PLAYER_TOOK_DAMAGE,
	PLAYER_HP_REDUCED,
	OPPONENT_TOOK_DAMAGE,
	PLAYER_DREW_EVENT_CARD,
	EVENT_CARD_PLAYED,
	EVENT_CARD_ADDED_TO_HAND,
	EVENT_CARD_ADDED_TO_DECK,
	EVENT_CARD_RESOLVED,
	EVENT_CARD_DISCARDED,
	EVENT_CARD_DECK_SHUFFLED,
	BUG_REPORT,
	ILLEGAL_PLAYER_ACTION,
	DAMAGE_SYSTEM_MODIFIED_DAMAGE,
	STATUS_APPLIED_TO_TARGET,
	DAMAGE_DEALT,
	PLAYER_ENERGY_CHANGED,
	END_PLAYER_TURN
}

var timestamp: String

var message_key: String
var tags: Array
var values: Dictionary
var context: EffectContext
var show_to_player: bool = false
var video_action_tags: Array[VideoClip.ActionTags] = []
var video_participant_tags: Array[VideoClip.ParticipantTags] = []

static func make_new_log_fragment(
	_message_key: String, 
	_values: Dictionary = {},
	_tags: Array[LogFragment.LogTags] = [],
	_context: EffectContext = null,
	_show_to_player: bool = false,
	_video_action_tags:Array[VideoClip.ActionTags] = [],
	_video_participant_tags: Array[VideoClip.ParticipantTags] = []) -> LogFragment:
	var fragment: LogFragment = LogFragment.new()
	fragment.message_key = _message_key
	fragment.values = _values
	fragment.tags = _tags
	fragment.context = _context
	fragment.show_to_player = _show_to_player
	fragment.video_action_tags = _video_action_tags
	fragment.video_participant_tags = _video_participant_tags
	return fragment
