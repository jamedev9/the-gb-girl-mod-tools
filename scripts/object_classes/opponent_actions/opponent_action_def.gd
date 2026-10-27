@tool
extends ModExportable
class_name OpponentActionDefinition

@export var opponent_action_id: String
@export var move_name: String
@export var description: String
@export var picture: Texture2D
@export var video_tags: Array[VideoClip.ActionTags] = []
@export var log_description: String = ""

@export var only_require_one_condition: bool = false
@export var trigger_conditions: Array[TriggerCondition] = []

@export var effect_intents: Array[EffectAndTargetIntent]

### True for a Move loaded from a mod: its name and description are shown as written, never through tr().
### @export_storage (stored, not shown in the Inspector) so duplicate() keeps it. The hand-written to_json_dict() never writes it.
@export_storage var is_modded: bool = false

func get_action_name() -> String:
	if is_modded:
		return move_name
	return tr("OPPONENTACTIONDEFINITION_"+opponent_action_id.to_upper()+"_MOVE_NAME")
func get_action_description() -> String:
	if is_modded:
		return description
	return tr("OPPONENTACTIONDEFINITION_"+opponent_action_id.to_upper()+"_DESCRIPTION")

func get_translation_entries() -> Array[Dictionary]:
	if is_modded:
		return [] ### Mod text is shown as written, and must not be written into game.csv by the editor's auto-localization.
	var prefix: String = "OPPONENTACTIONDEFINITION_"+opponent_action_id.to_upper()
	return [
		{"key": prefix+"_MOVE_NAME", "text": move_name},
		{"key": prefix+"_DESCRIPTION", "text": description},
	]

### Generic description support (see DescriptionBuilder) - same effect_intents shape as
### EventCardDefinition (EffectAndTargetIntent.describe_all() covers the whole thing on its
### own), plus an optional gate: most opponent actions have no trigger_conditions and always
### resolve when performed, but a couple (e.g. Force Deepthroat) only actually do anything if a
### condition holds at resolution time (see should_action_fire()) - those get the same
### "When {condition}: {effect}." composition passives/statuses use for their own triggers
### (DescriptionBuilder.describe_when_then(), TriggerCondition.describe_conditions() - identical
### trigger_conditions/only_require_one_condition shape). Falls back to the hand-written
### description field if effect_intents somehow produces nothing.
func get_description_segments() -> Array[DescriptionSegment]:
	var effect_segments: Array[DescriptionSegment] = EffectAndTargetIntent.describe_all(effect_intents)
	if effect_segments.is_empty():
		return get_hand_written_description_segments()
	if trigger_conditions.is_empty():
		return effect_segments
	var when_segments: Array[DescriptionSegment] = TriggerCondition.describe_conditions(trigger_conditions, only_require_one_condition)
	return DescriptionBuilder.describe_when_then(when_segments, effect_segments)

### The hand-written description as segments: its {KEYWORD} and {STATUS:id}-style tokens become hover links (see
### DescriptionBuilder.parse_template() and DescriptionTerms). Show this with DescriptionLabel.show_segments(), never the raw string.
func get_hand_written_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		get_action_description(), {}, DescriptionTerms.card_permanence_hints(effect_intents))

func get_video_tags():
	return video_tags

func get_player_actions_grabbed() -> Array[String]:
	var player_action_ids: Array[String] = []
	for intent in effect_intents:
		if intent.effect_intent is Intent_CapturePlayerAction:
			var action_id: String = intent.effect_intent.player_action_id
			player_action_ids.append(action_id)
		
	return player_action_ids

func should_action_fire(
	input_context: EffectContext,
	game_state: GameState,
	save_game_state: SaveGameState,
	owner_of_trigger: TargetEntity) -> bool:
		var conditions_met: int = 0
		#print("Runnin should_component_trigger for %s"%trigger_component_id)
		if trigger_conditions.is_empty():
			#print("No trigger conditions - returning false")
			return true
		for condition in trigger_conditions:
			if condition.is_condition_met(input_context,game_state,save_game_state,owner_of_trigger):
				#print("Found contition that is not met, returning false.")
				conditions_met += 1
		
		if only_require_one_condition and conditions_met >= 1:
			#print("trigger %s only needs one condition, this is met, returning true"%trigger_component_id)
			return true
		if not only_require_one_condition and conditions_met == trigger_conditions.size():
			#print("trigger %s has all its conditions met, returning true"%trigger_component_id)
			return true
		#print("Trigger is not met, returning false")
		return false

### The registered content this Move's effects hand out or act with (kind -> ids, see EffectIntent.get_referenced_content_ids()).
### A mod Move naming something that isn't installed is skipped on load.
func get_referenced_content_ids() -> Dictionary:
	return EffectAndTargetIntent.collect_referenced_content_ids(effect_intents)

#region Mod export
func get_mod_export_subfolder() -> String:
	return "opponent_actions"

func get_file_reference_fields() -> Dictionary:
	return {"picture": "images"}

### Hand-written rather than the generic ModExportable default because picture: Texture2D is a file reference (see
### get_file_reference_fields()), like StatusEffectDefinition. video_tags are written by name. The trigger conditions and
### effects serialize through their own (generic) to_json_dict().
func to_json_dict() -> Dictionary:
	var video_tag_names: Array = []
	for tag in video_tags:
		video_tag_names.append(VideoClip.ActionTags.keys()[tag])
	var condition_dicts: Array = []
	for condition in trigger_conditions:
		if condition:
			condition_dicts.append(condition.to_json_dict())
	var intent_dicts: Array = []
	for intent in effect_intents:
		if intent:
			intent_dicts.append(intent.to_json_dict())

	return {
		"_class": get_script().get_global_name(),
		"opponent_action_id": opponent_action_id,
		"move_name": move_name,
		"description": description,
		"log_description": log_description,
		"picture": ModExportable.resolve_to_res_path(picture.resource_path, resource_path) if picture else "",
		"video_tags": video_tag_names,
		"only_require_one_condition": only_require_one_condition,
		"trigger_conditions": condition_dicts,
		"effect_intents": intent_dicts,
	}

### mod_folder_path: the mod's images folder (resolves picture, see get_file_reference_fields()). Conditions and effects
### are rebuilt through ModdableResourceRegistry.instantiate() from their "_class" tags.
static func from_json_dict(data: Dictionary, mod_folder_path: String = "") -> OpponentActionDefinition:
	var action_def: OpponentActionDefinition = OpponentActionDefinition.new()
	action_def.opponent_action_id = str(data.get("opponent_action_id", ""))
	action_def.move_name = str(data.get("move_name", ""))
	action_def.description = str(data.get("description", ""))
	action_def.log_description = str(data.get("log_description", ""))
	action_def.only_require_one_condition = bool(data.get("only_require_one_condition", false))

	for tag_name in data.get("video_tags", []):
		var tag_key: String = ModExportable.find_case_insensitive_enum_key(VideoClip.ActionTags.keys(), str(tag_name))
		if tag_key != "":
			action_def.video_tags.append(VideoClip.ActionTags[tag_key])

	var picture_file_name: String = data.get("picture", "")
	if picture_file_name != "" and mod_folder_path != "":
		action_def.picture = Utils.load_texture_from_path(mod_folder_path.path_join(picture_file_name))

	for condition_data in data.get("trigger_conditions", []):
		var condition: TriggerCondition = ModdableResourceRegistry.instantiate(condition_data) as TriggerCondition
		if condition:
			action_def.trigger_conditions.append(condition)
	for intent_data in data.get("effect_intents", []):
		var intent: EffectAndTargetIntent = ModdableResourceRegistry.instantiate(intent_data) as EffectAndTargetIntent
		if intent:
			action_def.effect_intents.append(intent)

	return action_def
#endregion
