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
	set info(video_file_cache) [list]
#
# Video stream sources.
#
	set config(video_stream) "tcp://192.168.1.31:2222"
#
# Video file properties.
#
	set config(video_file_time) "0"
	set config(video_fps) "20"
	set config(video_width) "820"
	set config(video_height) "616"
	set config(video_length_s) "1"
	set config(video_length_f) "1"
#
# Display properties.
#
	set config(display_start_s) "0"
	set config(display_end_s) "*"
	set config(display_speed) "1.0"
	set config(display_scale) "0.5"
	set config(display_time) "0.00"
	set info(display_photo) "videoplayer_photo"
	set info(frame_count) "0"
	set info(display_process) "0"
	set info(display_channel) "none"
	set config(display_timeout_ms) "1000"
	set config(stream_timeout_ms) "5000"
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
		set info(ssh) [file join $os_dir ssh/ssh.exe]	
		set info(ffmpeg) [file join $os_dir ffmpeg/bin/ffmpeg.exe]
	} elseif {$LWDAQ_Info(os) == "MacOS"} {
		set info(ssh) "/usr/bin/ssh"
		set info(ffmpeg) [file join $os_dir ffmpeg]
	} elseif {$LWDAQ_Info(os) == "Linux"} {
		set info(ssh) "/usr/bin/ssh"
		set info(ffmpeg) [file join $os_dir ffmpeg/ffmpeg]
	} elseif {$LWDAQ_Info(os) == "Raspbian"} {
		set info(ssh) "/usr/bin/ssh"
		set info(ffmpeg) "/usr/bin/ffmpeg"
	} else {
		Videoplayer_print "WARNING: Video playback may not work on $LWDAQ_Info(os)."
		set info(ssh) "/usr/bin/ssh"
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
# the user download the Videoarchiver directory to install ffmpeg and mplayer.
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
Videoarchiver directories will be next to one another. You now have Mplayer, and
FFMpeg installed for use by the Videoarchiver and Videoplayer on Linux, MacOS,
and Windows.
	}
}

#
# Videoplayer_clock_convert converts between integer seconds and the datetime
# format given in the configuration array. If the input is in integer seconds,
# it gets converted into our datetime format. If the input is in the datetime
# format, it gets converted into integer seconds. If the format is incorrect,
# we return the value zero.
#
proc Videoplayer_clock_convert {datetime} {
	upvar #0 Videoplayer_config config
	upvar #0 Videoplayer_info info
	
	if {[string is integer $datetime]} {
		set newformat [clock format $datetime -format $info(datetime_format)]
	} {
		if {[catch {
			set newformat [clock scan $datetime -format $info(datetime_format)]
		} error_result]} {
			set newformat 0
			Videoplayer_print "ERROR: Invalid time \"$datetime\",\
				should be $info(datetime_error)."
		}
	}
	return $newformat
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
	
	if {$config(verbose) \
		|| [regexp "^WARNING: " $line] \
		|| [regexp "^ERROR: " $line] \
		|| ($color != "verbose")} {
		if {$color == "verbose"} {
			if {!$config(slave)} {
				LWDAQ_print $info(text) $line black
			}
		} else {
			if {!$config(slave)} {
				LWDAQ_print $info(text) $line $color
			} else {
				puts $line
			}
		}
	}
	return ""
}

#
# Videoplayer_info calls ffmpeg to determine the width, height, frame rate
# and duration of an existing video file. The frame rate is frames per second.
# The duration is in seconds. If the file does not exist, the routine returns "0
# 0 0 -1".
#
proc Videoplayer_info {{fn ""}} {
	upvar #0 Videoplayer_config config
	upvar #0 Videoplayer_info info
	
	if {$fn == ""} {
		set fn $info(video_file)
		if {![file exists $fn]} {return "0 0 0 -1"}
	}
	
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
# Videoplayer_pickvid attempts to read a video file and determine its width,
# height, frame rate, and duration. If we pass an empty file name, or do not
# specify a file name, the routine will open a browser for the user to select a
# file. The routine sets the configuration array values for the four video
# parameters, so they may be used by other routines. If we set "post" to one,
# the routine will post itself to the event queue so that it is executed in 
# order.
#
proc Videoplayer_pickvid {{fn ""} {post 0}} {
	upvar #0 Videoplayer_config config
	upvar #0 Videoplayer_info info
	global LWDAQ_Info

	if {$post} {
		LWDAQ_post [list Videoplayer_pickvid $fn 0]
		return ""
	}

	set info(control) "Read"
	LWDAQ_update

	if {$fn == ""} {set fn [LWDAQ_get_file_name 0 $config(video_dir)]}
	if {![file exists $fn]} {
		Videoplayer_print "ERROR: Cannot find \"$fn\"."
		set info(control) "Idle"
		return ""
	}
	set config(video_file) $fn
	if {![regexp {V([0-9]{10})\.mp4} [file tail $fn] match config(video_file_time)]} {
		set config(video_file_time) 0
		Videoplayer_print "Cannot deduce start time of \"[file tail $fn]\"." verbose
	}
	scan [Videoplayer_info $fn] %d%d%f%f width height fps duration
	if {$duration < 0} {
		Videoplayer_print "ERROR: Cannot understand \"$fn\"."
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
		set info(control) "Idle"
		return ""
	} else {
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
		set info(control) "Idle"
		return $fn
	}	
}

#
# Videoplayer_pickdir allows the user to pick a new video directory. The 
# Videoplayer then picks the first video in that directory for its video file.
#
proc Videoplayer_pickdir {} {
	upvar #0 Videoplayer_config config
	upvar #0 Videoplayer_info info
	global LWDAQ_Info

	set dn [LWDAQ_get_dir_name [set config(video_dir)]]
	if {![file exists $dn]} {
		Videoplayer_print "WARNING: Directory \"$dn\" does not exist."
		return $dn
	}
	if {$dn != $config(video_dir)} {
		set info(video_file_cache) [list]
	}
	set config(video_dir) $dn
	
	Videoplayer_print "Directory: $dn\."
	cd $dn
	set vfl [glob -nocomplain V*.mp4]
	Videoplayer_print "Video directory contains [llength $vfl] files matching V*.mp4."

	return $dn
}

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

proc Videoplayer_raw_extract {} {
	upvar #0 Videoplayer_config config
	upvar #0 Videoplayer_info info
	upvar stream_data s
	upvar stream_pointer i
	
	set raw_size [expr round(3*$config(video_width)*$config(video_height)\
		*$config(display_scale)*$config(display_scale))]
	if {[string length $s] >= $i + $raw_size - 1} {
		set raw [string range $s $i [expr $i + $raw_size - 1]]
		set i [expr $i + $raw_size]
	} else {
		set raw ""
	}
	
	return $raw
}

#
# Videoplayer_play plays the current video file, which must previously have been
# read and understood by Videoplayer_pickvid. The routine starts playing the
# video at time "start" in seconds, continuing to "end" seconds. If the end time
# is a wildcard character, we play the entire video from the start time. If the
# end time is a "+" character, we grab one frame and stop. If "post" is one, we
# post the Videoplayer_play command to the event queue so it will be executed in
# turn, without delay, following other video actions.
#
proc Videoplayer_play {start end_code {post 0}} {
	upvar #0 Videoplayer_config config
	upvar #0 Videoplayer_info info
	
	if {$post} {
		LWDAQ_post [list Videoplayer_play $fn $start $end_code]
		return ""
	}
	
	if {$info(control) != "Idle"} {
		Videoplayer_print "ERROR: Cannot play a new file while busy."
		return ""
	}
	
	set fn $config(video_file)

	if {![file exists $fn]} {
		Videoplayer_print "ERROR: File \"$fn\" does not exist."
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
	if {$end_code == "*"} {
		set end $config(video_length_s)
		set time_control "-ss $start"
		set num_frames [expr round(($end - $start)*$config(video_fps))]
	} elseif {$end_code == "+"} {
		set end [format %.3f $start [expr 2.0/$config(video_fps)]]
		set time_control "-ss $start -t [format %.3f [expr 2.0/$config(video_fps)]]"
		set num_frames 1
	} else {
		if {![string is double -strict $end_code]} {
			Videoplayer_print "ERROR: Invalid end time \"$end_code\"."
			return ""
		}
		set end $end_code
		set time_control "-ss $start -t [format %.3f [expr $end - $start]]"
		set num_frames [expr round(($end_code - $start)*$config(video_fps))]
	}
	set w [expr round($config(display_scale) * $config(video_width))]
	set h [expr round($config(display_scale) * $config(video_height))]
	set frame_ms [format %.1f [expr 1000.0/$config(video_fps)/$config(display_speed)]]

	Videoplayer_print "Display width=$w, height=$h,\
		playing from $start s to $end s,\
		expect $num_frames frames,\
		$frame_ms ms per frame." verbose
	set info(control) "Play"
	LWDAQ_update

	set cmd "| $info(ffmpeg) -nostdin \
		-loglevel error \
		$time_control \
		-i \"$fn\" \
		-c:v rawvideo \
		-pix_fmt rgb24 \
		-vf \"scale=$w\:$h\" \
		-f image2pipe -"
		
# Other ffmpeg options we have worked with:
# -frames:v $num_frames says we will read only this number of frames
# -c:v rawvideo specifies raw video output, just pixels in a stream
# -c:v png specifies png output
# -pix_fmt gray specifies eight-bit gray scale, can use lwdaq_draw
# -pix_fmt rgb24 specifies twenty-four bit color, the default
# -pix_fmt rgb8 does nothing
	
	set ch [open $cmd r+]
	set chpid [pid $ch]
	set info(display_channel) $ch
	set info(display_process) $chpid
	Videoplayer_print "Opened channel $ch to ffmpeg, reading [file tail $fn]." verbose
	chan configure $ch -translation binary -blocking 0

	set stream_pointer 0
	set stream_data ""
	set info(frame_count) 0
	set start_time [clock milliseconds]
	set timeout 0

	while {($info(frame_count) < $num_frames) && ($info(control) != "Stop")} {	
		append stream_data [chan read $ch]
		set data [Videoplayer_raw_extract]
		if {$data != ""} {
			while {[clock milliseconds] < $start_time \
				+ 1.0*$info(frame_count)*$frame_ms} {
				LWDAQ_wait_ms 1
			}
			incr info(frame_count)
			set timeout 0
			lwdaq_draw_raw $data $info(display_photo) \
				-width $w -height $h -pix_fmt rgb24
			LWDAQ_update
		}
		LWDAQ_wait_ms 1
		incr timeout
		LWDAQ_support
		if {$timeout > $config(display_timeout_ms)} {
			Videoplayer_print "ERROR: Timeout waiting for frame $info(frame_count),\
				waited over $config(display_timeout_ms) ms."
			break
		}
	}
	
	catch {close $ch}
	Videoplayer_print "Done with video, closed channel $ch." verbose
	
	set video_s [format %.2f [expr 1.0*$info(frame_count)/$config(video_fps)]]
	set display_s [format %.2f [expr 0.001*([clock milliseconds] - $start_time)]]
	set config(display_start_s) [format %.2f [expr $start + $video_s]]
	set config(display_end_s) $end_code
	Videoplayer_print "Read $info(frame_count) frames\
		spanning $video_s s, displayed in $display_s s." verbose
	set info(control) "Idle"
	return ""
}

proc Videoplayer_stream {{post "0"}} {
	upvar #0 Videoplayer_config config
	upvar #0 Videoplayer_info info

	if {$post} {
		LWDAQ_post [list Videoplayer_stream 0]
		return ""
	}
	
	set w [expr round($config(display_scale) * $config(video_width))]
	set h [expr round($config(display_scale) * $config(video_height))]
	set stream $config(video_stream)
	Videoplayer_print "Display width=$w, height=$h,\
		streaming from $stream\
		at $config(video_fps)." verbose
	set info(control) "Stream"
	LWDAQ_update

	set cmd "| $info(ffmpeg) \
			-nostdin \
			-loglevel error \
			-i $stream \
			-c:v rawvideo \
			-pix_fmt rgb24 \
			-vf \"scale=$w\:$h\" \
			-f image2pipe -"

	set ch [open $cmd r+]
	set chpid [pid $ch]
	set info(display_channel) $ch
	set info(display_process) $chpid
	Videoplayer_print "Opened channel $ch to ffmpeg, reading $stream." verbose
	chan configure $ch -translation binary -blocking 0

	set stream_pointer 0
	set stream_data ""
	set info(frame_count) 0
	set start_time [clock milliseconds]
	set timeout 0
	
	while {$info(control) != "Stop"} {	
		append stream_data [chan read $ch]
		set data [Videoplayer_raw_extract]
		if {$data != ""} {
			incr info(frame_count)
			lwdaq_draw_raw $data $info(display_photo) \
				-width $w -height $h -pix_fmt rgb24
			LWDAQ_update
		}
		LWDAQ_wait_ms 1
		incr timeout
		LWDAQ_support
		if {$timeout > $config(stream_timeout_ms)} {
			Videoplayer_print "ERROR: Timeout waiting for frame $info(frame_count),\
				waited over $config(stream_timeout_ms) ms."
			break
		}
	}
	
	close $ch
	Videoplayer_print "Done with video, closed channel $ch." verbose
	
	set video_s [format %.2f [expr 1.0*$info(frame_count)/$config(video_fps)]]
	set display_s [format %.2f [expr 0.001*([clock milliseconds] - $start_time)]]
	Videoplayer_print "Received $info(frame_count) frames\
		spanning $video_s s, displayed in $display_s s." verbose
	set info(control) "Idle"
	return ""
}

proc Videoplayer_stop {} {
	upvar #0 Videoplayer_config config
	upvar #0 Videoplayer_info info

	if {$info(control) == "Idle"} {return ""}
	set info(control) "Stop"
	return ""
}

#
# Videoplayer_seek looks for an entire video interval within a single
# video file in the video directory. The routine returns the name of the video
# file containing the entire interval (vf), the video time at which the interval
# begins (vseek), the length of video in the file (vlen), and the length of
# video we expect the file to contain given the timestamp in the name of the
# next file in the video directory (clen). If further returns the width, height
# and framerate of the video. When choosing the video time, the routine assumes
# that the start of the video always corresponds to the absolute time specified
# in the video file name. The routine uses a cache of recently-used video
# files to save time when searching for the correct file, because the search
# requires that we get the length of the video calculated by ffmpeg, and this
# calculation is time-consuming. If the video is not in the cache, we use the
# video directory as a source of video files.
# 
proc Videoplayer_seek {datetime length} {
	upvar #0 Videoplayer_config config
	upvar #0 Videoplayer_info info
	
	# Check to see if ffmpeg and mplayer are available. If not, we suggest
	# downloading the Videoarchiver package and go to idle state.
	if {![file exists $info(ffmpeg)] || ![file exists $info(mplayer)]} {
		return "none 0 0 0 0 0 0"
	}

	# Look in our video file cache to see if the start and end of the 
	# requested interval is contained in a video we have already read
	# from the video directory and assessed previously.
	set vf ""
	foreach entry $info(video_file_cache) {
		scan $entry %s%d%f%f%d%d%f fn vtime vlen clen width height fps
		if {($vtime <= $datetime) && ($vtime + $clen >= $datetime + $length)} {
			set vf $fn
			break
		}
	}

	if {$vf != ""} {
		Videoplayer_print "Using cached video file $vf." verbose
	}
	
	# If we have not found a file that includes the start of the requested
	# interval, look for one in the file system.
	if {$vf == ""} {
	
		# Make a list of video files in the camera directory and sort them
		# in chronological order.
		set fl [LWDAQ_find_files $config(video_dir) V??????????.mp4]
		set fl [LWDAQ_sort_files $fl]
	
		# Find the newest file that begins before or at the start of our
		# interval. Determine the start time of the next file in the list.
		set vtime 0
		set ntime 0
		foreach fn $fl {
			if {[regexp {([0-9]{10})\.mp4$} [file tail $fn] match newtime]} {
				if {($newtime <= $datetime)} {
					set vf $fn
					set vtime $newtime
				} else {
					set ntime $newtime
					break
				}
			}
		}
		
		# If we still have no file return null values.
		if {$vf == ""} {
			return "none 0 0 0 0 0 0"
		}

		# Calculate the actual video file length.
		set vfi [Videoplayer_info $vf]
		scan $vfi %d%d%f%f width height fps vlen

		# Calculate the length of time between the start of this video file and
		# the start of the next video file, if one exists. We call this length
		# the "correct length" of the video. If there is no subsequent file, set
		# set the correct length equal to the duration, rounded to the nearest
		# second.
		if {$ntime > 0} {
			set clen [expr round($ntime - $vtime)]
		} {
			set clen [expr round($vlen)]
		}
		
		# Add the video to our cache.
		lappend info(video_file_cache) "$vf $vtime $vlen $clen $width $height $fps"
		if {[llength $info(video_file_cache)] > $info(max_files)} {
			set info(video_file_cache) [lrange $info(video_file_cache) 10 end]
		}
		Videoplayer_print "Added $vf to video cache." verbose
		
		# Check that the video file's correct length includes the interval start. If 
		# not, we return a null result.
		if {$vtime + $clen - $datetime < 0} {return "none 0 0 0 0 0 0"}
	}

	# We calculate the time within the video recording that corresponds to the 
	# sought-after moment in the signal recording. 
	set vseek [expr $datetime - $vtime]
	if {$vseek < 0.0} {set vseek 0.0}
	
	# Return the file name, seek position, and file length.
	return "$vf $vseek $vlen $clen $width $height $fps"
}

#
# Videoplayer_seek_play first seeks for the interval in one of the video files
# in the video directory tree. When it finds the interval it displays plays the
# interval. We specify the absolute time as a whole number of Unix seconds. We
# specify the length of the interval in seconds. 
#
proc Videoplayer_seek_play {datetime length} {
	upvar #0 Videoplayer_config config
	upvar #0 Videoplayer_info info
	
	# Check to see if ffmpeg and mplayer are available. If not, we suggest
	# downloading the Videoarchiver package and go to idle state.
	if {![file exists $info(ffmpeg)] || ![file exists $info(mplayer)]} {
		Videoplayer_suggest
		set info(video_state) "Idle"
		return ""
	}

	# Seek the interval in the video directory.
	set result [Videoplayer_seek $datetime $length]

	# Extract the file name, seek time, length of the video existing in the
	# file and the correct length of the file, which is the length of video that
	# fills the time between the start of this file and the next file in the
	# recording directory, if it exists.
	scan $result %s%f%f%f%d%d%f vf vseek vlen clen width height fps
	
	# If we have no file containing the interval start, give up.
	if {$vf == "none"} {
		Videoplayer_print "ERROR: No video file contains interval start."
		set info(video_state) "Idle"
		return ""
	}
	
	# If the end of the interval does not lie within the file, issue a warning.
	set missing [expr $vseek + $length - $clen]
	if {$missing > 0} {
		Videoplayer_print "WARNING: Video file missing last $missing s\
			of interval."
	}
		
	# If no video player window is open, we create a new one. If we
	# are loading a new video file, destroy the old process and create
	# a new one. This avoids problems we don't understand developing in
	# the Mplayer process.
	set new_process 0
	if {![LWDAQ_process_exists $info(video_process)] \
		|| [catch {puts $info(video_channel) ""}] \
		|| ([file tail $vf] != [file tail $info(video_file)])} {
		
		# Make sure the old video process is destroyed.
		LWDAQ_process_stop $info(video_process)
		catch {close $info(video_channel)}
		
		# Create MPlayer window with channel to write in commands and
		# read back answers. For a camera identifier, we are going to 
		# use the video directory tail.
		set camera_id [file tail $config(video_dir)]
		if {[winfo parent $info(window)] == ""} {
			set title "Camera $camera_id in [wm title .]"
		} {
			set title "Camera $camera_id in [wm title [winfo parent $info(window)]]"
		}
		set info(video_channel) [open "| $info(mplayer) \
			-title \"$title\" \
			-geometry 10%:10% -slave -idle -quiet -fixed-vo \
			-zoom -xy $config(video_zoom)" w+]
		fconfigure $info(video_channel) -buffering line -translation auto -blocking 0
		set info(video_process) [pid $info(video_channel)]
		
		# Set the video file, delete the video log if it exists.
		set info(video_file) $vf
		catch {file delete $info(video_log)}
		
		# Load the video file without starting playback. We don't want to start at
		# the beginning if we are seeking a later time in the file.
		puts $info(video_channel) "pausing loadfile \"$vf\" 0"
		
		# Disable the progress bar and other Mplayer overlays.
		puts $info(video_channel) "pausing osd 0"

		# Start up the watchdog for this MPlayer process.
		LWDAQ_post [list Videoplayer_watchdog $info(video_process)]
	}

	# Set the end time of the video and the stop time. The stop time is one
	# half-frame before the end time, so we don't play the first frame of the
	# next interval.
	set info(video_end_time) [format %.3f $vlen]
	set info(video_stop_time) [format %.3f \
		[expr $vseek + $length - 1.0/$fps]]
	if {$info(video_stop_time) > $info(video_end_time)} {
		set info(video_stop_time) $info(video_end_time)
	}

	# Set the playback speed and seek the interval start.
	puts $info(video_channel) "pausing speed_set $config(video_speed)"
	puts $info(video_channel) "seek $vseek 2"
	
	# Set the video state to play and report the seek time.
	Videoplayer_print "Playing $vf for $length s\
		starting at $vseek s of $vlen s." verbose
	LWDAQ_set_bg $info(control_label) cyan
	set info(video_state) "Play"
	
	# Return the file name, seek time, file duration, and correct length.
	return [list $vf $vseek $vlen $clen]
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
	frame $f -relief groove -border 2
	pack $f -side top -fill x
	
	image create photo $info(display_photo) -width 600 -height 200
	label $f.display -image $info(display_photo)
	pack $f.display -side top

	set f $w.controls
	frame $f -relief groove -border 2
	pack $f -side top -fill x
	
	label $f.ctrl -textvariable Videoplayer_info(control) -fg blue -width 8
	set info(play_control_label) $f.ctrl
	pack $f.ctrl -side left -expand yes

	button $f.play -text "Play" -command {
		Videoplayer_play $Videoplayer_config(display_start_s) \
			$Videoplayer_config(display_end_s)
	}
	pack $f.play -side left -expand yes

	button $f.stream -text "Stream" -command {Videoplayer_stream}
	pack $f.stream -side left -expand yes

	button $f.stop -text "Stop" -command {
		Videoplayer_stop
	}
	pack $f.stop -side left -expand yes

	foreach a {PickVid PickDir} {
		set b [string tolower $a]
		button $f.$b -text "$a" -command "LWDAQ_post Videoplayer_$b"
		pack $f.$b -side left -expand yes
	}

	button $f.config -text "Configure" -command "Videoplayer_configure"
	pack $f.config -side left -expand yes
	
	button $f.help -text "Help" -command "LWDAQ_tool_help Videoplayer"
	pack $f.help -side left -expand yes
	
	checkbutton $f.verbose -text "Verbose" -variable Videoplayer_config(verbose)
	pack $f.verbose -side left -expand yes

	set f $w.parameters
	frame $f -relief groove -border 2
	pack $f -side top -fill x
	
	foreach a {width height fps length_s length_f} {
		label $f.l$a -text "$a"
		entry $f.e$a -textvariable Videoplayer_config(video_$a) -width 5
		pack $f.l$a $f.e$a -side left -expand yes
	}

	foreach a {start_s end_s speed scale} {
		label $f.l$a -text "$a"
		entry $f.e$a -textvariable Videoplayer_config(display_$a) -width 5
		pack $f.l$a $f.e$a -side left -expand yes
	}

	set f $w.actions
	frame $f -relief groove -bd 1
	pack $f -side top -fill x
	
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
