# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name DMXOutput extends EngineComponent
## Base class for all DMX outputs


## Emited when this output connects or disconnects, added note for reason
signal on_connection_state_changed(state: bool, note: String)


## Dictionary containing the dmx data for this output, stored as channel:value
var dmx_data: Dictionary = {}


func _init(p_uuid: String = UUID_Util.v4(), p_name: String = name) -> void:
	set_name("DMX Output")
	set_self_class("DMXOutput")

	super._init()


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
func output() -> void:

	# As this is the base class, this script does not really output anything, so we are just printing the dmx data
	print(dmx_data)