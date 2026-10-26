extends PanelContainer
class_name UnlockRequirementPanel

@export var description: DescriptionLabel
@export var condition_met_box: TextureRect

var _displayed_reward_id: String
var _displayed_condition: UnlockCondition
var _displayed_save_game_state: SaveGameState
### What the label shows right now (the condition text + progress counter), for tests and anything else that wants the words.
var displayed_segments: Array[DescriptionSegment] = []

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_text()

func _refresh_text() -> void:
	### For localization
	if not _displayed_condition:
		return
	display_condition_status(_displayed_reward_id, _displayed_condition, _displayed_save_game_state)

func display_condition_status(reward_id: String, condition: UnlockCondition,save_game_state: SaveGameState) -> void:
	if not condition:
		return
	_displayed_reward_id = reward_id
	_displayed_condition = condition
	_displayed_save_game_state = save_game_state
	var is_condition_met: bool = condition.is_condition_met(save_game_state,null)
	### A condition judged on one run has no report here, so it is only ever met by a run that already happened.
	var reward_def: RewardDefinition = AutoloadDatabase.get_unlock_reward_definition(reward_id)
	var was_met_by_earlier_run: bool = reward_def != null and reward_def.is_condition_remembered_as_met(save_game_state,condition)
	if is_condition_met or was_met_by_earlier_run or save_game_state.is_reward_unlocked(reward_id):
		condition_met_box.visible = true
		
	### The condition writes its own text (UnlockCondition.get_description_segments()); this adds the counter after it.
	var segments: Array[DescriptionSegment] = condition.get_description_segments(save_game_state)
	var progress_suffix: Array[DescriptionSegment] = _get_progress_suffix(condition, save_game_state)
	if not progress_suffix.is_empty():
		segments.append(DescriptionSegment.text_segment(" "))
		segments.append_array(progress_suffix)
	displayed_segments = segments
	description.show_segments(segments)

### The number after the condition text: "(3/10)" for something counted up, "(Best: 7)" where lower is better. Only
### conditions that say they have one (UnlockCondition.get_progress_style()) get it; the older ones whose
### text already holds a counter say NONE.
func _get_progress_suffix(condition: UnlockCondition,save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	var no_suffix: Array[DescriptionSegment] = []
	if not save_game_state:
		return no_suffix
	var suffix_text: String = ""
	match condition.get_progress_style():
		UnlockCondition.ProgressStyle.COUNT_UP:
			var required: int = condition.get_progress_required(save_game_state)
			var current: int = mini(condition.get_progress_current(save_game_state),required)
			suffix_text = tr("UI_UNLOCK_CONDITION_PROGRESS_COUNT").format({"current": current,"required": required})
		UnlockCondition.ProgressStyle.BEST_LOWER:
			var best_value: int = condition.get_progress_current(save_game_state)
			if best_value < 0:
				return no_suffix ### no winning run recorded yet
			suffix_text = tr("UI_UNLOCK_CONDITION_PROGRESS_BEST").format({"best": condition.format_best_value(best_value)})
	if suffix_text == "":
		return no_suffix
	var suffix: Array[DescriptionSegment] = [DescriptionSegment.emphasis_segment(suffix_text)]
	return suffix
