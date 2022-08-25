mutable struct MultiAbilityTracker <: AbilityTracker
    trackers::Vector{AbilityTracker}
end

function track!(responses, ability_tracker::MultiAbilityTracker)
    for tracker in ability_tracker.trackers
        track!(responses, tracker)
    end
end