
function NextItemRule(bits...;
        ability_estimator = nothing,
        ability_tracker = nothing,
        parallel = true)
    @returnsome find1_instance(NextItemRule, bits)
    @returnsome ItemStrategyNextItemRule(bits...,
        ability_estimator = ability_estimator,
        ability_tracker = ability_tracker,
        parallel = parallel)
end
