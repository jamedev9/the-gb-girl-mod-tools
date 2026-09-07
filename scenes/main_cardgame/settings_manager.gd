extends GameManager
class_name SettingsManager

const GAME_TITLE: String = "The Gangbang Girl"
const DEVELOPER: String = "gb_girl_dev"
const COPYRIGHT: String = "2026"

const DEFAULT_SLIDER_VALUE: float = 100.0

const DEFAULT_COLORBLIND_POSITIVE_COLOR_HEX: String = "0072b2"
const DEFAULT_COLORBLIND_NEGATIVE_COLOR_HEX: String = "e69f00"

const DEFAULT_ANIMATION_SPEED: float = 0.7
const MIN_ANIMATION_SPEED: float = 0.1
const MAX_ANIMATION_SPEED: float = 10.0

const DEFAULT_ANIMATION_SPEED_MULTIPLIER_SCALE: float = 1.0
const MIN_ANIMATION_SPEED_MULTIPLIER_SCALE: float = 0.1
const MAX_ANIMATION_SPEED_MULTIPLIER_SCALE: float = 10.0

const DEFAULT_LANGUAGE: String = "en"
## locale code : system locale-language prefixes that should map to it (checked in order).
const LANGUAGE_LOCALE_PREFIXES: Dictionary = {
	"chi": ["zh"],
}


func _ready() -> void:
	load_settings()
	TranslationServer.set_locale(get_language())


var settings: Dictionary = {
	"animation_speed": 0.7,
	"window_mode": 0,
	"resolution_x": 1920,
	"resolution_y": 1080,
	"last_used_save_slot": 0,
	"videos_in_logs": true,
	"videos_on_opponents": true

}

func set_animation_speed(speed: float) -> void:
	settings["animation_speed"] = speed
func get_animation_speed() -> float:
	return float(settings["animation_speed"])
func set_animation_speed_multiplier_scale(scale: float) -> void:
	settings["animation_speed_multiplier_scale"] = scale
func get_animation_speed_multiplier_scale() -> float:
	if "animation_speed_multiplier_scale" not in settings.keys():
		settings["animation_speed_multiplier_scale"] = DEFAULT_ANIMATION_SPEED_MULTIPLIER_SCALE
	return float(settings["animation_speed_multiplier_scale"])
func set_value_for_setting(setting: String, value: float) -> void:
	settings[setting] = value
func get_value_for_setting(setting: String):
	if setting not in settings.keys():
		settings[setting] = DEFAULT_SLIDER_VALUE
	return float(settings[setting])
func get_window_mode() -> int:
	if "window_mode" not in settings.keys():
		settings["window_mode"] = 0
	return int(settings["window_mode"])
func get_resolution() -> Vector2i:
	if "resolution_x" not in settings.keys():
		settings["resolution_x"] =  1920
	if "resolution_y" not in settings.keys():
		settings["resolution_y"] =  1080
	return Vector2i(settings["resolution_x"],settings["resolution_y"])

#region Language
func get_language() -> String:
	if "language" not in settings.keys():
		settings["language"] = _determine_default_language()
	return String(settings["language"])

func set_language(locale_code: String) -> void:
	settings["language"] = locale_code

## First-boot default: match the system locale's language to an available
## translation ("zh_CN", "zh_TW", etc. all fall back to "chi"), otherwise
## fall back to DEFAULT_LANGUAGE.
func _determine_default_language() -> String:
	var system_language: String = OS.get_locale_language()
	for locale_code in LANGUAGE_LOCALE_PREFIXES.keys():
		for prefix in LANGUAGE_LOCALE_PREFIXES[locale_code]:
			if system_language.begins_with(prefix):
				return locale_code
	return DEFAULT_LANGUAGE
#endregion

func store_last_used_save_slot(save_slot: int) -> void:
	settings["last_used_save_slot"] = save_slot
func get_last_used_save_slot() -> int:
	if "last_used_save_slot" not in settings.keys():
		settings["last_used_save_slot"] = 0
	return int(settings["last_used_save_slot"])

func save_settings() -> void:
	SaveSystem.save_settings(settings)

func load_settings() -> void:
	var loaded_settings: Dictionary = SaveSystem.load_settings()
	if loaded_settings == {}:
		return
	settings = loaded_settings
	_enabled_mods_snapshot_at_launch = get_enabled_mods().duplicate(true)

func get_videos_in_logs_setting() -> bool:
	if "videos_in_logs" not in settings.keys():
		settings["videos_in_logs"] = true
		return true
	return get_value_for_setting("videos_in_logs")

func get_videos_on_opponents_setting() -> bool:
	if "videos_on_opponents" not in settings.keys():
		settings["videos_on_opponents"] = true
		return true
	return get_value_for_setting("videos_on_opponents")

#region Colorblind accessibility
func get_colorblind_mode() -> bool:
	if "colorblind_mode" not in settings.keys():
		settings["colorblind_mode"] = false
	return bool(settings["colorblind_mode"])

func set_colorblind_mode(enabled: bool) -> void:
	settings["colorblind_mode"] = enabled

func get_colorblind_positive_color() -> Color:
	return Color(settings.get("colorblind_positive_color", DEFAULT_COLORBLIND_POSITIVE_COLOR_HEX))

func get_colorblind_negative_color() -> Color:
	return Color(settings.get("colorblind_negative_color", DEFAULT_COLORBLIND_NEGATIVE_COLOR_HEX))

func set_colorblind_positive_color(color: Color) -> void:
	settings["colorblind_positive_color"] = color.to_html(false)

func set_colorblind_negative_color(color: Color) -> void:
	settings["colorblind_negative_color"] = color.to_html(false)

## Drop-in replacement for a hardcoded Color.GREEN: returns the colorblind-safe
## override when colorblind mode is on, otherwise plain green.
func get_positive_color() -> Color:
	return get_colorblind_positive_color() if get_colorblind_mode() else Color.GREEN

## Drop-in replacement for a hardcoded Color.RED: returns the colorblind-safe
## override when colorblind mode is on, otherwise plain red.
func get_negative_color() -> Color:
	return get_colorblind_negative_color() if get_colorblind_mode() else Color.RED

## For static call sites (no main_game/instance access, e.g. AnimationHelper_NodeFlasher).
static func get_active() -> SettingsManager:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var current_scene: Node = tree.current_scene if tree else null
	if current_scene and "settings_manager" in current_scene:
		return current_scene.settings_manager
	return null

static func active_positive_color() -> Color:
	var manager: SettingsManager = get_active()
	return manager.get_positive_color() if manager else Color.GREEN

static func active_negative_color() -> Color:
	var manager: SettingsManager = get_active()
	return manager.get_negative_color() if manager else Color.RED
#endregion

#region Mod management
## Set once in load_settings() so the mods menu can tell whether the player
## has actually changed anything - the restart-to-apply button should stay
## disabled otherwise.
var _enabled_mods_snapshot_at_launch: Dictionary = {}

func has_mod_enablement_changed_since_launch() -> bool:
	return get_enabled_mods() != _enabled_mods_snapshot_at_launch

func get_enabled_mods() -> Dictionary:
	if "enabled_mods" not in settings.keys():
		settings["enabled_mods"] = {}
	return settings["enabled_mods"]

## Mods are enabled by default until the player explicitly disables one.
func is_mod_enabled(mod_name: String) -> bool:
	return bool(get_enabled_mods().get(mod_name, true))

func set_mod_enabled(mod_name: String, enabled: bool) -> void:
	get_enabled_mods()[mod_name] = enabled

## Reads straight from the settings file instead of through an instance.
## autoload_database.gd and video_player_system.gd are true Autoloads that
## scan user://mods/ before the main scene (and this manager) exist, so they
## can't go through main_game.settings_manager the way in-game UI can.
static func is_mod_enabled_on_disk(mod_name: String) -> bool:
	var saved_settings: Dictionary = SaveSystem.load_settings()
	var enabled_mods: Dictionary = saved_settings.get("enabled_mods", {})
	return bool(enabled_mods.get(mod_name, true))
#endregion
