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
# DFPS_Manager_init creates and initializes the DFPS Manager Tool's
# configuration (config) and information (info) arrays. It reads saved
# configuration (but not information) parameters from disk if we have previously
# saved our configuration to disk. All the configuration parameters are visible
# in the tool's configuration array, where there are save and unsave buttons to
# create and delete a default configuration file.
#
proc DFPS_Manager_init {} {
	upvar #0 DFPS_Manager_info info
	upvar #0 DFPS_Manager_config config
	upvar #0 LWDAQ_info_BCAM iinfo
	upvar #0 LWDAQ_config_BCAM iconfig
	global LWDAQ_Info LWDAQ_Driver
	
	LWDAQ_tool_init "DFPS_Manager" "2.2"
	if {[winfo exists $info(window)]} {return ""}

	# The control variable tells us the current state of the tool.
	set info(control) "Idle"

	# Data acquisition parameters for the DFPS-4A.
	set config(ip_addr) "192.168.1.30"
	# Breadboard OSI Local: 192.168.1.10
	# DFPS-4A OSI Local: 192.168.1.30
	# DFPS-4A OSI Global: 71.174.73.186
	# DFPS-4A McDonald Local: 198.214.229
	set config(fvc_left) "5 0"
	set config(fvc_right) "4 0"
	set config(injector) "8 0"
	set config(fiducials) "A5 A6 A7 A8"
	set config(sort_code) "8"
	set config(guides) "D1 D2"
	set config(flash) "0.004"
	set config(transceiver) "1 0"
	set config(controllers) "FFFF"
	set config(source_type) "9"
	set config(camera_element) "2"
	set config(source_power) "2"
	set info(wildcard_id) "FFFF"
	set config(settling_ms) "1000"
	set config(dac_zero) "32000"
	set info(image_sensor) "ICX424"
	LWDAQ_set_image_sensor $info(image_sensor) BCAM
	set config(analysis_threshold) "10 #"
	set config(guide_1) "7 0 2"
	set config(guide_2) "6 0 1"
	set config(guide_3) "7 0 1"
	set config(guide_4) "6 0 2"
	set info(guide_sensors) "1 2 3 4"
	
	# Data acquisition and analysis results.
	set config(spots) ""
	set config(sources) ""
	set config(verbose) "0"
		
	# Fiber view camera geometry.
	set config(cam_left) \
		"12.675 39.312 1.000 -7.272 0.897 2.000 19.028 5.113"
	# DFPS-4A: Y71010 12.675 39.312 1.000 -7.272 0.897 2.000 19.028 5.113
	# Breadboard: Y71066 12.675 39.312 1.000 -14.793 -2.790 2.000 18.778 2.266
	set config(cam_right) \
		"12.675 39.312 1.000 2.718 -1.628 2.000 19.165 8.220"
	# DFPS-4A: Y71003 12.675 39.312 1.000 2.718 -1.628 2.000 19.165 8.220
	# Breadboard: Y71080 12.675 39.312 1.000 -7.059 3.068 2.000 19.016 1.316
	set config(mount_left) \
		"80.259 50.931 199.724 120.012 50.514 264.564 79.473 50.593 275.868"
	# DFPS-4A: 80.259 50.931 199.724 120.012 50.514 264.564 79.473 50.593 275.868
	# Breadboard: 79.614 51.505 199.754 119.777 51.355 264.265 79.277 51.400 275.713
	set config(mount_right) \
		"-104.780 51.156 198.354 -107.973 50.745 274.238 -147.781 50.858 260.948"
	# DFPS-4A: -104.780 51.156 198.354 -107.973 50.745 274.238 -147.781 50.858 260.948
	# Breadboard: -104.039 51.210 199.297 -108.680 51.004 275.110 -148.231 50.989 261.059
	set info(coord_left) [lwdaq bcam_coord_from_mount $config(mount_left)]
	set info(coord_right) [lwdaq bcam_coord_from_mount $config(mount_right)]

	# Default north-south, and east-west control values.
	set config(ns_all) $config(dac_zero) 
	set config(ew_all) $config(dac_zero) 
	
	# Command transmission values.
	set config(initiate_delay) "0.010"
	set config(spacing_delay) "0.0014"
	set config(byte_processing_time) "0.0002"
	set info(rf_on_op) "0081"
	set info(rf_xmit_op) "82"
	set info(checksum_preload) "1111111111111111"	
	set config(id) "FFFF"
	set config(commands) "8"
	
	# Panel appearance.
	set config(label_color) "green"
	set config(zoom) "0.5"
	set config(intensify) "exact"
	
	# Fiber View Camera Calibrator (FVCC) settings.
	set info(fvcc_state) "Idle"
	set info(cam_default) "12.675 39.312 1.0 0.0 0.0 2 19.0 0.0"
	set info(cam_left) $info(cam_default)
	set info(cam_right) $info(cam_default)
	set info(mount_left) "0 0 0 -21 0 -73 21 0 -73"
	set info(mount_right) "0 0 0 -2 1 0 -73 21 0 -73"
	set info(coord_left) [lwdaq bcam_coord_from_mount $info(mount_left)]
	set info(coord_right) [lwdaq bcam_coord_from_mount $info(mount_right)]
	set info(source_1) "0 105 -50"
	set info(source_2) "30 105 -50"
	set info(source_3) "0 75 -50"
	set info(source_4) "30 75 -50"
	set info(num_sources) "4"
	set info(spots_left) "100 100 200 100 100 200 200 200"
	set info(spots_right) "100 100 200 100 100 200 200 200"
	set config(bcam_width) "5180"
	set config(bcam_height) "3848"
	set config(bcam_threshold) "10 #"
	set config(bcam_sort) "8"
	set config(displace_scale) "1"
	set config(cross_size) "100"
	set config(fit_scaling) "0 0 0 1 1 0 1 1"
	set config(fit_steps) "1000"
	set config(fit_restarts) "4"
	set config(fit_startsize) "1"
	set config(fit_endsize) "0.005"
	set config(fit_show) "0"
	set config(fit_details) "0"
	set config(fit_stop) "0"
	set config(fvcc_zoom) "1.0"
	set config(fvcc_intensify) "exact"
	set info(fvcc_examine_window) "$info(window).fvcc_examine_window"
	set info(fvcc_state) "Idle"
	
	# Fiducial Plate Calibrator (FPC) settings.
	set info(fpc_orientations) "0 90 180 270"
	set info(fpc_swaps) "0 1 0 1"
	set info(fpc_orientation_codes) "1 2 4 3"
	set config(fpc_analysis_enable) "21"
	set config(fpc_analysis_square_size_um) "340"
	set config(fpc_daq_flash_seconds) "0.02"
	set config(fpc_daq_source_driver_socket) "9"
	set config(fpc_analysis_reference_code) "3"
	set config(fpc_analysis_reference_x_um) "0"
	set config(fpc_analysis_reference_y_um) "5180"
	LWDAQ_set_image_sensor $info(image_sensor) Rasnik
	set config(fpc_zoom) "0.5"
	set config(fpc_intensify) "exact"
	set info(fpc_examine_window) "$info(window).fpc_examine_window"
	set info(fpc_state) "Idle"
	
	# Fiducial Plate Calibrator (FPC) data. We have default values for rasnik
	# mask measurements from all four guide sensors in all four orientations,
	# for use in testing FPC calculations.
	set fpc_data {
24.315 68.403 4.776 69.198 68.384 3.833 24.233 23.443 0.848 69.284 23.490 9.864 
29.141 24.061 4.892 29.181 68.942 3.805 74.108 23.969 0.987 74.083 69.016 9.386 
73.477 28.849 5.348 28.594 28.884 3.947 73.558 73.819 0.832 28.537 73.766 9.426 
68.694 73.226 4.103 68.663 28.327 3.893 23.723 73.299 0.837 23.765 28.252 9.873 
	}
	set fpc_data [split [string trim $fpc_data] "\n"]
	for {set i 0} {$i < [llength $info(fpc_orientations)]} {incr i} {
		set info(fpc_mask_[lindex $info(fpc_orientations) $i]) [lindex $fpc_data $i]
	}

	# If we have a settings file, read and implement.	
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 

	# Create spaces to store FVC images as they come in from the BCAM
	# Instrument.
	foreach side {left right} {
		set info(image_$side) dfps_manager_$side
		lwdaq_image_create -name $info(image_$side) -width 700 -height 520
	}

	# Create spaces to store FVC images read from disk.
	foreach side {left right} {
		set info(fvcc_$side) fvcc_$side
		lwdaq_image_create -name $info(fvcc_$side) -width 700 -height 520
	}

	# Create spaces to store guide sensor images read from the Rasnik
	# Instrument.
	foreach guide $info(guide_sensors) {
		lwdaq_image_create -name fpc_$guide -width 520 -height 700
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
	set checksum $info(checksum_preload)
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
		LWDAQ_transmit_command_hex $sock $info(rf_on_op)
		LWDAQ_delay_seconds $sock $config(initiate_delay)
		foreach c $commands {
			LWDAQ_transmit_command_hex $sock "[format %02X $c]$info(rf_xmit_op)"
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
proc DFPS_Manager_set {id ns ew} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set command [DFPS_Manager_id_bytes $id]
	set n $ns
	set s [expr 65535 - $ns]
	set e $ew
	set w [expr 65535 - $ew]
	append command " 1 [expr $n / 256] [expr $n % 256]\
		2 [expr $s / 256] [expr $s % 256]\
		3 [expr $e / 256] [expr $e % 256]\
		4 [expr $w / 256] [expr $w % 256]"
	DFPS_Manager_transmit $command
	return "$command"
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
	set info(coord_left) [lwdaq bcam_coord_from_mount $config(mount_left)]
	set info(coord_right) [lwdaq bcam_coord_from_mount $config(mount_right)]

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
				[lrange [set b] 0 2] $info(coord_$side)]
			set dir_$side [lwdaq xyz_global_from_local_vector \
				[lrange [set b] 3 5] $info(coord_$side)]
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
	
	if {![winfo exists $info(window)]} {
		return ""
	}
	
	set info(control) "Check"	

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
	
	set info(control) "Idle"	
	return $sources
}

#
# DFPS_Manager_move_all sets the control values of all actuators to the values
# specified in the ns_all and ew_all parameters, waits for the settling time,
# and checks positions. It returns the positions of all sources.
#
proc DFPS_Manager_move_all {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	if {![winfo exists $info(window)]} {
		return ""
	}
	
	set info(control) "Move_All"	

	if {[catch {
		foreach id $config(controllers) {
			DFPS_Manager_set $id $config(ns_all) $config(ew_all)
		}
		LWDAQ_wait_ms $config(settling_ms)	
	} error_result]} {
		LWDAQ_print $info(text) "ERROR: $error_result"
		set info(control) "Idle"
		return ""
	}

	set info(control) "Idle"	
	return "$config(ns_all) $config(ew_all)"
}

#
# DFPS_Manager_zero_all sets the control values of all actuators to the value
# specified in dac_zero, waits for the settling time, and checks positions. It
# returns the positions of all sources.
#
proc DFPS_Manager_zero_all {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	
	if {![winfo exists $info(window)]} {
		return ""
	}
	
	set info(control) "Zero_All"	

	if {[catch {
		foreach id $config(controllers) {
			DFPS_Manager_set $id $config(dac_zero) $config(dac_zero)
		}
		LWDAQ_wait_ms $config(settling_ms)	
	} error_result]} {
		LWDAQ_print $info(text) "ERROR: $error_result"
		set info(control) "Idle"
		return ""
	}

	set info(control) "Idle"	
	return "$config(dac_zero) $config(dac_zero)"
}

#
# DFPS_Manager_fvcc_get_params puts together a string containing the parameters
# the fitter can adjust to minimise the calibration disagreement. The fitter
# will adjust any parameter for which we assign a scaling value greater than 
# zero. The scaling string gives the scaling factors the fitter uses for each
# camera calibration constant. The scaling factors are used twice: once for 
# the left camera and once for the right. See the fitting routine for their
# implementation.
#
proc DFPS_Manager_fvcc_get_params {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set params "$info(cam_left) $info(cam_right)"
	return $params
}

#
# DFPS_Manager_fvcc_examine opens a new window that displays the CMM measurements
# of the left and right mounting balls and the calibration sources. It displays
# the spot positions for these calibration sources in the left and right FVCs.
# The window allows us to modify the all these values by hand.
#
proc DFPS_Manager_fvcc_examine {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set w $info(fvcc_examine_window)
	if {![winfo exists $w]} {
		toplevel $w
		wm title $w "FVCC Coordinate Measurements, DFPS Calibrator $info(version)"
	} {
		raise $w
		return ""
	}

	foreach mount {Left Right} {
		set b [string tolower $mount]
		set f [frame $w.mnt$b]
		pack $f -side top -fill x
		label $f.l$b -text "$mount Mount:"
		entry $f.e$b -textvariable DFPS_Manager_info(mount_$b) -width 70
		pack $f.l$b $f.e$b -side left -expand yes
	}

	for {set a 1} {$a <= $info(num_sources)} {incr a} {
		set f [frame $w.src$a]
		pack $f -side top -fill x
		label $f.l$a -text "Source $a\:"
		entry $f.e$a -textvariable DFPS_Manager_info(source_$a) -width 70
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	foreach mount {Left Right} {
		set b [string tolower $mount]
		set f [frame $w.spt$b]
		pack $f -side top -fill x
		label $f.l$b -text "$mount Spots:"
		entry $f.e$b -textvariable DFPS_Manager_info(spots_$b) -width 70
		pack $f.l$b $f.e$b -side left -expand yes
	}
	
	return ""
}

#
# DFPS_Manager_fvcc_disagreement calculates root mean square square distance
# between the actual image positions and the modeled image positions we obtain
# when applying our mount measurements, FVC calibration constants, and measured
# source positions. We pass our FVC calibration constants into the routine with
# the params argument. If we omit this argument, the routine uses the constants
# stored in the left and right camera entries of our config array. Another
# optional parameter enables or disables the display of the blue crosses that
# show where the current parameters suggest the sources must be. By default, the
# display is enabled. This routine is called by the simplex fitter two or three
# hundred times do obtain the optimal camera calibration constants. The fit
# takes a fraction of a second with the display disabled, roughly ten seconds
# with the display enabled. All the time goes into clearing and drawing the
# images on the screen.
#
proc DFPS_Manager_fvcc_disagreement {{params ""} {show "1"}} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	# If user has closed the calibrator window, generate an error so that we stop any
	# fitting that might be calling this routine. 
	if {![winfo exists $info(window)]} {
		error "No DFPS window open."
	}
	
	# If no parameters specified, use those stored in configuration array.
	if {$params == ""} {
		set params [DFPS_Manager_fvcc_get_params]
	}
	
	# Make sure messages from the BCAM routines get to the DFPS Calibrator's text
	# window. Set the number of decimal places to three.
	lwdaq_config -text_name $info(fvcc_text)

	# Extract the two sets of camera calibration constants from the parameters passed
	# to us by the fitter.
	set fvc_left "FVC_L [lrange $params 0 7]"
	set fvc_right "FVC_R [lrange $params 8 15]"
	
	# Clear the overlay if showing.
	if {$show} {
		foreach side {left right} {
			lwdaq_image_manipulate $info(fvcc_$side) none -clear 1
		}
	}	
	
	# Go through the four sources. For each source, we calculate the modelled
	# image position in each camera. We look up the actual image position in
	# each camera, as we obtained when we read the two images. We square the
	# distance between the actual and modelled positions and add to our
	# disagreement.
	set sum_squares 0
	set count 0
	foreach side {left right} {
		set spots $info(spots_$side)
		for {set a 1} {$a <= $info(num_sources)} {incr a} {
			set sb [lwdaq xyz_local_from_global_point \
				$info(source_$a) $info(coord_$side)]
			set th [lwdaq bcam_image_position $sb [set fvc_$side]]
			scan $th %f%f x_th y_th
			set x_th [format %.2f [expr $x_th * 1000.0]]
			set y_th [format %.2f [expr $y_th * 1000.0]]
			set x_a [lindex $spots 0]
			set y_a [lindex $spots 1]
			set spots [lrange $spots 2 end]
			set err [expr ($x_a-$x_th)*($x_a-$x_th) + ($y_a-$y_th)*($y_a-$y_th)]
			set sum_squares [expr $sum_squares + $err]
			incr count
			
			if {$show} {
				set y [expr $config(bcam_height) - $y_th]
				set x $x_th
				set w $config(cross_size)
				lwdaq_graph "[expr $x - $w] $y [expr $x + $w] $y" \
					$info(fvcc_$side) -entire 1 \
					-x_min 0 -x_max $config(bcam_width) \
					-y_min 0 -y_max $config(bcam_height) -color 2
				lwdaq_graph "$x [expr $y - $w] $x [expr $y + $w]" \
					$info(fvcc_$side) -entire 1 \
					-x_min 0 -x_max $config(bcam_width) \
					-y_min 0 -y_max $config(bcam_height) -color 2
			}
		}
	}
	
	# Calculate root mean square error.
	set err [format %.3f [expr sqrt($sum_squares/$count)]]	
	
	# Draw the boxes and rectangles if showing.
	if {$show} {
		foreach side {left right} {
			lwdaq_draw $info(fvcc_$side) fvcc_$side \
				-intensify $config(fvcc_intensify) -zoom $config(fvcc_zoom)
		}
	}
	
	# Return the total disagreement, which is our error value.
	return $err
}

#
# DFPS_Manager_fvcc_show calls the disagreement function to show the location of 
# the modelled sources, and prints the calibration constants and disagreement
# to the text window, followed by a zero to indicated that zero fitting steps
# took place to produce these parameters and results.
#
proc DFPS_Manager_fvcc_show {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	
	set info(coord_left) [lwdaq bcam_coord_from_mount $info(mount_left)]
	set info(coord_right) [lwdaq bcam_coord_from_mount $info(mount_right)]
	set err [DFPS_Manager_fvcc_disagreement]
	LWDAQ_print $info(fvcc_text) "[DFPS_Manager_fvcc_get_params] $err 0"

	return ""
}

#
# DFPS_Manager_fvcc_check projects the image of each source in the left and right
# cameras to make a bearing line in the left and right mount coordinates using
# the current camera calibration constants, transforms to global coordinates
# using the mounting ball coordinates, and finds the mid-point of the shortest
# line between these two lines. This mid-point is the FVC measurement of the
# source position. It compares this position to the measured source position and
# reports the difference between the two.
#
proc DFPS_Manager_fvcc_check {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	
	LWDAQ_print $info(fvcc_text) "\nGlobal Measured Position and Error\
		(xm, ym, zm, xe, ye, ze in mm):" purple
	set sources ""
	set sum_squares 0.0
	for {set i 1} {$i <= 4} {incr i} {	
		lwdaq_config -fsd 6
		foreach side {left right} {
			set x [expr 0.001 * [lindex $info(spots_$side) [expr ($i-1)*2]]]
			set y [expr 0.001 * [lindex $info(spots_$side) [expr ($i-1)*2+1]]]
			set b [lwdaq bcam_source_bearing "$x $y" "$side $info(cam_$side)"]
			set point_$side [lwdaq xyz_global_from_local_point \
				[lrange [set b] 0 2] $info(coord_$side)]
			set dir_$side [lwdaq xyz_global_from_local_vector \
				[lrange [set b] 3 5] $info(coord_$side)]
		}
		lwdaq_config -fsd 3
		
		set bridge [lwdaq xyz_line_line_bridge \
			"$point_left $dir_left" "$point_right $dir_right"]
		scan $bridge %f%f%f%f%f%f x y z dx dy dz
		
		set x_src [format %8.3f [expr $x + 0.5*$dx]]
		set y_src [format %8.3f [expr $y + 0.5*$dy]]
		set z_src [format %8.3f [expr $z + 0.5*$dz]]
		
		set a $info(source_$i)
		set x_err [format %6.3f [expr [lindex $a 0]-$x_src]]
		set y_err [format %6.3f [expr [lindex $a 1]-$y_src]]
		set z_err [format %6.3f [expr [lindex $a 2]-$z_src]]
		
		LWDAQ_print $info(fvcc_text) "Source_$i\: $x_src $y_src $z_src\
			$x_err $y_err $z_err"
		
		set sum_squares [expr $sum_squares + $x_err*$x_err \
			+ $y_err*$y_err + $z_err*$z_err] 
	}

	set err [expr sqrt($sum_squares / $info(num_sources))]
	LWDAQ_print $info(fvcc_text) "Root Mean Square Error (mm): [format %.3f $err]"

	return ""
}

#
# DFPS_Manager_fvcc_read either reads a specified CMM measurement file or browses
# for one. The calibrator reads the global coordinates of the balls in the left
# and right FVC mounts, and the locations of the four calibration sources.
# Having read the CMM file the routine looks for L.gif and R.gif in the same
# directory. These should be the images returned by the left and right FVCs of
# the four calibration sources. In these two images, the sources must be
# arranged from 1 to 4 in an x-y grid, as recognised by the BCAM Instrument.
#
proc DFPS_Manager_fvcc_read {{fn ""}} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	upvar #0 LWDAQ_config_BCAM iconfig
	upvar #0 LWDAQ_info_BCAM iinfo

	if {$info(fvcc_state) != "Idle"} {return ""}
	set info(fvcc_state) "Reading"
	LWDAQ_update
	
	if {$fn == ""} {set fn [LWDAQ_get_file_name]}
	if {$fn == ""} {
		set info(fvcc_state) "Idle"
		return ""
	} {
		set img_dir [file dirname $fn]
	}
	
	LWDAQ_print $info(fvcc_text) "\nReading measurements from disk." purple
	
	LWDAQ_print $info(fvcc_text) "Reading CMM measurements from [file tail $fn]."
	set f [open $fn r]
	set cmm [read $f]
	close $f
	set numbers [list]
	foreach a $cmm {if {[string is double -strict $a]} {lappend numbers $a}}
	set spheres [list]
	foreach {d x y z} $numbers {
		lappend spheres "$x $y $z"
	}
	set info(mount_left) [join [lrange $spheres 3 5]]
	set info(mount_right) [join [lrange $spheres 6 8]]
	set spheres [lrange $spheres 9 end]
	for {set a 1} {$a <= $info(num_sources)} {incr a} {
		set info(source_$a) [lindex $spheres [expr $a-1]]
	}

	set info(coord_left) [lwdaq bcam_coord_from_mount $info(mount_left)]
	set info(coord_right) [lwdaq bcam_coord_from_mount $info(mount_right)]

	foreach {s side} {L left R right} {
		LWDAQ_print $info(fvcc_text) "Reading and analyzing image $s\.gif from $side camera."
		set ifn [file join $img_dir $s\.gif]
		if {[file exists $ifn]} {
			LWDAQ_read_image_file $ifn $info(fvcc_$side)
			set iconfig(analysis_num_spots) "$info(num_sources) $config(bcam_sort)"
			set iconfig(analysis_threshold) $config(bcam_threshold)
			LWDAQ_set_image_sensor $info(image_sensor) BCAM
			set config(bcam_width) [expr $iinfo(daq_image_width) \
				* $iinfo(analysis_pixel_size_um)]
			set config(bcam_height) [expr $iinfo(daq_image_height) \
				* $iinfo(analysis_pixel_size_um)]
			set result [LWDAQ_analysis_BCAM $info(fvcc_$side)]
			if {![LWDAQ_is_error_result $result]} {
				set info(spots_$side) ""
				foreach {x y num pk acc th} $result {
					append info(spots_$side) "$x $y "
				}
			} else {
				LWDAQ_print $info(fvcc_text) $result
				set info(fvcc_state) "Idle"
				return ""
			}
		}
	}

	set err [DFPS_Manager_fvcc_disagreement]
	LWDAQ_print $info(fvcc_text) "Current spot position fit error is $err um rms."

	LWDAQ_print $info(fvcc_text) "Done: measurements loaded and displayed." purple

	set info(fvcc_state) "Idle"
	return ""
}

#
# DFPS_Manager_fvcc_displace displaces the camera calibration constants by a
# random amount in proportion to their scaling factors. The routine does not
# print anything to the text window, but if show_fit is set, it does update the
# modelled source positions in the image. We want to be able to use this routine
# repeatedly to move the modelled sources around before starting a new fit,
# while reserving the text window for the fitted end values.
#
proc DFPS_Manager_fvcc_displace {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	foreach side {left right} {
		for {set i 0} {$i < [llength $info(cam_$side)]} {incr i} {
			lset info(cam_$side) $i [format %.3f \
				[expr [lindex $info(cam_$side) $i] \
					+ ((rand()-0.5) \
						*$config(displace_scale) \
						*[lindex $config(fit_scaling) $i])]]
		}
	}
	DFPS_Manager_fvcc_disagreement
	return ""
} 

#
# DFPS_Manager_fvcc_defaults restores the cameras to their default, nominal
# calibration constants.
#
proc DFPS_Manager_fvcc_defaults {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	foreach side {left right} {
		set info(cam_$side) $info(cam_default)
	}
	DFPS_Manager_fvcc_disagreement
	return ""
} 


#
# DFPS_Manager_fvcc_altitude is the error function for the fitter. The fitter calls
# this routine with a set of parameter values to get the disgreement, which it
# is attemptint to minimise.
#
proc DFPS_Manager_fvcc_altitude {params} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	if {$config(fit_stop)} {error "Fit aborted by user"}
	if {![winfo exists $info(window)]} {error "Tool window destroyed"}
	set altitude [DFPS_Manager_fvcc_disagreement "$params" $config(fit_show)]
	LWDAQ_support
	return $altitude
}

#
# DFPS_Manager_fvcc_fit gets the camera calibration constants as a starting point
# and calls the simplex fitter to minimise the disagreement between the modelled
# and actual bodies by adjusting the calibration constants of both parameter.
# The size of the adjustments the fitter makes in each parameter during the fit
# will be shrinking as the fit proceeds, but relative to one another thye will
# be in proportion to the list of scaling factors we have provided. These
# factors are applied twice: once to each camera. If the scaling factors are all
# unity, all parameters are fitted with equal steps. If a scaling factor is
# zero, the parameter will not be adjusted. If a scaling factor is 10, the
# parameter will be adjusted by ten times the amount as a parameter with scaling
# factor one. At the end of the fit, we take the final fitted parameter values
# and apply them to our body models.
#
proc DFPS_Manager_fvcc_fit {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set config(fit_stop) 0
	set info(fvcc_state) "Fitting"
	
	if {$config(verbose)} {
		LWDAQ_print $info(fvcc_text) "\nFitting camera parameters with settings\
		fit_show = $config(fit_show), fit_details = $config(fit_details)." purple
	}
	set start_time [clock milliseconds]
	if {[catch {
		set scaling "$config(fit_scaling) $config(fit_scaling)"
		set start_params [DFPS_Manager_fvcc_get_params] 
		set info(coord_left) [lwdaq bcam_coord_from_mount $info(mount_left)]
		set info(coord_right) [lwdaq bcam_coord_from_mount $info(mount_right)]
		lwdaq_config -show_details $config(fit_details)
		set end_params [lwdaq_simplex $start_params \
			DFPS_Manager_fvcc_altitude \
			-report $config(fit_show) \
			-steps $config(fit_steps) \
			-restarts $config(fit_restarts) \
			-start_size $config(fit_startsize) \
			-end_size $config(fit_endsize) \
			-scaling $scaling]
		lwdaq_config -show_details 0
		if {[LWDAQ_is_error_result $end_params]} {error "$end_params"}
		set info(cam_left) "[lrange $end_params 0 7]"
		set info(cam_right) "[lrange $end_params 8 15]"
		LWDAQ_print $info(fvcc_text) "$end_params"
		if {$config(verbose)} {
			LWDAQ_print $info(fvcc_text) "Fit converged in\
				[format %.2f [expr 0.001*([clock milliseconds]-$start_time)]] s\
				taking [lindex $end_params 17] steps\
				final error [format %.1f [lindex $end_params 16]] um." purple
		}
	} error_message]} {
		LWDAQ_print $info(fvcc_text) $error_message
		set info(fvcc_state) "Idle"
		return ""
	}

	DFPS_Manager_fvcc_disagreement
	set info(fvcc_state) "Idle"
}

#
# DFPS_Manager_fvcc_open opens the Fiber View Camera Calibrator window.
#
proc DFPS_Manager_fvcc_open {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set w $info(window)\.fvcc
	if {![winfo exists $w]} {
		toplevel $w
		wm title $w "Fiber View Camera Calibrator, DFPS Manager $info(version)"
	} {
		raise $w
	}
	
	set f [frame $w.controls]
	pack $f -side top -fill x
	
	label $f.state -textvariable DFPS_Manager_info(fvcc_state) -fg blue -width 10
	pack $f.state -side left -expand yes

	button $f.stop -text "Stop" -command {set DFPS_Manager_config(fit_stop) 1}
	pack $f.stop -side left -expand yes

	foreach a {Read Show Check Displace Defaults Examine Fit} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post DFPS_Manager_fvcc_$b"
		pack $f.$b -side left -expand yes
	}
	checkbutton $f.verbose -text "Verbose" -variable DFPS_Manager_config(verbose)
	pack $f.verbose -side left -expand yes

	set f [frame $w.fvc]
	pack $f -side top -fill x
	
	foreach {a wd} {bcam_threshold 6 fit_steps 8 fit_restarts 3 \
			fit_endsize 10 fit_show 2 fit_details 2 fit_scaling 20} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable DFPS_Manager_config($a) -width $wd
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	set f [frame $w.cameras]
	pack $f -side top -fill x

	foreach {a wd} {cam_left 50 cam_right 50} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable DFPS_Manager_info($a) -width $wd
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	set f [frame $w.images]
	pack $f -side top -fill x

	foreach a {left right} {
		image create photo "fvcc_$a"
		label $f.$a -image "fvcc_$a"
		pack $f.$a -side left -expand yes
	}
	
	# Create the text window and direct the lwdaq library routines to print to this
	# window.
	set info(fvcc_text) [LWDAQ_text_widget $w 120 15]
	lwdaq_config -text_name $info(fvcc_text) -fsd 3	
	
	# Draw two blank images into the display.
	foreach side {left right} {
		lwdaq_draw $info(fvcc_$side) fvcc_$side \
			-intensify $config(fvcc_intensify) -zoom $config(fvcc_zoom)
	}
	
	return $w
}

#
# DFPS_Manager_fpc_acquire reads images from all four guide sensors, displays
# them in the FPC window, analyzes them with the correct orientation codes, and
# returns the mask x and y coordinates of the top-left corner of the image, as
# well as the anti-clockwise rotation of the mask image with respect to the
# image sensor. We must specify an orientation of the fiducial plate so that
# we can get the rasnik analysis orientation code correct.
#
proc DFPS_Manager_fpc_acquire {orientation} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	upvar #0 LWDAQ_config_Rasnik iconfig 
	upvar #0 LWDAQ_info_Rasnik iinfo

	set info(fvcc_state) "Acquire"

	set i [lsearch $info(fpc_orientations) $orientation]
	set ocode 0
	set swap 0
	if {$i >= 0} {
		set ocode [lindex $info(fpc_orientation_codes) $i]
		set swap [lindex $info(fpc_swaps) $i]
	}
	
	set iconfig(analysis_orientation_code) $ocode
	set iconfig(daq_ip_addr) $config(ip_addr)
	set iconfig(analysis_enable) "0"
	LWDAQ_set_image_sensor $info(image_sensor) Rasnik 
	foreach param {analysis_square_size_um \
			daq_flash_seconds daq_source_driver_socket \
			analysis_reference_code} {
		set iconfig($param) $config(fpc_$param)
	}
	foreach param {analysis_reference_x_um analysis_reference_y_um} {
		set iinfo($param) $config(fpc_$param)
	}

	set result ""
	foreach guide $info(guide_sensors) {
		scan $config(guide_$guide) %d%d%d \
			iconfig(daq_driver_socket) \
			iconfig(daq_mux_socket) \
			iconfig(daq_device_element)
		set rasnik [LWDAQ_acquire Rasnik]
		if {[LWDAQ_is_error_result $rasnik]} {
			append rasnik " (Guide $guide, Orient $orientation, Time [clock seconds])"
			LWDAQ_print $info(fpc_text) $rasnik
			append result "-1 -1 -1 "
			continue
		}
		lwdaq_image_manipulate $iconfig(memory_name) copy -name fpc_$guide
		lwdaq_image_manipulate fpc_$guide invert -replace 1
		lwdaq_image_manipulate fpc_$guide rows_to_columns -replace 1
		set iconfig(analysis_enable) $config(fpc_analysis_enable)
		set rasnik [LWDAQ_analysis_Rasnik fpc_$guide]
		lwdaq_draw fpc_$guide fpc_$guide \
			-intensify $config(fpc_intensify) -zoom $config(fpc_zoom)
		if {![LWDAQ_is_error_result $rasnik]} {
			if {$swap} {
				append result "[format %.3f [expr 0.001*[lindex $rasnik 1]]]\
					[format %.3f [expr 0.001*[lindex $rasnik 0]]]\
					[lindex $rasnik 4] "
			} else {
				append result "[format %.3f [expr 0.001*[lindex $rasnik 0]]]\
					[format %.3f [expr 0.001*[lindex $rasnik 1]]]\
					[lindex $rasnik 4] "
			}
		} else {
			append rasnik " (Guide $guide, Orient $orientation, Time [clock seconds])"
			LWDAQ_print $info(fpc_text) $rasnik
			append result "-1 -1 -1 "
		}
	}
	
	set iconfig(analysis_orientation_code) 0
	
	if {$orientation != ""} {set info(fpc_mask_$orientation) $result}
	LWDAQ_print $info(fpc_text) "[format %3d $orientation] $result" green
	set info(fvcc_state) "Idle"
	return $result
}

#
# DFPS_Manager_fpc_calculate takes the four rasnik measurements we have obtained
# from the four orientations of the mask and calculates the mask origin in frame
# coordiates, the mask rotation with respect to frame coordinates,
# counter-clockwise positive, and the origins of the four guide sensors in frame
# coordinates as well as their rotations counter-clockwise positive with respect
# to frame coordinates.
#
proc DFPS_Manager_fpc_calculate {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

 	foreach {o1 o2} "0 180 90 270" {
		set m1 $info(fpc_mask_$o1)
		set m2 $info(fpc_mask_$o2)
		foreach gs $info(guide_sensors) {
			set x1 [lindex $m1 [expr ($gs-1)*3+0]]
			set y1 [lindex $m1 [expr ($gs-1)*3+1]]
			set x2 [lindex $m2 [expr ($gs-1)*3+0]]
			set y2 [lindex $m2 [expr ($gs-1)*3+1]]
			set x [format %.3f [expr 0.5*($x1+$x2)]]
			set y [format %.3f [expr 0.5*($y1+$y2)]]
			LWDAQ_print $info(fpc_text) "[format %4d $o1]\
				[format %4d $o2]\
				[format %4d $gs]\
				[format %10.3f $x]\
				[format %10.3f $y]"
		}
	}

	return ""
}

#
# DFPS_Manager_fpc_examine
#
proc DFPS_Manager_fpc_examine {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set w $info(fpc_examine_window)
	if {![winfo exists $w]} {
		toplevel $w
		wm title $w "FPC Rasnik Measurements, DFPS Calibrator $info(version)"
	} {
		raise $w
		return ""
	}

	foreach orientation $info(fpc_orientations) {
		set f [frame $w.orientation_$orientation]
		pack $f -side top -fill x
		label $f.l -text "Orientation $orientation\:"
		entry $f.e -textvariable DFPS_Manager_info(fpc_mask_$orientation) -width 100
		pack $f.l $f.e -side left -expand yes
	}
		
	return ""
}

#
# DFPS_Manager_fpc_open opens the Fiducial Plate Calibrator window.
#
proc DFPS_Manager_fpc_open {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set w $info(window)\.fpc
	if {![winfo exists $w]} {
		toplevel $w
		wm title $w "Fiducial Plate Calibrator, DFPS Manager $info(version)"
	} {
		raise $w
		return ""
	}
	
	set f [frame $w.controls]
	pack $f -side top -fill x
	
	label $f.state -textvariable DFPS_Manager_info(fvcc_state) -fg blue -width 10
	pack $f.state -side left -expand yes

	foreach a $info(fpc_orientations) {
		button $f.acq$a -text "Acquire $a" -command \
			[list LWDAQ_post "DFPS_Manager_fpc_acquire $a"]
		pack $f.acq$a -side left -expand yes
	}

	foreach a {Calculate Examine} {
		set b [string tolower $a]
		button $f.$b -text "$a" -command [list LWDAQ_post "DFPS_Manager_fpc_$b"]
		pack $f.$b -side left -expand yes
	}
	
	foreach a {Rasnik} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_open $a"
		pack $f.$b -side left -expand 1
	}

	set f [frame $w.options]
	pack $f -side top -fill x
	
	foreach {a wd} {analysis_enable 2 analysis_square_size_um 4 \
			daq_flash_seconds 10 analysis_reference_x_um 5 \
			analysis_reference_y_um 5} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable DFPS_Manager_config(fpc_$a) -width $wd
		pack $f.l$a $f.e$a -side left -expand yes
	}

	set f [frame $w.images]
	pack $f -side top -fill x

	foreach guide $info(guide_sensors) {
		image create photo "fpc_$guide"
		label $f.$guide -image "fpc_$guide"
		pack $f.$guide -side left -expand yes
	}
		
	# Create the text window and direct the lwdaq library routines to print to this
	# window.
	set info(fpc_text) [LWDAQ_text_widget $w 100 15]
	lwdaq_config -text_name $info(fpc_text) -fsd 3	
	
	# Draw blank images into the guide sensor displays.
	foreach guide $info(guide_sensors) {
		lwdaq_draw fpc_$guide fpc_$guide \
			-intensify $config(fpc_intensify) -zoom $config(fpc_zoom)
	}
	
	return $w
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
	foreach a {Check Move_All Zero_All Configure} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post DFPS_Manager_$b"
		pack $f.$b -side left -expand 1
	}
	foreach a {Help} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_tool_$b $info(name)"
		pack $f.$b -side left -expand 1
	}
	button $f.server -text "Server" -command "LWDAQ_server_open"
	pack $f.server -side left -expand 1
	foreach a {BCAM Diagnostic} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_open $a"
		pack $f.$b -side left -expand 1
	}
	
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
	
	foreach d {ns_all ew_all} {
		set a [string tolower $d]
		label $f.l$a -text $d -fg $config(label_color)
		entry $f.e$a -textvariable DFPS_Manager_config($a) -width 5
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	button $f.txcmd -text "Transmit Panel" \
		-command "LWDAQ_post DFPS_Manager_transmit_panel"
	pack $f.txcmd -side left -expand yes
	foreach a {FVCC FPC} {
		set b [string tolower $a]
		button $f.$b -text $a -command "DFPS_Manager_$b\_open"
		pack $f.$b -side left -expand 1
	}
	button $f.toolmaker -text "Toolmaker" -command "LWDAQ_Toolmaker"
	pack $f.toolmaker -side left -expand 1
	checkbutton $f.verbose -text "Verbose" -variable DFPS_Manager_config(verbose)
	pack $f.verbose -side left -expand yes

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


Direct Fiber Positioning System Manager
=======================================

Help coming soon.

Fiber View Camera Calibrator
============================

The Fiber View Camera Calibrator (FVCC) calculates the calibration constants of
the two Fiber View Cameras (FVCs) mounted on a DFPS base plate. The routine
assumes we have Coordinate Measuring Machine (CMM) measurements of the left FVC
mount, the right FVC mount, and four point sources visible to both cameras. The
program takes as input two images L.gif and R.gif from the left and right FVCs
respectively, and CMM.txt from the CMM.

The CMM.txt file must contain the diameter and x, y, and z coordinates of the
cone, slot, and flat balls in the two FVC mounts. After that we must find
diameter, x, y, and z coordinates of each calibration source ferrule. The file
containing these measurements must be named CMM.txt. In addition to the measured
diameters and coordinates, CMM.txt may contain any number of words that are not
real number strings and any number of white space charcters. All words that are
not real numbers will be ignored. An example CMM.txt file is to be found below.

+---------------------+--------------+------+-----------+---------+------+-------+----------+
| Feature Table       |              |      |           |         |      |       |          |
+---------------------+--------------+------+-----------+---------+------+-------+----------+
| Length Units        | Millimeters  |      |           |         |      |       |          |
| Coordinate Systems  | csys         |      |           |         |      |       |          |
| Data Alignments     | original     |      |           |         |      |       |          |
|                     |              |      |           |         |      |       |          |
| Name                | Control      | Nom  | Meas      | Tol     | Dev  | Test  | Out Tol  |
| g1                  | Diameter     |      | 12.702    | ±1.000  |      |       |          |
| g1                  | X            |      | 0.000     | ±1.000  |      |       |          |
| g1                  | Y            |      | 0.000     | ±1.000  |      |       |          |
| g1                  | Z            |      | 0.000     | ±1.000  |      |       |          |
| g2                  | Diameter     |      | 12.700    | ±1.000  |      |       |          |
| g2                  | X            |      | 100.390   | ±1.000  |      |       |          |
| g2                  | Y            |      | 0.000     | ±1.000  |      |       |          |
| g2                  | Z            |      | 0.000     | ±1.000  |      |       |          |
| g3                  | Diameter     |      | 12.698    | ±1.000  |      |       |          |
| g3                  | X            |      | 1.023     | ±1.000  |      |       |          |
| g3                  | Y            |      | -0.155    | ±1.000  |      |       |          |
| g3                  | Z            |      | 175.224   | ±1.000  |      |       |          |
| l1                  | Diameter     |      | 6.349     | ±1.000  |      |       |          |
| l1                  | X            |      | 79.614    | ±1.000  |      |       |          |
| l1                  | Y            |      | 51.505    | ±1.000  |      |       |          |
| l1                  | Z            |      | 199.754   | ±1.000  |      |       |          |
| l2                  | Diameter     |      | 6.347     | ±1.000  |      |       |          |
| l2                  | X            |      | 119.777   | ±1.000  |      |       |          |
| l2                  | Y            |      | 51.355    | ±1.000  |      |       |          |
| l2                  | Z            |      | 264.265   | ±1.000  |      |       |          |
| l3                  | Diameter     |      | 6.350     | ±1.000  |      |       |          |
| l3                  | X            |      | 79.277    | ±1.000  |      |       |          |
| l3                  | Y            |      | 51.400    | ±1.000  |      |       |          |
| l3                  | Z            |      | 275.713   | ±1.000  |      |       |          |
| r1                  | Diameter     |      | 6.352     | ±1.000  |      |       |          |
| r1                  | X            |      | -104.039  | ±1.000  |      |       |          |
| r1                  | Y            |      | 51.210    | ±1.000  |      |       |          |
| r1                  | Z            |      | 199.297   | ±1.000  |      |       |          |
| r2                  | Diameter     |      | 6.352     | ±1.000  |      |       |          |
| r2                  | X            |      | -108.680  | ±1.000  |      |       |          |
| r2                  | Y            |      | 51.004    | ±1.000  |      |       |          |
| r2                  | Z            |      | 275.110   | ±1.000  |      |       |          |
| r3                  | Diameter     |      | 6.354     | ±1.000  |      |       |          |
| r3                  | X            |      | -148.231  | ±1.000  |      |       |          |
| r3                  | Y            |      | 50.989    | ±1.000  |      |       |          |
| r3                  | Z            |      | 261.059   | ±1.000  |      |       |          |
| u1                  | Diameter     |      | 2.498     | ±1.000  |      |       |          |
| u1                  | X            |      | -28.554   | ±1.000  |      |       |          |
| u1                  | Y            |      | 103.614   | ±1.000  |      |       |          |
| u1                  | Z            |      | -91.666   | ±1.000  |      |       |          |
| u2                  | Diameter     |      | 2.399     | ±1.000  |      |       |          |
| u2                  | X            |      | 1.447     | ±1.000  |      |       |          |
| u2                  | Y            |      | 103.722   | ±1.000  |      |       |          |
| u2                  | Z            |      | -92.199   | ±1.000  |      |       |          |
| u3                  | Diameter     |      | 2.401     | ±1.000  |      |       |          |
| u3                  | X            |      | -28.490   | ±1.000  |      |       |          |
| u3                  | Y            |      | 73.650    | ±1.000  |      |       |          |
| u3                  | Z            |      | -92.161   | ±1.000  |      |       |          |
| u4                  | Diameter     |      | 2.372     | ±1.000  |      |       |          |
| u4                  | X            |      | 1.433     | ±1.000  |      |       |          |
| u4                  | Y            |      | 73.749    | ±1.000  |      |       |          |
| u4                  | Z            |      | -92.267   | ±1.000  |      |       |          |
+---------------------+--------------+------+-----------+---------+------+-------+----------+

The calibrator works by minimizing disagreement between actual spot positions
and modelled spot positions. When we press Fit, the simplex fitter starts
minimizing this disagreement by adjusting the calibrations of the left and right
FVCs. The fit applies the "fit_scaling" values to the eight calibration constants of
the cameras. We can fix any one of the eight parameters by setting its scaling
value to zero. We always fix the pivot.z scaling factor to zero because this
parameter has no geometric implementation. The fit uses only those calibration
sources specified in the fit_sources string.

Stop: Abort fitting.

Show: Show the silhouettes and modelled bodies.

Clear: Clear the silhouettes and modelled bodies, show the raw images.

Displace: Displace the camera calibration constants from their current values.

Fit: Start the simplex fitter adjusting calibration constants to minimize
disagreement.

Configure: Open configuration panel with Save and Unsave buttons.

Help: Get this help page.

Read: Select a directory, read image files and CMM measurements. The images must
be L.gif and R.gif.

Examine: Open a window that displays the mount and source measurements produced
by the CMM. We can modify any measurement in this window and see how our
modification affects the fit by following with the Show button.

To use the calibrator, press Read and select your measurements. The calibrator
will display the images, the measured image positions, and the modelled image
positions. If the bodies are nowhere near the silhouettes, or they are not
visible, you most likely have a mix-up in the mount coordinates. Press Fit. The
modelled sources will start moving around. The status indicator on the top left
will say "Fitting". The status label will return to "Idle" when the fit is done.
The camera calibration constants are now ready.


Fiducial Plate Calibrator
=========================

Help coming soon.


(C) Kevan Hashemi, 2023-2024, Open Source Instruments Inc.
https://www.opensourceinstruments.com

----------End Help----------

----------Begin Data----------

----------End Data----------