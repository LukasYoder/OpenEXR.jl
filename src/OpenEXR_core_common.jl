# Automatically generated using Clang.jl
using CEnum


# Skipping MacroDefinition: EXR_PRINTF_FUNC_ATTRIBUTE __attribute__ ( ( format ( printf , 3 , 4 ) ) )

const EXR_CONTEXT_FLAG_STRICT_HEADER = 1 << 0
const EXR_CONTEXT_FLAG_SILENT_HEADER_PARSE = 1 << 1
const EXR_CONTEXT_FLAG_DISABLE_CHUNK_RECONSTRUCTION = 1 << 2
const EXR_CONTEXT_FLAG_WRITE_LEGACY_HEADER = 1 << 3

# Skipping MacroDefinition: EXR_DEFAULT_CONTEXT_INITIALIZER { sizeof ( exr_context_initializer_t ) , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , - 2 , - 1.f , 0 , { 0 , 0 , 0 , 0 } }
# Skipping MacroDefinition: EXR_GET_TILE_LEVEL_MODE ( tiledesc ) ( ( exr_tile_level_mode_t ) ( ( ( tiledesc ) . level_and_round ) & 0xF ) )
# Skipping MacroDefinition: EXR_GET_TILE_ROUND_MODE ( tiledesc ) ( ( exr_tile_round_mode_t ) ( ( ( ( tiledesc ) . level_and_round ) >> 4 ) & 0xF ) )
# Skipping MacroDefinition: EXR_PACK_TILE_LEVEL_ROUND ( lvl , mode ) ( ( uint8_t ) ( ( ( ( uint8_t ) ( ( mode ) & 0xF ) << 4 ) ) | ( ( uint8_t ) ( ( lvl ) & 0xF ) ) ) )
# Skipping MacroDefinition: EXR_ENCODE_DATA_SAMPLE_COUNTS_ARE_INDIVIDUAL ( ( uint16_t ) ( 1 << 0 ) )
# Skipping MacroDefinition: EXR_ENCODE_NON_IMAGE_DATA_AS_POINTERS ( ( uint16_t ) ( 1 << 1 ) )
# Skipping MacroDefinition: EXR_ENCODE_PIPELINE_INITIALIZER { sizeof ( exr_encode_pipeline_t ) , 0 }
# Skipping MacroDefinition: EXR_DECODE_SAMPLE_COUNTS_AS_INDIVIDUAL ( ( uint16_t ) ( 1 << 0 ) )
# Skipping MacroDefinition: EXR_DECODE_NON_IMAGE_DATA_AS_POINTERS ( ( uint16_t ) ( 1 << 1 ) )
# Skipping MacroDefinition: EXR_DECODE_SAMPLE_DATA_ONLY ( ( uint16_t ) ( 1 << 2 ) )
# Skipping MacroDefinition: EXR_DECODE_PIPELINE_INITIALIZER { sizeof ( exr_decode_pipeline_t ) , 0 }

const exr_memory_allocation_func_t = Ptr{Cvoid}
const exr_memory_free_func_t = Ptr{Cvoid}

@cenum exr_error_code_t::UInt32 begin
    EXR_ERR_SUCCESS = 0
    EXR_ERR_OUT_OF_MEMORY = 1
    EXR_ERR_MISSING_CONTEXT_ARG = 2
    EXR_ERR_INVALID_ARGUMENT = 3
    EXR_ERR_ARGUMENT_OUT_OF_RANGE = 4
    EXR_ERR_FILE_ACCESS = 5
    EXR_ERR_FILE_BAD_HEADER = 6
    EXR_ERR_NOT_OPEN_READ = 7
    EXR_ERR_NOT_OPEN_WRITE = 8
    EXR_ERR_HEADER_NOT_WRITTEN = 9
    EXR_ERR_READ_IO = 10
    EXR_ERR_WRITE_IO = 11
    EXR_ERR_NAME_TOO_LONG = 12
    EXR_ERR_MISSING_REQ_ATTR = 13
    EXR_ERR_INVALID_ATTR = 14
    EXR_ERR_NO_ATTR_BY_NAME = 15
    EXR_ERR_ATTR_TYPE_MISMATCH = 16
    EXR_ERR_ATTR_SIZE_MISMATCH = 17
    EXR_ERR_SCAN_TILE_MIXEDAPI = 18
    EXR_ERR_TILE_SCAN_MIXEDAPI = 19
    EXR_ERR_MODIFY_SIZE_CHANGE = 20
    EXR_ERR_ALREADY_WROTE_ATTRS = 21
    EXR_ERR_BAD_CHUNK_LEADER = 22
    EXR_ERR_CORRUPT_CHUNK = 23
    EXR_ERR_INCOMPLETE_CHUNK_TABLE = 24
    EXR_ERR_INCORRECT_PART = 25
    EXR_ERR_INCORRECT_CHUNK = 26
    EXR_ERR_USE_SCAN_DEEP_WRITE = 27
    EXR_ERR_USE_TILE_DEEP_WRITE = 28
    EXR_ERR_USE_SCAN_NONDEEP_WRITE = 29
    EXR_ERR_USE_TILE_NONDEEP_WRITE = 30
    EXR_ERR_INVALID_SAMPLE_DATA = 31
    EXR_ERR_FEATURE_NOT_IMPLEMENTED = 32
    EXR_ERR_UNKNOWN = 33
end


const exr_result_t = Int32
const _priv_exr_context_t = Cvoid
const exr_context_t = Ptr{_priv_exr_context_t}
const exr_const_context_t = Ptr{_priv_exr_context_t}
const exr_stream_error_func_ptr_t = Ptr{Cvoid}
const exr_error_handler_cb_t = Ptr{Cvoid}
const exr_destroy_stream_func_ptr_t = Ptr{Cvoid}
const exr_query_size_func_ptr_t = Ptr{Cvoid}
const exr_read_func_ptr_t = Ptr{Cvoid}
const exr_write_func_ptr_t = Ptr{Cvoid}

mutable struct _exr_context_initializer_v3
    size::Csize_t
    error_handler_fn::exr_error_handler_cb_t
    alloc_fn::exr_memory_allocation_func_t
    free_fn::exr_memory_free_func_t
    user_data::Ptr{Cvoid}
    read_fn::exr_read_func_ptr_t
    size_fn::exr_query_size_func_ptr_t
    write_fn::exr_write_func_ptr_t
    destroy_fn::exr_destroy_stream_func_ptr_t
    max_image_width::Cint
    max_image_height::Cint
    max_tile_width::Cint
    max_tile_height::Cint
    zip_level::Cint
    dwa_quality::Cfloat
    flags::Cint
    pad::NTuple{4, UInt8}
end

const exr_context_initializer_t = _exr_context_initializer_v3

@cenum exr_default_write_mode::UInt32 begin
    EXR_WRITE_FILE_DIRECTLY = 0
    EXR_INTERMEDIATE_TEMP_FILE = 1
end


const exr_default_write_mode_t = exr_default_write_mode

@cenum exr_compression_t::UInt32 begin
    EXR_COMPRESSION_NONE = 0
    EXR_COMPRESSION_RLE = 1
    EXR_COMPRESSION_ZIPS = 2
    EXR_COMPRESSION_ZIP = 3
    EXR_COMPRESSION_PIZ = 4
    EXR_COMPRESSION_PXR24 = 5
    EXR_COMPRESSION_B44 = 6
    EXR_COMPRESSION_B44A = 7
    EXR_COMPRESSION_DWAA = 8
    EXR_COMPRESSION_DWAB = 9
    EXR_COMPRESSION_HTJ2K256 = 10
    EXR_COMPRESSION_HTJ2K32 = 11
    EXR_COMPRESSION_LAST_TYPE = 12
end

@cenum exr_envmap_t::UInt32 begin
    EXR_ENVMAP_LATLONG = 0
    EXR_ENVMAP_CUBE = 1
    EXR_ENVMAP_LAST_TYPE = 2
end

@cenum exr_lineorder_t::UInt32 begin
    EXR_LINEORDER_INCREASING_Y = 0
    EXR_LINEORDER_DECREASING_Y = 1
    EXR_LINEORDER_RANDOM_Y = 2
    EXR_LINEORDER_LAST_TYPE = 3
end

@cenum exr_storage_t::UInt32 begin
    EXR_STORAGE_SCANLINE = 0
    EXR_STORAGE_TILED = 1
    EXR_STORAGE_DEEP_SCANLINE = 2
    EXR_STORAGE_DEEP_TILED = 3
    EXR_STORAGE_LAST_TYPE = 4
    EXR_STORAGE_UNKNOWN = 5
end

@cenum exr_tile_level_mode_t::UInt32 begin
    EXR_TILE_ONE_LEVEL = 0
    EXR_TILE_MIPMAP_LEVELS = 1
    EXR_TILE_RIPMAP_LEVELS = 2
    EXR_TILE_LAST_TYPE = 3
end

@cenum exr_tile_round_mode_t::UInt32 begin
    EXR_TILE_ROUND_DOWN = 0
    EXR_TILE_ROUND_UP = 1
    EXR_TILE_ROUND_LAST_TYPE = 2
end

@cenum exr_pixel_type_t::UInt32 begin
    EXR_PIXEL_UINT = 0
    EXR_PIXEL_HALF = 1
    EXR_PIXEL_FLOAT = 2
    EXR_PIXEL_LAST_TYPE = 3
end

@cenum exr_deep_image_state_t::UInt32 begin
    EXR_DIS_MESSY = 0
    EXR_DIS_SORTED = 1
    EXR_DIS_NON_OVERLAPPING = 2
    EXR_DIS_TIDY = 3
    EXR_DIS_LAST_TYPE = 4
end


mutable struct exr_attr_chromaticities_t
    red_x::Cfloat
    red_y::Cfloat
    green_x::Cfloat
    green_y::Cfloat
    blue_x::Cfloat
    blue_y::Cfloat
    white_x::Cfloat
    white_y::Cfloat
end

mutable struct exr_attr_keycode_t
    film_mfc_code::Int32
    film_type::Int32
    prefix::Int32
    count::Int32
    perf_offset::Int32
    perfs_per_frame::Int32
    perfs_per_count::Int32
end

mutable struct exr_attr_m33f_t
    m::NTuple{9, Cfloat}
end

mutable struct exr_attr_m33d_t
    m::NTuple{9, Cdouble}
end

mutable struct exr_attr_m44f_t
    m::NTuple{16, Cfloat}
end

mutable struct exr_attr_m44d_t
    m::NTuple{16, Cdouble}
end

mutable struct exr_attr_rational_t
    num::Int32
    denom::UInt32
end

mutable struct exr_attr_timecode_t
    time_and_flags::UInt32
    user_data::UInt32
end

mutable struct exr_attr_v2i_t
    x::Int32
    y::Int32
end

mutable struct exr_attr_v2f_t
    x::Cfloat
    y::Cfloat
end

mutable struct exr_attr_v2d_t
    x::Cdouble
    y::Cdouble
end

mutable struct exr_attr_v3i_t
    x::Int32
    y::Int32
    z::Int32
end

mutable struct exr_attr_v3f_t
    x::Cfloat
    y::Cfloat
    z::Cfloat
end

mutable struct exr_attr_v3d_t
    x::Cdouble
    y::Cdouble
    z::Cdouble
end

mutable struct exr_attr_box2i_t
    min::exr_attr_v2i_t
    max::exr_attr_v2i_t
end

mutable struct exr_attr_box2f_t
    min::exr_attr_v2f_t
    max::exr_attr_v2f_t
end

mutable struct exr_attr_tiledesc_t
    x_size::UInt32
    y_size::UInt32
    level_and_round::UInt8
end

mutable struct exr_attr_string_t
    length::Int32
    alloc_size::Int32
    str::Cstring
end

mutable struct exr_attr_string_vector_t
    n_strings::Int32
    alloc_size::Int32
    strings::Ptr{exr_attr_string_t}
end

mutable struct exr_attr_float_vector_t
    length::Int32
    alloc_size::Int32
    arr::Ptr{Cfloat}
end

@cenum exr_perceptual_treatment_t::UInt32 begin
    EXR_PERCEPTUALLY_LOGARITHMIC = 0
    EXR_PERCEPTUALLY_LINEAR = 1
end


mutable struct exr_attr_chlist_entry_t
    name::exr_attr_string_t
    pixel_type::exr_pixel_type_t
    p_linear::UInt8
    reserved::NTuple{3, UInt8}
    x_sampling::Int32
    y_sampling::Int32
end

mutable struct exr_attr_chlist_t
    num_channels::Cint
    num_alloced::Cint
    entries::Ptr{exr_attr_chlist_entry_t}
end

mutable struct exr_attr_preview_t
    width::UInt32
    height::UInt32
    alloc_size::Csize_t
    rgba::Ptr{UInt8}
end

mutable struct exr_attr_bytes_t
    size::Csize_t
    data::Ptr{UInt8}
    hint_length::UInt32
    type_hint::Cstring
end

mutable struct exr_attr_opaquedata_t
    size::Int32
    unpacked_size::Int32
    packed_alloc_size::Int32
    pad::NTuple{4, UInt8}
    packed_data::Ptr{Cvoid}
    unpacked_data::Ptr{Cvoid}
    unpack_func_ptr::Ptr{Cvoid}
    pack_func_ptr::Ptr{Cvoid}
    destroy_unpacked_func_ptr::Ptr{Cvoid}
end

@cenum exr_attribute_type_t::UInt32 begin
    EXR_ATTR_UNKNOWN = 0
    EXR_ATTR_BOX2I = 1
    EXR_ATTR_BOX2F = 2
    EXR_ATTR_BYTES = 3
    EXR_ATTR_CHLIST = 4
    EXR_ATTR_CHROMATICITIES = 5
    EXR_ATTR_COMPRESSION = 6
    EXR_ATTR_DOUBLE = 7
    EXR_ATTR_ENVMAP = 8
    EXR_ATTR_FLOAT = 9
    EXR_ATTR_FLOAT_VECTOR = 10
    EXR_ATTR_INT = 11
    EXR_ATTR_KEYCODE = 12
    EXR_ATTR_LINEORDER = 13
    EXR_ATTR_M33F = 14
    EXR_ATTR_M33D = 15
    EXR_ATTR_M44F = 16
    EXR_ATTR_M44D = 17
    EXR_ATTR_PREVIEW = 18
    EXR_ATTR_RATIONAL = 19
    EXR_ATTR_STRING = 20
    EXR_ATTR_STRING_VECTOR = 21
    EXR_ATTR_TILEDESC = 22
    EXR_ATTR_TIMECODE = 23
    EXR_ATTR_V2I = 24
    EXR_ATTR_V2F = 25
    EXR_ATTR_V2D = 26
    EXR_ATTR_V3I = 27
    EXR_ATTR_V3F = 28
    EXR_ATTR_V3D = 29
    EXR_ATTR_DEEP_IMAGE_STATE = 30
    EXR_ATTR_OPAQUE = 31
    EXR_ATTR_LAST_KNOWN_TYPE = 32
end


mutable struct exr_attribute_t
    name::Cstring
    type_name::Cstring
    name_length::UInt8
    type_name_length::UInt8
    pad::NTuple{2, UInt8}
    type::exr_attribute_type_t
end

@cenum exr_attr_list_access_mode::UInt32 begin
    EXR_ATTR_LIST_FILE_ORDER = 0
    EXR_ATTR_LIST_SORTED_ORDER = 1
end


const exr_attr_list_access_mode_t = exr_attr_list_access_mode

mutable struct exr_chunk_info_t
    idx::Int32
    start_x::Int32
    start_y::Int32
    height::Int32
    width::Int32
    level_x::UInt8
    level_y::UInt8
    type::UInt8
    compression::UInt8
    data_offset::UInt64
    packed_size::UInt64
    unpacked_size::UInt64
    sample_count_data_offset::UInt64
    sample_count_table_size::UInt64
end

@cenum exr_transcoding_pipeline_buffer_id::UInt32 begin
    EXR_TRANSCODE_BUFFER_PACKED = 0
    EXR_TRANSCODE_BUFFER_UNPACKED = 1
    EXR_TRANSCODE_BUFFER_COMPRESSED = 2
    EXR_TRANSCODE_BUFFER_SCRATCH1 = 3
    EXR_TRANSCODE_BUFFER_SCRATCH2 = 4
    EXR_TRANSCODE_BUFFER_PACKED_SAMPLES = 5
    EXR_TRANSCODE_BUFFER_SAMPLES = 6
end


const exr_transcoding_pipeline_buffer_id_t = exr_transcoding_pipeline_buffer_id

mutable struct exr_coding_channel_info_t
    channel_name::Cstring
    height::Int32
    width::Int32
    x_samples::Int32
    y_samples::Int32
    p_linear::UInt8
    bytes_per_element::Int8
    data_type::UInt16
    user_bytes_per_element::Int16
    user_data_type::UInt16
    user_pixel_stride::Int32
    user_line_stride::Int32
    # Trailing anonymous union from the C header (decode_to_ptr / encode_from_ptr).
    # Patched in post-process because Clang.jl drops anonymous union members.
    user_ptr::Ptr{UInt8}
end

const _exr_chunk_info_storage_t = NTuple{sizeof(exr_chunk_info_t), UInt8}
const _exr_quick_channel_store_t = NTuple{5 * sizeof(exr_coding_channel_info_t), UInt8}

mutable struct _exr_encode_pipeline
    pipe_size::Csize_t
    channels::Ptr{exr_coding_channel_info_t}
    channel_count::Int16
    encode_flags::UInt16
    part_index::Cint
    context::exr_const_context_t
    chunk::_exr_chunk_info_storage_t
    encoding_user_data::Ptr{Cvoid}
    packed_buffer::Ptr{Cvoid}
    packed_bytes::UInt64
    packed_alloc_size::Csize_t
    sample_count_table::Ptr{Int32}
    sample_count_alloc_size::Csize_t
    packed_sample_count_table::Ptr{Cvoid}
    packed_sample_count_bytes::Csize_t
    packed_sample_count_alloc_size::Csize_t
    compressed_buffer::Ptr{Cvoid}
    compressed_bytes::Csize_t
    compressed_alloc_size::Csize_t
    scratch_buffer_1::Ptr{Cvoid}
    scratch_alloc_size_1::Csize_t
    scratch_buffer_2::Ptr{Cvoid}
    scratch_alloc_size_2::Csize_t
    alloc_fn::Ptr{Cvoid}
    free_fn::Ptr{Cvoid}
    convert_and_pack_fn::Ptr{Cvoid}
    compress_fn::Ptr{Cvoid}
    yield_until_ready_fn::Ptr{Cvoid}
    write_fn::Ptr{Cvoid}
    _quick_chan_store::_exr_quick_channel_store_t
end

const exr_encode_pipeline_t = _exr_encode_pipeline

mutable struct _exr_decode_pipeline
    pipe_size::Csize_t
    channels::Ptr{exr_coding_channel_info_t}
    channel_count::Int16
    decode_flags::UInt16
    part_index::Cint
    context::exr_const_context_t
    chunk::_exr_chunk_info_storage_t
    user_line_begin_skip::Int32
    user_line_end_ignore::Int32
    bytes_decompressed::UInt64
    decoding_user_data::Ptr{Cvoid}
    packed_buffer::Ptr{Cvoid}
    packed_alloc_size::Csize_t
    unpacked_buffer::Ptr{Cvoid}
    unpacked_alloc_size::Csize_t
    packed_sample_count_table::Ptr{Cvoid}
    packed_sample_count_alloc_size::Csize_t
    sample_count_table::Ptr{Int32}
    sample_count_alloc_size::Csize_t
    scratch_buffer_1::Ptr{Cvoid}
    scratch_alloc_size_1::Csize_t
    scratch_buffer_2::Ptr{Cvoid}
    scratch_alloc_size_2::Csize_t
    alloc_fn::Ptr{Cvoid}
    free_fn::Ptr{Cvoid}
    read_fn::Ptr{Cvoid}
    decompress_fn::Ptr{Cvoid}
    realloc_nonimage_data_fn::Ptr{Cvoid}
    unpack_and_convert_fn::Ptr{Cvoid}
    _quick_chan_store::_exr_quick_channel_store_t
end

const exr_decode_pipeline_t = _exr_decode_pipeline
