# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name Fixture extends EngineComponent
## Engine class to control parameters of fixtures

signal on_color_changed(color: Color) ## Emitted when the color of this fixture is changed 
signal on_mode_changed(mode: int) ## Emitted when the mode of the fixture is changed
signal on_channel_changed(new_channel: int) ## Emitted when the channel of the fixture is changed

signal _fixture_data_changed(data: Dictionary) ## Emitted when any of the channels of this fixture are changed, emitted as channel:value for all channels this fixtures uses

## Contains metadata infomation about this fixture
var meta: Dictionary = { 
	"fixture_brand":"",
	"fixture_name":"",
	"display_name":"",
}

var universe: Universe ## The universe this fixture is patched to
var channel: int ## Universe channel of this fixture
var length: int ## Channel length, from start channel, to end channel
var mode: int ## Current mode
var manifest: Dictionary ## Fixture manifest
var channels: Array ## Channels this fixture uses, and what they do
var channel_ranges: Dictionary ## What happenes at each channel, at each value

var position: Vector2 = Vector2.ZERO


## Contains all the parameters inputted by other function in spectrum, ie scenes, programmer, ect. 
## Each input it added to this dict with a id for each item, allowing for HTP and LTP calculations
var current_input_data: Dictionary = {} 

var _compiled_dmx_data: Dictionary


func _on_serialize_request() -> Dictionary:
	## Returnes serialized infomation about this fixture

	return {
		"channel": channel,
		"mode": mode,
		"position": position,
		"meta": meta
	}


func recompile_data() -> void:
	## Compiles dmx data from this fixture
	
	var highest_valued_data: Dictionary = {}
	
	for input_data_id in current_input_data:
		for input_data in current_input_data[input_data_id]:
			match input_data:
				"color":
					highest_valued_data["color"] = Utils.get_htp_color(highest_valued_data.get("color", Color()), current_input_data[input_data_id].color)
	
	_set_color(highest_valued_data.get("color", Color.BLACK))
	_fixture_data_changed.emit(_compiled_dmx_data)


func _on_delete_request() -> void:
	
	var empty_data: Dictionary = {}
	
	for i in _compiled_dmx_data:
		empty_data[i] = 0
	
	# universe.set_data(empty_data)


func _set_color(color: Color) -> void:
	if "ColorIntensityRed" in channels:
		_compiled_dmx_data[int(channels.find("ColorIntensityRed") + channel)] = color.r8
	if "ColorIntensityGreen" in channels:
		_compiled_dmx_data[int(channels.find("ColorIntensityGreen") + channel)] = color.g8
	if "ColorIntensityBlue" in channels:
		_compiled_dmx_data[int(channels.find("ColorIntensityBlue") + channel)] = color.b8
	
	on_color_changed.emit(color)


func set_color(color: Color, id: String = "overide") -> void:
	## Sets the color of this fixture
	
	if color == Color.BLACK:
		_remove_current_input_data(id, "color")
	else:
		_add_current_input_data(id, "color", color)
	
	recompile_data()


func _add_current_input_data(id: String, key: String, value: Variant) -> void:
	if id not in current_input_data:
		current_input_data[id] = {}
	current_input_data[id][key] = value


func _remove_current_input_data(id: String, key: String) -> void:
	current_input_data.get("id", {}).erase(key)
	if not current_input_data.get("id", false):
		current_input_data.erase(id) 
