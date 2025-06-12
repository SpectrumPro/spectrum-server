# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name FunctionGroup extends Function
## A group of functions


## Emitted when functions are added
signal on_functions_added(functions: Array)

## Emitted when functions are removed
signal on_functions_removed(functions: Array)

## Emitted when a Function's index is changed
signal on_functions_index_changed(function: Function, index: int)


## Refmap for storing functions
var _functions: Array[Function]


## Init
func _component_ready() -> void:
	set_name("FunctionGroup")
	set_self_class("FunctionGroup")


## Adds a function
func add_function(p_function: Function, no_signal: bool = false) -> bool:
	if not p_function or p_function in _functions or p_function == self:
		return false

	p_function.on_delete_requested.connect(remove_function.bind(p_function))
	_functions.append(p_function)

	if not no_signal:
		on_functions_added.emit([p_function])

	return true


## Adds mutiple functions at once
func add_functions(p_functions: Array) -> void:
	var just_added_functions: Array[Function]

	for function: Variant in p_functions:
		if function is Function:
			if add_function(function, true):
				just_added_functions.append(function)

	if just_added_functions:
		on_functions_added.emit(just_added_functions)


## Removes a function
func remove_function(p_function: Function, no_signal: bool = false) -> bool:
	if p_function not in _functions:
		return false

	_functions.erase(p_function)

	if not no_signal:
		on_functions_removed.emit([p_function])

	return true


## Removes mutiple functions at once
func remove_functions(p_functions: Array) -> void:
	var just_removed_functions: Array[Function]

	for function: Variant in p_functions:
		if function is Function:
			if remove_function(function, true):
				just_removed_functions.append(function)

	if just_removed_functions:
		on_functions_removed.emit(just_removed_functions)


## Sets the indes of a function
func set_function_index(p_function: Function, p_index: int) -> bool:
	if p_function not in _functions or p_index > _functions.size() - 1:
		return false

	_functions.erase(p_function)
	_functions.insert(p_index, p_function)

	on_functions_index_changed.emit(p_function, p_index)

	return true


## Moves a Function up an index
func move_up(p_function: Function) -> void:
	if p_function not in _functions:
		return

	set_function_index(p_function, clamp(_functions.find(p_function) - 1, 0, _functions.size()))


## Moves a Function down an index
func move_down(p_function: Function) -> void:
	if p_function not in _functions:
		return

	set_function_index(p_function, clamp(_functions.find(p_function) + 1, 0, _functions.size()))


## Gets all the functions
func get_functions() -> Array[Function]:
	return _functions.duplicate()


## Checks if this FunctionGroup has a function
func has_function(p_function: Function) -> bool:
	return _functions.has(p_function)


## Override this function to handle ActiveState changes
func _handle_active_state_change(active_state: ActiveState) -> void:
	for function: Function in _functions:
		function.set_active_state(active_state)


## Override this function to handle TransportState changes
func _handle_transport_state_change(transport_state: TransportState) -> void:
	for function: Function in _functions:
		function.set_transport_state(transport_state)


## Override this function to handle intensity changes
func _handle_intensity_change(p_intensity: float) -> void:
	for function: Function in _functions:
		function.set_intensity(p_intensity)


## Overide this function to serialize your object
func _on_serialize_request(p_mode: int) -> Dictionary:
	var function_uuids: Array[String]

	for function: Function in _functions:
		function_uuids.append(function.uuid)

	return {
		"functions": function_uuids
	}


## Overide this function to handle load requests
func _on_load_request(p_serialized_data: Dictionary) -> void:
	var function_uuids: Array = type_convert(p_serialized_data.get("functions", []), TYPE_ARRAY)

	for uuid: Variant in function_uuids:
		if uuid is String:
			ComponentDB.request_component(uuid, func (function: EngineComponent):
				if function is Function:
					add_function(function, true)
			)
