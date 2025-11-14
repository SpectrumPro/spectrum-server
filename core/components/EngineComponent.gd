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
var _name: String = "Unnamed EngineComponent"

## Infomation that can be stored by other scripts / clients, this data will get saved to disk and send to all clients
var _user_meta: Dictionary

## Infomation that can be stored by other scripts, this is not saved to disk, and will not be send to clients
var local_data: Dictionary

## Uuid of the current component, do not modify at runtime unless you know what you are doing, things will break
var _uuid: String = ""

## The class_name of this component this should always be set by the object that extends EngineComponent
var _self_class_name: String = "EngineComponent"

## Stores all the classes this component inherits from
var _class_tree: Array[String] = ["EngineComponent"]

## ComponentID
var _cid: int = -1

## Disables signal emmition during loading
var _disable_signals: bool = false

## The SettingsManager
var _settings_manager: SettingsManager = SettingsManager.new()


## init
func _init(p_uuid: String = UUID_Util.v4(), p_name: String = _name) -> void:
	_uuid = p_uuid
	_name = p_name

	_settings_manager.set_owner(self)
	_settings_manager.set_inheritance_array(_class_tree)

	_settings_manager.register_setting("name", Data.Type.STRING, set_name, get_name, [on_name_changed])\
	.display("EngineComponent", 0)
	
	#_settings_manager.register_setting("CID", Data.Type.CID, CIDManager.set_component_id.bind(self), cid, [cid_changed])\
	#.display("EngineComponent", 1)

	_settings_manager.register_networked_methods_auto([
		cid,
		uuid,
		name,
		classname,
		set_name,
		set_user_meta,
		delete_user_meta,
		get_user_meta,
		get_all_user_meta,
		get_cid,
		get_uuid,
		get_name,
		get_self_classname,
		get_class_tree,
		delete,
		serialize,
		load,
	])

	_settings_manager.register_networked_signals_auto([
		on_name_changed,
		on_delete_requested,
		on_user_meta_changed,
		on_user_meta_deleted
	])

	_component_ready()
	print_verbose("I am: ", name(), " | ", uuid())


## Override this function to provide a _ready function for your script
func _component_ready() -> void:
	pass


## Shorthand for get_cid()
func cid() -> int:
	return get_cid()


## shorthand for get_uuid()
func uuid() -> String:
	return get_uuid()


## Shorthand for get_name()
func name() -> String:
	return get_name()


## Shorthand for get_self_classname()
func classname() -> String:
	return get_self_classname()


## Shorthand for get_settings_manager()
func settings() -> SettingsManager:
	return get_settings_manager()


## Sets self process state
func set_process(process: bool) -> void:
	Core.set_component_process(self, process)


## Sets the name of this component
func set_name(p_name: String) -> void:
	_name = p_name
	print_verbose(uuid, ": Changing name to: ", _name)
	if not _disable_signals: on_name_changed.emit(_name)


## Sets user meta
func set_user_meta(p_key: String, p_value: Variant) -> void:
	_user_meta[p_key] = p_value
	on_user_meta_changed.emit(p_key, p_value)


## Delets an item from user meta, returning true if item was found and deleted, and false if not
func delete_user_meta(p_key: String, p_no_signal: bool = false) -> bool:
	var state: bool = _user_meta.erase(p_key)

	if not p_no_signal and not _disable_signals and state:
		on_user_meta_deleted.emit(p_key)

	return state


## Returns the value from user meta at the given key, if the key is not found, default is returned
func get_user_meta(p_key: String, p_default = null) -> Variant:
	return _user_meta.get(p_key, p_default)


## Returns all user meta
func get_all_user_meta() -> Dictionary:
	return _user_meta


## Gets the CID
func get_cid() -> int:
	return _cid


## Gets the uuid
func get_uuid() -> String:
	return _uuid


## Gets the name
func get_name() -> String:
	return _name


## Gets the classname of this EngineComponent
func get_self_classname() -> String:
	return _self_class_name


## Gets the settings manager
func get_settings_manager() -> SettingsManager:
	return _settings_manager


## Gets the class tree
func get_class_tree() -> Array[String]:
	return _class_tree.duplicate()


## Always call this function when you want to delete this component.
## As godot uses reference counting, this object will not truly be deleted untill no other script holds a refernce to it.
func delete(p_local_only: bool = false) -> void:
	if p_local_only:
		ComponentDB.deregister_component(self)
	
	_on_delete_request()
	on_delete_requested.emit()
	print(uuid(), " Has had a delete request send. Currently has:", str(get_reference_count()), " refernces")


## Returns serialized version of this component, change the mode to define if this object should be serialized for saving to disk, or for networking to clients
func serialize(p_flags: int = 0) -> Dictionary:
	var serialized_data: Dictionary = {}
	serialized_data = _on_serialize_request(p_flags)

	serialized_data.merge({
		"name": _name,
		"class_name": _self_class_name,
		"cid": _cid,
		"user_meta": get_all_user_meta()
	}, true)
	
	if not (p_flags & Core.SM_DUPLICATE):
		serialized_data.merge({
			"uuid": _uuid,
		})

	return serialized_data


## Loades this object from a serialized version
func load(p_serialized_data: Dictionary) -> void:
	_disable_signals = true
	_name = p_serialized_data.get("name", name)
	_self_class_name = p_serialized_data.get("class_name", _self_class_name)
	_user_meta = p_serialized_data.get("user_meta", {})

	var cid: int = type_convert(p_serialized_data.get("cid", -1), TYPE_INT)
	if CIDManager.set_component_id(cid, self, true):
		_cid = cid

	_on_load_request(p_serialized_data)
	_disable_signals = false


## Sets the self class name
func _set_self_class(p_self_class_name: String) -> void:
	if p_self_class_name == _self_class_name or p_self_class_name in _class_tree:
		return

	_class_tree.append(p_self_class_name)
	_self_class_name = p_self_class_name


## Debug function to tell if this component is freed from memory
func _notification(p_what: int) -> void:
	if p_what == NOTIFICATION_PREDELETE:
		print("\"", self._name, "\" Is being freed, uuid: ", self._uuid)


## This function is called every frame
func _process(delta: float) -> void:
	pass


## Overide this function to handle delete requests
func _on_delete_request() -> void:
	return


## Overide this function to serialize your object
func _on_serialize_request(p_flags: int) -> Dictionary:
	return {}


## Overide this function to handle load requests
func _on_load_request(p_serialized_data: Dictionary) -> void:
	pass



#region DeleteMe

## Adds a high frequency signal to the network config
func register_high_frequency_signal(p_signal: Signal, p_match_args: int = 0) -> void:
	pass


## Gets the arg match count of a high frequency signal
func get_hf_signal_arg_match(p_signal: Signal) -> int:
	return 0


## Registers a method that can be called by external control systems
func register_control_method(p_name: String, p_down_method: Callable, p_up_method: Callable = Callable(), p_signal: Signal = Signal(), p_args: Array[int] = []) -> void:
	pass


## Gets a control method by name
func get_control_methods() -> Dictionary[String, Dictionary]:
	return {}


## Gets a control method by name
func get_control_method(p_control_name: String) -> Dictionary:
	return {}

#endregion
