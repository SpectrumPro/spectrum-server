# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name Animator extends Node
## A replacement for Godots Tween system

## Emitted each time this animation completes a step
signal steped(time: float)


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

## Whether or not to play this animation backwards
var play_backwards: bool = false


## Contains all the infomation for this animation
var _animation_data: Dictionary = {}

## Elapsed time since this animation started
var elapsed_time: float = 0


func _ready() -> void:
	set_process(false)


## Plays this animation
func play() -> void:
	is_playing = true


## Pauses this animation
func pause() -> void:
	is_playing = false


## Stops this scene, reset all values to default
func stop() -> void:
	is_playing = false
	seek_to(0)


## Deletes this Animator, resets all values and queue_free()'s
func delete() -> void:
	_animation_data.values().map(func (animation_track: Dictionary):
		(animation_track.method as Callable).call(animation_track.from)
	)
		
	queue_free()


## Process function, delta is used to calculate the interpolated values for this animation
func _process(delta: float) -> void:
	_seek_to(elapsed_time)
	elapsed_time += -delta if play_backwards else delta
	
	if length == 0:
		if play_backwards:
			_seek_to(0, 1)
		else:
			_seek_to(1, 1)
			elapsed_time = INF

	
	if play_backwards and elapsed_time <= 0 or not play_backwards and elapsed_time >= length:
		is_playing = false


## Seeks to a point in time in the animation
func seek_to(time: float, custem_length: float = length) -> void:
	elapsed_time = time
	_seek_to(elapsed_time, custem_length)
	print(elapsed_time)


## Internal function to seek to a point in the animation
func _seek_to(time: float, custem_length: float = length) -> void:
	_animation_data.values().map(func (animation_track: Dictionary):
		(animation_track.method as Callable).call(Tween.interpolate_value(animation_track.from, animation_track.to, time, custem_length, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT))
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