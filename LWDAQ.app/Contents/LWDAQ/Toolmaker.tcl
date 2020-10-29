<script>
set tw [text .text -relief sunken -border 2 -setgrid 1 -height 10 -width 50 -wrap word]
$tw configure -yscrollcommand ".vsb set"
set vsb [scrollbar .vsb -orient vertical -command "$tw yview"]
pack $vsb -side right -fill y
$tw configure -xscrollcommand ".hsb set"
set hsb [scrollbar .hsb -orient horizontal -command "$tw xview"]
pack $hsb -side bottom -fill x
$tw configure -wrap none
pack $tw -expand yes -fill both
</script>

<script>
catch {destroy .quit}
catch {destroy .text}
text .text -relief sunken -border 2 -setgrid 1 -height 10 -width 50 -wrap none
.text configure -yscrollcommand ".vsb set"
scrollbar .vsb -orient vertical -command ".text yview"
pack .vsb -side right -fill y
.text configure -xscrollcommand ".hsb set"
scrollbar .hsb -orient horizontal -command ".text xview"
pack .hsb -side bottom -fill x
pack .text -expand yes -fill both
</script>

<script>
catch {destroy .f}
frame .f
pack .f -side top -fill x
text f.text -relief sunken -border 2 -setgrid 1 -height 10 -width 50 -wrap none
f.text configure -yscrollcommand "f.vsb set"
scrollbar f.vsb -orient vertical -command "f.text yview"
pack f.vsb -side right -fill y
f.text configure -xscrollcommand "f.hsb set"
scrollbar f.hsb -orient horizontal -command "f.text xview"
pack f.hsb -side bottom -fill x
pack f.text -expand yes -fill both
</script>

<script>
catch {destroy .f}
frame .f
pack .f -side top -fill x
text .f.text -relief sunken -border 2 -setgrid 1 -height 10 -width 50 -wrap none
.f.text configure -yscrollcommand ".f.vsb set"
scrollbar .f.vsb -orient vertical -command ".f.text yview"
pack .f.vsb -side right -fill y
.f.text configure -xscrollcommand ".f.hsb set"
scrollbar .f.hsb -orient horizontal -command ".f.text xview"
pack .f.hsb -side bottom -fill x
pack .f.text -expand yes -fill both
</script>

<script>
catch {destroy .f}
frame .f
pack .f -side top -fill x
text .f.text -relief sunken -border 2 -setgrid 1 -height 10 -width 50 -wrap none
.f.text configure -yscrollcommand ".f.vsb set"
scrollbar .f.vsb -orient vertical -command ".f.text yview"
pack .f.vsb -side right -fill y
.f.text configure -xscrollcommand ".f.hsb set"
scrollbar .f.hsb -orient horizontal -command ".f.text xview"
pack .f.hsb -side bottom -fill x
pack .f.text -expand yes -fill both
for {set i 0} {$i <20} {incr i} {
  .f.text insert "$i\: This window should have vertical and horizontal scroll bars."
}
</script>

<script>
catch {destroy .f}
frame .f
pack .f -side top -fill x
text .f.text -relief sunken -border 2 -setgrid 1 -height 10 -width 50 -wrap none
.f.text configure -yscrollcommand ".f.vsb set"
scrollbar .f.vsb -orient vertical -command ".f.text yview"
pack .f.vsb -side right -fill y
.f.text configure -xscrollcommand ".f.hsb set"
scrollbar .f.hsb -orient horizontal -command ".f.text xview"
pack .f.hsb -side bottom -fill x
pack .f.text -expand yes -fill both
for {set i 0} {$i <20} {incr i} {
  .f.text insert "$i\: This window should have vertical and horizontal scroll bars." end
}
</script>

<script>
catch {destroy .f}
frame .f
pack .f -side top -fill x
text .f.text -relief sunken -border 2 -setgrid 1 -height 10 -width 50 -wrap none
.f.text configure -yscrollcommand ".f.vsb set"
scrollbar .f.vsb -orient vertical -command ".f.text yview"
pack .f.vsb -side right -fill y
.f.text configure -xscrollcommand ".f.hsb set"
scrollbar .f.hsb -orient horizontal -command ".f.text xview"
pack .f.hsb -side bottom -fill x
pack .f.text -expand yes -fill both
for {set i 0} {$i <20} {incr i} {
  .f.text insert end "$i\: This window should have vertical and horizontal scroll bars." end
}
</script>

<script>
catch {destroy .f}
frame .f
pack .f -side top -fill x
text .f.text -relief sunken -border 2 -setgrid 1 -height 10 -width 50 -wrap none
.f.text configure -yscrollcommand ".f.vsb set"
scrollbar .f.vsb -orient vertical -command ".f.text yview"
pack .f.vsb -side right -fill y
.f.text configure -xscrollcommand ".f.hsb set"
scrollbar .f.hsb -orient horizontal -command ".f.text xview"
pack .f.hsb -side bottom -fill x
pack .f.text -expand yes -fill both
for {set i 0} {$i <20} {incr i} {
  .f.text insert end "$i\: This window should have vertical and horizontal scroll barsn" end
}
</script>

<script>
catch {destroy .f}
frame .f
pack .f -side top -fill x
text .f.text -relief sunken -border 2 -setgrid 1 -height 10 -width 50 -wrap none
.f.text configure -yscrollcommand ".f.vsb set"
scrollbar .f.vsb -orient vertical -command ".f.text yview"
pack .f.vsb -side right -fill y
.f.text configure -xscrollcommand ".f.hsb set"
scrollbar .f.hsb -orient horizontal -command ".f.text xview"
pack .f.hsb -side bottom -fill x
pack .f.text -expand yes -fill both
for {set i 0} {$i <20} {incr i} {
  .f.text insert end "$i\: This window should have vertical and horizontal scroll bars.\n" end
}
</script>

<script>
catch {destroy .f}
frame .f
pack .f -side top -fill x -expand yes
text .f.text -relief sunken -border 2 -setgrid 1 -height 10 -width 50 -wrap none
.f.text configure -yscrollcommand ".f.vsb set"
scrollbar .f.vsb -orient vertical -command ".f.text yview"
pack .f.vsb -side right -fill y
.f.text configure -xscrollcommand ".f.hsb set"
scrollbar .f.hsb -orient horizontal -command ".f.text xview"
pack .f.hsb -side bottom -fill x
pack .f.text -expand yes -fill both
for {set i 0} {$i <20} {incr i} {
  .f.text insert end "$i\: This window should have vertical and horizontal scroll bars.\n" end
}
</script>

<script>
catch {destroy .f}
frame .f -expand yes
pack .f -side top -fill x 
text .f.text -relief sunken -border 2 -setgrid 1 -height 10 -width 50 -wrap none
.f.text configure -yscrollcommand ".f.vsb set"
scrollbar .f.vsb -orient vertical -command ".f.text yview"
pack .f.vsb -side right -fill y
.f.text configure -xscrollcommand ".f.hsb set"
scrollbar .f.hsb -orient horizontal -command ".f.text xview"
pack .f.hsb -side bottom -fill x
pack .f.text -expand yes -fill both
for {set i 0} {$i <20} {incr i} {
  .f.text insert end "$i\: This window should have vertical and horizontal scroll bars.\n" end
}
</script>

<script>
catch {destroy .f}
frame .f
pack .f -side top -fill xy
text .f.text -relief sunken -border 2 -setgrid 1 -height 10 -width 50 -wrap none
.f.text configure -yscrollcommand ".f.vsb set"
scrollbar .f.vsb -orient vertical -command ".f.text yview"
pack .f.vsb -side right -fill y
.f.text configure -xscrollcommand ".f.hsb set"
scrollbar .f.hsb -orient horizontal -command ".f.text xview"
pack .f.hsb -side bottom -fill x
pack .f.text -expand yes -fill both
for {set i 0} {$i <20} {incr i} {
  .f.text insert end "$i\: This window should have vertical and horizontal scroll bars.\n" end
}
</script>

<script>
catch {destroy .f}
frame .f
pack .f -side top -fill both
text .f.text -relief sunken -border 2 -setgrid 1 -height 10 -width 50 -wrap none
.f.text configure -yscrollcommand ".f.vsb set"
scrollbar .f.vsb -orient vertical -command ".f.text yview"
pack .f.vsb -side right -fill y
.f.text configure -xscrollcommand ".f.hsb set"
scrollbar .f.hsb -orient horizontal -command ".f.text xview"
pack .f.hsb -side bottom -fill x
pack .f.text -expand yes -fill both
for {set i 0} {$i <20} {incr i} {
  .f.text insert end "$i\: This window should have vertical and horizontal scroll bars.\n" end
}
</script>

<script>
catch {destroy .f .q}
frame .f
pack .f -side top -fill both
text .f.text -relief sunken -border 2 -setgrid 1 -height 10 -width 50 -wrap none
.f.text configure -yscrollcommand ".f.vsb set"
scrollbar .f.vsb -orient vertical -command ".f.text yview"
pack .f.vsb -side right -fill y
.f.text configure -xscrollcommand ".f.hsb set"
scrollbar .f.hsb -orient horizontal -command ".f.text xview"
pack .f.hsb -side bottom -fill x
pack .f.text -expand yes -fill both
for {set i 0} {$i <20} {incr i} {
  .f.text insert end "$i\: This window should have vertical and horizontal scroll bars.\n" end
}
</script>

<script>
catch {destroy .f .quit}
frame .f
pack .f -side top -fill both
text .f.text -relief sunken -border 2 -setgrid 1 -height 10 -width 50 -wrap none
.f.text configure -yscrollcommand ".f.vsb set"
scrollbar .f.vsb -orient vertical -command ".f.text yview"
pack .f.vsb -side right -fill y
.f.text configure -xscrollcommand ".f.hsb set"
scrollbar .f.hsb -orient horizontal -command ".f.text xview"
pack .f.hsb -side bottom -fill x
pack .f.text -expand yes -fill both
for {set i 0} {$i <20} {incr i} {
  .f.text insert end "$i\: This window should have vertical and horizontal scroll bars.\n" end
}
</script>

<script>
catch {destroy .f}
frame .f
pack .f -side top -fill both
text .f.text -relief sunken -border 2 -setgrid 1 -height 10 -width 20 -wrap none
.f.text configure -yscrollcommand ".f.vsb set"
scrollbar .f.vsb -orient vertical -command ".f.text yview"
pack .f.vsb -side right -fill y
.f.text configure -xscrollcommand ".f.hsb set"
scrollbar .f.hsb -orient horizontal -command ".f.text xview"
pack .f.hsb -side bottom -fill x
pack .f.text -expand yes -fill both
for {set i 0} {$i <20} {incr i} {
  .f.text insert end "$i\: This window should have scroll bars.\n" end
}
</script>

<script>
catch {destroy .f}
frame .f
pack .f -side top -fill both
text .f.text -relief sunken -border 2 -setgrid 1 -height 10 -width 20 -wrap none
.f.text configure -yscrollcommand ".f.vsb set"
scrollbar .f.vsb -orient vertical -command ".f.text yview"
pack .f.vsb -side right -fill y
.f.text configure -xscrollcommand ".f.hsb set"
scrollbar .f.hsb -orient horizontal -command ".f.text xview"
pack .f.hsb -side bottom -fill x
pack .f.text -expand yes -fill both
for {set i 0} {$i <20} {incr i} {
  .f.text insert end "$i\: This window should have scroll bars.\n" end
}
</script>

<script>
# Restores NDF files from source directory to destination directory.
# Assumes the destination directory contains a file called NDF_List.txt
# of files to be restored.

# Get source directory.
set src [LWDAQ_get_dir_name]
LWDAQ_print $t "Source Directory: $src"

set listfile [LWDAQ_get_file_name]
set dest [file dirname $listfile]
LWDAQ_print $t "Destination Directory: $dest"
LWDAQ_print $t "List File: $listfile"

# Get list of NDF files in source directory.
set srcfiles [LWDAQ_find_files $src *.ndf]
LWDAQ_print $t "Found [llength $srcfiles] in source tree."
set destfiles [LWDAQ_find_files $dest *.ndf]
LWDAQ_print $t "Found [llength $destfiles] in destination tree."

# Get list of NDF files to copy.
set f [open $listfile r]
set copyfiles [split [string trim [read $f]] " \n\t"]
close $f
LWDAQ_print $t "Want to restore [llength $copyfiles] to destination."

foreach ft $copyfiles {
	if {![winfo exists $t]} {break}
	set i [lsearch $srcfiles *$ft]
	set j [lsearch $destfiles *$ft]
	if {($i >= 0) && ($j < 0)} {
		set fs [lindex $srcfiles $i]
		set fd [file join $dest $ft]
		LWDAQ_print $t "Copying: $fs to $fd."
		file copy $fs $fd 
		LWDAQ_support
	} elseif {($i < 0) && ($j < 0)} {
		LWDAQ_print $t "ERROR: Cannot find $ft in either location."
	} elseif {($i < 0) && ($j >= 0)} {
		LWDAQ_print $t "WARNING: Found $ft in destination but not source."
	} else {
		LWDAQ_print $t "Exists: Found $ft in both locations."
	}
}
</script>

<script>
for {set i 0} {$i <= 255} {incr i} {
	set x [expr sin($i*pi()*2/256)]
	set ADC [expr round($x*20000)+30000]
	set hex [format %04x $ADC]
	LWDAQ_print $t [string range $hex 0 1]
	LWDAQ_print $t [string range $hex 2 3]
}
</script>

<script>
for {set i 0} {$i <= 255} {incr i} {
	set x [expr sin($i*$pi*2/256)]
	set ADC [expr round($x*20000)+30000]
	set hex [format %04x $ADC]
	LWDAQ_print $t [string range $hex 0 1]
	LWDAQ_print $t [string range $hex 2 3]
}
</script>

<script>
for {set i 0} {$i <= 255} {incr i} {
	set x [expr sin($i*3.14159*2/256)]
	set ADC [expr round($x*20000)+30000]
	set hex [format %04x $ADC]
	LWDAQ_print $t [string range $hex 0 1]
	LWDAQ_print $t [string range $hex 2 3]
}
</script>

<script>
for {set i 0} {$i < 128} {incr i} {
	set x [expr sin($i*3.14159*2/128)]
	set ADC [expr round($x*20000)+30000]
	set hex [format %04x $ADC]
	LWDAQ_print $t [string range $hex 0 1]
	LWDAQ_print $t [string range $hex 2 3]
}
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [read $f]
close $f
LWDAQ_print $t $contents
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [read $f]
close $f

set found [regexp {nets(.*)} match nets]
if {!$found} {LWDAQ_print $t "ERROR: No netlist found."}
LWDAQ_print $t $match
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [read $f]
close $f

set found [regexp {nets(.*)} $contents match nets]
if {!$found} {LWDAQ_print $t "ERROR: No netlist found."}
LWDAQ_print $t $nets
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [read $f]
close $f

set found [regexp {nets(.*)} $contents match nets]
if {!$found} {LWDAQ_print $t "ERROR: No netlist found."}
LWDAQ_print $t $nets
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [read $f]
close $f

set found [regexp {nets(.*)} $contents match nets]
if {!$found} {LWDAQ_print $t "ERROR: No netlist found."}
set nets [string trim $nets]
LWDAQ_print $t $nets
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [read $f]
close $f

set found [regexp {nets(.*)} $contents match nets]
if {!$found} {LWDAQ_print $t "ERROR: No netlist found."}
set nets [split [string trim $nets] \n]
foreach line $nets {
	LWDAQ_print $t $line
}
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [read $f]
close $f

set found [regexp {nets(.*)} $contents match nets]
if {!$found} {LWDAQ_print $t "ERROR: No netlist found."}
set nets [split [string trim $nets] \n]
foreach line $nets {
	if {[regexpr {[ ]+\(net.*?\(name "([^"]*)"\)} $line match name]} {
		LWDAQ_print $t $name
	}
}
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [read $f]
close $f

set found [regexp {nets(.*)} $contents match nets]
if {!$found} {LWDAQ_print $t "ERROR: No netlist found."}
set nets [split [string trim $nets] \n]
foreach line $nets {
	if {[regexp {[ ]+\(net.*?\(name "([^"]*)"\)} $line match name]} {
		LWDAQ_print $t $name
	}
}
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [read $f]
close $f

set found [regexp {nets(.*)} $contents match nets]
if {!$found} {LWDAQ_print $t "ERROR: No netlist found."}
set nets [split [string trim $nets] \n]
foreach line $nets {
	if {[regexp {[ ]+\(net.*?\(name "([^"]*)"\)} $line match name]} {
		LWDAQ_print $t $name
	}
}
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [read $f]
close $f

set found [regexp {nets(.*)} $contents match nets]
if {!$found} {LWDAQ_print $t "ERROR: No netlist found."}
set nets [split [string trim $nets] \n]
foreach line $nets {
	if {[regexp {[ ]+\(net.*?\(name "([^"]*)"\)} $line match name]} {
		LWDAQ_print $t "\n$name "
	} elseif {[regexp {[ ]+\(node.*?\(ref (.*?)\)} $line match part]} {
		LWDAQ_print -nonewline $t "$part "
	}
}
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [read $f]
close $f

set found [regexp {nets(.*)} $contents match nets]
if {!$found} {LWDAQ_print $t "ERROR: No netlist found."}
set nets [split [string trim $nets] \n]
foreach line $nets {
	if {[regexp {[ ]+\(net.*?\(name "([^"]*)"\)} $line match name]} {
		LWDAQ_print $t "\n$name "
	} elseif {[regexp {[ ]+\(node.*?\(ref (.+?)\)} $line match part]} {
		LWDAQ_print -nonewline $t "$part "
	}
}
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [read $f]
close $f

set found [regexp {nets(.*)} $contents match nets]
if {!$found} {LWDAQ_print $t "ERROR: No netlist found."}
set nets [split [string trim $nets] \n]
foreach line $nets {
	if {[regexp {[ ]+\(net.*?\(name "([^"]*)"\)} $line match name]} {
		LWDAQ_print $t "\n$name "
	} elseif {[regexp {[ ]+\(node.*?\(ref ([^\)]*\)} $line match part]} {
		LWDAQ_print -nonewline $t "$part "
	}
}
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [read $f]
close $f

set found [regexp {nets(.*)} $contents match nets]
if {!$found} {LWDAQ_print $t "ERROR: No netlist found."}
set nets [split [string trim $nets] \n]
foreach line $nets {
	if {[regexp {[ ]+\(net.*?\(name "([^"]*)"\)} $line match name]} {
		LWDAQ_print $t "\n$name "
	} elseif {[regexp {[ ]+\(node.*?\(ref ([^\)]*)\)} $line match part]} {
		LWDAQ_print -nonewline $t "$part "
	}
}
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [read $f]
close $f

set found [regexp {nets(.*)} $contents match nets]
if {!$found} {LWDAQ_print $t "ERROR: No netlist found."}
set nets [split [string trim $nets] \n]
foreach line $nets {
	if {[regexp {[ ]+\(net.*?\(name "([^"]*)"\)} $line match name]} {
		LWDAQ_print $t "\n$name "
	} elseif {[regexp {[ ]+\(node.*?\(ref ([^\)]*)\).+?\(pin ([^\)]*)\)} $line match part pin]} {
		LWDAQ_print -nonewline $t "$part-$pin"
	}
}
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [read $f]
close $f

set found [regexp {nets(.*)} $contents match nets]
if {!$found} {LWDAQ_print $t "ERROR: No netlist found."}
set nets [split [string trim $nets] \n]
foreach line $nets {
	if {[regexp {[ ]+\(net.*?\(name "([^"]*)"\)} $line match name]} {
		LWDAQ_print -nonewline $t "\n$name "
	} elseif {[regexp {[ ]+\(node.*?\(ref ([^\)]*)\).+?\(pin ([^\)]*)\)} $line match part pin]} {
		LWDAQ_print -nonewline $t "$part-$pin "
	}
}
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [read $f]
close $f

set found [regexp {nets(.*)} $contents match nets]
if {!$found} {LWDAQ_print $t "ERROR: No netlist found."}
set nets [split [string trim $nets] \n]
foreach line $nets {
	if {[regexp {[ ]+\(net.*?\(name "([^"]*)"\)} $line match name]} {
		LWDAQ_print -nonewline $t "\n$name "
	} elseif {[regexp {[ ]+\(node.*?\(ref ([^\)]*)\).+?\(pin ([^\)]*)\)} $line match part pin]} {
		LWDAQ_print -nonewline $t "$part-$pin "
	}
}
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [read $f]
close $f

set found [regexp {nets(.*)} $contents match nets]
if {!$found} {LWDAQ_print $t "ERROR: No netlist found."}
set nets [split [string trim $nets] \n]
foreach line $nets {
	if {[regexp {[ ]*\(net.*?\(name "([^"]*)"\)} $line match name]} {
		LWDAQ_print -nonewline $t "\n$name "
	} elseif {[regexp {[ ]+\(node.*?\(ref ([^\)]*)\).+?\(pin ([^\)]*)\)} $line match part pin]} {
		LWDAQ_print -nonewline $t "$part-$pin "
	}
}
</script>

