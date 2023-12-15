# Long-Wire Data Acquisition Software (LWDAQ)
# Copyright (C) 2023 Kevan Hashemi, Open Source Instruments Inc.

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
# SCAM.tcl defines the SCAM instrument.
#

#
# LWDAQ_init_SCAM creates all elements of the SCAM instrument's
# config and info arrays.
#
proc LWDAQ_init_SCAM {} {
	global LWDAQ_Info LWDAQ_Driver
	upvar #0 LWDAQ_info_SCAM info
	upvar #0 LWDAQ_config_SCAM config
	array unset config
	array unset info

	# The info array elements will not be displayed in the 
	# instrument window. The only info variables set in the 
	# LWDAQ_open_Instrument procedure are those which are checked
	# only when the instrument window is open.
	set info(name) "SCAM"
	set info(control) "Idle"
	set info(window) [string tolower .$info(name)]
	set info(text) $info(window).text
	set info(photo) [string tolower $info(name)\_photo]
	set info(counter) "0" 
	set info(zoom) "1.0"
	set info(daq_extended) "0"
	set info(extended_parameters) "0.6 0.9 0 1"
	set info(file_use_daq_bounds) "0"
	LWDAQ_set_image_sensor ICX424 SCAM
	set info(daq_wake_ms) "0"
	set info(flash_seconds_max) "0.5"
	set info(flash_seconds_step) "0.001"
	set info(flash_seconds_reduce) "0.2"
	set info(flash_seconds_transition) "0.01"
	set info(flash_max_tries) "30"
	set info(flash_num_tries) "0"
	set info(ambient_exposure_seconds) "0"
	set info(peak_max) "200"
	set info(peak_min) "160"
	set info(file_try_header) "1"
	set info(analysis_add_x_um) "0"
	set info(analysis_add_y_um) "0"
	set info(analysis_reference_um) "0"
	set info(daq_source_device_type) "1"
	set info(daq_password) "no_password"
	set info(daq_source_ip_addr) "*"
	set info(delete_old_images) "1"
	set info(dummy_flash_element) "255"
	set info(dummy_flash_seconds) "0.0"
	set info(verbose_description) "{Disagreement (pixels)}"
	
	# All elements of the config array will be displayed in the
	# instrument window. No config array variables can be set in the
	# LWDAQ_open_Instrument procedure
	set config(image_source) "daq"
	set config(file_name) "./Images/$info(name)\*"
	set config(memory_name) "$info(name)\_0"
	set config(daq_ip_addr) "71.174.73.187"
	set config(daq_source_driver_socket) "3"
	set config(daq_source_mux_socket) "1"
	set config(daq_source_device_element) "1"
	set config(daq_driver_socket) "1"
	set config(daq_mux_socket) "1"
	set config(daq_device_element) "2"
	set config(daq_subtract_background) "0"
	set config(daq_adjust_flash) "0"
	set config(daq_flash_seconds) "0.05"
	set config(intensify) "exact"
	set config(analysis_threshold) "13 %"
	set config(analysis_enable) "1"
	set config(verbose_result) "0"

	return ""
}		

#
# LWDAQ_analysis_SCAM applies SCAM analysis to an image in the lwdaq image list.
# By default, the routine uses the image $config(memory_name).
proc LWDAQ_analysis_SCAM {{image_name ""}} {
	upvar #0 LWDAQ_config_SCAM config
	upvar #0 LWDAQ_info_SCAM info
	if {$image_name == ""} {set image_name $config(memory_name)}
	set result [lwdaq_scam $image_name disagreement $config(analysis_threshold)] 
	if {$result == ""} {set result "ERROR: $info(name) analysis failed."}
	return $result
}

#
# LWDAQ_infobuttons_SCAM creates buttons that allow us to configure
# the SCAM for any of the available image sensors. The general-purpose
# instrument routines will call this procedure when they create the
# info panel.
#
proc LWDAQ_infobuttons_SCAM {f} {
	global LWDAQ_Driver
	
	# Deduce the info panel window name.
	set iw [regsub {.buttons} $f ""]
	
	# Make a frame for the sensor buttons.
	set ff [frame $iw.sensor]
	pack $ff -side top -fill x
	label $ff.cl -text "Image Sensors:"
	pack $ff.cl -side left -expand yes
	foreach a "ICX424 ICX424Q" {
		set b [string tolower $a]
		button $ff.$b -text $a -command "LWDAQ_set_image_sensor $a SCAM"
		pack $ff.$b -side left -expand yes
	}
	label $ff.sl -text "Light Sources:"
	pack $ff.sl -side left -expand yes
	foreach {a sdt} "LED 1 A-SCAM 6 MULTISOURCE 9" {
		set b [string tolower $a]
		button $ff.$b -text $a -command \
			[list set LWDAQ_info_SCAM(daq_source_device_type) $sdt]
		pack $ff.$b -side left -expand yes
	}

	return ""
}

#
# LWDAQ_daq_SCAM captures an image from the LWDAQ electronics and places
# the image in the lwdaq image list. It provides background subtraction by
# taking a second image while flashing non-existent lasers. It provides
# automatic exposure adjustment by calling itself until the maximum image
# intensity lies within peak_min and peak_max. For detailed comments upon
# the readout of the image sensors, see the LWDAQ_daq_Camera routine.
#
proc LWDAQ_daq_SCAM {} {
	global LWDAQ_Info LWDAQ_Driver
	upvar #0 LWDAQ_info_SCAM info
	upvar #0 LWDAQ_config_SCAM config

	set image_size [expr $info(daq_image_width) * $info(daq_image_height)]
	if {$config(daq_flash_seconds) > $info(flash_seconds_max)} {
		set config(daq_flash_seconds) $info(flash_seconds_max)
	}
	if {$config(daq_flash_seconds) < 0} {
		set config(daq_flash_seconds) 0
	}

	if {[catch {
		# We open one or two sockets for the camera and the sources.
		set sock_1 [LWDAQ_socket_open $config(daq_ip_addr)]
		LWDAQ_login $sock_1 $info(daq_password)
		if {![LWDAQ_ip_addr_match $info(daq_source_ip_addr) $config(daq_ip_addr)]} {
			set sock_2 [LWDAQ_socket_open $info(daq_source_ip_addr)]
			LWDAQ_login $sock_2 $info(daq_password)
		} {
			set sock_2 $sock_1
		}

		# Select the device, set the device type, and wake the device up.
		LWDAQ_set_driver_mux $sock_1 $config(daq_driver_socket) $config(daq_mux_socket)
		LWDAQ_set_device_type $sock_1 $info(daq_device_type)
		LWDAQ_set_device_element $sock_1 $config(daq_device_element)
		LWDAQ_wake $sock_1
		
		# If wake delay is enabled, wait for the specified interval before continuing.
		if {$info(daq_wake_ms) > 0} {
			LWDAQ_delay_seconds $sock_1 [expr $info(daq_wake_ms) * 0.001]
		}
		
		# Clear the image sensor of charge.
		LWDAQ_image_sensor_clear $sock_1 $info(daq_device_type)

		# If two drivers, wait for the first to finish.	
		if {$sock_1 != $sock_2} {LWDAQ_wait_for_driver $sock_1}
		
		# Select the source device and wake it up.
		LWDAQ_set_driver_mux $sock_2 $config(daq_source_driver_socket) \
			$config(daq_source_mux_socket)
		LWDAQ_set_device_type $sock_2 $info(daq_source_device_type)
		LWDAQ_wake $sock_2
		
		# If wake delay is enabled, wait for the specified interval before continuing.
		if {$info(daq_wake_ms) > 0} {
			set background_exposure_s [expr $info(daq_wake_ms) * 0.001]	
			LWDAQ_delay_seconds $sock_2 $background_exposure_s
		} {
			set background_exposure_s 0		
		}

		# Select the sources one by one and flash them.
		LWDAQ_set_device_element $sock_2 $config(daq_source_device_element)	
		LWDAQ_flash_seconds $sock_2 $config(daq_flash_seconds)
			
		# Add the ambient exposure if it's non-zero.
		if {$info(ambient_exposure_seconds) > 0.0} {
			LWDAQ_delay_seconds $sock_2 $info(ambient_exposure_seconds)
		}
		
		# If two drivers, wait for the second one to finish.
		if {$sock_1 != $sock_2} {LWDAQ_wait_for_driver $sock_2}
		
		# Select the camera again.
		LWDAQ_set_driver_mux $sock_1 $config(daq_driver_socket) $config(daq_mux_socket)
		LWDAQ_set_device_type $sock_1 $info(daq_device_type)
		LWDAQ_set_device_element $sock_1 $config(daq_device_element)
		
		# Transfer the image into the readout array.
		LWDAQ_image_sensor_transfer $sock_1 $info(daq_device_type)
		
		# Read the image out of the sensor and into driver memory.
		LWDAQ_set_data_addr $sock_1 0
		LWDAQ_execute_job $sock_1 $LWDAQ_Driver(read_job)
		
		# Download the image from the driver.
		set image_contents [LWDAQ_ram_read $sock_1 0 $image_size]

		# Now we do it all again for background subtraction. We duplicate the total
		# exposure time of the foreground image by implementing delays in place of
		# the light flashes.
		if {$config(daq_subtract_background)} {
			LWDAQ_image_sensor_clear $sock_1 $info(daq_device_type)
			if {$sock_1 != $sock_2} {LWDAQ_wait_for_driver $sock_1}
			LWDAQ_set_driver_mux $sock_2 $config(daq_source_driver_socket) \
				$config(daq_source_mux_socket)
			LWDAQ_set_device_type $sock_2 $info(daq_source_device_type)
			LWDAQ_delay_seconds $sock_2 $config(daq_flash_seconds)
			if {$sock_1 != $sock_2} {LWDAQ_wait_for_driver $sock_2}
			LWDAQ_set_driver_mux $sock_1 $config(daq_driver_socket) \
				$config(daq_mux_socket)
			LWDAQ_set_device_type $sock_1 $info(daq_device_type)
			LWDAQ_set_device_element $sock_1 $config(daq_device_element)
			LWDAQ_image_sensor_transfer $sock_1 $info(daq_device_type)
			LWDAQ_set_data_addr $sock_1 0
			LWDAQ_execute_job $sock_1 $LWDAQ_Driver(read_job)
			set background_image_contents [LWDAQ_ram_read $sock_1 0 $image_size]
		}
		
		# Put camera and source to sleep.
		LWDAQ_set_driver_mux $sock_1 $config(daq_driver_socket) \
			$config(daq_mux_socket)
		LWDAQ_sleep $sock_1		
		LWDAQ_set_driver_mux $sock_2 $config(daq_source_driver_socket) \
			$config(daq_source_mux_socket)
		LWDAQ_sleep $sock_2
		
		# Close the sockets.
		LWDAQ_socket_close $sock_1
		if {$sock_2 != $sock_1} {LWDAQ_socket_close $sock_2}
	} error_result]} { 
		if {[info exists sock_1]} {LWDAQ_socket_close $sock_1}
		if {[info exists sock_2]} {LWDAQ_socket_close $sock_2}
		return "ERROR: $error_result"
	}
	
	# Create a LWDAQ image and load it with our acquired image contents. Give the 
	# image its name and analysis boundaries.
	set config(memory_name) [lwdaq_image_create \
		-width $info(daq_image_width) \
		-height $info(daq_image_height) \
		-left $info(daq_image_left) \
		-right $info(daq_image_right) \
		-top $info(daq_image_top) \
		-bottom $info(daq_image_bottom) \
		-data $image_contents \
		-name "$info(name)\_$info(counter)"]
		
	# If required, create a background image and load it with our acquired background
	# image contents. Subtract this image from our main image to obtain the final
	# background-subtracted image.
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
	
	# We may want to increase the flash time when the image is not bright enough,
	# or reduce the flash time when the image is too bright. We parse the
	# daq_adjust_flash option into two parts: a calculation code and an argument.
	set code [lindex $config(daq_adjust_flash) 0]
	set argument [lrange $config(daq_adjust_flash) 1 end]
	
	# If the code is zero, we do no further adjustment, but return the name of
	# the image we have acquired. Otherwise, we must start by measuring the
	# brightness of the image, which we do in a manner controlled by the code
	# and its argument. In all cases, the brightness measure applies only to the
	# analysis boundaries.
	switch $code {
		"0" {
			# No flash adjustment.
			return $config(memory_name)
		}
		"1" {
			# Use maximum intensity in image, argument ignored.
			set brightness [lindex [lwdaq_image_characteristics $config(memory_name)] 6]
		}
		"2" {
			# Use average intensity in image, argument ignored.
			set brightness [lindex [lwdaq_image_characteristics $config(memory_name)] 4]
		}
		"3" {
			# Use the maximum intensity for which a specified fraction of pixels
			# are as bright or brighter. The argument must be a fraction greater
			# than zero and less than one. We call this brightness a "soft
			# maximum".
			if {![string is double -strict $argument] \
				|| ($argument < 0.0) || ($argument > 1.0)} {
				return "ERROR: Invalid soft maximum fraction \"$argument\"."
			}
			set histogram [lwdaq_image_histogram $config(memory_name)]
			set num_pixels 0
			foreach {b n} $histogram {
				set num_pixels [expr $num_pixels + $n]
			}
			set num_above $num_pixels
			set brightness 0
			foreach {b n} $histogram {
				set num_above [expr $num_above - $n]
				if {$num_above < $num_pixels * $argument} {break}
				set brightness $b
			}
		}
		"4" {
			# Use the maximum intensity for which a specified number of pixels
			# are as bright or brighter. The argument must be an integer greater
			# than zero. We call this brightness the "optical maximum".
			if {![string is integer -strict $argument] || ($argument < 0)} {
				return "ERROR: Invalid optical maximum quantity \"$argument\"."
			}
			set histogram [lwdaq_image_histogram $config(memory_name)]
			set num_pixels 0
			foreach {b n} $histogram {
				set num_pixels [expr $num_pixels + $n]
			}
			set num_above $num_pixels
			set brightness 0
			foreach {b n} $histogram {
				set num_above [expr $num_above - $n]
				if {$num_above < $argument} {break}
				set brightness $b
			}
		}
		default {
			set brightness [lindex [lwdaq_image_characteristics $config(memory_name)] 6]
		}
	}
	
	# Adjust the flash time as needed and decide if we must call the data
	# acquisition routine again.
	set call_self 0
	set t $config(daq_flash_seconds)
	if {$brightness < 1} {set brightness 1}
	if {$brightness < $info(peak_min)} {
		if {$t < $info(flash_seconds_max)} {
			if {$t < $info(flash_seconds_transition)} {
				set t [expr $t + $info(flash_seconds_step) ]
				set call_self 1
			} {
				set t [expr ($info(peak_min) + $info(peak_max)) * 0.5 * $t / $brightness ]
				if {$t > $info(flash_seconds_max)} {
					set t $info(flash_seconds_max)
					set call_self 1
				} {
					set call_self 1
				}
			}
		} {
			set call_self 0
		}
	} {
		if {$brightness > $info(peak_max)} {
			if {$t > 0} {
				if {$t <= $info(flash_seconds_transition)} {
					set t [expr $t - $info(flash_seconds_step) ]
					set call_self 1
				} {
					set t  [expr $t * $info(flash_seconds_reduce) ]
					set call_self 1
				}
			} {
				set call_self 0
			}
		} {
			set call_self 0
		}
	}

	if {$call_self \
		&& ($info(control) != "Stop") \
		&& ($info(flash_num_tries)<$info(flash_max_tries))} {
		incr info(flash_num_tries)
		set config(daq_flash_seconds) [format "%.6f" $t]
		if {[winfo exists $info(window)]} {
			lwdaq_draw $config(memory_name) $info(photo) \
				-intensify $config(intensify) -zoom $info(zoom)
		} 
		return [LWDAQ_daq_$info(name)]
	} {
		set info(flash_num_tries) 0
		return $config(memory_name) 
	}
} 

#
# LWDAQ_extended_SCAM tries to assign optimal values to peak_max and peak_min,
# and adjust the analysis boundaries to enclose the spots within a number of
# pixels of their centers. You direct the configuration calculations with the
# extended_parameters string, which contains parameters as a list. The string
# "0.6 0.9 20 1" sets peak_min to 60% of saturation, peak_max to 90% of
# saturation, shrinks the image bounds to 20 pixels around the spot center, and
# adjusts individual source exposure times. If you don't want a border, specify
# bounds to be 0 (instead of 20). If you don't want to adjust multiple sources
# individually, specify 0 for individual_sources.
#
proc LWDAQ_extended_SCAM {} {
   	global LWDAQ_Info LWDAQ_Driver
	upvar #0 LWDAQ_info_SCAM info
	upvar #0 LWDAQ_config_SCAM config

	# Check extended parameter string to make sure that its elements
	# are correct, and insert default values if they are absent.
	LWDAQ_print $info(text) "\nExtended Acquisition" green
	LWDAQ_print $info(text) "parameters \"$info(extended_parameters)\""
	set min_frac [lindex $info(extended_parameters) 0]
	LWDAQ_print $info(text) "min_frac = $min_frac"
	if {![string is double -strict $min_frac]} {
		return "ERROR: value \"$min_frac\" is not valid for min_frac."
	}
	if {($min_frac<0) || ($min_frac>=1)} {
		return "ERROR: value \"$min_frac\" is not valid for min_frac."
	}
	set max_frac [lindex $info(extended_parameters) 1]
	LWDAQ_print $info(text) "max_frac = $max_frac"
	if {![string is double -strict $max_frac]} {
		return "ERROR: value \"$max_frac\" is not valid for max_frac."
	}
	if {($max_frac<=$min_frac) || ($max_frac>1)} {
		return "ERROR: value \"$max_frac\" is not valid for max_frac."
	}
	set border [lindex $info(extended_parameters) 2]
	if {$border == ""} {set border 0}
	LWDAQ_print $info(text) "border = $border"
	if {![string is integer $border]} {
		return "ERROR: value \"$border\" is not valid for border."
	}
	if {$border < 0} {
		return "ERROR: value \"$border\" is not valid for border."
	}
	set individual_sources [lindex $info(extended_parameters) 3]
	if {$individual_sources == ""} {set individual_sources 1}
	LWDAQ_print $info(text) "individual_sources = $individual_sources"
	if {![string is integer -strict $border]} {
		return "ERROR: value \"$individual_sources\" is not valid for individual_sources."
	}

	# Save the data acquisition parameters we will be altering during
	# extended acquisition. We used the saved values to make sure that
	# we restore the SCAM Instrument to its former condition at the end
	# of extended data acquisition, even if we abort with an error.
	set saved_daf $config(daq_adjust_flash)
	set saved_dfs $config(daq_flash_seconds)
	set saved_dsds $config(daq_source_driver_socket)
	set saved_apsu $info(analysis_pixel_size_um)
	set saved_dsde $config(daq_source_device_element) 
	
	# Obtain an image with zero flash time. This image serves
	# as a background or black-level reference.
	set config(daq_adjust_flash) 0
	set config(daq_source_driver_socket) 0
	set config(daq_flash_seconds) 0
	set image_name [LWDAQ_daq_SCAM]
	set config(daq_flash_seconds) $saved_dfs
	set config(daq_source_driver_socket) $saved_dsds
	set config(daq_adjust_flash) $saved_daf
	
	# Display the background image and determine its average intensity.
	if {[LWDAQ_is_error_result $image_name]} {return $image_name}	
	if {[winfo exists $info(window)]} {
		lwdaq_draw $image_name $info(photo) \
			-intensify $config(intensify) -zoom $info(zoom)
	} 
	set bg [lindex [lwdaq_image_characteristics $image_name] 4]
	LWDAQ_print $info(text) "background = $bg"
	
	# Obtain an image with the lasers flashing for the 
	# maximum possible time. We assume this image contains
	# saturated pixels.
	set config(daq_adjust_flash) 0
	set config(daq_flash_seconds) $info(flash_seconds_max)
	set image_name [LWDAQ_daq_SCAM]
	set config(daq_flash_seconds) $saved_dfs
	set config(daq_adjust_flash) $saved_daf
	
	# Display the saturated image and determine its maximum intensity.
	if {[LWDAQ_is_error_result $image_name]} {return $image_name}	
	if {[winfo exists $info(window)]} {
		lwdaq_draw $image_name $info(photo) \
			-intensify $config(intensify) -zoom $info(zoom)
	} 
	set sat [lindex [lwdaq_image_characteristics $image_name] 6]
	LWDAQ_print $info(text) "saturation = $sat"

	# Calculate the maximum and minimum acceptable peak spot
	# intensities for the SCAM, based upon the background
	# and saturated image intensities.
	set info(peak_max) [expr round(($sat - $bg) * $max_frac + $bg)]
	LWDAQ_print $info(text) "peak_max = $info(peak_max)"
	set info(peak_min) [expr round(($sat - $bg) * $min_frac + $bg)]
	LWDAQ_print $info(text) "peak_min = $info(peak_min)"
	
	# We now go through all the source elements in daq_source_element
	# and determine their optimal exposure times separately.
	if {([llength $config(daq_source_device_element)] > 1) && $individual_sources} {

		# Make a list of element numbers and their optimal flash times.
        set exposures [list]
        foreach element $config(daq_source_device_element) {
        	set element_num [lindex [split $element *] 0]
			set config(daq_source_device_element) $element_num
			set config(daq_flash_seconds) $info(flash_seconds_max)
			set config(daq_adjust_flash) 1
			set image_name [LWDAQ_daq_SCAM]
			set flash_seconds $config(daq_flash_seconds)
			set config(daq_adjust_flash) $saved_daf
			set config(daq_flash_seconds) $saved_dfs
			set config(daq_source_device_element) $saved_dsde

			if {[LWDAQ_is_error_result $image_name]} {return $image_name}	
			if {[winfo exists $info(window)]} {
				lwdaq_draw $image_name $info(photo) \
					-intensify $config(intensify) -zoom $info(zoom)
			} 
			lappend exposures "$element_num $flash_seconds"
			LWDAQ_print $info(text) "Element $element_num flash time = $flash_seconds"
        }
        
        # Sort this list in order of increasing exposure time, and determine
        # the minimum exposure time.
        set exposures [lsort -increasing -index 1 $exposures]
        set min_exposure [lindex $exposures 0 1]
        
        # We will use the minimum exposure time as daq_flash_seconds unless
        # the minimum exposure time is less than flash_seconds_step, in 
        # which case we use flash_seconds_step instead.
		if {$min_exposure < $info(flash_seconds_step)} {
			set config(daq_flash_seconds) $info(flash_seconds_step)
		} {
			set config(daq_flash_seconds) $min_exposure
		}
        LWDAQ_print $info(text) "Reference flash time = $config(daq_flash_seconds)"
        
        # Create a new device list in which we list the device elements in
        # order of increasing exposure time, with each element number followed
        # by "*" and the multiple of daq_flash_seconds required to 
        # obtain the element's exposure time.
        set new_device_list ""
		foreach element $exposures {
			set exposure [lindex $element 1]
			set element_num [lindex $element 0]
			set ratio [expr $exposure / $config(daq_flash_seconds)]
			append new_device_list "$element_num\*[format %1.2f $ratio] "
		}
		
		# Replace the old device list.
		set config(daq_source_device_element) $new_device_list
		LWDAQ_print $info(text) "New device list = \"$new_device_list\""
	}
	
	# Try out the new parameter with an acquisition with automatic
	# flash adjustement.
	set config(daq_adjust_flash) 1
	set image_name [LWDAQ_daq_SCAM]
	set config(daq_adjust_flash) $saved_daf
	if {[LWDAQ_is_error_result $image_name]} {return $image_name}	

	# If the border parameter is greater than zero, we adjust the
	# analysis boundaries so they enclose the spots with $border
	# pixels on all sides of the spot centers.
	if {$border > 0} {
	
		# Find the coordinates of the spots in units of
		# image pixels.
		set info(analysis_pixel_size_um) 1
		set result [LWDAQ_analysis_SCAM $image_name]
		set info(analysis_pixel_size_um) $saved_apsu
		if {[LWDAQ_is_error_result $result]} {return $image_name}	

		# Find the range of columns and rows spanned by
		# the spot centers.
		set max_i 1
		set max_j 1
		set min_i $info(daq_image_width)
		set min_j $info(daq_image_height)
		foreach {i j n p s t} $result {
			if {$i == -1} {continue}
			if {$i > $max_i} {set max_i $i}
			if {$i < $min_i} {set min_i $i}
			if {$j > $max_j} {set max_j $j}
			if {$j < $min_j} {set min_j $j}			
		}
		
		# Calculate the analysis boundaries to enclose the spot centers.
		set info(daq_image_left) [expr round($min_i - $border)]
		if {$info(daq_image_left) < 1} {
			set info(daq_image_left) 1
		}
		set info(daq_image_right) [expr round($max_i + $border)]
		if {$info(daq_image_right) >= [expr $info(daq_image_width) -1]} {
			set info(daq_image_right) [expr $info(daq_image_width) -1]
		}
		set info(daq_image_top) [expr round($min_j - $border)]
		if {$info(daq_image_top) < 1} {
			set info(daq_image_top) 1
		}
		set info(daq_image_bottom) [expr round($max_j + $border)]
		if {$info(daq_image_bottom) >= [expr $info(daq_image_height) - 1]} {
			set info(daq_image_bottom) [expr $info(daq_image_height) -1]
		}
		
		# Inform the user of the new boundaries.
		LWDAQ_print $info(text) "daq_image_left = $info(daq_image_left)"
		LWDAQ_print $info(text) "daq_image_top = $info(daq_image_top)"
		LWDAQ_print $info(text) "daq_image_right = $info(daq_image_right)"
		LWDAQ_print $info(text) "daq_image_bottom = $info(daq_image_bottom)"

		# Set the analysis boundaries of the existing image.
		lwdaq_image_manipulate $image_name none \
			-left $info(daq_image_left) \
			-right $info(daq_image_right) \
			-top $info(daq_image_top) \
			-bottom $info(daq_image_bottom)
	}

	# Display the final image.
	if {[winfo exists $info(window)]} {
		lwdaq_draw $image_name $info(photo) \
			-intensify $config(intensify) -zoom $info(zoom)
	} 
	
	# Return the name of the final image.
	return $image_name
}

