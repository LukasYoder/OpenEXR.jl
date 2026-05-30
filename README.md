# OpenEXR.jl

[![Build Status](https://github.com/twadleigh/OpenEXR.jl/workflows/CI/badge.svg)](https://github.com/twadleigh/OpenEXR.jl/actions?query=workflow%3A%22CI%22+branch%3Amaster)
[![codecov.io](http://codecov.io/github/twadleigh/OpenEXR.jl/coverage.svg?branch=master)](http://codecov.io/github/twadleigh/OpenEXR.jl?branch=master)

Saving and loading of OpenEXR files. OpenEXR.jl supports three I/O shapes
natively:

- **Colors-typed images** (`Array{<:Color, 2}`) — the existing API for
  standard RGB / RGBA / Gray / GrayA photographs.
- **`SpectralCube`** — a first-class type for hyperspectral, multispectral,
  and ultraspectral data with per-band wavelengths.
- **`ExrFile`** — a catch-all for arbitrary EXR files (renderer outputs,
  multi-part files, Cryptomatte mattes, custom channel sets).

# Load an EXR file

```jl
using OpenEXR

myimage = OpenEXR.load("myimage.exr")
```

`myimage` has type `Array{T,2}` where `T` is one of:

- RGBA{Float16}
- RGB{Float16}
- GrayA{Float16}
- Gray{Float16}

depending on which channels are present in the file.

# Save an image as an EXR file

```jl
OpenEXR.save("myimage2.exr", myimage)
```

`myimage` can be any subtype of `AbstractArray{C,2}` where `C` is any color type defined in
[ColorTypes.jl](https://github.com/JuliaGraphics/ColorTypes.jl).

# Spectral imaging and arbitrary-channel files

In addition to the Colors-typed image API above, OpenEXR.jl exposes two more
I/O shapes for scientific and VFX workflows.

## Auto-detection on read

`load(path)` with no type argument inspects the file header and dispatches:

1. If the header has the attribute `spectral_wavelengths_nm` (the marker that
   defines a SpectralCube) → returns `SpectralCube{T}`.
2. Else if the channel set is exactly one of the recognized Colors layouts —
   `{Y}` (Gray), `{Y, A}` (GrayA), `{R, G, B}` (RGB), or `{R, G, B, A}`
   (RGBA) — returns the existing Colors-typed `Array{<:Color, 2}`.
3. Else → returns `ExrFile` (everything else: depth + normal AOVs,
   Cryptomatte, multi-part files, custom channel sets, etc.).

This is fully backward-compatible: every file that the existing `load(path)`
successfully read as a Colors-typed image continues to read as one. Files
that previously errored or produced garbage on non-RGB channel layouts now
return sensible types instead.

## Type-asserted variants

For pipelines where the caller knows what they expect and wants loud
failures if reality disagrees, pass the expected type as the second
argument:

```jl
cube = OpenEXR.load("scene.exr", SpectralCube)
exr  = OpenEXR.load("comp.exr",  ExrFile)
rgb  = OpenEXR.load("photo.exr", Array{RGB{Float16}, 2})
```

Each throws a clear `ArgumentError` if the file's shape doesn't match.

The type constructors `SpectralCube(path)` and `ExrFile(path)` are
equivalent to `load(path, SpectralCube)` and `load(path, ExrFile)`.

## `SpectralCube` — hyperspectral / multispectral data

```jl
using OpenEXR

# Build a 224-band reflectance cube (AVIRIS-NG-like) at 380–2510 nm.
data        = rand(Float32, 512, 614, 224)                 # (h, w, band)
wavelengths = collect(Float32, range(380.0f0, 2510.0f0; length = 224))

cube = SpectralCube(
    data,
    wavelengths;
    fwhm        = fill(5.0f0, 224),
    band_names  = ["S$(round(λ, digits = 1))" for λ in wavelengths],
)

# Write as scanline with default compression (:zip).
OpenEXR.save("scene.exr", cube)

# Or write tiled with a preview thumbnail attached.
OpenEXR.save(
    "scene_tiled.exr", cube;
    compression = :piz,
    tile_size   = (256, 256),
    preview     = rand(NTuple{4, UInt8}, 128, 128),
)

# Auto-detect on load (returns SpectralCube because the spectral marker is
# present).
cube_back = OpenEXR.load("scene.exr")
@assert cube_back isa SpectralCube
@assert cube_back == cube                                  # byte-for-byte lossless
```

The `SpectralCube` behaves as an `AbstractArray{T, 3}` of shape
`(height, width, band)`. Spectral-axis metadata is accessed by property:
`cube.wavelengths`, `cube.fwhm`, `cube.band_names`, `cube.preview`,
`cube.attributes`, `cube.storage`, `cube.tile_size`.

### Supported pixel types

OpenEXR's file format natively supports three channel pixel types: `UINT`
(32-bit unsigned), `HALF` (Float16), `FLOAT` (Float32). The supported
`SpectralCube{T}` element types and their on-disk mapping:

| `T` | On-disk EXR pixel type | Notes |
|---|---|---|
| `Float32` | `FLOAT` | Native, byte-for-byte lossless |
| `Float16` | `HALF` | Native, byte-for-byte lossless |
| `UInt32` | `UINT` | Native, byte-for-byte lossless |
| `UInt16` | `UINT` | Auto-promoted to UInt32 on write (lossless, 2× storage); a `spectral_original_eltype = "UInt16"` attribute records the source so reads restore `SpectralCube{UInt16}` |
| `UInt8` | `UINT` | Same auto-promotion (lossless, 4× storage); `spectral_original_eltype = "UInt8"` |
| `Float64` | — | **Rejected at write time** with an actionable error: convert with `Float32.(cube.data)` if precision loss is acceptable, or use HDF5 / NetCDF / Zarr for Float64 spectral data |

The on-disk eltype is entirely dictated by the input data's eltype.
`SpectralCube` never converts precision silently.

### Supported compression (lossless only)

| `compression =` | Algorithm |
|---|---|
| `:none` | No compression |
| `:rle` | Run-length encoding |
| `:zip` (default) | DEFLATE on 16-scanline blocks |
| `:zips` | DEFLATE on single scanlines |
| `:piz` | Wavelet + Huffman, lossless |

Lossy compressions (`:pxr24`, `:b44`, `:b44a`, `:dwaa`, `:dwab`) are
rejected at the top of `save` before any C call:

```
ArgumentError: compression :b44 is lossy and not permitted for SpectralCube;
spectral data integrity requires lossless compression. Use :zip, :piz, :zips,
:rle, or :none.
```

The `ExrFile` write path allows lossy compressions — users who explicitly
chose `ExrFile` have opted out of spectral semantics and may want them.

### Storage layout

The user picks scanline or tiled at save time via the `tile_size` kwarg:

- `tile_size = nothing` (default) → scanline storage. Compression block is
  the smallest IO unit; best for whole-cube reads.
- `tile_size = (w, h)` → tiled storage. Each tile decompresses
  independently; best for large files where the caller wants small
  spatial subsets without reading the whole file.

## `ExrFile` — arbitrary EXR files

`ExrFile` is the catch-all for EXR files that don't fit either the Colors
or SpectralCube molds. Used for:

- Renderer / VFX outputs that combine RGB with depth (Z), normal vectors
  (N), object IDs, motion vectors, or custom AOVs.
- Multi-part EXR files (one part might be RGB, another part might be a
  depth map at a different resolution).
- Cryptomatte mattes (compositor workflows storing hashed object IDs
  across many channels).
- Files with arbitrary user-defined channel sets.
- "Inspect what's in this file before deciding how to handle it"
  workflows.

```jl
using OpenEXR

# Build a single-part file with renderer AOVs (RGB + depth + normal).
height, width = 1080, 1920
part = ExrPart(
    name        = "",
    channels    = Dict{String, AbstractArray}(
        "R"   => rand(Float16, height, width),
        "G"   => rand(Float16, height, width),
        "B"   => rand(Float16, height, width),
        "Z"   => rand(Float32, height, width),                # depth
        "N.X" => rand(Float16, height, width),                # surface normal
        "N.Y" => rand(Float16, height, width),
        "N.Z" => rand(Float16, height, width),
    ),
    attributes  = Dict{String, Any}("comments" => "render pass 042"),
    dimensions  = (width, height),
    storage     = :scanline,
    tile_size   = nothing,
    compression = :zip,
)
OpenEXR.save("aov.exr", ExrFile([part]))

# Auto-detect on load (returns ExrFile because the channel set isn't a
# recognized Colors layout and there's no spectral marker).
exr = OpenEXR.load("aov.exr")
@assert exr isa ExrFile
exr.channels["Z"]              # single-part convenience accessor
exr.parts[1].channels["N.X"]   # full path for multi-part files
```

### Kwarg-only escape hatch

For one-off arbitrary single-part writes that don't justify constructing
a full `ExrPart`/`ExrFile`, pass `channels` and `attributes` directly as
keyword arguments:

```jl
OpenEXR.save(
    "quick.exr";
    channels    = Dict("R" => r, "G" => g, "B" => b, "Z" => z),
    attributes  = Dict("comments" => "ad-hoc dump"),
    compression = :zip,
)
```

## When to use which

| You have... | Use |
|---|---|
| A photograph or composited image, RGB / RGBA / Gray / GrayA | `Array{<:Color, 2}` — `load(path)` auto-returns it |
| Hyperspectral, multispectral, or ultraspectral data with per-band wavelengths | `SpectralCube` |
| A renderer output combining RGB with depth, normals, motion vectors, or other AOVs | `ExrFile` |
| A multi-part EXR file (e.g., RGB part + depth part at different resolutions) | `ExrFile` |
| A Cryptomatte matte (hashed object IDs across many channels) | `ExrFile` |
| A file with an unfamiliar channel set, and you want to inspect it before deciding | `ExrFile` |
| An arbitrary one-off channel layout to write without constructing a struct | `save(path; channels=..., attributes=..., ...)` kwarg form |

The rule of thumb: if you have spectral imaging data, use `SpectralCube`. If
you have a standard color image, use `load(path)` and let auto-detection
return an `Array{<:Color, 2}`. Use `ExrFile` when neither applies.
