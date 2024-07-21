# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name Fixture extends EngineComponent
## Engine class to control parameters of fixtures, when calling load() be sure to also call set_manifest(), as fixtures do not seralise manifests, only manifest paths


## Emitted when the color of this fixture is changed 
signal on_color_changed(color: Color)

## Emitted when the value of a channel is changed
signal on_white_intensity_changed(value: int)
signal on_amber_intensity_changed(value: int)
signal on_uv_intensity_changed(value: int)
signal on_dimmer_changed(value: int)

## Emitted when the mode of the fixture is changed
signal on_mode_changed(mode: int)

## Emitted when the channel of the fixture is changed
signal on_channel_changed(new_channel: int)

## Emitted when any of the channels of this fixture are changed, emitted as channel:value for all channels this fixtures uses
signal _fixture_data_changed(data: Dictionary)



var network_config: Dictionary = {
	"high_frequency_signals": [
		on_color_changed,
		on_white_intensity_changed,
		on_amber_intensity_changed,
		on_uv_intensity_changed,
		on_dimmer_changed,
	]
}



## Universe channel of this fixture
var channel: int

## Channel length, from start channel, to end channel
var length: int 

## Current mode
var mode: int

## Fixture manifest
var manifest: Dictionary 

## Stores the file path to this fixtures manifest, if one exists 
var manifest_path: String

## Channels this fixture uses
var channels: Array 

## What happenes on each channel, at each value range
var channel_ranges: Dictionary 

var current_values: Dictionary = {
	"set_color": 			Color.BLACK,
	"ColorIntensityWhite": 	0,
	"ColorIntensityAmber": 	0,
	"ColorIntensityUV": 	0,
	"Dimmer": 				0
}


var channel_config: Dictionary = {
	"ColorIntensityRed": 	{},
	"ColorIntensityGreen": 	{},
	"ColorIntensityBlue":	{},
	"ColorIntensityWhite": 	{"signal": on_amber_intensity_changed},
	"ColorIntensityAmber": 	{"signal": on_white_intensity_changed},
	"ColorIntensityUV": 	{"signal": on_uv_intensity_changed},
	"Dimmer":				{"signal": on_dimmer_changed}
}



## The override value, pass this as the layer id to override any other values
const OVERRIDE: String = "OVERRIDE"
const REMOVE_OVERRIDE: String = "REMOVE_OVERRIDE"

## The highest dmx value allowed
const MAX_DMX_VALUE: int = 255


## Contains all the parameters inputted by other function, ie scenes, programmers, animations, ect. 
## Each input it added to this dict with a id for each item, allowing for HTP and LTP calculations
var _current_input_data: Dictionary = {} 

## The compiled dmx data, after htp and ltp calculation are ran
var _compiled_dmx_data: Dictionary


## Called when this EngineComponent is ready
func _component_ready() -> void:
	name = "Fixture"
	self_class_name = "Fixture"


## Set the manifest of this fixture
func set_manifest(p_manifest: Dictionary, p_manifest_path: String = "") -> void:
	length = len(p_manifest.modes.values()[mode - 1].channels)
	manifest = p_manifest

	channel_ranges = p_manifest.get("channels", {})
	channels = p_manifest.modes.values()[mode - 1].channels

	if p_manifest_path:
		manifest_path = p_manifest_path
	else:
		print_verbose(name, ": set_manifest() was called with out specifiing \"manifest_path\", this fixture may not work when loaded from a save file")


func set_channel(p_channel: int) -> void:
	emit_zero_values()
	channel = p_channel
	on_channel_changed.emit(channel)

## Channels


## Sets the color of this fixture
func set_color(p_color: Color, id: String) -> void:	
	var new_color: Color = Color()
	new_color.r8 = set_current_input_data(id, "ColorIntensityRed", clamp(p_color.r8, 0, MAX_DMX_VALUE), false)
	new_color.g8 = set_current_input_data(id, "ColorIntensityGreen", clamp(p_color.g8, 0, MAX_DMX_VALUE), false)
	new_color.b8 = set_current_input_data(id, "ColorIntensityBlue", clamp(p_color.b8, 0, MAX_DMX_VALUE), false)
	
	if not "set_color" in _current_input_data:
		_current_input_data["set_color"] = {}
	
	if p_color:
		_current_input_data["set_color"][id] = p_color
	else:
		_current_input_data["set_color"].erase(id)

	if new_color != current_values.set_color:
		_fixture_data_changed.emit(_compiled_dmx_data)

		current_values.set_color = new_color
		on_color_changed.emit(new_color)
	


## White channel intensity
func ColorIntensityWhite(value: int, id: String) -> void: current_values.ColorIntensityWhite = set_current_input_data(id, "ColorIntensityWhite", clamp(value, 0, MAX_DMX_VALUE))

## Amber channel intensity
func ColorIntensityAmber(value: int, id: String) -> void: current_values.ColorIntensityAmber = set_current_input_data(id, "ColorIntensityAmber", clamp(value, 0, MAX_DMX_VALUE))

## Amber channel intensity
func ColorIntensityUV(value: int, id: String) -> void: current_values.ColorIntensityUV = set_current_input_data(id, "ColorIntensityUV", clamp(value, 0, MAX_DMX_VALUE))

## Dimmer channel intensity
func Dimmer(value: int, id: String) -> void: current_values.Dimmer = set_current_input_data(id, "Dimmer", clamp(value, 0, MAX_DMX_VALUE))

## End Channels



## Adds some input data to this fixture, used for calculating blend modes when compiling. Returns the new highest value on that layer 
func set_current_input_data(layer_id: String, channel_key: String, value: Variant, emit_signals: bool = true) -> int:
	if channel_key not in _current_input_data:
		_current_input_data[channel_key] = {}

	var old_value = _current_input_data[channel_key].values().max()

	if value or layer_id == OVERRIDE:
		_current_input_data[channel_key][layer_id] = value
	else:
		_current_input_data[channel_key].erase(layer_id)
	
	var new_value = _current_input_data[channel_key].values().max()

	if OVERRIDE in _current_input_data[channel_key].keys():
		if layer_id == REMOVE_OVERRIDE:
			_current_input_data[channel_key].erase(OVERRIDE)
			new_value = _current_input_data[channel_key].values().max()
		else:
			new_value = _current_input_data[channel_key][OVERRIDE]

	new_value = new_value if new_value else 0

	if old_value != new_value and channel_key in channels:
		var channel_signal: Signal = channel_config.get(channel_key).get("signal", Signal())

		_compiled_dmx_data[channels.find(channel_key) + channel] = new_value

		if emit_signals:
			_fixture_data_changed.emit(_compiled_dmx_data)

			if not channel_signal.is_null():
				channel_signal.emit(new_value)

	return new_value


func get_value_from_layer_id(id: String, value_name: String) -> Variant:
	return _current_input_data.get(value_name, {}).get(id, get_zero_from_channel_key(value_name))


func get_zero_from_channel_key(value_name: String) -> Variant:
	match value_name:
		"set_color":
			return Color.BLACK
		_:
			return 0


func _on_serialize_request(mode: int) -> Dictionary:
	## Returnes serialized infomation about this fixture

	return {
		"channel": channel,
		"mode": mode,
		# "position": [position.x, position.y],
		"manifest_path": manifest_path
	}


func emit_zero_values() -> void:
	var empty_data: Dictionary = {}
	
	for i in _compiled_dmx_data:
		empty_data[i] = 0
	
	_fixture_data_changed.emit(empty_data)


func _on_delete_request() -> void:
	emit_zero_values()


func _on_load_request(serialized_data: Dictionary) -> void:
	channel = serialized_data.get("channel", 1)
	mode = serialized_data.get("mode", 1)
	# position = Vector2(serialized_data.get("position", [0,0])[0], serialized_data.get("position", [0,0])[1])
	manifest_path = serialized_data.get("manifest_path", "")
	
	set_manifest(Core.fixtures_definitions[manifest_path.split("/")[0]][manifest_path.split("/")[1]], manifest_path)
