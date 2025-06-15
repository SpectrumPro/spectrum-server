# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name CueAnimator extends Node
## A replacement for Godots Tween system. designed for animating fixtures


## Emitted each time this animation completes a step
signal steped(time: float)

## Emitted when this animation has stoped playing
signal finished


## The time_scale of this animator, 1 will play back at normal speed. Do not set this to negtive, instead use play_backwards
var _time_scale: float = 1

## Elapsed time since this animation started
var _progress: float = 0

## Playing state
var _is_playing: bool = false

## Intensity of the CueList
var _intensity: float = 1

## Layer Id for animating fixtures
var _layer_id: String = ""

## List of parameters that are allowed to be faded by intensity
var _allowed_intensity_parameters: Array[String]

## Contains all the infomation for this animation
var _tracks: Dictionary[String, Dictionary] = {}

## Previous time for the animation step
var _previous_time: float = 0


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


## Sets the layer id
func set_layer_id(p_layer_id: String) -> void:
	_layer_id = p_layer_id


## Sets the list of alowed_intensity_parameters
func set_allowed_intensity_parameters(p_allowed_intensity_parameters: Array[String]) -> void:
	_allowed_intensity_parameters = p_allowed_intensity_parameters


## Sets the time scale
func set_time_scale(p_time_scale: float) -> void:
	_time_scale = p_time_scale


## Sets the intensity
func set_intensity(p_intensity: float) -> void:
	_intensity = p_intensity


## Checks is this CueAnimator is playing
func is_playing() -> bool:
	return _is_playing


## Plays this animation
func play() -> void:		
	set_process(true)
	_is_playing = true


## Pauses this animation
func pause() -> void:
	set_process(false)
	_is_playing = false


## Stops this scene, reset all values to default
func stop() -> void:
	pause()
	_progress = 0

	finished.emit()


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

			if animation_track.parameter in _allowed_intensity_parameters:
				new_data *= _intensity

			fixture.set_parameter(animation_track.parameter, animation_track.function, new_data, _layer_id, animation_track.zone)
	
	_progress = time
	_previous_time = time


## Adds a method animation, method animation will call a method for each step in the animation, with the interpolated Variant as the argument
func add_track(id: String, fixture: Fixture, parameter: String, function: String, zone: String, from: float, to: float, can_fade: bool = true, start: float = 0.0, stop: float = 1.0) -> void:
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
		"first_time": true,
		"animator": self
	}
	print(_tracks[id].parameter, ": ", _tracks[id].to)


## Removes an animated method, will reset all values to default if reset == true
func remove_track(id: String, reset: bool = true) -> void:
	if _tracks.has(id):
		if reset:
			var track: Dictionary = _tracks[id]
			track.fixture.set_parameter(track.parameter, track.function, track.from, _layer_id, track.zone)

		_tracks.erase(id)

		if not _tracks:
			stop()


## Tracks a cues fixtures
func track(p_cue: Cue, p_pre_existing_data: Dictionary[String, Dictionary]) -> Dictionary[String, Dictionary]:
	for item: ContainerItem in p_cue.get_items():
		var id: String = item.get_attribute_id()
		var from: float = item.get_fixture().get_current_value_layered_or_force_default(
			item.get_zone(), 
			item.get_parameter(), 
			_layer_id, 
			item.get_function()
		)
		
		add_track(
			id,
			item.get_fixture(), 
			item.get_parameter(), 
			item.get_function(), 
			item.get_zone(),
			from * (2 - (_intensity if item.get_parameter() in _allowed_intensity_parameters else 1.0)), 
			item.get_value(), 
			item.get_can_fade(), 
			item.get_start(),
			item.get_stop(),
		)

		if id in p_pre_existing_data:
			var animator: Variant = p_pre_existing_data[id].animator
			if is_instance_valid(animator) and animator != self:
				animator.remove_track(id, false)

	return _tracks


## Gets an animated track from the given id
func get_track_from_id(id: Variant) -> Dictionary:
	return _tracks.get(id, {}).duplicate()


## Returnes a copy of the animated data
func get_animated_data(duplicate_data: bool = true) -> Dictionary:
	return _tracks.duplicate(true) if duplicate_data else _tracks


## Sets the animated data
func set_animated_data(animation_data: Dictionary) -> void:
	_tracks = {}
	_tracks.merge(animation_data, true)


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
