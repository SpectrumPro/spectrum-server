# Copyright (c) 2025 Liam Sherwin. All rights reserved.
# This file is part of the Spectrum Lighting Controller, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

class_name ArtNetOutput extends DMXOutput
## Art-Net DMX Output


## Emitted when the ip is changed
signal on_ip_changed(ip: String)

## Emitted when the broadcast state is changed
signal on_broadcast_state_changed(use_broadcast: bool)

## Emitted when the universe number is changed
signal on_universe_number_changed(universe_number: int)


## IP address of node to connect to
var _ip_address: String = "127.0.0.1"

## Art-Net _port number
var _port: int = 6454

## Broadcast state
var _use_broadcast: bool = false

## Art-Net universe number
var _universe_number: int = 0

 ## PacketPeerUDP responsible for sending art-net packets
var _udp_peer = PacketPeerUDP.new()


## Called when this object is first created
func _init(p_uuid: String = UUID_Util.v4(), p_name: String = _name) -> void:
	super._init(p_uuid, p_name)
	
	set_name("ArtNetOutput")
	_set_self_class("ArtNetOutput")
	
	_settings_manager.register_setting("ip_address", Data.Type.IP, set_ip, get_ip, [on_ip_changed])
	_settings_manager.register_setting("use_broadcast", Data.Type.BOOL, set_use_broadcast, get_use_broadcast, [on_broadcast_state_changed])
	_settings_manager.register_setting("universe_number", Data.Type.INT, set_universe_number, get_universe_number, [on_universe_number_changed])

	_settings_manager.register_networked_signals_auto([
		on_ip_changed,
		on_broadcast_state_changed,
		on_universe_number_changed,
	])

	_settings_manager.register_networked_methods_auto([
		set_ip,
		get_ip,
		set_use_broadcast,
		get_use_broadcast,
		set_universe_number,
		get_universe_number,
	])


## Sets the ip address
func set_ip(p_ip: String) -> void:
	_ip_address = p_ip

	on_ip_changed.emit(_ip_address)

	if _connection_state:
		start()


## Gets the ip address
func get_ip() -> String:
	return _ip_address



## Sets the broadcast state
func set_use_broadcast(p_use_broadcast: bool) -> void:
	_use_broadcast = p_use_broadcast
	_udp_peer.set_broadcast_enabled(_use_broadcast)
	
	on_broadcast_state_changed.emit(_use_broadcast)

	if _connection_state:
		start()


## Gets the broadcast state
func get_use_broadcast() -> bool:
	return _use_broadcast


## Sets the universe number
func set_universe_number(p_universe_number: int) -> void:
	output({})
	_universe_number = p_universe_number
	on_universe_number_changed.emit()


## Gets the universe number
func get_universe_number() -> int:
	return _universe_number


## Called when this output is started
func start():
	stop()
	set_use_broadcast(_use_broadcast)
	var err: Error = _udp_peer.set_dest_address(_ip_address, _port)

	if err:
		on_connection_state_changed.emit(false, error_string(err))

	else:
		_connection_state = true
		on_connection_state_changed.emit(true, "Art-Net Connected")


## Called when this output is stoped
func stop():
	output({})
	_connection_state = false
	on_connection_state_changed.emit(false, "Art-Net Disconnected")
	_udp_peer.close()


## Called when this output it told to output
func output(dmx: Dictionary = dmx_data) -> void:

	if not _connection_state:
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
		packet.append(clamp(dmx.get(channel, 0), 0, 255))
	
	# Send the packet
	_udp_peer.put_packet(packet)


## Saves this component to a dictonary
func _on_serialize_request(p_flags: int) -> Dictionary:
	var serialize_data: Dictionary = {
		"ip_address": _ip_address,
		"port": _port,
		"use_broadcast": _use_broadcast,
		"universe_number": _universe_number,
		"auto_start": _auto_start
	}

	if p_flags & Core.SM_NETWORK:
		serialize_data.merge({
			"connection_state": _connection_state,
			"connection_note": _previous_note
		})

	return serialize_data


## Loads this component from a dictonary
func _on_load_request(serialized_data: Dictionary) -> void:
	_ip_address = type_convert(serialized_data.get("ip_address", _ip_address), TYPE_STRING)
	_port = type_convert(serialized_data.get("port", _port), TYPE_INT)
	_use_broadcast = type_convert(serialized_data.get("use_broadcast"), TYPE_BOOL)
	_universe_number = type_convert(serialized_data.get("universe_number", _universe_number), TYPE_INT)
	_auto_start = type_convert(serialized_data.get("auto_start", _auto_start), TYPE_BOOL)

	if _auto_start:
		start()	


## Called when this object is requested to be deleted
func _on_delete_request():
	stop()
