"""
    Speculator(responses::TrackedResponses, size::Int)

Prepare a private response history and tracker for hypothetical responses.
Grid trackers stack a private density on their parent's density; other trackers
are copied. Recreate a speculator after changing its parent history or tracker.
"""
mutable struct Speculator{R <: TrackedResponses, P, S}
    responses::R
    size::Int
    delta_start::Int
    parent_tracker::P
    seed::S
end

speculation_seed(tracker::AbilityTracker) = deepcopy(tracker)
speculation_seed(::Union{GriddedAbilityTracker, LogGridAbilityTracker,
    StackedGridAbilityTracker}) = nothing
speculation_seed(tracker::ConsAbilityTracker) =
    (speculation_seed(tracker.head), speculation_seed(tracker.tail))

ensure_speculation_parent!(responses, tracker::AbilityTracker) = nothing
function ensure_speculation_parent!(responses, tracker::Union{
        GriddedAbilityTracker, LogGridAbilityTracker, StackedGridAbilityTracker})
    tracker.density === nothing && track!(responses, tracker)
end
function ensure_speculation_parent!(responses, tracker::ConsAbilityTracker)
    ensure_speculation_parent!(responses, tracker.head)
    ensure_speculation_parent!(responses, tracker.tail)
end

speculative_tracker(parent::AbilityTracker, seed, start) = deepcopy(seed)
speculative_tracker(parent::Union{GriddedAbilityTracker, LogGridAbilityTracker,
    StackedGridAbilityTracker}, ::Nothing, start) =
    StackedGridAbilityTracker(parent, parent.density, start)
speculative_tracker(parent::ConsAbilityTracker, seed::Tuple, start) =
    ConsAbilityTracker(speculative_tracker(parent.head, seed[1], start),
        speculative_tracker(parent.tail, seed[2], start))

function Speculator(responses::TrackedResponses, size::Int)
    size >= 0 || throw(ArgumentError("Speculation size must be nonnegative"))
    ensure_speculation_parent!(responses, responses.ability_tracker)
    response_type = ResponseType(responses.item_bank)
    orig_len = length(responses)
    spec_len = orig_len + size
    indices = Vector{Int}(undef, spec_len)
    values = Vector{concrete_response_type(response_type)}(undef, spec_len)
    indices[1:orig_len] = responses.responses.indices
    values[1:orig_len] = responses.responses.values
    start = orig_len + 1
    seed = speculation_seed(responses.ability_tracker)
    tracker = speculative_tracker(responses.ability_tracker, seed, start)
    speculative = TrackedResponses(BareResponses(response_type, indices, values),
        responses.item_bank, tracker, pending_start(responses))
    Speculator(speculative, size, start, responses.ability_tracker, seed)
end

function replay_speculation!(responses, tracker::AbilityTracker, start)
    track!(responses, tracker)
end
function replay_speculation!(responses, tracker::ClosedFormNormalAbilityTracker, start)
    for i in start:length(responses)
        prefix = response_view(responses.responses, 1:i)
        track!(TrackedResponses(prefix, responses.item_bank, tracker), tracker)
    end
end
function replay_speculation!(responses, tracker::ConsAbilityTracker, start)
    replay_speculation!(responses, tracker.head, start)
    replay_speculation!(responses, tracker.tail, start)
end

function refresh_speculative_tracker!(responses, parent::AbilityTracker, seed,
        tracker::AbilityTracker, start)
    fresh = deepcopy(seed)
    replay_speculation!(responses, fresh, start)
    fresh
end
function refresh_speculative_tracker!(responses,
        parent::Union{GriddedAbilityTracker, LogGridAbilityTracker, StackedGridAbilityTracker},
        ::Nothing, tracker::StackedGridAbilityTracker, start)
    track_delta!(responses, tracker)
end
function refresh_speculative_tracker!(responses, parent::ConsAbilityTracker, seed::Tuple,
        tracker::ConsAbilityTracker, start)
    ConsAbilityTracker(
        refresh_speculative_tracker!(responses, parent.head, seed[1], tracker.head, start),
        refresh_speculative_tracker!(responses, parent.tail, seed[2], tracker.tail, start))
end

function replace_speculation!(speculator::Speculator, indices, values)
    @assert length(indices) == speculator.size && length(values) == speculator.size
    history = speculator.responses.responses
    history.indices[speculator.delta_start:end] = indices
    history.values[speculator.delta_start:end] = values
    tracker = refresh_speculative_tracker!(speculator.responses,
        speculator.parent_tracker, speculator.seed,
        speculator.responses.ability_tracker, speculator.delta_start)
    speculator.responses = TrackedResponses(history, speculator.responses.item_bank,
        tracker, speculator.responses.speculation_start)
    nothing
end
