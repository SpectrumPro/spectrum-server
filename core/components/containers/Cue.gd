# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name Cue extends DataContainer
## Data container for CueLists, a Cue doesn't do anything by itself, and needs to be part of a CueList to work


## Emitted when the fade time it changed
signal on_fade_time_changed(new_fade_time: float)

## Emitted when the pre_wait time is changed
signal on_pre_wait_time_changed(pre_wait: float)

## Emitted when the trigger mode it changed
signal on_trigger_mode_changed(trigger_mode: Trigger)

## Emitted when the timecode enabled state is changed
signal on_timecode_enabled_state_changed(timecode_enabled: bool)

## Emitted when the timecode triggers change
signal on_timecode_trigger_changed(timecode_trigger: int)


## Enumeration for the trigger modes
enum Trigger { MANUAL, AFTER_LAST, WITH_LAST }

## The number of this cue, do not modify this when it is a part of a cuelist
var number: float = 0

## The CueList this cue is apart of
var cue_list: CueList

## Fade in time in seconds
var fade_time: float = 2.0 : set = set_fade_time

## Pre-Wait time in seconds, how long to wait before this cue will activate, only works with TRIGGER_MODE.WITH_LAST / AFTER_LAST
var pre_wait: float = 1 : set = set_pre_wait

## Trigger mode
var trigger_mode: Trigger = Trigger.MANUAL

## Tracking flag, indicates if this cue tracks changes
var tracking: bool = true

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
func set_trigger_mode(p_trigger_mode: Trigger) -> void:
	trigger_mode = p_trigger_mode
	on_trigger_mode_changed.emit(trigger_mode)


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
	}


func _on_load_request(serialized_data: Dictionary) -> void:
	number = serialized_data.get("number", number)
	fade_time = serialized_data.get("fade_time", fade_time)
	pre_wait = serialized_data.get("pre_wait", pre_wait)
	trigger_mode = serialized_data.get("trigger_mode", trigger_mode)
	tracking = serialized_data.get("tracking", tracking)

	_load(serialized_data.get("stored_data", {}))
