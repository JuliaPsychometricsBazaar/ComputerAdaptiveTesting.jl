module ComputerAdaptiveTesting

include("./hacks.jl")

using Pkg
using Reexport

export ConfigBase, Responses, Aggregators, NextItemRules, TerminationConditions
export CatConfig, Sim

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
include("./Comparison.jl")

@reexport using .CatConfig: CatLoopConfig, CatRules
@reexport using .Sim: run_cat
@reexport using .NextItemRules: preallocate

end
