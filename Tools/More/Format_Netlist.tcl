# Format Traxmaker Netlist and Create Updated Drill File. [13-MAR-19]

# Get the file name of the netlist created by Traxmaker. Read its contents.
set fn [LWDAQ_get_file_name]
if {$fn == ""} {exit}
set f [open $fn]
set contents [read $f]
close $f

# Replace all carriage returns with spaces, then insert carriage
# returns before parentheses and brackets.
set contents [regsub -all {\n} $contents " "]
set contents [regsub -all {\[} $contents "\n\["]
set contents [regsub -all {\(} $contents "\n\("]

# Write the new netlist to disk, but don't overwrite the old netlist.
set nfn [file root $fn]_Compact[file extension $fn]
set f [open $nfn w]
puts $f $contents
close $f

# Try to find the tool list and drill file.
set tfn [file root $fn].TOL
set dfn [file root $fn].TXT
if {[file exists $tfn] && [file exists $tfn]} {
	set f [open $dfn r]
	set drill [read $f]
	close $f
	set drill [regsub {M48.*?%} $drill ""]
	set f [open $tfn r]
	set tool [read $f]
	close $f
	set tool [regsub {\-.*-\n} $tool ""]
	set newdrill "M48\nINCH\n"
	foreach {tn dia} $tool {
		append newdrill "[set tn]C00.[format %03d $dia]\n"
	}
	append newdrill "%\n"
	append newdrill [string trim $drill]
	set f [open $dfn w]
	puts $f $newdrill
	close $f
} {
	puts "Cannot find TOL or TXT files."
}
