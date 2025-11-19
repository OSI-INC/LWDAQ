# Startup_Manager, a LWDAQ Tool
#
# Copyright (C) 2022-2023 Kevan Hashemi, Open Source Instruments Inc.
#
# The Startup Manager opens, configures, and launches multiple LWDAQ tools so as
# to simplify re-starting an experiment. The program is similar to the
# Acquisifier in the way it reads in a script in a custom format to perform its
# functions.
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


proc Startup_Manager_init {} {
	upvar #0 Startup_Manager_info info
	upvar #0 Startup_Manager_config config
	global LWDAQ_Info LWDAQ_Driver

	LWDAQ_tool_init "Startup_Manager" "1.7"
	if {[winfo exists $info(window)]} {return ""}

	set info(dummy_step) "dummy: end.\n"
	set info(control) "Idle"
	set info(steps) [list $info(dummy_step)]
	set info(step) 0
	set info(num_steps) 1

	set config(daq_script) [file join $info(data_dir) Startup_Script.tcl]
	set config(auto_load) 0
	set config(auto_run) 0
	set config(auto_close) 0
	set config(auto_quit) 0
	set config(forgetful) 0
	set config(title_color) purple
	set config(analysis_color) brown
	set config(result_color) darkgreen
	set config(num_steps_show) 20
	set config(corner_x) 50
	set config(corner_x_step) 20
	set config(corner_y) 20
	set config(corner_y_step) 10
	set config(startup_timeout) 20
	
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 

	return ""	
}

#
# Startup_Manager_command handles a button press requesting the execution of a command.
# If appropriate, the routine sets the Startup_Manager in motion.
#
proc Startup_Manager_command {command} {
	upvar #0 Startup_Manager_info info
	global LWDAQ_Info
	
	if {$command == $info(control)} {
		return ""
	}

	if {$command == "Stop"} {
		if {$info(control) == "Idle"} {
			return ""
		}
		set info(control) "Stop"
		set event_pending [string match "Startup_Manager*" $LWDAQ_Info(current_event)]
		foreach event $LWDAQ_Info(queue_events) {
			if {[string match "Startup_Manager*" $event]} {
				set event_pending 1
	 		}
		}
		if {!$event_pending} {
			set info(control) "Idle"
		}
		return ""
	}
	
	if {$info(control) == "Idle"} {
		set info(control) $command
		LWDAQ_post Startup_Manager_execute
		return ""
	} 
	
	set info(control) $command
	return ""
}

#
# Find and remember the data acquisition script.
#
proc Startup_Manager_browse_daq_script {} {
	upvar #0 Startup_Manager_config config
	set f [LWDAQ_get_file_name]
	if {$f != ""} {set config(daq_script) $f}
	return ""
}

#
# Startup_Manager_get_param_index returns the list-style index of the value of
# the parameter named $param_name in step number $step_num in the current
# startup script. This script is stored in info(steps). Thus the value of
# parameter $param_name in step number $step_num is the N'th list element in the
# string that defines step number $step_num, where N is the value returned by
# this routine. If N=0, there is no such parameter named in the script.
#
proc Startup_Manager_get_param_index {step_num param_name} {
	upvar #0 Startup_Manager_info info
	set e [lindex $info(steps) $step_num]
	set index [expr [lsearch $e "$param_name"] + 1]
	return $index
}

#
# Startup_Manager_get_param returns the value of the parameter named param_name
# in step step_num of the current startup script. If there is no such parameter,
# the routine returns and empty string.
#
proc Startup_Manager_get_param {step_num param_name} {
	upvar #0 Startup_Manager_info info
	set index [Startup_Manager_get_param_index $step_num $param_name]
	if {$index == 0} {return ""}
	return [lindex $info(steps) $step_num $index]
}

#
# Startup_Manager_put_param sets the value of the parameter named param_name in step
# step_num of the currrent Acqusifier script. If there is no such parameter,
# the routine does nothing.
#
proc Startup_Manager_put_param {step_num param_name value} {
	upvar #0 Startup_Manager_info info
	set index [Startup_Manager_get_param_index $step_num $param_name]
	if {$index == 0} {return ""}
	lset info(steps) $step_num $index $value
	return ""
}

#
# Startup_Manager_get_field returns the value of the field named field_name in
# step step_num of the current startup script. If there is no such field, the
# routine returns and empty string.
#
proc Startup_Manager_get_field {step_num field_name} {
	return [Startup_Manager_get_param $step_num "$field_name\:"]
}

#
# Startup_Manager_put_field sets the value of the field named field_name in step
# step_num of the currrent Acqusifier script. If there is no such field, the
# routine does nothing.
#
proc Startup_Manager_put_field {step_num field_name value} {
	return [Startup_Manager_put_param $step_num "$field_name\:" $value]
}

#
# Startup_Manager_get_config returns the configuration field of a step.
#
proc Startup_Manager_get_config {step_num} {
	upvar #0 Startup_Manager_info info
	
	set step [lindex $info(steps) $step_num]
	set i_start [string first "config:" $step]
	set i_end [string first "end." $step]
	if {$i_start < 0} {return ""}
	if {$i_end < 0} {set i_end end}
	set c [string range $step [expr $i_start + [string length "config:"]] \
		[expr $i_end - 1]]
	set c [string trim $c]
	set c [regsub -all {\n\W+} $c "\n"]
	return $c
}

#
# Startup_Manager_script_print prints a list of steps.
#
proc Startup_Manager_script_print {} {
	upvar #0 Startup_Manager_info info
	upvar #0 Startup_Manager_config config

	LWDAQ_print $info(text) "[format {%4s} Step] \
			[format {%-12s} Type] \
			[format {%-40s} Name] \
			[format {%-20s} Tool]" $config(title_color)
	for {set step_num 1} {$step_num <= $info(num_steps)} {incr step_num} {
		set type [string replace [lindex $info(steps) $step_num 0] end end ""]
		if {[lsearch {startup default communal standalone} $type] < 0} {
			set type "UNKNOWN"
		}
		set name [Startup_Manager_get_field $step_num "name"]
		if {$name == ""} {set name "None"}
		set tool [Startup_Manager_get_field $step_num "tool"]
		if {$tool == ""} {set tool "None"}
		LWDAQ_print $info(text) \
			"[format {%4d} $step_num] \
			[format {%-12s} $type] \
			[format {%-40s} $name] \
			[format {%-20s} $tool]"
	}
	
	return ""
}

#
# Startup_Manager_load_script loads a script into memory from a file. If we specify no
# file, the routine uses the file name given in config(daq_script).
#
proc Startup_Manager_load_script {{fn ""}} {
	upvar #0 Startup_Manager_info info
	upvar #0 Startup_Manager_config config
	
	if {$info(control) == "Load_Script"} {return ""}
	if {$info(control) != "Idle"} {return ""}
	set info(control) "Load_Script"
	set info(step) 0
	LWDAQ_update
	
	# If forgetful, unset previously-defined defaults and commands
	if {$config(forgetful)} {
		foreach n [array names info] {
			if {[string match *_defaults $n]} {
				unset info($n)
			}
			if {[string match *_commands $n]} {
				unset info($n)
			}
		}
	}

	# Determine the script file name.
	if {$fn == ""} {
		set fn $config(daq_script)
	} {
		set config(daq_script) $fn
	}
	LWDAQ_print $info(text) "\nLoad: $fn" $config(title_color)

	if {![file exists $fn]} {
		LWDAQ_print $info(text) "ERROR: Can't find startup manager script."
		LWDAQ_print $info(text) "SUGGESTION: Press \"Browse\" and choose a script."
		set info(control) "Idle"
		return ""
	}
		
	# Read file contents and remove comment lines.
	set as "\n"
	if {[catch {
		append as [LWDAQ_read_script $fn]
	} error_message]} {
		LWDAQ_print $info(text) "ERROR: $error_message\."
		set info(control) "Idle"
		return ""
	}
	regsub -all {\n[ \t]*#[^\n]*} $as "" as
	
	# Parse steps.
	set info(num_steps) 0
	set index 0
	set info(steps) [list $info(dummy_step)]
	while {1} {
		set i_end [string first "\nend." $as $index]
		if {$i_end < 0} {break}
		set s [string range $as $index [expr $i_end + [string length "\nend."] - 1]]
		lappend info(steps) $s		
		incr info(num_steps)
		set index [expr $i_end + [string length "\nend."]]
		if {$i_end <= 0} {break}
		LWDAQ_support
	}

	# Print a summary of the script to the screen.
	Startup_Manager_script_print 
	LWDAQ_print $info(text) "Load okay." $config(result_color)
	
	set info(control) "Idle"
	return ""
}

#
# Startup_Manager_edit_script opens a new toplevel window, reads the script file
# from disk, prints the script in the edit window, and provides buttons to save
# and duplicate the contents of the text window.
#
proc Startup_Manager_edit_script {} {
	upvar #0 Startup_Manager_info info
	upvar #0 Startup_Manager_config config

	if {![file exists $config(daq_script)]} {
		LWDAQ_print $info(text) "ERROR: Startup script file does not exist."
		return ""
	}
	
	LWDAQ_edit_script Open $config(daq_script)
	return ""
}

#
# Startup_Manager_execute performs a step, run, or stop. We control the routine through
# the control parameter in the info array, which we also display in the graphical 
# window, should such a window exist.
#
proc Startup_Manager_execute {} {
	upvar #0 Startup_Manager_info info
	upvar #0 Startup_Manager_config config
	global LWDAQ_Info

	# If the info array has been destroyed, abort.	
	if {![array exists info]} {return ""}

	# Detect global LWDAQ reset.
	if {$LWDAQ_Info(reset)} {
		set info(control) "Idle"
		return ""
	}
	
	# If the window is closed, quit the Startup_Manager.
	if {$info(gui) && ![winfo exists $info(window)]} {
		array unset info
		array unset config
		return ""
	}
	
	# Interpret the step number, in case it's a step name rather than a number.
	if {![string is integer -strict $info(step)]} {
		LWDAQ_print $info(text) "\nSearching for step \"$info(step)\"..." \
			$config(title_color)
		for {set i 1} {$i <= $info(num_steps)} {incr i} {
			set name [Startup_Manager_get_field $i "name"]
			if {$name == $info(step)} {
				set info(step) $i
				LWDAQ_print $info(text) "Done." $config(title_color)
				break
			}
		}
		if {![string is integer -strict $info(step)]} {
			LWDAQ_print $info(text) "ERROR: Cannot find step \"$info(step)\"."
			set info(step) 1
		}
	}
	
	# Interpret the control variable.
	if {$info(control) == "Stop"} {
		set info(control) "Idle"
		return ""
	}
	if {$info(control) == "Step"} {
		if {$info(step) == $info(num_steps)} {
			LWDAQ_print $info(text) "ERROR: At end of script, cannot step."
			set info(control) "Idle"
			return ""
		}
		incr info(step)
	}
	if {$info(control) == "Run"} {
		if {$info(step) == $info(num_steps)} {
			LWDAQ_print $info(text) "ERROR: At end of script, cannot run."
			LWDAQ_print $info(text) "SUGGESTION: Enter zero for step number, then run."
			set info(control) "Idle"
			return ""
		}
		incr info(step)
	}
	if {$info(control) == "Repeat"} {
		if {($info(step) > $info(num_steps)) || ($info(step) < 1)} {
			LWDAQ_print $info(text) "ERROR: Step number $info(step) out of bounds."
			set info(control) "Idle"
			return ""
		}
	}
	
	# Check that the step list is not empty.
	set info(steps) [string trim $info(steps)]
	if {$info(steps) == ""} {
		LWDAQ_print $info(text) "ERROR: Startup script is empty or not yet loaded."
		set info(control) "Idle"
		return ""
	}
	
	# Obtain the step type from the script. We take some trouble to remove the 
	# trailing colon from the first word in the step script.
	set step_type [string replace [lindex $info(steps) $info(step) 0] end end ""]
	if {[lsearch {default standalone communal startup} $step_type] < 0} {
		LWDAQ_print $info(text) "ERROR: Unrecognised step type \"$step_type\"."
		if {$step_type == "spawn"} {
			LWDAQ_print $info(text) "SUGGESTION: Type \"spawn\"\
				has been replaced by \"standalone\"."
		}
		if {$step_type == "run"} {
			LWDAQ_print $info(text) "SUGGESTION: Type \"run\"\
				has been replaced by \"communal\"."
		}
		set info(control) "Idle"
		return ""
	}

	# Obtain the name of the step. Some steps may have no specific name, in
	# which case we assign a default name which is the step type.
	set name [Startup_Manager_get_field $info(step) "name"]
	if {$name == ""} {set name $step_type\_$info(step)}
	
	# Determine the tool name, if any.
	set tool [Startup_Manager_get_field $info(step) "tool"]
	if {$tool == ""} {set tool "NONE"}
	
	# Print a title line to the screen.
	LWDAQ_print $info(text) "\nStep $info(step), $step_type, $name, $tool" \
		$config(title_color)

	# Read this step's metadata out of the script.
	set metadata [Startup_Manager_get_field $info(step) "metadata"]
	
	# Read this step's disable value. If it's defined as non-zero, 
	# we set the step type to "disabled".
	set disable [Startup_Manager_get_field $info(step) "disable"]
	if {($disable != "") && ($disable != "0")} {set step_type "disabled"}
		
	# Set the default result string.
	set result "Step \"$name\" okay."
	
	# A default step defines default commands and configuration for a tool.
	if {$step_type == "default"} {
		# Declare the tool configuration array for local use.
		upvar #0 $tool\_config tconfig
		
		# Make a list of parameter names and their default settings, which we
		# will apply at the start of each acquire step for this tool. 
		set info($tool\_defaults) [list]
		foreach {p v} [Startup_Manager_get_config $info(step)] {
			lappend info($tool\_defaults) $p $v
			LWDAQ_print $info(text) "$p = \"$v\""
		}
		
		# Extract the default command script. If there is no such script, we
		# obtain an empty string.
		set cmd [Startup_Manager_get_field $info(step) "commands"]
		set info($tool\_commands) $cmd
		
		# Print the default commands.
		foreach line [split [string trim [set info($tool\_commands)]] \n] {
			LWDAQ_print $info(text) [string trim $line]
		}
	}

	# A communal step runs a tool within the same LWDAQ process as the Startup
	# Manager, configures the tool, and executes the step's commands in the TCL
	# interpreter. These commands may start the tool doing something, or just
	# complete its configuration.
	if {$step_type == "communal"} {

		# Run the tool.
		if {[catch {LWDAQ_run_tool $tool} error_result]} {
			LWDAQ_print $info(text) "ERROR: $error_result"
			set info(control) "Idle"
			return ""
		}

		# Declare the tool config and info arrays for local access as tconfig
		# and tinfo.
		upvar #0 $tool\_config tconfig
		upvar #0 $tool\_info tinfo
		
		# Set the tool window title.
		wm title $tinfo(window) "$tool $tinfo(version)\: $name"
		set config(corner_x) [expr $config(corner_x) + $config(corner_x_step)]
		set config(corner_y) [expr $config(corner_y) + $config(corner_y_step)]
		wm geometry . +$config(corner_x)\+$config(corner_y)

		# Apply the tool's default configuration parameters.
		if {[info exists info($tool\_defaults)]} {
			foreach {p v} [set info($tool\_defaults)] {
				if {[info exists tconfig($p)]} {
					set tconfig($p) $v
					LWDAQ_print $info(text) "$p = \"$v\""
				} else {
					LWDAQ_print $info(text) "WARNING: Tool has no parameter \"$p\".\
						Check default configuration."
				}
			}
		}
		
		# Apply the tool's configuration parameters according to this step.
		foreach {p v} [Startup_Manager_get_config $info(step)] {
			if {[info exists tconfig($p)]} {
				set tconfig($p) $v
				LWDAQ_print $info(text) "$p = \"$v\""
			} else {
				LWDAQ_print $info(text) "WARNING: Tool has no parameter \"$p\".\
					Check step configuration."
			}
		}
		
		# Execute default startup commands. We perform percent substitution
		# for the name of the step.
		if {[info exists info($tool\_commands)]} {
			set cmd [set info($tool\_commands)]
			if {[catch {eval $cmd} error_result]} {
				LWDAQ_print $info(text) "ERROR: $error_result"
			}		
		}
				
 		# Execute the startup commands defined by this step. We perform percent substitution
		# for the name of the step.
		set cmd [Startup_Manager_get_field $info(step) "commands"]
		if {[catch {eval $cmd} error_result]} {
			LWDAQ_print $info(text) "ERROR: $error_result"
		}				
	}
	
	if {$step_type == "standalone"} {
		# To launch a standalone a tool, we will launch a separate LWDAQ and
		# configure it with a configuration file that instructs the new process
		# to run the tool. We trust that that the tool script exists somewhere
		# that LWDAQ can find it. We beging by composing the standalone process
		# configuration file name.		
		set cfn [file join $LWDAQ_Info(temporary_dir) $tool\_$info(step).tcl]
		
		# Initialized the command string. We want the standalone process to have 
		# access to the tool configuration and information arrays through 
		# variables tconfig and tinfo, for consistency with command execution
		# in run steps. 
		set commands "upvar #0 $tool\_config tconfig\n"
		append commands "upvar #0 $tool\_info tinfo\n"
		
		# Set the window title to include the step name.
		append commands "wm title . \"\[wm title .\]: $name\"\n"
		set config(corner_x) [expr $config(corner_x) + $config(corner_x_step)]
		set config(corner_y) [expr $config(corner_y) + $config(corner_y_step)]
		append commands "wm geometry . +$config(corner_x)\+$config(corner_y)\n"

		# Generate commands to apply the tool's default configuration parameters.
		if {[info exists info($tool\_defaults)]} {
			foreach {p v} [set info($tool\_defaults)] {
				append commands "set tconfig($p) \"$v\"\n"				
			}
		}
		
		# Generate commands to adjust the tool's configuration parameters in 
		# accordance with this steps configuration field.
		foreach {p v} [Startup_Manager_get_config $info(step)] {
			append commands "set tconfig($p) \"$v\"\n"				
		}
		
		# Append default startup commands.
		if {[info exists info($tool\_commands)]} {
			append commands [string trim [set info($tool\_commands)]]
			append commands "\n"
		}
				
		# Append the startup commands defined by this step.
		set cmd [Startup_Manager_get_field $info(step) "commands"]
		if {$cmd != ""} {
			append commands [string trim $cmd]
			append commands "\n"
		}
		
		# Show the commands.
		foreach line [split [string trim $commands] \n] {
			LWDAQ_print $info(text) [string trim $line]
		}
		
		# Append the configuration file deletion command.
		append commands "file delete $cfn\n"
		
		# Spawn the tool with configuration file.
		LWDAQ_spawn_tool $tool $commands $cfn
		
		# Wait until the configuration file is deleted, which indicates that the
		# spawned tool is running.
		set start_time [clock seconds]
		LWDAQ_print $info(text) "Waiting for \"$name\" to configure and run."
		while {[file exists $cfn]} {
			LWDAQ_update
			if {$info(control) == "Stop"} {
				LWDAQ_print $info(text) "User aborted waiting for \"$name\"."
				set result "WARNING: Step \"$name\" may not be running."
				break
			}
			if {[clock seconds] - $start_time > $config(startup_timeout)} {
				LWDAQ_print $info(text) "ERROR: Timeout waiting for \"$name\"."
				set result "ERROR: Step \"$name\" failed to configure and start."
				break
			}
		}
	}
	
	if {$step_type == "startup"} {
		set commands [Startup_Manager_get_field $info(step) "commands"]
		if {[catch {eval $commands} error_result]} {
			LWDAQ_print $info(text) "ERROR: $error_result"
		}
	}
	
	if {$step_type == "disabled"} {
		set result "Step \"$name\" disabled."
	}
	
	# Print the step result of the result to the screen. If it's an error, set
	# the control to Idle.
	LWDAQ_print $info(text) $result $config(result_color)
	if {[LWDAQ_is_error_result $result]} {
		set info(control) "Idle"
	}
	
	# Adjust the step number and decide whether to post another step
	# execution now.
	if {($info(control) == "Run") && ($info(step) < $info(num_steps))} {
		LWDAQ_post Startup_Manager_execute
		return $result
	}
	if {$info(step) == $info(num_steps)} {
		LWDAQ_print $info(text) "\nReached end of startup script." $config(title_color)
		if {$config(auto_quit)} {
			exit
		}
		if {$config(auto_close)} {
			destroy $info(window)
		} else {
			LWDAQ_print $info(text) "Feel free to close this window."
		}
	}
	
	set info(control) "Idle"
	return $result
}

proc Startup_Manager_open {} {
	upvar #0 Startup_Manager_config config
	upvar #0 Startup_Manager_info info
	
	set w [LWDAQ_tool_open Startup_Manager]
	if {$w == ""} {return ""}
	
	set f $w.setup
	frame $f
	pack $f -side top -fill x
	
	label $f.l1 -textvariable Startup_Manager_info(control) -width 10 -fg blue
	label $f.l2 -text "Step:" -width 4
	entry $f.l3 -textvariable Startup_Manager_info(step) -width 6
	label $f.l4 -text "of" -width 2
	label $f.l5 -textvariable Startup_Manager_info(num_steps) -width 5
	pack $f.l1 $f.l2 $f.l3 $f.l4 $f.l5 -side left -expand 1

	foreach a {Stop Step Repeat Run} {
		set b [string tolower $a]
		button $f.$b -text $a -command "Startup_Manager_command $a"
		pack $f.$b -side left -expand 1
	}

	button $f.configure -text Configure -command "LWDAQ_tool_configure Startup_Manager"
	pack $f.configure -side left -expand 1
	button $f.help -text Help -command "LWDAQ_tool_help Startup_Manager"
	pack $f.help -side left -expand 1

	set f $w.script
	frame $f
	pack $f -side top -fill x

	label $f.title -text "Script:"
	entry $f.entry -textvariable Startup_Manager_config(daq_script) -width 60
	button $f.browse -text Browse -command [list LWDAQ_post Startup_Manager_browse_daq_script]
	pack $f.title $f.entry $f.browse -side left -expand 1

	foreach a {Load Edit} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post Startup_Manager_$b\_script"
		pack $f.$b -side left -expand 1
	}
	
	set f $w.checkbuttons
	frame $f
	pack $f -side top -fill x
	foreach a {Auto_Load Auto_Run Auto_Close Auto_Quit Forgetful} {
		set b [string tolower $a]
		checkbutton $f.c$b -text $a -variable Startup_Manager_config($b)
		pack $f.c$b -side left -expand 1
	}
	
	set info(text) [LWDAQ_text_widget $w 90 25 1 1]
	
	return ""
}

Startup_Manager_init
Startup_Manager_open

if {$Startup_Manager_config(auto_load)} {
	Startup_Manager_load_script
}
if {$Startup_Manager_config(auto_run)} {
	Startup_Manager_command Run
}

# This is the final return.
return ""

----------Begin Help----------

https://www.bndhep.net/Electronics/LWDAQ/Startup_Manager.html

----------End Help----------
