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
	
	LWDAQ_tool_init "CPMS_Manager" "1.1"
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
	set config(scaling) "1 1 10 0 0 0"
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
	
	set info(projector_window) "$info(window).cpms_projector"

	set info(state) "Idle"

	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 

	lwdaq_image_create -name cpms_img_left -width 700 -height 520
	lwdaq_image_create -name cpms_img_right -width 700 -height 520

	return ""   
}

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

proc CPMS_Manager_get_params {} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info
	
	set params ""
	foreach obj $config(objects) {append params "[lrange $obj 1 6] "}
	return $params
}

proc CPMS_Manager_go {} {
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

proc CPMS_Manager_displace {} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info

	set params [CPMS_Manager_get_params]
	set obj_num 0
	set param_num 0
	foreach {x} $params {
		set new_x [expr $x + (rand()-0.5)*10.0*[lindex $config(scaling) $param_num]]
		set new_x [format %.3f $new_x]
		set obj_index [expr ($param_num % 6) + 1] 
		lset config(objects) $obj_num $obj_index $new_x
		incr param_num
		if {$param_num % 6 == 0} {incr obj_num}
	}
	CPMS_Manager_disagreement [CPMS_Manager_get_params]
	return [CPMS_Manager_get_params]
} 

proc CPMS_Manager_altitude {params} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info

	if {$config(stop_fit)} {error "Fit aborted by user"}
	if {![winfo exists $info(window)]} {error "Tool window destroyed"}
	set count [CPMS_Manager_disagreement "$params"]
	LWDAQ_support
	
	return $count
}

proc CPMS_Manager_fit {} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info

	set config(stop_fit) 0
	set info(state) "Fitting"
	LWDAQ_update
	
	if {[catch {
		set start_params [CPMS_Manager_get_params]
		set result [lwdaq_simplex $start_params CPMS_Manager_altitude \
			-report 0 \
			-steps $config(fit_steps) \
			-restarts $config(fit_restarts) \
			-start_size 1.0 \
			-end_size 0.01 \
			-scaling $config(scaling)]
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
		return ""
	}
	lwdaq_image_manipulate $iconfig(memory_name) copy -name cpms_img_left
	
	set iconfig(daq_driver_socket) $config(right_sensor_socket)
	set iconfig(daq_source_driver_socket) $config(right_source_socket)
	set result [LWDAQ_acquire SCAM]
	if {[LWDAQ_is_error_result $result]} {
		LWDAQ_print $info(text) $result
		return ""
	}
	lwdaq_image_manipulate $iconfig(memory_name) copy -name cpms_img_right
	
	CPMS_Manager_go

	set info(state) "Idle"
	LWDAQ_update
}

proc CPMS_Manager_open {} {
	upvar #0 CPMS_Manager_config config
	upvar #0 CPMS_Manager_info info

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
	
	set f [frame $w.controls]
	pack $f -side top -fill x
	
	label $f.state -textvariable CPMS_Manager_info(state) -fg blue
	pack $f.state -side left -expand yes

	foreach a {Acquire Fit Go Clear Displace} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post CPMS_Manager_$b"
		pack $f.$b -side left -expand yes
	}
	
	button $f.stop -text "Stop" -command {
		set CPMS_Manager_config(stop_fit) 1
	}
	pack $f.go $f.fit $f.stop -side left -expand yes
	
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

	set f [frame $w.parameters]
	pack $f -side top -fill x

	foreach a {cam_left cam_right} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable CPMS_Manager_config($a) -width 50
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	label $f.lnl -text "num_lines:"
	entry $f.enl -textvariable CPMS_Manager_config(num_lines) -width 5
	pack $f.lnl $f.enl -side left -expand yes
	
	foreach a {objects scaling} {
		set f [frame $w.$a]
		pack $f -side top -fill x
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable CPMS_Manager_config($a) -width 120
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
	LWDAQ_print $info(text) "$info(name) Version $info(version) \n"
	lwdaq_config -text_name $info(text) -fsd 3	
	
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

The compound object being viewed we describe with a list of objects. Here are
some example lists.

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


Kevan Hashemi hashemi@brandeis.edu
----------End Help----------

----------Begin Data----------

----------End Data----------