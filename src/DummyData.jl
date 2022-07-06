module DummyData

using Distributions: Normal, MvNormal, ZeroMeanIsoNormal, Zeros, ScalMat
using Faker: sentence
using Random
using StatsBase: sample

using ..Responses: BareResponses
using ..ItemBanks: AbstractItemBank, ItemBank2PL, ItemBank3PL, ItemBankMirt4PL, ItemResponse
using ..Aggregators: NullAbilityTracker, TrackedResponses

const default_num_questions = 8000
const default_num_testees = 30
const std_normal = Normal()

function std_mv_normal(dim)
    MvNormal(Zeros(dim), ScalMat(dim, 1.0))
end

function sent()
    sentence(number_words=12, variable_nb_words=true)
end

function dummy_2pl_item_bank(rng, num_questions)
    discrim_normal = Normal(1.0, 0.2)
    difficulties = rand(rng, std_normal, num_questions)
    discriminations = abs.(rand(rng, discrim_normal, num_questions))
    ItemBank2PL(difficulties, discriminations)
end
dummy_2pl_item_bank(num_questions) = dummy_2pl_item_bank(Random.default_rng(), num_questions)

function dummy_3pl_item_bank(rng, num_questions)
    discrim_normal = Normal(1.0, 0.2)
    guess_normal = Normal(0.0, 0.2)
    difficulties = rand(rng, std_normal, num_questions)
    discriminations = abs.(rand(rng, discrim_normal, num_questions))
    guesses = clamp.(rand(rng, guess_normal, num_questions), 0, 1)
    ItemBank3PL(difficulties, discriminations, guesses)
end
dummy_3pl_item_bank(num_questions) = dummy_3pl_item_bank(Random.default_rng(), num_questions)

function dummy_mirt_4pl_item_bank(rng, num_questions, dims)
    discrim_normal = Normal(1.0, 0.2)
    guess_normal = Normal(0.0, 0.2)
    slip_normal = Normal(0.0, 0.2)
    difficulties = rand(rng, std_normal, num_questions)
    discriminations = abs.(rand(rng, discrim_normal, dims, num_questions))
    guesses = clamp.(rand(rng, guess_normal, num_questions), 0.0, 1.0)
    slips = clamp.(rand(rng, slip_normal, num_questions), 0.0, 1.0)
    ItemBankMirt4PL(difficulties, discriminations, guesses, slips)
end
dummy_mirt_4pl_item_bank(num_questions, dims) = dummy_mirt_4pl_item_bank(Random.default_rng(), num_questions, dims)

function item_bank_to_full_dummy(rng, item_bank, num_testees)
    (item_bank, question_labels, abilities, responses) = mirt_item_bank_to_full_dummy(rng, item_bank, num_testees, 1; squeeze=true)
    (item_bank, question_labels, abilities[1, :], responses)
end

function mirt_item_bank_to_full_dummy(rng, item_bank, num_testees, dims; squeeze=false)
    num_questions = length(item_bank)
    question_labels = [sent() for _ in 1:num_questions]
    abilities = rand(rng, std_normal, dims, num_testees)
    irs = zeros(num_questions, num_testees)
    for question_idx in 1:num_questions
        for testee_idx in 1:num_testees
            if squeeze
                ability = abilities[1, testee_idx]
            else
                ability = abilities[:, testee_idx]
            end
            irs[question_idx, testee_idx] = ItemResponse(item_bank, question_idx)(ability)
        end
    end
    responses = rand(rng, num_questions, num_testees) .< irs
    (item_bank, question_labels, abilities, responses)
end

function dummy_2pl(rng, ;num_questions=default_num_questions, num_testees=default_num_testees)
    item_bank_to_full_dummy(rng, dummy_2pl_item_bank(rng, num_questions), num_testees)
end
dummy_2pl(; kwargs...) = dummy_2pl(Random.default_rng(); kwargs...)

function dummy_3pl(rng ;num_questions=default_num_questions, num_testees=default_num_testees)
    item_bank_to_full_dummy(rng, dummy_3pl_item_bank(rng, num_questions), num_testees)
end
dummy_3pl(; kwargs...) = dummy_3pl(Random.default_rng(); kwargs...)

function dummy_mirt_4pl(rng, dims; num_questions=default_num_questions, num_testees=default_num_testees)
    mirt_item_bank_to_full_dummy(rng, dummy_mirt_4pl_item_bank(rng, num_questions, dims), num_testees, dims)
end
dummy_mirt_4pl(dims; kwargs...) = dummy_mirt_4pl(Random.default_rng(), dims; kwargs...)

function dummy_responses(item_bank::AbstractItemBank, actual_responses, question_idxs::AbstractVector)
    response_values = Int8.(actual_responses[question_idxs])
    TrackedResponses(
        BareResponses(question_idxs, response_values),
        item_bank,
        NullAbilityTracker()
    )
end

function dummy_responses(rng::AbstractRNG, item_bank, actual_responses, num_questions::Integer)
    dummy_responses(item_bank, actual_responses, sample(rng, 1:length(actual_responses), num_questions; replace=false))
end
dummy_responses(item_bank::AbstractItemBank, actual_responses, num_questions::Integer) = dummy_responses(Random.default_rng(), item_bank, actual_responses, num_questions)

function dummy_responses(rng::AbstractRNG, item_bank, actual_responses)
    dummy_responses(rng, item_bank, actual_responses, round(Int, rand(rng) * length(actual_responses)))
end
dummy_responses(item_bank::AbstractItemBank, actual_responses) = dummy_responses(Random.default_rng(), item_bank, actual_responses)

end