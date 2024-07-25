# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name Programmer extends EngineComponent
## Engine class for programming lights, colors, positions, etc.


## Current data in the programmer
var save_data: Dictionary = {}

var fixture_layer_id: String = Fixture.OVERRIDE

enum SAVE_MODE {MODIFIED, ALL, ALL_NONE_ZERO}


## Called when this EngineComponent is ready
func _component_ready() -> void:
	name = "Programmer"
	self_class_name = "Programmer"


func set_color(fixtures: Array, color: Color) -> void: _set_fixture_data(fixtures, color, "set_color", fixture_layer_id)
func ColorIntensityWhite(fixtures: Array, value: int) -> void: _set_fixture_data(fixtures, value, "ColorIntensityWhite", fixture_layer_id)
func ColorIntensityAmber(fixtures: Array, value: int) -> void: _set_fixture_data(fixtures, value, "ColorIntensityAmber", fixture_layer_id)
func ColorIntensityUV(fixtures: Array, value: int) -> void: _set_fixture_data(fixtures, value, "ColorIntensityUV", fixture_layer_id)
func Dimmer(fixtures: Array, value: int) -> void: _set_fixture_data(fixtures, value, "Dimmer", fixture_layer_id)


func reset_color(fixtures: Array) -> void: _set_fixture_data(fixtures, Color.BLACK, "set_color", Fixture.REMOVE_OVERRIDE)
func reset_ColorIntensityWhite(fixtures: Array) -> void: _set_fixture_data(fixtures, 0, "ColorIntensityWhite", Fixture.REMOVE_OVERRIDE)
func reset_ColorIntensityAmber(fixtures: Array) -> void: _set_fixture_data(fixtures, 0, "ColorIntensityAmber", Fixture.REMOVE_OVERRIDE)
func reset_ColorIntensityUV(fixtures: Array) -> void: _set_fixture_data(fixtures, 0, "ColorIntensityUV", Fixture.REMOVE_OVERRIDE)
func reset_Dimmer(fixtures: Array) -> void: _set_fixture_data(fixtures, 0, "Dimmer", Fixture.REMOVE_OVERRIDE)


func _set_fixture_data(fixtures: Array, value: Variant, channel_key: String, layer_id: String):
	for fixture in fixtures:
		if fixture is Fixture:
			fixture.get(channel_key).call(value, layer_id)
			# Check to see if the value is 0, if so remove it from save_data
			if value:
				if fixture not in save_data:
					save_data[fixture] = {}
				
				save_data[fixture][channel_key] = value

			elif fixture in save_data:
				save_data[fixture].erase(channel_key)


## Saves the current state of this programmer to a scene
func save_to_scene(name: String = "New Scene") -> Scene:
	
	var new_scene: Scene = Scene.new()
	
	for fixture: Fixture in save_data:
		for channel_key: String in save_data[fixture].keys():
			new_scene.add_data(fixture, channel_key, fixture.get_zero_from_channel_key(channel_key), save_data[fixture][channel_key])


	new_scene.name = name
	
	Core.add_function(new_scene)
	
	return new_scene


func save_to_new_cue(fixtures: Array, cue_list: CueList, mode: SAVE_MODE) -> void:
	if not fixtures:
		return
	
	var new_cue: Cue = Cue.new()

	match mode:
		SAVE_MODE.MODIFIED:
			print("SAVE_MODE.MODIFIED")
			for fixture: Fixture in save_data:
				for channel_key: String in save_data[fixture]:
					new_cue.store_data(fixture, channel_key, save_data[fixture][channel_key], fixture.get_zero_from_channel_key(channel_key))

		SAVE_MODE.ALL:	
			print("SAVE_MODE.ALL")
			for fixture in fixtures:
				if fixture is Fixture:
					for channel_key: String in fixture.current_values:
						new_cue.store_data(fixture, channel_key, fixture.current_values[channel_key], fixture.get_zero_from_channel_key(channel_key))

		SAVE_MODE.ALL_NONE_ZERO:
			print("SAVE_MODE.ALL_NONE_ZERO")
			for fixture in fixtures:
				if fixture is Fixture:
					for channel_key: String in fixture.current_values:
						if fixture.current_values[channel_key]:
							new_cue.store_data(fixture, channel_key, fixture.current_values[channel_key], fixture.get_zero_from_channel_key(channel_key))

	cue_list.add_cue(new_cue, 0, true)


## Saves the current state of fixtures to a new cue list
func save_to_new_cue_list() -> void:

	var new_cue_list: CueList = CueList.new()

	var blackout_cue: Cue = Cue.new()
	blackout_cue.name = "Blackout"

	var new_cue: Cue = Cue.new()

	for fixture: Fixture in save_data:
		for channel_key: String in save_data[fixture]:
			new_cue.store_data(fixture, channel_key, save_data[fixture][channel_key], fixture.get_zero_from_channel_key(channel_key))

	new_cue_list.add_cue(blackout_cue, 0.5)
	new_cue_list.add_cue(new_cue)

	Core.add_function(new_cue_list)