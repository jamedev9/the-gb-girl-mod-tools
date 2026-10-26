extends Cardgame_UI_Element
class_name LogDisplay

@export var scroll_container: ScrollContainer
@export var log_entry_container: Control

@export var log_entry_scene: PackedScene = preload("res://scenes/main_cardgame/log_display/log_entry_panel.tscn")

var debug_mode: bool = false

var current_fragment_message: String = ""

var entries_with_vidoes: Array[LogEntryPanel] = []
var max_nr_of_videos: int = 4

const SCROLL_DELAY: float = 0.05


#region Log merging from claude:
var last_entry_node: LogEntryPanel = null
var last_fragment_message_key: String = ""

func _can_merge_with_last_entry(fragment: LogFragment) -> bool:
	if not last_entry_node:
		return false
	if fragment.message_key != last_fragment_message_key:
		return false
	if fragment.message_key not in LogEntryPanel.MERGEABLE_FRAGMENT_KEYS:
		return false
	if fragment.message_key == "new_status_effect_was_applied_to_target":
		var last_message_status_id: String = last_entry_node._applied_status_id
		if fragment.values["status_id"] != last_message_status_id:
			return false
	if fragment.message_key == "status_effect_reapplied_to_target":
		var last_message_status_id: String = last_entry_node._reapplied_status_id
		if fragment.values["status_id"] != last_message_status_id:
			return false
	
	return true

func _merge_into_last_entry(fragment: LogFragment) -> void:
	last_entry_node.merge_with_new_fragment(fragment)
	
func _create_and_register_new_entry(fragment: LogFragment) -> LogEntryPanel:
	#if not _fragment_has_visuals_to_display(fragment):
		#return null
	var entry_node: LogEntryPanel = _make_new_player_readable_log_entry()
	_add_entry_node_to_container(entry_node)
	entry_node.connect("added_video_player",Callable(self,"_register_log_panel_with_video"))
	entry_node.display_player_readable_log_fragment(fragment)
	last_entry_node = entry_node
	last_fragment_message_key = fragment.message_key
	return entry_node

#func _fragment_has_visuals_to_display(fragment: LogFragment) -> bool:
	#var checks: Array[bool] = []
	#checks.append(fragment.show_to_player)
	#checks.append(fragment.message_key == "")
	#checks.append(fragment.video_action_tags.is_empty())
	#print("Displaying fragment with key: %s - and checks: %s"%[fragment.message_key,checks])
	#for check in checks:
		#if check:
			#return true
	#return false

func _register_log_panel_with_video(log_entry_panel: LogEntryPanel) -> void:
	entries_with_vidoes.append(log_entry_panel)
	if entries_with_vidoes.size() > max_nr_of_videos:
		_delete_oldest_video()

func _delete_oldest_video() -> void:
	var oldest_entry_with_video: LogEntryPanel = entries_with_vidoes[0]
	if not oldest_entry_with_video:
		entries_with_vidoes.remove_at(0)
		_delete_oldest_video()
	else:
		oldest_entry_with_video.delete_video()
		entries_with_vidoes.erase(oldest_entry_with_video)

func _show_new_log_entry(fragment: LogFragment) -> void:
	#print("Showing new log entry for key: %s"%fragment.message_key)
	match debug_mode:
		false:
			if _should_show_fragment(fragment):
				if _can_merge_with_last_entry(fragment):
					_merge_into_last_entry(fragment)
				else:
					_create_and_register_new_entry(fragment)
		true:
			var entry_node = _make_new_debug_log_entry_node()
			_add_entry_node_to_container(entry_node)
			entry_node.display_debug_log_fragment(fragment)
	
	_scroll_to_bottom()

#endregion
### Personal code
func update_class_specific_displays(_game_state: GameState) -> void:
	_scroll_after_timer(SCROLL_DELAY)


func _ready() -> void:
	main_game.connect("game_state_changed", Callable(self,"update_class_specific_displays"))
	main_game.connect("relay_signal_from_log_fragment_added", Callable(self,"_show_new_log_entry"))
	
func _make_new_debug_log_entry_node() -> LogEntryPanel:
	var new_node: LogEntryPanel = log_entry_scene.instantiate()
	return new_node
	
func _make_new_player_readable_log_entry() -> LogEntryPanel:
	var new_node: LogEntryPanel = log_entry_scene.instantiate()
	return new_node

### Whether the log shows this fragment at all. Child logs can override this to show fragments the game
func _should_show_fragment(fragment: LogFragment) -> bool:
	return fragment.show_to_player == true

### Where a new entry goes. Here the log is a container that grows downward (newest entry at the bottom).
func _add_entry_node_to_container(entry_node: LogEntryPanel) -> void:
	log_entry_container.add_child(entry_node)

func _scroll_to_bottom() -> void: ### TODO: Figure out how to scroll down automatically
	var max_scroll = scroll_container.get_v_scroll_bar().max_value
	scroll_container.set_deferred("scroll_vertical", max_scroll)


func _clear_log_entries() -> void:
	for child in log_entry_container.get_children():
		child.queue_free()

func _scroll_after_timer(delay: float) -> void:
	var timer = get_tree().create_timer(delay)
	#push_error("_scroll_after_timer")
	timer.timeout.connect(func():
		if not is_instance_valid(self):
			push_error("timer is not valid")
			return
		_scroll_to_bottom()
	)

### DEBUG MODE SWITCH:
func _input(event):
	# Check if the 'quit_game' action was just pressed
	if event.is_action_pressed("toggle_debug_mode"):
		match debug_mode:
			false:
				debug_mode = true
			true:
				debug_mode = false
		_clear_log_entries()
		for fragment in main_game.game_state.game_log:
			_show_new_log_entry(fragment)
