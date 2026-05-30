# src/spectral_cube.jl
# First-class type for spectral imaging data (hyperspectral / multispectral
# / ultraspectral / any cube with per-band wavelengths).
#
# Behaves as an AbstractArray{T, 3} via delegation to .data, plus spectral-
# axis access via .wavelengths, .fwhm, .band_names, .preview, .attributes,
# .storage, .tile_size.

"""
    SpectralCube{T <: Real} <: AbstractArray{T, 3}

Spectral data cube with `(height, width, band)` layout, per-band
wavelengths (nm), optional FWHM (nm) and band names, optional RGBA8 preview
thumbnail, free-form EXR attributes, and storage descriptor.

Construct directly:

    cube = SpectralCube(data, wavelengths;
                        fwhm=nothing, band_names=nothing, preview=nothing,
                        attributes=Dict{String,Any}(),
                        storage=:scanline, tile_size=nothing)

or load from an EXR file:

    cube = SpectralCube(path)
    cube = OpenEXR.load(path, SpectralCube)

The cube preserves EXR-roundtrippable spectral metadata via marker
attributes (`spectral_cube_version`, `spectral_wavelengths_nm`, optional
`spectral_fwhm_nm`, `spectral_channel_names`, `spectral_original_eltype`).
These markers are stripped from the user-visible `attributes` Dict on read.

EXR's native pixel types are `Float32`, `Float16`, and `UInt32`. `UInt16`
and `UInt8` are losslessly promoted to `UInt32` on disk and restored on
read via `spectral_original_eltype`. `Float64` is rejected with an
actionable error message.

Lossless compression only — `:none`, `:rle`, `:zip` (default), `:zips`,
`:piz`. Lossy compressions (`:pxr24`, `:b44`, `:b44a`, `:dwaa`, `:dwab`)
are rejected to preserve spectral data integrity.

See [`save`](@ref) and [`load`](@ref) for the persistence interface.
"""
struct SpectralCube{T <: Real} <: AbstractArray{T, 3}
    data::Array{T, 3}
    wavelengths::Vector{Float32}
    fwhm::Union{Nothing, Vector{Float32}}
    band_names::Union{Nothing, Vector{String}}
    preview::Union{Nothing, Matrix{NTuple{4, UInt8}}}
    attributes::Dict{String, Any}
    storage::Symbol
    tile_size::Union{Nothing, NTuple{2, Int}}

    function SpectralCube{T}(
        data::Array{T, 3}, wavelengths::Vector{Float32};
        fwhm::Union{Nothing, Vector{Float32}} = nothing,
        band_names::Union{Nothing, Vector{String}} = nothing,
        preview::Union{Nothing, Matrix{NTuple{4, UInt8}}} = nothing,
        attributes::Dict{String, Any} = Dict{String, Any}(),
        storage::Symbol = :scanline,
        tile_size::Union{Nothing, NTuple{2, Int}} = nothing,
    ) where {T <: Real}
        _validate_spectral_cube(data, wavelengths, fwhm, band_names, storage, tile_size)
        return new{T}(data, wavelengths, fwhm, band_names, preview, attributes,
                      storage, tile_size)
    end
end

# Convenience outer constructor that infers T from data eltype.
function SpectralCube(data::Array{T, 3}, wavelengths::Vector{Float32}; kw...) where {T <: Real}
    return SpectralCube{T}(data, wavelengths; kw...)
end

# Convenience outer constructor accepting any wavelength vector eltype.
function SpectralCube(data::Array{T, 3}, wavelengths::AbstractVector{<:Real}; kw...) where {T <: Real}
    return SpectralCube{T}(data, Vector{Float32}(wavelengths); kw...)
end

function _validate_spectral_cube(data, wavelengths, fwhm, band_names, storage, tile_size)
    n_bands = size(data, 3)
    length(wavelengths) == n_bands || throw(ArgumentError(
        "wavelengths length ($(length(wavelengths))) does not match band count ($n_bands)"))
    if fwhm !== nothing
        length(fwhm) == n_bands || throw(ArgumentError(
            "fwhm length ($(length(fwhm))) does not match band count ($n_bands)"))
    end
    if band_names !== nothing
        length(band_names) == n_bands || throw(ArgumentError(
            "band_names length ($(length(band_names))) does not match band count ($n_bands)"))
    end
    storage in (:scanline, :tiled) || throw(ArgumentError(
        "storage must be :scanline or :tiled, got $(repr(storage))"))
    if storage == :tiled
        tile_size === nothing && throw(ArgumentError(
            "storage = :tiled requires non-nothing tile_size"))
        tile_size[1] > 0 && tile_size[2] > 0 || throw(ArgumentError(
            "tile_size dimensions must be positive, got $tile_size"))
    else
        tile_size === nothing || throw(ArgumentError(
            "tile_size must be nothing when storage = :scanline"))
    end
    return nothing
end

# AbstractArray interface — delegate to .data.
Base.size(c::SpectralCube) = size(c.data)
Base.IndexStyle(::Type{<:SpectralCube{T}}) where {T} = IndexCartesian()
Base.@propagate_inbounds Base.getindex(c::SpectralCube, I::Vararg{Int, 3}) = c.data[I...]
Base.@propagate_inbounds Base.setindex!(c::SpectralCube, v, I::Vararg{Int, 3}) =
    (c.data[I...] = v)


# ---------------------------------------------------------------------------
# Save side — pixel type, compression, and channel-name helpers, plus save().
# ---------------------------------------------------------------------------

# Lossless compressions permitted for SpectralCube.
const _LOSSLESS_COMPRESSIONS_FOR_SPECTRAL_CUBE = (:none, :rle, :zip, :zips, :piz)
# Lossy compressions explicitly rejected for SpectralCube.
const _LOSSY_COMPRESSIONS_FOR_SPECTRAL_CUBE    = (:pxr24, :b44, :b44a, :dwaa, :dwab)

# Map Julia eltype to (OpenEXR pixel-type enum, on-disk Julia eltype).
# Float32/Float16/UInt32 are the three native EXR pixel types.
# UInt16 / UInt8 are auto-promoted to UInt32 (lossless); the original eltype
# is recorded in a marker attribute so reads can restore it.
_exr_pixel_type(::Type{Float32}) = (OpenEXR.Core.EXR_PIXEL_FLOAT, Float32)
_exr_pixel_type(::Type{Float16}) = (OpenEXR.Core.EXR_PIXEL_HALF,  Float16)
_exr_pixel_type(::Type{UInt32})  = (OpenEXR.Core.EXR_PIXEL_UINT,  UInt32)
_exr_pixel_type(::Type{UInt16})  = (OpenEXR.Core.EXR_PIXEL_UINT,  UInt32)  # promote
_exr_pixel_type(::Type{UInt8})   = (OpenEXR.Core.EXR_PIXEL_UINT,  UInt32)  # promote

_exr_pixel_type(::Type{Float64}) = throw(ArgumentError(
    "EXR's largest native float type is Float32; convert with " *
    "Float32.(cube.data) if precision loss is acceptable, or use " *
    "HDF5/NetCDF/Zarr for Float64 spectral data."))

_exr_pixel_type(::Type{T}) where {T} = throw(ArgumentError(
    "SpectralCube eltype $T is not supported. EXR's native pixel types " *
    "are Float32, Float16, and UInt32; UInt8 and UInt16 are auto-" *
    "promoted to UInt32 (lossless). Float64 is rejected: convert with " *
    "Float32.(cube.data) if precision loss is acceptable, or use " *
    "HDF5/NetCDF/Zarr for Float64 spectral data."))

# Compression Symbol -> OpenEXR.Core enum.
function _exr_compression_enum(c::Symbol)
    c === :none  && return OpenEXR.Core.EXR_COMPRESSION_NONE
    c === :rle   && return OpenEXR.Core.EXR_COMPRESSION_RLE
    c === :zip   && return OpenEXR.Core.EXR_COMPRESSION_ZIP
    c === :zips  && return OpenEXR.Core.EXR_COMPRESSION_ZIPS
    c === :piz   && return OpenEXR.Core.EXR_COMPRESSION_PIZ
    c === :pxr24 && return OpenEXR.Core.EXR_COMPRESSION_PXR24
    c === :b44   && return OpenEXR.Core.EXR_COMPRESSION_B44
    c === :b44a  && return OpenEXR.Core.EXR_COMPRESSION_B44A
    c === :dwaa  && return OpenEXR.Core.EXR_COMPRESSION_DWAA
    c === :dwab  && return OpenEXR.Core.EXR_COMPRESSION_DWAB
    throw(ArgumentError("unknown compression $(repr(c))"))
end

# Inverse mapping: OpenEXR.Core compression enum -> Symbol.
function _compression_to_symbol(e)
    e == OpenEXR.Core.EXR_COMPRESSION_NONE  && return :none
    e == OpenEXR.Core.EXR_COMPRESSION_RLE   && return :rle
    e == OpenEXR.Core.EXR_COMPRESSION_ZIP   && return :zip
    e == OpenEXR.Core.EXR_COMPRESSION_ZIPS  && return :zips
    e == OpenEXR.Core.EXR_COMPRESSION_PIZ   && return :piz
    e == OpenEXR.Core.EXR_COMPRESSION_PXR24 && return :pxr24
    e == OpenEXR.Core.EXR_COMPRESSION_B44   && return :b44
    e == OpenEXR.Core.EXR_COMPRESSION_B44A  && return :b44a
    e == OpenEXR.Core.EXR_COMPRESSION_DWAA  && return :dwaa
    e == OpenEXR.Core.EXR_COMPRESSION_DWAB  && return :dwab
    return Symbol("compression_$(Int(e))")
end

# Default channel-name generator: "S<wavelength>" rounded to 1 decimal.
# On collisions, increase precision; throw if collision persists at Float32
# precision limit.
function _default_channel_names(wavelengths::AbstractVector{<:Real})
    digits = 1
    names = ["S$(round(Float64(w); digits = digits))" for w in wavelengths]
    while length(unique(names)) != length(names) && digits < 7
        digits += 1
        names = ["S$(round(Float64(w); digits = digits))" for w in wavelengths]
    end
    if length(unique(names)) != length(names)
        # Find a colliding pair to surface in the error message.
        seen = Dict{String, Int}()
        for (i, n) in enumerate(names)
            if haskey(seen, n)
                throw(ArgumentError(
                    "two bands have wavelength $(wavelengths[seen[n]]) (band " *
                    "$(seen[n])) and $(wavelengths[i]) (band $i) that collapse " *
                    "to channel name $(repr(n)); provide explicit " *
                    "cube.band_names to disambiguate"))
            end
            seen[n] = i
        end
    end
    return names
end

"""
    save(path::AbstractString, cube::SpectralCube;
         compression::Symbol = :zip,
         tile_size::Union{Nothing, NTuple{2, Int}} = nothing,
         preview::Union{Nothing, Matrix{NTuple{4, UInt8}}} = nothing) -> path

Write `cube` to an OpenEXR file at `path` as a single-part EXR with one
channel per band. `compression` must be one of `:none`, `:rle`, `:zip`,
`:zips`, `:piz` — lossy compressions are rejected to preserve spectral
data integrity. `tile_size = nothing` uses scanline storage; passing a
`(width, height)` tuple uses tiled storage.

The `preview` kwarg overrides `cube.preview` if given. Channel names
default to `"S<wavelength>"`; override via `cube.band_names`.
"""
function save(
    path::AbstractString, cube::SpectralCube{T};
    compression::Symbol = :zip,
    tile_size::Union{Nothing, NTuple{2, Int}} = cube.tile_size,
    preview::Union{Nothing, Matrix{NTuple{4, UInt8}}} = cube.preview,
) where {T}
    # Validate compression.
    if compression in _LOSSY_COMPRESSIONS_FOR_SPECTRAL_CUBE
        throw(ArgumentError(
            "compression $(repr(compression)) is lossy and not permitted for " *
            "SpectralCube; spectral data integrity requires lossless " *
            "compression. Use :zip, :piz, :zips, :rle, or :none."))
    end
    compression in _LOSSLESS_COMPRESSIONS_FOR_SPECTRAL_CUBE || throw(ArgumentError(
        "unknown compression $(repr(compression))"))

    pixel_type_enum, on_disk_T = _exr_pixel_type(T)
    h, w, n_bands = size(cube.data)
    channel_names = cube.band_names !== nothing ? cube.band_names :
        _default_channel_names(cube.wavelengths)

    # Build the marker attributes (copied so we don't mutate cube.attributes).
    attrs = copy(cube.attributes)
    attrs["spectral_cube_version"] = Int32(1)
    attrs["spectral_wavelengths_nm"] = Vector{Float32}(cube.wavelengths)
    cube.fwhm !== nothing && (attrs["spectral_fwhm_nm"] = Vector{Float32}(cube.fwhm))
    cube.band_names !== nothing &&
        (attrs["spectral_channel_names"] = Vector{String}(cube.band_names))
    if T !== on_disk_T
        attrs["spectral_original_eltype"] = string(T)
    end

    _write_exr_part(
        path, w, h, channel_names, pixel_type_enum, on_disk_T,
        cube.data, attrs, _exr_compression_enum(compression),
        tile_size, preview,
    )
    return path
end

# Helper that owns the OpenEXR.Core.exr_start_write -> exr_finish lifecycle
# for a single-part write. Caller provides channels, pixel type, data array,
# attributes Dict, compression enum, tile descriptor, and optional preview.
function _write_exr_part(
    path, w, h, channel_names, pixel_type, on_disk_T,
    data, attrs, compression_enum, tile_size, preview,
)
    ctxt_ref = Ref{OpenEXR.Core.exr_context_t}(C_NULL)
    # `exr_default_write_params()` doesn't exist; pass NULL so libOpenEXRCore
    # uses its built-in defaults (EXR_DEFAULT_CONTEXT_INITIALIZER).
    _check(
        OpenEXR.Core.exr_start_write(
            ctxt_ref, path, OpenEXR.Core.EXR_WRITE_FILE_DIRECTLY, C_NULL,
        ),
        :exr_start_write, path,
        "could not open file for writing; check directory exists and is writable",
    )
    try
        # Pick storage type up front; the EXR file is single-part.
        storage_enum = tile_size === nothing ?
            OpenEXR.Core.EXR_STORAGE_SCANLINE :
            OpenEXR.Core.EXR_STORAGE_TILED
        part_idx_ref = Ref{Cint}(0)
        _check(
            OpenEXR.Core.exr_add_part(ctxt_ref[], "", storage_enum, part_idx_ref),
            :exr_add_part, path, "could not add part",
        )
        part_idx = part_idx_ref[]

        # Seed the part with the required attributes (data/display window,
        # lineorder, pixelAspectRatio, screenWindowCenter, screenWindowWidth,
        # compression). exr_initialize_required_attr_simple sets the windows
        # to (0,0)-(w-1,h-1) and leaves everything else at the defaults; we
        # override the compression next.
        _check(
            OpenEXR.Core.exr_initialize_required_attr_simple(
                ctxt_ref[], part_idx, Int32(w), Int32(h), compression_enum,
            ),
            :exr_initialize_required_attr_simple, path,
            "could not initialize required attributes",
        )

        # Set tile descriptor for tiled storage (ignored for scanline parts).
        if tile_size !== nothing
            _check(
                OpenEXR.Core.exr_set_tile_descriptor(
                    ctxt_ref[], part_idx,
                    UInt32(tile_size[1]), UInt32(tile_size[2]),
                    OpenEXR.Core.EXR_TILE_ONE_LEVEL,
                    OpenEXR.Core.EXR_TILE_ROUND_DOWN,
                ),
                :exr_set_tile_descriptor, path,
                "could not set tile descriptor",
            )
        end

        # Add one channel per band, all with the same pixel type.
        for ch_name in channel_names
            _check(
                OpenEXR.Core.exr_add_channel(
                    ctxt_ref[], part_idx, ch_name, pixel_type,
                    OpenEXR.Core.EXR_PERCEPTUALLY_LINEAR,
                    Int32(1), Int32(1),
                ),
                :exr_add_channel, path,
                "could not add channel $ch_name",
            )
        end

        # User + marker attributes.
        _write_attributes!(ctxt_ref[], part_idx, attrs)

        # Optional preview thumbnail (uses EXR's reserved "preview" attr name).
        preview !== nothing && _write_preview_attribute!(
            ctxt_ref[], part_idx, preview,
        )

        # Finalize the header — required before encoding any chunks.
        _check(
            OpenEXR.Core.exr_write_header(ctxt_ref[]),
            :exr_write_header, path, "could not write header",
        )

        # Encode pixel data: scanlines or tiles.
        if tile_size === nothing
            _write_scanlines(
                ctxt_ref[], part_idx, channel_names, on_disk_T, data, w, h, path,
            )
        else
            _write_tiles(
                ctxt_ref[], part_idx, channel_names, on_disk_T, data,
                w, h, tile_size, path,
            )
        end
    finally
        # Closes the file. If the try-block above threw mid-write, a partial
        # file may still be on disk; we surface that in the error message.
        OpenEXR.Core.exr_finish(ctxt_ref)
    end
    return nothing
end

# Per-chunk encode loop for scanline parts.
#
# Memory layout of the encode pipeline (versioned struct, see CLAUDE.md note):
#  - The pipeline's `pipe_size` field must be initialized to
#    `sizeof(exr_encode_pipeline_t)` BEFORE exr_encoding_initialize is called,
#    so libOpenEXRCore can version-check against its compiled-in layout.
#  - `exr_encoding_initialize` then populates the rest of the struct based on
#    the part's compression / channel list, and allocates the per-channel
#    descriptors at `pipeline.channels`.
#  - For each channel we set `user_pixel_stride`, `user_line_stride`, and
#    `user_ptr` (the source pointer for encoding) before running.
#  - `user_ptr` is the trailing union member patched in by the generator,
#    pointing at the contiguous source buffer for this chunk's data.
#  - All Julia-side buffers must stay GC-rooted from the moment their pointer
#    is stored into the channel info until exr_encoding_run returns.
#
# Scanline parts: the EXR spec groups multiple scanlines into one chunk
# depending on the compression scheme (uncompressed/RLE/ZIPS: 1 row per
# chunk; ZIP: 16 rows per chunk; PIZ: 32 rows per chunk). We iterate by
# the chunk's starting row (`y_start`) in steps of `scanlines_per_chunk`,
# and for each chunk read its actual height from the chunk_info struct
# (the last chunk may be shorter than `scanlines_per_chunk`).
function _write_scanlines(ctxt, part_idx, channel_names, on_disk_T, data, w, h, path)
    n_bands = length(channel_names)
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
        # Build one contiguous row-major buffer per band, covering
        # chunk_h rows × w columns, with on-disk eltype.
        row_buffers = Vector{Vector{on_disk_T}}(undef, n_bands)
        for b in 1:n_bands
            chunk_buf = Vector{on_disk_T}(undef, w * chunk_h)
            idx = 1
            for j in 0:(chunk_h - 1)
                for i in 0:(w - 1)
                    @inbounds chunk_buf[idx] =
                        convert(on_disk_T, data[y_start + j + 1, i + 1, b])
                    idx += 1
                end
            end
            row_buffers[b] = chunk_buf
        end

        # GC-root the buffers across the encode pipeline lifecycle. The pipeline
        # holds raw pointers into row_buffers, so the Julia values MUST stay
        # live until exr_encoding_run returns.
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
            # Initialize the version-checked first field of the pipeline.
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

            # Read the channels pointer back so we can populate each channel's
            # user_* fields with the row buffer.
            pip = unsafe_load(pipeline_ptr)
            ch_arr_ptr = pip.channels                # Ptr{exr_coding_channel_info_t}
            for b in 1:n_bands
                ch = unsafe_load(ch_arr_ptr, b)
                ch.user_pixel_stride = Int32(sizeof(on_disk_T))
                ch.user_line_stride  = Int32(w * sizeof(on_disk_T))
                ch.user_ptr          = Ptr{UInt8}(pointer(row_buffers[b]))
                unsafe_store!(ch_arr_ptr, ch, b)
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

# Per-tile encode loop.
#
# The tile grid is (ceil(w/tile_w), ceil(h/tile_h)). For each tile we encode
# all bands in lock-step. `exr_write_tile_chunk_info` reports the tile's
# actual width/height (the edge tiles may be smaller than the descriptor
# size). The encode pipeline expects user_line_stride to be tile_actual_w *
# sizeof(eltype).
function _write_tiles(
    ctxt, part_idx, channel_names, on_disk_T, data, w, h, tile_size, path,
)
    n_bands  = length(channel_names)
    tile_w_d = Int(tile_size[1])
    tile_h_d = Int(tile_size[2])
    n_tx     = cld(w, tile_w_d)
    n_ty     = cld(h, tile_h_d)

    chunk_info_buf = zeros(UInt8, sizeof(OpenEXR.Core.exr_chunk_info_t))
    pipeline_buf   = zeros(UInt8, sizeof(OpenEXR.Core.exr_encode_pipeline_t))

    for ty in 0:(n_ty - 1)
        for tx in 0:(n_tx - 1)
            fill!(chunk_info_buf, 0x00)
            fill!(pipeline_buf, 0x00)

            # Pre-query the tile's actual dimensions from the chunk_info
            # populated by exr_write_tile_chunk_info. We do this with a
            # speculative call so the row buffer sizing is correct.
            tile_x0 = tx * tile_w_d
            tile_y0 = ty * tile_h_d
            tile_w  = min(tile_w_d, w - tile_x0)
            tile_h  = min(tile_h_d, h - tile_y0)

            tile_buffers = Vector{Vector{on_disk_T}}(undef, n_bands)
            for b in 1:n_bands
                tile_buf = Vector{on_disk_T}(undef, tile_w * tile_h)
                # Copy a (tile_h, tile_w) sub-rectangle from data[:,:,b] in
                # row-major order — the EXR encode pipeline expects rows
                # laid out contiguously from top to bottom.
                idx = 1
                for j in 0:(tile_h - 1)
                    for i in 0:(tile_w - 1)
                        @inbounds tile_buf[idx] = convert(
                            on_disk_T,
                            data[tile_y0 + j + 1, tile_x0 + i + 1, b],
                        )
                        idx += 1
                    end
                end
                tile_buffers[b] = tile_buf
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
                for b in 1:n_bands
                    ch = unsafe_load(ch_arr_ptr, b)
                    ch.user_pixel_stride = Int32(sizeof(on_disk_T))
                    ch.user_line_stride  = Int32(tile_w * sizeof(on_disk_T))
                    ch.user_ptr          = Ptr{UInt8}(pointer(tile_buffers[b]))
                    unsafe_store!(ch_arr_ptr, ch, b)
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

# Write a preview thumbnail. The EXR preview attribute is RGBA8, stored
# row-major (height rows of width * 4 bytes each). We pass `pointer(rgba)`
# under GC.@preserve so the byte buffer survives the ccall.
function _write_preview_attribute!(ctxt, part_idx, preview::Matrix{NTuple{4, UInt8}})
    ph, pw = size(preview)
    # Flatten the (height, width) matrix of RGBA tuples into a row-major
    # RGBA byte stream. The EXR convention is row-major top-to-bottom; our
    # Matrix is (row, col) which is column-major in storage, so we walk
    # rows-first explicitly.
    rgba_bytes = Vector{UInt8}(undef, ph * pw * 4)
    idx = 1
    for i in 1:ph
        for j in 1:pw
            r, g, b, a = preview[i, j]
            rgba_bytes[idx]     = r
            rgba_bytes[idx + 1] = g
            rgba_bytes[idx + 2] = b
            rgba_bytes[idx + 3] = a
            idx += 4
        end
    end
    GC.@preserve rgba_bytes begin
        pv = Ref(OpenEXR.Core.exr_attr_preview_t(
            UInt32(pw), UInt32(ph), Csize_t(length(rgba_bytes)),
            pointer(rgba_bytes),
        ))
        _check(
            OpenEXR.Core.exr_attr_set_preview(ctxt, part_idx, "preview", pv),
            :exr_attr_set_preview, "",
            "could not set preview attribute",
        )
    end
    return nothing
end


# ---------------------------------------------------------------------------
# Load side — pixel-type / storage / channel inspection helpers, plus load().
# ---------------------------------------------------------------------------

"""
    load(path::AbstractString, ::Type{SpectralCube}) -> SpectralCube{T}

Load an EXR file as a `SpectralCube`. The file must carry the
`spectral_wavelengths_nm` marker attribute. The returned cube's eltype is
determined by the file's channel pixel type and (when set) the
`spectral_original_eltype` attribute.

Throws `ArgumentError` if the file does not carry the spectral marker
attribute (with a hint to use `load(path)` for arbitrary EXR files).
"""
function load(path::AbstractString, ::Type{SpectralCube})
    ctxt_ref = Ref{OpenEXR.Core.exr_context_t}(C_NULL)
    _check(
        OpenEXR.Core.exr_start_read(ctxt_ref, path, C_NULL),
        :exr_start_read, path, "could not open file for reading",
    )
    try
        attrs = _read_attributes(ctxt_ref[], Cint(0))
        haskey(attrs, "spectral_wavelengths_nm") || throw(ArgumentError(
            "file \"$path\" has no `spectral_wavelengths_nm` attribute; " *
            "it is not a SpectralCube. Use `OpenEXR.load(path)` for " *
            "auto-detection or `OpenEXR.load(path, ExrFile)` for generic access."))

        # Pull and strip the marker attributes so the user-visible Dict is
        # free-form only.
        wavelengths     = Vector{Float32}(attrs["spectral_wavelengths_nm"])
        fwhm_raw        = get(attrs, "spectral_fwhm_nm", nothing)
        fwhm            = fwhm_raw === nothing ? nothing : Vector{Float32}(fwhm_raw)
        band_names_raw  = get(attrs, "spectral_channel_names", nothing)
        band_names      = band_names_raw === nothing ? nothing :
            Vector{String}(band_names_raw)
        original_elt_s  = get(attrs, "spectral_original_eltype", nothing)
        delete!(attrs, "spectral_cube_version")
        delete!(attrs, "spectral_wavelengths_nm")
        delete!(attrs, "spectral_fwhm_nm")
        delete!(attrs, "spectral_channel_names")
        delete!(attrs, "spectral_original_eltype")

        # On-disk channel pixel type.
        on_disk_T = _read_disk_pixel_type(ctxt_ref[], Cint(0))
        # Target Julia eltype (restoring promoted UInt8/UInt16 if marker set).
        T = original_elt_s === nothing ? on_disk_T :
            _parse_eltype_from_string(original_elt_s)
        # Storage descriptor + tile_size.
        storage, tile_size = _read_storage_descriptor(ctxt_ref[], Cint(0))
        # Optional preview thumbnail.
        preview = _read_preview_attribute(ctxt_ref[], Cint(0))
        # Image dimensions from the part's data window.
        h, w = _read_dimensions(ctxt_ref[], Cint(0))

        # Channel order = declared wavelength order. When band_names is set,
        # use those names exactly; otherwise the wavelength-derived defaults.
        n_bands = length(wavelengths)
        ch_names_in_order = band_names !== nothing ? band_names :
            _default_channel_names(wavelengths)

        # Allocate target array and decode each band.
        data = Array{T, 3}(undef, h, w, n_bands)
        if storage === :scanline
            _read_scanlines_into!(
                ctxt_ref[], Cint(0), ch_names_in_order,
                on_disk_T, T, data, w, h, path,
            )
        else
            _read_tiles_into!(
                ctxt_ref[], Cint(0), ch_names_in_order,
                on_disk_T, T, data, w, h, tile_size, path,
            )
        end

        return SpectralCube{T}(
            data, wavelengths;
            fwhm = fwhm, band_names = band_names,
            preview = preview, attributes = attrs,
            storage = storage, tile_size = tile_size,
        )
    finally
        OpenEXR.Core.exr_finish(ctxt_ref)
    end
end

# Construct a SpectralCube directly from a file path.
SpectralCube(path::AbstractString) = load(path, SpectralCube)

# Parse "UInt8" / "UInt16" / "UInt32" / "Float16" / "Float32" into Julia types.
function _parse_eltype_from_string(s::AbstractString)
    s == "UInt8"   && return UInt8
    s == "UInt16"  && return UInt16
    s == "UInt32"  && return UInt32
    s == "Float16" && return Float16
    s == "Float32" && return Float32
    throw(ArgumentError("unknown spectral_original_eltype: $(repr(s))"))
end

# Byte offsets within the flat C `exr_attr_chlist_entry_t` struct. The
# auto-generated Julia `mutable struct` mirror does NOT have the same
# layout as the flat C struct because Julia stores the nested
# `exr_attr_string_t` field as a boxed pointer rather than inlining its 16
# bytes. We read every channel-entry field via raw byte offsets so we
# never depend on the generator's struct layout for this type.
#
# Flat C layout (sizeof = 32 on a 64-bit target):
#   name::exr_attr_string_t       offset  0   size 16  (length: Int32; alloc_size: Int32; str: Cstring)
#   pixel_type::exr_pixel_type_t  offset 16   size  4  (UInt32 enum)
#   p_linear::UInt8               offset 20   size  1
#   reserved::NTuple{3, UInt8}    offset 21   size  3
#   x_sampling::Int32             offset 24   size  4
#   y_sampling::Int32             offset 28   size  4
const _CHLIST_ENTRY_STRIDE        = 32
const _CHLIST_ENTRY_NAME_STR_OFF  = 8       # bytes from entry base to str::Cstring
const _CHLIST_ENTRY_PIXEL_TYPE_OFF = 16

# Read the first channel's pixel type and translate to a Julia type. All
# channels in a SpectralCube file share one pixel type by construction.
function _read_disk_pixel_type(ctxt, part_idx)
    chlist_ptr_ref = Ref{Ptr{OpenEXR.Core.exr_attr_chlist_t}}(C_NULL)
    _check(
        OpenEXR.Core.exr_get_channels(ctxt, part_idx, chlist_ptr_ref),
        :exr_get_channels, "", "could not read channel list",
    )
    chlist = unsafe_load(chlist_ptr_ref[])
    chlist.num_channels > 0 || throw(ArgumentError("file has no channels"))
    entries_base = Ptr{UInt8}(chlist.entries)
    # First entry's pixel_type lives at offset _CHLIST_ENTRY_PIXEL_TYPE_OFF.
    pt_raw = unsafe_load(Ptr{UInt32}(entries_base + _CHLIST_ENTRY_PIXEL_TYPE_OFF))
    pt_raw == UInt32(OpenEXR.Core.EXR_PIXEL_UINT)  && return UInt32
    pt_raw == UInt32(OpenEXR.Core.EXR_PIXEL_HALF)  && return Float16
    pt_raw == UInt32(OpenEXR.Core.EXR_PIXEL_FLOAT) && return Float32
    throw(ArgumentError("unknown channel pixel type $pt_raw"))
end

# Read the storage type (scanline/tiled) and, for tiled, the tile descriptor.
function _read_storage_descriptor(ctxt, part_idx)
    storage_ref = Ref{OpenEXR.Core.exr_storage_t}(OpenEXR.Core.EXR_STORAGE_SCANLINE)
    _check(
        OpenEXR.Core.exr_get_storage(ctxt, part_idx, storage_ref),
        :exr_get_storage, "", "could not read storage descriptor",
    )
    s = storage_ref[]
    if s == OpenEXR.Core.EXR_STORAGE_SCANLINE
        return (:scanline, nothing)
    elseif s == OpenEXR.Core.EXR_STORAGE_TILED
        xs_ref = Ref{UInt32}(0)
        ys_ref = Ref{UInt32}(0)
        lvl_ref = Ref{OpenEXR.Core.exr_tile_level_mode_t}(OpenEXR.Core.EXR_TILE_ONE_LEVEL)
        rnd_ref = Ref{OpenEXR.Core.exr_tile_round_mode_t}(OpenEXR.Core.EXR_TILE_ROUND_DOWN)
        _check(
            OpenEXR.Core.exr_get_tile_descriptor(
                ctxt, part_idx, xs_ref, ys_ref, lvl_ref, rnd_ref,
            ),
            :exr_get_tile_descriptor, "", "could not read tile descriptor",
        )
        return (:tiled, (Int(xs_ref[]), Int(ys_ref[])))
    else
        throw(ArgumentError(
            "unsupported storage type $(Int(s)); SpectralCube supports " *
            "scanline and tiled storage only"))
    end
end

# Read the part's (height, width) from its data window.
#
# Note: `exr_attr_box2i_t` is a mutable Julia struct generated by Clang.jl
# whose nested `exr_attr_v2i_t` fields are themselves mutable. In Julia
# this means the box2i field layout stores its min/max children as boxed
# pointers, NOT inlined Int32 pairs as the C struct does. We therefore
# cannot pass a `Ref{exr_attr_box2i_t}` to the C function — the addresses
# would point at Julia-managed pointer slots, not the four Int32s the C
# side expects. The workaround is to back the box by a raw 16-byte buffer
# and read the four Int32 fields by explicit offsets.
const _BOX2I_BYTES = 16
function _read_dimensions(ctxt, part_idx)
    box_buf = zeros(UInt8, _BOX2I_BYTES)
    GC.@preserve box_buf begin
        box_ptr = Ptr{OpenEXR.Core.exr_attr_box2i_t}(pointer(box_buf))
        _check(
            OpenEXR.Core.exr_get_data_window(ctxt, part_idx, box_ptr),
            :exr_get_data_window, "", "could not read data window",
        )
        min_x = unsafe_load(Ptr{Int32}(pointer(box_buf) + 0))
        min_y = unsafe_load(Ptr{Int32}(pointer(box_buf) + 4))
        max_x = unsafe_load(Ptr{Int32}(pointer(box_buf) + 8))
        max_y = unsafe_load(Ptr{Int32}(pointer(box_buf) + 12))
        w = Int(max_x - min_x + 1)
        h = Int(max_y - min_y + 1)
        return (h, w)
    end
end

# Read the preview attribute, if present. Returns the (height, width) matrix
# of NTuple{4, UInt8} RGBA pixels, or nothing if the attribute is absent.
function _read_preview_attribute(ctxt, part_idx)
    out = Ref(OpenEXR.Core.exr_attr_preview_t(
        UInt32(0), UInt32(0), Csize_t(0), C_NULL,
    ))
    res = OpenEXR.Core.exr_attr_get_preview(ctxt, part_idx, "preview", out)
    # A non-success return code means the preview attribute is absent on this
    # part — that's a valid configuration, not an error.
    res == Int32(OpenEXR.Core.EXR_ERR_SUCCESS) || return nothing
    pw = Int(out[].width)
    ph = Int(out[].height)
    (pw > 0 && ph > 0) || return nothing
    rgba_ptr = out[].rgba
    rgba_ptr == C_NULL && return nothing
    # Materialize into a (height, width) matrix of RGBA tuples by reading the
    # row-major byte stream the library hands back.
    preview = Matrix{NTuple{4, UInt8}}(undef, ph, pw)
    for i in 1:ph
        for j in 1:pw
            base = ((i - 1) * pw + (j - 1)) * 4
            r = unsafe_load(rgba_ptr, base + 1)
            g = unsafe_load(rgba_ptr, base + 2)
            b = unsafe_load(rgba_ptr, base + 3)
            a = unsafe_load(rgba_ptr, base + 4)
            preview[i, j] = (r, g, b, a)
        end
    end
    return preview
end

# Per-chunk decode loop for scanline parts. Mirrors `_write_scanlines`:
# iterates by chunk-start-y in steps of `scanlines_per_chunk`, and for each
# chunk reads `chunk_h` rows of pixels into a per-band buffer before copying
# them into the destination array.
function _read_scanlines_into!(
    ctxt, part_idx, channel_names, on_disk_T, T, data, w, h, path,
)
    n_bands = length(channel_names)
    spc_ref = Ref{Int32}(0)
    _check(
        OpenEXR.Core.exr_get_scanlines_per_chunk(ctxt, part_idx, spc_ref),
        :exr_get_scanlines_per_chunk, path,
        "could not query scanlines-per-chunk",
    )
    chunk_stride = Int(spc_ref[])

    chunk_info_buf = zeros(UInt8, sizeof(OpenEXR.Core.exr_chunk_info_t))
    pipeline_buf   = zeros(UInt8, sizeof(OpenEXR.Core.exr_decode_pipeline_t))

    # Build the name->band lookup once.
    name_to_band = Dict{String, Int}()
    for b in 1:n_bands
        name_to_band[String(channel_names[b])] = b
    end

    y_start = 0
    while y_start < h
        fill!(chunk_info_buf, 0x00)
        fill!(pipeline_buf, 0x00)
        chunk_h = min(chunk_stride, h - y_start)

        # One per-band buffer sized to (chunk_h rows × w cols) of on-disk eltype.
        row_buffers = Vector{Vector{on_disk_T}}(undef, n_bands)
        for b in 1:n_bands
            row_buffers[b] = Vector{on_disk_T}(undef, w * chunk_h)
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

            # The decode pipeline's channels array is keyed by the file's
            # declared channel name. We resolve to caller-supplied order via
            # name string and wire each band's destination buffer.
            pip = unsafe_load(pipeline_ptr)
            ch_arr_ptr = pip.channels
            n_decoded  = Int(pip.channel_count)
            for c in 1:n_decoded
                ch = unsafe_load(ch_arr_ptr, c)
                ch_name = unsafe_string(ch.channel_name)
                if !haskey(name_to_band, ch_name)
                    continue
                end
                b = name_to_band[ch_name]
                ch.user_pixel_stride = Int32(sizeof(on_disk_T))
                ch.user_line_stride  = Int32(w * sizeof(on_disk_T))
                ch.user_ptr          = Ptr{UInt8}(pointer(row_buffers[b]))
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

            # Copy each band's chunk buffer into the destination array,
            # converting back to user-facing eltype T.
            for b in 1:n_bands
                idx = 1
                for j in 0:(chunk_h - 1)
                    for i in 0:(w - 1)
                        @inbounds data[y_start + j + 1, i + 1, b] =
                            convert(T, row_buffers[b][idx])
                        idx += 1
                    end
                end
            end
        end
        y_start += chunk_stride
    end
    return nothing
end

# Per-tile decode loop.
function _read_tiles_into!(
    ctxt, part_idx, channel_names, on_disk_T, T, data, w, h, tile_size, path,
)
    n_bands  = length(channel_names)
    tile_w_d = Int(tile_size[1])
    tile_h_d = Int(tile_size[2])
    n_tx     = cld(w, tile_w_d)
    n_ty     = cld(h, tile_h_d)

    chunk_info_buf = zeros(UInt8, sizeof(OpenEXR.Core.exr_chunk_info_t))
    pipeline_buf   = zeros(UInt8, sizeof(OpenEXR.Core.exr_decode_pipeline_t))

    for ty in 0:(n_ty - 1)
        for tx in 0:(n_tx - 1)
            fill!(chunk_info_buf, 0x00)
            fill!(pipeline_buf, 0x00)

            tile_x0 = tx * tile_w_d
            tile_y0 = ty * tile_h_d
            tile_w  = min(tile_w_d, w - tile_x0)
            tile_h  = min(tile_h_d, h - tile_y0)

            tile_buffers = Vector{Vector{on_disk_T}}(undef, n_bands)
            for b in 1:n_bands
                tile_buffers[b] = Vector{on_disk_T}(undef, tile_w * tile_h)
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
                n_decoded  = Int(pip.channel_count)
                name_to_band = Dict{String, Int}()
                for b in 1:n_bands
                    name_to_band[String(channel_names[b])] = b
                end
                for c in 1:n_decoded
                    ch = unsafe_load(ch_arr_ptr, c)
                    ch_name = unsafe_string(ch.channel_name)
                    if !haskey(name_to_band, ch_name)
                        continue
                    end
                    b = name_to_band[ch_name]
                    ch.user_pixel_stride = Int32(sizeof(on_disk_T))
                    ch.user_line_stride  = Int32(tile_w * sizeof(on_disk_T))
                    ch.user_ptr          = Ptr{UInt8}(pointer(tile_buffers[b]))
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

                # Copy each band's tile buffer into the destination rectangle,
                # converting to the user-facing eltype T.
                for b in 1:n_bands
                    idx = 1
                    for j in 0:(tile_h - 1)
                        for i in 0:(tile_w - 1)
                            @inbounds data[tile_y0 + j + 1, tile_x0 + i + 1, b] =
                                convert(T, tile_buffers[b][idx])
                            idx += 1
                        end
                    end
                end
            end
        end
    end
    return nothing
end
