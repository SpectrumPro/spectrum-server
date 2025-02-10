# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name ArtNetOutput extends DMXOutput


## IP address of node to connect to
var _ip_address: String = "192.168.1.73"

## Art-Net _port number
var _port: int = 6454

## Art-Net universe number
var _universe_number: int = 0

 ## PacketPeerUDP responsible for sending art-net packets
var _udp_peer = PacketPeerUDP.new()


## Called when this EngineComponent is ready
func _component_ready():
	set_name("Art-Net Output")
	set_self_class("ArtNetOutput")

	start()


## Called when this output is started
func start():
	stop()
	var err: Error = _udp_peer.connect_to_host(_ip_address, _port)

	if err:
		on_connection_state_changed.emit(false, error_string(err))

	else:
		on_connection_state_changed.emit(true, "Art-Net Connected")


## Called when this output is stoped
func stop():
	on_connection_state_changed.emit(false, "Art-Net Disconnected")
	_udp_peer.close()


## Called when this output it told to output
func output() -> void:

	if not _udp_peer.is_bound():
		return

	var packet = PackedByteArray([65, 114, 116, 45, 78, 101, 116, 0, 0, 80, 0, 14, 0, 0, int(_universe_number) % 256, int(_universe_number) / 256, 02, 00])
	
	# # Art-Net ID ('Art-Net')
	# packet.append_array([65, 114, 116, 45, 78, 101, 116, 0])
	
	# # OpCode: ArtDMX (0x5000)
	# packet.append_array([0, 80])
	
	# # Protocol Version: 14 (0x000e)
	# packet.append_array([0, 14])
	
	# # ArtDMX packet
	# # Sequence Number
	# packet.append(0)
	
	# # Physical Port
	# packet.append(0)
	
	# # Universe (16-bit)
	# packet.append(int(_universe_number) % 256)  # Lower 8 bits
	# packet.append(int(_universe_number) / 256)  # Upper 8 bits
	
	# # Length (16-bit)
	# packet.append(02)
	# packet.append(00)
	# DMX Channels
	for channel in range(1, 513):
		packet.append(clamp(dmx_data.get(channel, 0), 0, 255))
	
	# Send the packet
	_udp_peer.put_packet(packet)

	

## Saves this component to a dictonary
func _on_serialize_request(mode: int) -> Dictionary:
	
	return {
		"_ip_address": _ip_address,
		"_port": _port,
		"_universe_number": _universe_number
	}


## Loads this component from a dictonary
func _on_load_request(serialized_data: Dictionary) -> void:
	_ip_address = str(serialized_data.get("_ip_address", _ip_address))
	_port = int(serialized_data.get("_port", _port))
	_universe_number = int(serialized_data.get("_universe_number", _universe_number))

	start()


## Called when this object is requested to be deleted
func _on_delete_request():
	stop()
