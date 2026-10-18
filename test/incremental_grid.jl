module IncrementalGridTests

using Test
using Distributions: Normal, MvNormal, pdf, logpdf
import Distributions
using ComputerAdaptiveTesting: Aggregators, CatRules, Stateful, Rules
using ComputerAdaptiveTesting.Aggregators
using ComputerAdaptiveTesting.Responses
using ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting.TerminationConditions
using ComputerAdaptiveTesting.DecisionTree
using FittedItemBanks
using PsychometricsBazaarBase.Integrators: FixedGridIntegrator,
                                           IterativeFixedGridIntegrator, intval

struct UnsupportedDensity <: DistributionAbilityEstimator end
function Distributions.pdf(::UnsupportedDensity, r::TrackedResponses)
    pdf(PosteriorAbilityEstimator(), r)
end
function Distributions.logpdf(::UnsupportedDensity, r::TrackedResponses)
    logpdf(PosteriorAbilityEstimator(), r)
end

struct CountingPosterior <: DistributionAbilityEstimator
    evaluations::Base.RefValue{Int}
end
Aggregators.response_delta_style(::CountingPosterior) = MultiplicativeResponseDelta()
function Distributions.pdf(est::CountingPosterior, r::TrackedResponses)
    density = pdf(PosteriorAbilityEstimator(Normal(-0.3, 1.2)), r)
    x -> (est.evaluations[] += 1; density(x))
end
function Distributions.logpdf(est::CountingPosterior, r::TrackedResponses)
    density = logpdf(PosteriorAbilityEstimator(Normal(-0.3, 1.2)), r)
    x -> (est.evaluations[] += 1; density(x))
end

struct CountingBank{B <: AbstractItemBank} <: AbstractItemBank
    inner::B
    evaluated_items::Vector{Int}
    fail::Base.RefValue{Bool}
end
CountingBank(inner, items) = CountingBank(inner, items, Ref(false))
Base.length(bank::CountingBank) = length(bank.inner)
FittedItemBanks.ResponseType(bank::CountingBank) = ResponseType(bank.inner)
FittedItemBanks.DomainType(bank::CountingBank) = DomainType(bank.inner)
function FittedItemBanks.resp(ir::ItemResponse{<:CountingBank}, value, x)
    ir.item_bank.fail[] && error("Response evaluation failed")
    push!(ir.item_bank.evaluated_items, ir.index)
    resp(ItemResponse(ir.item_bank.inner, ir.index), value, x)
end
function FittedItemBanks.log_resp(ir::ItemResponse{<:CountingBank}, value, x)
    ir.item_bank.fail[] && error("Response evaluation failed")
    push!(ir.item_bank.evaluated_items, ir.index)
    log_resp(ItemResponse(ir.item_bank.inner, ir.index), value, x)
end

make_tracker(::LinSpace, est, grid) = GriddedAbilityTracker(est, grid)
make_tracker(::LogSpace, est, grid) = LogGridAbilityTracker(est, grid)
reference_integrator(::LinSpace, grid) = FunctionIntegrator(grid)
reference_integrator(::LogSpace, grid) = LogGridIntegrator(grid)

@testset "Incremental grid capability and configuration" begin
    grid = FixedGridIntegrator(range(-5, 5; length = 41))
    bank = ItemBank2PL([-0.8, 0.3, 1.4, -0.1], [0.9, 1.8, 1.1, 1.3])
    @test response_delta_style(LikelihoodAbilityEstimator()) isa MultiplicativeResponseDelta
    @test response_delta_style(PosteriorAbilityEstimator()) isa MultiplicativeResponseDelta
    @test response_delta_style(SafeLikelihoodAbilityEstimator()) isa NoResponseDelta
    for est in (UnsupportedDensity(), SafeLikelihoodAbilityEstimator())
        @test_throws ArgumentError GriddedAbilityTracker(est, grid)
        @test_throws ArgumentError LogGridAbilityTracker(est, grid)
        @test_throws ArgumentError CatRules(MeanAbilityEstimator, est, grid,
            GriddedAbilityTracker, AbilityVariance, FixedLength(2))
        r = TrackedResponses(BareResponses(ResponseType(bank), [1, 2], [false, true]), bank)
        @test isfinite(MeanAbilityEstimator(est, FunctionIntegrator(grid))(r))
        @test isfinite(MeanAbilityEstimator(est, LogGridIntegrator(grid))(r))
    end
    for space in (LinSpace(), LogSpace())
        est = PosteriorAbilityEstimator(Normal(0.6, 0.8), space)
        tracker = make_tracker(space, est, grid)
        @test GriddedAbilityTracker(grid, est).ability_estimator === est
        integral = AbilityIntegrator(grid, tracker)
        @test integral.tracker === tracker
        @test AbilityIntegrator(grid, tracker; ability_estimator = est).tracker === tracker
        other = PosteriorAbilityEstimator(Normal(-1, 0.7), space)
        @test AbilityIntegrator(grid, tracker; ability_estimator = other) !== integral
        explicit = FunctionIntegrator(grid)
        @test AbilityIntegrator(explicit, tracker) === explicit
        rules = CatRules(
            MeanAbilityEstimator, est, grid, tracker, AbilityVariance, FixedLength(2))
        prepared = preallocate(rules)
        @test prepared.ability_estimator.integrator.tracker === tracker
        @test prepared.next_item.criterion.criterion.integrator.tracker === tracker
        @test Rules.collect_trackers(prepared).head === tracker
        r = TrackedResponses(BareResponses(ResponseType(bank)), bank, prepared.ability_tracker)
        @test tracker.cache === nothing
        @test MeanAbilityEstimator(est, prepared.ability_estimator.integrator)(r) ≈
              MeanAbilityEstimator(est, reference_integrator(space, grid))(r)
        @test tracker.cache === nothing
        second = make_tracker(space, other, grid)
        both = Aggregators.ConsAbilityTracker(tracker, second)
        combined = TrackedResponses(BareResponses(ResponseType(bank)), bank, both)
        add_response!(combined, Response(ResponseType(bank), 1, true))
        add_response!(combined, Response(ResponseType(bank), 2, false))
        for (density, cache_tracker) in ((est, tracker), (other, second))
            @test MeanAbilityEstimator(density, AbilityIntegrator(grid, cache_tracker))(combined) ≈
                  MeanAbilityEstimator(density, reference_integrator(space, grid))(combined)
            @test length(cache_tracker.cache.responses) == 2
        end
        empty!(combined)
        @test isempty(tracker.cache.responses.indices)
        @test isempty(second.cache.responses.indices)
    end
end

@testset "Speculative grid density agrees with untracked integration" begin
    grid = FixedGridIntegrator(range(-5, 5; length = 41))
    bank = ItemBank2PL([-0.8, 0.3, 1.4, -0.1], [0.9, 1.8, 1.1, 1.3])
    for space in (LinSpace(), LogSpace()),
        est in (LikelihoodAbilityEstimator(space), PosteriorAbilityEstimator(Normal(0.6, 0.8), space))

        tracker = make_tracker(space, est, grid)
        integral = preallocate(AbilityIntegrator(grid, tracker))
        reference = reference_integrator(space, grid)
        r = TrackedResponses(BareResponses(ResponseType(bank), [1], [false]), bank, tracker)
        @test isempty(unsynced_responses(r).indices)
        @test MeanAbilityEstimator(est, integral)(r) ≈
              MeanAbilityEstimator(est, reference)(r)
        track!(r)
        cache = tracker.cache
        function check(history)
            @test Float64(normdenom(integral, est, history)) ≈
                  Float64(normdenom(reference, est, history))
            @test Float64(intval(integral(x -> x^2 + 2, 0, est, history))) ≈
                  Float64(intval(reference(x -> x^2 + 2, 0, est, history)))
            @test Float64.(intval(integral(x -> [x], 1, est, history))) ≈
                  [Float64(intval(reference(identity, 0, est, history)))]
            @test MeanAbilityEstimator(est, integral)(history) ≈
                  MeanAbilityEstimator(est, reference)(history)
            @test variance(integral, est, history) ≈ variance(reference, est, history)
            @test response_expectation(est, integral, history, 4) ≈
                  response_expectation(est, reference, history, 4)
        end
        check(r)
        zero = Speculator(r, 0)
        @test isempty(unsynced_responses(zero.responses).indices)
        check(zero.responses)
        @test_throws ArgumentError Speculator(r, -1)
        spec = Speculator(r, 1)
        replace_speculation!(spec, [2], [true])
        delta = unsynced_responses(spec.responses)
        @test delta.indices isa SubArray
        @test delta.values == [true]
        check(spec.responses)
        replace_speculation!(spec, [3], [false])
        @test delta.indices == [3]
        @test delta.values == [false]
        check(spec.responses)
        nested = Speculator(spec.responses, 1)
        replace_speculation!(nested, [4], [true])
        @test unsynced_responses(nested.responses).indices == [3, 4]
        check(nested.responses)
        multi = Speculator(r, 3)
        replace_speculation!(multi, [2, 3, 4], [true, false, true])
        check(multi.responses)
        track!(spec.responses)
        add_response!(spec.responses, Response(ResponseType(bank), 4, true))
        @test tracker.cache === cache
        check(spec.responses)
        @test tracker.cache === cache
        check(r)
        # A changed committed prefix invalidates an old speculative view.
        add_response!(r, Response(ResponseType(bank), 2, true))
        newcache = tracker.cache
        check(nested.responses)
        @test tracker.cache === newcache
        check(r)
        pop_response!(r)
        check(r)
        empty!(r)
        check(r)
        @test isempty(tracker.cache.responses.indices)
        add_response!(r.responses, Response(ResponseType(bank), 1, true))
        check(r)
        track!(r)
        r.responses.values[1] = false
        check(r)
        track!(r)
        other_bank = ItemBank2PL([-1.2, 0.6, 0.9, 0.0], ones(4))
        other = TrackedResponses(r.responses, other_bank)
        check(other)
        other_est = PosteriorAbilityEstimator(Normal(-0.5, 0.4), space)
        @test MeanAbilityEstimator(other_est, integral)(r) ≈
              MeanAbilityEstimator(other_est, reference)(r)
    end
end

@testset "Grid updates evaluate only the response delta" begin
    grid = FixedGridIntegrator(range(-4, 4; length = 21))
    for space in (LinSpace(), LogSpace())
        est = CountingPosterior(Ref(0))
        bank = CountingBank(ItemBank2PL([0.0, 0.5, 1.0, -0.5], ones(4)), Int[])
        tracker = make_tracker(space, est, grid)
        r = TrackedResponses(BareResponses(ResponseType(bank), [1, 2], [true, false]), bank, tracker)
        integral = preallocate(AbilityIntegrator(est, grid, tracker))
        # CountingPosterior uses LinSpace by default; explicitly adapt log tracking.
        integral = space == LogSpace() ? LogGridIntegrator(tracker) : integral
        track!(r)
        @test est.evaluations[] == length(grid.grid)
        empty!(bank.evaluated_items)
        add_response!(r, Response(ResponseType(bank), 3, true))
        @test est.evaluations[] == length(grid.grid)
        @test bank.evaluated_items == fill(3, length(grid.grid))
        empty!(bank.evaluated_items)
        spec = Speculator(r, 2)
        replace_speculation!(spec, [1, 4], [false, true])
        cache = tracker.cache
        normdenom(integral, est, spec.responses)
        @test est.evaluations[] == length(grid.grid)
        @test count(==(1), bank.evaluated_items) == length(grid.grid)
        @test count(==(4), bank.evaluated_items) == length(grid.grid)
        @test all(in((1, 4)), bank.evaluated_items)
        @test tracker.cache === cache
        pop_response!(r)
        @test est.evaluations[] == 2length(grid.grid)
        track!(r)
        @test est.evaluations[] == 3length(grid.grid)
        spec = Speculator(r, 1)
        replace_speculation!(spec, [4], [true])
        cache = tracker.cache
        bank.fail[] = true
        @test_throws ErrorException normdenom(integral, est, spec.responses)
        @test tracker.cache === cache
        @test_throws ErrorException add_response!(r, Response(ResponseType(bank), 4, true))
        @test tracker.cache === nothing
        bank.fail[] = false
        pop_response!(r)
        @test tracker.cache !== nothing
    end
end

@testset "General grid and response shapes" begin
    xs = [[x, y] for x in -2.0:1.0:2.0 for y in -2.0:1.0:2.0]
    bank = NominalItemBank([[-1.0, 0.0, 1.0]], reshape([1.0, 0.5], 2, 1), [[
        -0.5, 0.0, 0.5]])
    for space in (LinSpace(), LogSpace()),
        backend in (FixedGridIntegrator(xs), preallocate(FixedGridIntegrator(xs)),
            IterativeFixedGridIntegrator(xs))

        est = PosteriorAbilityEstimator(MvNormal([0.3, -0.2], [1.1, 0.8]), space)
        tracker = make_tracker(space, est, backend)
        integral = AbilityIntegrator(est, backend, tracker)
        r = TrackedResponses(BareResponses(ResponseType(bank)), bank, tracker)
        track!(r)
        add_response!(r, Response(ResponseType(bank), 1, 2))
        spec = Speculator(r, 2)
        replace_speculation!(spec, [1, 1], [1, 3])
        for history in (r, spec.responses)
            weights = pdf(est, history).(xs)
            mass = sum(weights)
            μ = sum(w * x for (w, x) in zip(weights, xs)) / mass
            cov = sum(w * (x - μ) * (x - μ)' for (w, x) in zip(weights, xs)) / mass
            @test Float64(normdenom(integral, est, history)) ≈ mass
            @test MeanAbilityEstimator(est, integral)(history) ≈ μ
            @test Aggregators.covariance_matrix(integral, est, history) ≈ cov
            @test Float64.(intval(integral(x -> x * x', 2, est, history))) ≈
                  sum(w * x * x' for (w, x) in zip(weights, xs))
            @test response_expectation(est, integral, history, 1) ≈
                  sum(w * resp_vec(ItemResponse(bank, 1), x)
            for (w, x) in zip(weights, xs)) / mass
        end
        @test_throws ArgumentError Aggregators.TrackedLikelihoodIntegrator(
            FixedGridIntegrator([[0.0, 0.0]]), GriddedAbilityTracker(est, backend))
    end
    points = DichotomousPointsItemBank([-1.0, 0.0, 1.0], reshape([0.2, 0.4, 0.8], :, 1))
    for space in (LinSpace(), LogSpace()),
        bank in (points, DichotomousPointsWithLogsItemBank(points))

        grid = IterativeFixedGridIntegrator(points.xs)
        est = PosteriorAbilityEstimator(Normal(0.3, 0.8), space)
        tracker = make_tracker(space, est, grid)
        r = TrackedResponses(BareResponses(ResponseType(bank)), bank, tracker)
        track!(r)
        add_response!(r, Response(ResponseType(bank), 1, true))
        spec = Speculator(r, 1)
        replace_speculation!(spec, [1], [false])
        integral = AbilityIntegrator(est, grid, tracker)
        weights = function_ys(AbilityLikelihood(spec.responses)) .*
                  pdf.(Ref(est.prior), points.xs)
        @test mean_1d(integral, est, spec.responses) ≈
              sum(points.xs .* weights) / sum(weights)
        @test MeanAbilityEstimator(est, integral)(spec.responses) ≈
              sum(points.xs .* weights) / sum(weights)
        @test response_expectation(est, integral, spec.responses, 1) ≈
              [sum(weights .* (1 .- points.ys[:, 1])), sum(weights .* points.ys[:, 1])] ./
              sum(weights)
    end
end

@testset "Tracked selection, CAT lifecycle and decision trees" begin
    grid = FixedGridIntegrator(range(-5, 5; length = 41))
    bank = ItemBank2PL([-1.1, 0.3, 1.4, -0.4, 0.8, -0.8], [0.9, 1.8, 1.1, 1.3, 0.8, 1.6])
    for space in (LinSpace(), LogSpace())
        est = PosteriorAbilityEstimator(Normal(0.6, 0.8), space)
        tracked_rules = preallocate(CatRules(MeanAbilityEstimator, est, grid,
            GriddedAbilityTracker, AbilityVariance, FixedLength(4)))
        plain_rules = CatRules(
            MeanAbilityEstimator, est, reference_integrator(space, grid),
            AbilityVariance, FixedLength(4))
        tracked = Stateful.StatefulCatRules(tracked_rules, bank)
        plain = Stateful.StatefulCatRules(plain_rules, bank)
        for response in (false, true, true, false)
            @test Stateful.item_criteria(tracked) ≈ Stateful.item_criteria(plain)
            @test Stateful.next_item(tracked) == Stateful.next_item(plain)
            item = Stateful.next_item(plain)
            Stateful.add_response!(tracked, item, response)
            Stateful.add_response!(plain, item, response)
            @test first(Stateful.get_ability(tracked)) ≈ first(Stateful.get_ability(plain))
        end
        Stateful.rollback!(tracked)
        Stateful.rollback!(plain)
        @test Stateful.item_criteria(tracked) ≈ Stateful.item_criteria(plain)
        Stateful.reset!(tracked)
        Stateful.reset!(plain)
        @test Stateful.next_item(tracked) == Stateful.next_item(plain)
        Stateful.set_item_bank!(tracked, ItemBank2PL(collect(-1.0:0.4:1.0), ones(6)))
        Stateful.set_item_bank!(plain, tracked.tracked_responses[].item_bank)
        @test Stateful.item_criteria(tracked) ≈ Stateful.item_criteria(plain)
        for (cat, rules) in ((tracked, tracked_rules), (plain, plain_rules))
            Stateful.add_response!(cat, 1, true)
        end
        @test first(Stateful.get_ability(tracked)) ≈ first(Stateful.get_ability(plain))
        function tree(rules)
            config = DecisionTreeGenerationConfig(max_depth = UInt(2),
                next_item = rules.next_item, ability_estimator = rules.ability_estimator,
                ability_tracker = rules.ability_tracker)
            generate_dt_cat(config, bank)
        end
        tracked_tree, plain_tree = tree(tracked_rules), tree(plain_rules)
        @test tracked_tree.questions == plain_tree.questions
        @test tracked_tree.ability_estimates ≈ plain_tree.ability_estimates
    end
end

end
