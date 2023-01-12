# LWDAQ EDF Package, (c) 2015-2023 Kevan Hashemi, Open Source Instruments Inc.
#
# A library of routines to create and add to EDF (European Data Format) files
# for neuroscience research, in which we assume all signals are are derived from
# sources that produce sixteen-bit unsigned data samples that we must translate
# into the EDF sixteen-bit little-endian signed integers, and for which all
# signals have the same voltage range and units.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.

# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.

# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place - Suite 330, Boston, MA  02111-1307, USA.

# Version 1.1 First version.
# Version 1.2 Change default description strings, add routine to read recording
# name.

# Load this package or routines into LWDAQ with "package require EDF".
package provide EDF 1.2

# Clear the global EDF array if it already exists.
if {[info exists EDF]} {unset EDF}

# Default values for EDF header fields. These apply to recordings from a
# subcutaneous transmitter with gain x100, battery voltage 2.7 V, and common
# voltages 1.8 V.
set EDF(patient) "unspecified"
set EDF(recording) "unspecified"
set EDF(transducer) "unspecified"
set EDF(unit) "uV"
set EDF(min) "-18000"
set EDF(max) "+9000"
set EDF(lo) "-32768"
set EDF(hi) "+32767"
set EDF(filter) "unspecified" 

# Global variables that define the location of records in the header, as defined
# in document http://www.edfplus.info/specs/edf.html.
set EDF(patient_loc) 8
set EDF(num_records_loc) 236
set EDF(header_size_loc) 184

#
# EDF_string_fix arranges strings for the EDF header. In the EDF header, strings
# must be a particular length, left-adjusted, and padded with spaces. We declare
# a routine to perform this padding and curtailing, in case the string we want
# to include is too long for the space available.
#
proc EDF_string_fix {s l} {
	set s [string range $s 0 [expr $l - 1]]
	while {[string length $s] < $l} {append s " "}
	return $s
}

#
# EDF_string_pop reads len characters from the string named strname, removes
# these characters from the string, and returns the characters with spaces
# before and after removed.
#
proc EDF_string_pop {strname len} {
	upvar $strname s
	set pop [string range $s 0 [expr $len - 1]]
	set s [string range $s $len end]
	return [string trim $pop]
}

#
# EDF_create creates a new European Data Format file, which is a format accepted
# by many EEG and ECG display programs. The file includes no data, only the
# header, which is text-only. For a description of the EDF file format, see
# http://www.edfplus.info/specs/edf.html. The format breaks a recording into
# intervals, which they call "records", each of which is of a fixed duration in
# seconds. Each record has a fixed number of signals, and each signal contains a
# fixed number of samples. All samples are little-endian two-byte signed
# integers. The minimum value is -32768 and the maxium is 32767. We cannot store
# values that range from 0-65536, nor can we store real-valued samples. But this
# routine does not store signals, it creates the header file, in which the
# number of records is set to zero, in anticipation of later routines adding
# records to the file and, in doing so, incrementing the number of data records
# field in the header. The total length of the header will be 256 bytes plus
# another 256 bytes per signal. If a file already exists with the specified
# name, this routine will delete and replace the previous file. The routine
# requires that we tell it the file name, the interval length in seconds, and we
# provide a list of signal labels with their number of samples per second. For
# example, "1 512 2 512 4 256 8 1024". Note that the EDF header will specify the
# number of samples per interval, which we calculate from the sample rate and
# interval length. If we don't specify a date, we use the current date. The
# patient and recording strings are optional.
#
proc EDF_create {file_name interval signals \
		{date ""} \
		{patient ""} \
		{recording ""}} {
	global EDF
	
	# Start with an empty header string.
	set header ""

	# Fill in version, patient, and recording fields.
	append header [EDF_string_fix "0" 8]
	if {$patient == ""} {set patient $EDF(patient)}
	append header [EDF_string_fix $patient 80]
	if {$recording == ""} {set recording $EDF(recording)}
	append header [EDF_string_fix $recording 80]

	# Record the start date and time. If we have no date specified, use the current
	# time.
	if {$date == ""} {set date [clock seconds]}
	append header [EDF_string_fix [clock format $date -format %d\.%m\.%y] 8]
	append header [EDF_string_fix [clock format $date -format %H\.%M\.%S] 8]

	# Header length will go here, we'll fill it in when we know it.
	append header {HHHHHHHH}

	# A reserved field.
	append header [EDF_string_fix "" 44]

	# The number of data records. Zero now, but will be updated every new interval.
	append header [EDF_string_fix "0" 8]

	# Duration of one data record in seconds.
	append header [EDF_string_fix $interval 8]

	# The number of signals in each data record. We have a signal list that 
	# provides a label and samples per second for each signal
	append header [EDF_string_fix [expr [llength $signals] / 2] 4]

	# The name of each signal is its channel number. We impose this restriction
	# so we can read the header and compose or channel selector string.
	foreach {id fq} $signals {
		append header [EDF_string_fix $id 16]
	}
	
	# A transducer type, units, minimum, and maximum values for each signal.
	foreach {p len} {transducer 80 unit 8 min 8 max 8 lo 8 hi 8 filter 80} {
		foreach {id fq} $signals {
			if {![info exists EDF($p\_$id)]} {
				set EDF($p\_$id) $EDF($p)
			}
			append header [EDF_string_fix [set EDF($p\_$id)] $len]
		}
	}
		
	# The number of samples per record. This is the sample frequency multiplied by the
	# playback interval.
	foreach {id fq} $signals {
		append header [EDF_string_fix "[expr round($interval * $fq)]" 8]
	}
	
	# A reserved field.
	foreach {id fq} $signals {
		append header [EDF_string_fix "" 32]
	}
	
	# Now we have the header, we can write its length into the header length field.
	set header_len [string length $header]
	set header [regsub {HHHHHHHH} $header [EDF_string_fix $header_len 8]]

	# Make sure we have only printable characters in the header. We replace any non-printable
	# characters with a space.
	set header [regsub -all {[^ -~]} $header " "]
	
	# Open the file for writing, and print the header to the file, making sure we don't 
	# leave a newline character at the end.
	set f [open $file_name w]
	puts -nonewline $f $header
	close $f

	# Return the length of the header.
	return $header_len
}

#
# EDF_num_records_write sets the number of records field in the header of
# and EDF file.
#
proc EDF_num_records_write {file_name num_records} {
	global EDF

	# Find the number of records counter in the header.
	set f [open $file_name r+]
	fconfigure $f -translation binary
	seek $f $EDF(num_records_loc)
	puts -nonewline $f [EDF_string_fix $num_records 8]
	close $f

	# Return the new value of the number of recrods.
	return $num_records
}

#
# EDF_num_records_read gets the number of records field from the header of
# and EDF file.
#
proc EDF_num_records_read {file_name} {
	global EDF

	# Find the number of records counter in the header.
	set f [open $file_name r+]
	fconfigure $f -translation binary
	seek $f $EDF(num_records_loc)
	set num_records [read $f 8]
	close $f
	
	# Return the new value of the number of records.
	return $num_records
}

#
# EDF_num_records_incr increments the number of data records field in the header of the
# named EDF file.
#
proc EDF_num_records_incr {file_name} {
	global EDF

	# Find the number of records counter in the header.
	set f [open $file_name r+]
	fconfigure $f -translation binary
	seek $f $EDF(num_records_loc)
	set num_records [read $f 8]
	
	# Increment number of records and write it back into the header.
	incr num_records
	seek $f $EDF(num_records_loc)
	puts -nonewline $f [EDF_string_fix $num_records 8]
	close $f

	# Return the new value of the number of recrods.
	return $num_records
}

#
# EDF_patient_read gets the patient name field from the header of
# and EDF file.
#
proc EDF_patient_read {file_name} {
	global EDF

	# Find the patient field in the header.
	set f [open $file_name r+]
	fconfigure $f -translation binary
	seek $f $EDF(patient_loc)
	set patient [read $f 80]
	close $f
	
	# Return the patient name, with white spaces removed
	return [string trim $patient]
}

#
# EDF_recording_read gets the recording name field from the header of
# and EDF file.
#
proc EDF_recording_read {file_name} {
	global EDF

	# Find the patient field in the header.
	set f [open $file_name r+]
	fconfigure $f -translation binary
	seek $f $EDF(recording_loc)
	set patient [read $f 80]
	close $f
	
	# Return the recording name, with white spaces removed
	return [string trim $recording]
}

#
# EDF_header_size returns the length of an EDF file's header field.
#
proc EDF_header_size {file_name} {
	global EDF
	
	# Check that the file exists.
	if {![file exists $file_name]} {
		error "Cannot find $file_name\."
	}

	# Find the header size value in the header.
	set f [open $file_name r+]
	fconfigure $f -translation binary
	seek $f $EDF(header_size_loc)
	set header_size [read $f 8]
	close $f
	
	# Check for errors.
	if {![string is integer -strict $header_size]} {
		error "Invalid EDF header size field."
	}
	
	# Return the value.
	return $header_size
}

#
# EDF_header_read reads the contents of an EDF header into the EDF package's
# global array. The names of the signals should contain no spaces or special
# characters other than an underscore, so they may be used to create array
# element names. If the name cannot be thus used, the routine reads all the
# signal headings, but does nothing with them. The routine is guaranteed to work
# on EDF files generated by this EDF package. It returns a list of signal names
# and sample rates.
#
proc EDF_header_read {file_name} {
	global EDF

	set size [EDF_header_size $file_name]
	set f [open $file_name r]
	fconfigure $f -translation binary
	set header [read $f $size]
	close $f
	
	set version [EDF_string_pop header 8]
	set EDF(patient) [EDF_string_pop header 80]
	set EDF(recording) [EDF_string_pop header 80]
	set date [EDF_string_pop header 16]
	set size_again [EDF_string_pop header 8]
	set reserved [EDF_string_pop header 44]
	set num_records [EDF_string_pop header 8]
	set interval [EDF_string_pop header 8]
	set num_signals [EDF_string_pop header 4]
	set ids [list]
	for {set n 1} {$n <= $num_signals} {incr n} {
		lappend ids [EDF_string_pop header 16]
	}
	foreach {p len} {transducer 80 unit 8 min 8 max 8 lo 8 hi 8 filter 80} {
		foreach id $ids {
			set value [EDF_string_pop header $len]
			if {[string is wordchar $id]} {set EDF($p\_$id) $value}
		}
	}
	set signals [list]
	foreach id $ids {
		set num_samples [EDF_string_pop header 8]
		set fq [expr round($num_samples / $interval)]
		if {[string is wordchar $id]} {lappend signals $id $fq}
	}

	return $signals	
}

#
# EDF_append adds data to an existing EDF file. It takes a string of unsigned
# integers in the range 0..65535 and translates them into little-endian
# sixteen-bit signed integers, with 0 being translated to -32768 and 65535
# becoming 32767. The binary data is added to the end of the named EDF file. If
# the incoming data is outside the range 0..65535, it will be translated as if
# it were its value modulo 65536.
#
proc EDF_append {file_name data} {

	# Check that the file exists.
	if {![file exists $file_name]} {
		error "Cannot find $file_name\."
	}
	
	# Translate ascii string to binary data.
	set binary_data ""
	foreach x $data {
		append binary_data [binary format s [expr round($x) - 32768]]
	}
	
	# Append binary data to file.
	set f [open $file_name a]
	fconfigure $f -translation binary
	puts -nonewline $f $binary_data
	close $f
	
	# Return number of samples written.
	return [llength $data]
}

#
# EDF_merge takes one or more EDF files and copies their contents into a new EDF
# file. The routine checks that the headers of all input files are the same
# length, but otherwise does not confirm that the files have identical data
# formats. The header of the output file is the same as the header of the input
# file. If the outfile name is the same as the first infile name, the routine
# simply adds the remaining input file contents to the existing outfile.
#
proc EDF_merge {outfile_name infile_name_list} {

	# Check that the input files exist.
	if {[llength $infile_name_list] == 0} {
		error "No input files specified."
	}
	foreach fn $infile_name_list {
		if {![file exists $fn]} {
			error "Cannot find input file $fn\."
		}
	}
	
	# Copy the first input file to the output file.
	set if1 [lindex $infile_name_list 0]
	if {[file normalize $outfile_name] != [file normalize $if1]} {
		if {[file exists $outfile_name]} {
			file delete $outfile_name
		}
		file copy $if1 $outfile_name
	}
	set infile_name_list [lrange $infile_name_list 1 end]
	
	# Determine the header size and number of records in the output file.
	set hso [EDF_header_size $outfile_name]
	set nro [EDF_num_records_read $outfile_name]
	
	# Transfer data from each subsequent input file.
	foreach fn $infile_name_list {
		# Determine the header size and number of records in the input file.
		set hsi [EDF_header_size $fn]
		set nri [EDF_num_records_read $fn]
		if {$hsi != $hso} {
			error "Header mismatch [file tail $outfile_name] and [file tail $fn]."
		}
	
		# Read the data records out of the input file.
		set f [open $fn r]
		fconfigure $f -translation binary
		seek $f $hsi
		set dri [read $f]
		close $f
	
		# Append the data records to the output file.
		set f [open $outfile_name a]
		fconfigure $f -translation binary
		puts -nonewline $f $dri
		close $f
	
		# Keep track of the number of records in the file.
		set nro [expr $nro + $nri]
		EDF_num_records_write $outfile_name $nro
	}
	
	# Return the number of data records in the output file.
	return $nro
}