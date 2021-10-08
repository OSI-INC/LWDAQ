<script>
# Toolmaker script that flashes all LEDs on a thirty-size way injector (A2080B)
# and checks their power dissipation. The power level to which they are each
# turned on is the final digit in the command, and varies from 0 to A (zero to
# ten) in the P2080A03 firmware. The script starts by turning on LED 1, then
# goes through to LED 58. The script uses the Diagnostic Instrument to flash the
# LEDs so that it can measure current consumption from +15V and -15V. Specify
# the driver address and socket number in the fields provided by this tool.

set max_power 2000 
set min_power 1600
set run_injector_test 0

foreach {c} {go stop} {
	button $f.$c -text $c -command $c\_injector_test
	pack $f.$c -side left
}
foreach {element} {daq_ip_addr daq_driver_socket daq_mux_socket} {
	label $f.lbl$element -text $element 
	entry $f.ety$element -textvariable LWDAQ_config_Diagnostic($element) -width 10
	pack $f.lbl$element $f.ety$element -side left
}

proc go_injector_test {{start 1}} {
	global t run_injector_test 
	global max_power min_power 
	global LWDAQ_info_Diagnostic LWDAQ_config_Diagnostic

	set LWDAQ_config_Diagnostic(daq_actions) "transmit"
	
	if {$start} {
		if {$run_injector_test} {
			return
		} else {
			set run_injector_test 1
		}
	} 

	set count 0
	set okay 1
	foreach i {1 2 3 4 5 6 7 8 \
		17 18 19 20 21 22 23 24 \
		33 34 35 36 37 38 39 40 41 42 \
		49 50 51 52 53 54 55 56 57 58} {
		set LWDAQ_info_Diagnostic(commands) "0000"
		set result [LWDAQ_acquire Diagnostic]
		if {[LWDAQ_is_error_result $result]} {
			LWDAQ_print $t $result
			break
		}
		if {![winfo exists $t]} {break}
		if {!$run_injector_test} {
			LWDAQ_print $t "Test aborted.\n" purple
			return
		}
		set P15V [lindex $result 8]
		set N15V [lindex $result 12]
		set command [format %02X $i]87
		set LWDAQ_info_Diagnostic(commands) $command
		set result [LWDAQ_acquire Diagnostic]
		set P15V [format %.1f [expr [lindex $result 8] - $P15V]]
		set N15V [format %.1f [expr [lindex $result 12] - $N15V]]
		set power [format %.1f [expr $N15V * 15.0 + $N15V * 15.0]]
		incr count
		if {($power <= $max_power) && ($power >= $min_power)} {
			LWDAQ_print $t "LED $count okay, $power mW."
		} {
			LWDAQ_print $t "LED $count faulty, $power mW." orange
			set okay 0
		}
	}
	
	set LWDAQ_info_Diagnostic(commands) "0000"
	set result [LWDAQ_acquire Diagnostic]
	if {$okay} {
		LWDAQ_print $t "All $count LEDs okay.\n" green
	} else {
		LWDAQ_print $t "One or more faulty LEDs.\n" red
	}
	set run_injector_test 0
}

proc stop_injector_test {} {
	global run_injector_test
	set run_injector_test 0
}
</script>

<script>
# Toolmaker script that flashes all LEDs on a thirty-size way injector (A2080B)
# and checks their power dissipation. The power level to which they are each
# turned on is the final digit in the command, and varies from 0 to A (zero to
# ten) in the P2080A03 firmware. The script starts by turning on LED 1, then
# goes through to LED 58. The script uses the Diagnostic Instrument to flash the
# LEDs so that it can measure current consumption from +15V and -15V. Specify
# the driver address and socket number in the fields provided by this tool.

set max_power 2000 
set min_power 1600
set run_injector_test 0

foreach {c} {go stop} {
	button $f.$c -text $c -command $c\_injector_test
	pack $f.$c -side left
}
foreach {element} {daq_ip_addr daq_driver_socket daq_mux_socket} {
	label $f.lbl$element -text $element 
	entry $f.ety$element -textvariable LWDAQ_config_Diagnostic($element) \
		-width [expr [string length [set LWDAQ_config_Diagnostic($element)] + 4]]
	pack $f.lbl$element $f.ety$element -side left
}

proc go_injector_test {{start 1}} {
	global t run_injector_test 
	global max_power min_power 
	global LWDAQ_info_Diagnostic LWDAQ_config_Diagnostic

	set LWDAQ_config_Diagnostic(daq_actions) "transmit"
	
	if {$start} {
		if {$run_injector_test} {
			return
		} else {
			set run_injector_test 1
		}
	} 

	set count 0
	set okay 1
	foreach i {1 2 3 4 5 6 7 8 \
		17 18 19 20 21 22 23 24 \
		33 34 35 36 37 38 39 40 41 42 \
		49 50 51 52 53 54 55 56 57 58} {
		set LWDAQ_info_Diagnostic(commands) "0000"
		set result [LWDAQ_acquire Diagnostic]
		if {[LWDAQ_is_error_result $result]} {
			LWDAQ_print $t $result
			break
		}
		if {![winfo exists $t]} {break}
		if {!$run_injector_test} {
			LWDAQ_print $t "Test aborted.\n" purple
			return
		}
		set P15V [lindex $result 8]
		set N15V [lindex $result 12]
		set command [format %02X $i]87
		set LWDAQ_info_Diagnostic(commands) $command
		set result [LWDAQ_acquire Diagnostic]
		set P15V [format %.1f [expr [lindex $result 8] - $P15V]]
		set N15V [format %.1f [expr [lindex $result 12] - $N15V]]
		set power [format %.1f [expr $N15V * 15.0 + $N15V * 15.0]]
		incr count
		if {($power <= $max_power) && ($power >= $min_power)} {
			LWDAQ_print $t "LED $count okay, $power mW."
		} {
			LWDAQ_print $t "LED $count faulty, $power mW." orange
			set okay 0
		}
	}
	
	set LWDAQ_info_Diagnostic(commands) "0000"
	set result [LWDAQ_acquire Diagnostic]
	if {$okay} {
		LWDAQ_print $t "All $count LEDs okay.\n" green
	} else {
		LWDAQ_print $t "One or more faulty LEDs.\n" red
	}
	set run_injector_test 0
}

proc stop_injector_test {} {
	global run_injector_test
	set run_injector_test 0
}
</script>

<script>
# Toolmaker script that flashes all LEDs on a thirty-size way injector (A2080B)
# and checks their power dissipation. The power level to which they are each
# turned on is the final digit in the command, and varies from 0 to A (zero to
# ten) in the P2080A03 firmware. The script starts by turning on LED 1, then
# goes through to LED 58. The script uses the Diagnostic Instrument to flash the
# LEDs so that it can measure current consumption from +15V and -15V. Specify
# the driver address and socket number in the fields provided by this tool.

set max_power 2000 
set min_power 1600
set run_injector_test 0

foreach {c} {go stop} {
	button $f.$c -text $c -command $c\_injector_test
	pack $f.$c -side left
}
foreach {element} {daq_ip_addr daq_driver_socket daq_mux_socket} {
	label $f.lbl$element -text $element 
	entry $f.ety$element -textvariable LWDAQ_config_Diagnostic($element) \
		-width [expr [string length [set LWDAQ_config_Diagnostic($element)]] + 4]
	pack $f.lbl$element $f.ety$element -side left
}

proc go_injector_test {{start 1}} {
	global t run_injector_test 
	global max_power min_power 
	global LWDAQ_info_Diagnostic LWDAQ_config_Diagnostic

	set LWDAQ_config_Diagnostic(daq_actions) "transmit"
	
	if {$start} {
		if {$run_injector_test} {
			return
		} else {
			set run_injector_test 1
		}
	} 

	set count 0
	set okay 1
	foreach i {1 2 3 4 5 6 7 8 \
		17 18 19 20 21 22 23 24 \
		33 34 35 36 37 38 39 40 41 42 \
		49 50 51 52 53 54 55 56 57 58} {
		set LWDAQ_info_Diagnostic(commands) "0000"
		set result [LWDAQ_acquire Diagnostic]
		if {[LWDAQ_is_error_result $result]} {
			LWDAQ_print $t $result
			break
		}
		if {![winfo exists $t]} {break}
		if {!$run_injector_test} {
			LWDAQ_print $t "Test aborted.\n" purple
			return
		}
		set P15V [lindex $result 8]
		set N15V [lindex $result 12]
		set command [format %02X $i]87
		set LWDAQ_info_Diagnostic(commands) $command
		set result [LWDAQ_acquire Diagnostic]
		set P15V [format %.1f [expr [lindex $result 8] - $P15V]]
		set N15V [format %.1f [expr [lindex $result 12] - $N15V]]
		set power [format %.1f [expr $N15V * 15.0 + $N15V * 15.0]]
		incr count
		if {($power <= $max_power) && ($power >= $min_power)} {
			LWDAQ_print $t "LED $count okay, $power mW."
		} {
			LWDAQ_print $t "LED $count faulty, $power mW." orange
			set okay 0
		}
	}
	
	set LWDAQ_info_Diagnostic(commands) "0000"
	set result [LWDAQ_acquire Diagnostic]
	if {$okay} {
		LWDAQ_print $t "All $count LEDs okay.\n" green
	} else {
		LWDAQ_print $t "One or more faulty LEDs.\n" red
	}
	set run_injector_test 0
}

proc stop_injector_test {} {
	global run_injector_test
	set run_injector_test 0
}
</script>

