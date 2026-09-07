@tool
extends EffectIntent
class_name ApplyStatusEffect

@export var status_definition: StatusEffectDefinition
@export var status_duration: int = 1
@export var number_of_stacks: int = 1

### status_definition points at a StatusEffectDefinition - a stable, AutoloadDatabase-registered
### content resource (status_effects_by_id), not something that belongs embedded in a serialized
### payload. Overrides the generic ModExportable walk (see mod_exportable.gd) to serialize it as
### an id string instead, matching the id-reference pattern the rest of the save/mod system
### already uses for this kind of reference.
func to_json_dict() -> Dictionary:
	var result: Dictionary = super.to_json_dict()
	result.erase("status_definition")
	result["status_definition_id"] = status_definition.status_id if status_definition else ""
	return result

func populate_from_json_dict(data: Dictionary) -> void:
	super.populate_from_json_dict(data)
	var status_id: String = data.get("status_definition_id", "")
	if not status_id.is_empty():
		status_definition = AutoloadDatabase.get_status_effect_by_id(status_id)

#func apply_effect_to_context(context: EffectContext):
	#context.statuses_to_apply.append(self)
	
func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var ctx = EffectContext.new()
	ctx.statuses_to_apply.append(self)
	return ctx

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_APPLYSTATUSEFFECT_TEMPLATE"),
		{"status_name": _status_name_segment()})

### "Apply X to yourself for 3 turns" reads oddly - a status the player gives themselves is
### "gained", not "applied to" themselves. Explicit "Player" (not just "Gain X") since
### statuses/passives can be owned by either side - targeting_intent=PLAYER always means the
### player specifically, not "whoever owns this" - see DealDamageEffect's own self-targeted
### override for the same reasoning.
func get_self_targeted_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_APPLYSTATUSEFFECT_SELF_TEMPLATE"),
		{"status_name": _status_name_segment()})

func _status_name_segment() -> DescriptionSegment:
	if status_definition:
		return DescriptionSegment.nested_segment(
			status_definition.get_effect_name(), status_definition.get_description_segments())
	return DescriptionSegment.text_segment("?")

### "for 3 turns" reads better after targeting ("Apply X to Y for 3 turns") than baked into the
### main phrase ("Apply X for 3 turns to Y") - see EffectIntent.get_trailing_description_segments().
func get_trailing_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_pluralized_template(
		status_duration,
		"EFFECTINTENT_APPLYSTATUSEFFECT_DURATION_TEMPLATE_SINGULAR",
		"EFFECTINTENT_APPLYSTATUSEFFECT_DURATION_TEMPLATE",
		{"duration": str(status_duration)})
