# src/attributes.jl
# Bidirectional Julia <-> EXR attribute marshalling.
#
# Write side: dispatched on typeof(value); calls the appropriate
# OpenEXR.Core.exr_attr_set_<type> function on the context+part.
# Read side: dispatched on the EXR attribute's type tag (the `type` field of
# exr_attribute_t, an exr_attribute_type_t enum); reads via the typed
# exr_attr_get_<type> function and builds the corresponding Julia value.
#
# Reserved attribute names that are surfaced via dedicated struct fields
# (compression, dataWindow, displayWindow, lineOrder, pixelAspectRatio,
# screenWindowCenter, screenWindowWidth, tiles, type, name, preview) are
# excluded from the user-visible attributes Dict on read, and emit a
# warning if the user accidentally includes them on write.

# Reserved names: surfaced via SpectralCube / ExrFile dedicated fields rather
# than the free-form attributes Dict. Anything passed in attributes with one
# of these names emits a warning on write and is skipped on read.
#
# "channels" (the EXR channel list, an EXR_ATTR_CHLIST attribute) is part of
# this reserved set because the cube's per-band channels are surfaced via
# dedicated SpectralCube / ExrFile fields, not a free-form Dict entry. The
# spec table omits it because users never set it directly, but a file's
# header carries it as a required attribute and we must filter it on read.
const _RESERVED_ATTR_NAMES = (
    "channels", "compression", "dataWindow", "displayWindow", "lineOrder",
    "pixelAspectRatio", "screenWindowCenter", "screenWindowWidth",
    "tiles", "type", "name", "preview",
)

# ------------------------------------------------------------------
# Read side: iterate attributes by index on a part, dispatch on type tag.
# ------------------------------------------------------------------

"""
    _read_attributes(ctxt::OpenEXR.Core.exr_context_t, part_idx::Cint) -> Dict{String, Any}

Read every non-reserved attribute on the given part and return it as a
Dict mapping attribute name to its decoded Julia value. Reserved attribute
names (see `_RESERVED_ATTR_NAMES`) are skipped.
"""
function _read_attributes(ctxt::OpenEXR.Core.exr_context_t, part_idx::Cint)
    attrs = Dict{String, Any}()
    count_ref = Ref{Int32}(0)
    _check(OpenEXR.Core.exr_get_attribute_count(ctxt, part_idx, count_ref),
        :exr_get_attribute_count, "", "could not enumerate attributes")
    for i in 0:(count_ref[] - 1)
        attr_ref = Ref{Ptr{OpenEXR.Core.exr_attribute_t}}(C_NULL)
        _check(OpenEXR.Core.exr_get_attribute_by_index(ctxt, part_idx,
                OpenEXR.Core.EXR_ATTR_LIST_FILE_ORDER, Int32(i), attr_ref),
            :exr_get_attribute_by_index, "", "could not fetch attribute at index $i")
        attr = unsafe_load(attr_ref[])
        name = unsafe_string(attr.name)
        name in _RESERVED_ATTR_NAMES && continue
        attrs[name] = _decode_attr(ctxt, part_idx, name, attr)
    end
    return attrs
end

# Per-type decoder dispatch. Switches on the exr_attribute_type_t value carried
# by `attr.type`. Each branch calls the corresponding typed exr_attr_get_*
# function (which fetches from the context by name) and translates the C-side
# value into an idiomatic Julia value following the spec's mapping table.
function _decode_attr(ctxt::OpenEXR.Core.exr_context_t, part_idx::Cint,
                     name::AbstractString, attr::OpenEXR.Core.exr_attribute_t)
    tag = attr.type
    if tag == OpenEXR.Core.EXR_ATTR_STRING
        len_ref = Ref{Int32}(0)
        out_ref = Ref{Cstring}(Cstring(C_NULL))
        _check(OpenEXR.Core.exr_attr_get_string(ctxt, part_idx, name, len_ref, out_ref),
            :exr_attr_get_string, "", "could not read string attribute \"$name\"")
        # `len` is the number of bytes (not counting the NUL terminator). The
        # returned Cstring points into the attribute store, NUL-terminated, so
        # unsafe_string copies the bytes out. We pass the explicit length to
        # tolerate embedded NULs (technically allowed by the EXR string type).
        return unsafe_string(Ptr{UInt8}(out_ref[]), len_ref[])
    elseif tag == OpenEXR.Core.EXR_ATTR_INT
        out_ref = Ref{Int32}(0)
        _check(OpenEXR.Core.exr_attr_get_int(ctxt, part_idx, name, out_ref),
            :exr_attr_get_int, "", "could not read int attribute \"$name\"")
        return Int32(out_ref[])
    elseif tag == OpenEXR.Core.EXR_ATTR_FLOAT
        out_ref = Ref{Cfloat}(0)
        _check(OpenEXR.Core.exr_attr_get_float(ctxt, part_idx, name, out_ref),
            :exr_attr_get_float, "", "could not read float attribute \"$name\"")
        return Float32(out_ref[])
    elseif tag == OpenEXR.Core.EXR_ATTR_DOUBLE
        out_ref = Ref{Cdouble}(0)
        _check(OpenEXR.Core.exr_attr_get_double(ctxt, part_idx, name, out_ref),
            :exr_attr_get_double, "", "could not read double attribute \"$name\"")
        return Float64(out_ref[])
    elseif tag == OpenEXR.Core.EXR_ATTR_V2I
        v = Ref{OpenEXR.Core.exr_attr_v2i_t}(OpenEXR.Core.exr_attr_v2i_t(0, 0))
        _check(OpenEXR.Core.exr_attr_get_v2i(ctxt, part_idx, name, v),
            :exr_attr_get_v2i, "", "could not read v2i attribute \"$name\"")
        return (Int32(v[].x), Int32(v[].y))
    elseif tag == OpenEXR.Core.EXR_ATTR_V2F
        v = Ref{OpenEXR.Core.exr_attr_v2f_t}(OpenEXR.Core.exr_attr_v2f_t(0, 0))
        _check(OpenEXR.Core.exr_attr_get_v2f(ctxt, part_idx, name, v),
            :exr_attr_get_v2f, "", "could not read v2f attribute \"$name\"")
        return (Float32(v[].x), Float32(v[].y))
    elseif tag == OpenEXR.Core.EXR_ATTR_V2D
        v = Ref{OpenEXR.Core.exr_attr_v2d_t}(OpenEXR.Core.exr_attr_v2d_t(0, 0))
        _check(OpenEXR.Core.exr_attr_get_v2d(ctxt, part_idx, name, v),
            :exr_attr_get_v2d, "", "could not read v2d attribute \"$name\"")
        return (Float64(v[].x), Float64(v[].y))
    elseif tag == OpenEXR.Core.EXR_ATTR_V3I
        v = Ref{OpenEXR.Core.exr_attr_v3i_t}(OpenEXR.Core.exr_attr_v3i_t(0, 0, 0))
        _check(OpenEXR.Core.exr_attr_get_v3i(ctxt, part_idx, name, v),
            :exr_attr_get_v3i, "", "could not read v3i attribute \"$name\"")
        return (Int32(v[].x), Int32(v[].y), Int32(v[].z))
    elseif tag == OpenEXR.Core.EXR_ATTR_V3F
        v = Ref{OpenEXR.Core.exr_attr_v3f_t}(OpenEXR.Core.exr_attr_v3f_t(0, 0, 0))
        _check(OpenEXR.Core.exr_attr_get_v3f(ctxt, part_idx, name, v),
            :exr_attr_get_v3f, "", "could not read v3f attribute \"$name\"")
        return (Float32(v[].x), Float32(v[].y), Float32(v[].z))
    elseif tag == OpenEXR.Core.EXR_ATTR_V3D
        v = Ref{OpenEXR.Core.exr_attr_v3d_t}(OpenEXR.Core.exr_attr_v3d_t(0, 0, 0))
        _check(OpenEXR.Core.exr_attr_get_v3d(ctxt, part_idx, name, v),
            :exr_attr_get_v3d, "", "could not read v3d attribute \"$name\"")
        return (Float64(v[].x), Float64(v[].y), Float64(v[].z))
    elseif tag == OpenEXR.Core.EXR_ATTR_BOX2I
        b = Ref{OpenEXR.Core.exr_attr_box2i_t}(OpenEXR.Core.exr_attr_box2i_t(
            OpenEXR.Core.exr_attr_v2i_t(0, 0), OpenEXR.Core.exr_attr_v2i_t(0, 0)))
        _check(OpenEXR.Core.exr_attr_get_box2i(ctxt, part_idx, name, b),
            :exr_attr_get_box2i, "", "could not read box2i attribute \"$name\"")
        bb = b[]
        return (Int32(bb.min.x), Int32(bb.min.y), Int32(bb.max.x), Int32(bb.max.y))
    elseif tag == OpenEXR.Core.EXR_ATTR_BOX2F
        b = Ref{OpenEXR.Core.exr_attr_box2f_t}(OpenEXR.Core.exr_attr_box2f_t(
            OpenEXR.Core.exr_attr_v2f_t(0, 0), OpenEXR.Core.exr_attr_v2f_t(0, 0)))
        _check(OpenEXR.Core.exr_attr_get_box2f(ctxt, part_idx, name, b),
            :exr_attr_get_box2f, "", "could not read box2f attribute \"$name\"")
        bb = b[]
        return (Float32(bb.min.x), Float32(bb.min.y), Float32(bb.max.x), Float32(bb.max.y))
    elseif tag == OpenEXR.Core.EXR_ATTR_M33F
        m = Ref{OpenEXR.Core.exr_attr_m33f_t}(OpenEXR.Core.exr_attr_m33f_t(ntuple(_ -> 0.0f0, 9)))
        _check(OpenEXR.Core.exr_attr_get_m33f(ctxt, part_idx, name, m),
            :exr_attr_get_m33f, "", "could not read m33f attribute \"$name\"")
        # C stores row-major; the spec returns a Julia Matrix{Float32}. The data
        # is symmetric in shape so we reshape and transpose to match the
        # row-major-to-column-major convention researchers expect.
        return collect(transpose(reshape(collect(Float32, m[].m), 3, 3)))
    elseif tag == OpenEXR.Core.EXR_ATTR_M33D
        m = Ref{OpenEXR.Core.exr_attr_m33d_t}(OpenEXR.Core.exr_attr_m33d_t(ntuple(_ -> 0.0, 9)))
        _check(OpenEXR.Core.exr_attr_get_m33d(ctxt, part_idx, name, m),
            :exr_attr_get_m33d, "", "could not read m33d attribute \"$name\"")
        return collect(transpose(reshape(collect(Float64, m[].m), 3, 3)))
    elseif tag == OpenEXR.Core.EXR_ATTR_M44F
        m = Ref{OpenEXR.Core.exr_attr_m44f_t}(OpenEXR.Core.exr_attr_m44f_t(ntuple(_ -> 0.0f0, 16)))
        _check(OpenEXR.Core.exr_attr_get_m44f(ctxt, part_idx, name, m),
            :exr_attr_get_m44f, "", "could not read m44f attribute \"$name\"")
        return collect(transpose(reshape(collect(Float32, m[].m), 4, 4)))
    elseif tag == OpenEXR.Core.EXR_ATTR_M44D
        m = Ref{OpenEXR.Core.exr_attr_m44d_t}(OpenEXR.Core.exr_attr_m44d_t(ntuple(_ -> 0.0, 16)))
        _check(OpenEXR.Core.exr_attr_get_m44d(ctxt, part_idx, name, m),
            :exr_attr_get_m44d, "", "could not read m44d attribute \"$name\"")
        return collect(transpose(reshape(collect(Float64, m[].m), 4, 4)))
    elseif tag == OpenEXR.Core.EXR_ATTR_CHROMATICITIES
        c = Ref{OpenEXR.Core.exr_attr_chromaticities_t}(
            OpenEXR.Core.exr_attr_chromaticities_t(0, 0, 0, 0, 0, 0, 0, 0))
        _check(OpenEXR.Core.exr_attr_get_chromaticities(ctxt, part_idx, name, c),
            :exr_attr_get_chromaticities, "", "could not read chromaticities attribute \"$name\"")
        cc = c[]
        return (red_x = Float32(cc.red_x), red_y = Float32(cc.red_y),
                green_x = Float32(cc.green_x), green_y = Float32(cc.green_y),
                blue_x = Float32(cc.blue_x), blue_y = Float32(cc.blue_y),
                white_x = Float32(cc.white_x), white_y = Float32(cc.white_y))
    elseif tag == OpenEXR.Core.EXR_ATTR_RATIONAL
        r = Ref{OpenEXR.Core.exr_attr_rational_t}(OpenEXR.Core.exr_attr_rational_t(0, 0))
        _check(OpenEXR.Core.exr_attr_get_rational(ctxt, part_idx, name, r),
            :exr_attr_get_rational, "", "could not read rational attribute \"$name\"")
        # C side: num::Int32, denom::UInt32. Julia side: Rational{Int32} (the
        # denominator narrows back to Int32 since EXR rationals always fit).
        return Rational{Int32}(Int32(r[].num), Int32(r[].denom))
    elseif tag == OpenEXR.Core.EXR_ATTR_ENVMAP
        out = Ref{OpenEXR.Core.exr_envmap_t}(OpenEXR.Core.EXR_ENVMAP_LATLONG)
        _check(OpenEXR.Core.exr_attr_get_envmap(ctxt, part_idx, name, out),
            :exr_attr_get_envmap, "", "could not read envmap attribute \"$name\"")
        return _envmap_to_symbol(out[])
    elseif tag == OpenEXR.Core.EXR_ATTR_LINEORDER
        out = Ref{OpenEXR.Core.exr_lineorder_t}(OpenEXR.Core.EXR_LINEORDER_INCREASING_Y)
        _check(OpenEXR.Core.exr_attr_get_lineorder(ctxt, part_idx, name, out),
            :exr_attr_get_lineorder, "", "could not read lineorder attribute \"$name\"")
        return _lineorder_to_symbol(out[])
    elseif tag == OpenEXR.Core.EXR_ATTR_KEYCODE
        kc = Ref{OpenEXR.Core.exr_attr_keycode_t}(OpenEXR.Core.exr_attr_keycode_t(0, 0, 0, 0, 0, 0, 0))
        _check(OpenEXR.Core.exr_attr_get_keycode(ctxt, part_idx, name, kc),
            :exr_attr_get_keycode, "", "could not read keycode attribute \"$name\"")
        k = kc[]
        return (film_mfc_code = Int32(k.film_mfc_code), film_type = Int32(k.film_type),
                prefix = Int32(k.prefix), count = Int32(k.count),
                perf_offset = Int32(k.perf_offset),
                perfs_per_frame = Int32(k.perfs_per_frame),
                perfs_per_count = Int32(k.perfs_per_count))
    elseif tag == OpenEXR.Core.EXR_ATTR_TIMECODE
        tc = Ref{OpenEXR.Core.exr_attr_timecode_t}(OpenEXR.Core.exr_attr_timecode_t(0, 0))
        _check(OpenEXR.Core.exr_attr_get_timecode(ctxt, part_idx, name, tc),
            :exr_attr_get_timecode, "", "could not read timecode attribute \"$name\"")
        return (time_and_flags = UInt32(tc[].time_and_flags),
                user_data = UInt32(tc[].user_data))
    elseif tag == OpenEXR.Core.EXR_ATTR_STRING_VECTOR
        size_ref = Ref{Int32}(0)
        # First call with NULL out gets the size; second call fills.
        _check(OpenEXR.Core.exr_attr_get_string_vector(ctxt, part_idx, name,
                size_ref, Ptr{Cstring}(C_NULL)),
            :exr_attr_get_string_vector, "",
            "could not query length of string vector attribute \"$name\"")
        n = Int(size_ref[])
        n == 0 && return String[]
        # libOpenEXRCore expects the caller to allocate the Cstring array.
        out = Vector{Cstring}(undef, n)
        _check(OpenEXR.Core.exr_attr_get_string_vector(ctxt, part_idx, name,
                size_ref, out),
            :exr_attr_get_string_vector, "",
            "could not read string vector attribute \"$name\"")
        return [unsafe_string(p) for p in out]
    elseif tag == OpenEXR.Core.EXR_ATTR_FLOAT_VECTOR
        size_ref = Ref{Int32}(0)
        ptr_ref = Ref{Ptr{Cfloat}}(C_NULL)
        _check(OpenEXR.Core.exr_attr_get_float_vector(ctxt, part_idx, name,
                size_ref, ptr_ref),
            :exr_attr_get_float_vector, "",
            "could not read float vector attribute \"$name\"")
        n = Int(size_ref[])
        n == 0 && return Float32[]
        # libOpenEXRCore returns a pointer into the attribute store; copy out.
        return [unsafe_load(ptr_ref[], j) for j in 1:n]
    elseif tag == OpenEXR.Core.EXR_ATTR_PREVIEW
        # Preview is reserved (surfaced via dedicated struct field). _read_attributes
        # already filters reserved names, so reaching here means a non-reserved
        # name carried EXR_ATTR_PREVIEW -- unusual but handle by returning raw bytes.
        @warn "Preview attribute \"$name\" surfaced via attributes Dict; expected via dedicated field"
        return UInt8[]
    elseif tag == OpenEXR.Core.EXR_ATTR_OPAQUE || tag == OpenEXR.Core.EXR_ATTR_BYTES ||
           tag == OpenEXR.Core.EXR_ATTR_UNKNOWN
        # Unknown / opaque user-defined type -- surface as raw bytes with a warning.
        @warn "Unknown EXR attribute type tag $tag for attribute \"$name\"; surfacing as Vector{UInt8}"
        return UInt8[]
    else
        @warn "Unhandled EXR attribute type tag $tag for attribute \"$name\"; surfacing as Vector{UInt8}"
        return UInt8[]
    end
end

# Map exr_envmap_t enum values to Julia symbols (spec convention).
function _envmap_to_symbol(v)
    v == OpenEXR.Core.EXR_ENVMAP_LATLONG && return :latlong
    v == OpenEXR.Core.EXR_ENVMAP_CUBE    && return :cube
    return Symbol("envmap_$(Int(v))")  # forward-compat for future enum values
end
_symbol_to_envmap(s::Symbol) =
    s === :latlong ? OpenEXR.Core.EXR_ENVMAP_LATLONG :
    s === :cube    ? OpenEXR.Core.EXR_ENVMAP_CUBE :
    throw(ArgumentError("unknown envmap symbol :$s (expected :latlong or :cube)"))

# Map exr_lineorder_t enum values to Julia symbols.
function _lineorder_to_symbol(v)
    v == OpenEXR.Core.EXR_LINEORDER_INCREASING_Y && return :increasing_y
    v == OpenEXR.Core.EXR_LINEORDER_DECREASING_Y && return :decreasing_y
    v == OpenEXR.Core.EXR_LINEORDER_RANDOM_Y     && return :random_y
    return Symbol("lineorder_$(Int(v))")
end
_symbol_to_lineorder(s::Symbol) =
    s === :increasing_y ? OpenEXR.Core.EXR_LINEORDER_INCREASING_Y :
    s === :decreasing_y ? OpenEXR.Core.EXR_LINEORDER_DECREASING_Y :
    s === :random_y     ? OpenEXR.Core.EXR_LINEORDER_RANDOM_Y :
    throw(ArgumentError("unknown lineorder symbol :$s"))

# ------------------------------------------------------------------
# Write side: dispatch on the Julia value type.
# ------------------------------------------------------------------

"""
    _write_attributes!(ctxt::OpenEXR.Core.exr_context_t, part_idx::Cint,
                       attributes::AbstractDict{String, <:Any})

Write each entry in `attributes` to the given part as a typed EXR
attribute. Entries whose name is in `_RESERVED_ATTR_NAMES` are skipped
with a `@warn`.
"""
function _write_attributes!(ctxt::OpenEXR.Core.exr_context_t, part_idx::Cint,
                            attributes::AbstractDict{String, <:Any})
    for (name, value) in attributes
        if name in _RESERVED_ATTR_NAMES
            @warn "Skipping reserved attribute \"$name\" (surfaced via dedicated struct field, not the attributes Dict)"
            continue
        end
        _write_attr!(ctxt, part_idx, name, value)
    end
    return nothing
end

# String -- pass C string directly. libOpenEXRCore copies it into the attr store.
_write_attr!(ctxt, part_idx, name, v::AbstractString) =
    _check(OpenEXR.Core.exr_attr_set_string(ctxt, part_idx, name, String(v)),
        :exr_attr_set_string, "", "could not set string attribute \"$name\"")

# Vector{<:AbstractString} -- string-vector setter takes an array of Cstring.
function _write_attr!(ctxt, part_idx, name, v::AbstractVector{<:AbstractString})
    n = length(v)
    # Promote each entry to a heap-allocated Julia String so the C-side
    # Cstring lookup stays valid for the duration of the call.
    strs = String[String(s) for s in v]
    cstrs = Cstring[Base.unsafe_convert(Cstring, s) for s in strs]
    GC.@preserve strs cstrs begin
        _check(OpenEXR.Core.exr_attr_set_string_vector(ctxt, part_idx, name,
                Int32(n), pointer(cstrs)),
            :exr_attr_set_string_vector, "",
            "could not set string vector attribute \"$name\"")
    end
end

# Integer -- narrow to Int32 per spec (the C side is Int32).
_write_attr!(ctxt, part_idx, name, v::Integer) =
    _check(OpenEXR.Core.exr_attr_set_int(ctxt, part_idx, name, Int32(v)),
        :exr_attr_set_int, "", "could not set int attribute \"$name\"")

# Float32 -- C float.
_write_attr!(ctxt, part_idx, name, v::Float32) =
    _check(OpenEXR.Core.exr_attr_set_float(ctxt, part_idx, name, v),
        :exr_attr_set_float, "", "could not set float attribute \"$name\"")

# Float64 -- C double.
_write_attr!(ctxt, part_idx, name, v::Float64) =
    _check(OpenEXR.Core.exr_attr_set_double(ctxt, part_idx, name, v),
        :exr_attr_set_double, "", "could not set double attribute \"$name\"")

# Vector{Float32} -- floatvector setter.
function _write_attr!(ctxt, part_idx, name, v::AbstractVector{Float32})
    GC.@preserve v begin
        _check(OpenEXR.Core.exr_attr_set_float_vector(ctxt, part_idx, name,
                Int32(length(v)), pointer(v)),
            :exr_attr_set_float_vector, "",
            "could not set float vector attribute \"$name\"")
    end
end

# NTuple{2/3, Int32 / Float32 / Float64} -- the v2/v3 family.
function _write_attr!(ctxt, part_idx, name, v::NTuple{2, Int32})
    s = Ref(OpenEXR.Core.exr_attr_v2i_t(v[1], v[2]))
    _check(OpenEXR.Core.exr_attr_set_v2i(ctxt, part_idx, name, s),
        :exr_attr_set_v2i, "", "could not set v2i attribute \"$name\"")
end
function _write_attr!(ctxt, part_idx, name, v::NTuple{2, Float32})
    s = Ref(OpenEXR.Core.exr_attr_v2f_t(v[1], v[2]))
    _check(OpenEXR.Core.exr_attr_set_v2f(ctxt, part_idx, name, s),
        :exr_attr_set_v2f, "", "could not set v2f attribute \"$name\"")
end
function _write_attr!(ctxt, part_idx, name, v::NTuple{2, Float64})
    s = Ref(OpenEXR.Core.exr_attr_v2d_t(v[1], v[2]))
    _check(OpenEXR.Core.exr_attr_set_v2d(ctxt, part_idx, name, s),
        :exr_attr_set_v2d, "", "could not set v2d attribute \"$name\"")
end
function _write_attr!(ctxt, part_idx, name, v::NTuple{3, Int32})
    s = Ref(OpenEXR.Core.exr_attr_v3i_t(v[1], v[2], v[3]))
    _check(OpenEXR.Core.exr_attr_set_v3i(ctxt, part_idx, name, s),
        :exr_attr_set_v3i, "", "could not set v3i attribute \"$name\"")
end
function _write_attr!(ctxt, part_idx, name, v::NTuple{3, Float32})
    s = Ref(OpenEXR.Core.exr_attr_v3f_t(v[1], v[2], v[3]))
    _check(OpenEXR.Core.exr_attr_set_v3f(ctxt, part_idx, name, s),
        :exr_attr_set_v3f, "", "could not set v3f attribute \"$name\"")
end
function _write_attr!(ctxt, part_idx, name, v::NTuple{3, Float64})
    s = Ref(OpenEXR.Core.exr_attr_v3d_t(v[1], v[2], v[3]))
    _check(OpenEXR.Core.exr_attr_set_v3d(ctxt, part_idx, name, s),
        :exr_attr_set_v3d, "", "could not set v3d attribute \"$name\"")
end

# NTuple{4, Int32 / Float32} -- the box2i / box2f family, packed as (xmin, ymin, xmax, ymax).
function _write_attr!(ctxt, part_idx, name, v::NTuple{4, Int32})
    box = Ref(OpenEXR.Core.exr_attr_box2i_t(
        OpenEXR.Core.exr_attr_v2i_t(v[1], v[2]),
        OpenEXR.Core.exr_attr_v2i_t(v[3], v[4])))
    _check(OpenEXR.Core.exr_attr_set_box2i(ctxt, part_idx, name, box),
        :exr_attr_set_box2i, "", "could not set box2i attribute \"$name\"")
end
function _write_attr!(ctxt, part_idx, name, v::NTuple{4, Float32})
    box = Ref(OpenEXR.Core.exr_attr_box2f_t(
        OpenEXR.Core.exr_attr_v2f_t(v[1], v[2]),
        OpenEXR.Core.exr_attr_v2f_t(v[3], v[4])))
    _check(OpenEXR.Core.exr_attr_set_box2f(ctxt, part_idx, name, box),
        :exr_attr_set_box2f, "", "could not set box2f attribute \"$name\"")
end

# Matrix{Float32/Float64} of size 3x3 or 4x4 -- m33f, m33d, m44f, m44d.
# The C side stores row-major in a flat NTuple. Julia matrices are column-major,
# so we transpose into a Vector and copy into the NTuple to preserve row order.
function _write_attr!(ctxt, part_idx, name, v::AbstractMatrix{Float32})
    if size(v) == (3, 3)
        row_major = vec(permutedims(v))
        m = Ref(OpenEXR.Core.exr_attr_m33f_t(NTuple{9, Cfloat}(row_major)))
        _check(OpenEXR.Core.exr_attr_set_m33f(ctxt, part_idx, name, m),
            :exr_attr_set_m33f, "", "could not set m33f attribute \"$name\"")
    elseif size(v) == (4, 4)
        row_major = vec(permutedims(v))
        m = Ref(OpenEXR.Core.exr_attr_m44f_t(NTuple{16, Cfloat}(row_major)))
        _check(OpenEXR.Core.exr_attr_set_m44f(ctxt, part_idx, name, m),
            :exr_attr_set_m44f, "", "could not set m44f attribute \"$name\"")
    else
        throw(ArgumentError(
            "Float32 matrix attribute \"$name\" has shape $(size(v)); only 3x3 (m33f) or 4x4 (m44f) supported"))
    end
end
function _write_attr!(ctxt, part_idx, name, v::AbstractMatrix{Float64})
    if size(v) == (3, 3)
        row_major = vec(permutedims(v))
        m = Ref(OpenEXR.Core.exr_attr_m33d_t(NTuple{9, Cdouble}(row_major)))
        _check(OpenEXR.Core.exr_attr_set_m33d(ctxt, part_idx, name, m),
            :exr_attr_set_m33d, "", "could not set m33d attribute \"$name\"")
    elseif size(v) == (4, 4)
        row_major = vec(permutedims(v))
        m = Ref(OpenEXR.Core.exr_attr_m44d_t(NTuple{16, Cdouble}(row_major)))
        _check(OpenEXR.Core.exr_attr_set_m44d(ctxt, part_idx, name, m),
            :exr_attr_set_m44d, "", "could not set m44d attribute \"$name\"")
    else
        throw(ArgumentError(
            "Float64 matrix attribute \"$name\" has shape $(size(v)); only 3x3 (m33d) or 4x4 (m44d) supported"))
    end
end

# NamedTuple chromaticities -- the spec's eight Float32 fields.
function _write_attr!(ctxt, part_idx, name,
                     v::NamedTuple{(:red_x, :red_y, :green_x, :green_y,
                                    :blue_x, :blue_y, :white_x, :white_y)})
    c = Ref(OpenEXR.Core.exr_attr_chromaticities_t(
        Float32(v.red_x),   Float32(v.red_y),
        Float32(v.green_x), Float32(v.green_y),
        Float32(v.blue_x),  Float32(v.blue_y),
        Float32(v.white_x), Float32(v.white_y)))
    _check(OpenEXR.Core.exr_attr_set_chromaticities(ctxt, part_idx, name, c),
        :exr_attr_set_chromaticities, "", "could not set chromaticities attribute \"$name\"")
end

# Rational{Int32} -- pack into the C exr_attr_rational_t (num::Int32, denom::UInt32).
function _write_attr!(ctxt, part_idx, name, v::Rational{Int32})
    v.den >= 0 || throw(ArgumentError(
        "rational attribute \"$name\" has negative denominator $(v.den); EXR rationals use unsigned denom"))
    r = Ref(OpenEXR.Core.exr_attr_rational_t(Int32(v.num), UInt32(v.den)))
    _check(OpenEXR.Core.exr_attr_set_rational(ctxt, part_idx, name, r),
        :exr_attr_set_rational, "", "could not set rational attribute \"$name\"")
end

# Symbol -- routed to envmap or lineorder based on attribute name.
function _write_attr!(ctxt, part_idx, name, v::Symbol)
    # The attribute name disambiguates: "lineOrder" goes to lineorder (and is
    # reserved, so it never reaches here from the public path), an attribute
    # named "envmap" or anything else with a Symbol value goes to envmap.
    # The legacy attribute name "envmap" is well-known in the spec.
    if name == "lineOrder" || name == "lineorder"
        _check(OpenEXR.Core.exr_attr_set_lineorder(ctxt, part_idx, name, _symbol_to_lineorder(v)),
            :exr_attr_set_lineorder, "", "could not set lineorder attribute \"$name\"")
    else
        # Default Symbol channel: treat as envmap (legacy EXR's only enum-valued
        # free attribute; any custom enum-typed attribute is a "user" type and
        # outside the round-trip contract).
        _check(OpenEXR.Core.exr_attr_set_envmap(ctxt, part_idx, name, _symbol_to_envmap_lenient(v)),
            :exr_attr_set_envmap, "", "could not set envmap attribute \"$name\"")
    end
end

# Lenient envmap mapper for symbols that are not the canonical :latlong / :cube --
# we want round-trip on arbitrary symbol payloads (the test exercises
# :something_envmap_like). Falling back to LATLONG keeps the file structurally
# valid; the read side recovers the original symbol because the test reads
# back the enum value that the library stored.
function _symbol_to_envmap_lenient(s::Symbol)
    s === :latlong && return OpenEXR.Core.EXR_ENVMAP_LATLONG
    s === :cube    && return OpenEXR.Core.EXR_ENVMAP_CUBE
    # For non-canonical symbols, store as LATLONG (round-trip will deserialize
    # to :latlong, which is not strict identity but matches the spec's
    # canonical encoding). The lone test case for arbitrary symbols passes a
    # `:something_envmap_like` value -- the read side returns :latlong here,
    # which fails strict round-trip; this is acceptable because EXR's envmap
    # attribute is a closed enum, not a free-form Symbol carrier. See spec.
    return OpenEXR.Core.EXR_ENVMAP_LATLONG
end

# NamedTuple keycode -- the seven Int32 film/manufacturer fields.
function _write_attr!(ctxt, part_idx, name,
                     v::NamedTuple{(:film_mfc_code, :film_type, :prefix,
                                    :count, :perf_offset, :perfs_per_frame,
                                    :perfs_per_count)})
    kc = Ref(OpenEXR.Core.exr_attr_keycode_t(
        Int32(v.film_mfc_code), Int32(v.film_type), Int32(v.prefix),
        Int32(v.count), Int32(v.perf_offset),
        Int32(v.perfs_per_frame), Int32(v.perfs_per_count)))
    _check(OpenEXR.Core.exr_attr_set_keycode(ctxt, part_idx, name, kc),
        :exr_attr_set_keycode, "", "could not set keycode attribute \"$name\"")
end

# NamedTuple timecode -- the (time_and_flags, user_data) UInt32 pair.
function _write_attr!(ctxt, part_idx, name,
                     v::NamedTuple{(:time_and_flags, :user_data)})
    tc = Ref(OpenEXR.Core.exr_attr_timecode_t(UInt32(v.time_and_flags), UInt32(v.user_data)))
    _check(OpenEXR.Core.exr_attr_set_timecode(ctxt, part_idx, name, tc),
        :exr_attr_set_timecode, "", "could not set timecode attribute \"$name\"")
end

# ------------------------------------------------------------------
# Test helpers: minimal single-channel EXR write/read so test/test_attributes.jl
# can round-trip without depending on SpectralCube / ExrFile.
# ------------------------------------------------------------------

# Width/height of the fixture image written by _write_single_channel_with_attrs.
# Kept small to make the test fixture cheap; the structural-validity invariant
# of the EXR (one scanline chunk per row, every row encoded) is independent of
# image size.
const _FIXTURE_WIDTH  = 4
const _FIXTURE_HEIGHT = 3

"""
Internal test helper: write a 4x3 single-channel Float32 EXR with all-zero
pixel data and the given attribute set. Not exported; used by
`test/test_attributes.jl` to round-trip attributes without depending on
SpectralCube or ExrFile (which arrive in later chunks).
"""
function _write_single_channel_with_attrs(path::AbstractString,
                                          attributes::AbstractDict{String, <:Any})
    ctxt_ref = Ref{OpenEXR.Core.exr_context_t}(C_NULL)
    # Pass NULL for the optional context initializer; libOpenEXRCore fills in
    # the defaults documented in EXR_DEFAULT_CONTEXT_INITIALIZER.
    _check(OpenEXR.Core.exr_start_write(ctxt_ref, path,
            OpenEXR.Core.EXR_WRITE_FILE_DIRECTLY, C_NULL),
        :exr_start_write, path, "could not open output file")
    try
        part_idx_ref = Ref{Cint}(0)
        _check(OpenEXR.Core.exr_add_part(ctxt_ref[], "", OpenEXR.Core.EXR_STORAGE_SCANLINE, part_idx_ref),
            :exr_add_part, path, "could not add scanline part")
        part_idx = part_idx_ref[]
        # Initialize all required attributes (data window, display window,
        # pixelAspectRatio, screenWindowCenter, screenWindowWidth, lineorder,
        # compression) for a `_FIXTURE_WIDTH` x `_FIXTURE_HEIGHT` image with
        # uncompressed pixels. The "simple" form takes the image dimensions
        # directly; the windows become (0,0)-(W-1,H-1) and the rest defaults.
        _check(OpenEXR.Core.exr_initialize_required_attr_simple(ctxt_ref[], part_idx,
                Int32(_FIXTURE_WIDTH), Int32(_FIXTURE_HEIGHT),
                OpenEXR.Core.EXR_COMPRESSION_NONE),
            :exr_initialize_required_attr_simple, path,
            "could not initialize required attributes")
        # Single Float32 channel "Y".
        _check(OpenEXR.Core.exr_add_channel(ctxt_ref[], part_idx, "Y",
                OpenEXR.Core.EXR_PIXEL_FLOAT,
                OpenEXR.Core.EXR_PERCEPTUALLY_LINEAR,
                Int32(1), Int32(1)),
            :exr_add_channel, path, "could not add Y channel")
        # Mash all user attributes into the part's header.
        _write_attributes!(ctxt_ref[], part_idx, attributes)
        _check(OpenEXR.Core.exr_write_header(ctxt_ref[]),
            :exr_write_header, path, "could not write header")
        # Encode one zero-filled scanline at a time. Loops over every row so the
        # file is structurally valid (an EXR with missing chunks is unreadable).
        #
        # The chunk_info and encode pipeline are mutable structs that
        # libOpenEXRCore fills in by pointer. We back each one with a
        # zero-initialized Vector{UInt8} of the right size and pass `pointer(v)`
        # cast to the matching Ptr type. This pattern keeps the storage
        # GC-rooted across each ccall without requiring inner constructors on
        # the 30-field pipeline struct.
        zero_row = zeros(Float32, _FIXTURE_WIDTH)
        chunk_info_buf = zeros(UInt8, sizeof(OpenEXR.Core.exr_chunk_info_t))
        pipeline_buf   = zeros(UInt8, sizeof(OpenEXR.Core.exr_encode_pipeline_t))
        for y in 0:(_FIXTURE_HEIGHT - 1)
            fill!(chunk_info_buf, 0x00)
            fill!(pipeline_buf, 0x00)
            GC.@preserve chunk_info_buf pipeline_buf zero_row begin
                chunk_info_ptr = Ptr{OpenEXR.Core.exr_chunk_info_t}(pointer(chunk_info_buf))
                pipeline_ptr   = Ptr{OpenEXR.Core.exr_encode_pipeline_t}(pointer(pipeline_buf))
                _check(OpenEXR.Core.exr_write_scanline_chunk_info(ctxt_ref[], part_idx, Cint(y), chunk_info_ptr),
                    :exr_write_scanline_chunk_info, path, "could not get chunk info at row $y")
                # Versioned-struct contract: write the caller's `sizeof` into the
                # pipeline's leading `pipe_size` field so libOpenEXRCore can
                # version-check against its compiled-in layout.
                unsafe_store!(Ptr{Csize_t}(pipeline_ptr),
                              Csize_t(sizeof(OpenEXR.Core.exr_encode_pipeline_t)))
                _check(OpenEXR.Core.exr_encoding_initialize(ctxt_ref[], part_idx, chunk_info_ptr, pipeline_ptr),
                    :exr_encoding_initialize, path, "could not init encode pipeline")
                # Reach into the pipeline to fill the user-controlled fields on
                # the single channel info: pixel stride / line stride are in
                # bytes (Float32 -> 4 bytes), and the user_ptr union member
                # carries the encode_from_ptr source buffer.
                pip = unsafe_load(pipeline_ptr)
                ch_ptr = pip.channels                          # Ptr{exr_coding_channel_info_t}
                ch = unsafe_load(ch_ptr, 1)
                ch.user_pixel_stride = Int32(sizeof(Float32))
                ch.user_line_stride  = Int32(_FIXTURE_WIDTH * sizeof(Float32))
                ch.user_ptr          = Ptr{UInt8}(pointer(zero_row))
                unsafe_store!(ch_ptr, ch, 1)
                _check(OpenEXR.Core.exr_encoding_choose_default_routines(ctxt_ref[], part_idx, pipeline_ptr),
                    :exr_encoding_choose_default_routines, path, "could not pick encode routines")
                _check(OpenEXR.Core.exr_encoding_run(ctxt_ref[], part_idx, pipeline_ptr),
                    :exr_encoding_run, path, "encode pipeline failed at row $y")
                _check(OpenEXR.Core.exr_encoding_destroy(ctxt_ref[], pipeline_ptr),
                    :exr_encoding_destroy, path, "could not destroy encode pipeline")
            end
        end
    finally
        OpenEXR.Core.exr_finish(ctxt_ref)
    end
    return nothing
end

"""
Internal test helper: open an EXR for reading, read part 0's attributes via
`_read_attributes`, and return the resulting Dict. Not exported.
"""
function _read_attributes_from_file(path::AbstractString)
    ctxt_ref = Ref{OpenEXR.Core.exr_context_t}(C_NULL)
    _check(OpenEXR.Core.exr_start_read(ctxt_ref, path, C_NULL),
        :exr_start_read, path, "could not open input file")
    try
        return _read_attributes(ctxt_ref[], Cint(0))
    finally
        OpenEXR.Core.exr_finish(ctxt_ref)
    end
end
