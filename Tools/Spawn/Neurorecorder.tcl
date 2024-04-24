# Neurorecorder.tcl, a LWDAQ Tool
#
# Copyright (C) 2007-2024 Kevan Hashemi, Open Source Instruments Inc.
#
# The Neurorecorder records signals from Subcutaneous Transmitters manufactured
# by Open Source Instruments. For detailed help, see:
#
# http://www.opensourceinstruments.com/Electronics/A3018/Neurorecorder.html
#
# The Neurorecorder stores telemetry data to NDF (Neuroscience Data Format) files.
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
# 
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <https://www.gnu.org/licenses/>.
#

#
# Neurorecorder_init creates the info and config arrays and the images the
# Neurorecorder uses to hold data in memory. The config array is available
# through the Config button but the info array is private. 
#
proc Neurorecorder_init {} {
#
# Here we declare the names of variables we want defined at the global scope.
# Such variables may exist before this procedure executes, and they will endure
# after the procedure concludes. The "upvar #0" assigns a local name to a global
# variable. After the following line, we can, for the duration of this
# procedure, refer to the global variable "Neurorecorder_info" with the local
# name "info". The Neurorecorder_info variable happens to be an array with a
# bunch of "elements". Each element has a name and a value. Here we will refer
# to the "name" element of the "Neurorecorder_info" array with info(name).
#
	upvar #0 Neurorecorder_info info
	upvar #0 Neurorecorder_config config
	global LWDAQ_Info
#
# We initialise the Neurorecorder with LWDAQ_tool_init. Because this command
# begins with "LWDAQ" we know that it's one of those in the LWDAQ command
# library. We can look it up in the LWDAQ Command Reference to find out more
# about what it does.
#
	LWDAQ_tool_init "Neurorecorder" "167"
#
# If a graphical tool window already exists, we abort our initialization.
#
	if {[winfo exists $info(window)]} {
		return ""
	}
#
# We start setting intial values for the private display and control variables.
#
	set info(record_control) "Idle"
	set info(record_control_label) "none"
#
# Recording data acquisition parameters.
#
	set info(alt_options) "A3032 A3038 A3042"
	set info(A3032_payload) "16"
	set info(A3038_payload) "16"
	set info(A3042_payload) "2"
	set info(A3032_coordinates) "\
		0 0 2  0 8 2  0 16 2 \
		8  0 2  8 8 2  8 16 2 \
		16 0 2 16 8 2 16 16 2 \
		24 0 2 24 8 2 24 16 2 \
		32 0 2 32 8 2 32 16 2"
	set info(A3038_coordinates) "\
		0  0 2 0  12 2  0 24 2 \
		12 0 2 12 12 2 12 24 2 \
		24 0 2 24 12 2 24 24 2 \
		36 0 2 36 12 2 36 24 2 \
		48 0 2 48 12 2 48 24 2 \
		-1 -1 -1"
	set info(A3042_coordinates) "\
		0 0  2 16  0 2 32  0 2 48  0 2 \
		0 8  2 16  8 2 32  8 2 48  8 2 \
		0 16 2 16 16 2 32 16 2 48 16 2 \
		0 24 2 16 24 2 32 24 2 48 24 2"
	set config(tracker_coordinates) ""
	set config(tracker_background) ""
#
# The recorder buffer variable holds data that we download from the 
# receiver but are unable to write to disk because the recording file
# is locked. 
#
	set info(rbuff) ""
	set config(max_rbuff) "20000000"
#
# Properties of data messages.
#
	set info(core_message_length) 4
#
# Properties of clock messages. The clock period is in clock ticks, where each
# tick is one period of 32.768 kHz. The clock frequency is 128 SPS.
#
	set info(clock_id) 0
	set info(clock_period) 256
#
# Files the Neurorecorder uses to record.
#
	set config(record_dir) "NONE"
	set config(record_file) "M0000000000.ndf"
#
# Parameters we will copy to the Receiver Instrument when we start recording.
#
	set config(daq_ip_addr) "10.0.0.37"
	set config(daq_channels) "*"
	set config(daq_driver_socket) "1"
#
# The verbose flag tells the Neurorecorder to print more process information in
# its text window.
#
	set config(verbose) 0
# 
# Timing constants for the recorder, in seconds.
#
	set config(record_end_time) 0
	set config(record_lag) 0.2
	set config(record_start_clock) 0
#
# Each new NDF file we create will have a metadata string of the following
# size in characters.
#
	set config(ndf_metadata_size) 20000
# 
# The NDF file name will start with a prefix, which is by default the letter
# "M" but which we can change here.
#
	set config(ndf_prefix) "M"
#
# The metadata header is a string the we append to the metadata of a new
# archive. We can edit the header in the metadata header window.
#
	set info(metadata_header) ""
	set info(metadata_header_window) "$info(window)\.metadataheader"
#
# The recorder_customization string allows us to override default values for
# data receiver parameters such as coil coordinates.
#
	set config(recorder_customization) ""
	set info(customization_window) "$info(window)\.customization"
#
# When autocreate is greater than zero, it gives the number of seconds after
# which we should stop using one archive and create another one. We find the
# Neurorecorder to be efficient with archives hundreds of megabytes long, so
# autocreate can be set to 43200 seconds with no drop in performance, leading to
# twelve hours of data in one file.
#
	set config(autocreate) 3600
# 
# When we create a new archive, we wait until the system clock enters a window
# of time after the start of a new second. During this time we reset the data
# receiver and name the new recording archive after the current time in seconds.
# The window must be wide enough that we are certain to notice that we are in
# the window, but narrow enough that it does not compromise synchronization of
# the recording with the system clock.
#
	set info(sync_window_ms) 30
#
# When we create a new archive, we either perform synchronization, or just
# open a new file and keep recording to disk.
#
	set config(synchronize) 1
#
# We record and play back data in intervals. Here we specify these intervals
# in seconds. The Neurorecorder translates seconds to clock messages.
#
	set config(record_interval) 0.5
	set info(clocks_per_second) 128
#
# The Neurorecorder will record events to a log, in particular warnings and
# errors generated during playback and recording.
#
	set config(log_warnings) 0
	set config(log_file) [file join \
		[file dirname $info(settings_file_name)] Neurorecorder_log.txt]
	set config(datetime_format) {%d-%b-%Y %H:%M:%S}
# 
# Some errors we don't want to write more than once to the text window, so
# we keep a copy of the most recent error to compare to.
#
	set info(previous_line) ""
#
# The recorder_error_time parameter gives us the time when the Neurorecorder
# first failed to download from the Data Receiver. A zero value means all is
# well. The message interval gives us the length of time between error reports
# to the text window.
#
	set info(recorder_error_time) 0
	set info(initial_message_interval) 10
	set info(recorder_message_interval) $info(initial_message_interval)
	set info(message_interval_multiplier) 3
#
# Colors for windows and widgets.
#
	set info(label_color) "darkgreen"
	set info(variable_bg) "lightgray"
	set info(active_color) "yellow"
	set info(error_color) "red"
	set info(start_color) "green"
	set info(inactive_color) "white"
	set info(pick_color) "orange"
#
# The Save button in the Configuration Panel allows you to save your own
# configuration parameters to disk a file called settings_file_name. This
# file was declared earlier in LWDAQ_tool_init. Now we check to see
# if there is such a file, and if so we read it in and execute the TCL
# commands it contains. Each of the commands sets an element in the 
# configuration array. Try pressing the Save button and look for the
# settings file in ./Tools/Data. You can open it and take a look.
#
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 
#
# We have file tail variables that we display in the Neurorecorder
# window. We set these now, after we have read in the saved settings.
#
	foreach n {record} {
		set info($n\_file_tail) [file tail $config($n\_file)]
	}
#
# We are done with initialization. We return a 1 to show success.
#
	return ""   
}

#
# We convert between integer seconds to the datetime format given in the 
# configuration array. If the input is in integer seconds, it gets converted
# into our datetime format. Otherwise, we convert it from datetime format
# into integer seconds if possible. We issue an error in the Neurorecorder
# window if the format is incorrect, and return the value zero.
#
proc Neurorecorder_clock_convert {datetime} {
	upvar #0 Neurorecorder_config config
	
	if {[string is integer $datetime]} {
		set newformat [clock format $datetime -format $config(datetime_format)]
	} {
		if {[catch {
			set newformat [clock scan $datetime -format $config(datetime_format)]
		} error_result]} {
			Neurorecorder_print "ERROR: Invalid clock string, \"$datetime\"."
			set newformat 0
		}
	}
	return $newformat
}

#
# Neurorecorder_configure calls the standard LWDAQ tool configuration
# routine to produce a window with an array of configuration parameters
# that the user can edit.
#
proc Neurorecorder_configure {} {
	upvar #0 Neurorecorder_config config
	upvar #0 Neurorecorder_info info
	LWDAQ_tool_configure Neurorecorder 3
}

#
# Neurorecorder_print writes a line to the text window. If the color specified
# is "verbose", the message prints only when the verbose flag is set, and in
# black. Warnings and errors are always printed in the warning and error colors.
# In addition, if the log_warnings is set, the routine writes all warnings and
# errors to the Neurorecorder log file. The print routine will refrainn from
# writing the same error message to the text window repeatedly when we set the
# color to the key word "norepeat". The routine always stores the previous line
# it writes, so as to compare in the case of a norepeat requirement. Note that
# the final print to a text window uses LWDAQ_print, which will not try to print
# to a target with a widget-style name when graphics are disabled.
#
proc Neurorecorder_print {line {color "black"}} {
	upvar #0 Neurorecorder_config config
	upvar #0 Neurorecorder_info info
	
	if {$color == "norepeat"} {
		if {$info(previous_line) == $line} {return ""}
		set color black
	}
	set info(previous_line) $line
	
	if {[regexp "^WARNING: " $line] || [regexp "^ERROR: " $line]} {
		append line " ([Neurorecorder_clock_convert [clock seconds]]\)"
		if {$config(log_warnings)} {
			LWDAQ_print $config(log_file) "$line"
		}
	}
	if {$config(verbose) \
			|| [regexp "^WARNING: " $line] \
			|| [regexp "^ERROR: " $line] \
			|| ($color != "verbose")} {
		if {$color == "verbose"} {set color black}
		LWDAQ_print $info(text) $line $color
	}
	return ""
}

#
# Neurorecorder_pick allows the user to pick a new record_directory.
#
proc Neurorecorder_pick {name {post 0}} {
	upvar #0 Neurorecorder_config config
	upvar #0 Neurorecorder_info info
	global LWDAQ_Info

	# If we call this routine from a button, we prefer to post
	# its execution to the event queue, and this we can do by
	# adding a parameter of 1 to the end of the call.
	if {$post} {
		LWDAQ_post [list Neurorecorder_pick $name]
		return ""
	}

	if {[regexp "_file" $name]} {
		set fn [LWDAQ_get_file_name 0 [file dirname [set config($name)]]]
		if {![file exists $fn]} {
			Neurorecorder_print "WARNING: File \"$fn\" does not exist."
			return $fn
		}
		set config($name) $fn
		set info($name\_tail) [file tail $fn]
		return $fn
	} 
	if {[regexp "_dir" $name]} {
		set dn [LWDAQ_get_dir_name [set config($name)]]
		if {![file exists $dn]} {
			Neurorecorder_print "WARNING: Directory \"$dn\" does not exist."
			return $dn
		}
		set config($name) $dn
		return $dn
	}
	return ""
}

#
# Neurorecorder_metadata_header returns a header string for a newly-created
# archive. The header string contains one or two xml <c> fields, which we intend
# to act as two comment fields. The first field is one we generate
# automatically. It contains the time, host, and software version. The second
# field contains the contents of the metadata header string, with white space
# removed before and after. If there are no non-whitespace characters in the
# metadata header string, we don't add the second comment, and this is the
# default when we open the Neurorecorder. We create a metadata header string by
# pressing the header button and entering and saving the string. This string
# might contain a description of our experiment, and it will be added to all
# archives we create as we record. If the receiver is an animal location
# tracker, we write to the metadata the positions of its detector coils.
#
proc Neurorecorder_metadata_header {} {
	upvar #0 Neurorecorder_info info
	upvar #0 Neurorecorder_config config
	upvar #0 LWDAQ_config_Receiver iconfig
	upvar #0 LWDAQ_info_Receiver iinfo
	global LWDAQ_Info	

	set header "<c>Created: [clock format [clock seconds]\
			-format $config(datetime_format)].\
			\nCreator: Neurorecorder $info(version),\
			LWDAQ_$LWDAQ_Info(program_patchlevel).\
			\nReceiver: $iinfo(receiver_type) with\
			firmware $iinfo(receiver_firmware).\
			\nAddress: $config(daq_ip_addr).\
			\nPlatform: $LWDAQ_Info(os).</c>\n"
	append header "<payload>$iconfig(payload_length)</payload>\n"
	if {[lsearch $info(alt_options) $iinfo(receiver_type)] >= 0} {
		set xyz ""
		foreach {x y z} $config(tracker_coordinates) {
			append xyz "$x $y $z "
		}
		append header "<alt>[string trim $xyz]</alt>\n"
		append header "<alt_bg>[string trim $config(tracker_background)]</alt_bg>\n"
	}
	if {[string trim $info(metadata_header)] != ""} {
		append header "<c>[string trim $info(metadata_header)]</c>\n"
	}

	return $header
}

#
# Neurorecorder_metadata_header_edit displays the recording header in a window.
# We can edit the header and change the codes. We save the new header string by
# pressing the save button. We cancel by closing the window.
#
proc Neurorecorder_metadata_header_edit {} {
	upvar #0 Neurorecorder_info info
	upvar #0 Neurorecorder_config config
	
	# Create a new top-level text window
	set w $info(metadata_header_window)
	if {[winfo exists $w]} {
		raise $w
		return ""
	} {
		toplevel $w
		wm title $w "Recording Metadata Header"
		LWDAQ_text_widget $w 60 20
		LWDAQ_enable_text_undo $w.text	
	}

	# Create the Save button.
	frame $w.f
	pack $w.f -side top
	button $w.f.save -text "Save" -command Neurorecorder_metadata_header_save
	pack $w.f.save -side left
	
	# Print the metadata to the text window.
	LWDAQ_print $w.text $info(metadata_header)

	return ""
}

#
# Neurorecorder_metadata_header_save takes the contents of the metadata header
# edit text window and saves it to the metadata header string.
#
proc Neurorecorder_metadata_header_save {} {
	upvar #0 Neurorecorder_info info
	upvar #0 Neurorecorder_config config

	set w $info(metadata_header_window)
	if {[winfo exists $w]} {
		set info(metadata_header) [string trim [$w.text get 1.0 end]]
	} {
		Neurorecorder_print "ERROR: Cannot find metadata header edit window."
	}
	return $info(metadata_header)
}

#
# Neurorecorder_customization_edit displays the recording customization string,
# allows us to edit, and to save. We cancel by closing the window.
#
proc Neurorecorder_customization_edit {} {
	upvar #0 Neurorecorder_info info
	upvar #0 Neurorecorder_config config
	
	# Create a new top-level text window
	set w $info(customization_window)
	if {[winfo exists $w]} {
		raise $w
		return ""
	} {
		toplevel $w
		wm title $w "Recorder Customization String"
		LWDAQ_text_widget $w 60 20
		LWDAQ_enable_text_undo $w.text	
	}

	# Create the Save button.
	frame $w.f
	pack $w.f -side top
	button $w.f.save -text "Save" -command Neurorecorder_customization_save
	pack $w.f.save -side left
	
	# Print the metadata to the text window.
	LWDAQ_print $w.text $config(recorder_customization)

	return ""
}

#
# Neurorecorder_customization_save takes the contents of the customization string
# edit text window and saves it to the recorder customization string.
#
proc Neurorecorder_customization_save {} {
	upvar #0 Neurorecorder_info info
	upvar #0 Neurorecorder_config config

	set w $info(customization_window)
	if {[winfo exists $w]} {
		set config(recorder_customization) [string trim [$w.text get 1.0 end]]
	} {
		Neurorecorder_print "ERROR: Cannot find customization edit window."
	}
	return $config(recorder_customization)
}

#
# Neurorecorder_command handles the various control commands generated by the
# record buttons. It refers to the LWDAQ event queue with the global
# LWDAQ_Info(queue_events) variable. The event queue is LWDAQ's way of getting
# several independent processes to run at the same time without coming into
# conflict when they access shared variables and shared data acquisition
# hardware. The TCL interpreter does provide several forms of multi-tasking, but
# none of them are adequate for our purposes. 
#
proc Neurorecorder_command {action} {
	upvar #0 Neurorecorder_info info
	global LWDAQ_Info

	set event_executing [string match "Neurorecorder_record*"\
		$LWDAQ_Info(current_event)]
	set event_pending 0
	foreach event $LWDAQ_Info(queue_events) {
		if {[string match "Neurorecorder_record*" $event]} {
			set event_pending 1
		}
	}

	if {$action != $info(record_control)} {
		if {!$event_executing} {
			set info(record_control) $action
			if {!$event_pending} {
				if {$action != "Stop"} {
					LWDAQ_post Neurorecorder_record
				} {
					set info(record_control) "Idle"
				}
			}
		} {
			if {$action != "Stop"} {
				LWDAQ_post [list Neurorecorder_command $action]	
			} {
				set info(record_control) $action
			}
		}
	}
	
	return "$action"
}

#
# Neurorecorder_set_receiver configures the Receiver Instrument for recording
# from a particular type of receiver.
#
proc Neurorecorder_set_receiver {version} {
	upvar #0 Neurorecorder_info info
	upvar #0 Neurorecorder_config config
	upvar #0 LWDAQ_config_Receiver iconfig
	upvar #0 LWDAQ_info_Receiver iinfo
	global LWDAQ_Info

	# Set data acquisition parameters based upon receiver type.
	switch $version {
		"A3018" {
			set iconfig(payload_length) 0
			set config(tracker_coordinates) ""
			set config(tracker_background) ""
			Neurorecorder_print "Detected: Data Receiver (A3018),\
				applying driver socket, ignoring channel selection."
		}
		"A3027" {
			set iconfig(payload_length) 0
			set config(tracker_coordinates) ""
			Neurorecorder_print "Detected: Octal Data Receiver (A3027),\
				applying driver socket, ignoring channel selection."
			set config(tracker_background) ""
		}
		"A3032" {
			set iconfig(payload_length) $info(A3032_payload)
			set config(tracker_coordinates) $info(A3032_coordinates)
			Neurorecorder_print "Detected: Animal Location Tracker (A3032),\
				applying driver socket, ignoring channel selection."
			set config(tracker_background) "0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0"
		}
		"A3038" {
			set iconfig(payload_length) $info(A3038_payload)
			set config(tracker_coordinates) $info(A3038_coordinates)
			Neurorecorder_print "Detected: Animal Location Tracker (A3038),\
				applying channel selection, ignoring driver socket."
			set config(tracker_background) "0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0"
		}
		"A3042" {
			set iconfig(payload_length) $info(A3042_payload)
			set config(tracker_coordinates) $info(A3042_coordinates)
			Neurorecorder_print "Detected: Telemetry Control Box (A3042),\
				applying channel selection, ignoring driver socket."
		}
		default {
			set iconfig(payload_length) 0
			set config(tracker_coordinates) ""
			Neurorecorder_print "WARNING: Unknown receiver version \"$version\"."
			set config(tracker_background) ""
		}
	}

	# User can specify their own tracker coil coordinates in the recorder
	# customization string.
	set alt [lindex [LWDAQ_xml_get_list $config(recorder_customization) "alt"] end]
	if {$alt != ""} {
		Neurorecorder_print "Found coil coordinates in recorder customization string."
		if {[catch {
			set count 0
			foreach {x y z} $alt {
				foreach a {x y z} {
					if {![string is double -strict [set $a]]} {
						error "invalid coordinate \"[set $a]\""
					}
				}
				incr count
			}
			if {$count != $iconfig(payload_length)} {
				error "found $count coordinates, need $iconfig(payload_length)"
			}		
			Neurorecorder_print "Will write custom coil coordinates to metadata."
			set config(tracker_coordinates) $alt
		} message]} {
			Neurorecorder_print "ERROR: $message, check customization string."
			Neurorecorder_print "WARNING: Will write default coordinates to metadata."
		}
	}

	# User can specify their own background power values for their tracker in
	# the customization string.
	set alt_bg [lindex [LWDAQ_xml_get_list $config(recorder_customization) "alt_bg"] end]
	if {$alt_bg != ""} {
		Neurorecorder_print "Found background powers in recorder customization string."
		if {[catch {
			set count 0
			foreach p $alt_bg {
				if {![string is double -strict $p]} {
					error "invalid background power \"$p\""
				}
				incr count
			}
			if {$count != $iconfig(payload_length)} {
				error "found $count background powers, need $iconfig(payload_length)"
			}		
			Neurorecorder_print "Will write custom background powers to metadata."
			set config(tracker_background) $alt_bg
		} message]} {
			Neurorecorder_print "ERROR: $message, check customization string."
			Neurorecorder_print "WARNING: Will write default background to metadata."
		}
	}
	
	return ""
}

#
# Neurorecorder_record manages the recording of data to archive files. It is the
# recorder's execution procedure. It calls the Receiver Instrument to produce a
# block of data with a fixed number of clock messages. It stores these messages
# to disk. If the control variable, config(record_control), is "Start", the
# procedure posts itself again with control "Record". The recorder calculates
# the number of clock messages from the record_interval time, which is in
# seconds, and is available in the Neurorecorder panel.
#
proc Neurorecorder_record {{command ""}} {
	upvar #0 Neurorecorder_info info
	upvar #0 Neurorecorder_config config
	upvar #0 LWDAQ_config_Receiver iconfig
	upvar #0 LWDAQ_info_Receiver iinfo
	global LWDAQ_Info

	# Make sure we have the info array.
	if {![array exists info]} {return ""}

	# Check if we have an overriding command passed with the call to this
	# procedure, as we might from a LWDAQ configuration script.
	if {$command != ""} {set info(record_control) $command}
	
	# If a global reset is going on, go to idle state.
	if {$LWDAQ_Info(reset)} {
		set info(record_control) "Idle"
		set info(rbuff) ""
		return ""
	}
	
	# If we have closed the Neurorecorder window when we are running with graphics,
	# this indicates that the user wants all recording to stop and the Neurorecorder
	# to close and reset.
	if {$info(gui) && ![winfo exists $info(window)]} {
		array unset info
		array unset config
		return ""
	}
	
	# If Stop, we move to Idle and return.
	if {$info(record_control) == "Stop"} {
		Neurorecorder_print "Stopped recording at\
			[Neurorecorder_clock_convert [clock seconds]]."
		Neurorecorder_print "Press Resume within the next few seconds to\
			re-start without loss."
		set info(record_control) "Idle"
		return ""
	}
	
	# If PickDir we choose a directory in which to create new archives.
	if {$info(record_control) == "PickDir"} {
		LWDAQ_set_bg $info(record_control_label) $info(pick_color)
		LWDAQ_update
		Neurorecorder_pick record_dir
		Neurorecorder_print "Files will be written to $config(record_dir)."
		LWDAQ_set_bg $info(record_control_label) $info(inactive_color)
		LWDAQ_update
	}
	
	# The Resume instruction is the same as Record, apart from the fact that we
	# announce the resumption of recording. We update the control variable, but
	# this will not immediately be visible.
	if {$info(record_control) == "Resume"} {
		Neurorecorder_print "Resumed recording at\
			[Neurorecorder_clock_convert [clock seconds]]."
		set info(record_control) "Record"
	}
	
	# If we are going to interact with the data receiver at all, apply the
	# Neurorecorder's receiver settings.
	if {($info(record_control) == "Start") \
		|| ($info(record_control) == "Record")} {
		set iconfig(daq_ip_addr) $config(daq_ip_addr)
		set iconfig(daq_channels) $config(daq_channels)
		set iconfig(daq_driver_socket) $config(daq_driver_socket)
	}


	# If Start or upon autocreate, we create a new archive using the record start clock
	# value as the timestamp in the file name, and the ndf_prefix as the the beginning
	# of the name.
	if {($info(record_control) == "Start") || \
		(($config(record_end_time) >= $config(autocreate)) \
			&& ($config(autocreate) > 0))} {

		# Turn the recording label to the start color.
		LWDAQ_set_bg $info(record_control_label) $info(start_color)
		
		# Clear the buffer.
		set info(rbuff) ""

		# If the synchronization flag is set, or if we are starting a new recording,
		# we wait until a new second begins so as to make the file time match the 
		# time we reset the data receiver.
		set ms_start [clock milliseconds]
		if {($info(record_control) == "Start") || $config(synchronize)} {
			while {[expr [clock milliseconds] % 1000] > $info(sync_window_ms)} {
				LWDAQ_support
				if {$info(record_control) == "Stop"} {
					set info(record_control) "Idle"
					if {[winfo exists $info(window)]} {
						LWDAQ_set_bg $info(record_control_label) $info(inactive_color)
					}
					return ""
				}
			}
		}
		set ms_stop [clock milliseconds]
		
		# Set the timestamp for the new file, with resolution one second.
		set config(record_start_clock) [clock seconds]
		
		# If the synchronize flag is set, or if we are starting a new recording,
		# reset the data receiver.
		if {($info(record_control) == "Start") || $config(synchronize)} {
			set info(recorder_error_time) 0
			set info(recorder_message_interval) $info(initial_message_interval)
			set result [LWDAQ_reset_Receiver]
			set ms_reset [clock milliseconds]		
			if {[LWDAQ_is_error_result $result]} {
				Neurorecorder_print "$result"
				set info(record_control) "Idle"
				LWDAQ_set_bg $info(record_control_label) $info(inactive_color)
				return ""
			}
			Neurorecorder_set_receiver $iinfo(receiver_type)
		}

		# Restore the recording label to the inactive color.
		LWDAQ_set_bg $info(record_control_label) $info(inactive_color)

		# Check that the destination directory exists.
		if {![file exists $config(record_dir)]} {
			Neurorecorder_print "ERROR: Recording directory \"$config(record_dir)\"\
				does not exist."
			Neurorecorder_print "SUGGESTION: Press PickDir to\
				specify a recording directory."
			set info(record_control) "Idle"
			return ""
		}

		# Create and set up the new recording file.
		set config(record_file) [file join $config(record_dir) \
			"$config(ndf_prefix)$config(record_start_clock)\.ndf"]
		set info(record_file_tail) [file tail $config(record_file)]
		if {[file exists $config(record_file)]} {
			Neurorecorder_print "ERROR: File \"$info(record_file_tail)\"\
				already exists, recording directory conflict."
			Neurorecorder_print "SUGGESTION: Make sure all Neurorecorders use\
				unique recording directories."
			set info(record_control) "Idle"
			return ""
		}
		if {[catch {
			LWDAQ_ndf_create $config(record_file) $config(ndf_metadata_size)	
			LWDAQ_ndf_string_write $config(record_file) [Neurorecorder_metadata_header] 
		} error_message]} {
			Neurorecorder_print "ERROR: $error_message\."
			Neurorecorder_print "SUGGESTION: Your disk drive may be full,\
				make space on the drive and try again."
			set info(record_control) "Idle"
			LWDAQ_set_bg $info(record_control_label) $info(inactive_color)
			return ""		
		}
		if {($info(record_control) == "Start") || $config(synchronize)} {
			Neurorecorder_print "Synchronization:\
				Waiting period [expr $ms_stop-$ms_start] ms,\
				reset delay [expr $ms_reset-$ms_stop] ms."
			Neurorecorder_print "Created: Synchronized archive\
				[file tail $config(record_file)] at\
				[Neurorecorder_clock_convert [clock seconds]]." purple
		} {
			Neurorecorder_print "Created: Unsynchronized archive\
				[file tail $config(record_file)] at\
				[Neurorecorder_clock_convert [clock seconds]]." purple
		}
		set config(record_end_time) 0
		
		set info(record_control) "Record"
	}

	# If Record, we attempt to download data from the data receiver and record
	# it to disk. If the download attempt fails, we will still try to write any
	# buffered data to disk. If the download succeeds, but the write failes, we
	# buffer the downloaded data.
	if {$info(record_control) == "Record"} {
		# If we have already caught up with our recording, we don't bother
		# trying to acquire more data because we'll be occupying the LWDAQ
		# process and the LWDAQ driver as well, for no good reason. Instead, we
		# post the recorder to the end of the event queue.
		if {$iinfo(acquire_end_ms) > [clock milliseconds] - 1000*$config(record_lag)} {		
			LWDAQ_post Neurorecorder_record end
			return ""
		}

		# If we are not dealing with no errors, set the record label to the
		# active color.
		if {($info(recorder_error_time) == 0) \
				&& ([string length $info(rbuff)] == 0)} {
			LWDAQ_set_bg $info(record_control_label) $info(active_color)
		}
		
		# If the Receiver Instrument happens to be looping, stop it.
		if {$iinfo(control) == "Loop"} {set iinfo(control) "Stop"}

		# Set the number of clocks we want to download using the Receiver
		# Instrument. The Receiver Instrument will giveus exactly this number of
		# clocks, unless there is an error.
		set iconfig(daq_num_clocks) \
			[expr round($config(record_interval) * $info(clocks_per_second))]

		# We are going to make single attempts to contact the data receiver and
		# download a block of messages, regardless of the value of
		# LWDAQ_Info(max_daq_attempts).
		set saved_max_daq_attempts $LWDAQ_Info(max_daq_attempts)
		set LWDAQ_Info(max_daq_attempts) 1	
		
		# If the Receiver Panel is not open, we disable Receiver Instrument
		# analysis. We don't want to use processing time drawing the signals
		# in the Receiver Instrument image when the image is not being 
		# displayed.
		if {![winfo exists ".receiver"]} {
			set iconfig(analysis_enable) 0
		}
		
		# Download a block of messages from the data receiver into a LWDAQ
		# image, the name of which is $iconfig(memory_name). The Receiver
		# Instrument returns a string that describes the data block, or reports
		# an error.
		set daq_result [LWDAQ_acquire Receiver]
		
		# Restore the global max_daq_attempts variable.
		set LWDAQ_Info(max_daq_attempts) $saved_max_daq_attempts
		
		# If the attempt to download encountered an error, we keep track of when
		# we last dealt with an error, so that we do not attempt to correct the
		# error too often. If the error is corrupted data, we are going to be
		# resetting the data receiver.
		if {[LWDAQ_is_error_result $daq_result]} {
			set print_error_and_reset 0
			if {($info(recorder_error_time) == 0)} {
				set print_error_and_reset 1
				set info(recorder_error_time) [clock seconds]
				set info(recorder_message_interval) $info(initial_message_interval)
			} elseif {[clock seconds] - $info(recorder_error_time) \
				> $info(recorder_message_interval)} {
				set print_error_and_reset 1
				set info(recorder_message_interval) \
					[expr $info(recorder_message_interval) \
					* $info(message_interval_multiplier)]
			}
			if {$print_error_and_reset} {
				LWDAQ_set_bg $info(record_control_label) $info(error_color)
				Neurorecorder_print "$daq_result"
				if {[regexp "corrupted" $daq_result]} {
					Neurorecorder_print "WARNING: Corrupted data, resetting receiver."
					set reset_result [LWDAQ_reset_Receiver]
					if {[LWDAQ_is_error_result $reset_result]} {
						LWDAQ_print "ERROR: $reset_result"
					}
				}
			}
		} 
		
		# If we did not encounter an error, but the previous attempt failed, we now
		# announce that we are resuming recording.
		if {![LWDAQ_is_error_result $daq_result] \
				&& ($info(recorder_error_time) != 0)} {
			Neurorecorder_print "WARNING: Download resumed after interruption of\
				[expr [clock seconds] - $info(recorder_error_time)] s."
			set info(recorder_error_time) 0
			set info(recorder_message_interval) $info(initial_message_interval)
		}
		
		# If our recorder buffer is not empty, we must be dealing with a problem
		# writing data to disk, so set a flag.
		if {$info(rbuff) != ""} {
			set prev_disk_error 1
		} {
			set prev_disk_error 0
		}
		
		# If we did not encounter an error during data aquisition from the
		# receiver, append the new data to our buffer. If our recording buffer
		# has overflowed, we discard the new data and print a warning. If the
		# new data contains errors, print a warning.
		if {![LWDAQ_is_error_result $daq_result]} {
			set message_length \
				[expr $info(core_message_length) + $iconfig(payload_length)]
			if {[lwdaq_image_exists $iconfig(memory_name)] != ""} {
				set new [lwdaq_image_contents $iconfig(memory_name) \
						-truncate 1 -data_only 1 -record_size $message_length]
				if {[string length $info(rbuff)] < $config(max_rbuff)} {
					append info(rbuff) $new
					if {[string length $info(rbuff)] >= $config(max_rbuff)} {
						Neurorecorder_print "WARNING: Recording buffer overflow,\
							[format %.1f [expr [string length $info(rbuff)]/1000000]] MB\
							waiting to be written to disk."	
					} 
				}
			} {
				set new ""
			}
			Neurorecorder_print "Received [string length $new] bytes,\
				buffer contains [string length $info(rbuff)] bytes." verbose
			scan [lwdaq_receiver $iconfig(memory_name) \
				"-payload $iconfig(payload_length) clocks 0"] %d%d%d%d \
				num_errors num_clocks num_messages first_index
			if {$num_errors > 0} {
				Neurorecorder_print "WARNING: Encountered $num_errors errors\
					in received interval."
			}
		}
		
		# If our recording buffer is not empty, try to write the data to disk. If our
		# write succeeds, we empty the buffer. If our write fails with a locked file
		# error, we set the recording label to the error color. If our write fails with
		# some other error, abort recording.
		if {$info(rbuff) != ""} {
			if {[catch {
				LWDAQ_ndf_data_append $config(record_file) $info(rbuff)
				if {$prev_disk_error} {
					Neurorecorder_print "WARNING: Wrote\
						[string length $info(rbuff)]\
						bytes to [file tail $config(record_file)]\
						after previous write failure."
				} {
					Neurorecorder_print "Wrote [string length $info(rbuff)]\
						bytes to disk." verbose
				}
				set info(rbuff) ""
			} error_message]} {
				if {[regexp "file locked" $error_message]} {
					if {!$prev_disk_error} {		
						LWDAQ_set_bg $info(record_control_label) $info(error_color)
						Neurorecorder_print "WARNING: Could not write to\
							[file tail $config(record_file)],\
							file locked, buffering data."
					}
				} {
					Neurorecorder_print "ERROR: $error_message\."
					set info(rbuff) ""
					set info(record_control) "Idle"
					LWDAQ_set_bg $info(record_control_label) $info(inactive_color)
					return ""
				}
			}
		}
		
		# Trim the text window to a maximum number of lines.
		if {[winfo exists $info(text)]} {
			if {[$info(text) index end] > 1.2 * $LWDAQ_Info(num_lines_keep)} {
				$info(text) delete 1.0 "end [expr 0 - $LWDAQ_Info(num_lines_keep)] lines"
			}
		}

		# Increment the record time, on the assumption that we obtained the 
		# data we wanted.
		set config(record_end_time) \
			[expr $config(record_end_time) + $config(record_interval)]
			
		# If we are not dealing with no errors, set the record label to the
		# inactive color.
		if {($info(recorder_error_time) == 0) \
				&& ([string length $info(rbuff)] == 0)} {
			LWDAQ_set_bg $info(record_control_label) $info(inactive_color)
		}			
		
		# We continue recording by posting the record process to the LWDAQ event queue.
		LWDAQ_post Neurorecorder_record end
		return ""
	}

	# We are done and Idle.
	set info(record_control) "Idle"
	return ""
}

#
# Neurorecorder_open creates the Neurorecorder window, with all its buttons,
# boxes, and displays. It uses routines from the TK library to make the frames
# and widgets. To make sense of what the procedure is doing, look at the
# features in the Neurorecorder from top-left to bottom right. That's the order
# in which we create them in the code. Frames enclose rows of buttons, labels,
# and entry boxes. 
proc Neurorecorder_open {} {
	upvar #0 Neurorecorder_config config
	upvar #0 Neurorecorder_info info
	global LWDAQ_Info

	# Open the tool window. If we get an empty string back from the opening
	# routine, something has gone wrong, or a window already exists for this
	# tool, so we abort.
	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
	
	# Get on with creating the display in the tool's frame or window.
	set f $w.record
	frame $f
	pack $f -side top -fill x

	set f $w.record.a
	frame $f
	pack $f -side top -fill x

	label $f.control -textvariable Neurorecorder_info(record_control) \
		-fg blue -width 8
	set info(record_control_label) $f.control
	pack $f.control -side left

	foreach a {Start Resume Stop PickDir} {
		set b [string tolower $a]
		button $f.$b -text $a -command "Neurorecorder_command $a"
		pack $f.$b -side left -expand yes
	}
	
	button $f.signals -text "Receiver" -command {
		set LWDAQ_config_Receiver(analysis_enable) 1
		LWDAQ_post "LWDAQ_open Receiver"
	}
	pack $f.signals -side left -expand yes

	button $f.stimulator -text "Stimulator" -command {
		LWDAQ_run_tool Stimulator
	}
	pack $f.stimulator -side left -expand yes

	button $f.conf -text "Configure" -command "Neurorecorder_configure"
	pack $f.conf -side left -expand yes
	button $f.help -text "Help" -command "LWDAQ_tool_help Neurorecorder"
	pack $f.help -side left -expand yes
	checkbutton $f.synch -variable \
		Neurorecorder_config(synchronize) -text "Synchronize"
	pack $f.synch -side left -expand yes

	set f $w.record.b
	frame $f
	pack $f -side top -fill x

	label $f.a -text "Receiver:" -anchor w -fg $info(label_color)
	label $f.rt -textvariable LWDAQ_info_Receiver(receiver_type)
	pack $f.a $f.rt -side left

	label $f.ipl -text "ip_addr:" -fg $info(label_color)
	entry $f.ipe -textvariable Neurorecorder_config(daq_ip_addr) -width 14
	pack $f.ipl $f.ipe -side left -expand yes

	label $f.sl -text "driver_sckt:" -fg $info(label_color)
	entry $f.se -textvariable Neurorecorder_config(daq_driver_socket) -width 2
	pack $f.sl $f.se -side left -expand yes

	label $f.lchannels -text "Select:" -anchor e -fg $info(label_color)
	entry $f.echannels -textvariable Neurorecorder_config(daq_channels) -width 20
	pack $f.lchannels $f.echannels -side left -expand yes

	label $f.fvl -text "firmware:" -fg $info(label_color)
	label $f.fvd -textvariable LWDAQ_info_Receiver(receiver_firmware) -width 2
	pack $f.fvl $f.fvd -side left -expand yes

	set f $w.record.c
	frame $f
	pack $f -side top -fill x

	label $f.a -text "Archive:" -anchor w -fg $info(label_color)
	pack $f.a -side left
	
	label $f.b -textvariable Neurorecorder_info(record_file_tail) \
		-width 20 -bg $info(variable_bg)
	pack $f.b -side left -expand yes
	
	button $f.customize -text "Customize" \
		-command Neurorecorder_customization_edit
	pack $f.customize -side left -expand yes 
	
	button $f.metadata -text "Header" \
		-command Neurorecorder_metadata_header_edit
	pack $f.metadata -side left -expand yes
	
	label $f.lac -text "Length (s):" -fg $info(label_color) 
	pack $f.lac -side left -expand yes
	label $f.eac -textvariable Neurorecorder_config(record_end_time) -width 6
	pack $f.eac -side left -expand yes
	
	label $f.le -text "Autocreate (s):" -fg $info(label_color)
	pack $f.le -side left -expand yes
	entry $f.ee -textvariable Neurorecorder_config(autocreate) -width 6
	pack $f.ee -side left -expand yes

	set info(text) [LWDAQ_text_widget $w 90 7 1 1]
	
	return "$w"
}

#
# Neurorecorder_close closes the Neurorecorder and deletes its configuration and
# info arrays.
#
proc Neurorecorder_close {} {
	upvar #0 Neurorecorder_config config
	upvar #0 Neurorecorder_info info
	global LWDAQ_Info
	if {$info(gui) && [winfo exists $info(window)]} {
		destroy $info(window)
	}
	array unset config
	array unset info
	return ""
}

Neurorecorder_init 
Neurorecorder_open
	
return ""

----------Begin Help----------

http://www.opensourceinstruments.com/Electronics/A3018/Neurorecorder.html

----------End Help----------
