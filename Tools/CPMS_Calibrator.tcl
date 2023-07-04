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
	
	LWDAQ_tool_init "CPMS_Calibrator" "1.0"
	if {[winfo exists $info(window)]} {return ""}

	set config(pose) "4.684 -8.436 447.944 0 0 0"
	set config(cam_left) "83.509 0.000 0.000 -201.372 0.000 2.000 23.748 0.000" 
	set config(cam_right) "-83.509 0.000 0.000 234.757 0.922 2.000 23.687 0.000" 
	set config(object) [list "sphere 0 0 0 0 0 0 34.72"]
	set config(displacements) "0 -40 -70 -100"
	set config(scaling) "1 1 10 10 10 0"

	set config(fit_steps) "1000"
	set config(fit_restarts) "0"
	set config(num_lines) "2000"
	set config(fit_cam_left) 0
	set config(fit_cam_right) 0
	set config(stop_fit) 0
	set config(zoom) 0.5
	set config(intensify) "exact"
	set config(project_silhouette) "1"
	set config(project_fill) "0"
	set config(threshold) "8 %"
	set config(img_dir) "~/Desktop"
	
	set info(projector_window) "$info(window).cpms_projector"

	set info(state) "Idle"
	set iconfig(analysis_enable) 0
	set iconfig(daq_flash_seconds) 0.05
	set iconfig(daq_ip_addr) "71.174.73.187"
	set iconfig(daq_source_device_element) "1"
	set iinfo(daq_source_device_type) "1"
	set iconfig(daq_driver_socket) "2"
	set iconfig(daq_source_driver_socket) "1"
		
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 

	foreach a {1 2 3 4} {
		lwdaq_image_create -name img_left_$a -width 700 -height 520
		lwdaq_image_create -name img_right_$a -width 700 -height 520
	}
	CPMS_Calibrator_read_files $config(img_dir)

	return ""   
}

proc CPMS_Calibrator_read_files {{img_dir ""}} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	if {$info(state) != "Idle"} {return ""}
	set info(state) "Reading"
	LWDAQ_update
	if {$img_dir == ""} {set img_dir [LWDAQ_get_dir_name]}
	if {$img_dir == ""} {return ""} {set config(img_dir) $img_dir}
	foreach a {1 2 3 4} {
		set lf [file join $config(img_dir) L$a\.gif]
		if {[file exists $lf]} {LWDAQ_read_image_file $lf img_left_$a}
		set rf [file join $config(img_dir) R$a\.gif]
		if {[file exists $rf]} {LWDAQ_read_image_file $rf img_right_$a}
	}
	set info(state) "Idle"
	LWDAQ_post CPMS_Calibrator_go
}

proc CPMS_Calibrator_get_params {} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	set params "$config(cam_left)\
		[expr -[lindex $config(cam_left) 0]]\
		[lrange $config(cam_right) 1 7] \
		$config(pose)"
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
	set rotation "[expr 0.001*[lindex $params 19]]\
		[expr 0.001*[lindex $params 20]]\
		[expr 0.001*[lindex $params 21]]"
	
	set disagreement 0
	foreach a {1 2 3 4} {
		lwdaq_image_manipulate img_left_$a none -clear 1
		lwdaq_image_manipulate img_right_$a none -clear 1
		set displacement [lindex $config(displacements) [expr $a-1]]
	
		foreach obj $config(object) {
			set objloc [lwdaq xyz_sum [lrange $obj 1 3] "0 0 $displacement"]
			set objloc [lwdaq xyz_rotate $objloc $rotation]
			set objloc [lwdaq xyz_sum $objloc $location]
			set objrot [lwdaq xyz_rotate [lrange $obj 4 6] $rotation]
			lwdaq_scam img_left_$a project $LC \
				"[lindex $obj 0] $objloc $objrot [lrange $obj 7 end]" $config(num_lines)		
			lwdaq_scam img_right_$a project $RC \
				"[lindex $obj 0] $objloc $objrot [lrange $obj 7 end]" $config(num_lines)		
		}

		set left_count [lwdaq_scam img_left_$a disagreement $config(threshold)]
		set right_count [lwdaq_scam img_right_$a disagreement $config(threshold)]
		set disagreement [expr $disagreement + $left_count + $right_count]

		lwdaq_draw img_left_$a photo_left_$a \
			-intensify $config(intensify) -zoom $config(zoom)
		lwdaq_draw img_right_$a photo_right_$a \
			-intensify $config(intensify) -zoom $config(zoom)
	}
	
	return $disagreement
}

proc CPMS_Calibrator_altitude {params} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	if {$config(stop_fit)} {
		error "Fit aborted by user"
	}
	if {![winfo exists $info(window)]} {error "Tool window destoryed"}
	
	set count [CPMS_Calibrator_go "$params"]
	LWDAQ_update
	
	return $count
}

proc CPMS_Calibrator_fit {} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	set config(stop_fit) 0
	set info(state) "Fitting"
	
	set scaling ""
	if {$config(fit_cam_left)} {
		append scaling "1 0 0 1 0 0 1 10 "
	} else {
		append scaling "0 0 0 0 0 0 0 0 "
	}
	if {$config(fit_cam_left)} {
		append scaling "0 0 0 1 1 0 1 10 "
	} else {
		append scaling "0 0 0 0 0 0 0 0 "
	}
	append scaling $config(scaling)
	
	if {$scaling == ""} {
		LWDAQ_print $info(text) "ERROR: No fit parameters selected."
		return ""
	}
 	set params [lwdaq_simplex [CPMS_Calibrator_get_params] \
 		CPMS_Calibrator_altitude \
		-report 0 -steps $config(fit_steps) -restarts $config(fit_restarts) \
		-start_size 1.0 -end_size 0.01 \
		-scaling $scaling]
	set info(state) "Idle"

	if {[LWDAQ_is_error_result $params]} {
		LWDAQ_print $info(text) "$params\."
		return ""
	} 

	for {set i 0} {$i < [llength $params]} {incr i} {
		if {[lindex $scaling $i] > 0} {
			LWDAQ_print -nonewline $info(text) "[lindex $params $i] " brown
		}
	}
	LWDAQ_print $info(text) "[lrange $params end-1 end]" black

	set config(cam_left) "[lrange $params 0 7]"
	set config(cam_right) "[expr -[lindex $params 0]] [lrange $params 9 15]"
	set config(pose) "[lrange $params 16 21]"
	CPMS_Calibrator_go
}

proc CPMS_Calibrator_project {param value} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info
	upvar #0 LWDAQ_config_BCAM iconfig
	
	set pi 3.141593
	switch $param {
		x {lset config(pose) 0 $value}
		y {lset config(pose) 1 $value}
		z {lset config(pose) 2 $value}
		rx {lset config(pose) 3 [format %.3f [expr 1000.0*$pi*$value/180]]}
		ry {lset config(pose) 4 [format %.3f [expr 1000.0*$pi*$value/180]]}
		rz {lset config(pose) 5 [format %.3f [expr 1000.0*$pi*$value/180]]}
	}

	set location "[lrange $config(pose) 0 2]"
	set rotation "[expr 0.001*[lindex $config(pose) 3]]\
		[expr 0.001*[lindex $config(pose) 4]]\
		[expr 0.001*[lindex $config(pose) 5]]"

	set cam_left "LC $config(cam_left)"
	set cam_right "RC $config(cam_right)"
	
	foreach a {1 2 3 4} {
		if {$config(project_fill)} {
			lwdaq_image_manipulate img_left_$a none -fill 1
			lwdaq_image_manipulate img_right_$a none -fill 1
		} else {
			lwdaq_image_manipulate img_left_$a none -clear 1
			lwdaq_image_manipulate img_right_$a none -clear 1
		}
		
		set displacement [lindex $config(displacements) [expr $a-1]]

		foreach obj $config(object) {
			set objloc [lwdaq xyz_sum [lrange $obj 1 3] "0 0 $displacement"]
			set objloc [lwdaq xyz_rotate $objloc $rotation]
			set objloc [lwdaq xyz_sum $objloc $location]
			set objrot [lwdaq xyz_rotate [lrange $obj 4 6] $rotation]
			lwdaq_scam img_left_$a project $cam_left \
				"[lindex $obj 0] $objloc $objrot [lrange $obj 7 end]" $config(num_lines)		
			lwdaq_scam img_right_$a project $cam_right \
				"[lindex $obj 0] $objloc $objrot [lrange $obj 7 end]" $config(num_lines)		
		}
				
		if {$config(project_silhouette)} {
			lwdaq_scam img_left_$a disagreement $config(threshold)
			lwdaq_scam img_right_$a disagreement $config(threshold)
		}
		lwdaq_draw img_left_$a photo_left_$a \
			-intensify $config(intensify) -zoom $config(zoom)
		lwdaq_draw img_right_$a photo_right_$a \
			-intensify $config(intensify) -zoom $config(zoom)
	}
}

proc CPMS_Calibrator_projector {} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	if {[winfo exists $info(projector_window)]} {
		raise $info(projector_window)
		CPMS_Calibrator_project none 0
		return ""
	}	
	
	set w $info(projector_window)
	toplevel $w
	wm title $w "Object Projector for CPMS Calibrator Version $info(version)"

	set f [frame $w.controls]
	pack $f -side top -fill x
	
	checkbutton $f.cms -text "Silhouette" \
		-variable CPMS_Calibrator_config(project_silhouette)
	checkbutton $f.fill -text "Fill" \
		-variable CPMS_Calibrator_config(project_fill)
	pack $f.cms $f.fill -side left -expand yes
	foreach a {num_lines threshold} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable CPMS_Calibrator_config($a) -width 6
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	set info(projector_x) [lindex $config(pose) 0]
	set info(projector_y) [lindex $config(pose) 1]
	set info(projector_z) [lindex $config(pose) 2]
	set pi 3.141593
	set info(projector_rx) [format %.3f [expr 0.180*[lindex $config(pose) 3]/$pi]]
	set info(projector_ry) [format %.3f [expr 0.180*[lindex $config(pose) 4]/$pi]]
	set info(projector_rz) [format %.3f [expr 0.180*[lindex $config(pose) 5]/$pi]]

	foreach a {x y} {
		set f [frame $w.$a -border 2 -relief sunken]
		pack $f -side top -fill x
		label $f.l$a -text "$a\:"
		scale $f.$a -from -50 -to +50 -length 1000 -resolution 0.1 \
			-variable CPMS_Calibrator_info(projector_$a) \
			-orient horizontal -showvalue false -tickinterval 5 \
			-command "CPMS_Calibrator_project $a"
		pack $f.l$a $f.$a -side left -expand yes
	}
	foreach a {z} {
		set f [frame $w.$a -border 2 -relief sunken]
		pack $f -side top -fill x
		label $f.l$a -text "$a\:"
		scale $f.$a -from 0 -to 1000 -length 1000 -resolution 1.0 \
			-variable CPMS_Calibrator_info(projector_$a) \
			-orient horizontal -showvalue false -tickinterval 50 \
			-command "CPMS_Calibrator_project $a"
		pack $f.l$a $f.$a -side left -expand yes
	}
	foreach a {rx ry rz} {
		set f [frame $w.$a -border 2 -relief sunken]
		pack $f -side top -fill x
		label $f.l$a -text "$a\:"
		scale $f.$a -from -180 -to +180 -length 1000 -resolution 1 \
			-variable CPMS_Calibrator_info(projector_$a) \
			-orient horizontal -showvalue false -tickinterval 20 \
			-command "CPMS_Calibrator_project $a"
		pack $f.l$a $f.$a -side left -expand yes
	}

	CPMS_Calibrator_project none 0
}

proc CPMS_Calibrator_open {} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
	
	set f [frame $w.controls]
	pack $f -side top -fill x
	
	label $f.state -textvariable CPMS_Calibrator_info(state) -fg blue
	pack $f.state -side left -expand yes

	button $f.clear -text "Clear" -command {
		lwdaq_image_manipulate img_left none -clear 1
		lwdaq_image_manipulate img_right none -clear 1	
		lwdaq_draw img_left photo_left \
			-intensify $CPMS_Calibrator_config(intensify) -zoom 1.0
		lwdaq_draw img_right photo_right \
			-intensify $CPMS_Calibrator_config(intensify) -zoom 1.0
	}
	pack $f.clear -side left -expand yes
	
	button $f.go -text "Go" -command {
		set count [CPMS_Calibrator_go]
		LWDAQ_print $CPMS_Calibrator_info(text) \
			"$CPMS_Calibrator_config(pose) [format %.0f $count]"
	}
	button $f.fit -text "Fit" -command {CPMS_Calibrator_fit}
	button $f.stop -text "Stop" -command {set CPMS_Calibrator_config(stop_fit) 1}
	pack $f.go $f.fit $f.stop -side left -expand yes
	
	foreach a {threshold} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable CPMS_Calibrator_config($a) -width 6
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	button $f.projector -text "Projector" -command {CPMS_Calibrator_projector}
	pack $f.projector -side left -expand yes 

	foreach a {Help Configure} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_tool_$b $info(name)"
		pack $f.$b -side left -expand 1
	}

	set f [frame $w.parameters]
	pack $f -side top -fill x

	foreach a {cam_left cam_right} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable CPMS_Calibrator_config($a) -width 50
		checkbutton $f.c$a -text "fit_$a" -variable CPMS_Calibrator_config(fit_$a)
		pack $f.l$a $f.e$a $f.c$a -side left -expand yes
	}
	
	set f [frame $w.pose]
	pack $f -side top -fill x
	
	foreach a {pose} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable CPMS_Calibrator_config($a) -width 40
		pack $f.l$a $f.e$a -side left -expand yes
	}
	foreach a {scaling displacements} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable CPMS_Calibrator_config($a) -width 15
		pack $f.l$a $f.e$a -side left -expand yes
	}
	button $f.rdf -text "ReadFiles" -command {CPMS_Calibrator_read_files}
	pack $f.rdf -side left -expand yes

	set f [frame $w.object]
	pack $f -side top -fill x

	label $f.lobj -text "object:"
	entry $f.eobj -textvariable CPMS_Calibrator_config(object) -width 130
	pack $f.lobj $f.eobj -side left -expand yes
		
	set f [frame $w.images_a]
	pack $f -side top -fill x

	foreach a {1 2} {
		image create photo "photo_left_$a"
		label $f.left_$a -image "photo_left_$a"
		pack $f.left_$a -side left -expand yes
		image create photo "photo_right_$a"
		label $f.right_$a -image "photo_right_$a"
		pack $f.right_$a -side left -expand yes
	}
		
	set f [frame $w.images_b]
	pack $f -side top -fill x

	foreach a {3 4} {
		image create photo "photo_left_$a"
		label $f.left_$a -image "photo_left_$a"
		pack $f.left_$a -side left -expand yes
		image create photo "photo_right_$a"
		label $f.right_$a -image "photo_right_$a"
		pack $f.right_$a -side left -expand yes
	}
		
	set info(text) [LWDAQ_text_widget $w 100 15]
	LWDAQ_print $info(text) "$info(name) Version $info(version) \n"
	lwdaq_config -text_name $info(text) -fsd 3	
	
	return $w
}

CPMS_Calibrator_init
CPMS_Calibrator_open
CPMS_Calibrator_go
	
return ""

----------Begin Help----------

The Contactless Position Measurement System (CPMS) Calibrator takes a series of
silhouette images of the same object moving in a straight line to calibrate a
pair of stereo Silhouette Cameras (SCAMs). The origin and direction of the locus
of the calibration object is the "pose", given as x, y, z, rot_x, rot_y, rot_z
in mm and mrad. The "scaling" is the size of the fitter simplex in each of the
pose coordinates. The four positions of the object are given by four distances
along the direction of the locus, in the "displacements" box. 


Sphere:
{sphere 0 0 0 0 0 0 34.72}

Cylinder:
{cylinder 0 0 0 1 0 0 20 30}

Shaft:
{shaft 0 0 0 1 0 0 0 -20 20 -20 30 10 36 10 40 12 40 30 60 30 60 39 58 40 0 40}
			
Compound:
{cylinder 0 0 0 1 0 0 33.78 7.24} {cylinder 0 0 0 1 0 0 19.00 -20.0} {cylinder 3.62 16.89 0 0 1 0 4 10}


Kevan Hashemi hashemi@brandeis.edu
----------End Help----------

----------Begin Data----------

----------End Data----------