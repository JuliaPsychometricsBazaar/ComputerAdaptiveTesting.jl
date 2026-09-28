module LogGridTests

using Test
using Distributions: Normal, MvNormal, Uniform, logpdf, pdf
import Distributions
using FittedItemBanks
using ComputerAdaptiveTesting: Aggregators, NextItemRules, CatRules
using ComputerAdaptiveTesting.Aggregators
using ComputerAdaptiveTesting.Responses
using ComputerAdaptiveTesting.NextItemRules: preallocate, DistributionResponseExpectation,
    ResponseExpectation, RandomNextItemRule
using ComputerAdaptiveTesting.TerminationConditions: FixedLength
using PsychometricsBazaarBase.Integrators: FixedGridIntegrator, IterativeFixedGridIntegrator,
    IntValue, intval
using PsychometricsBazaarBase: IntegralCoeffs

struct CountingDensity <: DistributionAbilityEstimator
    calls::Base.RefValue{Int}
end

struct ConstantLogDensity <: DistributionAbilityEstimator
    value::Float64
end
Distributions.logpdf(est::ConstantLogDensity, ::TrackedResponses) = _ -> est.value
function Distributions.logpdf(est::CountingDensity, responses::TrackedResponses)
    density = logpdf(PosteriorAbilityEstimator(Normal(-0.4, 1.2)), responses)
    x -> begin
        est.calls[] += 1
        density(x)
    end
end

# No CAT-specific dependencies are needed by these numerical helpers.
@testset "Normalized log-grid reductions" begin
    W = Aggregators.LogGridWeights
    reduce_grid = Aggregators.weighted_grid_mean
    @test_throws ArgumentError W(Float64[])
    @test_throws DomainError W([-Inf, -Inf])
    @test_throws DomainError W([0.0, NaN])
    @test_throws DomainError W([0.0, Inf])
    @test_throws DimensionMismatch reduce_grid(identity, [1.0], W([0.0, 0.0]))
    # logsumexp rounded back into a huge shift would lose the factor of three.
    for shift in (-1e20, 1e20)
        weights = W(fill(shift, 3))
        @test sum(weights.weights) ≈ 1
        @test reduce_grid(identity, [-2.0, 1.0, 4.0], weights) ≈ 1
        @test reduce_grid(x -> [x, x^2], [-2.0, 1.0, 4.0], weights) ≈ [1, 7]
    end
    weights = W([-Inf, 0.0])
    @test reduce_grid(log, [-1.0, 1.0], weights) == 0
    @test eltype(W(BigFloat[-1000, -1001]).weights) == BigFloat
end

@testset "Log-grid inference" begin
    bank = ItemBank2PL([0.0, 1.0], [1.0, 1.4])
    history = BareResponses(ResponseType(bank), [1, 2], [false, true])
    responses = TrackedResponses(history, bank)
    xs = collect(range(-5, 5; length=101))
    grid = FixedGridIntegrator(xs)
    posterior = PosteriorAbilityEstimator(Normal(-0.4, 1.2))

    @testset "Ordinary-range equivalence and raw mass" begin
        for dist in (LikelihoodAbilityEstimator(), posterior, SafeLikelihoodAbilityEstimator())
            p = pdf(dist, responses).(xs)
            mass = sum(p)
            μ = sum(xs .* p) / mass
            v = sum((xs .- μ).^2 .* p) / mass
            for backend in (grid, preallocate(grid), IterativeFixedGridIntegrator(xs))
                integral = LogGridIntegrator(backend)
                @test MeanAbilityEstimator(dist, integral)(responses) ≈ μ
                @test mean_1d(integral, dist, responses) ≈ μ
                @test variance(integral, dist, responses) ≈ v
                @test Float64(normdenom(integral, dist, responses)) ≈ mass
                @test Float64(intval(integral(identity, 0, dist, responses))) ≈ sum(xs .* p)
                @test expectation(identity, 0, integral, dist, responses, mass * 2) ≈ μ / 2
                expected = [sum(p .* [resp(ItemResponse(bank, 1), r, x) for x in xs]) / mass
                            for r in (false, true)]
                @test response_expectation(dist, integral, responses, 1) ≈ expected
                @test sum(response_expectation(dist, integral, responses, 1)) ≈ 1
            end
        end
    end

    @testset "Underflow compared to independent high precision" begin
        # Use an asymmetric history to exercise a negative mean, not just zero.
        nfalse, ntrue = 1200, 800
        long_history = BareResponses(ResponseType(bank), fill(1, nfalse + ntrue),
            vcat(fill(false, nfalse), fill(true, ntrue)))
        long_responses = TrackedResponses(long_history, bank)
        @test all(iszero, pdf(posterior, long_responses).(xs))
        weights = [exp(-big(nfalse) * log1p(exp(big(x))) -
                       big(ntrue) * log1p(exp(-big(x))) -
                       ((big(x) + big(0.4)) / big(1.2))^2 / 2) for x in xs]
        weights ./= sum(weights)
        μ = sum(big.(xs) .* weights)
        v = sum((big.(xs) .- μ).^2 .* weights)
        tracker = LogGridAbilityTracker(posterior, grid)
        integral = LogGridIntegrator(tracker)
        tracked = TrackedResponses(long_history, bank, tracker)
        track!(tracked)
        @test MeanAbilityEstimator(posterior, integral)(tracked) ≈ Float64(μ) atol=1e-11
        @test variance(integral, posterior, tracked) ≈ Float64(v) atol=1e-11
        @test isfinite(log(normdenom(integral, posterior, tracked)))
        @test Float64(normdenom(integral, posterior, tracked)) == 0
        @test sum(tracker.cache.density.weights) ≈ 1
        expected_false = sum(weights ./ (1 .+ exp.(big.(xs))))
        @test response_expectation(posterior, integral, tracked, 1)[1] ≈ Float64(expected_false)
    end

    @testset "Cache reuse, mismatches and lifecycle" begin
        dist = CountingDensity(Ref(0))
        tracker = LogGridAbilityTracker(grid, dist)
        integral = LogGridIntegrator(tracker)
        tracked = TrackedResponses(deepcopy(history), bank, tracker)
        # Lazy use before the first track! is safe.
        @test isfinite(MeanAbilityEstimator(dist, integral)(tracked))
        @test tracker.cache === nothing
        track!(tracked)
        calls = dist.calls[]
        cache = tracker.cache
        μ = MeanAbilityEstimator(dist, integral)(tracked)
        @test isfinite(variance(integral, dist, tracked))
        @test sum(response_expectation(dist, integral, tracked, 1)) ≈ 1
        @test dist.calls[] == calls
        @test tracker.cache === cache

        other = PosteriorAbilityEstimator(Normal(2, 0.4))
        @test MeanAbilityEstimator(other, integral)(tracked) ≈
              MeanAbilityEstimator(other, LogGridIntegrator(grid))(tracked)
        @test tracker.cache === cache

        speculator = Speculator(tracked, 1)
        replace_speculation!(speculator, [1], [true])
        speculative_mean = MeanAbilityEstimator(dist, integral)(speculator.responses)
        @test speculative_mean ≈ MeanAbilityEstimator(dist, LogGridIntegrator(grid))(speculator.responses)
        @test speculative_mean > μ
        @test tracker.cache === cache
        @test MeanAbilityEstimator(dist, integral)(tracked) == μ
        replace_speculation!(speculator, [1], [false])
        @test MeanAbilityEstimator(dist, integral)(speculator.responses) < μ

        add_response!(tracked, Response(ResponseType(bank), 1, true))
        @test tracker.cache !== cache
        @test MeanAbilityEstimator(dist, integral)(tracked) > μ
        pop_response!(tracked)
        @test MeanAbilityEstimator(dist, integral)(tracked) ≈ μ
        empty!(tracked)
        @test isempty(tracker.cache.responses.indices)
        @test MeanAbilityEstimator(dist, integral)(tracked) ≈
              MeanAbilityEstimator(dist, LogGridIntegrator(grid))(tracked)

        # Mutating a bare history cannot trick the snapshot check.
        add_response!(tracked.responses, Response(ResponseType(bank), 1, false))
        @test MeanAbilityEstimator(dist, integral)(tracked) ≈
              MeanAbilityEstimator(dist, LogGridIntegrator(grid))(tracked)
        @test isempty(tracker.cache.responses.indices)
        other_bank = ItemBank2PL([3.0, 4.0], [1.0, 1.4])
        other_responses = TrackedResponses(tracked.responses, other_bank)
        @test MeanAbilityEstimator(dist, integral)(other_responses) ≈
              MeanAbilityEstimator(dist, LogGridIntegrator(grid))(other_responses)
        @test_throws ArgumentError LogGridIntegrator(FixedGridIntegrator([0.0]), tracker)

        prepared = preallocate(integral)
        @test MeanAbilityEstimator(dist, prepared)(tracked) ≈ MeanAbilityEstimator(dist, integral)(tracked)
        @test ResponseExpectation(dist, integral) isa DistributionResponseExpectation
        @test Aggregators.response_expectation(ResponseExpectation(dist, integral), tracked, 1) ≈
              response_expectation(dist, integral, tracked, 1)
        rules = CatRules(MeanAbilityEstimator(dist, integral), RandomNextItemRule(), FixedLength(2))
        @test rules.ability_tracker isa Aggregators.ConsAbilityTracker
        prepared_rules = preallocate(rules)
        @test prepared_rules.ability_estimator.integrator.tracker === tracker
        tracker.cache = nothing
        rule_responses = TrackedResponses(deepcopy(history), bank, prepared_rules.ability_tracker)
        track!(rule_responses)
        @test tracker.cache.responses == history
    end

    @testset "Support and rare response categories" begin
        empty_responses = TrackedResponses(BareResponses(ResponseType(bank)), bank)
        for shift in (-1e20, 1e20)
            constant = ConstantLogDensity(shift)
            i = LogGridIntegrator(FixedGridIntegrator([-2.0, 1.0, 4.0]))
            @test MeanAbilityEstimator(constant, i)(empty_responses) ≈ 1
            @test mean_1d(i, constant, empty_responses) ≈ 1
            @test variance(i, constant, empty_responses) ≈ 6
        end
        integral = LogGridIntegrator(FixedGridIntegrator([40.0]))
        predictions = response_expectation(LikelihoodAbilityEstimator(), integral, empty_responses, 1)
        @test predictions[1] > 0
        @test predictions[1] ≈ Float64(inv(1 + exp(big(40))))
        @test_throws DomainError MeanAbilityEstimator(PosteriorAbilityEstimator(Uniform(-1, 1)), integral)(empty_responses)
        @test_throws ArgumentError MeanAbilityEstimator(posterior, LogGridIntegrator(FixedGridIntegrator(Float64[])))(empty_responses)
        certain = FixedGuessItemBank(1.0, bank)
        impossible = TrackedResponses(BareResponses(ResponseType(certain), [1], [false]), certain)
        @test_throws DomainError MeanAbilityEstimator(posterior, LogGridIntegrator(grid))(impossible)
        tracker = LogGridAbilityTracker(posterior, grid)
        r = TrackedResponses(BareResponses(ResponseType(certain)), certain,
            Aggregators.ConsAbilityTracker(tracker, NullAbilityTracker()))
        track!(r)
        @test_throws DomainError add_response!(r, Response(ResponseType(certain), 1, false))
        @test tracker.cache === nothing
        pop_response!(r)
        @test tracker.cache !== nothing
        add_response!(r, Response(ResponseType(certain), 1, true))
        empty!(r)
        @test isempty(tracker.cache.responses.indices)
    end

    @testset "Matrix moments and nominal predictions" begin
        mirt = ItemBankMirt2PL([0.0], reshape([1.0, 1.0], 2, 1))
        xs2 = [[x, y] for x in -2.0:1.0:2.0 for y in -2.0:1.0:2.0]
        dist = PosteriorAbilityEstimator(MvNormal(zeros(2), ones(2)))
        history2 = BareResponses(ResponseType(mirt), [1], [true])
        tracker = LogGridAbilityTracker(dist, FixedGridIntegrator(xs2))
        integral = LogGridIntegrator(tracker)
        tracked = TrackedResponses(history2, mirt, tracker)
        track!(tracked)
        p = pdf(dist, tracked).(xs2)
        p ./= sum(p)
        μ = sum(w * x for (w, x) in zip(p, xs2))
        cov = sum(w * (x - μ) * (x - μ)' for (w, x) in zip(p, xs2))
        @test MeanAbilityEstimator(dist, integral)(tracked) ≈ μ
        @test Aggregators.covariance_matrix(integral, dist, tracked) ≈ cov
        @test cov[1, 2] < 0
        raw = intval(integral(x -> x * x', 2, dist, tracked))
        @test Float64.(raw) ≈ sum(pdf(dist, tracked, x) * x * x' for x in xs2)

        nominal = NominalItemBank([[-1.0, 0.0, 1.0]], reshape([1.0, 0.5], 2, 1), [[-0.5, 0.0, 0.5]])
        r = TrackedResponses(BareResponses(ResponseType(nominal)), nominal)
        integral = LogGridIntegrator(FixedGridIntegrator(xs2))
        prediction = response_expectation(dist, integral, r, 1)
        p = pdf(dist, r).(xs2)
        expected = sum(w * resp_vec(ItemResponse(nominal, 1), x) for (w, x) in zip(p, xs2)) / sum(p)
        @test prediction ≈ expected
        @test sum(prediction) ≈ 1
    end

    @testset "Tabulated densities" begin
        points = DichotomousPointsItemBank([-1.0, 0.0, 1.0], reshape([0.2, 0.4, 0.8], :, 1))
        for b in (points, DichotomousPointsWithLogsItemBank(points))
            r = TrackedResponses(BareResponses(ResponseType(b), [1], [true]), b)
            integral = LogGridIntegrator(FixedGridIntegrator(points.xs))
            @test MeanAbilityEstimator(LikelihoodAbilityEstimator(), integral)(r) ≈ 0.6 / 1.4
            @test response_expectation(LikelihoodAbilityEstimator(), integral, r, 1) ≈
                  [0.2 * 0.8 + 0.4 * 0.6 + 0.8 * 0.2, 0.2^2 + 0.4^2 + 0.8^2] / 1.4
            p = [0.2, 0.4, 0.8] .* pdf.(Ref(posterior.prior), points.xs)
            @test MeanAbilityEstimator(posterior, integral)(r) ≈ sum(points.xs .* p) / sum(p)
            @test_throws ArgumentError MeanAbilityEstimator(posterior, LogGridIntegrator(grid))(r)
        end
    end
end

end
