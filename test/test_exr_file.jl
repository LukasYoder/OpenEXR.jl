using Test
using OpenEXR

@testset "ExrFile round-trip" begin
    @testset "single-part with RGBA + Z" begin
        mktempdir() do dir
            path = joinpath(dir, "rgbz.exr")
            h, w = 8, 6
            r = rand(Float32, h, w)
            g = rand(Float32, h, w)
            b = rand(Float32, h, w)
            z = rand(Float32, h, w)
            part = ExrPart(
                "",
                Dict{String, AbstractArray}(
                    "R" => r, "G" => g, "B" => b, "Z" => z,
                ),
                Dict{String, Any}("rendererName" => "claude-test"),
                (w, h), :scanline, nothing, :zip,
            )
            exr = ExrFile([part])
            OpenEXR.save(path, exr)
            exr_back = OpenEXR.load(path, ExrFile)
            @test length(exr_back.parts) == 1
            @test exr_back.parts[1].channels["R"] == r
            @test exr_back.parts[1].channels["G"] == g
            @test exr_back.parts[1].channels["B"] == b
            @test exr_back.parts[1].channels["Z"] == z
            @test exr_back.parts[1].attributes["rendererName"] == "claude-test"
            @test exr_back.parts[1].dimensions == (w, h)
            @test exr_back.parts[1].storage === :scanline
            @test exr_back.parts[1].compression === :zip
        end
    end

    @testset "single-part with mixed pixel types (Float16 + Float32 + UInt32)" begin
        mktempdir() do dir
            path = joinpath(dir, "mixed.exr")
            h, w = 8, 6
            r_half  = rand(Float16, h, w)
            g_float = rand(Float32, h, w)
            mask    = rand(UInt32(0):UInt32(7), h, w)
            part = ExrPart(
                "",
                Dict{String, AbstractArray}(
                    "R_half" => r_half, "G_float" => g_float, "mask" => mask,
                ),
                Dict{String, Any}(),
                (w, h), :scanline, nothing, :zip,
            )
            OpenEXR.save(path, ExrFile([part]))
            exr_back = OpenEXR.load(path, ExrFile)
            @test exr_back.channels["R_half"]  == r_half
            @test exr_back.channels["G_float"] == g_float
            @test exr_back.channels["mask"]    == mask
            # The on-disk eltype is preserved exactly through the round-trip.
            @test eltype(exr_back.channels["R_half"])  === Float16
            @test eltype(exr_back.channels["G_float"]) === Float32
            @test eltype(exr_back.channels["mask"])    === UInt32
        end
    end

    @testset "single-part tiled storage" begin
        mktempdir() do dir
            path = joinpath(dir, "tiled.exr")
            h, w = 10, 8
            r = rand(Float32, h, w)
            g = rand(Float32, h, w)
            part = ExrPart(
                "",
                Dict{String, AbstractArray}("R" => r, "G" => g),
                Dict{String, Any}(),
                (w, h), :tiled, (4, 4), :zips,
            )
            OpenEXR.save(path, ExrFile([part]))
            exr_back = OpenEXR.load(path, ExrFile)
            @test exr_back.storage === :tiled
            @test exr_back.tile_size == (4, 4)
            @test exr_back.channels["R"] == r
            @test exr_back.channels["G"] == g
        end
    end

    @testset "multi-part: RGB part + depth part with different dimensions" begin
        mktempdir() do dir
            path = joinpath(dir, "mp.exr")
            rgb_r = rand(Float32, 8, 6)
            rgb_g = rand(Float32, 8, 6)
            rgb_b = rand(Float32, 8, 6)
            depth_z = rand(Float32, 4, 3)
            rgb_part = ExrPart(
                "color",
                Dict{String, AbstractArray}(
                    "R" => rgb_r, "G" => rgb_g, "B" => rgb_b,
                ),
                Dict{String, Any}(),
                (6, 8), :scanline, nothing, :zip,
            )
            z_part = ExrPart(
                "depth",
                Dict{String, AbstractArray}("Z" => depth_z),
                Dict{String, Any}(),
                (3, 4), :tiled, (2, 2), :zips,
            )
            exr = ExrFile([rgb_part, z_part])
            OpenEXR.save(path, exr)
            exr_back = OpenEXR.load(path, ExrFile)
            @test length(exr_back.parts) == 2
            # Part order preserved.
            @test exr_back.parts[1].name == "color"
            @test exr_back.parts[2].name == "depth"
            @test exr_back.parts[1].channels["R"] == rgb_r
            @test exr_back.parts[1].channels["G"] == rgb_g
            @test exr_back.parts[1].channels["B"] == rgb_b
            @test exr_back.parts[2].channels["Z"] == depth_z
            @test exr_back.parts[1].storage === :scanline
            @test exr_back.parts[2].storage === :tiled
            @test exr_back.parts[2].tile_size == (2, 2)
            @test exr_back.parts[1].dimensions == (6, 8)
            @test exr_back.parts[2].dimensions == (3, 4)
        end
    end

    @testset "convenience accessors raise for multi-part" begin
        mktempdir() do dir
            path = joinpath(dir, "mp2.exr")
            p1 = ExrPart("a",
                Dict{String, AbstractArray}("R" => rand(Float32, 4, 3)),
                Dict{String, Any}(),
                (3, 4), :scanline, nothing, :zip)
            p2 = ExrPart("b",
                Dict{String, AbstractArray}("R" => rand(Float32, 4, 3)),
                Dict{String, Any}(),
                (3, 4), :scanline, nothing, :zip)
            exr = ExrFile([p1, p2])
            # Reaching for a single-part convenience accessor on a
            # multi-part file should throw a clear error pointing the
            # user at parts[i].
            @test_throws ArgumentError exr.channels
            @test_throws ArgumentError exr.dimensions
        end
    end

    @testset "kwarg save (no struct construction needed)" begin
        mktempdir() do dir
            path = joinpath(dir, "kwarg.exr")
            OpenEXR.save(
                path;
                channels = Dict("Y" => rand(Float32, 4, 3),
                                "A" => rand(Float32, 4, 3)),
                attributes = Dict("foo" => "bar"),
                compression = :zip,
            )
            exr_back = OpenEXR.load(path, ExrFile)
            @test "Y" in keys(exr_back.channels)
            @test "A" in keys(exr_back.channels)
            @test exr_back.attributes["foo"] == "bar"
        end
    end

    @testset "kwarg save with tile_size produces tiled storage" begin
        mktempdir() do dir
            path = joinpath(dir, "kwarg_tiled.exr")
            OpenEXR.save(
                path;
                channels = Dict("X" => rand(Float32, 8, 6),
                                "Y" => rand(Float32, 8, 6)),
                tile_size = (4, 4),
            )
            exr_back = OpenEXR.load(path, ExrFile)
            @test exr_back.storage === :tiled
            @test exr_back.tile_size == (4, 4)
        end
    end

    @testset "kwarg save validates equal-dim channels" begin
        mktempdir() do dir
            @test_throws ArgumentError OpenEXR.save(
                joinpath(dir, "bad.exr");
                channels = Dict("Y" => rand(Float32, 4, 3),
                                "Z" => rand(Float32, 8, 8)),
            )
        end
    end

    @testset "kwarg save rejects empty channels Dict" begin
        mktempdir() do dir
            @test_throws ArgumentError OpenEXR.save(
                joinpath(dir, "empty.exr");
                channels = Dict{String, AbstractArray}(),
            )
        end
    end

    @testset "ExrFile accepts lossy :b44 compression for Float16 channels" begin
        mktempdir() do dir
            path = joinpath(dir, "lossy_b44.exr")
            h, w = 8, 6
            part = ExrPart(
                "",
                Dict{String, AbstractArray}(
                    "R" => rand(Float16, h, w),
                    "G" => rand(Float16, h, w),
                    "B" => rand(Float16, h, w),
                ),
                Dict{String, Any}(),
                (w, h), :scanline, nothing, :b44,
            )
            OpenEXR.save(path, ExrFile([part]))
            exr_back = OpenEXR.load(path, ExrFile)
            @test exr_back.compression === :b44
            # Lossy: data may differ slightly. Just confirm the file is
            # readable and the channel set / shape are intact.
            @test size(exr_back.channels["R"]) == (h, w)
            @test size(exr_back.channels["G"]) == (h, w)
            @test size(exr_back.channels["B"]) == (h, w)
        end
    end

    @testset "ExrFile accepts lossy :dwaa compression for Float32 channels" begin
        mktempdir() do dir
            path = joinpath(dir, "lossy_dwaa.exr")
            h, w = 8, 6
            part = ExrPart(
                "",
                Dict{String, AbstractArray}(
                    "R" => rand(Float32, h, w),
                    "G" => rand(Float32, h, w),
                    "B" => rand(Float32, h, w),
                ),
                Dict{String, Any}(),
                (w, h), :scanline, nothing, :dwaa,
            )
            OpenEXR.save(path, ExrFile([part]))
            exr_back = OpenEXR.load(path, ExrFile)
            @test exr_back.compression === :dwaa
            @test size(exr_back.channels["R"]) == (h, w)
        end
    end

    @testset "ExrFile accepts :pxr24 for any pixel type" begin
        mktempdir() do dir
            path = joinpath(dir, "pxr24.exr")
            h, w = 8, 6
            part = ExrPart(
                "",
                Dict{String, AbstractArray}(
                    "F" => rand(Float32, h, w),
                    "H" => rand(Float16, h, w),
                    "U" => rand(UInt32(0):UInt32(7), h, w),
                ),
                Dict{String, Any}(),
                (w, h), :scanline, nothing, :pxr24,
            )
            OpenEXR.save(path, ExrFile([part]))
            exr_back = OpenEXR.load(path, ExrFile)
            @test exr_back.compression === :pxr24
            # :pxr24 is lossless for Float16 and UInt32.
            @test exr_back.channels["H"] == part.channels["H"]
            @test exr_back.channels["U"] == part.channels["U"]
        end
    end

    @testset "ExrFile rejects :b44 for UInt32 channels" begin
        mktempdir() do dir
            path = joinpath(dir, "bad_b44.exr")
            @test_throws ArgumentError OpenEXR.save(
                path,
                ExrFile([ExrPart(
                    "",
                    Dict{String, AbstractArray}("X" => rand(UInt32, 4, 3)),
                    Dict{String, Any}(),
                    (3, 4), :scanline, nothing, :b44,
                )]),
            )
        end
    end

    @testset "ExrFile rejects :b44 for Float32 channels" begin
        mktempdir() do dir
            path = joinpath(dir, "bad_b44_f32.exr")
            @test_throws ArgumentError OpenEXR.save(
                path,
                ExrFile([ExrPart(
                    "",
                    Dict{String, AbstractArray}("X" => rand(Float32, 4, 3)),
                    Dict{String, Any}(),
                    (3, 4), :scanline, nothing, :b44,
                )]),
            )
        end
    end

    @testset "ExrFile rejects :dwaa for UInt32 channels" begin
        mktempdir() do dir
            path = joinpath(dir, "bad_dwaa.exr")
            @test_throws ArgumentError OpenEXR.save(
                path,
                ExrFile([ExrPart(
                    "",
                    Dict{String, AbstractArray}("X" => rand(UInt32, 4, 3)),
                    Dict{String, Any}(),
                    (3, 4), :scanline, nothing, :dwaa,
                )]),
            )
        end
    end

    @testset "ExrFile constructor from path" begin
        mktempdir() do dir
            path = joinpath(dir, "rgb.exr")
            OpenEXR.save(path;
                channels = Dict("R" => rand(Float32, 4, 3),
                                "G" => rand(Float32, 4, 3),
                                "B" => rand(Float32, 4, 3)))
            exr = ExrFile(path)
            @test length(exr.parts) == 1
            @test "R" in keys(exr.channels)
        end
    end
end
