function DRuleItemCriterion(ability_estimator)
    ScalarizedItemCriteron(
        InformationMatrixCriteria(ability_estimator),
        DeterminantScalarizer())
end

function TRuleItemCriterion(ability_estimator)
    ScalarizedItemCriteron(
        InformationMatrixCriteria(ability_estimator),
        TraceScalarizer())
end
