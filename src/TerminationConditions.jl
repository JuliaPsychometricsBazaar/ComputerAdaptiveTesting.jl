module TerminationConditions

using DocStringExtensions: TYPEDEF, TYPEDFIELDS
using FittedItemBanks: AbstractItemBank
using ..Aggregators: TrackedResponses
using ..NextItemRules: StateCriterion, compute_criterion, should_minimize
using ..ConfigBase
import PsychometricsBazaarBase: power_summary
using PsychometricsBazaarBase.ConfigTools: @returnsome, find1_instance
using FittedItemBanks
import Base: show

export TerminationCondition, FixedLength, TerminationTest
export RunForever
export LengthBoundedTermination, StateCriterionThresholdTermination

"""
$(TYPEDEF)
"""
abstract type TerminationCondition <: CatConfigBase end

function TerminationCondition(bits...)
    @returnsome find1_instance(TerminationCondition, bits)
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
struct FixedLength{} <: TerminationCondition
    num_items::Int64
end
function (condition::FixedLength)(responses::TrackedResponses,
        items::AbstractItemBank)
    length(responses) >= condition.num_items
end

function power_summary(io::IO, condition::FixedLength)
    println(io, "Terminate test after administering $(condition.num_items) items")
end

struct TerminationTest{F} <: TerminationCondition
    condition::F
end
function (condition::TerminationTest)(responses::TrackedResponses,
        items::AbstractItemBank)
    condition.condition(responses, items)
end

struct RunForever <: TerminationCondition end
function (condition::RunForever)(::TrackedResponses, ::AbstractItemBank)
    return false
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)

Wraps another termination condition so that the test always administers at least
`min_length` items and never more than `max_length` items.
"""
struct LengthBoundedTermination{InnerT <: TerminationCondition} <: TerminationCondition
    min_length::Int64
    max_length::Int64
    termination_condition::InnerT
end
function (condition::LengthBoundedTermination)(responses::TrackedResponses,
        items::AbstractItemBank)
    nresp = length(responses)
    return (
        (nresp >= condition.max_length) ||
        (nresp >= condition.min_length && condition.termination_condition(responses, items))
    )
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)

Terminates the test once a `StateCriterion` reaches `threshold`. When the
criterion is one which should be minimised, the test terminates once it drops to
or below the threshold, otherwise once it reaches or exceeds it.
"""
struct StateCriterionThresholdTermination{InnerT <: StateCriterion} <: TerminationCondition
    threshold::Float64
    criterion::InnerT
end
function (condition::StateCriterionThresholdTermination)(responses::TrackedResponses,
        ::AbstractItemBank)
    value = compute_criterion(condition.criterion, responses)
    if should_minimize(condition.criterion)
        return value <= condition.threshold
    else
        return value >= condition.threshold
    end
end

end
