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
	
	LWDAQ_tool_init "RAG_Manager" "1.4"
	if {[winfo exists $info(window)]} {return ""}
	
	package require RAG
	RAG_init
	
	set info(control) "Idle"
	set info(chat) [list]
	set info(result) ""
	set info(text) "stdout"
	
	
	set config(high_rel_model) "gpt-4"
	set config(mid_rel_modelk) "gpt-3.5-turbo"
	set config(low_rel_model) "gpt-3.5-turbo"
	
	set config(high_rel_tokens) "3000"
	set config(mid_rel_tokens) "1000"
	set config(low_rel_tokens) "500"
	set config(high_rel_thr) "0.80"
	set config(low_rel_thr) "0.75"
	
	set info(high_rel_message) ""
	set info(mid_rel_message) "Our documentation does not appear to provide\
		a clear answer to this question. Here's the best we can do:\n\n"
	set info(low_rel_message) "This question does not appear to be related\
		to our products. Here's what we found anyway:\n\n"

	set config(verbose) "0"
	set config(source_url) "https://www.opensourceinstruments.com/Electronics/A3017/SCT.html"
	set config(key_file) "~/Active/Admin/Keys/OpenAI_API.txt"
	set config(chunk_dir) "~/Active/RAG/Chunks"
	set config(embed_dir) "~/Active/RAG/Embeds"
	set config(question) "What is the smallest telemetry sensor OSI makes?"
	set config(assistant) "You are a helpful assistant.\
		You can perform mathematical calculations.\
		Return numeric result with units.\
		Provide links to source material.\
		Prefer newer information over older."

	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 
	
	return ""	
}

proc RAG_Manager_configure {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info

	LWDAQ_tool_configure RAG_Manager 2
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
	RAG_print "Done" purple
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
	RAG_print "Reading key file $config(key_file)..."
	set f [open $config(key_file) r]
	set api_key [read $f]
	close $f 
	RAG_fetch_embeds $config(chunk_dir) $config(embed_dir) $api_key
	RAG_print "Done" purple
	set info(control) "Idle"
	return "[string length $chunks]"
}


proc RAG_Manager_submit {{question ""}} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info
	global RAG_info

	if {$info(control) != "Idle"} {return ""}
	set info(control) "Submit"
	RAG_print "\nSubmitting Question to Completion End Point [RAG_time]" purple
	
	if {$question != ""} {set config(question) $question}
	RAG_print "Question: $config(question)"
	
	RAG_print "Reading api key $config(key_file)\."
	set f [open $config(key_file) r]
	set api_key [read $f]
	close $f 
	RAG_print "Read API key."

	RAG_print "Getting embed file list..."
	set efl [glob -nocomplain [file join $config(embed_dir) *.json]]
	RAG_print "Found [llength $efl] embeds on disk."

	RAG_print "Embedding the question..."
	set config(question) [string trim $config(question)]
	lappend info(chat) $config(question)
	set q_embed [RAG_embed_chunk $config(question) $api_key]
	
	RAG_print "Comparing question to all chunks..."
	set comparisons [list]
	foreach efn $efl {
		LWDAQ_support
		set f [open $efn r]
		set c_embed [read $f]
		close $f
		set comparison [RAG_compare_vectors $q_embed $c_embed]
		lappend comparisons " $comparison [file root [file tail $efn]]"
	}
	
	RAG_print "Sorting chunks by decreasing relevance..."
	set comparisons [lsort -decreasing -real -index 0 $comparisons]
	
	set relevance [lindex $comparisons 0 0]
	if {$relevance >= $config(high_rel_thr)} {
		set model $config(high_rel_model)
		set num $config(high_rel_tokens)
		set msg $info(high_rel_message)
		RAG_print "High-relevance question, relevance=$relevance,\
			use $model, submit $num\+ tokens." 
	} elseif {$relevance >= $config(low_rel_thr)} {
		set model $config(mid_rel_model)
		set num $config(mid_rel_tokens)
		set msg $info(mid_rel_message)
		RAG_print "Mid-relevance question, relevance=$relevance,\
		 	use $model, submit $num tokens." 
	} else {
		set model $config(low_rel_model)
		set num $config(low_rel_tokens)
		set msg $info(low_rel_message)
		RAG_print "Low-relevance question, relevance=$relevance,\
		 	use $model, submit $num tokens." 
	}
	
	RAG_print "Chunks selected to support \"$config(question)\"" brown
	set index 0
	set data [list]
	set count 0
	set tokens [expr [string length $question] / 4]
	foreach comparison $comparisons {
		incr count
		RAG_print "-----------------------------------------------------" brown
		RAG_print "$count\: Similarity [lindex $comparison 0]:" brown
		set cfn [file join $config(chunk_dir) [lindex $comparison 1]\.txt]
		set f [open $cfn r]
		set chunk [read $f]
		close $f
		lappend data $chunk
		RAG_print $chunk green
		set tokens [expr $tokens + ([string length $chunk]/4)]
		if {$tokens > $num} {break}
	}
	
	RAG_print "Submitting question and $count chunks to OpenAI,\
		$tokens tokens, at [RAG_time]."
	set info(result) [RAG_get_answer $config(question)\
		$data $config(assistant) $api_key $model]
	
	if {[regexp {"content": *"((?:[^"\\]|\\.)*)"} $info(result) match answer]} {
		# Convert backslash-n-backslash-r to newline, backslash-r to newline,
		# backslash-n to newline, backlash-t to tab, backslash-double-quote to
		# double-quote, single newline with no preceding whitespace to
		# double-space-newline. 
		regsub -all {\\r\\n} $answer "\n" answer
		regsub -all {\\r} $answer "\n" answer
		regsub -all {\\n} $answer "\n" answer
		regsub -all {\\t} $answer "\t" answer   
		regsub -all {\\\"} $answer "\"" answer
		regsub -all {^([^\n]+)\n(?!\s)} $answer "\1  \n" answer 

		# Convert solitary asterisk to backslash-asterisk.
		regsub -all {(\d) \* (\d)} $answer {\1 \\* \2} answer
		
	   	append msg $answer
    	set answer $msg
	} else {
		set answer "Failed to extract answer from result."
		RAG_print "ERROR: Cannot find answer content in result string."
	}
 	lappend info(chat) $answer

	RAG_print "Done" purple
	set info(control) "Idle"

	RAG_print "\nAnswer to \"$config(question)\":" purple
	RAG_print $answer 
	RAG_print "End of Answer" purple
	
	return $answer
}

proc RAG_Manager_history {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info

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
	return [string length $info(chat)]
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

	foreach a {Delete Generate Submit History} {
		set b [string tolower $a]
		button $f.$b -text "$a" -command "RAG_Manager_$b"
		pack $f.$b -side left -expand yes
	}
	
	checkbutton $f.verbose -text "Verbose" -variable RAG_Manager_config(verbose)
	pack $f.verbose -side left -expand yes
	
	foreach a {high_rel_tokens high_rel_thr} {
		label $f.l$a -text "$a\:" -fg green
		entry $f.e$a -textvariable RAG_Manager_config($a) -width 6
		pack $f.l$a $f.e$a -side left -expand yes
	}

	button $f.config -text "Configure" -command "RAG_Manager_configure"
	pack $f.config -side left -expand yes
	
	foreach a {Question Assistant Source_URL} {
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

