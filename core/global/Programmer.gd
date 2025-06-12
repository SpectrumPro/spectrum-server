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


## Mix Mode
enum MixMode {
	Additive,		## Uses Additive Mixing
	Subtractive		## Uses Subtractive Mixing
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
	if p_fixture.has_parameter(p_zone, p_parameter, p_function):
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


## Stores into an new component of the given type
func store_into_new(classname: String, fixtures: Array) -> EngineComponent:
	if not fixtures:
		return

	match classname:
		"Scene":
			return save_to_new_scene(fixtures)

		"CueList":
			return save_to_new_cue_list(fixtures)

	return null


## Stores into a pre-existing component
func store_into(component: EngineComponent, fixtures: Array) -> void:
	if not fixtures:
		return

	match component.self_class_name:
		"CueList":
			save_to_new_cue(fixtures, component)
		"Cue":
			merge_into_cue(fixtures, component)



## Saves the current state of this programmer to a scene
func save_to_new_scene(fixtures: Array, mode: SaveMode = SaveMode.MODIFIED) -> Scene:
	var new_scene: Scene = Scene.new()
	store_data_to_container(new_scene.get_data_container(), mode, fixtures)

	Core.add_component(new_scene)
	return new_scene


## Saves the current state of fixtures to a new cue list
func save_to_new_cue_list(fixtures: Array) -> CueList:
	var new_cue_list: CueList = CueList.new()

	var blackout_cue: Cue = Cue.new()
	var new_cue: Cue = Cue.new()

	blackout_cue.name = "Blackout"
	store_data_to_container(new_cue, SaveMode.MODIFIED, fixtures)

	new_cue_list.add_cue(blackout_cue)
	new_cue_list.add_cue(new_cue)
	new_cue_list.seek_to(new_cue)

	Core.add_component(new_cue_list)
	return new_cue_list


## Saves the selected fixtures to a new cue, using SaveMode
func save_to_new_cue(fixtures: Array, cue_list: CueList, mode: SaveMode = SaveMode.MODIFIED) -> void:
	var new_cue: Cue = Cue.new()

	store_data_to_container(new_cue, mode, fixtures)

	cue_list.add_cue(new_cue)
	cue_list.seek_to(new_cue)


## Merges data into a cue by its number in a cue list
func merge_into_cue(fixtures: Array, cue: Cue, mode: SaveMode = SaveMode.MODIFIED) -> void:
	store_data_to_container(cue, mode, fixtures)


## erases data into a cue by its number in a cue list
func erase_from_cue(fixtures: Array, cue: Cue, mode: SaveMode) -> void:
	erase_data_from_container(cue, mode, fixtures)


## Shortcut to set the color of fixtures
func shortcut_set_color(p_fixtures: Array, p_color: Color, p_mix_mode: MixMode) -> void:
	if not p_fixtures:
		return

	match p_mix_mode:
		MixMode.Additive:
			for fixture: Variant in p_fixtures:
				if fixture is Fixture:
					_set_individual_fixture_data(fixture, "ColorAdd_R", "ColorAdd_R", p_color.r, "root")
					_set_individual_fixture_data(fixture, "ColorAdd_G", "ColorAdd_G", p_color.g, "root")
					_set_individual_fixture_data(fixture, "ColorAdd_B", "ColorAdd_B", p_color.b, "root")

		MixMode.Subtractive:
			for fixture: Variant in p_fixtures:
				if fixture is Fixture:
					_set_individual_fixture_data(fixture, "ColorSub_C", "ColorSub_C", 1 - p_color.r, "root")
					_set_individual_fixture_data(fixture, "ColorSub_M", "ColorSub_M", 1 - p_color.g, "root")
					_set_individual_fixture_data(fixture, "ColorSub_Y", "ColorSub_Y", 1 - p_color.b, "root")
