# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name FunctionCreationTester extends RefCounted
## Tests the function class, and engine function methods


## Runs the test
static func run() -> bool:
    var state: bool = true


    var new_function = Core.add_function(Function.new())

    if not new_function is Function:
        state = false
        print("Core.add_function() failed to return a function")

    if not Core.functions.get(new_function.uuid, null) == new_function:
        state = false
        print_rich("[color=red]Core.add_function() failed to add function to CoreEngine.functions[/color]")


    if state:
        print_rich("[color=green]Function Creation Test Passed![/color]")
    else:
        print_rich("[color=red]Function Creation Test Failed![/color]")

    return state
