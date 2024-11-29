# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name EngineComponent extends RefCounted
## Base class for engine components, contains functions for storing metadata, and uuid's


## Emitted when an item is added or edited from user_meta
signal on_user_meta_changed(key: String, value: Variant)

## Emitted when an item is deleted from user_meta
signal on_user_meta_deleted(key: String)

## Emitted when the name of this object has changed
signal on_name_changed(new_name: String)

## Emited when this object is about to be deleted
signal on_delete_requested()


## The name of this object
var name: String = "Unnamed EngineComponent": set = set_name

## Infomation that can be stored by other scripts / clients, this data will get saved to disk and send to all clients
var user_meta: Dictionary 

## Infomation that can be stored by other scripts, this is not saved to disk, and will not be send to clients
var local_data: Dictionary

## Uuid of the current component, do not modify at runtime unless you know what you are doing, things will break
var uuid: String = ""

## The class_name of this component this should always be set by the object that extends EngineComponent
var self_class_name: String = "EngineComponent": set = set_self_class

## Stores all the classes this component inherits from
var class_tree: Array[String] = ["EngineComponent"]

## Network Config:
## high_frequency_signals: Contains all the signals that should be send over the udp stream, instead of the tcp websocket 
var network_config: Dictionary = {
	"high_frequency_signals": [
		
	]
}


## Disables signal emmition during loading 
var _disable_signals: bool = false


func _init(p_uuid: String = UUID_Util.v4()) -> void:
	uuid = p_uuid
	_component_ready()

	print_verbose("I am: ", name, " | ", uuid)
	

## Override this function to provide a _ready function for your script
func _component_ready() -> void:
	pass


func register_high_frequency_signals(p_high_frequency_signals: Array) -> void:
	network_config.high_frequency_signals.append_array(p_high_frequency_signals)


## Sets user_meta from the given value
func set_user_meta(key: String, value: Variant, no_signal: bool = false):
	
	user_meta[key] = value
	
	if not no_signal and not _disable_signals:
		on_user_meta_changed.emit(key, value)


## Returns the value from user meta at the given key, if the key is not found, default is returned
func get_user_meta(key: String, default = null) -> Variant: 
	
	return user_meta.get(key, default)


## Returns all user meta
func get_all_user_meta() -> Dictionary:

	return user_meta


## Delets an item from user meta, returning true if item was found and deleted, and false if not
func delete_user_meta(key: String, no_signal: bool = false) -> bool:
	
	if not no_signal and not _disable_signals:
		on_user_meta_deleted.emit(key)

	
	return user_meta.erase(key)


## Sets the name of this component
func set_name(new_name: String) -> void:
	name = new_name
	print_verbose(uuid, ": Changing name to: ", new_name)
	if not _disable_signals: on_name_changed.emit(name)


## Sets the self class name
func set_self_class(p_self_class_name: String) -> void:
	class_tree.append(p_self_class_name)
	self_class_name = p_self_class_name


## Returns serialized version of this component, change the mode to define if this object should be serialized for saving to disk, or for networking to clients
func serialize(mode: int = CoreEngine.SERIALIZE_MODE_NETWORK) -> Dictionary:
	
	var serialized_data: Dictionary = {}
	serialized_data = _on_serialize_request(mode)
	
	serialized_data.uuid = uuid
	serialized_data.name = name
	serialized_data.class_name = self_class_name
	serialized_data.user_meta = get_all_user_meta()
	
	return serialized_data


## Overide this function to serialize your object
func _on_serialize_request(mode: int) -> Dictionary:
	return {}


## Always call this function when you want to delete this component. 
## As godot uses reference counting, this object will not truly be deleted untill no other script holds a refernce to it.
func delete() -> void:
	_on_delete_request()
	
	on_delete_requested.emit()
	
	print_verbose(uuid, " Has had a delete request send. Currently has:", str(get_reference_count()), " refernces")


## Overide this function to handle delete requests
func _on_delete_request() -> void:
	return


## Loades this object from a serialized version
func load(serialized_data: Dictionary) -> void:
	_disable_signals = true
	name = serialized_data.get("name", name)
	self_class_name = serialized_data.get("class_name", self_class_name)
	user_meta = serialized_data.get("user_meta", {})
	
	_on_load_request(serialized_data)
	_disable_signals = false


## Overide this function to handle load requests
func _on_load_request(serialized_data: Dictionary) -> void:
	pass


## Debug function to tell if this component is freed from memory
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		print("\"", self.name, "\" Is being freed, uuid: ", self.uuid)
