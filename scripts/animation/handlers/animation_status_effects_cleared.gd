extends AnimationHandler
class_name Animation_StatusEffectsCleared

### message key: status_effects_cleared
### Statuses were cleared from the player (MainCardgame._remove_statuses_from_target()): their icons flash, fade out and are freed, at the
### moment the clearing happens in the animation queue instead of waiting for the next UI refresh. Not awaited, so the icons fade while the
### queue goes on. Only the player's icons so far; a Partner's statuses cleared this way are not announced.

const SIGNIFICANCE: float = 1.0
const STATUS_ICON_FLASH_DURATION: float = 0.3
const STATUS_ICON_FADE_DURATION: float = 0.5
const STATUS_ICON_POP_SCALE: float = 1.3

func play_animation(
	fragment: LogFragment,
	entity_registry: EntityRegistry,
	animation_speed: float) -> void:
	var player_status_effects_display: PlayerStatusEffectsDisplay = entity_registry.get_control_node("player_status_effects_display")
	if not player_status_effects_display:
		return
	for status_id in fragment.values.get("status_ids", []):
		var status_display: StatusEffectMiniDisplay = player_status_effects_display.take_display_for_status(status_id)
		if status_display:
			flash_fade_and_free_status_icon(status_display,status_id,animation_speed)

### Flashes the icon (red for a buff that is lost, green for a debuff that is), fades it out and frees it. Also used by the orgasm
### animation for the statuses an orgasm ends (Animation_PlayerOrgasmed).
static func flash_fade_and_free_status_icon(
	status_display: StatusEffectMiniDisplay, status_id: String, animation_speed: float) -> void:
	var status_def: StatusEffectDefinition = AutoloadDatabase.get_status_effect_by_id(status_id)
	var flash_color: Color = SettingsManager.active_negative_color()
	if status_def and status_def.status_category == StatusEffectDefinition.StatusCategory.DEBUFF:
		flash_color = SettingsManager.active_positive_color()
	await AnimationHelper_NodeFlasher._flash_and_fade_node(
		status_display,
		flash_color,
		SIGNIFICANCE,
		STATUS_ICON_POP_SCALE,
		STATUS_ICON_FLASH_DURATION*animation_speed,
		STATUS_ICON_FADE_DURATION*animation_speed)
	if is_instance_valid(status_display):
		status_display.queue_free()
