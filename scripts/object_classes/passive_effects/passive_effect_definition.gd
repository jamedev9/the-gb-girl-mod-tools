@tool
extends EffectDefinition
class_name PassiveEffectDefinition

@export var passive_id: String
@export var passive_name: String
@export var passive_description: String
@export var picture: Texture2D

@export var hidden_from_player: bool = false
@export var hidden_during_combat: bool = false
@export var toggleable_by_player: bool = false

#@export var trigger_phases: Array[EffectContext.ContextPhase]
@export var modifier_components: Array[StatusModifierComponent]
@export var ticking_effect_components: Array[StatusTickComponent]
@export var triggered_components: Array[StatusTriggeredComponent]

func get_effect_id() -> String:
	return passive_id

func get_modifier_components() -> Array:
	return modifier_components

func get_triggered_components() -> Array:
	return triggered_components

func get_effect_name() -> String:
	return tr("PASSIVEEFFECTDEFINITION_"+passive_id.to_upper()+"_PASSIVE_NAME")

func get_effect_description() -> String:
	return tr("PASSIVEEFFECTDEFINITION_"+passive_id.to_upper()+"_PASSIVE_DESCRIPTION")

func get_translation_entries() -> Array[Dictionary]:
	var prefix: String = "PASSIVEEFFECTDEFINITION_"+passive_id.to_upper()
	return [
		{"key": prefix+"_PASSIVE_NAME", "text": passive_name},
		{"key": prefix+"_PASSIVE_DESCRIPTION", "text": passive_description},
	]

func get_mod_export_subfolder() -> String:
	return "passives"

func get_file_reference_fields() -> Dictionary:
	return {"picture": "images"}

func to_json_dict() -> Dictionary:
	var modifier_component_dicts: Array = []
	for component in modifier_components:
		modifier_component_dicts.append(component.to_json_dict())
	var tick_component_dicts: Array = []
	for component in ticking_effect_components:
		tick_component_dicts.append(component.to_json_dict())
	var triggered_component_dicts: Array = []
	for component in triggered_components:
		triggered_component_dicts.append(component.to_json_dict())

	return {
		"passive_id": passive_id,
		"passive_name": passive_name,
		"passive_description": passive_description,
		"picture": ModExportable.resolve_to_res_path(picture.resource_path) if picture else "",
		"hidden_from_player": hidden_from_player,
		"hidden_during_combat": hidden_during_combat,
		"toggleable_by_player": toggleable_by_player,
		"modifier_components": modifier_component_dicts,
		"ticking_effect_components": tick_component_dicts,
		"triggered_components": triggered_component_dicts,
	}

static func from_json_dict(data: Dictionary, mod_folder_path: String = "") -> PassiveEffectDefinition:
	var passive_def := PassiveEffectDefinition.new()
	passive_def.passive_id = data.get("passive_id", "")
	passive_def.passive_name = data.get("passive_name", "")
	passive_def.passive_description = data.get("passive_description", "")
	passive_def.hidden_from_player = data.get("hidden_from_player", false)
	passive_def.hidden_during_combat = data.get("hidden_during_combat", false)
	passive_def.toggleable_by_player = data.get("toggleable_by_player", false)

	var picture_file_name: String = data.get("picture", "")
	if picture_file_name != "" and mod_folder_path != "":
		passive_def.picture = ModExportable.load_texture_from_mod(mod_folder_path.path_join(picture_file_name))

	for component_data in data.get("modifier_components", []):
		var component: StatusModifierComponent = StatusModifierComponent.from_json_dict(component_data)
		if component:
			passive_def.modifier_components.append(component)
	for component_data in data.get("ticking_effect_components", []):
		var tick_component: StatusTickComponent = StatusTickComponent.from_json_dict(component_data)
		if tick_component:
			passive_def.ticking_effect_components.append(tick_component)
	for component_data in data.get("triggered_components", []):
		var triggered_component: StatusTriggeredComponent = StatusTriggeredComponent.from_json_dict(component_data)
		if triggered_component:
			passive_def.triggered_components.append(triggered_component)

	return passive_def
