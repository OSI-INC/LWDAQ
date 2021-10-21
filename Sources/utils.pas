{
Utilities for Mathematical Analysis
Copyright (C) 2004-2021 Kevan Hashemi, Brandeis University

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA	02111-1307, USA.
}

unit utils;
{
	utils contains general-purpose, platform-independent constants, types, and
	routines for use in our analysis library. All names in utils.pas must use
	full words separated by underscore characters, unless the a word has an
	abbreviation given in the list below, in which case the abbreviation must be
	used.

	Word			Abbreviation
	----------------------------
	address			addr
	number			num
	pointer			ptr
	handle			hdl
	increment		inc
	decrement		dec
		
	Routines that transform parameters from one form to another, or from one
	space to another use the name convention second_from_first(). We prefer this
	convention to the first_to_second convention because it makes assignment
	statements clearer. Consider i:=integer_from_real() as compared to
	i:=real_to_integer(). In the first case, reading left to right, we see that
	i will be assigned an integer value, and this value will be derived from a
	real number. In the second case we have to go back and forth across the name
	to make the same determination. Furthermore, we can concatinate the routines
	with others like this: i:=integer_from_real(real_from_string(s)) to create
	compound transformations, that are lear when read in either direction.
	
	Routines in our analysis library use the global error_string variable to
	record error messages using the report_error procedure. Only a main program
	body or a function declared in the main program may reset the error_string
	to the empty string. No routine outside the main program may make its
	execution conditional upon the state of the error_string. The main program
	might be something like p.pas, which compiles to a stand-alone
	console-executable program, or lwdaq.pas, which compiles to a shared
	library. The report_error routine will append error messages to the global
	error string when the global flag append_errors is true, otherwise it will
	over-write existing errors.

	The utils initialization routine is at the end of the implementation
	section. It initializes the random number generator and the gui (graphical
	user interface) procedure variables.

	In Pascal, the standard input and output channels are called "input" and
	"output". In C they are called "stdin" and "stdout". The readln routine can
	crash a program if the standard input channel is not available. If the
	standard output channel is not available, writeln output will be lost, or
	will cause the program to crash. Utils provides two global variables, 
	stdout_available and stdin_available to indicate whether these channels are 
	available or not. Utils routines will not attempt to use a channel if its 
	global availability variable is false.

	Utils provides a set global procedure variables: gui_draw, gui_support,
	gui_wait, gui_writeln, and gui_readln. Utils initializes these four
	procedural variables to default_gui_draw, etc. The graphical user interface
	assigns working procedures to the variables. After that, analysis code can
	interact with the graphical user interface using these procedure variables.

	Utils makes free use of FPC Pascal extensions. These extensions stand out in
	the code because they use capital letters instead of underscores to delimit
	phrases within their names.

	There are many Utils routines that use strings for input and output. These
	routines delete characters they passes over, just as if they were reading
	from a file, with the string acting as the file. As a routine writes, it
	appends to the end of the string. When Utils routines read from a string,
	they ignore characters within curly brackets. With curly brackets, you can
	embed comments in the strings read from and written to by utils routines.

	Utils provides a selection of routines that convert between strings and
	numbers, and visa versa. The procedures beginning with "write_" convert
	mathematical objects into strings and append them to a string. Functions
	beginning with "read_" read a numberical object from the beginning of a
	string and delete it from the string. Functions beginning with
	"string_from_" take a mathematical parameter and return a string. Functions
	ending with "from_string" convert a string into a mathematical object.

	For measuring execution time, Utils provides the start_time, mark_time, and
	report_time_marks routines. When you call start_time, you set a global
	timestamp. Subsequently, mark_time records elapsed time by subtracting the
	start_time from the current time. The routines create a list of elapsed time
	strings which you display later with report_time_marks. By this means, you
	do not slow down your execution with text display. The mark_time routine
	takes roughly 100 us to executte on a 1.3 GHz G4 iBook, so you can use it to
	measure execution times of 1 ms with good precision. That's not to say that
	the elapsed time measured by mark_time corresponds exactly to the time used
	by your process. We observe frequent jumps of tens of milliseconds. We
	believe these jumps are caused by the microprocessor switching to another
	task and then back again.
}

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}

interface

uses 
	sysutils;

{
	Ordinal types and their pointers. We define "integer" to be a 32-bit signed
	integer, which is "longint" in FPC. A "smallint" is a 16-bit signed integer,
	while a "smallint" is an 8-bit signed integer. A "shortcard" is an unsigned
	16-bit integer, which is "word" in FPC. The "qword" is the 64-bit cardinal,
	and "int64" is the 64-bit integer.
}
type
	integer=longint;
	shortcard=word;
	smallint_ptr=^smallint;
	integer_ptr=^integer;
	cardinal_ptr=^cardinal;
	qword_ptr=^qword;
	int64_ptr=^int64;
	byte_ptr=^byte;
	byte_hdl=^byte_ptr;

{
	The standard "real" is eight bytes long, while the "longreal" is ten bytes
	long. The longreal is called "extended" in FPC.
}
type
	real_ptr=^real;
	longreal=extended;
	longreal_ptr=^longreal;

{
	Mathematical constants for convenience and clarity of our code, including those for one
	half and one quarter.
}
const
	pi=3.1415926536;
	max_integer=$7FFFFFFF;
	max_smallint=$7FFF;
	max_shortcard=$FFFF;
	max_byte=$FF;
	one_half=0.5;
	one_quarter=0.25;
	one_eighth=0.125;
	integer_mask=$FFFFFFFF;
	smallint_mask=$0000FFFF;
	byte_mask=$000000FF;
	nibble_mask=$0000000F;
	small_real=1e-20;
	large_real=1e40;

{
	Math routines, including random number generator.
}
type 
	sinusoid_type=record
		amplitude,phase:real;
	end;	

procedure check_for_math_error(x:real);
function math_error(x:real):boolean;
function math_overflow(x:real):boolean;
function error_function(x:real):real;
function complimentary_error_function(x:real):real;
function gamma_function(z:real):real;
function chi_squares_distribution(sum_chi_squares:real;num_parameters:integer):real;
function chi_squares_probability(sum_chi_squares:real;num_parameters:integer):real;
function factorial(n:integer):real;
function full_arctan(a,b:real):real;
function sum_sinusoids(a,b:sinusoid_type):sinusoid_type;
function xpy(x,y:real):real;
function xpyi(x:real;y:integer):real;
function random_0_to_1:real;

{
	Conversion factors between units.
}
const 
	ms_per_s=1000;
	us_per_s=1000000;
	us_per_ms=1000;
	s_per_min=60;
	min_per_hr=60;
	hr_per_day=24;
	day_per_mo=30.44;
	mo_per_yr=12;
	rad_per_deg=pi/180;
	mrad_per_rad=1000;	
	urad_per_rad=1000000;
	um_per_mm=1000;
	um_per_cm=10000;
	mm_per_cm=10;
	um_per_m=1000000;
	decades_per_ln=0.4342944;
	mA_per_A=1000;
	one_percent=0.01;
	
{
	Debugging and Error Handling. We have routines to measure execution time, to
	write debug messages to a file on disk, and to keep track of pointers.
}
const 
	default_log_file_name='lwdaq_log.txt';
	max_num_time_marks=100;
	not_valid_code=-1;
	ignore_remaining_data=-1;

var 
	show_details:boolean=false;
	big_endian:boolean;
	stdout_available:boolean=true;
	stdin_available:boolean=true;
	num_outstanding_ptrs:integer=0;
	track_ptrs:boolean=false;
	append_errors:boolean=false;
	log_errors:boolean=false;
	debug_counter:integer=0;
	debug_string:string='';
	log_file_name:string;
	
procedure inc_num_outstanding_ptrs(size:integer;caller:string);
procedure dec_num_outstanding_ptrs(size:integer;caller:string);
procedure report_error(s:string);
procedure start_timer(id,caller:string);
procedure mark_time(id,caller:string);
procedure report_time_marks;
function clock_milliseconds:qword;

{
	Graphical User Interface. We don't implement any kind of graphical user
	interface in this unit, nor do we interact with the file system directly.
	Instead, we provide procedural variables like gui_writeln that our routines
	can call to write strings to the screen or files. We have dummy procedures
	that do nothing to act as place-holders for these procedures until the use
	assigns working procedures.
}
type
	gui_procedure_type=procedure(s:string);
	gui_function_type=function(s:string):string;
	
var
	gui_draw:gui_procedure_type;
	gui_support:gui_procedure_type;
	gui_wait:gui_procedure_type;
	gui_write:gui_procedure_type;
	gui_writeln:gui_procedure_type;
	gui_readln:gui_function_type;
	debug_log:gui_procedure_type;

procedure default_gui_draw(s:string); 
procedure default_gui_wait(s:string); 
procedure default_gui_write(s:string); 
procedure default_gui_writeln(s:string); 
function default_gui_readln(s:string):string;

{
	Graph Data Structures.
}
const
	num_x_dimensions=1;
	num_xy_dimensions=2;
	num_xyz_dimensions=3;

type 
	x_graph_type=array of real;
	x_graph_ptr=^x_graph_type;

	xy_point_type=record x,y:real; end;
	xy_point_ptr_type=^xy_point_type;
	xy_graph_type=array of xy_point_type;
	xy_graph_ptr=^xy_graph_type;

	xyz_point_type=record x,y,z:real; end;
	xyz_point_ptr_type=^xyz_point_type;
	xyz_graph_type=array of xyz_point_type;
	xyz_graph_ptr=^xyz_graph_type;
	
{
	One-Dimensional Graph Manipulation.
}
function average_x_graph(gp:x_graph_ptr):real;
function max_x_graph(gp:x_graph_ptr):real;
function min_x_graph(gp:x_graph_ptr):real;
function stdev_x_graph(gp:x_graph_ptr):real;
function mad_x_graph(gp:x_graph_ptr):real;
function median_x_graph(gp:x_graph_ptr):real;
function percentile_x_graph(gp:x_graph_ptr;percentile:real):real;
function coastline_x_graph(gp:x_graph_ptr):real;
function coastline_x_graph_progress(gp:x_graph_ptr):x_graph_type;
function spikes_x_graph(gp:x_graph_ptr; threshold:real; extent:integer):xy_graph_type;
function slope_x_graph(gp:x_graph_ptr;index,extent:integer):real;

{
	Two-Dimensional Graph Manipulation.
}
function average_xy_graph(gp:xy_graph_ptr):xy_point_type;
function stdev_xy_graph(gp:xy_graph_ptr):xy_point_type;
function average_y_xy_graph(gp:xy_graph_ptr):real;
function max_y_xy_graph(gp:xy_graph_ptr):real;
function min_y_xy_graph(gp:xy_graph_ptr):real;
function stdev_y_xy_graph(gp:xy_graph_ptr):real;
function coastline_xy_graph(gp:xy_graph_ptr):real;
function coastline_xy_graph_progress(gp:xy_graph_ptr):xy_graph_type;

{
	Matrix Manipulation and Inversion. We have a library of routines that allow
	us to create and manipulate matrices. We have two types of matrix: a dynamic
	matrix that can be of any dimension, and a static three-dimensional matrix
	that makes our geometry routines slightly more efficient and easy to write.

	Dynamic arrays in FPC have indices starting with 0, but we want to name the
	columns and rows of a matrix 1..n and 1..m. So we declare the matrix to be a
	two-dimensional dynamic array, but we will allocate n+1 rows and m+1
	columns, which will allow us to use an nxm subset of the (n+1)x(m+1)
	available elements. We won't use the 0th row or column. Our matrix_rows and
	matrix_columns routines return the number of rows and columns in a matrix to
	keep our code clean. The new_matrix routine takes the number of rows and
	columns and returns a pointer to the new matrix.

	In order for our three-dimensional fixed matrices to be compatible with our
	dynamic matrices, we have their indices begin at zero, even though we will
	not use the 0th row or column in any of our calculations.
}
type 
	matrix_type=array of array of real;
	xyz_matrix_type=array [0..num_xyz_dimensions,0..num_xyz_dimensions] of real;

var 
	matrix_determinant_saved:real=0;
	matrix_rank_saved:integer=0;

function new_matrix(num_rows,num_columns:integer):matrix_type;
function matrix_rows(var A:matrix_type):integer;
function matrix_columns(var A:matrix_type):integer;
function matrix_copy(var A:matrix_type):matrix_type;
function unit_matrix(num_rows:integer):matrix_type;
function matrix_product(var A,B:matrix_type):matrix_type;
function matrix_determinant(var A:matrix_type):real;
function matrix_difference(var A,B:matrix_type):matrix_type;
function matrix_inverse(var A:matrix_type):matrix_type;
procedure swap_matrix_rows(var M:matrix_type;row_1,row_2:integer);

{
	Simplex Steepest Descent Fitting. The algorithm adjusts one or more
	parameters so as to reduce an error function calculated from those
	parameters. Our implementation of the simplex algorithm for steepest descent
	fitting is orders of magnitude faster than a gradient-following algorithm.
	We perform fitting in n dimensions using a shape with n+1 vertices that
	steps through the n-dimensional space by reflecting the highest vertex of
	the shape through the hyper-plane made by the other vertices. Each vertex is
	an n-dimensional point, and the set of vertices contains n+1 points. The
	errors of the n+1 vertices are an array of real numbers. We refer to the
	vertices and real numbers by indices 1..n+1, and to the n coordinates as
	1..n. But the FPC dynamic arrays support only indices 0..n. So we will
	create dynamic arrays with zero elements that we don't use.
}
type 
	simplex_vertex_type = array of real;
	simplex_type = record 
		vertices:array of simplex_vertex_type; 
		errors:array of real; 
		construct_size:real; {length of sides for simplex construction}
		done_counter:integer; {counter used to detect convergance}
		max_done_counter:integer; {counter value at convergance, try 10}
		n:integer; {dimensions of the space}
	end;
	simplex_ptr=^simplex_type;
	simplex_error_function_type = 
		function(vertex:simplex_vertex_type;ep:pointer):real;

var
	simplex_enable_shrink:boolean=false;

function new_simplex(num_coords:integer):simplex_type;
procedure simplex_step(var simplex:simplex_type;
	error:simplex_error_function_type;
	ep:pointer);
function simplex_volume(var simplex:simplex_type):real;
function simplex_size(var simplex:simplex_type):real;
procedure simplex_construct(var simplex:simplex_type;
	error:simplex_error_function_type;
	ep:pointer);
function simplex_vertex_copy(var a:simplex_vertex_type):simplex_vertex_type;
	
{
	List Sorting. We provide generic sort algorithms. The fastest is quick_sort,
	except when the list is almost perfectly sorted, in which case bubble_sort
	can be faster. The sort routines allow for a list subset to be sorted, so we
	pass start and end indices into the routine to point to the first and last
	elements of the sublist that we must sort. We pass into the sort algorithm a
	procedure to swap two elements and a function to determine if one element is
	after another. The "swap" function and the "after" function receive the
	indices of the two elements that are to be swapped or compared, as well as a
	generic pointer that the function needs to access the list. To use the sort
	algorithm, we define sort and after routines, and pass these into the sort
	algorithm, along with the two indices and a generic pointer to the list
	structure. The after and swap routines know how to use the pointer to get to
	the list elements. The sort algorithm itself does not have to know anything
	about the structure of the list. When working with FPC, these sort and after
	routines must be global, because FPC is unable to pass local procedures as
	parameters.
}
type 
	sort_swap_procedure_type=procedure(a,b:integer;lp:pointer);
	sort_after_function_type=function(a,b:integer;lp:pointer):boolean;

procedure bubble_sort(a,b:integer;
	swap:sort_swap_procedure_type;
	after:sort_after_function_type;
	lp:pointer);
procedure quick_sort(a,b:integer;
	swap:sort_swap_procedure_type;
	after:sort_after_function_type;
	lp:pointer);
procedure x_graph_ascending(gp:x_graph_ptr);
procedure x_graph_descending(gp:x_graph_ptr);
procedure x_graph_ascending_abs(gp:x_graph_ptr);
procedure x_graph_descending_abs(gp:x_graph_ptr);
procedure x_graph_swap(a,b:integer;lp:pointer); 
function x_graph_gt(a,b:integer;lp:pointer):boolean;
function x_graph_lt(a,b:integer;lp:pointer):boolean;
function x_graph_gt_abs(a,b:integer;lp:pointer):boolean;
function x_graph_lt_abs(a,b:integer;lp:pointer):boolean;

{
	Line Fitting and Interpolation.
}
procedure straight_line_fit(dp:xy_graph_ptr;
	var slope,intercept,rms_residual:real);
procedure weighted_straight_line_fit (dp:xyz_graph_ptr;
	var slope,intercept,rms_residual:real);
procedure parabolic_line_fit(dp:xy_graph_ptr;
	var parabola,slope,intercept,rms_residual:real);
procedure linear_interpolate(dp:xy_graph_ptr;position:real;
	var result:real);
function nearest_neighbor(var point,lib:matrix_type):integer;

{
	Signal Processing.
}
function recursive_filter(x:x_graph_ptr;a_list,b_list:string):x_graph_type;
function glitch_filter(dp:x_graph_ptr;threshold:real):integer;
function glitch_filter_y(gp:xy_graph_ptr;threshold:real):integer;
function glitch_filter_xy(gp:xy_graph_ptr;threshold:real):integer;
procedure window_function(dp:x_graph_ptr;extent:integer);
procedure calculate_ft_term(period:real;
	var dp:x_graph_type;var amplitude,offset:real);
procedure frequency_component(frequency:real;
	var dp:x_graph_type;var amplitude,offset:real);
function fft(var dp:xy_graph_type):xy_graph_type;
function fft_inverse(var ft:xy_graph_type):xy_graph_type;
function fft_real(var dp:x_graph_type):xy_graph_type;
function fft_real_inverse(var ft:xy_graph_type):x_graph_type;

{
	Pixel Array Geometry. We provide routines for manipulating shapes in pixel
	arrays, where coordinates are row j and column i, which are always integers.
}
type
	ij_point_type=record i,j:integer; end;
	ij_point_ptr_type=^ij_point_type;
	ij_line_type=record a,b:ij_point_type; end;
	ij_line_ptr_type=^ij_line_type;
	ij_rectangle_type=record top,left,bottom,right:integer; end;
	ij_rectangle_ptr_type=^ij_rectangle_type;
	ij_ellipse_type=record a,b:ij_point_type; axis_length:real; end;
	ij_ellipse_ptr_type=^ij_ellipse_type;
	ij_graph_type=array  of ij_point_type;
	ij_graph_ptr_type=^ij_graph_type;

function ij_origin:ij_point_type;
function ij_axis_j:ij_line_type;
function ij_axis_i:ij_line_type;
function ij_separation(a,b:ij_point_type):real;
function ij_difference(a,b:ij_point_type):ij_point_type;
function ij_dot_product(a,b:ij_point_type):real;
procedure ij_clip_line(var line:ij_line_type;var outside:boolean;clip:ij_rectangle_type);
procedure ij_clip_rectangle(var rect:ij_rectangle_type;clip:ij_rectangle_type);
function ij_combine_rectangles(a,b:ij_rectangle_type):ij_rectangle_type;
function ij_line_crosses_rectangle(line:ij_line_type;rect:ij_rectangle_type):boolean;
function ij_line_line_intersection(l1,l2:ij_line_type):ij_point_type;
function ij_in_rectangle(point:ij_point_type;rect:ij_rectangle_type): boolean;	
function ij_random_point(rect:ij_rectangle_type):ij_point_type;

{
	Two-Dimensional Geometry.
}
type
	xy_line_type=record a,b:xy_point_type;end;
	xy_line_ptr_type=^xy_line_type;
	xy_rectangle_type=record top,left,bottom,right:real; end;
	xy_rectangle_ptr_type=^xy_rectangle_type;
	xy_ellipse_type=record a,b:xy_point_type; axis_length:real; end;
	xy_ellipse_ptr_type=^xy_ellipse_type;

function xy_difference(p,q:xy_point_type):xy_point_type;
function xy_dot_product(p,q:xy_point_type):real;
function xy_random:xy_point_type;
function xy_length(p:xy_point_type):real;
function xy_bearing(p:xy_point_type):real;
function xy_line_line_intersection(l1,l2:xy_line_type):xy_point_type;
function xy_origin:xy_point_type;
function xy_rotate(p:xy_point_type;r:real):xy_point_type;
function xy_scale(p:xy_point_type;scale:real):xy_point_type;
function xy_separation(p,q:xy_point_type):real;
function xy_sum(p,q:xy_point_type):xy_point_type;
function xy_unit_vector(p:xy_point_type):xy_point_type;
function xy_rectangle_ellipse(rect:xy_rectangle_type):xy_ellipse_type;

{
	Three-Dimensional Geometry.
}
type 
	xyz_line_type=record point,direction:xyz_point_type; end;
	xyz_line_ptr_type=^xyz_line_type;
	xyz_plane_type=record point,normal:xyz_point_type; end;
	xyz_plane_ptr_type=^xyz_plane_type;
	coordinates_type=record
		origin,x_axis,y_axis,z_axis:xyz_point_type;{a point and three unit vectors}
	end;
	kinematic_mount_type=record 
		cone,slot,plane:xyz_point_type;{ball centers}
	end;

function xyz_random:xyz_point_type;
function xyz_length(p:xyz_point_type):real;
function xyz_dot_product(p,q:xyz_point_type):real;
function xyz_cross_product(p,q:xyz_point_type):xyz_point_type;
function xyz_angle(p,q:xyz_point_type):real;
function xyz_unit_vector(p:xyz_point_type):xyz_point_type;
function xyz_scale(p:xyz_point_type;scale:real):xyz_point_type;
function xyz_sum(p,q:xyz_point_type):xyz_point_type;
function xyz_origin:xyz_point_type;
function xyz_difference(p,q:xyz_point_type):xyz_point_type;
function xyz_separation(p,q:xyz_point_type):real;
function xyz_z_plane(z:real):xyz_plane_type;
function xyz_transform(M:xyz_matrix_type;p:xyz_point_type):xyz_point_type;
function xyz_matrix_from_points(p,q,r:xyz_point_type):xyz_matrix_type;
function xyz_plane_plane_plane_intersection(p,q,r:xyz_plane_type):xyz_point_type;
function xyz_line_plane_intersection(line:xyz_line_type;plane:xyz_plane_type):xyz_point_type;
function xyz_plane_plane_intersection(p,q:xyz_plane_type):xyz_line_type;
function xyz_line_reflect(line:xyz_line_type;plane:xyz_plane_type):xyz_line_type;
function xyz_point_line_vector(point:xyz_point_type;line:xyz_line_type):xyz_point_type;
function xyz_line_line_bridge(p,q:xyz_line_type):xyz_line_type;
function xyz_point_plane_vector(point:xyz_point_type;plane:xyz_plane_type):xyz_point_type;
function xyz_matrix_determinant(A:xyz_matrix_type):real;
function xyz_matrix_inverse(A:xyz_matrix_type):xyz_matrix_type;
function xyz_matrix_difference(A,B:xyz_matrix_type):xyz_matrix_type;
function xyz_rotate(point,rotation:xyz_point_type):xyz_point_type;
function xyz_unrotate(point,rotation:xyz_point_type):xyz_point_type;

{
	Memory Access. We use byte arrays as a data structure for copying blocks of
	data from one place to another. We provide routines for reading and writing
	from memory locations, as well as reversing the byte order of multi-byte
	values.
}
type
	byte_array = array of byte;
	byte_array_ptr = ^byte_array;

function new_byte_array(size:integer):byte_array_ptr;
procedure dispose_byte_array(b:byte_array_ptr);
function check_big_endian:boolean;
function big_endian_from_local_smallint(i:smallint):smallint;
procedure block_clear(a:pointer;length:integer);
procedure block_fill(a:pointer;length:integer);
procedure block_set(a:pointer;length:integer;value:byte);
procedure block_move(a,b:pointer;length:integer);
function local_from_little_endian_smallint(i:smallint):smallint;
function local_from_big_endian_smallint(i:smallint):smallint;
function real_from_integer(i:integer):real;
function reverse_smallint_bytes(i:smallint):smallint;
function memory_byte(address:qword):byte;
function memory_smallint(address:qword):smallint;
function memory_integer(address:qword):integer;
function memory_qword(address:qword):qword;
procedure read_memory_byte(address:qword;var value:byte);
procedure read_memory_smallint(address:qword;var value:smallint);
procedure read_memory_integer(address:qword;var value:integer);
procedure read_memory_qword(address:qword;var value:qword);
procedure write_memory_byte(address:qword;value:byte);
procedure write_memory_smallint(address:qword;value:smallint);
procedure write_memory_integer(address:qword;value:integer);
procedure write_memory_qword(address:qword;value:qword);

{
	String Testing, Formatting, and Translating. When we print numbers to strings, we
	allow a total of "fsr" spaces for the number and "fsd" spaces after the decimal point.
	But if the number requires more space for the digits to the left of the decimal point,
	the additional digits will be printed anyway.
}
const
	wild_char='?';
	wild_string='*';
	true_chars:set of char = ['y','Y','t','T','1'];
	false_chars:set of char = ['n','N','f','F','0'];
	file_name_separators:set of char = [':','/','\'];
	separator_chars:set of char = ['{','}',' ',',',chr(13),chr(10),chr(9)];
	start_comment_chars:set of char = ['{'];
	end_comment_chars:set of char = ['}'];
	true_string='1';
	false_string='0';
	null_code='_null_code_';
	error_prefix='ERROR: ';
	null_char=chr(0);
	crlf=chr(13)+chr(10);
	tab=chr(9);
	hex_digits_per_byte=2;
	short_string_length=2000;
	long_string_length=300000;

var
	eol:string[10]=chr(10);
	error_string:string='';
	fsr:integer=1;
	fsd:integer=6;

function alphabet_char(c:char):boolean;
function alphanumeric_char(c:char):boolean;
function strings_in_order(a,b:string):boolean;
function string_match(key,subject:string):boolean;
function string_checksum(s:string):integer;
function string_from_x_graph(var gp:x_graph_type):string;
function string_from_xy_graph(var gp:xy_graph_type):string;
function digit_from_char(c:char):integer;
function char_from_digit(digit:integer):char;
function boolean_from_string(s:string):boolean;
function cardinal_from_hex_string(s:string):cardinal;
function qword_from_hex_string(s:string):qword;
function integer_from_string(s:string;var okay:boolean):integer;
function decimal_from_string(s:string;base:integer):integer;
function real_from_string(s:string;var okay:boolean):real;
function xy_from_string(s:string):xy_point_type;
function xyz_from_string(s:string):xyz_point_type;
function xyz_line_from_string(s:string):xyz_line_type;
function xyz_plane_from_string(s:string):xyz_plane_type;
function kinematic_mount_from_string(s:string):kinematic_mount_type;
function string_from_boolean(value:boolean):string;
function string_from_integer(value,fsi:integer):string;
function sfi(value:integer):string;
function string_from_real(value:real;field_width,decimal_places:integer):string;
function string_from_decimal(decimal_number:integer;base,num_digits:integer):string;
function hex_string_from_qword(number:qword):string;
function hex_string_from_cardinal(number:cardinal):string;
function hex_string_from_byte(number:byte):string;
function string_from_ij(p:ij_point_type):string;
function string_from_xy(p:xy_point_type):string;
function string_from_xyz(p:xyz_point_type):string;
function string_from_xyz_line(l:xyz_line_type):string;
function string_from_xyz_plane(p:xyz_plane_type):string;
function upper_case(s:string):string;
function lower_case(s:string):string;
function strip_folder_name(s:string):string;
function strip_spaces(s:string):string;
function strip_separators(s:string):string;
function delete_substring(s:string;index,count:integer):string;
function delete_to_mark(s:string;mark:char):string;
function no_marks_left(s:string; mark:char):boolean;
function word_count(var s:string):integer;
function read_word(var s:string):string;
function read_boolean(var s:string):boolean;
function read_real(var s:string):real;
function read_integer(var s:string):integer;
function read_xy(var s:string):xy_point_type;
function read_xyz(var s:string):xyz_point_type;
function read_x_graph(var s:string):x_graph_type;
function read_xy_graph(var s:string):xy_graph_type;
procedure read_matrix(var s:string;var M:matrix_type);
function read_kinematic_mount(var s:string):kinematic_mount_type;
procedure write_ij(var s:string;p:ij_point_type);
procedure write_xy(var s:string;p:xy_point_type);
procedure write_xyz(var s:string;p:xyz_point_type);
procedure write_xyz_line(var s:string;l:xyz_line_type);
procedure write_xyz_plane(var s:string;p:xyz_plane_type);
procedure write_xyz_matrix(var s:string;M:xyz_matrix_type);
procedure write_memory_map(var s:string;base:qword;size:integer);
procedure write_matrix(var s:string;var M:matrix_type);
function string_from_matrix(var M:matrix_type):string;
procedure write_kinematic_mount(var s:string;mount:kinematic_mount_type);


implementation

{
	Execution timer variables. We use these with start_timer and mark_time to
	generate timing for execution of routines with a precision of one
	millisecond.
}
var
	start_time_ms:comp; 
	mark_time_list:array [0..max_num_time_marks] of string;
	mark_time_index:integer=0;

{
	Math error detection routines.
}
procedure check_for_math_error(x:real);
var s,w:string;
begin
	writestr(s,x);
	w:=read_word(s);
	if (w='+Inf') or (w='-Inf') or (w='NaN') then 
		report_error('Real number with value "'+w+'".');
end;

function math_error(x:real):boolean;
var s,w:string;
begin
	writestr(s,x);
	w:=read_word(s);
	if (w='Inf') or (w='-Inf') or (w='NaN') then 
		math_error:=true
	else 
		math_error:=false;
end;

function math_overflow(x:real):boolean;
begin
	if math_error(x) then 
		math_overflow:=true
	else if (abs(x)>large_real) or (abs(x)<small_real) then
		math_overflow:=true
	else 
		math_overflow:=false;
end;

{
	full_arctan calculates the arctangent of a/b, giving an answer between -pi and 
	+pi radians.
}
function full_arctan(a,b:real):real;
var
	phase:real=0;
begin
	if (b=0) and (a=0) then phase:=0;
	if (b=0) and (a>0) then phase:=pi/2;
	if (b=0) and (a<0) then phase:=3*pi/2;
	if (b>0) and (a>=0) then phase:=arctan(a/b);
	if (b<0) and (a>=0) then phase:=pi-arctan(-a/b);
	if (b<0) and (a<0) then phase:=pi+arctan(a/b);
	if (b>0) and (a<0) then phase:=2*pi-arctan(-a/b);
	if phase>pi then phase:=phase-2*pi;
	if phase<-pi then phase:=phase+2*pi;
	full_arctan := phase;
end;
{
	sum_sinusoids adds two sinusoids of the same frequency but differing phase and
	amplitude.
}
function sum_sinusoids(a,b:sinusoid_type):sinusoid_type;
var
	p,q:real;
	sum:sinusoid_type;
begin
	p:=a.amplitude + b.amplitude*cos(b.phase-a.phase);
	q:=b.amplitude*sin(b.phase-a.phase);
	sum.amplitude:=sqrt(p*p+q*q);
	sum.phase:=full_arctan(q,p);
	sum_sinusoids:=sum;
end;

{
	xpy returns x to the power y.
}
function xpy(x,y:real):real;

begin
	xpy:=0;
	if (x<0) then begin
		report_error('x<0 in xpy');
	end;
	if (x>0) then begin
		if y<>0 then xpy:=exp(ln(x)*y)
		else xpy:=1;
	end;
end;

{
	xpy is the same as xpy, but y is an integer greater than or equal to zero.
}
function xpyi(x:real;y:integer):real;
var i:integer;z:real;
begin
	z:=1;
	for i:=1 to abs(y) do z:=z*x;
	if y<0 then xpyi:=1/z else xpyi:=z;
end;{function xpy}

{
	factor_16 returns 16 to the power x
}
function factor_16(x:integer):qword;

var
	i:integer;
	y:qword;

begin
	y:=1;
	for i:=1 to x do y:=y*16;
	factor_16:=y;
end;

{
	factorial calculates n!.
}
function factorial(n:integer):real;

var
	i:integer;
	product:real;
	
begin
	product:=1;
	for i:=2 to n do product:=product*i;
	factorial:=product;
end;

{
	error_function calculates the error function, the integral from zero to u of
	2/sqrt(pi)*exp(-x*x) with respect to x, by using an approximate series
	expansion. We calculate the series expansion efficiently using the method
	described to us by Harley Flanders. The routine is accurate to ten decimal
	places for 0 < u < 4 and runs in 20 us on a 1-GHz iBook G4. 
	
	The series expansion is:
	
	erf(x) = 2/sqrt(pi) * sum(n=0 to max_n) of (-1)^n * x^(2n+1) / (2n+1)n! 
		= sum(n=0 to max_n) of T(n)
	
	Each term for n>=1 is related to the previous term by:
	
	T(n) = T(n-1) * -1 * x * x * (2n-1) / (2n+1)n
	
	We proceed from n=1 to max_n by adding the previous term multiplied by the above
	factor to our sum.
}
function error_function(x:real):real;

const
	max_n=100;
	
var
	n:integer;
	sum,term:real;
	
begin
	if (x<0) then begin
		error_function:=0;
		exit;
	end;
	
	term:=x;
	sum:=x;
	for n:=1 to max_n do begin
		term:=term*(-1.0)*x*x*(2*n-1.0)/(2.0*n+1)/n;
		sum:=sum+term;
	end;
	error_function:=sum*2/sqrt(pi);
end;

{
	complimentary_error_function calculates the complimentary error function, which is 1 - erf.
}
function complimentary_error_function(x:real):real;
begin complimentary_error_function:=1-error_function(x); end;

{
	gamma_function uses a version of the Lanczos Approximation we found here:
	
	http://www.rskey.org/gamma.htm
	
	The routine is accurate to six significant figures for z<10 and takes 10 us on
	a 1 GHz G4 laptop. Thanks to Harley Flanders for pointing out this routine to
	us. 
}
function  gamma_function(z:real):real;

const
	max_index=6;
	coefficients:array[0..max_index] of real =
		(75122.6331530,80916.6278952,36308.2951477,8687.24529705,
		1168.92649479,83.8676043424,2.50662827511);

var
	sum,product:real;
	n:integer;
	
begin
	gamma_function:=0;
	if z>0 then begin
		sum:=0;
		for n:=0 to max_index do
			sum:=sum+coefficients[n]*xpy(z,n);
		product:=1;
		for n:=0 to max_index do 
			product:=product*(z+n);
		gamma_function:=sum/product*xpy(z+5.5,z+0.5)*exp(-z-5.5);
	end;
	if z<0 then begin
		gamma_function:=-pi/(-z*gamma_function(-z)*sin(-pi*z));
	end;
	if z=0 then begin
		gamma_function:=0;
	end;
end; 

{
	chi_squares_distribution gives the value of the sum of chi squares
	distribution for a fit with the specified number of parameters, at your 
	specified value of sum of chi squares. Because the function is a ratio
	of two terms that both become very large with large sum_chi_square and
	num_paramters, we calculate it in steps, so that we keep a running ratio
	that is manageable. A one-step calculation would look like this:

	chi_squares_distribution := 	
		xpy(sum_chi_squares,num_parameters/2 - 1)
			*exp(-sum_chi_squares/2)
			/xpy(2,num_parameters/2)
			/gamma_function(num_parameters/2);

	The exponents are all terms in half of the two parameters, so in our routine
	we work with half-values of the parameters, decrementing each by 1 until it
	drops below our threshold. After that, we implement the above formula on the
	remaining factors.
}
function chi_squares_distribution(sum_chi_squares:real;num_parameters:integer):real;

const
	np2_min=2;
	ncs2_min=2;
	max_d=100000000000;
	min_d=0.0000000001;
	
var
	d:real;
	ncs2,np2:real;
	e:real;
	counter,max_counter:integer;
	
begin
	if num_parameters<=0 then d:=0
	else if sum_chi_squares<0 then d:=1
	else begin
		max_counter:=num_parameters+round(sum_chi_squares);
		e:=exp(1);
		d:=1;
		ncs2:=sum_chi_squares/2;
		np2:=num_parameters/2;
		counter:=0;
		while (ncs2>ncs2_min) or (np2>np2_min) do begin
			if (np2>np2_min) and (d<max_d) then begin
				d:=d*sum_chi_squares/2/(np2-1);
				np2:=np2-1;
			end;
			if (ncs2>ncs2_min) and (d>min_d) then begin
				d:=d/e;
				ncs2:=ncs2-1;
			end;
			inc(counter);
			if counter>max_counter then break;
		end;
		if counter<max_counter then
			d:=d*xpy(sum_chi_squares,np2 - 1)
				*exp(-ncs2)
				/xpy(2,np2)
				/gamma_function(np2)
		else d:=0;
	end;
	
	check_for_math_error(d);
	chi_squares_distribution:=d;
end;

{
	chi_squares_probability returns the probability that the sum of chi squares
	from a fit with num_parameters parameters will exceed sum_chi_squares. We
	integrate the chi squares distribution to obtain our answer, which avoids
	using multiple-approximations. For num_parameters=1, the distribution tends
	to infinity as sum_chi_squares tends to zero. You could use the exact error
	function solution for num_parameters=1, like this:

	probability:=complimentary_error_function(sqrt(sum_chi_squares*one_half))

	We could include such an option in our routine, but we don't. Instead, we go
	through some effort to integrate the chi squares distribution in the
	neighborhood of zero, and so obtain an approximation of the complimentary
	error function that is accurate to better than 1% all the way down to
	sum_chi_squares=0. For num_parameters>1, the distribution is finite at zero,
	and for large num_parameters, its value at zero becomes insignificant
	compared to the peak of the distribution, which occurs somewhere in the
	neighborhood of sum_chi_squares = num_parameters. As num_parameters
	increases, this peak becomes narrower. Our numerical integration of the
	distribution tries to be efficient about its choice of step size and the
	interval of sum_chi_squares over which it operates. The distribution
	calculation time increases with num_parameters, while at the same time its
	peak becomes narrower in proportion to the value of its center
	sum_chi_squares. We reduce the integration time by paying particular
	attention to integrating throughout the peak, and not elsewhere. This we do
	by checking if sum_chi_squares is less than num_parameters. If it is, then
	we first integrate the distribution from sum_chi_squares = num_paramters
	until the incremental additions we are making to the integral with each step
	fall below stop_element. We go back and integrate downwards from
	num_parameters to sum_chi_squares. If the elements are smaller than
	stop_element, then we stop. In the case of num_parameters=1, and
	sum_chi_squares=0, we start reducing the step size by asymptotic_factor as
	we approach zero, and stop only when the incremental additions drop below
	stop_element. We are able to use sum_chi_squares = num_parameters as a
	starting point because we are certain that for all values of num_paramters,
	the value of the distribution returned by our distribution routine is
	greater than 10% of its peak value. We have tested this for values of
	num_parameters up to ten million. If sum_chi_squares is greater than
	num_parameters, all we do is integrate from sum_chi_squares up, until the
	elements are smaller than stop_element.

	We can test the performance of the integration for num_parameters=1 by
	comparing it to the complimentary error function. We can test it for
	num_parameters>1 by setting sum_chi_squares to zero. The intergral should
	come up with probability 1.000. For num_parameters ranging from one to one
	million, we find the integral is accurate to better than 1%.
	
	When num_paramters is one million and sum_chi_squares is zero, the integral
	execution time is roughly 600 ms on a 1-GHz G4, and it comes up with the
	answer 0.9996. For num_parameters one thousand, and sum_chi_squares zero,
	the execution time drops to 2.5 ms.
}
function chi_squares_probability(sum_chi_squares:real;num_parameters:integer):real;

const
	x_step_factor=0.1;
	stop_element=0.0001;
	asymptotic_fraction=0.5;
	step_exponent=0.7;
	
var
	integral,x,x_step,csd,element:real;

	procedure show(s:string);
	var m:string;
	begin
		if show_details then begin
			writestr(m,x:1:3,' ',x_step:1:3,' ',csd:1:9,' ',
				element:1:9,' ',integral:1:9,' ',s);
			gui_writeln(m);
		end;
	end;
	
begin
	integral:=0;
	if (num_parameters <= 0) or (sum_chi_squares < 0) then integral:=0
	else begin
		x_step:=xpy(num_parameters,step_exponent)*x_step_factor;
		if sum_chi_squares<num_parameters then begin
			x:=num_parameters;
			repeat
				csd:=chi_squares_distribution(x+x_step*one_half,num_parameters);
				element:=x_step*csd;
				integral:=integral+element;
				show('Up from center.');
				x:=x+x_step;
			until element<stop_element;	
			x:=num_parameters;
			repeat
				csd:=chi_squares_distribution(x-x_step*one_half,num_parameters);
				element:=x_step*csd;
				integral:=integral+element;
				show('Down from center.');
				x:=x-x_step;
			until (x-x_step<sum_chi_squares+x_step) or (element<stop_element);
			if (element>stop_element) then begin
				repeat
					x_step:=asymptotic_fraction*(x-sum_chi_squares);
					csd:=chi_squares_distribution(x-x_step*one_half,num_parameters);
					element:=csd*x_step;
					integral:=integral+element;
					show('Asymptotic to end.');
					x:=x-x_step;
				until element<stop_element;
			end;
		end else begin
			x:=sum_chi_squares;
			repeat
				csd:=chi_squares_distribution(x+x_step*one_half,num_parameters);
				element:=csd*x_step;
				integral:=integral+element;
				show('Up from sum_chi_squares.');
				x:=x+x_step;
			until element<stop_element;
		end;
	end;
		
	chi_squares_probability:=integral;
	check_for_math_error(integral);
 end;

{
	delete_substring creates a new string by deleting count characters
	from a string starting at character index.
}
function delete_substring(s:string;index,count:integer):string;
begin
	delete(s,index,count);
	delete_substring:=s;
end;

{
	char_from_digit converts a number into a character 0..9 or A..Z.
}
function char_from_digit(digit:integer):char;

const
	max_for_decimal_digit=9;
	max_digit=26+9;

begin
	if(digit>max_digit) or(digit<0) then digit:=0;
	if digit in [0..max_for_decimal_digit] then char_from_digit:=chr(ord('0')+digit)
	else char_from_digit:=chr(ord('A')+digit-max_for_decimal_digit-1);
end;

{
	digit_from_char converts a character into a number 0..35.
}
function digit_from_char(c: char): integer;

const
	invalid_digit=-1;

var
	x:integer;

begin
	x:=invalid_digit;
	if(ord(c)>=ord('0')) and(ord(c)<=ord('9')) then x:=ord(c)-ord('0');
	if(ord(c)>=ord('A')) and(ord(c)<=ord('F')) then x:=ord(c)-ord('A')+10;
	if(ord(c)>=ord('a')) and(ord(c)<=ord('f')) then x:=ord(c)-ord('a')+10;
	digit_from_char:= x;
end;

{
	hex_string_from_cardinal takes a 32-bit unsigned integer and converts it into 
	a hex string eight digits long.
}
function hex_string_from_cardinal(number:cardinal):string;

const
		size=hex_digits_per_byte*sizeof(cardinal);
		
var
	line:string[size];
	digit:integer;

begin 
	line:=char_from_digit(number div factor_16(size-1));
	for digit:=size-1 downto 1 do
		line:=line+char_from_digit((number mod factor_16(digit)) div factor_16(digit-1));
	hex_string_from_cardinal:= line;
end;

{
	hex_string_from_qword takes a 64-bit unsigned integer and converts it into 
	a hex string sixteen digits long.
}
function hex_string_from_qword(number:qword):string;

const
	size=hex_digits_per_byte*sizeof(qword);
		
var
	line:string[size];
	digit:integer;

begin 
	line:='';
	line:=char_from_digit(number div factor_16(size-1));
	for digit:=size-1 downto 1 do
		line:=line+char_from_digit((number mod factor_16(digit)) div factor_16(digit-1));
	hex_string_from_qword:=line;
end;

{
	qword_from_hex_string takes a hex string, which may or may not have a
	leading '$' character, and turns it into an 64-bit cardinal, or qword.
	If any one of the characters, after the leading space and '$' character, is
	not a hex character, then we return zero.
}
function qword_from_hex_string(s:string):qword;

const
	max_size=16;

var
	index: integer;
	value: qword;
	valid: boolean;
	digit: integer;

begin 
	while(s[1]=' ') or(s[1]='$') do delete(s,1,1);
	value:=0;	
	valid:=true;
	if length(s)<=max_size then begin
		for index:=1 to length(s) do begin
			digit:=digit_from_char(s[index]);
			value:=value+digit*factor_16(length(s)-index);
			if digit<0 then valid:=false;
		end;
	end;
	if valid then qword_from_hex_string:=value
	else qword_from_hex_string:=0;
end;

{
	cardinal_from_hex_string is the 32-bit version of qword_from_hex_string.
}
function cardinal_from_hex_string(s:string):cardinal;

const
	max_size=8;
	convert=$100000000;

var
	value: qword;

begin 
	value:=qword_from_hex_string(s);
	cardinal_from_hex_string:=value div convert;
end;

{
	hex_string_from_byte converts a byte into a string of two hex(base-sixteen) characters.
}
function hex_string_from_byte(number:byte):string;

const
		size=hex_digits_per_byte*sizeof(byte);
		
var
	line:string[size];
	digit:integer;

begin 
		line:=char_from_digit(number div factor_16(size-1));
		for digit:=size-1 downto 1 do
			line:=line+char_from_digit((number mod factor_16(digit)) div factor_16(digit-1));
		hex_string_from_byte:=line;
end;

{
	string_from_decimal converts a positive decimal number to a string of num_digits 
	characters representing its value in base 'base'.
}
function string_from_decimal(decimal_number:integer;base,num_digits:integer):string;
	
const
	mask=$7FFFFFFF;
	max_num_digits=32;
	max_base=1000000;
	default_base=10;
	
var
	digit_string:string[max_num_digits];
	index:integer;
	
begin 
	decimal_number:=decimal_number and mask;
	
	if (num_digits>max_num_digits) or (num_digits<1) then 
		num_digits:=max_num_digits;
	
	if (base<0) or (base>max_base) then 
		base:=default_base;
	
	digit_string:='';	
	for index:=1 to num_digits do begin 
		digit_string:=
			char_from_digit(decimal_number mod base)
			+digit_string;
		decimal_number:=decimal_number div base;
	end;

	string_from_decimal:=digit_string;
end;

{
	decimal_from_string does the opposite of string_from_decimal: it converts a string 
	expressing a number in a specified base into a decimal integer.
}
function decimal_from_string(s:string;base:integer):integer;

var
	index: integer;
	x: integer;

	function factor(x: integer): integer;
	var
		i: integer;
		y: integer;
	begin
		y := 1;
		for i := 1 to x do y := y * base;
		factor := y;
	end;
	
begin 
	x := 0;
	for index := 1 to length(s) do
		x := x + digit_from_char(s[index])
					*factor(length(s) - index);
	decimal_from_string := x;
end;

{
	string_from_real takes a real number and turns it into an ascii string of length
	field_width and allowing decimal_places digits after the decimal point.
}
function string_from_real(value:real;field_width,decimal_places:integer):string;

const
	max_field_width=10;
	base=10;
	failure_string='NaN ';
	
var
	s:string;
	digit_num,top_digit_num,bottom_digit_num,digit:integer;
	leading_zeros,negative:boolean;
	
begin
	s:='';

	top_digit_num:=max_field_width;
	
	negative:=(value<0);
	if negative then begin
		value:=-value;
		dec(top_digit_num)
	end;
	
	if (decimal_places>0) then top_digit_num:=top_digit_num-decimal_places;
	bottom_digit_num:=-decimal_places;

	if (top_digit_num<=bottom_digit_num) then begin
		string_from_real:=failure_string;
		report_error('Invalid field sizes in string_from_real.');
		exit;
	end;

	while (trunc(value/xpyi(base,top_digit_num))>=base) 
			and (top_digit_num<max_field_width) do
		inc(top_digit_num);
	
	leading_zeros:=true;
	value:=value+xpy(base,bottom_digit_num-1);
	for digit_num:=top_digit_num downto bottom_digit_num do begin
		if digit_num=-1 then s:=s+'.';
		digit:=trunc(value/xpy(base,digit_num));
		if (digit>0) or (digit_num<1) then leading_zeros:=false;
		if not leading_zeros then s:=s+char_from_digit(digit);
		value:=value-digit*xpyi(base,digit_num);
	end;
	
	if negative then s:='-'+s;
	while(length(s)<field_width) do s:=' '+s;
	string_from_real:=s;
end;

{
	string_from_integer takes an integer and turns it into an ascii string fsi characters long.
}
function string_from_integer(value,fsi:integer):string;

const
	max_fsi=20;
	
var
	s:string;
	fsr:integer;
	
begin
	if((fsi<=1) or(fsi>=max_fsi)) then fsr:=max_fsi
	else fsr:=fsi;
	s:=string_from_real(value,fsr,0);
	if(fsi<=1) then s:=strip_spaces(s);
	string_from_integer:=s;
end;

{
	sfi calls string_from_integer with field size one. This routine is intended
	for use wth debug_log where we are preparing debugging messages that will be
	written to disk, and the debugging lines are temporary additions to the code
	that we would like to be quick to type. In permanent code, we use
	string_from_integer, because its function is obvious from the name.
}
function sfi(value:integer):string;
begin
	sfi:=string_from_integer(value,1);
end;

{
	real_from_string takes a string and interprets it as a real number. If it
	cannot make a real number out of the string, the routine returns zero and
	appends an error string to the global error_string. If you pass the routine
	an empty string, it returns the value zero but does not generate an error.
	Whenever it fails to read a real number, the routine returns okay set to
	false.
}
function real_from_string(s:string;var okay:boolean):real;

const
	max_exponent=99;

type
	states=(start,preamble,int,dec,separator,exponent,done,fail,quit);

var
	state:states;
	places:integer=0;
	index:integer=0;
	sign: -1..1 =0;
	power:integer=0;
	value:real=0;

begin
	okay:=true;
	state:=start;
	repeat
		case state of
			start:begin
				index:=1;value:=0;places:=0;sign:=+1;power:=0;
				if length(s)<>0 then state:=preamble
				else state:=fail;
			end;

			preamble:begin
				case s[index] of
					'0','1','2','3','4','5','6','7','8','9':state:=int;
					'-':begin index:=index+1;sign:=-1*sign;state:=preamble;end;
					'+',' ':begin index:=index+1;state:=preamble;end;
					'.':begin index:=index+1;state:=dec;end;
					else state:=fail;
				end;
			end;

			int:begin
				if index>length(s) then state:=done
				else case s[index] of
					'0','1','2','3','4','5','6','7','8','9':begin
						value:=value*10+sign*(ord(s[index])-ord('0'));
						index:=index+1;state:=int;
					end;
					'.':begin index:=index+1;state:=dec;end;
					'e','E':begin index:=index+1;state:=separator;sign:=+1;end;
					',',' ':state:=done
					else state:=fail;
				end;
			end;

			dec:begin
				if(index>length(s)) then state:=done
				else case s[index] of
					'0','1','2','3','4','5','6','7','8','9':begin
						places:=places+1;
						value:=value+
						sign*(ord(s[index])-ord('0'))/xpy(10,places);
						index:=index+1;state:=dec;
						end;
					'e','E':begin index:=index+1;state:=separator;sign:=+1;end;
					',',' ':state:=done
					else state:=fail;
				end;
			end;

			separator:begin
				case s[index] of
					'0','1','2','3','4','5','6','7','8','9':state:=exponent;
					'-':begin index:=index+1;sign:=-1*sign;state:=separator;end;
					'+':begin index:=index+1;state:=separator;end;
					' ':begin index:=index+1;state:=separator;end
					else state:=fail;
				end;
			end;

			exponent:begin
				if index>length(s) then state:=done
				else case s[index] of
					'0','1','2','3','4','5','6','7','8','9':begin
						power:=power*10+sign*(ord(s[index])-ord('0'));
						index:=index+1;state:=exponent;
					end;
					' ',',':state:=done
					else state:=fail;
				end;
			end;

			done:begin
				if abs(power)>=max_exponent then state:=fail
				else begin
					if power>0 then for places:=1 to power do value:=value*10;
					if power<0 then for places:=-1 downto power do value:=value/10;
					state:=quit;
				end;
			end;

			fail:begin 
				okay:=false;
				state:=quit;
				if s<>'' then
					report_error('Invalid string "'+s+'" in real_from_string.');
			end;
		end;{case state of}
	until state=quit;

	if okay then real_from_string:=value
	else real_from_string:=0;
end;

{
	integer_from_string takes a string and interprets it as an integer. If it cannot
	make an integer out of the string, the routine returns zero and sets the okay
	flag to false. Instead of objecting to a fractional real number, we simply round
	it off to the nearest integer and pass that number back.
}
function integer_from_string(s:string; var okay:boolean):integer;

begin
	integer_from_string:=round(real_from_string(s,okay));
end;

{
	boolean_from_string takes a string and determines if it indicates boolean
	true or boolean false. The default value is false, except in the case of
	passing an empty string to the routine, in which case boolean_from_string
	returns true. We return true for empty strings so that an empty value string
	associated with an option in a command line will return true, to set the
	boolean option instead of clear it. If the string is not a boolean string,
	we don't issue and error or set an error flag. We just set the result to
	false.
}
function boolean_from_string(s:string):boolean;

var 
	value,okay:boolean;
	i:integer;
	
begin
	value:=false;
	if s<>'' then begin
		if s[1] in true_chars then value:=true
		else if not (s[1] in false_chars) then begin
			i:=integer_from_string(s,okay);
			if okay then value:=(i<>0);
		end;
	end else value:=true;
	boolean_from_string:=value;
end; 

{
	string_from_boolean takes a boolean and returns a string naming its value.
}
function string_from_boolean(value:boolean):string;
begin
	if value then string_from_boolean:=true_string
	else string_from_boolean:=false_string;
end;

{
	read_word is the basis of all the utils file-like string read routines.
	It extracts the first word from s and returns the word. At the same time,
	read_word deletes the word from s, as well as any charcters it has skipped
	over while extracting the word. Note that read_word returns a string_type,
	which can then be used by other routines like boolean_from_string.
}
function read_word(var s:string):string;

var
	word:string;
	index:integer;
	comment,go:boolean;
	
begin
	word:='';
	read_word:=word;
	if s='' then exit;
	
	index:=0;
	comment:=false;
	go:=true;
	while go do begin
		inc(index);
		if index>length(s) then break;
		if (s[index] in start_comment_chars) then comment:=true;
		if (s[index] in end_comment_chars) then comment:=false;
		if (not comment) and (not (s[index] in separator_chars)) then go:=false;
	end;
	while (index<=length(s)) and (not (s[index] in separator_chars)) do begin
		word:=word+s[index];
		inc(index);
	end;
	delete(s,1,index-1);
	read_word:=word;
end;

{
	word_count returns the number of words in a string.
}
function word_count(var s:string):integer;

var
	i,count:integer;
	in_word:boolean;
	
begin
	if length(s)=0 then begin
		word_count:=0;
		exit;
	end;
	
	in_word:= not (s[1] in separator_chars);
	if in_word then count:=1 else count:=0;

	for i:=2 to length(s) do begin
		if (s[i] in separator_chars) then begin
			in_word:=false;		
		end else begin
			if not in_word then begin
				in_word:=true;
				inc(count);
			end;
		end;
	end;
	word_count:=count;
end;

{
	The following read_* functions read things out of a string and delete them 
	as they go. We don't report anything if we fail to read the correct variable 
	type, but the global error_message will be set to indicated such a failure.
}
function read_real(var s:string):real;
var okay:boolean;
begin
	read_real:=real_from_string(read_word(s),okay);
end;

function read_xy(var s:string):xy_point_type;
var p:xy_point_type;
begin
	with p do begin
		x:=read_real(s);
		y:=read_real(s);
	end;
	read_xy:=p;
end;

function read_xyz(var s:string):xyz_point_type;
var p:xyz_point_type;
begin
	with p do begin
		x:=read_real(s);
		y:=read_real(s);
		z:=read_real(s);
	end;
	read_xyz:=p;
end;

function read_integer(var s:string):integer;
var okay:boolean;
begin
	read_integer:=integer_from_string(read_word(s),okay);
end;

function read_boolean(var s:string):boolean;
begin
	read_boolean:=boolean_from_string(read_word(s));
end;

procedure read_matrix(var s:string;var M:matrix_type);
var i,j:integer;
begin
	for j:=1 to matrix_rows(M) do
		for i:=1 to matrix_columns(M) do
			M[j,i]:=read_real(s);
end;

function read_kinematic_mount(var s:string):kinematic_mount_type;
var mount:kinematic_mount_type;
begin
	with mount do begin
		cone:=read_xyz(s);
		slot:=read_xyz(s);
		plane:=read_xyz(s);
	end;
	read_kinematic_mount:=mount;
end;

{
	Reads a sequence of space-delimited numbers from a string into an
	x_graph_type and returns this graph. Does not alter the original string.
}
function read_x_graph(var s:string):x_graph_type;

var 
	num_points,point_num,index:integer;
	gp1,gp2:x_graph_type;
	w:string;
	okay:boolean;

begin
{
	Create a new graph long enough to accommodate the largest 
	possible number of numerical entries in the string.
}
	setlength(gp1,length(s));
{
	Read all available numerical entries from the string and put
	them in the new graph. If we encounter a bad numerical entry,
	we stop.
}
	num_points:=0;
	okay:=true;
	index:=1;
	while (index<=length(s)) and okay do begin
		while (index<=length(s)) and (s[index] in separator_chars) do 
			inc(index);
		w:='';
		while (index<=length(s)) and (not (s[index] in separator_chars)) do begin
			w:=w+s[index];
			inc(index);
		end;
		if w<>'' then begin
			gp1[num_points]:=real_from_string(w,okay);
			inc(num_points);
		end;
	end;
{
	Create a new graph just the right size for the available points
	and fill it.
}
	if num_points>0 then begin
		setlength(gp2,num_points);
		for point_num:=0 to num_points-1 do
			gp2[point_num]:=gp1[point_num];
	end else begin
		setlength(gp2,1);
		gp2[0]:=0;
	end;
{
	Return the fully-populated graph.
}
	read_x_graph:=gp2;
end;

{
	Reads a sequence of space-delimited numbers from a string into an
	xy_graph_type and returns this graph. Does not alter the original string.
	Returns an error if there are an odd number of numbers in the string.
}
function read_xy_graph(var s:string):xy_graph_type;

var 
	value_num,point_num:integer;
	gp1:x_graph_type;
	gp2:xy_graph_type;

begin
{
	Read the numbers out of the string and into an x-graph.
}
	gp1:=read_x_graph(s);
{
	Create an xy graph of the correct size.
}
	if length(gp1)>1 then begin
		setlength(gp2,length(gp1) div 2);
{
	Go through the x-graph, reading pairs of x and y into the xy-graph.
}
		point_num:=0;
		value_num:=0;
		while (value_num<=length(gp1)-1) do begin
			gp2[point_num].x:=gp1[value_num];
			gp2[point_num].y:=gp1[value_num+1];
			inc(point_num);
			inc(value_num);
			inc(value_num);
		end;
{
	If there's an extra number on the end, we issue an error.
}
		if value_num<length(gp1)-1 then
			report_error('Missing y-value for final point in read_xy_graph.');
	end else begin
		setlength(gp2,1);
		gp2[0].x:=0;
		gp2[0].y:=0;
	end;
{
	Return the xy-graph.
}
	read_xy_graph:=gp2;
end;

{
	The following *_from_string functions transform strings into mathematical
	and geometric objects by copying an input string and then calling one of
	the above read_* routines on the copy. The copy is only 255 characters long,
	so if the original string is longer, it will be curtailed.
}
function xy_from_string(s:string):xy_point_type;
begin xy_from_string:=read_xy(s);end;

function xyz_from_string(s:string):xyz_point_type;
begin xyz_from_string:=read_xyz(s);end;

function xyz_line_from_string(s:string):xyz_line_type;
var l:xyz_line_type;
begin 
	l.point:=read_xyz(s);
	l.direction:=read_xyz(s);
	xyz_line_from_string:=l;
end;

function xyz_plane_from_string(s:string):xyz_plane_type;
var p:xyz_plane_type;
begin 
	p.point:=read_xyz(s);
	p.normal:=read_xyz(s);
	xyz_plane_from_string:=p;
end;

function kinematic_mount_from_string(s:string):kinematic_mount_type;
begin kinematic_mount_from_string:=read_kinematic_mount(s); end;

{
	The following "write_*" functions append a string to the end
	of a string. Numerical values are separated by spaces or
	end of line characters.
}
procedure write_ij(var s:string;p:ij_point_type);
const fsi=1; var a:string;
begin
	writestr(a,p.i:fsi,' ',p.j:fsi);
	s:=s+a;
end;

procedure write_xy(var s:string;p:xy_point_type);
var a:string;
begin
	writestr(a,p.x:fsr:fsd,' ',p.y:fsr:fsd);
	s:=s+a;
end;

procedure write_xyz(var s:string;p:xyz_point_type);
var a:string;
begin 
	writestr(a,p.x:fsr:fsd,' ',p.y:fsr:fsd,' ',p.z:fsr:fsd);
	s:=s+a;
end;

procedure write_xyz_line(var s:string;l:xyz_line_type);
var a:string;
begin 
	with l.point do writestr(a,x:fsr:fsd,' ',y:fsr:fsd,' ',z:fsr:fsd);
	with l.direction do writestr(a,a,' ',x:fsr:fsd,' ',y:fsr:fsd,' ',z:fsr:fsd);
	s:=s+a;
end;

procedure write_xyz_plane(var s:string;p:xyz_plane_type);
var a:string;
begin 
	with p.point do writestr(a,x:fsr:fsd,' ',y:fsr:fsd,' ',z:fsr:fsd);
	with p.normal do writestr(a,a,' ',x:fsr:fsd,' ',y:fsr:fsd,' ',z:fsr:fsd);
	s:=s+a;
end;

procedure write_xyz_matrix(var s:string;M:xyz_matrix_type);
var column_num,row_num:integer;a:string;
begin
	a:='';
	for row_num:=1 to num_xyz_dimensions do begin
		for column_num:=1 to num_xyz_dimensions do begin
			writestr(a,a,M[row_num,column_num]:fsr:fsd,' ');
		end;
		a:=a+eol;
	end;
	s:=s+a;
end;

procedure write_matrix(var s:string; var M:matrix_type);
var i,j:integer;
begin
	for j:=1 to matrix_rows(M) do begin
		for i:=1 to matrix_columns(M) do begin
			writestr(s,s,M[j,i]:fsr:fsd,' ');
		end;
		s:=s+eol;
	end;
end;

function string_from_matrix(var M:matrix_type):string;
var s:string;
begin
	s:='';
	write_matrix(s,M);
	string_from_matrix:=s;
end;

procedure write_kinematic_mount(var s:string; mount:kinematic_mount_type);
begin
	with mount do begin
		write_xyz(s,cone);
		s:=s+' ';
		write_xyz(s,slot);
		s:=s+' ';
		write_xyz(s,plane);
	end;
end;

{
	The following string_from_* routines call the write_* routines to create
	and return string representations of mathematical and geometric objects.
}
function string_from_ij(p:ij_point_type):string;
var s:string='';
begin
	write_ij(s,p);
	string_from_ij:=s;
end;

function string_from_xy(p:xy_point_type):string;
var s:string='';
begin
	write_xy(s,p);
	string_from_xy:=s;
end;

function string_from_xyz(p:xyz_point_type):string;
var s:string='';
begin
	write_xyz(s,p);
	string_from_xyz:=s;
end;

function string_from_xyz_line(l:xyz_line_type):string;
var s:string='';
begin
	write_xyz_line(s,l);
	string_from_xyz_line:=s;
end;

function string_from_xyz_plane(p:xyz_plane_type):string;
var s:string='';
begin
	write_xyz_plane(s,p);
	string_from_xyz_plane:=s;
end;

{
	delete_to_mark creates a new string by deleting all characters in 
	a string before and including the mark character. If there is no mark
	character in the string, the entire string is deleted, and we return
	an empty string.
}
function delete_to_mark(s:string;mark:char):string;
var p:integer;
begin 
	p:=pos(mark,s);
	if p>0 then delete(s,1,pos(mark,s))
	else s:='';
	delete_to_mark:=s;
end; 

{
	no_marks_left returns true if the string contains no mark characters.
}
function no_marks_left(s:string;mark:char):boolean;
begin 
	no_marks_left:=(pos(mark,s)=0); 
end;

{
	strip_folder_name deletes all characters in a string(a file name)
	up to and including the last folder (directory) separator, and
	returns the new string, which we assume is the name of the file
	within its home folder (directory). The routine is imperfect in
	that it strips DOS, UNIT, and MacOS folder separators. A UNIX file
	with a colon in its name will be stripped of the characters
	leading up to the colon.
}
function strip_folder_name(s:string):string;
var 
		separator:char;		
begin
		for separator in file_name_separators do
				repeat
						s:=delete_to_mark(s,separator);
				until no_marks_left(s,separator);
	strip_folder_name:=s;
end;

{
	strip_spaces deletes all leading spaces.
}
function strip_spaces(s:string):string;
begin
	strip_spaces:='';
	if s = '' then exit;
	while s[1]=' ' do delete(s,1,1);
	strip_spaces:=s;
end;

{
	strip_separators deletes all leading separators.
}
function strip_separators(s:string):string;
begin
	while s[1] in separator_chars do delete(s,1,1);
	strip_separators:=s;
end;

{
	alphabet_char returns true iff c is a letter.
}
function alphabet_char(c:char):boolean;

begin
	alphabet_char:=
		((ord('a')<=ord(c)) and(ord('z')>=ord(c)))
		or
		((ord('A')<=ord(c)) and(ord('Z')>=ord(c)));
end;

{
	alphanumeric_char returns true iff c is a letter or a number.
}
function alphanumeric_char(c:char):boolean;

begin
	alphanumeric_char:=
		((ord('0')<=ord(c)) and(ord('9')>=ord(c)))
		or
		alphabet_char(c);
end;

{
	upper_case returns the upper-case only version of s.
}
function upper_case(s:string):string;

var
	index:integer;

begin
	for index:=1 to length(s) do 
		if(ord(s[index])>=ord('a')) and(ord(s[index])<=ord('z')) then
			s[index]:=chr(ord(s[index])+ord('A')-ord('a'));
	upper_case:=s;
end;

{
	lower_case returns the lower-case only version of s.
}
function lower_case( s:string):string;

var
	index:integer;

begin
	for index:=1 to length(s) do 
		if(ord(s[index])>=ord('A')) and(ord(s[index])<=ord('Z')) then
			s[index]:=chr(ord(s[index])+ord('a')-ord('A'));
	lower_case:=s;
end;

{
	string_match returns true if the subject string matches the key string.
	The key string may contain the '*' string wild-card, or the '?'
	character wild-card, but the subject string may not contain either wild
	card. The routine converts both key and subject to upper-case before it
	begins its comparison of the two strings, so the match is case insensitive.
}
function string_match(key,subject:string):boolean;

var
	match,key_empty,subject_empty:boolean;
	saved_char:char;
	
begin
	match:=false;
	
	key:=upper_case(key);
	subject:=upper_case(subject);
	
	key_empty:=(key='');
	subject_empty:=(subject='');
	
	if(key_empty) and (subject_empty) then begin
		match:=true;
	end;

	if(key_empty) and (not subject_empty) then begin
		match:=false;
	end;

	if(not key_empty) and (subject_empty) then begin
		if(key[1]<>wild_string) then begin
			match:=false
		end
		else begin
			delete(key,1,1);
			match:=string_match(key,subject);
		end;
	end;

	if(not key_empty) and (not subject_empty) then begin
		if key[1]=wild_string then begin
			while (key<>'') and (key[1]=wild_string) do delete(key,1,1);
			if(key='') then match:=true
			else begin
				if(key='?') or(key[1]=subject[1]) then begin
					delete(key,1,1);
					delete(subject,1,1);
					match:=string_match(key,subject);
				end
				else begin
					repeat
						repeat
							delete(subject,1,1);
						until (subject='') or (subject[1]=key[1]);
						if(subject='') then match:=false
						else begin
							saved_char:=key[1];
							delete(key,1,1);
							delete(subject,1,1);
							match:=string_match(key,subject);
							if not match then key:=saved_char+key;
						end;
					until match or(subject='')
				end;
			end;
		end
		else begin
			if(key[1]=wild_char) or(key[1]=subject[1]) then begin
				delete(key,1,1);
				delete(subject,1,1);
				match:=string_match(key,subject);
			end
			else begin
				match:=false;
			end;
		end;
	end;
	string_match:=match;
end;

{
	strings_in_order returns true if a is alphabetically before b. If either
	string has zero length, or contains characters that are not alpha-numeric,
	then strings_in_order returns false.
}
function strings_in_order(a,b:string):boolean;

var
	i:integer;
	order,done:boolean;
	
begin
	a:=upper_case(a);
	b:=upper_case(b);
	order:=false;
	done:=(a='') or(b='');
	i:=1;
	repeat
		if(i>length(a)) and(i>length(b)) then done:=true;
		if(i>length(a)) and(i<=length(b)) then begin
			done:=true;
			order:=true;
		end;
		if(i>length(b)) and(i<=length(a)) then done:=true;
		
		if(i<=length(a)) or(i<=length(b)) then begin
			if a[i]<>b[i] then begin
				done:=true;
				if	alphanumeric_char(a[i]) and	alphanumeric_char(b[i]) then
					order:=ord(a[i])<ord(b[i]);
			end;
			inc(i);
		end;
	until done;
	strings_in_order:=order;
end;

{
	string_checksum returns an integer equal to the sum of the ordinal
	values of all characters in a string.
}
function string_checksum(s:string):integer;

var
	i,sum:integer;

begin
	sum:=0;
	for i:=1 to length(s) do sum:=sum+ord(s[i]);
	string_checksum:=sum;
end;

{
	string_from_x_graph writes the elements of an x-graph to a string and
	returns the string. It uses fsr and fsd to format the real-valued elements
	when writing them to the string. If the string is in danger of overflowing
	our long_string_length, the routine generates an error and returns the
	partially-completed string.
}
function string_from_x_graph(var gp:x_graph_type):string;
var
	i:integer;
	ls,ss:string;

begin
{
	If the inputs are invalid, we return an empty string.
}
	string_from_x_graph:='';
	if length(gp)=0 then exit;
{
	Go through the data and write values to the string. If we overflow the string,
	dispose of the long string, report an error, and return a nil pointer.
}
	ls:='';
	for i:=0 to length(gp)-1 do begin
		writestr(ss,gp[i]:fsr:fsd,' ');
		insert(ss,ls,length(ls)+1);
		if length(ls)>long_string_length then begin
			report_error('length(ls)>long_string_length in string_from_x_graph.');
			exit;
		end;
	end;
{
	Return the string.
}
	string_from_x_graph:=ls;
end;

{
	string_from_xy_graph is like string_from_x_graph but for an x-y graph. It
	writes both coordinates of the xy points to a string.
}
function string_from_xy_graph(var gp:xy_graph_type):string;

var
	i:integer;
	ls,ss:string;

begin
{
	If the inputs are invalid, we return an empty string.
}
	string_from_xy_graph:='';
	if length(gp)=0 then exit;
{
	Go through the data and write values to the string. If we overflow the string,
	dispose of the long string, report an error, and return a nil pointer.
}
	ls:='';
	for i:=0 to length(gp)-1 do begin
		writestr(ss,gp[i].x:fsr:fsd,' ',gp[i].y:fsr:fsd,' ');
		insert(ss,ls,length(ls)+1);
		if length(ls)>long_string_length then begin
			report_error('length(ls)>long_string_length in string_from_x_graph.');
			exit;
		end;
	end;
{
	Return the string.
}
	string_from_xy_graph:=ls;
end;

{
	average_x_graph calculates the average of the values in a one-dimentional
	graph.
}
function average_x_graph(gp:x_graph_ptr):real;
var i:integer;sum:longreal;ave:real;
begin
	if length(gp^)<1 then begin
		average_x_graph:=0;
		exit;
	end;
	sum:=0;
	for i:=0 to length(gp^)-1 do sum:=sum+gp^[i];
	ave:=sum/length(gp^);
	average_x_graph:=ave;
	check_for_math_error(ave);
end;

{
	max_x_graph finds the maximum value in a one-dimentional graph.
}
function max_x_graph(gp:x_graph_ptr):real;
var i:integer;max:real;
begin
	if length(gp^)<1 then begin
		max_x_graph:=0;
		exit;
	end;
	max:=gp^[0];
	for i:=1 to length(gp^)-1 do 
		if gp^[i]>max then max:=gp^[i];
	max_x_graph:=max;
	check_for_math_error(max);
end;

{
	min_x_graph finds the minimum value in a one-dimentional graph.
}
function min_x_graph(gp:x_graph_ptr):real;
var i:integer;min:real;
begin
	if length(gp^)<1 then begin
		min_x_graph:=0;
		exit;
	end;
	min:=gp^[0];
	for i:=1 to length(gp^)-1 do 
		if gp^[i]<min then min:=gp^[i];
	min_x_graph:=min;
	check_for_math_error(min);
end;

{
	stdev_x_graph calculates the standard deviation of the values in a
	one-dimentional graph.
}
function stdev_x_graph(gp:x_graph_ptr):real;
var i:integer;sum,sum_sqr:longreal;stdev:real;
begin
	if length(gp^)<=1 then begin
		stdev_x_graph:=0;
		exit;
	end;
	sum:=0;
	sum_sqr:=0;
	for i:=0 to length(gp^)-1 do begin
		sum:=sum+gp^[i];
		sum_sqr:=sum_sqr+sqr(gp^[i]);
	end;
	stdev:=sqrt(sum_sqr/length(gp^)-sqr(sum/length(gp^)));
	stdev_x_graph:=stdev;
	check_for_math_error(stdev);
end;

{
	mad_x_graph calculates the mean absolute distance between values in a
	one-dimentional graph.
}
function mad_x_graph(gp:x_graph_ptr):real;
var i:integer;sum:longreal;mad,ave:real;
begin
	if length(gp^)<1 then begin
		mad_x_graph:=0;
		exit;
	end;
	sum:=0;
	ave:=average_x_graph(gp);
	for i:=0 to length(gp^)-1 do 
		sum:=sum+abs(gp^[i]-ave);
	mad:=sum/length(gp^);
	mad_x_graph:=mad;
	check_for_math_error(mad);
end;

{
	Routines for sorting graphs. We have a swap element routine and the four
	possible ordering routines: a>b (gt), a<b (lt), abs(a)>abs(b) (gt_abs), and
	abs(a)<abs(b) (lt_abs). Each takes a generic pointer for use with our quick
	sort routine. We apply these routines to all elements in an x-graph with
	four corresponding sort routines ascending, descending, ascending_abs, and
	descending_abs.
}
procedure x_graph_swap(a,b:integer;lp:pointer); 
var x:real; 
begin 
	x:=x_graph_ptr(lp)^[a];
	x_graph_ptr(lp)^[a]:=x_graph_ptr(lp)^[b];
	x_graph_ptr(lp)^[b]:=x;
end;

function x_graph_gt(a,b:integer;lp:pointer):boolean;
begin 
	x_graph_gt:=(x_graph_ptr(lp)^[a] > x_graph_ptr(lp)^[b]); 
end;

function x_graph_lt(a,b:integer;lp:pointer):boolean;
begin 
	x_graph_lt:=(x_graph_ptr(lp)^[a] < x_graph_ptr(lp)^[b]); 
end;

function x_graph_gt_abs(a,b:integer;lp:pointer):boolean;
begin 
	x_graph_gt_abs:=(abs(x_graph_ptr(lp)^[a]) > abs(x_graph_ptr(lp)^[b])); 
end;

function x_graph_lt_abs(a,b:integer;lp:pointer):boolean;
begin 
	x_graph_lt_abs:=(abs(x_graph_ptr(lp)^[a]) < abs(x_graph_ptr(lp)^[b])); 
end;

procedure x_graph_ascending(gp:x_graph_ptr);
begin
	quick_sort(0,length(gp^)-1,x_graph_swap,x_graph_gt,pointer(gp));
end;

procedure x_graph_descending(gp:x_graph_ptr);
begin
	quick_sort(0,length(gp^)-1,x_graph_swap,x_graph_lt,pointer(gp));
end;

procedure x_graph_ascending_abs(gp:x_graph_ptr);
begin
	quick_sort(0,length(gp^)-1,x_graph_swap,x_graph_gt_abs,pointer(gp));
end;

procedure x_graph_descending_abs(gp:x_graph_ptr);
begin
	quick_sort(0,length(gp^)-1,x_graph_swap,x_graph_lt_abs,pointer(gp));
end;

{
	percentile_x_graph returns a sample from the x-graph for which the fraction of
	samples that are less than or equal to the sample is p/100. For p=90, we get the 
	value for which 90% of samples are less than or equal to the value. For p=50 we 
	get the median. If p=0 we get the minimum and if p=100 we get the maximum. In
	order to perform the calculation, we copy the x-graph and sort it in order of
	increasing sample value using our quick-sort routine.
}
function percentile_x_graph(gp:x_graph_ptr;percentile:real):real;

var 
	p:real=0;
	g:x_graph_type;

begin
	if length(gp^)<=1 then begin
		percentile_x_graph:=gp^[0];
		exit;
	end;
	g:=gp^;
	x_graph_ascending(@g);
	if (percentile<0) then percentile:=0;
	if (percentile>100) then percentile:=100;
	p:=g[round((length(g)-1)*(1.0*percentile/100))];
	percentile_x_graph:=p;
	check_for_math_error(p);
end;

{
	median_x_graph returns the median value of a set of samles
	stored in an x-graph.
}
function median_x_graph(gp:x_graph_ptr):real;
const median_percentile=50;
begin
	median_x_graph:=percentile_x_graph(gp,median_percentile);
end;

function coastline_x_graph(gp:x_graph_ptr):real;
var i:integer;sum:longreal;
begin
	coastline_x_graph:=0;
	if length(gp^)<=1 then begin
		report_error('length(gp^)<=1 in coastline_x_graph');
		exit;
	end;
	sum:=0;
	for i:=1 to length(gp^)-1 do 
		sum:=sum+abs(gp^[i]-gp^[i-1]);
	coastline_x_graph:=sum;
	check_for_math_error(sum);
end;

function coastline_x_graph_progress(gp:x_graph_ptr):x_graph_type;
var 
	i:integer;
	cp:x_graph_type;
begin
	coastline_x_graph_progress:=nil;
	if gp=nil then exit;
	if length(gp^)<=1 then begin
		report_error('length(gp^)<=1 in coastline_x_graph_progress');
		exit;
	end;
	setlength(cp,length(gp^));
	cp[0]:=0;
	for i:=1 to length(gp^)-1 do begin
		cp[i]:=cp[i-1]+abs(gp^[i]-gp^[i-1]);
	end;
	coastline_x_graph_progress:=cp;
end;

{
	spikes_x_graph uses a path-finding algorithm to detect spikes
	in the progression of a two-dimensional graph. This routine 
	assumes that the path always progresses a fixed distance in the 
	first coordinate, while the second coordinate is given by the values
	in the x-graph.
}
function spikes_x_graph(gp:x_graph_ptr;
	threshold:real;extent:integer):xy_graph_type;
const
	max_spikes=100;
var
	i,j,next_j,num_spikes,spike_index:integer;
	s1,s2:xy_graph_type;
	scale,shortest_step,step,dev,max_dev:real;
begin
	spikes_x_graph:=nil;
	if gp=nil then exit;
	if length(gp^)<=1 then begin
		report_error('length(gp^)<=1 in spikes_x_graph');
		exit;
	end;
	scale:=coastline_x_graph(gp)/length(gp^);
	num_spikes:=0;
	setlength(s1,max_spikes);
	j:=1;
	while (j<length(gp^)) and (num_spikes<max_spikes) do begin
		shortest_step:=sqrt(sqr((gp^[j]-gp^[j-1])/scale)+1);
		next_j:=j;
		i:=j+1;
		while (shortest_step>i-j+1) and (extent>=i-j+1) and (i<length(gp^)) do begin
			step:=sqrt(sqr((gp^[i]-gp^[j-1])/scale)+sqr(i-j+1));
			if (step<shortest_step) then begin
				shortest_step:=step;
				next_j:=i;
			end;
			inc(i);
		end;
		
		spike_index:=j;
		max_dev:=0;
		for i:=j to next_j-1 do begin
			dev:=sqrt(sqr((gp^[next_j]-gp^[i])/scale)+sqr(next_j-i));
			if (dev>max_dev) then begin
				max_dev:=dev;
				spike_index:=i;
			end;
		end;
		
		if (max_dev>threshold) then begin
			s1[num_spikes].x:=spike_index;
			s1[num_spikes].y:=max_dev;
			inc(num_spikes);
		end;
		j:=next_j+1;
	end;
	if (num_spikes>0) then begin
		setlength(s2,num_spikes);
		for j:=0 to num_spikes-1 do
			s2[j]:=s1[j];
	end else begin
		setlength(s2,0);
	end;
	spikes_x_graph:=s2;
end;

{
	The following routines operate upon the y-component of an
	xy-graph.
}
function average_y_xy_graph(gp:xy_graph_ptr):real;
var i:integer;sum:longreal;ave:real;
begin
	if length(gp^)<1 then begin
		average_y_xy_graph:=0;
		exit;
	end;
	sum:=0;
	for i:=0 to length(gp^)-1 do 
		sum:=sum+gp^[i].y;
	ave:=sum/length(gp^);
	average_y_xy_graph:=ave;
	check_for_math_error(ave);
end;

function stdev_y_xy_graph(gp:xy_graph_ptr):real;
var i:integer;sum:longreal;stdev,ave:real;
begin
	if length(gp^)<=1 then begin
		stdev_y_xy_graph:=0;
		exit;
	end;
	sum:=0;
	ave:=average_y_xy_graph(gp);
	for i:=0 to length(gp^)-1 do 
		sum:=sum+sqr(gp^[i].y-ave);
	stdev:=sqrt(sum/(length(gp^)-1));
	stdev_y_xy_graph:=stdev;
	check_for_math_error(stdev);
end;

function max_y_xy_graph(gp:xy_graph_ptr):real;
var i:integer;max:longreal;
begin
	if length(gp^)<1 then begin
		max_y_xy_graph:=0;
		exit;
	end;
	max:=gp^[0].y;
	for i:=1 to length(gp^)-1 do 
		if max<gp^[i].y then max:=gp^[i].y;
	max_y_xy_graph:=max;
end;

function min_y_xy_graph(gp:xy_graph_ptr):real;
var i:integer;min:longreal;
begin
	if length(gp^)<1 then begin
		min_y_xy_graph:=0;
		exit;
	end;
	min:=gp^[0].y;
	for i:=1 to length(gp^)-1 do 
		if min>gp^[i].y then min:=gp^[i].y;
	min_y_xy_graph:=min;
end;

{
	The following functions treat the elements of an x-y graph as
	locations in space for coastline, standard deviation of position,
	and average position.
}
function average_xy_graph(gp:xy_graph_ptr):xy_point_type;
var i:integer;p:xy_point_type;sum_x,sum_y:longreal;
begin
	if length(gp^)<1 then begin
		average_xy_graph:=xy_origin;
		exit;
	end;
	sum_x:=0;
	sum_y:=0;
	for i:=0 to length(gp^)-1 do begin
		sum_x:=sum_x+gp^[i].x;
		sum_y:=sum_y+gp^[i].y;
	end;
	p.x:=sum_x/length(gp^);
	p.y:=sum_y/length(gp^);
	average_xy_graph:=p;
	check_for_math_error(p.x);
	check_for_math_error(p.y);
end;

function stdev_xy_graph(gp:xy_graph_ptr):xy_point_type;
var i:integer;p,ave:xy_point_type;sum_x,sum_y:longreal;
begin
	if length(gp^)<=1 then begin
		stdev_xy_graph:=xy_origin;
		exit;
	end;
	ave:=average_xy_graph(gp);
	sum_x:=0;
	sum_y:=0;
	for i:=0 to length(gp^)-1 do begin
		sum_x:=sum_x+sqr(gp^[i].x-ave.x);
		sum_y:=sum_y+sqr(gp^[i].y-ave.y);
	end;
	p.x:=sqrt(sum_x/(length(gp^)-1));
	p.y:=sqrt(sum_y/(length(gp^)-1));
	stdev_xy_graph:=p;
	check_for_math_error(p.x);
	check_for_math_error(p.y);
end;


function coastline_xy_graph(gp:xy_graph_ptr):real;
var i:integer;sum:longreal;
begin
	if length(gp^)<=1 then begin
		coastline_xy_graph:=0;
		report_error('length(gp^)<=1 in coastline_xy_graph');
		exit;
	end;
	sum:=0;
	for i:=1 to length(gp^)-1 do 
		sum:=sum+xy_separation(gp^[i],gp^[i-1]);
	coastline_xy_graph:=sum;
	check_for_math_error(sum);
end;

function coastline_xy_graph_progress(gp:xy_graph_ptr):xy_graph_type;
var 
	i:integer;
	cp:xy_graph_type;
begin
	coastline_xy_graph_progress:=nil;
	if gp=nil then exit;
	if length(gp^)<=1 then begin
		report_error('length(gp^)<=1 in coastline_xy_graph_progress');
		exit;
	end;
	setlength(cp,length(gp^));
	cp[0].x:=gp^[0].x;
	cp[0].y:=0;
	for i:=1 to length(gp^)-1 do begin
		cp[i].x:=gp^[i].x;
		cp[i].y:=cp[i-1].y+xy_separation(gp^[i],gp^[i-1]);
	end;
	coastline_xy_graph_progress:=cp;
end;


{
	window_function smooths off the first and last few samples of an
	x_graph_type with a ramp function so that they converge upon the
	graph's average value. If we specify extent = 3 then the window
	function affects the first and last 3 samples in the graph.
}
procedure window_function(dp:x_graph_ptr;extent:integer);

const
	min_multiple=2.0;
	
var
	n,m:integer;
	a:real;
	
begin
	if (extent<1) then exit;
	if dp=nil then exit;
	
	m:=length(dp^);
	if (m<=1) then exit;
	
	a:=average_x_graph(dp);
	if (min_multiple*extent>m) then extent:=round(m/min_multiple);

	for n:=0 to extent-1 do begin
		dp^[n]:=a+(dp^[n]-a)*n/extent;
		dp^[m-n-1]:=a+(dp^[m-n-1]-a)*n/extent;
	end;
end;

{
	The recursive_filter function implements a recursive filter with
	coefficients listed in the a_list and b_list strings. The a_list
	contains the coefficients used to multiply the current and
	previous input values when calculating the new filter output, and
	the b_list contains the coefficients used to multiply previous
	filter output values in the same calculation. The a_list begins
	with a[0], by which we multiply the current input value, followed
	by a[1], by which we multiply the previous input value, and so on,
	until the string ends. Values for coefficients a[n] after that
	will be set to zero by default, up to the maximum value of n given
	by the max_n constant. The b_list is in the same format, except it
	begins with b[1], by which we multiply the previous output. We
	assume b[0] = 0. The routine receives its data via an x-graph and
	returns data as an x-graph.
}
function recursive_filter(x:x_graph_ptr;a_list,b_list:string):x_graph_type;

const
	min_num_points=2;
	max_n=20;
	small_value=0.001;
	
var 
	i,k,n,end_b,end_a:integer;
	a:array [0..max_n] of real;
	b:array [1..max_n] of real;
	y:x_graph_type;
	dc_gain,p,q:real;

begin
	recursive_filter:=nil;
	if (x=nil) then exit;
	if (length(x^)<min_num_points) then begin
		report_error('length(gp^)<min_num_points in recursive_filter');
		exit;
	end;	
	n:=length(x^);
	setlength(y,n);
	
	for i:=0 to max_n do a[i]:=0;
	end_a:=0;
	while (a_list<>'') and (end_a<=max_n) do begin
		a[end_a]:=read_real(a_list);
		inc(end_a);
	end;
	for i:=1 to max_n do b[i]:=0;
	end_b:=1;
	while (b_list<>'') and (end_b<=max_n) do begin
		b[end_b]:=read_real(b_list);
		inc(end_b);
	end;
	
	p:=0;
	for i:=0 to end_a do p:=p+a[i];
	q:=1;
	for i:=1 to end_b do q:=q-b[i];
	if abs(q)>small_value then dc_gain:=p/q
	else dc_gain:=1;
	
	for k:=0 to n-1 do begin
		y[k]:=0;
		for i:=0 to end_a-1 do
			if (k-i)>=0 then y[k]:=y[k]+a[i]*x^[k-i]
			else y[k]:=y[k]+a[i]*x^[0];
		for i:=1 to end_b-1 do
			if (k-i)>=0 then y[k]:=y[k]+b[i]*y[k-i]
			else y[k]:=y[k]+b[i]*x^[0]*dc_gain;
	end;
	
	recursive_filter:=y;
end;

{
	glitch_filter_xy attempts to remove glitches from a signal. A "glitch" is a
	one-point disturbance due to corruption of one of the signal's sample
	values. Any point whose xy distance is more than the "threshold" from the
	point before is a potential glitch. If, by removing this point and the
	subsequent two points, we cause a factor of glitch_reduction drop in the
	xy-coastline of the signal within coastline_extent samples of the first
	point, we classify the point as a glitch. Once we find a glitch, we remove
	and replace every sample after the glitch until the samples return to within
	glitch_threshold of the sample just before the first glitch. Thus we can
	remove large two-point or three-point glitches in one pass. The routine
	returns the number of glitches it finds.
}
function glitch_filter_xy(gp:xy_graph_ptr;threshold:real):integer;

const
	glitch_length=2;
	coastline_extent=4;
	glitch_reduction=5;
	min_length=coastline_extent*2+1;
	
var
	n,m,c_start,c_end,count:integer;
	coastline_with,coastline_without,separation:real;
	inertial_point:xy_point_type;
	glitch:boolean;
	
begin
{
	Check for validity of input arguments.
}
	glitch_filter_xy:=0;
	if (threshold<=0) then exit;
	if gp=nil then exit;
	if (length(gp^)<=min_length) then exit;
{
	Our first guess at an inertial point for the filter, which is the point to 
	which we will compare the first sample, is the first sample itself.
}
	inertial_point:=gp^[0];
{
	Go through the sequence of points until we come to three that are within one
	threshold of one another, and take the middle one as our inertial point. If
	no such point exists, we will be using the first point as our inertial point.
}
	n:=1;
	while (n<length(gp^)-1) do begin				
		if (xy_separation(gp^[n-1],gp^[n])<threshold) 
			and (xy_separation(gp^[n-1],gp^[n])>0.0) 
			and (xy_separation(gp^[n+1],gp^[n])<threshold) 
			and (xy_separation(gp^[n+1],gp^[n])>0.0) then begin
			inertial_point:=gp^[n];
			n:=length(gp^);
		end else inc(n);
	end;
{
	Apply the absolute deviation limit required by the glitch filter, starting
	the comparison with our inertial point. When we come to a point that is
	farther than threshold from the inertial point, we check to see if removing
	this point and glitch_length-1 subsequent points will cause a significant
	reduction in the local coastline. If so, we remove all glitch_length points
	by replacing them with the inertial point.
}
	count:=0;
	for n:=0 to length(gp^)-1 do begin
		glitch:=false;
		separation:=xy_separation(gp^[n],inertial_point);
		if separation>threshold then begin
			c_start:=n-coastline_extent;
			if c_start<0 then c_start:=0;
			c_end:=c_start+2*coastline_extent;
			if c_end>length(gp^)-1 then c_end:=length(gp^)-1;
			if c_end-c_start<2*coastline_extent then c_start:=c_end-2*coastline_extent;
			if c_start<0 then c_start:=0;

			coastline_with:=0;
			for m:=c_start+1 to c_end do 
				coastline_with:=coastline_with+xy_separation(gp^[m],gp^[m-1]);

			coastline_without:=0;
			if n=c_start then begin
				for m:=c_start+glitch_length+1 to c_end do begin
					coastline_without:=coastline_without+xy_separation(gp^[m],gp^[m-1]);
				end;
			end else begin
				for m:=c_start+1 to c_end do begin
					if m<n then begin
						coastline_without:=coastline_without+xy_separation(gp^[m],gp^[m-1]);
					end else if m=n+glitch_length then begin
						coastline_without:=coastline_without+xy_separation(gp^[m],gp^[n-1]);
					end else if m>n+glitch_length then begin
						coastline_without:=coastline_without+xy_separation(gp^[m],gp^[m-1]);
					end;
				end;
			end;

			if coastline_with>glitch_reduction*coastline_without then glitch:=true;
		end;
		
		if glitch then begin
			for m:=n to n+glitch_length-1 do
				if m<length(gp^)-1 then
					if xy_separation(gp^[m],inertial_point)>threshold then
						gp^[m]:=inertial_point;
			inc(count);
		end else 
			inertial_point:=gp^[n];
	end;
	
	glitch_filter_xy:=count;
end;

{
	glitch_filter calls glitch_filter_xy to remove glitches in a one-dimensional
	signal.
}
function glitch_filter(dp:x_graph_ptr;threshold:real):integer;

var
	n:integer;
	gp:xy_graph_type;
	
begin
{
	Check for validity of input arguments.
}
	glitch_filter:=0;
	if (threshold<=0) or (dp=nil) then exit;
	if (length(dp^)<1) then exit;
{
	Create an xy-graph.
}
	setlength(gp,length(dp^));
	if gp=nil then exit;
{
	Copy the data values into the xy-graph as the y-values and set all the x-values to zero. 
	Call glitch_filter_xy on the new xy-graph.
}
	for n:=0 to length(dp^)-1 do begin
		gp[n].y:=dp^[n];
		gp[n].x:=0;
	end;
	glitch_filter:=glitch_filter_xy(@gp,threshold);
{
	Copy the glitch filter output back into the original graph.
}
	for n:=0 to length(dp^)-1 do
		dp^[n]:=gp[n].y;
end;

{
	glitch_filter_y applies glitch_filter_xy only to changes in the y-values of 
	a sequence of xy points.
}
function glitch_filter_y(gp:xy_graph_ptr;threshold:real):integer;

var
	n:integer;
	gp2:xy_graph_type=nil;
	
begin
{
	Check for validity of input arguments.
}
	glitch_filter_y:=0;
	if (threshold<=0) then exit;
	if gp=nil then exit;
	if (length(gp^)<1) then exit;
{
	Create an new xy-graph.
}
	setlength(gp2,length(gp^));
	if gp=nil then exit;
{
	Copy the y values from gp into the y-values of gp2 and set the x-values of gp2 all
	to zero. Call glitch_filter_xy on gp2.
}
	for n:=0 to length(gp^)-1 do begin
		gp2[n].y:=gp^[n].y;
		gp2[n].x:=0;
	end;
	glitch_filter_y:=glitch_filter_xy(@gp2,threshold);
{
	Copy the glitch-filtered y-values out of gp2 into gp. We leave the x-values of gp 
	as they were: only the y-values are being glitch filtered.
}
	for n:=0 to length(gp^)-1 do
		gp^[n].y:=gp2[n].y;
end;

{
	random_0_to_1 returns a real number betwen zero and one.
}
function random_0_to_1:real;
begin 
	random_0_to_1:=random; 
end;

{
	inc_num_outstanding_ptrs incrments num_outstanting_ptrs, and also reports
	the count to the user via gui_writeln if track_ptrs is true. The id string
	should give the name of the pointer, and caller should give the name of the
	routine that called inc_num_oustanding_ptrs. This routine, together with
	dec_num_outstanding_ptrs, can be paired with every use of the Pascal new()
	and dispose() procedures to help you find leaks in your code.
}
procedure inc_num_outstanding_ptrs(size:integer;caller:string);
var s:string='';
begin
	inc(num_outstanding_ptrs);
	if track_ptrs then begin
		writestr(s,'Allocated ',size:1,' elements for ',caller,', ',
			num_outstanding_ptrs:1,' pointers outstanding.');
		gui_writeln(s);
	end;
end;

{
	dec_num_outstanding_ptrs is similar to dec_num_outstanting_ptrs, but
	decrements num_outstanding_ptrs.
}
procedure dec_num_outstanding_ptrs(size:integer;caller:string);
var s:string='';
begin
	dec(num_outstanding_ptrs);
	if track_ptrs then begin
		writestr(s,'Disposing of ',size:1,' elements for ',caller,', ',
			num_outstanding_ptrs:1,' pointers outstanding.');
		gui_writeln(s);
	end;
end;


{
	report_error appends an error message to the global error_string. The text of
	the error message should be the contents of the string "s". The routine
	attaches error_prefix to "s" before it adds it to error_string. When
	append_errors is true, the routine appends the error to error_string on a
	new line. Otherwise it sets the error_string to the new error message. The
	error message passed in "s" should be a full sensence with a period at the
	end.
}
procedure report_error(s:string);

begin
	if log_errors then debug_log(s);
	if (error_string='') or not append_errors then 
		error_string:=error_prefix+s
	else 
		error_string:=error_string+eol+error_prefix+s;
end;

{
	Returns the current time in milliseconds as a 64-bit unsigned integer.
}
function clock_milliseconds:qword;

var
	tdt:TDateTime;
	tts:TTimeStamp;
	
begin
	tdt:=Now;
	tts:=DateTimeToTimeStamp(tdt);
	clock_milliseconds:=round(TimeStampToMSecs(tts));
end;

{
	start_timer sets the utility timer equal to the current time in
	milliseconds, and clears the mark_time_list. The "id" string identifies a
	point in execution, the "caller" string identifies the routine containing
	the execution point.
}
procedure start_timer(id,caller:string);

var
	tdt:TDateTime;
	tts:TTimeStamp;
	s:string;
	index:integer;
	
begin
	for index:=0 to max_num_time_marks do
		mark_time_list[index]:='';
	mark_time_index:=0;
	debug_counter:=0;

	tdt:=Now;
	tts:=DateTimeToTimeStamp(tdt);
	start_time_ms:=TimeStampToMSecs(tts);

	writestr(s,0:6,' ',id,' in ',caller);

	mark_time_list[mark_time_index]:=s;
	inc(mark_time_index);
end;

{
	mark_time adds an entry to the mark_time_list.
}
procedure mark_time(id,caller:string);

var
	ms,diff:comp;
	tdt:TDateTime;
	tts:TTimeStamp;
	s:string;
	
begin
	if mark_time_index>=max_num_time_marks then exit;
	
	tdt:=Now;
	tts:=DateTimeToTimeStamp(tdt);
	ms:=TimeStampToMSecs(tts);
	diff:=ms-start_time_ms;
	
	writestr(s,round(diff):6,' ',id,' in ',caller);

	mark_time_list[mark_time_index]:=s;
	inc(mark_time_index);
end;

{
	report_time_marks writes a list of time marks stored in the
	mark_time_list. It calls gui_writeln with each line of output.
}
procedure report_time_marks;

var
	index:integer;
	s:string;
	
begin
	s:='Index, Elapsed (ms), Comment:';
	gui_writeln(s);
	for index:=0 to mark_time_index-1 do begin
		writestr(s,index:6,' ',mark_time_list[index]);
		gui_writeln(s);
	end;
end;

{
	The default debug_log routine does nothing.
}
procedure default_debug_log(s:string);
begin
end;

{
	default_gui_draw does nothing.
}
procedure default_gui_draw(s:string); 
begin 
end;

{
	default_gui_support does nothing.
}
procedure default_gui_support(s:string);
begin
end;

{
	default_gui_wait calls gui_readln and waits for the user to
	press enter.
}
procedure default_gui_wait(s:string); 
begin
	s:=gui_readln('Press enter to continue...');
end;

{
	default_gui_write does nothing.
}
procedure default_gui_write(s:string);
begin
end;

{
	default_gui_writeln calls gui_writeln and adds a carriage return.
}
procedure default_gui_writeln(s:string); 
begin
	gui_write(s+eol);
end;

{
	default_gui_readln returns an empty string.
}
function default_gui_readln(s:string):string;
begin
	default_gui_readln:='';
end;

{
	new_byte_array allocates space for a new byte_array, and returns a
	pointer to that space.
}
function new_byte_array(size:integer):byte_array_ptr;
var b:byte_array_ptr;
begin
	new(b);
	setlength(b^,size);
	inc_num_outstanding_ptrs(length(b^),'new_byte_array');
	new_byte_array:=b;
end;

{
	dispose_byte array disposes of a byte_array.
}
procedure dispose_byte_array(b:byte_array_ptr);
begin
	if b=nil then exit;
	dec_num_outstanding_ptrs(length(b^),'dispose_byte_array');
	dispose(b);
end;

{
	bubble_sort arranges the elements of a list in ascending order, as defined
	by the "after" function, and does so by applying the "swap" function. The
	bubble sort algorithm usually completes in n*n time, where n is the length
	of the list. We provide the bubble sort algorithm as a basis for the format
	of a sort routine, and to compare the bubble-sort with our quick-sort
	routine. The integers a and b are the indices of an array between which you
	want the sort to take place. The bubble_sort will sort these elements in
	place and leave any other elements in the array undisturbed. The "swap"
	procedure must be defined by the bubble-sort user. It is a procedure that
	takes two integers, m and n. A call to swap(m,n) exchanges elements m and n
	in the list. The "after" function returns a boolean result and takes two
	integers m and n as parameters. If the m'th element in the list should come
	after the n'th element, after(m,n) should return true. Otherwise after(m,n)
	should return false. By means of swap(m,n) and after(m,n), the bubble_sort
	routine, and also the quick_sort routine that comes later, are able to
	interact with lists of any type. There is no point in the bubble_sort or
	quick_sort routine where the actual value of any list element is used
	directly.
}
procedure bubble_sort(a,b:integer;
	swap:sort_swap_procedure_type;
	after:sort_after_function_type;
	lp:pointer);

var
	swapped:boolean;
	n:integer;

begin
{
	Cover special cases of short lists.
}
	if b-a<=1 then exit;
	if (b-a)=2 then begin
		if after(a,b,lp) then swap(a,b,lp);
		exit;
	end;
{
	Go through the list repeatedly, swapping neighbors that are 
	out of order, until we run through once without swapping any
	elements.
}
	swapped:=true;
	while swapped do begin
		swapped:=false;
		for n:=a to b-1 do begin
			if after(n,n+1,lp) then begin
				swap(n,n+1,lp);
				swapped:=true;
			end;
		end;
	end;
end;

{
	quick_sort arranges the elements of a list in increasing order, as
	defined by the "after" function, by applying the "swap" function.
	For an explanation of how to define the after and swap functions
	for the quick_sort call, see the comments in the bubble-sort routine
	above.
	
	The quick sort algorithm usually operates in n.log(n) time, where n
	is the length of the list. The table below gives the average time to 
	sort a list of n integers, starting with random values between 1 and
	n in each element. We compare the bubble-sort to the quick-sort on the
	same computer (a 1 GHz PPC laptop) with the same list structure, record
	size, and swap function.
	
	n         Quick (us)  Bubble (us)
	1         0.1         0.1        
	10        6.2         4.1  
	100       75          490
	1000      1,000       56,000
	10000     13,000      5,300,000
	100000    150,000     610,000,000
	1000000   1,700,000   -
	10000000  19,000,000  -
	
	We find that the advantage of quick-sort is far less when the list is
	a concatination of several pre-sorted lists, or if the list is nearly-
	sorted to begin with.
}
procedure quick_sort(a,b:integer;
	swap:sort_swap_procedure_type;
	after:sort_after_function_type;
	lp:pointer);

var
	m,n,p:integer;
	
begin
{
	Exit in redundant cases.
}
	if b<=a then exit;
{
	Pick a random pivot element, p, and move it to the end of the list, 
	at location b, by swapping it with the element at location p. The 
	random pick avoids certain systematic delays in sorting caused by 
	regular patterns in the original list.
}
	p:=round(random_0_to_1*(b-a)+a);
	swap(p,b,lp);
{
	Move elements that should come after the pivot element to the end of the list
	made up of elements a to b-1.
}
	m:=a;
	n:=b-1;
	while m<n do begin
		if after(m,b,lp) then begin
			swap(m,n,lp);
			dec(n);
		end else begin
			inc(m);
		end;
	end;
{
	Put the pivot element into the list, with elements that should come before
	the pivot on the left and those that should come after on the right.
}
	if after(m,b,lp) then p:=m else p:=m+1;
	swap(p,b,lp);
{
	Sort the two sub-lists.
}
	quick_sort(a,p-1,swap,after,lp);
	quick_sort(p+1,b,swap,after,lp);
end;

{
	straight_line_fit calculates the slope and intercept (on the y-axix)
	of the straight line with minimum rms residuals upon the data
	set specified by dp. It also calculates the rms residuals. If 
	the slope or intercept are infinite, we set error_string to
	a non-empty string using check_for_math_error.
}
procedure straight_line_fit(dp:xy_graph_ptr;
	var slope,intercept,rms_residual:real);

const
	min_num_points=2;

var 
	index:integer;	
	k00,k10,k01,k11,k20:real;
	
begin 
	slope:=0;intercept:=0;rms_residual:=0;
	if length(dp^)>=min_num_points then begin
		k00:=0;k10:=0;k01:=0;k11:=0;k20:=0;
		for index:=0 to length(dp^)-1 do begin
			with dp^[index] do begin
				k00:=k00+1;
				k10:=k10+x;
				k01:=k01+y;
				k11:=k11+x*y;
				k20:=k20+x*x;
			end;
		end;	
		if (k20*k00-k10*k10 <> 0) then begin
			slope:=(k11*k00-k01*k10)/(k20*k00-k10*k10);
			intercept:=(k01*k20-k11*k10)/(k20*k00-k10*k10);
		end else begin
			slope:=0;
			intercept:=0;
		end;
		rms_residual:=0;
		for index:=0 to length(dp^)-1 do begin
			with dp^[index] do begin
				rms_residual:=rms_residual+sqr(x*slope+intercept-y);
			end;
		end;
		if length(dp^)<>0 then 
			rms_residual:=sqrt(rms_residual/length(dp^));
	end 
	else begin
		slope:=0;
		if length(dp^)=1 then intercept:=dp^[0].y
		else intercept:=0;
		rms_residual:=0;
	end;
	check_for_math_error(slope);
	check_for_math_error(intercept);
end;

{
	parabolic_line_fit calculates the parabola, slope and intercept (on the
	y-axix) of the second-order parabolic line with minimum rms residuals upon
	the data set specified by dp. It also calculates the rms residuals. The fit
	is y = px^2 + sx + i, where p is the parabola parameter, s is the slope
	parameter, and i is the intercept parameter. If any of these parameters is
	infinite, we set error_string to a non-empty string using
	check_for_math_error.
}
procedure parabolic_line_fit(dp:xy_graph_ptr;
	var parabola,slope,intercept,rms_residual:real);

const
	min_num_points=3;

var 
	index:integer;	
	k00,k10,k01,k11,k20,k21,k30,k40:real;
	M:xyz_matrix_type;
	
begin 
	k00:=0;k10:=0;k01:=0;k11:=0;k20:=0;k21:=0;k30:=0;k40:=0;
	slope:=0;intercept:=0;rms_residual:=0;
	if length(dp^)>=min_num_points then begin
		for index:=0 to length(dp^)-1 do begin
			with dp^[index] do begin
				k00:=k00+1;
				k10:=k10+x;
				k01:=k01+y;
				k11:=k11+x*y;
				k20:=k20+x*x;
				k21:=k21+x*x*y;
				k30:=k30+x*x*x;
				k40:=k40+x*x*x*x;
			end;
		end;	
		M[1,1]:=k40;M[1,2]:=k30;M[1,3]:=k20;
		M[2,1]:=k30;M[2,2]:=k20;M[2,3]:=k10;
		M[3,1]:=k20;M[3,2]:=k10;M[3,3]:=k00;
		if not math_overflow(xyz_matrix_determinant(M)) then begin
			M:=xyz_matrix_inverse(M);
			parabola:=M[1,1]*k21+M[1,2]*k11+M[1,3]*k01;
			slope:=M[2,1]*k21+M[2,2]*k11+M[2,3]*k01;
			intercept:=M[3,1]*k21+M[3,2]*k11+M[3,3]*k01;
		end else begin
			parabola:=0;
			slope:=0;
			intercept:=0;
		end;
		rms_residual:=0;
		for index:=0 to length(dp^)-1 do begin
			with dp^[index] do begin
				rms_residual:=rms_residual+sqr(x*x*parabola+x*slope+intercept-y);
			end;
		end;
		if length(dp^)<>0 then 
			rms_residual:=sqrt(rms_residual/length(dp^));
	end 
	else begin
		parabola:=0;
		slope:=0;
		if length(dp^)=1 then intercept:=dp^[0].y
		else intercept:=0;
		rms_residual:=0;
	end;
	check_for_math_error(parabola);
	check_for_math_error(slope);
	check_for_math_error(intercept);
end;

{
	slope_x_graph calculates the slope of a sub-section of a one-dimensional
	signal, where we treat each sample index as a unit of distance, so that
	the sample zero is at position (gp^[0],0), sample one at (gp^[1],1), and 
	so on. The slope calculation is centered on sample index and is calculated
	over samples index-extent to index+extent.
}
function slope_x_graph(gp:x_graph_ptr;index,extent:integer):real;

const
	min_num_points=2;

var 
	i,lo,hi:integer;	
	k00,k10,k01,k11,k20,slope:real;
	
begin 
	slope_x_graph:=0;
	if length(gp^)<min_num_points then exit;
	
	lo:=index-extent;
	if lo<0 then lo:=0;
	hi:=index+extent;
	if hi>length(gp^)-1 then hi:=length(gp^)-1;
	if hi-lo<min_num_points then exit;

	slope:=0;
	k00:=0;k10:=0;k01:=0;k11:=0;k20:=0;
	for i:=lo to hi do begin
		k00:=k00+1;
		k10:=k10+i;
		k01:=k01+gp^[i];
		k11:=k11+i*gp^[i];
		k20:=k20+i*i;
	end;	
	
	if (k20*k00-k10*k10 <> 0) then
		slope:=(k11*k00-k01*k10)/(k20*k00-k10*k10)
	else
		slope:=0;
	check_for_math_error(slope);
	slope_x_graph:=slope;
end;

{
	weighted_straight_line_fit acts as straight_line_fit, but it takes in 
	three-dimensional data: x,y and z. The first two are the points in the 
	line, and the last, z, is the weighting factor the routine should apply 
	to the point in the fit. This weighting factor must be greater than or
	equal to zero. If it is equal to the ignore_remaining_data constant, which
	is negative, then weighted_straight_line fit ignores the rest of the
	data in the graph.
}
procedure weighted_straight_line_fit (dp:xyz_graph_ptr;
	var slope,intercept,rms_residual:real);

const
	min_num_points=2;

var 
	index,num_points_used:integer;	
	k00,k10,k01,k11,k20:real;
	
begin 
	slope:=0;intercept:=0;rms_residual:=0;
	if length(dp^)>=min_num_points then begin
		k00:=0;k10:=0;k01:=0;k11:=0;k20:=0;
		for index:=0 to length(dp^)-1 do begin
			with dp^[index] do begin
				if (z=ignore_remaining_data) then break;
				k00:=k00+z;
				k10:=k10+x*z;
				k01:=k01+y*z;
				k11:=k11+x*y*z;
				k20:=k20+x*x*z;
			end;
		end;	
		num_points_used:=index;
		if num_points_used>min_num_points then begin
			if (k20*k00-k10*k10 <> 0) then begin
				slope:=(k11*k00-k01*k10)/(k20*k00-k10*k10);
				intercept:=(k01*k20-k11*k10)/(k20*k00-k10*k10);
			end else begin
				slope:=0;
				intercept:=0;
			end;
			rms_residual:=0;
			for index:=0 to num_points_used-1 do 
				with dp^[index] do 
					rms_residual:=rms_residual+z*sqr(y-x*slope-intercept);
			if k00>0 then rms_residual:=sqrt(rms_residual/k00)
		end else 
			if num_points_used=1 then intercept:=dp^[0].y
	end 
	else begin
		slope:=0;
		if length(dp^)=1 then intercept:=dp^[0].y
		else intercept:=0;
		rms_residual:=0;
	end;
	check_for_math_error(slope);
	check_for_math_error(intercept);
end;

{
	linear_interpolate returns the value obtained by interpolating between
	the two nearest data points in a graph pointed to by dp. The data points
	do not have to be in ascending order in the graph.
}
procedure linear_interpolate(dp:xy_graph_ptr;position:real; 
	var result:real);

const
	min_num_points=2;

var
	index,lower_index,upper_index:integer;
	
begin
	if length(dp^)<min_num_points then begin
		if length(dp^)>0 then result:=dp^[0].y
		else result:=0;
	end else begin
		lower_index:=0;
		upper_index:=0;
		for index:=1 to length(dp^)-1 do begin
			if (dp^[lower_index].x<=dp^[index].x) 
					and (dp^[index].x<=position) then
				lower_index:=index
			else if (position<dp^[lower_index].x)
					and (dp^[index].x<dp^[lower_index].x) then
				lower_index:=index;
			if (dp^[upper_index].x>=dp^[index].x) 
					and (dp^[index].x>=position) then
				upper_index:=index
			else if (position>dp^[upper_index].x)
					and (dp^[index].x>dp^[upper_index].x) then
				upper_index:=index;
		end;
		if (dp^[upper_index].x<>dp^[lower_index].x) then
			result:=(position-dp^[lower_index].x)
					*(dp^[upper_index].y-dp^[lower_index].y)
					/(dp^[upper_index].x-dp^[lower_index].x)
					+dp^[lower_index].y
		else result:=dp^[lower_index].y;
	end;
end;

{
	new_matrix returns a matrix with the specified number of rows and columns,
	which will be addressed as rows 1 to num_rows and 1 to num_columns. The
	matrix data structure contains row and column zero, but we don't use these.
	The new_matrix routine sets all elements of the matrix to zero.
}
function new_matrix(num_rows,num_columns:integer):matrix_type;
var 
	M:matrix_type;
	i,j:integer;
begin
	setlength(M,num_rows+1,num_columns+1);
	for j:=1 to num_rows do
		for i:=1 to num_columns do
			M[j,i]:=0;
	new_matrix:=M;
end;

{
	matrix_rows returns the number of rows in a matrix. This number is not
	necessarily the same as the length of the array of rows in the matrix
	variable. We implement matrices with two-dimensional dynamic arrays. Each
	row is an array of real numbers, and the matrix is an array of rows. But the
	FPC dynamic arrays are constrained to have low index zero, while we want to
	refer to rows 1..n in a matrix with n rows. Thus the matrix variable
	contains n+1 row arrays, and we use only those with index 1..n. So the
	routine below returns the highest row number, assuming the first row is row
	number one. We pass the matrix as a variable parameter to make certain that
	we don't copy the matrix when calling this routine. In FPC, no such copy
	would take place in any case, because a matrix is a dynamic variable with a
	reference count, so apparent copies are merely duplicate references to the
	same data structure. In order to make a real copy of a matrix, we have to
	create a new matrix and copy each element individually, as in the
	copy_matrix routine.
}
function matrix_rows(var A:matrix_type):integer;
begin 
	matrix_rows:=length(A)-1; 
end;

{
	matrix_columns is like matrix_rows, but for the number of columns.
}
function matrix_columns(var A:matrix_type):integer;
begin 
	matrix_columns:=length(A[0])-1; 
end;

{
	unit_matrix returns a square unit matrix of num_rows rows. It sets
	the diagonal elements to 1 and all others to 0.
}
function unit_matrix(num_rows:integer):matrix_type;
var 
	M:matrix_type;
	i,j:integer;
begin
	M:=new_matrix(num_rows,num_rows);
	for j:=1 to num_rows do
		for i:=1 to num_rows do
			if (i=j) then M[j,i]:=1 else M[j,i]:=0;
	unit_matrix:=M;
end;

{
	matrix_copy returns a copy of matrix A. This copy is a duplicate dynamic
	array in memory, with its own location and reference count. In FPC, we cannot
	obtain a copy of A by use of B:=A when A is a dynamic array like a matrix,
	because this results only in a duplicate pointer reference to the dynamic
	array stored in B.
}
function matrix_copy(var A:matrix_type):matrix_type;
var
	M:matrix_type;
	i,j,num_rows,num_columns:integer;
begin
	num_rows:=matrix_rows(A);
	num_columns:=matrix_columns(A);
	M:=new_matrix(num_rows,num_columns);
	for j:=1 to num_rows do
		for i:=1 to num_columns do
			M[j,i]:=A[j,i];
	matrix_copy:=M;
end;

{
	swap_matrix_rows exchanges two rows in a matrix. In FPC, we make sure
	that the elements of are moved individually, so as to avoid creating
	duplicate references to the same row array, rather than copying the
	elements of one row into another row.
}
procedure swap_matrix_rows(var M:matrix_type;row_1,row_2:integer);
var
	a,b:real;
	i:integer;	
begin
	for i:=1 to matrix_columns(M) do begin
		a:=M[row_1,i];
		b:=M[row_2,i];
		M[row_1,i]:=b;
		M[row_2,i]:=a;
	end;
end;

{
	matrix_product returns the product of A and B, in the order A.B. It checks that
	the number of columns in A is equal to the number of rows in B.
}
function matrix_product(var A,B:matrix_type):matrix_type;

var
	M:matrix_type;
	i,j,k:integer;
	sum:real;

begin
	M:=new_matrix(matrix_rows(A),matrix_columns(B));

	if (matrix_columns(A)<>matrix_rows(B)) then begin
		report_error('(matrix_columns(A)<>matrix_rows(B))  in matrix_product.');
		matrix_product:=M;
		exit;
	end;
	
	for j:=1 to matrix_rows(A) do begin
		for i:=1 to matrix_columns(B) do begin
			sum:=0;
			for k:=1 to matrix_columns(A) do
				sum:=sum+A[j,k]*B[k,i];
			M[j,i]:=sum;
		end;
	end;
	
	matrix_product:=M;
end;

{
	matrix_difference returns A-B.
}
function matrix_difference(var A,B:matrix_type):matrix_type;

var
	M:matrix_type;
	i,j:integer;
	
begin
	M:=new_matrix(matrix_rows(A),matrix_columns(A));

	if (matrix_rows(A)<>matrix_rows(B)) or
			(matrix_columns(A)<>matrix_columns(B)) then begin
		report_error('Mismatched matrices in matrix_difference.');
		matrix_difference:=M;
		exit;
	end;
	
	for j:=1 to matrix_rows(A) do begin
		for i:=1 to matrix_columns(A) do begin
			M[j,i]:=A[j,i]-B[j,i];
		end;
	end;
	
	matrix_difference:=M;
end;

{
	matrix_inverse attempts to return the inverse of A. If A is of full rank,
	the routine will succeed. But if A is not of full rank, the inverse will
	contain one or more rows of zeros. You can check the global variable
	matrix_rank_saved for the rank of the matrix, and matrix_determinant_saved
	for its determinant. Both these will be valid at the end of matrix_inverse.

	The routine uses Gausse-Jordan elimination to calculate the inverse matrix.
	The execution time of Gauss-Jordan elimination for randomly-populated
	matrices is of order n^3, where n is the number of rows and columns in the
	matrix.

	We measured matrix_inverse's execution time in the following way. For
	various values of n, we generated an nxn matrix containing random
	real-valued elements between -2.5 and +2.5. We inverted this matrix 100
	times. We generated a new random matrix, and inverted that 100 times, and so
	on, until we occupied the microprocessor for several seconds with all the
	inversions combined. We measured the total execution time and divided by the
	total number of inversions to obtain our estimate of a single inversion
	time. We compiled the matrix inverter with the GPC -O3 optimization and ran
	the test on a 1GHz iBook G3.
	
	n		time (us)	time/n*n*n (us)
	3		10			0.37		
	5		22			0.18
	7		53			0.15
	10		100			0.10			
	14		250			0.09
	20		820			0.10
	30		2300		0.09
	40		6000		0.09
	70		26000		0.08
	100		70000		0.07
	1000	130000000	0.13

	As we can see from the table, the execution time for n>70 is proportional to
	the third power of n. For smaller values of n, the time it takes to allocate
	space for the new matrix and populate the test matrix with random elements,
	is significant compared to the inversion time.

	We run the Matlab matrix inverter on a 100x100 matrix with random elements
	as above, on a PowerBook G4 and its execution time was 50 ms.

	When we translate from GPC to FPC we make the following observations of the
	average inversion time on the same PowerBook Pro 2.3 GHz running MacOSX,
	Windows, and Linux. We are using the -O3 optimization flag for all platforms
	and both compilers.
	
	n      OS       32/64    GPC/FPC  t (ms)
	100    MacOS    32        GPC       17
	100    MacOS    64        FPC       3.1
	100    Linux    32        GPC       16
	100    Linux    64        GPC       11
	100    Linux    64        FPC       3.2
	100    Windows  32        GPC       16
	100    Windows  64        FPC       3.0
	
	When we moved from pointer-based handling of matrices to dynamic arrays with
	reference counts, we saw no significant change in execution time.
}
function matrix_inverse(var A:matrix_type):matrix_type;

var
	n,rank:integer;
	M,B:matrix_type;
	determinant:real;

{
	swap exchanges row j with a row that contains the best available pivot element 
	in the i'th column of B.
}
	procedure swap(j,i:integer);
	var l,j_best:integer;
	begin
		j_best:=j;
		for l:=1 to n do 
			if abs(B[l,i]) > abs(B[j_best,i]) then
				if (l>j) or ((l<j) and (B[l,l]=0)) then 
					j_best:=l;
		if j_best<>j then begin
			swap_matrix_rows(M,j,j_best);
			swap_matrix_rows(B,j,j_best);
			determinant:=-determinant;
		end;
	end; 
	
{
	zero makes ill-conditioning in the matrix apparent to the elimination
	algorithm by setting certain small elements in column i of B to zero. The
	procedure assumes that there is no avilable pivot element in the i'th
	column.
}
	procedure zero(j,i:integer);
	var l:integer;
	begin
		for l:=1 to j-1 do 
			if (B[l,l]=0) then B[l,i]:=0;
		for l:=j to n do B[l,i]:=0;
	end;

var
	j,i,l:integer;
	factor:real;
	
begin
{
	Set the global variables.
}
	matrix_rank_saved:=0;
	matrix_determinant_saved:=0;
{
	Set the starting rank and determinant.
}
	rank:=0;
	determinant:=1;
	i:=1;
{
	We use n as an abbreviation for matrix_rows(A) = matrix_columns(A).
}
	n:=matrix_rows(A);
{
	Copy A to B and set M to the unit matrix. 
}
	B:=matrix_copy(A);
	M:=unit_matrix(n);
{
	Check that A is square. If not, report an error and return the unit matrix.
}
	if (matrix_columns(A)<>n) then begin
		report_error('matrix not square in matrix_inverse.');
		matrix_inverse:=M;
		exit;
	end;
{
	Diagonalize B, which is a copy of A, using Gauss-Jordan elimination, while
	at the same time applying every operation to M. When B is diagonalized, M
	will be a linear multiple of the inverse of A.
}
	for j:=1 to n do begin
		swap(j,j);
		if abs(B[j,j])>small_real then begin
			for l:=1 to n do begin
				if (l<>j) then begin
					factor:=B[l,j]/B[j,j];
					for i:=1 to n do begin
						M[l,i]:=M[l,i]-factor*M[j,i];
						B[l,i]:=B[l,i]-factor*B[j,i];
					end;
					B[l,j]:=0;{avoid rounding errors}
				end
			end;
		end 
		else zero(j,j);
	end;
{
	Normalize B to the unit matrix, so M becomes the inverse of A, if such exists, and
	calculate the rank and determinant of the matrix.
}
	for j:=1 to n do begin
		if abs(B[j,j])>small_real then begin
			inc(rank);
			factor:=B[j,j];
			determinant:=determinant*factor;
			for i:=1 to n do begin
				M[j,i]:=M[j,i]/factor;
				B[j,i]:=B[j,i]/factor;
			end;
			B[j,j]:=1;{avoid rounding errors}
		end else B[j,i]:=0;
	end;
	if (rank<n) then determinant:=0;
{
	Store the matrix rank and determinant in global variables, and return the inverse.
}
	matrix_determinant_saved:=determinant;
	matrix_rank_saved:=rank;
	matrix_inverse:=M;
end;

{
	matrix_determinant calls matrix_inverse and returns 0 if the rank
	of the input matrix is less than its size. Otherwise it returns
	whatever matrix_inverse arrives at for the determinant.
}
function matrix_determinant(var A:matrix_type):real;

var
	determinant:real;
	B:matrix_type;

begin
	if matrix_rows(A)=matrix_columns(A) then begin
		B:=matrix_inverse(A);
		if matrix_rank_saved=matrix_rows(B) then 
			determinant:=matrix_determinant_saved 
		else 
			determinant:=0;
	end else 
		determinant:=0;
	matrix_determinant:=determinant;
end;

{
	nearest_neighbor takes an N-dimensional point, p, and
	finds the nearest point to it in a library of N-dimensional
	points. We use matrix structures to store the point and
	the list. The point is a matrix of one row and N columns.
	The list is a matrix with M rows and n columns, where M
	is the number of points in the list. 
}
function nearest_neighbor(var point,lib:matrix_type):integer;

var 
	separation,min_separation:real;
	i,j,min_j:integer;
	
begin
	nearest_neighbor:=0;
	min_j:=0;
	
	if matrix_rows(point)<>1 then begin
		report_error('cannot specify more than one point in nearest_neighbor');
		exit;
	end;
	if matrix_rows(lib)<1 then begin
		report_error('empty library in in nearest_neighbor');
		exit;
	end;
	if matrix_columns(point)<>matrix_columns(lib) then begin
		report_error('mismatch between dimensions of point and library in nearest_neighbor');
		exit;
	end;
	
	min_separation:=-1;
	for j:=1 to matrix_rows(lib) do begin
		separation:=0;
		for i:=1 to matrix_columns(point) do
			separation:=separation+sqr(point[1,i]-lib[j,i]);
		if (separation<min_separation) or (min_separation<0) then begin
			min_separation:=separation;
			min_j:=j;
		end;
	end;
	
	nearest_neighbor:=min_j;
end;

{
	xyz_matrix_determinant returns the determinant of a 3x3 matrix.
}
function xyz_matrix_determinant(A:xyz_matrix_type):real;
var determinant:real;
begin
	determinant:=
		A[1,1]*(A[2,2]*A[3,3]-A[2,3]*A[3,2])
		-A[1,2]*(A[2,1]*A[3,3]-A[2,3]*A[3,1])
		+A[1,3]*(A[2,1]*A[3,2]-A[2,2]*A[3,1]);
	xyz_matrix_determinant:=determinant;
end;

{
	xyz_matrix_inverse inverts a 3x3 matrix for geometry calculations.
	We could use matrix_inverse, and dynamically-allocated 3x3 matrices,
	but the time taken by the dynamic allocation of space for the
	matrices is far greater than the time taken to invert them (see data
	in the comments for matrix_inverse). This routine uses stack
	variables and a direct formula for the inverse of a 3x3 matrix for
	faster execution. If you pass it an ill-conditioned matrix, it
	returns a unit matrix and sets matrix_rank equal to 0.

	Execution time for this routine, when compiled with the GPC -O3
	option, and executed on a 1GHz iBook with matrices containing random
	elements between values -2.5 and +2.5 is only 1.5 us, compared to 8
	us for matrix_inverse with a 3x3 matrix.
}
function xyz_matrix_inverse(A:xyz_matrix_type):xyz_matrix_type;

var
	B:xyz_matrix_type;
	i,j,rank:integer;
	determinant:real;
	
begin
	matrix_determinant_saved:=0;
	matrix_rank_saved:=0;
	
	determinant:=
		A[1,1]*(A[2,2]*A[3,3]-A[2,3]*A[3,2])
		-A[1,2]*(A[2,1]*A[3,3]-A[2,3]*A[3,1])
		+A[1,3]*(A[2,1]*A[3,2]-A[2,2]*A[3,1]);
		
	if abs(determinant)>small_real then begin
		rank:=num_xyz_dimensions;
		B[1,1]:=(A[2,2]*A[3,3]-A[2,3]*A[3,2])/determinant;
		B[1,2]:=(A[1,3]*A[3,2]-A[1,2]*A[3,3])/determinant;
		B[1,3]:=(A[1,2]*A[2,3]-A[1,3]*A[2,2])/determinant;
		B[2,1]:=(A[2,3]*A[3,1]-A[2,1]*A[3,3])/determinant;
		B[2,2]:=(A[1,1]*A[3,3]-A[1,3]*A[3,1])/determinant;
		B[2,3]:=(A[1,3]*A[2,1]-A[1,1]*A[2,3])/determinant;
		B[3,1]:=(A[2,1]*A[3,2]-A[2,2]*A[3,1])/determinant;
		B[3,2]:=(A[1,2]*A[3,1]-A[1,1]*A[3,2])/determinant;
		B[3,3]:=(A[1,1]*A[2,2]-A[1,2]*A[2,1])/determinant;
	end else begin 
		report_error('Matrix inversion failed on singular matrix.');
		rank:=0;
		determinant:=0;
		for j:=1 to num_xyz_dimensions do
			for i:=1 to num_xyz_dimensions do
				if i=j then B[j,i]:=1
				else B[j,i]:=0;
	end;
	
	
	matrix_determinant_saved:=determinant;
	matrix_rank_saved:=rank;
	xyz_matrix_inverse:=B;
end;

{
	xyz_matrix_difference is a fast 3x3 version of matrix_difference.
	It returns A - B.
}
function xyz_matrix_difference(A,B:xyz_matrix_type):xyz_matrix_type;
var i,j:integer; C:xyz_matrix_type;
begin
	for j:=1 to num_xyz_dimensions do
		for i:=1 to num_xyz_dimensions do
			C[j,i]:=A[j,i]-B[j,i];
	xyz_matrix_difference:=C;
end;

{
	xyz_matrix_from_points takes three xyz_point_types and makes them the rows 
	of an xyz matrix. It returns a pointer to this new matrix.	
}
function xyz_matrix_from_points(p,q,r:xyz_point_type):xyz_matrix_type;
var M:xyz_matrix_type;
begin
	M[1,1]:=p.x;
	M[1,2]:=p.y;
	M[1,3]:=p.z;
	M[2,1]:=q.x;
	M[2,2]:=q.y;
	M[2,3]:=q.z;
	M[3,1]:=r.x;
	M[3,2]:=r.y;
	M[3,3]:=r.z;
	xyz_matrix_from_points:=M;
end;

{
	new_simplex creates a new simplex fitting structure to operate in a space
	with "num_coords" coordinates. We use "n" for the number of coordinates in
	our code, and store the "n" in the simplex array for convenience. We fill
	the structure with some nominal values. The routine returns the structure,
	which is a dynamic array, and so will be returned as a pointer to the
	structure in memory, and the structure itself will keep a reference count so
	that when it is no longer being referred to, the process will dispose of the
	structure. Because our FPC dynamic array must start with index 0, but we
	want to work with 1..n for coordinates and 1..n+1 for vertices, we will make
	the vertex an array of size n+1, giving us elements 0..n, and using 1..n.
	For the vertices of the simplex shape, we will allow size n+2 so we can have
	elements 0..n+1.
}
function new_simplex(num_coords:integer):simplex_type;

var
	s:simplex_type;
	i:integer;
	
begin
	with s do begin
		n:=num_coords;
		setlength(vertices,n+2,n+1);
		setlength(errors,n+2);
		for i:=1 to n do vertices[1,i]:=0;
		construct_size:=1;
		done_counter:=0;
		max_done_counter:=10;
	end;
	new_simplex:=s;
end;

{
	simplex_vertex_copy creates a new vertex dynamic array and copies the
	elements of the original vertex into the new one. We cannot use the
	assignment operator to make copies of dynamic arrays in FPC, because the
	dynamic arrays are referenced variables and copying merely creates a copy of
	the pointer to the variable. We don't bother copying the 0'th element
	because we don't use that element.
}
function simplex_vertex_copy(var a:simplex_vertex_type):simplex_vertex_type;
var 
	v:simplex_vertex_type;
	i:integer;
begin
	setlength(v,length(a));
	for i:=1 to length(v)-1 do
		v[i]:=a[i];
	simplex_vertex_copy:=v;
end;

{
	simplex_construct constructs a new simplex with sides of length side_length.
	We assume that the first element in the simplex is already set. We
	re-calculate the error array using an error function. This function
	takes a vertex and a generic pointer, so we pass the pointer into
	simplex_construct as well. The simplex_construct routine makes no use of the
	pointer other than to pass it into the error function, where the pointer
	allows the error function to find the values it needs to determine its
	result.
}
procedure simplex_construct(var simplex:simplex_type;
	error:simplex_error_function_type;
	ep:pointer);

var 
	i:integer;

begin
	with simplex do begin
		for i:=2 to n+1 do begin
			vertices[i]:=simplex_vertex_copy(vertices[1]);
			vertices[i,i-1]:=vertices[i,i-1]+construct_size;
		end;
		for i:=1 to n+1 do errors[i]:=error(vertices[i],ep);
	end;
end;

{
	simplex_volume returns the volume of the current simplex.
}
function simplex_volume(var simplex:simplex_type):real;

var
	M:matrix_type;
	i,j:integer;

begin
	with simplex do begin
		M:=new_matrix(n,n);
		for j:=1 to n do begin
			for i:=1 to n do begin
				M[j,i]:=vertices[j+1,i]-vertices[1,i];
			end;
		end;
	end;
	simplex_volume:=abs(matrix_determinant(M));
end;

{
	simplex_size returns the length of the longest side in a simplex.
}
function simplex_size(var simplex:simplex_type):real;

var
	i,j,k:integer;
	max,s:real;

begin
	max:=0;
	with simplex do begin
		for j:=1 to n do begin
			for k:=j+1 to n+1 do begin
				s:=0;
				for i:=1 to n do 
					s:=s+sqr(vertices[j,i]-vertices[k,i]);
				if s>max then max:=s;
			end;
		end;
	end;
	simplex_size:=sqrt(max);
end;

{
	Sort the simplex vertices into order of ascending error. We use
	quick-sort so we can be efficient when the simplex dimension is large.
	The simplex sort provides its own swap and after functions, which are
	here declared globally within the unit implementation.
}
function simplex_sort_after(i,j:integer;lp:pointer):boolean;
begin 
	with simplex_ptr(lp)^ do begin
		simplex_sort_after:=(errors[i]>errors[j]);
	end;
end;
procedure simplex_sort_swap(i,j:integer;lp:pointer);
var
	v:simplex_vertex_type;
	a:real;
begin
	with simplex_ptr(lp)^ do begin
		v:=simplex_vertex_copy(vertices[i]);
		a:=errors[i];
		vertices[i]:=simplex_vertex_copy(vertices[j]);
		errors[i]:=errors[j];
		vertices[j]:=simplex_vertex_copy(v);
		errors[j]:=a;	
	end;
end;
procedure simplex_sort(var simplex:simplex_type);
begin
	quick_sort(1,simplex.n+1,simplex_sort_swap,simplex_sort_after,@simplex);
end;

{
	simplex_step is the kernel of our simplex fitting algorithm. It takes one
	simplex step, whereby a simplex shape in the fitting space is either
	reflected, extended, or contracted. As the fit converges, we re-construct
	the simplex to make sure we don't get stuck in a false convergance. The
	routine takes an n-dimensional simlex_type that holds the n+1 vertices of
	the simplex shape, as well as some counters, limits, and the errors of
	the vertices. In addition, it takes an error function and a generic
	pointer. The error function is provided by the process that uses the
	simplex fit: it returns the alititude of a vertex. We pass the error
	function the vertex and the generic pointer. The generic pointer allows the
	alitutude function to function to find the information it needs to determine
	the error of the vertex. The simplex_step routine does not use the
	pointer at all.
}
procedure simplex_step(var simplex:simplex_type;
	error:simplex_error_function_type;
	ep:pointer);

	procedure add(var a,b:simplex_vertex_type);
	var i:integer; begin for i:=1 to simplex.n do a[i]:=a[i]+b[i]; end;
	procedure subtract(var a,b:simplex_vertex_type);
	var i:integer; begin for i:=1 to simplex.n do a[i]:=a[i]-b[i]; end;
	procedure scale(var a:simplex_vertex_type;s:real);
	var i:integer; begin for i:=1 to simplex.n do a[i]:=a[i]*s; end;

const
	expand_scale=2;
	contract_scale=0.5;
	shrink_scale=0.5;
	report=false;
	small_size_factor=1e-5;
	
var 
	i,j:integer;
	v,v_center,v_contract,v_expand,v_reflect:simplex_vertex_type;
	a_reflect,a_contract,a_expand:real;
	
begin
{
	Set up the vertex variables we will use to perform the fitting. We must
	make sure that each is an independent dynamic array, so we set their
	lengths in separate instructions.
}
	v:=simplex_vertex_copy(simplex.vertices[1]);
	v_center:=simplex_vertex_copy(simplex.vertices[1]);
	v_contract:=simplex_vertex_copy(simplex.vertices[1]);
	v_expand:=simplex_vertex_copy(simplex.vertices[1]);
	v_reflect:=simplex_vertex_copy(simplex.vertices[1]);
{
	Sort the vertices in ascending error.
}
	simplex_sort(simplex);
{	
	Determine the center of mass of the first n vertices. The one remaining
	vertex, number n+1, is at the highest error following the sort.
}
	with simplex do begin
		v_center:=simplex_vertex_copy(vertices[1]);
		for i:=2 to n do add(v_center,vertices[i]);
		scale(v_center,1.0/n);
{
	Reflect the highest vertex through the center of mass of the others.
}
		v:=simplex_vertex_copy(v_center);
		subtract(v,vertices[n+1]);
		add(v,v_center);
		v_reflect:=v;
		a_reflect:=error(v_reflect,ep);
{
	If the error of the new vertex is somewhere between that of the the first
	n vertices, we keep it in place of the worst vertex.
}
		if (a_reflect>=errors[1]) and (a_reflect<errors[n]) then begin
			vertices[n+1]:=simplex_vertex_copy(v_reflect);
			errors[n+1]:=a_reflect;
			if show_details then gui_writeln('r: '+string_from_real(a_reflect,fsr,fsd));
		end;
{
	If the error of this new vertex is lower than all the other vertices, we
	try to expand our reflection in the hope of getting an even lower error.
	Otherwise we go back to the original reflected vertex and use is to replace
	the highest vertex.
}
		if (a_reflect<errors[1]) then begin
			v:=simplex_vertex_copy(v_center);
			subtract(v,vertices[n+1]);
			scale(v,expand_scale);
			add(v,v_center);
			v_expand:=simplex_vertex_copy(v);
			a_expand:=error(v_expand,ep);
			if a_expand<a_reflect then begin
				vertices[n+1]:=simplex_vertex_copy(v_expand);
				errors[n+1]:=a_expand;
				if show_details then gui_writeln('re: '+string_from_real(a_expand,fsr,fsd));
			end else begin
				vertices[n+1]:=simplex_vertex_copy(v_reflect);
				errors[n+1]:=a_reflect;
				if show_details then gui_writeln('rl: '+string_from_real(a_reflect,fsr,fsd));
			end;
		end;
{
	If the reflected vertex is higher than all the others, we contract the
	simplex by moving the highest original verticex towards the center of mass
	of the others. If the contracted vertex is lower than the highest original
	vertex, we accept the contracted vertex and reject the highest original
	vertex. Otherwise, we have encountered a double-ridge and we must do
	something to get going again. We can shrink the entire simplex or
	re-construct a new one around the best vertex. The Nelder-Mead method
	proscribes the shrink. We have code to perform the shrink, but we find that
	re-constructing the simplex in this situation avoids convergeance in the
	wrong spot, so we use the re-construction instead of the shrinking. We
	enable the shrink code with the global simplex_enable_shrink flag.
}
		if (a_reflect>=errors[n]) then begin
			v:=simplex_vertex_copy(v_center);
			subtract(v,vertices[n+1]);
			scale(v,contract_scale);
			add(v,vertices[n+1]);
			v_contract:=simplex_vertex_copy(v);
			a_contract:=error(v_contract,ep);
			if a_contract<=errors[n+1] then begin
				vertices[n+1]:=simplex_vertex_copy(v_contract);
				errors[n+1]:=a_contract;
				if (simplex_size(simplex)<construct_size*small_size_factor) then 
					inc(done_counter);
				if show_details then gui_writeln('c: '+string_from_real(a_contract,fsr,fsd));
			end else begin
				if simplex_enable_shrink then begin
					for i:=2 to n+1 do begin
						subtract(vertices[i],vertices[1]);
						scale(vertices[i],shrink_scale);
						add(vertices[i],vertices[1]);
						errors[i]:=error(vertices[i],ep);
					end;
					if show_details then writeln('s: '+string_from_real(a_contract,fsr,fsd));
				end;
				inc(done_counter);
				if done_counter<max_done_counter then begin
					simplex_construct(simplex,error,ep);
					if show_details then gui_writeln('x: '+string_from_real(a_contract,fsr,fsd));
				end else if show_details then gui_writeln('d: '+string_from_real(a_contract,fsr,fsd));
			end;
		end;
	end;
{
	Sort the vertices in order of ascending error again.
}
	simplex_sort(simplex);
{
	When reporting, we print out the entire list of vertices with their errors.
}
	if show_details then with simplex do begin
		for i:=1 to n+1 do begin
			write(i,': ',errors[i],' ');
			for j:=1 to n do begin
				write(vertices[i,j]:1:6,' ');
			end;
			gui_writeln('');
		end;
	end;
end;

{
	calculate_ft_term calculates the amplitude and offset of the discrete
	fourier transform component with sinusoidal period "period". We express
	period as a real-valued multiple of the sample period, T. The special case
	of period=0 we use to determine the DC component of the waveform. We pass
	data to the routine in an array of real numbers, each of which represents a
	sample.

	If your waveform has a significant DC component, we recommend you subtract
	the DC component from its elements before you calculate other components,
	because the DC component has a second-order effect upon the phase of other
	components.

	This routine returns a single component as an amplitude and an offset. The
	offset is related to the phase by phase = -2*pi*offset/period. You obtain
	the sinusoidal component value at point x with
	amplitude*sin(2*pi*(x-offset)/period).

	If you want to calculate the entire discrete fourier transform, and you have
	data with N a power of 2, then you can try our fft routine, but note that it
	returns complex-valued terms, which you have to convert into amplitude and
	offset. This routine returns amplitude and offset if a format that is
	convenient for image analysis. 
}
procedure calculate_ft_term(period:real;
	var dp:x_graph_type;
	var amplitude,offset:real);

const
	scaling_factor=2;

var
	n:integer;
	phase_step,phase,a,b:real;

begin
	if (length(dp)<1) or (period<0) then exit;
	if (period=0) then begin
		phase:=0;
		amplitude:=average_x_graph(@dp);
	end else begin
		phase_step:=2*pi/period;
		phase:=0;
		a:=0;
		b:=0;
		for n:=0 to length(dp)-1 do begin
			a:=a+cos(phase)*dp[n];
			b:=b+sin(phase)*dp[n];
			phase:=phase+phase_step;
		end;
		offset:=-period*full_arctan(a,b)/(2*pi);
		amplitude:=sqrt(sqr(a)+sqr(b))*scaling_factor/length(dp);
	end;
	check_for_math_error(offset);
	check_for_math_error(amplitude);
end;

{
	frequency_component is like calculate_ft_term, but accepts a frequency as a
	multiple of the fundamental signal frequency, or 1/<i>NT</i>, where <i>T</i>
	is the sample period and <i>N</i> is the number of samples. It returns the
	amplitude and offset of a sine wave amplitude*sin(2*pi*(x-offset)*f/N). If
	you want to obtain a true complex-valued discrete fourier transform, try our
	fft routine.
}
procedure frequency_component(frequency:real;
	var dp:x_graph_type;
	var amplitude,offset:real);

const
	scaling_factor=2;

var
	n:integer;
	phase_step,phase,a,b:real;

begin
	amplitude:=0;
	offset:=0;
	if (length(dp)<1) then exit;
	phase_step:=2*pi*frequency/length(dp);
	phase:=0;
	a:=0;
	b:=0;
	for n:=0 to length(dp)-1 do begin
		a:=a+cos(phase)*dp[n];
		b:=b+sin(phase)*dp[n];
		phase:=phase+phase_step;
	end;
	amplitude:=sqrt(sqr(a)+sqr(b))*scaling_factor/length(dp);
	if frequency<>0 then offset:=-length(dp)*full_arctan(a,b)/(2*pi*frequency);
	check_for_math_error(offset);
	check_for_math_error(amplitude);
end;

{
	fft is a Fast Fourier Transform routine for determining the discrete fourier
	transform in Nlog(N) time by a divide-and-conquer algorithm due to Colley
	and Tokey. The routine operates in the complex plane, taking complex input
	data and producting complex transform components.

	fft takes a complex-valued sequence of N data points and returns the N
	complex-valued components that make up its complete discrete fourier
	transform. The routine takes its data in an xy_graph and returns the
	transform in another xy_graph. The routine is reversible also: if you pass
	the transform back to fft, you will re-construct the original data. Each
	term dp^[k] in the data is a complex number. The k'th term represents the
	k'th sample, with the samples being numbered 0 to N-1. The real part of the
	term is dp^[k].x and the imaginary part is dp^[k].y. When the data is a
	real-valued sequence of samples, the imaginary components are all zero. Each
	term in the output is likewise a complex number. The k'th term represents a
	sinusoidal function with frequency k/NT, where T is the sample period. The
	magnitude of the complex number is the amplitude of the sinusoidal component
	and argument of the complex number is the phase of the sinusoidal component.
	Using x and y for the real and imaginary parts of the complex component, the
	sinusoidal amplitude is a = sqrt(sqr(x))+sqr(y)) and the sinusoidal phase is
	p = full_arctan(y/x)). The component itself has value a*cos(2*pi*k*n/N -
	p), at time nT. The component is a cosine delayed by the phase.

	The fft_step implements the Cooley-Tukey FFT algorithm. The fft routine
	calls fft_step, and fft_step calls itself recursively. The recursion does
	not involve the allocation of new arrays because they all share the same
	memory. The routine sets up a transform array and a scratch array, each of N
	complex elements. It stores the evolving transform in the transform array,
	but performs the merging of odd and even components in the scratch array.

	We applied fft to sets of real-valued samples and measured execution time on
	an iBook G4 1.33 GHz by calculating the fft a hundred times and dividing the
	total execution time by 100. We obtained the following results for ascending
	values of N.
	
	N		Time (ms)
	64		0.28
	128		1.2
	256		2.2
	512		3.7
	1024	8.1
	2048	15
	4096	33

	We can use the fft routine to perform an inverse-transform also. Take the
	discrete fourier transform the routine produces and reverse the order of its
	terms, so that X(k) -> X(N-k), but note that X(N) = X(0) so the first term
	remains in place.
}
function fft(var dp:xy_graph_type):xy_graph_type;

var
	tp,sp:xy_graph_type;

{
	The fft_step routine is the heart of the fft procedure. It implements the
	Cooley-Tukey algorithm, calling itself recursively. In each call, fft_step
	divides the transform job into two parts, each of half the size, and
	therefore one quarter the execution time. The first half consists of the
	transform of the odd-numbered samples. The second half is the transform of
	the even-numbered samples. The routine is complicated by the shared use of
	an existing scratch and transform array, but this sharing is neccessary to
	avoid allocating new arrays on every recursive call. After determining the
	sub-transforms, fft_step merges them together. When fft_step is called on
	data of length 1, it returns as its answer the single data point. We say
	"returns", but what actuall happens is the data point is copied over into
	the transform array.
}
	procedure fft_step(step,start:integer);
	
	var
		k,i_new,i_odd,i_even,npd2,np:integer;
		sc:xy_point_type;
		
	begin
		np:=length(dp) div step;
		npd2:=np div 2;
		if np>1 then begin
			fft_step(step*2,start);
			fft_step(step*2,start+step);
			
			for k:=0 to npd2-1 do begin
				i_new:=start+k*step;
				sc.x:=cos(-2*pi*k/np);
				sc.y:=sin(-2*pi*k/np);
				i_even:=start+2*k*step;
				i_odd:=i_even+step;
				sp[i_new].x:=
					tp[i_even].x
					+sc.x*tp[i_odd].x-sc.y*tp[i_odd].y;
				sp[i_new].y:=
					tp[i_even].y
					+sc.x*tp[i_odd].y+sc.y*tp[i_odd].x;
				i_new:=i_new+npd2*step;
				sp[i_new].x:=
					tp[i_even].x
					-sc.x*tp[i_odd].x+sc.y*tp[i_odd].y;
				sp[i_new].y:=
					tp[i_even].y
					-sc.x*tp[i_odd].y-sc.y*tp[i_odd].x;				
			end;
			
			for k:=0 to np-1 do begin
				i_new:=start+k*step;
				tp[i_new]:=sp[i_new];
			end;
		end else begin
			tp[start]:=dp[start];
		end;
	end;

var
	i:integer;
	scale:real;

begin
{
	A nil pointer indicates a problem.
}
	setlength(fft,0);
{
	We insist upon at least one data point.
}
	if length(dp)<1 then begin
		report_error('length(dp)<1 in fft');
		exit;
	end;
{
	We insist upon a number of samples that is a perfect power of two.
}
	i:=length(dp);
	while ((i mod 2) = 0) do i:=i div 2;
	if (i>1) then begin
		report_error('length(dp) is not a power of two in fft');
		exit;
	end;
{
	We allocate space for our transform and for a scratch area, in which
	we will assemble intermediate transform components.
}
	setlength(tp,length(dp));
	setlength(sp,length(dp));
{
	Apply our recursive fft_step routine to the data.
}
	fft_step(1,0);
{
	Scale all the components by 1/N. At this point, we are sure that N>0.
}
	scale:=1/length(tp);
	for i:=0 to length(tp)-1 do begin
		tp[i]:=xy_scale(tp[i],scale);
	end;
{
	Dispose of the scratch area and return the completed transform.
}
	fft:=tp;
end;

{
	fft_inverse takes a complex-valued spectrum of the form generated by
	our fft routine (its components have been scaled by 1/N to give the 
	correct sinusoidal amplitudes) and calculates the complex-valued inverse
	transform. The routine accepts N components and produces N points, where
	N must be a power of two. The fft_inverse works by reversing the order
	of the N frequency components and feeding them into the fft routine. After
	that, we scale the resulting components by N so that they have the correct
	magnitude.
}
function fft_inverse(var ft:xy_graph_type):xy_graph_type;

var
	ftr,dp:xy_graph_type;
	k,n:integer;
	
begin
{
	A nil pointer indicates a problem.
}
	setlength(fft_inverse,0);
	if length(ft)<1 then exit;
{
	Create a reverse-order array.
}
	setlength(ftr,length(ft));
	for k:=0 to length(ft)-1 do
		ftr[k]:=ft[(length(ft)-k) mod length(ft)];
{
	Obtain the inverse-transform.
}
	dp:=fft(ftr);
	if length(dp)=0 then exit;
{
	Scale the points by N.
}
	for n:=0 to length(dp)-1 do 
		dp[n]:=xy_scale(dp[n],length(dp));
{
	Return the complex-valued data points.
}
	fft_inverse:=dp;
end;

{
	The fft_real function takes N real-valued samples in an x-graph and returns
	N/2 frequency components in an xy-graph. The frequency components are
	expressed as magnitude and phase, with phase in radians. The full discrete
	fourier transform (DFT), as implemented by our fft routine, produces N
	complex-valued components from N complex-valued data points. But when the
	data points are real-valued (their imaginary parts are all zero), we find
	that the k'th component is the complex conjugate of the (N-k)'th component.
	Meanwhile, the (N-k)'th component is equivalent to the -k'th component, and
	the -k'th component is the complex conjugate of the k'th component. So we
	find that, for real-valued inputs, the sum of the k'th and (N-k)'th
	components is twice the k'th component. Thus we don't bother returning the
	top N/2 components for real-valued inputs. We just return twice the first
	N/2 components.

	Each component has an amplitude, a, and a phase, p in radians. It represents
	a sinusoid given by a*cos(2*pi*k*n/N - p), at time nT. Each component is a
	cosine of amplitude a delayed by p radians. The 0'th component is an
	exception. In this case we return the magnitude of the 0'th component and
	the magnitude of the N/2'th component. The phase of these components is
	always 0 or pi, never anything in between, and we can represent phase 0 with
	a positive magnitude and phase pi with a negative. 
}
function fft_real(var dp:x_graph_type):xy_graph_type;

var 
	dpxy,ft:xy_graph_type;
	n,k:integer;
	
begin
{
	A nil pointer indicates a problem.
}
	setlength(fft_real,0);
	if length(dp)<=1 then exit;
{
	Copy our real data into a complex array.
}
	setlength(dpxy,length(dp));
	for n:=0 to length(dp)-1 do begin
		dpxy[n].x:=dp[n];
		dpxy[n].y:=0;
	end;
{
	Obtain the complex-valued transform.
}
	ft:=fft(dpxy);
	if length(ft)<0 then exit;
{
	Convert complex transform to compact magnitude-phase transform.
}
	setlength(dpxy,length(dp) div 2);
	dpxy[0].x:=ft[0].x;
	dpxy[0].y:=ft[length(dpxy)].x;
	for k:=1 to length(dpxy)-1 do begin
		dpxy[k].x:=2*xy_length(ft[k]);
		dpxy[k].y:=xy_bearing(ft[k]);
	end;
{
	Return the compact transform.
}
	fft_real:=dpxy;
end;

{
	fft_real_inverse takes a compact transform of N/2 components in
	magnitude-phase format, as produced by fft_real, and applies the inverse
	fourier transform to the components to produce N real-valued data points.
	The one complication in our compact format is that we specify the 0 and N/2
	components in the first element of the transform. The x-component of the
	first element is the 0-frequency magnitude, and the y-component is the
	N/2-frequency magnitude. The other components we specify with the amplitude
	and phase of a sinusoid. The phase, p, is such that we obtain the correct
	sinusoid with a*cos(2*pi*k*n/N - p). That is: we are passing into the
	inverse routine the amplitudes and phases of a set of cosine waves.
}
function fft_real_inverse(var ft:xy_graph_type):x_graph_type;

var
	ftxy,dpxy:xy_graph_type;
	dp:x_graph_type;
	k,n:integer;
	
begin
{
	A nil pointer indicates a problem.
}
	setlength(fft_real_inverse,0);
	if length(ft)<1 then exit;
{
	Convert the N/2 magnitude-phase components of the compact transform
	into a complex-valued series of N components.
}
	setlength(ftxy,2*length(ft));
	ftxy[0].x:=ft[0].x;
	ftxy[0].y:=0;
	for k:=1 to length(ft)-1 do begin
		ftxy[k].x:=ft[k].x/2*cos(ft[k].y);
		ftxy[k].y:=ft[k].x/2*sin(ft[k].y);
	end;
	ftxy[length(ft)].x:=ft[0].y;
	ftxy[length(ft)].y:=0;
	for k:=(length(ft)+1) to (2*length(ft)-1) do begin
		ftxy[k].x:=ftxy[2*length(ft)-k].x;
		ftxy[k].y:=-ftxy[2*length(ft)-k].y;
	end;
{
	Obtain the inverse transform.
}
	dpxy:=fft_inverse(ftxy);
{
	Extract real values.
}
	setlength(dp,length(dpxy));
	for n:=0 to length(dpxy)-1 do
		dp[n]:=dpxy[n].x;
{
	Return the result.
}
	fft_real_inverse:=dp;
end;

{
	2-D integer-valued geometry.
}
function ij_origin:ij_point_type;
var p:ij_point_type;
begin
	p.i:=0;
	p.j:=0;
	ij_origin:=p;
end;

function ij_axis_i:ij_line_type;
var l:ij_line_type;
begin
	l.a.i:=0;
	l.a.j:=0;
	l.b.i:=1;
	l.b.j:=0;
	ij_axis_i:=l;
end;

function ij_axis_j:ij_line_type;
var l:ij_line_type;
begin
	l.a.i:=0;
	l.a.j:=0;
	l.b.i:=0;
	l.b.j:=1;
	ij_axis_j:=l;
end;

function ij_separation(a,b:ij_point_type):real;
var x:real;
begin
	x:=sqr(a.i-b.i)+sqr(a.j-b.j);
	if x>0 then ij_separation:=sqrt(x)
	else ij_separation:=0;
end;

function ij_difference(a,b:ij_point_type):ij_point_type;
var d:ij_point_type;
begin
	d.i:=a.i-b.i;
		d.j:=a.j-b.j;
		ij_difference:=d;
end;

function ij_dot_product(a,b:ij_point_type):real;
begin
	ij_dot_product:=a.i*b.i+a.j*b.j;
end;

{
	ij_line_line_intersection determines the closest ij_point to 
	the intersection of two ij_lines. It calls the more general
	xy_line_line_intersection to obtain its result.
}
function ij_line_line_intersection(l1,l2:ij_line_type):ij_point_type;
var r1,r2:xy_line_type;p:xy_point_type;q:ij_point_type;
begin
	r1.a.x:=l1.a.i;r1.a.y:=l1.a.j;r1.b.x:=l1.b.i;r1.b.y:=l1.b.j;
	r2.a.x:=l2.a.i;r2.a.y:=l2.a.j;r2.b.x:=l2.b.i;r2.b.y:=l2.b.j;
	p:=xy_line_line_intersection(r1,r2);
	if (abs(p.x)<max_integer) and (abs(p.y)<max_integer) then begin
		q.i:=round(p.x);q.j:=round(p.y);
	end else begin
		if p.x>max_integer then q.i:=max_integer
		else if p.x<-max_integer then q.i:=-max_integer
		else q.i:=round(p.x);
		if p.y>max_integer then q.j:=max_integer
		else if p.y<-max_integer then q.j:=-max_integer
		else q.j:=round(p.y);
	end;
	ij_line_line_intersection:=q;
end;

{
	ij_in_rectangle returns true iff an ij point lies in or on the border of 
	an ij_rectangle.
}
function ij_in_rectangle(point:ij_point_type;rect:ij_rectangle_type):boolean;	
begin 
	with point,rect do
		ij_in_rectangle:=(i>=left) and (i<=right) and (j>=top) and (j<=bottom);
end;

{
	ij_clip_line clips a line defined by the two points of an ij_line_type to an 
	ij_rectangle_type. The routine returns outside true iff no portion of the line 
	lying between the two points lies in the specified ij_line_type cross the 
	rectangle. After ij_clip_line is done, the line contains two points both within
	the rectangle. If one end of the line passed to the routine was outside the
	rectangle, this end will be replaced by a point on the edge of the rectangle,
	where the line crossed the edge.
}
procedure ij_clip_line(var line:ij_line_type;var outside:boolean;clip:ij_rectangle_type);

const
	max_num_intersections=4;
	min_num_intersections=2;
	
var 
	num_intersections:integer;
	tl,tr,bl,br,k:ij_point_type;
	i:array [1..max_num_intersections] of ij_point_type;
	a_in,b_in:boolean;
	
	function intersection(a,b:ij_point_type):ij_point_type;
	var edge:ij_line_type;
	begin
		edge.a:=a;edge.b:=b;
		intersection:=ij_line_line_intersection(edge,line);
	end;

begin
	num_intersections:=0;
	tl.i:=clip.left;tl.j:=clip.top;
	tr.i:=clip.right;tr.j:=clip.top;
	bl.i:=clip.left;bl.j:=clip.bottom;
	br.i:=clip.right;br.j:=clip.bottom;
	i[1]:=ij_origin;
	i[2]:=ij_origin;
	a_in:=ij_in_rectangle(line.a,clip);
	b_in:=ij_in_rectangle(line.b,clip);
	if (line.a.i<>line.b.i) or (line.a.j<>line.b.j) then begin
		if a_in and b_in then begin
			outside:=false;
		end else begin
			if line.a.i=line.b.i then begin
				if (line.a.i>=clip.left) and (line.a.i<=clip.right) then begin
					inc(num_intersections);
					i[num_intersections]:=intersection(tl,tr);
					inc(num_intersections);
					i[num_intersections]:=intersection(bl,br);
				end;
			end;
			if line.a.j=line.b.j then begin
				if (line.a.j>=clip.top) and (line.a.j<=clip.bottom) then begin
					inc(num_intersections);
					i[num_intersections]:=intersection(tl,bl);
					inc(num_intersections);
					i[num_intersections]:=intersection(tr,br);
				end;
			end;
			if (line.a.i<>line.b.i) and (line.a.j<>line.b.j) then begin	
				k:=intersection(tl,tr);
				if ij_in_rectangle(k,clip) then begin
					inc(num_intersections);
					i[num_intersections]:=k;
				end;
				k:=intersection(tr,br);
				if ij_in_rectangle(k,clip) then begin
					inc(num_intersections);
					i[num_intersections]:=k;
				end;
				k:=intersection(br,bl);
				if ij_in_rectangle(k,clip) then begin
					inc(num_intersections);
					i[num_intersections]:=k;
				end;
				k:=intersection(bl,tl);
				if ij_in_rectangle(k,clip) then begin
					inc(num_intersections);
					i[num_intersections]:=k;
				end;
			end;
			if num_intersections>=min_num_intersections then begin
				if not a_in and not b_in then begin
					outside:=ij_dot_product(
						ij_difference(line.a,i[1]),
						ij_difference(line.b,i[1]))>=0;
					line.a:=i[1];
					line.b:=i[min_num_intersections];
				end;
				if a_in and not b_in then begin
					if (ij_separation(line.b,i[1])
							>ij_separation(line.b,i[min_num_intersections])) then 
								line.b:=i[min_num_intersections]
					else line.b:=i[1];
					outside:=false;
				end;
				if b_in and not a_in then begin
					if (ij_separation(line.a,i[1])
							>ij_separation(line.a,i[min_num_intersections])) then 
								line.a:=i[min_num_intersections]
					else line.a:=i[1];
					outside:=false;
				end;
			end else begin
				outside:=true;
			end;
		end;
	end else begin
		outside:=not ij_in_rectangle(line.a,clip);
	end;
end;

{
	ij_combine_rectangles combines two rectangles and returns a single rectangle that
	encloses both the originals.
}
function ij_combine_rectangles(a,b:ij_rectangle_type):ij_rectangle_type;

begin
	if b.left<a.left then a.left:=b.left;
	if b.right>a.right then a.right:=b.right;
	if b.top<a.top then a.top:=b.top;
	if b.bottom>a.bottom then a.bottom:=b.bottom;
	ij_combine_rectangles:=a;
end;

{
	ij_line_crosses_rectangle returns true iff line crosses rect at two
	distinct points. Much of this routine is similar to ij_clip_line, but
	ij_line_crosses_rectanlge detects a degenerate crossing at a corner,
	and allows a crossing along one edge of the rectangle. We could, of
	course, break out parts of ij_clip_line and use them again in this
	routine, but to do so would take us at least an hour or two of debugging
	afterwards. A quick examination of the code of both routines will show
	that the logic of these simple operations, so straightforward for the
	human eye, is complex.
}
function ij_line_crosses_rectangle(line:ij_line_type;rect:ij_rectangle_type):boolean;

const
	min_num_intersections=2;
	
var 
	num_intersections:integer;
	tl,tr,bl,br,q,p,intersection:ij_point_type;
	
	procedure action(a,b:ij_point_type);
	var edge:ij_line_type;
	begin
		edge.a:=a;edge.b:=b;
		intersection:=ij_line_line_intersection(edge,line);
		if ij_in_rectangle(intersection,rect) then begin
			if num_intersections=0 then p:=intersection
			else q:=intersection;
			inc(num_intersections);
		end;		
	end;

begin
	q:=ij_origin;
	p:=ij_origin;
	num_intersections:=0;
	if ij_separation(line.a,line.b)<>0 then begin
		if line.a.i=line.b.i then
			if (line.a.i>=rect.left) and (line.a.i<=rect.right) then
				num_intersections:=min_num_intersections;
		if line.a.j=line.b.j then
			if (line.a.j>=rect.top) and (line.a.j<=rect.bottom) then
				num_intersections:=min_num_intersections;
		if num_intersections<min_num_intersections then begin
			tl.i:=rect.left;tl.j:=rect.top;
			tr.i:=rect.right;tr.j:=rect.top;
			bl.i:=rect.left;bl.j:=rect.bottom;
			br.i:=rect.right;br.j:=rect.bottom;
			action(tl,tr);
			action(tr,br);
			action(br,bl);
			action(bl,tl);
			if num_intersections=min_num_intersections then 
				if ij_separation(p,q)=0 then
					num_intersections:=1;
		end;
	end;
	ij_line_crosses_rectangle:=(num_intersections>=min_num_intersections);
end;

{
	equal_ij_rectangles checks if two rectangles are identical.
}
function equal_ij_rectangles(a,b:ij_rectangle_type):boolean;
begin
	equal_ij_rectangles:=
		(a.left=b.left) and (a.right=b.right) and (a.top=b.top) and (a.bottom=b.bottom);
end;

{
	ij_clip_rectangle clips rect to a clip area, clip.
}
procedure ij_clip_rectangle(var rect:ij_rectangle_type;clip:ij_rectangle_type);
	procedure clip_up(var a,b:integer);begin if a<b then a:=b; end;
	procedure clip_down(var a,b:integer);begin if a>b then a:=b; end;
begin
	clip_down(rect.right,clip.right);
	clip_up(rect.right,clip.left);
	clip_down(rect.left,clip.right);
	clip_up(rect.left,clip.left);
	clip_down(rect.bottom,clip.bottom);
	clip_up(rect.bottom,clip.top);
	clip_down(rect.top,clip.bottom);
	clip_up(rect.top,clip.top);
end;

{
	ij_random_point returns a random ij_point_type lying within a
	rectangle. 
}
function ij_random_point(rect:ij_rectangle_type):ij_point_type;
var p:ij_point_type;
begin
	with rect,p do begin
		i:=round(random_0_to_1*(right-left))+left;
		j:=round(random_0_to_1*(bottom-top))+top;
	end;
	ij_random_point:=p;
end;

{
	2-D real-valued geometry
}
function xy_difference(p,q:xy_point_type):xy_point_type;
var d:xy_point_type;
begin
	d.x:=p.x-q.x;
		d.y:=p.y-q.y;
		xy_difference:=d;
end;

function xy_dot_product(p,q:xy_point_type):real;
begin
	xy_dot_product:=p.x*q.x+p.y*q.y;
end;

function xy_random:xy_point_type;
var p:xy_point_type;
begin
	with p do begin
		x:=random_0_to_1; 
		y:=random_0_to_1; 
	end;
	xy_random:=p;
end;

function xy_length(p:xy_point_type):real;
var x:real;
begin
	x:=sqr(p.x)+sqr(p.y);
	if x>0 then xy_length:=sqrt(x)
	else xy_length:=0;
end;

function xy_bearing(p:xy_point_type):real;
var x:real;
begin
	x:=full_arctan(p.y,p.x);
	xy_bearing:=x;
end;

function xy_origin:xy_point_type;
var p:xy_point_type;
begin
	p.x:=0;p.y:=0;
	xy_origin:=p;
end;

function xy_scale(p:xy_point_type;scale:real):xy_point_type;
var s:xy_point_type;
begin
	s.x:=p.x*scale;
	s.y:=p.y*scale;
		xy_scale:=s;
end;

function xy_separation(p,q:xy_point_type):real;
var x:real;
begin
	x:=sqr(p.x-q.x)+sqr(p.y-q.y);
	if x>0 then xy_separation:=sqrt(x)
	else xy_separation:=0;
end;

function xy_sum(p,q:xy_point_type):xy_point_type;
var s:xy_point_type;
begin
	s.x:=p.x+q.x;
	s.y:=p.y+q.y;
		xy_sum:=s;
end;

function xy_unit_vector(p:xy_point_type):xy_point_type;
var v:xy_point_type;
begin
	if xy_length(p)<>0 then begin
		v.x:=p.x/xy_length(p);
		v.y:=p.y/xy_length(p);
	end else begin
				v.x:=1;v.y:=0;
		end;
		xy_unit_vector:=v;
end;

{
	xy_rectangle_ellipse calculates the focal points and major axis
	length of the ellipse that fits exactly into an xy_rectangle_type.
}
function xy_rectangle_ellipse(rect:xy_rectangle_type):xy_ellipse_type;
var
	minor_axis_length,focal_separation:real;
	ellipse:xy_ellipse_type;
begin
	with ellipse,rect do begin
		a:=xy_origin;
		b:=xy_origin;
		axis_length:=1;
		if (right-left)>(bottom-top) then begin
			axis_length:=right-left;
			minor_axis_length:=bottom-top;
			focal_separation:=sqrt(sqr(axis_length)-sqr(minor_axis_length));
			a.x:=(right+left)/2+focal_separation/2;
			a.y:=(bottom+top)/2;
			b.x:=(right+left)/2-focal_separation/2;
			b.y:=a.y;
		end;
		if (right-left)<(bottom-top) then begin
			axis_length:=bottom-top;
			minor_axis_length:=right-left;
			focal_separation:=sqrt(sqr(axis_length)-sqr(minor_axis_length));
			a.x:=(right+left)/2;
			a.y:=(bottom+top)/2-focal_separation/2;
			b.x:=a.x;
			b.y:=(bottom+top)/2+focal_separation/2;
		end;
		if (right-left)=(bottom-top) then begin
			axis_length:=bottom-top;
			a.x:=(right+left)/2;
			a.y:=(top+bottom)/2;
			b:=a;
		end;
	end;
	xy_rectangle_ellipse:=ellipse;
end;

{
	xy_rotate takes an xy point and rotates it about the origin
	by r radians in the anti-clockwise direction.
}
function xy_rotate(p:xy_point_type;r:real):xy_point_type;
var v:xy_point_type;
begin
	v.x:=p.x*cos(r)-p.y*sin(r);
	v.y:=p.x*sin(r)+p.y*cos(r);
	xy_rotate:=v;
end;

{
	xy_line_line_intersection calculates the intersection of two 
	lines in two-dimensional space. If there is no intersection,
	the routine returns a point with x and y set to large_real+1.
}
function xy_line_line_intersection(l1,l2:xy_line_type):xy_point_type;
var
	D,F:array [1..2,1..2] of real;
	E:array [1..2] of real;
	determinant:real;
	p:xy_point_type;
begin 
	D[1,1]:=l1.b.y-l1.a.y; D[1,2]:=-(l1.b.x-l1.a.x); E[1]:=l1.a.x*D[1,1]+l1.a.y*D[1,2];
	D[2,1]:=l2.b.y-l2.a.y; D[2,2]:=-(l2.b.x-l2.a.x); E[2]:=l2.a.x*D[2,1]+l2.a.y*D[2,2];
	determinant:=D[1,1]*D[2,2]-D[1,2]*D[2,1];
	if not math_overflow(determinant) then begin
		F[1,1]:=D[2,2]/determinant;
		F[1,2]:=-D[1,2]/determinant;
		F[2,1]:=-D[2,1]/determinant;
		F[2,2]:=D[1,1]/determinant;
		p.x:=F[1,1]*E[1]+F[1,2]*E[2];
		p.y:=F[2,1]*E[1]+F[2,2]*E[2];
	end else begin
		p.x:=large_real+1;
		p.y:=large_real+1;
	end;
	xy_line_line_intersection:=p;
end;

{
	3-D real-valued geometry
}
function xyz_origin:xyz_point_type;
var p:xyz_point_type;
begin
	p.x:=0;p.y:=0;p.z:=0;
	xyz_origin:=p;
end;

function xyz_random:xyz_point_type;
var p:xyz_point_type;
begin
	with p do begin
		x:=2*(random_0_to_1-0.5); 
		y:=2*(random_0_to_1-0.5); 
		z:=2*(random_0_to_1-0.5); 
	end;
	xyz_random:=p;
end;

function xyz_length(p:xyz_point_type):real;
var x:real;
begin
	x:=sqr(p.x)+sqr(p.y)+sqr(p.z);
	if x>0 then xyz_length:=sqrt(x)
	else xyz_length:=0;
end;

function xyz_dot_product(p,q:xyz_point_type):real;
begin
	xyz_dot_product:=p.x*q.x+p.y*q.y+p.z*q.z;
end;

function xyz_cross_product(p,q:xyz_point_type):xyz_point_type;
var c:xyz_point_type;
begin
	c.x:=p.y*q.z-p.z*q.y;
	c.y:=-(p.x*q.z-p.z*q.x);
	c.z:=p.x*q.y-p.y*q.x;
	xyz_cross_product:=c;
end;

function xyz_angle(p,q:xyz_point_type):real;
var c:real;
begin
	c:=xyz_dot_product(p,q)/xyz_length(p)/xyz_length(q);
	xyz_angle:=full_arctan(1/sqr(c)-1,1);
end;

function xyz_unit_vector(p:xyz_point_type):xyz_point_type;
var v:xyz_point_type;
begin
	if xyz_length(p)<>0 then begin
		v.x:=p.x/xyz_length(p);
		v.y:=p.y/xyz_length(p);
		v.z:=p.z/xyz_length(p);
	end else begin
		v.x:=1;v.y:=0;v.z:=0;
	end;
	xyz_unit_vector:=v;
end;

function xyz_scale(p:xyz_point_type;scale:real):xyz_point_type;
var s:xyz_point_type;
begin
	s.x:=p.x*scale;
	s.y:=p.y*scale;
	s.z:=p.z*scale;
	xyz_scale:=s;
end;

function xyz_sum(p,q:xyz_point_type):xyz_point_type;
var s:xyz_point_type;
begin
	s.x:=p.x+q.x;
	s.y:=p.y+q.y;
	s.z:=p.z+q.z;
	xyz_sum:=s;
end;

function xyz_difference(p,q:xyz_point_type):xyz_point_type;
var d:xyz_point_type;
begin
	d.x:=p.x-q.x;
	d.y:=p.y-q.y;
	d.z:=p.z-q.z;
	xyz_difference:=d;
end;

function xyz_separation(p,q:xyz_point_type):real;
var x:real;
begin
	x:=sqr(p.x-q.x)+sqr(p.y-q.y)+sqr(p.z-q.z);
	if x>0 then xyz_separation:=sqrt(x)
	else xyz_separation:=0;
end;

function xyz_z_plane(z:real):xyz_plane_type;
var plane:xyz_plane_type;
begin
	with plane do begin
		point.x:=0;point.y:=0;point.z:=z;
		normal.x:=0;normal.y:=0;normal.z:=1;
	end;
	xyz_z_plane:=plane;
end;

{
	xyz_transform transforms a point in xyz-space using an xyz transform matrix.
}
function xyz_transform(M:xyz_matrix_type;p:xyz_point_type):xyz_point_type;
var t:xyz_point_type;
begin
	t.x:=M[1,1]*p.x+M[1,2]*p.y+M[1,3]*p.z;
	t.y:=M[2,1]*p.x+M[2,2]*p.y+M[2,3]*p.z;
	t.z:=M[3,1]*p.x+M[3,2]*p.y+M[3,3]*p.z;
	xyz_transform:=t;
end;

{
	xyz_point_line_vector returns the shortest vector from a point to a line.
}
function xyz_point_line_vector(point:xyz_point_type;line:xyz_line_type):xyz_point_type;
begin
	xyz_point_line_vector:=
		xyz_sum(
			xyz_difference(line.point,point),
			xyz_scale(
				xyz_unit_vector(line.direction),
				xyz_dot_product(
					xyz_difference(point,line.point),
					xyz_unit_vector(line.direction))));	
end;

{
	xyz_plane_plane_plane_intersection returns the point of intersection of three 
	xyz planes.
}
function xyz_plane_plane_plane_intersection(p,q,r:xyz_plane_type):xyz_point_type;

var 
	row_x,row_y,row_z,constants:xyz_point_type;
	M,N:xyz_matrix_type;

begin
	row_x:=xyz_unit_vector(p.normal);
	constants.x:=xyz_dot_product(row_x,p.point);
	row_y:=xyz_unit_vector(q.normal);
	constants.y:=xyz_dot_product(row_y,q.point);
	row_z:=xyz_unit_vector(r.normal);
	constants.z:=xyz_dot_product(row_z,r.point);
	M:=xyz_matrix_from_points(row_x,row_y,row_z);
	N:=xyz_matrix_inverse(M);
	xyz_plane_plane_plane_intersection:=xyz_transform(N,constants);
end;

{
	xyz_line_plane_intersection returns the point at the intersection of the
	specified line and plane.
}
function xyz_line_plane_intersection(line:xyz_line_type;plane:xyz_plane_type):xyz_point_type;

const
	small_move=1;
	min_length=small_move/10;
	
var 
	row_x,row_y,row_z,constants,p:xyz_point_type;
	M,N:xyz_matrix_type;

begin
{
	The first row of our matrix is a unit vector normal to the plane.
}
	row_x:=xyz_unit_vector(plane.normal);
	constants.x:=xyz_dot_product(row_x,plane.point);
{
	The second row is a vector perpendicular to the line that intersects
	the plane.
}
	p:=xyz_origin;
	if xyz_length(xyz_point_line_vector(p,line))<min_length then 
		p.x:=p.x+small_move;
	if xyz_length(xyz_point_line_vector(p,line))<min_length then 
		p.y:=p.y+small_move;
	row_y:=xyz_unit_vector(xyz_point_line_vector(p,line));
	constants.y:=xyz_dot_product(row_y,line.point);
{
	The third row is a vector perpendicular to the line the first vector
	we chose perpendicular to the line.
}
	row_z:=xyz_unit_vector(xyz_cross_product(line.direction,row_y));
	constants.z:=xyz_dot_product(row_z,line.point);
{
	Now we invert the matrix, multiply the constant vector, and get
	the intersection point.
}
	M:=xyz_matrix_from_points(row_x,row_y,row_z);
	N:=xyz_matrix_inverse(M);
	xyz_line_plane_intersection:=xyz_transform(N,constants);
end;

{
	xyz_point_plane_vector returns the shortest vector from a point to a plane.
}
function xyz_point_plane_vector(point:xyz_point_type;plane:xyz_plane_type):xyz_point_type;

var
	line:xyz_line_type;
	p:xyz_point_type;
	
begin
	line.point:=point;
	line.direction:=plane.normal;
	p:=xyz_line_plane_intersection(line,plane);
	xyz_point_plane_vector:=xyz_difference(p,point);
end;

{
	xyz_line_line_bridge returns the shortest link from the first line to the
	second line, which is what we call the "bridge". We express the bridge as an
	xyz_line_type. We give the point in the first line that is closest to the
	second, and the vector that connects this point to the point in the second
	line that is closest to the first. The two lines must be skewed. Parallel
	lines will return the origin for a point, and a zero vector. We tested this
	routine with the following code. The code generates two random points, which
	are to form the bridge. It creates two lines that run through the points,
	each perpendicular to the bridge and in random directions. It prints to the
	terminal the known bridge and the calculated bridge so you can compare them.
	
	var 
		a,b,c:xyz_line_type;
	begin
		for i:=1 to 10 do begin
			a.point:=xyz_random;
			b.point:=xyz_random;
			c.point:=a.point;
			c.direction:=xyz_difference(b.point,a.point);
			a.direction:=xyz_cross_product(c.direction,xyz_random);
			b.direction:=xyz_cross_product(c.direction,xyz_random);
			a.point:=xyz_sum(a.point,xyz_scale(a.direction,random_0_to_1));
			b.point:=xyz_sum(b.point,xyz_scale(b.direction,random_0_to_1));
			writeln(i:0);
			writeln(string_from_xyz_line(c));
			writeln(string_from_xyz_line(xyz_line_line_bridge(a,b)));
		end;
	end;

}
function xyz_line_line_bridge(p,q:xyz_line_type):xyz_line_type;

var
	p1,p2:xyz_plane_type;
	line:xyz_line_type;
	
begin
	p1.point:=p.point;
	p1.normal:=xyz_unit_vector(xyz_cross_product(p.direction,q.direction));
	p2.point:=q.point;
	p2.normal:=p1.normal;
	line.direction:=xyz_difference(
		xyz_point_plane_vector(xyz_origin,p2),
		xyz_point_plane_vector(xyz_origin,p1));
	p2.normal:=xyz_unit_vector(xyz_cross_product(p2.normal,q.direction));
	line.point:=xyz_line_plane_intersection(p,p2);
	xyz_line_line_bridge:=line;	
end;

{
	xyz_plane_plane_intersection returns the line of intersection of two
	planes.
}
function xyz_plane_plane_intersection(p,q:xyz_plane_type):xyz_line_type;

var 
	line:xyz_line_type;
	plane:xyz_plane_type;
	
begin
	line.direction:=xyz_unit_vector(xyz_cross_product(p.normal,q.normal));
	plane.normal:=line.direction;
	plane.point:=xyz_origin;
	line.point:=xyz_plane_plane_plane_intersection(p,q,plane);
	xyz_plane_plane_intersection:=line;
end;

{
	xyz_line_reflect returns the reflection of a ray in a mirror. The ray is
	represented by a line, and the mirror by a plane. The point given in the
	line is the mirror image of the point given in the original line. The 
	line returned by the routine uses for its point the intersection of the 
	original ray and the mirror plane. The direction is the direction of light 
	from line.point would take after striking xyz_line_reflect.point.
}
function xyz_line_reflect(line:xyz_line_type;plane:xyz_plane_type):xyz_line_type;

var 
	reflection:xyz_line_type;
	perpendicular,parallel,intersection:xyz_point_type;
	
begin
	intersection:=xyz_line_plane_intersection(line,plane);
	plane.normal:=xyz_unit_vector(plane.normal);
	if xyz_dot_product(plane.normal,xyz_difference(line.point,intersection))<0 then 
		plane.normal:=xyz_scale(plane.normal,-1);
	line.direction:=xyz_unit_vector(line.direction);
	perpendicular:=xyz_scale(plane.normal,xyz_dot_product(plane.normal,line.direction));
	parallel:=xyz_difference(line.direction,perpendicular);
	reflection.direction:=xyz_unit_vector(xyz_difference(parallel,perpendicular));
	reflection.point:=
		xyz_sum(
			intersection,
			xyz_scale(
				reflection.direction,
				-xyz_separation(intersection,line.point)));
	xyz_line_reflect:=reflection;
end;

{
	xyz_rotate rotates a point about the x, y, and z axes. First, we
	rotate the point by an angle rotation.x about the x-axis. Next, we
	rotate the point by rotation.y about the y-axis. Last, we rotate
	by rotation.z about the z-axis. Positive rotation about an axis is
	in the direction a right-handed screw would turn to move in the 
	positive direction of the axis.
}
function xyz_rotate(point,rotation:xyz_point_type):xyz_point_type;

var
	p:xyz_point_type;
	
begin
	{rotate about x-axis}
	p.x:=point.x;
	p.y:=point.y*cos(rotation.x)-point.z*sin(rotation.x);
	p.z:=point.y*sin(rotation.x)+point.z*cos(rotation.x);
	{rotate about y-axis}
	point:=p;
	p.x:=point.x*cos(rotation.y)+point.z*sin(rotation.y);
	p.y:=point.y;
	p.z:=-point.x*sin(rotation.y)+point.z*cos(rotation.y);
	{rotate about z-axis}
	point:=p;
	p.x:=point.x*cos(rotation.z)-point.y*sin(rotation.z);
	p.y:=point.x*sin(rotation.z)+point.y*cos(rotation.z);
	p.z:=point.z;
	{return result}
	xyz_rotate:=p;	
end;

{
	xyz_unrotate does the opposite of xyz_rotate.
}
function xyz_unrotate(point,rotation:xyz_point_type):xyz_point_type;

var
	p:xyz_point_type;
	
begin
	{rotate about z-axis}
	p.x:=point.x*cos(-rotation.z)-point.y*sin(-rotation.z);
	p.y:=point.x*sin(-rotation.z)+point.y*cos(-rotation.z);
	p.z:=point.z;
	{rotate about y-axis}
	point:=p;
	p.x:=point.x*cos(-rotation.y)+point.z*sin(-rotation.y);
	p.y:=point.y;
	p.z:=-point.x*sin(-rotation.y)+point.z*cos(-rotation.y);
	{rotate about x-axis}
	point:=p;
	p.x:=point.x;
	p.y:=point.y*cos(-rotation.x)-point.z*sin(-rotation.x);
	p.z:=point.y*sin(-rotation.x)+point.z*cos(-rotation.x);
	{return result}
	xyz_unrotate:=p;	
end;

{	
	memory_byte	returns the value of the 8-bit unsigned byte at the specified address.
}
function memory_byte(address:qword):byte;
begin 
	memory_byte:=byte_ptr(pointer(address))^;
end;

{
	read_memory_byte is a procedural form of memory_byte.
}
procedure read_memory_byte(address:qword; var value:byte);
begin
	value:=memory_byte(address);
end;

{
	write_memory_byte sets the 8-bit unsigned byte at address to value.
}
procedure write_memory_byte(address:qword;value:byte);
begin 
	byte_ptr(address)^:=value;
end; 

{	
	memory_smallint returns the value of the 16-bit signed integer at the
	specified address.
}
function memory_smallint(address:qword):smallint;
begin 
	memory_smallint:=smallint_ptr(address)^;
end;

{
	read_memory_smallint is a procedural form of memory_smallint.
}
procedure read_memory_smallint(address:qword;var value:smallint);
begin 
	value:=memory_smallint(address);
end;

{
	write_memory_smallint sets the 16-bit signed integer at address to value.
}
procedure write_memory_smallint(address:qword;value:smallint);
begin
	smallint_ptr(address)^:=value;
end; 

{	
	memory_integer returns the value of the 32-bit signed integer at the
	specified address.
}
function memory_integer(address:qword):integer;
begin
	memory_integer:=integer_ptr(address)^;
end;

{
	read_memory_integer is a procedural form of memory_integer.
}
procedure read_memory_integer(address:qword;var value:integer);
begin	
	value:=memory_integer(address);
end; 

{
	write_memory_integer sets the signed 32-bit integer at address to value.
}
procedure write_memory_integer(address:qword;value:integer);
begin 
	integer_ptr(address)^:=value;
end; 

{	
	memory_qword returns the value of the 64-bit unsigned integer at the specified 
	address.
}
function memory_qword(address:qword):qword;
begin
	memory_qword:=qword_ptr(address)^;
end;

{
	read_memory_qword is a procedural form of memory_qword.
}
procedure read_memory_qword(address:qword;var value:qword);
begin	
	value:=memory_qword(address);
end; 

{
	write_memory_qword sets the 64-bit unsigned integer at address to value.
}
procedure write_memory_qword(address:qword;value:qword);
begin 
	qword_ptr(address)^:=value;
end; 

{
	write_memory_map writes memory contents to a string. It displays
	the values of size bytes starting with the byte at address base, 
	and expresses the values in hex.
}
procedure write_memory_map(var s:string;base:qword;size:integer);

const
	bytes_per_line=8;
	fs=3;

var
	address:qword;

begin
	for address:=base to base+size-1 do begin
		if (address-base) mod bytes_per_line=0 then begin
			s:=s+eol+'0x'+hex_string_from_qword(address)+': ';
		end;
		s:=s+hex_string_from_byte(memory_byte(address));
	end;
end;

{
	block_move copies length bytes starting at a^ to the location
	starting at b^.
}
procedure block_move(a,b:pointer;length:integer);
begin
	while ((qword(a) mod sizeof(qword))<>0) and (length>=1) do begin
		byte_ptr(b)^:=byte_ptr(a)^;
		a:=pointer(qword(a)+1);
		b:=pointer(qword(b)+1);
		length:=length-1;
	end;
	while (length>=sizeof(qword)) do begin
		qword_ptr(b)^:=qword_ptr(a)^;
		a:=pointer(qword(a)+sizeof(qword));
		b:=pointer(qword(b)+sizeof(qword));
		length:=length-sizeof(qword);
	end;
	while (length>=sizeof(byte)) do begin
		byte_ptr(b)^:=byte_ptr(a)^;
		a:=pointer(qword(a)+1);
		b:=pointer(qword(b)+1);
		length:=length-1;
	end;
end;

{
	block_set writes the specified byte value to length bytes
	starting at a^.
}
procedure block_set(a:pointer;length:integer;value:byte);
var
	c:qword;
begin
	if length<=0 then exit;
	
	{
		Create a 64-bit integer with the value repeated in each of its 8 bytes.
	}
	c:= value and $000000FF;
	c:= c or (c shl 8);
	c:= c or (c shl 16);
	c:= c or (c shl 32);
	
	{
		Copy in bytes at ends, but 64-bit words in the middle.
	}
	while ((qword(a) mod sizeof(qword))<>0) and (length>=1) do begin
		byte_ptr(a)^:=value;
		a:=pointer(qword(a)+1);
		length:=length-1;
	end;
	while (length>=sizeof(qword)) do begin
		qword_ptr(a)^:=c;
		a:=pointer(qword(a)+sizeof(qword));
		length:=length-sizeof(qword);
	end;
	while (length>=1) do begin
		byte_ptr(a)^:=value;
		a:=pointer(qword(a)+1);
		length:=length-1;
	end;
end;

{
	block_clear clears length bytes starting at a^ to zero. It calls
	block_set with value zero.
}
procedure block_clear(a:pointer;length:integer);
begin
	block_set(a,length,$00);
end;

{
	block_fill fills length bytes starting at a^ with ones.
}
procedure block_fill(a:pointer;length:integer);
begin
	block_set(a,length,$FF);
end;

{
	real_from_integer converts a real number into a four-byte
	integer. GPC appears to have trouble doing this automatically.
}
function real_from_integer(i:integer):real;
begin real_from_integer:=1.0*i; end;

{
	reverse_smallint_bytes swaps the bytes of a short integer;
}
function reverse_smallint_bytes(i:smallint):smallint;

type
	si_type=packed record
		case boolean of
			true: (a,b:byte);
			false: (i:smallint);
	end;

var
	new_i,old_i:si_type;	
	
begin
	old_i.i:=i;
	new_i.a:=old_i.b;
	new_i.b:=old_i.a;
	reverse_smallint_bytes:=smallint(new_i.i);
end;

{
	check_big_endian returns true if this processor stores the high byte 
	of a multi-byte integer in the low-address location. Otherwise it 
	returns false. We use check_big_endian to initialize the big_endian
	global variable.
}
function check_big_endian:boolean;

const
	high_byte_ones=$FF000000;

type
	four_byte_cardinal=packed record
		case boolean of
			true: (b1,b2,b3,b4:byte);
			false: (c:cardinal);
	end;
		
var
	b:four_byte_cardinal;
		
begin
	b.c:=high_byte_ones;
	check_big_endian:=(b.b1<>0);
end;

{
	big_endian_from_local_smallint takes a local smallint
	and returns a smallint with big-endian byte ordering,
	regardless of host platform..
}
function big_endian_from_local_smallint(i:smallint):smallint;
begin
	if big_endian then big_endian_from_local_smallint:=i
	else big_endian_from_local_smallint:=reverse_smallint_bytes(i);
end;

{
	local_from_big_endian_smallint takes a big-endian smallint
	and returns a smallint in the local byte ordering, regardless
	of host platform.
}
function local_from_big_endian_smallint(i:smallint):smallint;
begin
	if big_endian then local_from_big_endian_smallint:=i
	else local_from_big_endian_smallint:=reverse_smallint_bytes(i);
end;

{
	local_from_little_endian_smallint takes a little-endian smallint
	and returns a smallint in the local byte ordering, regardless
	of host platform.
}
function local_from_little_endian_smallint(i:smallint):smallint;
begin
	if (not big_endian) then local_from_little_endian_smallint:=i
	else local_from_little_endian_smallint:=reverse_smallint_bytes(i);
end;


{
	initialization sets up the utils variables.
}
initialization 

randomize;
gui_draw:=default_gui_draw;
gui_support:=default_gui_support;
gui_wait:=default_gui_wait;
gui_write:=default_gui_write;
gui_writeln:=default_gui_writeln;
gui_readln:=default_gui_readln;
debug_log:=default_debug_log;
big_endian:=check_big_endian;
log_file_name:=default_log_file_name;

{
	finalization does nothing.
}
finalization

end.