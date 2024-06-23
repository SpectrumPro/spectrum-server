# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name ClassListTester extends RefCounted
## Tester script for the ClassList


## Runs the test
static func run() -> bool:
    var state: bool = true

    var expected_result = ClassList.component_class_table.duplicate()
    expected_result.merge(ClassList.function_class_table)
    expected_result.merge(ClassList.output_class_table)
        
    if not expected_result == ClassList.global_class_table:
        state = false
        print_rich("[color=red]ClassList.global_class_table failed to return correct result[/color]")

    if state:
        print_rich("[color=green]ClassList Test Passed![/color]")
    else:
        print_rich("[color=red]ClassList Test Failed![/color]")

    return state