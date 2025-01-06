# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name DMXFixture extends EngineComponent
## Dmx Fixture


## Emitted when parameters are changed
signal parameter_changed(parameter: String, value: Variant, head_id: int)

## Emited when a parameter override is changed or added
signal override_changed(parameter: String, value: Variant, head_id: int)

## Emitted when a parameter override is removed
signal override_removed(parameter: String, head_id: int)

## Emitted when the dmx data is updated, this may not contain all the current dmx data, as it will only emit changes
signal dmx_data_updated(dmx_data: Dictionary)


enum BlendMode {HTP, LTP}


## The DMX channel of this fixture
var _channel: int = 1


## The supported parameters of this fixture, there dmx channels, precedence, and ranges
## { head_id: { parameter": { config... } } }
var _parameters: Dictionary = {}

## All the layers of this fixture, used to calculate HTP
## { head_id: { "parameter": { "layer_id": value } } }
var _layers: Dictionary = {}

## Current values of this fixture, post precedence calculation
## { head_id: { "parameter": value } }
var _current: Dictionary = {}

## Current dmx data
var _current_dmx: Dictionary


func _component_ready() -> void:
     set_name("DMXFixture")
     set_self_class("DMXFixture")

     register_high_frequency_signals([parameter_changed, override_changed])



## Sets a parameter to a float value
func set_parameter(parameter: String, value: float, layer_id: String, head_id: int = 0) -> void:
     if _parameters.has(head_id) and _parameters[head_id].has(parameter):
          var layers: Dictionary = _layers.get_or_add(head_id, {}).get_or_add(parameter, {})
          var parameter_config: Dictionary = _parameters[head_id][parameter]
          layers[layer_id] = value

          if value > _current[head_id][parameter] or parameter_config.blend_mode == BlendMode.LTP:
               _set_value(parameter, value, head_id)


## Erases the parameter on the given layer
func erase_parameter(parameter: String, layer_id: String, head_id: int = 0) -> void:
     pass



## Sets a parameter override to a float value
func set_override(parameter: String, value: float, head_id: int = 0) -> void:
     pass


## Erases the parameter override 
func erase_override(parameter: String, head: int = 0) -> void:
     pass


## Erases all overrides
func erase_all_overrides() -> void:
     pass



## Sets a parameter mode
func set_parameter_mode(parameter: String, mode: int, head: int = 0) -> void:
     pass


## Internal method to set a parameter and output the new values
func set_value(parameter: String, value: float, head_id: int) -> void:
     ## The channels that control this parameter on the fixture
     var channels: Array = _parameters[head_id][parameter].channels
     
     ## Range of value that control this parameter, as one chanel may control mutiple differnt things, eg Color Wheels or Modes
     var dmx_range: Array =_parameters[head_id][parameter].dmx_range

     # The orignal value remapped to fit into the dmx range
     var mapped_value: int = snapped(remap(value, 0.0, 1.0, dmx_range[0], dmx_range[1]), 1)

     _current[head_id][parameter] = value
     