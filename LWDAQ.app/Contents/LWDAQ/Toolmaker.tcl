<script>
for {set start 0} {$start < [expr 24 * 60 * 60]} {incr start 60} {
	LWDAQ_print ~/Desktop/Minutes.txt [LWDAQ_minute_of_day $start]
}
</script>

<script>
set offset [clock seconds]
for {set offset 0} {$offset < [expr 24 * 60 * 60]} {incr offset 60} {
	LWDAQ_print ~/Desktop/Minutes.txt [LWDAQ_minute_of_day [expr $start + $offset]]
}
</script>

<script>
set offset [clock seconds]
for {set offset 0} {$offset < [expr 24 * 60 * 60]} {incr offset 60} {
	LWDAQ_minute_of_day [expr $start + $offset]
}
</script>

<script>
set start [clock seconds]
for {set offset 0} {$offset < [expr 24 * 60 * 60]} {incr offset 60} {
	LWDAQ_minute_of_day [expr $start + $offset]
}
</script>

<script>
set start [clock seconds]
for {set offset 0} {$offset < [expr 24 * 60 * 60]} {incr offset 60} {
	LWDAQ_minute_of_day [expr $start + $offset]
}
</script>

<script>
set LWDAQ_Info(scheduled_tasks) [list "10 * * * *" "puts hi"]
LWDAQ_scheduler 0
</script>

<script>
set LWDAQ_Info(scheduled_tasks) [list "10 * * * *" "puts hi"]
LWDAQ_scheduler 0
</script>

<script>
set LWDAQ_Info(scheduled_tasks) [list "10 * * * *" "puts hi"]
LWDAQ_scheduler 0
</script>

<script>
set LWDAQ_Info(scheduled_tasks) [list "10 * * * *" "puts hi"]
		foreach task $LWDAQ_Info(scheduled_tasks) {
			LWDAQ_print $t $task
			LWDAQ_print $t [lindex $task 0]
			scan [lindex $task 0] %s%s%s%s%s min hr dymo mo dywk
			set command [lindex $task 1]
			LWDAQ_print $t "$min $hr $dymo $mo $dywk $command"	
		}
</script>

<script>
set LWDAQ_Info(scheduled_tasks) [list "10 * * * *" "puts hi"]
		foreach task $LWDAQ_Info(scheduled_tasks) {
			LWDAQ_print $t $task
			LWDAQ_print $t [lindex $task 0]
			scan [lindex $task 0] %s%s%s%s%s min hr dymo mo dywk
			set command [lindex $task 1]
			LWDAQ_print $t "$min $hr $dymo $mo $dywk $command"	
		}
</script>

<script>
set LWDAQ_Info(scheduled_tasks) [list [list "10 * * * *" "puts hi"]]
		foreach task $LWDAQ_Info(scheduled_tasks) {
			LWDAQ_print $t $task
			LWDAQ_print $t [lindex $task 0]
			scan [lindex $task 0] %s%s%s%s%s min hr dymo mo dywk
			set command [lindex $task 1]
			LWDAQ_print $t "$min $hr $dymo $mo $dywk $command"	
		}
</script>

<script>
set LWDAQ_Info(scheduled_tasks) [list [list "13 * * * *" "puts hi"]]
LWDAQ_scheduler 0
</script>

<script>
LWDAQ_scheduler 0
</script>

<script>
LWDAQ_scheduler 0
LWDAQ_schedule_task "hello" "33 * * * *" {puts "hello [clock seconds]"} 
LWDAQ_schedule_task "well" "35 * * * *" {puts "well well"}
</script>

<script>
LWDAQ_scheduler 0
LWDAQ_schedule_task "hello" "41 * * * *" {puts "hello [clock seconds]"} 
LWDAQ_schedule_task "well" "42 * * * *" {puts "well well"}
</script>

<script>
LWDAQ_schedule_task "hello" "41 * * * *" {puts "hello [clock seconds]"} 
LWDAQ_schedule_task "well" "42 * * * *" {puts "well well"}
foreach task $LWDAQ_Info(scheduled_tasks) {LWDAQ_print $t $task}

LWDAQ_schedule_task "hello" "46 * * * *" {puts "hello [clock seconds]"} 
LWDAQ_schedule_task "well" "49 * * * *" {puts "well well"}
foreach task $LWDAQ_Info(scheduled_tasks) {LWDAQ_print $t $task}
</script>

<script>
LWDAQ_schedule_task "hello" "41 * * * *" {puts "hello [clock seconds]"} 
LWDAQ_schedule_task "well" "42 * * * *" {puts "well well"}
foreach task $LWDAQ_Info(scheduled_tasks) {LWDAQ_print $t $task}

LWDAQ_schedule_task "hello" "50 * * * *" {puts "hello [clock seconds]"} 
LWDAQ_schedule_task "well" "51 * * * *" {puts "well well"}
foreach task $LWDAQ_Info(scheduled_tasks) {LWDAQ_print $t $task}
</script>

<script>
LWDAQ_schedule_task "hello" "41 * * * *" {puts "hello [clock seconds]"} 
LWDAQ_schedule_task "well" "42 * * * *" {puts "well well"}
foreach task $LWDAQ_Info(scheduled_tasks) {LWDAQ_print $t $task}

LWDAQ_schedule_task "hello" "50 * * * *" {puts "hello [clock seconds]"} 
LWDAQ_schedule_task "well" "51 * * * *" {puts "well well"}
foreach task $LWDAQ_Info(scheduled_tasks) {LWDAQ_print $t $task}
LWDAQ_scheduler
</script>

<script>
LWDAQ_schedule_task "hello" "54 11 9 3 *" {puts "hello [clock seconds]"} 
LWDAQ_schedule_task "well" "55 * * * *" {puts "well well"}
foreach task $LWDAQ_Info(scheduled_tasks) {LWDAQ_print $t $task}
LWDAQ_scheduler
</script>

<script>
LWDAQ_schedule_task "hello" "54 11 9 3 *" {puts "hello [clock seconds]"} 
LWDAQ_schedule_task "well" "55 * * * *" {puts "well well"}
foreach task $LWDAQ_Info(scheduled_tasks) {LWDAQ_print $t $task}
LWDAQ_scheduler
</script>

<script>
LWDAQ_schedule_task "hello" "57 11 9 3 *" {puts "hello [clock seconds]"} 
LWDAQ_schedule_task "well" "58 * * * 3" {puts "well well"}
foreach task $LWDAQ_Info(scheduled_tasks) {LWDAQ_print $t $task}
</script>

<script>
LWDAQ_schedule_task "hello" "57 11 9 3 *" {puts "hello [clock seconds]"} 
LWDAQ_schedule_task "well" "58 * * * 3" {puts "well well"}
foreach task $LWDAQ_Info(scheduled_tasks) {LWDAQ_print $t $task}
set LWDAQ_Info(scheduler_log) $t
LWDAQ_scheduler
</script>

<script>
LWDAQ_schedule_task "hello" "05 12 9 3 *" {puts "hello [clock seconds]"} 
LWDAQ_schedule_task "well" "05 12 * * 3" {puts "well well"}
</script>

<script>
set LWDAQ_Info(scheduler_log) $t
LWDAQ_schedule_task "hello" "13 12 * * 3" {puts "hello [clock seconds]"} 
LWDAQ_schedule_task "well" "12 * * * 3" {puts "well well"}
foreach task $LWDAQ_Info(scheduled_tasks) {LWDAQ_print $t $task}
</script>

<script>
set LWDAQ_Info(scheduler_log) $t
LWDAQ_schedule_task "hello" "19 12 * * 3" {puts "hello [clock seconds]"} 
LWDAQ_schedule_task "well" "20 * 9 * *" {puts "well well"}
foreach task $LWDAQ_Info(scheduled_tasks) {LWDAQ_print $t $task}
</script>

<script>
set LWDAQ_Info(scheduler_log) $t
LWDAQ_schedule_task "hello" "20 12 * * 3" {puts "hello [clock seconds]"} 
LWDAQ_schedule_task "well" "21 * 9 * *" {puts "well well"}
foreach task $LWDAQ_Info(scheduled_tasks) {LWDAQ_print $t $task}
</script>

<script>
set LWDAQ_Info(scheduler_log) $t
LWDAQ_schedule_task "hello" "22 12 * * 3" {puts "hello [clock seconds]"} 
LWDAQ_schedule_task "well" "23 * 9 * *" {puts "well well"}
foreach task $LWDAQ_Info(scheduled_tasks) {LWDAQ_print $t $task}
</script>

