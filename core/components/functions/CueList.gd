# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name CueList extends Function
## A list of cues


## Emitted when the active cue is changed
signal on_active_cue_changed(cue: Cue)

## Emitted when a cues crossfade is finished
signal on_cue_crossfade_finished(cue: Cue)

## Emitted when the global fade state is changed
signal on_global_fade_state_changed(use_global_fade: bool)

## Emitted when the global pre_wait state is changed
signal on_global_pre_wait_state_changed(use_global_pre_wait: bool)

## Emitted when the global fade is changed
signal on_global_fade_changed(global_fade: float)

## Emitted when the global pre_wait is changed
signal on_global_pre_wait_changed(global_pre_wait: float)

## Emitted when a cue is added to this CueList
signal on_cues_added(cues: Array)

## Emitted when a cue is removed from this CueList
signal on_cues_removed(cues: Array)

## Emitted when a cue's position has changed
signal on_cue_order_changed(cue: Cue, position: int)

## Emitted when the loop mode is changed
signal on_loop_mode_changed(loop_mode: LoopMode)


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

## Global fade state
var _use_global_fade: bool = false

## Global pre wait state
var _use_global_pre_wait: bool = false

## Global fade time
var _global_fade: float = 1

## Global pre wait
var _global_pre_wait: float = 1

## Has this cuelist paused during a crossfade between two or more cues
var _has_paused_during_crossfade: bool

## All active animators
var _active_animators: Array[CueAnimator]


func _component_ready() -> void:
	set_name("CueList")
	set_self_class("CueList")


## Adds a cue to the list
func add_cue(p_cue: Cue, p_no_signal: bool = false) -> bool:
	if p_cue in _cues:
		return false
	
	_cues.append(p_cue)
	p_cue.on_delete_requested.connect(remove_cue.bind(p_cue))
	Server.register_component(p_cue)

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
	Server.deregister_component(p_cue)

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
func set_cue_position(cue: Cue, position: int) -> void:
	if cue not in _cues:
		return
	
	var old_index: int = _cues.find(cue)
	_cues.insert(position, cue)
	_cues.remove_at(old_index)

	on_cue_order_changed.emit(cue, position)


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
	on_global_fade_state_changed.emit(_use_global_pre_wait)


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
	on_global_fade_changed.emit(_global_pre_wait)


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
	if cue not in _cues or cue == _active_cue:
		return

	_previous_cue = _active_cue
	_active_cue = cue

	var tracking_range: Array[Cue] = _cues.slice(
		clamp(_cues.find(_previous_cue), 0, INF), 
		clamp(_cues.find(_active_cue), 0, INF) + 1
	)
	var animator: CueAnimator = _create_animator()

	for cue_to_track: Cue in tracking_range:
		animator.track(cue_to_track)

	animator.set_time_scale(1 / _global_fade if _use_global_fade else cue.fade_time)
	animator.finished.connect(_on_animator_finished.bind(animator))

	_active_animators.append(animator)
	_play()


## Creates and returns a new CueAnimator
func _create_animator() -> CueAnimator:
	var animator: CueAnimator = CueAnimator.new()

	animator.set_layer_id(uuid)
	animator.set_allowed_intensity_parameters(_allowed_intensity_parameters)

	Core.add_child(animator)
	return animator


## Called when an animator is finished
func _on_animator_finished(animator: CueAnimator) -> void:
	_active_animators.erase(animator)


## Plays the cuelist, when paused during a crossfade
func _play() -> void:
	for animator: CueAnimator in _active_animators:
		animator.play()


## Stops the cuelist
func _stop() -> void:
	for animator: CueAnimator in _active_animators:
		animator.stop()
	
	_active_cue = null
	_previous_cue = null


## Pauses the cuelist, during a crossfade
func _pause() -> void:
	for animator: CueAnimator in _active_animators:
		animator.pause()


## Override this function to handle ActiveState changes
func _handle_active_state_change(active_state: ActiveState) -> void:
	match active_state:
		ActiveState.DISABLED:
			if _active_cue:
				_stop()

		ActiveState.ENABLED:
			if not  _active_cue:
				go_next()
				

## Override this function to handle TransportState changes
func _handle_transport_state_change(transport_state: TransportState) -> void:
	match transport_state:
		TransportState.FORWARDS:
			if _has_paused_during_crossfade:
				_play()
			else:
				go_next()

		TransportState.PAUSED:
			_pause()

		TransportState.BACKWARDS:
			if _has_paused_during_crossfade:
				_play()
			else:
				go_previous()


## Override this function to handle intensity changes
func _handle_intensity_change(p_intensity: float) -> void:
	pass



## Saves this cue list to a Dictionary
func _on_serialize_request(p_mode: int) -> Dictionary:
	return {
		"use_global_fade": _use_global_fade,
		"use_global_pre_wait": _use_global_pre_wait,
		"global_fade": _global_fade,
		"global_pre_wait": _global_pre_wait,
		"cues": Utils.seralise_component_array(_cues)
	}


## Loads this cue list from a Dictionary
func _on_load_request(serialized_data: Dictionary) -> void:
	_use_global_fade = type_convert(serialized_data.get("use_global_fade", _use_global_fade), TYPE_BOOL)
	_use_global_pre_wait = type_convert(serialized_data.get("use_global_pre_wait", _use_global_pre_wait), TYPE_BOOL)
	_global_fade = type_convert(serialized_data.get("global_fade", _global_fade), TYPE_FLOAT)
	_global_pre_wait = type_convert(serialized_data.get("global_pre_wait", _global_pre_wait), TYPE_FLOAT)

	add_cues(Utils.deseralise_component_array(type_convert(serialized_data.get("cues", []), TYPE_ARRAY)))


## Called when this CueList is to be deleted
func _on_delete_request() -> void:
	_stop()

	for cue: Cue in _cues:
		remove_cue(cue, true)
		cue.delete()
