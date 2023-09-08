# Wire_Monitor, a Standard and Polite LWDAQ Tool
# Copyright (C) 2019 Kevan Hashemi, Open Source Instruments Inc.
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

proc Wire_Monitor_init {} {
	upvar #0 Wire_Monitor_info info
	upvar #0 Wire_Monitor_config config
	global LWDAQ_Info LWDAQ_Driver
	
	LWDAQ_tool_init "Wire_Monitor" "1.4"
	if {[winfo exists $info(window)]} {return ""}

	set config(wps_list) "1"	
	set config(wps1_id) "Q0216"
	set config(wps1_version) "WPS2B"
	set config(wps1_addr) "10.0.0.37"
	set config(wps1_sock) "8"
	set config(wps1_x) "-1"
	set config(wps1_y) "-1"
	set config(ref_z) "-5"
	set config(wps_calib_addr) "http://www.opensourceinstruments.com/WPS/WPS_Calibrations.txt"
	
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
<html>
<head><title>301 Moved Permanently</title></head>
<body>
<center><h1>301 Moved Permanently</h1></center>
<hr><center>openresty/1.19.9.1</center>
</body>
</html>

----------End Data----------




























