# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name CoreFixtureLibrary extends Node
## The main fixture library used to manage fixture manifests



## Emitted when the manifests are found
signal manifests_found()



## File path for the built in fixture library
const _built_in_library_path: String = "res://core/fixtures/"

## File path for the user fixture library. This needs to be loaded after Core is ready, otherwise Core.data_folder will be invalid
var _user_fixture_library_path: String = ""


## All the current found manifests, { "manufacturer": { "name": FixtureManifest } }
var _found_sorted_manifest_info: Dictionary = {}

## All the current found manifests, { "manifest_uuid": FixtureManifest }
var _found_manifest_info: Dictionary = {}

## All loaded fixture manifests, { "manifest_uuid": FixtureManifest }
var _loaded_manifests: Dictionary = {}

## All the current requests for manifetst, used when fixtures are loaded before manifest importing
var _manifest_requests: Dictionary

## Loaded state
var _is_loaded: bool = false


## Contains all manifest importers keyed by the file extension 
var _manifest_importers: Dictionary = {
	"gdtf": GDTFImport.new()
}


## Load the fixture manifests from the folders, buit in manifests will override user manifests
func _ready() -> void:
	await Core.ready

	_user_fixture_library_path = Core.data_folder + "/fixtures"
	Utils.ensure_folder_exists(_user_fixture_library_path)

	for location: String in [_user_fixture_library_path, _built_in_library_path]:
		var manifests: Dictionary = _find_manifests(location)
		_found_manifest_info.merge(manifests.files, true)

		for manufacturer: String in manifests.sorted:
			_found_sorted_manifest_info.get_or_add(manufacturer, {}).merge(manifests.sorted[manufacturer], true)

	_resolve_requests()
	_is_loaded = true 
	manifests_found.emit()


## Returnes the sorted manifest info of all manifests found
func get_sorted_manifest_info() -> Dictionary:
	return _found_sorted_manifest_info.duplicate(true)


## Gets a manifest from a manifest uuid, return a promise 
func request_manifest(p_manifest_uuid: String) -> Promise:
	var promise: Promise = Promise.new()
	var manifest: FixtureManifest = get_manifest(p_manifest_uuid)

	if manifest:
		promise.auto_resolve([manifest])
	else:
		_manifest_requests.get_or_add(p_manifest_uuid, []).append(promise)

	return promise


## Gets a manifest, imports it if its not already imported
func get_manifest(p_manifest_uuid: String) -> FixtureManifest:
	if _loaded_manifests.has(p_manifest_uuid):
		return _loaded_manifests[p_manifest_uuid]
	
	elif _found_manifest_info.has(p_manifest_uuid):
		var manifest_info: FixtureManifest = _found_manifest_info[p_manifest_uuid]

		if manifest_info.importer in _manifest_importers:
			var manifest: FixtureManifest = (_manifest_importers[manifest_info.importer] as ManifestImport).load_from_file(manifest_info.file_path)
			_loaded_manifests[p_manifest_uuid] = manifest

			return manifest

	return null


## Check loaded state
func is_loaded() -> bool: 
	return _is_loaded


## Creates a new fixture from a manifest
func create_fixture(p_manifest_uuid: String, p_universe: Universe, p_config: Dictionary) -> void:
	var just_added_fixtures: Array[Fixture] = []
	var manifest: FixtureManifest = get_manifest(p_manifest_uuid)

	if manifest and manifest.has_mode(p_config.get("mode")):
		var length: int = manifest.get_mode_length(p_config.mode)

		for i: int in range(p_config.quantity):

			var new_fixture: DMXFixture = DMXFixture.new()

			new_fixture.set_channel(p_config.channel + (length * i) + (p_config.offset * i))
			new_fixture.set_name(p_config.name)
			new_fixture.set_manifest(manifest, p_config.mode)

			just_added_fixtures.append(new_fixture)
	
	if just_added_fixtures:
		p_universe.add_fixtures(just_added_fixtures)


## Finds all the fixture manifetsts in the folders
func _find_manifests(folder_path: String) -> Dictionary:
	# var user_library: Dictionary = _get_gdtf_list_from_folder(_user_fixture_library_path, true)
	# var built_in_libaray: Dictionary = _get_gdtf_list_from_folder(_built_in_library_path, true)

	# _sorted_fixture_manifests = user_library.sorted
	# _sorted_fixture_manifests.merge(built_in_libaray.sorted, true)

	# _fixture_manifests = user_library.files
	# _fixture_manifests.merge(built_in_libaray.files, true)
	
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
		var file_type: String = file_name.split(".")[-1]
		if not access.current_is_dir() and file_type in _manifest_importers.keys():
			var path: String = folder_path + "/" + file_name
			printraw(TF.auto_format(0, "\r", "Importing Fixture (", file_type, "): ", i, "/", num_of_files))
			i += 1

			var manifest: FixtureManifest =( _manifest_importers[file_type] as ManifestImport).get_info(path)
			manifest.importer = file_type
			manifest.file_path = path
			
			result.sorted.get_or_add(manifest.manufacturer, {})[manifest.name] = manifest
			result.files[manifest.uuid] = manifest

		file_name = access.get_next()
	
	print()
	return result


## Attempts to resolve all manifest requests
func _resolve_requests() -> void:
	for manifest_uuid: String in _manifest_requests.keys():
		var manifest: FixtureManifest = get_manifest(manifest_uuid)
		if manifest:
			
			for promise: Promise in _manifest_requests[manifest_uuid]:
				promise.resolve([manifest])
			
			_manifest_requests.erase(manifest_uuid)
