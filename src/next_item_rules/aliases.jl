"""
This mapping provides next item rules through the same names that they are
available through in the `catR` R package. TODO compability with `mirtcat`
"""
const catr_next_item_aliases = Dict(
    "MFI" => (ability_estimator; parallel = true) -> ItemStrategyNextItemRule(
        ExhaustiveSearch1Ply(parallel),
        InformationItemCriterion(ability_estimator)),
    "bOpt" => (ability_estimator; parallel = true) -> ItemStrategyNextItemRule(
        ExhaustiveSearch1Ply(parallel),
        UrryItemCriterion(ability_estimator)),
    "MEPV" => (ability_estimator; parallel = true) -> ItemStrategyNextItemRule(
        ExhaustiveSearch1Ply(parallel),
        ExpectationBasedItemCriterion(ability_estimator,
            AbilityVarianceStateCriterion(ability_estimator)))    #"MLWI",    #"MPWI",    #"MEI",
)

#"thOpt",
#"progressive",
#"proportional",
#"KL",
#"KLP",
#"GDI",
#"GDIP",
#"random"

function _mirtcat_helper(item_criterion_callback)
    function _helper(bits...; ability_estimator = nothing)
        ability_estimator = AbilityEstimator(bits...; ability_estimator = ability_estimator)
        item_criterion = item_criterion_callback(
            [bits..., ability_estimator], ability_estimator)
        return ItemStrategyNextItemRule(ExhaustiveSearch1Ply(), item_criterion)
    end
    return _helper
end

const mirtcat_next_item_aliases = Dict(
    # "MI' for the maximum information
    "MI" => _mirtcat_helper((bits, ability_estimator) -> InformationItemCriterion(ability_estimator)),
    # 'MEPV' for minimum expected posterior variance
    "MEPV" => _mirtcat_helper((bits, ability_estimator) -> ExpectationBasedItemCriterion(
        ability_estimator,
        AbilityVarianceStateCriterion(bits...)))
)

# 'MLWI' for maximum likelihood weighted information
#"MLWI" => _mirtcat_helper((bits, ability_estimator) -> InformationItemCriterion(ability_estimator))
# 'MPWI' for maximum posterior weighted information
# 'MEI' for maximum expected information
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

const mirtcat_ability_estimator_aliases = Dict(
# "MAP" for the maximum a-posteriori (i.e, Bayes modal)
# "ML" for maximum likelihood
# "WLE" for weighted likelihood estimation
# "EAPsum" for the expected a-posteriori for each sum score
# "EAP" for the expected a-posteriori (default).
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
