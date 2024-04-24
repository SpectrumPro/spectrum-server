# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name Universe extends EngineComponent
## Engine component for handling universes, and there outputs

signal on_fixture_name_changed(fixture: Fixture, new_name: String)
signal on_fixtures_added(fixtures: Array[Fixture])
signal on_fixtures_deleted(fixture_uuids: Array)

signal on_outputs_added(outputs: Array[DataOutputPlugin]) ## Emited when an output or outputs are added
signal on_outputs_removed(outputs: Array[DataOutputPlugin]) ## Emited when an output or outputs are removed

var fixtures: Dictionary = {} ## Dictionary containing all the fixtures in this universe
var outputs: Dictionary = {} ## Dictionary containing all the outputs in this universe

var dmx_data: Dictionary = {} ## Dictionary containing the current dmx data of this universe, this is constantly updated, so modifying this manualy will cause unexpected outcomes

## Adds a new output to this universe, output must be in [member CoreEngine.output_plugins]. Otherwise a DataOutputPlugin will be added
func new_output(type: String, no_signal: bool = false) -> DataOutputPlugin:	
	
	var new_output: DataOutputPlugin

	# Check if type is a valid DataOutputPlugin, if not create a new instance of DataOutputPlugin
	if type in Core.output_plugins:
		new_output = Core.output_plugins[type].new()
	else:
		new_output = DataOutputPlugin.new()

	add_output(new_output, no_signal)

	return new_output


## Adds a already created output plugin to this universe
func add_output(output: DataOutputPlugin, no_signal: bool = false) -> void:
	Core._output_timer.connect(output.output)
	
	outputs[output.uuid] = output
	
	if not no_signal:
		on_outputs_added.emit([output])


## Removes an output from this universe. This does not delete the output, but will only disconnect it from this universe 
func remove_output(output: DataOutputPlugin, no_signal: bool = false) -> void:
	outputs.erase(output.uuid)

	Core._output_timer.disconnect(output.output)
	
	if not no_signal:
		on_outputs_removed.emit([output])


## Removes a list of outputs, see [method Universe.remove_output]
func remove_outputs(outputs_to_remove: Array, no_signal: bool = false) -> void:
	
	var removed_outputs: Array[DataOutputPlugin] = []
	
	for output in outputs_to_remove:
		if output is DataOutputPlugin:
			remove_output(output, true)
			removed_outputs.append(output)
	
	if not no_signal:
		on_outputs_removed.emit(removed_outputs)


func new_fixture(manifest: Dictionary, mode:int, channel: int = -1, quantity:int = 1, offset:int = 0, uuid: String = "", no_signal: bool = false) -> bool:
	## Adds a new fixture to this universe, if the channels are already in use false it returned
	
	if is_channel_used(range(channel, len(manifest.modes.values()[mode].channels))):
		return false
	
	var just_added_fixtures: Array[Fixture] = []
	
	for i: int in range(quantity):
		var channel_index = channel + offset
		channel_index += (len(manifest.modes.values()[mode].channels)) * i
		
		var new_fixture = Fixture.new({
			"universe": self,
			"channel": channel_index,
			"mode": mode,
			"manifest": manifest
		})

		
		fixtures[channel_index] = new_fixture
		Core.fixtures[new_fixture.uuid] = new_fixture
		just_added_fixtures.append(new_fixture)
		
	if not no_signal:
		on_fixtures_added.emit(just_added_fixtures)
	
	return true

func remove_fixture(fixture: Fixture, no_signal: bool = false):
	## Removes a fixture from this universe
	
	var fixture_uuid: String = fixture.uuid
	
	if fixture in Core.selected_fixtures:
		Core.deselect_fixtures([fixture])
	
	fixtures.erase(fixture.channel)
	Core.fixtures.erase(fixture.uuid)
	fixture.delete()
	fixture.free()
	
	if not no_signal:
		on_fixtures_deleted.emit([fixture_uuid])


func remove_fixtures(fixtures_to_remove: Array, no_signal: bool = false) -> void:
	## Removes mutiple fixtures at once
	
	var uuids: Array = []
	
	for fixture: Fixture in fixtures_to_remove:
		uuids.append(fixture.uuid)
		remove_fixture(fixture, true)
	
	if not no_signal:
		on_fixtures_deleted.emit(uuids)


func is_channel_used(channels: Array) -> bool: 
	## Checks if any of the channels in channels are used by another fixture
	return false


func delete():
	## Called when this universe is about to be deleted, it will remove all outputs and fixtures from this universe
	
	remove_fixtures(fixtures.values())
	remove_outputs(outputs.values())


func set_data(data: Dictionary):
	## Set dmx data, layers will be added soom
	dmx_data.merge(data, true)
	_compile_and_send()


func _compile_and_send():
	var compiled_dmx_data: Dictionary = dmx_data
	for output in outputs.values():
		output.set_data(compiled_dmx_data)
		

## Serializes this universe
func on_serialize_request() -> Dictionary:
	
	var serialized_outputs = {}

	for output: DataOutputPlugin in outputs.values():
		serialized_outputs[output.uuid] = output.serialize()
	
	return {
		"outputs": serialized_outputs
	}


func load_from(serialised_data: Dictionary) -> void:
	## Loads this universe from a serialised universe
	
	self.name = serialised_data.get("name", "")
	
	fixtures = {}
	outputs = {}
	
	for fixture_uuid: String in serialised_data.get("fixtures", {}):
		var serialised_fixture: Dictionary = serialised_data.fixtures[fixture_uuid]
		
		var fixture_brand: String = serialised_fixture.get("meta", {}).get("fixture_brand", "Generic")
		var fixture_name: String = serialised_fixture.get("meta", {}).get("fixture_name", "Dimmer")
		
		var fixture_manifest: Dictionary = Core.fixtures_definitions[fixture_brand][fixture_name]
		var channel: int = serialised_fixture.get("channel", 1)
		
		var new_fixture = Fixture.new({
			"universe": self,
			"channel": channel,
			"mode": serialised_fixture.get("mode", 0),
			"manifest": fixture_manifest,
			"uuid": fixture_uuid
		})
		
		
		fixtures[channel] = new_fixture
		Core.fixtures[new_fixture.uuid] = new_fixture
		
	
	on_fixtures_added.emit(fixtures.values())
	
	
	for output_uuid: String in serialised_data.get("outputs"):
		var serialised_output: Dictionary = serialised_data.outputs[output_uuid]
		
		var new_output: DataOutputPlugin = Core.output_plugins[serialised_output.file].plugin.new(serialised_output)
		new_output.uuid = output_uuid
		Core.output_timer.connect(new_output.send_packet)
		
		
		outputs[new_output.uuid] = new_output
	
	on_outputs_added.emit(outputs.values())