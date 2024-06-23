# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

extends Node
## Controls comunication bettween clients and servers


var _networked_objects: Dictionary = {} ## Stores all the objects that will be networked 


var _networked_objects_delete_callbacks: Dictionary = {}

const PORT: int = 3824 ## Port to listen to

func _ready() -> void:
	MainSocketServer.message_received.connect(self._on_web_socket_server_message_received)
	MainSocketServer.client_connected.connect(self._on_web_socket_server_client_connected)
	MainSocketServer.client_disconnected.connect(self._on_web_socket_server_client_disconnected)

	## Start server
	var err = MainSocketServer.listen(PORT)
	if err != OK:
		print("Error listing on port %s" % PORT)
		return
	
	print("Listing on port %s, supported protocols: %s" % [PORT, MainSocketServer.supported_protocols])


func add_networked_object(object_name: String, object: Object, delete_signal: Signal = Signal()) -> bool:
	## Adds an object to the networked_objects dictnary, allowing for networked functions for the object

	if object_name in _networked_objects.keys():
		return false	

	var new_networked_config: Dictionary = {
		"object": object,
		"functions": {},
	}

	if not delete_signal.is_null():
		_networked_objects_delete_callbacks[object_name] = {
			"callable":remove_networked_object.bind(object_name),
			"signal":delete_signal
			}
		 
		delete_signal.connect(_networked_objects_delete_callbacks[object_name].callable)

	var method_list: Array = object.get_script().get_script_method_list()

	# Loop through each function on the object that is being added, and create a dictionary containing the avaibal function, and their args
	for index: int in range(len(method_list)):
		
		# If the method name starts with an "_", discard it, as this meanes its an internal method that should not be called by the client
		if method_list[index].name.begins_with("_"):
			continue 
	
		var method: Dictionary = {
			"callable":object.get(method_list[index].name),
			"args":{}
		}
		
		# Loop through all the args in this method, and note down there name and type
		for arg: Dictionary in method_list[index].args:
			method.args[arg.name] = arg.type

		new_networked_config.functions[method_list[index].name] = method

	_networked_objects[object_name] = new_networked_config 

	var object_signals: Array = object.get_signal_list() # Returnes a array containing all the signals on this object, including ones from which this object extends.
	var base_signals: Array = ClassDB.class_get_signal_list(object.get_class()) # Returnes all the signals from this objects base class, eg Node, RefCounted or Object.

	var base_signal_names: Array = [] # This array will contain the list of signal names from base_signals

	for base_signal: Dictionary in base_signals:
		base_signal_names.append(base_signal.name) # Append the base signal name to this list

	# Loop through all the objects signals
	for object_signal: Dictionary in object_signals:

		# Checks if this signal start with an _ if so it is discarded as it is considered an internal signal, and not to be networked
		# Also checks if this signal is in base_signal_names, if so it is also discarded, as it is a signals from the objects base class, and should not be networked
		if object_signal.name.begins_with("_") or object_signal.name in base_signal_names:
			continue
		
		# Get the signal from the object and connect a function to it that will seralise the data, and send it to the clients
		# Due the the fact that gdscript does not yet support vararg functions, this work areund is needed to allow all args to be passed, how ever this does have the side efect of limiting signals to 8 args
		# https://github.com/godotengine/godot/pull/82808
		(object.get(object_signal.name) as Signal).connect(
			func (arg1: Variant = null, arg2: Variant = null, arg3: Variant = null, arg4: Variant = null, arg5: Variant = null, arg6: Variant = null, arg7: Variant = null, arg8: Variant = null):
				var args: Array = [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8] # Create an array of the args

				# Loop through the all of the args, checking if they are null, if so discard them.
				for arg in args.duplicate():
					if arg == null:
						args.erase(arg)
				
				send({
					"for": object_name,
					"signal": object_signal.name,
					"args": args
				})

		)

	return true


func remove_networked_object(object_name: String) -> void:
	print("Removing Networked Object: ", object_name)
	if _networked_objects_delete_callbacks.has(object_name):
		(_networked_objects_delete_callbacks[object_name].signal as Signal).disconnect(_networked_objects_delete_callbacks[object_name].callable)
		_networked_objects_delete_callbacks.erase(object_name)
		
	_networked_objects.erase(object_name)


## Returnes a copy of the networked objects
func get_networked_objects() -> Dictionary:
	return _networked_objects.duplicate(true)


func send(data: Dictionary) -> void:
	MainSocketServer.send(0, var_to_str(Utils.objects_to_uuids(data)))


# MainSocketServer signals
func _on_web_socket_server_client_connected(peer_id):
	var peer: WebSocketPeer = MainSocketServer.peers[peer_id]
	print("Remote client connected: %d. Protocol: %s" % [peer_id, peer.get_selected_protocol()])
	MainSocketServer.send(-peer_id, "[%d] connected" % peer_id)


func _on_web_socket_server_client_disconnected(peer_id):
	var peer: WebSocketPeer = MainSocketServer.peers[peer_id]
	print("Remote client disconnected: %d. Code: %d, Reason: %s" % [peer_id, peer.get_close_code(), peer.get_close_reason()])
	MainSocketServer.send(-peer_id, "[%d] disconnected" % peer_id)


func _on_web_socket_server_message_received(peer_id, message):
	
	message = str_to_var(message)
	
	if not message is Dictionary:
		return

	if "call" in message and message.get("for", "") in _networked_objects:
		var networked_object: Dictionary = _networked_objects[message.for]

		var method: Dictionary = networked_object.functions.get(message.call, {})

		if not method:
			return
		
		var command: Dictionary = Utils.uuids_to_objects(message, _networked_objects)


		if "args" in command:
			for index in len(command.args):
				# Check if the type of the arg passed by the client matches the arg expected by the function, if not stop now to avoid a crash, ignore if the expected type is null, as this could also be Variant
				if not typeof(command.args[index]) == method.args.values()[index] and not method.args.values()[index] == 0:
					print(typeof(command.args[index]))
					print(method.args.values()[index])
					print("Type of data: ", command.args[index],  " does not match type: ", type_string(method.args.values()[index]), " required by: ", method.callable)
					return

		print("Calling Methord: ", method.callable)
		var result: Variant = method.callable.callv(command.get("args", []))

		if "callback_id" in command:
			send({
				"callback_id": command.get("callback_id", ""),
				"response": result
			})
	# MainSocketServer.send(-peer_id, "[%d] Says: %s" % [peer_id, message])
