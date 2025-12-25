# Copyright (c) 2025 Liam Sherwin. All rights reserved.
# This file is part of the Spectrum Lighting Controller, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

class_name FixtureGroupItem extends EngineComponent
## A data container for Fixture Groups, this does not do anyting by its self.


## Emited when the _fixture changes
signal on_fixture_changed(fixture: Fixture)

## Emitted when the _position changes
signal on_position_changed(position: Vector3)


## The _fixture asigned to this group item
var _fixture: Fixture = null

## The _position of this _fixture in this group item
var _position: Vector3 = Vector3.ZERO


## init
func _init(p_uuid: String = UUID_Util.v4(), p_name: String = _name) -> void:
	super._init(p_uuid, p_name)
	
	set_name("FixtureGroupItem")
	_set_self_class("FixtureGroupItem")

	_settings_manager.register_networked_methods_auto([
		set_fixture,
		set_position,
		get_fixture,
		get_position,
	])

	_settings_manager.register_networked_signals_auto([
		on_fixture_changed,
		on_position_changed,
	])


## Sets the _fixture
func set_fixture(p_fixture: Fixture) -> void:
	if p_fixture == _fixture: return

	_fixture = p_fixture
	set_name(_fixture.name() + " Group Item")
	on_fixture_changed.emit(_fixture)


## Sets the fixtures _position
func set_position(p_position: Vector3) -> void:
	if _position == p_position: return

	_position = p_position
	on_position_changed.emit(_position)


## Gets the fixture
func get_fixture() -> Fixture:
	return _fixture


## Gets the position
func get_position() -> Vector3:
	return _position


## Saves this component into a dict
func serialize(p_flags: int = 0) -> Dictionary:
	return super.serialize(p_flags).merged({
		"fixture": _fixture.uuid(),
		"position": var_to_str(_position)
	} if _fixture else {})


## Loads this component from a dict
func deserialize(p_serialized_data: Dictionary) -> void:
	super.deserialize(p_serialized_data)

	if p_serialized_data.get("fixture") is String and ComponentDB.get_component(p_serialized_data.fixture) is Fixture:
		set_fixture(ComponentDB.get_component(p_serialized_data.fixture))
	
	var position: Variant = p_serialized_data.get("position", null)
	if position is String and str_to_var(position) is Vector3:
		set_position(str_to_var(position))
