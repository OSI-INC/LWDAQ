# SCT Check, a LWDAQ Tool.
#
# Copyright (C) 2024 Kevan Hashemi, Open Source Instruments Inc.
#
# SCT Check measures the frequency response of subcutaneous transmitters (SCTs).
# It operates a LWDAQ Function Generator (A3050) to deliver increasing
# frequencies one after the other to an SCT, and uses the Receiver Instrument to
# read out the SCT's digitized version of the signal.
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

proc SCT_Check_init {} {
	upvar #0 SCT_Check_info info
	upvar #0 SCT_Check_config config
	
	LWDAQ_tool_init "SCT_Check" "1.1"
	if {[winfo exists $info(window)]} {return ""}
	
	package require LWFG

	set info(control) "Idle"
	
	set config(version) "A"
	set config(signals) "1"
	set config(batch) "1"

	set config(gen_ip) "10.0.0.37"
	set config(gen_ch) "1"

	set config(waveform_type) "sine"
	set config(waveform_amplitude) "3"
	set config(waveform_offset) "0"
	set config(waveform_frequency) "10"

	set config(min_num_clocks) "64"
	set config(max_num_clocks) "512"
	set config(min_id) "1"
	set config(max_id) "254"
	set config(glitch_threshold) "0"
	
	set config(off_frequency) "1e6"
	set config(vbat_ref) "1.80"
	
	set config(sample_rates) "64 128 256 512 1024 2048"
	set config(ratio_fc_sps) [format %.3f [expr 160.0/512]]
	set config(frequencies_shared) "0.25 0.5 1.0 2.0 4 10\
		20 40 100 200 400 1000"
	set config(frequencies_wrt_fc) "0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0\
		1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0"
	set config(min_num_clocks_2048) 32
	set config(en_2048) 0
	set config(min_num_clocks_1024) 32
	set config(en_1024) 0
	set config(min_num_clocks_512) 32
	set config(en_512) 0
	set config(min_num_clocks_256) 64
	set config(en_256) 1
	set config(min_num_clocks_128) 64
	set config(en_128) 0
	set config(min_num_clocks_64) 128
	set config(en_64) 0
	set config(frequencies) "$config(frequencies_shared)"
	set config(min_num_clocks) $config(min_num_clocks_512)
	
	set config(label_color) "green"

	set info(data) [list]
	
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 
	
	return ""	
}

proc SCT_Check_frequencies {{print 0}} {
	upvar #0 SCT_Check_config config
	upvar #0 SCT_Check_info info
	
	set frequencies $config(frequencies_shared)
	set config(min_num_clocks) 32
	foreach sps $config(sample_rates) {
		if {$config(en_$sps)} {
			foreach ratio $config(frequencies_wrt_fc) {
				lappend frequencies [format %.0f \
					[expr $ratio * $sps * $config(ratio_fc_sps)]]
			}
			if {$config(min_num_clocks_$sps) > $config(min_num_clocks)} {
				set config(min_num_clocks) $config(min_num_clocks_$sps)
			}
		}
	}
	set frequencies [lsort -increasing -real $frequencies]
	set config(frequencies) [list]
	set previous "-1"
	foreach f $frequencies {
		if {$f != $previous} {
			lappend config(frequencies) $f
			set previous $f
		}
	}
	
	if {$print} {
		foreach f $config(frequencies) {
			LWDAQ_print $info(text) "$f" green
		}
	}
	return ""
}

proc SCT_Check_on {} {
	upvar #0 SCT_Check_info info
	upvar #0 SCT_Check_config config
	global LWFG

	LWDAQ_print $info(text) "Channel $config(gen_ch), $config(waveform_type),\
		$config(waveform_frequency) Hz,\
		$config(waveform_amplitude) V amplitude,\
		$config(waveform_offset) V offset." purple
	set v_lo [expr $config(waveform_offset) - $config(waveform_amplitude)]
	set v_hi [expr $config(waveform_offset) + $config(waveform_amplitude)]
	set result [LWFG_configure $config(gen_ip) $config(gen_ch) \
		$config(waveform_type) \
		$config(waveform_frequency) \
		$v_lo $v_hi]
	if {[LWDAQ_is_error_result $result]} {
		LWDAQ_print $info(text) $result
	}
	
	return ""
}

proc SCT_Check_off {} {
	upvar #0 SCT_Check_info info
	upvar #0 SCT_Check_config config

	LWDAQ_print $info(text) "Channel $config(gen_ch) off." purple
	set result [LWFG_configure $config(gen_ip) $config(gen_ch) sine \
		$config(off_frequency) 0 0]
	if {[LWDAQ_is_error_result $result]} {
		LWDAQ_print $info(text) $result
	}
	
	return ""
}

proc SCT_Check_battery {} {
	upvar #0 SCT_Check_config config
	upvar #0 SCT_Check_info info
	upvar #0 LWDAQ_config_Receiver iconfig
	upvar #0 LWDAQ_info_Receiver iinfo

	LWDAQ_print $info(text) "Measuring battery voltages for selected signals." purple
	LWDAQ_reset_Receiver
	set iconfig(analysis_channels) $config(signals)
	set iinfo(glitch_threshold) $config(glitch_threshold)
	set result [LWDAQ_acquire Receiver]
	set iconfig(analysis_channels) "*"
	if {[LWDAQ_is_error_result $result]} {
		LWDAQ_print $info(text) $result
		return ""
	}
	set result [lrange $result 1 end]

	foreach ch $config(signals) {
		set ave [lindex $result 2]
		if {$ave > 10000} {
			set vb [format %.2f [expr $config(vbat_ref)*65535/$ave]]
		} else {
			set vb "-1"
		}
		LWDAQ_print -nonewline $info(text) "$ch $vb "
		set result [lrange $result 4 end]
	}
	LWDAQ_print $info(text)
	
	return ""
}

proc SCT_Check_detect {} {
	upvar #0 SCT_Check_config config
	upvar #0 SCT_Check_info info
	upvar #0 LWDAQ_config_Receiver iconfig
	upvar #0 LWDAQ_info_Receiver iinfo

	LWDAQ_print $info(text) "Detecting available telemetry signals." purple
	set detect ""
	LWDAQ_reset_Receiver
	set iconfig(analysis_channels) "*"
	set result [LWDAQ_acquire Receiver]
	if {[LWDAQ_is_error_result $result]} {
		LWDAQ_print $info(text) $result
		return ""
	}	
	for {set id $config(min_id)} {$id <= $config(max_id)} {incr id} {
		if {[lsearch $iinfo(channel_activity) "$id\:*"] >= 0} {
			append detect "$id "
		}		
	}
	set detect [string trim $detect]
	if {$detect == ""} {
		LWDAQ_print $info(text) "Found no active telemetry signals."
	} else {
		LWDAQ_print $info(text) $detect
	}
	set config(signals) $detect
	return ""
}

proc SCT_Check_sweep {{index "-1"}} {
	upvar #0 SCT_Check_info info
	upvar #0 SCT_Check_config config
	upvar #0 LWDAQ_config_Receiver iconfig
	upvar #0 LWDAQ_info_Receiver iinfo

	if {$index < 0} {
		if {$info(control) == "Sweep"} {return "0"}
		set info(control) "Sweep"
		SCT_Check_frequencies	
		set info(data) [list]
		LWDAQ_post [list SCT_Check_sweep "0"]
		return ""
	}
	
	if {$index >= 0} {
		if {$info(control) == "Stop"} {
			LWDAQ_print $info(text) "Sweep aborted."
			set info(control) "Idle"
			SCT_Check_off
			return ""
		}

		set frequency [lindex $config(frequencies) $index]
		set num_clocks [expr round(2.0*$iinfo(clock_frequency)/$frequency)]
		if {$num_clocks < $config(min_num_clocks)} {
			set num_clocks $config(min_num_clocks)
		}
		if {$num_clocks > $config(max_num_clocks)} {
			set num_clocks $config(max_num_clocks)
		}
		set iconfig(daq_num_clocks) $num_clocks
		set config(waveform_frequency) $frequency
		SCT_Check_on
		LWDAQ_wait_ms [expr 10+round(1000.0/$frequency)]

		LWDAQ_reset_Receiver
		set iconfig(analysis_channels) $config(signals)
		set iinfo(glitch_threshold) $config(glitch_threshold)
		set result [LWDAQ_acquire Receiver]
		set iconfig(analysis_channels) "*"
		if {[LWDAQ_is_error_result $result]} {
			LWDAQ_print $info(text) $result
			return ""
		}
		set result [lrange $result 1 end]
		set output_line "$frequency "
		foreach c [lsort -increasing $config(signals)] {
			set amplitude [format %.1f [expr sqrt(2)*[lindex $result 3]]]
			set result [lrange $result 4 end]
			append output_line "$c $amplitude "
		}
		LWDAQ_print $info(text) "$output_line"
		lappend info(data) "$output_line"
		
		# Call the sweep routine with the next frequency, or if we are done,
		# write data to output file.
		incr index
		if {$index < [llength $config(frequencies)]} {
			LWDAQ_post [list SCT_Check_sweep $index]
			return ""
		} else {
			LWDAQ_print $info(text) "Sweep Complete,\
				[llength $config(frequencies)] frequencies." purple
			set info(control) "Idle"
			return ""
		}
	}
}

proc SCT_Check_stop {} {
	upvar #0 SCT_Check_info info
	upvar #0 SCT_Check_config config
	
	if {$info(control) != "Idle"} {
		set info(control) "Stop"
	} 
	return ""
}

proc SCT_Check_print {} {
	upvar #0 SCT_Check_info info
	upvar #0 SCT_Check_config config

	foreach c [lsort -increasing -integer $config(signals)] {
		LWDAQ_print -nonewline $info(text) \
			"$config(version)$config(batch)\.$c\t"
	}
	LWDAQ_print $info(text)
	foreach output_line $info(data) {
		set output_line [lrange $output_line 1 end]
		foreach {c a} $output_line {
			LWDAQ_print -nonewline $info(text) "$a\t"
		}
		LWDAQ_print $info(text)
	}
	return ""
}


proc SCT_Check_open {} {
	upvar #0 SCT_Check_config config
	upvar #0 SCT_Check_info info
	upvar #0 LWDAQ_config_Receiver iconfig
		
	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
		
	set f [frame $w.control]
	pack $f -side top -fill x
	
	label $f.control -textvariable SCT_Check_info(control) -fg blue -width 8
	pack $f.control -side left -expand yes
		
	foreach a {On Off Sweep Stop Print Battery} {
		set b [string tolower $a]
		button $f.$b -text "$a" -command "LWDAQ_post SCT_Check_$b"
		pack $f.$b -side left -expand yes
	}

	foreach a {Help Configure} {
		set b [string tolower $a]
		button $f.$b -text "$a" -command "LWDAQ_tool_$b SCT_Check"
		pack $f.$b -side left -expand yes
	}

	foreach a {Receiver} {
		set b [string tolower $a]
		button $f.$b -text "$a" -command "LWDAQ_open $a"
		pack $f.$b -side left -expand yes
	}
	
	set f [frame $w.configure]
	pack $f -side top -fill x
	
	foreach a {Type Frequency Amplitude Offset} {
		set b [string tolower $a]
		label $f.l$a -text "$a\:" -fg $config(label_color)
		entry $f.e$a -textvariable SCT_Check_config(waveform_$b) -width 6
		pack $f.l$a $f.e$a -side left -expand yes
	}
		
	label $f.lgch -text "Channel:" -fg $config(label_color)
	entry $f.egch -textvariable SCT_Check_config(gen_ch) -width 3
	pack $f.lgch $f.egch -side left -expand yes

	label $f.lgip -text "FGIP:" -fg $config(label_color)
	entry $f.egip -textvariable SCT_Check_config(gen_ip) -width 16
	pack $f.lgip $f.egip -side left -expand yes

	label $f.lrip -text "RXIP:" -fg $config(label_color)
	entry $f.erip -textvariable LWDAQ_config_Receiver(daq_ip_addr) -width 16
	pack $f.lrip $f.erip -side left -expand yes
	
	set f [frame $w.batch]
	pack $f -side top -fill x

	foreach a {Version Batch} {
		set b [string tolower $a]
		label $f.l$b -text "$a\:" -fg $config(label_color)
		entry $f.e$b -textvariable SCT_Check_config($b) -width 4
		pack $f.l$b $f.e$b -side left -expand yes
	}
	
	foreach a {Signals} {
		set b [string tolower $a]
		label $f.l$b -text "$a\:" -fg $config(label_color)
		entry $f.e$b -textvariable SCT_Check_config($b) -width 50
		pack $f.l$b $f.e$b -side left -expand yes
	}
		
	foreach a {Detect} {
		set b [string tolower $a]
		button $f.$b -text "$a" -command "LWDAQ_post SCT_Check_$b"
		pack $f.$b -side left -expand yes
	}

	set f [frame $w.frequencies]
	pack $f -side top -fill x

	label $f.lf -text "Frequenies:" -fg $config(label_color)
	entry $f.ef -textvariable SCT_Check_config(frequencies) -width 100
	pack $f.lf $f.ef -side left -expand yes
	
	set f [frame $w.sps]
	pack $f -side top -fill x

	button $f.lfset -text "Frequencies" -command {SCT_Check_frequencies 1}
	pack $f.lfset -side left -expand yes
	
	label $f.spsl -text "Sample Rates:" -fg $config(label_color)
	pack $f.spsl -side left -expand yes
	foreach sps $config(sample_rates) {
		checkbutton $f.sps$sps -text $sps -variable SCT_Check_config(en_$sps)
		pack $f.sps$sps -side left -expand yes
	}
		
	set info(text) [LWDAQ_text_widget $w 90 20]
	LWDAQ_print $info(text) "$info(name) Version $info(version) \n" purple
	
	SCT_Check_frequencies
	
	return $w	
}

SCT_Check_init
SCT_Check_open

return ""

----------Begin Help----------

Waveform Types:  Enter either sin, tri, square, or an integer value. Version 1.1
only allows the amplitude of the sin function to be altered when setting the
output voltage. The tri and square currently output maximum voltage.

Output Frequency:  Frequency Range= 0.1Hz - 40kHz(maximum voltage is limited by
bug in v1.1 code.

Output Voltage Range:  0.10V - 9.8V peak to peak, unloaded.

Sweep Points:  Enter a list of discrete frequency values from lowest frequency
to highest.  These values will dictate the frequency sweep range.

Enter transmitter ID:  Type in any alphanumeric value to identify the
transmitter under test.

Sweep and Record:  Press this button to initiate a frequency sweep. If the ip
addresses/mux sockets/driver sockets are set incorrectly, the tool will hang.

Record to file?:  Click this button to have the frequency sweep data recorded to
a text file as defined under the button 'Set File Name'. Default file name is:
Transmitter Frequency Response.txt.  File is located under the LWDAQ folder.

Set File Name:  Use this button to define a unique file name to save the
frequency sweep data.

Set Output:  Pressing this will turn on/adjust the function generator output as
defined by the values in 'Waveform Type, Output Frequency, and Output Voltage.'

Output Off:  Disables function generator output.

Number of Samples:  Currently, this entry box only displays the number of
samples used for a given frequency output.

Auto Filter Select:  Pressing this button will automatically select an RC filter
based on number of samples/frequency/sample period and based on the actual
resistors and capacitors installed on the pcb.

Choose a Filter:  Pressing this button will bring up a list of all possible RC
Filter -3dB Corner Frequency choices based on the resistors and capacitors
installed on the pcb.

----------End Help----------

