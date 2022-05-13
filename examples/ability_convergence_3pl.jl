#md # How abilities converge on simulated 3PL data
#
#md # [![](https://mybinder.org/badge_logo.svg)](@__BINDER_ROOT_URL__/generated/ability_convergence_3pl.ipynb)

# # Running a CAT based on a synthetic correct/incorrect 3PL IRT model
#
# This example shows how to run a CAT based on a synthetic correct/incorrect 3PL
# IRT model.

# Import order is important. We put ComputerAdaptiveTesting last so we get the
# extra dependencies.
include("./import_makie.jl")
import Random
using Distributions: Normal, cdf
using AlgebraOfGraphics
using ComputerAdaptiveTesting
using ComputerAdaptiveTesting.ExtraDistributions: NormalScaledLogistic
using ComputerAdaptiveTesting.Sim: auto_responder
using ComputerAdaptiveTesting.NextItemRules: AbilityVarianceStateCriterion
using ComputerAdaptiveTesting.TerminationConditions: FixedItemsTerminationCondition
using ComputerAdaptiveTesting.Aggregators: PriorAbilityEstimator, MeanAbilityEstimator, integrate, LikelihoodAbilityEstimator
using ComputerAdaptiveTesting.Plots
using ComputerAdaptiveTesting.ItemBanks
using ComputerAdaptiveTesting.Integrators
import ComputerAdaptiveTesting.IntegralCoeffs

# Now we are read to generate our synthetic data using the supplied DummyData
# module. We generate an item bank with 100 items and fake responses for 3
# testees.
using ComputerAdaptiveTesting.DummyData: dummy_3pl, std_normal
Random.seed!(42)
(item_bank, question_labels, abilities, responses) = dummy_3pl(;num_questions=100, num_testees=3)

# Simulate a CAT for each testee and record it using CatRecorder.
# CatRecorder collects information which can be used to draw different types of plots.
const max_questions = 99
const integrator = FixedGKIntegrator(-10.0, 10.0, 80)
const ability_estimator = MeanAbilityEstimator(PriorAbilityEstimator(std_normal, integrator))
const rules = CatRules(
    ability_estimator,
    AbilityVarianceStateCriterion(),
    FixedItemsTerminationCondition(max_questions)
)

const points = 500
xs = range(-2.5, 2.5, length=points)
raw_estimator = LikelihoodAbilityEstimator(integrator)
recorder = CatRecorder(xs, responses, raw_estimator, ability_estimator)
for testee_idx in axes(responses, 2)
    θ = run_cat(
        CatLoopConfig(
            rules=rules,
            get_response=auto_responder(@view responses[:, testee_idx]),
            new_response_callback=(tracked_responses, terminating) -> recorder(tracked_responses, testee_idx, terminating),
        ),
        item_bank
    )
    true_θ = abilities[testee_idx]
    abs_err = abs(θ - true_θ)
end

# Make a plot showing how the estimated value evolves during the CAT.
# We also plot the 'true' values used to generate the responses.
conv_lines_fig = ability_evolution_lines(recorder; abilities=abilities)
conv_lines_fig 

# Make an interactive plot, showing how the distribution of the ability
# likelihood evolves.

conv_dist_fig = lh_evoluation_interactive(recorder; abilities=abilities)
conv_dist_fig