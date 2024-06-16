# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name SceneCreationTester extends RefCounted
## Tests the Scene class, and engine scene methods


## Runs the test
static func run() -> bool:
    var state: bool = true


    var new_scene = Core.add_scene()

    if not new_scene is Scene:
        state = false
        print("Core.add_scene() failed to return a scene")

    if not Core.scenes.get(new_scene.uuid, null) == new_scene:
        state = false
        print_rich("[color=red]Core.add_scene() failed to add scene to CoreEngine.scenes[/color]")


    if state:
        print_rich("[color=green]Scene Creation Test Passed![/color]")
    else:
        print_rich("[color=red]Scene Creation Test Failed![/color]")

    return state
