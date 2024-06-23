# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name CueList extends Function
## Stores a list of Scenes, that are enabled and disabled in order one after another


## Emitted when the current cue index is changed
signal on_cue_changed(index: int)

## Emitted when this CueList starts playing
signal on_played(index: int)

## Emitted when this CueList is paused
signal on_paused(index: int)

## Emitted when a cue is moved in this list
signal on_cue_moved(scene: Scene, to: int)

## Emitted when a cue is added to this CueList
signal on_cues_added(cues: Array)

## Emitted when a cue is removed form this CueList
signal on_cues_removed(cues: Array)

## Emitted when a cue's fade in time, out, or hold time is changed
signal cue_timings_changed(index: int, fade_in_time: float, fade_out_time: float, hold_time: float)


## Stores all the Scenes that make up this cue list, stored as: {"index": {"scenes": [Scene, ...], "hold_time": float}}
var cues: Dictionary = {}

## The index of the current cue, do not change this at runtime, instead use seek_to()
var index: int = 0

## Used to store the on_delete_requested signal connection for each scene in this CueList, stored here to they can be dissconnected to remove refernces once a scene is deleted
var _scene_signal_connections: Dictionary = {}

## Stores the scenes that are currently fading in or out, this is used when pausing and playing the CueList
var _active_scenes: Array = []
var _is_playing: bool = false


## Called when this EngineComponent is ready
func _component_ready() -> void:
	name = "CueList"
	self_class_name = "CueList"


## Plays this CueList, starting at index, or from the current index if one is not provided
func play(start_index: int = -1) -> void:
	if not _is_playing and len(cues):
		_is_playing = true

		index = start_index if not start_index == -1 else index

		for scene: Scene in _active_scenes:
			scene.play()
		
		while _is_playing:
			go_next()
			await Core.get_tree().create_timer(cues[index].hold_time).timeout


## Pauses the CueList at the current state
func pause() -> void:
	_is_playing = false
	
	for scene: Scene in _active_scenes:
		scene.pause()


## Stopes the CueList, will fade out all running scnes, using fade_out_speed, otherwise will use the fade_out_speed of the current index
func stop(fade_out_speed: float = -1) -> void:
	_active_scenes = _active_scenes.filter(func (scene: Scene):
		scene.set_enabled(false, fade_out_speed if not fade_out_speed == -1 else cues[index].fade_out_speed)
		return false
	)
	_is_playing = false


## Advances to the next cue in the list, can be used with out needing to run play(), will use fade speeds of the cue if none are provided
func go_next(fade_in_speed: float = -1, fade_out_speed: float = -1) -> void:
	seek_to(wrapi(index + 1, 1, len(cues) + 1), fade_in_speed, fade_out_speed)


## Retuens to the previous cue in the list, can be used with out needing to run play(), will use fade speeds of the cue if none are provided
func go_previous(fade_in_speed: float = -1, fade_out_speed: float = -1) -> void:
	seek_to(wrapi(index - 1, 1, len(cues) + 1), fade_in_speed, fade_out_speed)


## Skips to the cue provided in index, can be used with out needing to run play(), will use fade speeds of the cue if none are provided
func seek_to(p_index: int, fade_in_speed: float = -1, fade_out_speed: float = -1) -> void:
	index = p_index

	_active_scenes = _active_scenes.filter(func (scene: Scene):
		scene.set_enabled(false, fade_out_speed if not fade_out_speed == -1 else cues[index].fade_out_speed)
		return false
	)

	cues[index].scene.set_enabled(true, fade_in_speed if not fade_in_speed == -1 else cues[index].fade_in_speed)
	_active_scenes.append(cues[index].scene)

	on_cue_changed.emit(index)
		


## Adds a cue to this CueList, will override cues if they already exist. If no index is provided the cue will be appened at the end of the list. Will use the fade times of the scene if none are givven
## Returns true if the cue was added, otherwise false
func add_cue(scene: Scene, at_index: int = -1 , fade_in_speed: float = -1, fade_out_speed: float = -1, hold_time: float = 1.0, no_signal: bool = false) -> bool:
	if at_index == -1:
		at_index = len(cues.keys()) + 1

	print(at_index)
	print(range(1, len(cues.keys()) + 2))
	if at_index < 0 or at_index not in range(1, len(cues.keys()) + 2):  
		print("Returning False")
		return false

	else:
		cues[at_index] = {
			"scene": scene,
			"hold_time": hold_time,
			"fade_in_speed": fade_in_speed,
			"fade_out_speed": fade_out_speed
		}

		return true


func _connect_scene_signals(scene: Scene) -> void:
	pass


func _disconnect_scene_signals(scene: Scene) -> void:
	pass


## Moves the cue at index, to to_index
func move_cue(scene: Scene, to_index: int) -> void:
	pass


## Removes a cue at index
func remove_cue(scene: Scene) -> void:
	pass


## Sets the fade in time for the cue at index
func set_fade_in_time(scene: Scene, fade_in_time: float) -> void:
	pass


## Sets the fade out time for the cue at index
func set_fade_out_time(scene: Scene, fade_out_time: float) -> void:
	pass


## Sets the hold time for the cue at index
func set_hold_time(at_index: int, hold_time: float) -> void:
	if cues.has(at_index):
		cues[at_index].hold_time = hold_time


func _on_serialize_request(mode: int) -> Dictionary:
	var serialized_cues: Dictionary = {}

	for index in cues:
		serialized_cues[index] = {
			"hold_time": cues[index].hold_time,
			"fade_in_speed": cues[index].fade_in_speed,
			"fade_out_speed": cues[index].fade_out_speed,
			"scene": cues[index].scene.uuid
		}

	return {
		"cues": serialized_cues,
	}


func _on_load_request(serialized_data: Dictionary) -> void:

	var just_added_cues: Array = []

	# Loop through all the cues in the serialized data
	for index in serialized_data.get("cues", {}):
		var serialized_cue: Dictionary = serialized_data.cues[index]

		var hold_time: float = serialized_cue.get("hold_time", 1.0)
		var scene_uuid: String = serialized_cue.get("scene", "")

		if scene_uuid in Core.functions.keys() and Core.functions[scene_uuid] is Scene:

			var fade_in_speed: float = serialized_cue.get("fade_in_speed", 1)
			var fade_out_speed: float = serialized_cue.get("fade_out_speed", 1)
			
			add_cue(Core.functions[scene_uuid], int(index), fade_in_speed, fade_out_speed, hold_time,  true)
		
		set_hold_time(int(index), hold_time)


	if just_added_cues:
		on_cues_added.emit(just_added_cues)


func _on_delete_request() -> void:
	stop(0)
