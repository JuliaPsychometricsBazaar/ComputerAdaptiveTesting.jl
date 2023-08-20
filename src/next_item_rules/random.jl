@with_kw struct RandomNextItemRule{RandomT <: AbstractRNG} <: NextItemRule
    rng::RandomT=Xoshiro()
end

#=
function get_rng(bits...)
    @returnsome find1_instance(AbstractRNG, bits)
    @returnsome find1_type(AbstractRNG, bits) typ -> typ()
    Xoshiro()
end

function RandomNextItemRule(bits...)
    RandomNextItemRule(rng=get_rng(bits...))
end
=#

function (rule::RandomNextItemRule)(responses, items)
    # TODO: This is not efficient
    item_idxes = Set(1:length(items))
    available = setdiff(item_idxes, Set(responses.responses.indices))
    rand(rule.rng, available)
end
