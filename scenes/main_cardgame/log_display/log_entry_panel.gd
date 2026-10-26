extends Cardgame_UI_Element
class_name LogEntryPanel

@export var log_entry_container: Container
@export var text_label: RichTextLabel
@export var log_video: PackedScene = preload("res://scripts/video_player_system/log_video.tscn")

const TIME_UNTIL_VIDEO_DELETION: float = 30.0

var is_summary_entry: bool = false

signal added_video_player(log_entry_panel: LogEntryPanel)

### The current/most recent fragment shown - kept so _refresh_text() can re-derive
### translated text (status/card names, etc.) when the locale changes.
var _current_fragment: LogFragment = null

#region Merging fragments:
var merge_count: int = 1
var _drawn_card_ids: Array[String] = []
var _applied_status_id: String = ""
var _applied_status_target_names: Array[String] = []
var _reapplied_status_id: String = ""
var _reapplied_status_target_names: Array[String] = []

const MERGEABLE_FRAGMENT_KEYS: Array[String] = [
	"player_drew_an_event_card_from_deck",
	"new_status_effect_was_applied_to_target",
	"status_effect_reapplied_to_target"
]

func merge_with_new_fragment(fragment: LogFragment) -> void:
	merge_count += 1
	match fragment.message_key:
		"player_drew_an_event_card_from_deck":
			_merge_player_drew_card(fragment)
		"new_status_effect_was_applied_to_target":
			_merge_status_applied(fragment)
		"status_effect_reapplied_to_target":
			_merge_statuses_reapplied(fragment)
	pass

func _merge_player_drew_card(fragment: LogFragment) -> void:
	var event_card_id: String = fragment.values["card_type_id"]
	_drawn_card_ids.append(event_card_id)
	text_label.text = _format_drew_cards_text()

func _format_drew_cards_text() -> String:
	var drawn_card_names: Array[String] = []
	for card_id in _drawn_card_ids:
		drawn_card_names.append(AutoloadDatabase.event_cards_by_id[card_id].get_card_name())
	if drawn_card_names.size() == 1:
		return tr("LOG_PLAYER_DREW_EVENT_CARD") % drawn_card_names[0]
	var all_but_last: Array[String] = drawn_card_names.slice(0, drawn_card_names.size() - 1)
	var last: String = drawn_card_names[-1]
	return tr("LOG_PLAYER_DREW_MULTIPLE_EVENT_CARDS") % [", ".join(all_but_last), last]

func _merge_status_applied(fragment: LogFragment) -> void:
	var target: TargetEntity = fragment.values["target_entity"]
	if target is not OpponentEntity:
		return
	var opponent_instance: OpponentInstance = fragment.values["opponent_instance"]
	_applied_status_target_names.append(opponent_instance.opponent_name)
	text_label.text = _format_status_applied_text()

func _format_status_applied_text() -> String:
	var status_name: String = AutoloadDatabase.status_effects_by_id[_applied_status_id].get_effect_name()
	if _applied_status_target_names.size() == 1:
		return tr("LOG_STATUS_APPLIED_TO_OPPONENT") % [status_name, _applied_status_target_names[0]]
	var all_but_last: Array[String] = _applied_status_target_names.slice(0, _applied_status_target_names.size() - 1)
	var last: String = _applied_status_target_names[-1]
	return tr("LOG_STATUS_APPLIED_TO_MULTIPLE_OPPONENTS") % [status_name, ", ".join(all_but_last), last]

func _merge_statuses_reapplied(fragment: LogFragment) -> void:
	var target: TargetEntity = fragment.values["target_entity"]
	if target is not OpponentEntity:
		return
	var opponent_instance: OpponentInstance = fragment.values["opponent_instance"]
	_reapplied_status_target_names.append(opponent_instance.opponent_name)
	text_label.text = _format_status_reapplied_text()
	
func _format_status_reapplied_text() -> String:
	var status_name: String = AutoloadDatabase.status_effects_by_id[_reapplied_status_id].get_effect_name()
	if _reapplied_status_target_names.size() == 1:
		return tr("LOG_STATUS_REAPPLIED_TO_OPPONENT") % [status_name, _reapplied_status_target_names[0]]
	var all_but_last: Array[String] = _reapplied_status_target_names.slice(0, _reapplied_status_target_names.size() - 1)
	var last: String = _reapplied_status_target_names[-1]
	return tr("LOG_STATUS_REAPPLIED_TO_MULTIPLE_OPPONENTS") % [status_name, ", ".join(all_but_last), last]

#endregion
func display_debug_log_fragment(fragment: LogFragment) -> void:
	text_label.text = fragment.message_key+JSON.stringify(fragment.values)
	pass

func display_player_readable_log_fragment(fragment: LogFragment) -> void:
	_current_fragment = fragment
	_set_text_for_fragment(fragment)

	if "ERROR" in fragment.message_key:
		fade_rich_text_red_to_white(text_label)

	var video_added: bool = _add_video_matching_tags(fragment)
	if not video_added and text_label.text == "":
		#print("Panel with key: %s  - found nothing to display, hiding."%fragment.message_key)
		self.hide()

### Only sets text_label.text - no side effects (video, fade, hide). Split out from
### display_player_readable_log_fragment() so _refresh_text() can recompute display text
### on a locale change without re-triggering the fade animation or adding another video.
func _set_text_for_fragment(fragment: LogFragment) -> void:
	#var game_state: GameState = main_game.get_current_game_state()
	match fragment.message_key:
		"player_passed_turn":
			text_label.text = tr("LOG_PLAYER_PASSED_TURN")
		"player_turn_start":
			text_label.text = tr("LOG_PLAYER_TURN_START")
		"player_moved_action_to_opponent":
			var action_id: String = fragment.values["action_id"]
			var action: PlayerAction = AutoloadDatabase.player_actions_by_id[action_id]
			var opponent_instance = fragment.values["opponent_instance"]
			var opponent_name: String = opponent_instance.opponent_name
			var display_text: String
			if action.log_text_when_started != "":
				display_text = action.get_log_text_when_started().replace("[target]", opponent_name)
			else:
				display_text = tr("LOG_PLAYER_MOVED_ACTION_TO_OPPONENT") % [action.get_action_name(), opponent_name]
			text_label.text = display_text
		"player_retracted_action_from_opponent":
			var action_id: String = fragment.values["action_id"]
			var action_name: String = AutoloadDatabase.player_actions_by_id[action_id].action_name
			var opponent_id: String = fragment.values["opponent_id"]
			var opponent_instance: OpponentInstance = main_game.game_state.get_opponent_instance(opponent_id)
			var opponent_name: String = opponent_instance.opponent_name
			text_label.text = tr("LOG_PLAYER_RETRACTED_ACTION") % [action_name, opponent_name]
		"opponent_defeated":
			#var opponent_id: String = fragment.values["opponent_id"]
			var opponent_instance: OpponentInstance = fragment.values["opponent_instance"]
			var opponent_name: String = opponent_instance.opponent_name
			text_label.text = tr("LOG_OPPONENT_DEFEATED") % opponent_name
		"opponent_orgasmed":
			var opponent_instance: OpponentInstance = fragment.values["opponent_instance"]
			var opponent_name: String = opponent_instance.opponent_name
			text_label.text = tr("LOG_OPPONENT_ORGASMED") % opponent_name
		"player_won":
			text_label.text = tr("LOG_PLAYER_WON")
		"player_lost":
			text_label.text = tr("LOG_PLAYER_LOST")
		"event_card_started_resolving":
			var event_card_id: String = fragment.values["card_type_id"]
			var event_card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[event_card_id]
			var event_card_name: String = event_card_def.get_card_name()
			text_label.text = tr("LOG_EVENT_CARD_STARTED_RESOLVING") % event_card_name
		"new_status_effect_was_applied_to_target":
			var target: TargetEntity = fragment.values["target_entity"]
			var status_id: String = fragment.values["status_id"]
			_applied_status_id = status_id
			var status_name: String = AutoloadDatabase.status_effects_by_id[status_id].get_effect_name()
			var opponent_name: String = ""
			if target is OpponentEntity:
				var opponent_instance: OpponentInstance = fragment.values["opponent_instance"]
				opponent_name = opponent_instance.opponent_name
				_applied_status_target_names = [opponent_name] # Seed with first name
			match target.get_script():
				OpponentEntity:
					text_label.text = tr("LOG_STATUS_APPLIED_TO_OPPONENT") % [status_name, opponent_name]
				PlayerEntity:
					text_label.text = tr("LOG_STATUS_APPLIED_TO_PLAYER") % status_name
		"status_effect_reapplied_to_target":
			var target: TargetEntity = fragment.values["target_entity"]
			var status_id: String = fragment.values["status_id"]
			_reapplied_status_id = status_id
			var status_name: String = AutoloadDatabase.status_effects_by_id[status_id].get_effect_name()
			var new_duration: int = fragment.values["new_duration"]
			var opponent_name: String = ""
			if target is OpponentEntity:
				var opponent_instance: OpponentInstance = fragment.values["opponent_instance"]
				opponent_name = opponent_instance.opponent_name
				_reapplied_status_target_names = [opponent_name]
			match target.get_script():
				OpponentEntity:
					text_label.text = tr("LOG_STATUS_REAPPLIED_TO_OPPONENT") % [status_name, opponent_name]
				PlayerEntity:
					if StatusEffectManager.is_duration_persistent(new_duration):
						text_label.text = tr("LOG_STATUS_REAPPLIED_TO_PLAYER_PERSISTENT") % status_name
					else:
						text_label.text = tr("LOG_STATUS_REAPPLIED_TO_PLAYER") % [status_name, new_duration]
		"player_took_damage_from_opponents_action":
			var opponent_id: String = fragment.values["opponent_id"]
			var opponent_action: OpponentActionDefinition = fragment.values["opponent_action"]
			var opponent_action_name: String = opponent_action.move_name
			var opponent_instance: OpponentInstance = main_game.game_state.get_opponent_instance(opponent_id)
			var opponent_name: String = opponent_instance.opponent_name
			text_label.text = tr("LOG_PLAYER_TOOK_DAMAGE_FROM_OPPONENT_ACTION") % [opponent_name, opponent_action_name, fragment.values["damage"]]
		"player_HP_reduced":
			text_label.text = tr("LOG_PLAYER_HP_REDUCED") % fragment.values["hp_reduction"]
		"opponent_took_damage_from_source": ### Handles damage from statuses.
			var damage: int = fragment.values["damage"]
			var target: OpponentEntity = fragment.values["target"]
			var context: EffectContext = fragment.context
			if not target is OpponentEntity:
				return
			if context.status_sending_context:
				var status_name: String = context.status_sending_context.status_name
				text_label.text = tr("LOG_OPPONENT_TOOK_DAMAGE_FROM_STATUS") % [status_name, damage, target.opponent_id]
				return
			text_label.text = tr("LOG_OPPONENT_TOOK_DAMAGE_GENERIC") % [target.opponent_id, damage]
		"opponent_took_damage_from_player_action":
			var opponent_id: String = fragment.values["opponent_id"]
			var damage: int = fragment.values["damage"]
			var action_id: String = fragment.values["action_id"]
			var action_name: String = AutoloadDatabase.player_actions_by_id[action_id].action_name
			var opponent_instance: OpponentInstance = main_game.game_state.get_opponent_instance(opponent_id)
			var opponent_name: String = opponent_instance.opponent_name
			text_label.text = tr("LOG_OPPONENT_TOOK_DAMAGE_FROM_PLAYER_ACTION") % [action_name, damage, opponent_name]
		"player_HP_changed":
			text_label.text = tr("LOG_PLAYER_HP_CHANGED")
		"opponent_performed_action":			
			var opponent_action: OpponentActionDefinition = fragment.values["opponent_action"]
			var opponent_instance: OpponentInstance = fragment.values["opponent_instance"]
			var opponent_name: String = opponent_instance.opponent_name
			var formatted_string: String = format_string_for_display(opponent_action.log_description,opponent_name)
			text_label.text = format_string_for_display(formatted_string,opponent_name)

		
#region Event cards:
		"player_drew_an_event_card_from_deck":
			var event_card_id: String = fragment.values["card_type_id"]
			var event_card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[event_card_id]
			text_label.text = tr("LOG_PLAYER_DREW_EVENT_CARD") % event_card_def.get_card_name()
		"event_card_added_to_players_hand":
			var event_card_id: String = fragment.values["card_type_id"]
			var event_card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[event_card_id]
			text_label.text = tr("LOG_EVENT_CARD_ADDED_TO_HAND") % event_card_def.get_card_name()
		"player_discarded_event_card":
			var event_card_id: String = fragment.values["card_type_id"]
			var event_card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[event_card_id]
			text_label.text = tr("LOG_PLAYER_DISCARDED_EVENT_CARD") % event_card_def.get_card_name()
		
		

#region ERRORS:
		"PLAYER_ERROR_tried_playing_single_target_event_card_without_target":
			var event_card_id: String = fragment.values["card_type_id"]
			var event_card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[event_card_id]
			var event_card_name: String = event_card_def.get_card_name()
			text_label.text = tr("LOG_ERROR_EVENT_CARD_NEEDS_TARGET") % event_card_name
		"PLAYER_ERROR_tried_playing_action_card_without_enough_energy":
			var event_card_id: String = fragment.values["card_type_id"]
			var event_card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[event_card_id]
			var event_card_name: String = event_card_def.get_card_name()
			text_label.text = tr("LOG_ERROR_NOT_ENOUGH_ENERGY") % event_card_name
		"PLAYER_ERROR_player_played_action_card_without_valid_targets":
			var event_card_id: String = fragment.values["card_type_id"]
			var event_card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[event_card_id]
			var event_card_name: String = event_card_def.get_card_name()
			text_label.text = tr("LOG_ERROR_NO_VALID_TARGETS") % event_card_name
		"PLAYER_ERROR_player_played_action_card_with_non_targeting_on_single_opponent":
			var event_card_id: String = fragment.values["card_type_id"]
			var event_card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[event_card_id]
			var event_card_name: String = event_card_def.get_card_name()
			text_label.text = tr("LOG_ERROR_CANNOT_TARGET_OPPONENT") % event_card_name
		"PLAYER_ACTION_REQUIRED_BY_OPPONENT_ACTION_IS_MISSING": ### TODO: Pass which actions are missing.
			var missing_player_actions: Array[String] = fragment.context.failed_to_resolve_info["missing_player_actions"]
			var names_of_missing_actions: Array[String]
			for action_id in missing_player_actions:
				var action_def: PlayerAction = AutoloadDatabase.get_player_action_by_id(action_id)
				names_of_missing_actions.append(action_def.action_name)
			var string_of_missing_actions: String = Utils.format_string_list(names_of_missing_actions)
			var event_card_instance: EventCardInstance = fragment.values["event_card_instance"]
			var event_card_id: String = event_card_instance.card_id
			var event_card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[event_card_id]
			var event_card_name: String = event_card_def.get_card_name()
			text_label.text = tr("LOG_ERROR_MISSING_REQUIRED_ACTIONS") % [event_card_name, string_of_missing_actions]

func _refresh_text() -> void:
	if not _current_fragment:
		return
	if merge_count > 1:
		match _current_fragment.message_key:
			"player_drew_an_event_card_from_deck":
				text_label.text = _format_drew_cards_text()
			"new_status_effect_was_applied_to_target":
				text_label.text = _format_status_applied_text()
			"status_effect_reapplied_to_target":
				text_label.text = _format_status_reapplied_text()
	else:
		_set_text_for_fragment(_current_fragment)

func fade_rich_text_red_to_white(label: RichTextLabel) -> void:
	var fade_tween: Tween = null
	if label == null:
		return
	label.modulate = Color(0.83, 0.14, 0.13, 1.0)
	fade_tween = create_tween()
	fade_tween.tween_interval(0.5)
	fade_tween.tween_property(
		label,"modulate",Color.WHITE,2.0
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

func _add_video_matching_tags(fragment: LogFragment) -> bool:
	if not main_game.settings_manager.get_videos_in_logs_setting():
		return false
	if fragment.video_action_tags.is_empty():
		return false
	var video_clip: VideoClip = VideoPlayerSystem.get_video_by_tags(fragment.video_action_tags, fragment.video_participant_tags)
	if not video_clip:
		push_warning("Could not find a video clip with the requested tags: %s" % [fragment.video_action_tags])
		return false
	var new_video_node: LogVideo = log_video.instantiate()
	log_entry_container.add_child(new_video_node)
	var video_playback: VideoPlayback = new_video_node.get_node("VideoPlayback")
	video_playback.set_video_path(video_clip.video_file)
	VideoPlayerSystem.register_clip_as_seen(video_clip)
	emit_signal("added_video_player", self)
	return true

#func _add_video_matching_tags(fragment: LogFragment) -> void:
	#if fragment.video_action_tags.is_empty():
		#return
	#var new_video_node = log_video.instantiate()
	#var video_clip: VideoClip = VideoPlayerSystem.get_video_by_tags(fragment.video_action_tags,fragment.video_participant_tags)
	##var video_clip: VideoClip = VideoPlayerSystem.get_video_by_tags(fragment.video_action_tags,[])
	#if not video_clip:
		#push_error("Could not find a video clip with the requested tags.")
		#return
	#new_video_node.stream = video_clip.video_file
	#log_entry_container.add_child(new_video_node)
	#emit_signal("added_video_player",self)

func delete_video() -> void:
	for child in log_entry_container.get_children():
		if child is LogVideo:
			child.queue_free()

func format_string_for_display(raw_string: String,opponent_name: String ="") -> String:
	var formatted_string: String = raw_string
	formatted_string = formatted_string.replace("[OPPONENT_NAME]",opponent_name)
	
	return formatted_string
