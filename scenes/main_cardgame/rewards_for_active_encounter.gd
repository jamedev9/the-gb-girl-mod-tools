extends EncounterDescriptionDisplay
class_name RewardsForActiveEncounter


func _ready() -> void:
	pass

func update_when_save_game_changes(_save_game_state: SaveGameState) -> void:
	pass

### Rebuilt from scratch each time (when the panel is opened, and while it is open after every UI refresh, see
### MainCardgame.refresh_in_encounter_rewards_panel()), so the numbers follow the run.
func display_rewards_requiring_current_encounter(game_state: GameState) -> void:
	_clear_unlock_rewards_container()

	### A temporary copy of the save with this run's results added. Conditions that count over the whole save read
	### them from there; conditions that count one run read the report itself.
	var updated_save_game: SaveGameState = SaveSystem.load_save(meta_game.current_save_id)
	updated_save_game.apply_encounter_report(game_state.encounter_report)
	updated_save_game.in_progress_encounter_report = game_state.encounter_report

	_display_rewards_requiring_encounter(game_state.current_encounter,updated_save_game)


func _on_close_saved_games_button_pressed() -> void:
	self.hide()
