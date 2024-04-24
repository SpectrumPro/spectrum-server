# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name CoreEngine extends Node
## The core engine that powers Spectrum

signal on_universe_name_changed(universe: Universe, new_name: String) ## Emitted when any of the universes in this engine have there name changed
signal on_universes_added(universe: Array[Universe], all_uuids: Array[String])
signal on_universes_removed(universe_uuids: Array)
signal on_universe_selection_changed(selected_universes: Array)

signal on_fixture_name_changed(fixture: Fixture, new_name)
signal on_fixture_added(fixture: Array)
signal on_fixture_removed(fixture_uuid: Array)
signal on_fixture_selection_changed(selected_fixtures: Array)

signal on_scenes_added(scene: Array)
signal on_scenes_removed(scene_uuids: Array)

signal _output_timer() ## Emited [call_interval] number of times per second

var universes: Dictionary = {}
var fixtures: Dictionary = {}
var fixtures_definitions: Dictionary = {}
var scenes: Dictionary = {} 
var selected_fixtures: Array[Fixture] = []
var selected_universes: Array[Universe] = []

var input_plugins: Dictionary = {}
var output_plugins: Dictionary = {}

const fixture_path: String = "res://core/fixtures/"
# const input_plugin_path: String = "res://core/io_plugins/input_plugins/"
const output_plugin_path: String = "res://core/output_plugins/"

var current_file_name: String = ""
var current_file_path: String = ""

var programmer = Programmer.new()

var call_interval: float = 1.0 / 45.0  # 1 second divided by 45

var accumulated_time: float = 0.0

var object_test: RefCounted

func _ready() -> void:
	programmer.engine = self
	
	OS.set_low_processor_usage_mode(true)
	reload_io_plugins()
	reload_fixtures()

	Server.add_networked_object("engine", self)


func _process(delta: float) -> void:
	# Accumulate the time
	accumulated_time += delta
	
	# Check if enough time has passed since the last function call
	if accumulated_time >= call_interval:
		# Call the function
		_output_timer.emit()
		
		# Subtract the interval from the accumulated time
		accumulated_time -= call_interval


func serialize() -> Dictionary:
	var serialized_data: Dictionary = {}
	
	serialized_data.universes = serialize_universes()
	serialized_data.scenes = serialize_scenes()

	return serialized_data

#region Save Load
func save(file_name: String = current_file_name, file_path: String = current_file_name) -> Error:
	
	return Utils.save_json_to_file(file_path, file_name, serialize())


func load(file_path) -> void:
	## Loads a save file and deserialize the data
	
	var saved_file = FileAccess.open(file_path, FileAccess.READ)
	var serialized_data: Dictionary = JSON.parse_string(saved_file.get_as_text())
	
	## Loops through each universe in the save file (if any), and loads them into the engine
	for universe_uuid: String in serialized_data.get("universes", {}):
		var serialized_universe: Dictionary = serialized_data.universes[universe_uuid]
		
		var new_universe: Universe = new_universe(serialized_universe.name, false, serialized_universe, universe_uuid)
		universes[new_universe.uuid] = new_universe
	
	for scene_uuid: String in serialized_data.get("scenes", {}):
		var serialized_scene: Dictionary = serialized_data.scenes[scene_uuid]
		
		new_scene(Scene.new(), true, serialized_scene, scene_uuid)
		
		on_scenes_added.emit(scenes)
#endregion


#region Universes
func new_universe(name: String = "New Universe", no_signal: bool = false, serialised_data: Dictionary = {}, uuid: String = "") -> Universe:
	## Adds a new universe
	
	print("making new universe: ", name)

	var new_universe: Universe = Universe.new()
		
	if serialised_data:
		new_universe.load_from(serialised_data)
	else:
		new_universe.name = name
	
	if uuid:
		new_universe.uuid = uuid
	
	universes[new_universe.uuid] = new_universe

	if not no_signal:
		on_universes_added.emit([new_universe], universes.keys())
	
	_connect_universe_signals(new_universe)
	Server.add_networked_object(new_universe.uuid, new_universe)
	
	return new_universe


func _connect_universe_signals(universe: Universe):
	## Connects all the signals of the new universe to the signals of this engine
	
	universe.name_changed.connect(
		func(new_name: String): 
			on_universe_name_changed.emit(universe, new_name)
	)
	
	universe.fixture_name_changed.connect(
		func(fixture: Fixture, new_name: String):
			on_fixture_name_changed.emit(fixture, new_name)
	)
	
	universe.fixtures_added.connect(
		func(fixtures: Array[Fixture]):
			on_fixture_added.emit(fixtures)
	)
	
	universe.fixtures_deleted.connect(
		func(fixture_uuids: Array):
			on_fixture_removed.emit(fixture_uuids)
	)


func remove_universe(universe: Universe, no_signal: bool = false) -> bool: 
	## Removes a universe
	
	if universe in universes.values():
		
		universes.erase(universe.uuid)				
		if not no_signal:
			on_universes_removed.emit([universe.uuid])
		
		return true

	else:
		return false


func remove_universes(universes_to_remove: Array, no_signal: bool = false) -> void:
	## Removes mutiple universes at once
	
	print(universes_to_remove)
	print(universes)

	var uuids: Array = []
	
	for universe: Universe in universes_to_remove:
		if remove_universe(universe, true):
			uuids.append(universe.uuid)
		else:
			print("Universe: ", universe.uuid, " is not part of this engine")
		
	
	if not no_signal:
		on_universes_removed.emit(uuids)


func serialize_universes() -> Dictionary:
	## Serializes all universes and returnes them in a dictionary 
	
	var serialized_universes: Dictionary = {}
	
	for universe: Universe in universes.values():
		serialized_universes[universe.uuid] = universe.serialize()
		
	return serialized_universes


func select_universes(universes_to_select: Array, no_signal: bool = false) -> void:
	## Selects all the fixtures passed to this function
	
	for universe: Universe in universes_to_select:
		if universe not in selected_universes:
			selected_universes.append(universe)
			universe.set_selected(true)
	
	if not no_signal:
		on_universe_selection_changed.emit(selected_universes)


func set_universe_selection(universes_to_select: Array) -> void:
	## Changes the selection to be the universes passed to this function

	deselect_universes(selected_universes, true)
	select_universes(universes_to_select)


func deselect_universes(universes_to_deselect: Array, no_signal: bool = false) -> void:
	## Selects all the fixtures passed to this function
	
	for universe: Universe in universes_to_deselect.duplicate():
		if universe in selected_universes:
			selected_universes.erase(universe)
			universe.set_selected(false)
	
	if not no_signal:
		on_universe_selection_changed.emit(selected_universes)

#endregion


#region IO
func reload_io_plugins() -> void:
	## Loads all output plugins from the folder
	
	output_plugins = {}
	
	var output_plugin_folder : DirAccess = DirAccess.open(output_plugin_path)
	
	for plugin in output_plugin_folder.get_files():
		var uninitialized_plugin = ResourceLoader.load(output_plugin_path + plugin)
		
		var initialized_plugin: DataOutputPlugin = uninitialized_plugin.new()
		var plugin_name: String = initialized_plugin.name
		 
		if plugin_name in output_plugins.keys():
			continue
		
		# object_test = weakref(initialized_plugin)

		# _output_timer.connect(func(): print(object_test.get_reference_count()))


		output_plugins[plugin_name] = uninitialized_plugin
#endregion


#region Fixtures 


func reload_fixtures() -> void:
	## Loads fixture definition files from a folder
	
	fixtures_definitions = {}
	
	var access = DirAccess.open(fixture_path)
	
	for fixture_folder in access.get_directories():
		
		for fixture in access.open(fixture_path+"/"+fixture_folder).get_files():
			
			var manifest_file = FileAccess.open(fixture_path+fixture_folder+"/"+fixture, FileAccess.READ)
			var manifest = JSON.parse_string(manifest_file.get_as_text())
			
			manifest.info.file_path = fixture_path+fixture_folder+"/"+fixture
			
			if fixtures_definitions.has(manifest.info.brand):
				fixtures_definitions[manifest.info.brand][manifest.info.name] = manifest
			else:
				fixtures_definitions[manifest.info.brand] = {manifest.info.name:manifest}


func select_fixtures(fixtures: Array, no_signal: bool = false) -> void:
	## Selects all the fixtures passed to this function
	
	for fixture: Fixture in fixtures:
		if fixture not in selected_fixtures:
			selected_fixtures.append(fixture)
			fixture.set_selected(true)
	
	if not no_signal:
		on_fixture_selection_changed.emit(selected_fixtures)


func set_fixture_selection(fixtures: Array) -> void:
	## Changes the selection to be the fixtures passed to this function
	
	deselect_fixtures(selected_fixtures, true)
	select_fixtures(fixtures)

func deselect_fixtures(fixtures: Array, no_signal: bool = false) -> void:
	## Deselects all the fixtures pass to this function
	
	for fixture: Fixture in fixtures.duplicate():
		if fixture in selected_fixtures:
			selected_fixtures.erase(fixture)
			fixture.set_selected(false)
	
	if not no_signal:
		on_fixture_selection_changed.emit(selected_fixtures)
#endregion


#region Scenes

func new_scene(scene: Scene = Scene.new(), no_signal: bool = false, serialized_data: Dictionary = {}, uuid: String = "") -> Scene:
	## Adds a scene to this engine, creats a new one if none is passed
	
	if uuid:
		scene.uuid = uuid
	
	scene.engine = self
	
	if serialized_data:
		scene.load_from(serialized_data)
	
	
	scenes[scene.uuid] = scene
	
	if not no_signal:
		on_scenes_added.emit([scene])
	
	return scene


func remove_scenes(scenes_to_remove: Array, no_signal: bool = false) -> void:
	## Removes a scene from this engine
	
	var uuids: Array = []
	
	for scene: Scene in scenes_to_remove:
		uuids.append(scene.uuid)
		scenes.erase(scene.uuid)
		
		scene.delete()
		scene.free()
	
	
	if not no_signal:
		on_scenes_removed.emit(uuids)


func serialize_scenes() -> Dictionary:
	## Serializes all scenes and returnes them in a dictionary 
	
	var serialized_scenes: Dictionary = {}
	
	for scene: Scene in scenes.values():
		serialized_scenes[scene.uuid] = scene.serialize()
	
	return serialized_scenes


#endregion


func animate(function: Callable, from: Variant, to: Variant, duration: int) -> void:
	var animation = get_tree().create_tween()
	animation.tween_method(function, from, to, duration)
