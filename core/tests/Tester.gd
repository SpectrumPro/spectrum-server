# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name Tester extends RefCounted
## Runs each test and returns a summary to the user


var unit_tests: Array = [

]


var global_tests: Array = [
    CueListGlobalTester
]



enum test_type {UNIT_TESTS, GLOBAL_TESTS}


## Run all the tests in the array, then return and print the results
func run(type: test_type) -> Dictionary:

    var tests_ran: int = 0 # Number of tests ran
    var tests_passed: int = 0 # Number of tests passed
    var tests_failed: int = 0 # Number of tests failed

    # Loop through each test in the list, and run it.
    for test: Object in unit_tests if type == test_type.UNIT_TESTS else global_tests:
        print()
        var result = test.run()

        if result:
            tests_passed += 1
        else:
            tests_failed += 1
        
        tests_ran += 1

    var pass_percentage: float = 0

    if tests_ran > 0:
        pass_percentage = roundf((float(tests_passed) / float(tests_ran)) * 100)

    print()
    print_rich("[b]Tests Ran:[/b] [color=blue]" + str(tests_ran) + "[/color]")
    print_rich("[b]Tests Passed:[/b] [color=green]" + str(tests_passed) + "[/color]")
    print_rich("[b]Tests Failed:[/b] [color=red]" + str(tests_failed) + "[/color]")
    print_rich("[b]Tests Scored:[/b] [color=orange]" + str(pass_percentage) + "%[/color]")
    print()
    
    var test_results = {
        "tests_ran": tests_ran,
        "tests_passed": tests_passed,
        "tests_failed": tests_failed,
        "pass_percentage": pass_percentage
    }

    return test_results