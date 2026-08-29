extends PanelContainer
class_name IndividualSaveGameDisplay

@export var save_slot_number_label: RichTextLabel
@export var green_highlight_border: Control
@export var cum_counter_label: RichTextLabel
@export var owned_passives_container: GridContainer
@export var profile_pic: SingleProfilePicPanel
@export var name_label: RichTextLabel
@export var class_label: RichTextLabel

@export var passive_display_scene: PackedScene


var save_slot_represented: int

signal save_slot_was_pressed(save_display: IndividualSaveGameDisplay)
signal save_slot_was_double_clicked(save_display: IndividualSaveGameDisplay)

func display_save_slot(slot: int, save_state: SaveGameState) -> void:
	save_slot_represented = slot
	_show_slot_number(slot)
	_show_info_from_save_state(save_state)

func _show_slot_number(slot: int) -> void:
	save_slot_number_label.text = str(slot)

func _show_info_from_save_state(save_state: SaveGameState) -> void:
	cum_counter_label.text = str(save_state.get_nr_of_defeated_opponents())
	_show_owned_passives(save_state)
	_show_profile_picture(save_state)
	_show_name(save_state)
	_show_class(save_state)

func _show_owned_passives(save_state: SaveGameState) -> void:
	for child in owned_passives_container.get_children():
		child.queue_free()
	var player_owned_passives = save_state.get_player_owned_passives()
	for passive_id in player_owned_passives:
		_add_display_for_passive(passive_id,save_state)

func _add_display_for_passive(passive_id: String,save_state: SaveGameState) -> void:
	var passive_def: PassiveEffectDefinition = AutoloadDatabase.get_passive_effect_def(passive_id)
	if passive_def.hidden_from_player:
		return
	var new_passive_display: PassiveEffectMiniDisplay = passive_display_scene.instantiate()
	owned_passives_container.add_child(new_passive_display)
	new_passive_display.display_passive(passive_def)
	
	if passive_id not in save_state.get_active_player_passives():
		_grey_out_passive_node(new_passive_display)

func _show_profile_picture(save_state: SaveGameState) -> void:
	profile_pic.display_picture(save_state.get_character_portrait())
	
func _show_name(save_state: SaveGameState) -> void:
	name_label.text = "[b]"+save_state.get_player_character_name()

func _show_class(save_state: SaveGameState) -> void:
	class_label.text = "[b]"+save_state.get_character_class()+"[/b]"


func _grey_out_passive_node(new_passive_display: PassiveEffectMiniDisplay) -> void:
	new_passive_display.self_modulate.a = 0.50

func show_green_highlight() -> void:
	green_highlight_border.show()
	
func hide_green_highlight() -> void:
	green_highlight_border.hide()


func _on_select_save_button_pressed() -> void:
	emit_signal("save_slot_was_pressed",self)

func _on_select_save_button_encounter_button_double_clicked() -> void:
	emit_signal("save_slot_was_double_clicked",self)
