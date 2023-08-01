using Base.Filesystem
using ComputerAdaptiveTesting
using FittedItemBanks.DummyData: std_normal
using ComputerAdaptiveTesting.Sim
using ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting.TerminationConditions
using ComputerAdaptiveTesting.Aggregators
using FittedItemBanks
using PsychometricsBazaarBase.Integrators
using PsychometricsBazaarBase.Optimizers
import PsychometricsBazaarBase.IntegralCoeffs
using CATPlots
using ItemResponseDatasets: prompt_readline
using ItemResponseDatasets.VocabIQ
using GLMakie
using RIrtWrappers.Mirt


function get_item_bank()
    fit_4pl(get_marked_df_cached(); TOL=1e-2)[1]
end


function main()
    item_bank = get_item_bank()
    integrator = FixedGKIntegrator(-6, 6, 61)
    ability_integrator = AbilityIntegrator(integrator)
    lh_ability_est = LikelihoodAbilityEstimator()
    prior_ability_est = PriorAbilityEstimator(std_normal)
    optimizer = AbilityOptimizer(OneDimOptimOptimizer(-6.0, 6.0, NelderMead()))
    ability_estimator = ModeAbilityEstimator(prior_ability_est, optimizer)
    grid = -3:0.1:3
    lh_grid_tracker = GriddedAbilityTracker(lh_ability_est, grid)
    prior_grid_tracker = GriddedAbilityTracker(prior_ability_est, grid)
    closed_normal_tracker = ClosedFormNormalAbilityTracker(prior_ability_est)
    #laplace_normal_tracker = LaplaceAbilityTracker(prior_ability_est)
    rules = CatRules(
        MultiAbilityTracker([
            lh_grid_tracker,
            prior_grid_tracker,
            closed_normal_tracker 
        ]),
        ability_estimator,
        AbilityVarianceStateCriterion(prior_ability_est, ability_integrator),
        FixedItemsTerminationCondition(45)
    )
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
        var = variance_given_mean(ability_integrator, prior_ability_est, tracked_responses, ability)
        println("Got ability estimate: $ability ± $var")
        fig = plot_likelihoods(
            [
                ("Likelihood", lh_ability_est),
                ("Prior", prior_ability_est),
                ("Mode", ability_estimator),
                ("Likelihood grid", lh_grid_tracker),
                ("Prior grid", prior_grid_tracker),
                ("Closed normal (Owen 1975)", closed_normal_tracker)
            ],
            tracked_responses,
            ability_integrator,
            -6:0.01:6,
        )
        display(GLMakie.Screen(), fig)
        println("Press enter to continue")
        readline()
    end
    loop_config = CatLoopConfig(
        rules=rules,
        get_response=get_response,
        new_response_callback=new_response_callback
    )
    run_cat(loop_config, item_bank)
end


main()
