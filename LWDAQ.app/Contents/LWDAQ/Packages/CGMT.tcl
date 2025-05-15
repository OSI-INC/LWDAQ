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

# Clear the global CGMT_info array if it already exists.
if {[info exists CGMT_info]} {unset CGMT_info}

# A list of html entities and the unicode characters we want to replace them
# with.
set CGMT_info(replace_entities) {
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

# Text output, defaults to stdout.
set CGMT_info(t) "stdout"

# A list of tags we want to remove
set CGMT_info(remove_tags) {i b}

# The chunk delimiting tags.
set CGMT_info(chunk_tags) {p table ul ol h2 h3}

#
# CGMT_read_url fetch the source html code at a url and return as a single text
# string.
#
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
# CGMT_convert_list takes the body of a list chunk and converts it to markup
# format with dashes for bullets and one list entry on each line. It returns the
# converted chunk body.
#
proc CGMT_convert_list {chunk} {
	global CGMT_info
	
	regsub -all {[\t ]*<li>} $chunk "- " chunk 
	regsub -all {</li>} $chunk "" chunk
	return $chunk
}

#
# CGMT_catalog_chunks takes an html page and makes a list of chunks descriptors.
# Each descriptor consists of a start and end index for the content of the chunk
# and the chunk type. The indices point to the first and last characters within
# the chunk, not including whatever delimiters we used to find the chunk. In the
# case of a paragraph chunk, for example, the indices point to the first and
# last character of the body of the paragraph, between the <p> and </p> tags,
# but not including the tags themselves. The chunk type is the same as the html
# tag we use to find tagged chunks, but is some other name in the case of
# specialized chunks like "date", "figure", and "caption".
#
proc CGMT_catalog_chunks {page} {
	global CGMT_info

	set catalog [list]
	foreach {tag} $CGMT_info(chunk_tags) {
		set index 0
		set start_pattern <$tag\[^>\]*>
		set end_pattern </$tag>
		while {[regexp -indices -start $index $start_pattern $page i_open]} {
			set i_body_first [expr [lindex $i_open 1] + 1] 
			if {[regexp -indices -start $i_body_first $end_pattern $page i_close]} {
				set i_body_end [expr [lindex $i_close 0] - 1]
				set index [expr [lindex $i_close 1] + 1]
			} else {
				set i_body_end [string length $page]
				set index [expr $i_body_end + 1]
			}
			set chunk "$i_body_first $i_body_end $tag"
			lappend catalog $chunk
		}
	}
	
	
	set catalog [lsort -increasing -integer -index 0 $catalog]
	
	foreach chunk $catalog {
		switch [lindex $chunk 2] {
			"p" {set color orange}
			"ul" {set color green}
			"ol" {set color green}
			"h2" {set color blue}
			"h3" {set color brown}
			"table" {set color cyan}
			"figure" {set color pink}
			"date" {set color darkgreen}
			"caption" {set color darkred}
			default {set color black}
		}
		LWDAQ_print $CGMT_info(t) $chunk $color	
	}
	
	return $catalog
}

proc CGMT_extract_chunks {page catalog base_url} {
	global CGMT_info
	set chunks [list]
	foreach desc $catalog {
		scan $desc %d%d%s i_start i_end name
		set chunk [string range $page $i_start $i_end]

		set chunk [CGMT_convert_entities $chunk]
		set chunk [CGMT_resolve_urls $base_url $chunk]
		set chunk [CGMT_convert_urls $chunk]
		
		switch $name {
			"ol" {set chunk [CGMT_convert_list $chunk]}
			"ul" {set chunk [CGMT_convert_list $chunk]}
			"h2" {set chunk "Chapter: $chunk"}
			"h3" {set chunk "Section: $chunk"}
		}
		
		lappend chunks $chunk
	}
	return $chunks
}

#
# CGMT_convert_entities converts html entities to unicode characters and returns
# the converted chunk.
#
proc CGMT_convert_entities {chunk} {
	global CGMT_info
    foreach {entity char} $CGMT_info(replace_entities) {
        regsub -all $entity $chunk $char chunk
    }
    return $chunk
}

#
# CGMT_remove_tags removes the html markup tags we won't be using from our a
# chunk of text and returnes the cleaned chunk.
#
proc CGMT_remove_tags {chunk} {
	global CGMT_info
    foreach {tag} $CGMT_info(remove_tags) {
        regsub -all "<$tag>|</$tag>" $chunk "" chunk
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
	set index 0
	set new_chunk ""
	while {[regexp -indices -start $index {<a href="([^"]+)"[^>]*>} $chunk a url]} {
		append new_chunk [string range $chunk $index [expr [lindex $a 0] - 1]]
		set url [string range $chunk {*}$url]
		if {![regexp {https?} $url match]} {
			set url [CGMT_resolve_relative_url $base $url]
		}
		append new_chunk "<a href=\"$url\">"
		set index [expr [lindex $a 1] + 1]
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

#
# A complete chunk extractin process that reports to a text widget or stdout and
# writes chunks to a file.
#
proc CGMT_run {} {
	global CGMT_info
	set url "http://opensourceinstruments.host/Electronics/A3017/SCT.html"
	set base_url "https://www.opensourceinstruments.com/Electronics/A3017"
	LWDAQ_print $CGMT_info(t) "Requesting $url\."
	set page [CGMT_read_url $url]
	LWDAQ_print $CGMT_info(t) "Downloaded [string length $page] bytes."
	set catalog [CGMT_catalog_chunks $page]
	set chunks [CGMT_extract_chunks $page $catalog $base_url]
	LWDAQ_print $CGMT_info(t) "Extracted [llength $chunks] chunks."
	set f [open ~/Desktop/converted.txt w]
	foreach chunk $chunks {
		puts $f "$chunk\n"
	}
	close $f
	LWDAQ_print $CGMT_info(t) "Done"
}

