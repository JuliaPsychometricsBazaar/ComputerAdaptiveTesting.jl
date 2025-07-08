
"""
$(TYPEDEF)

Abstract base type for all item selection rules. All descendants of this type
are expected to implement the interface
`(::NextItemRule)(responses::TrackedResponses, items::AbstractItemBank)::Int`.

In practice, all adaptive rules in this package use `ItemCriterionRule`.

    $(FUNCTIONNAME)(bits...; ability_estimator=nothing, parallel=true)

Implicit constructor for $(FUNCTIONNAME). Uses any given `NextItemRule` or
delegates to `ItemCriterionRule` the default instance.
"""
abstract type NextItemRule <: CatConfigBase end

"""
$(TYPEDEF)

Abstract type for next item strategies, tightly coupled with `ItemCriterionRule`.
All descendants of this type are expected to implement the interface
`(rule::ItemCriterionRule{::NextItemStrategy, ::ItemCriterion})(responses::TrackedResponses,
        items) where {ItemCriterionT <: }
`(strategy::NextItemStrategy)(; parallel=true)::NextItemStrategy`
"""
abstract type NextItemStrategy <: CatConfigBase end

"""
$(TYPEDEF)

Abstract base type all criteria should inherit from
"""
abstract type CriterionBase <: CatConfigBase end
abstract type SubItemCriterionBase <: CatConfigBase end

"""
$(TYPEDEF)
"""
abstract type ItemCriterion <: CatConfigBase end

"""
$(TYPEDEF)
"""
abstract type StateCriterion <: CriterionBase end

"""
$(TYPEDEF)
"""
abstract type PointwiseItemCriterion <: SubItemCriterionBase end

"""
$(TYPEDEF)
"""
abstract type ItemCategoryCriterion <: SubItemCriterionBase end

"""
$(TYPEDEF)
"""
abstract type PointwiseItemCategoryCriterion <: SubItemCriterionBase end

abstract type MatrixScalarizer end
abstract type StateMultiCriterion end
abstract type ItemMultiCriterion end
