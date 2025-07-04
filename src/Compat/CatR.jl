module CatR

using ComputerAdaptiveTesting.Aggregators: AbilityIntegrator,
                                           LikelihoodAbilityEstimator,
                                           DistributionAbilityEstimator,
                                           ModeAbilityEstimator,
                                           MeanAbilityEstimator,
                                           PosteriorAbilityEstimator
using ComputerAdaptiveTesting.TerminationConditions: RunForever
using ComputerAdaptiveTesting.Rules: CatRules
using ComputerAdaptiveTesting.NextItemRules
using PsychometricsBazaarBase: Integrators, Optimizers

public next_item_aliases, ability_estimator_aliases, assemble_rules

function _next_item_aliases()
    res = Dict{String, Any}()
    for (nick, mk_item_criterion) in (
        "MFI" => InformationItemCriterion,
        "bOpt" => UrryItemCriterion,
    )
        res[nick] = (bits...; kwargs...) -> ItemCriterionRule(
            ExhaustiveSearch(),
            mk_item_criterion(bits...))
    end
    res["MEPV"] = (bits...; posterior_ability_estimator, kwargs...) -> ItemCriterionRule(
        ExhaustiveSearch(),
        ExpectationBasedItemCriterion(bits...,
            AbilityVariance(posterior_ability_estimator, AbilityIntegrator(bits...))))
    res["MEI"] = (bits...; kwargs...) -> ItemCriterionRule(
        ExhaustiveSearch(),
        ExpectationBasedItemCriterion(bits...,
            InformationItemCriterion(bits...)))
    #"MLWI",    #"MPWI",
    return res
    #"thOpt",
    #"progressive",
    #"proportional",
    #"KL",
    #"KLP",
    #"GDI",
    #"GDIP",
    #"random"
end

"""
This mapping provides next item rules through the same names that they are
available through in the `catR` R package. TODO compability with `mirtcat`
"""
const next_item_aliases = _next_item_aliases()

function _ability_estimator_aliases()
    res = Dict{String, Any}()
    res["BM"] = (; optimizer, kwargs...) -> ModeAbilityEstimator(PosteriorAbilityEstimator(), optimizer)
    res["ML"] = (; optimizer, kwargs...) -> ModeAbilityEstimator(LikelihoodAbilityEstimator(), optimizer)
    res["EAP"] = (; integrator, kwargs...) -> MeanAbilityEstimator(PosteriorAbilityEstimator(), integrator)
    #res["WL"]
    #res["ROB"]
    return res
end

const ability_estimator_aliases = _ability_estimator_aliases()

#=
        for (resp_exp, resp_exp_nick) in resp_exp_nick_pairs
            next_item_rule = NextItemRule(
                ExpectationBasedItemCriterion(resp_exp, AbilityVariance(numtools.integrator, distribution_estimator(abil_est)))
            )
            next_item_rule = preallocate(next_item_rule)
            est_next_item_rule_pairs[Symbol("$(abil_est_str)_mepv_$(resp_exp_nick)")] = (abil_est, next_item_rule)
            next_item_rule = NextItemRule(
                ExpectationBasedItemCriterion(resp_exp, InformationItemCriterion(abil_est))
            )
            next_item_rule = preallocate(next_item_rule)
            est_next_item_rule_pairs[Symbol("$(abil_est_str)_mei_$(resp_exp_nick)")] = (abil_est, next_item_rule)
        end
        est_next_item_rule_pairs[Symbol("$(abil_est_str)_mi")] = (abil_est, InformationItemCriterion(abil_est))
=#


function setup_integrator(lo=-4.0, hi=4.0, pts=33)
    Integrators.MidpointIntegrator(range(lo, hi, pts))
end

function setup_optimizer(lo=-4.0, hi=4.0)
    Optimizers.NativeOneDimOptimOptimizer(; lo, hi)
end

function assemble_rules(;
    criterion,
    method,
    start_item = 1
    #prior_dist="norm",
    #prior_par=@SVector[0.0, 1.0],
    #info_type="observed"
)
    integrator = setup_integrator()
    optimizer = setup_optimizer()
    ability_estimator = ability_estimator_aliases[method](; integrator, optimizer)
    posterior_ability_estimator = PosteriorAbilityEstimator()
    raw_next_item = next_item_aliases[criterion](ability_estimator, integrator, optimizer; posterior_ability_estimator=posterior_ability_estimator)
    next_item = FixedFirstItem(start_item, raw_next_item)
    CatRules(;
        next_item,
        termination_condition = RunForever(),
        ability_estimator,
        #ability_tracker::AbilityTrackerT = NullAbilityTracker()
    )
end

end
