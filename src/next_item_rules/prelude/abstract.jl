
"""
$(TYPEDEF)

Abstract base type for all item selection rules. All descendants of this type
are expected to implement the interface
`(rule::NextItemRule)(responses::TrackedResponses, items::AbstractItemBank)::Int`

    $(FUNCTIONNAME)(bits...; ability_estimator=nothing, parallel=true)

Implicit constructor for $(FUNCTIONNAME). Uses any given `NextItemRule` or
delegates to `ItemStrategyNextItemRule`.
"""
abstract type NextItemRule <: CatConfigBase end

"""
$(TYPEDEF)
"""
abstract type NextItemStrategy <: CatConfigBase end

"""
$(TYPEDEF)
"""
abstract type ItemCriterion <: CatConfigBase end

"""
$(TYPEDEF)
"""
abstract type StateCriterion <: CatConfigBase end

abstract type MatrixScalarizer end
abstract type StateCriteria end
abstract type ItemCriteria end
