# Copyright (c) 2025 Liam Sherwin. All rights reserved.
# This file is part of the Spectrum Lighting Controller, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

class_name CueList extends Function
## A list of cues


## Emitted when the active cue is changed
signal on_active_cue_changed(cue: Cue)

## Emitted when the global fade state is changed
signal on_global_fade_state_changed(use_global_fade: bool)

## Emitted when the global pre_wait state is changed
signal on_global_pre_wait_state_changed(use_global_pre_wait: bool)

## Emitted when the global fade is changed
signal on_global_fade_changed(global_fade: float)

## Emitted when the global pre_wait is changed
signal on_global_pre_wait_changed(global_pre_wait: float)

## Emitted when the allow triggered looping state is changed
signal on_triggered_looping_changed(allow_triggered_looping: bool)

## Emitted when the loop mode is changed
signal on_loop_mode_changed(loop_mode: LoopMode)

## Emitted when a cue is added to this CueList
signal on_cues_added(cues: Array)

## Emitted when a cue is removed from this CueList
signal on_cues_removed(cues: Array)

## Emitted when a cue's position has changed
signal on_cue_order_changed(cue: Cue, position: int)



## Loop mode, Reset: Reset all track and go to a default state, Track: Track changes while looping the cue list
enum LoopMode {RESET, TRACK}

## Allowed parameters to changed when setting function intencity
const _allowed_intensity_parameters: Array[String] = ["Dimmer"]


## All the cues in the list
var _cues: Array[Cue]

## Current active cue
var _active_cue: Cue

## The previous active cue
var _previous_cue: Cue

## The previous seek direction
var _previous_seek_direction: TransportState = TransportState.PAUSED

## If a cues data has been modifed
var _cue_data_modified: bool = false

## Global fade state
var _use_global_fade: bool = false

## Global pre wait state
var _use_global_pre_wait: bool = false

## Global fade time
var _global_fade: float = 1

## Global pre wait
var _global_pre_wait: float = 1

## Current loop mode for the cue list
var _loop_mode: LoopMode = LoopMode.RESET

## Allow cues with trigger modes to loop back to the start when reaching the end.
var _allow_triggered_looping: bool = false

## Allows cues follow modes
var _allow_follow_cues: bool = true

## All active animators
var _active_animators: Array[CueAnimator]

## All active fixtures
var _active_fixtures: Dictionary[String, Dictionary]

## All active timers for cue trigger modes
var _active_trigger_timers: Array[Timer]


## init
func _init(p_uuid: String = UUID_Util.v4(), p_name: String = _name) -> void:
	super._init(p_uuid, p_name)
	
	set_name("CueList")
	_set_self_class("CueList")
	
	_settings_manager.register_setting("allow_triggered_looping", Data.Type.BOOL, set_allow_triggered_looping, get_allow_triggered_looping, [on_triggered_looping_changed])
	_settings_manager.register_setting("use_global_fade", Data.Type.BOOL, set_global_fade_state, get_global_fade_state, [on_global_fade_state_changed])
	_settings_manager.register_setting("use_global_pre_wait", Data.Type.BOOL, set_global_pre_wait_state, get_global_pre_wait_state, [on_global_pre_wait_state_changed])
	_settings_manager.register_setting("loop_mode", Data.Type.ENUM, set_loop_mode, get_loop_mode, [on_loop_mode_changed]).set_enum_dict(LoopMode)
	
	_settings_manager.register_control("go_previous", Data.Type.ACTION, go_previous)
	_settings_manager.register_control("go_next", Data.Type.ACTION, go_next)
	_settings_manager.register_control("global_fade_speed", Data.Type.FLOAT, set_global_fade_speed, get_global_fade_speed, [on_global_fade_changed])
	_settings_manager.register_control("global_pre_wait_speed", Data.Type.FLOAT, set_global_pre_wait_speed, get_global_pre_wait_speed, [on_global_pre_wait_changed])

	_settings_manager.register_networked_methods_auto([
		add_cue,
		add_cues,
		remove_cue,
		remove_cues,
		get_cues,
		set_cue_position,
		set_allow_triggered_looping,
		set_loop_mode,
		set_global_fade_state,
		set_global_pre_wait_state,
		set_global_fade_speed,
		set_global_pre_wait_speed,
		get_loop_mode,
		get_allow_triggered_looping,
		get_global_fade_state,
		get_global_pre_wait_state,
		get_global_fade_speed,
		get_global_pre_wait_speed,
		get_active_cue,
		go_next,
		go_previous,
		seek_to,
	])

	_settings_manager.set_method_allow_serialize(get_cues)
	_settings_manager.set_method_allow_deserialize(add_cue)
	_settings_manager.set_method_allow_deserialize(add_cues)

	_settings_manager.register_networked_signals_auto([
		on_active_cue_changed,
		on_global_fade_state_changed,
		on_global_pre_wait_state_changed,
		on_global_fade_changed,
		on_global_pre_wait_changed,
		on_triggered_looping_changed,
		on_loop_mode_changed,
		on_cues_added,
		on_cues_removed,
		on_cue_order_changed,
	])

	_settings_manager.set_signal_allow_serialize(on_cues_added)
	

## Adds a cue to the list
func add_cue(p_cue: Cue, p_no_signal: bool = false) -> bool:
	if p_cue in _cues:
		return false
	
	_cues.append(p_cue)
	p_cue.on_delete_requested.connect(remove_cue.bind(p_cue))
	Network.register_network_object(p_cue.uuid(), p_cue.settings())

	if not p_no_signal:
		on_cues_added.emit([p_cue])
	
	return true


## Adds mutiple cues
func add_cues(p_cues: Array) -> void:
	var just_added_cues: Array[Cue]

	for cue: Variant in p_cues:
		if cue is Cue and add_cue(cue, true):
			just_added_cues.append(cue)
	
	if just_added_cues:
		on_cues_added.emit(just_added_cues)


## Removes a cue from the list
func remove_cue(p_cue: Cue, p_no_signal: bool = false) -> bool:
	if p_cue not in _cues:
		return false
	 
	_cues.erase(p_cue)
	Network.deregister_network_object(p_cue.settings())

	if not p_no_signal:
		on_cues_removed.emit([p_cue])

	return true


## Removes mutiple cues
func remove_cues(p_cues: Array) -> void:
	var just_removed_cues: Array[Cue]

	for cue: Variant in p_cues:
		if cue is Cue and remove_cue(cue, true):
			just_removed_cues.append(cue)
	
	if just_removed_cues:
		on_cues_removed.emit(just_removed_cues)


## Returns an ordored list of cues
func get_cues() -> Array[Cue]:
	return _cues.duplicate()


## Sets the posititon of a cue in the list
func set_cue_position(p_cue: Cue, p_position: int) -> void:
	if p_cue not in _cues or p_position > len(_cues) - 1:
		return
	
	var old_index: int = _cues.find(p_cue)
	_cues.remove_at(old_index)
	_cues.insert(p_position, p_cue)

	_cue_data_modified = true
	on_cue_order_changed.emit(p_cue, p_position)


## Sets whether triggered cues can loop back to the start
func set_allow_triggered_looping(p_allow_triggered_looping: bool) -> void:
	if p_allow_triggered_looping == _allow_triggered_looping:
		return

	_allow_triggered_looping = p_allow_triggered_looping
	on_triggered_looping_changed.emit(_allow_triggered_looping)


## Sets the loop mode
func set_loop_mode(p_loop_mode: LoopMode) -> void:
	if _loop_mode == p_loop_mode:
		return

	_loop_mode = p_loop_mode
	on_loop_mode_changed.emit(_loop_mode)


## Sets the global fade state
func set_global_fade_state(use_global_fade: bool) -> void:
	if _use_global_fade == use_global_fade:
		return
	
	_use_global_fade = use_global_fade
	on_global_fade_state_changed.emit(_use_global_fade)


## Sets the global pre wait state
func set_global_pre_wait_state(use_global_pre_wait: bool) -> void:
	if _use_global_pre_wait == use_global_pre_wait:
		return
	
	_use_global_pre_wait = use_global_pre_wait
	on_global_pre_wait_state_changed.emit(_use_global_pre_wait)


## Sets the global fade speed
func set_global_fade_speed(global_fade_speed: float) -> void:
	if _global_fade == global_fade_speed:
		return
	
	_global_fade = global_fade_speed
	on_global_fade_changed.emit(_global_fade)


## Sets the global pre wait speed
func set_global_pre_wait_speed(global_pre_wait_speed: float) -> void:
	if _global_pre_wait == global_pre_wait_speed:
		return
	
	_global_pre_wait = global_pre_wait_speed
	on_global_pre_wait_changed.emit(_global_pre_wait)


## Gets the current loop mode
func get_loop_mode() -> LoopMode:
	return _loop_mode


## Gets whether triggered cues can loop back to the start
func get_allow_triggered_looping() -> bool:
	return _allow_triggered_looping


## Gets the global fade state
func get_global_fade_state() -> bool:
	return _use_global_fade


## Gets the global pre wait state
func get_global_pre_wait_state() -> bool:
	return _use_global_pre_wait


## Gets the global fade speed
func get_global_fade_speed() -> float:
	return _global_fade


## Gets the global pre wait speed
func get_global_pre_wait_speed() -> float:
	return _global_pre_wait


## Gets the active cue, or null
func get_active_cue() -> Cue:
	return _active_cue


## Seeks to the next cue in the list
func go_next() -> void:
	if not _cues:
		return
	
	seek_to(_cues[wrapi(_cues.find(_active_cue) + 1, 0, _cues.size())])


## Seeks to the previous cue in the list
func go_previous() -> void:
	if not _cues:
		return
	
	seek_to(_cues[wrapi(_cues.find(_active_cue) - 1, 0, _cues.size())])


## Seeks to a cue
func seek_to(cue: Cue) -> void:
	if cue not in _cues or (cue == _active_cue and not _cue_data_modified):
		return

	_previous_cue = _active_cue
	_active_cue = cue

	var _active_pos: int = _cues.find(_active_cue)
	var _previous_pos: int = _cues.find(_previous_cue)
	var seeking_backwards: bool = _active_pos <= _previous_pos

	var tracking_range: Array[Cue] = _cues.slice(
		0, 
		_active_pos + 1
	) if seeking_backwards or _cue_data_modified else _cues.slice(
		_previous_pos + 1,
		_active_pos + 1
	)

	var animator: CueAnimator = _create_animator(cue.name())

	if seeking_backwards and _loop_mode == LoopMode.RESET:
		animator.set_animated_data(_get_reset_tracks(animator))
		animator.name = "Reset_" + str(randi())

	for cue_to_track: Cue in tracking_range:
		var tracks: Dictionary[String, Dictionary] = animator.track(cue_to_track, _active_fixtures)
		_active_fixtures.merge(tracks, true)

	animator.set_time_scale(1 / (_global_fade if _use_global_fade else cue.get_fade_time()))
	animator.finished.connect(_on_animator_finished.bind(animator))

	_active_animators.append(animator)
	_previous_seek_direction = TransportState.BACKWARDS if seeking_backwards else TransportState.FORWARDS
	_cue_data_modified = false
	
	if _allow_follow_cues:
		_handle_cue_trigger(cue, _active_pos, animator)
	
	_set_transport_state(_previous_seek_direction)
	_set_active_state(ActiveState.ENABLED)
	_play()
	on_active_cue_changed.emit(cue)


## Creates and returns a new CueAnimator
func _create_animator(p_name: String) -> CueAnimator:
	var animator: CueAnimator = CueAnimator.new()

	animator.set_layer_id(uuid())
	animator.set_intensity(_intensity)
	animator.set_allowed_intensity_parameters(_allowed_intensity_parameters)
	on_intensity_changed.connect(animator.set_intensity)

	animator.name = p_name + "_" + str(randi())

	Core.add_child(animator)
	return animator


## Called when an animator is finished
func _on_animator_finished(p_animator: CueAnimator) -> void:
	_active_animators.erase(p_animator)	
	Core.remove_child(p_animator)

	p_animator.finished.disconnect(_on_animator_finished)
	p_animator.queue_free()

	if not _active_animators:
		_set_transport_state(TransportState.PAUSED)


## Gets reset tracks from _active_fixtures
func _get_reset_tracks(p_animator: CueAnimator) -> Dictionary[String, Dictionary]:
	var reset_tracks: Dictionary[String, Dictionary]

	for track_id: String in _active_fixtures:
		var track: Dictionary = _active_fixtures[track_id]

		reset_tracks[track_id] = track.duplicate()
		reset_tracks[track_id].merge({
			"from": track.current,
			"to": track.fixture.get_default(track.zone, track.parameter, track.function),
			"first_time": true,
			"animator": p_animator
		}, true)

	for animator: CueAnimator in _active_animators.duplicate():
		animator.stop()
	
	return reset_tracks


## Handles the next cues trigger mode
func _handle_cue_trigger(p_current_cue: Cue, p_current_cue_pos: int, p_animator: CueAnimator) -> void:
	_kill_triger_timers()
	var next_cue: Cue = null

	if p_current_cue_pos + 1 < _cues.size():
		next_cue = _cues[p_current_cue_pos + 1]

	elif _allow_triggered_looping:
		next_cue = _cues[0]
	
	if next_cue:
		var pre_wait: float = _global_pre_wait if _use_global_pre_wait else next_cue.get_pre_wait()

		match next_cue.get_trigger_mode():
			Cue.TriggerMode.AFTER_LAST:
				p_animator.finished.connect(_trigger_cue_after.bind(clampf(pre_wait, 0.001, INF), next_cue))

			Cue.TriggerMode.WITH_LAST:
				_trigger_cue_after(clampf(pre_wait, 0.001, INF), next_cue)


## Kills all cue trigger mode timers
func _kill_triger_timers() -> void:
	for timer: Timer in _active_trigger_timers.duplicate():
		_active_trigger_timers.erase(timer)
		timer.stop()

		if timer.get_parent():
			Core.remove_child(timer)


## Triggers a cue after a set wait time
func _trigger_cue_after(p_wait_time: float, p_cue: Cue) -> Timer:
	var timer: Timer = Timer.new()
	timer.timeout.connect(func ():
		_active_trigger_timers.erase(timer)

		if timer.get_parent():
			Core.remove_child(timer)
		
		seek_to(p_cue)
	)

	_active_trigger_timers.append(timer)
	Core.add_child(timer)

	timer.wait_time = p_wait_time
	timer.start()
	return timer


## Called when cue data is modified
func _on_cue_data_modified() -> void:
	_cue_data_modified


## Plays the cuelist, when paused during a crossfade
func _play() -> void:
	for animator: CueAnimator in _active_animators:
		animator.play()

	for timer: Timer in _active_trigger_timers:
		timer.paused = false


## Stops the cuelist
func _stop() -> void:
	for animator: CueAnimator in _active_animators.duplicate():
		animator.stop()

	for track: Dictionary in _active_fixtures.values():
		(track.fixture as Fixture).erase_parameter(
			track.parameter,
			uuid(),
			track.zone
		)

	_kill_triger_timers()
	_active_fixtures.clear()
	_active_cue = null
	_previous_cue = null
	on_active_cue_changed.emit(null)


## Pauses the cuelist, during a crossfade
func _pause() -> void:
	for animator: CueAnimator in _active_animators:
		animator.pause()
	
	for timer: Timer in _active_trigger_timers:
		timer.paused = true


## Override this function to handle ActiveState changes
func _handle_active_state_change(active_state: ActiveState) -> void:
	match active_state:
		ActiveState.DISABLED:
			if _active_cue:
				_stop()

		ActiveState.ENABLED:
			if not _active_cue:
				go_next()
				

## Override this function to handle TransportState changes
func _handle_transport_state_change(transport_state: TransportState) -> void:
	match transport_state:
		TransportState.FORWARDS:
			_allow_follow_cues = true
			if _active_animators and _previous_seek_direction == TransportState.FORWARDS:
				_play()
			else:
				go_next()

		TransportState.PAUSED:
			_allow_follow_cues = false
			_pause()

		TransportState.BACKWARDS:
			_allow_follow_cues = true
			if _active_animators and _previous_seek_direction == TransportState.BACKWARDS:
				_play()
			else:
				go_previous()


## Override this function to handle intensity changes
func _handle_intensity_change(p_intensity: float) -> void:
	for track_id: String in _active_fixtures:
		var data: Dictionary = _active_fixtures[track_id]

		if (data.animator == null or not data.animator.is_playing()) and data.parameter in _allowed_intensity_parameters:
			var fixture: Fixture = data.fixture
			var value: float = data.current * _intensity

			fixture.set_parameter(data.parameter, data.function, value, uuid(), data.zone)


## Called when this CueList is to be deleted
func delete(p_local_only: bool = false) -> void:
	_stop()

	for cue: Cue in _cues:
		remove_cue(cue, true)
		cue.delete(p_local_only)
	
	super.delete(p_local_only)


## Saves this cue list to a Dictionary
func serialize(p_flags: int = 0) -> Dictionary:
	return super.serialize(p_flags).merged({
		"use_global_fade": _use_global_fade,
		"use_global_pre_wait": _use_global_pre_wait,
		"global_fade": _global_fade,
		"global_pre_wait": _global_pre_wait,
		"allow_triggered_looping": _allow_triggered_looping,
		"loop_mode": _loop_mode,
		"cues": Utils.seralise_component_array(_cues, p_flags)
	}.merged({
		"active_cue_uuid": _active_cue.uuid() if _active_cue else ""
	} if p_flags & Core.SM_NETWORK else {}))


## Loads this cue list from a Dictionary
func deserialize(p_serialized_data: Dictionary) -> void:
	super.deserialize(p_serialized_data)

	_use_global_fade = type_convert(p_serialized_data.get("use_global_fade", _use_global_fade), TYPE_BOOL)
	_use_global_pre_wait = type_convert(p_serialized_data.get("use_global_pre_wait", _use_global_pre_wait), TYPE_BOOL)
	_global_fade = type_convert(p_serialized_data.get("global_fade", _global_fade), TYPE_FLOAT)
	_global_pre_wait = type_convert(p_serialized_data.get("global_pre_wait", _global_pre_wait), TYPE_FLOAT)
	_allow_triggered_looping = type_convert(p_serialized_data.get("allow_triggered_looping", _allow_triggered_looping), TYPE_BOOL)
	_loop_mode = type_convert(p_serialized_data.get("loop_mode", _loop_mode), TYPE_INT)

	add_cues(Utils.deseralise_component_array(type_convert(p_serialized_data.get("cues", []), TYPE_ARRAY)))