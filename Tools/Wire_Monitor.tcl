# Wire_Monitor, a LWDAQ Tool
#
# Copyright (C) 2019 Kevan Hashemi, Open Source Instruments Inc.
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

proc Wire_Monitor_init {} {
	upvar #0 Wire_Monitor_info info
	upvar #0 Wire_Monitor_config config
	global LWDAQ_Info LWDAQ_Driver
	
	LWDAQ_tool_init "Wire_Monitor" "1.5"
	if {[winfo exists $info(window)]} {return ""}

	set config(wps_list) "1"	
	set config(wps1_id) "Q0216"
	set config(wps1_version) "WPS2B"
	set config(wps1_addr) "10.0.0.37"
	set config(wps1_sock) "8"
	set config(wps1_x) "-1"
	set config(wps1_y) "-1"
	set config(ref_z) "-5"
	set config(wps_calib_addr) "http://www.bndhep.net/Devices/Calibration/WPS_Calibrations.txt"
	
	set config(version_list) [list \
		"WPS1B 0 2 0.05 TC255 None" "WPS2A 1 1 0.02 TC255 A3022" \
		"WPS2B 1 1 0.02 TC255 A3022" "WPS2C 1 1 0.02 TC255 A3022"]

	set info(calibration) [split [string trim [LWDAQ_tool_data $info(name)] ] \n]

	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 

	return ""   
}

proc Wire_Monitor_acquire {} {
	upvar #0 Wire_Monitor_config config
	upvar #0 Wire_Monitor_info info
	upvar #0 LWDAQ_config_WPS iconfig
	upvar #0 LWDAQ_info_WPS iinfo
	upvar #0 LWDAQ_config_Thermometer tconfig
	upvar #0 LWDAQ_info_Thermometer tinfo
	
	set acquire_result ""
		
	foreach n $config(wps_list) {
		# Configure WPS and Thermometer for this sensor.
		set name $config(wps$n\_id)
		set iconfig(daq_ip_addr) $config(wps$n\_addr)
		set iconfig(daq_driver_socket) $config(wps$n\_sock) 
		set tconfig(daq_ip_addr) $config(wps$n\_addr)
		set tconfig(daq_driver_socket) $config(wps$n\_sock) 
		set tconfig(daq_device_element) "1"
		set index [lsearch -index 0 $config(version_list) $config(wps$n\_version)]
		if {$index >= 0} {
			set version [lindex $config(version_list) $index]
			set iconfig(daq_simultaneous) [lindex $version 1]
			set iconfig(daq_source_device_element) [lindex $version 2]
			set iconfig(daq_flash_seconds) [lindex $version 3]
			set tconfig(daq_device_name) [lindex $version 5]
		} else {
			LWDAQ_print $info(text) "WARNING: Do not recognise version \"$config(wps$n\_version)\""
		}

		# Acquire images and get wire edges.
		set result [LWDAQ_acquire WPS]
		
		# Check to make sure that all four wire edges visible.
		if {![LWDAQ_is_error_result $result]} {
			foreach i {1 3 5 7} {
				if {[lindex $result $i] == -1} {
					set result "ERROR: At least one edge is out of bounds."
				}
			}
		}
	
		if {![LWDAQ_is_error_result $result]} {
			# Extract the reference height on the image from the instrument
			# parameters analysis_reference_um, which is in the WPS instrument's
			# info array.
			set ref_y [format %.6f [expr 1.0 * $iinfo(analysis_reference_um) / 1000]]
	
			# Start with the top camera. Calculate the wire image center and rotation,
			# extract calibration constants, and obtain the plane containing the center
			# of the wire.
			set x [format %6.5f [expr ([lindex $result 1] + [lindex $result 3]) / 2000]]
			set rot [format %6.5f [expr ([lindex $result 2] + [lindex $result 4]) / 2]]
			set constants [lindex $info(calibration) [lsearch $info(calibration) "$name\_1 *"]]
			if {$constants == ""} {
				LWDAQ_print $info(text) "ERROR: Could not find $name\_1 calibration."
				return "$name"
			}
			set plane_1 [lwdaq wps_wire_plane "$x $ref_y" $rot $constants]
	
			# Do the same for the bottom camera.
			set x [format %6.5f [expr ([lindex $result 5] + [lindex $result 7]) / 2000]]
			set rot [format %6.5f [expr ([lindex $result 6] + [lindex $result 8]) / 2]]
			set constants [lindex $info(calibration) [lsearch $info(calibration) "$name\_2 *"]]
			if {$constants == ""} {
				LWDAQ_print $info(text) "ERROR: Could not find $name\_1 calibration."
				return "$name"
			}
			set plane_2 [lwdaq wps_wire_plane "$x $ref_y" $rot $constants]
	
			# Obtain the center-line of the wire in mount coordinates.
			set wire [lwdaq xyz_plane_plane_intersection $plane_1 $plane_2]
			set point [lwdaq xyz_line_plane_intersection $wire "0 0 $config(ref_z) 0 0 1"]
			
			# We set the sensor and the x and y coordinates of the wire.
			set config(wps$n\_x) [format %.4f [lindex $point 0]]
			set config(wps$n\_y) [format %.4f [lindex $point 1]]
		} {
			# We assign error values.
			set config(wps$n\_x) "-1"
			set config(wps$n\_y) "-1"
		}
		
		# Acquire the temperature.
		if {$tconfig(daq_device_name) != "None"} {
			set result [LWDAQ_acquire Thermometer]
			if {![LWDAQ_is_error_result $result]} {
				set temperature [format %.2f [lindex $result 1]]
			} {
				set temperature "-1"
			}
		} {
			set temperature "-1"
		}
		
		# Append the resulting positions to a string.
		append acquire_result "$name $config(wps$n\_x) $config(wps$n\_y) $temperature "
	}
	
	LWDAQ_print $info(text) "[clock seconds] $acquire_result"
	return ""
}


proc Wire_Monitor_undraw_list {} {
	upvar #0 Wire_Monitor_config config
	upvar #0 Wire_Monitor_info info

	foreach n $config(wps_list) {
		set ff $info(window).wps_list.wps$n
		catch {destroy $ff}
	}
	
	return ""
}

proc Wire_Monitor_draw_list {} {
	upvar #0 Wire_Monitor_config config
	upvar #0 Wire_Monitor_info info

	set f $info(window).wps_list
	if {![winfo exists $f]} {
		frame $f
		pack $f -side top -fill x
	}
	
	foreach n $config(wps_list) {
		set ff $f.wps$n
		frame $ff
		pack $ff -side top -fill x
		foreach a {ID Version Addr Sock X Y} {
			set b [string tolower $a]
			label $ff.$b\_name -text $a -fg brown
			entry $ff.$b\_value -textvariable Wire_Monitor_config(wps$n\_$b) -width 10
			pack $ff.$b\_name $ff.$b\_value -side left -expand 1
		}
		button $ff.delete -text "Remove" -command "Wire_Monitor_remove $n"
		pack $ff.delete -side left -expand yes
	}
	return ""
}

proc Wire_Monitor_remove {n} {
	upvar #0 Wire_Monitor_config config
	upvar #0 Wire_Monitor_info info

	set index [lsearch $config(wps_list) $n]
	if {$index >= 0} {
		Wire_Monitor_undraw_list
		set config(wps_list) [lreplace $config(wps_list) $index $index]
		unset config(wps$n\_id) 
		unset config(wps$n\_version)
		unset config(wps$n\_addr)
		unset config(wps$n\_sock)
		unset config(wps$n\_x)
		unset config(wps$n\_y)
		Wire_Monitor_draw_list
	}
	return ""
}

proc Wire_Monitor_add {} {
	upvar #0 Wire_Monitor_config config
	upvar #0 Wire_Monitor_info info

	# Delete the list display.
	Wire_Monitor_undraw_list
	
	# Find a new index for this sensor, add the new id to the list.
	set n 1
	while {[lsearch $config(wps_list) $n] >= 0} {
		incr n
	}
	
	# Add the new sensor index to the list.
	lappend config(wps_list) $n
	
	# Configure the new sensor to default values.
	set config(wps$n\_id) "Q0216"
	set config(wps$n\_version) "WPS2B"
	set config(wps$n\_addr) "10.0.0.37"
	set config(wps$n\_sock) "8"
	set config(wps$n\_x) "-1"
	set config(wps$n\_y) "-1"

	# Re-draw the sensor list.
	Wire_Monitor_draw_list
	return ""
}

proc Wire_Monitor_save {} {
	upvar #0 Wire_Monitor_config config
	upvar #0 Wire_Monitor_info info

	set fn [LWDAQ_put_file_name]
	if {$fn == ""} {return}
	
	set f [open $fn w]
	foreach n $config(wps_list) {
		foreach a {id version addr sock} {
			puts $f $config(wps[set n]_[set a])
		}
	}
	close $f

	return $fn
}

proc Wire_Monitor_load {} {
	upvar #0 Wire_Monitor_config config
	upvar #0 Wire_Monitor_info info

	set fn [LWDAQ_get_file_name]
	if {$fn == ""} {return}
	
	Wire_Monitor_undraw_list
	foreach n $config(wps_list) {
		Wire_Monitor_remove $n
	}
	set f [open $fn r]
	set data [split [string trim [read $f]] \n]
	close $f
	set n 0
	foreach {id version addr sock} $data {
		incr n
		lappend config(wps_list) $n
		set config(wps$n\_id) $id
		set config(wps$n\_version) $version
		set config(wps$n\_addr) $addr
		set config(wps$n\_sock) $sock
	}
	Wire_Monitor_draw_list
	return $fn
}

proc Wire_Monitor_download {} {
	upvar #0 Wire_Monitor_config config
	upvar #0 Wire_Monitor_info info

	set data [LWDAQ_url_download $config(wps_calib_addr)]
	if {[regexp {not found} $data] || [regexp -nocase {Failure} $data]} {
		LWDAQ_print $info(text) "ERROR: Failed to load \"$config(wps_calib_addr)\"."
		LWDAQ_print $info(text) "SUGGESTION: Copy and paste this URL into a browser and see what happens."
		return $data
	} 
	LWDAQ_tool_rewrite_data $info(name) $data
	set info(calibration) [split [string trim [LWDAQ_tool_data $info(name)] ] \n]
	LWDAQ_print $info(text) "Downloaded [expr [llength $info(calibration)]/2] calbrations,\
		saved to disk, and reloaded into memory."
	return ""
}

proc Wire_Monitor_edit {{command "New"}} {
	upvar #0 Wire_Monitor_config config
	upvar #0 Wire_Monitor_info info

	set w $info(window).edit

	if {$command == "New"} {
		if {[winfo exists $w]} {
			raise $w
			return $w
		}
		toplevel $w
		wm title $w "Wire Monitor $info(version) Calibration Editor"
		set f [frame $w.bf]
		pack $f -side top -fill x
		button $f.save -text "Save and Reload" -command [list Wire_Monitor_edit "Apply"]
		pack $f.save -side left -expand 2
		button $f.cancel -text "Cancel" -command [list destroy $w]
		pack $f.cancel -side left -expand 2
		set t [LWDAQ_text_widget $w 130 30 1 1]
		LWDAQ_enable_text_undo $t
		foreach c $info(calibration) {
			$w.text insert end "$c\n"
		}
		return $w
	}

	if {$command == "Apply"} {
		raise $info(window)
		set data [string trim [$w.text get 1.0 end]]
		foreach c [split $data \n] {
			set name [lindex $c 0]
			if {![regexp {^([A-Z][0-9]{4}_[1-2])} $name match]} {
				LWDAQ_print $info(text) "ERROR: Invalid camera name \"$name\",\
					save and reload aborted."
				return ""
			}
			foreach x [lrange $c 1 11] {
				if {![string is double -strict $x]} {
					LWDAQ_print $info(text) "ERROR: Invalid calibration parameter \"$x\"\
						for camera $name,\
						save and reload aborted."
					return ""
				}
			}
		}
		LWDAQ_tool_rewrite_data $info(name) $data
		set info(calibration) [split [string trim [LWDAQ_tool_data $info(name)] ] \n]
		LWDAQ_print $info(text) "Found [expr [llength $info(calibration)]/2] calbrations,\
			saved to disk, and reloaded into memory."
		return $data
	}		
}

proc Wire_Monitor_open {} {
	upvar #0 Wire_Monitor_config config
	upvar #0 Wire_Monitor_info info

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
	
	set f $w.controls
	frame $f
	pack $f -side top -fill x
	
	label $f.daq -text "Acquisition:" -fg purple
	pack $f.daq -side left
	foreach a {Acquire Add Save Load} {
		set b [string tolower $a]
		button $f.$b -text $a -command [list LWDAQ_post Wire_Monitor_$b]
		pack $f.$b -side left -expand 1
	}
	label $f.calib -text "Calibration:" -fg purple
	pack $f.calib -side left -expand 1
	foreach a {Download Edit} {
		set b [string tolower $a]
		button $f.$b -text $a -command [list LWDAQ_post Wire_Monitor_$b]
		pack $f.$b -side left -expand 1
	}
	foreach a {Help Configure} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_tool_$b $info(name)"
		pack $f.$b -side left -expand 1
	}
		
	Wire_Monitor_draw_list

	set info(text) [LWDAQ_text_widget $w 100 10 1 1]

	LWDAQ_print $info(text) "$info(name) Version $info(version) \n" purple
	
	return $w
}

Wire_Monitor_init
Wire_Monitor_open
	
return ""

----------Begin Help----------

http://www.opensourceinstruments.com/WPS/WPS2/index.html#Operation

----------End Help----------

----------Begin Data----------
C0562_1 -3.5814 88.8400 -4.9796 -12.6389 94.3849 -4.9598 -1558.772  -0.344 -566.827 10.620  1.6
C0562_2 -3.2934 39.0816 -4.9960 -12.3827 33.6002 -5.1009  1582.496  -3.005  536.976 10.615  1.0
C0563_1 -3.5214 88.9127 -5.1230 -12.7312 94.5887 -5.0763 -1575.969   5.514 -542.610 10.819  1.5
C0563_2 -3.3509 39.2680 -4.9734 -12.5065 33.7752 -4.9481  1551.272  19.575  539.416 10.677  1.1
C0564_1 -3.9747 88.5415 -4.7928 -13.1483 94.0905 -4.6594 -1569.021  -8.746 -512.315 10.722  1.4
C0564_2 -3.9695 39.3654 -4.7458 -13.1743 34.0412 -4.7220  1593.724   4.024  520.136 10.634  0.9
C0565_1 -3.5672 88.6207 -5.0629 -12.6076 94.2726 -4.9598 -1567.705  10.392 -546.849 10.662  1.0
C0565_2 -3.4484 39.8043 -5.2642 -12.5624 34.5183 -5.4396  1565.119  -3.078  508.839 10.537  1.3
C0566_1 -3.8859 88.6454 -5.2273 -12.9857 94.2809 -5.1865 -1582.320 -20.841 -534.469 10.704  1.1
C0566_2 -3.7466 39.2677 -5.0547 -12.9736 33.8539 -5.0552  1563.256 -13.310  543.711 10.698  0.7
C0567_1 -3.5694 88.6711 -5.0861 -12.6712 94.3061 -5.0781 -1580.440  -5.260 -537.937 10.705  1.0
C0567_2 -3.7736 39.4031 -4.8684 -12.9777 33.9881 -4.9191  1572.537   0.816  536.695 10.679  0.9
C0568_1 -3.3093 88.3844 -5.1412 -12.5615 93.9346 -5.1872 -1570.244  16.832 -516.928 10.789  1.5
C0568_2 -3.3202 39.7891 -5.0332 -12.5296 34.4080 -5.0489  1574.662 -22.893  523.054 10.666  1.4
C0569_1 -3.7589 88.3002 -5.1047 -12.8801 93.9368 -4.9732 -1572.172   0.810 -521.804 10.723  1.1
C0569_2 -3.3012 39.2002 -5.0119 -12.4385 33.8331 -5.0350  1567.840   9.412  527.534 10.597  0.8
C0570_1 -3.2442 88.4068 -4.9615 -12.2915 94.0330 -4.7980 -1567.418  13.082 -564.814 10.655  0.8
C0570_2 -3.6587 39.5604 -4.7582 -12.8826 34.2429 -4.8317  1571.667   8.676  507.737 10.647  1.0
C0571_1 -3.4310 88.3453 -4.9420 -12.4542 94.0619 -4.8731 -1574.059  11.026 -545.430 10.682  0.7
C0571_2 -2.9100 39.2205 -4.8333 -12.0803 33.9034 -4.8948  1586.120  -3.044  523.163 10.601  1.9
C0572_1 -3.3310 88.4273 -5.0365 -12.3326 94.0394 -5.0141 -1572.532  -3.147 -584.894 10.608  1.1
C0572_2 -3.3205 39.1416 -4.6273 -12.5399 33.8051 -4.6120  1585.005  35.942  502.761 10.653  1.6
C0573_1 -3.0105 88.0131 -5.0867 -12.1858 93.5084 -5.0842 -1566.850   1.849 -529.929 10.695  1.7
C0573_2 -3.1108 39.4726 -5.1132 -12.4342 34.2241 -5.4606  1583.793 -19.189  474.527 10.705  1.7
C0574_1 -3.7672 88.0655 -5.1314 -12.9420 93.6321 -5.1718 -1563.151 -11.060 -502.908 10.732  1.0
C0574_2 -3.4638 39.1504 -4.9903 -12.7721 33.8712 -4.9789  1582.060   9.463  476.708 10.701  1.0
C0575_1 -3.5899 88.2808 -4.8065 -12.7710 93.7388 -4.5779 -1555.422   0.226 -533.660 10.683  0.9
C0575_2 -3.4780 39.4648 -5.2590 -12.6939 34.0032 -5.3275  1574.193  -9.697  540.351 10.713  1.1
C0576_1 -3.6122 88.3072 -5.2199 -12.6852 93.9971 -5.2623 -1559.916  -9.041 -552.198 10.710  1.7
C0576_2 -3.5002 38.8492 -5.1328 -12.8716 33.4424 -5.3060  1579.434  -1.799  505.294 10.821  1.6
C0577_1 -3.0532 88.1737 -4.6874 -12.1139 93.7990 -4.6121 -1575.027  11.455 -531.172 10.665  1.0
C0577_2 -3.1468 39.4506 -4.9204 -12.5241 34.1552 -4.9024  1574.531 -12.994  499.106 10.769  1.0
C0578_1 -3.6175 88.0932 -5.0633 -12.7138 93.6782 -4.9648 -1572.136  12.085 -541.722 10.674  0.7
C0578_2 -3.3534 39.2265 -4.9850 -12.5076 33.7612 -4.9016  1565.918  11.386  492.205 10.662  0.9
C0579_1 -3.3659 88.2530 -5.1653 -12.4633 93.8897 -5.1154 -1564.642   8.264 -536.941 10.702  1.8
C0579_2 -3.7198 38.9574 -4.9004 -13.0884 33.5283 -4.9737  1571.121 -15.314  507.540 10.828  1.1
C0580_1 -3.4580 88.3465 -4.9325 -12.6421 94.0081 -4.8300 -1575.557   9.820 -548.068 10.789  1.7
C0580_2 -2.8809 39.4290 -5.0137 -12.1095 33.9672 -5.1403  1567.693  -6.918  543.600 10.724  1.6
C0581_1 -3.6676 88.2095 -5.3032 -12.9480 93.6797 -5.2093 -1570.081  12.812 -494.762 10.773  0.8
C0581_2 -3.3130 39.2144 -5.5655 -12.5075 33.7681 -5.7888  1571.064   2.444  529.898 10.689  1.6
C0582_1 -3.2097 88.1029 -4.8020 -12.2649 93.7537 -4.6914 -1568.776   5.256 -547.926 10.674  0.9
C0582_2 -3.4677 39.2683 -4.5794 -12.7149 33.8733 -4.7029  1567.015   3.807  535.636 10.707  1.1
C0583_1 -2.9301 88.2465 -5.0233 -12.0009 93.7958 -5.0725 -1575.312  -8.390 -546.042 10.634  1.3
C0583_2 -3.2566 39.5093 -5.0483 -12.6026 34.1069 -5.1614  1571.859 -26.316  537.762 10.796  1.7
C0584_1 -3.4858 88.3578 -5.0164 -12.7522 93.8360 -5.0101 -1564.727  -1.190 -501.328 10.765  1.8
C0584_2 -3.1045 39.4025 -4.8897 -12.3314 34.1424 -4.9835  1570.411  -4.260  522.362 10.621  1.6
C0585_1 -3.6850 88.3330 -5.1424 -12.8687 94.0633 -5.0198 -1576.082  16.447 -555.258 10.825  2.5
C0585_2 -3.3292 39.2889 -5.1974 -12.5287 33.8389 -5.2820  1569.332 -18.081  547.339 10.693  1.8
D0626_1 -3.4660 88.5146 -4.4080 -12.4029 93.6920 -4.2045 -1548.082  -0.851 -483.968 10.330  2.0
D0626_2 -3.3930 39.2460 -5.1325 -12.3524 34.1230 -5.3459  1577.508   0.975  472.777 10.323  2.8
D0627_1 -3.2337 88.3093 -4.4387 -12.0975 93.4288 -4.2974 -1570.237   1.287 -497.693 10.237  3.3
D0627_2 -3.4599 39.1193 -5.1083 -12.5445 33.9130 -5.1399  1574.018  -6.026  512.043 10.471  2.0
D0628_1 -3.1341 88.3358 -4.2149 -12.1069 93.6195 -3.9104 -1567.817 -21.984 -521.493 10.417  4.2
D0628_2 -3.5688 39.0205 -4.9440 -12.5178 33.8427 -4.9456  1572.613   7.986  493.239 10.339  2.5
D0629_1 -3.6595 88.5039 -4.4685 -12.5879 93.7091 -4.2458 -1592.497 -10.273 -505.660 10.337  2.5
D0629_2 -3.2418 38.9423 -5.2814 -12.2294 33.7803 -5.3506  1597.449  -3.513  491.629 10.365  2.4
D0630_1 -3.3010 88.3110 -4.3996 -12.2174 93.5357 -4.1328 -1570.338 -15.234 -503.681 10.338  3.3
D0630_2 -3.1854 39.0972 -5.0641 -12.1690 33.9942 -5.1393  1598.223   8.082  491.919 10.332  2.5
D0631_1 -3.6020 88.3447 -4.5227 -12.5575 93.5697 -4.3609 -1565.626 -12.875 -502.267 10.370  3.3
D0631_2 -3.4441 39.3122 -4.8866 -12.4812 34.2009 -4.8964  1580.517   2.057  494.888 10.382  3.4
D0632_1 -3.3470 88.2762 -4.5507 -12.2917 93.4924 -4.4490 -1562.400  -9.042 -511.454 10.355  3.2
D0632_2 -3.1818 39.0966 -5.0891 -12.3118 33.9236 -5.0999  1566.116  -9.202  511.568 10.494  2.5
D0634_1 -3.7311 88.3928 -4.4738 -12.6470 93.5865 -4.3705 -1561.631  -8.308 -502.245 10.319  3.4
D0634_2 -3.5711 39.3367 -4.7799 -12.6160 34.3293 -4.9796  1573.596   8.876  499.990 10.340  1.8
D0635_1 -3.9953 88.4980 -4.6178 -13.0793 93.6704 -4.6039 -1565.822 -18.622 -488.802 10.453  2.8
D0635_2 -3.1588 39.0357 -4.9591 -12.1288 33.8712 -5.0913  1589.920  -2.068  509.595 10.351  2.1
D0636_1 -3.4617 88.3490 -4.5941 -12.4451 93.5378 -4.4367 -1544.948   2.466 -491.264 10.375  2.4
D0636_2 -3.6034 39.1542 -5.1007 -12.5746 33.9779 -5.2776  1576.369   8.068  507.508 10.359  2.7
D0637_1 -3.9778 88.5263 -4.1027 -12.9990 93.7253 -3.8016 -1570.861  -6.763 -529.696 10.416  3.3
D0637_2 -3.4881 39.2770 -4.7990 -12.4534 34.2224 -4.9546  1586.197   4.751  484.496 10.293  2.8
D0638_1 -3.7437 88.3677 -4.6103 -12.6937 93.5630 -4.4767 -1567.619  -8.569 -528.002 10.349  3.5
D0638_2 -3.4819 39.0585 -5.1671 -12.5525 33.9345 -5.2631  1576.673  -8.384  533.557 10.418  2.8
D0639_1 -3.4677 88.3759 -4.1715 -12.5546 93.6835 -3.8527 -1565.259 -17.400 -540.662 10.528  3.6
D0639_2 -3.2170 39.0177 -4.8561 -12.2073 33.9122 -4.9175  1571.588   3.343  497.833 10.339  1.9
D0640_1 -3.3520 88.2560 -4.4044 -12.2274 93.4439 -4.0923 -1559.527  -9.651 -480.877 10.285  2.4
D0640_2 -3.2451 39.0881 -5.0387 -12.1740 34.0199 -5.1314  1581.281   1.743  503.850 10.267  2.8
D0641_1 -3.1622 88.3082 -4.3546 -12.0576 93.5157 -4.1340 -1580.705   1.594 -533.622 10.310  2.5
D0641_2 -3.1895 39.0060 -5.0439 -12.4522 33.7492 -5.1335  1581.108   5.581  510.558 10.651  3.1
D0642_1 -3.7635 88.3614 -4.6533 -12.0186 93.1952 -4.6065 -1544.517  -0.658 -509.346  9.566  2.7
D0642_2 -3.3411 38.9527 -4.8871 -11.5991 34.1799 -5.1101  1578.766  -3.885  503.294  9.541  1.1
D0643_1 -3.7711 88.3364 -4.5965 -12.0681 93.0889 -4.4709 -1561.928  -3.569 -513.268  9.562  2.4
D0643_2 -3.6230 38.8190 -4.7128 -12.0464 34.0995 -4.6935  1575.446  -1.720  508.145  9.655  2.4
D0644_1 -3.9850 88.3589 -4.3371 -13.0815 93.5853 -4.1912 -1563.393   1.849 -518.938 10.492  3.6
D0644_2 -3.1469 39.2644 -5.0507 -12.0814 34.1662 -5.0740  1581.728  -0.967  528.614 10.287  2.5
D0645_1 -3.5926 88.1641 -4.8188 -12.5256 93.3092 -4.6956 -1560.701  -4.296 -515.180 10.309  2.3
D0645_2 -3.7857 39.1243 -5.0852 -12.7481 34.0358 -5.1882  1575.846  -9.219  517.817 10.307  3.2
D0646_1 -3.4077 88.3079 -4.5771 -12.3599 93.5277 -4.6089 -1565.635  -3.822 -533.093 10.363  2.9
D0646_2 -3.3776 39.0542 -4.9610 -12.3998 33.9598 -4.9991  1572.829   1.236  497.594 10.361  3.2
D0647_1 -3.4696 88.2327 -4.1099 -12.3762 93.4043 -3.8811 -1569.435  -8.086 -522.292 10.302  2.4
D0647_2 -3.6372 39.1465 -4.9210 -12.6973 34.0767 -4.8842  1580.882  12.633  507.496 10.382  2.2
D0648_1 -3.6518 88.3929 -4.4605 -12.6657 93.5946 -4.2689 -1541.131   0.271 -508.302 10.409  2.6
D0648_2 -3.3901 39.4513 -5.0325 -12.5644 34.3405 -5.1610  1552.122   4.970  484.145 10.503  1.8
D0649_1 -3.6575 88.4462 -4.1960 -12.6205 93.6968 -3.8993 -1581.208 -10.384 -525.449 10.392  2.7
D0649_2 -3.5806 39.5932 -4.8893 -12.6683 34.4605 -4.9512  1579.408  -0.443  488.831 10.437  2.6
D0650_1 -3.3799 88.1671 -4.5174 -12.3108 93.3205 -4.2253 -1564.704  -0.615 -521.338 10.315  2.7
D0650_2 -3.6378 39.3977 -4.9942 -12.5927 34.3198 -5.1705  1576.530   5.088  491.459 10.296  2.0
D0651_1 -3.9238 88.5074 -4.1021 -12.9093 93.7323 -3.7752 -1554.484 -15.547 -498.823 10.399  3.7
D0651_2 -3.4560 39.0248 -4.8170 -12.6997 33.7971 -4.9645  1575.273   3.987  525.798 10.621  2.7
D0652_1 -3.5243 88.3285 -4.2592 -12.5015 93.5275 -4.0524 -1563.070   2.680 -518.658 10.376  3.5
D0652_2 -3.3216 38.9217 -4.9936 -11.6066 34.1823 -5.0456  1579.972   0.475  523.507  9.545  2.2
D0655_1 -4.2525 88.5454 -4.6597 -12.5997 93.3955 -4.5914 -1561.884   2.946 -507.262  9.654  2.5
D0655_2 -3.2246 39.0487 -4.8854 -12.1909 33.8923 -4.9602  1570.943   5.014  514.027 10.344  1.8
D0656_1 -3.8612 88.4597 -4.3552 -12.8798 93.6115 -4.2521 -1559.444 -14.434 -499.324 10.387  3.0
D0656_2 -3.4087 39.2145 -4.9526 -12.4014 34.2160 -5.0058  1579.132   2.817  515.367 10.289  2.2
D0657_1 -3.8350 88.3003 -4.5873 -12.0866 93.1493 -4.4375 -1562.738  -7.146 -517.118  9.572  2.7
D0657_2 -3.7776 38.9644 -4.8603 -12.1383 34.1733 -5.0140  1588.321  -5.409  505.625  9.637  3.1
D0658_1 -3.7286 88.1363 -4.7413 -11.9990 92.9842 -4.6932 -1561.205   2.253 -507.259  9.587  2.3
D0658_2 -3.9360 38.9570 -4.8772 -12.2538 34.2011 -4.8553  1577.151   2.636  504.298  9.581  1.5
D0659_1 -3.8263 88.4211 -4.3403 -12.8425 93.6433 -4.0867 -1562.661  -9.905 -502.937 10.422  3.7
D0659_2 -3.1012 39.2097 -4.9588 -12.0557 34.1241 -5.1922  1571.030   1.619  467.162 10.301  2.3
D0660_1 -3.3112 88.2646 -4.4776 -12.2221 93.4465 -4.2212 -1550.009 -16.778 -521.728 10.311  2.8
D0660_1 -3.3112 88.2646 -4.4776 -12.2221 93.4465 -4.2212 -1550.009 -16.778 -521.728 10.311  2.8
D0660_2 -3.2675 39.2747 -5.0421 -12.2811 34.1612 -5.2958  1572.930  -0.532  484.131 10.366  2.5
D0661_1 -3.0430 88.3090 -4.7929 -12.0218 93.5162 -4.6181 -1581.780  -3.148 -500.814 10.381  2.1
D0661_2 -3.0328 39.0703 -5.0207 -12.1212 33.8699 -5.1386  1592.061   8.458  511.963 10.472  2.0
D0662_1 -3.5568 88.3782 -4.3402 -12.5213 93.5636 -4.2067 -1566.570  -8.549 -487.066 10.357  3.1
D0662_2 -3.3684 39.2896 -4.8498 -12.3725 34.1993 -4.9057  1580.789   4.125  463.319 10.344  2.3
D0663_1 -3.4687 88.1269 -4.5386 -12.3900 93.3111 -4.3294 -1563.309 -19.771 -510.262 10.320  3.7
D0663_2 -3.3431 39.1453 -4.9220 -12.3140 33.9977 -5.1897  1577.197  -3.230  503.916 10.346  2.4
D0664_1 -3.4498 88.3717 -4.8031 -12.3761 93.5533 -4.6353 -1574.458   2.144 -505.955 10.323  3.1
D0664_2 -3.2909 39.1718 -5.1886 -12.2676 34.0564 -5.3699  1569.250  -0.993  506.165 10.334  2.6
D0665_1 -3.5470 88.4160 -4.0701 -12.6451 93.7238 -3.7350 -1556.492  -3.259 -526.404 10.538  3.0
D0665_2 -3.3628 39.2111 -5.1063 -12.3165 34.0917 -5.2537  1577.221   7.053  506.605 10.315  3.7
Q0129_1 -5.1326 89.5092 -4.7955 -14.2253 94.9853 -4.6239 -1573.462  19.096 -553.251 10.616  1.8
Q0129_2 -5.0402 38.8200 -4.2803 -14.0014 33.1804 -4.0978  1567.728  19.874  564.146 10.590  1.2
Q0130_1 -5.0285 88.6823 -1.8141 -15.7230 94.9590 -1.3438 -1567.144 -35.132 -510.121 12.409  6.5
Q0130_2 -2.0807 39.9298 -6.0488 -11.8436 34.2353 -6.7620  1568.044  -0.141  652.405 11.325  6.1
Q0131_1 -5.6082 89.6961 -2.9988 -16.1144 96.4313 -2.7459 -1576.227   5.898 -519.091 12.482  3.1
Q0131_2 -2.4564 40.7047 -4.6130 -12.0240 35.1758 -5.2505  1584.573  39.607  663.654 11.069  2.2
Q0132_1 -4.4475 87.6752 -4.0442 -14.6304 93.6529 -3.9048 -1574.944   1.036 -638.629 11.809  3.1
Q0132_2 -4.1223 37.6675 -4.9617 -14.3354 31.3532 -4.6422  1578.667 -23.815  537.598 12.012  3.5
Q0217_1 -3.7341 88.0156 -5.1446 -12.3450 93.1604 -5.2928 -1570.842  -2.451 -524.061 10.032  4.1
Q0217_2 -3.7659 39.2857 -5.2480 -12.4664 33.8635 -5.4907  1579.498 -14.559  538.006 10.255  3.4
Q0218_1 -3.6018 88.2855 -5.0126 -12.3584 93.4981 -5.2071 -1577.149 -17.284 -501.482 10.192  2.8
Q0218_2 -3.0596 39.2682 -5.0441 -11.6498 34.0748 -5.1754  1587.457 -16.477  524.521 10.039  3.7
Q0219_1 -3.8759 88.2146 -4.7390 -12.6778 93.3898 -4.6159 -1571.005 -12.498 -512.488 10.211  2.5
Q0219_2 -4.0707 38.9694 -5.0821 -12.8743 33.7455 -5.3048  1564.117   4.317  515.094 10.239  1.8
Q0220_1 -3.7948 88.5341 -4.7400 -12.5552 93.8233 -4.6305 -1566.102  -3.111 -518.490 10.234  2.1
Q0220_2 -3.8614 39.3036 -5.1557 -12.6308 34.0132 -5.3138  1582.762  -2.705  523.321 10.243  2.4
Q0221_1 -3.3586 88.5632 -4.9410 -12.1735 93.9090 -5.2002 -1564.346 -27.796 -536.440 10.312  2.6
Q0221_2 -3.3045 38.9175 -5.1852 -12.5596 33.2526 -5.2870  1572.349  -6.001  508.072 10.852  2.9
Q0222_1 -3.5939 88.5958 -5.0038 -12.2096 93.8843 -5.1148 -1572.245  -3.883 -507.002 10.110  1.7
Q0222_2 -3.6261 38.9267 -5.1733 -12.2358 33.7303 -5.3230  1588.706  -7.100  529.875 10.057  3.7
Q0223_1 -3.2025 88.1766 -4.7700 -11.9550 93.4682 -4.7886 -1556.892 -12.035 -538.804 10.228  3.3
Q0223_2 -3.6462 39.1606 -5.1181 -12.4282 33.8708 -5.2248  1574.217   7.468  497.789 10.253  2.6
Q0224_1 -3.1736 88.0767 -4.7332 -11.9028 93.3959 -4.7607 -1571.339  -3.505 -517.339 10.222  1.9
Q0224_2 -3.2439 39.0459 -4.9030 -11.8900 33.8745 -4.9614  1576.473   1.831  512.887 10.075  1.9
Q0225_1 -4.0725 88.3797 -4.8922 -12.8451 93.5157 -4.8969 -1553.142  -4.703 -521.642 10.165  2.4
Q0225_2 -3.2968 39.3486 -5.0098 -11.8783 34.3293 -5.2225  1571.359  -6.605  525.489  9.944  1.8
Q0227_1 -3.9676 88.4175 -4.7537 -12.7444 93.7234 -4.7456 -1555.251 -20.240 -518.738 10.256  2.3
Q0227_2 -3.2000 39.3041 -4.7522 -11.8056 34.0984 -4.9438  1569.443  -9.962  520.687 10.059  2.4
P0195_1 -8.0503 91.8587 -4.2477 -17.2217 97.4737 -4.2104 -1577.398  -0.325 -533.494 10.754  1.6
P0195_2 -3.8649 39.2839 -4.3795 -12.7663 33.5418 -4.3931  1562.686  -1.550  572.270 10.593  1.6
P0197_1 -3.7906 89.4672 -3.8999 -12.5781 94.6556 -3.8052 -1575.547  14.727 -537.395 10.205  1.2
P0197_2 -3.3961 38.2920 -4.5059 -12.2748 32.8203 -4.5708  1574.446   7.187  546.390 10.430  1.5
P0198_1 -3.0843 90.1940 -4.2425 -11.9576 95.7197 -4.3450 -1575.744   0.437 -541.792 10.454  1.2
P0198_2 -3.7644 38.9943 -4.6077 -12.7347 33.4335 -4.6656  1567.472  -2.328  551.404 10.554  1.3
P0199_1 -4.0176 88.0416 -4.4290 -12.7107 93.3821 -4.0536 -1573.817  38.910 -547.634 10.209  1.2
P0199_2 -4.4658 39.4894 -4.4051 -13.4677 34.0853 -4.1260  1571.587  20.234  519.217 10.503  1.9
P0200_1 -3.7885 89.4043 -4.2377 -12.5270 94.9308 -4.2667 -1567.298  10.040 -556.169 10.339  1.6
P0200_2 -4.2151 38.6110 -4.5358 -13.2755 33.1151 -4.5946  1572.835   8.406  525.869 10.597  1.9
P0201_1 -3.7992 89.0629 -4.0823 -12.6996 94.3538 -4.1472 -1569.350  11.913 -532.884 10.354  1.5
P0201_2 -4.1684 38.7802 -4.1355 -13.1010 33.2285 -4.2102  1560.343  15.907  547.316 10.518  1.3
P0202_1 -3.9688 89.2693 -4.3937 -12.8662 94.7569 -4.2628 -1568.482  14.449 -540.951 10.454  1.5
P0202_2 -4.4135 39.0829 -4.2892 -13.4683 33.8120 -4.3727  1573.235   2.048  514.979 10.477  1.5
P0203_1 -3.0524 89.2967 -4.3284 -11.8453 94.7261 -4.3051 -1573.151   7.914 -543.224 10.334  1.9
P0203_2 -3.4665 38.0783 -4.1433 -12.3490 32.5047 -4.2011  1573.072  -6.642  538.407 10.486  1.6
P0222_1 -3.2506 88.2492 -4.5628 -12.3277 93.8891 -4.4901 -1568.477   4.154 -581.213 10.687  2.1
P0222_2 -4.7831 38.5881 -4.5009 -13.5001 33.2596 -4.3538  1570.995  28.621  528.012 10.218  1.4
P0223_1 -3.8841 87.8976 -4.2084 -12.9706 93.3465 -4.1088 -1571.456  15.510 -556.602 10.596  1.2
P0223_2 -4.5310 40.0608 -4.3034 -13.7758 34.5910 -4.5274  1574.408  -1.478  520.011 10.744  1.5
P0224_1 -4.2213 87.7491 -4.6937 -13.2627 93.3834 -4.5124 -1569.469  14.796 -536.644 10.655  1.6
P0224_2 -4.5677 39.6968 -4.6057 -13.9320 34.2023 -4.8243  1579.873  -0.778  517.847 10.860  2.0
P0225_1 -3.1255 88.0477 -4.5187 -12.1260 93.5160 -4.6606 -1581.139  -2.690 -555.326 10.532  1.3
P0225_2 -4.1338 38.9178 -4.4174 -13.2475 33.4272 -4.2957  1582.116  23.001  530.661 10.641  1.1
----------End Data----------



























