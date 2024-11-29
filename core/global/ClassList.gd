# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name ComponentClassList extends Node
## Contains a list of all the classes that can be networked, stored here so they can be found when deserializing a network request


## Contains all the classes in this engine, will merge component_class_table, function_class_table, and output_class_table
var global_class_table: Dictionary = {} : get = get_global_class_list


## Contains all the core component classes
var component_class_table: Dictionary = {
    "Universe": Universe,
    "Fixture": Fixture,
    "Programmer": Programmer,
}


## Contains all the function classes
var function_class_table: Dictionary = {
    "Scene": Scene,
    "CueList": CueList
}


## Contains all the output plugin classes
var output_class_table: Dictionary = {
    "ArtNetOutput": ArtNetOutput
}


## Returns component_class_table, function_class_table, and output_class_table merged into one 
func get_global_class_list() -> Dictionary:
    var merged_list = component_class_table.duplicate()
    merged_list.merge(function_class_table)
    merged_list.merge(output_class_table)
        
    return merged_list


## Returns the class names of all the functions
func get_function_classes() -> Array: return function_class_table.keys()

## Returns the class names of all the outputs
func get_output_classes() -> Array: return output_class_table.keys()
