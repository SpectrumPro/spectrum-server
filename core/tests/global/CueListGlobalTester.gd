# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name CueListGlobalTester extends RefCounted
## Tests the CueList by adding a set of Cues to it


static func run() -> bool:
    var state: bool = true

    var cue_list: CueList = CueList.new()
    cue_list.name = "Global Test CueList"
    Core.add_function(cue_list)

    var colors: Array = ["BLACK", "RED", "YELLOW", "GREEN", "BLUE", "PURPLE"]

    if Core.fixtures:

        var previous_fixtures: Array[Fixture] = []

        for fixture: Fixture in Core.fixtures.values():
            var index: int = Core.fixtures.values().find(fixture) + 1
            var color_string: String = colors[remap(index - 1, 0, len(Core.fixtures) - 1, 0, len(colors) - 1)]

            var new_cue: Cue = Cue.new()
            new_cue.name = "Step: " + color_string

            previous_fixtures.append(fixture)
            for previous_fixture: Fixture in previous_fixtures:
                new_cue.store_data(fixture, "set_color", Color(color_string), Color.BLACK)
            
            cue_list.add_cue(new_cue, index)
            

    else:
        print_rich("[color=red]Core.fixtures is empty, unable to run the test[/color]")
        state = false
    
    if state:
        print_rich("[color=green]CueList Test Passed![/color]")
    else:
        print_rich("[color=red]CueList Test Failed![/color]")

    return state
