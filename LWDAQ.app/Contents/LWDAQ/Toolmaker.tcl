<script>

</script>

<script>
#
# SCT Label Generator. The SCT serial number consists of a series
# number, which is three digits, and a channel number, which is one to
# three digits. The channel number gives the first SCT communication
# channel the labelled device uses, but does not give the subsequent
# channel numbers. This generator skips the reserved SCT channel numbers,
# which are those for which the remainder is zero or fifteen when divided
# by sixteen. 
#
# [06-DEC-19] Generate 2000 labels starting with 215_69.
# [07-JUN-22] Generate 2000 labels starting with 225_115
#
set f [open ~/Desktop/Labels.txt w]
set set_num 225
set id_num 115
set num_labels 2000
set count 0
while {$count < $num_labels} {
	if {($id_num % 16 > 0) && ($id_num % 16 < 15)} {
		puts $f "$set_num $id_num"
		incr count
	} 
	incr id_num
	if {$id_num > 222} {
		incr set_num
		set id_num 1
	}
}
close $f
</script>

