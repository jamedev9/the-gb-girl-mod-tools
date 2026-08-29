extends Resource
class_name EncounterDefinition

@export_category("Map node properties")
@export var unlock_conditions: Array[UnlockCondition]
@export var branch_index: int
@export var rewards_granted_by_clearing: Array[String] #Reward Definition IDs
@export var map_region_id: String

@export_category("Encounter info")
@export var encounter_id: String
@export var encounter_display_name: String
@export var encounter_description: String
@export var encounter_picture: Texture2D
@export var encounter_music: AudioStream

@export var opponents_in_encounter_reserves: Dictionary[String,int] = {
	#"avg_joe":3,
	#"wingman": 2,
	#"long_john": 3
}

@export var min_simultaneous_opponents: int

@export var fixed_spawn_order: Dictionary[int,String] = {} # int (spawn number) -> opponent_type_id

@export var event_cards_starting_hand: Dictionary[String,int] = {
	#"invert_outgoing_damage":1,
	#"player_dubs_damage": 1,
}

@export var forbid_all_summons: bool = false
@export var forbidden_ally_summons: Array[String] = [] #ID of opponent type. Use for lore or challenge reasons

func get_encounter_name() -> String:
	return tr("ENCOUNTERDEFINITION_"+encounter_id.to_upper()+"_ENCOUNTER_DISPLAY_NAME")
func get_encounter_description() -> String:
	return tr("ENCOUNTERDEFINITION_"+encounter_id.to_upper()+"_ENCOUNTER_DESCRIPTION")

func get_translation_entries() -> Array[Dictionary]:
	var prefix: String = "ENCOUNTERDEFINITION_"+encounter_id.to_upper()
	return [
		{"key": prefix+"_ENCOUNTER_DISPLAY_NAME", "text": encounter_display_name},
		{"key": prefix+"_ENCOUNTER_DESCRIPTION", "text": encounter_description},
	]
