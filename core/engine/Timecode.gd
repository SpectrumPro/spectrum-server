# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name Timecode extends Node
## Class for distributing timecode


## Emitted when the current frame count changes
signal frames_changed(frame_count: int)

## Emitted when the current hour count changes
signal hours_changed(hours: int)

## The total number or frames
var frame_count: int = 0 : set = set_frame_count


## Hours, Minutes, and Second counters
var h: int = 0
var m: int = 0
var s: int = 0
var f: int = 0


## The timecode as a string, formatted as: Hours:Minutes:Seconds:Frames
var tc_as_string: String :
    get():
        return str("%02d" % h) + ":" + str("%02d" % m) + ":" + str("%02d" % s) + ":" + str("%02d" % f)


## The fps of the incoming timecode
var fps: float = 25


## Sets the total frame count
func set_frame_count(p_frame_count: int) -> void:
    if frame_count == p_frame_count:
        return
    
    frame_count = p_frame_count

    var total_seconds: int = frame_count / fps
    var hours: int = total_seconds / 3600

    var emit_hours_signal: bool = false
    emit_hours_signal = hours != h

    h = hours
    m = int((total_seconds % 3600) / 60)
    s = int(total_seconds % 60)
    f = frame_count % int(fps)  # Frames are the remainder of frame_count divided by fps

    print(frame_count)
    frames_changed.emit(frame_count)
    if emit_hours_signal: hours_changed.emit(h)
