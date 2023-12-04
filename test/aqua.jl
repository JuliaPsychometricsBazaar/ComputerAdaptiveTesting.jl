using Aqua
using ComputerAdaptiveTesting

Aqua.test_all(
    ComputerAdaptiveTesting;
    ambiguities=false,
)
# Ambiguities are not tested in default configuration as a workaround for
# https://github.com/JuliaTesting/Aqua.jl/issues/77
# Core is not included because of Core.Number, namely

# ComputerAdaptiveTesting gets errors from FowardDiff extending Core.Number
# Could possibly get some of these fixed in ForwardDiff eventually?
# https://github.com/JuliaDiff/ForwardDiff.jl/issues/597
Aqua.test_ambiguities([ComputerAdaptiveTesting])
