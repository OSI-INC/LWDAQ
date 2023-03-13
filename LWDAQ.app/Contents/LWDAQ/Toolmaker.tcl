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

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

if {$info(os) == "Windows"} {
	set ch [open "| ./LWDAQ.bat --gui" w+]
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

set ch [open "| ./LWDAQ.bat --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
puts "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
puts "Opened the standalone tool."
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./lwdaq --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
puts "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
puts "Opened the standalone tool."
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./lwdaq --quiet --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
puts "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
puts "Opened the standalone tool."
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./lwdaq --quiet --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
puts "Opened new LWDAQ with channel $ch."
puts $ch {set LWDAQ_Info(console_prompt) ""}
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
puts "Opened the standalone tool."
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./lwdaq --quiet --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
puts "Opened new LWDAQ with channel $ch."
puts $ch {set LWDAQ_Info(console_prompt) ""}
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
gets $ch line
if {![regexp {SUCCESS} $line]} {
	puts "ERROR: $line"
}
puts "Opened the standalone tool."
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./lwdaq --quiet --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 1
puts "Opened new LWDAQ with channel $ch."
puts $ch {set LWDAQ_Info(console_prompt) ""}
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
gets $ch line
if {![regexp {SUCCESS} $line]} {
	puts "ERROR: $line"
}
puts "Opened the standalone tool."
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./lwdaq --quiet --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 1
puts "Opened new LWDAQ with channel $ch."
puts $ch {set LWDAQ_Info(console_prompt) ""}
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
gets $ch line
if {![regexp {SUCCESS} $line]} {
	puts "Failed to open standalone tool."
} else {
	puts "Opened the standalone tool."
}
fconfigure $ch -blocking 0
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./lwdaq --quiet --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 1
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {set LWDAQ_Info(console_prompt) ""}
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
gets $ch line
if {![regexp {SUCCESS} $line]} {
	LWDAQ_print $t "ERROR: Failed to open standalone tool."
} else {
	LWDAQ_print $t "Opened the standalone tool."
}
fconfigure $ch -blocking 0
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./lwdaq --quiet --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 1
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {set LWDAQ_Info(console_prompt) ""}
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
gets $ch line
if {![regexp {SUCCESS} $line]} {
	LWDAQ_print $t "ERROR: Failed to open standalone tool."
} else {
	LWDAQ_print $t "Opened the standalone tool."
}
puts $ch {Videoarchiver_read}
gets $ch line
LWDAQ_print $t $line
fconfigure $ch -blocking 0
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./lwdaq --quiet --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 1
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {set LWDAQ_Info(console_prompt) ""}
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
gets $ch line
if {![regexp {SUCCESS} $line]} {
	LWDAQ_print $t "ERROR: Failed to open standalone tool."
} else {
	LWDAQ_print $t "Opened the standalone tool."
}
puts $ch {Videoplayer_read}
gets $ch line
LWDAQ_print $t $line
fconfigure $ch -blocking 0
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./lwdaq --quiet --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 1
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {set LWDAQ_Info(console_prompt) ""}
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
gets $ch line
if {![regexp {SUCCESS} $line]} {
	LWDAQ_print $t "ERROR: Failed to open standalone tool."
} else {
	LWDAQ_print $t "Opened the standalone tool."
}
puts $ch {Videoplayer_read /Users/kevan/Desktop/Scratch/VideoPlayer/V1234567890.mp4}
gets $ch line
LWDAQ_print $t "Opened $line"
puts $ch {Videoplayer_play}
puts $ch {set Videoplayer_info(frame_count)}
gets $ch line
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./lwdaq --quiet --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 1
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {set LWDAQ_Info(console_prompt) ""}
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
gets $ch line
if {![regexp {SUCCESS} $line]} {
	LWDAQ_print $t "ERROR: Failed to open standalone tool."
} else {
	LWDAQ_print $t "Opened the standalone tool."
}
puts $ch {Videoplayer_read /Users/kevan/Desktop/Scratch/VideoPlayer/V1234567890.mp4}
gets $ch line
LWDAQ_print $t "Opened $line"
fconfigure $ch -translation auto -buffering line -blocking 0
puts $ch {Videoplayer_play}
puts $ch {set Videoplayer_info(frame_count)}
</script>

<script>
upvar #0 LWDAQ_Info info

cd $info(program_dir)

set ch [open "| ./lwdaq --quiet --gui" w+]
fconfigure $ch -translation auto -buffering line -blocking 1
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {set LWDAQ_Info(console_prompt) ""}
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
gets $ch line
if {![regexp {SUCCESS} $line]} {
	LWDAQ_print $t "ERROR: Failed to open standalone tool."
} else {
	LWDAQ_print $t "Opened the standalone tool."
}
puts $ch {Videoplayer_read /Users/kevan/Desktop/Scratch/VideoPlayer/V1234567890.mp4}
gets $ch line
LWDAQ_print $t "Opened $line"
fconfigure $ch -translation auto -buffering line -blocking 0
puts $ch {Videoplayer_play}
puts $ch {set Videoplayer_info(frame_count)}
</script>

<script>
upvar #0 LWDAQ_Info info
cd $info(program_dir)
set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
fconfigure $ch -translation auto -buffering line -blocking 1
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
puts $ch {Videoplayer_read /Users/kevan/Desktop/Scratch/VideoPlayer/V1234567890.mp4}
</script>

<script>
upvar #0 LWDAQ_Info info
cd $info(program_dir)
set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
puts $ch {Videoplayer_read /Users/kevan/Desktop/Scratch/VideoPlayer/V1234567890.mp4}
</script>

<script>
upvar #0 LWDAQ_Info info
cd $info(program_dir)
set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Standalone}
puts $ch {Videoplayer_read /Users/kevan/Desktop/Scratch/VideoPlayer/V1234567890.mp4}
</script>

<script>
upvar #0 LWDAQ_Info info
cd $info(program_dir)
set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Slave}
puts $ch {Videoplayer_read /Users/kevan/Desktop/Scratch/VideoPlayer/V1234567890.mp4}
</script>

<script>
upvar #0 LWDAQ_Info info
cd $info(program_dir)
set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Slave}
puts $ch {Videoplayer_read /Users/kevan/Desktop/Scratch/VideoPlayer/V1234567890.mp4}
</script>

<script>
upvar #0 LWDAQ_Info info
cd $info(program_dir)
set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Slave}
puts $ch {Videoplayer_play /Users/kevan/Desktop/Scratch/VideoPlayer/V1234567890.mp4}
</script>

<script>
upvar #0 LWDAQ_Info info
cd $info(program_dir)
set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Slave}
puts $ch {Videoplayer_play}
</script>

<script>
upvar #0 LWDAQ_Info info
cd $info(program_dir)
set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Slave}
puts $ch {Videoplayer_play}
</script>

<script>
upvar #0 LWDAQ_Info info
cd $info(program_dir)
set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Slave}
puts $ch {Videoplayer_play}
</script>

<script>
upvar #0 LWDAQ_Info info
cd $info(program_dir)
set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Slave}
puts $ch {videoplayer play}
</script>

<script>
upvar #0 LWDAQ_Info info
cd $info(program_dir)
set ch [open "| ./lwdaq --quiet --gui --no-prompt" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
LWDAQ_print $t "Opened new LWDAQ with channel $ch."
puts $ch {LWDAQ_run_tool Videoplayer.tcl Slave}
puts $ch {videoplayer play}
</script>

