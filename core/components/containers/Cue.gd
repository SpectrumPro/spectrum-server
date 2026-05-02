# Copyright (c) 2026 Liam Sherwin. All rights reserved.
# This file is part of the Spectrum Lighting Controller, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

class_name Cue extends DataContainer
## Data container for CueLists, a Cue doesn't do anything by itself, and needs to be part of a CueList to work


## Emitted when the QID is changed
signal qid_changed(qid: String)

## Emitted when the fade time it changed
signal fade_time_changed(new_fade_time: float)

## Emitted when the pre_wait time is changed
signal pre_wait_time_changed(pre_wait: float)

## Emitted when the trigger mode it changed
signal trigger_mode_changed(trigger_mode: TriggerMode)

## Emitted when the tracking state is changed
signal tracking_mode_changed(tracking_mode: TrackingMode)


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


## init
func _init(p_uuid: String = UUID.v4(), ...p_args: Array[Variant]) -> void:
	super._init(p_uuid, p_args)
	
	_set_class_name("Cue")
	set_name("Cue")
	
	_settings.register_setting("QID", Data.Type.STRING, set_qid, get_qid, [qid_changed])
	_settings.register_setting("TriggerMode", Data.Type.ENUM, set_trigger_mode, get_trigger_mode, [trigger_mode_changed]).set_enum_dict(TriggerMode)
	_settings.register_setting("TrackingMode", Data.Type.ENUM, set_tracking_mode, get_tracking_mode, [tracking_mode_changed]).set_enum_dict(TrackingMode)
	_settings.register_control("FadeTime", Data.Type.FLOAT, set_fade_time, get_fade_time, [fade_time_changed])
	_settings.register_control("PreWait", Data.Type.FLOAT, set_pre_wait, get_pre_wait, [pre_wait_time_changed])

	_settings.register_networked_methods_auto([
		set_qid,
		set_fade_time,
		set_pre_wait,
		set_trigger_mode,
		set_tracking_mode,
		get_qid,
		get_fade_time,
		get_pre_wait,
		get_trigger_mode,
		get_tracking_mode,
	])

	_settings.register_networked_signals_auto([
		qid_changed,
		fade_time_changed,
		pre_wait_time_changed,
		trigger_mode_changed,
		tracking_mode_changed,
	])


## Sets this Cue's QID
func set_qid(p_qid: String) -> void:
	if p_qid == _qid:
		return
	
	_qid = p_qid
	qid_changed.emit(_qid)


## Sets the fade time in seconds
func set_fade_time(p_fade_time: float) -> void:
	if p_fade_time == _fade_time:
		return
	
	_fade_time = p_fade_time
	fade_time_changed.emit(_fade_time)


## Sets the pre-wait time in seconds
func set_pre_wait(p_pre_wait: float) -> void:
	if p_pre_wait == _pre_wait:
		return
	
	_pre_wait = p_pre_wait
	pre_wait_time_changed.emit(_pre_wait)


## Sets the trigger mode
func set_trigger_mode(p_trigger_mode: TriggerMode) -> void:
	if p_trigger_mode == _trigger_mode:
		return
	
	_trigger_mode = p_trigger_mode
	trigger_mode_changed.emit(_trigger_mode)


## Sets the tracking mode state
func set_tracking_mode(p_tracking_mode: TrackingMode) -> void:
	if p_tracking_mode == _tracking_mode:
		return
	
	_tracking_mode = p_tracking_mode
	tracking_mode_changed.emit(_tracking_mode)


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
func serialize(p_flags: Data.SerializationFlags = Data.SerializationFlags.NONE) -> Dictionary:
	return super.serialize(p_flags).merged({
		"qid": _qid,
		"fade_time": _fade_time,
		"pre_wait": _pre_wait,
		"trigger_mode": _trigger_mode,
		"tracking_mode": _tracking_mode,
	})


## Loads this Cue from a dictionary
func deserialize(p_serialized_data: Dictionary, p_flags: Data.SerializationFlags = Data.SerializationFlags.NONE) -> void:
	super.deserialize(p_serialized_data, p_flags)
	
	_qid = type_convert(p_serialized_data.get("qid", _qid), TYPE_STRING)
	_fade_time = type_convert(p_serialized_data.get("fade_time", _fade_time), TYPE_FLOAT)
	_pre_wait = type_convert(p_serialized_data.get("pre_wait", _pre_wait), TYPE_FLOAT)
	_trigger_mode = type_convert(p_serialized_data.get("trigger_mode", _trigger_mode), TYPE_INT)
	_tracking_mode = type_convert(p_serialized_data.get("tracking_mode", _tracking_mode), TYPE_INT)
