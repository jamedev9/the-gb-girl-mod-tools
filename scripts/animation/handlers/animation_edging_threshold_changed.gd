extends AnimationHandler
class_name Animation_EdgingThresholdChanged

### message key: edging_threshold_changed
### The player's edging threshold changed during the encounter: slides the marker on the player's pleasure bar to the
### new threshold (see MainCardgame._set_player_edging_threshold()). The encounter's first value is set when the
### encounter starts, not through here.

func play_animation(
	fragment: LogFragment,
	entity_registry: EntityRegistry,
	_animation_speed: float) -> void:
	var player_stat_display: PlayerCombatStatDisplay = entity_registry.get_control_node("player")
	if not player_stat_display:
		return
	player_stat_display.set_edging_threshold_pleasure(int(fragment.values["threshold_pleasure"]),true)
