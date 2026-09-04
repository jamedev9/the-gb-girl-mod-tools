@tool
extends StatusModifierComponent
class_name Status_ChangeCostOfPlayingEventCards

@export var all_cards: bool = false
@export var card_ids: Array[String]
@export var energy_delta: int = 0

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "Status_ChangeCostOfPlayingEventCards"
	d["all_cards"] = all_cards
	d["card_ids"] = card_ids
	d["energy_delta"] = energy_delta
	return d

static func from_json_dict(data: Dictionary) -> Status_ChangeCostOfPlayingEventCards:
	var component := Status_ChangeCostOfPlayingEventCards.new()
	component.status_modifer_component_id = data.get("status_modifer_component_id", "")
	component.all_cards = data.get("all_cards", false)
	var ids: Array[String] = []
	for id in data.get("card_ids", []):
		ids.append(str(id))
	component.card_ids = ids
	component.energy_delta = int(data.get("energy_delta", 0))
	return component

func modify_context(_effect_context: EffectContext) -> void:
	pass

func get_list_of_cards() -> Array[String]:
	return card_ids
	
