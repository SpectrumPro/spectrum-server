# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name Programmer extends EngineComponent
## Engine class for programming lights, colors, positions, etc.


## Current data in the programmer
var save_data: Dictionary = {}

## Fixture layer IDs to use
var fixture_set_layer_id: String = Fixture.OVERRIDE
var fixture_reset_layer_id: String = Fixture.REMOVE_OVERRIDE

## List of all the channel keys which set_random is allowed to change. set_color is not in this list, as colors are handled differntly to other channels
var random_allowed_channel_keys: Array = [
	"ColorIntensityWhite",
	"ColorIntensityAmber",
	"ColorIntensityUV",
	"Dimmer"
]

## Max length in seconds for the fixture locate mode
var locate_max_length: float = 5


## Save Modes
enum SAVE_MODE {
	MODIFIED,		## Only save fixtures that have been changed in the programmer
	ALL,			## Save all values of the fixtures
	ALL_NONE_ZERO	## Save all values of the fixtures, as long as they are not the zero value for that channel
}


## Called when this EngineComponent is ready
func _component_ready() -> void:
	name = "Programmer"
	self_class_name = "Programmer"


func set_locate(fixtures: Array, enabled: bool) -> void:
	for fixture in fixtures:
		if fixture is Fixture:
			fixture.set_locate(enabled)


## Imports all the none zero values from the selected fixtures into the programmer
func import(fixtures: Array) -> void:
	for fixture in fixtures:
		if fixture is Fixture:
			for channel_key in fixture.current_values.keys():
				var value: Variant = fixture.current_values[channel_key]

				_set_individual_fixture_data(fixture, value, channel_key, fixture_set_layer_id)


func set_random(fixtures: Array, min: int, max: int, channel_key: String) -> void:
	if channel_key in random_allowed_channel_keys:
		for fixture in fixtures:
			if fixture is Fixture:
				_set_individual_fixture_data(fixture, randi_range(min, max), channel_key, fixture_set_layer_id)


func set_color_random(fixtures: Array, min: int, max: int, color_key: String) -> void:
	for fixture in fixtures:
		if fixture is Fixture:
			var new_color: Color = fixture.get_value_from_layer_id(fixture_set_layer_id, "set_color")
			match color_key:
				"r": new_color.r8 = randi_range(min, max)
				"g": new_color.g8 = randi_range(min, max)
				"b": new_color.b8 = randi_range(min, max)
				"h": new_color.h = remap(randi_range(min, max), 0, 360, 0.0, 1.0)
				"s": new_color.s = remap(randi_range(min, max), 0, 255, 0.0, 1.0)
				"v": new_color.v = remap(randi_range(min, max), 0, 255, 0.0, 1.0)

			_set_individual_fixture_data(fixture, new_color, "set_color", fixture_set_layer_id)



func set_color(fixtures: Array, color: Color) -> void: 			_set_fixture_data(fixtures, color, "set_color", 			fixture_set_layer_id)
func ColorIntensityWhite(fixtures: Array, value: int) -> void: 	_set_fixture_data(fixtures, value, "ColorIntensityWhite", 	fixture_set_layer_id)
func ColorIntensityAmber(fixtures: Array, value: int) -> void: 	_set_fixture_data(fixtures, value, "ColorIntensityAmber", 	fixture_set_layer_id)
func ColorIntensityUV(fixtures: Array, value: int) -> void: 	_set_fixture_data(fixtures, value, "ColorIntensityUV", 		fixture_set_layer_id)
func Dimmer(fixtures: Array, value: int) -> void: 				_set_fixture_data(fixtures, value, "Dimmer", 				fixture_set_layer_id)


func reset_color(fixtures: Array) -> void: 						_set_fixture_data(fixtures, Color.BLACK, "set_color", 		fixture_reset_layer_id)
func reset_ColorIntensityWhite(fixtures: Array) -> void:		_set_fixture_data(fixtures, 0, "ColorIntensityWhite", 		fixture_reset_layer_id)
func reset_ColorIntensityAmber(fixtures: Array) -> void: 		_set_fixture_data(fixtures, 0, "ColorIntensityAmber",		fixture_reset_layer_id)
func reset_ColorIntensityUV(fixtures: Array) -> void:			_set_fixture_data(fixtures, 0, "ColorIntensityUV", 			fixture_reset_layer_id)
func reset_Dimmer(fixtures: Array) -> void: 					_set_fixture_data(fixtures, 0, "Dimmer", 					fixture_reset_layer_id)


## Function to set the fixture data at the given chanel key
func _set_fixture_data(fixtures: Array, value: Variant, channel_key: String, layer_id: String) -> void:
	for fixture in fixtures:
		if fixture is Fixture:
			_set_individual_fixture_data(fixture, value, channel_key, layer_id)


## Sets the data on a single fixture at a time
func _set_individual_fixture_data(fixture: Fixture, value: Variant, channel_key: String, layer_id: String) -> void:
	fixture.get(channel_key).call(value, layer_id)
	# Check to see if the value is 0, if so remove it from save_data
	if value or layer_id == Fixture.OVERRIDE:
		if fixture not in save_data:
			save_data[fixture] = {}

		save_data[fixture][channel_key] = value

	elif fixture in save_data:
		save_data[fixture].erase(channel_key)


func store_data_to_function(function: Function, mode: SAVE_MODE, fixtures: Array = []) -> void:
	match mode:
		SAVE_MODE.MODIFIED:
			for fixture: Fixture in fixtures:
				if fixture in save_data:
					for channel_key: String in save_data[fixture]:
						function.store_data(fixture, channel_key, save_data[fixture][channel_key])

		SAVE_MODE.ALL:
			for fixture in fixtures:
				if fixture is Fixture:
					for channel_key: String in fixture.current_values:
						function.store_data(fixture, channel_key, fixture.current_values[channel_key])

		SAVE_MODE.ALL_NONE_ZERO:
			for fixture in fixtures:
				if fixture is Fixture:
					for channel_key: String in fixture.current_values:
						if fixture.current_values[channel_key]:
							function.store_data(fixture, channel_key, fixture.current_values[channel_key])


func erace_data_from_function(function: Function, mode: SAVE_MODE, fixtures: Array = []) -> void:
	match mode:
		SAVE_MODE.MODIFIED:
			for fixture: Fixture in fixtures:
				if fixture in save_data:
					for channel_key: String in save_data[fixture]:
						function.erace_data(fixture, channel_key)

		SAVE_MODE.ALL:
			for fixture in fixtures:
				if fixture is Fixture:
					for channel_key: String in fixture.current_values:
						function.erace_data(fixture, channel_key)

		SAVE_MODE.ALL_NONE_ZERO:
			for fixture in fixtures:
				if fixture is Fixture:
					for channel_key: String in fixture.current_values:
						if fixture.current_values[channel_key]:
							function.erace_data(fixture, channel_key)


## Saves the current state of this programmer to a scene
func save_to_scene(fixtures: Array, mode: SAVE_MODE = SAVE_MODE.MODIFIED) -> Scene:
	var new_scene: Scene = Scene.new()
	store_data_to_function(new_scene, mode, fixtures)

	Core.add_function(new_scene)
	return new_scene


## Saves the selected fixtures to a new cue, using SAVE_MODE
func save_to_new_cue(fixtures: Array, cue_list: CueList, mode: SAVE_MODE) -> void:
	if not fixtures:
		return

	var new_cue: Cue = Cue.new()

	store_data_to_function(new_cue, mode, fixtures)

	cue_list.add_cue(new_cue, 0, true)


func merge_into_cue(fixtures: Array, cue_list: CueList, cue_number: float, mode: SAVE_MODE) -> void:
	var cue: Cue = cue_list.get_cue(cue_number)

	if cue:
		store_data_to_function(cue, mode, fixtures)
		cue_list.force_reload = true


func erace_from_cue(fixtures: Array, cue_list: CueList, cue_number: float, mode: SAVE_MODE) -> void:
	var cue: Cue = cue_list.get_cue(cue_number)

	if cue:
		erace_data_from_function(cue, mode, fixtures)
		cue_list.force_reload = true


## Saves the current state of fixtures to a new cue list
func save_to_new_cue_list(fixtures: Array) -> void:

	var new_cue_list: CueList = CueList.new()

	var blackout_cue: Cue = Cue.new()
	blackout_cue.name = "Blackout"

	var new_cue: Cue = Cue.new()

	store_data_to_function(new_cue, SAVE_MODE.MODIFIED, fixtures)

	for fixture: Fixture in save_data:
		for channel_key: String in save_data[fixture]:
			new_cue.store_data(fixture, channel_key, save_data[fixture][channel_key])

	new_cue_list.add_cue(blackout_cue, 0.5)
	new_cue_list.add_cue(new_cue, 1, true)

	Core.add_function(new_cue_list)
