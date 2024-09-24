# Direct Fiber Positioning System Manager, a LWDAQ Tool
#
# Copyright (C) 2022-2024 Kevan Hashemi, Open Source Instruments Inc.
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <https://www.gnu.org/licenses/>.

#
# DFPS_Manager_init creates and initializes the DFPS Manager Tool's
# configuration (config) and information (info) arrays. It reads saved
# configuration (but not information) parameters from disk if we have previously
# saved our configuration to disk. All the configuration parameters are visible
# in the tool's configuration array, where there are save and unsave buttons to
# create and delete a default configuration file.
#
proc DFPS_Manager_init {} {
	upvar #0 DFPS_Manager_info info
	upvar #0 DFPS_Manager_config config
	upvar #0 LWDAQ_info_BCAM iinfo
	upvar #0 LWDAQ_config_BCAM iconfig
	global LWDAQ_Info LWDAQ_Driver
	
	LWDAQ_tool_init "DFPS_Manager" "2.12"
	if {[winfo exists $info(window)]} {return ""}
	
	# Set the precision of the lwdaq libraries. We need six places after the
	# decimal point so we can see microradians in radian values.
	lwdaq_config -fsd 6

	# The state variable tells us the current state of the tool.
	set info(state) "Idle"
	set config(verbose) "0"
	set config(report) "0"
	set info(vcolor) "brown"
	
	# Instrument fundamentals.
	set info(fiducial_fibers) "1 2 3 4"
	set info(guide_sensors) "1 2 3 4"
	set info(positioner_masts) "1 2 3 4"
	set info(detector_fibers) "1 2"	

	# Data acquisition parameters for the DFPS-4A.
	set config(ip_addr) "192.168.1.30"
	# Breadboard OSI Local: 192.168.1.10
	# DFPS-4A OSI Local: 192.168.1.30
	# DFPS-4A OSI Global: 71.174.73.186
	# DFPS-4A McDonald Local: 198.214.229
	set config(fvc_left) "5 0"
	set config(fvc_right) "4 0"
	set config(injector) "8 0"
	set config(fiducial_leds) "A5 A7 A6 A8"
	set config(guide_leds) "D3 D4 D2 D1"
	set config(flash_s) "0.004"
	set config(expose_s) "0.1"
	set config(sort_code) "8"
	set config(transceiver) "1 0"
	set config(controllers) "6912 1834 C323 1845"
	set config(source_type) "9"
	set config(camera_element) "2"
	set config(source_pwr) "2"
	set info(wildcard_id) "FFFF"
	set info(dac_zero) "32000"
	set info(dac_max) "65535"
	set info(dac_min) "0"
	set info(image_sensor) "ICX424"
	LWDAQ_set_image_sensor $info(image_sensor) BCAM
	LWDAQ_set_image_sensor $info(image_sensor) Rasnik
	LWDAQ_set_image_sensor $info(image_sensor) Camera
	set config(analysis_threshold) "10 #"
	set config(guide_daq_1) "7 0 2"
	set config(guide_daq_2) "6 0 1"
	set config(guide_daq_3) "7 0 1"
	set config(guide_daq_4) "6 0 2"
	set info(guide_manipulations) "invert rows_to_columns"
	
	# Acquisition and analysis results.
	set info(fiducial_sources) ""
	foreach m $info(positioner_masts) {
		set info(mast_$m) "0.000 0.000"
		set info(target_$m) "0.000 0.000"
		set info(offset_$m) "0.000 0.000"
	}
	
	# Calibration file. By default, we store calibration constants in the
	# LWDAQ Tools/Data directory.
	set config(calib_file) [file join $LWDAQ_Info(tools_dir) Data DFPS_Calibration.tcl]
		
	# Fiber view camera calibration constants.
	set info(cam_default) "12.675 39.312 1.000 0.000 0.000 2.000 19.000 0.000" 
	set info(cam_left) \
"12.675 39.312 1.000 -7.070 1.241 2.000 19.026 5.172"
# Nominal FVC:
# 12.675 39.312 1.000 0.000 0.000 2.000 19.000 0.000
# DFPS-4A Y71010:
# 12.675 39.312 1.000 -7.070 1.241 2.000 19.026 5.172
# Breadboard Y71066:
# 12.675 39.312 1.000 -14.793 -2.790 2.000 18.778 2.266
	set info(cam_right) \
"12.675 39.312 1.000 2.954 -1.443 2.000 19.172 7.765"
# Nominal: 
# FVC 12.675 39.312 1.000 0.000 0.000 2.000 19.000 0.000
# DFPS-4A Y71003:
# 12.675 39.312 1.000 2.954 -1.443 2.000 19.172 7.765
# Breadboard Y71080:
# 12.675 39.312 1.000 -7.059 3.068 2.000 19.016 1.316
	
	# Fiber view camera mount measurents.
	set info(mount_left) \
"80.259 50.931 199.724 120.012 50.514 264.564 79.473 50.593 275.868"
# DFPS-4A: 
# 80.259 50.931 199.724 120.012 50.514 264.564 79.473 50.593 275.868
# Breadboard: 
# 79.614 51.505 199.754 119.777 51.355 264.265 79.277 51.400 275.713
	set info(mount_right) \
"-104.780 51.156 198.354 -107.973 50.745 274.238 -147.781 50.858 260.948"
# DFPS-4A: 
# -104.780 51.156 198.354 -107.973 50.745 274.238 -147.781 50.858 260.948
# Breadboard: 
# -104.039 51.210 199.297 -108.680 51.004 275.110 -148.231 50.989 261.059
	
	# We obtain the pose of the mount coordinats by a fit to the mount measurements.
	set info(coord_left) [lwdaq bcam_coord_from_mount $info(mount_left)]
	set info(coord_right) [lwdaq bcam_coord_from_mount $info(mount_right)]
	
	# Local coordinate offset with respect to frame coordinates.
	set info(local_coord_offset) "65.0"

	# Local coordinate pose in global coordinates.
	set info(local_coord) "-13.0 90.0 -92.0 0.0 0.0 0.0"
	# Nominal -13.0 90.0 -92.0 0 0 0
	# DFPS-4A -12.904 89.042 -96.586 0.001 -0.001 0.000
	
	# Fiducial positions in local coordinates.
	set info(fiducial_1) "-15.0 +15.0 2.8"
	# Nominal: -15.0 +15.0 2.8
	# DFPS-4A: -15.255 14.899 2.800
	set info(fiducial_2) "+15.0 +15.0 2.8"
	# Nominal: +15.0 +15.0 2.8
	# DFPS-4A:  14.684 14.941 2.550
	set info(fiducial_3) "-15.0 -15.0 2.8"
	# Nominal: -15.0 -15.0 2.8
	# DFPS-4A: -15.292 -15.074 2.238
	set info(fiducial_4) "+15.0 -15.0 2.8"
	# Nominal: +15.0 -15.0 2.8
	# DFPS-4A:  14.562 -15.076 2.726
	
	# Guide sensor positions and orientations in local coordinates.
	set info(guide_1) "-24.598 19.792 5.028"
	# Nominal: -24.400 19.900 0.100
	# DFPS-4A: -24.572 19.714 5.188
	set info(guide_2) "20.268 19.770 3.874"
	# Nominal: 20.600 19.900 0.100
	# DFPS-4A: 20.310 19.685 3.932
	set info(guide_3) "-24.685 -25.170 0.917"
	# Nominal: -24.400 -25.100 0.100
	# DFPS-4A: -24.651 -25.258 0.987
	set info(guide_4) "20.347 -25.146 9.414"
	# Nominal: 20.600 -25.100 0.100
	# DFPS-4A: 20.391 -25.227 9.697
	
	# Default control values for the upleft and upright.
	set config(upleft) $info(dac_zero) 
	set config(upright) $info(dac_zero) 
	
	# Command transmission values.
	set config(initiate_delay) "0.010"
	set config(spacing_delay) "0.0014"
	set config(byte_processing_time) "0.0002"
	set info(rf_on_op) "0081"
	set info(rf_xmit_op) "82"
	set info(checksum_preload) "1111111111111111"	
	
	# Mast control system.
	set info(fiducial_survey_time) "0"
	set info(mast_control_time) "0"
	set config(fiducial_survey_period) "1000"
	set config(mast_control_period) "10"
	set config(enable_mast_control) "0"
	foreach m $info(positioner_masts) {
		set info(voltage_$m) "$info(dac_zero) $info(dac_zero)"
	}
	set config(gain) "10000"
	set config(displacement) "0.0 0.0"
	
	# Window settings.
	set info(label_color) "brown"
	set config(guide_zoom) "0.3"
	set config(guide_mag_zoom) "1.0"
	set config(fvc_zoom) "0.5"
	set config(intensify) "exact"	
	set config(mouse_offset_x) "0"
	set config(mouse_offset_y) "2"
	
	# Image dimensions.
	set info(guide_width_um) "3848"
	set info(guide_height_um) "5180"
	set info(bcam_width_um) "5180"
	set info(bcam_height_um) "3848"
	set info(icx424_col) "700"
	set info(icx424_row) "520"
	set info(icx424_pix_um) "7.4"

	# Utility panel parameters.
	set config(utils_ctrl) "FFFF"
	set config(utils_cmd) "8"	
	set info(utils_state) "Idle"
	set info(utils_text) "none"
	
	# Fiber View Camera Calibration (fvcalib) settings.
	set info(fvcalib_state) "Idle"
	set info(num_sources) "4"
	set info(fvcalib_fid_1) "-28.223 104.229 -91.363"
	set info(fvcalib_fid_2) "1.717 104.294 -91.613"
	set info(fvcalib_fid_3) "-28.229 74.268 -91.925"
	set info(fvcalib_fid_4) "1.631 74.257 -91.437"
	set info(spots_left) \
"1572.16 1192.59 3377.92 1154.19 1594.61 3038.75 3381.78 3051.64"
	set info(spots_right) \
"2223.58 1109.76 4000.05 1117.53 2232.85 3038.02 4017.75 2984.44"
	set config(bcam_sort) "8"
	set config(displace_scale) "1"
	set config(cross_size) "100"
	set config(fit_scaling) "0 0 0 1 1 0 1 1"
	set config(fit_steps) "1000"
	set config(fit_restarts) "4"
	set config(fit_startsize) "1"
	set config(fit_endsize) "0.005"
	set config(fit_show) "0"
	set config(fit_details) "0"
	set config(fit_stop) "0"
	set config(fvcalib_zoom) "1.0"
	set config(fvcalib_intensify) "exact"
	
	# Guide Sensor with Rasnik Calibration (gscalib) settings.
	set info(gscalib_state) "Idle"
	set info(gscalib_orientations) "0 90 180 270"
	set info(gscalib_swaps) "0 1 0 1"
	set config(gscalib_orientation_codes) "1 3 4 2"
	set config(gscalib_algorithm) "21"
	set config(gscalib_square_um) "340"
	set config(gscalib_flash_s) "0.02"
	set info(gscalib_refcode) "3"
	set config(gscalib_ref_x_um) "0"
	set config(gscalib_ref_y_um) "5180"
	set config(gscalib_zoom) "0.5"
	set config(gscalib_intensify) "exact"
	
	# gscalib data. We have default values for rasnik mask measurements from
	# all four guide sensors in all four orientations, for use in testing
	# gscalib calculations.
	set info(gscalib_mask_0) \
"24.335 68.344 -5.088 69.217 68.315 -3.832 24.256 23.372 -0.887 69.298 23.403 -9.597"
# Nominal: 
# 24.4 68.2 0 69.4 68.2 0 24.4 23.2 0 69.4 23.2 0
# DFPS-4A: 
# 24.335 68.344 -5.088 69.217 68.315 -3.832 24.256 23.372 -0.887 69.298 23.403 -9.597 
	set info(gscalib_mask_90) \
"29.204 24.074 -5.196 29.233 68.955 -3.762 74.179 23.986 -0.955 74.137 69.036 -10.000"
# Nominal: 
# 28.9 23.9 0 28.9 68.9 0 73.9 23.9 0 73.9 68.9 0
# DFPS-4A: 
# 29.204 24.074 -5.196 29.233 68.955 -3.762 74.179 23.986 -0.955 74.137 69.036 -10.000 
	set info(gscalib_mask_180) \
"73.459 28.917 -5.187 28.577 28.951 -3.851 73.555 73.893 -0.862 28.506 73.849 -9.665"
# Nominal: 
# 73.2 28.4 0 28.2 28.4 0 73.2 73.4 0 28.2 73.4 0
# DFPS-4A: 
# 73.459 28.917 -5.187 28.577 28.951 -3.851 73.555 73.893 -0.862 28.506 73.849 -9.665 
	set info(gscalib_mask_270) \
"68.625 73.183 -5.271 68.588 28.300 -3.737 23.652 73.275 -0.754 23.685 28.226 -9.795"
# Nominal: 
# 68.7 72.7 0 68.7 27.7 0 23.7 72.7 0 23.7 27.7 0
# DFPS-4A: 
# 68.625 73.183 -5.271 68.588 28.300 -3.737 23.652 73.275 -0.754 23.685 28.226 -9.795 
	set info(gscalib_rot_mrad) "-0.10"
	# Nominal: 0.00
	# Actual: -0.10
	set info(gscalib_width) "130.000"
	# Nominal: 130.0
	# Actual: 130.00
	set info(gscalib_height) "130.000"
	# Nominal: 130.0
	# Actual: 130.00
	
	# Fiducial Rotation Calibration (FRot) settings.
	set info(frot_state) "Idle"
	set info(frot_measurements) [list]
	set info(frot_orientations) "0 90 180 270"
	set info(frot_0) \
"-30.0 +105.0 -90.0 0.0 +105 -90.0 -30.0 +75.0 -90.0 0.0 +75.0 -90.0"
	set info(frot_90) \
"0.0 +105.0 -90.0 0.0 +75 -90.0 -30.0 +105.0 -90.0 -30.0 +75.0 -90.0"
	set info(frot_180) \
"0.0 +75.0 -90.0 -30.0 +75 -90.0 0.0 +105.0 -90.0 -30.0 +105.0 -90.0"
	set info(frot_270) \
"-30.0 +75.0 -90.0 -30.0 +105 -90.0 0.0 +75.0 -90.0 0.0 +105.0 -90.0"
	set info(frot_wait_ms) "100"
	set info(frot_width) "130.00"
	# Nominal: 130.0
	# Actual: 130.00
	set info(frot_height) "130.00"
	# Nominal: 130.0
	# Actual: 130.00
	
	# Mast Calibration (MCalib) settings. We have detector offsets from the
	# guide fibers, x and y in local coordinates, to be added to mast position
	# (the guide fiber position) to obtain the detector position. We have data
	# acquisition parameters for the calibration. We have the mast ranges
	# expressed as a rotated square. We have the square center x and y in local
	# coordinates, the side of the square, and its rotation counter clockwise as
	# seen from in front of the mast, in radians.
	set info(mcalib_state) "Idle"
	foreach m $info(positioner_masts) {
		foreach d $info(detector_fibers) {
			set info(detector_$m\_$d) "0.000 0.000"
		}
	}
	set config(mcalib_pwr) "7"
	set config(mcalib_mast) "1"
	set config(mcalib_detector) "1"
	set config(mcalib_led) "A1"
	set config(mcalib_flash) "0.1"
	set info(mrange_corners) "bottom left top right"
	foreach m $info(positioner_masts) {
		set info(mrange_$m) "0.000 0.000 3.5 0.000"
	}
	set config(mcalib_settling_ms) "5000"
	
	# If we have a settings file, read and implement.	
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 
	
	# Read the calibration file, if it exists.
	if {[file exists $config(calib_file)]} {
		uplevel #0 [list source $config(calib_file)]
	} 

	# Create spaces to store FVC images as they come in from the BCAM
	# Instrument.
	foreach side {left right} {
		set info(image_$side) dfps_fvc_$side
		lwdaq_image_create -name $info(image_$side) \
			-width $info(icx424_col) -height $info(icx424_row)
	}

	# Create spaces to store guide images as they come in from the Camera
	# Instrument.
	foreach guide $info(guide_sensors) {
		set info(image_$guide) dfps_guide_$guide
		lwdaq_image_create -name $info(image_$guide) \
			-width $info(icx424_row) -height $info(icx424_col)
	}

	# Create spaces to store FVC images read from disk.
	foreach side {left right} {
		set info(fvcalib_$side) fvcalib_$side
		lwdaq_image_create -name $info(fvcalib_$side) \
			-width $info(icx424_col) -height $info(icx424_row)
	}
	
	return ""   
}

#
# DFPS_Manager_read_calibration reads calibration constants from a named file, or
# from the default file if no file is specified.
#
proc DFPS_Manager_read_calibration {{fn ""}} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	if {$fn == ""} {set fn [LWDAQ_get_file_name 0 [file dirname $config(calib_file)]]}
	if {$fn != ""} {
		set config(calib_file) $fn
		uplevel #0 [list source $config(calib_file)]
	}
	
	return ""
}

#
# DFPS_Manager_save_calibration saves the fiber view mounts, camera parameters,
# fiducial positions, guide sensor positions, detector fiber offsets, actuator
# ranges, and actuator maps to disk in the Tools/Settings folder.
#
proc DFPS_Manager_save_calibration {{fn ""}} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	if {$fn == ""} {
		set fn [LWDAQ_put_file_name $config(calib_file)]
	}
	if {$fn == ""} {
		return ""
	} else {
		set config(calib_file) $fn
	}
	
	set f [open $config(calib_file) w]
	foreach or $info(gscalib_orientations) {
		puts $f "set DFPS_Manager_info(gscalib_mask_$or) \"$info(gscalib_mask_$or)\""
	}
	foreach a {rot_mrad width height} {
		puts $f "set DFPS_Manager_info(gscalib_$a) \"$info(gscalib_$a)\""
	}
	foreach guide $info(guide_sensors) {
		puts $f "set DFPS_Manager_info(guide_$guide) \"$info(guide_$guide)\""
	}
	foreach or $info(frot_orientations) {
		puts $f "set DFPS_Manager_info(frot_$or) \"$info(frot_$or)\""
	}
	foreach a {width height} {
		puts $f "set DFPS_Manager_info(frot_$a) \"$info(frot_$a)\""
	}
	foreach a {left right} {
		puts $f "set DFPS_Manager_info(mount_$a) \"$info(mount_$a)\""
		puts $f "set DFPS_Manager_info(cam_$a) \"$info(cam_$a)\""
	}
	foreach a $info(fiducial_fibers) {
		puts $f "set DFPS_Manager_info(fiducial_$a) \"$info(fiducial_$a)\""
	}
	puts $f "set DFPS_Manager_info(local_coord) \"$info(local_coord)\""
	foreach m $info(positioner_masts) {
		puts $f "set DFPS_Manager_info(mrange_$m) \"$info(mrange_$m)\""
	}
	foreach a $info(positioner_masts) {
		foreach b $info(detector_fibers) {
			puts $f "set DFPS_Manager_info(detector_$a\_$b)\
				\"$info(detector_$a\_$b)\""
		}
	}
	close $f
	
	if {$config(verbose)} {
		set f [open $config(calib_file) r]
		set contents [read $f]
		close $f
		LWDAQ_print $info(text) $contents $info(vcolor)
	}
	return ""
}

#
# DFPS_Manager_examine_calibration opens a new window that displays the CMM
# measurements of the left and right mounting balls, the camera calibration
# constants, and the fiducial plate measurements.
#
proc DFPS_Manager_examine_calibration {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set w "$info(window).examine_window"
	if {![winfo exists $w]} {
		toplevel $w
		wm title $w "Calibration Constants, DFPS Manager $info(version)"
	} {
		raise $w
		return ""
	}
	
	set big 90
	set sl 14
	set se 20
	set i 0
	
	foreach a {left right} {
		set f [frame $w.f[incr i]]
		pack $f -side top -fill x
		label $f.ml$a -text "mount_$a\:" -fg $info(label_color)
		entry $f.me$a -textvariable DFPS_Manager_info(mount_$a) -width $big
		pack $f.ml$a $f.me$a -side left -expand yes
	}

	foreach a {left right} {
		set f [frame $w.f[incr i]]
		pack $f -side top -fill x
		label $f.cl$a -text "cam_$a\:" -fg $info(label_color)
		entry $f.ce$a -textvariable DFPS_Manager_info(cam_$a) -width $big
		pack $f.cl$a $f.ce$a -side left -expand yes
	}

	set f [frame $w.f[incr i]]
	pack $f -side top -fill x
	label $f.fcpl -text "local_coord\:" -fg $info(label_color)
	entry $f.fcpe -textvariable DFPS_Manager_info(local_coord) -width $big
	pack $f.fcpl $f.fcpe -side left -expand yes
	
	foreach a $info(gscalib_orientations) {
		set f [frame $w.f[incr i]]
		pack $f -side top -fill x
		label $f.maskl$a -text "gscalib_mask_$a\:" -fg $info(label_color)
		entry $f.maske$a -textvariable DFPS_Manager_info(gscalib_mask_$a) -width $big
		pack $f.maskl$a $f.maske$a -side left -expand yes
	}
	
	set f [frame $w.f[incr i]]
	pack $f -side top -fill x
	foreach a {rot_mrad width height} {
		label $f.gsl$a -text "gscalib_$a\:" -fg $info(label_color) -width $sl
		entry $f.gse$a -textvariable DFPS_Manager_info(gscalib_$a) -width $se
		pack $f.gsl$a $f.gse$a -side left -expand yes
	}
	
	foreach a $info(frot_orientations) {
		set f [frame $w.f[incr i]]
		pack $f -side top -fill x
		label $f.ffl$a -text "frot_$a\:" -fg $info(label_color)
		entry $f.ffe$a -textvariable DFPS_Manager_info(frot_$a) -width $big
		pack $f.ffl$a $f.ffe$a -side left -expand yes
	}
	
	set f [frame $w.f[incr i]]
	pack $f -side top -fill x
	foreach a {width height} {
		label $f.ffl$a -text "frot_$a\:" -fg $info(label_color) -width $sl
		entry $f.ffe$a -textvariable DFPS_Manager_info(gscalib_$a) -width $se
		pack $f.ffl$a $f.ffe$a -side left -expand yes
	}
	
	set f [frame $w.f[incr i]]
	pack $f -side top -fill x
	foreach a $info(guide_sensors) {
		label $f.gl$a -text "guide_$a\:" -fg $info(label_color) -width $sl
		entry $f.ge$a -textvariable DFPS_Manager_info(guide_$a) -width $se
		pack $f.gl$a $f.ge$a -side left -expand yes
	}
	
	set f [frame $w.f[incr i]]
	pack $f -side top -fill x
	foreach a $info(fiducial_fibers) {
		label $f.fl$a -text "fiducial_$a\:" -fg $info(label_color) -width $sl
		entry $f.fe$a -textvariable DFPS_Manager_info(fiducial_$a) -width $se
		pack $f.fl$a $f.fe$a -side left -expand yes
	}
	
	set f [frame $w.f[incr i]]
	pack $f -side top -fill x
	foreach a $info(positioner_masts) {
		label $f.fl$a -text "mrange_$a\:" -fg $info(label_color) -width $sl
		entry $f.fe$a -textvariable DFPS_Manager_info(mrange_$a) -width $se
		pack $f.fl$a $f.fe$a -side left -expand yes
	}
	
	foreach b $info(detector_fibers) {
		set f [frame $w.f[incr i]]
		pack $f -side top -fill x
		foreach a $info(positioner_masts) {
			label $f.dfl$a\_$b -text "detector_$a\_$b\:" \
				-fg $info(label_color) -width $sl
			entry $f.dfe$a\_$b \
				-textvariable DFPS_Manager_info(detector_$a\_$b) -width $se
			pack $f.dfl$a\_$b $f.dfe$a\_$b -side left -expand yes
		}
	}

	return ""
}


#
# DFPS_Manager_id_bytes returns a list of two bytes as decimal numbers that
# represent the identifier of the controller. Thus FF10 returns as "255 16".
#
proc DFPS_Manager_id_bytes {id_hex} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set id [string trim $id_hex]
	if {[regexp {([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})} $id match b1 b2]} {
		return "[expr 0x$b1] [expr 0x$b2]"
	} elseif {$id == "*"} {
		return "255 255"
	} else {
		LWDAQ_print $info(text) "ERROR: Bad device identifier \"$id\",\
			defaulting to null identifier."
		return "0 0"
	}
}

#
# DFPS_Manager_transmit takes a string of command bytes and transmits them
# through a Command Transmitter such as the A3029A. The routine appends a
# sixteen-bit checksum. The checksum is the two bytes necessary to return a
# sixteen-bit linear feedback shift register to all zeros, thus performing a
# sixteen-bit cyclic redundancy check. We assume the destination shift register
# is preloaded with the checksum_preload value. The shift register has taps at
# locations 16, 14, 13, and 11. 
#
proc DFPS_Manager_transmit {commands} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	global LWDAQ_Driver
	
	# Append a two-byte checksum.
	set checksum $info(checksum_preload)
	foreach c "$commands 0 0" {
		binary scan [binary format c $c] B8 bits
		for {set i 0} {$i < 8} {set i [expr $i + 1]} {
			set bit [string index $bits $i]
			set fb [string index $checksum 15]
			set new [string range $checksum 5 14]
			set new "[expr [string index $checksum 4] ^ $fb]$new"
			set new "[string index $checksum 3]$new"
			set new "[expr [string index $checksum 2] ^ $fb]$new"
			set new "[expr [string index $checksum 1] ^ $fb]$new"
			set new "[string index $checksum 0]$new"
			set new "[expr $fb ^ $bit]$new"
			set checksum $new
			binary scan [binary format b16 $checksum] cu1cu1 d21 d22
		}
	}
	append commands " $d22 $d21"
		
	# Print the commands to the text window.
	if {[winfo exists $info(utils_text)] && $config(verbose)} {
		LWDAQ_print $info(utils_text) "transmit $commands" $info(vcolor)
	}

	# Open a socket to the command transmitter's LWDAQ server, select the
	# command transmitter, and instruct it to transmit each byte of the
	# command, including the checksum.
	if {[catch {
		set sock [LWDAQ_socket_open $config(ip_addr)]
		set sd $config(spacing_delay)
		LWDAQ_set_driver_mux $sock \
			[lindex $config(transceiver) 0] [lindex $config(transceiver) 1]
		LWDAQ_transmit_command_hex $sock $info(rf_on_op)
		LWDAQ_delay_seconds $sock $config(initiate_delay)
		foreach c $commands {
			LWDAQ_transmit_command_hex $sock "[format %02X $c]$info(rf_xmit_op)"
			if {$sd > 0} {LWDAQ_delay_seconds $sock $sd}
		}
		LWDAQ_transmit_command_hex $sock "0000"
		LWDAQ_delay_seconds $sock \
			[expr $config(byte_processing_time)*[llength $commands]]
		LWDAQ_wait_for_driver $sock
		LWDAQ_socket_close $sock
	} error_result]} {
		if {[info exists sock]} {LWDAQ_socket_close $sock}
		LWDAQ_print $info(text) "ERROR: $error_result"
		if {[winfo exists $info(utils_text)]} {
			LWDAQ_print $info(utils_text) "ERROR: $error_result"
		}
		return "ERROR: $error_result"
	}
	
	# If we get here, we have no reason to believe the transmission failed, although
	# we could have instructed an empty driver socket or the positioner could have
	# failed to receive the command.
	return "$commands"
}

#
# DFPS_Manager_voltage_set takes the upleft and upright control values and
# instructs the named positioner to set its converters accordingly. The control
# values must be unsigned integers between 0 and 65535. If the values exceed
# this range, they will be clipped to the range. The return string consits of
# the controller id and the DAC values that were applied, clipped if clipped.
#
proc DFPS_Manager_voltage_set {id upleft upright} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	if {$upleft > $info(dac_max)} {
		set upleft $info(dac_max)
	}
	if {$upright > $info(dac_max)} {
		set upright $info(dac_max)
	}
	if {$upleft < $info(dac_min)} {
		set upleft $info(dac_min)
	}
	if {$upright < $info(dac_min)} {
		set upright $info(dac_min)
	}
	
	set commands [DFPS_Manager_id_bytes $id]
	set n $upleft
	set s [expr 65535 - $upleft]
	set e $upright
	set w [expr 65535 - $upright]
	append commands " 1 [expr $n / 256] [expr $n % 256]\
		2 [expr $s / 256] [expr $s % 256]\
		3 [expr $e / 256] [expr $e % 256]\
		4 [expr $w / 256] [expr $w % 256]"
	set commands [DFPS_Manager_transmit $commands]
	if {[LWDAQ_is_error_result $commands]} {
		return $commands
	} else {
		return "$id $upleft $upright"
	}
}
		
#
# DFPS_Manager_move sets the drive voltages of a mast's actuators to the
# specified values. We give the mast index. In a system with four masts, the
# index will be 1-4.
#
proc DFPS_Manager_move {mast upleft upright} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	if {![winfo exists $info(window)]} {
		return ""
	}
	
	set id [lindex $config(controllers) [expr $mast-1]]
	set result [DFPS_Manager_voltage_set $id $upleft $upright]
	if {![LWDAQ_is_error_result $result] && $config(verbose)} {
		scan $result %d%f%f id upleft upright
		LWDAQ_print $info(text) "move id=0x$id\
			upleft=$upleft upright=$upright" $info(vcolor)
	}

	return "$result"
}

#
# DFPS_Manager_set_all sets the drive voltages of all actuators to the values 
# specified in the upleft and upright configuration parameters.
#
proc DFPS_Manager_set_all {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set info(utils_state) "SetAll"
	foreach m $info(positioner_masts) {
		set info(voltage_$m) "$config(upleft) $config(upright)"
	}
	DFPS_Manager_voltage_set $info(wildcard_id) $config(upleft) $config(upright)
	if {[winfo exists $info(utils_text)]} {
		LWDAQ_print $info(utils_text) "Voltages: $config(upleft) $config(upright)"
	}
	set info(utils_state) "Idle"
	return ""
}

#
# DFPS_Manager_zero_all sets the drive voltages of all mast actuators to their 
# zero values.
#
proc DFPS_Manager_zero_all {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	
	set info(utils_state) "ZeroAll"	
	foreach m $info(positioner_masts) {
		set info(voltage_$m) "$info(dac_zero) $info(dac_zero)"
	}
	DFPS_Manager_voltage_set $info(wildcard_id) $info(dac_zero) $info(dac_zero)
	if {[winfo exists $info(utils_text)]} {
		LWDAQ_print $info(utils_text) "Voltages: $info(dac_zero) $info(dac_zero)"
	}
	set info(utils_state) "Idle"
	return ""
}

#
# DFPS_Manager_move_all adds a displacement to the mast target positions.
#
proc DFPS_Manager_move_all {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	
	set info(utils_state) "MoveAll"	
	set move_report "move_all "
	foreach m $info(positioner_masts) {
		scan $info(target_$m) %f%f xt yt
		scan $config(displacement) %f%f xd yd
		set xt [format %.3f [expr $xt+$xd]]
		set yt [format %.3f [expr $yt+$yd]]
		set info(target_$m) "$xt $yt"
		append move_report "$xt $yt "
		scan $info(mast_$m) %f%f xm ym
		set xo [format %.3f [expr $xm-$xt]]
		set yo [format %.3f [expr $ym-$yt]]
		set info(offset_$m) "$xo $yo"
	}
	if {[winfo exists $info(utils_text)]} {
		LWDAQ_print $info(utils_text) $move_report
	}
	set info(utils_state) "Idle"
	return ""
}

#
# DFPS_Manager_spots captures an image of the sources whose light sources are
# listed in the leds argument. If we pass an empty string for the elements, the
# routine combines the fiducial and guide elements to obtain a list of all
# available sources. It returns the coordinates of the two images of each source
# in the left and right cameras in the format "x1l y1l x1r y1r... xnl ynl xnr
# ynr", where "n" is the number of sources it flashes.
#
proc DFPS_Manager_spots {{leds ""}} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	upvar #0 LWDAQ_config_BCAM iconfig
	upvar #0 LWDAQ_info_BCAM iinfo
	
	# Default leds.
	if {$leds == ""} {
		set leds [string trim "$config(fiducial_leds) $config(guide_leds)"]
	}
	
	# Prepare the BCAM Instrument for fiber view camera (FVC) acquisition.
	set iconfig(daq_ip_addr) $config(ip_addr)
	set iconfig(daq_source_driver_socket) [lindex $config(injector) 0]
	set iconfig(daq_source_mux_socket) [lindex $config(injector) 1]
	set iconfig(daq_source_device_element) $leds 
	set iinfo(daq_source_device_type) $config(source_type)
	set iinfo(daq_source_power) $config(source_pwr)
	set iconfig(daq_device_element) $config(camera_element)
	set iconfig(daq_flash_seconds) $config(flash_s)
	set iconfig(analysis_num_spots) \
		"[llength $iconfig(daq_source_device_element)] $config(sort_code)"
	set iconfig(analysis_threshold) $config(analysis_threshold)
	
	# Acquire from both FVCs.
	foreach side {left right} {
		set iconfig(daq_driver_socket) [lindex $config(fvc_$side) 0]
		set iconfig(daq_mux_socket) [lindex $config(fvc_$side) 1]
		set result [LWDAQ_acquire BCAM]
		if {[LWDAQ_is_error_result $result]} {
			LWDAQ_print $info(text) "$result"
			return "$result"
		} else {
			if {$config(verbose)} {
				LWDAQ_print -nonewline $info(text) "spots side=$side "  $info(vcolor)
				foreach {x y n m e t} [lrange $result 1 end] {
					LWDAQ_print -nonewline $info(text) "x=$x y=$y "  $info(vcolor)
				}
				LWDAQ_print $info(text) ""
			}
			set result_$side [lrange $result 1 end]
			lwdaq_image_manipulate $iconfig(memory_name) \
				copy -name $info(image_$side)
			lwdaq_image_manipulate $info(image_$side) \
				transfer_overlay $iconfig(memory_name)
			lwdaq_draw $info(image_$side) dfps_fvc_$side \
				-intensify $config(intensify) -zoom $config(fvc_zoom)
		}
		
	}
	
	# Parse result string.
	set spots ""
	foreach led $leds {
		foreach side {left right} {
			append spots "[lindex [set result_$side] 0] [lindex [set result_$side] 1] "
			set result_$side [lrange [set result_$side] 6 end]
		}
	}
	
	# Return the spot list.
	return [string trim $spots]
}

#
# DFPS_Manager_show_spots flashes all the fiducials and guides so we can see their
# images in the fiber view images. It finds all the spots, but may get them mixed
# up.
#
proc DFPS_Manager_show_spots {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set info(state) "Show"
	set result [DFPS_Manager_spots]
	set info(state) "Idle"
	return $result
}

#
# DFPS_Manager_sources_global calculates source positions in global coordinates
# from a set of left and right camera image positions. Each image is a "spot"
# with a centroid position measured in microns from the center of the image
# sensor's top-left pixel. We pass it a list containing the coordinates of the
# spots in the forma "x1l y1l x1r y1r... xnl ynl xnr ynr" where "n" is the
# number of sources, "l" specifies the left camera, and "r" specifies the right
# camera. The routine returns a list of source positions in "x1 y1 z1 ... xn yn
# zn" in global coordinates. The routine checks to see if the spot positions are
# invalid, which is marked by coordinates "-1 -1 -1 -1", and if so, it returns
# for the source position the global coordinate origin.
#
proc DFPS_Manager_sources_global {spots} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	# Refresh the left and right camera mount coordinate systems in case we have
	# changed the left and right mounting ball coordinates since our previous
	# use of the mount coordinates. We need six decimal places of resolution in
	# order to get the angles correct.
	set info(coord_left) [lwdaq bcam_coord_from_mount $info(mount_left)]
	set info(coord_right) [lwdaq bcam_coord_from_mount $info(mount_right)]

	# For each source, we extract the left and right camera spot coordinates and
	# use these to measure the source position.
	set sources ""
	foreach {x_left y_left x_right y_right} $spots {
	
		# If our spot positions are "-1", set the source position to the global origin.
		if {$x_left == "-1"} {
			append sources "0 0 0 0 "
			continue
		}
		
		# For each camera, we transform the image position in to mount
		# coordinates, then project the image position through the pivot point
		# of the camera to obtain a bearing line. We transform the bearing line
		# into global coordinates.
		foreach side {left right} {
			set x [expr 0.001 * [set x_$side]]
			set y [expr 0.001 * [set y_$side]]
			set b [lwdaq bcam_source_bearing "$x $y" "$side $info(cam_$side)"]
			set point_$side [lwdaq xyz_global_from_local_point \
				[lrange [set b] 0 2] $info(coord_$side)]
			set dir_$side [lwdaq xyz_global_from_local_vector \
				[lrange [set b] 3 5] $info(coord_$side)]
		}
		
		# Find the point and direction that define the shortest vector between the
		# two bearings in global coordinates.
		set bridge [lwdaq xyz_line_line_bridge \
			"$point_left $dir_left" "$point_right $dir_right"]
		scan $bridge %f%f%f%f%f%f x y z dx dy dz
		
		# Use the midpoint of this vector as our position measurement, append to
		# our source list.
		set x_g [format %.3f [expr $x + 0.5*$dx]]
		set y_g [format %.3f [expr $y + 0.5*$dy]]
		set z_g [format %.3f [expr $z + 0.5*$dz]]
		set sg "$x_g $y_g $z_g"
		append sources "$sg "
		if {$config(verbose)} {
			LWDAQ_print $info(text) "sources_global $sg" $info(vcolor)
		}
	}

	return [string trim $sources]	
}

#
# DFPS_Manager_local_from_global takes a list global points and transforms them into
# local coordinates using the local coordinate pose. The list must be a string of
# x, y, z values separated by spaces. The DFPS global coordinate system is defined by
# three half-inch steel balls sitting on the base plate in front of the fiducial stage.
# The DFPS local coordinate system is defined by its fiducial plate. The fiducial plate
# defines a frame coordinate system with its front, lower-left corner as the frame coordinate
# origin, the bottom front edge as the frame coordinate x-axis, and the y-axis perpendiculare to the fiducial stage. The local coordinates are at x=local_coord_offset, y=local_coord_offset
# in frame coordinates. In the DFPS-4A, local_coord_offset = 65 mm.
#
proc DFPS_Manager_local_from_global {points} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set lp ""
	foreach {x y z} $points {
		append lp [lwdaq xyz_local_from_global_point "$x $y $z" $info(local_coord)]
		append lp " "
	}
	return [string trim $lp]
}

#
# DFPS_Manager_global_from_local takes a list local points and transforms them into
# global coordinates using the local coordinate pose. The list must be a string of
# x, y, z values separated by spaces.
#
proc DFPS_Manager_global_from_local {points} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set gp ""
	foreach {x y z} $points {
		append gp [lwdaq xyz_global_from_local_point "$x $y $z" $info(local_coord)]
		append gp " "
	}
	return [string trim $gp]
}

#
# DFPS_Manager_mast_measure returns the local coordinates of a mast. We take the
# optical centroid of the mast's guide fiber to define the mast position. The
# routine takes a mast number as input. It returns the x, y, and z coordinates
# of the guide fiber in local coordinates. The routine first measures the
# position of the masts in global coordinates, then uses the local coordinate
# pose to transform into local coordinates. We assume the local coordinate pose
# is correct.
#
proc DFPS_Manager_mast_measure {mast} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	
	if {![winfo exists $info(window)]} {
		return ""
	}
	
	set info(state) "Measure"	

	if {[lsearch $info(positioner_masts) $mast] < 0} {
		set result "ERROR: No mast \"$mast\" in mast_measure."
		LWDAQ_print $info(text) $result
		set info(state) "Idle"
		return $result
	}
	
	set led [lindex $config(guide_leds) [expr $mast-1]]
	
	set spots [DFPS_Manager_spots $led]
	if {[LWDAQ_is_error_result $spots]} {
		set info(state) "Idle"
		return $spots
	}
	set mast_global [DFPS_Manager_sources_global $spots]
	set mast_local [DFPS_Manager_local_from_global $mast_global]
	
	scan $mast_local %f%f%f x y z
	set info(mast_$mast) "[format %.3f $x] [format %.3f $y]"
	scan $info(target_$mast) %f%f xt yt
	set xo [format %.3f [expr $x - $xt]]
	set yo [format %.3f [expr $y - $yt]]
	set info(offset_$mast) "$xo $yo"
	if {$config(verbose)} {
		LWDAQ_print $info(text) "mast_measure x=$x y=$y z=$z\
			xo=$xo yo=$yo" $info(vcolor)
	}
		
	set info(state) "Idle"	
	return $mast_local
}

#
# DFPS_Manager_fvcalib_get_params puts together a string containing the parameters
# the fitter can adjust to minimise the calibration disagreement. The fitter
# will adjust any parameter for which we assign a scaling value greater than 
# zero. The scaling string gives the scaling factors the fitter uses for each
# camera calibration constant. The scaling factors are used twice: once for 
# the left camera and once for the right. See the fitting routine for their
# implementation.
#
proc DFPS_Manager_fvcalib_get_params {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set params "$info(cam_left) $info(cam_right)"
	return $params
}

#
# DFPS_Manager_fvcalib_disagreement calculates root mean square square distance
# between the actual image positions and the modeled image positions we obtain
# when applying our mount measurements, FVC calibration constants, and measured
# source positions. We pass our FVC calibration constants into the routine with
# the params argument. If we omit this argument, the routine uses the constants
# stored in the left and right camera entries of our config array. Another
# optional parameter enables or disables the display of the blue crosses that
# show where the current parameters suggest the sources must be. By default, the
# display is enabled. This routine is called by the simplex fitter two or three
# hundred times do obtain the optimal camera calibration constants. The fit
# takes a fraction of a second with the display disabled, roughly ten seconds
# with the display enabled. All the time goes into clearing and drawing the
# images on the screen.
#
proc DFPS_Manager_fvcalib_disagreement {{params ""} {show "1"}} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	# If user has closed the manager window, generate an error so that we stop
	# any fitting that might be calling this routine. 
	if {![winfo exists $info(window)]} {
		error "No DFPS window open."
	}
	
	# If no parameters specified, use those stored in configuration array.
	if {$params == ""} {
		set params [DFPS_Manager_fvcalib_get_params]
	}
	
	# Extract the two sets of camera calibration constants from the parameters passed
	# to us by the fitter.
	set fvc_left "FVC_L [lrange $params 0 7]"
	set fvc_right "FVC_R [lrange $params 8 15]"
	
	# Clear the overlay if showing.
	if {$show} {
		foreach side {left right} {
			lwdaq_image_manipulate $info(fvcalib_$side) none -clear 1
		}
	}	
	
	# Go through the four sources. For each source, we calculate the modelled
	# image position in each camera. We look up the actual image position in
	# each camera, as we obtained when we read the two images. We square the
	# distance between the actual and modelled positions and add to our
	# disagreement.
	set sum_squares 0
	set count 0
	foreach side {left right} {
		set spots $info(spots_$side)
		for {set a 1} {$a <= $info(num_sources)} {incr a} {
			set sb [lwdaq xyz_local_from_global_point \
				$info(fvcalib_fid_$a) $info(coord_$side)]
			set th [lwdaq bcam_image_position $sb [set fvc_$side]]
			scan $th %f%f x_th y_th
			set x_th [format %.2f [expr $x_th * 1000.0]]
			set y_th [format %.2f [expr $y_th * 1000.0]]
			set x_a [lindex $spots 0]
			set y_a [lindex $spots 1]
			set spots [lrange $spots 2 end]
			set err [expr ($x_a-$x_th)*($x_a-$x_th) + ($y_a-$y_th)*($y_a-$y_th)]
			set sum_squares [expr $sum_squares + $err]
			incr count
			
			if {$show} {
				set y [expr $info(bcam_height_um) - $y_th]
				set x $x_th
				set w $config(cross_size)
				lwdaq_graph "[expr $x - $w] $y [expr $x + $w] $y" \
					$info(fvcalib_$side) -entire 1 \
					-x_min 0 -x_max $info(bcam_width_um) \
					-y_min 0 -y_max $info(bcam_height_um) -color 2
				lwdaq_graph "$x [expr $y - $w] $x [expr $y + $w]" \
					$info(fvcalib_$side) -entire 1 \
					-x_min 0 -x_max $info(bcam_width_um) \
					-y_min 0 -y_max $info(bcam_height_um) -color 2
			}
		}
	}
	
	# Calculate root mean square error.
	set err [format %.3f [expr sqrt($sum_squares/$count)]]	
	
	# Draw the boxes and rectangles if showing.
	if {$show} {
		foreach side {left right} {
			lwdaq_draw $info(fvcalib_$side) fvcalib_$side \
				-intensify $config(fvcalib_intensify) -zoom $config(fvcalib_zoom)
		}
	}
	
	# Return the total disagreement, which is our error value.
	return $err
}

#
# DFPS_Manager_fvcalib_show calls the disagreement function to show the location of 
# the modelled sources, and prints the calibration constants and disagreement
# to the text window, followed by a zero to indicated that zero fitting steps
# took place to produce these parameters and results.
#
proc DFPS_Manager_fvcalib_show {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	
	set info(coord_left) [lwdaq bcam_coord_from_mount $info(mount_left)]
	set info(coord_right) [lwdaq bcam_coord_from_mount $info(mount_right)]
	set err [DFPS_Manager_fvcalib_disagreement]
	foreach v "[DFPS_Manager_fvcalib_get_params] $err" {
		LWDAQ_print -nonewline $info(fvcalib_text) "[format %.3f $v] "
	}
	
	return ""
}

#
# DFPS_Manager_fvcalib_check projects the image of each source in the left and right
# cameras to make a bearing line in the left and right mount coordinates using
# the current camera calibration constants, transforms to global coordinates
# using the mounting ball coordinates, and finds the mid-point of the shortest
# line between these two lines. This mid-point is the FVC measurement of the
# source position. It compares this position to the measured source position and
# reports the difference between the two.
#
proc DFPS_Manager_fvcalib_check {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	
	LWDAQ_print $info(fvcalib_text) "\nGlobal Measured Position and Error\
		(xm, ym, zm, xe, ye, ze in mm):" purple
	set sources ""
	set sum_squares 0.0
	for {set i 1} {$i <= 4} {incr i} {	
		foreach side {left right} {
			set x [expr 0.001 * [lindex $info(spots_$side) [expr ($i-1)*2]]]
			set y [expr 0.001 * [lindex $info(spots_$side) [expr ($i-1)*2+1]]]
			set b [lwdaq bcam_source_bearing "$x $y" "$side $info(cam_$side)"]
			set point_$side [lwdaq xyz_global_from_local_point \
				[lrange [set b] 0 2] $info(coord_$side)]
			set dir_$side [lwdaq xyz_global_from_local_vector \
				[lrange [set b] 3 5] $info(coord_$side)]
		}
		
		set bridge [lwdaq xyz_line_line_bridge \
			"$point_left $dir_left" "$point_right $dir_right"]
		scan $bridge %f%f%f%f%f%f x y z dx dy dz
		
		set x_src [format %8.3f [expr $x + 0.5*$dx]]
		set y_src [format %8.3f [expr $y + 0.5*$dy]]
		set z_src [format %8.3f [expr $z + 0.5*$dz]]
		
		set a $info(fvcalib_fid_$i)
		set x_err [format %6.3f [expr [lindex $a 0]-$x_src]]
		set y_err [format %6.3f [expr [lindex $a 1]-$y_src]]
		set z_err [format %6.3f [expr [lindex $a 2]-$z_src]]
		
		LWDAQ_print $info(fvcalib_text) "fvcalib_fid_$i\: $x_src $y_src $z_src\
			$x_err $y_err $z_err"
		
		set sum_squares [expr $sum_squares + $x_err*$x_err \
			+ $y_err*$y_err + $z_err*$z_err] 
	}

	set err [expr sqrt($sum_squares / $info(num_sources))]
	LWDAQ_print $info(fvcalib_text) "Root Mean Square Error (mm): [format %.3f $err]\n"

	return ""
}

#
# DFPS_Manager_fvcalib_read either reads a specified CMM measurement file or
# browses for one. The fiber view calibrator reads the global coordinates of the
# balls in the left and right FVC mounts, and the locations of the four
# calibration sources. Having read the CMM file the routine looks for L.gif and
# R.gif in the same directory. These should be the images returned by the left
# and right FVCs of the four calibration sources. In these two images, the
# sources must be arranged from 1 to 4 in an x-y grid, as recognised by the BCAM
# Instrument.
#
proc DFPS_Manager_fvcalib_read {{fn ""}} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	upvar #0 LWDAQ_config_BCAM iconfig
	upvar #0 LWDAQ_info_BCAM iinfo

	if {$info(fvcalib_state) != "Idle"} {return ""}
	set info(fvcalib) "Reading"
	LWDAQ_update
	
	if {$fn == ""} {set fn [LWDAQ_get_file_name]}
	if {$fn == ""} {
		set info(fvcalib) "Idle"
		return ""
	} {
		set img_dir [file dirname $fn]
	}
	
	LWDAQ_print $info(fvcalib_text) "\nReading measurements from disk." purple
	
	LWDAQ_print $info(fvcalib_text) "Reading CMM measurements from [file tail $fn]."
	set f [open $fn r]
	set cmm [read $f]
	close $f
	set numbers [list]
	foreach a $cmm {if {[string is double -strict $a]} {lappend numbers $a}}
	set spheres [list]
	foreach {d x y z} $numbers {
		lappend spheres "$x $y $z"
	}
	set info(mount_left) [join [lrange $spheres 3 5]]
	LWDAQ_print $info(fvcalib_text) "Left Mount: $info(mount_left)"
	set info(mount_right) [join [lrange $spheres 6 8]]
	LWDAQ_print $info(fvcalib_text) "Right Mount: $info(mount_right)"
	set spheres [lrange $spheres 9 end]
	for {set a 1} {$a <= $info(num_sources)} {incr a} {
		set info(fvcalib_fid_$a) [lindex $spheres [expr $a-1]]
		LWDAQ_print $info(fvcalib_text) "Fiducial $a\: $info(fvcalib_fid_$a)"
	}

	set info(coord_left) [lwdaq bcam_coord_from_mount $info(mount_left)]
	set info(coord_right) [lwdaq bcam_coord_from_mount $info(mount_right)]

	foreach {s side} {L left R right} {
		LWDAQ_print $info(fvcalib_text) \
			"Reading and analyzing image $s\.gif from $side camera."
		set ifn [file join $img_dir $s\.gif]
		if {[file exists $ifn]} {
			LWDAQ_read_image_file $ifn $info(fvcalib_$side)
			set iconfig(analysis_num_spots) "$info(num_sources) $config(bcam_sort)"
			set iconfig(analysis_threshold) $config(analysis_threshold)
			set info(bcam_width_um) [expr $iinfo(daq_image_width) \
				* $iinfo(analysis_pixel_size_um)]
			set info(bcam_height_um) [expr $iinfo(daq_image_height) \
				* $iinfo(analysis_pixel_size_um)]
			set result [LWDAQ_analysis_BCAM $info(fvcalib_$side)]
			if {![LWDAQ_is_error_result $result]} {
				set info(spots_$side) ""
				foreach {x y num pk acc th} $result {
					append info(spots_$side) "$x $y "
				}
			} else {
				LWDAQ_print $info(fvcalib_text) $result
				set info(fvcalib) "Idle"
				return $result
			}
		}
	}

	set err [DFPS_Manager_fvcalib_disagreement]
	LWDAQ_print $info(fvcalib_text) "Current spot position fit error is $err um rms.\n"

	set info(fvcalib) "Idle"
	return ""
}

#
# DFPS_Manager_fvcalib_displace displaces the camera calibration constants by a
# random amount in proportion to their scaling factors. The routine does not
# print anything to the text window, but if show_fit is set, it does update the
# modelled source positions in the image. We want to be able to use this routine
# repeatedly to move the modelled sources around before starting a new fit,
# while reserving the text window for the fitted end values.
#
proc DFPS_Manager_fvcalib_displace {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	foreach side {left right} {
		for {set i 0} {$i < [llength $info(cam_$side)]} {incr i} {
			lset info(cam_$side) $i [format %.3f \
				[expr [lindex $info(cam_$side) $i] \
					+ ((rand()-0.5) \
						*$config(displace_scale) \
						*[lindex $config(fit_scaling) $i])]]
		}
	}
	DFPS_Manager_fvcalib_disagreement
	return ""
} 

#
# DFPS_Manager_fvcalib_defaults restores the cameras to their default, nominal
# calibration constants.
#
proc DFPS_Manager_fvcalib_defaults {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	foreach side {left right} {
		set info(cam_$side) $info(cam_default)
	}
	DFPS_Manager_fvcalib_disagreement
	return ""
} 

#
# DFPS_Manager_fvcalib_altitude is the error function for the fitter. The fitter calls
# this routine with a set of parameter values to get the disgreement, which it
# is attemptint to minimise.
#
proc DFPS_Manager_fvcalib_altitude {params} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	if {$config(fit_stop)} {error "Fit aborted by user"}
	if {![winfo exists $info(window)]} {error "Tool window destroyed"}
	set altitude [DFPS_Manager_fvcalib_disagreement "$params" $config(fit_show)]
	LWDAQ_support
	return $altitude
}

#
# DFPS_Manager_fvcalib_fit gets the camera calibration constants as a starting point
# and calls the simplex fitter to minimise the disagreement between the modelled
# and actual bodies by adjusting the calibration constants of both parameter.
# The size of the adjustments the fitter makes in each parameter during the fit
# will be shrinking as the fit proceeds, but relative to one another thye will
# be in proportion to the list of scaling factors we have provided. These
# factors are applied twice: once to each camera. If the scaling factors are all
# unity, all parameters are fitted with equal steps. If a scaling factor is
# zero, the parameter will not be adjusted. If a scaling factor is 10, the
# parameter will be adjusted by ten times the amount as a parameter with scaling
# factor one. At the end of the fit, we take the final fitted parameter values
# and apply them to our body models.
#
proc DFPS_Manager_fvcalib_fit {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set config(fit_stop) 0
	set info(fvcalib) "Fitting"
	
	if {$config(verbose)} {
		LWDAQ_print $info(fvcalib_text) "\nFitting camera parameters with\
			fit_show=$config(fit_show),\
			fit_details=$config(fit_details)." purple
	}
	set start_time [clock milliseconds]
	set scaling "$config(fit_scaling) $config(fit_scaling)"
	set start_params [DFPS_Manager_fvcalib_get_params] 
	set info(coord_left) [lwdaq bcam_coord_from_mount $info(mount_left)]
	set info(coord_right) [lwdaq bcam_coord_from_mount $info(mount_right)]
	lwdaq_config -show_details $config(fit_details) -text_name $info(fvcalib_text)
	lwdaq_config -fsd 3
	
	set end_params [lwdaq_simplex $start_params \
		DFPS_Manager_fvcalib_altitude \
		-report $config(fit_show) \
		-steps $config(fit_steps) \
		-restarts $config(fit_restarts) \
		-start_size $config(fit_startsize) \
		-end_size $config(fit_endsize) \
		-scaling $scaling]
	lwdaq_config -show_details 0 -text_name $info(text)
	if {[LWDAQ_is_error_result $end_params]} {
		LWDAQ_print $info(fvcalib_text) $error_message
		set info(fvcalib) "Idle"
		return $error_message
	}
	
	lwdaq_config -fsd 6
	set info(cam_left) "[lrange $end_params 0 7]"
	set info(cam_right) "[lrange $end_params 8 15]"
	set disagreement [lindex $end_params 16]
	set iterations [lindex $end_params 17]
	foreach v [join "$info(cam_left) [join $info(cam_right)] $disagreement"] {
		LWDAQ_print -nonewline $info(fvcalib_text) "[format %.3f $v] "
	}
	LWDAQ_print $info(fvcalib_text) "$iterations"
	if {$config(verbose)} {
		LWDAQ_print $info(fvcalib_text) "Fit converged in\
			[format %.2f [expr 0.001*([clock milliseconds]-$start_time)]] s\
			and [lindex $end_params 17] steps,\
			final error [format %.1f [lindex $end_params 16]] um." purple
	}

	DFPS_Manager_fvcalib_disagreement
	set info(fvcalib) "Idle"
	return $end_params
}

#
# DFPS_Manager_fvcalib opens the Fiber View Camera Calibrator window.
#
proc DFPS_Manager_fvcalib {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set w $info(window)\.fvcalib
	if {![winfo exists $w]} {
		toplevel $w
		wm title $w "Fiber View Camera Coordinate Measurement Machine Calibrator,\
			DFPS Manager $info(version)"
	} {
		raise $w
	}
	
	set f [frame $w.controls]
	pack $f -side top -fill x
	
	label $f.state -textvariable DFPS_Manager_info(fvcalib) -width 20 -fg blue
	pack $f.state -side left -expand 1
	
	button $f.stop -text "Stop" -command {set DFPS_Manager_config(fit_stop) 1}
	pack $f.stop -side left -expand yes

	foreach a {Read Show Check Displace Defaults Fit} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post DFPS_Manager_fvcalib_$b"
		pack $f.$b -side left -expand yes
	}
	checkbutton $f.verbose -text "Verbose" -variable DFPS_Manager_config(verbose)
	pack $f.verbose -side left -expand yes

	set f [frame $w.fvc]
	pack $f -side top -fill x
	
	foreach {a wd} {analysis_threshold 6 fit_steps 8 fit_restarts 3 \
			fit_endsize 10 fit_show 2 fit_details 2 fit_scaling 20} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable DFPS_Manager_config($a) -width $wd
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	set f [frame $w.cameras]
	pack $f -side top -fill x

	foreach {a wd} {cam_left 50 cam_right 50} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable DFPS_Manager_info($a) -width $wd
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	set f [frame $w.images]
	pack $f -side top -fill x

	foreach a {left right} {
		image create photo "fvcalib_$a"
		label $f.$a -image "fvcalib_$a"
		pack $f.$a -side left -expand yes
	}
	
	set info(fvcalib_text) [LWDAQ_text_widget $w 120 15]
	LWDAQ_print $info(fvcalib_text) \
		"Fiber View Camera CMM Calibration Text Output" purple
	
	foreach side {left right} {
		lwdaq_draw $info(fvcalib_$side) fvcalib_$side \
			-intensify $config(fvcalib_intensify) -zoom $config(fvcalib_zoom)
	}
	
	return $w
}

#
# DFPS_Manager_guide_acquire acquires an image from one of the DFPS guide
# sensors with a specified exposure time. It stores the image in the LWDAQ image
# array with the name dfps_guide_n, where n is the guide sensor number. It
# returns a string of information about the image, as obtained from the Camera
# Instrument. If the string is an error message, it will begin with "ERROR:".
# Otherwise it will contain the word "Guide_n" where n is the guide number,
# followed by the left, top, right, and bottom analysis boundaries, the average,
# stdev, maximum, and minimum intensity, and finally the number or rows and the
# number of columns. Multiply the number of rows by the number of columns to get
# the image size in bytes.
#
proc DFPS_Manager_guide_acquire {guide exposure_s} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	upvar #0 LWDAQ_config_Camera iconfig 

	set iconfig(analysis_manipulation) $info(guide_manipulations)
	set iconfig(daq_ip_addr) $config(ip_addr)
	set iconfig(intensify) $config(intensify) 
	scan $config(guide_daq_$guide) %d%d%d \
		iconfig(daq_driver_socket) \
		iconfig(daq_mux_socket) \
		iconfig(daq_device_element)
	set iconfig(daq_exposure_seconds) $exposure_s
	set camera [LWDAQ_acquire Camera]
	if {![LWDAQ_is_error_result $camera]} {
		lwdaq_image_manipulate $iconfig(memory_name) copy -name dfps_guide_$guide
		lwdaq_draw dfps_guide_$guide dfps_guide_$guide \
			-intensify $config(intensify) -zoom $config(guide_zoom)
		if {[winfo exists $info(window).mag_$guide]} {
			lwdaq_draw dfps_guide_$guide dfps_guide_mag_$guide \
				-intensify $config(intensify) -zoom $config(guide_mag_zoom)
		}
		set camera "Guide_$guide [lrange $camera 1 end]"
	} else {
		LWDAQ_print $info(text) $camera
	}
	return $camera
}

#
# DFPS_Manager_gscalib_acquire reads images from all four guide sensors,
# analyzes them with the correct orientation codes, displayes them in the
# gscalib window and returns the mask x and y coordinates of the top-left
# corner of the image, as well as the anti-clockwise rotation of the mask image
# with respect to the image sensor. We must specify an orientation of the
# fiducial plate so that we can get the rasnik analysis orientation code
# correct.
#
proc DFPS_Manager_gscalib_acquire {orientation} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	upvar #0 LWDAQ_config_Rasnik iconfig 
	upvar #0 LWDAQ_info_Rasnik iinfo

	set info(gscalib_state) "Acquire"

	set i [lsearch $info(gscalib_orientations) $orientation]
	set ocode 0
	set swap 0
	if {$i >= 0} {
		set ocode [lindex $config(gscalib_orientation_codes) $i]
		set swap [lindex $info(gscalib_swaps) $i]
	}
	
	set iconfig(analysis_orientation_code) $ocode
	set iconfig(analysis_enable) $config(gscalib_algorithm)
	set iconfig(analysis_reference_code) $info(gscalib_refcode)
	set iconfig(analysis_square_size_um) $config(gscalib_square_um)
	set iinfo(analysis_reference_x_um) $config(gscalib_ref_x_um)
	set iinfo(analysis_reference_y_um) $config(gscalib_ref_y_um)
	set iconfig(image_source) "memory"

	set result ""
	foreach guide $info(guide_sensors) {
		set esuffix " (Guide $guide, Orient $orientation, Time [clock seconds])"
		set camera [DFPS_Manager_guide_acquire $guide $config(gscalib_flash_s)]
		if {[LWDAQ_is_error_result $camera]} {
			LWDAQ_print $info(gscalib_text) "$camera $esuffix"
			append result "-1 -1 -1 "
			continue
		}
		set iconfig(memory_name) dfps_guide_$guide
		set rasnik [LWDAQ_acquire Rasnik]
		lwdaq_draw dfps_guide_$guide gscalib_$guide \
			-intensify $config(gscalib_intensify) -zoom $config(gscalib_zoom)
		if {![LWDAQ_is_error_result $rasnik]} {
			if {$swap} {
				append result "[format %.3f [expr 0.001*[lindex $rasnik 2]]]\
					[format %.3f [expr 0.001*[lindex $rasnik 1]]]\
					[lindex $rasnik 5] "
			} else {
				append result "[format %.3f [expr 0.001*[lindex $rasnik 1]]]\
					[format %.3f [expr 0.001*[lindex $rasnik 2]]]\
					[lindex $rasnik 5] "
			}
		} else {
			LWDAQ_print $info(gscalib_text) "$rasnik $esuffix"
			append result "-1 -1 -1 "
		}
	}
	
	if {$orientation != ""} {set info(gscalib_mask_$orientation) $result}
	LWDAQ_print $info(gscalib_text) "[format %3d $orientation] $result" 
	set info(gscalib_state) "Idle"
	return $result
}

#
# DFPS_Manager_gscalib_calculate takes the four rasnik measurements we have
# obtained from the four orientations of the mask and calculates the mask origin
# in frame coordiates, the mask rotation with respect to frame coordinates,
# counter-clockwise positive, and the origins of the four guide sensors in frame
# coordinates as well as their rotations counter-clockwise positive with respect
# to frame coordinates.
#
proc DFPS_Manager_gscalib_calculate {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	
	set info(gscalib_state) "Calculate"
	LWDAQ_update

	LWDAQ_print $info(gscalib_text) "\nRasnik Mask Center" purple
	LWDAQ_print $info(gscalib_text) "------------------------------------" 
	LWDAQ_print $info(gscalib_text) "  O1   O2   GS     X (mm)     Y (mm)" 
	LWDAQ_print $info(gscalib_text) "------------------------------------" 
	set sum_x "0.0"
	set sum_y "0.0"
	set sum_sqr_x "0.0"
	set sum_sqr_y "0.0"
	set cnt 0
 	foreach {o1 o2} "0 180 90 270" {
		set m1 $info(gscalib_mask_$o1)
		set m2 $info(gscalib_mask_$o2)
		foreach gs $info(guide_sensors) {
			set x1 [lindex $m1 [expr ($gs-1)*3+0]]
			set y1 [lindex $m1 [expr ($gs-1)*3+1]]
			set x2 [lindex $m2 [expr ($gs-1)*3+0]]
			set y2 [lindex $m2 [expr ($gs-1)*3+1]]
			set x [expr 0.5*($x1+$x2)]
			set y [expr 0.5*($y1+$y2)]
			LWDAQ_print $info(gscalib_text) "[format %4d $o1]\
				[format %4d $o2]\
				[format %4d $gs]\
				[format %10.3f $x]\
				[format %10.3f $y]"
			set sum_x [expr $sum_x + $x]
			set sum_y [expr $sum_y + $y]
			set sum_sqr_x [expr $sum_sqr_x + ($x*$x)]
			set sum_sqr_y [expr $sum_sqr_y + ($y*$y)]
			incr cnt
		}
	}
	LWDAQ_print $info(gscalib_text) "------------------------------------" 
	set x_ave [expr $sum_x/$cnt]
	set y_ave [expr $sum_y/$cnt]
	LWDAQ_print $info(gscalib_text) "Average       \
		[format %10.3f $x_ave]\
		[format %10.3f $y_ave]"
	set x_var [expr ($sum_sqr_x/$cnt)-($x_ave*$x_ave)]
	if {$x_var < 0} {set x_var 0}
	set x_stdev [format %.3f [expr sqrt($x_var)]]
	set y_var [expr ($sum_sqr_y/$cnt)-($y_ave*$y_ave)]
	if {$y_var < 0} {set y_var 0}
	set y_stdev [format %.3f [expr sqrt($y_var)]]
	LWDAQ_print $info(gscalib_text) "Stdev         \
		[format %10.3f $x_stdev]\
		[format %10.3f $y_stdev]"
	LWDAQ_print $info(gscalib_text) "------------------------------------" 

	set pose "[format %10.3f $x_ave] [format %10.3f $y_ave] 0.0 0.0\
		[format %10.6f [expr -0.001*$info(gscalib_rot_mrad)]]"

	LWDAQ_print $info(gscalib_text) "\nGuide Sensor Poses" purple
	LWDAQ_print $info(gscalib_text) "-------------------------------------" 
	LWDAQ_print $info(gscalib_text) " GS   X (mm)     Y (mm)    rot (mrad)" 
	LWDAQ_print $info(gscalib_text) "-------------------------------------" 
	foreach gs $info(guide_sensors) {
		set x [lindex $info(gscalib_mask_0) [expr ($gs-1)*3+0]]
		set y [lindex $info(gscalib_mask_0) [expr ($gs-1)*3+1]]
		set rot [lindex $info(gscalib_mask_0) [expr ($gs-1)*3+2]]
		set gsxyz [lwdaq xyz_local_from_global_point "$x $y 0" $pose]
		scan $gsxyz %f%f%f xx yy zz
		set xx [expr $xx + 0.5*$info(gscalib_width) - $info(local_coord_offset)]
		set yy [expr $yy + 0.5*$info(gscalib_height) - $info(local_coord_offset)]
		set rr [expr 0 - $rot - $info(gscalib_rot_mrad)]
		set info(guide_$gs) "[format %.3f $xx] [format %.3f $yy] [format %.3f $rr]"
		LWDAQ_print $info(gscalib_text) \
			" $gs [format %9.3f $xx] [format %9.3f $yy] [format %9.3f $rr]"
	}
	LWDAQ_print $info(gscalib_text) "-------------------------------------" 

	set info(gscalib_state) "Idle"
	return ""
}

#
# DFPS_Manager_gscalib opens the Fiducial Plate Calibrator window.
#
proc DFPS_Manager_gscalib {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set w $info(window)\.gscalib
	if {![winfo exists $w]} {
		toplevel $w
		wm title $w "Guide Sensor Rasnik Calibration, DFPS Manager $info(version)"
	} {
		raise $w
		return ""
	}
	
	set f [frame $w.controls]
	pack $f -side top -fill x
	
	label $f.state -textvariable DFPS_Manager_info(gscalib_state) -fg blue -width 10
	pack $f.state -side left -expand yes

	foreach a $info(gscalib_orientations) {
		button $f.acq$a -text "Acquire $a" -command \
			[list LWDAQ_post "DFPS_Manager_gscalib_acquire $a"]
		pack $f.acq$a -side left -expand yes
	}

	foreach a {Calculate} {
		set b [string tolower $a]
		button $f.$b -text "$a" -command [list LWDAQ_post "DFPS_Manager_gscalib_$b"]
		pack $f.$b -side left -expand yes
	}
	
	foreach a {Rasnik Camera} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_open $a"
		pack $f.$b -side left -expand 1
	}

	checkbutton $f.verbose -text "Verbose" -variable DFPS_Manager_config(verbose)
	pack $f.verbose -side left -expand yes

	set f [frame $w.options]
	pack $f -side top -fill x
	
	foreach {a wd} {algorithm 2 square_um 4 ref_x_um 5 ref_y_um 5 flash_s 10} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable DFPS_Manager_config(gscalib_$a) -width $wd
		pack $f.l$a $f.e$a -side left -expand yes
	}

	set f [frame $w.images]
	pack $f -side top -fill x

	foreach guide $info(guide_sensors) {
		image create photo "gscalib_$guide"
		label $f.$guide -image "gscalib_$guide"
		pack $f.$guide -side left -expand yes
	}
		
	set info(gscalib_text) [LWDAQ_text_widget $w 100 15]
	LWDAQ_print $info(gscalib_text) \
		"Guide Sensor Rasnik Calibration Text Output" purple
	
	foreach guide $info(guide_sensors) {
		lwdaq_draw dfps_guide_$guide gscalib_$guide \
			-intensify $config(gscalib_intensify) -zoom $config(gscalib_zoom)
	}
	
	return $w
}

#
# DFPS_Manager_frot_acquire takes an orientation name as input, which directs
# where its output will be saved. It goes through the fiducials listed in the
# manager's fiducial_leds string and checks their positions one after another.
# It saves their positions in the frot measurement for the named position.
#
proc DFPS_Manager_frot_acquire {orientation} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	
	set info(frot_state) "Acquire"

	set spots [DFPS_Manager_spots $config(fiducial_leds)]
	if {[LWDAQ_is_error_result $spots]} {
		set info(frot_state) "Idle"
		return $spots
	}
	set fiducials_global [DFPS_Manager_sources_global $spots]
	set info(frot_$orientation) $fiducials_global
	LWDAQ_print $info(frot_text) "$orientation $fiducials_global"	

	set info(frot_state) "Idle"
	return "$fiducials_global"
}

#
# DFPS_Manager_frot_calculate takes the four measurements of fidicial fibers
# from four orientations and calculates for each fiducial its position in frame
# coordinates. For each orienation we construct the two-dimensional rotation
# matrix that transforms vectors in the 0-degree orientation to those in the new
# orienation. For the 0-degree orientaion this matrix is the identity matris.
# For each fiber and each pair of orientations, we subtract the second rotation
# matrix from the first, invert the difference matrix, and apply this transform
# to the vector between the two global positions of the fibers. The result is
# the vector from the center of the plate to the fiber. We now correct for a
# plate whose center is not exactly at our fiducial coordinate origin. If the
# width of the plate is 140 mm, for example, and our coordinate origin is at 65
# mm, the center is 5 mm to the right of the coordinate origin, so we must add 5
# mm to the x-coordinate of the vector from the center to the fiber in order to
# obtain the x-coordinate of the vector from the origin to the fiber.
#
proc DFPS_Manager_frot_calculate {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	
	set info(frot_state) "Calculate"
	
	set pi 3.141592654
	foreach o {0 90 180 270} {
		set r [expr $o*1.0/360*2*$pi]
		set R_$o "[format %6.3f [expr cos($r)]] \
			[format %6.3f [expr 1.0*sin($r)]] \
			[format %6.3f [expr -1.0*sin($r)]] \
			[format %6.3f [expr cos($r)]]"
	}
	
	LWDAQ_print $info(frot_text) "\nFiducial Positions" purple
	LWDAQ_print $info(frot_text) \
	"--------------------------------------------------------------------------------"
	LWDAQ_print $info(frot_text) "  O1   O2     X1       Y1       X2      \
		Y2       X3       Y3       X4       Y4"
	LWDAQ_print $info(frot_text) \
	"--------------------------------------------------------------------------------"

	foreach ff $info(fiducial_fibers) {
		set sum_x_$ff 0.0
		set sum_sqr_x_$ff 0.0
		set sum_y_$ff 0.0
		set sum_sqr_y_$ff 0.0
	}
	set cnt 0
 	foreach {o1 o2} "0 90 0 180 0 270 90 180 90 270 180 270 " {
		set m1 $info(frot_$o1)
		set m2 $info(frot_$o2)
		set R_link ""
		for {set i 0} {$i < 4} {incr i} {
			lappend R_link [expr [lindex [set R_$o2] $i] - [lindex [set R_$o1] $i]]
		}
		set R_unlink [lwdaq matrix_inverse $R_link]
		scan $R_unlink %f%f%f%f m11 m12 m21 m22
		LWDAQ_print -nonewline $info(frot_text) "[format %4d $o1] [format %4d $o2] "
		foreach ff $info(fiducial_fibers) {
			set x1 [lindex $m1 [expr ($ff-1)*3+0]]
			set y1 [lindex $m1 [expr ($ff-1)*3+1]]
			set x2 [lindex $m2 [expr ($ff-1)*3+0]]
			set y2 [lindex $m2 [expr ($ff-1)*3+1]]
			set dx [expr $x2-$x1]
			set dy [expr $y2-$y1]
			set x [expr $m11*$dx + $m12*$dy]
			set y [expr $m21*$dx + $m22*$dy]
			set x [expr $x + 0.5*$info(frot_width) - $info(local_coord_offset)]
			set y [expr $y + 0.5*$info(frot_height) - $info(local_coord_offset)]
			LWDAQ_print -nonewline $info(frot_text) \
				"[format %8.3f $x] [format %8.3f $y] "
			set sum_x_$ff [expr [set sum_x_$ff] + $x]
			set sum_sqr_x_$ff [expr [set sum_sqr_x_$ff] + ($x*$x)]
			set sum_y_$ff [expr [set sum_y_$ff] + $y]
			set sum_sqr_y_$ff [expr [set sum_sqr_y_$ff] + ($y*$y)]
		}
		LWDAQ_print $info(frot_text) ""
		incr cnt
	}

	LWDAQ_print $info(frot_text) \
	"--------------------------------------------------------------------------------"

	LWDAQ_print -nonewline $info(frot_text) "Average   "
	foreach ff $info(fiducial_fibers) {
		set x_ave [expr [set sum_x_$ff]/$cnt]
		set y_ave [expr [set sum_y_$ff]/$cnt]
		LWDAQ_print -nonewline $info(frot_text) \
			"[format %8.3f $x_ave] [format %8.3f $y_ave] "
		lset info(fiducial_$ff) 0 [format %.3f $x_ave]
		lset info(fiducial_$ff) 1 [format %.3f $y_ave]
	}
	LWDAQ_print $info(frot_text) ""
	LWDAQ_print -nonewline $info(frot_text) "Stdev     "
	foreach ff $info(fiducial_fibers) {
		set x_ave [expr [set sum_x_$ff]/$cnt]
		set y_ave [expr [set sum_y_$ff]/$cnt]
		set x_var [expr ([set sum_sqr_x_$ff]/$cnt)-($x_ave*$x_ave)]
		if {$x_var < 0} {set x_var 0}
		set x_stdev [format %.3f [expr sqrt($x_var)]]
		set y_var [expr ([set sum_sqr_y_$ff]/$cnt)-($y_ave*$y_ave)]
		if {$y_var < 0} {set y_var 0}
		set y_stdev [format %.3f [expr sqrt($y_var)]]
		LWDAQ_print -nonewline $info(frot_text) \
			"[format %8.3f $x_stdev] [format %8.3f $y_stdev] "
	}
	LWDAQ_print $info(frot_text) ""

	LWDAQ_print $info(frot_text) \
	"--------------------------------------------------------------------------------"

	set info(frot_state) "Idle"
	return ""
}

#
# DFPS_Manager_frot opens the Fiducial Rotation Calibration window.
#
proc DFPS_Manager_frot {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set w $info(window)\.frot
	if {![winfo exists $w]} {
		toplevel $w
		wm title $w "Fiducial Calibration, DFPS Manager $info(version)"
	} {
		raise $w
		return ""
	}

	set i 0
	set f [frame $w.f[incr i]]
	pack $f -side top -fill x
	
	label $f.state -textvariable DFPS_Manager_info(frot_state) -fg blue -width 10
	pack $f.state -side left -expand yes

	foreach a $info(frot_orientations) {
		button $f.acq$a -text "Acquire $a" -command \
			[list LWDAQ_post "DFPS_Manager_frot_acquire $a"]
		pack $f.acq$a -side left -expand yes
	}

	foreach a {Calculate} {
		set b [string tolower $a]
		button $f.$b -text "$a" -command [list LWDAQ_post "DFPS_Manager_frot_$b"]
		pack $f.$b -side left -expand yes
	}
	
	set f [frame $w.f[incr i]]
	pack $f -side top -fill x

	foreach a {frot_width frot_height} {
		label $f.l$a -text "$a\:" -fg $info(label_color)
		entry $f.e$a -textvariable DFPS_Manager_info($a) -width 10
		pack $f.l$a $f.e$a -side left -expand yes
	}

	foreach a {BCAM} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_open $a"
		pack $f.$b -side left -expand 1
	}
	
	checkbutton $f.verbose -text "Verbose" -variable DFPS_Manager_config(verbose)
	pack $f.verbose -side left -expand yes

	set info(frot_text) [LWDAQ_text_widget $w 100 15]
	LWDAQ_print $info(frot_text) \
		"Fiducial Calibration Text Output" purple
	
	return $w
}

#
# DFPS_Manager_watchdog watches the system commands list for incoming commands.
# It manages the position of fibers by comparing measured positions to target
# positions and adjusting control voltages to minimize disagreement. It monitors
# fiducials and adjusts the fiducial frame pose in fiber view camera
# coordinates.
#
proc DFPS_Manager_watchdog {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	global LWDAQ_server_commands LWDAQ_Info
	set t .serverwindow.text
	
	# Trim the manager text window to a maximum number of lines.
	if {[$info(text) index end] > 1.2 * $LWDAQ_Info(num_lines_keep)} {
		$info(text) delete 1.0 "end [expr 0 - $LWDAQ_Info(num_lines_keep)] lines"
	}
	
	# Default value for result string.
	set result ""
	
	# If mast control is enabled, at intervals, adjust mast positions. We
	# measure the mast positions, look at the offsets from their target
	# positions, and adjust their control voltages so as to move the mast
	# towards the target.
	if {$config(enable_mast_control)} {
		if {[clock seconds] - $info(mast_control_time) \
				>= $config(mast_control_period)} {
			set info(mast_control_time) [clock seconds]
			if {$config(verbose)} {
				LWDAQ_print $info(text) \
					"mast_control_time [clock seconds]" $info(vcolor)
			}
			set control_report "[clock seconds] "
			DFPS_Manager_mast_measure_all
			foreach m $info(positioner_masts) {
				scan $info(voltage_$m) %d%d upleft upright
				scan $info(offset_$m) %f%f xo yo
				set ulo [format %.3f [expr $yo/sqrt(2)-$xo/sqrt(2)]]
				set uro [format %.3f [expr $yo/sqrt(2)+$xo/sqrt(2)]]
				set upleft [format %.0f [expr $upleft - $config(gain)*$ulo]]
				set upright [format %.0f [expr $upright - $config(gain)*$uro]]
				set result [DFPS_Manager_move $m $upleft $upright]
				set info(voltage_$m) "[lrange $result 1 2]"
				append control_report \
					"[format %.3f $xo] [format %.3f $yo] $info(voltage_$m) "
			}
			if {[winfo exists $info(utils_text)] && $config(report)} {
				LWDAQ_print $info(utils_text) $control_report
			} 
			if {$config(verbose)} {
				LWDAQ_print $info(text) $control_report $info(vcolor)
			}
		}
	} {
		set info(mast_control_time) "0"
	}
	
	# At intervals, survey the fiducial fibers an adjust frame
	# coordinate pose. The fiducial period is in units of
	# mast_control_period.
	if {$config(enable_mast_control)} {
		if {[clock seconds] - $info(fiducial_survey_time) \
				>= $config(fiducial_survey_period)} {
			set info(fiducial_survey_time) [clock seconds]
			if {$config(verbose)} {
				LWDAQ_print $info(text) \
					"fiducial_survey_time [clock seconds]" $info(vcolor)
			}
			DFPS_Manager_fsurvey
		}
	} {
		set info(fiducial_survey_time) "0"
	}
	
	# Handle incoming server commands.
	if {[llength $LWDAQ_server_commands] > 0} {
		set cmd [lindex $LWDAQ_server_commands 0 0]
		set sock [lindex $LWDAQ_server_commands 0 1]
		set LWDAQ_server_commands [lrange $LWDAQ_server_commands 1 end]
		if {$config(verbose)} {
			LWDAQ_print $info(text) "server_command $cmd $sock" $info(vcolor)
		}
		
		if {[string match "LWDAQ_server_info" $cmd]} {
			append cmd " $sock"
		}
		
		if {[catch {
			set result [uplevel #0 $cmd]
			if {$config(verbose)} {
				LWDAQ_print $info(text) "server_result $result" $info(vcolor)
			}
		} error_result]} {
			set result "ERROR: $error_result"
		}		
		
		if {$result != ""} {
			if {[catch {puts $sock $result} sock_error]} {
				LWDAQ_print -nonewline $t "$sock\: " blue
				LWDAQ_print $t "ERROR: $sock_error"
				LWDAQ_socket_close $sock
				LWDAQ_print -nonewline $t "$sock\: " blue
				LWDAQ_print $t "Closed after fatal socket error."
				LWDAQ_print $info(text) "ERROR: $sock_error"
			} {
				if {[string length $result] > 50} {
					LWDAQ_print -nonewline $t "$sock\: " blue
					LWDAQ_print $t "Wrote \"[string range $result 0 49]\...\""
				} {
					LWDAQ_print -nonewline $t "$sock\: " blue
					LWDAQ_print $t "Wrote \"$result\""
				}
			}
		}
	}
	
	LWDAQ_post DFPS_Manager_watchdog
	return $result
}

#
# DFPS_Manager_fsurvey_err returns a measure of the disagreement between the
# measured positions of the fiducials and the positions we predict from our
# calibration of the fiducials and our fiducial coordinate pose. This routine
# will be called by the simplex fitter.
#
proc DFPS_Manager_fsurvey_err {params} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	# If user has closed the calibrator window or asserted the stop flag abort with
	# an error. 
	LWDAQ_support
	if {$config(fit_stop)} {error "Fit aborted by user"}
	if {![winfo exists $info(window)]} {error "Tool window destroyed"}
	
	# Go through the four fiducials to calculate an error. We already have the
	# measured global coordinates of the fiducials. Now we transform the
	# fiducial's local coordinates, which we have obtained from a separate
	# calibration of the fiducial plate, into global coordinates using the
	# current fiducial coordinate pose. We obtain the length of the vector from
	# actual to transformed positions, square its length and add to our
	# disagreement measurement.
	set sum_sqr 0
	set count 0
	foreach {x y z} $info(fiducial_sources) {
		incr count
		set ffg [lwdaq xyz_global_from_local_point $info(fiducial_$count) $params]
		scan $ffg %f%f%f xx yy zz
		set sqr [expr ($xx-$x)*($xx-$x) + ($yy-$y)*($yy-$y) +($zz-$z)*($zz-$z)]
		set sum_sqr [expr $sum_sqr + $sqr]
	}
	
	# Calculate root mean square error.
	set err [format %.3f [expr sqrt($sum_sqr/$count)]]	
	
	# Return the total disagreement, which is our error value.
	return $err
}

#
# DFPS_Manager_fvcr measures the four fiducial positions in the global
# coordinate system of the fiber view cameras and then proceeds to adjust the
# pose of the local coordinates so as to match the calibrated fiducial
# positions with the observed fiducial positions. If we execute this routine,
# translate the fiducial plate by 5 mm in x, and execute again, the pose of the
# local coordinates will move by 5 mm in x. Knowing the pose of the fiducial
# coordinates, we can transform global measurements of guide fibers into local
# coordinates, and so connect them with the local coordinates of star image on
# the guide sensors.
#
proc DFPS_Manager_fsurvey {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	
	set info(utils_state) "FSurvey"
	if {[winfo exists $info(utils_text)]} {
		set t $info(utils_text)
	} else {
		set t $info(text)
	}
	
	set spots [DFPS_Manager_spots $config(fiducial_leds)]
	
	if {[LWDAQ_is_error_result $spots]} {
		LWDAQ_print $t $spots
		set info(utils_state) "Idle"
		return $spots
	}
	
	set sources [DFPS_Manager_sources_global $spots]
	set info(fiducial_sources) $sources

	set start_params $info(local_coord)
	lwdaq_config -show_details $config(fit_details) -text_name $info(text)	
	set end_params [lwdaq_simplex $start_params \
		DFPS_Manager_fsurvey_err \
		-report $config(fit_show) \
		-steps $config(fit_steps) \
		-restarts $config(fit_restarts) \
		-start_size $config(fit_startsize) \
		-end_size $config(fit_endsize) \
		-scaling "1.0 1.0 1.0 0.1 0.1 0.1"]
	lwdaq_config -show_details 0 -text_name $info(text)

	if {[LWDAQ_is_error_result $end_params]} {
		LWDAQ_print $t "ERROR: $end_params"
		set info(utils_state) "Idle"
		return ""
	}
	
	set pl ""
	foreach p [lrange $end_params 0 5] {append pl "[format %.3f $p] "}
	set info(local_coord) [string trim $pl]

	if {$config(verbose)} {
		LWDAQ_print $t \
			"fsurvey steps=[lindex $end_params 7]\
				error_um=[format %.1f [expr 1000*[lindex $end_params 6]]]" \
			$info(vcolor)
	}
	if {$config(report)} {
		LWDAQ_print $t "$info(local_coord)"
	}
	
	set info(utils_state) "Idle"
	return "$info(local_coord)"
}

#
# DFPS_Manager_dfcalib measures the position of a guide fiber in local
# coordinates, measures the position of the chosen detector fiber in local
# coordinates, and subtracts the detector position from the guide position to
# obtain the x-y offset of the detector with respect to the guide fiber. We add
# this offset to the mast position, which is the guide fiber position, to obtain
# the detector position. The routine assumes that we have the detector
# calibration fiber plugged into the detector fiber output connector on the
# DFPS, so that light enters the detector and can be seen by the fiber view
# cameras. The optical energy we must inject into the detector must be intense:
# thousands of times more energy than we need to see the guide fiber. The fiber
# view cameras will be seeing the detector fibers outside their cone of
# emission, so that we see only traces of light at the fringes of the detector
# numerical aperture. During the calibration we will see the guide fiber flash
# twice, once for each FVC, and the detector fiber flash twice. Both will appear
# to be in the same location to the naked eye, but the detector fiber will be
# much brighter when seen looking down its axis.
#
proc DFPS_Manager_dfcalib {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set info(mcalib_state) "Mast"

	set m $config(mcalib_mast)
	set d $config(mcalib_detector)
	set led [lindex $config(guide_leds) [expr $m - 1]]
	if {$config(verbose)} {
		LWDAQ_print $info(mcalib_text) \
			"dfcalib detector=$d mast=$m source=$config(mcalib_led)." $info(vcolor)
	}
	
	set spots [DFPS_Manager_spots $led]
	if {[LWDAQ_is_error_result $spots]} {
		LWDAQ_print $info(mcalib_text) $spots
		set info(mcalib_state) "Idle"
		return $spots
	}
	
	set mast_global [DFPS_Manager_sources_global $spots]
	set mast_local [DFPS_Manager_local_from_global $mast_global]
	if {$config(verbose)} {
		LWDAQ_print $info(mcalib_text) "dfcalib mast_local=$mast_local." $info(vcolor)
	}
	
	set info(mcalib_state) "Detector"

	set saved_pwr $config(source_pwr)
	set config(source_pwr) $config(mcalib_pwr)
	set saved_flash $config(flash_s)
	set config(flash_s) $config(mcalib_flash)
	set spots [DFPS_Manager_spots $config(mcalib_led)]
	set config(source_pwr) $saved_pwr
	set config(flash_s) $saved_flash

	if {[LWDAQ_is_error_result $spots]} {
		LWDAQ_print $info(mcalib_text) $spots
		set info(mcalib_state) "Idle"
		return $spots
	}

	set detector_global [DFPS_Manager_sources_global $spots]
	set detector_local [DFPS_Manager_local_from_global $detector_global]
	if {$config(verbose)} {
		LWDAQ_print $info(mcalib_text) \
			"dfcalib detector_local=$detector_local" $info(vcolor)
	}
	
	scan $detector_local %f%f%f xd yd zd
	scan $mast_local %f%f%f xm ym zm
	set offset "[format %.3f [expr $xd-$xm]] [format %.3f [expr $yd-$ym]]"
	set info(detector_$m\_$d) $offset
	LWDAQ_print $info(mcalib_text) "$m $d $offset"
	
	set info(mcalib_state) "Idle"	
	return "$mast_local $offset"
}

# 
# DFPS_Manager_mranges measures the center of the range of motion of a set of
# masts, the length of the side of the rotated square that is the range, and the
# rotation of the range counter-clockwise in local coordinates as seen looking
# down on the mast tip from the aperture of the instrument. The rotation is in
# radians. The routine stores these values in each mast's range parameter. If no
# masts are specified, all masts are measured. In order to make sure the masts
# do not interfere with one another, the procedure moves all masts together,
# using the controller wild card. It waits for the mcalib settling time at each
# corner before recording the position. At the end of the process, mranges
# returns all masts to their zero position.
#
proc DFPS_Manager_mranges {{masts ""}} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	if {$masts == ""} {set masts $info(positioner_masts)}
	
	set i 0
	foreach {upleft upright} "$info(dac_min) $info(dac_min)\
			$info(dac_max) $info(dac_min)\
			$info(dac_max) $info(dac_max)\
			$info(dac_min) $info(dac_max)" {
		set corner [lindex $info(mrange_corners) $i]
		set config(upleft) $upleft
		set config(upright) $upright
		set info(mcalib_state) "Move$corner"	
		if {$config(verbose)} {
			LWDAQ_print $info(mcalib_text) "mranges corner=$corner\
				upleft=$upleft upright=$upright" $info(vcolor)
		}
		DFPS_Manager_voltage_set $info(wildcard_id) $config(upleft) $config(upright)
		set st $config(mcalib_settling_ms)
		set info(mcalib_state) "Settle"	
		if {$config(verbose)} {
			LWDAQ_print $info(mcalib_text) "mranges settling_ms=$st" $info(vcolor)
		}
		LWDAQ_wait_ms $st
		foreach m $masts {
			set info(mcalib_state) "Measure_$m"	
			set ml [DFPS_Manager_mast_measure $m]
			if {[LWDAQ_is_error_result $ml]} {
				LWDAQ_print $info(mcalib_text) $ml
				set info(mcalib_state) "Idle"
				return $ml
			}
			if {$config(verbose)} {
				LWDAQ_print $info(mcalib_text) "mranges mast=$m $ml" $info(vcolor)
			}
			set m_$m\_$corner [lrange $ml 0 1]
		}		
		incr i
	}

	set info(mcalib_state) "Zero"	
	set config(upleft) $info(dac_zero)
	set config(upright) $info(dac_zero)
	DFPS_Manager_voltage_set $info(wildcard_id) $config(upleft) $config(upright)
	
	set info(mcalib_state) "Calculate"	
	LWDAQ_update
	set n [llength $info(mrange_corners)]
	foreach m $masts {
		set x_sum 0
		set y_sum 0
		set perimeter 0
		scan [set m_$m\_[lindex $info(mrange_corners) end]] %f%f x_prev y_prev
		foreach c $info(mrange_corners) {
			scan [set m_$m\_$c] %f%f x y
			set side [format %.3f [expr sqrt( \
				($x-$x_prev)*($x-$x_prev) + \
				($y-$y_prev)*($y-$y_prev))]]
			if {$config(verbose)} {
				LWDAQ_print $info(mcalib_text) "mranges mast=$m \
					corner=$c x=$x y=$y side=$side" $info(vcolor)
			}
			set x_sum [expr $x_sum + $x]
			set y_sum [expr $y_sum + $y]
			set perimeter [expr $perimeter + $side]
			set x_prev $x
			set y_prev $y
		}
		set x_ave [format %.3f [expr $x_sum / $n]]
		set y_ave [format %.3f [expr $y_sum / $n]]
		set side [format %.3f [expr $perimeter / $n]]
		
		set x_top [lindex [set m_$m\_top] 0]
		set x_bottom [lindex [set m_$m\_bottom] 0]
		set rot_x [format %.3f [expr atan(($x_bottom-$x_top)/$side/sqrt(2))]]
		set y_left [lindex [set m_$m\_left] 1]
		set y_right [lindex [set m_$m\_right] 1]
		set rot_y [format %.3f [expr atan(($y_right-$y_left)/$side/sqrt(2))]]
		set rot [format %.3f [expr ($rot_x + $rot_y)/2.0]]
		set info(mrange_$m) "$x_ave $y_ave $side $rot"
		if {$config(verbose)} {
			LWDAQ_print $info(mcalib_text) \
			"mast=$m x_ave=$x_ave y_ave=$y_ave side=$side\
				rot_x=$rot_x rot_y=$rot_y rot=$rot" $info(vcolor)
		}
	}
	
	foreach m $masts {
		LWDAQ_print -nonewline $info(mcalib_text) "$info(mrange_$m) "
	}
	LWDAQ_print $info(mcalib_text) ""
		
	set info(mcalib_state) "Idle"	
	return ""
}

#
# DFPS_Manager_mcalib opens the Detector Fiber Calibration window.
#
proc DFPS_Manager_mcalib {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set w $info(window)\.mcalib
	if {![winfo exists $w]} {
		toplevel $w
		wm title $w "Mast and Detector Calibration, DFPS Manager $info(version)"
	} {
		raise $w
		return ""
	}

	set i 0
	set f [frame $w.f[incr i]]
	pack $f -side top -fill x
	
	label $f.state -textvariable DFPS_Manager_info(mcalib_state) -fg blue -width 10
	pack $f.state -side left -expand yes

	button $f.calib -text "Calibrate" -command "LWDAQ_post DFPS_Manager_dfcalib"
	pack $f.calib -side left -expand yes
	
	button $f.mranges -text "MRanges" -command "LWDAQ_post DFPS_Manager_mranges"
	pack $f.mranges -side left -expand yes
	
	checkbutton $f.verbose -text "Verbose" -variable DFPS_Manager_config(verbose)
	pack $f.verbose -side left -expand yes

	foreach a {mast detector led flash pwr settling_ms} {
		label $f.l$a -text "$a\:" -fg $info(label_color)
		entry $f.e$a -textvariable DFPS_Manager_config(mcalib_$a) -width 5
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	set info(mcalib_text) [LWDAQ_text_widget $w 80 15]
	LWDAQ_print $info(mcalib_text) \
		"Mast and Detector Calibration Text Output" purple
	
	return $w
}


#
# DFPS_Manager_utils_transmit sends the command in the utils_cmd parameter
# to controller utils_ctrl.
#
proc DFPS_Manager_utils_transmit {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	
	set info(utils_state) "Transmit"
	set commands "[DFPS_Manager_id_bytes $config(utils_ctrl)] $config(utils_cmd)"
	LWDAQ_print $info(utils_text) "Transmit: $commands"
	set result [DFPS_Manager_transmit $commands]
	if {[LWDAQ_is_error_result $result]} {
		LWDAQ_print $info(utils_text) $result
		set info(utils_state) "Idle"
		return $result
	} else {
		set info(utils_state) "Idle"
		return ""
	}
}

#
# DFPS_Manager_utils opens the Utilities Panel, where we have various options for
# calibrating the DFPS optical components, transmitting commands to fiber controllers,
# and opening LWDAQ instruments.
#
proc DFPS_Manager_utils {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set w $info(window)\.utils
	if {![winfo exists $w]} {
		toplevel $w
		wm title $w "Utilities Panel, DFPS Manager $info(version)"
	} {
		raise $w
		return ""
	}
	
	set i 0
	set f [frame $w.f[incr i]]
	pack $f -side top -fill x
	
	label $f.state -textvariable DFPS_Manager_info(utils_state) -width 20 -fg blue
	pack $f.state -side left -expand 1
	
	foreach a {BCAM Camera Rasnik Diagnostic} {
		set b [string tolower $a]
		button $f.$b -text $a -command [list LWDAQ_post "LWDAQ_open $a"]
		pack $f.$b -side left -expand 1
	}
	
	button $f.toolmaker -text "Toolmaker" -command "LWDAQ_post LWDAQ_Toolmaker"
	pack $f.toolmaker -side left -expand 1

	button $f.configurator -text "Configurator" \
		-command [list LWDAQ_post "LWDAQ_run_tool Configurator"]
	pack $f.configurator -side left -expand 1

	button $f.server -text "Server" -command "LWDAQ_post LWDAQ_server_open"
	pack $f.server -side left -expand 1

	checkbutton $f.verbose -text "Verbose" -variable DFPS_Manager_config(verbose)
	pack $f.verbose -side left -expand yes

	set f [frame $w.f[incr i]]
	pack $f -side top -fill x

	foreach {a b} {"Survey Fiducials" fsurvey \
			"Guide Sensor Calib" gscalib \
			"Fiducial Fiber Calib" frot \
			"Mast and Detector Calib" mcalib \
			"Fiber View Camera Calib" fvcalib} {
		button $f.$b -text $a -command "LWDAQ_post DFPS_Manager_$b"
		pack $f.$b -side left -expand 1
	}

	set f [frame $w.f[incr i]]
	pack $f -side top -fill x

	foreach a {Examine_Calibration Save_Calibration Read_Calibration} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post DFPS_Manager_$b"
		pack $f.$b -side left -expand 1
	}
	
	label $f.title -text "Calib File:" -fg $info(label_color)
	entry $f.entry -textvariable DFPS_Manager_config(calib_file) -width 60
	pack $f.title $f.entry -side left -expand 1

	set f [frame $w.f[incr i]]
	pack $f -side top -fill x

	foreach a {fiducial_leds guide_leds} {
		label $f.l$a -text "$a\:" -fg $info(label_color)
		entry $f.e$a -textvariable DFPS_Manager_config($a) -width 16
		pack $f.l$a $f.e$a -side left -expand yes
	}

	foreach a {fvc_left fvc_right injector} {
		label $f.l$a -text "$a\:" -fg $info(label_color)
		entry $f.e$a -textvariable DFPS_Manager_config($a) \
			-width [expr [string length $config($a)] + 1]
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	set f [frame $w.f[incr i]]
	pack $f -side top -fill x

	foreach {a b} {"ZeroAll" zero_all "SetAll" set_all} {
		button $f.$b -text $a -command "LWDAQ_post DFPS_Manager_$b"
		pack $f.$b -side left -expand yes
	}
	
	foreach d {upleft upright gain} {
		set a [string tolower $d]
		label $f.l$a -text "$d\:" -fg $info(label_color)
		entry $f.e$a -textvariable DFPS_Manager_config($a) -width 6
		pack $f.l$a $f.e$a -side left -expand yes
	}

	foreach a {controllers} {
		label $f.l$a -text "$a\:" -fg $info(label_color)
		entry $f.e$a -textvariable DFPS_Manager_config($a) -width 20
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	foreach a {transceiver} {
		label $f.l$a -text "$a\:" -fg $info(label_color)
		entry $f.e$a -textvariable DFPS_Manager_config($a) \
			-width [expr [string length $config($a)] + 1]
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	set lw 15
	set ew 12
	
	set f [frame $w.f[incr i]]
	pack $f -side top -fill x

	label $f.title -text "Mast Offsets:" -fg $info(label_color) -width $lw
	pack $f.title -side left -expand yes
	foreach m $info(positioner_masts) {
		entry $f.e$m -textvariable DFPS_Manager_info(offset_$m) -width $ew
		pack $f.e$m -side left -expand yes
	}

	set f [frame $w.f[incr i]]
	pack $f -side top -fill x

	label $f.title -text "Drive Voltages:" -fg $info(label_color) -width $lw
	pack $f.title -side left -expand yes
	foreach m $info(positioner_masts) {
		entry $f.e$m -textvariable DFPS_Manager_info(voltage_$m) -width $ew
		pack $f.e$m -side left -expand yes
	}

	set f [frame $w.f[incr i]]
	pack $f -side top -fill x
	
	button $f.move -text "MoveAll" -command "LWDAQ_post DFPS_Manager_move_all"
	entry $f.disp -textvariable DFPS_Manager_config(displacement) -width 12
	pack $f.move $f.disp -side left -expand yes

	button $f.transmit -text "Transmit" \
		-command "LWDAQ_post DFPS_Manager_utils_transmit"
	pack $f.transmit -side left -expand yes
	
	label $f.lid -text "Controller:" -fg $info(label_color)
	entry $f.id -textvariable DFPS_Manager_config(utils_ctrl) -width 10
	label $f.lcommands -text "Commands:" -fg $info(label_color)
	entry $f.commands -textvariable DFPS_Manager_config(utils_cmd) -width 50
	pack $f.lid $f.id $f.lcommands $f.commands -side left -expand yes

	set info(utils_text) [LWDAQ_text_widget $w 80 20 1 1]
	LWDAQ_print $info(utils_text) "Utility Text Output" purple

	return $w
}

#
# DFPS_Manager_acquire_guides capture images from all guide sensors and displays them in
# the manager window. It uses the default guide exposure time exposure_s.
#
proc DFPS_Manager_acquire_guides {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set info(state) "Guides"
	foreach g $info(guide_sensors) {
		set result [DFPS_Manager_guide_acquire $g $config(expose_s)]
		if {[LWDAQ_is_error_result $result]} {
			set info(state) "Idle"
			return $result
		}
		if {$config(verbose)} {
			LWDAQ_print $info(text) "acquire_guides $result" $info(vcolor)
		}
	}
	set info(state) "Idle"
	return ""
}

#
# DFPS_Manager_mast_measure_all measures the positions of all masts one by one
# and returns their x-y positions in local coordinates. It also reports these
# positions if the report flag is set.
#
proc DFPS_Manager_mast_measure_all {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set positions [list]
	foreach m $info(positioner_masts) {
		set mp [DFPS_Manager_mast_measure $m]
		if {[LWDAQ_is_error_result $mp]} {
			set info(state) "Idle"
			return $mp
		}
		scan $mp %f%f%f x y z
		lappend positions $x $y
	}
	
	if {$config(report)} {
		foreach p $positions {
			LWDAQ_print -nonewline $info(text) "[format %.3f $p] "
		}
		LWDAQ_print $info(text) ""
	}
	
	return $positions
}

#
# DFPS_Manager_reset_masts surveys the fiducials to obtain a new local
# coordinate pose, sets the mast target positions to the centers of the mast
# ranges, zeros the control voltages on all controllers, re-measures the mast
# positions, and shows all fiducial and guide sources.
#
proc DFPS_Manager_reset_masts {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	
	set info(state) "Reset"
	
	LWDAQ_print $info(text) "\nPositioner Reset Start" purple
	LWDAQ_print $info(text) "Zeroing actuator voltages..."
	DFPS_Manager_zero_all
	foreach m $info(positioner_masts) {
		set info(voltage_$m) "$info(dac_zero) $info(dac_zero)"
	}
	LWDAQ_print $info(text) "Surveying fiducials..."
	DFPS_Manager_fsurvey
	LWDAQ_print $info(text) "Setting mast targets to range centers..."
	foreach m $info(positioner_masts) {
		set info(target_$m) [lrange $info(mrange_$m) 0 1]
	}
	LWDAQ_print $info(text) "Measuring mast positions..."
	DFPS_Manager_mast_measure_all

	LWDAQ_print $info(text) "Showing all sources..."
	DFPS_Manager_spots

	LWDAQ_print $info(text) "Positioner Reset Complete" purple
	set info(state) "Idle"
	
	return ""
}

#
# DFPS_Manger_gmark takes an x-y position in one of the guide sensor images and marks
# the spot in the image overlay, both in the normal guide sensor displays and in any
# magnified display that might exist. We display in the magnified window first, so that
# we keep the marking lines one pixel wide, then display in the standard window.
#
proc DFPS_Manager_gmark {guide x_g y_g} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set ext $info(guide_height_um)
	set width [expr 0.001*$info(guide_width_um)]
	set height [expr 0.001*$info(guide_height_um)]
	lwdaq_image_manipulate dfps_guide_$guide none -clear 1
	lwdaq_graph "[expr $x_g - $ext] $y_g [expr $x_g + $ext] $y_g" \
		dfps_guide_$guide -entire 1 \
		-x_min 0 -x_max $width \
		-y_min 0 -y_max $height -color 2
	lwdaq_graph "$x_g [expr $y_g - $ext] $x_g [expr $y_g + $ext]" \
		dfps_guide_$guide -entire 1 \
		-x_min 0 -x_max $width \
		-y_min 0 -y_max $height -color 2
	if {[winfo exists $info(window).mag_$guide]} {
		lwdaq_draw dfps_guide_$guide dfps_guide_mag_$guide \
			-intensify $config(intensify) -zoom $config(guide_mag_zoom)
	}
	lwdaq_draw dfps_guide_$guide dfps_guide_$guide \
		-intensify $config(intensify) -zoom $config(guide_zoom)
	return ""
}

#
# DFPS_Manager_local_from_guide takes a guide sensor number and an x and y
# coordinate in a guide sensor image, and returns the local coordinates of the
# image point. The guide coordinate system has its origin at the center of the
# center of the lower-left pixel in the guide image. The x-axis is to the right,
# the y-axis is upwards. Each guide sensor has stored for it a string of numbers
# giving the local coordinates of the sensor origin and the rotation of the
# guide x-axis anti-clockwise positive with respect to the local coordinate
# x-axis in milliradians. We can view these coordinate definitions in the
# Calibration Constants window, which we can open from the Utilities Panel with
# the View Calibration button. The local coordinate system is at the approximate
# center of the fiducial plate. Its origin is at x=local_coord_offset mm and
# y=local_coord_offset mm in the framed coordinate system. In the DFPS-4A, this
# offset is 65 mm. The frame coordinate system is at the front, lower-left
# corner of the fiducial plate, with its x-axis running along the front edge and
# the y-axis perpendicular to the fiducial stage.
#
proc DFPS_Manager_local_from_guide {guide x_g y_g} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	
	if {[lsearch $info(guide_sensors) $guide] < 0} {
		LWDAQ_print $info(text) "ERROR: No guide sensor \"$guide\" in local_from_guide."
		return "0 0"
	}
	
	scan $info(guide_$guide) %f%f%f xorigin yorigin rot
	set x_l [format %.3f [expr $xorigin + $x_g*cos($rot*0.001) - $y_g*sin($rot*0.001)]]
	set y_l [format %.3f [expr $yorigin + $y_g*cos($rot*0.001) + $x_g*sin($rot*0.001)]]
	
	if {$config(verbose)} {
		LWDAQ_print $info(text) "local_from_guide guide=$guide x_g=$x_g y_g=$y_g\
			x_l=$x_l y_l=$y_l" $info(vcolor)
	}
	if {$config(report)} {
		LWDAQ_print $info(text) "$x_g $y_g $x_l $y_l" 
	}
	DFPS_Manager_gmark $guide $x_g $y_g	
	
	return "$x_l $y_l"
}

#
# DFPS_Manager_guide_from_local takes a local coordinate position and transforms it into
# the coordinates of one of the guide sensors. See comments on the local_from_global routine
# for more details of the coordinate systems.
#
proc DFPS_Manager_guide_from_local {guide x_l y_l} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info
	
	if {[lsearch $info(guide_sensors) $guide] < 0} {
		LWDAQ_print $info(text) "ERROR: No guide sensor \"$guide\" in guide_from_local."
		return "0 0"
	}
	
	scan $info(guide_$guide) %f%f%f xorigin yorigin rot
	set x_g [format %.3f [expr \
		($x_l - $xorigin)*cos($rot*0.001) + ($y_l - $yorigin)*sin($rot*0.001)]]
	set y_g [format %.3f [expr \
		($y_l - $yorigin)*cos($rot*0.001) - ($x_l - $xorigin)*sin($rot*0.001)]]
	if {$config(verbose)} {
		LWDAQ_print $info(text) "guide_from_local guide=$guide x_l=$x_l y_l=$y_l\
			x_g=$x_g y_g=$y_g" $info(vcolor)
	}		
	if {$config(report)} {
		LWDAQ_print $info(text) "$x_l $y_l $x_g $y_g" 
	}
	DFPS_Manager_gmark $x_g $y_g	

	return "$x_g $y_g"
}

#
# DFPS_Manager_guide_click handles mouse clicks on guide sensor images. It takes
# a guide sensor number, an x and y coordinate, and a command. The mag_g command
# tells the routine to open a new magnified view of a guide sensor. The mark_g
# and mark_gm commands tell the routine to mark a guide sensor view, based upon
# the x-y coordinates of a mouse click in the normal guide sensor display or the
# magnified guide sensor display. The actual marking, which will be a cross of 
# some sort, will be done in the gmark routine, which will in turn be called by
# local_from_guide, which we call from this routine.
#
proc DFPS_Manager_guide_click {guide x y cmd} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	if {[lsearch $info(guide_sensors) $guide] < 0} {
		LWDAQ_print $info(text) "ERROR: No guide sensor \"$guide\" in mag_guide."
		return ""
	}
	
	if {$cmd == "mag_g"} {
		set w $info(window).mag_$guide
		if {[winfo exists $w]} {
			raise $w
		} else {
			toplevel $w
			wm title $w "Guide $guide, DFPS Manager $info(version)"
			image create photo dfps_guide_mag_$guide
			label $w.img -image dfps_guide_mag_$guide
			pack $w.img -side top
			bind $w.img <Button-1> \
				[list LWDAQ_post "DFPS_Manager_guide_click $guide %x %y mark_gm"]
		}
	
		lwdaq_draw dfps_guide_$guide dfps_guide_mag_$guide \
			-intensify $config(intensify) -zoom $config(guide_mag_zoom)
	}	

	if {($cmd == "mark_gm") || ($cmd == "mark_g")} {
		switch $cmd {
			"mark_gm" {set zoom $config(guide_mag_zoom)}
			"mark_g"  {set zoom $config(guide_zoom)}
			default {set zoom 1}
		}
		if {$zoom < 1.0} {
			set pix [expr round(1.0/$zoom)*$info(icx424_pix_um)]
		} else {
			set pix [expr round($zoom)*$info(icx424_pix_um)]
		}
		set y_g [format %.3f [expr 0.001*( \
			$info(guide_height_um)-$pix*($y+$config(mouse_offset_y)))]]
		set x_g [format %.3f [expr 0.001*( \
			$pix*($x+$config(mouse_offset_x)))]]
		if {$config(verbose)} {
			LWDAQ_print $info(text) \
				"guide_click guide=$guide x=$x y=$y cmd=$cmd\
					zoom=$zoom pix=[format %.3f $pix]" $info(vcolor)
		}
		set local [DFPS_Manager_local_from_guide $guide $x_g $y_g]
	}
		
	return ""
}

#
# DFPS_Manager_open creates the DFPS Manager window.
#
proc DFPS_Manager_open {} {
	upvar #0 DFPS_Manager_config config
	upvar #0 DFPS_Manager_info info

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
	
	set i 0
	set f [frame $w.f[incr i]]
	pack $f -side top -fill x
	
	label $f.state -textvariable DFPS_Manager_info(state) -width 20 -fg blue
	pack $f.state -side left -expand yes
	
	foreach {a b} {"Masts" mast_measure_all \
		"Show" show_spots \
		"Reset" reset_masts \
		"Guides" acquire_guides \
		"Utilities" utils} {
		button $f.$b -text $a -command "LWDAQ_post DFPS_Manager_$b"
		pack $f.$b -side left -expand yes
	}
	
	button $f.configure -text "Configure" -command "LWDAQ_tool_configure DFPS_Manager 4"
	pack $f.configure -side left -expand yes
	button $f.help -text "Help" -command "LWDAQ_tool_help DFPS_Manager"
	pack $f.help -side left -expand yes
	
	set f [frame $w.f[incr i]]
	pack $f -side top -fill x

	foreach a {Enable_Mast_Control Report Verbose} {
		set b [string tolower $a]
		checkbutton $f.$b -text $a -variable DFPS_Manager_config($b)
		pack $f.$b -side left -expand yes
	}

	foreach a {ip_addr flash_s expose_s} {
		label $f.l$a -text "$a\:" -fg $info(label_color)
		entry $f.e$a -textvariable DFPS_Manager_config($a) \
			-width [string length $config($a)]
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	set f [frame $w.f[incr i]]
	pack $f -side top -fill x
	
	foreach guide $info(guide_sensors) {
		image create photo "dfps_guide_$guide"
		label $f.l$guide -image "dfps_guide_$guide"
		bind $f.l$guide <Double-Button-1> [list LWDAQ_post \
			"DFPS_Manager_guide_click $guide 0 0 mag_g"]
		pack $f.l$guide -side left -expand yes
		lwdaq_draw dfps_guide_$guide dfps_guide_$guide \
			-intensify $config(intensify) -zoom $config(guide_zoom)
	}
	
	set lw 15
	set ew 12
	
	set f [frame $w.f[incr i]]
	pack $f -side top -fill x

	label $f.title -text "Mast Positions:" -fg $info(label_color) -width $lw
	pack $f.title -side left -expand yes
	foreach m $info(positioner_masts) {
		entry $f.e$m -textvariable DFPS_Manager_info(mast_$m) -width $ew
		pack $f.e$m -side left -expand yes
	}

	set f [frame $w.f[incr i]]
	pack $f -side top -fill x

	label $f.title -text "Mast Targets:" -fg $info(label_color) -width $lw
	pack $f.title -side left -expand yes
	foreach m $info(positioner_masts) {
		entry $f.e$m -textvariable DFPS_Manager_info(target_$m) -width $ew
		pack $f.e$m -side left -expand yes
	}

	set f [frame $w.f[incr i]]
	pack $f -side top -fill x
	
	foreach side {left right} {
		image create photo "dfps_fvc_$side"
		label $f.$side -image "dfps_fvc_$side"
		pack $f.$side -side left -expand yes
		lwdaq_draw dfps_fvc_$side dfps_fvc_$side \
			-intensify $config(intensify) -zoom $config(fvc_zoom)	
	}
	
	set info(text) [LWDAQ_text_widget $w 80 30 1 1]
	LWDAQ_print $info(text) "Manager Text Output" purple

	return $w
}

DFPS_Manager_init
DFPS_Manager_open
DFPS_Manager_watchdog

return ""

----------Begin Help----------


http://www.opensourceinstruments.com/DFPS/Manual.html


----------End Help----------

----------Begin Data----------

----------End Data----------