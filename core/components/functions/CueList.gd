# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name CueList extends Function
## Stores a list of Cues, that can be moved to at any point.

## Emitted when the current cue number is changed
signal on_cue_changed(cue_number: float)

## Emitted when this CueList starts playing
signal on_played()

## Emitted when this CueList is paused
signal on_paused()

## Emitted when this CueList is stopped
signal on_stopped

## Emitted when a cue is added to this CueList
signal on_cues_added(cues: Array)

## Emitted when a cue is removed from this CueList
signal on_cues_removed(cues: Array)

## Emitted when cue numbers are changed, stored as {Cue:new_number, ...}
signal on_cue_numbers_changed(new_numbers: Dictionary)

## Emitted when the mode is changed
signal on_mode_changed(mode: MODE)


## The current active, and previous active cue
var current_cue: Cue = null
var last_cue: Cue = null
var next_cue: Cue = null


## Allowed parameters to changed when setting function intencity
const _allowed_intensity_parameters: Array[String] = ["Dimmer"]

## The current mode of this cuelist. When in loop mode the cuelist will not reset fixtures to 0-value when looping back to the start
enum MODE {NORMAL, LOOP}
var _mode: int = MODE.NORMAL

## Stores all fixtures that are currently being animated
## str(fixture.uuid + zone + parameter):{
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


## Contains all the keyframes for timecode, stored as {frame: [cue_number, cue_number...]}
var _keyframes: Dictionary = {}

## Contains a sorted version of the keyframes
var _sorted_keyframes: Array = []

## The last leyframe that was triggred
var last_triggered_keyframe: int = -1


## Used to determin if a force reload from the start should happen, used when a cue is added, removed, moved, or edited
var force_reload: bool = false

## Autoplay state
var _autoplay: bool = false


func _component_ready() -> void:
	set_name("CueList")
	set_self_class("CueList")

	_intensity = 1
	TC.frames_changed.connect(_find_keyframes)


## Adds a pre-existing cue to this CueList
## Returns false if the cue already exists in this list, or if the index is already in use
func add_cue(cue: Cue, number: float = 0, rename: bool = false) -> bool:
	if number == 0:
		number = cue.number

	if number <= 0:
		number = round(_index_list[-1] + 1) if _index_list else 1

	if cue in _cues.values() or number in _index_list:
		return false

	if rename:
		cue.name = "Un-named Cue: " + str(number)

	cue.number = number
	cue.cue_list = self
	_cues[number] = cue
	_index_list.append(number)
	_index_list.sort()

	cue.on_delete_requested.connect(remove_cue.bind(cue), CONNECT_ONE_SHOT)

	cue.local_data[uuid+"on_timecode_trigger_changed"] = _on_cue_timecode_trigger_changed.bind(cue)
	cue.local_data[uuid+"on_timecode_enabled_state_changed"] = _on_cue_timecode_enabled_stage_changed.bind(cue)

	if cue.timecode_enabled:
		_add_cue_keyframe(cue)

	cue.on_timecode_trigger_changed.connect(cue.local_data[uuid+"on_timecode_trigger_changed"])
	cue.on_timecode_enabled_state_changed.connect(cue.local_data[uuid+"on_timecode_enabled_state_changed"])

	Server.add_networked_object(cue.uuid, cue, cue.on_delete_requested)

	force_reload = true

	on_cues_added.emit([cue])

	return true


## Removes a cue from this CueList
func remove_cue(cue: Cue) -> void:
	if cue.number in _cues:
		_index_list.erase(cue.number)
		_cues.erase(cue.number)

		_index = _index - 1
		force_reload = true

		cue.on_timecode_trigger_changed.disconnect(cue.local_data[uuid+"on_timecode_trigger_changed"])
		cue.on_timecode_enabled_state_changed.disconnect(cue.local_data[uuid+"on_timecode_enabled_state_changed"])
		cue.local_data.erase(uuid+"on_timecode_trigger_changed")
		cue.local_data.erase(uuid+"on_timecode_enabled_state_changed")
		cue.local_data.erase(uuid+"old_timecode_trigger")

		Server.remove_networked_object(cue.uuid)
		cue.delete()
		on_cues_removed.emit([cue])


func _on_cue_timecode_trigger_changed(timecode_trigger: int, cue: Cue) -> void:
	if cue.timecode_enabled:
		var old_trigger: int = cue.local_data.get(uuid+"old_timecode_trigger", -1)

		if old_trigger != -1 and old_trigger in _keyframes.keys():
			_keyframes[old_trigger].erase(cue.number)

			if not _keyframes[old_trigger]:
				_keyframes.erase(old_trigger)

		_add_cue_keyframe(cue)


func _add_cue_keyframe(cue: Cue) -> void:
	if not cue.timecode_trigger in _keyframes.keys():
		_keyframes[cue.timecode_trigger] = []

	_keyframes[cue.timecode_trigger].append(cue.number)

	_sorted_keyframes = _keyframes.keys()
	_sorted_keyframes.sort()

	cue.local_data[uuid+"old_timecode_trigger"] = cue.timecode_trigger


func _on_cue_timecode_enabled_stage_changed(timecode_enabled: bool, cue: Cue) -> void:
	if timecode_enabled:
		_add_cue_keyframe(cue)

	else:
		if cue.timecode_trigger in _keyframes.keys():
			_keyframes[cue.timecode_trigger].erase(cue.number)

		if not _keyframes[cue.timecode_trigger]:
			_keyframes.erase(cue.timecode_trigger)

		_sorted_keyframes = _keyframes.keys()
		_sorted_keyframes.sort()

	print(_keyframes)


func _find_keyframes(frame: int) -> void:
	# Use binary search to find the closest frame <= frame

	var left = 0
	var right = len(_sorted_keyframes) - 1

	# Binary search for closest keyframe <= frame
	while left <= right:
		var mid = int((left + right) / 2)
		if _sorted_keyframes[mid] == frame and _sorted_keyframes[mid] != last_triggered_keyframe :
			last_triggered_keyframe = _sorted_keyframes[mid]
			_trigger_keyframe(_sorted_keyframes[mid])
			return
		elif _sorted_keyframes[mid] < frame:
			left = mid + 1
		else:
			right = mid - 1

	# If we didn't find an exact match, trigger the closest valid keyframe
	if right >= 0:
		if _sorted_keyframes[right] <= frame and _sorted_keyframes[right] != last_triggered_keyframe:
			last_triggered_keyframe = _sorted_keyframes[right]
			_trigger_keyframe(_sorted_keyframes[right])
		return


func _trigger_keyframe(keyframe: int) -> void:
	for cue_number: float in _keyframes[keyframe]:
		seek_to(cue_number)


## Advances to the next cue in the list
func go_next() -> void:
	if _cues:
		seek_to(_index_list[wrapi(_index + 1, 0, len(_cues))])
	else: stop()


## Returns to the previous cue in the list
func go_previous() -> void:
	if _cues:
		seek_to(_index_list[wrapi(_index - 1, 0, len(_cues)) if _index != -1 else -1])
	else: stop()


## Skips to the cue index
func seek_to(cue_number: float, p_fade_time: float = -1) -> void:
	if not cue_number in _index_list and cue_number != -1 or _index == _index_list.find(cue_number):
		return

	var reset: bool = cue_number == -1
	var fade_time: float = 1

	_index = _index_list.find(cue_number)

	if reset:
		fade_time = current_cue.fade_time if current_cue else 0.0
		current_cue = null
		next_cue = _cues[_index_list[0]]
	else:
		current_cue = _cues[cue_number]
		fade_time = current_cue.fade_time
		next_cue = _cues[_index_list[(_index + 1) % len(_index_list)]]

	if p_fade_time != -1 : fade_time = p_fade_time

	var current_cue_index: int = _index_list.find(current_cue.number) if current_cue else -1

	var animator = Core.create_animator()
	animator.kill_on_finish = true

	var accumulated_animated_data: Dictionary = {}
	var going_backwards: bool = (last_cue and (_index_list.find(last_cue.number) > current_cue_index)) if not reset else true

	if (going_backwards and _mode != MODE.LOOP) or force_reload or reset:
		_reset_animated_fixtures(animator, accumulated_animated_data)
		_remove_all_animators()

	var cue_range: Array = range(0, current_cue_index + 1)
	if not going_backwards and not force_reload:
		var last_cue_index: int = _index_list.find(last_cue.number) if last_cue else -1
		cue_range = [current_cue_index] if (last_cue_index + 1) == current_cue_index else range(last_cue_index + 1, current_cue_index + 1)

	if not reset:
		for index in cue_range:
			var cue: Cue = _cues[_index_list[index]]
			_accumulate_state(cue, accumulated_animated_data, animator)

	animator.set_animated_data(accumulated_animated_data)
	_handle_animator_finished(animator, cue_number, fade_time)

	force_reload = false


	if (not going_backwards or _mode == MODE.LOOP) and not reset:
		match next_cue.trigger_mode:
			Cue.TRIGGER_MODE.AFTER_LAST:
				_seek_to_next_cue_after(next_cue.pre_wait + fade_time)

			Cue.TRIGGER_MODE.WITH_LAST:
				_seek_to_next_cue_after(next_cue.pre_wait)

			Cue.TRIGGER_MODE.MANUAL:
				if _autoplay:
					_seek_to_next_cue_after(next_cue.pre_wait + fade_time)


	last_cue = current_cue
	on_cue_changed.emit(_index_list[_index] if not reset else -1.0)



func _seek_to_next_cue_after(seconds: float) -> void:
	var orignal_index: int = _index

	await Core.get_tree().create_timer(seconds).timeout

	if _index == orignal_index:
		go_next()


func _reset_animated_fixtures(animator: Animator, accumulated_animated_data: Dictionary) -> void:
	for animation_id in _current_animated_fixtures.keys():
		var animating_fixture = _current_animated_fixtures[animation_id]
		var from_value: float = animating_fixture.fixture.get_current_value(animating_fixture.zone, animating_fixture.parameter, uuid, animating_fixture.function)
		var to_value: float = animating_fixture.fixture.get_default(animating_fixture.zone, animating_fixture.parameter, animating_fixture.function)

		if is_instance_valid(animating_fixture.animator):
			animating_fixture.animator.remove_track_from_id(animation_id, false)

		accumulated_animated_data[animation_id] = {
			"method": func (new_value: Variant) -> void:
					_current_animated_fixtures[animation_id].current_value = new_value
					animating_fixture.fixture.set_parameter(
						animating_fixture.parameter,
						animating_fixture.function,
						new_value * (_intensity if animating_fixture.parameter in _allowed_intensity_parameters else 1.0),
						uuid,
						animating_fixture.zone
					),
			"from": from_value,
			"to": to_value,
			"current": from_value,
			"can_fade": animating_fixture.can_fade,
			"start": animating_fixture.start,
			"stop": animating_fixture.stop,
			"first_time": true
		}

		_current_animated_fixtures[animation_id] = {
			"zone": animating_fixture.zone,
			"parameter": animating_fixture.parameter,
			"function": animating_fixture.function,
			"fixture": animating_fixture.fixture,
			"can_fade": animating_fixture.can_fade,
			"start": animating_fixture.start,
			"stop": animating_fixture.stop,
			"animator": animator,
			# "current_value": to_value
		}


func _remove_all_animators() -> void:
	for old_cue_number: float in _current_animators:
		_remove_animator(old_cue_number)


## Builds animation data from the cue and updates current animations.
func _accumulate_state(cue: Cue, accumulated_animated_data: Dictionary, animator: Animator) -> void:
	var fixture_data: Dictionary = cue.get_fixture_data()

	for fixture: Fixture in fixture_data:
		for zone: String in fixture_data[fixture]:
			for parameter: String in fixture_data[fixture][zone]:
				var value_config: Dictionary = fixture_data[fixture][zone][parameter]
				var from_value: float = fixture.get_current_value(zone, parameter, uuid, value_config.function)
				var to_value: Variant = value_config.value

				var animation_id: String = fixture.uuid + zone + parameter
				accumulated_animated_data[animation_id] = {
					"method": func (new_value: Variant) -> void:
						_current_animated_fixtures[animation_id].current_value = new_value

						fixture.set_parameter(
							parameter,
							value_config.function,
							new_value * (_intensity if parameter in _allowed_intensity_parameters else 1.0),
							uuid,
							zone
						),
					"from": from_value * (2 - (_intensity if parameter in _allowed_intensity_parameters else 1.0)),
					"to": to_value,
					"current": from_value * (2 - (_intensity if parameter in _allowed_intensity_parameters else 1.0)),
					"can_fade": value_config.can_fade,
					"start": value_config.start,
					"stop": value_config.stop,
					"first_time": true
				}

				if animation_id in _current_animated_fixtures:
					if _current_animated_fixtures[animation_id].has("current_value"):
						accumulated_animated_data[animation_id].from = _current_animated_fixtures[animation_id].current_value

					var _animator = _current_animated_fixtures[animation_id].animator
					if is_instance_valid(_animator) and _animator != animator:
						_animator.remove_track_from_id(animation_id, false)


				_current_animated_fixtures[animation_id] = {
					"zone": zone,
					"parameter": parameter,
					"function": value_config.function,
					"can_fade": value_config.can_fade,
					"start": value_config.start,
					"stop": value_config.stop,
					"fixture": fixture,
					"animator": animator,
					"current_value": from_value
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
	_autoplay = false
	seek_to(-1)
	on_stopped.emit()


## Start auto play
func play() -> void:
	_autoplay = true
	go_next()
	on_played.emit()


## Stop auto play
func pause() -> void:
	_autoplay = false
	on_paused.emit()


## Moves the cue at cue_number up. By swapping the number with the next cue in the list
func move_cue_up(cue_number: float) -> void:
	if cue_number in _index_list:
		var main_cue: Cue = _cues[cue_number]
		var next_cue: Cue = _cues[_index_list[_index_list.find(main_cue.number) - 1]]

		var main_cue_old_number: float = main_cue.number
		main_cue.number = next_cue.number
		next_cue.number = main_cue_old_number

		_cues[main_cue.number] = main_cue
		_cues[next_cue.number] = next_cue

		force_reload = true
		_index = _index_list.find(main_cue.number)

		on_cue_numbers_changed.emit({
			main_cue.number: main_cue,
			next_cue.number: next_cue
		})

## Moves the cue at cue_number down. By swapping the number with the previous cue in the list
func move_cue_down(cue_number: float) -> void:
	if cue_number in _index_list:
		var main_cue: Cue = _cues[cue_number]
		var previous_cue: Cue = _cues[_index_list[wrapi(_index_list.find(main_cue.number) + 1, 0, len(_index_list))]]

		var main_cue_old_number: float = main_cue.number
		main_cue.number = previous_cue.number
		previous_cue.number = main_cue_old_number

		_cues[main_cue.number] = main_cue
		_cues[previous_cue.number] = previous_cue

		force_reload = true
		_index = _index_list.find(main_cue.number)

		on_cue_numbers_changed.emit({
			main_cue.number: main_cue,
			previous_cue.number: previous_cue
		})


func set_cue_number(new_number: float, cue: Cue) -> bool:
	if cue in _cues.values() and get_cue(new_number) == null:

		_index_list.erase(cue.number)
		_index_list.append(new_number)
		_index_list.sort()

		_cues.erase(cue.number)
		_cues[new_number] = cue

		cue.number = new_number

		_index = _index_list.find(cue.number)
		force_reload = true

		on_cue_numbers_changed.emit({
			new_number: cue
		})

		return true

	else:
		return false


##Duplicates a cue
func duplicate_cue(cue_number: float) -> void:
	if not cue_number in _cues.keys():
		return

	var new_cue: Cue = Cue.new()
	new_cue.load(_cues[cue_number].serialize())

	add_cue(new_cue, -1)


## Returnes the cue at the given index, or null if none is found
func get_cue(cue_number: float) -> Cue:
	return _cues.get(cue_number, null)


## Changes the current mode
func set_mode(p_mode: MODE) -> void:
	_mode = p_mode
	on_mode_changed.emit(_mode)


## Sets the intensity of this function, from 0.0 to 1.0
func set_intensity(p_intensity: float) -> void:
	_intensity = p_intensity
	on_intensity_changed.emit(snapped(_intensity, 0.001))

	if _index != -1:
		for animated_fixture: Dictionary in _current_animated_fixtures.values():
			if not is_instance_valid(animated_fixture.animator) and animated_fixture.has("current_value") and animated_fixture.parameter in _allowed_intensity_parameters:
				var fixture: Fixture = animated_fixture.fixture

				if fixture.function_can_fade(animated_fixture.zone, animated_fixture.parameter, animated_fixture.function):
					fixture.set_parameter(
						animated_fixture.parameter,
						animated_fixture.function,
						animated_fixture.current_value * _intensity,
						uuid,
						animated_fixture.zone
					)


## Sets the fade time for all cues
func set_global_fade_time(fade_time: float) -> void:
	for cue: Cue in _cues.values():
		cue.set_fade_time(fade_time)


## Sets the pre wait time for all cues
func set_global_pre_wait(pre_wait: float) -> void:
	for cue: Cue in _cues.values():
		cue.set_pre_wait(pre_wait)


## Called when this CueList is to be deleted
func _on_delete_request() -> void:
	seek_to(-1, 0)

	for cue: Cue in _cues.values():
		Server.remove_networked_object(cue.uuid)
		cue.delete()


## Saves this cue list to a Dictionary
func _on_serialize_request(p_mode: int) -> Dictionary:
	var serialized_cues: Dictionary = {}
	for cue_index: float in _index_list:
		serialized_cues[str(cue_index)] = _cues[cue_index].serialize()

	var serialized_data: Dictionary = {
		"cues": serialized_cues,
		"mode": _mode,
	}

	if p_mode == CoreEngine.SERIALIZE_MODE_NETWORK:
		serialized_data.merge({
			"index": _index,
			"intensity": _intensity
		})

	return serialized_data


## Loads this cue list from a Dictionary
func _on_load_request(serialized_data: Dictionary) -> void:
	_mode = int(serialized_data.get("mode", MODE.NORMAL))

	for cue_index: String in serialized_data.get("cues").keys():
		var new_cue: Cue = Cue.new()
		new_cue.load(serialized_data.cues[cue_index])
		add_cue(new_cue, float(cue_index))
