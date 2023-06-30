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

	set config(object) "16.573 1.529 441.217 -13.047 1.461"
	set config(left_cam) "83.5 0 0 -212.052 0.0 2 26.647 0" 
	set config(right_cam) "-83.5 0 0 211.333 0.406 2 25.787 0" 
	set config(steps) "1000"
	set config(tangents) "2000"
	set config(fit_object) 1
	set config(fit_left_cam) 0
	set config(fit_right_cam) 0
	set config(stop_fit) 0

	set iconfig(analysis_enable) 0
	set iconfig(daq_flash_seconds) 0.05
	set iconfig(analysis_threshold) "15 %"
	set iconfig(daq_ip_addr) "71.174.73.187"
	set iconfig(daq_source_device_element) "1"
	set iinfo(daq_source_device_type) "1"
	set iconfig(daq_driver_socket) "2"
	set iconfig(daq_source_driver_socket) "1"
		
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 

	LWDAQ_read_image_file "~/Active/OSI/CPMS/Data/230627/LC_100ms.gif" left_img
	LWDAQ_read_image_file "~/Active/OSI/CPMS/Data/230627/RC_100ms.gif" right_img

	return ""   
}

proc CPMS_Calibrator_get_params {} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	set params "$config(left_cam)\
		[expr -[lindex $config(left_cam) 0]]\
		[lrange $config(right_cam) 1 7] \
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
	set center "[lrange $params 16 18]"
	set axis [lwdaq xyz_rotate "1 0 0" \
		"0 [expr 0.001*[lindex $params 19]] [expr 0.001*[lindex $params 20]]"]

	lwdaq_image_manipulate left_img none -clear 1
	lwdaq_image_manipulate right_img none -clear 1
	
	set shaft "shaft $center $axis \
		16.89 0.0 \
		16.89 7.24  \
		9.50 7.24 \
		9.50 28.59 \
		29.36 28.59 \
		29.36 100.0"
	lwdaq_scam left_img project $LC $shaft $config(tangents)
	lwdaq_scam right_img project $RC $shaft $config(tangents)

	set left_count [lwdaq_scam left_img disagreement $iconfig(analysis_threshold)]
	set right_count [lwdaq_scam right_img disagreement $iconfig(analysis_threshold)]

	lwdaq_draw left_img left_photo -intensify $iconfig(intensify)
	lwdaq_draw right_img right_photo -intensify $iconfig(intensify)
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
	if {$config(fit_left_cam)} {
		append scaling "0 0 0 1 0 0 1 0 "
	} else {
		append scaling "0 0 0 0 0 0 0 0 "
	}
	if {$config(fit_left_cam)} {
		append scaling "0 0 0 1 1 0 1 0 "
	} else {
		append scaling "0 0 0 0 0 0 0 0 "
	}
	if {$config(fit_object)} {
		append scaling "1 1 10 10 10 "
	} else {
		append scaling "0 0 0 0 0 "
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

	set config(left_cam) "[lrange $params 0 7]"
	set config(right_cam) "[expr -[lindex $params 0]] [lrange $params 9 15]"
	set config(object) "[lrange $params 16 20]"
	CPMS_Calibrator_go
}


proc CPMS_Calibrator_open {} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
	
	set ff [frame $w.controls]
	pack $ff -side top -fill x

	button $ff.clear -text "Clear" -command {
		lwdaq_image_manipulate left_img none -clear 1
		lwdaq_image_manipulate right_img none -clear 1	
		lwdaq_draw left_img left_photo \
			-intensify $LWDAQ_config_BCAM(intensify) -zoom 1.0
		lwdaq_draw right_img right_photo \
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

	foreach a {Help Configure} {
		set b [string tolower $a]
		button $ff.$b -text $a -command "LWDAQ_tool_$b $info(name)"
		pack $ff.$b -side left -expand 1
	}

	set ff [frame $w.parameters]
	pack $ff -side top -fill x

	foreach a {left_cam right_cam object} {
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