extends Cardgame_UI_Element
class_name SavedGamesPanel

@export var save_game_container: Container
@export var load_save_button: Button
@export var delete_save_button: Button
@export var confirm_delete_save: Control

@export var individual_save_game_display_scene: PackedScene

var saved_games: Dictionary[int,SaveGameState] = {}
var currently_highlighted_save: IndividualSaveGameDisplay

signal _request_loading_save(slot: int)
signal _request_deleting_save(slot: int)

func _ready() -> void:
	rebuild_save_games()

### Save-slot previews read passive definitions from AutoloadDatabase, which may still
### be loading in the background (see AutoloadDatabase._ready()). The guard lives here
### (rather than in each caller) since this is called from more than one place -
### _ready() above, and StateMachine._on_main_menu_enter() via MainMenu.reload_saved_games()
### - and any future caller gets the same safety for free.
func rebuild_save_games() -> void:
	if not AutoloadDatabase.is_content_loaded:
		AutoloadDatabase.run_when_content_loaded(rebuild_save_games)
		return
	_disable_load_and_delete_buttons()
	_clear_old_save_panels()
	saved_games.clear()  # <-- add this
	_load_saves_in_save_folder()
	_show_current_saves()

func _disable_load_and_delete_buttons() -> void:
	load_save_button.disabled = true
	delete_save_button.disabled = true
func _enable_load_and_delete_buttons() -> void:
	load_save_button.disabled = false
	delete_save_button.disabled = false

func _clear_old_save_panels() -> void:
	for child in save_game_container.get_children():
		if child is IndividualSaveGameDisplay:
			child.queue_free()

func _load_saves_in_save_folder() -> void:
	var save_game_slots: Array[int] = SaveSystem.get_used_save_slots()
	for slot in save_game_slots:
		_load_save_for_slot(slot)

func _load_save_for_slot(slot: int) -> void:
	var save_state: SaveGameState = SaveSystem.load_save(slot)
	saved_games[slot] = save_state

func _show_current_saves() -> void:
	for slot in saved_games.keys():
		var save_state: SaveGameState = saved_games[slot]
		_add_panel_for_save_slot(slot,save_state)

func _add_panel_for_save_slot(slot,save_state) -> void:
	var new_panel: IndividualSaveGameDisplay = _make_new_save_panel()
	save_game_container.add_child(new_panel)
	new_panel.display_save_slot(slot,save_state)
	new_panel.connect("save_slot_was_pressed",Callable(self,"_on_save_slot_pressed"))
	new_panel.connect("save_slot_was_double_clicked",Callable(self,"_load_save_from_panel"))

func _make_new_save_panel() -> IndividualSaveGameDisplay:
	var new_panel: IndividualSaveGameDisplay = individual_save_game_display_scene.instantiate()
	return new_panel

func _on_save_slot_pressed(save_display: IndividualSaveGameDisplay) -> void:
	_select_save_display(save_display)

func _select_save_display(save_display) -> void:
	if currently_highlighted_save:
		currently_highlighted_save.hide_green_highlight()
	currently_highlighted_save = save_display
	save_display.show_green_highlight()
	_enable_load_and_delete_buttons()

func _load_save_from_panel(panel: IndividualSaveGameDisplay) -> void:
	var loaded_slot: int = panel.save_slot_represented
	emit_signal("_request_loading_save",loaded_slot)

func _on_load_save_button_pressed() -> void:
	_load_save_from_panel(currently_highlighted_save)


func _on_close_saved_games_button_pressed() -> void:
	confirm_delete_save.hide()
	self.hide()

func _on_delete_save_button_pressed() -> void:
	confirm_delete_save.show()

func _on_delete_yes_pressed() -> void:
	confirm_delete_save.hide()
	emit_signal("_request_deleting_save",currently_highlighted_save.save_slot_represented)
	currently_highlighted_save.queue_free()
	currently_highlighted_save = null


func _on_delete_no_pressed() -> void:
	confirm_delete_save.hide()
