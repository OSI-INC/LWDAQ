<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
frame $f.f
pack $f.f -side top
label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left
label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left
label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left
button $f.f.go -text Go -command go
pack $f.f.go -side left
button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left
button $f.f.rd -text Read -command rd
pack $f.f.rd
set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
  for {set fnum 0} {$fnum < 20} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -filter:v select=eq(n\,$fnum) -filter:v scale=$width\:$height -frames:v 1 \
			-c:v png -f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cccccccc h1 h2 h3 h4 h5 h6 h7 h8
		LWDAQ_print $t "$h1 $h2 $h3 $h4 $h5 $h6 $h7 $h8" purple
		LWDAQ_update

#		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
frame $f.f
pack $f.f -side top
label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left
label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left
label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left
button $f.f.go -text Go -command go
pack $f.f.go -side left
button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left
button $f.f.rd -text Read -command rd
pack $f.f.rd
set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
  for {set fnum 0} {$fnum < 20} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -filter:v select=eq(n\,$fnum) -filter:v scale=$width\:$height -frames:v 1 \
			-c:v png -f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img c8 header
		LWDAQ_print $t "$header" purple
		LWDAQ_update

#		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
frame $f.f
pack $f.f -side top
label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left
label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left
label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left
button $f.f.go -text Go -command go
pack $f.f.go -side left
button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left
button $f.f.rd -text Read -command rd
pack $f.f.rd
set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
  for {set fnum 0} {$fnum < 20} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -filter:v select=eq(n\,$fnum) -filter:v scale=$width\:$height -frames:v 1 \
			-c:v png -f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8 header
		LWDAQ_print $t "$header" purple
		LWDAQ_update

#		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
frame $f.f
pack $f.f -side top
label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left
label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left
label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left
button $f.f.go -text Go -command go
pack $f.f.go -side left
button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left
button $f.f.rd -text Read -command rd
pack $f.f.rd
set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
  for {set fnum 0} {$fnum < 20} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -filter:v select=eq(n\,$fnum) -filter:v scale=$width\:$height -frames:v 1 \
			-c:v png -f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8ii header len type 
		LWDAQ_print $t "$header" purple
		LWDAQ_update

#		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
frame $f.f
pack $f.f -side top
label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left
label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left
label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left
button $f.f.go -text Go -command go
pack $f.f.go -side left
button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left
button $f.f.rd -text Read -command rd
pack $f.f.rd
set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
  for {set fnum 0} {$fnum < 20} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -filter:v select=eq(n\,$fnum) -filter:v scale=$width\:$height -frames:v 1 \
			-c:v png -f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8ii header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

#		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
frame $f.f
pack $f.f -side top
label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left
label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left
label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left
button $f.f.go -text Go -command go
pack $f.f.go -side left
button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left
button $f.f.rd -text Read -command rd
pack $f.f.rd
set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
  for {set fnum 0} {$fnum < 20} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -filter:v select=eq(n\,$fnum) -filter:v scale=$width\:$height -frames:v 1 \
			-c:v png -f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8II header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

#		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
frame $f.f
pack $f.f -side top
label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left
label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left
label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left
button $f.f.go -text Go -command go
pack $f.f.go -side left
button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left
button $f.f.rd -text Read -command rd
pack $f.f.rd
set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
  for {set fnum 0} {$fnum < 20} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -filter:v select=eq(n\,$fnum) -filter:v scale=$width\:$height -frames:v 1 \
			-c:v png -f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

#		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
frame $f.f
pack $f.f -side top
label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left
label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left
label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left
button $f.f.go -text Go -command go
pack $f.f.go -side left
button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left
button $f.f.rd -text Read -command rd
pack $f.f.rd
set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
  for {set fnum 0} {$fnum < 20} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -filter:v select=eq(n\,$fnum) -filter:v scale=$width\:$height -frames:v 1 \
			-c:v png -f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
frame $f.f
pack $f.f -side top
label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left
label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left
label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left
button $f.f.go -text Go -command go
pack $f.f.go -side left
button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left
button $f.f.rd -text Read -command rd
pack $f.f.rd
set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
  for {set fnum 0} {$fnum < 200} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -filter:v select=eq(n\,$fnum) -filter:v scale=$width\:$height -frames:v 1 \
			-c:v png -f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
frame $f.f
pack $f.f -side top
label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left
label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left
label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left
button $f.f.go -text Go -command go
pack $f.f.go -side left
button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left
button $f.f.rd -text Read -command rd
pack $f.f.rd
set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
  for {set fnum 0} {$fnum < 200} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -filter:v 'select=eq(n\,$fnum)' -filter:v scale=$width\:$height -frames:v 1 \
			-c:v png -f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
frame $f.f
pack $f.f -side top
label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left
label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left
label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left
button $f.f.go -text Go -command go
pack $f.f.go -side left
button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left
button $f.f.rd -text Read -command rd
pack $f.f.rd
set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
  for {set fnum 0} {$fnum < 200} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -filter:v 'select=eq(n\,$fnum)' -filter:v scale=$width\:$height -frames:v 1 \
			-c:v png -f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 200} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-filter:v 'select=eq(n\,$fnum),scale=$width\:$height' -frames:v 1 \
			-f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 200} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-filter:v \"select=eq(n\,$fnum), scale=$width\:$height\" -frames:v 1 \
			-f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 200} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-filter:v select=eq(n\,$fnum) -frames:v 1 \
			-f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 200} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-filter:v \"select=eq(n\,$fnum\)\" -frames:v 1 \
			-f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 40} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set select "select=eq(n,$fnum)"
		LWDAQ_print $t $select green
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-filter:v $select -frames:v 1 \
			-f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 40} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set select "select=eq(n\\,$fnum)"
		LWDAQ_print $t $select green
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-filter:v $select -frames:v 1 \
			-f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 40} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set select "select=eq(n\\,$fnum)"
		LWDAQ_print $t $select green
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-filter:v '$select' -frames:v 1 \
			-f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 40} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-filter:v select=eq(n\\,$fnum) -frames:v 1 \
			-f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 40} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-filter:v 'select=\"eq(n,$fnum)\"' -frames:v 1 \
			-f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 40} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-filter:v select=\"eq(n,$fnum)\" -frames:v 1 \
			-f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 40} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-filter:v 'select=eq(n,$fnum)' -frames:v 1 \
			-f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 40} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set ch [open | $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-filter:v 'select=eq(n,$fnum)' -frames:v 1 \
			-f image2pipe -]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 40} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-filter:v \"select=eq(n,200)\" -frames:v 1 \
			-f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 40} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-filter:v select=eq(n\\,200) -frames:v 1 \
			-f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 40} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set ch [open "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-filter:v \"select=eq(n\\,200)\" -frames:v 1 \
			-f image2pipe -"]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 40} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set cmd "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-filter:v \"select=eq(n\\,200)\" -frames:v 1 \
			-f image2pipe -"
		LWDAQ_print $t $cmd green
		LWDAQ_update
		set ch [open $cmd]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 40} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set cmd "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-vf \"select=eq(n\\,200)\" -frames:v 1 \
			-f image2pipe -"
		LWDAQ_print $t $cmd green
		LWDAQ_update
		set ch [open $cmd]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 40} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set cmd "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-vf 'select=eq(n\\,200)' -frames:v 1 \
			-f image2pipe -"
		LWDAQ_print $t $cmd green
		LWDAQ_update
		set ch [open $cmd]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 40} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set cmd "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-vf '\"select=eq(n\\,200)\"' -frames:v 1 \
			-f image2pipe -"
		LWDAQ_print $t $cmd green
		LWDAQ_update
		set ch [open $cmd]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 40} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set cmd "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-vf \"'select=eq(n\\,200)'\" -frames:v 1 \
			-f image2pipe -"
		LWDAQ_print $t $cmd green
		LWDAQ_update
		set ch [open $cmd]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 40} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set cmd "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-vf \"select=eq(n\\,200)\" -frames:v 1 \
			-f image2pipe -"
		LWDAQ_print $t $cmd green
		LWDAQ_update
		set ch [open $cmd]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 400} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set cmd "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-vf \"select=eq(n\\\\,200)\" -frames:v 1 \
			-f image2pipe -"
		LWDAQ_print $t $cmd green
		LWDAQ_update
		set ch [open $cmd]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 400} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set cmd "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-vf \"select=eq(n\\\\,$fnum)\" -frames:v 1 \
			-f image2pipe -"
		LWDAQ_print $t $cmd green
		LWDAQ_update
		set ch [open $cmd]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 400} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
			if {![winfo exists $t]} {return}
			if {$start == 0} {return}
		}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set cmd "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-vf \"select=eq(n\\\\,$fnum)\" -frames:v 1 \
			-f image2pipe -"
		LWDAQ_print $t $cmd green
		LWDAQ_update
		set ch [open $cmd]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 400} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
		}
		if {![winfo exists $t]} {return}
		if {$start == 0} {return}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set cmd "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-vf \"select=eq(n\\\\,$fnum)\" -frames:v 1 \
			-f image2pipe -"
		LWDAQ_print $t $cmd green
		LWDAQ_update
		set ch [open $cmd]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 400} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
		}
		if {![winfo exists $t]} {return}
		if {$start == 0} {return}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set cmd "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-vf \"select=eq(n\\\\,$fnum)\" -frames:v 1 \
			-f image2pipe -"
		LWDAQ_print $t $cmd green
		LWDAQ_update
		set ch [open $cmd]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 400} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
		}
		if {![winfo exists $t]} {return}
		if {$start == 0} {return}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set cmd "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-vf \"select=eq(n\\\\,$fnum)\" -frames:v 1 \
			-f image2pipe -"
		set ch [open $cmd]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch

		binary scan $img cu8Ia4 header len type 
		LWDAQ_print $t "$header $len $type" purple
		LWDAQ_update

		$p put $img
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 400} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
		}
		if {![winfo exists $t]} {return}
		if {$start == 0} {return}
		LWDAQ_print $t "Frame $fnum"
		LWDAQ_update
		set prev $now
		set cmd "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-vf \"select=eq(n\\\\,$fnum)\" -frames:v 1 \
			-f image2pipe -"
		set ch [open $cmd]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch
		$p put $img
		LWDAQ_update
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	LWDAQ_print $t "Deleting files..." brown
	LWDAQ_update
	file delete -- {*}[glob -nocomplain *.png]
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 400} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
		}
		if {![winfo exists $t]} {return}
		if {$start == 0} {return}
		set prev $now
		set cmd "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-vf \"select=eq(n\\\\,$fnum)\" -frames:v 1 \
			-f image2pipe -"
		set ch [open $cmd]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch
		$p put $img
		LWDAQ_update
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

<script>
# Toomaker script creates a video player.
LWDAQ_run_tool Neuroplayer

set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top

frame $f.f
pack $f.f -side top

label $f.f.lfps -text "fps:"
entry $f.f.fps -textvariable fps -width 5
pack $f.f.lfps $f.f.fps -side left

label $f.f.lscale -text "Scale"
entry $f.f.scale -textvariable scale -width 5
pack $f.f.lscale $f.f.scale -side left

label $f.f.ltime -text "time (ms)" -width 7
label $f.f.time -textvariable vtime -width 8
pack $f.f.ltime $f.f.time -side left

button $f.f.go -text Go -command go
pack $f.f.go -side left

button $f.f.stop -text Stop -command stop
pack $f.f.stop -side left

button $f.f.rd -text Read -command rd
pack $f.f.rd

set vtime 0
set fps 20.0
set fn "V0000000000.mp4"
set scale 1.0
set start 0

proc rd {} {
	global t fps fn p vtime scale width height
	upvar #0 Neuroplayer_info info

	set fn [LWDAQ_get_file_name]
	cd [file dirname $fn]
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match ftime]} {
		set ftime 0
	}
	
	catch {exec $info(ffmpeg) -i $fn} answer
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set duration -1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match framerate]} {
		set framerate 20
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set width 820
		set height 616
	}

	LWDAQ_print $t "duration =  $duration s, framerate = $framerate fps,\
		width = $width, height = $height." brown
	set fps $framerate
	set height [expr round($scale*$height)]
	set width [expr round($scale*$width)]
	$p configure -width $width -height $height
	LWDAQ_update
}

proc stop {} {
	global start
	set start 0
}

proc go {} {
	global t fps fn p vtime width height scale start
	upvar #0 Neuroplayer_info info

	set start [clock milliseconds]
	set prev 0
	set vtime 0
	
	for {set fnum 0} {$fnum < 400} {incr fnum} {	
		while {[set now [clock milliseconds]] - $prev < 1000.0/$fps} {
			LWDAQ_wait_ms 1
		}
		if {![winfo exists $t]} {return}
		if {$start == 0} {return}
		set prev $now
		set cmd "| $info(ffmpeg) -nostdin -loglevel error \
			-i $fn -c:v png \
			-vf \"select=eq(n\\\\,$fnum)\" -frames:v 1 \
			-f image2pipe -"
		set ch [open $cmd]
		fconfigure $ch -translation binary -buffering full
		set img [read $ch]
		close $ch
		$p put $img
		LWDAQ_update
		set vtime [expr $vtime + round(1000.0/$fps)]
	}
	LWDAQ_print $t [expr [clock milliseconds] - $start]
}
</script>

