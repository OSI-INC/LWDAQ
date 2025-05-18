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

proc CGMT_init {} {
#
# We use a global array named after the package to store its configuration. When
# we execute the initialization, we clear any existing copy of the array. We
# will be referring to the array as "info" in this routine, but its global name
# is "CGMT_info".
#
	upvar #0 CGMT_info info
	if {[info exists info]} {unset info}
#
# A verbose flag for diagnostics.
#
	set info(verbose) 0
#
# A list of html entities and the unicode characters we want to replace them
# with.
#
	set info(entities_to_convert) {
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
#
# A list of tags we want to remove
#
	set info(tags_to_convert) {
		i ""
		/i ""
		b ""
		/b ""
		br " "
	}
#
# The chunk delimiting tags.
#
	set info(chunk_tags) {p center ul ol h2 h3}
#
# Input-output parameters.
#	
	set info(hash_len) "12"
	set info(t) "stdout"
#
# Return an empty string to show now error.
#
	return ""
}

#
# CGMT_read_url fetches the source html code at a url and return as a single
# text string.
#
proc CGMT_read_url {url} {
	upvar #0 CGMT_info info

	set page [LWDAQ_url_download $url]
	return $page
}
 
#
# CGMT_read_file reads an html file from a file and return as a single text
# string.
#
proc CGMT_read_file {{fn ""}} {
	upvar #0 CGMT_info info

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
# CGMT_locate_field goes to the index'th character in a page and searches
# forward for the first occurance of the named tage opening, looks further for
# the same tag to close. The routine returns the locations of four characters in
# the page. These are the begin and end characters of the body of the field, and
# the begin and end characters of the entire field including the tags. If an
# opening tag exits, but no end tage, the routine returns the entire remainder of
# the page as the contents of the field.
#
proc CGMT_locate_field {page index tag} {
	upvar #0 CGMT_info info
	
	if {[regexp -indices -start $index "<$tag\(| \[^>\]*\)>" $page i_open]} {
		set i_body_begin [expr [lindex $i_open 1] + 1] 
		set i_field_begin [lindex $i_open 0]
		if {[regexp -indices -start $i_body_begin "</$tag>" $page i_close]} {
			set i_body_end [expr [lindex $i_close 0] - 1]
			set i_field_end [lindex $i_close 1]
		} else {
			set i_body_end [string length $page]
			set i_field_end $i_body_end
		}
	} else {
		set i_field_begin [string length $page]
		set i_field_end $i_field_begin
		set i_body_begin $i_field_begin
		set i_body_end $i_field_begin
	}
	return "$i_body_begin $i_body_end $i_field_begin $i_field_end"
}

#
# CGMT_extract_list takes the body of a list chunk and converts it to markup
# format with dashes for bullets and one list entry on each line. It returns the
# converted chunk body.
#
proc CGMT_extract_list {chunk} {
	upvar #0 CGMT_info info
	
	regsub -all {[\t ]*<li>} $chunk "- " chunk 
	regsub -all {</li>} $chunk "" chunk
	return $chunk
}

#
# CGMT_extract_caption looks for a table or figure caption beginning with
# bold "Figure:" or "Table:". It extracts the text of the caption and returns
# with Figure or Table.
#
proc CGMT_extract_caption {chunk} {
	upvar #0 CGMT_info info
	
	set caption ""
	if {[regexp {<small><b>(Figure|Table):</b>(.+?)</small>} $chunk -> type caption]} {
		return "$type: [string trim $caption]"
	} else {
		return ""
	}
}

#
# CGMT_extract_figures looks for img tags and creates an image reference to go with
# a figure caption, one for each image.
#
proc CGMT_extract_figures {chunk} {
	upvar #0 CGMT_info info
	
	if {[regexp {\[Image\]\(([^)]*)\)} $chunk img url]} {
		return $img
	} else {
		return ""
	}
}

#
# CGMT_extract_table takes the body of a table chunk and converts it to markup
# format. The routine looks for a first row that contains heading cells. It
# reads the headings and makes a list. If there are no headings, its heading
# list will be empty. In subsequent rows, if it sees another list of headings,
# the previous list will be overwritten. In any row consisting of data cells the
# routine will prefix the contents of the n'th cell with the n'th heading. After
# extracting the table, we look for a table caption and extract it to append
# to our table chunk. We extract the caption using the separate caption
# extract routine.
#
proc CGMT_extract_table {chunk} {
	upvar #0 CGMT_info info
	
	set headings [list]
	set table ""
	set i 0
	while {$i < [string length $chunk]} {
		set indices [CGMT_locate_field $chunk $i "tr"]
		scan $indices %d%d%d%d cells_begin cells_end row_begin row_end
		if {$row_end <= $row_begin} {break}
		
		set ii $cells_begin
		set cell_index 0
		while {$ii < $cells_end} {
			LWDAQ_support
			set indices [CGMT_locate_field $chunk $ii "th"]
			scan $indices %d%d%d%d heading_begin heading_end cell_begin cell_end
			if {$cell_end <= $cells_end} {
				set heading [string range $chunk $heading_begin $heading_end]
				regsub "\n" $heading " " heading
				regsub "<br>" $heading " " heading
				if {$cell_index == 0} {
					set headings [list $heading]
				} else {
					lappend headings $heading
				}
				incr cell_index
				set ii [expr $cell_end + 1]
				continue
			} 

			set indices [CGMT_locate_field $chunk $ii "td"]
			scan $indices %d%d%d%d data_begin data_end cell_begin cell_end
			if {$cell_end <= $cells_end} {
				set data [string range $chunk $data_begin $data_end]
				regsub "\n" $data " " data
				regsub "<br>" $data " " data
				append table "\"[lindex $headings $cell_index]\": $data "
				incr cell_index
				set ii [expr $cell_end + 1]
				continue
			} 
			
			set ii $cells_end
		}
		
		append table "\n"
		set i [expr $row_end + 1]
	}
	
	return [string trim $table]
}

#
# CGMT_extract_date takes the body of a date chunk and converts it to a text
# title.
#
proc CGMT_extract_date {chunk} {
	upvar #0 CGMT_info info
	
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
	upvar #0 CGMT_info info

	set catalog [list]
	foreach {tag} $info(chunk_tags) {
		set index 0
		while {$index < [string length $page]} {
			set indices [CGMT_locate_field $page $index $tag]
			scan $indices %d%d%d%d i_body_begin i_body_end i_field_begin i_field_end
			if {$i_body_end > $i_body_begin} {
				set chunk "$i_body_begin $i_body_end $tag"
				lappend catalog $chunk
			}
			set index [expr $i_field_end + 1]
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
	
	if {$info(verbose)} {
		foreach chunk $catalog {
			switch [lindex $chunk 2] {
				"p" {set color orange}
				"ul" {set color green}
				"ol" {set color green}
				"h2" {set color blue}
				"h3" {set color brown}
				"center" {set color cyan}
				"figure" {set color pink}
				"date" {set color darkgreen}
				"caption" {set color darkred}
				default {set color black}
			}
			LWDAQ_print $info(t) $chunk $color	
		}
	}
		
	return $catalog
}

#
# CGMT_convert_tags removes the html markup tags we won't be using from a chunk
# of text and returnes the cleaned chunk.
#
proc CGMT_convert_tags {chunk} {
	upvar #0 CGMT_info info
    foreach {tag replace} $info(tags_to_convert) {
        regsub -all "<$tag>" $chunk $replace chunk
    }
    return $chunk
}

#
# CGMT_remove_dates removes our date stamps from a chunk and returnes the
# cleaned chunk.
#
proc CGMT_remove_dates {chunk} {
	upvar #0 CGMT_info info
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
	upvar #0 CGMT_info info
	
	set date "NONE"
	set chapter "NONE"
	set section "NONE"
	set step "NONE"
	set chunks [list]
	foreach chunk_id $catalog {
		scan $chunk_id %d%d%s i_start i_end name
		set chunk [string trim [string range $page $i_start $i_end]]

		switch -- $name {
			"ol" {
				set chunk [CGMT_extract_list $chunk]
			}
			"ul" {
				set chunk [CGMT_extract_list $chunk]
			}
			"center" {
				set caption [CGMT_extract_caption $chunk]
				if {[regexp {^Table} $caption]} {
					set table [CGMT_extract_table $chunk]
					if {[string length $table] > 0} {
						set chunk "$caption\n\n$table"
					} else {
						set chunk "$caption"
					}
				} elseif {[regexp {^Figure} $caption]} {
					set figures [CGMT_extract_figures $chunk]
					if {[string length $figures] > 0} {
						set chunk "$caption\n$figures"
					} else {
						set chunk "$caption"
					}
				} else {
					set chunk "$caption"
				}
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
				if {[regexp {^<b>([^:]+):</b>} $chunk -> bold]} {
					set step $bold
				}
			}
		}
		
		set chunk [CGMT_convert_tags $chunk]
		set chunk [CGMT_remove_dates $chunk]
		set chunk [string trim $chunk]
		if {([string length $chunk] == 0)} {
			if {$info(verbose)} {
				LWDAQ_print $info(t) "Empty chunk, $chunk_id" brown
			}
			continue
		}
		
		switch -- $name {
			"ol" -
			"ul" -
			"center" {
				if {[llength $chunks] > 0} {
					lset chunks end "[lindex $chunks end]\n\n$chunk"
				} else {
					lappend chunks $chunk
				}
			}
			default {
				set heading ""
				if {$chapter != "NONE"} {
					append heading "Chapter: $chapter\n"
				}
				if {$section != "NONE"} {
					set heading "Section: $section\n"
				}
				if {$step != "NONE"} {
					append heading "Step: $step\n"
				}
				if {$date != "NONE"} {
					append heading "Date: $date\n"
				}
				if {[string length $heading] > 0} {
					set chunk "$heading\n$chunk"
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
	upvar #0 CGMT_info info

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

   # Process relative navigation. For ".." we go up one directory. For "." we stay
   # in the same directory. For a hash sign followed by anything we create an
   # internal link. By default, we go into a subdirectory or file.
    foreach part [split $relative_url "/"] {
        switch -glob -- $part {
            ".." {
                set base_parts [lrange $base_parts 0 end-1]
            }
            "." {
            }
            "\#*" {
            	lappend base_parts "$document$part"
           }
            default {
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
# relative url it finds. The routine looks for urls in anchor tags <a> and in
# image tags <img>.
#
proc CGMT_resolve_urls {page base_url} {
	upvar #0 CGMT_info info

	set new_page ""

	set index 0
	while {[regexp -indices -start $index {<a +href="([^"]+)"[^>]*>} $page tag url]} {
		append new_page [string range $page $index [expr [lindex $tag 0] - 1]]
		set url [string range $page {*}$url]
		if {![regexp {https?} $url match]} {
			set url [CGMT_resolve_relative_url $base_url $url]
		}
		append new_page "<a href=\"$url\">"
		set index [expr [lindex $tag 1] + 1]
	}

	set index 0
	set page $new_page
	set new_page ""
	while {[regexp -indices -start $index {<img +src="([^"]+)"[^>]*>} $page tag url]} {
		append new_page [string range $page $index [expr [lindex $tag 0] - 1]]
		set url [string range $page {*}$url]
		if {![regexp {https?} $url match]} {
			set url [CGMT_resolve_relative_url $base_url $url]
		}
		append new_page "<img src=\"$url\">"
		set index [expr [lindex $tag 1] + 1]
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
	upvar #0 CGMT_info info
	regsub -all {<a +href="([^"]+)"[^>]*>([^<]+)</a>} $page {[\2](\1)} page
	regsub -all {<img +src="([^"]+)"[^>]*>} $page {[Image](\1)} page
	return $page
}

#
# CGMT_chapter_urls converts the "Chapter: Title" at the top of every chunk in a
# chunk list into a markdown anchor with absolute link to the chapter. It
# returns the modified chunks in a new list.
#
proc CGMT_chapter_urls {chunks base_url} {
	upvar #0 CGMT_info info
	set new_chunks [list]
	foreach chunk $chunks {
		if {[regexp {^Chapter: ([^\n]*)} $chunk -> title]} {
			regsub {^Chapter: ([^\n]*)} $chunk "" chunk
			set chapter "Chapter: \[$title\]\($base_url\#$title\)"
			lappend new_chunks "$chapter$chunk"
		} else {
			lappend new_chunks $chunk
		}
	}
	return $new_chunks
}

#
# CGMT_convert_entities converts html entities in a page to unicode characters
# and returns the converted page. We also replace tabs with double-spaces.
#
proc CGMT_convert_entities {page} {
	upvar #0 CGMT_info info
    foreach {entity char} $info(entities_to_convert) {
        regsub -all $entity $page $char page
    }
    regsub -all {\t} $page "  " page
    return $page
}

#
# CGMT_html_chunks downloads an html page and chunks it for OpenAI, returning
# a list of chunks.
#
proc CGMT_html_chunks {url base_url} {
	upvar #0 CGMT_info info
	set t $info(t)
	
	set page [CGMT_read_url $url]
	LWDAQ_print $t "Downloaded [string length $page] bytes from $url\."
	
	LWDAQ_print $t "Resolving urls wrt $base_url..."
	set page [CGMT_resolve_urls $page $base_url]
	
	LWDAQ_print $t "Converting urls to markdown..."
	set page [CGMT_convert_urls $page]
	
	LWDAQ_print $t "Converting html entities to unicode..."
	set page [CGMT_convert_entities $page]
	
	LWDAQ_print $t "Cataloging chunks, chapters, and dates..."
	set catalog [CGMT_catalog_chunks $page]
	LWDAQ_print $t "Catalog contains [llength $catalog] chunks."
	
	LWDAQ_print $t "Extracting and combining chunks from source page..."
	set chunks [CGMT_extract_chunks $page $catalog]
	LWDAQ_print $t "Extracted [llength $chunks] chunks."
	
	LWDAQ_print $t "Inserting chapter urls..."
	set chunks [CGMT_chapter_urls $chunks $base_url]
	LWDAQ_print $t "Chunk list complete with [llength $chunks] chunks."
	
	return $chunks
}

#
# CGMT_submit_chunk submits a chunk, with the help of an access key, to the OpenAI
# embedding end point and retrieves its embed vector in a json record.
#
proc CGMT_submit_chunk {chunk api_key} {
	upvar #0 CGMT_info info
	set t $info(t)

    set chunk [string map {\\ \\\\} $chunk]
    set chunk [string map {\" \\\"} $chunk]
    set chunk [string map {\n \\n} $chunk]
    regsub -all {\s+} $chunk " " chunk
	set json_body " \{\n \
		\"model\": \"text-embedding-ada-002\",\n \
		\"input\": \"$chunk\"\n \}"
	set cmd [list curl -s -X POST https://api.openai.com/v1/embeddings \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer $api_key" \
		-d $json_body]
	set result [eval exec $cmd]
	return $result
}

#
# CGMT_embed_chunks stores chunks to disk. It takes each chunk in the list and
# uses its contents to obtain a unique hash name for the chunk. It stores the
# chunk to disk in the specified directory with the name hash.txt.
#
proc CGMT_store_chunks {chunks dir} {
	upvar #0 CGMT_info info
	set t $info(t)

	LWDAQ_print $t "Storing [llength $chunks] to $dir\..."
	set count 0
	foreach chunk $chunks {
		incr count
		set cmd [list echo -n $chunk | openssl dgst -sha1]
		set hash [eval exec $cmd]
		set hash [string range $hash 1 $info(hash_len)]
		set cfn [file join $dir $hash\.txt]
		set f [open $cfn w]
		puts -nonewline $f $chunk
		close $f
		LWDAQ_print $t "$count\: Stored chunk $hash\."
		LWDAQ_support
	}
	LWDAQ_print $t "Stored $count chunks."
	return $count
}

#
# CGMT_embed_chunk submits a chunk, with the help of an access key, to the
# embedding end point and retrieves its embed vector in a json record.
#
proc CGMT_embed_chunk {chunk api_key} {
	upvar #0 CGMT_info info
	set t $info(t)

    set chunk [string map {\\ \\\\} $chunk]
    set chunk [string map {\" \\\"} $chunk]
    set chunk [string map {\n \\n} $chunk]
    regsub -all {\s+} $chunk " " chunk
	set json_body " \{\n \
		\"model\": \"text-embedding-ada-002\",\n \
		\"input\": \"$chunk\"\n \}"
	set cmd [list curl -s -X POST https://api.openai.com/v1/embeddings \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer $api_key" \
		-d $json_body]
	set result [eval exec $cmd]
	return $result
}

#
# CGMT_store_embeds reads all chunks in a directory, which we assume are all
# files with extention txt, reads them, submits them to the embedding end point,
# and stores the embed vector in the same directory with the same name, but
# extension json.
#
proc CGMT_store_embeds {dir api_key} {
	upvar #0 CGMT_info info
	set t $info(t)
	
	set cfl [glob [file join $dir *.txt]]
	LWDAQ_print $t "Found [llength $cfl] chunks found on disk."
	set count 0
	foreach cfn $cfl {
		incr count
		set efn [file join $dir [file root [file tail $cfn]].json]
		set f [open $cfn r]
		set chunk [read $f]
		close $f
		set embed [CGMT_embed_chunk $chunk $api_key]
		if {[regexp -nocase "error" $embed]} {
			LWDAQ_print $t "ERROR: $embed"
			LWDAQ_print $t $chunk blue
			break
		}
		set f [open $efn w]
		puts -nonewline $f $embed
		close $f
		LWDAQ_print $t "$count\: Embed [file tail $efn]."
		LWDAQ_update
	}
	LWDAQ_print $t "Embedded $count chunks."
	return $count
}


#
# Run the initialization routine.
#
CGMT_init

