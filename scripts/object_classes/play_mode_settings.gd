class_name PlayModeSettings

### Which track the game is running as. Set once, before anything reads it, by the root scene
### (the new-UI test scene's play_mode - its setter runs while the scene is instantiated,
### i.e. before any child's _ready). Read it wherever the two tracks must behave differently.
### Static rather than an autoload: it has no behaviour, only a value.

enum Mode {
	DEFAULT, ## The prototype: loads all current content, legacy slot-numbered saves.
	FULL_REWORK, ## The rework track: unique-id saves (and, later, only carried-over content).
}

static var current: Mode = Mode.DEFAULT

### Set by the new-UI test scene: lets DEFAULT mode apply the rework content
### set's art (opponent appearances, action art parts, replacement art, keyword icons), so the prototype
### content can be tried in the new UI. Only the art: the rework pack's own content (encounters,
### characters, ...) is never scanned in DEFAULT. Nothing in the rework folders is ever referenced from
### here, so it does nothing when those files aren't shipped.
static var include_rework_content_in_default: bool = false

### True when the content set's art should be applied (the rework pack folder itself is scanned in
### FULL_REWORK only).
static func uses_rework_content() -> bool:
	return current == Mode.FULL_REWORK or include_rework_content_in_default
