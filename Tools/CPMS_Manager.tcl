# CPMS Calibrator a LWDAQ Tool
# Copyright (C) 2023 Kevan Hashemi, Open Source Instruments Inc.
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <https://www.gnu.org/licenses/>.
#

#
# CPMS_Manager_init initializes the tool's configuration and information arrays.
#
proc CPMS_Manager_init {} {
	upvar #0 CPMS_Manager_info info
	upvar #0 CPMS_Manager_config config
	
	LWDAQ_tool_init "CPMS_Manager" "1.6"
	if {[winfo exists $info(window)]} {return ""}

	set config(cam_left) "12.283 38.549 4.568 -7.789 1.833 2.000 26.411 0.137" 
	set config(mount_left) "92.123 -18.364 -3.450\
		83.853 -18.211 -78.940\
		125.201 -17.747 -71.806"
	set config(coord_left) [lwdaq bcam_coord_from_mount $config(mount_left)]
	set config(cam_right) "12.588 -38.571 4.827 -3.708 7.509 2.000 26.252 3144.919" 
	set config(mount_right) "-77.819 -20.395 -2.397\
		-74.201 -20.179 -75.451\
		-115.549 -20.643 -68.317"
	set config(coord_right) [lwdaq bcam_coord_from_mount $config(mount_right)]
	
	set config(bodies) [list {0 20 450 0 0 0 sphere 0 0 0 38.068} ]
	set config(scaling) "1 1 1 0 0.1 0.1"
	set config(fit_steps) "1000"
	set config(fit_restarts) "0"
	set config(num_lines) "100"
	set config(line_width) "1"
	set config(stop_fit) "0"
	
	set config(zoom) "1.0"
	set config(intensify) "exact"
	
	set config(left_sensor_socket) "1"
	set config(right_sensor_socket) "2"
	set config(left_source_socket) "3"
	set config(right_source_socket) "4"
	
	set config(image_dir) "~/Desktop"
	set config(auto_fit) "0"
	set config(file_index) "0000000000"
	
	set info(calib_window) "$info(window).calib_window"
	set info(state) "Idle"

	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 

	set info(img_left) "cpms_img_left"
	lwdaq_image_create -name $info(img_left) -width 700 -height 520
	set info(img_right) "cpms_img_right"
	lwdaq_image_create -name $info(img_right) -width 700 -height 520

	return ""   
}

#
# CPMS_Manager_disagreement takes the two SCAM images and obtains the number of
# pixels in which our modelled bodies and their actual silhouettes disagree. In
# doing so, the routine colors the overlay of the SCAM images to show the
# modelled bodies and their silhouettes with the disagreement pixels colored
# blue for model without silhouette and orange for silhouette without model and
# no overlay color for agreement between the two.
#
proc CPMS_Manager_disagreement {params} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info
	upvar #0 LWDAQ_config_SCAM iconfig

	# If user has closed the manager window, generate an error so that we stop any
	# fitting that might be calling this routine. 
	if {![winfo exists $info(window)]} {
		error "Cannot draw CPMS images: no CPMS window open."
	}
	
	# Make sure messages from the SCAM routines get to the CPMS Manager's text
	# window. Set the number of decimal places to three.
	lwdaq_config -text_name $info(text)

	# We clear the overlays in the two CPMS images. We will be using the overlays
	# to keep track of silhouettes and bodies.
	lwdaq_image_manipulate $info(img_left) none -clear 1
	lwdaq_image_manipulate $info(img_right) none -clear 1
	
	# Go through each modelled body and project a drawing of it onto the image
	# plane of both of our SCAMs.
	foreach body $config(bodies) {
		
		foreach side {left right} {
			# The first six parameters in our parameter string are the pose of
			# the body that we want to try out. We project our body onto the
			# image sensor plane of the SCAM. We provide the mount coordinates,
			# the camera calibration constants, and our global-coordinate 
			# description of the body with its pose over-written by the pose
			# provided by the parameter string.
			lwdaq_scam $info(img_$side) project \
				$config(coord_$side) \
				"SCAM_$side $config(cam_$side)" \
				"[lrange $params 0 5] [lrange $body 6 end]" \
				-num_lines $config(num_lines) -line_width $config(line_width)
		}

		# We have made use of six parameters, which are what we need for one
		# body. We remove these six from our parameter list so that the next
		# six parameter will come to the front and be ready for the next body,
		# if any.
		set params [lrange $params 6 end]
	}

	# Go through both images and adjust the overlay to be orange for silhouette
	# only, blue for body only, and clear for agreement. Count the disagreeing
	# pixels.
	set disagreement 0
	set left_count [lindex [lwdaq_scam $info(img_left) disagreement \
		$iconfig(analysis_threshold)] 0]
	set right_count [lindex [lwdaq_scam $info(img_right) disagreement \
		$iconfig(analysis_threshold)] 0]
	set disagreement [expr $disagreement + $left_count + $right_count]

	# Draw the images with their overlays in the manager window.
	lwdaq_draw $info(img_left) cpms_photo_left \
		-intensify $config(intensify) -zoom $config(zoom)
	lwdaq_draw $info(img_right) cpms_photo_right \
		-intensify $config(intensify) -zoom $config(zoom)
			
	# Return the disagremenet. The fitter uses the disagreement as its error function.
	return $disagreement
}

#
# CPMS_Manager_get_params extracts from the bodies their postion and
# orientation. When we fit the model to the silhouettes, we will be adjusting
# the position and orientation of each modelled body, but not its body type
# string or its diameter and length parameters. The fitter will adjust any
# parameter for which we assign a scaling value greater than zero. The scaling
# string gives the scaling factors the fitter uses for each camera calibration
# constant. The scaling factors are used twice: once for the left camera and
# once for the right. See the fitting routine for their implementation.
#
proc CPMS_Manager_get_params {} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info
	
	set params ""
	foreach body $config(bodies) {append params "[lrange $body 0 5] "}
	return [string trim $params]
}

#
# CPMS_Manager_show gets the parameters from the current modelled bodies, calculates
# the disagreement, and prints the current parameters and disagreement to the text
# window. 
#
proc CPMS_Manager_show {} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info

	set info(control) "Show"
	LWDAQ_update
	
	set config(coord_left) [lwdaq bcam_coord_from_mount $config(mount_left)]
	set config(coord_right) [lwdaq bcam_coord_from_mount $config(mount_right)]
	set params [CPMS_Manager_get_params]
	set disagreement [CPMS_Manager_disagreement $params]
	LWDAQ_print -nonewline $info(text) "$config(file_index) " green
	set result "$params $disagreement"
	LWDAQ_print $info(text) $result
	
	set info(control) "Idle"
	return 
}

#
# CPMS_Manager_displace displaces the body position and orientation a random
# amount.
#
proc CPMS_Manager_displace {} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info

	for {set i 0} {$i < [llength $config(bodies)]} {incr i} {
		for {set j 0} {$j < 6} {incr j} {
			lset config(bodies) $i $j [format %.3f \
				[expr [lindex $config(bodies) $i $j] \
					+ (rand()-0.5)*10.0*[lindex $config(scaling) $j]]]
		}
	}
	CPMS_Manager_disagreement [CPMS_Manager_get_params]
	return [CPMS_Manager_get_params]
} 

#
# CPMS_Manager_altitude is the error function for the fitter. The fitter calls
# this routine with a set of parameter values to get the disgreement, which it
# is attemptint to minimise.
#
proc CPMS_Manager_altitude {params} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info

	if {$config(stop_fit)} {error "Fit aborted by user"}
	if {![winfo exists $info(window)]} {error "Tool window destroyed"}
	set count [CPMS_Manager_disagreement "$params"]
	LWDAQ_support
	
	return $count
}

#
# CPMS_Manager_fit gets the body parameters as a starting point and calls the
# simplex fitter to minimise the disagreement between the modelled and actual
# bodies. The size of the adjustments the fitter makes in each parameter during
# the fit will be shrinking as the fit proceeds, but relative to one another
# thye will be in proportion to the list of scaling factors we have provided. If
# the scaling factors are all unity, all parameters are fitted with equal steps.
# If a scaling factor is zero, the parameter will not be adjusted. If a scaling
# factor is 10, the parameter will be adjusted by ten times the amount as a
# parameter with scaling factor one. At the end of the fit, we take the final
# fitted parameter values and apply them to our body models.
#
proc CPMS_Manager_fit {} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info

	set config(stop_fit) 0
	set info(state) "Fitting"
	LWDAQ_update
	
	if {[catch {
		set config(coord_left) [lwdaq bcam_coord_from_mount $config(mount_left)]
		set config(coord_right) [lwdaq bcam_coord_from_mount $config(mount_right)]
		set start_params [CPMS_Manager_get_params]
		set scaling ""
		foreach body $config(bodies) {append scaling "$config(scaling) "}
		set result [lwdaq_simplex $start_params CPMS_Manager_altitude \
			-report 0 \
			-steps $config(fit_steps) \
			-restarts $config(fit_restarts) \
			-start_size 1.0 \
			-end_size 0.01 \
			-scaling $scaling]
		if {[LWDAQ_is_error_result $result]} {error "$result"}
		LWDAQ_print -nonewline $info(text) "$config(file_index) " green	
		LWDAQ_print $info(text) $result black
		set newbodies [list]
		foreach body $config(bodies) {
			lappend newbodies "[lrange $result 0 5] [lrange $body 6 end]"
			set result [lrange $result 6 end]
		}
		set config(bodies) $newbodies
	} error_message]} {
		LWDAQ_print $info(text) $error_message
		set info(state) "Idle"
		return ""
	}

	CPMS_Manager_disagreement [CPMS_Manager_get_params]
	set info(state) "Idle"
	return $result
}

#
# CPMS_Manager_clear clears the overlay pixels in the cpms images, so that we see
# only the original silhouette images.
#
proc CPMS_Manager_clear {} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info

	set info(state) "Clear"
	LWDAQ_update
	
	lwdaq_image_manipulate $info(img_left) none -clear 1
	lwdaq_image_manipulate $info(img_right) none -clear 1	
	lwdaq_draw $info(img_left) cpms_photo_left \
		-intensify $config(intensify) -zoom $config(zoom)
	lwdaq_draw $info(img_right) cpms_photo_right \
		-intensify $config(intensify) -zoom $config(zoom)
		
	set info(state) "Idle"
	return ""
}

#
# CPMS_Manager_acquire uses the SCAM Instrument to acquire two SCAM images, thus
# obtaining a stereo CPMS pair of images.
#
proc CPMS_Manager_acquire {} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info
	upvar #0 LWDAQ_config_SCAM iconfig
	
	set info(state) "Acquire"
	LWDAQ_update
	
	set iconfig(daq_driver_socket) $config(left_sensor_socket)
	set iconfig(daq_source_driver_socket) $config(left_source_socket)
	set result [LWDAQ_acquire SCAM]
	if {[LWDAQ_is_error_result $result]} {
		LWDAQ_print $info(text) $result
		set info(state) "Idle"
		return ""
	}
	lwdaq_image_manipulate $iconfig(memory_name) copy -name $info(img_left)
	
	set iconfig(daq_driver_socket) $config(right_sensor_socket)
	set iconfig(daq_source_driver_socket) $config(right_source_socket)
	set result [LWDAQ_acquire SCAM]
	if {[LWDAQ_is_error_result $result]} {
		LWDAQ_print $info(text) $result
		set info(state) "Idle"
		return ""
	}
	lwdaq_image_manipulate $iconfig(memory_name) copy -name $info(img_right)
	
	set config(file_index) [clock seconds]
	if {$config(auto_fit)} {
		CPMS_Manager_fit
	} else {
		CPMS_Manager_show
	}
	
	set info(state) "Idle"
	return ""
}

#
# CPMS_Manager_pickdir picks a directory into which to write image files when we
# press call CPMS_Manager_write.
#
proc CPMS_Manager_pickdir {} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info

	set info(state) "Pickdir"
	LWDAQ_update

	set dirname [LWDAQ_get_dir_name]
	if {$dirname != ""} {
		set config(image_dir) $dirname
	}
	
	set info(state) "Idle"
	return ""
}

#
# CPMS_Manager_write writes both cpms images into the image directory, giving
# them both names S followed by UNIX timestamp and suffix L or R followed by .gif.
#
proc CPMS_Manager_write {} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info

	set info(state) "Write"
	LWDAQ_update
	
	if {![file exists $config(image_dir)]} {
		LWDAQ_print $info(text) "ERROR: Cannot find image directory\
			\"$config(image_dir)\"."
		set info(state) "Idle"
		return ""
	}
	set fn [file join $config(image_dir) S$config(file_index)_L.gif]
	LWDAQ_write_image_file $info(img_left) $fn		
	LWDAQ_print $info(text) "Wrote left-hand image to \"$fn\"."
	set fn [file join $config(image_dir) S$config(file_index)_R.gif]
	LWDAQ_write_image_file $info(img_right) $fn
	LWDAQ_print $info(text) "Wrote right-hand image to \"$fn\"."
	
	set info(state) "Idle"
	return ""
}

#
# CPMS_Manager_read reads pairs of image files from disk. It opens a browser in
# the image directory and allows us to select images. We must selet an even
# number of images for the read to complete. Each pair of stereo image files
# must be named in the CPMS format, which is L and UNIX time with GIF extension
# for left and same with R for right. If auto_fit is set, the routine fits the
# modelled bodies to each pair of images and prints results to text window.
#
proc CPMS_Manager_read {} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info
	global LWDAQ_Info

	set info(state) "Read"
	LWDAQ_update
	
	if {[file exists $config(image_dir)]} {
		set LWDAQ_Info(working_dir) $config(image_dir)
	}
	set fnl [lsort -increasing [LWDAQ_get_file_name 1]]
	foreach {lfn rfn} $fnl {
		LWDAQ_read_image_file $lfn $info(img_left)
		LWDAQ_read_image_file $rfn $info(img_right)
		if {[regexp {S([0-9]{10})} [file tail $lfn] match ts]} {
			set config(file_index) $ts
		} else {
			set config(file_index) [file root [file tail $lfn]]
		}
		if {$config(auto_fit)} {
			CPMS_Manager_fit
		} else {
			CPMS_Manager_show
		}
	}
	
	set info(state) "Idle"
	return ""
}

#
# CPMS_Manager_calibration opens a new window that displays the calibration constants
# of the left and right cameras, as well as the mounting ball measurements in CPMS
# coordinates.
#
proc CPMS_Manager_calibration {} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info

	set w $info(calib_window)
	if {![winfo exists $w]} {
		toplevel $w
		wm title $w "Calibration Constants, CPMS Manager $info(version)"
	} {
		raise $w
		return ""
	}

	set f [frame $w.buttons]
	pack $f -side top -fill x
	button $f.save -text "Save Configuration" -command "LWDAQ_tool_save $info(name)"
	pack $f.save -side left -expand 1
	button $f.unsave -text "Unsave Configuration" -command "LWDAQ_tool_unsave $info(name)"
	pack $f.unsave -side left -expand 1
	
	foreach a {cam_left cam_right} {
		set f [frame $w.$a]
		pack $f -side top -fill x
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable CPMS_Manager_config($a) -width 70
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	foreach a {mount_left mount_right} {
		set f [frame $w.$a]
		pack $f -side top -fill x
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable CPMS_Manager_config($a) -width 70
		pack $f.l$a $f.e$a -side left -expand yes
	}
}

#
# CPMS_Manager_open opens the CPMS Manger Tool window.
#
proc CPMS_Manager_open {} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
	
	set f [frame $w.controls]
	pack $f -side top -fill x
	
	label $f.state -textvariable CPMS_Manager_info(state) -fg blue -width 10
	pack $f.state -side left -expand yes

	button $f.stop -text "Stop" -command {set CPMS_Manager_config(stop_fit) 1}
	pack $f.stop -side left -expand yes
	
	foreach a {Acquire Show Clear Displace Fit Calibration Pickdir Write Read} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post CPMS_Manager_$b"
		pack $f.$b -side left -expand yes
	}
	
	checkbutton $f.af -variable CPMS_Manager_config(auto_fit) -text "auto_fit"
	pack $f.af -side left -expand yes

	label $f.lfi -text "index:"
	entry $f.efi -textvariable CPMS_Manager_config(file_index) -width 12
	pack $f.lfi $f.efi -side left -expand yes

	foreach a {Help Configure} {
		set b [string tolower $a]
		button $f.$b -text $a -command [list LWDAQ_tool_$b $info(name)]
		pack $f.$b -side left -expand 1
	}

	set f [frame $w.cameras]
	pack $f -side top -fill x

	foreach a {daq_flash_seconds analysis_threshold} {
		label $f.l$a -text "$a"
		entry $f.e$a -textvariable LWDAQ_config_SCAM($a) -width 4
		pack $f.l$a $f.e$a -side left -expand yes
	}

	foreach a {num_lines line_width left_sensor_socket right_sensor_socket \
		left_source_socket right_source_socket} {
		label $f.l$a -text "$a"
		entry $f.e$a -textvariable CPMS_Manager_config($a) -width 3
		pack $f.l$a $f.e$a -side left -expand yes
	}

	button $f.scam -text "SCAM" -command {LWDAQ_post "LWDAQ_open SCAM"}
	pack $f.scam -side left -expand yes
	
	set f [frame $w.bodies]
	pack $f -side top -fill x
	
	label $f.lbodies -text "bodies:"
	entry $f.ebodies -textvariable CPMS_Manager_config(bodies) -width 130
	pack $f.lbodies $f.ebodies -side left -expand yes

	label $f.lscaling -text "scaling:"
	entry $f.escaling -textvariable CPMS_Manager_config(scaling) -width 20
	pack $f.lscaling $f.escaling -side left -expand yes

	set f [frame $w.images_a]
	pack $f -side top -fill x

	image create photo "cpms_photo_left"
	label $f.limg -image "cpms_photo_left"
	pack $f.limg -side left -expand yes
	image create photo "cpms_photo_right"
	label $f.rimg -image "cpms_photo_right"
	pack $f.rimg -side left -expand yes

	set info(text) [LWDAQ_text_widget $w 150 15]
	LWDAQ_print $info(text) "$info(name) Version $info(version)\n" purple
	lwdaq_config -text_name $info(text) -fsd 3
	
	lwdaq_draw $info(img_left) cpms_photo_left \
		-intensify $config(intensify) -zoom $config(zoom)
	lwdaq_draw $info(img_right) cpms_photo_right \
		-intensify $config(intensify) -zoom $config(zoom)

	return $w
}

CPMS_Manager_init
CPMS_Manager_open
	
return ""

----------Begin Help----------

The Contactless Position Measurement System (CPMS) Manager uses stereo
Silhouette Cameras (SCAMs) to measures the position of one or more bodies. The
manager must be provided with Coordinate Measuring Machine (CMM) measurements of
the three balls on the left and right SCAM mounts. We must configure the SCAM
Instrument to capture images from one of the two SCAMs, and we must direct the
manager in selecting the left and right SCAMs by entering the LWDAQ driver
socket of the left and right cameras and backlights. When we have the manager
set up correctly, we can acquire and analyze images in a few seconds to obtain
the position of bodies such as spheres, cylinders, and flanges.

We describe the bodies we want the manager to find with the help of a list that
we enter in the "bodies" entry box in the manager window. We enclose each body
in braces. The description of each body begins with its "pose", which is its
location and orientation in global coordinates. The location is x, y, and z. The
orientation is three angles that specify three rotations made about the x, y,
and z axes in the order x, y, and z. The pose is what will be adjusted by the
manger to produce its measurement of body position and orientation.

Each body consists of one or more "objects". An object begins with a name, such
as "sphere" or "shaft". Each object has its own position in the body coordinate
system. The "body coordinate system" is the one we obtain by translating the
global coordinate system by the body position and rotating the global coordinate
system by the body orientation. A sphere has only a position and a diameter. A
shaft consists of one or more circular "faces" along an axis. We specify the
direction of the axis with a vector in the body coordinate system. Here are some
example bodies.

One body, a sphere (1.5-inch diameter):
{0 10 450 0 0 0 sphere 0 0 0 38.10}

Single body, a sphere (1.5-inch diameter) sitting on a post (0.75-inch diameter):
{0 10 450 0 0 0 sphere 0 0 0 38.10 shaft 1 -19.05 0 0 -1 0 19.05 0 19.05 40}

Two bodies, one a sphere (1.5-inch diameter), another a sphere (0.75-inch diameter):
{0 10 450 0 0 0 sphere 0 0 0 38.10} {40 10 450 0 0 0 sphere 0 0 0 19.05}

Single body, a shaft with a bolt-alignment rod:
{-5 10 550 0 0 0 shaft 1 0 0 1 0 0 50 0 50 20 20 20 20 50 30 50 30 55 shaft 10 25 0 0 1 0 4 0 4 20}

The "scaling" string dictates which elements of the body pose will be adjusted,
and rapidly they will be adjusted. For bodies with no axis of symmetry, we set
the scaling parameter to "1 1 1 0.1 0.1 0.1". The position of the body will be
adjusted by one millimeter at first, and each rotation angle by 0.1 radians. As
the fit progresses and the adjustments shrink, the size of the position
adjustments in millimeters will remain ten times the angle adjustments in
radians. If a body is radially symmetric, align its axis of symmetry with the
global x-coordinate axis and instruct the fitter not to adjust the rotation of
the body about the x-axis, which is the first of the three rotations that the
fitter applies when applying the body orientation. We don't want the fitter to
adjust more parameters than are absolutely necessary, so that it will converge
faster and more accurately. To disable the x-axis rotation, we set the fourth
value in the scaling string to zero. For a single sphere object, we disable the
orientation fit all together, by setting the fourth, fifth, and sixth elements
of scaling to zero.

The manager works by minimizing disagreement between actual silhouettes and a
line drawing of modelled bodies. The line drawing can be sparse, as when
num_lines = 20, or filled completely, as when num_lines = 2000. We can increase
the thickness of the lines with line_width. The silhouettes will be drawn using
the intensity threshold dictated by the threshold string. When we press Fit, the
simplex fitter starts minimizing the disagreement by adjusting the pose of each
body. This process should take no more than a few seconds. If the fit fails to
converge, we can stop it with the Stop button. The manager buttons have the
following functions.

Stop: Abort fitting.

Acquire: Obtain new images.

Show: Show the silhouettes and line drawings.

Clear: Clear the silhouettes and line drawings, show the raw images.

Displace: Displace the camera calibration constants from their current values.

Fit: Start the simplex fitter adjusting calibration constants to minimize
disagreement.

Calibration: Open the calibration panel, in which we see the calibration
constants of the left and right SCAMs, and the mount measurements of the left
and right mounts.

Pickdir: Select a directory into which to write images and from which to read images.

Write: Write both images to disk with the current index in their name, preceeded by
the letter L or R for left and right cameras.

Read: Read one or more pairs of images with L and R as prefix in their file names to
indicate left and right. 

Help: Get this help page.

Configure: Open configuration panel with Save and Unsave buttons.

SCAM: Open the SCAM Instrument.

To use the calibrator, press SCAM to open the SCAM Instrument. Set up the
instrument to take images from one of the SCAMs. Confirm that it can take images
from the other SCAM too. In the manager window, enter the CPMS sensor and source
socket numbers that select the left and right SCAMs. Press Acquire. You should
get images, silhouettes shaded in orange and modelled objects projected with
blue lines. If the objects are overlapping the silhouettes and of the same
shape, press Fit. The modelled bodies will start moving around. The status
indicator on the top left will say "Fitting". After a few seconds, the status
label should return to "Idle". The body pose measurement is now available.

The parameters available in the manager window entry boxes are the ones you are
most likely to adjust during operation.

auto_fit: Check to apply the fitter whenever we acquire or read a pair of
images.

daq_flash_seconds: The SCAM Instrument's backlight flash time.

analysis_threshold: the SCAM Instrument's threshold control string.

num_lines: The number of perimiter points used to obtain drawing lines during
projection.

line_width: The width of the drawing lines, in units of pixels.

left_sensor_socket: The driver socket used by the left SCAM.

right_sensor_socket: The driver socket used by the right SCAM.

left_source_socket: The driver socket used by the left SCAM's backlight.

right_source_socket: The driver socket used by the right SCAM's backlight.

bodies: The list of bodies, ecample "{0 10 450 0 0 0 sphere 0 0 0 38.10}" for
1.5-inch diameter sphere.

scaling: the scaling string, example "1 1 1 0 0.1 0.1" for a shaft.

(C) Kevan Hashemi, 2023, Open Source Instruments Inc.
https://www.opensourceinstruments.com

----------End Help----------

----------Begin Data----------

----------End Data----------