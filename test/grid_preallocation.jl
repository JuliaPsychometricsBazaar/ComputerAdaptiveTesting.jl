module GridPreallocationTests

using Test
using ComputerAdaptiveTesting: Aggregators, NextItemRules
using ComputerAdaptiveTesting.Aggregators
using ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting.Responses
using FittedItemBanks
using PsychometricsBazaarBase: Integrators

function fixture(n; space = LinSpace(), points = 33)
    bank = ItemBank2PL(collect(range(-2, 2; length = n)), fill(1.3, n))
    grid = Integrators.FixedGridIntegrator(range(-4, 4; length = points))
    dist = PosteriorAbilityEstimator(space)
    tracker = AbilityTracker(GriddedAbilityTracker, dist, grid)
    integral = AbilityIntegrator(grid, tracker)
    point = MeanAbilityEstimator(dist, integral)
    history = TrackedResponses(
        BareResponses(ResponseType(bank), collect(1:10), isodd.(1:10)), bank, tracker)
    track!(history)
    (; bank, grid, dist, tracker, integral, point, history)
end

function warmed_allocations(f::F) where {F}
    f()
    f()
    minimum(@allocated(f()) for _ in 1:3)
end

@testset "Preallocation reaches sequenced response expectations" begin
    for space in (LinSpace(), LogSpace())
        (; dist, tracker, integral, point, history) = fixture(32; space)
        for expectation in (NextItemRules.PointResponseExpectation(point),
                NextItemRules.DistributionResponseExpectation(dist, integral))
            criterion = NextItemRules.ExpectationBasedItemCriterion(
                expectation, AbilityVariance(dist, integral))
            rule = FixedFirstItem(1, ItemCriterionRule(ExhaustiveSearch(), criterion))
            prepared = preallocate(rule)
            inner = last(prepared.rules).criterion
            prediction = inner.response_expectation
            prediction_integral = prediction isa NextItemRules.PointResponseExpectation ?
                                  prediction.ability_estimator.integrator : prediction.integrator
            for adapter in (prediction_integral, inner.criterion.integrator)
                @test adapter.tracker === tracker
                if space == LinSpace()
                    @test get_integrator(adapter) isa Integrators.PreallocatedFixedGridIntegrator
                else
                    @test adapter === integral
                end
            end
            @test prepared.rules[1].item_idxs == (1,)
            @test compute_criteria(prepared, history) ≈ compute_criteria(rule, history)
            @test best_item(prepared, history) == best_item(rule, history)
            @test preallocate((; nested = (integral,))).nested[1].tracker === tracker
        end
    end
end

@testset "Prepared linear scans do not allocate per candidate" begin
    function scan_allocations(n)
        (; dist, integral, point, history) = fixture(n)
        rule = preallocate(FixedFirstItem(1,
            ItemCriterionRule(point, AbilityVariance(dist, integral))))
        reference_integral = FunctionIntegrator(get_integrator(integral))
        reference = ItemCriterionRule(MeanAbilityEstimator(dist, reference_integral),
            AbilityVariance(dist, reference_integral))
        @test compute_criteria(rule, history) ≈ compute_criteria(reference, history)
        warmed_allocations(() -> best_item(rule, history))
    end
    small = scan_allocations(64)
    large = scan_allocations(512)
    # Permit fixed framework/compiler overhead, but not a grid allocation for
    # every candidate, response or moment. Do not depend on an exact byte count.
    @test large <= small + 2048
end

@testset "Analytic speculative deltas reuse grid scratch" begin
    @testset "$space" for space in (LinSpace(), LogSpace())
        function delta_allocations(points)
            (; dist, tracker, integral, history) = fixture(32; space, points)
            spec = Speculator(history, 1)
            scratch = spec.responses.ability_tracker.scratch
            parent_density = deepcopy(tracker.density)
            indices, positive, negative = [11], [true], [false]
            replace_speculation!(spec, indices, positive)
            allocations = warmed_allocations(() -> replace_speculation!(spec, indices, negative))
            @test spec.responses.ability_tracker.scratch === scratch
            reference = space == LinSpace() ? FunctionIntegrator(get_integrator(integral)) :
                        LogGridIntegrator(get_integrator(integral))
            @test variance(integral, dist, spec.responses) ≈ variance(reference, dist, spec.responses)
            if space == LinSpace()
                @test tracker.density == parent_density
            else
                @test tracker.density.log_values == parent_density.log_values
                @test tracker.density.weights == parent_density.weights
            end
            # An empty delta must also restore normalized log weights left by
            # the previous speculation, not just its unnormalized log density.
            restored = Aggregators.grid_delta_density!(scratch, tracker,
                tracker.density, history, length(history) + 1)
            if space == LinSpace()
                @test restored == tracker.density
            else
                @test restored.log_values == tracker.density.log_values
                @test restored.weights == tracker.density.weights
                @test restored.log_scale == tracker.density.log_scale
                @test restored.scaled_sum == tracker.density.scaled_sum
            end
            allocations
        end
        small = delta_allocations(33)
        large = delta_allocations(513)
        @test large <= small + 256
    end
end

end
