# Copyright (c) 2025 Liam Sherwin. All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

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
var _manifest_importers: Dictionary[String, ManifestImport] = {
	"gdtf": GDTFImport.new()
}

## Global LTP layers for fixtures
var _global_ltp_layers: Dictionary[String, Variant]

## The SettingsManager
var settings_manager: SettingsManager = SettingsManager.new()


## init
func _init() -> void:
	settings_manager.set_owner(self)
	settings_manager.set_inheritance_array(["CoreFixtureLibrary"])
	settings_manager.register_networked_methods_auto([
		create_fixture,
		get_manifest,
		get_sorted_manifest_info,
		is_loaded,
	])

	settings_manager.set_method_allow_serialize(get_sorted_manifest_info)
	settings_manager.set_method_allow_serialize(get_manifest)


## Load the fixture manifests from the folders, buit in manifests will override user manifests
func _ready() -> void:
	await Core.ready

	_user_fixture_library_path = Core.get_data_folder() + "/fixtures"
	Utils.ensure_folder_exists(_user_fixture_library_path)

	for location: String in [_user_fixture_library_path, _built_in_library_path]:
		var manifests: Dictionary = _find_manifests(location)
		_found_manifest_info.merge(manifests.files, true)

		for manufacturer: String in manifests.sorted:
			_found_sorted_manifest_info.get_or_add(manufacturer, {}).merge(manifests.sorted[manufacturer], true)

	_resolve_requests()
	_is_loaded = true 
	manifests_found.emit()


## Creates a new fixture from a manifest
func create_fixture(p_manifest_uuid: String, p_universe: Universe, p_channel: int, p_quantity: int, p_offset: int, p_mode: String, p_name: String, p_increment_name: bool) -> void:
	var just_added_fixtures: Array[Fixture] = []
	var manifest: FixtureManifest = get_manifest(p_manifest_uuid)

	if manifest and manifest.has_mode(p_mode):
		var length: int = manifest.get_mode_length(p_mode)

		for i: int in range(p_quantity):

			var new_fixture: DMXFixture = DMXFixture.new()

			new_fixture.set_channel(p_channel + (length * i) + (p_offset * i))
			new_fixture.set_name(p_name + ((" " + str(i + 1)) if p_increment_name else ""))
			new_fixture.set_manifest(manifest, p_mode)

			just_added_fixtures.append(new_fixture)
	
	if just_added_fixtures:
		Core.add_components(just_added_fixtures)
		p_universe.add_fixtures(just_added_fixtures)


## Gets a manifest, imports it if its not already imported
func get_manifest(p_manifest_uuid: String) -> FixtureManifest:
	if _loaded_manifests.has(p_manifest_uuid):
		return _loaded_manifests[p_manifest_uuid]
	
	elif _found_manifest_info.has(p_manifest_uuid):
		var manifest_info: Dictionary = _found_manifest_info[p_manifest_uuid]

		if manifest_info.importer in _manifest_importers:
			var manifest: FixtureManifest = _manifest_importers[manifest_info.importer].load_from_file(manifest_info.file_path)
			_loaded_manifests[p_manifest_uuid] = manifest

			return manifest

	return null


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


## Check loaded state
func is_loaded() -> bool: 
	return _is_loaded


## Enabled LTP on a layer
func add_global_ltp_layer(p_layer_id: String) -> bool:
	if has_global_ltp_layer(p_layer_id):
		return false

	_global_ltp_layers[p_layer_id] = null
	return true


## Enabled LTP on a layer
func remove_global_ltp_layer(p_layer_id: String) -> bool:
	if not has_global_ltp_layer(p_layer_id):
		return false

	_global_ltp_layers.erase(p_layer_id)
	return true


## Enabled LTP on a layer
func has_global_ltp_layer(p_layer_id: String) -> bool:
	return _global_ltp_layers.has(p_layer_id)


## Finds all the fixture manifetsts in the folders
func _find_manifests(folder_path: String) -> Dictionary:	
	var access:DirAccess = DirAccess.open(folder_path)
	var index: int = 1
	var num_of_files: int = len(access.get_files())

	access.list_dir_begin()

	var file_name: String = access.get_next()
	var result: Dictionary = {
		"sorted": {},
		"files": {}
	}

	print()

	while file_name != "":
		var file_type: String = file_name.split(".")[-1]
		if not access.current_is_dir() and file_type in _manifest_importers.keys():
			var path: String = folder_path + "/" + file_name
			var manifest: Dictionary = _manifest_importers[file_type].get_info(path)

			manifest.importer = file_type
			manifest.file_path = path
			
			result.sorted.get_or_add(manifest.manufacturer, {})[manifest.name] = manifest
			result.files[manifest.uuid] = manifest

			printraw(TF.auto_format(0, "\r", "Imported Fixture (", file_type, "): ", index, "/", num_of_files))
			index += 1

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
