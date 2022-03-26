using NLSolversBase
using ForwardDiff
using Optim

@from "../utils.jl" import get_full_responses

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