# Videoarchiver, a Standard and Polite LWDAQ Tool
#
# Copyright (C) 2018-2023 Kevan Hashemi, Open Source Instruments Inc.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.

# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.	See the GNU General Public License for more
# details.

# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place - Suite 330, Boston, MA	02111-1307, USA.

# [17-MAR-23] Videoarchiver should detect when live or recording views are lagging
# behind, receive error from Videoplayer, and close live window, suggesting
# user drops resolution.


#
# Videoarchiver_init initializes the info and config arrays, and reads
# in previously-saved settings.
#
proc Videoarchiver_init {} {
	upvar #0 Videoarchiver_info info
	upvar #0 Videoarchiver_config config
	global LWDAQ_Info LWDAQ_Driver
	
	# Initialize the tool. Exit if the window is already open.
	LWDAQ_tool_init "Videoarchiver" "32"
	
	# Set minimum camera compressor version.
	set info(min_compressor_version) "31"

	# If a graphical tool window already exists, we abort our initialization.
	if {[winfo exists $info(window)]} {
		return ""
	}
	
	# Set up directory names.
	set info(main_dir) [file join $LWDAQ_Info(program_dir) Videoarchiver]
	if {![file exists $info(main_dir)]} {
		set info(main_dir) [file normalize \
			[file join $LWDAQ_Info(program_dir) .. Videoarchiver]]
	}
	set info(scratch_dir) [file join $info(main_dir) Scratch]
	set info(keys_dir) [file join $info(main_dir) Keys]
	set info(os) $LWDAQ_Info(os)
	set info(os_dir) [file join $info(main_dir) $info(os)]
	
	# Determine executable names depending upon operating system.
	if {$info(os) == "Windows"} {
		set info(ssh) [file join $info(os_dir) ssh/ssh.exe]	
		set info(ffmpeg) [file join $info(os_dir) ffmpeg/bin/ffmpeg.exe]
	} elseif {$info(os) == "MacOS"} {
		set info(ssh) "/usr/bin/ssh"
		set info(ffmpeg) [file join $info(os_dir) ffmpeg]
	} elseif {$info(os) == "Linux"} {
		set info(ssh) "/usr/bin/ssh"
		set info(ffmpeg) [file join $info(os_dir) ffmpeg/ffmpeg]
	} elseif {$LWDAQ_Info(os) == "Raspbian"} {
		set info(ssh) "/usr/bin/ssh"
		set info(ffmpeg) "/usr/bin/ffmpeg"
	} else {
		Neuroplayer_print "WARNING: Videoarchive may not work on $LWDAQ_Info(os)."
		set info(ssh) "/usr/bin/ssh"
		set info(ffmpeg) "/usr/bin/ffmpeg"
	}
	
	# The time we allow for video streaming to start on the camera.
	set info(pi_start_ms) "500"
	
	# The codec to use for compression on the Pi. The libx264 codec is provided
	# by ffmpeg in compiled code that runs on the Pi microprocessor cores
	# (CPUs). If we want to use the Pi's graphics co-processor (GPU), we must
	# use h264_omx, but there is only one GPU, while there are four CPUs. If we
	# try to use both codecs, ffmpeg fails to concatinate them correctly on the
	# data acquisition machine.
	set config(compression_codec) "libx264"
	set config(stream_codec) "MJPEG"
	set config(compression_num_cpu) "3"
	set config(seg_length_s) "2"
	set config(min_seg_frac) "0.95"

	# Fixed IP addresses for default configurations and camera streaming.
	set info(local_ip_addr) "127.0.0.1"
	set info(default_ip_addr) "10.0.0.34"
	set info(null_addr) "0.0.0.0"
	set info(new_ip_addr) $info(default_ip_addr)
	set info(new_router_addr) $info(null_addr)
	set info(tcp_port) "2222"
	set info(tcl_port) "2223"
	set info(library_archive) "http://www.opensourceinstruments.com/ACC/Videoarchiver.zip"

	# These are the camera versions, each version accompanied by five numbers:
	# the width x, height y, frame rate fr, and constant rate factor crf. The
	# image will be x * y pixels with fr frames per second, and the H264
	# compression will be greater as the crf is lower. Standard crf is 23. The
	# crf of 15 gives a particularly sharp image.
	set config(versions) [list \
		{A3034C1 820 616 20 27} \
		{A3034C2 820 616 20 27} ]
	
	# The rotation of the image readout.
	set info(rotation_options) "0 90 180 270"
	
	# Default settings for cameras.
	set info(default_rot) "0"
	set info(default_sat) "0.5"
	set info(default_ec) "0.5"
	
	# In the following paragraphs, we define shell commands that we pass via
	# secure shell (ssh) to the camera, where we can run the libcamera-vid or
	# raspivid utilities to operate the camera, of control input and output
	# lines with the gpio utility. Each string we send directly to the camera
	# with ssh to be executed on the camera. 

	# We initialize the camera by making sure the Videoarchiver directory
	# exists, moving to that directory, cleaning up old log, video, and image
	# files, killing all videoarchiver-generated processes, video processes, and
	# image capture processes, and starting the TCPIP interface.
	set info(camera_init) {
killall -9 tclsh 
killall -9 ffmpeg 
killall -9 raspivid 
killall -9 libcamera-vid
cd Videoarchiver
rm -f *_log.txt
rm -f tmp/*.mp4
rm -f *.gif
tclsh interface.tcl -port %Q >& interface_log.txt &
echo "SUCCESS"
}	
	
	# To stop the streaming of video, and the capture of an image, we call the
	# Linux command "killall". After stopping everything, we restart the TCPIP
	# interface process.
	set info(stop) {
cd Videoarchiver
killall -9 tclsh 
killall -9 ffmpeg
killall -9 raspivid
killall -9 libcamera-vid
tclsh interface.tcl -port %Q >& interface_log.txt &
echo "SUCCESS"
}

	# The Raspberry Pi lets us re-boot as the Pi user without a password, so we
	# can reboot with the reboot command, running the command in the background
	# allows us to send back a success word before the reboot completes.
	set info(reboot) {
cd Videoarchiver
sudo reboot >& reboot_log.txt &
echo "SUCCESS"
}

	# Extract the compressor script from the data field of this script.
	set script_list [LWDAQ_xml_get_list [LWDAQ_tool_data $info(name)] script]
	set n 0
	foreach a {interface manager compressor dhcpcd init \
			stream segment framerate single compress colors} {
		set info($a\_script) [lindex $script_list $n]
		incr n
	}

	# The following parameters will appear in the configuration panel, so the
	# user can modify them by hand.
	set config(transfer_period_s) "60"
	set config(sync_period_s) "3600"
	set info(prev_sync_time) "0"
	set config(transfer_max_files) "20"
	set config(record_length_s) "600"
	set config(connect_timeout_s) "5"
	set config(restart_wait_s) "30"
	
	# Set the verbose compressor argument to have the compressors print input
	# and output segment names to their log files. With two-second segments, we
	# will have thirty lines added to the log files per minute, or 1.3 million
	# lines per month. The log files will be too long to view in the Query
	# Window. So we will print only the last log_max lines of the file.
	set config(verbose_compressors) "0"
	set config(log_max) "100"
	
	# Display parameters.
	set config(monitor_speed) "1.0"
	set config(monitor_longevity) "600"
	set info(monitor_start) "0"
	set info(watchdog_interval) "1000"
	
	# Operating-system dependent display parameters.
	if {$info(os) == "Windows"} {
		set config(display_zoom) "2.0"
		set config(display_scale) "0.5"
	} elseif {$info(os) == "MacOS"} {
		set config(display_zoom) "1.0"
		set config(display_scale) "1.0"
	} elseif {$info(os) == "Linux"} {
		set config(display_zoom) "2.0"
		set config(display_scale) "0.5"
	} elseif {$LWDAQ_Info(os) == "Raspbian"} {
		set config(display_zoom) "2.0"
		set config(display_scale) "0.5"
	} else {
		Neuroplayer_print "WARNING: Videoarchive may not work on $LWDAQ_Info(os)."
		set config(display_zoom) "2.0"
		set config(display_scale) "0.5"
	}
	
	# Lag thresholds and error log.
	set config(lag_warning) "10.0"
	set config(lag_alarm) "20.0"
	set config(lag_reset) "40.0"
	set config(error_log) [file join $info(scratch_dir) error_log.txt]
	set info(previous_line) ""
	
	# Text window colors.
	set config(v_col) "green"
	set config(s_col) "black"
	set config(verbose) "0"
	
	# Text window number of lines to keep.
	set info(num_lines_keep) "200"
	
	# The following parameter gives the four-bit DAC values that correspond to
	# the six power settings 0-4 presented to the use and programmer for
	# controlling the intensity of the LEDs, both white and infrared.
	set info(lamp_dac_values) "0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15"	
	
	# Camera login details. We don't use the camera password, but we record it
	# here for manual ssh access.
	set info(camera_login) "pi"
	set info(camera_password) "osicamera"

	# A list of cameras, which is now empty, but will be filled later, or given
	# a single entry as a starting point.
	set info(cam_list) [list]	
	
	# The camera list file defines a list of cameras with TCL commands that set
	# the camera list string and camera parameters.
	set config(cam_list_file) [file normalize "~/Desktop/CamList.tcl"]

	# The recording directory is where we store video to disk. The Videoarchiver
	# creates individual directories for each camera, using the camera ID for
	# the directory name. By default, we create these folders on the desktop.
	# Even if this is the wrong place, at least our user will see them
	# appearing.
	set config(recording_dir) [file normalize "~/Desktop"]
	
	# Variables that control the scheduler.
	set info(scheduler_panel) $info(window)\.scheduler
	set info(scheduler_state) "Stop"
	foreach a {white_on white_off infrared_on infrared_off} {
		set info($a\_min) "*"
		set info($a\_hr) "*"
		set info($a\_dymo) "*"
		set info($a\_mo) "*"
		set info($a\_dywk) "*"
		set info($a\_int) "0"
		set info($a\_step) "10"
	}
	set config(datetime_format) {%d-%b-%Y %H:%M:%S}
	
	# Read in a settings file and apply if it exists.
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 
	
	return ""	 
}

#
# Videoarchiver_ip returns the IP address of camera "n".
#
proc Videoarchiver_ip {n} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	# we can't find any such camera, generate an error.
	if {[info exists info(cam$n\_addr)]} {
		set ip $info(cam$n\_addr)
	} else {
		set ip $info(null_addr)
	}
	
	return $ip
}

#
# Videoarchiver_segdir return the segment directory, which is a sub-directory of
# the scratch directory, and is named after the camera IP address. If this
# sub-directory does not exist, the routine creates the directory. We pass the
# camera index into the routine and the routine looks up the camera's IP
# address.
#
proc Videoarchiver_segdir {n} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	set ip [Videoarchiver_ip $n]
	set dn [file join $info(scratch_dir) [string map ". _" $ip]]
	if {![file exists $dn]} {
		file mkdir $dn
	}
	
	return $dn
}

#
# Videoarchiver_print prints a message to the text window. If the message is an
# error, the routine writes the error message with the current date and time
# to the error log file.
#
proc Videoarchiver_print {line {color "black"}} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info
	
	if {$color == "norepeat"} {
		if {$info(previous_line) == $line} {return ""}
		set color black
	}
	set info(previous_line) $line
	
	if {[regexp "^WARNING: " $line] || [regexp "^ERROR: " $line]} {
		append line " ([clock format [clock seconds]]\)"
		LWDAQ_print $config(error_log) "$line"
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
# Videoarchiver_view_error_log opens a text window that allows us to view the 
# error log, edit it, and save it if needed.
#
proc Videoarchiver_view_error_log {} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	if {![file exists $config(error_log)]} {
		set f [open $config(error_log) w]
		puts $f "Videoarchiver Error Log, Created [clock format [clock seconds]]."
		close $f
	}
	set result [LWDAQ_view_text_file $config(error_log)]
	if {[LWDAQ_is_error_result $result]} {
		Videoarchiver_print $result
		return ""
	}
	
	return ""
}

#
# Videoarchiver_clear_error_log clears the error log, leaving only a line
# stating the time at which the log was cleared.
#
proc Videoarchiver_clear_error_log {} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	set f [open $config(error_log) w]
	puts $f "Videoarchiver Error Log, Cleared [clock format [clock seconds]]."
	close $f
	
	return ""
}

#
# Videoarchiver_camera_init initializes a camera by stopping all ffmpeg and
# tclsh processes, deleting old files, and starting up the interface process on
# the camera. The routine determines the camera version so we can set the
# segment length, image dimensions, and any other version-specific parameters.
# The routine checks that the firmware on the camera is compatible with this
# version of the Videoarchiver, and if not it generates an error and advises the
# user to update the camera.
#
proc Videoarchiver_camera_init {n} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	# Don't try to contact a non-existent camera.
	set ip [Videoarchiver_ip $n]
	if {$ip == $info(null_addr)} {error "No camera with index $n."}
	
	# Compose the initialization command.
	set command $info(camera_init)
	set command [regsub -all {%Q} $command $info(tcl_port)]
	
	# Check that the key is present.
	set key_file [file join $info(keys_dir) id_rsa]
	if {![file exists $key_file]} {
		error "$info(cam$n\_id) Cannot find encryption key,\
			check Videoarchiver directory."
	}

	# Send the initialization command to the camera using a secure shell.
	catch {[exec $info(ssh) \
		-o ConnectTimeout=$config(connect_timeout_s) \
		-o UserKnownHostsFile=/dev/null \
		-o StrictHostKeyChecking=no \
		-o LogLevel=error \
		-i $key_file \
		"$info(camera_login)@$ip" \
		 $command]} message
	if {[regexp "SUCCESS" $message]} {
		Videoarchiver_print "$info(cam$n\_id) Initialized,\
			tcpip interface started."
	} else {
		error $message
	}
	
	# Wait for the tcpip interface to start up.
	LWDAQ_wait_ms $info(pi_start_ms)
	
	# Use the interface to determine the camera version and check compatibility of
	# its firmwarwe.
	if {[catch {
		set sock [LWDAQ_socket_open $ip\:$info(tcl_port) basic]

		# We look at the configuration file on the camera to determine the
		# version.
		LWDAQ_socket_write $sock "getfile videoarchiver.config\n"
		set size [LWDAQ_socket_read $sock line]
		if {[LWDAQ_is_error_result $size]} {error $size}
		set configuration [LWDAQ_socket_read $sock $size]
		if {[regexp "os Bullseye" $configuration]} {
			set info(cam$n\_ver) "A3034C2"
		} else {
			set info(cam$n\_ver) "A3034C1"
		}
		Videoarchiver_print "$info(cam$n\_id) Camera is version [set info(cam$n\_ver)]."
		
		# We look at the compressor.config file. If it's not present, or if the version
		# number it contains is obsolete, the camera must be updated.
		LWDAQ_socket_write $sock "getfile compressor.config\n"
		set size [LWDAQ_socket_read $sock line]
		if {[LWDAQ_is_error_result $size]} {
			error $size
		}		
		if {$size == 0} {
			error "Camera software obsolete, update with \"U\" button."
		}
		set configuration [LWDAQ_socket_read $sock $size]
		if {[regexp {version=([0-9]+)} $configuration match version]} {
			if {$version < $info(min_compressor_version)} {
				error "Camera software V$version obsolete, update with \"U\" button."
			}
		} else {
			error "Corrupted camera software, update with \"U\" button."
		}
		
		LWDAQ_socket_close $sock
	} message]} {
		catch {LWDAQ_socket_close $sock}
		error $message	
	}

	return ""
}

#
# Videoarchiver_query prints the local and remote process log files.
#
proc Videoarchiver_query {n} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	# Get IP address and open an interface socket.
	set ip [Videoarchiver_ip $n]

	# Don't try to contact a non-existent camera.
	if {$ip == $info(null_addr)} {
		Videoarchiver_print "ERROR: No camera with list index $n."
		return ""
	}
	
	# Open a new text window and set its title.
	set w $info(window)\.query$n
	set t $w.text
	if {![winfo exists $w]} {
		toplevel $w
		LWDAQ_text_widget $w 100 20
		wm title $w "Query Results for Camera $info(cam$n\_id) at $ip"
	}

	LWDAQ_print $t "Query at Time: [clock format [clock seconds]]" purple
	LWDAQ_print $t "-------------------------------------------" purple
	LWDAQ_print $t "Local Segment Directory:" purple
	LWDAQ_print $t [Videoarchiver_segdir $n]

	foreach log {live transfer monitor} {
		set fn [file join [Videoarchiver_segdir $n] $log\_log.txt]
		if {[file exists $fn]} {
			set f [open $fn r]
			set contents [read $f]
			close $f
		} else {
			set contents ""
		}
		set contents [string trim $contents]
		LWDAQ_print $t "Contents of local [file tail $fn]\:" purple
		if {$contents != ""} {
			foreach line [lrange [split $contents \n] end-$config(log_max) end] {
				LWDAQ_print $t $line
			}
		}
		LWDAQ_update
	}
	
	if {[catch {
		set sock [LWDAQ_socket_open $ip\:$info(tcl_port) basic]
		
		foreach cf {videoarchiver compressor} {
			LWDAQ_socket_write $sock "getfile $cf\.config\n"
			set size [LWDAQ_socket_read $sock line]
			if {[LWDAQ_is_error_result $size]} {error $size}
			set contents [string trim [LWDAQ_socket_read $sock $size]]
			LWDAQ_print $t "Contents of $cf\.config\
				on $info(cam$n\_id):" purple
			if {$size > 0} {
				LWDAQ_print $t $contents
			} else {
				LWDAQ_print $t "WARNING: Cannot find $cf\.config,\
					firmware update required."
			}
		}

		foreach log {interface stream segmentation manager compressor} {
			set lfn "$log\_log.txt"
			LWDAQ_socket_write $sock "getfile $lfn\n"
			set size [LWDAQ_socket_read $sock line]
			if {[LWDAQ_is_error_result $size]} {error $size}
			set contents [LWDAQ_socket_read $sock $size]	
			set contents [regsub -all {\.\.\.} $contents "...\n"]
			set contents [string trim $contents]
			LWDAQ_print $t "Contents of $lfn on $info(cam$n\_id):" purple
			if {$size > 0} {
				foreach line [lrange [split $contents \n] end-$config(log_max) end] {
					LWDAQ_print $t $line
				}
			} 
			LWDAQ_update
		}
	
		LWDAQ_socket_write $sock "llength \[glob -nocomplain tmp/V*.mp4\]\n"
		set len [LWDAQ_socket_read $sock line]
		if {[LWDAQ_is_error_result $len]} {error $len}
		LWDAQ_print $t "Number of compressed video segments\
			on $info(cam$n\_id): $len" purple

		LWDAQ_socket_write $sock "llength \[glob -nocomplain tmp/S*.mp4\]\n"
		set len [LWDAQ_socket_read $sock line]
		if {[LWDAQ_is_error_result $len]} {error $len}
		LWDAQ_print $t "Number video segments awaiting compression\
			on $info(cam$n\_id): $len" purple

		LWDAQ_socket_write $sock "gettemp\n"
		set temp [LWDAQ_socket_read $sock line]
		if {[LWDAQ_is_error_result $temp]} {error $temp}
		LWDAQ_print $t "Microprocessor core temperature (Centigrade): $temp" purple

		LWDAQ_socket_write $sock "getfreq\n"
		set freq [LWDAQ_socket_read $sock line]
		if {[LWDAQ_is_error_result $freq]} {error $freq}
		LWDAQ_print $t "Microprocessor clock frequency (GHz): $freq" purple
		
		LWDAQ_print $t "\n"
		LWDAQ_socket_close $sock
	} message]} {
		set message [string trim [regsub "ERROR: " $message ""]]
		Videoarchiver_print "ERROR: $message"
		catch {LWDAQ_socket_close $sock}
		return ""	
	}	
}

#
# Videoarchiver_reboot causes the camera to reboot.
#
proc Videoarchiver_reboot {n} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	# Get IP address and open an interface socket.
	set ip [Videoarchiver_ip $n]

	# Don't try to contact a non-existent camera.
	if {$ip == $info(null_addr)} {
		Videoarchiver_print "ERROR: No camera with list index $n."
		return ""
	}

	if {$info(cam$n\_state) != "Idle"} {
		Videoarchiver_print "ERROR: Wait until $info(cam$n\_id) is Idle\
			before trying a reboot."
		return ""
	}	
	set info(cam$n\_state) "Reboot"
	
	Videoarchiver_print "\nRebooting $info(cam$n\_id)" purple
	Videoarchiver_print "$info(cam$n\_id) Sending reboot command..."
	LWDAQ_update
	
	catch {exec $info(ssh) \
		-o ConnectTimeout=$config(connect_timeout_s) \
		-o UserKnownHostsFile=/dev/null \
		-o StrictHostKeyChecking=no \
		-o LogLevel=error \
		-i [file join $info(keys_dir) id_rsa] \
		"$info(camera_login)@$ip" \
		 $info(reboot)} message
	if {[regexp "SUCCESS" $message]} {
		Videoarchiver_print "$info(cam$n\_id) Rebooting,\
			done when lights flash three times."
	} else {
		Videoarchiver_print "ERROR: $info(cam$n\_id) $message"
	}
	
	set info(cam$n\_state) "Idle"
	return ""
}

#
# Videoarchiver_setlamp sets lamps to a specified intensity in the
# range defined by the first and last elements in lamp_dac_values. The routine
# works on white or infrared lamps, as specified by "color".
#
proc Videoarchiver_setlamp {n color intensity} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info
	
	if {[catch {
		# Convert the intensity into a four-bit DAC value for the camera's
		# lamp control circuit.
		if {![string is integer -strict $intensity] \
				|| ($intensity < [lindex $info(lamp_dac_values) 0]) \
				|| ($intensity > [lindex $info(lamp_dac_values) end])} {
			Videoarchiver_print "ERROR: Invalid lamp intensity \"$intensity\"."
		}
		
		# Get IP address and open an interface socket.
		set ip [Videoarchiver_ip $n]
	
		# Don't try to contact a non-existent camera.
		if {$ip == $info(null_addr)} {
			Videoarchiver_print "ERROR: No camera with list index $n."
			return ""
		}

		# Open a socket to the interface.
		set sock [LWDAQ_socket_open $ip\:$info(tcl_port) basic]
		
		# Send setlamp command.
		LWDAQ_socket_write $sock "setlamp $color $intensity\n"
		set result [LWDAQ_socket_read $sock line]
		if {$result != $intensity} {
			set message [string trim [regsub "ERROR: " $result ""]]
			error $message
		}
		
		# Close the socket.
		LWDAQ_socket_close $sock
	
		# Report the change, provided verbose flag is set. Set the menubutton value.
		Videoarchiver_print "$info(cam$n\_id) Set $color lamps to\
			intensity $intensity." verbose
		set info(cam$n\_$color) $intensity
	} message]} {
		catch {LWDAQ_socket_close $sock}
		Videoarchiver_print "ERROR: $message"
	}
	return ""
}

#
# Videoarchiver_cleanup gets rid of old segment and log files on the camera and
# in the local segment directory.
#
proc Videoarchiver_cleanup {n} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	set ip [Videoarchiver_ip $n]
	cd [Videoarchiver_segdir $n]
	set file_list [lsort -dictionary [glob -nocomplain *.mp4]]
	set num_old_files [llength $file_list]
	if {$num_old_files > 0} {
		foreach fn $file_list {
			if {[catch {file delete $fn} message]} {
				Videoarchiver_print "ERROR: $message."
				return ""
			}
		}
	}
	set file_list [lsort -dictionary [glob -nocomplain *.txt]]
	set num_old_files [llength $file_list]
	if {$num_old_files > 0} {
		foreach fn $file_list {
			if {[catch {file delete $fn} message]} {
				Videoarchiver_print "ERROR: $info(cam$n\_id) $message."
				Videoarchiver_print "WARNING: Kill rogue process that\
					ownes [file tail $fn] or recording will crash."
				return ""
			}
		}
	}
	
	return ""
}

#
# Videoarchiver_update uploads new interface, compressor, initialization, and 
# factory-default dhcp configuration files on the camera, as well as the latest
# suite of test code.
#
proc Videoarchiver_update {n} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info
	global LWDAQ_Info

	# Get IP address and open an interface socket.
	set ip [Videoarchiver_ip $n]

	# Don't try to contact a non-existent camera.
	if {$ip == $info(null_addr)} {
		Videoarchiver_print "ERROR: No camera with list index $n."
		return ""
	}

	Videoarchiver_print "\nUpdating Software on $info(cam$n\_id)" purple
	if {[catch {	
	
		# Stop all camera activity in preparation for the update.
		Videoarchiver_print "$info(cam$n\_id) Stopping all activity..."
		LWDAQ_update
		catch {[exec $info(ssh) \
			-o ConnectTimeout=$config(connect_timeout_s) \
			-o UserKnownHostsFile=/dev/null \
			-o StrictHostKeyChecking=no \
			-o LogLevel=error \
			-i [file join $info(keys_dir) id_rsa] \
			"$info(camera_login)@$ip" \
			$info(stop)]} message
		if {![regexp "SUCCESS" $message]} {error $message}
		
		# Use ssh to send a new tcpip interface script to the camera.
		Videoarchiver_print "$info(cam$n\_id) Updating tcpip interface script..."
		LWDAQ_update
		set message [exec $info(ssh) \
			-o ConnectTimeout=$config(connect_timeout_s) \
			-o UserKnownHostsFile=/dev/null \
			-o StrictHostKeyChecking=no \
			-o LogLevel=error \
			-i [file join $info(keys_dir) id_rsa] \
			"$info(camera_login)@$ip" \
			"echo \'$info(interface_script)\' > Videoarchiver/interface.tcl"]
		if {$message != ""} {error $message}
	
		# Start the tcpip interface using the camera initialization command.
		Videoarchiver_print "$info(cam$n\_id) Starting tcpip interface..."
		LWDAQ_update
		set command $info(camera_init)
		set command [regsub -all {%Q} $command $info(tcl_port)]
		catch {[exec $info(ssh) \
			-o ConnectTimeout=$config(connect_timeout_s) \
			-o UserKnownHostsFile=/dev/null \
			-o StrictHostKeyChecking=no \
			-o LogLevel=error \
			-i [file join $info(keys_dir) id_rsa] \
			"$info(camera_login)@$ip" \
			 $command]} message
		if {![regexp "SUCCESS" $message]} {error $message}

		# Wait for the streaming to start up, or else the videoplayer process may find
		# no listening port and abort.
		LWDAQ_wait_ms $info(pi_start_ms)
	
		# Open a socket to the tcpip interface.
		set sock [LWDAQ_socket_open $ip\:$info(tcl_port) basic]
		
		# Make sure the test subdirectory exists.
		Videoarchiver_print "$info(cam$n\_id) Creating test directory..."
		LWDAQ_socket_write $sock "mkdir test\n"
		set result [LWDAQ_socket_read $sock line]
		if {$result != "test"} {
			catch {close $sock}
			error "Failed to create test directory."
		}
				
		# Update files on the camera. For each file we provide a functional name and
		# a file name.
		foreach {sn fn} {manager manager.tcl \
				compressor compressor.tcl \
				dhcpcd dhcpcd_default.conf \
				init init.sh \
				stream test/stream.sh \
				segment test/segment.sh \
				framerate test/framerate.tcl \
				single test/single.tcl \
				compress test/compress.tcl \
				colors colors.json} {
			Videoarchiver_print "$info(cam$n\_id) Updating $fn..."
			LWDAQ_update
			set size [string length $info($sn\_script)]
			LWDAQ_socket_write $sock "putfile $fn $size\n$info($sn\_script)"
			set result [LWDAQ_socket_read $sock line]
			if {$result != $size} {
				catch {close $sock}
				error "Failed to write $size bytes to $fn on $info(cam$n\_id)"
			}
		}
		
		# Write a new compressor configuration file.
		set cc "version=$info(version)"
		set size [string length $cc]
		LWDAQ_socket_write $sock "putfile compressor.config $size\n$cc"
		set result [LWDAQ_socket_read $sock line]
		if {$result != $size} {
			catch {close $sock}
			error "Failed to write $size bytes to $fn on $info(cam$n\_id)"
		}
		
		# Close the socket, the update is complete.
		LWDAQ_socket_close $sock

		# Synchronize the clock on the camera.
		Videoarchiver_print "$info(cam$n\_id) Synchronizing camera clock..."
		Videoarchiver_synchronize $n
		
		# Update is complete.
		Videoarchiver_print "$info(cam$n\_id) Update complete.\n"
	} message]} {
		Videoarchiver_print "ERROR: $info(cam$n\_id) $message.\n"
		catch {LWDAQ_socket_close $sock}
		return ""
	}
	
	return ""
}

#
# Videoarchiver_ask_ip ask to change a camera's IP address.
#
proc Videoarchiver_ask_ip {n} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	# Get IP address and open an interface socket.
	set ip [Videoarchiver_ip $n]

	# Don't try to contact a non-existent camera.
	if {$ip == $info(null_addr)} {
		Videoarchiver_print "ERROR: No camera with list index $n."
		return ""
	}

	# Check to see if the New IP window already exists.	
	set new_ip $ip
	set w $info(window)\.changeip$n
	if {[winfo exists $w]} {
		raise $w
		return ""
	}
	
	# Set the proposed new IP address and router address. We always propose
	# the pre-existing IP address and the null router address.
	set info(new_ip_addr) $ip
	set info(new_router_addr) $info(null_addr)
	
	# Make a window with entries and proceed button.
	toplevel $w
	wm title $w "Set Address of $info(cam$n\_id)"
	label $w.nal -text "New IP Address:" -fg purple
	entry $w.nae -textvariable Videoarchiver_info(new_ip_addr) -width 10
	label $w.nrl -text "New Router Address:" -fg purple
	entry $w.nre -textvariable Videoarchiver_info(new_router_addr) -width 10
	label $w.setl -text "Apply New Addresses:"
	button $w.setb -text "Go" -command [list Videoarchiver_set_ip $n]
	grid $w.nal $w.nae -sticky nsew
	grid $w.nrl $w.nre -sticky nsew
	grid $w.setl $w.setb -sticky nsew
	
	# Return.
	return ""
}

#
# Videoarchiver_set_ip change a camera's IP address.
#
proc Videoarchiver_set_ip {n {new_ip ""} {new_router ""}} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	# If the state of the camera is not Idle, don't allow IP change.
	if {$info(cam$n\_state) != "Idle"} {
		Videoarchiver_print "ERROR: Wait until $info(cam$n\_id) is Idle\
			before changing camera IP address."
		return ""
	}	
	
	# Get IP address and open an interface socket.
	set ip [Videoarchiver_ip $n]

	# Destroy the ask ip window.
	set w $info(window)\.changeip$n
	if {[winfo exists $w]} {
		destroy $w
	}

	# Don't try to contact a non-existent camera.
	if {$ip == $info(null_addr)} {
		Videoarchiver_print "ERROR: No camera with list index $n."
		return ""
	}

	# If we have not passed the IP and router addresses as arguments, use the
	# global variables.	
	if {$new_ip == ""} {set new_ip $info(new_ip_addr)}
	if {$new_router == ""} {set new_router $info(new_router_addr)}
	
	Videoarchiver_print "\n$info(cam$n\_id) Setting IP address to $new_ip" purple
	if {[catch {	
		# Start by checking the new IP addresses.
		if {![regexp {([0-9]+\.[0-9]+\.[0-9]+)\.[0-9]+} $new_ip match subnet_ip]} {
			error "Invalid IP address \"$new_ip\", operation aborted"
		}
		if {![regexp {([0-9]+\.[0-9]+\.[0-9]+)\.[0-9]+} $new_router match subnet_ip]} {
			error "Invalid router address \"$new_router\", operation aborted"
		}
			
		# Stop all camera activity in preparation for the update.
		Videoarchiver_print "$info(cam$n\_id) Stopping all activity..."
		LWDAQ_update
		catch {[exec $info(ssh) \
			-o ConnectTimeout=$config(connect_timeout_s) \
			-o UserKnownHostsFile=/dev/null \
			-o StrictHostKeyChecking=no \
			-o LogLevel=error \
			-i [file join $info(keys_dir) id_rsa] \
			"$info(camera_login)@$ip" \
			$info(stop)]} message
		if {![regexp "SUCCESS" $message]} {error $message}
		
		# Start the tcpip interface using the camera initialization command.
		Videoarchiver_print "$info(cam$n\_id) Starting tcpip interface..."
		LWDAQ_update
		set command $info(camera_init)
		set command [regsub -all {%Q} $command $info(tcl_port)]
		catch {[exec $info(ssh) \
			-o ConnectTimeout=$config(connect_timeout_s) \
			-o UserKnownHostsFile=/dev/null \
			-o StrictHostKeyChecking=no \
			-o LogLevel=error \
			-i [file join $info(keys_dir) id_rsa] \
			"$info(camera_login)@$ip" \
			 $command]} message
		if {![regexp "SUCCESS" $message]} {error $message}

		# Wait for the interface to start up, or else it will not let us connect.
		LWDAQ_wait_ms $info(pi_start_ms)
	
		# Open a socket to the tcpip interface and instruct the interface
		# to update the IP address.
		set sock [LWDAQ_socket_open $ip\:$info(tcl_port) basic]
		LWDAQ_socket_write $sock "setip $new_ip $new_router\n"
		set result [LWDAQ_socket_read $sock line]
		if {$result != $new_ip} {error $result}
			
		# Close the socket, the update is complete.
		LWDAQ_socket_close $sock
		
		# Update is complete.
		set info(cam$n\_addr) $new_ip
		
		Videoarchiver_print "$info(cam$n\_id) New IP address is $new_ip,\
			new router address is $new_router, ready in a few seconds."
	} message]} {
		Videoarchiver_print "ERROR: $info(cam$n\_id) $message."
		catch {LWDAQ_socket_close $sock}
		return ""
	}
	
	return ""
}

#
# Videoarchiver_stream start streaming of video from the camera.
#
proc Videoarchiver_stream {n} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	# Get IP address and open an interface socket.
	set ip [Videoarchiver_ip $n]

	# Don't try to contact a non-existent camera.
	if {$ip == $info(null_addr)} {
		error "No camera with list index $n."
	}

	# We move to the scratch directory because file names are simpler when
	# calling ffmpeg so we can use the same command line code for all operating
	# systems.
	cd [Videoarchiver_segdir $n]
	
	# Obtain the height and width size of the image we want, and the frame rate.
	set sensor_index [lsearch $config(versions) "$info(cam$n\_ver)*"]
	if {$sensor_index < 0} {set sensor_index 0}
	scan [lindex $config(versions) $sensor_index] %s%d%d%d%d%d \
		version width height framerate crf sl
		
	# Report what we are doing.
	Videoarchiver_print "$info(cam$n\_id) Starting video,\
		$width X $height, $framerate fps, $info(cam$n\_rot) deg,\
		sat $info(cam$n\_sat), exp $info(cam$n\_ec)."
	LWDAQ_update

	# Determine the rotation we want from the camera. Some rotations we begin
	# in the camera and complete during compression. In some versions of the
	# Videoarchiver, we perform no ration in the stream at all, but we leave
	# this code in place for future versions.
	switch $info(cam$n\_rot) {
		0 {set rot 0}
		90 {set rot 0}
		180 {set rot 0}
		270 {set rot 0}
		default {set rot 0}
	}

	if {[catch {
		# Open a socket to the interface.
		set sock [LWDAQ_socket_open $ip\:$info(tcl_port) basic]
		
		# We start video streaming to a TCPIP port. Our command uses the long
		# versions of all options for clarity. We are going to perform percent
		# substitution on this string to allow the user to change the
		# resolution, compensation, rotation and saturation of the video. The
		# final command to echo the word SUCCESS is to allow our secure shell to
		# return a success code. Any error will cause the echo to be skipped.
		if {$info(cam$n\_ver) == "A3034C2"} {
			LWDAQ_socket_write $sock "exec libcamera-vid \
				--codec $config(stream_codec) \
				--timeout 0 \
				--flush \
				--width $width --height $height \
				--rotation $rot \
				--saturation [format %.1f [expr 2.0*$info(cam$n\_sat)]] \
				--ev [format %.1f [expr 2.0*($info(cam$n\_ec)-0.5)]] \
				--nopreview \
				--framerate $framerate \
				--tuning-file /home/pi/Videoarchiver/colors.json \
				--listen --output tcp://0.0.0.0:$info(tcp_port) \
				>& stream_log.txt & \n"
		} else {
			LWDAQ_socket_write $sock "exec raspivid \
				--codec $config(stream_codec) \
				--timeout 0 \
				--flush \
				--width $width --height $height \
				--saturation [expr round(200*$info(cam$n\_sat)-100)] \
				--ev [expr round(20.0*($info(cam$n\_ec)-0.5))] \
				--rotation $rot \
				--nopreview \
				--framerate $framerate \
				--listen --output tcp://0.0.0.0:$info(tcp_port) \
				>& stream_log.txt & \n"
		}
		set result [LWDAQ_socket_read $sock line]
		if {[LWDAQ_is_error_result $result]} {
			set message [string trim [regsub "ERROR: " $result ""]]
			error $message
		} 
		
		# Close socket.
		LWDAQ_socket_close $sock
	} message]} {
		Videoarchiver_print "ERROR: $info(cam$n\_id) $message"
		catch {LWDAQ_socket_close $sock}
		return ""
	}

	# Wait for the streaming to start up, or else the videoplayer process may
	# find no listening port and abort.
	LWDAQ_wait_ms $info(pi_start_ms)
	
	# Return success.
	return ""
}

#
# Videoarchiver_synchronize matches the camera clock with the local computer clock. 
# This routine uses the interface process on the camera, so must be called only after 
# the interface has been started, which is done by Videoarchiver_stream or by
# the Videoarchiver_photo routine,
#
proc Videoarchiver_synchronize {n} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	# Get IP address and open an interface socket.
	set ip [Videoarchiver_ip $n]

	# Don't try to contact a non-existent camera.
	if {$ip == $info(null_addr)} {
		Videoarchiver_print "ERROR: No camera with list index $n."
		return ""
	}

	if {[catch {
		# Open a socket to the interface.
		set sock [LWDAQ_socket_open $ip\:$info(tcl_port) basic]
		
		# Get the current time from the camera, as a way of measuring the 
		# latency in our effort to synchronize the time.
		set timer_ms [clock milliseconds]
		LWDAQ_socket_write $sock "clock milliseconds\n"
		set camera_time_ms [LWDAQ_socket_read $sock line]
		if {![regexp {[0-9]{13}} $camera_time_ms]} {
			Videoarchiver_print "ERROR: $info(cam$n\_id) $camera_time_ms"
			catch {LWDAQ_socket_close $sock}
			return ""
		}
		
		# Calculate times.
		set current_time_ms [clock milliseconds]
		set offset_ms [expr $camera_time_ms - $current_time_ms]	
		set latency_ms [expr $current_time_ms - $timer_ms]
		set sync_wait_ms [expr (- $latency_ms - $current_time_ms) % 1000]
		set sync_time [expr ($current_time_ms / 1000) + 1]
		
		# Wait until the start of the next second, minus the latency.
		LWDAQ_wait_ms $sync_wait_ms
		
		# Set the camera time.
		LWDAQ_socket_write $sock "exec sudo date +%s --set \"@$sync_time\"\n"
		set result [LWDAQ_socket_read $sock line]
		
		# Close the socket.	
		LWDAQ_socket_close $sock
	} message]} {
		Videoarchiver_print "ERROR: $info(cam$n\_id) $message"
		catch {LWDAQ_socket_close $sock}
		return ""
	}
	
	# Report.
	if {![regexp {invalid} $result]} {
		Videoarchiver_print "$info(cam$n\_id) Synchronized at time $sync_time,\
			correcting offset of $offset_ms ms." verbose
	} else {
		Videoarchiver_print "ERROR: $info(cam$n\_id) $result"
		return ""
	}
	
	return "$offset_ms $latency_ms $sync_wait_ms $sync_time"
}

#
# Videoarchiver_live streams live video from camera "n" and displays it on the
# screen. The video stream consists of individual compressed frames (MJPEG), but
# has no inter-frame compression (no H264 compression). 
#
proc Videoarchiver_live {n} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info
	global LWDAQ_Info
	
	# Get IP address and open an interface socket.
	set ip [Videoarchiver_ip $n]

	# Don't try to contact a non-existent camera.
	if {$ip == $info(null_addr)} {
		Videoarchiver_print "ERROR: No camera with list index $n."
		return ""
	}

	# Check the camera state.
	if {$info(cam$n\_state) != "Idle"} {
		Videoarchiver_print "ERROR: $info(cam$n\_id) Cannot provide live\
			image during \"$info(cam$n\_state)\"."
		return ""
	}
	set info(cam$n\_state) "Live"
	LWDAQ_set_bg $info(cam$n\_state_label) yellow
	Videoarchiver_cleanup $n
	
	# Initialize the camera.
	if {[catch {Videoarchiver_camera_init $n} message]} {
		Videoarchiver_print "ERROR: $info(cam$n\_id) $message"
		Videoarchiver_stop $n
		return ""	
	} 
	
	# Start streaming video from camera.
	if {[catch {Videoarchiver_stream $n} message]} {
		Videoarchiver_print "ERROR: $info(cam$n\_id) $message"
		Videoarchiver_stop $n
		return ""	
	} 
	
	# We move to the scratch directory because file names are simpler when
	# calling ffmpeg. We can use the same command line code for all operating
	# systems.
	cd [Videoarchiver_segdir $n]
	
	# Obtain the height and width size of the image we want, and the frame rate.
	set sensor_index [lsearch $config(versions) "$info(cam$n\_ver)*"]
	if {$sensor_index < 0} {set sensor_index 0}
	scan [lindex $config(versions) $sensor_index] %s%d%d%d%d%d \
		version width height framerate crf sl
		
	# Spawn a Videoplayer and use it to stream the incoming video.
	Videoarchiver_print "$info(cam$n\_id) Starting live view." $config(v_col)
	cd $LWDAQ_Info(program_dir)
	set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
	set info(cam$n\_vchan) $ch
	set info(cam$n\_vpid) [pid $ch]
	fconfigure $ch -translation auto -buffering line -blocking 0
	puts $ch "cd [Videoarchiver_segdir $n]"
	puts $ch "LWDAQ_run_tool Videoplayer.tcl Slave"
	puts $ch "videoplayer stream \
		-stream tcp://$ip:$info(tcp_port) \
		-width $width \
		-height $height \
		-rotation $info(cam$n\_rot) \
		-scale $config(display_scale) \
		-zoom $config(display_zoom)\
		-title \"Live View From $info(cam$n\_id) $ip\""
	while {[gets $ch message] > 0} {
		if {[LWDAQ_is_error_result $line]} {
			Videoarchiver_print "$message"
		}
		Videoarchiver_stop $n
		return ""
	}
			
	# We start the live video watchdog process that looks to see if the 
	# videoplayer process has been stopped by a user closing its window. 
	Videoarchiver_print "$info(cam$n\_id)\
		Starting live view watchdog." $config(v_col)
	LWDAQ_post [list Videoarchiver_live_watchdog $n 1]
	return ""
}

#
# Videoarchiver_live_watchdog check the status of the live view process running
# for camera "n". If the viewer process disappears, execute a stop on the same 
# camera. The routine also checks to see if any error occurred when starting
# up the streaming, by reading the stream log file. We read the log file only 
# occasionaly, at random.
#
proc Videoarchiver_live_watchdog {n {first 0}} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info
	global LWDAQ_Info
		
	# Get IP address and open an interface socket.
	set ip [Videoarchiver_ip $n]

	# Don't try to contact a non-existent camera.
	if {$ip == $info(null_addr)} {
		Videoarchiver_print "ERROR: No camera with list index $n."
		return ""
	}

	# Don't do anything if the state is not "Live".
	if {$info(cam$n\_state) != "Live"} {
		Videoarchiver_print "$info(cam$n\_id)\
			Stopped live view watchdog." $config(v_col)
		return ""
	} 
	
	# If this is our first call to the watchdog, set the timer.
	if {$first} {
		set info(cam$n\_wdt) [clock milliseconds]
		LWDAQ_post [list Videoarchiver_live_watchdog $n]
		return ""
	}
	
	if {$LWDAQ_Info(reset)} {
		Videoarchiver_stop $n
		return ""
	} 
	
	if {[catch {puts $info(cam$n\_vchan) ""}]} {
		Videoarchiver_print "$info(cam$n\_id)\
			Live view has stopped running, stopping watchdog." \
			$config(v_col)
		Videoarchiver_stop $n
		return ""
	} 
	
	if {[clock milliseconds] - $info(cam$n\_wdt) > $info(watchdog_interval)} {
		if {[catch {		
			set sock [LWDAQ_socket_open $ip\:$info(tcl_port) basic]
			LWDAQ_socket_write $sock \
				"exec ps -e | grep -e raspivid -e libcamera-vid \n"
			set result [LWDAQ_socket_read $sock line]
			if {[LWDAQ_is_error_result $result] \
					|| ($result == "") \
					|| [regexp {defunct} $result]} {
				error "Live view stalled, try again, or reboot camera and try again"
			}
			LWDAQ_socket_close $sock
		} message]} {
			catch {LWDAQ_socket_close $sock}
			Videoarchiver_print "ERROR: $info(cam$n\_id) $message\."
			Videoarchiver_stop $n
			return ""
		}
		set info(cam$n\_wdt) [clock milliseconds]
	}
	
	LWDAQ_post [list Videoarchiver_live_watchdog $n]
	return ""
}

#
# Videoarchiver_monitor manages the video monitor that gives a delayed view of 
# recorded video. We allow only one video stream to be monitored at a time. We
# have an optional file name for the Add instruction.
#
proc Videoarchiver_monitor {n {command "Start"} {fn ""}} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info
	global LWDAQ_Info

	# Get IP address and open an interface socket.
	set ip [Videoarchiver_ip $n]

	# Don't try to contact a non-existent camera.
	if {$ip == $info(null_addr)} {
		Videoarchiver_print "ERROR: No camera with list index $n."
		return ""
	}

	# Start a new monitor window. 
	if {$command == "Start"} {

		# Check we are recording.
		if {$info(cam$n\_state) != "Record"} {
			Videoarchiver_print "ERROR: $info(cam$n\_id) Cannot start recording\
				view during \"$info(cam$n\_state)\"."
			return ""
		}

		# Check the state of the camera.
		if {$info(cam$n\_vchan) != "none"} {
			catch {puts $info(cam$n\_vchan) "videoplayer stop"}
			catch {puts $info(cam$n\_vchan) "exit"}
			catch {close $info(cam$n\_vchan)}
			LWDAQ_process_stop $info(cam$n\_vpid)
			Videoarchiver_print "$info(cam$n\_id)\
				Stopped pre-existing monitor view, starting another." $config(v_col)
		}
		
		# Obtain the height and width size of the image we want, and the frame rate.
		set sensor_index [lsearch $config(versions) "$info(cam$n\_ver)*"]
		if {$sensor_index < 0} {set sensor_index 0}
		scan [lindex $config(versions) $sensor_index] %s%d%d%d%d%d \
			version width height framerate crf sl
		
		# Spawn and configure a Videoplayer and use it to stream the incoming
		# video. We tell it not to complain if a video file does not exist when
		# it tries to play the file. We can set the speed slightly higher than
		# normal so the view will catch up with recording. We allow for scaling
		# of the view, and we tell the viewer the correct dimensions of the
		# video and its framerate.
		Videoarchiver_print "$info(cam$n\_id) Starting recording view." $config(v_col)
		cd $LWDAQ_Info(program_dir)
		set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
		fconfigure $ch -translation auto -buffering line -blocking 0
		set info(cam$n\_vchan) $ch
		set info(cam$n\_vpid) [pid $info(cam$n\_vchan)]
		set info(monitor_start) [clock seconds]
		puts $ch "cd [Videoarchiver_segdir $n]"
		puts $ch {LWDAQ_run_tool Videoplayer.tcl Slave}
		puts $ch "videoplayer setup \
			-title \"Recording View From $info(cam$n\_id) $ip\" \
			-speed $config(monitor_speed) \
			-scale $config(display_scale) \
			-zoom $config(display_zoom) \
			-width $width \
			-height $height \
			-framerate $framerate \
			-nocomplain 1"
			
		# Check to see if the Videoplayer returned any errors.
		while {[gets $ch message] > 0} {
			if {[LWDAQ_is_error_result $line]} {
				Videoarchiver_print "$message"
			}
			return ""
		}
	} elseif {$command == "Stop"} {
		if {$info(cam$n\_vchan) != "none"} {
			catch {puts $info(cam$n\_vchan) "videoplayer stop"}
			catch {puts $info(cam$n\_vchan) "exit"}
			catch {close $info(cam$n\_vchan)}
			LWDAQ_process_stop $info(cam$n\_vpid)
			Videoarchiver_print "$info(cam$n\_id)\
				Stopped monitor view." $config(v_col)
		}
		set info(cam$n\_vchan) "none"
		set info(cam$n\_vpid) "0"
	} elseif {$command == "Add"} {
		if {[clock seconds] - $info(monitor_start) > $config(monitor_longevity)} {
			Videoarchiver_print "Closing recording view automatically after\
				$config(monitor_longevity) s." $config(v_col)
			LWDAQ_post [list Videoarchiver_monitor $n "Stop"]
			return "" 
		}
		if {[catch {
			while {[gets $info(cam$n\_vchan) result] > 0} {
				Videoarchiver_print $result orange
			}
			if {$fn != ""} {
				puts $info(cam$n\_vchan) "videoplayer play -file $fn -start 0 -end *"
			}
		} message]} {
			Videoarchiver_print "$info(cam$n\_id) Recording view has been closed." \
				$config(v_col)
			LWDAQ_post [list Videoarchiver_monitor $n "Stop"]
			return "" 
		}		
	} else {
		Videoarchiver_print "ERROR: $info(cam$n\_id) Unknown recording view\
			command \"$command\"." $config(v_col)
		return ""
	}
	return ""
}

#
# Videoarchiver_compress starts the compression processes on the camera.
#
proc Videoarchiver_compress {n} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	# Get IP address and open an interface socket.
	set ip [Videoarchiver_ip $n]

	# Don't try to contact a non-existent camera.
	if {$ip == $info(null_addr)} {
		Videoarchiver_print "ERROR: No camera with list index $n."
		return ""
	}

	# Obtain the height and width size of the image we want, and the frame rate.
	set sensor_index [lsearch $config(versions) "$info(cam$n\_ver)*"]
	if {$sensor_index < 0} {set sensor_index 0}
	scan [lindex $config(versions) $sensor_index] %s%d%d%d%d%d \
		version width height framerate crf sl
	
	if {[catch {
		# Open a socket to the interface.
		set sock [LWDAQ_socket_open $ip\:$info(tcl_port) basic]
		
		# Start the compression manager.
		LWDAQ_socket_write $sock "exec /usr/bin/tclsh manager.tcl \
			-framerate $framerate \
			-seglen $config(seg_length_s) \
			-codec $config(compression_codec) \
			-crf $crf \
			-preset veryfast \
			-verbose $config(verbose_compressors) \
			-rotation $info(cam$n\_rot) \
			-processes $config(compression_num_cpu) \
			>& manager_log.txt & \n"
		set result [LWDAQ_socket_read $sock line]
		if {[LWDAQ_is_error_result $result]} {
			set message [string trim [regsub "ERROR: " $result ""]]
			error $message
		}

		# Close socket and report.
		LWDAQ_socket_close $sock
		Videoarchiver_print "$info(cam$n\_id) Started compression manager\
			on camera with crf $crf."
	} message]} {
		Videoarchiver_print "ERROR: $info(cam$n\_id) $message"
		catch {LWDAQ_socket_close $sock}
		return ""
	}

	return ""
}

#
# Videoarchiver_segment starts the remote segmentation process on the camera.
#
proc Videoarchiver_segment {n} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	# Get IP address and open an interface socket.
	set ip [Videoarchiver_ip $n]

	# Don't try to contact a non-existent camera.
	if {$ip == $info(null_addr)} {
		Videoarchiver_print "ERROR: No camera with list index $n."
		return ""
	}

	# Obtain the height and width size of the image we want, and the frame rate.
	set sensor_index [lsearch $config(versions) "$info(cam$n\_ver)*"]
	if {$sensor_index < 0} {set sensor_index 0}
	scan [lindex $config(versions) $sensor_index] %s%d%d%d%d \
		version width height framerate crf
	
	if {[catch {
		# Open a socket to the interface.
		set sock [LWDAQ_socket_open $ip\:$info(tcl_port) basic]
		
		# Start the ffmpeg segmenter as a background process. We assume the segmenter 
		# will be started after streaming and compression engines are already running. 
		# We don't specify a frame rate for the incoming stream: we want ffmpeg to take
		# however many frames arrive in each segment time and write them to disk with 
		# a new time-stamped file name.
		LWDAQ_socket_write $sock "exec ffmpeg \
			-nostdin \
			-loglevel error \
			-i tcp://$info(local_ip_addr)\:$info(tcp_port) \
			-f segment \
			-segment_atclocktime 1 \
			-segment_time $config(seg_length_s) \
			-reset_timestamps 1 \
			-codec copy \
			-segment_list segment_list.txt \
			-segment_list_size 1000 \
			-strftime 1 tmp/S%s.mp4 \
			>& segmentation_log.txt & \n"
		set result [LWDAQ_socket_read $sock line]
		if {[LWDAQ_is_error_result $result]} {
			set message [string trim [regsub "ERROR: " $result ""]]
			error $message
		}

		# Close socket and report.
		LWDAQ_socket_close $sock
		Videoarchiver_print "$info(cam$n\_id) Started segmentation process\
			on camera with segment length $config(seg_length_s) s."
	} message]} {
		Videoarchiver_print "ERROR: $info(cam$n\_id) $message"
		catch {LWDAQ_socket_close $sock}
		return ""
	}
	
	return ""
}

#
# Videoarchiver_record starts video streaming on the camera, but receive this remotely, 
# on the camera with an ffmpeg segmentation process, which writes segments to the 
# camera hard driver. Start one or more compression processes on the camera to compress 
# the segments. Start the remote transfer process that downloads the compressed segments
# to the local segment directory and adds them to the video recording.
#
proc Videoarchiver_record {n} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info
	
	# Get IP address and open an interface socket.
	set ip [Videoarchiver_ip $n]

	# Don't try to contact a non-existent camera.
	if {$ip == $info(null_addr)} {
		Videoarchiver_print "ERROR: No camera with list index $n."
		return ""
	}
	
	# Do nothing if we are already recording.
	if {$info(cam$n\_state) == "Record"} {
		return ""
	}

	# Check the state of the camera.
	if {($info(cam$n\_state) != "Idle") && ($info(cam$n\_state) != "Stalled")} {
		Videoarchiver_stop $n
	}
	
	# Make sure we have a place to record video.
	if {[catch {
		set info(cam$n\_dir) [file join $config(recording_dir) $info(cam$n\_id)]
		if {![file exists $info(cam$n\_dir)]} {
			file mkdir $info(cam$n\_dir)
			Videoarchiver_print "$info(cam$n\_id) Created directory \
				$info(cam$n\_dir) for video files."
		} 
	} message]} {
		Videoarchiver_print "ERROR: $info(cam$n\_id) $message ."
		return ""	
	}

	# Clean up old files. This routine handles its own errors.
	if {[Videoarchiver_cleanup $n] == "ERROR"} {
		return ""	
	}

	# Initialize the camera.
	if {[catch {Videoarchiver_camera_init $n} message]} {
		Videoarchiver_print "ERROR: $info(cam$n\_id) $message"
		return ""	
	} 
	
	# Start streaming video on the camera as well as the interface process.
	if {[catch {Videoarchiver_stream $n} message]} {
		Videoarchiver_print "ERROR: $info(cam$n\_id) $message"
		return ""	
	} 
	
	# Synchronize the camera clock. The segments will be timestamped on the camera, 
	# so the remote clock must be accurate. We synchronize it now, and periodically
	# in the transfer process.
	Videoarchiver_print "$info(cam$n\_id) Synchronizing camera clock."
	if {[Videoarchiver_synchronize $n] == "ERROR"} {
		return ""
	}

	# Start compression on the camera.
	if {[catch {Videoarchiver_compress $n} message]} {
		Videoarchiver_print "ERROR: $info(cam$n\_id) $message"
		Videoarchiver_stop $n
		return ""	
	} 
	
	# Start the segmentation on the camera.
	if {[catch {Videoarchiver_segment $n} message]} {
		Videoarchiver_print "ERROR: $info(cam$n\_id) $message"
		Videoarchiver_stop $n
		return ""	
	} 

	# Start transfer of files from camera with concatination.
	Videoarchiver_print "$info(cam$n\_id) Starting remote transfer process\
		 with period $config(transfer_period_s) s." 
	LWDAQ_post [list Videoarchiver_transfer $n 1]

	# We can now say that we are recording.
	set info(cam$n\_state) "Record"	
	return ""
}

#
# Videoarchiver_restart_recording following an error, attempt to re-start remote 
# streaming and compression,
#
proc Videoarchiver_restart_recording {n {start_time ""}} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info
	global LWDAQ_Info
	
	# Don't try to contact a non-existent camera.
	if {[lsearch $info(cam_list) $n] < 0} {
		Videoarchiver_print "ERROR: No camera with index $n to restart."
		return ""
	}

	# If the camera state is Record, set it to Stalled and reset the lag
	# indicator.
	if {$info(cam$n\_state) == "Record"} {
		set info(cam$n\_state) "Stalled"
		LWDAQ_set_bg $info(cam$n\_state_label) red
		set info(cam$n\_lag) "?"
		LWDAQ_set_fg $info(cam$n\_laglabel) gray
	}
	
	# Check the camera state. If the state is no longer Stalled, don't try to
	# restart.
	if {$info(cam$n\_state) != "Stalled"} {
		return ""
	}
	
	# If we did not pass a value for the start time, the restart was requested
	# by one of the recording processes. So we set the start time to the current
	# time and write a message to the screen and the restart log.
	if {$start_time == ""} {
		set start_time [clock seconds]
		LWDAQ_print $config(error_log) \
			"$info(cam$n\_id) Recording stalled at [clock format $start_time]."
		Videoarchiver_print "$info(cam$n\_id) Recording stalled,\
			will try to restart every $config(restart_wait_s) seconds."
	}

	# If restart_wait_s seconds have not yet passed since start time, post the
	# restart operation to the queue. We don't want to try too often to restart
	# or else we will slow the other cameras down.
	if {[clock seconds] - $start_time < $config(restart_wait_s)} {
		LWDAQ_post [list Videoarchiver_restart_recording $n $start_time]
		return ""
	}
	
	# To re-start, we stop the camera and then try to start recording using
	# existing routines that catch their own errors and return the ERROR word
	# when they fail. 
	Videoarchiver_print "$info(cam$n\_id) Trying to re-start recording after fatal error."
	set result [Videoarchiver_record $n]
	
	# If recording has not started, we will try to restart again soon.
	if {$info(cam$n\_state) != "Record"} {
		set info(cam$n\_state) "Stalled"
		LWDAQ_post [list Videoarchiver_restart_recording $n [clock seconds]]
		return ""
	}
	
	# If we get here, we were successful. Note the time we re-started recording
	Videoarchiver_print \
		"$info(cam$n\_id) Recording restarted at [clock format [clock seconds]]."
	LWDAQ_print $config(error_log) \
		"$info(cam$n\_id) Recording restarted at [clock format [clock seconds]]."
	return ""
}

#
# Videoarchiver_transfer downloads video segments from the camera, where they are 
# being compressed. Keeps the camera clock synchronized. Arranges video segments in 
# correct order adds to recording file. The first time we call the routine to start
# a transfer process, we pass a 1 for the init parameter. This allows the routine
# to delete the first segment in a stream, identify the first segment that it is going
# to save, and make sure that its timestamp is correct.
#
proc Videoarchiver_transfer {n {init 0}} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info
	global LWDAQ_Info
	
	# Know when to quit. The transfer process quits if the window is gone.
  	if {![winfo exists $info(window)]} {
		return ""
 	}

	# Get IP address and open an interface socket.
	set ip [Videoarchiver_ip $n]

	# Get particulars of camera. We rarely need to use them, but we deduce
	# them here to make sure we have them.
	set sensor_index [lsearch $config(versions) "$info(cam$n\_ver)*"]
	if {$sensor_index < 0} {set sensor_index 0}
	scan [lindex $config(versions) $sensor_index] %s%d%d%d%d%d \
		version width height framerate crf sl

	# Don't try to contact a non-existent camera.
	if {$ip == $info(null_addr)} {
		Videoarchiver_print "ERROR: No camera with list index $n."
		return ""
	}

	# We move to the scratch directory because file names are simpler when
	# calling ffmpeg. We can use the same command line code for all operating
	# systems.
	cd [Videoarchiver_segdir $n]
	
	# If recording has been stopped, we don't want to try to contact the camera
	# because its interface will have been stopped too. Instead, we will skip
	# the downloading and transfer all remaining segments, then stop.
	if {$info(cam$n\_state) == "Record"} {
	
		if {[catch {
			# Open a socket to the interface on the camera.
			set when "opening socket"
			set sock [LWDAQ_socket_open $ip\:$info(tcl_port) basic]

			# Check that the video is still streaming.
			set when "checking streaming"
			LWDAQ_socket_write $sock \
				"exec ps -e | grep -e raspivid -e libcamera-vid \n"
			set result [LWDAQ_socket_read $sock line]
			if {[LWDAQ_is_error_result $result] \
					|| ($result == "") \
					|| [regexp {defunct} $result]} {
				error "Camera stalled"
			}
		
			# Get a list of segments that are available for download on the camera. 
			set when "fetching segment list"
			LWDAQ_socket_write $sock "glob -nocomplain tmp/V*.mp4\n"
			set seg_list [LWDAQ_socket_read $sock line]
			set seg_list [regsub -all {tmp/} $seg_list ""]

			# Close the socket.
			LWDAQ_socket_close $sock
		} message]} {
			set error_description "ERROR: [string trim $message]\
				while $when for $info(cam$n\_id)."
			Videoarchiver_print $error_description
			LWDAQ_print $config(error_log) $error_description
			catch {LWDAQ_socket_close $sock}
			LWDAQ_post [list Videoarchiver_restart_recording $n]
			return ""
		}
				
		# If there are one or more segments available, download up to
		# transfer_max_files of them from the camera, save to the local segment
		# directory, and delete from the camera.
		if {$seg_list != ""} {
			# Flash the background of the state label.
			LWDAQ_set_bg $info(cam$n\_state_label) yellow
		
			# Sort the segment list into increasing order, which will be oldest
			# to newest. Take from this list up to transfer_max_files names.
			set seg_list [lrange [lsort -increasing $seg_list] \
				0 [expr $config(transfer_max_files) - 1]]
				
			if {[catch {
				# Indicate camera activity by making label yellow.
				LWDAQ_set_bg $info(cam$n\_state_label) yellow
			
				# Open a socket to the camera. We will use the same socket to
				# download all segment files.
				set when "opening socket"
				set sock [LWDAQ_socket_open $ip\:$info(tcl_port) basic]

				# Get temperature and frequency of CPU.
				set when "measuring temperature"
				LWDAQ_socket_write $sock "gettemp\n"
				set temp [LWDAQ_socket_read $sock line]
				set when "measuring frequency"
				LWDAQ_socket_write $sock "getfreq\n"
				set freq [LWDAQ_socket_read $sock line]
				
				# Download, save, and delete each file.
				foreach sf $seg_list {
					# Download the segment.
					set start_ms [clock milliseconds]
					set when "downloading $sf"
					LWDAQ_socket_write $sock "getfile tmp/$sf\n"
					set size [LWDAQ_socket_read $sock line]
					if {[LWDAQ_is_error_result $size]} {error $size}
					set contents [LWDAQ_socket_read $sock $size]
					set download_ms [expr [clock milliseconds] - $start_ms]

					# Delete the original segment file.
					set when "deleting original $sf"
					LWDAQ_socket_write $sock "file delete tmp/$sf\n"
					set result [LWDAQ_socket_read $sock line]
					if {[LWDAQ_is_error_result $result]} {error $result}
					
					# If we are initializing, don't save this segment to disk.
					# Instead, we take this opportunity to create a blank image
					# that we will use to pad segments that are missing frames.
					# We clear the file time to zero, set the lag to unknown,
					# and clear the init flat.
					if {$init} {
						set info(cam$n\_ftime) 0
						set lag "?"
						exec $info(ffmpeg) -loglevel error -f lavfi \
							-i color=size=$width\x$height\:rate=$framerate\:color=black \
							-c:v libx264 -t $config(seg_length_s) Blank.mp4 \
							> transfer_log.txt					
						set init 0
						continue
					}

					# If the file time is zero, set it to the segment file time and reset
					# the number of segments loaded into the recording file.
					set when "checking segment"
					if {$info(cam$n\_ftime) == 0} {
						set info(cam$n\_fsegs) 0
						if {[regexp {V([0-9]{10})} $sf match ftime]} {
							set info(cam$n\_ftime) $ftime
						} {
							error "$info(cam$n\_id) Unexpected file \"$sf\""					
						}
					}
					
					# Write the segment to disk.
					set when "saving $sf to disk"
					set f [open $sf w]
					fconfigure $f -translation binary
					puts -nonewline $f $contents
					close $f
					
					# Determine the duration of the segment using ffmpeg.
					catch {[exec $info(ffmpeg) -i $sf]} answer
					if {[regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} \
							$answer match hr min sec]} {
						scan $hr %d hr
						scan $min %d min
						scan $sec %f sec
						set duration [format %.2f [expr $hr*3600+$min*60+$sec]]
					} else {
						set duration "0.00"
					}
					
					# Calculate the time lag between the current time and the
					# timestamp of the last segment we downloaded and saved.
					set when "reporting"
					set sf [lindex $seg_list end]
					if {[regexp {V([0-9]{10})} $sf match timestamp]} {
						set lag [expr [clock seconds] - $timestamp]
					} else {
						set lag "?"
					}
				
					# If verbose, report to text window.
					Videoarchiver_print "$info(cam$n\_id)\
						Downloaded $sf in $download_ms ms,\
						[format %.1f [expr 0.001*$size]] kByte, $duration s,\
						lag $lag s, $freq GHz, $temp C." verbose

					# If a segment is too short, we append the blank video to
					# the end, then extract a segment-length video from the
					# result, with which we replace the original segment. We
					# find that ffmpeg adds two frames to the video it extracts,
					# so we reduce time value we pass to ffmpeg for the
					# extraction by two frames. The result is a segment of the
					# correct length.
					if {$duration < $config(seg_length_s)*$config(min_seg_frac)} {
						set st [clock milliseconds]
						set ifl [open transfer_list.txt w]
						puts $ifl "file $sf"
						puts $ifl "file Blank.mp4"
						close $ifl
						exec $info(ffmpeg) -nostdin -loglevel error \
							-f concat -safe 0 -i transfer_list.txt -c copy \
							Long_$sf > transfer_log.txt
						file delete $sf
						set dur [format %.3f [expr $config(seg_length_s)-2.0/$framerate]]
						exec $info(ffmpeg) -nostdin -loglevel error -t $dur \
							-i Long_$sf -c copy Lengthened_$sf > transfer_log.txt
						file delete Long_$sf
						file rename Lengthened_$sf $sf
						Videoarchiver_print "$info(cam$n\_id)\
							Extended segment $sf duration from\
							$duration s to [format %.2f $config(seg_length_s)] s,\
							in [expr [clock milliseconds] - $st] ms."
					} 

					# If a segment is too long, we extract the correct length and
					# use this to replace the original segment.
					if {$duration > $config(seg_length_s)/$config(min_seg_frac)} {
						set st [clock milliseconds]
						set dur [format %.3f [expr $config(seg_length_s)-2.0/$framerate]]
						exec $info(ffmpeg) -nostdin -loglevel error -t $dur \
							-i $sf -c copy Shortened_$sf > transfer_log.txt
						file delete $sf
						file rename Shortened_$sf $sf
						Videoarchiver_print "$info(cam$n\_id)\
							Shortened segment $sf duration from\
							$duration s to [format %.2f $config(seg_length_s)] s,\
							in [expr [clock milliseconds] - $st] ms."
					}	
				}
				
				# Close the socket.
				LWDAQ_socket_close $sock

				# If the recording monitor is running for this channel, load the
				# new segments into the monitor. We specify 
				if {$info(cam$n\_vchan) != "none"} {
					set when "loading monitor"
					foreach sf $seg_list {
						Videoarchiver_monitor $n Add $sf
					}
					regexp {V([0-9]{10})} [lindex $seg_list 0] match tfirst
					set tnow [clock seconds]
					Videoarchiver_print "$info(cam$n\_id)\
						Added [llength $seg_list] segments to monitor playlist,\
						monitor lagging by [expr $tnow-$tfirst+1] s."
				}
				
				# Check the lag and set the lag label accordingly.
				set when "checking lag"
				if {[string is double -strict $lag]} {
					set info(cam$n\_lag) "[set lag] s"
					if {$lag > $config(lag_reset)} {
						error "Lagging by $lag seconds"
					} elseif {$lag > $config(lag_alarm)} {
						if {[$info(cam$n\_laglabel) cget -fg] != "red"} {
							Videoarchiver_print "WARNING: Lag exceeds alarm level\
								$config(lag_alarm) s for $info(cam$n\_id)." 
						}
						LWDAQ_set_fg $info(cam$n\_laglabel) red
						if {$config(verbose)} {
							Videoarchiver_print "WARNING: Turning off verbose\
								reporting in an effort to reduce camera lag." 
							set config(verbose) 0
						}
					} elseif {$lag > $config(lag_warning)} {
						if {[$info(cam$n\_laglabel) cget -fg] != "orange"} {
							Videoarchiver_print "WARNING: Lag exceeds warning level\
								$config(lag_warning) s for $info(cam$n\_id)."
						}
						LWDAQ_set_fg $info(cam$n\_laglabel) orange
					} else {
						LWDAQ_set_fg $info(cam$n\_laglabel) green
					}
				} else {
					set info(cam$n\_lag) "?"
					LWDAQ_set_fg $info(cam$n\_laglabel) gray
				}
				
			} message]} {
				set error_description "ERROR: [string trim $message]\
					while $when for $info(cam$n\_id)."
				Videoarchiver_print $error_description
				LWDAQ_print $config(error_log) $error_description
				catch {LWDAQ_socket_close $sock}
				LWDAQ_post [list Videoarchiver_restart_recording $n]
				return ""
			}
		}
	}

	# Compose a list of local segments in order oldest to newest.
	set seg_list [lsort -dictionary [glob -nocomplain V*.mp4]]	

	if {[catch {
		# If we have two or more segments, it might be time to create a new recording
		# file by moving this segment into the recording directory.
		if {[llength $seg_list] > 1} {

			# Flash the background of the state label.
			LWDAQ_set_bg $info(cam$n\_state_label) yellow
			
			# Calculate the number of segments to be included in each recording
			# file, and form the name of the current recording file. Determine
			# the minumum number of segments we need to transfer later on.
			set when "calculating constants"
			set fsegs_full [expr $config(record_length_s) / $config(seg_length_s)]
			set fname [file join $info(cam$n\_dir) V$info(cam$n\_ftime)\.mp4]
			set min_transfer_segs [expr \
				$config(transfer_period_s) / $config(seg_length_s)]
				
			# If the existing recording file is complete, increment the
			# recording file time by the recording length and reset the file
			# segment counter.
			if {$info(cam$n\_fsegs) == $fsegs_full} {
				set info(cam$n\_ftime) [expr $info(cam$n\_ftime) \
					+ $config(record_length_s)]
				set info(cam$n\_fsegs) 0
			}
			set fname [file join $info(cam$n\_dir) V$info(cam$n\_ftime)\.mp4]
			
			# If the recording file does not exist, create it out of the oldest
			# segment.
			if {![file exists $fname]} {			
				set when "creating recording file"
				Videoarchiver_print "$info(cam$n\_id)\
					Creating [file tail $fname],\
					start [clock format $info(cam$n\_ftime)]." verbose
				file rename [lindex $seg_list 0] $fname
				set info(cam$n\_fsegs) 1
				
				# Delete the first segment from the segment list, now that it
				# has been moved.
				set seg_list [lrange $seg_list 1 end]
			}
		}
	
		# If we still have two or more segments available, we have an
		# opportunity to transfer segments into the recording file. We will not
		# attempt a transfer if there is only one segment available, because
		# this segment may be loaded into the recording monitor play list.
		if {[llength $seg_list] > 1} {
		
			# If we have the minimum number of segments to make up the transfer period,
			# or if we have stopped recording, transfer all available segments into the
			# recording file until it is complete or we run out of segments.
			if { ($info(cam$n\_state) != "Record") \
				|| ([llength $seg_list] > $min_transfer_segs)} {
	
				# Open a text file into which we are going to write a list of
				# segments to transfer to the recording file.
				set when "composing segment list"
				set ifl [open transfer_list.txt w]
	
				# Here we must make sure that we give ffmpeg a native-format
				# file path to the recording directory. We have to specify
				# backslashes with double-backslashes in ffmpeg file lists, so
				# here we replace each backslash in the native name with two
				# backslashes. We have to specify each backslash in the regsub
				# command with two backslashes, so the resulting regular
				# expression is as follows.
				puts $ifl "file [regsub -all {\\} [file nativename $fname] {\\\\}]"
				
				# We go through the available segments, up to but not including
				# the most recent segment, and check to see if it belongs in the
				# recording file. We do not include the most recent segment
				# because this one may be loaded into the monitor.
				set transfer_segments [list]
				foreach infile [lrange $seg_list 0 end-1] {
					if {$info(cam$n\_fsegs) < $fsegs_full} {
						puts $ifl "file $infile"
						lappend transfer_segments $infile
						incr info(cam$n\_fsegs)
					} else {
						break
					}
				}
				
				# Our list is complete.
				close $ifl
				
				# To be safe, we attempt to concatinate only if we have at least
				# one file in our list, although we should always have one or
				# more at this point.
				set num_segments [llength $transfer_segments]
				if {$num_segments > 0} {
					Videoarchiver_print "$info(cam$n\_id) Adding $num_segments\
						segments to [file tail $fname]." verbose
	
					# We take this opportunity to remove excess lines from the
					# text window.
					set when "deleting old text"
					$info(text) delete 1.0 "end [expr 0 - $info(num_lines_keep)] lines"			
					set start_ms [clock milliseconds]
					
					# We are going to copy the existing video file into a
					# temporary file, followed by copying one or more compressed
					# segments. We want the temporary file in the same directory
					# as the recording file so that, when we replace the
					# recording file with the temporary file, all we have to do
					# is delete the recording file and rename the temporary
					# file, rather than copying a video file. If we were to put
					# the temporary file in the segment directory, this might be
					# on a different volume from the recording directory, and
					# moving the completed temporary file would require copying
					# and deleting.
					set tempfile [file join $info(cam$n\_dir) Temporary.mp4]
					
					# Here is where the transfer of files into the current
					# recording file takes place. We use the ffmpeg
					# concatination function, passing to ffmpeg the list of
					# files to add to the recording file. The result is a new
					# file, Temporary.mp4. 
					set when "concatinating segments"
					exec $info(ffmpeg) \
						-nostdin -f concat -safe 0 -loglevel error \
						-i transfer_list.txt -c copy \
						[file nativename $tempfile] \
						 > transfer_log.txt
										
					# We replace the previous recording file with the newly
					# created video file, delete the old file, and delete all
					# the compressed segments from the segments directory.
					set when "renaming video file"
					foreach infile $transfer_segments {
						file delete $infile
					}
					file delete $fname
					file rename $tempfile $fname
				} else {
					# We don't expect to end up here. If we have more than one
					# segment, we must have at least one that we can transfer.
					# But we find that we can end up here if we change the 
					# recording length while we are recording.
					error "Expected segments but found none"
				}
			}
		} 
		
		# If we are still recording, and enough time has passed, re-synchronize the
		# camera clock.		
		if {($info(cam$n\_state) == "Record") \
			&& ([clock seconds] >= $info(prev_sync_time) + $config(sync_period_s))} {
			Videoarchiver_synchronize $n
			set info(prev_sync_time) [clock seconds]
		}

	} message]} {
		set error_description "ERROR: [string trim $message]\
			while $when for $info(cam$n\_id)."
		Videoarchiver_print $error_description
		LWDAQ_print $config(error_log) $error_description
		LWDAQ_post [list Videoarchiver_restart_recording $n]
		catch {file delete $tempfile}
		return ""
	}
	
	# Restore the background of the state label to white.
	LWDAQ_set_bg $info(cam$n\_state_label) white
	
	# If we are no longer recording, stop the transfer process, otherwise
	# re-post it.
	if {$info(cam$n\_state) == "Record"} {
		LWDAQ_post [list Videoarchiver_transfer $n $init]
		return ""
	} else {
		Videoarchiver_print "$info(cam$n\_id) Stopped remote\
			transfer process." 
		return ""
	}	
}

#
# Videoarchiver_stop stops recording, display, and streaming.
#
proc Videoarchiver_stop {n} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info
	
	# Find the camera in our list.
	set index [lsearch $info(cam_list) $n]
	
	# Exit if the camera does not exist.
	if {$index < 0} {
		Videoarchiver_print "ERROR: No camera with list index $n."
		return ""
	}
	
	# Set the state variable and reset the lag indicator.
	set info(cam$n\_state) "Stop"
	LWDAQ_set_bg $info(cam$n\_state_label) white
	set info(cam$n\_lag) "?"
	LWDAQ_set_fg $info(cam$n\_laglabel) gray

 	if {![winfo exists $info(window)]} {
 		set info(text) stdout
 	}
		
	Videoarchiver_monitor $n "Stop"
	
	if {![catch {puts $info(cam$n\_vchan) ""}]} {
		catch {puts $info(cam$n\_vchan) "videoplayer stop"}
		catch {puts $info(cam$n\_vchan) "exit"}
		catch {close $info(cam$n\_vchan)}
		Videoarchiver_print "$info(cam$n\_id) Stopped live view." $config(v_col)
	}
	LWDAQ_process_stop $info(cam$n\_vpid)
	
	Videoarchiver_print "$info(cam$n\_id) Stopping streaming, segmentation,\
		and compression."
	LWDAQ_update
	cd $info(main_dir)
	set ip [Videoarchiver_ip $n]
	catch {exec $info(ssh) \
		-o ConnectTimeout=$config(connect_timeout_s) \
		-o UserKnownHostsFile=/dev/null \
		-o StrictHostKeyChecking=no \
		-o LogLevel=error \
		-i [file join $info(keys_dir) id_rsa] \
		"$info(camera_login)@$ip" \
		$info(stop)]} message
	if {![regexp "SUCCESS" $message]} {
		Videoarchiver_print "ERROR: $info(cam$n\_id)\
			Failed to connect to $ip with ssh."
	}
	
	set info(cam$n\_state) "Idle"
	return ""
}

#
# Videoarchiver_stop_all stops all cameras.
#
proc Videoarchiver_stop_all {} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	foreach n $info(cam_list) {
		LWDAQ_post "Videoarchiver_stop $n" front
	}
	
	return ""
}

#
# Videoarchiver_record_all starts recording on all cameras.
#
proc Videoarchiver_record_all {} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	foreach n $info(cam_list) {
		LWDAQ_post "Videoarchiver_record $n"
	}
	
	return ""
}

#
# Videoarchiver_killall kills all ffmpeg processes.
#
proc Videoarchiver_killall {ip} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	if {$info(os) == "Windows"} {
		catch {eval exec [auto_execok taskkill] /IM ffmpeg.exe /F} message
		if {[regexp "SUCCESS" $message]} {
			Videoarchiver_print "Stopped additional ffmpeg processes." 
		}
	} else {
		catch {eval exec [auto_execok killall] -9 ffmpeg} message
		if {$message == ""} {
			Videoarchiver_print "Stopped additional ffmpeg processes." 
		}
	}
	return ""
}

#
# Videoarchiver_directory allows the user to pick a new master recording directory.
#
proc Videoarchiver_directory {{post 1}} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	# If we call this routine from a button, we prefer to post
	# its execution to the event queue, and this we can do by
	# adding a parameter of 1 to the end of the call. We put
	# the command at the front of the queue.
	if {$post} {
		LWDAQ_post [list Videoarchiver_directory 0] front
		return ""
	}

	# Don't try to change master recording directory if any camera is 
	# currently recording or even stalled.
	foreach n $info(cam_list) {
		if {($info(cam$n\_state) == "Record") || ($info(cam$n\_state) == "Stalled")} {
			Videoarchiver_print "ERROR: $info(cam$n\_id) Cannot change recording\
				directory during \"$info(cam$n\_state)\"."
			return ""
		}
	}

	# Ask the user to pick an existing directory. If they don't, 
	# we don't change the recording directory and we print out an 
	# error message.
	set dn [LWDAQ_get_dir_name $config(recording_dir)]
	if {![file exists $dn]} {
		Videoarchiver_print "ERROR: Proposed recording directory \"$dn\"\
			does not exist."
		return ""
	} else {
		set config(recording_dir) $dn
		return $dn
	}
	
	# If we get here, we are okay.
	return ""
}

#
# Videoarchiver_download_libraries downloads the Videoarchiver zip archive with the
# help of a web browser.
#
proc Videoarchiver_download_libraries {} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	set result [LWDAQ_url_open $info(library_archive)]
	if {[LWDAQ_is_error_result $result]} {
		Videoarchiver_print $result
	}
	return ""
}

#
# Videoarchiver_suggest_download prints a message with a text link suggesting that
# the user download the Videoarchiver directory to install ffmpeg.
#
proc Videoarchiver_suggest_download {} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	LWDAQ_print $info(text) ""
	LWDAQ_print $info(text) "  Click on link below to download Videoarchiver\
		library zip archive."
	$info(text) insert end "           "
	$info(text) insert end "$info(library_archive)" "textbutton download"
	$info(text) tag bind download <Button> Videoarchiver_download_libraries
	$info(text) insert end "\n"
	LWDAQ_print $info(text) {
After download, expand the zip archive. Move the entire Videoarchiver directory
into the same directory as your LWDAQ installation, so the LWDAQ and
Videoarchiver directories will be next to one another. You now have ffmpeg and
ssh installed for use by the Videoarchiver and Neuroplayer on Linux, MacOS, and
Windows.
	}
}

#
# Videoarchiver_check_libraries check to see if the ffpeg and ssh programs 
# are available at the command line, and issue warnings if not.
#
proc Videoarchiver_check_libraries {} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	set suggest 0
	LWDAQ_print -nonewline $info(text) "Checking for Videoarchiver directory... "
	if {![file exists $info(main_dir)]} {
		LWDAQ_print $info(text) "FAIL."
		set suggest 1
	} else {
		LWDAQ_print $info(text) "success."
		LWDAQ_print -nonewline $info(text) "Checking ssh utility... " 
		catch {exec $info(ssh) -V} message
		if {[regexp "OpenSSH" $message]} {
			LWDAQ_print $info(text) "success."
		} else {
			LWDAQ_print $info(text) "FAIL."
			LWDAQ_print $info(text) "ERROR: $message"
			if {$info(os) == "Windows"} {
				LWDAQ_print $info(text)"The ssh executable should be in\
					[file dirname $info(ssh)]."
				set suggest 1
			} else {
				LWDAQ_print $info(text) "Install ssh in\
					[file dirname $info(ssh)]."
			}
		}
		LWDAQ_print -nonewline $info(text) "Checking ffmpeg utility... " 
		catch {exec $info(ffmpeg) -h} message
		if {[regexp "Hyper" $message]} {
			LWDAQ_print $info(text) "success."
		} else {
			LWDAQ_print $info(text) "FAIL."
			LWDAQ_print $info(text) "ERROR: $message"
			LWDAQ_print $info(text) "The ffmpeg executable should be in\
				[file dirname $info(ffmpeg)]."
			set suggest 1
		}
	}
	if {$suggest} {
		Videoarchiver_suggest_download
	}
	return ""
}

#
# Videoarchiver_undraw_list removes the camera list from the Videoarchiver window.
#
proc Videoarchiver_undraw_list {} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	foreach n $info(cam_list) {
		set ff $info(window).cam_list.cam$n
		catch {destroy $ff}
	}
	return ""
}

#
# Videoarchiver_view chooses between calling the Videoarchiver's live or monitor
# procedures depending upon whether the camera is idle or recording
# respectively.
#
proc Videoarchiver_view {n} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	# Get IP address and open an interface socket.
	set ip [Videoarchiver_ip $n]

	# Don't try to contact a non-existent camera.
	if {$ip == $info(null_addr)} {
		Videoarchiver_print "ERROR: No camera with list index $n."
		return ""
	}
	
	switch $info(cam$n\_state) {
		"Idle" {LWDAQ_post "Videoarchiver_live $n" front}
		"Record" {LWDAQ_post "Videoarchiver_monitor $n" front}
		"Live" {return ""}
		default {
			Videoarchiver_print "ERROR: $info(cam$n\_id)\
				Cannot view during \"$info(cam$n\_state)\"."
			return ""
		}
	}

	return ""
}

#
# Videoarchiver_draw_list draws the current list of cameras in the 
# Videoarchiver window.
#
proc Videoarchiver_draw_list {} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	set f $info(window).cam_list
	if {![winfo exists $f]} {
		frame $f
		pack $f -side top -fill x
	}
	
	set padx 0
	
	foreach n $info(cam_list) {
	
		# If this camera's state variable does not exist, then create it now, as well
		# as other system parameters.
		if {![info exists info(cam$n\_state)]} {
			set info(cam$n\_state) "Idle"
			set info(cam$n\_vchan) "none"
			set info(cam$n\_vpid) "0"
			set info(cam$n\_prevseg) "V0000000000.mp4"
			set info(cam$n\_white) "0"
			set info(cam$n\_infrared) "0"
			set info(cam$n\_lag) "?"
		}

		set g $f.cam$n
		frame $g -relief sunken -bd 2
		pack $g -side top -fill x

		set ff $g.a
		frame $ff
		pack $ff -side top -fill x

		entry $ff.id_value -textvariable Videoarchiver_info(cam$n\_id) -width 8
		pack $ff.id_value -side left -expand 0
		
		label $ff.state -textvariable Videoarchiver_info(cam$n\_state) -fg blue -width 10
		pack $ff.state -side left -expand 0
		set info(cam$n\_state_label) $ff.state

		button $ff.record -text "Record" -fg red -padx $padx -command \
			[list LWDAQ_post "Videoarchiver_record $n" front]
		button $ff.stop -text "Stop" -fg black -padx $padx -command \
			[list LWDAQ_post "Videoarchiver_stop $n" front]
		button $ff.view -text "View" -fg green -padx $padx -command \
			[list LWDAQ_post "Videoarchiver_view $n" front]
		pack $ff.record $ff.view $ff.stop -side left -expand 1

		button $ff.ch -text "IP" -padx $padx -command [list Videoarchiver_ask_ip $n]
		pack $ff.ch -side left -expand 1
	
		entry $ff.addr_value -textvariable Videoarchiver_info(cam$n\_addr) -width 14
		pack $ff.addr_value -side left -expand 0

		label $ff.rotl -text "Rot:" -fg brown -justify right
		pack $ff.rotl -side left -expand 0
		set m [tk_optionMenu $ff.rotm Videoarchiver_info(cam$n\_rot) none]
		$m delete 0 end
		foreach rotation $info(rotation_options) {
			$m add command -label "$rotation" \
				-command [list set Videoarchiver_info(cam$n\_rot) $rotation]
		}	
		pack $ff.rotm -side left -expand 1
	
		label $ff.satl -text "Sat:" -fg brown -justify right
		pack $ff.satl -side left -expand 0
		set m [tk_optionMenu $ff.satm Videoarchiver_info(cam$n\_sat) none]
		$m delete 0 end
		for {set sat 0.0} {$sat <= 1.0} {set sat [format %.1f [expr $sat + 0.1]]} {
			$m add command -label "$sat" \
				-command [list set Videoarchiver_info(cam$n\_sat) $sat]
		}	
		pack $ff.satm -side left -expand 1

		label $ff.ecl -text "Exp:" -fg brown -justify right
		pack $ff.ecl -side left -expand 0
		set m [tk_optionMenu $ff.ecm Videoarchiver_info(cam$n\_ec) none]
		$m delete 0 end
		for {set ec 0.0} {$ec <= 1.0} {set ec [format %.1f [expr $ec + 0.1]]} {
			$m add command -label "$ec" \
				-command [list set Videoarchiver_info(cam$n\_ec) $ec]
		}	
		pack $ff.ecm -side left -expand 1

		label $ff.wl -text "Wht:" -padx $padx -fg brown -justify right
		pack $ff.wl -side left -expand 0
		set m [tk_optionMenu $ff.wm Videoarchiver_info(cam$n\_white) none]
		$m delete 0 end
		foreach a $info(lamp_dac_values) {
			$m add command -label "$a" \
				-command [list LWDAQ_post "Videoarchiver_setlamp $n white $a" front]
		}
		pack $ff.wm -side left -expand 1
		
		label $ff.irl -text "IR:" -padx $padx -fg brown -justify right
		pack $ff.irl -side left -expand 0
		set m [tk_optionMenu $ff.irm Videoarchiver_info(cam$n\_infrared) none]
		$m delete 0 end
		foreach a $info(lamp_dac_values) {
			$m add command -label "$a" \
				-command [list LWDAQ_post "Videoarchiver_setlamp $n infrared $a" front]
		}
		pack $ff.irm -side left -expand 1

		button $ff.query -text "Q" -fg black -padx $padx -command \
			[list LWDAQ_post "Videoarchiver_query $n" front]
		button $ff.update -text "U" -fg black -padx $padx -command \
			[list LWDAQ_post "Videoarchiver_update $n"]
		button $ff.reboot -text "R" -fg black -padx $padx -command \
			[list LWDAQ_post "Videoarchiver_reboot $n"]
		pack $ff.query $ff.update $ff.reboot -side left -expand 1
		set info(cam$n\_laglabel) [label $ff.lag -textvariable \
			Videoarchiver_info(cam$n\_lag) \
			-width 3 -bg lightgray -fg gray]
		pack $ff.lag -side left -expand 1
		button $ff.delete -text "X" -padx $padx -command \
			[list LWDAQ_post "Videoarchiver_ask_remove $n" front]
		pack $ff.delete -side left -expand yes
	}
	return ""
}

#
# Videoarchiver_ask_remove ask if the user is certain they want to remove a 
# camera from the list.
#
proc Videoarchiver_ask_remove {n} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	# Find the camera in our list.
	set index [lsearch $info(cam_list) $n]
	
	# Exit if the camera does not exist.
	if {$index < 0} {
		Videoarchiver_print "ERROR: No camera with list index $n."
		return ""
	}
	
	set w $info(window)\.remove$n
	if {[winfo exists $w]} {
		raise $w
		return ""
	}
	toplevel $w
	wm title $w "Remove Camera $info(cam$n\_id)"
	label $w.q -text "Remove Camera $info(cam$n\_id)?" \
		-padx 10 -pady 5 -fg purple
	button $w.yes -text "Yes" -padx 10 -pady 5 -command \
		[list LWDAQ_post "Videoarchiver_remove $n" front]
	button $w.no -text "No" -padx 10 -pady 5 -command \
		[list LWDAQ_post "destroy $w" front]
	pack $w.q $w.yes $w.no -side left -expand yes

	return ""
}

#
# Videoarchiver_remove remove a camera from the list.
#
proc Videoarchiver_remove {n} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	# Find the camera in our list.
	set index [lsearch $info(cam_list) $n]
	
	# If a remove window exists, destroy it
	set w $info(window)\.remove$n
	if {[winfo exists $w]} {destroy $w}

	# Exit if the camera does not exist.
	if {$index < 0} {
		Videoarchiver_print "ERROR: No camera with list index $n."
		return ""
	}
	
	# Check the state of the camera.
	if {$info(cam$n\_state) != "Idle"} {
		Videoarchiver_print "ERROR: $info(cam$n\_id) Wait until Idle\
			before removing camera from list."
		return ""
	}
	
	catch {destroy $info(window).cam_list.cam$n}
	set info(cam_list) [lreplace $info(cam_list) $index $index]
	catch {
		unset info(cam$n\_id)
		unset info(cam$n\_ver)
		unset info(cam$n\_addr)
		unset info(cam$n\_rot)
		unset info(cam$n\_sat)
		unset info(cam$n\_ec)
		unset info(cam$n\_state)
		unset info(cam$n\_vchan)
		unset info(cam$n\_vpid)
		unset info(cam$n\_prevseg)
		unset info(cam$n\_white)
		unset info(cam$n\_infrared)
		unset info(cam$n\_lag)
		unset info(cam$n\_laglabel)
	}
	
	return ""
}

#
# Videoarchiver_add_camera adds a new camera to the list.
#
proc Videoarchiver_add_camera {} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	# Delete the list display.
	Videoarchiver_undraw_list
	
	# Find a new index for this sensor, add the new id to the list.
	set n 1
	while {[lsearch $info(cam_list) $n] >= 0} {
		incr n
	}
	
	# Add the new sensor index to the list.
	lappend info(cam_list) $n
	
	# Configure the new sensor to default values.
	set info(cam$n\_id) "Z000$n"
	set info(cam$n\_ver) "unknown"
	set info(cam$n\_addr) $info(default_ip_addr)
	set info(cam$n\_rot) $info(default_rot)
	set info(cam$n\_sat) $info(default_sat)
	set info(cam$n\_ec) $info(default_ec)
	set info(cam$n\_dir) [file normalize "~/Desktop"]
	set info(cam$n\_state) "Idle"
	set info(cam$n\_vchan) "none"
	set info(cam$n\_vpid) "0"
	set info(cam$n\_prevseg) "V0000000000.mp4"
	set info(cam$n\_white) "0"
	set info(cam$n\_infrared) "0"
	set info(cam$n\_lag) "?"
	
	# Re-draw the sensor list.
	Videoarchiver_draw_list
	
	return ""
}

#
# Videoarchiver_save_list save a camera list to disk. Returns the file to which 
# it saves the list.
#
proc Videoarchiver_save_list {{fn ""}} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info
	
	
	# Try to get a valid file name.
	if {$fn == ""} {
		set fn [LWDAQ_put_file_name "CamList.tcl"]
		if {$fn == ""} {return ""}
	}

	# Write camera list to disk.
	set f [open $fn w]
	puts $f "set Videoarchiver_info(cam_list) \"$info(cam_list)\""
	foreach n $info(cam_list) {
		foreach a {id ver addr rot sat ec} {
			puts $f "set Videoarchiver_info(cam$n\_$a) \"[set info(cam$n\_$a)]\"" 
		}
	}
	close $f
	
	# Change the camera list file parameter.
	set config(cam_list_file) $fn

	return $fn
}

#
# Videoarchiver_load_list loads a camera list from disk. If we don't
# specify the list file name, the routine uses a browser to get a file
# name. Returns the name of the list.
#
proc Videoarchiver_load_list {{fn ""}} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info
	
	# We won't load a new list so long as even one camera is not idle.
	foreach n $info(cam_list) {
		if {$info(cam$n\_state) != "Idle"} {
			Videoarchiver_print "ERROR: $info(cam$n\_id) Cannot load new camera\
				list during \"$info(cam$n\_state)\"."
			return ""
		}
	}

	# Try to get a valid file name.
	if {$fn == ""} {
		set fn [LWDAQ_get_file_name]		
		if {$fn == ""} {return ""}
	} else {
		if {![file exists $fn]} {return ""}
	}

	# Undraw the list, run the camera list file, and re-draw the list.
	if {[catch {
		Videoarchiver_undraw_list	
		set info(cam_list) [list]
		uplevel #0 [list source $fn]
		Videoarchiver_draw_list
		foreach n $info(cam_list) {
			set info(cam$n\_state) "Idle"
			set info(cam$n\_lag) "?"
		}
	} error_message]} {
		Videoarchiver_print "ERROR: $error_message."
		return
	}
	
	# Change the camera list file name to match the newly-loaded file.
	set config(cam_list_file) $fn
	
	return $fn
}

#
# Videoarchiver_configure opens the standard tool configuration window,
# and adds some special buttons.
#
proc Videoarchiver_configure {} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info
	
	# This is the standard configuration routine, which returns the name
	# of a frame widget into which we can put more buttons.
	set f [LWDAQ_tool_configure $info(name) 2]
	
	# Routines to view and clear the error log. We make sure they run
	# in the LWDAQ event queue so we don't get a file access conflict
	# with the recording processes.
	foreach a {View_Error_Log Clear_Error_Log} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post Videoarchiver_$b"
		pack $f.$b -side top -expand 1
	}
	
	return "" 
}

#
# Videoarchiver_lamps_adjust sets all lamps of a particular color to a specified
# intensity, but does so taking "step" seconds per change in intensity. It uses
# the intensity value stored in the camera info arrays to find the current
# intensity.
#
proc Videoarchiver_lamps_adjust {color intensity {step "1"} {previous "0"}} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info
	
	if {$previous == 0} {
		Videoarchiver_print "Started adjustment of $color lamps to intensity\
			$intensity with step $step s at\
			[clock format [clock seconds] -format $config(datetime_format)]."
	}
	
	if {[clock seconds] - $previous < $step} {
		LWDAQ_post [list Videoarchiver_lamps_adjust $color $intensity $step $previous]
		return ""
	} else {
		set done 1
		foreach n $info(cam_list) {
			set current_intensity [set info(cam$n\_$color)]
			if {$intensity > $current_intensity} {
				Videoarchiver_setlamp $n $color [expr $current_intensity + 1]
				set done 0
			} elseif {$intensity < $current_intensity}  {
				Videoarchiver_setlamp $n $color [expr $current_intensity - 1]
				set done 0
			}
		}
		if {!$done} {
			LWDAQ_post [list Videoarchiver_lamps_adjust \
				$color $intensity $step [clock seconds]]
			return ""
		} else {
			Videoarchiver_print "Completed adjustment of $color lamps to intensity\
				$intensity at [clock format [clock seconds] \
				-format $config(datetime_format)]."
			return ""
		}
	}		
}

#
# Videoarchiver_lamps_off turns off all the white and infrared lamps of the
# cameras in the camera list.
#
proc Videoarchiver_lamps_off {} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	foreach n $info(cam_list) {
		Videoarchiver_setlamp $n white [lindex $info(lamp_dac_values) 0]
		Videoarchiver_setlamp $n infrared [lindex $info(lamp_dac_values) 0]
	}		
	return ""
}

#
# Videoarchiver_scheduler opens a panel that allows the user to define, start,
# and stop a twenty-four lamp fade schedule. The panel does not perform the
# scheduling itself, but instead uses the LWDAQ built-in scheduler defined by
# the LWDAQ_scheduler routine.
#
proc Videoarchiver_scheduler {} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info
	global LWDAQ_Info

	# Open the scheduler panel.
	set w $info(scheduler_panel)
	if {[winfo exists $w]} {
		raise $w
		return ""
	}
	toplevel $w
	wm title $w "Scheduler Panel for Videoarchiver $info(version)"

	# Create the start and stop controls.
	set f [frame $w.control]
	pack $f -side top -fill x
	label $f.state -textvariable Videoarchiver_info(scheduler_state) -fg blue -width 10
	button $f.start -text "Start" -command "LWDAQ_post Videoarchiver_schedule_start"
	button $f.stop -text "Stop" -command "LWDAQ_post Videoarchiver_schedule_stop"
	pack $f.state $f.start $f.stop -side left -expand yes
	
	# Create the schedule definition entries.
	foreach a {white_on white_off infrared_on infrared_off} {
		set f [frame $w.$a -relief sunken -bd 2] 
		pack $f -side top -fill x
		label $f.l$a -text "Task:" -fg brown -width 6 -justify right
		pack $f.l$a -side left -expand yes
		label $f.$a -text $a -justify left -width 15
		pack $f.$a -side left -expand yes

		label $f.lmin -text "Minute:" -fg brown -justify right
		pack $f.lmin -side left -expand 0
		set m [tk_optionMenu $f.mmin Videoarchiver_info($a\_min) "*"]
		$m delete 0 end
		foreach value {* 0 5 10 15 20 25 30 35 40 45 50 55} {
			$m add command -label "$value" \
				-command [list set Videoarchiver_info($a\_min) $value]
		}	
		pack $f.mmin -side left -expand 1

		label $f.lhr -text "Hour:" -fg brown -justify right
		pack $f.lhr -side left -expand 0
		set m [tk_optionMenu $f.mhr Videoarchiver_info($a\_hr) "*"]
		$m delete 0 end
		foreach value {* 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23} {
			$m add command -label "$value" \
				-command [list set Videoarchiver_info($a\_hr) $value]
		}	
		pack $f.mhr -side left -expand 1

		label $f.ldymo -text "Day of Month:" -fg brown -justify right
		pack $f.ldymo -side left -expand 0
		set m [tk_optionMenu $f.mdymo Videoarchiver_info($a\_dymo) "*"]
		$m delete 0 end
		foreach value {* 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 \
				15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31} {
			$m add command -label "$value" \
				-command [list set Videoarchiver_info($a\_dymo) $value]
		}	
		pack $f.mdymo -side left -expand 1

		label $f.lmo -text "Month:" -fg brown -justify right
		pack $f.lmo -side left -expand 0
		set m [tk_optionMenu $f.mmo Videoarchiver_info($a\_mo) "*"]
		$m delete 0 end
		foreach value {* 0 1 2 3 4 5 6 7 8 9 10 11 12} {
			$m add command -label "$value" \
				-command [list set Videoarchiver_info($a\_mo) $value]
		}	
		pack $f.mmo -side left -expand 1

		label $f.ldywk -text "Day of Week:" -fg brown -justify right
		pack $f.ldywk -side left -expand 0
		set m [tk_optionMenu $f.mdywk Videoarchiver_info($a\_dywk) "*"]
		$m delete 0 end
		$m add command -label "*" -command [list set Videoarchiver_info($a\_dywk) "*"]
		set index 0
		foreach value {Sunday Monday Tuesday Wednesday Thursday Friday Saturday} {
			$m add command -label "$value" \
				-command [list set Videoarchiver_info($a\_dywk) $index]
			incr index
		}	
		pack $f.mdywk -side left -expand 1

		label $f.lint -text "Intensity:" -fg brown -justify right
		pack $f.lint -side left -expand 0
		set m [tk_optionMenu $f.mint Videoarchiver_info($a\_int) "0"]
		$m delete 0 end
		foreach value {0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15} {
			$m add command -label "$value" \
				-command [list set Videoarchiver_info($a\_int) $value]
		}	
		pack $f.mint -side left -expand 1

		label $f.lstep -text "Step (s):" -fg brown -justify right
		pack $f.lstep -side left -expand 0
		entry $f.estep -textvariable Videoarchiver_info($a\_step) -width 5
		pack $f.estep -side left -expand 1
	}
	
	return ""
}

#
# Videoarchiver_schedule_start schedules all Videoarchiver scheduled tasks. We direct
# the scheduler output to the videoarchiver text window.
#
proc Videoarchiver_schedule_start {} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info
	global LWDAQ_Info

	set LWDAQ_Info(scheduler_log) $info(text)
	foreach a {white_on white_off infrared_on infrared_off} {
		set schedule "$info($a\_min) $info($a\_hr) $info($a\_dymo)\
			$info($a\_mo) $info($a\_dywk)"
		LWDAQ_schedule_task $a $schedule \
			"Videoarchiver_lamps_adjust [regsub {_.*} $a ""]\
				$info($a\_int) $info($a\_step)"
		Videoarchiver_print "Scheduled task $a\
			with schedule \"$schedule\"\
			intensity $info($a\_int)\
			and step interval $info($a\_step) s."
	}
	set info(scheduler_state) "Run"
	return ""
}

#
# Videoarchiver_schedule_stop deletes all Videoarchiver tasks from the LWDAQ schedule
# list.
#
proc Videoarchiver_schedule_stop {} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	LWDAQ_unschedule_task "white_on"
	LWDAQ_unschedule_task "white_off"
	LWDAQ_unschedule_task "infrared_on"
	LWDAQ_unschedule_task "infrared_off"
	LWDAQ_queue_clear "Videoarchiver_lamps_*"
	set info(scheduler_state) "Stop"
	Videoarchiver_print "Unscheduled all tasks, aborted all tasks,\
		aborted tasks remain incomplete."
	return ""
}

#
# Videoarchiver_open creates the Videoarchiver's user interface.
#
proc Videoarchiver_open {} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	# Open the tool window. If we get an empty string back from the opening
	# routine, something has gone wrong, or a window already exists for this
	# tool, so we abort.
	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
	
	# Get on with creating the display in the tool's frame or window.	
	set padx 0
	set f $w.f1
	frame $f -pady $padx -padx $padx
	pack $f -side top -fill x
	
	foreach a {Record_All Stop_All Lamps_Off Scheduler Directory} {
		set b [string tolower $a]
		button $f.$b -text $a -padx $padx \
			-command [list LWDAQ_post "Videoarchiver_$b" front]
		pack $f.$b -side left -expand 1
	}
	
	entry $f.dire -textvariable Videoarchiver_config(recording_dir) -width 30
	pack $f.dire -side left -expand 1
	
	foreach a {Add_Camera Save_List Load_List Configure} {
		set b [string tolower $a]
		button $f.$b -text $a -padx $padx \
			-command [list LWDAQ_post "Videoarchiver_$b" front]
		pack $f.$b -side left -expand 1
	}
	
	foreach a {Help} {
		set b [string tolower $a]
		button $f.$b -text $a -padx $padx \
			-command [list LWDAQ_post "LWDAQ_tool_$b $info(name)" front]
		pack $f.$b -side left -expand 1
	}
		
	checkbutton $f.verbose -text "Verbose" -variable Videoarchiver_config(verbose)
	pack $f.verbose -side left -expand 1

	if {[llength $info(cam_list)] == 0} {
		Videoarchiver_add_camera
	} else {
		Videoarchiver_draw_list
	}

	set info(text) [LWDAQ_text_widget $w 120 10]
	$info(text) tag configure textbutton -background cyan
	$info(text) tag bind textbutton <Enter> {%W configure -cursor arrow} 
	$info(text) tag bind textbutton <Leave> {%W configure -cursor xterm} 

	Videoarchiver_print "$info(name) Version $info(version)" purple
	
	
	# If the camera list file exist, load it.
	if {[file exists $config(cam_list_file)]} {
		Videoarchiver_load_list $config(cam_list_file)
	}
	
	Videoarchiver_check_libraries
	
	return $w
}

Videoarchiver_init
Videoarchiver_open

return ""

----------Begin Help----------

http://www.opensourceinstruments.com/Electronics/A3034/Videoarchiver.html

----------End Help----------

----------Begin Data----------
<script>
#
# Videoarchiver/interface.tcl
#
# The TCPIP interface process that runs on the camera. It opens a server socket
# that will receive connections and allow us to download files, get directory
# listings, and other tasks. We assume its stdout it directed to a log file.

# WARNING: No single-quotation marks allowed in this script, because we use
# secure shell to upload the entire script to a file on the Pi, and a single
# quote markes the end of a Bash argument.

# Get the command line arguments.
set port 2223
set verbose 0
set maxshow 50
foreach {option value} $argv {
	switch $option {
		"-port" {
			set listenport $value
		}
		"-verbose" {
			set verbose $value
		}
		"-maxshow" {
			set maxshow $value
		}
		default {
			puts "WARNING: Unknown option \"$option\"."
		}
	}
}

# Determine the operating system version.
set f [open videoarchiver.config r]
set contents [read $f]
close $f
if {[regexp "os Bullseye" $contents]} {
	set os "Bullseye"
} else {
	set os "Stretch"
}
			
# Announce the start of interface in stdout.
puts "Starting interface process at [clock format [clock seconds]] with:"
puts "verbose = $verbose, port = $port, maxshow = $maxshow, os = $os."

# The socket acceptor receives a connection, sets up a socket channel, and
# configures it so that every time it is readable, the incoming data is passed
# to the interpreter procesdure.
proc accept {sock addr port} {
	global verbose

	# Configure the socket with line buffering, so it can receive text 
	# commands with ease.
	fconfigure $sock -translation auto -buffering line
	
	# Call the interpreter every time a complete command has been received.
	fileevent $sock readable [list interpreter $sock]
	
	if {$verbose} {puts "$sock connection from $addr at\
		[clock format [clock seconds]]."}
	return ""
}

# The interpreter implements a set of commands for the Videoarchiver. We call
# this procedure whenever the socket is readable.
proc interpreter {sock} {
	global verbose maxshow os

	# If the client closes the socket, we do the same.
	if {[eof $sock]} {
		if {$verbose} {puts "$sock closed by client at\
			[clock format [clock seconds]]."}
		close $sock
		return ""
	}	
	
	# Read the command line from the socket.
	if {[catch {gets $sock line} result]} {
		if {$verbose} {puts "$sock broken at\
			[clock format [clock seconds]]."}
		close $sock
		return ""
	}

	# We ignore empty commands.
	set line [string trim $line]
	if {$line == ""} {return ""}

	# If verbose, write the command to the log file.
	if {$verbose} {
		if {[string length $line] > $maxshow} {
			puts "$sock read: \"[string range $line 0 $maxshow]\...\""
		} else {
			puts "$sock read: \"$line\""
		}
	}

	# Set up command and paramters.
	set cmd [lindex $line 0]
	set argv [lrange $line 1 end]
	
	if {[catch {
		# The getfile command asks the interface to read a named file, transmit
		# its size as a string, then transmit the entire file contents as a
		# binary object.
		if {$cmd == "getfile"} {
			
			# If the file exists, read its contents. When we read the file, we
			# assume it is binary so that we can read any type of file. If the
			# file does not exist, we set the contents to an empty string and
			# the size to zero.
			set fn [lindex $argv 0]
			if {[file exists $fn]} {
				set f [open $fn r]
				fconfigure $f -translation binary
				set contents [read $f]
				close $f
				if {$verbose} {
					puts "$sock getfile \"$fn\" size [string length $contents] bytes\
						at [clock seconds]."
				}
			} else {
				set contents ""
				if {$verbose} {
					puts "$sock getfile \"$fn\" does not exist at\
						[clock format [clock seconds]]."
				}
			}
			
			# Transmit the size of the file contents so the client will know how
			# many bytes it must read. If the file does not exist, the file size
			# will be zero, but we raise no other error.
			puts $sock [string length $contents]
			
			# Now reconfigure the socket for binary data with full buffering and
			# send the contents without a line break at the end. Flush the
			# socket.
			fconfigure $sock -translation binary -buffering full
			puts -nonewline $sock $contents
			flush $sock
			
			# Return the socket to line buffering and automatic line break
			# translation.
			fconfigure $sock -translation auto -buffering line
	
		# The putfile command takes a filename and file contents and writes the
		# contents to the filename on disk. First the command obtains the file
		# name and the size of the file from the command line, then waits for
		# the data to be downloaded over the socket.
		} elseif {$cmd == "putfile"} {
			
			# Get the file name and the size of the contents.
			set fn [lindex $argv 0]
			set size [lindex $argv 1]
			if {$verbose} {
				puts "$sock putfile \"$fn\" size $size bytes at\
					[clock format [clock seconds]]."
			}
			
			# Now reconfigure the socket for binary data with full buffering and
			# receive the contents.
			fconfigure $sock -translation binary -buffering full
			set contents [read $sock $size]

			# Write the contents to disk.
			set f [open $fn w]
			puts -nonewline $f $contents
			close $f			
			if {$verbose} {
				puts "Wrote $size bytes to \"$fn\" at\
					[clock format [clock seconds]]."
			}
			
			# Return the socket to line buffering and automatic line break
			# translation.
			fconfigure $sock -translation auto -buffering line
			
			# Send back the number of bytes written.
			puts $sock $size
			
		# The mkdir command creates a new directory if it does not exist.
		} elseif {$cmd == "mkdir"} {
			
			# Get the directory name and report it.
			set dn [lindex $argv 0]
			if {$verbose} {
				puts "$sock mkdir \"$dn\" at [clock format [clock seconds]]."
			}

			# Make the directory.
			if {![file exists $dn]} {
				file mkdir $dn
			}
			
			# Return the directory name as success.
			puts $sock $dn

		# The sockname command returns the local name of the socket so we can
		# refer to the socket in subsequent commands.
		} elseif {$cmd == "sockname"} {
			puts $sock $sock
	
		# The gettemp command returns the CPU temperture
		} elseif {$cmd == "gettemp"} {
			set tempstring [exec /usr/bin/vcgencmd measure_temp]
			regexp {=([0-9\.]*)} $tempstring match temperature
			puts $sock $temperature
	
		# The getfreq command returns the CPU clock frequency in GHz.
		} elseif {$cmd == "getfreq"} {
			set freqstring [exec /usr/bin/vcgencmd measure_clock arm]
			regexp {=([0-9]*)} $freqstring match frequency
			set frequency [expr 1.0*$frequency/1e9]
			puts $sock [format %.2f $frequency]
	
		# The setip command sets the static IP address of the camera by
		# re-writing the dhcpcd.conf file. It then shuts off the Ethernet
		# interface and turns it on again, which closes the socket.
		} elseif {$cmd == "setip"} {
			set new_ip [lindex $argv 0]
			if {![regexp {[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+} $new_ip]} {
				error "Invalid internet protocol address \"$new_ip\""
			}
			set new_router [lindex $argv 1]
			if {![regexp {[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+} $new_router]} {
				error "Invalid router internet protocol address \"$new_router\""
			}
			set f [open dhcpcd_default.conf r]
			set contents [read $f]
			close $f
			set contents [regsub -all 10.0.0.34 $contents $new_ip]
			set contents [regsub -all 0.0.0.0 $contents $new_router]
			set f [open temp.txt w]
			puts $f $contents
			close $f
			exec sudo cp temp.txt /etc/dhcpcd.conf
			exec rm temp.txt
			puts $sock $new_ip
			after 100
			close $sock
			exec sudo ifconfig eth0 down
			after 100
			exec sudo ifconfig eth0 up
			
		# Set the white or infrared lamp intensity.
		} elseif {$cmd == "setlamp"} {
			set color [lindex $argv 0]
			if {($color != "white") && ($color != "infrared")} {
				error "Invalid lamp color \"$color\""
			}
			set intensity [expr [lindex $argv 1] % 16]
			if {![string is integer -strict $intensity]} {
				error "Non-integer intensity \"$intensity\""
			}
			if {($intensity < 0) || ($intensity > 15) } {
				error "Intensity $intensity out of range 0-15"
			}
			
			# Extract the bit values from the intensity.
			binary scan [binary format c $intensity] B8 bits
			set D3 [string index $bits 4]
			set D2 [string index $bits 5]
			set D1 [string index $bits 6]
			set D0 [string index $bits 7]
			
			# Set the white or infrared lamp intensity. We use a different
			# input-ouput routine depending upon the operating system.
			if {$os == "Bullseye"} {
				if {$D3 == "1"} {set D3 "dh"} {set D3 "dl"}
				if {$D2 == "1"} {set D2 "dh"} {set D2 "dl"}
				if {$D1 == "1"} {set D1 "dh"} {set D1 "dl"}
				if {$D0 == "1"} {set D0 "dh"} {set D0 "dl"}
				if {$color == "white"} {
					exec raspi-gpio set 2 op $D0
					exec raspi-gpio set 3 op $D1
					exec raspi-gpio set 4 op $D2
					exec raspi-gpio set 14 op $D3
				} else {
					exec raspi-gpio set 16 op $D0
					exec raspi-gpio set 26 op $D1
					exec raspi-gpio set 20 op $D2
					exec raspi-gpio set 21 op $D3
				}
			} else {
				if {$color == "white"} {
					exec gpio -g write 2 $D0
					exec gpio -g write 3 $D1
					exec gpio -g write 4 $D2
					exec gpio -g write 14 $D3				
				} else {
					exec gpio -g write 16 $D0
					exec gpio -g write 26 $D1
					exec gpio -g write 20 $D2
					exec gpio -g write 21 $D3				
				}
			}
			
			# Return the intensity as confirmation.
			puts $sock $intensity	
			
		# By default, the interface evaluates the entire line as a command at
		# the global scope, and returns the result of the command.
		} else {
			set result [uplevel #0 $line]
			puts $sock $result
		}
	} message]} {
		puts "ERROR: $message, at [clock format [clock seconds]]."
		puts $sock "ERROR: $message."
	}
	
	return "$sock"
}

# Set up a server listening on the specified port.
set sock [socket -server accept $port]
puts "Listening on port $port..."

# This vwait for undefined variable "quit" stops the shell from exiting.
vwait quit
</script>

<script>
#
# Videoarchiver/manager.tcl
#
# The manager takes new video segments, spawns compression processes to compress
# the segments, and makes the compressed segments available for download by the
# Videoarchiver in order of oldest to newest. 
#

# Get the command line arguments.
set framerate "20"
set maxfiles "40"
set processes "3"
set crf "23"
set codec "libx264"
set preset "veryfast"
set rotation "0"
set verbose "0"
set loopwait "100"
set segdir "tmp"
set maxage "40"
set seglen "2"
foreach {option value} $argv {
	switch $option {
		"-framerate" {
			set framerate $value
		}
		"-maxfiles" {
			set maxfiles $value
		}
		"-processes" {
			set processes $value
		}
		"-crf" {
			set crf $value
		}
		"-codec" {
			set codec $value
		}
		"-preset" {
			set preset $value
		}
		"-rotation" {
			set rotation $value
		}
		"-verbose" {
			set verbose $value
		}
		"-loopwait" {
			set loopwait $value
		}
		"-segdir" {
			set segdir $value
		}
		"-maxage" {
			set maxage $value
		}
		"-seglen" {
			set seglen $value
		}
		default {
			puts "ERROR: Unknown option \"$option\"."
		}
	}
}

# Announce the start of compression to stdout.
puts "Starting compression manager at [clock format [clock seconds]] with:"
puts "framerate = $framerate fps, codec = $codec, crf = $crf, preset = $preset,"
puts "maxfiles = $maxfiles, processes = $processes, verbose = $verbose,\
	segdir = $segdir, rotation = $rotation."

# Initialize our compressor list.
set compressors [list]

# An infinite loop. This process must be killed if it is to be stopped.
while {1} {

	# Begin with a delay.
	after $loopwait

	# Get a list of all the uncompressed files.
	set sfl [lsort -increasing [glob -nocomplain $segdir/S*.mp4]]
 
	# Look for excessive number of uncompressed segments. If there are more than
	# maxfiles, delete some of the oldest, but not the oldest, because they
	# might be involved in the start of a compression. We delete as many files
	# as there are processes.
	if {[llength $sfl] >= $maxfiles} {
		puts "ERROR: Too many uncompressed segments, deleting $processes\
			segments at time [clock format [clock seconds]]."
		for {set i $processes} {$i < 2*$processes} {incr i} {
			if {[catch {
				file delete [lindex $sfl $i]
			} message]} {
				puts "ERROR: $message."
			}
		}
	}
	
	# If there is more than one uncompressed segment available, and our compressor list
	# is not full, compress the eldest file that still exists.
	if {([llength $sfl] > 1) && ([llength $compressors] < $processes)} {
	
		# Check the file name is of the correct format. If not, we delete it and continue.
		set sfn [lindex $sfl 0]
		if {![regexp {S([0-9]{10})} [file tail $sfn] match timestamp]} {
			puts "ERROR: Bad segment name \"[file tail $sfn]\",\
				deleting segment at time [clock format [clock seconds]]."
			catch {file delete $sfn}
			continue
		}
	
		# Use the timestamp to construct the temporary name.
		set tfn $segdir/T$timestamp\.mp4
		
		# Check that the temporary file does not exist already. If it does, 
		# delete the temporary file.
		if {[file exists $tfn]} {
			puts "ERROR: File \"[file tail $tfn]\" already exists, deleting."
			catch {file delete $tfn}
			continue
		}
		
		# Rename the segment so that we will not try to compress it twice.
		if {[catch {file rename $sfn $tfn} message]} {
			puts "ERROR: $message."
			continue
		}
		
		# Spawn a compressor to compress the temporary file. The Pi has a
		# graphics processor, which we can enlist with the h264_omx codec, but
		# the graphics processor is not capable of compressing video of the
		# quality we require in real time. We instead enlist multiple processor
		# cores to compress our segments using the ffmpeg libx264 codec. The
		# number of processes we enlist is given by our "processes" argument.
		if {$verbose} {
			puts "Starting compression of $sfn."
		}
		if {[catch {
			set pid [exec tclsh compressor.tcl \
				-infile $tfn \
				-framerate $framerate \
				-seglen $seglen \
				-codec $codec \
				-crf $crf \
				-preset $preset \
				-rotation $rotation \
				-verbose $verbose \
				>> compressor_log.txt &]
		} message]} {
			puts "ERROR: $message starting compression of [file tail $tfn]."
		} else {
		# If we did not encounter an error, we add the timestamp and process
		# id to our compressor list.
			lappend compressors $timestamp		
		}
	}
	
	# Check the first entry in our compressor list to see if it is complete.
	if {[llength $compressors] > 0} {
	
		# We get the timestamp from the compressor list and use it to construct
		# the temporary name, working name, and final segment name.
		set timestamp [lindex $compressors 0 0]
		set tfn $segdir/T$timestamp\.mp4
		set wfn $segdir/W$timestamp\.mp4
		set vfn $segdir/V$timestamp\.mp4
	
		# If the temporary file no longer exists, compression is complete.
		if {![file exists $tfn]} {
		
			# Rename the output file. The compressed file is available for
			# download. Report any error but proceed anyway.
			if {[catch {file rename $wfn $vfn} message]} {
				puts "ERROR: $message\."
			}
			
			# Delete this compressor from the list.
			set compressors [lrange $compressors 1 end]
		} else {
		# If the file does exist, we check to see how old it is, and if it is
		# too old, we kill the compressor process and delete its files. We report
		# an error.
			if {[clock seconds] - $timestamp > $maxage} {
				set pid [lindex $compressors 0 1]
				catch {exec kill $pid}
				catch {rm $tfn}
				catch {rm $wfn}
				set compressors [lrange $compressors 1 end]
				puts "ERROR: Compression of $tfn frozen, now killed, segment lost."
			}
		}
	}
}
</script>

<script>
#
# Videoarchiver/compressor.tcl
#
# Compression engine to run on the Raspberry Pi. The compression_manager calls
# the compressor, passing it a file name. The file must be a video segment, and
# the name must be in the form Tx.mp4, where x is a UNIX time. The compressor
# compresses the segment into another file named Wx.mp4. When it's done, the
# compressor deletes Tx.mp4 and exits. It reports errors to stdout, which the
# compression_manager can redirect wherever it likes. With the verbose option,
# the compressor reports progress to stdout as well. We assume that the process
# spawning the compressor has redirected stdout to a log file.
#

# Get the command line arguments.
set infile "T0000000000.mp4"
set framerate "20"
set codec "libx264"
set crf "23"
set preset "veryfast"
set rotation "0"
set verbose "0"
foreach {option value} $argv {
	switch $option {
		"-infile" {
			set infile $value
		}
		"-framerate" {
			set framerate $value
		}
		"-seglen" {
			set seglen $value
		}
		"-codec" {
			set codec $value
		}
		"-crf" {
			set crf $value
		}
		"-preset" {
			set preset $value
		}
		"-rotation" {
			set rotation $value
		}
		"-verbose" {
			set verbose $value
		}
		default {
			puts "ERROR: Unknown option \"$option\"."
		}
	}
}

# Check the file name is of the correct format. If not, we exit.
if {![regexp {T([0-9]{10})} [file tail $infile] match timestamp]} {
	puts "ERROR: Bad segment name \"[file tail $infile]\" at time\
		[clock format [clock seconds]]."
	exit
}

# Check that the file exists.
if {![file exists $infile]} {
	puts "ERROR: File $infile does not exist."
	exit
}
	
# Use the timestamp to construct a working file name.
set outfile [file dirname $infile]/W$timestamp\.mp4

# Compose the ffmpeg command.
set cmd [list /usr/bin/ffmpeg \
	-nostdin -loglevel error \
	-r $framerate \
	-i $infile \
	-c:v $codec \
	-crf $crf \
	-preset $preset]
	
# If we are to rotate the image before compression, we add a video filter to
# specify the rotation.
switch $rotation {
	"90" {
	lappend cmd -vf "transpose=clock"
	}
	"180" {
	lappend cmd -vf "hflip,vflip"
	}
	"270" {
	lappend cmd -vf "transpose=cclock"
	}	
}

# We force key frames every second, so that we can navigate easily to the
# one-second boundaries.
lappend cmd -force_key_frames "expr:eq(mod(n,20),0)" $outfile

# Compress with ffmpeg to produce video with the specified frame rate. If we
# encounter an ffmpeg error, we report to stdout, but otherwise proceed, because
# ffmpeg will report errors even though it completes compression.
set start [clock milliseconds]
if {[catch {exec {*}$cmd} message]} {
	puts "ERROR: $message during compression of [file tail $infile]."
	exit
}
set duration [expr [clock milliseconds] - $start]
	
# Verbose reporting.
if {$verbose} {
	set insize [format %.1f [expr 1.0 * [file size $infile] / 1000]]
	set outsize [format %.1f [expr 1.0 * [file size $outfile] / 1000]]
	puts "Compressed $infile $insize kByte to $outfile $outsize kByte in $duration ms." 
}
		
# Delete the original segment. Report any error.
if {[catch {file delete $infile} message]} {
	puts "ERROR: $message\."
}
</script>

<script>
#
# Videoarchiver/dhcpcd_default.conf
#
# Dynamic Host Configuration Protocol Configuration File for the Animal Cage
# Camera (A3034), Open Source Instruments Inc.
#

# We assign a static IP address with subnet mask 255.255.255.0 to the wired
# Ethernet interface, which the operating system calls "eth0". Do not change the 
# static IP address in this file unless you are prepared to change it in the 
# Videoarchiver's set_ip routine as well. We disable routers for this interface
# with router address 0.0.0.0, which is a null address. The operating system
# will not attempt to use eth0 to communicate with any other subnet. 
interface eth0
static ip_address=10.0.0.34/24
static routers=0.0.0.0

# In normal operation, the camera's wireless interface is disabled at boot time
# by a command in the /boot/config.txt file. But if we were to remove that command
# and allow the wireless interface to power up, and if we have given the operating
# system the name and password for a local wireless network, the camera will try
# to connect to that network. Here we give static addresses for name servers and 
# we allow the interface to obtain its own IP address and router address through
# a dynamic host configuration protocol (DHCP) exchange. 
interface wlan0
static domain_name_servers=8.8.4.4 8.8.8.8

</script>

<script>
#!/bin/bash
#
# Videoarchiver/init.sh
#
# The startup Bash script run by the Animal Cage Camera (A3034) after it boots
# up. We must run it in a bash shell or else the regular expressions don't work
# We turn off the infrared and white lights, flash the white ones three times,
# check the configuration switch. If the switch is pressed, we flash the white
# lights five times and overwrite the existing TCPIP configuration file to
# return the camera's IP address to the factory default value. If the switch is
# not pressed, we continue. The final action is to start up the TCL interface on
# port 2223.
#

# Move to the Videoarchiver directory.
cd /home/pi/Videoarchiver

# Report to log file.
if [ "$SHELL" != "" ]
then
	echo "Shell init.sh running in $SHELL" > init_log.txt
else
	echo "Shell init.sh running in unknown shell" > init_log.txt
fi
echo "Moved to directory `pwd`, reading videoarchiver config" >> init_log.txt
cat videoarchiver.config >> init_log.txt
OS=`grep "Bullseye" videoarchiver.config`

# Determine the camera version. The "B" and "C" versions run Rasbian Stretch
# with the gpio command. These versions both have "A3034B" in their
# configuration file. The "D" version runs Raspberry Pi Bullseye and has
# "A3034D" in its configuration file.
if [ "$OS" != "" ]
then
	# We use raspi-gpio routines to configure and flash lights on A3034D.
	echo "Detected Bullseye, using raspi-gpio." >> init_log.txt

	# Set the configuration switch port to input with pull-up resistor.
	raspi-gpio set 5 ip pu

	# Turn off the infrared LEDs.
	raspi-gpio set 16,26,20,21 op dl

	# Turn off the white LEDs.
	raspi-gpio set 2,3,4,14 op dl

	# Flash the white LEDs three times, then wait one second.
	for count in 1 2 3; do
		sleep 0.3
		raspi-gpio set 2,3,4,14 op dh
		sleep 0.1
		raspi-gpio set 2,3,4,14 op dl
	done

	# Check the configuration switch. If it is depressed, we replace the existing
	# /etc/dhcpcd.conf file with the dhcpcd_default.conf, which sets the IP address
	# of this camera to the default value 10.0.0.34. While this reset is taking
	# place, we turn the white LEDs on half power.
	if [ "`raspi-gpio get 5 | grep level=0`" != "" ]
	then
		sleep 1.0
		sudo ifconfig eth0 down
		sudo cp dhcpcd_default.conf /etc/dhcpcd.conf
		for count in 1 2 3 4 5; do
			raspi-gpio set 2,3,4,14 op dh
			sleep 0.1
			raspi-gpio set 2,3,4,14 op dl
			sleep 0.1
		done
		sudo ifconfig eth0 up
		sleep 0.5
	fi
else
	# We use gpio routines to configure and flash lights on A3034B and A3034C.
	echo "Defaulting to Stretch, using gpio" >> init_log.txt

	# Set the configuration switch port to input with pull-up resistor.
	gpio -g mode 5 in
	gpio -g mode 5 up

	# Turn off the infrared LEDs.
	for value in 16 26 20 21; do
		gpio -g mode $value out
		gpio -g write $value 0
	done

	# Turn off the white LEDs.
	for value in 2 3 4 14; do
		gpio -g mode $value out
		gpio -g write $value 0
	done

	# Flash the white LEDs three times.
	for count in 1 2 3; do
		sleep 0.3
		for value in 2 3 4 14; do
			gpio -g write $value 1
		done
		sleep 0.1
		for value in 2 3 4 14; do
			gpio -g write $value 0
		done
	done

	# Check the configuration switch. If it is depressed, we replace the existing
	# /etc/dhcpcd.conf file with the dhcpcd_default.conf, which sets the IP address
	# of this camera to the default value 10.0.0.34. While this reset is taking
	# place, we turn the white LEDs on half power.
	if [ `gpio -g read 5` -eq 0 ]
	then
		sleep 1.0
		sudo ifconfig eth0 down
		sudo cp dhcpcd_default.conf /etc/dhcpcd.conf
		for count in 1 2 3 4 5; do
			for value in 2 3 4 14; do
				gpio -g write $value 1
			done
			sleep 0.1
			for value in 2 3 4 14; do
				gpio -g write $value 0
			done
			sleep 0.1
		done
		sudo ifconfig eth0 up
		sleep 0.5
	fi
fi

# Start the TCPIP interface process as user PI.
echo "Starting TCL interface process." >> init_log.txt
sudo -u pi bash -c "tclsh interface.tcl -port 2223 > interface_log.txt &"
</script>

<script>
#
# Videoarchiver/test/stream.sh
#
# Stream video to port 2222 in MJPEG format, frame-by-frame compression only.
#
if [ "`grep Bullseye ../videoarchiver.config`" == "os Bullseye" ]
then
	libcamera-vid --codec MJPEG --timeout 0 --flush --width 820 --height 616 \
		--nopreview --framerate 20 --listen --saturation 0.5 --output tcp://0.0.0.0:2222 \
	>& stream_log.txt
else
	raspivid --codec MJPEG --timeout 0 --flush --width 820 --height 616 \
		--nopreview --framerate 20 --listen --output tcp://0.0.0.0:2222 \
		>& stream_log.txt
fi
</script>

<script>
# 
# Videoarchiver/test/segment.sh
#
# Take video stream and divide into segments.
#
ffmpeg -nostdin \
	-loglevel error \
	-i tcp://127.0.0.1:2222 \
	-framerate 20 \
	-f segment \
	-segment_atclocktime 1 \
	-segment_time 1 \
	-reset_timestamps 1 \
	-codec copy \
	-segment_list segment_list.txt \
	-segment_list_size 1000 \
	-strftime 1 S%s.mp4 \
	>& segment_log.txt
</script>

<script>
# 
# Videoarchiver/test/framerate.tcl
#
# Measure the number of frames in each S*.mp4 file in the local directory, as well
# as the size of the files, and then all the V*.mp4 files.
#
foreach prefix {S V} {
	puts "Looking for [set prefix]*.mp4 segments... "
	set fnl [lsort -dictionary [glob -nocomplain [set prefix]*.mp4]]
	if {[llength $fnl] < 1} {
		puts "No [set prefix]*.mp4 segments found."
		continue
	} else {
		puts "Found [llength $fnl] [set prefix]*.mp4 segments."
		set sum_size 0
		set sum_frames 0
		foreach fn $fnl {
			set size [format %.1f [expr [file size $fn] * 0.001]]
			set sum_size [expr $sum_size + $size]
			catch {exec /usr/bin/ffmpeg -i $fn -c copy -f null -} result
			if {[regexp -all {frame= *([0-9]+)} $result match frames]} {
				puts "$fn\: $frames frames, $size kBytes,\
					[format %.2f [expr $size / $frames]] kByte/frame"
				set sum_frames [expr $sum_frames + $frames]
			} else {
				puts "ERROR: Cannot obtain frame count for $fn\."
				exit
			}
		}
		puts "Average size: [format %.1f [expr $sum_size / [llength $fnl]]] kBytes."
		puts "Average frame size: [format %.1f [expr $sum_size / $sum_frames]] kBytes."
	}
}
</script>

<script>
# 
# Videoarchiver/test/single.tcl
#
# Compress a single mp4 segment to a new one with V prefix, delete pre-existing.
# 
set fn [file tail [lindex $argv 0]]
if {$fn != ""} {
	puts $fn
	if {[file exists V$fn]} {file delete V$fn }
	exec /usr/bin/ffmpeg \
		-loglevel error \
		-i $fn \
		-c:v libx264 \
		-preset veryfast V$fn
}
</script>

<script>
# 
# Videoarchiver/test/compress.tcl
#
# Measures compression rate. Specify the number of processors we want to use for
# compression with the -processes option. Compresses all videos S*.mp4 in local
# directory using xargs and single.tcl.
#
set start_time [clock seconds]
set fnl [glob -nocomplain S*.mp4]
set processes 1
foreach {option value} $argv {
	switch $option {
		"-processes" {
			set processes $value
		}
		default {
			puts "ERROR: Unknown option \"$option\"."
		}
	}
}
puts "Compressing [llength $fnl] files using $processes processes..."
exec find ./ -name "S*.mp4" -print | xargs -n1 -P$processes tclsh single.tcl
set t [expr [clock seconds] - $start_time]
if {[llength $fnl] > 0} {
	set tt [expr 1.0*$t/[llength $fnl]]
} else {
	set tt $t
}
puts "Done in $t seconds, [format %.2f $tt] per segment." 
</script>

<script>
{
    "rpi.black_level":
    {
        "black_level": 4096
    },
    "rpi.dpc":
    {

    },
    "rpi.lux":
    {
        "reference_shutter_speed": 27685,
        "reference_gain": 1.0,
        "reference_aperture": 1.0,
        "reference_lux": 998,
        "reference_Y": 12744
    },
    "rpi.noise":
    {
        "reference_constant": 0,
        "reference_slope": 3.67
    },
    "rpi.geq":
    {
        "offset": 204,
        "slope": 0.01633
    },
    "rpi.sdn":
    {

    },
    "rpi.awb":
    {
	"bayes": 0
    },
    "rpi.agc":
    {
        "metering_modes":
        {
            "centre-weighted":
            {
                "weights":
                [
                    3, 3, 3, 2, 2, 2, 2, 1, 1, 1, 1, 0, 0, 0, 0
                ]
            },
            "spot":
            {
                "weights":
                [
                    2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
                ]
            },
            "matrix":
            {
                "weights":
                [
                    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
                ]
            }
        },
        "exposure_modes":
        {
            "normal":
            {
                "shutter":
                [
                    100, 10000, 30000, 60000, 66666
                ],
                "gain":
                [
                    1.0, 2.0, 4.0, 6.0, 8.0
                ]
            },
            "short":
            {
                "shutter":
                [
                    100, 5000, 10000, 20000, 33333
                ],
                "gain":
                [
                    1.0, 2.0, 4.0, 6.0, 8.0
                ]
            },
            "long":
            {
                "shutter":
                [
                    100, 10000, 30000, 60000, 120000
                ],
                "gain":
                [
                    1.0, 2.0, 4.0, 6.0, 12.0
                ]
            }
        },
        "constraint_modes":
        {
            "normal":
            [
                {
                    "bound": "LOWER", "q_lo": 0.98, "q_hi": 1.0, "y_target":
                    [
                        0, 0.5, 1000, 0.5
                    ]
                }
            ],
            "highlight":
            [
                {
                    "bound": "LOWER", "q_lo": 0.98, "q_hi": 1.0, "y_target":
                    [
                        0, 0.5, 1000, 0.5
                    ]
                },
                {
                    "bound": "UPPER", "q_lo": 0.98, "q_hi": 1.0, "y_target":
                    [
                        0, 0.8, 1000, 0.8
                    ]
                }
            ],
	    "shadows":
	    [
		{
		    "bound": "LOWER", "q_lo": 0.0, "q_hi": 0.5, "y_target":
                    [
                        0, 0.17, 1000, 0.17
                    ]
                }
            ]
        },
        "y_target":
        [
            0, 0.16, 1000, 0.165, 10000, 0.17
        ]
    },
    "rpi.alsc":
    {
        "omega": 1.3,
        "n_iter": 100,
        "luminance_strength": 0.7,
        "calibrations_Cr":
        [
            {
                "ct": 3000, "table":
                [
                    1.584, 1.574, 1.568, 1.569, 1.584, 1.599, 1.624, 1.634, 1.634, 1.634, 1.624, 1.613, 1.603, 1.596, 1.596, 1.609,
                    1.574, 1.544, 1.555, 1.568, 1.591, 1.616, 1.658, 1.681, 1.681, 1.677, 1.634, 1.615, 1.596, 1.578, 1.567, 1.585,
                    1.529, 1.519, 1.539, 1.557, 1.611, 1.658, 1.721, 1.759, 1.759, 1.739, 1.677, 1.629, 1.578, 1.564, 1.539, 1.539,
                    1.493, 1.494, 1.506, 1.557, 1.637, 1.721, 1.773, 1.851, 1.851, 1.785, 1.739, 1.651, 1.578, 1.525, 1.514, 1.503,
                    1.466, 1.478, 1.492, 1.564, 1.664, 1.773, 1.851, 1.899, 1.911, 1.856, 1.785, 1.674, 1.581, 1.514, 1.496, 1.478,
                    1.452, 1.458, 1.488, 1.565, 1.673, 1.791, 1.891, 1.928, 1.928, 1.906, 1.806, 1.684, 1.582, 1.509, 1.477, 1.464,
                    1.452, 1.457, 1.487, 1.564, 1.673, 1.791, 1.891, 1.907, 1.911, 1.905, 1.806, 1.684, 1.582, 1.508, 1.471, 1.464,
                    1.466, 1.476, 1.488, 1.556, 1.649, 1.755, 1.818, 1.891, 1.901, 1.823, 1.769, 1.666, 1.576, 1.508, 1.487, 1.473,
                    1.492, 1.492, 1.501, 1.544, 1.616, 1.688, 1.755, 1.818, 1.818, 1.769, 1.702, 1.634, 1.566, 1.515, 1.508, 1.498,
                    1.525, 1.506, 1.521, 1.536, 1.583, 1.617, 1.688, 1.721, 1.721, 1.702, 1.634, 1.606, 1.559, 1.544, 1.524, 1.528,
                    1.564, 1.533, 1.534, 1.558, 1.563, 1.585, 1.615, 1.635, 1.635, 1.631, 1.606, 1.591, 1.582, 1.559, 1.546, 1.567,
                    1.586, 1.564, 1.558, 1.559, 1.563, 1.574, 1.587, 1.601, 1.602, 1.602, 1.597, 1.591, 1.583, 1.583, 1.587, 1.603
                ]
            }
        ],
        "calibrations_Cb":
        [
            {
                "ct": 3000, "table":
                [
                    1.217, 1.221, 1.229, 1.235, 1.243, 1.251, 1.257, 1.258, 1.257, 1.249, 1.234, 1.222, 1.207, 1.191, 1.177, 1.172,
                    1.217, 1.221, 1.226, 1.233, 1.241, 1.251, 1.258, 1.259, 1.257, 1.248, 1.228, 1.211, 1.194, 1.178, 1.169, 1.159,
                    1.214, 1.219, 1.226, 1.233, 1.241, 1.251, 1.259, 1.263, 1.262, 1.248, 1.228, 1.205, 1.185, 1.169, 1.159, 1.149,
                    1.214, 1.219, 1.226, 1.233, 1.241, 1.255, 1.267, 1.275, 1.274, 1.258, 1.231, 1.204, 1.179, 1.162, 1.149, 1.145,
                    1.217, 1.219, 1.227, 1.237, 1.249, 1.267, 1.279, 1.293, 1.285, 1.274, 1.241, 1.206, 1.179, 1.161, 1.145, 1.141,
                    1.219, 1.225, 1.234, 1.242, 1.258, 1.276, 1.297, 1.299, 1.297, 1.285, 1.249, 1.211, 1.181, 1.161, 1.145, 1.142,
                    1.222, 1.226, 1.236, 1.246, 1.261, 1.277, 1.298, 1.305, 1.305, 1.285, 1.252, 1.215, 1.186, 1.164, 1.148, 1.144,
                    1.226, 1.229, 1.238, 1.249, 1.261, 1.277, 1.295, 1.299, 1.296, 1.284, 1.252, 1.221, 1.193, 1.171, 1.161, 1.148,
                    1.229, 1.233, 1.242, 1.251, 1.262, 1.274, 1.287, 1.293, 1.289, 1.277, 1.253, 1.224, 1.202, 1.184, 1.171, 1.161,
                    1.233, 1.238, 1.246, 1.253, 1.263, 1.274, 1.284, 1.289, 1.287, 1.276, 1.254, 1.232, 1.213, 1.195, 1.184, 1.172,
                    1.235, 1.238, 1.246, 1.253, 1.263, 1.273, 1.282, 1.284, 1.282, 1.274, 1.257, 1.241, 1.222, 1.205, 1.191, 1.183,
                    1.235, 1.235, 1.244, 1.251, 1.259, 1.268, 1.277, 1.282, 1.278, 1.271, 1.257, 1.242, 1.222, 1.205, 1.191, 1.185
                ]
            }
        ],
        "luminance_lut":
        [
            1.843, 1.786, 1.715, 1.646, 1.567, 1.475, 1.433, 1.431, 1.431, 1.437, 1.498, 1.586, 1.664, 1.758, 1.844, 1.914,
            1.843, 1.792, 1.702, 1.587, 1.502, 1.397, 1.315, 1.289, 1.289, 1.335, 1.407, 1.519, 1.607, 1.721, 1.829, 1.914,
            1.853, 1.793, 1.677, 1.535, 1.397, 1.304, 1.197, 1.161, 1.161, 1.203, 1.331, 1.407, 1.546, 1.689, 1.817, 1.914,
            1.864, 1.791, 1.647, 1.479, 1.315, 1.197, 1.118, 1.059, 1.059, 1.134, 1.203, 1.331, 1.497, 1.667, 1.816, 1.916,
            1.873, 1.791, 1.629, 1.442, 1.261, 1.118, 1.056, 1.011, 1.017, 1.059, 1.134, 1.275, 1.462, 1.648, 1.814, 1.919,
            1.888, 1.799, 1.629, 1.437, 1.246, 1.102, 1.017, 1.001, 1.001, 1.019, 1.108, 1.249, 1.449, 1.646, 1.821, 1.919,
            1.905, 1.807, 1.634, 1.437, 1.246, 1.102, 1.018, 1.011, 1.015, 1.019, 1.108, 1.249, 1.449, 1.649, 1.827, 1.932,
            1.908, 1.856, 1.669, 1.476, 1.289, 1.145, 1.098, 1.019, 1.021, 1.098, 1.145, 1.285, 1.472, 1.669, 1.839, 1.935,
            1.911, 1.873, 1.716, 1.541, 1.366, 1.272, 1.145, 1.099, 1.099, 1.145, 1.269, 1.364, 1.535, 1.708, 1.855, 1.939,
            1.917, 1.873, 1.769, 1.625, 1.514, 1.366, 1.272, 1.234, 1.234, 1.269, 1.364, 1.492, 1.616, 1.757, 1.872, 1.947,
            1.932, 1.922, 1.873, 1.769, 1.625, 1.514, 1.438, 1.398, 1.398, 1.424, 1.492, 1.616, 1.757, 1.872, 1.953, 1.957,
            2.059, 2.009, 1.943, 1.857, 1.783, 1.721, 1.679, 1.672, 1.672, 1.672, 1.694, 1.754, 1.828, 1.912, 1.991, 2.062
        ],
        "sigma": 0.00381,
        "sigma_Cb": 0.00216
    },
    "rpi.contrast":
    {
        "ce_enable": 1,
        "gamma_curve":
        [
            0, 0, 1024, 5040, 2048, 9338, 3072, 12356, 4096, 15312, 5120, 18051, 6144, 20790, 7168, 23193,
            8192, 25744, 9216, 27942, 10240, 30035, 11264, 32005, 12288, 33975, 13312, 35815, 14336, 37600, 15360, 39168,
            16384, 40642, 18432, 43379, 20480, 45749, 22528, 47753, 24576, 49621, 26624, 51253, 28672, 52698, 30720, 53796,
            32768, 54876, 36864, 57012, 40960, 58656, 45056, 59954, 49152, 61183, 53248, 62355, 57344, 63419, 61440, 64476,
            65535, 65535
        ]
    },
    "rpi.ccm":
    {
        "ccms":
        [
            {
                "ct": 2498, "ccm":
                [
                    1.58731, -0.18011, -0.40721, -0.60639, 2.03422, -0.42782, -0.19612, -1.69203, 2.88815
                ]
            },
            {
                "ct": 2811, "ccm":
                [
                    1.61593, -0.33164, -0.28429, -0.55048, 1.97779, -0.42731, -0.12042, -1.42847, 2.54889
                ]
            },
            {
                "ct": 2911, "ccm":
                [
                    1.62771, -0.41282, -0.21489, -0.57991, 2.04176, -0.46186, -0.07613, -1.13359, 2.20972
                ]
            },
            {
                "ct": 2919, "ccm":
                [
                    1.62661, -0.37736, -0.24925, -0.52519, 1.95233, -0.42714, -0.10842, -1.34929, 2.45771
                ]
            },
            {
                "ct": 3627, "ccm":
                [
                    1.70385, -0.57231, -0.13154, -0.47763, 1.85998, -0.38235, -0.07467, -0.82678, 1.90145
                ]
            },
            {
                "ct": 4600, "ccm":
                [
                    1.68486, -0.61085, -0.07402, -0.41927, 2.04016, -0.62089, -0.08633, -0.67672, 1.76305
                ]
            },
            {
                "ct": 5716, "ccm":
                [
                    1.80439, -0.73699, -0.06739, -0.36073, 1.83327, -0.47255, -0.08378, -0.56403, 1.64781
                ]
            },
            {
                "ct": 8575, "ccm":
                [
                    1.89357, -0.76427, -0.12931, -0.27399, 2.15605, -0.88206, -0.12035, -0.68256, 1.80292
                ]
            }
        ]
    },
    "rpi.sharpen":
    {

    },
    "rpi.dpc":
    {

    }
}
</script>

----------End Data----------


