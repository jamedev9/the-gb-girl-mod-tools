extends AnimationHandler
class_name Animation_PlayerOrgasmed

### message key: player_HP_changed

const strength: float = 10.0
const duration: float = 5
const steps: int = 9

const SIGNIFICANCE: float = 1.0

const FLASH_DURATION:  float = 0.5
const FLASH_SCALE: float = 1.4

const REFILL_DURATION: float = 1

func play_animation(
	fragment: LogFragment, 
	entity_registry: EntityRegistry,
	animation_speed: float) -> void:
	#print("Animating fragment with message: %s"%fragment.message_key)
	
	#var hp_reduction: int = _fragment.values["hp_reduction"]s
	var sound_manager: SoundManager = entity_registry.get_control_node("sound_manager")
	var sound_effect: SoundManager.SoundEffects = SoundManager.SoundEffects.PLAYER_ORGASMS
	sound_manager.play_sound_effect(sound_effect,5.0)
	
	var player_stat_display: PlayerCombatStatDisplay = entity_registry.get_control_node("player")
	
	
	### One fragment covers every orgasm that happened together (hp_reduction): both counters move by that many.
	var nr_of_orgasms: int = int(fragment.values.get("hp_reduction",1))
	_flash_orgasm_counter(player_stat_display)
	_decrement_remaining_orgasms_counter(player_stat_display,nr_of_orgasms)
	_increment_orgasms_counter(player_stat_display,nr_of_orgasms)
	_remove_status_icons_ended_by_orgasm(fragment,entity_registry,animation_speed)
	_drain_pleasure_bar(player_stat_display)
	await _shake_player_card(player_stat_display)
	await _refill_pleasure_bar(player_stat_display,fragment,animation_speed)



### Statuses the orgasm itself ended (fragment value "statuses_removed", e.g. Edging - see
### MainCardgame._trigger_n_player_orgasms()) lose their icon right as the orgasm starts, together with the bar draining,
### instead of waiting for the next UI refresh. Not awaited, like the bar drain.
func _remove_status_icons_ended_by_orgasm(
	fragment: LogFragment, entity_registry: EntityRegistry, animation_speed: float) -> void:
	var player_status_effects_display: PlayerStatusEffectsDisplay = entity_registry.get_control_node("player_status_effects_display")
	if not player_status_effects_display:
		return
	for status_id in fragment.values.get("statuses_removed", []):
		var status_display: StatusEffectMiniDisplay = player_status_effects_display.take_display_for_status(status_id)
		if status_display:
			Animation_StatusEffectsCleared.flash_fade_and_free_status_icon(status_display,status_id,animation_speed)

func _shake_player_card(player_stat_display: PlayerCombatStatDisplay) -> void:
	await AnimationHelper_NodeShaker.shake_node(player_stat_display,strength,duration,steps)

func _flash_orgasm_counter(player_stat_display: PlayerCombatStatDisplay) -> void:
	var orgasm_counter_node: OrgasmIcon = player_stat_display.get_orgasm_counter()
	AnimationHelper_NodeFlasher._flash_nodes_red([orgasm_counter_node],SIGNIFICANCE,FLASH_SCALE,FLASH_DURATION)

func _decrement_remaining_orgasms_counter(player_stat_display: PlayerCombatStatDisplay,nr_of_orgasms: int) -> void:
	player_stat_display.decrement_hp_value(nr_of_orgasms)

func _increment_orgasms_counter(player_stat_display: PlayerCombatStatDisplay,nr_of_orgasms: int) -> void:
	player_stat_display.increment_orgasm_counter(nr_of_orgasms)

func _drain_pleasure_bar(player_stat_display: PlayerCombatStatDisplay) -> void:
	await player_stat_display.drain_pleasure_bar()

func _refill_pleasure_bar(player_stat_display: PlayerCombatStatDisplay,fragment: LogFragment,animation_speed:float) -> void:
	var pleasure_after_orgasm: int = fragment.values["spillover_damage"]
	await player_stat_display.animate_pleasure_bar_to_value(pleasure_after_orgasm,REFILL_DURATION*animation_speed*pleasure_after_orgasm/player_stat_display.pleasure_bar.max_pleasure)
