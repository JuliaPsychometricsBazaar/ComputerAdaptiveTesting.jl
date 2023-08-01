using Base.Filesystem
using ComputerAdaptiveTesting
using FittedItemBanks
using PsychometricsBazaarBase.ConstDistributions
using ComputerAdaptiveTesting.Sim
using ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting.TerminationConditions
using ComputerAdaptiveTesting.Aggregators
using PsychometricsBazaarBase.Integrators
using PsychometricsBazaarBase.Optimizers
import PsychometricsBazaarBase.IntegralCoeffs
using CATPlots
using ItemResponseDatasets: prompt_readline
using ItemResponseDatasets.VocabIQ
using RIrtWrappers.KernSmoothIRT
using GLMakie


function main()
    df = get_marked_df_cached()
    item_bank = fit_ks_dichotomous(df)[1]
    @info "ksirt" item_bank
    integrator = FixedGKIntegrator(-6, 6, 61)
    ability_integrator = AbilityIntegrator(integrator)
    optimizer = AbilityOptimizer(OneDimOptimOptimizer(-6.0, 6.0, NelderMead()))
    prior_ability_est = PriorAbilityEstimator(std_normal)
    ability_estimator = ModeAbilityEstimator(prior_ability_est, optimizer)
    rules = CatRules(
        ability_estimator,
        AbilityVarianceStateCriterion(prior_ability_est, ability_integrator),
        FixedItemsTerminationCondition(45)
    )
    function get_response(response_idx, response_name)
        prompt_readline(VocabIQ.questions[response_idx])
    end
    function new_response_callback(tracked_responses, terminating)
        if tracked_responses.responses.values[end] > 0
            println("Correct")
        else
            println("Wrong")
        end
        ability = ability_estimator(tracked_responses)
        var = variance_given_mean(ability_integrator, prior_ability_est, tracked_responses, ability)
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


main()