# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name CueList extends Function
## Stores a list of Scenes, that are enabled and disabled in order one after another


## Emitted when the current cue _index is changed
signal on_index_changed(index: float)

## Emitted when this CueList starts playing
signal on_played()

## Emitted when this CueList is paused
signal on_paused()

## Emitted when this CueList is stopped
signal on_stopped()

## Emitted when a cue is added to this CueList
signal on_cues_added(cues: Array)

## Emitted when a cue is removed form this CueList
signal on_cues_removed(cues: Array)


## The current active, and previous active cue
var current_cue: Cue = null
var last_cue: Cue = null


## The most recent animator
var _animator: Animator = null

## Stores all fixtures that are currently be animatred
## str(fixture.uuid + method_name):{
##			"current_value": Variant,
##			"animator": Animator
##	  }
var _current_animated_fixtures: Dictionary = {}

## Stores all the current animators, stoed at {cue_number: Animator}
var _current_animators: Dictionary = {}

## Stores all the cues, theese are stored unordored
var _cues: Dictionary = {}

## Stores an ordored list of all the cue indexes
var _index_list: Array = []

## The current _index in the _index_list array
var _index: int = -1


func _component_ready() -> void:
	name = "CueList"
	self_class_name = "CueList"



## Adds a pre existing cue to this CueList
## Returnes false if the cue already exists in this list, or if the _index is already in use
func add_cue(cue: Cue, number: float = 0) -> bool:

	number = cue.number if number == 0 else number

	if number <= 0:
		number = (_index_list[-1] + 1) if _index_list else 1

	if cue in _cues.values() or number in _index_list:
		return false

	cue.number = number

	_cues[number] = cue
	_index_list.append(number)
	_index_list.sort()

	return true


## Advances to the next cue in the listd
func go_next() -> void:
	seek_to(_index_list[wrapi(_index + 1, 0, len(_cues))])


## Retuens to the previous cue in the list
func go_previous() -> void:
	seek_to(_index_list[wrapi(_index - 1, 0, len(_cues))])


## Skips to the cue index
func seek_to(cue_number: float) -> void:

	if not cue_number in _index_list:
		return

	_index = _index_list.find(cue_number)
	last_cue = current_cue
	current_cue = _cues[cue_number]

	var old_animated_data: Dictionary = _animator.get_animated_data() if is_instance_valid(_animator) else {}

	_animator = Core.create_animator()
	_animator.kill_on_finish = true

	var last_cue_index: int = _index_list.find(last_cue.number) if last_cue else 0
	var current_cue_index: int = _index_list.find(current_cue.number)

	var cue_range: Array = []
	var going_backwards: bool = false

	if last_cue_index + 1 == current_cue_index:
		cue_range = [current_cue_index]
	
	else:
		if last_cue_index > current_cue_index:
			cue_range = range(last_cue_index, current_cue_index, -1 )
			going_backwards = true

		else:
			cue_range = range(last_cue_index, current_cue_index + 1)
	
	var new_animated_data: Dictionary = {}

	for index: int in cue_range:
		var cue: Cue = _cues[_index_list[index]]
		
		for fixture: Fixture in cue.stored_data.keys():
			for method_name: String in cue.stored_data[fixture]:
				
				var stored_value: Dictionary = cue.stored_data[fixture][method_name]
				var from_value: Variant = stored_value.default
				
				var animation_id: String = fixture.uuid + method_name


				if animation_id in _current_animated_fixtures:
					var current_animating_fixture: Dictionary = _current_animated_fixtures[animation_id]

					if is_instance_valid(current_animating_fixture.animator):
						from_value = current_animating_fixture.animator.get_track_from_id(animation_id).current
						current_animating_fixture.animator.remove_track_from_id(animation_id, false)
					else:
						from_value = current_animating_fixture.current_value

				if going_backwards:
					new_animated_data[animation_id] = {
						"method": fixture.get(method_name).bind(uuid),
						"from": from_value,
						"to": stored_value.default,
						"current": from_value
					}
				else:
					new_animated_data[animation_id] = {
						"method": fixture.get(method_name).bind(uuid),
						"from": from_value,
						"to": stored_value.value,
						"current": from_value
					}
				
				_current_animated_fixtures[animation_id] = {
					"current_value": from_value,
					"animator": _animator
				}
	
	_animator.set_animated_data(new_animated_data)

	_animator.finished.connect(_remove_animator.bind(_animator, cue_number), CONNECT_ONE_SHOT)

	for animator: Animator in _current_animators.values():
		animator.time_scale = 1 / current_cue.fade_time

	var subtract_time: float = 0

	if cue_number in _current_animators:
		subtract_time = remap(_current_animators[cue_number].elapsed_time, 0, 1, 0, current_cue.fade_time)
		
		_remove_animator(_current_animators[cue_number], cue_number)
		# _current_animators[cue_number].queue_free()

	_animator.time_scale = 1 / (current_cue.fade_time) 

	_current_animators[cue_number] = _animator
	_animator.play()

	print(_current_animated_fixtures)
	on_index_changed.emit(_index_list[_index])



func _remove_animator(animator: Animator, cue_number: float) -> void:
	var animated_data: Dictionary = animator.get_animated_data()

	for uuid_and_method: String in animated_data.keys():
		if is_instance_valid(_current_animated_fixtures[uuid_and_method].animator) and _current_animated_fixtures[uuid_and_method].animator == animator:
			_current_animated_fixtures[uuid_and_method].current_value = animated_data[uuid_and_method].current

			# Normally, you would set this to null. However, due to the fact that the animator may have already been freed from memory,
			# Godot will auto-set it to null. But it's not a normal null Variant; it's one that will return true if you check it with an if statement.
			# This is because this special null Variant remembers that it was once a valid node and will use that information to provide an error message 
			# to the user, saying that they tried to get a member of a previously freed node.
			#
			# This should work fine. However, when you assign a value to a Variant, Godot will check to see if the new value and the old value are the same.
			# When Godot compares this special null Variant with a normal null Variant, it will return true, thus Godot won't change the value of the Variant.
			# This means that the special null Variant is still there and will return true if you check with an if statement,
			# which can cause issues later on, as your code believes that it's a valid object.
			#
			# To fix this, I am setting it to an empty Object, which passes all of the engine checks and won't cause any issues when setting the variant,
			# and still allows me to compare it to other objects without any type errors.
			#_current_animated_fixtures[uuid_and_method].animator = ""
	
	_current_animators[cue_number].queue_free()
	_current_animators.erase(cue_number)


## Saves this cue list to a Dictionary
func _on_serialize_request(mode: int) -> Dictionary:
	var serialized_cues: Dictionary = {}

	for cue_index: float in _index_list:
		serialized_cues[cue_index] = _cues[cue_index].serialize()

	return {

		"cues": serialized_cues
	}


func _on_load_request(serialized_data: Dictionary) -> void:
	for cue_index: String in serialized_data.get("cues").keys():
		var new_cue: Cue = Cue.new()
		new_cue.load(serialized_data.cues[cue_index])

		add_cue(new_cue, float(cue_index))

