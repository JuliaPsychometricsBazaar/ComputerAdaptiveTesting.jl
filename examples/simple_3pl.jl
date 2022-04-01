# # Running a CAT based on a synthetic correct/incorrect 3PL IRT model
#
# This example shows how to run a CAT based on a synthetic correct/incorrect 3PL
# IRT model.

# We will use the 3PL model. We can construct such an item bank in two ways.
# Typically, the logistic c.d.f. is used as the transfer function in IRT.
# However, it in an IRT context, a scaled version intended to be close to a
# normal c.d.f. is often used. ComputerAdaptiveTesting provides
# NormalScaledLogistic, which is also used by default, for this purpose:

using ComputerAdaptiveTesting
using ComputerAdaptiveTesting.ExtraDistributions: NormalScaledLogistic
using ComputerAdaptiveTesting.Sim: auto_responder
using ComputerAdaptiveTesting.NextItemRules: NEXT_ITEM_ALIASES
using ComputerAdaptiveTesting.TerminationConditions: FixedItemsTerminationCondition
using ComputerAdaptiveTesting.Aggregators: PriorAbilityEstimator, MeanAbilityEstimator
using Makie
using CairoMakie
using Distributions: Normal, cdf

xs = -8:0.05:8
lines(xs, cdf.(Normal(), xs))
lines!(xs, cdf.(NormalScaledLogistic(), xs))
current_figure()

# Now we are read to generate our synthetic data.
using ComputerAdaptiveTesting.DummyData: dummy_3pl, STD_NORMAL
(item_bank, question_labels, abilities, responses) = dummy_3pl(;num_questions=100, num_testees=5)

# Now let's simulate the CAT for our data and find the error versus the true
# values and the values estimated from all points
for resp_idx in axes(responses, 2)
    ability_estimator = MeanAbilityEstimator(PriorAbilityEstimator(STD_NORMAL))
    config = CatLoopConfig(
        get_response=auto_responder(
            @view responses[:, resp_idx]
        ),
        next_item=NEXT_ITEM_ALIASES["MEPV"](ability_estimator),
        termination_condition=FixedItemsTerminationCondition(80),
        ability_estimator=ability_estimator,
    )
    θ = run_cat(config, item_bank)
    true_θ = abilities[resp_idx]
    abs_err = abs(θ - true_θ)
    @info "final estimated ability" resp_idx θ true_θ abs_err
end