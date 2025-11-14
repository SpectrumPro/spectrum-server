# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name CoreServer extends Node
## Controls comunication bettween clients and servers


## Port for the websocket to listen to
var websocket_port: int = 3824

## Port for the UDP socket to listen to, defaults to websocket_port - 1
var udp_port: int = websocket_port - 1

## How often to send the the UDP queue
var udp_frequency: float = 1.0 / 60.0  # 1 second divided by 45

## Disables signal emissions to clients
var disable_signals: bool = false

## Dissables the use of the high frequency UDP socketc
var dissable_high_frequency: bool = false


## Used as an internal refernce for timing call_interval correctly
var _accumulated_time: float = 0.0 

## Stores all the objects that will be networked 
var _networked_objects: Dictionary = {}

## Stores all the methdods that object delete signals have connections to, to allow them to be disconnected later
var _networked_object_callbacks: Dictionary = {}

## The queue of data that needs to be send over the UDP socket, there can only be one item in the queue at one, so new data will be merged into what is already there, using Dictionary.merge()
var _udp_queue: Dictionary[Array, Dictionary] = {}


func _ready() -> void:
	pass


## Starts the server on the given port, 
func start_server(p_websocket_port: int = websocket_port, p_udp_port: int = udp_port):
	pass



## Check if enough time has passed since the last function call
func _process(delta: float) -> void:
	pass


## Registers a component as a network object
func register_component(p_component: EngineComponent) -> void:
	pass


## Deregisters a component as a network object
func deregister_component(p_component: EngineComponent) -> void:
	pass


## Adds an object to the networked_objects dictnary, allowing for networked functions for the object
func add_networked_object(object_name: String, object: Object, delete_signal: Signal = Signal()) -> bool:
	return false


## Remove an object from the networked objects
func remove_networked_object(object_name: String) -> void:
	pass


## Returnes a copy of the networked objects
func get_networked_objects() -> Dictionary:
	return {}


## Send a message to all clients, or just one if you sepcify a client id
func send(data: Dictionary, client_id: int = 0) -> void:
	pass


## Send a message to all clients, using the udp socket for high frequency data
func send_high_frequency(data: Dictionary) -> void:
	pass


func _on_web_socket_server_client_connected(peer_id):
	pass


func _on_web_socket_server_client_disconnected(peer_id):
	pass


## Called when message is receved by the server
func _on_web_socket_server_message_received(peer_id, message):
	pass
