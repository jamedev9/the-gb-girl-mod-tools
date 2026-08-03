extends Resource
class_name OpponentInstance

var opponent_type: OpponentType
var opponent_id: String
var opponent_name: String

var current_damage: int = 0
var status_effects: Dictionary

var damage_tracking_index: int = 0
var damage_tracking_dict: Dictionary[int,Dictionary]

var upcoming_action: OpponentActionDefinition
var strategy_state: Dictionary = {}

func _init(_opponent_type: OpponentType) -> void:
	self.opponent_type = _opponent_type
	self.opponent_name = get_opponent_name_from_type(_opponent_type)

func choose_action(_context: EffectContext=null) -> OpponentActionDefinition:
	return opponent_type.action_strategy.choose_action(self, _context)

func get_opponent_name_from_type(_opponent_type: OpponentType) -> String:
	return _opponent_type.get_random_name()
	
func log_damage_taken(context: EffectContext,damage: int) -> void:
	damage_tracking_dict[damage_tracking_index] = {"context":context,"damage":damage}
	damage_tracking_index += 1

func get_context_of_last_damage_taken() -> EffectContext:
	var last_entry: Dictionary = damage_tracking_dict[damage_tracking_index-1]
	var context: EffectContext = last_entry["context"]
	return context

func get_participant_tags() -> Array[VideoClip.ParticipantTags]:
	return opponent_type.video_particpant_tags
