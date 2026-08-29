extends PanelContainer
class_name IndividualCharacterSelectPanel

@export var name_input_line: LineEdit
@export var age_input_line: LineEdit
@export var character_type_label: RichTextLabel
@export var passive_info: BoxContainer
@export var passives_container: GridContainer
@export var starting_hp_label: RichTextLabel
@export var starting_damage_threshold_label: RichTextLabel
@export var starting_max_energy_label: RichTextLabel
@export var starting_ally_container: BoxContainer
@export var starting_ally_panel: OpponentTypePanelWithTooltip
@export var starting_orgasm_card_container: BoxContainer
@export var orgasm_card_decklist_panel: DecklistCardPanel
@export var extra_starting_cards_container: BoxContainer
@export var starting_deck_panels_container: BoxContainer
@export var profile_picture_rect: TextureRect
@export var green_border_control: Control
@export var overlaid_button: Button
@export var actions_container: GridContainer
#@export var tags_label: Label
@export var min_deck_size_container: BoxContainer
@export var min_deck_size_label: RichTextLabel
@export var video_tags_container: BoxContainer

@export var passive_effect_mini_display_scene: PackedScene
@export var decklist_panel_scene: PackedScene
@export var action_name_with_tooltip_scene: PackedScene
@export var video_tag_button_scene: PackedScene


@onready var empty_save_game_state: SaveGameState = SaveGameState.new()

var displayed_character_def: CharacterDefinition

signal character_was_clicked(panel: IndividualCharacterSelectPanel)

func _ready() -> void:
	overlaid_button.show() ### Hiding it to make working in the editor easier

func _on_overlaid_button_pressed() -> void:
	emit_signal("character_was_clicked",self)

func show_green_highlight() -> void:
	green_border_control.show()
func hide_green_highlight() -> void:
	green_border_control.hide()

func display_character(given_character: CharacterDefinition) -> void:
	var character_def: CharacterDefinition = given_character.duplicate(true)
	### Deep copy that can be altered by the player before being sent to start new game.
	_set_displayed_character_resource(character_def)
	_display_name(character_def)
	_display_age(character_def)
	_display_character_class_name(character_def)
	_display_portrait(character_def)
	_display_participant_tags(character_def)
	_display_actions(character_def)
	_display_passives(character_def)
	_display_deck_overrides(character_def)
	_display_staring_hp(character_def)
	_display_starting_damage_threshold(character_def)
	_display_starting_max_energy(character_def)
	_display_starting_ally(character_def)
	_display_starting_orgasm_card(character_def)
	_display_min_deck_size(character_def)
	

func _set_displayed_character_resource(character_def: CharacterDefinition) -> void:
	displayed_character_def = character_def

func _display_name(character_def: CharacterDefinition) -> void:
	if character_def.character_name != "":
		name_input_line.text = character_def.character_name
		return
	var default_player_name: String = empty_save_game_state.get_player_character_name()
	name_input_line.text = default_player_name

func _display_age(character_def: CharacterDefinition) -> void:
	if character_def.character_age:
		age_input_line.text = str(character_def.character_age)
		return
	var default_player_age: int = empty_save_game_state.get_player_age()
	age_input_line.text = str(default_player_age)
	
func _display_character_class_name(character_def: CharacterDefinition) -> void:
	var type_name: String = "Unspecified"
	if character_def.character_class_name:
		if character_def.character_class_name !="":
			type_name = character_def.character_class_name
	else:
		type_name = empty_save_game_state.get_default_character_class_name()
	character_type_label.text = type_name

func _display_portrait(character_def: CharacterDefinition) -> void:
	var character_picture: Texture2D = null
	if not character_def.portrait_image_path:
		character_picture = _load_default_picture()

	if character_def.portrait_image_path == "":
		character_picture = _load_default_picture()

	if not character_picture:
		character_picture = _load_picture_from_character_def(character_def)
	
	profile_picture_rect.texture = character_picture
	

func _load_default_picture() -> Texture2D:
	return empty_save_game_state.get_character_portrait()

func _load_picture_from_character_def(character_def: CharacterDefinition) -> Texture2D:
	var path_to_picture: String = character_def.portrait_image_path

	if path_to_picture.begins_with("res://"):
		if not ResourceLoader.exists(path_to_picture):
			print("Could not find project resource at path: %s - returning null texture" % path_to_picture)
			return null
		var loaded_resource = load(path_to_picture)
		if loaded_resource is Texture2D:
			return loaded_resource
		print("Resource at path is not a Texture2D: %s" % path_to_picture)
		return null

	# External filesystem path (for modded/user-provided images later)
	if not FileAccess.file_exists(path_to_picture):
		print("Could not find file at path: %s - returning null texture" % path_to_picture)
		return null
	var image := Image.load_from_file(path_to_picture)
	if not image:
		print("Failed to load image data at path: %s" % path_to_picture)
		return null
	return ImageTexture.create_from_image(image)

func _display_participant_tags(character_def: CharacterDefinition) -> void:
	#var participant_tags = character_def.video_participant_tags
	var parsed_tags = character_def.video_participant_tags
	 #VideoClip._parse_participant_tags(participant_tags,character_def.character_id)
	for tag in parsed_tags:
		var new_button: VideoTagButton = video_tag_button_scene.instantiate()
		video_tags_container.add_child(new_button)
		new_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		new_button.set_represented_tag(tag)

func _display_actions(character_def: CharacterDefinition) -> void:
	var list_of_actions: Array
	if not character_def.starting_actions.is_empty():
		list_of_actions = character_def.starting_actions
	else:
		list_of_actions = empty_save_game_state.default_owned_player_actions
	
	for action in list_of_actions:
		_add_panel_for_action(character_def,action)

func _add_panel_for_action(character_def: CharacterDefinition,action_id: String) -> void:
	var new_panel: IndividualActionCardDisplay_mini = action_name_with_tooltip_scene.instantiate()
	actions_container.add_child(new_panel)
	new_panel.display_action_from_character_def(character_def,action_id)


func _display_passives(character_def: CharacterDefinition) -> void:
	passive_info.show()
	if character_def.starting_passives.is_empty():
		passive_info.hide()
		return
	for passive_id in character_def.starting_passives:
		var passive_def: PassiveEffectDefinition = AutoloadDatabase.get_passive_effect_def(passive_id)
		if not passive_def:
			continue
		var new_passive_display: PassiveEffectMiniDisplay = passive_effect_mini_display_scene.instantiate()
		passives_container.add_child(new_passive_display)
		new_passive_display.custom_minimum_size = Vector2(40,40)
		new_passive_display.display_passive(passive_def)
	

func _display_deck_overrides(character_def: CharacterDefinition) -> void:
	extra_starting_cards_container.show()
	if character_def.extra_starting_cards.keys().is_empty():
		extra_starting_cards_container.hide()
		return
	
	for card_id in character_def.extra_starting_cards.keys():
		if card_id not in AutoloadDatabase.event_cards_by_id.keys():
			continue
		_add_panel_for_card(card_id,character_def.extra_starting_cards[card_id])

func _add_panel_for_card(card_id: String,count: int) -> void:
	var new_panel: DecklistCardPanel = decklist_panel_scene.instantiate()
	starting_deck_panels_container.add_child(new_panel)
	new_panel.display_event_card(card_id,count)
	new_panel.add_one_button.hide()
	new_panel.remove_one_button.hide()

	
func _display_staring_hp(character_def: CharacterDefinition) -> void:
	var starting_hp: String
	if character_def.get_starting_orgasm_count():
		starting_hp = str(character_def.get_starting_orgasm_count())
	else:
		starting_hp = str(empty_save_game_state.get_default_player_stat("hp"))
	
	starting_hp_label.text = starting_hp
	
func _display_starting_damage_threshold(character_def: CharacterDefinition) -> void:
	var starting_damage_threshold: String
	if character_def.get_starting_pleasure_max():
		starting_damage_threshold = str(character_def.get_starting_pleasure_max())
	else:
		starting_damage_threshold = str(empty_save_game_state.get_default_player_stat("damage_threshold"))
	
	starting_damage_threshold_label.text = starting_damage_threshold
	
func _display_starting_max_energy(character_def: CharacterDefinition) -> void:
	var starting_max_energy: String
	if character_def.starting_max_energy:
		starting_max_energy = str(character_def.starting_max_energy)
	else:
		starting_max_energy = str(empty_save_game_state.get_default_player_stat("max_energy"))
	
	starting_max_energy_label.text = starting_max_energy
	pass
	
func _display_starting_ally(character_def: CharacterDefinition) -> void:
	starting_ally_container.show()
	if not character_def.starting_ally_card:
		starting_ally_container.hide()
		return
	if character_def.starting_ally_card == "":
		starting_ally_container.hide()
		return
	if character_def.starting_ally_card not in AutoloadDatabase.event_cards_by_id.keys():
		starting_ally_container.hide()
		return
	
	var ally_summon_opponent_type_id: String = SaveGameState.get_ally_card_from_id(character_def.starting_ally_card)
	starting_ally_panel.update_displayed_info(ally_summon_opponent_type_id)


func _display_starting_orgasm_card(character_def: CharacterDefinition) -> void:
	if character_def.starting_orgasm_card:
		orgasm_card_decklist_panel.display_event_card(character_def.starting_orgasm_card,0)
		return
	var default_o_card: String = empty_save_game_state.get_default_orgasm_card()
	orgasm_card_decklist_panel.display_event_card(default_o_card,0)
	orgasm_card_decklist_panel.change_theme_of_card(EventCardDefinition.CardCategory.ORGASM_REWARD)

func _display_min_deck_size(character_def: CharacterDefinition) -> void:
	if character_def.minimum_deck_size:
		min_deck_size_label.text= str(character_def.minimum_deck_size)
	else:
		min_deck_size_label.text= str(SaveGameState.get_default_min_deck_size())
#region Selection button:

### The button is fired by the panel, not the other way around. This is to enable tooptips.
#func _gui_input(event: InputEvent) -> void:
	#if event is InputEventMouseButton:
		#if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			##print("Overlaid button input detected")
			#_on_overlaid_button_pressed()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _is_point_in_visible_area(get_global_mouse_position()):
				_on_overlaid_button_pressed()

func _is_point_in_visible_area(point: Vector2) -> bool:
	if not get_global_rect().has_point(point):
		return false
	var scroll_ancestor := _find_scroll_container_ancestor()
	if scroll_ancestor and not scroll_ancestor.get_global_rect().has_point(point):
		return false
	return true

func _find_scroll_container_ancestor() -> ScrollContainer:
	var node: Node = get_parent()
	while node:
		if node is ScrollContainer:
			return node
		node = node.get_parent()
	return null

func _on_mouse_entered() -> void:
	overlaid_button.add_theme_stylebox_override("normal", overlaid_button.get_theme_stylebox("hover"))

func _on_mouse_exited() -> void:
	if not get_global_rect().has_point(get_global_mouse_position()):
		overlaid_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())

#endregion
#region Player editing name and age:
func _on_player_name_edit_text_submitted(new_text: String) -> void:
	displayed_character_def.character_name = new_text

func _on_age_edit_text_submitted(new_text: String) -> void:
	var minimum_age: int = empty_save_game_state.get_minimum_age()
	var new_age: int = int(new_text)
	if new_age < minimum_age:
		new_age = minimum_age
	displayed_character_def.character_age = new_age

func _on_age_edit_text_changed(new_text: String) -> void:
	var sanitized: String = ""
	for character in new_text:
		if character.is_valid_int():
			sanitized += character
	if sanitized != new_text:
		age_input_line.text = sanitized
		age_input_line.caret_column = sanitized.length()
#endregion
