# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name CoreFixtureLibrary extends Node
## The main fixture library used to manage fixture manifests


## Emitted when the manifests are loaded
signal manifests_loaded()


## File path for the built in fixture library
const _built_in_library_path: String = "res://core/fixtures/"

## File path for the user fixture library. This needs to be loaded after Core is ready, otherwise core.data_folder will be invalid
var _user_fixture_library_path: String = ""

## All the current fixture manifests, sorted by manufacturer and fixture
var _sorted_fixture_manifests: Dictionary = {}

## All the current fixture manifests, sorted by filenames
var _fixture_manifests: Dictionary = {}

## All the current requests for manifetst
var _manifest_requests: Dictionary

## Loaded state
var _is_loaded: bool = false


## Load the fixture manifests from the folders, buit in manifests will override user manifests
func _ready() -> void:
	await Core.ready

	_user_fixture_library_path = Core.data_folder + "/fixtures"
	Utils.ensure_folder_exists(_user_fixture_library_path)

	_load_manifests()
	manifests_loaded.emit()


## Returnes all currently loaded sorted fixture manifests
func get_sorted_fixture_manifests() -> Dictionary:
	return _sorted_fixture_manifests.duplicate(true)


## Gets a manifest from a manifest uuid
func request_manifest(p_manifest_uuid: String) -> Promise:
	var promise: Promise = Promise.new()

	print(p_manifest_uuid)
	if _fixture_manifests.has(p_manifest_uuid):
		print("has")
		promise.auto_resolve([_get_gdtf_from_file_path(_fixture_manifests[p_manifest_uuid])])
	else:
		_manifest_requests.get_or_add(p_manifest_uuid, []).append(promise)

	return promise


## Check loaded state
func is_loaded() -> bool: 
	return _is_loaded


## Creates a new fixture from a manifest
func create_fixture(manifest_uuid: String, universe: Universe, config: Dictionary) -> void:
	if manifest_uuid in _fixture_manifests:
		var manifest: Dictionary = _get_gdtf_from_file_path(_fixture_manifests[manifest_uuid])
		if manifest and manifest.has(config.get("mode")):
			var length: int = manifest[config.mode].dmx_length

			for i: int in range(config.quantity):

				var new_fixture: DMXFixture = DMXFixture.new()

				new_fixture.set_channel(config.channel + (length * i) + (config.offset if i != 0 else 0))
				new_fixture.set_name(config.name)
				new_fixture.set_manifest(manifest_uuid, manifest, config.mode)

				universe.add_fixture(new_fixture)


## Loads all the fixture manifetst
func _load_manifests() -> void:
	var user_library: Dictionary = _get_gdtf_list_from_folder(_user_fixture_library_path, true)
	var built_in_libaray: Dictionary = _get_gdtf_list_from_folder(_built_in_library_path, true)

	_sorted_fixture_manifests = user_library.sorted
	_sorted_fixture_manifests.merge(built_in_libaray.sorted, true)

	_fixture_manifests = user_library.files
	_fixture_manifests.merge(built_in_libaray.files, true)
	
	_is_loaded = true
	manifests_loaded.emit()
	_resolve_requests()


## Attempts to resolve all manifest requests
func _resolve_requests() -> void:
	for manifest_uuid: String in _manifest_requests.keys():
		if _fixture_manifests.has(manifest_uuid):
			var manifest: Dictionary = _get_gdtf_from_file_path(_fixture_manifests[manifest_uuid])
			for promise: Promise in _manifest_requests[manifest_uuid]:
				promise.resolve([manifest])



## Gets list of all gdtf fixtures in a folder
func _get_gdtf_list_from_folder(folder_path: String, p_get_info: bool = false) -> Dictionary:

	var access = DirAccess.open(folder_path)
	var i: int = 1
	var num_of_files: int = len(access.get_files())

	access.list_dir_begin()
	var file_name = access.get_next()
	var result: Dictionary = {
		"sorted": {},
		"files": {}
	}

	while file_name != "":
		if not access.current_is_dir() and file_name.ends_with(".gdtf"):
			var path: String = folder_path + "/" + file_name
			printraw(TF.auto_format(0, "\r", "Importing Fixture: ", i, "/", num_of_files))
			i += 1

			var info: Dictionary = _get_gdtf_info(path)
			if info:
				result.sorted.get_or_add(info.manufacturer, {})[info.name] = {
					"modes": info.modes,
					"path": folder_path,
					"file": file_name,
					"uuid": info.uuid
				}
				result.files[info.uuid] = path
	
			
			
		file_name = access.get_next()
	
	print()
	return result


## Returns a dictionary with the name, manufacturer, and quanti of modes from the given gdtf
func _get_gdtf_info(file_path: String) -> Dictionary:
	var result: Dictionary = {
		"name": "Unknown",
		"manufacturer": "Unknown",
		"modes": {},
		"uuid": ""
	}
	
	var x = _get_xml_reader(file_path)
	if not x:
		return {}
	
	var reader: ZIPReader = x[0]
	var parser: XMLParser = x[1]
	var current_mode: String = ""
	
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			match parser.get_node_name():
				"FixtureType":
					result.name = parser.get_named_attribute_value_safe("Name")
					result.manufacturer = parser.get_named_attribute_value_safe("Manufacturer")
					result.uuid = parser.get_named_attribute_value_safe("FixtureTypeID")
					
					# var thumnail: String = parser.get_named_attribute_value_safe("Thumbnail")
					# if reader.file_exists(thumnail + ".png") and import_images:
					# 	var image: Image = Image.new()
					# 	image.load_png_from_buffer(reader.read_file(thumnail + ".png"))
					# 	result.icon = image
					
				"DMXMode":
					current_mode = parser.get_named_attribute_value_safe("Name")
					result.modes[current_mode] = 0
				
				"DMXChannel":
					var offset_array: Array = parser.get_named_attribute_value_safe("Offset").split(",")
					if offset_array != [""]:
						result.modes[current_mode] = result.modes[current_mode] + len(offset_array)
	
	return result


## Internal wrapper function for thread execution
func _get_gdtf_from_file_path(file_path: String) -> Dictionary:
	var parser = _get_xml_reader(file_path)[1]
	var modes: Dictionary = {}
	
	var current_mode: String = "unknown"
	var current_geometry: String = ""
	var current_offset: Array[int] = []
	var current_logical_attribute: String = ""
	var current_channel_attribute: String = ""

	var previous_dmx_range: Array = []
	
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			match parser.get_node_name():
				"DMXMode":
					current_mode = parser.get_named_attribute_value_safe("Name")
					modes[current_mode] = {
						"name": current_mode,
						"channels": {},
						"dmx_length": 0
					}
				
				"DMXChannel":
					current_geometry = parser.get_named_attribute_value_safe("Geometry")

					current_offset = []
					previous_dmx_range = []

					var offsets: String = parser.get_named_attribute_value_safe("Offset")
					for offset: String in offsets.split(","):
						current_offset.append(int(offset))

					modes[current_mode].channels.get_or_add(current_geometry, {})
					modes[current_mode].dmx_length += len(current_offset)
					
				"LogicalChannel":
					current_logical_attribute = parser.get_named_attribute_value_safe("Attribute")
					modes[current_mode].channels.get_or_add(current_geometry, {})[current_logical_attribute] = {
						"attribute": current_logical_attribute,
						"offset": current_offset,
						"functions": {}
					}
				"ChannelFunction":
					current_channel_attribute = parser.get_named_attribute_value_safe("Attribute")
					var attribute: String = current_channel_attribute
					var i: int = 1
					while modes[current_mode].channels[current_geometry][current_logical_attribute].functions.has(attribute):
						attribute = current_channel_attribute + "_" + str(i)
						i += 1
					
					current_channel_attribute = attribute

					var dmx_from: int = int(parser.get_named_attribute_value_safe("DMXFrom").split("/")[0])
					var dmx_range: Array[int] = [dmx_from, [255, 65535, 16777215, 4294967295][len(current_offset) - 1]]

					if previous_dmx_range:
						previous_dmx_range[1] = dmx_from - 1
					previous_dmx_range = dmx_range
					
					modes[current_mode].channels[current_geometry][current_logical_attribute].functions[current_channel_attribute] = {
						"attribute": current_channel_attribute,
						"name": parser.get_named_attribute_value_safe("Name"),
						"default": int(parser.get_named_attribute_value_safe("Default").split("/")[0]),
						"dmx_range": dmx_range,
						"sets": []
					}
				"ChannelSet":
					modes[current_mode].channels[current_geometry][current_logical_attribute].functions[current_channel_attribute].sets.append({
						"from": parser.get_named_attribute_value_safe("DMXFrom"),
						"name": parser.get_named_attribute_value_safe("Name"),
					})
	
	return _separate_channels_by_zones(modes)


## separates all the channels from zones if they are not duplicates
func _separate_channels_by_zones(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	
	for mode: String in data:
		var mode_channels: Dictionary = data[mode].channels
		var all_attributes: Array[String] = []
		
		result[mode] = data[mode]
		result[mode].channels = {
			"root": {}
		}
		
		for geometry: String in mode_channels:
			all_attributes.append_array(mode_channels[geometry].keys())
		
		for geometry: String in mode_channels:
			for attribute: String in mode_channels[geometry]:
				if all_attributes.count(attribute) == 1:
					result[mode].channels["root"][attribute] = mode_channels[geometry][attribute]
				else:
					var new_geometry_name: String = geometry.capitalize().to_lower().replace(" ", "_")
					result[mode].channels.get_or_add(new_geometry_name, {})[attribute] = mode_channels[geometry][attribute]
	
	return result


## Returns a XMLParser for the given gdtf file path
func _get_xml_reader(file_path: String) -> Array[RefCounted]:
	var reader: ZIPReader = ZIPReader.new()
	var parser: XMLParser = XMLParser.new()
	
	if reader.open(file_path) == OK:
		parser.open_buffer(reader.read_file("description.xml"))
		return [reader, parser]
	else:
		return []
