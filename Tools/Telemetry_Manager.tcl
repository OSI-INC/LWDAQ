# Telemetry Manager, a LWDAQ Tool
#
# Copyright (C) 2026 Kevan Hashemi, Open Source Instruments
#
# The Telemetry Manager controls and configures telemetry sensors equipped with
# crystal radio receivers. These include the existing A3054 Intraperitoneal
# Transmitter (IPT) and other planned second-generation Subcutaneous
# Transmitters (SCTs).
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <https://www.gnu.org/licenses/>.

#
# Telemetry_Manager_init initializes the Telemetry_Manager Tool.
#
proc Telemetry_Manager_init {} {
	upvar #0 Telemetry_Manager_info info
	upvar #0 Telemetry_Manager_config config
	global LWDAQ_Info LWDAQ_Driver
	
	LWDAQ_tool_init "Telemetry_Manager" "1.4"
	if {[winfo exists $info(window)]} {return ""}
	
	set config(ip_addr) "10.0.0.37"
	set config(driver_socket) "8"
	set config(mux_socket) "1"
	
	set config(rck_khz) "32.768"
	set config(rck_divisor) "32"

	set config(initiate_delay) "0.005"
	set config(spacing_delay_A2037E) "0.0000"
	set config(spacing_delay_A2071E) "0.0014"
	set config(spacing_delay_cmd) "0.0"
	set config(byte_processing_time) "0.0002"
	set config(rf_off_op) "0080"
	set config(rf_on_op) "0081"
	set config(rf_xmit_op) "82"
	set config(Telemetry_Manager_element) "2"
	set config(checksum_preload) "1111111111111111"
	set config(log_enable) "0"
	set config(log_file) "~/Desktop/Telemetry_Manager_Log.txt"
	
	set config(ton_color) "red"
	set config(toff_color) "black"
	set config(lon_color) "lightgreen"
	set config(loff_color) "lightgray"	
	set config(label_color) "brown"
	
	set config(conf_delay) "3"
	set config(aux_show) "0"
	set config(aux_color) "orange"
	set info(time_format) {%d-%b-%Y %H:%M:%S}
	
	set info(transmit_ms) "0"
	set config(default_id) "1234"
	set config(multicast_id) "FFFF"
	set config(max_tx_sps) "2048"
	
	set config(sps) "512"
	
	# Transmit Panel Parameters
	set config(prog_id) "FFFF"
	set config(prog_file) "~/Desktop/Config.txt"
	set config(prog_seglen) "32"
	set config(prog_addr) "0x0000"
	set info(prog_control) "Idle"
	set info(prog_ew) $info(window).progew
	set info(prog_text) $info(prog_ew).text
	
	# Auxiliary message types.
	set info(at_id) "1"
	set info(at_ack) "2"
	set info(at_batt) "3"
	set info(at_conf) "4"
	set info(at_ver) "5"
	
	# Operation codes, which we use to construct instructions, which
	# we in turn combine to form commands.
	set info(op_id) "5"
	set info(op_ver) "11"
	set info(op_ton) "16" 
	set info(op_toff) "17" 
	set info(op_zon) "18" 
	set info(op_zoff) "19" 
	set info(op_nvmwr) "20"
	set info(op_lon) "30"
	set info(op_loff) "31" 
	
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
# Telemetry_Manager_print writes a line to the text window. In addition, if the
# log_enable is set, the routine writes all messages to a log file. The routine
# does not keep an infinite number of lines but instead limits the number of
# lines in the text window to the global num_lines_keep value.
#
proc Telemetry_Manager_print {line {color black}} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info
	global LWDAQ_Info

	LWDAQ_print $info(text) $line $color
	if {$config(log_enable)} {
		if {[catch {LWDAQ_print $config(log_file) $line} message]} {
			LWDAQ_print $info(text) "ERROR: $message writing to \"$config(log_file)\"."
		}
	}
	
	if {[$info(text) index end] > 1.2 * $LWDAQ_Info(num_lines_keep)} {
		$info(text) delete 1.0 "end [expr 0 - $LWDAQ_Info(num_lines_keep)] lines"
	}

	return ""
}

#
# Telemetry_Manager_transmit takes a device identifier and a list of command
# bytes and transmits them through a Command Transmitter such as the A3029A. The
# device identifier must be a four-digit hex value. The bytes must be decimal
# values 0..255. The routine appends a sixteen-bit checksum. The checksum is the
# two bytes necessary to return a sixteen-bit linear feedback shift register to
# all zeros, thus performing a sixteen-bit cyclic redundancy check. We assume
# the destination shift register is preloaded with the checksum_preload value.
# The shift register has taps at locations 16, 14, 13, and 11. The routine
# prints the identifier, the commands, and the checksum at the end. The
# identifier and checksum are given as four-digit hex strings. The other bytes
# are decimal numbers 0..255.
#
proc Telemetry_Manager_transmit {id commands} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info
	global LWDAQ_Driver
	
	# Take the four-digit hex code for an identifier, or a wild card character,
	# and returns two decimal numbers giving the decimal values of the two bytes
	# that make up either the specific identifier or the wild card identifier.
	set id [string trim $id]
	if {$id == "*"} {set id $config(multicast_id)}
	if {[regexp {([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})} $id match b1 b2]} {
		set commands "[expr 0x$b1] [expr 0x$b2] $commands"
	} else {
		Telemetry_Manager_print "ERROR: Bad device identifier \"$id\", using 0x000."
		set id "0000"
		set commands "0 0 $commands"
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

	# Print the commands to the text window before appending checksum, and show
	# checksum in hex.
	Telemetry_Manager_print "Transmit: 0x[format %4s $id] $commands\
		0x[format %04X [expr $d22*255+$d21]]" green

	# Append checksum as two bytes.	
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
		LWDAQ_set_driver_mux $sock $config(driver_socket) $config(mux_socket)
		LWDAQ_set_device_element $sock $config(Telemetry_Manager_element)
		LWDAQ_transmit_command_hex $sock $config(rf_on_op)
		LWDAQ_delay_seconds $sock $config(initiate_delay)
		LWDAQ_transmit_command_hex $sock $config(rf_off_op)
		if {$sd > 0} {LWDAQ_delay_seconds $sock $sd}
		set counter 0
		foreach c $commands {
			LWDAQ_transmit_command_hex $sock "[format %02X $c]$config(rf_xmit_op)"
			if {$sd > 0} {LWDAQ_delay_seconds $sock $sd}
		}
		LWDAQ_transmit_command_hex $sock "0000"
		LWDAQ_delay_seconds $sock \
			[expr $config(byte_processing_time)*[llength $commands]]
		LWDAQ_wait_for_driver $sock
		LWDAQ_socket_close $sock
	} error_result]} {
		Telemetry_Manager_print "ERROR: Transmit failed, [string tolower $error_result]"
		if {[info exists sock]} {LWDAQ_socket_close $sock}
		return ""
	}
	
	# If we get here, we have no reason to believe the transmission failed,
	# although we could have instructed an empty driver socket or the
	# Telemetry_Manager could have failed to receive the command.
	set info(transmit_ms) [clock milliseconds]
	return ""
}

#
# Telemetry_Manager_id takes either a device list index or a four-digit
# hexadecimal value and returns a four-digit hexadecimal value. If first looks
# to see if the value it is passed is an element in the device list. If so, it
# returns the identifier of this device. If not, it checks to see if the value
# is a four-digit hex string, and if so returns the value. Otherwise, it returns
# the default identifier and prints a warning to the Telemetry_Manager window.
#
proc Telemetry_Manager_id {n} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info

	if {[lsearch $info(dev_list) $n] >= 0} {
		return $info(dev$n\_id)
	} elseif {[regexp {[0-9A-Fa-f]{4}} $n]} {
		return $n
	} else {
		Telemetry_Manager_print "WARNING: Invalid device identifier \"$n\",\
			using $config(default_id) instead."
		return "$config(default_id)"
	}
}

#
# Telemetry_Manager_lon transmits a command to turn on the target's indicator
# lamp.
#
proc Telemetry_Manager_lon {n} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info

	# Set the tool state variable.
	if {$info(state) != "Idle"} {return}
	set info(state) "Lon"

	# Combose command with a battery measurement and version number check, 
	# then begin the start instruction.
	set commands [list $info(op_lon)]
	
	# Transmit the commands.
	Telemetry_Manager_transmit [Telemetry_Manager_id $n] $commands

	# Set state variables.
	set info(state) "Idle"
	
	return ""
}

#
# Telemetry_Manager_loff transmits a command to turn off the target's indicator
# lamp.
#
proc Telemetry_Manager_loff {n} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info

	# Set the tool state variable.
	if {$info(state) != "Idle"} {return}
	set info(state) "Loff"

	# Measure battery voltage, check version, and stop stimulus.
	set commands [list $info(op_loff)]
	
	# Transmit the commands.
	Telemetry_Manager_transmit [Telemetry_Manager_id $n] $commands
	
	# Set state variables.
	set info(state) "Idle"
	
	return ""
}

#
# Telemetry_Manager_zon transmits a command to close the sensor's impedance
# measurement switch.
#
proc Telemetry_Manager_zon {n} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info

	# Set the tool state variable.
	if {$info(state) != "Idle"} {return}
	set info(state) "Zon"

	# Combose command with a battery measurement and version number check, 
	# then begin the start instruction.
	set commands [list $info(op_zon)]
	
	# Transmit the commands.
	Telemetry_Manager_transmit [Telemetry_Manager_id $n] $commands

	# Set state variables.
	set info(state) "Idle"
	
	return ""
}

#
# Telemetry_Manager_zoff transmits a command to open the sensor's impedance
# measurement switch.
#
proc Telemetry_Manager_zoff {n} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info

	# Set the tool state variable.
	if {$info(state) != "Idle"} {return}
	set info(state) "Zoff"

	# Combose command with a battery measurement and version number check, 
	# then begin the start instruction.
	set commands [list $info(op_zoff)]
	
	# Transmit the commands.
	Telemetry_Manager_transmit [Telemetry_Manager_id $n] $commands

	# Set state variables.
	set info(state) "Idle"
	
	return ""
}

#
# Telemetry_Manager_ton activates the telemetry protocol of the selected device.
#
proc Telemetry_Manager_ton {n} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info

	# Set the tool state variable.
	if {$info(state) != "Idle"} {return}
	set info(state) "Ton"

	# Start our command with version request instruction.
	set commands [list $info(op_ton)]
		
	# Transmit the command.
	Telemetry_Manager_transmit [Telemetry_Manager_id $n] $commands

	# Set state variables.
	set info(state) "Idle"
	
	return ""
}

#
# Telemetry_Manager_toff deactivates the telemetry protocol.
#
proc Telemetry_Manager_toff {n} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info

	# Set the tool state variable.
	if {$info(state) != "Idle"} {return}
	set info(state) "Toff"

	# Send a Toff command.
	set commands [list $info(op_toff)]
	
	# Transmit the commands.
	Telemetry_Manager_transmit [Telemetry_Manager_id $n] $commands

	# Set state variables.
	set info(state) "Idle"
	
	return ""
}

#
# Telemetry_Manager_identify requests a identifying messages from all devices. It uses
# the data acquisition configuration of the first device in our list, but
# applies the multicast identifier to reach all devices.
#
proc Telemetry_Manager_identify {} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info

	# We will use the first device's data acquisition configuration
	# as a starting point.
	set n [lindex $info(dev_list) 0]

	# Set the tool state variable.
	if {$info(state) != "Idle"} {return}
	set info(state) "Identify"

	# Add the idenfity command.
	set commands [list $info(op_id)]
	
	# Report to user.
	Telemetry_Manager_print "Sending identification command."

	# Transmit commands to multicast address.
	Telemetry_Manager_transmit $config(multicast_id) $commands
	
	# Set state variable.
	set info(state) "Idle"
	
	return ""
}

#
# Telemetry_Manager_all takes a parameter "action" that it uses to define a
# procedure it will call on every Telemetry_Manager in the current list,
# provided that its ID is not "*". We introduce a delay after each action to
# give Telemetry_Managers a chance to get ready for the next command.
# 
proc Telemetry_Manager_all {action} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info

	foreach n $info(dev_list) {
		if {$info(dev$n\_id) != "*"} {
			LWDAQ_post [list Telemetry_Manager_$action $n]
		}
	}

	return ""
}

#
# Telemetry_Manager_clear clears the status and battery values of an
# Telemetry_Managers in the list.
#
proc Telemetry_Manager_clear {n} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info

	LWDAQ_set_bg $info(dev$n\_state) $config(loff_color)
	LWDAQ_set_fg $info(dev$n\_state) $config(toff_color)
	set info(dev$n\_battery) "?"	
	set info(dev$n\_version) "?"	

	return ""
}

#
# Telemetry_Manager_monitor captures auxiliary messages from Telemetry_Managers
# and keeps track of when stimuli end, so it can change the state label colors.
# The routine looks for auxiliary messages first in the Neuroplayer Tool, if one
# exists, and second in the Receiver Instrument. While the monitor is running,
# it enables analysis in the Receiver Instrument so that we can get auxiliary
# messages. Right now the Telemetry_Manager Tool operates only with a graphical
# user interface, so we use the existence of its window to determine if the
# monitor should shut down.
#
proc Telemetry_Manager_monitor {} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info
	upvar #0 LWDAQ_info_Receiver rconfig
	upvar #0 LWDAQ_info_Receiver rinfo
	upvar #0 Neuroplayer_info ninfo
	upvar #0 Neuroplayer_config nconfig
	global LWDAQ_Info
	
	# Set or clear the analysis enable flag in the Receiver Instruments.
	if {![winfo exists $info(window)] || $LWDAQ_Info(reset)} {
		set rconfig(analysis_enable) "0"
		return ""
	} else {
		set rconfig(analysis_enable) "1"
	}
	set f $info(window).state

	# Note the time for stimulation tracking.
	set now_ms [clock milliseconds]
	
	# Look for auxiliary message lists. If we find one, copy and clear the list.
	set aux_messages ""
	if {[info exists ninfo(aux_messages)]} {
		set aux_messages $ninfo(aux_messages)
		set ninfo(aux_messages) ""
		set now_time \($ninfo(play_datetime)\)
	} elseif {[info exists rinfo(aux_messages)]} {
		set aux_messages $rinfo(aux_messages)
		set rinfo(aux_messages) ""
		set now_time \([clock format [clock seconds] -format $info(time_format)]\)
	}
	
	# If we have no auxiliary messages, we are done.
	if {[llength $aux_messages] == 0} { 
		LWDAQ_post Telemetry_Manager_monitor
		return ""
	}
	
	# Compose a list of active device numbers with their sixteen-bit identifiers,
	# as listed in our Telemetry_Manager window.
	set id_list ""
	foreach n $info(dev_list) {lappend id_list "$n $info(dev$n\_id)"}
	
	# Go through the auxiliary message list and find messages that could be from
	# Telemetry_Managers. As we proceed, we save the previous valid auxiliary
	# message so that we can avoid processing duplicates in the list.
	set previd 0
	set prevfa 0
	set prevdb 0
	foreach am $aux_messages {
	
		# Scan the auxiliary message for identifier, field address, data byte
		# and timestamp. The timestamp is a sixteen-bit positive integer that
		# counts 32.768 kHz clock ticks.
		scan $am %d%d%d%d id fa db ts
		if {$config(aux_show)} {
			Telemetry_Manager_print "Auxiliary Message:\
				id=$id fa=$fa db=$db ts=$ts" $config(aux_color)
		}
		
		# If this is a confirmation message, proceed to next auxiliary message.
		if {$fa == $info(at_conf)} {continue}
		
		# If this is a repeat of a previously processed auxilliary message,
		# proceed.
		if {($previd == $id) && ($prevfa == $fa) && ($prevdb == $db)} {continue}

		# If it is some other sort of message, look for a confirmation that
		# arrived no more than conf_delay ticks after our auxiliary message. If
		# we don't find one, proceed to next auxiliary message. If we do find
		# one, use it to obtain the full device identifier.
		set device_id "0"
		foreach cam $aux_messages {
			scan $cam %d%d%d%d cid cfa cdb cts
			if {$cfa != $info(at_conf)} {continue}
			if {($cid == $id) && (($cts - $ts) % 65536 <= $config(conf_delay))} {
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
			
			# Acknowledgements encode the type of command in their data byte. We
			# use the rare list format of the switch command in order to resolve
			# variables in the matching clauses.
			switch $db \
				$info(op_zon) {
					set type "zon"
				} \
				$info(op_zoff) {
					set type "zoff"
				} \
				$info(op_ton) {
					set type "ton"
					LWDAQ_set_fg $info(dev$n\_state) $config(ton_color)
				} \
				$info(op_toff) {
					set type "toff"
					LWDAQ_set_fg $info(dev$n\_state) $config(toff_color)
				} \
				$info(op_loff) {
					set type "loff"
					LWDAQ_set_bg $info(dev$n\_state) $config(loff_color)
				} \
				$info(op_lon) {
					set type "lon"
					LWDAQ_set_bg $info(dev$n\_state) $config(lon_color)
				} \
				$info(op_nvmwr) {
					set type "nvmwr"
				} \
				default {
					set type "invalid"
				}
			if {$type != "invalid"} {
				Telemetry_Manager_print "Acknowledge:\
					device_id=$device_id type=$type ts=$ts $now_time"
			}
		} elseif {$fa == $info(at_batt)} {
			
			# Ignore battery measurements from devices that are not in our list.
			if {$n == 0} {continue}
			
			# We interpret battery measurements in a manner particular to the
			# various supported device versions.
			set ver $info(dev$n\_version)
			switch $ver {
				"21" {set voltage [format %.2f [expr 255.0/$db*1.2]]}
				default {set voltage [format %.2f [expr 255.0/$db*1.2]]}
			}
			
			# Report the battery measurement.
			set info(dev$n\_battery) $voltage
			Telemetry_Manager_print "Battery:\
				device_id=$device_id value=$db ts=$ts\
				voltage=$voltage $now_time" 
		} elseif {$fa == $info(at_id)} {
			Telemetry_Manager_print "Identification:\
				device_id=$device_id ts=$ts $now_time" green
		} elseif {$fa == $info(at_ver)} {

			# Ignore version number reports from devices that are not in our list.
			if {$n == 0} {continue}
			
			set info(dev$n\_version) "$db"
			Telemetry_Manager_print "Version:\
				device_id=$device_id value=$db ts=$ts $now_time"
		} else {
			
			# We don't recognise this type of auxiliary message, so proceed.
			continue
		}
		
		# By this point, we have processed and report on the confirmed auxiliary
		# message, so record its identifier, field address, and data byte in
		# order to avoid processing a subsequent duplicate.
		set previd $id
		set prevfa $fa
		set prevdb $db
	}
	
	# We post the monitor to the event queue and report success.
	LWDAQ_post Telemetry_Manager_monitor
	return ""
}

#
# Telemetry_Manager_undraw_list removes the Telemetry_Manager list from the
# Telemetry_Manager window.
#
proc Telemetry_Manager_undraw_list {} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info

	foreach n $info(dev_list) {
		set ff $info(window).dev_list.dev$n
		catch {destroy $ff}
	}
	
	return ""
}

#
# Telemetry_Manager_draw_list draws the current list of Telemetry_Managers in
# the Telemetry_Manager window.
#
proc Telemetry_Manager_draw_list {} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info

	set f $info(window).dev_list
	if {![winfo exists $f]} {
		frame $f
		pack $f -side top -fill x
	}
	
	set padx $info(button_padx)
	
	foreach n $info(dev_list) {
	
		# If this Telemetry_Manager's state variable does not exist, then create
		# it now, as well as other system parameters.
		if {![info exists info(dev$n\_id)]} {
			set info(dev$n\_id) $config(default_id)
			set info(dev$n\_channel) [expr 0x$config(default_id) % 256]
			set info(dev$n\_version) "?"
			set info(dev$n\_battery) "?"
		}

		set ff $f.dev$n
		frame $ff -relief sunken -bd 2
		pack $ff -side top -fill x
		
		entry $ff.id -textvariable Telemetry_Manager_info(dev$n\_id) -width 5
		pack $ff.id -side left -expand 1
		set info(dev$n\_state) $ff.id
		LWDAQ_set_bg $info(dev$n\_state) $config(toff_color)
		LWDAQ_set_bg $info(dev$n\_state) $config(loff_color)
		
		foreach {a c} {Lon green \
				Loff black \
				Ton green \
				Toff black \
				Zon green \
				Zoff black} {
			set b [string tolower $a]
			button $ff.$b -text $a -padx $padx -fg $c -command \
				[list LWDAQ_post "Telemetry_Manager_$b $n" front]
			pack $ff.$b -side left -expand 1
		}

		foreach {a c} {channel 3} {
			label $ff.l$a -text "$a\:" -fg $config(label_color)
			entry $ff.$a -textvariable Telemetry_Manager_info(dev$n\_$a) -width $c
			pack $ff.l$a $ff.$a -side left -expand 1
		}

		foreach {a c} { version 3 battery 3} {
			label $ff.l$a -text "$a\:" -fg $config(label_color)
			label $ff.$a -textvariable Telemetry_Manager_info(dev$n\_$a) -width $c
			pack $ff.l$a $ff.$a -side left -expand 1
		}

		button $ff.delete -text "X" -padx $padx -command \
			[list LWDAQ_post "Telemetry_Manager_ask_remove $n" front]
		pack $ff.delete -side left -expand 1
	}
	
	return ""
}

#
# Telemetry_Manager_ask_remove ask if the user is certain they want to remove an 
# Telemetry_Manager from the list.
#
proc Telemetry_Manager_ask_remove {n} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info

	# Find the Telemetry_Manager in our list.
	set index [lsearch $info(dev_list) $n]
	
	# Exit if the Telemetry_Manager does not exist.
	if {$index < 0} {
		Telemetry_Manager_print "ERROR: No Telemetry_Manager with list index $n\."
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
		[list LWDAQ_post "Telemetry_Manager_remove $n" front]
	button $w.no -text "No" -padx 10 -pady 5 -command \
		[list LWDAQ_post "destroy $w" front]
	pack $w.q $w.yes $w.no -side left -expand 1

	return ""
}

#
# Telemetry_Manager_remove remove a Telemetry_Manager from the list.
#
proc Telemetry_Manager_remove {n} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info

	# Find the Telemetry_Manager in our list.
	set index [lsearch $info(dev_list) $n]
	
	# If a remove window exists, destroy it
	set w $info(window)\.remove$n
	if {[winfo exists $w]} {destroy $w}

	# Exit if the Telemetry_Manager does not exist.
	if {$index < 0} {
		Telemetry_Manager_print "ERROR: No Telemetry_Manager with list index $n\."
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
# Telemetry_Manager_add_device adds a new Telemetry_Manager to the list.
#
proc Telemetry_Manager_add_device {} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info

	# Delete the list display.
	Telemetry_Manager_undraw_list
	
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
	Telemetry_Manager_draw_list
	
	return ""
}

#
# Telemetry_Manager_save_list save a Telemetry_Manager list to disk.
#
proc Telemetry_Manager_save_list {{fn ""}} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info
	
	# Try to get a valid file name.
	if {$fn == ""} {
		set fn [LWDAQ_put_file_name "DevList.tcl"]
		if {$fn == ""} {return ""}
	}

	# Write Telemetry_Manager list to disk.
	set f [open $fn w]
	puts $f "set Telemetry_Manager_info(dev_list) \"$info(dev_list)\""
	foreach n $info(dev_list) {
		foreach p {id channel version} {
			set e "dev$n\_$p"
			puts $f "set Telemetry_Manager_info($e) \"[set info($e)]\"" 
		}
	}
	close $f
	
	# Change the Telemetry_Manager list file parameter.
	set config(dev_list_file) $fn

	return ""
}

#
# Telemetry_Manager_load_list loads a Telemetry_Manager list from disk. If we
# don't specify the list file name, the routine uses a browser to get a file
# name.
#
proc Telemetry_Manager_load_list {{fn ""}} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info
	
	# Try to get a valid file name.
	if {$fn == ""} {
		set fn [LWDAQ_get_file_name]		
		if {$fn == ""} {return ""}
	} else {
		if {![file exists $fn]} {return ""}
	}

	# Undraw the list, run the Telemetry_Manager list file, and re-draw the list.
	if {[catch {
		Telemetry_Manager_undraw_list	
		set info(dev_list) [list]
		uplevel #0 [list source $fn]
		Telemetry_Manager_draw_list
		foreach n $info(dev_list) {
			LWDAQ_set_bg $info(dev$n\_state) $config(loff_color)
			LWDAQ_set_fg $info(dev$n\_state) $config(toff_color)
			set info(dev$n\_battery) "?"
			set info(dev$n\_version) "?"	
		}
	} error_message]} {
		Telemetry_Manager_print "ERROR: $error_message\."
		return
	}
	
	# Change the Telemetry_Manager list file name to match the newly-loaded file.
	set config(dev_list_file) $fn
	
	return ""
}

#
# Telemetry_Manager_rename_device changes the device name from one value to
# another, overwriting any pre-existing device of the new name, and deleging the
# device under the old name.
#
proc Telemetry_Manager_rename_device {n m} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info

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
# Telemetry_Manager_refresh_list assigns ascending, consecutive device numbers
# to the existing rows of the device list. It clears all state indication colors
# and battery values.
#
proc Telemetry_Manager_refresh_list {{fn ""}} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info
	
	Telemetry_Manager_undraw_list	

	set new_list [list]
	set m 1000
	foreach n $info(dev_list) {
		Telemetry_Manager_rename_device $n $m
		lappend new_list "$m $info(dev$m\_id)"
		incr m
	}
	set new_list [lsort -increasing -index 1 $new_list]
	
	set info(dev_list) [list]
	set m 1
	foreach dev $new_list {
		set n [lindex $dev 0]
		Telemetry_Manager_rename_device $n $m
		set info(dev$m\_battery) "?"
		set info(dev$n\_version) "?"	
		lappend info(dev_list) $m
		incr m
	}
	unset new_list
	
	Telemetry_Manager_draw_list
	
	return ""
}

#
# Telemetry_Manager_programmer opens a new window that allows the user to upload
# bytes to any location in a telemetry device's non-volatile memory, provided
# that those locations are not locked for writing by the device's internal
# write-protection logic. The programmer uses the same ip_addr and driver_socket
# specified in the Telemetry_Manager main window, but it uses its own device
# identifier. The identifier must be a four-digit hexadecimal value. We can
# include or omit a "0x" prefix. We can be set to the wild card FFFF or a
# specific four-digit identifier. The memory address to which we will write
# bytes we specify either in decimal or in hexadecimal in the "0xFFF" format.
# The programmer uses a text file as its source of bytes to upload to a device.
# These bytes must be delimited by whitespace. They can be expressed as decimal
# values or two-digit hex values in the 0xFF format.
#
proc Telemetry_Manager_programmer {} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info
	
	# Open the transmit panel.
	set w $info(window)\.xmit_panel
	if {[winfo exists $w]} {
		raise $w
		return ""
	}
	toplevel $w
	wm title $w "Telemetry Manager $info(version) Device Programmer"
	
	set f [frame $w.controls]
	pack $f -side top -fill x
	
	label $f.state -textvariable Telemetry_Manager_info(prog_control) \
		-width 12 -fg blue
	pack $f.state -side left -expand 1

	label $f.idl -text "Device Identifier:"
	entry $f.ide -textvariable Telemetry_Manager_config(prog_id) -width 7
	pack $f.idl $f.ide -side left -expand 1

	label $f.addrl -text "Memory Address:"
	entry $f.addre -textvariable Telemetry_Manager_config(prog_addr) -width 8
	pack $f.addrl $f.addre -side left -expand 1
	
	label $f.seglenl -text "Sgement Length:"
	entry $f.seglene -textvariable Telemetry_Manager_config(prog_seglen) -width 4
	pack $f.seglenl $f.seglene -side left -expand 1

	button $f.upload -text "Upload" -command \
		"LWDAQ_post Telemetry_Manager_programmer_upload"
	pack $f.upload -side left -expand 1

	button $f.stop -text "Stop" -command {
		set Telemetry_Manager_info(prog_control) "Stop"
	}
	pack $f.stop -side left -expand 1

	set f [frame $w.program]
	pack $f -side top -fill x
	
	label $f.lprogram -text "Program File (hex):" -fg $config(label_color)
	entry $f.eprogram -textvariable Telemetry_Manager_config(prog_file) -width 60
	pack $f.lprogram $f.eprogram -side left -expand 1

	foreach a {Browse Edit} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post Telemetry_Manager_programmer_$b"
		pack $f.$b -side left -expand 1
	}

	set info(prog_text) [LWDAQ_text_widget $w 80 15]

	return "" 
}

#
# Telemetry_Manager_programmer_browse opens a file browser to select the program
# file.
#
proc Telemetry_Manager_programmer_browse {} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info

	set fn [LWDAQ_get_file_name]
	if {$fn != ""} {set config(prog_file) $fn}
	return ""
}

#
# Telemetry_Manager_programmer_edit opens the data file in an editor window.
#
proc Telemetry_Manager_programmer_edit {} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info

	if {[winfo exists $info(prog_ew)]} {
		raise $info(prog_ew)
	} else {
		set info(prog_ew) [LWDAQ_edit_script Open $config(prog_file)]
	}
	return $info(prog_ew)
}

#
# Telemetry_Manager_programmer_upload reads bytes in decimal string format from
# a text files and uploads them to the sensor's non-volatile memory. The number
# of bytes written must be divisible by sixteen, and the destination address
# must lie on a sixteen-byte boundary. The non-volatile memory enforces a write
# page size of sixteen bytes and the pages lie on sixteen-byte boundaries. If we
# pass no arguments to this routine, it picks the device identifier form the
# programming panel, reads the contents of the file named in the programming
# panel, and uses the address provided in the programming panel. Otherwise, it
# uses the identifier, data, and address provided in its argument list. The data
# must be a list of bytes delimited by white spaces with each byte in either
# decimal or 0xFF hexadecimal format. The routine takes a segment of bytes from
# the front of the list and uploads them to the given memory address, then posts
# itself to the LWDAQ event queue with the remaining bytes as data and an
# address incremented by the segment length. By posting itself to the event
# queue, the upload process allows the Receiver Instrument and the Telemetry
# Manager Monitor to continue operating.
#
#
proc Telemetry_Manager_programmer_upload {{id ""} {addr ""} {data ""}} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info
	upvar #0 OSR8_Assembler_config aconfig
	upvar #0 OSR8_Assembler_info ainfo
	
	# If the control has been set to Stop, then do so.
	if {$info(prog_control) == "Stop"} {
		LWDAQ_print $info(prog_text) "Stopped program upload."
		set info(prog_control) "Idle"
		return ""
	}
	
	# If no identifier argument has been passed, use the value in the panel.
	if {$id == ""} {
		set id $config(prog_id)
	}
	
	# If no address argment has been passed, use the value in the panel.
	if {$addr == ""} {
		set addr $config(prog_addr)
	}
	
	# If no data argument has been passed, try to read data from the program
	# file.
	if {$data == ""} {
		if {[file exists $config(prog_file)]} {
			set f [open $config(prog_file)]
			set data [read $f]
			close $f
			set data [regsub -all {\n} $data " "]
			set data [string trim $data]
			LWDAQ_print $info(prog_text) "Read [llength $data] data bytes\
				from \"[file tail $config(prog_file)]\"."
		} else {
			LWDAQ_print $info(prog_text) "ERROR: Cannot find\
				programming data file \"$config(prog_file)\"."
			return ""
		} 
	}
	
	# Check the address and data lengths.
	if {$addr % 16 != 0} {
		LWDAQ_print $info(prog_text) "ERROR: Memory address must lie\
			on a sixteen-byte boundary."
		return ""
	}
	if {[llength $data] % 16 != 0} {
		LWDAQ_print $info(prog_text) "ERROR: Number of data bytes must be\
			divisible by sixteen."
		return ""
	}
	if {[llength $data] < 16} {
		LWDAQ_print $info(prog_text) "ERROR: Number of data bytes must be\
			at least sixteen."
		return ""
	}
	
	# Set the control to upload.
	set info(prog_control) "Upload"

	# Extract a segment from the data, or a partial segment if we 
	# don't have a full segment remaining.
	if {[llength $data] >= $config(prog_seglen)} {
		set segment [lrange $data 0 [expr $config(prog_seglen)-1]]
		set data [lrange $data $config(prog_seglen) end]
	} else {
		set segment $data
		set data ""
	}
	
	# Calculate the top and bottom address bytes.
	set addr_h [expr $addr / 256]
	set addr_l [expr $addr % 256]
	
	# Print a notification.
	LWDAQ_print $info(prog_text) "Uploading [llength $segment] bytes\
		to 0x[format %04X $addr] on device 0x$id\..."

	# Compose the upload command and transmit.
	set commands [list $info(op_nvmwr) [llength $segment] $addr_h $addr_l]
	set commands [concat $commands $segment]
	Telemetry_Manager_transmit $config(prog_id) $commands
	
	# Increment the address.
	set addr [expr $addr + [llength $segment]]
	
	# If we have more data to transmit, post another upload to the
	# event queue.
	if {[llength $data] >= 16} {
		LWDAQ_post [list Telemetry_Manager_programmer_upload $id $addr $data]
	} else {
		set info(prog_control) "Idle"
	}
	
	# We are done.
	return ""
}

#
# Telemetry_Manager_open opens the tool window and makes all its controls.
#
proc Telemetry_Manager_open {} {
	upvar #0 Telemetry_Manager_config config
	upvar #0 Telemetry_Manager_info info

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
	
	set f $w.controls
	frame $f
	pack $f -side top -fill x
	
	label $f.state -textvariable Telemetry_Manager_info(state) -width 12 -fg blue
	pack $f.state -side left -expand 1
	
	label $f.laddr -text "ip_addr:" -fg $config(label_color)
	entry $f.eaddr -textvariable Telemetry_Manager_config(ip_addr) -width 16
	pack $f.laddr $f.eaddr -side left -expand 1

	label $f.lsckt -text "driver_socket:" -fg $config(label_color)
	entry $f.esckt -textvariable Telemetry_Manager_config(driver_socket) -width 4
	pack $f.lsckt $f.esckt -side left -expand 1

	button $f.neuroplayer -text "Neuroplayer" -command {
		LWDAQ_post "LWDAQ_run_tool Neuroplayer"
	}
	pack $f.neuroplayer -side left -expand 1

	button $f.receiver -text "Receiver" -command {
		set LWDAQ_config_Receiver(analysis_enable) 1
		set LWDAQ_config_Receiver(daq_ip_addr) $Telemetry_Manager_config(ip_addr)
		LWDAQ_post "LWDAQ_open Receiver"
	}
	pack $f.receiver -side left -expand 1

	button $f.txcmd -text "Programmer" -command {
		LWDAQ_post "Telemetry_Manager_programmer"
	}
	pack $f.txcmd -side left -expand 1

	foreach a {Configure Help} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_tool_$b $info(name)"
		pack $f.$b -side left -expand 1
	}
	
	checkbutton $f.log -variable Telemetry_Manager_config(log_enable) -text "Log"
	pack $f.log -side left -expand 1

	set f $w.list
	frame $f
	pack $f -side top -fill x
	
	foreach {a c} {Ton green Toff black} {
		set b [string tolower $a]
		button $f.$b -text "$a\_All" -fg $c -command \
			[list LWDAQ_post "Telemetry_Manager_all $b"]
		pack $f.$b -side left -expand 1
	}
	
	foreach a {Add_Device Save_List Load_List Refresh_List Identify} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post Telemetry_Manager_$b"
		pack $f.$b -side left -expand 1
	}
	
	foreach {a c} {sps 5} {
		label $f.l$a -text "$a\:" -fg $config(label_color)
		entry $f.$a -textvariable Telemetry_Manager_config($a) -width $c
		pack $f.l$a $f.$a -side left -expand 1
	}

	if {[llength $info(dev_list)] == 0} {
		Telemetry_Manager_add_device
	} else {
		Telemetry_Manager_draw_list
	}

	set info(text) [LWDAQ_text_widget $w 80 15]

	# If the device list file exist, load it.
	if {[file exists $config(dev_list_file)]} {
		Telemetry_Manager_load_list $config(dev_list_file)
	}
	
	return $w
}

# Start up the tool. We call the monitor routine, which sets the monitor 
# working in the background to maintain the Telemetry_Manager status 
Telemetry_Manager_init
Telemetry_Manager_open
Telemetry_Manager_monitor

return ""

----------Begin Help----------

http://www.opensourceinstruments.com/Electronics/A3054/Telemetry_Manager.html

----------End Help----------

----------Begin Data----------

----------End Data----------