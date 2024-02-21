# Printed Circuit Board Netlist (PCBNL), a LWDAQ Package
#
# Copyright (C) 2005-2021 Kevan Hashemi, Brandeis University
# Copyright (C) 2022-2024 Kevan Hashemi, Open Source Instruments Inc.
#
# Formats netlists produced by Traxmaker or Kicad, producing a human-readable
# list that we can use to cross-check a hand-drawn schematic against its
# transcribed digital schematic, or against a layout. The PCBNL package began as
# a non-standard LWDAQ Tool. Now it provides a command that accepts a file name
# or browses for a file, reads the file in, and tries to parse the file into a
# list of nets that includes component pads but no vias. The output file will be
# named after the folder enclosing the netlist, with suffix _PCBNL and extension
# ".txt".
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <https://www.gnu.org/licenses/>.

# Load this package or routines into LWDAQ with "package require EDF".
package provide PCBNL 3.1

# Clear the global EDF array if it already exists.
if {[info exists PCBNL]} {unset PCBNL}

# Initialize the PCBNL global array.
set PCBNL(infile_name) ""
set PCBNL(outfile_name) ""
set PCBNL(netlist_type) "traxmaker"
set PCBNL(netlist_types) "traxmaker kicadschematic kicadpcbnew"

proc PCBNL_get_files {} {
	global PCBNL
	set fn [LWDAQ_get_file_name]
	if {$fn == ""} {return ""}
	set PCBNL(infile_name) $fn
	set nfn [file root [file direname $]_Compact[file extension $fn]]
}

proc PCBNL_get_type {} {
	
}


# Detect Kicad or Traxmaker by looking for the keyword "(export" written only by
# Kicad. 
proc PCBNL_do {} {

	if {[regexp {\(export} $contents]} {
		# Reformat Kicad netlist. We remove the component library, find the netlist,
		# eliminate verbiage and try to put each net on one line.
		set found [regexp {nets(.*)} $contents match nets]
		if {!$found} {
			error "File contains \"export\" keyword, but not \"(nets\"."
		}
		set nets [split [string trim $nets] \n]
		set contents ""
		set net ""
		set nodes "0"
		foreach line $nets {
			if {[regexp {[ ]*\(net.*?\(name ([^\n]*)} $line match name]} {
				if {$nodes > 1} {append contents "$net \n"}
				set name [regsub -all {\)|/|.+?\(|"} $name ""]
				set net "NET: \"$name\" "
				set nodes "0"
			} elseif {[regexp {[ ]+\(node.*?\(ref ([^\)]*)\).+?\(pin ([^\)]*)\)} \
					$line match part pin]} {
				append net "$part-$pin "
				incr nodes
			}
		}
		if {$nodes > 1} {append contents $net}
		set f [open $nfn w]
		puts $f $contents
		close $f
	} else {
		# For Traxmaker netlists, we replace all carriage returns with spaces, then
		# insert carriage returns before parentheses and brackets.
		set contents [regsub -all {\n} $contents " "]
		set contents [regsub -all {\[} $contents "\n\["]
		set contents [regsub -all {\(} $contents "\n\("]

		# Write the new netlist to disk, but don't overwrite the old netlist.
		set f [open $nfn w]
		puts $f $contents
		close $f

		# Try to find the tool list and drill file.
		set tfn [file root $fn].TOL
		set dfn [file root $fn].TXT
		if {[file exists $tfn] && [file exists $tfn]} {
			set f [open $dfn r]
			set drill [read $f]
			close $f
			set drill [regsub {M48.*?%} $drill ""]
			set f [open $tfn r]
			set tool [read $f]
			close $f
			set tool [regsub {\-.*-\n} $tool ""]
			set newdrill "M48\nINCH\n"
			foreach {tn dia} $tool {
				append newdrill "[set tn]C00.[format %03d $dia]\n"
			}
			append newdrill "%\n"
			append newdrill [string trim $drill]
			set f [open $dfn w]
			puts $f $newdrill
			close $f
		} 
	}
}