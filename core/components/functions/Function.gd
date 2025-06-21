# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name Function extends EngineComponent
## Base class for all functions, scenes, cuelists ect


## Emitted when the current intensity of this function changes, eg the fade position of a scene
signal on_intensity_changed(intensity: float)

## Emitted when the active state changes
signal on_active_state_changed(state: ActiveState)

## Emitted when the transport state changes
signal on_transport_state_changed(state: TransportState)

## Emitted when the PriorityMode state changes
signal on_priority_mode_state_changed(state: PriorityMode)

## Emitted when auto start is changed
signal on_auto_start_changed(auto_start: bool)

## Emitted when auto stop is changed
signal on_auto_stop_changed(auto_stop: bool)


## Active State
enum ActiveState {
	DISABLED,
	ENABLED,
}

## Transport State
enum TransportState {
	PAUSED,
	FORWARDS,
	BACKWARDS
}


## Priority Mode
enum PriorityMode {
	HTP,
	LTP
}


## Intensity of this function
var _intensity: float = 0

## Current ActiveState of this function
var _active_state: ActiveState = ActiveState.DISABLED

## Current TransportState of this function
var _transport_state: TransportState = TransportState.PAUSED

## The previous transport state before setting it to Paused
var _previous_transport_state: TransportState = TransportState.PAUSED

## The current PriorityMode
var _priority_mode: PriorityMode = PriorityMode.HTP

## Should this Function set ActiveState to ENABLED when intensity is not 0
var _auto_start: bool = true

## Should this Function set ActiveState to DISABLED when intensity is 0
var _auto_stop: bool = true

## The DataContainer used to store scene data
var _data_container: DataContainer = DataContainer.new()


## Constructor
func _init(p_uuid: String = UUID_Util.v4(), p_name: String = name) -> void:
	set_name("Function")
	set_self_class("Function")

	register_control_method("set_intensity", set_intensity, get_intensity, on_intensity_changed, [TYPE_FLOAT])
	register_control_method("on", on)
	register_control_method("off", off)
	register_control_method("toggle", toggle)
	register_control_method("play", play)
	register_control_method("pause", pause)
	register_control_method("temp", full, blackout)
	register_control_method("flash", on, off)
	register_control_method("full", full)
	register_control_method("blackout", blackout)

	register_high_frequency_signal(on_intensity_changed)
	Server.add_networked_object(_data_container.uuid, _data_container)

	super._init(p_uuid, p_name)


## Enables this Function
func on() -> void:
	set_active_state(ActiveState.ENABLED)


## Disables this function
func off() -> void:
	set_active_state(ActiveState.DISABLED)


## Toggles this scenes acive state
func toggle() -> void:
	set_active_state(int(!_active_state))


## Sets this scenes ActiveState
func set_active_state(active_state: ActiveState) -> void:
	_set_active_state(active_state)
	_handle_active_state_change(_active_state)


## Internal: Sets this scenes ActiveState
func _set_active_state(active_state: ActiveState) -> void:
	_active_state = active_state
	on_active_state_changed.emit(_active_state)


## Override this function to handle ActiveState changes
func _handle_active_state_change(active_state: ActiveState) -> void:
	pass


## Gets the ActiveState
func get_active_state() -> ActiveState:
	return _active_state


## Plays this Function, with the previous TransportState
func play() -> void:
	if _previous_transport_state:
		set_transport_state(_previous_transport_state)
	else:
		play_forwards()


## Plays this Function with TransportState.FORWARDS
func play_forwards() -> void:
	set_transport_state(TransportState.FORWARDS)


## Plays this Function with TransportState.BACKWARDS
func play_backwards() -> void:
	set_transport_state(TransportState.BACKWARDS)
	

## Pauses this function
func pause() -> void:
	set_transport_state(TransportState.PAUSED)


## Sets this Function TransportState
func set_transport_state(transport_state: TransportState) -> void:
	if _transport_state == transport_state:
		return

	_set_transport_state(transport_state)
	_handle_transport_state_change(_transport_state)


## Internal: Sets this Function TransportState
func _set_transport_state(transport_state: TransportState) -> void:
	if _transport_state:
		_previous_transport_state = _transport_state
	
	_transport_state = transport_state
	on_transport_state_changed.emit(_transport_state)


## Override this function to handle TransportState changes
func _handle_transport_state_change(transport_state: TransportState) -> void:
	pass


## Gets the current TransportState
func get_transport_state() -> TransportState:
	return _transport_state


## Blackouts this Function, by setting the intensity to 0
func blackout() -> void:
	set_intensity(0)


## Sets this Function at full, by setting the intensity to 1
func full() -> void:
	set_intensity(1)


## Sets the intensity of this function, from 0.0 to 1.0
func set_intensity(p_intensity: float) -> void:
	if p_intensity == _intensity:
		return

	var prev_intensity: float = _intensity

	_set_intensity(p_intensity)
	_handle_intensity_change(_intensity)

	if prev_intensity == 0 and p_intensity != 0 and _auto_start:
		set_active_state(ActiveState.ENABLED)
	elif prev_intensity != 0 and p_intensity == 0 and _auto_stop:
		set_active_state(ActiveState.DISABLED)
	

## Internal: Sets the intensity of this function, from 0.0 to 1.0
func _set_intensity(p_intensity: float) -> void:
	_intensity = p_intensity
	on_intensity_changed.emit(_intensity)


## Override this function to handle intensity changes
func _handle_intensity_change(p_intensity: float) -> void:
	pass


## Returnes the intensity
func get_intensity() -> float:
	return _intensity


## Sets the _priority_mode state
func set_priority_mode_state(p_priority_mode: PriorityMode) -> void:
	if p_priority_mode == _priority_mode:
		return
	
	_priority_mode = p_priority_mode
	on_priority_mode_state_changed.emit(_priority_mode)
	_handle_priority_mode_change(_priority_mode)


## Override this function to handle _priority_mode changes
func _handle_priority_mode_change(p_priority_mode: PriorityMode) -> void:
	match p_priority_mode:
		PriorityMode.HTP:
			FixtureLibrary.remove_global_ltp_layer(uuid)
		
		PriorityMode.LTP:
			FixtureLibrary.add_global_ltp_layer(uuid)


## Gets the current PriorityMode
func get_priority_mode_state() -> PriorityMode:
	return _priority_mode


## Sets the auto start state
func set_auto_start(p_auto_start: bool) -> void:
	if _auto_start == p_auto_start:
		return
	
	_auto_start = p_auto_start
	on_auto_start_changed.emit(_auto_start)


## Gets the autostart state
func get_auto_start() -> bool:
	return _auto_start


## Sets the auto stop state
func set_auto_stop(p_auto_stop: bool) -> void:
	if _auto_stop == p_auto_stop:
		return
	
	_auto_stop = p_auto_stop
	on_auto_stop_changed.emit(_auto_stop)


## Gets the auto stop state
func get_auto_stop() -> bool:
	return _auto_stop


## Returns the DataContainer 
func get_data_container() -> DataContainer:
	return _data_container


## Returns serialized version of this component, change the mode to define if this object should be serialized for saving to disk, or for networking to clients
func serialize(p_mode: int = CoreEngine.SERIALIZE_MODE_NETWORK) -> Dictionary:
	return super.serialize(p_mode).merged({
		"priority_mode": _priority_mode,
		"auto_start": _auto_start,
		"auto_stop": _auto_stop
	}.merged({
		"intensity": _intensity,
		"active_state": _active_state,
		"transport_state": _transport_state,
	} if p_mode == CoreEngine.SERIALIZE_MODE_NETWORK else {}))


## Loades this object from a serialized version
func load(p_serialized_data: Dictionary) -> void:
	set_priority_mode_state(type_convert(p_serialized_data.get("priority_mode", _priority_mode), TYPE_INT))

	_auto_start = type_convert(p_serialized_data.get("auto_start", _auto_start), TYPE_BOOL)
	_auto_stop = type_convert(p_serialized_data.get("auto_stop", _auto_stop), TYPE_BOOL)

	super.load(p_serialized_data)


## Deletes this component localy, with out contacting the server. Usefull when handling server side delete requests
func delete(p_local_only: bool = false) -> void:
	Server.remove_networked_object(_data_container.uuid)
	super.delete(p_local_only)
