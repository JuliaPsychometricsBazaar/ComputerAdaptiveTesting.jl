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

function show(io::IO, ::MIME"text/plain", rule::PointwiseNextItemRule)
    println(io, "Optimize a pointwise criterion at specified points")
    indent_io = indent(io, 2)
    points_desc = join(rule.points, ", ")
    println(indent_io, "Points: $points_desc")
    print(indent_io, "Criterion: ")
    show(indent_io, MIME("text/plain"), rule.criterion)
end


function PointwiseFirstNextItemRule(criterion, points, rule)
    FixedRuleSequencer((length(points),), (PointwiseNextItemRule(criterion, points), rule))
end
