# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name CueList extends Function
## Stores a list of Scenes, that are enabled and disabled in order one after another

## Emitted when the current cue index is changed
signal on_cue_changed(index: float)

## Emitted when this CueList starts playing
signal on_played()

## Emitted when this CueList is paused
signal on_paused()

## Emitted when a cue is added to this CueList
signal on_cues_added(cues: Array)

## Emitted when a cue is removed from this CueList
signal on_cues_removed(cues: Array)

## The current active, and previous active cue
var current_cue: Cue = null
var last_cue: Cue = null

## Stores all fixtures that are currently being animated
## str(fixture.uuid + method_name):{
##      "current_value": Variant,
##      "animator": Animator
##    }
var _current_animated_fixtures: Dictionary = {}

## Stores all the current animators, stored at {cue_number: Animator}
var _current_animators: Dictionary = {}

## Stores all the cues, these are stored unordered
var _cues: Dictionary = {}

## Stores an ordered list of all the cue indexes
var _index_list: Array = []

## The current index in the _index_list array
var _index: int = -1

func _component_ready() -> void:
	name = "CueList"
	self_class_name = "CueList"

## Adds a pre-existing cue to this CueList
## Returns false if the cue already exists in this list, or if the index is already in use
func add_cue(cue: Cue, number: float = 0) -> bool:
	if number == 0:
		number = cue.number
	
	if number <= 0:
		number = (_index_list[-1] + 1) if _index_list else 1
	
	if cue in _cues.values() or number in _index_list:
		return false

	cue.number = number
	_cues[number] = cue
	_index_list.append(number)
	_index_list.sort()

	return true

## Advances to the next cue in the list
func go_next() -> void:
	seek_to(_index_list[wrapi(_index + 1, 0, len(_cues))])

## Returns to the previous cue in the list
func go_previous() -> void:
	seek_to(_index_list[wrapi(_index - 1, 0, len(_cues)) if _index != -1 else -1])

## Skips to the cue index
func seek_to(cue_number: float) -> void:
	if not cue_number in _index_list and cue_number != -1:
		return
	
	var reset: bool = cue_number == -1
	var fade_time: float = 1
	if reset:
		fade_time = current_cue.fade_time if current_cue else 0.0
		current_cue = null
	else:
		current_cue = _cues[cue_number]
		fade_time = current_cue.fade_time

	_index = _index_list.find(cue_number)
	var current_cue_index: int = _index_list.find(current_cue.number) if current_cue else -1
	var animator = Core.create_animator()
	animator.kill_on_finish = true

	var accumulated_animated_data: Dictionary = {}
	var going_backwards: bool = (last_cue and (_index_list.find(last_cue.number) > current_cue_index)) if not reset else true

	if going_backwards:
		_reset_animated_fixtures(animator, accumulated_animated_data)
		_remove_all_animators()

	var cue_range: Array = range(0, current_cue_index + 1)
	if not going_backwards:
		var last_cue_index: int = _index_list.find(last_cue.number) if last_cue else -1
		cue_range = [current_cue_index] if (last_cue_index + 1) == current_cue_index else range(last_cue_index + 1, current_cue_index + 1)

	if not reset:
		for index in cue_range:
			var cue: Cue = _cues[_index_list[index]]
			_accumulate_state(cue, accumulated_animated_data, animator)

	animator.set_animated_data(accumulated_animated_data)
	_handle_animator_finished(animator, cue_number, fade_time)

	last_cue = current_cue
	on_cue_changed.emit(_index_list[_index] if not reset else -1.0)


func _reset_animated_fixtures(animator: Animator, accumulated_animated_data: Dictionary) -> void:
	for animation_id in _current_animated_fixtures.keys():
		var animating_fixture = _current_animated_fixtures[animation_id]
		var from_value: Variant = animating_fixture.fixture.get_value_from_layer_id(uuid, animating_fixture.method_name)
		var to_value: Variant = animating_fixture.fixture.get_zero_from_value_name(animating_fixture.method_name)

		if is_instance_valid(animating_fixture.animator):
			animating_fixture.animator.remove_track_from_id(animation_id, false)

		accumulated_animated_data[animation_id] = {
			"method": animating_fixture.fixture.get(animating_fixture.method_name).bind(uuid),
			"from": from_value,
			"to": to_value,
			"current": from_value
		}

		_current_animated_fixtures[animation_id] = {
			"method_name": animating_fixture.method_name,
			"fixture": animating_fixture.fixture,
			"animator": animator
		}

func _remove_all_animators() -> void:
	for old_cue_number: float in _current_animators:
		_remove_animator(old_cue_number)

func _accumulate_state(cue: Cue, accumulated_animated_data: Dictionary, animator: Animator) -> void:
	for fixture: Fixture in cue.stored_data.keys():
		for method_name: String in cue.stored_data[fixture]:
			var stored_value: Dictionary = cue.stored_data[fixture][method_name]
			var from_value: Variant = fixture.get_value_from_layer_id(uuid, method_name)
			var to_value: Variant = stored_value.value

			var animation_id: String = fixture.uuid + method_name
			if animation_id in accumulated_animated_data:
				accumulated_animated_data[animation_id]["to"] = to_value
			else:
				accumulated_animated_data[animation_id] = {
					"method": fixture.get(method_name).bind(uuid),
					"from": from_value,
					"to": to_value,
					"current": from_value
				}

			if animation_id in _current_animated_fixtures:
				var _animator = _current_animated_fixtures[animation_id].animator
				if is_instance_valid(_animator) and _animator != animator:
					_current_animated_fixtures[animation_id].animator.remove_track_from_id(animation_id, false)

			_current_animated_fixtures[animation_id] = {
				"method_name": method_name,
				"fixture": fixture,
				"animator": animator
			}

func _handle_animator_finished(animator: Animator, cue_number: float, fade_time: float) -> void:
	animator.finished.connect((func (current_cue_number: float):
		_current_animators[current_cue_number].pause()
		_current_animators[current_cue_number].queue_free()
		_current_animators.erase(current_cue_number)
	).bind(cue_number), CONNECT_ONE_SHOT)

	var subtract_time: float = 0
	if cue_number in _current_animators:
		subtract_time = remap(_current_animators[cue_number].elapsed_time, 0, 1, 0, fade_time)
		_current_animators[cue_number].pause()
		_current_animators[cue_number].queue_free()
		_current_animators.erase(cue_number)

	animator.time_scale = 1 / (fade_time)
	_current_animators[cue_number] = animator
	animator.play()

func _remove_animator(cue_number: float, erase: bool = true) -> void:
	_current_animators[cue_number].pause()
	_current_animators[cue_number].queue_free()
	if erase:
		_current_animators.erase(cue_number)

## Stops this cue list, fades all fixtures down to 0, using the fade time provided, otherwise will use the fade time of the current cue
func stop() -> void:
	seek_to(-1)

## Saves this cue list to a Dictionary
func _on_serialize_request(mode: int) -> Dictionary:
	var serialized_cues: Dictionary = {}
	for cue_index: float in _index_list:
		serialized_cues[cue_index] = _cues[cue_index].serialize()
	return {"cues": serialized_cues}

## Loads this cue list from a Dictionary
func _on_load_request(serialized_data: Dictionary) -> void:
	for cue_index: String in serialized_data.get("cues").keys():
		var new_cue: Cue = Cue.new()
		new_cue.load(serialized_data.cues[cue_index])
		add_cue(new_cue, float(cue_index))
