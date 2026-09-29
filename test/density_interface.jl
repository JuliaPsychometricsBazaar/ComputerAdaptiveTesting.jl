module DensityInterfaceTests

using Test
using Distributions: Normal, MvNormal, Uniform, pdf, logpdf
using FittedItemBanks
using ComputerAdaptiveTesting.Responses
using ComputerAdaptiveTesting.Aggregators
using ComputerAdaptiveTesting.Aggregators: GuardedAbilityEstimator, ForwardDiff

# Deliberately lacks a logpdf method, to detect evaluation of an unselected branch.
struct UnsupportedDensity <: DistributionAbilityEstimator end

@testset "Log density interface" begin
    bank = ItemBank2PL([0.0, 0.0], [1.0, 1.0])
    responses = BareResponses(ResponseType(bank), [1, 2], [false, true])
    tracked = TrackedResponses(responses, bank)
    likelihood = AbilityLikelihood(tracked)
    log_likelihood = AbilityLogLikelihood(tracked)

    @testset "Pointwise likelihoods" begin
        for θ in (-2.0, 0.0, 3.0)
            expected = log(resp(ItemResponse(bank, 1), false, θ)) +
                       log(resp(ItemResponse(bank, 2), true, θ))
            @test log_likelihood(θ) ≈ expected
            @test exp(log_likelihood(θ)) ≈ likelihood(θ)
            @test AbilityLogLikelihood(bank, responses)(θ) ≈ expected
            @test AbilityLogLikelihood(likelihood)(θ) ≈ expected
            @test logpdf(LikelihoodAbilityEstimator(), tracked)(θ) ≈ expected
            @test logpdf(LikelihoodAbilityEstimator(), tracked, θ) ≈ expected
            @test AbilityLogLikelihood(LogItemBank(bank), responses)(θ) ≈ expected
        end
        @test ForwardDiff.derivative(log_likelihood, 0.0) ≈ 0.0 atol=1e-14
        @test ForwardDiff.derivative(x -> ForwardDiff.derivative(log_likelihood, x), 0.0) ≈ -0.5

        # A logistic reference evaluated independently at higher precision.
        for (value, θ) in ((false, 1000.0), (true, -1000.0))
            history = BareResponses(ResponseType(bank), [1], [value])
            expected = Float64(-log1p(exp(big(1000))))
            @test AbilityLogLikelihood(bank, history)(θ) ≈ expected
            @test AbilityLikelihood(bank, history)(θ) == 0.0
        end
        long_history = BareResponses(ResponseType(bank), fill(1, 2000), fill(true, 2000))
        @test AbilityLikelihood(bank, long_history)(0.0) == 0.0
        @test AbilityLogLikelihood(bank, long_history)(0.0) ≈ -2000log(2)

        history = BareResponses(ResponseType(bank))
        live_density = AbilityLogLikelihood(bank, history)
        @test live_density(0.0) == 0.0
        add_response!(history, Response(ResponseType(bank), 1, false))
        @test live_density(0.0) ≈ -log(2)
        pop_response!(history)
        @test live_density(0.0) == 0.0

        certain_bank = FixedGuessItemBank(1.0, bank)
        impossible = BareResponses(ResponseType(certain_bank), [1], [false])
        @test AbilityLogLikelihood(certain_bank, impossible)(0.0) == -Inf
    end

    @testset "Posteriors and guards" begin
        prior = Normal(0.5, 1.3)
        posterior = PosteriorAbilityEstimator(prior)
        for θ in (-2.0, 0.0, 3.0)
            expected = log_likelihood(θ) + logpdf(prior, θ)
            @test logpdf(posterior, tracked)(θ) ≈ expected
            @test logpdf(posterior, tracked, θ) ≈ expected
            @test exp(expected) ≈ pdf(posterior, tracked, θ)
        end
        empty_tracked = TrackedResponses(BareResponses(ResponseType(bank)), bank)
        @test logpdf(posterior, empty_tracked, 100.0) == logpdf(prior, 100.0)
        @test isfinite(logpdf(posterior, empty_tracked, 100.0))
        @test pdf(posterior, empty_tracked, 100.0) == 0.0
        @test logpdf(PosteriorAbilityEstimator(Uniform(-1, 1)), tracked, 2.0) == -Inf

        one_response = TrackedResponses(BareResponses(ResponseType(bank), [1], [true]), bank)
        safe = SafeLikelihoodAbilityEstimator(prior)
        @test logpdf(safe, tracked, 0.0) ≈ log_likelihood(0.0)
        @test logpdf(safe, empty_tracked, 0.0) == logpdf(prior, 0.0)
        @test logpdf(safe, one_response, 0.0) ≈ -log(2) + logpdf(prior, 0.0)
        for history in (tracked, empty_tracked, one_response)
            @test exp(logpdf(safe, history)(0.0)) ≈ pdf(safe, history, 0.0)
        end
        primary = GuardedAbilityEstimator(LikelihoodAbilityEstimator(), UnsupportedDensity(), _ -> true)
        fallback = GuardedAbilityEstimator(UnsupportedDensity(), posterior, _ -> false)
        @test logpdf(primary, tracked, 0.0) ≈ -2log(2)
        @test logpdf(fallback, tracked, 0.0) ≈ logpdf(posterior, tracked, 0.0)
        @test_throws MethodError logpdf(UnsupportedDensity(), tracked, 0.0)
    end

    @testset "Vector abilities and categorical responses" begin
        mirt = ItemBankMirt2PL([0.0, 0.0], [1.0 0.0; 0.0 1.0])
        history = TrackedResponses(BareResponses(ResponseType(mirt), [1, 2], [false, true]), mirt)
        posterior = PosteriorAbilityEstimator(MvNormal(zeros(2), ones(2)))
        for θ in ([0.0, 0.0], [1.0, -2.0], [1000.0, -1000.0])
            expected = Float64(-log1p(exp(big(θ[1]))) - log1p(exp(-big(θ[2]))))
            @test AbilityLogLikelihood(history)(θ) ≈ expected
            @test logpdf(posterior, history, θ) ≈ expected + logpdf(posterior.prior, θ)
        end
        nominal = NominalItemBank([[-1.0, 0.0, 1.0]], reshape([1.0, 0.5], 2, 1), [[-0.5, 0.0, 0.5]])
        for category in 1:3
            history = BareResponses(ResponseType(nominal), [1], [category])
            θ = [0.2, -0.4]
            @test exp(AbilityLogLikelihood(nominal, history)(θ)) ≈ resp(ItemResponse(nominal, 1), category, θ)
        end
    end

    @testset "Grid log likelihoods" begin
        xs = [-1.0, 0.0, 1.0]
        points = DichotomousPointsItemBank(xs, [0.2 0.9; 0.4 0.7; 0.8 0.3])
        for grid_bank in (points, DichotomousPointsWithLogsItemBank(points))
            history = BareResponses(ResponseType(grid_bank), [1, 2], [true, false])
            likelihood = AbilityLikelihood(grid_bank, history)
            log_likelihood = AbilityLogLikelihood(likelihood)
            expected = log.([0.2 * 0.1, 0.4 * 0.3, 0.8 * 0.7])
            @test function_xs(likelihood) === xs
            @test function_xs(log_likelihood) === xs
            @test function_log_ys(likelihood) ≈ expected
            @test function_ys(log_likelihood) ≈ expected
            @test function_ys(likelihood) ≈ exp.(expected)
            empty!(history)
            @test function_ys(log_likelihood) == zeros(3)
            @test function_ys(likelihood) == ones(3)
            for _ in 1:2000
                add_response!(history, Response(ResponseType(grid_bank), 1, true))
            end
            @test function_ys(log_likelihood) ≈ 2000 .* log.([0.2, 0.4, 0.8])
            @test all(isfinite, function_ys(log_likelihood))
            @test function_ys(likelihood)[1] == 0.0
        end
        edges = DichotomousPointsItemBank(xs, reshape([0.0, 1e-20, 1.0], :, 1))
        for grid_bank in (edges, DichotomousPointsWithLogsItemBank(edges))
            yes = AbilityLikelihood(grid_bank, BareResponses(ResponseType(grid_bank), [1], [true]))
            no = AbilityLikelihood(grid_bank, BareResponses(ResponseType(grid_bank), [1], [false]))
            @test function_log_ys(yes) ≈ [-Inf, log(1e-20), 0.0]
            @test function_log_ys(no) ≈ [0.0, -1e-20, -Inf]
            @test function_log_ys(no)[2] < 0.0
        end
    end
end

end
