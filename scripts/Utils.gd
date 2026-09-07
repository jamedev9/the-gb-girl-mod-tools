extends Node
class_name Utils

static func get_random_item(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	var random_item = arr[randi_range(0, arr.size() - 1)]
	return random_item
	
#static func get_files_in_folder(folder_path: String,file_type: String = "",filter_strings: Array[String] = []) -> Array:
	#var files := []
	#var dir := DirAccess.open(folder_path)
	#
	#filter_strings.append(".uid") # Block out files that only exist in the exported version.
	#
	#if dir == null:
		#push_error("Failed to open directory: %s" % folder_path)
		#return files
#
	#dir.list_dir_begin()
	#var item := dir.get_next()
#
	#while item != "":
		#if not dir.current_is_dir() and file_type in item and ".import" not in item:
			#if filter_strings.is_empty():
				#files.append(folder_path + item)
			#else:
				#var matches := true
				#for filter in filter_strings:
					#if filter in item:
						#matches = false
						#break
				#if matches:
					#files.append(folder_path + item)
		#item = dir.get_next()
#
	#dir.list_dir_end()
	#return files

static func get_files_in_folder(folder_path: String, file_type: String = "", filter_strings: Array[String] = []) -> Array:
	var files := []
	var dir := DirAccess.open(folder_path)

	# Remove the .remap filter — we need to handle remaps, not ignore them
	filter_strings.append(".uid")

	if dir == null:
		push_error("Failed to open directory: %s" % folder_path)
		return files

	dir.list_dir_begin()
	var item := dir.get_next()
	while item != "":
		if not dir.current_is_dir() and ".import" not in item:
			var full_path := folder_path + item

			# Resolve .remap to the actual resource path
			if item.ends_with(".remap"):
				full_path = _resolve_remap(full_path)
				if full_path == "":
					item = dir.get_next()
					continue

			# Apply file type filter
			if file_type != "" and file_type not in item:
				item = dir.get_next()
				continue

			# Apply custom filters
			var matches := true
			for filter in filter_strings:
				if filter in item:
					matches = false
					break

			if matches:
				files.append(full_path)

		item = dir.get_next()
	dir.list_dir_end()
	return files

static func _resolve_remap(remap_path: String) -> String:
	var file := FileAccess.open(remap_path, FileAccess.READ)
	if file == null:
		push_error("Could not open remap file: %s" % remap_path)
		return ""
	var content := file.get_as_text()
	file.close()
	# The remap file contains a line like: path="res://path/to/file.ctex"
	for line in content.split("\n"):
		if line.begins_with("path="):
			return line.split("=", true, 1)[1].strip_edges().trim_prefix('"').trim_suffix('"')
	return ""

static func debug_folder(folder_path: String) -> void:
	print("=== DEBUG: Inspecting folder: ", folder_path, " ===")
	
	var dir := DirAccess.open(folder_path)
	if dir == null:
		print("ERROR: Could not open folder. DirAccess error: ", DirAccess.get_open_error())
		return
	
	print("Folder opened successfully. Listing all contents:")
	dir.list_dir_begin()
	var item := dir.get_next()
	while item != "":
		print("  Found: ", item, " | is_dir: ", dir.current_is_dir())
		item = dir.get_next()
	dir.list_dir_end()
	
	print("=== END DEBUG ===")

static func select_random_video_from_directory(directory_path: String) -> String:
	var random_video_path : String
	var video_files = get_files_in_folder(directory_path,".ogv",[".uid"])
	random_video_path = Utils.get_random_item(video_files)
	return random_video_path

static func clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

static func remove_duplicates(arr: Array):
	var result := []
	for element in arr:
		if not element in result:
			result.append(element)
	return result

static func load_resources_in_folder(folder_path) -> Array[Resource]:
	var array_of_resources: Array[Resource] = []
	var files_in_folder = get_files_in_folder(folder_path,".tres",[".remap"])
	for file in files_in_folder:
		array_of_resources.append(load(file))
	return array_of_resources

static func copy_resources_in_folder(folder_path) -> Array[Resource]:
	var array_of_resources: Array[Resource] = []
	var files_in_folder = get_files_in_folder(folder_path,".tres",[""])
	for file in files_in_folder:
		array_of_resources.append(load(file).duplicate())
	return array_of_resources


static func capitalize_each_sentence(text: String) -> String: ### This is just doing .capitalize()
	var out := ""
	var capitalize_next := true
	for i in range(text.length()):
		var ch := text.substr(i, 1)

		if capitalize_next:
			# Skip leading whitespace / openers at the start of a sentence
			if ch == " " or ch == "\t" or ch == "\n" or ch == "\"" or ch == "'" or ch == "“" or ch == "‘" or ch == "(" or ch == "[" or ch == "{" or ch == "—" or ch == "-":
				out += ch
				continue

			# If it's a cased letter, uppercase it
			if ch.to_lower() != ch.to_upper():
				out += ch.to_upper()
				capitalize_next = false
				continue

			# Non-letter (e.g., number/symbol) — keep looking for a letter
			out += ch
			continue
		else:
			out += ch

		# After punctuation that ends a sentence, capitalize next letter we encounter
		if ch == "." or ch == "!" or ch == "?":
			capitalize_next = true

	return out

static func arrays_have_same_content(array1: Array, array2: Array) -> bool:
	# Check if the arrays have the same size
	if array1.size() != array2.size():
		return false
	# Check if each element in array1 exists in array2 with the same count
	for item in array1:
		if not array2.has(item):
			return false
		if array1.count(item) != array2.count(item):
			return false
	return true

static func increase_value_in_dictionary(dict: Dictionary,key: String,delta: int) -> void:
	if key not in dict.keys():
		dict[key] = delta
	else:
		dict[key] += delta

static func format_string_list(items: Array[String]) -> String:
	if items.size() == 0:
		return ""
	if items.size() == 1:
		return items[0]
	if items.size() == 2:
		return "%s and %s" % [items[0], items[1]]
	var all_but_last: Array[String] = items.slice(0, items.size() - 1)
	return "%s, and %s" % [", ".join(all_but_last), items[-1]]

static func add_delta_to_displayed_integer_value(label: Node,delta: int) -> void:
	if label is not Label and label is not RichTextLabel:
		push_error("decrease_displayed_integer_value_by was called on node %s, which is not a label"%label)
		return
	var current_value: int = int(label.text)
	var new_value: int = current_value+delta
	label.text = str(new_value)

enum VersionComparison {BEFORE, SAME, AFTER}

static func compare_versions(version_a: String, version_b: String) -> VersionComparison:
	var parts_a: PackedStringArray = version_a.split(".")
	var parts_b: PackedStringArray = version_b.split(".")
	var part_count: int = max(parts_a.size(), parts_b.size())
	for i in range(part_count):
		var value_a: int = int(parts_a[i]) if i < parts_a.size() else 0
		var value_b: int = int(parts_b[i]) if i < parts_b.size() else 0
		if value_a < value_b:
			return VersionComparison.BEFORE
		if value_a > value_b:
			return VersionComparison.AFTER
	return VersionComparison.SAME

## Loads a Texture2D from an @export_file-style path string, tolerating the ways such paths
## go stale: a uid:// string Godot substituted in the editor (resolved via
## ModExportable.resolve_to_res_path), a res:// project resource, or a plain filesystem path
## (modded/user-provided images). Returns fallback and logs an error on any failure instead of
## letting a bad path silently render nothing.
static func load_texture_from_path(path: String, fallback: Texture2D = null) -> Texture2D:
	if path == "":
		return fallback

	var resolved_path: String = ModExportable.resolve_to_res_path(path)
	if resolved_path == "":
		push_error("Could not resolve texture path: %s" % path)
		return fallback

	if resolved_path.begins_with("res://"):
		if not ResourceLoader.exists(resolved_path):
			push_error("Texture resource not found at path: %s" % resolved_path)
			return fallback
		var loaded_resource = load(resolved_path)
		if loaded_resource is Texture2D:
			return loaded_resource
		push_error("Resource at path is not a Texture2D: %s" % resolved_path)
		return fallback

	# External filesystem path (modded/user-provided images)
	if not FileAccess.file_exists(resolved_path):
		push_error("Texture file not found at path: %s" % resolved_path)
		return fallback
	var image := Image.load_from_file(resolved_path)
	if not image:
		push_error("Failed to load image data at path: %s" % resolved_path)
		return fallback
	return ImageTexture.create_from_image(image)

static func load_asset(path : String) -> Resource:
	if OS.has_feature("export"):
		# Check if file is .remap
		if not path.ends_with(".remap"):
			return load(path)

		# Open the file
		var __config_file = ConfigFile.new()
		__config_file.load(path)

		# Load the remapped file
		var __remapped_file_path = __config_file.get_value("remap", "path")
		__config_file = null
		return load(__remapped_file_path)
	else:
		return load(path)
