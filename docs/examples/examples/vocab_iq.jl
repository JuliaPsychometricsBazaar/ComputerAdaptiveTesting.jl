#md # How abilities converge on simulated 3PL data

# # Running a CAT based based on real reponse data
# 
# This example shows how to run a CAT end-to-end on real data.
# 
# First a 1-dimensional IRT model is fitted based on open response data to the
# vocabulary IQ test using the IRTSupport package which internally, this uses
# the `mirt` R package. Next, the model is used to administer the test
# interactively.

ENV["R_HOME"] = "*"

using Base.Filesystem
using ComputerAdaptiveTesting
using ComputerAdaptiveTesting.DummyData: std_normal
using ComputerAdaptiveTesting.ExtraDistributions
using ComputerAdaptiveTesting.Sim
using ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting.TerminationConditions
using ComputerAdaptiveTesting.Aggregators
using ComputerAdaptiveTesting.ItemBanks
using ComputerAdaptiveTesting.Integrators
using ComputerAdaptiveTesting.Optimizers
import ComputerAdaptiveTesting.IntegralCoeffs
using IRTSupport.VocabIQ

function run_vocab_iq_cat()
    item_bank = get_item_bank_cached(answers)
    integrator = FixedGKIntegrator(-6, 6, 61)
    ability_integrator = AbilityIntegrator(integrator)
    dist_ability_est = PriorAbilityEstimator(std_normal)
    optimizer = AbilityOptimizer(OneDimOptimOptimizer(-6.0, 6.0, NelderMead()))
    ability_estimator = ModeAbilityEstimator(dist_ability_est, optimizer)
    @info "run_cat" ability_estimator 
    rules = CatRules(
        ability_estimator,
        AbilityVarianceStateCriterion(dist_ability_est, ability_integrator),
        FixedItemsTerminationCondition(45)
    )
    function get_response(response_idx, response_name)
        params = item_params(item_bank, response_idx)
        println("Parameters for next question: $params")
        options = potential_answers[response_idx, :]
        options_fmt = join(options, "/")

        function get_word(idx)
            while true
                print("Which two of $options_fmt have the same meaning $idx/2 (blank = do not know) > ")
                word = readline()
                if strip(word) == ""
                    return nothing
                end
                if word in options
                    return word
                end
                println("Could not find $word in $options_fmt")
            end
        end
        word1 = get_word(1)
        word2 = get_word(2)
        if word1 === nothing || word2 === nothing
            return 0
        end
        return Set([word1, word2]) == Set(gold_answers[response_idx, :]) ? 1 : 0
    end
    function new_response_callback(tracked_responses, terminating)
        if tracked_responses.responses.values[end] > 0
            println("Correct")
        else
            println("Wrong")
        end
        ability = ability_estimator(tracked_responses)
        var = variance_given_mean(ability_integrator, dist_ability_est, tracked_responses, ability)
        println("Got ability estimate: $ability ± $var")
        println("")
    end
    loop_config = CatLoopConfig(
        rules=rules,
        get_response=get_response,
        new_response_callback=new_response_callback
    )
    run_cat(loop_config, item_bank)
end

run_vocab_iq_cat()