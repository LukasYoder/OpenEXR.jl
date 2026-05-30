using Test
using OpenEXR
using Colors

# Tests for the load(path) auto-detection and the type-asserted load(path, T)
# variants introduced in Chunk 6.

@testset "load(path) auto-detection" begin
    mktempdir() do dir
        # 1. RGBA file -> Colors-typed Array{RGBA{Float16}, 2}.
        rgba_path = joinpath(dir, "rgba.exr")
        rgba_img = rand(RGBA{Float16}, 8, 6)
        OpenEXR.save(rgba_path, rgba_img)
        loaded = OpenEXR.load(rgba_path)
        @test loaded isa Array{RGBA{Float16}, 2}
        @test loaded == rgba_img

        # 2. SpectralCube file -> SpectralCube{Float32}.
        spec_path = joinpath(dir, "spec.exr")
        spec = SpectralCube(
            rand(Float32, 4, 3, 5), Float32[400, 500, 600, 700, 800],
        )
        OpenEXR.save(spec_path, spec)
        loaded = OpenEXR.load(spec_path)
        @test loaded isa SpectralCube{Float32}
        @test loaded.wavelengths == Float32[400, 500, 600, 700, 800]
        @test loaded.data == spec.data

        # 3. Renderer-style output (R, G, B, Z) -> ExrFile (channel set is
        # not one of the four Colors-recognized layouts).
        aov_path = joinpath(dir, "aov.exr")
        OpenEXR.save(aov_path;
            channels = Dict{String, AbstractArray}(
                "R" => rand(Float32, 4, 3),
                "G" => rand(Float32, 4, 3),
                "B" => rand(Float32, 4, 3),
                "Z" => rand(Float32, 4, 3),
            ),
        )
        loaded = OpenEXR.load(aov_path)
        @test loaded isa ExrFile
        @test Set(keys(loaded.channels)) == Set(["R", "G", "B", "Z"])

        # 4. Single-channel "Y" -> Colors path (Gray{Float16}).
        y_path = joinpath(dir, "y.exr")
        y_img = rand(Gray{Float16}, 4, 3)
        OpenEXR.save(y_path, y_img)
        loaded = OpenEXR.load(y_path)
        @test loaded isa Array{Gray{Float16}, 2}

        # 5. Two-channel "Y, A" -> Colors path (GrayA{Float16}).
        ya_path = joinpath(dir, "ya.exr")
        ya_img = rand(GrayA{Float16}, 4, 3)
        OpenEXR.save(ya_path, ya_img)
        loaded = OpenEXR.load(ya_path)
        @test loaded isa Array{GrayA{Float16}, 2}

        # 6. Three-channel "R, G, B" -> Colors path (RGB{Float16}).
        rgb_path = joinpath(dir, "rgb.exr")
        rgb_img = rand(RGB{Float16}, 4, 3)
        OpenEXR.save(rgb_path, rgb_img)
        loaded = OpenEXR.load(rgb_path)
        @test loaded isa Array{RGB{Float16}, 2}
    end
end

@testset "load(path, T) type-asserted" begin
    mktempdir() do dir
        # Set up fixtures of each kind.
        rgba_path = joinpath(dir, "rgba.exr")
        OpenEXR.save(rgba_path, rand(RGBA{Float16}, 8, 6))

        spec_path = joinpath(dir, "spec.exr")
        OpenEXR.save(
            spec_path,
            SpectralCube(
                rand(Float32, 4, 3, 5), Float32[400, 500, 600, 700, 800],
            ),
        )

        aov_path = joinpath(dir, "aov.exr")
        OpenEXR.save(aov_path;
            channels = Dict{String, AbstractArray}(
                "R" => rand(Float32, 4, 3),
                "G" => rand(Float32, 4, 3),
                "B" => rand(Float32, 4, 3),
                "Z" => rand(Float32, 4, 3),
            ),
        )

        # Successful assertions: shape matches the target.
        @test OpenEXR.load(rgba_path, Array{RGBA{Float16}, 2}) isa
              Array{RGBA{Float16}, 2}
        @test OpenEXR.load(spec_path, SpectralCube) isa SpectralCube
        @test OpenEXR.load(aov_path, ExrFile) isa ExrFile
        # Every file is loadable as ExrFile (the generic catch-all type).
        @test OpenEXR.load(spec_path, ExrFile) isa ExrFile
        @test OpenEXR.load(rgba_path, ExrFile) isa ExrFile

        # Mismatched assertions: shape does not match the requested target.
        @test_throws ArgumentError OpenEXR.load(rgba_path, SpectralCube)
        @test_throws ArgumentError OpenEXR.load(spec_path, Array{RGBA{Float16}, 2})
        @test_throws ArgumentError OpenEXR.load(aov_path, SpectralCube)
        @test_throws ArgumentError OpenEXR.load(aov_path, Array{RGBA{Float16}, 2})

        # Channel-set mismatch (asking for RGBA on a file that loads as RGB).
        rgb_path = joinpath(dir, "rgb.exr")
        OpenEXR.save(rgb_path, rand(RGB{Float16}, 4, 3))
        @test_throws ArgumentError OpenEXR.load(rgb_path, Array{RGBA{Float16}, 2})
    end
end
