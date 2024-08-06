# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name Interval extends Object
## Implementation of JavaScripts setInterval() function in godot


## Emitted each time this Interval times out
signal timed_out

## Emitted when this timer has hit the max_iterations limit
signal finished


## Interval time in seconds
var interval: float = 1 : set = set_interval

## The method to call when this Inerval times out
var method: Callable = Callable() : set = set_method

## Args to pass to the method when it is called
var args: Array = []

## Max number of times this Interval can run, set to 0 to disable
var max_iterations: int = 0 : set = set_max_iterations

## If this Interval sould kill() once it has hit the iteration limit
var kill_on_finish: bool = true


## Internal counter for number of iterations
var _iterations: int = 0

## The Timer node used in this Interval
var _timer: Timer = null


func _init(p_method: Callable = Callable(), p_interval: float = 1, p_max_iterations: int = 0, p_args: Array = []) -> void:
	_timer = Timer.new()
	_timer.one_shot = false

	method = p_method
	interval = p_interval
	max_iterations = p_max_iterations
	args = p_args

	Core.add_child(_timer)
	_timer.start()


## Plays the timer
func play() -> void:
	_timer.paused = false


## Pauses the timer
func pause() -> void:
	_timer.paused = true


## Kills this interval
func kill() -> void:
	pause()
	if _timer.get_parent() == Core:
		Core.remove_child(_timer)

	call_deferred("free")


## Sets the interval in seconds
func set_interval(p_interval: float) -> void:
	interval = absf(p_interval)
	_timer.wait_time = interval


## Sets the method to be called when this Interval times out
func set_method(p_method: Callable) -> void:
	if not method.is_null() and _timer.timeout.is_connected(_timer_callback):
		_timer.timeout.disconnect(method)

	method = p_method

	if not method.is_null():
		_timer.timeout.connect(_timer_callback)


## Sets the max number of iterations for this Interval
func set_max_iterations(p_max_iterations: int) -> void:
	max_iterations = absi(p_max_iterations)
	_iterations = 0


## Callback for _timer.timeout
func _timer_callback() -> void:
	if max_iterations and _iterations >= max_iterations:
		finished.emit()
		if kill_on_finish:
			kill()
	
	else:
		_iterations = _iterations + 1
		timed_out.emit()
		method.callv(args)