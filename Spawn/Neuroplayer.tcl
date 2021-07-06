# Neruoplayer.tcl spawns a child process containing the player section
# of the Neuroarchiver Tool.
#
# Copyright (C) 2007-2021 Kevan Hashemi, Open Source Instruments Inc.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

cd $LWDAQ_Info(program_dir)
set ch [open "| [info nameofexecutable]" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
lappend LWDAQ_Info(children) "$ch Neuro-Recorder"
puts "Child process initialized, using channel $ch\."
puts $ch {if {![info exists LWDAQ_Info]} {source LWDAQ.app/Contents/LWDAQ/Init.tcl}}
puts $ch {destroy .menubar.instruments}
puts $ch {destroy .menubar.tools}
puts $ch {destroy .menubar.spawn}
puts $ch {set Neuroarchiver_mode Player}
puts $ch {LWDAQ_run_tool Neuroarchiver.tcl}
puts $ch {puts "Child Neuro-Player running."}
return "SUCCESS"
