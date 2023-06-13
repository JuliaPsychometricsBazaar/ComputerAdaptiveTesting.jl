using Random

using ComputerAdaptiveTesting.Aggregators
using PsychometricsBazaarBase.Integrators
using FittedItemBanks.DummyData: dummy_full, std_normal, SimpleItemBankSpec, StdModel4PL, VectorContinuousDomain, OneDimContinuousDomain, BooleanResponse
using ComputerAdaptiveTesting.Sim: run_random_comparison
using ComputerAdaptiveTesting.NextItemRules
using FittedItemBanks
using CATPlots: compare

const next_item_aliases = [keys(catr_next_item_aliases)..., "drule"]

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

function main()
    chosen_next_item_aliases = []
    for arg in ARGS
        if arg in keys(next_item_aliases)
            push!(chosen_next_item_aliases, arg)
        end
    end
    if length(chosen_next_item_aliases) == 0
        chosen_next_item_aliases = next_item_aliases
    end
    for next_item_alias in chosen_next_item_aliases
        show("starting $next_item_alias")
        if next_item_alias == "drule"
            (item_bank, abilities, responses) = dummy_full(
                Random.default_rng(42),
                SimpleItemBankSpec(StdModel4PL(), VectorContinuousDomain(), BooleanResponse()),
                2;
                num_questions=100,
                num_testees=3
            )
        else
            (item_bank, abilities, responses) = dummy_full(
                Random.default_rng(42),
                SimpleItemBankSpec(StdModel4PL(), OneDimContinuousDomain(), BooleanResponse());
                num_questions=100,
                num_testees=3
            )
        end
        (ability_estimator, next_item_rule) = get_next_item_rule(next_item_alias)
        comparison = run_random_comparison(next_item_rule, ability_estimator, item_bank, responses, 50)
        show("# $next_item_alias")
        show(compare(comparison))
        #=run_cat(CatLoopConfig(
            CatRules(next_item_rule),
            auto
        ))=#
    end
end

main()