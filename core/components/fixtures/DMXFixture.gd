# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name DMXFixture extends Fixture
## Dmx Fixture


## Emitted when parameters are changed
signal on_parameter_changed(parameter: String, value: Variant, zone: String)

## Emited when a parameter override is changed or added
signal on_override_changed(parameter: String, value: Variant, zone: String)

## Emitted when a parameter override is removed
signal on_override_erased(parameter: String, zone: String)

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
## { "zone": { parameter": { config... } } }
var _parameters: Dictionary = {}

## All the input value layers as mapped values
## { "zone": { "parameter": { "layer_id": mapped_value } } }
var _mapped_layers: Dictionary = {}

## Al the input value layers as raw values
## { "zone": { "parameter": { "layer_id": raw_value } } }
var _raw_layers: Dictionary = {}

## Current values of this fixture, post precedence calculation
## { "zone": { "parameter": value } }
var _current: Dictionary = {}

## Default channel values, pre-compiled
var _default: Dictionary = {}

## Current dmx data
var _current_dmx: Dictionary

## Current manifest name
var _manifest_uuid: String


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
func set_parameter(parameter: String, value: float, layer_id: String, zone: String = "root") -> void:
	var split: PackedStringArray = parameter.split(".", true, 1)
	if _parameters.has(zone) and len(split) == 2 and _parameters[zone].has(split[0]) and _parameters[zone][split[0]].functions.has(split[1]):
		var logical: String = split[0]
		var function: String = split[1]

		var offsets: Array = _parameters[zone][logical].offset
		var dmx_range: Array =_parameters[zone][logical].functions[function].dmx_range
		var mapped_value: int = snapped(remap(value, 0.0, 1.0, dmx_range[0], dmx_range[1]), 1)
		var mapped_layer: Dictionary = _mapped_layers.get_or_add(zone, {}).get_or_add(logical, {})
		var raw_layer: Dictionary = _raw_layers.get_or_add(zone, {}).get_or_add(logical, {})
		mapped_layer[layer_id] = mapped_value
		raw_layer[layer_id] = value

		var max: int = mapped_layer.values().max()
		
		if max != _current.get(zone, {}).get(logical, null):
			_current.get_or_add(zone, {})[logical] = mapped_value
			on_parameter_changed.emit(parameter, value, zone)

		_compile_output()



## Erases the parameter on the given layer
func erase_parameter(parameter: String, layer_id: String, zone: String = "root") -> void:
	var split: PackedStringArray = parameter.split(".", true, 1)
	if _current.has(zone) and len(split) == 2 and _current[zone].has(split[0]):
		var logical: String = split[0]
		var function: String = split[1]
		var mapped_layer: Dictionary = _mapped_layers.get_or_add(zone, {}).get_or_add(logical, {})
		var raw_layer: Dictionary = _raw_layers.get_or_add(zone, {}).get_or_add(logical, {})

		mapped_layer.erase(layer_id)
		raw_layer.erase(layer_id)
		var max: Variant = mapped_layer.values().max()
		
		if max and max != _current[zone][logical]:
			_current[zone][logical] = max
			on_parameter_changed.emit(parameter, raw_layer.keys()[mapped_layer.values().find(max)], zone)
		else:
			_current[zone].erase(logical)

		_compile_output()


## Sets a parameter override to a float value
func set_override(parameter: String, value: float, zone: String = "root") -> void:
	pass


## Erases the parameter override 
func erase_override(parameter: String, zone: String = "root") -> void:
	pass


## Erases all overrides
func erase_all_overrides() -> void:
	pass


## Sets the manifest for this fixture
func set_manifest(manifest_uuid: String, manifest: Dictionary, mode: String) -> void:
	_parameters = manifest[mode].channels
	_mode = mode
	_manifest_uuid = manifest_uuid

	_current.clear()
	_default.clear()
	zero_channels()

	for zone: String in _parameters.keys():
		for attribute: String in _parameters[zone].keys():
			_default.get_or_add(zone, {})[attribute] = _parameters[zone][attribute].functions.values()[0].default

	print(_parameters)
	print(_default)
	_compile_output()


## Updates dmx data with all zeros
func zero_channels() -> void:
	for zone: String in _parameters.keys():
		for attribute: String in _parameters[zone].keys():
			_current.get_or_add(zone, {})[attribute] = 0
	
	_current_dmx.clear()
	_compile_output()
	_current.clear()


## Compiles the inputted data with internal data and overrides and outputs the result
func _compile_output() -> void:

	for zone: String in _current.keys() if _current else _default.keys():
		var zone_merged: Dictionary = _current.get(zone, {}).merged(_default.get(zone, {}))
		print(zone_merged)
		for parameter: String in zone_merged.keys():
			var offset: Array[int] = _parameters[zone][parameter].offset
			var value: int = clamp(zone_merged[parameter], 0, (256**len(offset)) - 1)

			for i in range(len(offset)):
				var shift_amount = (offset.size() - 1 - i) * 8
				var channel_value = (value >> shift_amount) & 0xFF
				_current_dmx[offset[i] + _channel - 1] = channel_value
	
	print(_current_dmx)
	dmx_data_updated.emit(_current_dmx.duplicate())


## Saves this DMXFixture to a dictonary
func _on_serialize_request(p_mode: int) -> Dictionary:
	return {
		"channel": _channel,
		"mode": _mode,
		"manifest_uuid": _manifest_uuid
	}


## Loads this DMXFixture from a dictonary
func _on_load_request(p_serialized_data: Dictionary) -> void:
	set_channel(p_serialized_data.get("channel"))

	_manifest_uuid = p_serialized_data.get("manifest_uuid", "")
	_mode = p_serialized_data.get("mode", "")
	FixtureLibrary.request_manifest(_manifest_uuid).then(func (manifest: Dictionary):
		set_manifest(_manifest_uuid, manifest, _mode)
	)
