# Neruoarchiver.tcl, Interprets, Analyzes, and Archives Data from 
# the LWDAQ Recorder Instrument. It is a Polite LWDAQ Tool.
#
# Copyright (C) 2007-2021 Kevan Hashemi, Open Source Instruments Inc.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

#
# The Neuroarchiver records signals from Subcutaneous Transmitters 
# manufactured by Open Source Instruments. For detailed help, see:
#
# http://www.opensourceinstruments.com/Electronics/A3018/Neuroarchiver.html
#
# The Neuroarchiver uses NDF (Neuroscience Data Format) files to store
# data to disk. It provides play-back of data stored on file, with signal
# plotting and processing.
#

#
# Neuroarchiver_init creates the info and config arrays and the images the 
# Neuroarchiver uses to hold data in memory. The config array is available
# through the Config button but the info array is private.
#
proc Neuroarchiver_init {} {
#
# Here we declare the names of variables we want defined at the global scope.
# Such variables may exist before this procedure executes, and they will endure
# after the procedure concludes. The "upvar #0" assigns a local name to a global
# variable. After the following line, we can, for the duration of this
# procedure, refer to the global variable "Neuroarchiver_info" with the local
# name "info". The Neuroarchiver_info variable happens to be an array with a
# bunch of "elements". Each element has a name and a value. Here we will refer
# to the "name" element of the "Neuroarchiver_info" array with info(name).
#
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config
	global LWDAQ_Info
#
# We initialise the Neuroarchiver with LWDAQ_tool_init. Because this command
# begins with "LWDAQ" we know that it's one of those in the LWDAQ command
# library. We can look it up in the LWDAQ Command Reference to find out
# more about what it does.
#
	LWDAQ_tool_init "Neuroarchiver" "143"
	if {[winfo exists $info(window)]} {return 0}
#
# We start setting intial values for the private display and control variables.
#
	set info(play_control) "Idle"
	set info(record_control) "Idle"
	set info(record_control_label) "none"
	set info(play_control_label) "none"
#
# Recording data acquisition parameters.
#
	set config(daq_receiver) "A3027"
	set config(daq_ip_addr) "10.0.0.37"
	set config(daq_driver_socket) "1"
#
# A flag to tell us if the Neuroarchiver is running with graphics.
#
	set info(gui) $LWDAQ_Info(gui_enabled)
#
# The Neuroarchiver uses four LWDAQ images to hold data. The vt_image and
# af_image are those behind the display of the signal trace and the signal
# spectrum respectively. The buffer_image and data_image are used by the
# play-back process to buffer data from disk and pass data to the recorder
# instrument analysis routines respectively.
#
	set info(vt_image) "_neuroarchiver_vt_image_"
	set info(af_image) "_neuroarchiver_af_image_"
	set info(data_image) "_neuroarchiver_data_image_"
	set info(buffer_image) "_neuroarchiver_buffer_image_"
	lwdaq_image_destroy $info(vt_image)
	lwdaq_image_destroy $info(af_image)
	lwdaq_image_destroy $info(data_image)
	lwdaq_image_destroy $info(buffer_image)
#
# The recorder buffer variable holds data that we download from the 
# receiver but are unable to write to disk because the recording file
# is locked. The player buffer contains the results of processing for
# times when the characteristics file is locked.
#
	set info(recorder_buffer) ""
	set info(player_buffer) ""
#
# The plot window width and height get set here.
#
	set info(vt_plot_width) 600
	set info(vt_plot_height) 250
	lwdaq_image_create -width $info(vt_plot_width) \
		-height $info(vt_plot_height) -name $info(vt_image)
	set info(af_plot_width) 400
	set info(af_plot_height) 250
	lwdaq_image_create -width $info(af_plot_width) \
		-height $info(af_plot_height) -name $info(af_image)
#
# The size of the data and buffer images gets set here. We want both images to
# be large enough to hold the biggest block of messages the Neuroarchiver is
# likely to be called upon to display and analyze in one step. With a
# twenty-second time interval and ten subcutaneous transmitters running at 512
# messages per second, we would have a block of roughly 400 kbytes. The space
# available for a single block of data is the square of the image width. 
#
	set width 2000
	lwdaq_image_create -name $info(buffer_image) -width $width -height $width
	lwdaq_image_create -name $info(data_image) -width $width -height $width
# 
# When we read data from disk, we want to be sure that we will never read more
# data than our image can hold, but at the same time as much data as we can. We
# set the block size for reads from disk to be a fraction of the size of the
# data and buffer images.
#
	set info(block_size) [expr round($width * $width / 10) ]
#
# Properties of data messages.
#
	set info(core_message_length) 4
	set config(player_payload_length) 0
	set info(max_sample) 65535
	set info(min_id) 1
	set info(max_id) 255
	set info(set_size) 16
#
# Properties of clock messages. The clock period is in clock ticks, where each
# tick is one period of 32.768 kHz. The clock frequency is 128 SPS.
#
	set info(clock_id) 0
	set info(clock_period) 256
# 
# The number of messages records in data and buffer. Includes null messages that
# may be generated by corruption of a recording.
#
	set info(buffer_size) 0
	set info(data_size) 0
	set info(max_buffer_bytes) [expr $width * $width]
#
# The file overview window is an extension of the Neuroarchiver that allows us
# to work with an overview of a file's contents to select sections for
# play-back.
#
	set config(overview_num_samples) 20000
	set config(overview_activity_fraction) 0.01
	set info(overview_width) 800
	set info(overview_height) 250
	set info(overview_image) "_neuroarchiver_ov_image_"
	lwdaq_image_destroy $info(overview_image)
	lwdaq_image_create -width $info(overview_width) \
		-height $info(overview_height) \
		-name $info(overview_image)
	set info(overview_fsd) 2
#
# During play-back and processing, we step through each channel selected by the
# user (see channel_select parameter) and for each channel we create a graph of
# its signal versus time, which we display in the v-t window, and its amplitude
# versus frequency, which we display in the a-t window. The empty value for
# these two graphs is a point at the origin. When we have real data in the
# graphs, each graph point is two numbers: an x and y value, which would give
# time and value or frequency and amplitude. Note that the info(signal) and
# info(spectrum) elements are strings of characters. Their x-y values are
# represented as characters giving each number, with each number separated from
# its neighbors by spaces. On the one hand, handling numbers as strings is
# computationally intensive. On the other hand, the string-handling routines
# provided by TCL make it easy for us to write code that handles numbers in
# strings. As computers have become more powerful, passing numbers around in
# strings has become more practical. On a 1-GHz or faster computer, the
# Neuroarchiver Version can perform its most extensive signal processing on
# fourteen 512 SPS message streams faster than the messages come in.
#
	set info(channel_code) "0"
	set info(channel_num) "0"
	set info(signal) "0 0"
	set info(spectrum) "0 0"
	set info(values) "0"
#
# During play-back, we obtain a list of the number of messages available in
# each channel number. We include in this list any channels that have more
# than the config(active_threshold) parameter, which we define below.
#
	set info(channel_activity) ""
#
# When we determine a channel's expected message frequency in one routine,
# we want to save the frequency in a place that other routines can read it.
# The default frequency is 512.
#
	set info(frequency) "512"
#
# The separation of the components of the fourier transform is related to
# the playback interval. We set it to 1 Hz by default.
#
	set info(f_step) 1
#
# After we reconstruct a channel, we sometimes like to know how many messages we
# received from this channel. We cannot obtain this number from the signal
# string because reconstruction inserts substitute messages whenever a message
# is missing in the signal. So we save the number of messages received in its
# own info array parameter. We also save the number of messages after
# reconstruction and the loss as a percentage. We obtain reception efficiency by
# subtracting the loss from 100%.
#
	set info(num_received) 0
	set info(num_messages) 0
	set info(loss) 0
# 
# We set the baseline power values that we use for event detection to a value
# that is impossibly high, in units of k-square-counts. 
#
	set config(bp_set) 200.0
	set info(bp_reset) 10000.0
#
# We set the array of selected frequencies for reconstruction to an empty string.
# During reconstruction, we will set them to a value picked from the default
# frequency string. We also have a f_alert parameter for each channel, that we
# set to "Extra" if we have too many, "Loss" if we have too few, "None" if 
# the channel has not been active yet, and "Okay" if we have the correct number.
# Once the channel becomes inactive, it's most recent alert remains in place.
#
	for {set id $info(min_id)} {$id <= $info(max_id)} {incr id} {
		set info(f_$id) "0"
		set info(f_alert_$id) "None"
	}
	set config(loss_fraction) 0.8
	set config(extra_fraction) 1.1
	set config(calib_include) "Active"
	set info(calib_selected) ""
#
# When we read and write sets of baseline powers to archive metadata, we can use
# a name to distinguish different sets stored therein, or we can opt for no name
# at all, which is how things were before Neuroarchiver version 80.
#
	set info(no_name) "NONAME"
	set config(bp_name) $info(no_name)
#
# When we jump to an event in an event list or event library, we have a variety of 
# strategies for choosing the baseline power to apply when we arrive at the new 
# location. The "local" strategy is to use the current baseline power. The "read" 
# strategy is to read the baseline power out of the metadata. The "event" strategy 
# is to use the baseline power stored in the event to which we are jumping.
#
	set config(jump_strategy) "local"
#
# When we come to the end of an archive during playback, we can store the current 
# baseline powers in the metadata.
#
	set config(bp_autowrite) 0
#
# When we start a new archive, we have the option of reading the baseline powers
# out of the metadata.
#
	set config(bp_autoread) 0
#
# When we start a new archive, we should have the option of resetting the baseline
# powers in case it is an archive un-related to the source of the existing baseline
# powers.
#
	set config(bp_autoreset) 0
#
# We set the width fraction for the divisions in the graphs.
#
	set config(t_div) 0.1
	set config(v_div) 0.1
	set config(overview_t_div) 0.05
	set config(a_div) 0.1
	set config(f_div) 0.1
#
# Log plots require a list of values at which grid lines should appear
#
	set info(log_lines) "0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9\
		1 2 3 4 5 6 7 8 9 10 20 30 40 50 60 70 80 90 100 200 300 400 500 600\
		700 800 900 1000 2000 3000 4000 5000 6000 7000 8000 9000 10000\
		20000 30000 40000 50000 60000 70000 80000 90000 100000"
	set info(log_color) 11
#
# Here we provide a list of color codes we want to use for the voltage-
# time and amplitude-frequency plots. The list specifies deviations from
# the standard color table, giving an identifier and alternate color
# number for any such change. There are times when you may wish
# to force a more distinct color on two traces. The Neuroarchiver_color
# routine takes a channel number and returns a color code that accounts
# for any alterations in the color table.
#
	set config(color_table) "{0 0}"
#
# When the user defines their own processor file, we read the file into a
# local string so that we can apply it quickly to multiple channels. We
# keep this string private because otherwise it would appear in an entry box
# of our configuration array panel.
#
	set info(processor_script) ""
#
# We now define the configuration variables that the user can look at
# and modify in the configuration panel. We begin with the files the
# Neuroarchiver uses to record, play back, process, and report.
#
	set config(play_dir) $LWDAQ_Info(working_dir)
	set config(record_dir) $LWDAQ_Info(working_dir)
	set config(record_file) [file join $config(record_dir) Archive.ndf]
	set config(play_file) [file join $config(play_dir) Archive.ndf]
	set config(processor_file) [file join $config(play_dir) Processor.tcl]
	set config(event_file) [file join $config(play_dir) Events.txt]
#
# The verbose flag tells the Neuroarchiver to print more process
# information in its text window.
#
	set config(verbose) 0
# 
# The quiet_processing flag stops interval processing from printing
# the chracteristics line to the text window. This saves time when
# saving the results to a characteristics file.
#
	set config(quiet_processing) 0
#
# For diagnostic purposes we can print out raw messages to the screen when 
# verbose flag is set. We enter the number of messages we want displayed in
# the show_message parameter.
#
	set config(show_messages) 0
	set info(min_show_messages) 20
# 
# Timing constants for the recorder, in seconds.
	set config(record_end_time) 0
	set config(record_lag) 0.2
	set config(record_start_clock) 0
#
# The play index is the message number in the archive that is the start
# of the next interval.
#
	set config(play_index) 0
#
# Timing constants for the player, in seconds.
#
	set config(play_time) 0.0
	set info(t_min) $config(play_time)
	set info(play_end_time) 0.0
#
# The jump offset is added to the time of an event, so that the start of the
# event might be centered upon the playback interval. By default, we disable
# the offset by making it zero.
#
	set config(jump_offset) 0.0 
#
# The maximum play time is a value we are certain will be greater than the
# play time in any archive.
#
	set info(max_play_time) 360000
#
# Constants for sequential playback, in which we go through the entire file,
# looking at all clock messages to determine the play time.
#
	set info(sequential_block_length_messages) 100000
	set config(sequential_play) 0
#
# By default, the player moves from one file to the next automatically, or
# waits for data to be added to a file if there is no other later file. But
# we can force the player to stop with this configuration parameter. When
# LWDAQ is running as a background process, it will quit at the end of the
# file, which is what we want when we submit the processing of archives to 
# a cluster of computers.
#
	set config(play_stop_at_end) 0
#
#
# When we display events, we can isolate the channels to which the event 
# belongs. The channel select string is the third element in the event
# description. We isolate events with the following variable set to 1.
#
	set config(isolate_events) 1
	set info(num_events) 0
	set config(event_index) 1
	set info(event_id) 0
#
# The saved play file name variable allows us to detect when the file name
# has been changed since the last time it was used.
#
	set info(saved_play_time) "0000000000"
	set info(saved_play_file) "None"
#
# The saved_play_file_mtime saves the play file modification time, which allows
# us to recognise when the file has been modified, so we re-calculate the
# end time, which is useful when the file is being written to by the Recorder.
#
	set info(saved_play_file_mtime) 0
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
# The metadata header is a string the we append to the metadata of a 
# new archive. We can edit the header in the metadata header window.
#
	set info(metadata_header) ""
	set info(metadata_header_window) "$info(window)\.metadataheader"
#
# When autocreate is greater than zero, it gives the number of seconds
# after which we should stop using one archive and create another one.
# We find the Neuroarchiver to be efficient with archives hundreds of
# megabytes long, so autocreate can be set to 43200 seconds with no drop
# in performance, leading to twelve hours of data in one file.
#
	set config(autocreate) 3600
# 
# When we create a new archive, we wait until the system clock enters
# a window of time after the start of a new second. During this time
# we reset the data receiver and name the new recording archive after
# the current time in seconds. The window must be wide enough that we
# are certain to notice that we are in the window, but narrow enough
# that it does not compromise synchronization of the recording with
# the system clock.
#
	set info(sync_window_ms) 30
#
# When we create a new archive, we either perform synchronization, or just
# open a new file and keep recording to disk.
#
	set config(synchronize) 1
#
# The channel list tells the play-back process which channels it should
# extract from the message blocks for analysis. If we want reconstruction
# of the signal, which eliminates bad messages and replaces missing messages,
# we must specify the correct message frequency and the extent of the
# transmission scatter implemented by the tranmsitter. The phrase "5:512:8"
# specifies channel 5 with frequency 512 and scatter 8. We have default values
# for frequency, which will be used if we do not specify values.
#
	set config(channel_select) "*"
	set config(default_frequency) "128 256 512 1024 2048 4096"
	set config(standing_values) ""
	set config(unaccepted_values) ""
#
# We save the last clock message value in each message block so we can compare it 
# to the first message in the next message block. If the two are not consecutive,
# we issue a warning. The code for "undefined" is -1.
#
	set info(play_previous_clock) -1
#
# The Neuroarchiver provides several steps of signal processing. We can turn 
# these on and off with the following switches, each of which appears as a 
# checkbox in the Neuroarchiver panel. 
#
	set config(enable_processing) 0
	set config(save_processing) 0
	set config(enable_vt) 1
	set info(force_vt) 0
	if {$info(gui)} {
		set config(enable_af) 1
	} {
		set config(enable_af) 0
	}
	set config(af_calculate) 1
	set config(lt_calculate) 1
#
# The reconstruct flag turns on reconstruction. There are few times when we
# don't want reconstruction, but one such time might be when we don't know the
# frequency of the underlying signal.
#
	set config(enable_reconstruct) 1
#
# We record and play back data in intervals. Here we specify these intervals
# in seconds. The Neuroarchiver translates seconds to clock messages.
#
	set config(record_interval) 0.5
	set config(play_interval) 1.0
	set info(play_interval_copy) 1.0
	set info(clocks_per_second) 128
	set info(ticks_per_clock) 256
	set info(max_message_value) 65535
	set info(value_range) [expr $info(max_message_value) + 1]
	set info(clock_cycle_period) \
		[expr ($info(max_message_value)+1)/$info(clocks_per_second)]
#
# Any channel with enough messages in the playback interval will be considered
# active. The activity rate is the minimum message rate, in messages per second,
# that will be treated as active.
#
	set config(activity_rate) 40
#
# The Neuroarchiver will record events to a log, in particular warnings and
# errors generated during playback and recording.
#
	set config(log_warnings) 0
	set config(log_file) [file join \
		[file dirname $info(settings_file_name)] \
		Neuroarchiver_log.txt ]
# 
# Some errors we don't want to write more than once to the text window, so
# we keep a copy of the most recent error to compare to.
#
	set info(previous_line) ""
#
# The num_errors parameter contains the number of errors detected in the
# clock message sequence of the current interval's data.
#
	set info(num_errors) 0
#
# Plot display controls, each of which appear in an entry or checkbox.
#
	set config(v_range) 65535
	set config(v_offset) 0
	set config(vt_mode) "SP"
	set config(a_max) 10000
	set config(a_min) 0.0
	set config(f_min) 0.0
	set config(f_max) 200
	set config(log_frequency) 0
	set config(log_amplitude) 0
#
# The Neuroarchiver deletes old lines from its text window. It keeps
# the following number of most recent lines. The more lines we keep,
# the slower the print-out of characteristics to the screen will be.
#
	set config(num_lines_keep) 200
#
# Colors for windows.
#
	set info(title_color) "purple"
	set info(label_color) "purple"
	set info(variable_bg) "tan"
#
# We apply a window function to the signal before we take the fourier 
# transform. This function smooths the signal to its average value 
# starting window_fraction*num_samples from the left and right edges.
#
	set config(window_fraction) 0.1
# 
# We define two different display zoom values for the value versus time
# and amplitude versus frequency plots. We alternate between these when
# we click on the display panels.
#
	set info(vt_zoom_small) 1.0
	set info(af_zoom_small) 1.0
	set info(vt_zoom_large) 2.0
	set info(af_zoom_large) 2.0
	set config(vt_zoom) $info(vt_zoom_small)
	set config(af_zoom) $info(af_zoom_small)
#
# When glitch_threshold is greater than zero, the glitch threshold
# is enabled. A threshold equal to the baseline amplitude is a good
# choice.
#
	set config(glitch_threshold) 200
#
# The glitch_count parameter is for counting how many glitches the 
# glitch filter removes from the data.
#
	set config(glitch_count) 0
# 
# The Event Classifier default settings. 
#
	set info(classifier_window) $info(window)\.classifier
	set config(classifier_types) ""
	set config(classifier_metrics) ""
	set info(classifier_metrics_saved) ""
	set config(classifier_x_metric) "none"
	set config(classifier_y_metric) "none"
	set info(classifier_match) "0.0"	
	set config(classifier_match_limit) "0.1"
	set config(classifier_threshold) "0.0"
	set config(enable_handler) "0"
	set info(handler_script) ""
	set config(classifier_library) ""
#
# The Location Tracker settings.
#
	set info(tracker_window) $info(window)\.tracker
	set info(tracker_width) 640
	set info(tracker_height) 320
	set info(tracker_image_border_pixels) 10
	set config(tracker_scale) "32" 
	set config(tracker_extent) "100"
	set config(tracker_percentile) "50"
	set config(tracker_threshold) "60"
	set config(tracker_slices) "8"
	set config(tracker_persistence) "None"
	set config(tracker_mark_cm) "0.1"
	set config(tracker_show_coils) "0"
	set info(A3032_coordinates) "0 0 0 8 0 16 \
		8 0 8 8 8 16 \
		16 0 16 8 16 16 \
		24 0 24 8 24 16 \
		32 0 32 8 32 16"
	set info(A3032_payload) "16"
	set info(A3038A_coordinates) $info(A3032_coordinates)
	set info(A3038A_payload) $info(A3032_payload)
	set config(tracker_coordinates) ""
		
	set config(tracker_background) "0 0 0 0 0 0 0 0 0 0 0 0 0 0 0"
	set info(tracker_range_border) "1.0"
	set info(tracker_range) "-1.0 -1.0 +33.0 +17.0"
	set info(tracker_powers) "0"
	set info(tracker_x) "0"
	set info(tracker_y) "0"
	set info(tracker_x_previous) "0"
	set info(tracker_y_previous) "0"
#
# The Playback Clock default settings.
#
	set config(datetime_format) {%d-%b-%Y %H:%M:%S}
	set info(datetime_play_time) [Neuroarchiver_datetime_convert [clock seconds]]
	set config(datetime_jump_to) [Neuroarchiver_datetime_convert [clock seconds]]
	set info(datetime_start_time) [Neuroarchiver_datetime_convert [clock seconds]]
	set info(datetime_archive_name) "M0000000000.ndf"
	set info(datetime_panel) $info(window)\.clock
	set info(export_panel) $info(window)\.export
	set info(export_help_url) \
		"http://www.opensourceinstruments.com/Electronics/A3018/Neuroarchiver.html#Exporting%20Data"
#
# Export boundaries.
#
	set info(export_start_s) "0000000000"
	set info(export_end_s) $info(export_start_s)
	set config(export_start) [Neuroarchiver_datetime_convert $info(export_start_s)]
	set config(export_duration) 60
	set config(export_dir) "~/Desktop"
	set info(export_state) "Idle"
	set info(export_vfl) ""
	set info(export_epl) ""
	set config(export_video) "0"
	set config(export_format) "TXT"
	set info(export_run_start) [clock seconds]
	set config(export_reps) "1"
	set info(optimal_export_interval) "8"
#
# Video playback parameters. We define executable names for ffmpeg and mplayer.
#
	set info(video_library_archive) "http://www.opensourceinstruments.com/ACC/Videoarchiver.zip"
	set config(video_dir) $LWDAQ_Info(working_dir)
	set info(video_file) [file join $config(video_dir) Video.mp4]
	set info(video_stop_time) 0.0
	set info(video_end_time) 0.0
	set info(video_wait_ms) 100
	set info(video_num_waits) 10
	set info(video_min_interval_s) 1.0
	set config(video_speed) "1.0"
	set config(video_zoom) "1.0"
	set info(video_state) "Idle"
	set info(video_log) [file join $LWDAQ_Info(program_dir) \
		Videoarchiver Scratch neuroarchiver_video_log.txt]
	set config(video_enable) "0"
	set info(video_process) "0"
	set info(video_channel) "file1"
	set info(video_file_cache) [list]
	set info(max_video_files) "100"
	set os_dir [file join $LWDAQ_Info(program_dir) Videoarchiver $LWDAQ_Info(os)]
	if {$LWDAQ_Info(os) == "Windows"} {
		set info(ssh) [file join $os_dir ssh/ssh.exe]	
		set info(ffmpeg) [file join $os_dir ffmpeg/bin/ffmpeg.exe]
		set info(mplayer) [file join $os_dir mplayer/mplayer.exe]
	} elseif {$LWDAQ_Info(os) == "MacOS"} {
		set info(ssh) "/usr/bin/ssh"
		set info(ffmpeg) [file join $os_dir ffmpeg]
		set info(mplayer) [file join $os_dir mplayer]
	} elseif {$LWDAQ_Info(os) == "Linux"} {
		set info(ssh) "/usr/bin/ssh"
		set info(ffmpeg) [file join $os_dir $LWDAQ_Info(arch) ffmpeg/ffmpeg]
		set info(mplayer) [file join $os_dir $LWDAQ_Info(arch) mplayer]
	} else {
		error "Videoarchiver does not support $LWDAQ_Info(os)."
		return ""
	}
#
# The Save button in the Configuration Panel allows you to save your own
# configuration parameters to disk a file called settings_file_name. This
# file was declared earlier in LWDAQ_tool_startup. Now we check to see
# if there is such a file, and if so we read it in and execute the TCL
# commands it contains. Each of the commands sets an element in the 
# configuration array. Try pressing the Save button and look for the
# settings file in ./Tools/Data. You can open it and take a look.
#
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 
#
# We use the value of bp_set to initialize the baseline powers to 
# one common value.
#
	for {set id $info(min_id)} {$id <= $info(max_id)} {incr id} {
		set info(bp_$id) $config(bp_set)
	}
#
# We have file tail variables that we display in the Neuroarchiver
# window. We set these now, after we have read in the saved settings.
#
	foreach n {record play processor event} {
		set info($n\_file_tail) [file tail $config($n\_file)]
	}
#
# We are done with initialization. We return a 1 to show success.
#
	return 1   
}

#
# Neuroarchiver_configure calls the standard LWDAQ tool configuration
# routine to produce a window with an array of configuration parameters
# that the user can edit.
#
proc Neuroarchiver_configure {} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info
	LWDAQ_tool_configure Neuroarchiver 4
}

#
# Neuroarchiver_print writes a line to the text window. If the color
# specified is "verbose", the message prints only when the verbose flag
# is set, and in black. Warnings and errors are always printed in the warning
# and error colors. In addition, if the log_warnings is set, the routine
# writes all warnings and errors to the Neuroarchiver log file. The print
# routine will refrainn from writing the same error message to the text 
# window repeatedly when we set the color to the key word "norepeat". The 
# routine always stores the previous line it writes, so as to compare in 
# the case of a norepeat requirement.
#
proc Neuroarchiver_print {line {color "black"}} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info
	
	if {$color == "norepeat"} {
		if {$info(previous_line) == $line} {return ""}
		set color black
	}
	set info(previous_line) $line
	
	if {[regexp "^WARNING: " $line] || [regexp "^ERROR: " $line]} {
		append line " ([Neuroarchiver_datetime_convert [clock seconds]]\)"
		if {[regexp -nocase [file tail $config(play_file)] $line]} {
			set line [regsub "^WARNING: " $line "WARNING: $info(datetime_play_time) "]
		} 
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
	return $line
}

#
# Neuroarchiver_print_event prints an event to the text window with a link
# embedded in the file name so that we can click on the event and jump to it.
# If we don't specify an event, the routine prints the current event to the
# window.
#
proc Neuroarchiver_print_event {{event ""}} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info

	if {![winfo exists $info(window)]} {return 0}

	if {$event == ""} {
		set event "$info(play_file_tail) $info(t_min) \"$config(channel_select)\"\
			\"Event in $config(play_interval)-s interval\""
	}

	set t $info(text)
	set i [incr info(event_id)]
	$t tag bind event_$i <Button> [list LWDAQ_post [list Neuroarchiver_jump $event 0]]
	$t insert end "<J>" "event_$i textbutton"
	$t insert end " $event\n"
	$t see end

	return $event
}



#
# Neuroarchiver_play_time_format stops the play time from becoming corrupted
# by rounding errors, and makes sure that there is always one number after the
# decimal point, while at the same time dropping unecessary trailing zeros.
#
proc Neuroarchiver_play_time_format {play_time} {
	if {![string is double -strict $play_time]} {
		Neuroarchiver_print "ERROR: Bad play time \"$play_time\", assuming 0.0s."
		return "0.0"
	}
	set play_time [format %.6f $play_time]
	if {![regexp {[0-9]+\.[0-9]+} $play_time]} {
		set play_time [format %.1f $play_time]
	}
	while {[regexp {[0-9]0$} $play_time]} {
		set play_time [string range $play_time 0 end-1]
	}
	return $play_time
}

#
# Neuroarchiver_pick allows the user to pick a new play_file, record_file, 
# processor_file, event_file, record_dir, play_dir, or video_dir.
#
proc Neuroarchiver_pick {name {post 0}} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info
	global LWDAQ_Info

	# If we call this routine from a button, we prefer to post
	# its execution to the event queue, and this we can do by
	# adding a parameter of 1 to the end of the call.
	if {$post} {
		LWDAQ_post [list Neuroarchiver_pick $name]
		return ""
	}

	if {[regexp "_file" $name]} {
		set fn [LWDAQ_get_file_name 0 [file dirname [set config($name)]]]
		if {![file exists $fn]} {
			Neuroarchiver_print "WARNING: File \"$fn\" does not exist."
			return $fn
		}
		set config($name) $fn
		set info($name\_tail) [file tail $fn]
		return $fn
	} 
	if {[regexp "_dir" $name]} {
		set dn [LWDAQ_get_dir_name [set config($name)]]
		if {![file exists $dn]} {
			Neuroarchiver_print "WARNING: Directory \"$dn\" does not exist."
			return $dn
		}
		set config($name) $dn
		return $dn
	}
	return ""
}

#
# Neuroarchiver_list prints a list of NDF files and their metadata 
# comments. The routine takes as input a list of files. If the list
# is empty, it asks the user to select the files to list.
#
proc Neuroarchiver_list {{fl ""}} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info
	
	if {$fl == ""} {
		set fl [LWDAQ_get_file_name 1]
		if {$fl == ""} {
			return 0
		}
	}
	set fl [lsort -dictionary $fl]

	set i 1
	while {[winfo exists [set w $info(window)\.comments_$i]]} {incr i}
	toplevel $w
	wm title $w "List of [llength $fl] Selected Archives"
	LWDAQ_text_widget $w 70 40
	LWDAQ_enable_text_undo $w.text	
	$w.text tag configure textbutton -background lightblue
	$w.text tag bind textbutton <Enter> {%W configure -cursor arrow} 
	$w.text tag bind textbutton <Leave> {%W configure -cursor xterm} 

	set i 1
	foreach fn $fl {
		LWDAQ_print -nonewline $w.text "[file tail $fn]   " purple
		$w.text tag bind s_$i <Button> [list LWDAQ_post \
			[list Neuroarchiver_jump "[file tail $fn] 0.0 * Selected from list"]]
		$w.text insert end "  Step  " "s_$i textbutton"
		$w.text insert end "   "
		$w.text tag bind e_$i <Button> [list LWDAQ_post \
			[list Neuroarchiver_metadata_view $fn]]
		$w.text insert end "  Metadata  " "e_$i textbutton"
		$w.text insert end "   "
		$w.text tag bind o_$i <Button> [list LWDAQ_post \
			[list Neuroarchiver_overview $fn]]
		$w.text insert end "  Overview  " "o_$i textbutton"
		$w.text insert end "\n"
		if {![catch {LWDAQ_ndf_data_check $fn} error_message]} {
			set metadata [LWDAQ_ndf_string_read $fn]
			set comments [LWDAQ_xml_get_list $metadata "c"]
			foreach c $comments {
				$w.text insert end [string trim $c]\n
			}
			$w.text insert end "\n"
		} {
			LWDAQ_print $w.text "ERROR: $error_message.\n"
		}
		incr i
		LWDAQ_support
	}
	return 1
}

#
# Neuroarchiver_metadata_write writes the contents of a text window, which is 
# $w.text, into the metadata of a file $fn. We use this procedure in the Save 
# button of the metadata display window.
#
proc Neuroarchiver_metadata_write {w fn} {
	LWDAQ_ndf_string_write $fn [string trim [$w.text get 1.0 end]]\n
}

#
# Neuroarchiver_metadata_view reads the metadata from an NDF file called
# $fn and displays the metadata string in a new text window. You 
# can edit the string and save it to the same file with a Save button.
#
proc Neuroarchiver_metadata_view {fn} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config
	
	# Determine the file name.
	switch $fn {
		"play" {set fn $config(play_file)}
		"record" {set fn $config(record_file)}
		default {
			if {![file exists $fn]} {
				Neuroarchiver_print "ERROR: File \"$fn\" does not exist."
				return 0
			}
		}
	}
	
	# Check the file.
	if {[catch {LWDAQ_ndf_data_check $fn} error_message]} {
		Neuroarchiver_print "ERROR: Checking archive, $error_message."
		return 0
	}
	
	# Create a new top-level text window that is a child of the 
	# Neuroarchiver window. 
	set i 1
	while {[winfo exists [set w $info(window)\.metadata_$i]]} {incr i}
	toplevel $w
	wm title $w "[file tail $fn] Metadata"
	LWDAQ_text_widget $w 60 20
	LWDAQ_enable_text_undo $w.text	

	# Create the Save button.
	frame $w.f
	pack $w.f -side top
	button $w.f.save -text "Save" -command [list Neuroarchiver_metadata_write $w $fn]
	pack $w.f.save -side left
	
	# Print the metadata to the text window.
	LWDAQ_print $w.text [LWDAQ_ndf_string_read $fn]

	return 1
}

#
# Neuroarchvier_metadata_header returns a header string for a newly-created
# archive. The header string contains one or two xml <c> fields, which we intend to
# act as two comment fields. The first field is one we generate automatically.
# It contains the time, host, and software version. The second field contains 
# the contents of the metadata header string, with white space removed before 
# and after. If there are no non-whitespace characters in the metadata header
# string, we don't add the second comment, and this is the default when we open
# the Neuroarchiver. We create a metadata header string by pressing the header
# button and entering and saving the string. This string might contain a 
# description of our experiment, and it will be added to all archives we create
# as we record.
#
proc Neuroarchiver_metadata_header {} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config
	upvar #0 LWDAQ_config_Recorder iconfig
	global LWDAQ_Info	

	set header "<c>\
			\nDate Created: [clock format [clock seconds] -format $config(datetime_format)].\
			\nCreator: Neuroarchiver $info(version), LWDAQ_$LWDAQ_Info(program_patchlevel).\
			\nHost: [info hostname]\
			\n</c>\
			\n<payload>$iconfig(payload_length)</payload>\
			\n<coordinates>$config(tracker_coordinates)</coordinates>"
	if {[string trim $info(metadata_header)] != ""} {
		append header "<c>\
			\n[string trim $info(metadata_header)]\
			\n</c>"
	}
	return $header
}

#
# Neuroarchiver_metadata_header_edit displays the recording header in
# a window. We can edit the header and change the codes. We save the 
# new header string by pressing the save button. We cancel by closing 
# the window.
#
proc Neuroarchiver_metadata_header_edit {} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config
	
	# Create a new top-level text window
	set w $info(metadata_header_window)
	if {[winfo exists $w]} {
		raise $w
	} {
		toplevel $w
		wm title $w "Recording Metadata Header"
		LWDAQ_text_widget $w 60 20
		LWDAQ_enable_text_undo $w.text	
	}

	# Create the Save button.
	frame $w.f
	pack $w.f -side top
	button $w.f.save -text "Save" -command Neuroarchiver_metadata_header_save
	pack $w.f.save -side left
	
	# Print the metadata to the text window.
	LWDAQ_print $w.text $info(metadata_header)

	return 1
}

#
# Neuroarchiver_metadata_header_save takes the contents of the metadata header
# edit text window and saves it to the metadata header string.
#
proc Neuroarchiver_metadata_header_save {} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config

	set w $info(metadata_header_window)
	if {[winfo exists $w]} {
		set info(metadata_header) [string trim [$w.text get 1.0 end]]
	} {
		Neuroarchiver_print "ERROR: Cannot find metadata header edit window."
	}
	return $info(metadata_header)
}

#
# Neuroarchiver_seek_time determines the index of the clock message that
# occurs just before seek_time and also just after seek time. If the seek
# time lies exactly upon a clock message, the before and after clock 
# messages will be the same. When the routine searches through an archive
# for the correct clock messages, it starts at the beginning and proceeds in 
# steps small enough to be less than one complete clock cycle (512 s for 
# clock frequency 128 Hz). If the archive is uncorrupted, it will contain a
# sequence of clock messages, each with value one greater than the last, 
# with the exception of clock messages with value max_sample, which will 
# be followed by one of value zero. The seek routine is able to find 
# time points in the archive quickly because it does not have to look at
# all the clock messages in the archive. If the archive is severely 
# corrupted, with blocks of null messages and missing data, the seek 
# routine can fail to notice jumps in the clock messages values and so fail to 
# note that its time calculation is invalid. As an alternative to jumping
# through the archive, the Neuroarchiver_sequential_time starts at the first
# clock message and counts clock messages, adding one clock period to its
# measurement of archive time for every clock message, irrespective of the
# values of the messages. Both rseek_time routines take the same parameters
# and return four numbers: lo_time, lo_index, hi_time, and hi_index. The 
# routines assume the archive contains a clock message immediately after the 
# last message in the archive, which we call the "end clock". The routine 
# will choose the end clock for hi_time and hi_index if the seek time is 
# equal to or greater than the length of the archive. If the seek time is 
# -1, the routine takes this to mean that it should find the end time of 
# the archive, which will be the time and index of the end clock, even though
# this end clock is not included in the archive. Note that the index of a 
# message is its index in the archive's data block, when we divide the block
# into messages. Messages are at least core_message_length long, and my have an
# arbitrary payload attached to the end, as given by player_payload_length.
# The byte address of a message is the byte number of the first byte of
# the message within the archive's data block. The return string "0 2 0 2" 
# means time zero occurs at message index 2 in the archive. The message with 
# index 2 is the third message in the data block of the archive. We might obtain
# such a result when we specify seek time of 0 and apply it to an archive
# that, for some reason, does not start with a clock message. We can pass
# in optional values for lo_time and lo_index, where the seek should start
# from these values. The lo_time should be the play time that is correct
# for message lo_index within the file.
#
proc Neuroarchiver_seek_time {fn seek_time {lo_time 0.0} {lo_index 0}} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config
	
	if {$config(sequential_play)} {
		return [Neuroarchiver_sequential_time $fn $seek_time $lo_time $lo_index]
	}

	set max_consecutive_non_clocks 200
	set jump_scale 0.1
	set message_length [expr $info(core_message_length) + $config(player_payload_length)]
	
	if {$seek_time < 0} {set seek_time -1}
	if {$lo_index == 0} {set lo_time 0.0}
	set hi_time $lo_time
	set hi_index $lo_index

	scan [LWDAQ_ndf_data_check $fn] %u%u data_start data_length
	set end_index [expr $data_length / $message_length - 1]

	set f [open $fn r]
	fconfigure $f -translation binary
	set jump_size $info(max_message_value)
	set value -1
	set previous_clock_value -1
	set clock_time $lo_time
	set previous_clock_time $lo_time
	set index $lo_index
	set previous_clock_index $lo_index
	set num_consecutive_non_clocks -1
	while {$index <= $end_index} {	
		# We read the index'th message in the archive and read its 
		# id, value, and timestamp from the file.
		seek $f [expr $data_start + ($message_length * $index)]
		binary scan [read $f $message_length] cSc id value timestamp
		set id [expr $id & 0xff] 
		set value [expr $value & 0xffff]
		set timestamp [expr $timestamp & 0xff]
		
		if {($id == 0) & ($timestamp != 0)} {
			# We have found a clock message. The id is zero and the timestamp is not
			# zero. If the timestamp were zero, this would be either a null message 
			# or a corrupted clock message. All clock messages have a non-zero firmware
			# number in their timestamp field.			
			set num_consecutive_non_clocks 0
			
			# Check to see if this is the first clock message we have found.
			if {$previous_clock_value < 0} {
				# If this is the first clock message, as indicated by the negative
				# previous_clock_value, we intialize our clock message tracking.
				set previous_clock_value $value
				set previous_clock_time $lo_time
				set clock_time $lo_time
			} {
				# If this is not our first clock message, we save the existing clock
				# time and calculate the new clock time using the difference in the
				# clock message values. We never jump more than max_message_value 
				# messages through an archive, so we are certain that the difference
				# in the values gives us an unambiguous measurement of the time 
				# difference.
				if {$previous_clock_value != $value} {
					set previous_clock_time $clock_time
					set clock_time [expr $clock_time \
						+ 1.0 * ($value - $previous_clock_value) / $info(clocks_per_second)]
					if {$value < $previous_clock_value} {
						set clock_time [expr $clock_time + $info(clock_cycle_period)]
					}
				}
			}
			if {($clock_time > $seek_time) && ($seek_time > 0)} {
				if {$jump_size == 1} {
					# We moved one message at a time from the previous clock, which
					# had time less than the seek time, and now we arrive at a clock
					# with time greater than the seek time. So the previous and current
					# clocks straddle the seek time. The two times should be separated
					# by exactly one clock period, but their indices can be separated
					# by many transmitter messages. If there are missing clock messages
					# in the recording, the two times can be separated by many clock
					# periods, as when there is missing data from a recording.
					set lo_time $previous_clock_time
					set lo_index $previous_clock_index
					set hi_time $clock_time
					set hi_index $index
					set index [expr $end_index +1]
				} {
					# We jumped past the clock that is just after the seek time, or
					# there is no such clock just after the seek time. We don't know
					# which yet, but to find out, we reduce the jump size and go back 
					# to the previous clock. We must restore the clock time to the 
					# previous clock time and the index to the previous clock index.
					set jump_size [expr round($jump_scale*$jump_size)]
					set clock_time $previous_clock_time
					set index $previous_clock_index
				}
			} {
				if {$clock_time == $seek_time} {
					# This is the ideal case of seek time within the archive range
					# and we find a clock that has exactly that time. Thus the lo and
					# hi clocks are the same.
					set lo_time $clock_time
					set lo_index $index
					set hi_time $lo_time
					set hi_index $lo_index
					set index [expr $end_index +1]
				} {
					# The clock time is still less than the seek time, so we must keep
					# going to find a higher clock time. We jump farther into the archive,
					# after saving the current clock value and index.
					set previous_clock_value $value
					set previous_clock_index $index
					set index [expr $index + $jump_size]
					if {$index > $end_index} {
						if {$jump_size == 1} {
							# Our previous clock message is the last message in the archive.
							# The next clock message is the end clock, and our clock time
							# is either less than the seek time or we are seeking the end
							# time. So we use the index that is just past the end of the
							# archive and we increment our clock time by one clock period
							# to get both the lo and hi clocks.
							set lo_time [expr $clock_time + 1.0/$info(clocks_per_second)]
							set lo_index $index
							set hi_time $lo_time
							set hi_index $lo_index
						} {
							# We jumped past the end of the archive, missing some messages
							# between our current clock and the end. So reduce the jump
							# size and go back to the previous clock.
							set jump_size [expr round($jump_scale*$jump_size)]
							set index $previous_clock_index
						}
					}
				}
			}
		} {
			# This message is not a clock message. Either we have just jumped to this
			# location in the archive, ready to search for the next clock message, or 
			# we have been stepping through the archive one message at a time performing
			# the search. We must step to the next message. The message may be a null 
			# message or a corrupted clock message or a valid data message. In all 
			# cases, we take a step forward.
			incr index

			# We keep track of the number of non-clocks. If we encounter more than is
			# possible in valid data, we force another jump. If this jump takes us past
			# the end of the archive, we set the time and index parameters as best
			# we can.
			incr num_consecutive_non_clocks
			if {$num_consecutive_non_clocks >= $max_consecutive_non_clocks} {
				set num_consecutive_non_clocks 0
				set index [expr $index + $jump_size]
				if {$index > $end_index} {
					set lo_time [expr $clock_time + 1.0/$info(clocks_per_second)]
					set lo_index $index
					set hi_time $lo_time
					set hi_index $lo_index
					break
				}
			}
			
			if {$index > $end_index} {
				# Our index now points past the end of the archive, to the end clock.
				if {$jump_size <= 1} {
					# The jump size is 1, which means we have examined every message 
					# between the previous clock and the end clock. So we can determine
					# the end clock time by adding a clock period to the previous clock
					# time. We know that the previous clock time was either less than
					# the seek time or we were seeking the end clock, so we will use
					# the end clock for both our clocks.
					set lo_time [expr $clock_time + 1.0/$info(clocks_per_second)]
					set lo_index $index
					set hi_time $lo_time
					set hi_index $lo_index
				} {
					# The jump size is more than 1, so we may have jumped over a clock
					# message that lies between the previous clock and the end clock. 
					# We must go back to the previous clock and use a smaller jump size.
					set index $previous_clock_index
					set jump_size [expr round($jump_scale*$jump_size)]
				}
			}
		}

		LWDAQ_support
	}

	close $f

	if {$num_consecutive_non_clocks >= $max_consecutive_non_clocks} {
		Neuroarchiver_print "WARNING: Archive [file tail $fn] is severely corrupted,\
			consider using sequential navigation."
	}
	
	return "$lo_time $lo_index $hi_time $hi_index"
}

#
# Neuroarchiver_sequential_time has the same format as Neuroarchiver_seek_time
# but proceeds through the archive calculating time by counting every single
# clock message. We use this routine with corrupted archvies, in which the time
# represented by the values of the clock messages is so distorted as to be useless.
# Instead of using the clock message values, we assume every clock message represents
# a time increment of one clock period, and we search through every clock message
# to find the correct time.
#
proc Neuroarchiver_sequential_time {fn seek_time {lo_time 0.0} {lo_index 0}} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config

	set message_length [expr $info(core_message_length) + $config(player_payload_length)]
	set block_length [expr $message_length * $info(sequential_block_length_messages)]
	set image_width [expr round(sqrt($block_length)) + 10]

	set image_name "_neuroarchiver_sequential_image_"
	lwdaq_image_destroy $image_name
	lwdaq_image_create -width $image_width -height $image_width	-name $image_name

	if {$seek_time < 0} {set seek_time -1}
	if {$lo_index == 0} {set lo_time 0.0}
	set hi_time $lo_time
	set hi_index $lo_index

	scan [LWDAQ_ndf_data_check $fn] %u%u data_start data_length
	set end_index [expr ($data_length / $message_length) - 1]
	
	set f [open $fn r]
	fconfigure $f -translation binary

	set clock_time $lo_time
	set index $lo_index
	set done 0
	while {!$done} {
		seek $f [expr $data_start + ($index * $message_length)]
		set data [read $f $block_length]
		set data_size [string length $data]

		lwdaq_data_manipulate $image_name clear
		lwdaq_data_manipulate $image_name write 0 $data
		
		if {$seek_time >= 0} {
			set target_lo [expr ($seek_time - $clock_time) * $info(clocks_per_second)]
			set target_lo [expr round($target_lo - fmod($target_lo,1))]
			set target_hi [expr $target_lo + 1]
		} {
			set target_lo -1
			set target_hi -1
		}

		set clocks [lwdaq_recorder $image_name \
			"-payload $config(player_payload_length) \
			-size [expr $data_size / $message_length] clocks $target_lo $target_hi -1"]
		scan $clocks %d%d%d%d%d%d num_errors num_clocks num_messages \
			local_lo_index local_hi_index last_index
		set block_end_time [expr $clock_time + 1.0 * $num_clocks / $info(clocks_per_second)]

		if {$seek_time >= 0} {
			if {$block_end_time > $seek_time} {
				set lo_index [expr $index + $local_lo_index]
				set lo_time [expr $clock_time + 1.0 * $target_lo / $info(clocks_per_second)]
				if {$lo_time == $seek_time} {
					set hi_index $lo_index
					set hi_time $lo_time
				} {
					set hi_index [expr $index + $local_hi_index]
					set hi_time [expr $clock_time + 1.0 * $target_hi / $info(clocks_per_second)]
				}
				set done 1
			} {
				set lo_index $last_index
				set lo_time [expr $block_end_time - 1.0 / $info(clocks_per_second)]
				set hi_index [expr $index + $num_messages]
				set hi_time $block_end_time
				set clock_time $block_end_time
			}
		} {
			set lo_index [expr $index + $num_messages]
			set lo_time $block_end_time
			set hi_index $lo_index
			set hi_time $lo_time
			set clock_time $block_end_time
			if {$index >= $end_index} {
				set done 1
			}
		}
		set index [expr $index + ($data_size / $message_length)] 
		if {$index > $end_index} {set done 1}
		LWDAQ_support
	}

	close $f
	
	return "$lo_time $lo_index $hi_time $hi_index"
}

# Neuroarchiver_end_time determines the time interval spanned by a file.
# It calls Neuroarchiver_seek_time with value -1 to obtain the length of 
# the archive. We curtail the end time to two decimal places in order to
# avoid display problems for archives that have unusual end times as a result
# of data loss during recording.
#
proc Neuroarchiver_end_time {fn {ref_time 0} {ref_index 0}} {
	scan [Neuroarchiver_seek_time $fn -1 $ref_time $ref_index] \
		%f%u%f%u lo_time lo_index hi_time hi_index
	set end_time [Neuroarchiver_play_time_format $hi_time]
	if {fmod($end_time,1) != 0} {
		set end_time [format %.2f $end_time]
	}
	return $end_time
}

#
# Neuroarchiver_filter is for use in processor scripts as a means of detecting
# events in a signal. The routine scales the amplitude of the discrete transform 
# components according to four numbers, which specify the central region of the
# pass-band and the two extremes of the pass-band. The scaling is linear,
# which is not something we can do easily with recursive filters, or with
# analog filters, but is simple in software. The four numbers are band_lo_end,
# band_lo_center, band_hi_center, and band_hi_end. They are in units of frequency.
# Components below band_lo_end and above band_hi_end are multiplied by zero. 
# Components between band_lo_end and band_lo_center are scaled by zero to one
# from the lower to the upper frequency. Components from band_lo_center to 
# band_hi_center are added as they are. Components from band_hi_center to
# band_hi_end are scaled from one to zero from the lower to the upper frequency.
# Thus we have a pass-band that might be sharp or gentle. We can implement
# a high-pass filter by setting band_lo_end and band_lo_center to zero. The
# routine returns the total power of the remaining components, which is the
# sum of their squares. We do not multiply the combined power by any scaling
# factor because there are several variants of the discrete fourier transform
# with different scaling factors, and we want to avoid hiding such multiplications
# in our code. If "show" is set, the routine plots the filtered signal on the 
# screen by taking the inverse transform of the selected frequency components. 
# If "replace" is set, the routine calculates the inverse transform of the filtered 
# signal, making it available to the calling routine in the info(values) variable.
# Note that the routine does not replace the info(signal) string, which contains
# the reconstructed signal values and their timestamps. Only the info(values) 
# string is replaced. By default, the routine does not plot nor does it perform 
# the inverse transform, both of which take time and slow down processing. The 
# show parameter, if not zero, is used to scale the signal for display. By default
# the filter is band-pass. But if we set "bandpass" to 0, the filter is a band-stop
# filter.
#
proc Neuroarchiver_filter {band_lo_end band_lo_center \
		band_hi_center band_hi_end \
		{show 0} {replace 0} {bandpass 1}} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config

	# Check the inputs.
	foreach f "$band_lo_end $band_lo_center $band_hi_center $band_hi_end" {
		if {![string is double -strict $f]} {
			error "invalid frequency \"$f\""
		}
	}
	if {$band_lo_end > $band_lo_center} {
		error "cannot have band_lo_end > band_lo_center"
	}
	if {$band_lo_center > $band_hi_center} {
		error "cannot have band_lo_center > band_hi_center"
	}
	if {$band_hi_center > $band_hi_end} {
		error "cannot have band_hi_center > band_hi_end"
	}

	# Check the current spectrum.
	if {[llength $info(spectrum)] <= 1} {
		error "no spectrum exists to filter"
	}
	
	# Filter the current spectrum and calculate the total power.
	set filtered_spectrum ""
	set f 0
	set band_power 0.0
	foreach {a p} $info(spectrum) {
		if {($f > $band_lo_end) && ($f < $band_lo_center)} {
			set b [expr $a*($f-$band_lo_end)/($band_lo_center-$band_lo_end)]
		} elseif {($f >= $band_lo_center) && ($f <= $band_hi_center)} {
			set b $a
		} elseif {($f > $band_hi_center) && ($f < $band_hi_end)} {
			set b [expr $a*($f-$band_hi_center)/($band_hi_end-$band_hi_center)]
		} else {
			set b 0.0
		}
		if {!$bandpass} {set b [expr $a - $b]}
		append filtered_spectrum "$b $p "
		set band_power [expr $band_power + ($b * $b)/2.0]
		set f [expr $f + $info(f_step)]
	}

	# If show or replace, take the inverse transform. The filtered
	# values will be available to the calling procedure in a variable
	# of the same name.
	if {$show || $replace} {
		set filtered_values [lwdaq_fft $filtered_spectrum -inverse 1]
	}
	
	# If show, plot the filtered signal to the screen. If our  
	# frequency band does not include zero, we add the zero-frequency
	# component to every sample value so that the filtered signal 
	# will be super-imposed upon the unfiltered signal in the display.
	# If the usual display of the value versus time is disabled, this
	# inverse-transform will still be shown because we assert the
	# force_vt flag.
	if {$show} {
		if {$band_lo_center > 0} {
			set offset [lindex $info(spectrum) 0]
		} {
			set offset 0
		}
		set filtered_signal ""
		set timestamp 0
		foreach v $filtered_values {
			append filtered_signal "$timestamp [expr $show*$v + $offset] "
			incr timestamp
		}
		Neuroarchiver_plot_signal [expr $info(channel_num) + 32] $filtered_signal
		set info(force_vt) 1
	}
	
	# If replace, replace the existing info(values) string with the new
	# filtered values.
	if {$replace} {
		set info(values) $filtered_values
	}
	
	# Return the power.
	return $band_power
}

#
# Neuroarchiver_band_power is for use in processor scripts as a means of detecting
# events in a signal. The routine selects the frequency components in
# $info(spectrum) that lie between band_lo and band_hi Hertz (inclusive), adds the
# power of all components in this band, and returns the total. If show is set, the
# routine plots the filtered signal on the screen by taking the inverse transform
# of the selected frequency components. If replace is set, the routine calculates
# the inverse transform of the filtered signal, making it available to the calling
# routine in the info(values) variable. Note that the routine does not change,
# info(signal), which contains the reconstructed signal values and their timestamps,
# nor the spectrum of the signal. Only the info(values) string is replaced. By default, 
# the routine does not plot nor does it perform the inverse transform, both of which 
# take time and slow down processing. The show parameter, if not zero, is used to 
# scale the signal for display.
#
proc Neuroarchiver_band_power {band_lo band_hi {show 0} {replace 0}} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config

	# Check the inputs.
	foreach f "$band_lo $band_hi" {
		if {![string is double -strict $f]} {
			error "invalid frequency \"$f\""
		}
	}
	if {$band_lo > $band_hi} {
		error "cannot have band_lo_end > band_lo_center"
	}
	
	# Check the current spectrum.
	if {[llength $info(spectrum)] <= 1} {
		error "no spectrum exists to filter"
	}
	
	# We call Neuroarchiver_filter with sharp upper and lower edges to 
	# the pass band, and so obtain the power, plot the inverse, and prepare
	# the inverse if requested.
	return [Neuroarchiver_filter $band_lo $band_lo $band_hi $band_hi $show $replace]
}

#
# Neuroarchiver_band_amplitude calls Neuroarchiver_band_power and converts the
# power into a standard deviation of the signal, which is the root mean square
# amplitude.
#
proc Neuroarchiver_band_amplitude {band_lo band_hi {show 0} {replace 0}} {
	set power [Neuroarchiver_band_power $band_lo $band_hi $show $replace]
	if {[string is double $power]} {
		return [expr sqrt($power)]
	} {
		return $power
	}
}

#
# Neuroarchiver_multi_band_filter allows us to specify ranges of frequency
# to be included in the filtered signal. The routine returns the sum of the
# squares of the selected components. The "band_list" parameter is a list
# containing an even number of real-valued frequencies. Each pair of 
# frequencies is the lowest and highest frequency of a band. The lowest
# must be specified first. The bands may overlap. Any component in the 
# discrete fourier transform that lies within one or more of these bands
# will be included in the spectrum of the filtered signal. The band edges
# are themselves contained in the band, so a 1-4 Hz band will include 
# components of 1 Hz and 4 Hz. When "replace" is set, the routine calculates
# the inverse fourier transform of the selected components and replaces
# the original info(values) string with the filtered signal values. But 
# the info(signal) and info(spectrum) are not changed. If a processor
# is to change info(signal), it can replace all the sample values in 
# info(signal) with the sample values in info(values).
#
proc Neuroarchiver_multi_band_filter {{band_list ""} {show 0} {replace 0}} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config

	# Check the inputs.
	if {[llength $band_list] == 0} {
		error "no band frequencies specified"
	}
	if {[llength $band_list] % 2 != 0} {
		error "odd number of frequencies specified"
	}
	foreach {flo fhi} $band_list {
		if {![string is double -strict $flo]} {
			error "invalid frequency \"$flo\""
		}
		if {![string is double -strict $fhi]} {
			error "invalid frequency \"$fhi\""
		}
		if {$flo >= $fhi} {
			error "cannot have flo >= fhi"
		}
	}

	# Check the current spectrum.
	if {[llength $info(spectrum)] <= 1} {
		error "no spectrum exists to filter"
	}
	
	# Filter the current spectrum and calculate the total power.
	set filtered_spectrum ""
	set f 0
	set band_power 0.0
	foreach {a p} $info(spectrum) {
		set b 0
		foreach {flo fhi} $band_list {
			if {($f >= $flo) && ($f <= $fhi)} {
				set b $a
				break
			}
		}
		append filtered_spectrum "$b $p "
		set band_power [expr $band_power + ($b * $b)/2.0]
		set f [expr $f + $info(f_step)]
	}

	# If show or replace, take the inverse transform. The filtered
	# values will be available to the calling procedure in a variable
	# of the same name.
	if {$show || $replace} {
		set filtered_values [lwdaq_fft $filtered_spectrum -inverse 1]
	}
	
	# If show, plot the filtered signal to the screen. If our  
	# frequency band does not include zero, we add the zero-frequency
	# component to every sample value so that the filtered signal 
	# will be super-imposed upon the unfiltered signal in the display.
	if {$show} {
		if {[lindex $band_list 0] > 0} {
			set offset [lindex $info(spectrum) 0]
		} {
			set offset 0
		}
		set filtered_signal ""
		set timestamp 0
		foreach {v} $filtered_values {
			append filtered_signal "$timestamp [expr $show*$v + $offset] "
			incr timestamp
		}
		Neuroarchiver_plot_signal [expr $info(channel_num) + 32] $filtered_signal
	}
	
	# If replace, replace the existing info(values) string with the new
	# filtered values.
	if {$replace} {
		set info(values) $filtered_values
	}
	
	# Return the power.
	return $band_power
}

#
# Neuroarchiver_contiguous_band_power accepts a low and high frequency
# to define a range of frequencies to be analyzed, and then a number of
# contiguous bands into which to divide that range. It returns the power
# of the signal in each band in units of square counts.
#
proc Neuroarchiver_contiguous_band_power {flo fhi num} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config
	
	# Check inputs.
	if {![string is double -strict $flo]} {
		error "invalid frequency \"$flo\""
	}
	if {![string is double -strict $fhi]} {
		error "invalid frequency \"$fhi\""
	}
	if {$flo >= $fhi} {
		error "cannot have flo >= fhi"
	}
	if {![string is integer -strict $num]} {
		error "invalid number of bands \"$num\""
	}
	
	# Calculate band width.
	set width [expr 1.0*($fhi-$flo)/$num]

	# Go through spectrum and add powers to consecutive bands until
	# we have passed fhi or readed the end of the spectrum.
	set band_powers ""
	set f 0.0
	set pwr 0.0
	foreach {a p} $info(spectrum) {
		if {$f >= $flo + $width} {
			append band_powers "[format %.2f $pwr] "
			set pwr [expr ($a * $a)/2.0]
			set flo [expr $flo + $width]
			if {$flo >= $fhi} {break}
		} elseif {$f >= $flo} {
			set pwr [expr $pwr + ($a * $a)/2.0]
		}
		set f [expr $f + $info(f_step)]
	}

	return $band_powers
}

#
# Neuroarchiver_command handles the various control commands generated by
# the record and play buttons. It refers to the LWDAQ event queue
# with the global LWDAQ_Info(queue_events) variable. The event queue
# is LWDAQ's way of getting several independent processes to run at
# the same time without coming into conflict when they access shared
# variables and shared data acquisition hardware. The TCL interpreter
# does provide several forms of multi-tasking, but none of them are
# adequate for our purposes. This procedure controls the record
# process when $target == record and the play process when $target ==
# play.
#
proc Neuroarchiver_command {target action} {
	upvar #0 Neuroarchiver_info info
	global LWDAQ_Info

	set event_executing [string match "Neuroarchiver_$target\*" $LWDAQ_Info(current_event)]
	set event_pending 0
	foreach event $LWDAQ_Info(queue_events) {
		if {[string match "Neuroarchiver_$target\*" $event]} {
			set event_pending 1
		}
	}

	if {$action != $info($target\_control)} {
		if {!$event_executing} {
			set info($target\_control) $action
			if {!$event_pending} {
				if {$action != "Stop"} {
					LWDAQ_post Neuroarchiver_$target
				} {
					set info($target\_control) "Idle"
				}
			}
		} {
			if {$action != "Stop"} {
				LWDAQ_post [list Neuroarchiver_command $target $action]	
			} {
				set info($target\_control) $action
			}
		}
	}
	
	return "$target $action"
}

#
# Neuroarchiver_signal extracts or reconstructs the signal from one channel in the
# data image. It updates config(unaccepted_values), updates info(num_received)
# config(standing_values), sets info(frequency), sets info(num_messages), and
# returns the extracted or reconstructed signal. The signal is a sequence of
# messsages. Each message is a timestamp followed by a sample value. The timestamp
# is an integer number of clock ticks from the beginning of the playback interval.
# The timestamps and vsample alues alternate in the return string, separated by
# single spaces. The "extracted" signal is a list of messages that exist in the
# data image. The "reconstructed" signal is the extracted signal with substitute
# messages inserted and bad messages removed, so as to create a signal with
# info(frequency) messages. To perform extraction and reconstruction, the routine
# calls lwdaq_recorder from the lwdaq library. See the Recorder Manual for more
# information, and also the LWDAQ Command Reference. The routine takes a single
# parameter: a channel code, which is of the form "id" or "id:f" or "id:f" where
# "id" is the channel number and "f" is its nominal message rate per second. Once 
# the signal is reconstructed or extracted, we apply a glitch filter. The 
# glitch_threshold is the value set below the value versus time plot. When the 
# value is zero, the filter is disabled. Values greater than zero enable the filter, 
# so that any sample that stands out by more than the threshold from the surrounding 
# samples will be removed from the data and replaced by the previous valid sample.
# 
proc Neuroarchiver_signal {{channel_code ""}} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config
	
	# Set the loss to 100% in case we encounter an error, we want the processor
	# to know there's no signal.
	set info(loss) 100.0

	# We split the channel code into id and frequency.
	if {$channel_code == ""} {set channel_code $info(channel_code)}
	set parameters [split $channel_code ":"] 
	set id [lindex $parameters 0]
	if {![string is integer -strict $id]} {
		Neuroarchiver_print "ERROR: Invalid signal identifier \"$id\"."
		return "0 0"
	}
	set frequency [lindex $parameters 1]
	
	# We look up how many messages were received in the activity string.
	set num_received 0
	if {[regexp " $id:(\[0-9\]*)" " $info(channel_activity)" m a]} {
		set num_received $a 
	}
	set info(num_received) $num_received

	# We set the frequency if it is not already set. The default
	# frequency can be a single frequency or a list of frequencies,
	# the closest of which to the number of messages received is the
	# one that will be picked. If our search for a good frequency fails
	# because there are too many messages, we use the highest frequency
	# in the default list.
	if {![string is integer -strict $frequency]} {
		set fl [lsort -integer -decreasing [string trim $config(default_frequency)]]
		set frequency [lindex $fl 0]
		foreach f $fl {
			if {![string is integer -strict $f]} {
				Neuroarchiver_print "ERROR: Invalid frequency \"$f\" in default frequency list."
				return "0 0"	
			}
			if {$num_received < [expr $config(extra_fraction) \
				* $f * $info(play_interval_copy)]} {
				set frequency $f
			}
		}
	}
	if {$num_received > [expr $config(extra_fraction) \
			* $frequency * $info(play_interval_copy)]} {
		if {$info(f_alert_$id) != "Extra"} {
			Neuroarchiver_print \
				"WARNING: Extra samples on channel $id\
				at $config(play_time) s in [file tail $config(play_file)]."
			set info(f_alert_$id) "Extra"
		}
	} elseif {$num_received < [expr $config(loss_fraction) \
			* $frequency * $info(play_interval_copy)]} {
		set info(f_alert_$id) "Loss"
	} else {
		set info(f_alert_$id) "Okay"
	}
	set info(frequency) $frequency
	set info(f_$id) $frequency
	
	# We calculate the number of messages expected and the period
	# of the nominal sample rate in clock ticks.
	set num_expected [expr $frequency * $info(play_interval_copy)]
	set period [expr round(1.0 * $info(ticks_per_clock) \
		* $info(clocks_per_second) / $frequency)]
	
	# Determine the standing value of the signal from its previous interval. 
	# If the first message in the interval is missing, we will use this standing
	# value as a substitute. If there is no standing value, we extract the signal 
	# and use the first extracted value as our standing value. We add the new 
	# standing value to our standing value list.
	set standing_value_index [lsearch -index 0 $config(standing_values) $id]
	if {$standing_value_index < 0} {
		set signal [lwdaq_recorder $info(data_image) \
			"-payload $config(player_payload_length) \
				-size $info(data_size) \
				extract $id"]
		if {![LWDAQ_is_error_result $signal] && ([llength $signal] > 0)} {
			lappend config(standing_values) "$id [lindex $signal 1]"
		} {
			lappend config(standing_values) "$id 0"
		}
		set standing_value_index [expr [llength $config(standing_values)] - 1]
	}
	set standing_value [lindex $config(standing_values) $standing_value_index 1]
	
	# Obtain the unaccepted value list for this channel.
	set unaccepted_value_index [lsearch -index 0 $config(unaccepted_values) $id]
	if {$unaccepted_value_index < 0} {
		lappend config(unaccepted_values) "$id {}"
		set unaccepted_value_index [expr [llength $config(unaccepted_values)] - 1]
	}		
	set unaccepted_values [lindex $config(unaccepted_values) $unaccepted_value_index 1]
	
	# Reconstruct or extract the signal.	
	if {$config(enable_reconstruct)} {
		# Reconstruction involves extraction, then filling in missing
		# messages and eliminating bad messages. We may need to bring
		# one or more messages from the previous interval to add to the
		# start of this one, as a consequence of transmission scatter.
		# We have a standing value in case the first message is missing.
		# The reconstruction always returns the nominal number of messages.
		set signal [lwdaq_recorder $info(data_image) \
			"-payload $config(player_payload_length) \
			-size $info(data_size) \
			reconstruct $id $period $standing_value \
			$unaccepted_values"]
	} {
		# Extraction returns the messages with matching id in the recording.
		# There is no detection of duplicate of bad messages, no filling in
		# of missing messages. Thus we may get more or fewer messages than
		# the nominal number.
		set signal [lwdaq_recorder $info(data_image) \
			"-payload $config(player_payload_length) \
				-size $info(data_size) extract $id $period"]
	}
	if {[LWDAQ_is_error_result $signal]} {
		Neuroarchiver_print $signal
		set signal "0 0"
		return $signal
	}
	
	
	# Check the glitch threshold.
	if {![string is double -strict $config(glitch_threshold)]} {
		Neuroarchiver_print "WARNING: Invalid glitch threshold \"$config(glitch_threshold)\",\
			clearing to zero at $config(play_time) s [file tail $config(play_file)]."
		set config(glitch_threshold) 0
	}

	# Apply the glitch filter. We pass the negative of the absolute threshold value 
	# so as to instruct the glitch filter to add to the end of the returned values an
	# integer that is the number of glitches removed. In order to allow us to apply
	# the glitch filter to the longest possible interval, we temporarily configure 
	# the lwdaq library routines to return no digits after the decimal place.
	set num_glitches 0
	if {$config(glitch_threshold) > 0} {
		set saved_config [lwdaq_config]
		lwdaq_config -fsd 0
		set filtered_signal \
			[lwdaq glitch_filter_y [expr -abs($config(glitch_threshold))] $signal]
		eval lwdaq_config $saved_config
		if {![LWDAQ_is_error_result $filtered_signal]} {
			set num_glitches [lindex $filtered_signal end]
			set config(glitch_count) [expr $config(glitch_count) + $num_glitches]
			set signal [lrange $filtered_signal 0 end-1]
		} {
			Neuroarchiver_print $filtered_signal
		}
	}
	
	# Set the unaccepted values, standing values, and the result string. Print a message
	# if we are set to verbose output, summarizing the reconstruction.
	lset config(standing_values) $standing_value_index 1 [lindex $signal end]
	set results [lwdaq_image_results $info(data_image)]
	if {$config(enable_reconstruct)} {
		scan $results %d%d%d%d num_clocks num_messages num_bad num_missing
		lset config(unaccepted_values) $unaccepted_value_index 1 [lrange $results 4 end]
		set info(loss) [expr 100.0 * $num_missing / $num_expected]
		Neuroarchiver_print "Channel [format %2d $id],\
			[format %4.1f $info(loss)]% loss,\
			[format %4d $num_messages] reconstructed,\
			$num_bad bad,\
			removed $num_glitches glitches." verbose
	} {
		scan $results %d%d num_clocks num_messages
		lset config(unaccepted_values) $unaccepted_value_index 1 [lrange $results 4 end]
		set info(loss) [expr 100.0 - 100.0 * $num_messages / $num_expected]
		Neuroarchiver_print "Channel [format %2d $id],\
			[format %4.1f $info(loss)]% loss,\
			[format %4d $num_messages] extracted,\
			removed $num_glitches glitches." verbose
	}
	
	set info(num_messages) $num_messages

	return $signal
}

#
# Neuroarchiver_values extracts only the voltage values from the Neuroarchiver
# signal. If there are values missing, it adds values so that we have a power
# of two number of values to pass to the fft later. If there are too many values,
# we remove some until the number is correct.
#
proc Neuroarchiver_values {{signal ""}} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config

	if {$signal == ""} {set signal $info(signal)}

	set values ""
	foreach {t v} $info(signal) {append values "$v "}
	
	if {!$config(enable_reconstruct)} {
		set missing [expr round($info(frequency) * $info(play_interval_copy) \
			- [llength $values])]
		for {set m 1} {$m <= $missing} {incr m} {
			append values "[lindex $values end] "
		}
		for {set m $missing} {$m < 0} {incr m} {
			set values [lreplace $values end end]
		}
	}
		
	return $values
}

#
# Neuroarchiver_spectrum calculates the discrete Fourier transform of the
# signal. It returns the spectrum as a sequence of real numbers separated by
# spaces. Each pair of numbers is the amplitude and phase of a component in the
# transform. The k'th pair represent a sinusoidal component of frequency k/NT,
# where T is the sample period and N is the number of samples. We have k = 0 to
# (N/2)-1. We note that the playback interval has length NT. If the sample
# frequency is f_s, we have f_s = 1/T. For a f_s = 512 SPS and NT = 1 s, we have
# 256 pairs of numbers, k = 0 to 255, the k'th component having frequency k/1 =
# k Hz. Each pair consists of a amplitude, a, and a phase, p, and represents a
# single sinusoidal component of frequency k/NT whose value at sample n is equal
# to a*cos(2*pi*k*n/N - p). Here we have sample n occurring at time nT. The
# final pair is the amplitude and phase of the 255-Hz component. We have not yet
# accounted for the 256-Hz component, which is the highest frequency we can
# represent with 512 SPS. The k=0 pair is the first pair, and is an exception.
# The first number in the k=0 pair is the average value of the signal and the
# second number is the amplitude of the N/2'th component. This final component
# has phase 0 or pi, and we represent this phase with the sign of the amplitude,
# positive for phase 0 and negative for phase pi. If we pass an empty string to
# the routine, it uses info(values). The procedure calls the lwdaq_fft. You can
# read more about the Fourier transform routine in the LWDAQ Command Reference.
#
proc Neuroarchiver_spectrum {{values ""}} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config
	upvar result result
	
	if {$values == ""} {set values $info(values)}
	set info(f_step) [expr 1.0/$info(play_interval_copy)]	
	set spectrum [lwdaq_fft $values \
		-window [expr round([llength $values] * $config(window_fraction))]]
	if {[LWDAQ_is_error_result $spectrum]} {
		Neuroarchiver_print $spectrum
		set spectrum "0 0"
	}
	
	LWDAQ_support
	return $spectrum
}

#
# Neuroarchiver_overview displays an overview of a file's contents. This
# routine sets up the overview window and calles a plot routine to sample
# the archvie and plot the results. An Export button provides a way to
# export the graph data to disk for plotting in other programs.
#
proc Neuroarchiver_overview {{fn ""}} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config
	global LWDAQ_Info
	
	# Delete all unused overview images.
	foreach name [image names] {
		if {![image inuse $name]} {
			if {[string match "_neuroarchiver_ov_photo_*" $name]} {
				image delete $name
			}
		}
	}

	# Open a new toplevel window and a global configuration array.
	set i 1
	while {[winfo exists [set w $info(window)\.overview_$i]]} {incr i}
	upvar #0 Neuroarchiver_overview_$i ov_config
	toplevel $w
	set ov_config(w) $w

	# Use the play file if none is specified.
	if {$fn != ""} {
		set ov_config(fn) $fn
	} {
		set ov_config(fn) $config(play_file)
	}
	
	# Try to determine the start time of the archive.
	if {![regexp {([0-9]{10})\.ndf} [file tail $ov_config(fn)] match atime]} {
		set atime 0
	}
	set ov_config(atime) $atime
	
	# Set title of window.
	wm title $w "Overview of [file tail $ov_config(fn)], Start Time\
		[Neuroarchiver_datetime_convert $atime],\
		Neuroarchiver $info(version)"

	# Create a new photo in which to plot our graph.
	set ov_config(photo) [image create photo "_neuroarchiver_ov_photo_$i" \
		-width $info(overview_width) -height $info(overview_height)]

	# Initialize the display parameters.
	set ov_config(t_min) 0
	set ov_config(t_max) 0
	set ov_config(num_samples) $config(overview_num_samples)
	set ov_config(activity) ""
	set ov_config(select) $config(channel_select)
	set ov_config(status) "Idle"
	foreach v {v_range v_offset vt_mode} {
		set ov_config($v) $config($v)
	}
	
	# Create graph display.
	set f $w.graph
	frame $f -relief sunken
	pack $f -side top -fill x
	label $f.graph -image $ov_config(photo)
	pack $f.graph -side top	
	bind $f.graph <Double-Button-1> [list LWDAQ_post [list Neuroarchiver_overview_jump $i %x %y]]

	# Create value controls.	
	set f $w.value
	frame $f 
	pack $f -side top -fill x
	label $f.status -textvariable Neuroarchiver_overview_$i\(status) \
		-fg blue -bg white -width 10
	pack $f.status -side left -expand yes
	button $f.plot -text "Plot" -command \
		[list LWDAQ_post [list Neuroarchiver_overview_plot $i 0]]
	pack $f.plot -side left -expand yes
	button $f.export -text "Export" -command \
		[list LWDAQ_post [list Neuroarchiver_overview_plot $i 1]]
	pack $f.export -side left -expand yes
	foreach a "SP CP NP" {
		set b [string tolower $a]
		radiobutton $f.$b -variable Neuroarchiver_overview_$i\(vt_mode) \
			-text $a -value $a
		pack $f.$b -side left -expand no
	}
	foreach v {v_range v_offset num_samples} {
		label $f.l$v -text $v -width [string length $v]
		entry $f.e$v -textvariable Neuroarchiver_overview_$i\($v) -width 5
		pack $f.l$v $f.e$v -side left -expand yes
	}
	button $f.nf -text "NextNDF" -command \
		[list LWDAQ_post [list Neuroarchiver_overview_newndf $i +1]]
	button $f.pf -text "PrevNDF" -command \
		[list LWDAQ_post [list Neuroarchiver_overview_newndf $i -1]]
	pack $f.nf $f.pf -side left -expand yes

	# Create time controls
	set f $w.time
	frame $f 
	pack $f -side top -fill x
	label $f.lt_min -text "t_min"
	entry $f.et_min -textvariable Neuroarchiver_overview_$i\(t_min) -width 6
	label $f.lt_max -text "t_max"
	entry $f.et_max -textvariable Neuroarchiver_overview_$i\(t_max) -width 6
	label $f.lt_end -text "t_end"
	label $f.et_end -textvariable Neuroarchiver_overview_$i\(t_end) -width 6
	label $f.ls -text "Select:" -anchor e
	entry $f.es -textvariable Neuroarchiver_overview_$i\(select) -width 35
	pack $f.lt_min $f.et_min $f.lt_max $f.et_max \
		$f.lt_end $f.et_end $f.ls $f.es -side left -expand yes

	# Create activity display
	set f $w.activy
	frame $f
	pack $f -side top -fill x
	label $f.la -text "Points Used (id:qty):" -anchor e
	label $f.ea -textvariable Neuroarchiver_overview_$i\(activity) \
		-anchor w -width 70 -bg lightgray
	pack $f.la $f.ea -side left -expand yes
	
	LWDAQ_update 
	
	# Get the end time of the archive and check the file syntax.
	set ov_config(status) "Seeking"
	if {[catch {
		set ov_config(t_end) [Neuroarchiver_end_time $ov_config(fn)]
	} message]} {
		Neuroarchiver_print "ERROR: $message."
		return 0
	}
	set ov_config(t_max) $ov_config(t_end)
	set ov_config(status) "Idle"

	Neuroarchiver_overview_plot $i
	
	return 1
}

#
# Neuroarchiver_overview_jump jumps to the point in the overview archive that
# lies under the coordinates (x,y) in the overview graph. We call it after a
# mouse double-click in the graph. We round the jump-to time to the nearest
# second so that accompanying synchronous video will have a key frame to
# show at the start of the interval.
#
proc Neuroarchiver_overview_jump {i x y} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_overview_$i ov_config

	set ptime [expr round(1.0 * ($x - 2.0) / $info(overview_width) \
		* ($ov_config(t_max) - $ov_config(t_min)))]
	if {$ov_config(atime)>0} {
		Neuroarchiver_jump "$ov_config(atime) [format %.1f $ptime]\
			\"$ov_config(select)\" \"Overview Jump\"" 0
	} {
		Neuroarchiver_jump "[file tail $ov_config(fn)] [format %.1f $ptime]\
			\"$ov_config(select)\" \"Overview Jump\"" 0
	}
}

#
# Neuroarchiver_color returns a color code that is equal to the identifier
# it is passed, unless there is a color switch value in the color table.
#
proc Neuroarchiver_color {id} {
	upvar #0 Neuroarchiver_config config

	set index [lsearch -index 0 $config(color_table) $id]
	if {$index >= 0} {
		return [lindex $config(color_table) $index 1]
	} {
		return $id
	}
}

#
# Neuroarchiver_overview_plot selects an existing overview window and re-plots
# its graphs using the current display parameters. If the export parameter is 
# non-zero, the routine exports the selected channels each to a separate file
# named En.txt, where n is the channel number. Each line in the export file 
# will contain the archive time of a sample and the sample value. These files
# will be written to the directory that contains the overview archive.
#
proc Neuroarchiver_overview_plot {i {export 0}} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_overview_$i ov_config
	global LWDAQ_Info

	# Check the window and declare the overview array.
	if {![winfo exists $info(window)]} {return 0}
	if {![info exists ov_config]} {return 0}
	if {![winfo exists $ov_config(w)]} {return 0}
	set w $ov_config(w)
	if {$ov_config(status) != "Idle"} {return 0}

	# Check that the archive exists and is an ndf file. Extract the
	# data start address and data length.
	if {[catch {
		scan [LWDAQ_ndf_data_check $ov_config(fn)] %u%u data_start data_length
	} error_message]} {
		Neuroarchiver_print "ERROR: Checking archive, $error_message."
		return 0
	}
	
	# Draw a grid on the overview graph.
	lwdaq_graph "0 0" $info(overview_image) -fill 1 \
		-x_min 0 -x_max 1 -x_div $config(overview_t_div) \
		-y_min 0 -y_max 1 -y_div $config(v_div) \
		-color 1
	lwdaq_draw $info(overview_image) $ov_config(photo)
	set ov_config(activity) ""
	LWDAQ_update
	
	# Check the input parameters.
	if {$ov_config(t_min) < 0} {set ov_config(t_min) 0}
	if {$ov_config(num_samples) <= 1} {set ov_config(num_samples) 1}
	
	# Create an array of graphs, one for each possible channel.
	for {set id $info(min_id)} {$id <= $info(max_id)} {incr id} {
		set graph($id) ""
	}

	# Seek the clock message just before and just after the plot interval.
	set ov_config(status) "Seeking"
	LWDAQ_update
	scan [Neuroarchiver_seek_time $ov_config(fn) $ov_config(t_min)] \
		%f%u%f%u ov_config(t_min) index_min dummy1 dummy2
	scan [Neuroarchiver_seek_time $ov_config(fn) $ov_config(t_max)] \
		%f%u%f%u dummy1 dummy2 ov_config(t_max) index_max

	# Read num_samples messages from the archive at random locations.
	set ov_config(status) "Reading"
	set ave_step [expr 2.0 * ($index_max - $index_min) / $ov_config(num_samples)]
	set message_length [expr $info(core_message_length) + $config(player_payload_length)]
	set addr [expr $data_start + $message_length * $index_min]
	set addr_end [expr $data_start + $message_length * $index_max]
	set f [open $ov_config(fn) r]
	fconfigure $f -translation binary
	set samples ""
	while {$addr < $addr_end} {
		LWDAQ_support
		seek $f $addr
		binary scan [read $f $message_length] cSc id value timestamp
		lappend samples "[expr $id & 0xff] [expr $value & 0xffff]"
		set addr [expr $addr + $message_length * round(1 + ($ave_step-1)*rand())]
	}
	close $f
	
	# Go through the list of messages, calculating the time of each message
	# by interpolating between the times of existing clock messages. We assume
	# that less than one clock cycle period (that's 512 s) passes between clock 
	# messages so that we can keep time by looking at the clock message values.
	set ov_config(status) "Analyzing"
	LWDAQ_update
	set offset_time -1
	set lo_time $ov_config(t_min)
	set time_step 0
	set previous_clock_index 0
	set clock_cycles 0
	set previous_clock 0
	for {set sample_num 0} {$sample_num < [llength $samples]} {incr sample_num} {
		scan [lindex $samples $sample_num] %u%u id value
		if {$id == 0} {
			if {$value < $previous_clock} {incr clock_cycles}
			set previous_clock $value
			set lo_time [expr $info(clock_cycle_period) * $clock_cycles \
				+ (1.0 * $previous_clock / $info(clocks_per_second))]
			if {$offset_time < 0} {set offset_time $lo_time}
			set lo_time [expr $lo_time - $offset_time]
			set next_clock_sample_num [lsearch -start \
				[expr $sample_num + 1] -index 0 $samples 0]
			if {$next_clock_sample_num > 0} {
				set next_clock [lindex $samples $next_clock_sample_num 1]
				set hi_time [expr $clock_cycles * $info(clock_cycle_period) \
					+ (1.0 * $next_clock / $info(clocks_per_second)) - $offset_time]
				if {$next_clock < $previous_clock} {
					set hi_time [expr $hi_time + $info(clock_cycle_period)]
				}
				set time_step [expr ($hi_time - $lo_time) \
					/ ($next_clock_sample_num - $sample_num)]
			} {
				set hi_time [expr $ov_config(t_max) - $ov_config(t_min)]
				set time_step [expr ($hi_time - $lo_time) \
					/ ([llength $samples] - $sample_num)]
			}
			set previous_clock_index $sample_num
			set archive_time [expr $lo_time + $ov_config(t_min)]
		} {
			set archive_time [expr $lo_time \
				+ $time_step * ($sample_num - $previous_clock_index) \
				+ $ov_config(t_min)]
		}
		append graph($id) "[format %.3f $archive_time] $value "
	}	
	
	# Apply the glitch filter to the graphs of values and check their lengths.
	set saved_config [lwdaq_config]
	lwdaq_config -fsd $info(overview_fsd)
	for {set id $info(min_id)} {$id <= $info(max_id)} {incr id} {
		if {[string length $graph($id)] > $LWDAQ_Info(lwdaq_long_string_capacity)} {
			Neuroarchiver_print "ERROR: Too many points in overview of No$id."
			set graph($id) ""
			continue
		}
		set filtered_graph [lwdaq glitch_filter_y $config(glitch_threshold) $graph($id)]
		if {![LWDAQ_is_error_result $filtered_graph]} {
			set graph($id) $filtered_graph
		}
	}
	eval lwdaq_config $saved_config
	
	# Create the plot viewing ranges from the user parameters.
	if {$ov_config(vt_mode) == "CP"} {
		set v_min [expr - $ov_config(v_range) / 2 ]
		set v_max [expr + $ov_config(v_range) / 2]
		set ac 1
	} elseif {$ov_config(vt_mode) == "NP"} {
		set v_min 0
		set v_max 0
		set ac 0
	} else {
		set v_min $ov_config(v_offset)
		set v_max [expr $ov_config(v_offset) + $ov_config(v_range)]
		set ac 0
	}

	# Plot all graphs that have more than the activity threshold number of 
	# points in them.
	if {$export} {
		set ov_config(status) "Exporting"
	} {
		set ov_config(status) "Plotting"
	}
	set ov_config(activity) ""
	for {set id $info(min_id)} {$id <= $info(max_id)} {incr id} {
		if {[llength $graph($id)] / 2 < \
			[expr $config(overview_activity_fraction)\
			* $ov_config(num_samples)]} {continue}
		LWDAQ_support
		if {![winfo exists $w]} {return 0}
		append ov_config(activity) "$id:[expr [llength $graph($id)] / 2] "
		if {($ov_config(select) != "*") \
			&& ([lsearch $ov_config(select) "$id"] < 0) \
			&& ([lsearch $ov_config(select) "$id:\*"] < 0) } {continue}
		if {($ov_config(select) == "*") \
			&& ($id == 0)} {continue}
		lwdaq_graph $graph($id) $info(overview_image) \
			-x_min $ov_config(t_min) -x_max $ov_config(t_max) \
			-y_min $v_min -y_max $v_max \
			-color [Neuroarchiver_color $id] -ac_couple $ac 
		lwdaq_draw $info(overview_image) $ov_config(photo)
		if {$export} {
			set f [open [file join [file dirname $ov_config(fn)] E$id\.txt] w]
			foreach {at sv} $graph($id) {puts $f "$at $sv"}
			close $f
		}		
	}
	
	# Done.
	set ov_config(status) "Idle"
	return 1
}

#
# Neuroarchiver_overview_newndf finds the file that is
# the one $step places after the overview file in the 
# Player Directory Tree, switches the overview to the
# new file, and plots its contents.
#
proc Neuroarchiver_overview_newndf {i step} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_overview_$i ov_config

	# Set the status show we are searching for the requested file.
	set ov_config(status) "Searching"
	LWDAQ_update

	# We obtain a list of all NDF files in the play_dir directory tree. If
	# can't find the current file in the directory tree, we abort.
	set fl [LWDAQ_find_files $config(play_dir) *.ndf]
	set fl [LWDAQ_sort_files $fl]
	set index [lsearch $fl $ov_config(fn)]
	if {$index < 0} {
		Neuroarchiver_print "ERROR: In Overview, cannot find\
			\"[file tail $ov_config(fn)]\" in playback directory tree."
		set ov_config(status) "Idle"
		return 0
	}
	
	# We see if there is later file in the directory tree. If so,
	# switch to this file.
	set file_name [lindex $fl [expr $index + $step]]
	if {$file_name == ""} {
		Neuroarchiver_print "ERROR: Overview cannot step $step from\
			\"[file tail $ov_config(fn)]\" in Player Directory Tree."
		set ov_config(status) "Idle"
		return 0	
	}
	set ov_config(fn) $file_name
	
	# Try to determine the start time of the new archive.
	if {![regexp {([0-9]{10})\.ndf} [file tail $ov_config(fn)] match atime]} {
		set atime 0
	}
	set ov_config(atime) $atime

	# Determine the archive end time.
	set ov_config(t_end) [Neuroarchiver_end_time $ov_config(fn)]
	set ov_config(t_max) $ov_config(t_end)
	set ov_config(t_min) 0.0

	# Change the window title.
	wm title $ov_config(w) "Overview of [file tail $ov_config(fn)], Start Time\
		[Neuroarchiver_datetime_convert $atime],\
		Neuroarchiver $info(version)"
		
	# Plot the overview of the new archive.
	set ov_config(status) "Idle"
	Neuroarchiver_overview_plot $i

	# Clear all pending overview newndf events from the queue.
	LWDAQ_queue_clear "Neuroarchiver_overview_newndf*"
}

#
# Neuroclassifier allows us to view, jump to, and manipulate a list 
# of reference events with which new events may be compared for
# classification. The event classifier lists events like this:
#
# archive.ndf time channel event_type baseline_power m1 m2...
#
# It expects the Neuroarchiver's processor to produce characteristics
# lines in the same format, except the line can contain characteristics
# for multiple channels. The baseline power should be in units of kilo
# square ADC counts. The remaining characteristics are "metrics", which
# each indicated something about the shape of the interval signal, and
# which vary between 0 to 1, with 0.5 being roughly in the middle of 
# the expected range for recorded data. In particular, the Classifier
# assumes that a value of 0.5 or greater in the metric1 characteristic
# indicates an event worthy of classification has occurred. We reserve 
# three event type words for the processor to allocate to each interval
# before classification, "N" for "Normal", meaning no event has occurred,
# "U" for "Unclassified", meaning the event has not yet been compared to
# a set of reference events for classification, and "L" for "Loss", meaning
# reception is poor.
#
proc Neuroclassifier_open {} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config

	# Size of the map and its points.
	set info(classifier_map_size) 450
	set info(classifier_point_size) 10
	
	# Some internal variables.
	set info(classifier_index) 0
	set info(classifier_continue) 0
	catch {unset info(reprocessing_event_list)}

	# Signal identifier index in a reference event.
	set info(sii) 2 
	
	# Event type location, offset from signal identifier.
	set info(cto) 1 

	# Baseline power location, offset from signal identifier.
	set info(cbo) 2 

	# Open the classifier window.
	set w $info(classifier_window)
	if {[winfo exists $w]} {
		raise $w
		return 0
	}
	toplevel $w
	wm title $w "Event Classifier for Neuroarchiver $info(version)"
	
	# Create the classifier user interface.
	frame $w.controls1
	pack $w.controls1 -side top -fill x
	
	set f $w.controls1
	label $f.cv -text "0 Events" -width 15 -bg black -fg white
	set info(classification_label) $f.cv
	pack $f.cv -side left -expand yes

	label $f.rl -text "Match:" 
	label $f.rv -textvariable Neuroarchiver_info(classifier_match) -width 5 
	pack $f.rl $f.rv -side left -expand yes

	label $f.mrl -text "Limit:" 
	entry $f.mre -textvariable Neuroarchiver_config(classifier_match_limit) -width 5
	pack $f.mrl $f.mre -side left -expand yes

	label $f.etl -text "Threshold:" 
	entry $f.ete -textvariable Neuroarchiver_config(classifier_threshold) -width 5
	pack $f.etl $f.ete -side left -expand yes

	foreach a {Add Continue Stop Step Back Batch_Classification} {
		set b [string tolower $a]
		button $f.$b -text $a -command "Neuroclassifier_$b"
		pack $f.$b -side left -expand yes
	}

	frame $w.controls2
	pack $w.controls2 -side top -fill x
	set f $w.controls2
	label $f.yml -text "y:"
	set info(classifier_y_menu) [tk_optionMenu $f.ym \
		Neuroarchiver_config(classifier_y_metric) "none"]
	pack $f.yml $f.ym -side left -expand yes
	label $f.xml -text "x:"
	set info(classifier_x_menu) [tk_optionMenu $f.xm \
		Neuroarchiver_config(classifier_x_metric) "none"]
	pack $f.xml $f.xm -side left -expand yes

	checkbutton $f.handler -text "Handler" \
		-variable Neuroarchiver_config(enable_handler)
	pack $f.handler -side left -expand yes
	
	foreach a {Refresh Load Save Reprocess Compare} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post Neuroclassifier_$b"
		pack $f.$b -side left -expand yes
	}

	frame $w.data
	pack $w.data -side top -expand yes -fill both
	
	frame $w.data.metrics
	pack $w.data.metrics -side left
	
	set c [canvas $w.data.metrics.map \
		-height $info(classifier_map_size) \
		-width $info(classifier_map_size) \
		-bd 2 -relief sunken]
	set info(classifier_map) $c
	pack $c -side left -fill y
	
	frame $w.data.events
	pack $w.data.events -side left -expand yes -fill both
	
	set t [LWDAQ_text_widget $w.data.events 50 10 1 1]
	LWDAQ_enable_text_undo $t
	$t tag configure jumpbutton -background green
	$t tag configure changebutton -background orange
	$t tag bind "jumpbutton changebutton" <Enter> {%W configure -cursor arrow} 
	$t tag bind "jumpbutton changebutton" <Leave> {%W configure -cursor xterm} 
	set info(classifier_text) $t
	
	frame $w.controls3
	pack $w.controls3 -side top -fill x
	set info(classifier_enable_metric_frame) $w.controls3

	Neuroclassifier_display ""
}

#
# Neuroclassifier_sigmoidal takes a value greater than zero and returns a value
# between zero and one. It takes as parameters a center and an exponent for
# its sigmoidal function. The result is formatted to three decimal places.
#
proc Neuroclassifier_sigmoidal {x center exponent} {
	if {$x <= 0.001} {set x 0.001}
	return [format %.3f [expr 1.0 / (1.0 + pow($center/$x,$exponent))]]
}

#
# Neuroclassifier_plot takes an event and plots it at a point in the map
# given by the x and y metrics selected by the user. These metrics come from
# the characteristics provided with the event string. The color of the point
# on the map is given by the list of event types and colors in the Classifier
# types parameter. The relationship between the names of metrics and their
# location in the characteristics is given by the Classifier metrics 
# parameters. Point (0,0) is the lower-left corner of the map. Point (1,1)
# is the upper-right corner. The tag allows the routine to tag the point
# it plots. If the tag is "displayed", we plot the point as a white square
# with tag "displayed" and "event". Otherwise, the routine deletes all points
# with tag $tag and plots the new point with the event type color.
#
proc Neuroclassifier_plot {tag event} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info
	global LWDAQ_Info

	# Abort if running in no-graphics mode.
	if {![winfo exists $info(window)]} {return 0}
	if {![winfo exists $info(classifier_window)]} {return 0}

	set pointsize $info(classifier_point_size)
	set c $info(classifier_map)

	set x 0
	set y 0
	set metric_index [expr $info(sii)+$info(cbo)+1]
	foreach metric $config(classifier_metrics) {
		set m [lindex $event $metric_index]
		if {$m == ""} {break}
		if {[string match -nocase $metric $config(classifier_x_metric)]} {
			set x [expr $m * $info(classifier_map_size)]
		}
		if {[string match -nocase $metric $config(classifier_y_metric)]} {
			set y [expr $info(classifier_map_size) * (1 - $m)]
		}
		incr metric_index
	}
		
	set type [lindex $event [expr $info(sii)+$info(cto)]]
	set color white
	foreach {et fc} [string trim "$config(classifier_types) Unknown black"] {
		if {[string match -nocase $et $type]} {
			set color $fc
		}
	}

	if {$tag != "displayed"} {
		# For library events, we create a point with the color
		# corresponding to the type, and we set the point so that
		# clicking on it jumps to the event.
		$c delete $tag
		set point [$c create rectangle $x $y \
			[expr $x+$pointsize] [expr $y+$pointsize] \
			-fill $color -tag "event $tag"]
		$c bind $tag <Button> [list LWDAQ_post [list Neuroclassifier_jump $event]]
	} {
		# For displayed events, we plot a white point and we leave
		# it to the classifier processing routine to delete all
		# displayed points before arranging to plot the new set
		# of displayed points.
		set point [$c create rectangle $x $y \
			[expr $x+$pointsize] [expr $y+$pointsize] \
			-fill white -tag "event displayed"]
	}	
	
	# Set the classification label text and color.
	if {$color != "black"} {
		$info(classification_label) configure -text $type \
			-fg black -bg $color
	} {
		$info(classification_label) configure -text $type \
			-fg $color -bg white
	}

	return $point
}

#
# Neuroclassifier_event takes the file name, file time, and channel 
# number of an event and looks for it in the Classifier text window. 
# It returns the event as it appears in the text window, or returns 
# the event it was passed otherwise.
#
proc Neuroclassifier_event {event} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info

	if {![winfo exists $info(classifier_window)]} {return 0}
	set t $info(classifier_text)
	set index [$t search [lrange $event 0 $info(sii)] 1.0]
	if {$index != ""} {
		set event [$t get "$index" "$index lineend"]
	}
	return $event
}

#
# Neuroclassifier_select hilites and event in the text window.
#
proc Neuroclassifier_select {event} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info

	if {![winfo exists $info(classifier_window)]} {return 0}

	# We remove any hilites in the text window.
	set t $info(classifier_text)
	$t tag delete hilite

	# We locate the most up to date form of the event in the
	# text window. If we can't find the event in the text window,
	# we abort.
	set index [$t search [lrange $event 0 $info(sii)] 1.0]
	if {$index != ""} {
		set event [$t get "$index" "$index lineend"]
	} {
		Neuroarchiver_print "ERROR: Cannot find event \"[lrange $event 0 2]\"."
		return 0
	}

	# We hilite the event and move it into the visible area of the
	# text window.
	$t tag add hilite "$index" "$index lineend"
	$t tag configure hilite -background lightgreen
	$t see $index
}

#
# Neuroclassifier_jump jumps to an event. It selects the event in the Classifier
# window, then calls the Neuroarchiver's jump routine to navigate to the event.
#
proc Neuroclassifier_jump {event} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info

	if {![winfo exists $info(classifier_window)]} {return 0}

	Neuroclassifier_select $event
	Neuroarchiver_jump $event 0
}

#
# Neuroclassifier_change finds an event in the text window
# and changes its event type. It then re-plots the event in the map.
#
proc Neuroclassifier_change {event} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info

	if {![winfo exists $info(classifier_window)]} {return 0}

	# Find the event in the text window.
	set t $info(classifier_text)
	set index [$t search [lrange $event 0 $info(sii)] 1.0]
	
	if {$index != ""} {
		# Extract the event, delete the line, change the type
		# and insert the new event string into the text window.
		set event [$t get "$index" "$index lineend"]
		$t delete "$index" "$index lineend"
		set type [lindex $event [expr $info(sii)+$info(cto)]]
		set type_index [lsearch "$config(classifier_types) Unknown black" $type]
		if {$type_index > 1} {
			lset event [expr $info(sii)+$info(cto)]\
				[lindex "$config(classifier_types) Unknown black" $type_index-2]
		} {
			lset event [expr $info(sii)+$info(cto)]\
				[lindex "$config(classifier_types) Unknown black" end-1]
		}
		$t insert $index $event

		# Hilite the event in the text window.
		Neuroclassifier_select $event

		# Determine the event's index using the tag on its Go button,
		# and use this to re-plot the event in its new color.	
		set go_index [lindex [split $index .] 0]\.1
		set tags [$t tag names $go_index]
		if {[regexp {event_([0-9]+)} $tags tag event_index]} {
			Neuroclassifier_plot event_$event_index $event
		} 
	} {
		Neuroarchiver_print "ERROR: Cannot find event \"[lrange $event 0 $info(sii)]\"."
	}
}

#
# Neuroclassifier_add adds an event to the event list. If the event
# is empty, the routine composes the event from the displayed play
# interval, and so adds the displayed interval to the event list. In
# doing so, the routine also jumps to the interval so as to set the
# characteristics of the event. The index we pass to the routine tells 
# it how to tag the buttons in the event line.
#
proc Neuroclassifier_add {{index ""} {event ""}} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info

	if {![winfo exists $info(classifier_window)]} {return 0}

	if {$index == ""} {
		set index $info(classifier_index)
		incr info(classifier_index)
	}
	if {$event == ""} {
		set id [lindex $config(channel_select) 0]
		if {([llength $id]>1) || ($id == "*")} {
			raise $info(window)
			Neuroarchiver_print "ERROR: Select a single channel to add to the library."
			return ""
		}
		set event "[file tail $config(play_file)]\
			[Neuroarchiver_play_time_format \
				[expr $config(play_time) - $config(play_interval)]]\
			$id\
			Added"
		set jump 1
	} {
		set jump 0
	}
	
	set t $info(classifier_text)
	$t insert end " "
	$t tag bind event_$index <Button> [list LWDAQ_post [list Neuroclassifier_jump $event]]
	$t insert end "<J>" "event_$index jumpbutton"
	$t tag bind type_$index <Button> [list LWDAQ_post [list Neuroclassifier_change $event]]
	$t insert end "<C>" "type_$index changebutton"
	$t insert end " $event\n"
	$t see end
	
	if {$jump} {
		LWDAQ_post [list Neuroclassifier_jump $event]
	}

	return $event
}

#
# Neuroclassifier_metric_display sets up the x-y plot menus so they each contain
# all the metrics in the classifier_metrics list, and makes a checkbutton for each 
# metric to enable or disable the metric for classification.
#
proc Neuroclassifier_metric_display {} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info

	if {![winfo exists $info(classifier_window)]} {return 0}

	# Set up the x and y metric selection menues. Make sure the current 
	# value of the metric menu is one of those available. If not, set it
	# to the first available metric. If the metric list is empty, set
	# the menu selection to "none".
	foreach a {x y} {
		$info(classifier_$a\_menu) delete 0 end
		foreach b $config(classifier_metrics) {
			$info(classifier_$a\_menu) add command -label $b \
				-command "set Neuroarchiver_config(classifier_$a\_metric) $b;\
					Neuroclassifier_refresh"
		}
		if {[lsearch $config(classifier_metrics) $config(classifier_$a\_metric)] < 0} {
			set config(classifier_$a\_metric) [lindex $config(classifier_metrics) 0]
		}
		if {$config(classifier_$a\_metric) == ""} {
			set config(classifier_$a\_metric) "none"
		}
	}
	
	# Make a checkbutton for each available metric that will enable
	# it for classification.
	if {[llength $config(classifier_metrics)] > 0} {
		set f $info(classifier_enable_metric_frame)
		catch {destroy $f}
		frame $f 
		pack $f -side top -fill x
		if {[llength $config(classifier_metrics)] > 0} {
			label $f.title -text "Classification Metrics:"
			pack $f.title -side left -expand yes
			foreach m $config(classifier_metrics) {
				set mlc [string tolower $m]
				if {![info exists info(metric_enable_$mlc)]} {
					set info(metric_enable_$mlc) 1
				}
				checkbutton $f.$mlc \
					-variable Neuroarchiver_info(metric_enable_$mlc) \
					-text $m
				pack $f.$mlc -side left -expand yes
			}
		}
	}
}

#
# Neuroclassifier_display writes an entire event list to 
# the classifier text window and plots the events on the map.
#
proc Neuroclassifier_display {event_list} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info

	if {![winfo exists $info(classifier_window)]} {return 0}

	# Clear the text window and map.
	set t $info(classifier_text)
	set c $info(classifier_map)
	$t delete 1.0 end
	$c delete event
	
	# Plot grid lines in map.
	set b $info(classifier_map_size)
	set s [expr $b * 0.1]
	for {set a [expr $b + 4]} {$a >= 0.0} {set a [expr $a - $s]} {
		$c create line 0.0 $a $b $a -fill gray
		$c create line $a 0.0 $a $b -fill gray
	}
	$c create line 0.0 $b $b $b -fill gray
	$c create line $b 0.0 $b $b -fill gray
	
	# Print and plot the events in turn.
	set info(classifier_index) 1
	set info(classifier_display_control) "Run"
	foreach event $event_list {
		Neuroclassifier_add $info(classifier_index) $event
		Neuroclassifier_plot event_$info(classifier_index) $event
		incr info(classifier_index)
		LWDAQ_support
		if {$info(classifier_display_control) != "Run"} {
			return 0
		}
	}
	
	# Set up the metric enable buttons and the metric selection menus.
	Neuroclassifier_metric_display
	
	# Display the number of reference events in the classification
	# label.
	set num_events [llength $event_list]
	$info(classification_label) configure \
		-text "$num_events Events" -fg white -bg black

	# Return the number of events displayed.
	return $num_events
}

#
# Neuroclassifier_event_list extracts an event list from the text window.
#
proc Neuroclassifier_event_list {} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config

	set t $info(classifier_text)
	set contents [split [string trim [$t get 1.0 end]] \n]
	set event_list ""
	foreach event $contents {
		while {![string match -nocase "*.ndf" [lindex $event 0]]} {
			set event [lrange $event 1 end]
		}
		if {([llength $event] >= $info(sii)+$info(cbo))} {
			lappend event_list $event
		}
	}
	return $event_list
}

#
# Neuroclassifier_refresh extracts the event list from the text window,
# then calls the list command to re-write the text window and re-plot
# the map.
#
proc Neuroclassifier_refresh {} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info

	if {![winfo exists $info(classifier_window)]} {return 0}

	set event_list [Neuroclassifier_event_list]
	Neuroclassifier_display $event_list
	return [llength $event_list]
}

#
# Neuroclassifier_classify finds the event in a classifier library that
# is the best match to one with the metrics provided. The routine
# assumes the existence of a list of classifier events called 
# classifier_library in the scope of the calling routine. It returns
# the closest event in a string. It also sets the global classifier
# match parameter, which gives the distance of the closest library
# point. With setup set to 1, the routine sets up the lwdaq nearest
# neighbor routine by passing the classifier library metrics into the
# routine. Subsequent calls to the routine will use the previously
# established library.
#
proc Neuroclassifier_classify {metrics setup} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info
	upvar 1 classifier_library cl

	# If the classifier library in the calling routine is empty, abort.
	if {[llength $cl] == 0} {return ""}
	
	# Make a list of the indices of the enabled metrics within an event line. We
	# start with the power metric index, and we use the metric enable flags to
	# perform a selection.
	set index [expr $info(sii)+$info(cbo)+1]
	set index_list ""
	foreach m $config(classifier_metrics) {
		set mlc [string tolower $m]
		if {$info(metric_enable_$mlc)} {lappend index_list $index}
		incr index
	}
	
	# We extract the enabled metrics from the event we want to classify.
	set enabled_metrics ""
	foreach i $index_list {
		append enabled_metrics "[lindex $metrics [expr $i-$info(sii)-$info(cbo)-1]] "
	}

	# If we are to set up the nearest neighbor algorithm, we must compose a
	# classification library containing only the metrics we want to use for
	# the nearest neighbor distance calculation. If the nearest neighbor
	# routine has already been set up, we just pass the current event into
	# the routine.
	if {[catch {	
		if {$setup} {
			set nnl ""
			foreach c $cl {
				foreach i $index_list {
					append nnl "[lindex $c $i] "
				}
			}
			set index [lwdaq nearest_neighbor $enabled_metrics $nnl]
		} {
			set index [lwdaq nearest_neighbor $enabled_metrics]
		}
	} error_result]} {
		Neuroarchiver_print "ERROR: $error_result"
		return ""
	}
	
	if {![LWDAQ_is_error_result $index]} {
		set closest [lindex $cl [expr $index-1]]
	} {
		set closest 0
		Neuroarchiver_print $index
		Neuroarchiver_print "ERROR: The classified event is incorrectly formatted."
	}

	set distance 0.0
	foreach i $index_list {
		set z1 [lindex $metrics [expr $i-$info(sii)-$info(cbo)-1]]
		if {![string is double -strict $z1]} {
			Neuroarchiver_print "ERROR: Invalid metrics provided by processor."
			return $closest
		}
		set z2 [lindex $closest $i]
		if {![string is double -strict $z2]} {
			Neuroarchiver_print "ERROR: Invalid metrics provided by matching event."
			return $closest
		}
		set distance [expr $distance + ($z1-$z2)*($z1-$z2)]
	}
	set info(classifier_match) [format %.3f [expr sqrt($distance)]]

	return $closest
}

#
# Neuroclassifier_processing accepts a characteristics line as
# input. If there are mutliple channels recorded in this line, 
# the routine separates the characteristics of each channel and
# forms a list of events, one for each channel. It searches the 
# event library for each event, in case the event is a repeat of
# one that already exists in the library. If so, it hilites
# the event in the library and makes it visible in the text
# window. Otherwise, the routine checks to see if the event
# qualifies as unusual. The first metric should be greater than
# the classifier threshold. If the event is unusual, the
# routine finds the closest match to the event in the library
# and classifies the event as being of the same type. In either
# case, the routine plots the characteristics of the event
# upon the map. In the special case where we are re-processing
# the event libarary to obtain new metrics, the routine replaces
# the existing baseline power and metrics for each library event
# with the newly-calculated values from the processor.
#
proc Neuroclassifier_processing {characteristics} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info

	if {![winfo exists $info(classifier_window)]} {return 0}
	
	# We check to see if the processor has modified the metric list.
	# if so, we refresh the plot coordinate menus and the metric
	# enable buttons.
	if {$config(classifier_metrics) != $info(classifier_metrics_saved)} {
		Neuroclassifier_metric_display
		set info(classifier_metrics_saved) $config(classifier_metrics)
		if {[winfo exists $info(classifier_window)\.nbc]} {
			LWDAQ_print $info(classifier_window)\.nbc\.text \
				"WARNING: Batch Classifier metric buttons may no longer be valid."
		}
	}

	# We extract from the characteristics line the file name
	# and play time, then we make a list of separate intervals,
	# one for each channel. To do this, we assume that only the
	# channel numbers will be integers.
	scan $characteristics %s%f fn pt
	set idcs ""
	set idc ""
	foreach a [lrange $characteristics $info(sii) end] {
		if {[string is integer $a]} {
			if {$idc != ""} {lappend idcs $idc}
			set idc $a
		} {
			lappend idc $a
		}
	}
	lappend idcs $idc
	
	# We define the text and map widgets and delete all displayed
	# points in the map.
	set t $info(classifier_text)
	set c $info(classifier_map)	
	$c delete displayed
	$t tag delete hilite

	# We search for each interval in turn, looking through the text window.
	# Thus we have idc as the characteristics of each particular interval 
	# taken from the list idcs that we constructed above.
	foreach idc $idcs {

		# Extract the signal idenfier and look for the event in the library.
		set id [lindex $idc 0]
		set index [$t search "$fn $pt $id" 1.0]

		if {$index != ""} {
			# Get the library event from the text window.
			set event [$t get "$index" "$index lineend"]
			
			# If we are re-processing the library, we will replace the
			# old baseline power and metrics with the displayed values.
			if {[info exists info(reprocessing_event_list)]} {
				set event "[lrange $event 0 [expr $info(sii)+$info(cto)]]\
					[lrange $idc $info(cbo) end]"
				$t delete "$index" "$index lineend"
				$t insert $index $event
			}
			
			# If the event type is "Added" we assume we have just added it to
			# the library. We insert the displayed baseline power and metrics, 
			# and switch the type of the event to Unknown.
			if {[lindex $event [expr $info(sii)+$info(cto)]] == "Added"} {
				set event "[lrange $event 0 [expr $info(sii)+$info(cto)-1]]\
					Unknown\
					[lrange $idc $info(cbo) end]"
				$t delete "$index" "$index lineend"
				$t insert $index $event
			}

			# We have found the interval in the library, so we hilite
			# it and show it.
			$t tag add hilite "$index" "$index lineend"
			$t tag configure hilite -background lightgreen
			$t see $index
			
			# Because we have already identified the type of this event
			# by eye, and stored it as such in the event list, we can be
			# certain of its type. But even if we know the type, if the 
			# power metric is below the event threshold, we will call the
			# interval Normal, and we over-write its type in the event
			# string we will display.
			if {[lindex $idc [expr $info(cbo)+1]] >= $config(classifier_threshold)} {
				set type [lindex $event [expr $info(sii) + $info(cto)]]
			} {
				set type "Normal"
				set event [lreplace $event [expr $info(cbo)+1] [expr $info(cbo)+1] "Normal"]
			}
			
			# And the match distance is of course zero, and the closest
			# event it itself.
			set info(classifier_match) 0.0
			set closest $event
			
			# Plot the event as a white square.
			Neuroclassifier_plot displayed $event
		} {
			# We did not find the interval, so we check its threshold metric,
			# which is the one that marks the occurance of an event, to see
			# if the interval is normal, loss, or event. If it's an event, we
			# classify it by finding the closest match in the event list. 
			if {[lindex $idc [expr $info(cbo)+1]] >= $config(classifier_threshold)} {
				
				# If the event is a loss, we set the type to loss now, and avoid
				# performing any matching.
				if {[lindex $idc [expr $info(cbo)+1]] == 0.0} {
					set type "Loss"
				} {
				# If the event is not a loss, we are going to perform classification
				# using the library.
					set classifier_library [Neuroclassifier_event_list]
					set closest [Neuroclassifier_classify \
						[lrange $idc [expr $info(cbo)+1] end] 1]
						
					# A non-empty string for closest means a nearest match
					# was found. Otherwise the matching failed, perhaps because
					# the library itself is empty. We call the event Unknown if
					# the distance is greater than the match threshold. Otherwise
					# the event takes the same type as the closest match.
					if {$closest != ""} {
						if {$info(classifier_match) <= $config(classifier_match_limit)} {
							set type [lindex $closest [expr $info(sii)+$info(cto)]]
						} {
							set type "Unknown"
						}
						set index [$t search $closest 1.0]
						$t tag add hilite "$index" "$index lineend"
						$t tag configure hilite -background lightblue
						$t see $index
					} {
						set type "Unknown"
					}
				}
			} {
				# A low-power event is Normal only if there is sufficient signal 
				# reception to be sure that it has lower power. Otherwise it's a 
				# Loss.
				set closest ""
				if {[lindex $idc [expr $info(cbo)+1]] > 0.0} {
					set type "Normal"
				} {
					set type "Loss"
				}
			}

			# We plot the interval on the screen as a displayed point.
			Neuroclassifier_plot displayed \
				"$fn $pt $id $type [lrange $idc $info(cbo) end]"
		}
		
		# If we have defined an event handler script, we execute it now
		# at the local scope, so that the script has access to the variables
		# type, id, fn, pt, closest, event, and of course the info and config
		# arrays of the Neuroarchiver. We also provide support for a TCPIP
		# socket whose name will be stored in sock. In the event of an error
		# we close this socket, so that the handler script does not have to
		# worry about sockets being left open.
		set sock "sock0"
		if {$config(enable_handler) && ($info(handler_script) != "")} {
			if {[catch {eval $info(handler_script)} error_result]} {
				Neuroarchiver_print "ERROR: $error_result"
				LWDAQ_socket_close $sock
			}
		}

		# If we are continuing only to the next unusual event, rather than
		# playing indefinitely, we check to see if this event was unsusual,
		# or if it is unknown and the power metric is zero, and if so we 
		# stop playback.
		if {$info(classifier_continue) \
			&& ((($type != "Normal") && ($config(classifier_threshold) > 0.0))\
				|| (($type == "Unknown") && ($config(classifier_threshold) == 0.0))) \
			&& ($type != "Loss")} {
			Neuroarchiver_command "play" "Stop"
			set info(classifier_continue) 0
		}
	}
}

#
# Neuroclassifier_reprocess goes through the events in the text window and
# re-processes each of them so as to replace the old characteristics with 
# those generated by the Neuroarchiver's current processor script. Before
# reprocessing, the routine sorts the events by event type, so that in the 
# new library, all events of the same type will be grouped together.
#
proc Neuroclassifier_reprocess {{index 0}} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info

	if {![winfo exists $info(classifier_window)]} {
		catch {unset info(reprocessing_event_list)}
		return 0
	}
	if {$index == 0} {
		if {[info exists info(reprocessing_event_list)]} {return 0}
		set info(reprocessing_event_list) [Neuroclassifier_event_list]
	} 
	if {($index > 0) && ![info exists info(reprocessing_event_list)]} {
		return 0
	}
	if {$index >= [llength $info(reprocessing_event_list)]} {
		set event_list [lsort -increasing \
			-index [expr $info(sii)+$info(cto)] \
			[Neuroclassifier_event_list]]
		Neuroclassifier_display $event_list
		catch {unset info(reprocessing_event_list)}
		return 0
	}
	if {![info exists info(reprocessing_event_list)]} {return 0}
	Neuroclassifier_jump [lindex $info(reprocessing_event_list) $index]
	if {$index < [llength $info(reprocessing_event_list)]} {
		LWDAQ_post [list Neuroclassifier_reprocess [incr index]]
	}
	return 1
}

#
# Neuroclassifier_compare goes through the event list and measures the
# distance between every pair of events of differing types, and compares
# this distance to the match limit. If the distance is less, the Classifier
# prints the pair of events to the Neuroarchiver text window as a pair of
# potentially-contradictory events.
#
proc Neuroclassifier_compare {} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info

	# Make a list of the indices of the enabled metrics within a string containing
	# all the metrics, in the order they are listed in the classifier metrics names
	# string.
	set index 0
	set index_list [list]
	set metric_list [list]
	foreach m $config(classifier_metrics) {
		set mlc [string tolower $m]
		if {$info(metric_enable_$mlc)} {
			lappend index_list $index
			lappend metric_list $m
		}
		incr index
	}
	
	# Notify the user that comparison has begun.
	Neuroarchiver_print "\nComparison of Library Events" purple
	Neuroarchiver_print "Threshold: $config(classifier_threshold),\
		limit: $config(classifier_match_limit),\
		metrics: $metric_list\." purple

	# Check that at least one metric is enabled.
	if {[llength $index_list] == 0} {
		Neuroarchiver_print "ERROR: No events metrics enabled for comparison.\n"
		return 0
	}
	
	# Make a copy of the event library.
	set events [Neuroclassifier_event_list]
	if {[llength $events] == 0} {
		Neuroarchiver_print "ERROR: No events in library to compare.\n"
		return 0
	}
	
	# Go through the event list, comparing each event to every other event.
	catch {$info(classification_label) configure -text "Comparing" -fg white -bg black}
	set count 0
	while {[llength $events] > 1} {
		set event1 [lindex $events 0]
		set e1 $event1
		foreach v {fn pt id et bp} {
			set $v\_1 [lindex $e1 0]
			set e1 [lrange $e1 1 end]
		}
		set events [lrange $events 1 end]
		if {[lindex $e1 0] < $config(classifier_threshold)} {continue}
		foreach event2 $events {
			set e2 $event2
			foreach v {fn pt id et bp} {
				set $v\_2 [lindex $e2 0]
				set e2 [lrange $e2 1 end]
			}
			if {[lindex $e2 0] < $config(classifier_threshold)} {continue}
			if {($fn_1 == $fn_2) && ($pt_1 == $pt_2) && ($id_1 == $id_2)} {
				if {$et_1 == $et_2} {
					Neuroarchiver_print "Duplicates:"
					Neuroarchiver_print_event $event1
					Neuroarchiver_print_event $event2
				} {
					Neuroarchiver_print "Contradiction:"
					Neuroarchiver_print_event $event1
					Neuroarchiver_print_event $event2
				}
			} {
				if {$et_1 != $et_2} {
					if {[llength $e1]*[llength $e2] > 0} {
						if {[llength $e1] == [llength $e2]} {
							set separation 0
							foreach i $index_list {
								set separation [expr $separation + \
									pow([lindex $e1 $i]-[lindex $e2 $i],2)]
							}
							set separation [expr sqrt(1.0*$separation)]
							if {$separation < $config(classifier_match_limit)} {
								incr count
								Neuroarchiver_print \
									"Overlap (Separation = [format %.3f $separation]):"
								Neuroarchiver_print_event $event1
								Neuroarchiver_print_event $event2
							}
						} {
							Neuroarchiver_print "Mismatch:"
							Neuroarchiver_print_event $event1
							Neuroarchiver_print_event $event2
						}
					}
				}
			}
			LWDAQ_support
		}
	}
	catch {$info(classification_label) configure -text "Idle" -fg white -bg black}
	Neuroarchiver_print "Done with $count Overlaps." purple
}

#
# Neuroclassifier_stop puts a stop to all reprocessing events by unsetting
# the event list, and stops playback as well.
#
proc Neuroclassifier_stop {} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info

	catch {unset info(reprocessing_event_list)}
	set info(classifier_display_control) "Stop"
	Neuroarchiver_command "play" "Stop"
}

proc Neuroclassifier_step {} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info

	if {!$config(enable_processing)} {
		Neuroarchiver_print "ERROR: Processing is disabled."
		return
	}
	set info(classifier_continue) 0
	Neuroarchiver_command "play" "Step"
}

proc Neuroclassifier_back {} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info

	if {!$config(enable_processing)} {
		Neuroarchiver_print "ERROR: Processing is disabled."
		return
	}
	set info(classifier_continue) 0
	Neuroarchiver_command "play" "Back"
}

proc Neuroclassifier_continue {} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info

	if {!$config(enable_processing)} {
		Neuroarchiver_print "ERROR: Processing is disabled."
		return
	}
	set info(classifier_continue) 1
	Neuroarchiver_command "play" "Play"
}

#
# Neuroclassifier_batch_classification selects one or more characteristics 
# files and goes through them comparing each interval to the classifier
# events. It does this for the channels specified in the channel select
# string in the main Neuroarchiver window. The result is a text window
# containing a list of events that we can cut and paste into a file.
#
proc Neuroclassifier_batch_classification {{state "Start"}} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info
	global nbc

	set w $info(classifier_window)\.nbc

	if {$state == "Start"} {
		if {[winfo exists $w]} {
			raise $w
			return 0
		}
		toplevel $w
		wm title $w "Batch Classification for Neuroarchiver $info(version)"
		catch {unset nbc}
		
		set f [frame $w.f1]
		pack $f -side top -fill x
		
		label $f.fl -text "Input:" -fg blue
		button $f.scf -text "Pick Files" -command {
			set fn [LWDAQ_get_file_name 1]
			if {$fn != ""} {
				set nbc(fnl) $fn
				LWDAQ_print $nbc(t) "Picked [llength $nbc(fnl)] input files."
			}
		}
		button $f.scd -text "Apply Pattern to Directory" -command {
			set dn [LWDAQ_get_dir_name]
			if {$dn != ""} {
				set nbc(fnl) [LWDAQ_find_files $dn $nbc(dmp)]
				LWDAQ_print $nbc(t) "Found [llength $nbc(fnl)] input files\
					matching \"$nbc(dmp)\" in \"[file tail $dn]\"."
			}
		}
		set nbc(dmp) "*.txt"
		label $f.lmatch -text "Pattern:"
		entry $f.ematch -textvariable nbc(dmp)
		pack $f.fl $f.scf $f.scd $f.lmatch $f.ematch -side left -expand yes

		label $f.ofl -text "Output:" -fg blue
		set nbc(ofn) [file join $config(play_dir) "Events.txt"]
		button $f.sof -text "Specify File" -command {
			set fn [LWDAQ_put_file_name [file tail $nbc(ofn)]]
			if {$fn != ""} {set nbc(ofn) $fn}
		}
		pack $f.ofl $f.sof -side left -expand yes
		label $f.tl -text "Threshold:" -fg blue
		entry $f.te -textvariable Neuroarchiver_config(classifier_threshold) \
			-width 6
		pack $f.te $f.tl -side right	
		
		set f [frame $w.f2]
		pack $f -side top -fill x
		label $f.cl -text "Controls:" -fg blue
		set nbc(run) 0
		button $f.go -text "Batch Classify" -command {
			LWDAQ_post [list Neuroclassifier_batch_classification "Classify"]
		}
		button $f.stop -text "Stop" -command {
			set nbc(run) 0
		}
		set nbc(all_types) "$config(classifier_types) Unknown black"
		button $f.allt -text "All Types" -command {
			foreach {type color} $nbc(all_types) {
				set nbc($type) 1
			}
		}
		button $f.not -text "No Types" -command {
			foreach {type color} $nbc(all_types) {
				set nbc($type) 0
			}
		}
		pack $f.cl $f.go $f.stop $f.allt $f.not -side left -expand yes
		label $f.ssl -text "Channels Numbers:"
		set nbc(channel_select) "1 2 3 4 5 6 7 8 9 10 11 12 13 14"
		entry $f.sse -textvariable nbc(channel_select) -width 35
		pack $f.ssl $f.sse -side left
		label $f.ll -text "Limit:" -fg blue
		entry $f.le -textvariable Neuroarchiver_config(classifier_match_limit) \
			-width 6
		pack $f.le $f.ll -side right
				
		set f [frame $w.types]
		pack $f -side top -fill x
		label $f.tl -text "Types:" -fg blue
		pack $f.tl -side left
		foreach {type color} $nbc(all_types) {
			set b [string tolower $type]
			set nbc($type) 0
			checkbutton $f.$b -variable nbc($type) -text $type
			pack $f.$b -side left
		}
		set nbc(exclusive) 0
		checkbutton $f.exclusive -variable nbc(exclusive) \
			-text "Exclusive" -fg blue
		pack $f.exclusive -side right
		set nbc(show_loss) 0
		checkbutton $f.sl -variable nbc(show_loss) \
			-text "Loss" -fg darkgreen
		pack $f.sl -side right
		
		set nbc(t) [LWDAQ_text_widget $w 110 20 1 1]
		LWDAQ_enable_text_undo $nbc(t)

		set f [frame $w.metrics]
		pack $f -side top -fill x
		label $f.tl -text "Metrics:" -fg blue
		pack $f.tl -side left
		foreach m $config(classifier_metrics) {
			set mlc [string tolower $m]
			if {![info exists info(metric_enable_$mlc)]} {
				set info(metric_enable_$mlc) 1
			}
			checkbutton $f.$mlc \
				-variable Neuroarchiver_info(metric_enable_$mlc) \
				-text $m
			pack $f.$mlc -side left -expand yes
		}
	}
	
	if {$state == "Classify"} {
		if {$nbc(run)} {return 0}
		
		if {![info exists nbc(fnl)]} {
			LWDAQ_print $nbc(t) "ERROR: Select input files."
			return 0
		}
		if {![info exists nbc(ofn)]} {
			LWDAQ_print $nbc(t) "ERROR: Specify output files."
			return 0
		}
		set entire_classifier_library [Neuroclassifier_event_list]
		set classifier_library [list]
		set selected_types ""
		if {$nbc(exclusive)} {
			foreach {type color} $nbc(all_types) {
				if {$nbc($type)} {
					append selected_types "$type "
				}
			}
		}
		foreach c $entire_classifier_library {
			set selected 0
			if {$selected_types == ""} {
				set selected 1
			} {
				foreach et $selected_types {
					if {[lsearch $c $et] >= 0} {set selected 1}
				}
			}
			if {$selected} {
				lappend classifier_library $c
			}
		}
		if {[llength $classifier_library] < 1} {
			LWDAQ_print $nbc(t) "ERROR: No library events exist or are selected."
			return 0
		}
		
		set nbc(run) 1
		set nbc(setup) 1

		LWDAQ_print $nbc(t) "Start Classification" purple
		set metrics_start [expr $info(cbo)+1]
		set metrics_end [expr $info(cbo)+[llength $config(classifier_metrics)]]
		set match_count 0
		set event_count 0
		set total_interval_count 0
		set total_loss_count 0

		if {[catch {set of [open $nbc(ofn) w]} error_result]} {
			LWDAQ_print $nbc(t) "ERROR: Cannot open file \"$nbc(ofn)\"."
			return 0
		}
		LWDAQ_print $nbc(t) "Opened \"$nbc(ofn)\" for output."
		
		foreach fn [lsort -dictionary $nbc(fnl)] {
			# Read in the characteristics of the first file.
			LWDAQ_print -nonewline $nbc(t) "[file tail $fn] "
			LWDAQ_update
			set f [open $fn r]
			set characteristics [string trim [read $f]]
			close $f

			# Check to see if the output file has the correct form for 
			# automatic output file naming. This form is M, a ten-digit 
			# unsigned integer, an underscore, a string, and finally the
			# extension .txt. If the event file has this format, we check 
			# if the characteristics file also has this format. If so, we 
			# construct the new event file name by replacing the old event 
			# file's timestamp with the new characteristics file timestamp.
			# We close the old event file and open a new one.
			if {[regexp {M[0-9]{10}_(.*?)\.txt} $nbc(ofn) match efs]} {
				if {[regexp {M([0-9]{10})_.*?\.txt} $fn match ts]} {
					set nbc(ofn) [file join [file dirname $nbc(ofn)] M$ts\_$efs\.txt]
					close $of
					set of [open $nbc(ofn) w]
				}
			}
						
			# We are going to count events of each selected type for each selected
			# signal in this file, so we define variables for these counts. We
			# will count intervals and loss intervals individually also.
			for {set id $info(min_id)} {$id <= $info(max_id)} {incr id} {
				if 	{[lsearch $nbc(channel_select) $id] >= 0} {
					set nbc(en_$id) 1
					set loss_count_$id 0
					set count_$id 0
					foreach {type color} $nbc(all_types) {
						if {[info exists nbc($type)] && $nbc($type)} {
							set match_count_$id\_$type 0
						}
					}
				} {
					set nbc(en_$id) 0
				}
			}
			
			# We will count the number of intervals in the file as well.
			set file_interval_count 0

			# For each characteristics line, we check to see if the interval
			# is an event, and if so, what kind of event. We check for loss
			# and new events.
			foreach c [split $characteristics \n] { 
				if {!$nbc(run) || ![winfo exists $w]} {
					LWDAQ_print $nbc(t) "Aborted\n" purple
					close $of
					return 0
				}
				incr file_interval_count
				set archive [lindex $c 0]
				set play_time [lindex $c 1]
				set c [lrange $c 2 end]
				while {[llength $c] > 0} {
					set id [lindex $c 0]
					if {![string is integer -strict $id]} {
						LWDAQ_print $nbc(t) ""
						LWDAQ_print $nbc(t) "ERROR: Invalid characteristics in \"[file tail $fn]\"."
						close $of
						set nbc(run) 0
						return 0
					}
					incr count_$id
					if {$nbc(en_$id)} {
						incr total_interval_count
						if {[lindex $c $metrics_start] > $config(classifier_threshold)} {
							incr event_count
							set baseline_pwr [lindex $c $info(cbo)]
							set metrics [lrange $c $metrics_start $metrics_end]
							set closest [Neuroclassifier_classify $metrics $nbc(setup)]
							set nbc(setup) 0
							if {$info(classifier_match) <= $config(classifier_match_limit)} {						
								set type [lindex $closest [expr $info(sii)+$info(cto)]]
							} {
								set type "Unknown"
							}
							set event "$archive $play_time $id $type $baseline_pwr $metrics"
							if {[info exists nbc($type)] && $nbc($type)} {
								puts $of $event
								incr match_count
								incr match_count_$id\_$type
							}
						}
						if {[lindex $c $metrics_start] == 0.0} {
							incr loss_count_$id
							incr total_loss_count
						}
					}
					set c [lrange $c [expr $metrics_end+1] end]
				}
				LWDAQ_support
			}
			
			# We complete the single line we began with the file name above, and record
			# the event counts for each selected channel and selected event type.
			for {set id $info(min_id)} {$id <= $info(max_id)} {incr id} {
				if {$nbc(en_$id)} {
					LWDAQ_print -nonewline $nbc(t) "$id " purple
					foreach {type color} $nbc(all_types) {
						if {[info exists nbc($type)] && $nbc($type)} {
							LWDAQ_print -nonewline $nbc(t) "[set match_count_$id\_$type] "
						}
					}
					if {$nbc(show_loss)} {
						LWDAQ_print -nonewline $nbc(t) \
							"[set loss_count_$id] [set count_$id] " darkgreen
					}
				}
			}
			LWDAQ_print $nbc(t)
		}
		close $of

		LWDAQ_print $nbc(t) "Total of $total_interval_count intervals,\
			$total_loss_count with signal loss,\
			$event_count above threshold,\
			$match_count matched types."
		LWDAQ_print $nbc(t) "Done." purple
		set nbc(run) 0
	}
}

#
# Neuroclassifier_save saves the events listed in the Classifier test
# window to a file, and refreshes the text window and map. If no file
# is passed to the routine, it opens a file browser.
#
proc Neuroclassifier_save {{name ""}} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info

	if {$name == ""} {set name [LWDAQ_put_file_name "Event_Library.txt"]}
	if {$name == ""} {return ""}
	
	set event_list [Neuroclassifier_event_list] 
	set f [open $name w]
	foreach event $event_list {puts $f "$event"}
	close $f
}

#
# Neuroclassifier_load reads an event list from a text file into the
# Classifier's text window. If no file is passed to the routine, it opens a file
# browser.
#
proc Neuroclassifier_load {{name ""}} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info
	global LWDAQ_Info

	if {($config(classifier_library) != "") \
		&& [file exists [file dirname $config(classifier_library)]]} {
		set LWDAQ_Info(working_dir) [file dirname $config(classifier_library)]
	}
	if {$name == ""} {set name [LWDAQ_get_file_name]}
	if {$name == ""} {return ""}
	if {![file exists $name]} {
		Neuroarchiver_print "ERROR: Cannot find \"[file tail $name]\"."
		return ""
	}

	set f [open $name r]
	set event_list [split [string trim [read $f]] \n]
	close $f
	
	set config(classifier_library) $name
	
	Neuroclassifier_display $event_list
}

#
# Neurotracker_extract calculates the position of a transmitter over an array of
# detector coils and returns the position as a sequency of x-y coordinates. The routine
# relies upon a prior call to lwdaq_recorder filling a list of power measurements that
# correspond to some device we want to locate. This list exists in the lwdaq library
# global variable space, but not in the LWDAQ TclTk variable space. The indices allow the 
# lwdaq_locator routine to find the message payloads in the data image that correspond
# to the device.
#
proc Neurotracker_extract {} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config

	# Determine the number of detectors.
	set num_detectors [expr [llength $config(tracker_coordinates)]/2]
	
	# If the playload length matches the number of detector coils, we 
	# calculate the location of the transmitter.
	if {($config(player_payload_length) == $num_detectors + 1)} {
		if {$info(signal) != "0 0"} {
			set track [lwdaq_locator $info(data_image) \
				$config(tracker_coordinates) \
				-payload $config(player_payload_length) \
				-scale $config(tracker_scale) \
				-extent $config(tracker_extent) \
				-percentile $config(tracker_percentile) \
				-slices $config(tracker_slices) \
				-background $config(tracker_background)]
		} {
			set track "$config(tracker_background) 0.0 0.0 0.0"
		}
			
		# Check for errors.
		if {[LWDAQ_is_error_result $track]} {
			Neuroarchiver_print $track
			return ""
		}
		
		# Extract the tracker powers and detemrine the maximum power.
		set info(tracker_powers) [lrange $track 0 [expr $num_detectors - 1]]
		set max_power 0.0
		foreach p $info(tracker_powers) {
			if {$p > $max_power} {
				set max_power $p
			}
		}
		
		# Check to see if we have a tracker history for this device. If not
		# create an empty history.
		if {![info exists info(tracker_history_$info(channel_num))]} {
			set info(tracker_history_$info(channel_num)) ""
		}
		
		# We extract the newly-calculated tracker position. If we have excessive 
		# signal loss, as defined by the tracker_loss parameter, or if the maximum 
		# coil power is insufficient, as defined by the tracker power threshold,
		# we ignore this calculation and use the previous tracker position.
		if {($info(loss)/100.0 < (1-$config(loss_fraction))) \
				&& ($max_power >= $config(tracker_threshold))} {
			set info(tracker_x) [lindex $track $num_detectors]
			set info(tracker_y) [lindex $track [expr $num_detectors + 1]]
		} {
			if {$info(tracker_history_$info(channel_num)) != ""} {
				set info(tracker_x) [lindex $info(tracker_history_$info(channel_num)) 0]
				set info(tracker_y) [lindex $info(tracker_history_$info(channel_num)) 1]
			} {
				set info(tracker_x) 0.0
				set info(tracker_y) 0.0
			}
		}
		
		# Push the new positions into the history. This history is what we use when we
		# plot the latest position on the screen. The tracker_x and tracker_y variables
		# are for processors.
		set info(tracker_history_$info(channel_num)) "$info(tracker_x) $info(tracker_y)\
			[lrange $info(tracker_history_$info(channel_num)) 0 1]"
			
		# In verbose mode, we print out the tracker powers.
		Neuroarchiver_print "Tracker: $info(tracker_powers)\
			$info(tracker_x) $info(tracker_y) [lindex $track end]" verbose	
			
		# Return a flag that says we did something.
		return 1
	} {
		# Return a flag that says we did nothing
		return 0
	}
}

#
# Neurotracker_open opens the tracker window and creates the graphical images and
# photos required to plot the tracks.
#
proc Neurotracker_open {} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config
	global LWDAQ_Info
	
	# Abort if we don't have graphics.
	if {!$info(gui)} {return 0}

	# Open the tracker window, unless it exists already.
	set w $info(tracker_window)
	if {[winfo exists $w]} {
		raise $w
		return ""
	}
	toplevel $w
	wm title $w "Neurotracker for Neuroarchiver $info(version)"	
	
	# Create configuration fields.
	set f [frame $w.config]
	pack $f -side top -fill x
	foreach a {scale extent threshold slices} {
		label $f.l$a -text $a
		entry $f.e$a -textvariable Neuroarchiver_config(tracker_$a) -width 4
		pack $f.l$a $f.e$a -side left -expand yes
	}
	label $f.lp -text "persistence"
	tk_optionMenu $f.mp \
		Neuroarchiver_config(tracker_persistence) \
		None Path Mark
	pack $f.lp $f.mp -side left -expand yes
	checkbutton $f.sdp -text "Coils" \
		-variable Neuroarchiver_config(tracker_show_coils)
	pack $f.sdp -side left -expand yes
	
	# Create control buttons.
	set f [frame $w.control]
	pack $f -side top -fill x
	foreach a {Play Step Stop Repeat Back} {
		set b [string tolower $a]
		button $f.$b -text $a -command "Neuroarchiver_command play $a"
		pack $f.$b -side left -expand yes
	}
	button $f.clear -text Clear -command Neurotracker_clear
	pack $f.clear -side left -expand yes
	label $f.li -text "Time (s):"
	entry $f.ei -textvariable Neuroarchiver_config(play_time) -width 8
	pack $f.li $f.ei -side left -expand yes
	
	# Create the map photo and canvass widget.
	set bd $info(tracker_image_border_pixels)
   	set info(tracker_photo) [image create photo "_neurotracker_photo_" \
   		-width $info(tracker_width) \
   		-height $info(tracker_height)]
	set f [frame $w.graph -relief groove -border 4]
	pack $f -side top -fill x
	set info(tracker_plot) [canvas $f.track \
		-height [expr $info(tracker_height) + 2*$bd] \
		-width [expr $info(tracker_width) + 2*$bd]]
	pack $info(tracker_plot) -side top
	$info(tracker_plot) create image $bd $bd -anchor nw -image $info(tracker_photo)

	# Create the map image.
	set info(tracker_image) "_neurotracker_image_"
	lwdaq_image_destroy $info(tracker_image)
	lwdaq_image_create -width $info(tracker_width) \
		-height $info(tracker_height) \
		-name $info(tracker_image)
		
	# Draw empty graph with grid.
	Neurotracker_clear
	
	return $w
}

#
# Neurotracker_fresh_graphs prepares for tracking of available channels. When
# graphics are avaialable, the routine also clears the overlay of the 
# tracker plot and draws the grid.
#
proc Neurotracker_fresh_graphs {} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config
	global LWDAQ_Info	

	# Find the detector coil range.
	set x_min 0
	set x_max $x_min
	set y_min [lindex $config(tracker_coordinates) 1]
	set y_max $y_min
	foreach {x y} $config(tracker_coordinates) {
		if {$x > $x_max} {set x_max $x}
		if {$x < $x_min} {set x_min $x}
		if {$y > $y_max} {set y_max $y}
		if {$y < $y_min} {set y_min $y}
	}
	set bd $info(tracker_range_border)
	set x_min [expr $x_min - $bd]
	set y_min [expr $y_min - $bd]
	set x_max [expr $x_max + $bd]
	set y_max [expr $y_max + $bd]
	set info(tracker_range) "$x_min $x_max $y_min $y_max"

	# Return now if the tracker window is unavailable.
	if {![winfo exists $info(tracker_window)]} {return 1}
	
	# Clear canvass widget.
	$info(tracker_plot) delete location
	$info(tracker_plot) delete power

	# Clear the overlay unless we are keeping a history.
	if {$config(tracker_persistence) == "None"} {
		lwdaq_graph "0 0" $info(tracker_image) -fill 1
	}

	# Mark the coil locations.
	foreach {x y} $config(tracker_coordinates) {
		lwdaq_graph "$x $y_min $x $y_max" $info(tracker_image) \
			-x_min $x_min -x_max $x_max -x_div 0 \
			-y_min $y_min -y_max $y_max -y_div 0 \
			-color 11
		lwdaq_graph "$x_min $y $x_max $y" $info(tracker_image) \
			-x_min $x_min -x_max $x_max -x_div 0 \
			-y_min $y_min -y_max $y_max -y_div 0 \
			-color 11
	}
	
	return 1
}

#
# Neurotracker_plot plots the locus of transmitter position in the tracker
# window.
#
proc Neurotracker_plot {{color ""} {locations ""}} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config
	global LWDAQ_Info	

	# Abort if running in no-gui mode or window does not exist.
	if {!$info(gui)} {return 0}
	if {![winfo exists $info(tracker_window)]} {return 0}
	
	# Set colors and the source of the location values.
	if {$color == ""} {set color [Neuroarchiver_color $info(channel_num)]}
	if {$locations == ""} {set locations $info(tracker_history_$info(channel_num))}
	
	# Extract the current location from the location history.
	if {[llength $locations] > 1} {
		set tracker_x [lindex $locations 0]
		set tracker_y [lindex $locations 1]
	} {
		set tracker_x 0
		set tracker_y 0
	}
	
	# Find the range of x and y values we must cover.
	scan $info(tracker_range) %f%f%f%f x_min x_max y_min y_max
	
	# Plot the locations in the tracker image.
	if {$config(tracker_persistence) == "Path"} {
		lwdaq_graph $locations $info(tracker_image) \
			-y_min $y_min -y_max $y_max -x_min $x_min -x_max $x_max -color $color
	}

	# Make a mark at the current location.
	if {$config(tracker_persistence) == "Mark"} {
		set x $tracker_x
		set y $tracker_y
		set w $config(tracker_mark_cm)
		lwdaq_graph "[expr $x-$w] [expr $y-$w] [expr $x-$w] [expr $y+$w] \
			[expr $x+$w] [expr $y+$w] [expr $x+$w] [expr $y-$w] [expr $x-$w] [expr $y-$w]" \
			$info(tracker_image) \
			-y_min $y_min -y_max $y_max -x_min $x_min -x_max $x_max -color $color
	}

	# Determine border and color.
	set bd $info(tracker_image_border_pixels)
	set tkc [lwdaq tkcolor $color]

	# Mark the coil powers.
	if {$config(tracker_show_coils)} {
		set min_p 255
		set max_p 0
		foreach p $info(tracker_powers) {
			if {$p > $max_p} {set max_p $p}
			if {$p < $min_p} {set min_p $p}
		}
		for {set i 0} {$i < [llength $info(tracker_powers)]} {incr i} {
			set coil_x [lindex $config(tracker_coordinates) [expr 2*$i]]
			set coil_y [lindex $config(tracker_coordinates) [expr 2*$i+1]]
			set coil_p [lindex $info(tracker_powers) [expr $i]]
			set x [expr round(1.0*($coil_x-$x_min)*$info(tracker_width) \
				/($x_max-$x_min)) + $bd]
			set y [expr round($info(tracker_height) \
				-1.0*($coil_y-$y_min)*$info(tracker_height) \
				/($y_max-$y_min)) + $bd]
			if {$min_p < $max_p} {
				set a [expr round(255.0*($coil_p-$min_p)/($max_p-$min_p))]
			} {
				set a 0
			}
			if {$a>255} {set a 255}
			set a [format %02x $a]
			set pw 10
			$info(tracker_plot) create oval \
				[expr $x-$pw] [expr $y-$pw] \
				[expr $x+$pw] [expr $y+$pw] \
				-outline $tkc -fill "#$a$a$a" -tag power
		}
	}

	# Place a mark on the display to show averge position.
	set x [expr round(1.0*($tracker_x-$x_min)*$info(tracker_width) \
		/($x_max-$x_min)) + $bd]
	set y [expr round($info(tracker_height) \
		-1.0*($tracker_y-$y_min)*$info(tracker_height) \
		/($y_max-$y_min)) + $bd]
	set pw 4
	$info(tracker_plot) create oval \
		[expr $x-$pw] [expr $y-$pw] \
		[expr $x+$pw] [expr $y+$pw] \
		-outline $tkc -fill $tkc -tag location		

	# Detect errors.
	if {[lwdaq_error_string] != ""} {Neuroarchiver_print [lwdaq_error_string]}
	LWDAQ_support
	return 1
}

#
# Neurotracker_draw_graphs draws the traker graphs in the tracker window.
#
proc Neurotracker_draw_graphs {} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config
	global LWDAQ_Info	

	# Abort if running in no-gui mode.
	if {!$info(gui)} {return 0}
	if {![winfo exists $info(tracker_window)]} {return 0}
	
	lwdaq_draw $info(tracker_image) $info(tracker_photo)
	return 1
}

#
# Neurotracker_clear clears the display and the history.
#
proc Neurotracker_clear {} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config

	set names [array names info]
	foreach a $names {
		if {[string match "tracker_history_*" $a]} {
			set info($a) ""
		}
	}
	set saved $config(tracker_persistence)
	set config(tracker_persistence) "None"
	Neurotracker_fresh_graphs
	set config(tracker_persistence) $saved
	Neurotracker_draw_graphs
}

#
# Neuroarchiver_datetime creates the Playtime Clock panel, or raises it to the top 
# for viewing if it already exists.
#
proc Neuroarchiver_datetime {} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config

	# Open the clock window.
	set w $info(datetime_panel)
	if {[winfo exists $w]} {
		raise $w
		return 0
	}
	toplevel $w
	wm title $w "Player Date and Time"

	label $w.pl -text "Archive Play Time" -fg blue -width 20
	label $w.plc -textvariable Neuroarchiver_info(datetime_play_time)
	button $w.pli -text "Insert" -command {
		set Neuroarchiver_config(datetime_jump_to) $Neuroarchiver_info(datetime_play_time)
	}
	label $w.al -text "Archive Start Time" -fg blue
	label $w.alc -textvariable Neuroarchiver_info(datetime_start_time)
	button $w.ali -text "Insert" -command {
		set Neuroarchiver_config(datetime_jump_to) $Neuroarchiver_info(datetime_start_time)
	}
	button $w.jl -text "Jump to Time" -command [list LWDAQ_post \
		[list Neuroarchiver_datetime_jump]] -fg blue
	entry $w.jlc -textvariable Neuroarchiver_config(datetime_jump_to) -width 20
	button $w.jli -text "Now" -command {
		set Neuroarchiver_config(datetime_jump_to) [Neuroarchiver_datetime_convert [clock seconds]]
	}
	
	grid $w.pl $w.plc $w.pli -sticky news
	grid $w.al $w.alc $w.ali -sticky news
	grid $w.jl $w.jlc $w.jli -sticky news

	Neuroarchiver_datetime_update
}

#
# Neuroarchiver_exporter_open creates the Export Panel, or raises it to the top 
# for viewing if it already exists.
#
proc Neuroarchiver_exporter_open {} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config

	# Open the export panel.
	set w $info(export_panel)
	if {[winfo exists $w]} {
		raise $w
		return 0
	}
	toplevel $w
	wm title $w "Exporter Panel"

	set f [frame $w.limits]
	pack $f -side top -fill x
	
	label $f.sl -text "Export Start Time:" -anchor w -fg green 
	label $f.slv -textvariable Neuroarchiver_config(export_start) -anchor w
	label $f.stl -text "Set To:" -anchor w -fg green
	button $f.ssi -text "Interval Start" -command {
		set Neuroarchiver_config(export_start) [Neuroarchiver_datetime_convert \
			[expr [Neuroarchiver_datetime_convert \
				$Neuroarchiver_info(datetime_start_time)] \
				+ round($Neuroarchiver_info(t_min)) ]]
		LWDAQ_print $Neuroarchiver_info(export_text) \
			"Set export start $Neuroarchiver_info(t_min) s\
				in archive [file tail $Neuroarchiver_config(play_file)],\
				duration $Neuroarchiver_config(export_duration) s."
	}
	button $f.ssa -text "Archive Start" -command {
		set Neuroarchiver_config(export_start) \
			$Neuroarchiver_info(datetime_start_time)
		LWDAQ_print $Neuroarchiver_info(export_text) \
			"Export start at 0 s in archive\
				[file tail $Neuroarchiver_config(play_file)],\
				duration $Neuroarchiver_config(export_duration) s."
	}
	label $f.dl -text "Duration (s):" -anchor w -fg green 
	entry $f.dlv -textvariable Neuroarchiver_config(export_duration) -width 6
	label $f.ql -text "Repetitions:" -anchor w -fg green
	entry $f.qlv -textvariable Neuroarchiver_config(export_reps) -width 3
	pack $f.sl $f.slv $f.stl $f.ssi $f.ssa $f.dl $f.dlv $f.ql $f.qlv -side left -expand yes 
	
	set f [frame $w.select]
	pack $f -side top -fill x
	label $f.lchannels -text "Select (ID:SPS):" -anchor w -fg green
	entry $f.echannels -textvariable Neuroarchiver_config(channel_select) -width 70
	pack $f.lchannels $f.echannels -side left -expand yes
	button $f.auto -text "Autofill" -command {
		set Neuroarchiver_config(channel_select) "*"
		LWDAQ_post Neuroarchiver_play "Step"
		LWDAQ_post Neuroarchiver_exporter_autofill
	}
	checkbutton $f.ve -variable Neuroarchiver_config(export_video) \
		-text "Export Video" -fg green
	pack $f.auto $f.ve -side left -expand yes
	
	set f [frame $w.control]
	pack $f -side top -fill x
	label $f.state -textvariable Neuroarchiver_info(export_state) -fg blue -width 10
	button $f.export -text "Start Export" -command "LWDAQ_post Neuroarchiver_export"
	button $f.stop -text "Stop Export" -command {Neuroarchiver_export "Stop"}
	button $f.dir -text "Pick Export Dir" -command {
		set ndir [LWDAQ_get_dir_name]
		if {($ndir != "") && ([file exists $ndir])} {
			set Neuroarchiver_config(export_dir) $ndir
			LWDAQ_print $Neuroarchiver_info(export_text) \
				"Set export directory to $Neuroarchiver_config(export_dir)."
		}
	}
	pack $f.state $f.export $f.stop $f.dir -side left -expand yes
	label $f.fl -text "Format:" -fg green
	pack $f.fl -side left -expand yes
	foreach a "TXT BIN" {
		set b [string tolower $a]
		radiobutton $f.$b -variable Neuroarchiver_config(export_format) \
			-text $a -value $a
		pack $f.$b -side left -expand yes
	}
	button $f.help -text "Help" -command "LWDAQ_url_open $info(export_help_url)"
	pack $f.help -side left -expand yes
	
	set info(export_text) [LWDAQ_text_widget $w 60 25 1 1]
	
	# Initialize the export start time to the start of the current
	# playback archive.
	set config(export_start) $info(datetime_start_time)	
}

#
# Neuroarchiver_exporter_autofill fills the channel select field with the Neuroarchiver's
# best guess as to all the channels that are active in the most recently-played 
# interval.
#
proc Neuroarchiver_exporter_autofill {} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config

	set autofill ""
	for {set id $info(min_id)} {$id <= $info(max_id)} {incr id} {
		if {$info(f_alert_$id) == "Okay"} {
			append autofill "$id\:[set info(f_$id)] "
		}		
	}
	if {$autofill == ""} {
		LWDAQ_print $info(export_text) "Autofill found no active channels.\
			Setting channel select to \"*\". Play one interval and try again."
		set config(channel_select) "*"
		return "FAIL"
	}
	set config(channel_select) [string trim $autofill]
	return "SUCCESS"
}

#
# Neuroarchiver_export manages the exporting of both recorded signals to text files
# and video to a concatinated video file. 
#
proc Neuroarchiver_export {{cmd "Start"}} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config
	
	if {$cmd == "Stop"} {
		if {$info(export_state) != "Idle"} {
			LWDAQ_print $info(export_text) "Aborting export at\
				$config(play_time) s in archive\
				[file tail $config(play_file)]."
		}
		Neuroarchiver_command play "Stop"
		foreach pid $info(export_epl) {
			LWDAQ_process_stop $pid
		}
		set info(export_state) "Idle"
		return "SUCCESS"
	}

	if {$cmd == "Start"} {
		# Check the current state of the exporter.
		if {$info(export_state) != "Idle"} {
			LWDAQ_print $info(export_text) "WARNING: Exporter already started,\
				press stop before starting again."
			return "ERROR"
		}
		set info(export_state) "Start"
		set info(export_run_start) [clock seconds]			
		
		# Calculate Unix start and end times.
		set info(export_start_s) [Neuroarchiver_datetime_convert $config(export_start)]
		set info(export_end_s) [expr $info(export_start_s) + $config(export_duration)]
		LWDAQ_print $info(export_text) "\nStarting export of $config(export_duration) s\
			from time $config(export_start)." purple
		LWDAQ_print $info(export_text) "Start absolute time $info(export_start_s) s,\
			end absolute time $info(export_end_s) s."
		LWDAQ_print $info(export_text) \
			"Start archive time $info(t_min) s in archive [file tail $config(play_file)]."
		LWDAQ_print $info(export_text) "Export directory $config(export_dir)."
	
		# Check the channel select string and clean up existing export files.
		set config(channel_select) [string trim $config(channel_select)]
		foreach channel $config(channel_select) {
			if {$channel == "*"} {
				LWDAQ_print $info(export_text) \
					"ERROR: Cannot use wildcard channel select, aborting export."
				LWDAQ_post "Neuroarchiver_export Stop"
				return "FAIL"
			}
			set id [lindex [split $channel :] 0]		
			if {![string is integer -strict $id] \
					|| ($id < $info(clock_id)) \
					|| ($id > $info(max_id))} {
				LWDAQ_print $info(export_text) \
					"ERROR: Invalid channel id \"$id\", aborting export."
				LWDAQ_post "Neuroarchiver_export Stop"
				return "FAIL"
			}
			set sps [lindex [split $channel :] 1]
			if {$sps == ""} {
				LWDAQ_print $info(export_text) \
					"ERROR: No sample rate specified for channel $id, aborting export."
				LWDAQ_post "Neuroarchiver_export Stop"
				return "FAIL"
			}
			if {[lsearch "16 32 64 128 256 512 1024 2048 4096" $sps] < 0} {
				LWDAQ_print $info(export_text) \
					"ERROR: Invalid sample rate \"$sps\", aborting export."
				LWDAQ_post "Neuroarchiver_export Stop"
				return "FAIL"
			}
			if {$config(export_format) == "TXT"} {
				set ext "txt"
			} elseif {$config(export_format) == "BIN"} {
				set ext "bin"
			} else {
				LWDAQ_print $info(export_text) \
					"ERROR: Invalid output format \"config(export_format)\",\
						aborting export."
				LWDAQ_post "Neuroarchiver_export Stop"
				return "FAIL"
			}
			set efn [file join $config(export_dir) "E$info(export_start_s)\_$id\.$ext"]
			LWDAQ_print $info(export_text) "Exporting channel $id at $sps SPS to $efn."
			if {[file exists $efn]} {
				LWDAQ_print $info(export_text) "Deleting existing file\
					[file tail $efn] in export directory."
				file delete $efn
			}
		}
		
		# Stop stray left-over processes, then clear the process list and the
		# video file list.
		foreach pid $info(export_epl) {
			LWDAQ_process_stop $pid
		}
		set info(export_vfl) [list]
		set info(export_epl) [list]

		# Start the one or two extractions we may need to perform on video files
		# to get the start and end segments aligned with the start and end
		# export times. Make a list of the segments we want to concatinate
		# together later.
		if {$config(export_video)} {
			LWDAQ_print $info(export_text) "Looking for video files in\
				$config(video_dir)."
			set vt $info(export_start_s)
			while {$vt < $info(export_end_s)} {
				set vfi [Neuroarchiver_video_action "Seek" $vt 0]
				if {$vfi == ""} {
					LWDAQ_print $info(export_text) "ERROR: Cannot find video for $vt s,\
						aborting export."
					LWDAQ_post "Neuroarchiver_export Stop"
					return "FAIL"
				}
				scan $vfi %s%d%f vfn vsk vlen
				if {$info(export_end_s) - $vt > round($vlen - $vsk)} {
					set vdur [expr round($vlen - $vsk)]
				} {
					set vdur [expr $info(export_end_s) - $vt]
				}
				if {$vdur <= 0} {
					LWDAQ_print $info(export_text) "ERROR: Internal problem\
						vdur=$vdur vsk=$vsk vlen=$vlen\
						vt=$vt end_s=$info(export_end_s)\
						vf=[file tail $vfn], aborting export."
					LWDAQ_post "Neuroarchiver_export Stop"
					return "FAIL"
				}

				if {$vdur < round($vlen)} {
					cd $config(export_dir)
					set nvfn [file join $config(export_dir) V$vt\.mp4]
					if {[file exists $nvfn]} {
						LWDAQ_print $info(export_text) "Deleting existing file\
							[file tail $nvfn] in export directory."				
						file delete $nvfn
					}
					if {$vsk > 0} {
						LWDAQ_print $info(export_text) "Will include final $vdur s of\
							[file tail $vfn] in export video."
					} {
						LWDAQ_print $info(export_text) "Will include first $vdur s of\
							[file tail $vfn] in export video."
					}
					set pid [exec $info(ffmpeg) -nostdin -loglevel error \
						-ss $vsk -t $vdur -i [file nativename $vfn] \
						[file nativename $nvfn] > export_log.txt &]
					lappend info(export_epl) $pid
					LWDAQ_print $info(export_text) "Process $pid is copying these\
						$vdur s to [file tail $nvfn] in export directory."
					lappend info(export_vfl) $nvfn
				} {
					LWDAQ_print $info(export_text) "Will include all\
						[format %.2f $vlen] s of [file tail $vfn] in export video."	
					lappend info(export_vfl) $vfn
				}			
				set vt [expr $vt + $vdur]
				LWDAQ_support
			}
			LWDAQ_print $info(export_text) "Video file list complete,\
				copying start and end segments in background."
		}
	
		LWDAQ_print $info(export_text) "Starting export of $config(export_duration) s\
			of recorded signal from NDF archives."
		if {$config(video_enable)} {
			LWDAQ_print $info(export_text) "WARNING: Disabling video playback to\
				accelerate export of recorded signal."
			set config(video_enable) 0
		}
		if {$config(enable_vt)} {
			LWDAQ_print $info(export_text) "SUGGESTION: Exporting is faster\
				if you disable the Value vs. Time plot in the Player."
		}
		if {$config(enable_af)} {
			LWDAQ_print $info(export_text) "SUGGESTION: Exporting is faster\
				if you disable the Amplitude vs. Frequency plot in the Player."
		}
		if {$config(play_interval) != $info(optimal_export_interval)} {
			LWDAQ_print $info(export_text) "SUGGESTION: Exporting is faster\
				with an 8-s interval in the Player."
		}
		set info(export_state) "Play"	
		set jump_outcome [Neuroarchiver_jump \
			"$info(export_start_s) 0 ? \"Starting export of $config(export_duration) s.\""]
		if {[LWDAQ_is_error_result $jump_outcome]} {
			LWDAQ_print $info(export_text) $jump_outcome
			LWDAQ_post "Neuroarchiver_export Stop"
			return "FAIL"
		}
		Neuroarchiver_command play "Play"

		return "SUCCESS"
	}

	if {$cmd == "Play"} {	
		# Check the current state of the exporter is "Play", or else we won't play.
		if {$info(export_state) != "Play"} {
			return "SUCCESS"
		}
		
		# If we have arrived at the end of the export interval, stop. Right now,
		# the clocks value for the play time is that of the start of the interval
		# for which this routine has been called for export. 
		set play_datetime [Neuroarchiver_datetime_convert $info(datetime_play_time)]
		if {$play_datetime >= $info(export_end_s)} {
			Neuroarchiver_print "Stopping playback because export job is done."
			LWDAQ_print $info(export_text) "Export of $config(export_duration) s\
				of recorded signal complete."
			set info(play_control) "Stop"

			# If there are no video files to deal with, stop.
			if {[llength $info(export_vfl)] == 0} {
				LWDAQ_print $info(export_text) "Export complete in\
					[expr [clock seconds] - $info(export_run_start)] s." purple
				set info(export_state) "Wait"
				LWDAQ_post "Neuroarchiver_export Repeat" 
			} {
				set info(export_state) "Wait"
				LWDAQ_post "Neuroarchiver_export Video"
				LWDAQ_print $info(export_text) "Waiting for video extractions to complete."
			}
			return "SUCCESS"
		}
	
		# Write the signal to disk.
		if {$config(export_format) == "TXT"} {
			set fn [file join $config(export_dir) "E$info(export_start_s)\_$info(channel_num)\.txt"]
			set export_string ""
			foreach {timestamp value} $info(signal) {
			  append export_string "$value\n"
			}
			set f [open $fn a]
			puts -nonewline $f $export_string
			close $f
		} elseif {$config(export_format) == "BIN"} {
			set fn [file join $config(export_dir) "E$info(export_start_s)\_$info(channel_num)\.bin"]
			set export_bytes ""
			foreach {timestamp value} $info(signal) {
			  append export_bytes [binary format S $value]
			}
			set f [open $fn a]
			fconfigure $f -translation binary
			puts -nonewline $f $export_bytes
			close $f
		}
		
		return "SUCCESS"
	}
	
	if {$cmd == "Video"} {
		# Check to see if video processes are still running, and if they are, keep
		# waiting until they do complete.
		if {$info(export_state) == "Wait"} {
			foreach pid $info(export_epl) {
				if {[LWDAQ_process_exists $pid]} {
					LWDAQ_post "Neuroarchiver_export Video"
					return "SUCCESS"
				}
			}
			
			LWDAQ_print $info(export_text) "Video extractions complete."

			set info(export_state) "Concat"
			cd $config(export_dir)
			set clf [open concat_list.txt w]
			foreach vfn $info(export_vfl) {
				puts $clf "file [regsub -all {\\} [file nativename $vfn] {\\\\}]"
			}
			close $clf			
			set tempfile [file join $config(export_dir) temp.mp4]
			set info(export_epl) [exec $info(ffmpeg) \
				-nostdin -f concat -safe 0 -loglevel error \
				-i concat_list.txt -c copy \
				[file nativename $tempfile] > concat_log.txt &]
			LWDAQ_print $info(export_text) "Process $info(export_epl) performing\
				video concatination into temporary file."
			LWDAQ_post "Neuroarchiver_export Video"
			return "SUCCESS"
		}

		# If we are concatinating, we are waiting for the concatination to complete.
		if {$info(export_state) == "Concat"} {
			if {[LWDAQ_process_exists $info(export_epl)]} {
				LWDAQ_post "Neuroarchiver_export Video"
				return "SUCCESS"
			}
			set efn [lindex $info(export_vfl) 0]
			set tempfile [file join $config(export_dir) temp.mp4]
			catch {file delete $efn}
			catch {file delete [lindex $info(export_vfl) end]}
			file rename $tempfile $efn
			LWDAQ_print $info(export_text) "Concatination of [llength $info(export_vfl)]\
				video files into [file tail $efn] complete."

			cd $config(export_dir)
			catch {file delete concat_list.txt}
			if {[file exists concat_log.txt]} {
				set clf [open concat_log.txt r]
				set log [string trim [read $clf]]
				close $clf
				file delete concat_log.txt
				if {$log != ""} {
					LWDAQ_print $info(export_text) "Concatination Log:\n$log"
				}
			}
			if {[file exists export_log.txt]} {
				set elf [open export_log.txt r]
				set log [string trim [read $clf]]
				close $elf
				file delete export_log.txt
				if {$log != ""} {
					LWDAQ_print $info(export_text) "Export Log:\n$log"
				}
			}

			LWDAQ_print $info(export_text) "Export complete in\
				[expr [clock seconds] - $info(export_run_start)] s." purple
			set info(export_state) "Wait"
			LWDAQ_post "Neuroarchiver_export Repeat" 
			return "SUCCESS"
		}
	}

	# At the end of an export, we check to see if we should repeat the export strating
	# from the point immediately after the end of the previous export.
	if {$cmd == "Repeat"} {
		if {$info(export_state) != "Wait"} {
			return "SUCCESS"
		}
		
		if {$config(export_reps) == "*"} {
			set repeat 1
		} elseif {[string is integer $config(export_reps)] \
			&& ($config(export_reps) > 1)} {
			set repeat 1
			set config(export_reps) [expr $config(export_reps) - 1]	
		} else {
			set repeat 0
			set config(export_reps) 1
		}
		
		if {$repeat} {
			LWDAQ_print $info(export_text) "\nPreparing another export..." purple
			set config(export_start) \
				[Neuroarchiver_datetime_convert \
				[expr [Neuroarchiver_datetime_convert $info(datetime_start_time)] \
				+ round($info(t_min)) ]]
			set info(export_state) "Idle"
			LWDAQ_post Neuroarchiver_export	"Start" 
			return "SUCCESS"	
		} {
			set info(export_state) "Idle"
			return "SUCCESS"
		}		
	}

	return "FAIL"
}

#
# Neuroarchiver_datetime_update always updates the playback datetime, and if necessary 
# updates the archive start datetime.
#
proc Neuroarchiver_datetime_update {} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config

	set pfn [file tail $config(play_file)]
	if {$pfn != $info(datetime_archive_name)} {
		set info(datetime_archive_name) $pfn
		if {![regexp {([0-9]{10})\.ndf} $pfn match atime]} {
			set atime 0
		}
		set info(datetime_start_time) [Neuroarchiver_datetime_convert $atime]
	}
	set info(datetime_play_time) [Neuroarchiver_datetime_convert \
		[expr [Neuroarchiver_datetime_convert $info(datetime_start_time)] \
			+ round($config(play_time)) ] ]
}

#
# Neuroarchiver_datetime_jump constructs a datetime event string and instructs 
# the Neuroarchiver to jump to an archive containing the datetime specified by the 
# user in the datetime window. If such an archive does not exist, the jump routine 
# will issue an error.
#
proc Neuroarchiver_datetime_jump {} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config

	set jump_time [Neuroarchiver_datetime_convert $config(datetime_jump_to)]
	if {$jump_time > 0} {
		set config(datetime_jump_to) [Neuroarchiver_datetime_convert $jump_time]
		Neuroarchiver_jump "$jump_time 0.0 ? \"$config(datetime_jump_to)\"" 0
	}
}

#
# We convert between integer seconds to the datetime format given in the 
# configuration array. If the input is in integer seconds, it gets converted
# into our datetime format. Otherwise, we convert it from datetime format
# into integer seconds if possible. We issue an error in the Neuroarchiver
# window if the format is incorrect, and return the value zero.
#
proc Neuroarchiver_datetime_convert {datetime} {
	upvar #0 Neuroarchiver_config config
	
	if {[string is integer $datetime]} {
		set newformat [clock format $datetime -format $config(datetime_format)]
	} {
		if {[catch {
			set newformat [clock scan $datetime -format $config(datetime_format)]
		} error_result]} {
			Neuroarchiver_print "ERROR: Invalid clock string, \"$datetime\"."
			set newformat 0
		}
	}
	return $newformat
}

#
# Neuroarchiver_calibration allows us to view and edit the global baseline
# power values used by some processors to produce interval characteristics
# that are independent of the sensitivity of the sensor. The processor can
# use these global variables to keep track of a "baseline" power value by
# which other power measurements may be divided to obtain a normalised
# power measurement. We can save the baseline power values to the metadata
# of an NDF file, or load them from the metadata. The Calibration Panel also
# displays the frequencies used for reconstruction, which may have been
# specified by the user, or may have been picked from a list of possible
# frequencies in the default frequency parameter. 
#
proc Neuroarchiver_calibration {{name ""}} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info

	set w $info(window)\.baselines
	if {[winfo exists $w]} {
		raise $w
		return 0
	}
	toplevel $w
	wm title $w "Calibration Panel for Neuroarchiver $info(version)"

	set f [frame $w.controls]
	pack $f -side left -fill both

	label $f.lsel -text "Channel Include String:" -fg blue
	entry $f.einc -textvariable Neuroarchiver_config(calib_include) -width 35
	button $f.refresh -text "Refresh List" -command {
		destroy $Neuroarchiver_info(window)\.baselines
		LWDAQ_post Neuroarchiver_calibration
	}
	pack $f.lsel $f.einc $f.refresh -side top
	
	set f [frame $w.controls.f1 -relief groove -border 4]
	pack $f -side top -fill both

	button $f.rb -text "Reset Baselines" -command {Neuroarchiver_baseline_reset}
	button $f.rf -text "Reset Frequencies" -command {Neuroarchiver_frequency_reset}
	grid $f.rb $f.rf -sticky news

	button $f.nb -text "Set Baselines To:" -command {Neuroarchiver_baselines_set}
	entry $f.bset -textvariable Neuroarchiver_config(bp_set)
	grid $f.nb $f.bset -sticky news

	set f [frame $w.controls.f2 -relief groove -border 4]
	pack $f -side top -fill both

	button $f.read -text "Read Baselines from Metadata" \
		-command {Neuroarchiver_baselines_read $Neuroarchiver_config(bp_name)}
	pack $f.read -side top
	button $f.save -text "Write Baselines to Metadata" \
		-command {Neuroarchiver_baselines_write $Neuroarchiver_config(bp_name)}
	pack $f.save -side top

	set f [frame $w.controls.f3 -relief groove -border 4]
	pack $f -side top -fill both

	label $f.lname -text "Name for Metadata Reads and Writes:" -fg blue
	pack $f.lname -side top
	entry $f.name -textvariable Neuroarchiver_config(bp_name)
	pack $f.name -side top	
	
	set f [frame $w.controls.f4 -relief groove -border 4]
	pack $f -side top -fill both
	
	label $f.lplayback -text "Playback Strategy:" -fg blue
	pack $f.lplayback -side top
	checkbutton $f.autoreset -variable Neuroarchiver_config(bp_autoreset) \
		-text "Reset Baselines on Playback Start"
	pack $f.autoreset -side top
	checkbutton $f.autoread -variable Neuroarchiver_config(bp_autoread) \
		-text "Read Baselines from Metadata on Playback Start"
	pack $f.autoread -side top
	checkbutton $f.autowrite -variable Neuroarchiver_config(bp_autowrite) \
		-text "Write Baselines to Metadata on Playback Finish"
	pack $f.autowrite -side top

	set f [frame $w.controls.f5 -relief groove -border 4]
	pack $f -side top -fill both
	
	label $f.ljump -text "Jumping Strategy:" -fg blue
	pack $f.ljump -side top
	radiobutton $f.jumpread -variable Neuroarchiver_config(jump_strategy) \
		-text "Read Baselines from Metadata" -value "read"
	radiobutton $f.jumplocal -variable Neuroarchiver_config(jump_strategy) \
		-text "Use Current Baseline Power" -value "local"
	radiobutton $f.jumpevent -variable Neuroarchiver_config(jump_strategy) \
		-text "Use Baseline Power in Event Description" -value "event"
	pack $f.jumpread $f.jumplocal $f.jumpevent -side top

	set f [frame $w.controls.f6 -relief groove -border 4]
	pack $f -side top -fill both
	
	# Get a list of the channels we are supposed to display in the calibration
	# window, and the codes for including channels based upon their alert
	# values.
	set inclist ""
	foreach inc_code $config(calib_include)	{
		if {[regexp {([0-9]+)\-([0-9]+)} $inc_code match a b]} {
			for {set id $a} {$id <= $b} {incr id} {
				lappend inclist $id
			}
		} {
			lappend inclist $inc_code
		}
	}

	# Determine which channels we should display, by consulting their channel 
	# alerts. We create frames to display the channels, their frequency values
	# and their alerts and baseline powers as we go along. We show the channel
	# number in the color it will be plotted in the Neuroarchiver and Neurotracker.
	set count 0
	set info(calib_selected) ""
	for {set id $info(min_id)} {$id <= $info(max_id)} {incr id} {
		if {$id % $info(set_size) == $info(set_size) - 1} {continue}
		if {$id % $info(set_size) == 0} {continue}
		if {$count % 18 == 0} {
			set f [frame $w.calib$count -relief groove -border 4]
			pack $f -side left -fill y
			label $f.tid -text "ID" -fg purple
			label $f.tbp -text "Baseline" -fg purple
			label $f.tsps -text "SPS" -fg purple
			label $f.talert -text "State" -fg purple
			grid $f.tid $f.tbp $f.tsps $f.talert -sticky news
			incr count
		}

		set alert_code [set info(f_alert_$id)] 
		if {([lsearch $inclist "All"] >= 0) \
				|| (($alert_code != "None") && ([lsearch $inclist "Active"] >= 0)) \
				|| ([lsearch $inclist $alert_code] >= 0) \
				|| ([lsearch $inclist $id] >= 0)} {
			lappend info(calib_selected) $id
			set color [lwdaq tkcolor [Neuroarchiver_color $id]]
			label $f.l$id -text $id -anchor w -fg $color
			entry $f.e$id -textvariable Neuroarchiver_info(bp_$id) \
				-relief sunken -bd 1 -width 7
			label $f.f$id -textvariable Neuroarchiver_info(f_$id) -width 5
			label $f.a$id -textvariable Neuroarchiver_info(f_alert_$id) -width 6
			grid $f.l$id $f.e$id $f.f$id $f.a$id -sticky news
			incr count
		}
	}
}

#
# Neuroarchiver_baseline_reset sets all the baseline power values to the
# reset value, which is supposed to be so high that no channel will have a
# baseline power exceeding it.
#
proc Neuroarchiver_baseline_reset {} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info	

	for {set i $info(min_id)} {$i <= $info(max_id)} {incr i} {
		set info(bp_$i) $info(bp_reset)
	}
}

#
# Neuroarchiver_frequency_reset sets all the frequency and frequency alerts
# to zero and N.
#
proc Neuroarchiver_frequency_reset {} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info	

	for {set i $info(min_id)} {$i <= $info(max_id)} {incr i} {
		set info(f_$i) 0
		set info(f_alert_$i) "None"
	}
}

#
# Neuroarchiver_baselines_set sets all the baseline power values to the bp_set
# value.
#
proc Neuroarchiver_baselines_set {} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info	

	for {set i $info(min_id)} {$i <= $info(max_id)} {incr i} {
		set info(bp_$i) $config(bp_set)
	}
}

#
# Neuroarchiver_baselines_write takes the existing baseline power values
# and saves them as baseline power string in the metadata of the current
# playback file, with the name specified in the config(bp_name) parameter.
# The routine does not write baseline powers that meet or exceed the reset 
# value, because these are not valid.
#
proc Neuroarchiver_baselines_write {name} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info	

	if {[regexp {[^a-zA-Z0-9_\-\.]} $name]} {
		Neuroarchiver_print "ERROR: Name \"$name\" invalid contains illegal characters."
		return 0
	}

	if {[catch {set metadata [LWDAQ_ndf_string_read $config(play_file)]} error_string]} {
		Neuroarchiver_print "ERROR: $error_string"
		return 0
	}
	
	if {$name == $info(no_name)} {
		set pattern "<baseline>\[^<\]*</baseline>"
	} {
		set pattern "<baseline id=\"$name\">\[^<\]*</baseline>"
	}
	set metadata [string trim [regsub -all $pattern $metadata ""]]
	
	if {$name == $info(no_name)} {
		append metadata "\n<baseline>\n"
	} {
		append metadata "\n<baseline id=\"$name\">\n"	
	}
	
	for {set id $info(min_id)} {$id <= $info(max_id)} {incr id} {
		if {$info(f_alert_$id) != "None"} {
			append metadata "$id $info(bp_$id)\n"
		}
	}
	
	append metadata "</baseline>\n"
	
	LWDAQ_ndf_string_write $config(play_file) [string trim $metadata]\n

	Neuroarchiver_print "Wrote baselines \"$name\" to [file tail $config(play_file)]." verbose

	return 1
}

#
# Neuroarchiver_baselines_read looks at the metadata of the current playback
# archive and looks for a baseline power string with the name given by the
# config(bp_name) string. It reads any such baseline powers it finds into
# the baseline power array.
#
proc Neuroarchiver_baselines_read {name} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info

	if {[regexp {[^a-zA-Z0-9_\-\.]} $name]} {
		Neuroarchiver_print "ERROR: Baseline name \"$name\" contains illegal characters."
		return 0
	}

	if {[catch {set metadata [LWDAQ_ndf_string_read $config(play_file)]} error_string]} {
		Neuroarchiver_print "ERROR: $error_string"
		return 0
	}

	if {$name == $info(no_name)} {
		set pattern "<baseline>(\[^<\]*)</baseline>"
	} {
		set pattern "<baseline id=\"$name\">(\[^<\]*)</baseline>"
	}

	if {[regexp $pattern $metadata match baselines]} {
		foreach {id bp} [string trim $baselines] {
			if {$bp < $info(bp_reset)} {
				set info(bp_$id) $bp
			}
		}		
	} {
		Neuroarchiver_print "ERROR: No baselines \"$name\" in [file tail $config(play_file)]."
		return 0
	}
	Neuroarchiver_print "Read baselines \"$name\" from [file tail $config(play_file)]." verbose
	return 1
}

#
# Neuroarchiver_fresh_graphs clears the graph images in memory. If you pass it
# a "1" as a parameter, it will clear the graphs from the screen as well.
# It calls lwdaq_graph to create an empty graph in the overlay area of the
# graph images, and lwdaq_draw to draw the empty graph on the screen.
#
proc Neuroarchiver_fresh_graphs {{clear_screen 0}} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config
	global LWDAQ_Info	

	if {![winfo exists $info(window)]} {return 0}
	
	lwdaq_graph "0 0" $info(vt_image) -fill 1 \
			-x_min 0 -x_max 1 -x_div $config(t_div) \
			-y_min 0 -y_max 1 -y_div $config(v_div) \
			-color 1  

	lwdaq_graph "0 0" $info(af_image) -fill 1 -x_min 0 -x_max 1 -y_min 0 -y_max 1

	if {$config(log_frequency)} {
		if {$config(f_min) < [lindex $info(log_lines) 0]} {
			set config(f_min) [lindex $info(log_lines) 0]
		}
		foreach f $info(log_lines) {
			if {$f < $config(f_min)} {continue}
			if {$f > $config(f_max)} {break}
			lwdaq_graph "[expr log($f)] 0 [expr log($f)] 1" $info(af_image) -fill 0 \
				-x_min [expr log($config(f_min))] -x_max [expr log($config(f_max))] \
				-y_min 0 -y_max 1 -color $info(log_color)
		}
	} {	
		lwdaq_graph "0 0" $info(af_image) -fill 0 \
			-x_min 0 -x_max 1 -x_div $config(f_div) \
			-y_min 0 -y_max 1 -y_div 0 \
			-color 1
	}
	
	if {$config(log_amplitude)} {
		if {$config(a_min) < [lindex $info(log_lines) 0]} {
			set config(a_min) [lindex $info(log_lines) 0]
		}
		foreach a $info(log_lines) {
			if {$a < $config(a_min)} {continue}
			if {$a > $config(a_max)} {break}
			lwdaq_graph "0 [expr log($a)] 1 [expr log($a)]" $info(af_image) -fill 0 \
				-y_min [expr log($config(a_min))] -y_max [expr log($config(a_max))] \
				-x_min 0 -x_max 1 -color $info(log_color)
		}
	} {	
		lwdaq_graph "0 0" $info(af_image) -fill 0 \
			-x_min 0 -x_max 1 -x_div 0 \
			-y_min 0 -y_max 1 -y_div $config(a_div) \
			-color 1
	}
	
	if {$clear_screen} {
		Neuroarchiver_draw_graphs
	}
	
	set info(signal) "0 0"
	set info(values) "0"
	set info(spectrum) "0 0"
	
	LWDAQ_support
	return 1
}

#
# Neuroarchiver_draw_graphs draws the vt and af graphs in the two view
# windows in the Neuroarchiver.
#
proc Neuroarchiver_draw_graphs {} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config
	global LWDAQ_Info	

	if {![winfo exists $info(window)]} {return 0}

	if {$config(enable_vt) || $info(force_vt)} {
		lwdaq_draw $info(vt_image) $info(vt_photo) -zoom $config(vt_zoom)
	}
	if {$config(enable_af)} {	
		lwdaq_draw $info(af_image) $info(af_photo) -zoom $config(af_zoom)
	}
	
	return 1
}

#
# Neuroarchiver_magnify_view switches the magnification of the VT or AF view
# and re-plots the view. 
#
proc Neuroarchiver_magnify_view {figure} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config

	if {$figure == "vt"} {
		if {$config(vt_zoom) == $info(vt_zoom_small)} {
			set config(vt_zoom) $info(vt_zoom_large)
		} {
			set config(vt_zoom) $info(vt_zoom_small)
		}
		Neuroarchiver_draw_graphs
	}
	if {$figure == "af"} {
		if {$config(af_zoom) == $info(af_zoom_small)} {
			set config(af_zoom) $info(af_zoom_large)
		} {
			set config(af_zoom) $info(af_zoom_small)
		}
		Neuroarchiver_draw_graphs
	}
	
	return $figure
}

#
# Neuroarchiver_plot_signal plots the a signal on the screen. It uses 
# lwdaq_graph to plot data in the vt_image overlay. The procedure does not 
# draw the graph on the screen. We leave the drawing until all the signals have 
# been plotted in the vt_image overlay by successive calls to this procedure.
# For more information about lwdaw_graph, see the LWDAQ Command Reference.
# If we don't pass a signal to the routine, it uses $info(signal). The signal
# string must be a list of time and sample values "t v ". If we don't specify
# a color, the routine uses the info(channel_num) as the color code. If we don't 
# specify a signal, the routine uses the $info(signal).
#
proc Neuroarchiver_plot_signal {{color ""} {signal ""}} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config
	upvar result result
	global LWDAQ_Info	

	# Abort if running in no-gui mode.
	if {!$info(gui)} {return 0}
	
	# Select colors and signal.
	if {$color == ""} {set color [Neuroarchiver_color $info(channel_num)]}
	if {$signal == ""} {set signal $info(signal)}
	
	# Check the range and offset parameters for errors.
	foreach a {v_range v_offset} {
		if {![string is double -strict $config($a)]} {
			set result "ERROR: Invalid value, \"$config($a)\" for $a."
			return 0
		}
	}
	
	# Check color for errors.
	if {[llength $color] > 1} {
		set result "ERROR: Invalid color, \"$color\"."
		return 0
	}

	# Set up the range and plot the values.
	if {$config(vt_mode) == "CP"} {
		lwdaq_graph $signal $info(vt_image) \
			-y_min [expr - $config(v_range) / 2 ] \
			-y_max [expr + $config(v_range) / 2] \
			-color $color \
			-ac_couple 1
	} elseif {$config(vt_mode) == "NP"} {
		lwdaq_graph $signal $info(vt_image) \
			-y_min 0 -y_max 0 \
			-color $color \
			-ac_couple 0
	} else {
		lwdaq_graph $signal $info(vt_image) \
			-y_min $config(v_offset) \
			-y_max [expr $config(v_offset) + $config(v_range)] \
			-color $color \
			-ac_couple 0
	}

	# Check for errors and report.
	if {[lwdaq_error_string] != ""} {Neuroarchiver_print [lwdaq_error_string]}

	LWDAQ_support
	return 1
}

#
# Neuroarchiver_plot_values takes a list of values and plots them in the
# value versus time display as if they were evenly-spaced samples. The 
# routine is identical to Neuroarchiver_plot_signal except that we don't
# have to pass it a string of x-y values, only the y-values. We pass the
# routine a color and a string of values. If the values are omitted, the
# routine uses the current string of values in info(values).
#
proc Neuroarchiver_plot_values {{color ""} {values ""}} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config
	upvar result result
	global LWDAQ_Info

	# Abort if running in no-gui mode.
	if {!$info(gui)} {return 0}
	
	# Select values.
	if {$values == ""} {set values $info(values)}
	
	# Construct a signal for Neuroarchiver_plot_signal.
	set timestamp 0
	set signal ""
	foreach v $values {
		append signal "$timestamp $v "
		incr timestamp
	}
	
	# Call the plot routine.
	Neuroarchiver_plot_signal $color $signal
	
	return 1
}



#
# Neuroarchiver_plot_spectrum plots a spectrum in the af_image overlay, but 
# does not display the plot on the screen. The actual display will take
# place later, for all channels at once, to save time. If you don't
# pass a spectrum to the routine, it will plot $info(spectrum). Each
# spectrum point must be in the format "f a ", where f is frequency
# in Hertz and a is amplitude in ADC counts. If we don't specify a color for
# the plot, the routine uses the $info(channel_num). If we don't specify a spectrum,
# it uses $info(spectrum).
#
proc Neuroarchiver_plot_spectrum {{color ""} {spectrum ""}} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config
	upvar result result
	global LWDAQ_Info	

	# Abort if running in no-gui mode.
	if {!$info(gui)} {return 0}
	
	# Select color and spectrum values.
	if {$color == ""} {set color [Neuroarchiver_color $info(channel_num)]}
	if {$spectrum == ""} {set spectrum $info(spectrum)}

	# Check the range paramters for errors.
	foreach a {a_min a_max f_min f_max} {
		if {![string is double -strict $config($a)]} {
			set result "ERROR: Invalid value, \"$config($a)\" for $a."
			return 0
		}
	}
	
	# Extract the amplitudes and associate them with frequencies.
	set amplitudes ""
	set frequency 0
	foreach {a p} $spectrum {
		if {($frequency >= $config(f_min)) && ($frequency <= $config(f_max))} {

			if {$config(log_amplitude)} {
				if {$a > 0.0} {
					set plot_y [format %.3f [expr log($a)]]
				} {
					set plot_y [format %.3f [expr log([lindex $info(log_lines) 0])]]
				}
			} {
				set plot_y $a
			}

			if {$config(log_frequency)} {
				set plot_x [format %.3f [expr log($frequency)]]
			} {
				set plot_x $frequency
			}
			
			append amplitudes "$plot_x $plot_y "
		}
		set frequency [expr $frequency + $info(f_step)]
	}
	
	# Set ranges.
	if {$config(log_frequency)} {
		set x_min [expr log($config(f_min))]
		set x_max [expr log($config(f_max))]
	} {
		set x_min $config(f_min)
		set x_max $config(f_max)
	}
	if {$config(log_amplitude)} {
		set y_min [expr log($config(a_min))]
		set y_max [expr log($config(a_max))]
	} {
		set y_min $config(a_min)
		set y_max $config(a_max)
	}
	
	# Plot in the af image.
	lwdaq_graph $amplitudes $info(af_image) \
		-x_min $x_min -x_max $x_max \
		-y_min $y_min -y_max $y_max \
		-color $color
	
	# Detect errors.
	if {[lwdaq_error_string] != ""} {Neuroarchiver_print [lwdaq_error_string]}

	LWDAQ_support
	return 1
}

#
# Neuroarchiver_record manages the recording of data to archive files. It is the
# recorder's execution procedure. It calls the Recorder Instrument to produce
# a block of data with a fixed number of clock messages. It stores these
# messages to disk. If the control variable, config(record_control), is "Record",
# the procedure posts itself again to the event queue. The recorder calculates
# the number of clock messages from the record_interval time, which is in 
# seconds, and is available in the Neuroarchiver panel.
#
proc Neuroarchiver_record {{command ""}} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config
	upvar #0 LWDAQ_config_Recorder iconfig
	upvar #0 LWDAQ_info_Recorder iinfo
	global LWDAQ_Info
	
	# Make sure we have the info array.
	if {![array exists info]} {return 0}

	# Check if we have an overriding command passed with the call to this
	# procedure, as we might from a LWDAQ configuration script.
	if {$command != ""} {set info(record_control) $command}
	
	# If a global reset is going on, go to idle state.
	if {$LWDAQ_Info(reset)} {
		set info(record_control) "Idle"
		set info(recorder_buffer) ""
		return 1
	}
	
	# If we have closed the Neuroarchiver window when we are running with graphics,
	# this indicates that the user wants all recording to stop and the Neuroarchiver
	# to close and reset.
	if {$info(gui) && ![winfo exists $info(window)]} {
		array unset info
		array unset config
		return 0
	}
	
	# If the gui is enabled, update it now.
	if {$info(gui)} {
		LWDAQ_update	
	}
	
	# If Stop, we move to Idle and return.
	if {$info(record_control) == "Stop"} {
		set info(record_control) "Idle"
		set info(recorder_buffer) ""
		return 1
	}
	
	# If Pick we choose an archive into which to record data.
	if {$info(record_control) == "Pick"} {
		LWDAQ_set_bg $info(record_control_label) orange
		LWDAQ_update
		Neuroarchiver_pick record_file
		LWDAQ_set_bg $info(record_control_label) white
		LWDAQ_update
	}

	# If PickDir we choose a directory in which to create new archives.
	if {$info(record_control) == "PickDir"} {
		LWDAQ_set_bg $info(record_control_label) orange
		LWDAQ_update
		Neuroarchiver_pick record_dir
		LWDAQ_set_bg $info(record_control_label) white
		LWDAQ_update
	}

	# If reset or autocreate, we create a new archive using the record start clock
	# value as the timestamp in the file name, and the ndf_prefix as the the beginning
	# of the name.
	if {($info(record_control) == "Reset") || \
		(($config(record_end_time) >= $config(autocreate)) && ($config(autocreate) > 0))} {

		# Turn the recording label red,
		LWDAQ_set_bg $info(record_control_label) red
		
		# Clear the buffer.
		set info(recorder_buffer) ""

		# Wait until a new second begins, but only on a Reset command or if the
		# synchronization flag set.
		set ms_start [clock milliseconds]
		if {($info(record_control) == "Reset") || $config(synchronize)} {
			while {[expr [clock milliseconds] % 1000] > $info(sync_window_ms)} {
				LWDAQ_support
				if {$info(record_control) == "Stop"} {
					set info(record_control) "Idle"
					if {[winfo exists $info(window)]} {
						LWDAQ_set_bg $info(record_control_label) white
					}
					return 1
				}
			}
		}
		set ms_stop [clock milliseconds]
		
		# Set the timestamp for the new file, with resolution one second.
		set config(record_start_clock) [clock seconds]
		
		# Configure the Recorder Instrument with IP address and driver socket
		# number. Set the payload length and tracker coordinates based upon the
		# receiver version.
		set iconfig(daq_ip_addr) $config(daq_ip_addr)
		set iconfig(daq_driver_socket) $config(daq_driver_socket)
		switch $config(daq_receiver) {
			"A3018" {
				set iconfig(payload_length) 0
				set config(tracker_coordinates) ""
			}
			"A3027" {
				set iconfig(payload_length) 0
				set config(tracker_coordinates) ""
			}
			"A3032" {
				set iconfig(payload_length) $info(A3032_payload)
				set config(tracker_coordinates) $info(A3032_coordinates)
			}
			"A3038A" {
				set iconfig(payload_length) $info(A3038A_payload)
				set config(tracker_coordinates) $info(A3038A_coordinates)
			}
			default {
				set iconfig(payload_length) 0
				set config(tracker_coordinates) ""
			}
		}

		# Reset the data recorder, but only if the comand is Reset or if
		# the synchronize flag is set.
		if {($info(record_control) == "Reset") || $config(synchronize)} {
			set result [LWDAQ_reset_Recorder]
			if {[LWDAQ_is_error_result $result]} {
				Neuroarchiver_print "$result"
				set info(record_control) "Idle"
				return 0
			}
		}
		set ms_reset [clock milliseconds]		

		# Restore the recording label to white.
		LWDAQ_set_bg $info(record_control_label) white
		LWDAQ_update

		# Check that the destination directory exists.
		if {![file exists $config(record_dir)]} {
			Neuroarchiver_print "ERROR: Directory $config(record_dir)\
				does not exist for new archive."
			set info(record_control) "Idle"
			return 0
		}

		# Create and set up the new recording file.
		set config(record_file) [file join $config(record_dir) \
			"$config(ndf_prefix)$config(record_start_clock)\.ndf"]
		set info(record_file_tail) [file tail $config(record_file)]
		LWDAQ_ndf_create $config(record_file) $config(ndf_metadata_size)	
		LWDAQ_ndf_string_write $config(record_file) [Neuroarchiver_metadata_header] 
		if {($info(record_control) == "Reset") || $config(synchronize)} {
			Neuroarchiver_print "Created synchronized NDF file\
				[file tail $config(record_file)],\
				reset delay [expr $ms_reset-$ms_stop] ms,\
				sync wait [expr $ms_stop-$ms_start] ms."
		} {
			Neuroarchiver_print "Created unsynchronized NDF file\
				[file tail $config(record_file)]."
		}
		set config(record_end_time) 0
	}

	# If Record, we download data from the data recorder and write it to
	# the archive.
	if {$info(record_control) == "Record"} {
		# If we have already caught up with our recording, we don't bother trying to
		# acquire more data because we'll be occupying the LWDAQ process and the 
		# LWDAQ driver as well, for no good reason. Instead, we post the recorder to
		# the end of the event queue.
		if {$iinfo(acquire_end_ms) > [clock milliseconds] - 1000*$config(record_lag)} {		
			LWDAQ_post Neuroarchiver_record end
			return 1
		}

		# If our recording buffer is not empty, try to write the data to disk
		# now. If we get a file locked error, we will try again later to write
		# the data to disk, but avoid trying to download any more data. If we
		# get any other error we abandon recording.
		if {$info(recorder_buffer) != ""} {
			if {[catch {
				LWDAQ_ndf_data_append $config(record_file) $info(recorder_buffer)
				set info(recorder_buffer) ""	
				Neuroarchiver_print "WARNING: Wrote buffered data to\
					[file tail $config(record_file)]\
					after previous write failure."		
			} error_message]} {
				if {[regexp "file locked" $error_message]} {				
					LWDAQ_post Neuroarchiver_record end
				} {
					Neuroarchiver_print "ERROR: $error_message\."
					set info(recorder_buffer) ""
					set info(record_control) "Idle"
				}
				LWDAQ_set_bg $info(record_control_label) white
				return 0
			}
		}
		
		# Set the record label to the download color.
		LWDAQ_set_bg $info(record_control_label) yellow
		
		# If the Recorder happens to be looping, stop it.
		if {$iinfo(control) == "Loop"} {set iinfo(control) "Acquire"}

		# Set the number of clocks we want to download using the Recorder Instrument.
		# The Recorder Instrument will giveus exactly this number of clocks, unless there
		# is an error.
		set iconfig(daq_num_clocks) \
			[expr round($config(record_interval) * $info(clocks_per_second))]

		# We are going to make single attempts to contact the data receiver and download
		# a block of messages, regardless of the value of LWDAQ_Info(max_daq_attempts).
		set saved_max_daq_attempts $LWDAQ_Info(max_daq_attempts)
		set LWDAQ_Info(max_daq_attempts) 1	
	
		# Download a block of messages from the data receiver into a LWDAQ image, the name
		# of which is $iconfig(memory_name). The Recorder Instrument returns a string that
		# describes the data block, or reports an error.
		set daq_result [LWDAQ_acquire Recorder]
		
		# We restore the global max_daq_attempts variable.
		set LWDAQ_Info(max_daq_attempts) $saved_max_daq_attempts
		
		# If the attempt to download encountered an error, report it to the
		# Neuroarchvier text window with the current date and time. When it
		# encounters an error, the Recorder Instrument will try to reset the
		# data receiver, which will clear its data memory. The Recorder
		# Instrument will set its acquire_end_ms parameter accordingly. We post
		# the Neuroarchiver_record command again, so we can make another
		# attempt. The Neuroarchiver will never give up trying to download data
		# until the user presses the Stop button. In this case, we post the
		# recording process to the end of the event queue because our recovery
		# is not urgent.
		if {[LWDAQ_is_error_result $daq_result]} {
			Neuroarchiver_print "$daq_result"
			LWDAQ_set_bg $info(record_control_label) white
			LWDAQ_post Neuroarchiver_record end
			return 0
		}
		
		# Append the new data to our NDF file. If the data write fails, we print
		# an error message warning of the loss of data. An error writing to the
		# file will occur on Windows if another process is reading the file. If
		# we encounter such an error, we drop this interval of data, post the
		# recording process to the end of the event queue, and hope that the
		# file system conflict will soon be resolved.
		set message_length [expr $info(core_message_length) + $iconfig(payload_length)]
		if {[catch {
			set info(recorder_buffer) [lwdaq_image_contents $iconfig(memory_name) -truncate 1 \
					-data_only 1 -record_size $message_length]
			LWDAQ_ndf_data_append $config(record_file) $info(recorder_buffer)
			set info(recorder_buffer) ""				
		} error_message]} {
			if {[regexp "file locked" $error_message]} {				
				Neuroarchiver_print "WARNING: Could not write to\
					[file tail $config(record_file)],\
					permission denied, buffering data."
				LWDAQ_post Neuroarchiver_record end
			} {
				Neuroarchiver_print "ERROR: $error_message\."
				set info(record_control) "Idle"
				set info(recorder_buffer) ""				
			}
			LWDAQ_set_bg $info(record_control_label) white
			return 0
		}
		
		# Increment the record time. If there has been interruption in the
		# data acquisition, in which we lost data, this end time will be too
		# low. If the data acquisition has been fragmented, so that we obtain
		# fewer clock messages than we asked for, this end time will be too high.
		set config(record_end_time) [expr $config(record_end_time) + $config(record_interval)]
		
		# We restore the record lable color.
		LWDAQ_set_bg $info(record_control_label) white
		
		# We continue recording by posting the record process to the LWDAQ event queue.
		# If we are lagging behind in our recording, we post the recording process to
		# second place in the queue so we don't have to wait for playback. Otherwise we post
		# to the back of the queue.
		if {$iinfo(acquire_end_ms) < [clock milliseconds] - 1000*$config(record_lag)} {		
			LWDAQ_post Neuroarchiver_record front		
			return 1
		} {
			LWDAQ_post Neuroarchiver_record end
			return 1
		}
	}

	set info(record_control) "Idle"
	return 1
}

#
# Neuroarchiver_play manages the play-back and processing of signals
# from archive files. We start by checking the block of messages in 
# the buffer_image. We read messages out of the play-back archive until
# it has enough clock messages to span play_interval seconds. Sometimes,
# the block of messages we read will be many times larger than necessary.
# We extract from the buffer_image exactly the correct number of messages
# to span the play_interval and put these in the data_image. We go through
# the channels string and make a list of channels we want to process. For
# each of these channels, in the order they appear in the channels string,
# we apply extraction, reconstruction, transformation, and processing to the 
# data image. If requested by the user, we read their processor_file off
# disk and apply it in turn to the signal and spectrum we obtained for
# each channel. We store the results of processing to disk in a text file
# and print them to the text window also.
#
proc Neuroarchiver_play {{command ""}} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config
	upvar #0 LWDAQ_config_Recorder iconfig
	upvar #0 LWDAQ_info_Recorder iinfo
	global LWDAQ_Info

	# Make sure we have the info array.
	if {![array exists info]} {return 0}

	# Check if we have an overriding command.
	if {$command != ""} {set info(play_control) $command}

	# Consider various ways in which we will do nothing and return.
	if {$LWDAQ_Info(reset)} {
		set info(play_control) "Idle"
		return 1
	}
	if {$info(gui) && ![winfo exists $info(window)]} {
		array unset info
		array unset config
		return 0
	}
	if {[winfo exists $info(window)]} {
		LWDAQ_update	
	}	
	if {$info(play_control) == "Stop"} {
		LWDAQ_set_bg $info(play_control_label) white
		set info(play_control) "Idle"
		return 1
	}
	if {$config(video_enable) && ($config(play_interval) < $info(video_min_interval_s))} {
		Neuroarchiver_print "ERROR: Playback interval must be a multiple\
			of $info(video_min_interval_s) when video is enabled."
		LWDAQ_set_bg $info(play_control_label) white
		set info(play_control) "Idle"
		return 1
	}

	# Check to see if there are any videos playing. We must wait for them
	# to finish before we continue with playback of the archive.	
	if {$info(video_state) == "Play"} {
		LWDAQ_post Neuroarchiver_play
		return 1
	}
	
	# If the play control label background is yellow and we are 
	# playing an archive, we won't set the label green yet. Otherwise
	# we adjust the color.
	if {[winfo exists $info(window)]} {
		if {($info(play_control) == "Play") \
				&& ([$info(play_control_label) cget -bg] != "yellow")} {
			LWDAQ_set_bg $info(play_control_label) green
		} 
		if {$info(play_control) != "Play"} {
			LWDAQ_set_bg $info(play_control_label) orange
		}
		LWDAQ_update
	}
	
	# Format the play time variable and save the play interval.
	set config(play_time) [Neuroarchiver_play_time_format $config(play_time)]
	set info(play_interval_copy) $config(play_interval)
	
	# If Pick, we choose an archive for playback.
	if {$info(play_control) == "Pick"} {
		Neuroarchiver_pick play_file
		set config(play_time) 0.0
		set config(saved_play_time) $config(play_time)
		Neuroarchiver_fresh_graphs 1
		if {![string match $config(play_dir)* $config(play_file)]} {
			Neuroarchiver_print "WARNING: Directory tree changed to include new play file."
			set config(play_dir) [file dirname $config(play_file)]
		}
	}

	# If PickDir we choose a directory in which to find archives for
	# playback.
	if {$info(play_control) == "PickDir"} {
		Neuroarchiver_pick play_dir
		Neuroarchiver_fresh_graphs 1
		set info(play_control) "First"
	}

	# If First we find the first file in the playback directory tree.
	if {$info(play_control) == "First"} {
		set play_list [LWDAQ_find_files $config(play_dir) *.ndf]
		set play_list [LWDAQ_sort_files $play_list]
		if {[llength $play_list] < 1} {
			Neuroarchiver_print "ERROR: There are no NDF files in the\
				playback directory tree."
			LWDAQ_set_bg $info(play_control_label) white
			set info(play_control) "Idle"
			return 0
		}
		set config(play_file) [lindex $play_list 0]
		set config(play_time) 0.0
		set config(saved_play_time) $config(play_time)
		Neuroarchiver_fresh_graphs 1
	}
	
	# Check that the play file exists.
	if {![file exists $config(play_file)]} {
		Neuroarchiver_print "ERROR: Cannot find play file \"$config(play_file)\"."
		LWDAQ_set_bg $info(play_control_label) white
		set info(play_control) "Idle"
		return 0
	}

	# If we have changed files, check the new file is NDF.
	if {$config(play_file) != $info(saved_play_file)} {
		if {[catch {LWDAQ_ndf_data_check $config(play_file)} error_message]} {
			Neuroarchiver_print "ERROR: Checking archive, $error_message."
			LWDAQ_set_bg $info(play_control_label) white
			set info(play_control) "Idle"
			return 0
		}	
	}
	
	# If we have changed files, get the new end time for this file, set the
	# play time to the start of the file, read the payload length from the
	# new file metadata, update the clock, and reset tracking variables.
	if {$config(play_file) != $info(saved_play_file)} {
		set config(play_index) 0
		set info(play_file_tail) [file tail $config(play_file)]
		set info(saved_play_file_mtime) [file mtime $config(play_file)]
		set info(saved_play_file) $config(play_file)
		set info(play_end_time) [Neuroarchiver_end_time $config(play_file)]
		set info(play_previous_clock) -1
		if {$config(play_time) < 0.0} {
			set config(play_time) 0.0
		}
		if {($config(play_time) > [expr $info(play_end_time) - $info(play_interval_copy)])} {
			set config(play_time) [Neuroarchiver_play_time_format \
				[expr $info(play_end_time) - \
				$info(play_interval_copy) - \
				fmod($info(play_end_time),$info(play_interval_copy))] ]
		}
		if {$config(play_time) < 0} {
			set config(play_time) 0.0
		}
		set info(saved_play_time) 0.0
		Neuroarchiver_datetime_update
		lwdaq_data_manipulate $info(buffer_image) clear
		set info(buffer_size) 0
		set config(standing_values) ""
		set config(unaccepted_values) ""
		
		# Read the metadata out of the archive to obtain the payload and
		# tracker coordinates that accompany the recording. By default,
		# the payload is zero. But if we find a payload field int he metadata,
		# we use the value given in the field. By default, the tracker
		# coordinates will be those of the original location tracker, the 
		# ALT (A3032), because some early ALT recordings did not contain the
		# tracker coordinates in their metadata. Thus we can end up with 
		# payload zero and coordinates for fifteen coils, which is not a
		# self-consistent combination. Our tracker extraction routine, however,
		# checks to see if the coordinates and payload are consistent, and
		# only if they are does it proceed with location calculation.
		if {[catch {
			set metadata [LWDAQ_ndf_string_read $config(play_file)]
		} error_message]} {
			Neuroarchiver_print "ERROR: $error_message."
			LWDAQ_set_bg $info(play_control_label) white
			set info(play_control) "Idle"
			return 0			
		}
		set payload [LWDAQ_xml_get_list $metadata "payload"]
		if {[string is integer -strict $payload]} {
			set config(player_payload_length) $payload
		} {
			set config(player_payload_length) 0
		}
		set coordinates [LWDAQ_xml_get_list $metadata "coordinates"]
		if {[llength $coordinates] >= 1} {
			set config(tracker_coordinates) [lindex $coordinates end]
		} {
			set config(tracker_coordinates) $info(A3032_coordinates)
		}
	}

	# We update the player's file end-time when the play file has been
	# modified. But we pass the end-time routine the current play time
	# and play index as a starting point, so the routine will not have
	# to start from the beginning of a file that is being recorded to
	# disk while we play it back.
	if {$info(saved_play_file_mtime) != [file mtime $config(play_file)]} {
		set info(saved_play_file_mtime) [file mtime $config(play_file)]
		set info(play_end_time) [Neuroarchiver_end_time $config(play_file)\
			$config(play_time) $config(play_index)]
	}

	# If Pick or First we are done.
	if {($info(play_control) == "Pick") || ($info(play_control) == "First")} {
		LWDAQ_set_bg $info(play_control_label) white
		set info(play_control) "Idle"
		return 1
	}
	
	# If Back, we are going to jump to the start of the previous interval, even
	# if that interval is in an earlier file.
	if {$info(play_control) == "Back"} {
		# Set the play time back by two intervals.
		set config(play_time) [Neuroarchiver_play_time_format \
			[expr $config(play_time) - 2.0 * $info(play_interval_copy)]]

		# If we are going back before the start of this archive, we try to find
		# an previous archive. We get a list of all NDF files in the play_dir
		# directory tree.
		if {$config(play_time) < 0.0} {
			set fl [LWDAQ_find_files $config(play_dir) *.ndf]
			set fl [LWDAQ_sort_files $fl]
			set i [lsearch $fl $config(play_file)]
			if {$i < 0} {
				Neuroarchiver_print "ERROR: Cannot move to previous file,\
					\"$info(play_file_tail)\" not in playback directory tree."
				LWDAQ_set_bg $info(play_control_label) white
				set info(play_control) "Idle"
				return 0
			}
			set file_name [lindex $fl [expr $i - 1]]
			if {$file_name != ""} {
				Neuroarchiver_print "Playback switching to previous file \"$file_name\"."
				set config(play_file) $file_name
				set info(play_file_tail) [file tail $file_name]
				set config(play_time) $info(max_play_time)
			} {
				Neuroarchiver_print "ERROR: No previous file in\
					playback directory tree."
				set config(play_time) 0.0
				LWDAQ_set_bg $info(play_control_label) white
				set info(play_control) "Idle"
				return 0
			}
		} 
		
		set info(play_control) "Step"
		LWDAQ_post Neuroarchiver_play
		return 1
	}
	
	# If Repeat we re-disoplay the previous interval.
	if {$info(play_control) == "Repeat"} {
		set config(play_time) [Neuroarchiver_play_time_format \
			[expr $config(play_time) - $info(play_interval_copy)]]
		if {$config(play_time) < 0.0} {
			set config(play_time) 0.0
		}
		set info(play_control) "Step"
		LWDAQ_post Neuroarchiver_play
		return 1
	}
	
	# We trim the text window to a maximum number of lines.
	if {[winfo exists $info(text)]} {
		if {[$info(text) index end] > 1.2 * $config(num_lines_keep)} {
			$info(text) delete 1.0 "end [expr 0 - $config(num_lines_keep)] lines"
		}
	}

	# If we have jumped since the previous interval display, we must seek
	# the point in the archive that corresponds to the desired time.
	if {$config(play_time) != $info(saved_play_time)} {
		# Because we are jumping to a new location, we set the previous clock
		# variable to the undefined code.
		set info(play_previous_clock) -1

		# Our target play time is play_time. We seek through the archive and
		# find the last clock message that occurs in the data before or exactly
		# at the target time.
		scan [Neuroarchiver_seek_time $config(play_file) $config(play_time)] \
			%f%u new_play_time new_play_index

		# If the new play time is less than our target, we either asked for
		# a time that does not correspond to a clock message, or there are 
		# clock messages missing from the data. In either case, we move to
		# the interval boundary just before the new play time.
		if {$new_play_time < $config(play_time)} {
			set new_play_time [Neuroarchiver_play_time_format \
				[expr $new_play_time - fmod($new_play_time,$info(play_interval_copy))]]
			scan [Neuroarchiver_seek_time $config(play_file) $new_play_time] \
				%f%u new_play_time new_play_index
		}
		
		# If our new play time is greater than our target play time, and the target
		# play time is itself greater than zero, something has gone wrong in the 
		# seek operation.
		if {($new_play_time > $config(play_time)) && ($config(play_time) > 0)} {
			Neuroarchiver_print "WARNING: No clock message preceding\
				time $config(play_time) s in [file tail $config(play_file)],\
				moving to $new_play_time s."
		}

		# Report the move to the text window when verbose is set.
		Neuroarchiver_print "Moving to clock at $new_play_time s,\
			index $new_play_index,\
			closest to target $config(play_time) s." verbose
			
		# Set the play time and index.
		set config(play_time) $new_play_time
		set config(play_index) $new_play_index

		# Set the saved play time and clear the data buffer and reset the
		# unaccepted value list.
		set info(saved_play_time) $config(play_time)
		Neuroarchiver_datetime_update	
		lwdaq_data_manipulate $info(buffer_image) clear
		set info(buffer_size) 0
		set config(standing_values) "" 
		set config(unaccepted_values) ""
	}

	# At the start of an archive, we might have to reset baseline powers and read new
	# baseline powers.
	if {$config(play_time) == 0.0} {
		if {$config(bp_autoreset)} {Neuroarchiver_baseline_reset}
		if {$config(bp_autoread)} {Neuroarchiver_baselines_read $config(bp_name)}
	}
	
	# Check the data we already have in the buffer image, which will be empty if we
	# have just jumped to a new time, but will contain left-over data from previous 
	# file reads if we are simply moving on through the same file.
	set play_num_clocks [expr round($info(play_interval_copy) * $info(clocks_per_second))]
	set clocks [lwdaq_recorder $info(buffer_image) \
		"-payload $config(player_payload_length) \
			-size $info(buffer_size) clocks 0 $play_num_clocks"]
	scan $clocks %d%d%d%d%d num_buff_errors num_clocks num_messages start_index end_index

	# We read more data from the file until we have enough to make an entire playback
	# interval. If the file ends, we set a flag.
	set end_of_file 0
	set message_length [expr $info(core_message_length) + $config(player_payload_length)]
	while {($num_clocks < $play_num_clocks) && !$end_of_file} {
		if {[catch {
			set data [LWDAQ_ndf_data_read \
				$config(play_file) \
				[expr $message_length * ($config(play_index) + $info(buffer_size))] \
				$info(block_size)]} error_message]} {
			Neuroarchiver_print "ERROR: $error_message."
			LWDAQ_set_bg $info(play_control_label) white
			set info(play_control) "Idle"
			return 0			
		}
		set num_messages_read [expr [string length $data] / $message_length ]
		if {$num_messages_read > 0} {
			Neuroarchiver_print "Read $num_messages_read messages from\
				[file tail $config(play_file)]." verbose
			if { $info(max_buffer_bytes) <= \
					($info(buffer_size) * $message_length) + [string length $data]} {
				lwdaq_data_manipulate $info(buffer_image) clear
				set info(buffer_size) 0
				Neuroarchiver_print "WARNING: Data buffer overflow\
					at $config(play_time) s in [file tail $config(play_file)]."
			}
			lwdaq_data_manipulate $info(buffer_image) write \
				[expr $info(buffer_size) * $message_length] $data
			set info(buffer_size) [expr $info(buffer_size) \
				+ ([string length $data] / $message_length)]
			set clocks [lwdaq_recorder $info(buffer_image) \
				"-payload $config(player_payload_length) \
					-size $info(buffer_size) clocks 0 $play_num_clocks"]
			scan $clocks %d%d%d%d%d num_buff_errors num_clocks num_messages start_index end_index
		} {
			set end_of_file 1
		}
	}
	
	# The file ends without supplying us with enough data for the playback interval. We try to 
	# find the next file and continue. Otherwise we wait.
	if {$end_of_file} {
		# We are at the end of the file, so write baselines to metadata if
		# instructed by the user.
		if {$config(bp_autowrite)} {
			Neuroarchiver_baselines_write $config(bp_name)
		}	
		
		# Stop now if play_stop_at_end is set. We don't have enough data
		# to display a full interval.
		if {$config(play_stop_at_end)} {
			LWDAQ_set_bg $info(play_control_label) white
			set info(play_control) "Idle"
			return 1
		}
		
		# We obtain a list of all NDF files in the play_dir directory tree. If
		# can't find the current file in the directory tree, we abort.
		set fl [LWDAQ_find_files $config(play_dir) *.ndf]
		set fl [LWDAQ_sort_files $fl]
		set i [lsearch $fl $config(play_file)]
		if {$i < 0} {
			Neuroarchiver_print "ERROR: Cannot continue to a later file,\
				\"$info(play_file_tail)\" not in playback directory tree."
			LWDAQ_set_bg $info(play_control_label) white
			set info(play_control) "Idle"
			return 0
		}
		
		# We see if there is a later file in the directory tree. If so, we switch to
		# the later file. Otherwise, we wait for a new file or new data, by calling
		# the Neuroarchiver play routine again and turning the control label yellow.
		set file_name [lindex $fl [expr $i + 1]]
		if {$file_name != ""} {
			Neuroarchiver_print "Playback switching to next file $file_name."
			set config(play_file) $file_name
			set info(play_file_tail) [file tail $file_name]
			set config(play_time) 0.0
			set old_end_time [Neuroarchiver_datetime_convert $info(datetime_play_time)]
			Neuroarchiver_datetime_update
			set new_start_time [Neuroarchiver_datetime_convert $info(datetime_start_time)]
			set time_gap [expr $new_start_time - $old_end_time]
			if {$time_gap > $info(play_interval_copy)} {
				Neuroarchiver_print "WARNING: Jumping $time_gap s from\
					[Neuroarchiver_datetime_convert $old_end_time] to\
					[Neuroarchiver_datetime_convert $new_start_time]\
					when switching to [file tail $file_name]."
			}
			LWDAQ_set_bg $info(play_control_label) white
			LWDAQ_post Neuroarchiver_play
			return 1
		} {
			# This is the case where we have $num_clocks but need $play_num_clocks
			# and we have no later file to switch to. This case arises during live 
			# play-back, when the player is trying to read more data out of the file 
			# that is being written to by the recorder. The screen will show you when 
			# the Player is waiting. By checking the state of the play_control_label, 
			# we make sure that we issue the following print statement only once. While
			# the Player is waiting, the label remains yellow.
			if {[winfo exists $info(window)]} {
				if {[$info(play_control_label) cget -bg] != "yellow"} {
					Neuroarchiver_print "Have $num_clocks clocks, need $play_num_clocks.\
						Waiting for next archive to be recorded." verbose
					LWDAQ_set_bg $info(play_control_label) yellow
				}
			}
			LWDAQ_post Neuroarchiver_play
			return 1
		}
	}
	
	# By this point, the number of clocks in the buffer should be at least equal
	# to the number required by the interval. If not, something has gone wrong that
	# we did not anticipate. We issue a warning and hope that the Neuroarchiver can
	# keep going without crashing.
	if {$num_clocks < $play_num_clocks} {
		Neuroarchiver_print "WARNING: Internal error, num_clocks < play_num_clocks."
	}
	
	# We make sure the Play control label background is no longer yellow, because
	# we are no longer waiting for data.
	if {[winfo exists $info(window)]} {
		if {$info(play_control) == "Play"} {
			LWDAQ_set_bg $info(play_control_label) green
		} {
			LWDAQ_set_bg $info(play_control_label) orange
		}
		LWDAQ_update
	}
	
	# By this point, start_index and end_index should be the indices within the buffer
	# image of the first clock message in the current playback interval and the first 
	# clock message in the next playback interval. It is possible, however, for the 
	# buffer to contain the current interval and no additional clock messages, so our
	# end_index is now -1. If the index is -1, we set it to the number of messages.
	if {$end_index < 0} {
		set end_index $num_messages
	}
	
	# We transfer this interval's data from the buffer image into our
	# data image, which we will use for analysis and reconstruction.
	# The transfer involves copying the interval data from the buffer
	# image and deleting it from the buffer image.
	set start_addr [expr $start_index * $message_length]
	set end_addr [expr $end_index * $message_length]
	set data [lwdaq_data_manipulate $info(buffer_image) read \
		$start_addr [expr $end_addr - $start_addr]]
	lwdaq_data_manipulate $info(data_image) clear
	lwdaq_data_manipulate $info(data_image) write 0 $data 
	set info(data_size) [expr [string length $data] / $message_length]
	lwdaq_data_manipulate $info(buffer_image) shift $end_addr
	set info(buffer_size) [expr $info(buffer_size) - $end_index]

	# We count the number of clocks and determine the index, within the 
	# interval data, of the first and last clocks. We use these indices to
	# obtain the value of the first and last clocks as well. In the process
	# we get a count of errors in the data block. Note that the last clock
	# in the interval is not the one that marks the beginning of the next
	# interval, but the one before that, which we obtain with the index -1.
	# We set the num_errors parameter so it contains the number of clock 
	# message errors in the interval data.
	set clocks [lwdaq_recorder $info(data_image) \
		"-payload $config(player_payload_length) \
			-size $info(data_size) clocks 0 -1"]
	scan $clocks %d%d%d%d%d info(num_errors) num_clocks num_messages first_index last_index
	set indices [lwdaq_recorder $info(data_image) \
		"-payload $config(player_payload_length) \
			-size $info(data_size) get $first_index $last_index"]
	set first_clock [lindex $indices 1]
	set last_clock [lindex $indices 4]

	# The first problem we look for is a jump in the clock value between the
	# end of the previous interval and the start of this interval. This jump
	# does not take place within our new interval, but is a mismatch between
	# two neighboring intervals. If we encounter such a jump, we issue a 
	# warning. In either case, we set a initial skip variable to indicate the
	# extent of the initial skip, if any.
	if {([expr $first_clock - $info(play_previous_clock)] != 1) \
			&& (($info(play_previous_clock) != $info(max_sample)) \
					|| ($first_clock != 0)) \
			&& ($info(play_previous_clock) != -1)} {
		set initial_skip [expr ($first_clock - $info(play_previous_clock)) \
			/ $info(clocks_per_second) ]
		if {$initial_skip <= 0} {
			set initial_skip [expr $initial_skip + \
				1.0 * ($info(max_sample)+1) / $info(clocks_per_second) ]
		}
		Neuroarchiver_print "WARNING: Loss of at least $initial_skip s\
			at $config(play_time) s in [file tail $config(play_file)]."
	} {
		set initial_skip 0.0
	}

	# We determine the time span of this interval, as indicated by the clock
	# messages it contains. We trust that the interval contains at least the
	# required number of clocks, so it must span at least the play interval.
	set display_span $info(play_interval_copy)
	if {$info(num_errors) > 0} {
		set display_span [expr 1.0 * \
			($last_clock - $first_clock + 1) / \
			$info(clocks_per_second)]
		while {$display_span < $info(play_interval_copy)} {
			set display_span [expr $display_span + \
				1.0 * ($info(max_sample) + 1) / $info(clocks_per_second)]
		}
	}
	
	# We report upon the number of errors within this interval, as provided 
	# by the lwdaq_recorder routine.
	if {$info(num_errors) > 0} {
		Neuroarchiver_print "WARNING: Encountered $info(num_errors) errors\
			in [file tail $config(play_file)] between $config(play_time) s and\
			[expr $config(play_time) + $info(play_interval_copy)] s."
	}	

	# If the time span is greater than the play interval, the interval contains
	# some kind of corruption. In verbose mode, we inform the user.
	if {$display_span > $info(play_interval_copy)} {
		Neuroarchiver_print "Missing\
			[format %.2f [expr $display_span - $info(play_interval_copy)]] s\
			after $config(play_time) s,\
			display spans [format %.2f $display_span] s." verbose
	}
	
	# We show the raw message data in the text window if the user wants to see
	# it in verbose mode, or if we have encountered an error in verbose mode.
	if {($config(show_messages) || ($info(num_errors) > 0)) && $config(verbose)} {
		set report [lwdaq_recorder $info(data_image) \
			"-payload $config(player_payload_length) \
				-size $info(data_size) print 0 1"]
		if {[regexp {index=([0-9]*) } $report match index]} {
			if {$config(show_messages) > $info(min_show_messages)} {
				set extent [expr $config(show_messages)/2]
			} {
				set extent [expr $info(min_show_messages)/2]
			}
			set lo_index [expr $index - $extent] 
			if {$lo_index < 0} {set lo_index 0}
			set hi_index [expr $index + $extent]
			if {$hi_index < $lo_index + 2*$extent} {set hi_index [expr $lo_index + 2*$extent]}
			Neuroarchiver_print [lwdaq_recorder $info(data_image) \
				"-payload $config(player_payload_length) \
					-size $info(data_size) print $lo_index $hi_index"]
		} {
			Neuroarchiver_print [lwdaq_recorder $info(data_image) \
				"-payload $config(player_payload_length) \
					-size $info(data_size) print 0 $config(show_messages)"]
		}
	}
	
	# If verbose, let the user know how many messages are included in this
	# interval. The total includes null messages, if corruption has introduced
	# them into the interval. The number of clocks should be equal to the 
	# interval length multiplied by the clock frequency, but in case of 
	# errors in playback, we print the number we are actually using.
	Neuroarchiver_print "Using $num_messages messages,\
		including $num_clocks clocks." verbose

	# Clear the Neuroarchiver graphs in preparation for new data.
	Neuroarchiver_fresh_graphs		
	
	# Clear the Neurotracker graphs.
	Neurotracker_fresh_graphs

	# Get a list of the available channel numbers and message counts.
	set channel_list [lwdaq_recorder $info(data_image) \
		"-payload $config(player_payload_length) \
			-size $info(data_size) list"]	

	# We make a list of the active channels.
	if {![LWDAQ_is_error_result $channel_list]} {
		set ca ""
		foreach {id qty} $channel_list {
			if {$qty > $config(activity_rate) * $info(play_interval_copy)} {
				if {($id >= $info(min_id)) && ($id <= $info(max_id))} {
					lappend ca "$id:$qty"
				}
			}
		}
		set info(channel_activity) $ca
	} {
		Neuroarchiver_print $channel_list
		set info(channel_activity) ""
		set channel_list ""
	}

	# We change channel alerts to "None" for channels that are not active.
	foreach id $info(calib_selected) {
		if {[lsearch $info(channel_activity) "$id\:*"] < 0} {
			set info(f_alert_$id) "None"
		}
	}

	# We select some or all active channels based on the channel_select
	# string entered by the user.
	if {[string trim $config(channel_select)] == "*"} {
		set channels ""
		foreach {id qty} $channel_list {
			if {($qty > ($config(activity_rate) * $info(play_interval_copy))) \
				&& ($id >= $info(min_id)) \
				&& ($id <= $info(max_id)) } {
				lappend channels "$id"
			}
		}
	} {
		set channels $config(channel_select)
	}
	
	# We read the processor script from disk.
	set result ""
	set en_proc $config(enable_processing)
	if {$en_proc} {
		if {![file exists $config(processor_file)]} {
			set result "ERROR: Processor script $config(processor_file) does not exist."
		} {
			set f [open $config(processor_file) r]
			set info(processor_script) [read $f]
			close $f
		}
	}
	
	# We apply processing to each channel for this interval, plot the signal,
	# and plot the spectrum, as enabled by the user. We set the force_vt flag
	# to zero, which means the value versus time plot will be drawn only if
	# enable_vt is set, or if the processor itself sets force_vt in one of
	# its plotting routines.
	set info(force_vt) 0
	foreach info(channel_code) $channels {
		set info(channel_num) [lindex [split $info(channel_code) :] 0]
		if {![string is integer -strict $info(channel_num)] \
				|| ($info(channel_num) < $info(clock_id)) \
				|| ($info(channel_num) > $info(max_id))} {
			set result "ERROR: Invalid channel number \"$info(channel_num)\"."
			set info(play_control) "Stop"
			break
		}
		set info(signal) [Neuroarchiver_signal]
		set info(values) [Neuroarchiver_values]
		if {$config(enable_af) || $config(af_calculate)} {
			set info(spectrum) [Neuroarchiver_spectrum]
		}
		if {$config(enable_vt)} {Neuroarchiver_plot_signal}
		set info(t_min) $config(play_time)
		if {$config(enable_af)} {Neuroarchiver_plot_spectrum}
		if {$config(lt_calculate) || [winfo exists $info(tracker_window)]} {
			Neurotracker_extract
		} 
		if {[winfo exists $info(tracker_window)]} {
			Neurotracker_plot
		}
		if {[winfo exists $info(export_panel)]} {
			Neuroarchiver_export "Play"
			if {$info(play_control) == "Stop"} {
				break
			}
		}
		if {![LWDAQ_is_error_result $result] && $en_proc} {
			if {[catch {eval $info(processor_script)} error_result]} {
				set result "ERROR: $error_result"
				if {[regexp -nocase {ABORTING} $error_result]} {
					set info(play_control) "Stop"
					break
				}
			}
		}
		LWDAQ_support
	}
	
	# We check the processing result for errors, report to the screen, and write
	# to characteristics file. We also hand control over to the Neuroclassifier
	# if it's running. All the Neuroclassifier needs to plot and classify the most
	# recent interval is the results of processing, which will, we assume, contain
	# the metrics the Neuroarclassifier is expecting to receive.
	if {$result != ""} {
		if {![LWDAQ_is_error_result $result]} {
			set result "[file tail $config(play_file)] $config(play_time) $result"
		}
		if {[LWDAQ_is_error_result $result] \
			|| [regexp {^WARNING: } $result] \
			|| !$config(quiet_processing)} {
			Neuroarchiver_print $result
		}
		if {$config(save_processing)} {
			set cfn [file root [file tail $config(play_file)]]_[\
				regsub {\.tcl} [file tail $config(processor_file)] .txt]
			set cfn [file join [file dirname $config(processor_file)] $cfn]
			if {[catch {
				if {$info(player_buffer) != ""} {
					set data_backlog 1
				} {
					set data_backlog 0
				}
				append info(player_buffer) "$result\n"
				LWDAQ_print -nonewline $cfn $info(player_buffer)
				set info(player_buffer) ""
				if {$data_backlog} {
					Neuroarchiver_print "WARNING: Wrote buffered characteristics to\
						[file tail $cfn] after previous write failure."		
				}
			} error_result]} {
				if {!$data_backlog} {
					Neuroarchiver_print "WARNING: Could not write to [file tail $cfn],\
						permission denied, buffering characteristics."
				}
			}
		}
		if {![LWDAQ_is_error_result $result] \
				&& [winfo exists $info(classifier_window)]} {
			Neuroclassifier_processing $result
		}

	} {
		if {$config(save_processing) && !$config(enable_processing)} {
			Neuroarchiver_print "WARNING: Processing is disabled, so will not be saved."
		}
	}
	
	# Turn the label back to white before we plot the graphs. This gives the
	# label a better flash behavior during rapid playback.
	LWDAQ_set_bg $info(play_control_label) white
	LWDAQ_update

	# Draw the graphs on the screen if the graphics are enabled.
	Neuroarchiver_draw_graphs
	Neurotracker_draw_graphs
	
	# Play any video that needs to be played, specifying the current play time as a
	# Unix time, and the current interval length.
	if {$config(video_enable)} {
		Neuroarchiver_video_action \
			"Play" \
			[Neuroarchiver_datetime_convert $info(datetime_play_time)] \
			$info(play_interval_copy)		
	} 
	
	# We set the new previous clock to the last clock of this interval.
	set info(play_previous_clock) $last_clock
		
	# Our new play index will be the previous index plus the end index of the 
	# interval we just played. 
	set config(play_index) [expr $config(play_index) + $end_index]
	
	# The new play time will be the the old play time plus the interval length,
	# regardless of whaterver errors we may have encountered in the data.
	set config(play_time) [Neuroarchiver_play_time_format \
		[expr $config(play_time) + $info(play_interval_copy)]]
	set info(saved_play_time) $config(play_time)
	
	# We update the time values of the Player Date and Time window, and format
	# the play time in the Player window.
	Neuroarchiver_datetime_update
		
	# Post another execution of this routine to the queue, or terminate.
	if {$info(play_control) == "Play"} {
		LWDAQ_post Neuroarchiver_play
	} {
		set info(play_control) "Idle"
	}

	return $result
}

#
# Neuroarchiver_jump displays an event. We can pass the event directly to the
# routine, or we can a keyword that directs the routine to select an event from
# an event list, or to move to the archive preceeding or following the current
# playback archive. An event list is a file on disk. Each line in such a file
# must itself be an event. And event is a list of values. The first two elements
# in the list give the location of the event. The location can be specified with
# a file name and an file time in seconds from the file start, or as an absolute
# date-time string and an offset in seconds from that time. The third element in
# the list is a selection string, which lists the channel numbers involved in
# the event. If the selection string is a list of numbers, the jump routine sets
# the Player's select string to the event selection string. If the selection
# string is "*", the Player's channel select string will be set to "*" and all
# channels will be selected after the jump. If the string is "?", the Player's
# channel select string will be left unchanged. We can suppress the alteration
# of the Player's select string by setting the Neuroarchiver configuration
# parameter "isolate_events" to 0. If, instead of an event string composed of
# event elements, we pass one of the keywords "Back", "Go", "Step", "Hop",
# "Play", or "Stop" the routine will read the current event list from disk and
# select one of its events for display, just as if this event were passed to the
# jump routine. The Back, Go, and Step keywords instruct the jump routine to
# decrement, leave unaltered, or increment the Neuroarchiver's event_index. The
# Hop keyword instructs the jump routine to select an event at random from the
# list, by setting the event_index to a random number between one and the event
# list length. We use the Hop instruction to move at random in large event lists
# to perform random sampling for confirmation of effective event classification.
# The Play instruction causes the Neuroarchiver to move through the event list,
# displaying each event as fast as it can. The Stop instruction stops the Play
# instruction but does nothing else. The jump routine will set the baseline
# powers in preparation for display and processing, according to the
# jump_strategy parameter. If this is "local" we use the current baseline
# powers, if "read" we read them from the archive metadata using the baseline
# power name in the Baselines Panel. If it is "event" we assume the fourth
# element in the event list is a keyword describing the event and the fifth
# element is the baseline power we should apply to the selected channels.
# Another option is "verbose", which if set to zero, suppresses the event
# description printout in the Neuroarchiver text window. The "Next_NDF",
# "Current_NDF", "Previous_NDF" keywords jump to the start of the next, current,
# or previous NDF files in the alphabetical list of archives in the playback
# directory tree.
#
proc Neuroarchiver_jump {{event ""} {verbose 1}} {
	upvar #0 Neuroarchiver_info info
	upvar #0 Neuroarchiver_config config

	# If the event is anything other than the Play instruction,
	# we clear every pending Neuroarchiver_jump event in the 
	# LWDAQ event queue so that this event will stop all jump
	# activity when it completes.
	if {$event != "Play"} {
		LWDAQ_queue_clear "Neuroarchiver_jump*"
	}	

	# If the event is the Stop keyword, we make sure the list file
	# background is gray and we return. Otherwise, we set the background
	# to orange and allow the window manager to draw the new color.
	if {($event == "Stop") } {
		LWDAQ_set_bg $info(play_control_label) white	
		return ""
	} {
		LWDAQ_set_bg $info(play_control_label) orange
		LWDAQ_update
	}

	# In order to jump to the next or preceeding file, we must obtain
	# a list of NDFs in the playback directory tree, so as to identify
	# the next or preceeding file.
	if {[lsearch "Next_NDF Current_NDF Previous_NDF" $event] >= 0} {
		# We obtain a list of all NDF files in the play_dir directory tree. If
		# can't find the current file in the directory tree, we abort.
		set fl [LWDAQ_find_files $config(play_dir) *.ndf]
		set fl [LWDAQ_sort_files $fl]
		set index [lsearch $fl $config(play_file)]
		if {$index < 0} {
			set error_message "ERROR: Cannot find current play file\
				in playback directory tree."
			Neuroarchiver_print $error_message
			LWDAQ_set_bg $info(play_control_label) white
			return $error_message
		}
		
		# We see if there is a next or previous file in the directory tree. 
		if {$event == "Next_NDF"} {set file_name [lindex $fl [expr $index + 1]]}
		if {$event == "Previous_NDF"} {set file_name [lindex $fl [expr $index - 1]]}
		if {$event == "Current_NDF"} {set file_name [lindex $fl [expr $index]]}
		if {$file_name == ""} {
			set error_message "ERROR: No matching file in playback directory tree."
			Neuroarchiver_print $error_message
			LWDAQ_set_bg $info(play_control_label) white		
			return $error_message
		}

		# We compose an event out of the new NDF file name and time zero.
		set event "[file tail $file_name] 0.0 ? $event"
		Neuroarchiver_print "Playback switching to $file_name."
	}
	 
	# The repeat flag will be set by the Play event keyword. Otherwise
	# it's going to stay zero and we'll use the flag to control subsequent
	# play-related actions.
	set repeat 0
	
	# If the event is an event list action keyword, we read in the 
	# event file, adjust the event index and pick the event_index'th 
	# event in the file, with event one being the first.
	if {[lsearch "Back Go Step Hop Play Stop" $event] >= 0} {
		if {![file exists $config(event_file)]} {
			set error_message "ERROR: Cannot find \"[file tail $config(event_file)]\"."
			Neuroarchiver_print $error_message
			LWDAQ_set_bg $info(play_control_label) white	
			return $error_message
		}
	
		set f [open $config(event_file) r]
		set event_list [split [string trim [read $f]] \n]
		close $f
		
		if {[llength $event_list] < 1} {
			set error_message "ERROR: Empty event list."
			Neuroarchiver_print error_message
			LWDAQ_set_bg $info(play_control_label) white		
			return $error_message
		}
	
		set info(num_events) [llength $event_list]

		switch $event {
			"Back" {incr config(event_index) -1}
			"Step" {incr config(event_index) +1}
			"Hop"  {set config(event_index) [expr round(rand()*$info(num_events))]}
			"Step" {incr config(event_index) +1}
			"Play" {
				incr config(event_index) +1
				set repeat 1
			}
		}
		
		if {$config(event_index) < 1} {
			set config(event_index) 1
		}
		if {$config(event_index) >= $info(num_events)} {
			set config(event_index) $info(num_events)
			set repeat 0
		}

		set event [lindex $event_list [expr $config(event_index)-1]]
	}
		
	# If the event contains an archive name and a play time, we try to find
	# the archive in the playback directory tree, and jump to the specified
	# time within that archive.
	if {([string match -nocase *.ndf [lindex $event 0]]) \
			&& ([string is double [lindex $event 1]])} {

		# Try to find the event NDF file in the playback directory tree.
		set fl [LWDAQ_find_files $config(play_dir) *.ndf]
		set pft [lindex $event 0]
		set index [lsearch $fl "*[lindex $event 0]"]
		if {$index < 0} {
			set error_message "ERROR: Cannot find $pft in $config(play_dir)."
			Neuroarchiver_print $error_message
			LWDAQ_set_bg $info(play_control_label) white
			return $error_message
		}
		set pf [lindex $fl $index]
		if {[catch {LWDAQ_ndf_data_check $pf} error_message]} {
			set error_message "ERROR: Checking archive, $error_message."
			Neuroarchiver_print $error_message
			LWDAQ_set_bg $info(play_control_label) white		
			return $error_message
		}
		
		# Set the play file and play time to match this event.
		set config(play_file) $pf
		set info(play_file_tail) [file tail $pf]
		set config(play_time) [Neuroarchiver_play_time_format \
		  [expr [lindex $event 1] + $config(jump_offset)]]

	# If the event contains an absolute time, as an integer number of seconds 
	# since 1970, we find the archive with start time closest before the absolute
	# time, and see if we can jump to the correct absolute time within this
	# archive.
	} elseif {([regexp {^[0-9]{10}$} [lindex $event 0] datetime]) \
			&& ([string is double [lindex $event 1]])} {
			
		# Our desired time is the clock time plus an offset in the
		# second event parameter. We add whole seconds of this offset
		# to the absolute time, leaving only the fractional time in
		# the offset.
		set offset [expr fmod([lindex $event 1],1.0)]
		set datetime [expr round($datetime + [lindex $event 1] - $offset)]
		
		# We focus on files with names in the form *xxxxxxxxxx.ndf, where the 
		# ten x's are the digits of the archive's start time and the * is a 
		# prefix, which is by default "M". We find the one that starts soonest 
		# before our target time.
		set fl [LWDAQ_find_files $config(play_dir) *??????????.ndf]
		set fl [LWDAQ_sort_files $fl]
		set pf ""
		set atime 0
		foreach fn $fl {
			if {[regexp {([0-9]{10})\.ndf$} [file tail $fn] match newtime]} {
				if {($newtime <= $datetime) && ($newtime > $atime)} {
					set pf $fn
					set atime $newtime
				}
			}
		}
		if {$pf == ""} {
			set error_message "ERROR: Cannot find\
				\"[Neuroarchiver_datetime_convert $datetime]\"\
				in $config(play_dir)."
			Neuroarchiver_print $error_message
			LWDAQ_set_bg $info(play_control_label) white	
			return $error_message
		}
		if {[catch {LWDAQ_ndf_data_check $pf} error_message]} {
			set error_message "ERROR: Checking archive, $error_message."
			Neuroarchiver_print $error_message
			LWDAQ_set_bg $info(play_control_label) white		
			return $error_message
		}

		# We have an archive starting before our target time. Now we check
		# to see if the archive extends as far as our target time.
		set alen [Neuroarchiver_end_time $pf]
		if {$alen + $atime < $datetime + $offset + $info(play_interval_copy)} {
			set error_message "ERROR: Cannot find\
				\"[Neuroarchiver_datetime_convert $datetime]\"\
				in $config(play_dir)."
			Neuroarchiver_print $error_message
			LWDAQ_set_bg $info(play_control_label) white		
			return $error_message
		}
		
		# Set the play file and play time to match this event.
		set config(play_file) $pf
		set info(play_file_tail) [file tail $pf]
		set config(play_time) [Neuroarchiver_play_time_format \
			[expr $datetime + $offset - $atime] ]
	} else {
		set error_message "ERROR: Invalid event \"[string range $event 0 60]\"."
		Neuroarchiver_print $error_message
		LWDAQ_set_bg $info(play_control_label) white		
		return $error_message
	}
	
	# If event isolation is turned on, we adjust the Player's channel 
	# select string according to the event's channel select string.
	if {$config(isolate_events)} {
		set cs [lindex $event 2]
		if {$cs != "?"} {
			set config(channel_select) $cs
		}
	}
	
	# Display the event in the text window with a jump button.
	if {$verbose} {Neuroarchiver_print_event $event}
	
	# Set up the baseline powers according to the jump configuration in the
	# Baselines Panel. If we are supposed to use the baseline calibration in
	# the event description, we try to extract one baseline for each channel
	# listed in event.
	switch $config(jump_strategy) {
		"read" {
			Neuroarchiver_baselines_read $config(bp_name)
		}
		"event" {
			set index 0
			foreach id [lindex $event 2] {
				set bp [lindex $event 4 $index]
				if {[string is double -strict $bp]} {set info(bp_$id) $bp}
				incr index
			}
		}
		default {
		# In all other cases we do nothing, and use the current baseline power.
		}
	}
	
	# We execute the jump in the command routine.
	Neuroarchiver_command play "Step"
	
	# If we are playing through and archive, post another jump to the queue.
	# Otherwise, make sure the file name background is gray.
	if {$repeat} {
		LWDAQ_post [list Neuroarchiver_jump "Play"]
	} {
		LWDAQ_set_bg $info(event_file_label) lightgray
	}
	
	# We return the event.
	return $event
}

#
# Neuroarchiver_video_download downloads the Videoarchiver zip archive with the
# help of a web browser.
#
proc Neuroarchiver_video_download {} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info

	set result [LWDAQ_url_open $info(video_library_archive)]
	if {[LWDAQ_is_error_result $result]} {
		LWDAQ_print $info(text) $result
		return "ERROR"
	} else {
		return "SUCCESS"
	}
}

#
# Neuroarchiver_video_suggest prints a message with a text link suggesting that
# the user download the Videoarchiver directory to install ffmpeg and mplayer.
#
proc Neuroarchiver_video_suggest {} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info

	LWDAQ_print $info(text) ""
	LWDAQ_print $info(text) \
		"ERROR: Cannot play videos, Videoarchiver package not installed."
	LWDAQ_print $info(text) \
		"  To install libraries, click on the link below which will download a zip archive."
	$info(text) insert end "           "
	$info(text) insert end \
		"$info(video_library_archive)" "textbutton download"
	$info(text) tag bind download <Button> Neuroarchiver_video_download
	$info(text) insert end "\n"
	LWDAQ_print $info(text) \
		"  After download, expand the zip archive. Move the entire Videoarchiver directory into\n \
		your LWDAQ directory so as to create a directory LWDAQ/Videoarchvier. You now have\n \
		Mplayer and FFMpeg installed for use by both the Videoarchiver and the Neuroarchiver\n \
		on Linux, MacOS, and Windows. You may begin video playback in the Neuroarchiver immediately."
}

#
# Neuroarchiver_video_duration calls ffmpeg to determine the duration of an existing video
# file. If the file does not exist, the routine returns -1, otherwise it returns the length
# of the video in seconds.
#
proc Neuroarchiver_video_duration {{fn ""}} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info
	
	if {$fn == ""} {
		set fn $info(video_file)
		if {![file exists $fn]} {return -1}
	}
	
	catch {[exec $info(ffmpeg) -i $fn]} answer
	if {[regexp {Duration: ([0-9]*):([0-9]*):([0-9\.]*)} $answer match hr min sec]} {
		scan $hr %d hr
		scan $min %d min
		scan $sec %f sec
		set duration [expr $hr*3600+$min*60+$sec]
	} else {
		return -1
	}
	
	return $duration
}

#
# Neuroarchiver_video_watchdog waits for the existing video to play for one
# play interval and then stops the video.
#
proc Neuroarchiver_video_watchdog {pid} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info

	if {![info exists config]} {
		LWDAQ_process_stop $pid
		return "Idle"
	}

	if {$info(gui) && ![winfo exists $info(window)]} {
		LWDAQ_process_stop $pid
		return "Idle"
	}

	if {!$config(video_enable)} {
		set info(video_state) "Idle"
		LWDAQ_process_stop $pid
		LWDAQ_set_bg $info(play_control_label) white
		return "Idle"
	}
	
	if {$info(video_process) != $pid} {
		LWDAQ_process_stop $pid
		return "Idle"
	}
	
	if {$info(video_state) == "Play"} {
		set vt "-1"
		set line ""

		if {[catch {
			puts $info(video_channel) "get_time_pos"
			set counter 0
			while {$vt < 0} {
				LWDAQ_support
				set line [gets $info(video_channel)]
				if {$line != ""} {
					if {[regexp {ANS_TIME_POSITION=([0-9]+\.[0-9]+)} $line match value]} {
						set vt $value
					} {
						LWDAQ_print $info(video_log) $line
					}
				} {
					incr counter
					if {$counter > $info(video_num_waits)} {
						set vt $info(video_end_time)
					} {
						LWDAQ_wait_ms $info(video_wait_ms)
					}
				}
			}
		} error_message]} {
			Neuroarchiver_print "Playback of $info(video_file) aborted." verbose
			LWDAQ_set_bg $info(play_control_label) white
			set info(video_state) "Idle"
			return $info(video_state)
		}

		if {$vt >= $info(video_stop_time)} {
			catch {puts $info(video_channel) "pause"}
			Neuroarchiver_print "Playback of $info(video_file)\
				paused at video time $vt s." verbose
			LWDAQ_set_bg $info(play_control_label) white
			set info(video_state) "Idle"
		} elseif {$vt >= $info(video_end_time) - ($info(video_wait_ms)/1000.0)} {
			Neuroarchiver_print "Playback of $info(video_file)\
				stopped at video end $info(video_end_time) s." verbose
			LWDAQ_set_bg $info(play_control_label) white
			set info(video_state) "Idle"
		}
	}

	LWDAQ_post [list Neuroarchiver_video_watchdog $pid]
	return $info(video_state)
}

#
# Neuroarchiver_video_action finds the video file and video internal time that
# corresponds to the specified Unix time. The routine uses a cache of
# recently-used video files to save time when searching for the correct file,
# because the search requires that we get the length of the video calculated by
# ffmpeg, and this calculation is time-consuming. If the video is not in the
# cache, we use the video directory as a source of video files. We pass three
# parameters to the routine: a command "cmd", a Unix time in seconds "datetime",
# and an interval length in seconds "length". The command is  "Seek" by default.
# The Seek command returns the name of the video containing the datetime, the
# time within the video that corresponds to the datetime, and the duration of
# the video. The Play command plays the video starting at datetime and going on
# for length seconds.
# 
proc Neuroarchiver_video_action {cmd datetime length} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info
	
	# Check to see if ffmpeg and mplayer are available. If not, we suggest
	# downloading the Videoarchiver package and go to idle state.
	if {![file exists $info(ffmpeg)] || ![file exists $info(mplayer)]} {
		Neuroarchiver_video_suggest
		set info(video_state) "Idle"
		return ""
	}

	# Look in our video file cache to see if the start and end of the 
	# requested interval is contained in a video we have already used.
	set vf ""
	set min_length [format %.1f [expr $info(video_min_interval_s)*0.5]]
	set camera_id [file tail $config(video_dir)]
	foreach entry $info(video_file_cache) {
		set fn [lindex $entry 0]
		set vtime [lindex $entry 1]
		set vlen [lindex $entry 2]
		set id [file tail [file dirname $fn]]
		if {($id == $camera_id) \
			&& ($vtime <= $datetime) \
			&& ($vtime + $vlen >= $datetime + $length) \
			&& ($vtime + $vlen - $datetime >= $min_length)} {
			set vf $fn
			break
		}
	}

	if {$vf != ""} {
		Neuroarchiver_print "Using cached video file $vf." verbose
	}
	
	# If we have not found a file that includes the start of the requested interval, 
	# look for one in the file system.
	if {$vf == ""} {
	
		# Make a list of video files in the camera directory.
		set fl [LWDAQ_find_files $config(video_dir) V??????????.mp4]
		set fl [LWDAQ_sort_files $fl]
	
		# Find the newest file that begins before the start of our interval.
		set vtime 0
		foreach fn $fl {
			if {[regexp {([0-9]{10})\.mp4$} [file tail $fn] match newtime]} {
				if {($newtime <= $datetime)} {
					set vf $fn
					set vtime $newtime
				} else {
					break
				}
			}
		}
		
		# If we still have no file, issue an error and exit.
		if {$vf == ""} {
			Neuroarchiver_print "ERROR: No video in [file tail $config(video_dir)]\
				begins before time $datetime s."
			return ""
		}

		# Calculate the video file length.
		set vlen [Neuroarchiver_video_duration $vf]

		# Check that the video file includes the start of the requested interval.
		if {($vtime + $vlen <= $datetime)} {
			Neuroarchiver_print "ERROR: File [file tail $vf], length $vlen s,\
				does not contain time $datetime s."
			return ""
		}
		
		# Check that the video file contains the interval end.
		set missing [expr ($datetime + $length) - ($vtime + $vlen)]
		if {$missing > 0} {
			Neuroarchiver_print "WARNING: File [file tail $vf] missing final\
				$missing s of requested interval."
		}

		# Add the video file to the cache. Keep the cache of finite length.
		lappend info(video_file_cache) [list $vf $vtime $vlen]
		if {[llength $info(video_file_cache)] > $info(max_video_files)} {
			set info(video_file_cache) [lrange $info(video_file_cache) 1 end]
		}

		Neuroarchiver_print "Adding video file $vf to video cache." verbose
	}

	# We calculate the time within the video recording that corresponds to the 
	# sought-after moment in the signal recording. If the resulting seek time is 
	# less than zero, we set it to zero.
	set vseek [expr $datetime - $vtime]
	if {$vseek < 0.0} {set vseek 0.0}
	
	# If we just want to find this point in the video, we exit now giving the
	# file name, seek position, and file length.
	if {$cmd == "Seek"} {
		return [list $vf $vseek $vlen]
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
		
		# Create Mplayer window with channel to write in commands and
		# read back answers.
		set info(video_channel) [open "| $info(mplayer) \
			-title \"Neuroarchiver Video Player for Camera $camera_id\" \
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

		# Start up the watchdog for this Mplayer process.
		LWDAQ_post [list Neuroarchiver_video_watchdog $info(video_process)]
	}

	# Set the end time of the video and the stop time.
	set info(video_end_time) [format %.1f $vlen]
	set info(video_stop_time) [format %.1f [expr $vseek + $length]]
	if {$info(video_stop_time) > $info(video_end_time)} {
		set info(video_stop_time) $info(video_end_time)
	}

	# Set the playback speed and seek the interval start.
	puts $info(video_channel) "pausing speed_set $config(video_speed)"
	puts $info(video_channel) "seek $vseek 2"
	
	# Set the video state to play and report the seek time.
	Neuroarchiver_print "Playing $vf for $length s\
		starting at time $vseek s of $vlen s." verbose
	LWDAQ_set_bg $info(play_control_label) cyan
	set info(video_state) "Play"
	
	# Return the file name, seek time and file duration.
	return [list $vf $vseek $vlen]
}

#
# Neuroarchiver_open creates the Neuroarchiver window, with all its buttons, boxes,
# and displays. It uses routines from the TK library to make the frames and widgets.
# To make sense of what the procedure is doing, look at the features in the 
# Neuroarchiver from top-left to bottom right. That's the order in which we 
# create them in the code. Frames enclose rows of buttons, labels, and entry 
# boxes. The images are TK "photos" associated with label widgets. The last thing
# to go into the Neuroarchiver panel is its text window.
#
proc Neuroarchiver_open {} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info
	
	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return 0}
	
	scan [wm maxsize .] %d%d x y
	wm maxsize $w [expr $x*2] [expr $y*2]
	
	set f $w.record
	frame $f
	pack $f -side top -fill x
	
	set f $w.record.a
	frame $f
	pack $f -side top -fill x

	label $f.control -textvariable Neuroarchiver_info(record_control) \
		-fg blue -width 8
	set info(record_control_label) $f.control
	pack $f.control -side left -expand yes

	foreach a {Record Stop Reset} {
		set b [string tolower $a]
		button $f.$b -text $a -command "Neuroarchiver_command record $a"
		pack $f.$b -side left -expand yes
	}
	
	label $f.ipl -text "IP:" -fg $info(label_color)
	entry $f.ipe -textvariable Neuroarchiver_config(daq_ip_addr) -width 14
	pack $f.ipl $f.ipe -side left -expand yes
	label $f.sl -text "Socket:" -fg $info(label_color)
	entry $f.se -textvariable Neuroarchiver_config(daq_driver_socket) -width 2
	pack $f.sl $f.se -side left -expand yes
	tk_optionMenu $f.mr Neuroarchiver_config(daq_receiver) \
		"A3018" "A3027" "A3032" "A3038A"
	pack $f.mr -side left -expand yes
	label $f.fvl -text "FV:" -fg $info(label_color)
	label $f.fvd -textvariable LWDAQ_info_Recorder(firmware_version) -width 2
	pack $f.fvl $f.fvd -side left -expand yes

	button $f.conf -text "Configure" -command "Neuroarchiver_configure"
	button $f.help -text "Help" -command "LWDAQ_tool_help Neuroarchiver"
	checkbutton $f.d -variable Neuroarchiver_config(verbose) -text "Verbose"
	pack $f.conf $f.help $f.d -side left -expand yes
	
	set f $w.record.b
	frame $f
	pack $f -side top -fill x
	
	label $f.a -text "Archive:" -anchor w -fg $info(label_color)
	pack $f.a -side left
	label $f.b -textvariable Neuroarchiver_info(record_file_tail) \
		-width 20 -bg $info(variable_bg)
	button $f.pick -text "Pick" -command "Neuroarchiver_command record Pick"
	button $f.pick_dir -text "PickDir" -command "Neuroarchiver_command record PickDir"
	button $f.metadata -text "Header" \
		-command "LWDAQ_post Neuroarchiver_metadata_header_edit"
	label $f.lac -text "End (s):" -fg $info(label_color) -width 6
	label $f.eac -textvariable Neuroarchiver_config(record_end_time) -width 6
	label $f.le -text "Autocreate (s):" -fg $info(label_color)
	entry $f.ee -textvariable Neuroarchiver_config(autocreate) -width 6
	pack $f.b $f.pick $f.pick_dir $f.metadata $f.lac $f.eac $f.le $f.ee \
		-side left -expand yes

	checkbutton $f.synch -variable Neuroarchiver_config(synchronize) -text "Synchronize"
	pack $f.synch $f.synch -side left -expand yes
	
	set f $w.displays
	frame $f -border 2
	pack $f -side top -fill x
	
	set f $w.displays.signal
	frame $f -relief groove -border 2
	pack $f -side left -fill y
	
	set f $w.displays.signal.title
	frame $f
	pack $f -side top -fill x

	checkbutton $f.enable -variable Neuroarchiver_config(enable_vt) -text "Enable" 
	label $f.title -text "Value vs. Time" -fg $info(title_color)
	pack $f.enable $f.title -side left -expand yes
	foreach a "SP CP NP" {
		set b [string tolower $a]
		radiobutton $f.$b -variable Neuroarchiver_config(vt_mode) \
			-text $a -value $a
		pack $f.$b -side left -expand yes
	}
#	button $f.magnify -text "Zoom" -command {Neuroarchiver_magnify_view vt}
#	pack $f.magnify -side left -expand yes

	set f $w.displays.signal
   	set info(vt_photo) [image create photo "_neuroarchiver_vt_photo_" \
   		-width $info(vt_plot_width) \
   		-height $info(vt_plot_height)]
	label $f.graph -image $info(vt_photo)
	pack $f.graph -side top -expand yes
	
	set f $w.displays.signal.controls
	frame $f
	pack $f -side top -fill x
	label $f.lv_offset -text "v_offset:" -fg $info(label_color)
	entry $f.ev_offset -textvariable Neuroarchiver_config(v_offset) -width 5
	pack $f.lv_offset $f.ev_offset -side left -expand yes
	label $f.lv_range -text "v_range:" -fg $info(label_color)
	entry $f.ev_range -textvariable Neuroarchiver_config(v_range) -width 5
	pack $f.lv_range $f.ev_range -side left -expand yes
	label $f.l_glitch -text "glitch_threshold:" -fg $info(label_color)
	entry $f.e_glitch -textvariable Neuroarchiver_config(glitch_threshold) -width 5
	pack $f.l_glitch $f.e_glitch -side left -expand yes
	label $f.lt_left -text "t_min:" -fg $info(label_color)
	label $f.et_left -textvariable Neuroarchiver_info(t_min) -width 7
	pack $f.lt_left $f.et_left -side left -expand yes
	
	set f $w.displays.spectrum
	frame $f -relief groove -border 2
	pack $f -side right -fill y
	
	set f $w.displays.spectrum.title
	frame $f 
	pack $f -side top -fill x
	
	label $f.title -text "Amplitude vs. Frequency" -fg $info(title_color)
	checkbutton $f.lf -variable Neuroarchiver_config(log_frequency) -text "Log"
	checkbutton $f.la -variable Neuroarchiver_config(log_amplitude) -text "Log"
	checkbutton $f.enable -variable Neuroarchiver_config(enable_af) -text "Enable"
	pack $f.la $f.title $f.lf $f.enable -side left -expand yes
#	button $f.magnify -text "Zoom" -command {Neuroarchiver_magnify_view af}
#	pack $f.magnify -side left -expand yes
	
	set f $w.displays.spectrum
   	set info(af_photo) [image create photo "_neuroarchiver_af_photo_" \
   		-width $info(af_plot_width) \
   		-height $info(af_plot_height)]
	label $f.graph -image $info(af_photo) 
	pack $f.graph -side top -expand yes
	
	set f $w.displays.spectrum.controls
	frame $f
	pack $f -side top -fill x
	foreach a {a_min a_max f_min f_max} {
		label $f.l$a -text "$a\:" -fg $info(label_color)
		entry $f.e$a -textvariable Neuroarchiver_config($a) \
			-relief sunken -bd 1 -width 5
		pack $f.l$a $f.e$a -side left -expand yes
	}

	set f $w.play
	frame $f -border 4
	pack $f -side top -fill x 

	set f $w.play.a
	frame $f
	pack $f -side top -fill x

	label $f.control -textvariable Neuroarchiver_info(play_control) -fg blue -width 8
	set info(play_control_label) $f.control
	pack $f.control -side left -expand yes

	foreach a {Play Step Stop Repeat Back} {
		set b [string tolower $a]
		button $f.$b -text $a -command "Neuroarchiver_command play $a"
		pack $f.$b -side left -expand yes
	}

	label $f.lrs -text "Interval (s):" -fg $info(label_color)
	tk_optionMenu $f.mrs Neuroarchiver_config(play_interval) \
		0.0625 0.125 0.25 0.5 1.0 2.0 4.0 8.0 16.0 32.0
	label $f.li -text "Time (s):" -fg $info(label_color)
	entry $f.ei -textvariable Neuroarchiver_config(play_time) -width 8
	pack $f.lrs $f.mrs $f.li $f.ei -side left -expand yes
	label $f.le -text "End (s):" -fg $info(label_color)
	label $f.ee -textvariable Neuroarchiver_info(play_end_time) -width 8 \
		-bg $info(variable_bg) -anchor w
	pack $f.le $f.ee -side left -expand yes
	checkbutton $f.seq -variable Neuroarchiver_config(sequential_play) -text "Seq"
	pack $f.seq -side left -expand yes
	button $f.export -text "Export" -command "LWDAQ_post Neuroarchiver_exporter_open"
	pack $f.export -side left -expand yes
	button $f.clock -text "Clock" -command "LWDAQ_post Neuroarchiver_datetime"
	pack $f.clock -side left -expand yes
	
	set f $w.play.ac
	frame $f -bd 1
	pack $f -side top -fill x

	label $f.al -text "Activity:" -anchor w -fg $info(label_color)
	pack $f.al -side left 
	label $f.ae -textvariable Neuroarchiver_info(channel_activity) \
		-width 120 -bg $info(variable_bg) -anchor w
	pack $f.ae -side left -expand yes

	set f $w.play.b
	frame $f -bd 1
	pack $f -side top -fill x

	label $f.a -text "Archive:" -anchor w -fg $info(label_color)
	pack $f.a -side left 
	label $f.b -textvariable Neuroarchiver_info(play_file_tail) \
		-width 20 -bg $info(variable_bg)
	button $f.pick -text "Pick" -command "Neuroarchiver_command play Pick"
	button $f.pickd -text "PickDir" -command "Neuroarchiver_command play PickDir"
	button $f.first -text "First" -command "Neuroarchiver_command play First"
	button $f.clist -text "List" -command {
		LWDAQ_post [list Neuroarchiver_list ""]
	}
	pack $f.b $f.pick $f.pickd $f.first $f.clist -side left -expand yes
	button $f.metadata -text "Metadata" -command {
		LWDAQ_post [list Neuroarchiver_metadata_view play]
	}
	pack $f.metadata -side left -expand yes
	button $f.overview -text "Overview" -command {
		LWDAQ_post [list LWDAQ_post Neuroarchiver_overview]
	}
	pack $f.overview -side left -expand yes
	button $f.baselines -text "Calibration" -command "Neuroarchiver_calibration"
	pack $f.baselines -side left -expand yes
	
	label $f.v -text "Video:" -fg $info(label_color)
	pack $f.v -side left -expand no
	button $f.vp -text "PickDir" -command "Neuroarchiver_pick video_dir 1"
	checkbutton $f.ve -variable Neuroarchiver_config(video_enable) -text "Enable"
	pack $f.vp $f.ve -side left -expand yes

	set f $w.play.c
	frame $f -bd 1
	pack $f -side top -fill x
		
	label $f.e -text "Processing:" -anchor w -fg $info(label_color)
	pack $f.e -side left 
	label $f.f -textvariable Neuroarchiver_info(processor_file_tail) \
		-width 16 -bg $info(variable_bg)
	button $f.g -text "Pick" -command "Neuroarchiver_pick processor_file 1"
	checkbutton $f.enable -variable Neuroarchiver_config(enable_processing) -text "Enable"
	checkbutton $f.save -variable Neuroarchiver_config(save_processing) -text "Save"
	checkbutton $f.quiet -variable Neuroarchiver_config(quiet_processing) -text "Quiet"
	pack $f.f $f.g $f.enable $f.save $f.quiet -side left -expand yes
	label $f.lchannels -text "Select:" -anchor e -fg $info(label_color)
	entry $f.echannels -textvariable Neuroarchiver_config(channel_select) -width 35
	pack $f.lchannels $f.echannels -side left -expand yes
	button $f.cb -text "Classifier" -command "LWDAQ_post Neuroclassifier_open"
	pack $f.cb -side left -expand yes
	button $f.tb -text "Tracker" -command "LWDAQ_post Neurotracker_open"
	pack $f.tb -side left -expand yes
	
	set f $w.play.d
	frame $f -bd 1
	pack $f -side top -fill x
		
	label $f.e -text "Events:" -anchor w -fg $info(label_color)
	pack $f.e -side left
	label $f.f -textvariable Neuroarchiver_info(event_file_tail) \
		-width 24 -bg $info(variable_bg)
	set info(event_file_label) $f.f
	button $f.g -text "Pick" -command "Neuroarchiver_pick event_file 1"
	pack $f.f $f.g -side left -expand yes
	foreach a {Hop Play Back Go Step Stop} {
		set b [string tolower $a]
		button $f.$b -text $a -command [list LWDAQ_post "Neuroarchiver_jump $a"]
		pack $f.$b -side left -expand yes
	}
	label $f.il -text "Index:"  -fg $info(label_color)
	entry $f.ie -textvariable Neuroarchiver_config(event_index) -width 5
	label $f.ll -text "Length:"  -fg $info(label_color)
	label $f.le -textvariable Neuroarchiver_info(num_events) -width 5
	button $f.mark -text Mark -command [list LWDAQ_post "Neuroarchiver_print_event"]
	pack $f.il $f.ie $f.ll $f.le $f.mark -side left -expand yes
	
	set info(text) [LWDAQ_text_widget $w 100 10 1 1]

	LWDAQ_bind_command_key $w Left {Neuroarchiver_command play Back}
	LWDAQ_bind_command_key $w Right {Neuroarchiver_command play Step}
	LWDAQ_bind_command_key $w greater {Neuroarchiver_command play Play}
	LWDAQ_bind_command_key $w Up [list LWDAQ_post {Neuroarchiver_jump Next_NDF 0}]
	LWDAQ_bind_command_key $w Down [list LWDAQ_post {Neuroarchiver_jump Previous_NDF 0}]
	LWDAQ_bind_command_key $w less [list LWDAQ_post {Neuroarchiver_jump Current_NDF 0}]
	$info(text) tag configure textbutton -background cyan
	$info(text) tag bind textbutton <Enter> {%W configure -cursor arrow} 
	$info(text) tag bind textbutton <Leave> {%W configure -cursor xterm} 
	
	return 1
}

#
# Neuroarchiver_close closes the Neuroarchiver and deletes its configuration and
# info arrays.
#
proc Neuroarchiver_close {} {
	upvar #0 Neuroarchiver_config config
	upvar #0 Neuroarchiver_info info
	global LWDAQ_Info
	if {$info(gui) && [winfo exists $info(window)]} {
		destroy $info(window)
	}
	array unset config
	array unset info
	return 1
}

Neuroarchiver_init
Neuroarchiver_open
Neuroarchiver_fresh_graphs 1
	
return 1

----------Begin Help----------

http://www.opensourceinstruments.com/Electronics/A3018/Neuroarchiver.html

----------End Help----------
