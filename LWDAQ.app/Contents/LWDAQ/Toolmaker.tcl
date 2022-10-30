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

