{
Routines for Analysis of Data Retrieved from Miscellaneous LWDAQ Devices
Copyright (C) 2004-2019 Kevan Hashemi, Brandeis University
Copyright (C) 2006-2022 Kevan Hashemi, Open Source Instruments Inc.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
}

unit electronics;

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}

interface

uses
	transforms,image_manip,images,utils;
	
var
	electronics_trace:xy_graph_type;

function lwdaq_A2037_monitor(ip:image_ptr_type;
	t_min,t_max,v_min,v_max:real;
	ac_couple:boolean):string;

function lwdaq_A2053_gauge(ip:image_ptr_type;
	t_min,t_max,y_min,y_max:real;
	ac_couple:boolean;ref_bottom,ref_top:real;
	ave,stdev:boolean):string;

function lwdaq_A2053_flowmeter(ip:image_ptr_type;
	t_min,t_max,c_min,c_max:real;
	ref_bottom,ref_top:real):string;

function lwdaq_A2057_voltmeter(ip:image_ptr_type;
	t_min,t_max,v_min,v_max,v_trigger:real;
	ac_couple,positive_trigger,auto_calib:boolean):string;

function lwdaq_A2065_inclinometer(ip:image_ptr_type;
	v_trigger,v_min,v_max,harmonic:real):string;
	
function lwdaq_sct_receiver(ip:image_ptr_type;command:string):string;

function lwdaq_A3008_rfpm(ip:image_ptr_type;
	v_min,v_max:real;rms:boolean):string;


implementation

{
	sample_A2037E_adc16 returns the voltage seen at the input of the
	sixteen-bit ACD of an A2037E for a given channel number and sample
	number. The routine finds the sample in an image (which acts as a block
	of ADC data). The first row of the image contains image dimensions and a
	results string, as is usual for LWDAQ images. The second and third rows
	(numbers 1 and 2) contain the ADC samples for channel zero. There are
	i_size samples per channel. If you specify channel zero, you can refer
	to samples as if they were all taken from a single channel much longer
	than i_size samples. The image will hold up to i_size*(j_size-1)/2
	samples.
}
function sample_A2037E_adc16(ip:image_ptr_type;channel_num,sample_num:integer):real;

const
	v_per_count=20/$10000; {+-10-V full range, signed sixteen bit output}
	sample_size=2; {bytes per adc sample}

var 
	i,j:integer;

begin
	j:=1+(channel_num*sample_size)+(sample_num*sample_size div ip^.i_size);
	i:=(sample_num*sample_size mod ip^.i_size);
	if (j>ip^.j_size-1) or (i>ip^.i_size-1) then
		sample_A2037E_adc16:=0
	else 
		sample_A2037E_adc16:=v_per_count*
			local_from_big_endian_smallint(
				smallint_ptr(pointer(@ip^.intensity[j*ip^.i_size+i]))^);
end;

{
	sample_A2037E_adc8 is similar to the adc16 routine, but each channel
	consists of only one row in the image, because the samples are each only
	one byte long. Once again, you can treat the image as one extended list
	of samples by specifying channel zero. The image will hold up to
	i_size*(j_size-1) samples.
}
function sample_A2037E_adc8(ip:image_ptr_type;channel_num,sample_num:integer):real;

const
	v_per_count=1/$100; {0..1 V unsigned output}
	v_offset=0.5; {added to input to place 0V in middle of ADC range}
	sample_size=1; {bytes per adc sample}

var 
	i,j:integer;

begin
	j:=1+(channel_num*sample_size)+(sample_num*sample_size div ip^.i_size);
	i:=(sample_num*sample_size mod ip^.i_size);
	if (j>ip^.j_size-1) or (i>ip^.i_size-1) then
		sample_A2037E_adc8:=0
	else 
		sample_A2037E_adc8:=v_per_count*get_px(ip,j,i)-v_offset;
end;

{
	draw_oscilloscope_scale fills the overlay, so that it is white, and 
	draws an oscilloscope scale in it with the specified number of divisions
	across the width and height.
}
procedure draw_oscilloscope_scale(ip:image_ptr_type;num_divisions:integer);

const
	extents_per_width=2;
	scale_color=light_gray_color;
	
var
	div_extent,div_num:integer;
	rect:ij_rectangle_type;
	
begin
	fill_overlay(ip);
	if num_divisions<extents_per_width then exit;
	div_extent:=num_divisions div extents_per_width;
	for div_num:=0 to div_extent do begin
		rect.left:=0;
		rect.right:=ip^.i_size-1;
		rect.top:=round(div_num*one_half*ip^.j_size/div_extent);
		rect.bottom:=ip^.j_size-1-round(div_num*one_half*ip^.j_size/div_extent);
		display_ccd_rectangle(ip,rect,scale_color);
	end;
	for div_num:=0 to div_extent do begin
		rect.left:=round(div_num*one_half*ip^.i_size/div_extent);
		rect.right:=ip^.i_size-1-round(div_num*one_half*ip^.i_size/div_extent);
		rect.top:=0;
		rect.bottom:=ip^.j_size-1;
		display_ccd_rectangle(ip,rect,scale_color);
	end;
end;

{
	lwdaq_A2037_monitor analyzes sixteen-bit adc samples from the driver supplies
	to calculate the power supply currents and voltages.
}
function lwdaq_A2037_monitor(ip:image_ptr_type;
	t_min,t_max,v_min,v_max:real;
	ac_couple:boolean):string;


const
	num_divisions=10; {number of display divisions across width of height}
	rn=490; {average network resistance, some drivers use 470, some use 511}
	reference=5.03; {measured for our first lot of ZBR500s}
	beta=rn/(100000+rn); {divider with 100k}
	alpha=0.47; {current-monitoring resistance in ohms}
	gamma=alpha/2; {5-V current monitoring resistance in ohms}
	nigcf=(rn-4)/(rn-1); {negative input gain correction factor}

var 
	result:string='';
	input_string:string='';
	p15V,p15I,p5V,p5I,n15V,n15I:xy_graph_type; {voltages in V, currents in mA}
	c_gain,d_gain:xy_graph_type;{properties of adc input}
	n:integer;
	p15V_ave:real=0;
	p5V_ave:real=0;
	n15V_ave:real=0;
	period:real=0;
	sv,an,hv,fv,lt,tr:real;

begin
	lwdaq_A2037_monitor:='ERROR: Diagnostic analysis failed.';
	if not valid_image_ptr(ip) then exit;
	
	input_string:=ip^.results;
	sv:=read_real(input_string);
	an:=read_real(input_string);
	hv:=read_real(input_string);
	fv:=read_real(input_string);
	lt:=read_real(input_string);
	tr:=read_real(input_string);
	period:=read_real(input_string);
	if (period<=0) then period:=1;
	
	writestr(result,sv:1:0,' ',an:1:0,' ',hv:1:0,' ',fv:1:0,' ',lt:1:0,' ',tr:1:0);

	setlength(c_gain,ip^.i_size);
	setlength(d_gain,ip^.i_size);
	setlength(p15V,ip^.i_size);
	setlength(p15I,ip^.i_size);
	setlength(p5V,ip^.i_size);
	setlength(p5I,ip^.i_size);
	setlength(n15V,ip^.i_size);
	setlength(n15I,ip^.i_size);
	for n:=0 to ip^.i_size-1 do begin
		c_gain[n].y:=(sample_A2037E_adc16(ip,1,n)-sample_A2037E_adc16(ip,8,n))
			/reference;
		d_gain[n].y:=(sample_A2037E_adc16(ip,0,n)-sample_A2037E_adc16(ip,8,n))
			/(reference*beta);
		if d_gain[n].y=0 then d_gain[n].y:=1;
		p15V[n].y:=(sample_A2037E_adc16(ip,3,n)-sample_A2037E_adc16(ip,8,n))
			/(d_gain[n].y*beta);
		p15I[n].y:=(sample_A2037E_adc16(ip,2,n)-sample_A2037E_adc16(ip,8,n)
			-c_gain[n].y*p15V[n].y)*mA_per_A/(d_gain[n].y*alpha);
		p5V[n].y:=(sample_A2037E_adc16(ip,5,n)-sample_A2037E_adc16(ip,8,n))
			/(d_gain[n].y*beta);
		p5I[n].y:=(sample_A2037E_adc16(ip,4,n)-sample_A2037E_adc16(ip,8,n)
			-c_gain[n].y*p5V[n].y)*mA_per_A/(d_gain[n].y*gamma);
		n15V[n].y:=-(sample_A2037E_adc16(ip,7,n)
			-sample_A2037E_adc16(ip,8,n))/(d_gain[n].y*beta*nigcf);
		n15I[n].y:=(sample_A2037E_adc16(ip,6,n)-sample_A2037E_adc16(ip,8,n)
			-c_gain[n].y*n15V[n].y)*mA_per_A/(d_gain[n].y*alpha);
		c_gain[n].x:=period*n;
		d_gain[n].x:=period*n;
		p15V[n].x:=period*n;
		p15I[n].x:=period*n;
		p5V[n].x:=period*n;
		p5I[n].x:=period*n;
		n15V[n].x:=period*n;
		n15I[n].x:=period*n;
	end;
	p15V_ave:=average_y_xy_graph(p15V);
	p5V_ave:=average_y_xy_graph(p5V);
	n15V_ave:=average_y_xy_graph(n15V);
	writestr(result,result,' ',
		p15V_ave:5:3,' ',average_y_xy_graph(p15I):5:3,' ',
		p5V_ave:5:3,' ',average_y_xy_graph(p5I):5:3,' ',
		n15V_ave:5:3,' ',average_y_xy_graph(n15I):5:3,' ',
		average_y_xy_graph(c_gain):6:4,' ',average_y_xy_graph(d_gain):3:1);
		
	draw_oscilloscope_scale(ip,num_divisions);
	if ac_couple then begin
		display_real_graph(ip,p15V,yellow_color,
			t_min,t_max,v_min+p15V_ave,v_max+p15V_ave,0,0);
		display_real_graph(ip,p5V,red_color,
			t_min,t_max,v_min+p5V_ave,v_max+p5V_ave,0,0);
		display_real_graph(ip,n15V,green_color,
			t_min,t_max,v_min+n15V_ave,v_max+n15V_ave,0,0);
	end 
	else begin
		display_real_graph(ip,p15V,yellow_color,t_min,t_max,v_min,v_max,0,0);
		display_real_graph(ip,p5V,red_color,t_min,t_max,v_min,v_max,0,0);
		display_real_graph(ip,n15V,green_color,t_min,t_max,v_min,v_max,0,0);
	end;
	
	lwdaq_A2037_monitor:=result;
end;

{
	lwdaq_A2053_gauge takes adc samples from an A2053 or compatible device
	and converts them into sensor measurements. 
}
function lwdaq_A2053_gauge(ip:image_ptr_type;
	t_min,t_max,y_min,y_max:real;
	ac_couple:boolean;ref_bottom,ref_top:real;
	ave,stdev:boolean):string;

const
	num_divisions=10; 
	max_num_channels=30;
	ref_bottom_row=0;
	channel_row=1;
	ref_top_row=2;
	rows_per_channel=3;

var 
	result:string='';
	input_string:string='';
	gauge:xy_graph_type; 
	n,channel_num,num_channels:integer;
	gauge_ave,ref_top_voltage,ref_bottom_voltage,period:real;

begin
	lwdaq_A2053_gauge:='ERROR: Gauge analysis failed.';
	if not valid_image_ptr(ip) then exit;
	
	if abs(ref_top-ref_bottom)<small_real then begin
		report_error('ref_top=ref_bottom.');
		exit;
	end;

	input_string:=ip^.results;
	period:=read_real(input_string);
	if (period<=0) then period:=1;
	num_channels:=read_integer(input_string);
	if num_channels=0 then num_channels:=1;
	
	draw_oscilloscope_scale(ip,num_divisions);

	setlength(gauge,ip^.i_size);
	
	for channel_num:=0 to num_channels-1 do begin
		ref_bottom_voltage:=0;
		for n:=0 to ip^.i_size-1 do
			ref_bottom_voltage:=ref_bottom_voltage
				+sample_A2037E_adc16(ip,ref_bottom_row
					+rows_per_channel*channel_num,n);
		ref_bottom_voltage:=ref_bottom_voltage/ip^.i_size;
				
		ref_top_voltage:=0;
		for n:=0 to ip^.i_size-1 do
			ref_top_voltage:=ref_top_voltage
				+sample_A2037E_adc16(ip,ref_top_row
					+rows_per_channel*channel_num,n);
		ref_top_voltage:=ref_top_voltage/ip^.i_size;

		if abs(ref_top_voltage-ref_bottom_voltage)<small_real then 
			ref_top_voltage:=ref_bottom_voltage+1;

		for n:=0 to ip^.i_size-1 do begin
			gauge[n].y:=
				(sample_A2037E_adc16(ip,channel_row
						+rows_per_channel*channel_num,n)
							-ref_bottom_voltage)
				/(ref_top_voltage-ref_bottom_voltage)
				*(ref_top-ref_bottom) 
				+ref_bottom;
			gauge[n].x:=period*n;
		end;
		gauge_ave:=average_y_xy_graph(gauge);

		if ac_couple then
			display_real_graph(ip,gauge,
				overlay_color_from_integer(channel_num),
				t_min,t_max,y_min+gauge_ave,y_max+gauge_ave,0,0)
		else 
			display_real_graph(ip,gauge,
				overlay_color_from_integer(channel_num),
				t_min,t_max,y_min,y_max,0,0);

		if ave then writestr(result,result,gauge_ave:5:3,' ');
		if stdev then writestr(result,result,stdev_y_xy_graph(gauge):5:3,' ');
	end;

	electronics_trace:=gauge;

	lwdaq_A2053_gauge:=result;
end;

{
	lwdaq_A2053_flowmeter takes adc samples from an A2053 and converts them
	into temperature sensor measurements. It plots the temperatures in an
	oscilloscope display.
}
function lwdaq_A2053_flowmeter(ip:image_ptr_type;
	t_min,t_max,c_min,c_max:real;
	ref_bottom,ref_top:real):string;

const
	num_divisions=10; {number of display divisions across width of height}
	ambient_divisions=1;{number of divisions dedicated to ambient measurement}
	skip_divisions=1;{number of divisions to skip at cool-down start}
	min_num_cooling_samples=2;

var 
	result:string='';
	input_string:string='';
	temperature,log_temperature,fit,log_fit:xy_graph_type; 
	num_ambient_samples,num_cooling_samples:integer;
	n,cooling_start_index:integer;
	ref_top_voltage,ref_bottom_voltage,period:real;
	slope,intercept,rms_residual,t_relative:real;
	peak_temp,start_temp,end_temp,ambient_temp:real;

begin
	lwdaq_A2053_flowmeter:='ERROR: Flowmeter analysis failed.';
	if not valid_image_ptr(ip) then exit;
	
	if abs(ref_top-ref_bottom)<small_real then begin
		report_error('ref_top=ref_bottom.');
		exit;
	end;

	input_string:=ip^.results;
	period:=read_real(input_string);
	if (period<=0) then period:=1;
	draw_oscilloscope_scale(ip,num_divisions);

	ref_bottom_voltage:=0;
	for n:=0 to ip^.i_size-1 do
		ref_bottom_voltage:=ref_bottom_voltage
			+sample_A2037E_adc16(ip,0,n);
	ref_bottom_voltage:=ref_bottom_voltage/ip^.i_size;

	ref_top_voltage:=0;
	for n:=0 to ip^.i_size-1 do
		ref_top_voltage:=ref_top_voltage
			+sample_A2037E_adc16(ip,2,n);
	ref_top_voltage:=ref_top_voltage/ip^.i_size;
	
	if (ref_top_voltage=ref_bottom_voltage) then begin
		report_error('ref_top_voltage=ref_bottom_voltage.');
		exit;
	end;

	setlength(temperature,ip^.i_size);
	for n:=0 to ip^.i_size-1 do begin
		temperature[n].y:=
			(sample_A2037E_adc16(ip,1,n)-ref_bottom_voltage)
			/(ref_top_voltage-ref_bottom_voltage)
			*(ref_top-ref_bottom) 
			+ref_bottom;
		temperature[n].x:=period*n;
	end;

	num_ambient_samples:=round(ambient_divisions*ip^.i_size/num_divisions)-1;
	cooling_start_index:=round(
		(ambient_divisions+skip_divisions)
		*ip^.i_size/num_divisions
		+2);
	num_cooling_samples:=ip^.i_size-cooling_start_index;
	if num_cooling_samples<min_num_cooling_samples then begin
		report_error('num_cooling_samples<min_num_cooling_samples.');
		exit;
	end;
	
	ambient_temp:=0;
	for n:=0 to num_ambient_samples-1 do
		ambient_temp:=ambient_temp+temperature[n].y;
	ambient_temp:=ambient_temp/num_ambient_samples;
	peak_temp:=temperature[num_ambient_samples+2].y;
	start_temp:=temperature[ip^.i_size-num_cooling_samples].y;
	end_temp:=temperature[ip^.i_size-1].y;
	setlength(log_temperature,num_cooling_samples);
	for n:=0 to num_cooling_samples-1 do begin
		t_relative:=temperature[n+cooling_start_index].y-ambient_temp;
		if t_relative>0 then
			log_temperature[n].y:=ln(t_relative)
		else begin
			report_error('t_relative<=0 at n='+string_from_integer(n,1)+'.');
			exit;
		end;
		log_temperature[n].x:=temperature[n+cooling_start_index].x;
	end;
	straight_line_fit(log_temperature,slope,intercept,rms_residual);

	setlength(log_fit,num_cooling_samples);
	for n:=0 to num_cooling_samples-1 do begin
		log_fit[n].y:=log_temperature[n].x*slope+intercept;
		log_fit[n].x:=log_temperature[n].x;
	end;

	rms_residual:=0;
	setlength(fit,num_cooling_samples);
	for n:=0 to num_cooling_samples-1 do begin
		fit[n].y:=exp(log_fit[n].y)+ambient_temp;
		fit[n].x:=log_fit[n].x;
		rms_residual:=rms_residual
			+sqr(temperature[n+cooling_start_index].y-fit[n].y);
	end;
	rms_residual:=sqrt(rms_residual/num_cooling_samples);

	display_real_graph(ip,log_fit,green_color,t_min,t_max,0,0,0,0);
	display_real_graph(ip,log_temperature,red_color,t_min,t_max,0,0,0,0);
	display_real_graph(ip,fit,
		green_color,t_min,t_max,c_min+ambient_temp,c_max+ambient_temp,0,0);
	display_real_graph(ip,temperature,
		red_color,t_min,t_max,c_min+ambient_temp,c_max+ambient_temp,0,0);

	electronics_trace:=temperature;

	writestr(result,-slope:8:6,' ',rms_residual:8:6,' ',
		ambient_temp:5:3,' ',
		peak_temp-ambient_temp:5:3,' ',
		start_temp-ambient_temp:5:3,' ',
		end_temp-ambient_temp:5:3);
	
	lwdaq_A2053_flowmeter:=result;
end;

{
	lwdaq_A2057_voltmeter takes sixten bit adc samples in an image, together with
	trigger parameters, plots an osciloscope output, and returns the averge, standard
	deviation and fundamental frequency of the input to the A2057. When auto_calib is
	set, the routine uses the 0-V and 5-V reference inputs to get the input voltage 
	correct.
}
function lwdaq_A2057_voltmeter(ip:image_ptr_type;
	t_min,t_max,v_min,v_max,v_trigger:real;
	ac_couple,positive_trigger,auto_calib:boolean):string;


const
	num_divisions=10; {number of display divisions across width and height}
	max_redundancy_factor=4; 
	min_redundancy_factor=1;
	max_num_channels=8;
	min_channel_gain=0.001;
	max_channel_gain=1000;
	
var 
	result:string='';
	input_string:string='';
	trace,reference,transform:xy_graph_type;
	subset:x_graph_type;
	n,num_samples,num_channels,channel_num:integer;
	subset_size,redundancy_factor:integer;
	ave:real=0;
	stdev:real=0;
	period:real=0;
	frequency:real=0;
	amplitude:real=0;
	ref_top_V:real=0;
	ref_bottom_V:real=0;
	ref_bottom:real=0;
	ref_top:real=0;
	channel_gain:real=0;
	trigger:real;
	
begin
	lwdaq_A2057_voltmeter:='ERROR: Voltmeter analysis failed.';
	if not valid_image_ptr(ip) then exit;
	
	input_string:=ip^.results;
	period:=read_real(input_string);
	if (period<=0) then period:=1;
	ref_bottom_V:=read_real(input_string);
	ref_top_V:=read_real(input_string);
	if (abs(ref_top_V-ref_bottom_V)<small_real) and auto_calib then begin
		report_error('ref_bottom_V=ref_top_V with auto_calib.');
		exit;
	end;
	channel_gain:=read_real(input_string);
	if (abs(channel_gain)<min_channel_gain) or 
			(abs(channel_gain)>max_channel_gain) then begin
		report_error('Invalid channel_gain.');
		exit;
	end;
	redundancy_factor:=read_integer(input_string);
	if (redundancy_factor>max_redundancy_factor) or 
			(redundancy_factor<min_redundancy_factor) then begin
		report_error('Invalid redundancy_factor.');
		exit;
	end;
	num_channels:=read_integer(input_string);
	if (num_channels<1) or (num_channels>max_num_channels) then 
		num_channels:=1;
		
	draw_oscilloscope_scale(ip,num_divisions);

	if auto_calib then begin
		setlength(reference,ip^.i_size);
		for n:=0 to ip^.i_size-1 do begin
			reference[n].y:=sample_A2037E_adc16(ip,0,n);
			reference[n].x:=n;
		end;
		ref_bottom:=average_y_xy_graph(reference);	
		for n:=0 to ip^.i_size-1 do begin
			reference[n].y:=sample_A2037E_adc16(ip,redundancy_factor*num_channels+1,n);
			reference[n].x:=n;
		end;
		ref_top:=average_y_xy_graph(reference);	
		if abs(ref_top-ref_bottom)<small_real then begin
			report_error('ref_top=ref_bottom with auto_calib');
			exit;
		end;
	end;

	num_samples:=ip^.i_size*redundancy_factor;
	setlength(trace,num_samples);

	for channel_num:=0 to num_channels-1 do begin
{
	Extract channel voltages from the image.
}
		for n:=0 to num_samples-1 do begin
			trace[n].x:=period*n;
			trace[n].y:=sample_A2037E_adc16(ip,redundancy_factor*channel_num+1,n);
		end;
{
	If we are asking for auto-calibration using the top and bottom reference
	voltages, adjust the trace voltage.
}
		if auto_calib then
			for n:=0 to num_samples-1 do
				trace[n].y:=(trace[n].y-ref_bottom)
					/ (ref_top-ref_bottom)
					* (ref_top_V-ref_bottom_V)
					/ channel_gain
					+ ref_bottom_V;
		ave:=average_y_xy_graph(trace);
		stdev:=stdev_y_xy_graph(trace);
{
	If we want to ac-couple the signal, subtract its average value now.
}
		if ac_couple then
			for n:=0 to num_samples-1 do
				trace[n].y:=trace[n].y-ave;
{
	Find the sample just before the trigger event.
}
		trigger:=0;
		n:=0;
		while (trigger=0) and (n<num_samples-1) do begin
			if (positive_trigger and 
				(trace[n].y<=v_trigger) and 
				(trace[n+1].y>v_trigger)) 
					or
				(not positive_trigger and 
				(trace[n].y>=v_trigger) and 
				(trace[n+1].y<v_trigger)) then begin
				trigger:=n;
			end;
			inc(n);
		end;
{
	If we have found a trigger, refine the trigger instant for fractions of a sample 
	period.
}
		if (trigger<>0) then begin
			n:=round(trigger);
			if abs(trace[n+1].y-trace[n].y)>small_real then 
				trigger:=n+(v_trigger-trace[n].y)/(trace[n+1].y-trace[n].y);
		end;
{
	Use the trigger to offset the time axis of the trace, making the trigger instant
	the time zero instant.
}
		for n:=0 to num_samples-1 do trace[n].x:=trace[n].x-trigger*period;
{
	Display a graph of the voltage versus time, with time zero representing the moment
	of the first trigger.
}
		display_real_graph(ip,trace,
			overlay_color_from_integer(channel_num),
			t_min,t_max,v_min,v_max,0,0);
{
	Apply a fourier transform to the data to obtain the fundamental frequency, should
	such a frequency exist.
}
		subset_size:=1;
		while (subset_size<=num_samples/2.0) do subset_size:=subset_size*2;
		setlength(subset,subset_size);		
		for n:=0 to subset_size-1 do subset[n]:=trace[n].y;
		transform:=fft_real(subset);
		amplitude:=0;
		frequency:=0;
		for n:=1 to (subset_size div 2)-1 do begin
			if transform[n].x>amplitude then begin
				amplitude:=transform[n].x;
				frequency:=n/subset_size/period;
			end;
		end;
{
	Add measurements to the result string.
}
		writestr(result,result,ave:fsr:fsd,' ',stdev:fsr:fsd,' ',
			frequency:fsr:fsd,' ',amplitude:fsr:fsd,' ');
	end;
{
	We make the final trace available with a global pointer, after disposing of the pre-existing
	trace, should it exist. Note that if we displayed more than one channel, only the final 
	channel's trace will be available.
}
	electronics_trace:=trace;
	
	lwdaq_A2057_voltmeter:=result;
end;

{
	lwdaq_A2065_inclinometer takes an Inclinometer instrument image and
	calculates the amplitude of each eight-bit digitized waveform in the
	image. We specify the number of sinusoidal periods in each waveform,
	and the routine assumes that the period of all sinusoids is the same.
	The routine draws the waveforms in the image overlay for display by
	the Inclinometer.
	
}
function lwdaq_A2065_inclinometer(ip:image_ptr_type;
	v_trigger,v_min,v_max,harmonic:real):string;


const
	num_divisions=10; {number of display divisions across width and height}
	startup_skip=10; {gets over the ADC's pipeline}
	max_redundancy_factor=4; {protects routine from bad redundancy_factor integer}
	max_num_channels=20; {protects routine from bad num_channels integer}
	sample_size=2;{bytes per sample}
	
var 
	result:string='';
	input_string:string='';
	trace:xy_graph_type;
	signal:x_graph_type;
	n,num_samples,num_channels,channel_num:integer;
	redundancy_factor,trigger:integer;
	amplitude,offset,period:real;
	
begin
	lwdaq_A2065_inclinometer:='ERROR: Inclinometer analysis failed.';
	if not valid_image_ptr(ip) then exit;
	
	draw_oscilloscope_scale(ip,num_divisions);

	input_string:=ip^.results;
	num_samples:=read_integer(input_string);
	if (num_samples>(ip^.j_size-1)*ip^.i_size/sample_size) or (num_samples<1) then begin
		report_error('Invalid num_samples.');
		exit;
	end;
	redundancy_factor:=read_integer(input_string);
	if (redundancy_factor>max_redundancy_factor) or (redundancy_factor<=1) then begin
		report_error('Invalid redundancy_factor.');
		exit;
	end;
	num_channels:=read_integer(input_string);
	if (num_channels>max_num_channels) or (num_channels<=0) then begin
		report_error('Invalid num_channels.');
		exit;
	end;

	setlength(trace,num_samples);
	setlength(signal,num_samples);

	for channel_num:=0 to num_channels-1 do begin
		trigger:=startup_skip;
		n:=startup_skip;
		while n<num_samples*(redundancy_factor-1) do begin
			inc(n);
			if (sample_A2037E_adc16(
					ip,0,redundancy_factor*channel_num*num_samples+n)
				<= v_trigger) and (sample_A2037E_adc16(
					ip,0,redundancy_factor*channel_num*num_samples+n+1)
				> v_trigger) then begin
				trigger:=n;
			end;
		end;
		for n:=0 to num_samples-1 do begin
			trace[n].x:=n;
			trace[n].y:=sample_A2037E_adc16(ip,0,
				redundancy_factor*channel_num*num_samples+n+trigger);
			signal[n]:=trace[n].y;
		end;
		display_real_graph(ip,trace,
			overlay_color_from_integer(channel_num),
				0,num_samples-1,v_min,v_max,0,0);
		if (harmonic>0) then period:=num_samples/harmonic
		else period:=0;
		calculate_ft_term(period,signal,amplitude,offset);
		writestr(result,result,' ',amplitude:fsr:fsd);
	end;
{
	We make the trace available with a global pointer, after disposing of the pre-existing
	trace, should it exist.
}
	electronics_trace:=trace;

	lwdaq_A2065_inclinometer:=result;
end;

{
	lwdaq_sct_receiver analyzes receiver messages. These messages have a
	four-byte core, and may be accompanied by one or more bytes of payload data.
	The routine assumes that the first byte of the second image row is the first
	byte of a message. Each message takes the following form: an eight-bit
	signal identifier, a sixteen-bit sample value, an eight-bit time stamp, and
	zero or more bytes of payload. The routine will return the sixteen-bit
	sample values, or various characteristics of the data block, depending upon
	the options passed in through the command string.

	The routine does not return the payload directly, but instead uses the
	global electronics_trace to store indices that allow another routine to
	extract payload values from the image data. The electronics trace is filled
	with message indices when we execute the "extract" or "reconstruct"
	instructions.

	The only command that alters the image data is "purge", which eliminates
	duplicate messages. All other commands leave the image data untouched. Some
	commands alter the image result string.

	In some cases, following aborted data acquisition, it is possible for the
	data block to be aligned incorrectly, so that the first byte of the block is
	not the first byte of a message, but instead the second, third, or fourth
	byte of an incomplete message. The routine does not handle such exceptions.
	If we want to deal with such corruption, we must shift the image data one
	byte to the left and try again until we meet with success.

	The command string passed into this routine begins with options and values,
	followed by an instruction and parameters. We present the options and
	instructions in the comments below. Each option must be accompanied by an
	option value.

	The "-size n" option tells the routine how many messages are in the image.
	The default value is 0, in which case the routine scans through the entire
	image looking until it encounters a null message or the end of the image. A
	null message is any one for which the first four bytes are zero. Such
	messages arise in corrupted recordings, but are also used to fill in the
	remainder of the image after the last valid message. If n > 0, the routine
	reads n messages even if there are null messages in the block it reads.

	The "-payload n" option indicates that the four-byte core of each message is
	followed by n bytes of payload data. The default value of n is zero. The
	only instruction that returns the payload data directly is the "print"
	instruction. Otherwise, payload data is accessible through a list of indices
	passed back by the "extract" and "reconstruct" instructions.

	Because of limitations in their logic, some data receivers may be unable to
	eliminate duplicate messages from their data stream. The same signal message
	received on two or more antennas may appear two or more times in the data.
	This routine eliminates these duplicates when it copies the messages from
	the image block into a separate message array. We will see the duplicates
	with the "print" and "get" instructions, which operate on the original image
	data. But all other instructions operate upon the message array, from which
	duplicates have been removed.

	The "purge" instruction re-writes the image data, eliminating duplicate
	messages and returning the number of messages in the purged data.

	The "plot" instruction tells the routine to plot all messages received from
	the channel numbers we specify, or all channels if we specify a "*"
	character. Glitches caused by bad messages will be plotted also. No
	elimination of messages nor reconstruction is performed prior to plotting.
	The two parameters after the plot instruction specify the minimum and
	maximum values of the signal in the interval. The next parameter is either
	AC or DC, to specify the display coupling. After these three, we add the
	identifiers of the signals we want to plot. To specify all signals except
	the clock signal, use a "*". The routine returns a summary result of the
	form "id_num num_message ave stdev" for each selected channel. For the clock
	channel signal, which is channel number zero, the routine gives the start
	and end clock samples. The final two numbers in the summary result are the
	invalid_id code followed by the number of messages the routine did not plot.

	The "print" instruction returns the error_report string followed by the
	content of all messages, or a subrange of messages. In the event of analysis
	failure, "print" will assume messages are aligned with the first data byte
	in the image, and print out the contents of all messages, regardless of
	errors found. When analysis fails because there are too many messages in the
	image, the result string returned by print is likely to be cut off at the
	end. The "print" instruction tries to read first_message and last_message
	out of the command string. If they are present, the routine uses these as
	the first and last message numbers it writes to its return string. Otherwise
	it returns all messages.

	The "extract" instruction tells the routine to return a string containing
	all messages from a specified signal, but rejecting duplicates. A duplicate
	is any message with the same value as the previous message, and a timestamp
	that is at most one later than the previous message. The routine takes two
	parameters. The first is the identifier of the signal we want to extract.
	The second is the sampling period in clock ticks. The routine returns each
	message on a separate line. On each line is the time of the message in ticks
	from the beginning of the image time interval, followed by the sample value.
	The command writes the following numbers into ip^.results: the number of
	clock messages in the image and the number of samples it extracted.

	The "reconstruct" instruction tells the routine to reconstruct a particular
	signal with the assumption that the transmission is periodic with temporal
	scattering of transmission to avoid systematic collisions between
	transmitters. Where messages are missing from the data, the routine adds
	substitute messages. It removes duplicate messages and messages that occur
	at invalid moments in time. The result of reconstruction is a sequence of
	messages with none missing and none extra. The instruction string for the
	"reconstruct" instruction begins with the word "reconstruct" and is followed
	by several paramters. The first parameter is the identifier of the signal we
	want to reconstruct. The second parameter is its nominal sampling period in
	clock ticks. The third parameter is "standing_value", the signal's most
	recent correct sample value. The fourth parameter "glitch_threshold", a
	threshold for a glitch filter the routine can apply after reconstruction is
	complete. If the glitch threshold is zero, the glitch filters is disabled.
	The fifth parameter is "divergent_clocks", a binary value that we set when
	we want to accommodate greater disagreement between the transmitter and
	receiver clocks. By default, standing_value, glitch_threshold, and
	divent_clocks are all zero. The result string contains the reconstructed
	message stream with one message per line. Each message is represented by the
	time it occured, in ticks after the first clock in the image time interval,
	and the message data value. The "reconstruct" command writes the following
	numbers into ip^.results: the number of clock messages in the image, the
	number of messages in the reconstructed messages stream, the number of bad
	messages, and the number of substituted messages.

	The "clocks" instruction returns a the number of errors in the sequence of
	clock messages, the number of clock messages, the total number of messages
	from all signals, and the byte location of clock messages specified by a
	list of integers. The command "clocks 0 100" might return "0 128 640 0 500"
	when passed a 2560-byte block of messages containing 128 valid clocks and
	512 messages from non-clock signals. The last two numbers are the byte
	location of the 1st clock message and the byte location of the 101st clock
	message. A negative index specifies a clock message with respect to the end
	of the message block. Thus "-1" specifies the last clock message.

	The "list" instruction returns a list of signal identifiers and the number
	of samples in the signal. Signals with no samples are omitted from the list.
	The list takes the form of channel identifier followed by number of samples
	separated by spaces.

	The "get" instruction performs no analysis of messages, but instead returns
	only the id, value, and timestamp of a list of messages. We Specify each
	message with its index. The first message it message zero. A message index
	greater than the maximum number of messages the image can hold, or less than
	zero, will return zero values for all parameters.
}
function lwdaq_sct_receiver(ip:image_ptr_type;command:string):string;
	
const
	core_message_length=4;
	max_num_candidates=100;
	max_num_reports=5;
	num_divisions=0;
	min_sample=0;
	max_sample=65535;
	min_id=0;
	max_id=255;
	invalid_id=-1;
	clock_id=min_id;
	sys_reserve_ids=0;
	aux_reserve_ids=15;
	set_size=16;
	clock_period=256;
	min_period=16;
	max_period=2048;
	max_duplicate_separation=2;
	max_print_length=long_string_length;
	min_reconstruct_clocks=8;
	id_offset=0;
	sample_offset=1;
	timestamp_offset=3;
	tcb_payload_size=2;
	tcb_pwr_offset=0;
	report_timestamp_error=true;
	id_bits=4;
	max_scatter_extent=8;
	scatter_divisor=4;
	default_window_fraction=0.125;
	max_window_fraction=0.5;
	
type
	message_type=record
		id:integer; {the identifier number of the signal}
		sample:integer; {the sixteen bit sample value in the message core}
		timestamp:integer; {the eight-bit timestamp}
		time:integer; {clock ticks since start of interval}
		index:integer; {the index of the original message in image}
	end;
	message_array_type=array of message_type;
	
var 
	message_length:integer=4;
	data_size:integer=0;
	payload_size:integer=0;
	max_num_selected:integer=0;
	num_messages:integer=0;
	num_selected:integer=0;
	message_num:integer=0;
	message_index:integer=0;
	max_index:integer=0;
	i:integer=0;
	num_bad_messages:integer=0;
	mp,msp:message_array_type;
	gp:x_graph_type;
	result:string;
	error_report:string;
	instruction:string='';
	option:string='';
	word:string='';
	message_string:string='';
	trace:xy_graph_type;
	sample_num:integer=0;
	null_count:integer=0;
	null_block_length:integer=0;
	stack_height:integer=0;
	valid_index:integer=0;
	ave,stdev,min,max:real;
	m:message_type;
	num_clocks:integer=0;
	clock_num:integer=0;
	clock_index:integer=0;
	num_errors:integer=0;
	num_duplicates:integer=0;
	id_num,reconstruct_id,extract_id:integer;
	standing_value:integer=0;
	period:integer=64;
	glitch_threshold:real=0;
	num_glitches:integer;
	divergent_clocks:boolean=false;
	id_valid:array [min_id..max_id] of boolean;
	id_qty:array [min_id..max_id] of integer;
	id_previous:array [min_id..max_id] of integer;
	display_active:boolean;
	display_mode:string;
	display_min,display_max:real;
	phase_histogram:array [0..max_period-1] of integer;
	phase_index,window_index,scatter_extent:integer;
	window_extent,window_score,winning_window_score,window_phase:integer;
	candidate_list:array [0..max_num_candidates-1] of message_type;
	best_num,num_missing,num_bad,num_extracted:integer;
	smallest_deviation,deviation:integer;
	previous_clock,previous_timestamp:integer;
	window_time,num_candidates:integer;
	start_index,end_index:integer;
	receiver_version:integer;	
	payload_index:integer=0;
	done_with_options:boolean=false;

	{
		image_message reads the core of a message from the image data. We
		specify the message with its message index. The first message in the
		image is index zero. The second message is index one. The routine
		multiplies the index by message_length to get the byte address of the
		first byte of the message within the image. The routine returns an image
		record. The image record contains the index.
	}
	function image_message(ip:image_ptr_type;n:integer):message_type;
	var 
		m:message_type;
		byte_num:integer;
	begin
		byte_num:=n*message_length;
		m.id:=image_data_byte(ip,byte_num+id_offset);
		m.sample:=
			 $0100*image_data_byte(ip,byte_num+sample_offset)
			+$0001*image_data_byte(ip,byte_num+sample_offset+1);
		m.timestamp:=image_data_byte(ip,byte_num+timestamp_offset);
		m.time:=0;
		m.index:=n;
		image_message:=m;
	end;
	
	{
		write_image_message writes the core of a message into a message location
		in the image data, leaving the payload untouched. We specify the
		location with an image index.
	}
	procedure write_image_message(ip:image_ptr_type;m:message_type;n:integer);
	var byte_num:integer;
	begin
		byte_num:=n*message_length;
		write_image_data_byte(ip,m.id,byte_num+id_offset);
		write_image_data_byte(ip,m.sample div $100,byte_num+sample_offset);
		write_image_data_byte(ip,m.sample mod $100,byte_num+sample_offset+1);
		write_image_data_byte(ip,m.timestamp,byte_num+timestamp_offset)
	end;
	
	{
		payload_byte returns the m'th payload byte of message n, where the first
		payload byte is the number 0 and the last is number payload-1.
	}
	function payload_byte(ip:image_ptr_type;n,m:integer):integer;
	begin
		if m<payload_size then 
			payload_byte:=image_data_byte(ip,n*message_length+core_message_length+m)
		else 
			payload_byte:=0;
	end;
	
	{
		copy_message overwrites the n'th message with the m'th message.
	}
	procedure copy_message(ip:image_ptr_type;m,n:integer);
	var pm,pn:pointer;mm,nn:integer;
	begin
		mm:=m*message_length;
		pm:=@ip^.intensity[mm+ip^.i_size];
		nn:=n*message_length;
		pn:=@ip^.intensity[nn+ip^.i_size];
		block_move(pm,pn,message_length);
	end;
	
begin
{
	Allocate return string and check image pointer.
}
	result:='ERROR: Receiver suffered an undocumented failure.';
	lwdaq_sct_receiver:=result;
	if ip=nil then exit;
	ip^.results:='';
	mark_time('entered routine','lwdaq_sct_receiver');
{
	Read options out of the command string.
}
	done_with_options:=false;
	repeat
		option:=read_word(command);
		if option='-payload' then payload_size:=read_integer(command)
		else if option='-size' then data_size:=read_integer(command)
		else done_with_options:=true;
	until done_with_options;
{
	Implement the options.
}
	message_length:=core_message_length+payload_size;
{
	The option string now contains the instruction.
}
	instruction:=option;
{
	Put a limit on the number of messages and create the message array.
}
	max_num_selected:=trunc((length(ip^.intensity)-ip^.i_size)/message_length)-1;
{
	The get instruction does not need a message array or any analysis. We 
	execute the instruction and then exit the receiver procedure. The get
	instruction returns the message at a specified message index in the
	image data.
}
	if instruction='get' then begin
		result:='';
		word:=read_word(command);
		while word<>'' do begin
			message_index:=read_integer(word);
			if (message_index<0) or (message_index>=max_num_selected) then begin
				insert('0 0 0 ',result,length(result)+1);
			end else begin
				m:=image_message(ip,message_index);
				writestr(message_string,m.id:1,' ',m.sample:1,' ',m.timestamp:1,' ');
				insert(message_string,result,length(result)+1);
			end;
			word:=read_word(command);
		end;
		lwdaq_sct_receiver:=result;
		exit;
	end;
{
	Create a message array for use in analysis. The message array does not
	contain any payload data that may exist in the image data. The array
	contains only the core bytes of the messages, but does retain the index of
	the message in the original image. When we copy messages to fill in for
	those that are missing or corrupted, this index will be carried over, so
	that the array keeps track of where the data for each message originated.
}
	setlength(mp,max_num_selected);
{
	We scan through the messages in the image and construct an array that is
	easier for us to manipulate. If we have specified data_size = n, we go
	through exactly n messages. We select all non-null messages and copy their
	first four bytes into another array, which we can manipulate more
	efficiently during reconstruction. A null message is one for which the first
	four bytes are zero. Null messages arise only in corrupted data. We keep
	track of where each message comes from in the image data. If size = 0, we
	stop going through the data as soon as we see a null message, which acts as
	a terminating message. If our data contains null messages because of
	corruption, we will not find non-null messages following the first null
	message.

	We assign each messages in our new array a time of occurance, in units of
	clock ticks. Time zero occurs at the first clock message. A clock message is
	a messages with ID zero. Messages that occur before that have a negative
	time. We assume that the first byte of the first message is at byte zero in
	the image data.

	While we are going through the messages, we look for corruption of the image
	data. The value of the clock should increment from one message to the next,
	except when it jumps from its maximum value to zero. If we see a jump in the
	clock, we note a "clock error". Consecutive non-clock messages must have
	non-decreasing timestamps, with the exception of a drop to zero just before
	a clock message is stored. A deviation from this progression is a "timestamp
	error". The report_timestamp_error flag determines whether or not this
	routine will report timestamp errors to its error string. A clock error can
	be the result of data acquisition failing to keep up with data recording. A
	timestamp error is almost always serious because it indicates a loss of one
	or more bytes of data from the receiver. The four-byte messages become
	misaligned with respect to the four-byte boundaries in the image. A
	timestamp error can also indicate actual corruption of data bits. We observe
	timestamp errors during electrical events like static discharge and power
	failure.

	When it appears that a message is valid, we check to see if it is a
	duplicate. Sometimes the data receiver does not eliminate duplicate messages
	itself, because of the large number of possible channels upon which
	duplication can occur, and the limited logic resources in its firmware. The
	id_previous array contains for all channels the index of the previous
	message from that channel in the message array. When a new, valid message
	has an identical sample value to the previous message in the same channel,
	and the message times are no more than max_sample_separation clock ticks
	apart, we don't transfer the new message to our message array. If the
	payload size is tcb_payload_size, we have in the payload the power of the
	message and the number of the antenna input that provided the message. Of
	the duplicate messages, we want to save the one with the highest power. The
	antenna number of this message gives us an estimate of the location of the
	transmitter, and also presents to us the best antenna to use for
	transmitting commands to implantable stimulators.

	We count the number of messages for each signal identifier with the id_qty
	array. We do not count duplicate messages, but we do count bad messages in
	the signal.

	We report on the first max_num_reports errors in detail and trust that the
	data acquisition software will attempt to correct the errors and restore the
	integrity of the data.
}
	mark_time('creating message array','lwdaq_sct_receiver');
	for id_num:=min_id to max_id do id_qty[id_num]:=0;
	num_errors:=0;
	error_report:='';
	null_block_length:=0;
	null_count:=0;
	if data_size>0 then max_index:=data_size-1
	else max_index:=max_num_selected-1;
	num_selected:=0;
	num_messages:=0;
	num_clocks:=0;
	previous_clock:=0;
	previous_timestamp:=0;
	receiver_version:=-1;
	num_duplicates:=0;
	while (num_messages<=max_index) and ((null_block_length=0) or (data_size>0)) do begin
		message_string:='';
		m:=image_message(ip,num_messages);
		if (m.id=0) and (m.sample=0) and (m.timestamp=0) then inc(null_block_length)
		else begin
			if m.id=clock_id then begin 
				if (m.sample <> (previous_clock+1) mod (max_sample+1))
						and (num_clocks > 0) then
					writestr(message_string,
						'Clock Error: index=',num_messages:1,
						' current=',m.sample:1,
						' previous=',previous_clock:1,
						eol)
				else
					receiver_version:=m.timestamp;
				m.time:=num_clocks*clock_period;
				inc(num_clocks);
				previous_timestamp:=0;
				previous_clock:=m.sample;
			end else begin
				if (m.timestamp>=previous_timestamp) then begin
					m.time:=m.timestamp+(num_clocks-1)*clock_period;
				end else if (m.timestamp=0) then begin
					m.time:=num_clocks*clock_period;
				end else begin
					if report_timestamp_error then 
						writestr(message_string,
							'Timestamp Error: index=',num_messages:1,
							' current=',m.timestamp:1,
							' previous=',previous_timestamp:1,
							eol);
					m.time:=m.timestamp+(num_clocks-1)*clock_period;
				end;
				previous_timestamp:=m.timestamp;
			end;
			if null_block_length>0 then begin
				writestr(message_string,
					'Null Message Block: index=',num_messages-null_block_length:1,
					' length=',null_block_length:1,
					eol);
				null_count:=null_count+null_block_length;
				null_block_length:=0;
			end;
			with m do begin
				if (id_qty[id]=0) or (sample<>mp[id_previous[id]].sample) 
						or (time-mp[id_previous[id]].time
								>max_duplicate_separation) then begin
					id_qty[id]:=id_qty[id]+1;
					id_previous[id]:=num_selected;
					mp[num_selected]:=m;
					inc(num_selected);
				end else begin
					inc(num_duplicates);
					if (payload_size=tcb_payload_size) and 
						(payload_byte(ip,m.index,tcb_pwr_offset) >
							payload_byte(ip,mp[id_previous[id]].index,
								tcb_pwr_offset)) then begin
						for i:=id_previous[id] to num_selected-2 do
							mp[i]:=mp[i+1];
						id_previous[id]:=num_selected-1;
						mp[num_selected-1]:=m;
					end;
				end;
			end;
		end;
		if message_string<>'' then begin
			inc(num_errors);
			if num_errors<=max_num_reports then
				insert(message_string,error_report,length(error_report)+1);
			if num_errors=max_num_reports then
				insert('No report on remaining errors.'+eol,
					error_report,length(error_report)+1);
		end;
		inc(num_messages);
	end;
{
	If the final message we looked at was a null message, and data_size = 0, then this
	final message is the terminating null message, and we don't want to count it
	as an actual message.
}
	if (null_block_length>0) and (data_size=0) then dec(num_messages);
{
	If "purge", we will re-write the image data using the message array we have
	just composed, which does not contain duplicate messages. The resulting
	image data is the same as the original, but with duplicates removed. Following
	the last unique message, insert a null message to act as a terminator.
}
	if instruction='purge' then begin
		for message_num:=0 to num_selected-1 do
			if message_num<>mp[message_num].index then
				copy_message(ip,mp[message_num].index,message_num);
		m.id:=0;
		m.sample:=0;
		m.time:=0;
		write_image_message(ip,m,num_selected);
		writestr(result,num_selected:1);
	end;
{
	If "print" then we print the raw message contents to the screen. We do not
	abort the print instruction just because the data in the image is corrupted.
	The print command always returns a string describing the data. If the data
	contains an invalid sequence of clock messages, the print command declares
	this in its first line. If there are payload bytes, these follow the
	hexadecimal printing of the core message bytes, separated by a space.
}
	if instruction='print' then begin
		writestr(result,'Total ',num_messages:1,' messages, ',
			num_clocks:1,' clocks, ',
			num_errors:1,' errors, ',
			null_count:1,' null messages, ',
			num_duplicates:1,' duplicates.',eol);
		if error_report<>'' then insert(error_report,result,length(result)+1);
			
		start_index:=read_integer(command);
		if (start_index>max_index) then start_index:=num_messages;			
		if (start_index<0) then start_index:=0;

		end_index:=read_integer(command);
		if (end_index<start_index) then end_index:=start_index;
		if (end_index>num_messages) then end_index:=num_messages;
		if (end_index<0) then end_index:=0;

		writestr(message_string,
			'Messages ',start_index:1,
			' to ',end_index:1,' (index id value timestamp $hex):',eol);
		insert(message_string,result,length(result)+1);
		message_index:=start_index;
		while (message_index<=end_index) do begin
			m:=image_message(ip,message_index);
			with m do begin
				writestr(message_string,
					index:5,' ',id:3,' ',sample:5,' ',timestamp:3,' $',
					string_from_decimal(id,16,2),
					string_from_decimal(sample,16,4),
					string_from_decimal(timestamp,16,2));
				if payload_size>0 then begin
					message_string:=message_string+' ';
					for payload_index:=0 to payload_size-1 do
						writestr(message_string,message_string,
							string_from_decimal(
								payload_byte(ip,index,payload_index),16,2))
				end;
				writestr(message_string,message_string,eol);
			end;
			insert(message_string,result,length(result)+1);
			inc(message_index);
			if (length(result)>max_print_length) and (message_index<end_index-1) then begin
				insert('...'+eol,result,length(result)+1);
				message_index:=end_index-1;
			end;
		end;
		writestr(message_string,
			'Data Receiver Version ',receiver_version:1,'.');
		insert(message_string,result,length(result)+1);
	end;
{
	If "extract" then return all messages from the specified signal. Even if the
	clock messages sequence is invalid, extract will still try to retrieve all
	the messages from the specified signal.
}
	if instruction='extract' then begin
		extract_id:=read_integer(command);
		if (extract_id<min_id) or (extract_id>max_id) then begin
			report_error('Invalid extract_id in lwdaq_sct_receiver');
			exit;
		end;
		result:='';
{
		We go through the messages looking for those with the extract_id and count them.
		We write the time and sample to the return string.
}
		mark_time('extracting messages','lwdaq_sct_receiver');
		setlength(trace,num_selected);
		num_extracted:=0;
		standing_value:=0;
		for message_num:=0 to num_selected-1 do begin
			with mp[message_num] do begin
				if id=extract_id then begin
					trace[num_extracted].x:=time;
					trace[num_extracted].y:=index;
					inc(num_extracted);
					writestr(message_string,time:1,' ',sample:1);
					if length(result)>0 then message_string:=eol+message_string;
					insert(message_string,result,length(result)+1);
					if length(result)>max_print_length then begin
						report_error('Too many messages for result string in '
							+'lwdaq_sct_receiver');
						exit;
					end;
					standing_value:=sample;
				end;
			end;
		end;
{
		We create an xy-graph of the correct length and containing the
		time values in x and the message indicese in y.
}
		setlength(electronics_trace,num_extracted);	
		for message_num:=0 to num_extracted-1 do
			electronics_trace[message_num]:=trace[message_num];
{
	Record number of clocks and number extracted to the image result string, along
	with the standing value, which is the final sample. We include two zeros for
	the number missing and the number of bad messages, so as to maintain the same
	format as the results string produced by the reconstruct instruction.
}
		writestr(ip^.results,num_clocks:1,' ',num_extracted:1,
			' 0 0 ',standing_value:1,' 0');
	end;
{
	If "clocks" then we return the number of errors, the number of clock
	messages, the total number of messages, and the index of each clock messages
	we specify in the command. We specify the n'th clock message in the data
	with the number n in the command.
}
	if instruction='clocks' then begin
		writestr(result,num_errors:1,' ',num_clocks:1,' ',num_messages:1,' ');
		word:=read_word(command);
		while word<>'' do begin
			clock_num:=read_integer(word);
			if clock_num<0 then clock_num:=num_clocks+clock_num;
			clock_index:=0;
			message_index:=-1;
			message_num:=0;
			while (message_index<0) and (message_num<num_selected) do begin
				m:=mp[message_num];
				if m.id=clock_id then begin
					if clock_index=clock_num then message_index:=m.index;
					inc(clock_index);
				end;
				inc(message_num);
			end;
			writestr(result,result,message_index:1,' ');
			word:=read_word(command);
		end;
	end;
{
	If "reconstruct" then read a message identifier and period from the command
	string. Select all messages from this signal. Any messages occurring outside
	the transmission windows, or any message that is farther from the previous
	sample than another sample in the same window, will be removed.
}
	if instruction='reconstruct' then begin
		if (num_clocks<min_reconstruct_clocks) then begin
			report_error('Too few clock messages for reconstruction in lwdaq_sct_receiver');
			exit;
		end;
		
		{
			We must specify the reconstruct_id and the period.
		}
		reconstruct_id:=read_integer(command);
		if (reconstruct_id<min_id) or (reconstruct_id>max_id) then begin
			report_error('Invalid reconstruct_id in lwdaq_sct_receiver');
			exit;
		end;
		period:=read_integer(command);
		if (period<min_period) or (period>max_period) then begin
			report_error('Invalid period in lwdaq_sct_receiver');
			exit;
		end;
		
		{
			The standing_value, glitch_threshold, and divergent_clocks
			parameters are optional, in that when the command string is
			exhausted, they will assume their default values.
		}
		word:=read_word(command);
		if (word<>'') then begin
			standing_value:=read_integer(word);
			if (standing_value<min_sample) or (standing_value>max_sample) then begin
				report_error('Invalid standing_value in lwdaq_sct_receiver');
				exit;
			end;
		end;
		word:=read_word(command);
		if (word<>'') then glitch_threshold:=read_real(word);
		word:=read_word(command);
		if (word<>'') then divergent_clocks:=read_boolean(word);
{
	Determine the transmission scatter_extent and window_extent. Transmitters
	displace transmission by +-scatter_extent ticks so as to avoid systematic
	collisions with other transmitters. The scatter_extent is a fraction of the
	sample period for small periods, and a constant value for larger periods.
	The value we use here should match the transmitter firmware. 
}
		scatter_extent:=period div scatter_divisor;
		if scatter_extent>max_scatter_extent then scatter_extent:=max_scatter_extent;
{
	During reconstruction, we assume all valid messages lie in a uniformly
	spaced temporal windows. The windows must be large enough to contain the
	scatter and disagreement between the transmitter and receiver clocks. Over a
	16-s interval, a 20 ppm disagreement is 0.32 ms, or 10 clock ticks at 32.768
	kHz. If the period of the messages is small enough, we will be unable to
	accommodate such a disagreement over a 16-s interval. The window_extent is
	the half-width of the windows we use in reconstruction. If divergent_clocks
	is false, we use a smaller window. But with divergent_clocks true, we use
	the largest possible window, which is half the period.
}
		if divergent_clocks then
			window_extent:=round(max_window_fraction*period)
		else
			window_extent:=scatter_extent+round(default_window_fraction*period);
{
	Create a message stack.
}
		setlength(msp,max_num_selected);
{
	Take messages from the reconstruct signal and put them in the
	message stack. We assume the messages are in chronological order.
}
		for message_num:=0 to num_selected-1 do begin
			with mp[message_num] do begin
				if (id=reconstruct_id) then begin 
					msp[stack_height]:=mp[message_num];
					inc(stack_height);
				end;
			end;
		end;
{
	We replace the old message array with the newly-created message stack, which
	contains only messages from the reconstruct signal.
}
		mp:=msp;
		num_selected:=stack_height;
{
	Determine the phase of the transmission window. Each transmission window is
	window_extent*2+1 ticks wide, and separated by period ticks from its
	neighboring windows. We take an array of windows separated by the transmit
	period and offset by phase_index clock ticks from the time of the first
	clock message in the message block. As we increase phase_index from zero to
	one less than the transmit period, we count the number of messages that fall
	into the windows. The phase that gives us the largest number of messages is
	our best guess at the message source's nominal transmit time.
}
		mark_time('determine window phase','lwdaq_sct_receiver');
		for phase_index:=0 to period-1 do phase_histogram[phase_index]:=0;
		for message_num:=0 to num_selected-1 do
			inc(phase_histogram[mp[message_num].time mod period]);
		winning_window_score:=0;
		window_phase:=0;
		for phase_index:=0 to period-1 do begin
			window_score:=0;
			for window_index:=-window_extent to window_extent do begin
				window_score:=window_score
					+ phase_histogram[(phase_index+window_index+period) mod period];
			end;
			if window_score>winning_window_score then begin
				winning_window_score:=window_score;
				window_phase:=phase_index;
			end;
		end;
{
	Set the location of the first transmission window. 
}
		if window_phase>=period-window_extent then
			window_time:=window_phase-period
		else 
			window_time:=window_phase;
{
	Run through transmission windows. In each window, make a list of available
	samples. Ideally, there will be only one, and we accept it into our new
	list, which we are forming in the message stack. We set the standing value
	equal to its sample. But there may be two or more messages. We pick the one
	that is closest to the standing value, and we leave the standing value as it
	is. There may be no messages, in which case we insert a substitute message
	with the standing value at the center of the window. By this procedure, we
	also eliminate messages that fall outside the windows. The number of "bad
	messages" is the number that lie outside the windows plus the number that we
	reject despite lying inside the windows.
}		
		mark_time('selecting samples','lwdaq_sct_receiver');
		setlength(msp,max_num_selected);
		stack_height:=0;
		num_missing:=0;
		num_bad:=0;
		message_num:=0;
		while window_time<num_clocks*clock_period-window_extent do begin
			num_candidates:=0;
			while (message_num<num_selected) and
					(mp[message_num].time-window_time<=window_extent) and
					(num_candidates<max_num_candidates) do begin
				if abs(mp[message_num].time-window_time)<=window_extent then begin
					candidate_list[num_candidates]:=mp[message_num];
					inc(num_candidates);
				end else begin
					inc(num_bad);
				end;
				inc(message_num);
			end;
			
			if num_candidates=0 then begin
				inc(num_missing);
				with m do begin
					id:=reconstruct_id;
					sample:=standing_value;
					time:=window_time;
					if stack_height>0 then index:=msp[stack_height-1].index
					else index:=-1;
				end;
			end;
			if num_candidates=1 then begin
				m:=candidate_list[0];
				standing_value:=m.sample;
			end;
			if num_candidates>1 then begin
				best_num:=0;
				smallest_deviation:=max_sample-min_sample+1;
				for message_index:=0 to num_candidates-1 do begin
					deviation:=abs(candidate_list[message_index].sample-standing_value);
					if deviation<smallest_deviation then begin
						best_num:=message_index;
						smallest_deviation:=deviation;
					end;
				end;
				m:=candidate_list[best_num];
				num_bad:=num_bad+num_candidates-1;
			end;
			msp[stack_height]:=m;
			inc(stack_height);
			window_time:=window_time+period;
		end;
{
	We correct invalid indices, which are marked with the value -1. If there are
	no valid messages in this interval, all the indices will be left as -1, so
	any routine that uses the indices left in the electronics_trace must check
	for the index equal to -1.
}
		valid_index:=-1;
		message_num:=0;
		while (message_num<stack_height) and (valid_index=-1) do begin
			valid_index:=msp[message_num].index;
			inc(message_num);
		end;
		message_num:=0;
		while (message_num<stack_height) and (msp[message_num].index=-1) do begin
			msp[message_num].index:=valid_index;
			inc(message_num);
		end;
{
	We are now finished with the previous message list, so we dispose of it and
	replace it with our message stack.
}
		mp:=msp;
		num_selected:=stack_height;
{
	Apply a glitch filter to the signal.
}
		mark_time('applying glitch filter','lwdaq_sct_receiver');
		setlength(gp,num_selected);
		for message_num:=0 to num_selected-1 do 
			gp[message_num]:=mp[message_num].sample;
		num_glitches:=glitch_filter(gp,glitch_threshold);
		for message_num:=0 to num_selected-1 do 
			mp[message_num].sample:=round(gp[message_num]);	
		mark_time('creating electronics trace','lwdq_sct_receiver');
{
	Return the reconstructed message list in a string. Each line gives the time
	and value of a message, in order of increasing time. In an x-y graph we
	record the time and origin index of each reconstructed message.
}
		result:='';
		setlength(electronics_trace,num_selected);		
		if num_selected>0 then begin
			for message_num:=0 to num_selected-1 do begin
				with mp[message_num] do begin
					electronics_trace[message_num].x:=time;
					electronics_trace[message_num].y:=index;				
					writestr(message_string,time:1,' ',sample:1);
					if length(result)>0 then message_string:=eol+message_string;
					insert(message_string,result,length(result)+1);
					if length(result)>max_print_length then begin
						report_error('Too many messages for result string'
							+'in lwdaq_sct_receiver');
						exit;
					end;
				end;
			end;
		end;
{
	Record the meta-data in the image result string.
}
		writestr(ip^.results,num_clocks:1,' ',num_selected:1,' ',
			num_bad:1,' ',num_missing:1,' ',standing_value:1,' ',
			num_glitches:1);
	end;
{
	If "plot", we plot them on the screen and return a summary result for each
	specified signal or for all signals with samples, depending upon the
	command. Plot does not abort unless it receives an invalid command. It will
	plot data even when a clock error has occurred. I returns a list of active
	signals regardless of the state of the data.
}
 	if instruction='plot' then begin
		draw_oscilloscope_scale(ip,num_divisions);
 		display_min:=read_real(command);
 		display_max:=read_real(command);
 		display_mode:=read_word(command);

		word:=read_word(command);
 		if word='*' then begin
 			display_active:=true;
			for id_num:=min_id to max_id do 
				id_valid[id_num]:= ((id_qty[id_num] > 0) 
					and (id_num mod set_size <> sys_reserve_ids)
					and (id_num mod set_size <> aux_reserve_ids))
					or (id_num = clock_id);
 		end else begin
 			display_active:=false;
 			for id_num:=min_id to max_id do 
 				id_valid[id_num]:=false;
			while word<>'' do begin
				id_num:=read_integer(word);
				if (id_num<min_id) or (id_num>max_id) then begin
					report_error('Invalid id_num in lwdaq_sct_receiver');
					exit;
				end;
				id_valid[id_num]:=true;	
				word:=read_word(command);
			end;
 		end;
 		
 		if num_errors>0 then
			for message_num:=0 to num_selected-1 do
				mp[message_num].time:=message_num;
 		
		num_bad_messages:=0;
		
		result:='';
		for id_num:=min_id to max_id do begin
			if id_valid[id_num] then begin
				if id_qty[id_num]>0 then begin
					setlength(trace,id_qty[id_num]);
					sample_num:=0;
					for message_num:=0 to num_selected-1 do
						with mp[message_num] do begin
							if id=id_num then begin
								trace[sample_num].x:=time;
								trace[sample_num].y:=sample;
								inc(sample_num);
							end;
						end;
					ave:=average_y_xy_graph(trace);
					stdev:=stdev_y_xy_graph(trace);
					min:=min_y_xy_graph(trace);
					max:=max_y_xy_graph(trace);
					if display_mode='CP' then 
						display_real_graph(ip,trace,
							overlay_color_from_integer(id_num),
							mp[0].time,mp[num_selected-1].time,
							display_min+ave,display_max+ave,0,0)
					else if display_mode='NP' then
						display_real_graph(ip,trace,
							overlay_color_from_integer(id_num),
							mp[0].time,mp[num_selected-1].time,
							0,0,0,0)
					else 
						display_real_graph(ip,trace,
							overlay_color_from_integer(id_num),
							mp[0].time,mp[num_selected-1].time,
							display_min,display_max,0,0);
				end else begin
					ave:=0;
					stdev:=0;
					min:=0;
					max:=0;
				end;
				if (id_qty[id_num]>0) or (not display_active) then begin
					if id_num=0 then
						writestr(result,result,id_num:1,' ',num_clocks:1,' ',
							min:1:0,' ',max:1:0,' ')
					else
						writestr(result,result,id_num:1,' ',id_qty[id_num]:1,' ',
							ave:1:1,' ',stdev:1:1,' ')
				end;
			end else begin
				if id_num<>clock_id then
					num_bad_messages:=num_bad_messages+id_qty[id_num];
			end;
		end;
		
		if not display_active then
			writestr(result,result,invalid_id:1,' ',num_bad_messages:1);
	end;
{
	If "list", we list the signals that contain more than one sample, and the number
	of samples in each of these signals.
}
 	if instruction='list' then begin		
		result:='';
		for id_num:=min_id to max_id do
			if id_qty[id_num]>0 then 
				writestr(result,result,id_num:1,' ',id_qty[id_num]:1,' ');
 	end;	
{
 	Clean up.
}
	lwdaq_sct_receiver:=result;
end;

{
	lwdaq_A3008_rfpm plots and analyzes images from an A3008 radio frequency power
	meter.
}
function lwdaq_A3008_rfpm(ip:image_ptr_type;
	v_min,v_max:real;rms:boolean):string;


const
	num_divisions=10; 
	max_num_channels=30;
	
var 
	result:string='';
	input_string:string='';
	trace:xy_graph_type;
	n,num_samples,num_channels,channel_num:integer;
	startup_skip:integer;
	max,min:real;
	
begin
	lwdaq_A3008_rfpm:='ERROR: RFPM analysis failed.';
	if not valid_image_ptr(ip) then exit;
	
	draw_oscilloscope_scale(ip,num_divisions);

	input_string:=ip^.results;
	num_samples:=read_integer(input_string);
	if (num_samples>(ip^.j_size-1)*ip^.i_size) or (num_samples<1) then begin
		report_error('Invalid num_samples in lwdaq_sct_receiver');
		exit;
	end;
	startup_skip:=read_integer(input_string);
	if (startup_skip>ip^.i_size) or (startup_skip<=0) then begin
		report_error('Invalid startup_skip in lwdaq_sct_receiver');
		exit;
	end;
	num_channels:=read_integer(input_string);
	if (num_channels>max_num_channels) or (num_channels<=0) then begin
		report_error('Invalid num_channels in lwdaq_sct_receiver');
		exit;
	end;

	setlength(trace,num_samples);
	for channel_num:=0 to num_channels-1 do begin
		for n:=0 to num_samples-1 do begin
			trace[n].x:=n;
			trace[n].y:=sample_A2037E_adc8(ip,0,
				channel_num*(num_samples+startup_skip)+n+startup_skip);
		end;
		max:=max_y_xy_graph(trace);
		min:=min_y_xy_graph(trace);
		if rms then 
			writestr(result,result,' ',stdev_y_xy_graph(trace):fsr:fsd)
		else
			writestr(result,result,' ',(max-min):fsr:fsd);
		if (max<v_max) and (min>v_min) then 
			display_real_graph(ip,trace,
				overlay_color_from_integer(channel_num),
				0,num_samples-1,v_min,v_max,0,0);
	end;
{
	We make the trace available with a global pointer, after disposing of the pre-existing
	trace, should it exist.
}
	electronics_trace:=trace;

	lwdaq_A3008_rfpm:=result;
end;

{
	initialization sets up the utils variables.
}
initialization 
	setlength(electronics_trace,0);
	
end.