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
