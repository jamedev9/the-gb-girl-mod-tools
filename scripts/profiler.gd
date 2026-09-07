class_name Profiler

var _label: String
var _start_usec: int

const MINIMUM_DURATION: int = 10

func _init(label: String) -> void:
	_label = label
	_start_usec = Time.get_ticks_usec()

func stop() -> void:
	var elapsed := Time.get_ticks_usec() - _start_usec
	if elapsed < MINIMUM_DURATION:
		return
	print("%s: %d us" % [_label, elapsed])
