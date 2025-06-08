# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name Scene extends Function
## Function for creating and recalling saved data


## Emitted when the fade in time has changed
signal on_fade_in_speed_changed(fade_in_time: float)

## Emitted when the fade out time has changed
signal on_fade_out_speed_changed(fade_out_time: float)


## Fade in time in seconds, defaults to 2 seconds
var _fade_in_speed: float = 2

## Fade out time in seconds, defaults to 2 seconds
var _fade_out_speed: float = 2

## The Animator used for this scene
var _animator: DataContainerAnimator = DataContainerAnimator.new()


## Called when this EngineComponent is ready
func _component_ready() -> void:
	set_name("New Scene")
	set_self_class("Scene")

	_auto_start = false
	_auto_stop = false

	_data_container.set_allow_store_zero_data(true)
	_animator.set_container(_data_container)

	_animator.set_layer_id(uuid)
	_animator.steped.connect(_on_animator_stepped)
	_animator.finished.connect(_on_animator_finished)
	Core.add_child(_animator)


## Handles ActiveState changes
func _handle_active_state_change(p_active_state: ActiveState) -> void:
	if (_intensity == 0 and p_active_state == ActiveState.DISABLED ) or (_intensity == 1 and p_active_state == ActiveState.ENABLED):
		if get_transport_state() != TransportState.PAUSED:
			set_transport_state(TransportState.PAUSED)
		
		return
	
	var fade_speed: float = (_fade_in_speed if p_active_state else -_fade_out_speed)

	if fade_speed:
		_animator.set_time_scale(1 / fade_speed)
		_animator.play()

	else:
		_animator.seek_to(1 if p_active_state else 0)
	
	_set_transport_state(TransportState.FORWARDS if p_active_state else TransportState.BACKWARDS)


## Handles TransportState changes
func _handle_transport_state_change(p_transport_state: TransportState) -> void:
	match p_transport_state:
		TransportState.FORWARDS:
			set_active_state(ActiveState.ENABLED)
		
		TransportState.PAUSED:
			_animator.pause()
		
		TransportState.BACKWARDS:
			set_active_state(ActiveState.DISABLED)


## Handles intensity changes, this is only called when intensity is changed externaly
func _handle_intensity_change(p_intensity: float) -> void:
	if get_transport_state() != TransportState.PAUSED:
		set_transport_state(TransportState.PAUSED)

	if p_intensity and get_active_state() != ActiveState.ENABLED:
		_set_active_state(ActiveState.ENABLED)
	
	if p_intensity:
		_animator.seek_to(p_intensity)
	else:
		_animator.stop()


## Sets the fade in speed in seconds
func set_fade_in_speed(speed: float) -> void:
	_fade_in_speed = abs(speed)
	on_fade_in_speed_changed.emit(_fade_in_speed)


## Sets the fade out speed in seconds
func set_fade_out_speed(speed: float) -> void:
	_fade_out_speed = abs(speed)
	on_fade_out_speed_changed.emit(_fade_out_speed)


## Called when the animator steps
func _on_animator_stepped(step: float) -> void:
	_set_intensity(step)


## Called when the animator is finished
func _on_animator_finished() -> void:
	_set_transport_state(TransportState.PAUSED)


## Serializes this scene and returnes it in a dictionary
func _on_serialize_request(mode: int) -> Dictionary:
	var serialized_data: Dictionary = {
		"fade_in_speed": _fade_in_speed,
		"fade_out_speed": _fade_out_speed,
		"save_data": _data_container.serialize()
	}

	return serialized_data


## Called when this scene is to be loaded from serialized data
func _on_load_request(serialized_data: Dictionary) -> void:	
	_fade_in_speed = abs(type_convert(serialized_data.get("fade_in_speed", _fade_in_speed), TYPE_FLOAT))
	_fade_out_speed = abs(type_convert(serialized_data.get("fade_out_speed", _fade_out_speed), TYPE_FLOAT))
	
	Server.remove_networked_object(_data_container.uuid)
	_data_container.load(serialized_data.get("save_data", {}))
	Server.add_networked_object(_data_container.uuid, _data_container)


## Called when this scene is to be deleted
func _on_delete_request() -> void:
	_animator.delete()
