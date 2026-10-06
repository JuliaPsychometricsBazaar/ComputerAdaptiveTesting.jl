module ConfigurationAPITests

using Test
using ComputerAdaptiveTesting: CatRules, Stateful, Rules, Aggregators
using ComputerAdaptiveTesting.Aggregators
using ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting.TerminationConditions
using ComputerAdaptiveTesting.Responses
using PsychometricsBazaarBase.Integrators: FixedGridIntegrator, QuadGKIntegrator
using PsychometricsBazaarBase.Optimizers: NativeOneDimOptimOptimizer
using FittedItemBanks
using Distributions: Normal, logpdf

mutable struct CountingTracker <: AbilityTracker
    calls::Int
end
Aggregators.track!(responses, tracker::CountingTracker) = (tracker.calls += 1)

@testset "Public space configuration" begin
    grid = FixedGridIntegrator(range(-6, 6; length=121))
    bank = ItemBank2PL([0.0, 0.5, 1.0], [1.0, 1.0, 1.0])
    for space in (LinSpace(), LogSpace())
        dist = PosteriorAbilityEstimator(Normal(-0.5, 1.0), space)
        rules = CatRules(dist, grid, MeanAbilityEstimator, InformationItemCriterion, FixedLength(2))
        cat = Stateful.StatefulCatRules(rules, bank)
        @test Stateful.logdensity(cat, 0.0) == logpdf(dist.prior, 0.0)
        Stateful.add_response!(cat, 1, true)
        expected = FittedItemBanks.log_resp(ItemResponse(bank, 1), true, 0.0) + logpdf(dist.prior, 0.0)
        @test Stateful.logdensity(cat, 0.0) ≈ expected
        @test Stateful.likelihood(cat, 0.0) ≈ exp(expected)
        @test isfinite(first(Stateful.get_ability(cat)))
        @test Stateful.next_item(cat) in 2:3
        Stateful.rollback!(cat)
        @test Stateful.logdensity(cat, 0.0) == logpdf(dist.prior, 0.0)
        description = sprint(show, MIME("text/plain"), rules)
        @test occursin(space == LogSpace() ? "log space" : "linear space", description)
        optimizer = NativeOneDimOptimOptimizer(; lo=-6.0, hi=6.0)
        mode_rules = CatRules(ModeAbilityEstimator, dist, optimizer, InformationItemCriterion, FixedLength(2))
        @test mode_rules.ability_estimator(cat.tracked_responses[]) ≈ -0.5 atol=1e-4
    end
    dist = PosteriorAbilityEstimator(LogSpace())
    point_tracked = CatRules(MeanAbilityEstimator, dist, grid, PointAbilityTracker,
        AbilityVariance, FixedLength(2))
    @test point_tracked.next_item.criterion.criterion.integrator === point_tracked.ability_estimator.integrator
    override = MeanAbilityEstimator(dist, FunctionIntegrator(grid))
    description = sprint(show, MIME("text/plain"), override)
    @test occursin("log space", description)
    @test occursin("linear space", description)
    backend = QuadGKIntegrator(; lo=-6.0, hi=6.0)
    optimizer = NativeOneDimOptimOptimizer(; lo=-6.0, hi=6.0)
    continuous = MeanAbilityEstimator(dist, backend, optimizer)
    other = PosteriorAbilityEstimator(Normal(1.0, 1.0), LogSpace())
    inherited = AbilityVariance(other, continuous)
    @test inherited.integrator isa LogFunctionIntegrator
    @test inherited.integrator.optimizer === optimizer
    @test inherited.dist_est === other
    different_optimizer = NativeOneDimOptimOptimizer(; lo=-5.0, hi=5.0)
    @test AbilityVariance(continuous, different_optimizer).integrator.optimizer === different_optimizer
    @test_throws ErrorException PosteriorAbilityEstimator(LogSpace(), LinSpace())

    # The stateful accessor must not pass through an ordinary density.
    rules = CatRules(MeanAbilityEstimator, dist, grid, GriddedAbilityTracker, AbilityVariance, FixedLength(2))
    @test AbilityVariance(rules.ability_estimator, NullAbilityTracker()).integrator.tracker === nothing
    cat = Stateful.StatefulCatRules(rules, bank)
    responses = cat.tracked_responses[].responses
    append!(responses.indices, fill(1, 2000))
    append!(responses.values, vcat(fill(false, 1200), fill(true, 800)))
    track!(cat.tracked_responses[])
    @test Stateful.likelihood(cat, 0.0) == 0.0
    @test isfinite(Stateful.logdensity(cat, 0.0))
    @test isfinite(first(Stateful.get_ability(cat)))
    @test Stateful.next_item(cat) in 2:3
    Stateful.reset!(cat)
    @test Stateful.logdensity(cat, 0.0) == logpdf(dist.prior, 0.0)

    # Deduplication is observable as a single refresh, not just matching values.
    tracker = CountingTracker(0)
    collected = Rules.collect_trackers(tracker, (tracker, tracker))
    tracked = TrackedResponses(BareResponses(ResponseType(bank)), bank, collected)
    add_response!(tracked, Response(ResponseType(bank), 1, true))
    @test tracker.calls == 1
end

end
