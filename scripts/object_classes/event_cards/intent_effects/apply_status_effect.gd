@tool
extends EffectIntent
class_name ApplyStatusEffect

### The status to apply, by its id (StatusEffectDefinition.status_id), like the rest of the game names content: read it
### through get_status_definition(). In the Inspector it has a dropdown of the statuses found in the project, and any id
### can be typed (a base-game status in the mod tools). Generic JSON writes it as "status_id".
@export var status_id: String = ""
@export var status_duration: int = 1
@export var number_of_stacks: int = 1

func _validate_property(property: Dictionary) -> void:
	ContentIdSuggestions.apply_to_property(property, "status_id", "StatusEffectDefinition", "status_id")

### The registered status status_id names; null when it isn't registered (yet, or its mod is gone).
func get_status_definition() -> StatusEffectDefinition:
	if status_id == "":
		return null
	return AutoloadDatabase.get_status_effect_by_id(status_id)

### Saves and mod files written before status_id existed hold the id as "status_definition_id".
func populate_from_json_dict(data: Dictionary) -> void:
	super.populate_from_json_dict(data)
	if status_id == "":
		status_id = str(data.get("status_definition_id", ""))

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
	var status_definition: StatusEffectDefinition = get_status_definition()
	if status_definition:
		return DescriptionSegment.nested_segment(
			status_definition.get_effect_name(), status_definition.get_description_segments())
	return DescriptionSegment.text_segment(status_id if status_id != "" else "?")

### "for 3 turns" reads better after targeting ("Apply X to Y for 3 turns") than baked into the
### main phrase ("Apply X for 3 turns to Y") - see EffectIntent.get_trailing_description_segments().
func get_trailing_description_segments() -> Array[DescriptionSegment]:
	if StatusEffectManager.is_duration_persistent(status_duration):
		return [] ### Persistent (duration 0): no "for N turns" to say.
	return DescriptionBuilder.parse_pluralized_template(
		status_duration,
		"EFFECTINTENT_APPLYSTATUSEFFECT_DURATION_TEMPLATE_SINGULAR",
		"EFFECTINTENT_APPLYSTATUSEFFECT_DURATION_TEMPLATE",
		{"duration": str(status_duration)})

func get_referenced_content_ids() -> Dictionary:
	return {"statuses": [status_id]}
