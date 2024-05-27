# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name Fixture extends EngineComponent
## Engine class to control parameters of fixtures, when calling load() be sure to also call set_manifest(), as fixtures do not seralise manifests, only manifest paths

signal on_color_changed(color: Color) ## Emitted when the color of this fixture is changed 
signal on_mode_changed(mode: int) ## Emitted when the mode of the fixture is changed
signal on_channel_changed(new_channel: int) ## Emitted when the channel of the fixture is changed

signal _fixture_data_changed(data: Dictionary) ## Emitted when any of the channels of this fixture are changed, emitted as channel:value for all channels this fixtures uses

var channel: int ## Universe channel of this fixture
var length: int ## Channel length, from start channel, to end channel
var mode: int ## Current mode

var manifest: Dictionary ## Fixture manifest
var manifest_path: String ## Stores the file path to this fixtures manifest, if one exists 
var channels: Array ## Channels this fixture uses, and what they do
var channel_ranges: Dictionary ## What happenes on each channel, at each value range


var color: Color = Color.BLACK
var position: Vector2 = Vector2.ZERO ## Position of this fixture in space, unused currently, but will be used for pixel mapping at some point


## Contains all the parameters inputted by other function, ie scenes, programmers, animations, ect. 
## Each input it added to this dict with a id for each item, allowing for HTP and LTP calculations
var current_input_data: Dictionary = {} 

var _compiled_dmx_data: Dictionary


func set_manifest(p_manifest: Dictionary, p_manifest_path: String = "") -> void:
	length = len(p_manifest.modes.values()[mode].channels)
	manifest = p_manifest
	channel_ranges = p_manifest.get("channels", {})
	channels = p_manifest.modes.values()[mode].channels

	if p_manifest_path:
		manifest_path = p_manifest_path
	else:
		print(name, ": set_manifest() was called with out specifiing \"manifest_path\", this fixture may not work when loaded from a save file")


func _on_serialize_request() -> Dictionary:
	## Returnes serialized infomation about this fixture

	return {
		"channel": channel,
		"mode": mode,
		"position": [position.x, position.y],
		"manifest_path": manifest_path
	}


func _on_delete_request() -> void:
	
	var empty_data: Dictionary = {}
	
	for i in _compiled_dmx_data:
		empty_data[i] = 0
	
	_fixture_data_changed.emit(empty_data)


func _on_load_request(serialized_data: Dictionary) -> void:
	channel = serialized_data.get("channel", 1)
	mode = serialized_data.get("mode", 1)
	position = Vector2(serialized_data.get("position", [0,0])[0], serialized_data.get("position", [0,0])[1])
	manifest_path = serialized_data.get("manifest_path", "")

	if not manifest_path:
		print(name, ": Was loaded with out specifying a manifest_path, unless a seprate script loads a manifest, i will be useless after a file reload")


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



func _set_color(p_color: Color) -> void:

	if p_color.is_equal_approx(color):
		return 

	if "ColorIntensityRed" in channels:
		_compiled_dmx_data[int(channels.find("ColorIntensityRed") + channel)] = p_color.r8
	if "ColorIntensityGreen" in channels:
		_compiled_dmx_data[int(channels.find("ColorIntensityGreen") + channel)] = p_color.g8
	if "ColorIntensityBlue" in channels:
		_compiled_dmx_data[int(channels.find("ColorIntensityBlue") + channel)] = p_color.b8
	color = p_color
	on_color_changed.emit(p_color)


func set_color(color: Color, id: String = "override") -> void:
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
