<script>
# [24-MAR-23] Test classification and measure sensitivity of error. 
label $f.lx -text "x:"
entry $f.ex -textvariable x -width 6
label $f.ly -text "y:"
entry $f.ey -textvariable y -width 6
label $f.lz -text "z:"
entry $f.ez -textvariable z -width 6
pack $f.lx $f.ex $f.ly $f.ey $f.lz $f.ez -side left
label $f.lth -text "th:"
entry $f.th -textvariable LWDAQ_config_BCAM(analysis_threshold) -width 8
pack $f.lth $f.th -side left

label $f.lext -text "ext:"
entry $f.ext -textvariable ext -width 4
label $f.lstp -text "stp:"
entry $f.stp -textvariable stp -widt 4
pack $f.lext $f.ext $f.lstp $f.stp -side left

button $f.go -text "Go" -command {
	set count [go $x $y $z]
	LWDAQ_print $t "$x $y $z $count"
	lwdaq_draw $LWDAQ_config_BCAM(memory_name) bcam_photo -intensify exact
}
button $f.scanx -text "ScanX" -command {offset x}
button $f.scany -text "ScanY" -command {offset y}
button $f.scanz -text "ScanZ" -command {offset z}
button $f.fit -text "Fit" -command {fit}
button $f.stop -text "Stop" -command {stop}
pack $f.go $f.scanx $f.scany $f.scanz $f.fit $f.stop -side left

set x "-2.6"
set y "-4.35"
set z "520"
set ext 1.0
set stp 0.05

LWDAQ_open BCAM
set LWDAQ_config_BCAM(analysis_enable) 0
set LWDAQ_config_BCAM(daq_flash_seconds) 0.05
lwdaq_config -text_name $t -fsd 3

proc go {x y z} {
	global t LWDAQ_config_BCAM

	if {![winfo exists $t]} {error}
	LWDAQ_acquire BCAM
	set img $LWDAQ_config_BCAM(memory_name)
	set camera "test 0 0 0 0 0 2 25 0" 
	set t1 [clock milliseconds]
	lwdaq_scam $img project $camera "cylinder $x [expr $y-17.4] $z 0 -1 0 6.4 500"
	set t2 [clock milliseconds]
	lwdaq_scam $img project $camera "sphere $x $y $z 17.4"
	set t3 [clock milliseconds]
	set count [lwdaq_scam $img classify $LWDAQ_config_BCAM(analysis_threshold)]
	set t4 [clock milliseconds]
	lwdaq_draw $img bcam_photo -intensify exact
	set t5 [clock milliseconds]
	# LWDAQ_print $t "[expr $t2-$t1] [expr $t3-$t2] [expr $t4-$t3] [expr $t5-$t4]"
	LWDAQ_print $t "[format %.3f $x] [format %.3f $y] [format %.1f $z] $count" orange
	LWDAQ_update
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

proc altitude {x y z10} {
	global stop_fit
	if {$stop_fit} {
		set stop_fit 0
		error
	}
	go $x $y [expr $z10*10]
}

proc stop {} {
	global stop_fit t
	LWDAQ_print $t "Stopping"
	set stop_fit 1
}

proc fit {} {
	global x y z t stop_fit
	set stop_fit 0
	set z10 [expr $z/10]
	set result [lwdaq_simplex "$x $y $z10" altitude -report 1 -max_steps 100]
	scan $result %f%f%f x y z10
	set z [format %.1f [expr $z10*10]]
	go $x $y $z
}
</script>

