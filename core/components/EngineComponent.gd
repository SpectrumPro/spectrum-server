# Copyright (c) 2026 Liam Sherwin. All rights reserved.
# This file is part of the Spectrum Lighting Controller, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

class_name EngineComponent extends RefCounted
## Base class for engine components, contains functions for storing metadata, and uuid's


## Emitted when an item is added or edited from user_meta
signal user_meta_changed(key: String, value: Variant)

## Emitted when an item is deleted from user_meta
signal user_meta_deleted(key: String)

## Emitted when the name of this object has changed
signal name_changed(new_name: String)

## Emitted when the CID is changed
@warning_ignore("unused_signal")
signal cid_changed(cid: int)

## Emited when this object is about to be deleted
signal delete_requested(from: Object)


## The name of this object
var _name: String = "Unnamed EngineComponent"

## Uuid of the current component, do not modify at runtime unless you know what you are doing, things will break
var _uuid: String = ""

## The class_name of this component this should always be set by the object that extends EngineComponent
var _class_name: String

## Stores all the classes this component inherits from
var _class_tree: Array[String]

## Infomation that can be stored by other scripts / clients, this data will get saved to disk and send to all clients
var _user_meta: Dictionary

## ComponentID
var _cid: int = -1

# The SettingsManager
var _settings: SettingsManager = SettingsManager.new()


## init
func _init(p_uuid: String = UUID.v4(), ...p_args: Array[Variant]) -> void:
	_uuid = p_uuid
	_set_class_name("EngineComponent")
	
	_settings.set_owner(self)
	_settings.set_inheritance_array(_class_tree)
	_settings.set_delete_signal(delete_requested)
	
	_settings.register_setting("Name", Data.Type.STRING, set_name, get_name, [name_changed])
	
	#_settings.register_setting("CID", Data.Type.CID, CIDManager.set_component_id.bind(self), cid, [cid_changed])\
	#.display("EngineComponent", 1)

	_settings.register_networked_methods_auto([
		get_uuid,
		get_name,
		get_uname,
		get_class_name,
		get_base_class,
		get_class_tree,
		get_cid,
		get_user_meta,
		get_all_user_meta,
		set_name,
		set_uname,
		set_user_meta,
		delete_user_meta,
		delete,
		serialize,
	])

	_settings.register_networked_signals_auto([
		user_meta_changed,
		user_meta_deleted,
		name_changed,
		cid_changed,
		delete_requested,
	])

	print_verbose("I am: ", get_name(), " | ", get_uuid())



## Gets the uuid
func get_uuid() -> String:
	return _uuid


## Gets the name
func get_name() -> String:
	return _name


## Gets the name
func get_uname() -> String:
	return _name


## Gets the classname of this EngineComponent
func get_class_name() -> String:
	return _class_name


## Gets the classname of this EngineComponent
func get_base_class() -> String:
	return _class_tree[-1]


## Gets the class tree
func get_class_tree() -> Array[String]:
	return _class_tree.duplicate()


## Gets the settings manager
func get_settings() -> SettingsManager:
	return _settings


## Gets the CID
func get_cid() -> int:
	return _cid


## Returns the value from user meta at the given key, if the key is not found, default is returned
func get_user_meta(p_key: String, p_default = null) -> Variant:
	return _user_meta.get(p_key, p_default)


## Returns all user meta
func get_all_user_meta() -> Dictionary:
	return _user_meta


## Sets the name of this component
func set_name(p_name: String, p_no_signal: bool = false) -> void:
	set_uname(p_name, p_no_signal)


## Sets the name of this component
func set_uname(p_name: String, p_no_signal: bool = false) -> void:
	_name = p_name
	
	if not p_no_signal:
		name_changed.emit(_name)


## Sets self process state
func set_process(process: bool) -> void:
	Core.set_component_process(self, process)


## Sets user meta
func set_user_meta(p_key: String, p_value: Variant) -> void:
	_user_meta[p_key] = p_value
	user_meta_changed.emit(p_key, p_value)


## Delets an item from user meta, returning true if item was found and deleted, and false if not
func delete_user_meta(p_key: String, p_no_signal: bool = false) -> bool:
	var state: bool = _user_meta.erase(p_key)
	
	if not p_no_signal and state:
		user_meta_deleted.emit(p_key)
	
	return state


## Returns a copy of this EngineComponent
func duplicate(p_serialize_flags: int = 0) -> EngineComponent:
	var new_component: EngineComponent = ComponentClassList.get_class_script(_class_name).new()

	new_component.deserialize(serialize(p_serialize_flags | Data.SerializationFlags.NO_UUID))
	return new_component


## Always call this function when you want to delete this component.
## As godot uses reference counting, this object will not truly be deleted untill no other script holds a refernce to it.
func delete() -> void:
	delete_requested.emit()
	print(get_uuid(), " Has had a delete request send. Currently has:", str(get_reference_count()), " refernces")


## Returns serialized version of this component
func serialize(p_flags: Data.SerializationFlags = Data.SerializationFlags.NONE) -> Dictionary:
	return {
		"name": _name,
		"user_meta": get_all_user_meta(),
		"class_name": _class_name
	}.merged({}
	if p_flags & Data.SerializationFlags.NO_UUID else {
		"uuid": _uuid
	})


## Loades this object from a serialized version
func deserialize(p_serialized_data: Dictionary, p_flags: Data.SerializationFlags = Data.SerializationFlags.NONE) -> void:
	set_name(type_convert(p_serialized_data.get("name", _name), TYPE_STRING), true)
	
	if not p_flags & Data.SerializationFlags.NO_UUID:
		_uuid = p_serialized_data.get("uuid", UUID.v4())
	
	_user_meta = type_convert(p_serialized_data.get("user_meta", _user_meta), TYPE_DICTIONARY)
	
	#var cid: int = type_convert(p_serialized_data.get("cid", -1), TYPE_INT)
	#if CIDManager.set_component_id_local(cid, self, true):
		#_cid = cid


## Sets the self class name
func _set_class_name(p_class_name: String) -> void:
	_class_tree.append(p_class_name)
	_class_name = p_class_name


## Debug function to tell if this component is freed from memory
func _notification(p_what: int) -> void:
	if p_what == NOTIFICATION_PREDELETE:
		print("\"", self._name, "\" Is being freed, uuid: ", self._uuid)


## This function is called every frame
func _process(delta: float) -> void:
	pass


## Seralizes an array of EngineComponents
static func seralise_component_array(array: Array, p_flags: Data.SerializationFlags = Data.SerializationFlags.NONE) -> Array[Dictionary]:
	var result: Array[Dictionary]
	
	for component: Variant in array:
		if component is EngineComponent:
			result.append(component.serialize(p_flags))
	
	return result


## Deseralizes an array of seralized EngineComponents
static func deseralise_component_array(array: Array, p_flags: Data.SerializationFlags = Data.SerializationFlags.NONE) -> Array[EngineComponent]:
	var result: Array[EngineComponent]
	
	for seralized_component: Variant in array:
		if seralized_component is Dictionary and seralized_component.has("class_name"):
			var component: EngineComponent = ComponentClassList.get_class_script(seralized_component.class_name).new()
	
			component.deserialize(seralized_component, p_flags)
			result.append(component)
	
	return result
