<script>
# [04-AUG-22] Text Data Translator is a LWDAQ Toolmaker script. It uses the
# Neuroplayer constants, so it opens the Neuroplayer when it starts up. The
# translator opens a file selected by the user. It assumes the first line
# contains the value names. With remove_sample_time set to 1, the translator
# assumes the first value in each line is the time and ignores the first value.
# Subsequent values are samples. The values in each line can be space or tab
# delimited, or even comma delimited. The translator takes each sample and
# translates it to a sixteen-bit ADC count using the bottom and top parameters.
# The bottom parameter is the sample voltage that should correspond to 0 ADC
# counts. The top parameter is the voltage corresponding to 65535 ADC counts. We
# specify the sample frequency with the frequency parameter, in Hz. To run this
# script, copy and paste it into the Toolmaker script window. The final archive
# will contain all the channels available in the original text file. The
# metadata of the archive will tell us the name of this program, and the names
# of the channels in the original text file, and how these names correspond to
# the NDF channel numbers. When it's done translating, if open_neuroplayer is
# set, the translator opens the Neuroplayer and configures it to play the
# newly-translated archive.

# Initialize.
set TDT(version) "1.5"
set TDT(control) "Idle"
set TDT(frequency) 1024
set TDT(done) 0.0
set TDT(bottom) -5000
set TDT(top) +5000
set TDT(remove_sample_time) 1
set TDT(ndf_metadata_size) 20000
set TDT(open_neuroplayer) 1
set TDT(clocks_per_second) 128
set TDT(min_play_interval) 1.0

# Make buttons.
set ff [frame $f.a]
pack $ff -side top
button $ff.translate -text Translate -command Translate
button $ff.stop -text Stop -command [list set TDT(control) "Stop"]
label $ff.control -textvariable TDT(control) -fg blue -width 20
pack $ff.control $ff.translate $ff.stop -side left 
checkbutton $ff.onp -text "Open Neuroplayer" \
  -variable TDT(open_neuroplayer)
pack $ff.onp -side left
set ff [frame $f.f]
pack $ff -side top
label $ff.fl -text "Sample Frequency (Hz)"
entry $ff.frequency -textvariable TDT(frequency) -width 6
pack $ff.fl $ff.frequency -side left
checkbutton $ff.rst -text "Remove Sample Time" \
  -variable TDT(remove_sample_time)
pack $ff.rst -side left
set ff [frame $f.r]
pack $ff -side top
label $ff.rl -text "Range (Bottom and Top)"
entry $ff.rb -textvariable TDT(bottom) -width 10
entry $ff.rt -textvariable TDT(top) -width 10
pack $ff.rl $ff.rb $ff.rt -side left
set ff [frame $f.d]
pack $ff -side top
scale $ff.done -from 0 -to 100 -length 200 -variable TDT(done) \
  -orient horizontal -label "Progress %" -showvalue 0
pack $ff.done -side left
raise [winfo toplevel $f]

# Translate routine.
proc Translate {} {
  global TDT t
  upvar Neuroplayer_info info
  upvar Neuroplayer_config config

  if {$TDT(control) != "Idle"} {return}
  set TDT(control) "Translate"
  set TDT(done) 0.0
  
  if {$TDT(bottom) >= $TDT(top)} {
  	LWDAQ_print $t "ERROR: Range bottom must be less than range top."
  	set TDT(control) "Idle"
  	return "ERROR"
  }
  
  set TDT(fn) [LWDAQ_get_file_name]
  if {$TDT(fn) == ""} {
  	LWDAQ_print $t "ERROR: No file selected."
  	set TDT(control) "Idle"
  	return "ERROR"
  }

  LWDAQ_print $t "Opening text file..."
  set f [open $TDT(fn) r]
  set line [string trim [gets $f]]
  set names [split $line ", \t"]
  LWDAQ_print $t "First line contains [llength $names] values."
  if {$TDT(remove_sample_time)} {
    LWDAQ_print $t "We assume the first value is a measure of time."
    set names [lreplace $names 0 0]
  }
  set TDT(num_channels) [llength $names]
  LWDAQ_print $t "Channel Names: $names"
  LWDAQ_print $t "Translating $TDT(num_channels) signal channels."
  set TDT(ofn) [file join \
    [file dirname $TDT(fn)] \
    [file rootname $TDT(fn)]\.ndf]
  LWDAQ_print $t "Creating NDF archive [file tail $TDT(ofn)] with metadata:"
  LWDAQ_ndf_create $TDT(ofn) $TDT(ndf_metadata_size)
  set metadata "Date Created: [clock format [clock seconds] -format {%c}]\
     \nCreator: Text Data Translator applied to [file tail $TDT(fn)]\
     \nRange: $TDT(bottom) to $TDT(top)\
     \nSample Frequency: $TDT(frequency) Hz\
     \nOriginal Channel Name, Translated Channel Number:"
  set id 0
  foreach name $names { 
    incr id
    append metadata "\n$name $id"
  }
  LWDAQ_ndf_string_write $TDT(ofn) "<c>\n$metadata\n</c>"
  LWDAQ_print $t $metadata green

  LWDAQ_print $t "Writing translation to [file tail $TDT(ofn)]..."
  set sample_period \
    [expr 1.0 * $TDT(clocks_per_second) / $TDT(frequency)] 
  set next_sample_time 0.0
  set next_timestamp_time 0
  set data_block ""
  set file_size [file size $TDT(fn)]
  set bytes_read [string length $line]
  while {[gets $f line] > 0} {
    # If it's time to insert a timestamp, do so before we append
    # the data to our data block.
    if {$next_timestamp_time <= $next_sample_time} {
      append data_block [binary format cSc 0 $next_timestamp_time 4]
      incr next_timestamp_time
    }
    
    # Get the list of values for this line. Replace commas with 
    # spaces. Remove the first value because it is the timestamp
    # if necessary.
    set values [split [string trim $line] ", \t"] 
    if {$TDT(remove_sample_time)} {set values [lreplace $values 0 0]}
    
    # Append the data to the our data block.
    set id 1
    foreach v $values {
      append data_block [binary format cSc \
        $id [expr round(65535.0 * \
          ($v - $TDT(bottom)) / \
          ($TDT(top) - $TDT(bottom))) ] \
        [expr round(($next_sample_time - $next_timestamp_time + 1) * 256)]]
      incr id
    }
    set next_sample_time [expr $next_sample_time + $sample_period]

    # When the block gets big enough, write it to our ndf file.
    if {[string length $data_block] > 10000} {
      LWDAQ_ndf_data_append $TDT(ofn) $data_block
      set data_block ""
    }

    # Every now and then, we adjust our status bar.
    set bytes_read [expr $bytes_read + [string length $line]]
    set TDT(done) [expr 100.0 * $bytes_read / $file_size]
    LWDAQ_support

    if {$TDT(control) == "Stop"} {break}
  }

  # Append whatever data is in the block and close the file.
  LWDAQ_ndf_data_append $TDT(ofn) $data_block
  close $f
  
  # Open the Neuroplayer and configure.
  set TDT(control) "Configure"
  LWDAQ_print $t "Opening and configuring Neuroplayer..."
  LWDAQ_run_tool Neuroplayer
  set play_interval [expr 512.0 / $TDT(frequency)]
  while {$play_interval < $TDT(min_play_interval)} {set play_interval [expr $play_interval * 2.0]}
  foreach {a b} [list enable_reconstruct 0 \
    play_interval $play_interval \
    play_file $TDT(ofn) \
    play_file_tail [file tail $TDT(ofn)] \
    default_frequency $TDT(frequency) \
    f_max [expr round($TDT(frequency) / 2.0)]] {
    LWDAQ_print $t "Setting $a = \"$b\"" orange
    if {[info exists config($a)]} {
      set config($a) $b
    } {
      set info($a) $b
    }
  }
  
  set TDT(control) "Idle"
  LWDAQ_print $t "Done."
  return "SUCCESS"
}

# Write to text window.
LWDAQ_print $t "Text Data Translator Version $TDT(version)" purple
LWDAQ_print $t "Press Translate to choose text file for translation."
update
</script>

