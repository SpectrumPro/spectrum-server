# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name Fixture extends EngineComponent
## Base class for all controlable items


## Emitted when a parameter is changed
signal on_parameter_changed(parameter: String, function: String, value: Variant, zone: String)

## Emitted when a parameter is erased
signal on_parameter_erased(parameter: String, zone: String)

## Emited when a parameter override is changed or added
signal on_override_changed(parameter: String, function: String, value: Variant, zone: String)

## Emitted when a parameter override is removed
signal on_override_erased(parameter: String, zone: String)

## Emitted when all overrides are removed
signal on_all_override_removed()


## Root Zone
static var RootZone: String = "root"


## Enables layer based LTP on layers
var _ltp_layers: Dictionary[String, Variant]


## Called when this EngineComponent is ready
func _init(p_uuid: String = UUID_Util.v4(), p_name: String = name) -> void:
	set_self_class("Fixture")

	super._init(p_uuid, p_name)


## Sets a parameter to a float value
func set_parameter(p_parameter: String, p_function: String, p_value: float, p_layer_id: String, p_zone: String = "root") -> bool:
	return false


## Erases the parameter on the given layer
func erase_parameter(p_parameter: String, p_layer_id: String, p_zone: String = "root") -> void:
	pass


## Sets a parameter override to a float value
func set_override(p_parameter: String, p_function: String, p_value: float, p_zone: String = "root") -> bool:
	return false


## Erases the parameter override
func erase_override(p_parameter: String, zone: String = "root") -> void:
	pass


## Erases all overrides
func erase_all_overrides() -> void:
	pass


## Gets all the override values
func get_all_override_values() -> Dictionary:
	return {}


## Gets all the values
func get_all_values_layered() -> Dictionary:
	return {}


## Gets all the values
func get_all_values() -> Dictionary:
	return {}


## Gets all the parameters and there category from a zone
func get_parameter_categories(p_zone: String) -> Dictionary:
	return {}


## Gets all the parameter functions
func get_parameter_functions(p_zone: String, p_parameter: String) -> Array:
	return []


## Gets the default value of a parameter
func get_default(p_zone: String, p_parameter: String, p_function: String = "", p_raw_dmx: bool = false) -> float:
	return 0.0


## Gets the force default value of a parameter
func get_force_default(p_zone: String, p_parameter: String, p_function: String = "", p_raw_dmx: bool = false) -> float:
	return 0.0


## Gets the default function for a zone and parameter, or the first function if none can be found
func get_default_function(p_zone: String, p_parameter: String) -> String:
	return ""


## Gets the current value, or the default
func get_current_value(p_zone: String, p_parameter: String, p_allow_default: bool = true) -> float:
	return 0.0


## Gets the current value, or the default
func get_current_value_or_force_default(p_zone: String, p_parameter: String) -> float:
	return 0.0


## Gets a value from the given layer id, parameter, and zone
func get_current_value_layered(p_zone: String, p_parameter: String, p_layer_id: String, p_function: String = "", p_allow_default: bool = true) -> float:
	return 0.0


## Gets the current value from a given layer ID, the default is none is present, or 0 if p_parameter is not a force default
func get_current_value_layered_or_force_default(p_zone: String, p_parameter: String, p_layer_id: String, p_function: String = "") -> float:
	return 0.0


## Gets all the zones
func get_zones() -> Array[String]:
	return []


## Checks if this Fixture has any overrides
func has_overrides() -> bool:
	return false


## Checks if this fixture has a parameter
func has_parameter(p_zone: String, p_parameter: String, p_function: String = "") -> bool:
	return false


## Checks if a parameter is a force default
func has_force_default(p_parameter: String) -> bool:
	return false


## Checks if this Fixture has a function that can fade
func function_can_fade(p_zone: String, p_parameter: String, p_function: String) -> bool:
	return false


## Enabled LTP on a layer
func add_ltp_layer(p_layer_id: String) -> bool:
	if _ltp_layers.has(p_layer_id):
		return false

	_ltp_layers[p_layer_id] = null
	return true


## Enabled LTP on a layer
func remove_ltp_layer(p_layer_id: String) -> bool:
	if not _ltp_layers.has(p_layer_id):
		return false

	_ltp_layers.erase(p_layer_id)
	return true


## Enabled LTP on a layer
func has_ltp_layer(p_layer_id: String) -> bool:
	return _ltp_layers.has(p_layer_id) or FixtureLibrary.has_global_ltp_layer(p_layer_id)
