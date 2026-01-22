# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name CoreProgrammer extends Node
## Engine class for programming lights, colors, positions, etc.


## Emitted when the programmer is cleared
signal on_cleared()


## Enum for StoreMode
enum StoreMode {
	INSERT,			## Insets data into the container
	ERASE,			## Erases data from the container
}

## Enum for StoreFilter
enum StoreFilter {
	MODIFIED,
	ALL,
	NONE_DEFAULT,
}

## Random parameter modes
enum RandomMode {
	All,			## Sets all fixture's parameter to the same random value
	Individual		## Uses a differnt random value for each fixture
}

## Mix Mode
enum MixMode {
	Additive,		## Uses Additive Mixing
	Subtractive		## Uses Subtractive Mixing
}


## Current data in the programmer
var _container: DataContainer = DataContainer.new()

## The SettingsManager for this Programmer
var settings_manager: SettingsManager = SettingsManager.new()


## init
func _init() -> void:
	settings_manager.set_owner(self)
	settings_manager.set_inheritance_array(["Programmer"])

	settings_manager.register_networked_methods_auto([
		clear,
		set_parameter,
		erase_parameter,
		# store_data_to_container,
		# erase_data_from_container,
		# store_into_new,
		# store_into,
		# save_to_new_scene,
		# save_to_new_cue_list,
		# save_to_new_cue,
		# merge_into_cue,
		# erase_from_cue,
		shortcut_set_color,
		store_into,
	])

	settings_manager.register_networked_signals_auto([
		on_cleared
	])


# Clears all values in the programmer
func clear() -> void:
	for fixture: Fixture in _container.get_fixtures():
		fixture.erase_all_overrides()

	_container.delete()
	_container = DataContainer.new()
	on_cleared.emit()


## Function to set the fixture data at the given chanel key
func set_parameter(p_fixtures: Array, p_parameter: String, p_function: String, p_value: float, p_zone: String) -> void:
	for fixture in p_fixtures:
		if fixture is Fixture:
			_set_individual_fixture_data(fixture, p_parameter, p_function, p_value, p_zone)


## Sets a fixture parameter to a random value
func set_parameter_random(p_fixtures: Array, p_parameter: String, p_function: String, p_zone: String, p_mode: RandomMode) -> void:
	var value: float = randf_range(0, 1)
	for fixture in p_fixtures:
		if fixture is Fixture:
			_set_individual_fixture_data(fixture, p_parameter, p_function, value, p_zone)

			if p_mode == RandomMode.Individual:
				value = randf_range(0, 1)


## Erases a parameter
func erase_parameter(p_fixtures: Array, p_parameter: String, p_zone: String) -> void:
	for fixture in p_fixtures:
		if fixture is Fixture:
			_erase_individual_fixture_data(fixture, p_parameter, p_zone)


## Stores data into a function
func store_data_to_container(p_source: DataContainer, p_destination: DataContainer, p_store_mode: StoreMode, p_store_filter: StoreFilter = StoreFilter.MODIFIED, p_fixtures: Array = []) -> void:
	if not is_instance_valid(p_source) or not is_instance_valid(p_destination):
		return

	if p_fixtures == []:
		p_fixtures = p_source.get_fixtures()

	for fixture: Variant in p_fixtures:
		if not fixture is Fixture:
			continue
		
		match p_store_filter:
			StoreFilter.MODIFIED:
				_store_mode_modified(p_source, p_destination, fixture, p_store_mode)
			
			StoreFilter.ALL:
				pass
			
			StoreFilter.NONE_DEFAULT:
				pass


## Shortcut to set the color of fixtures
func shortcut_set_color(p_fixtures: Array, p_color: Color, p_mix_mode: MixMode) -> void:
	if not p_fixtures:
		return

	match p_mix_mode:
		MixMode.Additive:
			set_parameter(p_fixtures, "ColorAdd_R", "ColorAdd_R", p_color.r, "root")
			set_parameter(p_fixtures, "ColorAdd_G", "ColorAdd_G", p_color.g, "root")
			set_parameter(p_fixtures, "ColorAdd_B", "ColorAdd_B", p_color.b, "root")

		MixMode.Subtractive:
			set_parameter(p_fixtures, "ColorSub_C", "ColorSub_C", 1 - p_color.r, "root")
			set_parameter(p_fixtures, "ColorSub_M", "ColorSub_M", 1 - p_color.g, "root")
			set_parameter(p_fixtures, "ColorSub_Y", "ColorSub_Y", 1 - p_color.b, "root")


## Attempts to store the current data into the given component the best way possable
func store_into(p_component: EngineComponent, p_store_mode: StoreMode = StoreMode.INSERT, p_store_filter: StoreFilter = StoreFilter.MODIFIED) -> bool:
	if not is_instance_valid(p_component):
		return false
	
	if p_component is CueList:
			var new_cue: Cue = Cue.new()
			store_data_to_container(_container, new_cue, p_store_mode, p_store_filter)

			p_component.add_cue(new_cue)
			p_component.seek_to(new_cue)

			return true
	
	elif p_component is Cue:
			store_data_to_container(_container, p_component, p_store_mode, p_store_filter)
			return true

	elif p_component is Function:
			store_data_to_container(_container, p_component.get_data_container(), p_store_mode, p_store_filter)
			return true
	
	return false


## Handles StoreFilter.ALL
func _store_mode_modified(p_source: DataContainer, p_destination: DataContainer, p_fixture: Fixture, p_store_mode: StoreMode) -> void:
	var items: Array[ContainerItem]
	var fixture_data: Dictionary[String, Dictionary] = p_source.get_data_for(p_fixture)

	for zone: String in fixture_data.keys():
		for item: ContainerItem in fixture_data[zone].values():
			match p_store_mode:
				StoreMode.INSERT:
					items.append(item.duplicate())
				
				StoreMode.ERASE:
					items.append(p_destination.get_item(p_fixture, item.get_zone(), item.get_parameter()))

	match p_store_mode:
		StoreMode.INSERT:
			p_destination.store_items(items)
		
		StoreMode.ERASE:
			p_destination.erase_items(items)


## Sets the data on a single fixture at a time
func _set_individual_fixture_data(p_fixture: Fixture, p_parameter: String, p_function: String, p_value: float, p_zone: String) -> void:
	if p_fixture.has_parameter(p_zone, p_parameter, p_function):
		p_fixture.set_override(p_parameter, p_function, p_value, p_zone)
		_container.store_data(p_fixture, p_zone, p_parameter, p_function, p_value, p_fixture.function_can_fade(p_zone, p_parameter, p_function))


## Eraces the data on a single fixture at a time
func _erase_individual_fixture_data(p_fixture: Fixture, p_parameter: String, p_zone: String) -> void:
	if p_fixture.has_parameter(p_zone, p_parameter):
		p_fixture.erase_override(p_parameter, p_zone)
		_container.erase_data(p_fixture, p_parameter, p_zone)


# ## Stores into an new component of the given type
# func store_into_new(classname: String, fixtures: Array) -> EngineComponent:
# 	if not fixtures:
# 		return

# 	match classname:
# 		"Scene":
# 			return save_to_new_scene(fixtures)

# 		"CueList":
# 			return save_to_new_cue_list(fixtures)

# 	return null


# ## Stores into a pre-existing component
# func store_into(component: EngineComponent, fixtures: Array) -> void:
# 	if not fixtures:
# 		return

# 	match component.self_class_name:
# 		"CueList":
# 			save_to_new_cue(fixtures, component)
# 		"Cue":
# 			merge_into_cue(fixtures, component)



# ## Saves the current state of this programmer to a scene
# func save_to_new_scene(fixtures: Array, mode: SaveMode = SaveMode.MODIFIED) -> Scene:
# 	var new_scene: Scene = Scene.new()
# 	store_data_to_container(new_scene.get_data_container(), mode, fixtures)

# 	Core.add_component(new_scene)
# 	return new_scene


# ## Saves the current state of fixtures to a new cue list
# func save_to_new_cue_list(fixtures: Array) -> CueList:
# 	var new_cue_list: CueList = CueList.new()

# 	var blackout_cue: Cue = Cue.new()
# 	var new_cue: Cue = Cue.new()

# 	blackout_cue.set_name("Blackout")
# 	store_data_to_container(new_cue, SaveMode.MODIFIED, fixtures)

# 	new_cue_list.add_cue(blackout_cue)
# 	new_cue_list.add_cue(new_cue)
# 	new_cue_list.seek_to(new_cue)

# 	Core.add_component(new_cue_list)
# 	return new_cue_list


# ## Saves the selected fixtures to a new cue, using SaveMode
# func save_to_new_cue(fixtures: Array, cue_list: CueList, mode: SaveMode = SaveMode.MODIFIED) -> void:
# 	var new_cue: Cue = Cue.new()

# 	store_data_to_container(new_cue, mode, fixtures)

# 	cue_list.add_cue(new_cue)
# 	cue_list.seek_to(new_cue)


# ## Merges data into a cue by its number in a cue list
# func merge_into_cue(fixtures: Array, cue: Cue, mode: SaveMode = SaveMode.MODIFIED) -> void:
# 	store_data_to_container(cue, mode, fixtures)


# ## erases data into a cue by its number in a cue list
# func erase_from_cue(fixtures: Array, cue: Cue, mode: SaveMode) -> void:
# 	erase_data_from_container(cue, mode, fixtures)
