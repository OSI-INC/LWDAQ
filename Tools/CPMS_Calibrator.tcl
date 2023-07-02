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


proc CPMS_Calibrator_init {} {
	upvar #0 CPMS_Calibrator_info info
	upvar #0 CPMS_Calibrator_config config
	upvar #0 LWDAQ_config_BCAM iconfig
	upvar #0 LWDAQ_info_BCAM iinfo
	global LWDAQ_Info LWDAQ_Driver
	
	LWDAQ_tool_init "CPMS_Calibrator" "1.0"
	if {[winfo exists $info(window)]} {return ""}

	set config(object) "4.684 -8.436 447.944 0 0 0"
	set config(cam_left) "83.509 0.000 0.000 -201.372 0.000 2.000 23.748 0.000" 
	set config(cam_right) "-83.509 0.000 0.000 234.757 0.922 2.000 23.687 0.000" 
	set config(steps) "1000"
	set config(tangents) "2000"
	set config(fit_object) 1
	set config(fit_cam_left) 0
	set config(fit_cam_right) 0
	set config(stop_fit) 0
	
	set info(projector_window) "$info(window).cpms_projector"

	set iconfig(analysis_enable) 0
	set iconfig(daq_flash_seconds) 0.05
	set iconfig(analysis_threshold) "10 %"
	set iconfig(daq_ip_addr) "71.174.73.187"
	set iconfig(daq_source_device_element) "1"
	set iinfo(daq_source_device_type) "1"
	set iconfig(daq_driver_socket) "2"
	set iconfig(daq_source_driver_socket) "1"
		
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 

	LWDAQ_read_image_file "~/Active/OSI/CPMS/Data/230629/LC_1.gif" img_left
	LWDAQ_read_image_file "~/Active/OSI/CPMS/Data/230629/RC_1.gif" img_right

	return ""   
}

proc CPMS_Calibrator_get_params {} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	set params "$config(cam_left)\
		[expr -[lindex $config(cam_left) 0]]\
		[lrange $config(cam_right) 1 7] \
		$config(object)"
	return $params
}

proc CPMS_Calibrator_go {{params ""}} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info
	upvar #0 LWDAQ_config_BCAM iconfig
	upvar #0 LWDAQ_info_BCAM iinfo

	if {$params == ""} {set params [CPMS_Calibrator_get_params]}
	if {![winfo exists $info(window)]} {error}
	
	set LC "LC [lrange $params 0 7]"
	set RC "RC [expr -[lindex $params 0]] [lrange $params 9 15]"
	set location "[lrange $params 16 18]"
	set orientation [lwdaq xyz_rotate "1 0 0" \
		"[expr 0.001*[lindex $params 19]]\
		[expr 0.001*[lindex $params 20]]\
		[expr 0.001*[lindex $params 21]]"]

	lwdaq_image_manipulate img_left none -clear 1
	lwdaq_image_manipulate img_right none -clear 1
	
	set shaft "sphere $location $orientation 34.72"
	lwdaq_scam img_left project $LC $shaft $config(tangents)
	lwdaq_scam img_right project $RC $shaft $config(tangents)

	set left_count [lwdaq_scam img_left disagreement $iconfig(analysis_threshold)]
	set right_count [lwdaq_scam img_right disagreement $iconfig(analysis_threshold)]

	lwdaq_draw img_left left_photo -intensify $iconfig(intensify)
	lwdaq_draw img_right right_photo -intensify $iconfig(intensify)
	return "[expr $left_count + $right_count]"
}

proc CPMS_Calibrator_altitude {params} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	if {$config(stop_fit)} {error "Fit aborted by user"}
	if {![winfo exists $info(window)]} {error "Tool window destoryed"}
	
	set count [CPMS_Calibrator_go "$params"]
	LWDAQ_update
	
	return $count
}

proc CPMS_Calibrator_fit {} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	set config(stop_fit) 0
	set scaling ""
	if {$config(fit_cam_left)} {
		append scaling "0 0 0 1 0 0 1 0 "
	} else {
		append scaling "0 0 0 0 0 0 0 0 "
	}
	if {$config(fit_cam_left)} {
		append scaling "0 0 0 1 1 0 1 0 "
	} else {
		append scaling "0 0 0 0 0 0 0 0 "
	}
	if {$config(fit_object)} {
		append scaling "1 1 10 0 10 10"
	} else {
		append scaling "0 0 0 0 0 0"
	}
	if {$scaling == ""} {
		LWDAQ_print $info(text) "ERROR: No fit parameters selected."
		return ""
	}
 	set params [lwdaq_simplex [CPMS_Calibrator_get_params] \
 		CPMS_Calibrator_altitude \
		-report 0 -steps $config(steps) -restarts 0 \
		-start_size 1.0 -end_size 0.01 \
		-scaling $scaling]
	if {[LWDAQ_is_error_result $params]} {
		LWDAQ_print $info(text) "$params\."
		return ""
	} 
	
	LWDAQ_print $info(text) "$params" brown

	set config(cam_left) "[lrange $params 0 7]"
	set config(cam_right) "[expr -[lindex $params 0]] [lrange $params 9 15]"
	set config(object) "[lrange $params 16 21]"
	CPMS_Calibrator_go
}

proc CPMS_Calibrator_project {param value} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info
	
	set pi 3.141593
	switch $param {
		x {lset config(object) 0 $value}
		y {lset config(object) 1 $value}
		z {lset config(object) 2 $value}
		rx {lset config(object) 3 [format %.3f [expr 1000.0*$pi*$value/180]]}
		ry {lset config(object) 4 [format %.3f [expr 1000.0*$pi*$value/180]]}
		rz {lset config(object) 5 [format %.3f [expr 1000.0*$pi*$value/180]]}
		default {error "unrecognised parameter $param"}
	}
	set config(projector_$param) $value

	set location "[lrange $config(object)  0 2]"
	set rot "[expr 0.001*[lindex $config(object) 3]]\
		[expr 0.001*[lindex $config(object) 4]]\
		[expr 0.001*[lindex $config(object) 5]]"
	set orientation [lwdaq xyz_rotate "1 0 0" $rot]

	set type "other"
	set diameter "33"
	
	if {$type == "cylinder"} {
		set object [list "cylinder $location $orientation $diameter $length"]
	} elseif {$type == "sphere"} {
		set object [list "sphere $location $orientation $diameter"]
	} elseif {$type == "shaft"} {
		set object [list "shaft $location $orientation \
			0 -20 \
			20 -20 \
			30 10 \
			36 10 \
			40 12 \
			40 30 \
			60 30 \
			60 39 \
			58 40 \
			0 40"]
	} else {
		set object [list "cylinder $location $orientation 33.78 7.24"]
		lappend object "cylinder $location $orientation 19.00 -50.0" 
		set rodpos [lwdaq xyz_rotate "3.62 16.89 0" $rot]
		set rodpos [lwdaq xyz_sum $rodpos $location]
		set rodaxis [lwdaq xyz_rotate "0 1 0" $rot]
		lappend object "cylinder $rodpos $rodaxis 4 10"
	}
	
	set cam_left "LC $config(cam_left)"
	set cam_right "RC $config(cam_right)"
	lwdaq_image_manipulate proj_left none -fill 1
	lwdaq_image_manipulate proj_right none -fill 1
	foreach obj $object {
		lwdaq_scam proj_left project $cam_left $obj $config(tangents)		
		lwdaq_scam proj_right project $cam_right $obj $config(tangents)		
	}
	lwdaq_draw proj_left proj_photo_left -zoom 0.5
	lwdaq_draw proj_right proj_photo_right -zoom 0.5
}


proc CPMS_Calibrator_projector {} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	if {[winfo exists $info(projector_window)]} {
		raise $info(projector_window)
		return ""
	}	
	
	set w $info(projector_window)
	toplevel $w
	wm title $w "CPMS Projector, Version $info(version)"

	set f [frame $w.img]
	pack $f -side top -fill x
	foreach a {left right} {
		image create photo "proj_photo_$a"
		label $f.$a -image proj_photo_$a
		pack $f.$a -side left 
		lwdaq_image_create -name proj_$a -width 700 -height 520
		lwdaq_image_manipulate proj_$a none -fill 1
	}
	
	foreach a {x y rx ry rz} {set config(projector_$a) 0}
	set config(projector_z) 500
	
	foreach a {x y} {
		set f [frame $w.$a]
		pack $f -side top -fill x
		label $f.l$a -text "$a\:"
		set $a 0
		scale $f.$a -from -100 -to +100 -length 700 \
			-variable CPMS_Calibrator_config(projector_$a) \
			-orient horizontal -showvalue false -tickinterval 10 \
			-command "CPMS_Calibrator_project $a"
		pack $f.l$a $f.$a -side left -expand yes
	}
	foreach a {z} {
		set f [frame $w.$a]
		pack $f -side top -fill x
		label $f.l$a -text "$a\:"
		set $a 500
		scale $f.$a -from 0 -to 1000 -length 700 \
			-variable CPMS_Calibrator_config(projector_$a) \
			-orient horizontal -showvalue false -tickinterval 100 \
			-command "CPMS_Calibrator_project $a"
		pack $f.l$a $f.$a -side left -expand yes
	}
	foreach a {rx ry rz} {
		set f [frame $w.$a]
		pack $f -side top -fill x
		label $f.l$a -text "$a\:"
		set $a 0
		scale $f.$a -from -180 -to +180 -length 700 \
			-variable CPMS_Calibrator_config(projector_$a) \
			-orient horizontal -showvalue false -tickinterval 45 \
			-command "CPMS_Calibrator_project $a"
		pack $f.l$a $f.$a -side left -expand yes
	}

	CPMS_Calibrator_project z 500
}


proc CPMS_Calibrator_open {} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
	
	set ff [frame $w.controls]
	pack $ff -side top -fill x

	button $ff.clear -text "Clear" -command {
		lwdaq_image_manipulate img_left none -clear 1
		lwdaq_image_manipulate img_right none -clear 1	
		lwdaq_draw img_left left_photo \
			-intensify $LWDAQ_config_BCAM(intensify) -zoom 1.0
		lwdaq_draw img_right right_photo \
			-intensify $LWDAQ_config_BCAM(intensify) -zoom 1.0
	}
	pack $ff.clear -side left -expand yes
	
	button $ff.go -text "Go" -command {
		set count [CPMS_Calibrator_go]
		LWDAQ_print $CPMS_Calibrator_info(text) \
			"$CPMS_Calibrator_config(object) [format %.0f $count]"
	}
	button $ff.fit -text "Fit" -command {CPMS_Calibrator_fit}
	button $ff.stop -text "Stop" -command {set CPMS_Calibrator_config(stop_fit) 1}
	pack $ff.go $ff.fit $ff.stop -side left -expand yes
	
	foreach a {steps tangents} {
		label $ff.l$a -text "$a\:"
		entry $ff.e$a -textvariable CPMS_Calibrator_config($a) -width 6
		pack $ff.l$a $ff.e$a -side left -expand yes
	}

	label $ff.lth -text "threshold:"
	entry $ff.eth -textvariable LWDAQ_config_BCAM(analysis_threshold) -width 6
	pack $ff.lth $ff.eth -side left -expand yes
	
	button $ff.projector -text "Projector" -command {CPMS_Calibrator_projector}
	pack $ff.projector -side left -expand yes 

	foreach a {Help Configure} {
		set b [string tolower $a]
		button $ff.$b -text $a -command "LWDAQ_tool_$b $info(name)"
		pack $ff.$b -side left -expand 1
	}

	set ff [frame $w.parameters]
	pack $ff -side top -fill x

	foreach a {cam_left cam_right object} {
		label $ff.l$a -text "$a\:"
		entry $ff.e$a -textvariable CPMS_Calibrator_config($a) -width 40
		checkbutton $ff.c$a -variable CPMS_Calibrator_config(fit_$a)
		pack $ff.l$a $ff.e$a $ff.c$a -side left -expand yes
	}
		
	set ff [frame $w.images]
	pack $ff -side top -fill x

	image create photo "left_photo"
	label $ff.left -image "left_photo"
	pack $ff.left -side left
		
	image create photo "right_photo"
	label $ff.right -image "right_photo"
	pack $ff.right -side right

	set info(text) [LWDAQ_text_widget $w 100 15]
	LWDAQ_print $info(text) "$info(name) Version $info(version) \n"
	lwdaq_config -text_name $info(text) -fsd 3	
	
	return $w
}

CPMS_Calibrator_init
CPMS_Calibrator_open
	
return ""

----------Begin Help----------

The Contactless Position Measurement System (CPMS) Calibrator takes a series of 
silhouette images of the same sphere moving in a straight line in uniform steps
to calibrate a pair of stereo Silhouette Cameras (SCAMs). 

Kevan Hashemi hashemi@brandeis.edu
----------End Help----------

----------Begin Data----------

----------End Data----------