# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name Cue extends DataContainer
## Data container for CueLists, a Cue doesn't do anything by itself, and needs to be part of a CueList to work


## Emitted when the QID is changed
signal on_qid_changed(qid: String)

## Emitted when the fade time it changed
signal on_fade_time_changed(new_fade_time: float)

## Emitted when the pre_wait time is changed
signal on_pre_wait_time_changed(pre_wait: float)

## Emitted when the trigger mode it changed
signal on_trigger_mode_changed(trigger_mode: TriggerMode)

## Emitted when the tracking state is changed
signal on_tracking_mode_changed(tracking_mode: TrackingMode)


## Enumeration for the trigger modes
enum TriggerMode { MANUAL, AFTER_LAST, WITH_LAST }

## Enum for the tracking modes
enum TrackingMode { TRACKING, RESET }


## the QID of this Cue
var _qid: String = ""

## Fade in time in seconds
var _fade_time: float = 2.0

## Pre-Wait time in seconds, how long to wait before this cue will activate, only works with TRIGGER_MODE.WITH_LAST / AFTER_LAST
var _pre_wait: float = 1

## Trigger mode
var _trigger_mode: TriggerMode = TriggerMode.MANUAL

## Tracking flag, indicates if this cue tracks changes
var _tracking_mode: TrackingMode = TrackingMode.TRACKING


## Constructor
func _component_ready() -> void:
	set_name("Cue")
	set_self_class("Cue")


## Sets this Cue's QID
func set_qid(p_qid: String) -> void:
	if p_qid == _qid:
		return
	
	_qid = p_qid
	on_qid_changed.emit(_qid)


## Sets the fade time in seconds
func set_fade_time(p_fade_time: float) -> void:
	if p_fade_time == _fade_time:
		return
	
	_fade_time = p_fade_time
	on_fade_time_changed.emit(_fade_time)


## Sets the pre-wait time in seconds
func set_pre_wait(p_pre_wait: float) -> void:
	if p_pre_wait == _pre_wait:
		return
	
	_pre_wait = p_pre_wait
	on_pre_wait_time_changed.emit(_pre_wait)


## Sets the trigger mode
func set_trigger_mode(p_trigger_mode: TriggerMode) -> void:
	if p_trigger_mode == _trigger_mode:
		return
	
	_trigger_mode = p_trigger_mode
	on_trigger_mode_changed.emit(_trigger_mode)


## Sets the tracking mode state
func set_tracking_mode(p_tracking_mode: TrackingMode) -> void:
	if p_tracking_mode == _tracking_mode:
		return
	
	_tracking_mode = p_tracking_mode
	on_tracking_mode_changed.emit(_tracking_mode)


## Returns the QID
func get_qid() -> String:
	return _qid


## Returns the fade time in seconds
func get_fade_time() -> float:
	return _fade_time


## Returns the pre-wait time in seconds
func get_pre_wait() -> float:
	return _pre_wait


## Gets the trigger mode
func get_trigger_mode() -> TriggerMode:
	return _trigger_mode


## Gets the tracking mode
func get_tracking_mode() -> TrackingMode:
	return _tracking_mode


## Returnes a serialized copy of this cue
func _on_serialize_request(p_flags: int) -> Dictionary:
	return {
		"qid": _qid,
		"fade_time": _fade_time,
		"pre_wait": _pre_wait,
		"trigger_mode": _trigger_mode,
		"tracking_mode": _tracking_mode,
		"stored_data": _serialize(),
	}


## Loads this Cue from a dictionary
func _on_load_request(serialized_data: Dictionary) -> void:
	_qid = type_convert(serialized_data.get("qid", _qid), TYPE_STRING)
	_fade_time = type_convert(serialized_data.get("fade_time", _fade_time), TYPE_FLOAT)
	_pre_wait = type_convert(serialized_data.get("pre_wait", _pre_wait), TYPE_FLOAT)
	_trigger_mode = type_convert(serialized_data.get("trigger_mode", _trigger_mode), TYPE_INT)
	_tracking_mode = type_convert(serialized_data.get("tracking_mode", _tracking_mode), TYPE_INT)

	_load(type_convert(serialized_data.get("stored_data", {}), TYPE_DICTIONARY))
