extends PanelContainer
class_name CharacterSelectionScreen

@export var character_panels_container: Container
@export var start_encounter_button: Button

@export var individual_character_select_panel: PackedScene

signal _forward_request_to_start_new_game_with_character(character_definition: CharacterDefinition)

var currently_selected_character_panel: IndividualCharacterSelectPanel = null

func _ready() -> void:
	start_encounter_button.disabled = true
	SaveSystem.connect("_player_progression_changed",Callable(self,"_on_player_progression_changed"))

func _on_player_progression_changed() -> void:
	display_available_characters()

func display_available_characters() -> void:
	for child in character_panels_container.get_children():
		if child is IndividualCharacterSelectPanel:
			child.queue_free()
	
	var available_characters: Array[CharacterDefinition] = AutoloadDatabase.get_all_character_definitions()
	for character in available_characters:
		if not character.is_modded and not SaveSystem.is_character_unlocked(character.character_id):
			continue
		var new_panel: IndividualCharacterSelectPanel = _make_new_panel()
		character_panels_container.add_child(new_panel)
		new_panel.display_character(character)
		new_panel.connect("character_was_clicked",Callable(self,"_on_character_panel_clicked"))

func _make_new_panel() -> IndividualCharacterSelectPanel:
	var new_panel: IndividualCharacterSelectPanel = individual_character_select_panel.instantiate()
	return new_panel

func _on_character_panel_clicked(character_panel: IndividualCharacterSelectPanel) -> void:
	if currently_selected_character_panel:
		currently_selected_character_panel.hide_green_highlight()
	currently_selected_character_panel = character_panel
	character_panel.show_green_highlight()
	start_encounter_button.disabled = false


func _on_start_encounter_button_pressed() -> void:
	if not currently_selected_character_panel:
		return
	emit_signal("_forward_request_to_start_new_game_with_character",currently_selected_character_panel.displayed_character_def)
	pass # Replace with function body.


func _on_close_button_pressed() -> void:
	self.hide()
	pass # Replace with function body.
