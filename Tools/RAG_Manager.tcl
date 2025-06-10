# Retrieval-Assisted Generation Manager, a LWDAQ Tool.
#
# Copyright (C) 2025 Kevan Hashemi, Open Source Instruments Inc.

# RAG Check provides an interface for our Retrieval Access Generation (RAG)
# routines, provided by our RAG package.

# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.

# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

# You should have received a copy of the GNU General Public License along with
# this program. If not, see <https://www.gnu.org/licenses/>.

proc RAG_Manager_init {} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config

#
# Set up the RAG Manager in the LWDAQ tool system.
#
	LWDAQ_tool_init "RAG_Manager" "3.7"
	if {[winfo exists $info(window)]} {return ""}
#
# Directory locations for key, chunks, embeds.
#
	set config(root_dir) "~/Active/RAG"
	set config(key_file) [file join $config(root_dir) "Key/OpenAI_API.txt"]
#
# The default question.
#
	set config(question) "Calculate the operating life of an A3048 SCT\
		with 160-Hz bandwidth and mass 2 g."
#
# Internal flags, lists, and control variables.
#
	set info(control) "Idle"
	set info(engine_ctrl) "Idle"
	set info(chat) ""
	set info(result) ""
	set info(text) "stdout"
	set info(contents) ""
	set info(relevance) "0.0"
	set info(signal_time) "0"
	set info(signal_s) "2"
	set info(rand_fn_scale) "1000000"
	set info(retrieval_giveup_ms) "1000"
	set info(retrieval_check_ms) "10"
	set info(library_loaded) "0"
	set info(reload_s) "3600"
	set info(reload_time) "0"
#
# Public control flags.
#
	set config(chat_submit) "3"
	set config(verbose) "0"
	set config(show_match) "0"
	set config(snippet_len) "45"
	set config(progress_frac) "0.1" 
#
# The source documents. Can be edited with a dedicated window and saved to
# settings file.
#
	set config(sources) {

https://www.opensourceinstruments.com/Electronics/A3017/SCT.html
https://www.opensourceinstruments.com/Electronics/A3038/M3038.html
https://www.opensourceinstruments.com/Electronics/A3042/M3042.html
https://www.opensourceinstruments.com/Electronics/A3047/M3047.html
https://www.opensourceinstruments.com/Electronics/A3048/M3048.html
https://www.opensourceinstruments.com/Electronics/A3049/M3049.html
https://www.opensourceinstruments.com/Electronics/A3040/M3040.html
https://www.opensourceinstruments.com/Electronics/A3040/EIF.html
https://www.opensourceinstruments.com/Electronics/A3018/Neuroplayer.html
https://www.opensourceinstruments.com/Electronics/A3018/Neurorecorder.html
https://www.opensourceinstruments.com/Electronics/A3018/Receiver.html
https://www.opensourceinstruments.com/Electronics/A3019/Electrodes.html
https://www.opensourceinstruments.com/Electronics/A3013/Flexible_Wires.html
https://www.opensourceinstruments.com/IST/Manual.html
https://www.opensourceinstruments.com/Electronics/A3041/Stimulator.html
https://www.opensourceinstruments.com/Electronics/A3041/M3041.html
https://www.opensourceinstruments.com/Electronics/A3036/M3036.html
https://www.opensourceinstruments.com/ACC/Manual.html
https://www.opensourceinstruments.com/Electronics/A3034/Videoarchiver.html
https://www.opensourceinstruments.com/Electronics/A3034/M3034.html
https://www.opensourceinstruments.com/About/about.php
https://www.opensourceinstruments.com/Software/LWDAQ/Manual.html
https://www.bndhep.net/Devices/BCAM/User_Manual.html

	}
#
# Configuration for retrieval and submission based upon relevance of the question
# to the chunk library. We have three tiers of relevance: high, mid, and low.
#	
	set config(high_rel_thr) "0.50"
	set config(low_rel_thr) "0.30"
	set config(high_rel_model) "gpt-4o"
	set config(mid_rel_model) "gpt-3.5-turbo"
	set config(low_rel_model) "gpt-3.5-turbo"
	set config(high_rel_tokens) "6000"
	set config(mid_rel_tokens) "10000"
	set config(low_rel_tokens) "0"
	set config(max_question_tokens) "300"
	set config(embed_model) "text-embedding-3-small"
#
# Titles for content we submit to completion end point.
#	
	set config(chunk_title) "### Documentation Chunk\n\n"
	set config(chat_title) "### Previous Q&A\n\n"
#
# Completion assistant instructions for the three tiers of relevance. Can be
# edited with a dedicated window and saved to settings file.
#
	set config(high_rel_assistant) {
	
You are a helpful technical assistant.
You will summarize and explain technical documentation.
You will complete mathematical calculations whenever possible.
When answering the user's question:
  - If the question asks for a figure, graph, or image
    and a relevant figure is available in the provided content,
    include the figure in your response like this:  
    `![Figure Caption](image_url)`  
  - Do not say "you cannot search the web" or "you cannot find images" if a 
    relevant figure is available in the provided content.
  - Provide hyperlinks to original documentation sources when available.
  - Prefer newer information over older.
  - Respond using Markdown formatting.
  - Use LaTeX formatting within Markdown for mathematical expressions.
  - Use the minimal escaping required to represent valid LaTeX.
    }
	set config(mid_rel_assistant) {
	
You are a helpful technical assistant.
You will summarize and explain technical documentation.
You will complete mathematical calculations whenever possible.
Respond using Markdown formatting.
When writing mathematical expressions.
Use LaTeX formatting within Markdown for mathematical expressions.

	}
	set config(low_rel_assistant) {
	
You are a helpful technical assistant.
You will summarize and explain technical documentation.
You will complete mathematical calculations whenever possible.
Respond using Markdown formatting.
When writing mathematical expressions.
Use LaTeX formatting within Markdown for mathematical expressions.

	}
#
# A list of html entities and the unicode characters we want to replace them
# with.
#
	set info(entities_to_convert) {
		&Alpha;     "Α"
		&alpha;     "α"
		&Beta;      "Β"
		&beta;      "β"
		&Gamma;     "Γ"
		&gamma;     "γ"
		&Delta;     "Δ"
		&delta;     "δ"
		&Epsilon;   "Ε"
		&epsilon;   "ε"
		&Zeta;      "Ζ"
		&zeta;      "ζ"
		&Eta;       "Η"
		&eta;       "η"
		&Theta;     "Θ"
		&theta;     "θ"
		&Iota;      "Ι"
		&iota;      "ι"
		&Kappa;     "Κ"
		&kappa;     "κ"
		&Lambda;    "Λ"
		&lambda;    "λ"
		&Mu;        "Μ"
		&mu;        "μ"
		&Nu;        "Ν"
		&nu;        "ν"
		&Xi;        "Ξ"
		&xi;        "ξ"
		&Omicron;   "Ο"
		&omicron;   "ο"
		&Pi;        "Π"
		&pi;        "π"
		&Rho;       "Ρ"
		&rho;       "ρ"
		&Sigma;     "Σ"
		&sigma;     "σ"
		&sigmaf;    "ς"
		&Tau;       "Τ"
		&tau;       "τ"
		&Upsilon;   "Υ"
		&upsilon;   "υ"
		&Phi;       "Φ"
		&phi;       "φ"
		&varphi;    "ϕ"
		&Chi;       "Χ"
		&chi;       "χ"
		&Psi;       "Ψ"
		&psi;       "ψ"
		&Omega;     "Ω"
		&omega;     "ω"
		&plusmn;    "±"
		&div;       "÷"
		&amp;       "&"
		&nbsp;      " "
		&pi;        "π"
		&lt;        "<"
		&gt;        ">"
		&le;        "≤"
		&ge;        "≥"
		&asymp;     "≈"
		&infin;     "∞"
		&times;     "×"
		&deg;       "°"
		&middot;    "·"
		&minus;     "−"
		&radic;     "√"
		&asymp;     "≈"
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
		sup "^"
		/sup ""
		sub "_"
		/sub ""
		span ""
		/span ""
		font ""
		/font ""
		big ""
		/big ""
		bold ""
		/bold ""
		em ""
		/em ""
		eq ""
		/eq ""
		prompt ""
		/prompt ""
	}
#
# The chunk delimiting tags.
#
	set info(chunk_tags) {p center pre equation ul ol h2 h3}
#
# Input-output parameters.
#	
	set info(hash_len) "12"
	set info(token_size) "4"
	set info(embed_scale) "100000"
	set info(retrieve_len) "500" 
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
# Configure the file locations based upon the root.
#
	set info(content_dir) [file join $config(root_dir) "Content"]
	set info(match_dir) [file join $config(root_dir) "Match"]
	set info(embed_dir) [file join $config(root_dir) "Embed"]
	set info(log_dir) [file join $config(root_dir) "Log"]
	set info(signal_file) [file join $info(log_dir) "signal.txt"]
#
# Empty string return means all well.
#
	return ""	
}

# 
# RAG_Manager_time provides a timestamp for log messages. It accepts a UNIX time,
# or will default to current UNIX time.
#
proc RAG_Manager_time {{ts ""}} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config

	if {$ts == ""} {set ts [clock seconds]}
	return [clock format $ts]
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
# RAG_Manager_snippet returns a snippet of text from a page, starting from
# a provided index. We extract text from the page, replace all newlines with
# spaces, trim, and return.
#
proc RAG_Manager_snippet {page index} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config

	set snippet [string range $page $index [expr $index + $config(snippet_len)]]
	set snippet [string trim [regsub -all {\n} $snippet " "]]
	return $snippet
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
proc RAG_Manager_assistant_prompts {} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
	
	# If the assistant viewing panel exists, destroy it. We are going to make a
	# new one.
	set w $info(window)\.assistant
	if {[winfo exists $w]} {destroy $w}
	
	# Create a new top-level text window that is a child of the main tool
	# window. Bind the Command-a key to save the metadata.
	toplevel $w
	wm title $w "Assistant Prompts, RAG_Manager $info(version)"
	LWDAQ_text_widget $w 100 40
	LWDAQ_enable_text_undo $w.text
	LWDAQ_bind_command_key $w "a" [list RAG_Manager_apply $w]
	
	# Create the Applpy button.
	frame $w.f
	pack $w.f -side top
	button $w.f.apply -text "Apply" -command [list RAG_Manager_apply $w]
	pack $w.f.apply -side left
	
	# Print the assistant prompts for all relevance levels.
	foreach level {high mid low} {
		LWDAQ_print $w.text "set config($level\_rel_assistant) \{\n" blue
		LWDAQ_print $w.text "[string trim $config($level\_rel_assistant)]"
		LWDAQ_print $w.text "\n\}\n" blue
	}
	
	return ""
}

#
# RAG_Manager_source_urls opens a text window and prints out the source list. We can
# edit and then apply with an Apply button.
#
proc RAG_Manager_source_urls {} {
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
	LWDAQ_text_widget $w 100 10
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
# RAG_Manager_set_root takes a directory name as input. If this name is an empty
# string or omitted, it opens a browser window to allow us to pick a directory
# to act as the RAG Manager's root directory. If this directory contains the
# Content, Match, Embed, and Log directories, so much the better, but if not,
# this procedure will create them. The procedure returns the current root
# directory, whether it has been changed or not.
#
proc RAG_Manager_set_root {{rdn ""}} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info

	if {$info(control) != "Idle"} {return ""}
	set info(control) "Root_Dir"
	RAG_Manager_print "Choosing Root Directory [RAG_Manager_time]" purple

	if {$rdn == ""} {
		set rdn [LWDAQ_get_dir_name $config(root_dir)]
	}
	
	if {![file exists $rdn]} {
		RAG_Manager_print "ERROR: Directory \"$rdn\" does not exist."
		set info(control) "Idle"
		return $config(root_dir)
	}
	
	set config(root_dir) $rdn
	RAG_Manager_print "Root Directory: $rdn"
	if {[catch {
		foreach sdn {Content Match Embed Log} {
			set sdn [file join $config(root_dir) $sdn]
			if {[file exists $sdn]} {
				RAG_Manager_print "Found $sdn"
			} else {
				file mkdir $sdn
				RAG_Manager_print "Created $sdn"
			}
		}
	} error_message]} {
		RAG_Manager_print "ERROR: $error_message"
		set info(control) "Idle"
		return $rdn
	}
	
	set info(content_dir) [file join $config(root_dir) "Content"]
	set info(match_dir) [file join $config(root_dir) "Match"]
	set info(embed_dir) [file join $config(root_dir) "Embed"]
	set info(log_dir) [file join $config(root_dir) "Log"]
	
	RAG_Manager_print "New root directory established [RAG_Manager_time]" purple
	set info(control) "Idle"
	return $rdn
}

#
# RAG_Manager_set_key selects the key file we need to access endpoints.
#
proc RAG_Manager_set_key {{kfn ""}} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info

	if {$info(control) != "Idle"} {return ""}
	set info(control) "Key_File"
	RAG_Manager_print "Choosing Key File [RAG_Manager_time]" purple

	if {$kfn == ""} {
		set kfn [LWDAQ_get_file_name]
	}
	
	if {![file exists $kfn]} {
		RAG_Manager_print "ERROR: File \"$kfn\" does not exist."
		set info(control) "Idle"
		return $config(key_file)
	}
	
	set config(key_file) $kfn
	RAG_Manager_print "Key File: $kfn"

	RAG_Manager_print "New key file chosen [RAG_Manager_time]" purple
	set info(control) "Idle"
	return $kfn
}

#
# RAG_Manager_configure opens the tool configuration window, which allows us to
# edit the configuration parameters. Additional buttons give access to multi-line
# parameters, like the source url list and the assistant prompts. Another button
# purges obsolete embeds from the embed directory.
#
proc RAG_Manager_configure {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info

	set f [LWDAQ_tool_configure RAG_Manager 3]

	foreach a {Set_Root Set_Key Source_URLs Assistant_Prompts Purge_Embeds} {
		set b [string tolower $a]
		button $f.$b -text "$a" -command "LWDAQ_post RAG_Manager_$b"
		pack $f.$b -side left -expand yes
	}
		
	return ""
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
# RAG_Manager_convert_urls finds all the anchors in a page and converts from
# html to markup format, where the title of the anchor is in brackets and the
# url is in parentheses immediately afterwards.
#
proc RAG_Manager_convert_urls {page} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
	
	regsub -all {<img +src="([^"]+)"[^>]*>} $page {[Figure](\1)} page
	regsub -all {<a +href="([^"]+)"[^>]*>([^<]+)</a>} $page {[\2](\1)} page
	return $page
}

#
# RAG_Manager_locate_field goes to the index'th character in a page and searches
# forward for the first occurance of the named tag opening, looks further for
# the same tag to close. If there are further openings of the same tag before
# the closing, the routine keeps track of these and so finds the closing tag
# that corresponds to the original opening. The routine returns the locations of
# four characters in the page. These are the begin and end characters of the
# body of the field, and the begin and end characters of the field including the
# tags. If an opening tag exits, but no end tag, the routine returns the entire
# remainder of the page as the contents of the field.
#
proc RAG_Manager_locate_field {page index tag} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config

	set i_field_begin [string length $page]
	set i_field_end $i_field_begin
	set i_body_begin $i_field_begin
	set i_body_end $i_field_begin

	set tag_pattern "</?\\s*$tag\(>|\\s+\[^>\]*>\)"
	set tag_indices [regexp -all -inline -indices -start $index $tag_pattern $page]
	set warning_given 0
	set open_count -1
	if {[llength $tag_indices] > 0} {
		foreach {ax bx} $tag_indices {
			lassign $ax start end
			set key [string range $page $start $end]
			if {[regexp {^</} $key]} {
				if {$open_count > 0} {
					incr open_count -1
					set i_body_end [expr $start - 1]
					set i_field_end $end
				}
			} else {
				if {$open_count == -1} {
					set i_field_begin $start
					set i_body_begin [expr $end + 1]
					set open_count 1
				} else {
					incr open_count 1
				}
			}
			if {$open_count == 0} {break}
			if {($open_count > 1) && !$warning_given \
					&& ($tag != "ul") && ($tag != "ol")} {
				RAG_Manager_print "WARNING: Nested <$tag>\
					\"[RAG_Manager_snippet $page $i_field_begin]\""
				set warning_given 1
			}
		}
	}
	if {($open_count > 0) && !$warning_given} {
		RAG_Manager_print "WARNING: Unclosed <$tag>\
			\"[RAG_Manager_snippet $page $i_field_begin]\""
	}
	return "$i_body_begin $i_body_end $i_field_begin $i_field_end"
}

#
# RAG_Manager_list_bodies calls the locate-field routine repeatedly to obtain
# list of all field bodies with a specified tag within a supplied document. The
# routine does not ignore empty bodies, but adds them to the list.
#
proc RAG_Manager_list_bodies {page tag} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
	
	set location 0
	set bodies [list]
	while {$location < [string length $page]} {
		set indices [RAG_Manager_locate_field $page $location $tag]
		lassign $indices i_body_begin i_body_end i_field_begin i_field_end
		set location [expr $i_field_end + 1]
		set field_len [expr $i_field_end - $i_field_begin]
		if {$field_len > 0} {
			set body [string range $page $i_body_begin $i_body_end]
			set body [string trim $body]
			lappend bodies $body
		}
	}
	return $bodies
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
# RAG_Manager_extract_caption looks for a table, figure, or video caption beginning with
# bold "Table:", "Figure:", or "Video:". It extracts the text of the caption and returns
# with "Table: ", "Figure: ", or "Video: ".
#
proc RAG_Manager_extract_caption {chunk} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
	
	set caption ""
	if {[regexp {<b>(Table|Figure|Video):</b>(.+?)</small>} $chunk -> type caption]} {
		return "$type: [string trim $caption]"
	} else {
		return ""
	}
}

#
# RAG_Manager_extract_figures looks for figure links and creates an inline image
# reference reference to go with a figure caption, one for each image.
#
proc RAG_Manager_extract_figures {content} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
	
	set i 0
	set images ""
	while {$i < [string length $content]} {

		if {[regexp -indices -start $i {\[Figure\]\(([^)]*)\)} $content img url]} {
			set i [lindex $img 1]
			incr i
			set img [string range $content {*}$img]
			append images "!$img  \n"
		} else {
			break
		}
	}
	return [string trim $images]
}

#
# RAG_Manager_extract_video looks for a Markdown anchor. It takes everything
# inside the biggest pair of square brakets it can find, followed by a term in
# parentheses. Thus it will get the Markdown representation of a clickable
# image.
#
proc RAG_Manager_extract_video {content} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
	
	if {[regexp {\[.+\]\(([^)]*)\)} $content vid url]} {
		return [string trim $vid]
	} else {
		return ""
	}
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
        regsub -all "<$tag\[^>\]*?>" $chunk $replace chunk
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
# RAG_Manager_extract_chunks goes through a page extracting chunks of text from
# the provided page. By the time the page arrives at this chunking routine, all
# URLs should have been converted to Markdown. If there are any anchor or img
# tags left, something has gone wrong. We reject the chunk and count it. This
# routine converts HTML lists to markdown lists. It keeps track of the chapter,
# section and date using <h2>, <h3>, and our own [01-JAN-69] date entries
# respectively. It extracts entire sections in <center> fields because these
# should consist only of figures and tables in our documents. Once it has a raw
# list of chunks, it begins to process them by further extraction, such as
# extracting table and figure captions, and extracting hyper links. The
# extractor appends <pre>, <ul>, and <oL> chunks with the previous chunk
# provided the previous chunk was a <p> field. They will share the same chapter,
# section, and date fields. Otherwise these chunks are stored alone with their
# own chapter, section, and date fields. Tables and figures are always kept in
# their own chunks. It combines equations with the subsequent chunk, whatever
# that chunk may be, and the subsequent chunk shares the metadata of the
# equation chunk. The routine constructs a chunk list. Each chunk list entry
# consists of two strings: a match string and a content string. The match string
# contains text stripped of metadata or tables of numbers or web links. This is
# the string we will use to generate the embedding vector for the chunk. The
# content string contains chapter, section, and date headings, tabulated values
# for tables, captions, links, and all other metadata. This is the string we
# will submit as input to the completion endpoint. The extractor looks for
# commands within the page that will modify its behavior. These comands are
# strings embedded in hidden "rag" fields. It also looks for retrieval prompts
# in "prompt" fields. These prompts it leaves in place in the match string, but
# removes from the content string. The single-chunk command tells the extractor
# to combine all chunks into one, producing only one content string and only one
# match string. The match-prompts-only tells the extractor to include only the
# retrieval prompts in the match string, nothing else.
#
proc RAG_Manager_extract_chunks {page catalog} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config

	set single_chunk 0
	set match_prompts_only 0
	set commands [RAG_Manager_list_bodies $page "rag"]
	foreach cmd $commands {
		switch -- $cmd {
			"single-chunk" {
				set single_chunk 1
			}
			"match-prompts-only" {
				set match_prompts_only 1
			}
			default {
				RAG_Manager_print "WARNING: Unrecognised retrieval command \"$cmd\""
			}
		}
	}
	RAG_Manager_print "Generation rules:\
		single_chunk=$single_chunk,\
		match-prompts-only=$match_prompts_only"
	
	set date "NONE"
	set chapter "NONE"
	set section "NONE"
	set prev_name "NONE"
	set empty_match 0
	set empty_content 0
	set contaminated 0
	set chunks [list]
	foreach chunk_id $catalog {
		scan $chunk_id %d%d%s i_start i_end name
		set content [string trim [string range $page $i_start $i_end]]
		
		if {[regexp {<a href=} $content] \
			|| [regexp {<img src=} $content] \
			|| [regexp {<h3>} $content] \
			|| [regexp {</ul>} $content] \
			|| [regexp {</ol>} $content]} {
			incr contaminated
			RAG_Manager_print "[format %7.0f $i_start]\
				[format %7.0f $i_end]\
				[format %8s contam]\
				\"[RAG_Manager_snippet $content 0]\"" blue
			continue
		}
		
		switch $name {
			"p" {set color brown}
			"ul" {set color violet}
			"ol" {set color violet}
			"h2" {set color blue}
			"h3" {set color blue}
			"center" {set color green}
			"equation" {set color green}
			"pre" {set color gray}
			"date" {set color orange}
			default {set color red}
		}
		
		switch -- $name {
			"ol" {
				set content [RAG_Manager_extract_list $content]
				set match $content
			}
			"ul" {
				set content [RAG_Manager_extract_list $content]
				set match $content
			}
			"center" {
				set caption [RAG_Manager_extract_caption $content]
				if {[regexp {^Table} $caption]} {
					set table [RAG_Manager_extract_table $content]
					if {[string length $table] > 0} {
						set content "$caption  \n$table"
						set match "$caption"
					} else {
						set content "$caption"
						set match "$caption"
					}
					set name "table"
				} elseif {[regexp {^Figure} $caption]} {
					set figures [RAG_Manager_extract_figures $content]
					if {[string length $figures] > 0} {
						set content "$caption  \n$figures"
						set match "$caption"
					} else {
						set content "$caption"
						set match "$caption"
					}
					set name "figure"
				} elseif {[regexp {^Video} $caption]} {
					set video [RAG_Manager_extract_video $content]
					set content "$caption  \n$video"
					set match "$caption"
					set name "video"
				} else {
					set content "$caption"
					set match "$caption"
					set name "center"
				}
			}
			"equation" {
				set match $content
			}
			"pre" {
				set match $content
			}
			"h2" {
				set chapter $content
				set section "NONE" 
				set prev_name $name
				continue
			}
			"h3" {
				set section $content
				set prev_name $name
				continue
			}
			"date" {
				set date [RAG_Manager_extract_date $content]
				continue
			}
			default {
				set match $content
			}
		}
		
		regsub -all {</?\s*prompt(>|\s+[^>]*>)[^<]*</prompt>} $content "" content
		set content [RAG_Manager_convert_tags $content]
		set content [RAG_Manager_remove_dates $content]
		set content [string trim $content]
		if {([string length $content] == 0)} {
			incr empty_content
			if {$name != "center"} {
				RAG_Manager_print "WARNING: Empty $name content\
					\"[RAG_Manager_snippet $page $i_start]\""
			}
			continue
		}

		if {$match_prompts_only} {
			set prompts [RAG_Manager_list_bodies $match "prompt"]
			set prompts [join $prompts "\n"]
			set prompts [string trim $prompts]
			set match $prompts
		} else {
			set match [RAG_Manager_convert_tags $match]
			set match [RAG_Manager_remove_dates $match]
			regsub -all {[!]*\[([^\]]+)\]\([^)]+\)} $match {\1} match
			set match [string trim $match]
		}
		if {$match == ""} {
			if {!$single_chunk} {
				incr empty_match
				continue
			}
		}
		
		if {$config(verbose)} {
			RAG_Manager_print "[format %7.0f $i_start]\
				[format %7.0f $i_end]\
				[format %8s $name]\
				\"[RAG_Manager_snippet $content 0]\"" $color	
		}

		set heading ""
		if {$chapter != "NONE"} {
			append heading "%%%%Chapter: $chapter\n"
		}
		if {$section != "NONE"} {
			append heading "%%%%Section: $section\n"
		}
		if {$date != "NONE"} {
			append heading "Date: $date\n"
		}
		set heading [string trim $heading]

		switch -- $name {
			"ol" -
			"ul" -
			"pre" {
				if {$prev_name == "p"} {
					lset chunks end 0 "[lindex $chunks end 0]\n\n$match"
					lset chunks end 1 "[lindex $chunks end 1]\n\n$content"
				} else {
					if {[string length $heading] > 0} {
						set content "$heading\n\n$content"
					}
					lappend chunks [list $match $content]
				}
			}
			"equation" {
				switch -- $prev_name {
					"equation" {
						set match "[lindex $chunks end 0]\n\n$match"
						set content "[lindex $chunks end 1]\n\n$content"
						lset chunks end [list $match $content]
					}
					default {
						lappend chunks [list $match $content]
					}
				} 
			}
			default {
				switch -- $prev_name {
					"equation" {
						set match "[lindex $chunks end 0]\n\n$match"
						set content "[lindex $chunks end 1]\n\n$content"
						set chunks [lreplace $chunks end end]
					}
				}
				if {[string length $heading] > 0} {
					set content "$heading\n\n$content"
				}
				lappend chunks [list $match $content]
				set step "NONE"
			}
		}
		set prev_name $name
	}
	
	RAG_Manager_print "Generated [llength $chunks] chunks,\
		rejected [expr $contaminated+$empty_match+$empty_content],\
		of which $contaminated contaminated,\
		$empty_match empty match,\
		$empty_content empty content."
	
	if {$single_chunk} {
		set single_match ""
		set single_content ""
		foreach chunk $chunks {
			append single_match "[lindex $chunk 0]\n\n"
			append single_content "[lindex $chunk 1]\n\n"
		}
		set chunks [list [list $single_match $single_content]]
		RAG_Manager_print "Consolidated [llength $chunks] chunks into one\
			for single-chunk generation rule."
	}
	
	return $chunks
}

#
# RAG_Manager_relative_url takes a relative url and resolves it into an
# absolute url using a supplied base url. The framework of this code was
# provided by ChatGPT. We enhanced to support internal document links. The base
# url can be a document with extenion php or html and the routine will use the
# document url for internal links.
#
proc RAG_Manager_relative_url {base_url relative_url} {
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
# constructs a new page with the absolute urls. It applies the RAG Manager's
# relative_url to each relative url it finds. The routine looks for urls in
# anchor tags <a> and in image tags <img>. In the final resolved url, we replace
# space characters with the HTML escape sequence "%20".
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
			set url [RAG_Manager_relative_url $base_url $url]
		}
		regsub -all { } $url {%20} url
		append new_page "<a href=\"$url\">"
		set index [expr [lindex $tag 1] + 1]
	}
	append new_page [string range $page $index end]

	set index 0
	set page $new_page
	set new_page ""
	while {[regexp -indices -start $index {<img +src="([^"]+)"[^>]*>} $page tag url]} {
		append new_page [string range $page $index [expr [lindex $tag 0] - 1]]
		set url [string range $page {*}$url]
		set url [string trim $url]
		if {![regexp {https?} $url match]} {
			set url [RAG_Manager_relative_url $base_url $url]
		}
		regsub -all { } $url {%20} url
		append new_page "<img src=\"$url\">"
		set index [expr [lindex $tag 1] + 1]
	}
	append new_page [string range $page $index end]
	
	return $new_page
}

#
# RAG_Manager_chapter_urls converts all lines of the form "%%%%Chapter: Title" or
# form "%%%%Section: Title" into Markdown anchors with absolute links to chapter and
# section. We pass the base url into the routine, and the routine attaches the
# chapter or section name, with spaces replaced with space entities, to form the
# absolute ur. The routine operates only on the content strings, not match
# strings.
#
proc RAG_Manager_chapter_urls {chunks base_url} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
	
	set new_chunks [list]
	foreach chunk $chunks {
		set match [lindex $chunk 0]
		set content [lindex $chunk 1]
		set found 1
		while {$found} {
			set found 0
			if {[regexp {%%%%Chapter: ([^\n]*)} $content -> title]} {
				regsub -all { } $title {%20} link
				regsub {%%%%Chapter: ([^\n]*)} $content \
					"Chapter: \[$title\]\($base_url\#$link\)" content
				set found 1
			} 
			if {[regexp {%%%%Section: ([^\n]*)} $content -> title]} {
				regsub -all { } $title {%20} link
				regsub {%%%%Section: ([^\n]*)} $content \
					"Section: \[$title\]\($base_url\#$link\)" content
				set found 1
			} 
			LWDAQ_support
		}
		lappend new_chunks [list $match $content]
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
    regsub -all {\t} $page {    } page
    return $page
}

#
# RAG_Manager_html_chunks downloads an html page from a url, splits it into
# chunks of text, and returns a list of chunks.
#
proc RAG_Manager_html_chunks {url} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
		
	RAG_Manager_print "Fetch $url..." 
	set page [RAG_Manager_read_url $url]
	RAG_Manager_print "Received [string length $page] bytes." 
	
	RAG_Manager_print "Resolving urls..." 
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
# RAG_Manager_store_chunks stores the match and content strings of a chunk list
# to disk. It stores the content strings in the contents_dir and the match
# strings in the matches_dir. It takes each match string and uses its contents
# to obtain a unique hash name for the chunk. We will use this name to form the
# content, match, and embed names, which will in fact all be the same: hash.txt.
# With this routine, we store the content string with as hash.txt in the
# contents_dir, the match string as hash.txt in the match_dir. The routine takes
# as input a chunk list, in which each chunk consists of a match string and a
# content string.
#
proc RAG_Manager_store_chunks {chunks} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
	
	RAG_Manager_print "Storing [llength $chunks] chunks\
		in content and match directories..." 
	set count 0
	foreach chunk $chunks {
		set match [lindex $chunk 0]
		set content [lindex $chunk 1]

		set cmd [list echo -n $match | openssl dgst -sha1]
		if {[catch {
			set result [eval exec $cmd]
		} error_result]} {
			RAG_Manager_print "ERROR: $error_result"
			RAG_Manager_print $content green
			continue
		}
		if {[regexp {[a-f0-9]{40}} $result hash]} {
			set hash [string range $hash 1 $info(hash_len)]
		} else {
			RAG_Manager_print "ERROR: Cannot find hash string in openssl result."
			RAG_Manager_print "RESULT: $result"
			break
		}
		
		if {[catch {
			set mfn [file join $info(match_dir) $hash\.txt]
			set f [open $mfn w]
			puts -nonewline $f $match
			close $f

			set cfn [file join $info(content_dir) $hash\.txt]
			set f [open $cfn w]
			puts -nonewline $f $content
			close $f
		} error_message]} {
			RAG_Manager_print "ERROR: $error_result"
			RAG_Manager_print "SUGGESTION: Use Set_Root in the Configuration Panel."
			break
		}
		
		incr count
		if {$config(verbose)} {
			if {($count % (round([llength $chunks]*$config(progress_frac))+1) == 1) \
				|| ($count == [llength $chunks])} {
				RAG_Manager_print "[format %5d $count]: [file tail $mfn]\
					\"[RAG_Manager_snippet $match 0]\"" green
			}
		}
		
		LWDAQ_support
	}
	RAG_Manager_print "Stored $count match and content strings." 
	return $count
}

#
# RAG_Manager_embed_string submits a string, which could either be a chunk match
# string or a question string, to the embedding endpoint. We use an access key
# to connect to our endpoint. The endpoint returns an embedding vector in a json
# record.
#
proc RAG_Manager_embed_string {match api_key} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
	
	set tokens [expr [string length $match] / $info(token_size)]
	RAG_Manager_print "Embedding $tokens tokens with model $config(embed_model)." brown
    set match [string map {\\ \\\\} $match]
    set match [string map {\" \\\"} $match]
    set match [string map {\n \\n} $match]
    regsub -all {\s+} $match " " match
	set json_body " \{\n \
		\"model\": \"$config(embed_model)\",\n \
		\"input\": \"$match\"\n \}"
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
# RAG_Manager_vector_from_embed takes an embedding json string and extracts its
# embed vector as a Tcl list.
#
proc RAG_Manager_vector_from_embed {embed} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
		
	if {[regexp {"embedding": \[([^\]]*)} $embed -> vector]} {
		regsub -all {,} $vector " " vector
		regsub -all {[\n\t ]+} $vector " " vector
	} else {
		return "ERROR: Failed to extract vector from embed."
	}

	set new_vector ""
	foreach x $vector {
		lappend new_vector [expr round($info(embed_scale)*$x)]
	}
	set vector $new_vector

	return [string trim $vector]
}

#
# RAG_Manager_fetch_embeds makes a list of all match strings in a match
# directory. It makes a list of all the embeds in the embed directory. For each
# match string, it checks to see if an embed exists for it. If not, it creates a
# new embed. The routine counts the number of embeds that have not corresponding
# match strings, but it does not remove these embeds. Use the purge command to
# remove obsolete embeds. The only parameter we have to pass into this routine
# is the api_key. The routine returns the number of new embeds it fetched.
#
proc RAG_Manager_fetch_embeds {api_key} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
		
	set mfl [glob -nocomplain [file join $info(match_dir) *.txt]]
	RAG_Manager_print "Found [llength $mfl] chunks on disk."
	set efl [glob -nocomplain [file join $info(embed_dir) *.txt]]
	RAG_Manager_print "Found [llength $efl] embeds on disk."
	set new_count 0
	set old_count 0
	set count 0
	RAG_Manager_print "Creating embeds for new match strings..."
	foreach mfn $mfl {
		incr count
		set root [file root [file tail $mfn]]
		if {![regexp $root $efl]} {
			set f [open $mfn r]
			set match [read $f]
			close $f
			RAG_Manager_print "[format %5d $count]:\
				[file tail $mfn] fetching embed..." orange
			set embed [RAG_Manager_embed_string $match $api_key]
			if {[LWDAQ_is_error_result $embed]} {
				RAG_Manager_print "ERROR: $embed"
				break
			}
			set vector [RAG_Manager_vector_from_embed $embed]
			if {[LWDAQ_is_error_result $vector]} {
				RAG_Manager_print "ERROR: $vector"
				break
			}
			set efn [file join $info(embed_dir) $root\.txt]
			set f [open $efn w]
			puts -nonewline $f $vector
			close $f
			incr new_count
		} else {
			incr old_count
			if {$config(verbose)} {
				if {($count % (round([llength $mfl]*$config(progress_frac))+1) == 1) \
					|| ($count == [llength $mfl])} {
					RAG_Manager_print "[format %5d $count]:\
						$root has existing embed." green
				}
			}
		} 
		LWDAQ_update
	}

	set efl [glob -nocomplain [file join $info(embed_dir) *.txt]]
	set obsolete_count 0
	foreach efn $efl {
		set root [file root [file tail $efn]]
		if {![regexp $root $mfl]} {
			incr obsolete_count
		}
	}

	RAG_Manager_print "Checked $count chunks,\
		found $old_count embeds,\
		fetched $new_count embeds,\
		$obsolete_count obsolete embeds."
		
	return $new_count
}

#
# RAG_Manager_purge_embeds makes a list of all content strings in a match
# directory and another list of all the embeds in the embed directory. It
# deletes any embed for which there is not corresponding match string.
#
proc RAG_Manager_purge_embeds {} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
		
	if {$info(control) != "Idle"} {return ""}
	set info(control) "Purge"
	RAG_Manager_print "Purge Obsolete Embed Vectors [RAG_Manager_time]" purple
	
	set cfl [glob -nocomplain [file join $info(content_dir) *.txt]]
	RAG_Manager_print "Found [llength $cfl] content strings on disk."
	set efl [glob -nocomplain [file join $info(embed_dir) *.txt]]
	RAG_Manager_print "Found [llength $efl] embeds on disk."

	set purge_count 0
	foreach efn $efl {
		set root [file root [file tail $efn]]
		if {![regexp $root $cfl]} {
			file delete $efn
			incr purge_count
		}
	}
	RAG_Manager_print "Purged $purge_count embeds with no content string."

	RAG_Manager_print "Purge Complete [RAG_Manager_time]" purple
	set info(control) "Idle"
	return $purge_count
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
# RAG_Manager_delete deletes all chunks from the chunk directory. It does not
# delete embeddings in the embed directory. Unused embedding vectors are culled
# during generation.
#
proc RAG_Manager_delete {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info

	if {$info(control) != "Idle"} {return ""}
	set info(control) "Delete"
	RAG_Manager_print "Delete Content and Match Strings [RAG_Manager_time]" purple

	set cfl [glob -nocomplain [file join $info(content_dir) *.txt]]
	RAG_Manager_print "Found [llength $cfl] content strings."
	set count 0
	foreach cfn $cfl {
		file delete $cfn
		incr count
		LWDAQ_support
	}
	RAG_Manager_print "Deleted $count content strings."

	set mfl [glob -nocomplain [file join $info(match_dir) *.txt]]
	RAG_Manager_print "Found [llength $cfl] match strings."
	set count 0
	foreach mfn $mfl {
		file delete $mfn
		incr count
		LWDAQ_support
	}
	RAG_Manager_print "Deleted $count match strings."

	RAG_Manager_print "Deletion Complete [RAG_Manager_time]" purple
	set info(control) "Idle"
	return ""
}

#
# RAG_Manager_chunk downloads and chunks all URL resources named in the
# sources list. 
#
proc RAG_Manager_chunk {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info

	if {$info(control) != "Idle"} {return ""}
	set info(control) "Chunk"
	RAG_Manager_print "Download Sources and Chunk [RAG_Manager_time]" purple
	
	set chunks [list]
	foreach url [string trim $config(sources)] {
		set chunks [concat $chunks [RAG_Manager_html_chunks $url]]
	}
	RAG_Manager_store_chunks $chunks
	RAG_Manager_print "Chunking complete [RAG_Manager_time]" purple

	set info(control) "Idle"
	return "[llength $chunks]"
}

#
# RAG_Manager_embed identifies match strings for which no embedding vector
# exists and submits them to the embedding endpoing. This routine needs a valid
# API key from disk. It clears the libarary-loaded flag.
#
proc RAG_Manager_embed {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info

	if {$info(control) != "Idle"} {return ""}
	set info(control) "Embed"
	RAG_Manager_print "Embed Match Strings [RAG_Manager_time]" purple	
	set info(library_loaded) 0

	if {![file exists $config(key_file)]} {
		RAG_Manager_print "ERROR: Cannot find key file $config(key_file)."
		set info(control) "Idle"
		return ""
	}
	set f [open $config(key_file) r]
	set api_key [read $f]
	close $f 
	RAG_Manager_print "Read api key from $config(key_file)\." brown

	RAG_Manager_print "Building embedding vector library..."	
	RAG_Manager_fetch_embeds $api_key
	
	RAG_Manager_print "Embed Library Complete [RAG_Manager_time]" purple
	set info(control) "Idle"
	return ""
}

#
# RAG_Manager_load loads all the embedding vectors stored in the embed director
# into memory using the lwdaq_rag utility. It deduces the number of embed vectors
# from the list of files and makes a library that is exactly the correct size, and
# deduces the dimensionality of the vectors from the first vector in the list.
# 
proc RAG_Manager_load {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info
	
	RAG_Manager_print "Loading embed library into memory..."
	set info(library_loaded) "0"

	set efl [glob -nocomplain [file join $info(embed_dir) *.txt]]
	set lib_len [llength $efl]
	if {$lib_len == 0} {
		error "No embed vectors found in $info(embed_dir)."
	}
	
	set efn [lindex $efl 0]
	set f [open $efn r]
	set vector [read $f]
	close $f
	set vec_len [llength $vector]
	if {$vec_len == 0} {
		error "Vector of length zero in [file tail $efn]."
	}
	
	set start_time [clock milliseconds]
	lwdaq_rag create -lib_len $lib_len -vec_len $vec_len
	RAG_Manager_print "Embed library created in\
		[expr [clock milliseconds] - $start_time] ms."
		
	set start_time [clock milliseconds]
	foreach efn $efl {
		incr count
		set f [open $efn r]
		set vector [read $f]
		close $f
		set name [file root [file tail $efn]]
		lwdaq_rag add -name $name -vector $vector
		if {$config(verbose)} {
			if {($count % (round([llength $efl]*$config(progress_frac))+1) == 1) \
				|| ($count == [llength $efl])} {
				RAG_Manager_print "[format %5d $count]: Added $name" orange
			}
		}
	}
	RAG_Manager_print "Embeds added to library in\
		[expr [clock milliseconds] - $start_time] ms."
	
	RAG_Manager_print "Loading complete with a total of $count embeds"
	set info(library_loaded) "1"
	return $count
}

#
# RAG_Manager_engine manages the process that watches the log directory for
# retrieval requests and services those requests by loading a request embed from
# disk, retrieving a list of relevant embeds, and writing this list to disk. The
# engine process posts itself to the event queue. When it starts, it loads the
# embed library regardless of whether one is already loaded into memory. It will
# re-load the embed library every reload_s after that. The engine indicates its
# existence by touching a signal file in the log directory every few seconds.
# The engine watches the log directory. When it finds there a file with
# extension ".txt", first letter Q, and remaining letters all decimal digits, it
# renames the file by replacing the leading Q with a T. We call the first file
# the "question file" and the second file the "temporary file". It reads the
# temporary file. It confirms the contents are a valid vector for matching the
# embed library. It retrieves relevant embeds using our lwdaq_rag utility. It
# re-writes the temporary file with the retrieved embed list. It renames the
# temporary file by replacing thge leading T with an R. This "retrieval file" is
# now ready for consumption by the process that wrote the question file to the
# log directory.
#
proc RAG_Manager_engine {{cmd ""}} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info
	global LWDAQ_Info
	
	if {$LWDAQ_Info(gui_enabled) && ![winfo exists $info(window)]} {
		return ""
	}
	if {($cmd == "Stop") && ($info(engine_ctrl) == "Run")} {
		set info(engine_ctrl) "Stop"
		return ""
	}
	if {($cmd == "") && ($info(engine_ctrl) == "Stop")} {
		RAG_Manager_print "Engine: Stopping." purple
		set info(engine_ctrl) "Idle"
		return ""
	}
	if {$cmd == "Start"} {
		if {$info(engine_ctrl) == "Idle"} {
			set info(engine_ctrl) "Run"
			RAG_Manager_print "Engine: Starting Up [RAG_Manager_time]." purple
			RAG_Manager_print "Engine: Operating in $info(log_dir)."
			set info(reload_time) "0"
		} else {
			return ""
		}
	}
	
	if {[clock seconds] > $info(reload_time)} {
		if {[catch {
			RAG_Manager_print "Engine: Re-loading library\
				[RAG_Manager_time $info(reload_time)]"
			RAG_Manager_load
		} error_message]} {
			RAG_Manager_print "ERROR: $error_message"
			set info(engine_ctrl) "Idle"
			return ""
		}
		set info(reload_time) [expr [clock seconds] + $info(reload_s)]
		RAG_Manager_print "Engine: Next library load\
			[RAG_Manager_time $info(reload_time)]"
	}

	if {[file exists $info(signal_file)]} {
		if {$info(signal_time) <= [clock seconds]} {
			file mtime $info(signal_file) [clock seconds]
			set info(signal_time) [expr [clock seconds] + $info(signal_s)]
			RAG_Manager_print "Engine: Touched signal file $info(signal_file)." salmon
		}
	} else {
		set f [open $info(signal_file) w]
		puts $f "\
			This is the RAG Manager Engine Signal File. The engine touches this\
			file every $info(signal_s) seconds to show that it is running."
		close $f
		RAG_Manager_print "Engine: Created signal file $info(signal_file)."
	}
	
	set lfl [glob -nocomplain [file join $info(log_dir) *.txt]]
	foreach lfn $lfl {
		set name [file root [file tail $lfn]]
		if {[regexp {Q([0-9a-f]+)} $name -> name]} {
			RAG_Manager_print "Engine: Grabbing question embed\
				[file tail $lfn], [RAG_Manager_time]."
			set tfn [file join $info(log_dir) "T$name\.txt"]
			file rename $lfn $tfn
			
			set f [open $tfn r]
			set q_vector [read $f]
			close $f
			
			set good 1
			foreach x $q_vector {
				if {![string is double $x]} {
					RAG_Manager_print "ERROR: Bad component in vector [file tail $lfn],\
						in Retrieval Engine."
					set good 0
					break
				}
			}
			set rc [lwdaq_rag config]
			if {[regexp -- {-vec_len ([0-9]*)} $rc -> n]} {
				if {$n != [llength $q_vector]} {
					RAG_Manager_print "ERROR: Question and library vector\
						length mismatch, $n<>[llength $vector],\
						in Retrieval Engine."
					set good 0
				}
			} else {
				RAG_Manager_print "ERROR: Unexpected lwdaq_rag configuration \"$rc\",\
					in Retrieval Engine."
				set good 0
			}
			if {!$good} {break}
			
			RAG_Manager_print "Engine: Retrieving embeds\
				relevant to question $name..." brown
			set start_time [clock milliseconds]
			if {[catch {
				set retrieval [lwdaq_rag retrieve -retrieve_len \
					$info(retrieve_len) -vector $q_vector]
				RAG_Manager_print "Engine: [lrange $retrieval 0 3]" brown
				set f [open $tfn w]
				puts $f $retrieval
				close $f
				set rfn [file join $info(log_dir) "R$name\.txt"]
				file rename $tfn $rfn
				RAG_Manager_print "Engine:\
					Retrieval file R$name\.txt ready, [RAG_Manager_time]."
			} error_result]} {
				RAG_Manager_print "ERROR: $error_result"
				set info(control) "Idle"
				return "0"
			}		
		}
	}
	
	if {$info(engine_ctrl) == "Run"} {
		LWDAQ_post RAG_Manager_engine
	} else {
		set info(engine_ctrl) "Idle"
	}
	return ""
}

#
# RAG_Manager_retrieve embeds the current question using an embedding endpoint.
# We compare the question vector to the vectors in the embed directory and
# obtain a list of embeds sorted in order of decreasing relevance. There are two
# ways we can perform this retrieval. We can either use the services of a
# Retrieval Engine, or we can retrieve from the RAG Manager's own embed library.
# Our first choice is to retrieve from our own embed library, but if the library
# is not yet loaded, we will see if there is an active signal file in our log
# directory. If so, we will write the question embed to disk in the log
# directory and see if an engine grabs it and returns a matching retrieval list
# file. We will wait a few seconds for that. If we don't see the retrieval list
# appear, we generate an error and abandon the retrieval. Assuming we obtain a
# retrieval list, we operate on the first retrieve_len embeds in this list. We
# remove "obsolete embeds". These are embeds for which no supporting content
# exists. Obsolete embeds arise when we re-generate our chunk library. New match
# strings will need new embeds, but the embeds of non-existent match strings
# will remain in the embed library until we deliberately purge them with the
# Purge Embeds command. Once obsolete embeds have been removed from the list,
# all remaining embeds have existing content chunks. We use the relevance of the
# first chunk in the list as a measure of the relevance of the question, and
# classify the question as high, mid, or low-relevance. We construct the
# retrieved content based upon this classification. We read content strings from
# disk and add them to list. When we exceed the token limit for the question
# relevance, we stop. We return the number of content strings added to our list,
# and we store them in the info(contents) list. In order to embed the question,
# this routine must read a valid API key from disk.
#
proc RAG_Manager_retrieve {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info
	
	if {$info(control) != "Idle"} {return ""}
	set question [string trim $config(question)]
	if {$question == ""} {
		RAG_Manager_print "ERROR: Empty question, abandoning retrieval."
		return "0"
	}
	
	set info(control) "Retrieve"
	RAG_Manager_print "Retrieve Question-Related Content [RAG_Manager_time]" purple
	
	RAG_Manager_print "Question: $config(question)"
	
	if {![file exists $config(key_file)]} {
		RAG_Manager_print "ERROR: Cannot find key file $config(key_file)."
		set info(control) "Idle"
		return "0"
	}
	set f [open $config(key_file) r]
	set api_key [read $f]
	close $f 
	RAG_Manager_print "Read api key from $config(key_file)\." brown

	RAG_Manager_print "Obtaining question embedding vector..."
	set start_time [clock milliseconds]
	set q_embed [RAG_Manager_embed_string $config(question) $api_key]
	set q_vector [RAG_Manager_vector_from_embed $q_embed]

	RAG_Manager_print "Question embed obtained in\
		[expr [clock milliseconds] - $start_time] ms,\
		retrieving relevant embeds..."
	set start_time [clock milliseconds]
	set retrieval ""
	if {$info(library_loaded)} {
		RAG_Manager_print "Using embed library loaded into memory..."
		set retrieval [lwdaq_rag retrieve \
			-retrieve_len $info(retrieve_len) \
			-vector $q_vector]
	} else {
		RAG_Manager_print "No embed library loaded, looking for\
			retrieval engine in $info(log_dir)..."
		if {[catch {
			if {[file exists $info(signal_file)] \
					&& (([clock seconds]-[file mtime $info(signal_file)]) \
					< $info(signal_s))} {
				RAG_Manager_print "Found sign of retrieval engine in $info(log_dir)..."
				set name [expr round(rand()*$info(rand_fn_scale))]
				set pfn [file join $info(log_dir) "P$name\.txt"] 
				set f [open $pfn w]
				puts $f $q_vector
				close $f
				exec chmod 777 [file normalize $pfn]
				set qfn [file join $info(log_dir) "Q$name\.txt"] 
				file rename $pfn $qfn
				RAG_Manager_print "Wrote embedding vector to $qfn\."
				set rfn [file join $info(log_dir) "R$name\.txt"]
				set start [clock milliseconds]
				while {[clock milliseconds] < $start + $info(retrieval_giveup_ms)} {
					LWDAQ_wait_ms $info(retrieval_check_ms)
					if {[file exists $rfn]} {
						set f [open $rfn r]
						set retrieval [read $f]
						close $f
						file delete $rfn
						RAG_Manager_print "Retrieval engine provided $rfn\."
						break
					}
				}
			}
		} error_result]} {
			RAG_Manager_print "ERROR: $error_result"
		}	
		if {($retrieval == "") && !$info(library_loaded)} {
			RAG_Manager_print "No retrieval engine available, loading embed library..."
			RAG_Manager_load
			set retrieval [lwdaq_rag retrieve \
				-retrieve_len $info(retrieve_len) \
				-vector $q_vector]
		}
	}
	RAG_Manager_print "Top chunks: [lrange $retrieval 0 7]"
	
	RAG_Manager_print "Retrieval complete in\
		[expr [clock milliseconds] - $start_time] ms,\
		selecting content strings..."
	set start_time [clock milliseconds]
	set cfl [glob -nocomplain [file join $info(content_dir) *.txt]]
	set new_retrieval [list]
	set obsolete_count 0
	set valid_count 0
	foreach {name rel} $retrieval {
		if {[regexp $name $cfl]} {
			lappend new_retrieval $name $rel
			incr valid_count
		} else {
			incr obsolete_count
		}
	}
	set retrieval $new_retrieval
	if {$valid_count == 0} {
		RAG_Manager_print "ERROR: No content strings exist for retrieved embeds."
		set info(control) "Idle"
		return "0"
	} 
	RAG_Manager_print "Have $valid_count valid embeds,\
		ignoring $obsolete_count obsolete embeds."

	set info(relevance) [lindex $retrieval 1]
	set rel $info(relevance)
	if {$rel >= $config(high_rel_thr)} {
		set num $config(high_rel_tokens)
		RAG_Manager_print "High-relevance question, relevance=$rel, provide $num\+ tokens." 
	} elseif {$rel >= $config(low_rel_thr)} {
		set num $config(mid_rel_tokens)
		RAG_Manager_print "Mid-relevance question, relevance=$rel, provide $num\+ tokens." 
	} else {
		set num $config(low_rel_tokens)
		RAG_Manager_print "Low-relevance question, relevance=$rel, provide $num\+ tokens." 
	}
	
	if {$config(show_match)} {
		RAG_Manager_print "List of match strings, most relevant first." brown
	} else {
		RAG_Manager_print "List of content strings, most relevant first." brown
	
	}
	set index 0
	set count 0
	set tokens 0
	set contents [list]
	foreach {name rel} $retrieval {
		if {$tokens >= $num} {break}
		if {($info(relevance) >= $config(high_rel_thr)) && ($rel <= $config(low_rel_thr))} {
			break
		}
		incr count
		RAG_Manager_print "-----------------------------------------------------" brown
		set embed [lindex $retrieval 0]
		set cfn [file join $info(content_dir) $name\.txt]
		set f [open $cfn r]
		set content [read $f]
		close $f
		lappend contents "$config(chunk_title)$content"
		set tokens [expr $tokens + ([string length $content]/$info(token_size))]

		if {$config(show_match)} {
			set mfn [file join $info(match_dir) $name\.txt]
			set f [open $mfn r]
			set match [read $f]
			close $f
			RAG_Manager_print "$count\: Match String with Relevance $rel:" brown
			RAG_Manager_print $match darkgreen
		} else {
			RAG_Manager_print "$count\: Content String with Relevance $rel:" brown
			RAG_Manager_print $content green
		}
	}
	RAG_Manager_print "-----------------------------------------------------" brown

	if {$config(chat_submit)} {
		set matches [regexp -all -inline -indices \
			{Question:.*?(?=Question:|$)} $info(chat)]
		set chat ""
		set first [expr [llength $matches]-$config(chat_submit)]
		set last [expr [llength $matches]-1]
		foreach match [lrange $matches $first $last] {
			append chat "[string trim [string range $info(chat) {*}$match]]\n"
		}
		set chat [string trim $chat]
		
		if {$chat != ""} {
			RAG_Manager_print \
				"Adding previous $config(chat_submit) exchanges from chat history..."
			RAG_Manager_print \
				"-----------------------------------------------------" brown
			RAG_Manager_print [string trim $chat] green
			RAG_Manager_print \
				"-----------------------------------------------------" brown
			lappend contents "config(chat_title)$info(chat)"
			set tokens [expr $tokens + ([string length $info(chat)]/$info(token_size))]	
		}
	}

	set info(contents) $contents
	RAG_Manager_print "Retrieval complete, $count chunks,\
		total of $tokens content tokens [RAG_Manager_time]" purple
	set info(control) "Idle"
	return [llength $contents]
}

#
# RAG_Manager_get_answer submits a list of chunks and a question to the chat
# completion end point and returns the answer it obtains. It takes as in put
# five parameters: the question, the list of content strings, a description of
# the attitude with which the end point is supposed to answer the question, a
# key that grants access to the generator, and a completion model. It returns
# the entire result from the end point, as a json record, and leaves it to the
# calling procedure to extract the answer.
#
proc RAG_Manager_get_answer {question contents assistant api_key model} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config
	
	set assistant [RAG_Manager_json_format $assistant]
 	set json_body "\{\n \
		\"model\": \"$model\",\n \
		\"messages\": \[\n   \
		\{ \"role\": \"system\", \"content\": \"$assistant\" \},\n"
	foreach content $contents {
		set content [RAG_Manager_json_format $content]
		append json_body "    \{ \"role\": \"user\", \"content\": \"$content\" \},\n"
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
# RAG_Manager_submit combines the question and the assistant prompt with the
# retrieved data, all of which are stored in elements of the info array, and
# passes them to the RAG package for submission to the completion end point. In
# order to submit the question, this routine must read a valid API key from
# disk. Once we receive a response from the completion end point, we try to
# extract an answer from the response json record. If we succeed, we format it
# for plain text display and print it out in the console or tool window. What we
# pass back to the calling routine, however, is the raw answer with no
# formatting. If we can't extract the answer then we try to extract an error
# message and report the error. If we can't extract an error message, we return
# a failure error message of our own. In all cases, what we return is the raw
# json, but what we print to the console or log file is formatted for plain text
# display.
#
proc RAG_Manager_submit {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info
	
	if {$info(control) != "Idle"} {return ""}
	set question [string trim $config(question)]
	if {$question == ""} {
		RAG_Manager_print "ERROR: Empty question, abandoning submission."
		return ""
	}
	if {[string length $question]/$info(token_size) \
			> $config(max_question_tokens)} {
		set answer "ERROR: Question is longer than\
			[expr $config(max_question_tokens)*$info(token_size)] characters."
		return $answer
	}
	
	set info(control) "Submit"
	RAG_Manager_print "Submit Question and Contents to\
		Completion End Point [RAG_Manager_time]" purple
	RAG_Manager_print "Choosing answer model and assistant prompt..."
	set r $info(relevance)
	if {$r >= $config(high_rel_thr)} {
		set model $config(high_rel_model)
		set assistant [string trim $config(high_rel_assistant)]
		RAG_Manager_print "High-relevance question, relevance=$r,\
			use $model and high-relevance prompt." 
	} elseif {$r >= $config(low_rel_thr)} {
		set model $config(mid_rel_model)
		set assistant [string trim $config(mid_rel_assistant)]
		RAG_Manager_print "Mid-relevance question, relevance=$r,\
		 	use $model and mid-relevance prompt." 
	} else {
		set model $config(low_rel_model)
		set assistant [string trim $config(low_rel_assistant)]
		RAG_Manager_print "Low-relevance question, relevance=$r,\
		 	use $model and low-relevance prompt." 
	}
	RAG_Manager_print "Assistant prompt being submitted with this question:" brown
	RAG_Manager_print "$assistant" green

	if {![file exists $config(key_file)]} {
		set answer "ERROR: Cannot find key file $config(key_file)."
		set info(control) "Idle"
		return $answer
	}
	set f [open $config(key_file) r]
	set api_key [read $f]
	close $f 
	RAG_Manager_print "Read api key from $config(key_file)\." brown
	
	set size [string length $assistant]
	foreach content $info(contents) {
		set size [expr $size + [string length $content]]
	}
	set size [expr $size + [string length $question]]
	set tokens [expr $size / $info(token_size)]
	RAG_Manager_print "Submitting total of $tokens tokens to $model for completion..."
	append info(chat) "Question: [string trim $question]\n"
	set start_ms [clock milliseconds]
	set info(result) [RAG_Manager_get_answer $question\
		$info(contents) $assistant $api_key $model]
	set len [expr [string length $info(result)]/$info(token_size)]
	set del [format %.1f [expr 0.001*([clock milliseconds] - $start_ms)]]
	RAG_Manager_print "Received $len tokens after $del s, processing response..."
		
		
	if {[regexp {"content": *"((?:[^"\\]|\\.)*)"} $info(result) -> answer]} {
		RAG_Manager_print "-----------------------------------------------------" brown
		RAG_Manager_print "Raw answer content from completion endpoint:" brown
		RAG_Manager_print $answer green
		RAG_Manager_print "-----------------------------------------------------" brown
	} elseif {[regexp {"message": *"((?:[^"\\]|\\.)*)"} $info(result) -> message]} {
		set answer "ERROR: $message"
	} else {
		set answer "ERROR: Could not find answer or error message in result."
	}

	# Print the answer to the console or log file. We perform minimal formatting
	# on the json answer: we replace escaped newline characters with newlines so
	# that we can see the answer clearly. But we do not replace escaped backslashes
	# nor make any attempt to clean up LaTeX. We want to know what the endpoint
	# returned when we look in our log file. Any newline must have come from an
	# escaped newline because the json string will never contains newlines.
	RAG_Manager_print "Answer to \"$question\":" purple
	regsub -all {\\r\\n|\\r|\\n} $answer "\n" answer_txt
	RAG_Manager_print $answer_txt
	append info(chat) "Answer: $answer_txt\n\n"
	RAG_Manager_print "Submission Complete [RAG_Manager_time]\n" purple
	
	set info(control) "Idle"
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
	
	if {$info(control) != "Idle"} {return ""}
	set info(control) "History"
	RAG_Manager_print "------------- Chat History -------------------------" purple
	RAG_Manager_print [string trim $info(chat)]
	if {$config(verbose)} {
		RAG_Manager_print "------ Full Text of Previous Question Result --------" purple
		RAG_Manager_print $info(result)
	}
	RAG_Manager_print "-----------------------------------------------------" purple
	set info(control) "Idle"
	return [expr [string length $info(chat)] / $info(token_size)]
}

#
# RAG_Manager_clear cleaers the chat history and the text window.
#
proc RAG_Manager_clear {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info

	if {$info(control) != "Idle"} {return ""}
	set info(control) "Clear"
	RAG_Manager_print "Clear Chat History" purple
	set info(chat) ""
	if {[winfo exists $info(text)]} {
		$info(text) delete 1.0 end
	}
	set info(control) "Idle"
	return ""
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

	foreach a {Delete Chunk Embed Retrieve Submit History Clear} {
		set b [string tolower $a]
		button $f.$b -text "$a" -command "LWDAQ_post RAG_Manager_$b"
		pack $f.$b -side left -expand yes
	}

	foreach a {Verbose} {
		set b [string tolower $a]
		checkbutton $f.$b -text "$a" -variable RAG_Manager_config($b)
		pack $f.$b -side left -expand yes
	}

	foreach a {Start Stop} {
		set b [string tolower $a]
		button $f.$b -text "Engine $a" -command \
			[list LWDAQ_post "RAG_Manager_engine $a"]
		pack $f.$b -side left -expand yes
	}

	label $f.ectrl -textvariable RAG_Manager_info(engine_ctrl) -fg green -width 8
	pack $f.ectrl -side left -expand yes
	
	button $f.config -text "Configure" -command "LWDAQ_post RAG_Manager_configure"
	pack $f.config -side left -expand yes
	button $f.help -text "Help" -command {
		LWDAQ_post [list LWDAQ_tool_help RAG_Manager]
	}
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
	LWDAQ_print $info(text) "$info(name) Version $info(version)\n" purple
	
	return $w	
}

RAG_Manager_init
RAG_Manager_open

return ""

----------Begin Help----------


Introduction
------------

The RAG Manager provides the routines we use at to support the OSI Chatbot. The
acronym "RAG" stands for "Retrieval-Assisted Generation", where "generation" is
the composing of an answer to a question by a large language model (LLM), and
"retrieval-assistance" is gathering exerpts relevant to the question from our
documentation. In the jargon of retrieval-assisted generation, these exerpts are
called "chunks". The chat web interface is provided by a PHP process running on
our server and some JavaScript running on the client web browser. When the user
provides a new question, the server calls LWDAQ to collect relevant chunks,
submit them to the LLM, and wait for an answer.


Embedding
---------

The key to retrieval-assisted generation is the ability of the LLM to represent
the content of an chunk with a unit vector in an n-dimensional sphere. In the
jargon of retrieval-assisted generation, the process of representing the
syntactic meaning of a chunk as an n-dimensional vector is called "embedding",
and the resulting vector is the "embedding vector". We use OpenAI's
"text-embedding-3-small" service to embed our chunks. This service produces
vectors in a 1536-dimensional space. We submit an chunk to the OpenAI "embedding
end point" and receive in response 1536 numbers representing the components of
the vector. If we sum the squares of all these numbers, we always obtain a
result close to 1.00000, so we have concluded that the vectors are normalized at
the source. Retrieval-assisted generation operates on the assumptioin that the
angle between two embedding vectors that have similar meaning will be a small
angle. In particular, if the angle between the embedding vector of a question
and the embedding vector of an chunk is small, that chunk is relevant to the
question, and should be used as a basis for answering the question.

We measure the proximity of two embedding vectors by taking their dot product.
Because all embedding vectors are normalized before delivery, their dot product
is equal to the cosine of the angle between them. Our measure of "relevance" for
a chunk is the cosine of the angle between the chunk embedding vector and the
question embedding vector. Two identical chunks have relevance 1.0. In principle
a chunk could have relevance -1. With "text-embedding-3-small", we find that
when the best chunk in our library has relevance 0.5 or greater, it is almost
certainly a question about our products. If the relevance is between 0.3 and 0.5
is may be a question about our products, but if less than 0.3, the question is
almost certainly or general question that cannot be answered by our chatbot
library.


Sources
-------

Before we generate a new chunk libary, we must provide the RAG Manager with a
list of URLs from which it should download the documents out of which it will
create the library. The RAG Manager window, which appears when you open the RAG
manager from a graphical instance of LWDAQ, provides a Source_URLs button in its
Configuration Panel that allows you to define and apply a list of URLs. When the
list is "applied" it is saved in the RAG Manager's internal array, but the URLs
are not yet accessed. The pages we are going to download to make our chunk
library are our "sources".

Once we have our list of URLs, we use the Delete button to delete the old
library. All the chunks will be deleted, but none of the embedding vectors. Each
chunk has two files on disk. One is the "content string", wich resides in the
content directory, and the other is the "match string", which resides in the
match directory. The embedding vectors are stored in the embed directory. The
locations of these directories are set in the RAG Manager's configuration array.
All three files corresponding to a chunk have the same name. All three are text
files. When we delete the chunks, we delete the match and content strings, but
not the embeds.


Chunk
-----

We press Chunk to download our sources and divide them all into a single list of
chunks. The RAG Manager uses "curl" to download the sources. The "curl" utility
supports both https and http. We test the RAG Manager on Linux and MacOS, both
of which are UNIX variants with "curl" installed. We do not test the RAG Manager
on Windows. The RAG Manager proceeds one URL at a time, dividing each page into
an initial sequence of chunks, and then combining some chunks with those before
or after in order to bind things like equations to their explanatory text below,
and lists to their explanatory text above. Check "verbose" to see the
notification and type of every chunk created.

The simplest chunk extraction is to isolate an HTML paragraph using p-tags. Our
HTML documentation is all hand-typed and follows particular, strict patterns
when it comes to tables, lists, figures, and chapter titles. We include dates at
the beginning of chapters in a particular format to indicate when the chapter
was last updated. Thus we are able to extract paragraphs, lists, captions, and
code samples in a uniform and consistent mannger for our chunk library, with
every chunk given a chapter name, a URL pointing to the chapter on-line, and
often a last-modified date as well. We translate the chunks from HTML into
Markdown. This translation includes all URLs. We resolve all relative URLs and
internal document links to absolute URLs. The answer we get back from the
completion endpoint will also be in Markdown. The OpenAI LLM likes Markdown.

As we are generating the chunks, we are generating two strings for each chunk.
One is the "content string", which is the one that includes the chapter title
and link, a date timestamp, URL links, and tables. The tables are written
verbosely in Markdown with every table cell receiving a column title. The other
string is the "match string". The match string is the best representation of the
syntactic meaning of the chunk. If we accompany a table caption with one hundred
numbers from the table itself, the embedding vector generated by the entire
string does not capture the meaning of the caption, but is instead diluted into
ambiguity by the presence of the numbers, which have little or no syntactic
meaning. Chapter titles, date stamps, and URLs also dilute the syntactic
meaning, because they are not prose or equations. Mathematical equations do have
a strong syntactic meaning, so we include those in our match strings, along with
prose, but with all the other metadata text removed. Furthermore, isn our html
document, we can add "prompt" fields like this:

<prompt>Use this table to calculate SCT or HMT operating life.</prompt>

The RAG Manager will include the bodies of these fields in the chunk's match
string, but exclude them from the content strings. These fields are "retrieval
prompts". When we add well-chosen retrieval prompts to the caption of a table or
figure, we can greatly increase the likelyhood that the table will be retrieved
for certain questions that require the numbers in the table. We may want to hide
the prompt strings from the browser view of the html document, in which case we
can do this:

<prompt style="display:none">What is an SCT?</prompt>

Some documents are sparse but dense. Our implantation protocols, for example,
consist of lists of concise instructions interspersed with photographs and
tables. An entire protocol consists of under fifteen hundred tokens. Instead of
dividing the document into separate chunks, we prefer to place the entire
document into a single content string, and compose our own match string with
retrieval prompts. To achive this end, we embed retrieval commands in the
document by means of "rag" fields. These can be placed anywhere in the html
file. Here is an example series of rag instructions with prompt fields that
results in a single chunk for the entire document, with a match string
consisting only of a title and some questions.

<rag style="display:none">single-chunk</rag>
<rag style="display:none">match-prompts-only</rag>
<prompt style="display:none">HMT Implantation Protocol</prompt>
<prompt style="display:none">What is the procedure for implanting an HMT?</prompt>
<prompt style="display:none">How do I attach an EIF to a mouse?</prompt>

Once we have all the match and content strings, the RAG Manager passes the match
string to  "openssl" to obtain a unique twelve-digit name for the chunk, which
we use to form the names of the content and match strings. They will have
names like "6270ebd71f0b.txt". We store the content and match strings to disk.
We use the match string instead of the content string to create the name because
we do not want to change the embedding vector when we change only numbers in a
table or metadata like hyperlinks. In particular, if we are working with a large
html file on a local server, we don't want to have to re-embed the entire
document when we work with the same html file on our remote server, which would
be required if we generated names based on the hyperlink-rich content strings.

With our contents strings and match strings saved to disk in separate
directories, each chunk's match and contents strings saved with a unique, shared
name, our chunking is complete.


Embed
-----

Now that we have the content and match strings, we are ready to embed the match
strings. We press "Embed". The manager goes through all the match strings and
checks to see whether an embedding vector exists for that match string. The
embed vector, if it exist, will reside in the embed directory and share the same
name as the match string. If an embed exists, the chunk is ready to deploy. If
no embedding vector exists, the embedder submits the match string to the OpenAI
embedding endpoint, obtains the match string embedding vector, and writes the
match string embedding vector to disk in the embed directory. To obtain the
vector, we need an API Key, which is the means by which we identify ourselves to
OpenAI and agree to pay for the embedding service. Embedding is inexpensive. At
the time of writing, the "text-embedding-3-small" embedding model costs $0.00002
per one thousand tokens, where a "token" is four characters. So one thousand
chunks, each one thousand tokens long, will cost a total of two cents to embed.

With embedding complete, we have a library of content strings and embedding
vectors ready for retrieval-assisted generation. Note that we have not removed
obsolete embedding vectors from the embed library. By "obsolete" we mean any
vector for which there is no corresponding content string. If we want to purge
obsolete vectors, we use the Purge_Embeds button in the Configuration Panel.
There is no particular rush to purge obsolete vectors. When we retrieve a list
of content strings most relevant to a question, any content string that does not
exist we will skip over. But if obsolete embedding vectors start to outnumber
our active vectors, retrieval will be less efficient.


Retrieval
---------

Now that the library is complete, we are ready to retrieve content strings
relevant to a question. To ask a question, we enter a question in the question
entry box and press Retrieve. The first time we do this after chunking, the
manager will load the library into memory, which will take a few seconds. It
loads all embedding vectors in the embed directory into memory. Each embed takes
up 8 KByte on disk and 12 KByte in memory. On disk, we store the embedding
vector components as integers, having multiplied their original real-valued
components by embed_scale. Saving them as integers makes the disk files more
compact and easier for us to examine. In memory, we convert back to real-valued
components. Each component is an eight-byte real number, which is slightly
larger than the original text-format integer value.

With the embed library loaded into memory, the retrieval will proceed to finding
the most relevant chunks. The RAG Manager fetches the embedding vector of the
question from the embedding end point and compares it to every embedding vector
in its list. It sorts the embedding vectors in order of decreasing relevance. We
use the relevance of the first chunk as our measure of the relevance of a
question to our chunk library. We determine if the question is high, mid, or
low-relevance. We set a limit on the number of content tokens we will submit to
the completion endpoint based upon the relevance of the question. Low-relevance
questions get no documentation at all. The manager reads content strings from
disk, starting with the content string of the most relevant chunk, and proceeds
through its list. When the total number of tokens passes our limit, it stops
adding content. If chat_submit is greater than zero, the manager adds the most
recent chat_submit exchanges from the chat history to the submission data as
well. By default, we add the previous three exchanges to to give continuity to
the chat. 

We select content strings using the embedding vectors of the match strings. When
we select a table of numbers, we select it based upon its match string, not the
numbers themselves. The match string could be the table caption, or it could be
the table caption combined with some retrieval prompts we embedded in the source
html document. With the match-prompts-only command, we will be matching only on
prompts: even the table caption will be removed from the match string. But what
we submit to the completion end point is the entire table with its caption. The
LLM does well understanding and making use of tabulated numbers, especially if
they are supplied with repeating column titles on every line and in Mardown
format. The LLM has no trouble understanding URLs in Markdown format, and it can
understand our chapter, section and date titles as well.

At the end of retrieval, we have all the content strings ready to send to the
completion endpoint. With the verbose flag set, we get to see all the content
strings and the chat history printed in the manager's text window. If we set the
show_matches flag, we will see in place of the content strings the match strings
used to make the embedding vectors.


Submission
----------

Once retrieval is complete, we press Submit and the RAG Manager combines the
assistant prompt, the documentation chunks, and the question in one big json
record. It submits this record to the OpenAI completion endpoint and waits for
an answer. For high-relevance questions, we are currently using the "gpt-4o"
completion model. For mid and low-relevance questions, we use "gpt-3.5-turbo".
The former is more accurate and precise. The latter is faster and cheaper. 

The answer we receive from the completion endpoint will take a form, tone, and
level of detail controlled by our assistant prompt. Our default promp instructs
the endpoint to give us answers in Markdown, with equations in LaTeX. The gpt
LLMs understand Markdown and LaTeX very well, these being the native formats
upon which they were trained. When it comes to producing answers, Markdown and
LaTeX are their preferred output formats, so we instruct the LLM to produce
Markdown and LaTeX. The answer we receive from the LLM is wrapped in a JSON
container, so we have to extract the answer, translate the many characters
escaped for JSON, so as to recover the original Mardown and LaTeX. This we do in
the manager's get-answer routine.

Copyright (C) 2025, Kevan Hashemi, Open Source Instruments Inc.

----------End Help----------

