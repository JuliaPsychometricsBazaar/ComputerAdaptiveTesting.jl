module LogFunctionTests

using Test
using Distributions: Normal, MvNormal, pdf, logpdf
import Distributions
using FittedItemBanks
using ComputerAdaptiveTesting.Aggregators
using ComputerAdaptiveTesting: Aggregators
using ComputerAdaptiveTesting.Responses
using ComputerAdaptiveTesting.NextItemRules: preallocate
using PsychometricsBazaarBase.Integrators
using PsychometricsBazaarBase.Integrators: IntPassthrough
using PsychometricsBazaarBase.Optimizers: NativeOneDimOptimOptimizer, MultiDimOptimOptimizer, NelderMead

struct TestLogDensity{F} <: DistributionAbilityEstimator
    f::F
end
Distributions.logpdf(est::TestLogDensity, ::TrackedResponses) = est.f

@testset "Continuous log-density integration" begin
    bank = ItemBank2PL([0.0], [1.0])
    empty_responses = TrackedResponses(BareResponses(ResponseType(bank)), bank)
    history = BareResponses(ResponseType(bank), [1, 1], [false, true])
    responses = TrackedResponses(history, bank)
    opt = NativeOneDimOptimOptimizer(; lo=-8.0, hi=8.0)
    adaptive = QuadGKIntegrator(; lo=-8.0, hi=8.0, rtol=1e-9)

    @testset "Ordinary-range agreement and absolute errors" begin
        for backend in (adaptive, FixedGKIntegrator(-8.0, 8.0, 61))
            integral = LogFunctionIntegrator(backend, opt)
            @test LogFunctionIntegrator(opt, backend) == integral
            @test LogFunctionIntegrator(integral) === integral
            @test get_integrator(integral) === backend
            for dist in (LikelihoodAbilityEstimator(), PosteriorAbilityEstimator(Normal(-0.7, 1.1)),
                    SafeLikelihoodAbilityEstimator())
                ordinary = FunctionIntegrator(backend)
                @test MeanAbilityEstimator(dist, integral)(responses) ≈
                    MeanAbilityEstimator(dist, ordinary)(responses) atol=1e-8
                @test variance(integral, dist, responses) ≈ variance(ordinary, dist, responses) rtol=1e-8
                mass = normdenom(integral, dist, responses)
                @test Float64(mass) ≈ normdenom(ordinary, dist, responses) rtol=1e-8
                raw = integral(x -> x^2, 0, dist, responses)
                @test Float64(intval(raw)) ≈ intval(ordinary(x -> x^2, 0, dist, responses)) rtol=1e-8
                @test Float64(interr(raw)) >= 0
                μ = expectation(x -> x^2, 0, integral, dist, responses)
                @test expectation(x -> x^2, 0, integral, dist, responses, 2mass) ≈ μ / 2
                result = expectation(IntPassthrough(), x -> x^2, 0, integral, dist, responses)
                @test intval(result) ≈ μ
                @test isfinite(interr(result)) && interr(result) >= 0
                predictions = response_expectation(dist, integral, responses, 1)
                @test sum(predictions) ≈ 1 atol=1e-8
            end
        end
    end

    @testset "Underflow and scale-invariant error estimates" begin
        integral = LogFunctionIntegrator(adaptive, opt)
        # The unnormalized Gaussian has a known mean, variance and mass.
        shape(x) = -(x + 0.7)^2 / 2
        for offset in (-1000.0, 1000.0)
            dist = TestLogDensity(x -> offset + shape(x))
            @test MeanAbilityEstimator(dist, integral)(empty_responses) ≈ -0.7 atol=1e-9
            @test mean_1d(integral, dist, empty_responses) ≈ -0.7 atol=1e-9
            @test variance(integral, dist, empty_responses) ≈ 1 atol=1e-8
            mass = normdenom(IntPassthrough(), integral, dist, empty_responses)
            @test log(intval(mass)) ≈ offset + log(2π) / 2 atol=1e-9
            @test isfinite(log(interr(mass)))
            # Backend errors must be scaled by the same factor as values.
            reference = opt(logpdf(dist, empty_responses))
            c = logpdf(dist, empty_responses, reference)
            scaled = adaptive(x -> exp(offset + shape(x) - c), 0)
            @test log(interr(mass)) ≈ c + log(interr(scaled)) atol=1e-9
            moment = integral(identity, 0, dist, empty_responses)
            @test intval(moment) < 0
            @test Float64(intval(moment) / intval(mass)) ≈ -0.7 atol=1e-9
            measured = expectation(IntMeasurement(), identity, 0, integral, dist, empty_responses)
            @test isfinite(measured)
        end

        # A huge common offset must not swallow log(normalization) before division.
        for offset in (-1e20, 1e20)
            dist = TestLogDensity(_ -> offset)
            i = LogFunctionIntegrator(QuadGKIntegrator(; lo=-2.0, hi=4.0),
                NativeOneDimOptimOptimizer(; lo=-2.0, hi=4.0))
            @test MeanAbilityEstimator(dist, i)(empty_responses) ≈ 1
            @test mean_1d(i, dist, empty_responses) ≈ 1
            @test variance(i, dist, empty_responses) ≈ 3
        end

        infinite = LogFunctionIntegrator(QuadGKIntegrator(; lo=-Inf, hi=Inf, rtol=1e-9), opt)
        @test MeanAbilityEstimator(TestLogDensity(x -> -1000 + shape(x)), infinite)(empty_responses) ≈ -0.7 atol=1e-9

        # Independent analytic reference: a uniform prior on the logistic
        # response probability gives a Beta posterior and known E[p].
        nfalse, ntrue = 1200, 800
        long_history = BareResponses(ResponseType(bank), fill(1, nfalse + ntrue),
            vcat(fill(false, nfalse), fill(true, ntrue)))
        long_responses = TrackedResponses(long_history, bank)
        likelihood = AbilityLogLikelihood(long_responses)
        dist = TestLogDensity(x -> likelihood(x) - log1p(exp(x)) - log1p(exp(-x)))
        @test pdf(LikelihoodAbilityEstimator(), long_responses, -0.4) == 0
        expected = (ntrue + 1) / (nfalse + ntrue + 2)
        @test response_expectation(dist, integral, long_responses, 1) ≈ [1 - expected, expected] atol=1e-9
        @test isfinite(variance(integral, dist, long_responses))
        @test isfinite(log(normdenom(integral, dist, long_responses)))
        @test Float64(normdenom(integral, dist, long_responses)) == 0
        @test MeanAbilityEstimator(dist, preallocate(integral))(long_responses) ≈
            MeanAbilityEstimator(dist, integral)(long_responses)
    end

    @testset "Vector and matrix moments" begin
        mirt = ItemBankMirt2PL([0.0], reshape([1.0, 1.0], 2, 1))
        r = TrackedResponses(BareResponses(ResponseType(mirt)), mirt)
        prior = MvNormal([-0.6, 0.3], [1.0 -0.3; -0.3 0.7])
        dist = TestLogDensity(x -> -1000 + logpdf(prior, x))
        optimizer = MultiDimOptimOptimizer([-8.0, -8.0], [8.0, 8.0], NelderMead())
        backend = HCubatureIntegrator([-8.0, -8.0], [8.0, 8.0]; rtol=1e-7)
        integral = LogFunctionIntegrator(backend, optimizer)
        @test MeanAbilityEstimator(dist, integral)(r) ≈ [-0.6, 0.3] atol=1e-6
        @test Aggregators.covariance_matrix(integral, dist, r) ≈ [1.0 -0.3; -0.3 0.7] atol=1e-6
        matrix = expectation(IntPassthrough(), x -> x * x', 2, integral, dist, r)
        @test size(intval(matrix)) == size(interr(matrix)) == (2, 2)
        @test all(isfinite, interr(matrix))
        mass = normdenom(integral, dist, r)
        raw = integral(x -> x * x', 2, dist, r)
        @test Float64.(intval(raw) ./ mass) ≈ intval(matrix) atol=1e-6
        # The existing fixed multidimensional backend supplies no error estimate.
        fixed = LogFunctionIntegrator(MultiDimFixedGKIntegrator([-8.0, -8.0], [8.0, 8.0], 31), optimizer)
        @test expectation(identity, 2, fixed, dist, r) ≈ [-0.6, 0.3] atol=1e-6
        @test interr(fixed(_ -> 1.0, 0, dist, r)) === nothing
        cubature = LogFunctionIntegrator(CubatureIntegrator([-8.0, -8.0], [8.0, 8.0]; reltol=1e-7), optimizer)
        @test expectation(x -> x[1], 0, cubature, dist, r) ≈ -0.6 atol=1e-6
    end

    @testset "Invalid density and zero-support handling" begin
        integral = LogFunctionIntegrator(adaptive, opt)
        for value in (-Inf, Inf, NaN)
            @test_throws DomainError normdenom(integral, TestLogDensity(_ -> value), empty_responses)
        end
        # Finite at the reference point but zero almost everywhere.
        @test_throws DomainError Aggregators.scaled_mass(integral,
            (; density=x -> x == 0.1 ? 0.0 : -Inf, reference=0.1, scale=0.0))
        @test_throws DomainError Aggregators.scaled_density_value(_ -> NaN, 0.0, 1.0)
        @test_throws DomainError Aggregators.scaled_density_value(_ -> 1000.0, 0.0, 1.0)
        @test_throws DomainError Aggregators.normalized_integral(
            ErrorIntegrationResult(1.0, 0.1), ErrorIntegrationResult(1.0, 2.0), 1.0)
        @test_throws ArgumentError LogFunctionIntegrator(FixedGridIntegrator([-1.0, 1.0]), opt)
        # A coefficient undefined outside positive support is never called there.
        dist = TestLogDensity(x -> x > 0 ? -1000 - (x - 1)^2 : -Inf)
        positive_opt = NativeOneDimOptimOptimizer(; lo=0.1, hi=4.0)
        integral = LogFunctionIntegrator(adaptive, positive_opt)
        @test isfinite(expectation(log, 0, integral, dist, empty_responses))
    end
end

end
