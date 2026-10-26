@tool
extends Resource
class_name HairPalette

### Recolours the hair layers of the opponent art (parts with use_hair_palette = true).
###
### Works exactly like SkinPalette and uses the same shader (skin_palette.gdshader): the hair art
### only uses four flat colours (listed in _get_source_colors()), each pixel's luminance is looked
### up on a ramp that runs through them, and each stop is replaced by the matching colour below.
### Defaults are the original blond art colours, so a default HairPalette changes nothing.
### Keep new hair shading in the art on the same light-to-dark order as the stops, or it will map oddly.

const SHADER: Shader = preload("res://scripts/object_classes/opponent_visuals/skin_palette.gdshader")
const RAMP_SIZE: int = 256

@export var id: String

@export_group("Hair colours")
@export var outline_color: Color = Color8(15, 15, 12):
	set(value):
		outline_color = value
		_update_material()
@export var shadow_color: Color = Color8(238, 176, 91):
	set(value):
		shadow_color = value
		_update_material()
@export var base_color: Color = Color8(250, 255, 199):
	set(value):
		base_color = value
		_update_material()
@export var highlight_color: Color = Color8(253, 255, 223):
	set(value):
		highlight_color = value
		_update_material()

var _material: ShaderMaterial
var _spine_hair_materials: Dictionary = {} ### slot name ("Man 1 Hair") -> ShaderMaterial

### One shared material per palette: every sprite using this palette uses the same instance, and
### editing the palette in the inspector updates it live.
func get_material() -> ShaderMaterial:
	if not _material:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_update_material()
	return _material

### Same recolour for a hair slot of the central Spine animation. The rig's hair is drawn in its own
### colours (not the card art's), so each hair slot gets a ramp built from its own source colours.
### Null if that slot isn't known - it is then left as drawn. Shared per slot, like get_material().
func get_spine_hair_material(slot_name: String) -> ShaderMaterial:
	if _get_spine_hair_sources(slot_name).is_empty():
		return null
	if not _spine_hair_materials.has(slot_name):
		var spine_material := ShaderMaterial.new()
		spine_material.shader = SHADER
		spine_material.set_shader_parameter("source_is_premultiplied", true)
		_spine_hair_materials[slot_name] = spine_material
		_update_spine_hair_material(slot_name)
	return _spine_hair_materials[slot_name]

func _update_material() -> void:
	if _material:
		_material.set_shader_parameter("ramp", _build_ramp_texture(_get_source_colors(), _get_target_colors()))
	for slot_name in _spine_hair_materials:
		_update_spine_hair_material(slot_name)

func _update_spine_hair_material(slot_name: String) -> void:
	var source_colors: Array[Color] = []
	var target_colors: Array[Color] = []
	for source in _get_spine_hair_sources(slot_name):
		source_colors.append(source[0])
		target_colors.append(_get_color_for_role(source[1]))
	var spine_material: ShaderMaterial = _spine_hair_materials[slot_name]
	spine_material.set_shader_parameter("ramp", _build_ramp_texture(source_colors, target_colors))

### Flat colours of each hair slot in Emily_Scene_1.png (the Spine atlas), measured from the art.
### Each row is [colour in the atlas, which palette colour replaces it], darkest first. A hair slot
### that isn't listed isn't recoloured - add a row here when the animator delivers a new hairstyle
### or another man gets hair. Only Man 1 (the vaginal man) has hair so far; his hair has no shadow
### tone, so the palette's shadow_color isn't used for him.
func _get_spine_hair_sources(slot_name: String) -> Array:
	match slot_name:
		"Man 1 Hair":
			return [
				[Color8(0, 0, 0), "outline"],
				[Color8(122, 22, 28), "base"],
				[Color8(182, 80, 83), "highlight"],
			]
	return []

func _get_color_for_role(role: String) -> Color:
	match role:
		"outline":
			return outline_color
		"shadow":
			return shadow_color
		"highlight":
			return highlight_color
	return base_color

### Original art colours, darkest to lightest (measured from hair_default.png).
func _get_source_colors() -> Array[Color]:
	return [
		Color8(15, 15, 12),    # outline
		Color8(238, 176, 91),  # shadow
		Color8(250, 255, 199), # base
		Color8(253, 255, 223), # highlight
	]

### Same order as _get_source_colors().
func _get_target_colors() -> Array[Color]:
	return [outline_color, shadow_color, base_color, highlight_color]

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
