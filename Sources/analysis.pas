{
	Main Program for use with Analysis Shared Library 
	Copyright (C) 2007-2020 Kevan Hashemi, Brandeis University
	
	This program is free software; you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the Free
	Software Foundation; either version 2 of the License, or (at your option)
	any later version.

	This program is distributed in the hope that it will be useful, but WITHOUT
	ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
	FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
	more details.

	You should have received a copy of the GNU General Public License along with
	this program; if not, write to the Free Software Foundation, Inc., 59 Temple
	Place - Suite 330, Boston, MA	02111-1307, USA.
}

library analysis;

{
	This is a library of routines from our analysis units, which are list
	in the library's uses clause.
}

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}

uses
	utils,images,transforms,image_manip,rasnik,
	spot,bcam,shadow,wps,electronics,metrics;

{$IFDEF DARWIN}
	const ld_prefix='_';
{$ENDIF}

{$IFDEF WINDOWS}
	const ld_prefix='_';
{$ENDIF}

{$IFNDEF WINDOWS}{$IFNDEF DARWIN}
	const ld_prefix='';
{$ENDIF}{$ENDIF}

exports

{utils}
	check_for_math_error name ld_prefix+'check_for_math_error',
	math_error name ld_prefix+'math_error',
	math_overflow name ld_prefix+'math_overflow',
	error_function name ld_prefix+'error_function',
	complimentary_error_function name ld_prefix+'complimentary_error_function',
	gamma_function name ld_prefix+'gamma_function',
	chi_squares_distribution name ld_prefix+'chi_squares_distribution',
	chi_squares_probability name ld_prefix+'chi_squares_probability',
	factorial name ld_prefix+'factorial',
	full_arctan name ld_prefix+'full_arctan',
	sum_sinusoids name ld_prefix+'sum_sinusoids',
	xpy name ld_prefix+'xpy',
	xpyi name ld_prefix+'xpyi',
	random_0_to_1 name ld_prefix+'random_0_to_1',
	new_matrix name ld_prefix+'new_matrix',
	matrix_rows name ld_prefix+'matrix_rows',
	matrix_columns name ld_prefix+'matrix_columns',
	matrix_copy name ld_prefix+'matrix_copy',
	unit_matrix name ld_prefix+'unit_matrix',
	matrix_product name ld_prefix+'matrix_product',
	matrix_determinant name ld_prefix+'matrix_determinant',
	matrix_difference name ld_prefix+'matrix_difference',
	matrix_inverse name ld_prefix+'matrix_inverse',
	swap_matrix_rows name ld_prefix+'swap_matrix_rows',
	new_simplex name ld_prefix+'new_simplex',
	simplex_step name ld_prefix+'simplex_step',
	simplex_volume name ld_prefix+'simplex_volume',
	simplex_size name ld_prefix+'simplex_size',
	simplex_construct name ld_prefix+'simplex_construct',
	simplex_vertex_copy name ld_prefix+'simplex_vertex_copy',

{images}
	get_px name ld_prefix+'get_px',
	set_px name ld_prefix+'set_px',
	get_ov name ld_prefix+'get_ov',
	set_ov name ld_prefix+'set_ov',
	paint_image name ld_prefix+'paint_image',
	clear_image name ld_prefix+'clear_image',
	paint_overlay name ld_prefix+'paint_overlay',
	fill_overlay name ld_prefix+'fill_overlay',
	clear_overlay name ld_prefix+'clear_overlay',
	dispose_image name ld_prefix+'dispose_image',
	dispose_named_images name ld_prefix+'dispose_named_images',
	draw_image name ld_prefix+'draw_image',
	draw_rggb_image name ld_prefix+'draw_rggb_image',
	draw_gbrg_image name ld_prefix+'draw_gbrg_image',
	draw_image_line name ld_prefix+'draw_image_line',
	draw_overlay_line name ld_prefix+'draw_overlay_line',
	draw_overlay_pixel name ld_prefix+'draw_overlay_pixel',
	draw_overlay_rectangle name ld_prefix+'draw_overlay_rectangle',
	draw_overlay_rectangle_ellipse name ld_prefix+'draw_overlay_rectangle_ellipse',
	draw_overlay_ellipse name ld_prefix+'draw_overlay_ellipse',
	embed_image_header name ld_prefix+'embed_image_header',
	image_ptr_from_name name ld_prefix+'image_ptr_from_name',
	image_amplitude name ld_prefix+'image_amplitude',
	image_average name ld_prefix+'image_average',
	image_median name ld_prefix+'image_median',
	image_maximum name ld_prefix+'image_maximum',
	image_minimum name ld_prefix+'image_minimum',
	image_sum name ld_prefix+'image_sum',
	overlay_color_from_integer name ld_prefix+'overlay_color_from_integer',
	spread_overlay name ld_prefix+'spread_overlay',
	paint_overlay_bounds name ld_prefix+'paint_overlay_bounds',
	new_image name ld_prefix+'new_image',
	valid_analysis_bounds name ld_prefix+'valid_analysis_bounds',
	valid_image_analysis_point name ld_prefix+'valid_image_analysis_point',	
	valid_image_name name ld_prefix+'valid_image_name',
	valid_image_point name ld_prefix+'valid_image_point',
	valid_image_ptr name ld_prefix+'valid_image_ptr',
	write_image_list name ld_prefix+'write_image_list',

{transforms}
	i_from_c name ld_prefix+'i_from_c',
	c_from_i name ld_prefix+'c_from_i',
	p_from_i name ld_prefix+'p_from_i',
	i_from_p name ld_prefix+'i_from_p',
	c_from_i_line name ld_prefix+'c_from_i_line',
	i_from_p_line name ld_prefix+'i_from_p_line',
	i_from_c_line name ld_prefix+'i_from_c_line',
	p_from_i_line name ld_prefix+'p_from_i_line',
	i_from_c_rectangle name ld_prefix+'i_from_c_rectangle',
	c_from_i_rectangle name ld_prefix+'c_from_i_rectangle',
	i_from_c_ellipse name ld_prefix+'i_from_c_ellipse',
	c_from_i_ellipse name ld_prefix+'c_from_i_ellipse',
	display_ccd_cross name ld_prefix+'display_ccd_cross',
	display_ccd_line name ld_prefix+'display_ccd_line',
	draw_ccd_line name ld_prefix+'draw_ccd_line',
	display_ccd_pixel name ld_prefix+'display_ccd_pixel',
	display_ccd_rectangle name ld_prefix+'display_ccd_rectangle',
	display_ccd_rectangle_cross name ld_prefix+'display_ccd_rectangle_cross',
	display_ccd_rectangle_ellipse name ld_prefix+'display_ccd_rectangle_ellipse',
	display_ccd_ellipse name ld_prefix+'display_ccd_ellipse',
	display_profile_row name ld_prefix+'display_profile_row',
	display_profile_column name ld_prefix+'display_profile_column',
	display_real_graph name ld_prefix+'display_real_graph',
	draw_real_graph name ld_prefix+'draw_real_graph',

{image_manip}
	image_copy name ld_prefix+'image_copy',
	image_filter name ld_prefix+'image_filter',
	image_grad_i name ld_prefix+'image_grad_i',
	image_grad_j name ld_prefix+'image_grad_j',
	image_grad name ld_prefix+'image_grad',
	image_shrink name ld_prefix+'image_shrink',
	image_enlarge name ld_prefix+'image_enlarge',
	image_rotate name ld_prefix+'image_rotate',
	image_profile_column name ld_prefix+'image_profile_column',
	image_profile_row name ld_prefix+'image_profile_row',
	image_quadratic_sum name ld_prefix+'image_quadratic_sum',
	image_accumulate name ld_prefix+'image_accumulate',
	image_subtract name ld_prefix+'image_subtract',
	image_subtract_row_average name ld_prefix+'image_subtract_row_average',
	image_subtract_gradient name ld_prefix+'image_subtract_gradient',
	image_transfer_overlay name ld_prefix+'image_transfer_overlay',
	image_bounds_subtract name ld_prefix+'image_bounds_subtract',
	image_negate name ld_prefix+'image_negate',
	image_histogram name ld_prefix+'image_histogram',
	image_invert name ld_prefix+'image_invert',
	image_reverse_rows name ld_prefix+'image_reverse_rows',
	image_soec name ld_prefix+'image_soec',
	image_soer name ld_prefix+'image_soer',
	image_crop name ld_prefix+'image_crop',

{rasnik}
	new_rasnik name ld_prefix+'new_rasnik',
	dispose_rasnik name ld_prefix+'dispose_rasnik',
	rasnik_analyze_image name ld_prefix+'rasnik_analyze_image',
	new_rasnik_pattern name ld_prefix+'new_rasnik_pattern',
	dispose_rasnik_pattern name ld_prefix+'dispose_rasnik_pattern',
	rasnik_adjust_pattern_parity name ld_prefix+'rasnik_adjust_pattern_parity',
	rasnik_analyze_code name ld_prefix+'rasnik_analyze_code',
	rasnik_display_pattern name ld_prefix+'rasnik_display_pattern',
	rasnik_find_pattern name ld_prefix+'rasnik_find_pattern',
	rasnik_refine_pattern name ld_prefix+'rasnik_refine_pattern',
	rasnik_from_pattern name ld_prefix+'rasnik_from_pattern',
	rasnik_identify_code_squares name ld_prefix+'rasnik_identify_code_squares',
	rasnik_identify_pattern_squares name ld_prefix+'rasnik_identify_pattern_squares',
	rasnik_mask_position name ld_prefix+'rasnik_mask_position',
	rasnik_pattern_from_string name ld_prefix+'rasnik_pattern_from_string',
	rasnik_from_string name ld_prefix+'rasnik_from_string',
	rasnik_shift_reference_point name ld_prefix+'rasnik_shift_reference_point',
	rasnik_simulated_image name ld_prefix+'rasnik_simulated_image',
	string_from_rasnik_pattern name ld_prefix+'string_from_rasnik_pattern',
	string_from_rasnik name ld_prefix+'string_from_rasnik';

end.
