using Test
using OpenEXR

@testset "Core bindings smoke" begin
    @testset "module exists with expected functions" begin
        @test isa(OpenEXR.Core, Module)
        @test isdefined(OpenEXR.Core, :exr_start_read)
        @test isdefined(OpenEXR.Core, :exr_finish)
        @test isdefined(OpenEXR.Core, :exr_get_count)
        @test isdefined(OpenEXR.Core, :exr_encoding_initialize)
        @test isdefined(OpenEXR.Core, :exr_decoding_initialize)
    end

    @testset "library version reports nonempty string" begin
        # exr_get_library_version writes the version components into Ref{Cint}.
        # The `extra` out-param is a `Ptr{Cstring}` in the C signature, so a
        # Ref{Cstring} is the correct Julia container.
        maj = Ref{Cint}(-1); min_ = Ref{Cint}(-1); patch = Ref{Cint}(-1)
        extra = Ref{Cstring}(Cstring(C_NULL))
        OpenEXR.Core.exr_get_library_version(maj, min_, patch, extra)
        @test maj[] >= 3
        @test min_[] >= 0
        @test patch[] >= 0
    end

    @testset "pipeline structs are mutable with pipe_size at offset 0" begin
        # The size-versioned C structs require pipe_size at field index 1.
        # Note: Clang.jl emits as `mutable struct _exr_encode_pipeline` plus a
        # `const exr_encode_pipeline_t = _exr_encode_pipeline` typealias. Both
        # `ismutabletype` and `fieldoffset` resolve through the alias.
        @test ismutabletype(OpenEXR.Core.exr_encode_pipeline_t)
        @test ismutabletype(OpenEXR.Core.exr_decode_pipeline_t)
        @test fieldoffset(OpenEXR.Core.exr_encode_pipeline_t, 1) == 0
        @test fieldoffset(OpenEXR.Core.exr_decode_pipeline_t, 1) == 0
        @test fieldname(OpenEXR.Core.exr_encode_pipeline_t, 1) == :pipe_size
        @test fieldname(OpenEXR.Core.exr_decode_pipeline_t, 1) == :pipe_size
    end

    @testset "pixel-type constants exist" begin
        # @cenum exports EXR_PIXEL_UINT/HALF/FLOAT at the module level.
        @test isdefined(OpenEXR.Core, :EXR_PIXEL_UINT)
        @test isdefined(OpenEXR.Core, :EXR_PIXEL_HALF)
        @test isdefined(OpenEXR.Core, :EXR_PIXEL_FLOAT)
    end
end
