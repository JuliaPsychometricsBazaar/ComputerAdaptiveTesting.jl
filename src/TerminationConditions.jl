module TerminationConditions

using ..ItemBanks: AbstractItemBank
using ..Aggregators: TrackedResponses
using ..ConfigBase
using ..MathTraits

abstract type TerminationCondition <: CatConfigBase end

function TerminationCondition(bits...)
    @returnsome find1_instance(TerminationCondition, bits)
end

struct FixedItemsTerminationCondition{} <: TerminationCondition
    num_items::Int64
end
ConfigPurity(::FixedItemsTerminationCondition) = PureConfig
function (condition::FixedItemsTerminationCondition)(responses::TrackedResponses, items::AbstractItemBank)
    length(responses) >= condition.num_items
end

struct SimpleFunctionTerminationCondition{F} <: TerminationCondition
    func::F
end
ConfigPurity(::SimpleFunctionTerminationCondition) = PureConfig
function (condition::SimpleFunctionTerminationCondition)(responses::TrackedResponses, items::AbstractItemBank)
    condition.func(responses, items)
end

end