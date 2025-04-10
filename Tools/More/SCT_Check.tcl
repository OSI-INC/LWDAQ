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
	
	LWDAQ_tool_init "SCT_Check" "2.3"
	if {[winfo exists $info(window)]} {return ""}
	
	package require LWFG

	set info(control) "Idle"
	set config(verbose) "0"
	
	set config(version) "A"
	set config(signals) "1"
	set config(batch) "1"

	set config(gen_ip) "10.0.0.37"
	set config(gen_ch) "1"

	set config(waveform_type) "sine"
	set config(waveform_types) "sine triangle square sweep"
	set config(waveform_amplitude) "3"
	set config(waveform_offset) "0"
	set config(waveform_frequency) "10"
	set config(sweep_flo) "1"
	set config(sweep_fhi) "1000"
	set config(sweep_time) "2"

	set config(min_num_clocks) "64"
	set config(max_num_clocks) "512"
	set config(min_id) "1"
	set config(max_id) "254"
	set config(glitch) "0"
	set config(settle) "0.5"
	
	set config(off_frequency) "40e6"
	set config(vbat_ref) "1.80"
	
	set config(sample_rates) "64 128 256 512 1024 2048"
	set config(frequencies_shared) "0.25 0.5 1.0 2.0 4 10\
		20 40 100 200 400 1000"
	set config(frequencies_wrt_sps) "0.13 0.15 0.17 0.19 0.21 0.23\
		0.27 0.29 0.31 0.33 0.35 0.37 0.39 0.41 0.43 0.45 0.49 0.55 0.57"
	set config(min_num_clocks_2048) 32
	set config(en_2048) 0
	set config(min_num_clocks_1024) 32
	set config(en_1024) 0
	set config(min_num_clocks_512) 32
	set config(en_512) 0
	set config(min_num_clocks_256) 64
	set config(en_256) 0
	set config(min_num_clocks_128) 64
	set config(en_128) 0
	set config(min_num_clocks_64) 128
	set config(en_64) 0
	set config(frequencies) $config(frequencies_shared)
	set config(min_num_clocks) $config(min_num_clocks_512)
	
	set config(label_color) "green"

	set info(data) [list]
	set info(start_time) "0"
	
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 
	
	return ""	
}

proc SCT_Check_set_frequencies {{print 0}} {
	upvar #0 SCT_Check_config config
	upvar #0 SCT_Check_info info
	
	set frequencies $config(frequencies_shared)
	set config(min_num_clocks) 32
	foreach sps $config(sample_rates) {
		if {$config(en_$sps)} {
			foreach ratio $config(frequencies_wrt_sps) {
				lappend frequencies [format %.0f [expr $ratio * $sps]]
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

proc SCT_Check_waveform_on {} {
	upvar #0 SCT_Check_info info
	upvar #0 SCT_Check_config config
	global LWFG

	if {$config(waveform_type) != "sweep"} {
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
		} elseif {$config(verbose)} {
			foreach a {dac_lo dac_hi divisor num_pts num_cycles} {
				set $a [lindex $result 0]
				LWDAQ_print $info(text) "$a = [lindex $result 0]"
				set result [lrange $result 1 end] 
			}
			LWDAQ_print $info(text) "rc = [format %3.f [expr 0.001*[lindex $result 0]]] us"
			LWDAQ_print $info(text) "att = [lindex $result 1]"
			set actual [expr $LWFG(clock_hz)*$num_cycles/$num_pts/$divisor]
			LWDAQ_print $info(text) "actual = [format %.3f $actual] Hz"
			LWDAQ_print $info(text) "requested = [format %.3f $config(waveform_frequency)] Hz"
		}
	} else {
		LWDAQ_print $info(text) "Channel $config(gen_ch), sweep,\
			$config(sweep_flo) to $config(sweep_fhi) Hz,\
			$config(sweep_time) s,\
			$config(waveform_amplitude) V amplitude,\
			$config(waveform_offset) V offset." purple
		set v_lo [expr $config(waveform_offset) - $config(waveform_amplitude)]
		set v_hi [expr $config(waveform_offset) + $config(waveform_amplitude)]
		set result [LWFG_sweep_sine $config(gen_ip) $config(gen_ch) \
			$config(sweep_flo) $config(sweep_fhi) $v_lo $v_hi \
			$config(sweep_time) 1]
		if {[LWDAQ_is_error_result $result]} {
			LWDAQ_print $info(text) $result
		} elseif {$config(verbose)} {
			foreach a {dac_lo dac_hi divisor num_pts num_cycles} {
				set $a [lindex $result 0]
				LWDAQ_print $info(text) "$a = [lindex $result 0]"
				set result [lrange $result 1 end] 
			}
			LWDAQ_print $info(text) "rc = [format %3.f [expr 0.001*[lindex $result 0]]] us"
			LWDAQ_print $info(text) "att = [lindex $result 1]"
		}
	}
	
	return ""
}

proc SCT_Check_waveform_off {} {
	upvar #0 SCT_Check_info info
	upvar #0 SCT_Check_config config

	LWDAQ_print $info(text) "Channel $config(gen_ch), 0 V amplitude, 0 V offset." purple
	set result [LWFG_off $config(gen_ip) $config(gen_ch)]
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
	set iinfo(glitch_threshold) $config(glitch)
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
	set iconfig(daq_num_clocks) 128
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

proc SCT_Check_measure {{index "-1"}} {
	upvar #0 SCT_Check_info info
	upvar #0 SCT_Check_config config
	upvar #0 LWDAQ_config_Receiver iconfig
	upvar #0 LWDAQ_info_Receiver iinfo

	if {$index < 0} {
		if {$info(control) == "Measure"} {return "0"}
		set info(control) "Measure"
		set info(start_time) [clock seconds]
		set info(data) [list]
		LWDAQ_post [list SCT_Check_measure "0"]
		return ""
	}
	
	if {$index >= 0} {
		if {$info(control) == "Stop"} {
			LWDAQ_print $info(text) "Measurement aborted."
			set info(control) "Idle"
			SCT_Check_waveform_off
			return ""
		}
		
		set $config(waveform_type) "sine"

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
		SCT_Check_waveform_on
		LWDAQ_wait_ms [expr round(1000.0*$config(settle)/$frequency)]

		LWDAQ_reset_Receiver
		set iconfig(analysis_channels) $config(signals)
		set iinfo(glitch_threshold) $config(glitch)
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
		
		# Call the measurement routine with the next frequency, or if we are
		# done, write data to output file.
		incr index
		if {$index < [llength $config(frequencies)]} {
			LWDAQ_post [list SCT_Check_measure $index]
			return ""
		} else {
			LWDAQ_print $info(text) "Measurement Complete,\
				[llength $config(frequencies)] frequencies\
				in [expr [clock seconds] - $info(start_time)] s." purple
			set iconfig(daq_num_clocks) 128
			SCT_Check_waveform_off
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
		
	foreach a {Measure Stop Print Waveform_On Waveform_Off } {
		set b [string tolower $a]
		button $f.$b -text "$a" -command "LWDAQ_post SCT_Check_$b"
		pack $f.$b -side left -expand yes
	}

	foreach a {Receiver} {
		set b [string tolower $a]
		button $f.$b -text "$a" -command "LWDAQ_open $a"
		pack $f.$b -side left -expand yes
	}
	
	foreach a {Spectrometer} {
		set b [string tolower $a]
		button $f.$b -text "$a" -command "LWDAQ_run_tool $a"
		pack $f.$b -side left -expand yes
	}
	
	foreach a {Help Configure} {
		set b [string tolower $a]
		button $f.$b -text "$a" -command "LWDAQ_tool_$b SCT_Check"
		pack $f.$b -side left -expand yes
	}
	
	checkbutton $f.verbose -text "Verbose" -variable SCT_Check_config(verbose)
	pack $f.verbose -side left -expand yes

	set f [frame $w.configure]
	pack $f -side top -fill x
	
	label $f.wfl -text "Waveform:" -fg $config(label_color)
	menubutton $f.wfm -menu $f.wfm.m \
		-width 8 -relief groove -indicatoron 1 \
		-textvariable SCT_Check_config(waveform_type)
	set m [menu $f.wfm.m]
	foreach wt $config(waveform_types) {
		$m add command -label $wt -command \
			[list set SCT_Check_config(waveform_type) $wt]
	}
	pack $f.wfl $f.wfm -side left -expand yes

	foreach {a b c} {"Channel" gen_ch 3 \
		"Frequency (Hz)" waveform_frequency 10 \
		"Amplitude (Vpp)" waveform_amplitude 10 \
		"Offset (V)" waveform_offset 10 } {
		label $f.l$b -text "$a\:" -fg $config(label_color)
		entry $f.e$b -textvariable SCT_Check_config($b) -width $c
		pack $f.l$b $f.e$b -side left -expand yes
	}
		
	set f [frame $w.misc]
	pack $f -side top -fill x

	foreach {a b} {"Sweep_Lo (Hz)" sweep_flo \
		"Sweep_Hi (Hz)" sweep_fhi \
		"Sweep_Time (s)" sweep_time} {
		label $f.l$b -text "$a\:" -fg $config(label_color)
		entry $f.e$b -textvariable SCT_Check_config($b) -width 6
		pack $f.l$b $f.e$b -side left -expand yes
	}
		
	label $f.lgip -text "FGIP:" -fg $config(label_color)
	entry $f.egip -textvariable SCT_Check_config(gen_ip) -width 16
	pack $f.lgip $f.egip -side left -expand yes

	label $f.lrip -text "RXIP:" -fg $config(label_color)
	entry $f.erip -textvariable LWDAQ_config_Receiver(daq_ip_addr) -width 16
	pack $f.lrip $f.erip -side left -expand yes
	
	foreach a {Glitch} {
		set b [string tolower $a]
		label $f.l$b -text "$a\:" -fg $config(label_color)
		entry $f.e$b -textvariable SCT_Check_config($b) -width 7
		pack $f.l$b $f.e$b -side left -expand yes
	}
		
	set f [frame $w.batch]
	pack $f -side top -fill x

	foreach a {Signals} {
		set b [string tolower $a]
		label $f.l$b -text "$a\:" -fg $config(label_color)
		entry $f.e$b -textvariable SCT_Check_config($b) -width 100
		pack $f.l$b $f.e$b -side left -expand yes
	}
		
	foreach a {Detect Battery} {
		set b [string tolower $a]
		button $f.$b -text "$a" -command "LWDAQ_post SCT_Check_$b"
		pack $f.$b -side left -expand yes
	}

	set f [frame $w.frequencies]
	pack $f -side top -fill x

	label $f.lf -text "Frequenies:" -fg $config(label_color)
	entry $f.ef -textvariable SCT_Check_config(frequencies) -width 100
	pack $f.lf $f.ef -side left -expand yes
	
	foreach a {Version Batch} {
		set b [string tolower $a]
		label $f.l$b -text "$a\:" -fg $config(label_color)
		entry $f.e$b -textvariable SCT_Check_config($b) -width 4
		pack $f.l$b $f.e$b -side left -expand yes
	}
	
	set f [frame $w.sps]
	pack $f -side top -fill x

	button $f.lfset -text "Set Frequencies" -command {SCT_Check_set_frequencies 1}
	pack $f.lfset -side left -expand yes
	
	label $f.spsl -text "Sample Rates:" -fg $config(label_color)
	pack $f.spsl -side left -expand yes
	foreach sps $config(sample_rates) {
		checkbutton $f.sps$sps -text $sps -variable SCT_Check_config(en_$sps)
		pack $f.sps$sps -side left -expand yes
	}
		
	set info(text) [LWDAQ_text_widget $w 90 20]
	LWDAQ_print $info(text) "$info(name) Version $info(version) \n" purple
	
	return $w	
}

SCT_Check_init
SCT_Check_open

return ""

----------Begin Help----------

The Subcutaneous Transmitter (SCT) Check tool uses a telemetry receiver and a
function generator to measure the frequency response and battery voltages of
SCTs during and after assembly and encapsulation. We use the tool to produce
rapid frequency sweeps that allow us to see the approximate frequency response
of a transmitter prior to encapsulation or during accelerated aging. We use the
Measure button to produce plots of gain versus frequency for permanent and
detailed records of the frequency response. The function generator is the
Function Generator (A3050) or other compatible PoE generator. The receiver must
be one of our LWDAQ telemetry receivers, such as the Octal Data Receiver
(A3027E), Animal Location Tracker, (ALT), or Telemetry Control Box (TCB). The
tool uses the LWFG package, included with LWDAQ, to configure the function
generator. It uses the Receiver Instrument, included with LWDAQ, to download
telemetry signals from the receiver.

Measure: Start a detailed measurement of frequency response. We will go through
all the frequencies defined for the measurement, starting with the lowest frequency. We
assert this frequency and measure the amplitude of the response from all transmitters
listed in the signals string. We move to the next frequency, and so on, recording 
the amplitudes of all signals as we go.

Stop: Abort a sweep.

Print: Print the results of a sweep to the text window.

Waveform_On: Turn on the waveform specified by the Waveform entry boxes. We now see
a repeating waveform produced by the function generator, perhaps even a repeating frequency sweep, on our function
generator, and we can see what this looks like in the Receiver window.

Waveform_Off: Turn off the waveform, the function generator output goes to zero.

Receiver: Open the Receiver Instrument. 

Spectrometer: Open the Spectrometer Tool.

Waveform: The waveform type, by default a sinusoid, can be "sine", "square",
"triangle", or "sweep". If "sine", "square", or "triangle", we will get a
waveform of fixed frequency, amplitude, and offset. If "sweep", we will get a
logarithmic, sinusoidal sweep. The sweep will start at sweep_lo and end at
sweep_hi in Hertz. It will take sweep_time seconds. Its amplitude and offset
will be the same as for any other waveform.

Channel: The function generator channel we want to produce our waveform.

Frequency: The waveform frequency, anything from 1 mHz to 1 MHz.

Amplitude: The amplitude of the symmetric waveform, which is half the peak to
peak amplitude. Can be anything from 0 to 10 V.

Offset: The offset of the waveform average from zero. Subject to a signal range
of -10 V to +10 V, the offset can be anything from -10 V to + 10 V.

Sweep_Lo: The low frequency we generate when the waveform type is "sweep", in
Hertz.

Sweep_Hi: The high frequency we generate when the waveform type is "sweep", in
Hertz.

Sweep_Time: The duration of a "sweep" type waveform, in seconds.

FGIP: The function generator IP address.

RXIP: The data receiver IP address. If we are using an ODR, we must also specify
the driver socket into which we have plugged the ODR. By default we use socket
one (1). We can specify another socket by opening the Receiver Instrument with
the Receiver button and setting daq_driver_socket to our chosen value.

Version: The SCT assembly version. The A3048S2 would be "S", the A3049Q4 would
be "Q". We could also write "A3Z" if we wanted, but if we write "A3", the "3"
will blend with the batch number, which is an integer, thus blending the two
numbers.

Batch: The SCT assembly batch number, which is the first part of its serial
number. Transmitter Q216.109 has batch number 216, and will share this batch
number with its partners in a production batch.

Signals: The SCT telemetry channels for which we want to measure sweep response
or battery voltage.

Detect Button: Press this button to auto-detect available SCT telemetry signals.
The tool will use the Receiver Instrument to populate the signals entry with all
available channels.

Glitch: Value for glitch filter to apply to telemetry signals before measuring
the amplitude of its fundamental frequency. We enter zero for no filter, which
is the defauilt. We enter 1000 if we want to apply the glitch filter to spikes
of height 1000 or greater, where the 1000 is in units of sixteen-bit ADC counts.

Frequencies: The frequencies at which we will measure SCT gain during a sweep.

Set Frequencies: Generate a list of frequencies for a sweep. We begin with the
shared frequencies in frequencies_shared. We add a series of frequencies for
each sample rate enabled by the sample rate checkboxes. We print the frequencies
to the screen so that we can cut and paste them into a spreadsheet.

Sample Rates: A series of checkboxes that turn on detailed measurement around
the corner frequency of SCT filters with various sample rates. When we check the
256 box, we add to our sweep the frequencies that will give us a good plot of
the SCT's low-pass filter near its corner frequency of 80 Hz. Check multiple
boxes to measure in detail around multiple corner frequencies.

Copyright (C) 2025, Kevan Hashemi, Open Source Instruments Inc.

----------End Help----------

