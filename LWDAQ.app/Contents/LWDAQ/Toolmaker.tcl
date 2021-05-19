<script>
button $f.get -text "Get" -command Get
button $f.run -text "Run" -command Run
button $f.stop -text "Stop" -command Stop
button $f.reseta -text "Reset_A" -command Reset_A
button $f.resetb -text "Reset_B" -command Reset_B
pack $f.get $f.run $f.stop $f.reseta $f.resetb -side left 

label $f.lclk2 -textvariable clk2 -width 4
label $f.lclk1 -textvariable clk1 -width 4
label $f.lclk0 -textvariable clk0 -width 4
label $f.version -textvariable version -width 4
pack $f.lclk2 $f.lclk1 $f.lclk0 $f.version  -side left

set running 0
set clk0 0
set clk1 0
set clk2 0
set version 0
set timeout 0

proc Run {} {
	global running
	set running 1
	LWDAQ_post doit
}

proc Get {} {
	LWDAQ_post getblock
}

proc Stop {} {
	global running
	set running 0
}

proc Reset_A {} {
	global t
	LWDAQ_print $t "Reset via software reset location."
	set sock [LWDAQ_socket_open 10.0.0.40]
	LWDAQ_byte_write $sock 41 1
	LWDAQ_wait_for_driver $sock
	LWDAQ_socket_close $sock
}

proc Reset_B {} {
	global t
	LWDAQ_print $t "Reset via reset command transmission."
	set sock [LWDAQ_socket_open 10.0.0.40]
	LWDAQ_transmit_command_hex $sock 0081
	LWDAQ_wait_for_driver $sock
	LWDAQ_socket_close $sock
}

proc getbyte {sock} {
	global running 
	LWDAQ_byte_write $sock 62 1
	set tm 0
	while {[LWDAQ_byte_read $sock 62] == 0} {
		incr tm
	}
	set b [LWDAQ_byte_read $sock 63]
	return [expr $b & 0xFF]
}

proc doit {} {
	global t running clk0 clk1 clk2 version
	set sock [LWDAQ_socket_open 10.0.0.40]
	
	set clk2 [getbyte $sock]
	set clk1 [getbyte $sock]
	set clk0 [getbyte $sock]
	set version [getbyte $sock]

	LWDAQ_socket_close $sock
	if {$running} {LWDAQ_post doit}
}

proc getblock {} {
	global t 
	set sock [LWDAQ_socket_open 10.0.0.40]
	set data [LWDAQ_stream_read $sock 63 64]
	LWDAQ_socket_close $sock
	
	binary scan $data c* decimal
	foreach {id hi lo ts} $decimal {
		LWDAQ_print $t "[expr $id & 0xFF] [expr $hi & 0xFF]\
			[expr $lo & 0xFF] [expr $ts & 0xFF]"
	}
	
}
</script>

<script>
for {set i 1} {$i <= 15} {incr i} {
	LWDAQ_print $t {
; Detector Coil Number $i\.
ld A,dm$i\_loc
push H
push A
pop IX
ld A,(IX)
ld (msg_write_addr),A}}

}
</script>

<script>
for {set i 1} {$i <= 15} {incr i} {
	LWDAQ_print $t {
; Detector Coil Number $i\.
ld A,dm$i\_loc
push H
push A
pop IX
ld A,(IX)
ld (msg_write_addr),A}

}
</script>

<script>
for {set i 1} {$i <= 15} {incr i} {
	LWDAQ_print $t {
; Detector Coil Number $i\.
ld A,dm$i\_loc
push H
push A
pop IX
ld A,(IX)
ld (msg_write_addr),A}

}
</script>

<script>
for {set i 1} {$i <= 15} {incr i} {
	LWDAQ_print $t " \
; Detector Coil Number $i\. \
ld A,dm$i\_loc \
push H \
push A \
pop IX \
ld A,(IX) \
ld (msg_write_addr),A"

}
</script>

<script>
for {set i 1} {$i <= 15} {incr i} {
	LWDAQ_print $t "\n; Detector Coil Number $i\."
	LWDAQ_print $t "ld A,dm$i\_loc"
	LWDAQ_print $t "push H"
	LWDAQ_print $t "pop IX"
	LWDAQ_print $t "ld A,(IX)"
	LWDAQ_print $t "ld (msg_write_addr),A"
}
</script>

<script>
for {set i 1} {$i <= 15} {incr i} {
	LWDAQ_print $t "\n; Detector Coil Number $i\."
	LWDAQ_print $t "ld A,dm$i\_loc"
	LWDAQ_print $t "push H"
	LWDAQ_print $t "push A"
	LWDAQ_print $t "pop IX"
	LWDAQ_print $t "ld A,(IX)"
	LWDAQ_print $t "ld (msg_write_addr),A"
}
</script>

<script>
for {set i 1} {$i <= 15} {incr i} {
	dm_calib_$i 0x00
}
</script>

<script>
for {set i 1} {$i <= 15} {incr i} {
	LWDAQ_print %t "dm_calib_$i 0x00"
}
</script>

<script>
for {set i 1} {$i <= 15} {incr i} {
	LWDAQ_print $t "dm_calib_$i 0x00"
}
</script>

<script>
for {set i 1} {$i <= 15} {incr i} {
	LWDAQ_print $t "\n; Detector Coil Number $i\."
	LWDAQ_print $t "ld A,dm_calib_$i"
	LWDAQ_print $t "ld (msg_write_addr),A"
}
</script>

<script>
for {set i 1} {$i <= 15} {incr i} {
	LWDAQ_print $t "ld A,dm_calib_$i"
	LWDAQ_print $t "ld (msg_write_addr),A"
}
</script>

<script>
for {set i 1} {$i <= 15} {incr i} {
	LWDAQ_print $t "const dm_calib_$i 0x00"
}
</script>

