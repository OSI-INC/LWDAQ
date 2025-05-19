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
	
	LWDAQ_tool_init "RAG_Manager" "1.0"
	if {[winfo exists $info(window)]} {return ""}
	
	package require RAG

	set info(control) "Idle"
	
	set config(verbose) "0"
	set config(key_file) "~/Active/Admin/Keys/OpenAI_API.txt"
	set config(chunk_dir) "~/Active/RAG/Chunks"
	set config(embed_dir) "~/Active/RAG/Embeds"
	set config(question) "What components do I need to set up a telemetry system?"
	set config(assistant) "You are a helpful assistant.\
		Provide links to source material.\
		Prefer newer information over older."

	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 
	
	return ""	
}

proc RAG_print {s {color "black"}} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info

	LWDAQ_print $info(text) $s $color
}


proc RAG_Manger_generate {} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info

	set source_url "http://opensourceinstruments.host/Electronics/A3017/SCT.html"
	set base_url "https://www.opensourceinstruments.com/Electronics/A3017/SCT.html"
	set chunk_dir "~/Active/Scholar/Chunks"
	set embed_dir "~/Active/Scholar/Embeds"
	set RAG_info(t) $t
	set chunks [RAG_html_chunks $source_url $base_url]
	RAG_store_chunks $chunks $chunk_dir
	set key_file "~/Active/Admin/Keys/OpenAI_API.txt"
	LWDAQ_print $t "Reading key file $key_file\."
	set f [open $key_file r]
	set api_key [read $f]
	close $f 
	LWDAQ_print $t "Read API key."
	RAG_store_embeds $chunk_dir $embed_dir $api_key
}


proc RAG_Manager_submit {question} {
	upvar #0 RAG_Manager_config config
	upvar #0 RAG_Manager_info info
	global RAG_info

	RAG_print "Reading api key $config(key_file)\."
	set f [open $config(key_file) r]
	set api_key [read $f]
	close $f 
	RAG_print "Read API key."

	RAG_print "Getting embed file list."
	set efl [glob [file join $config(embed_dir) *.json]]
	RAG_print "Found [llength $efl] embeds on disk."

	set q_embed [RAG_embed_chunk $question $api_key]
	set comparisons [list]
	foreach efn $efl {
		set f [open $efn r]
		set c_embed [read $f]
		close $f
		set comparison [RAG_compare_vectors $q_embed $c_embed]
		lappend comparisons " $comparison [file root [file tail $efn]]"
	}
	set comparisons [lsort -decreasing -real -index 0 $comparisons]
	RAG_print "\nQuestion: $question" purple
	RAG_print "Here are the most similar chunks:" purple
	set index 0
	set data [list]
	set max_index [expr $RAG_info(num_chunks) - 1]
	foreach comparison [lrange $comparisons 0 $max_index] {
		incr index
		RAG_print "------------------------------------" green
		RAG_print "$index\: Similarity [lindex $comparison 0]:" green
		set cfn [file join $config(chunk_dir) [lindex $comparison 1]\.txt]
		set f [open $cfn r]
		set chunk [read $f]
		close $f
		RAG_print $chunk
		lappend data $chunk
		LWDAQ_update
	}
	RAG_print "------------------------------------" green
	RAG_print "\nSubmitting chunks to ChatGPT for an answer, please wait..."
	LWDAQ_update
	set answer [RAG_get_answer $question $data $config(assistant) $api_key]
	RAG_print "Answer:" purple
	RAG_print $answer brown
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

	button $f.submit -text "Submit" -command {
		RAG_Manager_submit $RAG_Manager_config(question)
	}
	pack $f.submit -side left -expand yes
	
	set f [frame $w.q]
	pack $f -side top
	label $f.lq -text "Question:" -fg green
	entry $f.eq -textvariable RAG_Manager_config(question) -width 80
	pack $f.lq $f.eq -side left -expand yes
	
	set f [frame $w.a]
	pack $f -side top
	label $f.la -text "Assistant:" -fg green
	entry $f.ea -textvariable RAG_Manager_config(assistant) -width 80
	pack $f.la $f.ea -side left -expand yes
		
	set info(text) [LWDAQ_text_widget $w 90 20]
	LWDAQ_print $info(text) "$info(name) Version $info(version) \n" purple
	
	return $w	
}

RAG_Manager_init
RAG_Manager_open

return ""

----------Begin Help----------


Copyright (C) 2025, Kevan Hashemi, Open Source Instruments Inc.

----------End Help----------

