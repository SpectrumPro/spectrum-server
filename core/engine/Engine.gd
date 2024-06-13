# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name CoreEngine extends Node
## The core engine that powers Spectrum


# SIGNALS:
# Emitted when things happen in this engine, or in the Universes, Fixtures, Scenes ect... that are apart of it 

## Emitted when any of the universes in this engine have there name changed
signal on_universe_name_changed(universe: Universe, new_name: String) 

## Emited when a universe / universes are added to this engine, contains a list of all universe uuids for server-client synchronization
signal on_universes_added(universes: Array[Universe], universe_uuids: Array[String]) 

## Emited when a universe / universes are removed from this engine, contains a list of all universe uuids for server-client synchronization
signal on_universes_removed(universes: Array[Universe], universe_uuids: Array[String])


## Emitted when any of the fixtures in any of the universes in this engine have there name changed
signal on_fixture_name_changed(fixture: Fixture, new_name: String) 

## Emited when a fixture / fixtures are added to any of the universes in this engine, contains a list of all fixture uuids for server-client synchronization
signal on_fixtures_added(fixtures: Array[Fixture], fixture_uuids: Array[String])

## Emited when a fixture / fixtures are removed from any of the universes in this engine, contains a list of all fixture uuids for server-client synchronization
signal on_fixtures_removed(fixtures: Array[Fixture], fixture_uuids: Array[String])


## Emited when a scene / scenes are added to this engine, contains a list of all scene uuids for server-client synchronization
signal on_scenes_added(scenes: Array[Scene], scene_uuids: Array[String])

## Emited when a scene / scenes are removed from this engine, contains a list of all scene uuids for server-client synchronization
signal on_scenes_removed(scenes: Array[Scene], scene_uuids: Array[String])

## Emitted when a scene has its name changed, contains a list of all scene uuids for server-client synchronization
signal on_scene_name_changed(scene: Scene, new_name: String, scene_uuids: Array[String]) 


## Emited when a CueList / CueLists are added to this engine, contains a list of all CueList uuids for server-client synchronization
signal on_cue_lists_added(scenes: Array[Scene], scene_uuids: Array[String])

## Emited when a CueList / CueLists are removed from this engine, contains a list of all CueList uuids for server-client synchronization
signal on_cue_lists_removed(scenes: Array[Scene], scene_uuids: Array[String])


signal _output_timer() ## Emited [member CoreEngine.call_interval] number of times per second.


# OBJECT DICTIONARIES
# Used to store all the objects (Universes, Fixtures, Scens, ect...) in this engine

## Dictionary containing all universes in this engine, do not modify this at runtime unless you know what you are doing, instead call [method CoreEngine.add_universe]
var universes: Dictionary = {} 

## Dictionary containing all fixtures in this engine, do not modify this at runtime unless you know what you are doing, instead call [method CoreEngine.add_fixture]
var fixtures: Dictionary = {} 

## Dictionary containing all scenes in this engine, do not modify this at runtime unless you know what you are doing, instead call [method CoreEngine.add_scene]
var scenes: Dictionary = {}

## Dictionary containing all cue lists in this engine, do not modify this at runtime unless you know what you are doing, instead call [method CoreEngine.add_cue_list]
var cue_lists: Dictionary = {}


## Dictionary containing fixture definiton file, stored in [member CoreEngine.fixture_path]
var fixtures_definitions: Dictionary = {} 

## Dictionary containing all of the output plugins, sotred in [member CoreEngine.output_plugin_path]
var output_plugins: Dictionary = {}


# TIMING VALUES:
# Used to set the process frequency of this engine, and all the objects that are apart of it

## Output frequency of this engine, defaults to 45hz. defined as 1.0 / desired frequency
var call_interval: float = 1.0 / 45.0  # 1 second divided by 45

var _accumulated_time: float = 0.0 ## Used as an internal refernce for timing call_interval correctly


## SIGNAL CONNECTIONS:
## Folowing functions are for connecting universe signals to engine signals, they are defined as vairables so they can be dissconnected when universe is to be deleted
func _universe_on_name_changed(new_name: String, universe: Universe): 
	on_universe_name_changed.emit(universe, new_name)
	

func _universe_on_fixture_name_changed(fixture: Fixture, new_name: String):
	on_fixture_name_changed.emit(fixture, new_name)


func _universe_on_fixtures_added(p_fixtures: Array[Fixture], fixture_uuids: Array):
	for fixture: Fixture in p_fixtures:
		fixtures[fixture.uuid] = fixture

	on_fixtures_added.emit(p_fixtures, fixtures.keys())

func _universe_on_fixtures_removed(p_fixtures: Array, fixture_uuids: Array):
	for fixture: Fixture in p_fixtures:
		fixtures.erase(fixture.uuid)

	on_fixtures_removed.emit(p_fixtures, fixtures.keys())

## Stores callables that are connected to universe signals [br]
## When connecting [member Engine._universe_on_name_changed] to the universe, you need to bind the universe object to the callable, using _universe_on_name_changed.bind(universe) [br]
## how ever this has the side effect of creating new refernce and can cause a memory leek, as universes will not be freed [br]
## To counter act this, _universe_signal_connections stored as Universe:Dictionary{"callable": Callable}. Stores the copy of [member Engine._universe_on_name_changed] that is returned when it is .bind(universe) [br]
## This allows the callable to be dissconnected from the universe, and freed from memory
var _universe_signal_connections: Dictionary = {}


## Folowing functions are for connecting Scene signals to Engine signals, they are defined as vairables so they can be dissconnected when scenes are to be deleted
func _scene_on_name_changed(new_name: String, scene: Scene) -> void:
	on_scene_name_changed.emit(scene, new_name)


## See _universe_signal_connections for details
var _scene_signal_connections: Dictionary = {}


# FILE PATHS:
# File paths for stoage in the engine

var home_path := OS.get_environment("USERPROFILE") if OS.has_feature("windows") else OS.get_environment("HOME")
## The location for storing all the save show files
var show_library_location: String = home_path + "/.spectrum/Show Library"

## The main programmer for this engine, mutiple can be created, how ever this one is made automaticaly for clients to use
var programmer: Programmer = Programmer.new()

## File path for fixture definitons
const fixture_path: String = "res://core/fixtures/" 

## File path for output plugin definitons
const output_plugin_path: String = "res://core/output_plugins/" 


func _ready() -> void:	
	# Set low processor mode to true, to avoid using too much system resources 
	OS.set_low_processor_usage_mode(false)
	
	if not DirAccess.dir_exists_absolute(show_library_location):
		print("The folder \"show_library_location\" does not exist, creating one now, errcode: ", DirAccess.make_dir_absolute(show_library_location))

	# Load io plugins and fixtures
	output_plugins = get_io_plugins(output_plugin_path)
	fixtures_definitions = get_fixture_definitions(fixture_path)

	# Add self to networked objects to allow for client to server comunication
	Server.add_networked_object("engine", self)

	Server.add_networked_object("programmer", programmer)


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
func serialize() -> Dictionary:
	return {
		"universes": serialize_universes(),
		"scenes": serialize_scenes(),
		"cue_lists": serialize_cue_lists()
	}


## Saves this engine to disk
func save(file_name: String = "", autosave: bool = false) -> void:
	
	if file_name:
		var file_path: String = (show_library_location + "/autosave") if autosave else show_library_location
		print(Utils.save_json_to_file(file_path, file_name, serialize()))


## Get serialized data from a file, and load it into this engine
func load_from_file(file_name: String) -> void:
	var saved_file = FileAccess.open(show_library_location + "/" + file_name, FileAccess.READ)

	if not saved_file:
		print("Unable to open file: \"", file_name, "\", ",  error_string(FileAccess.get_open_error()))
		return
	
	var serialized_data: Dictionary = JSON.parse_string(saved_file.get_as_text())

	print(serialized_data)

	self.load(serialized_data) # Use self.load as load() is a gdscript global function


## Loads serialized data into this engine
func load(serialized_data: Dictionary) -> void:


	# Loops through each universe in the save file (if any), and adds them into the engine
	for universe_uuid: String in serialized_data.get("universes", {}):
		var new_universe: Universe = Universe.new(universe_uuid)

		add_universe("New Universe", new_universe)
		new_universe.load(serialized_data.universes[universe_uuid])

	
	# Loops through each scene in the save file (if any), and adds them into the engine
	for scene_uuid: String in serialized_data.get("scenes", {}):
		var new_scene: Scene = Scene.new(scene_uuid)

		add_scene(new_scene)
		new_scene.load(serialized_data.scenes[scene_uuid])

	# Loops through each of the cue lists in the save file (if any), and adds them into the engine
	for cue_list_uuid: String in serialized_data.get("cue_lists", {}):
		var new_cue_list: CueList = CueList.new(cue_list_uuid)

		add_cue_list("New Cue List", new_cue_list)
		new_cue_list.load(serialized_data.cue_lists[cue_list_uuid])


## Resets the engine back to the default state
func reset() -> void:
	save(Time.get_datetime_string_from_system(), true)
	
	remove_universes(universes.values())
	remove_scenes(scenes.values())
	remove_cue_lists(cue_lists.values())


func get_all_shows_from_library() -> Array[String]:

	var shows: Array[String] = []

	for file_name in DirAccess.open(show_library_location).get_files():
		shows.append(file_name)

	return shows

## Adds a new universe to this engine, if [param universe] is defined, it will be added, if no universe is defined, one will be created with the name passed
func add_universe(name: String = "New Universe", universe: Universe = null, no_signal: bool = false) -> Universe:
	
	# if universe is not defined, create a new one, and set its name to be the name passed to this function
	if not universe:
		universe = Universe.new()
		universe.name = name	
	
	if not universe.uuid in universes:

		universes[universe.uuid] = universe	
		
		_connect_universe_signals(universe)	
		
		Server.add_networked_object(universe.uuid, universe, universe.on_delete_requested) # Add this new universe to networked objects, to allow it to be controled remotley
		
		if not no_signal:
			on_universes_added.emit([universe], universes.keys())
	
	else:
		print("Universe: ", universe.uuid, " is already in this engine")

	return universe


## Adds mutiple universes to this engine at once, [param universes_to_add] can be a array of [Universe]s or a array of [param n] length, where [param n] is the number of universes to be added
func add_universes(universes_to_add: Array, no_signal: bool = false) -> Array[Universe]:

	var just_added_universes: Array = []

	for item in universes_to_add:
		if item is Universe:
			just_added_universes.append(add_universe("", item, true))
		else:
			just_added_universes.append(add_universe("New Universe", Universe.new(), true))

	on_universes_added.emit(just_added_universes, universes.keys())

	return just_added_universes


## Connects all the signals of the new universe to the signals of this engine
func _connect_universe_signals(universe: Universe):
	
	print("Connecting Signals")

	_universe_signal_connections[universe] = {
		"_universe_on_name_changed": _universe_on_name_changed.bind(universe),
		"remove_universe": remove_universe.bind(universe, false, false)
		}

	universe.on_name_changed.connect(_universe_signal_connections[universe]._universe_on_name_changed)

	universe.on_delete_requested.connect(_universe_signal_connections[universe].remove_universe)
	

	universe.on_fixture_name_changed.connect(_universe_on_fixture_name_changed)
	
	universe.on_fixtures_added.connect(_universe_on_fixtures_added)
	
	universe.on_fixtures_removed.connect(_universe_on_fixtures_removed)



## Disconnects all the signals of the universe to the signals of this engine
func _disconnect_universe_signals(universe: Universe):
	
	print("Disconnecting Signals")

	universe.on_name_changed.disconnect(_universe_signal_connections[universe]._universe_on_name_changed)
	
	universe.on_delete_requested.disconnect(_universe_signal_connections[universe].remove_universe)


	universe.on_fixture_name_changed.disconnect(_universe_on_fixture_name_changed)
	
	universe.on_fixtures_added.disconnect(_universe_on_fixtures_added)
	
	universe.on_fixtures_removed.disconnect(_universe_on_fixtures_removed)


	_universe_signal_connections[universe] = {}
	_universe_signal_connections.erase(universe)

## Removes a universe from this engine
func remove_universe(universe: Universe, no_signal: bool = false, delete_object: bool = true) -> bool: 
		
	# Check if this universe is part of this engine
	if universe in universes.values():
		universes.erase(universe.uuid)
		
		_disconnect_universe_signals(universe)		
		
		if not no_signal:
			on_universes_removed.emit([universe])

		if delete_object:
			universe.delete()		
		
		return true
	
	# If not return false
	else:
		print("Universe: ", universe.uuid, " is not part of this engine")
		return false


## Removes mutiple universes at once from this engine
func remove_universes(universes_to_remove: Array, no_signal: bool = false, delete_object: bool = true) -> void:

	var just_removed_universes: Array = []
	
	for universe: Universe in universes_to_remove:
		if remove_universe(universe, true, delete_object):
			just_removed_universes.append(universe)		
	
	if not no_signal and just_removed_universes:
		on_universes_removed.emit(just_removed_universes)


## Serializes all universes and returnes them in a dictionary 
func serialize_universes() -> Dictionary:
	
	var serialized_universes: Dictionary = {}
	
	for universe: Universe in universes.values():
		serialized_universes[universe.uuid] = universe.serialize()
		
	return serialized_universes


## Returns all output plugins into a dictionary containing the uninitialized object, from the folder defined in [param folder]
func get_io_plugins(folder: String) -> Dictionary:
	
	var uninitialized_output_plugins: Dictionary = {}
	
	var output_plugin_folder : DirAccess = DirAccess.open(folder)
	
	for plugin in output_plugin_folder.get_files():
		var uninitialized_plugin = ResourceLoader.load(folder + plugin)

		uninitialized_output_plugins[plugin] = uninitialized_plugin
	
	return uninitialized_output_plugins


## Returns fixture definition files from the folder defined in [param folder]
func get_fixture_definitions(folder: String) -> Dictionary:
	
	var loaded_fixtures_definitions: Dictionary = {}
	
	var access = DirAccess.open(folder)
	
	for fixture_folder in access.get_directories():
		
		for fixture in access.open(folder+"/"+fixture_folder).get_files():
			
			var manifest_file = FileAccess.open(folder+fixture_folder+"/"+fixture, FileAccess.READ)
			var manifest = JSON.parse_string(manifest_file.get_as_text())
			
			manifest.info.manifest_path = fixture_folder+"/"+fixture
			
			if loaded_fixtures_definitions.has(fixture_folder):
				loaded_fixtures_definitions[fixture_folder][fixture] = manifest
			else:
				loaded_fixtures_definitions[fixture_folder] = {fixture:manifest}

	return loaded_fixtures_definitions


## Returnes all currently loaded fixture definitions
func get_loaded_fixtures_definitions() -> Dictionary:
	return fixtures_definitions


## Returns serialised version of all the fixtures in this universe
func serialize_fixtures() -> Dictionary:
	var serialized_fixtures: Dictionary = {}

	for fixture: Fixture in fixtures.values():
		serialized_fixtures[fixture.uuid] = fixture.serialize()
	
	return serialized_fixtures



func add_scene(scene: Scene = Scene.new(), no_signal: bool = false) -> Scene:
	## Adds a scene to this engine, creats a new one if none is passed
	if not scene.uuid in scenes:

		scenes[scene.uuid] = scene
		
		Server.add_networked_object(scene.uuid, scene, scene.on_delete_requested)

		_connect_scene_signals(scene)

		if not no_signal:
			on_scenes_added.emit([scene], scenes.keys())

	else:
		print("Scene: ", scene.uuid, " is already in this engine")

	return scene


func _connect_scene_signals(scene: Scene) -> void:
	_scene_signal_connections[scene] = {
		"_scene_on_name_changed": _scene_on_name_changed.bind(scene),
		"_remove_scenes": remove_scenes.bind([scene])
		}
	
	scene.on_name_changed.connect(_scene_signal_connections[scene]._scene_on_name_changed)
	scene.on_delete_requested.connect(_scene_signal_connections[scene]._remove_scenes)



func _disconnect_scene_signals(scene: Scene) -> void:
	
	scene.on_name_changed.disconnect(_scene_signal_connections[scene]._scene_on_name_changed)
	scene.on_delete_requested.disconnect(_scene_signal_connections[scene]._remove_scenes)
	
	_scene_signal_connections[scene] = {}
	_scene_signal_connections.erase(scene)


## Removes a scene from this engine
func remove_scene(scene: Scene, no_signal: bool = false, delete_object: bool = true) -> bool:
	
	# Check if this scene is part of this engine
	if scene in scenes.values():
		
		scenes.erase(scene.uuid)	

		_disconnect_scene_signals(scene)

		if not no_signal:
			on_scenes_removed.emit([scene])

		if delete_object:
			scene.delete()	

		return true
	
	# If not return false
	else:
		print("Scene: ", scene.uuid, " is not part of this engine")
		return false


## Removes mutiple scenes from this engine
func remove_scenes(scenes_to_remove: Array, no_signal: bool = false, delete_object: bool = true) -> void:
	
	var just_removed_scenes: Array = []
	
	for scene: Scene in scenes_to_remove:
		if remove_scene(scene, true, delete_object):
			just_removed_scenes.append(scene)
	
	if not no_signal:
		on_scenes_removed.emit(just_removed_scenes)
	


## Serializes all scenes and returnes them in a dictionary 
func serialize_scenes() -> Dictionary:
	
	var serialized_scenes: Dictionary = {}
	
	for scene: Scene in scenes.values():
		serialized_scenes[scene.uuid] = scene.serialize()
	
	return serialized_scenes


func add_cue_list(name: String = "New Cue List", cue_list: CueList = CueList.new(), no_signal: bool = false) -> CueList:
	## Adds a cue_list to this engine, creats a new one if none is passed
	if not cue_list.uuid in cue_lists:

		cue_lists[cue_list.uuid] = cue_list
		
		Server.add_networked_object(cue_list.uuid, cue_list, cue_list.on_delete_requested)

		if not no_signal:
			on_cue_lists_added.emit([cue_list], cue_lists.keys())

	else:
		print("CueList: ", cue_list.uuid, " is already in this engine")

	return cue_list


## Removes a cue_list from this engine
func remove_cue_list(cue_list: CueList, no_signal: bool = false, delete_object: bool = true) -> bool:
	
	# Check if this cue_list is part of this engine
	if cue_list in cue_lists.values():
		
		cue_lists.erase(cue_list.uuid)	

		if not no_signal:
			on_cue_lists_removed.emit([cue_list])

		if delete_object:
			cue_list.delete()	

		return true
	
	# If not return false
	else:
		print("CueList: ", cue_list.uuid, " is not part of this engine")
		return false


## Removes mutiple cue_lists from this engine
func remove_cue_lists(cue_lists_to_remove: Array, no_signal: bool = false, delete_object: bool = true) -> void:
	
	var just_removed_cue_lists: Array = []
	
	for cue_list: CueList in cue_lists_to_remove:
		if remove_cue_list(cue_list, true, delete_object):
			just_removed_cue_lists.append(cue_list)
	
	if not no_signal:
		on_cue_lists_removed.emit(just_removed_cue_lists)
	


## Serializes all cue_lists and returnes them in a dictionary 
func serialize_cue_lists() -> Dictionary:
	
	var serialized_cue_lists: Dictionary = {}
	
	for cue_list: CueList in cue_lists.values():
		serialized_cue_lists[cue_list.uuid] = cue_list.serialize()
	
	return serialized_cue_lists


## Creates a new Animator and adds it as a child node so it can process
func create_animator() -> Animator:
	var animator: Animator = Animator.new()
	add_child(animator)

	return animator
