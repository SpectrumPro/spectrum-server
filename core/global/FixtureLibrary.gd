# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name CoreFixtureLibrary extends Node
## The main fixture library used to manage fixture manifests


## Emitted when the manifests are loaded
signal manifests_loaded()


## File path for the built in fixture library
const built_in_library_path: String = "res://core/fixtures/"

## File path for the user fixture library
var user_fixture_library_path: String = Core.data_folder + "/fixtures/"

## All the current fixture definitions
var fixture_manifests: Dictionary = {}



## Loaded state
var _is_loaded: bool = false


func _ready() -> void:
	# Load the fixture definitions from the folders, buit in manifests will override user manifests
	fixture_manifests = get_fixture_definitions(user_fixture_library_path)
	fixture_manifests.merge(get_fixture_definitions(built_in_library_path), true)
	
	_is_loaded = true
	manifests_loaded.emit()


## Returns fixture definition files from the folder defined in [param folder]
func get_fixture_definitions(folder: String) -> Dictionary:
	
	var loaded_fixtures_definitions: Dictionary = {}
	
	var access = DirAccess.open(folder)
	
	if access:
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
func get_loaded_fixture_definitions() -> Dictionary:
	return fixture_manifests.duplicate(true)


## Check loaded state
func is_loaded() -> bool: return _is_loaded