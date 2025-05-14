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

# A list of html entities and the unicode characters we want to replace them
# with.
set CGMT(html_entities) {
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
}

# A list of tags we want to remove
set CGMT(html_tags) {i b}

#
# CGMT_read_url fetch the source html code at a url and return as a single text
# string.

proc CGMT_read_url {url} {
	set page [LWDAQ_url_download $url]
	return $page
}
 
#
# CGMT_read_file reads an html file from a file and return as a single text
# string.
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
# CGMT_extract_paragraphs extract all the paragraphs marked by p tags and returns
# them as a list with the p-tags removed.
#
proc CGMT_extract_paragraphs {chunk} {
	set result [list]
	set index 0
	while {[regexp -indices -start $index {<p[^>]*>} $chunk start_tag opt]} {
		set p_start [expr [lindex $start_tag 1] + 1]
		if {[regexp -indices -start $index {</p>} $chunk end_tag]} {
			set p_end [expr [lindex $end_tag 0] - 1]
			set p_next [expr [lindex $end_tag 1] + 1]
		} else {
			set p_end [string length $chunk]
			set p_next [expr [string length $chunk] + 1]
		}
		
		set field [string range $chunk $p_start $p_end]
		set index $p_next
		lappend result $field
	}
	return $result
}

#
# CGMT_convert_entities converts html entities to unicode characters and returns
# the converted chunk.
#
proc CGMT_convert_entities {chunk} {
	global CGMT
    foreach {entity char} $CGMT(html_entities) {
        regsub -all $entity $chunk $char chunk
    }
    return $chunk
}

#
# CGMT_remove_tags removes the html markup tags we won't be using from our
# a chunk of text and returnes the cleaned chunk.
#
proc CGMT_remove_tags {chunk} {
	global CGMT
    foreach {tag} $CGMT(html_tags) {
        regsub -all <$tag>|</$tag> $chunk "" chunk
    }
    return $chunk
}

#
# CGMT_resolve_relative_url takes a relative url and resolves it into an
# absolute url using a supplied base url. This routine was provided by ChatGPT
# and works perfectly.
#
proc CGMT_resolve_relative_url {base_url relative_url} {

    # Extract the path part from the base URL
    regexp {^(https?://[^/]+)(/.*)$} $base_url -> domain base_path

    # Convert base path to a list for manipulation
    set base_parts [split $base_path "/"]

    # Remove the last element if it's empty (trailing slash)
    if {[lindex $base_parts end] eq ""} {
        set base_parts [lrange $base_parts 0 end-1]
    }

    # Process relative navigation
    foreach part [split $relative_url "/"] {
        switch -- $part {
            ".." {
                # Go up one directory
                set base_parts [lrange $base_parts 0 end-1]
            }
            "." {
                # Stay in the current directory, do nothing
            }
            default {
                # Go into a sub-directory or file
                lappend base_parts $part
            }
        }
    }

    # Reconstruct the absolute URL
    return "$domain[join $base_parts "/"]"
}

#
# CGMT_resolve_urls resolves all the relative urls in a chunk into absolute urls
# using the base url we pass in as the basis for resolution. It constructs a new
# chunk with the absolute urls. It calls CGMT_resolve_relative_url on each
# relative url it finds.
#
proc CGMT_resolve_urls {base chunk} {
	global t
	set index 0
	set new_chunk ""
	while {[regexp -indices -start $index \
			{<a href="([^"]+)"[^>]*>} \
			$chunk anchor url]} {
		append new_chunk [string range $chunk $index [expr [lindex $anchor 0] - 1]]
		set url [string range $chunk [lindex $url 0] [lindex $url 1]]
		if {![regexp {https?} $url match]} {
			set url [CGMT_resolve_relative_url $base $url]
		}
		append new_chunk "<a href=\"$url\">"
		set index [expr [lindex $anchor 1] + 1]
	}
	append new_chunk [string range $chunk $index end]
	return $new_chunk
}

#
# CGMT_convert_urls finds all the anchors in a chunk and converts from html to
# markup format, where the title of the anchor is in brackets and the url is in
# parentheses immediately afterwards.
#
proc CGMT_convert_urls {chunk} {
	regsub -all {<a href="([^"]+)"[^>]*>([^<]+)</a>} $chunk {[\2](\1)} chunk
	return $chunk
}


