@tool
extends Status_ChangeCostOfPlayingEventCards
class_name Status_ChangeCostOfPlayingEventCardsPerPlay

## Whose play count (this encounter) drives the scaling.
@export var tracked_card_id: String = ""
## Multiplied by how many times tracked_card_id has been played this encounter.
@export var energy_delta_per_play: int = 0

func get_energy_delta(game_state: GameState) -> int:
	if tracked_card_id == "":
		return 0
	var play_count: int = game_state.encounter_report.get_times_card_has_been_played(tracked_card_id)
	return energy_delta_per_play * play_count
