# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name CueListGlobalTester extends RefCounted
## Tests the CueList by adding a set of Cues to it


static func run() -> bool:
    var state: bool = true

    var cue_list: CueList = CueList.new()
    cue_list.name = "Global Test CueList"
    Core.add_function(cue_list)

    var colors: Array = ["RED", "ORANGE", "YELLOW", "GREEN", "BLUE", "PURPLE"]

    if Core.fixtures:

        var previous_fixtures: Array[Fixture] = []

        for color_string: String in colors:            
            var new_cue: Cue = Cue.new()
            new_cue.name = "Color: " + color_string

            for fixture: Fixture in Core.fixtures.values():
                new_cue.store_data(fixture, "set_color", Color(color_string))
            
            cue_list.add_cue(new_cue)
            

    else:
        print_rich("[color=red]Core.fixtures is empty, unable to run the test[/color]")
        state = false
    
    if state:
        print_rich("[color=green]CueList Test Passed![/color]")
    else:
        print_rich("[color=red]CueList Test Failed![/color]")

    return state
