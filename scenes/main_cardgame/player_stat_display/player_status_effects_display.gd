extends Cardgame_UI_Element
class_name PlayerStatusEffectsDisplay

@export var container_for_status_displays: Container
@export var status_mini_display_scene: PackedScene = preload("res://scenes/main_cardgame/status_effects/status_effect_mini_display.tscn")
@export var passive_effect_mini_display: PackedScene = preload("res://scenes/main_cardgame/passive_effect_mini_display/passive_effect_mini_display.tscn")

var displayed_passives: Dictionary[String, PassiveEffectMiniDisplay] = {}
var displayed_statuses: Dictionary[String, StatusEffectMiniDisplay] = {}

func update_class_specific_displays(game_state: GameState) -> void:
	_handle_player_passive_effects(game_state)
	_handle_active_status_effects(game_state)

func _handle_player_passive_effects(game_state: GameState) -> void:
	### Passives have no dedicated add-animation (only animation_remove_passive_effect_from_player.gd
	### exists), so wiping and rebuilding them here is safe - there's no competing path that could
	### already be displaying one.
	for child in container_for_status_displays.get_children():
		if child is PassiveEffectMiniDisplay:
			child.queue_free()
	displayed_passives.clear()
	var player_passives: Array = game_state.get_active_player_passives()
	for passive_id in player_passives:
		var passive: PassiveEffectDefinition = AutoloadDatabase.get_passive_effect_def(passive_id)
		if passive == null or passive.hidden_from_player: ### null = not in the game (e.g. a disabled mod's passive)
			continue
		var new_mini_display: PassiveEffectMiniDisplay = passive_effect_mini_display.instantiate()
		new_mini_display.display_passive(passive)
		container_for_status_displays.add_child(new_mini_display)
		displayed_passives[passive_id] = new_mini_display

### Diffs against game_state instead of wiping and rebuilding every status display, so this
### doesn't fight with animation_status_effect_applied_to_target.gd/refresh_status_on_target.gd,
### which add/update a status's display directly the moment its animation plays (well before
### this runs - game_state_changed only fires once that action's whole animation queue has
### drained). Update-in-place if already displayed (regardless of whether the animation path or
### this same function added it - see add_status_display_as_child()), add only if genuinely
### missing (a safety net for anything that doesn't go through the normal animated-apply path),
### remove only what's no longer in game_state (this is also the only place status removal ever
### happens - there's no dedicated removal animation).
func _handle_active_status_effects(game_state: GameState) -> void:
	var active_statuses: Dictionary = game_state.get_player_statuses()
	for status_id in displayed_statuses.keys().duplicate():
		if not active_statuses.has(status_id):
			displayed_statuses[status_id].queue_free()
			displayed_statuses.erase(status_id)
	for status_id in active_statuses.keys():
		var status_duration: int = active_statuses[status_id]["duration"]
		var status_stacks: int = active_statuses[status_id]["stacks"]
		if displayed_statuses.has(status_id):
			displayed_statuses[status_id].set_displayed_duration(status_duration)
			displayed_statuses[status_id].set_displayed_stacks(status_stacks)
			continue
		var status_display: StatusEffectMiniDisplay = StatusEffectMiniDisplay.new_status_display(status_id,status_duration,status_stacks)
		add_status_display_as_child(status_display)

func get_display_for_status(status_id: String) -> StatusEffectMiniDisplay:
	return displayed_statuses.get(status_id, null)

### Hands over a status's icon and forgets it, for an animation that takes the icon away (see
### Animation_PlayerOrgasmed). The node stays in the container until that animation frees it; forgetting it here means
### a status applied again while it fades out gets an icon of its own instead of reusing the fading one.
func take_display_for_status(status_id: String) -> StatusEffectMiniDisplay:
	var status_display: StatusEffectMiniDisplay = displayed_statuses.get(status_id, null)
	displayed_statuses.erase(status_id)
	return status_display

func add_status_display_as_child(status_display: StatusEffectMiniDisplay) -> void:
	container_for_status_displays.add_child(status_display)
	if status_display.represented_status_effect:
		displayed_statuses[status_display.represented_status_effect.status_id] = status_display

func get_energy_drain_from_displayed_statuses() -> int:
	var drain: int = 0
	for child in container_for_status_displays.get_children():
		if child is StatusEffectMiniDisplay:
			var status_def: StatusEffectDefinition = child.represented_status_effect
			for effect_component in status_def.status_effect_components:
				if effect_component is Status_ReducePlayerEnergy:
					drain += effect_component.energy_reduction
	return drain

func get_passive_from_id(passive_id: String) -> PassiveEffectMiniDisplay:
	if passive_id in displayed_passives.keys():
		return displayed_passives[passive_id]
	return null
