# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name CoreProgrammer extends Node
## Engine class for programming lights, colors, positions, etc.


## Emitted when the programmer is cleared
signal on_cleared()


## Save Modes
enum SaveMode {
	MODIFIED,		## Only save fixtures that have been changed in the programmer
	ALL,			## Save all values of the fixtures
	ALL_NONE_ZERO	## Save all values of the fixtures, as long as they are not the zero value for that channel
}

## Random parameter modes
enum RandomMode {
	All,			## Sets all fixture's parameter to the same random value
	Individual		## Uses a differnt random value for each fixture
}


## Current data in the programmer, {Fixture: {"channel_key": value...}...}
var _container: DataContainer = DataContainer.new()

## Temp layer id
var _layer_id: String = "Programmer"


# Clears all values in the programmer
func clear() -> void:
	for fixture: Fixture in _container.get_stored_fixtures():
		fixture.erase_all_overrides()
	
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


## Sets the data on a single fixture at a time
func _set_individual_fixture_data(p_fixture: Fixture, p_parameter: String, p_function: String, p_value: float, p_zone: String) -> void:
	if p_fixture.has_parameter(p_zone, p_parameter):
		p_fixture.set_override(p_parameter, p_function, p_value, p_zone)
		_container.store_data(p_fixture, p_parameter, p_function, p_value, p_zone, p_fixture.function_can_fade(p_zone, p_parameter, p_function))


## Eraces the data on a single fixture at a time
func _erase_individual_fixture_data(p_fixture: Fixture, p_parameter: String, p_zone: String) -> void:
	if p_fixture.has_parameter(p_zone, p_parameter):
		p_fixture.erase_override(p_parameter, p_zone)
		_container.erase_data(p_fixture, p_parameter, p_zone)


## Stores data into a function
func store_data_to_container(container: DataContainer, mode: SaveMode, fixtures: Array = []) -> void:
	match mode:
		SaveMode.MODIFIED:
			for fixture: Fixture in fixtures:
				var current_data: Dictionary = _container.get_fixture_data()

				if fixture in current_data:
					for zone: String in current_data[fixture]:
						for parameter: String in current_data[fixture][zone]:
							var stored_data: Dictionary = current_data[fixture][zone][parameter]
							container.store_data(fixture, parameter, stored_data.function, stored_data.value, zone, stored_data.can_fade)

		# SaveMode.ALL:
		# 	for fixture in fixtures:
		# 		if fixture is Fixture:
		# 			for channel_key: String in fixture.current_values:
		# 				container.store_data(fixture, channel_key, fixture.current_values[channel_key])

		# SaveMode.ALL_NONE_ZERO:
		# 	for fixture in fixtures:
		# 		if fixture is Fixture:
		# 			for channel_key: String in fixture.current_values:
		# 				if fixture.current_values[channel_key]:
		# 					container.store_data(fixture, channel_key, fixture.current_values[channel_key])


## erases data into a function
func erase_data_from_container(container: DataContainer, mode: SaveMode, fixtures: Array = []) -> void:
	match mode:
		SaveMode.MODIFIED:
			for fixture: Fixture in fixtures:
				var current_data: Dictionary = _container.get_fixture_data()

				if fixture in current_data:
					for zone: String in current_data[fixture]:
						for parameter: String in current_data[fixture][zone]:
							container.erase_data(fixture, parameter, zone)

		# SaveMode.ALL:
		# 	for fixture in fixtures:
		# 		if fixture is Fixture:
		# 			for channel_key: String in fixture.current_values:
		# 				container.erase_data(fixture, channel_key)

		# SaveMode.ALL_NONE_ZERO:
		# 	for fixture in fixtures:
		# 		if fixture is Fixture:
		# 			for channel_key: String in fixture.current_values:
		# 				if fixture.current_values[channel_key]:
		# 					container.erase_data(fixture, channel_key)


## Saves the current state of this programmer to a scene
func save_to_scene(fixtures: Array, mode: SaveMode = SaveMode.MODIFIED) -> Scene:
	var new_scene: Scene = Scene.new()
	store_data_to_container(new_scene.get_data_container(), mode, fixtures)

	Core.add_component(new_scene)
	return new_scene


# ## Saves the selected fixtures to a new cue, using SaveMode
# func save_to_new_cue(fixtures: Array, cue_list: CueList, mode: SaveMode) -> void:
# 	if not fixtures:
# 		return

# 	var new_cue: Cue = Cue.new()

# 	store_data_to_container(new_cue, mode, fixtures)

# 	cue_list.add_cue(new_cue, 0, true)
# 	cue_list.seek_to(new_cue.number)


# ## Merges data into a cue by its number in a cue list
# func merge_into_cue(fixtures: Array, cue_list: CueList, cue_number: float, mode: SaveMode) -> void:
# 	var cue: Cue = cue_list.get_cue(cue_number)

# 	if cue:
# 		store_data_to_container(cue, mode, fixtures)
# 		cue_list.force_reload = true


# ## erases data into a cue by its number in a cue list
# func erase_from_cue(fixtures: Array, cue_list: CueList, cue_number: float, mode: SaveMode) -> void:
# 	var cue: Cue = cue_list.get_cue(cue_number)

# 	if cue:
# 		erase_data_from_container(cue, mode, fixtures)
# 		cue_list.force_reload = true


# ## Saves the current state of fixtures to a new cue list
# func save_to_new_cue_list(fixtures: Array) -> void:

# 	var new_cue_list: CueList = CueList.new()

# 	var blackout_cue: Cue = Cue.new()
# 	blackout_cue.name = "Blackout"

# 	var new_cue: Cue = Cue.new()

# 	store_data_to_container(new_cue, SaveMode.MODIFIED, fixtures)

# 	for fixture: Fixture in save_data:
# 		for channel_key: String in save_data[fixture]:
# 			new_cue.store_data(fixture, channel_key, save_data[fixture][channel_key])

# 	new_cue_list.add_cue(blackout_cue, 0.5)
# 	new_cue_list.add_cue(new_cue, 1, true)

# 	Core.add_component(new_cue_list)
