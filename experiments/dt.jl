using ComputerAdaptiveTesting.Aggregators
using PsychometricsBazaarBase.Integrators
using FittedItemBanks.DummyData: dummy_full, std_normal, std_mv_normal
using ComputerAdaptiveTesting.Sim: run_random_comparison
using ComputerAdaptiveTesting.NextItemRules
using FittedItemBanks
using Base.Filesystem
using ComputerAdaptiveTesting
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
using RIrtWrappers.Mirt
using Random
using Distributions

const next_item_aliases = [keys(catr_next_item_aliases)..., "drule"]

pclamp(x) = clamp.(x, 0.0, 1.0)
abs_rand(rng, dist, dims...) = abs.(rand(rng, dist, dims...))
clamp_rand(rng, dist, dims...) = pclamp.(rand(rng, dist, dims...))

function clumpy_4pl_item_bank(rng, num_clumps, num_questions)
    clump_dist_mat = hcat(
        Normal.(rand(rng, Normal(), num_clumps), 0.1),  # Difficulty
        Normal.(abs_rand(rng, Normal(1.0, 0.2), num_clumps), 0.1),  # Discrimination
        Normal.(clamp_rand(rng, Normal(0.1, 0.2), num_clumps), 0.02),  # Guess
        Normal.(clamp_rand(rng, Normal(0.1, 0.2), num_clumps), 0.02)  # Slip
    )
    params_clumps = mapslices(Product, clump_dist_mat; dims=[2])[:, 1]
    # TODO: Resample the clumps to create a correlated distribution
    params = Array{Float64, 2}(undef, num_questions, 4)
    for (question_idx, clump) in enumerate(sample(rng, params_clumps, num_questions; replace=true))
        (difficulty, discrimination, guess, slip) = rand(rng, clump)
        params[question_idx, :] = [difficulty, abs(discrimination), pclamp(guess), pclamp(slip)]
    end
    ItemBank4PL(params[:, 1], params[:, 2], params[:, 3], params[:, 4])
end

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

function main(rule_name)
    rng = Xoshiro(42)
    params = clumpy_4pl_item_bank(rng, 3, 1000)
    ability_estimator, next_item_rule = get_next_item_rule(rule_name)
    dt = generate_dt_cat(
        DecisionTreeGenerationConfig(;
            max_depth=UInt(1),
            next_item=next_item_rule,
            ability_estimator=ability_estimator,
        ), params
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS[1])
end