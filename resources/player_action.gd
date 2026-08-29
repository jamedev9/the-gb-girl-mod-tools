extends Resource
class_name PlayerAction

@export var action_id: String
@export var action_name: String
@export var picture: Texture2D

@export var move_energy: int
@export var energy_per_round: int

@export var base_damage: int

@export var statuses_to_apply: Array[ApplyStatusEffect] = []

@export var event_cards_awarded_when_target_is_defeated: Array[EventCardDefinition]

@export var video_action_tags: Array[VideoClip.ActionTags] = []
@export var log_text_when_started: String = ""
@export var log_text_when_ended: String = ""

@export var looping_sound_category: SoundManager.LoopingCategory = SoundManager.LoopingCategory.NONE
@export var start_sound_effect: SoundManager.SoundEffects = SoundManager.SoundEffects.NONE

var active_on_opponent_with_id: String = "none"

func get_action_name() -> String:
	return tr("PLAYERACTION_"+action_id.to_upper()+"_ACTION_NAME")

func get_translation_entries() -> Array[Dictionary]:
	return [
		{"key": "PLAYERACTION_"+action_id.to_upper()+"_ACTION_NAME", "text": action_name},
	]
