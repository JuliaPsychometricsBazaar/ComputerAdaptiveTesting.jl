module PreparedGridMEPVTests

using Test
using Distributions: Normal, pdf, logpdf
import Distributions
using ComputerAdaptiveTesting: Aggregators, NextItemRules
using ComputerAdaptiveTesting.Aggregators
using ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting.Responses
using FittedItemBanks
using PsychometricsBazaarBase: Integrators

function setup(; space = LinSpace(), backend = Integrators.FixedGridIntegrator,
        n = 24, history_length = 6)
    bank = GuessAndSlipItemBank(fill(0.12, n), fill(0.08, n),
        ItemBank2PL(collect(range(-2, 2; length = n)), fill(1.4, n)))
    grid = backend(collect(range(-4, 4; length = 33)))
    dist = PosteriorAbilityEstimator(space)
    tracker = AbilityTracker(GriddedAbilityTracker, dist, grid)
    integral = AbilityIntegrator(grid, tracker)
    point = MeanAbilityEstimator(dist, integral)
    history = TrackedResponses(BareResponses(ResponseType(bank),
        [mod1(i, n) for i in 1:history_length], [isodd(i) for i in 1:history_length]), bank, tracker)
    track!(history)
    criterion = ExpectationBasedItemCriterion(PointResponseExpectation(point), AbilityVariance(dist, integral))
    reference_integral = space == LinSpace() ? FunctionIntegrator(grid) : LogGridIntegrator(grid)
    reference = ExpectationBasedItemCriterion(
        PointResponseExpectation(MeanAbilityEstimator(dist, reference_integral)),
        AbilityVariance(dist, reference_integral))
    (; bank, grid, dist, tracker, integral, point, history, criterion, reference)
end

function generic_values(criterion, history)
    spec = Speculator(history, 1)
    [compute_criterion(criterion, spec, history, i) for i in eachindex(history.item_bank)]
end

struct CountedPosterior <: DistributionAbilityEstimator
    calls::Base.RefValue{Int}
end
function Distributions.pdf(est::CountedPosterior, history::TrackedResponses)
    density = pdf(PosteriorAbilityEstimator(), history)
    x -> begin
        est.calls[] += 1
        density(x)
    end
end

@testset "Prepared fixed-grid MEPV" begin
    @testset "$space / $backend" for space in (LinSpace(), LogSpace()),
            backend in (Integrators.FixedGridIntegrator, Integrators.IterativeFixedGridIntegrator)
        (; history, criterion, reference, tracker) = setup(; space, backend)
        prepared = init_thread(criterion, history)
        @test prepared isa NextItemRules.PreparedGridMEPV
        original = deepcopy(tracker.density)
        actual = compute_criteria(criterion, history)
        @test actual ≈ generic_values(reference, history) rtol=1e-12
        @test actual ≈ generic_values(criterion, history) rtol=1e-12
        @test best_item(ItemCriterionRule(ExhaustiveSearch(), criterion), history) ==
              best_item(ItemCriterionRule(ExhaustiveSearch(), reference), history)
        other = init_thread(criterion, history)
        if space == LinSpace()
            @test prepared.density !== tracker.density
            @test prepared.scratch !== other.scratch
            @test tracker.density == original
        else
            @test prepared.density.log_values !== tracker.density.log_values
            @test prepared.scratch.weights !== other.scratch.weights
            @test tracker.density.log_values == original.log_values
            @test tracker.density.weights == original.weights
        end
        # Contexts are fresh for each scan, including scans inside speculation.
        nested = Speculator(history, 1)
        replace_speculation!(nested, [8], [true])
        @test compute_criteria(criterion, nested.responses) ≈ generic_values(reference, nested.responses)
        for edit! in (r -> add_response!(r, Response(ResponseType(r.item_bank), 9, false)),
                pop_response!, empty!)
            edit!(history)
            @test compute_criteria(criterion, history) ≈ generic_values(reference, history)
        end
        @test compute_criteria(preallocate(criterion), history) ≈ generic_values(reference, history)
    end

    @testset "EAP is evaluated once per scan" begin
        (; history, criterion, grid) = setup()
        count = Ref(0)
        point = MeanAbilityEstimator(CountedPosterior(count), FunctionIntegrator(grid))
        counted = ExpectationBasedItemCriterion(PointResponseExpectation(point), criterion.criterion)
        state = init_thread(counted, history)
        calls = count[]
        @test calls > 0
        for i in eachindex(history.item_bank)
            compute_criterion(counted, state, history, i)
        end
        @test count[] == calls
        @test compute_criteria(counted, history) ≈ compute_criteria(criterion, history)
    end

    @testset "Generic fallbacks" begin
        (; history, grid, reference) = setup()
        @test init_thread(reference, history) isa Speculator
        guarded = SafeLikelihoodAbilityEstimator()
        integral = LogGridIntegrator(grid)
        criterion = ExpectationBasedItemCriterion(
            PointResponseExpectation(MeanAbilityEstimator(guarded, integral)),
            AbilityVariance(guarded, integral))
        @test init_thread(criterion, history) isa Speculator
        @test compute_criteria(criterion, history) ≈ generic_values(criterion, history)
        distributed = ExpectationBasedItemCriterion(
            DistributionResponseExpectation(reference.criterion.dist_est, integral), reference.criterion)
        @test init_thread(distributed, history) isa Speculator
    end

    @testset "Absolute explicit denominators" for space in (LinSpace(), LogSpace())
        (; integral, dist, history, grid) = setup(; space)
        reference = space == LinSpace() ? FunctionIntegrator(grid) : LogGridIntegrator(grid)
        mass = normdenom(integral, dist, history)
        for factor in (0.5, 1.0, 2.0)
            denom = mass * factor
            mean = Aggregators.mean_1d(reference, dist, history, denom)
            expected = variance_given_mean(reference, dist, history, mean, denom)
            @test variance(integral, dist, history, denom) ≈ expected rtol=1e-12
        end
    end

    @testset "Long native log history" begin
        (; history, criterion, reference) = setup(; space = LogSpace(), history_length = 1600)
        state = init_thread(criterion, history)
        @test state isa NextItemRules.PreparedGridMEPV
        @test all(isfinite, state.density.log_values)
        @test all(iszero, exp.(state.density.log_values))
        spec = Speculator(history, 1)
        for i in (7, 12)
            actual = compute_criterion(criterion, state, history, i)
            @test isfinite(actual)
            @test actual ≈ compute_criterion(reference, spec, history, i) rtol=1e-10
        end
    end
end

end
