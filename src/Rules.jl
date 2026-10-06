module Rules

export CatRules

using DocStringExtensions
using PsychometricsBazaarBase.Parameters
using PsychometricsBazaarBase.IndentWrappers: indent

using ..Aggregators: AbilityEstimator, AbilityTracker, ConsAbilityTracker,
                     NullAbilityTracker
using ..NextItemRules: NextItemRule
using ..TerminationConditions: TerminationCondition
using ..ConfigBase
import Base: show
import PsychometricsBazaarBase: power_summary

"""
$(TYPEDEF)
$(TYPEDFIELDS)

Configuration of the rules for a CAT. This all includes all the basic rules for
the CAT's operation, but not the item bank, nor any of the interactivity hooks
needed to actually run the CAT.

This may be more a more convenient layer to integrate than CatLoop if you
want to write your own CAT loop rather than using hooks.

    $(FUNCTIONNAME)(; next_item=..., termination_condition=..., ability_estimator=..., ability_tracker=...)

Explicit constructor for $(FUNCTIONNAME).

    $(FUNCTIONNAME)(bits...)

Implicit constructor for $(FUNCTIONNAME). Supply a point estimator instance,
or a point estimator type (such as `MeanAbilityEstimator`) together with its
distribution and numerical backend. Constructors for item/state criteria inherit
the resolved estimator and compatible integration adapter. Explicitly supplied
components retain their own configuration. Shared trackers from estimation,
selection and stopping are registered once.
"""
@kw_only struct CatRules{
    NextItemRuleT <: NextItemRule,
    TerminationConditionT <: TerminationCondition,
    AbilityEstimatorT <: AbilityEstimator,
    AbilityTrackerT <: AbilityTracker
} <: CatConfigBase
    """
    The rule to choose the next item in the CAT given the current state.
    """
    next_item::NextItemRuleT
    """
    The rule to choose when to terminate the CAT.
    """
    termination_condition::TerminationConditionT
    """
    The ability estimator, which estimates the testee's current ability.
    """
    ability_estimator::AbilityEstimatorT
    """
    The ability tracker, which tracks the testee's current ability level.
    """
    ability_tracker::AbilityTrackerT = NullAbilityTracker()
end

function CatRules(bits...)
    ability_estimator, ability_tracker = _find_ability_estimator_and_tracker(bits...)
    if ability_estimator === nothing
        error("Could not find an ability estimator in $(bits)")
    end
    if ability_tracker === nothing
        error("Could not find an ability tracker in $(bits)")
    end
    next_item = NextItemRule(bits...,
        ability_estimator = ability_estimator,
        ability_tracker = ability_tracker)
    if next_item === nothing
        error("Could not find a next item rule in $(bits)")
    end
    termination_condition = TerminationCondition(bits...)
    if termination_condition === nothing
        error("Could not find a termination condition in $(bits)")
    end
    CatRules(;
        next_item = next_item,
        termination_condition = termination_condition,
        ability_estimator = ability_estimator,
        ability_tracker = collect_trackers(next_item, ability_estimator,
            termination_condition, ability_tracker))
end

function show(io::IO, ::MIME"text/plain", rules::CatRules)
    power_summary(io, rules; toplevel=true)
end

function power_summary(io::IO, rules::CatRules; toplevel=false)
    # TODO
    print(io, "Next item rule: ")
    power_summary(io, rules.next_item)
    if toplevel
        println(io)
    end
    print(io, "Termination condition: ")
    power_summary(io, rules.termination_condition)
    if toplevel
        println(io)
    end
    print(io, "Ability estimator: ")
    power_summary(io, rules.ability_estimator)
end

function _find_ability_estimator_and_tracker(bits...)
    ability_estimator = AbilityEstimator(bits...)
    ability_tracker = AbilityTracker(bits...; ability_estimator = ability_estimator)
    (ability_estimator, ability_tracker)
end

# A shared cache may be reachable through estimation, selection and stopping.
# Register each tracker once so a response update refreshes it only once.
function collect_trackers(configs...)
    trackers = AbilityTracker[]
    for config in configs
        collect_trackers!(trackers, config)
    end
    foldr(ConsAbilityTracker, trackers; init = NullAbilityTracker())
end

collect_trackers!(trackers, _) = nothing
collect_trackers!(trackers, ::NullAbilityTracker) = nothing
function collect_trackers!(trackers, tracker::AbilityTracker)
    any(existing -> existing === tracker, trackers) || push!(trackers, tracker)
    nothing
end
function collect_trackers!(trackers, pair::ConsAbilityTracker)
    collect_trackers!(trackers, pair.head)
    collect_trackers!(trackers, pair.tail)
end
function collect_trackers!(trackers, config::CatConfigBase)
    for field in fieldnames(typeof(config))
        collect_trackers!(trackers, getfield(config, field))
    end
end
function collect_trackers!(trackers, configs::Tuple)
    for config in configs
        collect_trackers!(trackers, config)
    end
end

end
