# Long-Wire Data Acquisition Software (LWDAQ)
# Copyright (C) 2009-2017 Kevan Hashemi, Brandeis University
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
# Dosimeter.tcl defines the Dosimeter instrument.
#

#
# LWDAQ_init_Dosimeter creates all elements of the Dosimeter instrument's
# config and info arrays.
#
proc LWDAQ_init_Dosimeter {} {
	global LWDAQ_Info LWDAQ_Driver
	upvar #0 LWDAQ_info_Dosimeter info
	upvar #0 LWDAQ_config_Dosimeter config
	array unset config
	array unset info

	# The info array elements will not be displayed in the 
	# instrument window. The only info variables set in the 
	# LWDAQ_open_Instrument procedure are those which are checked
	# only when the instrument window is open.
	set info(name) "Dosimeter"
	set info(control) "Idle"
	set info(window) [string tolower .$info(name)]
	set info(text) $info(window).text
	set info(photo) [string tolower $info(name)\_photo]
	set info(counter) 0 
	set info(zoom) 1
	set info(analysis_show_timing) 0
	set info(analysis_show_pixels) 0
	set info(analysis_include_ij) 0
	set info(daq_extended) 0
	set info(daq_device_type) 2
	set info(daq_source_device_type) 1
	set info(file_use_daq_bounds) 0
	set info(daq_image_width) 344
	set info(daq_image_height) 244
	set info(daq_image_left) 30
	set info(daq_image_right) [expr $info(daq_image_width) - 10]
	set info(daq_image_top) 11
	set info(daq_image_bottom) [expr $info(daq_image_height) - 10]
	set info(daq_wake_ms) 0
	set info(file_try_header) 1
	set info(use_image_area) 0
	set info(analysis_pixel_size_um) 10
	set info(daq_password) "no_password"
	set info(delete_old_images) 1
	set info(verbose_description) " \
			{Dark Current (counts/row)} \
			{Charge Density (counts/pixel)} \
			{Standard Deviation of Intensity (counts)} \
			{Threshold Intensity (counts)} \
			{Number of Valid Hits} \
			{Hit Data} {Hit Data} {Hit Data} {Hit Data} {Hit Data} \
			{Hit Data} {Hit Data} {Hit Data} {Hit Data} {Hit Data}"
	
	# All elements of the config array will be displayed in the
	# instrument window. No config array variables can be set in the
	# LWDAQ_open_Instrument procedure
	set config(image_source) "daq"
	set config(file_name) ./Images/$info(name)\*
	set config(memory_name) $info(name)\_0
	set config(daq_ip_addr) "129.64.37.90"
	set config(daq_driver_socket) 5
	set config(daq_mux_socket) 1
	set config(daq_device_element) 2
	set config(daq_source_driver_socket) 1
	set config(daq_source_mux_socket) 1
	set config(daq_source_device_element) 1
	set config(daq_flash_seconds) 0.0
	set config(daq_activate_hex) "0000"
	set config(daq_exposure_seconds) 0.1
	set config(daq_subtract_background) 0
	set config(intensify) exact
	set config(analysis_threshold) "5 $ 2 <"
	set config(analysis_num_hits) "*"
	set config(analysis_enable) "1"
	set config(verbose_result) "0"

	return ""
}		

#
# LWDAQ_analysis_Dosimeter applies Dosimeter analysis to an image in the lwdaq
# image list. By default, the routine uses the image named $config(memory_name).
# It calculates the vertical slope of intensity in cnt/row first. The analysis
# working with the original image when analyis_enable=1, but switches to using
# the image after subtraction of background gradient when analysis_enable>=2.
# With analysis_enable=2 the image in memory remains the same, and analysis
# operates on a copy of the original. With analysis_enable=3, the analysis
# replaces the original image with the gradient-subtracted image. The analysis
# calculates charge density in cnt/px next. The charge density is combined
# intensity of bright hits divided by the number of pixels in the analysis
# bounds of the image. A hit is a spot that satisfies the analysis_threshold
# string. The threshold string specifies a minumum intensity for pixels in a
# hit. The string "20 & 2 <" specifies a minimum intensity twenty counts above
# background, and indicates that the background should be the average intensity
# of the image. The same string sets a limit of two pixels in any valid hit.
# Following the charge density is the standard deviation of intensity, the value
# of the threshold intensity, and the number of hits found in the image. Each
# hit is represented by its total brightness above background, and if
# analysis_include_ij=1, the row and column number of the pixel closest to the
# optical center of the hit. Following these values, the analysis will list one
# or more bright hits in order of descending brightness. With
# analysis_num_hits="*", all hits found will be listed. With
# analysis_num_hits="10", ten hits will be listed. If only three hits exist, the
# remaining seven hits will be represented by brightness "-1" and position "0
# 0".
#
proc LWDAQ_analysis_Dosimeter {{image_name ""}} {
	upvar #0 LWDAQ_config_Dosimeter config
	upvar #0 LWDAQ_info_Dosimeter info
	if {$image_name == ""} {set image_name $config(memory_name)}

	# If analysis_enable is greater than one, subtract the average gradient 
	# of intensity from the image before analyzing.
	if {$config(analysis_enable) >= 2} {
		set subtract_gradient 1
	} {
		set subtract_gradient 0
	}
	
	# Interpret the "*" character in analysis_num_hits.
	if {$config(analysis_num_hits) == "*"} {
		set num_hits "-1"
	} {
		if {![string is integer -strict $config(analysis_num_hits)]} {
			LWDAQ_print $info(text) "WARNING: Invalid number of hits\
				\"$config(analysis_num_hits)\"."
			set num_hits "0"
		} {
			set num_hits $config(analysis_num_hits)
		}
	}

	# Obtain the dosimeter analysis result from the lwdaq library routine.
	set result [lwdaq_dosimeter $image_name \
		-show_timing $info(analysis_show_timing) \
		-show_pixels $info(analysis_show_pixels) \
		-num_hits $num_hits \
		-threshold $config(analysis_threshold) \
		-subtract_gradient $subtract_gradient \
		-include_ij $info(analysis_include_ij) \
		-color 1]

	# If analysis_enable is 3, subtract the gradient from the image.
	if {$config(analysis_enable) == 3} {
		set modified_image [lwdaq_image_manipulate $image_name subtract_gradient]
		lwdaq_image_manipulate $modified_image transfer_overlay $image_name
		lwdaq_image_destroy $image_name
		lwdaq_image_manipulate $modified_image none -name $image_name
	} 

	if {$result == ""} {set result "ERROR: $info(name) analysis failed."}
	return $result
}

#
# LWDAQ_infobuttons_Dosimeter creates buttons that allow us to configure
# the Dosimeter for any of the available image sensors.
#
proc LWDAQ_infobuttons_Dosimeter {f} {
	global LWDAQ_Driver

	foreach a "TC255 TC237 KAF0400 KAF0261 ICX424 ICX424Q" {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_set_image_sensor $a Dosimeter"
		pack $f.$b -side left -expand yes
	}
	return ""
}


#
# LWDAQ_daq_Dosimeter captures an image from the LWDAQ electronics and places
# the image in the lwdaq image list. 
#
proc LWDAQ_daq_Dosimeter {} {
	global LWDAQ_Info LWDAQ_Driver
	upvar #0 LWDAQ_info_Dosimeter info
	upvar #0 LWDAQ_config_Dosimeter config

	set image_size [expr $info(daq_image_width) * $info(daq_image_height)]

	if {($config(daq_flash_seconds) > 0) && ($config(daq_activate_hex) != "0000")} {
		LWDAQ_print $info(text) "WARNING: Flashing and activation are both enabled."
	}

	if {[catch {
		# Connect to the driver. We assume the dosimeter and radiation source are
		# connected to the same driver.
		set sock [LWDAQ_socket_open $config(daq_ip_addr)]
		LWDAQ_login $sock $info(daq_password)
		
		# Select the Dosimeter sensor and wake it up.
		LWDAQ_set_driver_mux $sock $config(daq_driver_socket) $config(daq_mux_socket)
		LWDAQ_set_device_type $sock $info(daq_device_type)
		LWDAQ_set_device_element $sock $config(daq_device_element)
		LWDAQ_wake $sock
		if {$info(daq_wake_ms) > 0} {
			LWDAQ_delay_seconds $sock [expr $info(daq_wake_ms) * 0.001]
		}

		# Clear the image sensor and put it in its exposure state.		
		LWDAQ_image_sensor_clear $sock $info(daq_device_type)

		# If we have a source of radiation that can be flashed quickly by
		# the driver with a flash job, daq_flash_seconds will be greater than
		# zero, and will indicate the time for which the source must be turned
		# on.
		if {$config(daq_flash_seconds) > 0} {
			LWDAQ_set_driver_mux $sock $config(daq_source_driver_socket) \
				$config(daq_source_mux_socket)
			LWDAQ_set_device_type $sock $info(daq_source_device_type)
			LWDAQ_set_device_element $sock $config(daq_source_device_element)
			LWDAQ_flash_seconds $sock $config(daq_flash_seconds)
		}
		
		# If we have a source of radiation that can be turned on with a single
		# device command, we send that command now. The subsequent delay introduced
		# by daq_exposure_seconds should be adequate to include the length of 
		# the radiation burst.
		if {$config(daq_activate_hex) != "0000"} {
			LWDAQ_set_driver_mux $sock $config(daq_source_driver_socket) \
				$config(daq_source_mux_socket)
			LWDAQ_transmit_command_hex $sock $config(daq_activate_hex)		
		}
		
		# Expose the sensor for the exposure time.
		LWDAQ_delay_seconds $sock $config(daq_exposure_seconds)
		
		# Select the image sensor.
		LWDAQ_set_driver_mux $sock $config(daq_driver_socket) \
			$config(daq_mux_socket)
		LWDAQ_set_device_type $sock $info(daq_device_type)
		LWDAQ_set_device_element $sock $config(daq_device_element)

		# Prepare image sensor for readout.
		if {($info(daq_device_type) == $LWDAQ_Driver(TC255_device)) \
			|| ($info(daq_device_type) == $LWDAQ_Driver(TC237_device))} {
			if {$info(use_image_area)} {
				# Transfer the image area charge into the storage area.
				LWDAQ_execute_job $sock $LWDAQ_Driver(alt_move_job)
			}
		}
		if {($info(daq_device_type) == $LWDAQ_Driver(ICX424_device)) \
			|| ($info(daq_device_type) == $LWDAQ_Driver(ICX424Q_device))} {
			if {$info(use_image_area)} {
				# Transfer the image out of the image area and into the
				# transfer columns by applying read pulse to V2 and V3.
				# We keep V1 lo to maintain pixel charge separation in 
				# the vertical transfer columns.
				LWDAQ_transmit_command_hex $sock 0099
				LWDAQ_transmit_command_hex $sock 0098
			}

			# Drive V2 hi, V1 and V3 lo so as to collect all pixel
			# charges under the V2 clock.
			LWDAQ_transmit_command_hex $sock 0088	
		}

		# Read out the pixels and store in driver memory.
		LWDAQ_set_data_addr $sock 0
		LWDAQ_execute_job $sock $LWDAQ_Driver(read_job)
		
		# Transfer the image from the driver to the data acquisition computer.
		set image_contents [LWDAQ_ram_read $sock 0 $image_size]

		# If we want to subtract a background, we obtain the 
		# background image and subtract it.
		if {$config(daq_subtract_background)} {
			LWDAQ_image_sensor_clear $sock $info(daq_device_type)

			if {$config(daq_flash_seconds) > 0} {
				LWDAQ_delay_seconds $sock $config(daq_flash_seconds)
			}
			LWDAQ_delay_seconds $sock $config(daq_exposure_seconds)

			if {($info(daq_device_type) == $LWDAQ_Driver(TC255_device)) \
				|| ($info(daq_device_type) == $LWDAQ_Driver(TC237_device))} {
				if {$info(use_image_area)} {
					LWDAQ_execute_job $sock $LWDAQ_Driver(alt_move_job)
				}
			}
			if {($info(daq_device_type) == $LWDAQ_Driver(ICX424_device)) \
				|| ($info(daq_device_type) == $LWDAQ_Driver(ICX424Q_device))} {
				if {$info(use_image_area)} {
					LWDAQ_transmit_command_hex $sock 0099
					LWDAQ_transmit_command_hex $sock 0098
				}
				LWDAQ_transmit_command_hex $sock 0088	
			}

			LWDAQ_set_data_addr $sock 0
			LWDAQ_execute_job $sock $LWDAQ_Driver(read_job)
			set background_image_contents [LWDAQ_ram_read $sock 0 $image_size]
		}

		# Send the sensor to sleep.
		LWDAQ_sleep $sock

		# Close the socket. We are done with data acquisition.
		LWDAQ_socket_close $sock
	} error_result]} { 
		if {[info exists sock]} {LWDAQ_socket_close $sock}
		return "ERROR: $error_result"
	}
	
	set config(memory_name) [lwdaq_image_create \
		-width $info(daq_image_width) \
		-height $info(daq_image_height) \
		-left $info(daq_image_left) \
		-right $info(daq_image_right) \
		-top $info(daq_image_top) \
		-bottom $info(daq_image_bottom) \
		-data $image_contents \
		-name "$info(name)\_$info(counter)"]

	if {$config(daq_subtract_background)} {
		set background_image_name [lwdaq_image_create \
			-width $info(daq_image_width) \
			-height $info(daq_image_height) \
			-left $info(daq_image_left) \
			-right $info(daq_image_right) \
			-top $info(daq_image_top) \
			-bottom $info(daq_image_bottom) \
			-data $background_image_contents]
		lwdaq_image_manipulate $config(memory_name) \
			subtract $background_image_name -replace 1
		lwdaq_image_destroy $background_image_name
	}

	lwdaq_image_manipulate $config(memory_name) none \
		-results "$config(daq_exposure_seconds)"

	return $config(memory_name) 
} 

