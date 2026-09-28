module LogObjectiveOptimizationTests

using Test
using Distributions: Distributions, Normal, MvNormal, pdf, logpdf
using FittedItemBanks
using ComputerAdaptiveTesting.Responses
using ComputerAdaptiveTesting.Aggregators
using ComputerAdaptiveTesting.DerivedMeasures: LaplaceApproxEstimator
using PsychometricsBazaarBase: IntegralCoeffs
using PsychometricsBazaarBase.Optimizers: NativeOneDimOptimOptimizer,
    MultiDimOptimOptimizer, NelderMead

# A mode/curvature calculation must work without evaluating a linear density.
struct LogOnlyDensity <: DistributionAbilityEstimator end
Distributions.logpdf(::LogOnlyDensity, ::TrackedResponses) = x -> -1000 - (x - 0.7)^2 / 2

# General weighted objectives must continue to work without a log-density API.
struct PDFOnlyDensity <: DistributionAbilityEstimator end
Distributions.pdf(::PDFOnlyDensity, ::TrackedResponses) = x -> pdf(Normal(), x)

@testset "Log-objective optimization" begin
    optimizer = AbilityOptimizer(NativeOneDimOptimOptimizer(
        lo = -4.0, hi = 4.0, rel_tol = 1e-10))
    bank = ItemBank2PL([0.0], [1.0])
    empty_history = TrackedResponses(BareResponses(ResponseType(bank)), bank)

    @testset "MLE, MAP and curvature" begin
        # Identical logistic items give an analytic MLE and observed information.
        # The larger history has an underflowed likelihood even at its maximum.
        for n in (40, 2400)
            values = vcat(fill(true, 3n ÷ 4), fill(false, n ÷ 4))
            history = TrackedResponses(
                BareResponses(ResponseType(bank), fill(1, n), values), bank)
            mode = log(3.0)
            prior = Normal(mode, 2.0)
            for (density, precision) in (
                (LikelihoodAbilityEstimator(), n * 0.75 * 0.25),
                (PosteriorAbilityEstimator(prior), n * 0.75 * 0.25 + 0.25),
                (SafeLikelihoodAbilityEstimator(prior), n * 0.75 * 0.25),
            )
                estimator = ModeAbilityEstimator(density, optimizer)
                @test estimator(history) ≈ mode atol=1e-5
                location, curvature = LaplaceApproxEstimator(estimator)(history)
                @test location ≈ mode atol=1e-5
                @test curvature ≈ precision rtol=1e-5
                if n == 2400
                    @test pdf(density, history, mode) == 0.0
                else
                    linear_mode = optimizer(IntegralCoeffs.one, pdf(density, history))
                    @test estimator(history) ≈ linear_mode atol=1e-5
                end
            end
        end
    end

    @testset "Prior fallback and custom log densities" begin
        prior = Normal(-0.6, 2.0)
        for density in (PosteriorAbilityEstimator(prior), SafeLikelihoodAbilityEstimator(prior))
            location, curvature = LaplaceApproxEstimator(
                ModeAbilityEstimator(density, optimizer))(empty_history)
            @test location ≈ -0.6 atol=1e-6
            @test curvature ≈ 0.25
        end
        density = LogOnlyDensity()
        estimator = ModeAbilityEstimator(density, optimizer)
        location, curvature = LaplaceApproxEstimator(estimator)(empty_history)
        @test location ≈ 0.7 atol=1e-5
        @test curvature ≈ 1.0
        # Backend keyword arguments must still reach the optimizer.
        @test optimizer(IntegralCoeffs.one, density, empty_history;
            lo = -2.0, hi = 0.0) ≈ 0.0 atol=1e-6
    end

    @testset "Signed and general objectives retain product semantics" begin
        density = PDFOnlyDensity()
        # x * Normal(0, 1)'s density has its maximum at x = 1.
        @test optimizer(identity, density, empty_history) ≈ 1.0 atol=1e-5
        # A negative density is largest at the bounds, not at the density mode.
        @test abs(optimizer(_ -> -1.0, density, empty_history)) ≈ 4.0 atol=1e-5
        @test optimizer(identity, pdf(density, empty_history)) ≈ 1.0 atol=1e-5
        # Even a unit coefficient in the general two-function API is not a
        # promise that the supplied function is a positive density.
        @test optimizer(IntegralCoeffs.one, x -> -(x + 0.3)^2 - 1) ≈ -0.3 atol=1e-5
        @test_throws MethodError ModeAbilityEstimator(density, optimizer)(empty_history)
    end

    @testset "Multidimensional MAP with underflowed density" begin
        mirt = ItemBankMirt2PL([0.0, 0.0], [1.0 0.0; 0.0 1.0])
        indices = vcat(fill(1, 1200), fill(2, 1200))
        values = vcat(fill(true, 900), fill(false, 300), fill(true, 300), fill(false, 900))
        history = TrackedResponses(BareResponses(ResponseType(mirt), indices, values), mirt)
        mode = [log(3.0), -log(3.0)]
        density = PosteriorAbilityEstimator(MvNormal(mode, ones(2)))
        estimator = ModeAbilityEstimator(density,
            AbilityOptimizer(MultiDimOptimOptimizer(fill(-4.0, 2), fill(4.0, 2), NelderMead())))
        @test pdf(density, history, mode) == 0.0
        @test estimator(history) ≈ mode atol=1e-3
    end
end

end
