# Reception Average Script for One-Minute Intervals
# Paste this script into the LWDAQ Toolmaker and execute it.

# Number of seconds over which you wish to take the average reception.
set averaging_interval 60

# Channels to analyze.
set select "1 2"

# We write a title line to the screen for the benefit of spreadsheet plots.
LWDAQ_print $t "Time $select"

# We select a list of files in a browser. We sort them in order of increasing time stamp.
set fnl [lsort -dictionary [LWDAQ_get_file_name 1]]

# We initialize some variables used in the analysis.
set previous_clock_seconds 0
set start_clock_seconds 0
set count 0
foreach id $select {
    set reception_$id 0
}

# We go through the files and set our start time based upon the file name.
foreach fn $fnl {
    if {![regexp -nocase {M([0-9]{10}).*?\.txt} $fn match file_clock_seconds]} {
        error "File [file tail $fn] has invalid name."
    }
    if {$previous_clock_seconds == 0} {
        set previous_clock_seconds $file_clock_seconds
        set start_clock_seconds $file_clock_seconds
    }

    # Read the characteristics from the file into a list.
    set f [open $fn r]
    set characteristics [string trim [read $f]]
    close $f
    set characteristics [split $characteristics \n]

    # Go through all the characteristics lines.
    for {set i 0} {$i < [llength $characteristics]} {incr i} { 

        # We get the i'th characteristics line from the list.
        set r [lindex $characteristics $i]

        # We go through each selected id, find the reception value that corresponds to this id, and store it.
        foreach id $select {
            set index [lsearch -start 2 $r $id]
            if {$index >= 0} {
                set reception_$id [expr [set reception_$id] + [lindex $r [expr $index + 1]]]
            }
        }

        # Increment the interval counter.
        incr count

        # We obtain the time of this line from the file name and the time given in the second element of the characteristics line.
        set clock_seconds [expr $file_clock_seconds + [lindex $r 1]]

        # Whenever we have accumulated an averaging interval's worth of data, we print the averages to the screen along with the time from the start of our calculation.
        if {[expr $clock_seconds - $previous_clock_seconds] >= $averaging_interval} {
            set result "[expr round($clock_seconds) - $start_clock_seconds] "
            foreach id $select {
                append result [format %.1f [expr [set reception_$id] / $count]]
                append result " "
            }
            set previous_clock_seconds $clock_seconds
            foreach id $select {set reception_$id 0}
            set count 0
            LWDAQ_print $t $result
        }
        LWDAQ_support
        if {![winfo exists $t]} {break}
    }
}
