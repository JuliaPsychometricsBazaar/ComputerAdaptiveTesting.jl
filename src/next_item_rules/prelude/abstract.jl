
"""
$(TYPEDEF)

Abstract base type for all item selection rules. All descendants of this type
are expected to implement the interface
`(::NextItemRule)(responses::TrackedResponses, items::AbstractItemBank)::Int`.

In practice, all adaptive rules in this package use `ItemStrategyNextItemRule`.

    $(FUNCTIONNAME)(bits...; ability_estimator=nothing, parallel=true)

Implicit constructor for $(FUNCTIONNAME). Uses any given `NextItemRule` or
delegates to `ItemStrategyNextItemRule` the default instance.
"""
abstract type NextItemRule <: CatConfigBase end

"""
$(TYPEDEF)

Abstract type for next item strategies, tightly coupled with `ItemStrategyNextItemRule`.
All descendants of this type are expected to implement the interface
`(rule::ItemStrategyNextItemRule{::NextItemStrategy, ::ItemCriterion})(responses::TrackedResponses,
        items) where {ItemCriterionT <: }
`(strategy::NextItemStrategy)(; parallel=true)::NextItemStrategy`
"""
abstract type NextItemStrategy <: CatConfigBase end

"""
$(TYPEDEF)

Abstract base type all criteria should inherit from
"""
abstract type CriterionBase <: CatConfigBase end
abstract type ItemCriterionBase <: CatConfigBase end

abstract type ItemCriterion <: ItemCriterionBase end

"""
$(TYPEDEF)
"""
abstract type StateCriterion <: CriterionBase end

"""
$(TYPEDEF)
"""
abstract type PointwiseItemCriterion <: ItemCriterionBase end

"""
$(TYPEDEF)
"""
abstract type ItemCategoryCriterion <: ItemCriterionBase end

"""
$(TYPEDEF)
"""
abstract type PointwiseItemCategoryCriterion <: ItemCriterionBase end

abstract type MatrixScalarizer end
abstract type StateMultiCriterion end
abstract type ItemMultiCriterion end
