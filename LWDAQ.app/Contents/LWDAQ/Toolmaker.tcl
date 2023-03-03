<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 344 -height 244
set fn [LWDAQ_get_file_name]
$p read $fn
</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 344 -height 244
set fn [LWDAQ_get_file_name]
set f [open $fn]
set data [read $f]
close $f
$p put $data
</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 344 -height 244
set fn [LWDAQ_get_file_name]
set f [open $fn]
set data [read $f]
close $f
$p put $data
</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 700 -height 520
set fn [LWDAQ_get_file_name]
set f [open $fn]
set data [read $f]
close $f
$p put $data
</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 392 -height 292
set fn [LWDAQ_get_file_name]
set f [open $fn]
set data [read $f]
close $f
$p put $data
</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 392 -height 292
set fn [LWDAQ_get_file_name]
set f [open $fn]
set data [read $f]
close $f
$p put $data -format rggbb
</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 392 -height 292
set fn [LWDAQ_get_file_name]
set f [open $fn]
set data [read $f]
close $f
$p put $data
</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 392 -height 292
set fn [LWDAQ_get_file_name]
set f [open $fn]
set data [read $f]
LWDAQ_print $t [string length $data]
close $f
$p put $data
</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 392 -height 292
set fn [LWDAQ_get_file_name]
set f [open $fn]
fconfigure $f -translation binary
set data [read $f]
LWDAQ_print $t [string length $data]
close $f
$p put $data
</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 0 -height 0
set fn [LWDAQ_get_file_name]
set f [open $fn]
fconfigure $f -translation binary
set data [read $f]
LWDAQ_print $t [string length $data]
close $f
$p put $data
</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 0 -height 0
set fn [LWDAQ_get_file_name]
set f [open $fn]
fconfigure $f -translation binary
set data [read $f]
LWDAQ_print $t [string length $data]
close $f
lwdaq_draw_raw $data $p
</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 0 -height 0
set fn [LWDAQ_get_file_name]
set f [open $fn]
fconfigure $f -translation binary
set data [read $f]
LWDAQ_print $t [string length $data]
close $f
lwdaq_draw_raw $data $p
</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 0 -height 0
set fn [LWDAQ_get_file_name]
set f [open $fn]
fconfigure $f -translation binary
set data [read $f]
LWDAQ_print $t [string length $data]
close $f
lwdaq_draw_raw $data $p -width 700 -height 520
</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 0 -height 0
set fn [LWDAQ_get_file_name]
set f [open $fn]
fconfigure $f -translation binary
set data [read $f]
LWDAQ_print $t [string length $data]
close $f
lwdaq_draw_raw $data $p -width 700 -height 500
</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 0 -height 0
set fn [LWDAQ_get_file_name]
set f [open $fn]
fconfigure $f -translation binary
set data [read $f]
LWDAQ_print $t [string length $data]
close $f
lwdaq_draw_raw $data $p -pix_fmt gray -width 700 -height 500
</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 0 -height 0
set fn [LWDAQ_get_file_name]
set f [open $fn]
fconfigure $f -translation binary
set data [read $f]
LWDAQ_print $t [string length $data]
close $f
lwdaq_draw_raw $data $p -pix_fmt gray -width 700 -height 520
</script>

<script>

</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 0 -height 0
set fn [LWDAQ_get_file_name]
set f [open $fn]
fconfigure $f -translation binary
set data [read $f]
LWDAQ_print $t [string length $data]
close $f
lwdaq_draw_raw $data $p -pix_fmt gray -width 700 -height 520
</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 0 -height 0
set fn [LWDAQ_get_file_name]
set f [open $fn]
fconfigure $f -translation binary
set data [read $f]
LWDAQ_print $t [string length $data]
close $f
lwdaq_draw_raw $data $p -pix_fmt rgb24 -width 700 -height 520
</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 0 -height 0
set fn [LWDAQ_get_file_name]
set f [open $fn]
fconfigure $f -translation binary
set data [read $f]
LWDAQ_print $t [string length $data]
close $f
lwdaq_draw_raw $data $p -pix_fmt rgb24 -width 700 -height 500
</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 0 -height 0
set fn [LWDAQ_get_file_name]
set f [open $fn]
fconfigure $f -translation binary
set data [read $f]
LWDAQ_print $t [string length $data]
close $f
lwdaq_draw_raw $data $p -pix_fmt rgb24 -width 860 -height 443
</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 0 -height 0
set fn [LWDAQ_get_file_name]
set f [open $fn]
fconfigure $f -translation binary
set data [read $f]
LWDAQ_print $t [string length $data]
close $f
lwdaq_draw_raw $data $p -pix_fmt rgb24 -width 860 -height 400
</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 0 -height 0
set fn [LWDAQ_get_file_name]
set f [open $fn]
fconfigure $f -translation binary
set data [read $f]
LWDAQ_print $t [string length $data]
close $f
lwdaq_draw_raw $data $p -pix_fmt rgb24 -width 859 -height 400
</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 0 -height 0
set fn [LWDAQ_get_file_name]
set f [open $fn]
fconfigure $f -translation binary
set data [read $f]
LWDAQ_print $t [string length $data]
close $f
lwdaq_draw_raw $data $p -pix_fmt rgb24 -width 860 -height 400
</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 0 -height 0
set fn [LWDAQ_get_file_name]
set f [open $fn]
fconfigure $f -translation binary
set data [read $f]
LWDAQ_print $t [string length $data]
close $f
lwdaq_draw_raw $data $p -pix_fmt rgb24 -width 864 -height 400
</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 0 -height 0
set fn [LWDAQ_get_file_name]
set f [open $fn]
fconfigure $f -translation binary
set data [read $f]
LWDAQ_print $t [string length $data]
close $f
lwdaq_draw_raw $data $p -pix_fmt gray -width 700 -height 520
</script>

<script>
set p [image create photo]
label $f.vplayer -image $p
pack $f.vplayer -side top
$p configure -width 0 -height 0
set fn [LWDAQ_get_file_name]
set f [open $fn]
fconfigure $f -translation binary
set data [read $f]
LWDAQ_print $t [string length $data]
close $f
lwdaq_draw_raw $data $p -pix_fmt gray -width 410 -height 308
</script>

