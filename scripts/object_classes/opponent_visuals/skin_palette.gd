@tool
extends Resource
class_name SkinPalette

### Recolours the skin layers of the opponent art (parts with use_skin_palette = true).
###
### The art only uses a handful of flat skin colours (listed in _get_source_colors()). The shader
### (skin_palette.gdshader) reads each pixel's luminance and looks the colour up on a ramp that
### runs through those stops, with each stop replaced by the matching colour below. Defaults are
### the original pale art colours, so a default SkinPalette changes nothing.
### Keep new skin shading in the art on the same light-to-dark order as the stops, or it will map oddly.

const SHADER: Shader = preload("res://scripts/object_classes/opponent_visuals/skin_palette.gdshader")
const RAMP_SIZE: int = 256

@export var id: String

@export_group("Skin colours")
@export var outline_color: Color = Color8(13, 11, 10):
	set(value):
		outline_color = value
		_update_material()
@export var shadow_color: Color = Color8(221, 126, 73):
	set(value):
		shadow_color = value
		_update_material()
@export var glans_color: Color = Color8(223, 147, 125):
	set(value):
		glans_color = value
		_update_material()
@export var base_color: Color = Color8(237, 185, 161):
	set(value):
		base_color = value
		_update_material()
@export var highlight_color: Color = Color8(247, 216, 202):
	set(value):
		highlight_color = value
		_update_material()
@export var bright_highlight_color: Color = Color8(251, 234, 226):
	set(value):
		bright_highlight_color = value
		_update_material()

var _material: ShaderMaterial
var _spine_man_materials: Dictionary = {} ### man_key ("Man 1") -> ShaderMaterial

### One shared material per palette: every sprite using this palette uses the same instance, and
### editing the palette in the inspector updates it live.
func get_material() -> ShaderMaterial:
	if not _material:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_update_material()
	return _material

### Same recolour for one of the men in the central Spine animation. Those men are drawn in their
### own skin tones (not the card art's), so each gets a ramp built from its own source colours.
### Null if that man isn't known. Shared per man, like get_material().
func get_spine_man_material(man_key: String) -> ShaderMaterial:
	if _get_spine_man_source_colors(man_key).is_empty():
		return null
	if not _spine_man_materials.has(man_key):
		var spine_material := ShaderMaterial.new()
		spine_material.shader = SHADER
		spine_material.set_shader_parameter("source_is_premultiplied", true)
		_spine_man_materials[man_key] = spine_material
		_update_spine_man_material(man_key)
	return _spine_man_materials[man_key]

func _update_material() -> void:
	if _material:
		_material.set_shader_parameter("ramp", _build_ramp_texture(_get_source_colors(), _get_target_colors()))
	for man_key in _spine_man_materials:
		_update_spine_man_material(man_key)

func _update_spine_man_material(man_key: String) -> void:
	var target_colors: Array[Color] = [outline_color, shadow_color, base_color, highlight_color]
	var spine_material: ShaderMaterial = _spine_man_materials[man_key]
	spine_material.set_shader_parameter("ramp", _build_ramp_texture(_get_spine_man_source_colors(man_key), target_colors))

### Flat colours of each man in Emily_Scene_1.png (the Spine atlas), measured from the art:
### outline, shadow tone, base tone, plus a highlight stop derived from the base tone (the art has
### a few pale highlights on the cocks). Same light-to-dark order as the target colours in
### _update_spine_man_material(). Empty = unknown man. Man 5 is the free-standing right-handjob
### cock (atlas region "Cock Right"), drawn in the same tones as Man 3.
func _get_spine_man_source_colors(man_key: String) -> Array[Color]:
	match man_key:
		"Man 5":
			return _make_spine_man_stops(Color8(248, 123, 56), Color8(255, 182, 136))
		"Man 1":
			return _make_spine_man_stops(Color8(224, 95, 36), Color8(243, 144, 98))
		"Man 2":
			return _make_spine_man_stops(Color8(244, 103, 37), Color8(255, 155, 103))
		"Man 3":
			return _make_spine_man_stops(Color8(248, 123, 56), Color8(255, 182, 136))
		"Man 4":
			return _make_spine_man_stops(Color8(167, 66, 25), Color8(181, 99, 70))
	return []

func _make_spine_man_stops(shadow: Color, base: Color) -> Array[Color]:
	return [Color8(0, 0, 0), shadow, base, base.lerp(Color.WHITE, 0.35)]

### Original art colours, darkest to lightest (measured from the body PNGs).
func _get_source_colors() -> Array[Color]:
	return [
		Color8(13, 11, 10),    # outline
		Color8(221, 126, 73),  # shadow
		Color8(223, 147, 125), # glans
		Color8(237, 185, 161), # base
		Color8(247, 216, 202), # highlight
		Color8(251, 234, 226), # bright highlight (muscular body)
	]

### Same order as _get_source_colors().
func _get_target_colors() -> Array[Color]:
	return [outline_color, shadow_color, glans_color, base_color, highlight_color, bright_highlight_color]

func _build_ramp_texture(source_colors: Array[Color], target_colors: Array[Color]) -> ImageTexture:
	var stop_positions: Array[float] = []
	for source_color in source_colors:
		stop_positions.append(_luminance(source_color))
	var image: Image = Image.create(RAMP_SIZE, 1, false, Image.FORMAT_RGBA8)
	for i in RAMP_SIZE:
		var luminance: float = float(i) / float(RAMP_SIZE - 1)
		image.set_pixel(i, 0, _sample_stops(luminance, stop_positions, target_colors))
	return ImageTexture.create_from_image(image)

func _sample_stops(luminance: float, stop_positions: Array[float], target_colors: Array[Color]) -> Color:
	var last: int = stop_positions.size() - 1
	if luminance <= stop_positions[0]:
		return target_colors[0]
	if luminance >= stop_positions[last]:
		return target_colors[last]
	for i in range(last):
		if luminance <= stop_positions[i + 1]:
			var span: float = stop_positions[i + 1] - stop_positions[i]
			var t: float = (luminance - stop_positions[i]) / span
			return target_colors[i].lerp(target_colors[i + 1], t)
	return target_colors[last]

### Must match the weights in skin_palette.gdshader.
func _luminance(color: Color) -> float:
	return 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
