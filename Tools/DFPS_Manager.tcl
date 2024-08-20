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
	
	LWDAQ_tool_init "DFPS_Manager" "2.1"
	if {[winfo exists $info(window)]} {return ""}

	# The control variable tells us the current state of the tool.
	set info(control) "Idle"

	# Data acquisition parameters.
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
	set config(guides) "D1"
	set config(flash) "0.004"
	set config(transceiver) "1 0"
	set config(controllers) "FFFF"
	set config(source_type) "9"
	set config(camera_element) "2"
	set config(source_power) "2"
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
	set config(coord_left) [lwdaq bcam_coord_from_mount $config(mount_left)]
	set config(coord_right) [lwdaq bcam_coord_from_mount $config(mount_right)]

	# Default north-south, and east-west control values.
	set config(ns_all) $config(dac_zero) 
	set config(ew_all) $config(dac_zero) 
	
	# Command transmission values.
	set config(initiate_delay) "0.010"
	set config(spacing_delay) "0.0014"
	set config(byte_processing_time) "0.0002"
	set config(rf_on_op) "0081"
	set config(rf_xmit_op) "82"
	set config(checksum_preload) "1111111111111111"	
	set config(id) "FFFF"
	set config(commands) "8"
	
	# Panel appearance.
	set config(label_color) "green"
	set info(examine_window) "$info(window).examine_window"
	set config(zoom) "0.5"
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
# DFPS_Manager_stop sets the control variable to Stop if it's not Idle, indicating 
# that whatever process is running should stop.
#
proc DFPS_Manager_stop {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	if {$info(control) != "Idle"} {set info(control) "Stop"}
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
	foreach a {Check Move_All Zero_All Configure} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post DFPS_Manager_$b"
		pack $f.$b -side left -expand 1
	}
	foreach a {Stop} {
		set b [string tolower $a]
		button $f.$b -text $a -command "DFPS_Manager_stop"
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
	
	button $f.txcmd -text "Transmit Panel" -command {
		LWDAQ_post "DFPS_Manager_transmit_panel"
	}
	pack $f.txcmd -side left -expand yes
	button $f.calibrator -text "Calibrator" -command "LWDAQ_run_tool DFPS_Calibrator"
	pack $f.calibrator -side left -expand 1
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

http://www.opensourceinstruments.com/DFPS/Development.html

----------End Help----------

----------Begin Data----------

----------End Data----------