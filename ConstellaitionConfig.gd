static var config: Dictionary = {
	"disable_startup_details": true,				## Disables the colorfull start up logo and copyright headder
	"custom_loging_method": TF.print_auto,			## Defines a custom callable to call when logging infomation
	"custom_loging_method_verbose": Callable(),		## Defines a custom callable to call when logging infomation verbosely
	"log_prefix": TF.bold(TF.white("CTL: ")),		## A String prefix to print before all message logs

}
