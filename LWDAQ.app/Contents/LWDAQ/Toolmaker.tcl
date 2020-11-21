<script>
button $f.getfile -text "Select Source Code" -command "Get_File"
button $f.assemble -text "Assemble" -command "Assemble"
pack $f.getfile $f.assemble -side left

proc Get_File {} {
	global t fn
	set fn [LWDAQ_get_file_name]
	LWDAQ_print $t "Source Code: $fn"
}

proc Assemble {} {
	global t fn
	
	cd [file dirname $fn]

	LWDAQ_print $t "Assembling [file tail $fn]."
	if {[catch {
		set result [exec /usr/local/bin/z80asm -i $fn -o output.o]
	} error_result]} {
		LWDAQ_print $t "ERROR: $error_result"
		return 
	}
	if {$result == ""} {
		LWDAQ_print $t "Assembly completed without error."
	} else {
		LWDAQ_print $t $result
	}

	LWDAQ_print $t "Reading object file."
	set f [open output.o r]
	fconfigure $f -translation binary
	set contents [read $f]
	close $f

	LWDAQ_print $t "Converting object code to hex file."
	binary scan $contents H* result
	set result [split $result ""]
	set output ""
	foreach {hi lo} $result {
		append output "$hi$lo\n"
	}
	set output [string trim $output]

	set hfn [file root $fn].mem
	LWDAQ_print $t "Writing [llength $output] hex bytes to [file tail $hfn]."
	set f [open $hfn w]
	puts -nonewline $f $output
	close $f

	LWDAQ_print $t "Deleting object file."
	file delete output.o
}
</script>

