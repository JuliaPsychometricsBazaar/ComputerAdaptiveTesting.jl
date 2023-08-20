module Dummy

using Accessors
using ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting.Aggregators
using ComputerAdaptiveTesting.Responses
using FittedItemBanks.DummyData: dummy_full, SimpleItemBankSpec, StdModel3PL,
      VectorContinuousDomain, BooleanResponse, std_normal, OneDimContinuousDomain
using PsychometricsBazaarBase.Integrators
using PsychometricsBazaarBase.Optimizers
using Optim
using Random
using ResumableFunctions

struct DummyAbilityEstimator <: AbilityEstimator
    val
end

function (est::DummyAbilityEstimator)(_::TrackedResponses)
    est.val
end

const optimizers_1d = [
    FunctionOptimizer(OneDimOptimOptimizer(-6.0, 6.0, NelderMead())),
]
const integrators_1d = [
    FunctionIntegrator(QuadGKIntegrator(-6, 6, 5)),
    FunctionIntegrator(FixedGKIntegrator(-6, 6, 80)),
]
const ability_estimators_1d = [
    ((:integrator,), (stuff) -> MeanAbilityEstimator(PriorAbilityEstimator(std_normal), stuff.integrator)),
    ((:optimizer,), (stuff) -> ModeAbilityEstimator(PriorAbilityEstimator(std_normal), stuff.optimizer)),
    ((:integrator,), (stuff) -> MeanAbilityEstimator(LikelihoodAbilityEstimator(), stuff.integrator)),
    ((:optimizer,), (stuff) -> ModeAbilityEstimator(LikelihoodAbilityEstimator(), stuff.optimizer)),
]
const criteria_1d = [
    ((:integrator, :est), (stuff) -> AbilityVarianceStateCriterion(distribution_estimator(stuff.est), stuff.integrator),),
    ((:est,), (stuff) -> InformationItemCriterion(stuff.est),),
    ((:est,), (stuff) -> UrryItemCriterion(stuff.est),),
    ((), (stuff) -> RandomNextItemRule()),
]

@resumable function _get_stuffs(needed)
    @info "begin get_stuffs" needed
    if :est in needed
        @info "est in needed"
        for (extra_needed, mk_est) in ability_estimators_1d
            for stuff in _get_stuffs(setdiff(needed, Set((:est,))) ∪ extra_needed)
                @info "mk_stuff" extra_needed stuff
                x = (; stuff..., est=mk_est(stuff))
                @info "est" needed x
                @yield x
            end
        end
        return
    end
    if :integrator in needed
        @info "integrator in needed"
        for new_integrator in integrators_1d
            for stuff in _get_stuffs(setdiff(needed, Set((:integrator,))))
                x = (; stuff..., integrator=new_integrator)
                @info "integrator" needed x
                @yield x
            end
        end
        return
    end
    if :optimizer in needed
        @info "optimizer in needed"
        pop!(needed, :optimizer)
        for new_optimizer in optimizers_1d
            for stuff in _get_stuffs(setdiff(needed, Set((:optimizer,))))
                x = (; stuff..., optimizer=new_optimizer)
                @info "optimizer" needed x
                @yield x
            end
        end
        return
    end
    @info "at end"
    x = NamedTuple()
    @info "got" x
    @yield x
    return
end

@resumable function get_stuffs(needed)
    @info "proper get_stuffs" needed
    add_dummy_est = !(:est in needed)
    for stuff in _get_stuffs(needed)
        if add_dummy_est
            stuff = (; stuff..., est = DummyAbilityEstimator(0.0))
        end
        @yield stuff
    end
end

end
