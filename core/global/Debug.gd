# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name Debug extends RefCounted
## Used to debug the engine


var home_path: String = OS.get_environment("USERPROFILE") if OS.has_feature("windows") else OS.get_environment("HOME")
var debug_file_location: String = home_path + "/.spectrum/debug/"



func _init() -> void:
    if not DirAccess.dir_exists_absolute(debug_file_location):
        print(TF.auto_format(TF.AUTO_MODE.INFO, "The folder \"debug_file_location\" does not exist, creating one now, errcode: ", DirAccess.make_dir_recursive_absolute(debug_file_location)))


## Resets the engine
func reset() -> void:
    Core.reset()


## Quits the engine
func quit() -> void:
    Core.get_tree().quit()


## Crashes the engine
func crash() -> void:
    OS.crash("crash() function called")


## Dumps the Server's networked objects
func dump_networked_objects() -> String:
    var networked_objects: Dictionary = Server.get_networked_objects()

    var file_name: String = Time.get_datetime_string_from_system() + "_dumped_network_objects"
    Utils.save_json_to_file(debug_file_location, file_name, Utils.objects_to_uuids(networked_objects, true))

    return debug_file_location + file_name


## Dumps all fixture data to a files
func dump_fixture_data(fixture: Fixture) -> String:
    var path: String = debug_file_location + "fixture_" + fixture.uuid + "/"

    if fixture is DMXFixture:
        Utils.save_json_to_file(path, "_active_ltp_parameters", fixture._active_ltp_parameters)
        Utils.save_json_to_file(path, "_active_values", fixture._active_values)
        Utils.save_json_to_file(path, "_parameters", fixture._parameters)
        Utils.save_json_to_file(path, "_mapped_layers", fixture._mapped_layers)
        Utils.save_json_to_file(path, "_raw_layers", fixture._raw_layers)
        Utils.save_json_to_file(path, "_raw_override_layers", fixture._raw_override_layers)
        Utils.save_json_to_file(path, "_current", fixture._current)
        Utils.save_json_to_file(path, "_current_dmx", fixture._current_dmx)
        Utils.save_json_to_file(path, "_current_override", fixture._current_override)
        Utils.save_json_to_file(path, "_current_override_dmx", fixture._current_override_dmx)
        Utils.save_json_to_file(path, "_default", fixture._default)
    
    return path
