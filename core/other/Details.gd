# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name Details extends RefCounted
## Static class to store program detils

static var version: String = "1.0.0 Beta"

static var schema_version: int = 2

static var copyright: String = "(c) 2024 Liam Sherwin. Licensed under GPL v3."

static var ascii_name: String = """      
  ___              _                  
 / __|_ __  ___ __| |_ _ _ _  _ _ __  
 \\__ \\ '_ \\/ -_) _|  _| '_| || | '  \\ 
 |___/ .__/\\___\\__|\\__|_|  \\_,_|_|_|_|
     |_|"""



## Function to print all the details
static func print_startup_detils() -> void:
    var colored_text: String = TF.bold(TF.add_rainbow_gradient(ascii_name, 6))

    print(colored_text, TF.bold(TF.white(" Version: " + TF.blue(version))))
    print()
    print(TF.cyan(copyright))
    print()