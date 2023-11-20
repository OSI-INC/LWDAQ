# Long-Wire Data Acquisition Software (LWDAQ)
# Copyright (C) 2004-2021 Kevan Hashemi, Brandeis University
# Copyright (C) 2022-2023 Kevan Hashemi, Open Source Instruments Inc.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

#
# Instruments.tcl contains the routines that set up the common
# foundations upon which all LWDAQ instruments are built.

#
# LWDAQ_instruments_init initializes the instruments routines.
#
proc LWDAQ_instruments_init {} {
	upvar #0 LWDAQ_Info info
	set info(instrument_info_rows) 20
	set info(instrument_entry_width) 20
	set info(num_lines_keep) 1000
	set info(line_purge_period) 100
	set info(max_daq_attempts) 5
	set info(num_daq_errors) 0
	set info(instrument_counter_max) 10000
	set instrument_files [glob [file join $info(instruments_dir) *.tcl]]
	set info(instruments) [list]
	foreach i $instrument_files {
		lappend info(instruments) [lindex [split [file tail $i] .] 0]
	}
	set info(instruments) [lsort -dictionary $info(instruments)]
	foreach i $instrument_files {source $i}
	foreach i $info(instruments) {LWDAQ_init_$i}
	return ""
}

#
# LWDAQ_reset_instrument_counters sets all the counters to 
# the specifiec value, or to 1 if no value is specified.
#
proc LWDAQ_reset_instrument_counters {{value 0}} {
	upvar #0 LWDAQ_Info info
	foreach e $info(instruments) {
		upvar #0 LWDAQ_info_$e info_instr
		set info_instr(counter) $value
	}
	return ""
}

#
# LWDAQ_info_button makes a new toplevel window with a button that lets you see
# the instrument script. Below the button are the elements of the instrument's
# info array. You can change the elements by typing in the entry boxes.
#
proc LWDAQ_info_button {name} {
	upvar #0 LWDAQ_info_$name info
	global LWDAQ_Info
	
	# Create the info window.
	set w $info(window)\.info
	if {[winfo exists $w]} {destroy $w}
	toplevel $w
	wm title $w "$info(name) Info Array"
	
	# Make three frames: one for buttons and two for entries.
	frame $w.buttons
	pack $w.buttons -side top -fill x
	
	# Make buttons to save and unsave the instrument settings.
	button $w.buttons.save -text "Save Settings" \
		-command "LWDAQ_instrument_save $name"
	button $w.buttons.unsave -text "Unsave Settings" \
		-command "LWDAQ_instrument_unsave $name"
	pack $w.buttons.save $w.buttons.unsave -side left -expand 1
	
	# Call the info buttons creation routine, if it exists, passing it
	# the name of the buttons frame.
	if {[info commands LWDAQ_infobuttons_$name] != ""} {
		LWDAQ_infobuttons_$name $w.buttons
	}
	
	# Divide the list of info array names into separate lists of up
	# to the info_rows value.
	set info_list [lsort -dictionary [array names info]]
	set n 0
	set h $LWDAQ_Info(instrument_info_rows)
	while {[llength $info_list] > 0} {
		incr n
		set column$n [lrange $info_list 0 [expr $h-1]]
		set info_list [lrange $info_list $h end]
	}
	
	# Make a frame for each list and create a label and entry for
	# each element in the list.
	for {set c 1} {$c <= $n} {incr c} {
		set f [frame $w.f$c]
		pack $f -side left -fill y
		set count 0
		foreach i [set column$c] {
			incr count
			label $f.l$i -text $i -anchor w
			entry $f.e$i -textvariable LWDAQ_info_$info(name)\($i) \
				-relief sunken -bd 1 -width $LWDAQ_Info(instrument_entry_width)
			grid $f.l$i $f.e$i -sticky news
		}
	}
	
	# Return the name of the window.
	return $w
}

#
# LWDAQ_write_button writes the current image to disk
#
proc LWDAQ_write_button {name} {
	upvar #0 LWDAQ_info_$name info
	upvar #0 LWDAQ_config_$name config
	global LWDAQ_Info
	if {$info(control) == "Idle"} {
		if {[lwdaq_image_exists $config(memory_name)] != ""} {
			set fn [LWDAQ_put_file_name $config(memory_name)\.daq]
			if {$fn == ""} {return ""}
			LWDAQ_write_image_file $config(memory_name) $fn
		} {
			LWDAQ_print $info(text) \
				"ERROR: Image \"$config(memory_name)\" does not exist."
			return ""
		}
	}
	return ""
}

#
# LWDAQ_read_button reads an image from disk. It allows the user
# to specify multiple files, and opens them one after another. It
# returns an empty string instead of the list of files, which might
# otherwise overwhelm our system server.
#
proc LWDAQ_read_button {name} {
	upvar #0 LWDAQ_info_$name info
	upvar #0 LWDAQ_config_$name config
	if {$info(control) == "Idle"} {
		set fl [LWDAQ_get_file_name 1]
		if {$fl == ""} {return ""}
		set config(image_source) "file"
		set config(file_name) $fl
		LWDAQ_post [list LWDAQ_acquire $name]
	}
	return ""
}
 
#
# LWDAQ_acquire_button is for use with instrument acquire buttons.
#
proc LWDAQ_acquire_button {name} {
	upvar #0 LWDAQ_info_$name info
	if {$info(control) == "Idle"} {
		set info(control) "Acquire"
		LWDAQ_post [list LWDAQ_acquire $info(name)]
	}
	if {$info(control) == "Loop"} {
		set info(control) "Acquire"
	}
	return ""
}
 
#
# LWDAQ_loop_button is for use with instrument loop buttons.
#
proc LWDAQ_loop_button {name} {
	upvar #0 LWDAQ_info_$name info
	if {$info(control) == "Idle"} {
		set info(control) "Loop"
		LWDAQ_post [list LWDAQ_acquire $info(name)]
	} 
	if {$info(control) == "Acquire"} {
		set info(control) "Loop"
		LWDAQ_post [list LWDAQ_acquire $info(name)]
	}
	return ""
}

#
# LWDAQ_stop_button is for use with instrument stop buttons. If
# the state of the instrument is already Stop, the stop button
# tries a little harder to make the instrument stop: it closes
# stops all existing LWDAQ vwait routines.
#
proc LWDAQ_stop_button {name} {
	upvar #0 LWDAQ_info_$name info
	global LWDAQ_Info
	if {$info(control) != "Idle"} {
		if {$info(control) == "Stop"} {
			if {[regexp $info(name) $LWDAQ_Info(current_event)]} {
				LWDAQ_stop_vwaits
			}
		} {
			set info(control) "Stop"
		}
	}
	return ""
}

#
# LWDAQ_stop_instruments stops all looping instruments.
#
proc LWDAQ_stop_instruments {} {
	global LWDAQ_Info
	foreach i $LWDAQ_Info(instruments) {
		LWDAQ_stop_button $i
	}
	return ""
}

#
# LWDAQ_instrument_print prints the result of analysis to an instrument text
# window using LWDAQ_print. If the verbose_result is set in the instrument's
# config array, then the routine uses the verbose_description list in the info
# array to describe each element of the result on on separate lines. We intend
# for this routine to be used only for printing instrument results in the
# instrument window. If you want to print anything else in the instrument
# window, use LWDAQ_print with the text window name $info(text). The info(text)
# element is set even if the instrument window is not open, and LWDAQ_print
# checks to see if the text window exists before it prints.
#
proc LWDAQ_instrument_print {instrument print_str {color black}} {
	upvar #0 LWDAQ_info_$instrument info
	upvar #0 LWDAQ_config_$instrument config
	if {![winfo exists $info(window)]} {return ""}
	if {(![LWDAQ_is_error_result $print_str]) && ($config(verbose_result) != 0)} {
		set verbose "\n[lindex $print_str 0]\n"
		set print_str [lreplace $print_str 0 0]
		for {set i 0} {$i < [llength $print_str]} {incr i} {
			set k [expr $i % [llength $info(verbose_description)]]
			set value [lindex $print_str $i]
			if {$value == ""} {set value "\"\""}
			set name [lindex $info(verbose_description) $k]
			append verbose "$name: $value\n"
		}
		set print_str $verbose
	}
	LWDAQ_print $info(text) $print_str $color
	return ""
}

#
# LWDAQ_instrument_analyze calls an instrument's analysis routine after checking
# its analysis_enable flag, and catches errors from the analysis routine. It
# assumes that the image it is to analyze is the image named in the instrument's
# memory_name parameter. The routine places an identifier in the result, as
# provided by the id parameter. By default, id becomes the memory name. The
# routine also prints the result to the panel text window.
#
proc LWDAQ_instrument_analyze {instrument {id ""}} {
	upvar #0 LWDAQ_info_$instrument info
	upvar #0 LWDAQ_config_$instrument config

	if {![string is integer -strict $config(analysis_enable)]} {
		set result "ERROR: Expected integer for analysis_enable,\
			got \"$config(analysis_enable)\"."
		LWDAQ_instrument_print $info(name) $result
		set analyze 0
	} {
		set result ""
		set analyze $config(analysis_enable)
	}

	# If the instrument's analyze flag is set, analyze the image using the
	# instrument's own analysis routine. Append a prefix to the result tring:
	# either the ID we were passed, or the image name. If the analysis result is
	# an error, and we have specified an ID, we want to add to the end of the
	# error report that the error occurred on "ID", for which we must remove the
	# period at the end of the error string.
	if {$analyze} {
		if {[catch {
			lwdaq_config -text_name $info(text) -photo_name $info(photo)
			set result [LWDAQ_analysis_$info(name) $config(memory_name)]
			if {![LWDAQ_is_error_result $result]} {
				if {$id != ""} {
					set result "$id $result"
				} {
					set result "$config(memory_name) $result"
				}
			} {
				if {$id != ""} {
					set result [string replace $result end end]
					set result "$result on $id\."
				}			
			}
		} error_report]} {
			set result "ERROR: $error_report"
		}
		LWDAQ_instrument_print $info(name) $result
	} {
	# If the analyze flag is not set, we clear the image overlay, so as to
	# remove any previous analysis graphics.
		lwdaq_image_manipulate $config(memory_name) none -clear 1
	}

	# If we have a window to draw the image, and the image exists, then draw it.
	if {[winfo exists $info(window)] \
			&& ([lwdaq_image_exists $config(memory_name)] != "")} {
		lwdaq_draw $config(memory_name) $info(photo) \
			-intensify $config(intensify) -zoom $info(zoom)
	}
	
	return $result
}

#
# LWDAQ_acquire acquires data for the instrument called $instrument from either
# a file, or an existing image in memory, or directly from the daq. After
# acquiring, it applies analysis if enabled and returns a result string.
#
proc LWDAQ_acquire {instrument} {
	global LWDAQ_Info LWDAQ_Driver
	upvar #0 LWDAQ_info_$instrument info
	upvar #0 LWDAQ_config_$instrument config

	if {[lsearch $LWDAQ_Info(instruments) $instrument] < 0} {
		error "no instrument called \"$instrument\""
	}
	if {$info(control) == "Stop"}  {
		set info(control) "Idle"
		return
	}
	if {$info(control) == "Idle"} {
		set info(control) "Acquire"
		if {[winfo exists $info(window)]} {
			LWDAQ_update
		}
	}
	
	if {[winfo exists $info(window)]} { 
		set saved_lwdaq_config [lwdaq_config]
		lwdaq_config -text_name $info(text) -photo_name $info(photo)
		if {[expr $info(counter) % $LWDAQ_Info(line_purge_period)] == 0} {
			$info(text) delete 1.0 "end [expr 0 - $LWDAQ_Info(num_lines_keep)] lines"
		}
	}
	
	incr info(counter) 
	if {$info(counter) > $LWDAQ_Info(instrument_counter_max)} {
		set info(counter) 1
	}
	set result ""
	set match 0
	
	if {[string match "file" $config(image_source)]} {
		set match 1
		set image_list ""
		if {[llength $config(file_name)] > 1} {
			set image_list $config(file_name)
			set restore_file_name ""
		} {
			set image_list [glob -nocomplain [lindex $config(file_name) 0]]
			set restore_file_name $config(file_name)
		}
		foreach f $image_list {
			if {$info(control) == "Stop"} {break}
			set config(file_name) $f
			if {$f != [lindex $image_list 0]} {
				incr info(counter)
				append result "\n"
			}
			if {![file exists $f]} {
				lappend result "ERROR: Cannot find file \"$f\"."
				continue
			}
			if {$info(delete_old_images)} {lwdaq_image_destroy $info(name)\*}
			if {[catch {
				set config(memory_name) [LWDAQ_read_image_file $f $info(name)\_$info(counter)]
			} error_result]} {
				LWDAQ_print $info(text) "ERROR: $error_result\."
				continue
			}
			if {$info(file_use_daq_bounds)} {
				lwdaq_image_manipulate $config(memory_name) none \
					-left $info(daq_image_left) \
					-top $info(daq_image_top) \
					-right $info(daq_image_right) \
					-bottom $info(daq_image_bottom) \
					-results ""
			}	
			lappend result [LWDAQ_instrument_analyze $info(name) [file tail $f]]
			if {[llength $image_list] > 1} {LWDAQ_update}
		}
		if {[llength $image_list] == 0} {
			set result "ERROR: No files match $config(file_name)\."
			LWDAQ_print $info(text) $result
		}
		if {[llength $image_list] == 1} {
			set result [join $result]
		}
		if {$restore_file_name != ""} {
			set config(file_name) $restore_file_name
		}
	}
		
	if {([string match "daq" $config(image_source)]) ||
			($info(name) == $config(image_source))} {
		set match 1
		set success 0
		set error_counter 0
		set daq_result "ERROR: Acquisition aborted."
		if {$info(delete_old_images)} {lwdaq_image_destroy $info(name)\*}
		while {!$success && \
				($error_counter < $LWDAQ_Info(max_daq_attempts)) \
				&& !$LWDAQ_Info(reset)} {
			if {$info(daq_extended) && \
				([info commands LWDAQ_extended_$info(name)] != "")} {
				set daq_result [LWDAQ_extended_$info(name)]
			} {
				set daq_result [LWDAQ_daq_$info(name)]
			}
			if {[LWDAQ_is_error_result $daq_result]} {
				incr error_counter
				incr LWDAQ_Info(num_daq_errors)
				if {[winfo exists $info(window)]} {
					$info(state_label) config -fg red
				} 
				LWDAQ_random_wait_ms 0 $LWDAQ_Info(daq_wait_ms)
			} {
				set success 1
			}
			if {$info(control) == "Stop"} {break}
		}
		if {[winfo exists $info(window)]} {$info(state_label) config -fg black} 
		if {$success} {
			set result [LWDAQ_instrument_analyze $info(name)]
		} {
			set result $daq_result
			LWDAQ_instrument_print $info(name) $result
		} 
	}
	
	if {[string match "memory" $config(image_source)]} {
		set match 1
		if {[lwdaq_image_exists $config(memory_name)] != ""} {
			set result [LWDAQ_instrument_analyze $info(name)]
		} {
			set result "ERROR: Image '$config(memory_name)' does not exist."
			LWDAQ_print $info(text) $result 
		}
	}
	
	if {([lsearch $LWDAQ_Info(instruments) $config(image_source)] >= 0)
			&& ($info(name) != $config(image_source))} {
		upvar #0 LWDAQ_config_$config(image_source) iconfig
		set match 1
		set saved_analysis_enable $iconfig(analysis_enable)
		set iconfig(analysis_enable) 0
		set iresult [LWDAQ_acquire $config(image_source)]
		set iconfig(analysis_enable) $saved_analysis_enable
		if {[LWDAQ_is_error_result $iresult]} {
			set result $iresult
			LWDAQ_print $info(text) $result 
		} {
			set config(memory_name) $iconfig(memory_name)
			set result [LWDAQ_instrument_analyze $info(name)]
		}
	} {
		if {[info command LWDAQ_daq_$config(image_source)] != ""} {
			set match 1
			set config(memory_name) [LWDAQ_daq_$config(image_source)]
			set result [LWDAQ_instrument_analyze $info(name)]
		}
	}
	
	if {!$match} {
		LWDAQ_print $info(text) "ERROR: no such image source,\
			\"$config(image_source)\"." red	
	}
	
	LWDAQ_update
	
	if {$info(control) == "Loop"} {
		if {[winfo exists $info(window)]} {
			LWDAQ_post [list LWDAQ_acquire $info(name)]
		} {
			set info(control) "Idle"
		}
	}
	if {$info(control) == "Acquire"} {
		set info(control) "Idle"
	}
	if {$info(control) == "Stop"}  {
		set info(control) "Idle"
	}
	
	if {[info exists saved_lwdaq_config]} {
		eval "lwdaq_config $saved_lwdaq_config"
	}

	return $result 
} 

#
# LWDAQ_open opens the named instrument's window. We recommend that you post
# this routine to the event queue, or else it will conflict with acquisitions
# from the same instrument that are taking place with the window closed. The
# routine returns the name of the instrument window.
#
proc LWDAQ_open {name} { 
	global LWDAQ_Info LWDAQ_Driver
	upvar #0 LWDAQ_info_$name info
	upvar #0 LWDAQ_config_$name config
	
	# See if the instrument window already exists, and if it does, bring
	# it to the front and return.
	set w $info(window)
	if {[winfo exists $w]} {
		raise $w
		return ""
	}

	# Create a new toplevel window for the instrument panel.
	toplevel $w
	scan [wm maxsize .] %d%d x y
	wm maxsize $w [expr $x*2] [expr $y*2]
	wm title $w $name
	
	# Start the instrument in the idle state.
	set info(control) "Idle" 

	# Make the standard instrument buttons along the top.
	set f [frame $w.buttons]
	pack $f -side top -fill x
	label $f.state -textvariable LWDAQ_info_$name\(control) -width 8
	label $f.counter -textvariable LWDAQ_info_$name\(counter) -width 6
	button $f.acquire -text "Acquire" -command [list LWDAQ_acquire_button $name]
	button $f.loop -text "Loop" -command [list LWDAQ_loop_button $name]
	button $f.stop -text "Stop" -command [list LWDAQ_stop_button $name]
	button $f.write -text "Write" \
		-command [list LWDAQ_post [list LWDAQ_write_button $name]]
	button $f.read -text "Read" \
		-command [list LWDAQ_post [list LWDAQ_read_button $name]]
	button $f.info -text "Info" -command [list LWDAQ_info_button $name]
	pack $f.state $f.counter $f.acquire $f.loop \
		$f.stop $f.write $f.read $f.info \
		-side left -expand 1
	set info(state_label) $info(window).buttons.state
	
	# Create a frame for the image and configuration parameters.
	set f [frame $w.ic]
	pack $f -side top -fill x

	# Create the image display frame, label, and photo widget. Bind the image 
	# inspector routine to the display widget.
	set ff [frame $f.i]
	pack $ff -side left -fill y
	image create photo $info(photo)
	set info(image_display) $ff.image
	label $info(image_display) -image $info(photo)
	pack $info(image_display) -side left
	bind $info(image_display) \
		<Double-ButtonPress> \
		[list LWDAQ_instrument_closeup %x %y $name]
	
	# Create the configuration frame and populate with configuration array.
	set ff [frame $f.c]
	pack $ff -side right -fill y
	set config_list [array names config]
	set config_list [lsort -dictionary $config_list]
	foreach c $config_list {
		label $ff.l$c -text $c -anchor w
		entry $ff.e$c -textvariable LWDAQ_config_$name\($c) \
			-relief sunken -bd 1 -width $LWDAQ_Info(instrument_entry_width)
		grid $ff.l$c $ff.e$c -sticky news
	}

	# Call the instrument's controls creation routine, if it exists.
	if {[info commands LWDAQ_controls_$name] != ""} {
		LWDAQ_controls_$name
	}

	# Make the text output window. We don't enable text undo because this gets
	# us into trouble when we write a lot of text to the instrument window while
	# running for a long time.
	set info(text) [LWDAQ_text_widget $w 90 10 1 1]

	return $w
}

#
# LWDAQ_close closes the window of the named instrument.
#
proc LWDAQ_close {name} {
	upvar #0 LWDAQ_info_$name info
	catch {destroy $info(window)}
	return ""
}

#
# LWDAQ_instrument_save saves instrument settings to a settings file in the
# LWDAQ configuration directory, so they will be loaded automatically when LWDAQ is
# next launched, or when a new LWDAQ is spawned. There is one parameter we don't
# want to save or read back: the name of the data image, which is something that
# cannot persist from one launch of LWDAQ to the next. It returns the name of the
# settings file.
#
proc LWDAQ_instrument_save {name} {
	global LWDAQ_Info 
	upvar LWDAQ_info_$name info
	upvar LWDAQ_config_$name config

	if {![info exists info]} {error "No such instrument \"$name\"."}
	
	set fn [file join $LWDAQ_Info(config_dir) "$name\_Settings.tcl"]
	set f [open $fn w]

	set vlist [array names info]
	foreach v $vlist {
		puts $f "set LWDAQ_info_$name\($v) \"$info($v)\""
	}
	set vlist [array names config]
	foreach v $vlist {
		if {$v == "memory_name"} {continue}
		puts $f "set LWDAQ_config_$name\($v) \"$config($v)\""
	}

	close $f
	return $fn
}

#
# LWDAQ_instrument_unsave deletes a perviously-saved instrument settings file,
# if one exists. It returns the name of the settings file that was deleted, or
# an empty string if no file was found.
#
proc LWDAQ_instrument_unsave {name} {
	global LWDAQ_Info 

	set fn [file join $LWDAQ_Info(config_dir) "$name\_Settings.tcl"]
	if {[file exists $fn]} {
		file delete $fn
		return $fn
	} {
		return ""
	}
}

#
# LWDAQ_instrument_closeup deduces column, row, and intensity of the pixel
# at the tip of our mouse pointer when we double-click on an image in any
# of the LWDAQ instruments. It prints the column, row, and intensity to 
# the instrument's text window, which we assume exists or else the 
# inspector routine would not have been called. This routine is bound to the
# double-press button event within the instrument image displays. If the
# Viewer instrument is open, a region around the pixel will be displayed 
# and zoomed so we can see detail. The routine calls Viewer routines to
# accomplish the crop and zoom.
#
proc LWDAQ_instrument_closeup {x y name} {
	upvar LWDAQ_config_$name config
	upvar LWDAQ_info_$name info
	upvar LWDAQ_info_Viewer vinfo
	upvar LWDAQ_config_Viewer vconfig
	
	# Check that the image named in the instrument memory name field does
	# in fact exists.
	if {[lwdaq_image_exists $config(memory_name)] == ""} {
		LWDAQ_print $info(text) "ERROR: Double clicked for image details,\
			but image \"$config(memory_name)\" does not exist."
		return ""
	}
	
	# Get the image column and row.
	set zoom [expr 1.0 * $info(zoom) * [LWDAQ_get_lwdaq_config display_zoom]]
	if {$zoom < 1} {set zoom [expr 1.0/round(1/$zoom)]} {set zoom [expr round($zoom)]}
	set xi [expr round(1.0*($x - 4)/$zoom)] 
	set yi [expr round(1.0*($y - 4)/$zoom)]
	
	# Get the pixel intensity.
	set intensity [LWDAQ_image_pixels $config(memory_name) $xi $yi $xi $yi]
	set intensity [string trim $intensity]
	
	# If the Viewer panel is open, copy the image, set its analysis bounds to be
	# a smaller rectangle centered upon the pixel, crop the image to these
	# bounds, and display in the Viewer panel. To determine the width and height
	# of the cropped image, we use the Viewer's closeup width and height
	# parameters. We are going to replace the local Viewer image with a new
	# image, thus deleting the previous one from memory.
	if {[winfo exists $vinfo(window)]} {
		set wext [expr $vconfig(closeup_width) / 2]
		set hext [expr $vconfig(closeup_height) / 2]
		set vconfig(memory_name) \
			[lwdaq_image_manipulate $config(memory_name) copy \
			-left [expr $xi-$wext] \
			-top [expr $yi-$hext] \
			-right [expr $xi+$wext] \
			-bottom [expr $yi+$hext] \
			-name $config(memory_name)_Detail]
		lwdaq_image_manipulate $vconfig(memory_name) crop -replace 1
		LWDAQ_zoom_Viewer
	}
	
	# Print message to instrument window reporting pixel details.
	if {[winfo exists $vinfo(window)]} {
		LWDAQ_print $info(text) "Pixel: column=$xi row=$yi intensity=$intensity.\
			Closeup drawn in Viewer Instrument."
	} else {
		LWDAQ_print $info(text) "Pixel: column=$xi row=$yi intensity=$intensity.\
			Open Viewer Instrument to get closeup."
	}
	
	return ""
}

