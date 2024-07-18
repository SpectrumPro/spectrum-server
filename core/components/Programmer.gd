# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name Programmer extends EngineComponent
## Engine class for programming lights, colors, positions, etc.

var save_data: Dictionary = {} ## Current data in the programmer

var fixture_layer_id: String = "programmer_" + uuid

## Called when this EngineComponent is ready
func _component_ready() -> void:
	name = "Programmer"
	self_class_name = "Programmer"


## Sets the color of all the fixtures in [pram fixtures], to color
func set_color(fixtures: Array, color: Color) -> void:
	
	for fixture in fixtures:
		if fixture is Fixture:
			fixture.set_color(color, fixture_layer_id)
			
			if fixture not in save_data:
				save_data[fixture] = {}
			
			save_data[fixture].color = color


## Sets the white intensity of all the fixtures pass in [pram fixtures] 
func set_white_intensity(fixtures: Array, value: int) -> void:
	for fixture in fixtures:
		if fixture is Fixture:
			value = clamp(value, 0, 255)
			fixture.set_white_intensity(value, fixture_layer_id)
			
			# Check to see if the value is 0, if so remove it from save_data
			if value:
				if fixture not in save_data:
					save_data[fixture] = {}
				
				save_data[fixture].white = value

			elif fixture in save_data:
				save_data[fixture].erase("white")



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
