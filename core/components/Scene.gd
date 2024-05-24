# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name Scene extends EngineComponent
## Engine class for creating and recalling saved data

signal state_changed(is_enabled: bool) ## Emmitted when this scene is enabled or dissabled

var fade_in_speed: float = 2 ## Fade in speed in seconds
var fade_out_speed: float = 2 ## Fade out speed in seconds

var enabled: bool = false: set = set_enabled ## The current state of this scene
var save_data: Dictionary = {} ## Saved data for this scene

var current_animation: Tween = null

func set_enabled(is_enabled: bool) -> void:
	## Enabled or dissables this scene
	
	enabled = is_enabled

	if current_animation:
		current_animation.pause()
	
	var new_current_animation: Tween = Core.create_tween()
	new_current_animation.set_parallel(true)

	if is_enabled:
		for fixture: Fixture in save_data:
			var color: Color = Color.BLACK
			if uuid in fixture.current_input_data:
				color = fixture.current_input_data[uuid].color
			
			new_current_animation.tween_method(fixture.set_color.bind(uuid), color, save_data[fixture].color, fade_in_speed)
	else:
		for fixture: Fixture in save_data:
			var color: Color = save_data[fixture].color
			if uuid in fixture.current_input_data:
				color = fixture.current_input_data[uuid].color
			new_current_animation.tween_method(fixture.set_color.bind(uuid), color, Color.BLACK, fade_out_speed)

	current_animation = new_current_animation


func set_fade_in_speed(p_fade_in_speed: float) -> void:
	fade_in_speed = p_fade_in_speed


func set_fade_out_speed(p_fade_out_speed: float) -> void:
	fade_out_speed = p_fade_out_speed


func set_save_data(saved_data: Dictionary) -> void:
	save_data = saved_data
	
	for fixture: Fixture in save_data.keys():
		fixture.on_delete_requested.connect(remove_fixture.bind(fixture), CONNECT_ONE_SHOT)


## Removes a fixture from save_data
func remove_fixture(fixture: Fixture) -> void:
	save_data.erase(fixture)


func _on_serialize_request() -> Dictionary:
	## Serializes this scene and returnes it in a dictionary
	
	return {
		"fade_in_speed": fade_in_speed,
		"fade_out_speed": fade_out_speed,
		"save_data": serialize_save_data()
	}


func _on_load_request(serialized_data: Dictionary) -> void:
		
	fade_in_speed = serialized_data.get("fade_in_speed", fade_in_speed)
	fade_out_speed = serialized_data.get("fade_out_speed", fade_out_speed)
	
	set_save_data(deserialize_save_data(serialized_data.get("save_data", {})))


func serialize_save_data() -> Dictionary:
	## Serializes save_data and returnes as a dictionary
	
	var serialized_save_data: Dictionary = {}
	
	for fixture: Fixture in save_data:
		serialized_save_data[fixture.uuid] = {}
		for save_key in save_data[fixture]:
			serialized_save_data[fixture.uuid][save_key] = Utils.serialize_variant(save_data[fixture][save_key])
	
	return serialized_save_data


func deserialize_save_data(serialized_data: Dictionary) -> Dictionary:
	## Deserializes save_data and returnes as a dictionary
	
	var deserialized_save_data: Dictionary = {}
	
	for fixture_uuid: String in serialized_data:
		var fixture_save: Dictionary = serialized_data[fixture_uuid]
		
		var deserialized_fixture_save = {}
		
		for saved_property: String in fixture_save:
			deserialized_fixture_save[saved_property] = Utils.deserialize_variant(fixture_save[saved_property])
		
		deserialized_save_data[Core.fixtures[fixture_uuid]] = deserialized_fixture_save
		
	return deserialized_save_data
