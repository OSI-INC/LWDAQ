# Function Generator, a LWDAQ Tool.
#
# Copyright (C) 2024 Nathan Sayer, Open Source Instruments Inc.
#

proc Function_Generator_init {} {
	upvar #0 Function_Generator_info info
	upvar #0 Function_Generator_config config
	global LWFG

	LWDAQ_tool_init "Function_Generator" "1.1"
	if {[winfo exists $info(window)]} {return ""}

	set info(data) [list]
	set info(start_time) "0"
	set info(channel_names) "1"

	set info(control) "Idle"
	set config(verbose) "0"
	set config(logarithmic) "0"
	set config(attnsw) "0.0dB"

	set config(gen_ip) "10.0.0.37"
	set config(gen_ch) [lindex $info(channel_names) 0]
	
	set config(waveform_type) "sine"
	set config(waveform_amplitude) "10"
	set config(waveform_offset) "0"
	set config(waveform_frequency) "10"

	set config(sweep_start_frequency) "1"
	set config(sweep_stop_frequency) "500"
	set config(sweep_time) "1"

	set config(label_color) "green"

# Setting variables for the LWFG package

	set LWFG(data_portal) "63"
	set LWFG(ch1_ram) "0x0000"
	set LWFG(ch1_rc) "0x8000"
	set LWFG(ch1_div) "0x8002"
	set LWFG(ch1_len) "0x800A"

	set LWFG(ch2_ram) "0x4000"
	set LWFG(ch2_rc) "0x8001"
	set LWFG(ch2_div) "0x8006"
	set LWFG(ch2_len) "0x800C"
	set LWFG(attenuation) "0x800E"

	set LWFG(max_pts) "8192"
	set LWFG(min_pts) "4000"
	set LWFG(clock_hz) "40.000e6"
	set LWFG(div_min) "2"

	set LWFG(ch_cnt_lo) "0"
	set LWFG(ch_cnt_z) "128"
	set LWFG(ch_cnt_hi) "255"
	set LWFG(ch_v_lo) "-10.0"
	set LWFG(ch_v_hi) "+10.0"

	set LWFG(rc_options) "1.3e1 0x01 5.1e1 0x11 1.1e2 0x21 2.7e2 0x14 5.6e2 0x18 1.1e3 0x21 \
		2.4e3 0x22 5.9e3 0x24 1.2e4 0x28 2.6e4 0x41 5.5e4 0x42 1.4e5 0x44 \
		2.8e5 0x48 1.0e6 0x81 2.2e6 0x82 5.4e6 0x84 1.1e7 0x88"
	set LWFG(rc_fraction) "0.01"
	set LWFG(rc_default) "0x11"

	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	}

	return ""
}

# Output one constant frequency
proc Function_Generator_on {} {
	upvar #0 Function_Generator_info info
	upvar #0 Function_Generator_config config
	global LWFG

	LWDAQ_print $info(text) "Channel $config(gen_ch), $config(waveform_type),\
		$config(waveform_frequency) Hz,\
		$config(waveform_amplitude) V amplitude,\
		$config(waveform_offset) V offset." purple

	# Determine the bounds of the waveform
	set v_lo [expr $config(waveform_offset) - $config(waveform_amplitude)]
	set v_hi [expr $config(waveform_offset) + $config(waveform_amplitude)]
	set result [LWFG_configure $config(gen_ip) $config(gen_ch) \
		$config(waveform_type) \
		$config(waveform_frequency) \
		$v_lo $v_hi]
	if {[LWDAQ_is_error_result $result]} {
		LWDAQ_print $info(text) $result 
	} elseif {$config(verbose)} {
		foreach a {dac_lo dac_hi divisor num_pts num_cycles} {
			set $a [lindex $result 0]
			LWDAQ_print $info(text) "$a = [lindex $result 0]"
			set result [lrange $result 1 end]
		}
		LWDAQ_print $info(text) "rc = [format %3.f [expr 0.001*[lindex $result 0]]] us"
		set actual [expr $LWFG(clock_hz)*$num_cycles/$num_pts/$divisor]
		LWDAQ_print $info(text) "actual = [format %.3f $actual] Hz"
		LWDAQ_print $info(text) "requested = [format %.3f $config(waveform_frequency)] Hz"
	}
}

# LWFG_configure configures a function generator for continuous generation of a square,
# triangle, or sine wave. We specify an IP address and channel number. We give the 
# frequency and the low and high voltages of the waveform.
#
proc LWFG_configure {ip ch_num waveform frequency v_lo v_hi} {
	upvar #0 Function_Generator_info info
	upvar #0 Function_Generator_config config
	global LWFG

	# Determine the lower and upper DAC values for our lower and upper waveform
	# voltages.
	set lsb [expr ($LWFG(ch_v_hi) - $LWFG(ch_v_lo)) \
		/ ($LWFG(ch_cnt_hi) - $LWFG(ch_cnt_lo))]
	set dac_lo [expr round(($v_lo - $LWFG(ch_v_lo)) / $lsb)]
	set dac_hi [expr round(($v_hi - $LWFG(ch_v_lo)) / $lsb)]

	# We begin by getting getting the number of points we need for one period
	# with the fastest sample rate, and if num_pts is too large, we increase
	# the divisor until num_pts is small enough.
	set divisor $LWFG(div_min)
	set num_pts [expr round($LWFG(clock_hz) / $frequency / $divisor)]
	while {$num_pts > $LWFG(max_pts)} {
		incr divisor
		set num_pts [expr round($LWFG(clock_hz) / $frequency / $divisor)]
	}
	
	# If num_pts is too small, we increase the number of cycles in the waveform
	# and recalculate our number of points until it is large enough.
	set num_cycles 1
	while {$num_pts < $LWFG(min_pts)} {
		incr num_cycles
		set num_pts [expr round($LWFG(clock_hz) * $num_cycles / $frequency / $divisor)]
	}

	# Calculate the actual frequency we are going to get.
	set actual [format %.3f [expr $LWFG(clock_hz)*$num_cycles/$num_pts/$divisor]]
	
	# Generate the waveform.
	set values [list]
	set period [expr 1.0*$num_pts/$num_cycles]
	switch $waveform {
		"sine" {
			set pi 3.141592654
			for {set i 0} {$i < $num_pts} {incr i} {
				set phase [expr fmod($i,$period)/$period]
				lappend values [expr $dac_lo + \
					round(($dac_hi-$dac_lo)*0.5*(1.0+sin(2*$pi*$phase)))]
			}
		}
		"square" {
			for {set i 0} {$i < $num_pts} {incr i} {\
				set phase [expr fmod($i,$period)/$period]
				if {$phase <= 0.5} { 
					lappend values $dac_hi
				} else {
					lappend values $dac_lo
				}
			}
		}
		"triangle" {
			for {set i 0} {$i < $num_pts} {incr i} {\
				set phase [expr fmod($i,$period)/$period]
				if {$phase <= 0.5} { 
					lappend values [expr $dac_lo + \
						round(($dac_hi-$dac_lo)*$phase*2.0)]
				} else {
					lappend values [expr $dac_hi - \
						round(($dac_hi-$dac_lo)*($phase-0.5)*2.0)]
				}
			}
		}
		default {
			return "ERROR: Unkown waveform \"$waveform\"."
		}
	}
	
	# Limit the values to the range 0 to 255.
	set clipped_values [list]
	foreach value $values {
		if {$value < 0} {set value 0}
		if {$value > 255} {set value 255}
		lappend clipped_values $value
	}
	set values $clipped_values
	
	# Choose the filter.
	set rc [lindex $LWFG(rc_options) 0]
	set filter [lindex $LWFG(rc_options) 1]
	switch $waveform {
		"sine"     - 
		"triangle" {
			set ideal_rc [expr 1.0E9/$frequency*$LWFG(rc_fraction)]
			foreach {p code} $LWFG(rc_options) {
				if {$p < $ideal_rc} {
					set filter $code
					set rc $p
				}
			}
		}
	}


	
	# Configure the function generator using TCPIP messaging.
	if {[catch {
	
		# Open a socket to the function generator.
		set sock [LWDAQ_socket_open $ip]
		
		# Write the waveform values to the waveform memory.
		LWDAQ_set_data_addr $sock $LWFG(ch$ch_num\_ram)
		LWDAQ_stream_write $sock $LWFG(data_portal) [binary format c* $values]
		
		# Set the filter configuration register.
		LWDAQ_set_data_addr $sock $LWFG(ch$ch_num\_rc)
		LWDAQ_stream_write $sock $LWFG(data_portal) [binary format c [expr $filter]]
		
		# Set the clock divisor.
		LWDAQ_set_data_addr $sock $LWFG(ch$ch_num\_div)
		LWDAQ_stream_write $sock $LWFG(data_portal) [binary format I [expr $divisor - 1]]
		
		# Set the waveform length.
		LWDAQ_set_data_addr $sock $LWFG(ch$ch_num\_len)
		LWDAQ_stream_write $sock $LWFG(data_portal) [binary format S [expr $num_pts - 1]]
		
		# Wait for the controller to be done with configuration.
		set id [LWDAQ_hardware_id $sock]
		
		# Close the socket.
		LWDAQ_socket_close $sock
	} error_message]} {
		catch {LWDAQ_socket_close $sock}
		return "ERROR: $error_message\."
	}
	
	# Return enough information about the waveform for us to assess accuracy.
	return "$dac_lo $dac_hi $divisor $num_pts $num_cycles [format %.0f $rc]"
}


proc Function_Generator_off {} {
	upvar #0 Function_Generator_info info 
	upvar #0 Function_Generator_config config 
	global LWFG

	LWDAQ_print $info(text) "Channel $config(gen_ch), 0 V amplitude, 0 V offset." purple
	set result [LWFG_off $config(gen_ip) $config(gen_ch)]
	if {[LWDAQ_is_error_result $result]} {
		LWDAQ_print $info(text) $result
	}
	
	return ""
}

proc LWFG_off {ip ch_num} {
	upvar #0 Function_Generator_info info 
	upvar #0 Function_Generator_config config 
	global LWFG

	# Configure the function generator for zero output.
	if {[catch {

		# Open a socket to the function generator.
		set sock [LWDAQ_socket_open $ip]
		
		# Write a single zero to the waveform memory.
		LWDAQ_set_data_addr $sock $LWFG(ch$ch_num\_ram)
		LWDAQ_stream_write $sock $LWFG(data_portal) [binary format c $LWFG(ch_cnt_z)]
		
		# Set the filter configuration register to its default value.
		LWDAQ_set_data_addr $sock $LWFG(ch$ch_num\_rc)
		LWDAQ_stream_write $sock $LWFG(data_portal) [binary format c $LWFG(rc_default)]
		
		# Set the clock divisor to one, for which we write a zero.
		LWDAQ_set_data_addr $sock $LWFG(ch$ch_num\_div)
		LWDAQ_stream_write $sock $LWFG(data_portal) [binary format I 0]
		
		# Set the waveform length to zero.
		LWDAQ_set_data_addr $sock $LWFG(ch$ch_num\_len)
		LWDAQ_stream_write $sock $LWFG(data_portal) [binary format S 0]
		
		# Wait for the controller to be done with configuration.
		set id [LWDAQ_hardware_id $sock]
		
		# Close the socket.
		LWDAQ_socket_close $sock
	} error_message]} {
		catch {LWDAQ_socket_close $sock}
		return "ERROR: $error_message\."
	}

	return ""
}
	
# Output a waveform with changing frequency
proc Function_Generator_sweep {} {

	upvar #0 Function_Generator_info info 
	upvar #0 Function_Generator_config config 
	global LWFG

	LWDAQ_print $info(text) "Channel $config(gen_ch), $config(waveform_type),\
		$config(sweep_start_frequency) Hz to $config(sweep_stop_frequency) Hz over\
		$config(sweep_time) seconds,\
		$config(waveform_amplitude) V amplitude,\
		$config(waveform_offset) V offset." purple

	set v_lo [expr $config(waveform_offset) - $config(waveform_amplitude)]
	set v_hi [expr $config(waveform_offset) + $config(waveform_amplitude)]
	set waveform $config(waveform_type)
	set sweep_period $config(sweep_time)
	set start_frequency $config(sweep_start_frequency)
	set stop_frequency $config(sweep_stop_frequency)
	set ch_num $config(gen_ch)
	set ip $config(gen_ip)

	# Determine the lower and upper DAC values for our lower and upper waveform
	# voltages.
	set lsb [expr ($LWFG(ch_v_hi) - $LWFG(ch_v_lo)) \
		/ ($LWFG(ch_cnt_hi) - $LWFG(ch_cnt_lo))]
	set dac_lo [expr round(($v_lo - $LWFG(ch_v_lo)) / $lsb)]
	set dac_hi [expr round(($v_hi - $LWFG(ch_v_lo)) / $lsb)]

	# We begin by getting getting the number of points we need for one period
	# with the fastest sample rate, and if num_pts is too large, we increase
	# the divisor until num_pts is small enough.
	set num_pts $LWFG(max_pts)
	set num_cycles 1
	set divisor [expr round(($LWFG(clock_hz) * $sweep_period) / $num_pts) - "1"]
	
	# Generate the waveform.
	set values [list]
	set period [expr 1.0*$num_pts/$num_cycles]
	switch $waveform {
		"sine" {
			set pi 3.141592654
			for {set i 0} {$i < $num_pts} {incr i} {
				set phase [expr fmod($i,$period)/$period]
				if {$config(logarithmic) == "0"} {
					lappend values [expr $dac_lo + \
						round(($dac_hi - $dac_lo) * 0.5 * \
							(1.0+sin(2*$pi*$sweep_period*(($start_frequency+ \
								(($stop_frequency-$start_frequency)/2)*$phase)*$phase))))]
				} else {
					lappend values [expr $dac_lo + \
						round(($dac_hi - $dac_lo) * 0.5 * \
							(1.0+sin(2*$pi*($start_frequency*$sweep_period* \
								((pow(($stop_frequency/$start_frequency), ($phase)) - 1) \
									/(log($stop_frequency/$start_frequency)))))))]
				}
			}
		}
		"square" {
			set pi 3.141592654
			for {set i 0} {$i < $num_pts} {incr i} {
				set phase [expr fmod($i,$period)/$period]
				if {$config(logarithmic) == "0"} {
					lappend values [expr $dac_lo + \
						($dac_hi - $dac_lo) * round(0.5 * \
							(1.0+sin(2*$pi*$sweep_period*(($start_frequency+ \
								(($stop_frequency-$start_frequency)/2)*$phase)*$phase))))]
				} else {
					lappend values [expr $dac_lo + \
						($dac_hi - $dac_lo) * round(0.5 * \
							(1.0+sin(2*$pi*($start_frequency*$sweep_period* \
								((pow(($stop_frequency/$start_frequency), ($phase)) - 1) \
									/(log($stop_frequency/$start_frequency)))))))]
				}
			}
		}
		"triangle" {
			set pi 3.141592654
			for {set i 0} {$i < $num_pts} {incr i} {\
				set phase [expr fmod($i,$period)/$period]
				if {$config(logarithmic) == "0"} {
					set n [expr (sin(2*$pi*$phase*$sweep_period*($stop_frequency*$phase+$start_frequency)) + \
					 $phase)]
					if {$phase <= $n} { 
						lappend values [expr $dac_lo + \
							round(($dac_hi-$dac_lo)*$phase*$sweep_period*($stop_frequency*$phase+$start_frequency))]
					} else {
						lappend values [expr $dac_hi - \
							round(($dac_hi-$dac_lo)*($phase-0.5)*$sweep_period*($stop_frequency*$phase+$start_frequency))]
					}
				} else {
					set n [expr (sin(2*$pi*$phase*$sweep_period*($stop_frequency*$phase+$start_frequency)) + \
						$phase)]
					if {$phase <= $n} { 
						lappend values [expr $dac_lo + \
							round(($dac_hi-$dac_lo)*$phase*$sweep_period*($stop_frequency*$phase+$start_frequency))]
					} else {
						lappend values [expr $dac_hi - \
							round(($dac_hi-$dac_lo)*($phase-0.5)*$sweep_period*($stop_frequency*$phase+$start_frequency))]
					}
				}
			}
		}
		default {
			return "ERROR: Unkown waveform \"$waveform\"."
		}
	}
	
	# Choose the filter.
	set rc [lindex $LWFG(rc_options) 0]
	set filter [lindex $LWFG(rc_options) 1]
	switch $waveform {
		"sine"     - 
		"triangle" {
			set ideal_rc [expr 1.0E9/($stop_frequency)*$LWFG(rc_fraction)]
			foreach {p code} $LWFG(rc_options) {
				if {$p < $ideal_rc} {
					set filter $code
					set rc $p
				}
			}
		}
	}
	
	# Open a socket to the function generator and configure it through
	# the data portal by means of stream write instructions.
	if {[catch {
		# Open a socket to the function generator.
		set sock [LWDAQ_socket_open $ip]
		
		LWDAQ_set_data_addr $sock $LWFG(ch$ch_num\_ram)
		LWDAQ_stream_write $sock $LWFG(data_portal) [binary format c* $values]

		LWDAQ_set_data_addr $sock $LWFG(ch$ch_num\_rc)
		LWDAQ_stream_write $sock $LWFG(data_portal) \
			[binary format c [expr $filter]]
		LWDAQ_set_data_addr $sock $LWFG(ch$ch_num\_div)
		LWDAQ_stream_write $sock $LWFG(data_portal) \
			[binary format I [expr $divisor - 1]]
		LWDAQ_set_data_addr $sock $LWFG(ch$ch_num\_len)
		LWDAQ_stream_write $sock $LWFG(data_portal) \
			[binary format S [expr $num_pts - 1]]

		set id [LWDAQ_hardware_id $sock]
		LWDAQ_socket_close $sock
	} error_message]} {
		catch {LWDAQ_socket_close $sock}
		return "ERROR: $error_message\."
	}
	
	# Return enough information about the waveform for us to assess accuracy.
	return "$dac_lo $dac_hi $divisor $num_pts $num_cycles [format %.0f $rc]"

}


proc Function_Generator_open {} {
	upvar #0 Function_Generator_config config 
	upvar #0 Function_Generator_info info 
	upvar #0 LWDAQ_config_Receiver ipconfig
	global LWFG

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}

	set f [frame $w.control]
	pack $f -side top -fill x 


	label $f.mtl -text "Channel:"
	tk_optionMenu $f.mtm Function_Generator_config(gen_ch) 2
	foreach s $info(channel_names) {
		$f.mtm.menu add command -label $s \
			-command "set Function_Generator_config(gen_ch) $s"
	}
	set config(gen_ch) [lindex $info(channel_names) 0]
	pack $f.mtl $f.mtm -side left -expand 1


	foreach a {On Off Sweep} {
		set b [string tolower $a]
		button $f.$b -text "$a" -command "LWDAQ_post Function_Generator_$b"
		pack $f.$b -side left -expand yes
	}

	foreach a {Help Configure} {
		set b [string tolower $a]
		button $f.$b -text "$a" -command "LWDAQ_tool_$b Function_Generator"
		pack $f.$b -side left -expand yes
	}

	checkbutton $f.verbose -text "Verbose" -variable Function_Generator_config(verbose)
	pack $f.verbose -side left -expand yes

	set f [frame $w.configure]
	pack $f -side top -fill x
	
	foreach a {Type Frequency Amplitude Offset} {
		set b [string tolower $a]
		label $f.l$a -text "$a\:" -fg $config(label_color)
		entry $f.e$a -textvariable Function_Generator_config(waveform_$b) -width 10
		pack $f.l$a $f.e$a -side left -expand yes
	}

	label $f.lgip -text "IP:" -fg $config(label_color)
	entry $f.egip -textvariable Function_Generator_config(gen_ip) -width 16
	pack $f.lgip $f.egip -side left -expand yes

	set f [frame $w.batch]
	pack $f -side top -fill x

	label $f.mtz -text "Attenuation:" -fg $config(label_color)
	tk_optionMenu $f.mtm Function_Generator_config(attnsw) 0.0dB
	foreach s {-3.0dB -4.8dB -7.0dB -9.6dB} {
		$f.mtm.menu add command -label $s \
			-command "set Function_Generator_config(attnsw) $s"
	}
	set config(attnsw) "0.0dB"
	pack $f.mtz $f.mtm -side left -expand 1

	foreach a {Start_Frequency Stop_Frequency Time} {
		set b [string tolower $a]
		label $f.l$b -text "$a\:" -fg $config(label_color)
		entry $f.e$b -textvariable Function_Generator_config(sweep_$b) -width 10
		pack $f.l$b $f.e$b -side left -expand yes
	}

	checkbutton $f.logarithmic -text "Logarithmic" -variable Function_Generator_config(logarithmic)
	pack $f.logarithmic -side left -expand yes

	set info(text) [LWDAQ_text_widget $w 90 20]
	LWDAQ_print $info(text) "$info(name) Version $info(version) \n" purple
	
	return $w


}

Function_Generator_init
Function_Generator_open 

return ""

----------Begin Help----------

Type: The waveform type, by default a sinusoid, can be "sine", "square", or
"triangle".

Frequency: The waveform frequency, anything from 1 mHz to 1 MHz.

Amplitude: The amplitude of the symmetric waveform, which is half the peak to
peak amplitude. Can be anything from 0 to 10 V.

Offset: The offset of the waveform average from zero. Subject to a signal range
of -10 V to +10 V, the offset can be anything from -10 V to + 10 V.

IP: The function generator IP address.

Copyright (C) 2024, Nathan Sayer, Open Source Instruments Inc.

----------End Help----------

