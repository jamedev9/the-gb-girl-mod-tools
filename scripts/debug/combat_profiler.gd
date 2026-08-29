extends Node

### Autoload: CombatProfiler
###
### Buffers structured performance log lines in memory during play and writes them all to
### disk ONCE, on clean quit (or when you press F9). An earlier debug-logging system in this
### project (DebugCrashLog, since removed) wrote to disk every frame and became a real source
### of slowdown itself - this deliberately avoids that pattern.
###
### Entirely inert outside debug builds (OS.has_feature("editor") guard elsewhere already
### stops most dev-only systems from running in exported builds, but this checks
### OS.is_debug_build() directly since it also needs to work in debug *exports*, not just
### editor runs).
###
### Hook points call log_event()/begin_timer()/end_timer()/note_*() from wherever they
### suspect a cost - see opponent_card.gd (video playback, passive/status UI rebuild),
### opponents_container.gd (active opponent count), and main_cardgame.gd (per-fragment
### animation timing) for the current call sites.

const LOG_FILE_PATH: String = "user://combat_perf_log.txt"
const SNAPSHOT_INTERVAL: float = 0.5 ### seconds between periodic frame-time snapshots

var _enabled: bool = false
var _log_lines: Array[String] = []
var _session_start_usec: int = 0

var _active_timers: Dictionary[String, int] = {} ### timer id -> start usec

var _playing_video_opponent_ids: Dictionary[String, bool] = {}
var _active_opponent_count: int = 0

var _snapshot_accumulator: float = 0.0
var _snapshot_frame_count: int = 0
var _snapshot_delta_sum: float = 0.0
var _snapshot_delta_max: float = 0.0

var _f9_was_pressed: bool = false

func _ready() -> void:
	_enabled = OS.is_debug_build()
	if not _enabled:
		set_process(false)
		return
	_session_start_usec = Time.get_ticks_usec()
	get_tree().set_auto_accept_quit(false)
	print("[CombatProfiler] Enabled - press F9 to flush early. Log will be written on quit to: %s" % ProjectSettings.globalize_path(LOG_FILE_PATH))

func _notification(what: int) -> void:
	if not _enabled:
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush_to_disk()
		get_tree().quit()

func _process(delta: float) -> void:
	_poll_manual_flush_key()
	_accumulate_frame_snapshot(delta)

func _poll_manual_flush_key() -> void:
	var pressed: bool = Input.is_key_pressed(KEY_F9)
	if pressed and not _f9_was_pressed:
		flush_to_disk()
	_f9_was_pressed = pressed

func _accumulate_frame_snapshot(delta: float) -> void:
	_snapshot_accumulator += delta
	_snapshot_frame_count += 1
	_snapshot_delta_sum += delta
	_snapshot_delta_max = max(_snapshot_delta_max, delta)
	if _snapshot_accumulator < SNAPSHOT_INTERVAL:
		return
	_log_periodic_snapshot()
	_snapshot_accumulator = 0.0
	_snapshot_frame_count = 0
	_snapshot_delta_sum = 0.0
	_snapshot_delta_max = 0.0

func _log_periodic_snapshot() -> void:
	if _snapshot_frame_count == 0:
		return
	var avg_ms: float = (_snapshot_delta_sum / _snapshot_frame_count) * 1000.0
	var max_ms: float = _snapshot_delta_max * 1000.0
	_append_line("SNAPSHOT",
		"avg_frame_ms=%.2f max_frame_ms=%.2f frames=%d opponents=%d videos_playing=%d" % [
			avg_ms, max_ms, _snapshot_frame_count, _active_opponent_count, _playing_video_opponent_ids.size()
		])

#region Public API - call these from wherever you suspect a cost

func log_event(category: String, message: String) -> void:
	if not _enabled:
		return
	_append_line(category, message)

## Start a named timer. Call end_timer() with the same id to log elapsed time.
## IDs only need to be unique among *concurrently in-flight* timers, not globally.
func begin_timer(timer_id: String) -> void:
	if not _enabled:
		return
	_active_timers[timer_id] = Time.get_ticks_usec()

func end_timer(timer_id: String, category: String, extra_info: String = "") -> void:
	if not _enabled:
		return
	if not _active_timers.has(timer_id):
		return
	var elapsed_usec: int = Time.get_ticks_usec() - _active_timers[timer_id]
	_active_timers.erase(timer_id)
	var suffix: String = (" " + extra_info) if extra_info != "" else ""
	_append_line(category, "%s took %.2f ms%s" % [timer_id, elapsed_usec / 1000.0, suffix])

func note_video_started(opponent_id: String) -> void:
	if not _enabled:
		return
	_playing_video_opponent_ids[opponent_id] = true

func note_video_stopped(opponent_id: String) -> void:
	if not _enabled:
		return
	_playing_video_opponent_ids.erase(opponent_id)

## Call when a video is being hidden - flags whether it's still actually playing/decoding
## despite being invisible (Godot's VideoStreamPlayer does NOT auto-pause on visible=false).
func note_video_still_playing_while_hidden(opponent_id: String) -> void:
	if not _enabled:
		return
	_append_line("VIDEO_WARNING", "opponent %s: video still playing/decoding despite being hidden" % opponent_id)

func note_active_opponent_count(count: int) -> void:
	if not _enabled:
		return
	_active_opponent_count = count

#endregion

func _append_line(category: String, message: String) -> void:
	var elapsed_ms: float = (Time.get_ticks_usec() - _session_start_usec) / 1000.0
	_log_lines.append("[%8.1fms] [%s] %s" % [elapsed_ms, category, message])

func flush_to_disk() -> void:
	if not _enabled or _log_lines.is_empty():
		return
	var file := FileAccess.open(LOG_FILE_PATH, FileAccess.WRITE)
	if not file:
		push_warning("CombatProfiler: could not open %s for writing." % LOG_FILE_PATH)
		return
	for line in _log_lines:
		file.store_line(line)
	file.close()
	print("[CombatProfiler] Wrote %d log line(s) to %s" % [_log_lines.size(), ProjectSettings.globalize_path(LOG_FILE_PATH)])
