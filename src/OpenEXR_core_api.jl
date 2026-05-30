# Julia wrapper for header: openexr.h
# Automatically generated using Clang.jl


function exr_get_library_version(maj, min, patch, extra)
    ccall((:exr_get_library_version, libOpenEXRCore), Cvoid, (Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ptr{Cstring}), maj, min, patch, extra)
end

function exr_set_default_maximum_image_size(w, h)
    ccall((:exr_set_default_maximum_image_size, libOpenEXRCore), Cvoid, (Cint, Cint), w, h)
end

function exr_get_default_maximum_image_size(w, h)
    ccall((:exr_get_default_maximum_image_size, libOpenEXRCore), Cvoid, (Ptr{Cint}, Ptr{Cint}), w, h)
end

function exr_set_default_maximum_tile_size(w, h)
    ccall((:exr_set_default_maximum_tile_size, libOpenEXRCore), Cvoid, (Cint, Cint), w, h)
end

function exr_get_default_maximum_tile_size(w, h)
    ccall((:exr_get_default_maximum_tile_size, libOpenEXRCore), Cvoid, (Ptr{Cint}, Ptr{Cint}), w, h)
end

function exr_set_default_zip_compression_level(l)
    ccall((:exr_set_default_zip_compression_level, libOpenEXRCore), Cvoid, (Cint,), l)
end

function exr_get_default_zip_compression_level(l)
    ccall((:exr_get_default_zip_compression_level, libOpenEXRCore), Cvoid, (Ptr{Cint},), l)
end

function exr_set_default_dwa_compression_quality(q)
    ccall((:exr_set_default_dwa_compression_quality, libOpenEXRCore), Cvoid, (Cfloat,), q)
end

function exr_get_default_dwa_compression_quality(q)
    ccall((:exr_get_default_dwa_compression_quality, libOpenEXRCore), Cvoid, (Ptr{Cfloat},), q)
end

function exr_set_default_memory_routines(alloc_func, free_func)
    ccall((:exr_set_default_memory_routines, libOpenEXRCore), Cvoid, (exr_memory_allocation_func_t, exr_memory_free_func_t), alloc_func, free_func)
end

function exr_get_default_error_message(code)
    ccall((:exr_get_default_error_message, libOpenEXRCore), Cstring, (exr_result_t,), code)
end

function exr_get_error_code_as_string(code)
    ccall((:exr_get_error_code_as_string, libOpenEXRCore), Cstring, (exr_result_t,), code)
end

function exr_test_file_header(filename, ctxtdata)
    ccall((:exr_test_file_header, libOpenEXRCore), exr_result_t, (Cstring, Ptr{exr_context_initializer_t}), filename, ctxtdata)
end

function exr_finish(ctxt)
    ccall((:exr_finish, libOpenEXRCore), exr_result_t, (Ptr{exr_context_t},), ctxt)
end

function exr_start_read(ctxt, filename, ctxtdata)
    ccall((:exr_start_read, libOpenEXRCore), exr_result_t, (Ptr{exr_context_t}, Cstring, Ptr{exr_context_initializer_t}), ctxt, filename, ctxtdata)
end

function exr_start_write(ctxt, filename, default_mode, ctxtdata)
    ccall((:exr_start_write, libOpenEXRCore), exr_result_t, (Ptr{exr_context_t}, Cstring, exr_default_write_mode_t, Ptr{exr_context_initializer_t}), ctxt, filename, default_mode, ctxtdata)
end

function exr_start_inplace_header_update(ctxt, filename, ctxtdata)
    ccall((:exr_start_inplace_header_update, libOpenEXRCore), exr_result_t, (Ptr{exr_context_t}, Cstring, Ptr{exr_context_initializer_t}), ctxt, filename, ctxtdata)
end

function exr_start_temporary_context(ctxt, context_name, ctxtdata)
    ccall((:exr_start_temporary_context, libOpenEXRCore), exr_result_t, (Ptr{exr_context_t}, Cstring, Ptr{exr_context_initializer_t}), ctxt, context_name, ctxtdata)
end

function exr_get_file_name(ctxt, name)
    ccall((:exr_get_file_name, libOpenEXRCore), exr_result_t, (exr_const_context_t, Ptr{Cstring}), ctxt, name)
end

function exr_get_file_version_and_flags(ctxt, ver)
    ccall((:exr_get_file_version_and_flags, libOpenEXRCore), exr_result_t, (exr_const_context_t, Ptr{UInt32}), ctxt, ver)
end

function exr_get_user_data(ctxt, userdata)
    ccall((:exr_get_user_data, libOpenEXRCore), exr_result_t, (exr_const_context_t, Ptr{Ptr{Cvoid}}), ctxt, userdata)
end

function exr_register_attr_type_handler(ctxt, type, unpack_func_ptr, pack_func_ptr, destroy_unpacked_func_ptr)
    ccall((:exr_register_attr_type_handler, libOpenEXRCore), exr_result_t, (exr_context_t, Cstring, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}), ctxt, type, unpack_func_ptr, pack_func_ptr, destroy_unpacked_func_ptr)
end

function exr_set_longname_support(ctxt, onoff)
    ccall((:exr_set_longname_support, libOpenEXRCore), exr_result_t, (exr_context_t, Cint), ctxt, onoff)
end

function exr_write_header(ctxt)
    ccall((:exr_write_header, libOpenEXRCore), exr_result_t, (exr_context_t,), ctxt)
end

function exr_get_count(ctxt, count)
    ccall((:exr_get_count, libOpenEXRCore), exr_result_t, (exr_const_context_t, Ptr{Cint}), ctxt, count)
end

function exr_get_name(ctxt, part_index, out)
    ccall((:exr_get_name, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{Cstring}), ctxt, part_index, out)
end

function exr_get_storage(ctxt, part_index, out)
    ccall((:exr_get_storage, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{exr_storage_t}), ctxt, part_index, out)
end

function exr_add_part(ctxt, partname, type, new_index)
    ccall((:exr_add_part, libOpenEXRCore), exr_result_t, (exr_context_t, Cstring, exr_storage_t, Ptr{Cint}), ctxt, partname, type, new_index)
end

function exr_get_tile_levels(ctxt, part_index, levelsx, levelsy)
    ccall((:exr_get_tile_levels, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{Int32}, Ptr{Int32}), ctxt, part_index, levelsx, levelsy)
end

function exr_get_tile_sizes(ctxt, part_index, levelx, levely, tilew, tileh)
    ccall((:exr_get_tile_sizes, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cint, Cint, Ptr{Int32}, Ptr{Int32}), ctxt, part_index, levelx, levely, tilew, tileh)
end

function exr_get_tile_counts(ctxt, part_index, levelx, levely, countx, county)
    ccall((:exr_get_tile_counts, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cint, Cint, Ptr{Int32}, Ptr{Int32}), ctxt, part_index, levelx, levely, countx, county)
end

function exr_get_level_sizes(ctxt, part_index, levelx, levely, levw, levh)
    ccall((:exr_get_level_sizes, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cint, Cint, Ptr{Int32}, Ptr{Int32}), ctxt, part_index, levelx, levely, levw, levh)
end

function exr_get_chunk_count(ctxt, part_index, out)
    ccall((:exr_get_chunk_count, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{Int32}), ctxt, part_index, out)
end

function exr_get_chunk_table(ctxt, part_index, table, count)
    ccall((:exr_get_chunk_table, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{Ptr{UInt64}}, Ptr{Int32}), ctxt, part_index, table, count)
end

function exr_validate_chunk_table(ctxt, part_index)
    ccall((:exr_validate_chunk_table, libOpenEXRCore), exr_result_t, (exr_context_t, Cint), ctxt, part_index)
end

function exr_get_scanlines_per_chunk(ctxt, part_index, out)
    ccall((:exr_get_scanlines_per_chunk, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{Int32}), ctxt, part_index, out)
end

function exr_get_chunk_unpacked_size(ctxt, part_index, out)
    ccall((:exr_get_chunk_unpacked_size, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{UInt64}), ctxt, part_index, out)
end

function exr_get_zip_compression_level(ctxt, part_index, level)
    ccall((:exr_get_zip_compression_level, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{Cint}), ctxt, part_index, level)
end

function exr_set_zip_compression_level(ctxt, part_index, level)
    ccall((:exr_set_zip_compression_level, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cint), ctxt, part_index, level)
end

function exr_get_dwa_compression_level(ctxt, part_index, level)
    ccall((:exr_get_dwa_compression_level, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{Cfloat}), ctxt, part_index, level)
end

function exr_set_dwa_compression_level(ctxt, part_index, level)
    ccall((:exr_set_dwa_compression_level, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cfloat), ctxt, part_index, level)
end

function exr_get_attribute_count(ctxt, part_index, count)
    ccall((:exr_get_attribute_count, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{Int32}), ctxt, part_index, count)
end

function exr_get_attribute_by_index(ctxt, part_index, mode, idx, outattr)
    ccall((:exr_get_attribute_by_index, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, exr_attr_list_access_mode_t, Int32, Ptr{Ptr{exr_attribute_t}}), ctxt, part_index, mode, idx, outattr)
end

function exr_get_attribute_by_name(ctxt, part_index, name, outattr)
    ccall((:exr_get_attribute_by_name, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{Ptr{exr_attribute_t}}), ctxt, part_index, name, outattr)
end

function exr_get_attribute_list(ctxt, part_index, mode, count, outlist)
    ccall((:exr_get_attribute_list, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, exr_attr_list_access_mode_t, Ptr{Int32}, Ptr{Ptr{exr_attribute_t}}), ctxt, part_index, mode, count, outlist)
end

function exr_attr_declare_by_type(ctxt, part_index, name, type, newattr)
    ccall((:exr_attr_declare_by_type, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Cstring, Ptr{Ptr{exr_attribute_t}}), ctxt, part_index, name, type, newattr)
end

function exr_attr_declare(ctxt, part_index, name, type, newattr)
    ccall((:exr_attr_declare, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, exr_attribute_type_t, Ptr{Ptr{exr_attribute_t}}), ctxt, part_index, name, type, newattr)
end

function exr_initialize_required_attr(ctxt, part_index, displayWindow, dataWindow, pixelaspectratio, screenWindowCenter, screenWindowWidth, lineorder, ctype)
    ccall((:exr_initialize_required_attr, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Ptr{exr_attr_box2i_t}, Ptr{exr_attr_box2i_t}, Cfloat, Ptr{exr_attr_v2f_t}, Cfloat, exr_lineorder_t, exr_compression_t), ctxt, part_index, displayWindow, dataWindow, pixelaspectratio, screenWindowCenter, screenWindowWidth, lineorder, ctype)
end

function exr_initialize_required_attr_simple(ctxt, part_index, width, height, ctype)
    ccall((:exr_initialize_required_attr_simple, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Int32, Int32, exr_compression_t), ctxt, part_index, width, height, ctype)
end

function exr_copy_unset_attributes(ctxt, part_index, source, src_part_index)
    ccall((:exr_copy_unset_attributes, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, exr_const_context_t, Cint), ctxt, part_index, source, src_part_index)
end

function exr_get_channels(ctxt, part_index, chlist)
    ccall((:exr_get_channels, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{Ptr{exr_attr_chlist_t}}), ctxt, part_index, chlist)
end

function exr_add_channel(ctxt, part_index, name, ptype, percept, xsamp, ysamp)
    ccall((:exr_add_channel, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, exr_pixel_type_t, exr_perceptual_treatment_t, Int32, Int32), ctxt, part_index, name, ptype, percept, xsamp, ysamp)
end

function exr_set_channels(ctxt, part_index, channels)
    ccall((:exr_set_channels, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Ptr{exr_attr_chlist_t}), ctxt, part_index, channels)
end

function exr_get_compression(ctxt, part_index, compression)
    ccall((:exr_get_compression, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{exr_compression_t}), ctxt, part_index, compression)
end

function exr_set_compression(ctxt, part_index, ctype)
    ccall((:exr_set_compression, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, exr_compression_t), ctxt, part_index, ctype)
end

function exr_get_data_window(ctxt, part_index, out)
    ccall((:exr_get_data_window, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{exr_attr_box2i_t}), ctxt, part_index, out)
end

function exr_set_data_window(ctxt, part_index, dw)
    ccall((:exr_set_data_window, libOpenEXRCore), Cint, (exr_context_t, Cint, Ptr{exr_attr_box2i_t}), ctxt, part_index, dw)
end

function exr_get_display_window(ctxt, part_index, out)
    ccall((:exr_get_display_window, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{exr_attr_box2i_t}), ctxt, part_index, out)
end

function exr_set_display_window(ctxt, part_index, dw)
    ccall((:exr_set_display_window, libOpenEXRCore), Cint, (exr_context_t, Cint, Ptr{exr_attr_box2i_t}), ctxt, part_index, dw)
end

function exr_get_lineorder(ctxt, part_index, out)
    ccall((:exr_get_lineorder, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{exr_lineorder_t}), ctxt, part_index, out)
end

function exr_set_lineorder(ctxt, part_index, lo)
    ccall((:exr_set_lineorder, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, exr_lineorder_t), ctxt, part_index, lo)
end

function exr_get_pixel_aspect_ratio(ctxt, part_index, par)
    ccall((:exr_get_pixel_aspect_ratio, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{Cfloat}), ctxt, part_index, par)
end

function exr_set_pixel_aspect_ratio(ctxt, part_index, par)
    ccall((:exr_set_pixel_aspect_ratio, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cfloat), ctxt, part_index, par)
end

function exr_get_screen_window_center(ctxt, part_index, wc)
    ccall((:exr_get_screen_window_center, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{exr_attr_v2f_t}), ctxt, part_index, wc)
end

function exr_set_screen_window_center(ctxt, part_index, wc)
    ccall((:exr_set_screen_window_center, libOpenEXRCore), Cint, (exr_context_t, Cint, Ptr{exr_attr_v2f_t}), ctxt, part_index, wc)
end

function exr_get_screen_window_width(ctxt, part_index, out)
    ccall((:exr_get_screen_window_width, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{Cfloat}), ctxt, part_index, out)
end

function exr_set_screen_window_width(ctxt, part_index, ssw)
    ccall((:exr_set_screen_window_width, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cfloat), ctxt, part_index, ssw)
end

function exr_get_tile_descriptor(ctxt, part_index, xsize, ysize, level, round)
    ccall((:exr_get_tile_descriptor, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{UInt32}, Ptr{UInt32}, Ptr{exr_tile_level_mode_t}, Ptr{exr_tile_round_mode_t}), ctxt, part_index, xsize, ysize, level, round)
end

function exr_set_tile_descriptor(ctxt, part_index, x_size, y_size, level_mode, round_mode)
    ccall((:exr_set_tile_descriptor, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, UInt32, UInt32, exr_tile_level_mode_t, exr_tile_round_mode_t), ctxt, part_index, x_size, y_size, level_mode, round_mode)
end

function exr_set_name(ctxt, part_index, val)
    ccall((:exr_set_name, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring), ctxt, part_index, val)
end

function exr_get_version(ctxt, part_index, out)
    ccall((:exr_get_version, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{Int32}), ctxt, part_index, out)
end

function exr_set_version(ctxt, part_index, val)
    ccall((:exr_set_version, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Int32), ctxt, part_index, val)
end

function exr_set_chunk_count(ctxt, part_index, val)
    ccall((:exr_set_chunk_count, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Int32), ctxt, part_index, val)
end

function exr_attr_get_box2i(ctxt, part_index, name, outval)
    ccall((:exr_attr_get_box2i, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{exr_attr_box2i_t}), ctxt, part_index, name, outval)
end

function exr_attr_set_box2i(ctxt, part_index, name, val)
    ccall((:exr_attr_set_box2i, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Ptr{exr_attr_box2i_t}), ctxt, part_index, name, val)
end

function exr_attr_get_box2f(ctxt, part_index, name, outval)
    ccall((:exr_attr_get_box2f, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{exr_attr_box2f_t}), ctxt, part_index, name, outval)
end

function exr_attr_set_box2f(ctxt, part_index, name, val)
    ccall((:exr_attr_set_box2f, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Ptr{exr_attr_box2f_t}), ctxt, part_index, name, val)
end

function exr_attr_get_bytes(ctxt, part_index, name, out)
    ccall((:exr_attr_get_bytes, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{exr_attr_bytes_t}), ctxt, part_index, name, out)
end

function exr_attr_set_bytes(ctxt, part_index, name, val)
    ccall((:exr_attr_set_bytes, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Ptr{exr_attr_bytes_t}), ctxt, part_index, name, val)
end

function exr_attr_get_channels(ctxt, part_index, name, chlist)
    ccall((:exr_attr_get_channels, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{Ptr{exr_attr_chlist_t}}), ctxt, part_index, name, chlist)
end

function exr_attr_set_channels(ctxt, part_index, name, channels)
    ccall((:exr_attr_set_channels, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Ptr{exr_attr_chlist_t}), ctxt, part_index, name, channels)
end

function exr_attr_get_chromaticities(ctxt, part_index, name, chroma)
    ccall((:exr_attr_get_chromaticities, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{exr_attr_chromaticities_t}), ctxt, part_index, name, chroma)
end

function exr_attr_set_chromaticities(ctxt, part_index, name, chroma)
    ccall((:exr_attr_set_chromaticities, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Ptr{exr_attr_chromaticities_t}), ctxt, part_index, name, chroma)
end

function exr_attr_get_compression(ctxt, part_index, name, out)
    ccall((:exr_attr_get_compression, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{exr_compression_t}), ctxt, part_index, name, out)
end

function exr_attr_set_compression(ctxt, part_index, name, comp)
    ccall((:exr_attr_set_compression, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, exr_compression_t), ctxt, part_index, name, comp)
end

function exr_attr_get_double(ctxt, part_index, name, out)
    ccall((:exr_attr_get_double, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{Cdouble}), ctxt, part_index, name, out)
end

function exr_attr_set_double(ctxt, part_index, name, val)
    ccall((:exr_attr_set_double, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Cdouble), ctxt, part_index, name, val)
end

function exr_attr_get_envmap(ctxt, part_index, name, out)
    ccall((:exr_attr_get_envmap, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{exr_envmap_t}), ctxt, part_index, name, out)
end

function exr_attr_set_envmap(ctxt, part_index, name, emap)
    ccall((:exr_attr_set_envmap, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, exr_envmap_t), ctxt, part_index, name, emap)
end

function exr_attr_get_float(ctxt, part_index, name, out)
    ccall((:exr_attr_get_float, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{Cfloat}), ctxt, part_index, name, out)
end

function exr_attr_set_float(ctxt, part_index, name, val)
    ccall((:exr_attr_set_float, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Cfloat), ctxt, part_index, name, val)
end

function exr_attr_get_float_vector(ctxt, part_index, name, sz, out)
    ccall((:exr_attr_get_float_vector, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{Int32}, Ptr{Ptr{Cfloat}}), ctxt, part_index, name, sz, out)
end

function exr_attr_set_float_vector(ctxt, part_index, name, sz, vals)
    ccall((:exr_attr_set_float_vector, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Int32, Ptr{Cfloat}), ctxt, part_index, name, sz, vals)
end

function exr_attr_get_int(ctxt, part_index, name, out)
    ccall((:exr_attr_get_int, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{Int32}), ctxt, part_index, name, out)
end

function exr_attr_set_int(ctxt, part_index, name, val)
    ccall((:exr_attr_set_int, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Int32), ctxt, part_index, name, val)
end

function exr_attr_get_keycode(ctxt, part_index, name, out)
    ccall((:exr_attr_get_keycode, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{exr_attr_keycode_t}), ctxt, part_index, name, out)
end

function exr_attr_set_keycode(ctxt, part_index, name, kc)
    ccall((:exr_attr_set_keycode, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Ptr{exr_attr_keycode_t}), ctxt, part_index, name, kc)
end

function exr_attr_get_lineorder(ctxt, part_index, name, out)
    ccall((:exr_attr_get_lineorder, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{exr_lineorder_t}), ctxt, part_index, name, out)
end

function exr_attr_set_lineorder(ctxt, part_index, name, lo)
    ccall((:exr_attr_set_lineorder, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, exr_lineorder_t), ctxt, part_index, name, lo)
end

function exr_attr_get_m33f(ctxt, part_index, name, out)
    ccall((:exr_attr_get_m33f, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{exr_attr_m33f_t}), ctxt, part_index, name, out)
end

function exr_attr_set_m33f(ctxt, part_index, name, m)
    ccall((:exr_attr_set_m33f, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Ptr{exr_attr_m33f_t}), ctxt, part_index, name, m)
end

function exr_attr_get_m33d(ctxt, part_index, name, out)
    ccall((:exr_attr_get_m33d, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{exr_attr_m33d_t}), ctxt, part_index, name, out)
end

function exr_attr_set_m33d(ctxt, part_index, name, m)
    ccall((:exr_attr_set_m33d, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Ptr{exr_attr_m33d_t}), ctxt, part_index, name, m)
end

function exr_attr_get_m44f(ctxt, part_index, name, out)
    ccall((:exr_attr_get_m44f, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{exr_attr_m44f_t}), ctxt, part_index, name, out)
end

function exr_attr_set_m44f(ctxt, part_index, name, m)
    ccall((:exr_attr_set_m44f, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Ptr{exr_attr_m44f_t}), ctxt, part_index, name, m)
end

function exr_attr_get_m44d(ctxt, part_index, name, out)
    ccall((:exr_attr_get_m44d, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{exr_attr_m44d_t}), ctxt, part_index, name, out)
end

function exr_attr_set_m44d(ctxt, part_index, name, m)
    ccall((:exr_attr_set_m44d, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Ptr{exr_attr_m44d_t}), ctxt, part_index, name, m)
end

function exr_attr_get_preview(ctxt, part_index, name, out)
    ccall((:exr_attr_get_preview, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{exr_attr_preview_t}), ctxt, part_index, name, out)
end

function exr_attr_set_preview(ctxt, part_index, name, p)
    ccall((:exr_attr_set_preview, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Ptr{exr_attr_preview_t}), ctxt, part_index, name, p)
end

function exr_attr_get_rational(ctxt, part_index, name, out)
    ccall((:exr_attr_get_rational, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{exr_attr_rational_t}), ctxt, part_index, name, out)
end

function exr_attr_set_rational(ctxt, part_index, name, r)
    ccall((:exr_attr_set_rational, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Ptr{exr_attr_rational_t}), ctxt, part_index, name, r)
end

function exr_attr_get_string(ctxt, part_index, name, length, out)
    ccall((:exr_attr_get_string, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{Int32}, Ptr{Cstring}), ctxt, part_index, name, length, out)
end

function exr_attr_set_string(ctxt, part_index, name, s)
    ccall((:exr_attr_set_string, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Cstring), ctxt, part_index, name, s)
end

function exr_attr_get_string_vector(ctxt, part_index, name, size, out)
    ccall((:exr_attr_get_string_vector, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{Int32}, Ptr{Cstring}), ctxt, part_index, name, size, out)
end

function exr_attr_set_string_vector(ctxt, part_index, name, size, sv)
    ccall((:exr_attr_set_string_vector, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Int32, Ptr{Cstring}), ctxt, part_index, name, size, sv)
end

function exr_attr_get_tiledesc(ctxt, part_index, name, out)
    ccall((:exr_attr_get_tiledesc, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{exr_attr_tiledesc_t}), ctxt, part_index, name, out)
end

function exr_attr_set_tiledesc(ctxt, part_index, name, td)
    ccall((:exr_attr_set_tiledesc, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Ptr{exr_attr_tiledesc_t}), ctxt, part_index, name, td)
end

function exr_attr_get_timecode(ctxt, part_index, name, out)
    ccall((:exr_attr_get_timecode, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{exr_attr_timecode_t}), ctxt, part_index, name, out)
end

function exr_attr_set_timecode(ctxt, part_index, name, tc)
    ccall((:exr_attr_set_timecode, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Ptr{exr_attr_timecode_t}), ctxt, part_index, name, tc)
end

function exr_attr_get_v2i(ctxt, part_index, name, out)
    ccall((:exr_attr_get_v2i, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{exr_attr_v2i_t}), ctxt, part_index, name, out)
end

function exr_attr_set_v2i(ctxt, part_index, name, v)
    ccall((:exr_attr_set_v2i, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Ptr{exr_attr_v2i_t}), ctxt, part_index, name, v)
end

function exr_attr_get_v2f(ctxt, part_index, name, out)
    ccall((:exr_attr_get_v2f, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{exr_attr_v2f_t}), ctxt, part_index, name, out)
end

function exr_attr_set_v2f(ctxt, part_index, name, v)
    ccall((:exr_attr_set_v2f, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Ptr{exr_attr_v2f_t}), ctxt, part_index, name, v)
end

function exr_attr_get_v2d(ctxt, part_index, name, out)
    ccall((:exr_attr_get_v2d, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{exr_attr_v2d_t}), ctxt, part_index, name, out)
end

function exr_attr_set_v2d(ctxt, part_index, name, v)
    ccall((:exr_attr_set_v2d, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Ptr{exr_attr_v2d_t}), ctxt, part_index, name, v)
end

function exr_attr_get_v3i(ctxt, part_index, name, out)
    ccall((:exr_attr_get_v3i, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{exr_attr_v3i_t}), ctxt, part_index, name, out)
end

function exr_attr_set_v3i(ctxt, part_index, name, v)
    ccall((:exr_attr_set_v3i, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Ptr{exr_attr_v3i_t}), ctxt, part_index, name, v)
end

function exr_attr_get_v3f(ctxt, part_index, name, out)
    ccall((:exr_attr_get_v3f, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{exr_attr_v3f_t}), ctxt, part_index, name, out)
end

function exr_attr_set_v3f(ctxt, part_index, name, v)
    ccall((:exr_attr_set_v3f, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Ptr{exr_attr_v3f_t}), ctxt, part_index, name, v)
end

function exr_attr_get_v3d(ctxt, part_index, name, out)
    ccall((:exr_attr_get_v3d, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{exr_attr_v3d_t}), ctxt, part_index, name, out)
end

function exr_attr_set_v3d(ctxt, part_index, name, v)
    ccall((:exr_attr_set_v3d, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Ptr{exr_attr_v3d_t}), ctxt, part_index, name, v)
end

function exr_attr_get_user(ctxt, part_index, name, type, size, out)
    ccall((:exr_attr_get_user, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cstring, Ptr{Cstring}, Ptr{Int32}, Ptr{Ptr{Cvoid}}), ctxt, part_index, name, type, size, out)
end

function exr_attr_set_user(ctxt, part_index, name, type, size, out)
    ccall((:exr_attr_set_user, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cstring, Cstring, Int32, Ptr{Cvoid}), ctxt, part_index, name, type, size, out)
end

function exr_get_chunk_table_offset(ctxt, part_index, chunk_offset_out)
    ccall((:exr_get_chunk_table_offset, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{UInt64}), ctxt, part_index, chunk_offset_out)
end

function exr_chunk_default_initialize(ctxt, part_index, box, levelx, levely, cinfo)
    ccall((:exr_chunk_default_initialize, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Ptr{exr_attr_box2i_t}, Cint, Cint, Ptr{exr_chunk_info_t}), ctxt, part_index, box, levelx, levely, cinfo)
end

function exr_read_scanline_chunk_info(ctxt, part_index, y, cinfo)
    ccall((:exr_read_scanline_chunk_info, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cint, Ptr{exr_chunk_info_t}), ctxt, part_index, y, cinfo)
end

function exr_read_tile_chunk_info(ctxt, part_index, tilex, tiley, levelx, levely, cinfo)
    ccall((:exr_read_tile_chunk_info, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Cint, Cint, Cint, Cint, Ptr{exr_chunk_info_t}), ctxt, part_index, tilex, tiley, levelx, levely, cinfo)
end

function exr_read_chunk(ctxt, part_index, cinfo, packed_data)
    ccall((:exr_read_chunk, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{exr_chunk_info_t}, Ptr{Cvoid}), ctxt, part_index, cinfo, packed_data)
end

function exr_read_deep_chunk(ctxt, part_index, cinfo, packed_data, sample_data)
    ccall((:exr_read_deep_chunk, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{exr_chunk_info_t}, Ptr{Cvoid}, Ptr{Cvoid}), ctxt, part_index, cinfo, packed_data, sample_data)
end

function exr_write_scanline_chunk_info(ctxt, part_index, y, cinfo)
    ccall((:exr_write_scanline_chunk_info, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cint, Ptr{exr_chunk_info_t}), ctxt, part_index, y, cinfo)
end

function exr_write_tile_chunk_info(ctxt, part_index, tilex, tiley, levelx, levely, cinfo)
    ccall((:exr_write_tile_chunk_info, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cint, Cint, Cint, Cint, Ptr{exr_chunk_info_t}), ctxt, part_index, tilex, tiley, levelx, levely, cinfo)
end

function exr_write_scanline_chunk(ctxt, part_index, y, packed_data, packed_size)
    ccall((:exr_write_scanline_chunk, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cint, Ptr{Cvoid}, UInt64), ctxt, part_index, y, packed_data, packed_size)
end

function exr_write_deep_scanline_chunk(ctxt, part_index, y, packed_data, packed_size, unpacked_size, sample_data, sample_data_size)
    ccall((:exr_write_deep_scanline_chunk, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cint, Ptr{Cvoid}, UInt64, UInt64, Ptr{Cvoid}, UInt64), ctxt, part_index, y, packed_data, packed_size, unpacked_size, sample_data, sample_data_size)
end

function exr_write_tile_chunk(ctxt, part_index, tilex, tiley, levelx, levely, packed_data, packed_size)
    ccall((:exr_write_tile_chunk, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cint, Cint, Cint, Cint, Ptr{Cvoid}, UInt64), ctxt, part_index, tilex, tiley, levelx, levely, packed_data, packed_size)
end

function exr_write_deep_tile_chunk(ctxt, part_index, tilex, tiley, levelx, levely, packed_data, packed_size, unpacked_size, sample_data, sample_data_size)
    ccall((:exr_write_deep_tile_chunk, libOpenEXRCore), exr_result_t, (exr_context_t, Cint, Cint, Cint, Cint, Cint, Ptr{Cvoid}, UInt64, UInt64, Ptr{Cvoid}, UInt64), ctxt, part_index, tilex, tiley, levelx, levely, packed_data, packed_size, unpacked_size, sample_data, sample_data_size)
end

function exr_encoding_initialize(ctxt, part_index, cinfo, encode_pipe)
    ccall((:exr_encoding_initialize, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{exr_chunk_info_t}, Ptr{exr_encode_pipeline_t}), ctxt, part_index, cinfo, encode_pipe)
end

function exr_encoding_choose_default_routines(ctxt, part_index, encode_pipe)
    ccall((:exr_encoding_choose_default_routines, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{exr_encode_pipeline_t}), ctxt, part_index, encode_pipe)
end

function exr_encoding_update(ctxt, part_index, cinfo, encode_pipe)
    ccall((:exr_encoding_update, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{exr_chunk_info_t}, Ptr{exr_encode_pipeline_t}), ctxt, part_index, cinfo, encode_pipe)
end

function exr_encoding_run(ctxt, part_index, encode_pipe)
    ccall((:exr_encoding_run, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{exr_encode_pipeline_t}), ctxt, part_index, encode_pipe)
end

function exr_encoding_destroy(ctxt, encode_pipe)
    ccall((:exr_encoding_destroy, libOpenEXRCore), exr_result_t, (exr_const_context_t, Ptr{exr_encode_pipeline_t}), ctxt, encode_pipe)
end

function exr_decoding_initialize(ctxt, part_index, cinfo, decode)
    ccall((:exr_decoding_initialize, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{exr_chunk_info_t}, Ptr{exr_decode_pipeline_t}), ctxt, part_index, cinfo, decode)
end

function exr_decoding_choose_default_routines(ctxt, part_index, decode)
    ccall((:exr_decoding_choose_default_routines, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{exr_decode_pipeline_t}), ctxt, part_index, decode)
end

function exr_decoding_update(ctxt, part_index, cinfo, decode)
    ccall((:exr_decoding_update, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{exr_chunk_info_t}, Ptr{exr_decode_pipeline_t}), ctxt, part_index, cinfo, decode)
end

function exr_decoding_run(ctxt, part_index, decode)
    ccall((:exr_decoding_run, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{exr_decode_pipeline_t}), ctxt, part_index, decode)
end

function exr_decoding_destroy(ctxt, decode)
    ccall((:exr_decoding_destroy, libOpenEXRCore), exr_result_t, (exr_const_context_t, Ptr{exr_decode_pipeline_t}), ctxt, decode)
end

function exr_compress_max_buffer_size(in_bytes)
    ccall((:exr_compress_max_buffer_size, libOpenEXRCore), Csize_t, (Csize_t,), in_bytes)
end

function exr_compress_buffer(ctxt, level, in, in_bytes, out, out_bytes_avail, actual_out)
    ccall((:exr_compress_buffer, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint, Ptr{Cvoid}, Csize_t, Ptr{Cvoid}, Csize_t, Ptr{Csize_t}), ctxt, level, in, in_bytes, out, out_bytes_avail, actual_out)
end

function exr_uncompress_buffer(ctxt, in, in_bytes, out, out_bytes_avail, actual_out)
    ccall((:exr_uncompress_buffer, libOpenEXRCore), exr_result_t, (exr_const_context_t, Ptr{Cvoid}, Csize_t, Ptr{Cvoid}, Csize_t, Ptr{Csize_t}), ctxt, in, in_bytes, out, out_bytes_avail, actual_out)
end

function exr_rle_compress_buffer(in_bytes, in, out, out_bytes_avail)
    ccall((:exr_rle_compress_buffer, libOpenEXRCore), Csize_t, (Csize_t, Ptr{Cvoid}, Ptr{Cvoid}, Csize_t), in_bytes, in, out, out_bytes_avail)
end

function exr_rle_uncompress_buffer(in_bytes, max_len, in, out)
    ccall((:exr_rle_uncompress_buffer, libOpenEXRCore), Csize_t, (Csize_t, Csize_t, Ptr{Cvoid}, Ptr{Cvoid}), in_bytes, max_len, in, out)
end

function exr_compression_lines_per_chunk(comptype)
    ccall((:exr_compression_lines_per_chunk, libOpenEXRCore), Cint, (exr_compression_t,), comptype)
end

function exr_compress_chunk(encode_state)
    ccall((:exr_compress_chunk, libOpenEXRCore), exr_result_t, (Ptr{exr_encode_pipeline_t},), encode_state)
end

function exr_uncompress_chunk(decode_state)
    ccall((:exr_uncompress_chunk, libOpenEXRCore), exr_result_t, (Ptr{exr_decode_pipeline_t},), decode_state)
end

function exr_print_context_info(c, verbose)
    ccall((:exr_print_context_info, libOpenEXRCore), exr_result_t, (exr_const_context_t, Cint), c, verbose)
end
