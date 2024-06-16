# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name Scene extends Function
## Engine class for creating and recalling saved data


## Emitted when this scene is _enabled or dissabled
signal on_state_changed(is_enabled: bool)

## Emitted when the fade in or out speed is changed
signal on_fade_speed_changed(fade_in: float, fade_out: float)

## Emitted when the current percentage step of this scene changes, ie the current position during the fade from 0 to 1.0
signal on_percentage_step_changed(percentage: float)


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
		print(_time_befour_flash)
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
func add_data(fixture: Fixture, method: String, default_data: Variant, data: Variant) -> void:

	if fixture.get(method) is Callable:
		_animator.animate_method(fixture.get(method).bind("scene_" + uuid), default_data, data)

		if not fixture.uuid in _save_data:
			_save_data[fixture.uuid] = []
		
		_save_data[fixture.uuid].append({
			"default": default_data,
			"data": data,
			"method": method
		})


## Serializes this scene and returnes it in a dictionary
func _on_serialize_request(mode: int) -> Dictionary:
	
	var serialized_save_data: Dictionary = {}

	for fixture_uuid: String in _save_data:
		serialized_save_data[fixture_uuid] = []

		var data: Array = _save_data[fixture_uuid]
		for track in data:
			serialized_save_data[fixture_uuid].append({
				"default": var_to_str(track.default),
				"data": var_to_str(track.data),
				"method": track.method
			})

	var serialized_data: Dictionary = {
		"fade_in_speed": fade_in_speed,
		"fade_out_speed": fade_out_speed,
		"save_data": serialized_save_data
	}

	if mode == CoreEngine.SERIALIZE_MODE_NETWORK:
		print("Seralizing for network")
		serialized_data["enabled"] = is_enabled()
		serialized_data["percentage_step"] = get_step_percentage()

	return serialized_data

## Called when this scene is to be loaded from serialized data
func _on_load_request(serialized_data: Dictionary) -> void:
		
	fade_in_speed = serialized_data.get("fade_in_speed", fade_in_speed)
	fade_out_speed = serialized_data.get("fade_out_speed", fade_out_speed)
	
	for fixture_uuid: String in serialized_data.get("save_data", {}):
		if fixture_uuid in Core.fixtures:
			var data: Array = serialized_data.save_data[fixture_uuid]
			for track in data:
				print(track)
				print(var_to_str(Color.BLACK))
				add_data(Core.fixtures[fixture_uuid], track.get("method", ""), str_to_var(track.get("default", 0)), str_to_var(track.get("data", 0)))


## Called when this scene is to be deleted
func _on_delete_request() -> void:
	_animator.delete()