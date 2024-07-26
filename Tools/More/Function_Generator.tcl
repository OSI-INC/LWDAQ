# Function Generator, a LWDAQ Tool.
#
# Copyright (C) 2024 Nathan Sayer, Open Source Instruments Inc.
#

proc Function_Generator_init {} {
	upvar #0 Function_Generator_info info
	upvar #0 Function_Generator_config config

	LWDAQ_tool_init "Function_Generator" "1.3"
	if {[winfo exists $info(window)]} {return ""}

	set info(data) [list]
	set info(start_time) "0"
	set info(channel_names) "1"

	set info(control) "Idle"
	set config(verbose) "0"
	set config(logarithmic) "0"

	set config(gen_ip) "10.0.0.37"
	set config(gen_ch) [lindex $info(channel_names) 0]
	
	set config(waveform_type) "sine"
	set config(waveform_amplitude) "10"
	set config(waveform_offset) "0"
	set config(waveform_frequency) "10"

	set config(sweep_start_frequency) "1"
	set config(sweep_stop_frequency) "500"
	set config(sweep_time) "1"
	set config(attenuation) "0x800E"
	set config(ch_attn) "0x00"
	set config(ch_fact) "1.0"

	set config(label_color) "green"

	package require LWFG

	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	}

	return ""
}

proc Function_Generator_attenuation {} {
	upvar #0 Function_Generator_info info
	upvar #0 Function_Generator_config config

	set a_lo [expr $config(waveform_offset) - $config(waveform_amplitude)]
	set a_hi [expr $config(waveform_offset) + $config(waveform_amplitude)]

	if {$config(gen_ch) == 1 } {
		if {$a_hi > 5 || $a_lo <-5} {
			set config(ch_attn) 0x00
			set config(ch_fact) 1.0
		} elseif {($a_hi > 3.333 && $a_hi <= 5) || ($a_lo < -3.333 && $a_lo >= -5)} {
			set config(ch_attn) 0x01
			set config(ch_fact) 2.0
		} elseif {($a_hi > 2 && $a_hi <= 3.333) || ($a_lo < -2 && $a_lo >= -3.333)} {
			set config(ch_attn) 0x08
			set config(ch_fact) 3.0
		} elseif {($a_hi > 1.111 && $a_hi <= 2) || ($a_lo < -1.111 && $a_lo >= -2)} {
			set config(ch_attn) 0x04
			set config(ch_fact) 5.0
		} elseif {($a_hi <= 1.111 || $a_lo >= -1.111)} {
			set config(ch_attn) 0x02
			set config(ch_fact) 9.0
		}
	} elseif {$config(gen_ch) == 2 } {
		if {$a_hi > 5 || $a_lo <-5} {
			set config(ch_attn) 0x00
			set config(ch_fact) 1.0
		} elseif {($a_hi > 3.333 && $a_hi <= 5) || ($a_lo < -3.333 && $a_lo >= -5)} {
			set config(ch_attn) 0x10
			set config(ch_fact) 2.0
		} elseif {($a_hi > 2 && $a_hi <= 3.333) || ($a_lo < -2 && $a_lo >= -3.333)} {
			set config(ch_attn) 0x80
			set config(ch_fact) 3.0
		} elseif {($a_hi > 1.111 && $a_hi <= 2) || ($a_lo < -1.111 && $a_lo >= -2)} {
			set config(ch_attn) 0x40
			set config(ch_fact) 5.0
		} elseif {($a_hi <= 1.111 || $a_lo >= -1.111)} {
			set config(ch_attn) 0x20
			set config(ch_fact) 9.0
		}
	}
}

# Specify the variables necessary for the LWFG package to output a waveform of
# constant frequency.
#
proc Function_Generator_on {} {
	upvar #0 Function_Generator_info info
	upvar #0 Function_Generator_config config

	set v_lo [expr ($config(waveform_offset) - $config(waveform_amplitude)) * $config(ch_fact)]
	set v_hi [expr ($config(waveform_offset) + $config(waveform_amplitude)) * $config(ch_fact)]

	if { [expr $config(waveform_offset) - $config(waveform_amplitude)] < -10 || \
	  [expr $config(waveform_offset) + $config(waveform_amplitude)] > 10} {
			LWDAQ_print $info(text) "ERROR: Maximum output of +/-10V exceeded."
		} else {
			LWDAQ_print $info(text) "Channel $config(gen_ch), $config(waveform_type),\
				$config(waveform_frequency) Hz,\
				$config(waveform_amplitude) V amplitude,\
				$config(waveform_offset) V offset." purple
		}
	

	# Determine the bounds of the waveform

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

# Tell the package LWFG to turn off a specific channel.
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

# Output a waveform with changing frequency. We allow the user to choose a starting frequency
# and a stopping frequency along with a "sweep period"
# that dictates how long it takes to cycle through the range of frequencies. 
#
proc Function_Generator_sweep {} {

	upvar #0 Function_Generator_info info 
	upvar #0 Function_Generator_config config 
	global LWFG

	set a_lo [expr $config(waveform_offset) - $config(waveform_amplitude)]
	set a_hi [expr $config(waveform_offset) + $config(waveform_amplitude)]

	if {$config(gen_ch) == 1 } {
		if {$a_hi > 5 || $a_lo <-5} {
			set config(ch_attn) 0x00
			set config(ch_fact) 1.0
		} elseif {($a_hi > 3.333 && $a_hi <= 5) || ($a_lo < -3.333 && $a_lo >= -5)} {
			set config(ch_attn) 0x01
			set config(ch_fact) 2.0
		} elseif {($a_hi > 2 && $a_hi <= 3.333) || ($a_lo < -2 && $a_lo >= -3.333)} {
			set config(ch_attn) 0x08
			set config(ch_fact) 3.0
		} elseif {($a_hi > 1.111 && $a_hi <= 2) || ($a_lo < -1.111 && $a_lo >= -2)} {
			set config(ch_attn) 0x04
			set config(ch_fact) 5.0
		} elseif {($a_hi <= 1.111 || $a_lo >= -1.111)} {
			set config(ch_attn) 0x02
			set config(ch_fact) 9.0
		}
	} elseif {$config(gen_ch) == 2 } {
		if {$a_hi > 5 || $a_lo <-5} {
			set config(ch_attn) 0x00
			set config(ch_fact) 1.0
		} elseif {($a_hi > 3.333 && $a_hi <= 5) || ($a_lo < -3.333 && $a_lo >= -5)} {
			set config(ch_attn) 0x10
			set config(ch_fact) 2.0
		} elseif {($a_hi > 2 && $a_hi <= 3.333) || ($a_lo < -2 && $a_lo >= -3.333)} {
			set config(ch_attn) 0x80
			set config(ch_fact) 3.0
		} elseif {($a_hi > 1.111 && $a_hi <= 2) || ($a_lo < -1.111 && $a_lo >= -2)} {
			set config(ch_attn) 0x40
			set config(ch_fact) 5.0
		} elseif {($a_hi <= 1.111 || $a_lo >= -1.111)} {
			set config(ch_attn) 0x20
			set config(ch_fact) 9.0
		}
	}

	set v_lo [expr ($config(waveform_offset) - $config(waveform_amplitude)) * $config(ch_fact)]
	set v_hi [expr ($config(waveform_offset) + $config(waveform_amplitude)) * $config(ch_fact)]

	if { [expr $config(waveform_offset) - $config(waveform_amplitude)] < -10 || \
	  [expr $config(waveform_offset) + $config(waveform_amplitude)] > 10} {
			LWDAQ_print $info(text) "ERROR: Maximum output of +/-10V exceeded."
		} else {
			LWDAQ_print $info(text) "Channel $config(gen_ch), $config(waveform_type),\
				$config(sweep_start_frequency) Hz to $config(sweep_stop_frequency) Hz over\
				$config(sweep_time) seconds,\
				$config(waveform_amplitude) V amplitude,\
				$config(waveform_offset) V offset." purple
		}

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

	# We begin by setting the number of points to its maximum to give us the greatest resolution possible during the sweep. 
	# This prevents the high frequency end of the sweep from being scrambled due to low resolution.
	set num_pts $LWFG(max_pts)
	set num_cycles 1
	set divisor [expr round(($LWFG(clock_hz) * $sweep_period) / $num_pts) - "1"]
	
	# Generate the waveform.
	set values [list]
	set period [expr 1.0*$num_pts/$num_cycles]

	# Based on the type of waveform calculate the values needed to be written to RAM.
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
			return "ERROR: Type of sweep not implemented. Please choose either sine or square."
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

	if { [expr $config(waveform_offset) - $config(waveform_amplitude)] < -10 || \
	  [expr $config(waveform_offset) + $config(waveform_amplitude)] > 10} {
		
	} elseif {[catch {
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
		LWDAQ_set_data_addr $sock $config(attenuation)
		LWDAQ_stream_write $sock $LWFG(data_portal) \
			[binary format c [expr $config(ch_attn)]]

		set id [LWDAQ_hardware_id $sock]
		LWDAQ_socket_close $sock
	} error_message]} {
		catch {LWDAQ_socket_close $sock}
		return "ERROR: $error_message\."
	}
	
	# Return enough information about the waveform for us to assess accuracy.
	return "$dac_lo $dac_hi $divisor $num_pts $num_cycles [format %.0f $rc]"

}

# Open the display window for the tool, specify the layout of buttons and their spacing.
#
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

Attenuation: Loss from attenuating the waveform through analog switches in dB.

Start_Frequency: The frequency that the sweep will begin with in Hz.

Stop_Frequency: The frequency that the sweep will reach at the end of its sweep period.

Time: The peiod of time it takes to go from the start frequency to the stop frequency in seconds.

Copyright (C) 2024, Nathan Sayer, Open Source Instruments Inc.

----------End Help----------

