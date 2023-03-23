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
lwdaq_scam $img classify "50 %"
lwdaq_draw $img bcam_photo -intensify exact
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
lwdaq_scam $img classify "50 %"
lwdaq_draw $img bcam_photo -intensify exact
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set body "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img classify "10 %"
lwdaq_scam $img project $camera $body
lwdaq_draw $img bcam_photo -intensify exact
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set body "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img classify "20 %"
lwdaq_scam $img project $camera $body
lwdaq_draw $img bcam_photo -intensify exact
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set body "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img classify "20 %"
#lwdaq_scam $img project $camera $body
lwdaq_draw $img bcam_photo -intensify exact
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set body "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img classify "15 %"
#lwdaq_scam $img project $camera $body
lwdaq_draw $img bcam_photo -intensify exact
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set body "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img classify "15 %"
#lwdaq_scam $img project $camera $body
lwdaq_draw $img bcam_photo -intensify exact
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set body "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img classify "10 %"
#lwdaq_scam $img project $camera $body
lwdaq_draw $img bcam_photo -intensify exact
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set body "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img classify "5 %"
#lwdaq_scam $img project $camera $body
lwdaq_draw $img bcam_photo -intensify exact
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set body "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img classify "10 %"
#lwdaq_scam $img project $camera $body
lwdaq_draw $img bcam_photo -intensify exact
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set body "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img classify "10 %"
#lwdaq_scam $img project $camera $body
lwdaq_draw $img bcam_photo -intensify exact
</script>

<script>

</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set body "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img classify "10 %"
#lwdaq_scam $img project $camera $body
lwdaq_draw $img bcam_photo -intensify exact
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set body "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img classify "10 %"
lwdaq_scam $img project $camera $body
lwdaq_draw $img bcam_photo -intensify exact
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set body "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img classify "5 %"
#lwdaq_scam $img project $camera $body
lwdaq_draw $img bcam_photo -intensify exact
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set body "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img classify "1 %"
#lwdaq_scam $img project $camera $body
lwdaq_draw $img bcam_photo -intensify exact
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set body "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img classify "10 %"
#lwdaq_scam $img project $camera $body
lwdaq_draw $img bcam_photo -intensify exact
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set body "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img classify "20 %"
#lwdaq_scam $img project $camera $body
lwdaq_draw $img bcam_photo -intensify exact
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set body "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img classify "20 %"
#lwdaq_scam $img project $camera $body
lwdaq_draw $img bcam_photo -intensify exact
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set body "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img classify "30 %"
#lwdaq_scam $img project $camera $body
lwdaq_draw $img bcam_photo -intensify exact
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set body "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img classify "50 %"
#lwdaq_scam $img project $camera $body
lwdaq_draw $img bcam_photo -intensify exact
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set body "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img classify "40 %"
#lwdaq_scam $img project $camera $body
lwdaq_draw $img bcam_photo -intensify exact
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set body "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img classify "10 %"
#lwdaq_scam $img project $camera $body
lwdaq_draw $img bcam_photo -intensify exact
</script>

<script>
LWDAQ_open BCAM
LWDAQ_acquire BCAM
set img $LWDAQ_config_BCAM(memory_name)
set camera "test 0 0 0 0 0 2 25 0" 
set body "cylinder 0 0 1000 0 -0.04 -1 10 500\
	sphere 50 50 1000 20\
	sphere 50 -50 1000 20\
	cylinder -200 100 4000 0.1 0.1 1 30 1000"
lwdaq_scam $img classify "50 %"
#lwdaq_scam $img project $camera $body
lwdaq_draw $img bcam_photo -intensify exact
</script>

