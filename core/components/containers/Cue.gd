# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name Cue extends DataContainer
## Data container for CueLists, a Cue doesn't do anything by itself, and needs to be part of a CueList to work


## Emitted when the fade time it changed
signal on_fade_time_changed(new_fade_time: float)

## Emitted when the pre_wait time is changed
signal on_pre_wait_time_changed(pre_wait: float)

## Emitted when the trigger mode it changed
signal on_trigger_mode_changed(trigger_mode: TRIGGER_MODE)

## Emitted when the timecode enabled state is changed
signal on_timecode_enabled_state_changed(timecode_enabled: bool)

## Emitted when the timecode triggers change
signal on_timecode_trigger_changed(timecode_trigger: int)


## The number of this cue, do not modify this when it is a part of a cuelist
var number: float = 0

## The CueList this cue is apart of
var cue_list: CueList

## Fade in time in seconds
var fade_time: float = 2.0 : set = set_fade_time

## Pre-Wait time in seconds, how long to wait before this cue will activate, only works with TRIGGER_MODE.WITH_LAST / AFTER_LAST
var pre_wait: float = 1 : set = set_pre_wait


## Enumeration for the trigger modes
enum TRIGGER_MODE { MANUAL, AFTER_LAST, WITH_LAST }
var trigger_mode: TRIGGER_MODE = TRIGGER_MODE.MANUAL

## Tracking flag, indicates if this cue tracks changes
var tracking: bool = true

## Stores all the timecode frame counters that will trigger this cue
var timecode_trigger: int = 0

## Enables timecode triggers on this cue
var timecode_enabled: bool = false

## List of Functions that should be triggred during this cue, stored as {Function: [[method_name, [args...]]]}
var function_triggers: Dictionary = {}



## Constructor
func _component_ready() -> void:
	set_name("Cue")
	set_self_class("Cue")


## Sets the fade time in seconds
func set_fade_time(p_fade_time: float) -> void:
	fade_time = p_fade_time
	on_fade_time_changed.emit(fade_time)


## Sets the pre-wait time in seconds
func set_pre_wait(p_pre_wait: float) -> void:
	pre_wait = p_pre_wait
	on_pre_wait_time_changed.emit(pre_wait)


## Sets the trigger mode
func set_trigger_mode(p_trigger_mode: TRIGGER_MODE) -> void:
	trigger_mode = p_trigger_mode
	on_trigger_mode_changed.emit(trigger_mode)


## Sets timecode enabled
func set_timecode_enabled(p_timecode_enabled: bool) -> void:
	if timecode_enabled == p_timecode_enabled:
		return

	timecode_enabled = p_timecode_enabled
	on_timecode_enabled_state_changed.emit(timecode_enabled)


## Adds a timecode trigger
func set_timecode_trigger(frame: int) -> void:
	if frame == timecode_trigger:
		return

	timecode_trigger = frame
	on_timecode_trigger_changed.emit(timecode_trigger)


## Sets the timecode trigger to the current frame as of calling this method
func set_timecode_now() -> void:
	set_timecode_trigger(TC.frame_count)


## Returnes a serialized copy of this cue
func _on_serialize_request(mode: int) -> Dictionary:
	var serialized_function_triggers: Dictionary = {}

	for function: Function in function_triggers:
		for stored_trigger: Array in function_triggers[function]:

			if not function.uuid in serialized_function_triggers:
				serialized_function_triggers[function.uuid] = []

			serialized_function_triggers[function.uuid].append([stored_trigger[0], var_to_str(stored_trigger[1])])

	return {
		"number": number,
		"fade_time": fade_time,
		"pre_wait": pre_wait,
		"trigger_mode": trigger_mode,
		"tracking": tracking,
		"stored_data": _serialize(),
		"function_triggers": serialized_function_triggers,
		"timecode_enabled": timecode_enabled,
		"timecode_trigger": timecode_trigger,
	}


func _on_load_request(serialized_data: Dictionary) -> void:
	number = serialized_data.get("number", number)
	fade_time = serialized_data.get("fade_time", fade_time)
	pre_wait = serialized_data.get("pre_wait", pre_wait)
	trigger_mode = serialized_data.get("trigger_mode", trigger_mode)
	tracking = serialized_data.get("tracking", tracking)

	timecode_enabled = serialized_data.get("timecode_enabled", timecode_enabled)
	timecode_trigger = serialized_data.get("timecode_trigger", timecode_trigger)

	_load(serialized_data.get("stored_data", {}))
