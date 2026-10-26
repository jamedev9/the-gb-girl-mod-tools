@tool
extends Resource
class_name OpponentAppearanceList

### The appearances (modular rework art) the opponents of one opponent type pick from in Full Rework.
### Lives in the ContentSet (opponent_appearances, keyed by opponent_type_id) instead of on the
### OpponentType's own file, because the prototype's files must never reference rework art - the
### prototype builds don't ship it. AutoloadDatabase puts these on a copy of the opponent type while
### registering it in Full Rework.

@export var appearances: Array[OpponentAppearance] = []
