# Function Generator, A LWDAQ Tool.
#
# Copyright (C) 2015 Michael Bradshaw, Open Source Instruments Inc.
# Copyright (C) 2015-2023 Kevan Hashemi, Open Source Instruments Inc.

proc Function_Generator_init {} {
	upvar #0 Function_Generator_info info
	upvar #0 Function_Generator_config config
	upvar #0 Function_Generator_wfgen wfgen
	upvar #0 Function_Generator_global global
	upvar #0 Function_Generator_row row
	upvar #0 Function_Generator_column column
	upvar #0 LWDAQ_config_Receiver iconfig
	upvar #0 Function_Generator_data data
	global LWDAQ_Info
	global LWDAQ_Driver

	
	LWDAQ_tool_init "Function_Generator" "4.2"
	if {[winfo exists $info(window)]} {return ""}

	set info(control) "Idle"
	set config(database_file_name) "/Users/kevan/Desktop/TX_Gain_vs_F.txt"
	
	set config(daq_driver_port) 90
	set config(version) "A"
	set config(channels) "1"
	set config(batch) "1"
	set data(output) ""

	set config(daq_ip_addr) 10.0.0.37
	set config(daq_mux_socket) 1
	set config(daq_driver_socket) 3
	set config(sine_cycles_per_memdepth) "1"
	set config(waveform_type) "sine"
	set config(voltage) "1"
	set config(amplitude) 128
	set config(dc_offset) 0
	set config(samples) 1000
	set config(command) "11111111"
	set config(analog_gain) "0011"
	set config(filter_r) "0000"
	set config(filter_c) "0000"
	set config(input_frequency) 1000
	set config(min_num_clocks) 32
	set config(max_num_clocks) 512
	set config(setup_delay_ms) 2000
	set config(min_id) 1
	set config(max_id) 254
	set config(glitch_threshold) "0"

	#These values reflect the RC filters components installed on pcb.
	set info(rcval,r8) 330.0
	set info(rcval,r9) 27.0
	set info(rcval,r10) 2.0
	set info(rcval,r11) 4.64
	set info(rccode,r8) "1000"
	set info(rccode,r9) "0100"
	set info(rccode,r10) "0010"
	set info(rccode,r11) "0001"
	set info(rcval,c13) [expr (10*pow(10,-9))]
	set info(rcval,c14) [expr (100*pow(10,-9))]
	set info(rcval,c15) [expr (1000*pow(10,-9))]
	set info(rcval,c16) [expr (10000*pow(10,-9))]			
	set info(rccode,c13) "1000"
	set info(rccode,c14) "0100"
	set info(rccode,c15) "0010"
	set info(rccode,c16) "0001"

	#These values reflect the Gain resistors installed on pcb.
	set config(gain,r12) 1.0 
	#1000
	set config(gain,r13) 5.0
	#0100
	set config(gain,r14) 75.0
	#0010
	set config(gain,r15) 100.0 
	#0001
	set config(gain,dac) 250.0
	#Create a list of RC filter 3dB frequencies base on what is installed on pcb
	set config(gain,amplifier) 2.0
	set i 0
	set info(rcfilter_choices) ""
	foreach y {c13 c14 c15 c16} {	
		foreach x {r8 r9 r10 r11} {
			set r $info(rcval,$x)
			set c $info(rcval,$y)
			set info(rc_freq,$i) [expr round((1/(2*3.14*$r*$c)))]
			lappend info(rcfilter_choices) [expr round((1/(2*3.14*$r*$c)))]
		 	append info(rcbits,$i) $info(rccode,$x) $info(rccode,$y)
			set i [expr $i + 1] 
		}
	}
	
	set config(sample_rates) "64 128 256 512 1024 2048"
	
	set config(frequencies_shared) "0.25 0.5 1.0 2.5 5.0 10.0\
		25.0 50.0 100.0 250.0 500.0 1000.0"

	set config(frequencies_2048) "200.0 300.0 400.0 450.0\
		500.0 530.0 570.0 615.0 670.0 730.0 800.0 900.0 1200.0 1500.0\
		2500.0 5000.0 10000.0"
	set config(min_num_clocks_2048) 32
	set config(en_2048) 0
	
	set config(frequencies_1024) "100.0 120.0 150.0 170.0 200.0 250.0\
		260.0 270.0 280.0 290.0 300.0 310.0 320.0\
		330.0 340.0 350.0 370.0"
	set config(min_num_clocks_1024) 32
	set config(en_1024) 0
	
	set config(frequencies_512) "30.0 60.0 70.0 80.0 90.0 95.0 105.0\
		110.0 120.0 125.0 130.0 135.0 140.0 145.0\
		150.0 155.0 160.0 170.0 180.0 190.0 200.0\
		220.0 240.0 260.0 280.0"
	set config(min_num_clocks_512) 32
	set config(en_512) 1
	
	set config(frequencies_256) "30.0 50.0 55.0 57.0 60.0 63.0 65.0\
		67.0 70.0 73.0 75.0 78.0 80.0 90.0 95.0 100.0 105.0\
		110.0 130.0 150.0"
	set config(min_num_clocks_256) 64
	set config(en_256) 0
	
	set config(frequencies_128) "13.0 16.0 20.0 22.0 26.0 28.0\
		30.0 32.0 34.0 36.0 38.0 40.0 42.0 44.0 45.0 50.0 55.0 60.0 80.0"
	set config(min_num_clocks_128) 64
	set config(en_128) 0
	
	set config(frequencies_64) "13.0 15.0 17.0 21.0 23.0 27.0 33.0 41.0"
	set config(min_num_clocks_64) 128
	set config(en_64) 0
	
	set config(frequencies) "$config(frequencies_512)"
	set config(min_num_clocks) $config(min_num_clocks_512)
	
	set info(record_yn) "0"
	set info(image_name) "Transmit Waveform"
	lwdaq_image_destroy $info(image_name)
	set info(photo_name) "Transmit Waveform"
		
	for {set j 0} {$j < $config(samples)} {incr j 1} {
		set wfgen(data,$j) 0
	}
			
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 
	
	return ""	
}

proc Function_Generator_set_frequencies {{print 0}} {
	upvar #0 Function_Generator_config config
	upvar #0 Function_Generator_info info
	
	set frequencies "$config(frequencies_shared) "
	set config(min_num_clocks) 32
	foreach sps $config(sample_rates) {
		if {$config(en_$sps)} {
			append frequencies "$config(frequencies_$sps) "
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

proc Function_Generator_browse {} {
	upvar #0 Function_Generator_config config
	set f [LWDAQ_put_file_name $config(database_file_name)]
	if {$f != ""} {
		set config(database_file_name) $f
	}
	return ""
}

proc Function_Generator_set_file_name {} {
	upvar #0 Function_Generator_config config
	upvar #0 Function_Generator_info info
	
	set w $info(window)\.info
	if {[winfo exists $w]} {return ""}
	toplevel $w
	wm title $w "$info(name) Set File Name"
	
	set top $w.top
	frame $top -borderwidth 15
	pack $top  -side top
	
	set a "database_file_name"
	label $top.l$a -text "$a"
	entry $top.e$a -textvariable Function_Generator_config($a) \
		-relief sunken -width 30 -justify left
	pack $top.l$a $top.e$a -side left -expand 1
	
	set a choose_database_file_name
	button $top.$a -text "Browse" -command Function_Generator_browse
	pack $top.$a -side left -expand 1
	return ""
}

proc Function_Generator_autofill {} {
	upvar #0 Function_Generator_config config
	upvar #0 Function_Generator_info info
	upvar #0 LWDAQ_info_Receiver iinfo

	set autofill ""
	LWDAQ_reset_Receiver
	LWDAQ_acquire Receiver
	for {set id $config(min_id)} {$id <= $config(max_id)} {incr id} {
		if {[lsearch $iinfo(channel_activity) "$id\:*"] >= 0} {
			append autofill "$id "
		}		
	}
	if {$autofill == ""} {
		LWDAQ_print $info(text) "Autofill found no active channels."
	}
	set config(channels) [string trim $autofill]
	return $autofill
}

#
# We can create 4 waveforms: single integer(flat), triangle wave, sine wave, and square wave.
#
proc Function_Generator_create_waveform {value} {
	upvar #0 Function_Generator_config config
	upvar #0 Function_Generator_info info
	upvar #0 Function_Generator_wfgen wfgen
	set integer_data_list ""
	set data ""
	
	for {set j 0} {$j < $config(samples)} {incr j 1} {
		set wfgen(data,$j) 0
	}

	if {[string is integer -strict $value]} {
		for {set i 0} {$i < $config(samples)} {incr i 1} {
			set data $value
			set binary_byte ""
			set zz [binary format c* $data]
			binary scan $zz B* binary_byte
			set wfgen(data,$i) $binary_byte			
			lappend integer_data_list $data
		}
	} elseif {[string equal -nocase $value "triangle"]} {	
		set config(amplitude) \
			[Function_Generator_convert_voltage_to_memory_amplitude $config(voltage)]
		
		for {set i 0} {$i < [expr $config(samples) / 2]} {incr i 1} {
			set dc_offset [expr 128 - $config(amplitude)]
			set data [expr (($config(amplitude) * $i * 4) / $config(samples))]
			set binary_byte ""
			set zz [binary format c* $data]
			binary scan $zz B* binary_byte
			set wfgen(data,$i) $binary_byte			
			lappend integer_data_list $data
		}
		for {set i [expr $config(samples) / 2]} {$i < $config(samples)} {incr i 1} {
			set dc_offset [expr 0 + $config(amplitude)]
			set j [expr $i - ($config(samples)/2)]
			set data [expr (-$config(amplitude)* $j * 4 /$config(samples)) + 2*$dc_offset]
			set binary_byte ""
			set zz [binary format c* $data]
			binary scan $zz B* binary_byte
			set wfgen(data,$i) $binary_byte			
			lappend integer_data_list $data
		}
	} elseif {[string equal -nocase $value "sine"]} {
		for {set i 0} {$i < $config(samples)} {incr i 1} {
			set pi 3.1459
			set f $config(sine_cycles_per_memdepth)
			set phase [expr -3*$pi/2]
			set dc_offset [expr $config(dc_offset) + 128]
			set config(amplitude) \
				[Function_Generator_convert_voltage_to_memory_amplitude $config(voltage)]

			if {[expr $config(dc_offset) + $config(amplitude)] > 128} {
				set amplitude [expr 128 - $config(dc_offset)]
			} elseif {[expr $config(dc_offset) - $config(amplitude)] < -128} {
				set amplitude [expr $config(dc_offset) + 128]
			} else {
				set amplitude $config(amplitude)
			}
			set dc_offset [expr $amplitude]
			set data [expr int($amplitude*sin(2*$f*$pi*$i/($config(samples)-1) + $phase) + $dc_offset)]
			set binary_byte ""
			set zz [binary format c* $data]
			binary scan $zz B* binary_byte
			set wfgen(data,$i) $binary_byte 
			lappend integer_data_list $data
		}	
	} elseif {[string equal -nocase $value "square"]} {
		set config(amplitude) \
			[Function_Generator_convert_voltage_to_memory_amplitude $config(voltage)]
			if {$config(amplitude) > 127} {
				set config(amplitude) 127
			}		
		for {set i 0} {$i < [expr $config(samples) /2]} {incr i 1} {
			set data [expr $config(amplitude) + 128]
			set binary_byte ""
			set zz [binary format c* $data]
			binary scan $zz B* binary_byte
			set wfgen(data,$i) $binary_byte			
			lappend integer_data_list $data
		}
		for {set i [expr $config(samples) /2]} {$i < $config(samples)} {incr i 1} {
			set data [expr 128 - $config(amplitude)]
			set binary_byte ""
			set zz [binary format c* $data]
			binary scan $zz B* binary_byte
			set wfgen(data,$i) $binary_byte
			lappend integer_data_list $data
		}
	} else {
			LWDAQ_print $info(text) "Invalid waveform choice,\
				must be 'sine','triangle', 'square' or constant 0-255."
	}
	
	return $integer_data_list
}

proc Function_Generator_assemble_command {control_data wake lb cw control_addr} {
	upvar #0 Function_Generator_config config
	upvar #0 Function_Generator_info info
	upvar #0 Function_Generator_wfgen wfgen

	#Control data input is binary
	#Wake input is binary
	#lb input is binary
	#Control address is integer
	#DC16 DC15 DC14 DC13 DC12 DC11 DC10 DC9  DC8  DC7 DC6 DC5 DC4 DC3 DC2 DC1
	#D7    D6   D5   D4   D3   D2   D1  D0  WAKE  LB  CW  A4  A3  A2  A1  A0
	
	set binary_string ""
	append binary_string $control_data
	append binary_string $wake
	append binary_string $lb
	append binary_string $cw
	
	set zz [binary format c* $control_addr]
	binary scan $zz B* binary_control_addr
	set reduced_binary_control_addr [string range $binary_control_addr 3 end]
	append binary_string $reduced_binary_control_addr
	set command $binary_string
	
	return $command	
}
	
proc Function_Generator_execute_start {} {
	upvar #0 Function_Generator_info info
	upvar #0 Function_Generator_config config

	if {[catch {
		set sock [LWDAQ_socket_open $config(daq_ip_addr):$config(daq_driver_port)]
		 LWDAQ_set_driver_mux $sock $config(daq_driver_socket) $config(daq_mux_socket)
			set wake "1"
			set lb "0"
			#CW, control write, should be set to 0 during waveform playback.
			set cw "0"
		
			set start_command \
				[Function_Generator_assemble_command 00000000 $wake $lb $cw 8]
			LWDAQ_transmit_command_binary $sock $start_command
			
		LWDAQ_print $info(text) "Frequency Generator Enabled."
		LWDAQ_socket_close $sock
	} error_result]} {
		if {[info exists sock]} {LWDAQ_socket_close $sock}
		LWDAQ_print $info(text) "ERROR: $error_result"
	}
	return ""
}

proc Function_Generator_execute_stop {} {
	upvar #0 Function_Generator_info info
	upvar #0 Function_Generator_config config

	if {[catch {
		set sock [LWDAQ_socket_open $config(daq_ip_addr):$config(daq_driver_port)]
		 LWDAQ_set_driver_mux $sock $config(daq_driver_socket) $config(daq_mux_socket)
			set wake "1"
			set lb "0"
			set cw "1"
		
			set stop_command \
				[Function_Generator_assemble_command 00000000 $wake $lb $cw 9]
			LWDAQ_transmit_command_binary $sock $stop_command		

		LWDAQ_print $info(text) "Frequency Generator disabled."
		LWDAQ_socket_close $sock
	} error_result]} {
		if {[info exists sock]} {LWDAQ_socket_close $sock}
		LWDAQ_print $info(text) "ERROR: $error_result"
	}
	return ""
}

proc Function_Generator_set_analog_gain {} {
	upvar #0 Function_Generator_info info
	upvar #0 Function_Generator_config config

	if {[catch {
		set sock [LWDAQ_socket_open $config(daq_ip_addr):$config(daq_driver_port)]
    	LWDAQ_set_driver_mux $sock $config(daq_driver_socket) $config(daq_mux_socket)
			set wake "1"
			set lb "0"
			set cw "1"
			set gain ""
			append gain "1111" $config(analog_gain)
			set setgain_command \
				[Function_Generator_assemble_command $gain $wake $lb $cw 7]
			
			binary scan $config(analog_gain) "bbbb" b3 b2 b1 b0
						
			if {$b3 == 1} {
				set R3 $config(gain,r12)
				#LWDAQ_print $info(text) "R12 $R3 ohms enabled."
			} else {
				set R3 100000000.0
			}
			if {$b2 == 1} {
				set R2 $config(gain,r13)
				#LWDAQ_print $info(text) "R13 $R2 ohms enabled."
			} else {
				set R2 100000000.0
			}
			if {$b1 == 1} {
				set R1 $config(gain,r14)
				#LWDAQ_print $info(text) "R14 $R1 ohms enabled."
			} else {
				set R1 100000000.0
			}
			if {$b0 == 1} {
				set R0 $config(gain,r15)
				#LWDAQ_print $info(text) "R15 $R0 ohms enabled."
			} else {
				set R0 100000000.0
			}
			set Gsum [expr 1/($R3+4) + 1/($R2+4) + 1/($R1+4) + 1/($R0+4)]
			set Rsum [expr 1/$Gsum]
			set Rsum [format "%6.5f" $Rsum]
			set Ratio [expr $Rsum/($config(gain,dac) + $Rsum)]
			set Ratio [format "%6.5f" $Ratio]
			
			set ExpectedVoltageOutput [expr 3.3 * ($config(amplitude)/128.0) * $Ratio * (4*$config(gain,amplifier))]
			set ExpectedVoltageOutput [format "%6.5f" $ExpectedVoltageOutput]
			LWDAQ_transmit_command_binary $sock $setgain_command	
			LWDAQ_wait_for_driver $sock

		#LWDAQ_print $info(text) "Selected Resistance: $Rsum"
		#LWDAQ_print $info(text) "Expected Output Voltage(unloaded): $ExpectedVoltageOutput Vp-p"
		#LWDAQ_print $info(text) ""
		LWDAQ_socket_close $sock
	} error_result]} {
		if {[info exists sock]} {LWDAQ_socket_close $sock}
		LWDAQ_print $info(text) "ERROR: $error_result"
	}
	return ""
}

proc Function_Generator_set_rcfilter_bits {} {
	upvar #0 Function_Generator_info info
	upvar #0 Function_Generator_config config

	set rcfilter_bits ""
	append rcfilter_bits $config(filter_r)
	append rcfilter_bits $config(filter_c)
	if {[catch {
		set sock [LWDAQ_socket_open $config(daq_ip_addr):$config(daq_driver_port)]
		    LWDAQ_set_driver_mux $sock $config(daq_driver_socket) $config(daq_mux_socket)	

			set wake "1"
			set lb "0"
			set cw "1"
			set setrcf_command \
				[Function_Generator_assemble_command $rcfilter_bits $wake $lb $cw 6]
			LWDAQ_transmit_command_binary $sock $setrcf_command
			LWDAQ_wait_for_driver $sock
	
			#LWDAQ_print $info(text) "RC Filters Set to: $setrcf_command"
			LWDAQ_socket_close $sock
	} error_result]} {
		if {[info exists sock]} {LWDAQ_socket_close $sock}
		LWDAQ_print $info(text) "ERROR: $error_result"
	}
	return ""
}

proc dec2bin {i} {
	set res {}
	if {$i<0} {
		set sign -
		set i [expr {abs($i)}]
	} else {
		set sign {}
	}
	while {$i>0} {
		set res [expr {$i%2}]$res
		set i [expr $i/2]
	}
	if {$res == {}} {set res 0}
	
	append d [string repeat 0 16] $res
	set res [string range $d [string length $res] end]
	
	return $res
}

proc Function_Generator_frequency_sweep {{index "-1"}} {
	upvar #0 Function_Generator_info info
	upvar #0 Function_Generator_config config
	upvar #0 Function_Generator_data data
	upvar #0 LWDAQ_config_Receiver iconfig
	upvar #0 LWDAQ_info_Receiver iinfo
	global LWDAQ_Info	
	
	Function_Generator_set_frequencies	

	if {$index < 0} {
		if {$info(control) == "Sweep"} {return "0"}

		set info(control) "Sweep"
		
		if {$info(record_yn) == 1} {
			set f [open $config(database_file_name) a]
			set sweeptime [clock format [clock seconds] -format "%D %r"]
			puts $f "Sweep: $config(version)$config(batch) $sweeptime"
			close $f
		}
		
		Function_Generator_execute_stop
		
		#Set RC filter to 2khz
		set config(filter_r) "1000"
		set config(filter_c) "0001"
		Function_Generator_set_rcfilter_bits
		
		LWDAQ_print $info(text) "Setting frequency."
		
		# Creates a waveform and upload to RAM using the first frequency specified in 
		# $config(frequencies), which is adjustable in the GUI
		set config(input_frequency) [lindex $config(frequencies) 0]
		set config(samples) 5000
		Function_Generator_upload_ram
		
		# set config(analog_gain) 1111
		Function_Generator_set_analog_gain
		
		LWDAQ_print $info(text) "Memory Upload Complete."
		Function_Generator_adjust_sample_period
		
		#Set RC filter to 2khz
		set config(filter_r) "0010"
		set config(filter_c) "0010"
		Function_Generator_set_rcfilter_bits
		
		Function_Generator_execute_start
		LWDAQ_wait_ms $config(setup_delay_ms)
		
		# Call the sweep routine with the first frequency in the
		# sweep list.
		set data(output) ""
		LWDAQ_post [list Function_Generator_frequency_sweep "0"]
		return "1"
	}
	
	if {$index >= 0} {
		if {$info(control) == "Stop"} {
			LWDAQ_print $info(text) "Sweep aborted."
			set info(control) "Idle"
			return "0"
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
		set config(input_frequency) $frequency
		Function_Generator_adjust_sample_period
		LWDAQ_wait_ms [expr round(1.0*$config(setup_delay_ms)/$config(input_frequency))]

		LWDAQ_reset_Receiver
		set iconfig(analysis_channels) $config(channels)
		set iinfo(glitch_threshold) $config(glitch_threshold)
		set result [LWDAQ_acquire Receiver]
		set iconfig(analysis_channels) "*"
		if {[LWDAQ_is_error_result $result]} {
			LWDAQ_print $info(text) $result
			return "0"
		}
		set result [lrange $result 1 end]
		set output_line "$frequency "
		foreach c [lsort -increasing $config(channels)] {
			set amplitude [format %.1f [expr sqrt(2)*[lindex $result 3]]]
			set result [lrange $result 4 end]
			append output_line "$c $amplitude "
		}
		LWDAQ_print $info(text) "$output_line"
		lappend data(output) "$output_line"
		
		# Call the sweep routine with the next frequency, or if we are done,
		# write data to output file.
		incr index
		if {$index < [llength $config(frequencies)]} {
			LWDAQ_post [list Function_Generator_frequency_sweep $index]
			return "1"
		} {
			if {$info(record_yn) == 1} {
				set f [open $config(database_file_name) a]
				foreach line $data(output) {puts $f $line}
				puts $f $data(output)
				close $f
			}
			LWDAQ_print $info(text) "Sweep Complete."
			set info(control) "Idle"
			return "1"
		}
	}
}

proc Function_Generator_print_response {} {
	upvar #0 Function_Generator_info info
	upvar #0 Function_Generator_data data
	upvar #0 Function_Generator_config config

	foreach c [lsort -increasing -integer $config(channels)] {
		LWDAQ_print -nonewline $info(text) \
			"$config(version)$config(batch)\.$c\t"
	}
	LWDAQ_print $info(text)
	foreach output_line $data(output) {
		set output_line [lrange $output_line 1 end]
		foreach {c a} $output_line {
			LWDAQ_print -nonewline $info(text) "$a\t"
		}
		LWDAQ_print $info(text)
	}
	return ""
}

proc Function_Generator_convert_voltage_to_memory_amplitude {voltage} {
	upvar #0 Function_Generator_config config
	if {$voltage >=1} {
		set config(analog_gain) "0011"
		set memory_amplitude [expr round(13.11 * $voltage + 2.14)]
	} else {
		set config(analog_gain) "1100"
		set memory_amplitude [expr round(127.27* $voltage + 0.727)]
		#set config(analog_gain) "0011"
		#set memory_amplitude [expr round(13.11 * $voltage + 2.14)]
	}
		
	return $memory_amplitude
}

proc Function_Generator_set_frequency {} {
	upvar #0 Function_Generator_info info
	upvar #0 Function_Generator_config config

	Function_Generator_execute_stop
	
	#Select number of samples based on user selected frequency
	if {$config(input_frequency) >=1000000} {
		set config(samples) 4
	} elseif {$config(input_frequency) >400000} {
		set config(samples) 8
	} elseif {$config(input_frequency) >100000} {
		set config(samples) 20
	} elseif {$config(input_frequency) >=1250} {
		set config(samples) 100
	} elseif {$config(input_frequency) >= 10} {
		set config(samples) 1000
	} else {
		set config(samples) 5000
	}
	LWDAQ_print $info(text) "Setting frequency...this may take a few seconds"
	Function_Generator_upload_ram
	
	Function_Generator_set_analog_gain

	Function_Generator_auto_filter
	
	Function_Generator_adjust_sample_period
	
	Function_Generator_execute_start
	LWDAQ_print $info(text) "Output Enabled."
	return ""
}


proc Function_Generator_adjust_sample_period {} {
	upvar #0 Function_Generator_info info
	upvar #0 Function_Generator_config config

	set config(clock_divider) [expr round(40000000.0 / $config(samples) \
		/ $config(input_frequency)) - 1]
	set binary_period [dec2bin $config(clock_divider)]
	set period_upper_bits [string range $binary_period 0 7]
	set period_lower_bits [string range $binary_period 8 15]	
	set frequency [expr 40000000.0 / $config(samples) / ($config(clock_divider) + 1)]
	if {[catch {
			set sock [LWDAQ_socket_open $config(daq_ip_addr):$config(daq_driver_port)]
		 	LWDAQ_set_driver_mux $sock $config(daq_driver_socket) $config(daq_mux_socket)
			set wake "1"
			set lb "0"
			set cw "1"
		
			#Sets uppermost 8 bits
			set set_period_command \
				[Function_Generator_assemble_command $period_upper_bits $wake $lb $cw 18]
			LWDAQ_transmit_command_binary $sock $set_period_command
			
			#Sets lowermost 8 bits
			set set_period_command1 \
				[Function_Generator_assemble_command $period_lower_bits $wake $lb $cw 19]
			LWDAQ_transmit_command_binary $sock $set_period_command1	
			
			set latch_command \
				[Function_Generator_assemble_command 00000000 $wake $lb $cw 17]
			
			LWDAQ_print $info(text) "Requested (Hz): $config(input_frequency)\
				Actual (Hz): [format %.3f $frequency] \
				Divider: $config(clock_divider)"
			LWDAQ_socket_close $sock
	} error_result]} {
			if {[info exists sock]} {LWDAQ_socket_close $sock}
			LWDAQ_print $info(text) "ERROR: $error_result"
	}
	return ""
}


proc Function_Generator_auto_filter {} {
	upvar #0 Function_Generator_info info
	upvar #0 Function_Generator_config config

	set config(clock_divider) [expr int((40000000 / ($config(samples) * $config(input_frequency)))-1)]
	set binary_period [expr int([dec2bin $config(clock_divider)])]

if {$config(waveform_type) == "square"} {
	set filter $info(rcbits,2)
	set filter_value [lindex $info(rcfilter_choices) 2]
	LWDAQ_print $info(text) "Filter Frequency:   $filter_value Hz"
} else {	
	if {$config(input_frequency) <= 20} {
		set filter $info(rcbits,12)
		set filter_value [lindex $info(rcfilter_choices) 12]
		LWDAQ_print $info(text) "Filter Frequency:   $filter_value Hz"
	} elseif {$config(input_frequency) <= 400} {
		set filter $info(rcbits,13)
		set filter_value [lindex $info(rcfilter_choices) 13]
		LWDAQ_print $info(text) "Filter Frequency:   $filter_value Hz"
	} elseif {$config(input_frequency) <= 3000} {
		set filter $info(rcbits,4)
		set filter_value [lindex $info(rcfilter_choices) 4]
		LWDAQ_print $info(text) "Filter Frequency:   $filter_value Hz"
	} elseif {$config(input_frequency) <= 30000} {
		set filter $info(rcbits,0)
		set filter_value [lindex $info(rcfilter_choices) 0]
		LWDAQ_print $info(text) "Filter Frequency:   $filter_value Hz"
	} elseif {$config(input_frequency) <= 500000} {
		set filter $info(rcbits,1)
		set filter_value [lindex $info(rcfilter_choices) 1]
		LWDAQ_print $info(text) "Filter Frequency:   $filter_value Hz"
	} elseif {$config(input_frequency) <= 3000000} {
		set filter $info(rcbits,3)
		set filter_value [lindex $info(rcfilter_choices) 3]
		LWDAQ_print $info(text) "Filter Frequency:   $filter_value Hz"
	} else {
		set filter $info(rcbits,2)
		set filter_value [lindex $info(rcfilter_choices) 2]
		LWDAQ_print $info(text) "Filter Frequency:   $filter_value Hz"
	}	
}	
	if {[catch {
		set sock [LWDAQ_socket_open $config(daq_ip_addr):$config(daq_driver_port)]
		 LWDAQ_set_driver_mux $sock $config(daq_driver_socket) $config(daq_mux_socket)
			set wake "1"
			set lb "0"
			set cw "1"
			set setrcf_command \
				[Function_Generator_assemble_command $filter $wake $lb $cw 6]
			LWDAQ_transmit_command_binary $sock $setrcf_command
		LWDAQ_socket_close $sock
	} error_result]} {
		if {[info exists sock]} {LWDAQ_socket_close $sock}
		LWDAQ_print $info(text) "ERROR: $error_result"
	}
}

proc Function_Generator_upload_ram {} {
	upvar #0 Function_Generator_config config
	upvar #0 Function_Generator_info info
	upvar #0 Function_Generator_wfgen wfgen

	Function_Generator_create_waveform $config(waveform_type)

	if {[catch {
		set sock [LWDAQ_socket_open $config(daq_ip_addr):$config(daq_driver_port)]
		 LWDAQ_set_driver_mux $sock $config(daq_driver_socket) $config(daq_mux_socket)
			
			set wake "1"
			set lb "0"
			set cw "1"
			
			#Stop waveform playback before new RAM upload
			set stop_command \
				[Function_Generator_assemble_command 00000000 $wake $lb $cw 9]
			LWDAQ_transmit_command_binary $sock $stop_command
		
			set binary_repeat_counter [dec2bin $config(samples)]
			set repeat_counter_middle_bits [string range $binary_repeat_counter 0 7]
			set repeat_counter_lower_bits [string range $binary_repeat_counter 8 15]
			
			set repeat_counter_command \
				[Function_Generator_assemble_command 00000000 $wake $lb $cw 14]
			LWDAQ_transmit_command_binary $sock $repeat_counter_command
			set repeat_counter_command \
				[Function_Generator_assemble_command $repeat_counter_middle_bits $wake $lb $cw 15]
			LWDAQ_transmit_command_binary $sock $repeat_counter_command
			set repeat_counter_command \
				[Function_Generator_assemble_command $repeat_counter_lower_bits $wake $lb $cw 16]
			LWDAQ_transmit_command_binary $sock $repeat_counter_command
			set latch_command \
				[Function_Generator_assemble_command 00000000 $wake $lb $cw 17]
			LWDAQ_transmit_command_binary $sock $latch_command
		
		
			#Set RAM start address to zero.  ram data address uses control addresses 0-3
			set ram_address_command \
				[Function_Generator_assemble_command 00000000 $wake $lb $cw 3]
			LWDAQ_transmit_command_binary $sock $ram_address_command
			set ram_address_command \
				[Function_Generator_assemble_command 00000000 $wake $lb $cw 2]
			LWDAQ_transmit_command_binary $sock $ram_address_command
			set ram_address_command \
				[Function_Generator_assemble_command 00000000 $wake $lb $cw 1]
			LWDAQ_transmit_command_binary $sock $ram_address_command
		
			set latch_command \
				[Function_Generator_assemble_command 00000000 $wake $lb $cw 17]
			LWDAQ_transmit_command_binary $sock $latch_command
			LWDAQ_transmit_command_binary $sock $latch_command
	
			#Send the data through the ram portal.	
			for {set i 0} {$i < $config(samples)} {incr i 1} {
				set control_data $wfgen(data,$i)
				set wake "1"
				set lb "0"
				set cw "1"
				set control_addr "12"
				set command \
					[Function_Generator_assemble_command $control_data $wake $lb $cw $control_addr]
				LWDAQ_transmit_command_binary $sock $command	
			}
	
		LWDAQ_wait_for_driver $sock 1
		LWDAQ_print $info(text) "RAM uploaded."
		LWDAQ_socket_close $sock
	} error_result]} {
		if {[info exists sock]} {LWDAQ_socket_close $sock}
		LWDAQ_print $info(text) "ERROR: $error_result"
	}	
}	
 
 proc Function_Generator_view_frequency_response {} {
	upvar #0 Function_Generator_info info
	upvar #0 Function_Generator_config config
	upvar #0 Function_Generator_data data
	
	
	set w $info(window)\.info
	if {[winfo exists $w]} {return ""}
	toplevel $w
	wm title $w "$info(name) Frequency Response Viewer"
	
	image create photo $info(photo_name) -width 400 -height 400
	lwdaq_image_create -name $info(image_name) -width 400 -height 400
	
	foreach c [lsort -increasing $config(channels)] {
		set amplitudes ""
		foreach output_line $data(output) {
			set index [lsearch $output_line $c]
			lappend amplitudes [lindex $output_line [expr $index + 1]]
		}
		lwdaq_graph $amplitudes $info(image_name) -y_only 1 -color $c -entire 1 -fill 1 
	}
	
	lwdaq_draw $info(image_name) $info(photo_name)
	
	set f $w.graph
	frame $f
	pack $f -side top -fill x
	label $f.image -image $info(photo_name)
	pack $f.image
}

 
proc Function_Generator_view_waveform {} {
	upvar #0 Function_Generator_info info
	upvar #0 Function_Generator_config config
	
	set w $info(window)\.info
	if {[winfo exists $w]} {return ""}
	toplevel $w
	wm title $w "$info(name) Waveform Viewer"
	
	set data [Function_Generator_create_waveform $config(waveform_type)]
	
	
	image create photo $info(photo_name) -width 400 -height 400
	lwdaq_image_create -name $info(image_name) -width 400 -height 400
	
	lwdaq_graph $data $info(image_name) -y_only 1 -color 0 -entire 1 -fill 1 
	
	lwdaq_draw $info(image_name) $info(photo_name)
	
	set f $w.graph
	frame $f
	pack $f -side top -fill x
	label $f.image -image $info(photo_name)
	pack $f.image
	
}

proc Function_Generator_choose_filter {} {
	upvar #0 Function_Generator_config config
	upvar #0 Function_Generator_info info
	upvar #0 Function_Generator_var var
	set w $info(window)\.info
	if {[winfo exists $w]} {return ""}
	toplevel $w
	wm title $w "$info(name) RC Filter Choices"
	
	set f $w.top_frame
	frame $f 
	pack $f  -side top
	
	set g $w.top_frame.left
	frame $g
	
	for {set x 0} {$x < [llength $info(rcfilter_choices)]} {incr x 1} {
			set rctext [lindex $info(rcfilter_choices) $x] 
			
			button $g.r$x -text $rctext -width 10 \
				-command "Function_Generator_update_filter $x"
			label $g.lbl$x -text "Hz"
			grid $g.r$x $g.lbl$x -padx 10 -pady 2
	}
	pack $g -side left
	set h $w.top_frame.right
	frame $h 
}

proc Function_Generator_update_filter {val} {
	upvar #0 Function_Generator_config config
	upvar #0 Function_Generator_info info
	upvar #0 Function_Generator_var var
	
	set var(x) $val
	set filter $info(rcbits,$val)
	set filter_value [lindex $info(rcfilter_choices) $val]
	LWDAQ_print $info(text) "$val $filter $filter_value"
	
	if {[catch {
		set sock [LWDAQ_socket_open $config(daq_ip_addr):$config(daq_driver_port)]
		 LWDAQ_set_driver_mux $sock $config(daq_driver_socket) $config(daq_mux_socket)
			set wake "1"
			set lb "0"
			set cw "1"
			set setrcf_command \
				[Function_Generator_assemble_command $filter $wake $lb $cw 6]
			LWDAQ_transmit_command_binary $sock $setrcf_command
		LWDAQ_socket_close $sock
	} error_result]} {
		if {[info exists sock]} {LWDAQ_socket_close $sock}
		LWDAQ_print $info(text) "ERROR: $error_result"
	}
	return ""
}		

proc Function_Generator_open {} {
	upvar #0 Function_Generator_config config
	upvar #0 Function_Generator_info info
	upvar #0 LWDAQ_config_Receiver iconfig
		
	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
			
	set e1 $w.e1
	frame $e1
	pack $e1 -side top -fill x
	
	set tf $w.topframe
	frame $tf
	
	set mf1 $w.midframe
	frame $mf1
	
	set mf2 $w.midframe2
	frame $mf2
	
	set bf $w.botframe
	frame $bf
	pack $tf $mf1 $mf2 $bf -side top -fill x
	
	set c $tf.labels
	frame $c
	
	set d $tf.entries
	frame $d
	
	set c2 $tf.labels2
	frame $c2
	
	set d2 $tf.entries2
	frame $d2

	pack $c $d -side left -fill y
	pack $c2 $d2 -side right -fill y
	
	set e2 $mf2.buttons
	frame $e2
		
	label $c.l_ipaddr -text "IP Address" -anchor w -justify right
	entry $c.e_ipaddr -textvariable Function_Generator_config(daq_ip_addr) \
		-relief sunken -bd 1 -width 15 -justify right
		
	label $c.l_driversocket -text "Driver Socket" -anchor w -justify right
	entry $c.e_driversocket -textvariable Function_Generator_config(daq_driver_socket) \
		-relief sunken -bd 1 -width 15 -justify right
		
	label $c.l_muxsocket -text "Mux Socket" -anchor w -justify right
	entry $c.e_muxsocket -textvariable Function_Generator_config(daq_mux_socket) \
		-relief sunken -bd 1 -width 15 -justify right
	
	label $c.l_wftype -text "Waveform Type" -anchor w -justify right
	entry $c.e_wftype -textvariable Function_Generator_config(waveform_type) \
		-relief sunken -bd 1 -width 15 -justify right
		
	label $c.l_infreq -text "Output Frequency (Hz)" -anchor w -justify right
	entry $c.e_infreq -textvariable Function_Generator_config(input_frequency) \
		-relief sunken -bd 1 -width 15 -justify right
		
	label $c.wf_descr -text "Choose: sin, tri, square, or enter an integer."

	label $c.l_wfreq -text "Sine cycles per sample depth" -anchor w
	entry $c.e_wfreq -textvariable Function_Generator_config(sine_cycles_per_memdepth) \
		-relief sunken -bd 1 -width 15 -justify right
	
	label $c.l_dcoffset -text "DC Offset" -anchor w -justify right
	entry $c.e_dcoffset -textvariable Function_Generator_config(dc_offset) \
		-relief sunken -bd 1 -width 15 -justify right
	label $c.ldc_label -text "Choose: -127 < DC offset < 127" -anchor w -justify left
	
	label $c.l_amplitude -text "Output Voltage (Vp-p)" -anchor w -justify right
	entry $c.e_amplitude -textvariable Function_Generator_config(voltage) \
		-relief sunken -bd 1 -width 15 -justify right
	
	label $c.l_filter_r -text "RC Filter Resistance" -anchor w -justify right
	entry $d.e_filter_r -textvariable Function_Generator_config(filter_r) \
		-relief sunken -bd 1 -width 15 -justify right
		
	label $c.l_filter_c -text "RC Filter Capacitance" -anchor w -justify right
	entry $d.e_filter_c -textvariable Function_Generator_config(filter_c) \
		-relief sunken -bd 1 -width 15 -justify right
		
	button $e1.fresponse -text "Plot" \
		-command Function_Generator_view_frequency_response
	button $e1.fprint -text "Print" \
		-command Function_Generator_print_response
		
	button $e1.gainbutton -text "Set Gain" -command "LWDAQ_post Function_Generator_set_analog_gain"
	button $e1.sfreq -text "Set Output" -command "LWDAQ_post Function_Generator_set_frequency"
	button $e1.auto_filter -text "Auto Filter Select" -command "LWDAQ_post Function_Generator_auto_filter"
    button $e1.off -text "Off" -command "LWDAQ_post Function_Generator_execute_stop"
	button $e1.l_filterbutton -text "Choose Filter" -command Function_Generator_choose_filter
	label $e1.control -textvariable Function_Generator_info(control) -fg blue -width 8
	button $e1.fsweep -text "Sweep" -command "LWDAQ_post Function_Generator_frequency_sweep"
	button $e1.stop -text "Stop" -command "set Function_Generator_info(control) Stop"
	button $e1.help -text "Help" -command "LWDAQ_tool_help Function_Generator"
	button $e1.config -text "Configure" -command "LWDAQ_tool_configure Function_Generator"
	button $c.upload -text "Upload RAM" -command Function_Generator_upload_ram
    button $c.viewwv -text "View Waveform" -command Function_Generator_view_waveform
    button $c.receiver -text "Receiver" -command "LWDAQ_open Receiver"
    button $c.spectrometer -text "Spectrometer" -command "LWDAQ_run_tool Spectrometer"
	
	grid $c.l_ipaddr $c.e_ipaddr -sticky news
	grid $c.l_driversocket $c.e_driversocket -sticky news
	grid $c.l_muxsocket $c.e_muxsocket -sticky news
	grid $c.l_wftype $c.e_wftype -sticky news
	grid $c.l_infreq $c.e_infreq -sticky news
	grid $c.l_amplitude $c.e_amplitude -sticky news
	grid $c.upload $c.viewwv -sticky news
	grid $c.receiver $c.spectrometer -sticky news
		
	label $c2.l_Rdriverip -text "Receiver IP Address" -anchor w 
	entry $c2.e_Rdriverip -textvariable LWDAQ_config_Receiver(daq_ip_addr) \
		-relief sunken -bd 1 -width 15 -justify right
	grid $c2.l_Rdriverip $c2.e_Rdriverip -sticky news
		
	label $c2.l_Rdriversocket -text "Receiver Driver Socket" -anchor w 
	entry $c2.e_Rdriversocket -textvariable LWDAQ_config_Receiver(daq_driver_socket) \
		-relief sunken -bd 1 -width 15 -justify right
	grid $c2.l_Rdriversocket $c2.e_Rdriversocket -sticky news
		
	label $c2.l_Rmuxsocket -text "Receiver Mux Socket" -anchor w
	entry $c2.e_Rmuxsocket -textvariable LWDAQ_config_Receiver(daq_mux_socket) \
		-relief sunken -bd 1 -width 15 -justify right					
	grid $c2.l_Rmuxsocket $c2.e_Rmuxsocket -sticky news
	
	foreach a {Version Batch Channels} {
		set b [string tolower $a]
		label $c2.l_$b -text "Transmitter $a" -anchor w
		entry $c2.e_$b -textvariable Function_Generator_config($b) -justify right
		grid $c2.l_$b $c2.e_$b -sticky news
	}

	label $c2.l_autofill -text "Autodetect Channels"
	button $c2.autofill -text "Autodetect" -command Function_Generator_autofill
	grid $c2.l_autofill $c2.autofill -sticky news

	checkbutton $c2.cbutton -text "Save" -variable Function_Generator_info(record_yn)
	button $c2.fnamebutton -text "Choose File" -command Function_Generator_set_file_name
	grid $c2.cbutton $c2.fnamebutton -sticky news

	pack $e1.control $e1.fsweep $e1.stop $e1.fresponse $e1.fprint \
		$e1.sfreq $e1.off $e1.l_filterbutton \
		$e1.config $e1.help \
		-side left -fill x -expand yes

	button $e2.l_fset -text "Frequencies" -command {
		Function_Generator_set_frequencies 1
	}
	entry $e2.e_fset -textvariable Function_Generator_config(frequencies) -width 80 
	
	pack $e2.l_fset $e2.e_fset -side left -expand yes
	
	set f $bf.spsbuttons 
	frame $f
	pack $f -fill x
	
	label $f.spsl -text "Sample Rates:" 
	pack $f.spsl -side left -expand yes
	foreach sps $config(sample_rates) {
		checkbutton $f.sps$sps -text $sps -variable Function_Generator_config(en_$sps)
		pack $f.sps$sps -side left -expand yes
	}
	
	set f $bf.textwindow
	frame $f
	pack $e1 $e2 $f -side top -fill x
	
	set info(text) [LWDAQ_text_widget $f 90 20]
	LWDAQ_print $info(text) "$info(name) Version $info(version) \n" purple
	
	Function_Generator_set_frequencies
	
	return $w	
}

Function_Generator_init
Function_Generator_open

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

