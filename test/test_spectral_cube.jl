using Test
using OpenEXR

# Generate a deterministic test cube. For floating-point eltypes we use a
# bounded fractional pattern; for integer eltypes we sweep through valid
# values modulo the type's range. The pattern is keyed off (i, j, k) so a
# round-trip can compare element-for-element.
function _make_cube(
    ::Type{T}, h::Int, w::Int, n::Int;
    wavelengths = collect(Float32, 400.0:50.0:(400.0 + 50.0 * (n - 1))),
    kw...,
) where {T <: Real}
    data = Array{T, 3}(undef, h, w, n)
    for k in 1:n
        for j in 1:w
            for i in 1:h
                # Use a deterministic mix; convert to T at the end so that
                # the floating-point branches get fractional values and the
                # integer branches stay within their valid range.
                if T <: AbstractFloat
                    raw = ((i * 31 + j * 17 + k * 7) % 1000) / 1000.0f0
                    data[i, j, k] = convert(T, raw)
                else
                    # Integer types: use modulus tied to the type's bit-width
                    # so values are always representable.
                    range = T <: UInt8  ? 256 :
                            T <: UInt16 ? 65536 :
                            T <: UInt32 ? 1000003 : 100
                    data[i, j, k] = T((i * 31 + j * 17 + k * 7) % range)
                end
            end
        end
    end
    return SpectralCube(data, wavelengths; kw...)
end

@testset "SpectralCube round-trip" begin
    @testset "Float32 + zip + scanline (default)" begin
        mktempdir() do dir
            path = joinpath(dir, "rt.exr")
            cube = _make_cube(Float32, 8, 6, 5)
            OpenEXR.save(path, cube)
            cube_back = OpenEXR.load(path, SpectralCube)
            @test eltype(cube_back) === Float32
            @test size(cube_back) == size(cube)
            @test cube_back.data == cube.data            # byte-for-byte (lossless)
            @test cube_back.wavelengths == cube.wavelengths
            @test cube_back.fwhm === nothing
            # default-generated names are not round-tripped as user-set
            @test cube_back.band_names === nothing
            @test cube_back.storage === :scanline
            @test cube_back.tile_size === nothing
        end
    end
end

# Helper: collapse a (storage, tile_size) pair into a printable id for test
# naming. `:scanline` parts have tile_size === nothing.
_storage_id(storage, tile_size) = tile_size === nothing ? "scanline" :
    "tiled_$(tile_size[1])x$(tile_size[2])"

# Single round-trip body factored into a function so the test loop below
# doesn't drive Julia's type inferencer through (eltype × compression ×
# storage)² × inlined-cube-types specialisations (which causes the parallel
# GC compiler to abort with SIGSEGV/SIGABRT on >2 threads). The function
# itself dispatches on T and is type-stable.
function _spectralcube_roundtrip_test(::Type{T}, compression::Symbol,
        storage::Symbol, tile_size, h::Int, w::Int, n::Int) where {T}
    mktempdir() do dir
        path = joinpath(dir, "rt.exr")
        cube = _make_cube(T, h, w, n;
            storage = storage, tile_size = tile_size,
        )
        OpenEXR.save(path, cube;
            compression = compression, tile_size = tile_size,
        )
        cube_back = OpenEXR.load(path, SpectralCube)
        @test eltype(cube_back) === T
        @test size(cube_back) == size(cube)
        @test cube_back.data == cube.data
        @test cube_back.wavelengths == cube.wavelengths
        @test cube_back.storage === storage
        if tile_size !== nothing
            @test cube_back.tile_size == tile_size
        else
            @test cube_back.tile_size === nothing
        end
    end
end

@testset "SpectralCube round-trip — eltype × compression × storage matrix" begin
    # Test image dimensions are deliberately chosen so that ZIP's 16-row
    # chunks span at least one full chunk and have a partial last chunk,
    # exercising the chunk-stride iterator. The tile grid (4, 3) also
    # makes the rightmost / bottom-most tile partial.
    h, w, n = 20, 12, 5
    for T in (Float32, Float16, UInt32, UInt16, UInt8)
        for compression in (:none, :rle, :zip, :zips, :piz)
            for (storage, tile_size) in (
                (:scanline, nothing),
                (:tiled,    (4, 3)),
            )
                @testset "$T / $compression / $(_storage_id(storage, tile_size))" begin
                    _spectralcube_roundtrip_test(
                        T, compression, storage, tile_size, h, w, n,
                    )
                end
            end
        end
    end
end

# Cover an additional tile geometry where neither tile dim evenly divides
# the image. Tested only for one representative (eltype, compression)
# combination so the test compile-time cost stays manageable.
@testset "SpectralCube tiled round-trip — non-divisible tile dims" begin
    for (T, compression) in ((Float32, :zip), (UInt16, :zip), (Float16, :piz))
        mktempdir() do dir
            path = joinpath(dir, "tiles_partial.exr")
            cube = _make_cube(T, 19, 13, 3; storage = :tiled, tile_size = (5, 7))
            OpenEXR.save(path, cube; compression = compression, tile_size = (5, 7))
            cube_back = OpenEXR.load(path, SpectralCube)
            @test cube_back.data == cube.data
            @test cube_back.tile_size == (5, 7)
            @test cube_back.storage === :tiled
        end
    end
end

@testset "SpectralCube fwhm / band_names / attributes round-trip" begin
    mktempdir() do dir
        path = joinpath(dir, "meta.exr")
        wavelengths = Float32[400, 450, 500, 550, 600]
        fwhm        = Float32[5.0, 5.0, 7.0, 7.0, 9.0]
        band_names  = ["band_blue", "band_cyan", "band_green",
                       "band_yellow", "band_red"]
        attrs = Dict{String, Any}(
            "instrument_name" => "Test-Sensor-A",
            "sensor_serial"   => Int32(42),
        )
        cube = SpectralCube(
            zeros(Float32, 8, 6, 5), wavelengths;
            fwhm = fwhm, band_names = band_names, attributes = attrs,
        )
        OpenEXR.save(path, cube)
        cube_back = OpenEXR.load(path, SpectralCube)
        @test cube_back.wavelengths == wavelengths
        @test cube_back.fwhm == fwhm
        @test cube_back.band_names == band_names
        @test cube_back.attributes["instrument_name"] == "Test-Sensor-A"
        @test cube_back.attributes["sensor_serial"]   === Int32(42)
        # Marker attributes must be stripped from the user-visible Dict.
        @test !haskey(cube_back.attributes, "spectral_cube_version")
        @test !haskey(cube_back.attributes, "spectral_wavelengths_nm")
        @test !haskey(cube_back.attributes, "spectral_fwhm_nm")
        @test !haskey(cube_back.attributes, "spectral_channel_names")
    end
end

@testset "SpectralCube preview thumbnail round-trip" begin
    mktempdir() do dir
        path = joinpath(dir, "with_preview.exr")
        cube = _make_cube(Float32, 8, 6, 5)
        # Deterministic 16x16 RGBA8 preview — every channel varies with (i, j).
        preview = Matrix{NTuple{4, UInt8}}(undef, 16, 16)
        for i in 1:16
            for j in 1:16
                preview[i, j] = (
                    UInt8((i * 16 - 1) % 256),
                    UInt8((j * 16 - 1) % 256),
                    UInt8((i + j) % 256),
                    UInt8(255),
                )
            end
        end
        OpenEXR.save(path, cube; preview = preview)
        cube_back = OpenEXR.load(path, SpectralCube)
        @test cube_back.preview !== nothing
        @test size(cube_back.preview) == (16, 16)
        @test cube_back.preview == preview
    end
end

@testset "SpectralCube no-preview round-trip leaves field nothing" begin
    mktempdir() do dir
        path = joinpath(dir, "no_preview.exr")
        cube = _make_cube(Float32, 8, 6, 5)
        OpenEXR.save(path, cube)
        cube_back = OpenEXR.load(path, SpectralCube)
        @test cube_back.preview === nothing
    end
end

@testset "SpectralCube negative cases" begin
    cube_f32 = _make_cube(Float32, 4, 3, 5)
    # Build a Float64 cube directly via the inner constructor — the outer
    # constructor would accept it too, but this clarifies that the rejection
    # happens at save time, not at construction.
    cube_f64 = SpectralCube{Float64}(
        Float64.(cube_f32.data), cube_f32.wavelengths,
    )

    @testset "Float64 rejected at save time with actionable message" begin
        mktempdir() do dir
            path = joinpath(dir, "bad.exr")
            @test_throws ArgumentError OpenEXR.save(path, cube_f64)
            err = nothing
            try
                OpenEXR.save(path, cube_f64)
            catch e
                err = e
            end
            @test err isa ArgumentError
            @test occursin("Float32", err.msg)
            @test occursin("HDF5", err.msg)
        end
    end

    @testset "Lossy compression rejected" begin
        mktempdir() do dir
            path = joinpath(dir, "lossy.exr")
            for c in (:pxr24, :b44, :b44a, :dwaa, :dwab)
                @test_throws ArgumentError OpenEXR.save(
                    path, cube_f32; compression = c,
                )
                # Verify the message mentions the rejected symbol and lists
                # the permitted lossless alternatives.
                err = nothing
                try
                    OpenEXR.save(path, cube_f32; compression = c)
                catch e
                    err = e
                end
                @test err isa ArgumentError
                @test occursin(repr(c), err.msg)
                @test occursin("lossless", err.msg)
            end
        end
    end

    @testset "Unknown compression symbol rejected" begin
        mktempdir() do dir
            path = joinpath(dir, "unknown.exr")
            @test_throws ArgumentError OpenEXR.save(
                path, cube_f32; compression = :no_such_codec,
            )
        end
    end

    @testset "Wavelengths length mismatch at construction" begin
        # 5 bands, but only 2 wavelengths.
        @test_throws ArgumentError SpectralCube(
            cube_f32.data, Float32[400, 500],
        )
    end

    @testset "FWHM length mismatch at construction" begin
        @test_throws ArgumentError SpectralCube(
            cube_f32.data, cube_f32.wavelengths;
            fwhm = Float32[1.0, 2.0],  # only 2 entries for 5 bands
        )
    end

    @testset "Band names length mismatch at construction" begin
        @test_throws ArgumentError SpectralCube(
            cube_f32.data, cube_f32.wavelengths;
            band_names = ["a", "b"],  # only 2 entries for 5 bands
        )
    end

    @testset "Storage / tile_size consistency at construction" begin
        # storage = :tiled without tile_size is invalid.
        @test_throws ArgumentError SpectralCube(
            cube_f32.data, cube_f32.wavelengths; storage = :tiled,
        )
        # storage = :scanline with tile_size is invalid.
        @test_throws ArgumentError SpectralCube(
            cube_f32.data, cube_f32.wavelengths;
            storage = :scanline, tile_size = (4, 4),
        )
        # Non-positive tile dim is invalid.
        @test_throws ArgumentError SpectralCube(
            cube_f32.data, cube_f32.wavelengths;
            storage = :tiled, tile_size = (0, 4),
        )
        # Unknown storage symbol is invalid.
        @test_throws ArgumentError SpectralCube(
            cube_f32.data, cube_f32.wavelengths; storage = :weird,
        )
    end

    @testset "Loading non-spectral file as SpectralCube throws" begin
        # Build a small EXR via the test helper (no spectral markers), then
        # try to load it as a SpectralCube — the marker check must fail.
        mktempdir() do dir
            path = joinpath(dir, "plain.exr")
            OpenEXR._write_single_channel_with_attrs(
                path, Dict{String, Any}("custom_attr" => "hi"),
            )
            err = nothing
            try
                OpenEXR.load(path, SpectralCube)
            catch e
                err = e
            end
            @test err isa ArgumentError
            @test occursin("spectral_wavelengths_nm", err.msg)
        end
    end
end
