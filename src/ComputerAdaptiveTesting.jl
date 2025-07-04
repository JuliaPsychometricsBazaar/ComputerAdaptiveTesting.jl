module ComputerAdaptiveTesting

include("./hacks.jl")

using Reexport: Reexport, @reexport

# Modules
export Responses, Aggregators
export NextItemRules, TerminationConditions
export Sim, DecisionTree
export Stateful, Comparison

# Extension modules
public require_testext

# Vendored dependencies
include("./vendor/PushVectors.jl")

# Config base
include("./ConfigBase.jl")

# Base
include("./Responses.jl")

# Near base
include("./Aggregators/Aggregators.jl")

# Extra item banks
include("./logitembank.jl")

# Stages
include("./NextItemRules/NextItemRules.jl")
include("./TerminationConditions.jl")

# Combining / running
include("./Rules.jl")
include("./Sim/Sim.jl")
include("./DecisionTree/DecisionTree.jl")

# Stateful layer, compat, and comparison
include("./Stateful.jl")
include("./Compat/Compat.jl")
include("./Comparison/Comparison.jl")

@reexport using .Rules: CatRules
@reexport using .Sim: CatLoop, run_cat
@reexport using .NextItemRules: preallocate

include("./precompiles.jl")

function require_testext()
    TestExt = Base.get_extension(@__MODULE__, :TestExt)
    if TestExt === nothing
        error("Failed to load extension module TestExt.")
    end
    return TestExt
end

end