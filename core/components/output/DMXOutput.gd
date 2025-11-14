# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name DMXOutput extends EngineComponent
## Base class for all DMX outputs


## Emitted when this output connects or disconnects, added note for reason
signal on_connection_state_changed(state: bool, note: String)

## Emitted when the auto start state is changed
signal on_auto_start_changed(auto_start)


## Dictionary containing the dmx data for this output, stored as channel:value
var dmx_data: Dictionary = {}

## Autostart state
var _auto_start: bool = true

## Current connection state
var _connection_state: bool = false

## The last note given for connection status
var _previous_note: String = ""


func _init(p_uuid: String = UUID_Util.v4(), p_name: String = _name) -> void:
	set_name("DMX Output")
	_set_self_class("DMXOutput")

	super._init()


## Sets the auto start state
func set_auto_start(p_auto_start) -> void:
	_auto_start = p_auto_start
	on_auto_start_changed.emit(_auto_start)


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
	
	on_connection_state_changed.emit(true, "Empty Output")
	# As this is the base class, this script does not connect to anything.
	print(name, " Started!")


## Stops this plugin
func stop() -> void:

	on_connection_state_changed.emit(false, "Empty Output")
	# As this is the base class, this script does not connect to anything.
	print(name, " Stoped")


## Outputs [mebmer DMXOutput.dmx_data]
func output(dmx: Dictionary = dmx_data) -> void:

	# As this is the base class, this script does not really output anything, so we are just printing the dmx data
	print(dmx_data)
