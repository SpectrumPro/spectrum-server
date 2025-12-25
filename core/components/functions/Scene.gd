# Copyright (c) 2025 Liam Sherwin. All rights reserved.
# This file is part of the Spectrum Lighting Controller, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

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
func _init(p_uuid: String = UUID_Util.v4(), p_name: String = _name) -> void:
	super._init(p_uuid, p_name)
	
	set_name("Scene")
	_set_self_class("Scene")
	
	_auto_start = false
	_auto_stop = false

	_animator.set_container(_data_container)

	_animator.set_layer_id(uuid())
	_animator.steped.connect(_on_animator_stepped)
	_animator.finished.connect(_on_animator_finished)
	Core.add_child(_animator)

	_settings_manager.register_setting("fade_in", Data.Type.FLOAT, set_fade_in_speed, get_fade_in_speed, [on_fade_in_speed_changed])
	_settings_manager.register_setting("fade_out", Data.Type.FLOAT, set_fade_out_speed, get_fade_out_speed, [on_fade_out_speed_changed])

	_settings_manager.register_networked_methods_auto([
		set_fade_in_speed,
		set_fade_out_speed,
		get_fade_in_speed,
		get_fade_out_speed,
	])

	_settings_manager.register_networked_signals_auto([
		on_fade_in_speed_changed,
		on_fade_out_speed_changed,
	])


## Handles ActiveState changes
func _handle_active_state_change(p_active_state: ActiveState) -> void:
	if (_intensity == 0 and p_active_state == ActiveState.DISABLED ) or (_intensity == 1 and p_active_state == ActiveState.ENABLED):
		if get_transport_state() != TransportState.PAUSED:
			set_transport_state(TransportState.PAUSED)
		
		return
	
	var fade_speed: float = (_fade_in_speed if p_active_state else -_fade_out_speed)

	if fade_speed != 0:
		_animator.set_time_scale(1.0 / fade_speed)
		_animator.play()
		
	else:
		_animator.pause()
		_animator.seek_to(1 if p_active_state else 0)
		_set_intensity(1 if p_active_state else 0)
	
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


## Gets the current fade speed
func get_fade_in_speed() -> float: 
	return _fade_in_speed


## Gets the fade out speed
func get_fade_out_speed() -> float: 
	return _fade_out_speed


## Called when the animator steps
func _on_animator_stepped(step: float) -> void:
	_set_intensity(step)


## Called when the animator is finished
func _on_animator_finished() -> void:
	_set_transport_state(TransportState.PAUSED)


## Called when this scene is to be deleted
func delete(p_local_only: bool = false) -> void:
	_animator.delete()
	super.delete(p_local_only)


## Serializes this scene and returnes it in a dictionary
func serialize(p_flags: int = 0) -> Dictionary:
	return super.serialize(p_flags).merged({
		"fade_in_speed": _fade_in_speed,
		"fade_out_speed": _fade_out_speed,
		"save_data": _data_container.serialize(p_flags)
	})


## Called when this scene is to be loaded from serialized data
func deserialize(p_serialized_data: Dictionary) -> void:
	super.deserialize(p_serialized_data)

	_fade_in_speed = abs(type_convert(p_serialized_data.get("fade_in_speed", _fade_in_speed), TYPE_FLOAT))
	_fade_out_speed = abs(type_convert(p_serialized_data.get("fade_out_speed", _fade_out_speed), TYPE_FLOAT))
	
	Network.deregister_network_object(_data_container.settings())
	_data_container.load(p_serialized_data.get("save_data", {}))
	Network.register_network_object(_data_container.uuid(), _data_container.settings())