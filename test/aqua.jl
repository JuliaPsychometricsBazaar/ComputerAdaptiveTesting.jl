using Aqua
using ComputerAdaptiveTesting

@testset "aqua" begin
    Aqua.test_all(
        ComputerAdaptiveTesting;
        ambiguities = false,
        # The persistent tasks test builds a temporary environment holding the
        # newest version of every dependency and precompiles it from scratch,
        # even when the test environment itself has been downgraded. That
        # precompilation fails on CI with
        # "Module <Ext> is missing from the cache", because the package
        # extensions are still being built by another precompilation process,
        # and Aqua then reports the failure as a persistent task. See
        # https://github.com/JuliaTesting/Aqua.jl/issues/315.
        persistent_tasks = false
    )
    # Ambiguities are not tested in default configuration as a workaround for
    # https://github.com/JuliaTesting/Aqua.jl/issues/77
    # Core is not included because of Core.Number, namely

    # ComputerAdaptiveTesting gets errors from FowardDiff extending Core.Number
    # Could possibly get some of these fixed in ForwardDiff eventually?
    # https://github.com/JuliaDiff/ForwardDiff.jl/issues/597
    Aqua.test_ambiguities([ComputerAdaptiveTesting])
end
