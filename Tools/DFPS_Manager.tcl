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
	
	LWDAQ_tool_init "DFPS_Manager" "2.3"
	if {[winfo exists $info(window)]} {return ""}

	# The state variable tells us the current state of the tool.
	set info(state) "Idle"

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
	set config(flash_s) "0.004"
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
	set config(guide_daq_1) "7 0 2"
	set config(guide_daq_2) "6 0 1"
	set config(guide_daq_3) "7 0 1"
	set config(guide_daq_4) "6 0 2"
	set info(guide_sensors) "1 2 3 4"
	set info(guide_manipulations) "invert rows_to_columns"
	set info(fiducials) "1 2 3 4"
	
	# Data acquisition and analysis results.
	set config(spots) ""
	set config(sources) ""
	set config(verbose) "1"
		
	# Fiber view camera calibration constants.
	set info(cam_left) \
		"12.675 39.312 1.000 -7.272 0.897 2.000 19.028 5.113"
	# DFPS-4A: Y71010 12.675 39.312 1.000 -7.272 0.897 2.000 19.028 5.113
	# Breadboard: Y71066 12.675 39.312 1.000 -14.793 -2.790 2.000 18.778 2.266
	set info(cam_right) \
		"12.675 39.312 1.000 2.718 -1.628 2.000 19.165 8.220"
	# DFPS-4A: Y71003 12.675 39.312 1.000 2.718 -1.628 2.000 19.165 8.220
	# Breadboard: Y71080 12.675 39.312 1.000 -7.059 3.068 2.000 19.016 1.316
	
	# Fiber view camera mount measurents.
	set info(mount_left) \
		"80.259 50.931 199.724 120.012 50.514 264.564 79.473 50.593 275.868"
	# DFPS-4A: 80.259 50.931 199.724 120.012 50.514 264.564 79.473 50.593 275.868
	# Breadboard: 79.614 51.505 199.754 119.777 51.355 264.265 79.277 51.400 275.713
	set info(mount_right) \
		"-104.780 51.156 198.354 -107.973 50.745 274.238 -147.781 50.858 260.948"
	# DFPS-4A: -104.780 51.156 198.354 -107.973 50.745 274.238 -147.781 50.858 260.948
	# Breadboard: -104.039 51.210 199.297 -108.680 51.004 275.110 -148.231 50.989 261.059
	
	# We obtain the pose of the mount coordinats by a fit to the mount measurements.
	set info(coord_left) [lwdaq bcam_coord_from_mount $info(mount_left)]
	set info(coord_right) [lwdaq bcam_coord_from_mount $info(mount_right)]
	
	# Pose of plate coordinates with respect to rasnik coordinates.
	set info(plate_rasnik_pose) "48.800 48.300 0.000 0.000 0.000 0.000"
	
	# Fiducial fiber positions in fiducial coordinates.
	set info(fiducial_1) "-15 +15 0"
	# DFPS-4A: 
	set info(fiducial_2) "+15 +15 0"
	# DFPS-4A: 
	set info(fiducial_3) "-15 -15 0"
	# DFPS-4A: 
	set info(fiducial_4) "+15 -15 0"
	# DFPS-4A: 
	
	# Guide sensor positions and orientations in fiducial coordinates.
	set info(guide_1) "-24.598 19.792 5.028"
	# DFPS-4A: 
	set info(guide_2) "20.268 19.770 3.874"
	# DFPS-4A: 
	set info(guide_3) "-24.685 -25.170 0.917"
	# DFPS-4A: 
	set info(guide_4) "20.347 -25.146 9.414"
	# DFPS-4A: 
	
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
	
	# Watchdog control.
	set info(fiducial_check_time) "0"
	set info(mast_check_time) "0"
	set config(fiducial_check_period) "100"
	set config(mast_check_period) "10"
	set config(check_masts) "0"
	set config(check_fiducials) "0"
	
	# Window settings.
	set config(label_color) "green"
	set config(guide_zoom) "0.3"
	set config(fvc_zoom) "0.5"
	set config(intensify) "exact"
	set info(examine_window) "$info(window).examine_window"
	
	# Fiber View Camera Coordinate Measuring Machine Calibration (FVCCMM) settings.
	set info(num_sources) "4"
	set info(fvccmm_src_1) "-28.223 104.229 -91.363"
	set info(fvccmm_src_2) "1.717 104.294 -91.613"
	set info(fvccmm_src_3) "-28.229 74.268 -91.925"
	set info(fvccmm_src_4) "1.631 74.257 -91.437"
	set info(spots_left) \
		"1572.16 1192.59 3377.92 1154.19 1594.61 3038.75 3381.78 3051.64"
	set info(spots_right) \
		"2223.58 1109.76 4000.05 1117.53 2232.85 3038.02 4017.75 2984.44"
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
	set config(fvccmm_zoom) "1.0"
	set config(fvccmm_intensify) "exact"
	set info(fvccmm_examine_window) "$info(window).fvccmm_examine_window"
	
	# Guide Sensor with Rasnik Calibration (GSRasnik) settings.
	set info(gsrasnik_orientations) "0 90 180 270"
	set info(gsrasnik_swaps) "0 1 0 1"
	set info(gsrasnik_orientation_codes) "1 2 4 3"
	set config(gsrasnik_algorithm) "21"
	set config(gsrasnik_square_um) "340"
	set config(gsrasnik_flash_s) "0.02"
	set info(gsrasnik_refcode) "3"
	set config(gsrasnik_ref_x_um) "0"
	set config(gsrasnik_ref_y_um) "5180"
	set config(gsrasnik_rot_mrad) "-0.10"
	set config(gsrasnik_width) "130.000"
	set config(gsrasnik_height) "130.000"
	LWDAQ_set_image_sensor $info(image_sensor) Rasnik
	set config(gsrasnik_zoom) "0.5"
	set config(gsrasnik_intensify) "exact"
	set info(gsrasnik_examine_window) "$info(window).gsrasnik_examine_window"
	
	# GSRasnik data. We have default values for rasnik mask measurements from
	# all four guide sensors in all four orientations, for use in testing
	# GSRasnik calculations.
	set gsrasnik_data {
24.315 68.403 -4.776 69.198 68.384 -3.833 24.233 23.443 -0.848 69.284 23.490 -9.864 
29.141 24.061 -4.892 29.181 68.942 -3.805 74.108 23.969 -0.987 74.083 69.016 -9.386 
73.477 28.849 -5.348 28.594 28.884 -3.947 73.558 73.819 -0.832 28.537 73.766 -9.426 
68.694 73.226 -4.103 68.663 28.327 -3.893 23.723 73.299 -0.837 23.765 28.252 -9.873 
	}
	set gsrasnik_data [split [string trim $gsrasnik_data] "\n"]
	for {set i 0} {$i < [llength $info(gsrasnik_orientations)]} {incr i} {
		set info(gsrasnik_mask_[lindex $info(gsrasnik_orientations) $i]) \
			[lindex $gsrasnik_data $i]
	}
	
	# Fiducial Fiber Rotation Calibration (FFRotate) settings.
	
	
	# Fiber View Camera Gauge Block Calibration (FVCGauge) settings.

	# If we have a settings file, read and implement.	
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 
	
	# Calibration file.
	set config(calibration_file) \
		[file join $LWDAQ_Info(tools_dir) Data DFPS_Calibration.tcl]
	if {[file exists $config(calibration_file)]} {
		uplevel #0 [list source $config(calibration_file)]
	} 

	# Create spaces to store FVC images as they come in from the BCAM
	# Instrument.
	foreach side {left right} {
		set info(image_$side) dfps_manager_$side
		lwdaq_image_create -name $info(image_$side) -width 700 -height 520
	}

	# Create spaces to store guide images as they come in from the Camera
	# Instrument.
	foreach guide $info(guide_sensors) {
		set info(image_$guide) dfps_manager_$guide
		lwdaq_image_create -name $info(image_$guide) -width 520 -height 700
	}

	# Create spaces to store FVC images read from disk.
	foreach side {left right} {
		set info(fvccmm_$side) fvccmm_$side
		lwdaq_image_create -name $info(fvccmm_$side) -width 700 -height 520
	}

	return ""   
}

#
# DFPS_Manager_examine opens a new window that displays the CMM measurements
# of the left and right mounting balls, the camera calibration constants,
# and the fiducial plate measurements.
#
proc DFPS_Manager_examine {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set w $info(examine_window)
	if {![winfo exists $w]} {
		toplevel $w
		wm title $w "Calibration Constants, DFPS Manager $info(version)"
	} {
		raise $w
		return ""
	}

	foreach a {Left Right} {
		set b [string tolower $a]
		set f [frame $w.mnt$b]
		pack $f -side top -fill x
		label $f.l$b -text "Mount $a:"
		entry $f.e$b -textvariable DFPS_Manager_info(mount_$b) -width 70
		pack $f.l$b $f.e$b -side left -expand yes
	}

	foreach a {Left Right} {
		set b [string tolower $a]
		set f [frame $w.cam$b]
		pack $f -side top -fill x
		label $f.l$b -text "Camera $a:"
		entry $f.e$b -textvariable DFPS_Manager_info(cam_$b) -width 70
		pack $f.l$b $f.e$b -side left -expand yes
	}

	foreach a {1 2 3 4} {
		set b [string tolower $a]
		set f [frame $w.fid$b]
		pack $f -side top -fill x
		label $f.l$b -text "Fiducial $a:"
		entry $f.e$b -textvariable DFPS_Manager_info(fiducial_$b) -width 70
		pack $f.l$b $f.e$b -side left -expand yes
	}

	foreach a {1 2 3 4} {
		set b [string tolower $a]
		set f [frame $w.gd$b]
		pack $f -side top -fill x
		label $f.l$b -text "Guide $a:"
		entry $f.e$b -textvariable DFPS_Manager_info(guide_$b) -width 70
		pack $f.l$b $f.e$b -side left -expand yes
	}

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
# DFPS_Manager_txp opens a new window and provides a button for transmitting a
# string of command bytes to a device. There are two entry boxes. One for the
# device identifier, another for the command bytes. The identifier is a four-hex
# value. The command bytes are each decimal values 0..255 separated by spaces.
# The routine parses the identifier into two bytes, transmits all the command
# bytes, and appends the correct checksum on the end.
#
proc DFPS_Manager_txp {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	
	set w $info(window)\.xmit_panel
	if {[winfo exists $w]} {
		raise $w
		return ""
	}
	toplevel $w
	wm title $w "Fiber_Positioner $info(version) Transmit Command Panel"

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
	set iconfig(daq_flash_seconds) $config(flash_s)
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
				-intensify $config(intensify) -zoom $config(fvc_zoom)
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
	set info(coord_left) [lwdaq bcam_coord_from_mount $info(mount_left)]
	set info(coord_right) [lwdaq bcam_coord_from_mount $info(mount_right)]

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
			set b [lwdaq bcam_source_bearing "$x $y" "$side $info(cam_$side)"]
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
	
	set info(state) "Check"	

	if {[catch {
		if {$elements == ""} {
			set elements [string trim "$config(fiducials) $config(guides)"]
		}
		set spots [DFPS_Manager_spots $elements]
		set sources [DFPS_Manager_sources $spots]
		LWDAQ_print $info(text) "[clock seconds] $sources"
	} error_result]} {
		LWDAQ_print $info(text) "ERROR: $error_result"
		set info(state) "Idle"
		return ""
	}
	
	set info(state) "Idle"	
	return $sources
}

#
# DFPS_Manager_move sets the control values of all actuators to the values
# specified in the ns_all and ew_all parameters, waits for the settling time,
# and checks positions. It returns the positions of all sources.
#
proc DFPS_Manager_move {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	if {![winfo exists $info(window)]} {
		return ""
	}
	
	set info(state) "Move"	

	if {[catch {
		foreach id $config(controllers) {
			DFPS_Manager_set $id $config(ns_all) $config(ew_all)
		}
		LWDAQ_wait_ms $config(settling_ms)	
	} error_result]} {
		LWDAQ_print $info(text) "ERROR: $error_result"
		set info(state) "Idle"
		return ""
	}

	set info(state) "Idle"	
	return "$config(ns_all) $config(ew_all)"
}

#
# DFPS_Manager_zero sets the control values of all actuators to the value
# specified in dac_zero, waits for the settling time, and checks positions. It
# returns the positions of all sources.
#
proc DFPS_Manager_zero {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	
	if {![winfo exists $info(window)]} {
		return ""
	}
	
	set info(state) "Zero"	

	if {[catch {
		foreach id $config(controllers) {
			DFPS_Manager_set $id $config(dac_zero) $config(dac_zero)
		}
		LWDAQ_wait_ms $config(settling_ms)	
	} error_result]} {
		LWDAQ_print $info(text) "ERROR: $error_result"
		set info(state) "Idle"
		return ""
	}

	set info(state) "Idle"	
	return "$config(dac_zero) $config(dac_zero)"
}

#
# DFPS_Manager_fvccmm_get_params puts together a string containing the parameters
# the fitter can adjust to minimise the calibration disagreement. The fitter
# will adjust any parameter for which we assign a scaling value greater than 
# zero. The scaling string gives the scaling factors the fitter uses for each
# camera calibration constant. The scaling factors are used twice: once for 
# the left camera and once for the right. See the fitting routine for their
# implementation.
#
proc DFPS_Manager_fvccmm_get_params {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set params "$info(cam_left) $info(cam_right)"
	return $params
}

#
# DFPS_Manager_fvccmm_examine opens a new window that displays the CMM measurements
# of the left and right mounting balls and the calibration sources. It displays
# the spot positions for these calibration sources in the left and right FVCs.
# The window allows us to modify the all these values by hand.
#
proc DFPS_Manager_fvccmm_examine {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set w $info(fvccmm_examine_window)
	if {![winfo exists $w]} {
		toplevel $w
		wm title $w "FVCCMM Measurements, DFPS Calibrator $info(version)"
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

	foreach a {1 2 3 4} {
		set f [frame $w.src$a]
		pack $f -side top -fill x
		label $f.l$a -text "Source $a\:"
		entry $f.e$a -textvariable DFPS_Manager_info(fvccmm_src_$a) -width 70
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
# DFPS_Manager_fvccmm_disagreement calculates root mean square square distance
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
proc DFPS_Manager_fvccmm_disagreement {{params ""} {show "1"}} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	# If user has closed the calibrator window, generate an error so that we stop any
	# fitting that might be calling this routine. 
	if {![winfo exists $info(window)]} {
		error "No DFPS window open."
	}
	
	# If no parameters specified, use those stored in configuration array.
	if {$params == ""} {
		set params [DFPS_Manager_fvccmm_get_params]
	}
	
	# Make sure messages from the BCAM routines get to the DFPS Calibrator's text
	# window. Set the number of decimal places to three.
	lwdaq_config -text_name $info(fvccmm_text)

	# Extract the two sets of camera calibration constants from the parameters passed
	# to us by the fitter.
	set fvc_left "FVC_L [lrange $params 0 7]"
	set fvc_right "FVC_R [lrange $params 8 15]"
	
	# Clear the overlay if showing.
	if {$show} {
		foreach side {left right} {
			lwdaq_image_manipulate $info(fvccmm_$side) none -clear 1
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
				$info(fvccmm_src_$a) $info(coord_$side)]
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
					$info(fvccmm_$side) -entire 1 \
					-x_min 0 -x_max $config(bcam_width) \
					-y_min 0 -y_max $config(bcam_height) -color 2
				lwdaq_graph "$x [expr $y - $w] $x [expr $y + $w]" \
					$info(fvccmm_$side) -entire 1 \
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
			lwdaq_draw $info(fvccmm_$side) fvccmm_$side \
				-intensify $config(fvccmm_intensify) -zoom $config(fvccmm_zoom)
		}
	}
	
	# Return the total disagreement, which is our error value.
	return $err
}

#
# DFPS_Manager_fvccmm_show calls the disagreement function to show the location of 
# the modelled sources, and prints the calibration constants and disagreement
# to the text window, followed by a zero to indicated that zero fitting steps
# took place to produce these parameters and results.
#
proc DFPS_Manager_fvccmm_show {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	
	set info(coord_left) [lwdaq bcam_coord_from_mount $info(mount_left)]
	set info(coord_right) [lwdaq bcam_coord_from_mount $info(mount_right)]
	set err [DFPS_Manager_fvccmm_disagreement]
	LWDAQ_print $info(fvccmm_text) "[DFPS_Manager_fvccmm_get_params] $err 0"

	return ""
}

#
# DFPS_Manager_fvccmm_check projects the image of each source in the left and right
# cameras to make a bearing line in the left and right mount coordinates using
# the current camera calibration constants, transforms to global coordinates
# using the mounting ball coordinates, and finds the mid-point of the shortest
# line between these two lines. This mid-point is the FVC measurement of the
# source position. It compares this position to the measured source position and
# reports the difference between the two.
#
proc DFPS_Manager_fvccmm_check {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	
	LWDAQ_print $info(fvccmm_text) "\nGlobal Measured Position and Error\
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
		
		set a $info(fvccmm_src_$i)
		set x_err [format %6.3f [expr [lindex $a 0]-$x_src]]
		set y_err [format %6.3f [expr [lindex $a 1]-$y_src]]
		set z_err [format %6.3f [expr [lindex $a 2]-$z_src]]
		
		LWDAQ_print $info(fvccmm_text) "fvccmm_src_$i\: $x_src $y_src $z_src\
			$x_err $y_err $z_err"
		
		set sum_squares [expr $sum_squares + $x_err*$x_err \
			+ $y_err*$y_err + $z_err*$z_err] 
	}

	set err [expr sqrt($sum_squares / $info(num_sources))]
	LWDAQ_print $info(fvccmm_text) "Root Mean Square Error (mm): [format %.3f $err]"

	return ""
}

#
# DFPS_Manager_fvccmm_read either reads a specified CMM measurement file or browses
# for one. The calibrator reads the global coordinates of the balls in the left
# and right FVC mounts, and the locations of the four calibration sources.
# Having read the CMM file the routine looks for L.gif and R.gif in the same
# directory. These should be the images returned by the left and right FVCs of
# the four calibration sources. In these two images, the sources must be
# arranged from 1 to 4 in an x-y grid, as recognised by the BCAM Instrument.
#
proc DFPS_Manager_fvccmm_read {{fn ""}} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	upvar #0 LWDAQ_config_BCAM iconfig
	upvar #0 LWDAQ_info_BCAM iinfo

	if {$info(state) != "Idle"} {return ""}
	set info(state) "Reading"
	LWDAQ_update
	
	if {$fn == ""} {set fn [LWDAQ_get_file_name]}
	if {$fn == ""} {
		set info(state) "Idle"
		return ""
	} {
		set img_dir [file dirname $fn]
	}
	
	LWDAQ_print $info(fvccmm_text) "\nReading measurements from disk." purple
	
	LWDAQ_print $info(fvccmm_text) "Reading CMM measurements from [file tail $fn]."
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
		set info(fvccmm_src_$a) [lindex $spheres [expr $a-1]]
	}

	set info(coord_left) [lwdaq bcam_coord_from_mount $info(mount_left)]
	set info(coord_right) [lwdaq bcam_coord_from_mount $info(mount_right)]

	foreach {s side} {L left R right} {
		LWDAQ_print $info(fvccmm_text) \
			"Reading and analyzing image $s\.gif from $side camera."
		set ifn [file join $img_dir $s\.gif]
		if {[file exists $ifn]} {
			LWDAQ_read_image_file $ifn $info(fvccmm_$side)
			set iconfig(analysis_num_spots) "$info(num_sources) $config(bcam_sort)"
			set iconfig(analysis_threshold) $config(bcam_threshold)
			LWDAQ_set_image_sensor $info(image_sensor) BCAM
			set config(bcam_width) [expr $iinfo(daq_image_width) \
				* $iinfo(analysis_pixel_size_um)]
			set config(bcam_height) [expr $iinfo(daq_image_height) \
				* $iinfo(analysis_pixel_size_um)]
			set result [LWDAQ_analysis_BCAM $info(fvccmm_$side)]
			if {![LWDAQ_is_error_result $result]} {
				set info(spots_$side) ""
				foreach {x y num pk acc th} $result {
					append info(spots_$side) "$x $y "
				}
			} else {
				LWDAQ_print $info(fvccmm_text) $result
				set info(state) "Idle"
				return ""
			}
		}
	}

	set err [DFPS_Manager_fvccmm_disagreement]
	LWDAQ_print $info(fvccmm_text) "Current spot position fit error is $err um rms."

	LWDAQ_print $info(fvccmm_text) "Done: measurements loaded and displayed." purple

	set info(state) "Idle"
	return ""
}

#
# DFPS_Manager_fvccmm_displace displaces the camera calibration constants by a
# random amount in proportion to their scaling factors. The routine does not
# print anything to the text window, but if show_fit is set, it does update the
# modelled source positions in the image. We want to be able to use this routine
# repeatedly to move the modelled sources around before starting a new fit,
# while reserving the text window for the fitted end values.
#
proc DFPS_Manager_fvccmm_displace {} {
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
	DFPS_Manager_fvccmm_disagreement
	return ""
} 

#
# DFPS_Manager_fvccmm_defaults restores the cameras to their default, nominal
# calibration constants.
#
proc DFPS_Manager_fvccmm_defaults {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	foreach side {left right} {
		set info(cam_$side) $info(cam_default)
	}
	DFPS_Manager_fvccmm_disagreement
	return ""
} 

#
# DFPS_Manager_fvccmm_altitude is the error function for the fitter. The fitter calls
# this routine with a set of parameter values to get the disgreement, which it
# is attemptint to minimise.
#
proc DFPS_Manager_fvccmm_altitude {params} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	if {$config(fit_stop)} {error "Fit aborted by user"}
	if {![winfo exists $info(window)]} {error "Tool window destroyed"}
	set altitude [DFPS_Manager_fvccmm_disagreement "$params" $config(fit_show)]
	LWDAQ_support
	return $altitude
}

#
# DFPS_Manager_fvccmm_fit gets the camera calibration constants as a starting point
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
proc DFPS_Manager_fvccmm_fit {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set config(fit_stop) 0
	set info(state) "Fitting"
	
	if {$config(verbose)} {
		LWDAQ_print $info(fvccmm_text) "\nFitting camera parameters with settings\
		fit_show = $config(fit_show), fit_details = $config(fit_details)." purple
	}
	set start_time [clock milliseconds]
	if {[catch {
		set scaling "$config(fit_scaling) $config(fit_scaling)"
		set start_params [DFPS_Manager_fvccmm_get_params] 
		set info(coord_left) [lwdaq bcam_coord_from_mount $info(mount_left)]
		set info(coord_right) [lwdaq bcam_coord_from_mount $info(mount_right)]
		lwdaq_config -show_details $config(fit_details) \
			-text_name $info(fvccmm_text) -fsd 3	
		set end_params [lwdaq_simplex $start_params \
			DFPS_Manager_fvccmm_altitude \
			-report $config(fit_show) \
			-steps $config(fit_steps) \
			-restarts $config(fit_restarts) \
			-start_size $config(fit_startsize) \
			-end_size $config(fit_endsize) \
			-scaling $scaling]
		lwdaq_config -show_details 0 -text_name $info(text) -fsd 6
		if {[LWDAQ_is_error_result $end_params]} {error "$end_params"}
		set info(cam_left) "[lrange $end_params 0 7]"
		set info(cam_right) "[lrange $end_params 8 15]"
		LWDAQ_print $info(fvccmm_text) "$end_params"
		if {$config(verbose)} {
			LWDAQ_print $info(fvccmm_text) "Fit converged in\
				[format %.2f [expr 0.001*([clock milliseconds]-$start_time)]] s\
				taking [lindex $end_params 17] steps\
				final error [format %.1f [lindex $end_params 16]] um." purple
		}
	} error_message]} {
		LWDAQ_print $info(fvccmm_text) $error_message
		set info(state) "Idle"
		return ""
	}

	DFPS_Manager_fvccmm_disagreement
	set info(state) "Idle"
}

#
# DFPS_Manager_fvccmm_open opens the Fiber View Camera Calibrator window.
#
proc DFPS_Manager_fvccmm_open {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set w $info(window)\.fvccmm
	if {![winfo exists $w]} {
		toplevel $w
		wm title $w "Fiber View Camera Coordinate Measurement Machine Calibrator,\
			DFPS Manager $info(version)"
	} {
		raise $w
	}
	
	set f [frame $w.controls]
	pack $f -side top -fill x
	
	label $f.state -textvariable DFPS_Manager_info(state) -width 20 -fg blue
	pack $f.state -side left -expand 1
	
	button $f.stop -text "Stop" -command {set DFPS_Manager_config(fit_stop) 1}
	pack $f.stop -side left -expand yes

	foreach a {Read Show Check Displace Defaults Examine Fit} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post DFPS_Manager_fvccmm_$b"
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
		image create photo "fvccmm_$a"
		label $f.$a -image "fvccmm_$a"
		pack $f.$a -side left -expand yes
	}
	
	# Create the text window and direct the lwdaq library routines to print to this
	# window.
	set info(fvccmm_text) [LWDAQ_text_widget $w 120 15]
	LWDAQ_print $info(fvccmm_text) "FVCCMM Text Output\n" purple
	
	# Draw two blank images into the display.
	foreach side {left right} {
		lwdaq_draw $info(fvccmm_$side) fvccmm_$side \
			-intensify $config(fvccmm_intensify) -zoom $config(fvccmm_zoom)
	}
	
	return $w
}

#
# DFPS_Manager_guide_acquire acquires an image from one of the DFPS guide
# sensors with a specified exposure time. It stores the image in LWDAQ image
# array called dfps_manager_n, where n is the guide sensor number. It returns a
# string of information about the image, as obtained from the Camera Instrument.
# If the string is an error message, it will begin with "ERROR:". Otherwise it
# will contain the word "Guide_n" where n is the guide number, followed by the
# left, top, right, and bottom analysis boundaries, the average, stdev, maximum,
# and minimum intensity, and finally the number or rows and the number of
# columns. Multiply the number of rows by the number of columns to get the image
# size in bytes.
#
proc DFPS_Manager_guide_acquire {guide exposure_s} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	upvar #0 LWDAQ_config_Camera iconfig 

	LWDAQ_set_image_sensor $info(image_sensor) Camera
	set iconfig(analysis_manipulation) $info(guide_manipulations)
	set iconfig(daq_ip_addr) $config(ip_addr)
	set iconfig(intensify) $config(intensify) 
	scan $config(guide_daq_$guide) %d%d%d \
		iconfig(daq_driver_socket) \
		iconfig(daq_mux_socket) \
		iconfig(daq_device_element)
	set iconfig(daq_exposure_seconds) $exposure_s
	set camera [LWDAQ_acquire Camera]
	if {![LWDAQ_is_error_result $camera]} {
		lwdaq_image_manipulate $iconfig(memory_name) copy -name dfps_manager_$guide
		lwdaq_draw dfps_manager_$guide dfps_manager_$guide \
			-intensify $config(intensify) -zoom $config(guide_zoom)
		set camera "Guide_$guide [lrange $camera 1 end]"
	}
	return $camera
}

#
# DFPS_Manager_gsrasnik_acquire reads images from all four guide sensors,
# analyzes them with the correct orientation codes, displayes them in the
# GSRasnik window and returns the mask x and y coordinates of the top-left
# corner of the image, as well as the anti-clockwise rotation of the mask image
# with respect to the image sensor. We must specify an orientation of the
# fiducial plate so that we can get the rasnik analysis orientation code
# correct.
#
proc DFPS_Manager_gsrasnik_acquire {orientation} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	upvar #0 LWDAQ_config_Rasnik iconfig 
	upvar #0 LWDAQ_info_Rasnik iinfo

	set info(state) "Acquire"

	set i [lsearch $info(gsrasnik_orientations) $orientation]
	set ocode 0
	set swap 0
	if {$i >= 0} {
		set ocode [lindex $info(gsrasnik_orientation_codes) $i]
		set swap [lindex $info(gsrasnik_swaps) $i]
	}
	
	set iconfig(analysis_orientation_code) $ocode
	LWDAQ_set_image_sensor $info(image_sensor) Rasnik 
	set iconfig(analysis_enable) $config(gsrasnik_algorithm)
	set iconfig(analysis_reference_code) $info(gsrasnik_refcode)
	set iconfig(analysis_square_size_um) $config(gsrasnik_square_um)
	set iinfo(analysis_reference_x_um) $config(gsrasnik_ref_x_um)
	set iinfo(analysis_reference_y_um) $config(gsrasnik_ref_y_um)

	set result ""
	foreach guide $info(guide_sensors) {
		set camera [DFPS_Manager_guide_acquire $guide $config(gsrasnik_flash_s)]
		if {[LWDAQ_is_error_result $camera]} {
			append rasnik " (Guide $guide, Orient $orientation, Time [clock seconds])"
			LWDAQ_print $info(gsrasnik_text) $rasnik
			append result "-1 -1 -1 "
			continue
		}
		set rasnik [LWDAQ_analysis_Rasnik dfps_manager_$guide]
		lwdaq_draw dfps_manager_$guide gsrasnik_$guide \
			-intensify $config(gsrasnik_intensify) -zoom $config(gsrasnik_zoom)
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
			LWDAQ_print $info(gsrasnik_text) $rasnik
			append result "-1 -1 -1 "
		}
	}
	
	set iconfig(analysis_orientation_code) 0
	
	if {$orientation != ""} {set info(gsrasnik_mask_$orientation) $result}
	LWDAQ_print $info(gsrasnik_text) "[format %3d $orientation] $result" green
	set info(state) "Idle"
	return $result
}

#
# DFPS_Manager_gsrasnik_calculate takes the four rasnik measurements we have
# obtained from the four orientations of the mask and calculates the mask origin
# in frame coordiates, the mask rotation with respect to frame coordinates,
# counter-clockwise positive, and the origins of the four guide sensors in frame
# coordinates as well as their rotations counter-clockwise positive with respect
# to frame coordinates.
#
proc DFPS_Manager_gsrasnik_calculate {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	LWDAQ_print $info(gsrasnik_text) "Rasnik Mask Center" purple
	LWDAQ_print $info(gsrasnik_text) "------------------------------------" 
	LWDAQ_print $info(gsrasnik_text) "  O1   O2   GS     X (mm)     Y (mm)" 
	LWDAQ_print $info(gsrasnik_text) "------------------------------------" 
	set sum_x "0.0"
	set sum_y "0.0"
	set sum_sqr_x "0.0"
	set sum_sqr_y "0.0"
	set cnt 0
 	foreach {o1 o2} "0 180 90 270" {
		set m1 $info(gsrasnik_mask_$o1)
		set m2 $info(gsrasnik_mask_$o2)
		foreach gs $info(guide_sensors) {
			set x1 [lindex $m1 [expr ($gs-1)*3+0]]
			set y1 [lindex $m1 [expr ($gs-1)*3+1]]
			set x2 [lindex $m2 [expr ($gs-1)*3+0]]
			set y2 [lindex $m2 [expr ($gs-1)*3+1]]
			set x [expr 0.5*($x1+$x2)]
			set y [expr 0.5*($y1+$y2)]
			LWDAQ_print $info(gsrasnik_text) "[format %4d $o1]\
				[format %4d $o2]\
				[format %4d $gs]\
				[format %10.3f $x]\
				[format %10.3f $y]"
			set sum_x [expr $sum_x + $x]
			set sum_y [expr $sum_y + $y]
			set sum_sqr_x [expr $sum_sqr_x + ($x*$x)]
			set sum_sqr_y [expr $sum_sqr_y + ($y*$y)]
			incr cnt
		}
	}
	LWDAQ_print $info(gsrasnik_text) "------------------------------------" 
	set x_ave [expr $sum_x/$cnt]
	set y_ave [expr $sum_y/$cnt]
	LWDAQ_print $info(gsrasnik_text) "Average       \
		[format %10.3f $x_ave]\
		[format %10.3f $y_ave]"
	set x_stdev [format %.3f [expr sqrt(($sum_sqr_x/$cnt)-($x_ave*$x_ave))]]
	set y_stdev [format %.3f [expr sqrt(($sum_sqr_y/$cnt)-($y_ave*$y_ave))]]
	LWDAQ_print $info(gsrasnik_text) "Stdev         \
		[format %10.3f $x_stdev]\
		[format %10.3f $y_stdev]"
	LWDAQ_print $info(gsrasnik_text) "------------------------------------" 

	set info(plate_rasnik_pose) \
		"[format %10.3f $x_ave]\
		[format %10.3f $y_ave]\
		0.000000\
		0.000000\
		[format %10.6f [expr 0.001*$config(gsrasnik_rot_mrad)]]"
	LWDAQ_print $info(gsrasnik_text) $info(plate_rasnik_pose)

	
	foreach gs $info(guide_sensors) {
		set x [lindex $info(gsrasnik_mask_0) [expr ($gs-1)*3+0]]
		set y [lindex $info(gsrasnik_mask_0) [expr ($gs-1)*3+1]]
		set rot [lindex $info(gsrasnik_mask_0) [expr ($gs-1)*3+2]]
		lwdaq_config -fsd 3
		set gsxyz [lwdaq xyz_local_from_global_point "$x $y 0" $info(plate_rasnik_pose)]
		lwdaq_config -fsd 6
		set info(guide_$gs) "[lindex $gsxyz 0] [lindex $gsxyz 1]\
			[format %.3f [expr -$rot-$config(gsrasnik_rot_mrad)]]"
		LWDAQ_print $info(gsrasnik_text) "Guide $gs\: $info(guide_$gs)"
	}

	return ""
}

#
# DFPS_Manager_gsrasnik_examine displays the rasnik measurements we obtained when acquiring
# from the four orientations.
#
proc DFPS_Manager_gsrasnik_examine {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set w $info(gsrasnik_examine_window)
	if {![winfo exists $w]} {
		toplevel $w
		wm title $w "Guide Sensor Rasnik Measurements, DFPS Calibrator $info(version)"
	} {
		raise $w
		return ""
	}

	foreach orientation $info(gsrasnik_orientations) {
		set f [frame $w.orientation_$orientation]
		pack $f -side top -fill x
		label $f.l -text "Orientation $orientation\:"
		entry $f.e -textvariable DFPS_Manager_info(gsrasnik_mask_$orientation) -width 100
		pack $f.l $f.e -side left -expand yes
	}
		
	foreach guide $info(guide_sensors) {
		set f [frame $w.guide_$guide]
		pack $f -side top -fill x
		label $f.l -text "Guide Sensor $guide\:"
		entry $f.e -textvariable DFPS_Manager_info(guide_$guide) -width 100
		pack $f.l $f.e -side left -expand yes
	}
		
	return ""
}

#
# DFPS_Manager_gsrasnik_open opens the Fiducial Plate Calibrator window.
#
proc DFPS_Manager_gsrasnik_open {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set w $info(window)\.gsrasnik
	if {![winfo exists $w]} {
		toplevel $w
		wm title $w "Guide Sensor Rasnik Calibration, DFPS Manager $info(version)"
	} {
		raise $w
		return ""
	}
	
	set f [frame $w.controls]
	pack $f -side top -fill x
	
	label $f.state -textvariable DFPS_Manager_info(state) -fg blue -width 10
	pack $f.state -side left -expand yes

	foreach a $info(gsrasnik_orientations) {
		button $f.acq$a -text "Acquire $a" -command \
			[list LWDAQ_post "DFPS_Manager_gsrasnik_acquire $a"]
		pack $f.acq$a -side left -expand yes
	}

	foreach a {Calculate Examine} {
		set b [string tolower $a]
		button $f.$b -text "$a" -command [list LWDAQ_post "DFPS_Manager_gsrasnik_$b"]
		pack $f.$b -side left -expand yes
	}
	
	foreach a {Rasnik Camera} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_open $a"
		pack $f.$b -side left -expand 1
	}

	set f [frame $w.options]
	pack $f -side top -fill x
	
	foreach {a wd} {algorithm 2 square_um 4 ref_x_um 5 ref_y_um 5 flash_s 10 \
			rot_mrad 10 height 10 width 10} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable DFPS_Manager_config(gsrasnik_$a) -width $wd
		pack $f.l$a $f.e$a -side left -expand yes
	}

	set f [frame $w.images]
	pack $f -side top -fill x

	foreach guide $info(guide_sensors) {
		image create photo "gsrasnik_$guide"
		label $f.$guide -image "gsrasnik_$guide"
		pack $f.$guide -side left -expand yes
	}
		
	# Create the text window and direct the lwdaq library routines to print to this
	# window.
	set info(gsrasnik_text) [LWDAQ_text_widget $w 100 15]
	LWDAQ_print $info(gsrasnik_text) "GSRasnik Text Output\n" purple
	
	# Draw blank images into the guide sensor displays.
	foreach guide $info(guide_sensors) {
		lwdaq_draw dfps_manager_$guide gsrasnik_$guide \
			-intensify $config(gsrasnik_intensify) -zoom $config(gsrasnik_zoom)
	}
	
	return $w
}

#
# DFPS_Manager_watchdog watches the system commands list for incoming commands.
# It manages the position of fibers by comparing measured positions to target
# positions and adjusting control voltages to minimize disagreement. It monitors
# fiducial fibers and adjusts the fiducial frame pose in fiber view camera
# coordinates.
#
proc DFPS_Manager_watchdog {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	global LWDAQ_server_commands
	set t .serverwindow.text
	
	# Default value for result string.
	set result ""
	
	# At intervals, check mast positions with fiber view cameras and adjust.
	if {$config(check_masts)} {
		if {[clock seconds] - $info(mast_check_time) \
				>= $config(mast_check_period)} {
			set info(mast_check_time) [clock seconds]
			if {$config(verbose)} {
				LWDAQ_print $info(text) "Checking masts. (Time [clock seconds])"
			}
			set result $info(mast_check_time)
		}
	} {
		set info(mast_check_time) "0"
	}
	
	# At intervals, adjust frame coordinate pose in global coordinates using
	# fiducial fiber positions measured by fiber view cameras.
	if {$config(check_fiducials)} {
		if {[clock seconds] - $info(fiducial_check_time) \
				>= $config(fiducial_check_period)} {
			set info(fiducial_check_time) [clock seconds]
			if {$config(verbose)} {
				LWDAQ_print $info(text) "Checking fiducials. (Time [clock seconds])"
			}
			DFPS_Manager_check
			set result $info(fiducial_check_time)
		}
	} {
		set info(fiducial_check_time) "0"
	}

	# Handle incoming server commands.
	if {[llength $LWDAQ_server_commands] > 0} {
		set cmd [lindex $LWDAQ_server_commands 0 0]
		set sock [lindex $LWDAQ_server_commands 0 1]
		set LWDAQ_server_commands [lrange $LWDAQ_server_commands 1 end]
		if {$config(verbose)} {
			LWDAQ_print $info(text) "SERVER: $cmd $sock"
		}
		
		if {[string match "LWDAQ_server_info" $cmd]} {
			append cmd " $sock"
		}
		
		if {[catch {
			set result [uplevel #0 $cmd]
			if {$config(verbose)} {LWDAQ_print $info(text) "SERVER: $result"}
		} error_result]} {
			set result "ERROR: $error_result"
		}		
		
		if {$result != ""} {
			if {[catch {puts $sock $result} sock_error]} {
				LWDAQ_print -nonewline $t "$sock\: " blue
				LWDAQ_print $t "ERROR: $sock_error"
				LWDAQ_socket_close $sock
				LWDAQ_print -nonewline $t "$sock\: " blue
				LWDAQ_print $t "Closed after fatal socket error."
				LWDAQ_print $info(text) "ERROR: $sock_error"
			} {
				if {[string length $result] > 50} {
					LWDAQ_print -nonewline $t "$sock\: " blue
					LWDAQ_print $t "Wrote \"[string range $result 0 49]\...\""
				} {
					LWDAQ_print -nonewline $t "$sock\: " blue
					LWDAQ_print $t "Wrote \"$result\""
				}
			}
		}
	}
	
	LWDAQ_post DFPS_Manager_watchdog
	return $result
}

#
# DFPS_Manager_ffrotate_open opens the Fiducial Fiber Rotation (FFRotate) Calibration
# panel.
#
proc DFPS_Manager_ffrotate_open {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set w $info(window)\.ffrotate
	if {![winfo exists $w]} {
		toplevel $w
		wm title $w "Fidicual Fiber Rotation Calibration, DFPS Manager $info(version)"
	} {
		raise $w
		return ""
	}
	
	set f [frame $w.acquire]

	label $f.state -textvariable DFPS_Manager_info(state) -width 20 -fg blue
	pack $f.state -side left -expand 1
	
	set f [frame $w.text_frame]
	pack $f -side top -fill both -expand yes
	
	set info(ffrotate_text) [LWDAQ_text_widget $f 80 20 1 1]
	LWDAQ_print $info(ffrotate_text) "FFRotate Text Output\n" purple
	
	return $w
}

#
# DFPS_Manager_save_calibration saves the fiber view mounts, camera parameters, fiducial
# positions, guide sensor positions, detector fiber offsets, actuator ranges, and
# actuator maps to disk in the Tools/Settings folder.
#
proc DFPS_Manager_save_calibration {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set f [open $config(calibration_file) w]
	
	foreach orientation $info(gsrasnik_orientations) {
		puts $f "set DFPS_Manager_info(gsrasnik_mask_$orientation)\
			\"$info(gsrasnik_mask_$orientation)\""
	}
		
	foreach guide $info(guide_sensors) {
		puts $f "set DFPS_Manager_info(guide_$guide)\
			\"$info(guide_$guide)\""
	}
	
	close $f
	return ""
}

#
# DFPS_Manager_utilities opens the utilities panel, where we have various options for
# calibrating the DFPS optical components, transmitting commands to fiber controllers,
# and opening LWDAQ instruments.
#
proc DFPS_Manager_utilities {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set w $info(window)\.utilities
	if {![winfo exists $w]} {
		toplevel $w
		wm title $w "Utilities, DFPS Manager $info(version)"
	} {
		raise $w
		return ""
	}
	
	set f [frame $w.calibration]
	pack $f -side top -fill x
	
	label $f.state -textvariable DFPS_Manager_info(state) -width 20 -fg blue
	pack $f.state -side left -expand 1
	
	foreach a {FVCCMM FVCGauge GSRasnik FFRotate} {
		set b [string tolower $a]
		button $f.$b -text $a -command "DFPS_Manager_$b\_open"
		pack $f.$b -side left -expand 1
	}

	set f [frame $w.tools]
	pack $f -side top -fill x

	foreach a {Examine Save_Calibration} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post DFPS_Manager_$b"
		pack $f.$b -side left -expand 1
	}
	
	foreach a {BCAM Diagnostic} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_open $a"
		pack $f.$b -side left -expand 1
	}
	
	button $f.toolmaker -text "Toolmaker" -command "LWDAQ_Toolmaker"
	pack $f.toolmaker -side left -expand 1

	button $f.server -text "Server" -command "LWDAQ_server_open"
	pack $f.server -side left -expand 1

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
	
	set f [frame $w.controls]
	pack $f -side top -fill x
	
	label $f.state -textvariable DFPS_Manager_info(state) -width 20 -fg blue
	pack $f.state -side left -expand 1
	
	foreach a {Check Move Zero Utilities} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post DFPS_Manager_$b"
		pack $f.$b -side left -expand 1
	}
	
	foreach a {Configure Help} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_tool_$b $info(name)"
		pack $f.$b -side left -expand 1
	}
	
	set f [frame $w.fiber]
	pack $f -side top -fill x

	foreach a {ip_addr fvc_left fvc_right injector flash_s transceiver} {
		label $f.l$a -text $a -fg $config(label_color)
		entry $f.e$a -textvariable DFPS_Manager_config($a) \
			-width [expr [string length $config($a)] + 1]
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	set f [frame $w.leds]
	pack $f -side top -fill x

	foreach a {fiducials guides controllers} {
		label $f.l$a -text $a -fg $config(label_color)
		entry $f.e$a -textvariable DFPS_Manager_config($a) -width 12
		pack $f.l$a $f.e$a -side left -expand yes
	}

	foreach d {ns_all ew_all} {
		set a [string tolower $d]
		label $f.l$a -text $d -fg $config(label_color)
		entry $f.e$a -textvariable DFPS_Manager_config($a) -width 5
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	set f [frame $w.dacs]
	pack $f -side top -fill x
	
	foreach a {Calibration} {
		set b [string tolower $a]
		button $f.$b -text $a -command "DFPS_Manager_$b"
		pack $f.$b -side left -expand 1
	}
	
	foreach a {Verbose Check_Masts Check_Fiducials} {
		set b [string tolower $a]
		checkbutton $f.$b -text $a -variable DFPS_Manager_config($b)
		pack $f.$b -side left -expand yes
	}

	set f [frame $w.guide_images]
	pack $f -side top -fill x -expand no
	
	foreach guide $info(guide_sensors) {
		image create photo "dfps_manager_$guide"
		label $f.$guide -image "dfps_manager_$guide"
		pack $f.$guide -side left -expand yes
		lwdaq_draw dfps_manager_$guide dfps_manager_$guide \
			-intensify $config(intensify) -zoom $config(guide_zoom)
	}
		
	set f [frame $w.fvc_images]
	pack $f -side top -fill x -expand no
	
	foreach side {left right} {
		image create photo "dfps_manager_$side"
		label $f.$side -image "dfps_manager_$side"
		pack $f.$side -side left -expand yes
		lwdaq_draw dfps_manager_$side dfps_manager_$side \
			-intensify $config(intensify) -zoom $config(fvc_zoom)	
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

# Specify a guide sensor number and a position in the guide sensor image and
# this routine returns the fiducial coordinates of that position. The result
# will be in millimeters.
DFPS_Manager_guide_to_fc sensor_num sensor_x_mm sensor_y_mm

# Specify a detector fiber and get its position in fiducial coordinates. The
# result will contain the x and y position in millimeters. We choose a detector
# by first specifying a mast (1-4), then a detector (1-2).
DFPS_Manager_detector_get_fc mast_num detector_num

# Specify a detector fiber number and set its position in fiducial coordinates.
# The result will contain the actual x and y position in millimeters following
# the initial movement,
DFPS_Manager_detector_set_fc mast_num detector_num fc_x_mm fc_y_mm

# Get the corners of a detector fiber's range of motion. Returns fiducial
# coordinates of top, right, bottom, and left corners of the forty-five degree
# rotated square that defines the detector fiber's range of motion.
DFPS_Manager_detector_get_range_fc detector_num

# Get the positions of the fiducial fibers. Returns the fiducial coordinates of
# the four fibers top-left, top-right, bottom-left, bottom-right.
DFPS_Manager_fiducial_get_fc

Help coming soon.

Fiber View Camera by Coordinate Measurement Machine Calibrator
==============================================================

The Fiber View Camera by Coordinate Measuring Machine (FVCCMM) Calibration
calculates the calibration constants of the two Fiber View Cameras (FVCs)
mounted on a DFPS base plate. The routine assumes we have Coordinate Measuring
Machine (CMM) measurements of the left FVC mount, the right FVC mount, and four
point sources visible to both cameras. The program takes as input two images
L.gif and R.gif from the left and right FVCs respectively, and CMM.txt from the
CMM.

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