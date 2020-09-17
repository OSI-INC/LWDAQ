{
Utilities for Calculating Metrics of Signal Traces for Event Detection
Copyright (C) 2014-2017, Kevan Hashemi, Open Source Instruments Inc.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.	See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place - Suite 330, Boston, MA	02111-1307, USA.
}

unit metrics;

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}

interface

uses
	utils;

function metric_calculation_A(gp:x_graph_ptr;command:string):string;
function metric_calculation_B(gp:x_graph_ptr;command:string):string;
function metric_calculation_C(gp:x_graph_ptr;command:string):string;
function metric_calculation_D(gp:x_graph_ptr;command:string):string;
function metric_calculation_E(gp:x_graph_ptr;command:string):string;


implementation

{
	find_peaks_valleys runs through a signal from left to right or right to
	left, looking for significant peaks and valleys. Reversals in direction of
	less than the threshold will be ignored. If we are ascending from a valley,
	and the signal dips by 2 counts before continuing upwards, and the threshold
	is 2 counts, this dip will be ignored. The local maximum before the dip will
	not be counted, nor will the local minimum at the bottom of the dip. If the
	threshold is zero, all maxima and minima are counted. The routine adds the
	peaks and valleys to a list, and returns the list. The list contains the
	locations in the signal at which the peaks and valleys occur. But element
	zero in the list contains the number of peaks and valleys, so that element
	one contains the first peak or valley. The routine guarantees that peaks and
	valleys will alternate, so we can determine if the first location is a peaks
	by checking if it is greater than the second location. From there on, we
	alternate peaks and valleys through the list.
}
function find_peaks_valleys(
	gp:x_graph_ptr;
	left_to_right:boolean;
	threshold:real):x_graph_ptr;

var
	i,state,min_i,max_i,num_valleys,num_peaks,i_step:integer;
	max,min:real;
	pv_gp:x_graph_ptr;
	
begin
	find_peaks_valleys:=nil;
	pv_gp:=new_x_graph(length(gp^));
	if (pv_gp=nil) then begin
		report_error('failed to allocate pv_gp in  find_peaks_valleys');
		exit;
	end;
	
	if left_to_right then begin
		i_step:=1;
		i:=0;
	end else begin
		i_step:=-1;
		i:=length(gp^)-1;
	end;
	
	min:=gp^[i];
	max:=gp^[i];				
	max_i:=i;
	min_i:=i;
	state:=0;
	num_valleys:=0;
	num_peaks:=0;
	while (i>=0) and (i<length(gp^)) do begin
		if gp^[i]>max then begin
			max:=gp^[i];
			max_i:=i;
		end;
		if gp^[i]<min then begin
			min:=gp^[i];
			min_i:=i;
		end;
		if (abs(gp^[i]-min)>threshold) and (state<>-1) then begin
			pv_gp^[num_valleys+num_peaks+1]:=min_i;
			inc(num_valleys);
			max:=gp^[i];
			max_i:=i;
			min:=gp^[i];
			min_i:=i;
			state:=-1;
		end else if (abs(gp^[i]-max)>threshold) and (state<>+1) then begin
			pv_gp^[num_valleys+num_peaks+1]:=max_i;
			inc(num_peaks);
			max:=gp^[i];
			max_i:=i;
			min:=gp^[i];
			min_i:=i;
			state:=+1;
		end;
		i:=i+i_step;
	end;
{
	Add one more minimum or maximum to our list, assuming the list has space.
}
	if (state=+1) and (num_valleys+num_peaks+1<length(pv_gp^)) then begin
		pv_gp^[num_valleys+num_peaks+1]:=min_i;
		inc(num_valleys);
	end;
	if (state=-1) and (num_valleys+num_peaks+1<length(pv_gp^)) then begin
		pv_gp^[num_valleys+num_peaks+1]:=max_i;
		inc(num_peaks);
	end;
{
	Record the number of maxima and valleys in the first element of the list.
}
	pv_gp^[0]:=num_peaks+num_valleys;
{
	Return the list.
}
	find_peaks_valleys:=pv_gp;
end;

{
	metric_calculation_A takes an interval of eeg, represented by a sequence of
	real-valued samples, and calculates six real-valued metrics, each of which
	represents some quality of the interval. All six metrics are restricted to
	lie within the range 0 to 1, so that they may be used for event
	classification in a six-dimensional unit cube. The metrics are amplitude,
	coastline, intermittency, spikiness, asymmetry, and periodicity. We explain
	what each one means in the comments below.

	In addition to a pointer to a graph of sample values, the routine expects a
	command string with three positive real-valued numbers. These are the glitch
	threshold, amplitude center, and periodicity threshold. The routine applies
	a glitch filter to the incoming data. The glitch threshold guides the application
	of a glitch filter. When zero, the filter is disabled. The amplitude center is 
	the standard deviation of the signal (after glitch filtering) at which the power 
	metric should be 0.500. The periodicity threshold is the scaling factor for our
	detection of maxima and minima.

	The routine returns six metrics as a string of real numbers, in the order we
	list them above.
}
function metric_calculation_A(gp:x_graph_ptr;command:string):string;

const
	amplitude_exponent=1.0;
	coastline_center=0.3;
	coastline_exponent=2.0;
	intermittency_fraction=0.1;
	intermittency_center=0.35;
	intermittency_exponent=5.0;
	spikiness_fraction=0.2;
	spikiness_center=0.5;
	spikiness_exponent=5.0;	
	asymmetry_center=0.5;
	asymmetry_exponent=3.0;
	periodicity_fraction=0.8;
	periodicity_few_steps=10;
	periodicity_many_steps=40;
	periodicity_degeneracy_fraction=1/256;
	periodicity_degeneracy_shrink=0.8;
	periodicity_center=0.5;
	periodicity_offset=0.2;
	periodicity_exponent=3.0;
	
var 
	print_diagnostics:boolean=false;
	amplitude,coastline,intermittency,spikiness:real;
	asymmetry,periodicity,forward_periodicity,backward_periodicity:real;
	glitch_threshold,amplitude_center,periodicity_threshold:real;
	i,limit:integer;
	sum_x,sum_x2:longreal;
	ave,stdev,mad,min,max,med:real;
	list_gp,maxima_gp,minima_gp,minmax_gp:x_graph_ptr;
	s:string;
	
{
	The periodicity function runs through the signal either in the forward or
	backward direction and generates a list of steps beteween minima and between
	maxima. The list is sorted in decreasing size. The procedure runs forward with
	i_step = +1 and backwards with i_step = -1.
}
	function calculate_periodicity(i_step:integer):real;
	var
		i,state,min_i,max_i,num_min,num_max:integer;
		p,min_c,max_c:real;
		small_step:real=0;
		num_steps,num_steps_accepted:integer;
		num_degenerate_pairs:integer=0;
	begin
{
	To obtain periodicity, we first make a list of prominent maxima and minima, each
	of which extends by at least a threshold distance above the preceeding minimum or
	maximum respectively. We set this threshold to be a multiple of the mean absolute
	deviation.
}
		if i_step>0 then begin
			i:=i_step;
		end else begin
			i:=length(gp^)-1+i_step;
		end;
		min:=gp^[i];
		max:=gp^[i];				
		max_i:=i;
		max_c:=0;
		min_i:=i;
		min_c:=0;
		state:=0;
		num_min:=0;
		num_max:=0;
		while (i>0) and (i<length(gp^)-1) do begin
			if gp^[i]>max then begin
				max:=gp^[i];
				max_i:=i;
				max_c:=0;
			end else begin
				max_c:=max_c+abs(gp^[i]-gp^[i-i_step]);
			end;
			if gp^[i]<min then begin
				min:=gp^[i];
				min_i:=i;
				min_c:=0;
			end else begin
				min_c:=min_c+abs(gp^[i]-gp^[i-i_step]);
			end;
			if (min_c>0) 
					and (sqr(gp^[i]-min)/mad/min_c>periodicity_threshold) 
					and (state<>-1) then begin
				minima_gp^[num_min]:=min_i;
				minmax_gp^[num_min+num_max]:=min_i;
				inc(num_min);
				max:=gp^[i];
				max_i:=i;
				max_c:=0;
				min:=gp^[i];
				min_i:=i;
				min_c:=0;
				state:=-1;
			end else if (max_c>0) 
					and (sqr(gp^[i]-max)/mad/max_c>periodicity_threshold) 
					and (state<>+1) then begin
				maxima_gp^[num_max]:=max_i;
				minmax_gp^[num_min+num_max]:=max_i;
				inc(num_max);
				max:=gp^[i];
				max_i:=i;
				max_c:=0;
				min:=gp^[i];
				min_i:=i;
				min_c:=0;
				state:=+1;
			end;
			i:=i+i_step;
		end;
{
	We have detailed diagnostic printing to aid debugging.
}
		if print_diagnostics then begin
			writestr(s,'minima/maxima: ');
			for i:=0 to num_max+num_min-1 do writestr(s,s,minmax_gp^[i]:0:0,' ');
			gui_writeln(s);
		end;
{
	Go through the minima and maxima and obtain for each a measure of the period
	of any periodic waveform present in the signal. Assemble all the steps in the
	list graph.
}
		for i:=1 to num_min-1 do list_gp^[i-1]:=abs(minima_gp^[i]-minima_gp^[i-1]);
		for i:=1 to num_max-1 do list_gp^[i-1+num_min-1]:=abs(maxima_gp^[i]-maxima_gp^[i-1]);
		num_steps:=num_min-1+num_max-1;
		if print_diagnostics then begin
			writestr(s,'unsorted steps: ');
			for i:=0 to num_steps-1 do writestr(s,s,list_gp^[i]:0:0,' ');
			gui_writeln(s);
		end;
{
	Sort the steps in descending order of size and obtain the median step
	size.
}
		quick_sort(0,num_steps-1,x_graph_swap,x_graph_lt,list_gp);
		if print_diagnostics then begin
			writestr(s,'sorted steps: ');
			for i:=0 to num_steps-1 do writestr(s,s,list_gp^[i]:0:0,' ');
			gui_writeln(s);
		end;
		if num_steps>1 then 
			med:=list_gp^[round((num_steps-1)/2.0)]
		else 
			med:=list_gp^[0];
{
	Select the steps that are within periodicity_fraction of the median
	step.
}
		if print_diagnostics then writestr(s,'selected steps: ');
		sum_x:=0;
		sum_x2:=0;
		num_steps_accepted:=0;
		for i:=0 to num_steps-1 do begin
			if (list_gp^[i]<=med/periodicity_fraction) 
				and (list_gp^[i]>=med*periodicity_fraction) then begin
				sum_x:=sum_x+list_gp^[i];
				sum_x2:=sum_x2+list_gp^[i]*list_gp^[i];
				inc(num_steps_accepted);
				if print_diagnostics then writestr(s,s,list_gp^[i]:0:0,' ');
			end;
		end;
		if print_diagnostics then gui_writeln(s);
{
	The periodicity is the ratio of the number of accepted steps to the total
	number of steps. But we reduce periodicity for special degenerate cases. We
	also over-write the values of ave and stdev so that we can produce a diagnostic
	print that gives the standard deviation and average of the accepted steps.
}
		if num_steps_accepted>0 then begin
			if num_steps>periodicity_few_steps then
				p:=num_steps_accepted/num_steps
			else 
				p:=num_steps_accepted/periodicity_few_steps;
	
			if num_steps_accepted<periodicity_few_steps then
				p:=p*num_steps_accepted/periodicity_few_steps;
	
			small_step:=length(gp^)/periodicity_many_steps;
			if med<small_step then
				p:=p*med/small_step;
	
			num_degenerate_pairs:=0;
			for i:=1 to num_steps-1 do 
				if abs(minmax_gp^[i]-minmax_gp^[i-1])
					<=length(gp^)*periodicity_degeneracy_fraction then begin
					inc(num_degenerate_pairs);
					p:=p*periodicity_degeneracy_shrink;
			end;
	
			ave:=sum_x/num_steps_accepted;
			stdev:=sqrt(sum_x2/num_steps_accepted-ave*ave);
		end else begin
			p:=0;
			ave:=0;
			stdev:=0;
		end;
{
	In diagnostic operation we print more information about the accepted steps.
}
		if print_diagnostics then begin
			writestr(s,'num=',num_steps:1,
				' num_accepted=',num_steps_accepted:1,
				' num_degenerate=',num_degenerate_pairs:1,
				' median=',med:0:0,
				' ave=',ave:0:1,
				' stdev=',stdev:0:1,
				' small=',small_step:0:1,
				' periodicity=',p:0:3);
			gui_writeln(s);		
		end;
		calculate_periodicity:=p;
	end;

begin
{
	We assign default values to the metrics and check the incoming graph pointer.
}
	metric_calculation_A:='0 0 0 0 0 0';
	if gp=nil then exit;
	if length(gp^)<=1 then begin
		report_error('length(gp^)<=1 in metric_calculation_A');
		exit;
	end;
{
	Allocate space for four graphs the same length as the input graph.
}
	list_gp:=new_x_graph(length(gp^));
	maxima_gp:=new_x_graph(length(gp^));
	minima_gp:=new_x_graph(length(gp^));
	minmax_gp:=new_x_graph(length(gp^));
	if (list_gp=nil) or (maxima_gp=nil) 
			or (minima_gp=nil) or (minmax_gp=nil) then begin
		report_error('failed to allocate an x_graph_type in metric_calculation_A');
		exit;
	end;
{
	Read parameters from the command string.
}
	glitch_threshold:=read_real(command);
	amplitude_center:=read_real(command);
	periodicity_threshold:=read_real(command);
	print_diagnostics:=read_boolean(command);
	if error_string<>'' then exit;
{
	Apply a glitch filter to the input samples. If the glitch threshold is zero,
	the filter will be disabled. If the data has already been glitch-filtered there
	is no need to do so again.
}
	glitch_filter(gp,glitch_threshold);
{
	In one pass, calculate the average, standard deviation, and coastline of
	the glitch-filtered signal. We store the absolute derivative of coastline,
	which is the absolute difference between consecutive samples, in the list
	graph. This graph will have one fewer valid entries than the original graph,
	so we set its first value to zero to make up the number of samples.
}
	sum_x:=0;
	sum_x2:=0;
	coastline:=0;
	min:=gp^[0];
	max:=gp^[0];
	list_gp^[0]:=0;
	for i:=0 to length(gp^)-1 do begin
		sum_x:=sum_x+gp^[i];
		sum_x2:=sum_x2+gp^[i]*gp^[i];
		if gp^[i]>max then max:=gp^[i];
		if gp^[i]<min then min:=gp^[i];
		if (i>0) then begin
			list_gp^[i]:=abs(gp^[i]-gp^[i-1]);
			coastline:=coastline+list_gp^[i];
		end;
	end;
	check_for_math_error(sum_x);
	check_for_math_error(sum_x2);
	if error_string<>'' then exit;
	ave:=sum_x/length(gp^);
	stdev:=sqrt(sum_x2/length(gp^)-ave*ave);
{
	Calculate the amplitude metric, which lies between zero and one.
}
	if print_diagnostics then begin
		writestr(s,'stdev: ',stdev:0:3,' ave ',ave:0:1);
		gui_writeln(s);
	end;
	amplitude:=1/(1+xpy(
		amplitude_center / stdev,
		amplitude_exponent));
{
	Calculate intermittency. Sort the coastline derivative, which is now
	in the list graph, in descending order. Sum the first N entries, where
	N we obtain by multiplying the number of entries by the intermittency
	fraction. We divide this sum by the coastline to get a measure of how
	concentrated the coastline is in features of the signal. We apply a
	sigmoidal function to get the intermittency metric.
}
	x_graph_descending(list_gp);
	limit:=round(intermittency_fraction*length(list_gp^));
	sum_x:=0;
	for i:=0 to limit-1 do sum_x:=sum_x+list_gp^[i];
	if sum_x>0 then intermittency:=sum_x/coastline
	else intermittency:=0.001;
	if print_diagnostics then begin
		writestr(s,'intermittency: ',intermittency:0:3,' limit ',limit:0);
		gui_writeln(s);
	end;
	intermittency:=1/(1+xpy(
		intermittency_center / intermittency,
		intermittency_exponent));
{
	Calculate the mean absolute deviation of the signal. We use this deviation 
	in the calculation of the remaining metrics.
}
	mad:=0;
	for i:=0 to length(gp^)-1 do
		mad:=mad+abs(gp^[i]-ave);
	mad:=mad/length(gp^);
{
	Divide the coastline by the mean absolute deviation to obtain a normalized 
	coastline, then apply sigmoidal function to generate the coastline metric.
}
	if mad>0 then coastline:=coastline/mad/length(gp^)
	else coastline:=0.0;
	if print_diagnostics then begin
		writestr(s,'coastline: ',coastline:0:3,' mad ',mad:0:1);
		gui_writeln(s);
	end;
	coastline:=1/(1+xpy(
		coastline_center / coastline,
		coastline_exponent));
{
	Over-write the list graph with the difference between the glitch-filtered
	samples and their average value. Sort them in descending order of absolute
	value. Thus -1000 comes before 999. We add the absolute values of the first
	N elements in the list, where N is the number of elements multiplied by the
	spikiness fraction. We divide this sum by the total sum of absolute deviations
	from the mean to obtain a measure of how concentrated the deviation is in 
	features of the signal. We apply a sigmoidal function to get the spiminess
	metric between zero and one.
}
	for i:=0 to length(list_gp^)-1 do list_gp^[i]:=gp^[i]-ave;
	x_graph_descending_abs(list_gp);
	limit:=round(spikiness_fraction*length(list_gp^));
	sum_x:=0;
	for i:=0 to limit-1 do sum_x:=sum_x+abs(list_gp^[i]);
	if sum_x>0 then spikiness:=sum_x/mad/length(list_gp^)
	else spikiness:=0.001;
	if print_diagnostics then begin
		writestr(s,'spikiness: ',spikiness:0:3,' sum_x ',sum_x:0:1);
		gui_writeln(s);
	end;
	spikiness:=1/(1+xpy(
		spikiness_center / spikiness,
		spikiness_exponent));
{
	We now find the contribution to spikiness that is due to positive deviations,
	and divite this by the contribution due to both positive and negative, so as to
	obtain a measure of asymmetry. We apply a signmoidal function and get the 
	asymmetry metric.
}
	sum_x2:=0;
	for i:=0 to limit-1 do 
		if list_gp^[i]>0 then
			sum_x2:=sum_x2+abs(list_gp^[i]);
	if sum_x>0 then asymmetry:=sum_x2/sum_x
	else asymmetry:=0.5;
	if print_diagnostics then begin
		writestr(s,'asymmetry: ',asymmetry:0:3,' sum_x2 ',sum_x2:0:1);
		gui_writeln(s);
	end;
	asymmetry:=1/(1+xpy(
		asymmetry_center / asymmetry,
		asymmetry_exponent));
{
	We call the calculate_periodicity function to determine periodicity in both
	the forward and backward direction in the waveform. We use the smaller of the
	two values, on the grounds that a random occurance of periodicity in one direction
	is very unlikely to occur in the backward direction as well, while an actual
	occurance will appear in both directions.
}
	forward_periodicity:=calculate_periodicity(1);
	backward_periodicity:=calculate_periodicity(-1);
	if forward_periodicity<backward_periodicity then
		periodicity:=forward_periodicity
	else
		periodicity:=backward_periodicity;
{
	Calculate the periodicity metric, which lies between zero and one.
}
	periodicity:=periodicity+periodicity_offset;
	periodicity:=1/(1+xpy(
		periodicity_center / periodicity,
		periodicity_exponent));
{
	Dispose of our graphs.
}
	dispose_x_graph(maxima_gp);
	dispose_x_graph(minima_gp);
	dispose_x_graph(minmax_gp);
	dispose_x_graph(list_gp);
	if error_string<>'' then exit;
{
	Create the return string.
}
	writestr(s,
		amplitude:fsr:fsd,' ',
		coastline:fsr:fsd,' ',
		intermittency:fsr:fsd,' ',
		spikiness:fsr:fsd,' ',
		asymmetry:fsr:fsd,' ',
		periodicity:fsr:fsd);
	metric_calculation_A:=s;
end;

{
	metric_calculation_B calculates the following metrics of a signal and returns them
	in a string.

	Power: Bounded 0 to 1, increasing function of the standard deviation divided
	by baseline power, equals 0.5 when this ratio is 1.0.

	Coastline: Bounded 0 to 1, increasing function of the one-dimensional
	coastline divided by the mean absolute deviation and the number of points.

	Intermittency: Bounded 0 to 1, increasing function of the fraction of the
	coastline generated by the 10% largest coastline steps.

	Spikiness: Bounded 0 to 1, increasing function of the average peak to valley
	height divided by the signal range, where the peaks and valleys are all
	those present in the signal with height or depth greater than the spikiness
	threshold multiplied by the signal range. The spikiness threshold should be
	lower than the periodicity threshold.

	Asymmetry: Bounded 0 to 1, increasing with the ratio of max-ave to ave-min.

	Periodicity: Bounded 0 to 1, increasing with the ratio of the number of
	accepted steps to the total number of steps, where a step is the separation
	of two peaks or two valleys, as obtained from a list of peaks and valleys
	with depth greater than the periodicity threshold multiplied by signal
	range. We accept all steps within 20% of the best step size, and we
	determine the best step size as the step size for which we have the largest
	number of accepted steps. We reduce the periodicity according to certain
	rules so as to make its calculation less vulnerable to random baseline
	intervals. If the number of peaks and valleys we obtain with the spikiness
	threshold is significantly greater than for the periodicity threshold (as
	set by the periodicity_instability_fraction), we reduce the periodicity in
	proportion to the excess. If there are too few steps or if some steps are
	too small, we reduce periodicity. Note that the periodicity metric is a
	measure of how certain we are that there is a periodic waveform in the
	signal, not a measure of the frequency of the waveform. We have a separate
	frequency metric for that.
	
	Frequency: Greater than or equal to zero, the number of best_step periods
	that fit in the interval width. If the interval is one second long, the
	value is a multiple of 1 Hz. If two seconds long, the value is a multiple of
	0.5 Hz.
}
function metric_calculation_B(gp:x_graph_ptr;command:string):string;

const
	amplitude_exponent=1.0;
	coastline_center=0.3;
	coastline_exponent=2.0;
	intermittency_fraction=0.1;
	intermittency_center=0.35;
	intermittency_exponent=5.0;
	spikiness_center=0.4;
	spikiness_exponent=3.0;	
	asymmetry_center=1.0;
	asymmetry_exponent=2.0;
	periodicity_fraction=0.8;
	periodicity_few_steps=10;
	periodicity_many_steps=40;
	periodicity_degenerate_step=2;
	periodicity_degeneracy_shrink=0.8;
	periodicity_instability_ratio=1.5;
	periodicity_center=0.4;
	periodicity_offset=0.1;
	periodicity_exponent=2.0;
	
var 
	print_diagnostics:boolean=false;
	amplitude:real=0;
	coastline:real=0;
	intermittency:real=0;
	spikiness:real=0.0;
	asymmetry:real=0;
	periodicity:real=0;
	frequency:real=0;
	stability:real=0.0;
	glitch_threshold:real=0;
	amplitude_center:real=0;
	spikiness_threshold:real=0;
	periodicity_threshold:real=0.0;
	i,j,limit,num_pv_s,num_pv_p:integer;
	sum_x,sum_x2,sum_separation,high_coastline:longreal;
	ave,stdev,mad,min,max,range,mas:real;
	list_gp,pv_gp:x_graph_ptr;
	hi_step,best_step,small_step,num_steps,num_steps_accepted:integer;
	num_degenerate_pairs:integer=0;
	s:string;
	
begin
{
	We assign default values to the metrics and check the incoming graph pointer.
}
	metric_calculation_B:='0 0 0 0 0 0 0';
	if gp=nil then exit;
	if length(gp^)<=1 then begin
		report_error('length(gp^)<=1 in metric_calculation_B');
		exit;
	end;
{
	Allocate space for four graphs the same length as the input graph.
}
	list_gp:=new_x_graph(length(gp^));
	if (list_gp=nil) then begin
		report_error('failed to allocate an x_graph_type in metric_calculation_B');
		exit;
	end;
{
	Read parameters from the command string.
}
	glitch_threshold:=read_real(command);
	amplitude_center:=read_real(command);
	spikiness_threshold:=read_real(command);
	periodicity_threshold:=read_real(command);
	print_diagnostics:=read_boolean(command);
	if error_string<>'' then exit;
{
	Apply a glitch filter to the input samples. If the glitch threshold is zero,
	the filter will be disabled. If the data has already been glitch-filtered there
	is no need to do so again.
}
	glitch_filter(gp,glitch_threshold);
{
	In one pass, calculate the average, standard deviation, and coastline of
	the glitch-filtered signal. We store the absolute derivative of coastline,
	which is the absolute difference between consecutive samples, in the list
	graph. This graph will have one fewer valid entries than the original graph,
	so we set its first value to zero to make up the number of samples. The mas
	variable gets the mean absolute step size for the interval.
}
	sum_x:=0;
	sum_x2:=0;
	coastline:=0;
	min:=gp^[0];
	max:=gp^[0];
	list_gp^[0]:=0;
	for i:=0 to length(gp^)-1 do begin
		sum_x:=sum_x+gp^[i];
		sum_x2:=sum_x2+gp^[i]*gp^[i];
		if gp^[i]>max then max:=gp^[i];
		if gp^[i]<min then min:=gp^[i];
		if (i>0) then begin
			list_gp^[i]:=abs(gp^[i]-gp^[i-1]);
			coastline:=coastline+list_gp^[i];
		end;
	end;
	check_for_math_error(sum_x);
	check_for_math_error(sum_x2);
	if error_string<>'' then exit;
	range:=max-min;
	if range<=0 then exit;
	ave:=sum_x/length(gp^);
	stdev:=sqrt(sum_x2/length(gp^)-ave*ave);
	mas:=coastline/length(gp^);
{
	Calculate the amplitude metric, which lies between zero and one.
}
	if print_diagnostics then begin
		writestr(s,'Amplitude: ',stdev/amplitude_center:0:3,
			' stdev=',stdev:0:1,' ave=',ave:0:1,' range=',range:0:1);
		gui_writeln(s);
	end;
	amplitude:=1/(1+xpy(
		amplitude_center / stdev,
		amplitude_exponent));
{
	Calculate intermittency. Sort the coastline derivative, which is now
	in the list graph, in descending order. Sum the first N entries, where
	N we obtain by multiplying the number of entries by the intermittency
	fraction. We divide this sum by the coastline to get a measure of how
	concentrated the coastline is in features of the signal. We apply a
	sigmoidal function to get the intermittency metric.
}
	x_graph_descending(list_gp);
	limit:=round(intermittency_fraction*length(list_gp^));
	high_coastline:=0;
	for i:=0 to limit-1 do high_coastline:=high_coastline+list_gp^[i];
	if high_coastline>0 then intermittency:=high_coastline/coastline
	else intermittency:=0.001;
	if print_diagnostics then begin
		writestr(s,'Intermittency: ',intermittency:0:3,
			' limit=',limit:0,' high_coastline=',high_coastline:0:1);
		gui_writeln(s);
	end;
	intermittency:=1/(1+xpy(
		intermittency_center / intermittency,
		intermittency_exponent));
{
	Calculate the mean absolute deviation of the signal. We use this deviation 
	in the calculation of the remaining metrics.
}
	mad:=0;
	for i:=0 to length(gp^)-1 do
		mad:=mad+abs(gp^[i]-ave);
	mad:=mad/length(gp^);
{
	Divide the coastline by the mean absolute deviation to obtain a normalized 
	coastline, then apply sigmoidal function to generate the coastline metric.
}
	coastline:=coastline/mad/length(gp^);
	if print_diagnostics then begin
		writestr(s,'Coastline: ',coastline:0:3,' mad=',mad:0:1,' mas=',mas:0:1);
		gui_writeln(s);
	end;
	coastline:=1/(1+xpy(
		coastline_center / coastline,
		coastline_exponent));
{
	Calculate the asymmetry metric.
}
	if (ave-min)>0 then asymmetry:=(max-ave)/(ave-min)
	else asymmetry:=0.5;
	if print_diagnostics then begin
		writestr(s,'Asymmetry: ',asymmetry:0:3,
			' max-ave=',max-ave:0:1,' ave-min=',ave-min:0:1);
		gui_writeln(s);
	end;
	asymmetry:=1/(1+xpy(
		asymmetry_center / asymmetry,
		asymmetry_exponent));
{
	We calculate spikiness using a list of peaks and valleys. A peak is 
	a positive excursion of a height greater than a threshold, and a valley
	is the opposite. The spikiness threshold is a multiple of the
	signal range, so we convert to signal units by multiplying by the range.
}
	pv_gp:=find_peaks_valleys(gp,true,spikiness_threshold*range);
	num_pv_s:=round(pv_gp^[0]);
{
	Diagnostic printing to aid debugging.
} 
	if print_diagnostics then begin
		writestr(s,'Spikiness Peaks and Valleys: ');
		for i:=1 to num_pv_s do writestr(s,s,pv_gp^[i]:0:0,' ');
		gui_writeln(s);
	end;
{
	We obtain the spikiness measure by calculating the average separation of 
	the neighboring peaks and valleys.
}
	sum_separation:=0;
	for i:=1 to num_pv_s-1 do begin
		sum_separation:=sum_separation
			+abs(gp^[round(pv_gp^[i+1])]-gp^[round(pv_gp^[i])])/range;
	end;
	if num_pv_s>1 then spikiness:=sum_separation/(num_pv_s-1)
	else spikiness:=0;
	if print_diagnostics then begin
		writestr(s,'Spikiness: ',spikiness:0:3,
			' threshold=',spikiness_threshold*range:0:1,
			' num_pv_s=',num_pv_s:1,
			' sum_separation=',sum_separation:0:3);
		gui_writeln(s);
	end;
{
	We are done with the spikiness peak and valley list.
}
	dispose_x_graph(pv_gp);
{
	Calculate the spikiness metric, which lies between zero and one.
}
	if spikiness>0 then 
		spikiness:=1/(1+xpy(
			spikiness_center / spikiness,
			spikiness_exponent));
{
	We begin calculation of periodicity by calling find_peaks_valleys to get the
	locations of the peaks and valleys in our signal.
}
	pv_gp:=find_peaks_valleys(gp,true,periodicity_threshold*range);
	num_pv_p:=round(pv_gp^[0]);
{
	Diagnostic printing to aid debugging.
} 
	if print_diagnostics then begin
		writestr(s,'Periodicity Peaks and Valleys: ');
		for i:=1 to num_pv_p do writestr(s,s,pv_gp^[i]:0:0,' ');
		gui_writeln(s);
	end;
{
	Go through the valleys and peaks and obtain a list of step sizes, then sort
	them in order of decreasing size.
}
	num_steps:=num_pv_p-1-1;
	for i:=1 to num_steps do list_gp^[i-1]:=abs(pv_gp^[i+2]-pv_gp^[i]);
	quick_sort(0,num_steps-1,x_graph_swap,x_graph_lt,list_gp);
	if print_diagnostics then begin
		writestr(s,'Sorted Step Sizes: ');
		for i:=0 to num_steps-1 do writestr(s,s,list_gp^[i]:0:0,' ');
		gui_writeln(s);
	end;
{
	For each step, count how many other steps are within the range defined by 
	our periodicity_fraction. The step size with the greatest number of other
	steps within this range of its value is our best guess at the period of the
	waveform, and the number of steps within range will be, as a fraction of 
	the total number of steps, the basis of our periodicity measurement.
}
	num_steps_accepted:=0;
	best_step:=0;
	hi_step:=0;
	for j:=0 to num_steps-1 do begin
		if best_step<>round(list_gp^[j]) then begin
			while (hi_step<num_steps) and
					(list_gp^[hi_step]>list_gp^[j]/periodicity_fraction) do
				inc(hi_step);
			i:=hi_step;
			while (i<num_steps) and
					(list_gp^[i]>=list_gp^[j]*periodicity_fraction) do
				inc(i);
			if i-hi_step+1>num_steps_accepted then begin
				num_steps_accepted:=i-hi_step+1;
				best_step:=round(list_gp^[j]);
			end;
		end;
	end;
{
	If we are printing diagnostic information, it's useful to know which steps we
	selected.
}
	if print_diagnostics then begin
		writestr(s,'Selected Step Sizes: ');
		for i:=0 to num_steps-1 do 
			if (list_gp^[i]<=best_step/periodicity_fraction) 
				and (list_gp^[i]>=best_step*periodicity_fraction) then
			writestr(s,s,list_gp^[i]:0:0,' ');
		gui_writeln(s);
	end;
{
	The periodicity is the ratio of the number of accepted steps to the total
	number of steps. But we reduce periodicity for special degenerate cases. One
	degenerate case is when the steps are very small. Another is when the number
	of peaks and valleys we obtained for spikiness is dramatically greater than
	the number we obtained for periodicity.
}
	if num_steps_accepted>0 then begin
		periodicity:=num_steps_accepted/num_steps;
		if num_steps_accepted<periodicity_few_steps then
			periodicity:=periodicity*sqr(num_steps_accepted/periodicity_few_steps);
		small_step:=1+trunc(length(gp^)/periodicity_many_steps);
		if best_step<small_step then
			periodicity:=periodicity*best_step/small_step;
		num_degenerate_pairs:=0;
		for i:=1 to num_steps-1 do 
			if abs(pv_gp^[i+1]-pv_gp^[i])
				<=periodicity_degenerate_step then begin
				inc(num_degenerate_pairs);
				periodicity:=periodicity*periodicity_degeneracy_shrink;
		end;
		if num_pv_s>periodicity_instability_ratio*num_pv_p then begin
			stability:=sqr(
					num_pv_p /
					(num_pv_s-num_pv_p*(periodicity_instability_ratio-1.0)));
			periodicity:=periodicity*stability;
		end else begin
			stability:=1.0;
		end;
	end else begin
		periodicity:=0;
		stability:=0;
	end;
{
	Now that we have a best value for the periodic step size, we can produce an
	estimate of frequency in units of cycles per interval.
}
	if best_step>0 then frequency:=length(gp^)/best_step
	else frequency:=length(gp^);
{
	We are done with the peak and valley list.
}
	dispose_x_graph(pv_gp);
{
	In diagnostic operation we print more information about the accepted steps.
}
	if print_diagnostics then begin
		writestr(s,'Periodicity: ',periodicity:0:3,
			' threshold=',periodicity_threshold*range:0:1,
			' num_steps=',num_steps:1,
			' num_steps_accepted=',num_steps_accepted:1,
			' num_degenerate_pairs=',num_degenerate_pairs:1);
		gui_writeln(s);		
		writestr(s,'Frequency: ',frequency:0:1,
			' best_step=',best_step:1,
			' num_pv_p=',num_pv_p:1,
			' stability=',stability:0:3);
		gui_writeln(s);
	end;
{
	Calculate the periodicity metric, which lies between zero and one.
}
	periodicity:=periodicity+periodicity_offset;
	periodicity:=1/(1+xpy(
		periodicity_center / periodicity,
		periodicity_exponent));
{
	Dispose of our list graph.
}
	dispose_x_graph(list_gp);
	if error_string<>'' then exit;
{
	Create the return string.
}
	writestr(s,
		amplitude:fsr:fsd,' ',
		coastline:fsr:fsd,' ',
		intermittency:fsr:fsd,' ',
		spikiness:fsr:fsd,' ',
		asymmetry:fsr:fsd,' ',
		periodicity:fsr:fsd,' ',
		frequency:fsr:fsd);
	metric_calculation_B:=s;
end;


{
	metric_calculation_C calculates the following measures of a signal and returns them
	in a string. Note that this routine does not return a metric between zero
	and one, but rather a measure that is greater than zero.

	Amplitude: The standard deviation of the signal.

	Coastline: The ratio of the mean absolute step size to the minimum possible
	step size to develop the same signal range with a straight line.

	Intermittency: The fraction of the coastline generated by the first
	intermittency fraction largest coastline steps.

	Coherence: The average height of the peaks and valleys as a fraction of the
	signal range.

	Asymmetry: The difference between the number of points above the mean plus
	asymmetry-extent standard deviations and the number below the mean minus
	asymmetry-extent standard deviations, divided by the number of points more
	than asymmetry-weight standard deviations from the mean.

	Rhythm: The ratio of the number of accepted steps to the total number of
	steps, where a step is the separation of two major peaks or two valleys, as
	obtained from a list of peaks and valleys with depth greater than the rhythm
	threshold multiplied by signal range. We accept all steps within a range
	defined by rhythm_fraction. The best step size is the one for which we have
	the largest number of accepted steps. We reduce the rhythm according to
	certain rules so as to make its calculation less vulnerable to random
	baseline intervals. If the number of minor peaks and valleys we obtain with
	a lower threshold is significantly greater than the number of major peaks
	and valleys, we reduce the rhythm in proportion to the excess. If there are
	too few steps or if some steps are too small, we reduce rhythm. Note that
	rhythm is a measure of how certain we are that there is a periodic waveform
	in the signal, not a measure of the frequency of the waveform. We have a
	separate frequency measure for that.

	Frequency: Greater than or equal to zero, the number of best_step periods
	that fit in the interval width. If the interval is one second long, the
	value is a multiple of 1 Hz. If two seconds long, the value is a multiple of
	0.5 Hz.
}
function metric_calculation_C(gp:x_graph_ptr;command:string):string;

const
	intermittency_fraction=0.1;
	asymmetry_extent=2.0;
	asymmetry_weight=1.5;
	rhythm_fraction=0.8;
	rhythm_few_steps=10;
	rhythm_many_steps=40;
	rhythm_degenerate_step=2;
	rhythm_degeneracy_shrink=0.8;
	rhythm_instability_ratio=1.5;
	rhythm_offset=0.1;
	small_value=0.0001;
	
var 
	print_diagnostics:boolean=false;
	amplitude:real=0;
	coastline:real=0;
	intermittency:real=0;
	coherence:real=0.0;
	asymmetry:real=0;
	rhythm:real=0;
	frequency:real=0;
	stability:real=0.0;
	glitch_threshold:real=0;
	num_glitches:integer;
	rhythm_threshold:real=0;
	coherence_threshold:real=0.0;
	count:integer=0;
	upcount:integer=0;
	downcount:integer=0;
	i,j,limit,num_pv_minor,num_pv_major:integer;
	sum_x,sum_x2,sum_separation,high_coastline:longreal;
	ave, {average value}
	stdev, {standard deviation}
	min, {minimum}
	max, {maximum}
	range, {maximum-minimum}
	mad, {mean absolute deviation}
	mas, {mean absolute step size, coastline divided by number of points}
	las {linear absolute step size, range divided by number of points}
	:real;
	list_gp,pv_gp:x_graph_ptr;
	hi_step,best_step,small_step,num_steps,num_steps_accepted:integer;
	num_degenerate_pairs:integer=0;
	s:string;
	
begin
{
	We assign default values to the measures and check the incoming graph pointer.
}
	metric_calculation_C:='0 0 0 0 0 0 0 0';
	if gp=nil then exit;
	if length(gp^)<=1 then begin
		report_error('length(gp^)<=1 in metric_calculation_C');
		exit;
	end;
{
	Allocate space for four graphs the same length as the input graph.
}
	list_gp:=new_x_graph(length(gp^));
	if (list_gp=nil) then begin
		report_error('failed to allocate an x_graph_type in metric_calculation_C');
		exit;
	end;
{
	Read parameters from the command string.
}
	glitch_threshold:=read_real(command);
	coherence_threshold:=read_real(command);
	rhythm_threshold:=read_real(command);
	print_diagnostics:=read_boolean(command);
	if error_string<>'' then exit;
{
	Apply a glitch filter to the input samples. If the glitch threshold is zero,
	the filter will be disabled. If the data has already been glitch-filtered there
	is no need to do so again.
}
	num_glitches:=glitch_filter(gp,glitch_threshold);
{
	In one pass, calculate the average, standard deviation, and coastline of the
	glitch-filtered signal. We store the absolute difference between consecutive
	samples in the list graph. This graph will have one fewer valid entries than
	the original graph, so we set its first value to zero to make up the number
	of samples. The mas variable gets the mean absolute step size for the
	interval.
}
	sum_x:=0;
	sum_x2:=0;
	coastline:=0;
	min:=gp^[0];
	max:=gp^[0];
	list_gp^[0]:=0;
	for i:=0 to length(gp^)-1 do begin
		sum_x:=sum_x+gp^[i];
		sum_x2:=sum_x2+gp^[i]*gp^[i];
		if gp^[i]>max then max:=gp^[i];
		if gp^[i]<min then min:=gp^[i];
		if (i>0) then begin
			list_gp^[i]:=abs(gp^[i]-gp^[i-1]);
			coastline:=coastline+list_gp^[i];
		end;
	end;
	check_for_math_error(sum_x);
	check_for_math_error(sum_x2);
	if error_string<>'' then exit;
	range:=max-min;
	if range<=0 then exit;
	ave:=sum_x/length(gp^);
	stdev:=sqrt(sum_x2/length(gp^)-ave*ave);
	mas:=coastline/length(gp^);
	las:=range/length(gp^);
{
	Calculate the mean absolute deviation of the signal.
}
	mad:=0;
	for i:=0 to length(gp^)-1 do
		mad:=mad+abs(gp^[i]-ave);
	mad:=mad/length(gp^);
{
	Calculate the amplitude measure, which lies between zero and one.
}
	if print_diagnostics then begin
		writestr(s,'Amplitude: ',
			' stdev=',stdev:0:1,' ave=',ave:0:1,
			' mad=',mad:0:1,' range=',range:0:1);
		gui_writeln(s);
	end;
	amplitude:=stdev;
{
	Calculate intermittency. Sort the coastline derivative, which is now
	in the list graph, in descending order. Sum the first N entries, where
	N we obtain by multiplying the number of entries by the intermittency
	fraction. We divide this sum by the coastline to get a measure of how
	concentrated the coastline is in features of the signal. We apply a
	sigmoidal function to get the intermittency measure.
}
	x_graph_descending(list_gp);
	limit:=round(intermittency_fraction*length(list_gp^));
	high_coastline:=0;
	for i:=0 to limit-1 do high_coastline:=high_coastline+list_gp^[i];
	if high_coastline>0 then intermittency:=high_coastline/coastline
	else intermittency:=small_value;
	if print_diagnostics then begin
		writestr(s,'Intermittency: ',intermittency:0:3,
			' limit=',limit:0,
			' high_coastline=',high_coastline:0:1,
			' coastline=',coastline:0:1);
		gui_writeln(s);
	end;
{
	Divide the mean average step by least absolute step size to get the normalized
	coastline, and calculate the coastline measure.
}
	coastline:=mas/las;
	if print_diagnostics then begin
		writestr(s,'Coastline: ',coastline:0:3,
			' mas=',mas:0:1,
			' las=',las:0:1,
			' mad=',mad:0:1);
		gui_writeln(s);
	end;
{
	Calculate the asymmetry measure using the average and standard deviation
	of the signal.
}
	count:=0;
	upcount:=0;
	downcount:=0;
	for i:=0 to length(gp^)-1 do begin
		if (gp^[i]-ave >= asymmetry_extent*stdev) then inc(upcount);
		if (gp^[i]-ave <= -asymmetry_extent*stdev) then inc(downcount);
		if (abs(gp^[i]-ave) >= asymmetry_weight*stdev) then inc(count);
	end;
	if count>0 then asymmetry:=1.0+1.0*(upcount-downcount)/count
	else asymmetry:=1.0;
	if asymmetry<=0.0 then asymmetry:=small_value;
	if print_diagnostics then begin
		writestr(s,'Asymmetry: ',asymmetry:0:3,
			' count=',count:0,' upcount=',upcount:0,' downcount=',downcount:0);
		gui_writeln(s);
	end;
{
	We calculate coherence using a list of peaks and valleys. A peak is 
	a positive excursion of a height greater than a threshold, and a valley
	is the opposite. The coherence threshold is a multiple of the
	signal range, so we convert to signal units by multiplying by the range.
}
	pv_gp:=find_peaks_valleys(gp,true,coherence_threshold*range);
	num_pv_minor:=round(pv_gp^[0]);
{
	Diagnostic printing to aid debugging.
} 
	if print_diagnostics then begin
		writestr(s,'Coherence Peaks and Valleys: ');
		for i:=1 to num_pv_minor do writestr(s,s,pv_gp^[i]:0:0,' ');
		gui_writeln(s);
	end;
{
	We obtain the coherence measure by calculating the average separation of 
	the neighboring peaks and valleys.
}
	sum_separation:=0;
	for i:=1 to num_pv_minor-1 do begin
		sum_separation:=sum_separation
			+abs(gp^[round(pv_gp^[i+1])]-gp^[round(pv_gp^[i])])/range;
	end;
	if num_pv_minor>1 then coherence:=sum_separation/(num_pv_minor-1)
	else coherence:=0;
	if coherence<=0 then coherence:=small_value;
	if print_diagnostics then begin
		writestr(s,'Coherence: ',coherence:0:3,
			' threshold=',coherence_threshold*range:0:1,
			' num_pv_minor=',num_pv_minor:1,
			' sum_separation=',sum_separation:0:3);
		gui_writeln(s);
	end;
{
	We are done with the coherence peak and valley list.
}
	dispose_x_graph(pv_gp);
{
	We begin our calculation of rhythm by making a list of the major peaks and
	valleys.
}
	pv_gp:=find_peaks_valleys(gp,true,rhythm_threshold*range);
	num_pv_major:=round(pv_gp^[0]);
{
	Diagnostic printing to aid debugging.
} 
	if print_diagnostics then begin
		writestr(s,'Rhythm Peaks and Valleys: ');
		for i:=1 to num_pv_major do writestr(s,s,pv_gp^[i]:0:0,' ');
		gui_writeln(s);
	end;
{
	Go through the valleys and peaks and obtain a list of step sizes, then sort
	them in order of decreasing size.
}
	num_steps:=num_pv_major-1-1;
	for i:=1 to num_steps do list_gp^[i-1]:=abs(pv_gp^[i+2]-pv_gp^[i]);
	quick_sort(0,num_steps-1,x_graph_swap,x_graph_lt,list_gp);
	if print_diagnostics then begin
		writestr(s,'Sorted Step Sizes: ');
		for i:=0 to num_steps-1 do writestr(s,s,list_gp^[i]:0:0,' ');
		gui_writeln(s);
	end;
{
	For each step, count how many other steps are within the range defined by 
	our rhythm_fraction. The step size with the greatest number of other
	steps within this range of its value is our best guess at the period of the
	waveform, and the number of steps within range will be, as a fraction of 
	the total number of steps, the basis of our rhythm measurement.
}
	num_steps_accepted:=0;
	best_step:=0;
	hi_step:=0;
	for j:=0 to num_steps-1 do begin
		if best_step<>round(list_gp^[j]) then begin
			while (hi_step<num_steps) and
					(list_gp^[hi_step]>list_gp^[j]/rhythm_fraction) do
				inc(hi_step);
			i:=hi_step;
			while (i<num_steps) and
					(list_gp^[i]>=list_gp^[j]*rhythm_fraction) do
				inc(i);
			if i-hi_step>num_steps_accepted then begin
				num_steps_accepted:=i-hi_step;
				best_step:=round(list_gp^[j]);
			end;
		end;
	end;
{
	If we are printing diagnostic information, it's useful to know which steps we
	selected.
}
	if print_diagnostics then begin
		writestr(s,'Selected Step Sizes: ');
		for i:=0 to num_steps-1 do 
			if (list_gp^[i]<=best_step/rhythm_fraction) 
				and (list_gp^[i]>=best_step*rhythm_fraction) then
			writestr(s,s,list_gp^[i]:0:0,' ');
		gui_writeln(s);
	end;
{
	The rhythm is the ratio of the number of accepted steps to the total
	number of steps. But we reduce rhythm for special degenerate cases. One
	degenerate case is when the steps are very small. Another is when the number
	of minor peaks and valleys is much greater than the number of major peaks
	and valleys.
}
	if num_steps_accepted>0 then begin
		rhythm:=num_steps_accepted/num_steps;
		if num_steps_accepted<rhythm_few_steps then
			rhythm:=rhythm*sqr(num_steps_accepted/rhythm_few_steps);
		small_step:=1+trunc(length(gp^)/rhythm_many_steps);
		if best_step<small_step then
			rhythm:=rhythm*best_step/small_step;
		num_degenerate_pairs:=0;
		for i:=1 to num_steps-1 do 
			if abs(pv_gp^[i+1]-pv_gp^[i])
				<=rhythm_degenerate_step then begin
				inc(num_degenerate_pairs);
				rhythm:=rhythm*rhythm_degeneracy_shrink;
		end;
		if num_pv_minor>rhythm_instability_ratio*num_pv_major then begin
			stability:=sqr(
					num_pv_major /
					(num_pv_minor-num_pv_major*(rhythm_instability_ratio-1.0)));
			rhythm:=rhythm*stability;
		end else begin
			stability:=1.0;
		end;
	end else begin
		rhythm:=small_value;
		stability:=small_value;
	end;
{
	Now that we have a best value for the periodic step size, we can produce an
	estimate of frequency in units of cycles per interval.
}
	if best_step>0 then frequency:=length(gp^)/best_step
	else frequency:=length(gp^);
{
	We are done with the peak and valley list.
}
	dispose_x_graph(pv_gp);
{
	In diagnostic operation we print more information about the accepted steps.
}
	if print_diagnostics then begin
		writestr(s,'Rhythm: ',rhythm:0:3,
			' threshold=',rhythm_threshold*range:0:1,
			' num_steps=',num_steps:1,
			' num_steps_accepted=',num_steps_accepted:1,
			' num_degenerate_pairs=',num_degenerate_pairs:1);
		gui_writeln(s);		
		writestr(s,'Frequency: ',frequency:0:1,
			' best_step=',best_step:1,
			' num_pv_major=',num_pv_major:1,
			' num_pv_minor=',num_pv_minor:1,
			' stability=',stability:0:3);
		gui_writeln(s);
	end;
{
	Offset the rhythm measure so that zero values don't occur.
}
	rhythm:=rhythm+rhythm_offset;
{
	Dispose of our list graph.
}
	dispose_x_graph(list_gp);
	if error_string<>'' then exit;
{
	Create the return string.
}
	writestr(s,
		amplitude:fsr:fsd,' ',
		coastline:fsr:fsd,' ',
		intermittency:fsr:fsd,' ',
		coherence:fsr:fsd,' ',
		asymmetry:fsr:fsd,' ',
		rhythm:fsr:fsd,' ',
		frequency:fsr:fsd,' ',
		num_glitches:0);
	metric_calculation_C:=s;
end;

{
	metric_calculation_D calculates the following measures of a signal and
	returns them in a string. The routine assumes that the signal has already
	been glitch-filtered. The routine returns eight real numbers in a string:
	amplitude, coastline, intermittency, coherence, asymmetry, rhythm,
	frequency, and spikiness.

	Amplitude: The standard deviation of the signal.

	Coastline: The ratio of the mean absolute step size to the signal range.

	Intermittency: The fraction of the coastline generated by the 10% largest
	coastline steps.

	Coherence: The ratio of the combined area of the biggest ten peaks and
	valleys to the total area of the signal.

	Asymmetry: The third moment of the signal.

	Rhythm: The ratio of the number of accepted steps to the total number of
	steps, where a step is the separation of two major peaks or two valleys, as
	obtained from a list of peaks and valleys with depth greater than the rhythm
	threshold multiplied by signal range. We accept all steps within a range
	defined by rhythm_fraction. The best step size is the one for which we have
	the largest number of accepted steps. We reduce the rhythm according to
	certain rules so as to make its calculation less vulnerable to random
	baseline intervals. If the number of minor peaks and valleys we obtain with
	a lower threshold is significantly greater than the number of major peaks
	and valleys, we reduce the rhythm in proportion to the excess. If there are
	too few steps or if some steps are too small, we reduce rhythm. Note that
	rhythm is a measure of how certain we are that there is a periodic waveform
	in the signal, not a measure of the frequency of the waveform. We have a
	separate frequency measure for that.

	Frequency: Greater than or equal to zero, the number of best_step periods
	that fit in the interval width. If the interval is one second long, the
	value is a multiple of 1 Hz. If two seconds long, the value is a multiple of
	0.5 Hz.
	
	Spikiness: We divide the interval into sections, as determined by the
	spikiness_extent parameter. In each section we measure the range. We make a
	list of the ranges and sort it in decreasing order. The spikiness is the
	ratio of the maximum section range to the median section range. The width of
	a section is, for sections in the center, equal to twice the extent. At the
	start and end of the interval, however, the sections are thinner.
}
function metric_calculation_D(gp:x_graph_ptr;command:string):string;

const
	intermittency_fraction=0.1;
	asymmetry_extent=2.0;
	asymmetry_weight=1.5;
	coherence_regions=10;
	rhythm_fraction=0.8;
	rhythm_few_steps=10;
	rhythm_many_steps=40;
	rhythm_degenerate_step=2;
	rhythm_degeneracy_shrink=0.8;
	rhythm_instability_ratio=1.5;
	rhythm_offset=0.1;
	rhythm_minor_factor=2.0;
	small_value=0.0001;
	
var 
	print_diagnostics:boolean=false;
	amplitude:real=0;
	coastline_normalized:real=0;
	intermittency:real=0;
	coherence:real=0.0;
	asymmetry:real=0;
	rhythm:real=0;
	frequency:real=0;
	stability:real=0;
	spikiness:real=0.0;
	spikiness_extent:integer;
	rhythm_threshold:real=0;
	coherence_threshold:real=0.0;
	top:real=0;
	bottom:real=0;
	med_range:real=0;
	coastline:real=0.0;
	i,j,limit,num_sections,num_pv_coherence,num_pv_minor,num_pv_major:integer;
	sum_x,sum_x2,high_coastline:longreal;
	score,coherence_score,asymmetry_score:longreal;
	ave, {average value}
	stdev, {standard deviation}
	mad, {mean absolute deviation}
	min, {minimum}
	max, {maximum}
	range, {maximum-minimum}
	mas {mean absolute step size, coastline divided by number of points}
	:real;
	list_gp,pv_gp:x_graph_ptr;
	hi_step,best_step,small_step,num_steps:integer;
	num_steps_accepted:integer;
	num_degenerate_pairs:integer=0;
	s:string;
	
begin
{
	We assign default values to the measures and check the incoming graph pointer.
}
	metric_calculation_D:='0 0 0 0 0 0 0 0';
	if gp=nil then exit;
	if length(gp^)<=1 then begin
		report_error('length(gp^)<=1 in metric_calculation_D');
		exit;
	end;
{
	Allocate space for four graphs the same length as the input graph.
}
	list_gp:=new_x_graph(length(gp^));
	if (list_gp=nil) then begin
		report_error('failed to allocate an x_graph_type in metric_calculation_D');
		exit;
	end;
{
	Read parameters from the command string.
}
	coherence_threshold:=read_real(command);
	rhythm_threshold:=read_real(command);
	spikiness_extent:=read_integer(command);
	print_diagnostics:=read_boolean(command);
	if error_string<>'' then exit;
{
	In one pass, calculate the average, standard deviation, and coastline of the
	signal. We store the absolute difference between consecutive samples in the
	list graph. This graph will have one fewer valid entries than the original
	graph, so we set its first value to zero to make up the number of samples.
	The mas variable gets the mean absolute step size for the interval.
}
	sum_x:=0;
	sum_x2:=0;
	coastline:=0;
	min:=gp^[0];
	max:=gp^[0];
	list_gp^[0]:=0;
	for i:=0 to length(gp^)-1 do begin
		sum_x:=sum_x+gp^[i];
		sum_x2:=sum_x2+gp^[i]*gp^[i];
		if gp^[i]>max then max:=gp^[i];
		if gp^[i]<min then min:=gp^[i];
		if (i>0) then begin
			list_gp^[i]:=abs(gp^[i]-gp^[i-1]);
			coastline:=coastline+list_gp^[i];
		end;
	end;
	check_for_math_error(sum_x);
	check_for_math_error(sum_x2);
	if error_string<>'' then exit;
	range:=max-min;
	if range<=0 then exit;
	ave:=sum_x/length(gp^);
	stdev:=sqrt(sum_x2/length(gp^)-ave*ave);
	mas:=coastline/length(gp^);
{
	Calculate the mean absolute deviation of the signal.
}
	mad:=0;
	for i:=0 to length(gp^)-1 do
		mad:=mad+abs(gp^[i]-ave);
	mad:=mad/length(gp^);
{
	Calculate the amplitude measure, which lies between zero and one.
}
	if print_diagnostics then begin
		writestr(s,'Amplitude: ',
			' stdev=',stdev:0:1,
			' ave=',ave:0:1,
			' mad=',mad:0:1,
			' range=',range:0:1);
		gui_writeln(s);
	end;
	amplitude:=stdev;
{
	Calculate intermittency. Sort the coastline derivative, which is now
	in the list graph, in descending order. Sum the first N entries, where
	N we obtain by multiplying the number of entries by the intermittency
	fraction. We divide this sum by the coastline to get a measure of how
	concentrated the coastline is in features of the signal. We apply a
	sigmoidal function to get the intermittency measure.
}
	x_graph_descending(list_gp);
	limit:=round(intermittency_fraction*length(list_gp^));
	high_coastline:=0;
	for i:=0 to limit-1 do high_coastline:=high_coastline+list_gp^[i];
	if high_coastline>0 then intermittency:=high_coastline/coastline
	else intermittency:=small_value;
	if print_diagnostics then begin
		writestr(s,'Intermittency: ',intermittency:0:3,
			' limit=',limit:0,
			' high_coastline=',high_coastline:0:1,
			' coastline=',coastline:0:1);
		gui_writeln(s);
	end;
{
	Divide the mean average step by least absolute step size to get the normalized
	coastline, which is our coastline measure.
}
	coastline_normalized:=mas/range;
	if print_diagnostics then begin
		writestr(s,'Coastline: ',coastline_normalized:0:4,
			' mas=',mas:0:1,
			' range=',range:0:1);
		gui_writeln(s);
	end;
{
	We calculate coherence using a list of peaks and valleys. A peak is 
	a positive excursion of a height greater than a threshold, and a valley
	is the opposite. The coherence threshold is a multiple of the
	signal range, so we convert it to counts by multiplying by the range.
}
	pv_gp:=find_peaks_valleys(gp,true,coherence_threshold*range);
	num_pv_coherence:=round(pv_gp^[0]);
{
	Each entry in the peak and valley list is an index into the original signal.
	We score each peak and valley by looking at the height and breadth of the
	approach to the peak or valley from the previous valley or peak
	respectively. We include a sign on the score to indicate a peak or a
	valley.
}
	for i:=2 to num_pv_coherence do begin
		score:=(gp^[round(pv_gp^[i])]-gp^[round(pv_gp^[i-1])])
			* (pv_gp^[i]-pv_gp^[i-1]);
		list_gp^[i-2]:=score;
	end;
{
	We are done with the coherence peak and valley list.
}
	dispose_x_graph(pv_gp);
{
	We go through the list of areas and sort by decreasing absolute area.
}
	quick_sort(0,num_pv_coherence-3,x_graph_swap,x_graph_lt_abs,list_gp);
{
	Diagnostic printing to aid debugging.
} 
	if print_diagnostics then begin
		writestr(s,'Coherence Scores Sorted: ');
		for i:=0 to num_pv_coherence-3 do 
			if i<coherence_regions then 
				writestr(s,s,list_gp^[i]:0:0,' ');
		gui_writeln(s);
	end;
{
	We assume that the coherence threshold is small, so there are many peaks and
	valleys. 
}
	coherence_score:=0;
	asymmetry_score:=0;
	for i:=0 to num_pv_coherence-3 do begin
		if i<coherence_regions then begin
			coherence_score:=coherence_score+abs(list_gp^[i]);
		end;
	end;
{
	Coherence is a measure of how much of the mean absolute deviation area of
	the signal is accounted for by the first ten discrete peaks and valleys.
}
	coherence:=coherence_score/mad/length(gp^);
	if print_diagnostics then begin
		writestr(s,'Coherence: ',coherence:0:3,
			' threshold=',coherence_threshold*range:0:1,
			' num_pv_coherence=',num_pv_coherence:1,
			' coherence_score=',coherence_score:0:0);
		gui_writeln(s);
	end;
{
	Calculate the asymmetry measure using the third moment of the signal.
}
	asymmetry_score:=0;
	for i:=0 to length(gp^)-1 do begin
		asymmetry_score:=asymmetry_score+xpyi((gp^[i]-ave)/stdev,3);
	end;
	asymmetry_score:=asymmetry_score/length(gp^);
	asymmetry:=exp(asymmetry_score);
	if print_diagnostics then begin
		writestr(s,'Asymmetry: ',asymmetry:0:3,' ',
			'score=',asymmetry_score:0:3);
		gui_writeln(s);
	end;
{
	We begin our calculation of rhythm by making a list of the minor peaks and
	valleys.
}
	pv_gp:=find_peaks_valleys(gp,true,rhythm_threshold*range/rhythm_minor_factor);
	num_pv_minor:=round(pv_gp^[0]);
	dispose_x_graph(pv_gp);
{
	And now a list of major peaks and valleys.
}
	pv_gp:=find_peaks_valleys(gp,true,rhythm_threshold*range);
	num_pv_major:=round(pv_gp^[0]);
{
	Diagnostic printing to aid debugging.
} 
	if print_diagnostics then begin
		writestr(s,'Rhythm Peaks and Valleys: ');
		for i:=1 to num_pv_major do writestr(s,s,pv_gp^[i]:0:0,' ');
		gui_writeln(s);
	end;
{
	Go through the valleys and peaks and obtain a list of step sizes, then sort
	them in order of decreasing size.
}
	num_steps:=num_pv_major-1-1;
	for i:=1 to num_steps do list_gp^[i-1]:=abs(pv_gp^[i+2]-pv_gp^[i]);
	quick_sort(0,num_steps-1,x_graph_swap,x_graph_lt,list_gp);
	if print_diagnostics then begin
		writestr(s,'Sorted Step Sizes: ');
		for i:=0 to num_steps-1 do writestr(s,s,list_gp^[i]:0:0,' ');
		gui_writeln(s);
	end;
{
	For each step, count how many other steps are within the range defined by 
	our rhythm_fraction. The step size with the greatest number of other
	steps within this range of its value is our best guess at the period of the
	waveform, and the number of steps within range will be, as a fraction of 
	the total number of steps, the basis of our rhythm measurement.
}
	num_steps_accepted:=0;
	best_step:=0;
	hi_step:=0;
	for j:=0 to num_steps-1 do begin
		if best_step<>round(list_gp^[j]) then begin
			while (hi_step<num_steps) and
					(list_gp^[hi_step]>list_gp^[j]/rhythm_fraction) do
				inc(hi_step);
			i:=hi_step;
			while (i<num_steps) and
					(list_gp^[i]>=list_gp^[j]*rhythm_fraction) do
				inc(i);
			if i-hi_step>num_steps_accepted then begin
				num_steps_accepted:=i-hi_step;
				best_step:=round(list_gp^[j]);
			end;
		end;
	end;
{
	If we are printing diagnostic information, it's useful to know which steps we
	selected.
}
	if print_diagnostics then begin
		writestr(s,'Selected Step Sizes: ');
		for i:=0 to num_steps-1 do 
			if (list_gp^[i]<=best_step/rhythm_fraction) 
				and (list_gp^[i]>=best_step*rhythm_fraction) then
			writestr(s,s,list_gp^[i]:0:0,' ');
		gui_writeln(s);
	end;
{
	The rhythm is the ratio of the number of accepted steps to the total
	number of steps. But we reduce rhythm for special degenerate cases. One
	degenerate case is when the steps are very small. Another is when the number
	of minor peaks and valleys is much greater than the number of major peaks
	and valleys.
}
	if num_steps_accepted>0 then begin
		rhythm:=num_steps_accepted/num_steps;
		if num_steps_accepted<rhythm_few_steps then
			rhythm:=rhythm*sqr(num_steps_accepted/rhythm_few_steps);
		small_step:=1+trunc(length(gp^)/rhythm_many_steps);
		if best_step<small_step then
			rhythm:=rhythm*best_step/small_step;
		num_degenerate_pairs:=0;
		for i:=1 to num_steps-1 do 
			if abs(pv_gp^[i+1]-pv_gp^[i])
				<=rhythm_degenerate_step then begin
				inc(num_degenerate_pairs);
				rhythm:=rhythm*rhythm_degeneracy_shrink;
		end;
		if num_pv_minor>rhythm_instability_ratio*num_pv_major then begin
			stability:=sqr(
					num_pv_major /
					(num_pv_minor-num_pv_major*(rhythm_instability_ratio-1.0)));
			rhythm:=rhythm*stability;
		end else begin
			stability:=1.0;
		end;
	end else begin
		rhythm:=small_value;
		stability:=small_value;
	end;
{
	Now that we have a best value for the periodic step size, we can produce an
	estimate of frequency in units of cycles per interval.
}
	if best_step>0 then frequency:=length(gp^)/best_step
	else frequency:=length(gp^);
{
	We are done with the peak and valley list.
}
	dispose_x_graph(pv_gp);
{
	In diagnostic operation we print more information about the accepted steps.
}
	if print_diagnostics then begin
		writestr(s,'Rhythm: ',rhythm:0:3,
			' threshold=',rhythm_threshold*range:0:1,
			' num_steps=',num_steps:1,
			' num_steps_accepted=',num_steps_accepted:1,
			' num_degenerate_pairs=',num_degenerate_pairs:1);
		gui_writeln(s);		
		writestr(s,'Frequency: ',frequency:0:1,
			' best_step=',best_step:1,
			' num_pv_major=',num_pv_major:1,
			' num_pv_minor=',num_pv_minor:1,
			' stability=',stability:0:3);
		gui_writeln(s);
	end;
{
	Offset the rhythm measure so that zero values don't occur.
}
	rhythm:=rhythm+rhythm_offset;
{
	Calculate spikiness measure.
}
	i:=0;
	num_sections:=0;
	while i<length(gp^) do begin
		top:=gp^[i];
		bottom:=gp^[i];
		for j:=i-spikiness_extent to i+spikiness_extent do begin
			if (j>=0) and (j<length(gp^)) then begin
				if gp^[j]>top then top:=gp^[j];
				if gp^[j]<bottom then bottom:=gp^[j];
			end;
		end;
		list_gp^[num_sections]:=top-bottom;
		inc(num_sections);
		i:=i+spikiness_extent;
	end;
	quick_sort(0,num_sections-1,x_graph_swap,x_graph_lt,list_gp);
	med_range:=list_gp^[round(num_sections/2.0)];
	spikiness:=list_gp^[0]/med_range;
	if print_diagnostics then begin
		writestr(s,'Spikiness: ',spikiness:0:2,
		' extent=',spikiness_extent:1,
		' median=',med_range:1:0,
		' max=',list_gp^[0]:1:0,
		' min=',list_gp^[num_sections-1]:1:0,
		' num_sections=',num_sections:1);
		gui_writeln(s);
	end;
{
	Dispose of our list graph.
}
	dispose_x_graph(list_gp);
	if error_string<>'' then exit;
{
	Create the return string.
}
	writestr(s,
		amplitude:fsr:fsd,' ',
		coastline_normalized:fsr:fsd,' ',
		intermittency:fsr:fsd,' ',
		coherence:fsr:fsd,' ',
		asymmetry:fsr:fsd,' ',
		rhythm:fsr:fsd,' ',
		frequency:fsr:fsd,' ',
		spikiness:fsr:fsd);
	metric_calculation_D:=s;
end;

{
	metric_calculation_E calculates the following measures of a signal and
	returns them in a string. The routine assumes that the signal has already
	been glitch-filtered. The routine returns eight real numbers in a string:
	amplitude, coastline, intermittency, coherence, asymmetry, rhythm,
	frequency, and spikiness.

	Amplitude: The standard deviation of the signal.

	Coastline: The ratio of the mean absolute step size to the signal range.

	Intermittency: The fraction of the coastline generated by the
	intermittency_fraction largest coastline steps.

	Coherence: The ratio of the combined area of the biggest coherence_regions
	peaks and valleys to the total area of the signal.

	Asymmetry: Absolute value of the third moment of the signal.

	Spikiness: We divide the interval into sections. Each section has width
	2*spikiness_extent+1. The sections are evenly spaced and overlapping. There
	are num_points/spikiness_extent sections. In each section we measure the
	range of the signal. We make a list of section ranges and sort it in
	decreasing order of range. The spikiness is the ratio of the maximum range
	to the median range.
}
function metric_calculation_E(gp:x_graph_ptr;command:string):string;

const
	intermittency_fraction=0.1;
	coherence_regions=10;
	small_value=0.0001;
	
var 
	print_diagnostics:boolean=false;
	amplitude:real=0;
	coastline_normalized:real=0;
	intermittency:real=0;
	coherence:real=0.0;
	asymmetry:real=0;
	spikiness:real=0.0;
	spikiness_extent:integer;
	coherence_threshold:real=0.0;
	top:real=0;
	bottom:real=0;
	med_range:real=0;
	coastline:real=0.0;
	i,j,limit,num_sections,num_pv_coherence:integer;
	sum_x,sum_x2,high_coastline:longreal;
	score,coherence_score,asymmetry_score:longreal;
	ave, {average value}
	stdev, {standard deviation}
	mad, {mean absolute deviation}
	min, {minimum}
	max, {maximum}
	range, {maximum-minimum}
	mas {mean absolute step size, coastline divided by number of points}
	:real;
	list_gp,pv_gp:x_graph_ptr;
	s:string='';
	
begin
{
	We assign default values to the measures and check the incoming graph pointer.
}
	metric_calculation_E:='0 0 0 0 0 0 0 0';
	if gp=nil then exit;
	if length(gp^)<=1 then begin
		report_error('length(gp^)<=1 in metric_calculation_E');
		exit;
	end;
{
	Allocate space for four graphs the same length as the input graph.
}
	list_gp:=new_x_graph(length(gp^));
	if (list_gp=nil) then begin
		report_error('failed to allocate an x_graph_type in metric_calculation_E');
		exit;
	end;
{
	Read parameters from the command string.
}
	coherence_threshold:=read_real(command);
	spikiness_extent:=read_integer(command);
	print_diagnostics:=read_boolean(command);
	if error_string<>'' then exit;
{
	In one pass, calculate the average, standard deviation, and coastline of the
	signal. We store the absolute difference between consecutive samples in the
	list graph. This graph will have one fewer valid entries than the original
	graph, so we set its first value to zero to make up the number of samples.
	The mas variable gets the mean absolute step size for the interval.
}
	sum_x:=0;
	sum_x2:=0;
	coastline:=0;
	min:=gp^[0];
	max:=gp^[0];
	list_gp^[0]:=0;
	for i:=0 to length(gp^)-1 do begin
		sum_x:=sum_x+gp^[i];
		sum_x2:=sum_x2+gp^[i]*gp^[i];
		if gp^[i]>max then max:=gp^[i];
		if gp^[i]<min then min:=gp^[i];
		if (i>0) then begin
			list_gp^[i]:=abs(gp^[i]-gp^[i-1]);
			coastline:=coastline+list_gp^[i];
		end;
	end;
	check_for_math_error(sum_x);
	check_for_math_error(sum_x2);
	if error_string<>'' then exit;
	range:=max-min;
	if range<=0 then exit;
	ave:=sum_x/length(gp^);
	stdev:=sqrt(sum_x2/length(gp^)-ave*ave);
	mas:=coastline/length(gp^);
{
	Calculate the mean absolute deviation of the signal.
}
	mad:=0;
	for i:=0 to length(gp^)-1 do
		mad:=mad+abs(gp^[i]-ave);
	mad:=mad/length(gp^);
{
	Calculate the amplitude measure, which lies between zero and one.
}
	if print_diagnostics then begin
		writestr(s,'Amplitude: ',
			' stdev=',stdev:0:1,
			' ave=',ave:0:1,
			' mad=',mad:0:1,
			' range=',range:0:1);
		gui_writeln(s);
	end;
	amplitude:=stdev;
{
	Calculate intermittency. Sort the coastline derivative, which is now
	in the list graph, in descending order. Sum the first N entries, where
	N we obtain by multiplying the number of entries by the intermittency
	fraction. We divide this sum by the coastline to get a measure of how
	concentrated the coastline is in features of the signal. We apply a
	sigmoidal function to get the intermittency measure.
}
	x_graph_descending(list_gp);
	limit:=round(intermittency_fraction*length(list_gp^));
	high_coastline:=0;
	for i:=0 to limit-1 do high_coastline:=high_coastline+list_gp^[i];
	if high_coastline>0 then intermittency:=high_coastline/coastline
	else intermittency:=small_value;
	if print_diagnostics then begin
		writestr(s,'Intermittency: ',intermittency:0:3,
			' limit=',limit:0,
			' high_coastline=',high_coastline:0:1,
			' coastline=',coastline:0:1);
		gui_writeln(s);
	end;
{
	Divide the mean average step by least absolute step size to get the normalized
	coastline, which is our coastline measure.
}
	coastline_normalized:=mas/range;
	if print_diagnostics then begin
		writestr(s,'Coastline: ',coastline_normalized:0:4,
			' mas=',mas:0:1,' range=',range:0:1,' num_points=',length(gp^):0);
		gui_writeln(s);
	end;
{
	We calculate coherence using a list of peaks and valleys. A peak is a
	positive excursion of a height greater than a threshold, and a valley is the
	opposite. Local peaks and valleys of height or depth less than the threshold
	we ignore. The threshold is a fraction of the signal range, given by
	coherence_threshold. The threshold is often zero, which means our peak and
	valley list will include every local maximum and minimum in the signal. The
	number of peaks and valleys found is recorded in the zero element of the
	peak-valley list. Subsequent elements are the indices of the peaks and
	valleys in the original signal.
}
	pv_gp:=find_peaks_valleys(gp,true,coherence_threshold*range);
	num_pv_coherence:=round(pv_gp^[0]);
{
	We score each peak-valley and valley-peak transition by multiplying its
	height by its breadth to obtain its area. The height is the change in signal
	from one to the other. Its breadth is the change in index from one to
	the other. We take the absolute value to obtain a positive area for every
	peak-valley transition.
}
	for i:=2 to num_pv_coherence do begin
		score:=(gp^[round(pv_gp^[i])]-gp^[round(pv_gp^[i-1])])
			* (pv_gp^[i]-pv_gp^[i-1]);
		list_gp^[i-2]:=abs(score);
	end;
{
	We are done with the coherence peak and valley list, so dispose of it.
}
	dispose_x_graph(pv_gp);
{
	We go through the list of scores and sort by decreasing absolute area. We
	have num_pv_coherence-1 scores, so we sort the list from index 0 to
	num_pv_coherence-2.
}
	quick_sort(0,num_pv_coherence-2,x_graph_swap,x_graph_lt,list_gp);
{
	Diagnostic printing to aid debugging.
} 
	if print_diagnostics then begin
		writestr(s,'Coherence Scores Sorted: ');
		for i:=0 to num_pv_coherence-3 do 
			if i<coherence_regions then 
				writestr(s,s,list_gp^[i]:0:0,' ');
		gui_writeln(s);
	end;
{
	We assume that the coherence threshold is small, so that there are dozens of
	peaks and valleys, and certainly more than the coherence_regions value. We
	add the areas of the largest peaks and valleys. We obtain the area from the
	score by taking the score's absolute value.
}
	coherence_score:=0;
	for i:=0 to num_pv_coherence-3 do begin
		if i<coherence_regions then begin
			coherence_score:=coherence_score+list_gp^[i];
		end;
	end;
{
	Coherence is a measure of how much of thearea of the signal is occupied by
	the largest peak-valley transitions. The area of the signal is the
	rectangular area we need for normalized display: the range multiplied by the
	number of samples.
}
	coherence:=coherence_score/range/length(gp^);
	if print_diagnostics then begin
		writestr(s,'Coherence: ',coherence:0:3,
			' threshold=',coherence_threshold*range:0:1,
			' num_pv_coherence=',num_pv_coherence:1,
			' coherence_score=',coherence_score:0:0);
		gui_writeln(s);
	end;
{
	Calculate the asymmetry measure using the third moment of the signal.
}
	asymmetry_score:=0;
	for i:=0 to length(gp^)-1 do begin
		asymmetry_score:=asymmetry_score+xpyi((gp^[i]-ave)/stdev,3);
	end;
	asymmetry:=abs(asymmetry_score/length(gp^));
	if print_diagnostics then begin
		writestr(s,'Asymmetry: ',asymmetry:0:3,' ',
			'score=',asymmetry_score:0:3,' num_points=',length(gp^):0,
				' ave=',ave:0:3,' stdev=',stdev:0:3);
		gui_writeln(s);
	end;
{
	Calculate spikiness measure.
}
	i:=0;
	num_sections:=0;
	while i<length(gp^) do begin
		top:=gp^[i];
		bottom:=gp^[i];
		for j:=i-spikiness_extent to i+spikiness_extent do begin
			if (j>=0) and (j<length(gp^)) then begin
				if gp^[j]>top then top:=gp^[j];
				if gp^[j]<bottom then bottom:=gp^[j];
			end;
		end;
		list_gp^[num_sections]:=top-bottom;
		inc(num_sections);
		i:=i+spikiness_extent;
	end;
	quick_sort(0,num_sections-1,x_graph_swap,x_graph_lt,list_gp);
	med_range:=list_gp^[round(num_sections/2.0)];
	spikiness:=list_gp^[0]/med_range;
	if print_diagnostics then begin
		writestr(s,'Spikiness: ',spikiness:0:2,
		' extent=',spikiness_extent:1,
		' median=',med_range:1:0,
		' max=',list_gp^[0]:1:0,
		' min=',list_gp^[num_sections-1]:1:0,
		' num_sections=',num_sections:1);
		gui_writeln(s);
	end;
{
	Dispose of our list graph.
}
	dispose_x_graph(list_gp);
	if error_string<>'' then exit;
{
	Create the return string.
}
	writestr(s,
		amplitude:fsr:fsd,' ',
		coastline_normalized:fsr:fsd,' ',
		intermittency:fsr:fsd,' ',
		coherence:fsr:fsd,' ',
		asymmetry:fsr:fsd,' ',
		spikiness:fsr:fsd);
	metric_calculation_E:=s;
end;

{
	initialization does nothing.
}
initialization 

{
	finalization does nothing.
}
finalization 


end.
