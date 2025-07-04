struct DeterminantScalarizer <: MatrixScalarizer end
scalarize(::DeterminantScalarizer, mat) = det(mat)

struct TraceScalarizer <: MatrixScalarizer end
scalarize(::TraceScalarizer, mat) = tr(mat)

struct ScalarizedItemCriteron{
    ItemMultiCriterionT <: ItemMultiCriterion,
    MatrixScalarizerT <: MatrixScalarizer
} <: ItemCriterion
    criteria::ItemMultiCriterionT
    scalarizer::MatrixScalarizerT
end

struct ScalarizedStateCriteron{
    StateMultiCriterionT <: StateMultiCriterion,
    MatrixScalarizerT <: MatrixScalarizer
} <: StateCriterion
    criteria::StateMultiCriterionT
    scalarizer::MatrixScalarizerT
end

function compute_criterion(ssc::Union{ScalarizedItemCriteron, ScalarizedStateCriteron},
        tracked_responses::TrackedResponses, item_idx...)
    res = scalarize(
        ssc.scalarizer,
        compute_multi_criterion(
            ssc.criteria,
            init_thread(ssc.criteria, tracked_responses),
            tracked_responses,
            item_idx...
        )
    )
    if !should_minimize(ssc.criteria)
        res = -res
    end
    res
end

struct WeightedStateMultiCriterion{InnerT <: StateMultiCriterion} <: StateMultiCriterion
    weights::Vector{Float64}
    criteria::InnerT
end

function compute_multi_criterion(
        wsc::WeightedStateMultiCriterion, tracked_responses::TrackedResponses, item_idx)
    wsc.weights' * wsc.criteria(tracked_responses, item_idx) * wsc.weights
end

struct WeightedItemMultiCriterion{InnerT <: ItemMultiCriterion} <: ItemMultiCriterion
    weights::Vector{Float64}
    criteria::InnerT
end

function compute_multi_criterion(
        wsc::WeightedItemMultiCriterion, tracked_responses::TrackedResponses, item_idx)
    wsc.weights' * wsc.criteria(tracked_responses, item_idx) * wsc.weights
end
