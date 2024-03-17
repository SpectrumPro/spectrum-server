# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

extends Control
## Temp ui panel for triggering scenes

func _ready() -> void:
	Core.scene_added.connect(self._reload_buttons)


func _reload_buttons(_scene) -> void:
	## Reloads the buttons in the ui
	
	for old_button: Button in self.get_children():
		self.remove_child(old_button)
		old_button.queue_free()
	
	for scene: Scene in Core.scenes.values():
		var button_to_add: Button = Button.new()
		
		button_to_add.text = scene.name
		button_to_add.custom_minimum_size = Vector2(50, 50)
		button_to_add.toggle_mode = true
		button_to_add.toggled.connect(
			func(state):
				scene.enabled = state
		)
		
		self.add_child(button_to_add)
