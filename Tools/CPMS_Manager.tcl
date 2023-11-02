# CPMS Calibrator a LWDAQ Tool
#
# Copyright (C) 2023 Kevan Hashemi, Open Source Instruments Inc.
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
# CPMS_Manager_init initializes the tool's configuration and information arrays.
#
proc CPMS_Manager_init {} {
	upvar #0 CPMS_Manager_info info
	upvar #0 CPMS_Manager_config config
	
	LWDAQ_tool_init "CPMS_Manager" "1.4"
	if {[winfo exists $info(window)]} {return ""}

	set config(cam_left) "12.283 38.549 4.568 -7.789 1.833 2.000 26.411 0.137" 
	set config(mount_left) "92.123 -18.364 -3.450\
		83.853 -18.211 -78.940\
		125.201 -17.747 -71.806"
	set config(coord_left) [lwdaq scam_coord_from_mount $config(mount_left)]
	set config(cam_right) "12.588 -38.571 4.827 -3.708 7.509 2.000 26.252 3144.919" 
	set config(mount_right) "-77.819 -20.395 -2.397\
		-74.201 -20.179 -75.451\
		-115.549 -20.643 -68.317"
	set config(coord_right) [lwdaq scam_coord_from_mount $config(mount_right)]
	
	set config(bodies) [list \
		{0.061 19.240 453.744 0.000 0.291 0.005 \
		sphere 0 0 0 38.068 \
		shaft 1 -27 0 0 -1 0 19 0 19 40} ]
	set config(scaling) "1 1 1 0 0.1 0.1"
	set config(fit_steps) "1000"
	set config(fit_restarts) "0"
	set config(num_lines) "50"
	set config(stop_fit) 0
	
	set config(zoom) "1.0"
	set config(intensify) "exact"
	set config(threshold) "5 %"
	
	set config(left_sensor_socket) "1"
	set config(right_sensor_socket) "2"
	set config(left_source_socket) "3"
	set config(right_source_socket) "4"
	
	set config(image_dir) "~/Desktop"
	set config(auto_fit) "0"
	set config(file_index) "0000000000"
	
	set info(projector_window) "$info(window).cpms_projector"

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
# CPMS_Manager_disagreement takes the two cpms images and obtains the number of
# pixels in which our modelled bodies and their actual silhouettes disagree. In
# doint so, the routine colors the overlay of the cpms images to show the modelled
# bodies and their silhouettes with the disagreement pixels colored blue for model
# without silhouette and orange for silhouette without model and no overlay color
# for agreement between the two.
#
proc CPMS_Manager_disagreement {params} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info

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
				$config(num_lines)
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
	set left_count [lwdaq_scam $info(img_left) disagreement $config(threshold)]
	set right_count [lwdaq_scam $info(img_right) disagreement $config(threshold)]
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
# string or its diameter and length parameters. 
#
proc CPMS_Manager_get_params {} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info
	
	set params ""
	foreach body $config(bodies) {append params "[lrange $body 0 5] "}
	return $params
}

#
# CPMS_Manager_show gets the parameters from the current modelled bodies, calculates
# the disagreement, and prints the current parameters and disagreement to the text
# window. 
#
proc CPMS_Manager_show {} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info

	set info(control) "Go"
	LWDAQ_update
	
	set config(coord_left) [lwdaq scam_coord_from_mount $config(mount_left)]
	set config(coord_right) [lwdaq scam_coord_from_mount $config(mount_right)]
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

	set newbodies [list]
	foreach body $config(bodies) {
		set x [format %.3f [expr [lindex $body 0] + (rand()-0.5)*10.0]]
		set y [format %.3f [expr [lindex $body 1] + (rand()-0.5)*10.0]]
		set z [format %.3f [expr [lindex $body 2] + (rand()-0.5)*10.0]]
		set rx [format %.3f [expr [lindex $body 3] + (rand()-0.5)*1.0]]
		set ry [format %.3f [expr [lindex $body 4] + (rand()-0.5)*1.0]]
		set rz [format %.3f [expr [lindex $body 5] + (rand()-0.5)*1.0]]
		
		lappend newbodies "$x $y $z $rx $ry $rz [lrange $body 6 end]"
	}
	LWDAQ_print $info(text) $newbodies
	set config(bodies) $newbodies
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
		set config(coord_left) [lwdaq scam_coord_from_mount $config(mount_left)]
		set config(coord_right) [lwdaq scam_coord_from_mount $config(mount_right)]
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
	CPMS_Manager_show
	
	set info(state) "Idle"
	return ""
}

#
# CPMS_Manager_pickdir picks a directory into which to write image files when
# we press call CPMS_Manager_write.
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
# CPMS_Manager_open opens the CPMS Manger Tool window.
#
proc CPMS_Manager_open {} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
	
	set f [frame $w.controls]
	pack $f -side top -fill x
	
	label $f.state -textvariable CPMS_Manager_info(state) -fg blue
	pack $f.state -side left -expand yes

	button $f.stop -text "Stop" -command {set CPMS_Manager_config(stop_fit) 1}
	pack $f.stop -side left -expand yes
	
	foreach a {Acquire Show Clear Displace Fit Pickdir Write Read} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post CPMS_Manager_$b"
		pack $f.$b -side left -expand yes
	}
	
	label $f.lfi -text "index:"
	entry $f.efi -textvariable CPMS_Manager_config(file_index) -width 12
	pack $f.lfi $f.efi -side left -expand yes

	checkbutton $f.af -variable CPMS_Manager_config(auto_fit) -text "auto_fit"
	pack $f.af -side left -expand yes

	foreach a {threshold} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable CPMS_Manager_config($a) -width 6
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	foreach a {Help Configure} {
		set b [string tolower $a]
		button $f.$b -text $a -command [list LWDAQ_tool_$b $info(name)]
		pack $f.$b -side left -expand 1
	}

	set f [frame $w.cameras]
	pack $f -side top -fill x

	foreach a {cam_left cam_right} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable CPMS_Manager_config($a) -width 50
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	button $f.scam -text "SCAM" -command {LWDAQ_post "LWDAQ_open SCAM"}
	pack $f.scam -side left -expand yes
	
	label $f.lnl -text "num_lines:"
	entry $f.enl -textvariable CPMS_Manager_config(num_lines) -width 5
	pack $f.lnl $f.enl -side left -expand yes
	
	set f [frame $w.mounts]
	pack $f -side top -fill x

	foreach a {mount_left mount_right} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable CPMS_Manager_config($a) -width 70
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	foreach a {bodies} {
		set f [frame $w.$a]
		pack $f -side top -fill x
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable CPMS_Manager_config($a) -width 180
		pack $f.l$a $f.e$a -side left -expand yes
	}

	set f [frame $w.images_a]
	pack $f -side top -fill x

	image create photo "cpms_photo_left"
	label $f.left_$a -image "cpms_photo_left"
	pack $f.left_$a -side left -expand yes
	image create photo "cpms_photo_right"
	label $f.right_$a -image "cpms_photo_right"
	pack $f.right_$a -side left -expand yes

	set info(text) [LWDAQ_text_widget $w 100 15]
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

Compound:
{0 20450 0.000 0.000 0.000 sphere 0 0 0 38.068 shaft 0 0 0 0 0 -1.57 1 0 1 40}

----------End Help----------

----------Begin Data----------

----------End Data----------