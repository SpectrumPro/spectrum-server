# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name Animator extends Node
## A replacement for Godots Tween system


## Emitted each time this animation completes a step
signal steped(time: float)

## Emitted when this animation has stoped playing
signal finished


## Default length for this animation
var length: float = 1 : 
	set(value):
		length = value
		elapsed_time = clamp(elapsed_time, 0, length)


## The play state of this animation
var is_playing: bool = false : 
	set(state):
		is_playing = state
		set_process(state)
		# _stop_at = length if state else 0.0

		if not state:
			finished.emit()


## The time_scale of this animator, 1 will play back at normal speed. Do not set this to negtive, instead use play_backwards
var time_scale: float = 1

## Whether or not to play this animation backwards
var play_backwards: bool = false : 
	set(state):
		play_backwards = state
		_stop_at = 0.0 if state else length


## Elapsed time since this animation started
var elapsed_time: float = 0


## Contains all the infomation for this animation
var _animation_data: Dictionary = {}

var _stop_at: float = -1

func _ready() -> void:
	set_process(false)


## Plays this animation
func play(stop_at: float = -1) -> void:
	is_playing = true

	if not stop_at == -1:
		_stop_at = stop_at 


## Pauses this animation
func pause() -> void:
	is_playing = false


## Stops this scene, reset all values to default
func stop() -> void:
	is_playing = false
	seek_to_percentage(0)


## Deletes this Animator, resets all values and queue_free()'s
func delete() -> void:
	_animation_data.values().map(func (animation_track: Dictionary):
		(animation_track.method as Callable).call(animation_track.from)
	)
		
	queue_free()


## Process function, delta is used to calculate the interpolated values for the animation
func _process(delta: float) -> void:
	_seek_to(elapsed_time)

	print(elapsed_time)
	print(_stop_at)

	if play_backwards:
		elapsed_time -= delta * time_scale

		if elapsed_time <= _stop_at:
			if elapsed_time <= 0:
				seek_to_percentage(0)

			is_playing = false 
			
	else:
		elapsed_time += delta * time_scale


		if elapsed_time >= _stop_at:
			if elapsed_time >= length:
				seek_to_percentage(1)
			
			is_playing = false


## Seeks to percentage amount through the animator
func seek_to_percentage(percentage: float) -> void:
	elapsed_time = remap(percentage, 0, 1, 0, length)
	_seek_to(elapsed_time)


## Internal function to seek to a point in the animation
func _seek_to(time: float) -> void:
	_animation_data.values().map(func (animation_track: Dictionary):
		(animation_track.method as Callable).call(Tween.interpolate_value(animation_track.from, animation_track.to, time, length, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT))
	)
	steped.emit(time)


## Adds a method animation, method animation will call a method for each step in the animation, with the interpolated Variant as the argument
func animate_method(method: Callable, from: Variant, to: Variant) -> int:
	var id: int = len(_animation_data.keys()) + 1
	
	_animation_data[id] = {
		"method": method,
		"from": from,
		"to": to
	}
	
	return id


## Removes an animated method, will reset the value to default
func remove_animated_method(id: int) -> void:
	if _animation_data.has(id):
		(_animation_data[id].method as Callable).call(_animation_data[id].from)
		_animation_data.erase(id)


## Returnes a copy of the animated data
func get_animated_data() -> Dictionary:
	return _animation_data.duplicate(true)