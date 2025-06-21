module MirtCAT

using ComputerAdaptiveTesting.Aggregators: SafeLikelihoodAbilityEstimator,
                                           LikelihoodAbilityEstimator,
                                           DistributionAbilityEstimator,
                                           ModeAbilityEstimator,
                                           MeanAbilityEstimator,
                                           PosteriorAbilityEstimator,
                                           AbilityEstimator,
                                           distribution_estimator
using ComputerAdaptiveTesting.TerminationConditions: RunForeverTerminationCondition
using ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting: CatRules
using PsychometricsBazaarBase: Integrators, Optimizers

public next_item_aliases, ability_estimator_aliases, assemble_rules

function _next_item_helper(item_criterion_callback)
    function _helper(ability_estimator, posterior_ability_estimator, integrator, optimizer)
        bits = [
            ability_estimator,
            integrator,
            optimizer,
        ]
        item_criterion = item_criterion_callback(; bits, ability_estimator, posterior_ability_estimator, integrator, optimizer)
        return ItemStrategyNextItemRule(ExhaustiveSearch(), item_criterion)
    end
    return _helper
end

const next_item_aliases = Dict(
    # "MI' for the maximum information
    "MI" => _next_item_helper((; bits, ability_estimator, rest...) -> InformationItemCriterion(ability_estimator)),
    # 'MEPV' for minimum expected posterior variance
    "MEPV" => _next_item_helper((; bits, ability_estimator, posterior_ability_estimator, integrator, rest...) -> ExpectationBasedItemCriterion(
        ability_estimator,
        AbilityVarianceStateCriterion(posterior_ability_estimator, integrator))),
    "MEI" => _next_item_helper((; bits, ability_estimator, rest...) -> ExpectationBasedItemCriterion(
        ability_estimator,
        PointItemCategoryCriterion(EmpiricalInformationPointwiseItemCategoryCriterion(), ability_estimator)
    )),
    "MLWI" => _next_item_helper((; bits, ability_estimator, integrator, rest...) -> LikelihoodWeightedItemCriterion(
        TotalItemInformation(RawEmpiricalInformationPointwiseItemCategoryCriterion()),
        distribution_estimator(ability_estimator),
        integrator
    )),
    "MPWI" => _next_item_helper((; bits, ability_estimator, posterior_ability_estimator, integrator, rest...) -> LikelihoodWeightedItemCriterion(
        TotalItemInformation(RawEmpiricalInformationPointwiseItemCategoryCriterion()),
        distribution_estimator(posterior_ability_estimator),
        integrator
    )),
    "Drule" => _next_item_helper((; bits, ability_estimator, rest...) -> DRuleItemCriterion(ability_estimator)),
    "Trule" => _next_item_helper((; bits, ability_estimator, rest...) -> TRuleItemCriterion(ability_estimator))
)

# 'IKLP' as well as 'IKL' for the integration based Kullback-Leibler criteria with and without the prior density weight,
# respectively, and their root-n items administered weighted counter-parts, 'IKLn' and 'IKLPn'.
#=
Possible inputs for multidimensional adaptive tests include: 'Drule' for the
maximum determinant of the information matrix, 'Trule' for the maximum
(potentially weighted) trace of the information matrix, 'Arule' for the minimum (potentially weighted) trace of the asymptotic covariance matrix, 'Erule'
for the minimum value of the information matrix, and 'Wrule' for the weighted
information criteria. For each of these rules, the posterior weight for the latent trait scores can also be included with the 'DPrule', 'TPrule', 'APrule',
'EPrule', and 'WPrule', respectively.
Applicable to both unidimensional and multidimensional tests are the 'KL' and
'KLn' for point-wise Kullback-Leibler divergence and point-wise KullbackLeibler with a decreasing delta value (delta*sqrt(n), where n is the number
of items previous answered), respectively. The delta criteria is defined in the
design object
Non-adaptive methods applicable even when no mo object is passed are: 'random'
to randomly select items, and 'seq' for selecting items sequentially
=#

const ability_estimator_aliases = Dict(
    "MAP" => (; optimizer, ncomp, kwargs...) -> ModeAbilityEstimator(PosteriorAbilityEstimator(; ncomp=ncomp), optimizer),
    "ML" => (; optimizer, ncomp, kwargs...) -> ModeAbilityEstimator(SafeLikelihoodAbilityEstimator(; ncomp=ncomp), optimizer),
    "EAP" => (; integrator, ncomp, kwargs...) -> MeanAbilityEstimator(PosteriorAbilityEstimator(; ncomp=ncomp), integrator),
# "WLE" for weighted likelihood estimation
# "EAPsum" for the expected a-posteriori for each sum score
)

#=
• "plausible" for a single plausible value imputation for each case. This is
equivalent to setting plausible.draws = 1
• "classify" for the posteriori classification probabilities (only applicable
when the input model was of class MixtureClass)
=#

function mirtcat_quadpts(nfact)
    if nfact == 1
        return 121
    elseif nfact == 2
        return 61
    elseif nfact == 3
        return 31
    elseif nfact == 4
        return 19
    elseif nfact == 5
        return 11
    else
        return 5
    end
end

function setup_integrator(lo=-6.0, hi=6.0, pts=mirtcat_quadpts(1))
    Integrators.even_grid(lo, hi, pts)
end

function setup_optimizer(lo=-6.0, hi=6.0)
    # TODO: Is this correct?
    # mirtcat uses the `nlm` function from the `stats` package
    # Source: https://github.com/philchalmers/mirt/blob/46b5db3a0120d87b8f1b034e6111fc5fb352a698/R/fscores.internal.R#L957C25-L957C28
    # It looks like no gradient is passed, so the numerical gradient will be used
    # Source: https://github.com/philchalmers/mirt/blob/46b5db3a0120d87b8f1b034e6111fc5fb352a698/R/fscores.internal.R#L623
    # This is what we get by default so do this
    # Main difference is probably in the line search
    # https://stats.stackexchange.com/questions/272880/algorithm-used-in-nlm-function-in-r
    # So just use Newton() with defaults for now
    # Except then we can't have box constraints so I suppose IPNewton
    if lo isa AbstractVector && hi isa AbstractVector
        Optimizers.MultiDimOptimOptimizer(lo, hi, Optimizers.IPNewton())
    else
        Optimizers.OneDimOptimOptimizer(lo, hi, Optimizers.IPNewton())
    end
end

function assemble_rules(;
    criteria = "MI",
    method = "MAP",
    start_item = 1,
    ncomp = 0
)
    if ncomp == 0
        lo = -6.0
        hi = 6.0
        pts = mirtcat_quadpts(1)
        theta_lim = 20.0
    else
        lo = fill(-6.0, ncomp)
        hi = fill(6.0, ncomp)
        pts = mirtcat_quadpts(ncomp)
        theta_lim = fill(20.0, ncomp)
    end
    integrator = setup_integrator(lo, hi, pts)
    optimizer = setup_optimizer(-theta_lim, theta_lim)
    ability_estimator = ability_estimator_aliases[method](; integrator, optimizer, ncomp)
    posterior_ability_estimator = PosteriorAbilityEstimator(; ncomp)
    raw_next_item = next_item_aliases[criteria](ability_estimator, posterior_ability_estimator, integrator, optimizer)
    next_item = FixedFirstItemNextItemRule(start_item, raw_next_item)
    CatRules(;
        next_item,
        ability_estimator,
        termination_condition = RunForeverTerminationCondition(),
    )
end

end
