extends Metagame_UI_Element
class_name UnlockRewardDisplay

var reward_id: String
var reward_def: RewardDefinition
var displayed_on_encounter: EncounterDefinition

@export var reward_name: RichTextLabel
@export var reward_description: RichTextLabel
@export var reward_picture: TextureRect
@export var check_box: TextureRect
@export var reward_unlock_container: Container
@export var reward_unlocked_overlay: PanelContainer
@export var unlock_header: RichTextLabel
@export var black_line_panel: Panel

@export var unlock_requirements_panel: PackedScene = preload("res://scenes/meta_game/unlock_reward_display/unlock_requirement_panel.tscn")

const FADE_REWARD_DURATION: float = 0.5
const FADE_DELAY: float = 0.5
const TIME_BETWEEN_FADES:float = 0.75

func _refresh_text() -> void:
	if not reward_def:
		return
	_update_text_boxes(reward_def)

func display_reward_information(encounter_def: EncounterDefinition,given_reward_def: RewardDefinition) -> void:
	#print("Displaying reward: %s"%given_reward_def.reward_name)
	displayed_on_encounter = encounter_def
	reward_id = given_reward_def.reward_id
	reward_def = given_reward_def
	reward_picture.texture = given_reward_def.reward_picture
	_update_text_boxes(given_reward_def)

func _update_text_boxes(given_reward_def: RewardDefinition) -> void:
	reward_name.text = "[b]"+given_reward_def.get_reward_name()+"[/b]"
	reward_description.text = given_reward_def.get_description()	

func update_on_meta_game_enter_finished(save_game_state: SaveGameState) -> void:
#func update_when_save_game_changes(save_game_state: SaveGameState) -> void:
	var is_clearance_rewards: bool = false
	if displayed_on_encounter:
		is_clearance_rewards = reward_id in displayed_on_encounter.rewards_granted_by_clearing
	var is_unlocked: bool = save_game_state.is_reward_unlocked(reward_id)
	if is_clearance_rewards:
		if displayed_on_encounter.encounter_id not in save_game_state.encounters_completed.keys():
			is_unlocked = false
		else:
			is_unlocked = save_game_state.encounters_completed[displayed_on_encounter.encounter_id] > 0
	if is_unlocked:
		_show_reward_as_unlocked()
	_show_unlock_criteria(save_game_state)

func _show_reward_as_unlocked() -> void:
	check_box.visible = true
	reward_unlocked_overlay.visible = true

func fade_in_unlocked_box() -> void:
	#print("Running fade_in_unlocked_box for reward: %s"%reward_def.reward_name)
#func _fade_in(node: Control,delay: float = 0.0,duration: float = fade_duration) -> void:
	#await get_tree().create_timer(TIME_BETWEEN_FADES).timeout
	check_box.visible = true
	reward_unlocked_overlay.visible = true
	check_box.modulate.a = 0.0
	reward_unlocked_overlay.modulate.a = 0.0
	var active_tween: Tween = null
	active_tween = create_tween()
	active_tween.tween_property(
		reward_unlocked_overlay,
		"modulate:a",
		1.0,
		FADE_REWARD_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(FADE_DELAY)

func _show_unlock_criteria(save_game_state: SaveGameState) -> void:
	unlock_header.show()
	black_line_panel.show()
	for child in reward_unlock_container.get_children():
		if child is UnlockRequirementPanel:
			child.queue_free()
	if not reward_def:
		return
	if reward_def.unlock_conditions.is_empty():
		unlock_header.hide()
		black_line_panel.hide()
	for condition in reward_def.unlock_conditions:
		var new_panel: UnlockRequirementPanel = unlock_requirements_panel.instantiate()
		new_panel.display_condition_status(reward_id,condition,save_game_state)
		reward_unlock_container.add_child(new_panel)
	var is_clearance_rewards: bool = false
	if displayed_on_encounter:
		is_clearance_rewards = reward_id in displayed_on_encounter.rewards_granted_by_clearing
	if is_clearance_rewards:
		var new_panel: UnlockRequirementPanel = unlock_requirements_panel.instantiate()
		new_panel.description.text = tr("UI_UNLOCK_REQUIREMENT_COMPLETE_ENCOUNTER") % displayed_on_encounter.encounter_display_name
		if save_game_state.is_encounter_completed(displayed_on_encounter.encounter_id):
			new_panel.condition_met_box.visible = true
		reward_unlock_container.add_child(new_panel)

	

		
	
