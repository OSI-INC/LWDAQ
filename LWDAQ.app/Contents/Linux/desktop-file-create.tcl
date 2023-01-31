# Run this script with "./lwdaq LWDAQ.app/Contents/Linux/desktop-file-create.tcl"
puts ""
puts "Desktop File Generator"
puts "----------------------"
set dfn [file join $LWDAQ_Info(program_dir) LWDAQ.app Contents Linux lwdaq.desktop]
set f [open $dfn r]
set contents [read $f]
close $f
puts "Read contents of the LWDAQ desktop file template." 
puts "Writing the following lines to desktop file:\n"
set contents [regsub -all "%P" $contents $LWDAQ_Info(program_dir)]
set contents [string trim $contents]
puts $contents
puts ""
set dfn [file normalize [file join ~ Desktop lwdaq.desktop]]
set f [open $dfn w]
puts $f $contents
close $f
if {[file exists $dfn]} {
	puts "Created $dfn\."
} else {
	puts "Failed to create $dfn\."
	exit
}
puts "In your terminal, execute the following command:"
puts "sudo desktop-file-install $dfn"
puts "Right-click on desktop file and select \"Allow Launching\"."
puts "The desktop file should show the LWDAQ icon."
puts "Double-click on the desktop file to launch LWDAQ."
exit