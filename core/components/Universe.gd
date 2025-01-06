# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name Universe extends EngineComponent
## Engine component for handling universes, and there outputs


## Emited when a fixture / fixtures are added to this universe, contains a list of all fixture uuids for server-client synchronization
signal on_fixtures_added(fixtures: Array[Fixture])

## Emited when a fixture / fixtures are removed from this universe, contains a list of all fixture uuids for server-client synchronization
signal on_fixtures_removed(fixtures: Array[Fixture])

## Emited when a output / outputs are added to this universe, contains a list of all output uuids for server-client synchronization
signal on_outputs_added(outputs: Array[DataOutputPlugin])

## Emited when a output / outputs are removed from this universe, contains a list of all output uuids for server-client synchronization
signal on_outputs_removed(outputs: Array[DataOutputPlugin])


## Dictionary containing all the fixtures in this universe, stored as channel:Array[fixture]
var _fixture_channels: Dictionary = {} 

## Dictionary containing all the fixtures in this universe, stored as uuid:fixture
var _fixtures: Dictionary = {}

## Dictionary containing all the outputs in this universe
var _outputs: Dictionary = {} 

## Dictionary containing the current dmx data of this universe, this is constantly updated, so modifying this manualy will cause unexpected outcomes
var _dmx_data: Dictionary = {} 

## Stores dmx overrides, sotred at {channel:value}. theese values will always override other data passed to this universe
var _dmx_overrides: Dictionary = {}


## Called when this EngineComponent is ready
func _component_ready() -> void:
	set_name("Universe")
	set_self_class("Universe")



## Creates a new output by class name
func create_output(p_output_class_name: String) -> DataOutputPlugin:
	if not p_output_class_name in ClassList.output_class_table:
		return null

	var new_output: DataOutputPlugin = ClassList.output_class_table[p_output_class_name].new()
	add_output(new_output)

	return new_output


## Adds a new output to this universe, returning false if this output can't be added
func add_output(p_output: DataOutputPlugin, p_no_signal: bool = false) -> bool:
	if p_output in _outputs.values():
		return false

	_outputs[p_output.uuid] = p_output
	
	p_output.on_delete_requested.connect(remove_output.bind(p_output), CONNECT_ONE_SHOT)
	Core._output_timer.connect(p_output.output)
	ComponentDB.register_component(p_output)
	

	if not p_no_signal:
		on_outputs_added.emit([p_output])
	
	return true


## Adds mutiple outputs to this univere at once
func add_outputs(p_outputs: Array, p_no_signal: bool = false) -> void:
	var just_added_outputs: Array[DataOutputPlugin] = []

	for output: Variant in p_outputs:
		if output is DataOutputPlugin:
			if add_output(output, true):
				just_added_outputs.append(output)

	if not p_no_signal and just_added_outputs:
		on_outputs_added.emit(just_added_outputs)


## Removes a output from this engine
func remove_output(p_output: DataOutputPlugin, p_no_signal: bool = false) -> bool: 
	if not p_output in _outputs.values():
		return false
	
	ComponentDB.deregister_component(p_output)
	_outputs.erase(p_output.uuid)

	if not p_no_signal:
		on_outputs_removed.emit([p_output])
	
	return true


## Removes mutiple outputs from this universe
func remove_outputs(p_outputs: Array, p_no_signal: bool = false) -> void:
	var just_removed_outputs: Array[DataOutputPlugin] = []

	for output: Variant in p_outputs:
		if output is DataOutputPlugin:
			if remove_output(output, true):
				just_removed_outputs.append(output)	
	
	if not p_no_signal and just_removed_outputs:
		on_outputs_removed.emit(just_removed_outputs)



## Adds a new fixture to this universe, from a fixture manifest
func create_fixture_from_manifest(p_fixture_manifest: Dictionary, p_mode: int, p_channel: int, p_no_signal: bool = false) -> Fixture:
	var new_fixture: Fixture = Fixture.new()
	
	new_fixture.name = p_fixture_manifest.info.name
	new_fixture.channel = p_channel
	new_fixture.mode = p_mode
	new_fixture.set_manifest(p_fixture_manifest, p_fixture_manifest.info.manifest_path)
	add_fixture(new_fixture, p_channel, p_no_signal)

	return new_fixture


## Adds a new fixture to this universe, from a pre exitsing fixture, also see [method Universe.add_fixture_from_manifest] [br]
## If [param channel] is -1 the channel in [member Fixture.channel] will be used [br]
## False is returned if the fixture is already part of this universe [br]
## Caution, if you add a fixture that is already part of another universe, the channel will be over written and the fixture will start to output on both universes at the same channel
func add_fixture(p_fixture: Fixture, p_channel: int = -1, p_no_signal: bool = false) -> bool:
	if p_fixture in _fixtures.values():
		return false

	var fixture_channel: int = p_fixture.channel if p_channel == -1 else p_channel
	p_fixture.channel = fixture_channel
	
	if not _fixture_channels.get(fixture_channel):
		_fixture_channels[fixture_channel] = []
	
	_fixture_channels[fixture_channel].append(p_fixture)
	_fixtures[p_fixture.uuid] = p_fixture

	ComponentDB.register_component(p_fixture)
	p_fixture.on_delete_requested.connect(remove_fixture.bind(p_fixture), CONNECT_ONE_SHOT)
	p_fixture.fixture_data_changed.connect(self.set_data)

	if not p_no_signal:
		on_fixtures_added.emit([p_fixture])
	
	return true


## Adds mutiple fixtures to this universe
func add_fixtures(p_fixtures: Array, p_no_signal: bool = false) -> void:
	var just_added_fixtures: Array[Fixture] = []

	for fixture: Variant in p_fixtures:
		if fixture is Fixture:
			if add_fixture(fixture):
				just_added_fixtures.append(fixture)
	
	if not p_no_signal and just_added_fixtures:
		on_fixtures_added.emit(just_added_fixtures)


## Adds mutiple new fixtures to this universe, from a fixture manifest
## start_channel is the first channel that will be asigned
## offset adds a channel gap between each fixture
func add_fixtures_from_manifest(p_fixture_manifest: Dictionary, p_mode: int, p_start_channel: int, p_quantity: int, p_offset: int = 0, p_no_signal: bool = false) -> Array[Fixture]:
	var just_added_fixtures: Array[Fixture] = []
	
	for index: int in range(p_quantity):
		var channel_index = p_start_channel + p_offset
		channel_index += len(p_fixture_manifest.modes[p_mode].channels) * index

		var new_fixture: Fixture = create_fixture_from_manifest(p_fixture_manifest, p_mode, channel_index, true)
		just_added_fixtures.append(new_fixture)
		
	if not p_no_signal and just_added_fixtures:
		on_fixtures_added.emit(just_added_fixtures)
	
	return just_added_fixtures


## Removes a fixture from this universe
func remove_fixture(p_fixture: Fixture, p_no_signal: bool = false) -> bool:	
	if not p_fixture in _fixtures.values():
		return false
	
	_fixtures.erase(p_fixture.uuid)
	_fixture_channels[p_fixture.channel].erase(p_fixture)

	p_fixture.fixture_data_changed.disconnect(set_data)

	if not _fixture_channels[p_fixture.channel]:
		_fixture_channels.erase(p_fixture.channel)

	ComponentDB.deregister_component(p_fixture)	

	if not p_no_signal:
		on_fixtures_removed.emit([p_fixture])

	return true
		


## Removes mutiple fixtures from this universe
func remove_fixtures(p_fixtures: Array, p_no_signal: bool = false) -> void:
	var just_removed_fixtures: Array[Fixture] = []
	
	for fixture: Variant in p_fixtures:
		if fixture is Fixture:
			if remove_fixture(fixture, true):
				just_removed_fixtures.append(fixture)		
	
	if not p_no_signal and just_removed_fixtures:
		on_outputs_removed.emit(just_removed_fixtures)
		

## Returns all fixture on the given channel
func get_fixture_by_channel(p_channel: int) -> Array[Fixture]:
	var fixtures: Array[Fixture] = []
	fixtures.assign(_fixture_channels.get(p_channel, []))

	return fixtures


## Set dmx data, data should be stored as channel:value
func set_data(p_data: Dictionary):
	_dmx_data.merge(p_data, true)
	_compile_and_send()


## Sets a manual dmx channel to the set value
func set_dmx_override(p_channel: int, p_value: int) -> void:
	_dmx_overrides[p_channel] = p_value
	_compile_and_send()


## Removes a manual dmx override
func remove_dmx_override(p_channel: int) -> void:
	_dmx_overrides.erase(p_channel)
	_compile_and_send()


## Removes all dmx overrides
func remove_all_dmx_overrides() -> void:
	_dmx_overrides.clear()
	_compile_and_send()


## Compile the dmx data, and send to the outputs
func _compile_and_send():
	var compiled_dmx_data: Dictionary = _dmx_data.duplicate()
	compiled_dmx_data.merge(_dmx_overrides, true)

	for output: DataOutputPlugin in _outputs.values():
		output.dmx_data = compiled_dmx_data
		

## Serializes this universe
func _on_serialize_request(p_mode: int = Core.SERIALIZE_MODE_NETWORK) -> Dictionary:
	var serialized_outputs: Dictionary = {}
	var serialized_fixtures: Dictionary = {}

	for output: DataOutputPlugin in _outputs.values():
		serialized_outputs[output.uuid] = output.serialize(p_mode)
	
	for channel: int in _fixture_channels.keys():
		serialized_fixtures[str(channel)] = []

		for fixture: Fixture in _fixture_channels[channel]:
			serialized_fixtures[str(channel)].append(fixture.serialize(p_mode))

	return {
		"outputs": serialized_outputs,
		"fixtures": serialized_fixtures
	}


## Called when this universe is to be deleted, see [method EngineComponent.delete]
func _on_delete_request():
	remove_outputs(_outputs.values())
	remove_fixtures(_fixtures.values())


## Loads this universe from a serialised universe
func _on_load_request(p_serialized_data: Dictionary) -> void:
		
	var just_added_fixtures: Array[Fixture] = []
	var just_added_output: Array[DataOutputPlugin] = []

	for fixture_channel: String in p_serialized_data.get("fixtures", []):
		for serialized_fixture: Dictionary in p_serialized_data.fixtures[fixture_channel]:
			var new_fixture: Fixture = Fixture.new(serialized_fixture.get("uuid"))
			new_fixture.load(serialized_fixture)
			
			add_fixture(new_fixture, -1, true)
			just_added_fixtures.append(new_fixture)
			
	
	for output_uuid: String in p_serialized_data.get("outputs", {}).keys():
		if p_serialized_data.outputs[output_uuid].get("class_name", "") in ClassList.output_class_table.keys():
			var new_output: DataOutputPlugin = ClassList.output_class_table[p_serialized_data.outputs[output_uuid]["class_name"]].new(output_uuid)
			new_output.load(p_serialized_data.outputs[output_uuid])
			
			add_output(new_output, true)
			just_added_output.append(new_output)

	if just_added_fixtures:
		on_fixtures_added.emit(just_added_fixtures)
	
	if just_added_output:
		on_outputs_added.emit(just_added_output)
