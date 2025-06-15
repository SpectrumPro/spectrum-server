# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name DataContainerAnimator extends Node
## A replacement for Godots Tween system. designed for animating fixtures


## Emitted each time this animation completes a step
signal steped(time: float)

## Emitted when this animation has stoped playing
signal finished


## The time_scale of this animator, 1 will play back at normal speed. Do not set this to negtive, instead use play_backwards
var _time_scale: float = 1

## Elapsed time since this animation started
var _progress: float = 0

## Layer Id for animating fixtures
var _layer_id: String = ""

## Contains all the infomation for this animation
var _tracks: Dictionary[ContainerItem, Dictionary] = {}

## Previous time for the animation step
var _previous_time: float = 0

## DataContainer, if any, to use
var _container: DataContainer

## Stores all track ids for containers
var _container_track_ids: Dictionary[Fixture, Dictionary]

## Seek to queued state
var _seek_queued: bool = false

## Signals to connect to the container
var _container_signals: Dictionary[String, Callable] = {
	"on_items_stored": _on_items_stored,
	"on_items_erased": _on_items_erased,
}


## Set process to false on start
func _ready() -> void:
	set_process(false)


## Process function, delta is used to calculate the interpolated values for the animation
func _process(delta: float) -> void:
	_progress += delta * _time_scale
	
	if _progress <= 0 or _progress >= 1:
		return finish()

	seek_to(_progress)
	steped.emit(_progress)


## Sets the data container to use for storage
func set_container(p_container: DataContainer) -> void:
	if is_instance_valid(_container):	
		Utils.disconnect_signals(_container_signals, _container)

	remove_all_data()
	_container = p_container

	if is_instance_valid(_container):
		Utils.connect_signals(_container_signals, _container)


## Sets the layer id
func set_layer_id(p_layer_id: String) -> void:
	_layer_id = p_layer_id


## Sets the time scale
func set_time_scale(p_time_scale: float) -> void:
	_time_scale = p_time_scale


## Plays this animation
func play() -> void:		
	set_process(true)


## Pauses this animation
func pause() -> void:
	set_process(false)


## Stops this scene, reset all values to default
func stop() -> void:
	set_process(false)
	_progress = 0

	for item: ContainerItem in _tracks.keys():
		item.get_fixture().erase_parameter(item.get_parameter(), _layer_id, item.get_zone())
		_tracks[item].first_time = true


## Finishes the animation imdetaly 
func finish() -> void:
	if _time_scale > 0:
		pause()
		seek_to(1)
	
	else:
		stop()

	steped.emit(_progress)
	finished.emit()


## Internal function to seek to a point in the animation
func seek_to(time: float) -> void:
	for item: ContainerItem in _tracks.keys():
		var from: float = _tracks[item].from
		var current: float = _tracks[item].current
		var first_time: bool = _tracks[item].first_time
		var new_data: float = - 1

		if item.get_can_fade():
			if time < item.get_start() or time > item.get_stop():
				continue

			var normalized_progress = (time - item.get_start()) / max(item.get_stop() - item.get_start(), 0.0001)
			new_data = Tween.interpolate_value(
				from,
				item.get_value() - from,
				normalized_progress,
				1,
				Tween.TRANS_LINEAR,
				Tween.EASE_IN_OUT
			)
		
		elif _previous_time > time and time <= item.get_stop():
			new_data = from
		
		elif time > _previous_time and time >= item.get_start():
			new_data = item.get_value()

		if new_data != - 1 and (current != new_data or first_time):
			_tracks[item].current = new_data
			_tracks[item].first_time = false

			item.get_fixture().set_parameter(
				item.get_parameter(), 
				item.get_function(),
				new_data,
				_layer_id,
				item.get_zone()
			)
	
	_progress = time
	_previous_time = time


## Called when data is stored to the container
func _on_items_stored(items: Array) -> void:
	for item: ContainerItem in items:
		_tracks[item] = {
			"from": item.get_fixture().get_current_value_layered_or_force_default(item.get_zone(), item.get_parameter(), _layer_id, item.get_function()),
			"current": 0.0,
			"first_time": true,
		}


## Called when data is stored to the container
func _on_items_erased(items: Array) -> void:
	for item: ContainerItem in items:
		item.get_fixture().erase_parameter(item.get_parameter(), _layer_id, item.get_zone())
		_tracks.erase(item)


## Deletes all the animated data
func remove_all_data() -> void:
	stop()
	_tracks.clear()
	_progress = 0
	_previous_time = 0


## Deletes this Animator, resets all values and queue_free()'s
func delete() -> void:
	remove_all_data()
	queue_free()
