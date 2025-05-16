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
set CGMT_info(entities_to_convert) {
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
set CGMT_info(tags_to_convert) {
	i ""
	/i ""
	b ""
	/b ""
	br " "
}

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
# CGMT_read_tag looks in a chunk for the first field delimited by the specified tag.
# It returns the start and end indices of the field, not including the tags.
#
proc CGMT_locate_field {chunk tag} {
	set result "0 0"
	if {[regexp -indices <$tag\(| \[^>\]*\)> $chunk match]} {
		set i_start [string first "<$tag>" $xml $index]
		set i_end [string first "</$tag>" $xml $index]
		if {$i_start < 0} {break}
		if {$i_end < 0} {break}
		set field \
			[string range $xml \
				[expr $i_start + [string length "<$tag>"]] \
				[expr $i_end - 1]]
		set index [expr $i_end + [string length "</$tag>"]]
		lappend result $field
	}
	return $result
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
# CGMT_convert_table takes the body of a table chunk and converts it to markup
# format. The routine looks for headings in the first table row, and if it finds them, it will 
# use these to identify every cell in each row of its output.
#
proc CGMT_convert_table {chunk} {
	global CGMT_info
	
	regsub -all {\s*<th>} $chunk "" chunk
	regsub -all {</th>\s*} $chunk " " chunk
	regsub -all {\s*<td>} $chunk "" chunk
	regsub -all {</td>\s*} $chunk " " chunk
	regsub -all {\s*<tr>[\n\t ]*} $chunk "" chunk 
	regsub -all {</tr>\s*} $chunk "\n" chunk
	
	return $chunk
}

#
# CGMT_extract_date takes the body of a date chunk and converts it to a text
# title.
#
proc CGMT_extract_date {chunk} {
	global CGMT_info
	
	if {[regexp {[0-9]{2}-[A-Z]{3}-[0-9]{2}} $chunk date]} {
		set chunk "$date"
	} else {
		set chunk "NONE"
	}

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
		set start_pattern "<$tag\(| \[^>\]*\)\>"
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
	
	set index 0
	set pattern {<p>\[[0-9]{2}-[A-Z]{3}-[0-9]{2}\]}
	while {[regexp -indices -start $index $pattern $page i_p]} {
		set chunk "$i_p date"
		lappend catalog $chunk
		set index [expr [lindex $i_p 1] + 1]
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

#
# CGMT_convert_tags removes the html markup tags we won't be using from a chunk
# of text and returnes the cleaned chunk.
#
proc CGMT_convert_tags {chunk} {
	global CGMT_info
    foreach {tag replace} $CGMT_info(tags_to_convert) {
        regsub -all "<$tag>" $chunk $replace chunk
    }
    return $chunk
}

#
# CGMT_remove_dates removes our date stamps from a chunk and returnes the
# cleaned chunk.
#
proc CGMT_remove_dates {chunk} {
	global CGMT_info
	regsub -all {\[[0-9]{2}-[A-Z]{3}-[0-9]{2}\][ ]*} $chunk "" chunk
    return $chunk
}

#
# CGMT_extract_chunks goes through a page extracting the body text of each chunk.
# It converts list chunks to markdown lists. It keeps track of the chapter, section
# and date as provided by the sequence of chunks. It adds to the start of each 
# chunk the current chapter, section, and date.
#
proc CGMT_extract_chunks {page catalog} {
	global CGMT_info
	
	set date "NONE"
	set chapter "NONE"
	set section "NONE"
	set step "NONE"
	set chunks [list]
	foreach desc $catalog {
		scan $desc %d%d%s i_start i_end name
		set chunk [string trim [string range $page $i_start $i_end]]

		switch -- $name {
			"ol" {
				set chunk [CGMT_convert_list $chunk]
			}
			"ul" {
				set chunk [CGMT_convert_list $chunk]
			}
			"table" {
				set chunk [CGMT_convert_table $chunk]
			}
			"h2" {
				set chapter $chunk
				set section "NONE"
				continue
			}
			"h3" {
				set section $chunk
				continue
			}
			"date" {
				set date [CGMT_extract_date $chunk]
				continue
			}
			default {
				if {[regexp {^<b>([^:]+):</b>} $chunk match bold]} {
					set step $bold
				}
			}
		}
		
		set chunk [CGMT_convert_tags $chunk]
		set chunk [CGMT_remove_dates $chunk]
		
		switch -- $name {
			"ol" -
			"ul" -
			"table" {
				lset chunks end "[lindex $chunks end]\n\n$chunk"
			}
			default {
				if {$date != "NONE"} {
					set chunk "Date: $date\n\n$chunk"
				}
				if {$step != "NONE"} {
					set chunk "Step: $step\n$chunk"
				}
				if {$section != "NONE"} {
					set chunk "Section: $section\n$chunk"
				}
				if {$chapter != "NONE"} {
					set chunk "Chapter: $chapter\n$chunk"
				}
				lappend chunks $chunk
				set step "NONE"
			}
		}
	}
	return $chunks
}

#
# CGMT_resolve_relative_url takes a relative url and resolves it into an
# absolute url using a supplied base url. The framework of this code was
# provided by ChatGPT. We enhanced to support internal document links. The
# Base url can be a document with extenion php or html and the routine will
# use the document url for internal links.
#
proc CGMT_resolve_relative_url {base_url relative_url} {
	global CGMT_info

    # Extract the path part from the base URL
    regexp {^(https?://[^/]+)(/.*)$} $base_url -> domain base_path

    # Convert base path to a list for manipulation
    set base_parts [split $base_path "/"]

    # Remove the last element if it's empty (trailing slash)
    if {[lindex $base_parts end] eq ""} {
        set base_parts [lrange $base_parts 0 end-1]
    }
    
    # Check if the last element is a php or html file. If so, remove
    # and place store elsewhere.
    if {[regexp {(\.html|\.php)$} [lindex $base_parts end] match]} {
    	set document [lindex $base_parts end]
        set base_parts [lrange $base_parts 0 end-1]
     } else {
     	set document ""
     }

   # Process relative navigation
    foreach part [split $relative_url "/"] {
        switch -glob -- $part {
            ".." {
                # Go up one directory
                set base_parts [lrange $base_parts 0 end-1]
            }
            "." {
                # Stay in the current directory, do nothing
            }
            "\#*" {
            	# This is an internal link marked by hash symbol.
            	lappend base_parts "$document$part"
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
# CGMT_resolve_urls resolves all the relative urls in a page into absolute urls
# using the base url we pass in as the basis for resolution. It constructs a new
# page with the absolute urls. It calls CGMT_resolve_relative_url on each
# relative url it finds.
#
proc CGMT_resolve_urls {page base_url} {
	set index 0
	set new_page ""
	while {[regexp -indices -start $index {<a href="([^"]+)"[^>]*>} $page a url]} {
		append new_page [string range $page $index [expr [lindex $a 0] - 1]]
		set url [string range $page {*}$url]
		if {![regexp {https?} $url match]} {
			set url [CGMT_resolve_relative_url $base_url $url]
		}
		append new_page "<a href=\"$url\">"
		set index [expr [lindex $a 1] + 1]
	}
	append new_page [string range $page $index end]
	return $new_page
}

#
# CGMT_convert_urls finds all the anchors in a page and converts from html to
# markup format, where the title of the anchor is in brackets and the url is in
# parentheses immediately afterwards.
#
proc CGMT_convert_urls {page} {
	regsub -all {<a href="([^"]+)"[^>]*>([^<]+)</a>} $page {[\2](\1)} page
	return $page
}

#
# CGMT_chapter_url converts the "Chapter: Title" at the top of a chunk into
# a markdown anchor with absolute link to the chapter. It returns the modified
# chunk.
#
proc CGMT_chapter_url {chunk base_url} {
	if {[regexp {^Chapter: ([^\n]*)} $chunk match title]} {
		regsub {^Chapter: ([^\n]*)} $chunk "" chunk
		set chapter "Chapter: \[$title\]\($base_url\#$title\)"
		set chunk "$chapter$chunk"
	}
	return $chunk
}

#
# CGMT_convert_entities converts html entities in a page to unicode characters
# and returns the converted page.
#
proc CGMT_convert_entities {page} {
	global CGMT_info
    foreach {entity char} $CGMT_info(entities_to_convert) {
        regsub -all $entity $page $char page
    }
    return $page
}

#
# A complete chunk extractin process that reports to a text widget or stdout and
# writes chunks to a file.
#
proc CGMT_run {} {
	global CGMT_info
	set url "http://opensourceinstruments.host/Electronics/A3017/SCT.html"
	set base_url "https://www.opensourceinstruments.com/Electronics/A3017/SCT.html"
	LWDAQ_print $CGMT_info(t) "Requesting $url\..."
	set page [CGMT_read_url $url]
	LWDAQ_print $CGMT_info(t) "Downloaded [string length $page] bytes."
	LWDAQ_print $CGMT_info(t) "Resolving urls, base $base_url..."
	set page [CGMT_resolve_urls $page $base_url]
	LWDAQ_print $CGMT_info(t) "Converting urls..."
	set page [CGMT_convert_urls $page]
	LWDAQ_print $CGMT_info(t) "Converting html entities..."
	set page [CGMT_convert_entities $page]
	LWDAQ_print $CGMT_info(t) "Cataloging chunks, chapters, and dates..."
	set catalog [CGMT_catalog_chunks $page]
	LWDAQ_print $CGMT_info(t) "Cataloged length [llength $catalog]."
	set chunks [CGMT_extract_chunks $page $catalog]
	LWDAQ_print $CGMT_info(t) "Extracted [llength $chunks] chunks."
	set f [open ~/Desktop/converted.txt w]
	foreach chunk $chunks {
		set chunk [CGMT_chapter_url $chunk $base_url]
		puts $f "$chunk\n"
	}
	close $f
	LWDAQ_print $CGMT_info(t) "Done"
}

