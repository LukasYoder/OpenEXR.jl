# src/io.jl
# Public load/save plumbing -- ExrIOError, _check, and (added in Chunk 6)
# the load(path) auto-detection logic.

"""
    ExrIOError(result_code, operation, path, message)

Exception raised when an OpenEXR C API call returns a non-success result.

Fields:
- `result_code::Int32` -- the `exr_result_t` value returned by libOpenEXRCore
- `operation::Symbol`  -- which Core function failed (e.g. `:exr_start_read`)
- `path::String`       -- file path involved (when relevant)
- `message::String`    -- human-readable explanation of the failure
"""
struct ExrIOError <: Exception
    result_code::Int32
    operation::Symbol
    path::String
    message::String
end

Base.showerror(io::IO, e::ExrIOError) = print(
    io, "OpenEXR I/O error during ", e.operation, " on \"", e.path,
    "\": ", e.message, " (result code: ", e.result_code, ")")

# Result-code check. Throws ExrIOError on any non-success result.
@inline function _check(result::Integer, op::Symbol, path::AbstractString, msg::AbstractString)
    result == Int32(OpenEXR.Core.EXR_ERR_SUCCESS) && return nothing
    throw(ExrIOError(Int32(result), op, String(path), msg))
end

# ---------------------------------------------------------------------------
# load(path) auto-detection
# ---------------------------------------------------------------------------

"""
    load(path::AbstractString)

Auto-detect the file's shape and return the most-specific Julia type:

1. Multi-part files (`exr_get_count > 1`) -> returns an `ExrFile`
   (Colors and SpectralCube are single-part by construction).
2. If the (single-part) file carries the `spectral_wavelengths_nm`
   attribute -> returns a `SpectralCube{T}`.
3. Else if the channel set is exactly one of `{Y}`, `{Y, A}`, `{R, G, B}`,
   `{R, G, B, A}` -> returns an `Array{<:Color, 2}` (existing legacy
   behaviour preserved for RGB users).
4. Else -> returns an `ExrFile`.

Use a type-asserted variant (`load(path, SpectralCube)`,
`load(path, ExrFile)`, `load(path, Array{C, 2})`) when you know exactly
what kind of file you are loading and want a clear error if the file's
shape does not match.
"""
function load(path::AbstractString)
    shape = _detect_shape(path)
    if shape === :spectral
        return load(path, SpectralCube)
    elseif shape === :colors
        # Delegate to the existing legacy path -- byte-identical to the
        # pre-redesign load(path) behaviour for {Y}, {Y, A}, {R, G, B},
        # {R, G, B, A} channel sets.
        return _legacy_load_colors(path)
    else  # :generic
        return load(path, ExrFile)
    end
end

# Header-only shape detector. Returns :spectral, :colors, or :generic.
# Does NOT decode any pixel data -- it is wasteful to call this before
# deciding to delegate to a full loader, so we only inspect the header.
function _detect_shape(path::AbstractString)
    ctxt_ref = Ref{OpenEXR.Core.exr_context_t}(C_NULL)
    _check(
        OpenEXR.Core.exr_start_read(ctxt_ref, path, C_NULL),
        :exr_start_read, path, "could not open file for shape detection",
    )
    try
        # Multi-part files cannot be Colors (the legacy load returns a 2D
        # Array{<:Color, 2}) and cannot be SpectralCube (single-part by
        # construction) -- always route to ExrFile.
        part_count_ref = Ref{Cint}(0)
        _check(
            OpenEXR.Core.exr_get_count(ctxt_ref[], part_count_ref),
            :exr_get_count, path, "could not enumerate parts",
        )
        Int(part_count_ref[]) > 1 && return :generic

        # Spectral marker check -- the spectral_wavelengths_nm attribute is
        # the canonical sign that this file should round-trip as a
        # SpectralCube. Reuse the existing attribute reader (handles
        # reserved-name filtering and type-tagged decoding).
        attrs = _read_attributes(ctxt_ref[], Cint(0))
        haskey(attrs, "spectral_wavelengths_nm") && return :spectral

        # Channel-set check -- inspect the part's channel names without
        # decoding pixel data. The Set equality is intentional: the EXR
        # spec gives channels in alphabetical order, which already matches
        # canonical RGB/RGBA/Y/YA ordering, but Set equality is robust to
        # any deviation a future library version might introduce.
        chlist_ptr_ref = Ref{Ptr{OpenEXR.Core.exr_attr_chlist_t}}(C_NULL)
        _check(
            OpenEXR.Core.exr_get_channels(ctxt_ref[], Cint(0), chlist_ptr_ref),
            :exr_get_channels, path, "could not read channel list",
        )
        chlist = unsafe_load(chlist_ptr_ref[])
        n = Int(chlist.num_channels)
        # The Julia mirror of exr_attr_chlist_entry_t does not match the
        # flat C layout (the nested string is boxed in Julia, inlined in
        # C). We read each entry's name via the raw byte-offset convention
        # already in use elsewhere in this package (see spectral_cube.jl
        # and exr_file.jl for the same _CHLIST_ENTRY_STRIDE pattern).
        names = Set{String}()
        entries_base = Ptr{UInt8}(chlist.entries)
        for i in 0:(n - 1)
            entry_base = entries_base + i * _CHLIST_ENTRY_STRIDE
            name_str_ptr = unsafe_load(
                Ptr{Cstring}(entry_base + _CHLIST_ENTRY_NAME_STR_OFF),
            )
            push!(names, unsafe_string(name_str_ptr))
        end
        if names == Set(["Y"]) ||
           names == Set(["Y", "A"]) ||
           names == Set(["R", "G", "B"]) ||
           names == Set(["R", "G", "B", "A"])
            return :colors
        end
        return :generic
    finally
        OpenEXR.Core.exr_finish(ctxt_ref)
    end
end

"""
    load(path::AbstractString, ::Type{Array{C, 2}}) where {C <: Colorant}

Type-asserted load: returns the file's image data as
`Array{C, 2}`. Throws `ArgumentError` if the file's channel set is not
one of the four Colors-recognized layouts ({Y}, {Y, A}, {R, G, B},
{R, G, B, A}), or if the Colors auto-conversion produces a different
concrete element type than `C` (e.g. asking for `RGB{Float16}` on a
file with an alpha channel).

Use this variant when you want a clear, type-stable failure for files
that aren't standard Colors images. For non-Colors EXR files, use
`load(path, SpectralCube)` (spectral data) or `load(path, ExrFile)`
(generic).
"""
function load(path::AbstractString, ::Type{Array{C, 2}}) where {C <: Colorant}
    shape = _detect_shape(path)
    shape === :colors || throw(ArgumentError(
        "file \"$path\" was loaded with explicit Array{$C, 2} target, but " *
        "its shape is :$(shape) (not one of {Y}, {Y, A}, {R, G, B}, " *
        "{R, G, B, A}). Use `load(path, SpectralCube)` for spectral data " *
        "or `load(path, ExrFile)` for generic access."))
    img = _legacy_load_colors(path)
    img isa Array{C, 2} || throw(ArgumentError(
        "file \"$path\" loads as $(typeof(img)) under Colors auto-" *
        "conversion, not the requested $(Array{C, 2}). Mismatched channel " *
        "set."))
    return img
end
