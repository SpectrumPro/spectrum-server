# Copyright (c) 2025 Liam Sherwin. All rights reserved.
# This file is part of the Spectrum Lighting Controller, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

class_name DMXOutput extends EngineComponent
## Base class for all DMX outputs


## Emitted when this output connects or disconnects, added note for reason
signal connection_state_changed(state: bool, note: String)

## Emitted when the auto start state is changed
signal auto_start_changed(auto_start)


## Dictionary containing the dmx data for this output, stored as channel:value
var dmx_data: Dictionary = {}

## Autostart state
var _auto_start: bool = true

## Current connection state
var _connection_state: bool = false

## The last note given for connection status
var _previous_note: String = ""


## init
func _init(p_uuid: String = UUID.v4(), ...p_args: Array[Variant]) -> void:
	super._init(p_uuid, p_args)
	
	_set_class_name("DMXOutput")
	set_name("DMXOutput")
	
	_settings.register_setting("AutoStart", Data.Type.BOOL, set_auto_start, get_auto_start, [auto_start_changed])
	_settings.register_control("Start", Data.Type.ACTION, start)
	_settings.register_control("Stop", Data.Type.ACTION, stop)
	_settings.register_status("ConnectionStatus", Data.Type.BOOL, get_connection_state, [connection_state_changed])

	_settings.register_networked_signals_auto([
		connection_state_changed,
		auto_start_changed,
	])

	_settings.register_networked_methods_auto([
		set_auto_start,
		get_auto_start,
		get_previous_note,
		get_connection_state,
		start,
		stop,
	])


## Sets the auto start state
func set_auto_start(p_auto_start) -> void:
	_auto_start = p_auto_start
	auto_start_changed.emit(_auto_start)


## Gets the auto start state
func get_auto_start() -> bool:
	return _auto_start


## Gets the previous note
func get_previous_note() -> String:
	return _previous_note


## Gets the current connection state
func get_connection_state()-> bool:
	return _connection_state


## Starts this plugin
func start() -> void:
	connection_state_changed.emit(true, "Empty Output")


## Stops this plugin
func stop() -> void:
	connection_state_changed.emit(false, "Empty Output")


## Outputs [mebmer DMXOutput.dmx_data]
func output(dmx: Dictionary = dmx_data) -> void:
	pass
