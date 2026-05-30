# src/exr_file.jl
# Catch-all type for arbitrary EXR files. Used for: renderer/VFX outputs
# (RGB + Z + N + AOVs), Cryptomatte mattes, multi-part files, custom
# channel sets, and "inspect-before-decide" workflows.
#
# If you have spectral imaging data, use SpectralCube.
# If you have a standard color image, use load(path) (auto-detect returns
# Array{<:Color, 2}).
# Use ExrFile only when neither applies.

"""
    ExrPart

A single part of an EXR file. A standard single-part file has one
ExrPart; multi-part files have several.

Reserved attribute Dict exclusion rule: an ExrPart's `compression`,
`storage`, and `tile_size` are stored exclusively as struct fields,
never duplicated into `attributes`.
"""
struct ExrPart
    name::String
    channels::Dict{String, AbstractArray}
    attributes::Dict{String, Any}
    dimensions::NTuple{2, Int}              # (width, height)
    storage::Symbol                         # :scanline or :tiled
    tile_size::Union{Nothing, NTuple{2, Int}}
    compression::Symbol                     # :none, :rle, :zip, :zips, :piz, :pxr24, :b44, :b44a, :dwaa, :dwab
end

"""
    ExrFile

Generic EXR file representation. Use this type for arbitrary EXR files
that aren't standard Colors images and aren't SpectralCubes. Examples:

- **Renderer/VFX outputs**: RGB combined with Z (depth), N (normal
  vectors), object IDs, motion vectors, custom AOVs.
- **Multi-part EXR files**: e.g., one part RGB, another part depth map.
- **Cryptomatte mattes**: compositor workflows that store hashed object
  IDs across many channels.
- **Files with arbitrary user-defined channel sets**.
- **"Inspect what's in this file before deciding how to handle it"**
  workflows.

Construct from a path: `ExrFile(path)` or `OpenEXR.load(path, ExrFile)`.

For single-part files, the convenience accessors
`.channels`, `.attributes`, `.dimensions`, `.compression`, `.storage`,
`.tile_size` delegate to `parts[1]`. For multi-part files, those
accessors throw a clear error pointing the user at `parts[i]`.
"""
struct ExrFile
    parts::Vector{ExrPart}
end

# Convenience accessors for single-part files
function Base.getproperty(exr::ExrFile, name::Symbol)
    if name === :parts
        return getfield(exr, :parts)
    end
    parts = getfield(exr, :parts)
    if length(parts) > 1
        throw(ArgumentError(
            "ExrFile has $(length(parts)) parts; the convenience accessor " *
            "`exr.$name` is only valid for single-part files. " *
            "Use `exr.parts[i].$name` instead."))
    end
    length(parts) == 0 && throw(ArgumentError("ExrFile has no parts"))
    return getproperty(parts[1], name)
end

# Path-based constructor convenience.
ExrFile(path::AbstractString) = load(path, ExrFile)


# ---------------------------------------------------------------------------
# Compression compatibility rules for ExrFile (more permissive than
# SpectralCube — lossy compressions are allowed when the per-channel pixel
# type permits).
# ---------------------------------------------------------------------------

# All compression symbols accepted by ExrFile (the full EXR set).
const _ALL_EXR_COMPRESSIONS = (
    :none, :rle, :zip, :zips, :piz, :pxr24, :b44, :b44a, :dwaa, :dwab,
)

# Validate that the given compression symbol is compatible with the set of
# per-channel pixel types in this part. EXR's lossy compressions have
# narrowing pixel-type compatibility — `:b44` / `:b44a` require Float16
# channels; `:dwaa` / `:dwab` require Float16 or Float32 channels.
# `:pxr24` is permitted for all native types (lossy for Float32, lossless
# for Float16/UInt32). Lossless compressions (`:none`, `:rle`, `:zip`,
# `:zips`, `:piz`) are unconstrained.
function _validate_exr_file_compression(compression::Symbol,
                                        channels::AbstractDict{String, <:AbstractArray})
    compression in _ALL_EXR_COMPRESSIONS || throw(ArgumentError(
        "unknown compression $(repr(compression)); valid values are " *
        "$(_ALL_EXR_COMPRESSIONS)"))

    # Per-channel pixel-type compatibility checks. We compute the on-disk
    # pixel type per channel via the same _exr_pixel_type mapping the
    # SpectralCube path uses (so UInt16/UInt8 promote to UInt32, Float64
    # is rejected).
    if compression === :b44 || compression === :b44a
        for (name, arr) in channels
            _, on_disk_T = _exr_pixel_type(eltype(arr))
            on_disk_T === Float16 || throw(ArgumentError(
                "compression $(repr(compression)) requires Float16 channels; " *
                "channel \"$name\" has on-disk eltype $on_disk_T " *
                "(Julia eltype $(eltype(arr))). Use :pxr24 for lossy " *
                "compression of Float32/UInt32 channels, or a lossless " *
                "compression like :zip / :piz / :rle / :none."))
        end
    elseif compression === :dwaa || compression === :dwab
        for (name, arr) in channels
            _, on_disk_T = _exr_pixel_type(eltype(arr))
            on_disk_T in (Float16, Float32) || throw(ArgumentError(
                "compression $(repr(compression)) requires Float16 or Float32 " *
                "channels; channel \"$name\" has on-disk eltype $on_disk_T " *
                "(Julia eltype $(eltype(arr))). Use a lossless compression " *
                "for UInt32 channels."))
        end
    end
    return nothing
end


# ---------------------------------------------------------------------------
# Save side — `save(path, ::ExrFile)` and the kwarg escape hatch.
# ---------------------------------------------------------------------------

"""
    save(path::AbstractString, exr::ExrFile) -> path

Write an `ExrFile` to disk. Each `ExrPart` in `exr.parts` becomes one part
in the output file; multi-part files are written via the standard
multi-part EXR layout (one part header per part, all chunks afterwards in
file order).

Each part's `compression`, `storage`, `tile_size`, and `attributes` are
honoured independently — different parts may use different compressions
and storage layouts.

For single-part files, the kwarg form `save(path; channels=..., ...)` is
often more convenient than constructing an `ExrFile` explicitly.
"""
function save(path::AbstractString, exr::ExrFile)
    isempty(exr.parts) && throw(ArgumentError(
        "ExrFile has no parts; cannot write an empty file"))

    # Validate each part's structure before opening the output file, so a
    # malformed input fails fast without leaving a partially-written file.
    for (i, part) in enumerate(exr.parts)
        _validate_exr_part(part, i)
    end

    # In a multi-part EXR, the `displayWindow` attribute is part of the
    # SHARED-ATTRIBUTE set and must be byte-identical across every part —
    # the multi-part spec requires displayWindow, pixelAspectRatio (and a
    # handful of timing attributes) to agree. `dataWindow` is per-part and
    # is the only one that varies with each part's dimensions.
    #
    # Single-part files have only one part, so the unified displayWindow
    # collapses to that part's (0,0)-(w-1,h-1).
    unified_display_w, unified_display_h = _unified_display_window(exr.parts)

    ctxt_ref = Ref{OpenEXR.Core.exr_context_t}(C_NULL)
    _check(
        OpenEXR.Core.exr_start_write(
            ctxt_ref, path, OpenEXR.Core.EXR_WRITE_FILE_DIRECTLY, C_NULL,
        ),
        :exr_start_write, path,
        "could not open file for writing; check directory exists and is writable",
    )
    try
        # First pass: declare every part (exr_add_part), set its required
        # attributes, channels, tile descriptor, user attributes. The
        # header must be fully populated for ALL parts before any chunk
        # data is written (multi-part EXR layout: all part headers up
        # front, then chunks in file order).
        part_indices = Vector{Cint}(undef, length(exr.parts))
        for (i, part) in enumerate(exr.parts)
            part_indices[i] = _declare_exr_part!(
                ctxt_ref[], part, path,
                unified_display_w, unified_display_h,
            )
        end

        # Finalize the file header now that every part is described.
        _check(
            OpenEXR.Core.exr_write_header(ctxt_ref[]),
            :exr_write_header, path, "could not write file header",
        )

        # Second pass: encode each part's pixel data.
        for (i, part) in enumerate(exr.parts)
            _write_exr_part_data(ctxt_ref[], part_indices[i], part, path)
        end
    finally
        OpenEXR.Core.exr_finish(ctxt_ref)
    end
    return path
end

"""
    save(path::AbstractString; channels, attributes = Dict(), compression = :zip, tile_size = nothing) -> path

Kwarg escape hatch for writing an arbitrary single-part EXR file without
constructing an `ExrFile`. `channels` is a Dict mapping channel name to a
2D AbstractArray (Float32 / Float16 / UInt32 / UInt16 / UInt8). All
channel arrays must have identical dimensions.

`attributes` is an optional Dict of user-defined header attributes
(stripped of EXR reserved names — see `_RESERVED_ATTR_NAMES`).

`compression` defaults to `:zip` and accepts all EXR compressions
(`:none`, `:rle`, `:zip`, `:zips`, `:piz`, `:pxr24`, `:b44`, `:b44a`,
`:dwaa`, `:dwab`). Lossy compressions have per-channel pixel-type
compatibility requirements (e.g. `:b44` requires Float16 channels).

`tile_size = nothing` uses scanline storage; passing `(width, height)`
uses tiled storage.
"""
function save(path::AbstractString;
              channels::AbstractDict{String, <:AbstractArray},
              attributes::AbstractDict{String, <:Any} = Dict{String, Any}(),
              compression::Symbol = :zip,
              tile_size::Union{Nothing, NTuple{2, Int}} = nothing)
    isempty(channels) && throw(ArgumentError("channels Dict must be non-empty"))
    sizes = unique(size(a) for a in values(channels))
    length(sizes) == 1 || throw(ArgumentError(
        "all channels must have identical dimensions; got " *
        "$(sort(collect(sizes)))"))
    h, w = sizes[1]
    part = ExrPart(
        "",
        Dict{String, AbstractArray}(channels),
        Dict{String, Any}(attributes),
        (w, h),
        tile_size === nothing ? :scanline : :tiled,
        tile_size,
        compression,
    )
    return save(path, ExrFile([part]))
end

# Structural validation for a single part before any I/O work. Catches
# inconsistencies (mismatched channel dims, storage/tile_size disagreement,
# empty channel set) at the source so a bad ExrPart never reaches the C API.
function _validate_exr_part(part::ExrPart, part_idx_1based::Int)
    isempty(part.channels) && throw(ArgumentError(
        "ExrPart at index $part_idx_1based (name $(repr(part.name))) has " *
        "no channels; every part must declare at least one channel"))

    w, h = part.dimensions
    w > 0 && h > 0 || throw(ArgumentError(
        "ExrPart at index $part_idx_1based has non-positive dimensions " *
        "$(part.dimensions)"))

    for (name, arr) in part.channels
        ndims(arr) == 2 || throw(ArgumentError(
            "channel \"$name\" in part $part_idx_1based must be a 2D array, " *
            "got $(ndims(arr))-dimensional array"))
        size(arr) == (h, w) || throw(ArgumentError(
            "channel \"$name\" in part $part_idx_1based has dimensions " *
            "$(size(arr)) which do not match part.dimensions " *
            "(width=$w, height=$h) → expected size $((h, w))"))
    end

    part.storage in (:scanline, :tiled) || throw(ArgumentError(
        "ExrPart.storage must be :scanline or :tiled, got " *
        "$(repr(part.storage)) in part $part_idx_1based"))
    if part.storage === :tiled
        part.tile_size === nothing && throw(ArgumentError(
            "ExrPart.storage = :tiled requires non-nothing tile_size in " *
            "part $part_idx_1based"))
        part.tile_size[1] > 0 && part.tile_size[2] > 0 || throw(ArgumentError(
            "ExrPart.tile_size must have positive dimensions, got " *
            "$(part.tile_size) in part $part_idx_1based"))
    else
        part.tile_size === nothing || throw(ArgumentError(
            "ExrPart.tile_size must be nothing when storage = :scanline, " *
            "got $(part.tile_size) in part $part_idx_1based"))
    end

    # Validate the compression against the part's per-channel pixel types.
    _validate_exr_file_compression(part.compression, part.channels)
    return nothing
end

# Compute the displayWindow shared by every part in the file. The
# multi-part EXR spec requires displayWindow to be identical across all
# parts; per-part dataWindow may differ. We take the union (the bounding
# rectangle that contains every part's dataWindow) so all parts agree on
# a window that covers them.
function _unified_display_window(parts::Vector{ExrPart})
    max_w = 0
    max_h = 0
    for part in parts
        w, h = part.dimensions
        max_w = max(max_w, w)
        max_h = max(max_h, h)
    end
    return max_w, max_h
end

# Add the part to the open context and seed every header attribute
# (required + channels + tile descriptor + user attributes). Does NOT
# encode pixel data — that's `_write_exr_part_data`.
#
# `display_w` and `display_h` set the SHARED displayWindow (identical
# across every part in the file). The part's own dataWindow is derived
# from its dimensions.
function _declare_exr_part!(ctxt::OpenEXR.Core.exr_context_t,
                            part::ExrPart, path::AbstractString,
                            display_w::Int, display_h::Int)
    storage_enum = part.storage === :tiled ?
        OpenEXR.Core.EXR_STORAGE_TILED :
        OpenEXR.Core.EXR_STORAGE_SCANLINE
    part_idx_ref = Ref{Cint}(0)
    _check(
        OpenEXR.Core.exr_add_part(ctxt, part.name, storage_enum, part_idx_ref),
        :exr_add_part, path,
        "could not add part $(repr(part.name))",
    )
    part_idx = part_idx_ref[]

    w, h = part.dimensions
    compression_enum = _exr_compression_enum(part.compression)
    _check(
        OpenEXR.Core.exr_initialize_required_attr_simple(
            ctxt, part_idx, Int32(w), Int32(h), compression_enum,
        ),
        :exr_initialize_required_attr_simple, path,
        "could not initialize required attributes on part $(repr(part.name))",
    )

    # In a multi-part file, displayWindow must agree across every part
    # (EXR multi-part shared-attribute rule). The `_simple` initializer
    # set both dataWindow and displayWindow to (0,0)-(w-1,h-1) for THIS
    # part's dims; if the file's unified display window differs, override
    # displayWindow now to the unified value. The dataWindow stays at the
    # part's own (0,0)-(w-1,h-1).
    #
    # IMPORTANT: We back the box by a raw 16-byte buffer rather than a
    # `Ref(exr_attr_box2i_t(...))`. The auto-generated `exr_attr_box2i_t`
    # is a mutable Julia struct whose nested `min`/`max::exr_attr_v2i_t`
    # fields are themselves mutable structs — Julia stores those as boxed
    # pointers, not inlined Int32 pairs, so passing the Ref to a C
    # function that dereferences the four Int32s directly reads pointer
    # bytes (resulting in garbage windows like (-1577101632, 32621)).
    # The same workaround is used in `_read_dimensions` (spectral_cube.jl).
    if display_w != w || display_h != h
        box_buf = zeros(UInt8, 16)
        GC.@preserve box_buf begin
            box_ptr = Ptr{OpenEXR.Core.exr_attr_box2i_t}(pointer(box_buf))
            unsafe_store!(Ptr{Int32}(pointer(box_buf) + 0),  Int32(0))
            unsafe_store!(Ptr{Int32}(pointer(box_buf) + 4),  Int32(0))
            unsafe_store!(Ptr{Int32}(pointer(box_buf) + 8),  Int32(display_w - 1))
            unsafe_store!(Ptr{Int32}(pointer(box_buf) + 12), Int32(display_h - 1))
            _check(
                OpenEXR.Core.exr_set_display_window(ctxt, part_idx, box_ptr),
                :exr_set_display_window, path,
                "could not set unified displayWindow on part $(repr(part.name))",
            )
        end
    end

    # Tile descriptor for tiled parts.
    if part.tile_size !== nothing
        _check(
            OpenEXR.Core.exr_set_tile_descriptor(
                ctxt, part_idx,
                UInt32(part.tile_size[1]), UInt32(part.tile_size[2]),
                OpenEXR.Core.EXR_TILE_ONE_LEVEL,
                OpenEXR.Core.EXR_TILE_ROUND_DOWN,
            ),
            :exr_set_tile_descriptor, path,
            "could not set tile descriptor on part $(repr(part.name))",
        )
    end

    # Channels — one per dict entry, each with its own pixel type derived
    # from the array's eltype.
    # We sort channel names for deterministic output ordering across runs;
    # EXR readers don't depend on a particular order, but a stable order
    # gives reproducible byte-identical files for the same Dict input.
    for ch_name in sort(collect(keys(part.channels)))
        pixel_type_enum, _ = _exr_pixel_type(eltype(part.channels[ch_name]))
        _check(
            OpenEXR.Core.exr_add_channel(
                ctxt, part_idx, ch_name, pixel_type_enum,
                OpenEXR.Core.EXR_PERCEPTUALLY_LINEAR,
                Int32(1), Int32(1),
            ),
            :exr_add_channel, path,
            "could not add channel \"$ch_name\" on part $(repr(part.name))",
        )
    end

    # User attributes (excluding reserved names like "compression" /
    # "dataWindow" — _write_attributes! filters them with a warning).
    _write_attributes!(ctxt, part_idx, part.attributes)
    return part_idx
end

# Encode every chunk of a single part. Dispatches to the scanline or tiled
# encoder based on `part.storage`; both routines handle the per-channel
# pixel-type heterogeneity that ExrFile parts can carry.
function _write_exr_part_data(ctxt::OpenEXR.Core.exr_context_t, part_idx::Cint,
                              part::ExrPart, path::AbstractString)
    # Build the per-channel lists in the same name order we declared them.
    # The encode pipeline reports channels in declaration order, so this
    # matches and we can index by position.
    ch_names = sort(collect(keys(part.channels)))
    n_ch = length(ch_names)
    ch_disk_types = Vector{DataType}(undef, n_ch)
    ch_data = Vector{AbstractArray}(undef, n_ch)
    for (i, ch_name) in enumerate(ch_names)
        arr = part.channels[ch_name]
        _, on_disk_T = _exr_pixel_type(eltype(arr))
        ch_disk_types[i] = on_disk_T
        ch_data[i] = arr
    end

    w, h = part.dimensions
    if part.storage === :tiled
        _write_part_tiles(
            ctxt, part_idx, ch_names, ch_disk_types, ch_data,
            w, h, part.tile_size, path,
        )
    else
        _write_part_scanlines(
            ctxt, part_idx, ch_names, ch_disk_types, ch_data, w, h, path,
        )
    end
    return nothing
end

# Per-chunk encode loop supporting heterogeneous channel pixel types.
# Mirrors `_write_scanlines` (the SpectralCube-specific scanline encoder)
# but accepts a per-channel `on_disk_T` and per-channel 2D source arrays.
function _write_part_scanlines(
    ctxt, part_idx, ch_names, ch_disk_types, ch_data, w, h, path,
)
    n_ch = length(ch_names)
    # Query the chunk stride for this part's compression.
    spc_ref = Ref{Int32}(0)
    _check(
        OpenEXR.Core.exr_get_scanlines_per_chunk(ctxt, part_idx, spc_ref),
        :exr_get_scanlines_per_chunk, path,
        "could not query scanlines-per-chunk",
    )
    chunk_stride = Int(spc_ref[])

    chunk_info_buf = zeros(UInt8, sizeof(OpenEXR.Core.exr_chunk_info_t))
    pipeline_buf   = zeros(UInt8, sizeof(OpenEXR.Core.exr_encode_pipeline_t))

    y_start = 0
    while y_start < h
        fill!(chunk_info_buf, 0x00)
        fill!(pipeline_buf, 0x00)
        chunk_h = min(chunk_stride, h - y_start)

        # Allocate one row-major (chunk_h × w) buffer per channel in its
        # on-disk eltype. The encode pipeline reads from these via
        # user_ptr.
        row_buffers = Vector{Any}(undef, n_ch)
        for c in 1:n_ch
            on_disk_T = ch_disk_types[c]
            arr = ch_data[c]
            chunk_buf = Vector{on_disk_T}(undef, w * chunk_h)
            idx = 1
            for j in 0:(chunk_h - 1)
                for i in 0:(w - 1)
                    @inbounds chunk_buf[idx] =
                        convert(on_disk_T, arr[y_start + j + 1, i + 1])
                    idx += 1
                end
            end
            row_buffers[c] = chunk_buf
        end

        # Build a name -> position lookup so we can match the pipeline's
        # reported channel order back to our declaration order.
        name_to_idx = Dict{String, Int}()
        for c in 1:n_ch
            name_to_idx[ch_names[c]] = c
        end

        GC.@preserve chunk_info_buf pipeline_buf row_buffers begin
            chunk_info_ptr = Ptr{OpenEXR.Core.exr_chunk_info_t}(pointer(chunk_info_buf))
            pipeline_ptr   = Ptr{OpenEXR.Core.exr_encode_pipeline_t}(pointer(pipeline_buf))

            _check(
                OpenEXR.Core.exr_write_scanline_chunk_info(
                    ctxt, part_idx, Cint(y_start), chunk_info_ptr,
                ),
                :exr_write_scanline_chunk_info, path,
                "could not get scanline chunk info at row $y_start",
            )
            unsafe_store!(
                Ptr{Csize_t}(pipeline_ptr),
                Csize_t(sizeof(OpenEXR.Core.exr_encode_pipeline_t)),
            )
            _check(
                OpenEXR.Core.exr_encoding_initialize(
                    ctxt, part_idx, chunk_info_ptr, pipeline_ptr,
                ),
                :exr_encoding_initialize, path,
                "could not init encode pipeline at row $y_start",
            )

            # Wire each pipeline channel to its source buffer by name.
            pip = unsafe_load(pipeline_ptr)
            ch_arr_ptr = pip.channels
            n_pipeline = Int(pip.channel_count)
            for c in 1:n_pipeline
                ch = unsafe_load(ch_arr_ptr, c)
                ch_name = unsafe_string(ch.channel_name)
                haskey(name_to_idx, ch_name) || continue
                src_idx = name_to_idx[ch_name]
                on_disk_T = ch_disk_types[src_idx]
                ch.user_pixel_stride = Int32(sizeof(on_disk_T))
                ch.user_line_stride  = Int32(w * sizeof(on_disk_T))
                ch.user_ptr          = Ptr{UInt8}(pointer(row_buffers[src_idx]))
                unsafe_store!(ch_arr_ptr, ch, c)
            end

            _check(
                OpenEXR.Core.exr_encoding_choose_default_routines(
                    ctxt, part_idx, pipeline_ptr,
                ),
                :exr_encoding_choose_default_routines, path,
                "could not pick encode routines at row $y_start",
            )
            _check(
                OpenEXR.Core.exr_encoding_run(ctxt, part_idx, pipeline_ptr),
                :exr_encoding_run, path,
                "encode pipeline failed at row $y_start",
            )
            _check(
                OpenEXR.Core.exr_encoding_destroy(ctxt, pipeline_ptr),
                :exr_encoding_destroy, path,
                "could not destroy encode pipeline at row $y_start",
            )
        end
        y_start += chunk_stride
    end
    return nothing
end

# Per-tile encode loop supporting heterogeneous channel pixel types.
function _write_part_tiles(
    ctxt, part_idx, ch_names, ch_disk_types, ch_data, w, h, tile_size, path,
)
    n_ch     = length(ch_names)
    tile_w_d = Int(tile_size[1])
    tile_h_d = Int(tile_size[2])
    n_tx     = cld(w, tile_w_d)
    n_ty     = cld(h, tile_h_d)

    chunk_info_buf = zeros(UInt8, sizeof(OpenEXR.Core.exr_chunk_info_t))
    pipeline_buf   = zeros(UInt8, sizeof(OpenEXR.Core.exr_encode_pipeline_t))

    name_to_idx = Dict{String, Int}()
    for c in 1:n_ch
        name_to_idx[ch_names[c]] = c
    end

    for ty in 0:(n_ty - 1)
        for tx in 0:(n_tx - 1)
            fill!(chunk_info_buf, 0x00)
            fill!(pipeline_buf, 0x00)

            tile_x0 = tx * tile_w_d
            tile_y0 = ty * tile_h_d
            tile_w  = min(tile_w_d, w - tile_x0)
            tile_h  = min(tile_h_d, h - tile_y0)

            tile_buffers = Vector{Any}(undef, n_ch)
            for c in 1:n_ch
                on_disk_T = ch_disk_types[c]
                arr = ch_data[c]
                tile_buf = Vector{on_disk_T}(undef, tile_w * tile_h)
                idx = 1
                for j in 0:(tile_h - 1)
                    for i in 0:(tile_w - 1)
                        @inbounds tile_buf[idx] = convert(
                            on_disk_T,
                            arr[tile_y0 + j + 1, tile_x0 + i + 1],
                        )
                        idx += 1
                    end
                end
                tile_buffers[c] = tile_buf
            end

            GC.@preserve chunk_info_buf pipeline_buf tile_buffers begin
                chunk_info_ptr = Ptr{OpenEXR.Core.exr_chunk_info_t}(pointer(chunk_info_buf))
                pipeline_ptr   = Ptr{OpenEXR.Core.exr_encode_pipeline_t}(pointer(pipeline_buf))

                _check(
                    OpenEXR.Core.exr_write_tile_chunk_info(
                        ctxt, part_idx, Cint(tx), Cint(ty),
                        Cint(0), Cint(0), chunk_info_ptr,
                    ),
                    :exr_write_tile_chunk_info, path,
                    "could not get tile chunk info at ($tx, $ty)",
                )
                unsafe_store!(
                    Ptr{Csize_t}(pipeline_ptr),
                    Csize_t(sizeof(OpenEXR.Core.exr_encode_pipeline_t)),
                )
                _check(
                    OpenEXR.Core.exr_encoding_initialize(
                        ctxt, part_idx, chunk_info_ptr, pipeline_ptr,
                    ),
                    :exr_encoding_initialize, path,
                    "could not init encode pipeline at tile ($tx, $ty)",
                )

                pip = unsafe_load(pipeline_ptr)
                ch_arr_ptr = pip.channels
                n_pipeline = Int(pip.channel_count)
                for c in 1:n_pipeline
                    ch = unsafe_load(ch_arr_ptr, c)
                    ch_name = unsafe_string(ch.channel_name)
                    haskey(name_to_idx, ch_name) || continue
                    src_idx = name_to_idx[ch_name]
                    on_disk_T = ch_disk_types[src_idx]
                    ch.user_pixel_stride = Int32(sizeof(on_disk_T))
                    ch.user_line_stride  = Int32(tile_w * sizeof(on_disk_T))
                    ch.user_ptr          = Ptr{UInt8}(pointer(tile_buffers[src_idx]))
                    unsafe_store!(ch_arr_ptr, ch, c)
                end

                _check(
                    OpenEXR.Core.exr_encoding_choose_default_routines(
                        ctxt, part_idx, pipeline_ptr,
                    ),
                    :exr_encoding_choose_default_routines, path,
                    "could not pick encode routines at tile ($tx, $ty)",
                )
                _check(
                    OpenEXR.Core.exr_encoding_run(ctxt, part_idx, pipeline_ptr),
                    :exr_encoding_run, path,
                    "encode pipeline failed at tile ($tx, $ty)",
                )
                _check(
                    OpenEXR.Core.exr_encoding_destroy(ctxt, pipeline_ptr),
                    :exr_encoding_destroy, path,
                    "could not destroy encode pipeline at tile ($tx, $ty)",
                )
            end
        end
    end
    return nothing
end


# ---------------------------------------------------------------------------
# Load side — `load(path, ::Type{ExrFile})`.
# ---------------------------------------------------------------------------

"""
    load(path::AbstractString, ::Type{ExrFile}) -> ExrFile

Load an arbitrary EXR file as an `ExrFile`. Every part in the file becomes
an `ExrPart`; channels are decoded into 2D arrays whose eltype matches
the on-disk pixel type (`Float16`, `Float32`, or `UInt32`).

Unlike `load(path, SpectralCube)`, this does not require any marker
attributes and accepts any valid EXR file (single-part or multi-part,
any compression, any channel layout).
"""
function load(path::AbstractString, ::Type{ExrFile})
    ctxt_ref = Ref{OpenEXR.Core.exr_context_t}(C_NULL)
    _check(
        OpenEXR.Core.exr_start_read(ctxt_ref, path, C_NULL),
        :exr_start_read, path, "could not open file for reading",
    )
    try
        # Enumerate parts. Single-part files report count == 1.
        n_parts_ref = Ref{Cint}(0)
        _check(
            OpenEXR.Core.exr_get_count(ctxt_ref[], n_parts_ref),
            :exr_get_count, path,
            "could not enumerate parts",
        )
        n_parts = Int(n_parts_ref[])
        n_parts > 0 || throw(ArgumentError(
            "EXR file \"$path\" reports zero parts"))

        parts = Vector{ExrPart}(undef, n_parts)
        for p in 0:(n_parts - 1)
            parts[p + 1] = _read_exr_part(ctxt_ref[], Cint(p), path)
        end
        return ExrFile(parts)
    finally
        OpenEXR.Core.exr_finish(ctxt_ref)
    end
end

# Read a single part fully (header + channels + pixel data). Returns the
# completed ExrPart.
function _read_exr_part(ctxt::OpenEXR.Core.exr_context_t, part_idx::Cint,
                        path::AbstractString)
    # Read the part's name (often "" for single-part files).
    name = _read_part_name(ctxt, part_idx)

    # Header attributes — _read_attributes already strips EXR reserved
    # names, so the returned Dict is free-form user attributes only.
    attrs = _read_attributes(ctxt, part_idx)

    # Storage descriptor + tile_size.
    storage, tile_size = _read_storage_descriptor(ctxt, part_idx)

    # Compression.
    compression = _read_compression(ctxt, part_idx)

    # Image dimensions from the data window.
    h, w = _read_dimensions(ctxt, part_idx)

    # Channel inventory: name + pixel type per channel, in file order.
    ch_names, ch_disk_types = _read_channel_inventory(ctxt, part_idx, path)
    n_ch = length(ch_names)

    # Allocate one destination 2D array per channel, sized (h, w) and
    # typed by the on-disk pixel type.
    ch_arrays = Vector{AbstractArray}(undef, n_ch)
    for c in 1:n_ch
        ch_arrays[c] = Array{ch_disk_types[c], 2}(undef, h, w)
    end

    # Decode each chunk into the destination arrays.
    if storage === :tiled
        _read_part_tiles_into!(
            ctxt, part_idx, ch_names, ch_disk_types, ch_arrays,
            w, h, tile_size, path,
        )
    else
        _read_part_scanlines_into!(
            ctxt, part_idx, ch_names, ch_disk_types, ch_arrays,
            w, h, path,
        )
    end

    channels_dict = Dict{String, AbstractArray}()
    for c in 1:n_ch
        channels_dict[ch_names[c]] = ch_arrays[c]
    end

    return ExrPart(
        name, channels_dict, attrs, (w, h),
        storage, tile_size, compression,
    )
end

# Read the part name. EXR allows empty / unset part names (the canonical
# state for single-part files), so we treat exr_get_name's empty-string
# return as a valid result.
function _read_part_name(ctxt::OpenEXR.Core.exr_context_t, part_idx::Cint)
    out_ref = Ref{Cstring}(Cstring(C_NULL))
    res = OpenEXR.Core.exr_get_name(ctxt, part_idx, out_ref)
    # Some single-part files have no `name` attribute at all; that's a
    # valid configuration and exr_get_name returns a non-success code.
    # Treat any non-success result as "unnamed" rather than erroring.
    res == Int32(OpenEXR.Core.EXR_ERR_SUCCESS) || return ""
    out_ref[] == C_NULL && return ""
    return unsafe_string(out_ref[])
end

# Read the part's compression as a Julia Symbol via the existing inverse
# mapping (defined in spectral_cube.jl).
function _read_compression(ctxt::OpenEXR.Core.exr_context_t, part_idx::Cint)
    c_ref = Ref{OpenEXR.Core.exr_compression_t}(OpenEXR.Core.EXR_COMPRESSION_NONE)
    _check(
        OpenEXR.Core.exr_get_compression(ctxt, part_idx, c_ref),
        :exr_get_compression, "", "could not read compression",
    )
    return _compression_to_symbol(c_ref[])
end

# Read every channel's name and on-disk pixel type, in file order. Returns
# (Vector{String}, Vector{DataType}) where the data types are one of
# Float16, Float32, UInt32 (the three native EXR pixel types).
#
# Uses the same raw byte-offset reads as _read_disk_pixel_type because
# the auto-generated mutable struct mirror for `exr_attr_chlist_entry_t`
# stores its nested `exr_attr_string_t` field as a boxed pointer rather
# than inlined bytes — so we can't unsafe_load the entry as a Julia
# struct and reach `.name.str` correctly.
function _read_channel_inventory(ctxt::OpenEXR.Core.exr_context_t,
                                 part_idx::Cint, path::AbstractString)
    chlist_ptr_ref = Ref{Ptr{OpenEXR.Core.exr_attr_chlist_t}}(C_NULL)
    _check(
        OpenEXR.Core.exr_get_channels(ctxt, part_idx, chlist_ptr_ref),
        :exr_get_channels, path, "could not read channel list",
    )
    chlist = unsafe_load(chlist_ptr_ref[])
    n = Int(chlist.num_channels)
    n > 0 || throw(ArgumentError(
        "EXR part at index $part_idx in \"$path\" has no channels"))

    entries_base = Ptr{UInt8}(chlist.entries)
    names      = Vector{String}(undef, n)
    disk_types = Vector{DataType}(undef, n)
    for i in 0:(n - 1)
        entry_base = entries_base + i * _CHLIST_ENTRY_STRIDE
        # Channel name string pointer (inside the embedded exr_attr_string_t).
        name_str_ptr = unsafe_load(
            Ptr{Cstring}(entry_base + _CHLIST_ENTRY_NAME_STR_OFF),
        )
        names[i + 1] = unsafe_string(name_str_ptr)
        # Pixel type enum.
        pt_raw = unsafe_load(Ptr{UInt32}(entry_base + _CHLIST_ENTRY_PIXEL_TYPE_OFF))
        if pt_raw == UInt32(OpenEXR.Core.EXR_PIXEL_UINT)
            disk_types[i + 1] = UInt32
        elseif pt_raw == UInt32(OpenEXR.Core.EXR_PIXEL_HALF)
            disk_types[i + 1] = Float16
        elseif pt_raw == UInt32(OpenEXR.Core.EXR_PIXEL_FLOAT)
            disk_types[i + 1] = Float32
        else
            throw(ArgumentError(
                "channel \"$(names[i + 1])\" has unknown pixel type enum value $pt_raw"))
        end
    end
    return names, disk_types
end

# Per-chunk decode loop for scanline parts with per-channel pixel types.
function _read_part_scanlines_into!(
    ctxt, part_idx, ch_names, ch_disk_types, ch_arrays, w, h, path,
)
    n_ch = length(ch_names)
    spc_ref = Ref{Int32}(0)
    _check(
        OpenEXR.Core.exr_get_scanlines_per_chunk(ctxt, part_idx, spc_ref),
        :exr_get_scanlines_per_chunk, path,
        "could not query scanlines-per-chunk",
    )
    chunk_stride = Int(spc_ref[])

    chunk_info_buf = zeros(UInt8, sizeof(OpenEXR.Core.exr_chunk_info_t))
    pipeline_buf   = zeros(UInt8, sizeof(OpenEXR.Core.exr_decode_pipeline_t))

    name_to_idx = Dict{String, Int}()
    for c in 1:n_ch
        name_to_idx[ch_names[c]] = c
    end

    y_start = 0
    while y_start < h
        fill!(chunk_info_buf, 0x00)
        fill!(pipeline_buf, 0x00)
        chunk_h = min(chunk_stride, h - y_start)

        # Per-channel scratch buffer sized (chunk_h × w) in on-disk eltype.
        row_buffers = Vector{Any}(undef, n_ch)
        for c in 1:n_ch
            row_buffers[c] = Vector{ch_disk_types[c]}(undef, w * chunk_h)
        end

        GC.@preserve chunk_info_buf pipeline_buf row_buffers begin
            chunk_info_ptr = Ptr{OpenEXR.Core.exr_chunk_info_t}(pointer(chunk_info_buf))
            pipeline_ptr   = Ptr{OpenEXR.Core.exr_decode_pipeline_t}(pointer(pipeline_buf))

            _check(
                OpenEXR.Core.exr_read_scanline_chunk_info(
                    ctxt, part_idx, Cint(y_start), chunk_info_ptr,
                ),
                :exr_read_scanline_chunk_info, path,
                "could not get scanline chunk info at row $y_start",
            )
            unsafe_store!(
                Ptr{Csize_t}(pipeline_ptr),
                Csize_t(sizeof(OpenEXR.Core.exr_decode_pipeline_t)),
            )
            _check(
                OpenEXR.Core.exr_decoding_initialize(
                    ctxt, part_idx, chunk_info_ptr, pipeline_ptr,
                ),
                :exr_decoding_initialize, path,
                "could not init decode pipeline at row $y_start",
            )

            pip = unsafe_load(pipeline_ptr)
            ch_arr_ptr = pip.channels
            n_pipeline = Int(pip.channel_count)
            for c in 1:n_pipeline
                ch = unsafe_load(ch_arr_ptr, c)
                ch_name = unsafe_string(ch.channel_name)
                haskey(name_to_idx, ch_name) || continue
                dst_idx = name_to_idx[ch_name]
                on_disk_T = ch_disk_types[dst_idx]
                ch.user_pixel_stride = Int32(sizeof(on_disk_T))
                ch.user_line_stride  = Int32(w * sizeof(on_disk_T))
                ch.user_ptr          = Ptr{UInt8}(pointer(row_buffers[dst_idx]))
                unsafe_store!(ch_arr_ptr, ch, c)
            end

            _check(
                OpenEXR.Core.exr_decoding_choose_default_routines(
                    ctxt, part_idx, pipeline_ptr,
                ),
                :exr_decoding_choose_default_routines, path,
                "could not pick decode routines at row $y_start",
            )
            _check(
                OpenEXR.Core.exr_decoding_run(ctxt, part_idx, pipeline_ptr),
                :exr_decoding_run, path,
                "decode pipeline failed at row $y_start",
            )
            _check(
                OpenEXR.Core.exr_decoding_destroy(ctxt, pipeline_ptr),
                :exr_decoding_destroy, path,
                "could not destroy decode pipeline at row $y_start",
            )

            # Scatter each channel's chunk buffer into its destination 2D array.
            for c in 1:n_ch
                dst = ch_arrays[c]
                buf = row_buffers[c]
                idx = 1
                for j in 0:(chunk_h - 1)
                    for i in 0:(w - 1)
                        @inbounds dst[y_start + j + 1, i + 1] = buf[idx]
                        idx += 1
                    end
                end
            end
        end
        y_start += chunk_stride
    end
    return nothing
end

# Per-tile decode loop for tiled parts with per-channel pixel types.
function _read_part_tiles_into!(
    ctxt, part_idx, ch_names, ch_disk_types, ch_arrays, w, h, tile_size, path,
)
    n_ch     = length(ch_names)
    tile_w_d = Int(tile_size[1])
    tile_h_d = Int(tile_size[2])
    n_tx     = cld(w, tile_w_d)
    n_ty     = cld(h, tile_h_d)

    chunk_info_buf = zeros(UInt8, sizeof(OpenEXR.Core.exr_chunk_info_t))
    pipeline_buf   = zeros(UInt8, sizeof(OpenEXR.Core.exr_decode_pipeline_t))

    name_to_idx = Dict{String, Int}()
    for c in 1:n_ch
        name_to_idx[ch_names[c]] = c
    end

    for ty in 0:(n_ty - 1)
        for tx in 0:(n_tx - 1)
            fill!(chunk_info_buf, 0x00)
            fill!(pipeline_buf, 0x00)

            tile_x0 = tx * tile_w_d
            tile_y0 = ty * tile_h_d
            tile_w  = min(tile_w_d, w - tile_x0)
            tile_h  = min(tile_h_d, h - tile_y0)

            tile_buffers = Vector{Any}(undef, n_ch)
            for c in 1:n_ch
                tile_buffers[c] = Vector{ch_disk_types[c]}(undef, tile_w * tile_h)
            end

            GC.@preserve chunk_info_buf pipeline_buf tile_buffers begin
                chunk_info_ptr = Ptr{OpenEXR.Core.exr_chunk_info_t}(pointer(chunk_info_buf))
                pipeline_ptr   = Ptr{OpenEXR.Core.exr_decode_pipeline_t}(pointer(pipeline_buf))

                _check(
                    OpenEXR.Core.exr_read_tile_chunk_info(
                        ctxt, part_idx, Cint(tx), Cint(ty),
                        Cint(0), Cint(0), chunk_info_ptr,
                    ),
                    :exr_read_tile_chunk_info, path,
                    "could not get tile chunk info at ($tx, $ty)",
                )
                unsafe_store!(
                    Ptr{Csize_t}(pipeline_ptr),
                    Csize_t(sizeof(OpenEXR.Core.exr_decode_pipeline_t)),
                )
                _check(
                    OpenEXR.Core.exr_decoding_initialize(
                        ctxt, part_idx, chunk_info_ptr, pipeline_ptr,
                    ),
                    :exr_decoding_initialize, path,
                    "could not init decode pipeline at tile ($tx, $ty)",
                )

                pip = unsafe_load(pipeline_ptr)
                ch_arr_ptr = pip.channels
                n_pipeline = Int(pip.channel_count)
                for c in 1:n_pipeline
                    ch = unsafe_load(ch_arr_ptr, c)
                    ch_name = unsafe_string(ch.channel_name)
                    haskey(name_to_idx, ch_name) || continue
                    dst_idx = name_to_idx[ch_name]
                    on_disk_T = ch_disk_types[dst_idx]
                    ch.user_pixel_stride = Int32(sizeof(on_disk_T))
                    ch.user_line_stride  = Int32(tile_w * sizeof(on_disk_T))
                    ch.user_ptr          = Ptr{UInt8}(pointer(tile_buffers[dst_idx]))
                    unsafe_store!(ch_arr_ptr, ch, c)
                end

                _check(
                    OpenEXR.Core.exr_decoding_choose_default_routines(
                        ctxt, part_idx, pipeline_ptr,
                    ),
                    :exr_decoding_choose_default_routines, path,
                    "could not pick decode routines at tile ($tx, $ty)",
                )
                _check(
                    OpenEXR.Core.exr_decoding_run(ctxt, part_idx, pipeline_ptr),
                    :exr_decoding_run, path,
                    "decode pipeline failed at tile ($tx, $ty)",
                )
                _check(
                    OpenEXR.Core.exr_decoding_destroy(ctxt, pipeline_ptr),
                    :exr_decoding_destroy, path,
                    "could not destroy decode pipeline at tile ($tx, $ty)",
                )

                # Scatter each channel's tile buffer into the destination rect.
                for c in 1:n_ch
                    dst = ch_arrays[c]
                    buf = tile_buffers[c]
                    idx = 1
                    for j in 0:(tile_h - 1)
                        for i in 0:(tile_w - 1)
                            @inbounds dst[tile_y0 + j + 1, tile_x0 + i + 1] = buf[idx]
                            idx += 1
                        end
                    end
                end
            end
        end
    end
    return nothing
end
