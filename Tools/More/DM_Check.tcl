# Detector Module Check, A LWDAQ Tool.
#
# Copyright (C) 2025, Kevan Hashemi, Open Source Instruments Inc.
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

proc DM_Check_init {} {
	upvar #0 DM_Check_info info
	upvar #0 DM_Check_config config
#
# Set up the tool within LWDAQ.
#
	LWDAQ_tool_init "DM_Check" "1.0"
	if {[winfo exists $info(window)]} {return ""}
#
# Process control variabls.
#
	set info(control) "Idle"
#
# Default value for the generator USB port.
#
	set config(gen_port) "/dev/cu.usbserial-14140"
	set info(gen_chan) "none"
#
# The RFX devices support 2400 baud and 500 kbaud. The latter is non-standard, so
# we choose to use the slower 2400 baud. But this is fast enough for our purposes.
# We also have a delay to allow the generator to adjust its output.
#
	set config(gen_baud) "2400"
	set config(gen_wait_ms) "200"
#
# Incoming USB data buffers.
#
	set info(gen_buff) ""
#
# Boundaries for both the fast sweep we use to tune the detector module, and the slow
# sweep to measure the gain of the preamplifier and the response of the demodulator.
	set config(sweep_low) "880.000"
	set config(sweep_high) "950.000"
	set config(sweep_dwell_us) "4"
#
# Calibration constants of the A3008E we use to generate the fast sweep.
#
	set config(A3008E_f_ref) "915.0"
	set config(A3008E_dac_ref) "57.2"
	set config(A3008E_slope) "0.824"
	set info(A3008E_start_cmd) "81"
	set info(A3008E_end_cmd) "82"
	set info(A3008E_dwell_cmd) "83"
	set config(A3008E_ip_addr) "192.168.1.11"
	set config(A3008E_driver_socket) "2"
#
# Target parameters for our A3057B, which reads the P and D outputs from the detector
# module.
#
	set config(A2057B_ip_addr) "192.168.1.11"
	set config(A2057B_driver_socket) "8"
#
# Power values for our measurement, to be applied for each frequency. Also, an
# attenuator value, in case we put an attenuator in between the generator and
# our detector module.
#
	set config(meas_step) "2.0"
	set config(meas_pwrs) "-40 -30 -20 -10 0"
	set config(attenuator) "30"
	
# Display parameters.
#
	set info(text) "stdout"
	set info(sweep_display_photo) "_dmt_sweep_photo_"
	set info(sweep_display_image) "_dmt_sweep_img_"
	set info(sweep_display_height) "300"
	set info(sweep_display_width) "1000"
	set config(sweep_display_color) "5"
#
# Display initialization.
#
	lwdaq_image_destroy $info(sweep_display_image)
	lwdaq_image_create -name $info(sweep_display_image) \
		-width $info(sweep_display_width) \
		-height $info(sweep_display_height)
	lwdaq_graph "0 0" $info(sweep_display_image) -fill 1 \
			-x_min 0 -x_max 1 -x_div 0.1 \
			-y_min 0 -y_max 1 -y_div 0.1 \
			-color 1  
#
# Look for a saved configuration file, and if we find one, load it.
#
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 
#
# Empty string return means all well.
#
	return ""	
}

proc DM_Check_configure {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info

	set f [LWDAQ_tool_configure DM_Check 3]

	return ""
}

#
# DM_Check_command takes a list of one or more commands and writes them to the
# RF Explorer. 
#
proc DM_Check_command {{commands ""}} {
	upvar #0 DM_Check_info info
	upvar #0 DM_Check_config config

	foreach cmd [string trim $commands] {
		set len [expr 2 + [string length $cmd]]
		set data [binary format c* "0x23 $len"]
		append data $cmd
		if {[catch {
			puts -nonewline $info(gen_chan) $data
			flush $info(gen_chan)
			LWDAQ_print $info(text) "Command: $commands" green
		} error_result]} {
			LWDAQ_print $info(text) "ERROR: $error_result"
			break
		}
		LWDAQ_update
	}
}

#
# DM_Check_connect opens a channel to the RF Explorer generator, starts the
# read engine, and requests a configuration report.
#
proc DM_Check_connect {} {
	upvar #0 DM_Check_info info
	upvar #0 DM_Check_config config

	
	LWDAQ_print $info(text) "Opening port $config(gen_port)..."
	if {[catch {
		set info(gen_chan) [open $config(gen_port) RDWR]
		fconfigure $info(gen_chan) -mode $config(gen_baud),n,8,1 \
			-translation binary \
			-buffering none \
			-blocking 0
		DM_Check_gen_read
		LWDAQ_print $info(text) "Port opened channel $info(gen_chan),\
			read engine started."
		DM_Check_command "C0"
	} error_result]} {
		LWDAQ_print $info(text) "ERROR: $error_result"
		catch {close $info(gen_chan)}
	}
	return $info(gen_chan)
}

#
# DM_Check_diconnect closes the channel to the RF Explorer generator.
#
proc DM_Check_disconnect {} {
	upvar #0 DM_Check_info info
	upvar #0 DM_Check_config config
	
	if {[catch {
		close $info(gen_chan)
		LWDAQ_print $info(text) "Closed $info(gen_chan) connection\
			to port $config(gen_port)."
	} error_result]} {
		LWDAQ_print $info(text) "ERROR: $error_result"
	}
	return ""
}

#
# DM_Check_gen_read reads from the USB incoming buffer and transfers to our own
# buffer. It looks to see if the buffer is a sweep data block, which will be
# true if it begins with "$S". It looks for return messages. It displays sweeps
# in the sweep plot and stores the most recent sweep in the rxf(sweep) list. It
# prints returned messages of type "C" and "S" to the text window. The routine
# takes one parameter "post", which is by default "1", but if cleared to "0",
# the routine will not post itself to the event queue, so it acts as a one-time
# message retrieval.
#
proc DM_Check_gen_read {{post "1"}} {
	upvar #0 DM_Check_info info
	upvar #0 DM_Check_config config

	if {![winfo exists $info(text)]} {
		DM_Check_disconnect
		return ""
	}
	if {[catch {append info(gen_buff) [read $info(gen_chan)]}]} {
		LWDAQ_print $info(text) "Stopping read engine for $config(gen_port)."
		set info(gen_buff) ""
		return ""
	}
	
	while {[regexp -indices {(\r\n|\r)} $info(gen_buff) match]} {
		foreach {start end} $match {
			set line [string range $info(gen_buff) 0 [expr {$start-1}]]
			set info(gen_buff) [string range $info(gen_buff) [expr {$end+1}] end]
			if {[string match "#C*" $line] || [string match "#S*" $line]} {
				LWDAQ_print $info(text) "Message: [string range $line 1 end]" green
			}
		}
	}
	
	if {$post} {LWDAQ_post [list DM_Check_gen_read]}
	return ""
}

#
# DM_Check_gen_on turns on the generator and sets its frequency and power.
#
proc DM_Check_gen_on {freq pwr} {
	upvar #0 DM_Check_info info
	upvar #0 DM_Check_config config
	
	set cmd "C5-F:"
	append cmd "[format %07d [expr round(1000*$freq)]],"
	if {$pwr < 0} {
		append cmd "[format -%03.1f [expr abs(round($pwr))]]"
	} else {
		append cmd "[format +%03.1f [expr abs(round($pwr))]]"
	}
	DM_Check_command $cmd
	return "$cmd"
}

#
# DM_Check_gen_off turns off the generator.
#
proc DM_Check_gen_off {} {
	upvar #0 DM_Check_info info
	upvar #0 DM_Check_config config
	
	catch {DM_Check_command "CP0"}
	return ""
}

#
# DM_Check_sweep_on turns on the A3008E sweep, set to the sweep start and 
# sweep end frequencies.
#
proc DM_Check_sweep_on {} {
	upvar #0 DM_Check_info info
	upvar #0 DM_Check_config config
	
	LWDAQ_print $info(text) "Sweep On:\
		$config(sweep_low) to $config(sweep_high) MHz." purple
		
	set dwell [expr round($config(sweep_dwell_us) - 1)]
	set low [expr round( \
		($config(sweep_low)-$config(A3008E_f_ref))/$config(A3008E_slope) \
		+ $config(A3008E_dac_ref) )]
	set high [expr round( \
		($config(sweep_high)-$config(A3008E_f_ref))/$config(A3008E_slope) \
		+ $config(A3008E_dac_ref))]
	LWDAQ_print $info(text) "DAC Start $low, DAC End $high, Dwell $dwell" green 

	if {[catch {
		set sock [LWDAQ_socket_open $config(A3008E_ip_addr)]
		LWDAQ_set_driver_mux $sock $config(A3008E_driver_socket) 0
		LWDAQ_transmit_command_hex $sock "[format %02X $low]$info(A3008E_start_cmd)"
		LWDAQ_transmit_command_hex $sock "[format %02X $high]$info(A3008E_end_cmd)"
		LWDAQ_transmit_command_hex $sock "[format %02X $dwell]$info(A3008E_dwell_cmd)"
		LWDAQ_wait_for_driver $sock
		LWDAQ_socket_close $sock
	} error_result]} { 
		if {[info exists sock]} {LWDAQ_socket_close $sock}
		return "ERROR: $error_result"
	}	
		
	return ""
}

#
# DM_Check_sweep_off turns on the A3008E sweep, seeing the sweep to a
# low, constant frequency.
#
#
proc DM_Check_sweep_off {} {
	upvar #0 DM_Check_info info
	upvar #0 DM_Check_config config

	if {[catch {
		set sock [LWDAQ_socket_open $config(A3008E_ip_addr)]
		LWDAQ_set_driver_mux $sock $config(A3008E_driver_socket) 0
		LWDAQ_transmit_command_hex $sock "00$info(A3008E_start_cmd)"
		LWDAQ_transmit_command_hex $sock "00$info(A3008E_end_cmd)"
		LWDAQ_transmit_command_hex $sock "01$info(A3008E_dwell_cmd)"
		LWDAQ_wait_for_driver $sock
		LWDAQ_socket_close $sock
	} error_result]} { 
		if {[info exists sock]} {LWDAQ_socket_close $sock}
		return "ERROR: $error_result"
	}
	LWDAQ_print $info(text) "Sweep Off" purple
	return ""
}

#
# DM_Check_measure starts at the sweep minimum frequency, applies it to the
# generator, and proceeds to the maximum frequency in steps. At each step, it
# measures the values of the detector module's P and D signals for a selection
# of power values at a particular frequency. To abort, we use the control
# variable set to Stop. We pass one parameter into the sweep: the frequency. If
# the frequency we pass is an empty string, the routine knows a sweep is
# starting, so it picks the sweep low frequency.
#
proc DM_Check_measure {{freq ""}} {
	upvar #0 DM_Check_info info
	upvar #0 DM_Check_config config
	upvar #0 LWDAQ_config_Voltmeter iconfig

	if {$info(control) == "Stop"} {
		catch {DM_Check_gen_off}
		set info(control) "Idle"
		LWDAQ_print $info(text) "Measurement Aborted" purple
		DM_Check_command "CP0"
		return ""
	}
	
	if {$freq == ""} {
		LWDAQ_print $info(text) "Measurement Starting:\
			$config(sweep_low) to $config(sweep_high) MHz" purple
		set info(control) "Measure"
		set freq $config(sweep_low)
		set info(measurement) ""
	} 
	
	set line "$freq "
	foreach pwr $config(meas_pwrs) {
		DM_Check_gen_on $freq $pwr
		LWDAQ_wait_ms $config(gen_wait_ms)
		DM_Check_gen_read 0
		set iconfig(analysis_auto_calib) "1"
		set iconfig(daq_driver_socket) $config(A2057B_driver_socket)
		set iconfig(daq_ip_addr) $config(A2057B_ip_addr)
		set iconfig(daq_device_element) "1 2"
		set iconfig(daq_hi_gain) "0"
		set result [LWDAQ_acquire Voltmeter]
		append line "[format %.3f [lindex $result 1]] "
		append line "[format %.3f [lindex $result 5]] "
	}
	LWDAQ_print $info(text) "$line"
	lappend info(measurement) [string trim $line]
	
	if {$freq < $config(sweep_high)} {
		set freq [format %.3f [expr $freq + $config(meas_step)]]
		LWDAQ_post [list DM_Check_measure $freq]
	} else {
		LWDAQ_print $info(text) "Measurement Complete" purple
		DM_Check_command "CP0"
		set title "Freq "
		foreach pwr $config(meas_pwrs) {
			append title "P[format %.1f [expr $pwr - $config(attenuator)]]\
				D[format %.1f [expr $pwr - $config(attenuator)]] "
		}
		LWDAQ_print $info(text) $title 
		foreach m $info(measurement) {
			LWDAQ_print $info(text) $m
		}
		set info(control) "Idle"
	}
	
	return "$freq"
}


#
# DM_Check_stop sends a stop command to the analyzer so that it will stop sending
# sweep data, which it otherwise does continuously.
#
proc DM_Check_stop {} {
	upvar #0 DM_Check_config config
	upvar #0 DM_Check_info info
	
	if {$info(control) != "Idle"} {
		set info(control) "Stop"
	} 
	DM_Check_command "CP0"
	return ""
}

#
# DM_Check_open opens the tool window and creates the graphical user interface.
#
proc DM_Check_open {} {
	upvar #0 DM_Check_config config
	upvar #0 DM_Check_info info
		
	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
		
	set f [frame $w.control]
	pack $f -side top -fill x
	
	label $f.control -textvariable DM_Check_info(control) -fg blue -width 8
	pack $f.control -side left -expand yes

	foreach a {Connect Disconnect Sweep_On Sweep_Off Measure Stop Configure Help} {
		set b [string tolower $a]
		button $f.b$b -text $a -command "LWDAQ_post [list DM_Check_$b]"
		pack $f.b$b -side left -expand yes
	}
	
	set f [frame $w.parameters]
	pack $f -side top -fill x
	
	foreach {a width} {gen_port 25 sweep_low 8 sweep_high 8\
			meas_step 4 meas_pwrs 16 attenuator 4} {
		label $f.l$a -text "$a:"
		entry $f.e$a -textvariable DM_Check_config($a) -width $width
		pack $f.l$a $f.e$a -side left -expand yes
	}

	set f [frame $w.display]
	pack $f -side top -fill x
	
	image create photo $info(sweep_display_photo)
	label $f.img -image $info(sweep_display_photo)
	pack $f.img -side top
	lwdaq_draw $info(sweep_display_image) $info(sweep_display_photo)
	
	set info(text) [LWDAQ_text_widget $w 100 20]
	LWDAQ_print $info(text) "$info(name) Version $info(version)\n" purple
	
	return $w	
}


#
# DM_Check_help prints some example commands we can send to the RFX, and provides a 
# web link to the RF Explorer UART API.
#
proc DM_Check_help {} {
	upvar #0 DM_Check_info info
	upvar #0 DM_Check_config config
	
	LWDAQ_print $info(text) {
[08-OCT-25] Kevan Hashemi, Open Source Instruments Inc.
	} brown
}


DM_Check_init
DM_Check_open
