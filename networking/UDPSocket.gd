# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name UDPSocket extends Node
## UDP Socket, used by the server to send high frequency data


## Emitted when a client connects to the socket
signal client_connected(peer: PacketPeerUDP)


var _server: UDPServer = UDPServer.new()

## Contains all the peers connected to this server
var _peers: Array = []


## Starts the server on the given port
func listen(p_port: int, address: String = "*") -> int:
	return _server.listen(p_port, address)


func _process(delta):
	_server.poll()

	if _server.is_connection_available():
		var new_peer: PacketPeerUDP = _server.take_connection()

		print("Accepted UDP peer from: ", TF.blue(str(new_peer.get_packet_ip()) + ":" + str(new_peer.get_packet_port())))

		print(new_peer)
		_peers.append(new_peer)


func put_var(variant: Variant):
	_peers.map(func (peer: PacketPeerUDP):
		peer.put_var(variant)	
	)
