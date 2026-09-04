@tool
extends StatusModifierComponent
class_name Status_ChangeCostOfPlayingEventCardsPerPlay

## Which cards get the discount.
@export var card_ids: Array[String] = []
## Whose play count (this encounter) drives the scaling.
@export var tracked_card_id: String = ""
## Multiplied by how many times tracked_card_id has been played this encounter.
@export var energy_delta_per_play: int = 0

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "Status_ChangeCostOfPlayingEventCardsPerPlay"
	d["card_ids"] = card_ids
	d["tracked_card_id"] = tracked_card_id
	d["energy_delta_per_play"] = energy_delta_per_play
	return d

static func from_json_dict(data: Dictionary) -> Status_ChangeCostOfPlayingEventCardsPerPlay:
	var component := Status_ChangeCostOfPlayingEventCardsPerPlay.new()
	component.status_modifer_component_id = data.get("status_modifer_component_id", "")
	var ids: Array[String] = []
	for id in data.get("card_ids", []):
		ids.append(str(id))
	component.card_ids = ids
	component.tracked_card_id = data.get("tracked_card_id", "")
	component.energy_delta_per_play = int(data.get("energy_delta_per_play", 0))
	return component

func modify_context(_effect_context: EffectContext) -> void:
	pass

func get_list_of_cards() -> Array[String]:
	return card_ids

func get_current_energy_delta(game_state: GameState) -> int:
	if tracked_card_id == "":
		return 0
	var play_count: int = game_state.encounter_report.get_times_card_has_been_played(tracked_card_id)
	return energy_delta_per_play * play_count
