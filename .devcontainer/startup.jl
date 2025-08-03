# Development startup file for ComputerAdaptiveTesting.jl
# This file is automatically loaded when Julia starts in the devcontainer

try
    using Revise
    @info "✅ Revise.jl loaded - automatic code reloading enabled"
catch e
    @warn "Could not load Revise.jl" exception=e
end

try
    using OhMyREPL
    @info "✅ OhMyREPL.jl loaded - enhanced REPL experience enabled"
catch e
    @warn "Could not load OhMyREPL.jl" exception=e
end

# Load the project if we're in the right directory
if isfile("Project.toml")
    try
        using Pkg
        Pkg.activate(".")
        @info "✅ Project environment activated"

        # Pre-load common development packages
        try
            using BenchmarkTools
            @info "✅ BenchmarkTools.jl available (@benchmark, @btime)"
        catch e
            @debug "BenchmarkTools.jl not available" exception=e
        end

        try
            using Test
            @info "✅ Test.jl available (@test, @testset)"
        catch e
            @debug "Test.jl not available" exception=e
        end

    catch e
        @warn "Could not activate project environment" exception=e
    end
end

@info """
🎉 ComputerAdaptiveTesting.jl development environment ready!

Quick commands:
  - Run tests: julia --project=test test/runtests.jl
  - Build docs: julia --project=docs docs/make.jl
  - Load package: using ComputerAdaptiveTesting
  - Benchmark: @benchmark your_function()
  - Profile: @profile your_function()
"""
