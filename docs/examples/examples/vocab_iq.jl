# ---
# title: Running a CAT based based on real response data
# id: vocab_iq
# execute: false
# ---

#md # Running a CAT based based on real response data
#
# This example shows how to run a CAT end-to-end on real data.
#
# First a 1-dimensional IRT model is fitted based on open response data to the
# vocabulary IQ test using the IRTSupport package which internally, this uses
# the `mirt` R package. Next, the model is used to administer the test
# interactively.

using Base.Filesystem
using ComputerAdaptiveTesting
using FittedItemBanks.DummyData: std_normal
using ComputerAdaptiveTesting.Sim
using ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting.TerminationConditions
using ComputerAdaptiveTesting.Aggregators
using FittedItemBanks
using FittedItemBanks: item_params
import PsychometricsBazaarBase.IntegralCoeffs
using PsychometricsBazaarBase.Integrators
using PsychometricsBazaarBase.Optimizers
using ItemResponseDatasets: prompt_readline
using ItemResponseDatasets.VocabIQ
using RIrtWrappers.Mirt

function get_item_bank()
    fit_4pl(get_marked_df_cached(); TOL = 1e-2)
end

function run_vocab_iq_cat()
    item_bank, labels = get_item_bank()
    integrator = FixedGKIntegrator(-6, 6, 61)
    ability_integrator = AbilityIntegrator(integrator)
    dist_ability_est = PosteriorAbilityEstimator(std_normal)
    optimizer = AbilityOptimizer(OneDimOptimOptimizer(-6.0, 6.0, NelderMead()))
    ability_estimator = ModeAbilityEstimator(dist_ability_est, optimizer)
    @info "run_cat" ability_estimator
    rules = CatRules(ability_estimator,
        AbilityVariance(dist_ability_est, ability_integrator),
        FixedLength(45))
    function get_response(response_idx, response_name)
        params = item_params(item_bank, response_idx)
        println("Parameters for next question: $params")
        prompt_readline(VocabIQ.questions[response_idx])
    end
    function new_response_callback(tracked_responses, terminating)
        if tracked_responses.responses.values[end] > 0
            println("Correct")
        else
            println("Wrong")
        end
        ability = ability_estimator(tracked_responses)
        var = variance_given_mean(ability_integrator,
            dist_ability_est,
            tracked_responses,
            ability)
        println("Got ability estimate: $ability ± $var")
        println("")
    end
    loop_config = CatLoop(rules = rules,
        get_response = get_response,
        new_response_callback = new_response_callback)
    run_cat(loop_config, item_bank)
end

run_vocab_iq_cat()
