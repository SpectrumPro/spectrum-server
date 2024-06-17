# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name Function extends EngineComponent
## Base class for all functions, scenes, cuelists ect


## Emitted when the fade speed has changed
signal on_fade_time_changed(fade_in_speed: float, fade_out_speed: float)


## Fade in time in seconds, defaults to 2 seconds
var fade_in_speed: float = 2 : set = set_fade_in_speed


## Fade out time in seconds, defaults to 2 seconds
var fade_out_speed: float = 2 : set = set_fade_out_speed



## Sets the fade in speed in seconds
func set_fade_in_speed(speed: float) -> void:
    fade_in_speed = speed
    on_fade_time_changed.emit(fade_in_speed, fade_out_speed)


## Sets the fade out speed in seconds
func set_fade_out_speed(speed: float) -> void:
    fade_out_speed = speed
    on_fade_time_changed.emit(fade_in_speed, fade_out_speed)