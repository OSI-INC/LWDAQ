# Retrieval-Assisted Generation Manager, a LWDAQ Tool.
#
# Copyright (C) 2025 Kevan Hashemi, Open Source Instruments Inc.
#
# RAG Check provides an interface for our Retrieval Access Generation (RAG) 
# routines, provided by our RAG package.
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

proc RAG_Manager_init {} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config

#
# Set up the RAG Manager in the LWDAQ tool system.
#
	LWDAQ_tool_init "RAG_Manager" "2.0"
	if {[winfo exists $info(window)]} {return ""}
#
# Directory locations for key, chunks, embeds, and dictionary.
#
	set config(key_file) "~/Active/Admin/Keys/OpenAI_API.txt"
	set config(chunk_dir) "~/Active/RAG/Chunks"
	set config(embed_dir) "~/Active/RAG/Embeds"
	set config(dict_dir) "~/Active/RAG/Dictionary"
#
# The default question.
#
	set config(question) "Calculate the operating life of an A3048 SCT\
		with 160-Hz bandwidth and mass 2 g."
#
# Internal flags, lists, and control variables.
#
	set info(control) "Idle"
	set info(chat) ""
	set info(result) ""
	set info(text) "stdout"
	set info(data) ""
	set info(relevance) "0.0"
#
# The source documents. Can be edited with a dedicated window and saved to
# settings file.
#
	set config(sources) {
https://www.opensourceinstruments.com/Electronics/A3017/SCT.html
https://www.opensourceinstruments.com/Software/LWDAQ/Manual.html
https://www.opensourceinstruments.com/About/about.php
https://www.bndhep.net/Devices/BCAM/User_Manual.html
	}
#
# Configuration for retrieval and submission based upon relevance of the question
# to the chunk library. We have three tiers of relevance: high, mid, and low.
#	
	set config(high_rel_thr) "0.50"
	set config(low_rel_thr) "0.30"
	set config(high_rel_model) "gpt-4"
	set config(mid_rel_model) "gpt-3.5-turbo"
	set config(low_rel_model) "gpt-3.5-turbo"
	set config(high_rel_tokens) "3000"
	set config(mid_rel_tokens) "1000"
	set config(low_rel_tokens) "0"
	set config(max_question_tokens) "300"
	set info(default_gpt_model) "gpt-4"
	set config(embed_model) "text-embedding-3-small"
#
# Titles for content we submit to completion end point.
#	
	set config(chunk_title) "### Documentation Chunk\n\n"
	set config(chat_title) "### Previous Q&A\n\n"
#
# Flag that turns on inclusion of the chat in the question.
#
	set config(chat_submit) "0"
#
# Verbose flag for diagnostic text output.
#
	set config(verbose) "0"
#
# Dictionary flag turns on use of dictionary to add chunks relevant to the most
# relevant chunks.
#
	set config(dictionary) "0"
#
# Completion assistant instructions for the three tiers of relevance. Can be
# edited with a dedicated window and saved to settings file.
#
	set config(high_rel_assistant) {
You are a helpful technical assistant.
You can perform mathematical calculations and return
numeric results with appropriate units.
You are also able to summarize, explain, and answer questions
about scientific and engineering documentation.
You are provided with excerpts from documentation that may include
text, figures, and links. When answering the user's question:
  - If the user's question asks for a figure, graph, or image
    and a matching figure is present in the excerpts,
    include it in your response using Markdown image formatting:  
    `![Figure Caption](image_url)`  
    This ensures the image will be rendered inline in the chat interface.
  - Do not say "you cannot search the web" or "you cannot find images" if a 
    relevant figure is already present in the provided content.
  - Provide hyperlinks to original documentation sources when available.
  - Prefer newer information over older when content appears to be 
    versioned or time-sensitive.
  - Respond using Markdown formatting.
    }
	set config(mid_rel_assistant) {
You are a helpful technical assistant.
If you are not certain of the answer to a question,
say you do not know the answer.
Respond using Markdown formatting. 
	}
	set config(low_rel_assistant) {
You are a helpful technical assistant.
If you are not certain of the answer to a question,
say you do not know the answer.
Respond using Markdown formatting. 
	}
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
# Look for a saved configuration file, and if we find one, load it.
#
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 
#
# Empty string return means all well.
#
	return ""	
}

#
# RAG_Manager_time provides a timestamp for log messages.
#
proc RAG_Manager_time {} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config

	return [clock format [clock seconds]]
}

#
# RAG_Manager_print prints to $info(text) using our LWDAQ_print routine. If
# $info(text) is a text widget, the text will be printed there with colors. If
# it is stdout, the text will go to the console, or wherever stdout is directed.
# If it is a valid file name in a directory in which the RAG Manager has write
# priviledge, the output will be appended to the file.
#
proc RAG_Manager_print {s {color "black"}} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config

	if {$config(verbose) || ($color == "black") || ($color == "purple") \
		|| [regexp {^ERROR: } $s] || [regexp {^WARNING: } $s]} {
		LWDAQ_print $info(text) $s $color
		LWDAQ_update
	}
}

#
# RAG_Manager_read_url fetches the source html code at a url and returns it as a single
# text string.
#
proc RAG_Manager_read_url {url} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config

	set page [exec curl -sS $url]
	return $page
}
 
#
# RAG_Manager_locate_field goes to the index'th character in a page and searches
# forward for the first occurance of the named tage opening, looks further for
# the same tag to close. The routine returns the locations of four characters in
# the page. These are the begin and end characters of the body of the field, and
# the begin and end characters of the entire field including the tags. If an
# opening tag exits, but no end tage, the routine returns the entire remainder
# of the page as the contents of the field.
#
proc RAG_Manager_locate_field {page index tag} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
	
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
# RAG_Manager_extract_list takes the body of a list chunk and converts it to
# markup format with dashes for bullets and one list entry on each line. It
# returns the converted chunk body.
#
proc RAG_Manager_extract_list {chunk} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
	
	regsub -all {[\t ]*<li>} $chunk "- " chunk 
	regsub -all {</li>} $chunk "" chunk
	return $chunk
}

#
# RAG_Manager_extract_caption looks for a table or figure caption beginning with
# bold "Figure:" or "Table:". It extracts the text of the caption and returns
# with Figure or Table.
#
proc RAG_Manager_extract_caption {chunk} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
	
	set caption ""
	if {[regexp {<small><b>(Figure|Table):</b>(.+?)</small>} $chunk -> type caption]} {
		return "$type: [string trim $caption]"
	} else {
		return ""
	}
}

#
# RAG_Manager_extract_figures looks for img tags and creates an image reference
# to go with a figure caption, one for each image.
#
proc RAG_Manager_extract_figures {chunk} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
	
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
# RAG_Manager_extract_table takes the body of a table chunk and converts it to
# markup format. The routine looks for a first row that contains heading cells.
# It reads the headings and makes a list. If there are no headings, its heading
# list will be empty. In subsequent rows, if it sees another list of headings,
# the previous list will be overwritten. In any row consisting of data cells the
# routine will prefix the contents of the n'th cell with the n'th heading. After
# extracting the table, we look for a table caption and extract it to append to
# our table chunk. We extract the caption using the separate caption extract
# routine.
#
proc RAG_Manager_extract_table {chunk} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
	
	set headings [list]
	set table ""
	set i 0
	while {$i < [string length $chunk]} {
		set indices [RAG_Manager_locate_field $chunk $i "tr"]
		scan $indices %d%d%d%d cells_begin cells_end row_begin row_end
		if {$row_end <= $row_begin} {break}
		
		set ii $cells_begin
		set cell_index 0
		while {$ii < $cells_end} {
			LWDAQ_support
			set indices [RAG_Manager_locate_field $chunk $ii "th"]
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

			set indices [RAG_Manager_locate_field $chunk $ii "td"]
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
# RAG_Manager_extract_date takes the body of a date chunk and converts it to a
# text title.
#
proc RAG_Manager_extract_date {chunk} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
	
	if {[regexp {[0-9]{2}-[A-Z]{3}-[0-9]{2}} $chunk date]} {
		set chunk "$date"
	} else {
		set chunk "NONE"
	}

	return $chunk
}

#
# RAG_Manager_catalog_chunks takes an html page and makes a list of chunks
# descriptors. Each descriptor consists of a start and end index for the content
# of the chunk and the chunk type. The indices point to the first and last
# characters within the chunk, not including whatever delimiters we used to find
# the chunk. In the case of a paragraph chunk, for example, the indices point to
# the first and last character of the body of the paragraph, between the <p> and
# </p> tags, but not including the tags themselves. The chunk type is the same
# as the html tag we use to find tagged chunks, but is some other name in the
# case of specialized chunks like "date", "figure", and "caption".
#
proc RAG_Manager_catalog_chunks {page} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config

	set catalog [list]
	foreach {tag} $info(chunk_tags) {
		set index 0
		while {$index < [string length $page]} {
			set indices [RAG_Manager_locate_field $page $index $tag]
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
		RAG_Manager_print $descriptor $color	
	}
		
	return $catalog
}

#
# RAG_Manager_convert_tags removes the html markup tags we won't be using from a
# chunk of text and returnes the cleaned chunk.
#
proc RAG_Manager_convert_tags {chunk} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config

    foreach {tag replace} $info(tags_to_convert) {
        regsub -all "<$tag>" $chunk $replace chunk
    }
    return $chunk
}

#
# RAG_Manager_remove_dates removes our date stamps from a chunk and returnes the
# cleaned chunk.
#
proc RAG_Manager_remove_dates {chunk} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config

	regsub -all {\[[0-9]{2}-[A-Z]{3}-[0-9]{2}\][ ]*} $chunk "" chunk
    return $chunk
}

#
# RAG_Manager_extract_chunks goes through a page extracting the body text of
# each chunk. It converts list chunks to markdown lists. It keeps track of the
# chapter, section and date as provided by the sequence of chunks. It adds to
# the start of each chunk the current chapter, section, and date. The extractor
# combines centered tables, all lists, and the contents of "pre" tags with the
# previous chunk, whatever that may have been, and adds no additional metadata.
# It combines centered figures and all equations with the subsequent chunk. By
# the time the page arrives at this chunking routine, all URLs should have been
# converted to Markdown. If there are any anchor or img tags left, something has
# gone wrong. We reject the chunk and count it.
#
proc RAG_Manager_extract_chunks {page catalog} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
	
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
				set chunk [RAG_Manager_extract_list $chunk]
			}
			"ul" {
				set chunk [RAG_Manager_extract_list $chunk]
			}
			"center" {
				set caption [RAG_Manager_extract_caption $chunk]
				if {[regexp {^Table} $caption]} {
					set table [RAG_Manager_extract_table $chunk]
					if {[string length $table] > 0} {
						set chunk "$caption  \n$table"
					} else {
						set chunk "$caption"
					}
					set name "table"
				} elseif {[regexp {^Figure} $caption]} {
					set figures [RAG_Manager_extract_figures $chunk]
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
				set date [RAG_Manager_extract_date $chunk]
				continue
			}
			default {
				if {[regexp {^<b>([^:]+):</b>} $chunk -> bold]} {
					set step $bold
				}
			}
		}
		
		set chunk [RAG_Manager_convert_tags $chunk]
		set chunk [RAG_Manager_remove_dates $chunk]
		set chunk [string trim $chunk]
		if {([string length $chunk] == 0)} {
			RAG_Manager_print "Empty chunk, $chunk_id" brown
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
		RAG_Manager_print "Rejected $rejected chunks with residual anchor and image tags."
	}
	return $chunks
}

#
# RAG_Manager_resolve_relative_url takes a relative url and resolves it into an
# absolute url using a supplied base url. The framework of this code was
# provided by ChatGPT. We enhanced to support internal document links. The base
# url can be a document with extenion php or html and the routine will use the
# document url for internal links.
#
proc RAG_Manager_resolve_relative_url {base_url relative_url} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config

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

   # Process relative navigation. For ".." we go up one directory. For "." we
   # stay in the same directory. For a hash sign followed by anything we create
   # an internal link. By default, we go into a subdirectory or file.
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
# RAG_Manager_resolve_urls resolves all the relative urls in a page into
# absolute urls using the base url we pass in as the basis for resolution. It
# constructs a new page with the absolute urls. It calls
# RAG_Manager_resolve_relative_url on each relative url it finds. The routine
# looks for urls in anchor tags <a> and in image tags <img>. In the final
# resolved url, we replace space characters with the HTML escape sequence "%20".
#
proc RAG_Manager_resolve_urls {page base_url} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config

	set new_page ""
	set index 0
	while {[regexp -indices -start $index {<a +href="([^"]+)"[^>]*>} $page tag url]} {
		append new_page [string range $page $index [expr [lindex $tag 0] - 1]]
		set url [string range $page {*}$url]
		if {![regexp {https?} $url match]} {
			set url [RAG_Manager_resolve_relative_url $base_url $url]
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
			set url [RAG_Manager_resolve_relative_url $base_url $url]
		}
		regsub -all { } $url {%20} url
		append new_page "<img src=\"$url\">"
		set index [expr [lindex $tag 1] + 1]
	}

	append new_page [string range $page $index end]
	return $new_page
}

#
# RAG_Manager_convert_urls finds all the anchors in a page and converts from
# html to markup format, where the title of the anchor is in brackets and the
# url is in parentheses immediately afterwards.
#
proc RAG_Manager_convert_urls {page} {
	upvar #0 RAG_Manager_info info
	regsub -all {<a +href="([^"]+)"[^>]*>([^<]+)</a>} $page {[\2](\1)} page
	regsub -all {<img +src="([^"]+)"[^>]*>} $page {[Figure](\1)} page
	return $page
}

#
# RAG_Manager_chapter_urls converts the "Chapter: Title" at the top of every
# chunk in a chunk list into a markdown anchor with absolute link to the
# chapter. It returns the modified chunks in a new list.
#
proc RAG_Manager_chapter_urls {chunks base_url} {
	upvar #0 RAG_Manager_info info
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
# RAG_Manager_convert_entities converts html entities in a page to unicode
# characters and returns the converted page. We also replace tabs with
# double-spaces.
#
proc RAG_Manager_convert_entities {page} {
	upvar #0 RAG_Manager_info info
    foreach {entity char} $info(entities_to_convert) {
        regsub -all $entity $page $char page
    }
    regsub -all {\t} $page "  " page
    return $page
}

#
# RAG_Manager_html_chunks downloads an html page from a url, splits it into
# chunks of text, and returns a list of chunks.
#
proc RAG_Manager_html_chunks {url} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
		
	RAG_Manager_print "Downloading from $url..." 
	set page [RAG_Manager_read_url $url]
	RAG_Manager_print "Downloaded [string length $page] bytes from $url\." 
	
	RAG_Manager_print "Resolving urls wrt $url..." 
	set page [RAG_Manager_resolve_urls $page $url]
	
	RAG_Manager_print "Converting urls to markdown..." 
	set page [RAG_Manager_convert_urls $page]
	
	RAG_Manager_print "Converting html entities to unicode..." 
	set page [RAG_Manager_convert_entities $page]
	
	RAG_Manager_print "Cataloging chunks, chapters, and dates..." 
	set catalog [RAG_Manager_catalog_chunks $page]
	RAG_Manager_print "Catalog contains [llength $catalog] chunks." 
	
	RAG_Manager_print "Extracting and combining chunks from source page..." 
	set chunks [RAG_Manager_extract_chunks $page $catalog]
	RAG_Manager_print "Extracted [llength $chunks] chunks." 
	
	RAG_Manager_print "Inserting chapter urls..." 
	set chunks [RAG_Manager_chapter_urls $chunks $url]
	RAG_Manager_print "Chunk list complete." 
	
	return $chunks
}

#
# RAG_Manager_store_chunks stores chunks to disk. It takes each chunk in the
# list and uses its contents to obtain a unique hash name for the chunk. It
# stores the chunk to disk in the specified directory with the name hash.txt.
#
proc RAG_Manager_store_chunks {chunks dir} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
	
	RAG_Manager_print "Storing chunks to $dir\..." 
	set count 0
	foreach chunk $chunks {
		set cmd [list echo -n $chunk | openssl dgst -sha1]
		if {[catch {
			set result [eval exec $cmd]
		} error_result]} {
			RAG_Manager_print "ERROR: $error_result"
			RAG_Manager_print $chunk green
			continue
		}
		if {[regexp {[a-f0-9]{40}} $result hash]} {
			set hash [string range $hash 1 $info(hash_len)]
		} else {
			RAG_Manager_print "ERROR: Cannot find hash string in openssl result."
			RAG_Manager_print "RESULT: $result"
			break
		}
		set cfn [file join $dir $hash\.txt]
		set f [open $cfn w]
		puts -nonewline $f $chunk
		close $f
		incr count
		RAG_Manager_print "$count\: $cfn" green
		LWDAQ_support
	}
	RAG_Manager_print "Stored $count chunks." 
	return $count
}

#
# RAG_Manager_embed_chunk submits a chunk, with the help of an access key, to
# the embedding end point and retrieves its embed vector in a json record.
#
proc RAG_Manager_embed_chunk {chunk api_key} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
	
	set tokens [expr [string length $chunk] / $info(token_size)]
	RAG_Manager_print "Embedding $tokens tokens with model $config(embed_model)." brown
    set chunk [string map {\\ \\\\} $chunk]
    set chunk [string map {\" \\\"} $chunk]
    set chunk [string map {\n \\n} $chunk]
    regsub -all {\s+} $chunk " " chunk
	set json_body " \{\n \
		\"model\": \"$config(embed_model)\",\n \
		\"input\": \"$chunk\"\n \}"
	set cmd [list curl -sS -X POST https://api.openai.com/v1/embeddings \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer $api_key" \
		-d $json_body]
	
	if {[catch {
		set result [eval exec $cmd]
	} error_result]} {
		return "ERROR: $error_result"
	}
	return $result
}

#
# RAG_Manager_fetch_embeds makes a list of all chunks in a chunk directory,
# which we assume are the files with extention txt, and another list of all the
# embeddings in an embed directory, which we assume are files with extension
# json, and checks to see if an embed exists for each chunk. If no embed exists,
# the routine reads the chunk, submits the chunk to the embedding end point,
# fetches the embedding, and stores the embedding to disk with the same file
# name root as the chunk. At the end, the routine purges any embeds that have no
# matching chunk remaining.
#
proc RAG_Manager_fetch_embeds {chunk_dir embed_dir api_key} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
		
	set cfl [glob -nocomplain [file join $chunk_dir *.txt]]
	RAG_Manager_print "Found [llength $cfl] chunks on disk."
	set efl [glob -nocomplain [file join $embed_dir *.json]]
	RAG_Manager_print "Found [llength $efl] embeds on disk."
	set new_count 0
	set old_count 0
	set count 0
	RAG_Manager_print "Creating embeds for new paragraphs..."
	foreach cfn $cfl {
		incr count
		set root [file root [file tail $cfn]]
		if {![regexp $root $efl]} {
			set f [open $cfn r]
			set chunk [read $f]
			close $f
			set embed [RAG_Manager_embed_chunk $chunk $api_key]
			if {[LWDAQ_is_error_result $embed]} {
				RAG_Manager_print "ERROR: $embed"
				break
			}
			set efn [file join $embed_dir $root\.json]
			set f [open $efn w]
			puts -nonewline $f $embed
			close $f
			incr new_count
			RAG_Manager_print "$count\: [file tail $cfn] fetched new embed." orange
		} else {
			incr old_count
			RAG_Manager_print "$count\: [file tail $cfn] embed exists." orange
		} 
		LWDAQ_update
	}
	RAG_Manager_print "Checked $count chunks,\
		found $old_count embeds,\
		fetched $new_count embeds."
		
	set efl [glob -nocomplain [file join $embed_dir *.json]]
	set count 0
	foreach efn $efl {
		set root [file root [file tail $efn]]
		if {![regexp $root $cfl]} {
			file delete $efn
			incr count
		}
	}
	RAG_Manager_print "Purged $count expired embeds from disk."
	
	return $count
}

#
# RAG_Manager_vector_from_json takes an embedding json string and extracts its
# embed vector as a Tcl list.
#
proc RAG_Manager_vector_from_embed {embed} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
		
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
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
		
	RAG_Manager_print "Starting dictionary generation at [RAG_Manager_time]."

	RAG_Manager_print "Reading embeds from disk into memory..."
	set efl [glob -nocomplain [file join $embed_dir *.json]]
	set embeds [list]
	foreach efn $efl {
		LWDAQ_support
		set f [open $efn r]
		set embed [read $f]
		close $f
		set vector [RAG_Manager_vector_from_embed $embed]
		lappend embeds [list [file root [file tail $efn]] $vector]
	}
	RAG_Manager_print "Read [llength $efl] embeds from disk into memory."

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
		RAG_Manager_print "$count: [lindex $e1 0] [lrange $comparisons 0 2]" orange
		LWDAQ_update
	}

	RAG_Manager_print "Done with dictionary generation at [RAG_Manager_time]."
	return ""
}

#
# RAG_Manager_json_format takes a string and formats double quotes, newlines,
# backslashes, and multiple white spaces for a json string.
#
proc RAG_Manager_json_format {s} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config

	set s [string map {\\ \\\\} $s]
	set s [string map {\" \\\"} $s]
	set s [string map {\n \\n} $s]
	regsub -all {\s+} $s " " s
	return $s
}

#
# RAG_Manager_get_answer submits a list of chunks and a question to the chat
# completion end point and returns the answer it obtains. It takes as in put
# four mandatory parameters: the question, the list of reference chunks, a
# description of the attitude with which the end point is supposed to answer the
# question, and a key that grants access to the generator. It returns the entire
# result from the end point, as a json record, and leaves it to the calling
# procedure to extract the answer. A fifth optional input is the gpt model. If
# we don't specify, we fall back on the default model specified in
# default_gpt_model.
#
proc RAG_Manager_get_answer {question chunks assistant api_key {model ""}} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
	
	if {$model == ""} {set model $info(default_gpt_model)}
	
	set assistant [RAG_Manager_json_format $assistant]
 	set json_body "\{\n \
		\"model\": \"$model\",\n \
		\"messages\": \[\n   \
		\{ \"role\": \"system\", \"content\": \"$assistant\" \},\n"
	foreach chunk $chunks {
		set chunk [RAG_Manager_json_format $chunk]
		append json_body "    \{ \"role\": \"user\", \"content\": \"$chunk\" \},\n"
	}
	set question [RAG_Manager_json_format $question]
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

#
# RAG_Manager_apply reads the contents of a text window and executes them as a
# Tcl script at the global scope. We can use this routine to reconfigure long
# string parameters such as our assistant instructions. Within the scripts we
# can refer to the RAG Manager configuration and information arrays as "config"
# and "info".
#
proc RAG_Manager_apply {w} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config

	set commands {
		upvar #0 RAG_Manager_info info
		upvar #0 RAG_Manager_config config	
	}
	append commands [string trim [$w.text get 1.0 end]]
	if {[catch {eval $commands} error_result]} {
		RAG_Manager_print "ERROR: $error_result"
	}
	
	return ""
}

#
# RAG_Manager_assistant opens a text window and prints out the declarations of
# the three assistant instructions. We can edit and then apply with an Apply
# button.
#
proc RAG_Manager_assistant {} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
	
	# If the assistant viewing panel exists, destroy it. We are going to make a
	# new one.
	set w $info(window)\.assistant
	if {[winfo exists $w]} {destroy $w}
	
	# Create a new top-level text window that is a child of the main tool
	# window. Bind the Command-a key to save the metadata.
	toplevel $w
	wm title $w "Assistant Instructions, RAG_Manager $info(version)"
	LWDAQ_text_widget $w 80 40
	LWDAQ_enable_text_undo $w.text
	LWDAQ_bind_command_key $w "a" [list RAG_Manager_apply $w]
	
	# Create the Applpy button.
	frame $w.f
	pack $w.f -side top
	button $w.f.apply -text "Apply" -command [list RAG_Manager_apply $w]
	pack $w.f.apply -side left
	
	# Print the assistant instructions for all relevance levels.
	foreach level {high mid low} {
		LWDAQ_print $w.text "set config($level\_rel_assistant) \{\n" blue
		LWDAQ_print $w.text "[string trim $config($level\_rel_assistant)]"
		LWDAQ_print $w.text "\n\}\n" blue
	}
	
	return ""
}

#
# RAG_Manager_sources opens a text window and prints out the source list. We can
# edit and then apply with an Apply button.
#
proc RAG_Manager_sources {} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
	
	# If the source viewing panel exists, destroy it. We are going to make a
	# new one.
	set w $info(window)\.sources
	if {[winfo exists $w]} {destroy $w}
	
	# Create a new top-level text window that is a child of the main tool
	# window. Bind the Command-a key to save the metadata.
	toplevel $w
	wm title $w "Source Documents, RAG_Manager $info(version)"
	LWDAQ_text_widget $w 70 10
	LWDAQ_enable_text_undo $w.text
	LWDAQ_bind_command_key $w "a" [list RAG_Manager_apply $w]
	
	# Create the Applpy button.
	frame $w.f
	pack $w.f -side top
	button $w.f.apply -text "Apply" -command [list RAG_Manager_apply $w]
	pack $w.f.apply -side left
	
	# Print the sources list in the window.
	LWDAQ_print $w.text "set config(sources) \{\n" blue
	LWDAQ_print $w.text "[string trim $config(sources)]"
	LWDAQ_print $w.text "\n\}\n" blue
	
	return ""
}

#
# RAG_Manager_configure opens the tool configuration window, which allows us to
# edit the configuration parameters. These do not include multi-line parameters
# such as the source URL list or the assistant instructions. These multi-line
# parameters are accessed through their own buttons and windows.
#
proc RAG_Manager_configure {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info

	set f [LWDAQ_tool_configure RAG_Manager 3]	
	return ""
}

#
# RAG_Manager_delete deletes all chunks from the chunk directory. It does not
# delete embeddings in the embed directory. Nor does it delete dictionary
# entries from the dict directory. Embeddings are culled during generation.
# Dictionary entries are never culled by these routines. There is no need to
# cull them: they are lists of most similiar chunks derived from an active list
# of embeds.
#
proc RAG_Manager_delete {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info

	if {$info(control) != "Idle"} {return ""}
	set info(control) "Delete"
	RAG_Manager_print "\nDeleting Chunks [RAG_Manager_time]" purple
	set cfl [glob -nocomplain [file join $config(chunk_dir) *.txt]]
	RAG_Manager_print "Found [llength $cfl] chunks."
	set count 0
	foreach cfn $cfl {
		file delete $cfn
		incr count
		LWDAQ_support
	}
	RAG_Manager_print "Deleted $count chunks."
	RAG_Manager_print "Deletion Complete [RAG_Manager_time]" purple
	set info(control) "Idle"
	return "$count"
}

#
# RAG_Manager_generate downloads and chunks all URL resources named in the
# sources list. It submits all chunks for embedding, although the RAG package
# routines will obtain new embeds only for new chunks. In order to embed the
# chunks, this routine must read a valid API key from disk. If dictionary
# retrieval is enabled, the routine generates dictionary entries as well.
# Chunking is fast, but dictionary generation is slow. Be prepared to wait
# several minutes for a dictionary of one thousand chunks to complete.
#
proc RAG_Manager_generate {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info

	if {$info(control) != "Idle"} {return ""}
	set info(control) "Generate"
	RAG_Manager_print "\nGenerate Chunks and Embed Vectors [RAG_Manager_time]" purple
	
	set chunks [list]
	foreach url [string trim $config(sources)] {
		set chunks [concat $chunks [RAG_Manager_html_chunks $url]]
	}
	RAG_Manager_store_chunks $chunks $config(chunk_dir)

	RAG_Manager_print "Reading api key $config(key_file)\." brown
	if {![file exists $config(key_file)]} {
		RAG_Manager_print "ERROR: Cannot find key file $config(key_file)."
		set info(control) "Idle"
		return ""
	}
	set f [open $config(key_file) r]
	set api_key [read $f]
	close $f 
	RAG_Manager_print "Read API key." brown

	RAG_Manager_print "Submitting all chunks for embedding..."	
	RAG_Manager_fetch_embeds $config(chunk_dir) $config(embed_dir) $api_key
	if {$config(dictionary)} {
		RAG_Manager_print "Generating dictionary of related chunks..."	
		RAG_make_dictionary $config(embed_dir) $config(dict_dir)
	}
	
	RAG_Manager_print "Generation Complete [RAG_Manager_time]." purple
	set info(control) "Idle"
	return "[llength $chunks]"
}

#
# RAG_Manager_retrieve obtains the embedding vector for the current question and
# compares this vector to all the vectors in the embed directory, thus making a
# list of chunks and their relevance to the question. It sorts this list so as
# to put the most relevant chunks in front. If we are using dictionary-enhanced
# retrieval, the routine fetches one or more secondary chunks to accompany each
# primary chunk, these secondary chunks being those most similar to a primary
# chunk. Using the front chunk, the routine judges the relevance of the question
# to the source materials. It copies zero or more chunks into a retrieved chunk
# list until the total number of tokens in the chunks is equal to or greater
# than the token limit for the question's level of relevance. It returns the
# list of chunks retrieved. In order to embed the question, this routine must
# read a valid API key from disk.
#
proc RAG_Manager_retrieve {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info
	global RAG_Manager_info

	if {$info(control) != "Idle"} {return ""}
	set question [string trim $config(question)]
	if {$question == ""} {
		RAG_Manager_print "ERROR: Empty question, abandoning retrieval."
		return ""
	}
	
	set info(control) "Retrieve"
	RAG_Manager_print "\nRetrieve Question-Related Data Chunks [RAG_Manager_time]" purple
	
	RAG_Manager_print "Question: $config(question)"
	
	RAG_Manager_print "Reading api key $config(key_file)\." brown
	if {![file exists $config(key_file)]} {
		RAG_Manager_print "ERROR: Cannot find key file $config(key_file)."
		set info(control) "Idle"
		return ""
	}
	set f [open $config(key_file) r]
	set api_key [read $f]
	close $f 
	RAG_Manager_print "Read API key." brown

	RAG_Manager_print "Obtaining question embedding vector..."
	set start_time [clock milliseconds]
	set q_embed [RAG_Manager_embed_chunk $config(question) $api_key]
	set q_vector [RAG_Manager_vector_from_embed $q_embed]
	RAG_Manager_print "Question embed obtained in\
		[expr [clock milliseconds] - $start_time] ms,\
		 reading embed library from disk..."
	
	set start_time [clock milliseconds]
	set efl [glob -nocomplain [file join $config(embed_dir) *.json]]
	set embeds [list]
	foreach efn $efl {
		LWDAQ_support
		set f [open $efn r]
		set embed [read $f]
		close $f
		set vector [RAG_Manager_vector_from_embed $embed]
		lappend embeds [list [file root [file tail $efn]] $vector]
	}

	RAG_Manager_print "Read [llength $efl] embeds in\
		[expr [clock milliseconds] - $start_time] ms,\
		comparing question to embed library..."
	set start_time [clock milliseconds]
	set comparisons [list]
	set len [llength $q_vector]
	foreach embed $embeds {
		LWDAQ_support
		set e_name [lindex $embed 0]
		set e_vector [lindex $embed 1]
		set dot_product 0
		for {set i 0} {$i < $len} {incr i} {
			set x1 [lindex $q_vector $i]
			set x2 [lindex $e_vector $i]
			set dot_product [expr $dot_product + $x1*$x2]
		}
		set relevance [format %.4f $dot_product]
		lappend comparisons "$relevance $e_name"
	}
	RAG_Manager_print "Comparison complete in\
		[expr [clock milliseconds] - $start_time] ms,\
		sorting chunks by relevance..."
	set start_time [clock milliseconds]
	set comparisons [lsort -decreasing -real -index 0 $comparisons]
	set info(relevance) [lindex $comparisons 0 0]

	set r $info(relevance)
	if {$r >= $config(high_rel_thr)} {
		set num $config(high_rel_tokens)
		RAG_Manager_print "High-relevance question, relevance=$r, retrieve $num\+ tokens." 
	} elseif {$r >= $config(low_rel_thr)} {
		set num $config(mid_rel_tokens)
		RAG_Manager_print "Mid-relevance question, relevance=$r, retrieve $num\+ tokens." 
	} else {
		set num $config(low_rel_tokens)
		RAG_Manager_print "Low-relevance question, relevance=$r, retrieve $num\+ tokens." 
	}
	
	if {$config(dictionary)} {
		RAG_Manager_print "Using dictionary to retrieve related chunks..."
		set new_list [list]
		foreach c [lrange $comparisons 0 20] {
			if {[lsearch -index 1 $new_list [lindex $c 1]] < 0} {
				lappend new_list $c
			}
			set dfn [file join $config(dict_dir) [lindex $c 1]\.txt]
			if {![file exists $dfn]} {
				RAG_Manager_print "ERROR: Cannot find dictionary file [file tail $dfn]."
				set info(control) "Idle"
				return ""
			}
			set f [open $dfn r]
			set dict [read $f]
			close $f
			foreach cc [lrange $dict 0 1] {
				set rel [lindex $cc 0]
				set name [lindex $cc 1]
				if {[lsearch -index 1 $new_list $name] < 0} {lappend new_list $cc}
			}
		}
		set comparisons $new_list
	}
	
	RAG_Manager_print "List of chunks retrieved to support question." brown
	set index 0
	set count 0
	set tokens 0
	set data [list]
	foreach comparison $comparisons {
		if {$tokens >= $num} {break}
		incr count
		RAG_Manager_print "-----------------------------------------------------" brown
		RAG_Manager_print "$count\: Relevance [lindex $comparison 0]:" brown
		set embed [lindex $comparison 1]
		set cfn [file join $config(chunk_dir) $embed\.txt]
		if {![file exists $cfn]} {
			if {$count == 1} {
				RAG_Manager_print "ERROR: Most relevant chunk missing, [file tail $cfn]."
				incr count -1
				break
			} else {
				RAG_Manager_print "WARNING: No chunk exists for embed $embed."
				continue
			}
		}
		set f [open $cfn r]
		set chunk [read $f]
		close $f
		lappend data "$config(chunk_title)$chunk"
		RAG_Manager_print $chunk green
		set tokens [expr $tokens + ([string length $chunk]/$RAG_Manager_info(token_size))]
	}

	if {$config(chat_submit)} {
		RAG_Manager_print "-----------------------------------------------------" brown
		RAG_Manager_print "Adding chat history to document chunks:" brown
		RAG_Manager_print $info(chat) green	
		lappend data "config(chat_title)$info(chat)"
		set tokens [expr $tokens + ([string length $info(chat)]/$RAG_Manager_info(token_size))]	
	}
	
	RAG_Manager_print "-----------------------------------------------------" brown

	set info(data) $data
	set info(control) "Idle"
	RAG_Manager_print "Retrieval complete, $count chunks, $tokens tokens [RAG_Manager_time]." purple
	return [llength $data]
}

#
# RAG_Manager_submit combines the question and the assistant instructions with
# the retrieved data, all of which are stored in elements of the info array, and
# passes them to the RAG package for submission to the completion end point. In
# order to submit the question, this routine must read a valid API key from
# disk. Once we receive a response from the completion end point, we try to
# extract an answer from the response json record. If we succeed, then format
# the answer for Markdown. We convert backslash-n-backslash-r to newline,
# backslash-r to newline, backslash-n to newline, backlash-t to tab,
# backslash-double-quote to double-quote, single newline with no preceding
# whitespace to double-space-newline. We replace solitary asterisks with
# multiplication symbols and we add two spaces to the end of any line with three
# backticks, so that we get a blank line after code samples. If we can't extract
# the answer then we try to extract an error message and report the error. If we
# can't extract an error message, we return a failure error message of our own.
#
proc RAG_Manager_submit {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info
	global RAG_Manager_info

	if {$info(control) != "Idle"} {return ""}
	set question [string trim $config(question)]
	if {$question == ""} {
		RAG_Manager_print "ERROR: Empty question, abandoning submission."
		return ""
	}
	if {[string length $question]/$RAG_Manager_info(token_size) \
			> $config(max_question_tokens)} {
		set answer "ERROR: Question is longer than\
			[expr $config(max_question_tokens)*$RAG_Manager_info(token_size)] characters."
		return $answer
	}
	
	set info(control) "Submit"
	RAG_Manager_print "\nSubmit Question and Data to\
		Completion End Point [RAG_Manager_time]" purple
	RAG_Manager_print "Choosing answer model and assistant instructions..."
	set r $info(relevance)
	if {$r >= $config(high_rel_thr)} {
		set model $config(high_rel_model)
		set assistant [string trim $config(high_rel_assistant)]
		RAG_Manager_print "High-relevance question, relevance=$r,\
			use $model and high-relevance instructions." 
	} elseif {$r >= $config(low_rel_thr)} {
		set model $config(mid_rel_model)
		set assistant [string trim $config(mid_rel_assistant)]
		RAG_Manager_print "Mid-relevance question, relevance=$r,\
		 	use $model and mid-relevance instructions." 
	} else {
		set model $config(low_rel_model)
		set assistant [string trim $config(low_rel_assistant)]
		RAG_Manager_print "Low-relevance question, relevance=$r,\
		 	use $model and low-relevance instructions." 
	}
	RAG_Manager_print "Assistant instructions being submitted with this question:" brown
	RAG_Manager_print "$assistant" green

	RAG_Manager_print "Reading api key $config(key_file)\." brown
	if {![file exists $config(key_file)]} {
		set answer "ERROR: Cannot find key file $config(key_file)."
		set info(control) "Idle"
		return $answer
	}
	set f [open $config(key_file) r]
	set api_key [read $f]
	close $f 
	RAG_Manager_print "Read API key." brown
	
	RAG_Manager_print "Submitting question with [llength $info(data)] chunks..."
	append info(chat) "Question: [string trim $question]\n"
	set info(result) [RAG_Manager_get_answer $question\
		$info(data) $assistant $api_key $model]
	set len [expr [string length $info(result)]/$RAG_Manager_info(token_size)]
	RAG_Manager_print "Received $len tokens,\
		extracting answer and formatting for Markdown."
		
	if {[regexp {"content": *"((?:[^"\\]|\\.)*)"} $info(result) match answer]} {
		set num [regsub -all {\\r\\n|\\r|\\n} $answer "\n" answer]
		RAG_Manager_print "Replaced $num \\r and \\n sequences with newlines." brown
		set num [regsub -all {\\\"} $answer "\"" answer]
		RAG_Manager_print "Replaced $num \\\\ with backslash." brown
		set num [regsub -all {\s+\*\s+} $answer { × } answer]
		RAG_Manager_print "Replaced $num solitary asterisks with ×." brown
		set num [regsub -all {([^\n]+)\n(?!\n)} $answer "\\1  \n" answer]
		RAG_Manager_print "Added spaces to the end of $num lines." brown
	} elseif {[regexp {"message": *"((?:[^"\\]|\\.)*)"} $info(result) match message]} {
		set answer "ERROR: $message"
	} else {
		set answer "ERROR: Could not find answer or error message in result."
	}
 	append info(chat) "Answer: [string trim $answer]\n\n"

	RAG_Manager_print "Submission Complete [RAG_Manager_time]" purple
	set info(control) "Idle"

	RAG_Manager_print "\nAnswer to \"$question\":" purple
	RAG_Manager_print $answer 
	RAG_Manager_print "End of Answer" purple
	
	return $answer
}

#
# RAG_Manager_history prints the history of questions and answers since this
# instance of the RAG Manager started. If the verbose flag is set, the routine
# also adds the complete json record returned from the end point in response to
# the most recent question submission.
#
proc RAG_Manager_history {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info
	global RAG_Manager_info

	if {$info(control) != "Idle"} {return ""}
	set info(control) "History"
	RAG_Manager_print "\n------------- Chat History -------------------------" purple
	RAG_Manager_print [string trim $info(chat)]
	if {$config(verbose)} {
		RAG_Manager_print "------ Full Text of Previous Question Result --------" purple
		RAG_Manager_print $info(result)
	}
	RAG_Manager_print "-----------------------------------------------------" purple
	set info(control) "Idle"
	return [expr [string length $info(chat)] / $RAG_Manager_info(token_size)]
}

#
# RAG_Manager_open opens the tool window and creates the graphical user interface.
#
proc RAG_Manager_open {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info
		
	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
		
	set f [frame $w.control]
	pack $f -side top -fill x
	
	label $f.control -textvariable RAG_Manager_info(control) -fg blue -width 8
	pack $f.control -side left -expand yes

	foreach a {Sources Delete Generate Retrieve Assistant Submit History} {
		set b [string tolower $a]
		button $f.$b -text "$a" -command "RAG_Manager_$b"
		pack $f.$b -side left -expand yes
	}
	
	foreach a {Verbose Dictionary} {
		set b [string tolower $a]
		checkbutton $f.$b -text "$a" -variable RAG_Manager_config($b)
		pack $f.$b -side left -expand yes
	}

	button $f.config -text "Configure" -command "RAG_Manager_configure"
	pack $f.config -side left -expand yes
	button $f.help -text "Help" -command "LWDAQ_tool_help RAG_Manager"
	pack $f.help -side left -expand yes
	
	foreach a {Question} {
		set b [string tolower $a]
		set f [frame $w.$b]
		pack $f -side top
		label $f.l$b -text "$a\:" -fg green
		entry $f.e$b -textvariable RAG_Manager_config($b) -width 140
		pack $f.l$b $f.e$b -side left -expand yes
	}
			
	set info(text) [LWDAQ_text_widget $w 140 40]
	LWDAQ_print $info(text) "$info(name) Version $info(version)" purple
	
	return $w	
}

RAG_Manager_init
RAG_Manager_open

return ""

----------Begin Help----------

The RAG Manager provides the routines we use at to support the OSI Chatbot. The
acronym "RAG" stands for "Retrieval-Assisted Generation", where "generation" is
the composing of an answer to a question by a large language model (LLM), and
"retrieval-assistance" is gathering exerpts relevant to the question from our
documentation. In the jargon of retrieval-assisted generation, these exerpts are
called "chunks". The chat web interface is provided by a PHP process running on
our server and some JavaScript running on the client web browser. When the user
provides a new question, the server calls LWDAQ to collect relevant chunks,
submit them to the LLM, and wait for an answer.

The key to retrieval-assisted generation is the ability of the LLM to classify
the content of an chunk with a point on a large-dimensional sphere. We use
OpenAI's RAG service, and their classification is a point in a 1536-dimensional
space. We submit an chunk to the OpenAI "embedding end point" and receive in
response an "embedding vector", which consists of 1536 numbers representing the
components of a unit vector in a 1536-dimensional space. Retrieval-assisted
generation operates on the assumptioin that similarity of embedding vectors is
an accurate measure of similarity of subject matter. That is: if the angle
between two embedding vectors is small, the two chunks they were derived from
will be discussing a similar topic. In particular: if the embedding vector of a
question is close to the embedding vector of an chunk, that chunk is relevant to
the question, and should be used as a basis for answering the question.

We measure the proximity of two embedding vectors by taking their dot product.
Because all embedding vectors are normalized before delivery, their dot product
is equal to the cosine of the angle between them. Our measure of "relevance" for
a chunk is the cosine of the angle between the chunk embedding vector and the
question embedding vector. Two identical chunks have relevance 1.0. In principle
a chunk could have relevance -1. In our experience, if the best chunk in our
library has relevance 0.5 or greater, it is almost certainly a question about
our products. If the relevance is between 0.3 and 0.5 is may be a question about
our products, but if less than 0.3, the question is almost certainly or general
question that cannot be answered by our chatbot library.

Before we generate a new chunk libary, we must provide the RAG Manager with a
list of URLs from which it should download the documents out of which it will
create the library. The RAG Manager window, which appears when you open the RAG
manager from a graphical instance of LWDAQ, provides a Source button that allows
you to define and apply a list of URLs. When the list is "applied" it is saved
in the RAG Manager's internal array, but the URLs are not yet accessed.

Once we have our list of URLs, we use the Delete button to delete the old
library. All the chunks will be delete, but none of the embedding vectors. The
chunks are stored in a chunk directory, the embedding vectors in an embed
directory. Both these directories are defined in the configuration array of the
tool.

We press Generate. Here we don't mean "generate an answer", we mean "generate
the chunk and embedding vector library". We apologise for the duplicate use of
the word "generate". The RAG Manager uses the command-line "curl" utility to
download all the HTML pages using their URLs. The "curl" utility supports both
https and http. We test the RAG Manager on Linux and MacOS, both of which are
UNIX variants with "curl" installed. We do not test the RAG Manager on Windows.
The RAG Manager proceeds one URL at a time, dividing each page into chunks.
Check "verbose" to see the notification and type of every chunk created. 

The simplest chunk extraction is to isolate an HTML paragraph using p-tags. Our
HTML documentation is all hand-typed and follows particular, strict patterns
when it comes to tables, lists, figures, and chapter titles. We include dates at
the beginning of chapters in a particular format to indicate when the chapter
was last updated. Thus we are able to extract paragraphs, lists, captions, and
code samples in a uniform and consistent mannger for our chunk library, with
every chunk given a chapter name, a URL pointing to the chapter on-line, and
often a last-modified data as well. We translate the chunks from HTML into
Markdown. This translation includes all URLs. We resolve all relative URLs and
internal document links to absolute URLs. The answer we get back from the
completion end-point will also be in Markdown. The OpenAI LLM likes Markdown.

Once all the chunks are generated, the RAG Manager calls "openssl" to provide a
unique name for each chunk, and stores the chunks in the chunk directory with
names of the form 6270ebd71f0b.txt.

Now that the generation process has produced all the chunks of the library, it
checks each chunk to see if it has an embedding vector in the embed directory.
The embedding vector will be named like 6270ebd71f0b.json. If the embed exists,
the chunk is ready to deploy. If the embedding vector does not exist, the
generator submits the chunk to the OpenAI embedding end-point, obtains its
embedding vector, and writes the vector to disk in the embed directory. To
obtain the vector, we need an API Key, which is the means by which we identify
ourselves to OpenAI and agree to pay for the embedding service. Embedding is
inexpensive. At the time of writing, we are using the "text-embedding-3-small"
model at a cost of $0.00002 per one thousand tokens, where a "token" is four
characters. So one thousand chunks, each one thousand tokens long, will cost a
total of two cents to embed.

The last stage of generation is to eliminate embedding vectors for which there
is no corresponding chunk. Now we have a complete library of chunks and
embedding vectors ready for RAG.

The RAG Manager provides instructions to the OpenAI "completion end-point",
which is the server tha answers questions. In the RAG Manager window, press
Assistant and you will be able to edit the instructions we will provide for
high, mid, and low-relevance questions.

Enter a question in the question entry box and press Retrieve. The RAG Manager
will obtain the embedding vector of the question and compare it to every
embedding vector in the embed directory. It sorts the embeds in order of
decreasing relevance and starts taking the most relevant until it accumulates a
number of tokens as specified by the RAG Manager token limits. The token limits
are different for the three levels of question relevance. If the submit_chat
flag is set, the manager adds the chat history to submission data. In the online
chatbot implementation, we submit the previous two questions and answers to give
continuity to the chat. Note that the question has not yet been submitted. We
have separated the retrieval and submission so that we can examine the retrieved
chunks without waiting for a submission to complete. With the verbose flag set,
we get to see all the chunks and the chat history.

Press Submit and the RAG Manager puts together the assistant instructions, the
documentation chunks, and the question in one big json record, submits them to
the OpenAI completion end-point as one big json record and waits for an answer.
For high-relevance questions, we are currently using the "gpt-4" completion
model, which costs $0.01 per thousand input tokens (assistant, chunk, question
and chat) and $0.03 per thousand output tokens (the answer). For mid and
low-relevance questions, we use the "gpt-3.5-turbo" model at a cost of $0.0005
per thousand input tokens and $0.0015 per thousand output tokens. Our default is
to send roughly 3400 input tokens for a high-relevance question, and we see
about 200 tokens in response, so our average high-relevance answer costs us
rouhly four cents.

Copyright (C) 2025, Kevan Hashemi, Open Source Instruments Inc.

----------End Help----------

