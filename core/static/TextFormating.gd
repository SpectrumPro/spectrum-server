# Copyright (c) 2024 Liam Sherwin, All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.

class_name TF extends RefCounted
## A utility class for adding color and text effects using ANSI escape codes.


# Text attributes
const RESET = "\u001b[0m"  ## Resets all text attributes to default.
const BOLD = "\u001b[1m"  ## Makes text bold.
const DIM = "\u001b[2m"  ## Makes text dim.
const ITALIC = "\u001b[3m"  ## Makes text italic.
const REVERSE = "\u001b[7m"  ## Reverses foreground and background colors.
const HIDDEN = "\u001b[8m"  ## Hides text.
const STRIKETHROUGH = "\u001b[9m"  ## Strikethrough text.


# Foreground colors
const FG_BLACK = "\u001b[30m"  ## Black text color.
const FG_RED = "\u001b[31m"  ## Red text color.
const FG_GREEN = "\u001b[32m"  ## Green text color.
const FG_YELLOW = "\u001b[33m"  ## Yellow text color.
const FG_BLUE = "\u001b[34m"  ## Blue text color.
const FG_MAGENTA = "\u001b[35m"  ## Magenta text color.
const FG_CYAN = "\u001b[36m"  ## Cyan text color.
const FG_WHITE = "\u001b[37m"  ## White text color.
const FG_DEFAULT = "\u001b[39m"  ## Default text color.


# Background colors
const BG_BLACK = "\u001b[40m"  ## Black background color.
const BG_RED = "\u001b[41m"  ## Red background color.
const BG_GREEN = "\u001b[42m"  ## Green background color.
const BG_YELLOW = "\u001b[43m"  ## Yellow background color.
const BG_BLUE = "\u001b[44m"  ## Blue background color.
const BG_MAGENTA = "\u001b[45m"  ## Magenta background color.
const BG_CYAN = "\u001b[46m"  ## Cyan background color.
const BG_WHITE = "\u001b[47m"  ## White background color.
const BG_DEFAULT = "\u001b[49m"  ## Default background color.


# Bright foreground colors
const FG_BRIGHT_BLACK = "\u001b[90m"  ## Bright black text color.
const FG_BRIGHT_RED = "\u001b[91m"  ## Bright red text color.
const FG_BRIGHT_GREEN = "\u001b[92m"  ## Bright green text color.
const FG_BRIGHT_YELLOW = "\u001b[93m"  ## Bright yellow text color.
const FG_BRIGHT_BLUE = "\u001b[94m"  ## Bright blue text color.
const FG_BRIGHT_MAGENTA = "\u001b[95m"  ## Bright magenta text color.
const FG_BRIGHT_CYAN = "\u001b[96m"  ## Bright cyan text color.
const FG_BRIGHT_WHITE = "\u001b[97m"  ## Bright white text color.


# Bright background colors
const BG_BRIGHT_BLACK = "\u001b[100m"  ## Bright black background color.
const BG_BRIGHT_RED = "\u001b[101m"  ## Bright red background color.
const BG_BRIGHT_GREEN = "\u001b[102m"  ## Bright green background color.
const BG_BRIGHT_YELLOW = "\u001b[103m"  ## Bright yellow background color.
const BG_BRIGHT_BLUE = "\u001b[104m"  ## Bright blue background color.
const BG_BRIGHT_MAGENTA = "\u001b[105m"  ## Bright magenta background color.
const BG_BRIGHT_CYAN = "\u001b[106m"  ## Bright cyan background color.
const BG_BRIGHT_WHITE = "\u001b[107m"  ## Bright white background color.


enum AUTO_MODE {NORMAL, SUCCESS, INFO, WARNING, ERROR}

## Configuration for automatic formatting based on mode.
static var auto_config: Dictionary = {
    AUTO_MODE.NORMAL: {
        TYPE_STRING: FG_DEFAULT,
        TYPE_INT: FG_BLUE + BOLD,
        TYPE_FLOAT: FG_BLUE + BOLD,
        0: FG_WHITE
    },
    AUTO_MODE.SUCCESS: {
        TYPE_STRING: FG_GREEN,
    },
    AUTO_MODE.INFO: {
        TYPE_STRING: FG_BRIGHT_MAGENTA,
    },
    AUTO_MODE.WARNING: {
        TYPE_STRING: FG_YELLOW,
    },
    AUTO_MODE.ERROR: {
        TYPE_STRING: FG_RED + BOLD,
    }
}

## Default placeholder string used in auto_format function. Any data type can be passed to the autoformat function, but i don't think anyone will use this one... 
static var _n: String = "⊙Ⲷ⧍"


## Adds a rainbow gradient to the given text with a specified size.
static func add_rainbow_gradient(text: String, gradient_size: int) -> String:
    var colors: Array = [
        FG_RED,
        FG_YELLOW,
        FG_GREEN,
        FG_CYAN,
        FG_BLUE,
        FG_MAGENTA,
    ]

    var result: String = ""
    var color_index: int = 0
    var char_count: int = 0

    for char: String in text:
        if char != '\n' and char != ' ':
            result += colors[color_index] + char
            char_count += 1

            if char_count >= gradient_size:
                color_index = (color_index + 1) % colors.size()
                char_count = 0

        else:
            result += char
        
    return result + RESET


## Wraps the given string in the specified ANSI escape code.
static func wrap_string(string: String, in_ANSI: String) -> String:
    return in_ANSI + string + RESET

static func bold(original_string: String) -> String:    return wrap_string(original_string, BOLD)

static func black(original_string: String) -> String:   return wrap_string(original_string, FG_BLACK)
static func red(original_string: String) -> String:     return wrap_string(original_string, FG_RED)
static func green(original_string: String) -> String:   return wrap_string(original_string, FG_GREEN)
static func yellow(original_string: String) -> String:  return wrap_string(original_string, FG_YELLOW)
static func blue(original_string: String) -> String:    return wrap_string(original_string, FG_BLUE)
static func magenta(original_string: String) -> String: return wrap_string(original_string, FG_MAGENTA)
static func cyan(original_string: String) -> String:    return wrap_string(original_string, FG_CYAN)
static func white(original_string: String) -> String:   return wrap_string(original_string, FG_WHITE)
static func default(original_string: String) -> String: return wrap_string(original_string, FG_DEFAULT)


## Applies automatic formatting to the given arguments based on the specified mode.
static func auto_format(mode: AUTO_MODE = AUTO_MODE.NORMAL, arg1=_n, arg2=_n, arg3=_n, arg4=_n, arg5=_n, arg6=_n, arg7=_n, arg8=_n) -> String:
    var args: Array = [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8]

    var result: String = ""

    for arg: Variant in args:
        if str(arg) != _n:
            var ansi: String = auto_config[mode].get(typeof(arg), auto_config[AUTO_MODE.NORMAL].get(typeof(arg), auto_config[0][0]))
            
            result += wrap_string(str(arg), ansi)

    return result


## Shorthand for auto_format(TF.AUTO_MODE.ERROR)
static func error(arg1=_n, arg2=_n, arg3=_n, arg4=_n, arg5=_n, arg6=_n, arg7=_n, arg8=_n) -> String: 
    return auto_format(AUTO_MODE.ERROR, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)


## Shorthand for auto_format(TF.AUTO_MODE.INFO)
static func info(arg1=_n, arg2=_n, arg3=_n, arg4=_n, arg5=_n, arg6=_n, arg7=_n, arg8=_n) -> String: 
    return auto_format(AUTO_MODE.INFO, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
