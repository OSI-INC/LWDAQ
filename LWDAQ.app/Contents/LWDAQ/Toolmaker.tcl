<script>
# NDF Archive Duplicate Machine. This Toolmaker script copies
# NDF files from a source to a destination directory. It
# copies only if the destination archive does not exist.
# If there are archives in the destination that do not exist
# in the source directory, the script deletes these files.
# At the end, the set of NDF files in the destination 
# directory will be the same as those in the source directory.

# Get source and destination directory names.
set src [LWDAQ_get_dir_name]
LWDAQ_print $t "Source Directory: $src"
set dest [LWDAQ_get_dir_name]
LWDAQ_print $t "Destination Directory: $dest"

# Get list of NDF files in each directory.
set srcfiles [glob [file join $src *.ndf]]
set destfiles [glob [file join $dest *.ndf]]

# Make a list of the existing and non-existing files. We will
# copy the non-existing files, provided there is at least one
# existing file.
set copyfiles [list]
set existingfiles [list]
foreach fn $srcfiles {
	if {[lsearch $destfiles *[file tail $fn]] >= 0} {
		lappend existingfiles $fn
	} {
		lappend copyfiles $fn
	}
}

# If there are no existing files, issue a warning.
if {[llength $existingfiles] == 0} {
	LWDAQ_print $t "WARNING: No matching files in destination folder."
} 

# If there are files in the destination folder that do not
# exist in the source folder, and there is some overlap to
# indicate that the destination is correct for the source,
# delete the files in the destination that do not exist
# in the source.
if {[llength $existingfiles] > 0} {
	set deletefiles [list]
	foreach fn $destfiles {
		if {[lsearch $srcfiles *[file tail $fn]] < 0} {
			lappend deletefiles $fn
		}
	}
	LWDAQ_print $t "Found [llength $deletefiles] unrecognized files in destination." 
	set i 0
	set n [llength $deletefiles]
	foreach fn $deletefiles {
		if {![winfo exists $t]} {break}
		incr i
		LWDAQ_print $t "Delete $i of $n [file tail $fn] in $dest..."
		LWDAQ_support
		file delete $fn
	}
}

# If there is some overlap, copy those files that don't exist
# in the destination foler.
if {[llength $existingfiles] > 0} {
	LWDAQ_print $t "Found [llength $srcfiles] NDF files in source."
	LWDAQ_print $t "Found [llength $existingfiles] matching files in destination."
	LWDAQ_print $t "Copying [llength $copyfiles] files to destination."
	set i 0
	set n [llength $copyfiles]
	foreach fn $copyfiles {
		if {![winfo exists $t]} {break}
		incr i
		LWDAQ_print $t "Copy $i of $n [file tail $fn]..."
		LWDAQ_support
		file copy $fn [file join $dest [file tail $fn]]
	}
}
</script>

<script>
# NDF Archive Duplicate Machine. This Toolmaker script copies
# NDF files from a source to a destination directory. It
# copies only if the destination archive does not exist.
# If there are archives in the destination that do not exist
# in the source directory, the script deletes these files.
# At the end, the set of NDF files in the destination 
# directory will be the same as those in the source directory.

# Get source and destination directory names.
set src [LWDAQ_get_dir_name]
LWDAQ_print $t "Source Directory: $src"
set dest [LWDAQ_get_dir_name]
LWDAQ_print $t "Destination Directory: $dest"

# Get list of NDF files in each directory.
set srcfiles [glob [file join $src *.ndf]]
set destfiles [glob [file join $dest *.ndf]]

# Make a list of the existing and non-existing files. We will
# copy the non-existing files, provided there is at least one
# existing file.
set copyfiles [list]
set existingfiles [list]
foreach fn $srcfiles {
	if {[lsearch $destfiles *[file tail $fn]] >= 0} {
		lappend existingfiles $fn
	} {
		lappend copyfiles $fn
	}
}

# If there are no existing files, issue a warning.
if {[llength $existingfiles] == 0} {
	LWDAQ_print $t "WARNING: No matching files in destination folder."
} 

# If there are files in the destination folder that do not
# exist in the source folder, and there is some overlap to
# indicate that the destination is correct for the source,
# delete the files in the destination that do not exist
# in the source.
if {[llength $existingfiles] > 0} {
	set deletefiles [list]
	foreach fn $destfiles {
		if {[lsearch $srcfiles *[file tail $fn]] < 0} {
			lappend deletefiles $fn
		}
	}
	LWDAQ_print $t "Found [llength $deletefiles] unrecognized files in destination." 
	set i 0
	set n [llength $deletefiles]
	foreach fn $deletefiles {
		if {![winfo exists $t]} {break}
		incr i
		LWDAQ_print $t "Delete $i of $n [file tail $fn] in $dest..."
		LWDAQ_support
		file delete $fn
	}
}

# If there is some overlap, copy those files that don't exist
# in the destination foler.
if {[llength $existingfiles] > 0} {
	LWDAQ_print $t "Found [llength $srcfiles] NDF files in source."
	LWDAQ_print $t "Found [llength $existingfiles] matching files in destination."
	LWDAQ_print $t "Copying [llength $copyfiles] files to destination."
	set i 0
	set n [llength $copyfiles]
	foreach fn $copyfiles {
		if {![winfo exists $t]} {break}
		incr i
		LWDAQ_print $t "Copy $i of $n [file tail $fn]..."
		LWDAQ_support
		file copy $fn [file join $dest [file tail $fn]]
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

