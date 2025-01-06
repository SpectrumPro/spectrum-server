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