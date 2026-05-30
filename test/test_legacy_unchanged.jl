using Test
using OpenEXR
using FileIO
using Colors
using FixedPointNumbers

# Regression suite -- confirms the legacy load / save / load_exr / save_exr
# paths produce byte-identical results to the pre-redesign baseline. Any
# new failure in these tests is a regression introduced by the redesign
# and must be fixed.
#
# The CRITICAL assertion is `typeof(loaded) === Array{typ, 2}` -- the new
# auto-detecting load(path) MUST return the same Colors-typed array as
# the pre-redesign load(path) for every {Y}, {Y, A}, {R, G, B},
# {R, G, B, A} channel set.

@testset "Legacy paths unchanged" begin
    @testset "load_exr / save_exr round-trip" begin
        # Low-level path: save_exr writes RGBA{Float16} (the EXR-native pixel
        # format used by the legacy Imf-based bindings); load_exr always
        # returns an RGBA{Float16} matrix plus the on-disk channel mode.
        for typ in (RGBA{Float16}, RGB{Float16}, GrayA{Float16}, Gray{Float16})
            img = rand(typ, 256, 512)
            mktempdir() do dir
                fn = joinpath(dir, "legacy.exr")
                # Convert the per-type image into the RGBA{Float16} buffer
                # that save_exr expects, and write with the matching channel
                # mode so the on-disk layout matches the source type.
                rgba_buf, chans_to_write = if typ === RGBA{Float16}
                    (img, OpenEXR.WRITE_RGBA)
                elseif typ === RGB{Float16}
                    ((c -> convert(RGBA{Float16}, c)).(img), OpenEXR.WRITE_RGB)
                elseif typ === GrayA{Float16}
                    ((c -> convert(RGBA{Float16}, c)).(img), OpenEXR.WRITE_YA)
                else  # Gray{Float16}
                    ((c -> convert(RGBA{Float16}, c)).(img), OpenEXR.WRITE_Y)
                end

                OpenEXR.save_exr(fn, rgba_buf, OpenEXR.ZIP_COMPRESSION,
                                 chans_to_write)
                (data, chans) = OpenEXR.load_exr(fn)
                @test typeof(data) === Array{RGBA{Float16}, 2}
                @test chans isa OpenEXR.RgbaChannels
                @test chans == chans_to_write
                @test size(data) == size(img)
            end
        end
    end

    @testset "load / save (high-level) round-trip returns same Colors types as before" begin
        # High-level path: save(path, Array{<:Color, 2}) dispatches on the
        # element type to choose the channel mode, and load(path) (post-Chunk
        # 6 auto-detect) returns the same Colors-typed array as the
        # pre-redesign load did.
        for typ in (RGBA{Float16}, RGB{Float16}, GrayA{Float16}, Gray{Float16})
            img = rand(typ, 256, 512)
            mktempdir() do dir
                fn = joinpath(dir, "legacy_hl.exr")
                OpenEXR.save(fn, img)
                loaded = OpenEXR.load(fn)
                # CRITICAL: auto-detect MUST return the same Colors type as
                # the pre-redesign load. This is the heart of the legacy-
                # unchanged guarantee.
                @test typeof(loaded) === Array{typ, 2}
                @test loaded == img
            end
        end
    end

    @testset "FileIO interface still works" begin
        # FileIO entry point: load(::File{DataFormat{:EXR}}) delegates to
        # the new auto-detecting load(path), which for an RGBA file routes
        # through _legacy_load_colors -- byte-identical to the pre-
        # redesign Colors return value.
        mktempdir() do dir
            fn = File{DataFormat{:EXR}}(joinpath(dir, "fileio.exr"))
            img = rand(RGBA{Float16}, 8, 6)
            OpenEXR.save(fn, img)
            loaded = OpenEXR.load(fn)
            @test typeof(loaded) === Array{RGBA{Float16}, 2}
            @test loaded == img
        end
    end

    @testset "FileIO interface across all Colors-recognized layouts" begin
        # Spot-check that the FileIO path returns the right Colors type for
        # each of {Y}, {Y, A}, {R, G, B}, {R, G, B, A} -- not just RGBA.
        for typ in (RGBA{Float16}, RGB{Float16}, GrayA{Float16}, Gray{Float16})
            mktempdir() do dir
                fn = File{DataFormat{:EXR}}(joinpath(dir, "fileio.exr"))
                img = rand(typ, 16, 12)
                OpenEXR.save(fn, img)
                loaded = OpenEXR.load(fn)
                @test typeof(loaded) === Array{typ, 2}
                @test loaded == img
            end
        end
    end
end
