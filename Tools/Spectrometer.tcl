# Spectrometer.tcl, a LWDAQ Tool
#
# Copyright (C) 2006-2025 Kevan Hashemi, Open Source Instruments Inc.
#
# Plots results from the RFPM Instrument.
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

# Version 20: Add calibration constant entries in the panel and now convert
# frequency lines into dac counts automatically. Control buttons are Scan and
# Repeat so we can scan a fequency band or monitor a particular frequency. We
# provide calibration constants in the Help screen, but direct the user to the
# A3008 manual for instructions.

# Version 21: Add another decimal place for power measurement.
#
# Version 22: Add support for SCT power measurements, and change calibration of
# power to a dB offset.
#
# Version 23: Remove explanatory words from output text. Add the Spectrometer
# sample routine to return the output string from other scripts. Update
# calibration parameters for A3008D assemblies.
# 
# Version 24: Add more plot names.
#
# Version 25: Change plot names from letters to numbers that give them the same
# colors as SCT channels of the same number.
#
# Version 26: Support loading multiple spectra.
#
# Version 27: Limit significant figures in file saving.
#
# Version 28: Switch active graph selection from menu button to entry box and
# allow graphs from 0 to 255.
#
# Version 28: Add increment button.
#
# Version 29: Add active and inactive line width parameters.
#
# Version 30: Replace tk_optionMenu with menubutton and menu commands.

proc Spectrometer_init {} {
	upvar #0 Spectrometer_info info
	upvar #0 Spectrometer_config config
	global LWDAQ_Info LWDAQ_Driver
	
	LWDAQ_tool_init "Spectrometer" "29"
	if {[winfo exists $info(window)]} {return ""}

	# Software constants for the Spectrometer Tool.
	set info(control) "Idle"
	set info(instrument) "RFPM"
	set info(graph_width) 900
	set info(graph_height) 300
	set info(measurement_names) "SCT Peak Average"
	set info(cursor_y) "0"
	set info(image_name) spectrometer
	lwdaq_image_destroy $info(image_name)
	set info(photo_name) spectrometer
	set info(data) [list]
	set info(a_ref) "1000"	
	set info(gain_c0) "0"
	set info(gain_c1) "121"
	set info(gain_c2) "11"
	set info(gain_c3) "1"
	set info(peak_v_limit) "0.8"
	set info(ave_v_limit) "0.3"
	set info(graph_names) ""
	for {set graph_name 0} {$graph_name < 256} {incr graph_name} {
		lappend info(graph_names) $graph_name
	}
  		
  	# Configuration parameters for the Spectrometer Tool.
	set config(active_graph) "[lindex $info(graph_names) 0]"
	set config(measurement_type) [lindex $info(measurement_names) 0]
	set config(count_max) "100"
	set config(count_min) "0"
	set config(average_to_dBm) "+9.0"
	set config(sct_to_dBm) "+0.0"
	set config(power_min) "-90"
	set config(power_max) "-20"
	set config(power_div) "10"
	set config(step_div) "255"
	set config(cursor_enable) "1"
	set config(cursor_color) "10"
	set config(step_increment) "1"
	set config(f_color) "2"
	set config(f_lines) "900 915 930"
	set config(step) "0"
	set config(active_width) "5"
	set config(inactive_width) "2"
	
	# Calibration constants for the Sepctrometer A3008 circuit.
	set config(f_ref) "915"
	set config(dac_ref) "59"
	set config(f_slope) "0.78"
	set config(p_calib) "4.0"
	
	
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 
	
	return ""	
}

proc Spectrometer_print {s {color black}} {
	upvar #0 Spectrometer_info info
	LWDAQ_print $info(text) $s $color
	return ""
}

proc Spectrometer_refresh {} {
	upvar #0 Spectrometer_info info
	upvar #0 Spectrometer_config config
	
	set x_max $config(count_max)
	set x_min $config(count_min)
	lwdaq_config -text_name $info(text)

	lwdaq_graph "0 0" $info(image_name) -fill 1 \
		-x_min $x_min -x_max $x_max \
		-y_min $config(power_min) -y_max $config(power_max) \
		-y_div $config(power_div) -x_div $config(step_div) \
		-color 1
		
	foreach {l} $config(f_lines) {
		set x [expr ($l - $config(f_ref)) / $config(f_slope) + $config(dac_ref)]
		set graph "$x $config(power_min) $x $config(power_max)"
		lwdaq_graph $graph $info(image_name) \
			-x_min $x_min -x_max $x_max \
			-y_min $config(power_min) -y_max $config(power_max) \
			-color $config(f_color)
	}
	
	foreach graph_name $info(graph_names) {
		set graph [list]
		foreach p $info(data) {
			foreach {step power gn} $p {
				if {$graph_name == $gn} {
					lappend graph "$step $power "
				}
			}
		}
		if {[llength $graph] < 2} {continue}
		set graph [join [lsort -increasing -integer -index 0 $graph]]
		set color [lsearch $info(graph_names) $graph_name]
		if {$graph_name == $config(active_graph)} {
			set width $config(active_width)
		} {
			set width $config(inactive_width)
		}
		lwdaq_graph $graph $info(image_name) \
			-x_min $x_min -x_max $x_max \
			-y_min $config(power_min) -y_max $config(power_max) \
			-color $color -width $width
	}
	
	if {$config(cursor_enable)} {
		set graph "$config(step) $config(power_min) $config(step) $config(power_max)"
		lwdaq_graph $graph $info(image_name) \
			-x_min $x_min -x_max $x_max \
			-y_min $config(power_min) -y_max $config(power_max) \
			-color $config(cursor_color)
		set graph "$x_min $info(cursor_y) $x_max $info(cursor_y)"
		lwdaq_graph $graph $info(image_name) \
			-x_min $x_min -x_max $x_max \
			-y_min $config(power_min) -y_max $config(power_max) \
			-color $config(cursor_color)
	}
	lwdaq_draw $info(image_name) $info(photo_name)
	return ""
}

proc Spectrometer_clear {} {
	upvar #0 Spectrometer_info info
	upvar #0 Spectrometer_config config
	set new_data [list]
	foreach e $info(data) {
		if {[lindex $e 2] != $config(active_graph)} {
			lappend new_data $e			
		}
	}
	set info(data) $new_data
	Spectrometer_refresh
	return ""
}

proc Spectrometer_clear_all {} {
	upvar #0 Spectrometer_info info
	upvar #0 Spectrometer_config config
	set info(data) [list]
	Spectrometer_refresh
	return ""
}

proc Spectrometer_save_graphs {} {
	upvar #0 Spectrometer_info info
	upvar #0 Spectrometer_config config
	set fn [LWDAQ_put_file_name "RF_Spectrum.txt"]
	if {$fn == ""} {return}
	set f [open $fn w]
	foreach e $info(data) {
		foreach {step power gn} $e {
			puts $f "$step [format %.1f $power] $gn"
		}
	}
	close $f
	return ""
}

proc Spectrometer_load_graphs {} {
	upvar #0 Spectrometer_info info
	upvar #0 Spectrometer_config config
	set fnl [LWDAQ_get_file_name 1]
	if {$fnl == ""} {return}
	foreach fn $fnl {
		set f [open $fn r]
		while {[gets $f line] > 0} {
			lappend info(data) $line
		}
		close $f
	}
	Spectrometer_refresh
	return ""
}

proc Spectrometer_command {command} {
	upvar #0 Spectrometer_info info
	upvar #0 Spectrometer_config config
	global LWDAQ_Info
	if {$command == $info(control)} {
		return ""
	}
	if {$command == "Stop"} {
		if {$info(control) != "Idle"} {set info(control) "Stop"}
		return ""
	}
	if {$info(control) == "Idle"} {
		set info(control) $command
		LWDAQ_post Spectrometer_execute
		return ""
	} {
		set info(control) $command
		return ""
	}
	return ""
}


proc Spectrometer_execute {} {
	upvar #0 Spectrometer_info info
	upvar #0 Spectrometer_config config

	global LWDAQ_Info
	
	if {![array exists info]} {return}

	if {$info(window) != ""} {
		if {![winfo exists $info(window)]} {return}
	}
	if {($info(control) == "Stop") || $LWDAQ_Info(reset)} {
		set info(control) "Idle"
		return "0"
	}
		
	if {($info(control) == "Scan")} {
		set config(step) [expr $config(step) + $config(step_increment)]
		if {$config(step) > $config(count_max)} {set config(step) $config(count_min)}
		if {$config(step) < $config(count_min)} {set config(step) $config(count_max)}
	}

	upvar #0 LWDAQ_config_$info(instrument) iconfig
	set iconfig(daq_dac_value) $config(step)
	if {$config(measurement_type) == "Average"} {
		set iconfig(analysis_enable) 2
	} {
		set iconfig(analysis_enable) 1
	}
	set result [LWDAQ_acquire $info(instrument)]
	if {$result == ""} {
		set result "ERROR: $info(instrument) returned empty result."
	} 
	
	if {![LWDAQ_is_error_result $result]} {
		scan $result %s%f%f%f%f name c0 c1 c2 c3
		
		if {$config(measurement_type) == "Average"} {
			set limit $info(ave_v_limit)
		} {
			set limit $info(peak_v_limit)
		}
		if {$c3 < $limit} {
			set amplitude [expr $c3 * $info(gain_c3)]
		} elseif {$c2 < $limit} {
			set amplitude [expr $c2 * $info(gain_c2)]
		} else {
			set amplitude [expr $c1 * $info(gain_c1)]
		}
		if {$amplitude > 0} { 
			set dbm [format {%.1f} [expr 20 * log10( $amplitude / $info(a_ref) ) ]]
			if {[string is double -strict $config(p_calib)]} {
				set dbm [expr $dbm + $config(p_calib)]
			}
			if {$config(measurement_type) == "Average"} {
				set dbm [expr $dbm + $config(average_to_dBm)]
			}
			if {$config(measurement_type) == "SCT"} {
				set dbm [expr $dbm + $config(sct_to_dBm)]
			}
		} {
			set dbm $config(power_min)
		}
		set i [lsearch $info(data) "$config(step) * $config(active_graph)"]
		if {$i > 0} {set info(data) [lreplace $info(data) $i $i]}
		lappend info(data) "$config(step) $dbm $config(active_graph)"
		set f [expr ($config(step) - $config(dac_ref)) * $config(f_slope) + $config(f_ref)]
		set measurement "$config(step)\
			[format %.1f $f]\
			$config(measurement_type)\
			[format %.2f $dbm]\
			$config(active_graph)"
		LWDAQ_print $info(text) $measurement
		set info(cursor_x) $config(step)
		set info(cursor_y) $dbm
		Spectrometer_refresh
	} {
		LWDAQ_print $info(text) $result
		set config(step) [expr $config(step) - $config(step_increment)]
		set info(control) "Idle"
		return $result
	}


	if {($info(control) == "Scan") || ($info(control) == "Repeat")} {
		LWDAQ_post Spectrometer_execute
		return $measurement
	} 
	
	set info(control) "Idle"
	return $measurement
}

proc Spectrometer_sample {} {
	upvar #0 Spectrometer_info info
	upvar #0 Spectrometer_config config

	if {$info(control) != "Idle"} {
		return "ERROR: Spectrometer is busy."
	}
	set info(control) "Sample"
	Spectrometer_execute
	return ""
}

proc Spectrometer_open {} {
	upvar #0 Spectrometer_config config
	upvar #0 Spectrometer_info info

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
		
	set f $w.setup
	frame $f
	pack $f -side top -fill x
	
	label $f.lstate -textvariable $info(name)_info(control) -width 6 -fg blue
	pack $f.lstate -side left -expand 1

	label $f.lstep -text "Step"
	entry $f.estep -textvariable $info(name)_config(step) -width 4
	pack $f.lstep $f.estep -side left -expand 1

	label $f.lgraph -text "Active Graph:"
	entry $f.ag -textvariable Spectrometer_config(active_graph) -width 4
	set config(active_graph) "0"
	pack $f.lgraph $f.ag -side left -expand 1
	
	button $f.increment -text "Increment" -command {
		incr Spectrometer_config(active_graph)
		LWDAQ_post Spectrometer_refresh
	}
	pack $f.increment -side left -expand 1
	
	button $f.clear -text "Clear" -command Spectrometer_clear
	pack $f.clear -side left -expand 1

	button $f.clearall -text "Clear All" -command Spectrometer_clear_all
	pack $f.clearall -side left -expand 1

	button $f.save -text "Save" -command Spectrometer_save_graphs
	pack $f.save -side left -expand 1

	button $f.load -text "Load" -command Spectrometer_load_graphs
	pack $f.load -side left -expand 1
	
	set f $w.controls
	frame $f
	pack $f -side top -fill x
	foreach a {Stop Sample Repeat Scan} {
		set b [string tolower $a]
		button $f.$b -text $a -command "Spectrometer_command $a"
		pack $f.$b -side left -expand 1
	}
	foreach a {Configure Help} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_tool_$b Spectrometer"
		pack $f.$b -side left -expand 1
	}

	checkbutton $f.ccursor -variable Spectrometer_config(cursor_enable)	-text "Show Cursor"
	pack $f.ccursor -side left -expand 1

	label $f.mtl -text "Measurement:"
	menubutton $f.mtm -menu $f.mtm.m -textvariable Spectrometer_config(measurement_type)
	menu $f.mtm.m 
	foreach gn $info(measurement_names) {
		$f.mtm.m add command -label $gn \
			-command "set Spectrometer_config(measurement_type) $gn"
	}
	set config(measurement_type) [lindex $info(measurement_names) 0]
	pack $f.mtl $f.mtm -side left -expand 1

	set f $w.graph
	frame $f 
	pack $f -side top -fill x
	image create photo $info(photo_name) \
		-width $info(graph_width) -height $info(graph_height)
	label $f.image -image $info(photo_name) 
	pack $f.image
	lwdaq_image_create -width $info(graph_width) \
   		-height $info(graph_height) -name $info(image_name)

	set f $w.calib
	frame $f
	pack $f -side top -fill x
	
	foreach p {f_ref dac_ref f_slope p_calib} {
		label $f.l$p -text "$p\:"
		entry $f.e$p -textvariable $info(name)_config($p) -width 5
		bind $f.e$p <Return> Spectrometer_refresh
		pack $f.l$p $f.e$p -side left -expand 1
	}

	label $f.l4 -text "f_lines:"
	entry $f.e4 -textvariable $info(name)_config(f_lines) -width 20
	bind $f.e4 <Return> Spectrometer_refresh
	pack $f.l4 $f.e4 -side left -expand 1

	set info(text) [LWDAQ_text_widget $w 80 10]

	Spectrometer_refresh

	return ""
}

Spectrometer_init
Spectrometer_open

return ""

----------Begin Help----------

http://www.opensourceinstruments.com/Electronics/A3008/M3008.html

----------End Help----------

