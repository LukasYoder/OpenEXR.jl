using Test
using OpenEXR

# Helper: write a tiny single-channel EXR with the given attribute set, then
# read it back through the attribute marshaller and return the resulting Dict.
# Builds the file via OpenEXR.Core directly so this test suite does not depend
# on SpectralCube / ExrFile (which arrive in later chunks).
function _attr_roundtrip(attributes::AbstractDict{String, <:Any})
    mktempdir() do dir
        path = joinpath(dir, "attrs.exr")
        OpenEXR._write_single_channel_with_attrs(path, attributes)
        return OpenEXR._read_attributes_from_file(path)
    end
end

@testset "Attribute marshalling round-trip" begin
    @testset "string" begin
        @test _attr_roundtrip(Dict{String, Any}("k" => "hello"))["k"] === "hello"
        @test _attr_roundtrip(Dict{String, Any}("k" => ""))["k"] === ""
        @test _attr_roundtrip(Dict{String, Any}("k" => "café — π"))["k"] === "café — π"
    end

    @testset "string vector" begin
        @test _attr_roundtrip(Dict{String, Any}("k" => ["a", "b", "c"]))["k"] == ["a", "b", "c"]
        @test _attr_roundtrip(Dict{String, Any}("k" => String[]))["k"] == String[]
    end

    @testset "int / float / double" begin
        @test _attr_roundtrip(Dict{String, Any}("k" => Int32(42)))["k"] === Int32(42)
        @test _attr_roundtrip(Dict{String, Any}("k" => Float32(3.14)))["k"] === Float32(3.14)
        @test _attr_roundtrip(Dict{String, Any}("k" => Float64(3.14)))["k"] === Float64(3.14)
        # Int (host word) narrows to Int32 on write
        @test _attr_roundtrip(Dict{String, Any}("k" => 42))["k"] === Int32(42)
    end

    @testset "floatvector" begin
        @test _attr_roundtrip(Dict{String, Any}("k" => Float32[1.0, 2.0, 3.0]))["k"] == Float32[1.0, 2.0, 3.0]
        @test _attr_roundtrip(Dict{String, Any}("k" => Float32[]))["k"] == Float32[]
    end

    @testset "v2/v3 ntuples" begin
        @test _attr_roundtrip(Dict{String, Any}("k" => (Int32(1), Int32(2))))["k"] === (Int32(1), Int32(2))
        @test _attr_roundtrip(Dict{String, Any}("k" => (Float32(1), Float32(2))))["k"] === (Float32(1), Float32(2))
        @test _attr_roundtrip(Dict{String, Any}("k" => (Float64(1), Float64(2))))["k"] === (Float64(1), Float64(2))
        @test _attr_roundtrip(Dict{String, Any}("k" => (Int32(1), Int32(2), Int32(3))))["k"] === (Int32(1), Int32(2), Int32(3))
    end

    @testset "box2 ntuples" begin
        @test _attr_roundtrip(Dict{String, Any}("k" => (Int32(0), Int32(0), Int32(99), Int32(99))))["k"] === (Int32(0), Int32(0), Int32(99), Int32(99))
    end

    @testset "matrix m33f / m44f" begin
        m33 = Float32[1 2 3; 4 5 6; 7 8 9]
        @test _attr_roundtrip(Dict{String, Any}("k" => m33))["k"] == m33
        m44 = Float32.(reshape(1:16, 4, 4))
        @test _attr_roundtrip(Dict{String, Any}("k" => m44))["k"] == m44
    end

    @testset "chromaticities" begin
        chrom = (red_x = 0.640f0, red_y = 0.330f0,
                 green_x = 0.300f0, green_y = 0.600f0,
                 blue_x = 0.150f0, blue_y = 0.060f0,
                 white_x = 0.3127f0, white_y = 0.3290f0)
        @test _attr_roundtrip(Dict{String, Any}("k" => chrom))["k"] == chrom
    end

    @testset "rational" begin
        @test _attr_roundtrip(Dict{String, Any}("k" => Rational{Int32}(24, 1)))["k"] === Rational{Int32}(24, 1)
    end

    @testset "envmap / lineorder symbols" begin
        # These attribute types live as enum-valued attributes on disk.
        # When the user supplies them as Symbols, the writer dispatches to
        # the enum-typed setter.
        @test _attr_roundtrip(Dict{String, Any}("envmap" => :latlong))["envmap"] === :latlong
        # Arbitrary Symbol values cannot strictly round-trip through EXR's
        # closed envmap enum (the C side accepts only EXR_ENVMAP_LATLONG /
        # _CUBE). Non-canonical symbols are stored as LATLONG by convention,
        # so the read side returns :latlong, not the original symbol. This is
        # a spec-level limitation of the EXR data model; the test stays as
        # @test_broken so the contract is visible.
        @test_broken _attr_roundtrip(Dict{String, Any}("k" => :something_envmap_like))["k"] === :something_envmap_like
    end

    @testset "reserved names emit warning on write" begin
        # `compression` is reserved (surfaced via struct field, not attributes Dict)
        @test_logs (:warn, r"compression") _attr_roundtrip(Dict{String, Any}("compression" => "zip"))
    end

    @testset "unknown EXR type surfaces as Vector{UInt8} with warning" begin
        # No direct Julia-side write for this -- best done by hand-crafting a
        # fixture file with an unknown attribute type. Implement as a Skipped
        # test for now; full coverage in Chunk 6 with fixtures.
        @test_skip false
    end
end
