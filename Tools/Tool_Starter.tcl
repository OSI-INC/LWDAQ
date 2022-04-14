# Tool Starter is a LWDAQ Tool that opens, configures, and launches
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


proc Tool_Starter_init {} {
	upvar #0 Tool_Starter_info info
	upvar #0 Tool_Starter_config config
	global LWDAQ_Info LWDAQ_Driver

	LWDAQ_tool_init "Tool_Starter" 1.0
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
	set config(cleanup) 1
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
# Tool_Starter_command handles a button press requesting the execution of a command.
# If appropriate, the routine sets the Tool_Starter in motion.
#
proc Tool_Starter_command {command} {
	upvar #0 Tool_Starter_info info
	global LWDAQ_Info
	
	if {$command == $info(control)} {
		return 1
	}

	if {$command == "Reset"} {
		if {$info(control) != "Idle"} {set info(control) "Stop"}
		LWDAQ_reset
		return 1
	}
	
	if {$command == "Stop"} {
		if {$info(control) == "Idle"} {
			return 1
		}
		set info(control) "Stop"
		set event_pending [string match "Tool_Starter*" $LWDAQ_Info(current_event)]
		foreach event $LWDAQ_Info(queue_events) {
			if {[string match "Tool_Starter*" $event]} {
				set event_pending 1
	 		}
		}
		if {!$event_pending} {
			set info(control) "Idle"
		}
		return 1
	}
	
	if {$info(control) == "Idle"} {
		set info(control) $command
		LWDAQ_post Tool_Starter_execute
		return 1
	} 
	
	set info(control) $command
	return 1	
}

#
# Find and remember the data acquisition script.
#
proc Tool_Starter_browse_daq_script {} {
	upvar #0 Tool_Starter_config config
	set f [LWDAQ_get_file_name]
	if {$f != ""} {set config(daq_script) $f}
}

#
# Tool_Starter_get_param_index returns the list-style index of the value of the
# parameter named $param_name in step number $step_num in the current
# starter script. This script is stored in info(steps). Thus the value of
# parameter $param_name in step number $step_num is the N'th list element in the
# string that defines step number $step_num, where N is the value returned by
# this routine. If N=0, there is no such parameter named in the script.
#
proc Tool_Starter_get_param_index {step_num param_name} {
	upvar #0 Tool_Starter_info info
	set e [lindex $info(steps) $step_num]
	set index [expr [lsearch $e "$param_name"] + 1]
	return $index
}

#
# Tool_Starter_get_param returns the value of the parameter named param_name in step
# step_num of the current starter script. If there is no such parameter,
# the routine returns and empty string.
#
proc Tool_Starter_get_param {step_num param_name} {
	upvar #0 Tool_Starter_info info
	set index [Tool_Starter_get_param_index $step_num $param_name]
	if {$index == 0} {return ""}
	return [lindex $info(steps) $step_num $index]
}

#
# Tool_Starter_put_param sets the value of the parameter named param_name in step
# step_num of the currrent Acqusifier script. If there is no such parameter,
# the routine does nothing.
#
proc Tool_Starter_put_param {step_num param_name value} {
	upvar #0 Tool_Starter_info info
	set index [Tool_Starter_get_param_index $step_num $param_name]
	if {$index == 0} {return 0}
	lset info(steps) $step_num $index $value
	return 1
}

#
# Tool_Starter_get_field returns the value of the field named field_name in step
# step_num of the current starter script. If there is no such field, the
# routine returns and empty string.
#
proc Tool_Starter_get_field {step_num field_name} {
	return [Tool_Starter_get_param $step_num "$field_name\:"]
}

#
# Tool_Starter_put_field sets the value of the field named field_name in step
# step_num of the currrent Acqusifier script. If there is no such field, the
# routine does nothing.
#
proc Tool_Starter_put_field {step_num field_name value} {
	return [Tool_Starter_put_param $step_num "$field_name\:" $value]
}

#
# Tool_Starter_get_config returns the configuration field of a step.
#
proc Tool_Starter_get_config {step_num} {
	upvar #0 Tool_Starter_info info
	
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
# Tool_Starter_step_list_print prints a list of steps to a text widget. It is
# used by the list_script and load_script routines. If num_lines > 0, the
# routine prints the first num_lines steps and the last num_lines steps.
#
proc Tool_Starter_step_list_print {text_widget num_lines} {
	upvar #0 Tool_Starter_info info
	upvar #0 Tool_Starter_config config

	LWDAQ_print $text_widget "[format {%6s} Step] \
			[format {%-12s} Type] \
			[format {%-22s} Name] \
			[format {%-12s} Tool]" $config(title_color)
	for {set step_num 1} {$step_num <= $info(num_steps)} {incr step_num} {
		set type [string replace [lindex $info(steps) $step_num 0] end end ""]
		if {[lsearch {run spawn starter} $type] < 0} {
			set type "UNKNOWN"
		}
		set name [Tool_Starter_get_field $step_num "name"]
		if {$name == ""} {set name "None"}
		set instrument [Tool_Starter_get_field $step_num "tool"]
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
# Tool_Starter_load_script loads a script into memory from a file. If we specify no
# file, the routine uses the file name given in config(daq_script).
#
proc Tool_Starter_load_script {{fn ""}} {
	upvar #0 Tool_Starter_info info
	upvar #0 Tool_Starter_config config
	
	if {$info(control) == "Load_Script"} {return}
	if {$info(control) != "Idle"} {
		return 0
	}
	set info(control) "Load_Script"
	set info(step) 0
	LWDAQ_update
	
	if {$fn == ""} {set fn $config(daq_script)}
	LWDAQ_print $info(text) "\nLoad: $fn" $config(title_color)

	if {![file exists $fn]} {
		LWDAQ_print $info(text) "ERROR: Can't find starter script."
		LWDAQ_print $info(text) "SUGGESTION: Press \"Browse\" and choose a script."
		set info(control) "Idle"
		return 0
	}
	
	# Read file contents and remove comment lines.
	set as "\n"
	append as [LWDAQ_read_script $fn]
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
	Tool_Starter_step_list_print $info(text) $config(num_steps_show)	
	LWDAQ_print $info(text) "Load okay." $config(result_color)
	
	set info(control) "Idle"
	return 1
}

#
# Tool_Starter_list_script prints an entire script to a separate window.
#
proc Tool_Starter_list_script {} {
	upvar #0 Tool_Starter_info info
	upvar #0 Tool_Starter_config config

	set w $info(window)\.list
	if {[winfo exists $w]} {destroy $w}
	toplevel $w
	wm title $w "Step List"
	set step_list ""
	set t [LWDAQ_text_widget $w 80 20]
	Tool_Starter_step_list_print $t 0

	return 1
}

#
# Tool_Starter_script_string returns a string version of the current script.
#
proc Tool_Starter_script_string {} {
	upvar #0 Tool_Starter_info info
	upvar #0 Tool_Starter_config config

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
# Tool_Starter_execute performs a step, run, or stop. We control the routine through
# the control parameter in the info array, which we also display in the graphical 
# window, should such a window exist.
#
proc Tool_Starter_execute {} {
	upvar #0 Tool_Starter_info info
	upvar #0 Tool_Starter_config config
	global LWDAQ_Info

	# If the info array has been destroyed, abort.	
	if {![array exists info]} {return 0}

	# Detect global LWDAQ reset.
	if {$LWDAQ_Info(reset)} {
		set info(control) "Idle"
		return 1
	}
	
	# If the window is closed, quit the Tool_Starter.
	if {$LWDAQ_Info(gui_enabled) && ![winfo exists $info(window)]} {
		array unset info
		array unset config
		return 0
	}
	
	# Interpret the step name, if it's not an integer
	if {![string is integer -strict $info(step)]} {
		LWDAQ_print $info(text) "\nSearching for step \"$info(step)\"..." \
			$config(title_color)
		for {set i 1} {$i <= $info(num_steps)} {incr i} {
			set name [Tool_Starter_get_field $i "name"]
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
		return 1
	}
	if {$info(control) == "Step"} {
		incr info(step)
		if {$info(step) > $info(num_steps)} {set info(step) 1}
	}
	if {$info(control) == "Run"} {
		incr info(step)
		if {$info(step) > $info(num_steps)} {set info(step) 1}
	}
	
	# Obtain the step type from the script. We take some trouble to remove the 
	# trailing colon from the first word in the step script.
	set step_type [string replace [lindex $info(steps) $info(step) 0] end end ""]
	if {[lsearch {spawn run starter} $step_type] < 0} {
		set step_type "UNKNOWN"
	}

	# Obtain the name of the step. Some steps may have no specific name, in
	# which case we assign a default name which is the step type.
	set name [Tool_Starter_get_field $info(step) "name"]
	if {$name == ""} {set name $step_type\_$info(step)}
	
	# Determine the tool name, if any.
	set tool [Tool_Starter_get_field $info(step) "tool"]
	if {$tool == ""} {set tool "None"}
	
	# Print a title line to the screen.
	LWDAQ_print $info(text) "\nStep $info(step), $step_type, $name, $tool" \
		$config(title_color)
	if {$step_type == "UNKNOWN"} {
		LWDAQ_print $info(text) "ERROR: Unrecognised step type or malformed step,\
			check script."
		set step_type "disabled"
	}

	# Read this step's metadata out of the script.
	set metadata [Tool_Starter_get_field $info(step) "metadata"]
	
	# Read this step's disable value. If it's defined as non-zero, 
	# we set the step type to "disabled".
	set disable [Tool_Starter_get_field $info(step) "disable"]
	if {($disable != "") && ($disable != "0")} {set step_type "disabled"}
		
	# Set the default result string.
	set result "$name okay."
	
	# A run step runs a tool within the same LWDAQ process as the Tool Starter,
	# configures the tool, and executes the step's commands in the TCL interpreter.
	# These commands may start the tool doing something, or just complete its
	# configuration.
	if {$step_type == "run"} {
		# Run the tool.
		if {[catch {LWDAQ_run_tool $tool} error_result]} {
			set result "ERROR: $error_result"
		}

		# Declare the tool config array for local access as tconfig.
		upvar #0 $tool\_config tconfig
		
		# Adjust the tool's configuration parameters.
		foreach {p v} [Tool_Starter_get_config $info(step)] {
			if {[info exists tconfig($p)]} {
				set tconfig($p) $v
				LWDAQ_print $info(text) "$p = \"$v\""
			} elseif {![LWDAQ_is_error_result $result]} {
				set result "ERROR: No parameter \"$p\" to assign value \"$v\"."
			}
		}
		
		# Execute the startup commands.
		set pp [Tool_Starter_get_field $info(step) "commands"]
		if {[catch {eval $pp} error_result]} {
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
		set f [open $sfn r]
		set commands [read $f]
		close $f
		
		# Compose the spawned process configuration file name.
		set cfn [file join [file dirname $config(daq_script)] $tool\_start.tcl]

		# Generate commands to adjust the tool's configuration parameters.
		foreach {p v} [Tool_Starter_get_config $info(step)] {
			append commands "set $tool\_config($p) \"$v\"\n"				
			LWDAQ_print $info(text) "$p = \"$v\""
		}
		
		# Append the configuration commands.
		append commands [Tool_Starter_get_field $info(step) "commands"]
		
		# If "cleanup" is checked, we add a command that deletes the 
		# configuration file.
		if {$config(cleanup)} {append commands "file delete \"$cfn\"\n"}
		
		# Create configuration file
		set f [open $cfn w]
		puts $f $commands
		close $f
		LWDAQ_print $info(text) $cfn brown
		LWDAQ_print $info(text) $commands green
		 
		# Spawn the tool with configuration file.
		cd $LWDAQ_Info(program_dir)
		switch $LWDAQ_Info(os) {
			"MacOS" {exec ./lwdaq --child $cfn &}
			"Windows" {exec ./LWDAQ.bat --child $cfn &}
			"Linux" {exec ./lwdaq --child $cfn &}
		}
	}
	
	if {$step_type == "starter"} {
		set commands [Tool_Starter_get_field $info(step) "commands"]
		if {[catch {eval $commands} error_result]} {
			if {![LWDAQ_is_error_result $result]} {
				set result "ERROR: $error_result"
			}
		}
	}
	
	if {$step_type == "disabled"} {
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
		LWDAQ_post Tool_Starter_execute
		return $result
	}
	if {($info(control) == "Run") && ($info(step) == $info(num_steps))} {
		LWDAQ_print $info(text) "\nEnd" $config(title_color)
		if {$config(auto_quit)} {exit}
	}
	
	set info(control) "Idle"
	return $result
}

proc Tool_Starter_open {} {
	upvar #0 Tool_Starter_config config
	upvar #0 Tool_Starter_info info
	
	set w [LWDAQ_tool_open Tool_Starter]
	if {$w == ""} {return 0}
	
	set f $w.setup
	frame $f
	pack $f -side top -fill x
	
	label $f.l1 -textvariable Tool_Starter_info(control) -width 16 -fg blue
	label $f.l2 -text "Step" -width 4
	entry $f.l3 -textvariable Tool_Starter_info(step) -width 10
	label $f.l4 -text "of" -width 2
	label $f.l5 -textvariable Tool_Starter_info(num_steps) -width 5
	pack $f.l1 $f.l2 $f.l3 $f.l4 $f.l5 -side left -expand 1

	button $f.configure -text Configure -command "LWDAQ_tool_configure Tool_Starter"
	pack $f.configure -side left -expand 1
	button $f.help -text Help -command "LWDAQ_tool_help Tool_Starter"
	pack $f.help -side left -expand 1

	set f $w.controls
	frame $f
	pack $f -side top -fill x
	foreach a {Stop Step Previous Repeat_Previous Run Reset} {
		set b [string tolower $a]
		button $f.$b -text $a -command "Tool_Starter_command $a"
		pack $f.$b -side left -expand 1
	}

	set f $w.script
	frame $f
	pack $f -side top -fill x

	label $f.title -text "Script:"
	entry $f.entry -textvariable Tool_Starter_config(daq_script) -width 45
	button $f.browse -text Browse -command [list LWDAQ_post Tool_Starter_browse_daq_script]
	pack $f.title $f.entry $f.browse -side left -expand 1

	foreach a {Load Store List} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post Tool_Starter_$b\_script"
		pack $f.$b -side left -expand 1
	}
	
	set f $w.checkbuttons
	frame $f
	pack $f -side top -fill x
	foreach a {Auto_Quit Auto_Run Auto_Load Cleanup} {
		set b [string tolower $a]
		checkbutton $f.c$b -text $a -variable Tool_Starter_config($b)
		pack $f.c$b -side left -expand 1
	}
	
	set info(text) [LWDAQ_text_widget $w 90 25 1 1]
	
	return 1
}

Tool_Starter_init
Tool_Starter_open

if {$Tool_Starter_config(auto_load)} {
	Tool_Starter_load_script
}

if {$Tool_Starter_config(auto_run)} {
	Tool_Starter_command Run
}

# This is the final return. There must be no tab or space in
# front of the return command, or else the spawn procedure
# won't work.
return 1

----------Begin Help----------

The Tool_Starter tool uses a starter script on disk to open and start the operation of LWDAQ tools.

----------End Help----------
