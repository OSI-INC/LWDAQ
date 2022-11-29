# Receiver Instrument, Long-Wire Data Acquisition Software (LWDAQ)
# Copyright (C) 2006-2022 Kevan Hashemi, Open Source Instruments Inc.
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


# Receiver.tcl defines the Receiver Instrument for LWDAQ, which until 13-SEP-21
# was called the Recorder Instrument, as defined in Recorder.tcl.


#
# LWDAQ_init_Receiver creates all elements of the Receiver Instrument's
# config and info arrays.
#
proc LWDAQ_init_Receiver {} {
	global LWDAQ_Info LWDAQ_Driver
	upvar #0 LWDAQ_info_Receiver info
	upvar #0 LWDAQ_config_Receiver config
	array unset config
	array unset info
	
	# The info array elements will not be displayed in the 
	# instrument window. The only info variables set in the 
	# LWDAQ_open_Instrument procedure are those which are checked
	# only when the instrument window is open.
	set info(name) "Receiver"
	set info(control) "Idle"
	set info(window) [string tolower .$info(name)]
	set info(text) $info(window).text
	set info(photo) [string tolower $info(name)\_photo]
	set info(counter) 0 
	set info(zoom) 1
	set info(daq_extended) 0
	set info(delete_old_images) 1
	set info(file_use_daq_bounds) 0
	set info(daq_image_width) 500
	set info(daq_image_height) 300
	set info(daq_buffer_width) 1000
	set info(daq_image_left) -1
	set info(daq_image_right) -1
	set info(daq_image_top) 0
	set info(daq_image_bottom) -1
	set info(daq_device_type) 3
	set info(daq_password) "no_password"
	set info(daq_fifo_av) 0
	set info(daq_fifo_unit) 512
	set info(verbose_description) "{Channel Number} \
		{Number of Samples Recorded} \
		{Average Value} \
		{Standard Deviation} "
	set info(timeout) 0
	set info(transmit_file_name) "./LWDAQ.tcl"
	set info(max_sample) 65535
	set info(min_sample) 0
	set info(display_range) [expr $info(max_sample) - $info(min_sample) + 1]
	set info(display_offset) $info(min_sample)
	set info(display_mode) "SP"
	set info(core_message_length) 4
	set info(upload_cmd) "00D0"
	set info(reset_cmd) "0081"
	set info(sel_ch_cmd) "84"
	set info(sel_all_cmd) "FF84"
	set info(sel_none_cmd) "0084"
	set info(all_sets_cmd) "1F04"
	set info(sleep_cmd) "0000"
	set info(config_size) 64
	set info(channel_activity) ""
	set info(activity_threshold) "10"
	set info(errors_for_stop) 10
	set info(clock_frequency) 128
	set info(max_block_reads) 100
	set info(min_messages_per_clock) 1
	set info(messages_per_clock) 1
	set info(min_clocks) 32
	set info(empty_fraction) 0.5
	set info(min_time_fetch) 0.2
	set info(max_time_fetch) 2.0
	set info(acquire_end_ms) 0
	set info(purge_duplicates) 1
	set info(payload_options) "0 2 16"
	set info(receiver_firmware) "?"
	set info(receiver_type) "?"
	set info(fv_range) 30
	set info(clock_id) 0
	set info(aux_num_keep) 64
	set info(show_errors) 0
	set info(show_error_extent) 20
	
	set info(buffer_image) "_receiver_buffer_image_"
	catch {lwdaq_image_destroy $info(buffer_image)}
	set info(scratch_image) "_receiver_scratch_image_"
	catch {lwdaq_image_destroy $info(scratch_image)}
		
	# All elements of the config array will be displayed in the
	# instrument window. No config array variables can be set in the
	# LWDAQ_open_Instrument procedure
	set config(image_source) "daq"
	set config(file_name) ./Images/$info(name)\*
	set config(memory_name) lwdaq_image_1
	set config(daq_ip_addr) 10.0.0.37
	set config(daq_driver_socket) 1
	set config(daq_mux_socket) 2
	set config(daq_channels) "*"
	set config(analysis_enable) 1
	set config(analysis_channels) "*"
	set config(intensify) none
	set config(verbose_result) 0
	set config(daq_num_clocks) 128
	set config(payload_length) 0

	return 1
}

#
# LWDAQ_analysis_Receiver applies receiver analysis to an image 
# in the lwdaq image list. By default, the routine uses the
# image $config(memory_name).
#
proc LWDAQ_analysis_Receiver {{image_name ""}} {
	upvar #0 LWDAQ_config_Receiver config
	upvar #0 LWDAQ_info_Receiver info

	# By default, we use the image whose name we passed in to this routine,
	# but if no such name was passed, we use the image named in the configuration
	# array.
	if {$image_name == ""} {set image_name $config(memory_name)}
	
	# We catch all errors in analysis so that we can report them in the instrument
	# text window. We don't want these errors to stop data acquisition.
	if {[catch {
	
		# We get the number of errors, the number of clock messages, and the total
		# number of messages. We also get the message index of the first clock message.
		# We will use the first clock index later.
		scan [lwdaq_receiver $image_name \
			"-payload $config(payload_length) clocks 0"] %d%d%d%d \
			num_errors num_clocks num_messages first_index
		if {$num_errors > 0} {
			LWDAQ_print $info(text) "WARNING: Encountered $num_errors errors\
				in data interval."
		}
		
		# We determine the display scale boundaries depending upon whether we have simple
		# plot, centered plot, or normalized plot.
		if {$info(display_mode) == "CP"} {
			set display_min [expr - $info(display_range) / 2 ]
			set display_max [expr + $info(display_range) / 2]
		} elseif {$info(display_mode) == "NP"} {
			set display_min 0
			set display_max 0
		} else {
			set display_min $info(display_offset)
			set display_max [expr $info(display_offset) + $info(display_range)]
		}
		
		# We compose a channel list from the analysis_channels string. The "*" character, 
		# if it appears anywhere in the analysis_channel list, will result in a "*" channel
		# number list. These channels are the ones we are going to plot and report on.
		set id_list ""
		foreach id $config(analysis_channels) {
			if {$id == "*"} {
				set id_list "*"
				break
			}
			if {![string is integer -strict $id]} {
				set id_list "*"
				LWDAQ_print $info(text) "WARNING: Bad channel number \"$id\"."
				break
			}
			lappend id_list $id
		}
		
		# We plot the selected channels in the image overlay. The result string
		# returned by this plot routine gives us the average and standard deviation
		# of each channel, and the number of messages present. For the clock 
		# channel, it gives the minimum and maximum timestamp values. This string is
		# the analysis result.
		set result [lwdaq_receiver $image_name \
			"-payload $config(payload_length) \
			plot $display_min $display_max \
			$info(display_mode) $id_list"]
			
		# We obtain a list of the channels with at least one message present
		# in the image, and the number of messages for each of these channels.
		set channels [lwdaq_receiver $image_name "-payload $config(payload_length) list"]
		if {![LWDAQ_is_error_result $channels]} {
			set ca ""
			foreach {c a} $channels {
				if {($a > $info(activity_threshold)) && ($c > 0)} {
					append ca "$c\:$a "
				}
			}
			set info(channel_activity) $ca
		} {
			error $channels
		}
	} error_result]} {return "ERROR: $error_result"}

	# Handle the case where we have no messages at all.
	if {$result == ""} {
		set result "0 0 0 0"
	}
	
	return $result
}

#
# LWDAQ_refresh_Receiver refreshes the display of the data, given new
# display settings.
#
proc LWDAQ_refresh_Receiver {} {
	upvar #0 LWDAQ_config_Receiver config
	upvar #0 LWDAQ_info_Receiver info
	if {[lwdaq_image_exists $config(memory_name)] != ""} {
		LWDAQ_analysis_Receiver $config(memory_name)
		lwdaq_draw $config(memory_name) $info(photo) \
			-intensify $config(intensify) -zoom $info(zoom)
	}
}

#
# LWDAQ_reset_Receiver resets and configures a data receiver. It resets the data
# receiver address and timestamp registers, thus emptying its message buffer and
# resetting its clock. It destroys the receiver instrument's data buffer and
# working image. It resets the acquired data time, a parameter we use to stop
# the Receiver Instrument attempting download too many messages from the data
# receiver. If the receiver is capable of saving a list of enabled channels that
# it should select for recording, the reset routine sends the daq_channels list
# to the receiver so as to select them.
#
proc LWDAQ_reset_Receiver {} {
	upvar #0 LWDAQ_config_Receiver config
	upvar #0 LWDAQ_info_Receiver info
	global LWDAQ_Driver LWDAQ_Info

	if {[catch {
		# Clear the firmware version to unknown.
		set info(receiver_firmware) "?"
		set info(receiver_type) "?"
		
		# Start the reset and configure.
		LWDAQ_print -nonewline $info(text) "Resetting receiver, "
		LWDAQ_update

		# Open a socket and log in to the driver.
		set sock [LWDAQ_socket_open $config(daq_ip_addr)]
		LWDAQ_login $sock $info(daq_password)
		
		# Select the data receiver.
		LWDAQ_set_device_type $sock $info(daq_device_type)
		LWDAQ_set_driver_mux $sock $config(daq_driver_socket) $config(daq_mux_socket)
		
		# Reset the receiver message buffer and message detectors.
		LWDAQ_transmit_command_hex $sock $info(reset_cmd)
		LWDAQ_wait_for_driver $sock
		
		# Read a few clock messages from the receiver and try to identify
		# what type of receiver it is, and determine its message payload.
		LWDAQ_print -nonewline $info(text) "detecting type, "
		LWDAQ_update
		
		# Download a small block of messages from the receiver.
		LWDAQ_transmit_command_hex $sock $info(upload_cmd)
		LWDAQ_set_data_addr $sock 0
		LWDAQ_set_repeat_counter $sock [expr $info(config_size) - 1]		
		LWDAQ_execute_job $sock $LWDAQ_Driver(read_job)
		LWDAQ_wait_for_driver $sock
		set data [LWDAQ_ram_read $sock 0 $info(config_size)]
		
		# Reset the data receiver again.
		LWDAQ_transmit_command_hex $sock $info(reset_cmd)
		LWDAQ_wait_for_driver $sock		

		# Try to determine the receiver version from the message block.
		set img [lwdaq_image_create -width $info(config_size) \
			-height $info(config_size)]
		lwdaq_data_manipulate $img clear
		lwdaq_data_manipulate $img write 0 $data
		set info(receiver_firmware) "?"
		set info(receiver_type) "?"
		foreach payload $info(payload_options) {
			set bb [lwdaq_receiver $img "-payload $payload print 0 1"]
			if {[regexp {Version ([0-9]+)} $bb match fv]} {
				set info(receiver_firmware) [expr $fv % $info(fv_range)]
				switch [expr $fv / $info(fv_range)] {
					0 {
						set info(receiver_type) "A3018"
						set config(payload_length) 0
						set info(daq_fifo_av) 0
						set channel_select_available 0
						set send_all_sets_cmd 0
						set info(purge_duplicates) 0
					}
					1 {
						set info(receiver_type) "A3027"
						set config(payload_length) 0
						set info(daq_fifo_av) 0
						set channel_select_available 0
						set send_all_sets_cmd 1
						set info(purge_duplicates) 1
					}
					2 {
						set info(receiver_type) "A3032"
						set config(payload_length) 16
						set info(daq_fifo_av) 0
						set channel_select_available 0
						set send_all_sets_cmd 0
						set info(purge_duplicates) 0
					}
					3 {
						set info(receiver_type) "A3038"
						set config(payload_length) 16
						set info(daq_fifo_av) 1
						set channel_select_available 1
						set send_all_sets_cmd 0
						set info(purge_duplicates) 0
					}
					4  {
						set info(receiver_type) "A3042"
						set config(payload_length) 2
						set info(daq_fifo_av) 1
						set channel_select_available 1
						set send_all_sets_cmd 0
						set info(purge_duplicates) 0
					}
					default {
						set info(receiver_type) "?"
						set config(payload_length) 0
						set info(daq_fifo_av) 0
						set channel_select_available 0
						set send_all_sets_cmd 0
						set info(purge_duplicates) 0
					}					
				}
				break
			}
		}
		lwdaq_image_destroy $img
		if {$info(receiver_type) == "?"} {
			error "Failed to identify data receiver."
		}
		
		# For backward-compatibility with Octal Data Receivers (ODR, assembly
		# number A3027) with firmware versions 10, 11, and 12, we include this
		# command that configures an A3027 to receive from all channels rather
		# than only channels 1-14.
		if {$send_all_sets_cmd} {
			LWDAQ_transmit_command_hex $sock $info(all_sets_cmd)
		}
	
		# Provided that channel selection is available with this data receiver,
		# send a list of channels to select for recording. If the list is simply
		# a wildcard, we configure the receiver to record all channels. If the
		# list contains only integers, we first instruct the receiver to accept
		# no channels, then to accept the channels listed. 
		if {$channel_select_available} {
			if {[string trim $config(daq_channels)] == "*"} {
				LWDAQ_print -nonewline $info(text) "selecting all channels, "
				LWDAQ_transmit_command_hex $sock $info(sel_all_cmd)
			} {
				set cmd_list [list $info(sel_none_cmd)]
				set ch_list [list]
				foreach ch $config(daq_channels) {
					if {[string is integer -strict $ch] && ($ch > 0) && ($ch < 255)} {
						lappend cmd_list "[format %02X $ch]$info(sel_ch_cmd)"
						lappend ch_list $ch
					} {
						error "Invalid channel \"$ch\". "
					}
				}
				if {[llength $ch_list] > 0} {
					LWDAQ_print -nonewline $info(text) "selecting channels $ch_list, "
					LWDAQ_transmit_command_hex $sock $info(sel_none_cmd)
					foreach cmd $cmd_list {
						LWDAQ_transmit_command_hex $sock $cmd
					}
				}
			}
		}
			
		# Sometimes we accidentally send a receiver reset and configure to the wrong
		# device. Receivers ignore the sleep command, so we send a sleep command now,
		# hoping that whatever device we may have activated with the reset will now
		# go to sleep.
		LWDAQ_sleep $sock
			
		# Wait for completion and close socket.
		LWDAQ_wait_for_driver $sock
		LWDAQ_socket_close $sock

		# Destroy the buffer and memory imagest.
		lwdaq_image_destroy $info(buffer_image)
		lwdaq_image_destroy $config(memory_name)
		
		# Reset the acquired data time. We will use this end time to avoid 
		# over-drawing from the data receiver. When we ask for more data than 
		# is currently available in the data receiver, we occupy the driver 
		# until the data becomes available, which stops other clients using 
		# the driver to download their own data.
		set info(acquire_end_ms) [clock milliseconds]
		
		# We reset the number of messages per clock.
		set info(messages_per_clock) $info(min_messages_per_clock)

		# Notification to user.		
		LWDAQ_print $info(text) "done."
	} error_result]} { 
		if {[info exists sock]} {LWDAQ_socket_close $sock}
		incr LWDAQ_Info(num_daq_errors)
		LWDAQ_print $info(text) "\nERROR: $error_result" red
		return "ERROR: $error_result"
	}
	
	return 1
}

#
# LWDAQ_controls_Receiver creates secial controls for the Receiver instrument.
#
proc LWDAQ_controls_Receiver {} {
	global LWDAQ_Info LWDAQ_Driver
	upvar #0 LWDAQ_config_Receiver config
	upvar #0 LWDAQ_info_Receiver info

	set w $info(window)
	if {![winfo exists $w]} {return 0}

	set g $w.scale
	frame $g
	pack $g -side top -fill x

	foreach {label_name element_name} { \
			"Offset:" {display_offset} \
			"Range:" {display_range} } {
		label $g.l$element_name -text $label_name 
		entry $g.e$element_name -textvariable LWDAQ_info_Receiver($element_name) \
			-relief sunken -bd 1 -width 6
		pack $g.l$element_name $g.e$element_name -side left -expand 1
		bind $g.e$element_name <Return> LWDAQ_refresh_Receiver
	}

	foreach a "SP CP NP" {
		set b [string tolower $a]
		radiobutton $g.$b -variable LWDAQ_info_Receiver(display_mode) \
			-text $a -value $a
		pack $g.$b -side left -expand 0
	}
	
	button $g.reset -text "Reset and Configure" -command "LWDAQ_post LWDAQ_reset_Receiver"
	pack $g.reset -side left -expand 1

	label $g.lrv -text "Receiver:" 
	label $g.erv -textvariable LWDAQ_info_Receiver(receiver_type) -width 5
	pack $g.lrv $g.erv -side left -expand 1
	
	label $g.lfv -text "Firmware:" 
	label $g.efv -textvariable LWDAQ_info_Receiver(receiver_firmware) -width 3
	pack $g.lfv $g.efv -side left -expand 1

	set g $w.channels
	frame $g -border 2
	pack $g -side top -fill x

	label $g.l -text "Activity (id:qty) "
	pack $g.l -side left
	label $g.c -textvariable LWDAQ_info_Receiver(channel_activity) \
		-relief sunken -anchor w -width 90
	pack $g.c -side left -expand yes
}

#
# LWDAQ_daq_Receiver reads data from a data device. It fetches the data in
# blocks, and opens and closes a socket to the driver for each block. Although
# opening and closing sockets introduces a delay into the data acquisition, it
# allows another LWDAQ process to use the same LWDAQ driver in parallel, as may
# be required when we have two data receivers running on the same LWDAQ Driver,
# or a single data receiver and two animal location trackers, or a spectrometer.
# Some receivers provide a register that gives the number of messages available
# for download in its memory. But no receiver built before 2021 provides such a
# register, so there is no way to determine the number of messages available for
# download. For such receivers, the LWDAQ_daq_Receiver routine estimates the
# number of messages available using aquire_end_ms, which it updates after every
# block download to be equal to or greater than the millisecond absolute time of
# the last clock message in the block. By subtracting the end time from the
# current time, the routine obtains an estimate of the length of time spanned by
# the messages available in the data receiver. The routine also maintains an
# estimate of the number of messages per clock message in the recording. It
# multiplies this ratio by the available time and the clock frequency to get its
# estimate of the number of messages avaialable in the data
# receiver. 
#
proc LWDAQ_daq_Receiver {} {
	global LWDAQ_Driver LWDAQ_Info
	upvar #0 LWDAQ_info_Receiver info
	upvar #0 LWDAQ_config_Receiver config

	# If they don't exist, create the buffer and scratch images.
	if {[lwdaq_image_exists $info(buffer_image)] == ""} {
		lwdaq_image_create \
			-width $info(daq_buffer_width) \
			-height $info(daq_buffer_width) \
			-name $info(buffer_image)
	}
	if {[lwdaq_image_exists $info(scratch_image)] == ""} {
		lwdaq_image_create \
			-width $info(daq_buffer_width) \
			-height $info(daq_buffer_width) \
			-name $info(scratch_image)
	}
		
	# Save the value of daq_num_clocks in case the user changes it 
	# during acquisition. Calculate the message length.
	set daq_num_clocks $config(daq_num_clocks)
	if {![string is integer -strict $daq_num_clocks]} {
		return "ERROR: Invalid number of clocks \"$daq_num_clocks\"."
	}
	set message_length [expr $info(core_message_length) + $config(payload_length)]
	
	# Check the buffer contents. If we have just reset the data receiver, this 
	# buffer will be empty, and no error will be caused by having the wrong
	# payload length.
	scan [lwdaq_receiver $info(buffer_image) \
		"-payload $config(payload_length) clocks 0 $daq_num_clocks"] %d%d%d%d%d \
		num_errors num_clocks num_messages start_index end_index
		
	if {[catch {
		# Set the block counter, which counts how many times we download a 
		# block of messages from the receiver.
		set block_counter 0
		
		# We download data until we have more than daq_num_clocks clock messages.
		# If the buffer already contains enough messages, we are already done without
		# any further download.
		while {$num_clocks <= $daq_num_clocks} {

			# Open a socket to driver and log in.
			set sock [LWDAQ_socket_open $config(daq_ip_addr)]
			LWDAQ_login $sock $info(daq_password)
	
			# Select the data receiver for communication within the LWDAQ.
			LWDAQ_set_device_type $sock $info(daq_device_type)
			LWDAQ_set_driver_mux $sock $config(daq_driver_socket) $config(daq_mux_socket)
			
			# Configure the data receiver for data download.
			LWDAQ_transmit_command_hex $sock $info(upload_cmd)

			# If we have a fifo block counter, read the number of bytes
			# available.
			if {$info(daq_fifo_av)} {
				set ac [expr [LWDAQ_byte_read $sock $LWDAQ_Driver(fifo_av_addr)] & 0xFF]
				set block_length [expr \
					($info(daq_fifo_unit) / $message_length) * $message_length * $ac \
					+ round($info(min_time_fetch) * $info(clock_frequency)) \
						* $message_length]
			} 
			
			
			# If we don't have a block counter, estimate the number of seconds of
			# data available in the data receiver. If we think there are few or
			# no seconds of data, we download a minimum duration. This minimum
			# download, combined with the acquire lag we introduce when we
			# update our acquire time, allows us to overcome a systematic error
			# in our acquire time estimate, in which we think we have advanced
			# farther in the data receiver buffer than is actually the case.
			if {!$info(daq_fifo_av)} {
				set time_fetch [expr 0.001 * ([clock milliseconds] - $info(acquire_end_ms))]
				if {$time_fetch < $info(min_time_fetch)} {
					set time_fetch $info(min_time_fetch)
				}
				if {$time_fetch > $info(max_time_fetch)} {
					set time_fetch $info(max_time_fetch)
				}
			
				# Calculate the length of the block of data we are going to attempt
				# to download from the data receiver.			
				set block_length [expr $message_length \
					* round( $time_fetch * $info(clock_frequency) ) \
					* $info(messages_per_clock)]
			}
				
			# We are going to measure how long it takes to transfer the block 
			# of data from the receiver to the driver. We must first wait for
			# the driver to acknowledge that it has accepted our socket request,
			# or else our transfer time will include the time it takes for the
			# driver to finish jobs with other clients and start working on our
			# connection.
			LWDAQ_wait_for_driver $sock
			set block_start_ms [clock milliseconds]

			# Transfer bytes from receiver to the driver.
			LWDAQ_set_data_addr $sock 0
			LWDAQ_set_repeat_counter $sock [expr $block_length - 1]			
			LWDAQ_execute_job $sock $LWDAQ_Driver(read_job)
			
			# Wait for the driver to complete the transfer. If we have asked
			# for too much data, we will get a TCPIP timeout. The socket will
			# be closed either by the driver or by the LWDAQ process, whichever
			# has the shortest timeout. Once a timeout has occurred, the socket
			# will almost certainly be closed, but we make sure it is closed 
			# so we can open a new one to the same driver. Between closing one 
			# socket and opening another, the driver could serve any number of
			# other clients, so there will be no way to recover the data in its 
			# memory. We must open another socket, reset the data receiver, close 
			# the socket, and break out of data acquisition. This error occurs
			# most easily when we disconnect the source of messages from the
			# data receiver, such as when we unplug a single antenna that is
			# receiving from a dozen channels.
			if {[catch {LWDAQ_wait_for_driver $sock} read_error]} {
				if {[info exists sock]} {LWDAQ_socket_close $sock}
				LWDAQ_print $info(text) "WARNING: Timeout awaiting transfer\
					from receiver to driver. Resetting receiver."
				LWDAQ_update
				set sock [LWDAQ_socket_open $config(daq_ip_addr)]
				LWDAQ_login $sock $info(daq_password)
				LWDAQ_set_driver_mux $sock $config(daq_driver_socket) $config(daq_mux_socket)
				LWDAQ_transmit_command_hex $sock $info(reset_cmd)
				LWDAQ_wait_for_driver $sock
				LWDAQ_socket_close $sock
				set start_index 0
				set end_index [expr $num_messages - 1]
				set info(messages_per_clock) $info(min_messages_per_clock)
				break
			}
			
			# Calculate the block transfer time. If the data was waiting in the
			# receiver, it will transfer at roughly 1.4 MBytes/s to the driver
			# memory for both the old and new drivers. If the driver has to wait
			# for the data to arrive from transmitters and the receiver clock,
			# the transfer takes much longer. 
			set block_ms [expr [clock milliseconds] - $block_start_ms]
			if {$block_ms < 1} {set block_ms 1}
			
			# Download data from the driver into a local byte array.
			set data [LWDAQ_ram_read $sock 0 $block_length]
						
			# Put the data in the scratch image. 
			lwdaq_data_manipulate $info(scratch_image) clear
			lwdaq_data_manipulate $info(scratch_image) write 0 $data
			
			# Check the block for errors and count the number of clocks and messages
			# it containes.
			scan [lwdaq_receiver $info(scratch_image) \
				"-payload $config(payload_length) clocks"] %d%d%d \
				num_errors num_new_clocks num_new_messages

			# We use the show_errors and show_error_extent parameters to control
			# the display of raw message blocks that contain errors.
			if {($num_errors > 0) && $info(show_errors)} {
				set result [lwdaq_receiver $info(scratch_image) \
					"-payload $config(payload_length) print 0 1"]
				if {[regexp {index=([0-9]+)} $result match index]} {
					set result [lwdaq_receiver $info(scratch_image) \
						"-payload $config(payload_length) print \
						[expr $index-$info(show_error_extent)] \
						[expr $index+$info(show_error_extent)]"]
					LWDAQ_print $info(text) $result purple
				} {
					LWDAQ_print $info(text) $result purple
				}
			}
				
			# If we see errors in the new data, we check to see if this is
			# because we are using the wrong payload length. If so, we throw
			# away the data we just downloaded, reset the data receiver, close
			# the socket, and abandon this acquisition. If not, we throw away
			# the data, reset the receiver, close the socket, and keep trying.
			# We throw away the data and reset the receiver because all
			# algorithms for trying to recover from data errors without
			# resetting the receiver are vulnerable to rare error sources that
			# cause disastrous loss of data. By resetting the data receiver, we
			# make sure that it is in a known state for our next download. But
			# we lose continuity of clock messages within the data buffer.
			if {$num_errors > 0} {
				foreach pl $info(payload_options) {
					scan [lwdaq_receiver $info(scratch_image) \
						"-payload $pl clocks"] %d%d%d ne nc nm
					if {$ne == 0} {break}
				}
				
				if {$ne == 0} {
					LWDAQ_print $info(text) \
						"WARNING: Suspect payload length $config(payload_length)\
							is wrong. Resetting data receiver and trying again."
				} {
					LWDAQ_print $info(text) \
						"WARNING: Received corrupted data. Resetting data receiver\
							and trying again."
				}

				LWDAQ_transmit_command_hex $sock $info(reset_cmd)
				LWDAQ_wait_for_driver $sock
				LWDAQ_socket_close $sock
				continue
			}
			
			# If purge_duplicates is set, we remove duplicate messages from the 
			# block before we do any processing.
			if {$info(purge_duplicates)} {
				set num_unique_messages \
					[lwdaq_receiver $info(scratch_image) \
						"-payload $config(payload_length) purge"]
				set data [lwdaq_data_manipulate $info(scratch_image) read \
					0 [expr $num_unique_messages * $message_length]]
				set num_new_messages $num_unique_messages
			}

			# Adjust the number of messages per clock we expect in our next
			# download, making sure we count the duplicate messages that may
			# have existed before we purged the data.
			set saved_messages_per_clock $info(messages_per_clock)
			if {$num_new_clocks > 1} {
				set info(messages_per_clock) [expr \
					round( 1.0 * $block_length / $message_length / $num_new_clocks )]
			}
			if {$info(messages_per_clock) < $info(min_messages_per_clock)} {
				set info(messages_per_clock) $info(min_messages_per_clock)
			}
			if {$info(messages_per_clock) > 2 * $saved_messages_per_clock} {
				set info(messages_per_clock) [expr 2 * $saved_messages_per_clock]
			}
			
			# Adjust the acquire time using the number of new clock messages and
			# the block transfer time. If the block transfer time was comparable
			# to the interval time, we can assume the data receiver buffer is
			# empty, which means the acquire time is equal to the current time.
			# Otherwise, we add to the acquire time the time spanned by the
			# messages in the block we downloaded, which we calculate from the
			# number of clocks it contains and the clock frequency. If the clock
			# on the data receiver is faster than the clock in our computer, we
			# will download one second of data and think it spans more than one
			# second. Our acquire time will be wrong: we think we have
			# downloaded all the messages in the data receiver up to the acquire
			# time, but we have failed to do so. As hours go by, we lag farther
			# and farther behind the data in the data receiver until its buffer
			# overflows. The acquire_lag is the number of clocks we subtract
			# from the numer we have just acquired, so that our estimate of the
			# time spanned by the data we download will always be lower than the
			# actual time it spans. Occasionally we will reach the end of the
			# buffer on the data receiver because it occurs earlier than our
			# acquire time suggests. At that point, we will reset the acquire
			# time to the current time because we detect the empty buffer with
			# the block transfer time.
			if {!$info(daq_fifo_av)} {
				set clock_ms [clock milliseconds]
				set acquired_ms [expr round( \
					1000.0 * ($num_new_clocks + 1) / $info(clock_frequency) )]
				if {$block_ms > 1000.0 * $info(empty_fraction) * $time_fetch} {
					set info(acquire_end_ms) $clock_ms
					set lag_ms 0
					# Un-comment to report when we detect an empty receiver buffer.
					# LWDAQ_print $info(text) "Empty buffer detected." purple

				} {
					set info(acquire_end_ms) [expr $info(acquire_end_ms) + $acquired_ms]
					if {$info(acquire_end_ms) > $clock_ms} {
						set info(acquire_end_ms) $clock_ms
					}
					set lag_ms [expr $clock_ms - $info(acquire_end_ms)]
				}	
				# LWDAQ_print $info(text) "$time_fetch $acquired_ms $lag_ms $block_ms" orange
			}


			# Check that we can fit the existing data in the buffer image. If not,
			# discard the data instead of adding it to the buffer, stop this 
			# data acquisition, and return the entire buffer as a source
			# of data.
			if {($num_new_messages + $num_messages) * $message_length > \
					[expr $info(daq_buffer_width) * ($info(daq_buffer_width) - 1)]} {
				LWDAQ_print $info(text) "ERROR: Buffer overflow,\
					abandoning this acquisition."
				LWDAQ_socket_close $sock
				set start_index 0
				set end_index [expr $num_messages - 1]
				break
			}
			
			# Append the new messages to buffer image. If we purged the data,
			# the purged data has already been copied back into the data array.
			lwdaq_data_manipulate $info(buffer_image) write \
				[expr $num_messages * $message_length] $data

			# Check the new buffer contents.
			scan [lwdaq_receiver $info(buffer_image) \
				"-payload $config(payload_length) clocks 0 $daq_num_clocks"] %d%d%d%d%d \
				num_errors num_clocks num_messages start_index end_index
			
			# If we have too many errors in the message buffer, we reset the
			# data receiver, wait for the driver to respond, close the socket,
			# and break out of the acquisition loop, returning the entire
			# message buffer as data.
			if {$num_errors > $info(errors_for_stop)} {
				LWDAQ_print $info(text) \
					"ERROR: Severely corrupted data.\
						resetting data receiver and\
						abandoning this acquisition."
				LWDAQ_transmit_command_hex $sock $info(reset_cmd)
				LWDAQ_wake $sock
				LWDAQ_wait_for_driver $sock
				LWDAQ_socket_close $sock
				set start_index 0
				set end_index [expr $num_messages - 1]
				set info(messages_per_clock) $info(min_messages_per_clock)
				break
			}

			# Check the block counter to see if we have made too many attempts
			# to get our data. 
			incr block_counter
			if {$block_counter > $info(max_block_reads)} {
				LWDAQ_print $info(text) \
					"ERROR: Failed to accumulate clock messages,\
						resetting data receiver and\
						abandoning this acquisition."
				LWDAQ_transmit_command_hex $sock $info(reset_cmd)
				LWDAQ_wake $sock
				LWDAQ_wait_for_driver $sock
				LWDAQ_socket_close $sock
				set start_index 0
				set end_index [expr $num_messages - 1]
				set info(messages_per_clock) $info(min_messages_per_clock)
				break
			}
			
			# Disable data upload from data receiver and close socket.
			LWDAQ_wake $sock
			LWDAQ_wait_for_driver $sock
			LWDAQ_socket_close $sock
		}
	} error_result]} { 
		# To get here, we have encountered a TCPIP communication error other than
		# a timeout waiting for the data receiver to supply data. We don't attempt
		# to reset the data receiver, but we reset the block size.
		if {[info exists sock]} {LWDAQ_socket_close $sock}
		set info(messages_per_clock) $info(min_messages_per_clock)
		return "ERROR: $error_result"
	}
	
	# Create the new data image, storing extra data in the Receiver
	# Instruments's buffer image.
	set config(memory_name) [lwdaq_image_create \
		-width $info(daq_image_width) \
		-height $info(daq_image_height) \
		-left $info(daq_image_left) \
		-right $info(daq_image_right) \
		-top $info(daq_image_top) \
		-bottom $info(daq_image_bottom) \
		-name "$info(name)\_$info(counter)"]
	
	# Extract data from the buffer.
	if {($start_index <= $end_index) && ($start_index >= 0) && ($end_index > 0)} {
		set start_addr [expr $message_length * $start_index]
		set end_addr [expr $message_length * $end_index]
		set data [lwdaq_data_manipulate $info(buffer_image) read \
			 $start_addr [expr $end_addr - $start_addr] ]
		lwdaq_data_manipulate $info(buffer_image) shift $end_addr
	} {
		set data ""
		lwdaq_data_manipulate $info(buffer_image) clear
	}
	
	# Write data into the new data image, but check that the data will fit.
	set max_length [expr $info(daq_image_width) * ($info(daq_image_height) - 1)]
	if {[string length $data] > $max_length} {
		LWDAQ_print $info(text) "WARNING: Discarding\
			[expr [string length $data] - $max_length]\
			bytes to fit data image."
		set data [string range $data 0 [expr $max_length - 1]]
	}
	lwdaq_data_manipulate $config(memory_name) write 0 $data
	
	return $config(memory_name) 
} 

