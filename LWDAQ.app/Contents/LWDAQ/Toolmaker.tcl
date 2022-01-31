<script>

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

