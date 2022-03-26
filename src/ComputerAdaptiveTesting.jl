module ComputerAdaptiveTesting

using Reexport

export ExtraDistributions, IntegralCoeffs, Integrators, Interpolators, Optimizers
export ConfigBase, Responses, IOUtils, ItemBanks, Aggregators, NextItemRules, TerminationConditions
export CatConfig, Sim, Plots, DummyData, Postprocess
    
# Maths stuff (no dependencies)
include("./maths/ExtraDistributions.jl")
include("./maths/IntegralCoeffs.jl")
include("./maths/Integrators.jl")
include("./maths/Interpolators.jl")
include("./maths/Optimizers.jl")

# Base
include("./ConfigBase.jl")
include("./Responses.jl")
include("./IOUtils.jl")

# Near base
include("./item_banks/ItemBanks.jl")
include("aggregators/Aggregators.jl")

# Stages
include("next_item_rules/NextItemRules.jl")
include("TerminationConditions.jl")

# Combining / running
include("CatConfig.jl")
include("Sim.jl")

# Peripheral / contrib
include("Plots.jl")
include("DummyData.jl")
include("postprocess/Postprocess.jl")

@reexport using .CatConfig: CatLoopConfig 
@reexport using .Sim: run_cat

end