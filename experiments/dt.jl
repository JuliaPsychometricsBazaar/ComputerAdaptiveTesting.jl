using ComputerAdaptiveTesting.Aggregators
using PsychometricsBazaarBase.Integrators
using FittedItemBanks.DummyData: dummy_full, std_normal, std_mv_normal
using ComputerAdaptiveTesting.Sim: run_random_comparison
using FittedItemBanks
using Base.Filesystem
using ComputerAdaptiveTesting
using ComputerAdaptiveTesting.DecisionTree: DecisionTreeGenerationConfig, generate_dt_cat, save_mmap
using ComputerAdaptiveTesting.Sim
using ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting.TerminationConditions
using ComputerAdaptiveTesting.Aggregators
using FittedItemBanks
using PsychometricsBazaarBase.Integrators
using PsychometricsBazaarBase.Optimizers
import PsychometricsBazaarBase.IntegralCoeffs
using ItemResponseDatasets.VocabIQ
using RIrtWrappers.Mirt
using Random
using Distributions
using Profile.Allocs: @profile
using PProf


include("./utils/RandomItemBanks.jl")

using .RandomItemBanks: clumpy_4pl_item_bank

const next_item_aliases = [keys(catr_next_item_aliases)..., "drule"]

# copy-pasted
function get_next_item_rule(rule_name)::Tuple{AbilityEstimator, NextItemRule}
    if rule_name == "drule"
        integrator = MultiDimFixedGKIntegrator([-6.0, -6.0], [6.0, 6.0], 16)
        ability_estimator = MeanAbilityEstimator(PriorAbilityEstimator(std_mv_normal(2)), integrator)
        next_item_rule = NextItemRule(DRuleItemCriterion(ability_estimator))
    elseif rule_name == "mepv_rect"
        integrator = even_grid(-6.0, 6.0, 39)
        ability_estimator = MeanAbilityEstimator(PriorAbilityEstimator(std_normal), integrator)
        next_item_rule = preallocate(catr_next_item_aliases["MEPV"](ability_estimator))
        @info "mepv_rect" integrator ability_estimator next_item_rule
    else
        integrator = FixedGKIntegrator(-6.0, 6.0, 80)
        ability_estimator = MeanAbilityEstimator(PriorAbilityEstimator(std_normal), integrator)
        next_item_rule = catr_next_item_aliases[rule_name](ability_estimator)
    end
    (ability_estimator, next_item_rule)
end


function main(rule_name, out_dir)
    rng = Xoshiro(42)
    params = clumpy_4pl_item_bank(rng, 3, 1000)
    ability_estimator, next_item_rule = get_next_item_rule(rule_name)
    dt = @time generate_dt_cat(
        DecisionTreeGenerationConfig(;
            max_depth=UInt(2),
            next_item=next_item_rule,
            ability_estimator=ability_estimator,
        ), params
    )
    config = @time DecisionTreeGenerationConfig(;
        max_depth=UInt(4),
        next_item=next_item_rule,
        ability_estimator=ability_estimator,
    )
    dt = @time generate_dt_cat(config, params)
    save_mmap(out_dir, dt)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS[1], ARGS[2])
end
