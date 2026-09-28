module CalculationSpaceTests

using Test
using Distributions: Normal, pdf, logpdf
using FittedItemBanks
using ComputerAdaptiveTesting.Aggregators
using ComputerAdaptiveTesting.Responses
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

end
