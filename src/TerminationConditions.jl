module TerminationConditions

using DocStringExtensions: TYPEDEF, TYPEDFIELDS
using FittedItemBanks: AbstractItemBank
using ..Aggregators: TrackedResponses
using ..ConfigBase
using PsychometricsBazaarBase.ConfigTools: @returnsome, find1_instance
using FittedItemBanks

export TerminationCondition,
       FixedItemsTerminationCondition, SimpleFunctionTerminationCondition
export RunForeverTerminationCondition

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
struct FixedItemsTerminationCondition{} <: TerminationCondition
    num_items::Int64
end
function (condition::FixedItemsTerminationCondition)(responses::TrackedResponses,
        items::AbstractItemBank)
    length(responses) >= condition.num_items
end

struct SimpleFunctionTerminationCondition{F} <: TerminationCondition
    func::F
end
function (condition::SimpleFunctionTerminationCondition)(responses::TrackedResponses,
        items::AbstractItemBank)
    condition.func(responses, items)
end

struct RunForeverTerminationCondition <: TerminationCondition end
function (condition::RunForeverTerminationCondition)(::TrackedResponses, ::AbstractItemBank)
    return false
end

end
