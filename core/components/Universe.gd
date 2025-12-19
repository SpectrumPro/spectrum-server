# Copyright (c) 2025 Liam Sherwin. All rights reserved.
# This file is part of the Spectrum Lighting Controller, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

class_name Universe extends EngineComponent
## Engine component for handling universes, and there outputs


## Emited when a fixture / fixtures are added to this universe
signal on_fixtures_added(fixtures: Array[DMXFixture])

## Emited when a fixture / fixtures are removed from this universe
signal on_fixtures_removed(fixtures: Array[DMXFixture])

## Emited when a output / outputs are added to this universe
signal on_outputs_added(outputs: Array[DMXOutput])

## Emited when a output / outputs are removed from this universe
signal on_outputs_removed(outputs: Array[DMXOutput])


## Dictionary containing all the fixtures in this universe, stored as channel:Array[fixture]
var _fixture_channels: Dictionary[int, Array] = {} 

## Dictionary containing all the fixtures in this universe, stored as uuid:fixture
var _fixtures: Dictionary[String, DMXFixture] = {}

## Dictionary containing all the outputs in this universe
var _outputs: Dictionary[String, DMXOutput] = {} 

## Dictionary containing the current dmx data of this universe, this is constantly updated, so modifying this manualy will cause unexpected outcomes
var _dmx_data: Dictionary[int, int] = {} 

## Stores dmx overrides, sotred at {channel:value}. theese values will always override other data passed to this universe
var _dmx_overrides: Dictionary[int, int] = {}


## Called when this EngineComponent is ready
func _init(p_uuid: String = UUID_Util.v4(), p_name: String = _name) -> void:
	super._init(p_uuid, p_name)
	
	set_name("Universe")
	_set_self_class("Universe")

	var zero: Dictionary
	for i in range(1, 513):
		zero[i] = 0
	
	set_data(zero)

	_settings_manager.register_networked_methods_auto([
		create_output,
		add_output,
		add_outputs,
		remove_output,
		remove_outputs,
		add_fixture,
		add_fixtures,
		remove_fixture,
		remove_fixtures,
		get_fixture_by_channel,
		get_outputs,
		get_fixtures,
		set_dmx_override,
		remove_dmx_override,
		remove_all_dmx_overrides,
	])

	_settings_manager.set_method_allow_deserialize(add_output)
	_settings_manager.set_method_allow_deserialize(add_outputs)

	_settings_manager.register_networked_signals_auto([
		on_fixtures_added,
		on_fixtures_removed,
		on_outputs_added,
		on_outputs_removed,
	])

	_settings_manager.set_signal_allow_serialize(on_outputs_added)


## Creates a new output by class name
func create_output(p_output_class_name: String) -> DMXOutput:
	if not ClassList.has_class(p_output_class_name, "DMXOutput"):
		return null

	var new_output: DMXOutput = ClassList.get_class_script(p_output_class_name).new()
	add_output(new_output)

	return new_output


## Adds a new output to this universe, returning false if this output can't be added
func add_output(p_output: DMXOutput, p_no_signal: bool = false) -> bool:
	if p_output in _outputs.values():
		return false

	_outputs[p_output.uuid()] = p_output
	
	p_output.on_delete_requested.connect(remove_output.bind(p_output), CONNECT_ONE_SHOT)
	Core._output_timer.connect(p_output.output)
	ComponentDB.register_component(p_output)
	
	p_output.dmx_data = _dmx_data

	if not p_no_signal:
		on_outputs_added.emit([p_output])
	
	return true


## Adds mutiple outputs to this univere at once
func add_outputs(p_outputs: Array, p_no_signal: bool = false) -> void:
	var just_added_outputs: Array[DMXOutput] = []

	for output: Variant in p_outputs:
		if output is DMXOutput:
			if add_output(output, true):
				just_added_outputs.append(output)

	if not p_no_signal and just_added_outputs:
		on_outputs_added.emit(just_added_outputs)


## Removes a output from this engine
func remove_output(p_output: DMXOutput, p_no_signal: bool = false) -> bool: 
	if not p_output in _outputs.values():
		return false
	
	ComponentDB.deregister_component(p_output)
	_outputs.erase(p_output.uuid())

	if not p_no_signal:
		on_outputs_removed.emit([p_output])
	
	return true


## Removes mutiple outputs from this universe
func remove_outputs(p_outputs: Array, p_no_signal: bool = false) -> void:
	var just_removed_outputs: Array[DMXOutput] = []

	for output: Variant in p_outputs:
		if output is DMXOutput:
			if remove_output(output, true):
				just_removed_outputs.append(output)	
	
	if not p_no_signal and just_removed_outputs:
		on_outputs_removed.emit(just_removed_outputs)


## Adds a new fixture to this universe, from a pre exitsing fixture, also see [method Universe.add_fixture_from_manifest] [br]
## If [param channel] is -1 the channel in [member DMXFixture.channel] will be used [br]
## False is returned if the fixture is already part of this universe [br]
## Caution, if you add a fixture that is already part of another universe, the channel will be over written and the fixture will start to output on both universes at the same channel
func add_fixture(p_fixture: DMXFixture, p_channel: int = -1, p_no_signal: bool = false) -> bool:
	if p_fixture in _fixtures.values():
		return false

	var fixture_channel: int = p_fixture.get_channel() if p_channel == -1 else p_channel
	p_fixture.set_channel(fixture_channel, true)
	p_fixture.set_universe_from_universe(self, true)
	
	if not _fixture_channels.get(fixture_channel):
		_fixture_channels[fixture_channel] = []
	
	_fixture_channels[fixture_channel].append(p_fixture)
	_fixtures[p_fixture.uuid()] = p_fixture

	p_fixture.on_delete_requested.connect(remove_fixture.bind(p_fixture), CONNECT_ONE_SHOT)
	p_fixture.dmx_data_updated.connect(self.set_data)
	set_data(p_fixture.get_current_dmx())

	if not p_no_signal:
		on_fixtures_added.emit([p_fixture])
	
	return true


## Adds mutiple fixtures to this universe
func add_fixtures(p_fixtures: Array, p_no_signal: bool = false) -> void:
	var just_added_fixtures: Array[DMXFixture] = []

	for fixture: Variant in p_fixtures:
		if fixture is DMXFixture:
			if add_fixture(fixture, -1, true):
				just_added_fixtures.append(fixture)
	
	if not p_no_signal and just_added_fixtures:
		on_fixtures_added.emit(just_added_fixtures)


## Removes a fixture from this universe
func remove_fixture(p_fixture: DMXFixture, p_no_signal: bool = false) -> bool:	
	if not p_fixture in _fixtures.values():
		return false
	
	_fixtures.erase(p_fixture.uuid())
	p_fixture.dmx_data_updated.disconnect(set_data)

	if _fixture_channels.has(p_fixture.get_channel()):
		_fixture_channels[p_fixture.get_channel()].erase(p_fixture)
		
		if not _fixture_channels[p_fixture.get_channel()]:
			_fixture_channels.erase(p_fixture.get_channel())

	if not p_no_signal:
		on_fixtures_removed.emit([p_fixture])

	return true
		


## Removes mutiple fixtures from this universe
func remove_fixtures(p_fixtures: Array, p_no_signal: bool = false) -> void:
	var just_removed_fixtures: Array[DMXFixture] = []
	
	for fixture: Variant in p_fixtures:
		if fixture is DMXFixture:
			if remove_fixture(fixture, true):
				just_removed_fixtures.append(fixture)		
	
	if not p_no_signal and just_removed_fixtures:
		on_outputs_removed.emit(just_removed_fixtures)
		

## Returns all fixture on the given channel
func get_fixture_by_channel(p_channel: int) -> Array[DMXFixture]:
	var fixtures: Array[DMXFixture] = []
	fixtures.assign(_fixture_channels.get(p_channel, []))

	return fixtures


## Gets all the outputs in this universe
func get_outputs() -> Dictionary:
	return _outputs.duplicate()


## Gets all the fixtures in this universe
func get_fixtures() -> Dictionary:
	return _fixtures.duplicate()


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

	for output: DMXOutput in _outputs.values():
		output.dmx_data = compiled_dmx_data
		

## Serializes this universe
func _on_serialize_request(p_flags: int) -> Dictionary:
	var serialized_outputs: Dictionary[String, Dictionary] = {}
	var serialized_fixtures: Dictionary[String, Array] = {}

	for output: DMXOutput in _outputs.values():
		serialized_outputs[output.uuid()] = output.serialize(p_flags)
	
	for channel: int in _fixture_channels.keys():
		serialized_fixtures[str(channel)] = []

		for fixture: DMXFixture in _fixture_channels[channel]:
			serialized_fixtures[str(channel)].append(fixture.uuid())

	return {
		"outputs": serialized_outputs,
		"fixtures": serialized_fixtures
	}


## Called when this universe is to be deleted, see [method EngineComponent.delete]
func _on_delete_request():
	for output: DMXOutput in _outputs.values():
		output.delete(true)	

	remove_fixtures(_fixtures.values())


## Loads this universe from a serialised universe
func _on_load_request(p_serialized_data: Dictionary) -> void:
		
	var just_added_fixtures: Array[DMXFixture] = []
	var just_added_output: Array[DMXOutput] = []

	for fixture_channel: String in p_serialized_data.get("fixtures", []):
		for fixture_uuid: String in p_serialized_data.fixtures[fixture_channel]:
			var fixture: EngineComponent = ComponentDB.get_component(fixture_uuid)

			if fixture is DMXFixture:
				add_fixture(fixture, -1, true)
				just_added_fixtures.append(fixture)
			
	
	for output_uuid: String in p_serialized_data.get("outputs", {}).keys():
		var classname: String = p_serialized_data.outputs[output_uuid].get("class_name", "")
		if ClassList.has_class(classname, "DMXOutput"):
			var new_output: DMXOutput = ClassList.get_class_script(classname).new(output_uuid)
			new_output.load(p_serialized_data.outputs[output_uuid])
			
			add_output(new_output, true)
			just_added_output.append(new_output)

	if just_added_fixtures:
		on_fixtures_added.emit(just_added_fixtures)
	
	if just_added_output:
		on_outputs_added.emit(just_added_output)
