extends RefCounted
class_name TurnStepSystem

### The central list of steps in the turn cycle. MainCardgame._enter_turn_step() sends one as an EffectContext (EffectContext.turn_step)
### each time the game enters it, through the normal pipeline, so a passive/status/Player Action can react with
### TriggerCondition_AtTurnStep. New steps: add a value here, a "TRIGGERCONDITION_ATTURNSTEP_<NAME>" text in game.csv (en + chi) and a
### _enter_turn_step() call where the game gets there. Only a list of values: it keeps no state (the coarse phase, player's turn vs the
### Partners', is GameState.current_game_phase).
###
### The order in a round, with where each is sent (MainCardgame._end_player_turn() / _start_player_turn()):
###   END_OF_PLAYER_TURN      the player's turn ends (End Turn button or EndPlayerTurn), still the player's phase
###   START_OF_OPPONENTS_TURN the phase has just become the Partners'; they have not acted yet
###   END_OF_OPPONENTS_TURN   the Partners have acted (and the room has been refilled); the phase is still theirs
###   START_OF_PLAYER_TURN    the phase has just become the player's: round + 1, round banner, energy restored
###   START_OF_DRAW_STEP      inside the player's turn, just before the hand is refilled
###   END_OF_DRAW_STEP        the hand has been refilled; the player acts next
### The very first turn of an encounter sends START_OF_PLAYER_TURN, START_OF_DRAW_STEP and END_OF_DRAW_STEP too, after the opening hand
### has been dealt (that draw happens while the encounter is set up).
enum TurnStep {
	START_OF_PLAYER_TURN,
	START_OF_DRAW_STEP,
	END_OF_DRAW_STEP,
	END_OF_PLAYER_TURN,
	START_OF_OPPONENTS_TURN,
	END_OF_OPPONENTS_TURN,
}

### EffectContext.turn_step of every context that is not a step (an int rather than a TurnStep value, so the enum has no "none").
const NO_STEP: int = -1

### The step's name as written above ("END_OF_DRAW_STEP"): the end of its translation key and handy in logs.
static func get_step_name(step: TurnStep) -> String:
	return TurnStep.keys()[step]
