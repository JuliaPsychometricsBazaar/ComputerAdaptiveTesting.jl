struct DeterminantScalarizer <: MatrixScalarizer end
(::DeterminantScalarizer)(mat) = det(mat)

struct TraceScalarizer <: MatrixScalarizer end
(::TraceScalarizer)(mat) = tr(mat)

struct ScalarizedItemCriteron{
    ItemCriteriaT <: ItemCriteria,
    MatrixScalarizerT <: MatrixScalarizer
} <: ItemCriterion
    criteria::ItemCriteriaT
    scalarizer::MatrixScalarizerT
end

function (ssc::ScalarizedItemCriteron)(tracked_responses, item_idx)
    res = ssc.criteria(
        init_thread(ssc.criteria, tracked_responses), tracked_responses, item_idx) |>
          ssc.scalarizer
    if !should_minimize(ssc.criteria)
        res = -res
    end
    res
end

struct ScalarizedStateCriteron{
    StateCriteriaT <: StateCriteria,
    MatrixScalarizerT <: MatrixScalarizer
} <: StateCriterion
    criteria::StateCriteriaT
    scalarizer::MatrixScalarizerT
end

function (ssc::ScalarizedStateCriteron)(tracked_responses)
    res = ssc.criteria(tracked_responses) |> ssc.scalarizer
    if !should_minimize(ssc.criteria)
        res = -res
    end
    res
end

struct WeightedStateCriteria{InnerT <: StateCriteria} <: StateCriteria
    weights::Vector{Float64}
    criteria::InnerT
end

function (wsc::WeightedStateCriteria)(tracked_responses, item_idx)
    wsc.weights' * wsc.criteria(tracked_responses, item_idx) * wsc.weights
end

struct WeightedItemCriteria{InnerT <: ItemCriteria} <: ItemCriteria
    weights::Vector{Float64}
    criteria::InnerT
end

function (wsc::WeightedItemCriteria)(tracked_responses, item_idx)
    wsc.weights' * wsc.criteria(tracked_responses, item_idx) * wsc.weights
end
