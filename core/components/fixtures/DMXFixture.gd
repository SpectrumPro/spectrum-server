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


## Gets the current dmx data
func get_current_dmx() -> Dictionary:
	return _current_dmx.duplicate()


# Shutter1.Shutter1Strobe, 1.0, effect_uuid, root

## Sets a parameter to a float value
func set_parameter(p_parameter: String, p_function: String, p_value: float, p_layer_id: String, p_zone: String = "root", p_disable_output: bool = false) -> void:
	if _parameters.has(p_zone) and _parameters[p_zone].has(p_parameter) and _parameters[p_zone][p_parameter].functions.has(p_function):
		var offsets: Array = _parameters[p_zone][p_parameter].offsets
		_raw_layers.get_or_add(p_zone, {}).get_or_add(p_parameter, {})[p_layer_id] = {"value": p_value, "function": p_function}

		if offsets != []:
			var dmx_range: Array = _parameters[p_zone][p_parameter].functions[p_function].dmx_range
			var mapped_value: int = snapped(remap(p_value, 0.0, 1.0, dmx_range[0], dmx_range[1]), 1)
			var mapped_layer: Dictionary = _mapped_layers.get_or_add(p_zone, {}).get_or_add(p_parameter, {})
			mapped_layer[p_layer_id] = mapped_value

			var max: int = mapped_layer.values().max()
			
			if max != _current.get(p_zone, {}).get(p_parameter, null):
				_current.get_or_add(p_zone, {})[p_parameter] = mapped_value

				if not p_disable_output:
					on_parameter_changed.emit(p_parameter, p_function, p_value, p_zone)
					_compile_output()
		else:
			var zones: Array = _parameters.keys()
			zones.erase(p_zone)
			
			for zone: String in zones:
				set_parameter(p_parameter, p_function, p_value, p_layer_id, zone, true)
			
			on_parameter_changed.emit(p_parameter, p_function, p_value, p_zone)
			_compile_output()


## Erases the parameter on the given layer
func erase_parameter(p_parameter: String, p_layer_id: String, p_zone: String = "root", p_disable_output: bool = false) -> void:
	if _raw_layers.has(p_zone) and _raw_layers[p_zone].has(p_parameter):
		var offsets: Array = _parameters[p_zone][p_parameter].offsets

		if offsets:
			var mapped_layer: Dictionary = _mapped_layers[p_zone][p_parameter]
			var raw_layer: Dictionary = _raw_layers[p_zone][p_parameter]

			mapped_layer.erase(p_layer_id)
			raw_layer.erase(p_layer_id)
			var max: Variant = mapped_layer.values().max()
			
			if max and max != _current[p_zone][p_parameter]:
				_current[p_zone][p_parameter] = max

				if not p_disable_output:
					on_parameter_erased.emit(p_parameter, p_zone)
					_compile_output()
			else:
				_current[p_zone].erase(p_parameter)
		
		else:
			var zones: Array = _parameters.keys()
			zones.erase(p_zone)
			
			for zone: String in zones:
				erase_parameter(p_parameter, p_layer_id, zone, true)
			
			on_parameter_erased.emit(p_parameter, p_zone)
			_compile_output()


## Sets a parameter override to a float value
func set_override(p_parameter: String, p_function: String, p_value: float, p_zone: String = "root", p_disable_output: bool = false) -> void:
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
					_compile_output()
		
		else:
			var zones: Array = _parameters.keys()
			zones.erase(p_zone)
			
			for zone: String in zones:
				set_override(p_parameter, p_function, p_value, zone, true)
			
			on_override_changed.emit(p_parameter, p_function, p_value, p_zone)
			_compile_output()
		


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
				_compile_output()
		
		else:
			var zones: Array = _parameters.keys()
			zones.erase(p_zone)
			
			for zone: String in zones:
				erase_override(p_parameter, zone, true)
			
			on_override_erased.emit(p_parameter, p_zone)
			_compile_output()


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


## Checks if this DMXFixture has any overrides
func has_overrides() -> bool:
	return _raw_override_layers != {}


## Checks if this fixture has a parameter
func has_parameter(p_zone: String, p_parameter: String, p_function: String = "") -> bool:
	if p_function:
		return _manifest.has_function(_mode, p_zone, p_parameter, p_function)
	else:
		return _manifest.has_parameter(_mode, p_zone, p_parameter)


## Checks if this DMXFixture has a function that can fade
func function_can_fade(p_zone: String, p_parameter: String, p_function: String) -> bool:
	return _manifest.function_can_fade(_mode, p_zone, p_parameter, p_function)


## Gets the default value of a parameter
func get_default(p_zone: String, p_parameter: String, p_function: String) -> float:
	var dmx_value: int = _parameters[p_zone][p_parameter].functions[p_function].default
	var range: Array = _parameters[p_zone][p_parameter].functions[p_function].dmx_range

	return remap(dmx_value, range[0], range[1], 0.0, 1.0)


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
				_default.get_or_add(zone, {})[attribute] = _parameters[zone][attribute].functions.values()[0].default

	_compile_output()


## Updates dmx data with all zeros
func zero_channels() -> void:
	for zone: String in _parameters.keys():
		for attribute: String in _parameters[zone].keys():
			if len(_parameters[zone][attribute].offsets):
				_current.get_or_add(zone, {})[attribute] = 0
	
	_current_dmx.clear()
	_compile_output()
	_current.clear()


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


## Saves this DMXFixture to a dictonary
func _on_serialize_request(p_mode: int) -> Dictionary:
	var seralized_data: Dictionary = {
		"channel": _channel,
		"mode": _mode,
		"manifest_uuid": _manifest.uuid if _manifest else ""
	}

	if p_mode == Core.SERIALIZE_MODE_NETWORK:
		seralized_data.merge({
			"raw_override_layers": get_all_override_values()
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