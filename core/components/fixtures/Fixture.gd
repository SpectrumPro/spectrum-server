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


## Called when this EngineComponent is ready
func _init(p_uuid: String = UUID_Util.v4(), p_name: String = name) -> void:
	set_self_class("Fixture")

	super._init(p_uuid, p_name)


## Sets a parameter to a float value
func set_parameter(p_parameter: String, p_function: String, p_value: float, p_layer_id: String, p_zone: String = "root") -> void:
	pass


## Erases the parameter on the given layer
func erase_parameter(p_parameter: String, p_layer_id: String, p_zone: String = "root") -> void:
	pass


## Sets a parameter override to a float value
func set_override(p_parameter: String, p_function: String, p_value: float, p_zone: String = "root") -> void:
	pass


## Erases the parameter override 
func erase_override(p_parameter: String, zone: String = "root") -> void:
	pass


## Erases all overrides
func erase_all_overrides() -> void:
	pass


## Gets all the override values
func get_all_override_values() -> Dictionary:
	return {}


## Checks if this Fixture has any overrides
func has_overrides() -> bool:
	return false


## Gets all the parameters and there category from a zone
func get_parameter_categories(p_zone: String) -> Dictionary:
	return {}


## Gets all the parameter functions
func get_parameter_functions(p_zone: String, p_parameter: String) -> Array:
	return []


## Checks if this fixture has a parameter
func has_parameter(p_zone: String, p_parameter: String) -> bool:
	return false


## Checks if this Fixture has a function that can fade
func function_can_fade(p_zone: String, p_parameter: String, p_function: String) -> bool:
	return false


## Gets the default value of a parameter
func get_default(p_zone: String, p_parameter: String, p_function: String) -> float:
	return 0.0
