module CatConfig

export CatLoopConfig

using Reexport, FromFile, Parameters

@from "./aggregators/Aggregators.jl" using Aggregators: AbilityEstimator, AbilityTracker, NullAbilityTracker
@from "./next_item_rules/NextItemRules.jl" using NextItemRules: NextItemRule
@from "./TerminationConditions.jl" using TerminationConditions: TerminationCondition
@from "./ConfigBase.jl" using ConfigBase: CatConfigBase

"""
Configuration for a CAT.
"""
@with_kw struct CatLoopConfig <: CatConfigBase
    """
    The function (index, label) -> Int8 which obtains the testee's response for
    a given question, e.g. by prompting or simulation from data.
    """
    get_response
    """
    The rule to choose the next item in the CAT given the current state.
    """
    next_item::NextItemRule
    """
    The rule to choose when to terminate the CAT.
    """
    termination_condition::TerminationCondition
    """
    The ability estimator, which estimates the testee's current ability.
    """
    ability_estimator::AbilityEstimator
    """
    The ability tracker, which tracks the testee's current ability level.
    """
    ability_tracker::AbilityTracker = NullAbilityTracker()
end

end