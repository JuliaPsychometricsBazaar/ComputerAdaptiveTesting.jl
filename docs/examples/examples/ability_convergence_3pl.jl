# ---
# title: How abilities converge on simulated 3PL data
# id: ability_convergence_3pl
# execute: false
# ---

#md # How abilities converge on simulated 3PL data

# # Running a CAT based on a synthetic correct/incorrect 3PL IRT model
#
# This example shows how to run a CAT based on a synthetic correct/incorrect 3PL
# IRT model.

# Import order is important. We put ComputerAdaptiveTesting last so we get the
# extra dependencies.
using Makie
import Pkg
import Random
using Distributions: Normal, cdf
using AlgebraOfGraphics
using ComputerAdaptiveTesting
using ComputerAdaptiveTesting.Sim: auto_responder
using ComputerAdaptiveTesting.NextItemRules: AbilityVarianceStateCriterion
using ComputerAdaptiveTesting.TerminationConditions: FixedItemsTerminationCondition
using ComputerAdaptiveTesting.Aggregators: PriorAbilityEstimator,
    MeanAbilityEstimator, LikelihoodAbilityEstimator
using FittedItemBanks
using ComputerAdaptiveTesting.Responses: BooleanResponse
import PsychometricsBazaarBase.IntegralCoeffs
using PsychometricsBazaarBase.Integrators
using PsychometricsBazaarBase.ConstDistributions: normal_scaled_logistic
using AdaptiveTestPlots

@automakie()

# Now we are read to generate our synthetic data using the supplied DummyData
# module. We generate an item bank with 100 items and fake responses for 3
# testees.
using FittedItemBanks.DummyData: dummy_full, std_normal, SimpleItemBankSpec, StdModel3PL
(item_bank, abilities, responses) = dummy_full(Random.default_rng(42),
    SimpleItemBankSpec(StdModel3PL(), OneDimContinuousDomain(), BooleanResponse());
    num_questions = 100,
    num_testees = 3)

# Simulate a CAT for each testee and record it using CatRecorder.
# CatRecorder collects information which can be used to draw different types of plots.
max_questions = 99
integrator = FixedGKIntegrator(-6, 6, 80)
dist_ability_est = PriorAbilityEstimator(std_normal)
ability_estimator = MeanAbilityEstimator(dist_ability_est, integrator)
rules = CatRules(ability_estimator,
    AbilityVarianceStateCriterion(dist_ability_est, integrator),
    FixedItemsTerminationCondition(max_questions))

points = 500
xs = range(-2.5, 2.5, length = points)
raw_estimator = LikelihoodAbilityEstimator()
recorder = CatRecorder(xs, responses, integrator, raw_estimator, ability_estimator)
for testee_idx in axes(responses, 2)
    tracked_responses, θ = run_cat(CatLoop(rules = rules,
            get_response = auto_responder(@view responses[:, testee_idx]),
            new_response_callback = (tracked_responses, terminating) -> recorder(tracked_responses,
                testee_idx,
                terminating)),
        item_bank)
    true_θ = abilities[testee_idx]
    abs_err = abs(θ - true_θ)
end

# Make a plot showing how the estimated value evolves during the CAT.
# We also plot the 'true' values used to generate the responses.
conv_lines_fig = ability_evolution_lines(recorder; abilities = abilities)
conv_lines_fig

# Make an interactive plot, showing how the distribution of the ability
# likelihood evolves.

conv_dist_fig = lh_evolution_interactive(recorder; abilities = abilities)
conv_dist_fig
