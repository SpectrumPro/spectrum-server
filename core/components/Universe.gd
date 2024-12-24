# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name Universe extends EngineComponent
## Engine component for handling universes, and there outputs
## [br][br]
## Caution, two or more fixtures can share the same channel, be carefull when adding fixtures, as overlapping channels may cause unexpected outputs

## Emitted when any of the fixtures in this universe have there name changed
signal on_fixture_name_changed(fixture: Fixture, new_name: String) 

## Emited when a fixture / fixtures are added to this universe, contains a list of all fixture uuids for server-client synchronization
signal on_fixtures_added(fixtures: Array[Fixture], fixture_uuids: Array[String])

## Emited when a fixture / fixtures are removed from this universe, contains a list of all fixture uuids for server-client synchronization
signal on_fixtures_removed(fixtures: Array[Fixture], fixture_uuids: Array[String])


## Emited when a output / outputs are added to this universe, contains a list of all output uuids for server-client synchronization
signal on_outputs_added(outputs: Array[DataOutputPlugin], output_uuids: Array[String])

## Emited when a output / outputs are removed from this universe, contains a list of all output uuids for server-client synchronization
signal on_outputs_removed(outputs: Array[DataOutputPlugin], output_uuids: Array[String])


## Dictionary containing all the fixtures in this universe, stored as channel:Array[fixture]
var fixture_channels: Dictionary = {} 

## Dictionary containing all the fixtures in this universe, stored as uuid:fixture
var fixtures: Dictionary = {}

## Dictionary containing all the outputs in this universe
var outputs: Dictionary = {} 

## Dictionary containing the current dmx data of this universe, this is constantly updated, so modifying this manualy will cause unexpected outcomes
var dmx_data: Dictionary = {} 

## Stores dmx overrides, sotred at {channel:value}. theese values will always override other data passed to this universe
var dmx_overrides: Dictionary = {}

## Called when this EngineComponent is ready
func _component_ready() -> void:
	name = "Universe"
	self_class_name = "Universe"


## Adds a new output to this universe, if [param output] is defined, it will be added, if no output is defined, a blank [DataOutputPlugin] will be created with the name passed
func add_output(output: DataOutputPlugin = null, no_signal: bool = false) -> DataOutputPlugin:
	
	# if output is not defined, create a new one, and set its name to be the name passed to this function
	if not output:
		output = DataOutputPlugin.new()

	outputs[output.uuid] = output
	
	Core._output_timer.connect(output.output)
	Server.add_networked_object(output.uuid, output, output.on_delete_requested) # Add this new output to networked objects, to allow it to be controled remotely
	
	if not no_signal:
		on_outputs_added.emit([output], outputs.keys())

	return output


## Adds mutiple outputs to this univere at once, [param outputs_to_add] can be a array of [DataOutputPlugin]s or a array of [param n] length, where [param n] is the number of [DataOutputPlugin]'s to be added
func add_outputs(outputs_to_add: Array, no_signal: bool = false) -> Array[DataOutputPlugin]:

	var just_added_outputs: Array = []

	for item in outputs_to_add:
		if item is DataOutputPlugin:
			just_added_outputs.append(add_output(item, true))
		else:
			just_added_outputs.append(add_output(DataOutputPlugin.new(), true))

	on_outputs_added.emit(just_added_outputs, outputs.keys())

	return just_added_outputs


## Removes a output from this engine
func remove_output(output: DataOutputPlugin, no_signal: bool = false, delete_object: bool = true) -> bool: 
	
	# Check if this output is part of this universe
	if output in outputs.values():
		
		outputs.erase(output.uuid)			

		if delete_object:
			output.delete()

		if not no_signal:
			on_outputs_removed.emit([output])
		
		return true
	
	# If not return false
	else:
		print("Output: ", output.uuid, " is not part of this universe")
		return false


## Removes mutiple outputs from this universe
func remove_outputs(outputs_to_remove: Array, no_signal: bool = false, delete_object: bool = true) -> void:

	var just_removed_outputs: Array = []

	for output: DataOutputPlugin in outputs_to_remove:
		if remove_output(output, true, delete_object):
			just_removed_outputs.append(output)		
	
	if not no_signal and just_removed_outputs:
		on_outputs_removed.emit(just_removed_outputs)


## Adds a new fixture to this universe, from a pre exitsing fixture, also see [method Universe.add_fixture_from_manifest] [br]
## If [param channel] is -1 the channel in [member Fixture.channel] will be used [br]
## False is returned if the fixture is already part of this universe [br]
## Caution, if you add a fixture that is already part of another universe, the channel will be over written and the fixture will start to output on both universes at the same channel
func add_fixture(fixture: Fixture, channel: int = -1, no_signal: bool = false) -> Variant:
	
	if fixture in fixtures.values():
		return false

	var fixture_channel: int = fixture.channel if channel == -1 else channel
	
	fixture.channel = fixture_channel

	if not fixture_channels.get(fixture_channel):
		fixture_channels[fixture_channel] = []
	
	fixture_channels[fixture_channel].append(fixture)

	fixtures[fixture.uuid] = fixture

	ComponentDB.register_component(fixture)
	fixture.on_delete_requested.connect(remove_fixture.bind(fixture), CONNECT_ONE_SHOT)
	fixture._fixture_data_changed.connect(self.set_data)

	if not no_signal:
		on_fixtures_added.emit([fixture], fixtures.keys())
	
	return fixture


## Adds a new fixture to this universe, from a fixture manifest [br]
## Returnes false if [parma fixture_manifest] is not valid fixture_manifest, see [method Utils.is_valid_fixture_manifest]
func add_fixture_from_manifest(fixture_manifest: Dictionary, mode: int, channel: int, no_signal: bool = false) -> Variant:
	
	var fixture: Fixture = Fixture.new()
	fixture.name = fixture_manifest.info.name
	fixture.channel = channel
	fixture.mode = mode
	fixture.set_manifest(fixture_manifest, fixture_manifest.info.manifest_path)
	
	return add_fixture(fixture, channel, no_signal)


## Adds mutiple new fixtures to this universe, from a fixture manifest [br]
## [param start_channel] is the first channel that will be asigned [br]
## [param offset] adds a channel gap between each fixture [br]
## Will return false is manifest is not valid, otherwise Array[Fixture]
func add_fixtures_from_manifest(fixture_manifest: Dictionary, mode:int, start_channel: int, quantity:int, offset:int = 0, no_signal: bool = false) -> Variant:

	var just_added_fixtures: Array[Fixture] = []
	
	for index: int in range(quantity):
		var channel_index = start_channel + offset
		channel_index += len(fixture_manifest.modes[mode].channels) * index

		var new_fixture = add_fixture_from_manifest(fixture_manifest, mode, channel_index, true)
		if new_fixture:
			just_added_fixtures.append(new_fixture)
		
	if not no_signal:
		on_fixtures_added.emit(just_added_fixtures, fixtures.keys())
	
	return just_added_fixtures


## Removes a fixture from this universe
func remove_fixture(fixture: Fixture, no_signal: bool = false, delete_object: bool = true) -> bool:
	if fixture in fixtures.values():

		fixtures.erase(fixture.uuid)
		fixture_channels[fixture.channel].erase(fixture)

		fixture._fixture_data_changed.disconnect(self.set_data)

		if not fixture_channels[fixture.channel]:
			fixture_channels.erase(fixture.channel)
		
		if delete_object:
			fixture.delete()

		if not no_signal:
			on_fixtures_removed.emit([fixture], fixtures.keys())

		return true
		# If not return false
	else:
		print("Fixture: ", fixture.uuid, " is not part of this universe")
		return false


## Removes mutiple fixtures from this universe
func remove_fixtures(fixtures_to_remove: Array, no_signal: bool = false, delete_object: bool = true) -> void:

	var just_removed_fixtures: Array = []
	
	for fixture: Fixture in fixtures_to_remove:
		if remove_fixture(fixture, true, delete_object):
			just_removed_fixtures.append(fixture)		
	
	if not no_signal and just_removed_fixtures:
		on_outputs_removed.emit(just_removed_fixtures)
		

## Returns a fixture from its channel, otherwise returns false
func get_fixture_by_channel(channel:int) -> Variant:
	if fixture_channels.has(channel):
		return fixture_channels[channel]
	else:
		return false


## Set dmx data, data should be stored as channel:value
func set_data(data: Dictionary):
	dmx_data.merge(data, true)
	_compile_and_send()


func set_dmx_override(channel: int, value: int) -> void:
	dmx_overrides[channel] = value
	_compile_and_send()


func remove_dmx_override(channel: int) -> void:
	dmx_overrides.erase(channel)
	_compile_and_send()



func remove_all_dmx_overrides() -> void:
	dmx_overrides = {}
	_compile_and_send()


## Compile the dmx data, and send to the outputs
func _compile_and_send():
	var compiled_dmx_data: Dictionary = dmx_data.duplicate()
	compiled_dmx_data.merge(dmx_overrides, true)

	for output: DataOutputPlugin in outputs.values():
		output.dmx_data = compiled_dmx_data
		

## Serializes this universe
func _on_serialize_request(mode: int = Core.SERIALIZE_MODE_NETWORK) -> Dictionary:
	
	var serialized_outputs: Dictionary = {}
	var serialized_fixtures: Dictionary = {}

	for output: DataOutputPlugin in outputs.values():
		serialized_outputs[output.uuid] = output.serialize(mode)
	
	for channel: int in fixture_channels.keys():
		serialized_fixtures[str(channel)] = []

		for fixture: Fixture in fixture_channels[channel]:
			serialized_fixtures[str(channel)].append(fixture.serialize(mode))

	return {
		"outputs": serialized_outputs,
		"fixtures": serialized_fixtures
	}

## Called when this universe is to be deleted, see [method EngineComponent.delete]
func _on_delete_request():
	remove_outputs(outputs.values())
	remove_fixtures(fixtures.values())


## Loads this universe from a serialised universe
func _on_load_request(serialized_data: Dictionary) -> void:
		
	var just_added_fixtures: Array[Fixture] = []
	var just_added_output: Array[DataOutputPlugin] = []

	for fixture_channel: String in serialized_data.get("fixtures", []):
		for serialized_fixture: Dictionary in serialized_data.fixtures[fixture_channel]:
			var new_fixture: Fixture = Fixture.new(serialized_fixture.get("uuid"))
			new_fixture.load(serialized_fixture)
			
			add_fixture(new_fixture, -1, true)
			just_added_fixtures.append(new_fixture)
			
	on_fixtures_added.emit(just_added_fixtures, fixtures.keys())
	
	for output_uuid: String in serialized_data.get("outputs", {}).keys():
		if serialized_data.outputs[output_uuid].get("class_name", "") in ClassList.output_class_table.keys():
			var new_output: DataOutputPlugin = ClassList.output_class_table[serialized_data.outputs[output_uuid]["class_name"]].new(output_uuid)
			new_output.load(serialized_data.outputs[output_uuid])
			
			add_output(new_output, true)
			just_added_output.append(new_output)

	on_outputs_added.emit(just_added_output, outputs.keys())
