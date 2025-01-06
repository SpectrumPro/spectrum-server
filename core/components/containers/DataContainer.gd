# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name DataContainer extends EngineComponent
## DataContainer stores fixture data


# Emitted when data is stored in this function
signal on_data_stored(fixture: Fixture, parameter_key: String, value: Variant)

## Emitted when data is erased from this function
signal on_data_erased(fixture: Fixture, parameter_key: String)

## Emitted when global data is stored in this function
signal on_global_data_stored(parameter_key: String, value: Variant)

## Emitted when globaldata is erased from this function
signal on_global_data_erased(parameter_key: String)



## Allows this function to store zero data, ie storing the color of black, or a intensity of 0
var _allow_store_zero_data: bool = true

## Stored fixture data
var _fixture_data: Dictionary = {}

## Stored global data
var _global_data: Dictionary = {}



## Constructor
func _init(p_uuid: String = UUID_Util.v4(), p_name: String = name) -> void:
	set_name("DataContainer")
	set_self_class("DataContainer")
	super._init(p_uuid, p_name)


## Changes the zero data store state
func set_allow_store_zero_data(state: bool) -> void:
	_allow_store_zero_data = state


## Gets all the fixture data
func get_fixture_data() -> Dictionary:
	return _fixture_data


## Gets all the global data
func get_global_data() -> Dictionary:
	return _global_data


## Stores data into this function
func store_data(p_fixture: Fixture, p_parameter_key: String, p_value: Variant) -> bool: 
	if not p_value and not _allow_store_zero_data:
		return false

	if not p_fixture in _fixture_data.keys():
		_fixture_data[p_fixture] = {}

	_fixture_data[p_fixture][p_parameter_key] = {
			"value": p_value,
		}

	on_data_stored.emit(p_fixture, p_parameter_key, p_value)

	return true


## Erases data from this function
func erase_data(p_fixture: Fixture, p_parameter_key: String) -> bool:
	var state: bool = _fixture_data[p_fixture].erase(p_parameter_key)

	if not _fixture_data[p_fixture]:
		_fixture_data.erase(p_fixture)

	if state:
		on_data_erased.emit(p_fixture, p_parameter_key)

	return state


## Stores global data into this function
func store_global_data(p_parameter_key: String, p_value: Variant) -> bool:
	if (not p_value and not _allow_store_zero_data) or _global_data.get(p_parameter_key) == p_value:
		return false
	
	_global_data[p_parameter_key] = p_value
	on_global_data_stored.emit(p_parameter_key, p_value)

	return true


## Erases global data from this function
func erase_global_data(p_parameter_key: String) -> bool:
	var state: bool =  _global_data.erase(p_parameter_key)

	if state:
		on_global_data_erased.emit(p_parameter_key)
	
	return state


## Serializes the stored data
func _serialize_stored_data() -> Dictionary:
	var serialized_stored_data: Dictionary = {}

	for fixture: Fixture in _fixture_data:
		for parameter_key: String in _fixture_data[fixture].keys():

			var stored_item: Dictionary = _fixture_data[fixture][parameter_key]

			if not fixture.uuid in serialized_stored_data:
				serialized_stored_data[fixture.uuid] = {}

			serialized_stored_data[fixture.uuid][parameter_key] = {
				"value": var_to_str(stored_item.value),
			}
	
	return serialized_stored_data


## Loads the stored data, by calling the given method
func _load_stored_data(p_serialized_stored_data: Dictionary) -> void:
	for fixture_uuid: String in p_serialized_stored_data.keys():
		if ComponentDB.components.get(fixture_uuid) is Fixture:
			var fixture: Fixture = ComponentDB.components[fixture_uuid]

			for parameter_key: String in p_serialized_stored_data[fixture_uuid]:
				var stored_item: Dictionary = p_serialized_stored_data[fixture_uuid][parameter_key]

				if fixture.has_method(parameter_key):
					store_data(fixture, parameter_key, str_to_var(stored_item.get("value", "0")))


## Serializes stored global data
func _serialize_stored_global_data() -> Dictionary:
	var serialized_stored_global_data: Dictionary = {}

	for parameter_key: String in _global_data.keys():
		var value: Variant = _global_data[parameter_key]

		serialized_stored_global_data[parameter_key] = {
			"value": var_to_str(value),
		}
	
	return serialized_stored_global_data


## Loads stored global data, by calling the given method
func _load_stored_global_data(p_serialized_stored_global_data: Dictionary) -> void:
	for parameter_key: String in p_serialized_stored_global_data.keys():
		var data: Dictionary = p_serialized_stored_global_data[parameter_key]

		store_global_data(parameter_key, str_to_var(data.get("value", "0")))


## Serializes this scene and returnes it in a dictionary
func _serialize() -> Dictionary:
	return {
		"fixture_data": _serialize_stored_data(),
		"global_data": _serialize_stored_global_data(),
	}


## Called when this scene is to be loaded from serialized data
func _load(serialized_data: Dictionary) -> void:
	_load_stored_data(serialized_data.get("fixture_data", {}))
	_load_stored_global_data(serialized_data.get("global_data", {}))


## Serializes this Datacontainer and returnes it in a dictionary
func _on_serialize_request(mode: int) -> Dictionary: return _serialize()

## Loads this DataContainer from a dictonary
func _on_load_request(serialized_data) -> void: _load(serialized_data)
