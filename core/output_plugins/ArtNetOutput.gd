# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name ArtNetOutput extends DataOutputPlugin

var ip_address: String = "172.16.198.151" ## IP address of node to connect to
var port: int = 6454 ## Art-Net port number
var universe_number: int = 0 ## Art-Net universe number

var _udp_peer = PacketPeerUDP.new() ## PacketPeerUDP responsible for sending art-net packets

## Called when this object is first created
func init():
	# Sets name, description, and authors list of this plugin
	self.plugin_name = "Art-Net Output"
	self.plugin_authors = ["Liam Sherwin"]
	self.plugin_description = "Outputs dmx data over Art-Net"
	start()


## Called when this output is started
func start():
	stop() # Stop the current connection, if one exists
	connection_state_changed.emit(true, "Art-Net Connected") # Emit state changed to true
	_udp_peer.connect_to_host(ip_address, port) # Connect to the node


## Called when this output is stoped
func stop():
	connection_state_changed.emit(false, "Art-Net Disconnected") # Emit state changed to false
	_udp_peer.close() # Disconnect from the node


## Called when this output it told to output
func output() -> void:

	if not _udp_peer.is_bound():
		return

	var packet = PackedByteArray()
	
	# Art-Net ID ('Art-Net')
	packet.append_array([65, 114, 116, 45, 78, 101, 116, 0])
	
	# OpCode: ArtDMX (0x5000)
	packet.append_array([0, 80])
	
	# Protocol Version: 14 (0x000e)
	packet.append_array([0, 14])
	
	# ArtDMX packet
	# Sequence Number
	packet.append(0)
	
	# Physical Port
	packet.append(0)
	
	# Universe (16-bit)
	packet.append(int(universe_number) % 256)  # Lower 8 bits
	packet.append(int(universe_number) / 256)  # Upper 8 bits
	
	# Length (16-bit)
	packet.append(02)
	packet.append(00)
	
	# DMX Channels
	for channel in range(1, 513):
		packet.append(clamp(dmx_data.get(channel, 0), 0, 255))
	
	# Send the packet
	_udp_peer.put_packet(packet)

	

## Called when this output is requested to serialize its config
func _on_data_output_plugin_serialize_request(mode: int) -> Dictionary:
	
	return {
		"ip_address": ip_address,
		"port": port,
		"universe_number": universe_number
	}


## Called when this object is requested to be deleted
func _on_delete_request():
	stop()
