extends RefCounted
class_name PleasurePreviewHit

### One piece of Pleasure an effect would give or take away right now (see PleasurePreview).

### Who gets it. null = not known yet (see PleasurePreview, "Targets"): only the giver's own modifiers are in the amount.
var target: TargetEntity
### After every modifier and the game's rounding: what the game would really apply. Never negative, is_healing says which way.
var amount: int = 0
### Before any modifier (but after counting, for effects like "5 Pleasure per energy"): what a live number is compared with to
### pick its color.
var base_amount: int = 0
### For an effect counted per something (EffectIntent.is_pleasure_counted(): per Energy, per Orgasm ...): what ONE unit gives after
### modifiers, and before (the number its text states). For any other effect the same as amount / base_amount.
var per_unit_amount: int = 0
var per_unit_base_amount: int = 0
### True: takes Pleasure away (healing). False: gives Pleasure.
var is_healing: bool = false
### The intent that gives it. For a triggered Action: the Action's own intent.
var effect_and_target_intent: EffectAndTargetIntent
### The "Trigger X" intent it came from (ApplyEffectOfPlayerAction), null when the effect gives it directly.
var trigger_intent: EffectAndTargetIntent

func is_on_player() -> bool:
	return target is PlayerEntity

func get_opponent_id() -> String:
	if target is OpponentEntity:
		return target.opponent_id
	return ""

### For a card played several times at once (Ctrl, FloatingPlayerHand.get_play_count()): the whole hit, count times. The per-unit
### amounts stay as they are: they describe one unit of one card ("5 Pleasure per Energy").
func multiply(count: int) -> void:
	amount *= count
	base_amount *= count

### What it does to the target's Pleasure: negative when it takes Pleasure away.
func get_pleasure_change() -> int:
	return -amount if is_healing else amount

func get_base_pleasure_change() -> int:
	return -base_amount if is_healing else base_amount

### How the modifiers change this hit, seen from the player: above 0 better for the player (a Partner gets more Pleasure, the player
### less), below 0 worse, 0 no change. per_unit: compare the per-unit amounts instead of the totals.
func get_change_for_player(per_unit: bool = false) -> int:
	var after: int = per_unit_amount if per_unit else amount
	var before: int = per_unit_base_amount if per_unit else base_amount
	var difference: int = after - before
	if is_healing:
		difference = -difference
	return -difference if is_on_player() else difference
