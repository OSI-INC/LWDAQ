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

#
# Stimulator_init initializes the Stimulator Tool.
#
proc Stimulator_init {} {
	upvar #0 Stimulator_info info
	upvar #0 Stimulator_config config
	global LWDAQ_Info LWDAQ_Driver
	
	LWDAQ_tool_init "Stimulator" "3.8"
	if {[winfo exists $info(window)]} {return ""}
	
	set config(ip_addr) "10.0.0.37"
	set config(driver_socket) "8"
	
	set config(rck_khz) "32.768"
	set config(rck_divisor) "32"
	set config(max_pulse_len) [expr (256 * 256) - 1]
	set config(min_pulse_len) "2"
	set config(max_interval_len) [expr (256 * 256) - 1]
	set config(min_interval_len) "2"
	set config(max_stimulus_len) [expr (256 * 256) - 1]
	set config(min_current) "0"
	set config(max_current) "15"
	set config(initiate_delay) "0.010"
	set config(spacing_delay_A2037E) "0.0000"
	set config(spacing_delay_A2071E) "0.0014"
	set config(spacing_delay_cmd) "0.0"
	set config(byte_processing_time) "0.0002"
	set config(rf_off_op) "0080"
	set config(rf_on_op) "0081"
	set config(rf_xmit_op) "82"
	set config(checksum_preload) "1111111111111111"
	
	set config(xon_color) "red"
	set config(xtimeout_color) "orange"
	set config(xoff_color) "black"
	set config(son_color) "lightgreen"
	set config(stimeout_color) "orange"
	set config(soff_color) "lightgray"	
	set config(ack_received_color) "black"
	set config(ack_lost_color) "darkorange"
	set config(label_color) "brown"
	
	set config(verbose) "1"
	set config(aux_show) "0"
	set config(aux_color) "orange"
	set info(time_format) {%d-%b-%Y %H:%M:%S}
	
	set info(transmit_ms) 0
	set config(default_id) "1234"
	set config(multicast_id) "FFFF"
	set config(max_tx_sps) "1024"
	
	set config(pulse_ms) "10"
	set config(period_ms) "100"
	set config(num_pulses) "10"
	set config(current) "8"
	set config(sps) "512"
	set config(random) "0"
	
	# Transmit Panel Parameters
	set config(tp_id) "FFFF"
	set config(tp_commands) "6 3 2 255"
	set config(tp_program) "~/Desktop/UProg.asm"
	set config(tp_base_addr) "0x0800"
	set config(tp_seg_len) "30"
	set info(tp_ew) $info(window).tpew
	set info(tp_text) $info(tp_ew).text
	
	# Auxiliary message types.
	set info(at_id) "1"
	set info(at_ack) "2"
	set info(at_batt) "3"
	set info(at_conf) "4"
	set info(at_ver) "5"
	
	# Stimulator operation codes, which we use to construct instructions, which
	# we in turn combine to form commands.
	set info(op_stop) "0"
	set info(op_start) "1"
	set info(op_xon) "2"
	set info(op_xoff) "3"
	set info(op_batt) "4"
	set info(op_id) "5"
	set info(op_pgld) "6"
	set info(op_pgon) "7"
	set info(op_pgoff) "8"
	set info(op_pgrst) "9"
	set info(op_shdn) "10"
	set info(op_ver) "11"
	
	set info(state) "Idle"
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
# Stimulator_transmit takes a device identifier and a list of command bytes and
# transmits them through a Command Transmitter such as the A3029A. The device
# identifier must be a four-digit hex value. The bytes must be decimal values
# 0..255. The routine appends a sixteen-bit checksum. The checksum is the two
# bytes necessary to return a sixteen-bit linear feedback shift register to all
# zeros, thus performing a sixteen-bit cyclic redundancy check. We assume the
# destination shift register is preloaded with the checksum_preload value. The
# shift register has taps at locations 16, 14, 13, and 11. When the verbose flag
# is set, the routine prints the identifier, the commands, and the checksum at
# the end. The identifier and checksum are given as four-digit hex strings. The
# other bytes are decimal numbers 0..255.
#
proc Stimulator_transmit {id commands} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info
	global LWDAQ_Driver
	
	# Take the four-digit hex code for an identifier, or a wild card character,
	# and returns two decimal numbers giving the decimal values of the two bytes
	# that make up either the specific identifier or the wild card identifier.
	set id [string trim $id]
	if {$id == "*"} {set id $config(multicast_id)}
	if {[regexp {([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})} $id match b1 b2]} {
		set commands "[expr 0x$b1] [expr 0x$b2] $commands"
	} else {
		LWDAQ_print $info(text) "ERROR: Bad device identifier \"$id\", using 0x000."
		set id "0000"
		set commands "0 0 $commands"
	}
	
	# Print the commands to the text window.
	if {$config(verbose)} {
		LWDAQ_print -nonewline $info(text) "Transmit: "
		LWDAQ_print -nonewline $info(text) "0x[format %4s $id] " green
		LWDAQ_print -nonewline $info(text) $commands
	}
	
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
	if {$config(verbose)} {
		LWDAQ_print $info(text) " 0x[format %04X [expr $d22*255+$d21]]"
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
		LWDAQ_transmit_command_hex $sock $config(rf_off_op)
		LWDAQ_delay_seconds $sock $sd
		set counter 0
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
	set info(transmit_ms) [clock milliseconds]
	return ""
}

#
# Stimulator_id takes either a device list index or a four-digit hexadecimal
# value and returns a four-digit hexadecimal value. If first looks to see if
# the value it is passed is an element in the device list. If so, it returns
# the identifier of this device. If not, it checks to see if the value is
# a four-digit hex string, and if so returns the value. Otherwise, it returns
# the value 0001 and prints a warning to the stimulator window.
#
proc Stimulator_id {n} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	if {[lsearch $info(dev_list) $n] >= 0} {
		return $info(dev$n\_id)
	} elseif {[regexp {[0-9A-Fa-f]{4}} $n]} {
		return $n
	} else {
		LWDAQ_print $info(text) "WARNING: Invalid device identifier \"$n\"."
		return "0001"
	}
}

#
# Stimulator_start transmits the stimulation commands defined in the tool
# window to a specific device. We can identify the device either by its
# list index or by its identifier.
#
proc Stimulator_start {n} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	# Set the tool state variable.
	if {$info(state) != "Idle"} {return}
	set info(state) "Start"

	# Begin command with a battery measurement and verstion number check, 
	# then begin the start instruction.
	set commands [list $info(op_batt) $info(op_ver) $info(op_start)]
	
	# Append the current.
	set current [expr round($config(current))]
	if {$current < $config(min_current)} {set current $config(min_current)}
	if {$current > $config(max_current)} {set current $config(max_current)}
	set config(current) $current
	lappend commands $current
	
	# Append the two bytes of the pulse length.
	set len [expr round($config(rck_khz) / $config(rck_divisor) * $config(pulse_ms)) - 1]
	if {$len > $config(max_pulse_len)} {
		set len $config(max_pulse_len)
		set len_ms [expr 1.0*$len/$config(rck_khz)*$config(rck_divisor)]
		LWDAQ_print $info(text) "WARNING: Pulses truncated to\
			[format %.0f $len_ms]  ms."
	} elseif {$len < $config(min_pulse_len)} {
		set len $config(min_pulse_len)
		set len_ms [expr 1.0*$len/$config(rck_khz)*$config(rck_divisor)]
		LWDAQ_print $info(text) "WARNING: Pulses lengthened to\
			[format %.0f $len_ms]  ms."
	}
	lappend commands [expr $len / 256] [expr $len % 256]

	# Set the two bytes of the interval length.
	set len [expr round($config(rck_khz) / $config(rck_divisor) * $config(period_ms))]
	if {$len > $config(max_interval_len)} {
		set len $config(max_interval_len)
		set len_ms [expr 1.0*$len/$config(rck_khz)*$config(rck_divisor)]
		LWDAQ_print $info(text) "WARNING: Intervals truncated to\
			[format %.0f $len_ms] ms."
	} elseif {$len < $config(min_interval_len)} {
		set len $config(min_interval_len)
		set len_ms [expr 1.0*$len/$config(rck_khz)*$config(rck_divisor)]
		LWDAQ_print $info(text) "WARNING: Intervals lengthened to\
			[format %.0f $len_ms]  ms."
	}
	lappend commands [expr $len / 256] [expr $len % 256]

	# Set the two bytes of the stimulus length, which is the number of intervals.
	set len $config(num_pulses)
	if {$len > $config(max_stimulus_len)} {
		set len $config(max_stimulus_len)
		LWDAQ_print $info(text) "WARNING: Stimulus truncated to $len pulses."
	}
	lappend commands [expr $len / 256] [expr $len % 256]

	# Randomize the pulses, or not.
	if {$config(random)} {lappend commands 1} {lappend commands 0}
	
	# Transmit the commands.
	Stimulator_transmit [Stimulator_id $n] $commands

	# Set state variables.
	set info(state) "Idle"
	
	return ""
}

#
# Stimulator_stop transmits a stop command and sets the stimulus end time
# for selected channel to the current time.
#
proc Stimulator_stop {n} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	# Set the tool state variable.
	if {$info(state) != "Idle"} {return}
	set info(state) "Stop"

	# Measure battery voltage, check version, and stop stimulus.
	set commands [list $info(op_batt) $info(op_ver) $info(op_stop)]
	
	# Transmit the commands.
	Stimulator_transmit [Stimulator_id $n] $commands
	
	# Set state variables.
	set info(state) "Idle"
	
	return ""
}

#
# Stimulator_xon turns on data transmission with a specific telemetry channel
# number and sample rate. In ISTs, this will be a synchronizing signal.
#
proc Stimulator_xon {n} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	# Set the tool state variable.
	if {$info(state) != "Idle"} {return}
	set info(state) "Xon"

	# Start our command with battery measurement and version request
	# instructions.
	set commands [list $info(op_batt) $info(op_ver)]

	# Send the Xon command with transmit period. 	
	if {$config(sps) > $config(max_tx_sps)} {
		LWDAQ_print $info(text) "ERROR: Requested frequency $config(sps) SPS\
			is greater than maximum $config(max_tx_sps) SPS."
		set info(state) "Idle"
		return ""
	}
	set tx_p [expr round($config(rck_khz)*1000/$config(sps))-1]
	
	# Add the XON instruction.
	lappend commands $info(op_xon) $info(dev$n\_channel) $tx_p
		
	# Transmit the command.
	Stimulator_transmit [Stimulator_id $n] $commands

	# Set state variables.
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
	set info(state) "Xoff"

	# Send the Xoff command, which is a transmit command with zero period.
	# Before stopping transmission, measure battery voltage and check version
	# number.
	set commands [list $info(op_batt) $info(op_ver) $info(op_xoff)]
	
	# Transmit the commands.
	Stimulator_transmit [Stimulator_id $n] $commands

	# Set state variables.
	set info(state) "Idle"
	
	return ""
}

#
# Stimulator_identify requests a identifying messages from all devices. It uses
# the data acquisition configuration of the first device in our list, but applies
# the multicast identifier to reach all devices.
#
proc Stimulator_identify {} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	# We will use the first device's data acquisition configuration
	# as a starting point.
	set n [lindex $info(dev_list) 0]

	# Set the tool state variable.
	if {$info(state) != "Idle"} {return}
	set info(state) "Identify"

	# Add the idenfity command.
	set commands [list $info(op_id)]
	
	# Report to user.
	LWDAQ_print $info(text) "Sending identification command."

	# Transmit commands to multicast address.
	Stimulator_transmit $config(multicast_id) $commands
	
	# Set state variable.
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
# Stimulator_clear clears the status and battery values of an stimulators in the list.
#
proc Stimulator_clear {n} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	LWDAQ_set_bg $info(dev$n\_state) $config(soff_color)
	LWDAQ_set_fg $info(dev$n\_state) $config(xoff_color)
	set info(dev$n\_battery) "?"	

	return ""
}

#
# Stimulator_monitor captures auxiliary messages from stimulators and keeps track
# of when stimuli end, so it can change the state label colors. The routine looks
# for auxiliary messages first in the Neuroplayer Tool, if one exists, and second
# in the Receiver Instrument.
#
proc Stimulator_monitor {} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info
	upvar #0 LWDAQ_info_Receiver rinfo
	upvar #0 Neuroplayer_info ninfo
	upvar #0 Neuroplayer_config nconfig
	global LWDAQ_Info
	
	if {![winfo exists $info(window)]} {return ""}
	if {$LWDAQ_Info(reset)} {return ""}
	set f $info(window).state

	# Note the time for stimulation tracking.
	set now_ms [clock milliseconds]
	
	# Look for auxiliary message lists. If we find one, copy and clear the
	# list.
	set aux_messages ""
	if {[info exists ninfo(aux_messages)]} {
		set aux_messages $ninfo(aux_messages)
		set ninfo(aux_messages) ""
		set now_time \($ninfo(datetime_play_time)\)
	} elseif {[info exists rinfo(aux_messages)]} {
		set aux_messages $rinfo(aux_messages)
		set rinfo(aux_messages) ""
		set now_time \([clock format [clock seconds] -format $info(time_format)]\)
	}
	
	# If we have no auxiliary messages, we are done.
	if {[llength $aux_messages] == 0} { 
		LWDAQ_post Stimulator_monitor
		return ""
	}
	
	# Compose a list of device numbers with their sixteen-bit identifiers.
	set id_list ""
	foreach n $info(dev_list) {lappend id_list "$n $info(dev$n\_id)"}
	
	# Go through the auxiliary message list and find messages that could be from
	# stimulators.
	foreach am $aux_messages {
	
		# Scan the auxiliary message for identifier, field address, data byte
		# and timestamp. The timestamp is a sixteen-bit positive integer that
		# counts 32.768 kHz clock ticks.
		scan $am %d%d%d%d id fa db ts
		if {$config(aux_show)} {
			LWDAQ_print $info(text) "Auxiliary Message:\
				id=$id fa=$fa db=$db ts=$ts" $config(aux_color)
		}
		
		# If this is a confirmation message, proceed to next auxiliary message.
		if {$fa == $info(at_conf)} {continue}

		# If it is some other sort of message, look for a confirmation. If we 
		# don't find one, proceed to next auxiliary message. If we do find
		# one, use it to obtain the full device identifier.
		set device_id "0"
		foreach cam $aux_messages {
			scan $cam %d%d%d%d cid cfa cdb cts
			if {$cfa != $info(at_conf)} {continue}
			if {($cid == $id) && (($cts - $ts) % 65536 <= 1)} {
				set device_id [format %04X [expr $cid + (256 * $cdb)]]
				break
			}
		}
		if {$device_id == "0"} {continue}
		
		# Look for the device in our list. If we find it, set n to the device
		# number, otherwise set n to zero.
		set i [lsearch -index 1 $id_list $device_id]
		if {$i >= 0} {set n [lindex $id_list $i 0]} else {set n 0}

		# Check the auxiliary message type, now that it has been confirmed.
		if {$fa == $info(at_ack)} {
			
			# Acknowledgements confirm that a device has received a command. We 
			# ignore acknowledgements from devices that are not in our list.
			if {$n == 0} {continue}
			
			# Acknowledgements encode the type of command in their data byte.
			switch $db \
				$info(op_stop) {
					set type "stop"
					LWDAQ_set_bg $info(dev$n\_state) $config(soff_color)
				} \
				$info(op_start) {
					set type "start"
					LWDAQ_set_bg $info(dev$n\_state) $config(son_color)
				} \
				$info(op_xon) {
					set type "xon"
					LWDAQ_set_fg $info(dev$n\_state) $config(xon_color)
				} \
				$info(op_xoff) {
					set type "xoff"
					LWDAQ_set_fg $info(dev$n\_state) $config(xoff_color)
				} \
				$info(op_batt) {
					set type "battery"
				} \
				$info(op_pgld) {
					set type "pgld"
				} \
				$info(op_pgon) {
					set type "pgon"
				} \
				$info(op_pgoff) {
					set type "pgoff"
				} \
				$info(op_pgrst) {
					set type "pgrst"
				} \
				$info(op_shdn) {
					set type "shdn"
					LWDAQ_set_bg $info(dev$n\_state) $config(soff_color)
					LWDAQ_set_fg $info(dev$n\_state) $config(xoff_color)
				} \
				default {
					set type "invalid"
				}
				
			if {($type != "invalid") && $config(verbose)} {
				LWDAQ_print $info(text) "Acknowledge:\
					device_id=$device_id type=$type ts=$ts $now_time"
			}
		} elseif {$fa == $info(at_batt)} {
			
			# Ignore battery measurements from devices that are not in our list.
			if {$n == 0} {continue}
			
			# We interpret battery measurements in a manner particular to the
			# various supported device versions.
			set ver $info(dev$n\_version)
			switch $ver {
				"21" {set voltage [format %.1f [expr 255.0/$db*1.2]]}
				default {set voltage [format %.1f [expr 255.0/$db*1.2]]}
			}
			
			# Report the battery measurement.
			set info(dev$n\_battery) $voltage
			if {$config(verbose)} {
				LWDAQ_print $info(text) "Battery:\
					device_id=$device_id value=$db ts=$ts\
					voltage=$voltage $now_time" 
			}
		} elseif {$fa == $info(at_id)} {
			if {$config(verbose)} {
				LWDAQ_print $info(text) "Identification:\
					device_id=$device_id ts=$ts $now_time" green
			}
		} elseif {$fa == $info(at_ver)} {
			set info(dev$n\_version) "$db"
			if {$config(verbose)} {
				LWDAQ_print $info(text) "Version:\
					device_id=$device_id value=$db ts=$ts $now_time"
			}
		} else {
			
			# We don't recognise this type of auxiliary message, so proceed.
			continue
		}
	}
	
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
		if {![info exists info(dev$n\_id)]} {
			set info(dev$n\_id) $config(default_id)
			set info(dev$n\_channel) [expr 0x$config(default_id) % 256]
			set info(dev$n\_version) "?"
			set info(dev$n\_battery) "?"
		}

		set ff $f.dev$n
		frame $ff -relief sunken -bd 2
		pack $ff -side top -fill x
		
		entry $ff.id -textvariable Stimulator_info(dev$n\_id) -width 5
		pack $ff.id -side left -expand 1
		set info(dev$n\_state) $ff.id
		LWDAQ_set_bg $info(dev$n\_state) $config(xoff_color)
		LWDAQ_set_bg $info(dev$n\_state) $config(soff_color)
		
		foreach {a c} {Start green Stop black} {
			set b [string tolower $a]
			button $ff.$b -text $a -padx $padx -fg $c -command \
				[list LWDAQ_post "Stimulator_$b $n" front]
			pack $ff.$b -side left -expand 1
		}

		foreach {a c} {Xon green Xoff black} {
			set b [string tolower $a]
			button $ff.$b -text $a -padx $padx -fg $c -command \
				[list LWDAQ_post "Stimulator_$b $n" front]
			pack $ff.$b -side left -expand 1
		}

		foreach {a c} {channel 3 version 3} {
			label $ff.l$a -text "$a\:" -fg $config(label_color)
			entry $ff.$a -textvariable Stimulator_info(dev$n\_$a) -width $c
			pack $ff.l$a $ff.$a -side left -expand 1
		}

		foreach {a c} {battery 3} {
			label $ff.l$a -text "$a\:" -fg $config(label_color)
			label $ff.$a -textvariable Stimulator_info(dev$n\_$a) -width $c
			pack $ff.l$a $ff.$a -side left -expand 1
		}

		button $ff.delete -text "X" -padx $padx -command \
			[list LWDAQ_post "Stimulator_ask_remove $n" front]
		pack $ff.delete -side left -expand 1
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
		LWDAQ_print $info(text) "ERROR: No stimulator with list index $n\."
		return ""
	}
	
	set w $info(window)\.remove$n
	if {[winfo exists $w]} {
		raise $w
		return ""
	}
	toplevel $w
	wm title $w "Remove $info(dev$n\_id), Index $n?"
	label $w.q -text "Remove $info(dev$n\_id), Index $n?" \
		-padx 10 -pady 5 -fg purple
	button $w.yes -text "Yes" -padx 10 -pady 5 -command \
		[list LWDAQ_post "Stimulator_remove $n" front]
	button $w.no -text "No" -padx 10 -pady 5 -command \
		[list LWDAQ_post "destroy $w" front]
	pack $w.q $w.yes $w.no -side left -expand 1

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
		LWDAQ_print $info(text) "ERROR: No stimulator with list index $n\."
		return ""
	}
	
	# Destroy the device window frame, remove the device from our
	# list, and unset its variables.
	catch {destroy $info(window).dev_list.dev$n}
	set info(dev_list) [lreplace $info(dev_list) $index $index]
	unset info(dev$n\_id)
	unset info(dev$n\_version)
	unset info(dev$n\_battery)
	unset info(dev$n\_channel) 
	
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
	set info(dev$n\_channel) [expr 0x$config(default_id) % 256]
	set info(dev$n\_version) "?"
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
	foreach n $info(dev_list) {
		foreach p {id channel version} {
			set e "dev$n\_$p"
			puts $f "set Stimulator_info($e) \"[set info($e)]\"" 
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
		LWDAQ_print $info(text) "ERROR: $error_message\."
		return
	}
	
	# Change the stimulator list file name to match the newly-loaded file.
	set config(dev_list_file) $fn
	
	return ""
}

#
# Stimulator_rename_device changes the device name from one value to another,
# overwriting any pre-existing device of the new name, and deleging the device
# under the old name.
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
	set new_list [lsort -increasing -index 1 $new_list]
	
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
# Stimulator_transmit_panel opens a new window that allows the user to transmit
# specific commands to a particular device, to assemble and upload user
# programs, and enable user programs. The transmit panel uses the driver address
# and socket specified in the Stimulator window, but it uses its own device
# identifier, which can be set to the wild card FFFF or a specific four-digit
# hex identifier. Command bytes can be specified either as a two-digit hex value
# using the 0x prefix, or a decimal value 0..255 with no prefix. User programs
# are read from a file. The transmit panel loads the OSR8 assembler package and
# uses it to generate the machine code bytes that it will upload to the
# stimulator.
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
	wm title $w "Stimulator $info(version) Transmit Panel"
	
	# If the OSR8 Assembler tool routines are not available, run the OSR8 Assembler
	# tool with no graphics.
	if {[info commands OSR8_Assembler_*] == ""} {
		upvar #0 OSR8_Assembler_info ainfo
		LWDAQ_run_tool OSR8_Assembler
		destroy $ainfo(window)
		if {[info commands OSR8_Assembler_assemble] == ""} {
			LWDAQ_print $info(text) "ERROR: Failed to open OSR8 Assembler tool."
		} 
	}

	set f [frame $w.controls]
	pack $f -side top -fill x
	
	label $f.nl -text "Target Identifier (Hex):"
	entry $f.ne -textvariable Stimulator_config(tp_id) -width 5
	pack $f.nl $f.ne -side left -expand 1

	foreach a {Run Halt} {
		set b [string tolower $a]
		button $f.$b -text "$a Program" -command "LWDAQ_post Stimulator_tp_$b"
		pack $f.$b -side left -expand 1
	}

	label $f.bl -text "Base Address:"
	entry $f.be -textvariable Stimulator_config(tp_base_addr) -width 8
	pack $f.bl $f.be -side left -expand 1

	checkbutton $f.verbose -variable Stimulator_config(verbose) -text "Verbose"
	pack $f.verbose -side left -expand 1
	
	set f [frame $w.program]
	pack $f -side top -fill x
	
	label $f.lprogram -text "Program:" -fg $config(label_color)
	entry $f.eprogram -textvariable Stimulator_config(tp_program) -width 60
	pack $f.lprogram $f.eprogram -side left -expand 1

	foreach a {Browse Edit} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post Stimulator_tp_$b"
		pack $f.$b -side left -expand 1
	}

	set f [frame $w.commands]
	pack $f -side top -fill x

	label $f.lcommands -text "Commands:" -fg $config(label_color)
	entry $f.commands -textvariable Stimulator_config(tp_commands) -width 70
	pack $f.lcommands $f.commands -side left -expand 1

	button $f.transmit -text "Transmit" \
		-command "LWDAQ_post Stimulator_tp_transmit"
	pack $f.transmit -side left -expand 1
		
	set info(tp_text) [LWDAQ_text_widget $w 80 15]

	return "" 
}

#
# Stimulator_tp_browse opens a file browser to select the program file.
#
proc Stimulator_tp_browse {} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	set fn [LWDAQ_get_file_name]
	if {$fn != ""} {set config(tp_program) $fn}
	return ""
}


#
# Stimulator_tp_edit opens the assembler program in an editor window.
#
proc Stimulator_tp_edit {} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	if {[winfo exists $info(tp_ew)]} {
		raise $info(tp_ew)
	} else {
		set info(tp_ew) [LWDAQ_edit_script Open $config(tp_program)]
	}
	return $info(tp_ew)
}

#
# Stimulator_tp_transmit transmits the commands listed in the transmit
# panel.
#
proc Stimulator_tp_transmit {} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	# Append all the commands in the transmit list, converting hex values
	# to decimal values as we go.
	set commands [list]
	foreach cmd $config(tp_commands) {lappend commands [expr $cmd]}
	
	# Transmit the commands. We don't ask for an acknowledgement because
	# we want the transmit to consist only of commands entered by the user.
	Stimulator_transmit $config(tp_id) $commands
}

#
# Stimulator_tp_run assembles and uploads user code in chunks. After the final
# chunk, it enables the program. If acknowledgements are enabled, the routine
# asks for an acknowledgement for every chunk.
#
proc Stimulator_tp_run {} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info
	upvar #0 OSR8_Assembler_config aconfig
	upvar #0 OSR8_Assembler_info ainfo
	
	# Read program from file.
	if {[file exists $config(tp_program)]} {
		LWDAQ_print $info(tp_text) "Reading and assembling $config(tp_program)."
		set f [open $config(tp_program)]
		set program [read $f]
		close $f
	} else {
		LWDAQ_print $info(tp_text) "ERROR: Cannot find \"$config(tp_program)\"."
		return ""
	} 
	
	# Assemble program, reporting errors to text window.
	if {[catch {
		set saved_text $ainfo(text)
		if {$config(verbose)} {set ainfo(text) $info(tp_text)}
		set aconfig(hex_output) 0
		set aconfig(ofn_write) 0
		set aconfig(base_addr) $config(tp_base_addr)
		set prog [OSR8_Assembler_assemble $program]
		set ainfo(text) $saved_text
	} error_message]} {
		LWDAQ_print $info(tp_text) "ERROR: $error_message\."
		return ""
	}
	LWDAQ_print $info(tp_text) "Assembly successful,\
		uploading [llength $prog] code bytes."	
	
	# Get device number and initialize command list. Before we send the
	# first byte of our program, we want to make sure the user program
	# pointer in the IST is reset.
	set commands [list $info(op_pgrst)]

	while {[llength $prog] > 0} {
		
		# Extract first few bytes.
		set segment [lrange $prog 0 [expr $config(tp_seg_len)-1]]
		set prog [lrange $prog $config(tp_seg_len) end]

		# Add upload command and the number of program bytes.
		lappend commands $info(op_pgld) [llength $segment]
	
		# Add all the program bytes.
		set commands [concat $commands $segment]
	
		# After the final chunk, we enable the program.
		if {[llength $prog] == 0} {
			lappend commands $info(op_pgon)
		}
			
		# Transmit the commands.
		Stimulator_transmit $config(tp_id) $commands
		
		# Reset the command list.
		set commands [list]
	}
}

#
# Stimulator_tp_halt disables execution of user code on the target device.
#
proc Stimulator_tp_halt {} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	# Send the program disable command.	
	set commands [list $info(op_pgoff)]

	# Transmit the commands.
	Stimulator_transmit $config(tp_id) $commands
}

#
# Stimulator_open opens the tool window and makes all its controls.
#
proc Stimulator_open {} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
	
	set f $w.controls
	frame $f
	pack $f -side top -fill x
	
	label $f.state -textvariable Stimulator_info(state) -width 12 -fg blue
	pack $f.state -side left -expand 1
	
	label $f.laddr -text "ip_addr:" -fg $config(label_color)
	entry $f.eaddr -textvariable Stimulator_config(ip_addr) -width 16
	pack $f.laddr $f.eaddr -side left -expand 1

	label $f.lsckt -text "driver_socket:" -fg $config(label_color)
	entry $f.esckt -textvariable Stimulator_config(driver_socket) -width 4
	pack $f.lsckt $f.esckt -side left -expand 1

	button $f.neuroplayer -text "Neuroplayer" -command {
		LWDAQ_post "LWDAQ_run_tool Neuroplayer"
	}
	pack $f.neuroplayer -side left -expand 1

	button $f.receiver -text "Receiver" -command {
		LWDAQ_post "LWDAQ_open Receiver"
	}
	pack $f.receiver -side left -expand 1

	button $f.txcmd -text "Transmit Panel" -command {
		LWDAQ_post "Stimulator_transmit_panel"
	}
	pack $f.txcmd -side left -expand 1

	foreach a {Configure Help} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_tool_$b $info(name)"
		pack $f.$b -side left -expand 1
	}
	
	checkbutton $f.verbose -variable Stimulator_config(verbose) -text "Verbose"
	pack $f.verbose -side left -expand 1
	
	set f $w.list
	frame $f
	pack $f -side top -fill x
	
	foreach {a c} {Start green Stop black Xon green Xoff black} {
		set b [string tolower $a]
		button $f.$b -text "$a\_All" -fg $c -command [list LWDAQ_post "Stimulator_all $b"]
		pack $f.$b -side left -expand 1
	}
	
	foreach a {Add_Device Save_List Load_List Refresh_List Identify} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post Stimulator_$b"
		pack $f.$b -side left -expand 1
	}
	
	set f $w.params
	frame $f
	pack $f -side top -fill x
	
	foreach {a c} {pulse_ms 5 period_ms 5 num_pulses 5 current 3} {
		label $f.l$a -text "$a\:" -fg $config(label_color)
		entry $f.$a -textvariable Stimulator_config($a) -width $c
		pack $f.l$a $f.$a -side left -expand 1
	}

	checkbutton $f.random -text "Random" \
		-variable Stimulator_config(random)
	pack $f.random -side left -expand 1
	
	foreach {a c} {sps 5} {
		label $f.l$a -text "$a\:" -fg $config(label_color)
		entry $f.$a -textvariable Stimulator_config($a) -width $c
		pack $f.l$a $f.$a -side left -expand 1
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