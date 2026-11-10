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
        n = 24, history_length = 6,
        points = collect(range(-4, 4; length = 33)),
        bank = GuessAndSlipItemBank(fill(0.12, n), fill(0.08, n),
            ItemBank2PL(collect(range(-2, 2; length = n)), fill(1.4, n))))
    grid = backend(points)
    dist = PosteriorAbilityEstimator(space)
    tracker = AbilityTracker(GriddedAbilityTracker, dist, grid)
    integral = AbilityIntegrator(grid, tracker)
    point = MeanAbilityEstimator(dist, integral)
    bare = BareResponses(ResponseType(bank))
    for i in 1:history_length
        add_response!(bare, Response(ResponseType(bank), mod1(i, n), isodd(i)))
    end
    history = TrackedResponses(bare, bank, tracker)
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

struct CountedBank{B} <: AbstractItemBank
    inner::B
    scalar_calls::Base.RefValue{Int}
    vector_calls::Base.RefValue{Int}
end
Base.length(bank::CountedBank) = length(bank.inner)
FittedItemBanks.DomainType(bank::CountedBank) = DomainType(bank.inner)
FittedItemBanks.ResponseType(bank::CountedBank) = ResponseType(bank.inner)
FittedItemBanks.domdims(bank::CountedBank) = domdims(bank.inner)
function FittedItemBanks.resp(ir::ItemResponse{<:CountedBank}, category, theta)
    ir.item_bank.scalar_calls[] += 1
    resp(ItemResponse(ir.item_bank.inner, ir.index), category, theta)
end
function FittedItemBanks.resp_vec(ir::ItemResponse{<:CountedBank}, theta)
    ir.item_bank.vector_calls[] += 1
    resp_vec(ItemResponse(ir.item_bank.inner, ir.index), theta)
end
function FittedItemBanks.log_resp(ir::ItemResponse{<:CountedBank}, category, theta)
    ir.item_bank.scalar_calls[] += 1
    log_resp(ItemResponse(ir.item_bank.inner, ir.index), category, theta)
end
function FittedItemBanks.log_resp_vec(ir::ItemResponse{<:CountedBank}, theta)
    ir.item_bank.vector_calls[] += 1
    log_resp_vec(ItemResponse(ir.item_bank.inner, ir.index), theta)
end

@testset "Prepared fixed-grid MEPV" begin
    @testset "Range coordinates are materialized once per scan" begin
        for space in (LinSpace(), LogSpace()),
                backend in (Integrators.FixedGridIntegrator, Integrators.IterativeFixedGridIntegrator),
                points in (range(-4., 4.; length=33), LinRange(-4., 4., 33))
            config = setup(; space, backend, points)
            state = init_thread(config.criterion, config.history)
            @test state.grid isa Vector{Float64}
            @test state.grid == [points[i] for i in eachindex(points)]
            @test Integrators.get_grid(config.grid) isa AbstractRange
            actual = [compute_criterion(config.criterion, state, config.history, i)
                      for i in eachindex(config.bank)]
            @test actual ≈ generic_values(config.reference, config.history) rtol=1e-12
        end
        points = collect(range(-4., 4.; length=33))
        config = setup(; points)
        @test init_thread(config.criterion, config.history).grid === points
    end

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
            @test prepared.scratch[1] !== other.scratch[1]
            @test prepared.scratch[1] !== prepared.scratch[2]
            @test tracker.density == original
        else
            @test prepared.density.log_values !== tracker.density.log_values
            @test prepared.scratch[1].weights !== other.scratch[1].weights
            @test prepared.scratch[1].weights !== prepared.scratch[2].weights
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
        (; history, criterion, reference, integral, dist) = setup(;
            space = LogSpace(), history_length = 1600)
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
        # Absolute denominators remain usable even if their normalized ratios
        # overflow/underflow. Compare with the pre-existing expectation path.
        mass = normdenom(integral, dist, history)
        for denom in (1.0, mass * exp(Aggregators.ULogarithmic, -1000.0))
            expected = invoke(variance,
                Tuple{AbilityIntegrator, DistributionAbilityEstimator, TrackedResponses, Any},
                integral, dist, history, denom)
            @test isequal(variance(integral, dist, history, denom), expected)
        end
        @test iszero(variance(integral, dist, history, 1.0))
    end

    @testset "Shared native log responses" begin
        bank = CountedBank(ItemBank2PL([-2.0, 2.0, -40.0, 40.0, -1000.0, 1000.0], ones(6)),
            Ref(0), Ref(0))
        (; history, criterion, reference) = setup(; space = LogSpace(), bank,
            n = length(bank), history_length = 2)
        state = init_thread(criterion, history)
        # Ordinary pairs now retain representable tails. Native log outcomes
        # also remain finite beyond the range of ordinary probabilities.
        @test resp_vec(ItemResponse(bank, 3), 0.0)[1] > 0.0
        @test exp(log_resp_vec(ItemResponse(bank, 3), 0.0)[1]) > 0.0
        @test all(isfinite, log_resp_vec(ItemResponse(bank, 5), 0.0))
        bank.scalar_calls[] = bank.vector_calls[] = 0
        compute_criterion(criterion, state, history, 3)
        @test bank.scalar_calls[] == 0
        @test bank.vector_calls[] == length(state.grid) + 1

        original_logs = copy(state.density.log_values)
        for i in 3:6
            ir = ItemResponse(bank, i)
            densities = NextItemRules.candidate_grid_densities!(
                state.scratch, state.density, ir, state.grid)
            for (density, category) in zip(densities, responses(ir))
                @test density.log_values ≈ original_logs .+ log_resp.(Ref(ir), category, state.grid)
                @test all(isfinite, density.weights)
                @test sum(density.weights) ≈ 1.0
                @test isfinite(Integrators.weighted_grid_moments(state.grid, density).variance)
            end
            actual = compute_criterion(criterion, state, history, i)
            @test isfinite(actual)
            @test actual ≈ compute_criterion(reference, Speculator(history, 1), history, i) rtol=1e-12
        end
        @test state.density.log_values == original_logs
    end

    @testset "Shared linear responses and scalar fallback" begin
        bank = ItemBank2PL([-2., 2., -40., 40.], ones(4))
        (; history, criterion, reference) = setup(; bank, n=4, history_length=2)
        state = init_thread(criterion, history)
        @test state.scratch isa NTuple{2, AbstractVector}
        before = copy(state.density)
        @test compute_criteria(criterion, history) ≈ generic_values(reference, history) rtol=1e-12
        @test state.density == before
        # The tiny opposite-outcome density is retained, rather than rounded to zero.
        compute_criterion(criterion, state, history, 3)
        @test all(>(0), state.scratch[1])

        counted = CountedBank(bank, Ref(0), Ref(0))
        custom = setup(; bank=counted, n=4, history_length=2)
        fallback = init_thread(custom.criterion, custom.history)
        @test fallback.scratch isa AbstractVector
        counted.scalar_calls[] = counted.vector_calls[] = 0
        compute_criterion(custom.criterion, fallback, custom.history, 3)
        @test counted.scalar_calls[] == 2length(fallback.grid)
        @test counted.vector_calls[] == 1
        @test compute_criteria(custom.criterion, custom.history) ≈
              generic_values(custom.reference, custom.history) rtol=1e-12

        certain = GuessAndSlipItemBank(ones(1), zeros(1), ItemBank2PL([0.], [1.]))
        zero_case = setup(; bank=certain, n=1, history_length=0)
        ordinary = zero_case.criterion
        zero_state = init_thread(ordinary, zero_case.history)
        @test_throws DomainError compute_criterion(ordinary, zero_state, zero_case.history, 1)
        variance = ordinary.criterion
        skipping = ExpectationBasedItemCriterion(ordinary.response_expectation,
            AbilityVariance(variance.dist_est, variance.integrator, true))
        skip_state = init_thread(skipping, zero_case.history)
        @test isequal(compute_criterion(skipping, skip_state, zero_case.history, 1),
            NextItemRules.candidate_expected_variance(skipping.criterion, skip_state,
                ItemResponse(certain, 1), first(skip_state.scratch)))
    end

    @testset "Polytomous per-outcome fallback" begin
        bank = FittedItemBanks.OneDimensionItemBankAdapter(
            NominalItemBank([[-1.0, 0.0, 1.0]], [1.0], [[-0.5, 0.0, 0.5]]))
        (; history, criterion, reference) = setup(; space = LogSpace(), bank,
            n = 1, history_length = 0)
        @test init_thread(criterion, history).scratch isa Integrators.LogGridWeights
        @test compute_criteria(criterion, history) ≈ generic_values(reference, history) rtol=1e-12
    end
end

end
