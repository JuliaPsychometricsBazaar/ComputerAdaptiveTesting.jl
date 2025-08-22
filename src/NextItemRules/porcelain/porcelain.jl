function DRuleItemCriterion(ability_estimator)
    ScalarizedItemCriterion(
        InformationMatrixCriteria(ability_estimator),
        DeterminantScalarizer())
end

function TRuleItemCriterion(ability_estimator)
    ScalarizedItemCriterion(
        InformationMatrixCriteria(ability_estimator),
        TraceScalarizer())
end
