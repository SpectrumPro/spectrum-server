# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name TestExamplePass extends RefCounted
## Example test that will always pass


## Runs the test
static func run() -> bool:
    print_rich("[color=green]Example Test Passed![/color]")
    return true