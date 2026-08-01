using ComputerAdaptiveTesting
using ComputerAdaptiveTesting.Aggregators
using ComputerAdaptiveTesting.Responses
using ComputerAdaptiveTesting.NextItemRules
import ComputerAdaptiveTesting.NextItemRules: should_minimize
using ComputerAdaptiveTesting.TerminationConditions
using FittedItemBanks
using PsychometricsBazaarBase.Integrators
using PsychometricsBazaarBase: power_summary
using Distributions

"""
An item bank of 8 identical, well behaved items, so that the only thing which
varies between the states below is how many items have been administered.
"""
const term_item_bank = ItemBank2PL(zeros(8), fill(1.5, 8))

"""
Tracked responses with the first `num_responses` items administered.
"""
function mk_tracked_responses(num_responses)
    responses = BareResponses(
        ResponseType(term_item_bank),
        collect(1:num_responses),
        [isodd(idx) for idx in 1:num_responses]
    )
    TrackedResponses(responses, term_item_bank, NullAbilityTracker())
end

const term_states = [mk_tracked_responses(num_responses) for num_responses in 0:8]

"""
A `StateCriterion` counting administered items, used to check delegation
without dragging in integration. Larger is better, i.e. it is maximised.
"""
struct CountStateCriterion <: NextItemRules.StateCriterion end

function NextItemRules.compute_criterion(
        ::CountStateCriterion, tracked_responses::TrackedResponses)
    Float64(length(tracked_responses))
end

should_minimize(::CountStateCriterion) = false

@testset "termination_conditions" begin
    @testset "FixedLength" begin
        condition = FixedLength(3)
        @test [condition(state, term_item_bank) for state in term_states] ==
              [false, false, false, true, true, true, true, true, true]
    end

    @testset "FixedLength power_summary" begin
        buf = IOBuffer()
        power_summary(buf, FixedLength(3))
        @test occursin("3 items", String(take!(buf)))
    end

    @testset "RunForever" begin
        @test !any(RunForever()(state, term_item_bank) for state in term_states)
    end

    @testset "TerminationTest delegates" begin
        seen = []
        condition = TerminationTest(function (responses, items)
            push!(seen, (length(responses), items))
            length(responses) == 2
        end)
        @test !condition(term_states[1], term_item_bank)
        @test condition(term_states[3], term_item_bank)
        @test seen == [(0, term_item_bank), (2, term_item_bank)]
    end

    @testset "TerminationCondition implicit constructor" begin
        condition = FixedLength(3)
        @test TerminationCondition(condition) === condition
        @test TerminationCondition("unrelated") === nothing
    end

    @testset "LengthBoundedTermination stops at max_length" begin
        condition = LengthBoundedTermination(2, 5, RunForever())
        @test [condition(state, term_item_bank) for state in term_states] ==
              [false, false, false, false, false, true, true, true, true]
    end

    @testset "LengthBoundedTermination respects min_length" begin
        condition = LengthBoundedTermination(
            3, 6, TerminationTest((responses, items) -> true))
        @test [condition(state, term_item_bank) for state in term_states] ==
              [false, false, false, true, true, true, true, true, true]
    end

    @testset "LengthBoundedTermination passes through inner condition" begin
        condition = LengthBoundedTermination(2, 7, FixedLength(4))
        @test [condition(state, term_item_bank) for state in term_states] ==
              [false, false, false, false, true, true, true, true, true]
    end

    @testset "LengthBoundedTermination max_length wins over min_length" begin
        # A degenerate configuration: the maximum is reached before the minimum
        condition = LengthBoundedTermination(5, 2, RunForever())
        @test condition(term_states[3], term_item_bank)
    end

    @testset "StateCriterionThresholdTermination minimised criterion" begin
        criterion = AbilityVariance(
            LikelihoodAbilityEstimator(),
            AbilityIntegrator(FixedGKIntegrator(-6.0, 6.0, 61))
        )
        @test should_minimize(criterion)
        variances = [compute_criterion(criterion, state) for state in term_states[2:end]]
        # Sanity check: the variance shrinks as responses come in
        @test variances[end] < variances[1]

        threshold = (variances[4] + variances[5]) / 2
        condition = StateCriterionThresholdTermination(threshold, criterion)
        @test !condition(term_states[5], term_item_bank)
        @test condition(term_states[6], term_item_bank)

        # Threshold above every observed value terminates immediately
        @test StateCriterionThresholdTermination(maximum(variances) + 1.0, criterion)(
            term_states[2], term_item_bank)
        # Threshold below every observed value never terminates
        @test !StateCriterionThresholdTermination(0.0, criterion)(
            term_states[end], term_item_bank)
    end

    @testset "StateCriterionThresholdTermination maximised criterion" begin
        condition = StateCriterionThresholdTermination(3.0, CountStateCriterion())
        @test [condition(state, term_item_bank) for state in term_states] ==
              [false, false, false, true, true, true, true, true, true]
    end

    @testset "StateCriterionThresholdTermination exactly at threshold" begin
        @test StateCriterionThresholdTermination(2.0, CountStateCriterion())(
            term_states[3], term_item_bank)
    end
end
