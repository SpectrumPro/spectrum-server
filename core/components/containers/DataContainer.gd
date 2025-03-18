# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name DataContainer extends EngineComponent
## DataContainer stores fixture data


# Emitted when data is stored in this function
signal on_data_stored(fixture: Fixture, parameter: String, function: String, value: Variant, zone: String, can_fade: bool, start: float, stop: float)

## Emitted when data is erased from this function
signal on_data_erased(fixture: Fixture, parameter: String, zone: String)

## Emitted when global data is stored in this function
signal on_global_data_stored(parameter: String, function: String, value: Variant, can_fade: bool, start: float, stop: float)

## Emitted when global data is erased from this function
signal on_global_data_erased(parameter: String)


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
	return _fixture_data.duplicate()


## Gets all the global data
func get_global_data() -> Dictionary:
	return _global_data.duplicate()


## Returns all the fixture stored in the fixture data
func get_stored_fixtures() -> Array[Fixture]:
	var fixtures: Array[Fixture]
	fixtures.assign(_fixture_data.keys())

	return fixtures


## Stores data into this function
func store_data(p_fixture: Fixture, p_parameter: String, p_function: String, p_value: Variant, p_zone: String, p_can_fade: bool = true, p_start: float = 0.0, p_stop: float = 1.0) -> bool:
	if not p_value and not _allow_store_zero_data:
		return false

	_fixture_data.get_or_add(p_fixture, {}).get_or_add(p_zone, {})[p_parameter] = {
			"value": p_value,
			"function": p_function,
			"can_fade": p_can_fade,
			"start": p_start,
			"stop": p_stop
		}

	on_data_stored.emit(p_fixture, p_parameter, p_function, p_value, p_zone, p_can_fade, p_start, p_stop)

	return true


## Erases data from this function
func erase_data(p_fixture: Fixture, p_parameter: String, p_zone: String) -> bool:
	if _fixture_data.get(p_fixture, {}).get(p_zone, {}).erase(p_parameter):
		if _fixture_data[p_fixture][p_zone] == {}:
			_fixture_data[p_fixture].erase(p_zone)
		
		if _fixture_data[p_fixture] == {}:
			_fixture_data.erase(p_fixture)

		on_data_erased.emit(p_fixture, p_parameter, p_zone)
		return true

	return false


## Stores global data into this function
func store_global_data(p_parameter: String, p_function: String, p_value: Variant, p_can_fade: bool = true, p_start: float = 0.0, p_stop: float = 0.0) -> bool:
	if (not p_value and not _allow_store_zero_data) or _global_data.get(p_parameter) == p_value:
		return false
	
	_global_data[p_parameter] = {
		"value": p_value,
		"function": p_function,
		"can_fade": p_can_fade,
		"start": p_start,
		"stop": p_stop
	}
	on_global_data_stored.emit(p_parameter, p_function, p_value, p_can_fade, p_start, p_stop)

	return true


## Erases global data from this function
func erase_global_data(p_parameter: String) -> bool:
	var state: bool = _global_data.erase(p_parameter)

	if state:
		on_global_data_erased.emit(p_parameter)
	
	return state
	

## Serializes the stored data
func _serialize_stored_data() -> Dictionary:
	var serialized_stored_data: Dictionary = {}

	for fixture: Fixture in _fixture_data:
		for zone: String in _fixture_data[fixture].keys():
			for parameter: String in _fixture_data[fixture][zone].keys():
				var stored_item: Dictionary = _fixture_data[fixture][zone][parameter]

				if not fixture.uuid in serialized_stored_data:
					serialized_stored_data[fixture.uuid] = {}

				if not zone in serialized_stored_data[fixture.uuid]:
					serialized_stored_data[fixture.uuid][zone] = {}

				serialized_stored_data[fixture.uuid][zone][parameter] = {
					"value": stored_item.value,
					"function": stored_item.function,
					"can_fade": stored_item.can_fade,
					"start": stored_item.start,
					"stop": stored_item.stop,
				}
	
	return serialized_stored_data


## Loads the stored data, by calling the given method
func _load_stored_data(p_serialized_stored_data: Dictionary) -> void:
	for fixture_uuid: String in p_serialized_stored_data.keys():
		var fixture: Fixture = ComponentDB.get_component(fixture_uuid)

		if fixture is Fixture:
			for zone: String in p_serialized_stored_data[fixture_uuid]:
				for parameter: String in p_serialized_stored_data[fixture_uuid][zone]:
					var stored_item: Dictionary = p_serialized_stored_data[fixture_uuid][zone][parameter]
					
					store_data(
						fixture, 
						parameter, 
						type_convert(stored_item.get("function", ""), TYPE_STRING), 
						type_convert(stored_item.get("value", 0), TYPE_FLOAT), 
						zone, 
						type_convert(stored_item.get("can_fade", true), TYPE_BOOL),
						type_convert(stored_item.get("start", 0.0), TYPE_FLOAT),
						type_convert(stored_item.get("stop", 1.0), TYPE_FLOAT)
					)


## Serializes stored global data
func _serialize_stored_global_data() -> Dictionary:
	var serialized_stored_global_data: Dictionary = {}

	for parameter: String in _global_data.keys():
		var stored_item: Dictionary = _global_data[parameter]

		serialized_stored_global_data[parameter] = {
			"value": stored_item.value,
			"function": stored_item.function,
			"can_fade": stored_item.can_fade,
			"start": stored_item.start,
			"stop": stored_item.stop,
		}
	
	return serialized_stored_global_data


## Loads stored global data, by calling the given method
func _load_stored_global_data(p_serialized_stored_global_data: Dictionary) -> void:
	for parameter: String in p_serialized_stored_global_data.keys():
		var stored_item: Dictionary = p_serialized_stored_global_data[parameter]

		store_global_data(
			parameter, 
			type_convert(stored_item.get("function", ""), TYPE_STRING), 
			type_convert(stored_item.get("value", 0), TYPE_FLOAT),
			type_convert(stored_item.get("can_fade", true), TYPE_BOOL),
			type_convert(stored_item.get("start", 0.0), TYPE_FLOAT),
			type_convert(stored_item.get("stop", 1.0), TYPE_FLOAT)
		)


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
