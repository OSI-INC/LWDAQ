# Videoarchiver, a Standard and Polite LWDAQ Tool
#
# Copyright (C) 2018-2022 Kevan Hashemi, Open Source Instruments Inc.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public Lices_colnse
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA	02111-1307, USA.


#
# Videoarchiver_init initializes the info and config arrays, and reads
# in previously-saved settings.
#
proc Videoarchiver_init {} {
	upvar #0 Videoarchiver_info info
	upvar #0 Videoarchiver_config config
	global LWDAQ_Info LWDAQ_Driver Videoarchiver_mode
	
	# Initialize the tool. Exit if the window is already open.
	LWDAQ_tool_init "Videoarchiver" "22"

	# We check the global Videoarchiver_mode variable, which is the means by
	# which we can direct the Videoarchiver to use the LWDAQ main window or
	# its own toplevel window.
	if {![info exists Videoarchiver_mode]} {
		set info(mode) "Main"
	} {
		set info(mode) $Videoarchiver_mode
	}

	# If we are to take over the LWDAQ main window with the Neuroarchiver, we
	# set the tool window name to the empty string. Otherwise we leave it as it
	# has been set by the tool initialization routine, and we check to see if
	# that window already exists. If it does exist, we abort. When we are taking
	# over the main window, we proceed anyway.
	switch $info(mode) {
		"Child" {set info(window) ""}
		default {
			if {[LWDAQ_widget_exists $info(window)]} {return "ABORT"}
		}
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
		set info(mplayer) [file join $info(os_dir) mplayer/mplayer.exe]
	} elseif {$info(os) == "MacOS"} {
		set info(ssh) "/usr/bin/ssh"
		set info(ffmpeg) [file join $info(os_dir) ffmpeg]
		set info(mplayer) [file join $info(os_dir) mplayer]
	} elseif {$info(os) == "Linux"} {
		set info(ssh) "/usr/bin/ssh"
		set info(ffmpeg) [file join $info(os_dir) ffmpeg/ffmpeg]
		set info(mplayer) [file join $info(os_dir) mplayer]
	} else {
		error "Videoarchiver does not support $info(os)."
		return ""
	}
	
	# The time we alloew for video streaming to start on the camera.
	set info(pi_start_ms) "500"
	
	# The codec to use for compression on the Pi. The libx264 codec is provided by
	# ffmpeg in compiled code that runs on the Pi microprocessor cores (CPUs). If 
	# we want to use the Pi's graphics co-processor (GPU), we must use h264_omx, 
	# but there is only one GPU, while there are four CPUs. If we try to use both
	# codecs, ffmpeg fails to concatinate them correctly on the data acquisition 
	# machine.
	set info(compression_codec) "libx264"
	set info(stream_codec) "MJPEG"
	set info(compression_num_cpu) "3"

	# Fixed IP addresses for default configurations and camera streaming.
	set info(local_ip_addr) "127.0.0.1"
	set info(default_ip_addr) "10.0.0.34"
	set info(default_router_addr) "10.0.0.1"
	set info(null_addr) "0.0.0.0"
	set info(new_ip_addr) $info(default_ip_addr)
	set info(tcp_port) "2222"
	set info(tcl_port) "2223"
	set info(library_archive) "http://www.opensourceinstruments.com/ACC/Videoarchiver.zip"
	
	# These are the camera versions and their resolutions and framerates.
	set config(versions) [list {A3034B-HR 820 616 20 23} {A3034B-LR 410 308 30 15}]
	
	# The rotation of the image readout.
	set info(rotation_options) "0 90 180 270"
		
	# In the following paragraphs, we define shell commands that we pass via secure
	# shell (ssh) to the camera, where we can run the raspivid or raspistill
	# utilities to operate the camera, of control input and output lines with the
	# gpio utility. Each string we send directly to the camera with ssh to be executed
	# on the camera. For documentation on the camera utilities see here:
	# https://www.raspberrypi.org/documentation/raspbian/applications/camera.md
	# For documentation on the gpio utility see here:
	# https://www.raspberrypi.org/documentation/usage/gpio/
	
	# We initialize the camera by making sure the Videoarchiver directory exists,
	# moving to that directory, cleaning up old log, video, and image files, killing
	# all videoarchiver-generated processes, video processes, and image capture
	# processes, and starting the TCPIP interface.
	set info(camera_init) {
cd Videoarchiver
rm -f *_log.txt
rm -f tmp/*.mp4
rm -f *.gif
killall -9 tclsh 
killall -9 ffmpeg 
killall -9 raspivid 
killall -9 raspivstill 
tclsh interface.tcl -port %Q >& interface_log.txt &
echo "SUCCESS"
}	
	
	# To stop the streaming of video, and the capture of an image, we call the Linux
	# command "killall". After stopping everything, we restart the TCPIP interface
	# process.
	set info(stop) {
cd Videoarchiver
killall -9 tclsh 
killall -9 ffmpeg
killall -9 raspivid
killall -9 raspivstill
tclsh interface.tcl -port %Q >& interface_log.txt &
echo "SUCCESS"
}

	# The Raspberry Pi lets us re-boot as the Pi user without a password, so we can
	# reboot with the reboot command, running the command in the background allows
	# us to send back a success word before the reboot completes.
	set info(reboot) {
sudo reboot &
echo "SUCCESS"
}

	# Extract the compressor script from the data field of this script.
	set script_list [LWDAQ_xml_get_list [LWDAQ_tool_data $info(name)] script]
	set info(interface_script) [lindex $script_list 0]
	set info(compressor_script) [lindex $script_list 1]
	set info(dhcpcd_script) [lindex $script_list 2]
	set info(init_script) [lindex $script_list 3]

	# The following parameters will appear in the configuration panel, so the user can
	# modify them by hand.
	set config(transfer_period_s) "60"
	set config(transfer_max_files) "10"
	set config(record_length_s) "600"
	set config(connect_timeout_s) "5"
	set config(restart_wait_s) "30"
	
	# Monitor parameters
	set config(monitor_speed) "1.0"
	set config(display_zoom) "1.0"
	set info(monitor_process) "0"
	set info(monitor_channel) "none"
	set info(monitor_cam) "0"
	
	# Lag thresholds and restart log.
	set config(lag_warning) "10.0"
	set config(lag_alarm) "30.0"
	set config(lag_reset) "40.0"
	set config(restart_log) [file join $info(scratch_dir) restart_log.txt]
	
	# Text window colors. We have a verbose comment color and a standard comment color.
	set config(v_col) "black"
	set config(s_col) "black"
	set config(verbose) "0"
	
	# Text window number of lines to keep.
	set info(num_lines_keep) "200"
	
	# The following parameter gives the four-bit DAC values that correspond to the 
	# six power settings 0-4 presented to the use and programmer for controlling
	# the intensity of the LEDs, both white and infrared.
	set info(lamp_dac_values) "0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15"	
	
	# Camera login details. We don't use the camera password, but we record it here for 
	# manual ssh access.
	set info(camera_login) "pi"
	set info(camera_password) "osicamera"

	# A list of cameras, which is now empty, but will be filled later, or given a single
	# entry as a starting point.
	set info(cam_list) [list]	
	
	# The camera list file defines a list of cameras with TCL commands that set the
	# camera list string and camera parameters.
	set config(cam_list_file) [file normalize "~/Desktop/CamList.tcl"]

	# The recording directory is where we store video to disk. The Videoarchiver creates 
	# individual directories for each camera, using the camera ID for the directory name. 
	# By default, we create these folders on the desktop. Even if this is the wrong place,
	# at least our user will see them appearing.
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
	
	return "SUCCESS"	 
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
# the scratch directory, and is named after the camera IP address. If this sub-directory 
# does not exist, the routine creates the directory. We pass the camera index into the 
# routine and the routine looks up the camera's IP address.
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
# Videoarchiver_camera_init initializes a camera by stopping all ffmpeg
# and tclsh processes, deleting old files, and starting up the interface
# process on the camera.
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

	# Send the initialization command to the camera using a secure shell.
	catch {[exec $info(ssh) \
		-o ConnectTimeout=$config(connect_timeout_s) \
		-o UserKnownHostsFile=/dev/null \
		-o StrictHostKeyChecking=no \
		-o LogLevel=error \
		-i [file join $info(keys_dir) id_rsa] \
		"$info(camera_login)@$ip" \
		 $command]} message
	if {[regexp "SUCCESS" $message]} {
		LWDAQ_print $info(text) "$info(cam$n\_id) initialized,\
			tcpip interface started, $ip." $config(s_col)
	} else {
		error $message
	}
	
	# Wait for the tcpip interface to start up.
	LWDAQ_wait_ms $info(pi_start_ms)
	
	return "SUCCESS"
}

#
# Videoarchiver_view_restart_log opens a text window that allows us to view the 
# restart log, edit it, and save it if needed.
#
proc Videoarchiver_view_restart_log {} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	set result [LWDAQ_view_text_file $config(restart_log)]
	if {[LWDAQ_is_error_result $result]} {
		LWDAQ_print $info(text) $result
		return "ERROR"
	}
	
	return "SUCCESS"
}

#
# Videoarchiver_clear_restart_log clears the restart log, leaving only a line
# stating the time at which the log was cleared.
#
proc Videoarchiver_clear_restart_log {} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	set f [open $config(restart_log) w]
	puts $f "Cleared restart log at [clock format [clock seconds]]."
	close $f
	
	return "SUCCESS"
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
		LWDAQ_print $info(text) "ERROR: No camera with list index $n."
		return "FAIL"
	}
	
	# Open a new text window and set its title.
	set w $info(window)\.query$n
	set t $w.text
	if {![winfo exists $w]} {
		toplevel $w
		LWDAQ_text_widget $w 80 20
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
		if {$contents != ""} {LWDAQ_print $t $contents}
		LWDAQ_update
	}
	
	if {[catch {
		set sock [LWDAQ_socket_open $ip\:$info(tcl_port) basic]
			
		foreach log {stream compressor_1 compressor_2 compressor_3 segmentation interface} {
			set lfn "$log\_log.txt"
			LWDAQ_socket_write $sock "getfile $lfn\n"
			set size [LWDAQ_socket_read $sock line]
			if {[LWDAQ_is_error_result $size]} {error $size}
			set contents [LWDAQ_socket_read $sock $size]	
			set contents [regsub -all {\.\.\.} $contents "...\n"]
			set contents [string trim $contents]
			LWDAQ_print $t "Contents of remote $log\_log.txt on $info(cam$n\_id):" purple
			if {$size > 0} {LWDAQ_print $t $contents} 
			LWDAQ_update
		}
	
		LWDAQ_socket_write $sock "getfile videoarchiver.conf\n"
		set size [LWDAQ_socket_read $sock line]
		if {[LWDAQ_is_error_result $size]} {error $size}
		set contents [string trim [LWDAQ_socket_read $sock $size]]
		LWDAQ_print $t "Contents of remote videoarchiver.conf:" purple
		if {$size > 0} {LWDAQ_print $t $contents}

		LWDAQ_socket_write $sock "llength \[glob -nocomplain tmp/V*.mp4\]\n"
		set len [LWDAQ_socket_read $sock line]
		if {[LWDAQ_is_error_result $len]} {error $len}
		LWDAQ_print $t "Number of compressed video segments: $len" purple

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
		set message [regsub "ERROR: " $message ""]
		LWDAQ_print $info(text) "ERROR: $message"
		catch {LWDAQ_socket_close $sock}
		return "ERROR"	
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
		LWDAQ_print $info(text) "ERROR: No camera with list index $n."
		return "FAIL"
	}

	if {$info(cam$n\_state) != "Idle"} {
		LWDAQ_print $info(text) "ERROR: Wait until $info(cam$n\_id) is Idle\
			before trying a reboot."
		return "ERROR"
	}	
	set info(cam$n\_state) "Reboot"
	
	LWDAQ_print $info(text) "\nRebooting $info(cam$n\_id)" purple
	LWDAQ_print $info(text) "$info(cam$n\_id) Sending reboot command..."
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
		LWDAQ_print $info(text) "$info(cam$n\_id) Rebooting,\
			done when lights flash three times."
	} else {
		LWDAQ_print $info(text) "ERROR: $info(cam$n\_id) $message"
	}
	
	set info(cam$n\_state) "Idle"
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
			LWDAQ_print $info(text) "ERROR: Invalid lamp intensity \"$intensity\"."
		}
		
		# Get IP address and open an interface socket.
		set ip [Videoarchiver_ip $n]
	
		# Don't try to contact a non-existent camera.
		if {$ip == $info(null_addr)} {
			LWDAQ_print $info(text) "ERROR: No camera with list index $n."
			return "FAIL"
		}

		# Open a socket to the interface.
		set sock [LWDAQ_socket_open $ip\:$info(tcl_port) basic]
		
		# Send setlamp command.
		LWDAQ_socket_write $sock "setlamp $color $intensity\n"
		set result [LWDAQ_socket_read $sock line]
		if {$result != $intensity} {
			set message [regsub "ERROR: " $result ""]
			error $message
		}
		
		# Close the socket.
		LWDAQ_socket_close $sock
	
		# Report the change, provided verbose flag is set. Set the menubutton value.
		if {$config(verbose)} {
			LWDAQ_print $info(text) "$info(cam$n\_id) Set $color lamps to\
				intensity $intensity, $ip." 
		}
		set info(cam$n\_$color) $intensity
	} message]} {
		catch {LWDAQ_socket_close $sock}
		LWDAQ_print $info(text) "ERROR: $message"
	}
	return "SUCCESS"
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
				LWDAQ_print $info(text) "ERROR: $message."
				return "ERROR"
			}
		}
	}
	set file_list [lsort -dictionary [glob -nocomplain *.txt]]
	set num_old_files [llength $file_list]
	if {$num_old_files > 0} {
		foreach fn $file_list {
			if {[catch {file delete $fn} message]} {
				LWDAQ_print $info(text) "ERROR: $info(cam$n\_id) $message."
				LWDAQ_print $info(text) "WARNING: Kill rogue process that\
					ownes [file tail $fn] or recording will crash."
				return "ERROR"
			}
		}
	}
	
	return "SUCCESS"
}

#
# Videoarchiver_update uploads new interface, compressor, initialization, and 
# factory-default dhcp configuration files on the camera.
#
proc Videoarchiver_update {n} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info
	global LWDAQ_Info

	# Get IP address and open an interface socket.
	set ip [Videoarchiver_ip $n]

	# Don't try to contact a non-existent camera.
	if {$ip == $info(null_addr)} {
		LWDAQ_print $info(text) "ERROR: No camera with list index $n."
		return "FAIL"
	}

	LWDAQ_print $info(text) "\nUpdating Software on $info(cam$n\_id)" purple
	if {[catch {	
	
		# Stop all camera activity in preparation for the update.
		LWDAQ_print $info(text) "$info(cam$n\_id) Stopping all activity..."
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
		LWDAQ_print $info(text) "$info(cam$n\_id) Updating tcpip interface script..."
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
		LWDAQ_print $info(text) "$info(cam$n\_id) Starting tcpip interface, $ip..."
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

		# Wait for the streaming to start up, or else the mplayer process may find
		# no listening port and abort.
		LWDAQ_wait_ms $info(pi_start_ms)
	
		# Open a socket to the tcpip interface.
		set sock [LWDAQ_socket_open $ip\:$info(tcl_port) basic]
	
		# Update files on the camera. For each file we provide a functional name and
		# a file name.
		foreach {sn fn} {compressor compressor.tcl dhcpcd dhcpcd_default.conf init init.sh} {
			LWDAQ_print $info(text) "$info(cam$n\_id) Updating $sn script..."
			LWDAQ_update
			set size [string length $info($sn\_script)]
			LWDAQ_socket_write $sock "putfile $fn $size\n$info($sn\_script)"
			set result [LWDAQ_socket_read $sock line]
			if {$result != $size} {
				catch {close $sock}
				error "Failed to write $size bytes to $fn on $info(cam$n\_id)"
			}
		}
			
		# Close the socket, the update is complete.
		LWDAQ_socket_close $sock

		# Synchronize the clock on the camera.
		LWDAQ_print $info(text) "$info(cam$n\_id) Synchronizing camera clock..."
		Videoarchiver_synchronize $n
		
		# Update is complete.
		LWDAQ_print $info(text) "$info(cam$n\_id) Update complete."
	} message]} {
		LWDAQ_print $info(text) "ERROR: $info(cam$n\_id) $message."
		catch {LWDAQ_socket_close $sock}
		return "ERROR"
	}
	
	return "SUCCESS"
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
		LWDAQ_print $info(text) "ERROR: No camera with list index $n."
		return "FAIL"
	}
	
	set new_ip $ip
	set w $info(window)\.changeip$n
	if {[winfo exists $w]} {
		raise $w
		return "FAIL"
	}
	toplevel $w
	wm title $w "Change IP Address of Camera $info(cam$n\_id)"
	label $w.nal -text "New IP Address:" -fg purple
	entry $w.nae -textvariable Videoarchiver_info(new_ip_addr) -width 10
	button $w.proceed -text "Proceed" -command [list Videoarchiver_set_ip $n]
	pack $w.nal $w.nae $w.proceed -side left
}

#
# Videoarchiver_set_ip change a camera's IP address.
#
proc Videoarchiver_set_ip {n {new_ip ""}} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	# If the state of the camera is not Idle, don't allow IP change.
	if {$info(cam$n\_state) != "Idle"} {
		LWDAQ_print $info(text) "ERROR: Wait until $info(cam$n\_id) is Idle\
			before changing camera IP address."
		return "ERROR"
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
		LWDAQ_print $info(text) "ERROR: No camera with list index $n."
		return "FAIL"
	}

	# Use the IP address stored in a global variable.	
	if {$new_ip == ""} {set new_ip $info(new_ip_addr)}
	
	LWDAQ_print $info(text) "\n$info(cam$n\_id) Setting IP address to $new_ip" purple
	if {[catch {	
		# Start by checking the new IP address.
		if {![regexp {([0-9]+\.[0-9]+\.[0-9]+)\.[0-9]+} $new_ip match new_router_ip]} {
			error "Invalid IP address \"$new_ip\", operation aborted"
		}
		set new_router_ip "$new_router_ip\.1"
			
		# Stop all camera activity in preparation for the update.
		LWDAQ_print $info(text) "$info(cam$n\_id) Stopping all activity..."
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
		LWDAQ_print $info(text) "$info(cam$n\_id) Starting tcpip interface, $ip..."
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
		LWDAQ_socket_write $sock "setip $new_ip $new_router_ip\n"
		set result [LWDAQ_socket_read $sock line]
		if {$result != $new_ip} {error $result}
			
		# Close the socket, the update is complete.
		LWDAQ_socket_close $sock
		
		# Update is complete.
		set info(cam$n\_addr) $new_ip
		
		LWDAQ_print $info(text) "$info(cam$n\_id) New IP address is $new_ip,\
			new router address is $new_router_ip, ready in a few seconds."
	} message]} {
		LWDAQ_print $info(text) "ERROR: $info(cam$n\_id) $message."
		catch {LWDAQ_socket_close $sock}
		return "ERROR"
	}
	
	return "SUCCESS"
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

	# We move to the scratch directory because file names are simpler
	# when calling mplayer and ffmpeg so we can use the same command line
	# code for all operating systems.
	cd [Videoarchiver_segdir $n]
	
	# Obtain the height and width size of the image we want, and the frame rate.
	set sensor_index [lsearch $config(versions) "$info(cam$n\_ver)*"]
	if {$sensor_index < 0} {set sensor_index 0}
	scan [lindex $config(versions) $sensor_index] %s%d%d%d%d version width height framerate crf
		
	# Print notification.
	LWDAQ_print $info(text) "$info(cam$n\_id) Starting video streaming,\
		$width X $height, $framerate fps, $info(cam$n\_rot) deg,\
		ec $info(cam$n\_ec), sat $info(cam$n\_sat),\
		crf $crf, $ip." $config(s_col)
	LWDAQ_update

	if {[catch {
		# Open a socket to the interface.
		set sock [LWDAQ_socket_open $ip\:$info(tcl_port) basic]
		
		# We start video streaming to a TCPIP port. Our command uses the long versions of 
		# all options for clarity. We are going to perform percent substitution on this
		# string to allow the user to change the resolution, compensation, rotation
		# and saturation of the video. The final command to echo the word SUCCESS is to allow our 
		# secure shell to return a success code. Any error will cause the echo to be skipped.
		LWDAQ_socket_write $sock "exec raspivid --codec $info(stream_codec) --timeout 0 --flush \
			--width $width --height $height --saturation $info(cam$n\_sat) \
			--rotation $info(cam$n\_rot) \
			--ev $info(cam$n\_ec) --nopreview --framerate $framerate \
			--listen --output tcp://0.0.0.0:$info(tcp_port) >& stream_log.txt & \n"
		set result [LWDAQ_socket_read $sock line]
		if {[LWDAQ_is_error_result $result]} {
			set message [regsub "ERROR: " $result ""]
			error $message
		}
		
		# Close socket.
		LWDAQ_socket_close $sock
	} message]} {
		LWDAQ_print $info(text) "ERROR: $info(cam$n\_id) $message"
		catch {LWDAQ_socket_close $sock}
		return "ERROR"
	}

	# Wait for the streaming to start up, or else the mplayer process may find
	# no listening port and abort.
	LWDAQ_wait_ms $info(pi_start_ms)
	
	# Return success.
	return "SUCCESS"
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
		LWDAQ_print $info(text) "ERROR: No camera with list index $n."
		return "FAIL"
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
			LWDAQ_print $info(text) "ERROR: $info(cam$n\_id) $camera_time_ms"
			catch {LWDAQ_socket_close $sock}
			return "ERROR"
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
		LWDAQ_print $info(text) "ERROR: $info(cam$n\_id) $message"
		catch {LWDAQ_socket_close $sock}
		return "ERROR"
	}
	
	# Report.
	if {![regexp {invalid} $result]} {
		if {$config(verbose)} {
			LWDAQ_print $info(text) "$info(cam$n\_id) Synchronized at time $sync_time,\
				correcting offset of $offset_ms ms." $config(v_col)
		}
	} else {
		LWDAQ_print $info(text) "ERROR: $info(cam$n\_id) $result"
		return "ERROR"
	}
	
	return "$offset_ms $latency_ms $sync_wait_ms $sync_time"
}

#
# Videoarchiver_live stream live video from camera "n" and display. The video
# stream consists of compressed frames, but has no inter-frame compression.
#
proc Videoarchiver_live {n} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info
	
	# Get IP address and open an interface socket.
	set ip [Videoarchiver_ip $n]

	# Don't try to contact a non-existent camera.
	if {$ip == $info(null_addr)} {
		LWDAQ_print $info(text) "ERROR: No camera with list index $n."
		return "FAIL"
	}

	# Check the camera state.
	if {$info(cam$n\_state) != "Idle"} {
		LWDAQ_print $info(text) "ERROR: $info(cam$n\_id) Wait until Idle\
			before starting live display."
		return "ERROR"
	}
	set info(cam$n\_state) "Live"
	Videoarchiver_cleanup $n
	
	# Initialize the camera.
	if {[catch {Videoarchiver_camera_init $n} message]} {
		LWDAQ_print $info(text) "ERROR: $info(cam$n\_id) $message"
		Videoarchiver_stop $n
		return "ERROR"	
	} 
	
	# Start streaming video from camera.
	if {[catch {Videoarchiver_stream $n} message]} {
		LWDAQ_print $info(text) "ERROR: $info(cam$n\_id) $message"
		Videoarchiver_stop $n
		return "ERROR"	
	} 
	
	# We move to the scratch directory because file names are simpler
	# when calling mplayer and ffmpeg so we can use the same command line
	# code for all operating systems.
	cd [Videoarchiver_segdir $n]
	
	# Obtain the height and width size of the image we want, and the frame rate.
	set sensor_index [lsearch $config(versions) "$info(cam$n\_ver)*"]
	if {$sensor_index < 0} {set sensor_index 0}
	scan [lindex $config(versions) $sensor_index] %s%d%d%d%d version width height framerate crf
				
	# Start the mplayer receiving the stream directly from the camera. We set 
	# the frame to be higher than the actual frame rate, so the player displays
	# every frame as it arrives, and catches up if it lags behind.
	set info(cam$n\_lproc) [exec \
		$info(mplayer) -title "Live From $ip" \
		-demuxer lavf -cache 1000 -really-quiet -noconsolecontrols \
		-zoom -xy $config(display_zoom) -geometry 10%:10% -fps [expr 2*$framerate] \
		"ffmpeg://tcp://$ip:$info(tcp_port)" \
		>& live_log.txt &]
	LWDAQ_print $info(text) "$info(cam$n\_id) Starting live video display, this\
		will take a few seconds..." $config(s_col)
		
	# We start the live video watchdog process that looks to see if the 
	# mplayer process has been stopped by a user closing its window. 
	LWDAQ_post [list Videoarchiver_live_watchdog $n]
}

#
# Videoarchiver_live_watchdog check the status of the live view process running
# for camera "n". If it disappears, execute a stop on the same camera.
#
proc Videoarchiver_live_watchdog {n} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info
	global LWDAQ_Info
		
	# Get IP address and open an interface socket.
	set ip [Videoarchiver_ip $n]

	# Don't try to contact a non-existent camera.
	if {$ip == $info(null_addr)} {
		LWDAQ_print $info(text) "ERROR: No camera with list index $n."
		return "FAIL"
	}

	if {$info(cam$n\_state) != "Live"} {
		LWDAQ_print $info(text) "$info(cam$n\_id) Stopped live watchdog." $config(s_col)
	} elseif {$LWDAQ_Info(reset)} {
		Videoarchiver_stop $n
	} elseif {![LWDAQ_process_exists $info(cam$n\_lproc)]} {
		LWDAQ_print $info(text) "$info(cam$n\_id) Live video terminated." $config(s_col)
		Videoarchiver_stop $n
	} else {
		LWDAQ_post [list Videoarchiver_live_watchdog $n]
	}
}

#
# Videoarchiver_monitor manages the video monitor that gives a delayed view of 
# recorded video. We allow only one video stream to be monitored at a time.
#
proc Videoarchiver_monitor {n {command "Start"} {line ""}} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	# Get IP address and open an interface socket.
	set ip [Videoarchiver_ip $n]

	# Don't try to contact a non-existent camera.
	if {$ip == $info(null_addr)} {
		LWDAQ_print $info(text) "ERROR: No camera with list index $n."
		return "FAIL"
	}

	# Check the state of the camera.
	if {$command == "Start"} {
		LWDAQ_process_stop $info(monitor_process)
		catch {close $info(monitor_channel)}
		set info(monitor_channel) "none"
		set info(monitor_cam) "0"
		if {$info(cam$n\_state) != "Record"} {
			LWDAQ_print $info(text) "ERROR: $info(cam$n\_id) Can start monitor\
				only when recording."
			return "ERROR"
		}
		set info(monitor_cam) $n
		set info(monitor_channel) [open "| $info(mplayer) \
			-title \"Monitor for $info(cam$n\_id) $ip\" \
			-slave -demuxer lavf -idle -really-quiet \
			-fixed-vo -zoom -xy $config(display_zoom) -geometry 10%:10% \
			>& monitor_log.txt" w]
		fconfigure $info(monitor_channel) -translation auto -buffering line
		set info(monitor_process) [pid $info(monitor_channel)]
		puts $info(monitor_channel) "vo_ontop 0"
		puts $info(monitor_channel) "speed_set $config(monitor_speed)"		
		LWDAQ_print $info(text) "$info(cam$n\_id) Started display monitor, close with ESC key."
	} elseif {$command == "Stop"} {
		LWDAQ_process_stop $info(monitor_process)
		catch {close $info(monitor_channel)}
		set info(monitor_channel) "none"
		set info(monitor_cam) "0"
	} elseif {$command == "Write"} {
		if {[catch {
			puts $info(monitor_channel) $line
		} message]} {
			LWDAQ_print $info(text) "$info(cam$n\_id) Monitor process has stopped."
			LWDAQ_process_stop $info(monitor_process)
			catch {close $info(monitor_channel)}
			set info(monitor_channel) "none"
			set info(monitor_cam) "0"
		}		
	} else {
		LWDAQ_print $info(text) "ERROR: $info(cam$n\_id) Unknown monitor command \"$command\"."
		return "ERROR"
	}
	return "SUCCESS"
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
		LWDAQ_print $info(text) "ERROR: No camera with list index $n."
		return "FAIL"
	}

	# Obtain the height and width size of the image we want, and the frame rate.
	set sensor_index [lsearch $config(versions) "$info(cam$n\_ver)*"]
	if {$sensor_index < 0} {set sensor_index 0}
	scan [lindex $config(versions) $sensor_index] %s%d%d%d%d version width height framerate crf
		
	if {[catch {
		# Open a socket to the interface.
		set sock [LWDAQ_socket_open $ip\:$info(tcl_port) basic]
		
		# Send three commands, one for each processor. Check result string
		# for errors. The compressor script is at the end of this program file.
		for {set i 1} {$i <= $info(compression_num_cpu)} {incr i} {
			LWDAQ_socket_write $sock "exec /usr/bin/tclsh compressor.tcl \
				-framerate $framerate -codec $info(compression_codec) -crf $crf \
				-processes $info(compression_num_cpu) -index $i >& compressor_$i\_log.txt & \n"
			set result [LWDAQ_socket_read $sock line]
			if {[LWDAQ_is_error_result $result]} {
				set message [regsub "ERROR: " $result ""]
				error $message
			}
		}
		LWDAQ_print $info(text) "$info(cam$n\_id) Started $info(compression_num_cpu)\
			compression engines on camera." $config(s_col)

		# Close socket.
		LWDAQ_socket_close $sock
	} message]} {
		LWDAQ_print $info(text) "ERROR: $info(cam$n\_id) $message"
		catch {LWDAQ_socket_close $sock}
		return "ERROR"
	}

	return "SUCCESS"
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
		LWDAQ_print $info(text) "ERROR: No camera with list index $n."
		return "FAIL"
	}

	# Obtain the height and width size of the image we want, and the frame rate.
	set sensor_index [lsearch $config(versions) "$info(cam$n\_ver)*"]
	if {$sensor_index < 0} {set sensor_index 0}
	scan [lindex $config(versions) $sensor_index] %s%d%d%d%d version width height framerate crf
	
	if {[catch {
		# Open a socket to the interface.
		set sock [LWDAQ_socket_open $ip\:$info(tcl_port) basic]
		
		# Start the ffmpeg segmenter as a background process. We assume the segmenter 
		# will be started after streaming and compression engines are already running. 
		LWDAQ_socket_write $sock "exec ffmpeg -nostdin -loglevel error -i \
			tcp://$info(local_ip_addr)\:$info(tcp_port) \
			-framerate $framerate -f segment \
			-segment_atclocktime 1 -segment_time 1 -reset_timestamps 1 -c copy \
			-strftime 1 tmp/S%s.mp4 >& segmentation_log.txt & \n"
		set result [LWDAQ_socket_read $sock line]
		if {[LWDAQ_is_error_result $result]} {
			set message [regsub "ERROR: " $result ""]
			error $message
		}

		# Close socket.
		LWDAQ_socket_close $sock
	} message]} {
		LWDAQ_print $info(text) "ERROR: $info(cam$n\_id) $message"
		catch {LWDAQ_socket_close $sock}
		return "ERROR"
	}
	
	return "SUCCESS"
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
		LWDAQ_print $info(text) "ERROR: No camera with list index $n."
		return "FAIL"
	}

	# Check the state of the camera.
	if {($info(cam$n\_state) != "Idle") && ($info(cam$n\_state) != "Stalled")} {
		LWDAQ_print $info(text) "ERROR: $info(cam$n\_id) Wait until Idle\
			before starting recording."
		return "ERROR"
	}
	
	# Make sure we have a place to record video.
	if {[catch {
		set info(cam$n\_dir) [file join $config(recording_dir) $info(cam$n\_id)]
		if {![file exists $info(cam$n\_dir)]} {
			file mkdir $info(cam$n\_dir)
			LWDAQ_print $info(text) "$info(cam$n\_id) Created directory $info(cam$n\_dir) for\
				video files."
		} 
	} message]} {
		LWDAQ_print $info(text) "ERROR: $info(cam$n\_id) $message ."
		return "ERROR"	
	}

	# Clean up old files. This routine handles its own errors.
	if {[Videoarchiver_cleanup $n] == "ERROR"} {
		return "ERROR"	
	}

	# Initialize the camera.
	if {[catch {Videoarchiver_camera_init $n} message]} {
		LWDAQ_print $info(text) "ERROR: $info(cam$n\_id) $message"
		return "ERROR"	
	} 
	
	# Start streaming video on the camera as well as the interface process.
	if {[catch {Videoarchiver_stream $n} message]} {
		LWDAQ_print $info(text) "ERROR: $info(cam$n\_id) $message"
		return "ERROR"	
	} 
	
	# Synchronize the camera clock. The segments will be timestamped on the camera, 
	# so the remote clock must be accurate. We synchronize it now, and periodically
	# in the transfer process.
	LWDAQ_print $info(text) "$info(cam$n\_id) Synchronizing camera clock."
	if {[Videoarchiver_synchronize $n] == "ERROR"} {
		return "ERROR"
	}

	# Start compression on the camera.
	if {[catch {Videoarchiver_compress $n} message]} {
		LWDAQ_print $info(text) "ERROR: $info(cam$n\_id) $message"
		Videoarchiver_stop $n
		return "ERROR"	
	} 
	
	# Start the segmentation on the camera.
	if {[catch {Videoarchiver_segment $n} message]} {
		LWDAQ_print $info(text) "ERROR: $info(cam$n\_id) $message"
		Videoarchiver_stop $n
		return "ERROR"	
	} 

	# Start transfer of files from camera with concatination.
	LWDAQ_print $info(text) "$info(cam$n\_id) Starting remote transfer process\
		 with period $config(transfer_period_s) s." $config(s_col)
	set info(cam$n\_ttime) [clock seconds]
	set info(cam$n\_file) [file join $info(cam$n\_dir) V0000000000.mp4]
	LWDAQ_post [list Videoarchiver_transfer $n]

	# We can now say that we are recording, and return a success flag.
	set info(cam$n\_state) "Record"	
	return "SUCCESS"
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
		LWDAQ_print $info(text) "ERROR: No camera with index $n to restart."
		return "STOP"
	}

	# If the camera state is Record, set it to Stalled and reset the
	# lag indicator.
	if {$info(cam$n\_state) == "Record"} {
		set info(cam$n\_state) "Stalled"
		set info(cam$n\_lag) "?"
		LWDAQ_set_fg $info(cam$n\_laglabel) gray
	}
	
	# Check the camera state. If the state is no longer Stalled, 
	# don't try to restart.
	if {$info(cam$n\_state) != "Stalled"} {
		return "STOP"
	}
	
	# If we don't pass a value for the start time, this is because the
	# restart has been requested by one of the recording processes.
	# We set the start time to the current time and write a message
	# to the screen and log.
	if {$start_time == ""} {
		set start_time [clock seconds]
		LWDAQ_print $info(text) "$info(cam$n\_id) Will try to restart recording every\
			$config(restart_wait_s) seconds."
		LWDAQ_print $config(restart_log) \
			"$info(cam$n\_id) Recording stalled at [clock format $start_time]."
	}

	# If restart_wait_s seconds have not yet passed since start time, post the 
	# restart operation to the queue. We don't want to try too often to
	# restart or else we will slow the other cameras down.
	if {[clock seconds] - $start_time < $config(restart_wait_s)} {
		LWDAQ_post [list Videoarchiver_restart_recording $n $start_time]
		return "WAITING"
	}
	
	# To re-start, we stop the camera and then try to start recording
	# using existing routines that catch their own errors and return
	# the ERROR word when they fail. 
	LWDAQ_print $info(text) "$info(cam$n\_id) Trying to re-start video recording after fatal error."
	set result [Videoarchiver_record $n]
	
	# If the recording process returned an error, we try to restart
	# again.
	if {$result == "ERROR"} {
		set info(cam$n\_state) "Stalled"
		LWDAQ_post [list Videoarchiver_restart_recording $n [clock seconds]]
		return "FAIL"
	}
	
	# If we get here, we were successful. Note the time we re-started recording
	LWDAQ_print $config(restart_log) \
		"$info(cam$n\_id) Recording restarted at [clock format [clock seconds]]."
	return "SUCCESS"
}

#
# Videoarchiver_transfer downloads video segments from the camera, where they are 
# being compressed. Keeps the camera clock synchronized. Arranges video segments in 
# correct order adds to recording file. 
#
proc Videoarchiver_transfer {n} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info
	global LWDAQ_Info
	
	# Know when to quit. The transfer process quits if the window is gone.
  	if {![LWDAQ_widget_exists $info(window)]} {
		return "STOP"
 	}

	# Get IP address and open an interface socket.
	set ip [Videoarchiver_ip $n]

	# Don't try to contact a non-existent camera.
	if {$ip == $info(null_addr)} {
		LWDAQ_print $info(text) "ERROR: No camera with list index $n."
		return "FAIL"
	}

	# We move to the scratch directory because file names are simpler
	# when calling mplayer and ffmpeg so we can use the same command line
	# code for all operating systems.
	cd [Videoarchiver_segdir $n]
	
	# If recording has been stopped, we don't want to try to contact the
	# camera because its interface will have been stopped too. Instead,
	# we will skip the downloading and transfer all remaining segments,
	# then stop.
	if {$info(cam$n\_state) == "Record"} {

		# Get a list of segments that are available for download on the camera. 
		set when "fetching segment list"
		if {[catch {
			set sock [LWDAQ_socket_open $ip\:$info(tcl_port) basic]
			LWDAQ_socket_write $sock "glob -nocomplain tmp/V*.mp4\n"
			set seg_list [LWDAQ_socket_read $sock line]
			set seg_list [regsub -all {tmp/} $seg_list ""]
			LWDAQ_socket_close $sock
		} message]} {
			set error_description "ERROR: $message while $when for $info(cam$n\_id)."
			LWDAQ_print $info(text) $error_description
			LWDAQ_print $config(restart_log) $error_description
			catch {LWDAQ_socket_close $sock}
			LWDAQ_post [list Videoarchiver_restart_recording $n]
			return "FAIL"
		}
		
		# If there are one or more segments available, download up to transfer_max_files of them
		# from the camera, save to the local segment directory, and delete from the camera.
		if {$seg_list != ""} {
		
			# Sort the segment list into increasing order, which will be oldest to newest. Take
			# from this list up to transfer_max_files names.
			set seg_list [lrange [lsort -increasing $seg_list] \
				0 [expr $config(transfer_max_files) - 1]]
				
			if {[catch {
			
				# Open a socket to the camera. We will use the same socket to 
				# download all segment files.
				set sock [LWDAQ_socket_open $ip\:$info(tcl_port) basic]

				# Start a timer and zero a data size accumulator.
				set start_ms [clock milliseconds]
				set data_size 0

				# Download, save, and delete each file.
				foreach sf $seg_list {
					# Download the first segment, adding its size to the total number
					# of bytes transferred.
					set when "downloading $sf"
					LWDAQ_socket_write $sock "getfile tmp/$sf\n"
					set size [LWDAQ_socket_read $sock line]
					if {[LWDAQ_is_error_result $size]} {error $size}
					set data_size [expr $data_size + $size]
					set contents [LWDAQ_socket_read $sock $size]
	
					# Delete the original segment file.
					set when "deleting original $sf"
					LWDAQ_socket_write $sock "file delete tmp/$sf\n"
					set result [LWDAQ_socket_read $sock line]
					if {[LWDAQ_is_error_result $result]} {error $result}
	
					# Write the file to disk.
					set when "saving copy $sf"
					set f [open $sf w]
					fconfigure $f -translation binary
					puts -nonewline $f $contents
					close $f
				}
				
				# Get temperature and frequency of CPU.
				set when "measuring temperature"
				LWDAQ_socket_write $sock "gettemp\n"
				set temp [LWDAQ_socket_read $sock line]
				set when "measuring frequency"
				LWDAQ_socket_write $sock "getfreq\n"
				set freq [LWDAQ_socket_read $sock line]
				
				# Close the socket.
				LWDAQ_socket_close $sock

				# Calculate download time.			
				set download_ms [expr [clock milliseconds] - $start_ms]

				# Calculate the time lag between the current time and the timestamp
				# of the last segment we downloaded and saved.
				set when "reporting"
				set sf [lindex $seg_list end]
				if {[regexp {V([0-9]{10})} $sf match timestamp]} {
					set lag [expr [clock seconds] - $timestamp]
				} else {
					set lag "?"
				}
				
				# If verbose, report to text window.
				if {$config(verbose)} {
					LWDAQ_print $info(text) "$info(cam$n\_id)\
						Transferred [llength $seg_list] segments,\
						[format %.1f [expr 0.001*$data_size]] kByte in $download_ms ms,\
						lag $lag s, $freq GHz, $temp C, $ip." $config(v_col)
				}
				
				# If the recording monitor is running for this channel, load the new segments 
				# into the monitor
				if {($info(monitor_cam) == $n) && ($info(monitor_channel) != "none")} {
					set when "loading monitor"
					foreach sf $seg_list {Videoarchiver_monitor $n Write \
						"loadfile [file join [Videoarchiver_segdir $n] $sf] 1"}
					if {$config(verbose)} {
						regexp {V([0-9]{10})} [lindex $seg_list 0] match tfirst
						set tnow [clock seconds]
						LWDAQ_print $info(text) "$info(cam$n\_id)\
							Added [llength $seg_list] segments to monitor playlist,\
							monitor lagging by [expr $tnow-$tfirst+1] s." $config(v_col)
					}
				}
				
				# Check the lag and set the lag label accordingly.
				set when "checking lag"
				if {[string is double -strict $lag]} {
					set info(cam$n\_lag) "[set lag] s"
					if {$lag > $config(lag_reset)} {
						error "Lagging by $lag seconds"
					} elseif {$lag > $config(lag_alarm)} {
						LWDAQ_set_fg $info(cam$n\_laglabel) red
					} elseif {$lag > $config(lag_warning)} {
						LWDAQ_set_fg $info(cam$n\_laglabel) orange
					} else {
						LWDAQ_set_fg $info(cam$n\_laglabel) green
					}
				} else {
					set info(cam$n\_lag) "?"
					LWDAQ_set_fg $info(cam$n\_laglabel) gray
				}
				
			} message]} {
				set error_description "ERROR: $message while $when for $info(cam$n\_id)."
				LWDAQ_print $info(text) $error_description
				LWDAQ_print $config(restart_log) $error_description
				catch {LWDAQ_socket_close $sock}
				LWDAQ_post [list Videoarchiver_restart_recording $n]
				return "FAIL"
			}
		}
	}
	
	# Compose a list of local segments in order oldest to newest.
	set seg_list [lsort -dictionary [glob -nocomplain V*.mp4]]
	
	if {[catch {
		# If we have one or more segments available for transfer, calculate the time remaining
		# to complete the existing recording file. If this time is zero or less, or if there
		# is no recording file created yet, we copy the first available segment into the 
		# recording directory to act as the new recording file.
		if {[llength $seg_list] > 0} {
		
			# We look at the first file in the list, which is the oldest file. We want to know
			# how much video time remains to complete the current recording file from the 
			# start time of this oldest segment. 
			set when "calculating time remaining"
			set infile [lindex $seg_list 0]
			if {![regexp {V([0-9]{10})} $infile match segment_time]} {
				catch {file delete $infile}
				error "Unexpected file \"$infile\""
			}
			set time_remaining [expr $config(record_length_s) - $segment_time + $info(cam$n\_rt)]
				
			# If the recording file does not exist, or the time remaining in the existing recording
			# file is zero or less, we create a new file in the recording directory by moving the 
			# first segment into the recording directory.
			if {![file exists $info(cam$n\_file)] || ($time_remaining <= 0)} {
			
				if {$config(verbose)} {
					LWDAQ_print $info(text) "$info(cam$n\_id) Creating $infile,\
						time [clock format $segment_time], $ip." $config(v_col)
				}
				set info(cam$n\_file) [file join $info(cam$n\_dir) $infile]
				set info(cam$n\_rt) $segment_time
				file rename $infile $info(cam$n\_file)
				set info(cam$n\_ttime) [clock seconds]
				
				# If we are still recording, we take take this opportunity to synchronize the
				# camera clock. Otherwise, don't bother because we have stopped transferring
				# segments, and this may be because of a communication problem, which would 
				# result in the synchronization failing.
				if {$info(cam$n\_state) == "Record"} {Videoarchiver_synchronize $n}
	
				# Delete the first segment from the segment list, now that it has been moved.
				set seg_list [lrange $seg_list 1 end]
			}
		}
	
		# If we still have two or more segments available, we have an opportunity to transfer
		# segments into the recording file. We will not attempt a transfer if there is only
		# one segment available, because this segment may be loaded into the recording 
		# monitor play list.
		if {[llength $seg_list] > 1} {
								
			# If the time since our previous transfer is greater than or equal to 
			# transfer_period_s, we transfer segments into the recording file. And if the 
			# state of the camera is no longer Record, we finish up by transferring segments. 
			if {([clock seconds] - $info(cam$n\_ttime) > $config(transfer_period_s)) \
				|| ($info(cam$n\_state) != "Record")} {
	
				# Open a text file into which we are going to write a list of segments to
				# transfer to the recording file.
				set when "composing segment list"
				set ifl [open transfer_list.txt w]
	
				# Here we must make sure that we give ffmpeg a native-format file path to
				# the recording directory. We have to specify backslashes with double-
				# backslashes in ffmpeg file lists, so here we replace each backslash in
				# the native name with two backslashes. We have to specify each backslash
				# in the regsub command with two backslashes, so the resulting regular
				# expression is as follows.
				puts $ifl "file [regsub -all {\\} [file nativename $info(cam$n\_file)] {\\\\}]"
				
				# We go through the available segments, up to but not including the most recent
				# segment, and check to see if it belongs in the recording file. We do not include
				# the most recent segment because this one may be loaded into the monitor.
				set transfer_segments [list]
				foreach infile [lrange $seg_list 0 end-1] {
					if {![regexp {V([0-9]{10})} $infile match segment_time]} {
						LWDAQ_print $info(text) "WARNING: $info(cam$n\_id) Deleting unexpected\
							file \"$infile\", $ip."
						catch {file delete $infile}
						LWDAQ_post [list Videoarchiver_transfer $ip]
						return "FAIL"	
					}
					set time_remaining [expr $config(record_length_s) \
						- ($segment_time - $info(cam$n\_rt))]
					if {$time_remaining > 0} {
						puts $ifl "file $infile"
						lappend transfer_segments $infile
					} else {
						break
					}
				}
				
				# Our list is complete.
				close $ifl
				
				# To be safe, we attempt to concatinate only if we have at least one file
				# in our list, although we should always have one or more at this point.
				set num_segments [llength $transfer_segments]
				if {$num_segments > 0} {
					if {$config(verbose)} {
						LWDAQ_print $info(text) "$info(cam$n\_id) Adding $num_segments segments\
							to [file tail $info(cam$n\_file)], $ip." $config(v_col)
					}
	
					# We take this opportunity to remove excess lines from the text window.
					set when "deleting old text"
					$info(text) delete 1.0 "end [expr 0 - $info(num_lines_keep)] lines"			
					
					# We are going to copy the existing video file into a temporary
					# file, followed by copying one or more compressed segments.
					# We want the temporary file in the same directory as the recording
					# file so that, when we replace the recording file with the temporary
					# file, all we have to do is delete the recording file and rename the
					# temporary file, rather than copying a video file. If we were to 
					# put the temporary file in the segment directory, this might be on
					# a different volume from the recording directory, and moving the 
					# completed temporary file would require copying and deleting.
					set tempfile [file join $info(cam$n\_dir) Temporary.mp4]
					
					# Here is where the transfer of files into the current recording file
					# takes place. We use the ffmpeg concatination function, passing
					# to ffmpeg the list of files to add to the recording file. The
					# result is a new file, tempfile. 
					set when "concatinating segments"
					exec $info(ffmpeg) \
						-nostdin -f concat -safe 0 -loglevel error \
						-i transfer_list.txt -c copy \
						[file nativename $tempfile] \
						 > transfer_log.txt
					
					# We replace the previous recording file with the newly created
					# video file, delete the old file, and delete all the compressed
					# segments from the segments directory.
					set when "renaming video file"
					foreach infile $transfer_segments {
						file delete $infile
					}
					file delete $info(cam$n\_file)
					file rename $tempfile $info(cam$n\_file)
					
					# We mark this transfer time.
					set info(cam$n\_ttime) [clock seconds]
				} else {
					# We don't expect to end up here. If we have more than one segment, we must
					# have at least one that we can transfer. But if file names are corrupted,
					# we could end up here. 
					error "Expected segments but found none"
				}
			}
		} 
	} message]} {
		set error_description "ERROR: $message while $when for $info(cam$n\_id)."
		LWDAQ_print $info(text) $error_description
		LWDAQ_print $config(restart_log) $error_description
		LWDAQ_post [list Videoarchiver_restart_recording $n]
		return "FAIL"
	}
	
	# If we are no longer recording, stop the transfer process, otherwise re-post it.
	if {$info(cam$n\_state) == "Record"} {
		LWDAQ_post [list Videoarchiver_transfer $n]
		return "SUCCESS"
	} else {
		LWDAQ_print $info(text) "$info(cam$n\_id) Stopped remote\
			transfer process, $ip." $config(s_col)
		return "STOP"
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
		LWDAQ_print $info(text) "ERROR: No camera with list index $n."
		return "ERROR"
	}
	
	# Set the state variable and reset the lag indicator.
	set info(cam$n\_state) "Stop"
	set info(cam$n\_lag) "?"
	LWDAQ_set_fg $info(cam$n\_laglabel) gray

 	if {![LWDAQ_widget_exists $info(window)]} {
 		set info(text) stdout
 	}
	
	set ip [Videoarchiver_ip $n]
	
	Videoarchiver_monitor $n "Stop"

	if {[LWDAQ_process_exists $info(cam$n\_lproc)]} {
		LWDAQ_process_stop $info(cam$n\_lproc)
		LWDAQ_print $info(text) "$info(cam$n\_id) Stopped local live process, $ip." 
	}
	
	LWDAQ_print $info(text) "$info(cam$n\_id) Stopping streaming, segmentation,\
		and compression, $ip."
	LWDAQ_update
	cd $info(main_dir)
	catch {exec $info(ssh) \
		-o ConnectTimeout=$config(connect_timeout_s) \
		-o UserKnownHostsFile=/dev/null \
		-o StrictHostKeyChecking=no \
		-o LogLevel=error \
		-i [file join $info(keys_dir) id_rsa] \
		"$info(camera_login)@$ip" \
		$info(stop)]} message
	if {![regexp "SUCCESS" $message]} {
		LWDAQ_print $info(text) "ERROR: $info(cam$n\_id) Failed to connect to $ip with ssh."
	}
	
	set info(cam$n\_state) "Idle"
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
	
	return "SUCCESS"
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
	
	return "SUCCESS"
}

#
# Videoarchiver_killall kills all ffmpeg and mplayer processes.
#
proc Videoarchiver_killall {ip} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	if {$info(os) == "Windows"} {
		catch {eval exec [auto_execok taskkill] /IM mplayer.exe /F} message
		if {[regexp "SUCCESS" $message]} {
			LWDAQ_print $info(text) "Stopped additional mplayer processes." 
		}
	} else {
		catch {eval exec [auto_execok killall] -9 mplayer} message
		if {$message == ""} {
			LWDAQ_print $info(text) "Stopped additional mplayer processes." 
		}
	}

	if {$info(os) == "Windows"} {
		catch {eval exec [auto_execok taskkill] /IM ffmpeg.exe /F} message
		if {[regexp "SUCCESS" $message]} {
			LWDAQ_print $info(text) "Stopped additional mplayer processes." 
		}
	} else {
		catch {eval exec [auto_execok killall] -9 ffmpeg} message
		if {$message == ""} {
			LWDAQ_print $info(text) "Stopped additional ffmpeg processes." 
		}
	}
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
		return "SUCCESS"
	}

	# Don't try to change master recording directory if any camera is 
	# currently recording or even stalled.
	foreach n $info(cam_list) {
		if {($info(cam$n\_state) == "Record") || ($info(cam$n\_state) == "Stalled")} {
			LWDAQ_print $info(text) "ERROR: Cannot change recording directory while\
				$info(cam$n\_id) is recording."
			return "ERROR"
		}
	}

	# Ask the user to pick an existing directory. If they don't, 
	# we don't change the recording directory and we print out an 
	# error message.
	set dn [LWDAQ_get_dir_name $config(recording_dir)]
	if {![file exists $dn]} {
		LWDAQ_print $info(text) "ERROR: Proposed recording directory \"$dn\" does not exist."
		return "ERROR"
	} else {
		set config(recording_dir) $dn
		return $dn
	}
	
	# If we get here, we are okay.
	return "SUCCESS"
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
		LWDAQ_print $info(text) $result
		return "ERROR"
	} else {
		return "SUCCESS"
	}
}

#
# Videoarchiver_suggest_download prints a message with a text link suggesting that
# the user download the Videoarchiver directory to install FFMPEG and MPLAYER.
#
proc Videoarchiver_suggest_download {} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	LWDAQ_print $info(text) ""
	LWDAQ_print $info(text) "  Click on link below to download Videoarchiver library zip archive."
	$info(text) insert end "           "
	$info(text) insert end "$info(library_archive)" "textbutton download"
	$info(text) tag bind download <Button> Videoarchiver_download_libraries
	$info(text) insert end "\n"
	LWDAQ_print $info(text) {
After download, expand the zip archive. Move the entire Videoarchiver directory
into the same directory as your LWDAQ installation, so the LWDAQ and
Videoarchiver directories will be next to one another. You now have Mplayer, and
FFMpeg installed for use by the Videoarchiver and Neuroplayer on Linux, MacOS,
and Windows.
	}
}

#
# Videoarchiver_check_libraries heck to see if the mplayer, ffpeg, and ssh programs 
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
				LWDAQ_print $info(text) "The ssh executable should be in\
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
		LWDAQ_print -nonewline $info(text) "Checking mplayer utility... " 
		catch {exec $info(mplayer) -V} message
		if {[regexp "MPlayer" $message]} {
			LWDAQ_print $info(text) "success."
		} else {
			LWDAQ_print $info(text) "FAIL."
			LWDAQ_print $info(text) "ERROR: $message"
			LWDAQ_print $info(text) "The mplayer executable should be in\
				[file dirname $info(mplayer)]."
			set suggest 1
		}
	}
	if {$suggest} {
		Videoarchiver_suggest_download
	}
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
			set info(cam$n\_ttime) "0"
			set info(cam$n\_lproc) "0"
			set info(cam$n\_rt) "0"
			set info(cam$n\_ver) "A3034B_HR"
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
		
		button $ff.live -text "Live" -fg green -padx $padx -command \
			[list LWDAQ_post "Videoarchiver_live $n" front]
		button $ff.record -text "Rec" -fg red -padx $padx -command \
			[list LWDAQ_post "Videoarchiver_record $n" front]
		button $ff.monitor -text "MRec" -fg orange -padx $padx -command \
			[list LWDAQ_post "Videoarchiver_monitor $n" front]
		button $ff.stop -text "Stop" -fg black -padx $padx -command \
			[list LWDAQ_post "Videoarchiver_stop $n" front]
		pack $ff.live $ff.record $ff.monitor $ff.stop -side left -expand 1

		button $ff.ch -text "IP" -padx $padx -command [list Videoarchiver_ask_ip $n]
		pack $ff.ch -side left -expand 1
	
		entry $ff.addr_value -textvariable Videoarchiver_info(cam$n\_addr) -width 14
		pack $ff.addr_value -side left -expand 0

		set m [tk_optionMenu $ff.verm Videoarchiver_info(cam$n\_ver) none]
		$m delete 0 end
		foreach version $config(versions) {
			$m add command -label [lindex $version 0] \
				-command [list set Videoarchiver_info(cam$n\_ver) [lindex $version 0]]
		}	
		pack $ff.verm -side left -expand 1

		label $ff.rotl -text "Rot:" -fg brown -justify right
		pack $ff.rotl -side left -expand 0
		set m [tk_optionMenu $ff.rotm Videoarchiver_info(cam$n\_rot) none]
		$m delete 0 end
		foreach rotation $info(rotation_options) {
			$m add command -label "$rotation" \
				-command [list set Videoarchiver_info(cam$n\_rot) $rotation]
		}	
		pack $ff.rotm -side left -expand 1
	
		label $ff.ecl -text "EC:" -fg brown -justify right
		pack $ff.ecl -side left -expand 0
		set m [tk_optionMenu $ff.ecm Videoarchiver_info(cam$n\_ec) none]
		$m delete 0 end
		for {set ec -10} {$ec <= +10} {incr ec} {
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
		LWDAQ_print $info(text) "ERROR: No camera with list index $n."
		return "ERROR"
	}
	
	set w $info(window)\.remove$n
	if {[winfo exists $w]} {
		raise $w
		return "FAIL"
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

	return "SUCCESS"
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
		LWDAQ_print $info(text) "ERROR: No camera with list index $n."
		return "ERROR"
	}
	
	# Check the state of the camera.
	if {$info(cam$n\_state) != "Idle"} {
		LWDAQ_print $info(text) "ERROR: $info(cam$n\_id) Wait until Idle\
			before removing camera from list."
		return "ERROR"
	}
	
	catch {destroy $info(window).cam_list.cam$n}
	set info(cam_list) [lreplace $info(cam_list) $index $index]
	unset info(cam$n\_id)
	unset info(cam$n\_ver)
	unset info(cam$n\_addr)
	unset info(cam$n\_ec)
	unset info(cam$n\_rot)
	unset info(cam$n\_sat)
	unset info(cam$n\_dir)
	unset info(cam$n\_file)
	unset info(cam$n\_state)
	unset info(cam$n\_ttime)
	unset info(cam$n\_lproc)
	unset info(cam$n\_rt)
	unset info(cam$n\_white)
	unset info(cam$n\_infrared)
	unset info(cam$n\_lag)
	unset info(cam$n\_laglabel)
	
	return "SUCCESS"
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
	set info(cam$n\_ver) "A3034B-HR"
	set info(cam$n\_addr) $info(default_ip_addr)
	set info(cam$n\_ec) "4"
	set info(cam$n\_rot) "0"
	set info(cam$n\_sat) "0"
	set info(cam$n\_dir) [file normalize "~/Desktop"]
	set info(cam$n\_file) [file join $info(cam$n\_dir) V0000000000.mp4]
	set info(cam$n\_state) "Idle"
	set info(cam$n\_ttime) "0"
	set info(cam$n\_lproc) "0"
	set info(cam$n\_rt) "0"
	set info(cam$n\_white) "0"
	set info(cam$n\_infrared) "0"
	set info(cam$n\_lag) "?"
	
	# Re-draw the sensor list.
	Videoarchiver_draw_list
	
	return "SUCCESS"
}

#
# Videoarchiver_save_list save a camera list to disk.
#
proc Videoarchiver_save_list {{fn ""}} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info
	
	
	# Try to get a valid file name.
	if {$fn == ""} {
		set fn [LWDAQ_put_file_name "CamList.tcl"]
		if {$fn == ""} {return "FAIL"}
	}

	# Write camera list to disk.
	set f [open $fn w]
	puts $f "set Videoarchiver_info(cam_list) \"$info(cam_list)\""
	puts $f "set Videoarchiver_config(recording_dir) \"$config(recording_dir)\""
	foreach p [lsort -dictionary [array names info]] {
		if {[regexp {cam[0-9]+_} $p]} {
			puts $f "set Videoarchiver_info($p) \"[set info($p)]\"" 
		}
		foreach a {white_on white_off infrared_on infrared_off} {
			if {[regexp $a $p]} {
				puts $f "set Videoarchiver_info($p) \"[set info($p)]\"" 
			}
		}
	}
	close $f
	
	# Change the camera list file parameter.
	set config(cam_list_file) $fn

	return "SUCCESS"
}

#
# Videoarchiver_load_list loads a camera list from disk. If we don't
# specify the list file name, the routine uses a browser to get a file
# name.
#
proc Videoarchiver_load_list {{fn ""}} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info
	
	# We won't load a new list so long as even one camera is not idle.
	foreach n $info(cam_list) {
		if {$info(cam$n\_state) != "Idle"} {
			LWDAQ_print $info(text) "ERROR: Cannot load new camera list while\
				$info(cam$n\_id) is busy."
			return "ERROR"
		}
	}

	# Try to get a valid file name.
	if {$fn == ""} {
		set fn [LWDAQ_get_file_name]		
		if {$fn == ""} {return "FAIL"}
	} else {
		if {![file exists $fn]} {return "FAIL"}
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
		LWDAQ_print $info(text) "ERROR: $error_message."
		return
	}
	
	# Change the camera list file name to match the newly-loaded file.
	set config(cam_list_file) $fn
	
	return "SUCCESS"
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
	
	# Routines to view and clear the restart log. We make sure they run
	# in the LWDAQ event queue so we don't get a file access conflict
	# with the recording processes.
	foreach a {View_Restart_Log Clear_Restart_Log} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post Videoarchiver_$b"
		pack $f.$b -side top -expand 1
	}
	
	return "SUCCESS" 
}

#
# Videoarchiver_lamps_adjust sets all lamps of a particular color to a specified intensity, 
# but does so taking "step" seconds per change in intensity. It uses the intensity value
# stored in the camera info arrays to find the current intensity.
#
proc Videoarchiver_lamps_adjust {color intensity {step "1"} {previous "0"}} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info
	
	if {$previous == 0} {
		LWDAQ_print $info(text) "Started adjustment of $color lamps to intensity\
			$intensity with step $step s at\
			[clock format [clock seconds] -format $config(datetime_format)]."
	}
	
	if {[clock seconds] - $previous < $step} {
		LWDAQ_post [list Videoarchiver_lamps_adjust $color $intensity $step $previous]
		return "WAIT"
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
			return "ADJUSTED"
		} else {
			LWDAQ_print $info(text) "Completed adjustment of $color lamps to intensity\
				$intensity at [clock format [clock seconds] \
				-format $config(datetime_format)]."
			return "DONE"
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
		return "ABORT"
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

		label $f.ldymo -text "Day_of_Month:" -fg brown -justify right
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

		label $f.ldywk -text "Day_of_Week:" -fg brown -justify right
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

		label $f.lstep -text "Step_Seconds:" -fg brown -justify right
		pack $f.lstep -side left -expand 0
		entry $f.estep -textvariable Videoarchiver_info($a\_step) -width 5
		pack $f.estep -side left -expand 1
	}
	
	return "SUCCESS"
}

#
# Videoarchiver_schedule_start schedules all Videoarchiver scheduled tasks.
#
proc Videoarchiver_schedule_start {} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	foreach a {white_on white_off infrared_on infrared_off} {
		set schedule "$info($a\_min) $info($a\_hr) $info($a\_dymo)\
			$info($a\_mo) $info($a\_dywk)"
		LWDAQ_print $info(text) "Scheduled task $a\
			with schedule \"$schedule\"\
			intensity $info($a\_int)\
			and step interval $info($a\_step) s."
		LWDAQ_schedule_task $a $schedule \
			"Videoarchiver_lamps_adjust [regsub {_.*} $a ""] $info($a\_int) $info($a\_step)"
	}
	set info(scheduler_state) "Run"
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
	LWDAQ_queue_clear "Videoarchiver*"
	set info(scheduler_state) "Stop"
	LWDAQ_print $info(text) "Unscheduled all tasks, aborted all tasks,\
		aborted tasks remain incomplete."
}

#
# Videoarchiver_open creates the Videoarchiver's user interface.
#
proc Videoarchiver_open {} {
	upvar #0 Videoarchiver_config config
	upvar #0 Videoarchiver_info info

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return "ABORT"}
	if {$w == "."} {set w ""}
	scan [wm maxsize .] %d%d x y
	
	switch $info(mode) {
		"Main" {
			wm title $w "Videoarchiver $info(version), Running in Main Process"
			wm maxsize $w [expr $x*2] [expr $y*2]
		}	
		"Child" {
			wm title . "Videoarchiver $info(version), Running in Child Process"
			wm maxsize . [expr $x*2] [expr $y*2]
		}	
	}
	
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

	LWDAQ_print $info(text) "$info(name) Version $info(version)" purple
	
	# If the camera list file exist, load it.
	if {[file exists $config(cam_list_file)]} {
		Videoarchiver_load_list $config(cam_list_file)
	}
	
	Videoarchiver_check_libraries
	
	return "SUCCESS"
}

Videoarchiver_init
Videoarchiver_open

return "SUCCESS"

----------Begin Help----------

http://www.opensourceinstruments.com/Electronics/A3034/Videoarchiver.html

----------End Help----------

----------Begin Data----------
<script>
# The TCPIP interface process that runs on the camera. It opens a server socket that
# will receive connections and allow us to download files, get directory listings, and
# other tasks. We assume its stdout it directed to a log file.
#
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

# Announce the start of interface in stdout.
puts "Starting interface process at [clock seconds] with:"
puts "verbose = $verbose, port = $port, maxshow = $maxshow."

# The socket acceptor receives a connection, sets up a socket channel, and configures
# it so that every time it is readable, the incoming data is passed to the interpreter
# procesdure.
proc accept {sock addr port} {
	global verbose

	# Configure the socket with line buffering, so it can receive text 
	# commands with ease.
	fconfigure $sock -translation auto -buffering line
	
	# Call the interpreter every time a complete command has been received.
	fileevent $sock readable [list interpreter $sock]
	
	if {$verbose} {puts "$sock connection from $addr at [clock seconds]."}
	return 1
}

# The interpreter implements a set of commands for the Videoarchiver. We call this
# procedure whenever the socket is readable.
proc interpreter {sock} {
	global verbose maxshow

	# If the client closes the socket, we do the same.
	if {[eof $sock]} {
		if {$verbose} {puts "$sock closed by client at [clock seconds]."}
		close $sock
		return 1
	}	
	
	# Read the command line from the socket.
	if {[catch {gets $sock line} result]} {
		if {$verbose} {puts "$sock broken at [clock seconds]."}
		close $sock
		return 1
	}

	# We ignore empty commands.
	set line [string trim $line]
	if {$line == ""} {return 1}

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
		# The getfile command asks the interface to read a named file, transmit its
		# size as a string, then transmit the entire file contents as a binary object.
		if {$cmd == "getfile"} {
			
			# If the file exists, read its contents. When we read the file, we assume 
			# it is binary so that we can read any type of file. If the file does not
			# exist, we set the contents to an empty string and the size to zero.
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
					puts "$sock getfile \"$fn\" does not exist at [clock seconds]."
				}
			}
			
			# Transmit the size of the file contents so the client will know how many
			# bytes it must read. If the file does not exist, the file size will be zero,
			# but we raise no other error.
			puts $sock [string length $contents]
			
			# Now reconfigure the socket for binary data with full buffering and
			# send the contents without a line break at the end. Flush the socket.
			fconfigure $sock -translation binary -buffering full
			puts -nonewline $sock $contents
			flush $sock
			
			# Return the socket to line buffering and automatic line break translation.
			fconfigure $sock -translation auto -buffering line
	
		# The putfile command takes a filename and file contents and writes the contents
		# to the filename on disk. First the command obtains the file name and the size
		# of the file from the command line, then waits for the data to be transferred
		# over the socket.
		} elseif {$cmd == "putfile"} {
			
			# Get the file name and the size of the contents.
			set fn [lindex $argv 0]
			set size [lindex $argv 1]
			if {$verbose} {
				puts "$sock putfile \"$fn\" size $size bytes at [clock seconds]."
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
				puts "Wrote $size bytes to \"$fn\" at [clock seconds]."
			}
			
			# Return the socket to line buffering and automatic line break translation.
			fconfigure $sock -translation auto -buffering line
			
			# Send back the number of bytes written.
			puts $sock $size

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
	
		# The setip command sets the static IP address of the camera
		# by re-writing the dhcpcd.conf file.
		} elseif {$cmd == "setip"} {
			set new_ip [lindex $argv 0]
			if {![regexp {[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+} $new_ip]} {
				error "Invalid internet protocol address \"$new_ip\""
			}
			set new_router_ip [lindex $argv 1]
			if {![regexp {[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+} $new_router_ip]} {
				error "Invalid router internet protocol address \"$new_router_ip\""
			}
			set f [open dhcpcd_default.conf r]
			set contents [read $f]
			close $f
			set contents [regsub -all 10.0.0.34 $contents $new_ip]
			set contents [regsub -all 10.0.0.1 $contents $new_router_ip]
			set f [open temp.txt w]
			puts $f $contents
			close $f
			exec sudo cp temp.txt /etc/dhcpcd.conf
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
			
			# Set the white or infrared lamp intensity.
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
			
			# Return the intensity as confirmation.
			puts $sock $intensity	
			
		# By default, the interface evaluates the entire line as a command
		# at the global scope, and returns the result of the command.
		} else {
			set result [uplevel #0 $line]
			puts $sock $result
		}
	} message]} {
		puts "ERROR: $message, at [clock seconds]."
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
# Compression engine and watchdog to run on the Raspberry Pi. When there are 
# two or more segment files, which we assume is any file named S*.mp4, we take 
# the older of the two, rename it, compress it, and rename it again. In renaming, 
# we transform the ffmpeg year, day, hour, minute, second timestamp in the original
# name into a UNIX timestamp. If there are too many compressed video files in the 
# local directory, the watchdog deletes some of them. We assume that this process
# will run in the background, with stdout directed to a log file. We can pass
# parameters into the process when we start it up. In particular, we must specify
# the framerate for the ffmpeg compressor. It is also a good idea to specify the
# number of compression processes running simultaneously, and give this one an 
# index between 1 and this number so that the compressors can avoid trying to 
# manipulate the same files.
#

# Get the command line arguments.
set framerate 20
set maxfiles 40
set loopwait 200
set processes 1
set index 0
set crf 23
set codec libx264
foreach {option value} $argv {
	switch $option {
		"-framerate" {
			set framerate $value
		}
		"-maxfiles" {
			set maxfiles $value
		}
		"-loopwait" {
			set loopwait $value
		}
		"-processes" {
			set processes $value
		}
		"-index" {
			set index $value
		}
		"-crf" {
			set crf $value
		}
		"-codec" {
			set codec $value
		}
		default {
			puts "WARNING: Unknown option \"$option\"."
		}
	}
}

# Announce the start of compression in stdout.
puts "Starting compression process at [clock seconds] with:"
puts "framerate = $framerate fps, crf = $crf, codec = $codec, maxfiles = $maxfiles,"
puts "processes = $processes, index = $index, loopwait = $loopwait ms."

# Change directory to the ramdisk.
cd tmp

# An infinite loop. This process must be killed if it is to be stopped.
while {1} {

	# We wait a random amount of time before executing, to reduce the probability of collisions.
	after [expr round($loopwait*rand())]

	# Get a list of all the uncompressed files.
	set sfl [lsort -increasing [glob -nocomplain S*.mp4]]
 
	# Look for excessive number of uncompressed segments. If there are more than 
	# maxfiles, delete some of the oldest, but not the oldest, because they might be
	# involved in the start of a compression. We delete as many files as there are
	# processes.
	if {[llength $sfl] >= $maxfiles} {
		puts "ERROR: Too many uncompressed segments, deleting $processes\
			segments at time [clock seconds]."
		for {set i $processes} {$i < 2*$processes} {incr i} {
			if {[catch {
				file delete [lindex $sfl $i]
			} message]} {
				puts "ERROR: $message."
			}
		}
	}
	
	# Extract the segments that match this process index. If the index-1 is equal
	# to the file timestamp modulo the number of processes, or if the index is zero,
	# we add a segment to the list of relevant segments.
	set new_sfl [list]
	foreach sfn $sfl {
		if {[regexp {S([0-9]{10})} [file tail $sfn] match timestamp]} {
			if {($index == 0) || \
					(($timestamp % $processes) == (($index - 1) % $processes))} {
				lappend new_sfl $sfn
			}
		}
	}
	set sfl $new_sfl
	
	# If there is more than one uncompressed segment available, compress the eldest.
	if {[llength $sfl] > 1} {
	
		# Check the file name is of the correct format. If not, we delete it and continue.
		set sfn [lindex $sfl 0]
		if {![regexp {S([0-9]{10})} [file tail $sfn] match timestamp]} {
			puts "ERROR: Bad segment name \"[file tail $sfn]\",\
				deleting segment at time [clock seconds]."
			catch {file delete $sfn}
			continue
		}
	
		# Rename the segment file so other compressors do not try to compress it as well.
		# If we encounter an error during the re-name, this is probably because another
		# compressor just renamed the file while we were checking its name, so just 
		# continue.
		set tfn [file join [file dirname $sfn] [regsub {^S} [file tail $sfn] T]]
		if {[catch {file rename $sfn $tfn} message]} {
			puts "ERROR: Conflict renaming segment $sfn at time [clock seconds]."
			continue
		}
		
		# Use the timestamp to construct the working compression output file
		# and the final compressed video segment file name.
		set wfn W$timestamp\.mp4
		set vfn V$timestamp\.mp4
	
		# Compress with ffmpeg libx264 to produce video with the specified frame rate.
		# If we encounter an ffmpeg error, we report the error but otherwise proceed,
		# because ffmpeg will report errors even though it completes compression. The
		# Pi has a graphics processor, which we can enlist with the h264_omx codec, but
		# we can run only one compressor on this processor at a time, and it is not
		# capable of compressing high-resolution video on its own, even though it is
		# twice as fast as the libx264 compression that runs in the main Pi processor
		# cores. So we instead enlist three of the processor cores into compression
		# simultaneously using the libx264 codec.
		if {[catch {
			exec /usr/bin/ffmpeg -nostdin -loglevel error \
				-r $framerate -i $tfn \
				-c:v $codec -crf $crf -preset veryfast $wfn
		} message]} {
			puts "ERROR: $message during compression of [file tail $tfn] at time [clock seconds]."
		}
	
		# Rename the output file. Report any error but proceed anyway.
		if {[catch {file rename $wfn $vfn} message]} {
			puts "ERROR: $message at [clock seconds]."
		}
		
		# Delete the original segment. Report any error.
		if {[catch {file delete $tfn} message]} {
			puts "ERROR: $message at [clock seconds]."
		}
	}
}
</script>

<script>
# Dynamic Host Configuration Protocol Configuration File for
# the Animal Cage Camera (A3034B), Open Source Instruments Inc.
#
# See dhcpcd.conf(5) for details of the options. This 
# configuration assigns a static IP address to the camera.

# Allow users of this group to interact with dhcpcd via the control socket.
controlgroup wheel

# A static IP configuration. Do not change the static IP address in this
# file unless you are prepared to change it in the Videoarchiver's
# set_ip routine as well.
interface eth0
static ip_address=10.0.0.34/24
static routers=10.0.0.1
</script>

<script>
# Move to the Videoarchiver directory.
cd /home/pi/Videoarchiver

# Set the configuration switch port to input with pull-up
# resistor.
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

# Flash the white LEDs three times, then wait one second.
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

# Check the configuration switch. If it is depressed, we 
# replace the existing /etc/dhcpcd.conf file with the
# dhcpcd_default.conf, which sets the IP address of 
# this camera to the default value 10.0.0.34. While this
# reset is taking place, we turn the white LEDs on half
# power.
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

# Start the TCPIP interface process as user PI.
sudo -u pi bash -c "tclsh interface.tcl -port 2223 > interface_log.txt &"

</script>
----------End Data----------


