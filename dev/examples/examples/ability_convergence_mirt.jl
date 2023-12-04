using Makie
import Pkg
import Random
using Distributions: Normal, cdf
using AlgebraOfGraphics
using ComputerAdaptiveTesting
using ComputerAdaptiveTesting.Sim: auto_responder
using ComputerAdaptiveTesting.NextItemRules: DRuleItemCriterion
using ComputerAdaptiveTesting.TerminationConditions: FixedItemsTerminationCondition
using ComputerAdaptiveTesting.Aggregators: PriorAbilityEstimator,
    MeanAbilityEstimator, LikelihoodAbilityEstimator
using FittedItemBanks
import PsychometricsBazaarBase.IntegralCoeffs
using PsychometricsBazaarBase.Integrators
using PsychometricsBazaarBase.ConstDistributions: normal_scaled_logistic
using AdaptiveTestPlots

@automakie()

dims = 2
using FittedItemBanks.DummyData: dummy_full, std_mv_normal, SimpleItemBankSpec, StdModel4PL
using ComputerAdaptiveTesting.Responses: BooleanResponse

(item_bank, abilities, responses) = dummy_full(Random.default_rng(42),
    SimpleItemBankSpec(StdModel4PL(), VectorContinuousDomain(), BooleanResponse()),
    dims;
    num_questions = 10,
    num_testees = 2)

max_questions = 9
integrator = CubaIntegrator([-6.0, -6.0], [6.0, 6.0], CubaVegas(); rtol = 1e-2)
ability_estimator = MeanAbilityEstimator(PriorAbilityEstimator(std_mv_normal(dims)),
    integrator)
rules = CatRules(ability_estimator,
    DRuleItemCriterion(ability_estimator),
    FixedItemsTerminationCondition(max_questions))

points = 3
xs = repeat(range(-2.5, 2.5, length = points)', dims, 1)
raw_estimator = LikelihoodAbilityEstimator()
recorder = CatRecorder(xs,
    responses,
    integrator,
    raw_estimator,
    ability_estimator,
    abilities)
for testee_idx in axes(responses, 2)
    @debug "Running for testee" testee_idx
    tracked_responses, θ = run_cat(CatLoopConfig(rules = rules,
            get_response = auto_responder(@view responses[:, testee_idx]),
            new_response_callback = (tracked_responses, terminating) -> recorder(tracked_responses,
                testee_idx,
                terminating)),
        item_bank)
    true_θ = abilities[:, testee_idx]
    abs_err = sum(abs.(θ .- true_θ))
    @info "convergence" true_θ θ abs_err
end

conv_lines_fig = ability_convergence_lines(recorder; abilities = abilities)
conv_lines_fig

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
