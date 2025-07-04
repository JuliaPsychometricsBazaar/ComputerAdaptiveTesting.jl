module TerminationConditions

using DocStringExtensions: TYPEDEF, TYPEDFIELDS
using FittedItemBanks: AbstractItemBank
using ..Aggregators: TrackedResponses
using ..ConfigBase
using PsychometricsBazaarBase.ConfigTools: @returnsome, find1_instance
using FittedItemBanks
import Base: show

export TerminationCondition, FixedLength, TerminationTest
export RunForever

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

function show(io::IO, ::MIME"text/plain", condition::FixedLength)
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

end
