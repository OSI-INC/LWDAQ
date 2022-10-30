# Neuroplayer.tcl, A LWDAQ Tool to display, and analyze telemetry signals from 
# subcutanous transmitters.
#
# Copyright (C) 2007-2022 Kevan Hashemi, Open Source Instruments Inc.
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
# The Neuroplayer records signals from Subcutaneous Transmitters manufactured
# by Open Source Instruments. For detailed help, see:
#
# http://www.opensourceinstruments.com/Electronics/A3018/Neuroplayer.html
#
# The Neuroplayer reads NDF (Neuroscience Data Format) files from disk. It
# provides play-back of data stored on file, with signal plotting and
# processing.
#

#
# Neuroplayer_init creates the info and config arrays and the images the
# Neuroplayer uses to hold data in memory. The config array is available through
# the Config button but the info array is private. We select the mode in which
# the Neuroplayer should operate by means of the global Neuroplayer_mode
# variable. If this is not set, or if it is set to "Main", we create a new
# toplevel window and construct the Neuroplayer interface in this new window. If
# the mode is set to "Standalone" we take over the LWDAQ main window and
# construct in it the Neuroplayer interface.
#
proc Neuroplayer_init {} {
#
# Here we declare the names of variables we want defined at the global scope.
# Such variables may exist before this procedure executes, and they will endure
# after the procedure concludes. The "upvar #0" assigns a local name to a global
# variable. After the following line, we can, for the duration of this
# procedure, refer to the global variable "Neuroplayer_info" with the local
# name "info". The Neuroplayer_info variable happens to be an array with a
# bunch of "elements". Each element has a name and a value. Here we will refer
# to the "name" element of the "Neuroplayer_info" array with info(name).
#
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	global LWDAQ_Info Neuroplayer_mode
#
# We initialise the Neuroplayer with LWDAQ_tool_init. Because this command
# begins with "LWDAQ" we know that it's one of those in the LWDAQ command
# library. We can look it up in the LWDAQ Command Reference to find out more
# about what it does.
#
	LWDAQ_tool_init "Neuroplayer" "160"
#
# If a graphical tool window already exists, we abort our initialization.
#
	if {[winfo exists $info(window)]} {
		return "ABORT"
	}
#
# We start setting intial values for the private display and control variables.
#
	set info(play_control) "Idle"
	set info(play_control_label) "none"
#
# The Neuroplayer uses four LWDAQ images to hold data. The vt_image and
# af_image are those behind the display of the signal trace and the signal
# spectrum respectively. The buffer_image and data_image are used by the
# play-back process to buffer data from disk and pass data to the Receiver
# Instrument analysis routines respectively.
#
	set info(vt_image) "_Neuroplayer_vt_image_"
	set info(af_image) "_Neuroplayer_af_image_"
	set info(data_image) "_Neuroplayer_data_image_"
	set info(buffer_image) "_Neuroplayer_buffer_image_"
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
	lwdaq_image_create -name $info(vt_image) \
		-width $info(vt_plot_width) \
		-height $info(vt_plot_height) 
	set info(af_plot_width) 400
	set info(af_plot_height) 250
	lwdaq_image_create -name $info(af_image) \
		-width $info(af_plot_width) \
		-height $info(af_plot_height) 
#
# Here we specify names for the windows that open up when we click on the
# voltage-time or amplitude-frequency plots.
#
	set info(vt_view) $info(window)\.vt_view_window
	set info(af_view) $info(window)\.af_view_window
#
# The size of the data and buffer images gets set here. We want both images to
# be large enough to hold the biggest block of messages the Neuroplayer is
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
# data and buffer images. When we read from disk, we must read a whole number
# of messages. If the block size specified below is not a whole number of messages,
# the read from disk will adjust its value.
#
	set info(block_size) [expr $width * $width / 10]
#
# Properties of data messages.
#
	set info(core_message_length) 4
	set info(player_payload) 0
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
# To permit identification of corrupted archives, we specify a maximum number of
# consecutive non-clock messages in the data stream, which is the maximum number of
# samples we could find between two 128-Hz clock messages.
#
	set info(max_consecutive_non_clocks) 1000
# 
# The number of messages records in data and buffer. Includes null messages that
# may be generated by corruption of a recording.
#
	set info(buffer_size) 0
	set info(data_size) 0
	set info(max_buffer_bytes) [expr $width * $width]
#
# The file overview window is an extension of the Neuroplayer that allows us
# to work with an overview of a file's contents to select sections for
# play-back.
#
	set config(overview_num_samples) 20000
	set config(overview_activity_fraction) 0.01
	set info(overview_width) 1000
	set info(overview_height) 250
	set info(overview_image) "_Neuroplayer_ov_image_"
	lwdaq_image_destroy $info(overview_image)
	lwdaq_image_create -width $info(overview_width) \
		-height $info(overview_height) \
		-name $info(overview_image)
	set info(overview_fsd) 2
#
# During play-back and processing, we step through each channel selected by the
# user with the channel_selector parameter. For each channel we create a graph
# of its signal versus time, which we display in the v-t window, and its
# amplitude versus frequency, which we display in the a-t window. The empty
# value for these two graphs is a point at the origin. When we have real data in
# the graphs, each graph point is two numbers: an x and y value, which would
# give time and value or frequency and amplitude. Note that the info(signal) and
# info(spectrum) elements are strings of characters. Their x-y values are
# represented as characters giving each number, with each number separated from
# its neighbors by spaces. On the one hand, handling numbers as strings is
# computationally intensive. On the other hand, the string-handling routines
# provided by TCL make it easy for us to write code that handles numbers in
# strings. As computers have become more powerful, passing numbers around in
# strings has become more practical. On a 1-GHz or faster computer, the
# Neuroplayer Version can perform its most extensive signal processing on
# fourteen 512 SPS message streams faster than the messages come in.
#
	set info(channel_code) "0"
	set info(channel_num) "0"
	set info(signal) "0 0"
	set info(spectrum) "0 0"
	set info(values) "0"
#
# Parameters that handle auxilliary messages.
#
	set info(aux_messages) ""
	set config(aux_num_keep) 100
	set config(aux_list_length) 0
#
# Any channel with a activity_threshold samples per second in the playback
# interval will be considered active. 
#
	set config(activity_threshold) 14
#
# During play-back, we obtain a list of all channels in which there exists
# at least one sample. From this list we select any channels from which we
# have received more than activity_threshold samples per second. We include
# these in the active_channels string. Each element of the string takes
# the form "id:qty" where id is the channel number and qty is the number of
# samples received during the playback interval.
#
	set info(active_channels) ""
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
# We set the array of selected frequencies for reconstruction to an empty
# string. During reconstruction, we will set them to a value picked from the
# default frequency string. We also have a f_alert parameter for each channel,
# that we set to "Extra" if we have too many, "Poor" if we have too few, "None"
# if the channel has not been active yet, "Okay" if we have the correct number,
# and "Gone" if it was active once, but has since vanished. Once the channel
# becomes inactive, it's most recent alert remains in place.
#
	for {set id $info(min_id)} {$id <= $info(max_id)} {incr id} {
		set info(qty_$id) "0"
		set info(sps_$id) "0"
		set info(status_$id) "None"
	}
	set config(min_reception) 0.8
	set config(max_rejection) 0.2
	set config(glitch_threshold) 1000
	set config(glitch_count) 0
	set info(max_window_fraction) 0.5
	set config(extra_fraction) 1.1
	set config(calibration_include) "Okay Loss Extra"
	set info(calibration_selected) ""
	set config(activity_include) "Okay Loss Extra Off"
	set info(activity_selected) ""
	set config(activity_rows) 23
#
# When we read and write sets of baseline powers to archive metadata, we can use
# a name to distinguish different sets stored therein, or we can opt for no name
# at all, which is how things were before Neuroplayer version 80.
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
# to force a more distinct color on two traces. The Neuroplayer_color
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
# Neuroplayer uses to record, play back, process, and report.
#
	set config(play_file) [file join $LWDAQ_Info(program_dir) Images M1361626536.ndf]
	set config(play_dir) [file dirname $config(play_file)]
	set config(processor_file) [file join $config(play_dir) Processor.tcl]
	set config(event_file) [file join $config(play_dir) Events.txt]
#
# The verbose flag tells the Neuroplayer to print more process
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
	set info(sequential_block_length) 100000
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
# The channel list tells the play-back process which channels it should extract
# from the message blocks for analysis. If we want reconstruction of the signal,
# which eliminates bad messages and replaces missing messages, we must specify
# the correct message frequency and the extent of the transmission scatter
# implemented by the tranmsitter. The phrase "5:512:8" specifies channel 5 with
# frequency 512 and scatter 8. We have default values for frequency, which will
# be used if we do not specify values.
#
	set config(channel_selector) "*"
	set config(default_frequency) "128 256 512 1024 2048 4096"
	set info(standing_values) ""
#
# We save the last clock message value in each message block so we can compare it 
# to the first message in the next message block. If the two are not consecutive,
# we issue a warning. The code for "undefined" is -1.
#
	set info(play_previous_clock) -1
#
# The Neuroplayer provides several steps of signal processing. We can turn 
# these on and off with the following switches, each of which appears as a 
# checkbox in the Neuroplayer panel. 
#
	set config(enable_processing) 0
	set config(save_processing) 0
	set config(enable_vt) 1
	if {$info(gui)} {
		set config(enable_af) 1
	} {
		set config(enable_af) 0
	}
	set config(af_calculate) 1
	set config(alt_calculate) 0
#
# The reconstruct flag turns on reconstruction. There are few times when we
# don't want reconstruction, but one such time might be when we don't know the
# frequency of the underlying signal.
#
	set config(enable_reconstruct) 1
#
# We record and play back data in intervals. Here we specify these intervals
# in seconds. The Neuroplayer translates seconds to clock messages.
#
	set config(play_interval) 1.0
	set info(play_interval_copy) 1.0
	set info(clocks_per_second) 128
	set info(ticks_per_clock) 256
	set info(max_message_value) 65535
	set info(value_range) [expr $info(max_message_value) + 1]
	set info(clock_cycle_period) \
		[expr ($info(max_message_value)+1)/$info(clocks_per_second)]
#
# The Neuroplayer will record events to a log, in particular warnings and
# errors generated during playback and recording.
#
	set config(log_warnings) 0
	set config(log_file) [file join \
		[file dirname $info(settings_file_name)] Neuroplayer_log.txt]
# 
# Some errors we don't want to write more than once to the text window, so
# we keep a copy of the most recent error to compare to.
#
	set info(previous_line) ""
#
# Plot display controls, each of which appear in an entry or checkbox.
#
	set config(v_range) 65535
	set config(v_offset) 0
	set config(vt_mode) "SP"
	set config(a_max) 100
	set config(a_min) 0.0
	set config(f_min) 0.0
	set config(f_max) 100
	set config(log_frequency) 0
	set config(log_amplitude) 0
#
# Colors for windows.
#
	set info(label_color) "darkgreen"
	set info(variable_bg) "lightgray"
#
# We apply a window function to the signal before we take the fourier transform.
# This function smooths the signal to its average value starting
# window_fraction*num_samples from the left and right edges.
#
	set config(window_fraction) 0.1
# 
# We zoom the plots in the separate signal and spectrum view windows.
#
	set config(vt_view_zoom) 2
	set config(af_view_zoom) 2
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
# Neurotracker panel configuration.
#
	set info(tracker_window) $info(window)\.tracker
	set info(tracker_width) [expr round(640 * $LWDAQ_Info(display_zoom))]
	set info(tracker_height) [expr round(320 * $LWDAQ_Info(display_zoom))]
	set info(tracker_image_border_pixels) 10
#
# Neurotracker calculation settings.
#
	set config(tracker_min_reception) "0.2"
	set config(tracker_decade_scale) "30" 
	set config(tracker_extent_radius) "100"
	set config(tracker_sample_rate) "16"
	set config(tracker_filter_divisor) "1"
	set config(tracker_persistence) "None"
	set config(tracker_mark_cm) "0.1"
	set config(tracker_show_coils) "0"
	set config(tracker_background) "0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0"
	set info(A3038_payload) "16"
	set info(A3038_coordinates) "\
		0  0 2 0  12 2  0 24 2 \
		12 0 2 12 12 2 12 24 2 \
		24 0 2 24 12 2 24 24 2 \
		36 0 2 36 12 2 36 24 2 \
		48 0 2 48 12 2 48 24 2 \
		-1 -1 -1"
	set info(A3032_payload) "16"
	set info(A3032_coordinates) "\
		0 0 2  0 8 2  0 16 2 \
		8  0 2  8 8 2  8 16 2 \
		16 0 2 16 8 2 16 16 2 \
		24 0 2 24 8 2 24 16 2 \
		32 0 2 32 8 2 32 16 2"
	set config(tracker_coordinates) ""
	set info(tracker_range_border) "1.0"
	set info(tracker_range) "-1.0 -1.0 +49.0 +25.0"
	set info(tracker_filter_database) [list \
		"512 0.0125" "256 0.0250" \
		"128 0.0470" "64 0.0900" \
		"32 0.1800" "16 0.3100" \
		"8 0.5200" "1 1.0000"]
#
# The Playback Clock default settings.
#
	set config(datetime_format) {%d-%b-%Y %H:%M:%S}
	set info(datetime_play_time) [Neuroplayer_clock_convert [clock seconds]]
	set config(datetime_jump_to) [Neuroplayer_clock_convert [clock seconds]]
	set info(datetime_start_time) [Neuroplayer_clock_convert [clock seconds]]
	set info(datetime_archive_name) "M0000000000.ndf"
	set info(datetime_panel) $info(window)\.clock
#
# Export settings.
#
	set info(export_help_url) \
		"http://www.opensourceinstruments.com/Electronics/A3018/Neuroplayer.html#Exporting%20Data"
	set info(export_panel) $info(window)\.export
	set info(export_text) $info(window)\.export.text
	set info(edf_panel) $info(export_panel)\.edf
	set info(text_panel) $info(export_panel)\.header
	set config(export_txt_header) ""
	set info(export_start_s) "0000000000"
	set info(export_end_s) $info(export_start_s)
	set config(export_start) [Neuroplayer_clock_convert $info(export_start_s)]
	set config(export_duration) 60
	set config(export_dir) "~/Desktop"
	set info(export_state) "Idle"
	set info(export_vfl) ""
	set info(export_epl) ""
	set config(export_video) "0"
	set config(export_signal) "1"
	set config(export_activity) "0"
	set config(export_centroid) "0"
	set config(export_combine) "0" 
	set config(export_powers) "0"
	set config(export_format) "TXT"
	set info(export_run_start) [clock seconds]
	set config(export_reps) "1"
	set config(export_activity_max) "10000"
#
# Video playback parameters. We define executable names for ffmpeg and mplayer.
#
	set info(video_library_archive) \
		"http://www.opensourceinstruments.com/ACC/Videoarchiver.zip"
	set config(videoarchiver_dir) [file join $LWDAQ_Info(program_dir) Videoarchiver]
	if {![file exists $config(videoarchiver_dir)]} {
		set config(videoarchiver_dir) \
			[file normalize [file join $LWDAQ_Info(program_dir) .. Videoarchiver]]
	}
	set config(video_dir) $LWDAQ_Info(working_dir)
	set info(video_file) [file join $config(video_dir) V0000000000.mp4]
	set info(video_stop_time) 0.0
	set info(video_end_time) 0.0
	set info(video_wait_ms) 100
	set info(video_num_waits) 10
	set info(video_frame_time) 0.05
	set info(video_min_interval) 1.0
	set config(video_speed) "1.0"
	set config(video_zoom) "1.0"
	set info(video_state) "Idle"
	set info(video_log) [file join $config(videoarchiver_dir) \
		Scratch Neuroplayer_video_log.txt]
	set config(video_enable) "0"
	set info(video_process) "0"
	set info(video_channel) "file1"
	set info(video_file_cache) [list]
	set info(max_video_files) "100"
	set os_dir [file join $config(videoarchiver_dir) $LWDAQ_Info(os)]
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
		set info(ffmpeg) [file join $os_dir ffmpeg/ffmpeg]
		set info(mplayer) [file join $os_dir mplayer]
	} elseif {$LWDAQ_Info(os) == "Raspbian"} {
		set info(ssh) "/usr/bin/ssh"
		set info(ffmpeg) "/usr/bin/ffmpeg"
		set info(mplayer) "/usr/bin/mplayer"
	} else {
		Neuroplayer_print "WARNING: Video playback may not work on $LWDAQ_Info(os)."
		set info(ssh) "/usr/bin/ssh"
		set info(ffmpeg) "/usr/bin/ffmpeg"
		set info(mplayer) "/usr/bin/mplayer"
	}
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
# We use the value of bp_set to initialize the baseline powers to 
# one common value.
#
	for {set id $info(min_id)} {$id <= $info(max_id)} {incr id} {
		set info(bp_$id) $config(bp_set)
	}
#
# We have file tail variables that we display in the Neuroplayer
# window. We set these now, after we have read in the saved settings.
#
	foreach n {play processor event} {
		set info($n\_file_tail) [file tail $config($n\_file)]
	}
#
# We are done with initialization. We return a 1 to show success.
#
	return "SUCCESS"   
}

#
# Neuroplayer_configure calls the standard LWDAQ tool configuration
# routine to produce a window with an array of configuration parameters
# that the user can edit.
#
proc Neuroplayer_configure {} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info
	LWDAQ_tool_configure Neuroplayer 4
}

#
# Neuroplayer_print writes a line to the text window. If the color specified
# is "verbose", the message prints only when the verbose flag is set, and in
# black. Warnings and errors are always printed in the warning and error colors.
# In addition, if the log_warnings is set, the routine writes all warnings and
# errors to the Neuroplayer log file. The print routine will refrainn from
# writing the same error message to the text window repeatedly when we set the
# color to the key word "norepeat". The routine always stores the previous line
# it writes, so as to compare in the case of a norepeat requirement. Note that
# the final print to a text window uses LWDAQ_print, which will not try to print
# to a target with a widget-style name when graphics are disabled.
#
proc Neuroplayer_print {line {color "black"}} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info
	
	if {$color == "norepeat"} {
		if {$info(previous_line) == $line} {return ""}
		set color black
	}
	set info(previous_line) $line
	
	if {[regexp "^WARNING: " $line] || [regexp "^ERROR: " $line]} {
		append line " ([Neuroplayer_clock_convert [clock seconds]]\)"
		if {[regexp -nocase [file tail $config(play_file)] $line]} {
			set line [regsub "^WARNING: " $line "WARNING: $info(datetime_play_time) "]
			set line [regsub "^ERROR: " $line "ERROR: $info(datetime_play_time) "]
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
# Neuroplayer_print_event prints an event to the text window with a link
# embedded in the file name so that we can click on the event and jump to it.
# If we don't specify an event, the routine prints the current event to the
# window.
#
proc Neuroplayer_print_event {{event ""}} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info

	if {![winfo exists $info(window)]} {return "ABORT"}

	if {$event == ""} {
		set event "$info(play_file_tail) $info(t_min) \"$config(channel_selector)\"\
			\"Event in $config(play_interval)-s interval\""
	}

	set t $info(text)
	set i [incr info(event_id)]
	$t tag bind event_$i <Button> [list LWDAQ_post [list Neuroplayer_jump $event 0]]
	$t insert end "<J>" "event_$i textbutton"
	$t insert end " $event\n"
	$t see end

	return $event
}



#
# Neuroplayer_play_time_format stops the play time from becoming corrupted
# by rounding errors, and makes sure that there is always one number after the
# decimal point, while at the same time dropping unecessary trailing zeros.
#
proc Neuroplayer_play_time_format {play_time} {
	if {![string is double -strict $play_time]} {
		Neuroplayer_print "ERROR: Bad play time \"$play_time\", assuming 0.0s."
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


# Neuroplayer_pick allows the user to pick a new play_file, processor_file,
# event_file, play_dir, or video_dir.

proc Neuroplayer_pick {name {post 0}} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info
	global LWDAQ_Info

	# If we call this routine from a button, we prefer to post
	# its execution to the event queue, and this we can do by
	# adding a parameter of 1 to the end of the call.
	if {$post} {
		LWDAQ_post [list Neuroplayer_pick $name]
		return ""
	}

	if {[regexp "_file" $name]} {
		set fn [LWDAQ_get_file_name 0 [file dirname [set config($name)]]]
		if {![file exists $fn]} {
			Neuroplayer_print "WARNING: File \"$fn\" does not exist."
			return $fn
		}
		set config($name) $fn
		set info($name\_tail) [file tail $fn]
		return $fn
	} 
	if {[regexp "_dir" $name]} {
		set dn [LWDAQ_get_dir_name [set config($name)]]
		if {![file exists $dn]} {
			Neuroplayer_print "WARNING: Directory \"$dn\" does not exist."
			return $dn
		}
		set config($name) $dn
		return $dn
	}
	return ""
}

#
# Neuroplayer_list prints a list of NDF files and their metadata 
# comments. The routine takes as input a list of files. If the list
# is empty, it asks the user to select the files to list. The list 
# contains links to open an archive in the Player, to open in the
# overview window, and to edit metadata.
#
proc Neuroplayer_list {{index 0} {fl ""}} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info
	
	# Get a list of files.
	if {$fl == ""} {
		set fl [LWDAQ_get_file_name 1]
		if {$fl == ""} {
			return "ABORT"
		}
	}
	set fl [lsort -dictionary $fl]

	# If the index is greater than zero, we look for a matching overview
	# window. If we find it, we raise it and exit.
	if {$index > 0} {
		set w $info(window)\.list_$index
		if {[winfo exists $w]} {
			raise $w
			return "SUCCESS"
		}
	}
	
	# If the index is zero, find a free window name.
	if {$index == 0} {
		set index 1
		while {[winfo exists [set w $info(window)\.list_$index]]} {
			incr index
		}
	}
	
	# Now we have the index providing an unused list name, so we create the window.
	toplevel $w
	wm title $w "List of [llength $fl] Selected Archives"
	
	# We will write the list in a text widget with text bindings.
	LWDAQ_text_widget $w 70 40
	LWDAQ_enable_text_undo $w.text	
	$w.text tag configure textbutton -background lightblue
	$w.text tag bind textbutton <Enter> {%W configure -cursor arrow} 
	$w.text tag bind textbutton <Leave> {%W configure -cursor xterm} 

	# Present all the files.
	set i 1
	foreach fn $fl {
		LWDAQ_print -nonewline $w.text "[file tail $fn]   " purple
		if {[catch {LWDAQ_ndf_data_check $fn} error_message]} {
			LWDAQ_print $w.text ""
			LWDAQ_print $w.text "ERROR: $error_message.\n"
			continue
		} 
		$w.text tag bind s_$i <Button> [list LWDAQ_post \
			[list Neuroplayer_jump "[file tail $fn] 0.0 * Selected from list"]]
		$w.text insert end "  Step  " "s_$i textbutton"
		$w.text insert end "   "
		$w.text tag bind e_$i <Button> [list LWDAQ_post \
			[list Neuroplayer_metadata_view $fn]]
		$w.text insert end "  Metadata  " "e_$i textbutton"
		$w.text insert end "   "
		$w.text tag bind o_$i <Button> [list LWDAQ_post \
			[list Neuroplayer_overview $fn]]
		$w.text insert end "  Overview  " "o_$i textbutton"
		$w.text insert end "\n"
		set metadata [LWDAQ_ndf_string_read $fn]
		set comments [LWDAQ_xml_get_list $metadata "c"]
		foreach c $comments {
			$w.text insert end [string trim $c]\n
		}
		$w.text insert end "\n"
		incr i
		LWDAQ_support
	}
	
	# Returnn successful.
	return "SUCCESS"
}

#
# Neuroplayer_metadata_write writes the contents of a text window, which is 
# $w.text, into the metadata of a file $fn. We use this procedure in the Save 
# button of the metadata display window.
#
proc Neuroplayer_metadata_write {w fn} {
	LWDAQ_ndf_string_write $fn [string trim [$w.text get 1.0 end]]\n
	return "SUCCESS"
}

#
# Neuroplayer_metadata_view reads the metadata from an NDF file called $fn and
# displays the metadata string in a metadata viewing panel. You can edit the
# string and save it to the same file with a Save button.
#
proc Neuroplayer_metadata_view {fn} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	
	# Determine the file name.
	switch $fn {
		"play" {set fn $config(play_file)}
		default {
			if {![file exists $fn]} {
				Neuroplayer_print "ERROR: File \"$fn\" does not exist."
				return "FAIL"
			}
		}
	}
	
	# Check the file.
	if {[catch {LWDAQ_ndf_data_check $fn} error_message]} {
		Neuroplayer_print "ERROR: Checking archive, $error_message."
		return "FAIL"
	}
	
	# If the metadata viewing panel exists, destroy it. We are going to make a
	# new one.
	set w $info(window)\.metadata
	if {[winfo exists $w]} {destroy $w}
	
	# Create a new top-level text window that is a child of the Neuroplayer
	# window. Bind the Command-S key to save the metadata.
	toplevel $w
	wm title $w "[file tail $fn] Metadata, Neuroplayer $info(version)"
	LWDAQ_text_widget $w 60 20
	LWDAQ_enable_text_undo $w.text
	LWDAQ_bind_command_key $w s [list Neuroplayer_metadata_write $w $fn]
	
	# Create the Save button.
	frame $w.f
	pack $w.f -side top
	button $w.f.save -text "Save" -command [list Neuroplayer_metadata_write $w $fn]
	pack $w.f.save -side left
	
	# Print the metadata to the text window.
	LWDAQ_print $w.text [LWDAQ_ndf_string_read $fn]

	return "SUCCESS"
}

#
# Neuroplayer_seek_time determines the index of the clock message that occurs
# just before seek_time and also just after seek time. If the seek time lies
# exactly upon a clock message, the before and after clock messages will be the
# same. When the routine searches through an archive for the correct clock
# messages, it starts at the beginning and proceeds in steps small enough to be
# less than one complete clock cycle (512 s for clock frequency 128 Hz). If the
# archive is uncorrupted, it will contain a sequence of clock messages, each
# with value one greater than the last, with the exception of clock messages
# with value max_sample, which will be followed by one of value zero. The seek
# routine is able to find time points in the archive quickly because it does not
# have to look at all the clock messages in the archive. If the archive is
# severely corrupted, with blocks of null messages and missing data, the seek
# routine can fail to notice jumps in the clock messages values and so fail to
# note that its time calculation is invalid. As an alternative to jumping
# through the archive, the Neuroplayer_sequential_time starts at the first
# clock message and counts clock messages, adding one clock period to its
# measurement of archive time for every clock message, irrespective of the
# values of the messages. Both seek_time routines take the same parameters and
# return four numbers: lo_time, lo_index, hi_time, and hi_index. The routines
# assume the archive contains a clock message immediately after the last message
# in the archive, which we call the "end clock". The routine will choose the end
# clock for hi_time and hi_index if the seek time is equal to or greater than
# the length of the archive. If the seek time is -1, the routine takes this to
# mean that it should find the end time of the archive, which will be the time
# and index of the end clock, even though this end clock is not included in the
# archive. Note that the index of a message is its index in the archive's data
# block, when we divide the block into messages. Messages are at least
# core_message_length long, and my have an arbitrary payload attached to the
# end, as given by the payload parameter. The byte address of a message is the
# byte number of the first byte of the message within the archive's data block.
# The return string "0 2 0 2" means time zero occurs at message index 2 in the
# archive. The message with index 2 is the third message in the data block of
# the archive. We might obtain such a result when we specify seek time of 0 and
# apply it to an archive that, for some reason, does not start with a clock
# message. We can pass in optional values for lo_time and lo_index, where the
# seek should start from these values. The lo_time should be the play time that
# is correct for message lo_index within the file.
#
proc Neuroplayer_seek_time {fn payload seek_time {lo_time 0.0} {lo_index 0}} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config

	if {$config(sequential_play)} {
		return [Neuroplayer_sequential_time $fn $payload $seek_time $lo_time $lo_index]
	}

	set jump_scale 0.1
	set message_length [expr $info(core_message_length) + $payload]
	
	if {$seek_time < 0} {set seek_time -1}
	if {$lo_index == 0} {set lo_time 0.0}
	set hi_time $lo_time
	set hi_index $lo_index

	scan [LWDAQ_ndf_data_check $fn] %u%u data_start data_length
	set end_index [expr round($data_length / $message_length) - 1]

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
			# We have found a clock message. The id is zero and the timestamp is
			# not zero. If the timestamp were zero, this would be either a null
			# message or a corrupted clock message. All clock messages have a
			# non-zero firmware number in their timestamp field.			
			set num_consecutive_non_clocks 0
			
			# Check to see if this is the first clock message we have found.
			if {$previous_clock_value < 0} {
				# If this is the first clock message, as indicated by the
				# negative previous_clock_value, we intialize our clock message
				# tracking.
				set previous_clock_value $value
				set previous_clock_time $lo_time
				set clock_time $lo_time
			} {
				# If this is not our first clock message, we save the existing
				# clock time and calculate the new clock time using the
				# difference in the clock message values. We never jump more
				# than max_message_value messages through an archive, so we are
				# certain that the difference in the values gives us an
				# unambiguous measurement of the time difference.
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
					# We moved one message at a time from the previous clock,
					# which had time less than the seek time, and now we arrive
					# at a clock with time greater than the seek time. So the
					# previous and current clocks straddle the seek time. The
					# two times should be separated by exactly one clock period,
					# but their indices can be separated by many transmitter
					# messages. If there are missing clock messages in the
					# recording, the two times can be separated by many clock
					# periods, as when there is missing data from a recording.
					set lo_time $previous_clock_time
					set lo_index $previous_clock_index
					set hi_time $clock_time
					set hi_index $index
					set index [expr $end_index + 1]
				} {
					# We jumped past the clock that is just after the seek time,
					# or there is no such clock just after the seek time. We
					# don't know which yet, but to find out, we reduce the jump
					# size and go back to the previous clock. We must restore
					# the clock time to the previous clock time and the index to
					# the previous clock index.
					set jump_size [expr round($jump_scale*$jump_size)]
					set clock_time $previous_clock_time
					set index $previous_clock_index
				}
			} {
				if {$clock_time == $seek_time} {
					# This is the ideal case of seek time within the archive
					# range and we find a clock that has exactly that time. Thus
					# the lo and hi clocks are the same.
					set lo_time $clock_time
					set lo_index $index
					set hi_time $lo_time
					set hi_index $lo_index
					set index [expr $end_index + 1]
				} {
					# The clock time is still less than the seek time, so we
					# must keep going to find a higher clock time. We jump
					# farther into the archive, after saving the current clock
					# value and index.
					set previous_clock_value $value
					set previous_clock_index $index
					set index [expr $index + $jump_size]
					if {$index > $end_index} {
						if {$jump_size == 1} {
							# Our previous clock message is the last message in
							# the archive. The next clock message is the end
							# clock, and our clock time is either less than the
							# seek time or we are seeking the end time. So we
							# use the index that is just past the end of the
							# archive and we increment our clock time by one
							# clock period to get both the lo and hi clocks.
							set lo_time [expr $clock_time + 1.0/$info(clocks_per_second)]
							set lo_index $index
							set hi_time $lo_time
							set hi_index $lo_index
						} {
							# We jumped past the end of the archive, missing
							# some messages between our current clock and the
							# end. So reduce the jump size and go back to the
							# previous clock.
							set jump_size [expr round($jump_scale*$jump_size)]
							set index $previous_clock_index
						}
					}
				}
			}
		} {
			# This message is not a clock message. Either we have just jumped to
			# this location in the archive, ready to search for the next clock
			# message, or we have been stepping through the archive one message
			# at a time performing the search. We must step to the next message.
			# The message may be a null message or a corrupted clock message or
			# a valid data message. In all cases, we take a step forward.
			incr index

			# We keep track of the number of non-clocks. If we encounter more
			# than is possible in valid data, we force another jump. If this
			# jump takes us past the end of the archive, we set the time and
			# index parameters as best we can.
			incr num_consecutive_non_clocks
			if {$num_consecutive_non_clocks >= $info(max_consecutive_non_clocks)} {
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
				# Our index now points past the end of the archive, to the end
				# clock.
				if {$jump_size <= 1} {
					# The jump size is 1, which means we have examined every
					# message between the previous clock and the end clock. So
					# we can determine the end clock time by adding a clock
					# period to the previous clock time. We know that the
					# previous clock time was either less than the seek time or
					# we were seeking the end clock, so we will use the end
					# clock for both our clocks.
					set lo_time [expr $clock_time + 1.0/$info(clocks_per_second)]
					set lo_index $index
					set hi_time $lo_time
					set hi_index $lo_index
				} {
					# The jump size is more than 1, so we may have jumped over a
					# clock message that lies between the previous clock and the
					# end clock. We must go back to the previous clock and use a
					# smaller jump size.
					set index $previous_clock_index
					set jump_size [expr round($jump_scale*$jump_size)]
				}
			}
		}

		LWDAQ_support
	}

	close $f

	if {$num_consecutive_non_clocks >= $info(max_consecutive_non_clocks)} {
		Neuroplayer_print "WARNING: Archive [file tail $fn] severely corrupted,\
			consider sequential navigation."
	}
	
	return "$lo_time $lo_index $hi_time $hi_index"
}

#
# Neuroplayer_sequential_time has the same format as Neuroplayer_seek_time
# but proceeds through the archive calculating time by counting every single
# clock message. We use this routine with corrupted archvies, in which the time
# represented by the values of the clock messages is so distorted as to be useless.
# Instead of using the clock message values, we assume every clock message represents
# a time increment of one clock period, and we search through every clock message
# to find the correct time.
#
proc Neuroplayer_sequential_time {fn payload seek_time {lo_time 0.0} {lo_index 0}} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config

	set message_length [expr $info(core_message_length) + $payload]
	set block_length [expr $message_length * $info(sequential_block_length)]
	set image_width [expr round(sqrt($block_length)) + 10]
	set image_name "_Neuroplayer_sequential_image_"
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

		set clocks [lwdaq_receiver $image_name \
			"-payload $info(player_payload) \
			-size [expr $data_size / $message_length] \
			clocks $target_lo $target_hi -1"]
		scan $clocks %d%d%d%d%d%d num_errors num_clocks num_messages \
			local_lo_index local_hi_index last_index
		set block_end_time [expr $clock_time \
			+ 1.0 * $num_clocks / $info(clocks_per_second)]

		if {$seek_time >= 0} {
			if {$block_end_time > $seek_time} {
				set lo_index [expr $index + $local_lo_index]
				set lo_time [expr $clock_time \
					+ 1.0 * $target_lo / $info(clocks_per_second)]
				if {$lo_time == $seek_time} {
					set hi_index $lo_index
					set hi_time $lo_time
				} {
					set hi_index [expr $index + $local_hi_index]
					set hi_time [expr $clock_time \
						+ 1.0 * $target_hi / $info(clocks_per_second)]
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

# Neuroplayer_end_time determines the time interval spanned by a file.
# It calls Neuroplayer_seek_time with value -1 to obtain the length of 
# the archive. We curtail the end time to two decimal places in order to
# avoid display problems for archives that have unusual end times as a result
# of data loss during recording.
#
proc Neuroplayer_end_time {fn payload {ref_time 0} {ref_index 0}} {
	scan [Neuroplayer_seek_time $fn $payload -1 $ref_time $ref_index] \
		%f%u%f%u lo_time lo_index hi_time hi_index
	set end_time [Neuroplayer_play_time_format $hi_time]
	if {fmod($end_time,1) != 0} {
		set end_time [format %.2f $end_time]
	}
	return $end_time
}

#
# Neuroplayer_filter is for use in processor scripts as a means of detecting
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
proc Neuroplayer_filter {band_lo_end band_lo_center \
		band_hi_center band_hi_end \
		{show 0} {replace 0} {bandpass 1}} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config

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

	# If show or replace, take the inverse transform. The filtered values will
	# be available to the calling procedure in a variable of the same name.
	if {$show || $replace} {
		set filtered_values [lwdaq_fft $filtered_spectrum -inverse 1]
	}
	
	# If show, plot the filtered signal to the screen. If our frequency band
	# does not include zero, we add the zero-frequency component to every sample
	# value so that the filtered signal will be super-imposed upon the
	# unfiltered signal in the display.
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
		Neuroplayer_plot_signal [expr $info(channel_num) + 32] $filtered_signal
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
# Neuroplayer_band_power is for use in processor scripts as a means of detecting
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
proc Neuroplayer_band_power {band_lo band_hi {show 0} {replace 0}} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config

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
	
	# We call Neuroplayer_filter with sharp upper and lower edges to 
	# the pass band, and so obtain the power, plot the inverse, and prepare
	# the inverse if requested.
	return [Neuroplayer_filter $band_lo $band_lo $band_hi $band_hi $show $replace]
}

#
# Neuroplayer_band_amplitude calls Neuroplayer_band_power and converts the
# power into a standard deviation of the signal, which is the root mean square
# amplitude.
#
proc Neuroplayer_band_amplitude {band_lo band_hi {show 0} {replace 0}} {
	set power [Neuroplayer_band_power $band_lo $band_hi $show $replace]
	if {[string is double $power]} {
		return [expr sqrt($power)]
	} {
		return $power
	}
}

#
# Neuroplayer_multi_band_filter allows us to specify ranges of frequency
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
proc Neuroplayer_multi_band_filter {{band_list ""} {show 0} {replace 0}} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config

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
		Neuroplayer_plot_signal [expr $info(channel_num) + 32] $filtered_signal
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
# Neuroplayer_contiguous_band_power accepts a low and high frequency
# to define a range of frequencies to be analyzed, and then a number of
# contiguous bands into which to divide that range. It returns the power
# of the signal in each band in units of square counts.
#
proc Neuroplayer_contiguous_band_power {flo fhi num} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	
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
# Neuroplayer_command handles the various control commands generated by the play
# buttons. It refers to the LWDAQ event queue with the global queue_events
# variable.
#
proc Neuroplayer_command {action} {
	upvar #0 Neuroplayer_info info
	global LWDAQ_Info

	set event_executing [string match "Neuroplayer_play*"\
		$LWDAQ_Info(current_event)]
	set event_pending 0
	foreach event $LWDAQ_Info(queue_events) {
		if {[string match "Neuroplayer_play*" $event]} {
			set event_pending 1
		}
	}

	if {$action != $info(play_control)} {
		if {!$event_executing} {
			set info(play_control) $action
			if {!$event_pending} {
				if {$action != "Stop"} {
					LWDAQ_post Neuroplayer_play
				} {
					set info(play_control) "Idle"
				}
			}
		} {
			if {$action != "Stop"} {
				LWDAQ_post [list Neuroplayer_command $action]	
			} {
				set info(play_control) $action
			}
		}
	}
	
	return "$action"
}

#
# Neuroplayer_signal extracts or reconstructs the signal from one channel in the
# data image. It updates info(num_received) and info(standing_values). It
# info(frequency) and info(num_messages). It returns the extracted or
# reconstructed signal. The returned signal format is a space-delimited string
# giving a sequence of messages. Each message is a timestamp followed by a
# sample value. The timestamp is an integer number of clock ticks from the
# beginning of the playback interval. The timestamps and vsample alues alternate
# in the return string, separated by single spaces. The "extracted" signal is a
# list of messages that exist in the data image. The "reconstructed" signal is
# the extracted signal with substitute messages inserted and bad messages
# removed, so as to create a signal with info(frequency) messages. To perform
# extraction and reconstruction, the routine calls lwdaq_receiver from the lwdaq
# library. See the Receiver Manual for more information, and also the LWDAQ
# Command Reference. The routine takes a single parameter: a channel code, which
# is of the form "id" or "id:f" or "id:f" where "id" is the channel number and
# "f" is its nominal message rate per second. If status_only is set, we don't
# reconstruct, but return after determining if there is loss, extra, or okay
# reception.
# 
proc Neuroplayer_signal {{channel_code ""} {status_only 0}} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	
	# Set the loss to 100% in case we encounter an error, we want the processor
	# to know there's no signal.
	set info(loss) 100.0

	# We split the channel code into id and frequency.
	if {$channel_code == ""} {set channel_code $info(channel_code)}
	set parameters [split $channel_code ":"] 
	set id [lindex $parameters 0]
	if {![string is integer -strict $id]} {
		Neuroplayer_print "ERROR: Invalid signal identifier \"$id\"."
		return "0 0"
	}
	
	# We look up how many messages were received in the activity string.
	set num_received 0
	if {[regexp " $id:(\[0-9\]*)" " $info(active_channels)" m a]} {
		set num_received $a 
	}
	
	# The frequency may be set by the channel code. If not, we look at the
	# expected frequency value that may be defined through the activity panel.
	set frequency [lindex $parameters 1]

	# We guess the frequency if it is not already set to a integer value. The
	# default frequency can be a single frequency or a list of frequencies, the
	# closest of which to the number of messages received is the one that will
	# be picked. If our search for a good frequency fails because there are too
	# many messages, we use the highest frequency in the default list.
	if {![string is integer -strict $frequency]} {
		set fl [lsort -integer -decreasing [string trim $config(default_frequency)]]
		set frequency [lindex $fl 0]
		foreach f $fl {
			if {![string is integer -strict $f]} {
				Neuroplayer_print "ERROR: Invalid frequency \"$f\" in default frequency list."
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
		if {$info(status_$id) != "Extra"} {
			Neuroplayer_print \
				"WARNING: Extra samples on channel $id\
				at $config(play_time) s in [file tail $config(play_file)]."
			set info(status_$id) "Extra"
		}
	} elseif {$num_received < [expr $config(min_reception) \
			* $frequency * $info(play_interval_copy)]} {
		set info(status_$id) "Loss"
	} else {
		set info(status_$id) "Okay"
	}
	set info(sps_$id) $frequency
	
	# If we are here only to the status and nominal sample rate of the transmitter,
	# we return now with an empty signal string.
	if {$status_only} {
		return "0 0"
	}
	
	# Set global parameters.
	set info(num_received) $num_received
	set info(frequency) $frequency

	# We calculate the number of messages expected and the period
	# of the nominal sample rate in clock ticks.
	set num_expected [expr $frequency * $info(play_interval_copy)]
	set period [expr round(1.0 * $info(ticks_per_clock) \
		* $info(clocks_per_second) / $frequency)]
	
	# Determine the standing value of the signal from its previous interval. If
	# the first message in the interval is missing, we will use this standing
	# value as a substitute. If there is no standing value, we extract the
	# signal and use the first extracted value as our standing value. We add the
	# new standing value to our standing value list.
	set standing_value_index [lsearch -index 0 $info(standing_values) $id]
	if {$standing_value_index < 0} {
		set signal [lwdaq_receiver $info(data_image) \
			"-payload $info(player_payload) -size $info(data_size) extract $id"]
		if {![LWDAQ_is_error_result $signal] && ([llength $signal] > 0)} {
			lappend info(standing_values) "$id [lindex $signal 1]"
		} {
			lappend info(standing_values) "$id 0"
		}
		set standing_value_index [expr [llength $info(standing_values)] - 1]
	}
	set standing_value [lindex $info(standing_values) $standing_value_index 1]
		
	# Reconstruct or extract the signal.	
	if {$config(enable_reconstruct)} {
		# Reconstruction involves extraction, then filling in missing
		# messages and eliminating bad messages. We may need to bring
		# one or more messages from the previous interval to add to the
		# start of this one, as a consequence of transmission scatter.
		# We have a standing value in case the first message is missing.
		# The reconstruction always returns the nominal number of messages.
		set signal [lwdaq_receiver $info(data_image) \
			"-payload $info(player_payload) \
			-size $info(data_size) \
			reconstruct $id $period $standing_value \
			$config(glitch_threshold)"]
		
		# Check for an error in reconstruction.
		if {[LWDAQ_is_error_result $signal]} {
			Neuroplayer_print $signal
			set signal "0 0"
			return $signal
		}
		
		# Reconstruction can fail if the transmit frequency is slightly too high
		# or too low as a result of a fault in the on-board oscillator. We check
		# for this mode of failure now, and if we find it, we reconstruct once 
		# again, but this time with the "divergent_clocks" option set true.
		scan [lwdaq_image_results $info(data_image)] %d%d%d%d%d%d \
			num_clocks num_ideal num_bad num_missing standing_value num_glitches
		if {$num_received + $num_missing > ($config(max_rejection)+1)*$num_ideal} {
			Neuroplayer_print "Channel [format %2d $id],\
				sample rate out of range, adapting reconstruction." verbose
			set signal [lwdaq_receiver $info(data_image) \
				"-payload $info(player_payload) \
				-size $info(data_size) \
				reconstruct $id $period $standing_value \
				$config(glitch_threshold) 1"]
		}
	} {
		# Extraction returns the messages with matching id in the recording.
		# There is no detection of duplicate of bad messages, no filling in
		# of missing messages. Thus we may get more or fewer messages than
		# the nominal number.
		set signal [lwdaq_receiver $info(data_image) \
			"-payload $info(player_payload) -size $info(data_size) extract $id $period"]
	}
	
	# Check for an error in reconstruction or extraction.
	if {[LWDAQ_is_error_result $signal]} {
		Neuroplayer_print $signal
		set signal "0 0"
		return $signal
	}
	
	# Set the standing values and image result string. Print a message if we are
	# set to verbose output, summarizing the reconstruction.
	set results [lwdaq_image_results $info(data_image)]
	scan [lwdaq_image_results $info(data_image)] %d%d%d%d%d%d \
		num_clocks num_messages num_bad num_missing standing_value num_glitches
	if {$config(enable_reconstruct)} {
		set info(loss) [expr 100.0 * $num_missing / $num_expected]
		Neuroplayer_print "Channel [format %2d $id],\
			[format %4.1f $info(loss)]% loss,\
			$num_messages reconstructed,\
			$num_received received,\
			$num_bad bad,\
			$num_missing missing." verbose
	} {
		set info(loss) [expr 100.0 - 100.0 * $num_messages / $num_expected]
		Neuroplayer_print "Channel [format %2d $id],\
			[format %4.1f $info(loss)]% loss,\
			$num_messages extracted,\
			$num_received received." verbose
	}
	lset info(standing_values) $standing_value_index 1 $standing_value
	set info(num_messages) $num_messages
	set config(glitch_count) [expr $config(glitch_count) + $num_glitches]

	return $signal
}

#
# Neuroplayer_values extracts only the voltage values from the Neuroplayer
# signal. If there are values missing, it adds values so that we have a power
# of two number of values to pass to the fft later. If there are too many values,
# we remove some until the number is correct.
#
proc Neuroplayer_values {{signal ""}} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config

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
# Neuroplayer_color returns a color code that is equal to the identifier
# it is passed, unless there is a color switch value in the color table.
#
proc Neuroplayer_color {id} {
	upvar #0 Neuroplayer_config config

	set index [lsearch -index 0 $config(color_table) $id]
	if {$index >= 0} {
		return [lindex $config(color_table) $index 1]
	} {
		return $id
	}
}

#
# Neuroplayer_spectrum calculates the discrete Fourier transform of the
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
proc Neuroplayer_spectrum {{values ""}} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	upvar result result
	
	if {$values == ""} {set values $info(values)}
	set info(f_step) [expr 1.0/$info(play_interval_copy)]	
	set spectrum [lwdaq_fft $values \
		-window [expr round([llength $values] * $config(window_fraction))]]
	if {[LWDAQ_is_error_result $spectrum]} {
		Neuroplayer_print $spectrum
		set spectrum "0 0"
	}
	
	LWDAQ_support
	return $spectrum
}

#
# Neuroplayer_overview displays an overview of a file's contents. This
# routine sets up the overview window and calles a plot routine to sample
# the archvie and plot the results. An Export button provides a way to
# export the graph data to disk for plotting in other programs.
#
proc Neuroplayer_overview {{fn ""} } {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_overview ov_config
	global LWDAQ_Info
	
	# Use play file if none specified.
	if {$fn == ""} {
		set fn $config(play_file)
	}
	
	# If the file does not exist, complain.
	if {![file exists $fn]} {
		Neuroplayer_print "ERROR: File \"$fn\" does not exist for overview."
		return "ERROR"
	}

	# Now we have the index providing an unused list name, so create the window
	# and its configuration array.
	set w $info(window)\.overview

	if {![winfo exists $w]} {
		toplevel $w
		wm title $w "Archive Overview, Neuroplayer $info(version)"
		set existing_window 0
		set existing_file 0
		catch {unset ov_config}
	} {
		raise $w
		set existing_window 1
		if {$ov_config(fn) != [file normalize $fn]} {
			$ov_config(plot) delete cursor
			set existing_file 0
		} {
			set existing_file 1
		}
	}
	set ov_config(w) $w

	# Set file variables.
	set ov_config(fn) [file normalize $fn]
	set ov_config(fn_tail) [file tail $ov_config(fn)]
	
	# Try to determine the start time of the archive.
	if {![regexp {([0-9]{10})\.ndf} [file tail $ov_config(fn)] match atime]} {
		set atime 0
	}
	set ov_config(atime) $atime

	if {!$existing_window} {	
		# Create a new photo in which to plot our graph.
		set ov_config(photo) [image create photo "_Neuroplayer_ov_photo_"]

		# Initialize the display parameters.
		set ov_config(t_min) 0
		set ov_config(t_max) 0
		set ov_config(status) "Idle"
		set ov_config(cursor_cc) 0
			
		# Make a frame for the plot.
		set f $w.plot
		frame $f 
		pack $f -side top -fill x
	
		# Create graph display. We create a canvas widget and display a lwdaq
		# image in the widget.
		set plot $f.canvas
		canvas $plot -bd 2 -relief sunken \
			-width [expr $info(overview_width) + 1] \
			-height [expr $info(overview_height) + 1]
		pack $plot -side top -expand 1
		$plot create image 0 0 -anchor nw -image $ov_config(photo)
		bind $plot <Double-Button-1> \
			[list LWDAQ_post [list Neuroplayer_overview_jump %x %y]]
		set ov_config(plot) $plot

		# Create value controls.	
		set f $w.value
		frame $f 
		pack $f -side top -fill x
		label $f.status -textvariable Neuroplayer_overview(status) \
			-fg blue -bg white -width 10
		pack $f.status -side left -expand yes
		button $f.plot -text "Plot" -command \
			[list LWDAQ_post Neuroplayer_overview_plot]
		pack $f.plot -side left -expand yes
		button $f.excerpt -text "Excerpt" -command \
			[list LWDAQ_post Neuroplayer_overview_excerpt]
		pack $f.excerpt -side left -expand yes
		foreach a "SP CP NP" {
			set b [string tolower $a]
			radiobutton $f.$b -variable Neuroplayer_config(vt_mode) \
				-text $a -value $a
			pack $f.$b -side left -expand no
		}
		foreach v {v_range v_offset} {
			label $f.l$v -text $v -width [string length $v]
			entry $f.e$v -textvariable Neuroplayer_config($v) -width 5
			pack $f.l$v $f.e$v -side left -expand yes
		}
		label $f.cursor -text "  " \
			-bg [lwdaq tkcolor [Neuroplayer_color $ov_config(cursor_cc)]]
		set ov_config(cursor_label) $f.cursor
		pack $f.cursor -side left -expand yes
		bind $f.cursor <ButtonPress> {
			incr Neuroplayer_overview(cursor_cc)
			set color [lwdaq tkcolor [Neuroplayer_color \
				$Neuroplayer_overview(cursor_cc)]]
			$Neuroplayer_overview(cursor_label) configure -bg $color
			$Neuroplayer_overview(plot) itemconfigure "cursor" -fill $color
		}
		button $f.nf -text "Next_NDF" -command \
			[list LWDAQ_post [list Neuroplayer_overview_newndf +1]]
		button $f.pf -text "Prev_NDF" -command \
			[list LWDAQ_post [list Neuroplayer_overview_newndf -1]]
		pack $f.nf $f.pf -side left -expand yes

		# Create time controls
		set f $w.time
		frame $f 
		pack $f -side top -fill x
		label $f.tfn -text "Archive:"
		label $f.lfn -textvariable Neuroplayer_overview(fn_tail) -width 14
		pack $f.tfn $f.lfn -side left -expand yes
		label $f.lt_min -text "t_min"
		entry $f.et_min -textvariable Neuroplayer_overview(t_min) -width 6
		label $f.lt_max -text "t_max"
		entry $f.et_max -textvariable Neuroplayer_overview(t_max) -width 6
		label $f.lt_end -text "t_end"
		label $f.et_end -textvariable Neuroplayer_overview(t_end) -width 6
		label $f.ls -text "Select:" -anchor e
		entry $f.es -textvariable Neuroplayer_config(channel_selector) -width 30
		pack $f.lt_min $f.et_min $f.lt_max $f.et_max \
			$f.lt_end $f.et_end $f.ls $f.es -side left -expand yes

		# Create activity display
		set f $w.activy
		frame $f
		pack $f -side top -fill x
		switch $LWDAQ_Info(os) {
			"MacOS" {set width 100}
			"Windows" {set width 90}
			"Linux" {set width 90}
			default {set width 90}
		}		
		label $f.la -text "Samples (id:qty):" -anchor e
		label $f.ea -textvariable Neuroplayer_overview(activity) \
			-anchor w -width $width -bg lightgray
		pack $f.la $f.ea -side left -expand yes
	}
	
	if {!$existing_file} {
		# Get the payload length from the file metadata.
		if {[catch {
			set metadata [LWDAQ_ndf_string_read $config(play_file)]
		} error_message]} {
			Neuroplayer_print "ERROR: $error_message."
			return "FAIL"			
		}
		set ov_config(payload) [LWDAQ_xml_get_list $metadata "payload"]
		if {![string is integer -strict $ov_config(payload)]} {
			set ov_config(payload) 0
		}
		
		# Get the end time of the archive and check the file syntax.
		set ov_config(status) "Seeking"
		if {[catch {
			set ov_config(t_end) \
				[Neuroplayer_end_time $ov_config(fn) $ov_config(payload)]
		} message]} {
			Neuroplayer_print "ERROR: $message."
			return "FAIL"
		}
		set ov_config(t_min) "0.0"
		set ov_config(t_max) $ov_config(t_end)
		set ov_config(status) "Idle"

		# Plot the archive.	
		Neuroplayer_overview_plot
	}
	
	return "SUCCESS"
}

#
# Neuroplayer_overview_jump jumps to the point in the overview archive that
# lies under the coordinates (x,y) in the overview graph. We call it after a
# mouse double-click in the graph. We round the jump-to time to the nearest
# second so that accompanying synchronous video will have a key frame to show at
# the start of the interval.
#
proc Neuroplayer_overview_jump {x y} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_overview ov_config

	# Check the window and declare the overview array.
	if {![winfo exists $info(window)]} {return "ABORT"}
	if {![info exists ov_config]} {return "ABORT"}
	if {![winfo exists $ov_config(w)]} {return "ABORT"}

	# Calculate the play time.
	set ptime [expr round( 1.0 \
		* $x \
		/ $info(overview_width) \
		* ($ov_config(t_max) - $ov_config(t_min)) \
		+ $ov_config(t_min) \
		- (0.5 * $config(play_interval)) )]
	if {$ptime < 0} {set ptime 0}
	
	# Jump to the new location, using the file nake to seek the playback tree.
	Neuroplayer_jump "$ov_config(fn_tail) [format %.1f $ptime] \
			\"$config(channel_selector)\" \"Overview Jump\"" 0
}

#
# Neuroplayer_overview_cursor draws a vertical line over the plot to show the
# start of the current playback interval, assuming the file displayed is the 
# current play file.
#
proc Neuroplayer_overview_cursor {} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_overview ov_config

	# Check the window and declare the overview array.
	if {![winfo exists $info(window)]} {return "ABORT"}
	if {![info exists ov_config]} {return "ABORT"}
	if {![winfo exists $ov_config(w)]} {return "ABORT"}

	# Delete the old cursor, if any.
	$ov_config(plot) delete cursor

	# Check to see if the overview is showing the play file.
	if {[file tail $config(play_file)] != [file tail $ov_config(fn)]} {
		return "ABORT"
	}
	
	# Check to see if the play time is in the overview time span.
	if {($config(play_time) < $ov_config(t_min)) \
		|| ($config(play_time) > $ov_config(t_max))} {
		return "ABORT"
	}
	
	# Detect zero width interval.
	if {$ov_config(t_max) - $ov_config(t_min) <= 0} {
		Neuroplayer_print "ERROR: Cannot draw cursor on zero width overview."
		return "ERROR"
	}
	
	# Draw the new cursor.
	set x [expr round(1.0 \
		* ($config(play_time)  \
			+ (0.5 * $config(play_interval)) \
			- $ov_config(t_min)) \
		* $info(overview_width) \
		/ ($ov_config(t_max) - $ov_config(t_min)))]
	$ov_config(plot) create line "$x 0 $x $info(overview_height)" -tag "cursor" \
		-fill [lwdaq tkcolor [Neuroplayer_color $ov_config(cursor_cc)]]
	
	return "SUCCESS"
}

#
# Neuroplayer_overview_plot selects an existing overview window and re-plots
# its graphs using the current display parameters. 
#
proc Neuroplayer_overview_plot {} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_overview ov_config
	global LWDAQ_Info

	# Check the window and declare the overview array.
	if {![winfo exists $info(window)]} {return "ABORT"}
	if {![info exists ov_config]} {return "ABORT"}
	if {![winfo exists $ov_config(w)]} {return "ABORT"}
	set w $ov_config(w)
	if {$ov_config(status) != "Idle"} {return "ABORT"}

	# Check that the archive exists and is an ndf file. Extract the
	# data start address and data length.
	if {[catch {
		scan [LWDAQ_ndf_data_check $ov_config(fn)] %u%u data_start data_length
	} error_message]} {
		Neuroplayer_print "ERROR: Checking archive, $error_message."
		return "FAIL"
	}
	
	# Delete the old cursor, if any.
	$ov_config(plot) delete cursor

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
	
	# Create an array of graphs, one for each possible channel.
	for {set id $info(min_id)} {$id <= $info(max_id)} {incr id} {
		if {($config(channel_selector) == "*") \
			|| ([lsearch $config(channel_selector) "$id"] >= 0) \
			|| ([lsearch $config(channel_selector) "$id\:*"] >= 0) } {
			set graph($id) ""
		}
	}
	if {[lsearch $config(channel_selector) "0"] >= 0} {
		set graph(0) ""
	}

	# Seek the clock message just before and just after the plot interval.
	set ov_config(status) "Seeking"
	LWDAQ_update
	scan [Neuroplayer_seek_time $ov_config(fn) $ov_config(payload) $ov_config(t_min)] \
		%f%u%f%u ov_config(t_min) index_min dummy1 dummy2
	scan [Neuroplayer_seek_time $ov_config(fn) $ov_config(payload) $ov_config(t_max)] \
		%f%u%f%u dummy1 dummy2 ov_config(t_max) index_max

	# Read num_samples messages from the archive at random locations.
	set ov_config(status) "Reading"
	set ave_step [expr 2.0 * ($index_max - $index_min) / $config(overview_num_samples)]
	set message_length [expr $info(core_message_length) + $ov_config(payload)]
	set addr [expr $data_start + $message_length * $index_min]
	set addr_end [expr $data_start + $message_length * $index_max]
	set f [open $ov_config(fn) r]
	fconfigure $f -translation binary
	set samples ""
	while {$addr < $addr_end} {
		LWDAQ_support
		seek $f $addr
		binary scan [read $f $message_length] cSc id value timestamp
		set id [expr $id & 0xff]
		set value [expr $value & 0xffff]
		if {[info exists graph($id)] || ($id == 0)} {
			lappend samples "$id $value"
			set addr [expr $addr + $message_length * round(1 + ($ave_step-1)*rand())]
		} {
			set addr [expr $addr + $message_length]
		}
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
		if {[info exists graph($id)]} {
			append graph($id) "[format %.3f $archive_time] $value "
		}
	}	
	
	# Apply a glitch filter to the graphs of values and check their lengths.
	if {$config(glitch_threshold) > 0} {
		set saved_config [lwdaq_config]
		lwdaq_config -fsd $info(overview_fsd)
		for {set id $info(min_id)} {$id <= $info(max_id)} {incr id} {
			if {[info exists graph($id)]} {
				set filtered_graph [lwdaq glitch_filter_y \
					$config(glitch_threshold) $graph($id)]
				if {![LWDAQ_is_error_result $filtered_graph]} {
					set graph($id) $filtered_graph
				}
			}
		}
		eval lwdaq_config $saved_config
	}

	# Create the plot viewing ranges from the user parameters.
	if {$config(vt_mode) == "CP"} {
		set v_min [expr - $config(v_range) / 2 ]
		set v_max [expr + $config(v_range) / 2]
		set ac 1
	} elseif {$config(vt_mode) == "NP"} {
		set v_min 0
		set v_max 0
		set ac 0
	} else {
		set v_min $config(v_offset)
		set v_max [expr $config(v_offset) + $config(v_range)]
		set ac 0
	}

	# Plot all graphs that have more than the activity threshold number of 
	# points in them.
	set ov_config(status) "Plotting"
	set ov_config(activity) ""
	for {set id 0} {$id <= $info(max_id)} {incr id} {
		if {![info exists graph($id)]} {continue}
		if {($config(channel_selector) == "*") \
			&& ([llength $graph($id)] / 2 < \
			[expr $config(overview_activity_fraction)\
			* $config(overview_num_samples)])} {continue}
		LWDAQ_support
		if {![winfo exists $w]} {return "ABORT"}
		append ov_config(activity) "$id:[expr [llength $graph($id)] / 2] "
		lwdaq_graph $graph($id) $info(overview_image) \
			-x_min $ov_config(t_min) -x_max $ov_config(t_max) \
			-y_min $v_min -y_max $v_max \
			-color [Neuroplayer_color $id] -ac_couple $ac 
		lwdaq_draw $info(overview_image) $ov_config(photo)
	}
	
	# Re-draw the cursor.
	Neuroplayer_overview_cursor
	
	# Done.
	set ov_config(status) "Idle"
	return "SUCCESS"
}

#
# Neuroplayer_overview_excerpt extracts the overview time interval and writes
# it to disk as a newly-created NDF file, including all channels. This new
# archive will be written to a file Xt.ndf in the same directory as the original
# archive, where "X" is the letter X to begin the file name and "t" is the UNIX
# time taken from the original archive name. The new archive's metadata will
# include a comment giving the original file name and the time period extracted.
#
proc Neuroplayer_overview_excerpt {} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_overview ov_config
	
	set ov_config(t_min) [expr round($ov_config(t_min))]
	set ov_config(t_max) [expr round($ov_config(t_max))]
	
	# Check that the archive exists and is an ndf file. Extract the
	# data start address and data length.
	if {[catch {
		scan [LWDAQ_ndf_data_check $ov_config(fn)] %u%u data_start data_length
	} error_message]} {
		Neuroplayer_print "ERROR: Checking archive, $error_message."
		return "FAIL"
	}
	
	set ov_config(status) "Excerpt"
	LWDAQ_support

	scan [Neuroplayer_seek_time $ov_config(fn) $ov_config(payload) $ov_config(t_min)] \
		%f%u%f%u ov_config(t_min) index_min dummy1 dummy2
	scan [Neuroplayer_seek_time $ov_config(fn) $ov_config(payload) $ov_config(t_max) ] \
		%f%u%f%u dummy1 dummy2 ov_config(t_max) index_max
	set message_length [expr $info(core_message_length) + $ov_config(payload)]
	set addr [expr $data_start + $message_length * $index_min]
	set addr_end [expr $data_start + $message_length * $index_max]

	set excerpt_atime [expr round($ov_config(atime) + $ov_config(t_min))]
	set excerpt_fn [file join [file dirname $ov_config(fn)] "X"$excerpt_atime\.ndf]
	set metadata [LWDAQ_ndf_string_read $ov_config(fn)]
	LWDAQ_ndf_create $excerpt_fn $config(ndf_metadata_size)
	LWDAQ_ndf_string_write $excerpt_fn $metadata
	LWDAQ_ndf_string_append $excerpt_fn \
		"<c>Excerpt from $ov_config(fn_tail) spanning\
		$ov_config(t_min)-$ov_config(t_max) s.\
		[Neuroplayer_clock_convert [clock seconds]]</c>"
	set f [open $ov_config(fn) r]
	fconfigure $f -translation binary
	seek $f [expr $data_start + ($message_length * $index_min)]
	set contents [read $f [expr $message_length * ($index_max - $index_min)]]
	close $f
	LWDAQ_ndf_data_append $excerpt_fn $contents
		
	Neuroplayer_print "Created $excerpt_fn spanning\
		$ov_config(t_min)-$ov_config(t_max) of $ov_config(fn_tail)."
				
	set ov_config(status) "Idle"
}

#
# Neuroplayer_overview_newndf finds the file that is the one $step places
# after the overview file in the Player Directory Tree, switches the overview to
# the new file, and plots its contents.
#
proc Neuroplayer_overview_newndf {step} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_overview ov_config

	# Set the status show we are searching for the requested file.
	set ov_config(status) "Searching"
	LWDAQ_update

	# We obtain a list of all NDF files in the play_dir directory tree. If
	# can't find the current file in the directory tree, we abort.
	set fl [LWDAQ_find_files $config(play_dir) *.ndf]
	set fl [LWDAQ_sort_files $fl]
	set index [lsearch $fl $ov_config(fn)]
	if {$index < 0} {
		Neuroplayer_print "ERROR: In Overview, cannot find\
			\"[file tail $ov_config(fn)]\" in playback directory tree."
		set ov_config(status) "Idle"
		return "FAIL"
	}
	
	# We see if there is later file in the directory tree. If so,
	# switch to this file.
	set file_name [lindex $fl [expr $index + $step]]
	if {$file_name == ""} {
		Neuroplayer_print "ERROR: Overview cannot step $step from\
			\"[file tail $ov_config(fn)]\" in Player Directory Tree."
		set ov_config(status) "Idle"
		return "FAIL"	
	}
	set ov_config(fn) $file_name
	set ov_config(fn_tail) [file tail $ov_config(fn)]
	
	# Try to determine the start time of the new archive.
	if {![regexp {([0-9]{10})\.ndf} [file tail $ov_config(fn)] match atime]} {
		set atime 0
	}
	set ov_config(atime) $atime
	
	# Get the payload length from the file metadata.
	if {[catch {
		set metadata [LWDAQ_ndf_string_read $ov_config(fn)]
	} error_message]} {
		Neuroplayer_print "ERROR: $error_message."
		return "FAIL"			
	}
	set ov_config(payload) [LWDAQ_xml_get_list $metadata "payload"]
	if {![string is integer -strict $ov_config(payload)]} {
		set ov_config(payload) 0
	}

	# Determine the archive end time.
	set ov_config(t_end) [Neuroplayer_end_time $ov_config(fn) $ov_config(payload)]
	set ov_config(t_max) $ov_config(t_end)
	set ov_config(t_min) 0.0

	# Plot the overview of the new archive.
	set ov_config(status) "Idle"
	Neuroplayer_overview_plot
}

#
# Neuroclassifier allows us to view, jump to, and manipulate a list 
# of reference events with which new events may be compared for
# classification. The event classifier lists events like this:
#
# archive.ndf time channel event_type baseline_power m1 m2...
#
# It expects the Neuroplayer's processor to produce characteristics
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
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config

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
		return "ABORT"
	}
	toplevel $w
	wm title $w "Event Classifier for Neuroplayer $info(version)"
	
	# Create the classifier user interface.
	frame $w.controls1
	pack $w.controls1 -side top -fill x
	
	set f $w.controls1
	label $f.cv -text "0 Events" -width 15 -bg black -fg white
	set info(classification_label) $f.cv
	pack $f.cv -side left -expand yes

	label $f.rl -text "Match:" 
	label $f.rv -textvariable Neuroplayer_info(classifier_match) -width 5 
	pack $f.rl $f.rv -side left -expand yes

	label $f.mrl -text "Limit:" 
	entry $f.mre -textvariable Neuroplayer_config(classifier_match_limit) -width 5
	pack $f.mrl $f.mre -side left -expand yes

	label $f.etl -text "Threshold:" 
	entry $f.ete -textvariable Neuroplayer_config(classifier_threshold) -width 5
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
		Neuroplayer_config(classifier_y_metric) "none"]
	pack $f.yml $f.ym -side left -expand yes
	label $f.xml -text "x:"
	set info(classifier_x_menu) [tk_optionMenu $f.xm \
		Neuroplayer_config(classifier_x_metric) "none"]
	pack $f.xml $f.xm -side left -expand yes

	checkbutton $f.handler -text "Handler" \
		-variable Neuroplayer_config(enable_handler)
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
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info
	global LWDAQ_Info

	# Abort if running in no-graphics mode.
	if {![winfo exists $info(window)]} {return "ABORT"}
	if {![winfo exists $info(classifier_window)]} {return "ABORT"}
	
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
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info

	if {![winfo exists $info(classifier_window)]} {return "ABORT"}
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
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info

	if {![winfo exists $info(classifier_window)]} {return "ABORT"}

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
		Neuroplayer_print "ERROR: Cannot find event \"[lrange $event 0 2]\"."
		return "FAIL"
	}

	# We hilite the event and move it into the visible area of the
	# text window.
	$t tag add hilite "$index" "$index lineend"
	$t tag configure hilite -background lightgreen
	$t see $index
}

#
# Neuroclassifier_jump jumps to an event. It selects the event in the Classifier
# window, then calls the Neuroplayer's jump routine to navigate to the event.
#
proc Neuroclassifier_jump {event} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info

	if {![winfo exists $info(classifier_window)]} {return "ABORT"}

	Neuroclassifier_select $event
	Neuroplayer_jump $event 0
}

#
# Neuroclassifier_change finds an event in the text window
# and changes its event type. It then re-plots the event in the map.
#
proc Neuroclassifier_change {event} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info

	if {![winfo exists $info(classifier_window)]} {return "ABORT"}

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
		Neuroplayer_print "ERROR: Cannot find event \"[lrange $event 0 $info(sii)]\"."
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
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info

	if {![winfo exists $info(classifier_window)]} {return "ABORT"}

	if {$index == ""} {
		set index $info(classifier_index)
		incr info(classifier_index)
	}
	if {$event == ""} {
		set id [lindex $config(channel_selector) 0]
		if {([llength $id]>1) || ($id == "*")} {
			if {$info(window) == ""} {raise "."} {raise $info(window)}
			Neuroplayer_print "ERROR: Select a single channel to add to the library."
			return "ERROR"
		}
		set event "[file tail $config(play_file)]\
			[Neuroplayer_play_time_format \
				[expr $config(play_time) - $config(play_interval)]]\
			$id\
			Added"
		set jump 1
	} {
		set jump 0
	}
	
	set t $info(classifier_text)
	$t insert end " "
	$t tag bind event_$index <Button> [list LWDAQ_post \
		[list Neuroclassifier_jump $event]]
	$t insert end "<J>" "event_$index jumpbutton"
	$t tag bind type_$index <Button> [list LWDAQ_post \
		[list Neuroclassifier_change $event]]
	$t insert end "<C>" "type_$index changebutton"
	$t insert end " $event\n"
	$t see end
	
	if {$jump} {
		LWDAQ_post [list Neuroclassifier_jump $event]
	}

	return "SUCCESS"
}

#
# Neuroclassifier_metric_display sets up the x-y plot menus so they each contain
# all the metrics in the classifier_metrics list, and makes a checkbutton for each 
# metric to enable or disable the metric for classification.
#
proc Neuroclassifier_metric_display {} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info

	if {![winfo exists $info(classifier_window)]} {return "ABORT"}

	# Set up the x and y metric selection menues. Make sure the current 
	# value of the metric menu is one of those available. If not, set it
	# to the first available metric. If the metric list is empty, set
	# the menu selection to "none".
	foreach a {x y} {
		$info(classifier_$a\_menu) delete 0 end
		foreach b $config(classifier_metrics) {
			$info(classifier_$a\_menu) add command -label $b \
				-command "set Neuroplayer_config(classifier_$a\_metric) $b;\
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
					-variable Neuroplayer_info(metric_enable_$mlc) \
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
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info

	if {![winfo exists $info(classifier_window)]} {return "ABORT"}

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
		# Add the event to the library and plot it. Catch errors, which
		# will arise when we read the wrong file for an event list.
		if {[catch {
			Neuroclassifier_add $info(classifier_index) $event
			Neuroclassifier_plot event_$info(classifier_index) $event
			incr info(classifier_index)
		} error_message]} {
			Neuroplayer_print "ERROR: Bad event \"$event\"."
			return "ERROR"
		}
		
		# Check for user pressing Stop.
		LWDAQ_support
		if {$info(classifier_display_control) != "Run"} {
			return "ABORT"
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
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config

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
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info

	if {![winfo exists $info(classifier_window)]} {return "ABORT"}

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
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info
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
		Neuroplayer_print "ERROR: $error_result"
		return ""
	}
	
	if {![LWDAQ_is_error_result $index]} {
		set closest [lindex $cl [expr $index-1]]
	} {
		set closest 0
		Neuroplayer_print $index
		Neuroplayer_print "ERROR: The classified event is incorrectly formatted."
	}

	set distance 0.0
	foreach i $index_list {
		set z1 [lindex $metrics [expr $i-$info(sii)-$info(cbo)-1]]
		if {![string is double -strict $z1]} {
			Neuroplayer_print "ERROR: Invalid metrics provided by processor."
			return $closest
		}
		set z2 [lindex $closest $i]
		if {![string is double -strict $z2]} {
			Neuroplayer_print "ERROR: Invalid metrics provided by matching event."
			return $closest
		}
		set distance [expr $distance + ($z1-$z2)*($z1-$z2)]
	}
	set info(classifier_match) [format %.3f [expr sqrt($distance)]]

	return $closest
}

#
# Neuroclassifier_processing accepts a characteristics line as input. If there
# are mutliple channels recorded in this line, the routine separates the
# characteristics of each channel and forms a list of events, one for each
# channel. It searches the event library for each event, in case the event is a
# repeat of one that already exists in the library. If so, it hilites the event
# in the library and makes it visible in the text window. Otherwise, the routine
# checks to see if the event qualifies as unusual. The first metric should be
# greater than the classifier threshold. If the event is unusual, the routine
# finds the closest match to the event in the library and classifies the event
# as being of the same type. In either case, the routine plots the
# characteristics of the event upon the map. In the special case where we are
# re-processing the event libarary to obtain new metrics, the routine replaces
# the existing baseline power and metrics for each library event with the
# newly-calculated values from the processor.
#
proc Neuroclassifier_processing {characteristics} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info

	if {![winfo exists $info(classifier_window)]} {return "ABORT"}
	
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
			
			# Because we have already identified the type of this event by eye,
			# and stored it as such in the event list, we can be certain of its
			# type. But even if we know the type, if the power metric is below
			# the event threshold, we will call the interval Normal, and we
			# over-write its type in the event string we will display.
			if {[lindex $idc [expr $info(cbo)+1]] >= $config(classifier_threshold)} {
				set type [lindex $event [expr $info(sii) + $info(cto)]]
			} {
				set type "Normal"
				set event [lreplace $event [expr $info(cbo)+1]\
					[expr $info(cbo)+1] "Normal"]
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
		# arrays of the Neuroplayer. We also provide support for a TCPIP
		# socket whose name will be stored in sock. In the event of an error
		# we close this socket, so that the handler script does not have to
		# worry about sockets being left open.
		set sock "sock0"
		if {$config(enable_handler) && ($info(handler_script) != "")} {
			if {[catch {eval $info(handler_script)} error_result]} {
				Neuroplayer_print "ERROR: $error_result"
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
			Neuroplayer_command "Stop"
			set info(classifier_continue) 0
		}
	}
}

#
# Neuroclassifier_reprocess goes through the events in the text window and
# re-processes each of them so as to replace the old characteristics with 
# those generated by the Neuroplayer's current processor script. Before
# reprocessing, the routine sorts the events by event type, so that in the 
# new library, all events of the same type will be grouped together.
#
proc Neuroclassifier_reprocess {{index 0}} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info

	if {![winfo exists $info(classifier_window)]} {
		catch {unset info(reprocessing_event_list)}
		return "ABORT"
	}
	if {$index == 0} {
		if {[info exists info(reprocessing_event_list)]} {return "ABORT"}
		set info(reprocessing_event_list) [Neuroclassifier_event_list]
	} 
	if {($index > 0) && ![info exists info(reprocessing_event_list)]} {
		return "ABORT"
	}
	if {$index >= [llength $info(reprocessing_event_list)]} {
		set event_list [lsort -increasing \
			-index [expr $info(sii)+$info(cto)] \
			[Neuroclassifier_event_list]]
		Neuroclassifier_display $event_list
		catch {unset info(reprocessing_event_list)}
		return "FAIL"
	}
	if {![info exists info(reprocessing_event_list)]} {return "FAIL"}
	Neuroclassifier_jump [lindex $info(reprocessing_event_list) $index]
	if {$index < [llength $info(reprocessing_event_list)]} {
		LWDAQ_post [list Neuroclassifier_reprocess [incr index]]
	}
	return "SUCCESS"
}

#
# Neuroclassifier_compare goes through the event list and measures the
# distance between every pair of events of differing types, and compares
# this distance to the match limit. If the distance is less, the Classifier
# prints the pair of events to the Neuroplayer text window as a pair of
# potentially-contradictory events.
#
proc Neuroclassifier_compare {} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info

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
	Neuroplayer_print "\nComparison of Library Events" purple
	Neuroplayer_print "Threshold: $config(classifier_threshold),\
		limit: $config(classifier_match_limit),\
		metrics: $metric_list\." purple

	# Check that at least one metric is enabled.
	if {[llength $index_list] == 0} {
		Neuroplayer_print "ERROR: No events metrics enabled for comparison.\n"
		return "FAIL"
	}
	
	# Make a copy of the event library.
	set events [Neuroclassifier_event_list]
	if {[llength $events] == 0} {
		Neuroplayer_print "ERROR: No events in library to compare.\n"
		return "FAIL"
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
					Neuroplayer_print "Duplicates:"
					Neuroplayer_print_event $event1
					Neuroplayer_print_event $event2
				} {
					Neuroplayer_print "Contradiction:"
					Neuroplayer_print_event $event1
					Neuroplayer_print_event $event2
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
								Neuroplayer_print \
									"Overlap (Separation = [format %.3f $separation]):"
								Neuroplayer_print_event $event1
								Neuroplayer_print_event $event2
							}
						} {
							Neuroplayer_print "Mismatch:"
							Neuroplayer_print_event $event1
							Neuroplayer_print_event $event2
						}
					}
				}
			}
			LWDAQ_support
		}
	}
	catch {$info(classification_label) configure -text "Idle" -fg white -bg black}
	Neuroplayer_print "Done with $count Overlaps." purple
}

#
# Neuroclassifier_stop puts a stop to all reprocessing events by unsetting
# the event list, and stops playback as well.
#
proc Neuroclassifier_stop {} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info

	catch {unset info(reprocessing_event_list)}
	set info(classifier_display_control) "Stop"
	Neuroplayer_command "Stop"
}

proc Neuroclassifier_step {} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info

	if {!$config(enable_processing)} {
		Neuroplayer_print "ERROR: Processing is disabled."
		return
	}
	set info(classifier_continue) 0
	Neuroplayer_command "Step"
}

proc Neuroclassifier_back {} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info

	if {!$config(enable_processing)} {
		Neuroplayer_print "ERROR: Processing is disabled."
		return
	}
	set info(classifier_continue) 0
	Neuroplayer_command "Back"
}

proc Neuroclassifier_continue {} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info

	if {!$config(enable_processing)} {
		Neuroplayer_print "ERROR: Processing is disabled."
		return
	}
	set info(classifier_continue) 1
	Neuroplayer_command "Play"
}

#
# Neuroclassifier_batch_classification selects one or more characteristics 
# files and goes through them comparing each interval to the classifier
# events. It does this for the channels specified in the channel select
# string in the main Neuroplayer window. The result is a text window
# containing a list of events that we can cut and paste into a file.
#
proc Neuroclassifier_batch_classification {{state "Start"}} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info
	global nbc

	set w $info(classifier_window)\.nbc

	if {$state == "Start"} {
		if {[winfo exists $w]} {
			raise $w
			return "ABORT"
		}
		toplevel $w
		wm title $w "Batch Classification for Neuroplayer $info(version)"
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
		entry $f.te -textvariable Neuroplayer_config(classifier_threshold) \
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
		set nbc(channel_selector) "1 2 3 4 5 6 7 8 9 10 11 12 13 14"
		entry $f.sse -textvariable nbc(processing_channels) -width 35
		pack $f.ssl $f.sse -side left
		label $f.ll -text "Limit:" -fg blue
		entry $f.le -textvariable Neuroplayer_config(classifier_match_limit) \
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
				-variable Neuroplayer_info(metric_enable_$mlc) \
				-text $m
			pack $f.$mlc -side left -expand yes
		}
	}
	
	if {$state == "Classify"} {
		if {$nbc(run)} {return "ABORT"}
		
		if {![info exists nbc(fnl)]} {
			LWDAQ_print $nbc(t) "ERROR: Select input files."
			return "FAIL"
		}
		if {![info exists nbc(ofn)]} {
			LWDAQ_print $nbc(t) "ERROR: Specify output files."
			return "FAIL"
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
			return "FAIL"
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
			return "FAIL"
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
				if 	{[lsearch $nbc(processing_channels) $id] >= 0} {
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
					return "ABORT"
				}
				incr file_interval_count
				set archive [lindex $c 0]
				set play_time [lindex $c 1]
				set c [lrange $c 2 end]
				while {[llength $c] > 0} {
					set id [lindex $c 0]
					if {![string is integer -strict $id]} {
						LWDAQ_print $nbc(t) ""
						LWDAQ_print $nbc(t) "ERROR: Invalid characteristics\
							in \"[file tail $fn]\"."
						close $of
						set nbc(run) 0
						return "FAIL"
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
							if {$info(classifier_match) <= \
									$config(classifier_match_limit)} {						
								set type [lindex $closest [expr $info(sii)+$info(cto)]]
							} {
								set type "Unknown"
							}
							set event "$archive $play_time $id $type\
								$baseline_pwr $metrics"
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
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info

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
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info
	global LWDAQ_Info

	if {($config(classifier_library) != "") \
		&& [file exists [file dirname $config(classifier_library)]]} {
		set LWDAQ_Info(working_dir) [file dirname $config(classifier_library)]
	}
	if {$name == ""} {set name [LWDAQ_get_file_name]}
	if {$name == ""} {return ""}
	if {![file exists $name]} {
		Neuroplayer_print "ERROR: Cannot find \"[file tail $name]\"."
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
# detector coils and returns the position as a sequency of xyz coordinates
# accompanied by the power measurement provided by each detector coil. The
# routine relies upon a prior call to lwdaq_receiver filling a list of power
# measurements that correspond to some device we want to locate. This list
# exists in the lwdaq library global variable space, but not in the LWDAQ TclTk
# variable space. The indices allow the lwdaq_alt routine to find the message
# payloads in the data image that correspond to the device.
#
proc Neurotracker_extract {} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info(tracker_$info(channel_num)) history

	# Calculate the number of slices into which we should divide the playback
	# interval for location tracking. If we see an error, set an error flag
	# and print the error to the Neuroplayer text window, but don't abort.
	set num_slices [expr $config(tracker_sample_rate) * $config(play_interval)]
	if {$num_slices < 1.0} {
		set num_slices 1
	} else {
		set num_slices [expr round($num_slices)]
	}
	
	# Determine the number of detectors.
	set num_detectors [expr [llength $config(tracker_coordinates)]/3]
	
	# If the playload length does not match the number of detector coils, we
	# abort, because we are not playing a tracker archive. We fill the tracker
	# history with zeros for raw x, y, and z, filtered x, y, and z and activity,
	# but no entries for coil powers. The fake history contains num_slices + 1
	# entries, because the history usually contains the final slice from the
	# previous interval as the first entry.
	if {($info(player_payload) < 1) || ($info(player_payload) < $num_detectors)} {
		set history [list]
		for {set slice_num 0} {$slice_num <= $num_slices} {incr slice_num} {
			lappend history "0.0 0.0 0.0 0.0 0.0 0.0 0.0"
		}
		return "ABORT"
	}
	
	# Determine if this is a lossy interval.
	if {$info(loss)/100.0 < (1-$config(tracker_min_reception))} {
		set lossy 0
	} {
		set lossy 1
	}
	
	# Set error flag.
	set error_flag 0
	
	# If we have a signal for the current channel, obtain a tracker measurement,
	# which will be one line per slice. 
	if {($info(signal) != "0 0") && !$lossy} {
		if {[catch {
			set alt_result [lwdaq_alt $info(data_image) \
				$config(tracker_coordinates) \
				-payload $info(player_payload) \
				-scale $config(tracker_decade_scale) \
				-extent $config(tracker_extent_radius) \
				-slices $num_slices \
				-background $config(tracker_background)]
			} error_result]} {
			Neuroplayer_print $error_result
			set error_flag 1
		}
	} 
	
	# If we don't have a signal, perhaps because of reception loss, or we have
	# encountered an error, we leave the existing tracker history in place by
	# simply exiting this routine now. If we have no history, we make a fake
	# one. Each history entry contains raw x, y, and z, filtered x, y, and z and
	# activity.
	if {($info(signal) == "0 0") || $lossy || $error_flag} {
		if {![info exists history]} {
			set history [list]
			for {set slice_num 0} {$slice_num <= $num_slices} {incr slice_num} {
				lappend history "0.0 0.0 0.0 0.0 0.0 0.0 0.0"
			}
		}
		return "ABORT"
	}
	
	# Split up the tracker result into a list delimited by line breaks.
	set alt_result [split [string trim $alt_result] \n]
	
	# If a history exists for this channel, delete all but the final slice
	# of the history. Otherwise, start the history with the coordinates 
	# given in the first slice of this interval, and zero for activity. 
	# We do not bother adding fake coil powers to the initializing slice
	# because we will never refer to the coil powers in the last slice
	# from the previous interval.
	if {[info exists history]} {
		set history [list [lindex $history end]]
	} {
		set first_position [lrange [lindex $alt_result 0] 0 2]
		set history [list "$first_position $first_position 0.000"]
	}
	
	# To start our filter, we need the values of raw and filtered centroid 
	# position from the slice before the first slice of this interval, which
	# would be the last slice of the previous interval.
	scan [lindex $history 0] %f%f%f%f%f%f x1 y1 z1 xx1 yy1 zz1
	
	# We generate the filtered centroid position with a single-pole recursive
	# low-pass filter governed by a single constant a0, from which we derive
	# a second constant b0 = 1 - a0. We obtain a0 from a look-up table using
	# the ratio of the sample rate to the cut-off frequency, which we present
	# to the user as filter_divisor.
	set index [lsearch -index 0 $info(tracker_filter_database) \
		$config(tracker_filter_divisor)]
	set a0 [lindex $info(tracker_filter_database) $index 1]
	set b1 [expr 1.0 - $a0]
	
	# We create the history for this interval by filtering the raw centroid
	# position and calculating acitivty. For each slice, we create a string with
	# the raw position, filtered position, activity, and coil powers. The units
	# of position are the same as those in the coil coordinate array. The units
	# of activity are these same units divided by seconds. Activity for each
	# slice is the absolute distance moved by the filtered position from the
	# previous slice to the current slice, multiplied by the sample rate to
	# produce a value for speed, which is our measurement of activity.
	foreach slice $alt_result {
		scan $slice %f%f%f x0 y0 z0
		set xx0 [format %.6f [expr ($xx1 * $b1) + ($a0 * $x0)]]
		set yy0 [format %.6f [expr ($yy1 * $b1) + ($a0 * $y0)]]
		set zz0 [format %.6f [expr ($zz1 * $b1) + ($a0 * $z0)]]
		set activity [format %.2f [expr $config(tracker_sample_rate) * \
			sqrt(($xx1-$xx0)*($xx1-$xx0) \
			+ ($yy1-$yy0)*($yy1-$yy0) \
			+ ($zz1-$zz0)*($zz1-$zz0))]]
		lappend history "$x0 $y0 $z0\
			$xx0 $yy0 $zz0\
			$activity\
			[lrange $slice 3 end]"
		set x1 $x0
		set y1 $y0
		set z1 $z0
		set xx1 $xx0
		set yy1 $yy0
		set zz1 $zz0
	}
	
	# In verbose mode, we print the unfiltered position and powers from the
	# final tracker slice.
	set final_slice [lindex $history end]
	Neuroplayer_print "Tracker: [lrange $final_slice 0 2]\
		[lrange $final_slice 7 end]" verbose
	
	# Return a success flag.
	if {$error_flag} {
		return "ERROR"
	} {
		return "SUCCESS"
	}
}

#
# Neurotracker_open opens the tracker window and creates the graphical images and
# photos required to plot the tracks.
#
proc Neurotracker_open {} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	global LWDAQ_Info
	
	# Abort if we don't have graphics.
	if {!$info(gui)} {return "ABORT"}

	# Open the tracker window, unless it exists already.
	set w $info(tracker_window)
	if {[winfo exists $w]} {
		raise $w
		return ""
	}
	toplevel $w
	wm title $w "Neurotracker for Neuroplayer $info(version)"	
	
	# Create configuration fields.
	set f [frame $w.config]
	pack $f -side top -fill x
	foreach a {decade_scale extent_radius} {
		label $f.l$a -text $a
		entry $f.e$a -textvariable Neuroplayer_config(tracker_$a) -width 4
		pack $f.l$a $f.e$a -side left -expand yes
	}
	label $f.lsps -text "sample_rate"
	tk_optionMenu $f.msps Neuroplayer_config(tracker_sample_rate) \
		1 2 4 8 16 32 64
	$f.msps configure -width 3
	pack $f.lsps $f.msps -side left -expand yes
	label $f.ldiv -text "filter_divisor"
	tk_optionMenu $f.mdiv \
		Neuroplayer_config(tracker_filter_divisor) \
		1 8 16 32 64 128 256 512
	$f.mdiv configure -width 3
	pack $f.ldiv $f.mdiv -side left -expand yes
	label $f.lp -text "persistence"
	tk_optionMenu $f.mp \
		Neuroplayer_config(tracker_persistence) \
		None Path Mark
	pack $f.lp $f.mp -side left -expand yes
	checkbutton $f.tsc -text "Coils" \
		-variable Neuroplayer_config(tracker_show_coils)
	pack $f.tsc -side left -expand yes
	
	# Create control buttons.
	set f [frame $w.control]
	pack $f -side top -fill x
	foreach a {Play Step Stop Repeat Back} {
		set b [string tolower $a]
		button $f.$b -text $a -command "Neuroplayer_command $a"
		pack $f.$b -side left -expand yes
	}
	button $f.clear -text Clear -command Neurotracker_clear
	pack $f.clear -side left -expand yes
	label $f.li -text "Time (s):"
	entry $f.ei -textvariable Neuroplayer_config(play_time) -width 8
	pack $f.li $f.ei -side left -expand yes
	
	# Create the map photo and canvass widget.
	set bd $info(tracker_image_border_pixels)
   	set info(tracker_photo) [image create photo "_neurotracker_photo_"]
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
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	global LWDAQ_Info	

	# Find the detector coil range.
	set x_min [lindex $config(tracker_coordinates) 0]
	set x_max $x_min
	set y_min [lindex $config(tracker_coordinates) 1]
	set y_max $y_min
	foreach {x y z} $config(tracker_coordinates) {
		if {$x >= 0} {
			if {$x > $x_max} {set x_max $x}
			if {$x < $x_min} {set x_min $x}
			if {$y > $y_max} {set y_max $y}
			if {$y < $y_min} {set y_min $y}
		}
	}
	set bd $info(tracker_range_border)
	set x_min [expr $x_min - $bd]
	set y_min [expr $y_min - $bd]
	set x_max [expr $x_max + $bd]
	set y_max [expr $y_max + $bd]
	set info(tracker_range) "$x_min $x_max $y_min $y_max"

	# Return now if the tracker window is unavailable.
	if {![winfo exists $info(tracker_window)]} {return "FAIL"}
	
	# Clear canvass widget.
	$info(tracker_plot) delete location
	$info(tracker_plot) delete power

	# Clear the overlay unless we are keeping a history.
	if {$config(tracker_persistence) == "None"} {
		lwdaq_graph "0 0" $info(tracker_image) -fill 1
	}

	# Mark the coil locations.
	foreach {x y z} $config(tracker_coordinates) {
		if {($x < 0) || ($y < 0)} {continue}
		lwdaq_graph "$x $y_min $x $y_max" $info(tracker_image) \
			-x_min $x_min -x_max $x_max -x_div 0 \
			-y_min $y_min -y_max $y_max -y_div 0 \
			-color 11
		lwdaq_graph "$x_min $y $x_max $y" $info(tracker_image) \
			-x_min $x_min -x_max $x_max -x_div 0 \
			-y_min $y_min -y_max $y_max -y_div 0 \
			-color 11
	}
	
	return "SUCCESS"
}

#
# Neurotracker_plot plots the locus of the current transmitter channel centroid
# in the tracker window. 
#
proc Neurotracker_plot {} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info(tracker_$info(channel_num)) history
	global LWDAQ_Info	

	# Abort if running in no-gui mode or window does not exist.
	if {!$info(gui)} {return "ABORT"}
	if {![winfo exists $info(tracker_window)]} {return "ABORT"}
	
	# Set colors and the source of the location values.
	set color [Neuroplayer_color $info(channel_num)]
	
	# If the locations string is empty, we get the locations we want to plot from
	# the history string. 
	if {![info exists history]} {return "ERROR"}
	
	# Find the range of x and y values we must cover.
	scan $info(tracker_range) %f%f%f%f x_min x_max y_min y_max
	
	# Plot the path if requested.
	if {$config(tracker_persistence) == "Path"} {
		set xy ""
		foreach p $history {append xy "[lindex $p 3] [lindex $p 4] "}
		lwdaq_graph $xy $info(tracker_image) \
			-y_min $y_min -y_max $y_max -x_min $x_min -x_max $x_max -color $color
	}

	# Make marks if requested.
	if {$config(tracker_persistence) == "Mark"} {
		foreach p $history {
			set x [lindex $p 3]
			set y [lindex $p 4]
			set w $config(tracker_mark_cm)
			lwdaq_graph "[expr $x-$w] [expr $y-$w] [expr $x-$w] [expr $y+$w] \
				[expr $x+$w] [expr $y+$w] [expr $x+$w]\
				[expr $y-$w] [expr $x-$w] [expr $y-$w]" \
				$info(tracker_image) \
				-y_min $y_min -y_max $y_max -x_min $x_min -x_max $x_max -color $color
		} 
	}

	# Determine border and color.
	set bd $info(tracker_image_border_pixels)
	set tkc [lwdaq tkcolor $color]

	# Mark the coil powers.
	if {$config(tracker_show_coils)} {
		set num_detectors [expr [llength $config(tracker_coordinates)]/3]
		set tracker_powers [lrange [lindex $history end] 7 end]
		set min_p 255
		set max_p 0
		foreach p $tracker_powers {
			if {$p > $max_p} {set max_p $p}
			if {$p < $min_p} {set min_p $p}
		}
		for {set i 0} {$i < $num_detectors} {incr i} {
			set coil_x [lindex $config(tracker_coordinates) [expr 3*$i]]
			set coil_y [lindex $config(tracker_coordinates) [expr 3*$i+1]]
			if {($coil_x < 0) || ($coil_y < 0)} {continue}
			set coil_p [lindex $tracker_powers $i]
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

	# Place a circle on the most recent position.
	if {[llength $history] >= 1} {
		set tracker_x [lindex $history end 3]
		set tracker_y [lindex $history end 4]
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
	}	

	# Detect errors.
	if {[lwdaq_error_string] != ""} {Neuroplayer_print [lwdaq_error_string]}
	LWDAQ_support
	return "SUCCESS"
}

#
# Neurotracker_draw_graphs draws the traker graphs in the tracker window.
#
proc Neurotracker_draw_graphs {} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	global LWDAQ_Info	

	# Abort if running in no-gui mode.
	if {!$info(gui)} {return "ABORT"}
	if {![winfo exists $info(tracker_window)]} {return "ABORT"}

	# Draw the tracker picture.
	lwdaq_draw $info(tracker_image) $info(tracker_photo)
	return "SUCCESS"
}

#
# Neurotracker_clear clears the display and the history.
#
proc Neurotracker_clear {} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config

	set names [array names info]
	foreach a $names {
		if {[string match "tracker_history_*" $a]} {
			unset info($a)
		}
	}
	set saved $config(tracker_persistence)
	set config(tracker_persistence) "None"
	Neurotracker_fresh_graphs
	set config(tracker_persistence) $saved
	Neurotracker_draw_graphs
}

#
# Neuroplayer_clock opens the Clock Panel, or raises it to the top 
# for viewing if it already exists.
#
proc Neuroplayer_clock {} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config

	# Open the clock window.
	set w $info(datetime_panel)
	if {[winfo exists $w]} {
		raise $w
		return "ABORT"
	}
	toplevel $w
	wm title $w "Clock Panel, Neuroplayer $info(version)"

	label $w.pl -text "Archive Play Time" -fg blue -width 20
	label $w.plc -textvariable Neuroplayer_info(datetime_play_time)
	button $w.pli -text "Insert" -command {
		set Neuroplayer_config(datetime_jump_to) \
			$Neuroplayer_info(datetime_play_time)
	}
	label $w.al -text "Archive Start Time" -fg blue
	label $w.alc -textvariable Neuroplayer_info(datetime_start_time)
	button $w.ali -text "Insert" -command {
		set Neuroplayer_config(datetime_jump_to) \
			$Neuroplayer_info(datetime_start_time)
	}
	button $w.jl -text "Jump to Time" -command [list LWDAQ_post \
		[list Neuroplayer_clock_jump]] -fg blue
	entry $w.jlc -textvariable Neuroplayer_config(datetime_jump_to) -width 20
	button $w.jli -text "Now" -command {
		set Neuroplayer_config(datetime_jump_to) \
			[Neuroplayer_clock_convert [clock seconds]]
	}
	
	grid $w.pl $w.plc $w.pli -sticky news
	grid $w.al $w.alc $w.ali -sticky news
	grid $w.jl $w.jlc $w.jli -sticky news

	Neuroplayer_clock_update
}

#
# Neuroexporter_open creates the Export Panel, or raises it to the top 
# for viewing if it already exists.
#
proc Neuroexporter_open {} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config

	# Open the export panel.
	set w $info(export_panel)
	if {[winfo exists $w]} {
		raise $w
		return "ABORT"
	}
	toplevel $w
	wm title $w "Exporter Panel for Neuroplayer $info(version)"

	set f [frame $w.control]
	pack $f -side top -fill x
	label $f.state -textvariable Neuroplayer_info(export_state) -fg blue -width 10
	button $f.export -text "Start" -command "LWDAQ_post Neuroexporter_export"
	button $f.stop -text "Abort" -command {Neuroexporter_export "Stop"}
	pack $f.state $f.export $f.stop -side left -expand yes
	
	label $f.lformat -text "File:" -anchor w -fg $info(label_color)
	pack $f.lformat -side left -expand yes
	foreach a "TXT BIN EDF" {
		set b [string tolower $a]
		radiobutton $f.$b -variable Neuroplayer_config(export_format) \
			-text $a -value $a
		pack $f.$b -side left -expand yes
	}
	checkbutton $f.sf -variable Neuroplayer_config(export_combine) \
		-text "Combine"
	pack $f.sf -side left -expand yes	
	
	button $f.dir -text "PickDir" -command {
		set ndir [LWDAQ_get_dir_name]
		if {($ndir != "") && ([file exists $ndir])} {
			set Neuroplayer_config(export_dir) $ndir
			LWDAQ_print $Neuroplayer_info(export_text) \
				"Set export directory to $Neuroplayer_config(export_dir)."
		}
	}
	pack $f.dir -side left -expand yes

	button $f.help -text "Help" -command "LWDAQ_url_open $info(export_help_url)"
	pack $f.help -side left -expand yes
	
	set f [frame $w.limits]
	pack $f -side top -fill x
	
	label $f.sl -text "Start:" -anchor w -fg $info(label_color) 
	label $f.slv -textvariable Neuroplayer_config(export_start) -anchor w
	pack $f.sl $f.slv -side left -expand yes 
	
	label $f.dl -text "Duration (s):" -anchor w -fg $info(label_color) 
	entry $f.dlv -textvariable Neuroplayer_config(export_duration) -width 14
	pack $f.dl $f.dlv -side left -expand yes 
	
	label $f.ql -text "Repetitions:" -anchor w -fg $info(label_color)
	entry $f.qlv -textvariable Neuroplayer_config(export_reps) -width 3
	pack $f.ql $f.qlv -side left -expand yes 
	
	button $f.ssi -text "Interval Beginning" -command {
		Neuroexporter_begin "Interval"
	}
	button $f.ssa -text "Archive Beginning" -command {
		Neuroexporter_begin "Archive"
	}
	pack $f.ssi $f.ssa -side left -expand yes 

	button $f.clock -text "Clock" -command "LWDAQ_post Neuroplayer_clock"
	pack $f.clock -side left -expand yes

	set f [frame $w.select]
	pack $f -side top -fill x
	
	label $f.lchannels -text "Select (ID:SPS):" -anchor w -fg $info(label_color)
	entry $f.echannels -textvariable Neuroplayer_config(channel_selector) -width 70	
	button $f.auto -text "Autofill" -command {
		set Neuroplayer_config(channel_selector) "*"
		LWDAQ_post [list Neuroplayer_play "Repeat"]
		LWDAQ_post Neuroplayer_autofill
	}
	pack $f.lchannels $f.echannels $f.auto -side left -expand yes

	set f [frame $w.data]
	pack $f -side top -fill x
	
	label $f.ldata -text "Data to Export:" -anchor w -fg $info(label_color)
	pack $f.ldata -side left -expand yes
	
	checkbutton $f.se -variable Neuroplayer_config(export_signal) \
		-text "Signal" 
	pack $f.se -side left -expand yes

	checkbutton $f.ae -variable Neuroplayer_config(export_activity) \
		-text "Activity" 
	pack $f.ae -side left -expand yes

	checkbutton $f.ve -variable Neuroplayer_config(export_video) \
		-text "Video" 
	pack $f.ve -side left -expand yes

	checkbutton $f.ce -variable Neuroplayer_config(export_centroid) \
		-text "Centroid" 
	pack $f.ce -side left -expand yes

	checkbutton $f.pe -variable Neuroplayer_config(export_powers) \
		-text "Powers" 
	pack $f.pe -side left -expand yes

	label $f.lsetup -text "Setup:" -anchor w -fg $info(label_color)
	pack $f.lsetup -side left -expand yes
	
	button $f.ts -text "Tracker" -command "LWDAQ_post Neurotracker_open"
	pack $f.ts -side left -expand yes

	button $f.edfs -text "EDF" -command "LWDAQ_post Neuroexporter_edf_setup"
	pack $f.edfs -side left -expand yes

	button $f.texts -text "TXT" -command "LWDAQ_post Neuroexporter_txt_setup"
	pack $f.texts -side left -expand yes

	set info(export_text) [LWDAQ_text_widget $w 60 25 1 1]
	
	# If we have opened the Exporter Panel when the Exporter is Idle, we now
	# initialize the export start time to the start of the current playback
	# archive.
	if {$info(export_state) == "Idle"} {
		LWDAQ_post {Neuroplayer_play "Reload"}
		LWDAQ_post {Neuroexporter_begin "Archive"}
	}
}

#
# Neuroexporter_begin sets the start time of the export to the beginning
# of the current interval or the beginning of the current archive.
#
proc Neuroexporter_begin {where} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	
	# Decide where to write messages. If the Exporter panel is not open, we write
	# messages to the Neuroplayer text window.
	if {[winfo exists $info(export_text)]} {
		set t $info(export_text)
	} {
		set t $info(text)
	}

	# Set the export start time according to where.	
	switch $where {
		"Interval" {
			set config(export_start) [Neuroplayer_clock_convert \
				[expr [Neuroplayer_clock_convert \
					$info(datetime_start_time)] \
					+ round($info(t_min)) ]]
			LWDAQ_print $t "Export start time: $config(export_start),\
				$info(t_min) s in [file tail $config(play_file)]."
		}
		default {
			set config(export_start) $info(datetime_start_time)
			LWDAQ_print $t "Export start time: $config(export_start),\
				0.0 s in [file tail $config(play_file)]."
		}
	}
	
	# Return the export start time.
	return $config(export_start)
}

#
# Neuroplayer_autofill fills the channel select field with the Neuroplayer's
# best guess as to all the channels that are active in the most recently-played
# interval. We report the outcome of the autofill to the export panel and the
# main Neuroplayer window.
#
proc Neuroplayer_autofill {} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config

	set autofill ""
	for {set id $info(min_id)} {$id <= $info(max_id)} {incr id} {
		if {$info(status_$id) == "Okay"} {
			append autofill "$id\:[set info(sps_$id)] "
		}		
	}
	if {$autofill == ""} {
		LWDAQ_print $info(export_text) "Autofill found no active channels.\
			Setting channel select to \"*\". Play one interval and try again."
		Neuroplayer_print "Autofill found no active channels.\
			Setting channel select to \"*\". Play one interval and try again."
		set config(channel_selector) "*"
		return "FAIL"
	}
	set config(channel_selector) [string trim $autofill]
	return "SUCCESS"
}

#
# Neuroexporter_edf_read reads the header of an EDF file and fills the EDF setup
# array and composes a new channel selector string from the channels and sample
# rates in the EDF file. It does not read any data from the file.
#
proc Neuroexporter_edf_read {} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config

	set fn [LWDAQ_get_file_name]
	if {$fn == ""} {retuen "ABORT"}
	set signals [EDF_header_read $fn]
	set s [list]
	foreach {id fq} $signals {
		if {[string is integer $id]} {
			lappend s "$id\:$fq"
		}
	}
	set config(channel_selector) $s
	Neuroexporter_edf_setup
	return $fn
}

#
# Neurotracker_edf_setup is used by the exporter to set the various titles and names
# that the EDF export file header provides for describing signals and defining their
# ranges. 
#
proc Neuroexporter_edf_setup {} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	global EDF

	# Open the EDF setup panel.
	package require EDF 1.2
	set w $info(edf_panel)
	if {[winfo exists $w]} {destroy $w}
	toplevel $w
	scan [wm maxsize .] %d%d x y
	wm maxsize $w [expr $x*2] [expr $y*2]
	wm title $w "European Data Format Setup, Neuroplayer $info(version)"

	set f [frame $w.controls]
	pack $f -side top -fill x
	
	label $f.lchannels -text "Select (ID:SPS):" -anchor w -fg $info(label_color)
	entry $f.echannels -textvariable Neuroplayer_config(channel_selector) -width 80	
	button $f.auto -text "Autofill" -command {
		set Neuroplayer_config(channel_selector) "*"
		LWDAQ_post [list Neuroplayer_play "Repeat"]
		LWDAQ_post Neuroplayer_autofill
	}
	pack $f.lchannels $f.echannels $f.auto -side left -expand yes
	
	button $f.read -text "Read" -command "LWDAQ_post Neuroexporter_edf_read"
	pack $f.read -side left -expand yes

	button $f.refresh -text "Refresh" -command Neuroexporter_edf_setup
	pack $f.refresh -side left -expand yes

	set f [frame $w.header]
	pack $f -side top -fill x
	
	foreach a {Patient Recording} {
		set b [string tolower $a]
		label $f.l$b -text "$a\:" -fg $info(label_color) 
		entry $f.e$b -textvariable EDF($b) -width 50
		pack $f.l$b $f.e$b -side left -expand yes
	}
	
	foreach code $config(channel_selector) {
		set code [split $code :]
		set id [lindex $code 0]
		if {![string is integer -strict $id]} {
			LWDAQ_print $info(export_text) "ERROR: Bad channel number \"$code\"\
				in EDF setup, try Autofill."
			raise $info(export_panel)
			break
		}
		set sps [lindex $code 1]
		if {![string is integer -strict $sps]} {
			Neuroplayer_print "ERROR: Bad sample rate \"$sps\" for channel $id\
				in EDF setup, try Autofill."
			raise $info(export)
			break
		}
		if {$config(export_signal)} {
			set f [frame $w.details_$id]
			pack $f -side top -fill x
			label $f.lid -text "Name:" -fg $info(label_color)
			label $f.vid -text "$id"
			set EDF(name_$id) "$id"
			label $f.lsps -text "SPS:" -fg $info(label_color)
			label $f.vsps -text "$sps"
			pack $f.lid $f.vid $f.lsps $f.vsps -side left -expand yes
			foreach {a len} {Transducer 30 Unit 4 Min 6 Max 6 Lo 6 Hi 6 Filter 16} {
				set b [string tolower $a]
				if {![info exists EDF($b\_$id)]} {
					set EDF($b\_$id) [set EDF($b)]
				}
				label $f.l$b -text "$a\:" -fg $info(label_color) 
				entry $f.e$b -textvariable EDF($b\_$id) -width $len
				pack $f.l$b $f.e$b -side left -expand yes
			}
		}
		if {$config(export_activity)} {
			set id_a "[set id]a"
			set sps $config(tracker_sample_rate)
			set f [frame $w.details_$id_a]
			pack $f -side top -fill x
			label $f.lid -text "Name:" -fg $info(label_color) 
			label $f.vid -text "$id_a" 
			set EDF(name_$id_a) "$id_a"
			label $f.lsps -text "SPS:" -fg $info(label_color)
			label $f.vsps -text "$sps"
			pack $f.lid $f.vid $f.lsps $f.vsps -side left -expand yes
			foreach {a len} {Transducer 30} {
				set b [string tolower $a]
				label $f.l$b -text "$a\:" -fg $info(label_color) 
				entry $f.e$b -textvariable EDF($b\_$id_a) -width $len
				pack $f.l$b $f.e$b -side left -expand yes
			}
			if {[set EDF(transducer_$id_a)] == ""} {
				set EDF(transducer_$id_a) "Tracker"
			}
			foreach {a len} {Unit 4 Min 6 Max 6 Lo 6 Hi 6 Filter 16} {
				set b [string tolower $a]
				label $f.l$b -text "$a\:" -fg $info(label_color) 
				label $f.e$b -textvariable EDF($b\_$id_a) -width $len
				pack $f.l$b $f.e$b -side left -expand yes
			}
			set EDF(unit_$id_a) "mm/s"
			set EDF(min_$id_a) "0"
			set EDF(max_$id_a) $config(export_activity_max)
			set EDF(lo_$id_a) $EDF(lo)
			set EDF(hi_$id_a) $EDF(hi)
			if {$config(tracker_filter_divisor) == 1} {
				set EDF(filter_$id_a) "None"
			} {
				set EDF(filter_$id_a) "0.0-[format %.3f \
					[expr 1.0 * $config(tracker_sample_rate) \
					/ $config(tracker_filter_divisor)]] Hz"
			}
		}
	}
}

#
# Neuroexporter_txt_setup opens a panel in which we can create a text header
# that will be written to the start of a text export file.
#
proc Neuroexporter_txt_setup {} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config

	# Raise the setup panel if it already exists.
	set w $info(text_panel)
	if {[winfo exists $w]} {
		raise $w
		return "ABORT"
	}
	
	# Create the text setup panel.	
	toplevel $w
	wm title $w "TXT Setup Panel, Neuroplayer $info(version)"
	LWDAQ_text_widget $w 40 10
	LWDAQ_enable_text_undo $w.text
	LWDAQ_bind_command_key $w s [list Neuroexporter_txt_save $w]
	
	# Create the Save button.
	frame $w.f
	pack $w.f -side top
	button $w.f.save -text "Save" -command [list Neuroexporter_txt_save $w]
	pack $w.f.save -side left
	
	# Print the metadata to the text window.
	if {$config(export_txt_header) != ""} {
		LWDAQ_print $w.text $config(export_txt_header)
	}
	
	# Return successful.
	return "SUCCESS"
}


#
# Neuroexporter_txt_save transfers the contents of the exporter's TXT setup
# window into the TXT header variable. White space is removed by the routine
# before storing in the variable. The header will be written to to export files
# only if it is not empty. If it is written, it will be written with a carriage
# return at the end.
#
proc Neuroexporter_txt_save {w} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config

	set config(export_txt_header) [string trim [$w.text get 1.0 end]]
	return "SUCCESS"
}

#
# Neuroexporter_export manages the exporting of recorded signals to files,
# tracker signals to files, and the creation of simultaneous video to
# concatinated video files. that match the export intervals.
#
proc Neuroexporter_export {{cmd "Start"}} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	
	# Decide where to write messages. If the Exporter panel is not open, we write
	# messages to the Neuroplayer text window.
	if {[winfo exists $info(export_text)]} {
		set t $info(export_text)
	} {
		set t $info(text)
	}
	
	# Establish file extension, which is the file format in lower case.
	set ext [string tolower $config(export_format)]
	if {$config(export_format) == "EDF"} {
		package require EDF 1.2
	}	
	
	# If the command is stop, abort all export processes.
	if {$cmd == "Stop"} {
		if {$info(export_state) != "Idle"} {
			LWDAQ_print $t "Aborting export at\
				$config(play_time) s in archive\
				[file tail $config(play_file)].\n" purple
		}
		Neuroplayer_command "Stop"
		foreach pid $info(export_epl) {
			LWDAQ_process_stop $pid
		}
		set info(export_state) "Idle"
		return "SUCCESS"
	}

	# If the command is start, begin the export process.
	if {$cmd == "Start"} {

		# Check the current state of the exporter.
		if {$info(export_state) != "Idle"} {
			LWDAQ_print $t "WARNING: Exporter already started,\
				press stop before starting again."
			return "ERROR"
		}

		# Check for incompatible options.
		if {$config(export_centroid) || $config(export_powers)} {
			if {$config(export_format) == "EDF"} {
				LWDAQ_print $t "ERROR: Cannot store centroid or powers in EDF."
				return "ERROR"
			}
		}	
		if {round([expr $config(export_duration)]) \
				% round($config(play_interval)) != 0} {
			LWDAQ_print $t "WARNING: Export duration is not an exact\
				multiple of playback interval, actual duration will be longer."
		}

		# Start the exporter. Calculate Unix start and end times. The duration
		# can be a mathematical expression, such as 24*60*60 for the number of
		# seconds in a day.
		set info(export_state) "Start"
		set info(export_run_start) [clock seconds]	
		set info(export_start_s) [Neuroplayer_clock_convert $config(export_start)]
		set info(export_end_s) [expr $info(export_start_s) \
			+ [expr $config(export_duration)]]
		LWDAQ_print $t "\nStarting export of\
				[expr $config(export_duration)] s\
			from time $config(export_start)." purple
		LWDAQ_print $t "Start absolute time $info(export_start_s) s,\
			end absolute time $info(export_end_s) s."
		set archive_start_time [expr \
			$info(export_start_s) \
			- [Neuroplayer_clock_convert $info(datetime_start_time)]]
		LWDAQ_print $t \
			"Start archive time $archive_start_time s in [file tail $config(play_file)]."
		LWDAQ_print $t "Export directory \"$config(export_dir)\"."		
		if {![file exists $config(export_dir)]} {
			LWDAQ_print $t "ERROR: Directory \"$config(export_dir)\" does not exist."
			return "ERROR"
		}
		
		# Check the channel select string and clean up existing export files.
		set config(channel_selector) [string trim $config(channel_selector)]
		set signals [list]
		foreach channel $config(channel_selector) {
			if {$channel == "*"} {
				LWDAQ_print $t \
					"ERROR: Cannot use wildcard channel select, aborting export.\
						Use Autofill or enter select string by hand."
				LWDAQ_post "Neuroexporter_export Stop"
				return "ERROR"
			}
			set id [lindex [split $channel :] 0]		
			if {![string is integer -strict $id] \
					|| ($id < $info(clock_id)) \
					|| ($id > $info(max_id))} {
				LWDAQ_print $t \
					"ERROR: Invalid channel id \"$id\", aborting export."
				LWDAQ_post "Neuroexporter_export Stop"
				return "ERROR"
			}
			set sps [lindex [split $channel :] 1]
			if {$sps == ""} {
				LWDAQ_print $t \
					"ERROR: No sample rate specified for channel $id, aborting export."
				LWDAQ_post "Neuroexporter_export Stop"
				return "ERROR"
			}
			if {[lsearch "16 32 64 128 256 512 1024 2048 4096" $sps] < 0} {
				LWDAQ_print $t \
					"ERROR: Invalid sample rate \"$sps\", aborting export."
				LWDAQ_post "Neuroexporter_export Stop"
				return "ERROR"
			}
			lappend signals $id $sps
						
			if {$config(export_signal)} {
				if {$config(export_combine)} {
					set sfn [file join $config(export_dir) \
						"E$info(export_start_s).$ext"]
				} {
					set sfn [file join $config(export_dir) \
						"E$info(export_start_s)\_$id\.$ext"]
				}
				LWDAQ_print $t "Exporting signal of channel\
					$id at $sps SPS to $sfn."
				if {[file exists $sfn]} {
					LWDAQ_print $t \
						"WARNING: Deleting existing [file tail $sfn]."
					file delete $sfn
				}
				if {!$config(export_combine) && ($config(export_format) == "EDF")} {
					LWDAQ_print $t "Creating EDF file [file tail $sfn]."
					EDF_create $sfn $config(play_interval) \
						"$id $sps" $info(export_start_s)
				}
				if {!$config(export_combine) \
					&& ($config(export_format) == "TXT") \
					&& ($config(export_txt_header) != "")} {
					LWDAQ_print $t "Creating TXT file [file tail $sfn]."
					LWDAQ_print $sfn $config(export_txt_header)
				}
			}
			
			if {$config(export_centroid) || $config(export_powers)} {
				if {$config(export_combine)} {
					set tfn [file join $config(export_dir) \
						"T$info(export_start_s).$ext"]
				} {
					set tfn [file join $config(export_dir) \
						"T$info(export_start_s)\_$id\.$ext"]
				}
				LWDAQ_print $t "Exporting tracker data of channel\
					$id at $config(tracker_sample_rate) SPS to $tfn."
				if {[file exists $tfn]} {
					LWDAQ_print $t \
						"WARNING: Deleting existing [file tail $tfn]."
					file delete $tfn
				}
				if {!$config(export_combine) \
					&& ($config(export_format) == "TXT") \
					&& ($config(export_txt_header) != "")} {
					LWDAQ_print $t "Creating TXT file [file tail $tfn]."
					LWDAQ_print $tfn $config(export_txt_header)
				}
			}		
			
			if {$config(export_activity)} {
				if {$config(export_combine)} {
					set afn [file join $config(export_dir) \
						"A$info(export_start_s).$ext"]
				} {
					set afn [file join $config(export_dir) \
						"A$info(export_start_s)\_$id\.$ext"]
				}
				LWDAQ_print $t "Exporting activity of channel\
					$id at $sps SPS to $afn."
				if {[file exists $afn]} {
					LWDAQ_print $t \
						"WARNING: Deleting existing [file tail $afn]."
					file delete $afn
				}
				if {!$config(export_combine) && ($config(export_format) == "EDF")} {
					LWDAQ_print $t "Creating EDF file [file tail $afn]."
					EDF_create $afn $config(play_interval) \
						"[set id]a $config(tracker_sample_rate)" $info(export_start_s)
				}
				if {!$config(export_combine) \
					&& ($config(export_format) == "TXT") \
					&& ($config(export_txt_header) != "")} {
					LWDAQ_print $t "Creating TXT file [file tail $afn]."
					LWDAQ_print $afn $config(export_txt_header)
				}
			}
		}
		
		# If we are exporting to one EDF file, create the header for all signals now.
		if {$config(export_combine) && ($config(export_format) == "EDF")} {
			if {$config(export_signal)} {
				LWDAQ_print $t "Creating EDF file [file tail $sfn]."
				EDF_create $sfn $config(play_interval) $signals $info(export_start_s)
			}
			if {$config(export_activity)} {
				LWDAQ_print $t "Creating EDF file [file tail $afn]."
				set headings ""
				foreach {id sps} $signals {
					append headings "[set id]a $config(tracker_sample_rate) "
				}
				EDF_create $afn $config(play_interval) $headings $info(export_start_s)
			}
		}

		# If we are exporting to one TXT file, create the header for all signals now.
		if {$config(export_combine) \
				&& ($config(export_format) == "TXT") \
				&& ($config(export_txt_header) != "")} {
			if {$config(export_signal)} {
				LWDAQ_print $t "Creating TXT file [file tail $sfn]."
				LWDAQ_print $sfn $config(export_txt_header)
			}
			if {$config(export_activity)} {
				LWDAQ_print $t "Creating TXT file [file tail $afn]."
				LWDAQ_print $afn $config(export_txt_header)
			}
			if {$config(export_centroid) || $config(export_powers)} {
				LWDAQ_print $t "Creating TXT file [file tail $tfn]."
				LWDAQ_print $tfn $config(export_txt_header)
			}
		}
		
		# Enable position calculation if required, and close the tracker window
		# if its open. 
		if {$config(export_activity) \
				|| $config(export_centroid) \
				|| $config(export_powers)} {
			set config(alt_calculate) "1"
			if {[winfo exists $info(tracker_window)]} {
				LWDAQ_print $t "WARNING: Closing the Neurotracker\
					panel to accelerate export."
				destroy $info(tracker_window)
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
			LWDAQ_print $t "Looking for video files\
				in $config(video_dir)."
			set vt $info(export_start_s)
			while {$vt < $info(export_end_s)} {
				set vfi [Neuroplayer_video_action "Seek" $vt 0]
				if {$vfi == ""} {
					LWDAQ_print $t "ERROR: Cannot find video for $vt s,\
						aborting export."
					LWDAQ_post "Neuroexporter_export Stop"
					return "ERROR"
				}
				scan $vfi %s%d%f vfn vsk vlen
				if {$info(export_end_s) - $vt > round($vlen - $vsk)} {
					set vdur [expr round($vlen - $vsk)]
				} {
					set vdur [expr $info(export_end_s) - $vt]
				}
				if {$vdur <= 0} {
					LWDAQ_print $t "ERROR: Internal problem\
						vdur=$vdur vsk=$vsk vlen=$vlen\
						vt=$vt end_s=$info(export_end_s)\
						vf=[file tail $vfn], aborting export."
					LWDAQ_post "Neuroexporter_export Stop"
					return "ERROR"
				}

				if {$vdur < round($vlen)} {
					cd $config(export_dir)
					set nvfn [file join $config(export_dir) V$vt\.mp4]
					if {[file exists $nvfn]} {
						LWDAQ_print $t \
							"Deleting existing [file tail $nvfn]."				
						file delete $nvfn
					}
					if {$vsk > 0} {
						LWDAQ_print $t "Will include final $vdur s of\
							[file tail $vfn] in export video."
					} {
						LWDAQ_print $t "Will include first $vdur s of\
							[file tail $vfn] in export video."
					}
					set pid [exec $info(ffmpeg) -nostdin -loglevel error \
						-ss $vsk -t $vdur -i [file nativename $vfn] \
						[file nativename $nvfn] > export_log.txt &]
					lappend info(export_epl) $pid
					LWDAQ_print $t "Process $pid is copying these\
						$vdur s to [file tail $nvfn] in export directory."
					lappend info(export_vfl) $nvfn
				} {
					LWDAQ_print $t "Will include all\
						[format %.2f $vlen] s of [file tail $vfn] in export video."	
					lappend info(export_vfl) $vfn
				}			
				set vt [expr $vt + $vdur]
				LWDAQ_support
			}
			LWDAQ_print $t "Video file list complete,\
				copying start and end segments in background."
		}
	
		LWDAQ_print $t "Starting export of\
			[expr $config(export_duration)] s from NDF archives."
		if {$config(video_enable)} {
			LWDAQ_print $t "WARNING: Disabling video playback to accelerate export."
			set config(video_enable) 0
		}
		
		set info(export_state) "Play"	
		set config(play_time) $archive_start_time
		Neuroplayer_command "Play"

		return "SUCCESS"
	}

	if {$cmd == "Play"} {	
		# Check the current state of the exporter is "Play", or else we will ignore
		# this request to play and return.
		if {$info(export_state) != "Play"} {return "IGNORE"}
		
		# Check that the export directory exists.
		if {![file exists $config(export_dir)]} {
			LWDAQ_print $t "ERROR: Directory \"$config(export_dir)\" does not exist."
			return "ERROR"
		}
		
		# Continue to export, provided that we are not yet done.
		set interval_start_s [Neuroplayer_clock_convert $info(datetime_play_time)]
		if {$interval_start_s < $info(export_end_s)} {

			# Write the signal to disk. This is the reconstructed signal we
			# receive from a transmitter. Each sample is a sixteen-bit unsigned
			# integer and we save these in a manner suitable for each export
			# format.
			if {$config(export_signal)} {
				if {$config(export_combine)} {
					set sfn [file join $config(export_dir) \
						"E$info(export_start_s).$ext"]
				} {
					set sfn [file join $config(export_dir) \
						"E$info(export_start_s)\_$info(channel_num)\.$ext"]
				}
				if {$config(export_format) == "TXT"} {
					set f [open $sfn a]
					foreach value $info(values) {
						puts $f $value
					}
					close $f
				} elseif {$config(export_format) == "BIN"} {
					set export_bytes ""
					foreach value $info(values) {
					  append export_bytes [binary format S $value]
					}
					set f [open $sfn a]
					fconfigure $f -translation binary
					puts -nonewline $f $export_bytes
					close $f
				} elseif {$config(export_format) == "EDF"} {
					if {!$config(export_combine) || \
							[string match "$info(channel_num):*" \
								[lindex $config(channel_selector) 0]]} {
						EDF_num_records_incr $sfn
					} 
					EDF_append $sfn $info(values)
				}
			}
		
			# Write tracker centroid and powers to disk. The tracker values are
			# stored in each channel's tracker history. The history is a list of
			# tracker measurements, which we call "slices". The list begins with
			# the last slice of the previous interval, so we will ignore that
			# slice in the code below. There follow f_s * T_p slices for the
			# current interval, where f_s is the tracker sample rate and T_p is
			# the playback interval length. Each slice is a list of
			# floating-point numbers. They begin with the unfiltered centroid
			# position x, y, z in whatever units are used to provide the tracker
			# coil coordinates. Then we have the filtered x, y, and z position,
			# and the activity obtained from the filtered position, and finally
			# the power measurements from all the detector coils. These coil
			# powers are all in the range 0 to 255 so we round them in binary
			# export and write them as single bytes. In the code below, we are
			# writing the filtered centroid position to disk. If the
			# filter_divisor in the Tracker Panel is 1, which is the default,
			# the filtered position will be the same as the original position.
			if {$config(export_centroid) || $config(export_powers)} {
				upvar #0 Neuroplayer_info(tracker_$info(channel_num)) history
				if {![info exists history]} {
					LWDAQ_print $t "ERROR: No tracker history to export,\
						make sure alt_calculate is set."
					return "ERROR"
				}
				if {$config(export_combine)} {
					set tfn [file join $config(export_dir) \
						"T$info(export_start_s).$ext"]
				} {
					set tfn [file join $config(export_dir) \
						"T$info(export_start_s)\_$info(channel_num)\.$ext"]
				}
				
				if {$config(export_format) == "TXT"} {
					set export_string ""
					foreach slice [lrange $history 1 end] {
						if {$config(export_centroid)} {
							foreach p [lrange $slice 3 5] {
								append export_string "[format %.1f $p] "
							}
						}
						if {$config(export_powers)} {
							append export_string "[lrange $slice 7 end]"
						}
						set export_string [string trim $export_string]
						append export_string "\n"
					}
					set f [open $tfn a]
					puts $f [string trim $export_string]
					close $f
				} elseif {$config(export_format) == "BIN"} {
					set export_bytes ""
					foreach slice [lrange $history 1 end] {
						if {$config(export_centroid)} {
							foreach v [lrange $slice 3 5] {
								if {![string is double -strict $v]} {set v 0.0}
								append export_bytes \
									[binary format S [expr round($v*10.0)]]
							}
						}
						if {$config(export_powers)} {
							foreach p [lrange $slice 7 end] {
								if {![string is double -strict $v]} {set v 0.0}
								append export_bytes [binary format c [expr round($p)]]
							}
						}
					}
					set f [open $tfn a]
					fconfigure $f -translation binary
					puts -nonewline $f $export_bytes
					close $f
				} elseif {$config(export_format) == "EDF"} {
				# We provide no export for centroid or powers in EDF format. Before
				# we ever get to this point, we should have generated an error.
				}
			}

			# Write activity to disk. We use the same tracker history we
			# describe in the comment above. Its seventh element (number six) is
			# the activity in centimeters per second. For text, we print the 
			# real-valued activity in cm/s. For binary, we multiply by ten then
			# round and write as a two-byte unsigned integer in big-endian format.
			# For EDF, we fit the range min_activity to max_activity into the
			# integer range 0-65535 before passing to our EDF append routine.
			if {$config(export_activity)} {
				upvar #0 Neuroplayer_info(tracker_$info(channel_num)) history
				if {![info exists history]} {
					LWDAQ_print $t "ERROR: No tracker history to export,\
						make sure alt_calculate is set."
					return "ERROR"
				}
				if {$config(export_combine)} {
					set afn [file join $config(export_dir) \
						"A$info(export_start_s).$ext"]
				} {
					set afn [file join $config(export_dir) \
						"A$info(export_start_s)\_$info(channel_num)\.$ext"]
				}
				
				if {$config(export_format) == "TXT"} {
					set export_string ""
					foreach slice [lrange $history 1 end] {
						set v [lindex $slice 6]
						if {![string is double -strict $v]} {
							set v 0.0
						}
						append export_string "[format %.2f $v]\n"
					}
					set f [open $afn a]
					puts $f [string trim $export_string]
					close $f
				} elseif {$config(export_format) == "BIN"} {
					set export_bytes ""
					foreach slice [lrange $history 1 end] {
						set v [lindex $slice 6]
						if {![string is double -strict $v]} {
							set v 0.0
						}
						append export_bytes \
							[binary format S [expr round($v*10.0)]]
					}
					set f [open $afn a]
					fconfigure $f -translation binary
					puts -nonewline $f $export_bytes
					close $f
				} elseif {$config(export_format) == "EDF"} {
					if {!$config(export_combine) || \
							[string match "$info(channel_num):*" \
								[lindex $config(channel_selector) 0]]} {
						EDF_num_records_incr $afn
					} 
					set values [list]
					set test [list]
					foreach slice [lrange $history 1 end] {
						set v [lindex $slice 6]
						lappend test $v
						if {![string is double -strict $v]} {
							set vv 0
						} {
							if {$v * 10.0 < $config(export_activity_max)} {
								set vv [expr round( $v * 10.0 * 65535 \
									/ $config(export_activity_max))]
							} {
								set vv 65535
							}
						}
						lappend values $vv
					}
					EDF_append $afn $values
				}
			}
		}

		# We are done if the end of this interval exceeds our export end time, and we 
		# have exported all channels already. 
		if {[string match "$info(channel_num):*" [lindex $config(channel_selector) end]] \
				&& ($interval_start_s + $info(play_interval_copy) \
					>= $info(export_end_s))} {
			LWDAQ_print $t "Export of [expr $config(export_duration)] s\
				of recorded signal complete."
			set info(play_control) "Stop"

			# If there are no video files to deal with, stop.
			if {[llength $info(export_vfl)] == 0} {
				LWDAQ_print $t "Export complete in\
					[expr [clock seconds] - $info(export_run_start)] s.\n" purple
				set info(export_state) "Wait"
				LWDAQ_post "Neuroexporter_export Repeat" 
			} {
				set info(export_state) "Wait"
				LWDAQ_post "Neuroexporter_export Video"
				LWDAQ_print $t "Waiting for video extractions to complete."
			}
		}
				
		return "SUCCESS"
	}
	
	if {$cmd == "Video"} {
		# Check to see if video processes are still running, and if they are, keep
		# waiting until they do complete.
		if {$info(export_state) == "Wait"} {
			foreach pid $info(export_epl) {
				if {[LWDAQ_process_exists $pid]} {
					LWDAQ_post "Neuroexporter_export Video"
					return "SUCCESS"
				}
			}
			
			LWDAQ_print $t "Video extractions complete."

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
			LWDAQ_print $t "Process $info(export_epl) performing\
				video concatination into temporary file."
			LWDAQ_post "Neuroexporter_export Video"
			return "SUCCESS"
		}

		# If we are concatinating, we are waiting for the concatination to complete.
		if {$info(export_state) == "Concat"} {
			if {[LWDAQ_process_exists $info(export_epl)]} {
				LWDAQ_post "Neuroexporter_export Video"
				return "SUCCESS"
			}
			set efn [lindex $info(export_vfl) 0]
			set tempfile [file join $config(export_dir) temp.mp4]
			catch {file delete $efn}
			catch {file delete [lindex $info(export_vfl) end]}
			file rename $tempfile $efn
			LWDAQ_print $t "Concatination of [llength $info(export_vfl)]\
				video files into [file tail $efn] complete."

			cd $config(export_dir)
			catch {file delete concat_list.txt}
			if {[file exists concat_log.txt]} {
				set clf [open concat_log.txt r]
				set log [string trim [read $clf]]
				close $clf
				file delete concat_log.txt
				if {$log != ""} {
					LWDAQ_print $t "Concatination Log:\n$log"
				}
			}
			if {[file exists export_log.txt]} {
				set elf [open export_log.txt r]
				set log [string trim [read $clf]]
				close $elf
				file delete export_log.txt
				if {$log != ""} {
					LWDAQ_print $t "Export Log:\n$log"
				}
			}

			LWDAQ_print $t "Export complete in\
				[expr [clock seconds] - $info(export_run_start)] s.\n" purple
			set info(export_state) "Wait"
			LWDAQ_post "Neuroexporter_export Repeat" 
			return "SUCCESS"
		}
	}

	# At the end of an export, we check to see if we should repeat the export strating
	# from the point immediately after the end of the previous export.
	if {$cmd == "Repeat"} {
		if {$info(export_state) != "Wait"} {
			return "ERROR"
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
			LWDAQ_print $t "\nPreparing another export..." purple
			set config(export_start) \
				[Neuroplayer_clock_convert \
				[expr [Neuroplayer_clock_convert $info(datetime_start_time)] \
				+ round($info(t_min)) ]]
			set info(export_state) "Idle"
			LWDAQ_post Neuroexporter_export
			return "SUCCESS"	
		} {
			set info(export_state) "Idle"
			return "SUCCESS"
		}		
	}

	return "ERROR"
}

#
# Neuroplayer_clock_update always updates the playback datetime, and if necessary 
# updates the archive start datetime.
#
proc Neuroplayer_clock_update {} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config

	set pfn [file tail $config(play_file)]
	if {$pfn != $info(datetime_archive_name)} {
		set info(datetime_archive_name) $pfn
		if {![regexp {([0-9]{10})\.ndf} $pfn match atime]} {
			set atime 0
		}
		set info(datetime_start_time) [Neuroplayer_clock_convert $atime]
	}
	set info(datetime_play_time) [Neuroplayer_clock_convert \
		[expr [Neuroplayer_clock_convert $info(datetime_start_time)] \
			+ round($config(play_time)) ] ]
}

#
# Neuroplayer_clock_jump constructs a datetime event string and instructs 
# the Neuroplayer to jump to an archive containing the datetime specified by the 
# user in the datetime window. If such an archive does not exist, the jump routine 
# will issue an error.
#
proc Neuroplayer_clock_jump {} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config

	set jump_time [Neuroplayer_clock_convert $config(datetime_jump_to)]
	if {$jump_time > 0} {
		set config(datetime_jump_to) [Neuroplayer_clock_convert $jump_time]
		Neuroplayer_jump "$jump_time 0.0 ? \"$config(datetime_jump_to)\"" 0
	}
}

#
# We convert between integer seconds to the datetime format given in the 
# configuration array. If the input is in integer seconds, it gets converted
# into our datetime format. Otherwise, we convert it from datetime format
# into integer seconds if possible. We issue an error in the Neuroplayer
# window if the format is incorrect, and return the value zero.
#
proc Neuroplayer_clock_convert {datetime} {
	upvar #0 Neuroplayer_config config
	
	if {[string is integer $datetime]} {
		set newformat [clock format $datetime -format $config(datetime_format)]
	} {
		if {[catch {
			set newformat [clock scan $datetime -format $config(datetime_format)]
		} error_result]} {
			Neuroplayer_print "ERROR: Invalid clock string, \"$datetime\"."
			set newformat 0
		}
	}
	return $newformat
}

#
# Neuroplayer_calibration allows us to view and edit the global baseline
# power values used by some processors to produce interval characteristics
# that are independent of the sensitivity of the sensor. The processor can
# use these global variables to keep track of a "baseline" power value by
# which other power measurements may be divided to obtain a normalised
# power measurement. We can save the baseline power values to the metadata
# of an NDF file, or load them from the metadata.
#
proc Neuroplayer_calibration {{name ""}} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info

	set w $info(window)\.baselines
	if {[winfo exists $w]} {
		raise $w
		return "ABORT"
	}
	toplevel $w
	wm title $w "Calibration Panel V$info(version)"
	scan [wm maxsize .] %d%d x y
	wm maxsize $w [expr $x*4] [expr $y*1]

	set f [frame $w.controls]
	pack $f -side left -fill both

	button $f.refresh -text "Update Panel" -command {
		destroy $Neuroplayer_info(window)\.baselines
		LWDAQ_post Neuroplayer_calibration
	}
	pack $f.refresh -side top
	button $f.rstclr -text "Reset Colors" -command {
		set Neuroplayer_config(color_table) {0 0}
		destroy $Neuroplayer_info(window)\.baselines
		LWDAQ_post Neuroplayer_calibration
	}
	pack $f.rstclr -side top

	label $f.lsel -text "Include String:" -fg blue
	entry $f.einc -textvariable Neuroplayer_config(calibration_include) -width 35
	pack $f.lsel $f.einc -side top
	
	label $f.bpl -text "Baseline Power Control:" -fg blue
	pack $f.bpl -side top 

	set f [frame $w.controls.f1  -border 4]
	pack $f -side top -fill both

	button $f.nb -text "Set Baselines To:" -command {Neuroplayer_baselines_set}
	entry $f.bset -textvariable Neuroplayer_config(bp_set)
	grid $f.nb $f.bset -sticky news

	set f [frame $w.controls.f2 -border 4]
	pack $f -side top -fill both

	button $f.reset -text "Reset Baselines" -command {Neuroplayer_baseline_reset}
	pack $f.reset -side top
	button $f.read -text "Read Baselines from Metadata" \
		-command {Neuroplayer_baselines_read $Neuroplayer_config(bp_name)}
	pack $f.read -side top
	button $f.save -text "Write Baselines to Metadata" \
		-command {Neuroplayer_baselines_write $Neuroplayer_config(bp_name)}
	pack $f.save -side top

	set f [frame $w.controls.f3 -border 4]
	pack $f -side top -fill both

	label $f.lname -text "Name for Metadata Reads and Writes:" -fg blue
	pack $f.lname -side top
	entry $f.name -textvariable Neuroplayer_config(bp_name)
	pack $f.name -side top	
	
	set f [frame $w.controls.f4 -border 4]
	pack $f -side top -fill both
	
	label $f.lplayback -text "Playback Strategy:" -fg blue
	pack $f.lplayback -side top
	checkbutton $f.autoreset -variable Neuroplayer_config(bp_autoreset) \
		-text "Reset Baselines on Playback Start"
	pack $f.autoreset -side top
	checkbutton $f.autoread -variable Neuroplayer_config(bp_autoread) \
		-text "Read Baselines from Metadata on Playback Start"
	pack $f.autoread -side top
	checkbutton $f.autowrite -variable Neuroplayer_config(bp_autowrite) \
		-text "Write Baselines to Metadata on Playback Finish"
	pack $f.autowrite -side top

	set f [frame $w.controls.f5 -border 4]
	pack $f -side top -fill both
	
	label $f.ljump -text "Jumping Strategy:" -fg blue
	pack $f.ljump -side top
	radiobutton $f.jumpread -variable Neuroplayer_config(jump_strategy) \
		-text "Read Baselines from Metadata" -value "read"
	radiobutton $f.jumplocal -variable Neuroplayer_config(jump_strategy) \
		-text "Use Current Baseline Power" -value "local"
	radiobutton $f.jumpevent -variable Neuroplayer_config(jump_strategy) \
		-text "Use Baseline Power in Event Description" -value "event"
	pack $f.jumpread $f.jumplocal $f.jumpevent -side top

	# Get a list of the channels we are supposed to display in the calibration
	# window, and the codes for including channels based upon their alert
	# values.
	set inclist ""
	foreach inc_code $config(calibration_include)	{
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
	# number in the color it will be plotted in the Neuroplayer and Neurotracker.
	set count 0
	for {set id $info(min_id)} {$id <= $info(max_id)} {incr id} {
		if {$id % $info(set_size) == $info(set_size) - 1} {continue}
		if {$id % $info(set_size) == 0} {continue}

		if {$count % $config(activity_rows) == 0} {
			set f [frame $w.calib$count -relief groove -border 4]
			pack $f -side left -fill y -expand 1
			label $f.id -text "ID" -fg purple
			label $f.color -text "  " -fg purple
			label $f.baseline -text "BP" -fg purple
			grid $f.id $f.color $f.baseline -sticky ew
			incr count
		} 

		if {([set info(status_$id)] != "None") && ([set info(qty_$id)] == 0)} {
			set info(status_$id) "Off"
		}
		
		if {([lsearch $inclist "All"] >= 0) \
				|| ([lsearch $inclist [set info(status_$id)] ] >= 0) \
				|| ([lsearch $inclist $id] >= 0)} {
			set color [lwdaq tkcolor [Neuroplayer_color $id]]
			label $f.l$id -text $id -anchor w
			label $f.c$id -text "   " -bg $color
			bind $f.c$id <ButtonPress> \
				[list Neuroplayer_color_swap $id $f.c$id Press %x %y]
			entry $f.e$id -textvariable Neuroplayer_info(bp_$id) \
				-relief sunken -bd 1 -width 7
			grid $f.l$id $f.c$id $f.e$id -sticky ew
			incr count
		}	
	}
}

#
# Neuroplayer_baseline_reset sets all the baseline power values to the
# reset value, which is supposed to be so high that no channel will have a
# baseline power exceeding it.
#
proc Neuroplayer_baseline_reset {} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info	

	for {set i $info(min_id)} {$i <= $info(max_id)} {incr i} {
		set info(bp_$i) $info(bp_reset)
	}
}

#
# Neuroplayer_baselines_set sets all the baseline power values to the bp_set
# value.
#
proc Neuroplayer_baselines_set {} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info	

	for {set i $info(min_id)} {$i <= $info(max_id)} {incr i} {
		set info(bp_$i) $config(bp_set)
	}
}

#
# Neuroplayer_baselines_write takes the existing baseline power values and
# saves them as baseline power string in the metadata of the current playback
# file, with the name specified in the config(bp_name) parameter. The routine
# does not write baseline powers that meet or exceed the reset value, because
# these are not valid.
#
proc Neuroplayer_baselines_write {name} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info	

	if {[regexp {[^a-zA-Z0-9_\-\.]} $name]} {
		Neuroplayer_print "ERROR: Name \"$name\" invalid contains illegal characters."
		return "FAIL"
	}

	if {[catch {set metadata [LWDAQ_ndf_string_read $config(play_file)]} error_string]} {
		Neuroplayer_print "ERROR: $error_string"
		return "FAIL"
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
		if {$info(status_$id) != "None"} {
			append metadata "$id $info(bp_$id)\n"
		}
	}
	
	append metadata "</baseline>\n"
	
	LWDAQ_ndf_string_write $config(play_file) [string trim $metadata]\n

	Neuroplayer_print "Wrote baselines \"$name\" to\
		[file tail $config(play_file)]." verbose

	return "SUCCESS"
}

#
# Neuroplayer_baselines_read looks at the metadata of the current playback
# archive and looks for a baseline power string with the name given by the
# config(bp_name) string. It reads any such baseline powers it finds into
# the baseline power array.
#
proc Neuroplayer_baselines_read {name} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info

	if {[regexp {[^a-zA-Z0-9_\-\.]} $name]} {
		Neuroplayer_print "ERROR: Baseline name \"$name\" contains illegal characters."
		return "FAIL"
	}

	if {[catch {set metadata [LWDAQ_ndf_string_read $config(play_file)]} error_string]} {
		Neuroplayer_print "ERROR: $error_string"
		return "FAIL"
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
		Neuroplayer_print "ERROR: No baselines \"$name\" in\
			[file tail $config(play_file)]."
		return "FAIL"
	}
	Neuroplayer_print "Read baselines \"$name\" from [file tail\
		$config(play_file)]." verbose
	return "SUCCESS"
}

# The activity displays the frequencies used for reconstruction, which may have
# been specified by the user, or may have been picked from a list of possible
# frequencies in the default frequency parameter. 
proc Neuroplayer_activity {} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info	

	set w $info(window)\.activity
	if {[winfo exists $w]} {
		raise $w
		return "ABORT"
	}
	toplevel $w
	scan [wm maxsize .] %d%d x y
	wm maxsize $w [expr $x*4] [expr $y*1]
	wm title $w "Activity Panel V$info(version)"
	
	# Make a frame for controls.
	set ff [frame $w.controls]
	pack $ff -side top -fill x -expand 1
	
	# Controls.
	label $ff.include -text "Include Channels:" -fg blue
	pack $ff.include -side left -expand yes
	entry $ff.string -textvariable Neuroplayer_config(activity_include) -width 35
	pack $ff.string -side left -expand yes
	
	# Make another frame for controls.
	set ff [frame $w.controls2]
	pack $ff -side top -fill x -expand 1
	
	button $ff.update -text "Update Panel" -command {
		destroy $Neuroplayer_info(window)\.activity
		LWDAQ_post Neuroplayer_activity
	}
	pack $ff.update -side left -expand yes
	button $ff.reset -text "Reset States" -command {
		for {set id $Neuroplayer_info(min_id)} \
			{$id < $Neuroplayer_info(max_id)} \
			{incr id} {
			set Neuroplayer_info(status_$id) "None"
		}
	}
	pack $ff.reset -side left -expand yes
	button $ff.rstclr -text "Reset Colors" -command {
		set Neuroplayer_config(color_table) {0 0}
		destroy $Neuroplayer_info(window)\.activity
		LWDAQ_post Neuroplayer_activity
	}
	pack $ff.rstclr -side left -expand yes


	# Make large frame for the activity columns.
	set ff [frame $w.activity]
	pack $ff -side top -fill x -expand 1

	# Get a list of the channels we are supposed to display in the activity
	# window, and the codes for including channels based upon their alert
	# values.
	set inclist ""
	foreach inc_code $config(activity_include)	{
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
	# number in the color it will be plotted in the Neuroplayer and Neurotracker.
	set count 0
	set info(activity_selected) [list]
	for {set id $info(min_id)} {$id <= $info(max_id)} {incr id} {
		if {$id % $info(set_size) == $info(set_size) - 1} {continue}
		if {$id % $info(set_size) == 0} {continue}
		
		if {$count % $config(activity_rows) == 0} {
			set f [frame $ff.column_$count -relief groove -border 4]
			pack $f -side left -fill y -expand 1
			label $f.id -text "ID" -fg purple
			label $f.cc -text "   " -fg purple
			label $f.csps -text "Qty" -fg purple
			label $f.msps -text "SPS" -fg purple
			label $f.alert -text "State" -fg purple
			grid $f.id $f.cc $f.csps $f.msps $f.alert -sticky ew
			incr count
		}

		if {([set info(status_$id)] != "None") && ([set info(qty_$id)] == 0)} {
			set info(status_$id) "Off"
		}
		
		if {([lsearch $inclist "All"] >= 0) \
				|| ([lsearch $inclist [set info(status_$id)]] >= 0) \
				|| ([lsearch $inclist $id] >= 0)} {
			label $f.id_$count -text $id -anchor w
			set color [lwdaq tkcolor [Neuroplayer_color $id]]
			label $f.cc_$count -text " " -bg $color
			bind $f.cc_$count <ButtonPress> \
				[list Neuroplayer_color_swap $id $f.cc_$count Press %x %y]
			label $f.csps_$count -textvariable Neuroplayer_info(qty_$id) -width 4
			label $f.msps_$count -textvariable Neuroplayer_info(sps_$id) -width 4
			label $f.status_$count -textvariable Neuroplayer_info(status_$id) -width 6
			grid $f.id_$count $f.cc_$count $f.csps_$count \
				$f.msps_$count $f.status_$count -sticky ew
			lappend info(activity_selected) $id
			incr count
		}
	}
}

#
# Neuroplayer_color_swap uses mouse events to switch the display colors.
#
proc Neuroplayer_color_swap {id w e x y} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info	
	
	if {$e == "Press"} {
		if {[LWDAQ_inside_widget $w $x $y]} {
			set index [lsearch -index 0 $config(color_table) $id]
			if {$index >= 0} {
				set code [lindex $config(color_table) $index 1]
				set code [expr $code + 1]
				lset config(color_table) $index 1 $code
			} {
				set code [expr $id + 31]
				lappend config(color_table) "$id $code"
			}
			set color [lwdaq tkcolor [Neuroplayer_color $code]]
		} {
			set color [lwdaq tkcolor [Neuroplayer_color $id]]
		}
	} {
		set color "white"
	}
	$w configure -bg $color
}

#
# Neuroplayer_frequency_reset sets all the frequency and frequency alerts to
# zero and N.
#
proc Neuroplayer_frequency_reset {} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info	

	for {set i $info(min_id)} {$i <= $info(max_id)} {incr i} {
		set info(csps_$i) 0
		set info(qsps_$i) "*"
		set info(msps_$i) "0"
		set info(status_$i) "None"
	}
}

#
# Neuroplayer_fresh_graphs clears the graph images in memory. If you pass it a
# "1" as a parameter, it will clear the graphs from the screen as well. It calls
# lwdaq_graph to create an empty graph in the overlay area of the graph images,
# and lwdaq_draw to draw the empty graph on the screen.
#
proc Neuroplayer_fresh_graphs {{clear_screen 0}} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	global LWDAQ_Info	

	if {![winfo exists $info(window)]} {return "ABORT"}
	
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
		Neuroplayer_draw_graphs
	}
	
	set info(signal) "0 0"
	set info(values) "0"
	set info(spectrum) "0 0"
	
	LWDAQ_support
	return "SUCCESS"
}

#
# Neuroplayer_draw_graphs draws the vt and af graphs in the two view windows
# in the Neuroplayer, and in the separate view windows, if they exist.
#
proc Neuroplayer_draw_graphs {} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	global LWDAQ_Info	

	if {!$info(gui)} {return "ABORT"}

	lwdaq_draw $info(vt_image) $info(vt_photo)
	if {[winfo exists $info(vt_view)]} {
		lwdaq_draw $info(vt_image) $info(vt_view_photo) -zoom $config(vt_view_zoom)
	}
	lwdaq_draw $info(af_image) $info(af_photo)
	if {[winfo exists $info(af_view)]} {
		lwdaq_draw $info(af_image) $info(af_view_photo) -zoom $config(af_view_zoom)
	}
	
	return "SUCCESS"
}

#
# Neuroplayer_magnified_view opens a new window with a larger, or at lease
# separate, plot of the voltage-time or amplitude-frequency graph. The size of
# the window is set by the vt_view_zoom and af_view_zoom parameters.
#
proc Neuroplayer_magnified_view {figure} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config

	if {$figure == "vt"} {
		set w $info(vt_view)
		if {[winfo exists $w]} {
			raise $w
			return "ABORT"
		}
		toplevel $w
		wm title $w "Voltage vs. Time Magnified View, Neuroplayer $info(version)"
   		set info(vt_view_photo) [image create photo "_Neuroplayer_vt_view_photo_"]
   		set l $w.plot
   		label $l -image $info(vt_view_photo)
		pack $l -side top
	}
	if {$figure == "af"} {
		set w $info(af_view)
		if {[winfo exists $w]} {
			raise $w
			return "ABORT"
		}
		toplevel $w
		wm title $w "Amplitude vs. Frequency Magnified View, Neuroplayer $info(version)"
   		set info(af_view_photo) [image create photo "_Neuroplayer_af_view_photo_"]
   		set l $w\.plot
   		label $l -image $info(af_view_photo)
		pack $l -side top
	}
	
	set f [frame $w.controls] 
	label $f.b -textvariable Neuroplayer_info(play_file_tail) \
		-width 20 -bg $info(variable_bg)
	pack $f.b -side left -expand yes
	button $f.pick -text "Pick" -command "Neuroplayer_command Pick"
	pack $f.pick -side left -expand yes
	if {$figure == "vt"} {
		foreach a "SP CP NP" {
			set b [string tolower $a]
			radiobutton $f.$b -variable Neuroplayer_config(vt_mode) \
				-text $a -value $a
			pack $f.$b -side left -expand yes
		}	
		label $f.lv_range -text "v_range:" -fg $info(label_color)
		entry $f.ev_range -textvariable Neuroplayer_config(v_range) -width 5
		pack $f.lv_range $f.ev_range -side left -expand yes
	}
	pack $f -side top
	foreach a {Play Step Stop Repeat Back} {
		set b [string tolower $a]
		button $f.$b -text $a -command "Neuroplayer_command $a"
		pack $f.$b -side left -expand yes
	}	
	button $f.metadata -text "Metadata" -command {
		LWDAQ_post [list Neuroplayer_metadata_view play]
	}
	pack $f.metadata -side left -expand yes
	button $f.overview -text "Overview" -command {
		LWDAQ_post [list LWDAQ_post "Neuroplayer_overview"]
	}
	pack $f.overview -side left -expand yes
	
	LWDAQ_bind_command_key $w Left {Neuroplayer_command Back}
	LWDAQ_bind_command_key $w Right {Neuroplayer_command Step}
	LWDAQ_bind_command_key $w greater {Neuroplayer_command Play}
	LWDAQ_bind_command_key $w Up [list LWDAQ_post {Neuroplayer_jump Next_NDF 0}]
	LWDAQ_bind_command_key $w Down [list LWDAQ_post {Neuroplayer_jump Previous_NDF 0}]
	LWDAQ_bind_command_key $w less [list LWDAQ_post {Neuroplayer_jump Current_NDF 0}]

	Neuroplayer_draw_graphs
	
	return $figure
}


#
# Neuroplayer_plot_signal plots the a signal on the screen. It uses lwdaq_graph
# to plot data in the vt_image overlay. The procedure does not draw the graph on
# the screen. We leave the drawing until all the signals have been plotted in
# the vt_image overlay by successive calls to this procedure. For more
# information about lwdaw_graph, see the LWDAQ Command Reference. If we don't
# pass a signal to the routine, it uses $info(signal). The signal string must be
# a list of time and sample values "t v ". If we don't specify a color, the
# routine uses the info(channel_num) as the color code. If we don't specify a
# signal, the routine uses the $info(signal).
#
proc Neuroplayer_plot_signal {{color ""} {signal ""}} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	upvar result result
	global LWDAQ_Info	

	# Abort if running in no-gui mode.
	if {!$info(gui)} {return "ABORT"}
	
	# Select colors and signal.
	if {$color == ""} {set color [Neuroplayer_color $info(channel_num)]}
	if {$signal == ""} {set signal $info(signal)}
	
	# Check the range and offset parameters for errors.
	foreach a {v_range v_offset} {
		if {![string is double -strict $config($a)]} {
			set result "ERROR: Invalid value, \"$config($a)\" for $a."
			return "FAIL"
		}
	}
	
	# Check color for errors.
	if {[llength $color] > 1} {
		set result "ERROR: Invalid color, \"$color\"."
		return "FAIL"
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
	if {[lwdaq_error_string] != ""} {Neuroplayer_print [lwdaq_error_string]}

	LWDAQ_support
	return "SUCCESS"
}

#
# Neuroplayer_plot_values takes a list of values and plots them in the value
# versus time display as if they were evenly-spaced samples. The routine is
# identical to Neuroplayer_plot_signal except that we don't have to pass it a
# string of x-y values, only the y-values. We pass the routine a color and a
# string of values. If the values are omitted, the routine uses the current
# string of values in info(values).
#
proc Neuroplayer_plot_values {{color ""} {values ""}} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	upvar result result
	global LWDAQ_Info

	# Abort if running in no-gui mode.
	if {!$info(gui)} {return "ABORT"}
	
	# Select values.
	if {$values == ""} {set values $info(values)}
	
	# Construct a signal for Neuroplayer_plot_signal.
	set timestamp 0
	set signal ""
	foreach v $values {
		append signal "$timestamp $v "
		incr timestamp
	}
	
	# Call the plot routine.
	Neuroplayer_plot_signal $color $signal
	
	return "SUCCESS"
}



#
# Neuroplayer_plot_spectrum plots a spectrum in the af_image overlay, but does
# not display the plot on the screen. The actual display will take place later,
# for all channels at once, to save time. If you don't pass a spectrum to the
# routine, it will plot $info(spectrum). Each spectrum point must be in the
# format "f a ", where f is frequency in Hertz and a is amplitude in ADC counts.
# If we don't specify a color for the plot, the routine uses the channel number.
# If we don't specify a spectrum, it uses $info(spectrum).
#
proc Neuroplayer_plot_spectrum {{color ""} {spectrum ""}} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	upvar result result
	global LWDAQ_Info	

	# Abort if running in no-gui mode.
	if {!$info(gui)} {return "ABORT"}
	
	# Select color and spectrum values.
	if {$color == ""} {set color [Neuroplayer_color $info(channel_num)]}
	if {$spectrum == ""} {set spectrum $info(spectrum)}

	# Check the range paramters for errors.
	foreach a {a_min a_max f_min f_max} {
		if {![string is double -strict $config($a)]} {
			set result "ERROR: Invalid value, \"$config($a)\" for $a."
			return "FAIL"
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
	if {[lwdaq_error_string] != ""} {Neuroplayer_print [lwdaq_error_string]}

	LWDAQ_support
	return "SUCCESS"
}

#
# Neuroplayer_play manages the play-back and processing of signals from
# archive files. We start by checking the block of messages in the buffer_image.
# We read messages out of the play-back archive until it has enough clock
# messages to span play_interval seconds. Sometimes, the block of messages we
# read will be many times larger than necessary. We extract from the
# buffer_image exactly the correct number of messages to span the play_interval
# and put these in the data_image. We go through the channels string and make a
# list of channels we want to process. For each of these channels, in the order
# they appear in the channels string, we apply extraction, reconstruction,
# transformation, and processing to the data image. If requested by the user, we
# read a processor_file off disk and apply it in turn to the signal and spectrum
# we obtained for each channel. We store the results of processing to disk in a
# text file and print them to the text window also. If we don't specify a
# command, the Neuroplayer continues with the action indicated by its control
# variable. But we can specify any of the following commands: Play, Step,
# Repeat, Back, Pick, PickDir, First, Last, and Reload.
#
proc Neuroplayer_play {{command ""}} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config
	upvar #0 LWDAQ_config_Receiver iconfig
	upvar #0 LWDAQ_info_Receiver iinfo
	global LWDAQ_Info

	# Make sure we have the info array.
	if {![array exists info]} {return "ABORT"}

	# Check if we have an overriding command.
	if {$command != ""} {set info(play_control) $command}

	# Consider various ways in which we will do nothing and return.
	if {$LWDAQ_Info(reset)} {
		set info(play_control) "Idle"
		return "SUCCESS"
	}
	if {$info(gui) && ![winfo exists $info(window)]} {
		array unset info
		array unset config
		return "ABORT"
	}
	if {$info(play_control) == "Stop"} {
		LWDAQ_set_bg $info(play_control_label) white
		set info(play_control) "Idle"
		return "SUCCESS"
	}
	if {$config(video_enable) && ($config(play_interval) < $info(video_min_interval))} {
		Neuroplayer_print "ERROR: Playback interval must be a multiple\
			of $info(video_min_interval) when video is enabled."
		LWDAQ_set_bg $info(play_control_label) white
		set info(play_control) "Idle"
		return "SUCCESS"
	}

	# Check to see if there are any videos playing. We must wait for them
	# to finish before we continue with playback of the archive.	
	if {$info(video_state) == "Play"} {
		LWDAQ_post Neuroplayer_play
		return "SUCCESS"
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
	}
	
	# Format the play time variable and save the play interval.
	set config(play_time) [Neuroplayer_play_time_format $config(play_time)]
	set info(play_interval_copy) $config(play_interval)
	
	# If Pick, we choose an archive for playback.
	if {$info(play_control) == "Pick"} {
		Neuroplayer_pick play_file
		set config(play_time) 0.0
		set info(saved_play_time) $config(play_time)
		Neuroplayer_fresh_graphs 1
		if {![string match $config(play_dir)* $config(play_file)]} {
			Neuroplayer_print "WARNING: Directory tree changed\
				to include new play file."
			set config(play_dir) [file dirname $config(play_file)]
		}
	}

	# If PickDir we choose a directory in which to find archives for
	# playback.
	if {$info(play_control) == "PickDir"} {
		Neuroplayer_pick play_dir
		Neuroplayer_fresh_graphs 1
		set info(play_control) "First"
	}
	
	# If Reload, we clear the saved play file name and change the play control to 
	# Repeat. We update the clock times and set the export start time to the start
	# time of the current archive.
	if {$info(play_control) == "Reload"} {
		set info(saved_play_file) "none"
		set config(play_time) 0.0
		set info(saved_play_time) 0.0
		Neuroplayer_fresh_graphs 1
		set info(play_control) "Repeat"
	}

	# If First or Last we find the first or last file in the playback directory tree.
	# We update the exporter start time.
	if {($info(play_control) == "First") \
		|| ($info(play_control) == "Last")} {
		set play_list [LWDAQ_find_files $config(play_dir) *.ndf]
		set play_list [LWDAQ_sort_files $play_list]
		if {[llength $play_list] < 1} {
			Neuroplayer_print "ERROR: There are no NDF files in the\
				playback directory tree."
			LWDAQ_set_bg $info(play_control_label) white
			set info(play_control) "Idle"
			return "FAIL"
		}
		if {$info(play_control) == "First"} {
			set config(play_file) [lindex $play_list 0]
		} {
			set config(play_file) [lindex $play_list end]
		}
		set config(play_time) 0.0
		Neuroplayer_fresh_graphs 1
	}
	
	# Check that the play file exists.
	if {![file exists $config(play_file)]} {
		Neuroplayer_print "ERROR: Cannot find play file \"$config(play_file)\"."
		LWDAQ_set_bg $info(play_control_label) white
		set info(play_control) "Idle"
		return "FAIL"
	}

	# If we have changed files, check the new file is NDF.
	if {$config(play_file) != $info(saved_play_file)} {
		if {[catch {LWDAQ_ndf_data_check $config(play_file)} error_message]} {
			Neuroplayer_print "ERROR: Checking archive, $error_message."
			LWDAQ_set_bg $info(play_control_label) white
			set info(play_control) "Idle"
			return "FAIL"
		}	
	}
	
	# If we have changed files, get the new end time for this file, set the
	# play time to the start of the file, read the payload length from the
	# new file metadata, read tracker coordinates and background powers if
	# they exist, and update the clock.
	if {$config(play_file) != $info(saved_play_file)} {
		set config(play_index) 0
		set info(play_file_tail) [file tail $config(play_file)]
		set info(saved_play_file_mtime) [file mtime $config(play_file)]
		set info(saved_play_file) $config(play_file)
		
		if {[catch {
			set metadata [LWDAQ_ndf_string_read $config(play_file)]
		} error_message]} {
			Neuroplayer_print "ERROR: $error_message."
			LWDAQ_set_bg $info(play_control_label) white
			set info(play_control) "Idle"
			return "FAIL"			
		}
		set payload [LWDAQ_xml_get_list $metadata "payload"]
		if {[string is integer -strict $payload]} {
			set info(player_payload) $payload
		} {
			set info(player_payload) 0
		}
		set coordinates [LWDAQ_xml_get_list $metadata "coordinates"]
		if {[llength $coordinates] >= 1} {
			set config(tracker_coordinates) ""
			foreach {x y} [lindex $coordinates end] {
				lappend config(tracker_coordinates) $x $y "2"
			}
		} {
			set config(tracker_coordinates) ""
		}
		set alt [LWDAQ_xml_get_list $metadata "alt"]
		if {[llength $alt] >= 1} {
			set config(tracker_coordinates) [lindex $alt end]
		}
		set alt_bg [LWDAQ_xml_get_list $metadata "alt_bg"]
		if {[llength $alt_bg] >= 1} {
			set config(tracker_background) [lindex $alt_bg end]
		} {
			set config(tracker_background) ""
			foreach {x y z} $config(tracker_coordinates) {
				lappend config(tracker_background) "0"
			}
		}
		set info(play_end_time) \
			[Neuroplayer_end_time $config(play_file) $info(player_payload)]
		set info(play_previous_clock) -1
		if {$config(play_time) < 0.0} {
			set config(play_time) 0.0
		}
		if {($config(play_time) \
			> [expr $info(play_end_time) - $info(play_interval_copy)])} {
			set config(play_time) [Neuroplayer_play_time_format \
				[expr $info(play_end_time) - \
				$info(play_interval_copy) - \
				fmod($info(play_end_time),$info(play_interval_copy))] ]
		}
		if {$config(play_time) < 0} {
			set config(play_time) 0.0
		}
		set info(saved_play_time) 0.0
		Neuroplayer_clock_update
		lwdaq_data_manipulate $info(buffer_image) clear
		set info(buffer_size) 0
		set info(standing_values) ""
	}

	# We update the player's file end-time when the play file has been
	# modified. But we pass the end-time routine the current play time
	# and play index as a starting point, so the routine will not have
	# to start from the beginning of a file that is being recorded to
	# disk while we play it back.
	if {$info(saved_play_file_mtime) != [file mtime $config(play_file)]} {
		set info(saved_play_file_mtime) [file mtime $config(play_file)]
		set info(play_end_time) \
			[Neuroplayer_end_time $config(play_file) $info(player_payload)]
	}

	# If Pick or First we are done.
	if {($info(play_control) == "Pick") || ($info(play_control) == "First")} {
		LWDAQ_set_bg $info(play_control_label) white
		set info(play_control) "Idle"
		return "SUCCESS"
	}
	
	# If Back, we are going to jump to the start of the previous interval, even
	# if that interval is in an earlier file.
	if {$info(play_control) == "Back"} {
		# Set the play time back by two intervals.
		set config(play_time) [Neuroplayer_play_time_format \
			[expr $config(play_time) - 2.0 * $info(play_interval_copy)]]

		# If we are going back before the start of this archive, we try to find
		# an previous archive. We get a list of all NDF files in the play_dir
		# directory tree.
		if {$config(play_time) < 0.0} {
			set fl [LWDAQ_find_files $config(play_dir) *.ndf]
			set fl [LWDAQ_sort_files $fl]
			set i [lsearch $fl $config(play_file)]
			if {$i < 0} {
				Neuroplayer_print "ERROR: Cannot move to previous file,\
					\"$info(play_file_tail)\" not in playback directory tree."
				LWDAQ_set_bg $info(play_control_label) white
				set info(play_control) "Idle"
				return "FAIL"
			}
			set file_name [lindex $fl [expr $i - 1]]
			if {$file_name != ""} {
				Neuroplayer_print "Playback switching to previous file \"$file_name\"."
				set config(play_file) $file_name
				set info(play_file_tail) [file tail $file_name]
				set config(play_time) $info(max_play_time)
			} {
				Neuroplayer_print "ERROR: No previous file in\
					playback directory tree."
				set config(play_time) 0.0
				LWDAQ_set_bg $info(play_control_label) white
				set info(play_control) "Idle"
				return "FAIL"
			}
		} 
		
		set info(play_control) "Step"
		LWDAQ_post Neuroplayer_play
		return "SUCCESS"
	}
	
	# If Repeat we re-display the previous interval.
	if {$info(play_control) == "Repeat"} {
		set config(play_time) [Neuroplayer_play_time_format \
			[expr $config(play_time) - $info(play_interval_copy)]]
		if {$config(play_time) < 0.0} {
			set config(play_time) 0.0
		}
		set info(play_control) "Step"
		LWDAQ_post Neuroplayer_play front
		return "SUCCESS"
	}
	
	# We trim the text window to a maximum number of lines.
	if {[winfo exists $info(text)]} {
		if {[$info(text) index end] > 1.2 * $LWDAQ_Info(num_lines_keep)} {
			$info(text) delete 1.0 "end [expr 0 - $LWDAQ_Info(num_lines_keep)] lines"
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
		scan [Neuroplayer_seek_time \
				$config(play_file) $info(player_payload) $config(play_time)] \
			%f%u new_play_time new_play_index

		# If the new play time is less than our target, we either asked for
		# a time that does not correspond to a clock message, or there are 
		# clock messages missing from the data. In either case, we move to
		# the interval boundary just before the new play time.
		if {$new_play_time < $config(play_time)} {
			set new_play_time [Neuroplayer_play_time_format \
				[expr $new_play_time - fmod($new_play_time,$info(play_interval_copy))]]
			scan [Neuroplayer_seek_time \
					$config(play_file) $info(player_payload) $new_play_time] \
				%f%u new_play_time new_play_index
		}
		
		# If our new play time is greater than our target play time, and the target
		# play time is itself greater than zero, something has gone wrong in the 
		# seek operation.
		if {($new_play_time > $config(play_time)) && ($config(play_time) > 0)} {
			Neuroplayer_print "WARNING: No clock message preceding\
				time $config(play_time) s in [file tail $config(play_file)],\
				moving to $new_play_time s."
		}

		# Report the move to the text window when verbose is set.
		Neuroplayer_print "Moving to clock at $new_play_time s,\
			index $new_play_index,\
			closest to target $config(play_time) s." verbose
			
		# Set the play time and index.
		set config(play_time) $new_play_time
		set config(play_index) $new_play_index

		# Set the saved play time and clear the data buffer standing value list.
		set info(saved_play_time) $config(play_time)
		Neuroplayer_clock_update	
		lwdaq_data_manipulate $info(buffer_image) clear
		set info(buffer_size) 0
		set info(standing_values) "" 
	}

	# At the start of an archive, we might have to reset baseline powers and read new
	# baseline powers.
	if {$config(play_time) == 0.0} {
		if {$config(bp_autoreset)} {Neuroplayer_baseline_reset}
		if {$config(bp_autoread)} {Neuroplayer_baselines_read $config(bp_name)}
	}
	
	# Point the lwdaq library routine's error reporting to the Neuroplayer text 
	# window, which helps us with debugging.
	lwdaq_config -text_name $info(text)
	
	# Check the data we already have in the buffer image, which will be empty if we
	# have just jumped to a new time, but will contain left-over data from previous 
	# file reads if we are simply moving on through the same file.
	set play_num_clocks [expr round($info(play_interval_copy) * $info(clocks_per_second))]
	set clocks [lwdaq_receiver $info(buffer_image) \
		"-payload $info(player_payload) \
			-size $info(buffer_size) clocks 0 $play_num_clocks"]
	scan $clocks %d%d%d%d%d num_buff_errors num_clocks num_messages start_index end_index

	# We read more data from the file until we have enough to make an entire playback
	# interval. If the file ends, we set a flag. Our NDF read routine handles the end
	# of the file by returning all bytes available.
	set end_of_file 0
	set message_length [expr $info(core_message_length) + $info(player_payload)]
	while {($num_clocks < $play_num_clocks) && !$end_of_file} {
		if {[catch {
			set data [LWDAQ_ndf_data_read $config(play_file) \
				[expr $message_length * ($config(play_index) + $info(buffer_size))] \
				$info(block_size)]} error_message]} {
			Neuroplayer_print "ERROR: $error_message."
			LWDAQ_set_bg $info(play_control_label) white
			set info(play_control) "Idle"
			return "FAIL"			
		}
		set num_bytes_read [string length $data]
		set num_messages_read [expr $num_bytes_read / $message_length ]
		set num_stray_bytes [expr $num_bytes_read % $message_length ]
		if {$num_messages_read > 0} {
			Neuroplayer_print "Read $num_messages_read messages from\
				[file tail $config(play_file)]." verbose

			if {$info(max_buffer_bytes) <= \
					($info(buffer_size) * $message_length) + [string length $data]} {
				# If we have not accumulated enough clock messages so far,
				# either our buffer is not big enough to handle the message rate
				# in the telemetry system for our chosen interval, or the file
				# is corrupted. It is the corruption possibility that dominates
				# our response to the overflow. We discard the existing buffer
				# data and replace it with our new buffer data. We move the play
				# index to the first message of the newly-read data. Then we
				# try to play the file again.
				Neuroplayer_print "WARNING: Corruption or overflow\
					at $config(play_time) s, index $config(play_index)\
					in [file tail $config(play_file)]."
				set config(play_index) [expr $config(play_index) + $info(buffer_size)]
				lwdaq_data_manipulate $info(buffer_image) clear
				lwdaq_data_manipulate $info(buffer_image) write 0 $data
				set info(buffer_size) $num_messages_read
				set info(standing_values) "" 
			
				if {$config(show_messages) && $config(verbose)} {
					Neuroplayer_print [lwdaq_receiver $info(buffer_image) \
						"-payload $info(player_payload) \
							-size $info(data_size) print \
							0 $config(show_messages)"]
				}

				LWDAQ_post Neuroplayer_play
				return "ERROR"
			}
			
			lwdaq_data_manipulate $info(buffer_image) write \
				[expr $info(buffer_size) * $message_length] $data
			set info(buffer_size) [expr $info(buffer_size) + $num_messages_read]
			set clocks [lwdaq_receiver $info(buffer_image) \
				"-payload $info(player_payload) \
					-size $info(buffer_size) clocks 0 $play_num_clocks"]
			scan $clocks %d%d%d%d%d num_buff_errors \
				num_clocks num_messages start_index end_index
		} {
			set end_of_file 1
		}
	}
	
	# The file ends without supplying us with enough data for the playback
	# interval. We try to find the next file and continue. Otherwise we wait.
	if {$end_of_file} {
		# We are at the end of the file, so write baselines to metadata if
		# instructed by the user.
		if {$config(bp_autowrite)} {
			Neuroplayer_baselines_write $config(bp_name)
		}	
		
		# Stop now if play_stop_at_end is set. We don't have enough data
		# to display a full interval.
		if {$config(play_stop_at_end)} {
			LWDAQ_set_bg $info(play_control_label) white
			set info(play_control) "Idle"
			return "SUCCESS"
		}
		
		# We obtain a list of all NDF files in the play_dir directory tree. If
		# can't find the current file in the directory tree, we abort.
		set fl [LWDAQ_find_files $config(play_dir) *.ndf]
		set fl [LWDAQ_sort_files $fl]
		set i [lsearch $fl $config(play_file)]
		if {$i < 0} {
			Neuroplayer_print "ERROR: Cannot continue to a later file,\
				\"$info(play_file_tail)\" not in playback directory tree."
			LWDAQ_set_bg $info(play_control_label) white
			set info(play_control) "Idle"
			return "FAIL"
		}
		
		# We see if there is a later file in the directory tree. If so, we switch to
		# the later file. Otherwise, we wait for a new file or new data, by calling
		# the Neuroplayer play routine again and turning the control label yellow.
		set file_name [lindex $fl [expr $i + 1]]
		if {$file_name != ""} {
			Neuroplayer_print "Playback switching to next file $file_name."
			set config(play_file) $file_name
			set info(play_file_tail) [file tail $file_name]
			set config(play_time) 0.0
			set old_end_time [Neuroplayer_clock_convert $info(datetime_play_time)]
			Neuroplayer_clock_update
			set new_start_time [Neuroplayer_clock_convert $info(datetime_start_time)]
			set time_gap [expr $new_start_time - $old_end_time]
			if {$time_gap > $info(play_interval_copy)} {
				Neuroplayer_print "WARNING: Jumping $time_gap s from\
					[Neuroplayer_clock_convert $old_end_time] to\
					[Neuroplayer_clock_convert $new_start_time]\
					when switching to [file tail $file_name]."
			}
			LWDAQ_set_bg $info(play_control_label) white
			LWDAQ_post Neuroplayer_play
			return "SUCCESS"
		} {
			# This is the case where we have $num_clocks but need
			# $play_num_clocks and we have no later file to switch to. This case
			# arises during live play-back, when the player is trying to read
			# more data out of the file that is being written to by the
			# recorder. The screen will show you when the Player is waiting. By
			# checking the state of the play_control_label, we make sure that we
			# issue the following print statement only once. While the Player is
			# waiting, the label remains yellow.
			if {[winfo exists $info(window)]} {
				if {[$info(play_control_label) cget -bg] != "yellow"} {
					Neuroplayer_print "Have $num_clocks clocks, need $play_num_clocks.\
						Waiting for next archive to be recorded." verbose
					LWDAQ_set_bg $info(play_control_label) yellow
				}
			}
			LWDAQ_post Neuroplayer_play
			return "SUCCESS"
		}
	}
	
	# By this point, the number of clocks in the buffer should be at least equal
	# to the number required by the interval. If not, something has gone wrong
	# that we did not anticipate. We issue a warning and hope that the
	# Neuroplayer can keep going without crashing.
	if {$num_clocks < $play_num_clocks} {
		Neuroplayer_print "WARNING: Internal error, num_clocks < play_num_clocks."
	}
	
	# We make sure the Play control label background is no longer yellow, because
	# we are no longer waiting for data.
	if {[winfo exists $info(window)]} {
		if {$info(play_control) == "Play"} {
			LWDAQ_set_bg $info(play_control_label) green
		} {
			LWDAQ_set_bg $info(play_control_label) orange
		}
	}
	
	# By this point, start_index and end_index should be the indices within the
	# buffer image of the first clock message in the current playback interval
	# and the first clock message in the next playback interval. It is possible,
	# however, for the buffer to contain the current interval and no additional
	# clock messages, so our end_index is now -1. If the index is -1, we set it
	# to the number of messages.
	if {$end_index < 0} {
		set end_index $num_messages
	}
	
	# We transfer this interval's data from the buffer image into our data
	# image, which we will use for analysis and reconstruction. The transfer
	# involves copying the interval data from the buffer image and deleting it
	# from the buffer image.
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
	# We set the num_errors variable so it contains the number of clock 
	# message errors in the interval data.
	set clocks [lwdaq_receiver $info(data_image) \
		"-payload $info(player_payload) \
			-size $info(data_size) clocks 0 -1"]
	scan $clocks %d%d%d%d%d num_errors num_clocks num_messages first_index last_index
	set indices [lwdaq_receiver $info(data_image) \
		"-payload $info(player_payload) \
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
		Neuroplayer_print "WARNING: Loss of at least $initial_skip s\
			at $config(play_time) s in [file tail $config(play_file)]."
	} {
		set initial_skip 0.0
	}

	# We determine the time span of this interval, as indicated by the clock
	# messages it contains. We trust that the interval contains at least the
	# required number of clocks, so it must span at least the play interval.
	set display_span $info(play_interval_copy)
	if {$num_errors > 0} {
		set display_span [expr 1.0 * \
			($last_clock - $first_clock + 1) / \
			$info(clocks_per_second)]
		while {$display_span < $info(play_interval_copy)} {
			set display_span [expr $display_span + \
				1.0 * ($info(max_sample) + 1) / $info(clocks_per_second)]
		}
	}
	
	# We report upon the number of errors within this interval, as provided 
	# by the lwdaq_receiver routine.
	if {$num_errors > 0} {
		Neuroplayer_print "WARNING: Encountered $num_errors errors\
			in [file tail $config(play_file)] between $config(play_time) s and\
			[expr $config(play_time) + $info(play_interval_copy)] s."
	}	

	# If the time span is greater than the play interval, the interval contains
	# some kind of corruption. In verbose mode, we inform the user.
	if {$display_span > $info(play_interval_copy)} {
		Neuroplayer_print "Missing\
			[format %.2f [expr $display_span - $info(play_interval_copy)]] s\
			after $config(play_time) s,\
			display spans [format %.2f $display_span] s." verbose
	}
	
	# We show the raw message data in the text window if the user wants to see
	# it in verbose mode, or if we have encountered an error in verbose mode.
	if {($config(show_messages) || ($num_errors > 0)) && $config(verbose)} {
		set report [lwdaq_receiver $info(data_image) \
			"-payload $info(player_payload) \
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
			if {$hi_index < $lo_index + 2*$extent} \
				{set hi_index [expr $lo_index + 2*$extent]}
			Neuroplayer_print [lwdaq_receiver $info(data_image) \
				"-payload $info(player_payload) \
					-size $info(data_size) print $lo_index $hi_index"]
		} {
			Neuroplayer_print [lwdaq_receiver $info(data_image) \
				"-payload $info(player_payload) \
					-size $info(data_size) print 0 $config(show_messages)"]
		}
	}
	
	# If verbose, let the user know how many messages are included in this
	# interval. The total includes null messages, if corruption has introduced
	# them into the interval. The number of clocks should be equal to the 
	# interval length multiplied by the clock frequency, but in case of 
	# errors in playback, we print the number we are actually using.
	Neuroplayer_print "Using $num_messages messages,\
		including $num_clocks clocks." verbose

	# Clear the Neuroplayer graphs in preparation for new data.
	Neuroplayer_fresh_graphs		
	
	# Clear the Neurotracker graphs.
	Neurotracker_fresh_graphs

	# Get a list of the available channel numbers and message counts. The list
	# includes any channel in which we have at least one message. It takes the
	# form of a space-delimited string of channel numbers and message counts.
	set all_message_channels [lwdaq_receiver $info(data_image) \
		"-payload $info(player_payload) \
			-size $info(data_size) list"]

	# We look for messages in the auxiliary channel.
	set new_aux_messages ""
	foreach {c a} $all_message_channels {
		if {$c % $info(set_size) == $info(set_size) - 1} {
			set messages [lwdaq_receiver $info(data_image) \
				"-payload $info(player_payload) extract $c"]
			if {[LWDAQ_is_error_result $messages]} {error $messages}
			foreach {mt md} $messages {
				append new_aux_messages "$c $mt $md "
			}
		}
	}

	# We are going to calculate a timestamp, with resolution one clock tick, for
	# each auxiliary message. The timestamps can be used as a form of addressing
	# for slow data transmissions. To get the absolute timestamp, we get the
	# time of the first clock message in the data. This time is a sixteen-bit
	# value that has counted the number of 256-tick periods since the data receiver
	# clock was last reset, wrapping around to zero every time it overflows.
	scan [lwdaq_receiver $info(data_image) \
		"-payload $info(player_payload) get $first_index"] %d%d%d cid bts fvn
		
	# We clear the auxiliary message list. Our assumption is that tools like
	# the Stimulator will be waiting for the Neuroplayer to complete a play
	# interval and then do all the work they need to on the list before the
	# next play interval.
	set info(aux_messages) ""

	# We take each new auxiliary message and break it up into three parts. The
	# first part is a four-bit ID, which is the primary channel number of the
	# device producing the auxiliary message. The second part is a four-bit
	# field address. The third is eight bits of data. These sixteen bits are the
	# contents of the auxiliary message. We add a fourth number, which is the
	# timestamp of message reception. We give the timestamp modulo 2^16, which
	# gives us sufficient precision to detect any time-based address encoding of
	# auxiliary data. These four numbers make one entry in the auxiliary message
	# list, so we append them to the existing list. If the four-bit ID is zero
	# or fifteen, this is a bad message, so we don't store it.
	foreach {cn mt md} $new_aux_messages {
		set id [expr ($md / 4096)]
		if {($id == $info(set_size) - 1) || ($id == 0)} {continue}
		set id [expr (($cn / $info(set_size)) * $info(set_size)) + $id]
		set fa [expr ($md / 256) % 16]
		set d [expr $md % 256]
		set ts  [expr ($mt + $bts * 256) % (65536)]
		lappend info(aux_messages) "$id $fa $d $ts"
	}
	
	# We keep only a finite number of the most recent auxiliary messages.
	set k [expr $config(aux_num_keep) - 1]
	if {[llength $info(aux_messages)] >= $k} {
		set info(aux_messages) [lrange $info(aux_messages) end-$k end]
	}
	set config(aux_list_length) [llength $info(aux_messages)]
		
	# We make a list of the active channels, in which channel numbers and numbers
	# of samples are separated by colons as in 4:256 for channel four with two
	# hundred and fifty six samples in the interval.
	if {![LWDAQ_is_error_result $all_message_channels]} {
		for {set id $info(min_id)} {$id < $info(max_id)} {incr id} {
			set info(qty_$id) 0
		}
		set info(active_channels) ""
		foreach {id qty} $all_message_channels {
			set info(qty_$id) $qty
			if {$qty > $config(activity_threshold) * $info(play_interval_copy)} {
				if {($id >= $info(min_id)) && ($id <= $info(max_id))} {
					lappend info(active_channels) "$id:$qty"
				}
			}
		}
	} {
		Neuroplayer_print $all_message_channels
		set info(active_channels) ""
		set all_message_channels ""
	}

	# If the activity or calibration panels are open, we change channel alerts to
	# "None" for channels that are not active.
	if {[winfo exists $info(window)\.activity]} {
		foreach id $info(activity_selected) {
			if {[set info(status_$id)] != "None"} {
				if {[lsearch $info(active_channels) "$id\:*"] < 0} {
					set info(status_$id) "Off"
				}
			}
		}
	}
	if {[winfo exists $info(window)\.calibration]} {
		foreach id $info(calibration_selected) {
			if {[set info(status_$id)] != "None"} {
				if {[lsearch $info(active_channels) "$id\:*"] < 0} {
					set info(status_$id) "Off"
				}
			}
		}
	}
	
	# We select all active channels or all channels specied by the channel
	# selector string directly. The selected_channels elements either take the
	# form of "id:sps" or just "id", where "sps" is the nominal sample rate of
	# the channel, as specified by the use. The active_channels elements are
	# "id:qty", where qty is the actual number of samples received, as opposed
	# to the nominal sample rate.
	if {[string trim $config(channel_selector)] == "*"} {
		set selected_channels ""
		foreach code $info(active_channels) {
			set id [lindex [split $code :] 0]
			lappend selected_channels $id
		}
	} {
		set selected_channels $config(channel_selector)
	}
	
	# Some active channels may be ignored by a user-specified channel list. We
	# will determine quality of reception for these now, before moving on to
	# processing the selected channels. We pass a status-only flag to the signal
	# procedure, which causes it to return before performing any reconstruction.
	foreach code $info(active_channels) {
		set id [lindex [split $code :] 0]
		if {([lsearch $selected_channels "$id"] < 0) \
				&& ([lsearch $selected_channels "$id\:*"] < 0)} {
			Neuroplayer_signal $id 1
		}
	}
	
	# We read the processor script from disk. We replace "Neuroarchiver" with
	# "Neuroplayer" for backward compatibility with old processors, prior to the
	# partition of the Neuroarchiver into two parts, player and recorder.
	set result ""
	set en_proc $config(enable_processing)
	if {$en_proc} {
		if {![file exists $config(processor_file)]} {
			set result "ERROR: Processor script $config(processor_file) does not exist."
		} {
			set info(processor_file_tail) [file tail $config(processor_file)]
			set f [open $config(processor_file) r]
			set info(processor_script) [read $f]
			close $f
			set info(processor_script) [regsub -all Neuroarchiver \
				$info(processor_script) Neuroplayer]
		}
	}
	
	# We apply processing to each channel for this interval, plot the signal,
	# and plot the spectrum, as enabled by the user.
	foreach info(channel_code) $selected_channels {
		set info(channel_num) [lindex [split $info(channel_code) :] 0]
		if {![string is integer -strict $info(channel_num)] \
				|| ($info(channel_num) < $info(clock_id)) \
				|| ($info(channel_num) > $info(max_id))} {
			set result "ERROR: Invalid channel number \"$info(channel_num)\"."
			set info(play_control) "Stop"
			break
		}
		
		set info(signal) [Neuroplayer_signal]
		set info(values) [Neuroplayer_values]
		if {$config(enable_vt)} {
			Neuroplayer_plot_signal
		}
		set info(t_min) $config(play_time)
		
		if {$config(enable_af) || $config(af_calculate)} {
			set info(spectrum) [Neuroplayer_spectrum]
		}
		if {$config(enable_af)} {
			Neuroplayer_plot_spectrum
		} 
		
		if {$config(alt_calculate) || [winfo exists $info(tracker_window)]} {
			Neurotracker_extract
		} 
		if {[winfo exists $info(tracker_window)]} {
			Neurotracker_plot
		}
		if {$info(export_state) == "Play"} {
			Neuroexporter_export "Play"
			if {$info(play_control) == "Stop"} {break}
		}
		if {![LWDAQ_is_error_result $result] && $en_proc} {
			if {[catch {eval $info(processor_script)} error_result]} {
				set result "ERROR: In $info(processor_file_tail)\
					for channel $info(channel_num),\
					$error_result"
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
	# if it's running. All the Neuroclassifier needs to plot and classify the
	# most recent interval is the results of processing, which will, we assume,
	# contain the metrics the Neuroarclassifier is expecting to receive.
	if {$result != ""} {
		if {![LWDAQ_is_error_result $result]} {
			set result "[file tail $config(play_file)] $config(play_time) $result"
		}
		if {[LWDAQ_is_error_result $result] \
			|| [regexp {^WARNING: } $result] \
			|| !$config(quiet_processing)} {
			Neuroplayer_print $result
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
					Neuroplayer_print "WARNING: Wrote buffered characteristics to\
						[file tail $cfn] after previous write failure."		
				}
			} error_result]} {
				if {!$data_backlog} {
					Neuroplayer_print "WARNING: Could not write to [file tail $cfn],\
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
			Neuroplayer_print "WARNING: Processing is disabled, so will not be saved."
		}
	}
	
	# Turn the label back to white before we plot the graphs. This gives the
	# label a better flash behavior during rapid playback.
	LWDAQ_set_bg $info(play_control_label) white

	# Draw the graphs on the screen.
	Neuroplayer_draw_graphs
	Neurotracker_draw_graphs
	Neuroplayer_overview_cursor
	
	# Play any video that needs to be played, specifying the current play time as a
	# Unix time, and the current interval length.
	if {$config(video_enable)} {
		Neuroplayer_video_action \
			"Play" \
			[Neuroplayer_clock_convert $info(datetime_play_time)] \
			$info(play_interval_copy)		
	} 
	
	# We set the new previous clock to the last clock of this interval.
	set info(play_previous_clock) $last_clock
		
	# Our new play index will be the previous index plus the end index of the 
	# interval we just played. 
	set config(play_index) [expr $config(play_index) + $end_index]
	
	# The new play time will be the the old play time plus the interval length,
	# regardless of whaterver errors we may have encountered in the data.
	set config(play_time) [Neuroplayer_play_time_format \
		[expr $config(play_time) + $info(play_interval_copy)]]
	set info(saved_play_time) $config(play_time)
	
	# We update the time values of the Clock Panel and format the play time in
	# the Player window.
	Neuroplayer_clock_update
		
	# Post another execution of this routine to the queue, or terminate.
	if {$info(play_control) == "Play"} {
		LWDAQ_post Neuroplayer_play
	} {
		set info(play_control) "Idle"
	}

	return $result
}

#
# Neuroplayer_jump displays an event. We can pass the event directly to the
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
# of the Player's select string by setting the Neuroplayer configuration
# parameter "isolate_events" to 0. If, instead of an event string composed of
# event elements, we pass one of the keywords "Back", "Go", "Step", "Hop",
# "Play", or "Stop" the routine will read the current event list from disk and
# select one of its events for display, just as if this event were passed to the
# jump routine. The Back, Go, and Step keywords instruct the jump routine to
# decrement, leave unaltered, or increment the Neuroplayer's event_index. The
# Hop keyword instructs the jump routine to select an event at random from the
# list, by setting the event_index to a random number between one and the event
# list length. We use the Hop instruction to move at random in large event lists
# to perform random sampling for confirmation of effective event classification.
# The Play instruction causes the Neuroplayer to move through the event list,
# displaying each event as fast as it can. The Stop instruction stops the Play
# instruction but does nothing else. The jump routine will set the baseline
# powers in preparation for display and processing, according to the
# jump_strategy parameter. If this is "local" we use the current baseline
# powers, if "read" we read them from the archive metadata using the baseline
# power name in the Baselines Panel. If it is "event" we assume the fourth
# element in the event list is a keyword describing the event and the fifth
# element is the baseline power we should apply to the selected channels.
# Another option is "verbose", which if set to zero, suppresses the event
# description printout in the Neuroplayer text window. The "Next_NDF",
# "Current_NDF", "Previous_NDF" keywords jump to the start of the next, current,
# or previous NDF files in the alphabetical list of archives in the playback
# directory tree.
#
proc Neuroplayer_jump {{event ""} {verbose 1}} {
	upvar #0 Neuroplayer_info info
	upvar #0 Neuroplayer_config config

	# If the event is anything other than the Play instruction,
	# we clear every pending Neuroplayer_jump event in the 
	# LWDAQ event queue so that this event will stop all jump
	# activity when it completes.
	if {$event != "Play"} {
		LWDAQ_queue_clear "Neuroplayer_jump*"
	}	

	# If the event is the Stop keyword, we make sure the list file
	# background is gray and we return. Otherwise, we set the background
	# to orange and allow the window manager to draw the new color.
	if {($event == "Stop") } {
		LWDAQ_set_bg $info(play_control_label) white	
		return ""
	} {
		LWDAQ_set_bg $info(play_control_label) orange
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
			Neuroplayer_print $error_message
			LWDAQ_set_bg $info(play_control_label) white
			return $error_message
		}
		
		# We see if there is a next or previous file in the directory tree. 
		if {$event == "Next_NDF"} {set file_name [lindex $fl [expr $index + 1]]}
		if {$event == "Previous_NDF"} {set file_name [lindex $fl [expr $index - 1]]}
		if {$event == "Current_NDF"} {set file_name [lindex $fl [expr $index]]}
		if {$file_name == ""} {
			set error_message "ERROR: No matching file in playback directory tree."
			Neuroplayer_print $error_message
			LWDAQ_set_bg $info(play_control_label) white		
			return $error_message
		}

		# We compose an event out of the new NDF file name and time zero.
		set event "[file tail $file_name] 0.0 ? $event"
		Neuroplayer_print "Playback switching to $file_name."
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
			Neuroplayer_print $error_message
			LWDAQ_set_bg $info(play_control_label) white	
			return $error_message
		}
	
		set f [open $config(event_file) r]
		set event_list [split [string trim [read $f]] \n]
		close $f
		
		if {[llength $event_list] < 1} {
			set error_message "ERROR: Empty event list."
			Neuroplayer_print error_message
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
			Neuroplayer_print $error_message
			LWDAQ_set_bg $info(play_control_label) white
			return $error_message
		}
		set pf [lindex $fl $index]
		if {[catch {LWDAQ_ndf_data_check $pf} error_message]} {
			set error_message "ERROR: Checking archive, $error_message."
			Neuroplayer_print $error_message
			LWDAQ_set_bg $info(play_control_label) white		
			return $error_message
		}
		
		# Set the play file and play time to match this event.
		set config(play_file) $pf
		set info(play_file_tail) [file tail $pf]
		set config(play_time) [Neuroplayer_play_time_format \
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
				\"[Neuroplayer_clock_convert $datetime]\"\
				in $config(play_dir)."
			Neuroplayer_print $error_message
			LWDAQ_set_bg $info(play_control_label) white	
			return $error_message
		}
		if {[catch {LWDAQ_ndf_data_check $pf} error_message]} {
			set error_message "ERROR: Checking archive, $error_message."
			Neuroplayer_print $error_message
			LWDAQ_set_bg $info(play_control_label) white		
			return $error_message
		}

		# We have an archive starting before our target time. Now we check
		# to see if the archive extends as far as our target time.
		set alen [Neuroplayer_end_time $pf $info(player_payload)]
		if {$alen + $atime < $datetime + $offset + $info(play_interval_copy)} {
			set error_message "ERROR: Cannot find\
				\"[Neuroplayer_clock_convert $datetime]\"\
				in $config(play_dir)."
			Neuroplayer_print $error_message
			LWDAQ_set_bg $info(play_control_label) white		
			return $error_message
		}
		
		# Set the play file and play time to match this event.
		set config(play_file) $pf
		set info(play_file_tail) [file tail $pf]
		set config(play_time) [Neuroplayer_play_time_format \
			[expr $datetime + $offset - $atime] ]
	} else {
		set error_message "ERROR: Invalid event \"[string range $event 0 60]\"."
		Neuroplayer_print $error_message
		LWDAQ_set_bg $info(play_control_label) white		
		return $error_message
	}
	
	# If event isolation is turned on, we adjust the Player's channel 
	# select string according to the event's channel select string.
	if {$config(isolate_events)} {
		set cs [lindex $event 2]
		if {$cs != "?"} {
			set config(channel_selector) $cs
		}
	}
	
	# Display the event in the text window with a jump button.
	if {$verbose} {Neuroplayer_print_event $event}
	
	# Set up the baseline powers according to the jump configuration in the
	# Baselines Panel. If we are supposed to use the baseline calibration in
	# the event description, we try to extract one baseline for each channel
	# listed in event.
	switch $config(jump_strategy) {
		"read" {
			Neuroplayer_baselines_read $config(bp_name)
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
	Neuroplayer_command "Step"
	
	# If we are playing through and archive, post another jump to the queue.
	# Otherwise, make sure the file name background is gray.
	if {$repeat} {
		LWDAQ_post [list Neuroplayer_jump "Play"]
	} {
		LWDAQ_set_bg $info(event_file_label) lightgray
	}
	
	# We return the event.
	return $event
}

#
# Neuroplayer_video_download downloads the Videoarchiver zip archive with the
# help of a web browser.
#
proc Neuroplayer_video_download {} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info

	set result [LWDAQ_url_open $info(video_library_archive)]
	if {[LWDAQ_is_error_result $result]} {
		LWDAQ_print $info(text) $result
		return "ERROR"
	} else {
		return "SUCCESS"
	}
}

#
# Neuroplayer_video_suggest prints a message with a text link suggesting that
# the user download the Videoarchiver directory to install ffmpeg and mplayer.
#
proc Neuroplayer_video_suggest {} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info

	LWDAQ_print $info(text) ""
	LWDAQ_print $info(text) \
		"ERROR: Cannot play videos, Videoarchiver package not installed."
	LWDAQ_print $info(text) \
		"  To install libraries, click on the link below which will download a zip archive."
	$info(text) insert end "           "
	$info(text) insert end \
		"$info(video_library_archive)" "textbutton download"
	$info(text) tag bind download <Button> Neuroplayer_video_download
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
# Neuroplayer_video_duration calls ffmpeg to determine the duration of an
# existing video file. If the file does not exist, the routine returns -1,
# otherwise it returns the length of the video in seconds.
#
proc Neuroplayer_video_duration {{fn ""}} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info
	
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
# Neuroplayer_video_watchdog waits for the existing video to play for one
# play interval and then stops the video.
#
proc Neuroplayer_video_watchdog {pid} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info

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
			Neuroplayer_print "Playback of $info(video_file) aborted." verbose
			LWDAQ_set_bg $info(play_control_label) white
			set info(video_state) "Idle"
			return $info(video_state)
		}

		if {$vt >= $info(video_stop_time)} {
			catch {puts $info(video_channel) "pause"}
			Neuroplayer_print "Playback of $info(video_file)\
				paused at video time $vt s." verbose
			LWDAQ_set_bg $info(play_control_label) white
			set info(video_state) "Idle"
		} elseif {$vt >= $info(video_end_time) - ($info(video_wait_ms)/1000.0)} {
			Neuroplayer_print "Playback of $info(video_file)\
				stopped at video end $info(video_end_time) s." verbose
			LWDAQ_set_bg $info(play_control_label) white
			set info(video_state) "Idle"
		}
	}

	LWDAQ_post [list Neuroplayer_video_watchdog $pid]
	return $info(video_state)
}

#
# Neuroplayer_video_action finds the video file and video internal time that
# corresponds to the specified Unix time. The routine uses a cache of
# recently-used video files to save time when searching for the correct file,
# because the search requires that we get the length of the video calculated by
# ffmpeg, and this calculation is time-consuming. If the video is not in the
# cache, we use the video directory as a source of video files. We pass three
# parameters to the routine: a command "cmd", a Unix time in seconds "datetime",
# and an interval length in seconds "length". The command must be "Seek" or
# "Play". The Seek command returns the name of the video containing the
# datetime, the time within the video that corresponds to the datetime, and the
# duration of the video. The Play command plays the video starting at datetime
# and going on for length seconds.
# 
proc Neuroplayer_video_action {cmd datetime length} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info
	
	# Check to see if ffmpeg and mplayer are available. If not, we suggest
	# downloading the Videoarchiver package and go to idle state.
	if {![file exists $info(ffmpeg)] || ![file exists $info(mplayer)]} {
		Neuroplayer_video_suggest
		set info(video_state) "Idle"
		return ""
	}

	# Look in our video file cache to see if the start and end of the 
	# requested interval is contained in a video we have already used.
	set vf ""
	set min_length [format %.1f [expr $info(video_min_interval)*0.5]]
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
		Neuroplayer_print "Using cached video file $vf." verbose
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
			Neuroplayer_print "ERROR: No video in [file tail $config(video_dir)]\
				begins before $datetime s."
			return ""
		}

		# Calculate the video file length.
		set vlen [Neuroplayer_video_duration $vf]

		# Check that the video file includes the start of the requested interval.
		set gap [expr $datetime - ($vtime + $vlen)]
		if {$gap > 0} {
			Neuroplayer_print "WARNIMG: File [file tail $vf], length $vlen s,\
				ends $gap s before start of requested interval."
		}
		
		# Check that the video file contains the interval end.
		set missing [expr ($datetime + $length) - ($vtime + $vlen)]
		if {$missing > $info(video_frame_time)} {
			Neuroplayer_print "WARNING: File [file tail $vf], length $vlen s,\
				ends $missing s before end of requested interval."
		}

		# Add the video file to the cache. Keep the cache of finite length.
		lappend info(video_file_cache) [list $vf $vtime $vlen]
		if {[llength $info(video_file_cache)] > $info(max_video_files)} {
			set info(video_file_cache) [lrange $info(video_file_cache) 1 end]
		}

		Neuroplayer_print "Adding video file $vf to video cache." verbose
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

		# Start up the watchdog for this Mplayer process.
		LWDAQ_post [list Neuroplayer_video_watchdog $info(video_process)]
	}

	# Set the end time of the video and the stop time. The stop time is one
	# half-frame before the end time, so we don't play the first frame of the
	# next interval.
	set info(video_end_time) [format %.3f $vlen]
	set info(video_stop_time) [format %.3f \
		[expr $vseek + $length - $info(video_frame_time)]]
	if {$info(video_stop_time) > $info(video_end_time)} {
		set info(video_stop_time) $info(video_end_time)
	}

	# Set the playback speed and seek the interval start.
	puts $info(video_channel) "pausing speed_set $config(video_speed)"
	puts $info(video_channel) "seek $vseek 2"
	
	# Set the video state to play and report the seek time.
	Neuroplayer_print "Playing $vf for $length s\
		starting at time $vseek s of $vlen s." verbose
	LWDAQ_set_bg $info(play_control_label) cyan
	set info(video_state) "Play"
	
	# Return the file name, seek time and file duration.
	return [list $vf $vseek $vlen]
}

#
# Neuroplayer_open creates the Neuroplayer window, with all its buttons, boxes,
# and displays. It uses routines from the TK library to make the frames and
# widgets. To make sense of what the procedure is doing, look at the features in
# the Neuroplayer from top-left to bottom right. That's the order in which we
# create them in the code. Frames enclose rows of buttons, labels, and entry
# boxes. The images are TK "photos" associated with label widgets. The last
# thing to go into the Neuroplayer panel is its text window. 
#
proc Neuroplayer_open {} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info
	global LWDAQ_Info

	# Open the tool window. If we get an empty string back from the opening
	# routine, something has gone wrong, or a window already exists for this
	# tool, so we abort.
	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return "ABORT"}
	
	# Get on with creating the display in the tool's frame or window.
	set f $w.displays
	frame $f -border 2
	pack $f -side top -fill x

	set f $w.displays.signal
	frame $f -relief groove -border 2
	pack $f -side left -fill y

	set f $w.displays.signal.title
	frame $f
	pack $f -side top -fill x

	checkbutton $f.enable -variable Neuroplayer_config(enable_vt) -text "Enable" 
	label $f.title -text "Value vs. Time" -fg $info(label_color)
	pack $f.enable $f.title -side left -expand yes
	foreach a "SP CP NP" {
		set b [string tolower $a]
		radiobutton $f.$b -variable Neuroplayer_config(vt_mode) \
			-text $a -value $a
		pack $f.$b -side left -expand yes
	}

	set f $w.displays.signal
	set info(vt_photo) [image create photo "_Neuroplayer_vt_photo_"]
	label $f.graph -image $info(vt_photo)
	bind $f.graph <Double-Button-1> {Neuroplayer_magnified_view vt}
	pack $f.graph -side top -expand yes

	set f $w.displays.signal.controls
	frame $f
	pack $f -side top -fill x
	label $f.lv_offset -text "v_offset:" -fg $info(label_color)
	entry $f.ev_offset -textvariable Neuroplayer_config(v_offset) -width 5
	pack $f.lv_offset $f.ev_offset -side left -expand yes
	label $f.lv_range -text "v_range:" -fg $info(label_color)
	entry $f.ev_range -textvariable Neuroplayer_config(v_range) -width 5
	pack $f.lv_range $f.ev_range -side left -expand yes
	label $f.l_glitch -text "glitch_threshold:" -fg $info(label_color)
	entry $f.e_glitch -textvariable Neuroplayer_config(glitch_threshold) -width 5
	pack $f.l_glitch $f.e_glitch -side left -expand yes	
	label $f.lt_left -text "t_min:" -fg $info(label_color)
	label $f.et_left -textvariable Neuroplayer_info(t_min) -width 7
	pack $f.lt_left $f.et_left -side left -expand yes

	set f $w.displays.spectrum
	frame $f -relief groove -border 2
	pack $f -side right -fill y

	set f $w.displays.spectrum.title
	frame $f 
	pack $f -side top -fill x

	label $f.title -text "Amplitude vs. Frequency" -fg $info(label_color)
	checkbutton $f.lf -variable Neuroplayer_config(log_frequency) -text "Log"
	checkbutton $f.la -variable Neuroplayer_config(log_amplitude) -text "Log"
	checkbutton $f.enable -variable Neuroplayer_config(enable_af) -text "Enable"
	pack $f.la $f.title $f.lf $f.enable -side left -expand yes

	set f $w.displays.spectrum
	set info(af_photo) [image create photo "_Neuroplayer_af_photo_"]
	label $f.graph -image $info(af_photo) 
	bind $f.graph <Double-Button-1> {Neuroplayer_magnified_view af}
	pack $f.graph -side top -expand yes

	set f $w.displays.spectrum.controls
	frame $f
	pack $f -side top -fill x
	foreach a {a_min a_max f_min f_max} {
		label $f.l$a -text "$a\:" -fg $info(label_color)
		entry $f.e$a -textvariable Neuroplayer_config($a) \
			-relief sunken -bd 1 -width 5
		pack $f.l$a $f.e$a -side left -expand yes
	}

	set f $w.play
	frame $f -border 4
	pack $f -side top -fill x

	set f $w.play.a
	frame $f
	pack $f -side top -fill x

	label $f.control -textvariable Neuroplayer_info(play_control) -fg blue -width 8
	set info(play_control_label) $f.control
	pack $f.control -side left -expand yes

	foreach a {Play Step Stop Repeat Back} {
		set b [string tolower $a]
		button $f.$b -text $a -command "Neuroplayer_command $a"
		pack $f.$b -side left -expand yes
	}

	label $f.lrs -text "Interval (s):" -fg $info(label_color)
	tk_optionMenu $f.mrs Neuroplayer_config(play_interval) \
		0.0625 0.125 0.25 0.5 1.0 2.0 4.0 8.0 16.0 32.0
	label $f.li -text "Time (s):" -fg $info(label_color)
	entry $f.ei -textvariable Neuroplayer_config(play_time) -width 8
	pack $f.lrs $f.mrs $f.li $f.ei -side left -expand yes
	label $f.le -text "Length (s):" -fg $info(label_color)
	label $f.ee -textvariable Neuroplayer_info(play_end_time) -width 8 \
		-bg $info(variable_bg) -anchor w
	pack $f.le $f.ee -side left -expand yes
	checkbutton $f.seq -variable Neuroplayer_config(sequential_play) \
		-text "Sequential"
	pack $f.seq -side left -expand yes

	set f $w.play.ac
	frame $f -bd 1
	pack $f -side top -fill x

	label $f.al -text "Activity:" -anchor w -fg $info(label_color)
	pack $f.al -side left 
	switch $LWDAQ_Info(os) {
		"MacOS" {set width 110}
		"Windows" {set width 85}
		"Linux" {set width 95}
		default {set width 100}
	}
	label $f.ae -textvariable Neuroplayer_info(active_channels) \
		-width $width -bg $info(variable_bg) -anchor w
	pack $f.ae -side left -expand yes
	button $f.ab -text "Panel" -command "LWDAQ_post Neuroplayer_activity"
	pack $f.ab -side left -expand yes

	set f $w.play.b
	frame $f -bd 1
	pack $f -side top -fill x

	label $f.a -text "Archive:" -anchor w -fg $info(label_color)
	pack $f.a -side left 
	label $f.b -textvariable Neuroplayer_info(play_file_tail) \
		-width 20 -bg $info(variable_bg)
	button $f.pick -text "Pick" -command "Neuroplayer_command Pick"
	button $f.pickd -text "PickDir" -command "Neuroplayer_command PickDir"
	button $f.first -text "First" -command "Neuroplayer_command First"
	button $f.reload -text "Reload" -command  "Neuroplayer_command Reload"
	button $f.clist -text "List" -command {
		LWDAQ_post [list Neuroplayer_list 0 ""]
	}
	pack $f.b $f.pick $f.pickd $f.first $f.reload $f.clist -side left -expand yes
	button $f.metadata -text "Metadata" -command {
		LWDAQ_post [list Neuroplayer_metadata_view play]
	}
	pack $f.metadata -side left -expand yes
	button $f.overview -text "Overview" -command {
		LWDAQ_post [list LWDAQ_post "Neuroplayer_overview"]
	}
	pack $f.overview -side left -expand yes

	label $f.v -text "Video:" -fg $info(label_color)
	pack $f.v -side left -expand no
	button $f.vp -text "PickDir" -command "Neuroplayer_pick video_dir 1"
	checkbutton $f.ve -variable Neuroplayer_config(video_enable) -text "Enable"
	pack $f.vp $f.ve -side left -expand yes

	set f $w.play.c
	frame $f -bd 1
	pack $f -side top -fill x
	
	label $f.e -text "Processing:" -anchor w -fg $info(label_color)
	pack $f.e -side left 
	label $f.f -textvariable Neuroplayer_info(processor_file_tail) \
		-width 16 -bg $info(variable_bg)
	button $f.g -text "Pick" -command "Neuroplayer_pick processor_file 1"
	checkbutton $f.enable -variable \
		Neuroplayer_config(enable_processing) -text "Enable"
	checkbutton $f.save -variable \
		Neuroplayer_config(save_processing) -text "Save"
	checkbutton $f.quiet -variable \
		Neuroplayer_config(quiet_processing) -text "Quiet"
	pack $f.f $f.g $f.enable $f.save $f.quiet -side left -expand yes
	label $f.lchannels -text "Select:" -anchor e -fg $info(label_color)
	switch $LWDAQ_Info(os) {
		"MacOS" {set width 50}
		"Windows" {set width 40}
		"Linux" {set width 40}
		default {set width 40}
	}
	entry $f.echannels -textvariable Neuroplayer_config(channel_selector) \
		-width $width
	pack $f.lchannels $f.echannels -side left -expand yes
	button $f.autofill -text "Autofill" -command {
		set Neuroplayer_config(channel_selector) "*"
		LWDAQ_post [list Neuroplayer_play "Repeat"]
		LWDAQ_post Neuroplayer_autofill
	}
	pack $f.autofill -side left -expand yes

	set f $w.play.d
	frame $f -bd 1
	pack $f -side top -fill x
	
	label $f.e -text "Events:" -anchor w -fg $info(label_color)
	pack $f.e -side left
	label $f.f -textvariable Neuroplayer_info(event_file_tail) \
		-width 24 -bg $info(variable_bg)
	set info(event_file_label) $f.f
	button $f.g -text "Pick" -command "Neuroplayer_pick event_file 1"
	pack $f.f $f.g -side left -expand yes
	foreach a {Hop Play Back Go Step Stop} {
		set b [string tolower $a]
		button $f.$b -text $a -command [list LWDAQ_post "Neuroplayer_jump $a"]
		pack $f.$b -side left -expand yes
	}
	label $f.il -text "Index:"  -fg $info(label_color)
	entry $f.ie -textvariable Neuroplayer_config(event_index) -width 5
	label $f.ll -text "Length:"  -fg $info(label_color)
	label $f.le -textvariable Neuroplayer_info(num_events) -width 5
	button $f.mark -text Mark -command [list LWDAQ_post "Neuroplayer_print_event"]
	pack $f.il $f.ie $f.ll $f.le $f.mark -side left -expand yes

	set f $w.play.e
	frame $f -bd 1
	pack $f -side top -fill x
	
	label $f.e -text "Extensions:" -anchor w -fg $info(label_color)
	pack $f.e -side left
	button $f.baselines -text "Calibration" -command "Neuroplayer_calibration"
	pack $f.baselines -side left -expand yes
	button $f.cb -text "Classifier" -command "LWDAQ_post Neuroclassifier_open"
	pack $f.cb -side left -expand yes
	button $f.clock -text "Clock" -command "LWDAQ_post Neuroplayer_clock"
	pack $f.clock -side left -expand yes
	button $f.export -text "Export" -command "LWDAQ_post Neuroexporter_open"
	pack $f.export -side left -expand yes
	button $f.tb -text "Tracker" -command "LWDAQ_post Neurotracker_open"
	pack $f.tb -side left -expand yes
	button $f.stimb -text "Stimulator" -command {
		LWDAQ_post "LWDAQ_run_tool Stimulator"
	}
	pack $f.stimb -side left -expand yes
	checkbutton $f.verbose -variable Neuroplayer_config(verbose) -text "Verbose"
	pack $f.verbose -side left -expand yes
	button $f.conf -text "Configure" -command "Neuroplayer_configure"
	pack $f.conf -side left -expand yes
	button $f.help -text "Help" -command "LWDAQ_tool_help Neuroplayer"
	pack $f.help -side left -expand yes

	set info(text) [LWDAQ_text_widget $w 100 10 1 1]
	
	# We have to bind keys to a window, not a frame, and in standalone mode our
	# $w is a frame in the root window, so we use the root window instead.
	if {$info(mode) == "Standalone"} {
		set b .
	} {
		set b $w
	}
	LWDAQ_bind_command_key $b Left {Neuroplayer_command Back}
	LWDAQ_bind_command_key $b Right {Neuroplayer_command Step}
	LWDAQ_bind_command_key $b greater {Neuroplayer_command Play}
	LWDAQ_bind_command_key $b Down \
		[list LWDAQ_post {Neuroplayer_jump Next_NDF 0}]
	LWDAQ_bind_command_key $b Up \
		[list LWDAQ_post {Neuroplayer_jump Previous_NDF 0}]
	LWDAQ_bind_command_key $b less \
		[list LWDAQ_post {Neuroplayer_jump Current_NDF 0}]
	$info(text) tag configure textbutton -background cyan
	$info(text) tag bind textbutton <Enter> {%W configure -cursor arrow} 
	$info(text) tag bind textbutton <Leave> {%W configure -cursor xterm} 

	return "SUCCESS"
}

#
# Neuroplayer_close closes the Neuroplayer and deletes its configuration and
# info arrays.
#
proc Neuroplayer_close {} {
	upvar #0 Neuroplayer_config config
	upvar #0 Neuroplayer_info info
	global LWDAQ_Info
	if {$info(gui) && [winfo exists $info(window)]} {
		destroy $info(window)
	}
	array unset config
	array unset info
	return "SUCCESS"
}

Neuroplayer_init 
Neuroplayer_open
Neuroplayer_fresh_graphs 1
	
return "SUCCESS"

----------Begin Help----------

http://www.opensourceinstruments.com/Electronics/A3018/Neuroplayer.html

----------End Help----------
