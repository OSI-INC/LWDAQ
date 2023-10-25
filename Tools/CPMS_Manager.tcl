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
	
	LWDAQ_tool_init "CPMS_Manager" "1.3"
	if {[winfo exists $info(window)]} {return ""}

	set config(cam_left) "12.283 38.549 4.568 -7.789 1.833 2.000 26.411 0.137" 
	set config(mount_left) "92.123 -18.364 -3.450 \
		83.853 -18.211 -78.940 \
		125.201 -17.747 -71.806"
	set config(cam_right) "12.588 -38.571 4.827 -3.708 7.509 2.000 26.252 3144.919" 
	set config(mount_right) "-77.819 -20.395 -2.397 \
		-74.201 -20.179 -75.451 \
		-115.549 -20.643 -68.317"
		
	set config(objects) [list "sphere 20 20 500 0 0 0 38.068"]
	set config(fit_steps) "1000"
	set config(fit_restarts) "0"
	set config(num_lines) "200"
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
	
	set info(projector_window) "$info(window).cpms_projector"

	set info(state) "Idle"

	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 

	lwdaq_image_create -name cpms_img_left -width 700 -height 520
	lwdaq_image_create -name cpms_img_right -width 700 -height 520

	return ""   
}

#
# CPMS_Manager_disagreement takes the two cpms images and obtains the number of
# pixels in which our modelled objects and their actual silhouettes disagree. In
# doint so, the routine colors the overlay of the cpms images to show the modelled
# objects and their silhouettes with the disagreement pixels colored blue for model
# without silhouette and orange for silhouette without model and no overlay color
# for agreement between the two.
#
proc CPMS_Manager_disagreement {params} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info

	if {![winfo exists $info(window)]} {
		error "Cannot draw CPMS images: no CPMS window open."
	}

	set lc "LC $config(cam_left)"
	set rc "RC $config(cam_right)"
	
	lwdaq_image_manipulate cpms_img_left none -clear 1
	lwdaq_image_manipulate cpms_img_right none -clear 1
		
	set disagreement 0
	foreach obj $config(objects) {
		set lp [lwdaq bcam_from_global_point [lrange $params 0 2] $config(mount_left)]
		set ld [lwdaq bcam_from_global_vector [lrange $params 3 5] $config(mount_left)]
		set lo "[lindex $obj 0] $lp $ld [lrange $obj 7 end]"
		lwdaq_scam cpms_img_left project $lc $lo $config(num_lines)

		set rp [lwdaq bcam_from_global_point [lrange $params 0 2] $config(mount_right)]
		set rd [lwdaq bcam_from_global_vector [lrange $params 3 5] $config(mount_right)]
		set ro "[lindex $obj 0] $rp $rd [lrange $obj 7 end]"
		lwdaq_scam cpms_img_right project $rc $ro $config(num_lines)

		set left_count [lwdaq_scam cpms_img_left disagreement $config(threshold)]
		set right_count [lwdaq_scam cpms_img_right disagreement $config(threshold)]
		set disagreement [expr $disagreement + $left_count + $right_count]

		lwdaq_draw cpms_img_left cpms_photo_left \
			-intensify $config(intensify) -zoom $config(zoom)
		lwdaq_draw cpms_img_right cpms_photo_right \
			-intensify $config(intensify) -zoom $config(zoom)
			
		set params [lrange $params 6 end]
	}

	return $disagreement
}

#
# CPMS_Manager_get_params extracts from the objects their postion and
# orientation When we fit the model to the silhouettes, we will be adjusting the
# position and orientation of each modelled object, but not its object type
# string or its diameter and length parameters. 
#
proc CPMS_Manager_get_params {} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info
	
	set params ""
	foreach obj $config(objects) {append params "[lrange $obj 1 6] "}
	return $params
}

#
# CPMS_Manager_show gets the parameters from the current modelled objects, calculates
# the disagreement, and prints the current parameters and disagreement to the text
# window. 
#
proc CPMS_Manager_show {} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info

	set info(control) "Go"
	LWDAQ_update
	
	set params [CPMS_Manager_get_params]
	set disagreement [CPMS_Manager_disagreement $params]
	set result "$params $disagreement"
	LWDAQ_print $info(text) $result
	
	set info(control) "Idle"
	return 
}

#
# CPMS_Manager_displace displaces the object position and orientation a random
# amount.
#
proc CPMS_Manager_displace {} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info

	for {set i 0} {$i < [llength $config(objects)]} {incr i} {
		set x [lindex $config(objects) $i 1]
		lset config(objects) $i 1 [format %.3f [expr $x + (rand()-0.5)*10.0]]
		set y [lindex $config(objects) $i 2]
		lset config(objects) $i 2 [format %.3f [expr $y + (rand()-0.5)*10.0]]
		set z [lindex $config(objects) $i 3]
		lset config(objects) $i 3 [format %.3f [expr $z + (rand()-0.5)*100.0]]
	}
	CPMS_Manager_disagreement [CPMS_Manager_get_params]
	return [CPMS_Manager_get_params]
} 

#
# CPMS_Manager_altitude is the error function for the fitter. The fitter calls this
# routine with a set of parameter values to get the disgreement, which it is 
# attemptint to minimise.
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
# CPMS_Manager_fit gets the object parameters as a starting point and calls the
# simplex fitter to minimise the disagreement between the modelled and actual
# objects. The size of the adjustments the fitter makes in each parameter during
# the fit will be shrinking as the fit proceeds, but relative to one another thye
# will be in proportion to the list of scaling factors we have provided. If the
# scaling factors are all unity, all parameters are fitted with equal steps. If 
# a scaling factor is zero, the parameter will not be adjusted. If a scaling factor
# is 10, the parameter will be adjusted by ten times the amount as a parameter with
# scaling factor one. At the end of the fit, we take the final fitted parameter
# values and apply them to our object models.
#
proc CPMS_Manager_fit {} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info

	set config(stop_fit) 0
	set info(state) "Fitting"
	LWDAQ_update
	
	if {[catch {
		set start_params [CPMS_Manager_get_params]
		set scaling ""
		foreach obj $config(objects) {
			append scaling "1 1 10 "
			if {[lindex $obj 0] != "sphere"} {
				append scaling "1 1 1 "
			} else {
				append scaling "0 0 0 "
			}
		}
		set result [lwdaq_simplex $start_params CPMS_Manager_altitude \
			-report 0 \
			-steps $config(fit_steps) \
			-restarts $config(fit_restarts) \
			-start_size 1.0 \
			-end_size 0.01 \
			-scaling $scaling]
		if {[LWDAQ_is_error_result $result]} {error "$result"}
		LWDAQ_print $info(text) $result black
		set obj_num 0
		foreach {x y z rx ry rz} [lrange $result 0 end-2] {
			lset config(objects) $obj_num 1 $x
			lset config(objects) $obj_num 2 $y
			lset config(objects) $obj_num 3 $z
			lset config(objects) $obj_num 4 $rx
			lset config(objects) $obj_num 5 $ry
			lset config(objects) $obj_num 6 $rz
			incr obj_num
		}
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
	
	lwdaq_image_manipulate cpms_img_left none -clear 1
	lwdaq_image_manipulate cpms_img_right none -clear 1	
	lwdaq_draw cpms_img_left cpms_photo_left \
		-intensify $config(intensify) -zoom $config(zoom)
	lwdaq_draw cpms_img_right cpms_photo_right \
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
	lwdaq_image_manipulate $iconfig(memory_name) copy -name cpms_img_left
	
	set iconfig(daq_driver_socket) $config(right_sensor_socket)
	set iconfig(daq_source_driver_socket) $config(right_source_socket)
	set result [LWDAQ_acquire SCAM]
	if {[LWDAQ_is_error_result $result]} {
		LWDAQ_print $info(text) $result
		set info(state) "Idle"
		return ""
	}
	lwdaq_image_manipulate $iconfig(memory_name) copy -name cpms_img_right
	
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
	set cs [clock seconds]
	set fn [file join $config(image_dir) S$cs\_L.gif]
	LWDAQ_write_image_file cpms_img_left $fn		
	LWDAQ_print $info(text) "Wrote left-hand image to \"$fn\"."
	set fn [file join $config(image_dir) S$cs\_R.gif]
	LWDAQ_write_image_file cpms_img_right $fn
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
# modelled objects to each pair of images and prints results to text window.
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
	set fnl [LWDAQ_get_file_name 1]
	foreach {lfn rfn} $fnl {
		LWDAQ_read_image_file $lfn cpms_img_left
		LWDAQ_read_image_file $rfn cpms_img_right
		if {[regexp {S([0-9]{10})} [file tail $lfn] match ts]} {
			set name $ts
		} else {
			set name [file tail $lfn]
		}
		if {$config(auto_fit)} {
			LWDAQ_print -nonewline $info(text) "$name " green
			CPMS_Manager_fit
		} else {
			LWDAQ_print -nonewline $info(text) "$name " green
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

	foreach a {Acquire Show Clear Displace Fit Pickdir Write Read} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post CPMS_Manager_$b"
		pack $f.$b -side left -expand yes
	}
	
	checkbutton $f.af -variable CPMS_Manager_config(auto_fit) -text "auto_fit"
	pack $f.af -side left -expand yes

	button $f.stop -text "Stop" -command {
		set CPMS_Manager_config(stop_fit) 1
	}
	pack $f.stop -side left -expand yes
	
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
	
	foreach a {objects} {
		set f [frame $w.$a]
		pack $f -side top -fill x
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable CPMS_Manager_config($a) -width 150
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
	lwdaq_config -text_name $info(text) -fsd 3
	LWDAQ_print $info(text) "$info(name) Version $info(version)\n" purple
	
	lwdaq_draw cpms_img_left cpms_photo_left \
		-intensify $config(intensify) -zoom $config(zoom)
	lwdaq_draw cpms_img_right cpms_photo_right \
		-intensify $config(intensify) -zoom $config(zoom)

	return $w
}

CPMS_Manager_init
CPMS_Manager_open
	
return ""

----------Begin Help----------

Before acquiring live images, configure SCAM instrument to acquire either the
left or right imageThe compound object being viewed we describe with a list of
objects. Here are some example lists.

Sphere:
{sphere 20 20 500 0 0 0 38.068}

Cylinder:
{cylinder 0 0 500 1 0 0 20 30}

Sphere on Post:
{sphere 20 20 500 0 0 0 40} {cylinder 20 0 500 0 -1 0 20 50}

Shaft:
{shaft 20 20 500 1 0 0 0 -20 20 -20 30 10 36 10 40 12 40 30 60 30 60 39 58 40 0 40}
			
Compound:
{cylinder 0 0 0 1 0 0 33.78 7.24} {cylinder 0 0 0 1 0 0 19.00 -20.0} {cylinder 3.62 16.89 0 0 1 0 4 10}

----------End Help----------

----------Begin Data----------

----------End Data----------