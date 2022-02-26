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
	
	LWDAQ_tool_init "Fiber_Positioner" "1.6"
	if {[winfo exists $info(window)]} {return 0}

	# The Fiber Positioner control variable tells us its current state. We can stop
	# a Fiber Positioner process by setting the control variable to "Stop", after
	# which the state will return to "Idle".
	set info(control) "Idle"
	
	# These numbers are used only when we open the Fiber Positioner panel for the 
	# first time, and need to allocate space for the fiber image.
	set config(image_width) 700
	set config(image_height) 520
	
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
	set config(fiber_element) "A1"
	set config(camera_sock) "4"
	set config(ccd_type) "ICX424"
	set config(flash_seconds) "0.0003"
	set config(num_spots) "1"
	
	# The north, south, east, and west control values. Set them to produce zero
	# control voltages.
	set config(n_out) $config(dac_zero) 
	set config(s_out) $config(dac_zero) 
	set config(e_out) $config(dac_zero) 
	set config(w_out) $config(dac_zero) 
	
	# The measurements we make of the electrode voltages, have to set them to 
	# something, assume zero.
	set config(n_in) "0"
	set config(s_in) "0"
	set config(e_in) "0"
	set config(w_in) "0"
	
	# The history of spot positions for the tracing.
	set config(history) [list]
	set config(trace) "0"
	set config(repeat) "0"
	
	# Travel configuration.
	set info(travel_window) "$info(window)\.travel_edit"
	set config(travel_file) [file normalize ~/Desktop/Travel_List.txt]
	
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
	set iconfig(daq_source_device_element) $config(fiber_element)
	set iinfo(daq_source_device_type) $config(fiber_type)
	set iconfig(daq_driver_socket) $config(camera_sock)
	set iconfig(daq_flash_seconds) $config(flash_seconds)
	set iconfig(analysis_num_spots) $config(num_spots)
	LWDAQ_set_image_sensor ICX424 BCAM
	
	set result [LWDAQ_acquire BCAM]
	
	if {![LWDAQ_is_error_result $result]} {
		lwdaq_draw $iconfig(memory_name) $info(photo)
	} else {
		LWDAQ_print $info(text) $result
		set info(control) "Stop"
		return "ERROR"
	}
	
	set config(spot_x) [lindex $result 1]
	set config(spot_y) [lindex $result 2]
		
	if {$config(trace)} {
		set x_min [expr $iinfo(daq_image_left) * $iinfo(analysis_pixel_size_um)]
		set y_min [expr $iinfo(daq_image_top) * $iinfo(analysis_pixel_size_um)]
		set x_max [expr $iinfo(daq_image_right) * $iinfo(analysis_pixel_size_um)]
		set y_max [expr $iinfo(daq_image_bottom) * $iinfo(analysis_pixel_size_um)]
		lappend config(history) \
			"$config(spot_x) [expr $y_max - $config(spot_y) + $y_min]"
		lwdaq_graph [join $config(history)] $iconfig(memory_name) \
			-x_max $x_max -y_max $y_max -y_min $y_min -x_min $x_min -color 5
		lwdaq_draw $iconfig(memory_name) $info(photo)
	} {
		set config(history) [list]
	}
	
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
		LWDAQ_print $info(text) $result
		set info(control) "Stop"
		return "ERROR"
	}
	set config(n_in) [format %.1f [expr $config(input_divisor) * [lindex $result 1]]]

	# Read the South electrode voltage.
	set iconfig(daq_device_element) $config(s_in_ch)
	set result [LWDAQ_acquire Voltmeter]
	if {[LWDAQ_is_error_result $result]} {
		LWDAQ_print $info(text) $result
		set info(control) "Stop"
		return "ERROR"
	}
	set config(s_in) [format %.1f [expr $config(input_divisor) * [lindex $result 1]]]

	# Read the East electrode voltage.
	set iconfig(daq_driver_socket) $config(ew_sock)
	set iconfig(daq_device_element) $config(e_in_ch)
	set result [LWDAQ_acquire Voltmeter]
	if {[LWDAQ_is_error_result $result]} {
		LWDAQ_print $info(text) $result
		set info(control) "Stop"
		return "ERROR"
	}
	set config(e_in) [format %.1f [expr $config(input_divisor) * [lindex $result 1]]]
	
	# Read the West electrode voltage.
	set iconfig(daq_device_element) $config(w_in_ch)
	set result [LWDAQ_acquire Voltmeter]
	if {[LWDAQ_is_error_result $result]} {
		LWDAQ_print $info(text) $result
		set info(control) "Stop"
		return "ERROR"
	}
	set config(w_in) [format %.1f [expr $config(input_divisor) * [lindex $result 1]]]
	
	return "SUCCESS"
}

#
# Fiber_Positioner_cmd takes a command, such as Step, Stop, Check, Travel, or
# Zero, and decides what to do about it. This routine does not execute the Fiber
# Positioner operation itself, but instead posts the execution of the operation
# to the LWDAQ event queue, and then returns. We use this routine from buttons,
# or from other programs that want to manipulate the Fiber Positioner because the
# routine does not stop or deley the graphical user interface or the program that
# wants to instruct the Fiber Positioner. A master program instructing the Fiber
# Positioner should use this routine to, for example, initiate a "Step", after which
# the master program should check the Fiber_Positioner_info(control) parameter
# until it returns to "Idle". But note that the master program itself must be 
# posting itself to the LWDAQ event queue, or else the master program will take
# over the TCL interpreter and prevent the Fiber Positioner from doing anything.
#
proc Fiber_Positioner_cmd {cmd} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info

	if {$info(control) != "Idle"} {
		if {$cmd == "Stop"} {
			set info(control) "Stop"
		} else {
			LWDAQ_print $info(text) "ERROR: Cannot $cmd during $info(control)."
		}
	} else {
		if {$cmd == "Stop"} {
			LWDAQ_print $info(text) "ERROR: Cannot stop while idle."
		} else {
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

	if {$t == ""} {set t $info(text)}
	LWDAQ_print -nonewline $t "[format %4.0f $config(n_out)]\
		[format %4.0f $config(s_out)]\
		[format %4.0f $config(e_out)]\
		[format %4.0f $config(w_out)] " green
	LWDAQ_print -nonewline $t "[format %6.1f $config(spot_x)]\
		[format %6.1f $config(spot_y)] " black
	LWDAQ_print $t "[format %6.1f $config(n_in)]\
		[format %6.1f $config(s_in)]\
		[format %6.1f $config(e_in)]\
		[format %6.1f $config(w_in)]" brown
	return "SUCCESS"
}

#
# Fiber_Positioner_step asserts the latest control values, waits for the
# settling time, measures the electrode voltages, measures the spot position,
# and reports.
#
proc Fiber_Positioner_step {} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info

	if {![winfo exists $info(window)]} {
		return "ABORT"
	}
	
	set info(control) "Step"
	
	if {[catch {
		Fiber_Positioner_set_nsew
	} error_result]} {
		LWDAQ_print $info(text) "ERROR: $error_result"
		set info(control) "Idle"
		return "ERROR"
	}
	
	LWDAQ_wait_ms $config(settling_ms)
	Fiber_Positioner_voltages	
	Fiber_Positioner_spot_position
	Fiber_Positioner_report
	
	set info(control) "Idle"
	return "SUCCESS"
}

#
# Fiber_Positioner_travel allows us to step through a list of control values of 
# arbitrary length. A travel file consists of north, south, east, west control values
# separated by spaces, each set of values on a separate line. We can include comments
# in the travel file with hash characters. 
#
proc Fiber_Positioner_travel {{index 0}} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info
	upvar #0 LWDAQ_config_BCAM iconfig
	upvar #0 LWDAQ_info_BCAM iinfo
	
	# Because the travel operation can go on for some time, we must handle the 
	# closing of the window gracefully: we abort if the window is no longer open.
	if {![winfo exists $info(window)]} {
		return "ABORT"
	}

	# Read the travel file, if we can find it.
	if {[catch {
		set f [open $config(travel_file) r]
		set travel_list [string trim [read $f]]
		close $f
	} error_result]} {
		catch {close $f}
		LWDAQ_print $info(text) "ERROR: $error_result."
		set info(control) "Idle"		
		return "ERROR"
	}
	
	# Make sure the control variable is set to Travel, which it may be already, but
	# certainly should be at this point.
	set info(control) "Travel"

	# Remove comment lines from travel list and split the travel list using line
	# breaks.
	set as "\n"
	append as $travel_list
	regsub -all {\n[ \t]*#[^\n]*} $as "" travel_list
	set travel_list [split [string trim $travel_list] \n]

	# Get the index'th set of north, south, east, and west control values from
	# the list contained in the file. We check to make sure we have four integer
	# values between 0 and 255 before we proceed.
	set values [lindex $travel_list $index]
	for {set i 0} {$i < 4} {incr i} {
		if {![string is integer -strict [lindex $values $i]]} {
			LWDAQ_print $info(text) "ERROR: Invalid line \"$values\" in travel file."
			set info(control) "Idle"
			return "ERROR"
		}
	}
	scan $values %d%d%d%d config(n_out) config(s_out) config(e_out) config(w_out)
	
	# Apply the new dac values to all four electrodes.
	if {[catch {
		Fiber_Positioner_set_nsew
	} error_result]} {
		LWDAQ_print $info(text) "ERROR: $error_result"
		set info(control) "Idle"
		return "ERROR"
	}
	
	# Wait for the fiber to settle, then measure voltages, spot position, and
	# report to text window.
	LWDAQ_wait_ms $config(settling_ms)
	Fiber_Positioner_voltages	
	Fiber_Positioner_spot_position
	Fiber_Positioner_report
	
	# Decide what to do next: continue through list, start at beginning again or
	# finish.
	if {$info(control) == "Stop"} {
		set info(control) "Idle"
		return "ABORT"
	} elseif {[expr $index + 1] < [llength $travel_list]} {	
		incr index
		LWDAQ_post "Fiber_Positioner_travel $index"
		return "SUCCESS"
	} elseif {$config(repeat)} {
		set index 0
		LWDAQ_post "Fiber_Positioner_travel $index"
		return "SUCCESS"
	} else {
		set info(control) "Idle"
		return "SUCCESS"
	}
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
	
	set info(control) "Zero"

	foreach d {n_out s_out e_out w_out} {
		set config($d) $config(dac_zero)
	}
	
	if {[catch {
		Fiber_Positioner_set_nsew
	} error_result]} {
		LWDAQ_print $info(text) "ERROR: $error_result"
		set info(control) "Idle"
		return "ERROR"
	}

	LWDAQ_wait_ms $config(settling_ms)
	Fiber_Positioner_voltages	
	Fiber_Positioner_spot_position
	Fiber_Positioner_report
		
	set info(control) "Idle"
	return "SUCCESS"
}

#
# Fiber_Positioner_check does nothing to the voltages, just measures them,
# measures spot position, and reports. It does not wait for the settling time.
#
proc Fiber_Positioner_check {} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info

	set info(control) "Check"
	
	Fiber_Positioner_voltages	
	Fiber_Positioner_spot_position
	Fiber_Positioner_report
	
	set info(control) "Idle"
	return "SUCCESS"
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
	
	set f $w.controls
	frame $f
	pack $f -side top -fill x
	
	label $f.state -textvariable Fiber_Positioner_info(control) -width 20 -fg blue
	pack $f.state -side left -expand 1
	foreach a {Step Zero Check Travel Stop} {
		set b [string tolower $a]
		button $f.$b -text $a -command "Fiber_Positioner_cmd $a"
		pack $f.$b -side left -expand 1
	}
	foreach a {Help Configure} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_tool_$b $info(name)"
		pack $f.$b -side left -expand 1
	}
	
	set f [frame $w.fiber]
	pack $f -side top -fill x

	foreach a {daq_ip_addr fiber_sock fiber_element \
			flash_seconds camera_sock settling_ms} {
		label $f.l$a -text $a
		entry $f.e$a -textvariable Fiber_Positioner_config($a) \
			-width [expr [string length $config($a)] + 2]
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	set f [frame $w.pz]
	pack $f -side top -fill x

	foreach a {ns_sock n_out_ch n_in_ch s_out_ch s_in_ch ew_sock \
			e_out_ch e_in_ch w_out_ch w_in_ch} {
		label $f.l$a -text $a
		entry $f.e$a -textvariable Fiber_Positioner_config($a) -width 2
		pack $f.l$a $f.e$a -side left -expand yes
	}

	set f [frame $w.dacs]
	pack $f -side top -fill x
	
	foreach d {n_out s_out e_out w_out n_in s_in e_in w_in} {
		set a [string tolower $d]
		label $f.l$a -text $d
		entry $f.e$a -textvariable Fiber_Positioner_config($a) -width 5
		pack $f.l$a $f.e$a -side left -expand yes
	}

	set f [frame $w.travel]
	pack $f -side top -fill x

	label $f.tl -text "Travel List:" 
	entry $f.tlf -textvariable Fiber_Positioner_config(travel_file) -width 60
	pack $f.tl $f.tlf -side left -expand yes
	button $f.browse -text "Browse" -command Fiber_Positioner_travel_browse
	button $f.edit -text "Edit" -command Fiber_Positioner_travel_edit
	pack $f.browse $f.edit -side left -expand yes
	checkbutton $f.repeat -text "Repeat" -variable Fiber_Positioner_config(repeat) 
	pack $f.repeat -side left -expand yes
	checkbutton $f.trace -text "Trace" -variable Fiber_Positioner_config(trace)
	pack $f.trace -side left -expand yes
	
	set f [frame $w.image_frame]
	pack $f -side top -fill x
	
	set info(photo) [image create photo -width 700 -height 520]
	label $f.image -image $info(photo) 
	pack $f.image -side left -expand yes

	set info(text) [LWDAQ_text_widget $w 100 15]

	LWDAQ_print $info(text) "$info(name) Version $info(version)\n" purple
	
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