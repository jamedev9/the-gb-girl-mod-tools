extends Metagame_UI_Element
class_name EncounterDescriptionDisplay

@export var node_containing_encounter_info: Control
@export var nodes_hidden_before_encounter_select: Array[Control]

@export var encounter_name_label: RichTextLabel
@export var encounter_description_label: Label
@export var encounter_picture: TextureRect
@export var start_encounter_button: Button
@export var unlock_rewards_container: Container
@export var times_completed_value: RichTextLabel
@export var unlock_requirements_container: Container
@export var opponents_in_encounter: Container
@export var encounter_unlocked_overlay: PanelContainer
@export var checkbox_container: PanelContainer
@export var total_opps_count: RichTextLabel

### The first star of the difficulty row (a TextureRect inside an HBoxContainer); it is the template the other stars
### are copied from - see DifficultyStarRow. Leave empty for no stars.
@export var star_texture_node: TextureRect

@export_group("Difficulty stars")
### Shows the displayed encounter's difficulty (MetaGame.get_encounter_difficulty_stars()) as that many stars. Only works
### while EncounterDifficultySettings.ENABLED (the master switch of the whole feature, currently off) is true.
@export var show_difficulty_stars: bool = false
### Debug builds only, and only with the feature and show_difficulty_stars on: 1-5 shows that many stars whatever the
### real rating is, to judge the look. 0 = real ratings.
@export_range(0, 5) var debug_preview_star_count: int = 0

@onready var reward_display_scene: PackedScene = load("res://scenes/meta_game/unlock_reward_display/unlock_reward_display.tscn")
@onready var unlock_requirements_panel: PackedScene = load("res://scenes/meta_game/unlock_reward_display/unlock_requirement_panel.tscn")
@onready var opponent_type_with_counter: PackedScene = load("res://scenes/meta_game/components/opponent_type_with_counter.tscn")

var currently_displayed_encounter: EncounterDefinition
var _difficulty_star_row: DifficultyStarRow

signal start_encounter_request(encounter_def: EncounterDefinition)

func _ready() -> void:
	super._ready()
	_hide_displays()
	start_encounter_button.connect("button_asking_for_encounter_id",Callable(self,"_send_encounter_id_to_button"))
	main_game.entity_registry.register_entity("encounter_description_display",self)

func _refresh_text() -> void:
	if not currently_displayed_encounter:
		return
	_update_text_from_description(currently_displayed_encounter)

func _hide_displays() -> void:
	node_containing_encounter_info.visible = false
	for node in nodes_hidden_before_encounter_select:
		node.hide()
	_clear_unlock_rewards_container()
	_hide_difficulty_stars()

func _show_displays() -> void:
	node_containing_encounter_info.visible = false
	for node in nodes_hidden_before_encounter_select:
		node.show()

func _clear_unlock_rewards_container() -> void:
	for child in unlock_rewards_container.get_children():
		child.queue_free()
		
func update_displayed_encounter(encounter_def: EncounterDefinition,save_game_state: SaveGameState) -> void:
	if encounter_def == null:
		_hide_displays()
		return
	_show_displays()
	self.currently_displayed_encounter = encounter_def
	start_encounter_button.visible = true
	_update_text_from_description(encounter_def)
	#encounter_name_label.text = "[b]"+encounter_def.get_encounter_name()+"[/b]"
	#encounter_description_label.text = encounter_def.get_encounter_description()
	encounter_picture.texture = encounter_def.encounter_picture
	_clear_unlock_rewards_container()
	_display_rewards_requiring_encounter(encounter_def,save_game_state)
	_display_opponents_in_encounter(encounter_def)
	node_containing_encounter_info.visible = true
	_update_difficulty_stars()

func _update_text_from_description(encounter_def: EncounterDefinition) -> void:
	encounter_name_label.text = "[b]"+encounter_def.get_encounter_name()+"[/b]"
	encounter_description_label.text = encounter_def.get_encounter_description()

func _display_rewards_requiring_encounter(
	encounter_def:EncounterDefinition,save_game_state: SaveGameState) -> void:
	var displayed_rewards: Array[String] = []
	var encounter_id: String = encounter_def.encounter_id
	var rewards_from_clearing: Array[String] = encounter_def.rewards_granted_by_clearing
	for reward_id in rewards_from_clearing:
		if reward_id in displayed_rewards:
			continue
		displayed_rewards.append(reward_id)
		_add_new_reward_display(encounter_def,reward_id,save_game_state)
	var reward_ids: Array[String] = AutoloadDatabase.get_rewards_requiring_encounter_to_unlock(encounter_id)
	for reward_id in reward_ids:
		if reward_id in displayed_rewards:
			continue
		displayed_rewards.append(reward_id)
		_add_new_reward_display(encounter_def,reward_id,save_game_state)

func _add_new_reward_display(
	encounter_def: EncounterDefinition,reward_id: String,save_game_state: SaveGameState) -> void:
	var reward_def: RewardDefinition = AutoloadDatabase.get_unlock_reward_definition(reward_id)
	if not RewardDebugMode.enabled and reward_def.reward_is_hidden_from_player(save_game_state):
		return
	var new_reward_box: UnlockRewardDisplay = reward_display_scene.instantiate()
	unlock_rewards_container.add_child(new_reward_box)
	new_reward_box.display_reward_information(encounter_def,reward_def)
	new_reward_box.update_on_meta_game_enter_finished(save_game_state)

func _display_opponents_in_encounter(encounter_def: EncounterDefinition) -> void:
	var opponents_total: int = 0
	for child in opponents_in_encounter.get_children():
		if child is OpponentTypeWithCounter:
			child.queue_free()
	for opponent_type_id in encounter_def.opponents_in_encounter_reserves.keys():
		var opponent_type: OpponentType = AutoloadDatabase.opponent_types[opponent_type_id]
		var nr_of_opps: int = encounter_def.opponents_in_encounter_reserves[opponent_type_id]
		opponents_total += nr_of_opps
		add_opponent_panel(opponent_type,str(nr_of_opps))
	
	total_opps_count.text = "[b]"+str(opponents_total)

func add_opponent_panel(opponent_type: OpponentType,counter_value: String) -> void:
	var new_panel: OpponentTypeWithCounter = opponent_type_with_counter.instantiate()
	new_panel.show_opponent_type_with_counter_value(opponent_type,counter_value)
	opponents_in_encounter.add_child(new_panel)


func update_when_save_game_changes(save_game_state: SaveGameState) -> void:
	#var p = Profiler.new("update: EncounterDescriptionDisplay")
	if not currently_displayed_encounter:
		node_containing_encounter_info.visible = false
		return
	if currently_displayed_encounter.encounter_id in save_game_state.encounters_completed.keys():
		times_completed_value.text = "[i]"+str(int(save_game_state.encounters_completed[currently_displayed_encounter.encounter_id]))
		checkbox_container.visible = true
	else: 
		times_completed_value.text = "0"
		checkbox_container.visible = false
	if currently_displayed_encounter.encounter_id in meta_game.available_encounters:
		start_encounter_button.disabled = false
	else:
		start_encounter_button.disabled = true
	_show_unlock_criteria(save_game_state)
	_handle_deck_size_effects(save_game_state)
	_update_difficulty_stars()
	#p.stop()

#region Difficulty stars
func _get_difficulty_star_row() -> DifficultyStarRow:
	if not star_texture_node:
		return null
	if _difficulty_star_row == null:
		_difficulty_star_row = DifficultyStarRow.new(star_texture_node)
	return _difficulty_star_row

### Shows the stars for the displayed encounter. Called when an encounter is selected and whenever the save changes
### (a stat reward or action upgrade changes the rating, and the UI is pushed right after it). Only while the info
### panel is up: _hide_displays() leaves currently_displayed_encounter behind (the next selection overwrites it), so
### that alone doesn't say whether an encounter is selected.
func _update_difficulty_stars() -> void:
	var star_row: DifficultyStarRow = _get_difficulty_star_row()
	if star_row == null:
		return
	var star_count: int = 0
	if node_containing_encounter_info.visible:
		star_count = DifficultyStarRow.get_star_count(
			meta_game, currently_displayed_encounter, show_difficulty_stars, debug_preview_star_count)
	star_row.show_count(star_count)

func _hide_difficulty_stars() -> void:
	var star_row: DifficultyStarRow = _get_difficulty_star_row()
	if star_row:
		star_row.show_count(0)
#endregion

func _handle_deck_size_effects(save_game_state: SaveGameState) -> void:
	if save_game_state.deck_is_too_small():
		start_encounter_button.disabled = true



func _on_start_encounter_button_pressed() -> void:
	if currently_displayed_encounter and start_encounter_button.disabled == false:
		emit_signal("start_encounter_request",self.currently_displayed_encounter)

func _show_unlock_criteria(save_game_state: SaveGameState) -> void:
	for child in unlock_requirements_container.get_children():
		if child is UnlockRequirementPanel:
			child.queue_free()
	if not currently_displayed_encounter:
		return
	var encounter_def: EncounterDefinition = AutoloadDatabase.get_encounter_def_by_id(currently_displayed_encounter.encounter_id)
	for condition in AutoloadDatabase.get_encounter_unlock_requirements(encounter_def):
		var new_panel: UnlockRequirementPanel = unlock_requirements_panel.instantiate()
		unlock_requirements_container.add_child(new_panel)
		new_panel.display_condition_status("",condition,save_game_state)

func _send_encounter_id_to_button() -> void:
	start_encounter_button.displayed_encounter = self.currently_displayed_encounter
