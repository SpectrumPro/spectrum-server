# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name Fixture extends EngineComponent
## Engine class to control parameters of fixtures, when calling load() be sure to also call set_manifest(), as fixtures do not seralise manifests, only manifest paths

## Emitted when the color of this fixture is changed 
signal on_color_changed(color: Color)

## Emitted when the white intensity of this fixture is changed
signal on_white_intensity_changed(value: int)


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
var white: int = 0

var position: Vector2 = Vector2.ZERO ## Position of this fixture in space, unused currently, but will be used for pixel mapping at some point


## Contains all the parameters inputted by other function, ie scenes, programmers, animations, ect. 
## Each input it added to this dict with a id for each item, allowing for HTP and LTP calculations
var current_input_data: Dictionary = {} 

var _compiled_dmx_data: Dictionary


## Set the manifest of this fixture
func set_manifest(p_manifest: Dictionary, p_manifest_path: String = "") -> void:
	length = len(p_manifest.modes.values()[mode - 1].channels)
	manifest = p_manifest
	channel_ranges = p_manifest.get("channels", {})
	channels = p_manifest.modes.values()[mode - 1].channels

	if p_manifest_path:
		manifest_path = p_manifest_path
	else:
		print(name, ": set_manifest() was called with out specifiing \"manifest_path\", this fixture may not work when loaded from a save file")


## Compiles the data to dmx data using the HTP blend mode
func recompile_data() -> void:
	## Compiles dmx data from this fixture
	
	var highest_valued_data: Dictionary = {}
	
	for input_data_id in current_input_data:
		for input_data in current_input_data[input_data_id]:
			match input_data:
				"color":
					highest_valued_data["color"] = Utils.get_htp_color(highest_valued_data.get("color", Color()), current_input_data[input_data_id].color)
				"white":
					var current_white: int = highest_valued_data.get("white", 0)
					highest_valued_data["white"] = current_white if current_white > current_input_data[input_data_id].white else current_input_data[input_data_id].white
	
	_set_color(highest_valued_data.get("color", Color.BLACK))
	_set_white_intensity(highest_valued_data.get("white", 0))
	_fixture_data_changed.emit(_compiled_dmx_data)



## Color Channels:



## Sets the color of this fixture
func set_color(color: Color, id: String = "override") -> void:
	## Sets the color of this fixture
	
	if color == Color.BLACK:
		_remove_current_input_data(id, "color")
	else:
		_add_current_input_data(id, "color", color)
	
	recompile_data()


## Internal function that really sets the color of this fixture, and emits the signal
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


## Sets the white intensity of this fixture
func set_white_intensity(value: int, id: String = "override") -> void:
	if value:
		_add_current_input_data(id, "white", clamp(value, 0, 255))
	else:
		_remove_current_input_data(id, "white")
	
	recompile_data()


## Internal function that really changed the white value, and emits the signal
func _set_white_intensity(value: int) -> void:
	if "ColorIntensityWhite" in channels:
		_compiled_dmx_data[int(channels.find("ColorIntensityWhite") + channel)] = value

	white = value
	on_white_intensity_changed.emit(value)


## Adds some input data to this fixture, used for calculating blend modes when compiling
func _add_current_input_data(id: String, key: String, value: Variant) -> void:
	if id not in current_input_data:
		current_input_data[id] = {}
	current_input_data[id][key] = value


## Removes some input data to this fixture
func _remove_current_input_data(id: String, key: String) -> void:
	current_input_data.get(id, {}).erase(key)
	# if not current_input_data.get(id, false):
	# 	current_input_data.erase(id) 


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
	
	set_manifest(Core.fixtures_definitions[manifest_path.split("/")[0]][manifest_path.split("/")[1]], manifest_path)

	if not manifest_path:
		print(name, ": Was loaded with out specifying a manifest_path, unless a seprate script loads a manifest, i will be useless after a file reload")