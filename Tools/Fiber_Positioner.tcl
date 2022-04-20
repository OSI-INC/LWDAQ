# Direct Fiber Positioning System, a LWDAQ Tool
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
#

#
# Fiber_Positioner_init creates and initializes the tools' configuration
# (config) and information (info) arrays. It reads saved configuration (but not
# information) parameters from disk if we have previously saved our
# configuration to disk. All the configuration parameters are visible in the
# tool's configuration array, where there are save and unsave buttons to create
# and delete a default configuration file.
#
proc Fiber_Positioner_init {} {
	upvar #0 Fiber_Positioner_info info
	upvar #0 Fiber_Positioner_config config
	global LWDAQ_Info LWDAQ_Driver
	
	LWDAQ_tool_init "Fiber_Positioner" "1.10"
	if {[winfo exists $info(window)]} {return 0}

	# The Fiber Positioner control variable tells us its current state. We can stop
	# a Fiber Positioner process by setting the control variable to "Stop", after
	# which the state will return to "Idle".
	set info(control) "Idle"

	# A zoom value for the display, and a choice of intensification.
	set config(zoom) 1.0
	set config(intensify) "exact"
		
	# These numbers are used only when we open the Fiber Positioner panel for the 
	# first time, and need to allocate space for the fiber image.
	set config(image_sensor) "ICX424"
	set config(image_width) [expr \
		[lindex $LWDAQ_Driver($config(image_sensor)\_details) 2] \
		* $config(zoom)]
	set config(image_height) [expr \
		[lindex $LWDAQ_Driver($config(image_sensor)_details) 1] \
		* $config(zoom)]
	
	# The control value for which the control voltages are closest to zero.
	set config(dac_zero) "133"
	
	# We assume only one driver in the test stand.
	set config(daq_ip_addr) "10.0.0.40"
	
	# The driver sockets and device elements for the analog outputs and inputs.
	set config(ns_sock) 1
	set config(n_out_ch) 1
	set config(n_in_ch) 1
	set config(s_out_ch) 2
	set config(s_in_ch) 2
	set config(ew_sock) 2
	set config(e_out_ch) 1
	set config(e_in_ch) 1
	set config(w_out_ch) 2
	set config(w_in_ch) 2
	
	# The factor by which the analog inputs are divided on their way from the 
	# connector to the input amplifier.
	set config(input_divisor) "32.0"
	
	# Parameters that set up the fiber image capture and analysis.
	set config(fiber_type) "9"
	set config(fiber_sock) "3"
	set config(fiber_elements) "A1 A2 A3"
	set config(camera_sock) "4"
	set config(flash_seconds) "0.0003"
	set config(sort_code) "8"
	
	# The north, south, east, and west control values. Set them to produce zero
	# control voltages.
	set config(n_out) $config(dac_zero) 
	set config(s_out) $config(dac_zero) 
	set config(e_out) $config(dac_zero) 
	set config(w_out) $config(dac_zero) 
	
	# The measurements we make of the electrode voltages, have to set them to 
	# something, assume zero.
	set info(n_in) "0"
	set info(s_in) "0"
	set info(e_in) "0"
	set info(w_in) "0"
	
	# The history of spot positions for the tracing.
	set info(trace_history) [list]
	set config(trace_enable) "0"
	set config(trace_persistence) "1000"
	set config(repeat) "0"
	set info(travel_wait) "0"
	
	# Travel configuration.
	set config(travel_index) "0"
	set config(loop_counter) "0"
	set config(pass_counter) "0"
	set config(travel_file) [file normalize ~/Desktop/Travel.txt]
	
	# Waiting time after setting control voltages before we make measurements.
	set config(settling_ms) "100"
	
	# If we have a settings file, read and implement.	
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 

	return 1   
}

#
# A2057_set_out sets the output of one digital to analog converter (DAC) on an
# Input-Output Head (A2057). We pass the routine driver address (ip), a driver
# socket number (dsock), a multiplexer socket number (msock), a device element
# number (dac) and an eight-bit value (value). The routine opens a socket,
# selects the Input-Output Head and sends a string of thirty-five commands to to
# set one of its DAC outputs.
#
proc A2057_set_out {ip dsock msock dac value} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info

	# Construct the sixteen bit value we must send to the DAC.
	if {![string is integer -strict $value]} {
		error "value \"$value\" not an integer."
	}
	if {($value>255) || ($value<0)} {
		error "value \"$value\" must be 0..255."
	}
	set bits 0000[LWDAQ_decimal_to_binary $value 8]0000

	if {[catch {
		# Open a socket to the driver and select the A2057.
		set sock [LWDAQ_socket_open $ip]
		LWDAQ_set_driver_mux $sock $dsock $msock

		# Assert the frame sync bit.
		LWDAQ_transmit_command_hex $sock "6C80"

		# Select DAC1 or DAC2.
		if {$dac == 1} {set c "480"} else {set c "880"}
		LWDAQ_transmit_command_hex $sock "6$c"

		# Transmit sixteen bits. Each bit requires two command words, one
		# to present the bit value and raise the clock, another to continue
		# the bit value while dropping the clock.
		for {set i 0} {$i < [string length $bits]} {incr i} {
			set b [string index $bits $i]
			if {$b} {
				LWDAQ_transmit_command_hex $sock "C$c"
				LWDAQ_transmit_command_hex $sock "8$c"
			} else {
				LWDAQ_transmit_command_hex $sock "4$c"
				LWDAQ_transmit_command_hex $sock "0$c"
			}
		}

		# End the transmission by deselecting both DACs.
		LWDAQ_transmit_command_hex $sock "4080"

		# Close the socket to the driver, freeing it for other activity.
		LWDAQ_wait_for_driver $sock
		LWDAQ_socket_close $sock
	} error_result]} {
		catch {LWDAQ_socket_close $sock}
		error $error_result
	}
	
	return "SUCCESS"
}

#
# Fiber_Positioner_set_nsew takes the north, south, east and west control values and
# writes them to their digital to analog converters. One after the other. The routine
# does not catch errors, so if something goes wrong, the routine aborts with an error.
#
proc Fiber_Positioner_set_nsew {} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info

	A2057_set_out $config(daq_ip_addr) $config(ns_sock) 1 $config(n_out_ch) $config(n_out)
	A2057_set_out $config(daq_ip_addr) $config(ns_sock) 1 $config(s_out_ch) $config(s_out)
	A2057_set_out $config(daq_ip_addr) $config(ew_sock) 1 $config(e_out_ch) $config(e_out)
	A2057_set_out $config(daq_ip_addr) $config(ew_sock) 1 $config(w_out_ch) $config(w_out)
}

#
# Fiber_Positioner_spot_position captures an image from the camera and finds the fiber
# tip image using the BCAM Instrument. If we have tracing enabled, it draws the entire
# history of spot positions as a locus on the image. The routine checks for errors in
# data acquisition and instructs the Fiber Positioner to stop any long-term operation
# if it does encounter an error.
#
proc Fiber_Positioner_spot_position {} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info
	upvar #0 LWDAQ_config_BCAM iconfig
	upvar #0 LWDAQ_info_BCAM iinfo
	
	set iconfig(daq_ip_addr) $config(daq_ip_addr)
	set iconfig(daq_source_driver_socket) $config(fiber_sock)
	set iconfig(daq_source_device_element) $config(fiber_elements)
	set iinfo(daq_source_device_type) $config(fiber_type)
	set iconfig(daq_driver_socket) $config(camera_sock)
	set iconfig(daq_flash_seconds) $config(flash_seconds)
	set iconfig(analysis_num_spots) \
		"[llength $config(fiber_elements)] $config(sort_code)"
	LWDAQ_set_image_sensor $config(image_sensor) BCAM
	
	set result [LWDAQ_acquire BCAM]
	
	if {[LWDAQ_is_error_result $result]} {
		LWDAQ_print $info(log) $result
		set info(control) "Stop"
		return "ERROR"
	}
	
	set result [lreplace $result 0 0]	
	set info(spot_positions) ""
	set index 0
	foreach fiber $config(fiber_elements) {
		incr index
		set x [format %.1f [lindex $result 0]]
		set y [format %.1f [lindex $result 1]]
		append info(spot_positions) "$x $y "
		set result [lrange $result 6 end]
		if {$config(trace_enable)} {
			set x_min [expr $iinfo(daq_image_left) * $iinfo(analysis_pixel_size_um)]
			set y_min [expr $iinfo(daq_image_top) * $iinfo(analysis_pixel_size_um)]
			set x_max [expr $iinfo(daq_image_right) * $iinfo(analysis_pixel_size_um)]
			set y_max [expr $iinfo(daq_image_bottom) * $iinfo(analysis_pixel_size_um)]
			lappend info(trace_history_$index) "$x [expr $y_max - $y + $y_min]"
			if {[llength $info(trace_history_$index)] > $config(trace_persistence)} {
				set info(trace_history_$index) \
					[lrange $info(trace_history_$index) 1 end]
			}
			lwdaq_graph [join $info(trace_history_$index)] $iconfig(memory_name) \
				-x_max $x_max -y_max $y_max -y_min $y_min -x_min $x_min -color 5
		} {
			set info(trace_history_$index) [list]
		}
	}

	lwdaq_draw $iconfig(memory_name) $info(photo) \
		-zoom $config(zoom) \
		-intensify $config(intensify)
	
	return "SUCCESS"
}

#
# Fiber_Positioner_Voltages uses the Voltmeter to read the four electrode
# voltages from two Input-Output Heads (A2057H). The routine checks for errors
# in data acquisition and instructs the Fiber Positioner to stop any long-term
# operation if it does encounter an error
#
proc Fiber_Positioner_voltages {} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info
	upvar #0 LWDAQ_config_Voltmeter iconfig
	upvar #0 LWDAQ_info_Voltmeter iinfo
	
	set iconfig(analysis_auto_calib) 1
	set iconfig(daq_no_sleep) 1
	set iconfig(daq_ip_addr) $config(daq_ip_addr)
	
	# Read the North electrode voltage.
	set iconfig(daq_driver_socket) $config(ns_sock)
	set iconfig(daq_device_element) $config(n_in_ch)
	set result [LWDAQ_acquire Voltmeter]
	if {[LWDAQ_is_error_result $result]} {
		LWDAQ_print $info(log) $result
		set info(control) "Stop"
		return "ERROR"
	}
	set info(n_in) [format %.1f [expr $config(input_divisor) * [lindex $result 1]]]

	# Read the South electrode voltage.
	set iconfig(daq_device_element) $config(s_in_ch)
	set result [LWDAQ_acquire Voltmeter]
	if {[LWDAQ_is_error_result $result]} {
		LWDAQ_print $info(log) $result
		set info(control) "Stop"
		return "ERROR"
	}
	set info(s_in) [format %.1f [expr $config(input_divisor) * [lindex $result 1]]]

	# Read the East electrode voltage.
	set iconfig(daq_driver_socket) $config(ew_sock)
	set iconfig(daq_device_element) $config(e_in_ch)
	set result [LWDAQ_acquire Voltmeter]
	if {[LWDAQ_is_error_result $result]} {
		LWDAQ_print $info(log) $result
		set info(control) "Stop"
		return "ERROR"
	}
	set info(e_in) [format %.1f [expr $config(input_divisor) * [lindex $result 1]]]
	
	# Read the West electrode voltage.
	set iconfig(daq_device_element) $config(w_in_ch)
	set result [LWDAQ_acquire Voltmeter]
	if {[LWDAQ_is_error_result $result]} {
		LWDAQ_print $info(log) $result
		set info(control) "Stop"
		return "ERROR"
	}
	set info(w_in) [format %.1f [expr $config(input_divisor) * [lindex $result 1]]]
	
	return "SUCCESS"
}

#
# Fiber_Positioner_cmd takes a command, such as Zero, Move, Check, Stop, Step or
# Travel, and decides what to do about it. This routine does not execute the
# Fiber Positioner operation itself, but instead posts the execution of the
# operation to the LWDAQ event queue, and then returns. We use this routine from
# buttons, or from other programs that want to manipulate the Fiber Positioner
# because the routine does not stop or deley the graphical user interface.
#
proc Fiber_Positioner_cmd {cmd} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info

	if {$info(control) != "Idle"} {
		if {$cmd == "Stop"} {
			set info(control) "Stop"
		} else {
			if {$cmd != $info(control)} {
				LWDAQ_print $info(log) "ERROR: Cannot $cmd during $info(control)."
			}
		}
	} else {
		if {$cmd == "Stop"} {
			# The stop command does not do anything when we are already stopped.
			LWDAQ_print $info(log) "ERROR: Cannot stop while idle."
		} else {
			# Set the control variable.
			set info(control) $cmd
			
			# Here we construct the Fiber Positioner procedure name we want to
			# call by converting the command to lower case, and trusting that
			# such a procedure exists. We post its execution to the event queue.
			LWDAQ_post Fiber_Positioner_[string tolower $cmd]
		}
	}
	
	return $info(control)
}

#
# Fiber_Positioner_report writes a report of the latest measurement to the text
# window. The report is a list of numbers, with some color coding and formatting
# to make it easy to read.
#
proc Fiber_Positioner_report {{t ""}} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info

	if {$t == ""} {set t $info(data)}
	LWDAQ_print -nonewline $t "[format %.0f $config(n_out)]\
		[format %.0f $config(s_out)]\
		[format %.0f $config(e_out)]\
		[format %.0f $config(w_out)] " green
	LWDAQ_print -nonewline $t "[format %6.1f $info(n_in)]\
		[format %.1f $info(s_in)]\
		[format %.1f $info(e_in)]\
		[format %.1f $info(w_in)] " brown
	LWDAQ_print $t "$info(spot_positions)" black
	return "SUCCESS"
}

#
# Fiber_Positioner_move asserts the latest control values, waits for the
# settling time, measures the electrode voltages, measures the spot position,
# and reports.
#
proc Fiber_Positioner_move {} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info

	if {![winfo exists $info(window)]} {
		return "ABORT"
	}
	
	if {[catch {
		Fiber_Positioner_set_nsew
	} error_result]} {
		LWDAQ_print $info(log) "ERROR: $error_result"
		set info(control) "Idle"
		return "ERROR"
	}
	
	LWDAQ_wait_ms $config(settling_ms)
	Fiber_Positioner_voltages	
	Fiber_Positioner_spot_position
	Fiber_Positioner_report
	
	if {$info(control) == "Move"} {
		set info(control) "Idle"
	}
	return "SUCCESS"
}

#
# Fiber_Positioner_zero sets all control values to their zero value, waits for the
# settling time, measures voltages, measures spot position, and reports.
#
proc Fiber_Positioner_zero {} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info
	upvar #0 LWDAQ_config_BCAM iconfig
	upvar #0 LWDAQ_info_BCAM iinfo
	
	foreach d {n_out s_out e_out w_out} {
		set config($d) $config(dac_zero)
	}
	
	if {[catch {
		Fiber_Positioner_set_nsew
	} error_result]} {
		LWDAQ_print $info(log) "ERROR: $error_result"
		set info(control) "Idle"
		return "ERROR"
	}

	LWDAQ_wait_ms $config(settling_ms)
	Fiber_Positioner_voltages	
	Fiber_Positioner_spot_position
	Fiber_Positioner_report
		
	if {$info(control) == "Zero"} {
		set info(control) "Idle"
	}
	return "SUCCESS"
}

#
# Fiber_Positioner_check does nothing to the voltages, just measures them,
# measures spot position, and reports. It does not wait for the settling time.
#
proc Fiber_Positioner_check {} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info

	Fiber_Positioner_voltages	
	Fiber_Positioner_spot_position
	Fiber_Positioner_report
	
	if {$info(control) == "Check"} {
		set info(control) "Idle"
	}
	return "SUCCESS"
}

#
# Fiber_Positioner_clear clears the display traces.
#
proc Fiber_Positioner_clear {} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info
	upvar #0 LWDAQ_config_BCAM iconfig

	set index 0
	foreach fiber $config(fiber_elements) {
		incr index
		set info(trace_history_$index) [list]
	}
	
	if {[lwdaq_image_exists $iconfig(memory_name)] != ""} {
		lwdaq_image_manipulate $iconfig(memory_name) none -clear 1
		lwdaq_draw $iconfig(memory_name) $info(photo) \
			-zoom $config(zoom) \
			-intensify $config(intensify)
	}
	if {$info(control) == "Clear"} {
		set info(control) "Idle"
	}
	
	return "SUCCESS"
}

#
# Fiber_Positioner_reset sets the travel index, pass counter, and loop 
# counters all to zero. It clears the traces.
#
proc Fiber_Positioner_reset {} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info

	set config(travel_index) 0
	set config(pass_counter) 0
	set config(loop_counter) 0
	Fiber_Positioner_clear
	if {$info(control) == "Reset"} {
		set info(control) "Idle"
	}
	
	return "SUCCESS"
}

#
# Fiber_Positioner_step just calls the travel routine. We assume the control 
# variable has been set to "Step", so the travel routine will know to stop
# after one step.
#
proc Fiber_Positioner_step {} {
	Fiber_Positioner_travel 
}

#
# Fiber_Positioner_goto is designed for use in travel scripts that are executed
# within the Fiber_Positioner_travel routine. The routine arranges for the
# travel index to be equal to the index of a labelled line number at the end of
# a travel step. To accomplish this result, the routine refers to the
# travel_list available in Fiber_Positioner_travel, finds the index of the
# labelled line in the list, and sets the global travel index equal to the
# labelled line's index minus one. The travel routine will subsequently
# increment the index, thus leaving it equal to the labelled line's index at the
# end fo the step. If the label does not exist in the travel file, we generate
# an error.  
#
proc Fiber_Positioner_goto {name} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info
	upvar travel_list travel_list

	# Go through the list until we find "label name".
	set goto_index -1
	for {set index 0} {$index < [llength $travel_list]} {incr index} {
		set line [string trim [lindex $travel_list $index]]
		if {([lindex $line 0] == "label") && ([lindex $line 1] == $name)} {
			set goto_index $index
			break
		}
	}
	
	# If we did not find the label, generate and error.
	if {$goto_index < 0} {
		error "cannot find label \"$name\"."
	}
	
	# Otherwise, set the travel index to the goto_index minus one.
	set config(travel_index) [expr $goto_index - 1]
	
	# Return the index.
	return $goto_index
}

#
# Fiber_Positioner_travel allows us to step through a list of control values of 
# arbitrary length. A travel file consists of north, south, east, west control values
# separated by spaces, each set of values on a separate line. We can include comments
# in the travel file with hash characters.
#
proc Fiber_Positioner_travel {} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info
	global LWDAQ_Info
	
	# Because the travel operation can go on for some time, we must handle the 
	# closing of the window gracefully: we abort if the window is no longer open.
	if {![winfo exists $info(window)]} {
		return "ABORT"
	}

	# Read the travel file, if we can find it. If not, abort and report an error.
	if {[catch {
		set f [open $config(travel_file) r]
		set travel_list [string trim [read $f]]
		close $f
	} error_result]} {
		catch {close $f}
		LWDAQ_print $info(log) "ERROR: $error_result."
		set info(control) "Idle"		
		return "ERROR"
	}
	
	# Our travel output file name we construct from the travel file name by
	# appending a suffix "_Out".
	set outfile [file root $config(travel_file)]_Out.txt
	
	# Split the travel list using line breaks.
	set travel_list [split $travel_list \n]
		
	# If the travel index is not an integer, or is out of range, we set it
	# to zero.
	if {![string is integer -strict $config(travel_index)] \
		|| ($config(travel_index) < 0) \
		|| ($config(travel_index) >= [llength $travel_list])} {
		set config(travel_index) 0
	}
	
	# If this is the first step, clear excess lines from the data and log windows and
	# increment the travel counter.
	if {$config(travel_index) == 0} {
		incr config(pass_counter)
		LWDAQ_print $info(log) "\nStarting [file tail $config(travel_file)],\
			Pass $config(pass_counter)." purple
		$info(log) delete 1.0 "end [expr 0 - $LWDAQ_Info(num_lines_keep)] lines"
		$info(data) delete 1.0 "end [expr 0 - $LWDAQ_Info(num_lines_keep)] lines"
		
	}
		
	# Get the travel_index'th line and extract the first word, which may be a command.
	set line [string trim [lindex $travel_list $config(travel_index)]]
	set first_word [lindex $line 0]

	# Print out the line in the log window with its line number, but don't keep
	# re-printing a wait command line.
	if {($first_word != "wait") || ($info(travel_wait) == 0)} {
		LWDAQ_print $info(log) "[format %-3d $config(travel_index)] $line"
	}
	
	# Address commands and the default behavior, which is to treat the line as four
	# integer control values.
	switch $first_word {
		"" {
		# We do nothing for empty lines, but we increment the index later, so as
		# to make sure the index matches the line number in the travel file.
		
		}
		
		"#" {
		# We do nothing for comment lines, but we increment the index later, so
		# as to make sure the index matches the line number in the travel file.
		
		}
		
		"label" {
		# A label instruction does not itself do anything, but must specify a
		# name. The Fiber_Positioner_goto command takes a a label name as its
		# argument, searches the travel file for "label name" and returns the
		# index of the labeled line. This allows tcl code to jump to the
		# labelled line, so we can build conditional branches or incrementing
		# loops into our travel scripts.
			set label [regsub {label[ \t]*} $line ""]
			if {![string is wordchar $label]} {
				LWDAQ_print $info(log) "ERROR: Bad label name \"$label\"."
				set info(control) "Idle"
				return "ERROR"
			}
		}
		
		"tcl" {
		# The tcl instruction specifies that the rest of the line should be
		# executed as a TCL command. We delete the tcl key word in the line
		# and pass to TCL interpreter with the "eval" command.
			if {[catch {
				eval [regsub {tcl[ \t]*} $line ""]
			} error_result]} {
				LWDAQ_print $info(log) "ERROR: $error_result"
				set info(control) "Idle"
				return "ERROR"
			}
		}
		
		"tcl_source" {
		# The tcl_source instruction specifies that the next entry in the line
		# is the name of a file in the same directory as the travel script, and
		# this file should be executed as a tcl script using the TCL "source"
		# command.
			set sft [lindex $line 1]
			set sfn [file join [file dirname $config(travel_file)] $sft]
			if {![file exists $sfn]} {
				LWDAQ_print $info(log) "ERROR: No such file \"$sfn\"."
				set info(control) "Idle"
				return "ERROR"				
			}
			if {[catch {
				source $sfn
			} error_result]} {
				LWDAQ_print $info(log) "ERROR: $error_result"
				set info(control) "Idle"
				return "ERROR"
			}
		}
		
		"wait" {
		# The wait instruction holds the travel operation at the same step until
		# a specified number of seconds has elapsed. The operation continues to
		# post itself to the event loop, so will respond to Stop commands.
			set wait_seconds [lindex $line 1]
			if {![string is integer -strict $wait_seconds]} {
				LWDAQ_print $info(log) "ERROR: Invalid wait time \"$wait_seconds\"."
				set info(control) "Idle"
				return "ERROR"
			}
			if {$info(travel_wait) == 0} {
				set info(travel_wait) [clock seconds]
				incr config(travel_index) -1
			} else {
				if {[clock seconds] - $info(travel_wait) >= $wait_seconds} {
					set info(travel_wait) 0
				} else {
					incr config(travel_index) -1
				}
			}
		}
		
		default {
		# At this point, the only valid option for the line is that it contain four
		# control values. We check to make sure we have four integer
		# values between 0 and 255. 
			set control_values 1
			for {set i 0} {$i < 4} {incr i} {
				if {![string is integer -strict [lindex $line $i]] \
					|| ([lindex $line $i] < 0) \
					|| ([lindex $line $i] > 255)} {
					LWDAQ_print $info(log) "ERROR: Invalid control value \"$line\"."
					set info(control) "Idle"
					return "ERROR"
				}
			}

			# Extract the four integers from the line.	
			scan $line %d%d%d%d config(n_out) config(s_out) config(e_out) config(w_out)
	
			# Apply the new control values to all four electrodes.
			if {[catch {
				Fiber_Positioner_set_nsew
			} error_result]} {
				LWDAQ_print $info(log) "ERROR: $error_result"
				set info(control) "Idle"
				return "ERROR"
			}
	
			# Wait for the fiber to settle, then measure voltages, spot position, and
			# report to text window.
			LWDAQ_wait_ms $config(settling_ms)
			Fiber_Positioner_voltages	
			Fiber_Positioner_spot_position
			Fiber_Positioner_report
		}
	}
	
	# Decide what to do next: continue through list, start at beginning again or
	# finish.
	incr config(travel_index)
	if {($info(control) == "Stop") || ($info(control) == "Step")} {
		set info(control) "Idle"
		return "ABORT"
	} elseif {($config(travel_index) < [llength $travel_list])} {
		LWDAQ_post "Fiber_Positioner_travel"
		return "SUCCESS"
	} else {
		LWDAQ_print $info(log) "Travel Complete, Pass $config(pass_counter)." purple
		if {$config(repeat)} {
			LWDAQ_post "Fiber_Positioner_travel"
			return "SUCCESS"
		} else {
			set info(control) "Idle"
			return "SUCCESS"
		}
	}
}

#
# Fiber_Positioner_travel_edit creats a travel list file if one does not exist
# under the current file name, or reads an existing file. Displays the file for
# editing, provides buttons to save under same or different names.
#
proc Fiber_Positioner_travel_edit {} {
	upvar #0 Fiber_Positioner_info info
	upvar #0 Fiber_Positioner_config config
	
	if {![file exists $config(travel_file)]} {
		LWDAQ_edit_script New 
	} else {
		LWDAQ_edit_script Open $config(travel_file)
	}
	return "SUCCESS"
}

#
# Fiber_Positioner_travel_browse allows us to choose a travel list file.
#
proc Fiber_Positioner_travel_browse {} {
	upvar #0 Fiber_Positioner_info info
	upvar #0 Fiber_Positioner_config config

	set fn [LWDAQ_get_file_name] 
	if {$fn != ""} {
		set config(travel_file) $fn
	}
	return $config(travel_file)
}

#
# Fiber_Positioner_open creates the Fiber Positioner window.
#
proc Fiber_Positioner_open {} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return 0}
	
	set ff [frame $w.parameters]
	pack $ff -side top -fill x
	
	set f [frame $ff.controls]
	pack $f -side top -fill x
	
	label $f.state -textvariable Fiber_Positioner_info(control) -width 20 -fg blue
	pack $f.state -side left -expand 1
	foreach a {Zero Move Check Travel Step Stop Clear Reset} {
		set b [string tolower $a]
		button $f.$b -text $a -command "Fiber_Positioner_cmd $a"
		pack $f.$b -side left -expand 1
	}
	foreach a {Help Configure} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_tool_$b $info(name)"
		pack $f.$b -side left -expand 1
	}
	
	set f [frame $ff.fiber]
	pack $f -side top -fill x

	foreach a {daq_ip_addr fiber_sock fiber_elements \
			flash_seconds camera_sock settling_ms} {
		label $f.l$a -text $a -fg green
		entry $f.e$a -textvariable Fiber_Positioner_config($a) \
			-width [expr [string length $config($a)] + 2]
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	set f [frame $ff.pz]
	pack $f -side top -fill x

	foreach a {ns_sock n_out_ch n_in_ch s_out_ch s_in_ch ew_sock \
			e_out_ch e_in_ch w_out_ch w_in_ch} {
		label $f.l$a -text $a -fg green
		entry $f.e$a -textvariable Fiber_Positioner_config($a) -width 2
		pack $f.l$a $f.e$a -side left -expand yes
	}

	set f [frame $ff.dacs]
	pack $f -side top -fill x
	
	foreach d {n_out s_out e_out w_out} {
		set a [string tolower $d]
		label $f.l$a -text $d -fg green
		entry $f.e$a -textvariable Fiber_Positioner_config($a) -width 5
		pack $f.l$a $f.e$a -side left -expand yes
	}
	foreach d {n_in s_in e_in w_in} {
		set a [string tolower $d]
		label $f.l$a -text $d -fg green
		label $f.e$a -textvariable Fiber_Positioner_info($a) -width 5
		pack $f.l$a $f.e$a -side left -expand yes
	}

	set f [frame $ff.travel]
	pack $f -side top -fill x

	label $f.til -text "travel_index" -fg green
	entry $f.tie -textvariable Fiber_Positioner_config(travel_index) -width 4
	pack $f.til $f.tie -side left -expand yes
	label $f.tl -text "travel_file" -fg green
	entry $f.tlf -textvariable Fiber_Positioner_config(travel_file) -width 40
	pack $f.tl $f.tlf -side left -expand yes
	button $f.browse -text "Browse" -command Fiber_Positioner_travel_browse
	button $f.edit -text "Edit" -command Fiber_Positioner_travel_edit
	pack $f.browse $f.edit -side left -expand yes
	checkbutton $f.repeat -text "Repeat" -variable Fiber_Positioner_config(repeat) 
	pack $f.repeat -side left -expand yes
	checkbutton $f.trace -text "Trace" -variable Fiber_Positioner_config(trace_enable)
	pack $f.trace -side left -expand yes
	label $f.tpl -text "pass" -fg green
	entry $f.tpe -textvariable Fiber_Positioner_config(pass_counter) -width 4
	pack $f.tpl $f.tpe -side left -expand yes
	label $f.tll -text "loop" -fg green
	entry $f.tle -textvariable Fiber_Positioner_config(loop_counter) -width 4
	pack $f.tll $f.tle -side left -expand yes
	
	set f [frame $w.image_frame]
	pack $f -side left -fill y 
	
	set info(photo) [image create photo -width 700 -height 520]
	label $f.image -image $info(photo) 
	pack $f.image -side top -expand yes

	set info(data) [LWDAQ_text_widget $f 60 15 1 1]
	LWDAQ_print $info(data) "Fiber Positioner Data" purple

	set f [frame $w.log]
	pack $f -side right -fill both -expand true
	
	set info(log) [LWDAQ_text_widget $f 30 60 1 1]
	LWDAQ_print $info(log) "Fiber Positioner Log" purple
	
	return 1
}

Fiber_Positioner_init
Fiber_Positioner_open
	
return 1

----------Begin Help----------

http://www.opensourceinstruments.com/Fiber_Positioner/Development.html#Software

----------End Help----------

----------Begin Data----------

----------End Data----------