# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name ComponentClassList extends Node
## Contains a list of all the classes that can be networked, stored here so they can be found when deserializing a network request


## Contains all the classes sorted by the system hierarchy tree
var _global_class_tree: Dictionary = {
	"EngineComponent": {
		"DataContainer": {
			"Cue": Cue,
			"DataContainer": DataContainer,
			"DataPaletteItem": DataPaletteItem,
		},
		"Fixture": {
			"Fixture": Fixture,
			"DMXFixture": DMXFixture
		},
		"Function": {
			"CueList": CueList,
			"DataPalette": DataPalette,
			"FixtureGroup": FixtureGroup,
			"Function": Function,
			"Scene": Scene,
		},
		"DMXOutput": {
			"ArtNetOutput": ArtNetOutput,
			"DMXOutput": DMXOutput,
		},
		"EngineComponent": EngineComponent,
		"FixtureGroupItem": FixtureGroupItem,
		"Universe": Universe,
	}
}

## Contains all classes sorted by the inheritance tree
var _inheritance_map: Dictionary = {

}

## Contains the class tree for each class
var _inheritance_trees: Dictionary = {

}

## Contains all the class scripts keyed by the classname
var _script_map: Dictionary = {

}

## Contains all the custom classes loaded at runtime
var _custom_classes: Dictionary = {

}


func _ready() -> void:
	rebuild_maps(_global_class_tree)
	


## Builds both the inheritance map and the class script map from the class_tree.
func rebuild_maps(tree: Dictionary) -> void:
	var inheritance_map: Dictionary = {}
	var inheritance_trees: Dictionary = {}
	var class_script_map: Dictionary = {}
	
	for key in tree.keys():
		_process_node(key, tree[key], inheritance_map, inheritance_trees, class_script_map, [key])
	
	_inheritance_map = inheritance_map
	_inheritance_trees = inheritance_trees
	_script_map = class_script_map


## Processes a node in the class_tree.
func _process_node(key: String, node: Variant, inheritance_map: Dictionary, inheritance_trees: Dictionary, class_script_map: Dictionary, current_position: Array) -> void:
	if node is Dictionary:
		var leaves: Array = []
		for subkey in node.keys():
			var subnode = node[subkey]
			
			inheritance_map.get_or_add(key, []).append(subkey)
			current_position.push_back(subkey)
			
			if subnode is Dictionary:
				_process_node(subkey, subnode, inheritance_map, inheritance_trees, class_script_map, current_position)
			else:
				leaves.append(subkey)
				class_script_map[subkey] = subnode
				inheritance_trees[subkey] = current_position.duplicate()
			
			current_position.pop_back()
	else:
		class_script_map[key] = node


## Returns the class script from the script map, or null if not found
func get_class_script(classname: String) -> Script:
	return _script_map.get(classname, null)


## Checks if a class exists in the map
func has_class(classname: String, match_parent: String = "") -> bool:
	if match_parent:
		return _script_map.has(classname) and _inheritance_map.get(match_parent, {}).has(classname)
	else:
		return _script_map.has(classname)


## Returns a copy of the global class tree
func get_global_class_tree() -> Dictionary:
	return _global_class_tree.duplicate(true)


## Returns a copy of the class inheritance map
func get_inheritance_map() -> Dictionary:
	return _inheritance_map.duplicate(true)


## Returns a copy of the script map
func get_script_map() -> Dictionary:
	return _script_map.duplicate()


## Returns a copy of all custom classes
func get_custon_classes() -> Dictionary:
	return _custom_classes.duplicate()


## Gets all the classes that extend the given parent class
func get_classes_from_parent(parent_class: String) -> Dictionary:
	return _inheritance_map.get(parent_class, {}).duplicate()


## Returns a copy of a class's inheritance
func get_class_inheritance_tree(classname: String) -> Array:
	return _inheritance_trees.get(classname, []).duplicate()


## Checks if the given class is custom
func is_class_custom(classname: String) -> bool:
	return _custom_classes.has(classname)


## Adds a new class to the class list
func register_custom_class(class_tree: Array[String], script: Script) -> void:
	var branch: Dictionary = _global_class_tree
	var script_class: String = class_tree[-1]

	if script_class in _custom_classes:
		return
	
	_custom_classes[script_class] = class_tree

	for classname: String in class_tree:
		if classname == script_class:
			branch[classname] = script
			_script_map[classname] = script
			_inheritance_map.get_or_add(class_tree[-2], []).append(script_class)

		else:
			branch = branch.get_or_add(classname, {})


## Returns a copy of all the custom classes
func get_custom_classes() -> Dictionary:
	return _custom_classes.duplicate()