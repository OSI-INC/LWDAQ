<script>
#
# LWDAQ Toolmaker Script to Simulate Reception of Serial Data.
#

# Set up the display.
set wd 1000
set ht 300
lwdaq_image_create -width $wd -height $ht -name plots
catch {image delete p}
image create photo p
destroy $f.i
label $f.i -image p
pack $f.i
frame $f.f
pack $f.f -side top -expand yes
button $f.f.go -text Go -command "start $t"
button $f.f.stop -text Stop -command "set Sim_Run 0"
pack $f.f.go $f.f.stop -side left -expand yes
foreach a {TXI_delay CK_period CK_jitter Num_Bits Trial_Count} {
  set b [string tolower $a]
  label $f.f.l$b -text $a\:
  entry $f.f.$b -textvariable $a -width 10
  pack $f.f.l$b $f.f.$b -side left -expand yes
}
set CK_jitter 1
set CK_period 500
set Trial_Count 0
set Sim_Run 0
set Num_Bits 8

proc start {t} {
  global Sim_Run
  if {$Sim_Run == 1} {return}
  set Sim_Run 1
  go $t
}

proc go {t} {
  # global variables
  global TXI_delay CK_jitter CK_period Trial_Count Sim_Run Num_Bits
  if {![winfo exists $t]} {return}

  # New plots
  lwdaq_graph "" plots -fill 1
  lwdaq_draw plots p
  incr Trial_Count

  # Extent of simulation in arbitrary time units.
  set bit_period 1000
  set max_time [expr $bit_period * ($Num_Bits + 4)]
  
  # Set up time simulation of the clock.
  set CK_signal ""
  set current_time 0
  set CK_offset [expr 10 + round(rand()*$CK_period)]
  set counter $CK_offset
  set current_value 0
  for {set current_time 0} {$current_time < $max_time} {incr current_time} {
    lappend CK_signal $current_value
    if {$counter > 1} {
      set counter [expr $counter - 1]
    } else {
      set counter [expr round($CK_period*0.5 + (rand()-0.5)*$CK_jitter)]
      if {$current_value} {
        set current_value 0
      } else {
        set current_value 1
      }
    }
  }
  
 # Signal to be synchronized.
  for {set i 0} {$i < $Num_Bits} {incr i} {
    set d$i [expr round(rand())]
  }
  set TXI_signal ""
  set current_time 0
  set current_value 1
  for {set current_time 0} {$current_time < $max_time} {incr current_time} {
    lappend TXI_signal $current_value
    set bit_num [expr $current_time / $bit_period]
    if {$bit_num < 1} {set current_value 1}
    if {$bit_num == 1} {set current_value 0}
    if {($bit_num > 1) && ($bit_num < $Num_Bits+2)} {
      set current_value [set d[expr $bit_num-2]]
    }
    if {$bit_num >= $Num_Bits+2} {set current_value 1}
  }
  
 # Generate synchronized signals.
  set TXICP 1
  set TXICP_signal $TXICP
  set TXICN 1
  set TXICN_signal $TXICN
  for {set current_time 1} {$current_time < $max_time} {incr current_time} {
    set TXI [lindex $TXI_signal $current_time]
    set CK [lindex $CK_signal $current_time]
    set CKD [lindex $CK_signal [expr $current_time - 1]]
    if {($CK == 1) && ($CKD == 0)} {
      set TXICP $TXI
    }
    if {($CK == 0) && ($CKD == 1)} {
      set TXICN $TXI
    }
    lappend TXICP_signal $TXICP
    lappend TXICN_signal $TXICN
  }
  
  # Decode the data bits.
  set state 0
  set clearance [expr abs($TXI_delay)]
  set end_state [expr $Num_Bits*2+3]
  for {set current_time $clearance} {$current_time < $max_time - $clearance} {incr current_time} {
    set TXICP [lindex $TXICP_signal [expr $current_time - 1]]
    set TXICN [lindex $TXICN_signal [expr $current_time - 1]]
    set CK [lindex $CK_signal $current_time]
    set CKD [lindex $CK_signal [expr $current_time - 1]]
    if {($CK == 1) && ($CKD == 0)} {
      set index [expr $current_time - $TXI_delay]
      set TXID [lindex $TXI_signal $index]
      for {set i 0} {$i < $Num_Bits} {incr i} {
        if {$state == 2*$i + 2} {
          set s$i $TXID
          lwdaq_graph "$index 0 $index 1" plots \
            -y_min 0 -y_max 1 -x_min 0 -x_max $max_time -color 9
        }
      }
      if {$state == 0} {
        if {!$TXICP} {set state 1} {set state 0}
      } elseif {$state == $end_state} {
        set state $end_state
      } else {
        incr state
      }
    }
  }

  # Plot
  lwdaq_graph $TXI_signal plots -y_only 1 -y_min -7 -y_max 2 -color 1
  lwdaq_graph $CK_signal plots -y_only 1 -y_min -5 -y_max 4 -color 2
  lwdaq_graph $TXICP_signal plots -y_only 1 -y_min -3 -y_max 6 -color 3
  lwdaq_graph $TXICN_signal plots -y_only 1 -y_min -1 -y_max 8 -color 4
  lwdaq_draw plots p
  LWDAQ_update

  # Check decode
  set e 0
  for {set i 0} {$i < $Num_Bits} {incr i} {
    if {[set s$i] != [set d$i]} {set e 1}
  }
  if {$e || ($Sim_Run == 0)} {
    for {set i 0} {$i < $Num_Bits} {incr i} {
      LWDAQ_print -nonewline $t "[set d$i] "
    }
    LWDAQ_print $t
    for {set i 0} {$i < $Num_Bits} {incr i} {
      LWDAQ_print -nonewline $t "[set s$i] " orange
    }
    LWDAQ_print $t
    if {$e} {
      set color red
      set Sim_Run 0
    } {
      set color purple
    }
    foreach a {TXI_delay CK_period CK_jitter CK_offset Trial_Count} {
      LWDAQ_print -nonewline $t "$a\: [set $a] " $color
    }
    LWDAQ_print $t
    set Trial_Count 0
  } else {
    if {$Sim_Run == 1} {LWDAQ_post "go $t"}
  }
}
</script>

<script>
#
# LWDAQ Toolmaker Script to Simulate Reception of Serial Data.
#

# Set up the display.
set wd 1000
set ht 300
lwdaq_image_create -width $wd -height $ht -name plots
catch {image delete p}
image create photo p
destroy $f.i
label $f.i -image p
pack $f.i
frame $f.f
pack $f.f -side top -expand yes
button $f.f.go -text Go -command "start $t"
button $f.f.stop -text Stop -command "set Sim_Run 0"
pack $f.f.go $f.f.stop -side left -expand yes
foreach a {TXI_delay CK_period CK_jitter Num_Bits Trial_Count} {
  set b [string tolower $a]
  label $f.f.l$b -text $a\:
  entry $f.f.$b -textvariable $a -width 10
  pack $f.f.l$b $f.f.$b -side left -expand yes
}
set CK_jitter 1
set CK_period 50
set Trial_Count 0
set Sim_Run 0
set Num_Bits 8

proc start {t} {
  global Sim_Run
  if {$Sim_Run == 1} {return}
  set Sim_Run 1
  go $t
}

proc go {t} {
  # global variables
  global TXI_delay CK_jitter CK_period Trial_Count Sim_Run Num_Bits
  if {![winfo exists $t]} {return}

  # New plots
  lwdaq_graph "" plots -fill 1
  lwdaq_draw plots p
  incr Trial_Count

  # Extent of simulation in arbitrary time units.
  set bit_period 100
  set max_time [expr $bit_period * ($Num_Bits + 4)]
  
  # Set up time simulation of the clock.
  set CK_signal ""
  set current_time 0
  set CK_offset [expr 10 + round(rand()*$CK_period)]
  set counter $CK_offset
  set current_value 0
  for {set current_time 0} {$current_time < $max_time} {incr current_time} {
    lappend CK_signal $current_value
    if {$counter > 1} {
      set counter [expr $counter - 1]
    } else {
      set counter [expr round($CK_period*0.5 + (rand()-0.5)*$CK_jitter)]
      if {$current_value} {
        set current_value 0
      } else {
        set current_value 1
      }
    }
  }
  
 # Signal to be synchronized.
  for {set i 0} {$i < $Num_Bits} {incr i} {
    set d$i [expr round(rand())]
  }
  set TXI_signal ""
  set current_time 0
  set current_value 1
  for {set current_time 0} {$current_time < $max_time} {incr current_time} {
    lappend TXI_signal $current_value
    set bit_num [expr $current_time / $bit_period]
    if {$bit_num < 1} {set current_value 1}
    if {$bit_num == 1} {set current_value 0}
    if {($bit_num > 1) && ($bit_num < $Num_Bits+2)} {
      set current_value [set d[expr $bit_num-2]]
    }
    if {$bit_num >= $Num_Bits+2} {set current_value 1}
  }
  
 # Generate synchronized signals.
  set TXICP 1
  set TXICP_signal $TXICP
  set TXICN 1
  set TXICN_signal $TXICN
  for {set current_time 1} {$current_time < $max_time} {incr current_time} {
    set TXI [lindex $TXI_signal $current_time]
    set CK [lindex $CK_signal $current_time]
    set CKD [lindex $CK_signal [expr $current_time - 1]]
    if {($CK == 1) && ($CKD == 0)} {
      set TXICP $TXI
    }
    if {($CK == 0) && ($CKD == 1)} {
      set TXICN $TXI
    }
    lappend TXICP_signal $TXICP
    lappend TXICN_signal $TXICN
  }
  
  # Decode the data bits.
  set state 0
  set clearance [expr abs($TXI_delay)]
  set end_state [expr $Num_Bits*2+3]
  for {set current_time $clearance} {$current_time < $max_time - $clearance} {incr current_time} {
    set TXICP [lindex $TXICP_signal [expr $current_time - 1]]
    set TXICN [lindex $TXICN_signal [expr $current_time - 1]]
    set CK [lindex $CK_signal $current_time]
    set CKD [lindex $CK_signal [expr $current_time - 1]]
    if {($CK == 1) && ($CKD == 0)} {
      set index [expr $current_time - $TXI_delay]
      set TXID [lindex $TXI_signal $index]
      for {set i 0} {$i < $Num_Bits} {incr i} {
        if {$state == 2*$i + 2} {
          set s$i $TXID
          lwdaq_graph "$index 0 $index 1" plots \
            -y_min 0 -y_max 1 -x_min 0 -x_max $max_time -color 9
        }
      }
      if {$state == 0} {
        if {!$TXICP} {set state 1} {set state 0}
      } elseif {$state == $end_state} {
        set state $end_state
      } else {
        incr state
      }
    }
  }

  # Plot
  lwdaq_graph $TXI_signal plots -y_only 1 -y_min -7 -y_max 2 -color 1
  lwdaq_graph $CK_signal plots -y_only 1 -y_min -5 -y_max 4 -color 2
  lwdaq_graph $TXICP_signal plots -y_only 1 -y_min -3 -y_max 6 -color 3
  lwdaq_graph $TXICN_signal plots -y_only 1 -y_min -1 -y_max 8 -color 4
  lwdaq_draw plots p
  LWDAQ_update

  # Check decode
  set e 0
  for {set i 0} {$i < $Num_Bits} {incr i} {
    if {[set s$i] != [set d$i]} {set e 1}
  }
  if {$e || ($Sim_Run == 0)} {
    for {set i 0} {$i < $Num_Bits} {incr i} {
      LWDAQ_print -nonewline $t "[set d$i] "
    }
    LWDAQ_print $t
    for {set i 0} {$i < $Num_Bits} {incr i} {
      LWDAQ_print -nonewline $t "[set s$i] " orange
    }
    LWDAQ_print $t
    if {$e} {
      set color red
      set Sim_Run 0
    } {
      set color purple
    }
    foreach a {TXI_delay CK_period CK_jitter CK_offset Trial_Count} {
      LWDAQ_print -nonewline $t "$a\: [set $a] " $color
    }
    LWDAQ_print $t
    set Trial_Count 0
  } else {
    if {$Sim_Run == 1} {LWDAQ_post "go $t"}
  }
}
</script>

<script>
#
# LWDAQ Toolmaker Script to Simulate Reception of Serial Data.
#

# Set up the display.
set wd 1000
set ht 300
lwdaq_image_create -width $wd -height $ht -name plots
catch {image delete p}
image create photo p
destroy $f.i
label $f.i -image p
pack $f.i
frame $f.f
pack $f.f -side top -expand yes
button $f.f.go -text Go -command "start $t"
button $f.f.stop -text Stop -command "set Sim_Run 0"
pack $f.f.go $f.f.stop -side left -expand yes
foreach a {TXI_delay CK_period CK_jitter Num_Bits Trial_Count} {
  set b [string tolower $a]
  label $f.f.l$b -text $a\:
  entry $f.f.$b -textvariable $a -width 10
  pack $f.f.l$b $f.f.$b -side left -expand yes
}
set TXI_delay 0
set CK_jitter 1
set CK_period 50
set Trial_Count 0
set Sim_Run 0
set Num_Bits 8

proc start {t} {
  global Sim_Run
  if {$Sim_Run == 1} {return}
  set Sim_Run 1
  go $t
}

proc go {t} {
  # global variables
  global TXI_delay CK_jitter CK_period Trial_Count Sim_Run Num_Bits
  if {![winfo exists $t]} {return}

  # New plots
  lwdaq_graph "" plots -fill 1
  lwdaq_draw plots p
  incr Trial_Count

  # Extent of simulation in arbitrary time units.
  set bit_period 100
  set max_time [expr $bit_period * ($Num_Bits + 4)]
  
  # Set up time simulation of the clock.
  set CK_signal ""
  set current_time 0
  set CK_offset [expr 10 + round(rand()*$CK_period)]
  set counter $CK_offset
  set current_value 0
  for {set current_time 0} {$current_time < $max_time} {incr current_time} {
    lappend CK_signal $current_value
    if {$counter > 1} {
      set counter [expr $counter - 1]
    } else {
      set counter [expr round($CK_period*0.5 + (rand()-0.5)*$CK_jitter)]
      if {$current_value} {
        set current_value 0
      } else {
        set current_value 1
      }
    }
  }
  
 # Signal to be synchronized.
  for {set i 0} {$i < $Num_Bits} {incr i} {
    set d$i [expr round(rand())]
  }
  set TXI_signal ""
  set current_time 0
  set current_value 1
  for {set current_time 0} {$current_time < $max_time} {incr current_time} {
    lappend TXI_signal $current_value
    set bit_num [expr $current_time / $bit_period]
    if {$bit_num < 1} {set current_value 1}
    if {$bit_num == 1} {set current_value 0}
    if {($bit_num > 1) && ($bit_num < $Num_Bits+2)} {
      set current_value [set d[expr $bit_num-2]]
    }
    if {$bit_num >= $Num_Bits+2} {set current_value 1}
  }
  
 # Generate synchronized signals.
  set TXICP 1
  set TXICP_signal $TXICP
  set TXICN 1
  set TXICN_signal $TXICN
  for {set current_time 1} {$current_time < $max_time} {incr current_time} {
    set TXI [lindex $TXI_signal $current_time]
    set CK [lindex $CK_signal $current_time]
    set CKD [lindex $CK_signal [expr $current_time - 1]]
    if {($CK == 1) && ($CKD == 0)} {
      set TXICP $TXI
    }
    if {($CK == 0) && ($CKD == 1)} {
      set TXICN $TXI
    }
    lappend TXICP_signal $TXICP
    lappend TXICN_signal $TXICN
  }
  
  # Decode the data bits.
  set state 0
  set clearance [expr abs($TXI_delay)]
  set end_state [expr $Num_Bits*2+3]
  for {set current_time $clearance} {$current_time < $max_time - $clearance} {incr current_time} {
    set TXICP [lindex $TXICP_signal [expr $current_time - 1]]
    set TXICN [lindex $TXICN_signal [expr $current_time - 1]]
    set CK [lindex $CK_signal $current_time]
    set CKD [lindex $CK_signal [expr $current_time - 1]]
    if {($CK == 1) && ($CKD == 0)} {
      set index [expr $current_time - $TXI_delay]
      set TXID [lindex $TXI_signal $index]
      for {set i 0} {$i < $Num_Bits} {incr i} {
        if {$state == 2*$i + 2} {
          set s$i $TXID
          lwdaq_graph "$index 0 $index 1" plots \
            -y_min 0 -y_max 1 -x_min 0 -x_max $max_time -color 9
        }
      }
      if {$state == 0} {
        if {!$TXICP} {set state 1} {set state 0}
      } elseif {$state == $end_state} {
        set state $end_state
      } else {
        incr state
      }
    }
  }

  # Plot
  lwdaq_graph $TXI_signal plots -y_only 1 -y_min -7 -y_max 2 -color 1
  lwdaq_graph $CK_signal plots -y_only 1 -y_min -5 -y_max 4 -color 2
  lwdaq_graph $TXICP_signal plots -y_only 1 -y_min -3 -y_max 6 -color 3
  lwdaq_graph $TXICN_signal plots -y_only 1 -y_min -1 -y_max 8 -color 4
  lwdaq_draw plots p
  LWDAQ_update

  # Check decode
  set e 0
  for {set i 0} {$i < $Num_Bits} {incr i} {
    if {[set s$i] != [set d$i]} {set e 1}
  }
  if {$e || ($Sim_Run == 0)} {
    for {set i 0} {$i < $Num_Bits} {incr i} {
      LWDAQ_print -nonewline $t "[set d$i] "
    }
    LWDAQ_print $t
    for {set i 0} {$i < $Num_Bits} {incr i} {
      LWDAQ_print -nonewline $t "[set s$i] " orange
    }
    LWDAQ_print $t
    if {$e} {
      set color red
      set Sim_Run 0
    } {
      set color purple
    }
    foreach a {TXI_delay CK_period CK_jitter CK_offset Trial_Count} {
      LWDAQ_print -nonewline $t "$a\: [set $a] " $color
    }
    LWDAQ_print $t
    set Trial_Count 0
  } else {
    if {$Sim_Run == 1} {LWDAQ_post "go $t"}
  }
}
</script>

<script>
#
# LWDAQ Toolmaker Script to Simulate Reception of Serial Data.
#

# Set up the display.
set wd 1000
set ht 300
lwdaq_image_create -width $wd -height $ht -name plots
catch {image delete p}
image create photo p
destroy $f.i
label $f.i -image p
pack $f.i
frame $f.f
pack $f.f -side top -expand yes
button $f.f.go -text Go -command "start $t"
button $f.f.stop -text Stop -command "set Sim_Run 0"
pack $f.f.go $f.f.stop -side left -expand yes
foreach a {TXI_delay CK_period CK_jitter Num_Bits Trial_Count} {
  set b [string tolower $a]
  label $f.f.l$b -text $a\:
  entry $f.f.$b -textvariable $a -width 10
  pack $f.f.l$b $f.f.$b -side left -expand yes
}
set TXI_delay 0
set CK_jitter 1
set CK_period 50
set Trial_Count 0
set Sim_Run 0
set Num_Bits 8

proc start {t} {
  global Sim_Run
  if {$Sim_Run == 1} {return}
  set Sim_Run 1
  go $t
}

proc go {t} {
  # global variables
  global TXI_delay CK_jitter CK_period Trial_Count Sim_Run Num_Bits
  if {![winfo exists $t]} {return}

  # New plots
  lwdaq_graph "" plots -fill 1
  lwdaq_draw plots p
  incr Trial_Count

  # Extent of simulation in arbitrary time units.
  set bit_period 100
  set max_time [expr $bit_period * ($Num_Bits + 4)]
  
  # Set up time simulation of the clock.
  set CK_signal ""
  set current_time 0
  set CK_offset [expr 10 + round(rand()*$CK_period)]
  set counter $CK_offset
  set current_value 0
  for {set current_time 0} {$current_time < $max_time} {incr current_time} {
    lappend CK_signal $current_value
    if {$counter > 1} {
      set counter [expr $counter - 1]
    } else {
      set counter [expr round($CK_period*0.5 + (rand()-0.5)*$CK_jitter)]
      if {$current_value} {
        set current_value 0
      } else {
        set current_value 1
      }
    }
  }
  
 # Signal to be synchronized.
  for {set i 0} {$i < $Num_Bits} {incr i} {
    set d$i [expr round(rand())]
  }
  set TXI_signal ""
  set current_time 0
  set current_value 1
  for {set current_time 0} {$current_time < $max_time} {incr current_time} {
    lappend TXI_signal $current_value
    set bit_num [expr $current_time / $bit_period]
    if {$bit_num < 1} {set current_value 1}
    if {$bit_num == 1} {set current_value 0}
    if {($bit_num > 1) && ($bit_num < $Num_Bits+2)} {
      set current_value [set d[expr $bit_num-2]]
    }
    if {$bit_num >= $Num_Bits+2} {set current_value 1}
  }
  
 # Generate synchronized signals.
  set TXICP 1
  set TXICP_signal $TXICP
  set TXICN 1
  set TXICN_signal $TXICN
  for {set current_time 1} {$current_time < $max_time} {incr current_time} {
    set TXI [lindex $TXI_signal $current_time]
    set CK [lindex $CK_signal $current_time]
    set CKD [lindex $CK_signal [expr $current_time - 1]]
    if {($CK == 1) && ($CKD == 0)} {
      set TXICP $TXI
    }
    if {($CK == 0) && ($CKD == 1)} {
      set TXICN $TXI
    }
    lappend TXICP_signal $TXICP
    lappend TXICN_signal $TXICN
  }
  
  # Decode the data bits.
  set state 0
  set clearance [expr abs($TXI_delay)]
  set end_state [expr $Num_Bits*2+3]
  for {set current_time $clearance} {$current_time < $max_time - $clearance} {incr current_time} {
    set TXICP [lindex $TXICP_signal [expr $current_time - 1]]
    set TXICN [lindex $TXICN_signal [expr $current_time - 1]]
    set CK [lindex $CK_signal $current_time]
    set CKD [lindex $CK_signal [expr $current_time - 1]]
    if {($CK == 1) && ($CKD == 0)} {
      set index [expr $current_time - $TXI_delay]
      set TXID [lindex $TXI_signal $index]
      for {set i 0} {$i < $Num_Bits} {incr i} {
        if {$state == 2*$i + 2} {
          set s$i $TXID
          lwdaq_graph "$index 0 $index 1" plots \
            -y_min 0 -y_max 1 -x_min 0 -x_max $max_time -color 9
        }
      }
      if {$state == 0} {
        if {!$TXICP} {set state 1} {set state 0}
      } elseif {$state == $end_state} {
        set state $end_state
      } else {
        incr state
      }
    }
  }

  # Plot
  lwdaq_graph $TXI_signal plots -y_only 1 -y_min -7 -y_max 2 -color 1
  lwdaq_graph $CK_signal plots -y_only 1 -y_min -5 -y_max 4 -color 2
  lwdaq_graph $TXICP_signal plots -y_only 1 -y_min -3 -y_max 6 -color 3
  lwdaq_graph $TXICN_signal plots -y_only 1 -y_min -1 -y_max 8 -color 4
  lwdaq_draw plots p
  LWDAQ_update

  # Check decode
  set e 0
  for {set i 0} {$i < $Num_Bits} {incr i} {
    if {[set s$i] != [set d$i]} {set e 1}
  }
  if {$e || ($Sim_Run == 0)} {
    for {set i 0} {$i < $Num_Bits} {incr i} {
      LWDAQ_print -nonewline $t "[set d$i] "
    }
    LWDAQ_print $t
    for {set i 0} {$i < $Num_Bits} {incr i} {
      LWDAQ_print -nonewline $t "[set s$i] " orange
    }
    LWDAQ_print $t
    if {$e} {
      set color red
      set Sim_Run 0
    } {
      set color purple
    }
    foreach a {TXI_delay CK_period CK_jitter CK_offset Trial_Count} {
      LWDAQ_print -nonewline $t "$a\: [set $a] " $color
    }
    LWDAQ_print $t
    set Trial_Count 0
  } else {
    if {$Sim_Run == 1} {LWDAQ_post "go $t"}
  }
}
</script>

<script>
#
# LWDAQ Toolmaker Script to Simulate Reception of Serial Data.
#

# Set up the display.
set wd 1000
set ht 300
lwdaq_image_create -width $wd -height $ht -name plots
catch {image delete p}
image create photo p
destroy $f.i
label $f.i -image p
pack $f.i
frame $f.f
pack $f.f -side top -expand yes
button $f.f.go -text Go -command "start $t"
button $f.f.stop -text Stop -command "set Sim_Run 0"
pack $f.f.go $f.f.stop -side left -expand yes
foreach a {SDI_delay CK_period CK_jitter Num_Bits Trial_Count} {
  set b [string tolower $a]
  label $f.f.l$b -text $a\:
  entry $f.f.$b -textvariable $a -width 10
  pack $f.f.l$b $f.f.$b -side left -expand yes
}
set SDI_delay 0
set CK_jitter 1
set CK_period 50
set Trial_Count 0
set Sim_Run 0
set Num_Bits 8

proc start {t} {
  global Sim_Run
  if {$Sim_Run == 1} {return}
  set Sim_Run 1
  go $t
}

proc go {t} {
  # global variables
  global SDI_delay CK_jitter CK_period Trial_Count Sim_Run Num_Bits
  if {![winfo exists $t]} {return}

  # New plots
  lwdaq_graph "" plots -fill 1
  lwdaq_draw plots p
  incr Trial_Count

  # Extent of simulation in arbitrary time units.
  set bit_period 100
  set max_time [expr $bit_period * ($Num_Bits + 4)]
  
  # Set up time simulation of the clock.
  set CK_signal ""
  set current_time 0
  set CK_offset [expr 10 + round(rand()*$CK_period)]
  set counter $CK_offset
  set current_value 0
  for {set current_time 0} {$current_time < $max_time} {incr current_time} {
    lappend CK_signal $current_value
    if {$counter > 1} {
      set counter [expr $counter - 1]
    } else {
      set counter [expr round($CK_period*0.5 + (rand()-0.5)*$CK_jitter)]
      if {$current_value} {
        set current_value 0
      } else {
        set current_value 1
      }
    }
  }
  
 # Signal to be synchronized.
  for {set i 0} {$i < $Num_Bits} {incr i} {
    set d$i [expr round(rand())]
  }
  set SDI_signal ""
  set current_time 0
  set current_value 1
  for {set current_time 0} {$current_time < $max_time} {incr current_time} {
    lappend SDI_signal $current_value
    set bit_num [expr $current_time / $bit_period]
    if {$bit_num < 1} {set current_value 1}
    if {$bit_num == 1} {set current_value 0}
    if {($bit_num > 1) && ($bit_num < $Num_Bits+2)} {
      set current_value [set d[expr $bit_num-2]]
    }
    if {$bit_num >= $Num_Bits+2} {set current_value 1}
  }
  
 # Generate synchronized signals.
  set SDICP 1
  set SDICP_signal $SDICP
  set SDICN 1
  set SDICN_signal $SDICN
  for {set current_time 1} {$current_time < $max_time} {incr current_time} {
    set SDI [lindex $SDI_signal $current_time]
    set CK [lindex $CK_signal $current_time]
    set CKD [lindex $CK_signal [expr $current_time - 1]]
    if {($CK == 1) && ($CKD == 0)} {
      set SDICP $SDI
    }
    if {($CK == 0) && ($CKD == 1)} {
      set SDICN $SDI
    }
    lappend SDICP_signal $SDICP
    lappend SDICN_signal $SDICN
  }
  
  # Decode the data bits.
  set state 0
  set clearance [expr abs($SDI_delay)]
  set end_state [expr $Num_Bits*2+3]
  for {set current_time $clearance} {$current_time < $max_time - $clearance} {incr current_time} {
    set SDICP [lindex $SDICP_signal [expr $current_time - 1]]
    set SDICN [lindex $SDICN_signal [expr $current_time - 1]]
    set CK [lindex $CK_signal $current_time]
    set CKD [lindex $CK_signal [expr $current_time - 1]]
    if {($CK == 1) && ($CKD == 0)} {
      set index [expr $current_time - $SDI_delay]
      set SDID [lindex $SDI_signal $index]
      for {set i 0} {$i < $Num_Bits} {incr i} {
        if {$state == 2*$i + 2} {
          set s$i $SDID
          lwdaq_graph "$index 0 $index 1" plots \
            -y_min 0 -y_max 1 -x_min 0 -x_max $max_time -color 9
        }
      }
      if {$state == 0} {
        if {!$SDICP} {set state 1} {set state 0}
      } elseif {$state == $end_state} {
        set state $end_state
      } else {
        incr state
      }
    }
  }

  # Plot
  lwdaq_graph $SDI_signal plots -y_only 1 -y_min -7 -y_max 2 -color 1
  lwdaq_graph $CK_signal plots -y_only 1 -y_min -5 -y_max 4 -color 2
  lwdaq_graph $SDICP_signal plots -y_only 1 -y_min -3 -y_max 6 -color 3
  lwdaq_graph $SDICN_signal plots -y_only 1 -y_min -1 -y_max 8 -color 4
  lwdaq_draw plots p
  LWDAQ_update

  # Check decode
  set e 0
  for {set i 0} {$i < $Num_Bits} {incr i} {
    if {[set s$i] != [set d$i]} {set e 1}
  }
  if {$e || ($Sim_Run == 0)} {
    for {set i 0} {$i < $Num_Bits} {incr i} {
      LWDAQ_print -nonewline $t "[set d$i] "
    }
    LWDAQ_print $t
    for {set i 0} {$i < $Num_Bits} {incr i} {
      LWDAQ_print -nonewline $t "[set s$i] " orange
    }
    LWDAQ_print $t
    if {$e} {
      set color red
      set Sim_Run 0
    } {
      set color purple
    }
    foreach a {SDI_delay CK_period CK_jitter CK_offset Trial_Count} {
      LWDAQ_print -nonewline $t "$a\: [set $a] " $color
    }
    LWDAQ_print $t
    set Trial_Count 0
  } else {
    if {$Sim_Run == 1} {LWDAQ_post "go $t"}
  }
}
</script>

<script>
#
# LWDAQ Toolmaker Script to Simulate Reception of Serial Data.
#

# Set up the display.
set wd 1000
set ht 300
lwdaq_image_create -width $wd -height $ht -name plots
catch {image delete p}
image create photo p
destroy $f.i
label $f.i -image p
pack $f.i
frame $f.f
pack $f.f -side top -expand yes
button $f.f.go -text Go -command "start $t"
button $f.f.stop -text Stop -command "set Sim_Run 0"
pack $f.f.go $f.f.stop -side left -expand yes
foreach a {SDI_delay CK_period CK_jitter Num_Bits Trial_Count} {
  set b [string tolower $a]
  label $f.f.l$b -text $a\:
  entry $f.f.$b -textvariable $a -width 10
  pack $f.f.l$b $f.f.$b -side left -expand yes
}
set CK_period 500
set SDI_delay [expr round($CK_period*0.5)]]
set CK_jitter 1
set Trial_Count 0
set Sim_Run 0
set Num_Bits 8

proc start {t} {
  global Sim_Run
  if {$Sim_Run == 1} {return}
  set Sim_Run 1
  go $t
}

proc go {t} {
  # global variables
  global SDI_delay CK_jitter CK_period Trial_Count Sim_Run Num_Bits
  if {![winfo exists $t]} {return}

  # New plots
  lwdaq_graph "" plots -fill 1
  lwdaq_draw plots p
  incr Trial_Count

  # Extent of simulation in arbitrary time units.
  set bit_period 1000
  set max_time [expr $bit_period * ($Num_Bits + 4)]
  
  # Set up time simulation of the clock.
  set CK_signal ""
  set current_time 0
  set CK_offset [expr 10 + round(rand()*$CK_period)]
  set counter $CK_offset
  set current_value 0
  for {set current_time 0} {$current_time < $max_time} {incr current_time} {
    lappend CK_signal $current_value
    if {$counter > 1} {
      set counter [expr $counter - 1]
    } else {
      set counter [expr round($CK_period*0.5 + (rand()-0.5)*$CK_jitter)]
      if {$current_value} {
        set current_value 0
      } else {
        set current_value 1
      }
    }
  }
  
 # Signal to be synchronized.
  for {set i 0} {$i < $Num_Bits} {incr i} {
    set d$i [expr round(rand())]
  }
  set SDI_signal ""
  set current_time 0
  set current_value 1
  for {set current_time 0} {$current_time < $max_time} {incr current_time} {
    lappend SDI_signal $current_value
    set bit_num [expr $current_time / $bit_period]
    if {$bit_num < 1} {set current_value 1}
    if {$bit_num == 1} {set current_value 0}
    if {($bit_num > 1) && ($bit_num < $Num_Bits+2)} {
      set current_value [set d[expr $bit_num-2]]
    }
    if {$bit_num >= $Num_Bits+2} {set current_value 1}
  }
  
 # Generate synchronized signals.
  set SDICP 1
  set SDICP_signal $SDICP
  set SDICN 1
  set SDICN_signal $SDICN
  for {set current_time 1} {$current_time < $max_time} {incr current_time} {
    set SDI [lindex $SDI_signal $current_time]
    set CK [lindex $CK_signal $current_time]
    set CKD [lindex $CK_signal [expr $current_time - 1]]
    if {($CK == 1) && ($CKD == 0)} {
      set SDICP $SDI
    }
    if {($CK == 0) && ($CKD == 1)} {
      set SDICN $SDI
    }
    lappend SDICP_signal $SDICP
    lappend SDICN_signal $SDICN
  }
  
  # Decode the data bits.
  set state 0
  set clearance [expr abs($SDI_delay)]
  set end_state [expr $Num_Bits*2+3]
  for {set current_time $clearance} {$current_time < $max_time - $clearance} {incr current_time} {
    set SDICP [lindex $SDICP_signal [expr $current_time - 1]]
    set SDICN [lindex $SDICN_signal [expr $current_time - 1]]
    set CK [lindex $CK_signal $current_time]
    set CKD [lindex $CK_signal [expr $current_time - 1]]
    if {($CK == 1) && ($CKD == 0)} {
      set index [expr $current_time - $SDI_delay]
      set SDID [lindex $SDI_signal $index]
      for {set i 0} {$i < $Num_Bits} {incr i} {
        if {$state == 2*$i + 2} {
          set s$i $SDID
          lwdaq_graph "$index 0 $index 1" plots \
            -y_min 0 -y_max 1 -x_min 0 -x_max $max_time -color 9
        }
      }
      if {$state == 0} {
        if {!$SDICP} {set state 1} {set state 0}
      } elseif {$state == $end_state} {
        set state $end_state
      } else {
        incr state
      }
    }
  }

  # Plot
  lwdaq_graph $SDI_signal plots -y_only 1 -y_min -7 -y_max 2 -color 1
  lwdaq_graph $CK_signal plots -y_only 1 -y_min -5 -y_max 4 -color 2
  lwdaq_graph $SDICP_signal plots -y_only 1 -y_min -3 -y_max 6 -color 3
  lwdaq_graph $SDICN_signal plots -y_only 1 -y_min -1 -y_max 8 -color 4
  lwdaq_draw plots p
  LWDAQ_update

  # Check decode
  set e 0
  for {set i 0} {$i < $Num_Bits} {incr i} {
    if {[set s$i] != [set d$i]} {set e 1}
  }
  if {$e || ($Sim_Run == 0)} {
    for {set i 0} {$i < $Num_Bits} {incr i} {
      LWDAQ_print -nonewline $t "[set d$i] "
    }
    LWDAQ_print $t
    for {set i 0} {$i < $Num_Bits} {incr i} {
      LWDAQ_print -nonewline $t "[set s$i] " orange
    }
    LWDAQ_print $t
    if {$e} {
      set color red
      set Sim_Run 0
    } {
      set color purple
    }
    foreach a {SDI_delay CK_period CK_jitter CK_offset Trial_Count} {
      LWDAQ_print -nonewline $t "$a\: [set $a] " $color
    }
    LWDAQ_print $t
    set Trial_Count 0
  } else {
    if {$Sim_Run == 1} {LWDAQ_post "go $t"}
  }
}
</script>

<script>
#
# LWDAQ Toolmaker Script to Simulate Reception of Serial Data.
#

# Set up the display.
set wd 1000
set ht 300
lwdaq_image_create -width $wd -height $ht -name plots
catch {image delete p}
image create photo p
destroy $f.i
label $f.i -image p
pack $f.i
frame $f.f
pack $f.f -side top -expand yes
button $f.f.go -text Go -command "start $t"
button $f.f.stop -text Stop -command "set Sim_Run 0"
pack $f.f.go $f.f.stop -side left -expand yes
foreach a {SDI_delay CK_period CK_jitter Num_Bits Trial_Count} {
  set b [string tolower $a]
  label $f.f.l$b -text $a\:
  entry $f.f.$b -textvariable $a -width 10
  pack $f.f.l$b $f.f.$b -side left -expand yes
}
set CK_period 500
set SDI_delay [expr round($CK_period*0.5)]
set CK_jitter 1
set Trial_Count 0
set Sim_Run 0
set Num_Bits 8

proc start {t} {
  global Sim_Run
  if {$Sim_Run == 1} {return}
  set Sim_Run 1
  go $t
}

proc go {t} {
  # global variables
  global SDI_delay CK_jitter CK_period Trial_Count Sim_Run Num_Bits
  if {![winfo exists $t]} {return}

  # New plots
  lwdaq_graph "" plots -fill 1
  lwdaq_draw plots p
  incr Trial_Count

  # Extent of simulation in arbitrary time units.
  set bit_period 1000
  set max_time [expr $bit_period * ($Num_Bits + 4)]
  
  # Set up time simulation of the clock.
  set CK_signal ""
  set current_time 0
  set CK_offset [expr 10 + round(rand()*$CK_period)]
  set counter $CK_offset
  set current_value 0
  for {set current_time 0} {$current_time < $max_time} {incr current_time} {
    lappend CK_signal $current_value
    if {$counter > 1} {
      set counter [expr $counter - 1]
    } else {
      set counter [expr round($CK_period*0.5 + (rand()-0.5)*$CK_jitter)]
      if {$current_value} {
        set current_value 0
      } else {
        set current_value 1
      }
    }
  }
  
 # Signal to be synchronized.
  for {set i 0} {$i < $Num_Bits} {incr i} {
    set d$i [expr round(rand())]
  }
  set SDI_signal ""
  set current_time 0
  set current_value 1
  for {set current_time 0} {$current_time < $max_time} {incr current_time} {
    lappend SDI_signal $current_value
    set bit_num [expr $current_time / $bit_period]
    if {$bit_num < 1} {set current_value 1}
    if {$bit_num == 1} {set current_value 0}
    if {($bit_num > 1) && ($bit_num < $Num_Bits+2)} {
      set current_value [set d[expr $bit_num-2]]
    }
    if {$bit_num >= $Num_Bits+2} {set current_value 1}
  }
  
 # Generate synchronized signals.
  set SDICP 1
  set SDICP_signal $SDICP
  set SDICN 1
  set SDICN_signal $SDICN
  for {set current_time 1} {$current_time < $max_time} {incr current_time} {
    set SDI [lindex $SDI_signal $current_time]
    set CK [lindex $CK_signal $current_time]
    set CKD [lindex $CK_signal [expr $current_time - 1]]
    if {($CK == 1) && ($CKD == 0)} {
      set SDICP $SDI
    }
    if {($CK == 0) && ($CKD == 1)} {
      set SDICN $SDI
    }
    lappend SDICP_signal $SDICP
    lappend SDICN_signal $SDICN
  }
  
  # Decode the data bits.
  set state 0
  set clearance [expr abs($SDI_delay)]
  set end_state [expr $Num_Bits*2+3]
  for {set current_time $clearance} {$current_time < $max_time - $clearance} {incr current_time} {
    set SDICP [lindex $SDICP_signal [expr $current_time - 1]]
    set SDICN [lindex $SDICN_signal [expr $current_time - 1]]
    set CK [lindex $CK_signal $current_time]
    set CKD [lindex $CK_signal [expr $current_time - 1]]
    if {($CK == 1) && ($CKD == 0)} {
      set index [expr $current_time - $SDI_delay]
      set SDID [lindex $SDI_signal $index]
      for {set i 0} {$i < $Num_Bits} {incr i} {
        if {$state == 2*$i + 2} {
          set s$i $SDID
          lwdaq_graph "$index 0 $index 1" plots \
            -y_min 0 -y_max 1 -x_min 0 -x_max $max_time -color 9
        }
      }
      if {$state == 0} {
        if {!$SDICP} {set state 1} {set state 0}
      } elseif {$state == $end_state} {
        set state $end_state
      } else {
        incr state
      }
    }
  }

  # Plot
  lwdaq_graph $SDI_signal plots -y_only 1 -y_min -7 -y_max 2 -color 1
  lwdaq_graph $CK_signal plots -y_only 1 -y_min -5 -y_max 4 -color 2
  lwdaq_graph $SDICP_signal plots -y_only 1 -y_min -3 -y_max 6 -color 3
  lwdaq_graph $SDICN_signal plots -y_only 1 -y_min -1 -y_max 8 -color 4
  lwdaq_draw plots p
  LWDAQ_update

  # Check decode
  set e 0
  for {set i 0} {$i < $Num_Bits} {incr i} {
    if {[set s$i] != [set d$i]} {set e 1}
  }
  if {$e || ($Sim_Run == 0)} {
    for {set i 0} {$i < $Num_Bits} {incr i} {
      LWDAQ_print -nonewline $t "[set d$i] "
    }
    LWDAQ_print $t
    for {set i 0} {$i < $Num_Bits} {incr i} {
      LWDAQ_print -nonewline $t "[set s$i] " orange
    }
    LWDAQ_print $t
    if {$e} {
      set color red
      set Sim_Run 0
    } {
      set color purple
    }
    foreach a {SDI_delay CK_period CK_jitter CK_offset Trial_Count} {
      LWDAQ_print -nonewline $t "$a\: [set $a] " $color
    }
    LWDAQ_print $t
    set Trial_Count 0
  } else {
    if {$Sim_Run == 1} {LWDAQ_post "go $t"}
  }
}
</script>

<script>
#
# LWDAQ Toolmaker Script to Simulate Reception of Serial Data.
#

# Set up the display.
set wd 1000
set ht 300
lwdaq_image_create -width $wd -height $ht -name plots
catch {image delete p}
image create photo p
destroy $f.i
label $f.i -image p
pack $f.i
frame $f.f
pack $f.f -side top -expand yes
button $f.f.go -text Go -command "start $t"
button $f.f.stop -text Stop -command "set Sim_Run 0"
pack $f.f.go $f.f.stop -side left -expand yes
foreach a {CK_period CK_jitter Num_Bits Trial_Count} {
  set b [string tolower $a]
  label $f.f.l$b -text $a\:
  entry $f.f.$b -textvariable $a -width 10
  pack $f.f.l$b $f.f.$b -side left -expand yes
}
set CK_period 500
set SDI_delay [expr round($CK_period*0.5)]
set CK_jitter 1
set Trial_Count 0
set Sim_Run 0
set Num_Bits 8

proc start {t} {
  global Sim_Run
  if {$Sim_Run == 1} {return}
  set Sim_Run 1
  go $t
}

proc go {t} {
  # global variables
  global SDI_delay CK_jitter CK_period Trial_Count Sim_Run Num_Bits
  if {![winfo exists $t]} {return}

  # New plots
  lwdaq_graph "" plots -fill 1
  lwdaq_draw plots p
  incr Trial_Count

  # Extent of simulation in arbitrary time units.
  set bit_period 1000
  set max_time [expr $bit_period * ($Num_Bits + 4)]
  
  # Set up time simulation of the clock.
  set CK_signal ""
  set current_time 0
  set CK_offset [expr 10 + round(rand()*$CK_period)]
  set counter $CK_offset
  set current_value 0
  for {set current_time 0} {$current_time < $max_time} {incr current_time} {
    lappend CK_signal $current_value
    if {$counter > 1} {
      set counter [expr $counter - 1]
    } else {
      set counter [expr round($CK_period*0.5 + (rand()-0.5)*$CK_jitter)]
      if {$current_value} {
        set current_value 0
      } else {
        set current_value 1
      }
    }
  }
  
 # Signal to be synchronized.
  for {set i 0} {$i < $Num_Bits} {incr i} {
    set d$i [expr round(rand())]
  }
  set SDI_signal ""
  set current_time 0
  set current_value 1
  for {set current_time 0} {$current_time < $max_time} {incr current_time} {
    lappend SDI_signal $current_value
    set bit_num [expr $current_time / $bit_period]
    if {$bit_num < 1} {set current_value 1}
    if {$bit_num == 1} {set current_value 0}
    if {($bit_num > 1) && ($bit_num < $Num_Bits+2)} {
      set current_value [set d[expr $bit_num-2]]
    }
    if {$bit_num >= $Num_Bits+2} {set current_value 1}
  }
  
 # Generate synchronized signals.
  set SDICP 1
  set SDICP_signal $SDICP
  set SDICN 1
  set SDICN_signal $SDICN
  for {set current_time 1} {$current_time < $max_time} {incr current_time} {
    set SDI [lindex $SDI_signal $current_time]
    set CK [lindex $CK_signal $current_time]
    set CKD [lindex $CK_signal [expr $current_time - 1]]
    if {($CK == 1) && ($CKD == 0)} {
      set SDICP $SDI
    }
    if {($CK == 0) && ($CKD == 1)} {
      set SDICN $SDI
    }
    lappend SDICP_signal $SDICP
    lappend SDICN_signal $SDICN
  }
  
  # Decode the data bits.
  set state 0
  set clearance [expr abs($SDI_delay)]
  set end_state [expr $Num_Bits*2+3]
  for {set current_time $clearance} {$current_time < $max_time - $clearance} {incr current_time} {
    set SDICP [lindex $SDICP_signal [expr $current_time - 1]]
    set SDICN [lindex $SDICN_signal [expr $current_time - 1]]
    set CK [lindex $CK_signal $current_time]
    set CKD [lindex $CK_signal [expr $current_time - 1]]
    if {($CK == 1) && ($CKD == 0)} {
      set index [expr $current_time - $SDI_delay]
      set SDID [lindex $SDI_signal $index]
      for {set i 0} {$i < $Num_Bits} {incr i} {
        if {$state == 2*$i + 2} {
          set s$i $SDID
          lwdaq_graph "$index 0 $index 1" plots \
            -y_min 0 -y_max 1 -x_min 0 -x_max $max_time -color 9
        }
      }
      if {$state == 0} {
        if {!$SDICP} {set state 1} {set state 0}
      } elseif {$state == $end_state} {
        set state $end_state
      } else {
        incr state
      }
    }
  }

  # Plot
  lwdaq_graph $SDI_signal plots -y_only 1 -y_min -7 -y_max 2 -color 1
  lwdaq_graph $CK_signal plots -y_only 1 -y_min -5 -y_max 4 -color 2
  lwdaq_graph $SDICP_signal plots -y_only 1 -y_min -3 -y_max 6 -color 3
  lwdaq_graph $SDICN_signal plots -y_only 1 -y_min -1 -y_max 8 -color 4
  lwdaq_draw plots p
  LWDAQ_update

  # Check decode
  set e 0
  for {set i 0} {$i < $Num_Bits} {incr i} {
    if {[set s$i] != [set d$i]} {set e 1}
  }
  if {$e || ($Sim_Run == 0)} {
    for {set i 0} {$i < $Num_Bits} {incr i} {
      LWDAQ_print -nonewline $t "[set d$i] "
    }
    LWDAQ_print $t
    for {set i 0} {$i < $Num_Bits} {incr i} {
      LWDAQ_print -nonewline $t "[set s$i] " orange
    }
    LWDAQ_print $t
    if {$e} {
      set color red
      set Sim_Run 0
    } {
      set color purple
    }
    foreach a {CK_period CK_jitter CK_offset Trial_Count} {
      LWDAQ_print -nonewline $t "$a\: [set $a] " $color
    }
    LWDAQ_print $t
    set Trial_Count 0
  } else {
    if {$Sim_Run == 1} {LWDAQ_post "go $t"}
  }
}
</script>

<script>
#
# LWDAQ Toolmaker Script to Simulate Reception of Serial Data.
#

# Set up the display.
set wd 1000
set ht 300
lwdaq_image_create -width $wd -height $ht -name plots
catch {image delete p}
image create photo p
destroy $f.i
label $f.i -image p
pack $f.i
frame $f.f
pack $f.f -side top -expand yes
button $f.f.go -text Go -command "start $t"
button $f.f.stop -text Stop -command "set Sim_Run 0"
pack $f.f.go $f.f.stop -side left -expand yes
foreach a {CK_period CK_jitter Num_Bits Trial_Count} {
  set b [string tolower $a]
  label $f.f.l$b -text $a\:
  entry $f.f.$b -textvariable $a -width 10
  pack $f.f.l$b $f.f.$b -side left -expand yes
}
set CK_period 500
set CK_jitter 1
set Trial_Count 0
set Sim_Run 0
set Num_Bits 8

proc start {t} {
  global Sim_Run
  if {$Sim_Run == 1} {return}
  set Sim_Run 1
  go $t
}

proc go {t} {
  # global variables
  global CK_jitter CK_period Trial_Count Sim_Run Num_Bits
  if {![winfo exists $t]} {return}

  # New plots
  lwdaq_graph "" plots -fill 1
  lwdaq_draw plots p
  incr Trial_Count

  # Extent of simulation in arbitrary time units.
  set bit_period 1000
  set max_time [expr $bit_period * ($Num_Bits + 4)]
  
  # Set up time simulation of the clock.
  set CK_signal ""
  set current_time 0
  set CK_offset [expr 10 + round(rand()*$CK_period)]
  set counter $CK_offset
  set current_value 0
  for {set current_time 0} {$current_time < $max_time} {incr current_time} {
    lappend CK_signal $current_value
    if {$counter > 1} {
      set counter [expr $counter - 1]
    } else {
      set counter [expr round($CK_period*0.5 + (rand()-0.5)*$CK_jitter)]
      if {$current_value} {
        set current_value 0
      } else {
        set current_value 1
      }
    }
  }
  
 # Signal to be synchronized.
  for {set i 0} {$i < $Num_Bits} {incr i} {
    set d$i [expr round(rand())]
  }
  set SDI_signal ""
  set current_time 0
  set current_value 1
  for {set current_time 0} {$current_time < $max_time} {incr current_time} {
    lappend SDI_signal $current_value
    set bit_num [expr $current_time / $bit_period]
    if {$bit_num < 1} {set current_value 1}
    if {$bit_num == 1} {set current_value 0}
    if {($bit_num > 1) && ($bit_num < $Num_Bits+2)} {
      set current_value [set d[expr $bit_num-2]]
    }
    if {$bit_num >= $Num_Bits+2} {set current_value 1}
  }
  
 # Generate synchronized signals.
  set SDICP 1
  set SDICP_signal $SDICP
  set SDICN 1
  set SDICN_signal $SDICN
  for {set current_time 1} {$current_time < $max_time} {incr current_time} {
    set SDI [lindex $SDI_signal $current_time]
    set CK [lindex $CK_signal $current_time]
    set CKD [lindex $CK_signal [expr $current_time - 1]]
    if {($CK == 1) && ($CKD == 0)} {
      set SDICP $SDI
    }
    if {($CK == 0) && ($CKD == 1)} {
      set SDICN $SDI
    }
    lappend SDICP_signal $SDICP
    lappend SDICN_signal $SDICN
  }
  
  # Decode the data bits.
  set state 0
  set clearance [expr round($CK_period*0.5)]
  set end_state [expr $Num_Bits*2+3]
  for {set current_time $clearance} {$current_time < $max_time - $clearance} {incr current_time} {
    set SDICP [lindex $SDICP_signal [expr $current_time - 1]]
    set SDICN [lindex $SDICN_signal [expr $current_time - 1]]
    set CK [lindex $CK_signal $current_time]
    set CKD [lindex $CK_signal [expr $current_time - 1]]
    if {($CK == 1) && ($CKD == 0)} {
      set index [expr $current_time - round($CK_period*0.5)]
      set SDID [lindex $SDI_signal $index]
      for {set i 0} {$i < $Num_Bits} {incr i} {
        if {$state == 2*$i + 2} {
          set s$i $SDID
          lwdaq_graph "$index 0 $index 1" plots \
            -y_min 0 -y_max 1 -x_min 0 -x_max $max_time -color 9
        }
      }
      if {$state == 0} {
        if {!$SDICP} {set state 1} {set state 0}
      } elseif {$state == $end_state} {
        set state $end_state
      } else {
        incr state
      }
    }
  }

  # Plot
  lwdaq_graph $SDI_signal plots -y_only 1 -y_min -7 -y_max 2 -color 1
  lwdaq_graph $CK_signal plots -y_only 1 -y_min -5 -y_max 4 -color 2
  lwdaq_graph $SDICP_signal plots -y_only 1 -y_min -3 -y_max 6 -color 3
  lwdaq_graph $SDICN_signal plots -y_only 1 -y_min -1 -y_max 8 -color 4
  lwdaq_draw plots p
  LWDAQ_update

  # Check decode
  set e 0
  for {set i 0} {$i < $Num_Bits} {incr i} {
    if {[set s$i] != [set d$i]} {set e 1}
  }
  if {$e || ($Sim_Run == 0)} {
    for {set i 0} {$i < $Num_Bits} {incr i} {
      LWDAQ_print -nonewline $t "[set d$i] "
    }
    LWDAQ_print $t
    for {set i 0} {$i < $Num_Bits} {incr i} {
      LWDAQ_print -nonewline $t "[set s$i] " orange
    }
    LWDAQ_print $t
    if {$e} {
      set color red
      set Sim_Run 0
    } {
      set color purple
    }
    foreach a {CK_period CK_jitter CK_offset Trial_Count} {
      LWDAQ_print -nonewline $t "$a\: [set $a] " $color
    }
    LWDAQ_print $t
    set Trial_Count 0
  } else {
    if {$Sim_Run == 1} {LWDAQ_post "go $t"}
  }
}
</script>

<script>
#
# LWDAQ Toolmaker Script to Simulate Deserialization. The serial bit period is
# 1000 ticks. The default deserializer clock, CK, is 500 ticks. The incoming
# serial signal is SDI. We detect the start bit on SDI with a rising edge of CK.
# on fourth rising edge, we obtain the value of the first serial bit. But we do
# not use SDI to obtain this bit, we instead use SDI synchronized with the
# falling edge of CK. Thus the first bit value is the value of SDI on the
# falling edge of CK just before the fourth rising edge. The simulation
# generates random serial transmissions, offset from our clock by a random time,
# and with clock jitter. It deserializes using the jittered clock edges and
# compares the original random serial byte to what it has obtained, and stops
# with a red text message if it sees disagreement. Otherwise, it keeps counting
# trials.
#

# Set up the display.
set wd 1000
set ht 300
lwdaq_image_create -width $wd -height $ht -name plots
catch {image delete p}
image create photo p
destroy $f.i
label $f.i -image p
pack $f.i
frame $f.f
pack $f.f -side top -expand yes
button $f.f.go -text Go -command "start $t"
button $f.f.stop -text Stop -command "set Sim_Run 0"
pack $f.f.go $f.f.stop -side left -expand yes
foreach a {CK_period CK_jitter Num_Bits Trial_Count} {
  set b [string tolower $a]
  label $f.f.l$b -text $a\:
  entry $f.f.$b -textvariable $a -width 10
  pack $f.f.l$b $f.f.$b -side left -expand yes
}
set CK_period 500
set CK_jitter 1
set Trial_Count 0
set Sim_Run 0
set Num_Bits 8

proc start {t} {
  global Sim_Run
  if {$Sim_Run == 1} {return}
  set Sim_Run 1
  go $t
}

proc go {t} {
  # global variables
  global CK_jitter CK_period Trial_Count Sim_Run Num_Bits
  if {![winfo exists $t]} {return}

  # New plots
  lwdaq_graph "" plots -fill 1
  lwdaq_draw plots p
  incr Trial_Count

  # Extent of simulation in arbitrary time units.
  set bit_period 1000
  set max_time [expr $bit_period * ($Num_Bits + 4)]
  
  # Set up time simulation of the clock.
  set CK_signal ""
  set current_time 0
  set CK_offset [expr 10 + round(rand()*$CK_period)]
  set counter $CK_offset
  set current_value 0
  for {set current_time 0} {$current_time < $max_time} {incr current_time} {
    lappend CK_signal $current_value
    if {$counter > 1} {
      set counter [expr $counter - 1]
    } else {
      set counter [expr round($CK_period*0.5 + (rand()-0.5)*$CK_jitter)]
      if {$current_value} {
        set current_value 0
      } else {
        set current_value 1
      }
    }
  }
  
 # Signal to be synchronized.
  for {set i 0} {$i < $Num_Bits} {incr i} {
    set d$i [expr round(rand())]
  }
  set SDI_signal ""
  set current_time 0
  set current_value 1
  for {set current_time 0} {$current_time < $max_time} {incr current_time} {
    lappend SDI_signal $current_value
    set bit_num [expr $current_time / $bit_period]
    if {$bit_num < 1} {set current_value 1}
    if {$bit_num == 1} {set current_value 0}
    if {($bit_num > 1) && ($bit_num < $Num_Bits+2)} {
      set current_value [set d[expr $bit_num-2]]
    }
    if {$bit_num >= $Num_Bits+2} {set current_value 1}
  }
  
 # Generate synchronized signals.
  set SDICP 1
  set SDICP_signal $SDICP
  set SDICN 1
  set SDICN_signal $SDICN
  for {set current_time 1} {$current_time < $max_time} {incr current_time} {
    set SDI [lindex $SDI_signal $current_time]
    set CK [lindex $CK_signal $current_time]
    set CKD [lindex $CK_signal [expr $current_time - 1]]
    if {($CK == 1) && ($CKD == 0)} {
      set SDICP $SDI
    }
    if {($CK == 0) && ($CKD == 1)} {
      set SDICN $SDI
    }
    lappend SDICP_signal $SDICP
    lappend SDICN_signal $SDICN
  }
  
  # Decode the data bits.
  set state 0
  set clearance [expr round($CK_period*0.5)]
  set end_state [expr $Num_Bits*2+3]
  for {set current_time $clearance} {$current_time < $max_time - $clearance} {incr current_time} {
    set SDICP [lindex $SDICP_signal [expr $current_time - 1]]
    set SDICN [lindex $SDICN_signal [expr $current_time - 1]]
    set CK [lindex $CK_signal $current_time]
    set CKD [lindex $CK_signal [expr $current_time - 1]]
    if {($CK == 1) && ($CKD == 0)} {
      set index [expr $current_time - round($CK_period*0.5)]
      set SDID [lindex $SDI_signal $index]
      for {set i 0} {$i < $Num_Bits} {incr i} {
        if {$state == 2*$i + 2} {
          set s$i $SDID
          lwdaq_graph "$index 0 $index 1" plots \
            -y_min 0 -y_max 1 -x_min 0 -x_max $max_time -color 9
        }
      }
      if {$state == 0} {
        if {!$SDICP} {set state 1} {set state 0}
      } elseif {$state == $end_state} {
        set state $end_state
      } else {
        incr state
      }
    }
  }

  # Plot
  lwdaq_graph $SDI_signal plots -y_only 1 -y_min -7 -y_max 2 -color 1
  lwdaq_graph $CK_signal plots -y_only 1 -y_min -5 -y_max 4 -color 2
  lwdaq_graph $SDICP_signal plots -y_only 1 -y_min -3 -y_max 6 -color 3
  lwdaq_graph $SDICN_signal plots -y_only 1 -y_min -1 -y_max 8 -color 4
  lwdaq_draw plots p
  LWDAQ_update

  # Check decode
  set e 0
  for {set i 0} {$i < $Num_Bits} {incr i} {
    if {[set s$i] != [set d$i]} {set e 1}
  }
  if {$e || ($Sim_Run == 0)} {
    for {set i 0} {$i < $Num_Bits} {incr i} {
      LWDAQ_print -nonewline $t "[set d$i] "
    }
    LWDAQ_print $t
    for {set i 0} {$i < $Num_Bits} {incr i} {
      LWDAQ_print -nonewline $t "[set s$i] " orange
    }
    LWDAQ_print $t
    if {$e} {
      set color red
      set Sim_Run 0
    } {
      set color purple
    }
    foreach a {CK_period CK_jitter CK_offset Trial_Count} {
      LWDAQ_print -nonewline $t "$a\: [set $a] " $color
    }
    LWDAQ_print $t
    set Trial_Count 0
  } else {
    if {$Sim_Run == 1} {LWDAQ_post "go $t"}
  }
}
</script>

<script>
#
# LWDAQ Toolmaker Script to Simulate Deserialization. The serial bit period is
# 1000 ticks. The default deserializer clock, CK, is 500 ticks. The incoming
# serial signal is SDI. We detect the start bit on SDI with a rising edge of CK.
# on fourth rising edge, we obtain the value of the first serial bit. But we do
# not use SDI to obtain this bit, we instead use SDI synchronized with the
# falling edge of CK. Thus the first bit value is the value of SDI on the
# falling edge of CK just before the fourth rising edge. The simulation
# generates random serial transmissions, offset from our clock by a random time,
# and with clock jitter. It deserializes using the jittered clock edges and
# compares the original random serial byte to what it has obtained, and stops
# with a red text message if it sees disagreement. Otherwise, it keeps counting
# trials.
#

# Set up the display.
set wd 1000
set ht 300
lwdaq_image_create -width $wd -height $ht -name plots
catch {image delete p}
image create photo p
destroy $f.i
label $f.i -image p
pack $f.i
frame $f.f
pack $f.f -side top -expand yes
button $f.f.go -text Go -command "start $t"
button $f.f.stop -text Stop -command "set Sim_Run 0"
pack $f.f.go $f.f.stop -side left -expand yes
foreach a {CK_period CK_jitter Num_Bits Trial_Count} {
  set b [string tolower $a]
  label $f.f.l$b -text $a\:
  entry $f.f.$b -textvariable $a -width 10
  pack $f.f.l$b $f.f.$b -side left -expand yes
}
set CK_period 500
set CK_jitter 10
set Trial_Count 0
set Sim_Run 0
set Num_Bits 8

proc start {t} {
  global Sim_Run
  if {$Sim_Run == 1} {return}
  set Sim_Run 1
  go $t
}

proc go {t} {
  # global variables
  global CK_jitter CK_period Trial_Count Sim_Run Num_Bits
  if {![winfo exists $t]} {return}

  # New plots
  lwdaq_graph "" plots -fill 1
  lwdaq_draw plots p
  incr Trial_Count

  # Extent of simulation in arbitrary time units.
  set bit_period 1000
  set max_time [expr $bit_period * ($Num_Bits + 4)]
  
  # Set up time simulation of the clock.
  set CK_signal ""
  set current_time 0
  set CK_offset [expr 10 + round(rand()*$CK_period)]
  set counter $CK_offset
  set current_value 0
  for {set current_time 0} {$current_time < $max_time} {incr current_time} {
    lappend CK_signal $current_value
    if {$counter > 1} {
      set counter [expr $counter - 1]
    } else {
      set counter [expr round($CK_period*0.5 + (rand()-0.5)*$CK_jitter)]
      if {$current_value} {
        set current_value 0
      } else {
        set current_value 1
      }
    }
  }
  
 # Signal to be synchronized.
  for {set i 0} {$i < $Num_Bits} {incr i} {
    set d$i [expr round(rand())]
  }
  set SDI_signal ""
  set current_time 0
  set current_value 1
  for {set current_time 0} {$current_time < $max_time} {incr current_time} {
    lappend SDI_signal $current_value
    set bit_num [expr $current_time / $bit_period]
    if {$bit_num < 1} {set current_value 1}
    if {$bit_num == 1} {set current_value 0}
    if {($bit_num > 1) && ($bit_num < $Num_Bits+2)} {
      set current_value [set d[expr $bit_num-2]]
    }
    if {$bit_num >= $Num_Bits+2} {set current_value 1}
  }
  
 # Generate synchronized signals.
  set SDICP 1
  set SDICP_signal $SDICP
  set SDICN 1
  set SDICN_signal $SDICN
  for {set current_time 1} {$current_time < $max_time} {incr current_time} {
    set SDI [lindex $SDI_signal $current_time]
    set CK [lindex $CK_signal $current_time]
    set CKD [lindex $CK_signal [expr $current_time - 1]]
    if {($CK == 1) && ($CKD == 0)} {
      set SDICP $SDI
    }
    if {($CK == 0) && ($CKD == 1)} {
      set SDICN $SDI
    }
    lappend SDICP_signal $SDICP
    lappend SDICN_signal $SDICN
  }
  
  # Decode the data bits.
  set state 0
  set clearance [expr round($CK_period*0.5)]
  set end_state [expr $Num_Bits*2+3]
  for {set current_time $clearance} {$current_time < $max_time - $clearance} {incr current_time} {
    set SDICP [lindex $SDICP_signal [expr $current_time - 1]]
    set SDICN [lindex $SDICN_signal [expr $current_time - 1]]
    set CK [lindex $CK_signal $current_time]
    set CKD [lindex $CK_signal [expr $current_time - 1]]
    if {($CK == 1) && ($CKD == 0)} {
      set index [expr $current_time - round($CK_period*0.5)]
      set SDID [lindex $SDI_signal $index]
      for {set i 0} {$i < $Num_Bits} {incr i} {
        if {$state == 2*$i + 2} {
          set s$i $SDID
          lwdaq_graph "$index 0 $index 1" plots \
            -y_min 0 -y_max 1 -x_min 0 -x_max $max_time -color 9
        }
      }
      if {$state == 0} {
        if {!$SDICP} {set state 1} {set state 0}
      } elseif {$state == $end_state} {
        set state $end_state
      } else {
        incr state
      }
    }
  }

  # Plot
  lwdaq_graph $SDI_signal plots -y_only 1 -y_min -7 -y_max 2 -color 1
  lwdaq_graph $CK_signal plots -y_only 1 -y_min -5 -y_max 4 -color 2
  lwdaq_graph $SDICP_signal plots -y_only 1 -y_min -3 -y_max 6 -color 3
  lwdaq_graph $SDICN_signal plots -y_only 1 -y_min -1 -y_max 8 -color 4
  lwdaq_draw plots p
  LWDAQ_update

  # Check decode
  set e 0
  for {set i 0} {$i < $Num_Bits} {incr i} {
    if {[set s$i] != [set d$i]} {set e 1}
  }
  if {$e || ($Sim_Run == 0)} {
    for {set i 0} {$i < $Num_Bits} {incr i} {
      LWDAQ_print -nonewline $t "[set d$i] "
    }
    LWDAQ_print $t
    for {set i 0} {$i < $Num_Bits} {incr i} {
      LWDAQ_print -nonewline $t "[set s$i] " orange
    }
    LWDAQ_print $t
    if {$e} {
      set color red
      set Sim_Run 0
    } {
      set color purple
    }
    foreach a {CK_period CK_jitter CK_offset Trial_Count} {
      LWDAQ_print -nonewline $t "$a\: [set $a] " $color
    }
    LWDAQ_print $t
    set Trial_Count 0
  } else {
    if {$Sim_Run == 1} {LWDAQ_post "go $t"}
  }
}
</script>

<script>
#
# LWDAQ Toolmaker Script to Simulate Deserialization. The serial bit period is
# 1000 ticks. The default deserializer clock, CK, is 500 ticks. The incoming
# serial signal is SDI. We detect the start bit on SDI with a rising edge of CK.
# on fourth rising edge, we obtain the value of the first serial bit. But we do
# not use SDI to obtain this bit, we instead use SDI synchronized with the
# falling edge of CK. Thus the first bit value is the value of SDI on the
# falling edge of CK just before the fourth rising edge. The simulation
# generates random serial transmissions, offset from our clock by a random time,
# and with clock jitter. It deserializes using the jittered clock edges and
# compares the original random serial byte to what it has obtained, and stops
# with a red text message if it sees disagreement. Otherwise, it keeps counting
# trials.
#

# Set up the display.
set wd 1000
set ht 300
lwdaq_image_create -width $wd -height $ht -name plots
catch {image delete p}
image create photo p
destroy $f.i
label $f.i -image p
pack $f.i
frame $f.f
pack $f.f -side top -expand yes
button $f.f.go -text Go -command "start $t"
button $f.f.stop -text Stop -command "set Sim_Run 0"
pack $f.f.go $f.f.stop -side left -expand yes
foreach a {CK_period CK_jitter Num_Bits Trial_Count} {
  set b [string tolower $a]
  label $f.f.l$b -text $a\:
  entry $f.f.$b -textvariable $a -width 10
  pack $f.f.l$b $f.f.$b -side left -expand yes
}
set CK_period 500
set CK_jitter 10
set Trial_Count 0
set Sim_Run 0
set Num_Bits 8

proc start {t} {
  global Sim_Run
  if {$Sim_Run == 1} {return}
  set Sim_Run 1
  go $t
}

proc go {t} {
  # global variables
  global CK_jitter CK_period Trial_Count Sim_Run Num_Bits
  if {![winfo exists $t]} {return}

  # New plots
  lwdaq_graph "" plots -fill 1
  lwdaq_draw plots p
  incr Trial_Count

  # Extent of simulation in arbitrary time units.
  set bit_period 1000
  set max_time [expr $bit_period * ($Num_Bits + 4)]
  
  # Set up time simulation of the clock.
  set CK_signal ""
  set current_time 0
  set CK_offset [expr 10 + round(rand()*$CK_period)]
  set counter $CK_offset
  set current_value 0
  for {set current_time 0} {$current_time < $max_time} {incr current_time} {
    lappend CK_signal $current_value
    if {$counter > 1} {
      set counter [expr $counter - 1]
    } else {
      set counter [expr round($CK_period*0.5 + (rand()-0.5)*$CK_jitter)]
      if {$current_value} {
        set current_value 0
      } else {
        set current_value 1
      }
    }
  }
  
 # Signal to be synchronized.
  for {set i 0} {$i < $Num_Bits} {incr i} {
    set d$i [expr round(rand())]
  }
  set SDI_signal ""
  set current_time 0
  set current_value 1
  for {set current_time 0} {$current_time < $max_time} {incr current_time} {
    lappend SDI_signal $current_value
    set bit_num [expr $current_time / $bit_period]
    if {$bit_num < 1} {set current_value 1}
    if {$bit_num == 1} {set current_value 0}
    if {($bit_num > 1) && ($bit_num < $Num_Bits+2)} {
      set current_value [set d[expr $bit_num-2]]
    }
    if {$bit_num >= $Num_Bits+2} {set current_value 1}
  }
  
 # Generate synchronized signals.
  set SDICP 1
  set SDICP_signal $SDICP
  set SDICN 1
  set SDICN_signal $SDICN
  for {set current_time 1} {$current_time < $max_time} {incr current_time} {
    set SDI [lindex $SDI_signal $current_time]
    set CK [lindex $CK_signal $current_time]
    set CKD [lindex $CK_signal [expr $current_time - 1]]
    if {($CK == 1) && ($CKD == 0)} {
      set SDICP $SDI
    }
    if {($CK == 0) && ($CKD == 1)} {
      set SDICN $SDI
    }
    lappend SDICP_signal $SDICP
    lappend SDICN_signal $SDICN
  }
  
  # Decode the data bits.
  set state 0
  set clearance [expr round($CK_period*0.5)]
  set end_state [expr $Num_Bits*2+3]
  for {set current_time $clearance} {$current_time < $max_time - $clearance} {incr current_time} {
    set SDICP [lindex $SDICP_signal [expr $current_time - 1]]
    set SDICN [lindex $SDICN_signal [expr $current_time - 1]]
    set CK [lindex $CK_signal $current_time]
    set CKD [lindex $CK_signal [expr $current_time - 1]]
    if {($CK == 1) && ($CKD == 0)} {
      set index [expr $current_time - round($CK_period*0.5)]
      set SDID [lindex $SDI_signal $index]
      for {set i 0} {$i < $Num_Bits} {incr i} {
        if {$state == 2*$i + 2} {
          set s$i $SDID
          lwdaq_graph "$index 0 $index 1" plots \
            -y_min 0 -y_max 1 -x_min 0 -x_max $max_time -color 9
        }
      }
      if {$state == 0} {
        if {!$SDICP} {set state 1} {set state 0}
      } elseif {$state == $end_state} {
        set state $end_state
      } else {
        incr state
      }
    }
  }

  # Plot
  lwdaq_graph $SDI_signal plots -y_only 1 -y_min -7 -y_max 2 -color 1
  lwdaq_graph $CK_signal plots -y_only 1 -y_min -5 -y_max 4 -color 2
  lwdaq_graph $SDICP_signal plots -y_only 1 -y_min -3 -y_max 6 -color 3
  lwdaq_graph $SDICN_signal plots -y_only 1 -y_min -1 -y_max 8 -color 4
  lwdaq_draw plots p
  LWDAQ_update

  # Check decode
  set e 0
  for {set i 0} {$i < $Num_Bits} {incr i} {
    if {[set s$i] != [set d$i]} {set e 1}
  }
  if {$e || ($Sim_Run == 0)} {
    for {set i 0} {$i < $Num_Bits} {incr i} {
      LWDAQ_print -nonewline $t "[set d$i] "
    }
    LWDAQ_print $t
    for {set i 0} {$i < $Num_Bits} {incr i} {
      LWDAQ_print -nonewline $t "[set s$i] " orange
    }
    LWDAQ_print $t
    if {$e} {
      set color red
      set Sim_Run 0
    } {
      set color purple
    }
    foreach a {CK_period CK_jitter CK_offset Trial_Count} {
      LWDAQ_print -nonewline $t "$a\: [set $a] " $color
    }
    LWDAQ_print $t
    set Trial_Count 0
  } else {
    if {$Sim_Run == 1} {LWDAQ_post "go $t"}
  }
}
</script>

