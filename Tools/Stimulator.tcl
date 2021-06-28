# Stimulator, a Standard and Polite LWDAQ Tool
# Copyright (C) 2014-2020 Kevan Hashemi, Open Source Instruments
# Based upon the ISL_Controller Tool.
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


proc Stimulator_init {} {
	upvar #0 Stimulator_info info
	upvar #0 Stimulator_config config
	global LWDAQ_Info LWDAQ_Driver
	
	LWDAQ_tool_init "Stimulator" "1.6"
	if {[winfo exists $info(window)]} {return 0}
	
	set config(ip_addr) "10.0.0.37"

	set config(device_rck_khz) "32.768"
	set config(max_len) "65535"
	set config(initiate_delay) "0.010"
	set config(spacing_delay_A2037E) "0.0000"
	set config(spacing_delay_A2071E) "0.0014"
	set config(spacing_delay_cmd) "0.0"
	set config(byte_processing_time) "0.0002"
	set config(rf_on_op) "0081"
	set config(rf_xmit_op) "82"
	set config(checksum_preload) "1111111111111111"
	
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

	set config(bat_calib_A3030) "8 40"
	set config(bat_calib_A3036) "3.7 200 -60"
	set config(blow) "3.6"
	set config(bempty) "3.2"

	set config(ack_enable) "0"
	set config(ack_timeout_ms) "2000"
	set config(ack_key) "0"
	set config(ack_fa) "1"
	set config(bat_fa) "2"
	set config(ack_pending) ""
	set config(default_device_version) "A3036"
	set config(device_versions) "A3030 A3036 A3037"
	set config(verbose) "1"
	
	set config(commands) "11 0 0"
	
	set info(state) "Idle"
	set info(monitor_interval_ms) "100"
	set info(monitor_ms) "0"
	set info(button_padx) "0"
	set info(device0_sckt) "8"
	
	set info(device_list) [list]	
	set config(device_list_file) [file normalize "~/Desktop/DevList.tcl"]

	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 

	return 1   
}

# 
# This procedure generates a list of bytes to transmit to the device so as to
# select, configure, and stimulate it according to the parameters in the
# Stimulator window. It appends a two-byte checksum, which is necessary for the
# device to accept the command. Each byte is expressed in the return string as a
# decimal number between 0 and 255.
#
proc Stimulator_commands {n} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	# Starting with an empty command string.
	set commands ""
	
	# Select the device, unless the device id given is "*", in which
	# case we won't specify a device.
	set id [set info(device$n\_id)]
	if {$id != "*"} {
		append commands "11 $id "
	}
	
	# Set the two bytes of the pulse length.
	set len [expr round($config(device_rck_khz) * [set info(device$n\_pulse_ms)])]
	if {$len > $config(max_len)} {
		set len $config(max_len)
		LWDAQ_print $info(text) "WARNING: Pulses truncated to\
			[format %.3f [expr 1.0*$len/$config(device_rck_khz)]] ms."
	}
	append commands "4 [expr $len / 256] 5 [expr $len % 256] "

	# Set the two bytes of the interval length.
	set len [expr round([set info(device$n\_period_ms)])]
	if {$len > $config(max_len)} {
		set len $config(max_len)
		LWDAQ_print $info(text) "WARNING: Interval truncated $len ms."
	}
	append commands "6 [expr $len / 256] 7 [expr $len % 256] "

	# Set the two bytes of the stimulus length, which is the number of intervals.
	set len [set info(device$n\_num_pulses)]
	if {$len > $config(max_len)} {
		set len $config(max_len)
		LWDAQ_print $info(text) "WARNING: Stimulus truncated to $len pulses."
		
	}
	append commands "8 [expr $len / 256] 9 [expr $len % 256] "

	# Randomize the pulses, or not.
	if {[set info(device$n\_random)]} {
		append commands "10 1 "
	} {
		append commands "10 0 "
	}
	
	# Set the pulse brightness to 100%.
	append commands "3 5 "
	
	# Request an acknowledgement.
	if {$config(ack_enable)} {
		append commands "12 $config(ack_key) "
	}
	
	# Start the stimulus.
	append commands "1"
	
	# We return the command string, which does not yet have the checksum
	# attached to the end, but is otherwise a sequence of operation codes
	# and parameter values.
	return $commands
}

#
# Takes a string of bytes and appends the two bytes necessary to
# return a sixteen-bit linear feedback shift register to all zeros, thus
# performing a sixteen-bit cyclic redundancy check. We assume the 
# destination shift register is preloaded with the checksum_preload 
# value. The shift register has taps at locations 16, 14, 13, and 11.
#
proc Stimulator_append_checksum {commands} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

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

	return "$commands $d22 $d21"
}

#
# The transmit routine takes a string of command bytes and transmits them
# through a Command Transmitter such as the A3029A. If we don't pass any
# commands to the routine, it gets its commands from the config(commands)
# parameter. The routine does not direct the commands to any particular
# stimulator, but rather trusts that commands to perform a selection will
# be included in the list of command bytes. It does append the checksum
# to the commands, to fit their values, and it does select the driver socket
# specified for device "n".
#
proc Stimulator_transmit {n {commands ""}} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info
	global LWDAQ_Driver

	if {$commands == ""} {set commands $config(commands)}
	
	set commands [Stimulator_append_checksum $commands]

	if {[catch {
		set sock [LWDAQ_socket_open $config(ip_addr)]
		if {[LWDAQ_hardware_id $sock] == "37"} {
			set sd $config(spacing_delay_A2037E)		
		} {
			set sd $config(spacing_delay_A2071E)
		}
		LWDAQ_set_driver_mux $sock [set info(device$n\_sckt)] 1
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
		return "FAIL"
	}
	if {$config(verbose)} {
		LWDAQ_print $info(text) "Bytes Transmitted: $commands"
	}
	
	return "SUCCESS"
}

#
# Stimulator_start transmits the stimulation commands defined in
# the tool window. It opens a socket to the Command Transmitter, turns on the
# RF power for the initiate delay, which activates all stimulators for command reception,
# transmits all bytes listed in the commands parameter, transmits the correct
# cyclic redundancy checksum for the command bytes, turns off RF power for, waits
# for the termination period, and closes the socket. It calculates the stimulus
# length in microseconds and sets the stimulus end time for the selected channel 
# or channels. If we have enabled acknowledgements, we add a request for
# acknowledgement to the start command, and set the timeout value for the
# selected channels.
#
proc Stimulator_start {n} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	# Check the device id.
	set id [set info(device$n\_id)]
	if {![string is integer -strict $id] && ($id != "*")} {
		LWDAQ_print $info(text) "ERROR: Bad device id \"$id\"."
		return "FAIL"
	}

	# Set the tool state variable.
	if {$info(state) != "Idle"} {return}
	set info(state) "Command"

	# Determine the end-time of a stimulus. We use 0 as a code for "forever".
	# A finite stimulus ends at after the interval length multiplied by the
	# stimulus length, the former being in milliseconds and the latter in 
	# intervals.
	if {[set info(device$n\_num_pulses)] == 0} {
		set info(device$n\_end)  0
	} {
		set info(device$n\_end) [expr [clock milliseconds] \
			+ [set info(device$n\_period_ms)] * [set info(device$n\_num_pulses)]]
	}
	
	# Determine the acknowledgement timeout moment. The acknowledgement
	# key is the least significant eight bits of the timeout moment.
	set ack_time [clock milliseconds]
	set config(ack_key) [expr $ack_time % 256]
	
	# Transmit the commands.
	Stimulator_transmit $n [Stimulator_commands $n]

	# Set acknowledgement timeout moment.
	if {$config(ack_enable) && ($id != "*")} {
		lappend config(ack_pending) "$n $id Start $ack_time"
	}

	# Set state variables.
	LWDAQ_set_bg [set info(device$n\_state)] $config(son_color)
	set info(state) "Idle"
	
	return "SUCCESS"
}

#
# The stop procedure transmits a stop command and sets the stimulus end time
# for selected channel to the current time.
#
proc Stimulator_stop {n} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	# Check the device id.
	set id [set info(device$n\_id)]
	if {![string is integer -strict $id] && ($id != "*")} {
		LWDAQ_print $info(text) "ERROR: Bad device id \"$id\"."
		return "FAIL"
	}

	# Set the tool state variable.
	if {$info(state) != "Idle"} {return}
	set info(state) "Command"

	# Set the acknowledgement time and key.
	set ack_time [clock milliseconds]
	set config(ack_key) [expr $ack_time % 256]
	
	# Send the stimulus stop command, which is just a zero. If we want the 
	# command to be obeyed only by a particular device, we send a select
	# instruction followed by the device id. We request an acknowledgement
	# only when we are instructing one particular device.
	if {$config(ack_enable) && ($id != "*")} {
		Stimulator_transmit $n "11 $id 0 12 $config(ack_key)"
		lappend config(ack_pending) "$n $id Stop $ack_time"
	} elseif {$id != "*"} {
		Stimulator_transmit $n "11 $id 0"
	} else {
		Stimulator_transmit $n "0"
	}
	
	# Reset the stimulus end time
	set info(device$n\_end) 0
	
	# Set state variables.
	LWDAQ_set_bg [set info(device$n\_state)] $config(soff_color)
	set info(state) "Idle"
	
	return "SUCCESS"
}

#
# Stimulator_xon turns on data transmission. In ISTs, this will be a synchronizing
# signal, and in stimulator-sensors a sensor signal.
#
proc Stimulator_xon {n} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	# Check the device id.
	set id [set info(device$n\_id)]
	if {![string is integer -strict $id] && ($id != "*")} {
		LWDAQ_print $info(text) "ERROR: Bad device id \"$id\"."
		return "FAIL"
	}

	# Set the tool state variable.
	if {$info(state) != "Idle"} {return}
	set info(state) "Command"

	# Set the acknowledgement time and key.
	set ack_time [clock milliseconds]
	set config(ack_key) [expr $ack_time % 256]
	
	# Send the Xon command. We request an acknowledgement
	# only when we are instructing one particular device.
	if {$config(ack_enable) && ($id != "*")} {
		Stimulator_transmit $n "11 $id 2 1 12 $config(ack_key)"
		lappend config(ack_pending) "$n $id Xon $ack_time"
	} elseif {$id != "*"} {
		Stimulator_transmit $n "11 $id 2 1"
	} else {
		Stimulator_transmit $n "2 1"
	}

	# Set state variables.
	LWDAQ_set_fg [set info(device$n\_state)] $config(xon_color)
	set info(state) "Idle"
	
	return "SUCCESS"
}

#
# Stimulator_xoff turns data transmission.
#
proc Stimulator_xoff {n} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	# Check the device id.
	set id [set info(device$n\_id)]
	if {![string is integer -strict $id] && ($id != "*")} {
		LWDAQ_print $info(text) "ERROR: Bad device id \"$id\"."
		return "FAIL"
	}

	# Set the tool state variable.
	if {$info(state) != "Idle"} {return}
	set info(state) "Command"

	# Set the acknowledgement time and key.
	set ack_time [clock milliseconds]
	set config(ack_key) [expr $ack_time % 256]
	
	# Send the Xoff command. We request an acknowledgement
	# only when we are instructing one particular device.
	if {$config(ack_enable) && ($id != "*")} {
		Stimulator_transmit $n "11 $id 2 0 12 $config(ack_key)"
		lappend config(ack_pending) "$n $id Xoff $ack_time"
	} elseif {$id != "*"} {
		Stimulator_transmit $n "11 $id 2 0"
	} else {
		Stimulator_transmit $n "2 0"
	}

	# Set state variables.
	LWDAQ_set_fg [set info(device$n\_state)] $config(xoff_color)
	set info(state) "Idle"
	
	return "SUCCESS"
}

#
# Stimulator_battery requests a battery voltage transmission.
#
proc Stimulator_battery {n} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	# Check the device id.
	set id [set info(device$n\_id)]
	if {![string is integer -strict $id] && ($id != "*")} {
		LWDAQ_print $info(text) "ERROR: Bad device id \"$id\"."
		return "FAIL"
	}

	# Set the tool state variable.
	if {$info(state) != "Idle"} {return}
	set info(state) "Command"

	# Set the acknowledgement time and key.
	set ack_time [clock milliseconds]
	set config(ack_key) [expr $ack_time % 256]
	
	# Send battery measurement request.
	if {$config(ack_enable) && ($id != "*")} {
		Stimulator_transmit $n "11 $id 13 12 $config(ack_key)"
		lappend config(ack_pending) "$n $id Battery $ack_time"
	} elseif {$id != "*"} {
		Stimulator_transmit $n "11 $id 13"
	} else {
		Stimulator_transmit $n "13"
	}

	# Set state variables.
	set info(state) "Idle"
	
	return "SUCCESS"
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

	foreach n $info(device_list) {
		if {[set info(device$n\_id)] != "*"} {
			Stimulator_$action $n
		}
		LWDAQ_wait_seconds $config(spacing_delay_cmd)
	}

	return "SUCCESS"
}

#
# Clears the status and battery values of an stimulators in the list.
#
proc Stimulator_clear {n} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	LWDAQ_set_bg [set info(device$n\_state)] $config(soff_color)
	LWDAQ_set_fg [set info(device$n\_state)] $config(xoff_color)
	LWDAQ_set_bg [set info(device$n\_vbat_label)] $config(bnone_color)
	set info(device$n\_battery) "?"	

	return "SUCCESS"
}

#
# A background routine, which keeps posting itself to the
# Tcl event loop, which maintains the colors of the stimulator 
# indicators in the tool window.
#
proc Stimulator_monitor {} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info
	global LWDAQ_info_Recorder 
	upvar #0 $LWDAQ_info_Recorder(aux_list_name) aux
	global LWDAQ_Info
	
	if {![winfo exists $info(window)]} {return 0}
	if {$LWDAQ_Info(reset)} {return 0}
	set f $info(window).state

	set now_time [clock milliseconds]
	if {$now_time < $info(monitor_ms)} {
		LWDAQ_post Stimulator_monitor
		return "WAITING"
	} {
		set info(monitor_ms) [expr $now_time + $info(monitor_interval_ms)]
	}
	
	# Check the stimuli and mark device state label when stimulus is complete.
	foreach n $info(device_list) {
		set end_time [set info(device$n\_end)]
		if {($end_time > 0) && ($end_time <= $now_time)} {
			LWDAQ_set_bg [set info(device$n\_state)] $config(soff_color)
		}	
	}
	
	# If acknowledgement monitoring is enabled, check for their arrival. The 
	# acknowledgements we obtain from the Recorder Instrument's auxilliary
	# message list, which is accessible here by the name "aux". This list will
	# contain new acknowledgements only if the Recorder Instrument is downloading
	# live data, either because it is Looping, or because the Neuroarchiver is
	# calling it repeatedly to obtain and record the data.
	if {$config(ack_enable)} {
		# Look for acknowledgements. When we receive one, remove its pending
		# acknowledgement entry from the pending acknowledgement list.
		set new_aux [list]
		foreach am $aux {
			set match 0
			scan $am %d%d%d%d id fa db ts
			if {$fa == $config(ack_fa)} {
				set new_acks [list]
				foreach ack $config(ack_pending) {
					scan $ack %s%s%s%s n ack_id ack_type ack_time
					set ack_key [expr $ack_time % 256]
					if {($ack_id == $id) && ($ack_key == $db)} {
						if {$config(verbose)} {
							LWDAQ_print $info(text) "Acknowledgement Received:\
								device=$n id=$ack_id type=$ack_type key=$ack_key time=$ack_time\."
							LWDAQ_set_fg [set info(device$n\_index)] $config(ack_received_color)
						}
						set match 1
					} {
						lappend new_acks $ack
					}
				}
				set config(ack_pending) $new_acks
			}
			if {!$match} {lappend new_aux $am}
		}
		set aux $new_aux
		
		# If no acknowledgement has arrived within the acknowledgement timeout, issue
		# a warning that it hs not been received.
		set new_acks [list]
		foreach ack $config(ack_pending) {
			scan $ack %s%s%s%s n ack_id ack_type ack_time
			set ack_key [expr $ack_time % 256]
			if {$ack_time + $config(ack_timeout_ms) < $now_time} {
				LWDAQ_print $info(text) "Acknowledgement Lost:\
					device=$n id=$ack_id type=$ack_type key=$ack_key time=$ack_time\." \
					$config(ack_lost_color)
				LWDAQ_set_fg [set info(device$n\_index)] $config(ack_lost_color)
			} {
				lappend new_acks $ack
			}
		}
		set config(ack_pending) $new_acks
	}

	# Look for battery measurement reports in the auxilliary message list.
	set new_aux [list]
	set id_list [list]
	foreach n $info(device_list) {lappend id_list "$n [set info(device$n\_id)]"}
	foreach am $aux {
		scan $am %d%d%d%d id fa db ts
		
		# The battery measurements have only the device id to identify them, so
		# we look for the first device entry with a matching id and assume this
		# is the matching device. If we find no matching id, we move on to the
		# next message.
		set i [lsearch -index 1 $id_list $id]
		if {$i >= 0} {
			set n [lindex $id_list $i 0]
		} else {
			lappend new_aux $am	
			continue
		}
		
		# If an auxilliary message is a battery measurement, analyze and report.
		if {$fa == $config(bat_fa)} {
			# Report the battery measurement if verbose flag is set.
			if {$config(verbose)} {
				LWDAQ_print $info(text) "Battery: device=$n id=$id value=$db time=$ts\."
			}
			
			# We interpret battery measurements in a manner particular to the
			# various supported device versions.
			set ver [set info(device$n\_ver)]
			if {$ver == "A3030"} {
				scan $config(bat_calib_A3030) %f%f vref scale
				set voltage [format %.1f [expr 1.0 * ($db - $vref) / $scale]]
			} elseif {$ver == "A3036"} {
				scan $config(bat_calib_A3036) %f%f%f vref mref scale
				set voltage [format %.1f [expr $vref + 1.0 * ($db - $mref) / $scale]]
			} else {
				set voltage "?"
			}
			
			# Set the battery voltage indicator and set its background according
			# to the approximate state of the battery: okay, low, or empty. If
			# we were unable to interpret the battery voltage, we leave it as a
			# question mark.
			set info(device$n\_battery) $voltage	
			if {$voltage == "?"} {
				LWDAQ_set_bg [set info(device$n\_vbat_label)] $config(bnone_color)
			} elseif {$voltage > $config(blow)} {
				LWDAQ_set_bg [set info(device$n\_vbat_label)] $config(bokay_color)
			} elseif {$voltage > $config(bempty)} {
				LWDAQ_set_bg [set info(device$n\_vbat_label)] $config(blow_color)
			} else {
				LWDAQ_set_bg [set info(device$n\_vbat_label)] $config(bempty_color)
			}
		} {
			lappend new_aux $am
		}
	}
	set aux $new_aux
	
	# We post the monitor to the event queue and report success.
	LWDAQ_post Stimulator_monitor
	return "SUCCESS"
}

#
# Stimulator_undraw_list removes the stimulator list from the Stimulator window.
#
proc Stimulator_undraw_list {} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	foreach n $info(device_list) {
		set ff $info(window).device_list.device$n
		catch {destroy $ff}
	}
	
	return "SUCCESS"
}

#
# Stimulator_draw_list draws the current list of stimulators in the 
# Stimulator window.
#
proc Stimulator_draw_list {} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	set f $info(window).device_list
	if {![winfo exists $f]} {
		frame $f
		pack $f -side top -fill x
	}
	
	set padx $info(button_padx)
	
	foreach n $info(device_list) {
	
		# If this stimulator's state variable does not exist, then create it
		# now, as well as other system parameters.
		if {![info exists info(device$n\_ver)]} {
			set info(device$n\_ver) $config(default_device_version)
			set info(device$n\_sckt) "8"
			set info(device$n\_id) "$n"
			set info(device$n\_pulse_ms) "10"
			set info(device$n\_period_ms) "100"
			set info(device$n\_num_pulses) "10"
			set info(device$n\_random) "0"
			set info(device$n\_battery) "?"
			set info(device$n\_end) "0"
		}

		set g $f.device$n
		frame $g -relief sunken -bd 2
		pack $g -side top -fill x

		set ff $g.a
		frame $ff
		pack $ff -side top -fill x
		
		set info(device$n\_index) $ff.ln
		label $ff.ln -text "Device:"
		pack $ff.ln -side left -expand 1
		LWDAQ_set_fg [set info(device$n\_index)] $config(ack_received_color)

		set info(device$n\_state) $ff.n
		label $ff.n -text "$n" -width 4 
		pack $ff.n -side left -expand 1
		LWDAQ_set_fg $ff.n $config(xoff_color)
		LWDAQ_set_bg $ff.n $config(soff_color)

		foreach {a c} {id 3 sckt 2 pulse_ms 5 period_ms 5 num_pulses 5} {
			set b [string tolower $a]
			label $ff.l$b -text "$a\:" -fg $config(label_color)
			entry $ff.$b -textvariable Stimulator_info(device$n\_$b) -width $c
			pack $ff.l$b $ff.$b -side left -expand 1
		}

		checkbutton $ff.random -text "Random" \
			-variable Stimulator_info(device$n\_random)
		pack $ff.random -side left -expand yes

		set m [tk_optionMenu $ff.verm Stimulator_info(device$n\_ver) "none"]
		$m delete 0 end
		foreach version $config(device_versions) {
			$m add command -label [lindex $version 0] \
				-command [list set Stimulator_info(device$n\_ver) [lindex $version 0]]
		}	
		pack $ff.verm -side left -expand 1

		foreach {a c} {Start green Stop black Xon green Xoff black Battery green} {
			set b [string tolower $a]
			button $ff.$b -text $a -padx $padx -fg $c -command \
				[list LWDAQ_post "Stimulator_$b $n" front]
			pack $ff.$b -side left -expand 1
		}

		set info(device$n\_vbat_label) [label $ff.vbat -textvariable \
			Stimulator_info(device$n\_battery) \
			-width 3 -bg $config(bnone_color) -fg black]
		pack $ff.vbat -side left -expand 1

		button $ff.delete -text "X" -padx $padx -command \
			[list LWDAQ_post "Stimulator_ask_remove $n" front]
		pack $ff.delete -side left -expand yes
	}
	
	return "SUCCESS"
}

#
# Stimulator_ask_remove ask if the user is certain they want to remove an 
# stimulator from the list.
#
proc Stimulator_ask_remove {n} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	# Find the stimulator in our list.
	set index [lsearch $info(device_list) $n]
	
	# Exit if the stimulator does not exist.
	if {$index < 0} {
		LWDAQ_print $info(text) "ERROR: No stimulator with list index $n."
		return "ERROR"
	}
	
	set w $info(window)\.remove$n
	if {[winfo exists $w]} {
		raise $w
		return "FAIL"
	}
	toplevel $w
	wm title $w "Remove Device Number $info(device$n\_id)"
	label $w.q -text "Remove Device Number $info(device$n\_id)?" \
		-padx 10 -pady 5 -fg purple
	button $w.yes -text "Yes" -padx 10 -pady 5 -command \
		[list LWDAQ_post "Stimulator_remove $n" front]
	button $w.no -text "No" -padx 10 -pady 5 -command \
		[list LWDAQ_post "destroy $w" front]
	pack $w.q $w.yes $w.no -side left -expand yes

	return "SUCCESS"
}

#
# Stimulator_remove remove a stimulator from the list.
#
proc Stimulator_remove {n} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	# Find the stimulator in our list.
	set index [lsearch $info(device_list) $n]
	
	# If a remove window exists, destroy it
	set w $info(window)\.remove$n
	if {[winfo exists $w]} {destroy $w}

	# Exit if the stimulator does not exist.
	if {$index < 0} {
		LWDAQ_print $info(text) "ERROR: No stimulator with list index $n."
		return "ERROR"
	}
	
	# Destroy the device window frame, remove the device from our
	# list, and unset its variables.
	catch {destroy $info(window).device_list.device$n}
	set info(device_list) [lreplace $info(device_list) $index $index]
	unset info(device$n\_id)
	unset info(device$n\_ver)
	unset info(device$n\_sckt)
	unset info(device$n\_battery)
	unset info(device$n\_pulse_ms) 
	unset info(device$n\_period_ms) 
	unset info(device$n\_num_pulses) 
	unset info(device$n\_random)
	unset info(device$n\_end)
	
	return "SUCCESS"
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
	while {[lsearch $info(device_list) $n] >= 0} {
		incr n
	}
	
	# Add the new sensor index to the list.
	lappend info(device_list) $n
	
	# Configure the new sensor to default values.
	set info(device$n\_id) "$n"
	set info(device$n\_ver) "A3036"
	set info(device$n\_sckt) "8"
	set info(device$n\_pulse_ms) "10"
	set info(device$n\_period_ms) "100"
	set info(device$n\_num_pulses) "10"
	set info(device$n\_random) "0"
	set info(device$n\_end) "0"
	
	set info(device$n\_battery) "?"
	
	# Re-draw the sensor list.
	Stimulator_draw_list
	
	return "SUCCESS"
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
		if {$fn == ""} {return "FAIL"}
	}

	# Write stimulator list to disk.
	set f [open $fn w]
	puts $f "set Stimulator_info(device_list) \"$info(device_list)\""
	foreach p [lsort -dictionary [array names info]] {
		if {[regexp {device[0-9]+_} $p]} {
			puts $f "set Stimulator_info($p) \"[set info($p)]\"" 
		}
	}
	close $f
	
	# Change the stimulator list file parameter.
	set config(device_list_file) $fn

	return "SUCCESS"
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
		if {$fn == ""} {return "FAIL"}
	} else {
		if {![file exists $fn]} {return "FAIL"}
	}

	# Undraw the list, run the stimulator list file, and re-draw the list.
	if {[catch {
		Stimulator_undraw_list	
		set info(device_list) [list]
		uplevel #0 [list source $fn]
		Stimulator_draw_list
		foreach n $info(device_list) {
			LWDAQ_set_bg [set info(device$n\_state)] $config(soff_color)
			LWDAQ_set_fg [set info(device$n\_state)] $config(xoff_color)
			set info(device$n\_battery) "?"
		}
	} error_message]} {
		LWDAQ_print $info(text) "ERROR: $error_message."
		return
	}
	
	# Change the stimulator list file name to match the newly-loaded file.
	set config(device_list_file) $fn
	
	return "SUCCESS"
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
		if {[string match "device$n\_*" $p]} {
			set pp [regsub $n $p $m]
			set info($pp) [set info($p)]
			unset info($p)
		}
	}
}

#
# Stimulator_refresh_list assigns ascending, consecutive device
# numbers to the existing rows of the device list. It clears all state
# indication colors and battery values.
#
proc Stimulator_refresh_list {{fn ""}} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info
	
	Stimulator_undraw_list	

	set new_list [list]
	set m 1000
	foreach n $info(device_list) {
		Stimulator_rename_device $n $m
		lappend new_list "$m $info(device$m\_id)"
		incr m
	}
	set new_list [lsort -increasing -integer -index 1 $new_list]
	
	set info(device_list) [list]
	set m 1
	foreach device $new_list {
		set n [lindex $device 0]
		Stimulator_rename_device $n $m
		set info(device$m\_battery) "?"
		lappend info(device_list) $m
		incr m
	}
	unset new_list
	
	Stimulator_draw_list
	
	return "SUCCESS"
}

#
# Stimulator_txcmd opens a new window and provides a button for transmitting 
# a string of command bytes, each expressed as a decimal value 0..255, to a
# particular socket on the driver specified in the main window.
#
proc Stimulator_tx_cmd {} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info
	
	# Open the transmit panel.
	set w $info(window)\.txcmd
	if {[winfo exists $w]} {
		raise $w
		return "ABORT"
	}
	toplevel $w
	wm title $w "Stimulator $info(version) Transmit Command Panel"

	set f [frame $w.tx]
	pack $f -side top -fill x

	button $f.transmit -text "Transmit" \
		-command [list LWDAQ_post "Stimulator_transmit 0"]
	pack $f.transmit -side left -expand yes

	label $f.lsckt -text "sckt:" -fg $config(label_color)
	entry $f.esckt -textvariable Stimulator_info(device0_sckt) -width 3
	pack $f.lsckt $f.esckt -side left -expand yes
	
	label $f.lcommands -text "command:" -fg $config(label_color)
	entry $f.commands -textvariable Stimulator_config(commands) -width 50
	pack $f.lcommands $f.commands -side left -expand yes

	return "SUCCESS" 
}

#
# Opens the tool window and makes all its controls.
#
proc Stimulator_open {} {
	upvar #0 Stimulator_config config
	upvar #0 Stimulator_info info

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return 0}
	
	set f $w.controls
	frame $f
	pack $f -side top -fill x
	
	label $f.state -textvariable Stimulator_info(state) \
		-width 12 -fg blue
	pack $f.state -side left -expand 1
	
	label $f.laddr -text "ip_addr:" -fg $config(label_color)
	entry $f.eaddr -textvariable Stimulator_config(ip_addr) -width 14
	pack $f.laddr $f.eaddr -side left -expand yes

	checkbutton $f.enack -text "Acknowledge" \
		-variable Stimulator_config(ack_enable)
	pack $f.enack -side left -expand yes
	checkbutton $f.verbose -text "Verbose" \
		-variable Stimulator_config(verbose) 
	pack $f.verbose -side left -expand yes

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
	
	foreach a {Add_Device Save_List Load_List Refresh_List Tx_Cmd} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post Stimulator_$b"
		pack $f.$b -side left -expand 1
	}
	
	if {[llength $info(device_list)] == 0} {
		Stimulator_add_device
	} else {
		Stimulator_draw_list
	}

	set info(text) [LWDAQ_text_widget $w 80 15]

	# If the device list file exist, load it.
	if {[file exists $config(device_list_file)]} {
		Stimulator_load_list $config(device_list_file)
	}
	
	return 1
}

# Start up the tool. We call the monitor routine, which sets the monitor 
# working in the background to maintain the stimulator status 
Stimulator_init
Stimulator_open
Stimulator_monitor

return 1

----------Begin Help----------

http://www.opensourceinstruments.com/Electronics/A3030/ISL.html#Software

----------End Help----------

----------Begin Data----------

----------End Data----------