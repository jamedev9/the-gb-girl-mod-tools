@tool
extends Resource
class_name EncounterDifficultyWeights

### Every tunable of the encounter difficulty estimate (see EncounterDifficultyModel). ONE resource shared by the
### prototype and the rework (so both tune the same numbers, and it ships in prototype builds - the rework folders
### don't): resources/encounter_difficulty/encounter_difficulty_weights.tres, loaded with load_shared().
###
### Groups starting with "Table:" change what the offline tool (tools/encounter_difficulty) writes into the
### table - re-run the tool after changing them (the debug log warns when the table is out of date).
### Groups starting with "Rating:" are applied at runtime, on top of the table, and need no re-run.
### All numbers are first guesses: calibrate them against the debug log (debug_output/encounter_difficulty_log.txt).

const SHARED_RESOURCE_PATH: String = "res://resources/encounter_difficulty/encounter_difficulty_weights.tres"

static func load_shared() -> EncounterDifficultyWeights:
	if not ResourceLoader.exists(SHARED_RESOURCE_PATH):
		return null
	return load(SHARED_RESOURCE_PATH) as EncounterDifficultyWeights

@export_group("Table: simulation")
### How many shuffled spawn queues each encounter is simulated with.
@export var simulation_trials: int = 200
@export var simulation_seed: int = 4711
### Safety stop for encounters the simulated player can never finish.
@export var max_simulated_turns: int = 300
### The player-output values (pleasure the player deals per turn) the table is sampled at: a geometric
### grid from min to max. The runtime interpolates between the points.
@export var output_grid_min: float = 15.0
@export var output_grid_max: float = 600.0
@export var output_grid_points: int = 12

@export_group("Table: opponent threat (pleasure per opponent turn)")
### A Move with trigger conditions only fires sometimes - its threat is multiplied by this.
@export_range(0.0, 1.0, 0.05) var conditional_move_chance: float = 0.3
### Statuses that tick or drain for several turns count at most this many turns.
@export var status_turns_cap: int = 3
### How often a passive's retaliation (e.g. Big Black Cock) triggers per turn.
@export_range(0.0, 1.0, 0.05) var passive_retaliation_chance: float = 0.6
### Pleasure-equivalents per use of effects that do not deal pleasure directly:
@export var weight_damage_scaling_move: float = 25.0 ### Pleasure per orgasm / per energy
@export var weight_capture_player_action: float = 20.0
@export var weight_retract_player_actions: float = 25.0
@export var weight_drain_energy_per_point: float = 8.0
@export var weight_add_cards_to_player: float = 8.0
@export var weight_heal_or_cleanse: float = 20.0
@export var weight_buff_other_opponents: float = 25.0
@export var weight_summon_opponent: float = 40.0

@export_group("Table: opponent toughness")
### Passive self-healing (e.g. Mental Control) is worth this many turns of healing per opponent.
@export var regen_lifetime_turns: float = 3.0
### Opponents the player's actions can't touch (e.g. Observer) count as this many times their HP.
@export var immune_to_player_actions_hp_multiplier: float = 3.0

@export_group("Rating: player strength")
### Pleasure per turn from cards, per Energy left over after the actions' upkeep.
@export var spare_energy_pleasure_per_point: float = 4.0

@export_group("Rating: stars")
### The expected pleasure taken is the table's average plus this much of its spread (bad luck counts a bit).
@export var spread_weight: float = 0.5
### Expected pleasure taken / the player's pleasure budget. At or below the first value the score is 1.0, at
### or above the second 5.0, and it moves on a log scale in between (difficulty compounds). The defaults were fitted
### to the whole prototype encounter list (tools/encounter_difficulty/encounter_difficulty_prototype_calibration.tscn):
### roughly its 5th and 95th percentile, giving 3/6/8/9/6 encounters on 1-5 stars for a starting Emily. The absolute
### ratios there are far above 1 because the model's player (no card play) is much weaker than a real one - only the
### spread is meaningful.
@export var ratio_for_one_star: float = 0.6
@export var ratio_for_five_stars: float = 20.0

### Everything in the "Table:" groups. Stored in the table when it is built, so a later change is noticed.
func get_table_settings_snapshot() -> Dictionary:
	return {
		"simulation_trials": simulation_trials,
		"simulation_seed": simulation_seed,
		"max_simulated_turns": max_simulated_turns,
		"output_grid_min": output_grid_min,
		"output_grid_max": output_grid_max,
		"output_grid_points": output_grid_points,
		"conditional_move_chance": conditional_move_chance,
		"status_turns_cap": status_turns_cap,
		"passive_retaliation_chance": passive_retaliation_chance,
		"weight_damage_scaling_move": weight_damage_scaling_move,
		"weight_capture_player_action": weight_capture_player_action,
		"weight_retract_player_actions": weight_retract_player_actions,
		"weight_drain_energy_per_point": weight_drain_energy_per_point,
		"weight_add_cards_to_player": weight_add_cards_to_player,
		"weight_heal_or_cleanse": weight_heal_or_cleanse,
		"weight_buff_other_opponents": weight_buff_other_opponents,
		"weight_summon_opponent": weight_summon_opponent,
		"regen_lifetime_turns": regen_lifetime_turns,
		"immune_to_player_actions_hp_multiplier": immune_to_player_actions_hp_multiplier,
	}

func is_table_settings_snapshot_current(snapshot: Dictionary) -> bool:
	return JSON.stringify(get_table_settings_snapshot(), "", true) == JSON.stringify(snapshot, "", true)
