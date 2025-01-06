# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name Function extends EngineComponent
## Base class for all functions, scenes, cuelists ect


## Emitted when the current intensity of this function changes, eg the fade position of a scene
signal on_intensity_changed(intensity: float)


## Intensity of this function
var _intensity: float = 0


## The DataContainer used to store scene data
var _data_container: DataContainer = DataContainer.new()


## Constructor
func _init(p_uuid: String = UUID_Util.v4(), p_name: String = name) -> void:
	set_name("Function")
	set_self_class("Function")

	register_high_frequency_signals([on_intensity_changed])
	Server.add_networked_object(_data_container.uuid, _data_container)

	super._init(p_uuid, p_name)


## Sets the intensity of this function, from 0.0 to 1.0
func set_intensity(p_intensity: float) -> void:
	if not p_intensity == _intensity:
		return
	
	_intensity = p_intensity
	on_intensity_changed.emit()


## Returnes the intensity
func get_intensity() -> float:
	return _intensity


## Returns the DataContainer 
func get_data_container() -> DataContainer:
	return _data_container


## Deletes this component localy, with out contacting the server. Usefull when handling server side delete requests
func delete() -> void:
	Server.remove_networked_object(_data_container.uuid)
	super.delete()
