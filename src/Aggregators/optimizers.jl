struct FunctionOptimizer{OptimizerT <: Optimizer} <: AbilityOptimizer
    optim::OptimizerT
end

function (optim::FunctionOptimizer)(f::F,
        lh_function) where {F}
    comp_f = let f = f, lh_function = lh_function
        x -> f(x) * lh_function(x)
    end
    optim.optim(comp_f)
end

function show(io::IO, ::MIME"text/plain", optim::FunctionOptimizer)
    indent_io = indent(io, 2)
    if optim.optim isa Optimizers.OneDimOptimOptimizer || optim.optim isa Optimizers.MultiDimOptimOptimizer || optim.optim isa Optimizers.NativeOneDimOptimOptimizer
        inner = optim.optim
        println(io, "Optimizer:")
        if optim.optim isa Optimizers.NativeOneDimOptimOptimizer
            name = typeof(inner.method).name.name
        else
            name = typeof(inner.optim).name.name
        end
        println(indent_io, "Method: ", name)
        println(indent_io, "Lo: ", inner.lo)
        println(indent_io, "Hi: ", inner.hi)
    end
end

#=
"""
Argmax + max over the ability likihood given a set of responses with a given
coefficient using exhaustive search.

TODO: Add item bank trait for enumerable item banks.
"""
struct EnumerationOptimizer{DomainT} <: AbilityOptimizer
    lo::DomainT
    hi::DomainT
end

function (optim::EnumerationOptimizer)(f::F,
        ability_likelihood::AbilityLikelihood;
        lo = optim.lo,
        hi = optim.hi) where {F}
    cur_argmax::Ref{Float64} = Ref(NaN)
    cur_max::Ref{Float64} = Ref(-Inf)
    cb_abil_given_resps(ability_likelihood.responses,
        ability_likelihood.item_bank;
        lo = lo,
        hi = hi) do (x, prob)
        # @inline
        fprob = f(x) * prob
        if fprob >= cur_max[]
            cur_argmax[] = x
            cur_max[] = fprob
        end
    end
    (cur_argmax[], cur_max[])
end
=#

function (optim::AbilityOptimizer)(f::F,
        est,
        tracked_responses::TrackedResponses;
        kwargs...) where {F}
    #optim(maybe_apply_prior(f, est), AbilityLikelihood(tracked_responses); kwargs...)
    optim(f, pdf(est, tracked_responses); kwargs...)
end
