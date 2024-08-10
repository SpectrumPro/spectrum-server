# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name Scene extends Function
## Function for creating and recalling saved data


## Emitted when this scene is _enabled or dissabled
signal on_state_changed(is_enabled: bool)

## Emitted when the fade speed has changed
signal on_fade_time_changed(fade_in_speed: float, fade_out_speed: float)

## Emitted when the current percentage step of this scene changes, ie the current position during the fade from 0 to 1.0
signal on_percentage_step_changed(percentage: float)
 

var network_config: Dictionary = {
	"high_frequency_signals": [
		on_percentage_step_changed
	]
}


## Fade in time in seconds, defaults to 2 seconds
var fade_in_speed: float = 2 : set = set_fade_in_speed


## Fade out time in seconds, defaults to 2 seconds
var fade_out_speed: float = 2 : set = set_fade_out_speed



## The current state of this scene
var _enabled: bool = false

## Saved data for this scene
var _save_data: Dictionary = {}

## The Animator used for this scene
var _animator: Animator = Core.create_animator()

var _time_scale_befour_flash: float  = 0
var _time_befour_flash: float = 0
var _backwards_befour_flash: bool = false
var _flash_active: bool = false

## Called when this EngineComponent is ready
func _component_ready() -> void:

	name = "Scene"
	self_class_name = "Scene"

	_allow_store_zero_data = false

	_animator.steped.connect(func (step: float): 
		var value

		if _animator.length == 0:
			value = step
		else:
			value = remap(step, 0, _animator.length, 0.0, 1.0)

		on_percentage_step_changed.emit(value)
	)


## Sets the state of this scene
func set_enabled(p_enabled: bool, fade_time: float = -1) -> void:
	_enabled = p_enabled

	# Workout wheather we are enabling or dissabling this scene, then adust the animation time scale to be fade_time * length
	# _animator.length always equals 1, so setting the time scale to 0.5 will cause the animation to run at half speed
	# This is to work around the issue where if the length is 0, the animation wont play as it will stop immediately 
	if _enabled:
		fade_time = fade_in_speed if fade_time == -1 else fade_time

		_animator.time_scale = _animator.length / fade_time

	else:
		fade_time = fade_out_speed if fade_time == -1 else fade_time

		_animator.time_scale = _animator.length / fade_time


	_animator.play_backwards = not _enabled
	_animator.play()

	on_state_changed.emit(_enabled)


## Returnes the state of this scene
func is_enabled() -> bool:
	return _enabled


## Resumes playback of this scene after calling pause()
func play() -> void:
	_animator.play()


## Pauses this scene
func pause() -> void:
	_animator.pause()


## Set the step percentage of this scene, value ranges from 0.0 to 1.0, and is used as a percentage to control the underlaying animation
func set_step_percentage(step: float) -> void:
	_enabled = true if step else false
	on_state_changed.emit(_enabled)

	_animator.pause()
	_animator.seek_to_percentage(step)


## Returnes the percentage step
func get_step_percentage() -> float:
	return _animator.elapsed_time / _animator.length


## Enables the scene in flash mode, this will force it to be held at 100%, and when released with flash_release, it will return to where it was befour the flash
func flash_hold(fade_in: float = fade_in_speed) -> void:
	if not _flash_active:
		_time_befour_flash = _animator.elapsed_time
		_time_scale_befour_flash = _animator.time_scale
		_backwards_befour_flash = _animator.play_backwards
	
	_flash_active = true

	if _animator.finished.is_connected(_animator_finished_flash_callback):
		_animator.finished.disconnect(_animator_finished_flash_callback)

	_animator.time_scale = _animator.length /  fade_in
	_animator.play_backwards = false
	_animator.play()



func _animator_finished_flash_callback() -> void:
	_animator.time_scale = _time_scale_befour_flash
	_animator.play_backwards = _backwards_befour_flash

	_flash_active = false


func flash_release(fade_out: float = fade_out_speed) -> void:
	_animator.time_scale = _animator.length /  fade_out
	_animator.play_backwards = true
	_animator.play(_time_befour_flash)


	_animator.finished.connect(_animator_finished_flash_callback, CONNECT_ONE_SHOT)

	

## Add a method to this scene
func store_data(fixture: Fixture, channel_key: String, value: Variant, p_store_data: Dictionary = _save_data) -> bool:
	var store_state: bool = store_data_static(fixture, channel_key, value, p_store_data)

	if store_state:
		_animator.animate_method(fixture.get(channel_key).bind("scene_" + uuid), fixture.get_zero_from_channel_key(channel_key), value)


	return store_state



## Sets the fade in speed in seconds
func set_fade_in_speed(speed: float) -> void:
	fade_in_speed = speed
	on_fade_time_changed.emit(fade_in_speed, fade_out_speed)


## Sets the fade out speed in seconds
func set_fade_out_speed(speed: float) -> void:
	fade_out_speed = speed
	on_fade_time_changed.emit(fade_in_speed, fade_out_speed)


## Serializes this scene and returnes it in a dictionary
func _on_serialize_request(mode: int) -> Dictionary:

	var serialized_data: Dictionary = {
		"fade_in_speed": fade_in_speed,
		"fade_out_speed": fade_out_speed,
		"save_data": serialize_stored_data(_save_data)
	}

	if mode == CoreEngine.SERIALIZE_MODE_NETWORK:
		serialized_data["enabled"] = is_enabled()
		serialized_data["percentage_step"] = get_step_percentage()

	return serialized_data


## Called when this scene is to be loaded from serialized data
func _on_load_request(serialized_data: Dictionary) -> void:
		
	fade_in_speed = serialized_data.get("fade_in_speed", fade_in_speed)
	fade_out_speed = serialized_data.get("fade_out_speed", fade_out_speed)
	
	load_stored_data(serialized_data.get("save_data", {}), _save_data, store_data)

## Called when this scene is to be deleted
func _on_delete_request() -> void:
	_animator.delete()
