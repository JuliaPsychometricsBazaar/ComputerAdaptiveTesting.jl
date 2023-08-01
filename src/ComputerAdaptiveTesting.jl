module ComputerAdaptiveTesting

using Pkg
using Reexport

export ConfigBase, Responses, Aggregators, NextItemRules, TerminationConditions
export CatConfig, Sim

# Vendored dependencies
include("./vendor/Parameters.jl")
include("./vendor/PushVectors.jl")

# Config base
include("./ConfigBase.jl")
    
# Base
include("./Responses.jl")

# Near base
include("./aggregators/Aggregators.jl")

# Stages
include("./next_item_rules/NextItemRules.jl")
include("./TerminationConditions.jl")

# Combining / running
include("./CatConfig.jl")
include("./Sim.jl")
include("./DecisionTree.jl")

@reexport using .CatConfig: CatLoopConfig, CatRules
@reexport using .Sim: run_cat

end
