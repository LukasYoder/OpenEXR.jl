using Clang
using OpenEXR_jll

const OPENEXR_INCLUDE = joinpath(OpenEXR_jll.artifact_dir, "include", "OpenEXR") |> normpath
const OPENEXR_HEADERS = [joinpath(OPENEXR_INCLUDE, "ImfCRgbaFile.h")]

# create a work context
ctx = DefaultContext()

# parse headers
parse_headers!(ctx, OPENEXR_HEADERS,
               args=["-I", joinpath(OPENEXR_INCLUDE, "..")],
               includes=vcat(OPENEXR_INCLUDE, CLANG_INCLUDE),
               )

# settings
ctx.libname = "libOpenEXR"
ctx.options["is_function_strictly_typed"] = false
ctx.options["is_struct_mutable"] = false

# write output
api_file = joinpath(@__DIR__, "..", "src", "OpenEXR_api.jl")
api_stream = open(api_file, "w")

for trans_unit in ctx.trans_units
    root_cursor = getcursor(trans_unit)
    push!(ctx.cursor_stack, root_cursor)
    header = spelling(root_cursor)
    @info "wrapping header: $header ..."
    # loop over all of the child cursors and wrap them, if appropriate.
    ctx.children = children(root_cursor)
    for (i, child) in enumerate(ctx.children)
        child_name = name(child)
        child_header = filename(child)
        ctx.children_index = i
        # choose which cursor to wrap
        startswith(child_name, "__") && continue  # skip compiler definitions
        child_name in keys(ctx.common_buffer) && continue  # already wrapped
        child_header != header && continue  # skip if cursor filename is not in the headers to be wrapped

        wrap!(ctx, child)
    end
    @info "writing $(api_file)"
    println(api_stream, "# Julia wrapper for header: $(basename(header))")
    println(api_stream, "# Automatically generated using Clang.jl\n")
    print_buffer(api_stream, ctx.api_buffer)
    empty!(ctx.api_buffer)  # clean up api_buffer for the next header
end
close(api_stream)

# Remove definition of ImfHalf. We will define it as Float16 instead of UInt16.
pop!(ctx.common_buffer, :ImfHalf)

# Remove definition of ImfRgba. We will define it as RGBA{ImfHalf}.
pop!(ctx.common_buffer, :ImfRgba)

# Remove definition of IMF_WRITE_RGBA. It isn't correct.
pop!(ctx.common_buffer, :IMF_WRITE_RGBA)

# Write "common" definitions: types, typealiases, etc.
common_file = joinpath(@__DIR__, "..", "src", "OpenEXR_common.jl")
open(common_file, "w") do f
    println(f, "# Automatically generated using Clang.jl\n")
    print_buffer(f, dump_to_buffer(ctx.common_buffer))
end

# ============================================================
# Core C API (libOpenEXRCore) — modern arbitrary-channel I/O
# ============================================================

const OPENEXR_CORE_HEADERS = [joinpath(OPENEXR_INCLUDE, "openexr.h")]

ctx_core = DefaultContext()

parse_headers!(ctx_core, OPENEXR_CORE_HEADERS,
               args=["-I", joinpath(OPENEXR_INCLUDE, "..")],
               includes=vcat(OPENEXR_INCLUDE, CLANG_INCLUDE),
               )

ctx_core.libname = "libOpenEXRCore"
ctx_core.options["is_function_strictly_typed"] = false
ctx_core.options["is_struct_mutable"] = true  # mutable so pipe_size etc. can be set

core_api_file = joinpath(@__DIR__, "..", "src", "OpenEXR_core_api.jl")
core_api_stream = open(core_api_file, "w")

for trans_unit in ctx_core.trans_units
    root_cursor = getcursor(trans_unit)
    push!(ctx_core.cursor_stack, root_cursor)
    header = spelling(root_cursor)
    @info "wrapping header: $header ..."
    ctx_core.children = children(root_cursor)
    for (i, child) in enumerate(ctx_core.children)
        child_name = name(child)
        child_header = filename(child)
        ctx_core.children_index = i
        startswith(child_name, "__") && continue
        child_name in keys(ctx_core.common_buffer) && continue
        # Accept symbols from any openexr_*.h header (umbrella header pulls them in).
        startswith(basename(child_header), "openexr") || continue
        wrap!(ctx_core, child)
    end
    @info "writing $(core_api_file)"
    println(core_api_stream, "# Julia wrapper for header: $(basename(header))")
    println(core_api_stream, "# Automatically generated using Clang.jl\n")
    print_buffer(core_api_stream, ctx_core.api_buffer)
    empty!(ctx_core.api_buffer)
end
close(core_api_stream)

# Remove EXR_EXPORT -- it is a C visibility-attribute macro (defined as
# `#define EXR_EXPORT OPENEXR_EXPORT` in openexr_conf.h), not a value. Clang.jl
# translates the #define into `const EXR_EXPORT = OPENEXR_EXPORT`, which then
# fails to load because `OPENEXR_EXPORT` itself is a stripped C macro with no
# Julia counterpart. The symbol has no meaningful translation in Julia and is
# never referenced by any auto-generated function signature.
haskey(ctx_core.common_buffer, :EXR_EXPORT) && pop!(ctx_core.common_buffer, :EXR_EXPORT)

# Write Core common file. The Core headers use C enums (which Clang.jl emits via
# CEnum.jl's `@cenum` macro), so prepend `using CEnum` so the file loads. The
# legacy ImfCRgbaFile.h headers contain only `#define`s and need no such import.
core_common_file = joinpath(@__DIR__, "..", "src", "OpenEXR_core_common.jl")
open(core_common_file, "w") do f
    println(f, "# Automatically generated using Clang.jl")
    println(f, "using CEnum\n")
    print_buffer(f, dump_to_buffer(ctx_core.common_buffer))
end

# ------------------------------------------------------------
# Post-process patch: inject the trailing anonymous union pointer field that
# Clang.jl drops from `exr_coding_channel_info_t`. The upstream C struct ends
# with `union { uint8_t* decode_to_ptr; const uint8_t* encode_from_ptr; }`,
# but Clang.jl emits the struct without that union -- the resulting Julia
# struct is 40 bytes instead of the correct 48, and there is no way to set
# the encode source pointer or read destination pointer from Julia.
#
# We add a single `user_ptr::Ptr{UInt8}` field at the tail. C uses the same
# 8-byte slot for both decode_to_ptr and encode_from_ptr (it is a union), and
# we expose them as the same Julia field with helper accessors in the
# high-level layer. Root-cause fix would be patching Clang.jl's anonymous-
# union handling; this localized post-process keeps the generator output
# correct and stable in the meantime.
let text = read(core_common_file, String)
    original = """mutable struct exr_coding_channel_info_t
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
end"""
    patched = """mutable struct exr_coding_channel_info_t
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
end"""
    occursin(original, text) ||
        error("post-process patch failed: exr_coding_channel_info_t shape changed; \
               regenerate this file with current Clang.jl and update the patch.")
    write(core_common_file, replace(text, original => patched))
end

# Post-process patch: Clang.jl emits nested mutable struct fields in the
# versioned encode/decode pipeline structs. Julia stores mutable struct fields
# as object references when they are embedded in another Julia struct, but the
# OpenEXRCore C layout stores `exr_chunk_info_t chunk` and
# `exr_coding_channel_info_t _quick_chan_store[5]` inline. If these regions are
# left as nested mutable fields, `sizeof(exr_encode_pipeline_t)` and
# `sizeof(exr_decode_pipeline_t)` are too small, and OpenEXRCore writes past the
# Julia buffer during `exr_encoding_initialize` / `exr_decoding_initialize`.
#
# The high-level code never reads the embedded `chunk` or quick channel store
# through the pipeline object; it only reads scalar fields such as `channels`
# and `channel_count`. Represent those C-only inline regions as raw byte tuples
# so Julia reserves the correct storage while preserving the fields we use.
let text = read(core_common_file, String)
    function replace_exactly(text, old, new, expected_count, label)
        count = 0
        position = firstindex(text)
        while true
            range = findnext(old, text, position)
            range === nothing && break
            count += 1
            position = nextind(text, last(range))
        end
        count == expected_count ||
            error("post-process patch failed: expected $expected_count $label \
                   replacement(s), found $count; regenerate this file with \
                   current Clang.jl and update the patch.")
        return replace(text, old => new)
    end

    original = """end

mutable struct _exr_encode_pipeline"""
    patched = """end

const _exr_chunk_info_storage_t = NTuple{sizeof(exr_chunk_info_t), UInt8}
const _exr_quick_channel_store_t = NTuple{5 * sizeof(exr_coding_channel_info_t), UInt8}

mutable struct _exr_encode_pipeline"""
    occursin(original, text) ||
        error("post-process patch failed: pipeline storage insertion point changed; \
               regenerate this file with current Clang.jl and update the patch.")
    text = replace(text, original => patched)
    text = replace_exactly(
        text,
        "    chunk::exr_chunk_info_t",
        "    chunk::_exr_chunk_info_storage_t",
        2,
        "pipeline chunk storage",
    )
    text = replace_exactly(
        text,
        "    _quick_chan_store::NTuple{5, exr_coding_channel_info_t}",
        "    _quick_chan_store::_exr_quick_channel_store_t",
        2,
        "pipeline quick channel storage",
    )
    write(core_common_file, text)
end
