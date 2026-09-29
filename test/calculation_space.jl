module CalculationSpaceTests

using Test
using Distributions: Normal, pdf, logpdf
using FittedItemBanks
using ComputerAdaptiveTesting.Aggregators
using ComputerAdaptiveTesting.Responses
using ComputerAdaptiveTesting: CatRules, Aggregators, Rules
using ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting.NextItemRules: ResponseExpectation, DistributionResponseExpectation
using ComputerAdaptiveTesting.TerminationConditions: FixedLength, StateCriterionThresholdTermination
using PsychometricsBazaarBase.Integrators: FixedGridIntegrator, QuadGKIntegrator,
    MidpointIntegrator
using PsychometricsBazaarBase.Optimizers: NativeOneDimOptimOptimizer

@testset "Calculation space and direct composition" begin
    prior = Normal(-0.5, 1.0)
    grid = FixedGridIntegrator(range(-6, 6; length=121))
    bank = ItemBank2PL([0.0], [1.0])
    history = TrackedResponses(BareResponses(ResponseType(bank)), bank)
    @test calculation_space(PosteriorAbilityEstimator(prior)) == LinSpace()
    @test calculation_space(LikelihoodAbilityEstimator()) == LinSpace()
    for bits in ((prior, LogSpace()), (LogSpace(), prior))
        dist = PosteriorAbilityEstimator(bits...)
        @test dist.prior === prior
        @test calculation_space(dist) == LogSpace()
        est = MeanAbilityEstimator(dist, grid)
        @test est.integrator isa LogGridIntegrator
        @test est(history) ≈ -0.5 atol=1e-5
        @test logpdf(dist, history, 0.0) ≈ log(pdf(dist, history, 0.0))
        @test MeanAbilityEstimator(grid, dist)(history) == est(history)
    end
    @test calculation_space(PosteriorAbilityEstimator(LogSpace())) == LogSpace()
    @test length(PosteriorAbilityEstimator(LogSpace(); ncomp=2).prior) == 2
    safe = SafeLikelihoodAbilityEstimator(LogSpace(); ncomp=2)
    @test calculation_space(safe) == LogSpace()
    @test calculation_space(safe.est) == calculation_space(safe.fallback)
    @test length(safe.fallback.prior) == 2
    @test MeanAbilityEstimator(LikelihoodAbilityEstimator(LogSpace()), grid).integrator isa LogGridIntegrator
    @test MeanAbilityEstimator(PosteriorAbilityEstimator(LinSpace()), grid).integrator isa FunctionIntegrator
    explicit = FunctionIntegrator(grid)
    @test MeanAbilityEstimator(PosteriorAbilityEstimator(LogSpace()), explicit).integrator === explicit
    @test MeanAbilityEstimator(PosteriorAbilityEstimator(), LogGridIntegrator(grid)).integrator isa LogGridIntegrator
    @test_throws ErrorException PosteriorAbilityEstimator(prior, LogSpace(), LinSpace())
    @test_throws ErrorException LikelihoodAbilityEstimator(LogSpace(), LinSpace())
    backend = QuadGKIntegrator(; lo=-6.0, hi=6.0)
    optimizer = NativeOneDimOptimOptimizer(; lo=-6.0, hi=6.0)
    dist = PosteriorAbilityEstimator(prior, LogSpace())
    continuous = MeanAbilityEstimator(dist, backend, optimizer)
    @test continuous.integrator isa LogFunctionIntegrator
    @test continuous(history) ≈ -0.5 atol=1e-5
    @test_throws ArgumentError MeanAbilityEstimator(dist, backend)
    @test_throws ArgumentError MeanAbilityEstimator(dist, MidpointIntegrator(collect(-6.0:0.1:6.0)))
end

@testset "Configuration propagation" begin
    grid = FixedGridIntegrator(range(-6, 6; length=121))
    dist = PosteriorAbilityEstimator(Normal(-0.5, 1.0), LogSpace())
    ability = MeanAbilityEstimator(dist, grid)
    bank = ItemBank2PL([0.0, 0.5, 1.0], [1.0, 1.0, 1.0])
    history = TrackedResponses(BareResponses(ResponseType(bank)), bank)
    for bits in ((MeanAbilityEstimator, dist, grid), (grid, dist, MeanAbilityEstimator))
        rules = CatRules(bits..., InformationItemCriterion, FixedLength(2))
        @test rules.ability_estimator isa MeanAbilityEstimator
        @test rules.ability_estimator.integrator isa LogGridIntegrator
        @test rules.ability_estimator(history) == ability(history)
        @test rules.next_item.criterion.ability_estimator === rules.ability_estimator
        @test best_item(rules.next_item, history) in 1:3
        variance_rules = CatRules(bits..., AbilityVariance, FixedLength(2))
        criterion = variance_rules.next_item.criterion.criterion
        @test criterion.dist_est === variance_rules.ability_estimator.dist_est
        @test criterion.integrator === variance_rules.ability_estimator.integrator
        @test isfinite(compute_criterion(variance_rules.next_item.criterion, history, 1))
    end
    @test AbilityVariance(ability).integrator === ability.integrator
    predictions = ResponseExpectation(dist, ability)
    @test predictions isa DistributionResponseExpectation
    @test predictions.integrator === ability.integrator
    @test sum(response_expectation(predictions, history, 1)) ≈ 1
    @test AbilityCovarianceStateMultiCriterion(ability).integrator === ability.integrator
    weighted = LikelihoodWeightedItemCriterion(ability, ObservedInformationPointwiseItemCriterion())
    @test weighted.integrator === ability.integrator
    @test isfinite(compute_criterion(weighted, history, 1))
    other = PosteriorAbilityEstimator(Normal(1.0, 1.0), LinSpace())
    local_criterion = AbilityVariance(other, ability)
    @test local_criterion.dist_est === other
    @test local_criterion.integrator isa FunctionIntegrator
    @test get_integrator(local_criterion.integrator) === grid
    explicit = FunctionIntegrator(grid)
    @test AbilityVariance(dist, explicit, ability).integrator === explicit
    local_rule = InformationItemCriterion(MeanAbilityEstimator(other, grid))
    @test CatRules(ability, local_rule, FixedLength(2)).next_item.criterion === local_rule
end

function tracker_count(tracker::Aggregators.ConsAbilityTracker)
    tracker_count(tracker.head) + tracker_count(tracker.tail)
end
tracker_count(::NullAbilityTracker) = 0
tracker_count(::AbilityTracker) = 1

@testset "Shared grid tracker construction" begin
    grid = FixedGridIntegrator(range(-6, 6; length=121))
    dist = PosteriorAbilityEstimator(LogSpace())
    @test AbilityTracker(LogGridAbilityTracker, dist, grid) isa LogGridAbilityTracker
    @test AbilityTracker(GriddedAbilityTracker, dist, grid) isa LogGridAbilityTracker
    @test AbilityTracker(dist, grid; integrator=grid) isa LogGridAbilityTracker
    for tracker_type in (LogGridAbilityTracker, GriddedAbilityTracker)
        rules = CatRules(MeanAbilityEstimator, dist, grid, tracker_type, AbilityVariance, FixedLength(2))
        integral = rules.ability_estimator.integrator
        @test integral.tracker isa LogGridAbilityTracker
        @test tracker_count(rules.ability_tracker) == 1
        @test rules.next_item.criterion.criterion.integrator === integral
        prepared = preallocate(rules)
        @test prepared.ability_estimator.integrator.tracker === integral.tracker
        @test tracker_count(prepared.ability_tracker) == 1
        bank = ItemBank2PL([0.0, 0.5, 1.0], [1.0, 1.0, 1.0])
        history = BareResponses(ResponseType(bank), fill(1, 2000),
            vcat(fill(false, 1200), fill(true, 800)))
        tracked = TrackedResponses(history, bank, prepared.ability_tracker)
        track!(tracked)
        @test isfinite(prepared.ability_estimator(tracked))
        cache = integral.tracker.cache
        @test all(isfinite, compute_criteria(prepared.next_item, tracked))
        @test integral.tracker.cache === cache
        pop_response!(tracked)
        @test length(integral.tracker.cache.responses) == 1999
        empty!(tracked)
        @test length(integral.tracker.cache.responses) == 0
        stopping = StateCriterionThresholdTermination(0.1, AbilityVariance(rules.ability_estimator))
        @test tracker_count(Rules.collect_trackers(rules, stopping)) == 1
    end
    disabled = MeanAbilityEstimator(dist, grid, NullAbilityTracker())
    @test disabled.integrator.tracker === nothing
    tracked = MeanAbilityEstimator(dist, grid, LogGridAbilityTracker)
    @test AbilityIntegrator(tracked; prefer_tracked=true) === tracked.integrator
    other = PosteriorAbilityEstimator(Normal(1.0, 1.0), LogSpace())
    @test AbilityIntegrator(other, grid, tracked.integrator.tracker).tracker === nothing
end

end
