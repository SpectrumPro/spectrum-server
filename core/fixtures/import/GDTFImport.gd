# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name GDTFImport extends ManifestImport
## GDTF fixture import


## Stores all GDTF attributes and their corresponding category
static var parameter_infomation: Dictionary = {

}


func _init() -> void:
	parameter_infomation = type_convert(load("res://core/fixtures/import/GDTFSpecAttributes.json").data, TYPE_DICTIONARY)
	

## Loads a fixture manifest from the given file path
static func load_from_file(file_path: String) -> FixtureManifest:
	var parser = _get_xml_reader(file_path)[1]
	var manifest: FixtureManifest = FixtureManifest.new()
	
	var remove_number_regex := RegEx.new()
	remove_number_regex.compile("\\d+")  # Matches one or more digits

	var geometry_references: Dictionary = {}
	var c_geo_name: String
	var c_geo_ref_name: String
	var parameters_to_instance: Array

	var c_mode: String = "unknown"
	var c_geo: String = ""
	var c_offset: Array[int] = []
	var c_logical_attri: String = ""
	var c_channel_attri: String = ""

	var previous_dmx_range: Array = []

	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			match parser.get_node_name():
				"FixtureType":
					manifest.name = parser.get_named_attribute_value_safe("Name")
					manifest.manufacturer = parser.get_named_attribute_value_safe("Manufacturer")
					manifest.uuid = parser.get_named_attribute_value_safe("FixtureTypeID")
				
				"GeometryReference":
					c_geo_name = parser.get_named_attribute_value_safe("Geometry")
					c_geo_ref_name = parser.get_named_attribute_value_safe("Name")

					geometry_references.get_or_add(c_geo_name, {})[c_geo_ref_name] = 0

				"Break":
					geometry_references[c_geo_name][c_geo_ref_name] = int(parser.get_named_attribute_value_safe("DMXOffset"))

				"DMXMode":
					c_mode = parser.get_named_attribute_value_safe("Name")
					manifest.create_mode(c_mode, 0)
				
				"DMXChannel":
					c_geo = parser.get_named_attribute_value_safe("Geometry")

					c_offset = []
					previous_dmx_range = []

					var offsets: String = parser.get_named_attribute_value_safe("Offset")
					for offset: String in offsets.split(","):
						c_offset.append(int(offset))
					

					manifest.create_zone(c_mode, c_geo)
					manifest.set_mode_length(c_mode, manifest.get_mode_length(c_mode) + len(c_offset))
					
				"LogicalChannel":
					c_logical_attri = parser.get_named_attribute_value_safe("Attribute")
					manifest.add_parameter(c_mode, c_geo, c_logical_attri, c_offset)

					if c_geo in geometry_references:
						parameters_to_instance.append({
							"mode": c_mode,
							"zone": c_geo,
							"parameter": c_logical_attri,
						})

				"ChannelFunction":
					c_channel_attri = parser.get_named_attribute_value_safe("Attribute")
					var attribute: String = c_channel_attri
					var i: int = 1
					while manifest.has_function(c_mode, c_geo, c_logical_attri, attribute):
						attribute = c_channel_attri + "_" + str(i)
						i += 1
					
					c_channel_attri = attribute

					var dmx_from: int = int(parser.get_named_attribute_value_safe("DMXFrom").split("/")[0])
					var dmx_range: Array[int] = [dmx_from, [255, 65535, 16777215, 4294967295][len(c_offset) - 1]]

					if previous_dmx_range:
						previous_dmx_range[1] = dmx_from - 1
					previous_dmx_range = dmx_range
					
					manifest.add_parameter_function(
						c_mode, 
						c_geo, 
						c_logical_attri, 
						c_channel_attri,
						parser.get_named_attribute_value_safe("Name"),
						int(parser.get_named_attribute_value_safe("Default").split("/")[0]),
						dmx_range,
						parameter_infomation.get(remove_number_regex.sub(attribute, "", true), {}).get("can_fade", false),
						parameter_infomation.get(remove_number_regex.sub(attribute, "", true), {}).get("vdim_effected", false)
					)
				
				"ChannelSet":
					manifest.add_function_set(
						c_mode,
						c_geo,
						c_logical_attri,
						c_channel_attri,
						parser.get_named_attribute_value_safe("Name"),
						int(parser.get_named_attribute_value_safe("DMXFrom").split("/")[0])
					)

	for to_instance: Dictionary in parameters_to_instance:
		for to_zone: String in geometry_references[to_instance.zone]:
			manifest.duplicate_parameter(
				to_instance.mode, 
				to_instance.parameter, 
				to_instance.zone, 
				to_zone, 
				[geometry_references[to_instance.zone][to_zone]]
			)
		
		manifest.remove_parameter(to_instance.mode, to_instance.zone, to_instance.parameter)

	_separate_channels_by_zones(manifest)
	return manifest




## Returns a dictionary with the name, manufacturer, and quanti of modes from the given gdtf file path
static func get_info(file_path: String) -> FixtureManifest:
	var manifest: FixtureManifest = FixtureManifest.new()
	manifest.type = FixtureManifest.Type.Info
	manifest.uuid = "unknown"

	var x = _get_xml_reader(file_path)
	if not x:
		return manifest
	
	var reader: ZIPReader = x[0]
	var parser: XMLParser = x[1]
	var current_mode: String = ""
	
	while parser.read() != ERR_FILE_EOF:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			match parser.get_node_name():
				"FixtureType":
					manifest.name = parser.get_named_attribute_value_safe("Name")
					manifest.manufacturer = parser.get_named_attribute_value_safe("Manufacturer")
					manifest.uuid = parser.get_named_attribute_value_safe("FixtureTypeID")
					
				"DMXMode":
					current_mode = parser.get_named_attribute_value_safe("Name")
					manifest.create_mode(current_mode, 0)
				
				"DMXChannel":
					var offset_array: Array = parser.get_named_attribute_value_safe("Offset").split(",")
					if offset_array != [""]:
						manifest.set_mode_length(current_mode, manifest.get_mode_length(current_mode) + len(offset_array))
	
	return manifest



## Returns a XMLParser for the given gdtf file path
static func _get_xml_reader(file_path: String) -> Array[RefCounted]:
	var reader: ZIPReader = ZIPReader.new()
	var parser: XMLParser = XMLParser.new()
	
	if reader.open(file_path) == OK:
		parser.open_buffer(reader.read_file("description.xml"))
		return [reader, parser]
	else:
		return []


## Separates all the channels from zones if they are not duplicates
static func _separate_channels_by_zones(manifest: FixtureManifest) -> void:
	var remove_number_regex := RegEx.new()
	remove_number_regex.compile("\\d+")  # Matches one or more digits
	manifest._categorys.clear()
	
	for mode: String in manifest._modes.keys():
		var mode_data = manifest._modes[mode]
		var all_attributes: Array[String] = []
		
		var new_zones: Dictionary = {
			"root": {}
		}
		
		for zone: String in mode_data.zones.keys():
			all_attributes.append_array(mode_data.zones[zone].keys())
		
		for zone: String in mode_data.zones.keys():
			for attribute: String in mode_data.zones[zone].keys():
				var param_data: Dictionary = mode_data.zones[zone][attribute]
				var category: String = parameter_infomation.get(remove_number_regex.sub(attribute, "", true), {}).get("_feature", "").split(".")[0]
				
				if all_attributes.count(attribute) == 1:
					new_zones["root"][attribute] = param_data
					manifest._categorys.get_or_add(mode, {}).get_or_add("root", {})[attribute] = category
				else:
					var new_zone_name: String = zone.capitalize().to_lower().replace(" ", "_")
					if not new_zones.has(new_zone_name):
						new_zones[new_zone_name] = {}
					
					new_zones[new_zone_name][attribute] = param_data
					manifest._categorys.get_or_add(mode, {}).get_or_add(new_zone_name, {})[attribute] = category
					
					new_zones["root"][attribute] = param_data.duplicate()
					new_zones["root"][attribute].offsets = []
					
					manifest._categorys.get_or_add(mode, {}).get_or_add("root", {})[attribute] = category
		
		manifest._modes[mode].zones = new_zones

