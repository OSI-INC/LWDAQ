# Videoplayer.tcl, A LWDAQ Tool to play videos.
#
# Copyright (C) 2023 Kevan Hashemi, Open Source Instruments Inc.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place - Suite 330, Boston, MA 02111-1307, USA.
#
# The Videoplayer records signals from Subcutaneous Transmitters manufactured
# by Open Source Instruments. For detailed help, see:
#
# http://www.opensourceinstruments.com/Electronics/A3018/Videoplayer.html
#
# The Videoplayer reads NDF (Neuroscience Data Format) files from disk. It
# provides play-back of data stored on file, with signal plotting and
# processing.
#

#
# Videoplayer_init creates the info and config arrays. The config array is
# available through the Config button but the info array is private. 
#
proc Videoplayer_init {} {
#
# Here we declare the names of variables we want defined at the global scope.
# Such variables may exist before this procedure executes, and they will endure
# after the procedure concludes. The "upvar #0" assigns a local name to a global
# variable. After the following line, we can, for the duration of this
# procedure, refer to the global variable "Videoplayer_info" with the local
# name "info". The Videoplayer_info variable happens to be an array with a
# bunch of "elements". Each element has a name and a value. Here we will refer
# to the "name" element of the "Videoplayer_info" array with info(name).
#
	upvar #0 Videoplayer_info info
	upvar #0 Videoplayer_config config
	global LWDAQ_Info
#
# We initialise the Videoplayer with LWDAQ_tool_init. Because this command
# begins with "LWDAQ" we know that it's one of those in the LWDAQ command
# library. We can look it up in the LWDAQ Command Reference to find out more
# about what it does.
#
	LWDAQ_tool_init "Videoplayer" "1"
#
# If a graphical tool window already exists, we abort our initialization.
#
	if {[winfo exists $info(window)]} {
		return ""
	}
#
# We start setting intial values for the private display and control variables.
#
	set info(control) "Idle"
	set info(control_label) "none"
#
# File and directory for videos.
#
	set config(video_dir) $LWDAQ_Info(working_dir)
	set config(video_file) [file join $config(video_dir) V0000000000.mp4]
	set config(video_stream) "tcp://192.168.1.31:2222"
#
# Video file properties.
#
	set config(video_file_time) "0"
	set config(video_fps) "20"
	set config(video_width) "820"
	set config(video_height) "616"
	set config(video_rotation) "0"
	set config(video_length_s) "1"
	set config(video_length_f) "20"
	set config(video_pix_fmt) "rgb24"
	set config(video_pix_size) "3"
#
# Display properties.
#
	set info(init_size) "200"
	set config(display_start_s) "0"
	set config(display_end_s) "*"
	set config(display_speed) "1.0"
	set config(display_scale) "0.5"
	set info(display_photo) "videoplayer_photo"
	set info(frame_count) "0"
	set info(display_process) "0"
	set info(display_channel) "none"
	set config(file_timeout_ms) "1000"
	set config(tcp_timeout_ms) "5000"
	set config(read_nocomplain) "0"
#
# Graphical user display configuration.
#
	set config(verbose) "1"
	set config(slave) "0"
#
# Date and time.
#
	set info(datetime_format) {%d-%b-%Y %H:%M:%S}
	set info(datetime_error) "dd-mmm-yyyy hh:mm:ss"
#
# Video tools.
#
	set info(video_library_archive) \
		"http://www.opensourceinstruments.com/ACC/Videoarchiver.zip"
	set info(videoarchiver_dir) [file join $LWDAQ_Info(program_dir) Videoarchiver]
	if {![file exists $info(videoarchiver_dir)]} {
		set info(videoarchiver_dir) \
			[file normalize [file join $LWDAQ_Info(program_dir) .. Videoarchiver]]
	}
	set info(video_scratch) [file join $info(videoarchiver_dir) Scratch]
	set info(log_file) [file join $info(video_scratch) Videoplayer_log.txt]
	set os_dir [file join $info(videoarchiver_dir) $LWDAQ_Info(os)]
	if {$LWDAQ_Info(os) == "Windows"} {
		set info(ffmpeg) [file join $os_dir ffmpeg/bin/ffmpeg.exe]
	} elseif {$LWDAQ_Info(os) == "MacOS"} {
		set info(ffmpeg) [file join $os_dir ffmpeg]
	} elseif {$LWDAQ_Info(os) == "Linux"} {
		set info(ffmpeg) [file join $os_dir ffmpeg/ffmpeg]
	} elseif {$LWDAQ_Info(os) == "Raspbian"} {
		set info(ffmpeg) "/usr/bin/ffmpeg"
	} else {
		Videoplayer_print "WARNING: Video playback may not work on $LWDAQ_Info(os)."
		set info(ffmpeg) "/usr/bin/ffmpeg"
	}
#
# The Save button in the Configuration Panel allows you to save your own
# configuration parameters to disk a file called settings_file_name. 
#
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 
#
# We are done with initialization. We return a 1 to show success.
#
	return ""   
}

#
# Videoplayer_configure calls the standard LWDAQ tool configuration
# routine to produce a window with an array of configuration parameters
# that the user can edit.
#
proc Videoplayer_configure {} {
	upvar #0 Videoplayer_config config
	upvar #0 Videoplayer_info info
	LWDAQ_tool_configure Videoplayer 4
	return ""
}

#
# Videoplayer_download downloads the Videoarchiver zip archive with the
# help of a web browser.
#
proc Videoplayer_download {} {
	upvar #0 Videoplayer_config config
	upvar #0 Videoplayer_info info

	set result [LWDAQ_url_open $info(video_library_archive)]
	if {[LWDAQ_is_error_result $result]} {
		LWDAQ_print $info(text) $result
	}
	return ""
}

#
# Videoplayer_suggest prints a message with a text link suggesting that
# the user download the Videoarchiver directory to install ffmpeg.
#
proc Videoplayer_suggest {} {
	upvar #0 Videoplayer_config config
	upvar #0 Videoplayer_info info

	LWDAQ_print $info(text) ""
	LWDAQ_print $info(text) \
		"ERROR: Cannot play videos, Videoarchiver package not installed."
	LWDAQ_print $info(text) \
		"  To install libraries, click on the link below which will download a zip archive."
	$info(text) insert end "           "
	$info(text) insert end \
		"$info(video_library_archive)" "textbutton download"
	$info(text) tag bind download <Button> Videoplayer_download
	$info(text) insert end "\n"
	LWDAQ_print $info(text) {
After download, expand the zip archive. Move the entire Videoarchiver directory
into the same directory as your LWDAQ installation, so the LWDAQ and
Videoarchiver directories will be next to one another. You now have FFMpeg
installed for use by the Videoarchiver and Videoplayer on Linux, MacOS, and
Windows.
	}
}

#
# Videoplayer_print writes a line to the text window, if it exists, and to
# the console if we are running as a slave. When verbose is set, we print
# things with color "verbose", otherwise we do not. We never print verbose
# information to stdout.
#
proc Videoplayer_print {line {color "black"}} {
	upvar #0 Videoplayer_config config
	upvar #0 Videoplayer_info info
	
	if {$info(mode) == "Slave"} {
		if {$color != "verbose"} {
			catch {puts $line}
		}
	} else {
		if {$config(verbose) \
				|| [regexp "^WARNING: " $line] \
				|| [regexp "^ERROR: " $line] \
				|| ($color != "verbose")} {
			if {$color == "verbose"} {
				LWDAQ_print $info(text) $line black
			} else {
				LWDAQ_print $info(text) $line $color
			}
		}
	}
	return ""
}

#
# Videoplayer_info calls ffmpeg to determine the width, height, framerate
# and duration of an existing video file. The framerate is frames per second.
# The duration is in seconds. If the file does not exist, the routine returns "0
# 0 0 -1".
#
proc Videoplayer_info {fn} {
	upvar #0 Videoplayer_config config
	upvar #0 Videoplayer_info info
	
	if {![file exists $fn]} {return "0 0 0 -1"}
	
	catch {[exec $info(ffmpeg) -i [file normalize $fn]]} answer
	
	set search_fail 0
	
	if {![regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		set search_fail 1
	} else {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	}

	if {![regexp { ([0-9\.]+) fps,} $answer match fps]} {
		set search_fail 1
	}
	
	if {![regexp { ([1-9][0-9]+)x([1-9][0-9]+)} $answer match width height]} {
		set search_fail 1
	}

	if {$search_fail} {
		return "0 0 0 -1"
	}
	
	return "$width $height $fps $duration"
}

#
# Videoplayer_pickfile reads a video file and determines its width, height,
# framerate, and duration. If we pass an empty file name, or do not specify a
# file name, the routine uses the current video_file name. If we pass the
# keyword "browse" for the file name, the routine opens a browser for the user
# to select a new file. The routine sets the configuration array values for the
# four video parameters, so they may be used by other routines. It sets the
# current video file name as well. 
#
proc Videoplayer_pickfile {{fn ""}} {
	upvar #0 Videoplayer_config config
	upvar #0 Videoplayer_info info
	global LWDAQ_Info

	# Set the control variable.
	set info(control) "Read"
	LWDAQ_update
	
	# Check the file exists. If so, save as current video file. 
	if {$fn == "browse"} {
		set fn [LWDAQ_get_file_name 0 $config(video_file)]
		if {$fn == ""} {
			set info(control) "Idle"
			return ""
		}
	}

	# If empty string, use current video file name.
	if {$fn == ""} {
		set fn $config(video_file)
	}
	
	# Check the file exists.
	if {![file exists $fn]} {
		Videoplayer_print "ERROR: Cannot find file \"$fn\"."
		set info(control) "Idle"
		return ""
	}
	
	# Update the video file in case we chose a new valid file.
	set config(video_file) $fn
	
	# Get properties of video contained in the file.
	scan [Videoplayer_info $fn] %d%d%f%f width height fps duration
	
	# If the duration is less than zero, we have encountered an error, so we
	# report on that now, including printing a full ffmpeg output if the verbose
	# flag is set.
	if {$duration < 0} {
		Videoplayer_print "ERROR: Cannot decode \"$fn\",\
			check Verbose for details."
		set config(video_width) 820
		set config(video_height) 616
		set config(video_fps) 20
		set config(video_length_s) 0
		set config(video_length_f) 0
		if {$config(verbose)} {
			Videoplayer_print "\nOutput from FFMPEG follows:" purple
			catch {exec $info(ffmpeg) -i $fn} answer
			Videoplayer_print $answer green
			Videoplayer_print "End Output from FFMPEG.\n" purple
		}
	} else {
	# If duration is greater than or equal to zero, we decoded the file and we
	# can now set configuration parameters to match the file.
		set config(video_width) $width
		set config(video_height) $height
		set config(video_fps) [format %.2f $fps]
		set config(video_length_s) [format %.2f $duration]
		set config(video_length_f) [expr round($duration * $fps)]
		Videoplayer_print "[file tail $fn]:\
			width = $config(video_width),\
			height = $config(video_height),\
			fps = $config(video_fps) fps,\
			length_s = $config(video_length_s) s,\
			length_f = $config(video_length_f) f." verbose
	}	
	
	# Reset the start and end codes.
	set config(display_start_s) "0"
	set config(display_end_s) "*"
	set info(control) "Idle"
	return ""
}

#
# Video_png_extract extracts a PNG message from a stream buffer. We don't use 
# this routine in the Videoplayer, but we are leaving it here because it shows
# how to find the end of a PNG.
#
proc Videoplayer_png_extract {} {
	upvar stream_data s
	upvar stream_pointer i
	
	set png [string range $s $i [expr $i + 7]]
	set type "IHDR"
	set original_i $i
	set i [expr $i + 8]
	while {($type != "IEND") && ($i < [string length $s])} {
		binary scan [string range $s $i [expr $i+7]] Ia4 len type 
		append png [string range $s $i [expr $i + 12 + $len - 1]]
		set i [expr $i + 12 + $len]
	}
	if {$type != "IEND"} {
		set i $original_i
		set png ""
	}
	
	return $png
}

#
# Videoplayer_play plays the video file named in video_file, for which the
# routine assumes the values of width, height, framerate, and duration stored in
# the configuration array are correct. The routine uses the display scale value
# to obtain the display dimensions from the video width and height. It starts
# playing the video at time "display_start_s" in seconds, continuing to
# "display_end_s" seconds. If the end time is a wildcard character, it plays the
# entire video from the start time. If the end time is a "+" character, it grabs
# one frame and stops.
#
proc Videoplayer_play {} {
	upvar #0 Videoplayer_config config
	upvar #0 Videoplayer_info info
	
	# Startup checks.
	if {$info(control) != "Idle"} {
		Videoplayer_print "ERROR: Cannot start playback while busy."
		return ""
	}

	# Abbreviations.
	set fn $config(video_file)
	set start $config(display_start_s)
	set end_code $config(display_end_s)
	
	# Consistency checks.
	if {![file exists $fn]} {
		if {!$config(read_nocomplain)} {
			Videoplayer_print "ERROR: File \"$fn\" does not exist."
		}
		return ""
	}
	if {![string is double -strict $start]} {
		Videoplayer_print "ERROR: Invalid start time \"$start\"."
		return ""
	}
	if {$start > $config(video_length_s)} {
		set start $config(video_length_s)
		set end_code "+"
	}
	
	# Determine the end time in seconds, the number of frames we should read to 
	# complete the required duration, and construct the ffmpeg time control string.
	if {$end_code == "*"} {
		set end $config(video_length_s)
		set num_frames [expr round(($end - $start)*$config(video_fps))]
		set time_control "-ss $start"
	} elseif {$end_code == "+"} {
		set end [format %.3f $start [expr 2.0/$config(video_fps)]]
		set num_frames 1
		set time_control "-ss $start -t [format %.3f [expr 2.0/$config(video_fps)]]"
	} else {
		if {![string is double -strict $end_code]} {
			Videoplayer_print "ERROR: Invalid end time \"$end_code\"."
			return ""
		}
		set end $end_code
		set num_frames [expr round(($end_code - $start)*$config(video_fps))]
		set time_control "-ss $start -t [format %.3f [expr $end - $start]]"
	}
	
	# If the display scale is greater than one, we want to expand the image in
	# our own drawing routine, rather than asking ffmpeg to provide us with the
	# enlarged image. But if the scale is less than one, we will allow ffmeg to
	# provide the reduced image, which accelerates the display. Here we calculate
	# width we will specify to ffmpeg, and also the final display dimensions.
	if {$config(display_scale) >= 1.0} {
		set w $config(video_width)
		set h $config(video_height)
		set dw [expr round($config(display_scale) * $w)]
		set dh [expr round($config(display_scale) * $h)]
	} else {
		set w [expr round($config(display_scale) * $config(video_width))]
		set h [expr round($config(display_scale) * $config(video_height))]	
		set dw $w
		set dh $h
	}
	
	# Calculate the frame time.
	set frame_ms [format %.1f [expr 1000.0/$config(video_fps)/$config(display_speed)]]
	
	# Combine dimensions and rotation into one video filter.
	switch $config(video_rotation) {
		"0" {
			set vf "scale=$w\:$h"
		}
		"90" {
			set vf "scale=$w\:$h, transpose=clock"
			set temp $dw
			set dw $dh
			set dh $temp
			set temp $w
			set w $h
			set h $temp
		}
		"180" {
			set vf "scale=$w\:$h, transpose=clock, transpose=clock"
		}
		"270" {
			set vf "scale=$w\:$h, transpose=cclock"
			set temp $dw
			set dw $dh
			set dh $temp
			set temp $w
			set w $h
			set h $temp
		}
		default {
			set vf "scale=$w\:$h"
			Videoplayer_print "WARNING: Invalid rotation \"$config(video_rotation)\"."
		}
	}
	
	# Report on final display parameters.
	Videoplayer_print "Display width=$dw, height=$dh,\
		rotation=$config(video_rotation),\
		playing from $start s to $end s,\
		expect $num_frames frames,\
		$frame_ms ms per frame." verbose
	set info(control) "Play"
	LWDAQ_update

	# We compose our ffmpeg command, taking care to include literal double
	# quotes for the file name and video filter definition. Other options
	# we have worked with, but eliminated, we list below.
	# -frames:v $num_frames says we will read only this number of rames
	# -c:v rawvideo specifies raw video output, just pixels in a stream
	# -c:v png specifies png output
	# -pix_fmt gray specifies eight-bit gray scale, can use lwdaq_draw
	# -pix_fmt rgb24 specifies twenty-four bit color, the default
	# -pix_fmt rgb8 does nothing
	set cmd "| $info(ffmpeg) -nostdin \
		-loglevel error \
		$time_control \
		-i \"$fn\" \
		-c:v rawvideo \
		-pix_fmt $config(video_pix_fmt) \
		-vf \"$vf\" \
		-f image2pipe -"
		
	# Launch ffmpeg with a one-way pipe out of which we can read the raw video.
	# We have no access to the standard error channel from the ffmpeg process.
	# We will use a timout to detect errors, but otherwise the nature of an
	# ffmpeg failure will be unknown. 
	set ch [open $cmd r]
	set chpid [pid $ch]
	set info(display_channel) $ch
	set info(display_process) $chpid
	Videoplayer_print "Opened channel $ch to ffmpeg, process $chpid,\
		reading [file tail $fn]." verbose
	chan configure $ch -translation binary -blocking 0

	# Configure and initialize the display process.
	set info(frame_count) 0
	set start_time [clock milliseconds]
	set timeout 0
	if {$config(display_scale) >= 1.0} {
		set zoom $config(display_scale)
	} else {
		set zoom 1.0
	}
	set raw_size [expr round( $config(video_pix_size) * $w * $h)]
	set data_size 0
	set data ""
	
	# We now enter the display loop, in which we are grabbing frames, waiting until
	# the next frame display time, displaying the frame, and watching for a timeout.
	while {($info(frame_count) < $num_frames) && ($info(control) != "Stop")} {	
		append data [chan read $ch [expr $raw_size - $data_size]]
		set data_size [string length $data]
		if {$data_size >= $raw_size} {
			while {[clock milliseconds] < $start_time \
				+ 1.0*$info(frame_count)*$frame_ms} {
				LWDAQ_wait_ms 1
			}
			incr info(frame_count)
			set timeout 0
			lwdaq_draw_raw $data $info(display_photo) -width $w -height $h \
				-pix_fmt $config(video_pix_fmt) -zoom $zoom
			set data ""
			LWDAQ_update
		}
		LWDAQ_wait_ms 1
		incr timeout
		LWDAQ_support
		if {$timeout > $config(file_timeout_ms)} {
			Videoplayer_print "ERROR: Timeout trying to read \"$fn\"." 
			break
		}
		if {($info(frame_count) > 0) && ($timeout > $frame_ms)} {
			break
		}
	}
	
	# Close the ffmpeg channel and make sure the ffmpeg process is stopped.
	catch {close $ch}
	LWDAQ_process_stop $chpid
	Videoplayer_print "Video playback complete, closed channel $ch,\
		stopped process $chpid." verbose
	
	# Report on outcome of playback if verbose flag is set.
	set video_s [format %.2f [expr 1.0*$info(frame_count)/$config(video_fps)]]
	set display_s [format %.2f [expr 0.001*([clock milliseconds] - $start_time)]]
	set config(display_start_s) [format %.2f [expr $start + $video_s]]
	set config(display_end_s) $end_code
	Videoplayer_print "Read $info(frame_count) frames\
		spanning $video_s s, displayed in $display_s s." verbose
	set info(control) "Idle"
	return ""
}

#
# Videoplayer_stream connects to a video stream server, which we specify with an
# IP address and port number like "tcp://192.168.1.31:2222". The routine uses
# the video_stream value and assumes the other video and display values in the
# configuration array are to be applied to the streaming. The routine calls
# ffmpeg to connect to the server and receive the stream. We do not give ffmpeg
# any advice as to the format or encoding of the stream, but instead leave
# ffmpeg to figure these details out for itself. The ffmpeg process translates
# the stream into raw video with dimensions and pixel format we specify. The
# width and height are obtained from the product of display_scale and
# video_width and video_height respectively. That is: the routine is assuming
# the stream has dimensions video_width x video_height, and asks ffmpeg to scale
# the stream by display_scale. The pixel format specified by video_pix_fmt,
# which must must be accompanied by a matching value of video_pix_size. We read
# the raw video produced by ffmpeg and display it on the screen. If ffmpeg fails
# to connect to the stream, or if the connection is subsequently broken or
# corrupted, we break out of the streaming loop with a timeout after
# tcp_timeout_ms. 
#
proc Videoplayer_stream {} {
	upvar #0 Videoplayer_config config
	upvar #0 Videoplayer_info info

	# Startup checks.
	if {$info(control) != "Idle"} {
		Videoplayer_print "ERROR: Cannot start streaming while busy."
		return ""
	}

	# Abbreviations.
	set stream $config(video_stream)
	
	# Determine the dimensions of the display.
	if {$config(display_scale) >= 1.0} {
		set w $config(video_width)
		set h $config(video_height)
		set dw [expr round($config(display_scale) * $w)]
		set dh [expr round($config(display_scale) * $h)]
	} else {
		set w [expr round($config(display_scale) * $config(video_width))]
		set h [expr round($config(display_scale) * $config(video_height))]	
		set dw $w
		set dh $h
	}

	# Combine dimensions and rotation into one video filter.
	switch $config(video_rotation) {
		"0" {
			set vf "scale=$w\:$h"
		}
		"90" {
			set vf "scale=$w\:$h, transpose=clock"
			set temp $dw
			set dw $dh
			set dh $temp
			set temp $w
			set w $h
			set h $temp
		}
		"180" {
			set vf "scale=$w\:$h, transpose=clock, transpose=clock"
		}
		"270" {
			set vf "scale=$w\:$h, transpose=cclock"
			set temp $dw
			set dw $dh
			set dh $temp
			set temp $w
			set w $h
			set h $temp
		}
		default {
			set vf "scale=$w\:$h"
			Videoplayer_print "WARNING: Invalid rotation \"$config(video_rotation)\"."
		}
	}

	# Report on final display parameters.
	Videoplayer_print "Display width=$w, height=$h,\
		rotation=$config(video_rotation),\
		stream server $stream." verbose
	set info(control) "Stream"
	LWDAQ_update

	# Define the ffmpeg command.
	set cmd "| $info(ffmpeg) \
		-nostdin \
		-loglevel error \
		-i $stream \
		-c:v rawvideo \
		-pix_fmt $config(video_pix_fmt) \
		-vf \"$vf\" \
		-f image2pipe -"

	# Open the channel to ffmpeg and start streaming.
	set ch [open $cmd r+]
	set chpid [pid $ch]
	set info(display_channel) $ch
	set info(display_process) $chpid
	Videoplayer_print "Opened channel $ch to ffmpeg, process $chpid,\
		connecting to $stream." verbose
	chan configure $ch -translation binary -blocking 0

	# Set monitor variables.
	set info(frame_count) 0
	set start_time [clock milliseconds]
	set timeout 0
	if {$config(display_scale) >= 1.0} {
		set zoom $config(display_scale)
	} else {
		set zoom 1.0
	}
	set raw_size [expr round( $config(video_pix_size) * $w * $h)]
	set data_size 0
	
	# Read the frames as they come in, watch for a timeout.
	while {$info(control) != "Stop"} {	
		append data [chan read $ch [expr $raw_size - $data_size]]
		set data_size [string length $data]
		if {$data_size >= $raw_size} {
			lwdaq_draw_raw $data $info(display_photo) \
				-width $w -height $h -pix_fmt rgb24 -zoom $zoom
			incr info(frame_count)
			set timeout 0
			set data ""
			LWDAQ_update
		}
		LWDAQ_wait_ms 1
		LWDAQ_support
		incr timeout
		if {$timeout > $config(tcp_timeout_ms)} {
			Videoplayer_print "ERROR: Streaming failure,\
				timeout waiting for frame $info(frame_count)."
			break
		}
	}
	
	# Close the channel and make sure the ffmpeg process is killed.
	catch {close $ch}
	LWDAQ_process_stop $chpid
	
	# Report on outcome of the streaming if the verbose flag is set.
	Videoplayer_print "Video streaming halted, closed channel $ch,\
		stopped process $chpid." verbose
	set video_s [format %.2f [expr 1.0*$info(frame_count)/$config(video_fps)]]
	set display_s [format %.2f [expr 0.001*([clock milliseconds] - $start_time)]]
	Videoplayer_print "Received $info(frame_count) frames\
		spanning $video_s s, displayed in $display_s s." verbose
	set info(control) "Idle"
	return ""
}

#
# Videoplayer_stop sets the Videoplayer control flag to Stop. Continuous
# Videoplayer processes should check the control flag and abort when they see
# Stop, then set the flag to Idle.
#
proc Videoplayer_stop {} {
	upvar #0 Videoplayer_config config
	upvar #0 Videoplayer_info info

	if {$info(control) == "Idle"} {return ""}
	set info(control) "Stop"
	return ""
}

#
# Videoplayer_setup allows us to set Videoplayer configuration parameters by 
# name by prefixing them with a dash and then giving their value.
#
proc Videoplayer_setup {args} {
	upvar #0 Videoplayer_config config
	upvar #0 Videoplayer_info info
	
	foreach {option value} $args {
		switch $option {
			"-file" {
				set config(video_file) $value
			}
			"-stream" {
				set config(video_stream) $value
			}
			"-width" {
				set config(video_width) $value
			}
			"-height" {
				set config(video_height) $value
			}
			"-rotation" {
				set config(video_rotation) $value
			}
			"-fps" {
				set config(video_fps) $value
			}
			"-framerate" {
				set config(video_fps) $value
			}
			"-length_s" {
				set config(video_duration) $value
			}
			"-duration" {
				set config(video_duration) $value
			}
			"-scale" {
				set config(display_scale) $value
			}
			"-speed" {
				set config(display_speed) $value
			}
			"-start" {
				set config(display_start_s) $value
			}
			"-end" {
				set config(display_end_s) $value
			}
			"-tcp_timeout_ms" {
				set config(display_tcp_timeout_ms) $value
			}
			"-title" {
				switch $info(mode) {
					"Standalone" {wm title . $value} 
					"Slave" {wm title . $value} 
					default {wm title $info(window) $value}
				}
			}
			"-nocomplain" {
				set config(read_nocomplain) 1
			}
			default {
				Videoplayer_print "ERROR: Unknown option \"$option\"."
			}
		}
	}
	return ""
}

#
# videoplayer is a command-line procedure for use when the Videoplayer is
# operating as a slave. It takes one instruction followed by arguments that will
# be passed to Videoplayer_setup. The arguments are of the form "-option value".
# The "play", "stream", and "pickfile" tasks are posted to the event queue, to
# be executed in turn, so that we can queue Videoplayer actions to generate
# seemless display. The other tasks execute immediately. They can return
# information or they can return an empty string. The "status" instruction
# returns a bunch of information about the videoplayer and its tasks to the text
# window or to standard out, in units of seconds.
#
proc videoplayer {instruction args} {
	upvar #0 Videoplayer_config config
	upvar #0 Videoplayer_info info
	global LWDAQ_Info

	switch $instruction {
		"stop" {
			Videoplayer_stop
		}
		"play" {
			LWDAQ_post "Videoplayer_setup $args"
			LWDAQ_post "Videoplayer_play"
		}
		"stream" {
			LWDAQ_post "Videoplayer_setup $args"
			LWDAQ_post "Videoplayer_stream"
		}
		"pickfile" {
			LWDAQ_post "Videoplayer_setup $args"
			LWDAQ_post "Videoplayer_pickfile"
		}
		"setup" {
			eval "Videoplayer_setup $args"
		}
		"status" {
			set busy "no"
			if {[llength $LWDAQ_Info(queue_events) ] > 0} {
				set busy "yes"
			}
			if {$LWDAQ_Info(current_event) != "Idle"} {
				set busy "yes"
			}
			if {$info(control) != "Idle"} {
				set busy "yes"
			}
			set play_time_s [format %.2f \
				[expr $config(display_start_s) \
				+ 1.0*$info(frame_count)/$config(video_fps)]]
			return "busy=$busy\
				control=$info(control)\
				play_time_s=$play_time_s\
				frame_count=$info(frame_count)"
		}
		default {
			Videoplayer_print "ERROR: Unrecognised instruction \"$instruction\".
		}
	}
	return ""
}

#
# Videoplayer_open creates the Videoplayer window, with all its buttons, boxes,
# and displays. 
#
proc Videoplayer_open {} {
	upvar #0 Videoplayer_config config
	upvar #0 Videoplayer_info info
	global LWDAQ_Info

	# Open the tool window. If we get an empty string back from the opening
	# routine, something has gone wrong, or a window already exists for this
	# tool, so we abort.
	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
	
	# Get on with creating the video display.
	set f $w.display
	frame $f -relief flat -bd 0
	pack $f -side top -fill x
	
	# Make the image where we will display video.
	image create photo $info(display_photo) \
		-width $info(init_size) -height $info(init_size) 
	label $f.display -image $info(display_photo)
	pack $f.display -side top

	# If we are running in slave or standalone mode, we make sure that we send
	# an exit command when someone closes the main window
	if {($info(mode) == "Slave") || ($info(mode) == "Standalone")} {
		wm protocol . WM_DELETE_WINDOW {
			LWDAQ_reset
			Videoplayer_stop
			LWDAQ_post exit			
		}
	}	
		
	# If we are running in slave mode, don't open any other widgets in the 
	# user interface.
	if {$info(mode) == "Slave"} {
		return $w
	}	
	
	set f $w.controls
	frame $f -relief groove -bd 2
	pack $f -side top -fill x
	
	label $f.ctrl -textvariable Videoplayer_info(control) -fg blue -width 8
	set info(play_control_label) $f.ctrl
	pack $f.ctrl -side left -expand yes

	button $f.play -text "Play" -command {LWDAQ_post Videoplayer_play}
	pack $f.play -side left -expand yes

	button $f.stream -text "Stream" -command {LWDAQ_post Videoplayer_stream}
	pack $f.stream -side left -expand yes

	button $f.stop -text "Stop" -command {Videoplayer_stop}
	pack $f.stop -side left -expand yes

	button $f.config -text "Configure" -command "Videoplayer_configure"
	pack $f.config -side left -expand yes
	
	button $f.help -text "Help" -command "LWDAQ_tool_help Videoplayer"
	pack $f.help -side left -expand yes
	
	checkbutton $f.verbose -text "Verbose" -variable Videoplayer_config(verbose)
	pack $f.verbose -side left -expand yes

	set f $w.parameters
	frame $f -relief groove -bd 2
	pack $f -side top -fill x
	
	foreach a {width height rotation fps length_s length_f} {
		label $f.l$a -text "$a"
		entry $f.e$a -textvariable Videoplayer_config(video_$a) -width 6
		pack $f.l$a $f.e$a -side left -expand yes
	}

	foreach a {start_s end_s speed scale} {
		label $f.l$a -text "$a"
		entry $f.e$a -textvariable Videoplayer_config(display_$a) -width 5
		pack $f.l$a $f.e$a -side left -expand yes
	}

	set f $w.vf
	frame $f -relief groove -bd 1
	pack $f -side top -fill x
	
	label $f.lfn -text "File:"
	entry $f.efn -textvariable Videoplayer_config(video_file) -width 60
	button $f.pick -text "PickFile" -command {
		LWDAQ_post "Videoplayer_pickfile browse"
	}
	pack $f.lfn $f.efn $f.pick -side left -expand yes
	label $f.lvs -text "Stream:"
	entry $f.evs -textvariable Videoplayer_config(video_stream) -width 20
	pack $f.lvs $f.evs -side left -expand yes

	set info(text) [LWDAQ_text_widget $w 100 10 1 1]
	
	LWDAQ_print $info(text) "WARNING: This tool is in active development, 09-MAR-23."
	
	return $w
}

#
# Videoplayer_close closes the Videoplayer and deletes its configuration and
# info arrays.
#
proc Videoplayer_close {} {
	upvar #0 Videoplayer_config config
	upvar #0 Videoplayer_info info
	global LWDAQ_Info
	if {$info(gui) && [winfo exists $info(window)]} {
		destroy $info(window)
	}
	array unset config
	array unset info
	return ""
}

Videoplayer_init 
Videoplayer_open
	
return ""

----------Begin Help----------

http://www.opensourceinstruments.com/ACC/Videoplayer.html

----------End Help----------
