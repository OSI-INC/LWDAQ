#==============================================================================
# Contains the implementation of the scrollsync widget.
#
# Structure of the module:
#   - Namespace initialization
#   - Private procedure creating the default bindings
#   - Public procedure creating a new scrollsync widget
#   - Private configuration procedures
#   - Private procedures implementing the scrollsync widget command
#   - Private callback procedure
#   - Private procedures used in bindings
#   - Private utility procedures
#
# Copyright (c) 2019  Csaba Nemethi (E-mail: csaba.nemethi@t-online.de)
#==============================================================================

#
# Namespace initialization
# ========================
#

namespace eval scrollutil::ss {
    #
    # The array configSpecs is used to handle configuration options.  The names
    # of its elements are the configuration options for the Scrollsync class.
    # The value of an array element is either an alias name or a list
    # containing the database name and class as well as an indicator specifying
    # the widget to which the option applies: f stands for the frame and w for
    # the scrollsync widget itself.
    #
    #	Command-Line Name	 {Database Name		  Database Class      W}
    #	------------------------------------------------------------------------
    #
    variable configSpecs
    array set configSpecs {
	-background		{background		Background	     f}
	-bg			-background
	-borderwidth		{borderWidth		BorderWidth	     f}
	-bd			-borderwidth
	-cursor			{cursor			Cursor		     f}
	-highlightbackground	{highlightBackground	HighlightBackground  f}
	-highlightcolor		{highlightColor		HighlightColor	     f}
	-highlightthickness	{highlightThickness	HighlightThickness   f}
	-relief			{relief			Relief		     f}
	-takefocus		{takeFocus		TakeFocus	     f}
	-xscrollcommand		{xScrollCommand		ScrollCommand	     w}
	-yscrollcommand		{yScrollCommand		ScrollCommand	     w}
    }

    #
    # Extend the elements of the array configSpecs
    #
    proc extendConfigSpecs {} {
	variable ::scrollutil::usingTile
	variable configSpecs

	if {$usingTile} {
	    foreach opt {-background -bg -highlightbackground -highlightcolor
			 -highlightthickness} {
		unset configSpecs($opt)
	    }
	} else {
	    set helpFrm .__helpFrm
	    for {set n 2} {[winfo exists $helpFrm]} {incr n} {
		set helpFrm .__helpFrm$n
	    }
	    tk::frame $helpFrm
	    foreach opt {-background -highlightbackground -highlightcolor
			 -highlightthickness} {
		set configSet [$helpFrm configure $opt]
		lappend configSpecs($opt) [lindex $configSet 3]
	    }
	    destroy $helpFrm
	}

	lappend configSpecs(-borderwidth) 0
	lappend configSpecs(-cursor) ""
	lappend configSpecs(-relief) flat
	lappend configSpecs(-takefocus) 0
	lappend configSpecs(-xscrollcommand) ""
	lappend configSpecs(-yscrollcommand) ""
    }
    extendConfigSpecs 

    variable configOpts [lsort [array names configSpecs]]

    #
    # Use a list to facilitate the handling of the command options
    #
    variable cmdOpts [list cget configure setwidgets widgets xview yview]
}

#
# Private procedure creating the default bindings
# ===============================================
#

#------------------------------------------------------------------------------
# scrollutil::ss::createBindings
#
# Creates the default bindings for the binding tags Scrollsync and
# WidgetOfScrollsync.
#------------------------------------------------------------------------------
proc scrollutil::ss::createBindings {} {
    bind Scrollsync <KeyPress> continue
    bind Scrollsync <FocusIn> {
        if {[string compare [focus -lastfor %W] %W] == 0} {
            focus [lindex [%W widgets] 0]
        }
    }
    bind Scrollsync <Configure> { scrollutil::ss::onScrollsyncConfigure %W }
    bind Scrollsync <Destroy>   { scrollutil::ss::onScrollsyncDestroy %W }

    bind WidgetOfScrollsync <Destroy> {
	scrollutil::ss::onWidgetOfScrollsyncDestroy %W
    }
}

#
# Public procedure creating a new scrollsync widget
# =================================================
#

#------------------------------------------------------------------------------
# scrollutil::scrollsync
#
# Creates a new scrollsync widget whose name is specified as the first command-
# line argument, and configures it according to the options and their values
# given on the command line.  Returns the name of the newly created widget.
#------------------------------------------------------------------------------
proc scrollutil::scrollsync args {
    variable usingTile
    variable ss::configSpecs
    variable ss::configOpts

    if {[llength $args] == 0} {
	mwutil::wrongNumArgs "scrollsync pathName ?options?"
    }

    #
    # Create a frame of the class Scrollsync
    #
    set win [lindex $args 0]
    if {[catch {
	if {$usingTile} {
	    ttk::frame $win -class Scrollsync -padding 0
	} else {
	    tk::frame $win -class Scrollsync -container 0
	    catch {$win configure -padx 0 -pady 0}
	}
	$win configure -height 0 -width 0
    } result] != 0} {
	return -code error $result
    }

    #
    # Create a namespace within the current one to hold the data of the widget
    #
    namespace eval ns$win {
	#
	# The folowing array holds various data for this widget
	#
	variable data
	array set data {
	    xviewLocked		0
	    yviewLocked		0
	    widgetList		{}
	    xScrollableList	{}
	    yScrollableList	{}
	}
    }

    #
    # Initialize some further components of data
    #
    upvar ::scrollutil::ns${win}::data data
    foreach opt $configOpts {
	set data($opt) [lindex $configSpecs($opt) 3]
    }

    #
    # Configure the widget according to the command-line
    # arguments and to the available database options
    #
    if {[catch {
	mwutil::configureWidget $win configSpecs scrollutil::ss::doConfig \
				scrollutil::ss::doCget [lrange $args 1 end] 1
    } result] != 0} {
	destroy $win
	return -code error $result
    }

    #
    # Move the original widget command into the namespace ss within the current
    # one and create an alias of the original name for a new widget procedure
    #
    rename ::$win ss::$win
    interp alias {} ::$win {} scrollutil::ss::scrollsyncWidgetCmd $win

    return $win
}

#
# Private configuration procedures
# ================================
#

#------------------------------------------------------------------------------
# scrollutil::ss::doConfig
#
# Applies the value val of the configuration option opt to the scrollsync
# widget win.
#------------------------------------------------------------------------------
proc scrollutil::ss::doConfig {win opt val} {
    variable configSpecs
    upvar ::scrollutil::ns${win}::data data

    #
    # Apply the value to the widget corresponding to the given option
    #
    switch [lindex $configSpecs($opt) 2] {
	f {
	    #
	    # Apply the value to the frame and save the
	    # properly formatted value of val in data($opt)
	    #
	    $win configure $opt $val
	    set data($opt) [$win cget $opt]
	}

	w {
	    switch -- $opt {
		-xscrollcommand -
		-yscrollcommand {
		    set data($opt) $val
		}
	    }
	}
    }
}

#------------------------------------------------------------------------------
# scrollutil::ss::doCget
#
# Returns the value of the configuration option opt for the scrollsync widget
# win.
#------------------------------------------------------------------------------
proc scrollutil::ss::doCget {win opt} {
    upvar ::scrollutil::ns${win}::data data
    return $data($opt)
}

#
# Private procedures implementing the scrollsync widget command
# =============================================================
#

#------------------------------------------------------------------------------
# scrollutil::ss::scrollsyncWidgetCmd
#
# Processes the Tcl command corresponding to a scrollsync widget.
#------------------------------------------------------------------------------
proc scrollutil::ss::scrollsyncWidgetCmd {win args} {
    set argCount [llength $args]
    if {$argCount == 0} {
	mwutil::wrongNumArgs "$win option ?arg arg ...?"
    }

    variable cmdOpts
    set cmd [mwutil::fullOpt "option" [lindex $args 0] $cmdOpts]
    switch $cmd {
	cget {
	    if {$argCount != 2} {
		mwutil::wrongNumArgs "$win $cmd option"
	    }

	    #
	    # Return the value of the specified configuration option
	    #
	    upvar ::scrollutil::ns${win}::data data
	    variable configSpecs
	    set opt [mwutil::fullConfigOpt [lindex $args 1] configSpecs]
	    return $data($opt)
	}

	configure {
	    variable configSpecs
	    return [mwutil::configureSubCmd $win configSpecs \
		    scrollutil::ss::doConfig scrollutil::ss::doCget \
		    [lrange $args 1 end]]
	}

	setwidgets {
	    if {$argCount != 2} {
		mwutil::wrongNumArgs "$win $cmd widgetList"
	    }

	    return [setwidgetsSubCmd $win [lindex $args 1]]
	}

	widgets {
	    if {$argCount != 1} {
		mwutil::wrongNumArgs "$win $cmd"
	    }

	    upvar ::scrollutil::ns${win}::data data
	    return $data(widgetList)
	}

	xview {
	    return [viewSubCmd $win x [lrange $args 1 end]]
	}

	yview {
	    return [viewSubCmd $win y [lrange $args 1 end]]
	}
    }
}

#------------------------------------------------------------------------------
# scrollutil::ss::setwidgetsSubCmd
#
# Processes the scrollsync setwidgets subcommmand.
#------------------------------------------------------------------------------
proc scrollutil::ss::setwidgetsSubCmd {win widgetList} {
    upvar ::scrollutil::ns${win}::data data

    foreach w $widgetList {
	if {![winfo exists $w]} {
	    return -code error "bad window path name \"$w\""
	}
    }

    variable scrollsyncArr

    set oldWidgetList $data(widgetList)
    foreach w $oldWidgetList {
	if {[winfo exists $w]} {
	    set tagList [bindtags $w]
	    set idx [lsearch -exact $tagList "WidgetOfScrollsync"]
	    bindtags $w [lreplace $tagList $idx $idx]
	}

	if {[info exists scrollsyncArr($w)]} {
	    unset scrollsyncArr($w)
	}
    }

    array set data {xScrollableList {}  yScrollableList {}}

    foreach w $widgetList {
	set tagList [bindtags $w]
	set idx [lsearch -exact $tagList "WidgetOfScrollsync"]
	if {$idx < 0} {
	    bindtags $w [linsert $tagList 1 WidgetOfScrollsync]
	}

	set scrollsyncArr($w) $win

	foreach axis {x y} {
	    if {[mwutil::isScrollable $w $axis]} {
		lappend data(${axis}ScrollableList) $w
		::$w ${axis}view moveto 0
		::$w configure -${axis}scrollcommand \
		    [list scrollutil::ss::scrollCmd $win $w $axis]
	    }
	}

    }

    set data(widgetList) $widgetList
    return $oldWidgetList
}

#------------------------------------------------------------------------------
# scrollutil::ss::viewSubCmd
#
# Processes the scrollsync xview and yview subcommmands.
#------------------------------------------------------------------------------
proc scrollutil::ss::viewSubCmd {win axis argList} {
    upvar ::scrollutil::ns${win}::data data
    set masterWidget [lindex $data(${axis}ScrollableList) 0]
    set viewCmd ${axis}view

    switch [llength $argList] {
	0 {
	    #
	    # Command: $win (x|y)view
	    #
	    if {[string length $masterWidget] == 0} {
		return [list 0 1]
	    } else {
		return [::$masterWidget $viewCmd]
	    }
	}

	1 {
	    #
	    # Command: $win (x|y)view <units>
	    #
	    return -code error \
		"the command \"$win $viewCmd <units>\" is not supported"
	}

	default {
	    #
	    # Command: $win (x|y)view moveto <fraction>
	    #	       $win (x|y)view scroll <number> units|pages
	    #
	    set argList [mwutil::getScrollInfo $argList]
	    if {[string length $masterWidget] != 0} {
		eval [list ::$masterWidget] $viewCmd $argList
	    }
	    return ""
	}
    }
}

#
# Private callback procedure
# ==========================
#

#------------------------------------------------------------------------------
# scrollutil::ss::scrollCmd
#
# Propagates the position of the horizontal/vertical view of the widget widget
# within the scrollsync win to the other horizontally/vertically scrollable
# widgets and passes the data of the master widget's view to the value of the
# -xscrollcommand/-yscrollcommand option.
#------------------------------------------------------------------------------
proc scrollutil::ss::scrollCmd {win widget axis first last} {
    upvar ::scrollutil::ns${win}::data data
    if {$data(${axis}viewLocked)} {
	return ""
    }

    foreach w $data(${axis}ScrollableList) {
	if {[string compare $w $widget] == 0} {
	    continue
	}

	if {$first != 0 && $last == 1} {
	    ::$w ${axis}view moveto 1
	} else {
	    ::$w ${axis}view moveto $first
	}
    }

    set masterWidget [sortScrollableList $win $axis]
    if {[string length $data(-${axis}scrollcommand)] != 0} {
	eval $data(-${axis}scrollcommand) [::$masterWidget ${axis}view]
    }

    set data(${axis}viewLocked) 1
    after 1 [list scrollutil::ss::unlockView $win $axis]
}

#
# Private procedures used in bindings
# ===================================
#

#------------------------------------------------------------------------------
# scrollutil::ss::onScrollsyncConfigure
#------------------------------------------------------------------------------
proc scrollutil::ss::onScrollsyncConfigure win {
    upvar ::scrollutil::ns${win}::data data
    after 50 [list scrollutil::ss::updateMasterWidgets $win]
}

#------------------------------------------------------------------------------
# scrollutil::ss::updateMasterWidgets
#------------------------------------------------------------------------------
proc scrollutil::ss::updateMasterWidgets win {
    if {![winfo exists $win] ||
	[string compare [winfo class $win] "Scrollsync"] != 0} {
	return ""
    }

    upvar ::scrollutil::ns${win}::data data
    foreach axis {x y} {
	set masterWidget [sortScrollableList $win $axis]
	if {[string length $masterWidget] != 0 &&
	    [string length $data(-${axis}scrollcommand)] != 0} {
	    eval $data(-${axis}scrollcommand) [::$masterWidget ${axis}view]
	}
    }
}

#------------------------------------------------------------------------------
# scrollutil::ss::onScrollsyncDestroy
#------------------------------------------------------------------------------
proc scrollutil::ss::onScrollsyncDestroy win {
    namespace delete ::scrollutil::ns$win
    catch {rename ::$win ""}
}

#------------------------------------------------------------------------------
# scrollutil::ss::onWidgetOfScrollsyncDestroy
#------------------------------------------------------------------------------
proc scrollutil::ss::onWidgetOfScrollsyncDestroy widget {
    variable scrollsyncArr
    set win $scrollsyncArr($widget)
    unset scrollsyncArr($widget)

    if {[winfo exists $win] &&
	[string compare [winfo class $win] "Scrollsync"] == 0} {
	set widgetList [::$win widgets]
	set idx [lsearch -exact $widgetList $widget]
	::$win setwidgets [lreplace $widgetList $idx $idx]
    }
}

#
# Private utility procedures
# ==========================
#

#------------------------------------------------------------------------------
# scrollutil::ss::sortScrollableList
#------------------------------------------------------------------------------
proc scrollutil::ss::sortScrollableList {win axis} {
    upvar ::scrollutil::ns${win}::data data
    set data(${axis}ScrollableList) \
	[lsort -command "compareViews $axis" $data(${axis}ScrollableList)]
    return [lindex $data(${axis}ScrollableList) 0]
}

#------------------------------------------------------------------------------
# scrollutil::ss::compareViews
#------------------------------------------------------------------------------
proc scrollutil::ss::compareViews {axis w1 w2} {
    foreach {first1 last1} [::$w1 ${axis}view] {}
    foreach {first2 last2} [::$w2 ${axis}view] {}
    set fraction1 [expr {$last1 - $first1}]
    set fraction2 [expr {$last2 - $first2}]

    if {$fraction1 < $fraction2} {
	return -1
    } elseif {$fraction1 == $fraction2} {
	return 0
    } else {
	return 1
    }
}

#------------------------------------------------------------------------------
# scrollutil::ss::unlockView
#------------------------------------------------------------------------------
proc scrollutil::ss::unlockView {win axis} {
    if {[winfo exists $win] &&
	[string compare [winfo class $win] "Scrollsync"] == 0} {
	upvar ::scrollutil::ns${win}::data data
	set data(${axis}viewLocked) 0
    }
}