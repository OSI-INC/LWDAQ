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
	
	LWDAQ_tool_init "DFPS_Manager" "1.4"
	if {[winfo exists $info(window)]} {return ""}

	# The control variable tells us the current state of the tool.
	set info(control) "Idle"

	# Data acquisition parameters.
	set config(ip_addr) "192.168.1.30"
	set config(fvc_left) "5 0"
	set config(fvc_right) "4 0"
	set config(injector) "8 0"
	set config(fiducials) "A5 A6 A7 A8"
	set config(sort_code) "8"
	set config(guides) "D1"
	set config(flash) "0.0005"
	set config(transceiver) "1 0"
	set config(controllers) "FFFF"
	set config(source_type) "9"
	set config(camera_element) "2"
	set config(source_power) "3"
	set info(wildcard_id) "FFFF"
	set config(settling_ms) "1000"
	set config(dac_zero) "32000"
	set config(image_sensor) "ICX424"
	LWDAQ_set_image_sensor $config(image_sensor) BCAM
	set config(analysis_threshold) "10 #"

	# Data acquisition and analysis results.
	set config(spots) ""
	set config(sources) ""
	set config(verbose) "0"
		
	# Fiber view camera geometry.
	set config(cam_left) \
		"12.675 39.312 1.000 -7.416 0.947 2.000 18.986 5.569"
# DFPS-4A: Y71010 12.675 39.312 1.000 -7.416 0.947 2.000 18.986 5.569
# Breadboard: Y71066 12.675 39.312 1.000 -14.793 -2.790 2.000 18.778 2.266
	set config(cam_right) \
		"12.675 39.312 1.000 3.017 -1.421 2.000 19.123 6.488"
# DFPS-4A: Y71003 12.675 39.312 1.000 3.017 -1.421 2.000 19.123 6.488
# Breadboard: Y71080 12.675 39.312 1.000 -7.059 3.068 2.000 19.016 1.316
	set config(mount_left) \
		"80.259 50.931 199.724 120.012 50.514 264.564 79.473 50.593 275.868"
# DFPS-4A: 80.259 50.931 199.724 120.012 50.514 264.564 79.473 50.593 275.868
# Breadboard: 79.614 51.505 199.754 119.777 51.355 264.265 79.277 51.400 275.713
	set config(mount_right) \
		"-104.780 51.156 198.354 -107.973 50.745 274.238 -147.781 50.858 260.948"
# DFPS-4A: -104.780 51.156 198.354 -107.973 50.745 274.238 -147.781 50.858 260.948
# Breadboard: -104.039 51.210 199.297 -108.680 51.004 275.110 -148.231 50.989 261.059
	set config(coord_left) [lwdaq bcam_coord_from_mount $config(mount_left)]
	set config(coord_right) [lwdaq bcam_coord_from_mount $config(mount_right)]

	# Default north, south, east, and west control values.
	set config(n_all) $config(dac_zero) 
	set config(s_all) $config(dac_zero) 
	set config(e_all) $config(dac_zero) 
	set config(w_all) $config(dac_zero) 
	
	# Command transmission values.
	set config(initiate_delay) "0.010"
	set config(spacing_delay) "0.0014"
	set config(byte_processing_time) "0.0002"
	set config(rf_on_op) "0081"
	set config(rf_xmit_op) "82"
	set config(checksum_preload) "1111111111111111"	
	set config(id) "FFFF"
	set config(commands) "8"
	
	# Travel configuration.
	set config(repeat) "0"
	set info(travel_wait) "0"
	set config(travel_index) "0"
	set config(pass_counter) "0"
	set config(travel_file) [file normalize ~/Desktop/Travel.txt]
	
	# Panel appearance.
	set config(label_color) "green"
	set info(examine_window) "$info(window).examine_window"
	set config(zoom) 1.0
	set config(intensify) "exact"
	
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
# DFPS_Manager_configure opens the configuration panel and adds entries for us
# to examine the mount measurements and camera calibration constants in more
# detail. Most of the work of the routine is done by the LWDAQ tool configure
# routine, which destroys any existing configuration panel before creating most
# of the entry boxes and returning the name of a frame in which we create larger
# boxes for the mount and camera parameters. The routine returns the contents
# of the configuration array as a list of "name" and "value".
#
proc DFPS_Manager_configure {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set ff [LWDAQ_tool_configure DFPS_Manager]

	foreach mount {Left Right} {
		set b [string tolower $mount]
		set f [frame $ff.mnt$b]
		pack $f -side top -fill x
		label $f.l$b -text "$mount Mount:"
		entry $f.e$b -textvariable DFPS_Manager_config(mount_$b) -width 70
		pack $f.l$b $f.e$b -side left -expand yes
	}

	foreach mount {Left Right} {
		set b [string tolower $mount]
		set f [frame $ff.cam$b]
		pack $f -side top -fill x
		label $f.l$b -text "$mount Camera:"
		entry $f.e$b -textvariable DFPS_Manager_config(cam_$b) -width 70
		pack $f.l$b $f.e$b -side left -expand yes
	}

	return [array get config]
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
		set commands "[DFPS_Manager_id_bytes $config(id)] $config(commands)"
	}

	# Print the commands to the text window.
	if {$config(verbose)} {LWDAQ_print $info(text) "Transmitting: $commands" orange}

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
			[lindex $config(transceiver) 0] [lindex $config(transceiver) 1]
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
# DFPS_Manager_set takes the north, south, east and west control values and
# instructs the named positioner to set its converters accordingly. The control
# values must be unsigned integers between 0 and 65535.
#
proc DFPS_Manager_set {id n s e w} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set command [DFPS_Manager_id_bytes $id]
	append command " 1 [expr $n / 256] [expr $n % 256]\
		2 [expr $s / 256] [expr $s % 256]\
		3 [expr $e / 256] [expr $e % 256]\
		4 [expr $w / 256] [expr $w % 256]"
	DFPS_Manager_transmit $command
	return ""
}
		
#
# DFPS_Manager_spots captures an image of the sources whose elements are listed
# in the elements argument. If we pass an empty string for the elements, the
# routine combines the fiducial and guide elements to obtain a list of all
# available sources. It returns the coordinates of the two images of each source
# in the left and right cameras in the format "x1l y1l x1r y1r... xnl ynl xnr
# ynr", where "n" is the number of sources it flashes.
#
proc DFPS_Manager_spots {{elements ""}} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	upvar #0 LWDAQ_config_BCAM iconfig
	upvar #0 LWDAQ_info_BCAM iinfo
	
	# Default elements.
	if {$elements == ""} {
		set elements [string trim "$config(fiducials) $config(guides)"]
	}
	
	# Prepare the BCAM Instrument for fiber view camera (FVC) acquisition.
	set iconfig(daq_ip_addr) $config(ip_addr)
	set iconfig(daq_source_driver_socket) [lindex $config(injector) 0]
	set iconfig(daq_source_mux_socket) [lindex $config(injector) 1]
	set iconfig(daq_source_device_element) $elements 
	set iinfo(daq_source_device_type) $config(source_type)
	set iinfo(daq_source_power) $config(source_power)
	set iconfig(daq_device_element) $config(camera_element)
		set iconfig(daq_flash_seconds) $config(flash)
	set iconfig(analysis_num_spots) \
		"[llength $iconfig(daq_source_device_element)] $config(sort_code)"
	set iconfig(analysis_threshold) $config(analysis_threshold)
	
	# Acquire from both FVCs.
	foreach side {left right} {
		set iconfig(daq_driver_socket) [lindex $config(fvc_$side) 0]
		set iconfig(daq_mux_socket) [lindex $config(fvc_$side) 1]
		set result [LWDAQ_acquire BCAM]
		if {[LWDAQ_is_error_result $result]} {
			LWDAQ_print $info(text) "$result"
			return ""
		} else {
			if {$config(verbose)} {LWDAQ_print $info(text) "Left: $result" brown}
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
	set spots ""
	foreach fiber "$iconfig(daq_source_device_element)" {
		foreach side {left right} {
			append spots "[lindex [set result_$side] 0] [lindex [set result_$side] 1] "
			set result_$side [lrange [set result_$side] 6 end]
		}
	}
	
	# Return the results string and store in configuration array.
	set config(spots) [string trim $spots]
	if {$config(verbose)} {LWDAQ_print $info(text) "Spots: $spots" brown}
	return $config(spots)
}

#
# DFPS_Manager_sources calculates source positions from a set of left and right
# camera image positions. We think of each image as a "spot" with a centroid
# position measured in microns from the center of the image sensor's top-left
# pixel. We pass it a list containing the coordinates of the spots in the forma
# "x1l y1l x1r y1r... xnl ynl xnr ynr" where "n" is the number of sources, "l"
# specifies the left camera, and "r" specifies the right camera. The routine
# returns a list of source positions in global coordinates "x1 y1 z1 ... xn yn
# zn". The routine checks to see if the spot positions are invalid, which is
# marked by coordinates "-1 -1 -1 -1", and if so, it returns for the source 
# position the global coordinate origin.
#
proc DFPS_Manager_sources {spots} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	# Refresh the left and right camera mount coordinate systems in case we have
	# changed the left and right mounting ball coordinates since our previous
	# use of the mount coordinates.
	set config(coord_left) [lwdaq bcam_coord_from_mount $config(mount_left)]
	set config(coord_right) [lwdaq bcam_coord_from_mount $config(mount_right)]

	# For each source, we extract the left and right camera spot coordinates and
	# use these to measure the source position.
	set sources ""
	foreach {x_left y_left x_right y_right} $spots {
	
		# If our spot positions are "-1", set the source position to the global origin.
		if {$x_left == "-1"} {
			append sources "0 0 0 0 "
			continue
		}
		
		# We need six decimal places of resolution in our bearing directions in
		# order to obtain one-micron precision in source position.
		lwdaq_config -fsd 6
		
		# For each camera, we transform the image position in to mount
		# coordinates, then project the image position through the pivot point
		# of the camera to obtain a bearing line. We transform the bearing line
		# into global coordinates.
		foreach side {left right} {
			set x [expr 0.001 * [set x_$side]]
			set y [expr 0.001 * [set y_$side]]
			set b [lwdaq bcam_source_bearing "$x $y" "$side $config(cam_$side)"]
			set point_$side [lwdaq xyz_global_from_local_point \
				[lrange [set b] 0 2] $config(coord_$side)]
			set dir_$side [lwdaq xyz_global_from_local_vector \
				[lrange [set b] 3 5] $config(coord_$side)]
		}
		
		# Go back to three decimal places so our position string will be compact.
		lwdaq_config -fsd 3
		
		# Find the point and direction that define the shortest vector between the
		# two bearings in global coordinates.
		set bridge [lwdaq xyz_line_line_bridge \
			"$point_left $dir_left" "$point_right $dir_right"]
		scan $bridge %f%f%f%f%f%f x y z dx dy dz
		
		# Use the midpoint of this vector as our position measurement, append to
		# our source list.
		set x_src [format %.3f [expr $x + 0.5*$dx]]
		set y_src [format %.3f [expr $y + 0.5*$dy]]
		set z_src [format %.3f [expr $z + 0.5*$dz]]
		append sources "$x_src $y_src $z_src "
	}

	# Store source positions in configuration array and return them too.
	set config(sources) [string trim $sources]	
	if {$config(verbose)} {LWDAQ_print $info(text) "Sources: $sources" brown}
	return $config(sources)
}

#
# DFPS_Manager_check measures spot position, and reports. We can pass it a list
# of source elements to flash and measure, or else the routine will generate its
# own list by combining the fiducial and guide LED elements.
#
proc DFPS_Manager_check {{elements ""}} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	
	if {[catch {
		if {$elements == ""} {
			set elements [string trim "$config(fiducials) $config(guides)"]
		}
		set spots [DFPS_Manager_spots $elements]
		set sources [DFPS_Manager_sources $spots]
		LWDAQ_print $info(text) "[clock seconds] $sources"
	} error_result]} {
		LWDAQ_print $info(text) "ERROR: $error_result"
		set info(control) "Idle"
		return ""
	}
	
	if {$info(control) == "Check"} {
		set info(control) "Idle"
	}
	
	return $sources
}

#
# DFPS_Manager_move_all sets the control values of all actuators to the values
# specified in the n_all, s_all, e_all, and w_all parameters, waits for the
# settling time, and checks positions. It returns the positions of all sources.
#
proc DFPS_Manager_move_all {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	if {![winfo exists $info(window)]} {
		return ""
	}
	
	if {[catch {
		foreach id $config(controllers) {
			DFPS_Manager_set $id \
				$config(n_all) $config(s_all) \
				$config(e_all) $config(w_all)
		}
		LWDAQ_wait_ms $config(settling_ms)	
		set sources [DFPS_Manager_check]
	} error_result]} {
		LWDAQ_print $info(text) "ERROR: $error_result"
		set info(control) "Idle"
		return ""
	}
	
	if {$info(control) == "Move_All"} {
		set info(control) "Idle"
	}
	
	return $sources
}

#
# DFPS_Manager_zero_all sets the control values of all actuators to the value
# specified in dac_zero, waits for the settling time, and checks positions. It
# returns the positions of all sources.
#
proc DFPS_Manager_zero_all {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	
	if {[catch {
		foreach id $config(controllers) {
			DFPS_Manager_set $id \
				$config(dac_zero) $config(dac_zero) \
				$config(dac_zero) $config(dac_zero) 
		}
		LWDAQ_wait_ms $config(settling_ms)	
		set sources [DFPS_Manager_check]
	} error_result]} {
		LWDAQ_print $info(text) "ERROR: $error_result"
		set info(control) "Idle"
		return ""
	}

	if {$info(control) == "Zero_All"} {
		set info(control) "Idle"
	}
	
	return $sources
}

#
# DFPS_Manager_stop stops the travel and sets the control state to Idle.
#
proc DFPS_Manager_stop {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set config(travel_index) 0
	set config(pass_counter) 0
	set info(control) "Idle"
	return ""
}

#
# DFPS_Manager_clear clears the display overlays.
#
proc DFPS_Manager_clear {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	foreach side {left right} {
		lwdaq_image_manipulate $info(image_$side) none -clear 1
		lwdaq_draw $info(image_$side) dfps_manager_$side \
			-zoom $config(zoom) \
			-intensify $config(intensify)
	}
	return ""
}

#
# DFPS_Manager_jump arranges for travel script execution to move to a labeled
# line in the script. The routine finds the labelled line in the script and sets
# the travel index equal to the labelled line's index minus one. The travel
# routine will subsequently increment the index, thus leaving it equal to the
# labeled line's index at the end fo the step. If the label does not exist in
# the travel file, we generate an error. We can call this goto routine with a
# "goto" instruction in a travel script, and also with the full name of the
# routine from within a Tcl script being executed by the travel process. In both
# cases, the goto routine refers to the travel list available in the travel
# procedure.
#
proc DFPS_Manager_jump {name} {
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
# DFPS_Manager_travel allows us to step through a list travel commands. The
# default travel command consists of a text line with a four integers 0-65535
# that will be used to set the control voltages of all controllers listed in the
# controllers parameter. Other valid travel commands are "label" to name a line
# and "jump" to jump to a labeled line. We have "tcl" to execute the rest of the
# command line as a Tcl command, "tcl_source" to load and execute a named Tcl
# script file, and "wait" to wait a number of seconds.
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
	
	# If the state is Idle, we exit.
	if {$info(control) == "Idle"} {
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
		if {$config(verbose)} {
			LWDAQ_print $info(text) "\nStarting\
			[file tail $config(travel_file)],\
			Pass $config(pass_counter)." purple
		}
		$info(text) delete 1.0 "end [expr 0 - $LWDAQ_Info(num_lines_keep)] lines"
		
	}
		
	# Get the travel_index'th line and extract the first word, which may be a command.
	set line [string trim [lindex $travel_list $config(travel_index)]]
	set first_word [lindex $line 0]

	# Print out the line in the text window with its line number, but don't keep
	# re-printing a wait command line.
	if {($first_word != "wait") || ($info(travel_wait) == 0)} {
		if {$config(verbose)} {
			LWDAQ_print $info(text) "[format %-3d $config(travel_index)] $line" purple
		}
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
		# A label instruction specifies a line that we can jump to with a "goto"
		# command.
			set label [regsub {label[ \t]*} $line ""]
			if {![string is wordchar $label]} {
				LWDAQ_print $info(text) "ERROR: Bad label name \"$label\"."
				set info(control) "Idle"
				return ""
			}
		}
		
		"jump" {
		# Jump to the named line.
			set label [regsub {goto[ \t]*} $line ""]
			if {![string is wordchar $label]} {
				LWDAQ_print $info(text) "ERROR: Bad label name \"$label\"."
				set info(control) "Idle"
				return ""
			}
			DFPS_Manager_jump $label
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
			if {$info(travel_wait) == 0} {
				set info(travel_wait) [clock milliseconds]
				incr config(travel_index) -1
			} else {
				if {[clock milliseconds] - $info(travel_wait) \
						>= [expr 1000*$wait_seconds]} {
					set info(travel_wait) 0
				} else {
					incr config(travel_index) -1
				}
			}
		}
		
		default {
		# At this point, the only valid option for the line is that it contains a
		# controller id and four control values.

			# Extract the id and four integers from the line.	
			scan $line %d%d%d%d n s e w
	
			# Apply the new control values to all four electrodes.
			if {[catch {
				foreach id $config(controllers) {
					DFPS_Manager_set $id $n $s $e $w
				}
			} error_result]} {
				LWDAQ_print $info(text) "ERROR: $error_result"
				set info(control) "Idle"
				return ""
			}
	
			# Wait for the fiber to settle, then check the spot positions.
			LWDAQ_wait_ms $config(settling_ms)	
			DFPS_Manager_check
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
		if {$config(verbose)} {
			LWDAQ_print $info(text) "Travel Complete, Pass $config(pass_counter)." purple
		}
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
# DFPS_Manager_step calls the travel routine. We assume the control variable has
# been set to "Step", so the travel routine will know to stop after one step.
#
proc DFPS_Manager_step {} {
	DFPS_Manager_travel 
	return ""
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
		if {$cmd != "Stop"} {
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
	foreach a {Check Travel Step} {
		set b [string tolower $a]
		button $f.$b -text $a -command "DFPS_Manager_cmd $a"
		pack $f.$b -side left -expand 1
	}
	foreach a {Stop Clear Configure} {
		set b [string tolower $a]
		button $f.$b -text $a -command "DFPS_Manager_$b"
		pack $f.$b -side left -expand 1
	}
	foreach a {Help} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_tool_$b $info(name)"
		pack $f.$b -side left -expand 1
	}
	button $f.server -text "Server" -command "LWDAQ_server_open"
	pack $f.server -side left -expand 1
	button $f.bcam -text "BCAM" -command "LWDAQ_open BCAM"
	pack $f.bcam -side left -expand 1
	button $f.calibrator -text "Calibrator" -command "LWDAQ_run_tool DFPS_Calibrator"
	pack $f.calibrator -side left -expand 1
	
	set f [frame $ff.fiber]
	pack $f -side top -fill x

	foreach a {ip_addr fvc_left fvc_right injector transceiver flash} {
		label $f.l$a -text $a -fg $config(label_color)
		entry $f.e$a -textvariable DFPS_Manager_config($a) \
			-width [expr [string length $config($a)] + 1]
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	set f [frame $ff.leds]
	pack $f -side top -fill x

	foreach a {fiducials guides controllers} {
		label $f.l$a -text $a -fg $config(label_color)
		entry $f.e$a -textvariable DFPS_Manager_config($a) -width 20
		pack $f.l$a $f.e$a -side left -expand yes
	}

	set f [frame $ff.dacs]
	pack $f -side top -fill x
	
	foreach d {n_all s_all e_all w_all} {
		set a [string tolower $d]
		label $f.l$a -text $d -fg $config(label_color)
		entry $f.e$a -textvariable DFPS_Manager_config($a) -width 5
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	foreach a {Move_All Zero_All} {
		set b [string tolower $a]
		button $f.$b -text $a -command "DFPS_Manager_cmd $a"
		pack $f.$b -side left -expand 1
	}
	button $f.txcmd -text "Transmit Panel" -command {
		LWDAQ_post "DFPS_Manager_transmit_panel"
	}
	pack $f.txcmd -side left -expand yes
	checkbutton $f.verbose -text "Verbose" -variable DFPS_Manager_config(verbose)
	pack $f.verbose -side left -expand yes

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
	label $f.til -text "index:" -fg $config(label_color)
	entry $f.tie -textvariable DFPS_Manager_config(travel_index) -width 4
	pack $f.til $f.tie -side left -expand yes
	label $f.tpl -text "pass:" -fg $config(label_color)
	entry $f.tpe -textvariable DFPS_Manager_config(pass_counter) -width 4
	pack $f.tpl $f.tpe -side left -expand yes
	
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
	LWDAQ_print $info(text) "DFPS Manager Text Output\n" purple

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