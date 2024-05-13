extends Control

var i: int = 0

var state: bool = false

var data: Dictionary = {}

func _ready() -> void:
	#for i in range(10000):
		#var new_universe: Universe = Universe.new()
		#Core.add_universe("New Universe", new_universe)
		#
		#
		#i = i + 1
		#$IndexCounter.text = str(i)
		#$FrameCounter.text = str(Engine.get_frames_per_second())
		#
		#print(len(Core.universes))
#
		#await get_tree().process_frame 
	pass


func _on_button_pressed() -> void:

	for i in range(5000):
		i=i+1
		print(i)
		
		data[UUID_Util.v4()] = Universe.new()
		
		await get_tree().process_frame



func _on_remove_pressed() -> void:
	for uuid in data.keys():
		data.erase(uuid)
		await get_tree().process_frame
		
	print(data)
