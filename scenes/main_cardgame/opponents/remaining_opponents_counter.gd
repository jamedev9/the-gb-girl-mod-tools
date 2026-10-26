extends Cardgame_UI_Element
class_name RemainingOpponentsCounter

### The number of opponents still to be defeated to win: what is left in the spawn queue plus the active opponents that came out of it
### (GameState.get_remaining_queued_opponent_count()); summoned opponents don't count, they don't count towards the win either.
### It is set once when an encounter is set up (MainCardgame._show_remaining_opponents_count()) and from then on it only moves with the
### animation of each opponent_defeated fragment (Animation_OpponentDefeated). It is NOT re-read from the game state on every refresh:
### the game state is already ahead of the animations, so that would let the number jump before the defeat is shown.

@export var label_for_value: Label

func show_remaining_opponents(game_state: GameState) -> void:
	label_for_value.text = str(game_state.get_remaining_queued_opponent_count())

func decrement_displayed_value() -> void:
	Utils.add_delta_to_displayed_integer_value(label_for_value,-1)
