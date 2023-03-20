<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

if {$info(os) == "Windows"} {
	set ch [open "| [info nameofexecutable]" w+]
} else {
	set ch [open "| ./lwdaq" w+]
}
fconfigure $ch -translation auto -buffering line -blocking 0
puts "Opened new LWDAQ with channel $ch."

if {$info(os) == "Windows"} {
	puts $ch {source LWDAQ.app/Contents/LWDAQ/Init.tcl}
} 
puts "Initialized the new LWDAQ."

puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
puts "Opened the standalone tool."
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

if {$info(os) == "Windows"} {
	set ch [open "| [info nameofexecutable]" w+]
} else {
	set ch [open "| ./lwdaq" w+]
}
fconfigure $ch -translation auto -buffering line -blocking 0
puts "Opened new LWDAQ with channel $ch."

if {$info(os) == "Windows"} {
	puts $ch {source LWDAQ.app/Contents/LWDAQ/Init.tcl}
} 
puts "Initialized the new LWDAQ."

puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
puts "Opened the standalone tool."
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

if {$info(os) == "Windows"} {
	set ch [open "| [info nameofexecutable]" w+]
} else {
	set ch [open "| ./lwdaq" w+]
}
fconfigure $ch -translation auto -buffering line -blocking 0
puts "Opened new LWDAQ with channel $ch."

if {$info(os) == "Windows"} {
	puts $ch {source LWDAQ.app/Contents/LWDAQ/Init.tcl}
} 
puts "Initialized the new LWDAQ."

puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
puts "Opened the standalone tool."
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

if {$info(os) == "Windows"} {
	set ch [open "| ./LWDAQ.bat --gui" w+]
} else {
	set ch [open "| ./lwdaq" w+]
}
fconfigure $ch -translation auto -buffering line -blocking 0
puts "Opened new LWDAQ with channel $ch."

if {$info(os) == "Windows"} {
	puts $ch {source LWDAQ.app/Contents/LWDAQ/Init.tcl}
} 
puts "Initialized the new LWDAQ."

puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
puts "Opened the standalone tool."
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./LWDAQ.bat --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
puts "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
puts "Opened the standalone tool."
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./lwdaq --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
puts "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
puts "Opened the standalone tool."
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./lwdaq --quiet --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
puts "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
puts "Opened the standalone tool."
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./lwdaq --quiet --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
puts "Opened new LWDAQ with channel $ch."
puts $ch {set LWDAQ_Info(console_prompt) ""}
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
puts "Opened the standalone tool."
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./lwdaq --quiet --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
puts "Opened new LWDAQ with channel $ch."
puts $ch {set LWDAQ_Info(console_prompt) ""}
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
gets $ch line
if {![regexp {SUCCESS} $line]} {
	puts "ERROR: $line"
}
puts "Opened the standalone tool."
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./lwdaq --quiet --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 1
puts "Opened new LWDAQ with channel $ch."
puts $ch {set LWDAQ_Info(console_prompt) ""}
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
gets $ch line
if {![regexp {SUCCESS} $line]} {
	puts "ERROR: $line"
}
puts "Opened the standalone tool."
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./lwdaq --quiet --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 1
puts "Opened new LWDAQ with channel $ch."
puts $ch {set LWDAQ_Info(console_prompt) ""}
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
gets $ch line
if {![regexp {SUCCESS} $line]} {
	puts "Failed to open standalone tool."
} else {
	puts "Opened the standalone tool."
}
fconfigure $ch -blocking 0
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./lwdaq --quiet --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 1
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {set LWDAQ_Info(console_prompt) ""}
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
gets $ch line
if {![regexp {SUCCESS} $line]} {
	LWDAQ_print $t "ERROR: Failed to open standalone tool."
} else {
	LWDAQ_print $t "Opened the standalone tool."
}
fconfigure $ch -blocking 0
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./lwdaq --quiet --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 1
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {set LWDAQ_Info(console_prompt) ""}
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
gets $ch line
if {![regexp {SUCCESS} $line]} {
	LWDAQ_print $t "ERROR: Failed to open standalone tool."
} else {
	LWDAQ_print $t "Opened the standalone tool."
}
puts $ch {Videoarchiver_read}
gets $ch line
LWDAQ_print $t $line
fconfigure $ch -blocking 0
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./lwdaq --quiet --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 1
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {set LWDAQ_Info(console_prompt) ""}
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
gets $ch line
if {![regexp {SUCCESS} $line]} {
	LWDAQ_print $t "ERROR: Failed to open standalone tool."
} else {
	LWDAQ_print $t "Opened the standalone tool."
}
puts $ch {Videoplayer_read}
gets $ch line
LWDAQ_print $t $line
fconfigure $ch -blocking 0
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./lwdaq --quiet --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 1
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {set LWDAQ_Info(console_prompt) ""}
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
gets $ch line
if {![regexp {SUCCESS} $line]} {
	LWDAQ_print $t "ERROR: Failed to open standalone tool."
} else {
	LWDAQ_print $t "Opened the standalone tool."
}
puts $ch {Videoplayer_read /Users/kevan/Desktop/Scratch/VideoPlayer/V1234567890.mp4}
gets $ch line
LWDAQ_print $t "Opened $line"
puts $ch {Videoplayer_play}
puts $ch {set Videoplayer_info(frame_count)}
gets $ch line
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./lwdaq --quiet --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 1
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {set LWDAQ_Info(console_prompt) ""}
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
gets $ch line
if {![regexp {SUCCESS} $line]} {
	LWDAQ_print $t "ERROR: Failed to open standalone tool."
} else {
	LWDAQ_print $t "Opened the standalone tool."
}
puts $ch {Videoplayer_read /Users/kevan/Desktop/Scratch/VideoPlayer/V1234567890.mp4}
gets $ch line
LWDAQ_print $t "Opened $line"
fconfigure $ch -translation auto -buffering line -blocking 0
puts $ch {Videoplayer_play}
puts $ch {set Videoplayer_info(frame_count)}
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./lwdaq --quiet --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 1
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {set LWDAQ_Info(console_prompt) ""}
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
gets $ch line
if {![regexp {SUCCESS} $line]} {
	LWDAQ_print $t "ERROR: Failed to open standalone tool."
} else {
	LWDAQ_print $t "Opened the standalone tool."
}
puts $ch {Videoplayer_read /Users/kevan/Desktop/Scratch/VideoPlayer/V1234567890.mp4}
gets $ch line
LWDAQ_print $t "Opened $line"
fconfigure $ch -translation auto -buffering line -blocking 0
puts $ch {Videoplayer_play}
puts $ch {set Videoplayer_info(frame_count)}
</script>

<script>
upvar #0 LWDAQ_Info info
cd $info(program_dir)
set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
fconfigure $ch -translation auto -buffering line -blocking 1
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
puts $ch {Videoplayer_read /Users/kevan/Desktop/Scratch/VideoPlayer/V1234567890.mp4}
</script>

<script>
upvar #0 LWDAQ_Info info
cd $info(program_dir)
set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
puts $ch {Videoplayer_read /Users/kevan/Desktop/Scratch/VideoPlayer/V1234567890.mp4}
</script>

<script>
upvar #0 LWDAQ_Info info
cd $info(program_dir)
set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
puts $ch {Videoplayer_read /Users/kevan/Desktop/Scratch/VideoPlayer/V1234567890.mp4}
</script>

<script>
upvar #0 LWDAQ_Info info
cd $info(program_dir)
set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Slave}
puts $ch {Videoplayer_read /Users/kevan/Desktop/Scratch/VideoPlayer/V1234567890.mp4}
</script>

<script>
upvar #0 LWDAQ_Info info
cd $info(program_dir)
set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Slave}
puts $ch {Videoplayer_read /Users/kevan/Desktop/Scratch/VideoPlayer/V1234567890.mp4}
</script>

<script>
upvar #0 LWDAQ_Info info
cd $info(program_dir)
set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Slave}
puts $ch {Videoplayer_play /Users/kevan/Desktop/Scratch/VideoPlayer/V1234567890.mp4}
</script>

<script>
upvar #0 LWDAQ_Info info
cd $info(program_dir)
set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Slave}
puts $ch {Videoplayer_play}
</script>

<script>
upvar #0 LWDAQ_Info info
cd $info(program_dir)
set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Slave}
puts $ch {Videoplayer_play}
</script>

<script>
upvar #0 LWDAQ_Info info
cd $info(program_dir)
set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Slave}
puts $ch {Videoplayer_play}
</script>

<script>
upvar #0 LWDAQ_Info info
cd $info(program_dir)
set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Slave}
puts $ch {videoplayer play}
</script>

<script>
upvar #0 LWDAQ_Info info
cd $info(program_dir)
set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Slave}
puts $ch {videoplayer play}
</script>

<script>
upvar #0 LWDAQ_Info info
cd $info(program_dir)
set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Slave}
puts $ch {videoplayer_pickfile browse}
puts $ch {videoplayer play}
</script>

<script>
upvar #0 LWDAQ_Info info
cd $info(program_dir)
set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Slave}
puts $ch {Videoplayer_pickfile browse}
puts $ch {videoplayer play}
</script>

<script>
package require DB
set devices [DB_read]
set devices [DB_get_list $devices device]
set count 0
foreach d $devices {
	set sn [DB_get_list $d sn]
	set pn [DB_get_list $d pn]
	set c [DB_get_list $d c]
	if {[regexp {A3038} $pn]} {
		LWDAQ_print $t "$sn $pn \"[lindex $c 0]\""
		incr count
	}
}
LWDAQ_print $t "Found $count matching devices."
</script>

<script>
# Spectrometer Observing Simulation 
# (C) 2019 Kevan Hashemi, Brandeis University
# (C) 2023 Kevan Hashemi, Open Source Instruments Inc.
#
# This is a LWDAQ Toolmaker Script, written in TclTk. Open the LWDAQ Toolmaker
# and load the script with the Load button.
#

set height 500
set width 1000
set pointsize 2
set fiber_spacing 50
set fiber_range 30
set num_objects 2000
set num_search 20
set objects [list]
set fraction 0
set random 0

set ff [frame $f.buttons]
pack $ff -side top -fill x

button $ff.new -text "New Objects" -command new_objects
button $ff.observe -text "Observe" -command observe
button $ff.search -text "Search" -command search
button $ff.stop -text "Stop" -command stop
checkbutton $ff.rand -variable random -text "Random"
label $ff.lfrac -text "Observed Fraction:" 
label $ff.frac -textvariable fraction
pack $ff.new $ff.observe $ff.search $ff.rand $ff.lfrac $ff.frac -side left -expand yes

set ff [frame $f.parameters]
pack $ff -side top -fill x

foreach a {fiber_spacing fiber_range num_objects num_search} {
	label $ff.l$a -text $a
	entry $ff.e$a -textvariable $a -width 6
	pack $ff.l$a $ff.e$a -side left -expand yes
}

set map [canvas $f.map -height $height -width $width -bd 2 -relief sunken]
pack $map -side top 

proc show {num} {
	global objects t
	LWDAQ_print $t "No$num [lindex $objects $num]"
}

proc observe {{offset_x ""} {offset_y ""}} {
	global map objects fiber_spacing fiber_range height width pointsize t fraction
	
	set count_before 0
	foreach object $objects {
		if {[lindex $object 2] == "observed"} {incr count_before}
	}
	
	if {$offset_x == ""} {
		set offset_x [expr round($fiber_spacing*rand())]
	}
	if {$offset_y == ""} {
		set offset_y [expr round($fiber_spacing*rand())]
	}
	$map delete "fiber"
	
	for {set center_y $offset_y} {$center_y < $height} {incr center_y $fiber_spacing} {
		for {set center_x $offset_x} {$center_x < $width} {incr center_x $fiber_spacing} {
			for {set num 0} {$num < [llength $objects]} {incr num} {
				scan [lindex $objects $num] %d%d%s x y state
				if {$state == "unobserved"} {
					if {(abs($x-$center_x)<$fiber_range/2) \
						&& (abs($y-$center_y)<$fiber_range/2)} {
						lset objects $num 2 "observed"
						set tag "num$num"
						$map delete $tag
						set point [$map create rectangle \
							[expr $x-$pointsize] [expr $y-$pointsize] \
							[expr $x+$pointsize] [expr $y+$pointsize] \
							-fill red -outline red -tag "object observed $tag"]
						$map bind $tag <Button> "show $num"
						break
					}
				}
			}
			set point [$map create rectangle \
				[expr $center_x-$fiber_range/2] [expr $center_y-$fiber_range/2] \
				[expr $center_x+$fiber_range/2] [expr $center_y+$fiber_range/2] \
				-outline green -tag "fiber"]
		}
	} 
	
	set count_after 0
	foreach object $objects {
		if {[lindex $object 2] == "observed"} {incr count_after}
	}
	
	set fraction "[format %.3f [expr 1.0*$count_after/[llength $objects]]]"
}

proc stop {} {
	global abort_search
	set abort_search 1
}

proc search {} {
	global fraction t num_search fiber_range fiber_spacing random abort_search
	set abort_search 0
	LWDAQ_print $t "\nSearch Program, $num_search Observations,\
		Pitch $fiber_spacing, Range $fiber_range" purple
	new_objects
	set offset_x 0
	set offset_y 0
	LWDAQ_print $t "0 $fraction"
	for {set i 1} {$i <= $num_search} {incr i} {
		set offset_x [expr $offset_x + $fiber_range/2]
		if {$offset_x > $fiber_spacing} {
			set offset_x 0
			set offset_y [expr $offset_y + $fiber_range/2]
			if {$offset_y > $fiber_spacing} {
				set offset_y 0
			}
		}
		if {$random} {
			observe
		} else {
			observe $offset_x $offset_y
		}
		LWDAQ_print $t "$i $fraction"
		LWDAQ_update
		if {$abort_search} {break}
	}
}

proc new_objects {} {
	global map objects height width pointsize num_objects fraction
	
	$map delete object
	$map delete "fiber"
	set objects [list]
	set fraction 0.000

	for {set num 0} {$num < $num_objects} {incr num} {
		set x [expr round($width*rand())]
		set y [expr round($height*rand())]
		lappend objects "$x $y unobserved"
		set tag "num$num"
		set point [$map create rectangle [expr $x-$pointsize] [expr $y-$pointsize] \
			[expr $x+$pointsize] [expr $y+$pointsize] \
			-fill black -outline black -tag "object unobserved $tag"]
		$map bind $tag <Button> "show $num"
	}	
}

new_objects

LWDAQ_print $t "Spectrometer Observing Simulation" purple
LWDAQ_print $t "Field Width $width"
LWDAQ_print $t "Field Height $height"
</script>

<script>
# Spectrometer Observing Simulation 
# (C) 2019 Kevan Hashemi, Brandeis University
# (C) 2023 Kevan Hashemi, Open Source Instruments Inc.
#
# This is a LWDAQ Toolmaker Script, written in TclTk. Open the LWDAQ Toolmaker
# and load the script with the Load button.
#

set height 500
set width 1000
set pointsize 2
set fiber_spacing 50
set fiber_range 30
set num_objects 2000
set num_search 20
set objects [list]
set fraction 0
set random 0

set ff [frame $f.buttons]
pack $ff -side top -fill x

button $ff.new -text "New Objects" -command new_objects
button $ff.observe -text "Observe" -command observe
button $ff.search -text "Search" -command search
button $ff.stop -text "Stop" -command stop
checkbutton $ff.rand -variable random -text "Random"
label $ff.lfrac -text "Observed Fraction:" 
label $ff.frac -textvariable fraction
pack $ff.new $ff.observe $ff.search $ff.rand $ff.lfrac $ff.frac -side left -expand yes

set ff [frame $f.parameters]
pack $ff -side top -fill x

foreach a {fiber_spacing fiber_range num_objects num_search} {
	label $ff.l$a -text $a
	entry $ff.e$a -textvariable $a -width 6
	pack $ff.l$a $ff.e$a -side left -expand yes
}

set map [canvas $f.map -height $height -width $width -bd 2 -relief sunken -bg white]
pack $map -side top 

proc show {num} {
	global objects t
	LWDAQ_print $t "No$num [lindex $objects $num]"
}

proc observe {{offset_x ""} {offset_y ""}} {
	global map objects fiber_spacing fiber_range height width pointsize t fraction
	
	set count_before 0
	foreach object $objects {
		if {[lindex $object 2] == "observed"} {incr count_before}
	}
	
	if {$offset_x == ""} {
		set offset_x [expr round($fiber_spacing*rand())]
	}
	if {$offset_y == ""} {
		set offset_y [expr round($fiber_spacing*rand())]
	}
	$map delete "fiber"
	
	for {set center_y $offset_y} {$center_y < $height} {incr center_y $fiber_spacing} {
		for {set center_x $offset_x} {$center_x < $width} {incr center_x $fiber_spacing} {
			for {set num 0} {$num < [llength $objects]} {incr num} {
				scan [lindex $objects $num] %d%d%s x y state
				if {$state == "unobserved"} {
					if {(abs($x-$center_x)<$fiber_range/2) \
						&& (abs($y-$center_y)<$fiber_range/2)} {
						lset objects $num 2 "observed"
						set tag "num$num"
						$map delete $tag
						set point [$map create rectangle \
							[expr $x-$pointsize] [expr $y-$pointsize] \
							[expr $x+$pointsize] [expr $y+$pointsize] \
							-fill red -outline red -tag "object observed $tag"]
						$map bind $tag <Button> "show $num"
						break
					}
				}
			}
			set point [$map create rectangle \
				[expr $center_x-$fiber_range/2] [expr $center_y-$fiber_range/2] \
				[expr $center_x+$fiber_range/2] [expr $center_y+$fiber_range/2] \
				-outline green -tag "fiber"]
		}
	} 
	
	set count_after 0
	foreach object $objects {
		if {[lindex $object 2] == "observed"} {incr count_after}
	}
	
	set fraction "[format %.3f [expr 1.0*$count_after/[llength $objects]]]"
}

proc stop {} {
	global abort_search
	set abort_search 1
}

proc search {} {
	global fraction t num_search fiber_range fiber_spacing random abort_search
	set abort_search 0
	LWDAQ_print $t "\nSearch Program, $num_search Observations,\
		Pitch $fiber_spacing, Range $fiber_range" purple
	new_objects
	set offset_x 0
	set offset_y 0
	LWDAQ_print $t "0 $fraction"
	for {set i 1} {$i <= $num_search} {incr i} {
		set offset_x [expr $offset_x + $fiber_range/2]
		if {$offset_x > $fiber_spacing} {
			set offset_x 0
			set offset_y [expr $offset_y + $fiber_range/2]
			if {$offset_y > $fiber_spacing} {
				set offset_y 0
			}
		}
		if {$random} {
			observe
		} else {
			observe $offset_x $offset_y
		}
		LWDAQ_print $t "$i $fraction"
		LWDAQ_update
		if {$abort_search} {break}
	}
}

proc new_objects {} {
	global map objects height width pointsize num_objects fraction
	
	$map delete object
	$map delete "fiber"
	set objects [list]
	set fraction 0.000

	for {set num 0} {$num < $num_objects} {incr num} {
		set x [expr round($width*rand())]
		set y [expr round($height*rand())]
		lappend objects "$x $y unobserved"
		set tag "num$num"
		set point [$map create rectangle [expr $x-$pointsize] [expr $y-$pointsize] \
			[expr $x+$pointsize] [expr $y+$pointsize] \
			-fill black -outline black -tag "object unobserved $tag"]
		$map bind $tag <Button> "show $num"
	}	
}

new_objects

LWDAQ_print $t "Spectrometer Observing Simulation" purple
LWDAQ_print $t "Field Width $width"
LWDAQ_print $t "Field Height $height"
</script>

