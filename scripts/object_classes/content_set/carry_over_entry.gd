@tool
extends Resource
class_name CarryOverEntry

### One piece of prototype content confirmed to carry over into the rework (see ContentSet).
### Points straight at the existing resource, so moving/renaming it in the editor keeps the link.
### The prototype's file is never edited: everything below is applied to a copy in Full Rework only.

@export var content: Resource
### Shown instead of the content's own art while in Full Rework mode. Empty = carried over but its
### art hasn't been reworked yet. Only applies to event cards, player actions and opponent types
### for now (the types ImageOverrideManager serves), plus gameplay keywords, where it replaces the
### keyword's icon.
@export var replacement_texture: Texture2D

@export_group("Overrides (Full Rework only)")
### Replaces the content's unlock conditions (rewards; encounters get theirs from ContentSet.encounter_map) with
### the list below, so the rework can chain content differently from the prototype. An empty list with this ticked removes all
### conditions. Ignored (with a warning) for content that lives inside the rework pack folder: edit that
### file directly instead.
@export var override_unlock_conditions: bool = false
@export var unlock_conditions: Array[UnlockCondition] = []
### Full Rework registers this instead of `content` (same id, same type): a copy of the prototype's
### resource, edited for the rework. Keep the copy inside the content set file (an embedded sub-resource,
### not its own .tres in the rework pack folder - the folder scan would register it a second time). Left
### empty = the prototype's resource is used. Ignored (with a warning) for content that lives inside the
### rework pack folder.
@export var replacement_content: Resource
