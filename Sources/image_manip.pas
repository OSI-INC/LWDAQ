{
Routines for Image Manipulation
Copyright (C) 2004-2021 Kevan Hashemi, Brandeis University
Copyright (C) 2022-2023 Kevan Hashemi, Open Source Instruments Inc.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place - Suite 330, Boston, MA  02111-1307, USA.
}

unit image_manip;

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}

interface

uses
	utils,images,transforms;

function image_copy(oip:image_ptr_type):image_ptr_type;
function image_filter(oip:image_ptr_type;a,b,c,d,e,f,divisor:real):image_ptr_type;
function image_grad_i(oip:image_ptr_type):image_ptr_type;
function image_grad_j(oip:image_ptr_type):image_ptr_type;
function image_grad(ip:image_ptr_type):image_ptr_type;
function image_shrink(ip:image_ptr_type;factor:integer):image_ptr_type;
function image_enlarge(ip:image_ptr_type;factor:integer):image_ptr_type;
function image_rotate(ip:image_ptr_type;rotation:real;center:xy_point_type):image_ptr_type;
function image_profile_column(ip:image_ptr_type):x_graph_type;
function image_profile_row(ip:image_ptr_type):x_graph_type;
function image_quadratic_sum(oip_1,oip_2:image_ptr_type):image_ptr_type;
function image_accumulate(oip_1,oip_2:image_ptr_type):image_ptr_type;
function image_subtract(oip_1,oip_2:image_ptr_type):image_ptr_type;
function image_subtract_row_average(oip:image_ptr_type):image_ptr_type;
function image_subtract_gradient(oip:image_ptr_type):image_ptr_type;
procedure image_transfer_overlay(dip,sip:image_ptr_type);
function image_bounds_subtract(oip_1,oip_2:image_ptr_type):image_ptr_type;
function image_negate(ip:image_ptr_type):image_ptr_type;
function image_histogram(ip:image_ptr_type):xy_graph_type;
function image_invert(ip:image_ptr_type):image_ptr_type;
function image_reverse_rows(ip:image_ptr_type):image_ptr_type;
function image_rows_to_columns(ip:image_ptr_type):image_ptr_type;
function image_soec(ip:image_ptr_type):image_ptr_type;
function image_soer(ip:image_ptr_type):image_ptr_type;
function image_crop(oip:image_ptr_type):image_ptr_type;

implementation

{
	image_transfer_overlay takes the overlay of a source image and copies it
	into the overlay of a destination image. It scales the height and width
	of the overlay to match the new image dimensions, regardless of any difference
	in their shapes. When there are several pixels in the source image overlay
	that might be used for a single pixel in the destination image, a colored
	pixel takes precedence over a clear pixel, and the lowest-value color takes
	precedence over all others.
}
procedure image_transfer_overlay(dip,sip:image_ptr_type);
var
	i,j,ii,jj,min:integer;
	j_scale,i_scale:real;
	j_extent,i_extent:integer;
	
begin
	if sip=nil then exit;
	if dip=nil then exit;

	j_scale:=dip^.j_size/sip^.j_size;
	i_scale:=dip^.i_size/sip^.i_size;
	
	if j_scale>=1 then j_extent:=0
	else j_extent:=round(1/j_scale-1);
	if i_scale>=1 then i_extent:=0
	else i_extent:=round(1/i_scale-1);

	clear_overlay(dip);
	for j:=0 to dip^.j_size-1 do begin
		for i:=0 to dip^.i_size-1 do begin
			min:=clear_color;
			for jj:=trunc(j/j_scale) to trunc(j/j_scale)+j_extent do
				for ii:=trunc(i/i_scale) to trunc(i/i_scale)+i_extent do 
					if get_ov(sip,jj,ii)<>clear_color then
						if (get_ov(sip,jj,ii)<min) or (min=clear_color) then
							min:=get_ov(sip,jj,ii);
			set_ov(dip,j,i,min);
		end;
	end;
end;

{
	image_shrink creates a new image that is an integer factor smaller in the
	horizontal and vertical dimensions. The routine sets pixel (i,j) of the 
	new image to the average of pixels (n*i..n*i+n-1,n*j..n*j+n-1), where n is
	the shrink factor. Thus when n=2 each pixel in the new image is the average
	of a block of four pixels in the old image. The overlay of the new image is
	clear and the result string is empty.
}
function image_shrink(ip:image_ptr_type;factor:integer):image_ptr_type;
var
	i,j,ii,jj,sum:integer;
	nip:image_ptr_type;
	
begin
	image_shrink:=nil;
	if ip=nil then exit;
	
	nip:=new_image(trunc(ip^.j_size/factor),trunc(ip^.i_size/factor));
	
	with nip^.analysis_bounds do begin
		left:=trunc(ip^.analysis_bounds.left/factor)+1;
		top:=trunc(ip^.analysis_bounds.top/factor)+1;
		right:=trunc(ip^.analysis_bounds.right/factor)-1;
		bottom:=trunc(ip^.analysis_bounds.bottom/factor)-1;
	end;
	
	for j:=0 to nip^.j_size-1 do begin
		for i:=0 to nip^.i_size-1 do begin
			sum:=0;
			for jj:=j*factor to j*factor+factor-1 do
				for ii:=i*factor to i*factor+factor-1 do 
					sum:=sum+get_px(ip,jj,ii);
			set_px(nip,j,i,round(sum/factor/factor));
		end;
	end;

	image_shrink:=nip;
end;

{
	image_enlarge does the opposite of image shrink. Pixel (i,j) in the original
	image provides the value for pixels (i*n..i*n+n-1,j*n..j*n+n-1) in the
	enlarged image. The overlay of the new image is clear and the result string
	is empty.
}
function image_enlarge(ip:image_ptr_type;factor:integer):image_ptr_type;

var
	i,j,ii,jj:integer;
	nip:image_ptr_type;
	
begin
	image_enlarge:=nil;
	if ip=nil then exit;
	
	nip:=new_image(ip^.j_size*factor,ip^.i_size*factor);
	
	with nip^.analysis_bounds do begin
		left:=ip^.analysis_bounds.left*factor;
		top:=ip^.analysis_bounds.top*factor;
		right:=ip^.analysis_bounds.right*factor;
		bottom:=ip^.analysis_bounds.bottom*factor;
	end;
	
	for j:=0 to nip^.j_size-1 do begin
		for i:=0 to nip^.i_size-1 do begin
			ii:=trunc(i/factor);
			jj:=trunc(j/factor);
			set_px(nip,j,i,get_px(ip,jj,ii));
		end;
	end;

	image_enlarge:=nip;
end;

{
	image_rotate takes an image and rotates it counterclockwise about a point that
	may or may not be contained within the image. The rotation we specify in radians. The 
	point we specify in image coordinates, so that it can be anywhere, rather than on the 
	boundary of a pixel. Image coordinates have units of pixels, with the top-left corner
	of the top-left pixel being point (0,0). The routine also rotates the overlay image. 
}
function image_rotate(ip:image_ptr_type;rotation:real;center:xy_point_type):image_ptr_type;
var
	i,j:integer;
	nip:image_ptr_type;
	point,new_point,radius,new_radius:xy_point_type;
	pixel,new_pixel:ij_point_type;
	ave:real;
	
begin
	image_rotate:=nil;
	if ip=nil then exit;
	
	nip:=new_image(ip^.j_size,ip^.i_size);
	nip^.analysis_bounds:=ip^.analysis_bounds;
	ave:=image_average(ip);
	
	for j:=0 to nip^.j_size-1 do begin
		for i:=0 to nip^.i_size-1 do begin
			pixel.j:=j;
			pixel.i:=i;
			point:=i_from_c(pixel);
			radius:=xy_difference(point,center);
			new_radius:=xy_rotate(radius,rotation);
			new_point:=xy_sum(center,new_radius);
			new_pixel:=c_from_i(new_point);
			if (new_pixel.i>=0) and (new_pixel.i<ip^.i_size)
				and (new_pixel.j>=0) and (new_pixel.j<ip^.j_size) then begin
				set_px(nip,pixel.j,pixel.i,get_px(ip,new_pixel.j,new_pixel.i));
				set_ov(nip,pixel.j,pixel.i,get_ov(ip,new_pixel.j,new_pixel.i));
			end else begin 
				set_px(nip,pixel.j,pixel.i,round(ave));
				set_ov(nip,pixel.j,pixel.i,clear_color);
			end;
		end;
	end;

	image_rotate:=nip;
end;

{
	image_copy returns a pointer to a copy of the original image. The
	copy contains the same intensity array, and the same analysis
	boundaries. The overlay is clear and the results string is empty.
}
function image_copy(oip:image_ptr_type):image_ptr_type;

var
	nip:image_ptr_type;
	copy_size:cardinal;
	
begin
	image_copy:=nil;
	if not valid_image_ptr(oip) then exit;
	if not valid_analysis_bounds(oip) then begin
		report_error('Invalid analysis bounds in image_copy.');
		exit;
	end;
	
	nip:=new_image(oip^.j_size,oip^.i_size);
	if nip=nil then exit;
	nip^.analysis_bounds:=oip^.analysis_bounds;
	copy_size:=sizeof(intensity_pixel_type)*oip^.j_size*oip^.i_size;
	block_move(@oip^.intensity[0],@nip^.intensity[0],copy_size);
	image_copy:=nip;
end;

{
	image_crop returns a pointer to a new image whose contents are
	the rectangle of pixels within the analysis boundaries of the original
	image. The overlay of the new image is clear. The crop routine does 
	add one row to the top of the rectangle of pixels, so that this row
	may be used by routines such as embed_image_header for image 
	information when storing the image contents to disk.
}
function image_crop(oip:image_ptr_type):image_ptr_type;

var
	nip:image_ptr_type;
	j:integer;
	
begin
	image_crop:=nil;
	if not valid_image_ptr(oip) then exit;
	if not valid_analysis_bounds(oip) then begin
		report_error('Invalid analysis bounds in image_crop.');
		exit;
	end;
	
	with oip^.analysis_bounds do begin
		nip:=new_image(bottom-top+1+1,right-left+1);
		if nip=nil then exit;
		for j:=1 to nip^.j_size-1 do
			block_move(
				@oip^.intensity[(j+top-1)*oip^.i_size+left],
				@nip^.intensity[j*nip^.i_size],
				nip^.i_size);
	end;
	image_crop:=nip;
end;

{
	image_subtract subtracts oip_2 from oip_1 to get a new image. We clip the
	difference intensity to min_intensity and max_intensity. We assume the two
	images are the same dimensions and subtract the entire image area. To subtract
	only the analysis bounds, use image_bounds_subtract.
}
function image_subtract(oip_1,oip_2:image_ptr_type):image_ptr_type;

var
	i,j,diff:integer;
	nip:image_ptr_type;

begin
	image_subtract:=nil;
	if not valid_image_ptr(oip_1) then exit;
	if not valid_analysis_bounds(oip_1) then begin
		report_error('Invalid analysis bounds in oip_1 in image_subtract.');
		exit;
	end;
	if not valid_image_ptr(oip_2) then exit;
	if not valid_analysis_bounds(oip_1) then begin
		report_error('Invalid analysis bounds in oip_2 in image_subtract.');
		exit;
	end;
	if (oip_2^.j_size<>oip_1^.j_size) or (oip_2^.i_size<>oip_1^.i_size) then begin
		report_error('Mismatched image sizes in image_subtract.');
		exit;
	end;
		
	nip:=new_image(oip_1^.j_size,oip_1^.i_size);
	if nip=nil then exit;
	nip^.analysis_bounds:=oip_1^.analysis_bounds;

	for j:=0 to nip^.j_size-1 do begin
		for i:=0 to nip^.i_size-1 do begin
			diff:=get_px(oip_1,j,i)-get_px(oip_2,j,i);
			if diff<min_intensity then diff:=min_intensity;
			if diff>max_intensity then diff:=max_intensity;
			set_px(nip,j,i,diff);
		end;
	end;
	
	image_subtract:=nip;
end;


{
	image_accumulate adds the contrast of oip_1 and oip_2 together and sets it
	upon an average intensity of mid_intensity. We assume the two images are the
	same dimensions and subtract the entire image area.
}
function image_accumulate(oip_1,oip_2:image_ptr_type):image_ptr_type;

var
	i,j,sum,offset:integer;
	nip:image_ptr_type;

begin
	image_accumulate:=nil;
	if not valid_image_ptr(oip_1) then exit;
	if not valid_analysis_bounds(oip_1) then begin
		report_error('Invalid analysis bounds in oip_1 in image_accumulate.');
		exit;
	end;
	if not valid_image_ptr(oip_2) then exit;
	if not valid_analysis_bounds(oip_1) then begin
		report_error('Invalid analysis bounds in oip_2 in image_accumulate.');
		exit;
	end;
	if (oip_2^.j_size<>oip_1^.j_size) or (oip_2^.i_size<>oip_1^.i_size) then begin
		report_error('Mismatched image sizes in image_accumulate.');
		exit;
	end;
		
	nip:=new_image(oip_1^.j_size,oip_1^.i_size);
	if nip=nil then exit;
	nip^.analysis_bounds:=oip_1^.analysis_bounds;
	
	offset:=round(mid_intensity-image_average(oip_1)-image_average(oip_2));

	for j:=0 to nip^.j_size-1 do begin
		for i:=0 to nip^.i_size-1 do begin
			sum:=get_px(oip_1,j,i)+get_px(oip_2,j,i)+offset;
			if sum<min_intensity then sum:=min_intensity;
			if sum>max_intensity then sum:=max_intensity;
			set_px(nip,j,i,sum);
		end;
	end;
	
	image_accumulate:=nip;
end;


{
	image_bounds_subtract subtracts the intensity of oip_2 from the intensity of
	oip_1 within the analysis bounds of oip_1. We clip the
	difference intensity to min_intensity and max_intensity. 
	We assume the two images have the same dimensions.
}
function image_bounds_subtract(oip_1,oip_2:image_ptr_type):image_ptr_type;

var
	i,j,diff:integer;
	nip:image_ptr_type;

begin
	image_bounds_subtract:=nil;
	if not valid_image_ptr(oip_1) then exit;
	if not valid_analysis_bounds(oip_1) then begin
		report_error('Invalid analysis bounds in oip_1 in image_bounds_subtract.');
		exit;
	end;
	if not valid_image_ptr(oip_2) then exit;
	if not valid_analysis_bounds(oip_1) then begin
		report_error('Invalid analysis bounds in oip_2 in image_bounds_subtract.');
		exit;
	end;
	if (oip_2^.j_size<>oip_1^.j_size) or (oip_2^.i_size<>oip_1^.i_size) then begin
		report_error('Mismatched image sizes in image_bounds_subtract.');
		exit;
	end;
		
	nip:=image_copy(oip_1);
	if nip=nil then exit;

	with nip^.analysis_bounds do begin
		for j:=top to bottom do begin
			for i:=left to right do begin
				diff:=get_px(oip_1,j,i)-get_px(oip_2,j,i);
				if diff<min_intensity then diff:=min_intensity;
				if diff>max_intensity then diff:=max_intensity;
				set_px(nip,j,i,diff);
			end;
		end;
	end;
	
	image_bounds_subtract:=nip;
end;

{
	image_subtract_row_average subtracts the average value of each row from the
	pixels of each row with the analysis boundaries. The row average itself is
	calculated within the analysis boundaries also. The routine offsets the
	image intensity so that the intensity in the top-left corner remains
	unchanged.
}
function image_subtract_row_average(oip:image_ptr_type):image_ptr_type;

var
	i,j:integer;
	diff,row_ave,offset:real;
	nip:image_ptr_type;

begin
	image_subtract_row_average:=nil;
	if not valid_image_ptr(oip) then exit;
	if not valid_analysis_bounds(oip) then begin
		report_error('Invalid analysis bounds in oip_1 in image_subtract_row_average.');
		exit;
	end;
		
	nip:=image_copy(oip);
	if nip=nil then exit;
	offset:=0;

	with nip^.analysis_bounds do begin
		for j:=top to bottom do begin
			row_ave:=0;
			for i:=left to right do
				row_ave:=row_ave+get_px(oip,j,i);
			row_ave:=row_ave/(right-left+1);
			if j=top then offset:=row_ave;
			for i:=left to right do begin
				diff:=get_px(oip,j,i)-row_ave+offset;
				if diff<min_intensity then diff:=min_intensity;
				if diff>max_intensity then diff:=max_intensity;
				set_px(nip,j,i,round(diff));
			end;
		end;
	end;
	
	image_subtract_row_average:=nip;
end;

{
	image_subtract_gradient finds the average gradient of intensity in the image
	and subtracts this gradient from the image, leaving the intensity in the top-left
	corner of the analysis bounds unchanged.
}
function image_subtract_gradient(oip:image_ptr_type):image_ptr_type;

var
	i,j:integer;
	ave,diff:real;
	nip:image_ptr_type;
	gp:xy_graph_type;
	h_slope,h_intercept,h_resid,v_slope,v_intercept,v_resid:real;

begin
	image_subtract_gradient:=nil;
	if not valid_image_ptr(oip) then exit;
	if not valid_analysis_bounds(oip) then begin
		report_error('Invalid analysis bounds in oip_1 in image_subtract_gradient.');
		exit;
	end;
		
	nip:=image_copy(oip);
	if nip=nil then exit;

	with nip^.analysis_bounds do begin
		setlength(gp,bottom-top+1);
		for j:=top to bottom do begin
			ave:=0;
			for i:=left to right do ave:=ave+get_px(oip,j,i);
			ave:=ave/(right-left+1);
			gp[j-top].x:=j-top;
			gp[j-top].y:=ave;
		end;
		straight_line_fit(gp,v_slope,v_intercept,v_resid);

		setlength(gp,right-left+1);
		for i:=left to right do begin
			ave:=0;
			for j:=top to bottom do ave:=ave+get_px(oip,j,i);
			ave:=ave/(bottom-top+1);
			gp[i-left].x:=i-left;
			gp[i-left].y:=ave;
		end;
		straight_line_fit(gp,h_slope,h_intercept,h_resid);
		
		for j:=top to bottom do begin
			for i:=left to right do begin
				diff:=get_px(oip,j,i)
					-h_slope*(i-left)
					-v_slope*(j-top);
				if diff<min_intensity then diff:=min_intensity;
				if diff>max_intensity then diff:=max_intensity;
				set_px(nip,j,i,round(diff));
			end;
		end;
	end;
	
	image_subtract_gradient:=nip;
end;

{
	image_negate returns the negtive of an image. It subtracts the value of each
	pixel from max_intensity.
}
function image_negate(ip:image_ptr_type):image_ptr_type;

var
	i,j,diff:integer;
	nip:image_ptr_type;
	
begin
	image_negate:=nil;
	if not valid_image_ptr(ip) then exit;
	if not valid_analysis_bounds(ip) then begin
		report_error('Invalid analysis bounds in ip in image_negate.');
		exit;
	end;

	nip:=new_image(ip^.j_size,ip^.i_size);
	if nip=nil then exit;
	nip^.analysis_bounds:=ip^.analysis_bounds;

	for j:=0 to ip^.j_size-1 do begin
		for i:=0 to ip^.i_size-1 do begin
			diff:=max_intensity-get_px(ip,j,i);
			if diff<min_intensity then diff:=min_intensity;
			if diff>max_intensity then diff:=max_intensity;
			set_px(nip,j,i,diff);
		end;
	end;
	
	image_negate:=nip;
end;

{
	image_invert returns an image in which the top-left pixel is the bottom-right
	pixel of the original image. The pixel order is reversed with respect to the 
	original image.
}
function image_invert(ip:image_ptr_type):image_ptr_type;

var
	i,j:integer;
	nip:image_ptr_type;
	
begin
	image_invert:=nil;
	if not valid_image_ptr(ip) then exit;
	if not valid_analysis_bounds(ip) then begin
		report_error('Invalid analysis bounds in ip in image_invert.');
		exit;
	end;

	nip:=new_image(ip^.j_size,ip^.i_size);
	if nip=nil then exit;
	with nip^.analysis_bounds do begin
		left:=ip^.i_size-1-ip^.analysis_bounds.right;
		right:=ip^.i_size-1-ip^.analysis_bounds.left;
		top:=ip^.j_size-1-ip^.analysis_bounds.bottom;
		bottom:=ip^.j_size-1-ip^.analysis_bounds.top;
	end;
	
	for j:=0 to ip^.j_size-1 do begin
		for i:=0 to ip^.i_size-1 do begin
			set_px(nip,j,i,get_px(ip,ip^.j_size-1-j,ip^.i_size-1-i));
		end;
	end;
	
	image_invert:=nip;
end;

{
	image_reverse_rows returns an image in which the top row becomes the bottom
	row. The row order in the new image is reversed with respect to the original.
}
function image_reverse_rows(ip:image_ptr_type):image_ptr_type;

var
	i,j:integer;
	nip:image_ptr_type;
	
begin
	image_reverse_rows:=nil;
	if not valid_image_ptr(ip) then exit;
	if not valid_analysis_bounds(ip) then begin
		report_error('Invalid analysis bounds in ip in image_reverse_rows.');
		exit;
	end;

	nip:=new_image(ip^.j_size,ip^.i_size);
	if nip=nil then exit;
	with nip^.analysis_bounds do begin
		top:=ip^.j_size-1-ip^.analysis_bounds.bottom;
		bottom:=ip^.j_size-1-ip^.analysis_bounds.top;
		left:=ip^.analysis_bounds.left;
		right:=ip^.analysis_bounds.right;
	end;
	
	for j:=0 to ip^.j_size-1 do begin
		for i:=0 to ip^.i_size-1 do begin
			set_px(nip,j,i,get_px(ip,ip^.j_size-1-j,i));
		end;
	end;
	
	image_reverse_rows:=nip;
end;

{
	image_rows_to_columns mirrors and rotates the image by making the first row
	of the new image the first column of the original image. The first column of
	the new image is the first row of the original image.
}
function image_rows_to_columns(ip:image_ptr_type):image_ptr_type;

var
	i,j:integer;
	nip:image_ptr_type;
	
begin
	image_rows_to_columns:=nil;
	if not valid_image_ptr(ip) then exit;
	if not valid_analysis_bounds(ip) then begin
		report_error('Invalid analysis bounds in ip in image_reverse_rows.');
		exit;
	end;

	nip:=new_image(ip^.i_size,ip^.j_size);
	if nip=nil then exit;
	with nip^.analysis_bounds do begin
		top:=ip^.analysis_bounds.left;
		bottom:=ip^.analysis_bounds.right;
		left:=ip^.analysis_bounds.top;
		right:=ip^.analysis_bounds.bottom;
	end;
	
	for j:=0 to ip^.j_size-1 do begin
		for i:=0 to ip^.i_size-1 do begin
			set_px(nip,i,j,get_px(ip,j,i));
		end;
	end;
	
	image_rows_to_columns:=nip;
end;

{
	image_soec swaps the odd and even-numbered columns in an image.
}
function image_soec(ip:image_ptr_type):image_ptr_type;

var
	i,j:integer;
	nip:image_ptr_type;
	
begin
	image_soec:=nil;
	if not valid_image_ptr(ip) then exit;
	if not valid_analysis_bounds(ip) then begin
		report_error('Invalid analysis bounds in ip in image_soec.');
		exit;
	end;

	nip:=new_image(ip^.j_size,ip^.i_size);
	if nip=nil then exit;
	nip^.analysis_bounds:=ip^.analysis_bounds;
	
	for j:=0 to ip^.j_size-1 do begin
		for i:=0 to ip^.i_size-1 do begin
			if odd(i) then set_px(nip,j,i,get_px(ip,j,i-1))
			else if i<ip^.i_size-1 then set_px(nip,j,i,get_px(ip,j,i+1))
			else set_px(nip,j,i,get_px(ip,j,i));
		end;
	end;
	
	image_soec:=nip;
end;

{
	image_soer swaps the odd and even-numbered rows in an image.
}
function image_soer(ip:image_ptr_type):image_ptr_type;

var
	i,j:integer;
	nip:image_ptr_type;
	
begin
	image_soer:=nil;
	if not valid_image_ptr(ip) then exit;
	if not valid_analysis_bounds(ip) then begin
		report_error('Invalid analysis bounds in ip in image_soer.');
		exit;
	end;

	nip:=new_image(ip^.j_size,ip^.i_size);
	if nip=nil then exit;
	nip^.analysis_bounds:=ip^.analysis_bounds;
	
	for j:=0 to ip^.j_size-1 do begin
		if odd(j) then 
			for i:=0 to ip^.i_size-1 do set_px(nip,j,i,get_px(ip,j-1,i))
		else if j<ip^.j_size-1 then 
			for i:=0 to ip^.i_size-1 do set_px(nip,j,i,get_px(ip,j+1,i))
		else 
			for i:=0 to ip^.i_size-1 do set_px(nip,j,i,get_px(ip,j,i));
	end;
	
	image_soer:=nip;
end;

{
	image_quadratic_sum combines the intensity of two images by
	quadratic sum and returns a pointer to the new image.
}
function image_quadratic_sum(oip_1,oip_2:image_ptr_type):image_ptr_type;
var
	i,j:integer;
	nip:image_ptr_type;
	sum:integer;

begin
	image_quadratic_sum:=nil;
	if not valid_image_ptr(oip_1) then exit;
	if not valid_analysis_bounds(oip_1) then begin
		report_error('Invalid analysis bounds in oip_1 in image_quadratic_sum.');
		exit;
	end;
	if not valid_image_ptr(oip_2) then exit;
	if not valid_analysis_bounds(oip_1) then begin
		report_error('Invalid analysis bounds in oip_2 in image_quadratic_sum.');
		exit;
	end;
	if (oip_2^.j_size<oip_1^.j_size) or (oip_2^.i_size<oip_1^.i_size) then begin
		report_error('Mismatched image sizes in image_quadratic_sum.');
		exit;
	end;
	nip:=new_image(oip_1^.j_size,oip_1^.i_size);
	if nip=nil then exit;
	nip^.analysis_bounds:=oip_1^.analysis_bounds;

	for j:=0 to nip^.j_size-1 do begin
		for i:=0 to nip^.i_size-1 do begin
			sum:=round(sqrt(sqr(1.0*get_px(oip_1,j,i))+sqr(1.0*get_px(oip_2,j,i))));			
			if (sum>max_intensity) then sum:=max_intensity;
			set_px(nip,j,i,sum);
		end;
	end;
	
	image_quadratic_sum:=nip;
end;

{
	image_filter passes a 3x3 filter over image_ptr^. The 3x3 filter is
	specified as a 3x1 and a 1x3 filter. The 3x3 is the matrix product (1x3)
	(3x1). The 3x1 matrix is (a b c). The 1x3 matrix is (c d e) transposed. To
	accommodate negative results, the filter output intensity is offset by
	mid_intensity. A filter output of zero results in intensity mid_intensity.
	The filtered image intensity is, of course, clipped to max_intensity and
	min_intensity. The divisor parameter allows us to reduce the filter output
	before we add it to mid_intensity, and so avoid clipping with high-gain
	filters. If you set the divisor to zero, the routine automatically scales
	the intensity so that it fills the available range in the output image. If
	your filter is a simple one, like the horizontal gradient or vertical
	gradient, consider using one of our specialized filter routines.
	image_filter is less efficient than the specialized routines because it must
	create an intermediate working area in order to support the general form of
	the 3x3 convoluted filter. Around the borders of the original image's
	analysis boundaries, we cannot implement the 3x3 filter because the filter
	extent crosses over the boundary. The routine fills in the border pixels so
	that it can leave the analysis boundaries the same as the original image
	boundaries.
}
function image_filter(oip:image_ptr_type;a,b,c,d,e,f,divisor:real):image_ptr_type;

type
	work_area_type=array of array of real;

var
	wa:work_area_type;
	fo:real;
	i,j:integer;
	nip:image_ptr_type;
	max,min,fo_max,fo_min:real;
	
begin
{
	Check the original image.	
}	
	image_filter:=nil;
	if not valid_image_ptr(oip) then exit;
	if not valid_analysis_bounds(oip) then begin
		report_error('Invalid analysis bounds in image_filter.');
		exit;
	end;
{
	Create a new image and move its analysis boundaries in by one
	to accommodate the filter, which extends by up to one pixel in
	every direction from the pixel of operation.
}
	nip:=new_image(oip^.j_size,oip^.i_size);
	if nip=nil then begin
		report_error('Cannot allocate space for nip in image_filter.');
		exit;
	end;
	nip^.analysis_bounds:=oip^.analysis_bounds;
{
	Create a working area in which to store intermediate results
	required by the filter calculation.
}
	setlength(wa,oip^.j_size,oip^.i_size);
{
	For each pixel in the new image, calculate the result of the
	row-component of the filter and place this result in the working
	area.
}
	min:=max_intensity;
	max:=0;
	with nip^.analysis_bounds do begin
		for j:=top to bottom do begin
			for i:=left+1 to right-1 do begin
				wa[j,i]:=a*get_px(oip,j,i-1)
					+ b*get_px(oip,j,i)
					+ c*get_px(oip,j,i+1);
				if wa[j,i]>max then max:=wa[j,i];
				if wa[j,i]<min then min:=wa[j,i];
			end;
		end;
	end;
{
	Deal with the left and right columns.
}
	with nip^.analysis_bounds do begin
		for j:=top to bottom do begin
			wa[j,left]:=wa[j,left+1];
			wa[j,right]:=wa[j,right-1];
		end;
	end;
{
	Determine the maximum possible value of the output image and the minimum
	possible value.
}
	fo_max:=0;
	fo_min:=0;
	if d>0 then begin fo_max:=fo_max+d*max; fo_min:=fo_min+d*min; end
	else begin fo_max:=fo_max+d*min; fo_min:=fo_min+d*max; end;
	if e>0 then begin fo_max:=fo_max+e*max; fo_min:=fo_min+e*min; end
	else begin fo_max:=fo_max+e*min; fo_min:=fo_min+e*max; end;
	if f>0 then begin fo_max:=fo_max+f*max; fo_min:=fo_min+f*min; end
	else begin fo_max:=fo_max+f*min; fo_min:=fo_min+f*max; end;
{
	Apply the column-component of the filter to the working area elements,
	reduce them with the divisor, offset them by mid_intensity, and clip them to
	min_intensity and max_intensity. If the divisor is zero, we use the maximum
	possible value of three elements of the work area added together as our
	guide to dividing the filtered image intensity.
}
	with nip^.analysis_bounds do begin
		for j:=top+1 to bottom-1 do begin
			for i:=left to right do begin
				fo:=d*wa[j-1,i]+e*wa[j,i]+f*wa[j+1,i];
				if divisor<>0 then begin
					fo:=fo/divisor;
					if fo<0 then fo:=0;
					if fo>max_intensity then fo:=max_intensity;
				end else 
					if (fo_max-fo_min)>0 then
						fo:=max_intensity*(fo-fo_min)/(fo_max-fo_min);
				set_px(nip,j,i,round(fo));
			end; 
		end;
	end;
{
	Fill in the top and bottom rows.
}
	with nip^.analysis_bounds do begin
		for i:=0 to nip^.i_size do begin
			set_px(nip,top,i,get_px(nip,top+1,i));
			set_px(nip,bottom,i,get_px(nip,bottom-1,i));
		end;
	end;
{
	Return a pointer to the newly-created filter image.
}
	image_filter:=nip;
end;

{
	image_grad_i calculates the absolute value of the horizontal
	intensity gradient at each pixel. The routine creates a new image
	with the same analysis boundaries as the original. The intensity
	of pixel (i,j) in the new image is the absolute value of the
	difference between the original pixels (i+1,j) and (i-1,j). On the
	left and right edges of the analyis boundaries, however, we use
	the (i,j) intensity and the right or left neighbor respectively,
	so that we do not use pixels outside the analysis boundaries.
}
function image_grad_i(oip:image_ptr_type):image_ptr_type;

var
	nip:image_ptr_type;
	i,j:integer;
	
begin
	image_grad_i:=nil;
	if not valid_image_ptr(oip) then exit;
	if not valid_analysis_bounds(oip) then begin
		report_error('Invalid analysis bounds in image_grad_i.');
		exit;
	end;

	nip:=new_image(oip^.j_size,oip^.i_size);
	if nip=nil then exit;
	
	nip^.analysis_bounds:=oip^.analysis_bounds;	
	with nip^.analysis_bounds do 
		for j:=top to bottom do begin
			set_px(nip,j,left,abs(get_px(oip,j,left+1)-get_px(oip,j,left)));
			for i:=left+1 to right-1 do
				set_px(nip,j,i,abs(get_px(oip,j,i+1)-get_px(oip,j,i-1)));
			set_px(nip,j,right,abs(get_px(oip,j,right)-get_px(oip,j,right-1)));
		end;
		
	image_grad_i:=nip;
end;

{
	image_grad_j calculates the absolute value of the vertical
	intensity gradient in the same way that image_grad_i calculates
	the horizontal intensity gradient.
}
function image_grad_j(oip:image_ptr_type):image_ptr_type;

var
	nip:image_ptr_type;
	i,j:integer;
	
begin
	image_grad_j:=nil;
	if not valid_image_ptr(oip) then exit;
	if not valid_analysis_bounds(oip) then begin
		report_error('Invalid analysis bounds in image_grad_j.');
		exit;
	end;

	nip:=new_image(oip^.j_size,oip^.i_size);
	if nip=nil then exit;
	
	nip^.analysis_bounds:=oip^.analysis_bounds;	
	with nip^.analysis_bounds do 
		for i:=left to right do begin
			set_px(nip,top,i,abs(get_px(oip,top+1,i)-get_px(oip,top,i)));
			for j:=top+1 to bottom-1 do
				set_px(nip,j,i,abs(get_px(oip,j+1,i)-get_px(oip,j-1,i)));
			set_px(nip,bottom,i,abs(get_px(oip,bottom,i)-get_px(oip,bottom-1,i)));
		end;
		
	image_grad_j:=nip;
end;


{
	image_grad returns the quadratic sum of image_grad_i 
	and image_grad_j results.
}
function image_grad(ip:image_ptr_type):image_ptr_type;

var 
	gip,gjp:image_ptr_type;

begin
	gip:=image_grad_i(ip);
	gjp:=image_grad_j(ip);
	image_grad:=image_quadratic_sum(gip,gjp);
	dispose_image(gip);
	dispose_image(gjp);
end;

{
	image_profile_row generates an x_graph_type containing the average intensity
	of pixels in each column within the analysis bounds of the specified image. 
	The first entry in the x_graph_type is the average intensity of the left-most
	column in the analysis bounds. It may at first seem more useful to provide this
	profile as an x-y graph, with column number for x and intensity for y. But we 
	run into trouble with the x-y graph presentation when we work with the column
	profiles, as obtained with image_profile_column. In that case, would x represent
	the row number and y the intensity, or would it be switched around? When it comes
	to plotting the graph with routines like display_real_graph, we run into even
	more confusion. So we leave the profile as an x-graph, just a sequence of numbers,
	and allow the calling routine to handle the sequence in the way it sees fit.
}
function image_profile_row(ip:image_ptr_type):x_graph_type;

var
	i,j,sum:integer;
	pp:x_graph_type;
	
begin	
	image_profile_row:=nil;
	if not valid_image_ptr(ip) then exit;
	if not valid_analysis_bounds(ip) then exit;
	
	with ip^.analysis_bounds do begin
		setlength(pp,right-left+1);
		for i:=left to right do begin 
			sum:=0;
			for j:=top to bottom do 
				sum:=sum+get_px(ip,j,i);
			pp[i-left]:=sum/(bottom-top+1);
		end;
	end;
	image_profile_row:=pp;
end;

{
	image_profile_column is like image_profile_row, but for columns.
}
function image_profile_column(ip:image_ptr_type):x_graph_type;

var
	i,j,sum:integer;
	pp:x_graph_type;

begin	
	image_profile_column:=nil;
	if not valid_image_ptr(ip) then exit;
	if not valid_analysis_bounds(ip) then exit;
	
	with ip^.analysis_bounds do begin
		setlength(pp,bottom-top+1);
		for j:=top to bottom do begin 
			sum:=0;
			for i:=left to right do 
				sum:=sum+get_px(ip,j,i);
			pp[j-top]:=sum/(right-left+1);
		end;
	end;
	image_profile_column:=pp;
end;

{
	image_histogram returns a histogram of intensity in the analysis bounds
	of an image. The histogram takes the form of an xy_graph that you can
	display in an image overlay with display_real_graph. The x-axis of the
	histogram gives the intensity, and the y-axis gives the frequency with
	which this intensity occured in the analysis bounds of the image.
}
function image_histogram(ip:image_ptr_type):xy_graph_type;

var
	i,j,num_bins:integer;
	hp:xy_graph_type;

begin
	image_histogram:=nil;
	if not valid_image_ptr(ip) then exit;
	if not valid_analysis_bounds(ip) then exit;


	num_bins:=max_intensity-min_intensity+1;
	setlength(hp,num_bins);
	
	for i:=min_intensity to max_intensity do begin
		with hp[i-min_intensity] do begin
			x:=i;
			y:=0;
		end;
	end;
	
	with ip^.analysis_bounds do begin
		for j:=top to bottom do begin
			for i:=left to right do begin
				with hp[get_px(ip,j,i)] do y:=y+1;
			end;
		end;
	end;	

	image_histogram:=hp;
end;


end.