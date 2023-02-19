<script>
# Get the duration, number of frames, and number of packets for each of a list of
# videos, and totals.
set fnl [lsort -increasing [LWDAQ_get_file_name 1]]
set total_duration 0
set total_frames 0
set total_packets 0
LWDAQ_print $t "File Duration Frames Packets" purple
foreach fn $fnl {
	catch {[exec /usr/local/bin/ffmpeg -i $fn]} answer
	if {[regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	} else {
		set duration 0
	}
	set total_duration [expr $total_duration + $duration]
	
	catch {[exec ~/Active/Videoarchiver/MacOS/ffmpeg -i $fn -c copy -f null -]} result
	regexp {frame= *([0-9]+)} $result match numf
	set total_frames [expr $total_frames + $numf]
	
	set nump [exec /usr/local/bin/ffprobe -v error -select_streams v:0 \
		-count_packets -show_entries stream=nb_read_packets -of csv=p=0 $fn]
	LWDAQ_print $t "[file tail $fn] $duration $numf $nump"
	set total_packets [expr $total_packets + $nump]
	
	LWDAQ_support
}
LWDAQ_print $t "Total: [format %.2f $total_duration] $total_frames $total_packets" purple
regexp {V[0-9]+} [lindex $fnl 0] match st
regexp {V[0-9]+} [lindex $fnl end] match et
LWDAQ_print $t "File Time Differenc: [expr $et - $st]" green
</script>

<script>
# Get the duration, number of frames, and number of packets for each of a list of
# videos, and totals.
set fnl [lsort -increasing [LWDAQ_get_file_name 1]]
set total_duration 0
set total_frames 0
set total_packets 0
LWDAQ_print $t "File Duration Frames Packets" purple
foreach fn $fnl {
	catch {[exec /usr/local/bin/ffmpeg -i $fn]} answer
	if {[regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	} else {
		set duration 0
	}
	set total_duration [expr $total_duration + $duration]
	
	catch {[exec ~/Active/Videoarchiver/MacOS/ffmpeg -i $fn -c copy -f null -]} result
	regexp {frame= *([0-9]+)} $result match numf
	set total_frames [expr $total_frames + $numf]
	
	set nump [exec /usr/local/bin/ffprobe -v error -select_streams v:0 \
		-count_packets -show_entries stream=nb_read_packets -of csv=p=0 $fn]
	LWDAQ_print $t "[file tail $fn] $duration $numf $nump"
	set total_packets [expr $total_packets + $nump]
	
	LWDAQ_support
}
LWDAQ_print $t "Total: [format %.2f $total_duration] $total_frames $total_packets" purple
regexp {V[0-9]+} [file tail [lindex $fnl 0]] match st
regexp {V[0-9]+} [file tail [lindex $fnl end]] match et
LWDAQ_print $t "File Time Differenc: [expr $et - $st]" green
</script>

<script>
# Get the duration, number of frames, and number of packets for each of a list of
# videos, and totals.
set fnl [lsort -increasing [LWDAQ_get_file_name 1]]
set total_duration 0
set total_frames 0
set total_packets 0
LWDAQ_print $t "File Duration Frames Packets" purple
foreach fn $fnl {
	catch {[exec /usr/local/bin/ffmpeg -i $fn]} answer
	if {[regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	} else {
		set duration 0
	}
	set total_duration [expr $total_duration + $duration]
	
	catch {[exec ~/Active/Videoarchiver/MacOS/ffmpeg -i $fn -c copy -f null -]} result
	regexp {frame= *([0-9]+)} $result match numf
	set total_frames [expr $total_frames + $numf]
	
	set nump [exec /usr/local/bin/ffprobe -v error -select_streams v:0 \
		-count_packets -show_entries stream=nb_read_packets -of csv=p=0 $fn]
	LWDAQ_print $t "[file tail $fn] $duration $numf $nump"
	set total_packets [expr $total_packets + $nump]
	
	LWDAQ_support
}
LWDAQ_print $t "Total: [format %.2f $total_duration] $total_frames $total_packets" purple
regexp {V([0-9]+)} [file tail [lindex $fnl 0]] match st
regexp {V([0-9]+)} [file tail [lindex $fnl end]] match et
LWDAQ_print $t "File Time Differenc: [expr $et - $st]" green
</script>

<script>
# Get the duration, number of frames, and number of packets for each of a list of
# videos, and totals.
set fnl [lsort -increasing [LWDAQ_get_file_name 1]]
set total_duration 0
set total_frames 0
set total_packets 0
LWDAQ_print $t "File Duration Frames Packets" purple
foreach fn $fnl {
	catch {[exec /usr/local/bin/ffmpeg -i $fn]} answer
	if {[regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	} else {
		set duration 0
	}
	set total_duration [expr $total_duration + $duration]
	
	catch {[exec ~/Active/Videoarchiver/MacOS/ffmpeg -i $fn -c copy -f null -]} result
	regexp {frame= *([0-9]+)} $result match numf
	set total_frames [expr $total_frames + $numf]
	
	set nump [exec /usr/local/bin/ffprobe -v error -select_streams v:0 \
		-count_packets -show_entries stream=nb_read_packets -of csv=p=0 $fn]
	LWDAQ_print $t "[file tail $fn] $duration $numf $nump"
	set total_packets [expr $total_packets + $nump]
	
	LWDAQ_support
}
LWDAQ_print $t "Total: [format %.2f $total_duration] $total_frames $total_packets" purple
regexp {V([0-9]+)} [file tail [lindex $fnl 0]] match st
regexp {V([0-9]+)} [file tail [lindex $fnl end]] match et
LWDAQ_print $t "File Time Differenc: [expr $et - $st]" green
LWDAQ_print $t "Next File Should Be: [expr $st + $total_duration]" green
</script>

<script>
# Get the duration, number of frames, and number of packets for each of a list of
# videos, and totals.
set fnl [lsort -increasing [LWDAQ_get_file_name 1]]
set total_duration 0
set total_frames 0
set total_packets 0
LWDAQ_print $t "File Duration Frames Packets" purple
foreach fn $fnl {
	catch {[exec /usr/local/bin/ffmpeg -i $fn]} answer
	if {[regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	} else {
		set duration 0
	}
	set total_duration [expr $total_duration + $duration]
	
	catch {[exec ~/Active/Videoarchiver/MacOS/ffmpeg -i $fn -c copy -f null -]} result
	regexp {frame= *([0-9]+)} $result match numf
	set total_frames [expr $total_frames + $numf]
	
	set nump [exec /usr/local/bin/ffprobe -v error -select_streams v:0 \
		-count_packets -show_entries stream=nb_read_packets -of csv=p=0 $fn]
	LWDAQ_print $t "[file tail $fn] $duration $numf $nump"
	set total_packets [expr $total_packets + $nump]
	
	LWDAQ_support
}
LWDAQ_print $t "Total: [format %.2f $total_duration] $total_frames $total_packets" purple
regexp {V([0-9]+)} [file tail [lindex $fnl 0]] match st
regexp {V([0-9]+)} [file tail [lindex $fnl end]] match et
LWDAQ_print $t "File Time Differenc: [expr $et - $st]" green
LWDAQ_print $t "Next File Should Be: V[expr $st + round($total_duration)].mp4" green
</script>

