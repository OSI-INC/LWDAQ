<script>
set fnl [LWDAQ_get_file_name 1]
foreach fn $fnl {
	if {[regexp {[0-9]{10}} [file tail $fn] match
LWDAQ_print $t $match
#	ffmpeg -i $fn -c:v libx264 -preset veryfast V$match\.mp4
}
</script>

<script>
set fnl [LWDAQ_get_file_name 1]
foreach fn $fnl {
	if {[regexp {[0-9]{10}} [file tail $fn] match]} {
LWDAQ_print $t $match
#	ffmpeg -i $fn -c:v libx264 -preset veryfast V$match\.mp4
	}
}
</script>

<script>
set fnl [LWDAQ_get_file_name 1]
foreach fn $fnl {
	if {[regexp {[0-9]{10}} [file tail $fn] match]} {
		set ofn V$match\.mp4
		LWDAQ_print $t "$fn -> $ofn"
		exec /usr/local/bin/ffmpeg -i $fn -c:v libx264 -preset veryfast 
	}
}
</script>

<script>
set fnl [LWDAQ_get_file_name 1]
foreach fn $fnl {
	if {[regexp {[0-9]{10}} [file tail $fn] match]} {
		set ofn V$match\.mp4
		cd [file dirname $fn]
		LWDAQ_print $t "$fn -> $ofn"
		exec /usr/local/bin/ffmpeg -i $fn -c:v libx264 -preset veryfast $ofn
	}
}
</script>

<script>
set fnl [LWDAQ_get_file_name 1]
foreach fn $fnl {
	if {[regexp {[0-9]{10}} [file tail $fn] match]} {
		set ofn V$match\.mp4
		cd [file dirname $fn]
		LWDAQ_print $t "$fn -> $ofn"
		exec /usr/local/bin/ffmpeg -i $fn -c:v libx264 -preset veryfast $ofn
	}
}
</script>

<script>
set fnl [LWDAQ_get_file_name 1]
foreach fn $fnl {
	if {[regexp {[0-9]{10}} [file tail $fn] match]} {
		set ofn V$match\.mp4
		cd [file dirname $fn]
		LWDAQ_print $t "$fn -> $ofn"
		LWDAQ_print "/usr/local/bin/ffmpeg -i $fn -c:v libx264 -preset veryfast $ofn"
		if {[catch {exec /usr/local/bin/ffmpeg -i $fn -c:v libx264 -preset veryfast $ofn &} error_report]} {
			LWDAQ_print $t "ERROR: $error_report"
		}
	}
}
</script>

<script>
set fnl [LWDAQ_get_file_name 1]
foreach fn $fnl {
	if {[regexp {[0-9]{10}} [file tail $fn] match]} {
		set ofn V$match\.mp4
		cd [file dirname $fn]
		LWDAQ_print $t "$fn -> $ofn"
		LWDAQ_print "/usr/local/bin/ffmpeg -i $fn -c:v libx264 -preset veryfast $ofn."
		if {[catch {exec /usr/local/bin/ffmpeg -i $fn -c:v libx264 -preset veryfast $ofn &} error_report]} {
			LWDAQ_print $t "ERROR: $error_report"
		}
	}
}
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [split [read $f] \n]
close $f

foreach {sa sn} {MA "Massachusetts" FL "Florida" GA "Georgia" \
	MN "Minnesota" NY "New York" CA "California" \
	SD "South Dakota" TX "Texas"} {
	set $sa [list]
	foreach line $contents {
		set line [split $line ","]
		if {[lindex $line 1] == $sn} {
			lappend $sa [lindex $line 5]
		}
	}
}

for {set i 0} {$i <  [llength [set MA]]} {incr i} {
	foreach sa {MA FL GA MN NY SD CA TX} {
		LWDAQ_print -nonewline $t "[lindex [set $sa] $i] "
	}
	LWDAQ_print $t
}
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [split [read $f] \n]
close $f

foreach {sa sn} {MA "Massachusetts" FL "Florida" GA "Georgia" \
	MN "Minnesota" NY "New York" CA "California" \
	SD "South Dakota" TX "Texas"} {
	set $sa [list]
	foreach line $contents {
		set line [split $line ","]
		if {[lindex $line 1] == $sn} {
			lappend $sa [lindex $line 5]
		}
	}
}

for {set i 0} {$i <  [llength [set MA]]} {incr i} {
	foreach sa {MA FL GA MN NY SD CA TX} {
		LWDAQ_print -nonewline $t "[lindex [set $sa] $i] "
	}
	LWDAQ_print $t
}
</script>

