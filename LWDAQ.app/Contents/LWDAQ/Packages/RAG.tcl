# Retrieval-Assisted Generation Package
# 
# (C) 2025, Kevan Hashemi, Open Source Instruments Inc.
#
# A Tcl package of routines that translate HTML documents into document chunks
# suitable for retrieval-assisted generation (RAG) of query answers by large
# language models (LLMs). The package relies upon "curl" and "openssl" being
# available at the operating system command line.
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

# Load this package or routines into LWDAQ with "package require RAG".
package provide RAG 1.5

proc RAG_init {} {
#
# We use a global array named after the package to store its configuration. When
# we execute the initialization, we clear any existing copy of the array. We
# will be referring to the array as "info" in this routine, but its global name
# is "RAG_info".
#
	upvar #0 RAG_info info
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
		small ""
		/small ""
	}
#
# The chunk delimiting tags.
#
	set info(chunk_tags) {p center pre equation ul ol h2 h3}
#
# Input-output parameters.
#	
	set info(hash_len) "12"
	set info(default_gpt_model) "gpt-4"
	set info(dict_entry_len) "10"
	set info(token_size) "4"
#
# Check existence of dependent utilities.
#
	if {[catch {exec which curl} error_result]} {
		error "Utility \"curl\" not found."
	}
	if {[catch {exec which openssl} error_result]} {
		error "Utility \"openssl\" not found."
	}
#
# Return an empty string to show now error.
#
	return ""
}

#
# RAG_print prints a line of text to a text widget or standard output or a file.
# The default definition of this procedure is given below, it just writes to
# standard output. The management process that uses the RAG package can
# re-define the procedure to direct text output wherever it likes, or to ignore
# text output. It takes one mandatory parameters, the string to be printed, and
# one optional parameter, a print color. The RAG routines will append "ERROR: "
# to error messages and "WARNING: " to warning messages. They will use colors
# other than black for diagnostic messages. Our assumption is that the RAG_print
# routine provided by a higher-level tool will include an update routine that
# allows the graphical user interface, if it exists, to respond to user input.
#
proc RAG_print {s {color "black"}} {
	puts $s
}

#
# RAG_time provides a timestamp for log messages.
#
proc RAG_time {} {
	return [clock format [clock seconds]]
}

#
# RAG_read_url fetches the source html code at a url and returns it as a single
# text string.
#
proc RAG_read_url {url} {
	upvar #0 RAG_info info

	set page [exec curl -sS $url]
	return $page
}
 
#
# RAG_locate_field goes to the index'th character in a page and searches
# forward for the first occurance of the named tage opening, looks further for
# the same tag to close. The routine returns the locations of four characters in
# the page. These are the begin and end characters of the body of the field, and
# the begin and end characters of the entire field including the tags. If an
# opening tag exits, but no end tage, the routine returns the entire remainder of
# the page as the contents of the field.
#
proc RAG_locate_field {page index tag} {
	upvar #0 RAG_info info
	
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
# RAG_extract_list takes the body of a list chunk and converts it to markup
# format with dashes for bullets and one list entry on each line. It returns the
# converted chunk body.
#
proc RAG_extract_list {chunk} {
	upvar #0 RAG_info info
	
	regsub -all {[\t ]*<li>} $chunk "- " chunk 
	regsub -all {</li>} $chunk "" chunk
	return $chunk
}

#
# RAG_extract_caption looks for a table or figure caption beginning with
# bold "Figure:" or "Table:". It extracts the text of the caption and returns
# with Figure or Table.
#
proc RAG_extract_caption {chunk} {
	upvar #0 RAG_info info
	
	set caption ""
	if {[regexp {<small><b>(Figure|Table):</b>(.+?)</small>} $chunk -> type caption]} {
		return "$type: [string trim $caption]"
	} else {
		return ""
	}
}

#
# RAG_extract_figures looks for img tags and creates an image reference to go with
# a figure caption, one for each image.
#
proc RAG_extract_figures {chunk} {
	upvar #0 RAG_info info
	
	set i 0
	set images ""
	while {$i < [string length $chunk]} {
		if {[regexp -indices -start $i {\[Figure\]\(([^)]*)\)} $chunk img url]} {
			set i [lindex $img 1]
			incr i
			set img [string range $chunk {*}$img]
			append images "!$img  \n"
		} else {
			break
		}
	}
	return [string trim $images]
}

#
# RAG_extract_table takes the body of a table chunk and converts it to markup
# format. The routine looks for a first row that contains heading cells. It
# reads the headings and makes a list. If there are no headings, its heading
# list will be empty. In subsequent rows, if it sees another list of headings,
# the previous list will be overwritten. In any row consisting of data cells the
# routine will prefix the contents of the n'th cell with the n'th heading. After
# extracting the table, we look for a table caption and extract it to append
# to our table chunk. We extract the caption using the separate caption
# extract routine.
#
proc RAG_extract_table {chunk} {
	upvar #0 RAG_info info
	
	set headings [list]
	set table ""
	set i 0
	while {$i < [string length $chunk]} {
		set indices [RAG_locate_field $chunk $i "tr"]
		scan $indices %d%d%d%d cells_begin cells_end row_begin row_end
		if {$row_end <= $row_begin} {break}
		
		set ii $cells_begin
		set cell_index 0
		while {$ii < $cells_end} {
			LWDAQ_support
			set indices [RAG_locate_field $chunk $ii "th"]
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

			set indices [RAG_locate_field $chunk $ii "td"]
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
# RAG_extract_date takes the body of a date chunk and converts it to a text
# title.
#
proc RAG_extract_date {chunk} {
	upvar #0 RAG_info info
	
	if {[regexp {[0-9]{2}-[A-Z]{3}-[0-9]{2}} $chunk date]} {
		set chunk "$date"
	} else {
		set chunk "NONE"
	}

	return $chunk
}

#
# RAG_catalog_chunks takes an html page and makes a list of chunks descriptors.
# Each descriptor consists of a start and end index for the content of the chunk
# and the chunk type. The indices point to the first and last characters within
# the chunk, not including whatever delimiters we used to find the chunk. In the
# case of a paragraph chunk, for example, the indices point to the first and
# last character of the body of the paragraph, between the <p> and </p> tags,
# but not including the tags themselves. The chunk type is the same as the html
# tag we use to find tagged chunks, but is some other name in the case of
# specialized chunks like "date", "figure", and "caption".
#
proc RAG_catalog_chunks {page} {
	upvar #0 RAG_info info

	set catalog [list]
	foreach {tag} $info(chunk_tags) {
		set index 0
		while {$index < [string length $page]} {
			set indices [RAG_locate_field $page $index $tag]
			scan $indices %d%d%d%d i_body_begin i_body_end i_field_begin i_field_end
			if {$i_body_end > $i_body_begin} {
				set descriptor "$i_body_begin $i_body_end $tag"
				lappend catalog $descriptor
			}
			set index [expr $i_field_end + 1]
		}
	}
	
	set index 0
	set pattern {<p>\[[0-9]{2}-[A-Z]{3}-[0-9]{2}\]}
	while {[regexp -indices -start $index $pattern $page i_p]} {
		set descriptor "$i_p date"
		lappend catalog $descriptor
		set index [expr [lindex $i_p 1] + 1]
	}

	set catalog [lsort -increasing -integer -index 0 $catalog]
	
	foreach descriptor $catalog {
		switch [lindex $descriptor 2] {
			"p" {set color gray}
			"ul" {set color green}
			"ol" {set color green}
			"h2" {set color darkpurple}
			"h3" {set color darkpurple}
			"center" {set color brown}
			"equation" {set color brown}
			"pre" {set color brown}
			"date" {set color darkpurple}
			default {set color red}
		}
		RAG_print $descriptor $color	
	}
		
	return $catalog
}

#
# RAG_convert_tags removes the html markup tags we won't be using from a chunk
# of text and returnes the cleaned chunk.
#
proc RAG_convert_tags {chunk} {
	upvar #0 RAG_info info
    foreach {tag replace} $info(tags_to_convert) {
        regsub -all "<$tag>" $chunk $replace chunk
    }
    return $chunk
}

#
# RAG_remove_dates removes our date stamps from a chunk and returnes the
# cleaned chunk.
#
proc RAG_remove_dates {chunk} {
	upvar #0 RAG_info info
	regsub -all {\[[0-9]{2}-[A-Z]{3}-[0-9]{2}\][ ]*} $chunk "" chunk
    return $chunk
}

#
# RAG_extract_chunks goes through a page extracting the body text of each chunk.
# It converts list chunks to markdown lists. It keeps track of the chapter, section
# and date as provided by the sequence of chunks. It adds to the start of each 
# chunk the current chapter, section, and date. The extractor combines centered
# tables, all lists, and the contents of "pre" tags with the previous chunk, whatever
# that may have been, and adds no additional metadata. It combines centered figures
# and all equations with the subsequent chunk. By the time the page arrives at this
# chunking routine, all URLs should have been converted to Markdown. If there are 
# any anchor or img tags left, something has gone wrong. We reject the chunk and
# count it.
#
proc RAG_extract_chunks {page catalog} {
	upvar #0 RAG_info info
	
	set date "NONE"
	set chapter "NONE"
	set section "NONE"
	set step "NONE"
	set prev_name "none"
	set rejected 0
	set chunks [list]
	foreach chunk_id $catalog {
		scan $chunk_id %d%d%s i_start i_end name
		set chunk [string trim [string range $page $i_start $i_end]]
		
		if {[regexp {<a href=} $chunk] \
			|| [regexp {</ul>} $chunk] \
			|| [regexp {</li>} $chunk]} {
			incr rejected
			continue
		}

		switch -- $name {
			"ol" {
				set chunk [RAG_extract_list $chunk]
			}
			"ul" {
				set chunk [RAG_extract_list $chunk]
			}
			"center" {
				set caption [RAG_extract_caption $chunk]
				if {[regexp {^Table} $caption]} {
					set table [RAG_extract_table $chunk]
					if {[string length $table] > 0} {
						set chunk "$caption  \n$table"
					} else {
						set chunk "$caption"
					}
					set name "table"
				} elseif {[regexp {^Figure} $caption]} {
					set figures [RAG_extract_figures $chunk]
					if {[string length $figures] > 0} {
						set chunk "$caption  \n$figures"
					} else {
						set chunk "$caption"
					}
					set name "figure"
				} else {
					set chunk "$caption"
				}
			}
			"equation" {
				
			}
			"pre" {
			
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
				set date [RAG_extract_date $chunk]
				continue
			}
			default {
				if {[regexp {^<b>([^:]+):</b>} $chunk -> bold]} {
					set step $bold
				}
			}
		}
		
		set chunk [RAG_convert_tags $chunk]
		set chunk [RAG_remove_dates $chunk]
		set chunk [string trim $chunk]
		if {([string length $chunk] == 0)} {
			RAG_print "Empty chunk, $chunk_id" brown
			continue
		}
		
		switch -- $name {
			"ol" -
			"ul" -
			"table" -
			"pre" {
				if {[llength $chunks] > 0} {
					lset chunks end "[lindex $chunks end]\n\n$chunk"
				} else {
					lappend chunks $chunk
				}
			}
			default {
				switch -- $prev_name {
					"equation" -
					"figure" {
						lset chunks end "[lindex $chunks end]\n\n$chunk"
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
					}
				}
				set step "NONE"
			}
		}
		set prev_name $name
	}
	if {$rejected > 0} {
		RAG_print "Rejected $rejected chunks with residual anchor and image tags."
	}
	return $chunks
}

#
# RAG_resolve_relative_url takes a relative url and resolves it into an
# absolute url using a supplied base url. The framework of this code was
# provided by ChatGPT. We enhanced to support internal document links. The
# base url can be a document with extenion php or html and the routine will
# use the document url for internal links.
#
proc RAG_resolve_relative_url {base_url relative_url} {
	upvar #0 RAG_info info

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
# RAG_resolve_urls resolves all the relative urls in a page into absolute urls
# using the base url we pass in as the basis for resolution. It constructs a new
# page with the absolute urls. It calls RAG_resolve_relative_url on each
# relative url it finds. The routine looks for urls in anchor tags <a> and in
# image tags <img>. In the final resolved url, we replace space characters with
# the HTML escape sequence "%20".
#
proc RAG_resolve_urls {page base_url} {
	upvar #0 RAG_info info

	set new_page ""

	set index 0
	while {[regexp -indices -start $index {<a +href="([^"]+)"[^>]*>} $page tag url]} {
		append new_page [string range $page $index [expr [lindex $tag 0] - 1]]
		set url [string range $page {*}$url]
		if {![regexp {https?} $url match]} {
			set url [RAG_resolve_relative_url $base_url $url]
		}
		regsub -all { } $url {%20} url
		append new_page "<a href=\"$url\">"
		set index [expr [lindex $tag 1] + 1]
	}

	set index 0
	set page $new_page
	set new_page ""
	while {[regexp -indices -start $index {<img +src="([^"]+)"[^>]*>} $page tag url]} {
		append new_page [string range $page $index [expr [lindex $tag 0] - 1]]
		set url [string range $page {*}$url]
		set url [string trim $url]
		if {![regexp {https?} $url match]} {
			set url [RAG_resolve_relative_url $base_url $url]
		}
		regsub -all { } $url {%20} url
		append new_page "<img src=\"$url\">"
		set index [expr [lindex $tag 1] + 1]
	}

	append new_page [string range $page $index end]
	return $new_page
}

#
# RAG_convert_urls finds all the anchors in a page and converts from html to
# markup format, where the title of the anchor is in brackets and the url is in
# parentheses immediately afterwards.
#
proc RAG_convert_urls {page} {
	upvar #0 RAG_info info
	regsub -all {<a +href="([^"]+)"[^>]*>([^<]+)</a>} $page {[\2](\1)} page
	regsub -all {<img +src="([^"]+)"[^>]*>} $page {[Figure](\1)} page
	return $page
}

#
# RAG_chapter_urls converts the "Chapter: Title" at the top of every chunk in a
# chunk list into a markdown anchor with absolute link to the chapter. It
# returns the modified chunks in a new list.
#
proc RAG_chapter_urls {chunks base_url} {
	upvar #0 RAG_info info
	set new_chunks [list]
	foreach chunk $chunks {
		if {[regexp {^Chapter: ([^\n]*)} $chunk -> title]} {
			regsub {^Chapter: ([^\n]*)} $chunk "" chunk
			regsub -all { } $title {%20} link
			set chapter "Chapter: \[$title\]\($base_url\#$link\)"
			lappend new_chunks "$chapter$chunk"
		} else {
			lappend new_chunks $chunk
		}
	}
	return $new_chunks
}

#
# RAG_convert_entities converts html entities in a page to unicode characters
# and returns the converted page. We also replace tabs with double-spaces.
#
proc RAG_convert_entities {page} {
	upvar #0 RAG_info info
    foreach {entity char} $info(entities_to_convert) {
        regsub -all $entity $page $char page
    }
    regsub -all {\t} $page "  " page
    return $page
}

#
# RAG_html_chunks downloads an html page from a url, splits it into chunks of text, and
# returns a list of chunks.
#
proc RAG_html_chunks {url} {
	upvar #0 RAG_info info
		
	RAG_print "Downloading from $url..." 
	set page [RAG_read_url $url]
	RAG_print "Downloaded [string length $page] bytes from $url\." 
	
	RAG_print "Resolving urls wrt $url..." 
	set page [RAG_resolve_urls $page $url]
	
	RAG_print "Converting urls to markdown..." 
	set page [RAG_convert_urls $page]
	
	RAG_print "Converting html entities to unicode..." 
	set page [RAG_convert_entities $page]
	
	RAG_print "Cataloging chunks, chapters, and dates..." 
	set catalog [RAG_catalog_chunks $page]
	RAG_print "Catalog contains [llength $catalog] chunks." 
	
	RAG_print "Extracting and combining chunks from source page..." 
	set chunks [RAG_extract_chunks $page $catalog]
	RAG_print "Extracted [llength $chunks] chunks." 
	
	RAG_print "Inserting chapter urls..." 
	set chunks [RAG_chapter_urls $chunks $url]
	RAG_print "Chunk list complete." 
	
	return $chunks
}

#
# RAG_submit_chunk submits a chunk, with the help of an access key, to the OpenAI
# embedding end point and retrieves its embed vector in a json record.
#
proc RAG_submit_chunk {chunk api_key} {
	upvar #0 RAG_info info
	
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
# RAG_embed_chunks stores chunks to disk. It takes each chunk in the list and
# uses its contents to obtain a unique hash name for the chunk. It stores the
# chunk to disk in the specified directory with the name hash.txt.
#
proc RAG_store_chunks {chunks dir} {
	upvar #0 RAG_info info
	
	RAG_print "Storing chunks to $dir\..." 
	set count 0
	foreach chunk $chunks {
		set cmd [list echo -n $chunk | openssl dgst -sha1]
		if {[catch {
			set result [eval exec $cmd]
		} error_result]} {
			RAG_print "ERROR: $error_result"
			RAG_print $chunk green
			continue
		}
		if {[regexp {[a-f0-9]{40}} $result hash]} {
			set hash [string range $hash 1 $info(hash_len)]
		} else {
			RAG_print "ERROR: Cannot find hash string in openssl result."
			RAG_print "RESULT: $result"
			break
		}
		set cfn [file join $dir $hash\.txt]
		set f [open $cfn w]
		puts -nonewline $f $chunk
		close $f
		incr count
		RAG_print "$count\: $cfn" green
	}
	RAG_print "Stored $count chunks." 
	return $count
}

#
# RAG_embed_chunk submits a chunk, with the help of an access key, to the
# embedding end point and retrieves its embed vector in a json record.
#
proc RAG_embed_chunk {chunk api_key} {
	upvar #0 RAG_info info
	
	set tokens [expr [string length $chunk] / $info(token_size)]
	RAG_print "Embedding chunk length $tokens tokens." brown
    set chunk [string map {\\ \\\\} $chunk]
    set chunk [string map {\" \\\"} $chunk]
    set chunk [string map {\n \\n} $chunk]
    regsub -all {\s+} $chunk " " chunk
	set json_body " \{\n \
		\"model\": \"text-embedding-ada-002\",\n \
		\"input\": \"$chunk\"\n \}"
	set cmd [list curl -sS -X POST https://api.openai.com/v1/embeddings \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer $api_key" \
		-d $json_body]
	if {[catch {
		set result [eval exec $cmd]
	} error_result]} {
		RAG_print "ERROR: $error_result"
		return ""
	}
	return $result
}

#
# RAG_fetch_embeds makes a list of all chunks in a chunk directory, which we
# assume are the files with extention txt, and another list of all the
# embeddings in an embed directory, which we assume are files with extension
# json, and checks to see if an embed exists for each chunk. If no embed exists,
# the routine reads the chunk, submits the chunk to the embedding end point,
# fetches the embedding, and stores the embedding to disk with the same file
# name root as the chunk. At the end, the routine purges any embeds that have
# no matching chunk remaining.
#
proc RAG_fetch_embeds {chunk_dir embed_dir api_key} {
	upvar #0 RAG_info info
		
	set cfl [glob -nocomplain [file join $chunk_dir *.txt]]
	RAG_print "Found [llength $cfl] chunks on disk."
	set efl [glob -nocomplain [file join $embed_dir *.json]]
	RAG_print "Found [llength $efl] embeds on disk."
	set new_count 0
	set old_count 0
	set count 0
	RAG_print "Creating embeds for new paragraphs..."
	foreach cfn $cfl {
		incr count
		set root [file root [file tail $cfn]]
		if {![regexp $root $efl]} {
			set f [open $cfn r]
			set chunk [read $f]
			close $f
			set embed [RAG_embed_chunk $chunk $api_key]
			if {[regexp -nocase "error" $embed]} {
				RAG_print "ERROR: $embed"
				break
			}
			set efn [file join $embed_dir $root\.json]
			set f [open $efn w]
			puts -nonewline $f $embed
			close $f
			incr new_count
			RAG_print "$count\: [file tail $cfn] fetched new embed." orange
		} else {
			incr old_count
			RAG_print "$count\: [file tail $cfn] embed exists." orange
		} 
		LWDAQ_update
	}
	RAG_print "Checked $count chunks,\
		found $old_count embeds,\
		fetched $new_count embeds."
		
	set efl [glob [file join $embed_dir *.json]]
	set count 0
	foreach efn $efl {
		set root [file root [file tail $efn]]
		if {![regexp $root $cfl]} {
			file delete $efn
			incr count
		}
	}
	RAG_print "Purged $count expired embeds from disk."
	
	return $count
}

#
# RAG_vector_from_json takes an embedding json string and extracts its embed
# vector as a Tcl list.
#
proc RAG_vector_from_embed {embed} {
	upvar #0 RAG_info info
		
	if {[regexp {"embedding": \[([^\]]*)} $embed match vector]} {
		regsub -all {,} $vector " " vector
		regsub -all {[\n\t ]+} $vector " " vector
	} else {
		set vector "0"
	}
	return [string trim $vector]
}

#
# RAG_make_dictionary goes through all the embed vectors in the embed directory
# and for each makes a text file in the dictionary directory that contains a
# list of similar chunks. This list consists of pairs of similarities and chunk
# names. 
# 
proc RAG_make_dictionary {embed_dir dict_dir} {
	upvar #0 RAG_info info
		
	RAG_print "Starting dictionary generation at [RAG_time]."

	RAG_print "Reading embeds from disk into memory..."
	set efl [glob -nocomplain [file join $embed_dir *.json]]
	set embeds [list]
	foreach efn $efl {
		LWDAQ_support
		set f [open $efn r]
		set embed [read $f]
		close $f
		set vector [RAG_vector_from_embed $embed]
		lappend embeds [list [file root [file tail $efn]] $vector]
	}
	RAG_print "Read [llength $efl] embeds from disk into memory."

	set count 0
	foreach e1 $embeds {
		incr count
		set name1 [lindex $e1 0]
		set vector1 [lindex $e1 1]
		set len [llength $vector1]
		set comparisons [list]
		foreach e2 $embeds {
			set name2 [lindex $e2 0]
			set vector2 [lindex $e2 1]
			set dot_product 0
			for {set i 0} {$i < $len} {incr i} {
				set x1 [lindex $vector1 $i]
				set x2 [lindex $vector2 $i]
				set dot_product [expr $dot_product + $x1*$x2]
			}
			set similarity [format %.4f $dot_product]
			lappend comparisons "$similarity $name2"
		}
		set comparisons [lsort -decreasing -real -index 0 $comparisons]
		set comparisons [lrange $comparisons 1 $info(dict_entry_len)]
		set dfn [file join $dict_dir $name1\.txt]
		set f [open $dfn w]
		puts -nonewline $f $comparisons
		close $f
		RAG_print "$count: [lindex $e1 0] [lrange $comparisons 0 2]" orange
		LWDAQ_update
	}

	RAG_print "Done with dictionary generation at [RAG_time]."
	return ""
}

#
# RAG_json_format takes a string and formats double quotes, newlines,
# backslashes, and multiple white spaces for a json string.
#
proc RAG_json_format {s} {
	set s [string map {\\ \\\\} $s]
	set s [string map {\" \\\"} $s]
	set s [string map {\n \\n} $s]
	regsub -all {\s+} $s " " s
	return $s
}

#
# RAG_get_answer submits a list of chunks and a question to the chat completion
# end point and returns the answer it obtains. It takes as in put four mandatory
# parameters: the question, the list of reference chunks, a description of the
# attitude with which the end point is supposed to answer the question, and a
# key that grants access to the generator. It returns the entire result from the
# end point, as a json record, and leaves it to the calling procedure to extract
# the answer. A fifth optional input is the gpt model. If we don't specify, we
# fall back on the default model specified in default_gpt_model.
#
proc RAG_get_answer {question chunks assistant api_key {model ""}} {
	upvar #0 RAG_info info
	
	if {$model == ""} {set model $info(default_gpt_model)}
	
	set assistant [RAG_json_format $assistant]
 	set json_body "\{\n \
		\"model\": \"$model\",\n \
		\"messages\": \[\n   \
		\{ \"role\": \"system\", \"content\": \"$assistant\" \},\n"
	foreach chunk $chunks {
		set chunk [RAG_json_format $chunk]
		append json_body "    \{ \"role\": \"user\", \"content\": \"$chunk\" \},\n"
	}
	set question [RAG_json_format $question]
	append json_body "    \{ \"role\": \"user\", \"content\": \"$question\" \} \n"
	append json_body "  \], \n  \"temperature\": 0.0 \n\}"
	
	set cmd [list | curl -sS -X POST https://api.openai.com/v1/chat/completions \
	  -H "Content-Type: application/json" \
	  -H "Authorization: Bearer $api_key" \
	  -d $json_body] 

	set ch [open $cmd]
	set chpid [pid $ch]
	fconfigure $ch -blocking 0 -buffering line
	set result ""
	while {1} {
		set line [gets $ch]
		if {[eof $ch]} {
			break
		} elseif {$line eq ""} {
			LWDAQ_update
			continue
		} else {
			append result "$line\n"
		}
	}		  
	return $result
}
