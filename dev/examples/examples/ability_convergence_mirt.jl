using Makie
import Pkg
if isdefined(Main, :IJulia) && Main.IJulia.inited
    using WGLMakie
elseif "GLMakie" in keys(Pkg.project().dependencies)
    using GLMakie
else
    using CairoMakie
end
import Random
using Distributions: Normal, cdf
using AlgebraOfGraphics
using ComputerAdaptiveTesting
using ComputerAdaptiveTesting.ExtraDistributions: NormalScaledLogistic
using ComputerAdaptiveTesting.Sim: auto_responder
using ComputerAdaptiveTesting.NextItemRules: DRuleItemCriterion
using ComputerAdaptiveTesting.TerminationConditions: FixedItemsTerminationCondition
using ComputerAdaptiveTesting.Aggregators: PriorAbilityEstimator, MeanAbilityEstimator, LikelihoodAbilityEstimator
using ComputerAdaptiveTesting.Plots
using ComputerAdaptiveTesting.ItemBanks
using ComputerAdaptiveTesting.Integrators
import ComputerAdaptiveTesting.IntegralCoeffs

const dims = 3
using ComputerAdaptiveTesting.DummyData: dummy_mirt_4pl, std_mv_normal
Random.seed!(42)
(item_bank, question_labels, abilities, responses) = dummy_mirt_4pl(dims; num_questions=10, num_testees=2)

const max_questions = 9
const integrator = MultiDimFixedGKIntegrator([-6.0, -6.0, -6.0], [6.0, 6.0, 6.0])
const ability_estimator = MeanAbilityEstimator(PriorAbilityEstimator(std_mv_normal(3)), integrator)
const rules = CatRules(
    ability_estimator,
    DRuleItemCriterion(ability_estimator),
    FixedItemsTerminationCondition(max_questions)
)

const points = 500
xs = repeat(range(-2.5, 2.5, length=points)', dims, 1)
raw_estimator = LikelihoodAbilityEstimator()
recorder = CatRecorder(xs, responses, integrator, raw_estimator, ability_estimator)
for testee_idx in axes(responses, 2)
    @debug "Running for testee" testee_idx
    tracked_responses, θ = run_cat(
        CatLoopConfig(
            rules=rules,
            get_response=auto_responder(@view responses[:, testee_idx]),
            new_response_callback=(tracked_responses, terminating) -> recorder(tracked_responses, testee_idx, terminating),
        ),
        item_bank
    )
    true_θ = abilities[testee_idx]
    abs_err = sum(abs(θ .- true_θ))
end

conv_lines_fig = ability_evolution_lines(recorder; abilities=abilities)
conv_lines_fig

conv_dist_fig = lh_evoluation_interactive(recorder; abilities=abilities)
conv_dist_fig

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl

