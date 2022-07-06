#md # How abilities converge on simulated MIRT data

# # Running a CAT based on a synthetic correct/incorrect MIRT model
#
# This example shows how to run a CAT based on a synthetic correct/incorrect
# MIRT model.

# Import order is important. We put ComputerAdaptiveTesting last so we get the
# extra dependencies.
using Makie
import Pkg
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

@automakie()

# Now we are read to generate our synthetic data using the supplied DummyData
# module. We generate an item bank with 100 items and fake responses for 3
# testees.
dims = 3
using ComputerAdaptiveTesting.DummyData: dummy_mirt_4pl, std_mv_normal
Random.seed!(42)
(item_bank, question_labels, abilities, responses) = dummy_mirt_4pl(dims; num_questions=10, num_testees=2)

# Simulate a CAT for each testee and record it using CatRecorder.
# CatRecorder collects information which can be used to draw different types of plots.
max_questions = 9
integrator = CubaIntegrator([-6.0, -6.0, -6.0], [6.0, 6.0, 6.0], CubaVegas())
ability_estimator = MeanAbilityEstimator(PriorAbilityEstimator(std_mv_normal(3)), integrator)
rules = CatRules(
    ability_estimator,
    DRuleItemCriterion(ability_estimator),
    FixedItemsTerminationCondition(max_questions)
)

# XXX: We shouldn't need to specify xs here since the distributions are not used -- rework
points = 3
xs = repeat(range(-2.5, 2.5, length=points)', dims, 1)
raw_estimator = LikelihoodAbilityEstimator()
recorder = CatRecorder(xs, responses, integrator, raw_estimator, ability_estimator, abilities)
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
    true_θ = abilities[:, testee_idx]
    abs_err = sum(abs.(θ .- true_θ))
    @info "convergence" true_θ θ abs_err
end

# Make a plot showing how the estimated value converges during the CAT.
conv_lines_fig = ability_convergence_lines(recorder; abilities=abilities)
conv_lines_fig 
