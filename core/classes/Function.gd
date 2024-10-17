# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name Function extends EngineComponent
## Base class for all functions, scenes, cuelists ect


## Emitted when data is stored in this function
signal on_data_stored(fixture: Fixture, channel_key: String, value: Variant)


## Emitted when data is eraced from this function
signal on_data_eraced(fixture: Fixture, channel_key: String)


## Emitted when the current intensity of this function changes, eg the fade position of a scene
signal on_intensity_changed(intensity: float)


## Allows this function to store zero data, ie storing the color of black, or a intensity of 0
var _allow_store_zero_data: bool = true


func _init(p_uuid: String = UUID_Util.v4()) -> void:
	set_name("Function")
	set_self_class("Function")
	register_high_frequency_signals([on_intensity_changed])
	super._init(p_uuid)


## Sets the intensity of this function, from 0.0 to 1.0
func set_intensity(p_intensity: float) -> void:
	pass


## Returnes the intensity
func get_intensity() -> float:
	return 0.0


## Stores data into this function
func store_data(fixture: Fixture, channel_key: String, value: Variant) -> bool:
	return false


## Eraces data from this function
func erace_data(fixture: Fixture, channel_key: String) -> bool:
	return false


## Static function to store saved fixture data into
func store_data_static(fixture: Fixture, channel_key: String, value: Variant, stored_data: Dictionary) -> bool:
	if (value or _allow_store_zero_data) and fixture.has_method(channel_key):
		if not fixture in stored_data.keys():
			stored_data[fixture] = {}

		stored_data[fixture][channel_key] = {
				"value": value,
				"default": fixture.get_zero_from_channel_key(channel_key)
			}

		on_data_stored.emit(fixture, channel_key, value)

		return true

	else:
		return false


func erace_data_static(fixture: Fixture, channel_key: String, stored_data: Dictionary) -> bool:
	if fixture in stored_data.keys():
		var return_state: bool = stored_data[fixture].erase(channel_key)

		if not stored_data[fixture]:
			stored_data.erase(fixture)

		if return_state:
			on_data_eraced.emit(fixture, channel_key)

		return return_state
	else:
		return false

## Serializes the stored data
func serialize_stored_data(stored_data: Dictionary) -> Dictionary:
	var serialized_stored_data: Dictionary = {}

	for fixture: Fixture in stored_data:
		for method_name: String in stored_data[fixture].keys():

			var stored_item: Dictionary = stored_data[fixture][method_name]

			if not fixture.uuid in serialized_stored_data:
				serialized_stored_data[fixture.uuid] = {}

			serialized_stored_data[fixture.uuid][method_name] = {
				"value": var_to_str(stored_item.value),
			}
	
	return serialized_stored_data


## Loads the stored data, by calling the given method
func load_stored_data(serialized_stored_data: Dictionary, stored_data: Dictionary, store_method: Callable = store_data_static) -> void:
	for fixture_uuid: String in serialized_stored_data.keys():
		if fixture_uuid in Core.fixtures:
			var fixture: Fixture = Core.fixtures[fixture_uuid]

			for channel_key: String in serialized_stored_data[fixture_uuid]:
				var stored_item: Dictionary = serialized_stored_data[fixture_uuid][channel_key]

				if fixture.has_method(channel_key):
					store_method.call(fixture, channel_key, str_to_var(stored_item.get("value", "0")), stored_data)
