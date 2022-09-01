using Optim

function prepare_responses(item_bank, response_data)
    responses_df = DataFrame(read_parquet(response_data))
    item_bank = subset_item_bank(item_bank, responses_df[!, :word])
    responses_df[!, :knows] = responses_df[!, :score] .>= 5
    (item_bank, responses_df)
end

function get_full_responses(item_bank, df)
    responses = Response[]
    ib_labels = labels(item_bank)
    sizehint!(responses, length(ib_labels))
    for (idx, word) in enumerate(ib_labels)
        knows = df[df[!, :word] .== word, :knows][1]
        push!(responses, Response(idx, knows))
    end
    responses
end

function loglik(item_bank, responses_df)
    function(θ, guess, slip)
        guess_slip_ib = GuessSlipItemBank(guess, slip, item_bank)
        abil_lh_given_resps(responses_df, guess_slip_ib, θ)
    end
end

function fit_slip_distract(item_bank, response_data)
    item_bank, responses_df = prepare_responses(item_bank, response_data)
    for respondent_df in groupby(responses_df, :respondent)
        full_responses = get_full_responses(item_bank, respondent_df)
        optimize(loglik(item_bank, responses_df), [7 0.1 0.1])
    end
end
