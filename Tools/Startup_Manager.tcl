# Startup_Manager is a LWDAQ Tool that opens, configures, and launches
# multiple LWDAQ tools so as to simplify re-starting an experiment.
# The program is similar to the Acquisifier in the way it reads in 
# a script in a custom format to perform its functions.
#
# Copyright (C) 2022 Kevan Hashemi, Open Source Instruments Inc.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.


proc Startup_Manager_init {} {
	upvar #0 Startup_Manager_info info
	upvar #0 Startup_Manager_config config
	global LWDAQ_Info LWDAQ_Driver

	LWDAQ_tool_init "Startup_Manager" 1.0
	if {[winfo exists $info(window)]} {return 0}

	set info(dummy_step) "dummy: end.\n"
	set info(control) "Idle"
	set info(steps) [list $info(dummy_step)]
	set info(step) 0
	set info(num_steps) 1

	set config(daq_script) [file join $info(data_dir) Starter_Script.tcl]
	set config(auto_load) 0
	set config(auto_run) 0
	set config(auto_quit) 0
	set config(forgetful) 0
	set config(title_color) purple
	set config(analysis_color) brown
	set config(result_color) darkgreen
	set config(num_steps_show) 20
	
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 

	return 1	
}

#
# Startup_Manager_command handles a button press requesting the execution of a command.
# If appropriate, the routine sets the Startup_Manager in motion.
#
proc Startup_Manager_command {command} {
	upvar #0 Startup_Manager_info info
	global LWDAQ_Info
	
	if {$command == $info(control)} {
		return "IGNORE"
	}

	if {$command == "Reset"} {
		if {$info(control) != "Idle"} {set info(control) "Stop"}
		LWDAQ_reset
		return "ABORT"
	}
	
	if {$command == "Stop"} {
		if {$info(control) == "Idle"} {
			return "ABORT"
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
		return "SUCCESS"
	}
	
	if {$info(control) == "Idle"} {
		set info(control) $command
		LWDAQ_post Startup_Manager_execute
		return "SUCCESS"
	} 
	
	set info(control) $command
	return "SUCCESS"
}

#
# Find and remember the data acquisition script.
#
proc Startup_Manager_browse_daq_script {} {
	upvar #0 Startup_Manager_config config
	set f [LWDAQ_get_file_name]
	if {$f != ""} {set config(daq_script) $f}
}

#
# Startup_Manager_get_param_index returns the list-style index of the value of the
# parameter named $param_name in step number $step_num in the current
# starter script. This script is stored in info(steps). Thus the value of
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
# Startup_Manager_get_param returns the value of the parameter named param_name in step
# step_num of the current starter script. If there is no such parameter,
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
	if {$index == 0} {return 0}
	lset info(steps) $step_num $index $value
	return 1
}

#
# Startup_Manager_get_field returns the value of the field named field_name in step
# step_num of the current starter script. If there is no such field, the
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
# Startup_Manager_step_list_print prints a list of steps to a text widget. It is
# used by the list_script and load_script routines. If num_lines > 0, the
# routine prints the first num_lines steps and the last num_lines steps.
#
proc Startup_Manager_step_list_print {text_widget num_lines} {
	upvar #0 Startup_Manager_info info
	upvar #0 Startup_Manager_config config

	LWDAQ_print $text_widget "[format {%6s} Step] \
			[format {%-12s} Type] \
			[format {%-22s} Name] \
			[format {%-12s} Tool]" $config(title_color)
	for {set step_num 1} {$step_num <= $info(num_steps)} {incr step_num} {
		set type [string replace [lindex $info(steps) $step_num 0] end end ""]
		if {[lsearch {starter default run spawn} $type] < 0} {
			set type "UNKNOWN"
		}
		set name [Startup_Manager_get_field $step_num "name"]
		if {$name == ""} {set name "None"}
		set instrument [Startup_Manager_get_field $step_num "tool"]
		if {$instrument == ""} {set instrument "None"}
		LWDAQ_print $text_widget \
			"[format {%6d} $step_num] \
			[format {%-12s} $type] \
			[format {%-22s} $name] \
			[format {%-12s} $instrument]"
		if {($step_num == $num_lines) && ($info(num_steps) > [expr $num_lines + $num_lines])} {
			set step_num [expr $info(num_steps) - $num_lines]
			LWDAQ_print $text_widget "[format {%6s} ...] \
					[format {%-12s} ...] \
					[format {%-22s} ...] \
					[format {%-12s} ...]" $config(title_color)
		}
	}
	
	return 1
}

#
# Startup_Manager_load_script loads a script into memory from a file. If we specify no
# file, the routine uses the file name given in config(daq_script).
#
proc Startup_Manager_load_script {{fn ""}} {
	upvar #0 Startup_Manager_info info
	upvar #0 Startup_Manager_config config
	
	if {$info(control) == "Load_Script"} {return "IGNORE"}
	if {$info(control) != "Idle"} {return "IGNORE"}
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

	if {$fn == ""} {set fn $config(daq_script)}
	LWDAQ_print $info(text) "\nLoad: $fn" $config(title_color)

	if {![file exists $fn]} {
		LWDAQ_print $info(text) "ERROR: Can't find starter script."
		LWDAQ_print $info(text) "SUGGESTION: Press \"Browse\" and choose a script."
		set info(control) "Idle"
		return "ERROR"
	}
	
	# Read file contents and remove comment lines.
	set as "\n"
	if {[catch {
		append as [LWDAQ_read_script $fn]
	} error_message]} {
		LWDAQ_print $info(text) "ERROR: $error_message\."
		set info(control) "Idle"
		return "ERROR"
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
	Startup_Manager_step_list_print $info(text) $config(num_steps_show)	
	LWDAQ_print $info(text) "Load okay." $config(result_color)
	
	set info(control) "Idle"
	return "SUCCESS"
}

#
# Startup_Manager_list_script prints an entire script to a separate window.
#
proc Startup_Manager_list_script {} {
	upvar #0 Startup_Manager_info info
	upvar #0 Startup_Manager_config config

	set w $info(window)\.list
	if {[winfo exists $w]} {destroy $w}
	toplevel $w
	wm title $w "Step List"
	set step_list ""
	set t [LWDAQ_text_widget $w 80 20]
	Startup_Manager_step_list_print $t 0

	return "SUCCESS"
}

#
# Startup_Manager_script_string returns a string version of the current script.
#
proc Startup_Manager_script_string {} {
	upvar #0 Startup_Manager_info info
	upvar #0 Startup_Manager_config config

	set s ""
	
	for {set step_num 1} {$step_num <= $info(num_steps)} {incr step_num} {
		set title 1
		set in_config 0
		set param_name 1
		set field_name 1
		foreach e [lindex $info(steps) $step_num] {
			if {$title == 1} {
				append s "$e\n"
				set title 0
				continue
			}
			if {$e == "end."} {
				append s "end.\n\n"
				break
			}
			if {$e == "config:"} {
				set in_config 1
				append s "config:\n"
				continue
			}
			if {$in_config == 0} {
				if {$field_name} {
					append s "$e "
					set field_name 0
				} {
					append s "\{$e\}\n"
					set field_name 1
				}	
			} {
				if {$param_name == 1} {
					append s "	$e "
					set param_name 0
				} {
					append s "\{$e\}\n"
					set param_name 1
				}	
			}
		}
	}
	
	return [string trim $s]
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
	if {![array exists info]} {return 0}

	# Detect global LWDAQ reset.
	if {$LWDAQ_Info(reset)} {
		set info(control) "Idle"
		return "ABORT"
	}
	
	# If the window is closed, quit the Startup_Manager.
	if {$LWDAQ_Info(gui_enabled) && ![winfo exists $info(window)]} {
		array unset info
		array unset config
		return "ABORT"
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
		return "ABORT"
	}
	if {$info(control) == "Step"} {
		incr info(step)
		if {$info(step) > $info(num_steps)} {set info(step) 1}
	}
	if {$info(control) == "Run"} {
		incr info(step)
		if {$info(step) > $info(num_steps)} {set info(step) 1}
	}
	if {$info(control) == "Repeat"} {
	
	}
	if {$info(control) == "Back"} {
		if {$info(step) == 0} {
			LWDAQ_print $info(text) "ERROR: Cannot go back past script start."
		} {
			incr info(step) -1
		}
	}
	
	# Obtain the step type from the script. We take some trouble to remove the 
	# trailing colon from the first word in the step script.
	set step_type [string replace [lindex $info(steps) $info(step) 0] end end ""]
	if {[lsearch {default spawn run starter} $step_type] < 0} {
		set step_type "UNKNOWN"
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
	if {$step_type == "UNKNOWN"} {
		LWDAQ_print $info(text) "ERROR: Unrecognised step type or malformed step,\
			check script."
		set step_type "disabled"
	}

	# Read this step's metadata out of the script.
	set metadata [Startup_Manager_get_field $info(step) "metadata"]
	
	# Read this step's disable value. If it's defined as non-zero, 
	# we set the step type to "disabled".
	set disable [Startup_Manager_get_field $info(step) "disable"]
	if {($disable != "") && ($disable != "0")} {set step_type "disabled"}
		
	# Set the default result string.
	set result "$name okay."
	
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

	# A run step runs a tool within the same LWDAQ process as the Tool Starter,
	# configures the tool, and executes the step's commands in the TCL interpreter.
	# These commands may start the tool doing something, or just complete its
	# configuration.
	if {$step_type == "run"} {
		# Run the tool.
		if {[catch {LWDAQ_run_tool $tool} error_result]} {
			set result "ERROR: $error_result"
		}

		# Declare the tool config and info arrays for local access as tconfig
		# and tinfo.
		upvar #0 $tool\_config tconfig
		upvar #0 $tool\_info tinfo
		
		# Set the tool window title.
		wm title $tinfo(window) "$tool $tinfo(version)\: $name"

		# Apply the tool's default configuration parameters.
		if {[info exists info($tool\_defaults)]} {
			foreach {p v} [set info($tool\_defaults)] {
				if {[info exists tconfig($p)]} {
					set tconfig($p) $v
					LWDAQ_print $info(text) "$p = \"$v\""
				} elseif {![LWDAQ_is_error_result $result]} {
					set result "ERROR: No parameter \"$p\" to assign value \"$v\"."
				}
			}
		}
		
		# Apply the tool's configuration parameters according to this step.
		foreach {p v} [Startup_Manager_get_config $info(step)] {
			if {[info exists tconfig($p)]} {
				set tconfig($p) $v
				LWDAQ_print $info(text) "$p = \"$v\""
			} elseif {![LWDAQ_is_error_result $result]} {
				set result "ERROR: No parameter \"$p\" to assign value \"$v\"."
			}
		}
		
		# Execute default startup commands. We perform percent substitution
		# for the name of the step.
		if {[info exists info($tool\_commands)]} {
			set cmd [set info($tool\_commands)]
			if {[catch {eval $cmd} error_result]} {
				if {![LWDAQ_is_error_result $result]} {
					set result "ERROR: $error_result"
				}
			}		
		}
				
		# Execute the startup commands defined by this step. We perform percent substitution
		# for the name of the step.
		set cmd [Startup_Manager_get_field $info(step) "commands"]
		if {[catch {eval $cmd} error_result]} {
			if {![LWDAQ_is_error_result $result]} {
				set result "ERROR: $error_result"
			}
		}
	}
	
	if {$step_type == "spawn"} {
		# To spawn a tool, we will launch a separate LWDAQ and configure it with
		# a configuration file. This file begins with the commands that set up
		# the tool, which we will find in the spawn menu.
		set sfn [file join $LWDAQ_Info(spawn_dir) $tool\.tcl]
		if {![file exists $sfn]} {
			set result "ERROR: Cannot find \"$tool\" in spawn directory."
		}
		
		# Compose the spawned process configuration file name.		
		set cfn [file join $LWDAQ_Info(temporary_dir) $tool\_$info(step).tcl]
		
		# Initialized the command string. We want the spawned process to have 
		# access to the tool configuration and information arrays through 
		# variables tconfig and tinfo, for consistency with command execution
		# in run steps. 
		set commands "upvar #0 $tool\_config tconfig\n"
		append commands "upvar #0 $tool\_info tinfo\n"
		
		# Set the window title to include the step name.
		append commands "wm title . \"\[wm title .]: $name\"\n"

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
		
		# Spawn the tool with configuration file.
		LWDAQ_spawn_tool $tool $commands $cfn
	}
	
	if {$step_type == "starter"} {
		set commands [Startup_Manager_get_field $info(step) "commands"]
		if {[catch {eval $commands} error_result]} {
			if {![LWDAQ_is_error_result $result]} {
				set result "ERROR: $error_result"
			}
		}
	}
	
	if {$step_type == "disabled"} {
		set result "$name disabled."
	}
	
	# Here we append the step name to error results so we'll know where
	# the error result comes from.
	if {[LWDAQ_is_error_result $result]} {
		if {[string index $result end] == "."} {
			set result [string replace $result end end ""]
		}
		set result "$result in $name\."
	}

	# Print the step result of the result to the screen.
	LWDAQ_print $info(text) $result $config(result_color)
	
	# Adjust the step number and decide whether to post another step
	# execution now.
	if {($info(control) == "Run") && ($info(step) < $info(num_steps))} {
		LWDAQ_post Startup_Manager_execute
		return $result
	}
	if {($info(control) == "Run") && ($info(step) == $info(num_steps))} {
		LWDAQ_print $info(text) "\nEnd" $config(title_color)
		if {$config(auto_quit)} {exit}
	}
	
	set info(control) "Idle"
	return $result
}

proc Startup_Manager_open {} {
	upvar #0 Startup_Manager_config config
	upvar #0 Startup_Manager_info info
	
	set w [LWDAQ_tool_open Startup_Manager]
	if {$w == ""} {return 0}
	
	set f $w.setup
	frame $f
	pack $f -side top -fill x
	
	label $f.l1 -textvariable Startup_Manager_info(control) -width 16 -fg blue
	label $f.l2 -text "Step" -width 4
	entry $f.l3 -textvariable Startup_Manager_info(step) -width 10
	label $f.l4 -text "of" -width 2
	label $f.l5 -textvariable Startup_Manager_info(num_steps) -width 5
	pack $f.l1 $f.l2 $f.l3 $f.l4 $f.l5 -side left -expand 1

	button $f.configure -text Configure -command "LWDAQ_tool_configure Startup_Manager"
	pack $f.configure -side left -expand 1
	button $f.help -text Help -command "LWDAQ_tool_help Startup_Manager"
	pack $f.help -side left -expand 1

	set f $w.controls
	frame $f
	pack $f -side top -fill x
	foreach a {Stop Step Repeat Back Run Reset} {
		set b [string tolower $a]
		button $f.$b -text $a -command "Startup_Manager_command $a"
		pack $f.$b -side left -expand 1
	}

	set f $w.script
	frame $f
	pack $f -side top -fill x

	label $f.title -text "Script:"
	entry $f.entry -textvariable Startup_Manager_config(daq_script) -width 45
	button $f.browse -text Browse -command [list LWDAQ_post Startup_Manager_browse_daq_script]
	pack $f.title $f.entry $f.browse -side left -expand 1

	foreach a {Load Store List} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post Startup_Manager_$b\_script"
		pack $f.$b -side left -expand 1
	}
	
	set f $w.checkbuttons
	frame $f
	pack $f -side top -fill x
	foreach a {Auto_Quit Auto_Run Auto_Load Forgetful} {
		set b [string tolower $a]
		checkbutton $f.c$b -text $a -variable Startup_Manager_config($b)
		pack $f.c$b -side left -expand 1
	}
	
	set info(text) [LWDAQ_text_widget $w 90 25 1 1]
	
	return "SUCCESS"
}

Startup_Manager_init
Startup_Manager_open

if {$Startup_Manager_config(auto_load)} {
	Startup_Manager_load_script
}
if {$Startup_Manager_config(auto_run)} {
	Startup_Manager_command Run
}

# This is the final return. There must be no tab or space in
# front of the return command, or else the spawn procedure
# won't work.
return 1

----------Begin Help----------

The Startup_Manager tool uses a starter script on disk to open and start the operation of LWDAQ tools.

----------End Help----------
