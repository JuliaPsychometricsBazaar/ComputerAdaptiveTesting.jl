module ComputerAdaptiveTesting

include("./hacks.jl")

using Reexport: Reexport, @reexport

# Modules
export ConfigBase, Responses, Aggregators
export NextItemRules, TerminationConditions
export CatConfig, Sim, DecisionTree
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
include("./aggregators/Aggregators.jl")

# Extra item banks
include("./logitembank.jl")

# Stages
include("./next_item_rules/NextItemRules.jl")
include("./TerminationConditions.jl")

# Combining / running
include("./CatConfig.jl")
include("./Sim.jl")
include("./decision_tree/DecisionTree.jl")

# Stateful layer and comparison
include("./Stateful.jl")
include("./Comparison.jl")

@reexport using .CatConfig: CatLoopConfig, CatRules
@reexport using .Sim: run_cat
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