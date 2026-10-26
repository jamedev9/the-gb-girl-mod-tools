extends RefCounted
class_name DifficultyStarRow

### A row of 1-5 difficulty stars, shared by every view that shows an encounter's difficulty (MapEncounterNode,
### EncounterDescriptionDisplay). The view hands over its first star (a TextureRect inside an HBoxContainer); that
### star is the template, so whatever it looks like in the editor is what every star looks like, and its parent is
### the row. Extra stars are copied from it once, the first time a higher count is needed, then only shown / hidden
### (tiling one TextureRect doesn't work: the star PNG is 512 px and tiles draw at native size).

var _template_star: TextureRect
var _stars: Array[TextureRect] = []

func _init(template_star: TextureRect) -> void:
	_template_star = template_star

### How many stars a view should show for the encounter: 0 = none (feature off, the view's own toggle off, no
### encounter, or no rating). debug_preview_count (debug builds only) forces a count whatever the rating is.
static func get_star_count(
		meta_game: Node, encounter_def: EncounterDefinition, view_shows_stars: bool, debug_preview_count: int) -> int:
	if not EncounterDifficultySettings.ENABLED or not view_shows_stars:
		return 0
	if encounter_def == null or meta_game == null:
		return 0
	if OS.is_debug_build() and debug_preview_count > 0:
		return debug_preview_count
	return meta_game.get_encounter_difficulty_stars(encounter_def.encounter_id)

### Shows exactly count stars (0 hides the whole row).
func show_count(count: int) -> void:
	if _template_star == null or not is_instance_valid(_template_star):
		return
	var star_row: Control = _template_star.get_parent() as Control
	if star_row == null:
		return
	if _stars.is_empty():
		_stars.append(_template_star)
	star_row.visible = count > 0
	if count <= 0:
		return
	while _stars.size() < count:
		var extra_star: TextureRect = _template_star.duplicate() as TextureRect
		star_row.add_child(extra_star)
		_stars.append(extra_star)
	for star_index in _stars.size():
		_stars[star_index].visible = star_index < count
