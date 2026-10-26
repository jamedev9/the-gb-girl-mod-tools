extends AnimationHandler
class_name Animation_OpponentDefeated

const SIGNIFICANCE: float = 1
const POP_SCALE: float = 1.25
const DURATION: float = 0.25

func play_animation(fragment: LogFragment, entity_registry: EntityRegistry,animation_speed:float) -> void:
	#print("Animating opponent defeat")
	var opponent_id: String = fragment.values["opponent_id"]
	var opponents_container: OpponentsContainer = entity_registry.get_control_node("opponents_container")
	var opponent_card: OpponentCard = entity_registry.get_control_node(opponent_id)

	### First, so nothing below (a card that is already gone, ...) can skip it: the remaining-guys counter is moved by this fragment.
	_update_remaining_opponent_counter(fragment, entity_registry)

	var sound_manager: SoundManager = entity_registry.get_control_node("sound_manager")
	var cum_sound_effect: SoundManager.SoundEffects = SoundManager.SoundEffects.CUM_OUTSIDE
	match fragment.values["action_on_opponent"]:
		"vaginal":
			cum_sound_effect = SoundManager.SoundEffects.CUM_INSIDE
		"anal":
			cum_sound_effect = SoundManager.SoundEffects.CUM_INSIDE
	#sound_manager.play_sound_effect(SoundManager.SoundEffects.OPPONENT_ORGASMS)
	sound_manager.play_opponent_orgasm_effect(cum_sound_effect)
	#sound_manager.play_sound_effect(cum_sound_effect)
	if is_instance_valid(opponent_card):
		opponents_container.focus_on_card(opponent_card)
		await AnimationHelper_NodeFlasher._flash_and_fade_node(
			opponent_card,SettingsManager.active_positive_color(),1,POP_SCALE,DURATION*animation_speed,DURATION*animation_speed
		)

	var action_on_opponent: String = fragment.values["action_on_opponent"]

	if action_on_opponent != "":
		var action_hand: FloatingPlayerActionCards = entity_registry.get_control_node("action_card_hand")
		action_hand._on_action_retracted_from_opponent(opponent_id,action_on_opponent)

	_increment_cum_layer_for_player_display(entity_registry)
	if not is_instance_valid(opponent_card):
		return
	opponent_card.active_player_action_id = ""


func _increment_cum_layer_for_player_display(entity_registry: EntityRegistry) -> void:
	var player_stat_display: PlayerCombatStatDisplay = entity_registry.get_control_node("player")
	player_stat_display.increment_number_of_times_cummed_on()

### The remaining-guys counter counts the opponents that still have to be defeated to win: the spawn queue plus the active opponents that
### came out of it (GameState.get_remaining_queued_opponent_count()). It is set when the encounter is set up and from then on moves only
### here, by the defeat fragment, so it follows the animation instead of the game state, which is already ahead. The fragment carries the
### defeated opponent's instance: a summoned opponent (not from the queue) never counted, so its defeat leaves the counter alone.
func _update_remaining_opponent_counter(fragment: LogFragment, entity_registry: EntityRegistry) -> void:
	var defeated_opponent: OpponentInstance = fragment.values.get("opponent_instance", null) as OpponentInstance
	if defeated_opponent == null or not defeated_opponent.spawned_from_spawn_queue:
		return
	var remaining_opponents_counter: RemainingOpponentsCounter = entity_registry.get_control_node("remaining_opponents_counter") as RemainingOpponentsCounter
	if remaining_opponents_counter == null:
		return
	remaining_opponents_counter.decrement_displayed_value()
	AnimationHelper_NodeFlasher._flash_nodes_green([remaining_opponents_counter],SIGNIFICANCE,POP_SCALE,DURATION)
