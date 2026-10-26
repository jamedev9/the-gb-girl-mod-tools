extends GameManager
class_name OpponentActionManager

const GAME_TITLE: String = "The Gangbang Girl"
const DEVELOPER: String = "gb_girl_dev"
const COPYRIGHT: String = "2026"

signal opponent_action_tries_to_apply_status(context: EffectContext)
signal opponent_action_wants_to_resolve_effect(context: EffectContext,effect: EffectAndTargetIntent)


#region Opponent actions:
func _select_next_action_for_active_opponents(game_state: GameState) -> void:
	for opponent_id in game_state.get_currently_active_opponents().keys():
		_select_next_action_for_opponent(game_state, opponent_id)


func _select_next_action_for_opponent(game_state: GameState, opponent_id: String) -> void:
	var opponent: OpponentInstance = game_state.get_opponent_instance(opponent_id)
	var next_action: OpponentActionDefinition = opponent.choose_action()
	
	var succesfully_changed_action = change_opponents_next_action(opponent_id,opponent,next_action)
	if not succesfully_changed_action:
		_select_next_action_for_opponent(game_state,opponent_id) 

func change_opponents_next_action(opponent_id: String,opponent: OpponentInstance,action:OpponentActionDefinition) -> bool:
	### This can be called elsewhere to change an opponents next action to any action.
	### Check if the opponent action tries to grab an invalid player action, and fail if so:
	var player_actions_grabbed_by_opponent: Array[String] = action.get_player_actions_grabbed()
	for player_action_id in player_actions_grabbed_by_opponent:
		if not main_game.game_state.is_action_available(player_action_id):
		#if player_action_id not in main_game.game_state.get_player_actions_in_encounter():
			return false
	
	### Checks passed
	opponent.upcoming_action = action
	main_game.log_manager._add_generic_log_fragment_to_log(
		"opponent_action_changed",
		{"opponent_id":opponent_id, "opponent_instance": opponent, "action": action}
	)
	return true

func _perform_upcoming_action_for_active_opponents_(game_state:GameState) -> void:
	for opponent_id in game_state.currently_active_opponents.keys():
		_perform_action_for_opponent(game_state,opponent_id)
		
func _perform_action_for_opponent(game_state: GameState,opponent_id: String) -> void:
	#await main_game._step_delay(game_state)
	var opponent_instance: OpponentInstance = game_state.get_opponent_instance(opponent_id)
	if not opponent_instance:
		return
	var source = OpponentEntity.new(game_state,opponent_id)
	var opponent_action: OpponentActionDefinition = opponent_instance.upcoming_action
	
	if not opponent_action.should_action_fire(
		null,game_state,main_game.meta_game.save_game_state,source):
			return
	
	var source_context: EffectContext = EffectContext.new()
	var log_tags: Array[LogFragment.LogTags] = []
	source_context.source = source
	main_game.log_manager._add_generic_log_fragment_to_log(
		"opponent_performed_action",
		{"opponent_instance":opponent_instance,"opponent_action":opponent_action},
		#[],source_context,opponent_action.log_description !="",opponent_action.get_video_tags(),opponent_instance.get_participant_tags(),
		log_tags,
		source_context,
		not opponent_action.get_video_tags().is_empty(),
		opponent_action.get_video_tags(),opponent_instance.get_participant_tags(),
		)
	for effect in opponent_action.effect_intents:
		emit_signal("opponent_action_wants_to_resolve_effect",source_context,effect)
	main_game._remove_defeated_opponents()

#func _opponent_applies_statuses(
	#game_state: GameState,opponent_id: String,
	#opponent_action: OpponentActionDefinition, targets: Array[TargetEntity]) -> void:
	#for target in targets:
		#_apply_statuses_to_target(target,game_state,opponent_id,opponent_action)
	
#func _apply_statuses_to_target(target: TargetEntity,game_state: GameState,opponent_id: String,
	#opponent_action: OpponentActionDefinition) -> void:
	#var statuses_to_apply: Array[ApplyStatusEffect] = opponent_action.statuses_to_apply
	#var source: TargetEntity = OpponentEntity.new(game_state,opponent_id)
	#var apply_statuses_intent: EffectContext = EffectContext.new_apply_statuses_intent(
		#game_state,opponent_action.opponent_action_id,opponent_action,source,target,statuses_to_apply)
	#emit_signal("opponent_action_tries_to_apply_status",apply_statuses_intent)
	##emit_signal("opponent_action_tries_to_apply_status",opponent_id,opponent_action,apply_statuses_intent)
	#
#endregion
