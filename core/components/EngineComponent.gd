# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name EngineComponent extends RefCounted
## Base class for engine components, contains functions for storing metadata, and uuid's


## Emitted when the name of this object has changed
signal on_name_changed(new_name: String)

## Emited when this object is about to be deleted
signal on_delete_requested()

## Emitted when an item is added or edited from user_meta
signal on_user_meta_changed(key: String, value: Variant)

## Emitted when an item is deleted from user_meta
signal on_user_meta_deleted(key: String)

## Emitted when the CID is changed
signal cid_changed(cid: int)


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

## ComponentID
var _cid: int = -1

## List of functions that are allowed to be called by external control scripts.
var _control_methods: Dictionary[String, Dictionary] = {}

## Network Config:
## high_frequency_signals: Contains all the signals that should be send over the udp stream, instead of the tcp websocket
var network_config: Dictionary = {
	"high_frequency_signals": {

	}
}


## Disables signal emmition during loading
var _disable_signals: bool = false


func _init(p_uuid: String = UUID_Util.v4(), p_name: String = name) -> void:
	uuid = p_uuid
	name = p_name
	_component_ready()

	print_verbose("I am: ", name, " | ", uuid)


## Override this function to provide a _ready function for your script
func _component_ready() -> void:
	pass


## Sets the name of this component
func set_name(p_name: String) -> void:
	name = p_name
	print_verbose(uuid, ": Changing name to: ", name)
	if not _disable_signals: on_name_changed.emit(name)


## Sets the self class name
func set_self_class(p_self_class_name: String) -> void:
	if p_self_class_name == self_class_name or p_self_class_name in class_tree:
		return

	class_tree.append(p_self_class_name)
	self_class_name = p_self_class_name


## Adds a high frequency signal to the network config
func register_high_frequency_signal(p_signal: Signal, p_match_args: int = 0) -> void:
	network_config.high_frequency_signals[p_signal] = p_match_args


## Gets the arg match count of a high frequency signal
func get_hf_signal_arg_match(p_signal: Signal) -> int:
	return network_config.high_frequency_signals.get(p_signal, 0)


## Registers a method that can be called by external control systems
func register_control_method(p_name: String, p_down_method: Callable, p_up_method: Callable = Callable(), p_signal: Signal = Signal(), p_args: Array[int] = []) -> void:
	_control_methods.merge({
		p_name: {
			"down": p_down_method,
			"up": p_up_method,
			"signal": p_signal,
			"args": p_args
		}
	})


## Gets a control method by name
func get_control_methods() -> Dictionary[String, Dictionary]:
	return _control_methods.duplicate()


## Gets a control method by name
func get_control_method(p_control_name: String) -> Dictionary:
	return _control_methods.get(p_control_name, {})


## Returns the value from user meta at the given key, if the key is not found, default is returned
func get_user_meta(p_key: String, p_default = null) -> Variant:
	return user_meta.get(p_key, p_default)


## Returns all user meta
func get_all_user_meta() -> Dictionary:
	return user_meta


## Gets the cid
func cid() -> int:
	return _cid


## Delets an item from user meta, returning true if item was found and deleted, and false if not
func delete_user_meta(p_key: String, p_no_signal: bool = false) -> bool:
	var state: bool = user_meta.erase(p_key)

	if not p_no_signal and not _disable_signals and state:
		on_user_meta_deleted.emit(p_key)

	return state


## Sets self process state
func set_process(process: bool) -> void:
	Core.set_component_process(self, process)


## This function is called every frame
func _process(delta: float) -> void:
	pass


## Always call this function when you want to delete this component.
## As godot uses reference counting, this object will not truly be deleted untill no other script holds a refernce to it.
func delete(p_local_only: bool = false) -> void:
	if p_local_only:
		ComponentDB.deregister_component(self)

	_on_delete_request()
	on_delete_requested.emit()
	print_verbose(uuid, " Has had a delete request send. Currently has:", str(get_reference_count()), " refernces")


## Overide this function to handle delete requests
func _on_delete_request() -> void:
	return


## Returns serialized version of this component, change the mode to define if this object should be serialized for saving to disk, or for networking to clients
func serialize(p_flags: int = 0) -> Dictionary:
	var serialized_data: Dictionary = {}
	serialized_data = _on_serialize_request(p_flags)

	serialized_data.merge({
		"name": name,
		"class_name": self_class_name,
		"cid": _cid,
		"user_meta": get_all_user_meta()
	}, true)
	
	if not (p_flags & Core.SM_DUPLICATE):
		serialized_data.merge({
			"uuid": uuid,
		})

	return serialized_data


## Overide this function to serialize your object
func _on_serialize_request(p_flags: int) -> Dictionary:
	return {}


## Loades this object from a serialized version
func load(p_serialized_data: Dictionary) -> void:
	_disable_signals = true
	name = p_serialized_data.get("name", name)
	self_class_name = p_serialized_data.get("class_name", self_class_name)
	user_meta = p_serialized_data.get("user_meta", {})

	var cid: int = type_convert(p_serialized_data.get("cid", -1), TYPE_INT)
	if CIDManager.set_component_id(cid, self, true):
		_cid = cid

	_on_load_request(p_serialized_data)
	_disable_signals = false


## Overide this function to handle load requests
func _on_load_request(p_serialized_data: Dictionary) -> void:
	pass


## Debug function to tell if this component is freed from memory
func _notification(p_what: int) -> void:
	if p_what == NOTIFICATION_PREDELETE:
		print("\"", self.name, "\" Is being freed, uuid: ", self.uuid)
