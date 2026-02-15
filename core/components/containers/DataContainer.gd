# Copyright (c) 2025 Liam Sherwin. All rights reserved.
# This file is part of the Spectrum Lighting Controller, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

class_name DataContainer extends EngineComponent
## DataContainer stores fixture data


## Emitted when ContainerItems are stored
signal on_items_stored(items: Array)

## Emitted when ContainerItems are erased
signal on_items_erased(items: Array)

## Emitted when the function is changed in mutiple ContainerItems
signal on_items_function_changed(items: Array, function: String)

## Emitted when the value is changed in mutiple ContainerItems
signal on_items_value_changed(items: Array, value: float)

## Emitted when the can_fade state is changed in mutiple ContainerItems
signal on_items_can_fade_changed(items: Array, can_fade: bool)

## Emitted when the start point is changed in mutiple ContainerItems
signal on_items_start_changed(items: Array, start: float)

## Emitted when the stop point is changed in mutiple ContainerItems
signal on_items_stop_changed(items: Array, stop: float)


## All ContainerItems
var _items: Array[ContainerItem]

## All fixtures stored as { Fixture: { zone: { parameter: ContainerItem } } }
var _fixtures: Dictionary[Fixture, Dictionary]


## init
func _init(p_uuid: String = UUID_Util.v4(), p_name: String = _name) -> void:
	super._init(p_uuid, p_name)
	
	set_name("DataContainer")
	_set_self_class("DataContainer")

	_settings_manager.register_networked_methods_auto([
		get_items,
		get_fixtures,
		get_data_for,
		store_data,
		erase_data,
		store_item,
		store_items,
		erase_item,
		erase_items,
		set_function,
		set_value,
		set_can_fade,
		set_start,
		set_stop,
	])

	_settings_manager.set_method_allow_serialize(get_items)
	_settings_manager.set_method_allow_serialize(get_data_for)

	_settings_manager.set_method_allow_deserialize(store_item)
	_settings_manager.set_method_allow_deserialize(store_items)

	_settings_manager.register_networked_signals_auto([
		on_items_stored,
		on_items_erased,
		on_items_function_changed,
		on_items_value_changed,
		on_items_can_fade_changed,
		on_items_start_changed,
		on_items_stop_changed,
	])

	_settings_manager.set_signal_allow_serialize(on_items_stored)


## Gets all the ContainerItems
func get_items() -> Array[ContainerItem]:
	return _items.duplicate()



## Returns all fixture in this DataContainer
func get_fixtures() -> Array[Fixture]:
	var result: Array[Fixture]
	result.assign(_fixtures.keys())

	return result


## Gets an item by fixture, zone, and parameter
func get_item(p_fixture: Fixture, p_zone: String, p_parameter: String) -> ContainerItem:
	if not _fixtures.has(p_fixture):
		return null
	
	var container: ContainerItem = _fixtures.get(p_fixture, {}).get(p_zone, {}).get(p_parameter, null)

	if not is_instance_valid(container):
		return null
	
	return container


## Gets all the data for a given fixture, stored as { zone: { parameter: ContainerItem } }
func get_data_for(p_fixture: Fixture) -> Dictionary[String, Dictionary]:
	var result: Dictionary[String, Dictionary]
	result.assign(_fixtures.get(p_fixture, {}).duplicate(true))
	
	return result


## Stores data into this DataContainer
func store_data(p_fixture: Fixture, p_zone: String, p_parameter: String, p_function: String, p_value: float, p_can_fade: bool = true, p_start: float = 0.0, p_stop: float = 1.0) -> ContainerItem:
	var item: ContainerItem

	if _fixtures.has(p_fixture) and _fixtures[p_fixture].has(p_zone) and _fixtures[p_fixture][p_zone].has(p_parameter):
		item = _fixtures[p_fixture][p_zone][p_parameter]

		set_value([item], p_value)
		set_can_fade([item], p_can_fade)
		set_start([item], p_start)
		set_stop([item], p_stop)

		return item
	
	else:
		item = ContainerItem.new()

		item.set_fixture(p_fixture)
		item.set_zone(p_zone)
		item.set_parameter(p_parameter)
		item.set_function(p_function)
		item.set_value(p_value)
		item.set_can_fade(p_can_fade)
		item.set_start(p_start)
		item.set_stop(p_stop)
		
		if store_item(item):
			return item
		else:
			return null


## Erases data
func erase_data(p_fixture: Fixture, p_zone: String, p_parameter: String) -> bool:
	var item: ContainerItem = _fixtures.get(p_fixture, {}).get(p_zone, {}).get(p_parameter, null)

	return erase_item(item)
	

## Stores a ContainerItem
func store_item(p_item: ContainerItem, no_signal: bool = false) -> bool:
	if not p_item or p_item in _items or not p_item.is_valid():
		return false
	
	_items.append(p_item)
	_fixtures.get_or_add(p_item.get_fixture(), {}).get_or_add(p_item.get_zone(), {})[p_item.get_parameter()] = p_item

	ComponentDB.register_component(p_item)
	p_item.on_delete_requested.connect(erase_item.bind(p_item))

	if not no_signal:
		on_items_stored.emit([p_item])
	
	return true


## Stores mutiple items at once
func store_items(p_items: Array) -> void:
	var just_added_items: Array[ContainerItem]

	for item: Variant in p_items:
		if item is ContainerItem:
			if store_item(item, true):
				just_added_items.append(item)
	
	if just_added_items:
		on_items_stored.emit(just_added_items)


## Erases an item
func erase_item(p_item: ContainerItem, no_signal: bool = false) -> bool:
	if not p_item or p_item not in _items:
		return false
	
	_items.erase(p_item)
	_fixtures[p_item.get_fixture()][p_item.get_zone()].erase(p_item.get_parameter())

	if not _fixtures[p_item.get_fixture()][p_item.get_zone()]:
		_fixtures[p_item.get_fixture()].erase(p_item.get_zone())
		
		if not _fixtures[p_item.get_fixture()]:
			_fixtures.erase(p_item.get_fixture())

	if not no_signal:
		on_items_erased.emit(p_item)
	
	return true


## Erases mutiple items at once
func erase_items(p_items: Array) -> void:
	var just_erased_items: Array[ContainerItem]

	for item: Variant in p_items:
		if item is ContainerItem:
			if erase_item(item, true):
				just_erased_items.append(item)
	
	if just_erased_items:
		on_items_erased.emit(just_erased_items)


## Sets the function of mutiple items
func set_function(p_items: Array, p_function: String) -> void:
	var changed_items: Array[ContainerItem]

	for item: Variant in p_items:
		if item is ContainerItem:
			if item.set_function(p_function):
				changed_items.append(item)
	
	if changed_items:
		on_items_function_changed.emit(changed_items, p_function)


## Sets the value of mutiple items
func set_value(p_items: Array, p_value: float) -> void:
	var changed_items: Array[ContainerItem]

	for item: Variant in p_items:
		if item is ContainerItem:
			if item.set_value(p_value):
				changed_items.append(item)
	
	if changed_items:
		on_items_value_changed.emit(changed_items, p_value)


## Sets the value of mutiple items
func set_can_fade(p_items: Array, p_can_fade: bool) -> void:
	var changed_items: Array[ContainerItem]

	for item: Variant in p_items:
		if item is ContainerItem:
			if item.set_can_fade(p_can_fade):
				changed_items.append(item)
	
	if changed_items:
		on_items_can_fade_changed.emit(changed_items, p_can_fade)


## Sets the value of mutiple items
func set_start(p_items: Array, p_start: float) -> void:
	var changed_items: Array[ContainerItem]

	for item: Variant in p_items:
		if item is ContainerItem:
			if item.set_start(p_start):
				changed_items.append(item)
	
	if changed_items:
		on_items_start_changed.emit(changed_items, p_start)


## Sets the value of mutiple items
func set_stop(p_items: Array, p_stop: float) -> void:
	var changed_items: Array[ContainerItem]

	for item: Variant in p_items:
		if item is ContainerItem:
			if item.set_stop(p_stop):
				changed_items.append(item)
	
	if changed_items:
		on_items_stop_changed.emit(changed_items, p_stop)


## Serializes this DataContainer and returnes it in a dictionary
func _serialize() -> Dictionary:
	return {
		"items": Utils.seralise_component_array(_items)
	}


## Called when this DataContainer is to be loaded from serialized data
func _load(serialized_data: Dictionary) -> void:
	store_items(Utils.deseralise_component_array(type_convert(serialized_data.get("items", []), TYPE_ARRAY)))


## Handles delete requests
func _delete() -> void:
	for item: ContainerItem in _items:
		item.delete(true)


## Handles delete requests
func delete(p_local_only: bool = false) -> void:
	_delete()
	super.delete(p_local_only)


## Serializes this Datacontainer and returnes it in a dictionary
func serialize(p_flags: int = 0) -> Dictionary:
	return super.serialize(p_flags).merged(_serialize())


## Loads this DataContainer from a dictonary
func deserialize(p_serialized_data: Dictionary) -> void:
	super.deserialize(p_serialized_data)
	_load(p_serialized_data)
