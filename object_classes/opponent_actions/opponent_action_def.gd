extends Resource
class_name OpponentActionDefinition

@export var opponent_action_id: String
@export var move_name: String
@export var description: String
@export var picture: Texture2D
@export var video_tags: Array[VideoClip.ActionTags] = []
@export var log_description: String = ""

@export var only_require_one_condition: bool = false
@export var trigger_conditions: Array[TriggerCondition] = []

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

func should_action_fire(
	input_context: EffectContext,
	game_state: GameState,
	save_game_state: SaveGameState,
	owner_of_trigger: TargetEntity) -> bool:
		var conditions_met: int = 0
		#print("Runnin should_component_trigger for %s"%trigger_component_id)
		if trigger_conditions.is_empty():
			#print("No trigger conditions - returning false")
			return true
		for condition in trigger_conditions:
			if condition.is_condition_met(input_context,game_state,save_game_state,owner_of_trigger):
				#print("Found contition that is not met, returning false.")
				conditions_met += 1
		
		if only_require_one_condition and conditions_met >= 1:
			#print("trigger %s only needs one condition, this is met, returning true"%trigger_component_id)
			return true
		if not only_require_one_condition and conditions_met == trigger_conditions.size():
			#print("trigger %s has all its conditions met, returning true"%trigger_component_id)
			return true
		#print("Trigger is not met, returning false")
		return false
