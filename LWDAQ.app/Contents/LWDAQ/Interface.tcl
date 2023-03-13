# Long-Wire Data Acquisition Software (LWDAQ)
# Copyright (C) 2004-2020 Kevan Hashemi, Brandeis University
# Copyright (C) 2022-2023 Kevan Hashemi, Open Source Instruments Inc.
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
# Interface.tcl creates the LWDAQ graphical user interface.
#

#
# LWDAQ_interface_init initializes the interface routines, installs
# operating-system dependent event handlers, and configures the default fonts
# for the graphical user interface.
#
proc LWDAQ_interface_init {} {
	global LWDAQ_Info LWDAQ_server_line
	
	set LWDAQ_Info(monitor_ms) 100
	
	set LWDAQ_Info(server_address_filter) "127.0.0.1"
	set LWDAQ_Info(server_listening_port) "1090"
	set LWDAQ_Info(server_listening_sock) "none"
	set LWDAQ_Info(server_control) "Stop"
	set LWDAQ_Info(server_mode) "execute"
	set LWDAQ_server_line ""
		
	set LWDAQ_Info(default_to_stdout) 0
	set LWDAQ_Info(error_color) red
	set LWDAQ_Info(warning_color) blue
	set LWDAQ_Info(suggestion_color) green
	set LWDAQ_Info(numbered_colors) "red green blue orange yellow\
		magenta brown salmon LightSlateBlue black gray40 gray60 maroon\
		green4 blue4 brown4"

	if {!$LWDAQ_Info(gui_enabled)} {return ""}

	if {($LWDAQ_Info(os) == "MacOS") && $LWDAQ_Info(gui_enabled)} {
		font configure TkTextFont -size 14 -family Helvetica -weight normal
		font configure TkDefaultFont -size 14 -family Helvetica -weight normal
		font configure TkFixedFont -size 14 -family Courier -weight normal
		font configure TkMenuFont -size 14 -family Helvetica -weight normal
		font configure TkCaptionFont -size 14 -family Helvetica -weight normal
		proc tk::mac::OpenDocument {args} {
			foreach f $args {
				LWDAQ_post [list LWDAQ_open_document $f]
			}
		}
		proc ::tk::mac::ShowPreferences {} {
			LWDAQ_preferences
		}
		proc ::tk::mac::ShowHelp {} {
			LWDAQ_url_open \
				http://alignment.hep.brandeis.edu/Electronics/LWDAQ/Manual.html		
		}
		proc ::tk::mac::Quit {} {LWDAQ_quit}
		proc tkAboutDialog {} {LWDAQ_about}
	}
	if {($LWDAQ_Info(os) == "Linux") && $LWDAQ_Info(gui_enabled)} {
		font configure TkTextFont -size 10
		font configure TkDefaultFont -size 10
		font configure TkFixedFont -size 11 -family Courier
		font configure TkMenuFont -size 10
		font configure TkCaptionFont -size 10
		proc tkAboutDialog {} {LWDAQ_about}
	}
	if {($LWDAQ_Info(os) == "Windows") && $LWDAQ_Info(gui_enabled)} {
		font configure TkTextFont -size 10 -family Helvetica -weight normal
		font configure TkDefaultFont -size 10 -family Helvetica -weight bold
		font configure TkFixedFont -size 10 -family Courier -weight bold
		font configure TkMenuFont -size 12 -family Helvetica -weight normal
		font configure TkCaptionFont -size 10 -family Helvetica -weight normal
		wm iconbitmap . -default $LWDAQ_Info(contents_dir)/Windows/LWDAQ.ico
		proc tkAboutDialog {} {LWDAQ_about}
	}
	
	LWDAQ_init_main_window	
	LWDAQ_bind_command_key all q [list exit]
	LWDAQ_bind_command_key all w "destroy \[winfo toplevel %W\]"
	
	return ""
}

#
# LWDAQ_init_main_window initialize the main window and defines 
# the menubar.
#
proc LWDAQ_init_main_window {} {
	upvar #0 LWDAQ_Info info
	if {!$info(gui_enabled)} {return ""}

	# Give a title to the main window
	wm title . $info(program_name)

	# Create a new menubar for the main window
	set info(menubar) ".menubar"
	set m $info(menubar)
	catch {destroy $m}
	menu $m
	. config -menu $m

	if {$info(os) == "MacOS"} {
		# On MacOS, set up the preferences section of the program menu.
		set info(program_menu) $m.apple
	} {
		# On Windows and Linux, create a new program menu for the main 
		# window menubar, and add About and Preferences.
		set info(program_menu) $m.program
		catch {destroy $info(program_menu)}
		menu $info(program_menu) -tearoff 0
		$m add cascade -menu $info(program_menu) -label "LWDAQ"
		$info(program_menu) add command -label "About $info(program_name)" \
			-command LWDAQ_about	
		$info(program_menu) add command -label "Preferences" \
			-command LWDAQ_preferences	
		$info(program_menu) add command -label "Quit" -command LWDAQ_quit
	}

	# Create the File menu
	set info(file_menu) $m.file 
	catch {destroy $info(file_menu)}
	menu $info(file_menu) -tearoff 0
	$m add cascade -menu $info(file_menu) -label "File"
	if {$info(slave_console)} {
		$info(file_menu) add command -label "Show Console" -command "console show"
		$info(file_menu) add command -label "Hide Console" -command "console hide"	
		$info(file_menu) add separator
	}
	$info(file_menu) add command -label "System Server" -command LWDAQ_server_open
	$info(file_menu) add command -label "System Monitor" -command LWDAQ_monitor_open
	$info(file_menu) add command -label "System Reset" -command LWDAQ_reset
	$info(file_menu) add command -label "Save Settings" -command LWDAQ_save_settings
	$info(file_menu) add command -label "Unsave Settings" -command LWDAQ_unsave_settings

	# Create the Instrument menu
	LWDAQ_make_instrument_menu

	# Create the Tool menu
	LWDAQ_make_tool_menu
	
	# Create the Help menu.
	set info(help_menu) $m.help 
	catch {destroy $info(help_menu)}
	menu $info(help_menu) -tearoff 0
	$m add cascade -menu $info(help_menu) -label "Help"
	$info(help_menu) add command -label "User Manual" -command \
		{LWDAQ_url_open http://bndhep.net/Electronics/LWDAQ/Manual.html}
	$info(help_menu) add command -label "Command Reference" -command \
		{LWDAQ_url_open http://bndhep.net/Electronics/LWDAQ/Commands.html}
	$info(help_menu) add command -label "Software Download" -command \
		{LWDAQ_url_open http://bndhep.net/Software/Download}
	$info(help_menu) add command -label "BNDHEP" -command \
		{LWDAQ_url_open http://bndhep.net/}
	$info(help_menu) add command -label "Open Source Instruments" -command \
		{LWDAQ_url_open http://www.opensourceinstruments.com}

	# Set up the main window.
	catch {destroy .frame}
	frame .frame
	pack .frame -side top -fill x
	button .frame.quit -text "Quit" -command "LWDAQ_quit" -padx 20 -pady 5
	switch $info(os) {
		"MacOS" {pack .frame.quit -side left -expand 1 -padx 100 -pady 20}
		"Linux" {pack .frame.quit -side left -expand 1 -padx 160 -pady 20}
		"Windows" {pack .frame.quit -side left -expand 1 -padx 160 -pady 20}
		default {pack .frame.quit -side left -expand 1 -padx 100 -pady 20}
	}

	return ""	
}

#
# LWDAQ_about creates a message box that pops up and tells us 
# about the program.
#
proc LWDAQ_about {} {
	upvar #0 LWDAQ_Info info
	
	set w .lwdaq_about
	if {[winfo exists $w]} {focus $w.b; return ""}
	toplevel $w
	wm title $w "About $info(program_name)"
	set f [frame $w.frame1 -padx 20 -pady 10]
	pack $f -side top
	set p [image create photo]
	label $f.lwdaq -image $p
	$p read [file join $info(contents_dir) Resources LWDAQ.gif] -format GIF
	pack $f.lwdaq -fill x -expand 1
	label $f.declare -text "\
		$info(program_name) $info(program_patchlevel),\
		TclTk $info(tcl_version), $info(os) $info(arch)\n\n \
		Copyright 2003-2021, Kevan Hashemi, Brandeis University\n \
		Copyright 2006-2023, Kevan Hashemi, Open Source Instruments Inc.\n\n \
		Distributed under GNU Public License (GPL).\n \
		This program is free and comes with absolutely no warranty." \
		-pady 5
	pack $f.declare -side top -expand 1
	set f [frame $w.frame2 -padx 20 -pady 10]
	pack $f -side top -expand 1 -fill x
	button $f.gpl -text "View GPL License" -padx 20 -pady 5 \
		-command "LWDAQ_view_text_file [file join $info(scripts_dir) License.txt]" 
	button $f.okay -text "OK" -padx 20 -pady 5 \
		-command "destroy $w" 
	pack $f.gpl $f.okay -side left -expand 1
	raise $w
	return ""
}

#
# LWDAQ_preferences opens a window with all the LWDAQ_Info settings. It returns
# the name of a custom frame in which we can put additional widgets.
#
proc LWDAQ_preferences {} {
	upvar #0 LWDAQ_Info info
	set num_columns 3
	
	# Raise the window if it already exists.
	set w .preferences
	set cf $w.custom
	if {[winfo exists $w]} {
		raise $w
		return $cf
	
	}
	
	# Create the window.
	toplevel $w
	wm title $w "LWDAQ Preferences"
	
	# Create the custom frame.
	frame $cf
	pack $cf -side top -fill x
	
	# Create the frames for the LWDAQ_Info array.
	for {set i 1} {$i <= $num_columns} {incr i} {
		frame $w.f$i
		pack $w.f$i -side left -fill y
	}
	
	set param_list [lsort -dictionary [array names info]]
	set num_rows [expr [llength $param_list] / $num_columns]
	if {[llength $param_list] % $num_columns != 0} {
		set num_rows [expr $num_rows + 1]
	}
	set count 1
	set frame_num 1
	foreach p_name $param_list {
		if {$count > $num_rows} {
			set count 1
			incr frame_num
		}
		set f f$frame_num
		label $w.$f.l$p_name -text $p_name -anchor w 
		entry $w.$f.e$p_name -textvariable LWDAQ_Info($p_name) \
			-relief sunken -bd 1 -width 25
		grid $w.$f.l$p_name $w.$f.e$p_name -sticky news
		incr count
	}
	
	return $cf
}

#
# LWDAQ_save_settings saves the library settings and a selection of other core 
# LWDAQ settings to disk.
#
proc LWDAQ_save_settings {} {
	upvar #0 LWDAQ_Info info

	set f [open [file join $info(config_dir) "Core_Settings.tcl"] w]
	foreach i "max_daq_attempts num_daq_errors num_lines_keep queue_ms daq_wait_ms \
			blocking_sockets lazy_flush tcp_timeout_ms support_ms update_ms \
			lwdaq_client_port default_to_stdout server_address_filter \
			server_listening_port close_delay_ms scheduler_increment \
			scheduler_log scheduler_window debug_log instrument_counter_max \
			line_purge_period" {
		puts $f "set LWDAQ_Info($i) \"[set info($i)]\""
	}
	puts $f "lwdaq_config [lwdaq_config]"
	close $f
	return ""
}

#
# LWDAQ_unsave_settings deletes any existing core settings file.
#
proc LWDAQ_unsave_settings {} {
	upvar #0 LWDAQ_Info info

	set fn [file join $info(config_dir) "Core_Settings.tcl"]
	if {[file exists $fn]} {file delete $fn}
	return ""
}


#
# LWDAQ_make_tool_menu destroys the current tool menu and makes a new one that
# matches the current selection of tools in the Tools, More, and Spawn
# directories.
#
proc LWDAQ_make_tool_menu {} {
	upvar #0 LWDAQ_Info info

	# Install the tool menu in the menu bar.
	set info(tool_menu) $info(menubar).tools
	set m $info(tool_menu)
	catch {destroy $m}
	menu $m -tearoff 0
	$info(menubar) add cascade -menu $m -label "Tool"
	$m add command -label "Run Tool" -command \
		[list LWDAQ_post LWDAQ_run_tool front]
	$m add command -label "Edit Script" -command \
		[list LWDAQ_post "LWDAQ_edit_script Open"]
	$m add command -label "New Script" -command \
		[list LWDAQ_post "LWDAQ_edit_script New"]
	$m add command -label "Toolmaker" -command \
		[list LWDAQ_post LWDAQ_Toolmaker front]

	# Create the spawn submenu using all files in the Spawn directory.
	set spawn_files [glob -nocomplain [file join $info(spawn_dir) *.tcl]]
	if {[llength $spawn_files] != 0} {
		$m add separator
		set spawn_tools [list]
		foreach sfn $spawn_files {
			lappend spawn_tools [lindex [split [file tail $sfn] .] 0]
		}
		set spawn_tools [lsort -dictionary $spawn_tools]
		foreach tool $spawn_tools {
			$m add command -label $tool -command \
				[list LWDAQ_post [list LWDAQ_spawn_tool $tool] front]
		}
	}

	# Create the main run submenu using all files in the Tools directory.
	set files [glob -nocomplain [file join $info(tools_dir) *.tcl]]
	if {[llength $files] != 0} {
		set tools ""
		foreach t $files {lappend tools [file tail $t]}
		set tools [lsort -dictionary $tools]
		$m add separator
		foreach t $tools {
			set menu_name [lindex [split $t .] 0]
			set file_name [file join $info(tools_dir) $t]
			$m add command -label $menu_name -command \
				[list LWDAQ_post [list LWDAQ_run_tool $file_name] front]
		}
	}

	# Create the more submenu using files in the More directory.
	set allsubdirs [glob -nocomplain -types d [file join $info(tools_dir) *]]
	set toolsubdirs ""
	if {[llength $allsubdirs] != 0} {
		foreach d $allsubdirs {
			if {[llength [glob -nocomplain [file join $d *.tcl]]] != 0} {
				if {($d != [file join $info(tools_dir) Data]) \
					&& ($d != [file join $info(tools_dir) Spawn])} {lappend toolsubdirs $d}
			}
		}
	}
	if {[llength $toolsubdirs] != 0} {
		set tooldirs ""
		foreach d $toolsubdirs {lappend tooldirs [file tail $d]}
		set tooldirs [lsort -dictionary $tooldirs]
		foreach d $tooldirs {
			set menu_name [string map {_ \ } [lindex [split $d .] 0]]
			set menu_widget [string tolower [lindex [split $d .] 0]]
			$m add cascade -label $menu_name -menu $m.$menu_widget
			set mm [menu $m.$menu_widget -tearoff 0]
			set files [glob -nocomplain [file join $info(tools_dir) $d *.tcl]]
			set tools ""
			foreach t $files {lappend tools [file tail $t]}
			set tools [lsort -dictionary $tools]
			foreach t $tools {
				set menu_name [lindex [split $t .] 0]
				set file_name [file join $info(tools_dir) $d $t]
				$mm add command -label $menu_name -command \
					[list LWDAQ_post [list LWDAQ_run_tool $file_name] front]
			}
		}
	}

	# Done.
	return ""
}

#
# LWDAQ_make_instrument_menu destroys the current instrument menu and
# makes a new one that matches the current list of instruments.
#
proc LWDAQ_make_instrument_menu {} {
	upvar #0 LWDAQ_Info info
	
	# Install the instrument menu in the menu bar.
	set info(instrument_menu) $info(menubar).instruments
	set m $info(instrument_menu)
	catch {destroy $m}
	menu $m -tearoff 0
	$info(menubar) add cascade -menu $m -label "Instrument"
	
	# Add entries for each instrument in the instrument folder.
	foreach i $info(instruments) {$m add command -label $i \
		-command [list LWDAQ_post [list LWDAQ_open $i] front]}
		
	# Add entry to stop all instruments from looping.
	$m add separator
	$m add command -label "Reset Counters" -command LWDAQ_reset_instrument_counters
	
	# Done.
	return ""
}

#
# LWDAQ_widget_list returns a list of all existing children of the window or
# widget you pass to the routine. If you pass just ".", then the routine will
# list all existing widgets and windows. The routine calls itself recursively.
#
proc LWDAQ_widget_list {w} {
	set wl [list]
	foreach c [winfo children $w] {
		lappend wl $c
		set wl [concat $wl [LWDAQ_widget_list $c]]
	}
	return $wl
}

#
# LWDAQ_text_widget opens a text window within the specified window frame. The
# text window has its "undo" stack turned off. The text widget is a child of an
# existing window frame "wf", and will be given the name $wf.text, which is
# returned by the routine. By default, the window has a y scrollbar, but no x
# scrollbar. If we have an x scrollbar we turn off the text wrapping. We bind
# the Command-B key to clear the widget of text, and we set the tab size to a
# quarter-inch.
#
proc LWDAQ_text_widget {wf width height {scrolly 1} {scrollx 0}} {
	global LWDAQ_Info

	set t [text $wf.text -relief sunken -border 2 -setgrid 1 \
		-height $height -width $width -wrap word]
	if {$scrolly} {
		$t configure -yscrollcommand "$wf.vsb set"
		set vsb [scrollbar $wf.vsb -orient vertical -command "$t yview"]
		pack $vsb -side right -fill y
	}
	if {$scrollx} {
		$t configure -xscrollcommand "$wf.hsb set"
		set hsb [scrollbar $wf.hsb -orient horizontal -command "$t xview"]
		pack $hsb -side bottom -fill x
		$t configure -wrap none
	}
	pack $t -expand yes -fill both
	LWDAQ_bind_command_key $t b [list $t delete 1.0 end]
	$t configure -tabs "0.25i left"
	$t configure -undo 0
	return $t
}

#
# LWDAQ_enable_text_undo turns on a text widget's undo stack. This
# stack will consume memory as it gets larger, so you should leave
# the stack off when you are repeatedly and automatically updating
# the text window contents, as we do in the System Monitor or the
# Acquisifier windows.
#
proc LWDAQ_enable_text_undo {t} {
	$t configure -undo 1 -autosep 1
	return ""
}

#
# LWDAQ_print prints a string to the end of a text device. The text device can
# be a text window or a file. When the routine writes to a text window, it does
# so in a specified color, unless the string begins with "ERROR: ", "WARNING: ",
# or "SUGGESTION: ", in which case the routine forces the color itself. If you
# pass "-nonewline" as an option after LWDAQ_print, the routine does not add a
# carriage return to the end of the print string. The routine also recognises
# "-newline", which is the default. The routine assumes the text device is a
# text window if its name starts with a period and this period is not followed
# by a forward slash or a backslash. If the text window exists, the routine
# writes the print string to the end of the window. If the text device is either
# "stdout" or "stderr", the routine writes directly to these channels. If the
# text device is a file name and the directory of the file exists, the routine
# appends the string to the file, or creates the file if the file does not
# exist. The routine will not accept any file name that contains a space, is an
# empty string, or is a real number. If the routine cannot find any valid device
# that matches the device name, it will write the string to stdout provided the
# default_to_stdout flag is set. Otherwise the routine does nothing. Another
# service provided by the routine is to replace any double occurrances of ERROR:
# or WARNING: that might arise as we pass error and warning strings through
# various routines before they are printed.
#
proc LWDAQ_print {args} {
	global LWDAQ_Info
	
	set option "-newline"
	if {[string match "-nonewline" [lindex $args 0]]} {
		set option "-nonewline"
		set args [lreplace $args 0 0]
	}
	if {[string match "-newline" [lindex $args 0]]} {
		set args [lreplace $args 0 0]
	}

	set destination [lindex $args 0]

	set print_str [lindex $args 1]
	if {$option == "-newline"} {append print_str \n}

	set color [lindex $args 2]
	if {$color == ""} {set color black}
	if {[regexp {^SUGGESTION: } $print_str]} {
		set color $LWDAQ_Info(suggestion_color)
		set print_str [regsub -all {^SUGGESTION: SUGGESTION: } $print_str {SUGGESTION: }]
	}
	if {[regexp {^WARNING: } $print_str]} {
		set color $LWDAQ_Info(warning_color)
		set print_str [regsub -all {^WARNING: WARNING: } $print_str {WARNING: }]
	}
	if {[regexp {^ERROR: } $print_str]} {
		set color $LWDAQ_Info(error_color)
		set print_str [regsub -all {^ERROR: ERROR: } $print_str {ERROR: }]
	}

	set printed 0
	
	if {([string index $destination 0] == ".") && \
		([string index $destination 1] != "/") && \
		([string index $destination 1] != "\\") } {
		if {$LWDAQ_Info(gui_enabled) && [winfo exists $destination]} {
			catch {
				$destination tag configure $color -foreground $color
			}
			catch {
				$destination insert end $print_str $color
				$destination yview moveto 1
				set printed 1
			}
		}
	} {
		if {($destination == "stdout") || ($destination == "stderr")} {
			if {$LWDAQ_Info(stdout_available)} {
				puts -nonewline $destination $print_str
				set printed 1
			}
		} {
			if {[file exists [file dirname $destination]] \
				&& ![string is double -strict [file tail $destination]]} {
				set f [open $destination a]
				puts -nonewline $f $print_str
				close $f
				set printed 1
			}
		}
	}

	if {!$printed} {
		if {$LWDAQ_Info(stdout_available) && $LWDAQ_Info(default_to_stdout)} {
			puts -nonewline stdout $print_str
		} {
			set destination "null"
		}
	}
	
	return $destination
}

#
# LWDAQ_edit_script creates and controls a text editor window. It returns the
# name of the window. The window provides New, Open, Save, and SaveAs buttons.
# The routine takes a command "cmd" and a text source "src" as input parameters.
# The "Open" command creates a new, empty, editing window. It treats the source
# parameter as a file name. If the named file is an empty string, edit_script
# opens a file browser so the user can select a file, and it reads that file
# into the editing window. Otherwise, if the named file exists, edit_script
# reads the contents of the named file into the editing window. It sets the
# window title equal to the file name. Note that the Open command does not
# create a new file. The "Save" command takes an editor window name as its
# source, and saves the contents of that editor window to the file named in the
# editor window's title. The "SaveAs" command also takes a window as its source
# but opens a browser for the user to choose a destination file. The "New"
# command opens a new editor window with a default file name. It ignores the
# source parameter. In the text editor window, we use command-z to undo,
# command-s to save the text to the title file. The New button in the text
# editor opens a file called Untitled.txt, which we assume does not exist.
# 
proc LWDAQ_edit_script {{cmd "Open"} {src ""}} {
	global LWDAQ_Info
	
	# The default file path and name we construct from the working
	# directory and the LWDAQ new text file name.
	set nft "Untitled.txt"

	if {($cmd == "Open")} {
		# The src parameter is a file name, so change to a better variable name.
		set fn $src
		
		# If the file name is empty, browse for one, and if it's still empty after
		# that, abort.
		if {$fn == ""} {
			set fn [LWDAQ_get_file_name]
			if {$fn == ""} {
				return "ABORTED"
			}
		}
	
		# Create a new editor window with New, Open, Save, and SaveAs buttons.
		set w [LWDAQ_toplevel_window]
		set f [frame $w.bf]
		pack $f -side top -fill x
		button $f.new -text "New" -command [list LWDAQ_edit_script "Open" $nft]
		button $f.open -text "Open" -command [list LWDAQ_edit_script "Open" ""]
		button $f.save -text "Save" -command [list LWDAQ_edit_script "Save" $w]
		button $f.saveas -text "SaveAs" -command [list LWDAQ_edit_script "SaveAs" $w]
		pack $f.new $f.open $f.save $f.saveas -side left -expand yes

		# Make the text window.
		set t [LWDAQ_text_widget $w 100 30 1 1]
		LWDAQ_enable_text_undo $t
		LWDAQ_bind_command_key $t s [list LWDAQ_edit_script Save $w]
		LWDAQ_bind_command_key $t S [list LWDAQ_edit_script SaveAs $w]

		# If the file exists, but is not equal to the default file name, read 
		# the file contents one line at a time. During this read, we have
		# the option to close the editor window and so abort the read, which may
		# be neccessary if we are trying to read a large file.
		if {[file exists $fn] && ($fn != $nft)} {
			$w.text delete 1.0 end
			set f [open $fn r]
			while {[gets $f line] >= 0} {
				LWDAQ_support
				if {![winfo exists $w]} {
					close $f
					return "ERROR: Aborted reading [file tail $fn], editor closed."
				}
				$w.text insert end "$line\n"
			}
			close $f

		# If the file name is the default file name, we add the working directory
		# in front of it now. 
		} elseif {$fn == $nft} {		
			set fn [file join $LWDAQ_Info(working_dir) $fn]

		# The file does not exist, and it is not the default file, so it must be a named
		# file from the command line. If no directory is specified, we make the directory
		# the working directory. 	
		} elseif {[file dirname $fn] == "."} {
			set fn [file join $LWDAQ_Info(working_dir) $fn]
		}
		
		# Set the window title to the file name and return the window name.
		wm title $w $fn
		return $w
	}

	if {$cmd == "Save"} {
	
		# The src parameter is a window, so change to a better variable name and
		# check that the window and the directory of its title file both exist.
		set w $src
		if {![winfo exists $w]} {
			return "ERROR: Editing widow closed, no script to save."
		}
		set fn [wm title $w]
		if {![file exists [file dirname $fn]]} {
			return "ERROR: Directory [file dirname $fn] does not exist."
		}
		
		# Extract the text from the editor window, trimming extra white space
		# on the ends, and write to the named file.
		set script [string trim [$w.text get 1.0 end]]
		set f [open $fn w]
		puts $f $script
		close $f

		# Return the file name.
		return $fn
	}

	if {$cmd == "SaveAs"} {
		# check that the window and the directory of its title file both exist.
		set w $src
		if {![winfo exists $w]} {
			return "ERROR: Editing widow closed, no script to save."
		}

		# We are going to browse for a file name, but we will start with the
		# name in the window title.
		set fn [LWDAQ_put_file_name [file tail [wm title $w]]]	
		if {$fn == ""} {return "ABORT"}
		if {![file exists [file dirname $fn]]} {
			return "ERROR: Directory [file dirname $fn] does not exist."
		}
		
		# Extract the text from the editor window, trimming extra white space
		# on the ends, and write to the named file.
		set script [string trim [$w.text get 1.0 end]]
		set f [open $fn w]
		puts $f $script
		close $f

		# Set the title bare to show the new file name, return the new file name.
		wm title $w $fn
		return $fn
	}
	
	if {$cmd == "New"} {
		# Open a new file by passing the new file tail as the source.
		set w [LWDAQ_edit_script "Open" $nft]
		
		# Return the new window name.
		return $w
	}
	
	return "ERROR: Unrecognised commmand \"$cmd\"."
}

#
# LWDAQ_clock_widget creates a text widget that displays 
# second-by-second current time. If you specify a window name,
# the clock widget will appear in the window, packed towards
# the top. Otherwise the routine creates a new toplevel window
# for the clock.
#
proc LWDAQ_clock_widget {{wf ""}} {
	if {$wf == ""} {
		set wf .[LWDAQ_global_var_name]
		toplevel $wf
		wm title $wf Clock
	} {
		if {![winfo exists $wf]} {return ""}
	}
	if {![winfo exists $wf\.clock]} {
		text $wf.clock -undo 0 -width 30 -height 1
		pack $wf.clock
	}
	$wf.clock delete "end -1 lines" end
	set s [clock format [clock seconds] -format {%c}]
	$wf.clock insert end $s
	LWDAQ_post "LWDAQ_clock_widget $wf"
	return ""
}

#
# LWDAQ_bind_command_key binds the specified command letter to the specified
# command on all platforms. We use the "command" key on MacOS and the "control"
# key on Windows and Linux. If the window is an empty string, we bing the key
# to the root window.
#
proc LWDAQ_bind_command_key {window letter command} {
	upvar #0 LWDAQ_Info info
	if {$window == ""} {set window "."}
	if {$info(os) == "MacOS"} {
		bind $window <Command-KeyPress-$letter> $command
	}
	if {$info(os) == "Linux"} {
		bind $window <Control-KeyPress-$letter> $command
	}
	if {$info(os) == "Windows"} {
		bind $window <Control-KeyPress-$letter> $command
	}
	return ""
}

#
# LWDAQ_set_bg takes the name of a widget and makes sure its background
# color is set to "color". If the background is already "color", the routine
# does nothing. If graphics are disabled, the routine does nothing. This
# routine abbreviates our code, and avoids unnecessary drawing by first 
# checking to see if the background color has already been set to the desired
# value. It is similar to LWDAQ_set_fg.
#
proc LWDAQ_set_bg {widget color} {
	if {[winfo exists $widget]} {		
		if {[$widget cget -bg] != $color} {
			$widget configure -bg $color
			update idletasks
		}
	}
	return ""
}

#
# LWDAQ_set_fg takes the name of a widget and makes sure its foreground color is
# set to "color". If the foreground is already "color", the routine does
# nothing. If graphics are disabled, the routine does nothing. This routine
# abbreviates our code, and avoids unnecessary drawing by first checking to see
# if the foreground color has already been set to the desired value. It is
# similar to LWDAQ_set_bg.
#
proc LWDAQ_set_fg {widget color} {
	if {[winfo exists $widget]} {		
		if {[$widget cget -fg] != $color} {
			$widget configure -fg $color
			update idletasks
		}
	}
	return ""
}

#
# LWDAQ_inside_widget takes a widget name and widget-local x and y coordinate 
# and returns true iff the point (x,y) is inside the widget. There may be an 
# existing TclTk routine for this, but we can't find it.
#
proc LWDAQ_inside_widget {w x y} {
	if {($x >= 0) && ($x < [winfo width $w]) \
		&& ($y >= 0) && ($y < [winfo height $w]) } {
		return 1	
	} {
		return 0
	}
}

#
# LWDAQ_toplevel_window will make a new top-level window with a unique name, and
# returns its name.
#
proc LWDAQ_toplevel_window { {title ""} } {
	set count 0
	set w ".toplevel[incr count]"
	while {[winfo exists $w]} {set w ".toplevel[incr count]"}
	toplevel $w
	if {$title != ""} {wm title $w $title}
	return $w
}

#
# LWDAQ_toplevel_text_window creates a new text window. It returns the name of
# the toplevel window containing the text widget. You can construct the name of
# the text widget itself by adding .text to the window name.
#
proc LWDAQ_toplevel_text_window {{width 84} {height 30}} {
	set w [LWDAQ_toplevel_window]
	set t [LWDAQ_text_widget $w $width $height]
	return $w
}

#
# LWDAQ_save_text_window saves the contents of text window $window_name to a
# file named $file_name.
#
proc LWDAQ_save_text_window {window_name file_name} {
	set f [open $file_name w]
	puts $f [$window_name get 1.0 end]
	close $f
	return ""
}

#
# LWDAQ_view_text_file reads a text file into a new top-level text window. The
# routine returns the name of the top-level window. The name of the text widget
# used to display the file is $w.text, where $w is the top-level window name.
#
proc LWDAQ_view_text_file {file_name} {
	set w [LWDAQ_toplevel_window]
	wm title $w [file tail $file_name]
	set t [LWDAQ_text_widget $w 100 30]
	set f [open $file_name r]
	set contents [read $f]
	close $f
	$w.text insert end $contents
	return $w
}

#
# LWDAQ_Macos_Open_File opens files dropped on the LWDAQ icon in Macos. Our code
# is based upon an example script provided to the MACTCL forum on 28-FEB-07 by
# Jon Guyer. When it opens image files, the routine looks at the first word in
# the image results string. If that word is the name of an Instrument, the
# routine opens the file in that instrument. Otherwise, it opens the file in the
# Viewer instrument.
#
proc LWDAQ_MacOS_Open_File {theAppleEvent theReplyAE} {
	upvar #0 LWDAQ_Info info
	set pathDesc [::tclAE::getKeyDesc $theAppleEvent ----]
	if {[tclAE::getDescType $pathDesc] ne "list"} {
		set pathDesc [::tclAE::coerceDesc $pathDesc list]
	}
	set count [::tclAE::countItems $pathDesc]
	set paths [list]
	for {set item 0} {$item < $count} {incr item} {
	set fileDesc [::tclAE::getNthDesc $pathDesc $item]
	set alisDesc [::tclAE::coerceDesc $fileDesc alis]
		lappend paths [::tclAE::getData $alisDesc TEXT]
	}
	return ""
}

#
# LWDAQ_open_document takes a file name and opens the file according to its file
# extensions. On MacOS, we call this procedure from tk::mac::OpenDocument.
#
proc LWDAQ_open_document {fn} {
	if {[file exists $fn]} {
		set ft [string tolower [file tail $fn]]
		switch -glob -- $ft {
			"*.txt" {
				set w [LWDAQ_toplevel_text_window 80 40]
				wm title $w $fn
				set f [open $fn r]
				set contents [read $f]
				close $f
				$w.text insert end $contents black
			}
			"*.tcl" {
				set script [LWDAQ_read_script $fn]
				if {$script != ""} {uplevel #0 $script}
			}
			default {
				LWDAQ_open Viewer
				upvar #0 LWDAQ_config_Viewer config
				set config(image_source) "file"
				set config(file_name) [list $fn]
				LWDAQ_acquire Viewer
			}
		}
	}	
	return ""
}

#
# LWDAQ_button_wait opens a toplevel window with a continue button
# and waits until the user presses the button before closing the window
# and continuing.
#
proc LWDAQ_button_wait {{s ""}} {
	if {$s == ""} {
		set s "Press OK to Continue"
	} {
		set s "$s\nPress OK to Continue"
	}
	return [tk_messageBox -type ok -title "Wait" -message $s]
}

#
# LWDAQ_button_warning opens a toplevel window called "Warning" and
# prints message $s in the window. The procedure returns after
# the user presses a button.
#
proc LWDAQ_button_warning {s} {
	return [tk_messageBox -type ok -title "Warning" -message "$s"]
}

#
# LWDAQ_button_confirm opens a toplevel window called "Confirm" and
# prints message $s in the window. The procedure returns after
# the user presses a button.
#
proc LWDAQ_button_confirm {s} {
	return [tk_messageBox -type yesno -title "Confirm" -message "$s"]
}

#
# LWDAQ_view_array opens a new window that displays the contents of a
# global TCL array. It and allows you to change the values of all elements 
# in the array.
#
proc LWDAQ_view_array {array_name} {
	upvar #0 $array_name array
	if {![info exists array]} {return ""}
	set w [LWDAQ_toplevel_window "$array_name"]
	frame $w.f1
	frame $w.f2
	pack $w.f1 $w.f2 -side left -fill y
	set array_list [array names array]
	set array_list [lsort -dictionary $array_list]
	set count 0
	set half [expr [llength $array_list] / 2]
	set label_width 0
	foreach l $array_list {
		if {[string length $l] > $label_width} {
			set label_width [string length $l]
		}
	}
	foreach i $array_list {
		incr count
		if {$count > $half} {set f f2} {set f f1}
		label $w.$f.l$i -text $i -anchor w -width $label_width
		entry $w.$f.e$i -textvariable $array_name\($i) \
			-relief sunken -bd 1 -width 30
		grid $w.$f.l$i $w.$f.e$i -sticky news
	}
	return $w
}

#
# LWDAQ_monitor_open opens the system monitor window.
#
proc LWDAQ_monitor_open {} {
	global LWDAQ_Info
	global LWDAQ_lwdaq_config

	if {!$LWDAQ_Info(gui_enabled)} {return ""}

	set w ".monitorwindow"
	if {[winfo exists $w]} {
		raise $w
		return ""
	}
	
	toplevel $w
	wm title $w "LWDAQ System Monitor"
	
	set f [frame $w.b]
	pack $f -side top -fill x
	
	foreach n "Queue_Start Queue_Stop Queue_Clear" {
		set m [string tolower $n]
		set p [string map {_ \ } $n]
		button $f.$m -text $p -command LWDAQ_$m
		pack $f.$m -side left -expand 1
	}
	
	button $f.reset -text "System Reset" -command LWDAQ_reset
	pack $f.reset -side left -expand 1

	button $f.ls -text "Library Settings" -command {LWDAQ_library_settings}
	pack $f.ls -side left -expand yes
	
	frame $w.v
	pack $w.v -side top -fill x
	set f [frame $w.v.left]
	pack $f -side left -fill y
	foreach i "max_daq_attempts num_daq_errors num_lines_keep queue_ms \
			daq_wait_ms scheduler_log" {
		label $f.l$i -text "$i" -anchor w -width 15
		entry $f.e$i -textvariable LWDAQ_Info($i) -relief sunken -bd 1 -width 10
		grid $f.l$i $f.e$i -sticky news
	}
	set f [frame $w.v.center]
	pack $f -side left -fill y
	foreach i "blocking_sockets lazy_flush tcp_timeout_ms support_ms \
			update_ms scheduler_window" {
		label $f.l$i -text "$i" -anchor w -width 15
		entry $f.e$i -textvariable LWDAQ_Info($i) -relief sunken -bd 1 -width 10
		grid $f.l$i $f.e$i -sticky news
	}
	set f [frame $w.v.right]
	pack $f -side left -fill y
	foreach i "lwdaq_client_port default_to_stdout server_address_filter\
			server_listening_port close_delay_ms scheduler_increment" {
		label $f.l$i -text "$i" -anchor w -width 20
		entry $f.e$i -textvariable LWDAQ_Info($i) -relief sunken -bd 1 -width 10
		grid $f.l$i $f.e$i -sticky news
	}
	
	frame $w.current
	pack $w.current
	LWDAQ_text_widget $w.current 90 2 0 0
	frame $w.queue
	pack $w.queue
	LWDAQ_text_widget $w.queue 90 8 0 0
	frame $w.vwaits
	pack $w.vwaits
	LWDAQ_text_widget $w.vwaits 90 4 0 0
	frame $w.sockets
	pack $w.sockets
	LWDAQ_text_widget $w.sockets 90 6 0 0
		
	after $LWDAQ_Info(monitor_ms) LWDAQ_monitor_refresh
	return ""
}

#
# LWDAQ_library_settings allows us to edit the settings used by the analysis
# libraries. These are accessible through the lwdaq_config command. We make
# an array of options and values which the user can edit and then apply.
#
proc LWDAQ_library_settings {} {
	global LWDAQ_Info
	global LWDAQ_lwdaq_config

	set w ".lwdaqconfig"
	if {[winfo exists $w]} {
		raise $w
		return ""
	}
	
	toplevel $w
	wm title $w "Library Settings"
	
	set f [frame $w.buttons]
	pack $f -side top -fill x
	
	button $f.lca -text "Apply" -command {
		set settings ""
		foreach {op val} [lwdaq_config] {
			append settings " $op $LWDAQ_lwdaq_config([string map {- ""} $op])"
		}
		eval lwdaq_config $settings
		foreach {op val} [lwdaq_config] {
			set op [string map {- ""} $op]
			set LWDAQ_lwdaq_config($op) $val
		}
		LWDAQ_print .lwdaqconfig.text "Applied library settings at [LWDAQ_time_stamp],\
			make permanent with Save Settings."
	}
	pack $f.lca -side left -expand 1

	set f [frame $w.parameters]
	pack $f -side top -fill x
	
	set f [frame $w.lwdaq]
	pack $f
	foreach {op val} [lwdaq_config] {
		set op [string map {- ""} $op]
		label $f.l$op -text $op
		entry $f.e$op -textvariable LWDAQ_lwdaq_config($op)
		set LWDAQ_lwdaq_config($op) $val
		grid $f.l$op $f.e$op -sticky nsew
	}
	
	LWDAQ_text_widget $w 90 4 0
	return $w
}

#
# LWDAQ_monitor_refresh updates the system monitor window, if it
# exists, and posts itself for re-execution in the TCL event
# loop.
#
proc LWDAQ_monitor_refresh {} {
	global LWDAQ_Info
	
	set w ".monitorwindow"
	if {![winfo exists $w]} {return ""}
	
	set t $w.current.text
	$t delete 1.0 end
	LWDAQ_print $t "Current Event:" blue
	LWDAQ_print -nonewline $t $LWDAQ_Info(current_event)
 
	set t $w.queue.text	
	$t delete 1.0 end
	LWDAQ_print $t "Event Queue:" blue
	foreach event $LWDAQ_Info(queue_events) {
		LWDAQ_print $t [string range $event 0 200]
	}
	
	set t $w.vwaits.text	
	$t delete 1.0 end
	LWDAQ_print $t "Control Variables:" blue
	foreach var $LWDAQ_Info(vwait_var_names) {
		upvar #0 $var v
		if {[info exists v]} {LWDAQ_print $t "$var = $v"}
	}

	set t $w.sockets.text	
	$t delete 1.0 end
	LWDAQ_print $t "Open Sockets:" blue
	foreach s $LWDAQ_Info(open_sockets) {
		LWDAQ_print $t "$s"
	}

	after $LWDAQ_Info(monitor_ms) LWDAQ_monitor_refresh
	return ""
}

#
# LWDAQ_reset stops all instruments, closes all sockets, stops all vwaits, 
# and the event queue, sets the global reset variable to 1 for a period of 
# time, and then sets all the instrument control variables to Idle.
#
proc LWDAQ_reset {} {
	global LWDAQ_Info
	
	if {$LWDAQ_Info(reset)} {
		if {[llength $LWDAQ_Info(queue_events)] > 0} {
			LWDAQ_post LWDAQ_reset
		} {
			foreach i $LWDAQ_Info(instruments) {
				upvar #0 LWDAQ_info_$i info
				set info(control) "Idle"
			}
			set LWDAQ_Info(reset) 0
		}
	} {
		set LWDAQ_Info(reset) 1
		LWDAQ_stop_instruments
		LWDAQ_stop_vwaits
		LWDAQ_close_all_sockets
		LWDAQ_post LWDAQ_reset
	}
	return $LWDAQ_Info(reset)
}

#
# LWDAQ_server_open opens the remote control window. In the window, you
# specify an IP address match string to filter incoming connection requests.
# You specify the IP port to at whith LWDAQ should listen. You provide match
# strings for the commands that the remote control command interpreter should
# process. When you press Run, the remote controller is running and listening.
# When you press Stop, it stops. You cannot adjust the listening port while
# the remote controller is running.
#
proc LWDAQ_server_open {} {
	global LWDAQ_Info

	if {!$LWDAQ_Info(gui_enabled)} {return ""}

	set w ".serverwindow"
	if {[winfo exists $w]} {
		raise $w
		return ""
	}
	
	toplevel $w
	wm title $w "LWDAQ System Server"
	
	set f [frame $w.b]
	pack $f -side top -fill x
	label $f.control -textvariable LWDAQ_Info(server_control) -width 20 -fg blue
	pack $f.control -side left -expand 1
	foreach n "Start Stop" {
		set m [string tolower $n]
		button $f.$m -text $n -command LWDAQ_server_$m
		pack $f.$m -side left -expand 1
	}

	set f [frame $w.v]
	pack $f -side top -fill x
	foreach i {address_filter listening_port} {
		label $f.l$i -text "$i" -width 10
		entry $f.e$i -textvariable LWDAQ_Info(server_$i) -relief sunken -bd 1 -width 10
		pack $f.l$i $f.e$i -side left
	}
	label $f.lmode -text "mode" -width 10
	tk_optionMenu $f.emode LWDAQ_Info(server_mode) execute echo receive
	pack $f.lmode $f.emode -side left

	LWDAQ_text_widget $w 60 20
	return ""
}

#
# LWDAQ_server_start starts up the remote control server socket.
#
proc LWDAQ_server_start {} {
	upvar #0 LWDAQ_Info info
	set t .serverwindow.text
	if {$info(server_control) == "Run"} {
		LWDAQ_server_stop
	}
	set sock [LWDAQ_socket_listen LWDAQ_server_accept $info(server_listening_port)]
	set info(server_listening_sock) $sock
	set info(server_control) "Run"
	LWDAQ_print -nonewline $t "$sock\: " green
	LWDAQ_print $t "Listening on port $info(server_listening_port)."
	return ""
}

#
# LWDAQ_server_stop stops the remote control server socket, and closes all open
# sockets.
#
proc LWDAQ_server_stop {} {
	upvar #0 LWDAQ_Info info
	set t .serverwindow.text
	LWDAQ_socket_close $info(server_listening_sock)
	LWDAQ_print $t "$info(server_listening_sock) closed." green
	foreach s $info(open_sockets) {
		if {[string match "*server*" $s]} {
			LWDAQ_socket_close [lindex $s 0]
			LWDAQ_print $t "[lindex $s 0] closed." blue
		}
	}
	set info(server_control) "Stop"
	return ""
}

#
# LWDAQ_server_accept is called when a remote control socket opens. The first
# thing the routine does is check that the IP address of the TCPIP client
# matches the server's address_filter. The routine installs the
# LWDAQ_server_interpreter routine as the incoming data handler for the remote
# control socket, and it lists the new socket in the LWDAQ open socket list. If
# succesful, it returns a one, otherwise a zero.
#
proc LWDAQ_server_accept {sock addr port} {
	upvar #0 LWDAQ_Info info
	set t .serverwindow.text
	if {![string match $info(server_address_filter) $addr]} {
		close $sock
		LWDAQ_print $t "Refused connection request from $addr."
		return ""
	} {
		fconfigure $sock -buffering line
		fileevent $sock readable [list LWDAQ_server_interpreter $sock]
		lappend info(open_sockets) "$sock $addr $port basic server"
		LWDAQ_print -nonewline $t "$sock\: " blue
		LWDAQ_print $t "Opened by client $addr\:$port."
		return ""
	}
}

#
# LWDAQ_server_info returns a string giving the name of the specified
# socket. The routine is intended for use within the System Server, where
# we pass the name of a socket to the routine, and it returns the name
# and various other pieces of system information. If, however, you call
# the routine from the console or within a script, it will return the
# same information, but with the socket name set to its default value.
# When you send the command "LWDAQ_server_info" to the System Server 
# over a System Server socket, the System Server calls LWDAQ_server_info
# with the name of this same socket, and so returns the socket name
# along with the system information. The elements returned by the routine
# are a socket number, the time in seconds, the local platform, the 
# program patchlevel, and the TCL version.n
#
proc LWDAQ_server_info {{sock "nosocket"}} {
	upvar #0 LWDAQ_Info info
	return "$sock \
		[clock seconds] \
		$info(os) \
		$info(program_patchlevel) \
		$info(tcl_version)"
}

#
# LWDAQ_server_interpreter receives commands from a TCPIP socket.
#
proc LWDAQ_server_interpreter {sock} {
	upvar #0 LWDAQ_Info info
	global LWDAQ_server_line
	set t .serverwindow.text

	if {[eof $sock]} {
		LWDAQ_socket_close $sock
		LWDAQ_print -nonewline $t "$sock\: " blue
		LWDAQ_print $t "Closed by client." 
		return ""
	}	
	
	if {[catch {gets $sock line} result]} {
		LWDAQ_socket_close $sock
		LWDAQ_print $t "$sock Closed because broken."
		return ""
	}
	
	set line [string trim $line]
	if {$line == ""} {return ""}
	
	if {[string length $line] == 1} {
		binary scan $line c lcode
		binary scan $info(lwdaq_close_string) c ccode
		if {$lcode == $ccode} {
			LWDAQ_socket_close $sock
			LWDAQ_print -nonewline $t "$sock\: " blue
			LWDAQ_print $t "Closed by client."	
			return ""		
		}
	}

	set LWDAQ_server_line $line

	if {[string length $line] > 50} {
		LWDAQ_print -nonewline $t "$sock\: " blue
		LWDAQ_print $t "Read \"[string range $line 0 49]\...\""
	} {
		LWDAQ_print -nonewline $t "$sock\: " blue
		LWDAQ_print $t "Read \"$line\""
	}
	
	set result ""
	
	if {$info(server_mode) == "execute"} {
		if {[string match "LWDAQ_server_info" $line]} {
			append line " $sock"
		}
		
		if {[catch {
			set result [uplevel #0 $line]
		} error_result]} {
			set result "ERROR: $error_result"
		}
	}
	
	if {$info(server_mode) == "echo"} {
		set result $line
	}
	
	if {$result != ""} {
		if {[catch {puts $sock $result} sock_error]} {
			LWDAQ_print -nonewline $t "$sock\: " blue
			LWDAQ_print $t "ERROR: $sock_error"
			LWDAQ_socket_close $sock
			LWDAQ_print -nonewline $t "$sock\: " blue
			LWDAQ_print $t "Closed after fatal socket error."
			return ""
		} {
			if {[string length $result] > 50} {
				LWDAQ_print -nonewline $t "$sock\: " blue
				LWDAQ_print $t "Wrote \"[string range $result 0 49]\...\""
			} {
				LWDAQ_print -nonewline $t "$sock\: " blue
				LWDAQ_print $t "Wrote \"$result\""
			}
			return ""
		}
	}
}

