# Copyright (c) 2026 Liam Sherwin. All rights reserved.
# This file is part of the Spectrum Lighting Controller, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

class_name FixtureGroup extends EngineComponent
## Stores a group of fixtures, using FixtureGroupItem


## Emitted when fixtures are added to this FixtureGroup
signal fixtures_added(group_items: Array[FixtureGroupItem])

## Emitted when fixtures are removed from this FixtureGroup
signal fixtures_removed(fixtures: Array[Fixture])


## Stores all the fixtures and there positions. Stored as {Fixture: FixtureGroupItem}
var _fixtures: Dictionary[Fixture, FixtureGroupItem] = {}


## init
func _init(p_uuid: String = UUID.v4(), ...p_args: Array[Variant]) -> void:
	super._init(p_uuid, p_args)
	
	_set_class_name("FixtureGroup")
	set_name("FixtureGroup")

	_settings.register_networked_methods_auto([
		get_fixtures,
		get_group_items,
		add_fixture,
		get_group_item_for,
		add_group_item,
		add_group_items,
		remove_fixture,
		remove_fixtures,
	])

	_settings.set_method_allow_deserialize(add_group_item)
	_settings.set_method_allow_deserialize(add_group_items)

	_settings.register_networked_signals_auto([
		fixtures_added,
		fixtures_removed,
	])

	_settings.set_signal_allow_serialize(fixtures_added)


## Gets all the fixtures
func get_fixtures() -> Array[Fixture]:
	var result: Array[Fixture]
	result.assign(_fixtures.keys())
	
	return result


## Gets all the group items
func get_group_items() -> Array[FixtureGroupItem]:
	var result: Array[FixtureGroupItem]
	result.assign(_fixtures.values())
	
	return result


## Gets a FixtureGroupItem
func get_group_item_for(fixture: Fixture) -> FixtureGroupItem:
	return _fixtures.get(fixture)


## Adds a new fixture to this group. Returns false the fixture is already in this group
func add_fixture(fixture: Fixture, position: Vector3 = Vector3.ZERO, no_signal: bool = false) -> bool:
	if fixture in _fixtures: return false

	var new_group_item: FixtureGroupItem = FixtureGroupItem.new()

	new_group_item.set_fixture(fixture)
	new_group_item.set_position(position)

	add_group_item(new_group_item, no_signal)    

	return true


## Adds a pre-existing FixtureGroupItem. Returns false the fixture is already in this group
func add_group_item(group_item: FixtureGroupItem, no_signal: bool = false) -> bool:
	if group_item.get_fixture() in _fixtures: return false

	_fixtures[group_item.get_fixture()] = group_item

	group_item.get_fixture().delete_requested.connect(remove_fixture, CONNECT_ONE_SHOT)
	Network.register_network_object(group_item.get_uuid(), group_item.get_settings())

	if not no_signal:
		fixtures_added.emit([group_item])
	
	return true


## Adds mutiple group items at once
func add_group_items(group_items: Array) -> void:
	var just_added_group_items: Array[FixtureGroupItem]

	for group_item: Variant in group_items:
		if group_item is FixtureGroupItem:
			if add_group_item(group_item, true):
				just_added_group_items.append(group_item)

	if just_added_group_items:
		fixtures_added.emit(just_added_group_items)



## Removes a fixture from this group, returns false if this fixture is not in this group
func remove_fixture(fixture: Fixture, no_signal: bool = false) -> bool:
	if not _fixtures.has(fixture): return false

	_fixtures[fixture].delete()
	_fixtures.erase(fixture)

	if not no_signal:
		fixtures_removed.emit([fixture])
	
	return true


## Adds mutiple fixtures at once
func remove_fixtures(fixtures: Array) -> void:
	var just_removed_fixtures: Array[Fixture] = []

	for fixture: Variant in fixtures:
		if fixture is Fixture:
			if remove_fixture(fixture, true):
				just_removed_fixtures.append(fixture)

	if just_removed_fixtures:
		fixtures_removed.emit(just_removed_fixtures)


## Deletes this FixtureGroup
func delete() -> void:
	for group_item: FixtureGroupItem in _fixtures.values():
		Network.deregister_network_object(group_item.get_settings())
		group_item.delete()
	
	super.delete()


## Saves this FixtureGroup into a dictionary
func serialize(p_flags: Data.SerializationFlags = Data.SerializationFlags.NONE) -> Dictionary:
	var serialized_data: Dictionary = {
		"fixtures": {}
	}
	
	for fixture: Fixture in _fixtures:
		serialized_data.fixtures[fixture.get_uuid()] = _fixtures[fixture].serialize(p_flags)

	return super.serialize(p_flags).merged(serialized_data)


## Loads this FixtureGroup from serialized data
func deserialize(p_serialized_data: Dictionary, p_flags: Data.SerializationFlags = Data.SerializationFlags.NONE) -> void:
	super.deserialize(p_serialized_data, p_flags)

	var just_added_fixtures: Array[FixtureGroupItem] = []

	if p_serialized_data.get("fixtures") is Dictionary: 
		var fixtures: Dictionary = p_serialized_data.fixtures

		for fixture_uuid: Variant in fixtures:
			if ComponentDB.get_component(fixture_uuid) is Fixture:

				var new_group_item: FixtureGroupItem = FixtureGroupItem.new()
				new_group_item.deserialize(fixtures[fixture_uuid])

				if add_group_item(new_group_item, true):
					just_added_fixtures.append(new_group_item)
	
	if just_added_fixtures:
		fixtures_added.emit(just_added_fixtures)
