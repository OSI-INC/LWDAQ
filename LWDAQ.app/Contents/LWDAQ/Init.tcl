# Long-Wire Data Acquisition Software (LWDAQ)
#
# Copyright (C) 2005-2021 Kevan Hashemi, Brandeis University
# Copyright (C) 2022-2025 Kevan Hashemi, Open Source Instruments Inc.
# 
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
# 
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <https://www.gnu.org/licenses/>.

# Clear our initialization error flag.
set num_errors 0

# Set version numbers in a few entries of the global LWDAQ_Info array
set LWDAQ_Info(program_name) "LWDAQ"
set LWDAQ_Info(program_version) "10.7"
set LWDAQ_Info(program_patchlevel) "10.7.3"
set LWDAQ_Info(tcl_version) [info patchlevel]
set LWDAQ_Init(default_prompt) "LWDAQ$ "
set LWDAQ_Info(prompt) $LWDAQ_Init(default_prompt)
	
# Determine architecture.
package require platform
set LWDAQ_Info(arch) [platform::identify]
package forget platform

# Determine operating system.
if {[regexp -nocase "Darwin" $tcl_platform(os)]} {
	set LWDAQ_Info(os) "MacOS"
} elseif {[regexp -nocase "Windows" $tcl_platform(os)]} {
	set LWDAQ_Info(os) "Windows"
} elseif {[regexp -nocase "Linux" $tcl_platform(os)]} {
	if {[string match *-arm $LWDAQ_Info(arch)]} {
		set LWDAQ_Info(os) "Raspbian"
	} else {
		set LWDAQ_Info(os) "Linux"
	}
} else {
	set LWDAQ_Info(os) "Unknown"
}

# Determine the contents directory name. On MacOS, Linux, and Windows we
# have our bundled TclTk executable as a reference point. For Raspbian, we
# assume we are calling wish or tclsh with this file as the initialization 
# script, so we use argv0 to obtain the contents directory.
set LWDAQ_Info(exec_dir) [file dirname [info nameofexecutable]]
switch $LWDAQ_Info(os) {
	"MacOS" {
		set LWDAQ_Info(contents_dir) [file normalize \
			[file join $LWDAQ_Info(exec_dir) ..]]
		set LWDAQ_Info(stdout_available) 1
	}
	"Linux" {
		set LWDAQ_Info(contents_dir) [file normalize [file join \
			$LWDAQ_Info(exec_dir) .. ..]]
		set LWDAQ_Info(stdout_available) 1
	}
	"Raspbian" {
		set LWDAQ_Info(contents_dir) [file normalize \
			[file join [file dirname $argv0] ..]]
		set LWDAQ_Info(stdout_available) 1
	}
	"Windows" {
		set LWDAQ_Info(contents_dir) [file normalize [file join \
			$LWDAQ_Info(exec_dir) .. ..]]
		set LWDAQ_Info(stdout_available) 0
	}
	default {
		set LWDAQ_Info(contents_dir) [file normalize \
			[file join [file dirname $argv0] ..]]
		set LWDAQ_Info(stdout_available) 1
	}
}

# Set the platform-dependent names for LWDAQ's directories.
set LWDAQ_Info(program_dir) [file normalize [file join $LWDAQ_Info(contents_dir) .. ..]]
set LWDAQ_Info(lib_dir) [file join $LWDAQ_Info(contents_dir) LWDAQ]
set LWDAQ_Info(package_dir) [file join $LWDAQ_Info(lib_dir) Packages]
set LWDAQ_Info(scripts_dir) [file join $LWDAQ_Info(contents_dir) LWDAQ]
set LWDAQ_Info(tools_dir) [file join $LWDAQ_Info(program_dir) Tools]
set LWDAQ_Info(spawn_dir) [file join $LWDAQ_Info(tools_dir) Spawn]
set LWDAQ_Info(sources_dir)  [file join $LWDAQ_Info(program_dir) Sources]
set LWDAQ_Info(instruments_dir) [file join $LWDAQ_Info(scripts_dir) Instruments]
set LWDAQ_Info(temporary_dir) [file join $LWDAQ_Info(scripts_dir) Temporary]
set LWDAQ_Info(config_dir) [file join $LWDAQ_Info(contents_dir) LWDAQ/Configuration]
set LWDAQ_Info(modes_dir) [file join $LWDAQ_Info(contents_dir) LWDAQ/Modes]
set LWDAQ_Info(working_dir) $LWDAQ_Info(program_dir)

# Set the user-defined flags to their default values.
set LWDAQ_Info(run_mode) "--gui"
set LWDAQ_Info(terminal_connected) "0"
set LWDAQ_Info(configuration_file) ""
set LWDAQ_Info(argv) ""

# Decide whether or not we should enable LWDAQ's graphical user interface (GUI).
# If LWDAQ is running in the "wish" shell, which is the TclTk shell, we turn on
# the GUI. But if LWDAQ is running in "tclsh", the Tcl-only shell, we turn off
# the GUI
set LWDAQ_Info(gui_enabled) \
	[string match -nocase "*wish*" \
		[file tail [info nameofexecutable]]]

# Go through the list of arguments passed to this script, and set the
# configuration file name and deteremine if we should commandeer the launching
# terminal's standard input and output for use as a Tcl console. If we are
# running without a GUI, any error causes us to print an error message and exit.
foreach a $argv {
	switch -glob -- $a {
		"" {
		# We often get empty arguments, and we ignore them.
		}
		"-psn*" {
		# We ignore these process serial number arguments.
		}
		"--no-console" {
			set LWDAQ_Info(terminal_connected) 0
			set LWDAQ_Info(run_mode) $a
		}
		"--gui" {
			set LWDAQ_Info(terminal_connected) 1
			set LWDAQ_Info(run_mode) $a
		}
		"--no-gui" {
			set LWDAQ_Info(terminal_connected) 1
			set LWDAQ_Info(run_mode) $a
		}
		"--spawn" {
			set LWDAQ_Info(terminal_connected) 0
			set LWDAQ_Info(run_mode) $a
		}
		"--pipe" {
			set LWDAQ_Info(terminal_connected) 0
			set LWDAQ_Info(run_mode) $a
		}
		"--no-prompt" {
			set LWDAQ_Info(prompt) ""
		}
		"--prompt" {
			set LWDAQ_Info(prompt) $LWDAQ_Init(default_prompt)
		}
		
		default {
			if {$LWDAQ_Info(configuration_file) == ""} {
				if {[file exists $a]} {
					set LWDAQ_Info(configuration_file) $a
				} elseif {[file exists [set mfn \
						[file join $LWDAQ_Info(modes_dir) $a]]]} {
					set LWDAQ_Info(configuration_file) $mfn
				} else {
					puts "ERROR: No such option or file \"$a\"."
					if {!$LWDAQ_Info(gui_enabled)} {exit}
					incr num_errors
				}
			} {
				lappend LWDAQ_Info(argv) $a
			}
		}
	}
}

# If the GUI is disabled, create a dummy TK window procedure. The winfo
# procedure returns zero always to indicate that windows don't exist.
if {!$LWDAQ_Info(gui_enabled)} {
	proc winfo {args} {return 0}
}

# Determine whether or not we should use a graphical console available through
# the TK "console" command. If we have a terminal connected, we will use the
# terminal instead, implementing a console with the TTY package, if it exists,
# of a primitive line-execution console if there is no TTY package.
if {$LWDAQ_Info(terminal_connected)} {
	set LWDAQ_Info(tk_console) 0
} {
	if {[info commands console] == "console"} {
		set LWDAQ_Info(tk_console) 1
	} {
		set LWDAQ_Info(tk_console) 0
	}
}

#
# Run the scripts that set up the LWDAQ program within the TclTk interpreter.
#
if {[catch {
	# Set the console title, if there is a console.
	if {$LWDAQ_Info(tk_console)} {
		console title "Console for $LWDAQ_Info(program_name) \
			$LWDAQ_Info(program_patchlevel) on $LWDAQ_Info(os)"
	}
	
	# Make a list of settings scripts we must run to configure the program to
	# the user's liking.
	set LWDAQ_Info(settings_scripts) \
			[lsort -dictionary \
				[glob -nocomplain [file join $LWDAQ_Info(config_dir) *.tcl]]]

	# For our help routines, we construct a list of all the TclTk files that define
	# the LWDAQ routines.
	set LWDAQ_Info(scripts) [concat \
		[glob -nocomplain [file join $LWDAQ_Info(scripts_dir) *.tcl]] \
		[glob -nocomplain [file join $LWDAQ_Info(instruments_dir) *.tcl]] ]
		
	# Add the LWDAQ's package directory to the auto_path for library searches.
	global auto_path
	lappend auto_path $LWDAQ_Info(package_dir)

	# Make an index of packages in the package directory. This command will
	# produce an error if there are no packages in the directory, but does not
	# produce an error if there are corrupted packages in the directory. Thus
	# we catch whatever error it produces and move on regardless.
	catch {pkg_mkIndex $LWDAQ_Info(package_dir)}

	# Set up LWDAQ event queue and load utility routines.
	source [file join $LWDAQ_Info(scripts_dir) Utils.tcl]
	LWDAQ_utils_init
	LWDAQ_queue_start

	# Set up the TCL commands that communicate with an LWDAQ Driver
	source [file join $LWDAQ_Info(scripts_dir) Driver.tcl]
	LWDAQ_driver_init

	# Set up TCL commands that manage instruments.
	source [file join $LWDAQ_Info(scripts_dir) Instruments.tcl]
	LWDAQ_instruments_init

	# Set up TCL commands that manage tools.
	source [file join $LWDAQ_Info(scripts_dir) Tools.tcl]
	LWDAQ_tools_init

	# Set up TCL commands that create the graphical user interface (GUI).
	source [file join $LWDAQ_Info(scripts_dir) Interface.tcl]
	LWDAQ_interface_init

	# Close all sockets
	LWDAQ_close_all_sockets

	# Load the lwdaq dynamic library we compile from our Pascal source code. This
	# library defines a bunch of TCL commands whose names start with "lwdaq_". We
	# can do this only once for each execution of LWDAQ. When we call LWDAQ_init
	# a second time, the interpreter ignores this load command. 
	load [file join $LWDAQ_Info(lib_dir) lwdaq.so_$LWDAQ_Info(os)] lwdaq

	# Set up options for TCL commands defined in our analysis library. These 
	# vary from one platform to the next.
	switch $LWDAQ_Info(os) {
		"MacOS" {
			lwdaq_config -stdout_available 1 -stdin_available 0 -wait_ms 100
		}
		"Linux" {
			lwdaq_config -stdout_available 1 -stdin_available 0 -wait_ms 100
		}
		"Windows" {
			lwdaq_config -stdout_available 0 -stdin_available 0 -wait_ms 100
		}
		"Raspbian" {
			lwdaq_config -stdout_available 1 -stdin_available 0 -wait_ms 100
		}
		default {
			lwdaq_config -stdout_available 1 -stdin_available 0 -wait_ms 100
		}
	}
} error_message]} {
	puts "ERROR: In initialization, $error_message"
	if {!$LWDAQ_Info(gui_enabled)} {exit}
	incr num_errors
}

# Install some routines that mimic Unix.
proc ls {args} {
	if {$args==""} {
		glob *
	} {
		if {[file isdirectory $args]} {
			glob "$args/*"
		} {
			eval "glob $args"
		}
	}
}

# When launching LWDAQ with the icon, the default Tcl directory can end up being
# the root directory, which is not much good, so change it.
if {[pwd] == "/"} {
	cd $LWDAQ_Info(program_dir)
}

# Run startup scripts. Let them know that they are operating as startup scripts,
# and which one they are in the order of execution, too. They will execute in
# alphabetical order.
set LWDAQ_Info(num_settings_scripts_loaded) 0
set LWDAQ_Info(loading_settings_scripts) 1
foreach s $LWDAQ_Info(settings_scripts) {
	if {[catch {source $s} error_message]} {
		puts "ERROR: $error_message in startup script \"[file tail $s]\"."
		if {!$LWDAQ_Info(gui_enabled)} {exit}
		incr num_errors
	}
	incr LWDAQ_Info(num_settings_scripts_loaded)
}
set LWDAQ_Info(loading_settings_scripts) 0

# Run the configuration script, if it exists.
if {$LWDAQ_Info(configuration_file) != ""} {
	if {[catch {source $LWDAQ_Info(configuration_file)} error_message]} {
		puts "ERROR: $error_message in configuration file\
			\"$LWDAQ_Info(configuration_file)\"."
		if {!$LWDAQ_Info(gui_enabled)} {exit}
		incr num_errors
	}
}

# Check to see if there are spaces in the LWDAQ program directory.
if {[regexp { } $LWDAQ_Info(program_dir)]} {
	puts "ERROR: Installation directory \"$LWDAQ_Info(program_dir)\" contains spaces."
	if {!$LWDAQ_Info(gui_enabled)} {exit}
	incr num_errors
}

# If we are operating in no-gui mode, exit so that we don't freeze any process
# that has called LWDAQ to do some job. Otherwise, report the number of errors
# to the console.
if {$num_errors > 0} {
	puts "Initialization concluded with $num_errors errors."
}

#
# LWDAQ_stdin_console_start turns the standard input, which will exist when we
# start LWDAQ from a terminal on UNIX, LINUX, Windows and MacOS. We check to see
# if a console package is available to make a full-functioning console interface.
# If not, we use a crude console with no arrow implementation, no history, and
# no insertion.
#
proc LWDAQ_stdin_console_start {} {
	global LWDAQ_Info
	if {[catch {package require TTY}] \
			|| ([auto_execok stty] == "") \
			|| ($LWDAQ_Info(prompt) == "")} {
		fconfigure stdin -translation auto -buffering line
		fileevent stdin readable LWDAQ_stdin_console_execute
		puts -nonewline stdout $LWDAQ_Info(prompt)
		flush stdout
	} {
		global TTY
		set TTY(prompt) $LWDAQ_Info(prompt)
		TTY_start
	}
}

#
# LWDAQ_stdin_console_stop disables the console, so that standard input and output
# are no longer being used to provide and respond to Tcl commands.
#
proc LWDAQ_stdin_console_stop {} {
	if {[catch {package require TTY}] \
		|| ([auto_execok stty] == "") \
		|| ($LWDAQ_Info(prompt) == "")} {
		fileevent stdin readable ""
	} {
		TTY_stop 
	}
}


#
# LWDAQ_stdin_console_execute executes a command supplied from stdin and writes
# the result stdout.
#
proc LWDAQ_stdin_console_execute {} {
	global LWDAQ_Info
	if {[catch {
		if {[gets stdin line] >= 0} {
			set result [uplevel $line]
			if {$result != ""} {puts stdout $result}
			puts -nonewline stdout $LWDAQ_Info(prompt)
			flush stdout
		}
	} error_result]} {
		if {[catch {puts $error_result}]} {exit}
	}
}

# If we are using the Tk console and we have errors, open the Tk console so it
# will show the errors. If we are using a terminal, start our own console.
if {$LWDAQ_Info(tk_console)} {
	if {$num_errors > 0} {
		console show
	}
} {
	if {$LWDAQ_Info(terminal_connected)} {
		LWDAQ_stdin_console_start
	}
}

# If we run without graphics, LWDAQ will be inclined to terminate now that it
# has run Init.tcl. We keep the shell alive by telling it to wait until
# LWDAQ_Info(quit) is set. You can force the shell to quit with the "exit"
# command.
if {!$LWDAQ_Info(gui_enabled)} {
	vwait LWDAQ_Info(quit)
}

# Return an empty string.
return ""
