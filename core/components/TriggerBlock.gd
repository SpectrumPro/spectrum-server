# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name TriggerBlock extends EngineComponent
## Block of triggers


## Emitted when a trigger is added
signal on_trigger_added(component: EngineComponent, id: String, name: String, row: int, column: int)

## Emitted when a trigger is added
signal on_trigger_removed(row: int, column: int)

## Emitted when a column is reset
signal on_column_reset(column: int)

## Emitted when a trigger name is changes
signal on_trigger_name_changed(row: int, column: int, name: String)

## Emitted when a trigger is triggred
signal on_trigger_up(row: int, column: int)

## Emitted when a trigger is triggred
signal on_trigger_down(row: int, column: int)


## All triggeres stores as { row: { column: {trigger...} } }
var _triggers: Dictionary[int, Dictionary]


## Ready
func _component_ready() -> void:
	set_name("TriggerBlock")
	set_self_class("TriggerBlock")


## Adds a trigger at the given row and column
func add_trigger(p_component: EngineComponent, p_id: String, p_name: String, p_row: int, p_column: int, no_signal: bool = false) -> bool:
	if not p_component.get_control_method(p_id):
		return false

	_triggers.get_or_add(p_row, {})[p_column] = {
		"component": p_component,
		"id": p_id,
		"name": p_name,
	}

	if not no_signal:
		on_trigger_added.emit(p_component, p_id, p_name, p_row, p_column)

	return true


## Removes a trigger
func remove_trigger(p_row: int, p_column: int, no_signal: bool = false) -> bool:
	if not _triggers.has(p_row) or not _triggers[p_row].has(p_column):
		return false

	_triggers.get(p_row, {}).erase(p_column)

	if not no_signal:
		on_trigger_removed.emit(p_row, p_column)

	return true


## Resets a whole column
func reset_column(p_column: int) -> void:
	for row: int in _triggers:
		if p_column in _triggers[row]:
			remove_trigger(row, p_column, true)
	
	on_column_reset.emit(p_column)


## Renames a trigger
func rename_trigger(p_row: int, p_column: int, p_name: String, no_signal: bool = false) -> bool:
	if not _triggers.has(p_row) or not _triggers[p_row].has(p_column):
		return false

	_triggers[p_row][p_column].name = p_name

	if not no_signal:
		on_trigger_name_changed.emit(p_row, p_column, no_signal)

	return true


## Triggers a trigger
func call_trigger_up(p_row: int, p_column: int, p_value: Variant = null) -> void:
	var trigger: Dictionary = _triggers.get(p_row, {}).get(p_column, {})
	if not trigger:
		return
	
	var config: Dictionary = trigger.component.get_control_method(trigger.id)

	if not config or not config.up:
		return

	if config.args and p_value != null:
		config.up.call(p_value)
	
	elif not config.args:
		config.up.call()

	on_trigger_up.emit(p_row, p_column, p_value)


## Triggers a trigger
func call_trigger_down(p_row: int, p_column: int, p_value: Variant = null) -> void:
	var trigger: Dictionary = _triggers.get(p_row, {}).get(p_column, {})
	if not trigger:
		return
	
	var config: Dictionary = trigger.component.get_control_method(trigger.id)

	if not config or not config.down:
		return

	if config.args and p_value != null:
		config.down.call(type_convert(p_value, config.args[0]))
	
	elif not config.args:
		config.down.call()

	on_trigger_down.emit(p_row, p_column, p_value)


## Gets all the triggers
func get_triggers() -> Dictionary[int, Dictionary]:
	return _triggers.duplicate()


## Overide this function to serialize your object
func _on_serialize_request(p_mode: int) -> Dictionary:
	var triggers: Dictionary[int, Dictionary]

	for row: int in _triggers:
		triggers[row] = {}
		for column: int in _triggers[row]:
			triggers[row][column] = {
				"component": _triggers[row][column].component.uuid,
				"id": _triggers[row][column].id,
				"name": _triggers[row][column].name,
			}

	return {
		"triggers": triggers
	}


## Overide this function to handle load requests
func _on_load_request(p_serialized_data: Dictionary) -> void:
	var triggers: Dictionary = type_convert(p_serialized_data.get("triggers", {}), TYPE_DICTIONARY)


	for row_key: Variant in triggers.keys():
		var row_str: String = str(row_key)
		var row_dict: Dictionary = type_convert(triggers.get(row_str, {}), TYPE_DICTIONARY)

		for column_key: Variant in row_dict.keys():
			var column_str: String = str(column_key)
			var trigger_data: Dictionary = type_convert(row_dict.get(column_str, {}), TYPE_DICTIONARY)

			var component_id: Variant = trigger_data.get("component", null)
			var id: String = type_convert(trigger_data.get("id", ""), TYPE_STRING)
			var name: String = type_convert(trigger_data.get("name", ""), TYPE_STRING)

			if component_id == null:
				continue

			var row_int: int = int(row_str)
			var column_int: int = int(column_str)

			ComponentDB.request_component(component_id, func(component: EngineComponent) -> void:
				add_trigger(component, id, name, row_int, column_int, true)
			)
		