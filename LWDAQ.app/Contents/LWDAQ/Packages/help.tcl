



	global LWDAQ_Info
	if {$pattern == ""} {
		puts "Try LWDAQ_list_commands to get a list of LWDAQ commands."
		puts "Try \"help\" or \"man\" followed by a procedure name containing wild cards."
		puts "Try the LWDAQ Manual (web address is in the About dialog box)."
		puts "Try typing a routine name to get a list of parameters it requires."
		return
	}
	foreach f $LWDAQ_Info(scripts) {
		set names [LWDAQ_proc_list $pattern $f]
		if {[llength $names] > 0} {
			puts ""
			puts "From [file tail $f]: "
			puts ""
			foreach n $names {
				puts [LWDAQ_proc_description $n $f 1]
				puts ""
				if {$option == "definition"} {
					puts [LWDAQ_proc_definition $n $f]
					puts ""
				}
			}
		}
	}
	return ""
}