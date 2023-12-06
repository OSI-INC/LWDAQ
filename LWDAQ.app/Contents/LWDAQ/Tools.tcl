# Tool Creation and Management Software
# Copyright (C) 2005-2021 Kevan Hashemi, Brandeis University
# Copyright (C) 2022-2023 Kevan Hashemi, Open Source Instruments Inc.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.

# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.

# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place - Suite 330, Boston, MA  02111-1307, USA.

#
# Tools.tcl contains routines that configure and manage polite and standard 
# LWDAQ tools. It provides the Tool Maker and Run Tool commands for the Tool
# menu.
#

#
# LWDAQ_tools_init initializes the Tools routines.
#
proc LWDAQ_tools_init {} {
	global LWDAQ_Info
	return ""
}

#
# LWDAQ_read_script reads a file from disk and returns its contents.
#
proc LWDAQ_read_script {fn} {
	set f [open $fn]
	set contents [read $f]
	close $f
	return $contents
}

#
# LWDAQ_run_tool runs a tool script. It takes two optional parameters: the tool
# name and the mode in which the tool is to run. If pass no paramters, these two
# default to an empty string and "Communal" mode. With an empty string for the
# tool name, when we are running with graphics, the routine opens a browser and
# asks the user to select a file. The routine deduces the tool name from the
# file name and runs the tool. If we pass it a tool name, the routine looks for
# the tool script in Tools, Tools/More, Tools/Spawn, the default directory, and
# the working directory in that order. The routine deduces the tool name from
# the root of the file name. Once we have the tool name and its script file
# name, we prepare to run the tool. The mode can have one of three possible
# values: Standalone, Slave, or Communal. If the mode is "Standalone" or
# "Slave", the routine deletes the Instrument and Tool menus. If the mode is
# Communal, the routine leaves these menus intact. When the tool starts up in
# Standalone of Slave mode, it should take over the main window for its own
# interface and delete the usual Quit button. When the tool starts up communal,
# it should create a new toplevel window for its interface. In Slave mode, the
# tool should set itself up to receive commands through stdin from its master,
# and send output through stdout. In Standalone mode, the tool should operate
# independent of stdin and stdout.
#
proc LWDAQ_run_tool {{tool ""} {mode "Communal"}} {
	global LWDAQ_Info

	if {$tool == ""} {
		# Browse for the tool file.
		if {$LWDAQ_Info(gui_enabled)} {
			set fn [LWDAQ_get_file_name]
			if {$fn == ""} {return ""}
		} else {
			error "No tool name given."
		}
	} else {
		# Search for the tool file. The tool name may already contain the tcl 
		# extension, and the tool name may include a file path. We strip off
		# the file path and we add the extension. 
		set tool [file root [file tail $tool]]\.tcl

		# We start looking for the file in various directories.
		set fn [file join $LWDAQ_Info(tools_dir) $tool]
		if {![file exists $fn]} {
			set fn [file join $LWDAQ_Info(tools_dir) More $tool]
			if {![file exists $fn]} {
				set fn [file join $LWDAQ_Info(tools_dir) Spawn $tool]
				if {![file exists $fn]} {
					set fn $tool
					if {![file exists $fn]} {
						set fn [file join $LWDAQ_Info(working_dir) $tool]
						if {![file exists $fn]} {
							error "Cannot find tool file \"$tool\""
						}
					}
				}
			}
		}
	}
	
	# Deduce the tool name from the file name.
	set name [file root [file tail $fn]]
	
	# Set global variables carrying the file name.
	global $name\_file 
	set $name\_file $fn
	global $name\_mode
	set $name\_mode $mode

	# If we are running the tool as a standalone, we delete some menus.
	if {($mode == "Standalone") || ($mode == "Slave")} {
		switch $LWDAQ_Info(os) {
			"MacOS" {.menubar delete 1 2}
			"Windows" {.menubar delete 3 4}
			"Linux" {.menubar delete 3 4}
		}
	}
	
	# Proceed to run the script at the global scope.
	uplevel #0 [list source $fn]
	
	# At this point, we can assume success. We return an empty string.
	return ""
}

#
# LWDAQ_spawn_tool runs a tool in a new and independent LWDAQ process. In the
# spawned LWDAQ, the root window does not contain the Quit button, but instead
# presents the Tool window. When the new LWDAQ process starts up, it uses a
# configuration file to launch the specified tool and take over the root window.
# The tool must be designed for spawning, in that it can deal with a window that
# is named ".toolname" or just "." We can pass in our own configuration commands
# into the routine through the commands string, and these will be written to
# the configuration file after the standalone run command. We can pass a
# configuration file name in for the spawn routine to use, in cases where we are
# spawning many processes consecutively, each with their own custom
# configuration, and we don't want to over-write one file before it has been
# used. If we don't provide a file name, the spawn routine generates a file in
# the temporary directory. When the routine launches the new process, it does so
# using the command-line "--spawn" option, which suppresses any console or pipe
# that might otherwise be connected to the new process. By this means, the new
# process will not quit when the process that created it quits.
#
proc LWDAQ_spawn_tool {tool {commands ""} {cfn ""}} {
	global LWDAQ_Info
	
	# When we spawn the tool, we want the spawned process to start with its operating
	# system file pointer in a known location. So we change directory to the 
	# LWDAQ program directory.
	cd $LWDAQ_Info(program_dir)
	
	# If we have not received a configuration file name, compose our own.
	if {$cfn == ""} {
		set cfn [file join $LWDAQ_Info(temporary_dir) $tool\.tcl]
	}
	
	# Open the configuration file and write the standalone commands into the
	# file followed by any user-defined commands.
	set f [open $cfn w]
	puts $f "LWDAQ_run_tool $tool\.tcl Standalone"
	if {$commands != ""} {puts $f $commands}
	close $f
	
	# Spawn a standalone LWDAQ process and give it the configuration file, which
	# will cause our chosen tool to start up and take over the root window.
	switch $LWDAQ_Info(os) {
		"MacOS" {
			exec ./lwdaq --spawn $cfn &
		}
		"Windows" {
			exec ./LWDAQ.bat --spawn $cfn &
		}
		"Linux" {
			set lfn [file join $LWDAQ_Info(temporary_dir) spawn_log.txt]
			exec ./lwdaq --spawn $cfn >& $lfn < /dev/null &
		}
		"Raspbian" {
			set lfn [file join $LWDAQ_Info(temporary_dir) spawn_log.txt]
			exec ./lwdaq --spawn $cfn >& $lfn < /dev/null &
		}
		default {
			exec ./lwdaq --spawn $cfn >& $lfn < /dev/null &
		}
	}
	
	# Return an empty string.
 	return ""
}

#
# LWDAQ_tool_init performs initialization common to all LWDAQ tools. If the tool
# is already being presented in graphical mode with a window, we do not
# re-initialize the tool, but simply raise its window. If no such window exists,
# we delete any existing tool arrays, and initialize some variables common to
# all tools.
#
proc LWDAQ_tool_init {name version} {
	upvar #0 $name\_info info
	upvar #0 $name\_config config
	upvar #0 $name\_mode mode
	upvar #0 $name\_file tool_file_name
	global LWDAQ_Info
	
	# If the tool window already exists, abort.
	if {[winfo exists [string tolower .$name]]} {
		raise [string tolower .$name]
		return "ABORT"
	}		
	
	# Delete any previous copies of the configuration and information arrays.
	array unset info
	array unset config

	# The window names will be the same for communal and standalone modes. But
	# in the case of the standalone the main window for the tool will be a frame
	# inside the root window, rather than its own top-level window.
	set info(window) [string tolower .$name]
	
	# If we are running with graphics, the tool will have its own text widget.
	set info(text) $info(window).text

	# Fill in elements common to all tools in all modes.
	set info(name) $name
	set info(version) $version
	set info(mode) $mode
	set info(tool_file_name) $tool_file_name
	set info(gui) $LWDAQ_Info(gui_enabled)	
	set info(settings_file_name) \
		[file join $LWDAQ_Info(tools_dir) Data $name\_Settings.tcl]
	set info(data_dir) [file join $LWDAQ_Info(tools_dir) Data]
		
	# Return an empty string.
	return ""
}

#
# LWDAQ_tool_open opens a tool window if none exists, and returns the name of
# the window. The routine assumes that the tool has already been initialized. If
# the tool window does exist, the routine raises the tool window and returns an
# empty string. If graphics are disabled, the routine returns an empty string.
# The routine recognises two special opening modes, Standalone and Slave, in
# which the tool will take over the main window and delete the Quit button.
#
proc LWDAQ_tool_open {name} {
	upvar #0 $name\_info info
	
	# Report an error if the tool has not been initialized.
	if {![info exists info]} {
		error "Cannot open $name window before initialization."
	}

	# Return if the tool is not supposed to be opened with graphics.
	if {!$info(gui)} {return ""}

	# Get the maximum size of the root window. We are going to double this
	# for our tool window.
	scan [wm maxsize .] %d%d x y	

	# In the standalone and slave modes, we create a frame in the root window
	# for the tool. In all other modes, we create a new top-level window for the
	# tool.
	switch $info(mode) {
		"Standalone" {
			if {[winfo exists $info(window)]} {
				raise .
				return ""
			} {
				catch {destroy .frame}
				set f [frame $info(window)]
				pack $f -side top -fill both -expand yes
				wm title . "Standalone $info(name) $info(version)" 
				raise .	
				wm maxsize . [expr $x*2] [expr $y*2]
			}
		}
		"Slave" {
			if {[winfo exists $info(window)]} {
				raise .
				return ""
			} {
				catch {destroy .frame}
				set f [frame $info(window)]
				pack $f -side top -fill both -expand yes
				wm title . "Slave $info(name) $info(version)" 
				raise .	
				wm maxsize . [expr $x*2] [expr $y*2]
			}
		}
		default {
			if {[winfo exists $info(window)]} {
				raise $info(window)
				return ""
			} {
				toplevel $info(window)
				wm title $info(window) "$info(name) $info(version)"				
				wm maxsize $info(window) [expr $x*2] [expr $y*2]
			}
		}
	}		
	
	# Return the frame or window name.
	return $info(window)
}

#
# LWDAQ_tool_save writes a tool's configuration array to disk.
#
proc LWDAQ_tool_save {name} {
	upvar #0 $name\_config config
	upvar #0 $name\_info info
	set f [open $info(settings_file_name) w]
	foreach {name} [lsort -dictionary [array names config]] {
		puts $f "set $info(name)\_config($name) \"$config($name)\""
	}
	close $f
	return ""
}

#
# LWDAQ_tool_unsave deletes a tool's saved configuration array.
#
proc LWDAQ_tool_unsave {name} {
	upvar #0 $name\_info info
	set fn $info(settings_file_name)
	if {[file exists $fn]} {
		file delete $fn
		return $fn
	} {
		return ""
	}
}

#
# LWDAQ_tool_help extracts help lines from the tool script. If the help
# consists only of an http reference, the routine attempts to open the
# link and display the help web page. Otherwise, the routine prints
# the help text in a new text window.
#
proc LWDAQ_tool_help {name} {
	upvar #0 $name\_info info

	if {[file exists $info(tool_file_name)]} {
		set f [open $info(tool_file_name) r]
		set help_text ""
		while {[gets $f line] >= 0} {
			if {$line == "return"} {break}
			if {$line == "----------Begin Help----------"} {break}
		}
		while {[gets $f line] >= 0} {
			if {$line == "----------End Help----------"} {break}
			append help_text "$line\n"
		}
		close $f
	} {
		LWDAQ_print $info(text) "ERROR: Can't find $info(tool_file_name) to get help text.\n"
		LWDAQ_print $info(text) "SUGGESTION: Put the tool script in ./Tools or ./Tools/More.\n"
		return ""
	}

	if {[regexp {\A[ \t\n]*(http://[^\n]*)} $help_text match link]} {
		LWDAQ_url_open $link
	} {
		set w [LWDAQ_toplevel_text_window 85 40]
		wm title $w "$info(name) Version $info(version) Help\n"
		$w.text insert end "$help_text\n"
	}
	return ""
}

#
# LWDAQ_tool_data extracts data lines from a tool's script and returns
# them as a string. The routine trims white spaces from the start and end
# of the data.
#
proc LWDAQ_tool_data {name} {
	upvar #0 $name\_info info
	if {[file exists $info(tool_file_name)]} {
		set data ""
		set f [open $info(tool_file_name) r]
		while {[gets $f line] >= 0} {
			if {$line == "----------Begin Data----------"} {break}
		}
		while {[gets $f line] >= 0} {
			if {$line == "----------End Data----------"} {break}
			append data "$line\n"
		}
		close $f
	} {
		LWDAQ_print $info(text) "ERROR: Can't find $info(tool_file_name) to extract data.\n"
		LWDAQ_print $info(text) "SUGGESTION: Put the tool script in the Tools folder.\n"
	}
	return [string trim $data]
}

#
# LWDAQ_tool_rewrite_data replaces the existing data portion of a tool script with a new
# data string.
#
proc LWDAQ_tool_rewrite_data {name data} {
	upvar #0 $name\_info info
	if {[file exists $info(tool_file_name)]} {
		set f [open $info(tool_file_name) r]
		set contents ""
		while {[gets $f line] >= 0} {
			append contents "$line\n"
			if {$line == "----------Begin Data----------"} {break}
		}
		append contents "$data\n"
		while {[gets $f line] >= 0} {
			if {$line == "----------End Data----------"} {
				append contents "$line\n"
				break
			}
		}
		while {[gets $f line] >= 0} {
			append contents "$line\n"
		}
		close $f
		set f [open $info(tool_file_name) w]
		puts $f $contents
		close $f
	} {
		LWDAQ_print $info(text) "ERROR: Can't find $info(tool_file_name) to extract data.\n"
		LWDAQ_print $info(text) "SUGGESTION: Put the tool script in the Tools folder.\n"
	}
	return ""
}


#
# LWDAQ_tool_configure opens a configuration panel so we can set a tool's
# configuration array elements. It also provides for extra configuration buttons
# by returning the name of a frame below the Save button.
#
proc LWDAQ_tool_configure {name {num_columns 2}} {
	upvar #0 $name\_info info
	upvar #0 $name\_config config

	set w $info(window)\.config
	if {[winfo exists $w]} {destroy $w}

	toplevel $w
	wm title $w "$info(name) Configuration Panel"
	scan [wm maxsize .] %d%d x y
	wm maxsize $w [expr $x*4] [expr $y*1]
	
	set ff [frame $w.save]
	pack $ff -side top -fill x 

	button $ff.save -text "Save Configuration" -command "LWDAQ_tool_save $name"
	pack $ff.save -side left -expand 1
	
	button $ff.unsave -text "Unsave Configuration" -command "LWDAQ_tool_unsave $name"
	pack $ff.unsave -side left -expand 1

	set custom_frame [frame $w.custom]
	pack $custom_frame -side top -fill x 
	
	set ff [frame $w.config]
	pack $ff -side top -fill x -expand 1
	for {set i 1} {$i <= $num_columns} {incr i} {
		frame $ff.f$i
		pack $ff.f$i -side left -fill y 
	}

	set config_list [lsort -dictionary [array names config]]
	set num_rows [expr [llength $config_list] / $num_columns]
	if {[llength $config_list] % $num_columns != 0} {
		set num_rows [expr $num_rows + 1]
	}

	set count 1
	set frame_num 1
	foreach p_name $config_list {
		if {$count > $num_rows} {
			set count 1
			incr frame_num
		}
		set f $ff.f$frame_num
		label $f.l$p_name -text $p_name -anchor w 
		entry $f.e$p_name -textvariable $info(name)_config($p_name) \
			-relief sunken -bd 1 
		grid $f.l$p_name $f.e$p_name -sticky news
		incr count
	}
	
	return $custom_frame
}

#
# LWDAQ_tool_reload closes the tool and opens it again. We use this procedure
# when we are developing a tool. It allows us to re-load with the new tool
# script with one button press.
#
proc LWDAQ_tool_reload {name} {
	upvar #0 $name\_info info

	catch {destroy $info(window)}
	if {[file exists $info(tool_file_name)]} {
		source $info(tool_file_name)
	} {
		LWDAQ_print $info(text) "ERROR: Can't find $info(tool_file_name) to reload."
	}
	return ""
}

#
# LWDAQ_Toolmaker_execute extracts the script in the Toolmaker's text window,
# appends it to the Toolmaker script list, creates a new toplevel text window or
# selects the existing toplevel execution window, and executes the script at the
# global level. It prints out results as the script requires, and print errors
# in red when they occur. The script can refer to the text widget with the
# global variable "t". Above the text window is a frame, "f", also declared at
# the global level, which is packed in the top of the window, but empty unless
# the script creates buttons and such like to fill it.
#
proc LWDAQ_Toolmaker_execute {{save 1}} {
	upvar #0 Toolmaker_info info
	global t f w

	# The script we execute will always be the one shown in the
	# text window.
	set script [string trim [$info(text) get 1.0 end]]
	
	# If we want to save the script, we add it to the script list
	# and we save the script list to a backup file.
	if {$save} {
		set script [string trim [$info(text) get 1.0 end]]
		lappend info(scripts) $script
		set info(scripts) [lrange $info(scripts) end-$info(max_scripts) end]
		set info(script_index) [llength $info(scripts)]
		LWDAQ_Toolmaker_save $info(list_backup)
		$info(text) delete 1.0 end
	}
	
	# Destroy any existing execution window and create a new one.
	catch {destroy $w}
	set w [LWDAQ_toplevel_window "Toolmaker Execution"]
	set f [frame $w.f]
	pack $f -side top -fill x
	set t [LWDAQ_text_widget $w 60 15 1 1]	

	# Execute the script at the global scope. If the script generates
	# an error, we catch the error and write it to the execution text
	# widget.
	if {[catch {uplevel #0 $script} result]} {
		LWDAQ_print $t "ERROR: $result" red
		LWDAQ_print $t "Error Information:"
		if {[info exists errorInfo]} {
			LWDAQ_print $t $errorInfo blue
		} {
			LWDAQ_print $t "No error information available." blue
		}
	}

	# Return an empty string.
	return ""
}

#
# LWDAQ_Toolmaker_repeat executes the previous script without adding a copy of it to 
# the list of scripts.
#
proc LWDAQ_Toolmaker_repeat {} {
	LWDAQ_Toolmaker_execute 0
}

#
# LWDAQ_Toolmaker_back clears the script text window, decrements the script index,
# and displays the previous script in the Toolmaker comamnd list.
#
proc LWDAQ_Toolmaker_back {} {
	upvar #0 Toolmaker_info info
	if {$info(script_index) > 0} {
		set info(script_index) [expr $info(script_index) -1]
		set script [lindex $info(scripts) $info(script_index)]
		$info(text) delete 1.0 end
		LWDAQ_print $info(text) $script
		$info(text) see 0.0
	}
	return ""
}

#
# LWDAQ_Toolmaker_forward clears the script window, increments the script index,
# and displays the next script in the Toolmaker script list. If you have reached
# the end of the list, it displays a blank screen, ready for a fresh script.
#
proc LWDAQ_Toolmaker_forward {} {
	upvar #0 Toolmaker_info info
	if {$info(script_index) < [llength $info(scripts)]} {
		incr info(script_index)
		set script [lindex $info(scripts) $info(script_index)]
		$info(text) delete 1.0 end
		LWDAQ_print $info(text) $script
		$info(text) see 0.0
	}
	return ""
}

#
# LWDAQ_Toolmaker_save saves the current Toolmaker script list 
# to a file. It returns the file name.
#
proc LWDAQ_Toolmaker_save {{file_name ""}} {
	upvar #0 Toolmaker_info info
	if {$file_name == ""} {set file_name [LWDAQ_put_file_name Scripts.tcl]}
	if {$file_name == ""} {return ""}
	set f [open $file_name w]
	foreach c $info(scripts) {
		puts $f "<script>"
		puts $f [string trim $c]
		puts $f "</script>\n"
	}
	close $f
	return $file_name
}

#
# LWDAQ_Toolmaker_load reads a previously-saved script library or an
# individual script from a file and appends the script or scripts
# to the current script list. It returns the file name.
#
proc LWDAQ_Toolmaker_load {{file_name ""}} {
	upvar #0 Toolmaker_info info
	if {$file_name == ""} {set file_name [LWDAQ_get_file_name]}
	if {$file_name == ""} {return ""}
	set f [open $file_name r]
	set contents [read $f]
	close $f
	set clist [list]
	set index 0
	while {[regexp -start $index <script> $contents match]} {
		set i_start [string first "<script>" $contents $index]
		set i_end [string first "</script>" $contents $index]
		if {$i_start < 0} {break}
		if {$i_end < 0} {break}
		set field \
			[string range $contents \
				[expr $i_start + [string length "<script>"]] \
				[expr $i_end - 1]]
		set index [expr $i_end + [string length "</script>"]]
		lappend clist $field
	}
	if {[llength $clist] == 0} {
		set clist [list $contents]
	}
	foreach c $clist {lappend info(scripts) [string trim $c]}
	set info(scripts) [lrange $info(scripts) end-$info(max_scripts) end]
	set info(script_index) [llength $info(scripts)]
	LWDAQ_Toolmaker_save $info(list_backup)
	LWDAQ_Toolmaker_back
	return $file_name
}

#
# LWDAQ_Toolmaker_delete deletes the current entry from the script list.
#
proc LWDAQ_Toolmaker_delete {} {
	upvar #0 Toolmaker_info info
	set info(scripts) [lreplace $info(scripts) $info(script_index) $info(script_index)]
	$info(text) delete 1.0 end
	if {$info(script_index) > 0} {
		set info(script_index) [expr $info(script_index) - 1]
		LWDAQ_print $info(text) [lindex $info(scripts) $info(script_index)]
	}
	LWDAQ_Toolmaker_save $info(list_backup)
	return ""
}

#
# LWDAQ_Toolmaker_delete_all clears all entries from the script list.
#
proc LWDAQ_Toolmaker_delete_all {} {
	upvar #0 Toolmaker_info info
	if {[LWDAQ_button_confirm "Delete all Toolmaker scripts?"] == "no"} {return}
	set info(scripts) [list]
	$info(text) delete 1.0 end
	LWDAQ_Toolmaker_save $info(list_backup)
	return ""
}

#
# LWDAQ_Toolmaker makes a new toplevel window for the Toolmaker. You enter a sequence of
# commands in the text window, and you can execute this sequence, which we call a script,
# with the Execute button. When you press Execute, your script will disappear from the 
# text window, but you can make it re-appear with the Back button. The Toolmaker 
# keeps a list of the scripts you have executed, and allows you to navigate and edit the 
# list with the Forward, Back, and Clear buttons. You can save the list to a file with 
# Save, and read a previously-saved list with Load. The file will contain all your scripts
# delimited by XML-style <script> and </script> marks at the beginning and end of each
# script respectively. For each Execute, Toolmaker creates a new toplevel text window.
# You can print to the lower one (which is intended for results) by referring to it as $t, 
# and using it with a text widget routine like LWDAQ_print, or calling it directly with 
# its TK widget command, $t.
#
proc LWDAQ_Toolmaker {} {
	global LWDAQ_Info
	upvar #0 Toolmaker_info info
	set info(window) ".toolmaker"
	set w $info(window)
	if {[winfo exists $w]} {
		raise $w
		return ""
	}
	toplevel $w
	wm title $w "Toolmaker"
	set info(max_scripts) 40
	set info(scripts) [list]
	set info(script_index) [llength $info(scripts)]
	set info(list_backup) [file join $LWDAQ_Info(scripts_dir) Toolmaker.tcl]

	set f [frame $w.f1]
	pack $f -side top -fill x
	foreach a {Delete_All Delete Save Load} {
		set b [string tolower $a]
		button $f.$b -text $a -command LWDAQ_Toolmaker_$b
		pack $f.$b -side left -expand 1
	}

	set f [frame $w.f2]
	pack $f -side top -fill x
	foreach a {Back Forward Execute Repeat} {
		set b [string tolower $a]
		button $f.$b -text $a -command LWDAQ_Toolmaker_$b
		pack $f.$b -side left -expand 1
	}
	set info(text) [LWDAQ_text_widget $w 80 20 1 1]
	LWDAQ_enable_text_undo $info(text)

	if {[file exists $info(list_backup)]} {
		LWDAQ_Toolmaker_load $info(list_backup)
	}
	
	return ""
}

