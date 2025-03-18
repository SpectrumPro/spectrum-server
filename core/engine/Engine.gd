# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name CoreEngine extends Node
## The core engine that powers Spectrum


## Emited when components are added to this engine,
signal on_components_added(components: Array[EngineComponent])

## Emited when components are removed from this engine, 
signal on_components_removed(components: Array[EngineComponent])

## Emitted when this engine is resetting
signal on_resetting()

## Emited when the file name is changed
signal on_file_name_changed(file_name: String)

 ## Emited [member CoreEngine.call_interval] number of times per second.
signal _output_timer()


## Serialization mode, if set to network, components will save extra infomation that doesent need to be saved to disk
enum {SERIALIZE_MODE_DISK, SERIALIZE_MODE_NETWORK}


## Output frequency of this engine, defaults to 45hz. defined as 1.0 / desired frequency
var call_interval: float = 1.0 / 45.0 # 1 second divided by 45

var _accumulated_time: float = 0.0 ## Used as an internal refernce for timing call_interval correctly


## Root data folder
var data_folder := (OS.get_environment("USERPROFILE") if OS.has_feature("windows") else OS.get_environment("HOME")) + "/.spectrum"

## The location for storing all the save show files
var save_library_location: String = data_folder + "/saves"
var user_script_folder: String = data_folder + "/scripts"
var user_functions_folder: String = data_folder + "/functions"


## The name of the current save file
var _current_file_name: String = ""


var EngineConfig = {
	## Network objects will be auto added to the servers networked objects index
	"network_objects": [
		{
			"object": (self),
			"name": "engine"
		},
		{
			"object": (Programmer),
			"name": "Programmer"
		},
		{
			"object": Debug.new(),
			"name": "debug"
		},
		{
			"object": (FixtureLibrary),
			"name": "FixtureLibrary"
		},
		{
			"object": (ClassList),
			"name": "ClassList"
		},
	],
	## Root classes are the primary classes that will be seralized and loaded 
	"root_classes": [
		"Universe",
		"Function"
	]
}

func _ready() -> void:
	# Set low processor mode to true, to avoid using too much system resources 
	OS.set_low_processor_usage_mode(false)
	
	var script_child: Node = Node.new()
	script_child.name = "Scripts"
	add_child(script_child)

	reload_scripts()
	import_custom_functions()

	Details.print_startup_detils()
	Utils.ensure_folder_exists(save_library_location)

	_add_auto_network_classes.call_deferred()
	Server.start_server()

	print()

	var cli_args: PackedStringArray = OS.get_cmdline_args()

	if "--load" in cli_args:
		(func ():
			var name_index: int = cli_args.find("--load") + 1
			var save_name: String = cli_args[name_index]

			print(TF.auto_format(0, "Loading save file: ", save_name))

			load_from_file(save_name)
		).call_deferred()


	if "--tests" in cli_args:
		print("\nRunning Tests")
		var tester = Tester.new()
		tester.run(Tester.test_type.UNIT_TESTS)

		if not "--test-keep-alive" in cli_args:
			save.call_deferred("Test At: " + str(Time.get_datetime_string_from_system()), true)
			get_tree().quit.call_deferred()


	if "--tests-global" in cli_args:
		print("\nRunning Tests")
		var tester = Tester.new()
		tester.run(Tester.test_type.GLOBAL_TESTS)

		if not "--test-keep-alive" in cli_args:
			save.call_deferred("Global Test At: " + str(Time.get_datetime_string_from_system()), true)
			get_tree().quit.call_deferred()


	# if "--relay-server" in cli_args:
	# 	print(TF.auto_format(TF.AUTO_MODE.INFO, "Trying to connect to relay server"))

	# 	var ip_index: int = cli_args.find("--relay-server") + 1

	# 	if ip_index < cli_args.size() and cli_args[ip_index].is_valid_ip_address():
	# 		print(cli_args[ip_index])
	# 	else:
	# 		print(TF.auto_format(TF.AUTO_MODE.ERROR, "Unable to connect to relay server, invalid IP address"))

	# Extra start up code


func _add_auto_network_classes() -> void:
	for config: Dictionary in EngineConfig.network_objects:
		Server.add_networked_object(config.name, config.object)


func _process(delta: float) -> void:
	# Accumulate the time
	_accumulated_time += delta
	
	# Check if enough time has passed since the last function call
	if _accumulated_time >= call_interval:
		# Call the function
		_output_timer.emit()
		
		# Subtract the interval from the accumulated time
		_accumulated_time -= call_interval


## Serializes all elements of this engine, used for file saving, and network synchronization
func serialize(mode: int = SERIALIZE_MODE_NETWORK) -> Dictionary:
	var serialized_data: Dictionary = {
		"schema_version": Details.schema_version,
	}

	# Loops through all the classes we have been told to serialize
	for object_class_name: String in EngineConfig.root_classes:
		serialized_data[object_class_name] = {}
		# Add them into the serialized_data
		for component in ComponentDB.get_components_by_classname(object_class_name):
			serialized_data[object_class_name][component.uuid] = component.serialize(mode)
	
	if mode == SERIALIZE_MODE_NETWORK:
		serialized_data.file_name = get_file_name()
		
	return serialized_data


## Saves this engine to disk
func save(file_name: String = _current_file_name, autosave: bool = false) -> Error:
	
	if file_name:
		set_file_name(file_name)
		var file_path: String = (save_library_location + "/autosave") if autosave else save_library_location
		return Utils.save_json_to_file(file_path, file_name, serialize(SERIALIZE_MODE_DISK))

	else:
		print_verbose("save(): ", error_string(ERR_FILE_BAD_PATH))
		return ERR_FILE_BAD_PATH


## Get serialized data from a file, and load it into this engine
func load_from_file(file_name: String) -> void:
	var saved_file = FileAccess.open(save_library_location + "/" + file_name, FileAccess.READ)

	# Check for any open errors
	if not saved_file:
		print("Unable to open file: \"", file_name, "\", ", error_string(FileAccess.get_open_error()))
		return 
	
	var serialized_data: Dictionary = JSON.parse_string(saved_file.get_as_text())
	print_verbose(serialized_data)

	# Check for the schema_version of the save file, if it does not match, or is not present give a warning
	var schema_version: int = int(serialized_data.get("schema_version", 0))
	if schema_version:
		if schema_version != Details.schema_version:
			print(TF.auto_format(TF.AUTO_MODE.WARNING, TF.bold("WARNING:"), " Save file: \"", file_name, "\" Is schema version: ", schema_version, " How ever version: ", Details.schema_version, " Is expected. Errors may occur loading this file"))
	else:
		print(TF.auto_format(TF.AUTO_MODE.WARNING, TF.bold("WARNING:"), " Save file: \"", file_name, "\" Does not have a schema version. Errors may occur loading this file"))
	

	set_file_name(file_name)
	self.load(serialized_data) # Use self.load as load() is a gdscript global function


## Loads serialized data into this engine
func load(serialized_data: Dictionary) -> void:
	# Array to keep track of all the components that have just been added, allowing them all to be networked to the client in the same message
	var just_added_components: Array[EngineComponent] = []

	# Loops throught all the classes we have been told to seralize, and check if they are present in the saved data
	for object_class_name: String in EngineConfig.root_classes:
		for component_uuid: String in serialized_data.get(object_class_name, {}):
			var serialized_component: Dictionary = serialized_data[object_class_name][component_uuid]
		
			# Check if the components class name is a valid class type in the engine
			if ClassList.has_class(serialized_component.get("class_name", "")):
				var new_component: EngineComponent = ClassList.get_class_script(serialized_component.class_name).new(component_uuid)
				new_component.load(serialized_component)
				add_component(new_component, true)

				just_added_components.append(new_component)

	
	on_components_added.emit.call_deferred(just_added_components)


## Returnes all the saves files from the save library
func get_all_saves_from_library() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	var version_match: RegEx = RegEx.new()
	version_match.compile('"schema_version"\\s*:\\s*(\\d+)')
	
	for file_name in DirAccess.open(save_library_location).get_files():
		var path: String = save_library_location + "/" + file_name
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
	_current_file_name = p_file_name
	on_file_name_changed.emit(_current_file_name)


## Renames a save file
func rename_file(orignal_name: String, new_name: String) -> Error:
	var access: DirAccess = DirAccess.open(save_library_location)

	if access.file_exists(orignal_name):
		var err: Error = access.rename(orignal_name, new_name)

		if err == OK:
			access.remove(orignal_name)
		
			if orignal_name == get_file_name():
				set_file_name(new_name)

		return err
	
	else:
		return ERR_FILE_BAD_PATH


## Deletes a save file
func delete_file(file_name: String) -> Error:
	var access: DirAccess = DirAccess.open(save_library_location)

	if access.file_exists(file_name):
		return access.remove(file_name)
	
	else:
		return ERR_FILE_BAD_PATH


## Resets the engine, then loads from a save file:
func reset_and_load(file_name: String) -> void:
	reset()
	load_from_file(file_name)


## Resets the engine back to the default state
func reset() -> void:
	print("Performing Engine Reset!")

	on_resetting.emit()
	Server.disable_signals = true
	set_file_name("")

	# Make a backup of the current state
	save(Time.get_datetime_string_from_system(), true)

	for object_class_name: String in EngineConfig.root_classes:
		for component: EngineComponent in ComponentDB.get_components_by_classname(object_class_name):
			component.delete()
	
	Server.disable_signals = false


## (Re)loads all the user scripts
func reload_scripts() -> void:

	for old_child in $Scripts.get_children():
		$Scripts.remove_child(old_child)
		old_child.queue_free()

	# Loop through all the script files if any, and add them
	for script_name: String in get_scripts_from_folder(user_script_folder).keys():

		var node: Node = Node.new()
		var script: GDScript = load(user_script_folder + "/" + script_name)
		
		node.name = script_name.replace(".gd", "")
		node.set_script(script)
		$Scripts.add_child(node)
	

## Imports all the custon function types and adds them to the class list
func import_custom_functions() -> void:
	var scripts: Dictionary = get_scripts_from_folder(user_functions_folder)
	for script_name: String in scripts:
		var script: Script = scripts[script_name]
		ClassList.register_custom_class(["EngineComponent", "Function", script_name.replace(".gd", "")], script)


## Returns all the scripts in the given folder, stored as {"ScriptName": Script}
func get_scripts_from_folder(folder: String) -> Dictionary:
	Utils.ensure_folder_exists(folder)
	var script_files: PackedStringArray = DirAccess.get_files_at(folder)
	var scripts: Dictionary = {}

	# Loop through all the script files if any, and add them
	for file_name: String in script_files:
		if file_name.ends_with(".gd"):
			scripts[file_name] = load(folder + "/" + file_name)

	return scripts


## Creates and adds a new component using the classname to get the type, will return null if the class is not found
func create_component(classname: String, name: String = "") -> EngineComponent:
	if ClassList.has_class(classname):
		var new_component: EngineComponent = ClassList.get_class_script(classname).new()

		if name:
			new_component.name = name
		
		add_component(new_component)

		return new_component

	else:
		return null


## Adds a new component to this engine
func add_component(component: EngineComponent, no_signal: bool = false) -> EngineComponent:

	# Check if this component is not already apart of this engine
	if not component in ComponentDB.components.values():
		ComponentDB.register_component(component)

		component.on_delete_requested.connect(remove_component.bind(component), CONNECT_ONE_SHOT)

		if not no_signal:
			on_components_added.emit([component])
	
	else:
		print("Component: ", component.uuid, " is already in this engine")

	return component


## Adds mutiple components to this engine at once
func add_components(components: Array, no_signal: bool = false) -> Array[EngineComponent]:
	var just_added_components: Array[EngineComponent]

	# Loop though all the components requeted, and check there type
	for component in components:
		if component is EngineComponent:
			just_added_components.append(add_component(component, true))

	on_components_added.emit(just_added_components)

	return just_added_components


## Removes a universe from this engine, this will not delete the component.
func remove_component(component: EngineComponent, no_signal: bool = false) -> bool:
	# Check if this universe is part of this engine
	if component in ComponentDB.components.values():
		ComponentDB.deregister_component(component)
				
		if not no_signal:
			on_components_removed.emit([component])
	
		return true
	
	# If not return false
	else:
		print("Component: ", component.uuid, " is not part of this engine")
		return false


## Removes mutiple universes at once from this engine, this will not delete the components.
func remove_components(components: Array, no_signal: bool = false) -> void:
	var just_removed_components: Array = []
	
	for component in components:
		if component is EngineComponent:
			if remove_component(component, true):
				just_removed_components.append(component)
	
	if not no_signal and just_removed_components:
		on_components_removed.emit(just_removed_components)


## Creates a new Animator and adds it as a child node so it can process
func create_animator() -> Animator:
	var animator: Animator = Animator.new()
	add_child(animator)

	return animator


func _notification(what: int) -> void:
	# Uh Oh
	if what == NOTIFICATION_CRASH:
		print(TF.auto_format(TF.AUTO_MODE.ERROR, "OH SHIT!"))
		Details.shit()
		print()

		var file_name: String = "Crash Save on " + Time.get_date_string_from_system()
		print(TF.info("Attempting Autosave, Error Code: ", error_string(save(file_name, true))))
		print(TF.info("Saved as: \"", file_name, "\""))
