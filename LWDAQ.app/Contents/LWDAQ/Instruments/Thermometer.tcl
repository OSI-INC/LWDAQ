# Long-Wire Data Acquisition Software (LWDAQ)
#
# Copyright (C) 2004-2019 Kevan Hashemi, Brandeis University
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
# Thermometer.tcl defines the Thermometer instrument.
#

#
# LWDAQ_init_Thermometer creates all elements of the Thermometer instrument's
# config and info arrays.
#
proc LWDAQ_init_Thermometer {} {
	global LWDAQ_Info LWDAQ_Driver
	upvar #0 LWDAQ_info_Thermometer info
	upvar #0 LWDAQ_config_Thermometer config
	array unset config
	array unset info
	
	# The info array elements will not be displayed in the 
	# instrument window. The only info variables set in the 
	# LWDAQ_open_Instrument procedure are those which are checked
	# only when the instrument window is open.
	set info(name) "Thermometer"
	set info(control) "Idle"
	set info(window) [string tolower .$info(name)]
	set info(text) $info(window).text
	set info(photo) [string tolower $info(name)\_photo]
	set info(counter) 0 
	set info(zoom) 1
	set info(daq_extended) 0
	set info(delete_old_images) 1
	set info(file_use_daq_bounds) 0
	set info(daq_device_type) 0
	set info(daq_image_width) 340
	set info(daq_image_height) 220
	set info(daq_image_left) -1
	set info(daq_image_right) -1
	set info(daq_image_top) -1
	set info(daq_image_bottom) -1
	set info(daq_wake_ms) 0
	set info(daq_sample_size) 2
	set info(daq_settle_s) 0
	set info(daq_password) "no_password"
	set info(ref_top_C) 25.69
	set info(ref_bottom_C) 15.38
	set info(rows_per_channel) 3
	set info(A2044_commands) "8090 00B0 0890 1090 2090 4090"
	set info(A2053_commands) "8080 00A0 0880 1080 2080 4080 0081 0082 0084 0088 0090 0180 0480"
	set info(A3022_commands) "8090 00B0 0890 1090"
	set info(A2082_commands) "2081 2082 2084 2088 2090 2180 2280 2480 2880 3080"
	set info(display_s_per_div) 0.001
	set info(display_C_per_div) 20
	set info(display_C_offset) 0
	set info(display_C_coupling) DC
	set info(display_num_div) 10
	set info(rows_per_channel) 3
	set info(verbose_description) "{Temperature (C)}"

	
	# All elements of the config array will be displayed in the
	# instrument window. No config array variables can be set in the
	# LWDAQ_open_Instrument procedure
	set config(image_source) "daq"
	set config(file_name) ./Images/$info(name)\*
	set config(memory_name) lwdaq_image_1
	set config(daq_ip_addr) "10.0.0.37"
	set config(daq_driver_socket) 4
	set config(daq_mux_socket) 1
	set config(daq_device_element) "B T 1 2 3 4"
	set config(daq_device_name) "A2053"
	set config(analysis_enable) 1
	set config(intensify) none
	set config(verbose_result) 0
	
	return ""
}

#
# LWDAQ_analysis_Thermometer takes the RTD resistance measurements
# contained in $image_name and plots a graph of temperature versus
# time for each sensor whose resistance is recorded in the image.
# It calculates the average value of each temperature and returns
# the averages as a string. By default, the routine uses image
# $config(memory_name).
#
proc LWDAQ_analysis_Thermometer {{image_name ""}} {
	upvar #0 LWDAQ_config_Thermometer config
	upvar #0 LWDAQ_info_Thermometer info
	if {$image_name == ""} {set image_name $config(memory_name)}
	if {$config(analysis_enable) == 2} {set stdev 1} {set stdev 0}
	set result ""
	if {[catch {
		set c_min [expr $info(display_C_offset) - \
			($info(display_num_div) * $info(display_C_per_div) / 2)]
		set c_max [expr $info(display_C_offset) + \
			($info(display_num_div) * $info(display_C_per_div) / 2)]
		set t_min 0
		set t_max [expr $info(display_num_div) * $info(display_s_per_div)]
		set result [lwdaq_gauge $image_name \
			-y_max $c_max -y_min $c_min -t_min $t_min -t_max $t_max \
			-ac_couple [string match -nocase $info(display_C_coupling) "AC"] \
			-ref_top $info(ref_top_C) -ref_bottom $info(ref_bottom_C) \
			-stdev $stdev]
	} error_result]} {return "ERROR: $error_result"}
	return $result
}

#
# LWDAQ_refresh_Thermometer refreshes the display of the data, 
# given new display settings. It calls the Thermometer analysis
# routine, which assumes that certain parameters are stored in 
# the image's results string. 
#
proc LWDAQ_refresh_Thermometer {} {
	upvar #0 LWDAQ_config_Thermometer config
	upvar #0 LWDAQ_info_Thermometer info
	if {[lwdaq_image_exists $config(memory_name)] != ""} {
		LWDAQ_analysis_Thermometer $config(memory_name)
		lwdaq_draw $config(memory_name) $info(photo) \
			-intensify $config(intensify) -zoom $info(zoom)
	}
	return ""
}

#
# LWDAQ_controls_Thermometer creates secial controls 
# for the Thermometer instrument.
#
proc LWDAQ_controls_Thermometer {} {
	global LWDAQ_Info LWDAQ_Driver
	upvar #0 LWDAQ_config_Thermometer config
	upvar #0 LWDAQ_info_Thermometer info

	set w $info(window)
	if {![winfo exists $w]} {return ""}

	set g $w.custom
	frame $g
	pack $g -side top -fill x

	foreach {label_name element_name} {
			"Offset (C)" {display_C_offset}
			"Scale (C/div)" {display_C_per_div}
			"Coupling (AC/DC)" {display_C_coupling} 
			"Scale (s/div)" {display_s_per_div} } {
		label $g.l$element_name -text $label_name \
			-width [string length $label_name]
		entry $g.e$element_name -textvariable LWDAQ_info_Thermometer($element_name) \
			-relief sunken -bd 1 -width 6
		pack $g.l$element_name $g.e$element_name -side left -expand 1
		bind $g.e$element_name <Return> LWDAQ_refresh_Thermometer
	}
	
	return ""
}


#
# LWDAQ_daq_Thermometer reads configuration paramters from the LWDAQ
# hardware, and records them in a result string, which it returns.
#
proc LWDAQ_daq_Thermometer {} {
	global LWDAQ_Info LWDAQ_Driver
	upvar #0 LWDAQ_info_Thermometer info
	upvar #0 LWDAQ_config_Thermometer config


	if {[catch {
		# Calculate the data block length and sampling period. 
		# Both calculations use parameters in the instrument's
		# config array. We put them inside our error trap
		# so we can handle user-error in the config array
		# during acquisision.
		set block_length [expr $info(rows_per_channel) \
			* [llength $config(daq_device_element)] \
			* $info(daq_image_width) \
			* $info(daq_sample_size)]
		set period [expr $info(display_s_per_div) \
			* $info(display_num_div) \
			/ $info(daq_image_width)]
		set delay [expr $period - $LWDAQ_Driver(min_adc16_sample_period)]
		if {$delay < 0} {
			set delay 0
			set period $LWDAQ_Driver(min_adc16_sample_period)
		}
		set display_s [expr $info(daq_image_width) * $period]
		
		# Open a socket to the LWDAQ relay and log in.
		set sock [LWDAQ_socket_open $config(daq_ip_addr)]
		LWDAQ_login $sock $info(daq_password)
		
		# Select the device.
		LWDAQ_set_driver_mux $sock $config(daq_driver_socket) $config(daq_mux_socket)
		LWDAQ_set_device_type $sock $info(daq_device_type)

		# Define the commands that will read out the thermometer.
		set channel_list $config(daq_device_element)
		set command_list $info($config(daq_device_name)\_commands)
		set b_cmd [lindex $command_list 0]
		set t_cmd [lindex $command_list 1]

		# Transmit the bottom reference command in order to wake up the device and
		# give it some time to settle.
		LWDAQ_transmit_command_hex $sock $b_cmd

		# If wake delay is enabled, wait for the specified interval before
		# continuing.
		if {$info(daq_wake_ms) > 0} {
			LWDAQ_delay_seconds $sock [expr $info(daq_wake_ms) * 0.001]
		}
		
		# Clear the controller RAM.
		LWDAQ_ram_delete $sock 0 $block_length
		LWDAQ_set_data_addr $sock 0
		
		# For each channel, read the bottom reference voltage, the channel
		# voltage, and the top reference voltage.
		set channel_list $config(daq_device_element)
		set command_list $info($config(daq_device_name)\_commands)
		set b_cmd [lindex $command_list 0]
		set t_cmd [lindex $command_list 1]
		foreach {c} $channel_list {
			set cmd "" 
			if {$c == "B"} {set cmd $b_cmd}
			if {$c == "T"} {set cmd $t_cmd}
			if {[string is integer $c]} {set cmd [lindex $command_list [expr $c + 1]]}
			if {$cmd != ""} {
				foreach d "$b_cmd $cmd $t_cmd" {
					LWDAQ_transmit_command_hex $sock $d
					LWDAQ_delay_seconds $sock $LWDAQ_Driver(adc16_settling_delay)
					LWDAQ_set_repeat_counter $sock [expr $info(daq_image_width) - 1]
					LWDAQ_set_delay_seconds $sock $delay
					LWDAQ_execute_job $sock $LWDAQ_Driver(adc16_job)
				}
				LWDAQ_wait_for_driver $sock $display_s
			} {
				error "device $config(daq_device_name) has no channel \"$c\""
			}
		}
		
		# Put the device to sleep.
		LWDAQ_sleep $sock
		
		# Read the data out of the relay RAM.
		set data [LWDAQ_ram_read $sock 0 $block_length]

		# Close the socket to the relay.
		LWDAQ_socket_close $sock
	} error_result]} { 
		if {[info exists sock]} {LWDAQ_socket_close $sock}
		return "ERROR: $error_result"
	}

	set config(memory_name) [lwdaq_image_create \
		-width $info(daq_image_width) \
		-height $info(daq_image_height) \
		-left $info(daq_image_left) \
		-right $info(daq_image_right) \
		-top $info(daq_image_top) \
		-bottom $info(daq_image_bottom) \
		-results "[format %1.5e $period] [llength $channel_list]" \
		-name "$info(name)\_$info(counter)"]
	lwdaq_data_manipulate $config(memory_name) write 0 $data 
		
	return $config(memory_name) 
} 
