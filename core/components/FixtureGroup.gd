# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name FixtureGroup extends EngineComponent
## Stores a group of fixtures, using FixtureGroupItem


## Emitted when fixtures are added to this FixtureGroup
signal on_fixtures_added(group_items: Array[FixtureGroupItem])

## Emitted when fixtures are removed from this FixtureGroup
signal on_fixtures_removed(fixtures: Array[Fixture])


## Stores all the fixtures and there positions. Stored as {Fixture: FixtureGroupItem}
var _fixtures: Dictionary = {}


## Called when this EngineComponent is ready
func _component_ready() -> void:
	set_self_class("FixtureGroup")
	set_name("Fixture Group")


## Gets a FixtureGroupItem
func get_group_item(fixture: Fixture) -> FixtureGroupItem:
	return _fixtures.get(fixture)


## Gets all the fixtures
func get_fixtures() -> Array:
	return _fixtures.keys()


## Adds a new fixture to this group. Returns false the fixture is already in this group
func add_fixture(fixture: Fixture, position: Vector3 = Vector3.ZERO, no_signal: bool = false) -> bool:
	if fixture in _fixtures: return false

	var new_group_item: FixtureGroupItem = FixtureGroupItem.new()

	new_group_item.fixture = fixture
	new_group_item.position = position

	add_group_item(new_group_item, no_signal)    

	return true


## Adds a pre-existing FixtureGroupItem. Returns false the fixture is already in this group
func add_group_item(group_item: FixtureGroupItem, no_signal: bool = false) -> bool:
	if group_item.fixture in _fixtures: return false

	_fixtures[group_item.fixture] = group_item

	group_item.fixture.on_delete_requested.connect(remove_fixture.bind(group_item.fixture), CONNECT_ONE_SHOT)
	Server.add_networked_object(group_item.uuid, group_item, group_item.on_delete_requested)

	if not no_signal:
		on_fixtures_added.emit([group_item])
	
	return true


## Adds mutiple group items at once
func add_group_items(group_items: Array) -> void:
	var just_added_group_items: Array[FixtureGroupItem]

	for group_item: Variant in group_items:
		if group_item is FixtureGroupItem:
			if add_group_item(group_item, true):
				just_added_group_items.append(group_item)

	if just_added_group_items:
		on_fixtures_added.emit(just_added_group_items)



## Removes a fixture from this group, returns false if this fixture is not in this group
func remove_fixture(fixture: Fixture, no_signal: bool = false) -> bool:
	if not _fixtures.has(fixture): return false

	_fixtures[fixture].delete()
	_fixtures.erase(fixture)

	if not no_signal:
		on_fixtures_removed.emit([fixture])
	
	return true


## Adds mutiple fixtures at once
func remove_fixtures(fixtures: Array) -> void:
	var just_removed_fixtures: Array[Fixture] = []

	for fixture: Variant in fixtures:
		if fixture is Fixture:
			if remove_fixture(fixture, true):
				just_removed_fixtures.append(fixture)

	if just_removed_fixtures:
		on_fixtures_removed.emit(just_removed_fixtures)


func _on_delete_request() -> void:
	for group_item: FixtureGroupItem in _fixtures.values():
		Server.remove_networked_object(group_item.uuid)
		group_item.delete()


## Saves this FixtureGroup into a dictionary
func _on_serialize_request(p_flags: int) -> Dictionary:
	var serialized_data: Dictionary = {
		"fixtures": {}
	}
	
	for fixture: Fixture in _fixtures:
		serialized_data.fixtures[fixture.uuid] = _fixtures[fixture].serialize(p_flags)

	return serialized_data


## Loads this FixtureGroup from serialized data
func _on_load_request(serialized_data: Dictionary) -> void:
	var just_added_fixtures: Array[FixtureGroupItem] = []

	if serialized_data.get("fixtures") is Dictionary: 
		var fixtures: Dictionary = serialized_data.fixtures

		for fixture_uuid: Variant in fixtures:
			if ComponentDB.get_component(fixture_uuid) is Fixture:

				var new_group_item: FixtureGroupItem = FixtureGroupItem.new()
				new_group_item.load(fixtures[fixture_uuid])

				if add_group_item(new_group_item, true):
					just_added_fixtures.append(new_group_item)
	
	if just_added_fixtures:
		on_fixtures_added.emit(just_added_fixtures)
