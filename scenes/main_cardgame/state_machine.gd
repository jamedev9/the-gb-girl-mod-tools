extends GameSystem
class_name StateMachine

enum States {
	MAIN_MENU,
	META_GAME,
	CARD_GAME
}

var _current_state: States = States.MAIN_MENU

var _pending_encounter_report: EncounterReport
var _pending_encounter_def: EncounterDefinition

func _ready() -> void:
	main_game.meta_game.connect("forward_start_encounter_request",Callable(self,"_on_encounter_start_requested"))
	main_game.end_game_menu.connect("return_to_map_button_pressed",Callable(self,"_return_to_map"))
	transition_to(States.MAIN_MENU)
	
func transition_to(new_state: States) -> void:
	_on_state_exit(_current_state)
	_current_state = new_state	
	_on_state_enter(new_state)

func _on_state_exit(state: States) -> void:
	match state:
		States.CARD_GAME:
			_on_exit_card_game()
		States.META_GAME:
			_on_meta_game_exit()
		States.MAIN_MENU:
			_on_main_menu_exit()

func _on_state_enter(state: States) -> void:
	match state:
		States.CARD_GAME:
			_on_enter_card_game() 
		States.META_GAME:
			_on_meta_game_enter()
		States.MAIN_MENU:
			_on_main_menu_enter()


func open_pause_menu() -> void:
	if _current_state == States.MAIN_MENU:
		return
	_on_pause_menu_enter()

func close_pause_menu() -> void:
	_on_exit_pause_menu()
	
func _on_pause_menu_enter()-> void:
	_pending_encounter_report = main_game.game_state.encounter_report
	main_game.end_game_menu.show_menu()
	
func _on_exit_pause_menu() -> void:
	_pending_encounter_report = null
	main_game.end_game_menu.hide_menu()

func _on_encounter_start_requested(encounter_def: EncounterDefinition) -> void:
	_pending_encounter_def = encounter_def
	transition_to(States.CARD_GAME)

func _on_enter_card_game() -> void:
	main_game.sound_manager.unmute_cardgame_sounds()
	main_game.end_game_menu.show_return_to_map_button()
	await main_game._start_encounter(_pending_encounter_def)
	_pending_encounter_def = null
	main_game.end_game_menu.hide_menu()

func _on_exit_card_game():
	main_game._disable_player_input()
	main_game.cancel_animation_queue()
	main_game._clear_fragments()
	### TEST
	if _pending_encounter_report:
		main_game.meta_game.handle_game_progression(_pending_encounter_report)
	### TEST end
	main_game._clear_encounter()
	main_game._hide_card_game_controller()
	main_game.clear_defeated_opponents()
	#main_game.opponents_container._clear_defeated_opponents(main_game.game_state)
	main_game.sound_manager.end_encounter_music()
	main_game.sound_manager.play_menu_music()
	main_game.sound_manager.mute_cardgame_sounds()
	main_game.sound_manager.end_looping_tracks()
	
func _on_meta_game_enter():
	#_start_tutorial_if_required()
	main_game.meta_game.visible = true
	main_game.end_game_menu.hide_menu()
	main_game.end_game_menu.clear_encounter_report()
	main_game.end_game_menu.hide_return_to_map_button()
	main_game.meta_game._check_for_completed_rewards(null)
	if _pending_encounter_report:
		main_game.meta_game._display_completed_rewards(_pending_encounter_report)
	else:
		main_game.meta_game._display_completed_rewards(null)
	main_game.meta_game._push_meta_game_ui_update()
	_pending_encounter_report = null
	main_game.sound_manager.play_menu_music()
	main_game.settings_manager.store_last_used_save_slot(main_game.meta_game.current_save_slot)
	main_game.settings_manager.save_settings()
	main_game.meta_game.emit_meta_game_entered_signal()

func _on_meta_game_exit():
	main_game.meta_game.visible = false

func _return_to_map() -> void: ### Called from pause menu
	main_game._disable_player_input()
	main_game.game_state.player_quit_the_game = true
	transition_to(States.META_GAME)

func _on_main_menu_enter() -> void:
	main_game.main_menu.character_selection_screen.hide()
	main_game.main_menu.saved_games.hide()
	main_game.main_menu.show()
	main_game.main_menu.reload_saved_games()

func _on_main_menu_exit() -> void:
	main_game.main_menu.hide()
	main_game.simplified_tutorial.load_examples_if_needed()


#region Settings menu:
func open_settings_menu() -> void:
	main_game.settings_menu.show()

func close_settings_menu() -> void:
	main_game.settings_menu.hide()

func open_mods_menu() -> void:
	main_game.mods_menu.show()

func close_mods_menu() -> void:
	main_game.mods_menu.hide()

func toggle_rewards_panel() -> void:
	if main_game.is_rewards_for_active_encounter_visible():
	#if main_game.rewards_for_active_encounter.visible:
		main_game.hide_rewards_for_active_encounter()
		#main_game.rewards_for_active_encounter.hide()
	else:
		#main_game.rewards_for_active_encounter.show()
		main_game.show_rewards_for_active_encounter()
		#main_game.rewards_for_active_encounter.display_rewards_requiring_current_encounter(main_game.game_state)
		main_game.show_current_encounter_rewards()
