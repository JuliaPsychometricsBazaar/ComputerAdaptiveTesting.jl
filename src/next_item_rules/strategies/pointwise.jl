struct PointwiseNextItemRule{CriterionT <: PointwiseItemCriterion, PointsT <: AbstractArray{<:Number}} <: NextItemRule
    criterion::CriterionT
    points::PointsT
end

function best_item(rule::PointwiseNextItemRule, responses::TrackedResponses, items)
    num_responses = length(responses.responses.indices)
    next_index = num_responses + 1
    if next_index > length(rule.points)
        error("Number of responses exceeds the number of points defined in the rule.")
    end
    current_point = rule.points[next_index]
    idx, _ = exhaustive_search(responses.responses.indices, items) do item_idx
        return compute_criterion(rule.criterion, ItemResponse(items, item_idx), current_point)
    end
    return idx
end

function PointwiseFirstNextItemRule(criterion, points, rule)
    PiecewiseNextItemRule((length(points),), (PointwiseNextItemRule(criterion, points), rule))
end