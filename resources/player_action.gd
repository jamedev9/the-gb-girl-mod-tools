@tool
extends ModExportable
class_name PlayerAction

@export var action_id: String
@export var action_name: String
@export var picture: Texture2D
@export var opponent_art_parts: Array[ArtPart] = [] ### Layers drawn over the reworked opponent card's visuals while active

@export var move_energy: int
@export var energy_per_round: int

### What this action does each round it's active on an opponent, same shape as
### OpponentActionDefinition/EventCardDefinition. Convention for authored actions: intents that act
### on the opponent the action is placed on use targeting_intent SINGLE_OPPONENT - an action's
### effects resolve against whichever opponent it's being triggered on (see
### MainCardgame._resolve_effects_of_player_action(), which supplies it as dropped_on_opponent), which
### isn't always the one it's assigned to (e.g. Double Vaginal triggers Vaginal on a different opponent).
@export var effect_intents: Array[EffectAndTargetIntent] = []

### Reactions while this action is active on an opponent (assigned to one), same shape as a passive/status's
### triggered components: when a trigger condition is met by an effect that just resolved, the component's
### effect_intents run (EffectContextManager._trigger_active_player_actions()). The source of such a reaction
### is the player. To make the action trigger itself, use an ApplyEffectOfPlayerAction intent for this
### action_id with the RULE_BASED targeting rule TargetsHaveOneOfSeveralActionsAssigned([action_id]).
### Read a save's version via SaveGameState.get_effective_player_action(): a save can have its own list.
@export var triggered_components: Array[StatusTriggeredComponent] = []

### Not read by any code yet (the Reward Cards an Action gives come from the save's unlocks, see
### Reward_UnlockRewardCardForActions). Cards by card_type_id, like the rest of the game names content.
@export var reward_card_ids: Array[String] = []

@export var video_action_tags: Array[VideoClip.ActionTags] = []
@export var log_text_when_started: String = ""
@export var log_text_when_ended: String = ""

@export var looping_sound_category: SoundManager.LoopingCategory = SoundManager.LoopingCategory.NONE
@export var start_sound_effect: SoundManager.SoundEffects = SoundManager.SoundEffects.NONE

### True for an Action loaded from a mod: its name and log text are shown as written, never through tr().
### @export_storage so duplicate() keeps it (a save's effective Action is a copy); never written to JSON.
@export_storage var is_modded: bool = false

func _validate_property(property: Dictionary) -> void:
	ContentIdSuggestions.apply_to_array_property(property, "reward_card_ids", "EventCardDefinition", "card_type_id")

### The Pleasure number shown on the action card - derived from effect_intents the same way the
### opponent card derives its upcoming-action number, except Pleasure the action gives the player
### (a PLAYER-targeted intent) isn't part of it.
func get_displayed_damage() -> int:
	return EffectAndTargetIntent.sum_displayed_damage(effect_intents, true)

### Statuses shown as icons on the action card.
func get_displayed_statuses() -> Array[ApplyStatusEffect]:
	var statuses: Array[ApplyStatusEffect] = []
	for intent in effect_intents:
		if intent and intent.effect_intent is ApplyStatusEffect:
			statuses.append(intent.effect_intent)
	return statuses

### Generated description of everything this action does. What it does each
### round first, then a Triggers section ("When {condition}: {effect}.") if it reacts to anything.
func get_description_segments() -> Array[DescriptionSegment]:
	var segments: Array[DescriptionSegment] = EffectAndTargetIntent.describe_all(effect_intents)
	if triggered_components.is_empty():
		return segments
	var trigger_lines: Array = []
	for component in triggered_components:
		trigger_lines.append(EffectDefinition.trigger_line(component.get_when_description_segments(), component.effect_intents))
	if not segments.is_empty():
		segments.append(DescriptionSegment.text_segment("\n\n"))
	segments.append_array(EffectDefinition.tooltip_section("EFFECTDEFINITION_TRIGGERS_HEADER", trigger_lines))
	return segments

func get_action_name() -> String:
	if is_modded:
		return action_name
	return tr("PLAYERACTION_"+action_id.to_upper()+"_ACTION_NAME")

func get_log_text_when_started() -> String:
	if is_modded:
		return log_text_when_started
	return tr("PLAYERACTION_"+action_id.to_upper()+"_LOG_TEXT_WHEN_STARTED")

func get_translation_entries() -> Array[Dictionary]:
	if is_modded:
		return [] ### Mod text is shown as written, and must not be written into game.csv by the editor's auto-localization.
	var entries: Array[Dictionary] = [
		{"key": "PLAYERACTION_"+action_id.to_upper()+"_ACTION_NAME", "text": action_name},
	]
	if log_text_when_started != "":
		entries.append({"key": "PLAYERACTION_"+action_id.to_upper()+"_LOG_TEXT_WHEN_STARTED", "text": log_text_when_started})
	return entries

### The registered content this Action's effects and triggers hand out or act with (kind -> ids, see
### EffectIntent.get_referenced_content_ids()). A mod Action naming something that isn't installed is skipped on load.
### reward_card_ids is left out: a missing Reward Card is only dropped.
func get_referenced_content_ids() -> Dictionary:
	var intents: Array = effect_intents.duplicate()
	for component in triggered_components:
		if component:
			intents.append_array(component.effect_intents)
	return EffectAndTargetIntent.collect_referenced_content_ids(intents)

#region Mod export
func get_mod_export_subfolder() -> String:
	return "actions"

func get_file_reference_fields() -> Dictionary:
	return {"picture": "images"}

### Hand-written: picture is a file (see get_file_reference_fields()), the enums are written by name, effects and triggers
### through their own (generic) to_json_dict(). Left out: opponent_art_parts (the rework's layered art, not moddable yet).
func to_json_dict() -> Dictionary:
	var intent_dicts: Array = []
	for intent in effect_intents:
		if intent:
			intent_dicts.append(intent.to_json_dict())
	var trigger_dicts: Array = []
	for component in triggered_components:
		if component:
			trigger_dicts.append(component.to_json_dict())
	var tag_names: Array = []
	for tag in video_action_tags:
		tag_names.append(VideoClip.ActionTags.keys()[tag])
	return {
		"_class": get_script().get_global_name(),
		"action_id": action_id,
		"action_name": action_name,
		"picture": ModExportable.resolve_to_res_path(picture.resource_path, resource_path) if picture else "",
		"move_energy": move_energy,
		"energy_per_round": energy_per_round,
		"effect_intents": intent_dicts,
		"triggered_components": trigger_dicts,
		"reward_card_ids": Array(reward_card_ids),
		"video_action_tags": tag_names,
		"log_text_when_started": log_text_when_started,
		"log_text_when_ended": log_text_when_ended,
		"looping_sound_category": SoundManager.LoopingCategory.keys()[looping_sound_category],
		"start_sound_effect": SoundManager.SoundEffects.keys()[start_sound_effect],
	}

### mod_folder_path: the mod's images folder (resolves picture). Effects and triggers are rebuilt through
### ModdableResourceRegistry.instantiate() from their "_class" tags.
static func from_json_dict(data: Dictionary, mod_folder_path: String = "") -> PlayerAction:
	var action: PlayerAction = PlayerAction.new()
	action.action_id = str(data.get("action_id", ""))
	action.action_name = str(data.get("action_name", ""))
	action.move_energy = int(data.get("move_energy", 0))
	action.energy_per_round = int(data.get("energy_per_round", 0))
	action.log_text_when_started = str(data.get("log_text_when_started", ""))
	action.log_text_when_ended = str(data.get("log_text_when_ended", ""))
	for intent_data in data.get("effect_intents", []):
		var intent: EffectAndTargetIntent = ModdableResourceRegistry.instantiate(intent_data) as EffectAndTargetIntent
		if intent:
			action.effect_intents.append(intent)
	for component_data in data.get("triggered_components", []):
		var component: StatusTriggeredComponent = ModdableResourceRegistry.instantiate(component_data) as StatusTriggeredComponent
		if component:
			action.triggered_components.append(component)
	for card_id in data.get("reward_card_ids", []):
		action.reward_card_ids.append(str(card_id))
	for tag_name in data.get("video_action_tags", []):
		var tag_key: String = ModExportable.find_case_insensitive_enum_key(VideoClip.ActionTags.keys(), str(tag_name))
		if tag_key != "":
			action.video_action_tags.append(VideoClip.ActionTags[tag_key])
	var looping_key: String = ModExportable.find_case_insensitive_enum_key(SoundManager.LoopingCategory.keys(), str(data.get("looping_sound_category", "")))
	if looping_key != "":
		action.looping_sound_category = SoundManager.LoopingCategory[looping_key]
	var start_key: String = ModExportable.find_case_insensitive_enum_key(SoundManager.SoundEffects.keys(), str(data.get("start_sound_effect", "")))
	if start_key != "":
		action.start_sound_effect = SoundManager.SoundEffects[start_key]
	var picture_file_name: String = str(data.get("picture", ""))
	if picture_file_name != "" and mod_folder_path != "":
		action.picture = Utils.load_texture_from_path(mod_folder_path.path_join(picture_file_name))
	return action
#endregion
