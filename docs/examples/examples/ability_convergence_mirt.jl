#md # How abilities converge on simulated MIRT data

# # Running a CAT based on a synthetic correct/incorrect MIRT model
#
# This example shows how to run a CAT based on a synthetic correct/incorrect
# MIRT model.

# Import order is important. We put ComputerAdaptiveTesting last so we get the
# extra dependencies.
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
using ComputerAdaptiveTesting.ItemBanks
using ComputerAdaptiveTesting.Integrators
import ComputerAdaptiveTesting.IntegralCoeffs
using CATPlots

# Now we are read to generate our synthetic data using the supplied DummyData
# module. We generate an item bank with 100 items and fake responses for 3
# testees.
const dims = 3
using ComputerAdaptiveTesting.DummyData: dummy_mirt_4pl, std_mv_normal
Random.seed!(42)
(item_bank, question_labels, abilities, responses) = dummy_mirt_4pl(dims; num_questions=10, num_testees=2)

# Simulate a CAT for each testee and record it using CatRecorder.
# CatRecorder collects information which can be used to draw different types of plots.
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

# Make a plot showing how the estimated value evolves during the CAT.
# We also plot the 'true' values used to generate the responses.
conv_lines_fig = ability_evolution_lines(recorder; abilities=abilities)
conv_lines_fig 

# Make an interactive plot, showing how the distribution of the ability
# likelihood evolves.

conv_dist_fig = lh_evoluation_interactive(recorder; abilities=abilities)
conv_dist_fig
