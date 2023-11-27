"""
This mapping provides next item rules through the same names that they are
available through in the `catR` R package. TODO compability with `mirtcat`
"""
const catr_next_item_aliases = Dict("MFI" => (ability_estimator; parallel = true) -> ItemStrategyNextItemRule(ExhaustiveSearch1Ply(parallel),
        InformationItemCriterion(ability_estimator)),
    "bOpt" => (ability_estimator; parallel = true) -> ItemStrategyNextItemRule(ExhaustiveSearch1Ply(parallel),
        UrryItemCriterion(ability_estimator)),
    #"thOpt",
    #"MLWI",
    #"MPWI",
    #"MEI",
    "MEPV" => (ability_estimator; parallel = true) -> ItemStrategyNextItemRule(ExhaustiveSearch1Ply(parallel),
        ExpectationBasedItemCriterion(ability_estimator,
            AbilityVarianceStateCriterion(ability_estimator)))
    #"progressive",
    #"proportional",
    #"KL",
    #"KLP",
    #"GDI",
    #"GDIP",
    #"random"
)
