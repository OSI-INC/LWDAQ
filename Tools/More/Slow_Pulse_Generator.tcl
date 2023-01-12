#
# Slow Pulse Generator, a LWDAQ Tool
#
# Copyright (C) 2014-2023 Kevan Hashemi, Open Source Instruments
#
# The Slow_Pulse_Generator Tool uses LWDAQ command transmissions to generate a sequence
# of pulses.
#

#
# Initialize the configuration and information arrays.
#
proc Slow_Pulse_Generator_init {} {
	upvar #0 Slow_Pulse_Generator_info info
	upvar #0 Slow_Pulse_Generator_config config
	global LWDAQ_Info LWDAQ_Driver
	
	LWDAQ_tool_init "Slow_Pulse_Generator" "1.2"
	if {[winfo exists $info(window)]} {return 0}

	set config(datetime_format) {%d-%b-%Y %H:%M:%S}
	set config(start_time) [Slow_Pulse_Generator_datetime_convert [clock seconds]]
	set config(stimulus_period_s) 10
	set config(pulse_separation_s) 1
	set config(pulse_length_s) 1
	set config(num_pulses) 3
	set config(ip_addr) 10.0.0.37
	set config(driver_socket) 1
	set config(mux_socket) 1
	set config(on_command) 0104
	set config(off_command) 0004
	set config(log_file) "~/Desktop/Slow_Pulse_Generator_Log.txt"
	set config(lwdaq_enabled) 1
	set config(channel_select) "*"
	
	set info(control) "Idle"
	set info(pulse_num) 0
	set info(stimulus_num) 0
	set info(state) "OFF"
	
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 

	return 1   
}

#
# Convert between integer seconds to the datetime format given in the 
# configuration array.
#
proc Slow_Pulse_Generator_datetime_convert {datetime} {
	upvar #0 Slow_Pulse_Generator_config config
	
	if {[string is integer $datetime]} {
		set newformat [clock format $datetime -format $config(datetime_format)]
	} {
		if {[catch {
			set newformat [clock scan $datetime -format $config(datetime_format)]
		} error_result]} {
			LWDAQ_print $info(text) "ERROR: Invalid clock string, \"$datetime\"."
			set newformat 0
		}
	}
	return $newformat
}

#
# Specify the log file name and location.
#
proc Slow_Pulse_Generator_browse {} {
	upvar #0 Slow_Pulse_Generator_config config
	upvar #0 Slow_Pulse_Generator_info info

	set fn [LWDAQ_put_file_name "log.txt"]
	if {$fn != ""} {
		set config(log_file) $fn
	}
}

#
# Set the control variable and call the execute procedure as necessary.
#
proc Slow_Pulse_Generator_command {action} {
	upvar #0 Slow_Pulse_Generator_config config
	upvar #0 Slow_Pulse_Generator_info info

	if {$info(control) == $action} {
		return $action
	}
	if {($info(control) == "Idle") && ($action == "Stop")} {
		return $action
	}
	if {$info(control) == "Idle"} {
		set info(control) $action
		LWDAQ_post "Slow_Pulse_Generator_execute"
		return $action
	}
	set info(control) $action
	return $action
}

#
# Slow_Pulse_Generator_set sets the TTL output on the octal data receiver
#
proc Slow_Pulse_Generator_set {state} {
	upvar #0 Slow_Pulse_Generator_config config
	upvar #0 Slow_Pulse_Generator_info info

	if {[string match -nocase "on" $state]} {
		LWDAQ_set_bg $info(state_label) green
		set info(state) "ON"
		set cmd $config(on_command)
	} {
		LWDAQ_set_bg $info(state_label) red
		set info(state) "OFF"
		set cmd $config(off_command)
	}
	if {$config(lwdaq_enabled)} {
		if {[catch {
			set sock [LWDAQ_socket_open $config(ip_addr)]
			LWDAQ_set_driver_mux $sock $config(driver_socket) $config(mux_socket)
			LWDAQ_transmit_command_hex $sock $cmd
			LWDAQ_socket_close $sock
			set result "[clock seconds] 0.0\
				\"$config(channel_select)\"\
				\"$info(state),\
				[Slow_Pulse_Generator_datetime_convert [clock seconds]]\""
		} error_result]} {
			set result "[clock seconds] 0.0\
				\"$config(channel_select)\"\
				\"$info(state),\
				[Slow_Pulse_Generator_datetime_convert [clock seconds]],\
				$error_result\""
			LWDAQ_print $info(text) "ERROR: $error_result"
		}
	} {
		set result "[clock seconds] 0.0\
			\"$config(channel_select)\"\
			\"$info(state),\
			[Slow_Pulse_Generator_datetime_convert [clock seconds]],\
			LWDAQ DISABLED\""
	}
	LWDAQ_print $config(log_file) $result
}

#
# Execute the Slow Pulse Generator process, and if necessary, post this
# routine for execution in the event queue to continue the stimulus.
#
proc Slow_Pulse_Generator_execute {} {
	upvar #0 Slow_Pulse_Generator_config config
	upvar #0 Slow_Pulse_Generator_info info

	if {![winfo exists $info(window)]} {
		return ""
	}

	if {$config(stimulus_period_s) < \
		[expr ($config(pulse_separation_s) + $config(pulse_length_s)) \
			* $config(num_pulses)]} {
		LWDAQ_print $info(text) "ERROR: Pulses longer than stimulus period."
		set info(control) "Idle"
		return ""
	}

	set ct [clock seconds]

	if {$info(control) == "Stop"} {
		Slow_Pulse_Generator_set OFF
		set info(control) "Idle"
	}
	
	if {$info(control) == "Reset"} {
		Slow_Pulse_Generator_set OFF
		set config(start_time) [Slow_Pulse_Generator_datetime_convert $ct]
		set info(pulse_num) 0
		set info(stimulus_num) 0
		set info(control) "Idle"
	}

	if {$info(control) == "Start"} {
		if {$ct > [Slow_Pulse_Generator_datetime_convert $config(start_time)]} {
			set config(start_time) [Slow_Pulse_Generator_datetime_convert $ct]
		}
		set info(pulse_num) 1
		set info(stimulus_num) 1
		Slow_Pulse_Generator_set ON
		set info(control) "Pulse"
	}

	if {$info(control) == "Pulse"} {
		set st [Slow_Pulse_Generator_datetime_convert $config(start_time)]
		if {$ct >= [expr $st + $info(pulse_num) * $config(pulse_length_s) \
			+ ($info(pulse_num) - 1) * $config(pulse_separation_s)]} {
			Slow_Pulse_Generator_set OFF
			if {$info(pulse_num) < $config(num_pulses)} {		
				set info(control) "Separation"	
			} {
				set config(start_time) [Slow_Pulse_Generator_datetime_convert \
					[expr $st + $config(stimulus_period_s) ] ]
				set info(control) "Waiting"
			}
		}
	}
	
	if {$info(control) == "Separation"} {
		set st [Slow_Pulse_Generator_datetime_convert $config(start_time)]
		if {$ct >= [expr $st + $info(pulse_num) * $config(pulse_length_s) \
			+ $info(pulse_num) * $config(pulse_separation_s)]} {
			incr info(pulse_num)
			Slow_Pulse_Generator_set ON
			set info(control) "Pulse"	
		}
	}
	
	if {$info(control) == "Waiting"} {
		set st [Slow_Pulse_Generator_datetime_convert $config(start_time)]
		if {$ct >= $st} {
			set info(pulse_num) 1
			incr info(stimulus_num)
			Slow_Pulse_Generator_set ON
			set info(control) "Pulse"	
		}
	}

	if {$info(control) != "Idle"} {
		LWDAQ_post Slow_Pulse_Generator_execute
	}
	return $info(control)
}

#
# Open the Slow Pulse Generator window.
#
proc Slow_Pulse_Generator_open {} {
	upvar #0 Slow_Pulse_Generator_config config
	upvar #0 Slow_Pulse_Generator_info info

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return 0}
	
	set f $w.controls
	frame $f
	pack $f -side top -fill x
	
	label $f.control -textvariable Slow_Pulse_Generator_info(control) \
		-fg blue -width 10
	pack $f.control -side left -expand 1
	foreach a {Start Stop Reset} {
		set b [string tolower $a]
		button $f.$b -text $a -command "Slow_Pulse_Generator_command $a"
		pack $f.$b -side left -expand 1
	}
	foreach a {Help Configure} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_tool_$b $info(name)"
		pack $f.$b -side left -expand 1
	}
	set info(state_label) $f.state
	label $f.state -textvariable Slow_Pulse_Generator_info(state) \
		-fg blue -width 6 -bg red
	pack $f.state -side left -expand 1

	set f $w.file
	frame $f
	pack $f -side top -fill x
	label $f.lf -text "log_file" -width 8 -fg blue
	entry $f.ef -textvariable Slow_Pulse_Generator_config(log_file) \
		-relief sunken -bd 1 -width 60
	button $f.bf -text "Change" -command Slow_Pulse_Generator_browse
	pack $f.lf $f.ef $f.bf -side left -expand yes

	set f $w.parameters
	frame $f
	pack $f -side top -fill x
	
	foreach {a b} {stimulus_period_s pulse_length_s pulse_separation_s \
		start_time num_pulses ip_addr driver_socket mux_socket} {
		label $f.l$a -text $a -width 18 -anchor w
		entry $f.e$a -textvariable Slow_Pulse_Generator_config($a) -relief sunken -bd 1 
		label $f.l$b -text $b -width 18 -anchor w
		entry $f.e$b -textvariable Slow_Pulse_Generator_config($b) -relief sunken -bd 1 
		grid $f.l$a $f.e$a $f.l$b $f.e$b -sticky nsew
	}
	
	set f $w.counts
	frame $f
	pack $f -side top -fill x
	foreach {a} {pulse_num stimulus_num} {
		label $f.l$a -text $a -width 18 -anchor w
		label $f.e$a -textvariable Slow_Pulse_Generator_info($a) -fg blue
		pack $f.l$a $f.e$a -side left -expand yes
	}
	checkbutton $f.cle -text "lwdaq_enabled" -variable Slow_Pulse_Generator_config(lwdaq_enabled)
	pack $f.cle -side left -expand yes

	set info(text) [LWDAQ_text_widget $w 40 15]

	LWDAQ_print $info(text) "$info(name) Version $info(version) \n"
	
	return 1
}

Slow_Pulse_Generator_init
Slow_Pulse_Generator_open
	
return 1

----------Begin Help----------

http://www.opensourceinstruments.com/Electronics/A3008/M3008.html

----------End Help----------

----------Begin Data----------

----------End Data----------