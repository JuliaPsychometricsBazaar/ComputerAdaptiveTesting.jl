using ComputerAdaptiveTesting.Aggregators
using PsychometricsBazaarBase.Integrators
using FittedItemBanks.DummyData: dummy_full, std_normal, SimpleItemBankSpec, StdModel4PL, VectorContinuousDomain, OneDimContinuousDomain, BooleanResponse, std_mv_normal
using ComputerAdaptiveTesting.Sim: run_random_comparison
using ComputerAdaptiveTesting.NextItemRules
using FittedItemBanks
using Base.Filesystem
using ComputerAdaptiveTesting
using FittedItemBanks.DummyData: std_normal
using ComputerAdaptiveTesting.DecisionTree: DecisionTreeGenerationConfig, generate_dt_cat
using ComputerAdaptiveTesting.Sim
using ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting.TerminationConditions
using ComputerAdaptiveTesting.Aggregators
using FittedItemBanks
using PsychometricsBazaarBase.Integrators
using PsychometricsBazaarBase.Optimizers
import PsychometricsBazaarBase.IntegralCoeffs
using ItemResponseDatasets.VocabIQ
using ItemResponseDatasets.VocabIQ: prompt_response
using GLMakie
using RIrtWrappers.Mirt

const next_item_aliases = [keys(catr_next_item_aliases)..., "drule"]

function get_item_bank()
    fit_4pl(get_marked_df_cached(); TOL=1e-2)[1]
end

# copy-pasted
function get_next_item_rule(rule_name)
    if rule_name == "drule"
        integrator = MultiDimFixedGKIntegrator([-6.0, -6.0], [6.0, 6.0], 16)
        ability_estimator = MeanAbilityEstimator(PriorAbilityEstimator(std_mv_normal(2)), integrator)
        next_item_rule = NextItemRule(DRuleItemCriterion(ability_estimator))
    else
        integrator = FixedGKIntegrator(-6.0, 6.0, 80)
        ability_estimator = MeanAbilityEstimator(PriorAbilityEstimator(std_normal), integrator)
        next_item_rule = catr_next_item_aliases[rule_name](ability_estimator)
    end
    (ability_estimator, next_item_rule)
end

function main(rule_name)
    item_bank = get_item_bank()
    ability_estimator, next_item_rule = get_next_item_rule(rule_name)
    dt = generate_dt_cat(
        DecisionTreeGenerationConfig(;
            max_depth=5,
            next_item=next_item_rule,
            ability_estimator=ability_estimator,
        ), item_bank
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS[1])
end