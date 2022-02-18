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
	
	LWDAQ_tool_init "Fiber_Positioner" "1.1"
	if {[winfo exists $info(window)]} {return 0}

	set info(control) "Idle"
	
	set config(image_width) 300
	set config(image_height) 300
	set config(plot_width) 300
	set config(plot_height) 300
	
	set config(dac_min) 0
	set config(dac_zero) 128
	set config(dac_max) 255
	
	set config(dac_ip) "10.0.0.37"
	set config(ns_sock) 1
	set config(n_dac) 1
	set config(s_dac) 2
	set config(ew_sock) 2
	set config(e_dac) 1
	set config(w_dac) 2
	
	set config(offline) 1
		
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 

	return 1   
}

#
# A2057_set_dac sets the output of one digital to analog converter (DAC) on an
# Input-Output Head (A2057). We pass the routine driver address (ip), a driver
# socket number (dsock), a multiplexer socket number (msock), a device element
# number (dac) and an eight-bit value (value). The routine opens a socket,
# selects the Input-Output Head and sends a string of thirty-five commands to to
# set one of its DAC outputs.
#
proc A2057_set_dac {ip dsock msock dac value} {
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
}


proc Fiber_Positioner_move {} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info

	if {$info(control) != "Idle"} {
		LWDAQ_print $info(text) "ERROR: Cannot move while $info(control)."
		return "ERROR"
	}
	set info(control) "Move"
	
	LWDAQ_print $info(text) "The move procedure."
	
	set info(control) "Idle"
	return "SUCCESS"
}

proc Fiber_Positioner_zero {} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info
	
	if {$info(control) != "Idle"} {
		LWDAQ_print $info(text) "ERROR: Cannot zero while $info(control)."
		return "ERROR"
	}
	set info(control) "Zero"

	LWDAQ_print $info(text) "Zeroring all dacs (setting them to $config(dac_zero)."
	A2057_set_dac $config(dac_ip) $config(ns_sock) 1 $config(n_dac) $config(dac_zero)
	A2057_set_dac $config(dac_ip) $config(ns_sock) 1 $config(s_dac) $config(dac_zero)
	A2057_set_dac $config(dac_ip) $config(ew_sock) 1 $config(e_dac) $config(dac_zero)
	A2057_set_dac $config(dac_ip) $config(ew_sock) 1 $config(w_dac) $config(dac_zero)
	
	set info(control) "Idle"
	return "SUCCESS"
}

proc Fiber_Positioner_measure {} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info
	upvar #0 LWDAQ_config_BCAM iconfig
	
	if {$info(control) != "Idle"} {
		LWDAQ_print $info(text) "ERROR: Cannot measure while $info(control)."
		return "ERROR"
	}
	set info(control) "Measure"
	
	set result [LWDAQ_acquire BCAM]
	lwdaq_draw $iconfig(memory_name) $info(photo)
	LWDAQ_print $info(text) $result

	set info(control) "Idle"
	return "SUCCESS"
}


proc Fiber_Positioner_stop {} {
	upvar #0 Fiber_Positioner_config config
	upvar #0 Fiber_Positioner_info info
	
	if {$info(control) == "Idle"} {
		LWDAQ_print $info(text) "ERROR: No need to stop while Idle."
		return "ERROR"
	}
	set info(control) "Stop"
	
	LWDAQ_print $info(text) "The stop procedure."
	
	return "SUCCESS"
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
	foreach a {Move Zero Measure Stop} {
		set b [string tolower $a]
		button $f.$b -text $a -command Fiber_Positioner_$b
		pack $f.$b -side left -expand 1
	}

	foreach a {Help Configure} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_tool_$b $info(name)"
		pack $f.$b -side left -expand 1
	}
	
	set f [frame $w.ns]
	pack $f -side top -fill x
	label $f.ns

	foreach a {dac_ip ns_sock n_dac s_dac ew_sock e_dac w_dac} {
		label $f.l$a -text $a
		entry $f.e$a -textvariable Fiber_Positioner_config($a) \
			-width [expr [string length $config($a)] + 2]
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	set f [frame $w.image_line]
	pack $f -side top -fill x
	
	set f1 [frame $f.image_frame]
	pack $f1 -side left -fill y
	
	set info(photo) [image create photo \
		-width $config(image_width) -height $config(image_height)]
	label $f1.image -image $info(photo) 
	pack $f1.image -side left

	set f2 $f.graph_frame
	frame $f2 
	pack $f2 -side left -fill y
	set info(graph) [image create photo \
		-width $config(plot_width) -height $config(plot_height)]
	label $f2.image -image $info(graph) 
	pack $f2.image -side left

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