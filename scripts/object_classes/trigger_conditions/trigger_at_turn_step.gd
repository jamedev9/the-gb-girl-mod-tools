@tool
extends TriggerCondition
class_name TriggerCondition_AtTurnStep

### Met when the game enters one step of the turn cycle (see TurnStepSystem): "when your draw step ends", "when your turn starts"...
### The step is picked in the inspector.

@export var step: TurnStepSystem.TurnStep = TurnStepSystem.TurnStep.START_OF_PLAYER_TURN

func is_condition_met(
	input_context: EffectContext,
	_game_state: GameState
	,_save_game_state: SaveGameState,
	_owner_of_trigger: TargetEntity) -> bool:
		return input_context.turn_step == step

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(tr("TRIGGERCONDITION_ATTURNSTEP_" + TurnStepSystem.get_step_name(step)))
