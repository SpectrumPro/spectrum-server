# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name Programmer extends EngineComponent
## Engine class for programming lights, colors, positions, etc.

var save_data: Dictionary = {} ## Current data in the programmer

var fixture_layer_id: String = Fixture.OVERRIDE

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


func _set_fixture_data(fixtures: Array, value: Variant, method: String, layer_id: String):
	for fixture in fixtures:
		if fixture is Fixture:
			fixture.get(method).call(value, layer_id)
			# Check to see if the value is 0, if so remove it from save_data
			if value:
				if fixture not in save_data:
					save_data[fixture] = {}
				
				save_data[fixture][method] = value

			elif fixture in save_data:
				save_data[fixture].erase(method)


## Saves the current state of this programmer to a scene
func save_to_scene(name: String = "New Scene") -> Scene:
	
	var new_scene: Scene = Scene.new()
	
	for fixture: Fixture in save_data:
		for channel: String in save_data[fixture].keys():
			match channel:
				"color":
					new_scene.add_data(fixture, "set_color", Color.BLACK, save_data[fixture].color)
				"white":
					new_scene.add_data(fixture, "set_white_intensity", 0, save_data[fixture].white)


	new_scene.name = name
	
	Core.add_function(new_scene)
	
	return new_scene
