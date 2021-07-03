# Neruoarchiver.tcl, Interprets, Analyzes, and Archives Data from 
# the LWDAQ Recorder Instrument. It is a Polite LWDAQ Tool.
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

#
# The Neuroarchiver records signals from Subcutaneous Transmitters 
# manufactured by Open Source Instruments. For detailed help, see:
#
# http://www.opensourceinstruments.com/Electronics/A3018/Neuroarchiver.html
#
# The Neuroarchiver uses NDF (Neuroscience Data Format) files to store
# data to disk. It provides play-back of data stored on file, with signal
# plotting and processing.
#

cd $LWDAQ_Info(program_dir)
set ch [open "| [info nameofexecutable]" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
puts $ch "source LWDAQ.app/Contents/LWDAQ/Init.tcl"
puts $ch "package require SCT"
puts $ch "Neuroarchiver_init R"
puts $ch "Neuroarchiver_open"
puts $ch "puts Done"
set waiting 1
set start_time [clock milliseconds]
while {$waiting} {
	while {[gets $ch line] < 0} {
		LWDAQ_support
		if {[clock milliseconds] > $start_time + 20000} {
			error "Failed to launch Neurorecorder."
		}	
	}
	if {[regexp "Done" $line match]} {
		puts "The Neurorecorder has been launched."
		set waiting 0
	}
	puts $line
}
close $ch
	
return 1

----------Begin Help----------

http://www.opensourceinstruments.com/Electronics/A3018/Neuroarchiver.html

----------End Help----------
