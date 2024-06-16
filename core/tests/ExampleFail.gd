# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name TestExampleFail extends RefCounted
## Example test that will always fail


## Runs the test
static func run() -> bool:
    print_rich("[color=red]Example Test Faild![/color]")
    return false