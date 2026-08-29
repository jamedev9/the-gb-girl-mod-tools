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
