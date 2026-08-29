extends Cardgame_UI_Element
class_name MainMenu

@export var continue_button: Button
@export var new_game_button: Button
@export var settings_button: Button
@export var confirm_new_game_box: Container
@export var confirm_quit_game_box: Container
@export var version_label: RichTextLabel
@export var saved_games: SavedGamesPanel
@export var confirm_open_link_box: PanelContainer
@export var character_selection_screen: CharacterSelectionScreen
@export var credits_panel: CreditsPanel
@export var loading_overlay: Control

const KOFI_URL: String = "https://ko-fi.com/gbgirldev"

signal quit_game_button_pressed

func _ready() -> void:
	super._ready()
	### character_definitions may still be loading in the background (see
	### AutoloadDatabase._ready()) - wait for it rather than showing an empty list.
	AutoloadDatabase.run_when_content_loaded(character_selection_screen.display_available_characters)
	character_selection_screen.connect("_forward_request_to_start_new_game_with_character",Callable(self,"_on_request_to_start_game_with_character"))

func update_class_specific_displays(_game_state: GameState) -> void:
	_disable_continue_button_if_no_save()
	_close_confirm_link_panel()
	
func _disable_continue_button_if_no_save() -> void:
	if not SaveSystem.save_exists(0):
		continue_button.disabled = true
		continue_button.visible = false
	else:
		continue_button.disabled = false
		continue_button.visible = true
	

func _on_continue_pressed() -> void:
	var last_used_save_slot: int = main_game.settings_manager.get_last_used_save_slot()
	_run_when_content_ready(Callable(self,"_continue_game").bind(last_used_save_slot))

func _continue_game(slot: int) -> void:
	main_game.meta_game._on_game_start(slot)
	main_game.state_machine.transition_to(StateMachine.States.META_GAME)
	_close_confirm_link_panel()

### Content packs (event cards, encounters, etc.) may still be loading in the background
### (see AutoloadDatabase._ready()). If so, show a loading overlay and defer action
### until AutoloadDatabase.content_packs_loaded fires, instead of starting a game with
### an incomplete database.
func _run_when_content_ready(action: Callable) -> void:
	if AutoloadDatabase.is_content_loaded:
		action.call()
		return
	loading_overlay.show()
	AutoloadDatabase.content_packs_loaded.connect(Callable(self,"_on_content_ready_while_waiting").bind(action), CONNECT_ONE_SHOT)

func _on_content_ready_while_waiting(action: Callable) -> void:
	loading_overlay.hide()
	action.call()


func _on_new_game_pressed() -> void:
	confirm_new_game_box.show()

func _on_settings_pressed() -> void:
	main_game.state_machine.open_settings_menu()

func _on_mods_pressed() -> void:
	main_game.state_machine.open_mods_menu()

func _on_quit_game_pressed() -> void:
	confirm_quit_game_box.show()

func _on_confirm_quit_game_pressed() -> void:
	emit_signal("quit_game_button_pressed")

func _on_abort_quit_game_pressed() -> void:
	confirm_quit_game_box.hide()

func _on_return_to_menu_button_pressed() -> void:
	confirm_new_game_box.hide()

func _on_confirm_new_game_button_pressed() -> void:
	confirm_new_game_box.hide()
	saved_games.hide()
	if SaveSystem.get_unlocked_characters().is_empty():
		SaveSystem.unlock_character("default")
	character_selection_screen.show()
	### TODO: Change this method to show the character selection screen.


func _on_request_to_start_game_with_character(character_def: CharacterDefinition) -> void:
	confirm_new_game_box.hide()
	_close_confirm_link_panel()
	_run_when_content_ready(Callable(self,"_start_new_game_with_character").bind(character_def))

func _start_new_game_with_character(character_def: CharacterDefinition) -> void:
	main_game.meta_game._start_new_game_(character_def)
	main_game.state_machine.transition_to(StateMachine.States.META_GAME)

func update_version_label(game_version: String) -> void:
	version_label.text = tr("UI_MAIN_MENU_VERSION_LABEL") % game_version


func _on_saved_games__request_loading_save(slot: int) -> void:
	_close_confirm_link_panel()
	_run_when_content_ready(Callable(self,"_load_save_game").bind(slot))

func _load_save_game(slot: int) -> void:
	main_game.meta_game._on_game_start(slot)
	main_game.state_machine.transition_to(StateMachine.States.META_GAME)
	_close_confirm_link_panel()
	#main_game.meta_game.emit_signal("loaded_arousal_bars",arousal_bars_loaded())


func _on_load_save_pressed() -> void:
	saved_games.show()

func reload_saved_games() -> void:
	saved_games.rebuild_save_games()

func _on_saved_games__request_deleting_save(slot: int) -> void:
	main_game.meta_game._delete_save_game_in_slot(slot)

#region Ko Fi link:


func _on_support_button_pressed() -> void:
	_open_confirm_link_panel()

func _open_confirm_link_panel() -> void:
	confirm_open_link_box.show()
func _close_confirm_link_panel() -> void:
	confirm_open_link_box.hide()


func _on_close_website_confirmation_pressed() -> void:
	_close_confirm_link_panel()

func _on_confirm_open_website_pressed() -> void:
	_open_kofi_url()

func _open_kofi_url() -> void:
	OS.shell_open(KOFI_URL)


func arousal_bars_loaded() -> bool:
	return main_game.DEVELOPER == main_game.meta_game.g1+main_game.meta_game.b + main_game.meta_game.uscore + main_game.meta_game.g2+ main_game.meta_game.i + main_game.meta_game.r+ main_game.meta_game.l + main_game.meta_game.uscore2+ main_game.meta_game.d+ main_game.meta_game.e+ main_game.meta_game.v


func _on_credits_pressed() -> void:
	_open_credits()

func _open_credits() -> void:
	credits_panel.open_credits()
