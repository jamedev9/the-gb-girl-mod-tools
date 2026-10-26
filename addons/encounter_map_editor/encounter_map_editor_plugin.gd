@tool
extends EditorPlugin

### The "Encounter Map" main-screen tab (next to 2D / 3D / Script). Opens when an EncounterMap resource is edited
### (double-click it in the FileSystem dock). The tab's content is EncounterMapEditorPanel.

const EncounterMapEditorPanel = preload("./encounter_map_editor_panel.gd")

var _panel: EncounterMapEditorPanel

func _enter_tree() -> void:
	_panel = EncounterMapEditorPanel.new()
	_panel.undo_redo = get_undo_redo()
	EditorInterface.get_editor_main_screen().add_child(_panel)
	_make_visible(false)

func _exit_tree() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null

func _has_main_screen() -> bool:
	return true

func _make_visible(should_show: bool) -> void:
	if _panel:
		_panel.visible = should_show

func _get_plugin_name() -> String:
	return "Encounter Map"

func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("GraphEdit", "EditorIcons")

func _handles(object: Object) -> bool:
	return object is EncounterMap

func _edit(object: Object) -> void:
	if object is EncounterMap:
		_panel.edit_map(object as EncounterMap)

### Called whenever the editor saves (Ctrl+S, and before running the game), so the game always reads the latest map.
func _save_external_data() -> void:
	if _panel:
		_panel.save_all_unsaved_maps()

### Asked when the editor closes: lists the maps with unsaved changes.
func _get_unsaved_status(for_scene: String) -> String:
	if _panel == null or not for_scene.is_empty():
		return ""
	return _panel.get_unsaved_status_text()
