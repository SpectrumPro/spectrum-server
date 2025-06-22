# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name FixtureGroupItem extends EngineComponent
## A data container for Fixture Groups, this does not do anyting by its self.


## Emited when the fixture changes
signal on_fixture_changed(fixture: Fixture)


## Emitted when the position changes
signal on_position_changed(position: Vector3)


## The fixture asigned to this group item
var fixture: Fixture = null : set = set_fixture

## The position of this fixture in this group item
var position: Vector3 = Vector3.ZERO : set = set_position


func _component_ready() -> void:
	set_self_class("FixtureGroupItem")
	set_name("Fixture Group Item")


## Sets the fixture
func set_fixture(p_fixture: Fixture) -> void:
	if p_fixture == fixture: return

	fixture = p_fixture
	set_name(fixture.name + " Group Item")
	on_fixture_changed.emit(fixture)


## Sets the fixtures position
func set_position(p_position: Vector3) -> void:
	if position == p_position: return

	position = p_position
	on_position_changed.emit(position)


## Saves this component into a dict
func _on_serialize_request(p_flags: int) -> Dictionary:
	if fixture:
		return {
			"fixture": fixture.uuid,
			"position": var_to_str(position)
		}
	else:
		return {}


## Loads this component from a dict
func _on_load_request(serialized_data: Dictionary) -> void:
	if serialized_data.get("fixture") is String and ComponentDB.get_component(serialized_data.fixture) is Fixture:
		set_fixture(ComponentDB.get_component(serialized_data.fixture))
	
	var position: Variant = serialized_data.get("position", null)
	if position is String and str_to_var(position) is Vector3:
		set_position(str_to_var(position))
