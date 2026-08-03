extends Resource
class_name OpponentActionDefinition

@export var opponent_action_id: String
@export var move_name: String
@export var description: String
@export var picture: Texture2D
@export var video_tags: Array[VideoClip.ActionTags] = []
@export var log_description: String = ""

@export var effect_intents: Array[EffectAndTargetIntent]

func get_video_tags():
	return video_tags

func get_player_actions_grabbed() -> Array[String]:
	var player_action_ids: Array[String] = []
	for intent in effect_intents:
		if intent.effect_intent is Intent_CapturePlayerAction:
			var action_id: String = intent.effect_intent.player_action_id
			player_action_ids.append(action_id)
		
	return player_action_ids
