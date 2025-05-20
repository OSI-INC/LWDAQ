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
	
	LWDAQ_tool_init "RAG_Manager" "1.1"
	if {[winfo exists $info(window)]} {return ""}
	
	package require RAG

	set info(control) "Idle"
	
	set config(verbose) "0"
	set config(source_url) "https://www.opensourceinstruments.com/Electronics/A3017/SCT.html"
	set config(key_file) "~/Active/Admin/Keys/OpenAI_API.txt"
	set config(chunk_dir) "~/Active/RAG/Chunks"
	set config(embed_dir) "~/Active/RAG/Embeds"
	set config(question) "What is the smallest telemetry sensor OSI makes?"
	set config(assistant) "You are a technical assistant.\
		You can and should retrieve information from provided documentation\
		and perform mathematical calculations when variables are given.\
		If the user supplies a value for a variable in a retrieved equation,\
		perform the calculation and return the numeric result with units.\
		When possible, provide links to source material.\
		When documents conflict, prefer newer information over older."
	set config(num_chunks) "6"

	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 
	
	return ""	
}


proc RAG_Manager_generate {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info

	if {$info(control) != "Idle"} {return ""}
	set info(control) "Generate"
	RAG_print "\nGenerate Chunks and Embed Vectors" purple
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


proc RAG_Manager_submit {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info
	global RAG_info

	if {$info(control) != "Idle"} {return ""}
	set info(control) "Submit"
	RAG_print "\nSubmitting Question to Completion End Point" purple
	
	RAG_print "Reading api key $config(key_file)\."
	set f [open $config(key_file) r]
	set api_key [read $f]
	close $f 
	RAG_print "Read API key."

	RAG_print "Getting embed file list..."
	set efl [glob [file join $config(embed_dir) *.json]]
	RAG_print "Found [llength $efl] embeds on disk."

	RAG_print "Embedding the question..."
	set q_embed [RAG_embed_chunk $config(question) $api_key]
	
	RAG_print "Comparing question to all chunks..."
	set comparisons [list]
	foreach efn $efl {
		set f [open $efn r]
		set c_embed [read $f]
		close $f
		set comparison [RAG_compare_vectors $q_embed $c_embed]
		lappend comparisons " $comparison [file root [file tail $efn]]"
	}
	
	RAG_print "Sorting chunks by decreasing relevance..."
	set comparisons [lsort -decreasing -real -index 0 $comparisons]
	
	RAG_print "Chunks relevant to \"$config(question)\"" brown
	set index 0
	set data [list]
	set index 0
	foreach comparison [lrange $comparisons 0 [expr $config(num_chunks) - 1]] {
		incr index
		RAG_print "-----------------------------------------------------" brown
		RAG_print "$index\: Similarity [lindex $comparison 0]:" brown
		set cfn [file join $config(chunk_dir) [lindex $comparison 1]\.txt]
		set f [open $cfn r]
		set chunk [read $f]
		close $f
		lappend data $chunk
		RAG_print $chunk green
	}
	RAG_print "Submitting best chunks $config(num_chunks) to OpenAI..."
	set answer [RAG_get_answer $config(question) $data $config(assistant) $api_key]
	
	RAG_print "Done" purple
	set info(control) "Idle"

	RAG_print "\nAnswer to \"$config(question)\":" purple
	RAG_print $answer 
	RAG_print "End of Answer" purple
	
	return $answer
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

	foreach a {Generate Submit} {
		set b [string tolower $a]
		button $f.$b -text "$a" -command "RAG_Manager_$b"
		pack $f.$b -side left -expand yes
	}
	
	checkbutton $f.verbose -text "Verbose" -variable RAG_Manager_config(verbose)
	pack $f.verbose -side left -expand yes

	foreach a {Question Assistant Source_URL} {
		set b [string tolower $a]
		set f [frame $w.$b]
		pack $f -side top
		label $f.l$b -text "$a\:" -fg green
		entry $f.e$b -textvariable RAG_Manager_config($b) -width 80
		pack $f.l$b $f.e$b -side left -expand yes
	}
			
	set info(text) [LWDAQ_text_widget $w 90 20]
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

