# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name Details extends RefCounted
## Static class to store program detils

static var version: String = "1.0.0 Beta"

static var schema_version: int = 3

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
  


## Oh no, we've crashed... print something fun????
static func shit() -> void:
  print(TF.error(
      [
      "All the lights went out... but hey, that’s what you wanted, right? (Next time, save your scene before triggering the apocalypse.)",
      "DMX? More like 'DM eXploded'. (Did you test that fixture profile?)",
      "We blame the lights. They blame the operator. It's a cycle. (Try restarting the software. Or your life choices.)",
      "The fixtures unionized and refused your last command. (Apparently, strobes have feelings too.)",
      "You’ve unlocked DMX Hard Mode! Everything’s broken. (No cheat codes available.)",
      "Warning: Smoke machines detected an error... wait, that’s just real smoke. (Good luck with that.)",
      "Too many RGB sliders to handle. Now everything’s magenta forever. (Magenta is a vibe, though.)",
      "Error 404: Your lighting designer’s sanity not found. (Restore from backup?)",
      "Your LEDs just got jealous of the moving heads. System crash! (Make sure all fixtures feel appreciated.)",
      "Blackout mode engaged… permanently. (But hey, isn’t that what a blackout is?)",
      "Goboflush.exe has stopped working. Fixture patterns lost in the void. (Gobos are temporary; drama is forever.)",
      "The dimmer pack overloaded and took the software down with it. (Have you tried using fewer lights? Nah, me neither.)",
      "DMX address conflict detected: everyone’s fighting over Channel 1. (No winners in this game of Thrones.)",
      "Disco inferno, but not the good kind. (Consider an extinguisher near the rig.)",
      "You broke it. Go tell the stage manager and watch the panic unfold. (This is why we can’t have nice things.)",
      "ERROR: You can't just plug MIDI into DMX like that! (Also, nice try.)",
      "Flash 'n Trash mode activated. Software gave up. (Cue the chaos music.)",
      "DMX Kingpin has disconnected your universe. (Too much power in one cable.)",
      "Lights were set to 'Party Mode' and crashed the system. (The fixtures know how to have a good time.)",
      "You’ve reached the end of the rainbow. No pot of gold here, just errors. (Try again.)",
      "You’ve been outshone by a $20 PAR can. Software shutting down in shame. (Upgrade time?)",
      "The lights revolted and declared their independence. (Long live the fixture rebellion!)",
      "Universe 1 is fine. Universe 2 is fine. Universe 3… imploded. (Never trust Universe 3.)"
    ].pick_random()
  ))