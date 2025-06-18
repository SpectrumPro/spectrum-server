# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name DMXFixture extends Fixture
## Dmx Fixture


## Emitted when the channel is changed
signal on_channel_changed(channel: int)

## Emitted when the dmx data is updated, this may not contain all the current dmx data, as it will only emit changes
signal dmx_data_updated(dmx_data: Dictionary)


enum BlendMode {HTP, LTP}


## The DMX channel of this fixture
var _channel: int = 1

## The mode of this fixture
var _mode: String = ""

## The supported parameters of this fixture, there dmx channels, precedence, and ranges
## { "zone": { "parameter": { config... } } }
var _parameters: Dictionary = {}

## Stores all active values per parameter
## { "zone": { "parameter": { value: float, function: String } } }
var _active_values: Dictionary[String, Dictionary]

## Stores all active LTP parameters
## { "zone": { "parameter": [ layer_id ] } } 
var _active_ltp_parameters: Dictionary[String, Dictionary]

## All the input value layers. Mapped to the DMX value used to calculate HTP
## { "zone": { "parameter": { "layer_id": mapped_value } } }
var _mapped_layers: Dictionary[String, Dictionary] = {}

## All the input value layers as raw values
## { "zone": { "parameter": { "layer_id": { "value": float, "function": String } } } }
var _raw_layers: Dictionary[String, Dictionary] = {}

## All the input value overrides as raw values
## { "zone": { "parameter": { "value": float, "function": String } } }
var _raw_override_layers: Dictionary[String, Dictionary] = {}

## Current values of this fixture, post precedence calculation
## { "zone": { "parameter": value } }
var _current: Dictionary[String, Dictionary] = {}

## Current dmx data
## {channel, value}
var _current_dmx: Dictionary[int, int]

## Current override values of this fixture, post precedence calculation
## { "zone": { "parameter": value } }
var _current_override: Dictionary[String, Dictionary] = {}

## Current dmx data
## {channel, value}
var _current_override_dmx: Dictionary[int, int]

## Default channel values, pre-compiled
## {channel, value}
var _default: Dictionary = {}

## Current manifest
var _manifest: FixtureManifest

## Is compilation queued
var _compilation_queued: bool = false


func _component_ready() -> void:
	set_name("DMXFixture")
	set_self_class("DMXFixture")

	register_high_frequency_signals([on_parameter_changed, on_override_changed])


## Gets the channel
func get_channel() -> int:
	return _channel


## Sets the channel
func set_channel(p_channel: int) -> void:
	_channel = p_channel

	if _current:
		zero_channels()

	on_channel_changed.emit(_channel)


## Gets the fixture manifest
func get_manifest() -> FixtureManifest:
	return _manifest


## Sets the manifest for this fixture
func set_manifest(p_manifest: FixtureManifest, p_mode: String) -> void:
	_parameters = p_manifest.get_mode(p_mode).zones
	_mode = p_mode
	_manifest = p_manifest

	_current.clear()
	_default.clear()
	zero_channels()

	for zone: String in _parameters.keys():
		for attribute: String in _parameters[zone].keys():
			if len(_parameters[zone][attribute].offsets):
				_default.get_or_add(zone, {})[attribute] = get_default(zone, attribute, "", true)


	_compile_output()


## Gets the current dmx data
func get_current_dmx() -> Dictionary:
	return _current_dmx.duplicate()


# Shutter1.Shutter1Strobe, 1.0, effect_uuid, root

## Sets a parameter to a float value
func set_parameter(p_parameter: String, p_function: String, p_value: float, p_layer_id: String, p_zone: String = "root", p_disable_output: bool = false) -> bool:
	if _parameters.has(p_zone) and _parameters[p_zone].has(p_parameter) and _parameters[p_zone][p_parameter].functions.has(p_function):

		var offsets: Array = _parameters[p_zone][p_parameter].offsets
		_raw_layers.get_or_add(p_zone, {}).get_or_add(p_parameter, {})[p_layer_id] = {"value": p_value, "function": p_function}

		if offsets != []:
			var dmx_range: Array = _parameters[p_zone][p_parameter].functions[p_function].dmx_range
			var mapped_value: int = snapped(remap(p_value, 0.0, 1.0, dmx_range[0], dmx_range[1]), 1)
			var mapped_layer: Dictionary = _mapped_layers.get_or_add(p_zone, {}).get_or_add(p_parameter, {})
			mapped_layer[p_layer_id] = mapped_value

			var new_value: int

			if has_ltp_layer(p_layer_id):
				_active_ltp_parameters.get_or_add(p_zone, {}).get_or_add(p_parameter, {})[p_layer_id] = mapped_value

			if _active_ltp_parameters.get(p_zone, {}).get(p_parameter, {}):
				new_value = _active_ltp_parameters[p_zone][p_parameter].values().max()
			
			else:
				new_value = mapped_layer.values().max()
			
			if new_value != _current.get(p_zone, {}).get(p_parameter, null):
				var remapped_value: float = remap(new_value, dmx_range[0], dmx_range[1], 0.0, 1.0)
				_current.get_or_add(p_zone, {})[p_parameter] = new_value
				_active_values.get_or_add(p_zone, {})[p_parameter] = {
					"value": remapped_value,
					"function": p_function
				}

				if not p_disable_output:
					on_parameter_changed.emit(p_parameter, p_function, remapped_value, p_zone)
					_queue_compilation()
		else:
			var zones: Array = _parameters.keys()
			zones.erase(p_zone)

			for zone: String in zones:
				set_parameter(p_parameter, p_function, p_value, p_layer_id, zone, true)

			on_parameter_changed.emit(p_parameter, p_function, p_value, p_zone)
			_queue_compilation()

		return true

	return false


## Erases the parameter on the given layer
func erase_parameter(p_parameter: String, p_layer_id: String, p_zone: String = "root", p_disable_output: bool = false) -> void:
	if _raw_layers.has(p_zone) and _raw_layers[p_zone].has(p_parameter):
		var offsets: Array = _parameters[p_zone][p_parameter].offsets

		if offsets:
			var mapped_layer: Dictionary = _mapped_layers[p_zone][p_parameter]
			var raw_layer: Dictionary = _raw_layers[p_zone][p_parameter]

			mapped_layer.erase(p_layer_id)
			raw_layer.erase(p_layer_id)

			var new_value: int

			if has_ltp_layer(p_layer_id):
				_active_ltp_parameters[p_zone][p_parameter].erase(p_layer_id)

				if not _active_ltp_parameters[p_zone][p_parameter]:
					_active_ltp_parameters[p_zone].erase(p_parameter)
			
			if _active_ltp_parameters[p_zone].get(p_parameter, {}):
				new_value = _active_ltp_parameters[p_zone][p_parameter].values().max()
			
			else:
				new_value = type_convert(mapped_layer.values().max(), TYPE_INT)
			

			if mapped_layer:
				_current[p_zone][p_parameter] = new_value

			else:
				_current[p_zone].erase(p_parameter)
				_active_values.get_or_add(p_zone, {}).erase(p_parameter)

			if not p_disable_output:
				on_parameter_erased.emit(p_parameter, p_zone)
				_find_and_output_parameter_function(p_parameter, p_zone, new_value)
				_queue_compilation()

		else:
			var zones: Array = _parameters.keys()
			zones.erase(p_zone)

			for zone: String in zones:
				erase_parameter(p_parameter, p_layer_id, zone, true)

			on_parameter_erased.emit(p_parameter, p_zone)
			_find_and_output_parameter_function(p_parameter, p_zone, _current[p_zone][p_parameter])

			_queue_compilation()


## Findes a function from a parameter using the current dmx value. and outputs it via on_parameter_changed
func _find_and_output_parameter_function(p_parameter: String, p_zone: String, p_dmx_value: int) -> void:
	for function: String in _parameters[p_zone][p_parameter].functions:
		var dmx_range: Array = _parameters[p_zone][p_parameter].functions[function].dmx_range

		if p_dmx_value >= dmx_range[0] and p_dmx_value <= dmx_range[1]:
			var remapped_value: float = remap(p_dmx_value, dmx_range[0], dmx_range[1], 0, 1)
			on_parameter_changed.emit(p_parameter, function, remapped_value, p_zone)

			_active_values.get_or_add(p_zone, {})[p_parameter] = {
				"value": remapped_value,
				"function": function
			}

			return
	

## Sets a parameter override to a float value
func set_override(p_parameter: String, p_function: String, p_value: float, p_zone: String = "root", p_disable_output: bool = false) -> bool:
	if _parameters.has(p_zone) and _parameters[p_zone].has(p_parameter) and _parameters[p_zone][p_parameter].functions.has(p_function):
		var offsets: Array = _parameters[p_zone][p_parameter].offsets
		_raw_override_layers.get_or_add(p_zone, {})[p_parameter] = {"value": p_value, "function": p_function}

		if offsets != []:
			var dmx_range: Array = _parameters[p_zone][p_parameter].functions[p_function].dmx_range
			var mapped_value: int = snapped(remap(p_value, 0.0, 1.0, dmx_range[0], dmx_range[1]), 1)
			var dmx_value: int = clamp(mapped_value, 0, (256 ** len(offsets)) - 1)

			if mapped_value != _current_override.get(p_zone, {}).get(p_parameter, null):
				_current_override.get_or_add(p_zone, {})[p_parameter] = p_value

				for i in range(len(offsets)):
					var shift_amount = (offsets.size() - 1 - i) * 8
					var channel_value = (dmx_value >> shift_amount) & 0xFF
					_current_override_dmx[offsets[i] + _channel - 1] = channel_value

				if not p_disable_output:
					on_override_changed.emit(p_parameter, p_function, p_value, p_zone)
					_queue_compilation()

		else:
			var zones: Array = _parameters.keys()
			zones.erase(p_zone)

			for zone: String in zones:
				set_override(p_parameter, p_function, p_value, zone, true)

			on_override_changed.emit(p_parameter, p_function, p_value, p_zone)
			_queue_compilation()

		return true

	return false


## Erases the parameter override
func erase_override(p_parameter: String, p_zone: String = "root", p_disable_output: bool = false) -> void:
	if _raw_override_layers.has(p_zone) and _raw_override_layers[p_zone].has(p_parameter):
		var offsets: Array = _parameters[p_zone][p_parameter].offsets

		if offsets:
			for i in range(len(offsets)):
				_current_override_dmx.erase(offsets[i] + _channel - 1)

			if _raw_override_layers[p_zone].erase(p_parameter) and not _raw_override_layers[p_zone]:
				_raw_override_layers.erase(p_zone)

			_current_override[p_zone].erase(p_parameter)
			if not _current_override[p_zone]:
				_current_override.erase(p_zone)

			if not p_disable_output:
				on_override_erased.emit(p_parameter, p_zone)
				_queue_compilation()

		else:
			var zones: Array = _parameters.keys()
			zones.erase(p_zone)

			for zone: String in zones:
				erase_override(p_parameter, zone, true)

			on_override_erased.emit(p_parameter, p_zone)
			_queue_compilation()


## Erases all overrides
func erase_all_overrides() -> void:
	_current_override_dmx.clear()
	_current_override.clear()
	_raw_override_layers.clear()
	_compile_output()

	on_all_override_removed.emit()


## Gets all the override values
func get_all_override_values() -> Dictionary:
	return _raw_override_layers.duplicate(true)


## Gets all the values
func get_all_values_layered() -> Dictionary:
	return _raw_layers.duplicate(true)


## Gets all the values
func get_all_values() -> Dictionary:
	return _active_values.duplicate(true)


## Gets all the parameters and there category from a zone
func get_parameter_categories(p_zone: String) -> Dictionary:
	return _manifest.get_categorys(_mode, p_zone)


## Gets all the parameter functions
func get_parameter_functions(p_zone: String, p_parameter: String) -> Array:
	return _manifest.get_parameter_functions(_mode, p_zone, p_parameter)


## Gets the default value of a parameter
func get_default(p_zone: String, p_parameter: String, p_function: String = "", p_raw_dmx: bool = false) -> float:
	if p_function == "":
		p_function = get_default_function(p_zone, p_parameter)

	var dmx_value: int = _parameters[p_zone][p_parameter].functions[p_function].default
	var range: Array = _parameters[p_zone][p_parameter].functions[p_function].dmx_range

	if p_raw_dmx:
		return dmx_value
	else:
		return remap(dmx_value, range[0], range[1], 0.0, 1.0)


## Gets the force default value of a parameter
func get_force_default(p_zone: String, p_parameter: String, p_function: String = "", p_raw_dmx: bool = false) -> float:
	if has_force_default(p_function):
		return get_default(p_zone, p_parameter)

	else:
		return 0.0


## Gets the default function for a zone and parameter, or the first function if none can be found
func get_default_function(p_zone: String, p_parameter: String) -> String:
	var default_function: String = _parameters[p_zone][p_parameter].default_function
	var functions: Dictionary = _parameters[p_zone][p_parameter].functions

	if functions.has(default_function):
		return default_function
	else:
		return functions.keys()[0]


## Gets the current value, or the default
func get_current_value(p_zone: String, p_parameter: String, p_allow_default: bool = true) -> float:
	return _active_values.get(p_zone, {}).get(p_parameter, {}).get("value", get_default(p_zone, p_parameter) if p_allow_default else 0.0)


## Gets the current value, or the default
func get_current_value_or_force_default(p_zone: String, p_parameter: String) -> float:
	var value: float = _active_values.get(p_zone, {}).get(p_parameter, {}).get("value", -1)

	if value == -1:
		if has_force_default(p_parameter):
			return get_default(p_zone, p_parameter)
		else:
			return 0.0
	else:
		return value


## Gets a value from the given layer id, parameter, and zone
func get_current_value_layered(p_zone: String, p_parameter: String, p_layer_id: String, p_function: String = "", p_allow_default: bool = true) -> float:
	return _raw_layers.get(p_zone, {}).get(p_parameter, {}).get(p_layer_id, {}).get("value", get_default(p_zone, p_parameter, p_function) if p_allow_default else 0.0)


## Gets the current value from a given layer ID, the default is none is present, or 0 if p_parameter is not a force default
func get_current_value_layered_or_force_default(p_zone: String, p_parameter: String, p_layer_id: String, p_function: String = "") -> float:
	var value: float = _raw_layers.get(p_zone, {}).get(p_parameter, {}).get(p_layer_id, {}).get("value", -1)

	if value == -1:
		if has_force_default(p_parameter):
			return get_default(p_zone, p_parameter, p_function)
		else:
			return 0.0
	else:
		return value


## Gets all the zones
func get_zones() -> Array[String]:
	return _manifest.get_zones(_mode)


## Checks if this DMXFixture has any overrides
func has_overrides() -> bool:
	return _raw_override_layers != {}


## Checks if this fixture has a parameter
func has_parameter(p_zone: String, p_parameter: String, p_function: String = "") -> bool:
	if p_function:
		return _manifest.has_function(_mode, p_zone, p_parameter, p_function)
	else:
		return _manifest.has_parameter(_mode, p_zone, p_parameter)


## Checks if a parameter is a force default
func has_force_default(p_parameter: String) -> bool:
	return _manifest.has_force_default(p_parameter)


## Checks if this DMXFixture has a function that can fade
func function_can_fade(p_zone: String, p_parameter: String, p_function: String) -> bool:
	return _manifest.function_can_fade(_mode, p_zone, p_parameter, p_function)


## Updates dmx data with all zeros
func zero_channels() -> void:
	for zone: String in _parameters.keys():
		for attribute: String in _parameters[zone].keys():
			if len(_parameters[zone][attribute].offsets):
				_current.get_or_add(zone, {})[attribute] = 0

	_current_dmx.clear()
	_compile_output()
	_current.clear()



## Queues compilation for the end of the frame
func _queue_compilation() -> void:
	if _compilation_queued:
		return

	_compilation_queued = true
	_compile_output.call_deferred()



## Compiles the inputted data with internal data and overrides and outputs the result
func _compile_output() -> void:
	for zone: String in _current.keys() if _current else _default.keys():
		var zone_merged: Dictionary = _current.get(zone, {}).merged(_default.get(zone, {}))
		for parameter: String in zone_merged.keys():
			var offset: Array[int] = _parameters[zone][parameter].offsets
			var value: int = clamp(zone_merged[parameter], 0, (256 ** len(offset)) - 1)

			for i in range(len(offset)):
				var shift_amount = (offset.size() - 1 - i) * 8
				var channel_value = (value >> shift_amount) & 0xFF
				_current_dmx[offset[i] + _channel - 1] = channel_value

	var final_dmx: Dictionary = _current_dmx.merged(_current_override_dmx, true)
	dmx_data_updated.emit(final_dmx)
	_compilation_queued = false


## Saves this DMXFixture to a dictonary
func _on_serialize_request(p_mode: int) -> Dictionary:
	var seralized_data: Dictionary = {
		"channel": _channel,
		"mode": _mode,
		"manifest_uuid": _manifest.uuid if _manifest else ""
	}

	if p_mode == Core.SERIALIZE_MODE_NETWORK:
		seralized_data.merge({
			"raw_override_layers": get_all_override_values(),
			"active_values": get_all_values()
		})

	return seralized_data


## Loads this DMXFixture from a dictonary
func _on_load_request(p_serialized_data: Dictionary) -> void:
	set_channel(type_convert(p_serialized_data.get("channel"), TYPE_INT))

	_mode = type_convert(p_serialized_data.get("mode", ""), TYPE_STRING)
	var manifest_uuid: String = type_convert(p_serialized_data.get("manifest_uuid"), TYPE_STRING)
	if manifest_uuid:
		FixtureLibrary.request_manifest(manifest_uuid).then(func(manifest: FixtureManifest):
			set_manifest(manifest, _mode)
		)


## Prints manifest info to console
func dump_manifest() -> void:
	print(_manifest._modes)
