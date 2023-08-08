#==============================================================================
# Contains procedures that create various SVG or bitmap images.
#
# Copyright (c) 2021-2023  Csaba Nemethi (E-mail: csaba.nemethi@t-online.de)
#==============================================================================

package require Tk 8.4

#------------------------------------------------------------------------------
# scrollutil::getForegroundColors
#
# Gets the normal and disabled foreground colors.
#------------------------------------------------------------------------------
proc scrollutil::getForegroundColors {normalFgName disabledFgName} {
    upvar $normalFgName normalFg  $disabledFgName disabledFg

    if {[set normalFg [ttk::style lookup . -foreground]] eq ""} {
	set normalFg black
    }

    array set arr [ttk::style map . -foreground]
    if {[info exists arr(disabled)]} {
	set disabledFg $arr(disabled)
    } else {
	set disabledFg $normalFg
    }
}

#------------------------------------------------------------------------------
# scrollutil::createCloseImages
#
# Creates the SVG or bitmap images scrollutil_close*Img.
#------------------------------------------------------------------------------
proc scrollutil::createCloseImages {} {
    variable svgSupported
    if {$svgSupported} {
	createCloseImages_svg
    } else {
	createCloseImages_xbm
    }
}

#------------------------------------------------------------------------------
# scrollutil::createLeftArrowImage
#
# Creates the SVG or bitmap image scrollutil_leftArrowImg.
#------------------------------------------------------------------------------
proc scrollutil::createLeftArrowImage {} {
    variable svgSupported
    if {$svgSupported} {
	createLeftArrowImage_svg
    } else {
	createLeftArrowImage_xbm
    }
}

#------------------------------------------------------------------------------
# scrollutil::createRightArrowImage
#
# Creates the SVG or bitmap image scrollutil_rightArrowImg.
#------------------------------------------------------------------------------
proc scrollutil::createRightArrowImage {} {
    variable svgSupported
    if {$svgSupported} {
	createRightArrowImage_svg
    } else {
	createRightArrowImage_xbm
    }
}

#------------------------------------------------------------------------------
# scrollutil::createDescendImages
#
# Creates the SVG or bitmap images scrollutil_descend*Img.
#------------------------------------------------------------------------------
proc scrollutil::createDescendImages {} {
    variable svgSupported
    if {$svgSupported} {
	createDescendImages_svg
    } else {
	createDescendImages_xbm
    }
}

#------------------------------------------------------------------------------
# scrollutil::createAscendImage
#
# Creates the SVG or bitmap image scrollutil_ascendImg.
#------------------------------------------------------------------------------
proc scrollutil::createAscendImage {} {
    variable svgSupported
    if {$svgSupported} {
	createAscendImage_svg
    } else {
	createAscendImage_xbm
    }
}

#------------------------------------------------------------------------------
# scrollutil::setImgForeground
#
# Sets the foreground of a given image to the specified color.
#------------------------------------------------------------------------------
proc scrollutil::setImgForeground {imgName color} {
    if {[image type $imgName] eq "bitmap"} {
	$imgName configure -foreground $color
    } else {
	variable svgfmt

	switch $imgName {
	    scrollutil_closeImg -
	    scrollutil_closeDisabledImg {
		variable closeData
		set data $closeData
	    }
	    scrollutil_leftArrowImg {
		variable leftArrowData
		set data $leftArrowData
	    }
	    scrollutil_rightArrowImg {
		variable rightArrowData
		set data $rightArrowData
	    }
	    scrollutil_descendImg -
	    scrollutil_descendDisabledImg {
		variable descendData
		set data $descendData
	    }
	    scrollutil_ascendImg {
		variable ascendData
		set data $ascendData
	    }
	}

	set idx1 [string first "#000" $data]
	set idx2 [expr {$idx1 + 3}]
	set color [mwutil::normalizeColor $color]
	set data [string replace $data $idx1 $idx2 $color]

	image create photo $imgName -format $svgfmt -data $data
    }
}

#------------------------------------------------------------------------------
# scrollutil::createCloseImages_svg
#
# Creates the SVG images scrollutil_close*Img.
#------------------------------------------------------------------------------
proc scrollutil::createCloseImages_svg {} {
    variable svgfmt

    variable closeData {
<svg width="16" height="16" version="1.1" xmlns="http://www.w3.org/2000/svg">
 <path d="m4.5 4.5 7 7m0-7-7 7" fill="none" stroke="#000" stroke-linecap="round"/>
</svg>
    }

    set idx1 [string first "#000" $closeData]
    set idx2 [expr {$idx1 + 3}]
    getForegroundColors normalFg disabledFg
    set normalFg   [mwutil::normalizeColor $normalFg]
    set disabledFg [mwutil::normalizeColor $disabledFg]

    set data [string replace $closeData $idx1 $idx2 $normalFg]
    image create photo scrollutil_closeImg -format $svgfmt -data $data

    set data [string replace $closeData $idx1 $idx2 $disabledFg]
    image create photo scrollutil_closeDisabledImg -format $svgfmt -data $data

    set data {
<svg width="16" height="16" version="1.1" xmlns="http://www.w3.org/2000/svg">
 <rect width="16" height="16" rx="2" fill="#ff6666"/>
 <path d="m4.5 4.5 7 7m0-7-7 7" fill="none" stroke="#fff" stroke-linecap="round"/>
</svg>
    }

    image create photo scrollutil_closeHoverImg -format $svgfmt -data $data

    set idx1 [string first "#ff6666" $data]
    set idx2 [expr {$idx1 + 6}]
    set data [string replace $data $idx1 $idx2 "#e60000"]
    image create photo scrollutil_closePressedImg -format $svgfmt -data $data
}

#------------------------------------------------------------------------------
# scrollutil::createCloseImages_xbm
#
# Creates the bitmap images scrollutil_close*Img.
#------------------------------------------------------------------------------
proc scrollutil::createCloseImages_xbm {} {
    variable scalingpct
    switch $scalingpct {
	100 {
	    set closeData "
#define close100_width 16
#define close100_height 15
static unsigned char close100_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x30, 0x0c, 0x60, 0x06,
   0xc0, 0x03, 0x80, 0x01, 0xc0, 0x03, 0x60, 0x06, 0x30, 0x0c, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00};"
	}

	125 {
	    set closeData "
#define close125_width 20
#define close125_height 19
static unsigned char close125_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x60, 0x60, 0x00, 0xc0, 0x30, 0x00, 0x80, 0x19, 0x00,
   0x00, 0x0f, 0x00, 0x00, 0x06, 0x00, 0x00, 0x0f, 0x00, 0x80, 0x19, 0x00,
   0xc0, 0x30, 0x00, 0x60, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};"
	}

	150 {
	    set closeData "
#define close150_width 24
#define close150_height 23
static unsigned char close150_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xc0, 0x00, 0x03, 0x80, 0x81, 0x01,
   0x00, 0xc3, 0x00, 0x00, 0x66, 0x00, 0x00, 0x3c, 0x00, 0x00, 0x18, 0x00,
   0x00, 0x3c, 0x00, 0x00, 0x66, 0x00, 0x00, 0xc3, 0x00, 0x80, 0x81, 0x01,
   0xc0, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};"
	}

	175 {
	    set closeData "
#define close175_width 28
#define close175_height 28
static unsigned char close175_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x80, 0x01, 0x18, 0x00, 0x80, 0x03, 0x1c, 0x00,
   0x00, 0x07, 0x0e, 0x00, 0x00, 0x0e, 0x07, 0x00, 0x00, 0x9c, 0x03, 0x00,
   0x00, 0xf8, 0x01, 0x00, 0x00, 0xf0, 0x00, 0x00, 0x00, 0xf0, 0x00, 0x00,
   0x00, 0xf8, 0x01, 0x00, 0x00, 0x9c, 0x03, 0x00, 0x00, 0x0e, 0x07, 0x00,
   0x00, 0x07, 0x0e, 0x00, 0x80, 0x03, 0x1c, 0x00, 0x80, 0x01, 0x18, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00};"
	}

	200 {
	    set closeData "
#define close200_width 32
#define close200_height 32
static unsigned char close200_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0xc0, 0x00,
   0x00, 0x07, 0xe0, 0x00, 0x00, 0x0e, 0x70, 0x00, 0x00, 0x1c, 0x38, 0x00,
   0x00, 0x38, 0x1c, 0x00, 0x00, 0x70, 0x0e, 0x00, 0x00, 0xe0, 0x07, 0x00,
   0x00, 0xc0, 0x03, 0x00, 0x00, 0xc0, 0x03, 0x00, 0x00, 0xe0, 0x07, 0x00,
   0x00, 0x70, 0x0e, 0x00, 0x00, 0x38, 0x1c, 0x00, 0x00, 0x1c, 0x38, 0x00,
   0x00, 0x0e, 0x70, 0x00, 0x00, 0x07, 0xe0, 0x00, 0x00, 0x03, 0xc0, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};"
	}
    }

    getForegroundColors normalFg disabledFg

    image create bitmap scrollutil_closeImg -data $closeData \
	-foreground $normalFg
    image create bitmap scrollutil_closeDisabledImg -data $closeData \
	-foreground $disabledFg
    image create bitmap scrollutil_closeHoverImg -data $closeData \
	-foreground #ffffff -background #ff6666
    image create bitmap scrollutil_closePressedImg -data $closeData \
	-foreground #ffffff -background #e60000
}

#------------------------------------------------------------------------------
# scrollutil::createLeftArrowImage_svg
#
# Creates the SVG image scrollutil_leftArrowImg.
#------------------------------------------------------------------------------
proc scrollutil::createLeftArrowImage_svg {} {
    variable svgfmt

    variable leftArrowData {
<svg width="8" height="16" version="1.1" xmlns="http://www.w3.org/2000/svg">
 <path d="m8 0-8 8 8 8z" fill="#000"/>
</svg>
    }

    set idx1 [string first "#000" $leftArrowData]
    set idx2 [expr {$idx1 + 3}]
    getForegroundColors normalFg disabledFg
    set normalFg [mwutil::normalizeColor $normalFg]

    set data [string replace $leftArrowData $idx1 $idx2 $normalFg]
    image create photo scrollutil_leftArrowImg -format $svgfmt -data $data
}

#------------------------------------------------------------------------------
# scrollutil::createLeftArrowImage_xbm
#
# Creates the bitmap image scrollutil_leftArrowImg.
#------------------------------------------------------------------------------
proc scrollutil::createLeftArrowImage_xbm {} {
    variable scalingpct
    switch $scalingpct {
	100 {
	    set leftArrowData "
#define leftArrow100_width 8
#define leftArrow100_height 16
static unsigned char leftArrow100_bits[] = {
   0x80, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc, 0xfe, 0xff, 0xff, 0xfe, 0xfc, 0xf8,
   0xf0, 0xe0, 0xc0, 0x80};"
	}

	125 {
	    set leftArrowData "
#define leftArrow125_width 10
#define leftArrow125_height 20
static unsigned char leftArrow125_bits[] = {
   0x00, 0x02, 0x00, 0x03, 0x80, 0x03, 0xc0, 0x03, 0xe0, 0x03, 0xf0, 0x03,
   0xf8, 0x03, 0xfc, 0x03, 0xfe, 0x03, 0xff, 0x03, 0xff, 0x03, 0xfe, 0x03,
   0xfc, 0x03, 0xf8, 0x03, 0xf0, 0x03, 0xe0, 0x03, 0xc0, 0x03, 0x80, 0x03,
   0x00, 0x03, 0x00, 0x02};"
	}

	150 {
	    set leftArrowData "
#define leftArrow150_width 12
#define leftArrow150_height 24
static unsigned char leftArrow150_bits[] = {
   0x00, 0x08, 0x00, 0x0c, 0x00, 0x0e, 0x00, 0x0f, 0x80, 0x0f, 0xc0, 0x0f,
   0xe0, 0x0f, 0xf0, 0x0f, 0xf8, 0x0f, 0xfc, 0x0f, 0xfe, 0x0f, 0xff, 0x0f,
   0xff, 0x0f, 0xfe, 0x0f, 0xfc, 0x0f, 0xf8, 0x0f, 0xf0, 0x0f, 0xe0, 0x0f,
   0xc0, 0x0f, 0x80, 0x0f, 0x00, 0x0f, 0x00, 0x0e, 0x00, 0x0c, 0x00, 0x08};"
	}

	175 {
	    set leftArrowData "
#define leftArrow175_width 14
#define leftArrow175_height 28
static unsigned char leftArrow175_bits[] = {
   0x00, 0x20, 0x00, 0x30, 0x00, 0x38, 0x00, 0x3c, 0x00, 0x3e, 0x00, 0x3f,
   0x80, 0x3f, 0xc0, 0x3f, 0xe0, 0x3f, 0xf0, 0x3f, 0xf8, 0x3f, 0xfc, 0x3f,
   0xfe, 0x3f, 0xff, 0x3f, 0xff, 0x3f, 0xfe, 0x3f, 0xfc, 0x3f, 0xf8, 0x3f,
   0xf0, 0x3f, 0xe0, 0x3f, 0xc0, 0x3f, 0x80, 0x3f, 0x00, 0x3f, 0x00, 0x3e,
   0x00, 0x3c, 0x00, 0x38, 0x00, 0x30, 0x00, 0x20};"
	}

	200 {
	    set leftArrowData "
#define leftArrow200_width 16
#define leftArrow200_height 32
static unsigned char leftArrow200_bits[] = {
   0x00, 0x80, 0x00, 0xc0, 0x00, 0xe0, 0x00, 0xf0, 0x00, 0xf8, 0x00, 0xfc,
   0x00, 0xfe, 0x00, 0xff, 0x80, 0xff, 0xc0, 0xff, 0xe0, 0xff, 0xf0, 0xff,
   0xf8, 0xff, 0xfc, 0xff, 0xfe, 0xff, 0xff, 0xff, 0xff, 0xff, 0xfe, 0xff,
   0xfc, 0xff, 0xf8, 0xff, 0xf0, 0xff, 0xe0, 0xff, 0xc0, 0xff, 0x80, 0xff,
   0x00, 0xff, 0x00, 0xfe, 0x00, 0xfc, 0x00, 0xf8, 0x00, 0xf0, 0x00, 0xe0,
   0x00, 0xc0, 0x00, 0x80};"
	}
    }

    getForegroundColors normalFg disabledFg

    image create bitmap scrollutil_leftArrowImg -data $leftArrowData \
	-foreground $normalFg
}

#------------------------------------------------------------------------------
# scrollutil::createRightArrowImage_svg
#
# Creates the SVG image scrollutil_rightArrowImg.
#------------------------------------------------------------------------------
proc scrollutil::createRightArrowImage_svg {} {
    variable svgfmt

    variable rightArrowData {
<svg width="8" height="16" version="1.1" xmlns="http://www.w3.org/2000/svg">
 <path d="m0 0 8 8-8 8z" fill="#000"/>
</svg>
    }

    set idx1 [string first "#000" $rightArrowData]
    set idx2 [expr {$idx1 + 3}]
    getForegroundColors normalFg disabledFg
    set normalFg [mwutil::normalizeColor $normalFg]

    set data [string replace $rightArrowData $idx1 $idx2 $normalFg]
    image create photo scrollutil_rightArrowImg -format $svgfmt -data $data
}

#------------------------------------------------------------------------------
# scrollutil::createRightArrowImage_xbm
#
# Creates the image scrollutil_rightArrowImg.
#------------------------------------------------------------------------------
proc scrollutil::createRightArrowImage_xbm {} {
    variable scalingpct
    switch $scalingpct {
	100 {
	    set rightArrowData "
#define rightArrow100_width 8
#define rightArrow100_height 16
static unsigned char rightArrow100_bits[] = {
   0x01, 0x03, 0x07, 0x0f, 0x1f, 0x3f, 0x7f, 0xff, 0xff, 0x7f, 0x3f, 0x1f,
   0x0f, 0x07, 0x03, 0x01};"
	}

	125 {
	    set rightArrowData "
#define rightArrow125_width 10
#define rightArrow125_height 20
static unsigned char rightArrow125_bits[] = {
   0x01, 0x00, 0x03, 0x00, 0x07, 0x00, 0x0f, 0x00, 0x1f, 0x00, 0x3f, 0x00,
   0x7f, 0x00, 0xff, 0x00, 0xff, 0x01, 0xff, 0x03, 0xff, 0x03, 0xff, 0x01,
   0xff, 0x00, 0x7f, 0x00, 0x3f, 0x00, 0x1f, 0x00, 0x0f, 0x00, 0x07, 0x00,
   0x03, 0x00, 0x01, 0x00};"
	}

	150 {
	    set rightArrowData "
#define rightArrow150_width 12
#define rightArrow150_height 24
static unsigned char rightArrow150_bits[] = {
   0x01, 0x00, 0x03, 0x00, 0x07, 0x00, 0x0f, 0x00, 0x1f, 0x00, 0x3f, 0x00,
   0x7f, 0x00, 0xff, 0x00, 0xff, 0x01, 0xff, 0x03, 0xff, 0x07, 0xff, 0x0f,
   0xff, 0x0f, 0xff, 0x07, 0xff, 0x03, 0xff, 0x01, 0xff, 0x00, 0x7f, 0x00,
   0x3f, 0x00, 0x1f, 0x00, 0x0f, 0x00, 0x07, 0x00, 0x03, 0x00, 0x01, 0x00};"
	}

	175 {
	    set rightArrowData "
#define rightArrow175_width 14
#define rightArrow175_height 28
static unsigned char rightArrow175_bits[] = {
   0x01, 0x00, 0x03, 0x00, 0x07, 0x00, 0x0f, 0x00, 0x1f, 0x00, 0x3f, 0x00,
   0x7f, 0x00, 0xff, 0x00, 0xff, 0x01, 0xff, 0x03, 0xff, 0x07, 0xff, 0x0f,
   0xff, 0x1f, 0xff, 0x3f, 0xff, 0x3f, 0xff, 0x1f, 0xff, 0x0f, 0xff, 0x07,
   0xff, 0x03, 0xff, 0x01, 0xff, 0x00, 0x7f, 0x00, 0x3f, 0x00, 0x1f, 0x00,
   0x0f, 0x00, 0x07, 0x00, 0x03, 0x00, 0x01, 0x00};"
	}

	200 {
	    set rightArrowData "
#define rightArrow200_width 16
#define rightArrow200_height 32
static unsigned char rightArrow200_bits[] = {
   0x01, 0x00, 0x03, 0x00, 0x07, 0x00, 0x0f, 0x00, 0x1f, 0x00, 0x3f, 0x00,
   0x7f, 0x00, 0xff, 0x00, 0xff, 0x01, 0xff, 0x03, 0xff, 0x07, 0xff, 0x0f,
   0xff, 0x1f, 0xff, 0x3f, 0xff, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f,
   0xff, 0x3f, 0xff, 0x1f, 0xff, 0x0f, 0xff, 0x07, 0xff, 0x03, 0xff, 0x01,
   0xff, 0x00, 0x7f, 0x00, 0x3f, 0x00, 0x1f, 0x00, 0x0f, 0x00, 0x07, 0x00,
   0x03, 0x00, 0x01, 0x00};"
	}
    }

    getForegroundColors normalFg disabledFg

    image create bitmap scrollutil_rightArrowImg -data $rightArrowData \
	-foreground $normalFg
}

#------------------------------------------------------------------------------
# scrollutil::createDescendImages_svg
#
# Creates the SVG images scrollutil_descend*Img.
#------------------------------------------------------------------------------
proc scrollutil::createDescendImages_svg {} {
    variable svgfmt

    variable descendData {
<svg width="8" height="12" version="1.1" xmlns="http://www.w3.org/2000/svg">
 <path d="m1 0.5 6 5.5-6 5.5" fill="none" stroke="#000" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
    }

    set idx1 [string first "#000" $descendData]
    set idx2 [expr {$idx1 + 3}]
    getForegroundColors normalFg disabledFg
    set normalFg   [mwutil::normalizeColor $normalFg]
    set disabledFg [mwutil::normalizeColor $disabledFg]

    set data [string replace $descendData $idx1 $idx2 $normalFg]
    image create photo scrollutil_descendImg -format $svgfmt -data $data

    set data [string replace $descendData $idx1 $idx2 $disabledFg]
    image create photo scrollutil_descendDisabledImg -format $svgfmt -data $data
}

#------------------------------------------------------------------------------
# scrollutil::createDescendImages_xbm
#
# Creates the bitmap images scrollutil_descend*Img.
#------------------------------------------------------------------------------
proc scrollutil::createDescendImages_xbm {} {
    variable scalingpct
    switch $scalingpct {
	100 {
	    set descendData "
#define descend100_width 7
#define descend100_height 12
static unsigned char descend100_bits[] = {
   0x03, 0x06, 0x0c, 0x18, 0x30, 0x60, 0x60, 0x30, 0x18, 0x0c, 0x06, 0x03};"
	}

	125 {
	    set descendData "
#define descend125_width 9
#define descend125_height 16
static unsigned char descend125_bits[] = {
   0x03, 0x00, 0x06, 0x00, 0x0c, 0x00, 0x18, 0x00, 0x30, 0x00, 0x60, 0x00,
   0xc0, 0x00, 0x80, 0x01, 0x80, 0x01, 0xc0, 0x00, 0x60, 0x00, 0x30, 0x00,
   0x18, 0x00, 0x0c, 0x00, 0x06, 0x00, 0x03, 0x00};"
	}

	150 {
	    set descendData "
#define descend150_width 10
#define descend150_height 18
static unsigned char descend150_bits[] = {
   0x03, 0x00, 0x06, 0x00, 0x0c, 0x00, 0x18, 0x00, 0x30, 0x00, 0x60, 0x00,
   0xc0, 0x00, 0x80, 0x01, 0x00, 0x03, 0x00, 0x03, 0x80, 0x01, 0xc0, 0x00,
   0x60, 0x00, 0x30, 0x00, 0x18, 0x00, 0x0c, 0x00, 0x06, 0x00, 0x03, 0x00};"
	}

	175 {
	    set descendData "
#define descend175_width 12
#define descend175_height 22
static unsigned char descend175_bits[] = {
   0x03, 0x00, 0x07, 0x00, 0x0e, 0x00, 0x1c, 0x00, 0x38, 0x00, 0x70, 0x00,
   0xe0, 0x00, 0xc0, 0x01, 0x80, 0x03, 0x00, 0x07, 0x00, 0x0e, 0x00, 0x0e,
   0x00, 0x07, 0x80, 0x03, 0xc0, 0x01, 0xe0, 0x00, 0x70, 0x00, 0x38, 0x00,
   0x1c, 0x00, 0x0e, 0x00, 0x07, 0x00, 0x03, 0x00};"
	}

	200 {
	    set descendData "
#define descend200_width 13
#define descend200_height 24
static unsigned char descend200_bits[] = {
   0x03, 0x00, 0x07, 0x00, 0x0e, 0x00, 0x1c, 0x00, 0x38, 0x00, 0x70, 0x00,
   0xe0, 0x00, 0xc0, 0x01, 0x80, 0x03, 0x00, 0x07, 0x00, 0x0e, 0x00, 0x1c,
   0x00, 0x1c, 0x00, 0x0e, 0x00, 0x07, 0x80, 0x03, 0xc0, 0x01, 0xe0, 0x00,
   0x70, 0x00, 0x38, 0x00, 0x1c, 0x00, 0x0e, 0x00, 0x07, 0x00, 0x03, 0x00};"
	}
    }

    getForegroundColors normalFg disabledFg

    image create bitmap scrollutil_descendImg -data $descendData \
	-foreground $normalFg
    image create bitmap scrollutil_descendDisabledImg -data $descendData \
	-foreground $disabledFg
}

#------------------------------------------------------------------------------
# scrollutil::createAscendImage_svg
#
# Creates the SVG image scrollutil_ascendImg.
#------------------------------------------------------------------------------
proc scrollutil::createAscendImage_svg {} {
    variable svgfmt

    variable ascendData {
<svg width="16" height="16" version="1.1" xmlns="http://www.w3.org/2000/svg">
 <path d="m10 3-5 5 5 5" fill="none" stroke="#000" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"/>
</svg>
    }

    set idx1 [string first "#000" $ascendData]
    set idx2 [expr {$idx1 + 3}]
    getForegroundColors normalFg disabledFg
    set normalFg [mwutil::normalizeColor $normalFg]

    set data [string replace $ascendData $idx1 $idx2 $normalFg]
    image create photo scrollutil_ascendImg -format $svgfmt -data $data
}

#------------------------------------------------------------------------------
# scrollutil::createAscendImage_xbm
#
# Creates the bitmap image scrollutil_ascendImg.
#------------------------------------------------------------------------------
proc scrollutil::createAscendImage_xbm {} {
    variable scalingpct
    switch $scalingpct {
	100 {
	    set ascendData "
#define ascend100_width 16
#define ascend100_height 16
static unsigned char ascend100_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x00, 0x07, 0x80, 0x03, 0xc0, 0x01,
   0xe0, 0x00, 0x70, 0x00, 0x70, 0x00, 0xe0, 0x00, 0xc0, 0x01, 0x80, 0x03,
   0x00, 0x07, 0x00, 0x06, 0x00, 0x00, 0x00, 0x00};"
	}

	125 {
	    set ascendData "
#define ascend125_width 20
#define ascend125_height 20
static unsigned char ascend125_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x30, 0x00,
   0x00, 0x38, 0x00, 0x00, 0x1c, 0x00, 0x00, 0x0e, 0x00, 0x00, 0x07, 0x00,
   0x80, 0x03, 0x00, 0xc0, 0x01, 0x00, 0xc0, 0x01, 0x00, 0x80, 0x03, 0x00,
   0x00, 0x07, 0x00, 0x00, 0x0e, 0x00, 0x00, 0x1c, 0x00, 0x00, 0x38, 0x00,
   0x00, 0x30, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};"
	}

	150 {
	    set ascendData "
#define ascend150_width 24
#define ascend150_height 24
static unsigned char ascend150_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x01,
   0x00, 0xc0, 0x01, 0x00, 0xe0, 0x00, 0x00, 0x70, 0x00, 0x00, 0x38, 0x00,
   0x00, 0x1c, 0x00, 0x00, 0x0e, 0x00, 0x00, 0x07, 0x00, 0x80, 0x03, 0x00,
   0x80, 0x03, 0x00, 0x00, 0x07, 0x00, 0x00, 0x0e, 0x00, 0x00, 0x1c, 0x00,
   0x00, 0x38, 0x00, 0x00, 0x70, 0x00, 0x00, 0xe0, 0x00, 0x00, 0xc0, 0x01,
   0x00, 0x80, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};"
	}

	175 {
	    set ascendData "
#define ascend175_width 28
#define ascend175_height 28
static unsigned char ascend175_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0e, 0x00, 0x00, 0x00, 0x0f, 0x00,
   0x00, 0x80, 0x07, 0x00, 0x00, 0xc0, 0x03, 0x00, 0x00, 0xe0, 0x01, 0x00,
   0x00, 0xf0, 0x00, 0x00, 0x00, 0x78, 0x00, 0x00, 0x00, 0x3c, 0x00, 0x00,
   0x00, 0x1e, 0x00, 0x00, 0x00, 0x0f, 0x00, 0x00, 0x00, 0x07, 0x00, 0x00,
   0x00, 0x0f, 0x00, 0x00, 0x00, 0x1e, 0x00, 0x00, 0x00, 0x3c, 0x00, 0x00,
   0x00, 0x78, 0x00, 0x00, 0x00, 0xf0, 0x00, 0x00, 0x00, 0xe0, 0x01, 0x00,
   0x00, 0xc0, 0x03, 0x00, 0x00, 0x80, 0x07, 0x00, 0x00, 0x00, 0x0f, 0x00,
   0x00, 0x00, 0x0e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00};"
	}

	200 {
	    set ascendData "
#define ascend200_width 32
#define ascend200_height 32
static unsigned char ascend200_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x38, 0x00,
   0x00, 0x00, 0x3c, 0x00, 0x00, 0x00, 0x1e, 0x00, 0x00, 0x00, 0x0f, 0x00,
   0x00, 0x80, 0x07, 0x00, 0x00, 0xc0, 0x03, 0x00, 0x00, 0xe0, 0x01, 0x00,
   0x00, 0xf0, 0x00, 0x00, 0x00, 0x78, 0x00, 0x00, 0x00, 0x3c, 0x00, 0x00,
   0x00, 0x1e, 0x00, 0x00, 0x00, 0x0e, 0x00, 0x00, 0x00, 0x1e, 0x00, 0x00,
   0x00, 0x3c, 0x00, 0x00, 0x00, 0x78, 0x00, 0x00, 0x00, 0xf0, 0x00, 0x00,
   0x00, 0xe0, 0x01, 0x00, 0x00, 0xc0, 0x03, 0x00, 0x00, 0x80, 0x07, 0x00,
   0x00, 0x00, 0x0f, 0x00, 0x00, 0x00, 0x1e, 0x00, 0x00, 0x00, 0x3c, 0x00,
   0x00, 0x00, 0x38, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};"
	}
    }

    getForegroundColors normalFg disabledFg

    image create bitmap scrollutil_ascendImg -data $ascendData \
	-foreground $normalFg
}