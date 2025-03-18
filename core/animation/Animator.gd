# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name Animator extends Node
## A replacement for Godots Tween system. designed for animating fixtures


## Emitted each time this animation completes a step
signal steped(time: float)

## Emitted when this animation has stoped playing
signal finished


## Default length for this animation
var length: float = 1:
	set(value):
		length = value
		_stop_at = 0.0 if play_backwards else length
		elapsed_time = clamp(elapsed_time, 0, length)


## The play state of this animation
var is_playing: bool = false:
	set(state):
		is_playing = state
		set_process(state)
		# _stop_at = length if state else 0.0


## The time_scale of this animator, 1 will play back at normal speed. Do not set this to negtive, instead use play_backwards
var time_scale: float = 1

## Whether or not to play this animation backwards
var play_backwards: bool = false:
	set(state):
		play_backwards = state
		_stop_at = 0.0 if state else length


## If true, this animator will queue_free() once finished, and will not reset any tracks to 0
var kill_on_finish: bool = false

## Elapsed time since this animation started
var elapsed_time: float = 0

## Layer Id for animating fixtures
var layer_id: String = ""

## Contains all the infomation for this animation
var _animation_data: Dictionary = {}

## Time to stop the animation at
var _stop_at: float = length


func _ready() -> void:
	set_process(false)


## Process function, delta is used to calculate the interpolated values for the animation
func _process(delta: float) -> void:
	_seek_to(elapsed_time)
	
	if play_backwards:
		elapsed_time -= delta * time_scale

		if elapsed_time <= _stop_at:
			if elapsed_time <= 0:
				finish()

			is_playing = false
			
	else:
		elapsed_time += delta * time_scale


		if elapsed_time >= _stop_at:
			finish()


## Plays this animation
func play(stop_at: float = -1) -> void:
	is_playing = true

	if not stop_at == -1:
		_stop_at = stop_at
	else:
		_stop_at = length


## Pauses this animation
func pause() -> void:
	is_playing = false


## Stops this scene, reset all values to default
func stop() -> void:
	is_playing = false
	seek_to_percentage(0)


## Deletes this Animator, resets all values and queue_free()'s
func delete() -> void:
	for animation_track: Dictionary in _animation_data.values():

		(animation_track.fixture as Fixture).erase_parameter(
			animation_track.parameter,
			layer_id,
			animation_track.zone
		)
		
	queue_free()


## Will immediately finish this animation
func finish():
	seek_to_percentage(0 if play_backwards else 1)

	finished.emit()

	if kill_on_finish:
		queue_free()


## Seeks to percentage amount through the animator
func seek_to_percentage(percentage: float) -> void:
	elapsed_time = remap(percentage, 0, 1, 0, length)
	_seek_to(elapsed_time)


## Internal function to seek to a point in the animation
func _seek_to(time: float) -> void:
	for animation_track in _animation_data.values():
		var new_data: float = - 1

		if animation_track.can_fade:
			if time < animation_track.start or time > animation_track.stop:
				continue

			var normalized_progress = (time - animation_track.start) / max(animation_track.stop - animation_track.start, 0.0001)
			new_data = Tween.interpolate_value(
				animation_track.from,
				animation_track.to - animation_track.from,
				normalized_progress,
				length,
				Tween.TRANS_LINEAR,
				Tween.EASE_IN_OUT
			)
		
		elif play_backwards and time <= animation_track.stop:
			new_data = animation_track.from
		
		elif not play_backwards and time >= animation_track.start:
			new_data = animation_track.to

		if new_data != - 1 and animation_track.current != new_data:
			animation_track.current = new_data
			var fixture: Fixture = animation_track.fixture
			fixture.set_parameter(animation_track.parameter, animation_track.function, new_data, layer_id, animation_track.zone)

	steped.emit(time)



## Adds a method animation, method animation will call a method for each step in the animation, with the interpolated Variant as the argument
func animate_parameter(fixture: Fixture, parameter: String, function: String, zone: String, from: float, to: float, can_fade: bool = true, start: float = 0.0, stop: float = 1.0, id: Variant = len(_animation_data.keys()) + 1) -> Variant:
	_animation_data[id] = {
		"fixture": fixture,
		"parameter": parameter,
		"function": function,
		"zone": zone,
		"from": from,
		"to": to,
		"current": from,
		"can_fade": can_fade,
		"start": start,
		"stop": stop
	}

	return id


## Removes an animated method, will reset all values to default if reset == true
func remove_track_from_id(id: Variant, reset: bool = true) -> void:
	if _animation_data.has(id):
		_animation_data.erase(id)


## Gets an animated track from the given id
func get_track_from_id(id: Variant) -> Dictionary:
	return _animation_data.get(id, {}).duplicate()


## Deletes all the animated data
func remove_all_data() -> void:
	_animation_data = {}
	elapsed_time = 0


## Returnes a copy of the animated data
func get_animated_data(duplicate_data: bool = true) -> Dictionary:
	return _animation_data.duplicate(true) if duplicate_data else _animation_data


## Sets the animated data
func set_animated_data(animation_data: Dictionary) -> void:
	_animation_data = animation_data.duplicate()
