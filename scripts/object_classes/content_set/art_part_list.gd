@tool
extends Resource
class_name ArtPartList

### The art parts drawn over the rework opponent card while one player action is active on it.
### Lives in the ContentSet (player_action_art_parts, keyed by action_id) instead of on the
### PlayerAction's own file, because the prototype's files must never reference rework art - the
### prototype builds don't ship it. AutoloadDatabase puts these on the player action while
### registering it in Full Rework.

@export var parts: Array[ArtPart] = []
