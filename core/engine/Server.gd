# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

extends Node
## Controls comunication bettween clients and servers


## Port for the websocket to listen to
var websocket_port: int = 3824

## Port for the UDP socket to listen to, defaults to websocket_port - 1
var udp_port: int = websocket_port - 1

## How often to send the the UDP queue
var udp_frequency: float = 1.0 / 45.0  # 1 second divided by 45


## Used as an internal refernce for timing call_interval correctly
var _accumulated_time: float = 0.0 

## Stores all the objects that will be networked 
var _networked_objects: Dictionary = {}

## Stores all the methdods that object delete signals have connections to, to allow them to be disconnected later
var _networked_object_callbacks: Dictionary = {}

## The queue of data that needs to be send over the UDP socket, there can only be one item in the queue at one, so new data will be merged into what is already there, using Dictionary.merge()
var _udp_queue: Dictionary = {}


func _ready() -> void:
	MainSocketServer.message_received.connect(self._on_web_socket_server_message_received)
	MainSocketServer.client_connected.connect(self._on_web_socket_server_client_connected)
	MainSocketServer.client_disconnected.connect(self._on_web_socket_server_client_disconnected)


## Starts the server on the given port, 
func start_server(p_websocket_port: int = websocket_port, p_udp_port: int = udp_port):
	print(TF.auto_format(TF.AUTO_MODE.INFO, "Starting websocket server"))

	var err = MainSocketServer.listen(p_websocket_port)
	if err != OK:
		print(TF.auto_format(TF.AUTO_MODE.ERROR, "Error starting websocket on port: ", p_websocket_port, " | errorcode: ", error_string(err)))
		return
	
	print(TF.auto_format(TF.AUTO_MODE.SUCCESS, "Websocket server started on port: ", p_websocket_port))

	print()

	print(TF.auto_format(TF.AUTO_MODE.INFO, "Starting UDP server"))

	err = MainUDPSocket.listen(p_udp_port)
	if err != OK:
		print(TF.auto_format(TF.AUTO_MODE.ERROR, "Error starting UDP socket on port: ", p_udp_port, " | errorcode: ", error_string(err)))
		return
	
	print(TF.auto_format(TF.AUTO_MODE.SUCCESS, "UDP Socket started on port: ", p_udp_port))


func _process(delta: float) -> void:
	_accumulated_time += delta
	
	# Check if enough time has passed since the last function call
	if _accumulated_time >= udp_frequency:
		
		if _udp_queue:
			MainUDPSocket.put_var(_udp_queue)
			_udp_queue = {}
		
		_accumulated_time -= udp_frequency


## Adds an object to the networked_objects dictnary, allowing for networked functions for the object
func add_networked_object(object_name: String, object: Object, delete_signal: Signal = Signal()) -> bool:

	if object_name in _networked_objects.keys():
		return false	

	var new_networked_config: Dictionary = {
		"object": object,
		"functions": {},
	}

	# Stores all the connected object signals, so they can be disconnected when remove_networked_object() is called
	_networked_object_callbacks[object_name] = {
		"signals": {}
	}


	# Check to see if the user has passed a delete signal, if so connect to it 
	if not delete_signal.is_null():
		 
		delete_signal.connect(remove_networked_object.bind(object_name), CONNECT_ONE_SHOT)

	# The objects script
	var object_script: Script = object.get_script()

	# Network config for the object, stores infomation like what signals are marked as high frequency and sould be routed through the udp socket
	var object_network_config: Dictionary = {
		"high_frequency_signals": []
	}

	# If the object has a network_config, merge it back into the default one
	if object.get("network_config") is Dictionary:
		object_network_config.merge(object.get("network_config"), true)

	# All the user creates methods in the object's script
	var method_list: Array = object_script.get_script_method_list()

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

	# Loop through all the objects signals
	for object_signal_dict: Dictionary in object_script.get_script_signal_list() :

		# Checks if this signal start with an _ if so it is discarded as it is considered an internal signal, and not to be networked
		if object_signal_dict.name.begins_with("_"):
			continue
		
		var object_signal: Signal = object.get(object_signal_dict.name)

		if object_signal in object_network_config.high_frequency_signals:
			_networked_object_callbacks[object_name].signals[object_signal] = func (arg1: Variant = null, arg2: Variant = null, arg3: Variant = null, arg4: Variant = null, arg5: Variant = null, arg6: Variant = null, arg7: Variant = null, arg8: Variant = null):
					var args: Array = [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8] # Create an array of the args
					
					args = args.filter(func (arg):
						return not (arg == null)
					)

					send_high_frequency({
						[object_name, object_signal_dict.name]: args
					})

		else:
			# Get the signal from the object and connect a function to it that will seralise the data, and send it to the clients
			# Due the the fact that gdscript does not yet support vararg functions, this work around is needed to allow all args to be passed, how ever this does have the side efect of limiting signals to 8 args
			# https://github.com/godotengine/godot/pull/82808
			_networked_object_callbacks[object_name].signals[object_signal] = func (arg1: Variant = null, arg2: Variant = null, arg3: Variant = null, arg4: Variant = null, arg5: Variant = null, arg6: Variant = null, arg7: Variant = null, arg8: Variant = null):
					var args: Array = [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8] # Create an array of the args

					send({
						"for": object_name,
						"signal": object_signal_dict.name,
						"args": args.filter(func (arg):
									return not (arg == null)
									)
					})

		
		object_signal.connect(_networked_object_callbacks[object_name].signals[object_signal])

	return true


## Remove an object from the networked objects
func remove_networked_object(object_name: String) -> void:
	print_verbose("Removing Networked Object: ", object_name)

	if _networked_object_callbacks.has(object_name):
		var delete_callbacks: Dictionary = _networked_object_callbacks[object_name]

		for object_signal: Signal in delete_callbacks.signals.keys():
			object_signal.disconnect(delete_callbacks.signals[object_signal])
	
	_networked_object_callbacks.erase(object_name)

	_networked_objects.erase(object_name)


## Returnes a copy of the networked objects
func get_networked_objects() -> Dictionary:
	return _networked_objects.duplicate(true)


## Send a message to all clients, or just one if you sepcify a client id
func send(data: Dictionary, client_id: int = 0) -> void:
	MainSocketServer.send(client_id, var_to_str(Utils.objects_to_uuids(data)))


## Send a message to all clients, using the udp socket for high frequency data
func send_high_frequency(data: Dictionary) -> void:
	_udp_queue.merge(data, true)


func _on_web_socket_server_client_connected(peer_id):
	print("Websocket client connected, ID: ", TF.blue(str(peer_id)))


func _on_web_socket_server_client_disconnected(peer_id):
	print("Websocket client disconnected, ID: ", TF.blue(str(peer_id)))



## Called when message is receved by the server
func _on_web_socket_server_message_received(peer_id, message):
	
	# Try and convert the string message to a Dictionary
	message = str_to_var(message)
	
	# Return if it wasent successfully
	if not message is Dictionary:
		return

	# Check to see if the requiored fields are present in the message
	if "call" in message and message.get("for", "") in _networked_objects:
		# Find the network objects that is being called
		var networked_object: Dictionary = _networked_objects[message.for]

		# Find the method in that networked object
		var method: Dictionary = networked_object.functions.get(message.call, {})

		# And return if it can't be found
		if not method:
			return
		
		# Search through all the values in the command and see if there is any object refernces, if so try and find the object
		var command: Dictionary = Utils.uuids_to_objects(message, _networked_objects)


		if "args" in command:
			for index in len(command.args):
				# Check if the type of the arg passed by the client matches the arg expected by the function, if not stop now to avoid a crash, ignore if the expected type is null, as this could also be Variant
				if not typeof(command.args[index]) == method.args.values()[index] and not method.args.values()[index] == 0:
					print_verbose("Type of data: ", command.args[index],  " does not match type: ", type_string(method.args.values()[index]), " required by: ", method.callable)
					return

		print_verbose("Calling Methord: ", method.callable)
		var result: Variant = method.callable.callv(command.get("args", []))

		# If there is a callback_id in the command, send the result of the function back to the client
		if "callback_id" in command:
			send({
				"callback_id": command.get("callback_id", ""),
				"response": result
			}, peer_id)