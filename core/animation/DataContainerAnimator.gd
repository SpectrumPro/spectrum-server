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
var _tracks: Dictionary[int, Dictionary] = {}

## Previous time for the animation step
var _previous_time: float = 0

## DataContainer, if any, to use
var _container: DataContainer

## Stores all track ids for containers
var _container_track_ids: Dictionary[Fixture, Dictionary]

## Signals to connect to the container
var _container_signals: Dictionary[String, Callable] = {
	"on_data_stored": _on_data_stored,
	"on_data_erased": _on_data_erased
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

	for track: Dictionary in _tracks.values():
		(track.fixture as Fixture).erase_parameter(
			track.parameter,
			_layer_id,
			track.zone
		)


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
	for animation_track in _tracks.values():
		var new_data: float = - 1

		if animation_track.can_fade:
			if time < animation_track.start or time > animation_track.stop:
				continue

			var normalized_progress = (time - animation_track.start) / max(animation_track.stop - animation_track.start, 0.0001)
			new_data = Tween.interpolate_value(
				animation_track.from,
				animation_track.to - animation_track.from,
				normalized_progress,
				1,
				Tween.TRANS_LINEAR,
				Tween.EASE_IN_OUT
			)
		
		elif _previous_time > time and time <= animation_track.stop:
			new_data = animation_track.from
		
		elif time > _previous_time and time >= animation_track.start:
			new_data = animation_track.to

		if new_data != - 1 and (animation_track.current != new_data or animation_track.first_time):
			animation_track.current = new_data
			animation_track.first_time = false

			var fixture: Fixture = animation_track.fixture
			fixture.set_parameter(animation_track.parameter, animation_track.function, new_data, _layer_id, animation_track.zone)
	
	_progress = time
	_previous_time = time


## Adds a method animation, method animation will call a method for each step in the animation, with the interpolated Variant as the argument
func add_track(fixture: Fixture, parameter: String, function: String, zone: String, from: float, to: float, can_fade: bool = true, start: float = 0.0, stop: float = 1.0) -> int:
	var ids: Array = _tracks.keys()
	ids.sort()	
	var id: int = type_convert(ids.max(), TYPE_INT) + 1

	_tracks[id] = {
		"fixture": fixture,
		"parameter": parameter,
		"function": function,
		"zone": zone,
		"from": from,
		"to": to,
		"current": from,
		"can_fade": can_fade,
		"start": start,
		"stop": stop,
		"first_time": true
	}

	return id


## Removes an animated method, will reset all values to default if reset == true
func remove_track(id: Variant, reset: bool = true) -> void:
	if _tracks.has(id):
		if reset:
			var track: Dictionary = _tracks[id]
			track.fixture.set_parameter(track.parameter, track.function, track.from, _layer_id, track.zone)

		_tracks.erase(id)


## Gets an animated track from the given id
func get_track_from_id(id: Variant) -> Dictionary:
	return _tracks.get(id, {}).duplicate()


## Returnes a copy of the animated data
func get_animated_data(duplicate_data: bool = true) -> Dictionary:
	return _tracks.duplicate(true) if duplicate_data else _tracks


## Sets the animated data
func set_animated_data(animation_data: Dictionary) -> void:
	_tracks = animation_data.duplicate()


## Called when data is stored to the container
func _on_data_stored(fixture: Fixture, parameter: String, function: String, value: Variant, zone: String, can_fade: bool, start: float, stop: float) -> void:
	var id: int = add_track(fixture, parameter, function, zone, fixture.get_default(zone, parameter, function), value, can_fade, start, stop)	
	_container_track_ids.get_or_add(fixture, {}).get_or_add(zone, {})[parameter] = id


## Called when data is stored to the container
func _on_data_erased(fixture: Fixture, parameter: String, zone: String) -> void:
	remove_track(_container_track_ids[fixture][zone][parameter])

	if not _container_track_ids[fixture][zone][parameter]:
		_container_track_ids[fixture][zone].erase(parameter)

		if not _container_track_ids[fixture][zone]:
			_container_track_ids[fixture].erase(zone)

			if not _container_track_ids[fixture]:
				_container_track_ids.erase(fixture)


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
