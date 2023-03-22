<script>

</script>

<script>
LWDAQ_acquire_BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 -25 0 0 0 0 0 0.01" "sphere 0 0 1000 10"
</script>

<script>
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 -25 0 0 0 0 0 0.01" "sphere 0 0 1000 10"
</script>

<script>
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 -25 0 0 0 0 0 0.01" 
set sphere "sphere 0 0 1000 10"
lwdaq_scam $img project $camera $sphere
</script>

<script>
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 -25 0 0 0 0 0 0.01" 
set sphere "sphere 0 0 1000 10"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "sphere 0 0 1000 40"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "sphere 0 0 1000 20"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "sphere 20 0 1000 20"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "sphere 20 0 1000 20 sphere 100 50 2000 50 cylinder 100 -100 1000 1 0 1 20 1000"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 100 -100 1000 1 0 1 20 1000 sphere 20 0 1000 20 sphere 100 50 2000 50"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 100 -100 1000 1 0 1 20 1000 sphere 20 0 1000 20 sphere 100 50 2000 50"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 100 -100 1000 1 0 1 20 1000 sphere 20 0 1000 20 sphere 100 50 2000 50"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 100 -100 1000 1 0 1 20 1000 sphere 20 0 1000 20 sphere 100 50 2000 50"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 10 -10 1000 1 1 0 20 1000 sphere 20 0 1000 20 sphere 100 50 2000 50"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 0 0 1000 0 -1 0 20 1000 sphere 20 0 1000 20 sphere 100 50 2000 50"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 0 0 1000 0 -1 0 10 1000 sphere 20 0 1000 20 sphere 100 50 2000 50"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 0 0 1000 0 -1 0 10 1000 sphere 0 0 1000 40"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 0 0 1000 0 -1 0 10 1000 sphere 100 100 1000 40"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 0 0 1000 0 -1 0 10 1000 sphere 50 50 1000 10"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 0 0 1000 0 -1 -0.1 10 1000 sphere 50 50 1000 10"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 0 0 1000 0 -1 -1 10 1000 sphere 50 50 1000 10"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 0 0 1000 0 -0.04 -1 10 1000 sphere 50 50 1000 10"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 0 0 1000 0 -0.01 -1 10 1000 sphere 50 50 1000 10"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 0 0 1000 0 -0.02 -1 10 1000 sphere 50 50 1000 10"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 0 0 1000 0 -0.02 -1 10 100 sphere 50 50 1000 10"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 0 0 1000 0 -0.02 -1 10 300 sphere 50 50 1000 10"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 0 0 1000 0 -0.04 -1 10 500 sphere 50 50 1000 10"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 0 0 1000 0 -0.04 -1 10 500 sphere 50 50 1000 20 sphere 150 -150 1000 20"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 0 0 1000 0 -0.04 -1 10 500 sphere 50 50 1000 20 sphere 50 -150 1000 20"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 0 0 1000 0 -0.04 -1 10 500 sphere 50 50 1000 20 sphere 50 -50 1000 20"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 0 10000 1 1 0 10 100"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 2000 1 1 0 20 100"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 1 1 0 20 100"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 1 1 1 30 1000"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo -intensification exact
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set sphere "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img project $camera $sphere
lwdaq_draw $img bcam_photo -intensify exact
</script>

