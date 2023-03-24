<script>
# [24-MAR-23] Test classification and measure sensitivity of error. 
label $f.lx -text "x:"
entry $f.ex -textvariable x -width 6
label $f.ly -text "y:"
entry $f.ey -textvariable y -width 6
label $f.lz -text "z:"
entry $f.ez -textvariable z -width 6
pack $f.lx $f.ex $f.ly $f.ey $f.lz $f.ez -side left

label $f.lext -text "ext:"
entry $f.ext -textvariable ext -width 4
label $f.lstp -text "stp:"
entry $f.stp -textvariable stp -widt 4
pack $f.lext $f.ext $f.lstp $f.stp -side left

button $f.go -text "Go" -command {
	set count [go $x $y $z]
	LWDAQ_print $t "$x $y $z $count"
}
button $f.scanx -text "ScanX" -command {offset x}
button $f.scany -text "ScanY" -command {offset y}
button $f.scanz -text "ScanZ" -command {offset z}
pack $f.go $f.scanx $f.scany $f.scanz -side left

set x "-2.6"
set y "-4.35"
set z "520"
set ext 1.0
set stp 0.05

LWDAQ_open BCAM

proc go {x y z} {
	global t LWDAQ_config_BCAM

	LWDAQ_acquire BCAM
	set img $LWDAQ_config_BCAM(memory_name)
	set camera "test 0 0 0 0 0 2 25 0" 
	set t1 [clock milliseconds]
	lwdaq_scam $img project $camera "cylinder $x [expr $y-17.4] $z 0 -1 0 6.4 500"
	set t2 [clock milliseconds]
	lwdaq_scam $img project $camera "sphere $x $y $z 17.4"
	set t3 [clock milliseconds]
	set count [lwdaq_scam $img classify "20 %"]
	set t4 [clock milliseconds]
	lwdaq_draw $img bcam_photo -intensify exact
	set t5 [clock milliseconds]
	LWDAQ_print $t "[expr $t2-$t1] [expr $t3-$t2] [expr $t4-$t3] [expr $t5-$t4]"
	return "$count"
}

proc offset {direction} {
	global x y z ext stp t
	for {set offset -$ext} {$offset <= $ext} \
			{set offset [format %.3f [expr $offset+$stp]]} {
		if {![winfo exists $t]} {break}
		switch $direction {
			"x" {set count [go [expr $x+$offset] $y $z]}
			"y" {set count [go $x [expr $y+$offset] $z]}
			"z" {set count [go $x $y [expr $z+$offset]]}
		}
		LWDAQ_print $t "[format %.3f $offset] $count"
		LWDAQ_update
	}
}
</script>

<script>
# [24-MAR-23] Test classification and measure sensitivity of error. 
label $f.lx -text "x:"
entry $f.ex -textvariable x -width 6
label $f.ly -text "y:"
entry $f.ey -textvariable y -width 6
label $f.lz -text "z:"
entry $f.ez -textvariable z -width 6
pack $f.lx $f.ex $f.ly $f.ey $f.lz $f.ez -side left

label $f.lext -text "ext:"
entry $f.ext -textvariable ext -width 4
label $f.lstp -text "stp:"
entry $f.stp -textvariable stp -widt 4
pack $f.lext $f.ext $f.lstp $f.stp -side left

button $f.go -text "Go" -command {
	set count [go $x $y $z]
	LWDAQ_print $t "$x $y $z $count"
}
button $f.scanx -text "ScanX" -command {offset x}
button $f.scany -text "ScanY" -command {offset y}
button $f.scanz -text "ScanZ" -command {offset z}
pack $f.go $f.scanx $f.scany $f.scanz -side left

set x "-2.6"
set y "-4.35"
set z "520"
set ext 1.0
set stp 0.05

LWDAQ_open BCAM

proc go {x y z} {
	global t LWDAQ_config_BCAM

	LWDAQ_acquire BCAM
	set img $LWDAQ_config_BCAM(memory_name)
	set camera "test 0 0 0 0 0 2 25 0" 
	set t1 [clock milliseconds]
	lwdaq_scam $img project $camera "cylinder $x [expr $y-17.4] $z 0 -1 0 6.4 500"
	set t2 [clock milliseconds]
	lwdaq_scam $img project $camera "sphere $x $y $z 17.4"
	set t3 [clock milliseconds]
	set count [lwdaq_scam $img classify "20 %"]
	set t4 [clock milliseconds]
	lwdaq_draw $img bcam_photo -intensify exact
	set t5 [clock milliseconds]
	LWDAQ_print $t "[expr $t2-$t1] [expr $t3-$t2] [expr $t4-$t3] [expr $t5-$t4]"
	return "$count"
}

proc offset {direction} {
	global x y z ext stp t
	for {set offset -$ext} {$offset <= $ext} \
			{set offset [format %.3f [expr $offset+$stp]]} {
		if {![winfo exists $t]} {break}
		switch $direction {
			"x" {set count [go [expr $x+$offset] $y $z]}
			"y" {set count [go $x [expr $y+$offset] $z]}
			"z" {set count [go $x $y [expr $z+$offset]]}
		}
		LWDAQ_print $t "[format %.3f $offset] $count"
		LWDAQ_update
	}
}
</script>

