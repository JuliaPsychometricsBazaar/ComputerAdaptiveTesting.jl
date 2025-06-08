module Dummy

using ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting.Aggregators
using ComputerAdaptiveTesting.Responses
using FittedItemBanks.DummyData: dummy_full, SimpleItemBankSpec, StdModel3PL,
                                 VectorContinuousDomain, BooleanResponse, std_normal,
                                 OneDimContinuousDomain
using PsychometricsBazaarBase.Integrators
using PsychometricsBazaarBase.Optimizers
using Optim
using Random

struct DummyAbilityEstimator <: AbilityEstimator
    val::Any
end

function (est::DummyAbilityEstimator)(_::TrackedResponses)
    est.val
end

const optimizers_1d = [
    FunctionOptimizer(OneDimOptimOptimizer(-6.0, 6.0, NelderMead()))
]
const integrators_1d = [
    FunctionIntegrator(QuadGKIntegrator(lo=-6.0, hi=6.0, order=5)),
    FunctionIntegrator(FixedGKIntegrator(-6, 6, 80))
]
const ability_estimators_1d = [
    ((:integrator,),
        (stuff) -> MeanAbilityEstimator(PriorAbilityEstimator(std_normal), stuff.integrator)),
    ((:optimizer,),
        (stuff) -> ModeAbilityEstimator(PriorAbilityEstimator(std_normal), stuff.optimizer)),
    ((:integrator,),
        (stuff) -> MeanAbilityEstimator(LikelihoodAbilityEstimator(), stuff.integrator)),
    ((:optimizer,),
        (stuff) -> ModeAbilityEstimator(LikelihoodAbilityEstimator(), stuff.optimizer))
]
const criteria_1d = [
    ((:integrator, :est),
        (stuff) -> AbilityVarianceStateCriterion(
            distribution_estimator(stuff.est), stuff.integrator)),
    ((:est,), (stuff) -> InformationItemCriterion(stuff.est)),
    ((:est,), (stuff) -> UrryItemCriterion(stuff.est)),
    ((), (stuff) -> RandomNextItemRule())
]

function _get_stuffs(needed)
    if :est in needed
        return (
            (; stuff..., est = mk_est(stuff))
            for (extra_needed, mk_est) in ability_estimators_1d
            for stuff in _get_stuffs(setdiff(needed, Set((:est,))) ∪ extra_needed)
        )
    end
    if :integrator in needed
        return (
            (; stuff..., integrator = new_integrator)
            for new_integrator in integrators_1d
            for stuff in _get_stuffs(setdiff(needed, Set((:integrator,))))
        )
    end
    if :optimizer in needed
        return (
            (; stuff..., optimizer = new_optimizer)
            for new_optimizer in optimizers_1d
            for stuff in _get_stuffs(setdiff(needed, Set((:optimizer,))))
        )
    end
    return [NamedTuple()]
end

function get_stuffs(needed)
    if !(:est in needed)
        return (
            (; stuff..., est = DummyAbilityEstimator(0.0))
            for stuff in _get_stuffs(needed)
        )
    else
        return _get_stuffs(needed)
    end
end

end
