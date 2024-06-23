# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name CueListGlobalTester extends RefCounted
## Tests the CueList by adding all the scenes in the current save file to it


static func run() -> bool:
    var state: bool = true

    var cue_list: CueList = CueList.new()
    Core.add_function(cue_list)


    if not Core.fixtures:
        state == false
        print_rich("[color=red]Core.fixtures is empty, unable to run the test[/color]")


    var red_scene: Scene = Scene.new()
    red_scene.name = "Red"
    for fixture: Fixture in Core.fixtures.values():
        red_scene.add_data(fixture, "set_color", Color.BLACK, Color.RED)


    var green_scene: Scene = Scene.new()
    green_scene.name = "Green"
    for fixture: Fixture in Core.fixtures.values():
        green_scene.add_data(fixture, "set_color", Color.BLACK, Color.GREEN)
    

    var blue_scene: Scene = Scene.new()
    blue_scene.name = "Blue"
    for fixture: Fixture in Core.fixtures.values():
        blue_scene.add_data(fixture, "set_color", Color.BLACK, Color.BLUE)

    Core.add_function(red_scene)
    Core.add_function(green_scene)
    Core.add_function(blue_scene)

    cue_list.add_cue(red_scene)
    cue_list.add_cue(green_scene)
    cue_list.add_cue(blue_scene)

    cue_list.play()

    if state:
        print_rich("[color=green]CueList Test Passed![/color]")
    else:
        print_rich("[color=red]CueList Test Failed![/color]")

    return state
