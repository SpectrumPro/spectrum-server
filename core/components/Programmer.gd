# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name Programmer extends EngineComponent
## Engine class for programming lights, colors, positions, etc.

var save_data: Dictionary = {} ## Current data in the programmer


## Sets the color of all the fixtures in [pram fixtures], to color
func set_color(fixtures: Array, color: Color) -> void:
	
	for fixture in fixtures:
		if fixture is Fixture:
			fixture.set_color(color, "programmer_" + uuid)
			
			if fixture not in save_data:
				save_data[fixture] = {}
			
			save_data[fixture].color = color


## Sets the white intensity of all the fixtures pass in [pram fixtures] 
func set_white_intensity(fixtures: Array, value: int) -> void:
	for fixture in fixtures:
		if fixture is Fixture:
			value = clamp(value, 0, 255)
			fixture.set_white_intensity(value, "programmer_" + uuid)
			
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
	
	new_scene.set_save_data(save_data.duplicate(true))
	new_scene.name = name
	
	Core.add_scene(new_scene)
	
	return new_scene
