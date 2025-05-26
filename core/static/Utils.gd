# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name Utils extends Object
## Usefull function that would be annoying to write out each time


static func save_json_to_file(file_path: String, file_name: String, json: Dictionary) -> Error:
	ensure_folder_exists(file_path)
	var file_access: FileAccess = FileAccess.open(file_path+"/"+file_name, FileAccess.WRITE)
	
	print_verbose("Saving a file to: ", file_path+"/"+file_name)

	if FileAccess.get_open_error():
		return FileAccess.get_open_error()
		
	file_access.store_string(JSON.stringify(json, "\t"))
	file_access.close()
	
	return file_access.get_error()


## Ensures a folder exists on the file system, if not one will be created
static func ensure_folder_exists(folder_path: String) -> void:
	if not DirAccess.dir_exists_absolute(folder_path):
		print(TF.auto_format(TF.AUTO_MODE.INFO, "The folder \"",folder_path ,"\" does not exist, creating one now, errcode: ", DirAccess.make_dir_recursive_absolute(folder_path)))



## Checks if there are any Objects in the data passed, also checks inside of arrays and dictionarys. If any are found, they are replaced with there uuid, if no uuid if found, it will be null instead 
static func objects_to_uuids(data, just_uuid: bool = false):
	match typeof(data):
		TYPE_OBJECT:
			if just_uuid:
				return str(data.get("uuid"))
			else:
				return {
						"_object_ref": str(data.get("uuid")),
						"_serialized_object": data.serialize(CoreEngine.SERIALIZE_MODE_NETWORK),
						"_class_name": data.get("self_class_name")
					}
		
		TYPE_DICTIONARY:
			var new_dict = {}
			for key in data.keys():
				new_dict[key] = objects_to_uuids(data[key], just_uuid)
			return new_dict

		TYPE_ARRAY:
			var new_array = []
			for item in data:
				new_array.append(objects_to_uuids(item, just_uuid))
			return new_array

		TYPE_COLOR:
			return var_to_str(data)
		

	return data


## Checks if there are any uuids in the data passed, also checks inside of arrays and dictionarys. If any are found, they are replaced with there object refenrce, if no object refernce is found, null is returned
static func uuids_to_objects(data: Variant, networked_objects: Dictionary):
	match typeof(data):
		TYPE_DICTIONARY:
			if "_object_ref" in data.keys():
				if data._object_ref in networked_objects.keys():
					return networked_objects[data._object_ref].object

				elif "_class_name" in data.keys():
					if ClassList.has_class(data["_class_name"]):
						var initialized_object = ClassList.get_class_script(data["_class_name"]).new(data._object_ref)

						if initialized_object.has_method("load") and "_serialized_object" in data.keys():
							initialized_object.load(data._serialized_object)

						return initialized_object
				else:
					return null

			else:
				var new_dict = {}
				for key in data.keys():
					new_dict[key] = uuids_to_objects(data[key], networked_objects)
				return new_dict
								
		TYPE_ARRAY:
			var new_array = []
			for item in data:
				new_array.append(uuids_to_objects(item, networked_objects))
			return new_array
		
		TYPE_STRING:
			if data.contains("Color("):
				return str_to_var(data)
	
	return data


## Connects all the callables to the signals in the dictionary. Stored as {"SignalName": Callable}
static func connect_signals(signals: Dictionary, object: Object) -> void:
	if is_instance_valid(object):
		for signal_name: String in signals:
			if object.has_signal(signal_name) and not (object.get(signal_name) as Signal).is_connected(signals[signal_name]):
				(object.get(signal_name) as Signal).connect(signals[signal_name])


## Disconnects all the callables from the signals in the dictionary. Stored as {"SignalName": Callable}
static func disconnect_signals(signals: Dictionary, object: Object) -> void:
	if is_instance_valid(object):
		for signal_name: String in signals:
			if object.has_signal(signal_name) and (object.get(signal_name) as Signal).is_connected(signals[signal_name]):
				(object.get(signal_name) as Signal).disconnect(signals[signal_name])