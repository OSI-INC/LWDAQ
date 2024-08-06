# Direct Fiber Positioning System Manager, a LWDAQ Tool
#
# Copyright (C) 2022-2024 Kevan Hashemi, Open Source Instruments Inc.
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <https://www.gnu.org/licenses/>.

#
# DFPS_Manager_init creates and initializes the tool's configuration (config)
# and information (info) arrays. It reads saved configuration (but not
# information) parameters from disk if we have previously saved our
# configuration to disk. All the configuration parameters are visible in the
# tool's configuration array, where there are save and unsave buttons to create
# and delete a default configuration file.
#
proc DFPS_Manager_init {} {
	upvar #0 DFPS_Manager_info info
	upvar #0 DFPS_Manager_config config
	upvar #0 LWDAQ_info_BCAM iinfo
	upvar #0 LWDAQ_config_BCAM iconfig
	global LWDAQ_Info LWDAQ_Driver
	
	LWDAQ_tool_init "DFPS_Manager" "1.1"
	if {[winfo exists $info(window)]} {return ""}

	# The control variable tells us the current state of the tool. We can stop a
	# DFPS Manager process by setting the control variable to "Stop", after
	# which the state will return to "Idle".
	set info(control) "Idle"

	# A zoom value for the display, and a choice of intensification.
	set config(zoom) 0.5
	set config(intensify) "exact"
		
	# These numbers are used only when we open the DFPS Manager panel for the 
	# first time, and need to allocate space for the fiber image.
	set config(image_sensor) "ICX424"
	set config(analysis_threshold) "10 #"
	
	# We configure the BCAM image sensor and adjust analysis bounds.
	LWDAQ_set_image_sensor $config(image_sensor) BCAM
	
	# The control value for which the control voltages are closest to zero.
	set config(dac_zero) "125"
	
	# Data acquisition addresses.
	set config(ip_addr) "192.168.1.10"
	set config(fvc_left_sock) "4 0"
	set config(fvc_right_sock) "5 0"
	set config(source_type) "9"
	set config(injector_sock) "3 0"
	set config(fiducial_leds) "D2 D4 D6 D10"
	set config(sort_code) "8"
	set config(guide_leds) "A1"
	set config(flash_seconds) "0.0"
	set config(controller_sock) "7 0"
	set config(controller_ids) "A123"
	set config(spots_left) ""
	set config(spots_right) ""
	
	# Fiber view camera geometry.
	set config(cam_default) "12.675 39.312 1.0 0.0 0.0 2 19.0 0.0"
	set config(cam_left) $config(cam_default)
	set config(cam_right) $config(cam_default)
	set config(mount_left) "0 0 0 -21 0 -73 21 0 -73"
	set config(mount_right) "0 0 0 -2 1 0 -73 21 0 -73"
	set config(coord_left) [lwdaq bcam_coord_from_mount $config(mount_left)]
	set config(coord_right) [lwdaq bcam_coord_from_mount $config(mount_right)]

	# Default north, south, east, and west control values.
	set config(n_out) $config(dac_zero) 
	set config(s_out) $config(dac_zero) 
	set config(e_out) $config(dac_zero) 
	set config(w_out) $config(dac_zero) 
	
	# Command transmission values.
	set config(initiate_delay) "0.010"
	set config(spacing_delay) "0.0014"
	set config(byte_processing_time) "0.0002"
	set config(rf_on_op) "0081"
	set config(rf_xmit_op) "82"
	set config(checksum_preload) "1111111111111111"	
	set config(id) "FFFF"
	set config(commands) "8"
	
	# The history of spot positions for the tracing.
	set config(repeat) "0"
	set info(travel_wait) "0"
	
	# Travel configuration.
	set config(travel_index) "0"
	set config(loop_counter) "0"
	set config(pass_counter) "0"
	set config(travel_file) [file normalize ~/Desktop/Travel.txt]
	
	# Panel appearance.
	set config(label_color) "green"
	set info(examine_window) "$info(window).examine_window"
	
	# Waiting time after setting control voltages before we make measurements.
	set config(settling_ms) "1000"
	
	# If we have a settings file, read and implement.	
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 

	# Create images to store FVC images as they come in from the BCAM.
	foreach side {left right} {
		set info(image_$side) dfps_manager_$side
		lwdaq_image_create -name $info(image_$side) -width 700 -height 520
	}

	return ""   
}

#
# DFPS_Manager_examine opens a new window that displays the CMM measurements of
# the left and right mounts, and the calibration constants of the left and right
# cameras. The window allows us to modify the all these values by hand.
#
proc DFPS_Manager_examine {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set w $info(examine_window)
	if {![winfo exists $w]} {
		toplevel $w
		wm title $w "Coordinate Measurements, DFPS Manager $info(version)"
	} {
		raise $w
		return ""
	}

	set f [frame $w.buttons]
	pack $f -side top -fill x
	button $f.save -text "Save Configuration" -command "LWDAQ_tool_save $info(name)"
	pack $f.save -side left -expand 1
	button $f.unsave -text "Unsave Configuration" -command "LWDAQ_tool_unsave $info(name)"
	pack $f.unsave -side left -expand 1
	
	foreach mount {Left Right} {
		set b [string tolower $mount]
		set f [frame $w.mnt$b]
		pack $f -side top -fill x
		label $f.l$b -text "$mount Mount:"
		entry $f.e$b -textvariable DFPS_Manager_config(mount_$b) -width 70
		pack $f.l$b $f.e$b -side left -expand yes
	}

	foreach mount {Left Right} {
		set b [string tolower $mount]
		set f [frame $w.cam$b]
		pack $f -side top -fill x
		label $f.l$b -text "$mount Camera:"
		entry $f.e$b -textvariable DFPS_Manager_config(cam_$b) -width 70
		pack $f.l$b $f.e$b -side left -expand yes
	}

	set info(control) "Idle"
	
	return ""
}

#
# DFPS_Manager_id_bytes returns a list of two bytes as decimal numbers that represent
# the identifier of the implant.
#
proc DFPS_Manager_id_bytes {id_hex} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set id [string trim $id_hex]
	if {[regexp {([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})} $id match b1 b2]} {
		return "[expr 0x$b1] [expr 0x$b2]"
	} elseif {$id == "*"} {
		return "255 255"
	} else {
		LWDAQ_print $info(text) "ERROR: Bad device identifier \"$id\",\
			defaulting to null identifier."
		return "0 0"
	}
}

#
# DFPS_Manager_transmit takes a string of command bytes and transmits them
# through a Command Transmitter such as the A3029A. The routine appends a
# sixteen-bit checksum. The checksum is the two bytes necessary to return a
# sixteen-bit linear feedback shift register to all zeros, thus performing a
# sixteen-bit cyclic redundancy check. We assume the destination shift register
# is preloaded with the checksum_preload value. The shift register has taps at
# locations 16, 14, 13, and 11.
#
proc DFPS_Manager_transmit {{commands ""}} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	global LWDAQ_Driver
	
	# If we specify no commands, use those in the commands parameter.
	if {$commands == ""} {
		set commands [DFPS_Manager_id_bytes $config(id)]
		append commands " "
		append commands $config(commands)
	}

	# Print the commands to the text window.
	LWDAQ_print $info(text) "Transmitting: $commands"

	# Append a two-byte checksum.
	set checksum $config(checksum_preload)
	foreach c "$commands 0 0" {
		binary scan [binary format c $c] B8 bits
		for {set i 0} {$i < 8} {set i [expr $i + 1]} {
			set bit [string index $bits $i]
			set fb [string index $checksum 15]
			set new [string range $checksum 5 14]
			set new "[expr [string index $checksum 4] ^ $fb]$new"
			set new "[string index $checksum 3]$new"
			set new "[expr [string index $checksum 2] ^ $fb]$new"
			set new "[expr [string index $checksum 1] ^ $fb]$new"
			set new "[string index $checksum 0]$new"
			set new "[expr $fb ^ $bit]$new"
			set checksum $new
			binary scan [binary format b16 $checksum] cu1cu1 d21 d22
		}
	}
	append commands " $d22 $d21"
		
	# Open a socket to the command transmitter's LWDAQ server, select the
	# command transmitter, and instruct it to transmit each byte of the
	# command, including the checksum.
	if {[catch {
		set sock [LWDAQ_socket_open $config(ip_addr)]
		set sd $config(spacing_delay)
		LWDAQ_set_driver_mux $sock \
			[lindex $config(dfps_sock) 0] [lindex $config(dfps_sock) 1]
		LWDAQ_transmit_command_hex $sock $config(rf_on_op)
		LWDAQ_delay_seconds $sock $config(initiate_delay)
		foreach c $commands {
			LWDAQ_transmit_command_hex $sock "[format %02X $c]$config(rf_xmit_op)"
			if {$sd > 0} {LWDAQ_delay_seconds $sock $sd}
		}
		LWDAQ_transmit_command_hex $sock "0000"
		LWDAQ_delay_seconds $sock [expr $config(byte_processing_time)*[llength $commands]]
		LWDAQ_wait_for_driver $sock
		LWDAQ_socket_close $sock
	} error_result]} {
		if {[info exists sock]} {LWDAQ_socket_close $sock}
		error $error_result
	}
	
	# If we get here, we have no reason to believe the transmission failed, although
	# we could have instructed an empty driver socket or the positioner could have
	# failed to receive the command.
	return ""
}

#
# DFPS_Manager_transmit_panel opens a new window and provides a button for
# transmitting a string of command bytes to a device. There are two entry boxes.
# One for the device identifier, another for the command bytes. The identifier
# is a four-hex value. The command bytes are each decimal values 0..255
# separated by spaces. The routine parses the identifier into two bytes,
# transmits all the command bytes, and appends the correct checksum on the end.
#
proc DFPS_Manager_transmit_panel {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	
	set w $info(window)\.xmit_panel
	if {[winfo exists $w]} {
		raise $w
		return ""
	}
	toplevel $w
	wm title $w "Fiber_Positioner $info(version) Transmit Command Panel"

	set f [frame $w.tx]
	pack $f -side top -fill x

	button $f.transmit -text "Transmit" -command {
		LWDAQ_post "DFPS_Manager_transmit"
	}
	pack $f.transmit -side left -expand yes
	
	label $f.lid -text "ID:" -fg $config(label_color) -width 4
	entry $f.id -textvariable DFPS_Manager_config(id) -width 6
	label $f.lcommands -text "Commands:" -fg $config(label_color)
	entry $f.commands -textvariable DFPS_Manager_config(commands) -width 50
	pack $f.lid $f.id $f.lcommands $f.commands -side left -expand yes

	return "" 
}

#
# DFPS_Manager_set_nsew takes the north, south, east and west control values and
# instructs the named positioner to set its converters accordingly.
#
proc DFPS_Manager_set_nsew {id} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set command [DFPS_Manager_id_bytes $id]
	append command " 1 $config(n_out) 0 2 $config(s_out) 0\
		3 $config(e_out) 0 4 $config(w_out) 0"
	DFPS_Manager_transmit $command
	return ""
}

#
# DFPS_Manager_spots captures an image of all available fiducial and guide
# fibers in each of the left and right fiber view camers. It fills the two spot
# position lists, spots_left and spots right, giving the spot positions in the
# left and right cameras for each fiber. The returned list takes the form of one
# entry "xl yl xr yr" for each fiducial fiber followed by similar entries for
# the guide fibers. The fiducial fibers are those listed in the fiducial_leds
# list, and the guides are in guide_leds. 
#
proc DFPS_Manager_spots {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	upvar #0 LWDAQ_config_BCAM iconfig
	upvar #0 LWDAQ_info_BCAM iinfo
	
	# Prepare the BCAM Instrument for fiber view camera (FVC) acquisition.
	set info(spots) ""
	set iconfig(daq_ip_addr) $config(ip_addr)
	set iconfig(daq_source_driver_socket) [lindex $config(injector_sock) 0]
	set iconfig(daq_source_mux_socket) [lindex $config(injector_sock) 1]
	set iconfig(daq_source_device_element) \
		[string trim "$config(fiducial_leds) $config(guide_leds)"]
	set iinfo(daq_source_device_type) $config(source_type)
		set iconfig(daq_flash_seconds) $config(flash_seconds)
	set iconfig(analysis_num_spots) \
		"[llength $iconfig(daq_source_device_element)] $config(sort_code)"
	set iconfig(analysis_threshold) $config(analysis_threshold)
	
	# Acquire from both FVCs.
	foreach side {left right} {
		set iconfig(daq_driver_socket) [lindex $config(fvc_$side\_sock) 0]
		set iconfig(daq_mux_socket) [lindex $config(fvc_$side\_sock) 1]
		set result [LWDAQ_acquire BCAM]
		if {[LWDAQ_is_error_result $result]} {
			LWDAQ_print $info(text) "$result"
			return ""
		} else {
			set result_$side [lrange $result 1 end]
			lwdaq_image_manipulate $iconfig(memory_name) \
				copy -name $info(image_$side)
			lwdaq_image_manipulate $info(image_$side) \
				transfer_overlay $iconfig(memory_name)
			lwdaq_draw $info(image_$side) dfps_manager_$side \
				-intensify $config(intensify) -zoom $config(zoom)
		}
	}
	
	# Parse result string.
	foreach side {left right} {
		set config(spots_$side) ""
		foreach fiber "$iconfig(daq_source_device_element)" {
			append config(spots_$side) \
				"[lindex [set result_$side] 0] [lindex [set result_$side] 1] "
			set result_$side [lrange [set result_$side] 6 end]
		}
		set config(spots_$side) [string trim $config(spots_$side)]
	}
	
	return ""
}

#
# DFPS_Manager_sources fills the global sources list, which contains the xyz
# position of all the sources in fiducial and guide lists. Each source entry
# consists of the position the source's image in the left and right FVC, in the
# form "xl yl xr yr" in microns from the center of the top-left corner pixel.
#
proc DFPS_Manager_sources {spots} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set config(coord_left) [lwdaq bcam_coord_from_mount $config(mount_left)]
	set config(coord_right) [lwdaq bcam_coord_from_mount $config(mount_right)]

	set config(sources) ""
	set num_sources [llength [string trim "$config(fiducial_leds) $config(guide_leds)"]]
	for {set i 0} {$i < $num_sources} {incr i} {	
		lwdaq_config -fsd 6
		foreach side {left right} {
			set x [expr 0.001 * [lindex $config(spots_$side) [expr $i*2]]]
			set y [expr 0.001 * [lindex $config(spots_$side) [expr $i*2+1]]]
			set b [lwdaq bcam_source_bearing "$x $y" "$side $config(cam_$side)"]
			set point_$side [lwdaq xyz_global_from_local_point \
				[lrange [set b] 0 2] $config(coord_$side)]
			set dir_$side [lwdaq xyz_global_from_local_vector \
				[lrange [set b] 3 5] $config(coord_$side)]
		}
		lwdaq_config -fsd 3
		
		set bridge [lwdaq xyz_line_line_bridge \
			"$point_left $dir_left" "$point_right $dir_right"]
		scan $bridge %f%f%f%f%f%f x y z dx dy dz
		
		set x_src [format %8.3f [expr $x + 0.5*$dx]]
		set y_src [format %8.3f [expr $y + 0.5*$dy]]
		set z_src [format %8.3f [expr $z + 0.5*$dz]]
		
		set source "$x_src $y_src $z_src"
		LWDAQ_print $info(text) "$i\: $source"
		lappend config(sources) $source
	}

	return ""
}

#
# DFPS_Manager_cmd takes a command, such as Zero, Move, Check, Stop, Step or
# Travel, and decides what to do about it. This routine does not execute the
# DFPS Manager operation itself, but instead posts the execution of the
# operation to the LWDAQ event queue, and then returns. We use this routine from
# buttons, or from other programs that want to manipulate the DFPS Manager
# because the routine does not stop or deley the graphical user interface.
#
proc DFPS_Manager_cmd {cmd} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	if {$info(control) != "Idle"} {
		if {$cmd == "Stop"} {
			set info(control) "Stop"
		} else {
			if {$cmd != $info(control)} {
				LWDAQ_print $info(text) "ERROR: Cannot $cmd during $info(control)."
			}
		}
	} else {
		if {$cmd == "Stop"} {
			# The stop command does not do anything when we are already stopped.
			LWDAQ_print $info(text) "ERROR: Cannot stop while idle."
		} else {
			# Set the control variable.
			set info(control) $cmd
			
			# Here we construct the DFPS Manager procedure name we want to
			# call by converting the command to lower case, and trusting that
			# such a procedure exists. We post its execution to the event queue.
			LWDAQ_post DFPS_Manager_[string tolower $cmd]
		}
	}
	
	return $info(control)
}

#
# DFPS_Manager_report writes a report of the latest measurement to the text
# window. The report is a list of numbers, with some color coding and formatting
# to make it easy to read.
#
proc DFPS_Manager_report {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	LWDAQ_print -nonewline $info(text) "[format %.0f $config(n_out)]\
		[format %.0f $config(s_out)]\
		[format %.0f $config(e_out)]\
		[format %.0f $config(w_out)] " green
	LWDAQ_print $info(text) "$info(spots)" black
	return ""
}

#
# DFPS_Manager_move asserts the latest control values, waits for the
# settling time, measures the electrode voltages, measures the spot position,
# and reports.
#
proc DFPS_Manager_move {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	if {![winfo exists $info(window)]} {
		return ""
	}
	
	if {[catch {
		foreach id $config(dfps_ids) {
			DFPS_Manager_set_nsew $id
		}
		LWDAQ_wait_ms $config(settling_ms)
		DFPS_Manager_spots
		DFPS_Manager_report
	} error_result]} {
		LWDAQ_print $info(text) "ERROR: $error_result"
		set info(control) "Idle"
		return ""
	}
	
	if {$info(control) == "Move"} {
		set info(control) "Idle"
	}
	return ""
}

#
# DFPS_Manager_zero sets all control values to their zero value, waits for the
# settling time, measures voltages, measures spot position, and reports.
#
proc DFPS_Manager_zero {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	upvar #0 LWDAQ_config_BCAM iconfig
	upvar #0 LWDAQ_info_BCAM iinfo
	
	foreach d {n_out s_out e_out w_out} {
		set config($d) $config(dac_zero)
	}
	
	if {[catch {
		foreach id $config(dfps_ids) {
			DFPS_Manager_set_nsew $id
		}
		LWDAQ_wait_ms $config(settling_ms)	
		DFPS_Manager_spots
		DFPS_Manager_report
	} error_result]} {
		LWDAQ_print $info(text) "ERROR: $error_result"
		set info(control) "Idle"
		return ""
	}

	if {$info(control) == "Zero"} {
		set info(control) "Idle"
	}
	return ""
}

#
# DFPS_Manager_check does nothing to the voltages, just measures them,
# measures spot position, and reports. It does not wait for the settling time.
#
proc DFPS_Manager_check {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	
	
	if {[catch {
		DFPS_Manager_spots
		DFPS_Manager_sources $info(spots)
		DFPS_Manager_report
	} error_result]} {
		LWDAQ_print $info(text) "ERROR: $error_result"
		set info(control) "Idle"
		return ""
	}
	
	if {$info(control) == "Check"} {
		set info(control) "Idle"
	}
	return ""
}

#
# DFPS_Manager_clear clears the display traces.
#
proc DFPS_Manager_clear {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	upvar #0 LWDAQ_config_BCAM iconfig

	set index 0
	if {[lwdaq_image_exists $iconfig(memory_name)] != ""} {
		foreach side {left right} {
			lwdaq_image_manipulate $info(image_$side) none -clear 1
			lwdaq_draw $info(image_$side) dfps_manager_$side \
				-zoom $config(zoom) \
				-intensify $config(intensify)
		}
	}
	
	if {$info(control) == "Clear"} {
		set info(control) "Idle"
	}
	
	return ""
}

#
# DFPS_Manager_reset sets the travel index, pass counter, and loop 
# counters all to zero. It clears the traces.
#
proc DFPS_Manager_reset {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set config(travel_index) 0
	set config(pass_counter) 0
	set config(loop_counter) 0
	DFPS_Manager_clear
	if {$info(control) == "Reset"} {
		set info(control) "Idle"
	}
	
	return ""
}

#
# DFPS_Manager_step just calls the travel routine. We assume the control 
# variable has been set to "Step", so the travel routine will know to stop
# after one step.
#
proc DFPS_Manager_step {} {
	DFPS_Manager_travel 
	return ""
}

#
# DFPS_Manager_goto is designed for use in travel scripts that are executed
# within the DFPS_Manager_travel routine. The routine arranges for the
# travel index to be equal to the index of a labelled line number at the end of
# a travel step. To accomplish this result, the routine refers to the
# travel_list available in DFPS_Manager_travel, finds the index of the
# labelled line in the list, and sets the global travel index equal to the
# labelled line's index minus one. The travel routine will subsequently
# increment the index, thus leaving it equal to the labelled line's index at the
# end fo the step. If the label does not exist in the travel file, we generate
# an error.  
#
proc DFPS_Manager_goto {name} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
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
# DFPS_Manager_travel allows us to step through a list of control values of 
# arbitrary length. A travel file consists of north, south, east, west control values
# separated by spaces, each set of values on a separate line. We can include comments
# in the travel file with hash characters.
#
proc DFPS_Manager_travel {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	global LWDAQ_Info
	
	# Because the travel operation can go on for some time, we must handle the 
	# closing of the window gracefully: we abort if the window is no longer open.
	if {![winfo exists $info(window)]} {
		return ""
	}

	# Read the travel file, if we can find it. If not, abort and report an error.
	if {[catch {
		set f [open $config(travel_file) r]
		set travel_list [string trim [read $f]]
		close $f
	} error_result]} {
		catch {close $f}
		LWDAQ_print $info(text) "ERROR: $error_result."
		set info(control) "Idle"		
		return ""
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
	
	# If this is the first step, clear excess lines from the text window and
	# increment the travel counter.
	if {$config(travel_index) == 0} {
		incr config(pass_counter)
		LWDAQ_print $info(text) "\nStarting [file tail $config(travel_file)],\
			Pass $config(pass_counter)." purple
		$info(text) delete 1.0 "end [expr 0 - $LWDAQ_Info(num_lines_keep)] lines"
		
	}
		
	# Get the travel_index'th line and extract the first word, which may be a command.
	set line [string trim [lindex $travel_list $config(travel_index)]]
	set first_word [lindex $line 0]

	# Print out the line in the text window with its line number, but don't keep
	# re-printing a wait command line.
	if {($first_word != "wait") || ($info(travel_wait) == 0)} {
		LWDAQ_print $info(text) "[format %-3d $config(travel_index)] $line"
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
		# name. The DFPS_Manager_goto command takes a a label name as its
		# argument, searches the travel file for "label name" and returns the
		# index of the labeled line. This allows tcl code to jump to the
		# labelled line, so we can build conditional branches or incrementing
		# loops into our travel scripts.
			set label [regsub {label[ \t]*} $line ""]
			if {![string is wordchar $label]} {
				LWDAQ_print $info(text) "ERROR: Bad label name \"$label\"."
				set info(control) "Idle"
				return ""
			}
		}
		
		"tcl" {
		# The tcl instruction specifies that the rest of the line should be
		# executed as a TCL command. We delete the tcl key word in the line
		# and pass to TCL interpreter with the "eval" command.
			if {[catch {
				eval [regsub {tcl[ \t]*} $line ""]
			} error_result]} {
				LWDAQ_print $info(text) "ERROR: $error_result"
				set info(control) "Idle"
				return ""
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
				LWDAQ_print $info(text) "ERROR: No such file \"$sfn\"."
				set info(control) "Idle"
				return ""				
			}
			if {[catch {
				source $sfn
			} error_result]} {
				LWDAQ_print $info(text) "ERROR: $error_result"
				set info(control) "Idle"
				return ""
			}
		}
		
		"wait" {
		# The wait instruction holds the travel operation at the same step until
		# a specified number of seconds has elapsed. The operation continues to
		# post itself to the event loop, so will respond to Stop commands.
			set wait_seconds [lindex $line 1]
			if {![string is integer -strict $wait_seconds]} {
				LWDAQ_print $info(text) "ERROR: Invalid wait time \"$wait_seconds\"."
				set info(control) "Idle"
				return ""
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
					LWDAQ_print $info(text) "ERROR: Invalid control value \"$line\"."
					set info(control) "Idle"
					return ""
				}
			}

			# Extract the four integers from the line.	
			scan $line %d%d%d%d config(n_out) config(s_out) config(e_out) config(w_out)
	
			# Apply the new control values to all four electrodes.
			if {[catch {
				foreach id $config(dfps_ids) {DFPS_Manager_set_nsew $id}
			} error_result]} {
				LWDAQ_print $info(text) "ERROR: $error_result"
				set info(control) "Idle"
				return ""
			}
	
			# Wait for the fiber to settle, then measure voltages, spot position, and
			# report to text window.
			LWDAQ_wait_ms $config(settling_ms)	
			DFPS_Manager_spots
			DFPS_Manager_report
		}
	}
	
	# Decide what to do next: continue through list, start at beginning again or
	# finish.
	incr config(travel_index)
	if {($info(control) == "Stop") || ($info(control) == "Step")} {
		set info(control) "Idle"
		return ""
	} elseif {($config(travel_index) < [llength $travel_list])} {
		LWDAQ_post "DFPS_Manager_travel"
		return ""
	} else {
		LWDAQ_print $info(text) "Travel Complete, Pass $config(pass_counter)." purple
		if {$config(repeat)} {
			LWDAQ_post "DFPS_Manager_travel"
			return ""
		} else {
			set info(control) "Idle"
			return ""
		}
	}
}

#
# DFPS_Manager_travel_edit creats a travel list file if one does not exist
# under the current file name, or reads an existing file. Displays the file for
# editing, provides buttons to save under same or different names.
#
proc DFPS_Manager_travel_edit {} {
	upvar #0 DFPS_Manager_info info
	upvar #0 DFPS_Manager_config config
	
	if {![file exists $config(travel_file)]} {
		LWDAQ_edit_script New 
	} else {
		LWDAQ_edit_script Open $config(travel_file)
	}
	return ""
}

#
# DFPS_Manager_travel_browse allows us to choose a travel list file.
#
proc DFPS_Manager_travel_browse {} {
	upvar #0 DFPS_Manager_info info
	upvar #0 DFPS_Manager_config config

	set dn [file dirname $config(travel_file)]
	if {![file exists $dn]} {set dn ""}
	set fn [LWDAQ_get_file_name 0 $dn] 
	if {$fn != ""} {set config(travel_file) $fn}
	return $config(travel_file)
}

#
# DFPS_Manager_open creates the DFPS Manager window.
#
proc DFPS_Manager_open {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
	
	set ff [frame $w.parameters]
	pack $ff -side top -fill x
	
	set f [frame $ff.controls]
	pack $f -side top -fill x
	
	label $f.state -textvariable DFPS_Manager_info(control) -width 20 -fg blue
	pack $f.state -side left -expand 1
	foreach a {Travel Step Stop Clear Reset Examine} {
		set b [string tolower $a]
		button $f.$b -text $a -command "DFPS_Manager_cmd $a"
		pack $f.$b -side left -expand 1
	}
	foreach a {Help Configure} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_tool_$b $info(name)"
		pack $f.$b -side left -expand 1
	}
	
	set f [frame $ff.fiber]
	pack $f -side top -fill x

	foreach a {ip_addr fvc_left_sock fvc_right_sock injector_sock  \
			controller_sock flash_seconds} {
		label $f.l$a -text $a -fg $config(label_color)
		entry $f.e$a -textvariable DFPS_Manager_config($a) \
			-width [expr [string length $config($a)] + 2]
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	set f [frame $ff.leds]
	pack $f -side top -fill x

	foreach a {fiducial_leds} {
		label $f.l$a -text $a -fg $config(label_color)
		entry $f.e$a -textvariable DFPS_Manager_config($a) -width 30
		pack $f.l$a $f.e$a -side left -expand yes
	}

	foreach a {guide_leds} {
		label $f.l$a -text $a -fg $config(label_color)
		entry $f.e$a -textvariable DFPS_Manager_config($a) -width 30
		pack $f.l$a $f.e$a -side left -expand yes
	}

	foreach a {controller_ids} {
		label $f.l$a -text $a -fg $config(label_color)
		entry $f.e$a -textvariable DFPS_Manager_config($a) -width 30
		pack $f.l$a $f.e$a -side left -expand yes
	}

	set f [frame $ff.dacs]
	pack $f -side top -fill x
	
	foreach d {n_out s_out e_out w_out} {
		set a [string tolower $d]
		label $f.l$a -text $d -fg $config(label_color)
		entry $f.e$a -textvariable DFPS_Manager_config($a) -width 5
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	foreach a {Move Zero Check} {
		set b [string tolower $a]
		button $f.$b -text $a -command "DFPS_Manager_cmd $a"
		pack $f.$b -side left -expand 1
	}
	button $f.txcmd -text "Transmit Panel" -command {
		LWDAQ_post "DFPS_Manager_transmit_panel"
	}
	pack $f.txcmd -side left -expand yes

	set f [frame $ff.travel]
	pack $f -side top -fill x

	label $f.tl -text "travel_file" -fg $config(label_color)
	entry $f.tlf -textvariable DFPS_Manager_config(travel_file) -width 40
	pack $f.tl $f.tlf -side left -expand yes
	button $f.browse -text "Browse" -command DFPS_Manager_travel_browse
	button $f.edit -text "Edit" -command DFPS_Manager_travel_edit
	pack $f.browse $f.edit -side left -expand yes
	checkbutton $f.repeat -text "Repeat" -variable DFPS_Manager_config(repeat) 
	pack $f.repeat -side left -expand yes
	checkbutton $f.trace -text "Trace" -variable DFPS_Manager_config(trace_enable)
	pack $f.trace -side left -expand yes
	label $f.til -text "index:" -fg $config(label_color)
	entry $f.tie -textvariable DFPS_Manager_config(travel_index) -width 4
	pack $f.til $f.tie -side left -expand yes
	label $f.tpl -text "pass:" -fg $config(label_color)
	entry $f.tpe -textvariable DFPS_Manager_config(pass_counter) -width 4
	pack $f.tpl $f.tpe -side left -expand yes
	label $f.tll -text "loop:" -fg $config(label_color)
	entry $f.tle -textvariable DFPS_Manager_config(loop_counter) -width 4
	pack $f.tll $f.tle -side left -expand yes
	
	set f [frame $w.image_frame]
	pack $f -side top -fill x -expand no
	
	foreach a {left right} {
		image create photo "dfps_manager_$a"
		label $f.$a -image "dfps_manager_$a"
		pack $f.$a -side left -expand yes
	}
	
	set f [frame $w.text_frame]
	pack $f -side top -fill both -expand yes
	
	set info(text) [LWDAQ_text_widget $f 80 20 1 1]
	LWDAQ_print $info(text) "DFPS Manager Text Output" purple

	return $w
}

DFPS_Manager_init
DFPS_Manager_open
	
return ""

----------Begin Help----------

http://www.opensourceinstruments.com/DFPS/Development.html

----------End Help----------

----------Begin Data----------

----------End Data----------