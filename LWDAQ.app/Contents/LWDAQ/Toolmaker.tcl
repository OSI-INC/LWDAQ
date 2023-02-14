<script>

</script>

<script>
# Try all ffmpeg presets on a mjpeg video to compare speed and size.
set dn [LWDAQ_get_dir_name]
cd $dn
set fn [file join $dn SEG2018-113-09-01-30.mjpg]
foreach s {ultrafast superfast veryfast fast medium slow slower veryslow} {
	set ofn [regsub {\.mjpg} $fn "_$s\.mp4"]
	set tstart [clock milliseconds]
	exec /usr/local/bin/ffmpeg -nostdin -i $fn -c:v libx264 -preset $s $ofn >& log.txt
	LWDAQ_print $t "$s [format %.0f [expr 0.001*[file size $ofn]]]\
		[expr [clock milliseconds] - $tstart]"
	LWDAQ_update	
	if {![winfo exists $t]} {break}
}
</script>

<script>
set extension "mpg"
set dn [LWDAQ_get_dir_name]
LWDAQ_print $t "Looking for $extension files in $dn"
set fnl [LWDAQ_find_files $dn "*.$extension"]
foreach fn $fnl {
	set ofn [file root $fn].mp4
	LWDAQ_print $t "Translating $fn bytes..."
	LWDAQ_update
	exec /usr/local/bin/ffmpeg -nostdin -i $fn -c:v libx264 -preset veryfast $ofn >& ~/Desktop/log.txt
	set ratio [expr 100.0*[file size $ofn]/[file size $fn]]
	LWDAQ_print $t "Output [file tail $ofn] size [format %.1f $ratio]% size of original."
	if {$ratio > 100.0} {
		LWDAQ_print $t "WARNING: Original file [file tail $fn] smaller."
	} else {
		LWDAQ_print $t "Moving original [file tail $fn] to desktop."
		file rename $fn ~/Desktop/[file tail $fn]
	}
	if {![winfo exists $t]} {break}
	LWDAQ_update
}
</script>

<script>
# Get the number of frames in a video.
set fnl [lsort -increasing [LWDAQ_get_file_name 1]]
foreach fn $fnl {
	catch {exec /usr/local/bin/ffmpeg -i $fn -c copy -f null -} result
	regexp {frame= *([0-9]+)} $result match numf
	LWDAQ_print $t "$fn $numf"
}
</script>

<script>
# Saved menubutton code.
		menubutton $ff.verm -text "Ver" -menu $ff.verm.menu
		pack $ff.verm -side left -expand 1
		set m [menu $ff.verm.menu]
		foreach version $config(versions) {
			$m add radio -label [lindex $version 0] -value [lindex $version 0] \
				-variable Videoarchiver_info(cam$n\_ver)
		}	

		menubutton $ff.rotm -text "Rot" -menu $ff.rotm.menu
		pack $ff.rotm -side left -expand 1
		set m [menu $ff.rotm.menu]
		foreach rotation $info(rotation_options) {
			$m add radio -label "$rotation" -value "$rotation" \
				-variable Videoarchiver_info(cam$n\_rot)
		}	

		menubutton $ff.ecm -text "Comp" -menu $ff.ecm.menu
		pack $ff.ecm -side left -expand 1
		set m [menu $ff.ecm.menu]
		for {set ec -10} {$ec <= +10} {incr ec} {
			$m add radio -label " $ec" -value "$ec" \
				-variable Videoarchiver_info(cam$n\_ec)
		}
</script>

<script>
# Open sockets to a bunch of cameras running the ACC interface 
# server and measure the time it takes to get the segment list.
while {[winfo exists $t]} {
	set result ""

	foreach ip {205 206 207 208 209 210 211 212 213 214} {
		# Start a timer and open the socket.
		set time [clock milliseconds]
		set sock [LWDAQ_socket_open 10.0.0.205:2223 basic]
	
		# Request the segment list.
		LWDAQ_socket_write $sock "glob -nocomplain tmp/V*.mp4\n"
		set seg_list [LWDAQ_socket_read $sock line]
		set seg_list [regsub -all {tmp/} $seg_list ""]
	
		# Close the socket.
		LWDAQ_socket_close $sock
		append result "[expr [clock milliseconds] - $time] "
	}

	# Update the GUI.
	LWDAQ_print $t $result

}
</script>

<script>
# Look through a file containing a list of one-second segments, obtained either
# from the ffmpeg segment routine or a directory listing, and find missing,
# duplicate and unexpected entries.
set f [open ~/Desktop/seglist.txt]
set fnl [string trim [read $f]]
close $f 
regexp {S([0-9]{10})\.mp4} [lindex $fnl 0] match segtime
set segtime [expr $segtime -1]
set missing 0
set duplicate 0
set unexpected 0
foreach fn $fnl {
	regexp {S([0-9]{10})\.mp4} $fn match st
	if {$st == $segtime + 2} {
		LWDAQ_print $t "Missing S[expr $segtime + 1]\.mp4"
		incr missing
	} elseif {$st == $segtime} {
		LWDAQ_print $t "Duplicate $fn"
		incr duplicate
	} elseif {$st != $segtime + 1} {
		LWDAQ_print $t "Unexpected $fn"
		incr unexpected
	}
	set segtime $st
}
LWDAQ_print $t "Missing $missing"
LWDAQ_print $t "Duplicates $duplicate"
LWDAQ_print $t "Unexpected $unexpected"
</script>

<script>
# Download video segments from a camera using the TCL interface and save to disk.
set sock [LWDAQ_socket_open 10.0.0.34:2223 basic]
LWDAQ_socket_write $sock "glob -nocomplain test/S*.mp4\n"
set seg_list [LWDAQ_socket_read $sock line]
set seg_list [regsub -all {test/} $seg_list ""]
LWDAQ_print $t "Found [llength $seg_list] segments."
foreach sf $seg_list {
		LWDAQ_print $t "Fetching $sf and writing to disk."
		LWDAQ_socket_write $sock "getfile test/$sf\n"
		set size [LWDAQ_socket_read $sock line]
		if {[LWDAQ_is_error_result $size]} {error $size}
		set contents [LWDAQ_socket_read $sock $size]
		set f [open ~/Desktop/test/$sf w]
		fconfigure $f -translation binary
		puts $f $contents
		close $f
}
LWDAQ_socket_close $sock
</script>

<script>
# Monitor the temperature and clock frequency of the Pi microprocessor.
while {1} {
	set a [exec /usr/bin/vcgencmd measure_clock arm]
	regexp {=([0-9]*)} $a match frequency
	set frequency [expr $frequency/1e6]
	set b [exec /usr/bin/vcgencmd measure_temp]
	regexp {=([0-9\.]*)} $b match temperature
	puts "[clock seconds] \
	[format %.1f $frequency]\
	[format %.1f $temperature]"
	after 3000
}
</script>

<script>
# Get the number of frames in a video.
set fnl [lsort -increasing [LWDAQ_get_file_name 1]]
foreach fn $fnl {
	catch {exec /usr/local/bin/ffmpeg -i $fn -c copy -f null -} result
	regexp {frame= *([0-9]+)} $result match numf
	LWDAQ_print $t "$fn $numf"
}
</script>

<script>
# Get the number of frames in a video.
set fnl [lsort -increasing [LWDAQ_get_file_name 1]]
foreach fn $fnl {
	catch {exec /usr/local/bin/ffmpeg -i $fn -c copy -f null -} result
	LWDAQ_print $t $result
	regexp {frame= *([0-9]+)} $result match numf
	LWDAQ_print $t "$fn $numf"
}
</script>

<script>
# Get the number of frames in a video.
set fnl [lsort -increasing [LWDAQ_get_file_name 1]]
foreach fn $fnl {
	set result [exec /usr/local/bin/ffmpeg -i $fn -c copy -f null -]
	LWDAQ_print $t $result
	regexp {frame= *([0-9]+)} $result match numf
	LWDAQ_print $t "$fn $numf"
}
</script>

<script>
# Get the number of frames in a video.
set fnl [lsort -increasing [LWDAQ_get_file_name 1]]
foreach fn $fnl {
	set result [exec /usr/local/bin/ffprobe $fn]
	LWDAQ_print $t $result
	regexp {frame= *([0-9]+)} $result match numf
	LWDAQ_print $t "$fn $numf"
}
</script>

