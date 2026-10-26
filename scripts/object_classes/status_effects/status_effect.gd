@tool
extends EffectDefinition
class_name StatusEffectDefinition

@export var status_id: String
@export var status_name: String
@export var status_description: String
@export var status_picture: Texture2D

enum StatusCategory {BUFF, DEBUFF}
@export var status_category: StatusCategory

enum StatusTag {
	BDSM
}
@export var status_tags: Array[StatusTag]

### Whether applying this status again adds to its stack count. Off by default: a non-stackable status stays
### at 1 stack and a reapplication just adds to its duration (see MainCardgame._resolve_applying_statuses_to_target()).
@export var stackable: bool = false
### The most stacks a stackable status can reach. 0 = no limit. Ignored when not stackable.
@export var max_stacks: int = 0


@export var status_effect_components: Array[StatusModifierComponent] 
@export var ticking_effect_components: Array[StatusTickComponent]
@export var triggered_effect_components: Array[StatusTriggeredComponent]

### Set by AutoloadDatabase on statuses loaded from a mod's JSON: the text is shown as written instead of going through
### tr() (see EventCardDefinition.is_modded). @export_storage so duplicate() keeps it.
@export_storage var is_modded: bool = false

func get_effect_id() -> String:
	return status_id

### The stack count this status ends up with when it is asked to have `wanted_stacks`: always 1 for a
### non-stackable status, otherwise at least 1 and at most max_stacks (when that is set).
func limit_stacks(wanted_stacks: int) -> int:
	if not stackable:
		return 1
	var limited_stacks: int = maxi(wanted_stacks, 1)
	if max_stacks > 0:
		limited_stacks = mini(limited_stacks, max_stacks)
	return limited_stacks

func get_modifier_components() -> Array:
	return status_effect_components

func get_triggered_components() -> Array:
	return triggered_effect_components

func get_ticking_components() -> Array:
	return ticking_effect_components

### Edging's rules live in the game logic, not in a component: gaining a stack at the end of a turn
### (MainCardgame._gain_edging_stack_if_on_the_edge) and what an orgasm does to it (MainCardgame._resolve_edging_on_orgasm).
func get_built_in_trigger_lines() -> Array:
	if status_id == EdgingRules.STATUS_ID:
		return [EdgingRules.get_stack_rule_trigger_line(), EdgingRules.get_orgasm_rule_trigger_line()]
	return []

func get_effect_name() -> String:
	if is_modded:
		return status_name
	return tr("STATUSEFFECTDEFINITION_"+status_id.to_upper()+"_STATUS_NAME")

func get_effect_description() -> String:
	if is_modded:
		return status_description
	return tr("STATUSEFFECTDEFINITION_"+status_id.to_upper()+"_STATUS_DESCRIPTION")

func get_translation_entries() -> Array[Dictionary]:
	if is_modded:
		return [] ### Mod text is shown as written, and must not be written into game.csv by the editor's auto-localization.
	var prefix: String = "STATUSEFFECTDEFINITION_"+status_id.to_upper()
	return [
		{"key": prefix+"_STATUS_NAME", "text": status_name},
		{"key": prefix+"_STATUS_DESCRIPTION", "text": status_description},
	]

### The generated tooltip of a status starts with a line saying whether it stacks ("Stackable" / "Does not stack"), in the same
### heading style as "Modifiers" / "Triggers" (see EffectDefinition.get_tooltip_description_segments()). Left out when nothing is
### generated at all, so get_description_segments() still falls back to the hand-written text. Statuses only: passives never stack.
### stacks is how many the displayed status has (0 = not known, e.g. a status named inside another text): see EffectDefinition.
func get_tooltip_description_segments(stacks: int = 0) -> Array[DescriptionSegment]:
	var sections: Array[DescriptionSegment] = super.get_tooltip_description_segments(stacks)
	if sections.is_empty():
		return sections
	var stacking_heading: String = tr("STATUSEFFECTDEFINITION_STACKABLE_HEADER" if stackable else "STATUSEFFECTDEFINITION_NOT_STACKABLE_HEADER")
	var segments: Array[DescriptionSegment] = [
		DescriptionSegment.heading_segment(stacking_heading),
		DescriptionSegment.text_segment("\n\n")]
	segments.append_array(sections)
	return segments

### Generic description support (see DescriptionBuilder) - used when something (currently
### ApplyStatusEffect) wants to nest-reference this status. Reuses the full Modifiers/Triggers
### tooltip (get_tooltip_description_segments()) - status_effect_components (e.g. MultiplyDamage)
### now describe themselves too, not just ticking_effect_components - falling back to the
### hand-written status_description if there's nothing generated at all.
func get_description_segments(stacks: int = 0) -> Array[DescriptionSegment]:
	var tooltip: Array[DescriptionSegment] = get_tooltip_description_segments(stacks)
	if tooltip.is_empty():
		return get_hand_written_description_segments()
	return tooltip


#STATUSEFFECTDEFINITION_AT_PEASE_STATUS_NAME,At Peace,安宁
#STATUSEFFECTDEFINITION_AT_PEASE_STATUS_DESCRIPTION,Target cannot give or receive pleasure.,目标无法给予或获得快乐。

#region Mod export
func get_mod_export_subfolder() -> String:
	return "status_effects"

func get_file_reference_fields() -> Dictionary:
	return {"status_picture": "images"}

### Hand-written rather than the generic ModExportable default because status_picture: Texture2D is a file reference
### (see get_file_reference_fields()), like PassiveEffectDefinition. The enums are written by name. The components
### serialize through their own (generic) to_json_dict().
func to_json_dict() -> Dictionary:
	var modifier_component_dicts: Array = []
	for component in status_effect_components:
		if component:
			modifier_component_dicts.append(component.to_json_dict())
	var tick_component_dicts: Array = []
	for component in ticking_effect_components:
		if component:
			tick_component_dicts.append(component.to_json_dict())
	var triggered_component_dicts: Array = []
	for component in triggered_effect_components:
		if component:
			triggered_component_dicts.append(component.to_json_dict())
	var tag_names: Array = []
	for tag in status_tags:
		tag_names.append(StatusTag.keys()[tag])

	return {
		"_class": get_script().get_global_name(),
		"status_id": status_id,
		"status_name": status_name,
		"status_description": status_description,
		"status_picture": ModExportable.resolve_to_res_path(status_picture.resource_path, resource_path) if status_picture else "",
		"status_category": StatusCategory.keys()[status_category],
		"status_tags": tag_names,
		"stackable": stackable,
		"max_stacks": max_stacks,
		"has_secret_description": has_secret_description,
		"status_effect_components": modifier_component_dicts,
		"ticking_effect_components": tick_component_dicts,
		"triggered_effect_components": triggered_component_dicts,
	}

### mod_folder_path: the mod's images folder (resolves status_picture, see get_file_reference_fields()). Components are
### rebuilt through ModdableResourceRegistry.instantiate() from their "_class" tags.
static func from_json_dict(data: Dictionary, mod_folder_path: String = "") -> StatusEffectDefinition:
	var status_def: StatusEffectDefinition = StatusEffectDefinition.new()
	status_def.status_id = str(data.get("status_id", ""))
	status_def.status_name = str(data.get("status_name", ""))
	status_def.status_description = str(data.get("status_description", ""))
	status_def.stackable = bool(data.get("stackable", false))
	status_def.max_stacks = int(data.get("max_stacks", 0))
	status_def.has_secret_description = bool(data.get("has_secret_description", false))

	var category_key: String = ModExportable.find_case_insensitive_enum_key(StatusCategory.keys(), str(data.get("status_category", "")))
	if category_key != "":
		status_def.status_category = StatusCategory[category_key]
	for tag_name in data.get("status_tags", []):
		var tag_key: String = ModExportable.find_case_insensitive_enum_key(StatusTag.keys(), str(tag_name))
		if tag_key != "":
			status_def.status_tags.append(StatusTag[tag_key])

	var picture_file_name: String = data.get("status_picture", "")
	if picture_file_name != "" and mod_folder_path != "":
		status_def.status_picture = Utils.load_texture_from_path(mod_folder_path.path_join(picture_file_name))

	for component_data in data.get("status_effect_components", []):
		var component: StatusModifierComponent = ModdableResourceRegistry.instantiate(component_data) as StatusModifierComponent
		if component:
			status_def.status_effect_components.append(component)
	for component_data in data.get("ticking_effect_components", []):
		var tick_component: StatusTickComponent = ModdableResourceRegistry.instantiate(component_data) as StatusTickComponent
		if tick_component:
			status_def.ticking_effect_components.append(tick_component)
	for component_data in data.get("triggered_effect_components", []):
		var triggered_component: StatusTriggeredComponent = ModdableResourceRegistry.instantiate(component_data) as StatusTriggeredComponent
		if triggered_component:
			status_def.triggered_effect_components.append(triggered_component)

	return status_def
#endregion
