@tool
extends Resource
class_name GameplayKeyword

### A core piece of game vocabulary (Pleasure, Energy, Duration, Opponent, ...) that generated
### descriptions can reference by id. keyword_id is the internal, code-facing name and never
### changes; display_name is the player-facing word and is free to be renamed/reworded/retranslated
### independently (e.g. "Opponent" -> "Partner") without touching any code that generates
### descriptions - those only ever reference the keyword_id.
@export var keyword_id: String
@export var display_name: String
@export var color: Color = Color.WHITE
@export var icon: Texture2D
### One-line vocabulary definition shown as the hover tooltip for this keyword (see
### DescriptionRenderer._render_keyword()). Optional - a keyword with no description just
### falls back to showing its display_name again.
@export_multiline var description: String

func get_display_name() -> String:
	return tr("GAMEPLAYKEYWORD_"+keyword_id.to_upper()+"_DISPLAY_NAME")

func get_description() -> String:
	if description.is_empty():
		return get_display_name()
	return tr("GAMEPLAYKEYWORD_"+keyword_id.to_upper()+"_DESCRIPTION")

func get_translation_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = [
		{"key": "GAMEPLAYKEYWORD_"+keyword_id.to_upper()+"_DISPLAY_NAME", "text": display_name},
	]
	if not description.is_empty():
		entries.append({"key": "GAMEPLAYKEYWORD_"+keyword_id.to_upper()+"_DESCRIPTION", "text": description})
	return entries
