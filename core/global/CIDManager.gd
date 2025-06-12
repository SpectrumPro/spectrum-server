# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name ComponentIDManager extends Node
## Manages CIDs (Component ID Numbers)


## Emitted when a Component's CID is changed
signal on_componend_id_changed(cid: int, component: EngineComponent)


## Stores all components's CID numbers sepreated by classnames
var _cids_by_classname: Dictionary[String, RefMap]


## Connect reset signal
func _ready() -> void:
	Core.on_resetting.connect(func (): _cids_by_classname.clear())


## Sets a component's CID, returning false if it was alreay taken
func set_component_id(cid: int, p_component: EngineComponent, no_signal: bool = false) -> bool:
	var class_cid_map: RefMap = _cids_by_classname.get_or_add(p_component.self_class_name, RefMap.new())

	if class_cid_map.right(cid):
		return false

	if cid >= 0:
		class_cid_map.map(p_component, cid)
	else:
		class_cid_map.erase_left(p_component)

	p_component._cid = cid
	p_component.cid_changed.emit(cid)

	if not no_signal:
		on_componend_id_changed.emit(cid, p_component)

	return true


## Gets a component via its CID and classname
func get_component_by_id(classname: String, cid: int) -> EngineComponent:
	if not _cids_by_classname.has(classname):
		return null

	return _cids_by_classname[classname].right(cid)


## Gets all the CID's of components by there classname
func get_components_ids_by_classname(classname: String) -> Dictionary[EngineComponent, int]:
	if not _cids_by_classname.has(classname):
		return {}

	return Dictionary(_cids_by_classname[classname].get_as_dict(), TYPE_NIL, "EngineComponent", EngineComponent, TYPE_INT, "", null)
