@tool
extends Resource
class_name ContentSet

### What Full Rework mode (PlayModeSettings.Mode.FULL_REWORK) is allowed to load, besides
### everything inside the rework content pack folder itself: prototype content confirmed to go
### into the reworked game, grouped by type, plus the hardcoded "start of game" ids that the
### prototype keeps in code.
###
### Each section is a Dictionary keyed by the content's own id (card_type_id, action_id, status_id,
### reward_id, ...), so the inspector labels every row with the id; expand a row to reach its
### CarryOverEntry (the content reference, replacement art, overrides). The key is only a label -
### the content is registered under its own id - but AutoloadDatabase warns when a key doesn't match.
### The sections only organise the list: an entry in the wrong section still works.
### Migrating a resource into the rework pack later = move the file, delete its entry here.

@export_group("Start of game")
@export var start_encounter_ids: Array[String] = []
### Passives a new player owns from the start (the prototype hardcodes birth_control + fertile).
@export var starter_passive_ids: Array[String] = []
### The deck (and owned cards) a new player starts with: card id -> count. The prototype hardcodes its own.
@export var starter_deck: Dictionary[String, int] = {}

@export_group("Encounter map")
### The rework's overworld map: which encounters are on it, where, and what unlocks each (see EncounterMap). It
### carries its encounters over (they need no entry here) and its nodes replace their unlock_conditions. Edited
### in the Encounter Map editor tab. Empty = the prototype's map rules (columns by unlock depth, rows by branch_index).
@export var encounter_map: EncounterMap
### The scene OverworldMap instantiates for each node of the map (root script extends MapEncounterNode). Kept here so
### the prototype's files never name a rework path. Empty = the prototype's node scene.
@export var map_encounter_node_scene: PackedScene

@export_group("Encounter difficulty")
### The table pre-calculated for the rework's characters and encounters by
### tools/encounter_difficulty/encounter_difficulty_builder.tscn (see EncounterDifficultyService). The tunables
### it was built with are shared with the prototype: EncounterDifficultyWeights.load_shared().
@export var encounter_difficulty_table: EncounterDifficultyTable

@export_group("Rework art")
### Rework-only art for shared content, keyed by the content's own id. Kept here rather than on the
### prototype's files so those never reference rework art (prototype builds don't ship it). Applied by
### AutoloadDatabase when it registers the content in Full Rework, so an entry for content that isn't
### carried over (yet) just waits. Opponent type id -> the appearances its opponents pick from.
@export var opponent_appearances: Dictionary[String, OpponentAppearanceList] = {}
### Player action id -> the art parts drawn on the opponent card while that action is active.
@export var player_action_art_parts: Dictionary[String, ArtPartList] = {}

@export_group("Characters")
@export var characters: Dictionary[String, CarryOverEntry] = {}

@export_group("Player actions")
@export var player_actions: Dictionary[String, CarryOverEntry] = {}

@export_group("Action progressions")
@export var action_progressions: Dictionary[String, CarryOverEntry] = {}

@export_group("Event cards")
@export var event_cards: Dictionary[String, CarryOverEntry] = {}

@export_group("Opponent types")
@export var opponent_types: Dictionary[String, CarryOverEntry] = {}

@export_group("Opponent actions")
@export var opponent_actions: Dictionary[String, CarryOverEntry] = {}

@export_group("Passive effects")
@export var passive_effects: Dictionary[String, CarryOverEntry] = {}

@export_group("Status effects")
@export var status_effects: Dictionary[String, CarryOverEntry] = {}

@export_group("Gameplay keywords")
@export var gameplay_keywords: Dictionary[String, CarryOverEntry] = {}

@export_group("Map regions")
@export var map_regions: Dictionary[String, CarryOverEntry] = {}

@export_group("Rewards")
@export var rewards: Dictionary[String, CarryOverEntry] = {}

@export_group("Picture lists")
@export var picture_lists: Dictionary[String, CarryOverEntry] = {}

@export_group("Video clips")
@export var video_clips: Dictionary[String, CarryOverEntry] = {}

### Every section as {key -> entry}, in the order they appear above.
func get_sections() -> Array:
	return [
		characters, player_actions, action_progressions, event_cards, opponent_types,
		opponent_actions, passive_effects, status_effects, gameplay_keywords,
		map_regions, rewards, picture_lists, video_clips,
	]
