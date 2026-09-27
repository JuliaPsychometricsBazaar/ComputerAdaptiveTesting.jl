module LikelihoodWeightedCriteriaTests

using Test
using Distributions: Normal, pdf
using FittedItemBanks
using ComputerAdaptiveTesting.Responses
using ComputerAdaptiveTesting.Aggregators
using ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting.NextItemRules: PointwiseItemCriterion,
    PointwiseItemCategoryCriterion
using PsychometricsBazaarBase.Integrators: FixedGKIntegrator, intval

struct TestItemCriterion <: PointwiseItemCriterion end
struct TestCategoryCriterion <: PointwiseItemCategoryCriterion end

NextItemRules.compute_criterion(::TestItemCriterion, ::ItemResponse, ability) = ability^2 + 2
NextItemRules.compute_criterion(::TestCategoryCriterion, ::ItemResponse, ability, category) =
    ability^2 + category

@testset "Likelihood-weighted criteria apply density once" begin
    xs = [-1.0, 0.0, 1.0]
    bank = DichotomousPointsItemBank(xs, reshape([0.2, 0.4, 0.8], :, 1))
    history = BareResponses(ResponseType(bank), [1], [true])
    tracked = TrackedResponses(history, bank)
    prior = Normal(0.4, 1.1)

    for (estimator, prior_weights) in (
        (LikelihoodAbilityEstimator(), ones(length(xs))),
        (PosteriorAbilityEstimator(prior), pdf.(Ref(prior), xs)),
    )
        weights = [0.2, 0.4, 0.8] .* prior_weights
        integrator = RiemannEnumerationIntegrator()
        item = LikelihoodWeightedItemCriterion(TestItemCriterion(), integrator, estimator)
        category = LikelihoodWeightedItemCategoryCriterion(
            TestCategoryCriterion(), integrator, estimator)
        @test compute_criterion(item, tracked, 1) ≈ sum(weights .* (xs .^ 2 .+ 2))
        @test compute_criterion(category, tracked, 1, 2) ≈
              sum(weights .* (xs .^ 2 .+ 2))
    end

    continuous_bank = ItemBank2PL([0.0], [1.0])
    continuous_tracked = TrackedResponses(
        BareResponses(ResponseType(continuous_bank), [1], [true]), continuous_bank)
    quadrature = FixedGKIntegrator(-6.0, 6.0, 61)
    integrator = FunctionIntegrator(quadrature)
    likelihood = AbilityLikelihood(continuous_tracked)
    for (estimator, prior_factor) in (
        (LikelihoodAbilityEstimator(), _ -> 1.0),
        (PosteriorAbilityEstimator(prior), x -> pdf(prior, x)),
    )
        reference = intval(quadrature(x -> (x^2 + 2) * likelihood(x) * prior_factor(x), 0))
        item = LikelihoodWeightedItemCriterion(TestItemCriterion(), integrator, estimator)
        category = LikelihoodWeightedItemCategoryCriterion(
            TestCategoryCriterion(), integrator, estimator)
        @test compute_criterion(item, continuous_tracked, 1) ≈ reference
        @test compute_criterion(category, continuous_tracked, 1, 2) ≈ reference
    end
end

end
