program test;

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}

uses
	utils;
	
const
	bsize=10000000;
	gsize=1000;
	tsize=10;
	reps=100;
	mreps=100;
	msize=4;
	tmsize=100;
	xsize=10;
	xreps=100;
	fftsize=1024;
	
var
	p,q:smallint;
	i,j,n:integer;
	x,slope,intercept,residual:real;
	b1,b2:byte_array;
	s:string;
	good:boolean=false;
	gpx:x_graph_type;
	gpxy:xy_graph_type;
	gxy:xy_graph_type;
	gpxyz:xyz_graph_type;
	start_ms:qword;
	A,B,C:matrix_type;
	simplex:simplex_type;
	sv:simplex_vertex_type;
	bridge1,bridge2,bridge3:xyz_line_type;
	plane1,plane2,plane3:xyz_plane_type;
	line1,line2,line3:xyz_line_type;
	dp:x_graph_type;
	ft:xy_graph_type;
	ptr:pointer=nil;
	
procedure console_write(s:string);
begin writeln(s); end;

function console_read(s:string):string;
begin write(s);readln(s);console_read:=s; end;

procedure print_error(error:string);
begin
	report_error(error);
	writeln('ERROR: ',error);
end;
	
function simplex_error(v:simplex_vertex_type;dp:pointer):real;
var
	i:integer;
	sum:real;
begin
	sum:=0;
	for i:=1 to length(v)-1 do
		sum:=sum+sqr(v[i]);
	simplex_error:=sum;
end;

begin
	track_ptrs:=true;
	append_errors:=true;
{
	Check the routines that detect endianess of local platform, and swap
	byte order.
}
	writeln('Testing two-byte integer swapping...');
	p:=256;
	q:=reverse_smallint_bytes(p);
	if q<>1 then print_error('reverse_smallint_bytes of 256 was '+string_from_integer(q,1));
	p:=1;
	q:=reverse_smallint_bytes(p);
	if q<>256 then print_error('reverse_smallint_bytes of 1 was '+string_from_integer(q,1));
	if check_big_endian then writeln('Detect big-endian byte ordering on this platform.')
	else writeln('Detect little-endian byte ordering on this platform.');
{
	Test block move and timer system.
}	
	writeln('Creating two 10-MByte arrays...');
	setlength(b1,bsize);
	setlength(b2,bsize);

	writeln('Filling first array with values...');
	for i:=0 to bsize-1 do
		b1[i]:=i mod 256;

	writeln('Copying 10 MByte with block_move ',reps:1,' times...');
	start_timer('Start','block_move test');
	for j:=1 to reps do 
		block_move(@b1[0],@b2[0],bsize);
	mark_time('Check','block_move test');
	good:=true;
	for i:=1 to bsize-1 do 
		if b1[i]<>b2[i] then begin
			if good then begin
				writestr(s,'b1[',i:1,']<>b2[',i:1,'] in block_move accuracy');
				print_error(s);
			end;
			good:=false;
		end;
	mark_time('Done','block_move test');
	if good then writeln('Block move accurate.');
{
	Write out the timer marks to show formatting.
}	
	writeln('Reporting timer marks...');
	report_time_marks;
{
	Test millisecond timer.
}
	writeln('The millisecond clock is: ',clock_milliseconds);
{
	Test block set and block clear.
}
	writeln('Testing block clear on 10-MByte array.');
	setlength(b1,bsize);
	for i:=0 to bsize-1 do b1[i]:=i mod 256;
	block_clear(@b1[0],bsize);
	good:=true;
	for i:=0 to bsize-1 do
		if b1[i]<>0 then begin
			if good then begin
				writestr(s,'b1[',i:1,']<>0 in block_clear accuracy');
				print_error(s);
			end;
			good:=false;
		end;
	if good then writeln('Block clear accurate.');
		
	writeln('Testing block fill on 10-MByte array.');
	for i:=0 to bsize-1 do b1[i]:=i mod 256;
	block_fill(@b1[0],bsize);
	good:=true;
	for i:=0 to bsize-1 do
		if b1[i]<>$FF then begin
			if good then begin
				writestr(s,'b1[',i:1,']<>$FF in block_fill accuracy');
				print_error(s);
			end;
			good:=false;
		end;
	if good then writeln('Block fill accurate.');
			
	writeln('Testing block set on 10-MByte array.');
	for i:=0 to bsize-1 do
		b1[i]:=i mod 256;
	block_set(@b1[0],bsize,$AA);
	good:=true;
	for i:=0 to bsize-1 do
		if b1[i]<>$AA then begin
			if good then begin
				writestr(s,'b1[',i:1,']<>$AA in block_clear accuracy');
				print_error(s);
			end;
			good:=false;
		end;
	if good then writeln('Block set accurate.');
{
	Test xyz-geometry routines. We generate three random planes. The intersection of any
	two of them is a line. All three such lines must intersect at the same place. 
}
	fsd:=3;
	fsr:=1;
	writeln('Checking accuracy of xyz-geometry transformations and intersections.');
	good:=true;
	for i:=0 to reps do begin
		plane1.point:=xyz_random;
		plane1.normal:=xyz_random;
		plane2.point:=xyz_random;
		plane2.normal:=xyz_random;
		plane3.point:=xyz_random;
		plane3.normal:=xyz_random;
		line1:=xyz_plane_plane_intersection(plane1,plane2);
		line2:=xyz_plane_plane_intersection(plane1,plane3);
		line3:=xyz_plane_plane_intersection(plane2,plane3);
		bridge1:=xyz_line_line_bridge(line1,line2);
		bridge2:=xyz_line_line_bridge(line1,line3);
		bridge3:=xyz_line_line_bridge(line2,line3);
		if (xyz_length(bridge1.direction)>0.0001) 
			or (xyz_length(bridge2.direction)>0.0001) 
			or (xyz_length(bridge3.direction)>0.0001) then begin
			if good then begin
				print_error('Geometry error intersecting three random planes:');
				writeln('plane1: ',string_from_xyz_plane(plane1));
				writeln('plane2: ',string_from_xyz_plane(plane2));
				writeln('plane3: ',string_from_xyz_plane(plane3));				
			end;
			good:=false;
		end;
	end;
	if good then writeln('Geometry routines accurate through ',reps:1,
		' random plane-plane-plane intersections,');	
{
	Test x-graph generation, string interfaces, and pointer tracking, checking
	frequently to see if we are failing to dispose of outstanding pointers.
}
	writeln('Testing graph routines...');
	
	setlength(gpx,gsize);
	for i:=0 to length(gpx)-1 do 
		gpx[i]:=i;
	writeln('Created and filled x-graph of length ',gsize,' and length(gpx)=',length(gpx),'.');
	writeln('Translating gpx into string with string_from_x_graph ',reps:1,' times');
	start_ms:=clock_milliseconds;
	for i:=1 to reps do
		s:=string_from_x_graph(gpx);
	writeln('Each translation takes ',1.0*(clock_milliseconds-start_ms)/reps:1:2,' ms.');
	writeln('Turning off pointer tracking...');
	track_ptrs:=false;
	if num_outstanding_ptrs>0 then begin
		writestr(s,'Have ',num_outstanding_ptrs:1,
			' outsanding pointers after translating gpx into string.');
		print_error(s);
		num_outstanding_ptrs:=0;
	end;

	writeln('Translating string back into x-graph with x_graph_from_string ',reps:1,' times');
	start_ms:=clock_milliseconds;
	for i:=1 to reps do
		begin
			gpx:=read_x_graph(s);
		end;
	writeln('Each translation takes ',1.0*(clock_milliseconds-start_ms)/reps:1:2,' ms.');
	if num_outstanding_ptrs>0 then begin
		writestr(s,'Have ',num_outstanding_ptrs:1,
			' outsanding pointers after translating string to x-graph.');
		print_error(s);
		num_outstanding_ptrs:=0;
	end;

	gpx:=read_x_graph(s);
	writeln('Checking accuracy of translation from x-graph to string and back.');
	good:=true;
	for i:=1 to gsize-1 do 
		if gpx[i]<>i then begin
			if good then begin
				writestr(s,'point ',i:1,' value ',gpx[i]:fsr:fsd,
					' in x-graph string translation');
				print_error(s);
			end;
			good:=false;			
		end;
	if good then writeln('Translation accurate.');
{
	Check sorting and random number generator.
}
	fsd:=3;
	fsr:=1;
	writeln('Random list of ',tsize,' real numbers.');
	setlength(gpx,tsize);
	for i:=0 to length(gpx) do
		gpx[i]:=random_0_to_1;
	writeln('gpx: ',string_from_x_graph(gpx));
	x_graph_ascending(gpx);
	writeln('ascending: ',string_from_x_graph(gpx));
	good:=true;
	for i:=1 to length(gpx)-1 do
		if gpx[i]<gpx[i-1] then begin
			if good then begin
				writestr(s,'Element ',i:1,' less than element ',i-1:1,
				' in x-graph ascending sort');
				print_error(s);
			end;
			good:=false;
		end;
		
	x_graph_descending(gpx);
	writeln('descending: ',string_from_x_graph(gpx));
	good:=true;
	for i:=1 to length(gpx)-1 do
		if gpx[i]>gpx[i-1] then begin
			if good then begin
				writestr(s,'Element ',i:1,' greater than element ',i-1:1,
				' in x-graph descending sort');
				print_error(s);
			end;
			good:=false;
		end;

	fsd:=0;
	fsr:=1;
	writeln('Simple integer list of same size.');
	setlength(gpx,tsize);
	for i:=0 to length(gpx) do
		gpx[i]:=i+1;
	writeln('gpx: ',string_from_x_graph(gpx));
	x_graph_descending(gpx);
	writeln('descending: ',string_from_x_graph(gpx));
	x_graph_ascending(gpx);
	writeln('ascending: ',string_from_x_graph(gpx));	
	if num_outstanding_ptrs>0 then begin
		writestr(s,'Have ',num_outstanding_ptrs:1,
			' outsanding pointers after sorting x-graphs.');
		print_error(s);
		num_outstanding_ptrs:=0;
	end;
{
	Routines that operate upon x-graphs.
}
	fsd:=2;
	fsr:=1;
	writeln('average_x_graph=',average_x_graph(gpx):fsr:fsd);
	writeln('max_x_graph=',max_x_graph(gpx):fsr:fsd);
	writeln('min_x_graph=',min_x_graph(gpx):fsr:fsd);
	writeln('stdev_x_graph=',stdev_x_graph(gpx):fsr:fsd);
	writeln('mad_x_graph=',mad_x_graph(gpx):fsr:fsd);
	writeln('median_x_graph=',median_x_graph(gpx):fsr:fsd);
	writeln('10% percentile_x_graph=',percentile_x_graph(gpx,10):fsr:fsd);
	writeln('coastline_x_graph=',coastline_x_graph(gpx):fsr:fsd);
	writeln('slope_x_graph=',slope_x_graph(gpx,tsize div 2,tsize div 4):fsr:fsd);
	if num_outstanding_ptrs>0 then begin
		writestr(s,'Have ',num_outstanding_ptrs:1,
			' outsanding pointers after x-graph checks.');
		print_error(s);
	end;
	if num_outstanding_ptrs>0 then begin
		writestr(s,'Have ',num_outstanding_ptrs:1,
			' outsanding pointers after x-graph calculations.');
		print_error(s);
		num_outstanding_ptrs:=0;
	end;
{
	Test the accuracy of the fast fourier trasform routines.
}
	writeln('Checking fast Fast Fourier Transform (FFT) accuracy on a sum of five sinusoids.');
	setlength(dp,fftsize);
	for i:=0 to fftsize-1 do
		dp[i]:=sin(2*pi*i/fftsize)+sin(4*pi*i/fftsize)
			+sin(6*pi*i/fftsize)+sin(8*pi*i/fftsize)+sin(16*pi*i/fftsize);
	ft:=fft_real(dp);
	dp:=fft_real_inverse(ft);
	good:=true;
	for i:=0 to fftsize-1 do
		if abs(dp[i]-sin(2*pi*i/fftsize)-sin(4*pi*i/fftsize)
			-sin(6*pi*i/fftsize)-sin(8*pi*i/fftsize)-sin(16*pi*i/fftsize))>0.001 then 
			good:=false;
	if good then writeln('Inverse of transformed signal agrees with original.')
	else print_error('Inverse of transformed signal does not agree with original.');
{
	Test the speed of the fast fourier trasform routines.
}
	writeln('Checking fast Fourier transform speed on white noise of ',fftsize:1,' points.');
	setlength(dp,fftsize);
	start_ms:=clock_milliseconds;
	for j:=1 to reps do begin
		for i:=0 to fftsize-1 do dp[i]:=random_0_to_1;
		ft:=fft_real(dp);
	end;
	writeln('Each transform takes ',1.0*(clock_milliseconds-start_ms)/reps*us_per_ms:1:1,' us.');
	if num_outstanding_ptrs>0 then begin
		writestr(s,'Have ',num_outstanding_ptrs:1,
			' outsanding pointers after FFT tests.');
		print_error(s);
		num_outstanding_ptrs:=0;
	end;
{
	Test xy-graph generation and string interfaces.
}
	setlength(gpxy,gsize);
	for i:=0 to length(gpxy)-1 do begin
		gpxy[i].x:=i;
		gpxy[i].y:=i+1;
	end;
	writeln('Created and filled xy-graph of length ',gsize,' and length(gpxy)=',length(gpxy),'.');

	straight_line_fit(gpxy,slope,intercept,residual);
	writeln('slope=',slope:fsr:fsd,' intercept=',intercept:fsr:fsd,' residual=',residual:fsr:fsd);

	writeln('Translating gpxy into string with string_from_xy_graph ',reps:1,' times');
	start_ms:=clock_milliseconds;
	for i:=1 to reps do
		s:=string_from_xy_graph(gpxy);
	writeln('Each translation takes ',1.0*(clock_milliseconds-start_ms)/reps*us_per_ms:1:1,' us.');
		
	writeln('Translating string back into xy-graph with read_xy_graph ',reps:1,' times');
	start_ms:=clock_milliseconds;
	for i:=1 to reps do
		begin
			gxy:=read_xy_graph(s);
		end;
	writeln('Each translation takes ',1.0*(clock_milliseconds-start_ms)/reps*us_per_ms:1:1,' us.');

	gpxy:=read_xy_graph(s);
	writeln('Checking accuracy of translation from xy-graph to string and back.');
	good:=true;
	for i:=1 to gsize-1 do 
		if (gpxy[i].x<>i) then begin
			if good then begin
				writestr(s,'Point ',i:1,' x value ',gpxy[i].x:fsr:fsd,
				'in xy-graph translation');
				print_error(s);
			end;
			good:=false;	
		end else if (gpxy[i].y<>i+1) then begin
			if good then begin
				writestr(s,'Point ',i:1,' y value ',gpxy[i].y:fsr:fsd,
				'in xy-graph translation');
				print_error(s);
			end;
			good:=false;			
		end;
	if good then writeln('Translation accurate.');

	if num_outstanding_ptrs>0 then begin
		writestr(s,'Have ',num_outstanding_ptrs:1,
			' outsanding pointers after xy-graph to string tests.');
		print_error(s);
		num_outstanding_ptrs:=0;
	end;
{
	Test xyz-graph generation.
}
	setlength(gpxyz,gsize);
	for i:=0 to length(gpxyz)-1 do 
		with gpxyz[i] do begin
			x:=i;
			y:=i+1;
			z:=i+2;
	end;
	writeln('Created and filled xyz-graph of length ',gsize,
		' and length(gpxyz)=',length(gpxyz),'.');
{
	Speed of quicksort.
}
	writeln('Generating and sorting list of ',gsize,' random elements ',reps,' times.');
	setlength(gpx,gsize);
	start_ms:=clock_milliseconds;
	for j:=1 to reps do begin
		for i:=0 to length(gpx)-1 do
			gpx[i]:=random_0_to_1;
		x_graph_ascending(gpx);
	end;
	writeln('Each sort takes ',1.0*(clock_milliseconds-start_ms)/reps*us_per_ms:1:1,' us.');

	setlength(gpx,gsize*10);
	writeln('Generating and sorting list of ',gsize*10,' random elements ',reps div 10,' times.');
	start_ms:=clock_milliseconds;
	for j:=1 to (reps div 10) do begin
		for i:=0 to length(gpx)-1 do
			gpx[i]:=random_0_to_1;
		x_graph_ascending(gpx);
	end;
	writeln('Each sort takes ',1.0*(clock_milliseconds-start_ms)/(reps div 10)*us_per_ms:1:1,' us.');
{
	Math functions.
}
	fsd:=3;
	fsr:=7;
	writeln('Testing error function (x, erf):');
	for i:=0 to 4 do begin
		x:=1.0*i/10;
		writeln('',x:1:1,' ',error_function(x):fsr:fsd);
	end;
{
	Matrix generation and inversion.
}
	writeln('Generating matrices with random elements.');
	for n:=2 to msize do begin
		A:=new_matrix(n,n);
		for i:=1 to n do
			for j:=1 to n do
				A[j,i]:=random_0_to_1;
		writeln('New random square matrix:');
		write(string_from_matrix(A));
		writeln('Determinant: ',matrix_determinant(A):fsr:fsd);
		
		writeln('Inverse of random matrix:');
		B:=matrix_inverse(A);
		write(string_from_matrix(B));
		writeln('Determinant: ',matrix_determinant(B):fsr:fsd);

		writeln('Check inverse * original = unit matrix.');
		C:=matrix_product(A,B);
		
		good:=true;
		for i:=1 to n do
			if abs(1-C[i,i])>0.0001 then begin
				if good then begin
					writestr(s,'Diagonal element <> 1 during ',n:1,
						'-dimensional matrix inversion check.');
					print_error(s);
				end;
				good:=false;
			end;
	end;
	
	writeln('Performing ',mreps:1,' inversions of random ',
		tmsize:1,'*',tmsize:1,' matrices...');
	A:=new_matrix(tmsize,tmsize);
	start_ms:=clock_milliseconds;
	for n:=1 to mreps do begin
		for i:=1 to tmsize do
			for j:=1 to tmsize do
				A[j,i]:=random_0_to_1;
		B:=matrix_inverse(A);
	end;
	writeln('Each inversion takes ',1.0*(clock_milliseconds-start_ms)/mreps:1:1,' ms.');
{
	Test simplex fitter.
}
	fsr:=5;
	fsd:=2;
	writeln('Testing simplex fitter in ',xsize:1,' dimensions.');
	good:=true;
	start_ms:=clock_milliseconds;
	for j:=1 to xreps do begin
		simplex:=new_simplex(xsize);
		with simplex do begin
			for i:=1 to n do
				vertices[1,i]:=random_0_to_1*n;
			sv:=simplex_vertex_copy(vertices[1]);
			construct_size:=1.0;
			max_done_counter:=2;
		end;
		simplex_construct(simplex,simplex_error,ptr);

		repeat
			simplex_step(simplex,simplex_error,ptr);
		until (simplex.done_counter>=simplex.max_done_counter);

		if good then with simplex do begin
			for i:=1 to n do 
				if abs(vertices[1,i])>0.001 then 
					good:=false;
			if not good then begin
				writestr(s,'Convergeance failure on iteration ',j:1,'.');
				print_error(s);
			end;
			if (not good) or (j=xreps) then begin
				write('Initial: ');
				for i:=1 to n do
					write(sv[i]:fsr:fsd,' ');
				writeln;
				write('Final:   ');
				for i:=1 to n do
					write(simplex.vertices[1,i]:fsr:fsd,' ');
				writeln;
			end;
		end;
	end;
	writeln('Each fit takes ',1.0*(clock_milliseconds-start_ms)/xreps:1:1,' ms.');
{
	Report error string.
}
	writeln('After all these tests, the global error string is as follows:');
	writeln(error_string);
	error_string:='';
	writeln('End error string.');
	writeln('There are ',num_outstanding_ptrs,' pointers outstanding.');
{
	Test gui_writeln and gui_readln by substitution of writeln.
}
	writeln('Testing gui_writeln and gui_readln...');
	gui_writeln:=console_write;
	gui_readln:=console_read;
	gui_writeln('Hello from gui_writeln.');
	repeat
		s:=gui_readln('Enter a number or press return. ');
		writeln('You entered: "',s,'".');
		x:=real_from_string(s,good);
		if not good then writeln('Hey! That was not a number')
		else writeln('That was a real number.');
	until good;
end.
