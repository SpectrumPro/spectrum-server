# Copyright (c) 2024 Liam Sherwin
# All rights reserved.

class_name Details extends RefCounted
## Static class to store program detils

static var version: String = "1.0.0 Beta"

static var copyright: String = "(c) Liam Sherwin 2024 | All rights reserved"

static var ascii_combined: String = """      
  ___              _                  
 / __|_ __  ___ __| |_ _ _ _  _ _ __  
 \\__ \\ '_ \\/ -_) _|  _| '_| || | '  \\ 
 |___/ .__/\\___\\__|\\__|_|  \\_,_|_|_|_|
     |_|"""



## Function to print all the details
static func print_startup_detils() -> void:
    var colored_text: String = TF.bold(TF.add_rainbow_gradient(ascii_combined, 6))

    print(colored_text, TF.bold(TF.white(" Version: " + TF.blue(version))))
    print()
    print(TF.cyan(copyright))
    print()