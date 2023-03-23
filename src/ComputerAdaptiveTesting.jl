module ComputerAdaptiveTesting

using Pkg
using Reexport

export ConfigBase, Responses, ItemBanks, Aggregators, NextItemRules, TerminationConditions
export CatConfig, Sim, DummyData

# Vendored dependencies
include("./vendor/Parameters.jl")

# Config base
include("./ConfigBase.jl")
    
# Base
include("./Responses.jl")
include("./MathTraits.jl")

# Near base
include("./item_banks/ItemBanks.jl")
include("./aggregators/Aggregators.jl")

# Stages
include("./next_item_rules/NextItemRules.jl")
include("./TerminationConditions.jl")

# Combining / running
include("./CatConfig.jl")
include("./Sim.jl")

# Peripheral / contrib
include("DummyData.jl")

@reexport using .CatConfig: CatLoopConfig, CatRules
@reexport using .Sim: run_cat

end
