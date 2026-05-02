# Copyright (c) 2026 Liam Sherwin. All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.0 or later.
# See the LICENSE file for details

class_name CoreEngine extends CoreGlobal
## The core engine that powers Spectrum


## Emited when components are added to this engine,
signal components_added(components: Array[EngineComponent])

## Emited when components are removed from this engine,
signal components_removed(components: Array[EngineComponent])

## Emitted when this engine is resetting
signal resetting()

## Emited when the file name is changed
signal file_name_changed(file_name: String)

## Emited [member CoreEngine.call_interval] number of times per second.
signal _output_timer()


## Output frequency of this engine, defaults to 45hz. defined as 1.0 / desired frequency
var _call_interval: float = 1.0 / 45.0 # 1 second divided by 45

## Used as an internal refernce for timing call_interval correctly
var _accumulated_time: float = 0.0 

## Root data folder
var _data_folder := (OS.get_environment("USERPROFILE") if OS.has_feature("windows") else OS.get_environment("HOME")) + "/.spectrum"

## The location for storing all the save show files
var _save_library_location: String = _data_folder + "/saves"

## The location for storing all the scripts
var _script_folder_location: String = _data_folder + "/scripts"

## The name of the current save file
var _current_file_name: String = ""

## The child node that contains all scripts
var _script_child: Node

## EngineConfig
var _config: EngineConfig


## Internal engine config options
class EngineConfig extends Object:
	## Network objects will be auto added to the servers networked objects index
	var network_objects: Array[Dictionary] = [
		{
			"object": (Core),
			"name": "engine"
		},
		{
			"object": (Programmer),
			"name": "Programmer"
		},
		{
			"object": (Debug),
			"name": "Debug"
		},
		{
			"object": (FixtureLibrary),
			"name": "FixtureLibrary"
		},
		{
			"object": (ComponentClassList),
			"name": "classlist"
		},
		#{
			#"object": (CIDManager),
			#"name": "CIDManager"
		#},
	]
	
	## Root classes are the primary classes that will be seralized and loaded 
	var root_classes: Array[String] = [
		"Fixture",
		"Universe",
		"Function",
		"FixtureGroup",
		"TriggerBlock"
	]



## Init
func _init(p_uuid: String = "", ...p_args: Array[Variant]) -> void:
	super._init(p_uuid, p_args)
	_set_class_name("CoreEngine")
	
	OS.set_low_processor_usage_mode(false)
	Details.print_startup_detils()
	
	_settings.register_networked_methods_auto([
		serialize,
		deserialize,
		save_to_file,
		load_from_file,
		reset_and_load,
		get_all_saves_from_library,
		get_file_name,
		set_file_name,
		rename_file,
		delete_file,
		reset,
		create_component,
		duplicate_component,
		add_component,
		add_components,
		remove_component,
		remove_components,
		get_data_folder,
	])

	_settings.register_networked_signals_auto([
		components_added,
		components_removed,
		resetting,
		file_name_changed,
	])
	
	_settings.set_method_allow_deserialize(add_component)
	_settings.set_method_allow_deserialize(add_components)
	_settings.set_signal_allow_serialize(components_added)

	Utils.ensure_folder_exists(_save_library_location)


## Ready
func _ready() -> void:
	_config = EngineConfig.new()

	Network.start_all()
	_reload_scripts()
	
	var local_node: ConstellationNode = Network.get_active_handler_by_name("Constellation").get_local_node()
	Log.set_instance_name(local_node.get_node_name())
	
	_add_auto_network_classes.call_deferred()

	var cli_args: PackedStringArray = OS.get_cmdline_args()
	if "--load" in cli_args:
		(func ():
			var name_index: int = cli_args.find("--load") + 1
			var save_name: String = cli_args[name_index]

			print("Loading save file: ", save_name)

			load_from_file(save_name)
		).call_deferred()


## Process
func _process(delta: float) -> void:
	# Accumulate the time
	_accumulated_time += delta

	# Check if enough time has passed since the last function call
	if _accumulated_time >= _call_interval:
		# Call the function
		_output_timer.emit()

		# Subtract the interval from the accumulated time
		_accumulated_time -= _call_interval


## Serializes all elements of this engine, used for file saving, and network synchronization
func serialize(p_flags: Data.SerializationFlags = Data.SerializationFlags.NONE) -> Dictionary:
	var serialized_data: Dictionary = {
		"schema_version": Details.schema_version,
	}

	# Loops through all the classes we have been told to serialize
	for object_class_name: String in _config.root_classes:
		serialized_data[object_class_name] = {}
		# Add them into the serialized_data
		for component in ComponentDB.get_components_by_classname(object_class_name):
			serialized_data[object_class_name][component.get_uuid()] = component.serialize(p_flags)

	if p_flags & Data.SerializationFlags.REALTIME:
		serialized_data.file_name = get_file_name()

	return serialized_data


## Loads serialized data into this engine
func deserialize(p_serialized_data: Dictionary, p_flags: Data.SerializationFlags) -> void:
	var just_added_components: Array[EngineComponent] = []
	
	for object_class_name: String in _config.root_classes:
		for component_uuid: String in p_serialized_data.get(object_class_name, {}):
			var serialized_component: Dictionary = p_serialized_data[object_class_name][component_uuid]
			var classname: String = type_convert(serialized_component.get("class_name", ""), TYPE_STRING)

			if not ComponentClassList.has_class(classname):
				continue
			
			var new_component: EngineComponent = ComponentClassList.get_class_script(serialized_component.class_name).new(component_uuid)
			new_component.deserialize(serialized_component, p_flags)

			if add_component(new_component, true):
				just_added_components.append(new_component)

	if just_added_components:
		components_added.emit.call_deferred(just_added_components)


## Saves this engine to disk
func save_to_file(p_file_name: String = _current_file_name, p_autosave: bool = false) -> Error:
	if p_file_name:

		if not p_autosave:
			set_file_name(p_file_name)
			
		var file_path: String = (_save_library_location + "/autosave") if p_autosave else _save_library_location
		return Utils.save_json_to_file(file_path, p_file_name, serialize())

	else:
		print_verbose("save(): ", error_string(ERR_FILE_BAD_PATH))
		return ERR_FILE_BAD_PATH


## Get serialized data from a file, and load it into this engine
func load_from_file(p_file_name: String) -> Error:
	var saved_file = FileAccess.open(_save_library_location + "/" + p_file_name, FileAccess.READ)

	# Check for any open errors
	if not saved_file:
		print("Unable to open file: \"", p_file_name, "\", ", error_string(FileAccess.get_open_error()))
		return FileAccess.get_open_error()

	var serialized_data: Dictionary = JSON.parse_string(saved_file.get_as_text())
	print_verbose(serialized_data)

	# Check for the schema_version of the save file, if it does not match, or is not present give a warning
	var schema_version: int = int(serialized_data.get("schema_version", 0))
	if schema_version:
		if schema_version != Details.schema_version:
			push_warning("Save file: \"", p_file_name, "\" Is schema version: ", schema_version, " How ever version: ", Details.schema_version, " Is expected. Errors may occur loading this file")
	else:
		push_warning("Save file: \"", p_file_name, "\" Does not have a schema version. Errors may occur loading this file")

	set_file_name(p_file_name)
	deserialize(serialized_data, Data.SerializationFlags.NONE)
	return OK


## Resets the engine, then loads from a save file:
func reset_and_load(p_file_name: String) -> void:
	reset()
	load_from_file(p_file_name)


## Returnes all the saves files from the save library
func get_all_saves_from_library() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	var version_match: RegEx = RegEx.new()
	version_match.compile('"schema_version"\\s*:\\s*(\\d+)')

	for file_name in DirAccess.open(_save_library_location).get_files():
		var path: String = _save_library_location + "/" + file_name
		var access: FileAccess = FileAccess.open(path, FileAccess.READ)

		if access:
			saves.append({
				"name": file_name,
				"modified": access.get_modified_time(path),
				"size": access.get_length(),
				"version": str(version_match.search(access.get_as_text()).get_string(1))
			})

	return saves


## Gets the current file name
func get_file_name() -> String:
	return _current_file_name


## Sets the current file name, this does not change the name of the file on disk, only in memory
func set_file_name(p_file_name: String) -> void:
	if p_file_name == _current_file_name:
		return
	
	_current_file_name = p_file_name
	file_name_changed.emit(_current_file_name)


## Renames a save file
func rename_file(p_orignal_name: String, p_new_name: String) -> Error:
	var access: DirAccess = DirAccess.open(_save_library_location)

	if access.file_exists(p_orignal_name):
		var err: Error = access.rename(p_orignal_name, p_new_name)

		if err == OK:
			access.remove(p_orignal_name)

			if p_orignal_name == get_file_name():
				set_file_name(p_new_name)

		return err

	else:
		return ERR_FILE_BAD_PATH


## Deletes a save file
func delete_file(p_file_name: String) -> Error:
	var access: DirAccess = DirAccess.open(_save_library_location)

	if access.file_exists(p_file_name):
		return access.remove(p_file_name)

	else:
		return ERR_FILE_BAD_PATH


## Resets the engine back to the default state
func reset() -> void:
	print("Performing Engine Reset!")
	save_to_file(Time.get_datetime_string_from_system(), true)

	resetting.emit()
	set_file_name("")

	for object_class_name: String in _config.root_classes:
		for component: EngineComponent in ComponentDB.get_components_by_classname(object_class_name):
			component.delete()


## Creates and adds a new component using the classname to get the type, will return null if the class is not found
func create_component(p_classname: String, p_name: String = "") -> EngineComponent:
	if ComponentClassList.has_class(p_classname):
		var new_component: EngineComponent = ComponentClassList.get_class_script(p_classname).new()

		if p_name:
			new_component.set_name(p_name)

		if add_component(new_component):
			return new_component
		
		else:
			return null

	else:
		return null


## Duplicates a component
func duplicate_component(p_component: EngineComponent) -> EngineComponent:
	if not ComponentClassList.has_class(p_component.classname()):
		return null
	
	var new_component: EngineComponent = ComponentClassList.get_class_script(p_component.classname()).new()
	new_component.load(p_component.serialize(Data.SerializationFlags.NO_UUID))

	if add_component(new_component):
		return new_component
	
	else:
		return null


## Adds a new component to this engine
func add_component(p_component: EngineComponent, p_no_signal: bool = false) -> bool:
	if ComponentDB.has_component(p_component, false):
		return false
	
	ComponentDB.register_component(p_component)
	
	if not p_no_signal:
		components_added.emit([p_component])
	
	return true


## Adds mutiple components to this engine at once
func add_components(p_components: Array, p_no_signal: bool = false) -> Array[EngineComponent]:
	var just_added_components: Array[EngineComponent]

	# Loop though all the components requeted, and check there type
	for component in p_components:
		if component is EngineComponent and add_component(component, true):
			just_added_components.append(component)

	if not p_no_signal and just_added_components:
		components_added.emit(just_added_components)

	return just_added_components


## Removes a universe from this engine, this will not delete the component.
func remove_component(p_component: EngineComponent, p_no_signal: bool = false) -> bool:
	if not ComponentDB.has_component(p_component, false):
		return false
	
	ComponentDB.deregister_component(p_component)
	
	if not p_no_signal:
		components_removed.emit([p_component])
	
	return true


## Removes mutiple universes at once from this engine, this will not delete the components.
func remove_components(p_components: Array, p_no_signal: bool = false) -> void:
	var just_removed_components: Array = []

	for component in p_components:
		if component is EngineComponent and remove_component(component, true):
				just_removed_components.append(component)

	if not p_no_signal and just_removed_components:
		components_removed.emit(just_removed_components)


## Creates a new Animator and adds it as a child node so it can process
func create_animator() -> Animator:
	var animator: Animator = Animator.new()
	add_child(animator)

	return animator


## Enables process frame on a component
func set_component_process(component: EngineComponent, process: bool) -> void:
	if process and get_tree().process_frame.is_connected(component._process):
		get_tree().process_frame.connect(component._process)

	elif not process and not get_tree().process_frame.is_connected(component._process):
		get_tree().process_frame.disconnect(component._process)


## Gets the system data folder
func get_data_folder() -> String:
	return _data_folder


## Adds all objects from _config.network_objects to the Network
func _add_auto_network_classes() -> void:
	for config: Dictionary in _config.network_objects:
		Network.register_network_object(config.name, config.object.get("_settings"))


## (Re)loads all the user scripts
func _reload_scripts() -> void:
	if is_instance_valid(_script_child):
		for script_node: Node in _script_child.get_children():
			script_node.queue_free()
		
		remove_child(_script_child)
	
	_script_child = Node.new()
	_script_child.name = "Scripts"
	add_child(_script_child)

	# Loop through all the script files if any, and add them
	for script_name: String in Utils.get_scripts_from_folder(_script_folder_location).keys():

		var node: Node = Node.new()
		var script: GDScript = load(_script_folder_location + "/" + script_name)

		node.name = script_name.replace(".gd", "")
		node.set_script(script)
		_script_child.add_child(node)


## Uh Oh
func _notification(what: int) -> void:
	if what == NOTIFICATION_CRASH:
		printerr("OH SHIT!")
		Details.shit()
		print()

		var file_name: String = "Crash Save on " + Time.get_date_string_from_system()
		print("Attempting Autosave, Error Code: ", error_string(save_to_file(file_name, true)))
		print("Saved as: \"", file_name, "\"")
