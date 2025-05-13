# Chunk Generator and Management Tools Package
# 
# (C) 2025, Kevan Hashemi, Open Source Instruments Inc.
#
# Routines that translate HTML documents into lists of document chunks suitable
# for large language models to transform into embed vectors, submit chunks to
# embedding end point, and return answers from the chat completions endpoint.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place - Suite 330, Boston, MA  02111-1307, USA.
#

# V0.1 [12-MAY-25] Create document and assign name.

# Load this package or routines into LWDAQ with "package require EDF".
package provide CGMT 0.1

# Clear the global CGMT array if it already exists.
if {[info exists CGMT]} {unset CGMT}

# Fill the html entity array. We use this array to convert html entities into
# unicode characters.
array set CGMT_html_entities {
    &mu; "μ"
    &plusmn; "±"
    &div; "÷"
    &amp; "&"
    &nbsp; " "
    &Omega; "Ω"
    &beta; "ß"
    &pi; "π"
    &lt; "<"
    &gt; ">"
    &le; "≤"
    &ge; "≥"
    &asymp; "≈"
    &infin; "∞"
    &times; "×"
    &deg; "°"
    &minus; "−"
    <i> ""
    </i> ""
    <b> ""
    </b> ""
}

#
#
#
proc CGMT_read_file {{fn ""}} {
	if {$fn == ""} {
		set fn [LWDAQ_get_file_name]
	}
	if {![file exists $fn]} {
		return ""
	}
	set f [open $fn]
	set contents [read $f]
	close $f
	return $contents
}

#
#
#
proc CGMT_convert_entities {text} {
	global CGMT_html_entities
    foreach {entity char} [array get CGMT_html_entities] {
        regsub -all $entity $text $char text
    }
    return $text
}

#
#
#
proc CGMT_convert_anchors {text} {
	regsub -all {<a href="([^"]+)"[^>]*>([^<]+)</a>} $text {[\2](\1)} text
	return $text
}

#
#
#
proc CGMT_extract_paragraphs {text} {
	set paragraphs [LWDAQ_xml_get_list $text "p"]
	return $paragraphs
}

