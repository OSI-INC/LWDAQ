<script>
# LWDAQ Toolmaker Script to Set Analog Outputs of A2057.
# (C) 2020 Kevan Hashemi, Brandeis University

set p(driver_ip) "10.0.0.37"
set p(driver_socket) "6"
set p(value) "0"
set p(dac) "1"
set p(text) $t
label $f.vl -text "Value:"
entry $f.ve -textvariable p(value) -width 5
pack $f.vl $f.ve -side left -expand yes
foreach a "1 2" {
	set b [string tolower $a]
	radiobutton $f.dac$b -variable p(dac) -text "DAC$a" -value $a
	pack $f.dac$b -side left -expand 0
}
button $f.xmit -text "Set" -command {LWDAQ_post set_voltage}
pack $f.xmit -side left -expand yes
button $f.ramp -text "Ramp" -command {LWDAQ_post "ramp_voltage 0"}
pack $f.ramp -side left -expand yes

#
# A2057_set_dac takes a driver IP address, ip, a driver socket number, dsock,
# a multiplexer socket number, msock, a dac number, dac, and an eight-bit dac
# value in decimal, value, and these to set an A2057 dac value. The routine
# opens a socket, selects the A2057 and sends a string of thirty-five commands
# to the device to set one of its DAC outputs.
#
proc A2057_set_dac {ip dsock msock dac value} {

	# Construct the sixteen bit value we must send to the DAC.
	if {![string is integer -strict $value]} {
		error "value \"$value\" not an integer."
	}
	if {($value>255) || ($value<0)} {
		error "value \"$value\" must be 0..255."
	}
	set bits 0000[LWDAQ_decimal_to_binary $value 8]0000
	
	# Open a socket to the driver and select the A2057.
	set sock [LWDAQ_socket_open $ip]
	LWDAQ_set_driver_mux $sock $dsock $msock
	
	# Assert the frame sync bit.
	LWDAQ_transmit_command_hex $sock "6C80"
	
	# Select DAC1 or DAC2.
	if {$dac == 1} {set c "480"} else {set c "880"} 
	LWDAQ_transmit_command_hex $sock "6$c"
	
	# Transmit sixteen bits. Each bit requires two command words, one
	# to present the bit value and raise the clock, another to continue
	# the bit value while dropping the clock.
	for {set i 0} {$i < [string length $bits]} {incr i} {
		set b [string index $bits $i]
		if {$b} {
			LWDAQ_transmit_command_hex $sock "C$c"
			LWDAQ_transmit_command_hex $sock "8$c"
		} else {
			LWDAQ_transmit_command_hex $sock "4$c"
			LWDAQ_transmit_command_hex $sock "0$c"
		}
	}
	
	# End the transmission by deselecting both DACs.
	LWDAQ_transmit_command_hex $sock "4080"
	
	# Close the socket to the driver, freeing it for other activity.
	LWDAQ_wait_for_driver $sock
	LWDAQ_socket_close $sock
}

proc set_voltage {} {
	global p
	
	if {[catch {
		A2057_set_dac $p(driver_ip) $p(driver_socket) 1 $p(dac) $p(value)
	} result]} {
		LWDAQ_print $p(text) "ERROR: $result"
	} else {
		LWDAQ_print $p(text) "Set DAC value to $p(value)."
	}
}

proc ramp_voltage {i} {
	global p
	
	if {![winfo exists $p(text)]} {return}
	set p(value) $i
	set_voltage
	if {$i < 255} { 
		LWDAQ_post "ramp_voltage [expr ($i + 1) % 256]"
	}
}
</script>

<script>
# LWDAQ Toolmaker Script to Set Analog Outputs of A2057.
# (C) 2020 Kevan Hashemi, Brandeis University

set p(driver_ip) "10.0.0.37"
set p(driver_socket) "1"
set p(value) "0"
set p(dac) "1"
set p(text) $t
label $f.vl -text "Value:"
entry $f.ve -textvariable p(value) -width 5
pack $f.vl $f.ve -side left -expand yes
foreach a "1 2" {
	set b [string tolower $a]
	radiobutton $f.dac$b -variable p(dac) -text "DAC$a" -value $a
	pack $f.dac$b -side left -expand 0
}
button $f.xmit -text "Set" -command {LWDAQ_post set_voltage}
pack $f.xmit -side left -expand yes
button $f.ramp -text "Ramp" -command {LWDAQ_post "ramp_voltage 0"}
pack $f.ramp -side left -expand yes

#
# A2057_set_dac takes a driver IP address, ip, a driver socket number, dsock,
# a multiplexer socket number, msock, a dac number, dac, and an eight-bit dac
# value in decimal, value, and these to set an A2057 dac value. The routine
# opens a socket, selects the A2057 and sends a string of thirty-five commands
# to the device to set one of its DAC outputs.
#
proc A2057_set_dac {ip dsock msock dac value} {

	# Construct the sixteen bit value we must send to the DAC.
	if {![string is integer -strict $value]} {
		error "value \"$value\" not an integer."
	}
	if {($value>255) || ($value<0)} {
		error "value \"$value\" must be 0..255."
	}
	set bits 0000[LWDAQ_decimal_to_binary $value 8]0000
	
	# Open a socket to the driver and select the A2057.
	set sock [LWDAQ_socket_open $ip]
	LWDAQ_set_driver_mux $sock $dsock $msock
	
	# Assert the frame sync bit.
	LWDAQ_transmit_command_hex $sock "6C80"
	
	# Select DAC1 or DAC2.
	if {$dac == 1} {set c "480"} else {set c "880"} 
	LWDAQ_transmit_command_hex $sock "6$c"
	
	# Transmit sixteen bits. Each bit requires two command words, one
	# to present the bit value and raise the clock, another to continue
	# the bit value while dropping the clock.
	for {set i 0} {$i < [string length $bits]} {incr i} {
		set b [string index $bits $i]
		if {$b} {
			LWDAQ_transmit_command_hex $sock "C$c"
			LWDAQ_transmit_command_hex $sock "8$c"
		} else {
			LWDAQ_transmit_command_hex $sock "4$c"
			LWDAQ_transmit_command_hex $sock "0$c"
		}
	}
	
	# End the transmission by deselecting both DACs.
	LWDAQ_transmit_command_hex $sock "4080"
	
	# Close the socket to the driver, freeing it for other activity.
	LWDAQ_wait_for_driver $sock
	LWDAQ_socket_close $sock
}

proc set_voltage {} {
	global p
	
	if {[catch {
		A2057_set_dac $p(driver_ip) $p(driver_socket) 1 $p(dac) $p(value)
	} result]} {
		LWDAQ_print $p(text) "ERROR: $result"
	} else {
		LWDAQ_print $p(text) "Set DAC value to $p(value)."
	}
}

proc ramp_voltage {i} {
	global p
	
	if {![winfo exists $p(text)]} {return}
	set p(value) $i
	set_voltage
	if {$i < 255} { 
		LWDAQ_post "ramp_voltage [expr ($i + 1) % 256]"
	}
}
</script>

<script>
# LWDAQ Toolmaker Script to Set Analog Outputs of A2057.
# (C) 2020 Kevan Hashemi, Brandeis University

set p(driver_ip) "10.0.0.37"
set p(driver_socket) "1"
set p(value) "0"
set p(dac) "1"
set p(text) $t
label $f.vl -text "Value:"
entry $f.ve -textvariable p(value) -width 5
pack $f.vl $f.ve -side left -expand yes
foreach a "1 2" {
	set b [string tolower $a]
	radiobutton $f.dac$b -variable p(dac) -text "DAC$a" -value $a
	pack $f.dac$b -side left -expand 0
}
button $f.xmit -text "Set" -command {LWDAQ_post set_voltage}
pack $f.xmit -side left -expand yes
button $f.ramp -text "Ramp" -command {LWDAQ_post "ramp_voltage 0"}
pack $f.ramp -side left -expand yes

#
# A2057_set_dac takes a driver IP address, ip, a driver socket number, dsock,
# a multiplexer socket number, msock, a dac number, dac, and an eight-bit dac
# value in decimal, value, and these to set an A2057 dac value. The routine
# opens a socket, selects the A2057 and sends a string of thirty-five commands
# to the device to set one of its DAC outputs.
#
proc A2057_set_dac {ip dsock msock dac value} {

	# Construct the sixteen bit value we must send to the DAC.
	if {![string is integer -strict $value]} {
		error "value \"$value\" not an integer."
	}
	if {($value>255) || ($value<0)} {
		error "value \"$value\" must be 0..255."
	}
	set bits 0000[LWDAQ_decimal_to_binary $value 8]0000
	
	# Open a socket to the driver and select the A2057.
	set sock [LWDAQ_socket_open $ip]
	LWDAQ_set_driver_mux $sock $dsock $msock
	
	# Assert the frame sync bit.
	LWDAQ_transmit_command_hex $sock "6C80"
	
	# Select DAC1 or DAC2.
	if {$dac == 1} {set c "480"} else {set c "880"} 
	LWDAQ_transmit_command_hex $sock "6$c"
	
	# Transmit sixteen bits. Each bit requires two command words, one
	# to present the bit value and raise the clock, another to continue
	# the bit value while dropping the clock.
	for {set i 0} {$i < [string length $bits]} {incr i} {
		set b [string index $bits $i]
		if {$b} {
			LWDAQ_transmit_command_hex $sock "C$c"
			LWDAQ_transmit_command_hex $sock "8$c"
		} else {
			LWDAQ_transmit_command_hex $sock "4$c"
			LWDAQ_transmit_command_hex $sock "0$c"
		}
	}
	
	# End the transmission by deselecting both DACs.
	LWDAQ_transmit_command_hex $sock "4080"
	
	# Close the socket to the driver, freeing it for other activity.
	LWDAQ_wait_for_driver $sock
	LWDAQ_socket_close $sock
}

proc set_voltage {} {
	global p
	
	if {[catch {
		A2057_set_dac $p(driver_ip) $p(driver_socket) 1 $p(dac) $p(value)
	} result]} {
		LWDAQ_print $p(text) "ERROR: $result"
	} else {
		LWDAQ_print $p(text) "Set DAC value to $p(value)."
	}
}

proc ramp_voltage {i} {
	global p
	
	if {![winfo exists $p(text)]} {return}
	set p(value) $i
	set_voltage
	if {$i < 255} { 
		LWDAQ_post "ramp_voltage [expr ($i + 1) % 256]"
	}
}
</script>

<script>
# LWDAQ Toolmaker Script to Set Analog Outputs of A2057.
# (C) 2020 Kevan Hashemi, Brandeis University

set p(driver_ip) "10.0.0.37"
set p(driver_socket) "2"
set p(value) "0"
set p(dac) "1"
set p(text) $t
label $f.vl -text "Value:"
entry $f.ve -textvariable p(value) -width 5
pack $f.vl $f.ve -side left -expand yes
foreach a "1 2" {
	set b [string tolower $a]
	radiobutton $f.dac$b -variable p(dac) -text "DAC$a" -value $a
	pack $f.dac$b -side left -expand 0
}
button $f.xmit -text "Set" -command {LWDAQ_post set_voltage}
pack $f.xmit -side left -expand yes
button $f.ramp -text "Ramp" -command {LWDAQ_post "ramp_voltage 0"}
pack $f.ramp -side left -expand yes

#
# A2057_set_dac takes a driver IP address, ip, a driver socket number, dsock,
# a multiplexer socket number, msock, a dac number, dac, and an eight-bit dac
# value in decimal, value, and these to set an A2057 dac value. The routine
# opens a socket, selects the A2057 and sends a string of thirty-five commands
# to the device to set one of its DAC outputs.
#
proc A2057_set_dac {ip dsock msock dac value} {

	# Construct the sixteen bit value we must send to the DAC.
	if {![string is integer -strict $value]} {
		error "value \"$value\" not an integer."
	}
	if {($value>255) || ($value<0)} {
		error "value \"$value\" must be 0..255."
	}
	set bits 0000[LWDAQ_decimal_to_binary $value 8]0000
	
	# Open a socket to the driver and select the A2057.
	set sock [LWDAQ_socket_open $ip]
	LWDAQ_set_driver_mux $sock $dsock $msock
	
	# Assert the frame sync bit.
	LWDAQ_transmit_command_hex $sock "6C80"
	
	# Select DAC1 or DAC2.
	if {$dac == 1} {set c "480"} else {set c "880"} 
	LWDAQ_transmit_command_hex $sock "6$c"
	
	# Transmit sixteen bits. Each bit requires two command words, one
	# to present the bit value and raise the clock, another to continue
	# the bit value while dropping the clock.
	for {set i 0} {$i < [string length $bits]} {incr i} {
		set b [string index $bits $i]
		if {$b} {
			LWDAQ_transmit_command_hex $sock "C$c"
			LWDAQ_transmit_command_hex $sock "8$c"
		} else {
			LWDAQ_transmit_command_hex $sock "4$c"
			LWDAQ_transmit_command_hex $sock "0$c"
		}
	}
	
	# End the transmission by deselecting both DACs.
	LWDAQ_transmit_command_hex $sock "4080"
	
	# Close the socket to the driver, freeing it for other activity.
	LWDAQ_wait_for_driver $sock
	LWDAQ_socket_close $sock
}

proc set_voltage {} {
	global p
	
	if {[catch {
		A2057_set_dac $p(driver_ip) $p(driver_socket) 1 $p(dac) $p(value)
	} result]} {
		LWDAQ_print $p(text) "ERROR: $result"
	} else {
		LWDAQ_print $p(text) "Set DAC value to $p(value)."
	}
}

proc ramp_voltage {i} {
	global p
	
	if {![winfo exists $p(text)]} {return}
	set p(value) $i
	set_voltage
	if {$i < 255} { 
		LWDAQ_post "ramp_voltage [expr ($i + 1) % 256]"
	}
}
</script>

<script>
# LWDAQ Toolmaker Script to Set Analog Outputs of A2057.
# (C) 2020 Kevan Hashemi, Brandeis University

set p(driver_ip) "10.0.0.37"
set p(driver_socket) "2"
set p(value) "0"
set p(dac) "1"
set p(text) $t
label $f.vl -text "Value:"
entry $f.ve -textvariable p(value) -width 5
pack $f.vl $f.ve -side left -expand yes
label $f.lsock -text "Socket:"
entry $f.esock -textvariable p(driver_socket) -width 5
pack $f.lsock $f.esock -side left -expand yes
foreach a "1 2" {
	set b [string tolower $a]
	radiobutton $f.dac$b -variable p(dac) -text "DAC$a" -value $a
	pack $f.dac$b -side left -expand 0
}
button $f.xmit -text "Set" -command {LWDAQ_post set_voltage}
pack $f.xmit -side left -expand yes
button $f.ramp -text "Ramp" -command {LWDAQ_post "ramp_voltage 0"}
pack $f.ramp -side left -expand yes

#
# A2057_set_dac takes a driver IP address, ip, a driver socket number, dsock,
# a multiplexer socket number, msock, a dac number, dac, and an eight-bit dac
# value in decimal, value, and these to set an A2057 dac value. The routine
# opens a socket, selects the A2057 and sends a string of thirty-five commands
# to the device to set one of its DAC outputs.
#
proc A2057_set_dac {ip dsock msock dac value} {

	# Construct the sixteen bit value we must send to the DAC.
	if {![string is integer -strict $value]} {
		error "value \"$value\" not an integer."
	}
	if {($value>255) || ($value<0)} {
		error "value \"$value\" must be 0..255."
	}
	set bits 0000[LWDAQ_decimal_to_binary $value 8]0000
	
	# Open a socket to the driver and select the A2057.
	set sock [LWDAQ_socket_open $ip]
	LWDAQ_set_driver_mux $sock $dsock $msock
	
	# Assert the frame sync bit.
	LWDAQ_transmit_command_hex $sock "6C80"
	
	# Select DAC1 or DAC2.
	if {$dac == 1} {set c "480"} else {set c "880"} 
	LWDAQ_transmit_command_hex $sock "6$c"
	
	# Transmit sixteen bits. Each bit requires two command words, one
	# to present the bit value and raise the clock, another to continue
	# the bit value while dropping the clock.
	for {set i 0} {$i < [string length $bits]} {incr i} {
		set b [string index $bits $i]
		if {$b} {
			LWDAQ_transmit_command_hex $sock "C$c"
			LWDAQ_transmit_command_hex $sock "8$c"
		} else {
			LWDAQ_transmit_command_hex $sock "4$c"
			LWDAQ_transmit_command_hex $sock "0$c"
		}
	}
	
	# End the transmission by deselecting both DACs.
	LWDAQ_transmit_command_hex $sock "4080"
	
	# Close the socket to the driver, freeing it for other activity.
	LWDAQ_wait_for_driver $sock
	LWDAQ_socket_close $sock
}

proc set_voltage {} {
	global p
	
	if {[catch {
		A2057_set_dac $p(driver_ip) $p(driver_socket) 1 $p(dac) $p(value)
	} result]} {
		LWDAQ_print $p(text) "ERROR: $result"
	} else {
		LWDAQ_print $p(text) "Set DAC value to $p(value)."
	}
}

proc ramp_voltage {i} {
	global p
	
	if {![winfo exists $p(text)]} {return}
	set p(value) $i
	set_voltage
	if {$i < 255} { 
		LWDAQ_post "ramp_voltage [expr ($i + 1) % 256]"
	}
}
</script>

