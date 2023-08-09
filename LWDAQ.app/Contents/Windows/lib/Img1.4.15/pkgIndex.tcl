if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded zlibtcl 1.2.13 [list load [file join $dir tcl9zlibtcl1213.dll]]
} else {
    package ifneeded zlibtcl 1.2.13 [list load [file join $dir zlibtcl1213.dll]]
}
if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded pngtcl 1.6.39 [list load [file join $dir tcl9pngtcl1639.dll]]
} else {
    package ifneeded pngtcl 1.6.39 [list load [file join $dir pngtcl1639.dll]]
}
if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded tifftcl 4.5.0 [list load [file join $dir tcl9tifftcl450.dll]]
} else {
    package ifneeded tifftcl 4.5.0 [list load [file join $dir tifftcl450.dll]]
}
if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded jpegtcl 9.5.0 [list load [file join $dir tcl9jpegtcl950.dll]]
} else {
    package ifneeded jpegtcl 9.5.0 [list load [file join $dir jpegtcl950.dll]]
}
# -*- tcl -*- Tcl package index file
# --- --- --- Handcrafted, final generation by configure.

if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded img::base 1.4.15 [list load [file join $dir tcl9tkimg1415.dll]]
} else {
    package ifneeded img::base 1.4.15 [list load [file join $dir tkimg1415.dll]]
}
# Compatibility hack. When asking for the old name of the package
# then load all format handlers and base libraries provided by tkImg.
# Actually we ask only for the format handlers, the required base
# packages will be loaded automatically through the usual package
# mechanism.

# When reading images without specifying it's format (option -format),
# the available formats are tried in reversed order as listed here.
# Therefore file formats with some "magic" identifier, which can be
# recognized safely, should be added at the end of this list.

package ifneeded Img 1.4.15 {
    package require img::window
    package require img::tga
    package require img::ico
    package require img::pcx
    package require img::sgi
    package require img::sun
    package require img::xbm
    package require img::xpm
    package require img::jpeg
    package require img::png
    package require img::tiff
    package require img::bmp
    package require img::ppm
    package require img::gif
    package require img::pixmap
    package provide Img 1.4.15
}

if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded img::bmp 1.4.15 [list load [file join $dir tcl9tkimgbmp1415.dll]]
} else {
    package ifneeded img::bmp 1.4.15 [list load [file join $dir tkimgbmp1415.dll]]
}
if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded img::gif 1.4.15 [list load [file join $dir tcl9tkimggif1415.dll]]
} else {
    package ifneeded img::gif 1.4.15 [list load [file join $dir tkimggif1415.dll]]
}
if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded img::ico 1.4.15 [list load [file join $dir tcl9tkimgico1415.dll]]
} else {
    package ifneeded img::ico 1.4.15 [list load [file join $dir tkimgico1415.dll]]
}
if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded img::jpeg 1.4.15 [list load [file join $dir tcl9tkimgjpeg1415.dll]]
} else {
    package ifneeded img::jpeg 1.4.15 [list load [file join $dir tkimgjpeg1415.dll]]
}
if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded img::pcx 1.4.15 [list load [file join $dir tcl9tkimgpcx1415.dll]]
} else {
    package ifneeded img::pcx 1.4.15 [list load [file join $dir tkimgpcx1415.dll]]
}
if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded img::pixmap 1.4.15 [list load [file join $dir tcl9tkimgpixmap1415.dll]]
} else {
    package ifneeded img::pixmap 1.4.15 [list load [file join $dir tkimgpixmap1415.dll]]
}
if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded img::png 1.4.15 [list load [file join $dir tcl9tkimgpng1415.dll]]
} else {
    package ifneeded img::png 1.4.15 [list load [file join $dir tkimgpng1415.dll]]
}
if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded img::ppm 1.4.15 [list load [file join $dir tcl9tkimgppm1415.dll]]
} else {
    package ifneeded img::ppm 1.4.15 [list load [file join $dir tkimgppm1415.dll]]
}
if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded img::ps 1.4.15 [list load [file join $dir tcl9tkimgps1415.dll]]
} else {
    package ifneeded img::ps 1.4.15 [list load [file join $dir tkimgps1415.dll]]
}
if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded img::sgi 1.4.15 [list load [file join $dir tcl9tkimgsgi1415.dll]]
} else {
    package ifneeded img::sgi 1.4.15 [list load [file join $dir tkimgsgi1415.dll]]
}
if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded img::sun 1.4.15 [list load [file join $dir tcl9tkimgsun1415.dll]]
} else {
    package ifneeded img::sun 1.4.15 [list load [file join $dir tkimgsun1415.dll]]
}
if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded img::tga 1.4.15 [list load [file join $dir tcl9tkimgtga1415.dll]]
} else {
    package ifneeded img::tga 1.4.15 [list load [file join $dir tkimgtga1415.dll]]
}
if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded img::tiff 1.4.15 [list load [file join $dir tcl9tkimgtiff1415.dll]]
} else {
    package ifneeded img::tiff 1.4.15 [list load [file join $dir tkimgtiff1415.dll]]
}
if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded img::window 1.4.15 [list load [file join $dir tcl9tkimgwindow1415.dll]]
} else {
    package ifneeded img::window 1.4.15 [list load [file join $dir tkimgwindow1415.dll]]
}
if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded img::xbm 1.4.15 [list load [file join $dir tcl9tkimgxbm1415.dll]]
} else {
    package ifneeded img::xbm 1.4.15 [list load [file join $dir tkimgxbm1415.dll]]
}
if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded img::xpm 1.4.15 [list load [file join $dir tcl9tkimgxpm1415.dll]]
} else {
    package ifneeded img::xpm 1.4.15 [list load [file join $dir tkimgxpm1415.dll]]
}
if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded img::dted 1.4.15 [list load [file join $dir tcl9tkimgdted1415.dll]]
} else {
    package ifneeded img::dted 1.4.15 [list load [file join $dir tkimgdted1415.dll]]
}
if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded img::raw 1.4.15 [list load [file join $dir tcl9tkimgraw1415.dll]]
} else {
    package ifneeded img::raw 1.4.15 [list load [file join $dir tkimgraw1415.dll]]
}
if {[package vsatisfies [package provide Tcl] 9.0-]} {
    package ifneeded img::flir 1.4.15 [list load [file join $dir tcl9tkimgflir1415.dll]]
} else {
    package ifneeded img::flir 1.4.15 [list load [file join $dir tkimgflir1415.dll]]
}
