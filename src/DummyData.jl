module DummyData

using Reexport, FromFile
using Distributions: Normal
using Faker: sentence
using Random

@from "./item_banks/ItemBanks.jl" using ItemBanks: ItemBank3PL, ItemResponse

const DEFAULT_NUM_QUESTIONS = 8000
const DEFAULT_NUM_TESTEES = 30
const STD_NORMAL = Normal()

function sent()
    sentence(number_words=12, variable_nb_words=true)
end

function dummy_3pl_item_bank(num_questions)
    discrim_normal = Normal(1.0, 0.2)
    guess_normal = Normal(0.0, 0.2)
    difficulties = rand(STD_NORMAL, num_questions)
    discriminations = abs.(rand(discrim_normal, num_questions))
    guesses = clamp.(rand(guess_normal, num_questions), 0, 1)
    ItemBank3PL(difficulties, discriminations, guesses)
end

function dummy_3pl(;num_questions=DEFAULT_NUM_QUESTIONS, num_testees=DEFAULT_NUM_TESTEES)
    item_bank = dummy_3pl_item_bank(num_questions)
    question_labels = [sent() for _ in 1:num_questions]
    abilities = rand(STD_NORMAL, num_testees)
    @inline ir(idx, ability) = ItemResponse(item_bank, idx)(ability)
    # Should be a faster way to do this without allocation
    responses = (
        randn(num_questions, num_testees)
        .< ir.(reshape(1:length(item_bank), (:, 1)), reshape(abilities, (1, :)))
    )
    (item_bank, question_labels, abilities, responses)
end

end