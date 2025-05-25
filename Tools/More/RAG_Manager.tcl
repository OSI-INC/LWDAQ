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
	
	LWDAQ_tool_init "RAG_Manager" "1.7"
	if {[winfo exists $info(window)]} {return ""}
	
	package require RAG
	RAG_init
	
	set config(verbose) "0"
	set config(dictionary) "0"
	set config(source_url) "https://www.opensourceinstruments.com/Electronics/A3017/SCT.html"
	set config(key_file) "~/Active/Admin/Keys/OpenAI_API.txt"
	set config(chunk_dir) "~/Active/RAG/Chunks"
	set config(embed_dir) "~/Active/RAG/Embeds"
	set config(dict_dir) "~/Active/RAG/Dictionary"
	set config(question) "Calculate the operating life of an A3048 single-channel\
		transmitter with 160-Hz bandwidth and a CR927 battery."

	set info(control) "Idle"
	set info(chat) [list]
	set info(result) ""
	set info(text) "stdout"
	set info(data) ""
	set info(relevance) "0.0"
	
	set config(high_rel_model) "gpt-4"
	set config(mid_rel_model) "gpt-3.5-turbo"
	set config(low_rel_model) "gpt-3.5-turbo"
	
	set config(high_rel_tokens) "3000"
	set config(mid_rel_tokens) "1000"
	set config(low_rel_tokens) "0"
	set config(high_rel_thr) "0.80"
	set config(low_rel_thr) "0.75"
	
	set config(max_question_tokens) "300"
	
	set info(high_rel_assistant) {
You are a helpful technical assistant.
You can perform mathematical calculations and return
numeric results with appropriate units.
You are also able to summarize, explain, and answer questions
about scientific and engineering documentation.
You are provided with excerpts from documentation that may include
text, figures, and links. When answering the user's question:
  - Use the most relevant and recent information available in the provided content.  
  - If the user's question asks for a figure, graph, or image
    (e.g., "show me a figure of X vs Y"),
    and a matching figure is present in the excerpts,
    include it in your response using Markdown image formatting:  
    `![Figure Caption](image_url)`  
    This ensures the image will be rendered inline in the chat interface.
  - Do not say "you cannot search the web" or "you cannot find images" if a 
    relevant figure is already present in the provided content.
  - Perform mathematical calculations when needed and return numeric
    results with appropriate units.
  - Provide hyperlinks to original documentation sources when available.
  - Prefer newer information over older when content appears to be 
    versioned or time-sensitive.
  - Respond using Markdown formatting. Use headers, bold text, lists, tables, 
    code blocks, and inline image embeds as appropriate.
}

	set info(mid_rel_assistant) {
You are a helpful technical assistant.
If you are not certain of the answer to a question,
say you do not know the answer.
	}
	
	set info(low_rel_assistant) {
You are a helpful technical assistant.
If you are not certain of the answer to a question,
say you do not know the answer.
	}
	
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 
	
	return ""	
}


#
# RAG_Manager_apply reads the contents of a text window and executes them
# as a Tcl script at the global scope. We can use this routine to reconfigure
# long string parameters such as our assistant instructions. Within the 
# scripts we can refer to the RAG Manager configuration and information arrays
# as "config" and "info".
#
proc RAG_Manager_apply {w} {

	set commands {
		upvar #0 RAG_Manager_info info
		upvar #0 RAG_Manager_config config	
		
	}
	append commands [string trim [$w.text get 1.0 end]]
	if {[catch {eval $commands} error_result]} {
		RAG_print "ERROR: $error_result"
	}
	
	return ""
}

#
# RAG_Manager_assistant opens a text window and prints out the declarations
# of the three assistant instructions. We can edit and then apply with an Apply
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
	LWDAQ_text_widget $w 60 20
	LWDAQ_enable_text_undo $w.text
	LWDAQ_bind_command_key $w "a" [list RAG_Manager_apply $w]
	
	# Create the Applpy button.
	frame $w.f
	pack $w.f -side top
	button $w.f.apply -text "Apply" -command [list RAG_Manager_apply $w]
	pack $w.f.apply -side left
	
	# Print the assistant instructions in the window.
	foreach level {high mid low} {
		LWDAQ_print $w.text "	set info($level\_rel_assistant)\
			\{$info($level\_rel_assistant)\}\n"
	}
	
	return ""
}


proc RAG_Manager_configure {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info

	set f [LWDAQ_tool_configure RAG_Manager 3]
	
	button $f.assistant -text "Edit Assistant Instructions" -command {
		RAG_Manager_assistant
	}
	pack $f.assistant -side top -expand 1
	
	return ""
}

proc RAG_Manager_delete {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info

	if {$info(control) != "Idle"} {return ""}
	set info(control) "Delete"
	RAG_print "\nDeleting Chunks [RAG_time]" purple
	set cfl [glob -nocomplain [file join $config(chunk_dir) *.txt]]
	RAG_print "Found [llength $cfl] chunks."
	set count 0
	foreach cfn $cfl {
		file delete $cfn
		incr count
		LWDAQ_support
	}
	RAG_print "Deleted $count chunks."
	RAG_print "Deletion Complete [RAG_time]" purple
	set info(control) "Idle"
	return "$count"
}

proc RAG_Manager_generate {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info

	if {$info(control) != "Idle"} {return ""}
	set info(control) "Generate"
	RAG_print "\nGenerate Chunks and Embed Vectors [RAG_time]" purple
	
	set chunks [RAG_html_chunks $config(source_url)]
	RAG_store_chunks $chunks $config(chunk_dir)

	RAG_print "Reading api key $config(key_file)\." brown
	if {![file exists $config(key_file)]} {
		RAG_print "ERROR: Cannot find key file $config(key_file)."
		set info(control) "Idle"
		return ""
	}
	set f [open $config(key_file) r]
	set api_key [read $f]
	close $f 
	RAG_print "Read API key." brown

	RAG_print "Submitting all chunks for embedding..."	
	RAG_fetch_embeds $config(chunk_dir) $config(embed_dir) $api_key
	if {$config(dictionary)} {
		RAG_print "Generating dictionary of related chunks..."	
		RAG_make_dictionary $config(embed_dir) $config(dict_dir)
	}
	
	RAG_print "Generation Complete [RAG_time]." purple
	set info(control) "Idle"
	return "[llength $chunks]"
}


proc RAG_Manager_retrieve {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info
	global RAG_info

	if {$info(control) != "Idle"} {return ""}
	set question [string trim $config(question)]
	if {$question == ""} {
		RAG_print "ERROR: Empty question, abandoning retrieval."
		return ""
	}
	
	set info(control) "Retrieve"
	RAG_print "\nRetrieve Question-Related Data Chunks [RAG_time]" purple
	
	lappend $info(chat) $question
	RAG_print "Question: $config(question)"
	
	RAG_print "Reading api key $config(key_file)\." brown
	if {![file exists $config(key_file)]} {
		RAG_print "ERROR: Cannot find key file $config(key_file)."
		set info(control) "Idle"
		return ""
	}
	set f [open $config(key_file) r]
	set api_key [read $f]
	close $f 
	RAG_print "Read API key." brown

	RAG_print "Obtaining question embedding vector from embed end point..."
	set q_embed [RAG_embed_chunk $config(question) $api_key]
	
	RAG_print "Getting list of all embed files on disk..."
	set efl [glob -nocomplain [file join $config(embed_dir) *.json]]
	RAG_print "Found [llength $efl] embeds in $config(embed_dir)."

	RAG_print "Comparing question to all chunks using embeds on disk..."
	set comparisons [list]
	foreach efn $efl {
		LWDAQ_support
		set f [open $efn r]
		set c_embed [read $f]
		close $f
		set comparison [RAG_compare_vectors $q_embed $c_embed]
		lappend comparisons "$comparison [file root [file tail $efn]]"
	}
	
	RAG_print "Sorting chunks by decreasing relevance to question..."
	set comparisons [lsort -decreasing -real -index 0 $comparisons]
	
	if {$config(dictionary)} {
		RAG_print "Using dictionary to retrieve related chunks..."
		set new_list [list]
		foreach c [lrange $comparisons 0 20] {
			if {[lsearch -index 1 $new_list [lindex $c 1]] < 0} {
				lappend new_list $c
			}
			set dfn [file join $config(dict_dir) [lindex $c 1]\.txt]
			if {![file exists $dfn]} {
				RAG_print "ERROR: Cannot find dictionary file [file tail $dfn]."
				set info(control) "Idle"
				return ""
			}
			set f [open $dfn r]
			set dict [read $f]
			close $f
			foreach cc [lrange $dict 0 1] {
				set rel [lindex $cc 0]
				set name [lindex $cc 1]
				if {[lsearch -index 1 $new_list $name] < 0} {
					lappend new_list $cc
				}
			}
		}
		set comparisons $new_list
	}
	
	RAG_print "Determining relevance and choosing retrieval size..."
	set info(relevance) [lindex $comparisons 0 0]
	set r $info(relevance)
	if {$r >= $config(high_rel_thr)} {
		set num $config(high_rel_tokens)
		RAG_print "High-relevance question, relevance=$r, retrieve $num\+ tokens." 
	} elseif {$r >= $config(low_rel_thr)} {
		set num $config(mid_rel_tokens)
		RAG_print "Mid-relevance question, relevance=$r, retrieve $num\+ tokens." 
	} else {
		set num $config(low_rel_tokens)
		RAG_print "Low-relevance question, relevance=$r, retrieve $num\+ tokens." 
	}
	
	RAG_print "List of chunks retrieved to support the question." brown
	set index 0
	set data [list]
	set count 0
	set tokens 0
	foreach comparison $comparisons {
		if {$tokens > $num} {break}
		incr count
		RAG_print "-----------------------------------------------------" brown
		RAG_print "$count\: Relevance [lindex $comparison 0]:" brown
		set cfn [file join $config(chunk_dir) [lindex $comparison 1]\.txt]
		set f [open $cfn r]
		set chunk [read $f]
		close $f
		lappend data $chunk
		RAG_print $chunk green
		set tokens [expr $tokens + ([string length $chunk]/$RAG_info(token_size))]
	}
	
	set info(data) $data
	set info(control) "Idle"
	RAG_print "Retrieval complete, $count chunks, $tokens tokens [RAG_time]." purple
	return [llength $data]
}


proc RAG_Manager_submit {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info
	global RAG_info

	if {$info(control) != "Idle"} {return ""}
	set question [string trim $config(question)]
	if {$question == ""} {
		RAG_print "ERROR: Empty question, abandoning submission."
		return ""
	}
	if {[string length $question]/$RAG_info(token_size) > $config(max_question_tokens)} {
		RAG_print "ERROR: Question is larger than $config(max_question_tokens)."
		return ""
	}
	
	set info(control) "Submit"
	RAG_print "\nSubmit Question and Retrieved Data to End Point [RAG_time]" purple
	RAG_print "Choosing answer model and assistant instructions..."
	set r $info(relevance)
	if {$r >= $config(high_rel_thr)} {
		set model $config(high_rel_model)
		set assistant [string trim $info(high_rel_assistant)]
		RAG_print "High-relevance question, relevance=$r,\
			use $model and detailed instruction." 
	} elseif {$r >= $config(low_rel_thr)} {
		set model $config(mid_rel_model)
		set assistant [string trim $info(mid_rel_assistant)]
		RAG_print "Mid-relevance question, relevance=$r,\
		 	use $model and clear instruction." 
	} else {
		set model $config(low_rel_model)
		set assistant [string trim $info(low_rel_assistant)]
		RAG_print "Low-relevance question, relevance=$r,\
		 	use $model and brief instruction." 
	}
	RAG_print "Assistant instructions being submitted with this question:" brown
	RAG_print "$assistant" green

	RAG_print "Reading api key $config(key_file)\." brown
	if {![file exists $config(key_file)]} {
		RAG_print "ERROR: Cannot find key file $config(key_file)."
		set info(control) "Idle"
		return ""
	}
	set f [open $config(key_file) r]
	set api_key [read $f]
	close $f 
	RAG_print "Read API key." brown
	
	RAG_print "Submitting question with [llength $info(data)] chunks..."
	set info(result) [RAG_get_answer $question\
		$info(data) $assistant $api_key $model]
	set len [expr [string length $info(result)]/$RAG_info(token_size)]
	RAG_print "Received response of $len tokens."
		
	# Try to extract the answer from the returned json record. If we succeed,
	# then format the answer for Markdown. We convert backslash-n-backslash-r to
	# newline, backslash-r to newline, backslash-n to newline, backlash-t to
	# tab, backslash-double-quote to double-quote, single newline with no
	# preceding whitespace to double-space-newline. We replace solitary
	# asterisks with multiplication symbols. If we can't extract the answer then
	# report an error.
	if {[regexp {"content": *"((?:[^"\\]|\\.)*)"} $info(result) match answer]} {
		set num [regsub -all {\\r\\n|\\r|\\n} $answer "\n" answer]
		RAG_print "Replaced $num \\r and \\n sequences with newlines." brown
		set num [regsub -all {\\\"} $answer "\"" answer]
		RAG_print "Replaced $num \\\\ with backslash." brown
		set num [regsub -all {\s+\*\s+} $answer { × } answer]
		RAG_print "Replaced $num solitary asterisks with ×." brown
		set num [regsub -all {([^\n]+)\n(?!\n)} $answer "\\1  \n" answer]
		RAG_print "Added spaces to the end of $num lines." brown
	} elseif {[regexp {"message": *"((?:[^"\\]|\\.)*)"} $info(result) match message]} {
		set answer "ERROR: $message"
	} else {
		set answer "ERROR: Could not find answer or error message in result."
	}
 	lappend info(chat) $answer

	RAG_print "Submission Complete [RAG_time]" purple
	set info(control) "Idle"

	RAG_print "\nAnswer to \"$question\":" purple
	RAG_print $answer 
	RAG_print "End of Answer" purple
	
	return $answer
}

proc RAG_Manager_history {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info
	global RAG_info

	if {$info(control) != "Idle"} {return ""}
	set info(control) "History"
	RAG_print "\nPrinting Chat History" purple
	foreach statement $info(chat) {
		RAG_print "-----------------------------------------------------" 
		RAG_print $statement
	}	
	RAG_print "-----------------------------------------------------" 

	if {$config(verbose)} {
		RAG_print "------ Full Text of Previous Question Result --------" 
		RAG_print $info(result)
		RAG_print "-----------------------------------------------------" 
	}

	RAG_print "Done" purple
	
	set info(control) "Idle"
	return [expr [string length $info(chat)] / $RAG_info(token_size)]
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

	foreach a {Delete Generate Retrieve Submit History} {
		set b [string tolower $a]
		button $f.$b -text "$a" -command "RAG_Manager_$b"
		pack $f.$b -side left -expand yes
	}
	
	foreach a {Verbose Dictionary} {
		set b [string tolower $a]
		checkbutton $f.$b -text "$a" -variable RAG_Manager_config($b)
		pack $f.$b -side left -expand yes
	}

	foreach a {high_rel_tokens high_rel_thr} {
		label $f.l$a -text "$a\:" -fg green
		entry $f.e$a -textvariable RAG_Manager_config($a) -width 6
		pack $f.l$a $f.e$a -side left -expand yes
	}

	button $f.config -text "Configure" -command "RAG_Manager_configure"
	pack $f.config -side left -expand yes
	
	foreach a {Question Source_URL} {
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

proc RAG_print {s {color "black"}} {
	upvar #0 RAG_Manager_info info
	upvar #0 RAG_Manager_config config

	if {$config(verbose) || ($color == "black") || ($color == "purple") \
		|| [regexp {^ERROR: } $s] || [regexp {^WARNING: } $s]} {
		LWDAQ_print $info(text) $s $color
		LWDAQ_update
	}
}

RAG_Manager_open

return ""

----------Begin Help----------


Copyright (C) 2025, Kevan Hashemi, Open Source Instruments Inc.

----------End Help----------

