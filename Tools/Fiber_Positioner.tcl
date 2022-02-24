# Direct Fiber Positioning System, a LWDAQ Tool
#
# Copyright (C) 2021-2022 Kevan Hashemi, Brandeis University
# Copyright (C) 2021 Kimika Arai, Brandeis University
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


proc Fiber_Positioner_init {} {
	upvar #0 Fiber_Positioner_info info
	upvar #0 Fiber_Positioner_config config
	global LWDAQ_Info LWDAQ_Driver
	
	LWDAQ_tool_init "Fiber_Positioner" "1.4"
	if {[winfo exists $info(window)]} {return 0}

	set info(control) "Idle"
	
	set config(image_width) 700
	set config(image_height) 520
	
	set config(dac_min) 0
	set config(dac_zero) 128
	set config(dac_max) 255
	
	set config(daq_ip_addr) "10.0.0.40"
	
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
		
	set config(fiber_type) "9"
	set config(fiber_sock) "3"
	set config(fiber_element) "A1"
	set config(camera_sock) "4"
	set config(ccd_type) "ICX424"
	set config(flash_seconds) "0.0010"
	set config(num_spots) "1"
	
	set config(n_out) $config(dac_zero) 
	set config(s_out) $config(dac_zero) 
	set config(e_out) $config(dac_zero) 
	set config(w_out) $config(dac_zero) 
	
	set config(n_in) "0"
	set config(s_in) "0"
	set config(e_in) "0"
	set config(w_in) "0"
	
	set config(history) [list]
	set config(trace) "0"
	set config(repeat) "0"
	
	set info(travel_window) "$info(window)\.travel_edit"
	set config(travel_list) "0 0 255 0 255 255 0 255"
	set config(settling_ms) "3000"
	
	set config(offline) 0
		
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

	# Offline for debugging at home.
	if {$config(offline)} {
		LWDAQ_print $info(text) "Set dac $ip $dsock $msock $dac to $value."
		return "ABORT"
	}
	
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

proc Fiber_Positioner_set_nsew {} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info

	A2057_set_out $config(daq_ip_addr) $config(ns_sock) 1 $config(n_out_ch) $config(n_out)
	A2057_set_out $config(daq_ip_addr) $config(ns_sock) 1 $config(s_out_ch) $config(s_out)
	A2057_set_out $config(daq_ip_addr) $config(ew_sock) 1 $config(e_out_ch) $config(e_out)
	A2057_set_out $config(daq_ip_addr) $config(ew_sock) 1 $config(w_out_ch) $config(w_out)
}

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
	LWDAQ_print $info(text) \
		"$config(n_out) $config(e_out) $config(spot_x) $config(spot_y)"
		
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

proc Fiber_Positioner_voltages {} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info
	upvar #0 LWDAQ_config_Voltmeter iconfig
	upvar #0 LWDAQ_info_Voltmeter iinfo
	
	set iconfig(analysis_auto_calib) 1
	set iconfig(daq_no_sleep) 1
	set iconfig(daq_ip_addr) $config(daq_ip_addr)
	
	set iconfig(daq_driver_socket) $config(ns_sock)
	set iconfig(daq_device_element) $config(n_in_ch)
	set result [LWDAQ_acquire Voltmeter]
	set config(n_in) [format %.1f [expr 32.8 * [lindex $result 1]]]
	set iconfig(daq_device_element) $config(s_in_ch)
	set result [LWDAQ_acquire Voltmeter]
	set config(s_in) [format %.1f [expr 32.8 * [lindex $result 1]]]

	set iconfig(daq_driver_socket) $config(ew_sock)
	set iconfig(daq_device_element) $config(e_in_ch)
	set result [LWDAQ_acquire Voltmeter]
	set config(e_in) [format %.1f [expr 32.8 * [lindex $result 1]]]
	set iconfig(daq_device_element) $config(w_in_ch)
	set result [LWDAQ_acquire Voltmeter]
	set config(w_in) [format %.1f [expr 32.8 * [lindex $result 1]]]
}

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
	
	set info(control) "Idle"
	return "SUCCESS"
}

proc Fiber_Positioner_travel {{index 0}} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info
	upvar #0 LWDAQ_config_BCAM iconfig
	upvar #0 LWDAQ_info_BCAM iinfo
	
	if {![winfo exists $info(window)]} {
		return "ABORT"
	}
	set info(control) "Travel"
	
	set n [lindex $config(travel_list) [expr $index * 2]]
	set e [lindex $config(travel_list) [expr ($index * 2) + 1]]
	
	set config(n_out) $n
	set config(s_out) [expr 255 - $n]
	set config(e_out) $e
	set config(w_out) [expr 255 - $e]
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
	
	if {$info(control) == "Stop"} {
		set info(control) "Idle"
		return "ABORT"
	} elseif {[expr ($index + 1) * 2] < [llength $config(travel_list)]} {	
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
		
	set info(control) "Idle"
	return "SUCCESS"
}

proc Fiber_Positioner_check {} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info

	set info(control) "Check"
	
	Fiber_Positioner_voltages	
	Fiber_Positioner_spot_position
	
	set info(control) "Idle"
	return "SUCCESS"
}

#
# Fiber_Positioner_travel_edit displays the travel string, allows us to edit and 
# to save. We cancel by closing the window.
#
proc Fiber_Positioner_travel_edit {} {
	upvar #0 Fiber_Positioner_info info
	upvar #0 Fiber_Positioner_config config
	
	# Create a new top-level text window
	set w $info(travel_window)
	if {[winfo exists $w]} {
		raise $w
		return "SUCCESS"
	} {
		toplevel $w
		wm title $w "Travel Edit Window"
		LWDAQ_text_widget $w 60 20
		LWDAQ_enable_text_undo $w.text	
	}

	# Create the Save button.
	frame $w.f
	pack $w.f -side top
	button $w.f.save -text "Save" -command Fiber_Positioner_travel_save
	pack $w.f.save -side left
	
	# Print the metadata to the text window.
	LWDAQ_print $w.text $config(travel_list)

	return "SUCCESS"
}

#
# Fiber_Positioner_travel_save takes the contents of the travel string
# edit window and saves it to the travel string.
#
proc Fiber_Positioner_travel_save {} {
	upvar #0 Fiber_Positioner_info info
	upvar #0 Fiber_Positioner_config config

	set w $info(travel_window)
	if {[winfo exists $w]} {
		set config(travel_list) [string trim [$w.text get 1.0 end]]
	} {
		LWDAQ_print $info(text) "ERROR: Cannot find travel edit window."
	}
	return $config(travel_list)
}

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

	button $f.etl -text "Edit Travel List" -command Fiber_Positioner_travel_edit
	checkbutton $f.repeat -text "Repeat" -variable Fiber_Positioner_config(repeat) 
	pack $f.etl $f.repeat -side left -expand yes
	checkbutton $f.trace -text "Trace" -variable Fiber_Positioner_config(trace)
	pack $f.trace -side left -expand yes
	
	set f [frame $w.image_frame]
	pack $f -side top -fill x
	
	set info(photo) [image create photo -width 700 -height 520]
	label $f.image -image $info(photo) 
	pack $f.image -side left -expand yes

	set info(text) [LWDAQ_text_widget $w 100 15]

	LWDAQ_print $info(text) "$info(name) Version $info(version) \n"
	
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