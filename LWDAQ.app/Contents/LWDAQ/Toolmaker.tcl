<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

if {$info(os) == "Windows"} {
	set ch [open "| [info nameofexecutable]" w+]
} else {
	set ch [open "| ./lwdaq" w+]
}
fconfigure $ch -translation auto -buffering line -blocking 0
puts "Opened new LWDAQ with channel $ch."

if {$info(os) == "Windows"} {
	puts $ch {source LWDAQ.app/Contents/LWDAQ/Init.tcl}
} 
puts "Initialized the new LWDAQ."

puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
puts "Opened the standalone tool."
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

if {$info(os) == "Windows"} {
	set ch [open "| [info nameofexecutable]" w+]
} else {
	set ch [open "| ./lwdaq" w+]
}
fconfigure $ch -translation auto -buffering line -blocking 0
puts "Opened new LWDAQ with channel $ch."

if {$info(os) == "Windows"} {
	puts $ch {source LWDAQ.app/Contents/LWDAQ/Init.tcl}
} 
puts "Initialized the new LWDAQ."

puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
puts "Opened the standalone tool."
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

if {$info(os) == "Windows"} {
	set ch [open "| [info nameofexecutable]" w+]
} else {
	set ch [open "| ./lwdaq" w+]
}
fconfigure $ch -translation auto -buffering line -blocking 0
puts "Opened new LWDAQ with channel $ch."

if {$info(os) == "Windows"} {
	puts $ch {source LWDAQ.app/Contents/LWDAQ/Init.tcl}
} 
puts "Initialized the new LWDAQ."

puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
puts "Opened the standalone tool."
</script>

