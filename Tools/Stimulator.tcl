# Stimulator, a Standard and Polite LWDAQ Tool
#
# Copyright (C) 2014-2023 Kevan Hashemi, Open Source Instruments
#
# Based upon the ISL_Controller Tool.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.

# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.

# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place - Suite 330, Boston, MA  02111-1307, USA.


proc Stimulator_init {} {
	upvar #0 Stimulator_info info
	upvar #0 Stimulator_config config
	global LWDAQ_Info LWDAQ_Driver
	
	LWDAQ_tool_init "Stimulator" "3.1"
	if {[winfo exists $info(window)]} {return ""}
	
	set config(ip_addr) "10.0.0.37"
	set config(driver_socket) "8"
	
	set config(device_rck_khz) "32.768"
	set config(max_pulse_len) [expr (256 * 256) - 1]
	set config(max_interval_len) [expr (256 * 256 * 256) - 1]
	set config(max_stimulus_len) [expr (256 * 256) - 1]
	set config(min_current) "0"
	set config(max_current) "15"
	set config(initiate_delay) "0.010"
	set config(spacing_delay_A2037E) "0.0000"
	set config(spacing_delay_A2071E) "0.0014"
	set config(spacing_delay_cmd) "0.0"
	set config(byte_processing_time) "0.0002"
	set config(rf_on_op) "0081"
	set config(rf_xmit_op) "82"
	set config(checksum_preload) "1111111111111111"
	set config(commands) "255 255 1 5 1 71 0 12 205 0 10 0"
	
	set config(xon_color) "red"
	set config(xtimeout_color) "orange"
	set config(xoff_color) "black"
	set config(son_color) "lightgreen"
	set config(stimeout_color) "orange"
	set config(soff_color) "lightgray"	
	set config(bnone_color) "lightgray"
	set config(bokay_color) "lightgreen"
	set config(blow_color) "orange"
	set config(bempty_color) "red"
	set config(ack_received_color) "black"
	set config(ack_lost_color) "darkorange"
	set config(label_color) "brown"

	set config(blow) "2.5"
	set config(bempty) "2.2"

	set config(ack_enable) "1"
	set info(id_at) "0"
	set info(ack_at) "1"
	set info(batt_at) "2"
	set info(sync_at) "3"
	set config(default_ver) "A3041"
	set config(default_id) "ABCD"
	set config(default_current)	"8"
	set info(op_stim_stop) "0"
	set info(op_stim_start) "1"
	set info(op_xmit) "2"
	set info(op_ack) "3"
	set info(op_battery) "4"
	set info(op_identify) "5"
	set info(op_setpcn) "6"
	set info(ack_stim_stop) "16"
	set info(ack_stim_start) "17"
	set info(ack_xon) "18"
	set info(ack_xoff) "19"
	set info(ack_ack) "20"
	set info(ack_battery) "21"
	set info(ack_identify) "22"
	set info(ack_setpcn) "23"
	
	set info(state) "Idle"
	set info(monitor_interval_ms) "100"
	set info(monitor_ms) "0"
	set info(button_padx) "0"
	
	set info(dev_list) [list]	
	set config(dev_list_file) [file normalize "~/Desktop/DevList.tcl"]

	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 

	return ""   
}

#
# Stimulator_transmit takes a string of command bytes and transmits them through a
# Command Transmitter such as the A3029A. The routine appends a sixteen-bit
# checksum. The checksum is the two bytes necessary to return a sixteen-bit
# linear feedback shift register to all zeros, thus performing a sixteen-bit
# cyclic redundancy check. We assume the destination shift register is preloaded
# with the checksum_preload value. The shift register has taps at locations 16,
# 14, 13, and 11.
#
proc Stimulator_transmit {{commands ""}} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info
	global LWDAQ_Driver
	
	# If we specify no commands, use those in the commands parameter.
	if {$commands == ""} {
		set commands $config(commands)
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
		if {[LWDAQ_hardware_id $sock] == "37"} {
			set sd $config(spacing_delay_A2037E)		
		} {
			set sd $config(spacing_delay_A2071E)
		}
		LWDAQ_set_driver_mux $sock $config(driver_socket) 1
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
		LWDAQ_print $info(text) "ERROR: Transmit failed, [string tolower $error_result]"
		if {[info exists sock]} {LWDAQ_socket_close $sock}
		return ""
	}
	
	# If we get here, we have no reason to believe the transmission failed, although
	# we could have instructed an empty driver socket or the stimulator could have
	# failed to receive the command.
	return ""
}

#
# Stimulator_id_bytes returns a list of two bytes as decimal numbers that represent
# the identifier of the implant.
#
proc Stimulator_id_bytes {n} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	set id [string trim $info(dev$n\_id)]
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
# Stimulator_start_cmd generates a list of bytes to transmit to the device so as
# to select, configure, and stimulate it according to the parameters in the
# Stimulator window. It appends a two-byte checksum, which is necessary for the
# device to accept the command. Each byte is expressed in the return string as a
# decimal number between 0 and 255.
#
proc Stimulator_start_cmd {n} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	# Start by transmitting the two-byte device id, which should be expressed in
	# the ID field by four hex digits. If the id is set to "*" we transmit FFFF 
	# for "select all".
	set commands [Stimulator_id_bytes $n]

	# Append the stimulus start command.
	lappend commands $info(op_stim_start)
	
	# Append the current.
	set current [expr round($info(dev$n\_current))]
	if {$current < $config(min_current)} {set current $config(min_current)}
	if {$current > $config(max_current)} {set current $config(max_current)}
	set info(dev$n\_current) $current
	lappend commands $current
	
	# Append the two bytes of the pulse length, which will prime a 
	# countdown to zero, so we subtract one from the number of RCK
	# periods we want the pulse to last for.
	set len [expr round($config(device_rck_khz) * $info(dev$n\_pulse_ms)) - 1]
	if {$len > $config(max_pulse_len)} {
		set len $config(max_pulse_len)
		LWDAQ_print $info(text) "WARNING: Pulses truncated to\
			[format %.0f [expr 1.0*$len/$config(device_rck_khz)]] ms."
	}
	lappend commands [expr $len / 256] [expr $len % 256]

	# Set the three bytes of the interval length.
	set len [expr round($config(device_rck_khz) * $info(dev$n\_period_ms))]
	if {$len > $config(max_interval_len)} {
		set len $config(max_interval_len)
		LWDAQ_print $info(text) "WARNING: Intervals truncated to\
			[format %.0f [expr 1.0*$len/$config(device_rck_khz)]] ms."
	}
	lappend commands [expr $len / 65536] \
		[expr ($len / 256) % 256] \
		[expr $len % 256]

	# Set the two bytes of the stimulus length, which is the number of intervals.
	set len $info(dev$n\_num_pulses)
	if {$len > $config(max_stimulus_len)} {
		set len $config(max_stimulus_len)
		LWDAQ_print $info(text) "WARNING: Stimulus truncated to $len pulses."
	}
	lappend commands [expr $len / 256] [expr $len % 256]

	# Randomize the pulses, or not.
	if {$info(dev$n\_random)} {
		lappend commands 1
	} {
		lappend commands 0
	}
	
	# Request an acknowledgement. We specify a primary channel number for
	# the acknowledgment to use. The acknowledgement key will contain 
	# information that allows our monitor routine to figure out what 
	# command has been acknowleged.
	if {$config(ack_enable)} {
		lappend commands $info(op_setpcn) $info(dev$n\_pcn)
		lappend commands $info(op_ack) $info(ack_stim_start)
	}
	
	# We return the command string, which does not yet have the checksum
	# attached to the end, but is otherwise a sequence of operation codes
	# and parameter values.
	return $commands
}

#
# Stimulator_start transmits the stimulation commands defined in the tool
# window. It opens a socket to the Command Transmitter, turns on the RF power
# for the initiate delay, which activates all stimulators for command reception,
# transmits all bytes listed in the commands parameter, transmits the correct
# cyclic redundancy checksum for the command bytes, turns off RF power for,
# waits for the termination period, and closes the socket. It calculates the
# stimulus length in microseconds and sets the stimulus end time for the
# selected channel or channels. If we have enabled acknowledgements, we add a
# request for acknowledgement to the start command, and set the timeout value
# for the selected channels.
#
proc Stimulator_start {n} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	# Set the tool state variable.
	if {$info(state) != "Idle"} {return}
	set info(state) "Command"

	# Determine the end-time of a stimulus. We use 0 as a code for "forever".
	# A finite stimulus ends at after the interval length multiplied by the
	# stimulus length, the former being in milliseconds and the latter in 
	# intervals.
	if {$info(dev$n\_num_pulses) == 0} {
		set info(dev$n\_end)  0
	} {
		set info(dev$n\_end) [expr [clock milliseconds] \
			+ $info(dev$n\_period_ms) * $info(dev$n\_num_pulses)]
	}
	
	# Transmit the commands.
	Stimulator_transmit [Stimulator_start_cmd $n]

	# Set state variables.
	LWDAQ_set_bg $info(dev$n\_state) $config(son_color)
	set info(state) "Idle"
	
	return ""
}

#
# The stop procedure transmits a stop command and sets the stimulus end time
# for selected channel to the current time.
#
proc Stimulator_stop {n} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	# Set the tool state variable.
	if {$info(state) != "Idle"} {return}
	set info(state) "Command"

	# Select the device and specify a primary channel number for acknowledgement.
	set commands [Stimulator_id_bytes $n]

	# Send the stimulus stop command, which is just a zero.
	lappend commands $info(op_stim_stop)
	
	# If we want an acknowledgement, specify a primary channel number and
	# request the acknowledgement.
	if {$config(ack_enable)} {
		lappend commands $info(op_setpcn) $info(dev$n\_pcn)
		lappend commands $info(op_ack) $info(ack_stim_stop)
	}
	Stimulator_transmit $commands
	
	# Reset the stimulus end time
	set info(dev$n\_end) 0
	
	# Set state variables.
	LWDAQ_set_bg $info(dev$n\_state) $config(soff_color)
	set info(state) "Idle"
	
	return ""
}

#
# Stimulator_xon turns on data transmission with the specified channel number
# and sample rate for the implant. In ISTs, this will be a synchronizing signal,
# and in stimulator-sensors a sensor signal.
#
proc Stimulator_xon {n} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	# Set the tool state variable.
	if {$info(state) != "Idle"} {return}
	set info(state) "Command"

	# Select the device and specify a primary channel number for transmission.
	set commands [Stimulator_id_bytes $n]
	lappend commands $info(op_setpcn) $info(dev$n\_pcn)

	# Send the Xon command with transmit period. 
	lappend commands $info(op_xmit) \
		[expr round($config(device_rck_khz)*1000/$info(dev$n\_sps))-1]
		
	# We request an acknowledgement.
	if {$config(ack_enable)} {
		lappend commands $info(op_ack) $info(ack_xon)
	}
	
	# Transmit the command.
	Stimulator_transmit $commands

	# Set state variables.
	LWDAQ_set_fg $info(dev$n\_state) $config(xon_color)
	set info(state) "Idle"
	
	return ""
}

#
# Stimulator_xoff turns data transmission.
#
proc Stimulator_xoff {n} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	# Set the tool state variable.
	if {$info(state) != "Idle"} {return}
	set info(state) "Command"

	# Select device and specify primary channel number.
	set commands [Stimulator_id_bytes $n]
	
	# Send the Xoff command, which is a transmit command with zero period.
	lappend commands $info(op_xmit) 0
	
	# If we want an acknowledgement, specify a primary channel number and
	# an acknowledgement key.
	if {$config(ack_enable)} {
		lappend commands $info(op_setpcn) $info(dev$n\_pcn)
		lappend commands $info(op_ack) $info(ack_xoff)
	}
	Stimulator_transmit $commands

	# Set state variables.
	LWDAQ_set_fg $info(dev$n\_state) $config(xoff_color)
	set info(state) "Idle"
	
	return ""
}

#
# Stimulator_battery requests a battery voltage transmission.
#
proc Stimulator_battery {n} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	# Set the tool state variable.
	if {$info(state) != "Idle"} {return}
	set info(state) "Command"

	# Select the device and specify a primary channel number for the
	# battery report to use.
	set commands [Stimulator_id_bytes $n]
	lappend commands $info(op_setpcn) $info(dev$n\_pcn)

	# Send battery measurement request.
	lappend commands $info(op_battery)
	
	# Add acknowledgement request if specified.
	if {$config(ack_enable)} {
		lappend commands $info(op_ack) $info(ack_battery)
	}
	
	# Transmit commands.
	Stimulator_transmit $commands

	# Set state variables.
	set info(state) "Idle"
	
	return ""
}

#
# Stimulator_identify requests a identifying messages from all devices. It uses
# the data acquisition configuration of the first device in our list.
#
proc Stimulator_identify {} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	# We will use the first device's data acquisition configuration
	# as a starting point.
	set n [lindex $info(dev_list) 0]

	# Set the tool state variable.
	if {$info(state) != "Idle"} {return}
	set info(state) "Command"

	# Provide the multicast address.
	set commands "255 255"
	
	# Add the idenfity command.
	lappend commands $info(op_identify)
	
	# Report to user.
	LWDAQ_print $info(text) "Sending identification command."

	# Transmit commands.
	Stimulator_transmit $commands
	
	# Set state variables.
	set info(state) "Idle"
	
	return ""
}

#
# Stimulator_all takes a parameter "action" that it uses to define a procedure
# it will call on every stimulator in the current list, provided that its ID is
# not "*". We introduce a delay after each action to give stimulators a chance 
# to get ready for the next command.
# 
proc Stimulator_all {action} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	foreach n $info(dev_list) {
		if {$info(dev$n\_id) != "*"} {
			Stimulator_$action $n
		}
		LWDAQ_wait_seconds $config(spacing_delay_cmd)
	}

	return ""
}

#
# Clears the status and battery values of an stimulators in the list.
#
proc Stimulator_clear {n} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	LWDAQ_set_bg $info(dev$n\_state) $config(soff_color)
	LWDAQ_set_fg $info(dev$n\_state) $config(xoff_color)
	LWDAQ_set_bg $info(dev$n\_vbat_label) $config(bnone_color)
	set info(dev$n\_battery) "?"	

	return ""
}

#
# A background routine, which keeps posting itself to the Tcl event loop, which
# maintains the colors of the stimulator indicators in the tool window.
#
proc Stimulator_monitor {} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info
	global LWDAQ_info_Receiver 
	upvar #0 Neuroplayer_info ninfo
	upvar #0 Neuroplayer_config nconfig
	global LWDAQ_Info
	
	if {![winfo exists $info(window)]} {return ""}
	if {$LWDAQ_Info(reset)} {return ""}
	set f $info(window).state

	set now_time [clock milliseconds]
	if {$now_time < $info(monitor_ms)} {
		LWDAQ_post Stimulator_monitor
		return ""
	} {
		set info(monitor_ms) [expr $now_time + $info(monitor_interval_ms)]
	}
	
	# Check the stimuli and mark device state label when stimulus is complete.
	foreach n $info(dev_list) {
		set end_time $info(dev$n\_end)
		if {($end_time > 0) && ($end_time <= $now_time)} {
			LWDAQ_set_bg $info(dev$n\_state) $config(soff_color)
		}	
	}
	
	# If the Neuroplayer's auxiliary message list does not exist, we have no
	# hope of finding any auxiliary messages from our stimulators.
	if {![info exists ninfo(aux_messages)]} {
		LWDAQ_post Stimulator_monitor
		return ""
	}
	
	# Go through the Neuroplayer's auxiliary message list and find messages that
	# could be from stimulators. Report them to the text window and delete them
	# from the list so we don't double-report them.
	set new_aux [list]
	foreach n $info(dev_list) {lappend id_list "$n $info(dev$n\_pcn)"}
	foreach am $ninfo(aux_messages) {
		scan $am %d%d%d%d id fa db ts
		if {$fa == $info(ack_at)} {

			# Acknowledgements encode the type of command in their data byte.
			switch $db \
				$info(ack_stim_stop) {set type "stop"} \
				$info(ack_stim_start) {set type "start"} \
				$info(ack_xon) {set type "xon"} \
				$info(ack_xoff) {set type "xoff"} \
				$info(ack_battery) {set type "battery"} \
				$info(ack_identify) {set type "identify"} \
				$info(ack_setpcn) {set type "setpcn"} \
				default {set type $db}
			LWDAQ_print $info(text) "Command Acknowledgement:\
				pcn=$id type=$type time=$ts\."
		} elseif {$fa == $info(batt_at)} {
			
			# Battery measurements may correspond to a stimulator in our
			# list, and if so we want to update its battery measurement. The
			# measurement is identified only by its primary channel number,
			# so we look for the first device entry with a matching id and
			# assume this is the matching device.
			set voltage "?"
			set i [lsearch -index 1 $id_list $id]
			if {$i >= 0} {
				set n [lindex $id_list $i 0]
				
				# We interpret battery measurements in a manner particular to the
				# various supported device versions.
				set ver $info(dev$n\_ver)
				switch $ver {
					"A3041" {
						set voltage [format %.1f [expr 255.0/$db*1.2]]
					}
					default {
						set voltage [format %.1f [expr 255.0/$db*1.2]]
					}
				}
				
				# Set the battery voltage indicator and set its background according
				# to the approximate state of the battery: okay, low, or empty. If
				# we were unable to interpret the battery voltage, we leave it as a
				# question mark.
				set info(dev$n\_battery) $voltage	
				if {$voltage == "?"} {
					LWDAQ_set_bg $info(dev$n\_vbat_label) $config(bnone_color)
				} elseif {$voltage > $config(blow)} {
					LWDAQ_set_bg $info(dev$n\_vbat_label) $config(bokay_color)
				} elseif {$voltage > $config(bempty)} {
					LWDAQ_set_bg $info(dev$n\_vbat_label) $config(blow_color)
				} else {
					LWDAQ_set_bg $info(dev$n\_vbat_label) $config(bempty_color)
				}
			}
		
			# Report the battery measurement.
			LWDAQ_print $info(text) "Battery Measurement:\
				pcn=$id value=$db time=$ts voltage=$voltage." brown
		} elseif {$fa == $info(sync_at)} {
		
			# Report a synchronizing mark.
			LWDAQ_print $info(text) "Synchronizing Mark: pcn=$id time=$ts\."
		} elseif {$fa == $info(id_at)} {
		
			# Report identity broadcast.
			set device_id [format %04X [expr $id +  (256 * $db)]]
			LWDAQ_print $info(text) "Identification Broadcast:\
				device_id=$device_id time=$ts\." green
		} else {
			# Add unrecognised auxiliary message to new list.
			lappend new_aux $am
		}
	}
	set ninfo(aux_messages) $new_aux

	# We post the monitor to the event queue and report success.
	LWDAQ_post Stimulator_monitor
	return ""
}

#
# Stimulator_undraw_list removes the stimulator list from the Stimulator window.
#
proc Stimulator_undraw_list {} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	foreach n $info(dev_list) {
		set ff $info(window).dev_list.dev$n
		catch {destroy $ff}
	}
	
	return ""
}

#
# Stimulator_draw_list draws the current list of stimulators in the 
# Stimulator window.
#
proc Stimulator_draw_list {} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	set f $info(window).dev_list
	if {![winfo exists $f]} {
		frame $f
		pack $f -side top -fill x
	}
	
	set padx $info(button_padx)
	
	foreach n $info(dev_list) {
	
		# If this stimulator's state variable does not exist, then create it
		# now, as well as other system parameters.
		if {![info exists info(dev$n\_ver)]} {
			set info(dev$n\_ver) $config(default_ver)
			set info(dev$n\_id) $config(default_id)
			set info(dev$n\_pulse_ms) "10"
			set info(dev$n\_current) $config(default_current)
			set info(dev$n\_period_ms) "100"
			set info(dev$n\_num_pulses) "10"
			set info(dev$n\_random) "0"
			set info(dev$n\_pcn) [expr 0x$config(default_id) % 256]
			set info(dev$n\_sps) "128"
			set info(dev$n\_battery) "?"
			set info(dev$n\_end) "0"
		}

		set g $f.dev$n
		frame $g -relief sunken -bd 2
		pack $g -side top -fill x

		set ff $g.a
		frame $ff
		pack $ff -side top -fill x
		
		entry $ff.id -textvariable Stimulator_info(dev$n\_id) -width 5
		pack $ff.id -side left -expand 1
		set info(dev$n\_state) $ff.id
		LWDAQ_set_bg $info(dev$n\_state) $config(xoff_color)
		LWDAQ_set_bg $info(dev$n\_state) $config(soff_color)

		foreach {a c} {pulse_ms 5 period_ms 5 num_pulses 5 current 3 ver 6} {
			set b [string tolower $a]
			label $ff.l$b -text "$a\:" -fg $config(label_color)
			entry $ff.$b -textvariable Stimulator_info(dev$n\_$b) -width $c
			pack $ff.l$b $ff.$b -side left -expand 1
		}

		checkbutton $ff.random -text "Random" \
			-variable Stimulator_info(dev$n\_random)
		pack $ff.random -side left -expand yes

		foreach {a c} {Start green Stop black} {
			set b [string tolower $a]
			button $ff.$b -text $a -padx $padx -fg $c -command \
				[list LWDAQ_post "Stimulator_$b $n" front]
			pack $ff.$b -side left -expand 1
		}

		foreach {a c} {pcn 4 sps 4} {
			set b [string tolower $a]
			label $ff.l$b -text "$a\:" -fg $config(label_color)
			entry $ff.$b -textvariable Stimulator_info(dev$n\_$b) -width $c
			pack $ff.l$b $ff.$b -side left -expand 1
		}

		foreach {a c} {Xon green Xoff black Battery green} {
			set b [string tolower $a]
			button $ff.$b -text $a -padx $padx -fg $c -command \
				[list LWDAQ_post "Stimulator_$b $n" front]
			pack $ff.$b -side left -expand 1
		}

		set info(dev$n\_vbat_label) [label $ff.vbat -textvariable \
			Stimulator_info(dev$n\_battery) \
			-width 3 -bg $config(bnone_color) -fg black]
		pack $ff.vbat -side left -expand 1

		button $ff.delete -text "X" -padx $padx -command \
			[list LWDAQ_post "Stimulator_ask_remove $n" front]
		pack $ff.delete -side left -expand yes
	}
	
	return ""
}

#
# Stimulator_ask_remove ask if the user is certain they want to remove an 
# stimulator from the list.
#
proc Stimulator_ask_remove {n} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	# Find the stimulator in our list.
	set index [lsearch $info(dev_list) $n]
	
	# Exit if the stimulator does not exist.
	if {$index < 0} {
		LWDAQ_print $info(text) "ERROR: No stimulator with list index $n."
		return ""
	}
	
	set w $info(window)\.remove$n
	if {[winfo exists $w]} {
		raise $w
		return ""
	}
	toplevel $w
	wm title $w "Remove Device Number $info(dev$n\_id)"
	label $w.q -text "Remove Device Number $info(dev$n\_id)?" \
		-padx 10 -pady 5 -fg purple
	button $w.yes -text "Yes" -padx 10 -pady 5 -command \
		[list LWDAQ_post "Stimulator_remove $n" front]
	button $w.no -text "No" -padx 10 -pady 5 -command \
		[list LWDAQ_post "destroy $w" front]
	pack $w.q $w.yes $w.no -side left -expand yes

	return ""
}

#
# Stimulator_remove remove a stimulator from the list.
#
proc Stimulator_remove {n} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	# Find the stimulator in our list.
	set index [lsearch $info(dev_list) $n]
	
	# If a remove window exists, destroy it
	set w $info(window)\.remove$n
	if {[winfo exists $w]} {destroy $w}

	# Exit if the stimulator does not exist.
	if {$index < 0} {
		LWDAQ_print $info(text) "ERROR: No stimulator with list index $n."
		return ""
	}
	
	# Destroy the device window frame, remove the device from our
	# list, and unset its variables.
	catch {destroy $info(window).dev_list.dev$n}
	set info(dev_list) [lreplace $info(dev_list) $index $index]
	unset info(dev$n\_id)
	unset info(dev$n\_ver)
	unset info(dev$n\_battery)
	unset info(dev$n\_pulse_ms) 
	unset info(dev$n\_period_ms) 
	unset info(dev$n\_current) 
	unset info(dev$n\_num_pulses) 
	unset info(dev$n\_random)
	unset info(dev$n\_pcn) 
	unset info(dev$n\_sps)
	unset info(dev$n\_end)
	
	return ""
}

#
# Stimulator_add_device adds a new stimulator to the list.
#
proc Stimulator_add_device {} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	# Delete the list display.
	Stimulator_undraw_list
	
	# Find a new index for this sensor, add the new id to the list.
	set n 1
	while {[lsearch $info(dev_list) $n] >= 0} {
		incr n
	}
	
	# Add the new sensor index to the list.
	lappend info(dev_list) $n
	
	# Configure the new sensor to default values.
	set info(dev$n\_id) $config(default_id)
	set info(dev$n\_ver) $config(default_ver)
	set info(dev$n\_pulse_ms) "10"
	set info(dev$n\_period_ms) "100"
	set info(dev$n\_num_pulses) "10"
	set info(dev$n\_current) $config(default_current)
	set info(dev$n\_pcn) [expr 0x$config(default_id) % 256]
	set info(dev$n\_sps) "128"
	set info(dev$n\_random) "0"
	set info(dev$n\_end) "0"
	
	set info(dev$n\_battery) "?"
	
	# Re-draw the sensor list.
	Stimulator_draw_list
	
	return ""
}

#
# Stimulator_save_list save a stimulator list to disk.
#
proc Stimulator_save_list {{fn ""}} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info
	
	# Try to get a valid file name.
	if {$fn == ""} {
		set fn [LWDAQ_put_file_name "DevList.tcl"]
		if {$fn == ""} {return ""}
	}

	# Write stimulator list to disk.
	set f [open $fn w]
	puts $f "set Stimulator_info(dev_list) \"$info(dev_list)\""
	foreach p [lsort -dictionary [array names info]] {
		if {[regexp {dev[0-9]+_} $p]} {
			puts $f "set Stimulator_info($p) \"[set info($p)]\"" 
		}
	}
	close $f
	
	# Change the stimulator list file parameter.
	set config(dev_list_file) $fn

	return ""
}

#
# Stimulator_load_list loads a stimulator list from disk. If we don't
# specify the list file name, the routine uses a browser to get a file
# name.
#
proc Stimulator_load_list {{fn ""}} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info
	
	# Try to get a valid file name.
	if {$fn == ""} {
		set fn [LWDAQ_get_file_name]		
		if {$fn == ""} {return ""}
	} else {
		if {![file exists $fn]} {return ""}
	}

	# Undraw the list, run the stimulator list file, and re-draw the list.
	if {[catch {
		Stimulator_undraw_list	
		set info(dev_list) [list]
		uplevel #0 [list source $fn]
		Stimulator_draw_list
		foreach n $info(dev_list) {
			LWDAQ_set_bg $info(dev$n\_state) $config(soff_color)
			LWDAQ_set_fg $info(dev$n\_state) $config(xoff_color)
			set info(dev$n\_battery) "?"
		}
	} error_message]} {
		LWDAQ_print $info(text) "ERROR: $error_message."
		return
	}
	
	# Change the stimulator list file name to match the newly-loaded file.
	set config(dev_list_file) $fn
	
	return ""
}

#
# Stimulator_rename_device changes the device name from
# one value to another, overwriting any pre-existing device of the
# new name, and deleging the device under the old name.
#
proc Stimulator_rename_device {n m} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	set parameters [array name info]
	foreach p $parameters {
		if {[string match "dev$n\_*" $p]} {
			set pp [regsub $n $p $m]
			set info($pp) [set info($p)]
			unset info($p)
		}
	}
	return ""
}

#
# Stimulator_refresh_list assigns ascending, consecutive device numbers to the
# existing rows of the device list. It clears all state indication colors and
# battery values.
#
proc Stimulator_refresh_list {{fn ""}} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info
	
	Stimulator_undraw_list	

	set new_list [list]
	set m 1000
	foreach n $info(dev_list) {
		Stimulator_rename_device $n $m
		lappend new_list "$m $info(dev$m\_id)"
		incr m
	}
	set new_list [lsort -increasing -dictionary -index 1 $new_list]
	
	set info(dev_list) [list]
	set m 1
	foreach dev $new_list {
		set n [lindex $dev 0]
		Stimulator_rename_device $n $m
		set info(dev$m\_battery) "?"
		lappend info(dev_list) $m
		incr m
	}
	unset new_list
	
	Stimulator_draw_list
	
	return ""
}

#
# Stimulator_transmit_panel opens a new window and provides a button for transmitting 
# a string of command bytes, each expressed as a decimal value 0..255, to a
# particular socket on the driver specified in the main window.
#
proc Stimulator_transmit_panel {} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info
	
	# Open the transmit panel.
	set w $info(window)\.xmit_panel
	if {[winfo exists $w]} {
		raise $w
		return ""
	}
	toplevel $w
	wm title $w "Stimulator $info(version) Transmit Command Panel"

	set f [frame $w.tx]
	pack $f -side top -fill x

	button $f.transmit -text "Transmit" -command {
		LWDAQ_post "Stimulator_transmit"
	}
	pack $f.transmit -side left -expand yes
	
	label $f.lcommands -text "Commands:" -fg $config(label_color)
	entry $f.commands -textvariable Stimulator_config(commands) -width 50
	pack $f.lcommands $f.commands -side left -expand yes

	return "" 
}

#
# Opens the tool window and makes all its controls.
#
proc Stimulator_open {} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
	
	set f $w.controls
	frame $f
	pack $f -side top -fill x
	
	label $f.state -textvariable Stimulator_info(state) \
		-width 12 -fg blue
	pack $f.state -side left -expand 1
	
	label $f.laddr -text "ip_addr:" -fg $config(label_color)
	entry $f.eaddr -textvariable Stimulator_config(ip_addr) -width 16
	pack $f.laddr $f.eaddr -side left -expand yes

	label $f.lsckt -text "driver_socket:" -fg $config(label_color)
	entry $f.esckt -textvariable Stimulator_config(driver_socket) -width 4
	pack $f.lsckt $f.esckt -side left -expand yes

	button $f.neuroplayer -text "Neuroplayer" -command {
		LWDAQ_post "LWDAQ_run_tool Neuroplayer"
	}
	pack $f.neuroplayer -side left -expand yes

	button $f.txcmd -text "Transmit Panel" -command {
		LWDAQ_post "Stimulator_transmit_panel"
	}
	pack $f.txcmd -side left -expand yes

	foreach a {Configure Help} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_tool_$b $info(name)"
		pack $f.$b -side left -expand 1
	}
	
	set f $w.list
	frame $f
	pack $f -side top -fill x
	
	foreach {a c} {Start green Stop black Xon green Xoff black Battery green} {
		set b [string tolower $a]
		button $f.$b -text "$a\_All" -fg $c -command [list LWDAQ_post "Stimulator_all $b"]
		pack $f.$b -side left -expand 1
	}
	
	foreach a {Add_Device Save_List Load_List Refresh_List Identify TxCmd} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post Stimulator_$b"
		pack $f.$b -side left -expand 1
	}
	
	if {[llength $info(dev_list)] == 0} {
		Stimulator_add_device
	} else {
		Stimulator_draw_list
	}

	set info(text) [LWDAQ_text_widget $w 80 15]

	# If the device list file exist, load it.
	if {[file exists $config(dev_list_file)]} {
		Stimulator_load_list $config(dev_list_file)
	}
	
	return $w
}

# Start up the tool. We call the monitor routine, which sets the monitor 
# working in the background to maintain the stimulator status 
Stimulator_init
Stimulator_open
Stimulator_monitor

return ""

----------Begin Help----------

http://www.opensourceinstruments.com/Electronics/A3041/Stimulator.html

----------End Help----------

----------Begin Data----------

----------End Data----------