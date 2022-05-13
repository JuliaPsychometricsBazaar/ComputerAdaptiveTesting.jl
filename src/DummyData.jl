module DummyData

using Distributions: Normal
using Faker: sentence
using Random

using ..ItemBanks: ItemBank2PL, ItemBank3PL, ItemBankMirt4PL, ItemResponse

const default_num_questions = 8000
const default_num_testees = 30
const std_normal = Normal()

function sent()
    sentence(number_words=12, variable_nb_words=true)
end

function dummy_2pl_item_bank(num_questions)
    discrim_normal = Normal(1.0, 0.2)
    difficulties = rand(std_normal, num_questions)
    discriminations = abs.(rand(discrim_normal, num_questions))
    ItemBank2PL(difficulties, discriminations)
end

function dummy_3pl_item_bank(num_questions)
    discrim_normal = Normal(1.0, 0.2)
    guess_normal = Normal(0.0, 0.2)
    difficulties = rand(std_normal, num_questions)
    discriminations = abs.(rand(discrim_normal, num_questions))
    guesses = clamp.(rand(guess_normal, num_questions), 0, 1)
    ItemBank3PL(difficulties, discriminations, guesses)
end

function dummy_mirt_4pl_item_bank(num_questions, dims)
    discrim_normal = Normal(1.0, 0.2)
    guess_normal = Normal(0.0, 0.2)
    slip_normal = Normal(0.0, 0.2)
    difficulties = rand(std_normal, num_questions)
    discriminations = abs.(rand(discrim_normal, dims, num_questions))
    guesses = clamp.(rand(guess_normal, num_questions), 0.0, 1.0)
    slips = clamp.(rand(slip_normal, num_questions), 0.0, 1.0)
    ItemBankMirt4PL(difficulties, discriminations, guesses, slips)
end

function item_bank_to_full_dummy(item_bank, num_testees)
    (item_bank, question_labels, abilities, responses) = mirt_item_bank_to_full_dummy(item_bank, num_testees, 1)
    (item_bank, question_labels, abilities[1, :], responses)
end

function mirt_item_bank_to_full_dummy(item_bank, num_testees, dims)
    num_questions = length(item_bank)
    question_labels = [sent() for _ in 1:num_questions]
    abilities = rand(std_normal, dims, num_testees)
    @inline ir(idx, ability) = ItemResponse(item_bank, idx)(ability)
    # Should be a faster way to do this without allocation
    responses = (
        rand(num_questions, num_testees)
        .< ir.(reshape(1:num_questions, (:, 1)), reshape(abilities, (1, :)))
    )
    (item_bank, question_labels, abilities, responses)
end

function dummy_2pl(;num_questions=default_num_questions, num_testees=default_num_testees)
    item_bank_to_full_dummy(dummy_2pl_item_bank(num_questions), num_testees)
end

function dummy_3pl(;num_questions=default_num_questions, num_testees=default_num_testees)
    item_bank_to_full_dummy(dummy_3pl_item_bank(num_questions), num_testees)
end

function dummy_mirt_4pl(dims; num_questions=default_num_questions, num_testees=default_num_testees)
    mirt_item_bank_to_full_dummy(dummy_mirt_4pl_item_bank(num_questions, dims), num_testees, dims)
end

end