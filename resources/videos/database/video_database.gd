extends Resource
class_name VideoDatabase

@export var video_clips: Array[VideoClip] = []

var _action_tag_index: Dictionary = {}
var _participant_tag_index: Dictionary = {}

func _build_index() -> void:
	_action_tag_index.clear()
	for clip in video_clips:
		for tag in clip.action_tags:
			if not _action_tag_index.has(tag):
				_action_tag_index[tag] = []
			_action_tag_index[tag].append(clip)
			
		for tag in clip.participant_tags:
			if not _participant_tag_index.has(tag):
				_participant_tag_index[tag] = []
			_participant_tag_index[tag].append(clip)

func get_random_clip(
	required_action_tags: Array[VideoClip.ActionTags] = [],
	required_participant_tags: Array[VideoClip.ParticipantTags] = []) -> VideoClip:
	if _action_tag_index.is_empty() or _participant_tag_index.is_empty():
		_build_index()
	
	# Action tags are mandatory: at least one is required, and every candidate must match ALL of them.
	if required_action_tags.is_empty():
		push_warning("get_random_clip called with no action tags. Action tags are required.")
		return null
	
	var candidates: Array[VideoClip] = video_clips.duplicate()
	for tag in required_action_tags:
		if not _action_tag_index.has(tag):
			return null
		candidates = candidates.filter(func(c): return tag in c.action_tags)
	
	if candidates.is_empty():
		return null
	
	# Participant tags are best-effort: pick whichever candidates match the MOST requested tags.
	if not required_participant_tags.is_empty():
		candidates = _filter_to_best_participant_match(candidates, required_participant_tags)
	
	var weighted_random_clip = _weighted_random(candidates)
	#print("Clip: %s"%weighted_random_clip.resource_path)
	return weighted_random_clip

func _filter_to_best_participant_match(
	candidates: Array[VideoClip],
	required_participant_tags: Array[VideoClip.ParticipantTags]) -> Array[VideoClip]:
	
	var required_tags_by_category: Dictionary = {}
	for tag in required_participant_tags:
		var category: VideoClip.ParticipantCategory = VideoClip.get_category_for_tag(tag)
		if not required_tags_by_category.has(category):
			required_tags_by_category[category] = []
		required_tags_by_category[category].append(tag)
	
	# Priority order: man's look first, then woman's look, then flavor/misc.
	var category_priority: Array[VideoClip.ParticipantCategory] = [
		VideoClip.ParticipantCategory.MAN_APPEARANCE,
		VideoClip.ParticipantCategory.WOMAN_APPEARANCE,
		VideoClip.ParticipantCategory.MISC
	]
	
	var best_candidates: Array[VideoClip] = candidates.duplicate()
	
	for category in category_priority:
		if not required_tags_by_category.has(category):
			continue # Nothing requested in this category, skip it entirely
		
		var tags_needed_in_category: Array = required_tags_by_category[category]
		var matching_candidates: Array[VideoClip] = []
		var non_matching_candidates: Array[VideoClip] = []
		
		for clip in best_candidates:
			if _clip_matches_any_tag(clip, tags_needed_in_category):
				matching_candidates.append(clip)
			else:
				non_matching_candidates.append(clip)
		
		if not matching_candidates.is_empty():
			# At least one candidate satisfies this category — narrow to those, discard the rest.
			best_candidates = matching_candidates
		# If NONE match this category, we keep the full current pool as-is and move to the next
		# (lower-priority) category rather than eliminating everyone.
	
	return best_candidates

func _clip_matches_any_tag(clip: VideoClip, tags: Array) -> bool:
	for tag in tags:
		if tag in clip.participant_tags:
			return true
	return false



#func get_random_clip(
	#required_action_tags: Array[VideoClip.ActionTags] = [],
	#required_participant_tags: Array[VideoClip.ParticipantTags] = []) -> VideoClip:
	#if _action_tag_index.is_empty() or _participant_tag_index.is_empty():
		#_build_index()
#
	#var candidates: Array[VideoClip] = video_clips.duplicate()
	#
#
	#for tag in required_action_tags:
		#if not _action_tag_index.has(tag):
			#return null
			#
		##push_error("get_random_clip: required action tags")
		#candidates = candidates.filter(func(c): return tag in c.action_tags)
	#for tag in required_participant_tags:
		#if not _participant_tag_index.has(tag):
			#return null
		##push_error("get_random_clip: required participant tags")
		#var participant_filtered_candidates = candidates.filter(func(c): return tag in c.participant_tags)
		#if not participant_filtered_candidates.is_empty():
			#candidates = participant_filtered_candidates
		##candidates = candidates.filter(func(c): return tag in c.participant_tags)
	#
	#var return_clip: VideoClip = _weighted_random(candidates)
#
	##if not return_clip.video_file:
		##print("Cannot find video file for video clip %s"%return_clip)
	#return return_clip

func _weighted_random(list: Array[VideoClip]) -> VideoClip:
	var total := 0.0
	for c in list:
		total += c.weight

	var r := randf() * total
	for c in list:
		r -= c.weight
		if r <= 0:
			return c
	return null
