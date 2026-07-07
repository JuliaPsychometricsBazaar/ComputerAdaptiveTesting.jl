import Base.Broadcast

# Ability likelihoods/estimators are built by composing many small closures
# (see IntegralCoeffs, FunctionProduct, etc.), giving deeply nested broadcast
# and getindex call chains. Julia's type inference uses `recursion_relation`
# on method signatures to detect (and stop inlining/specializing) genuine
# recursion, but for these chains it produces false positives, so inference
# bails out early and the resulting code allocates heavily instead of fusing
# into an allocation-free broadcast. `moneypatch_broadcast` works around this
# by patching `recursion_relation` on the relevant Base.Broadcast/getindex/copy
# methods to always return `true`, so these (non-recursive) call chains are
# always fully specialized. Set `CAT_DISABLE_HACKS` in the environment to
# disable this patch (e.g. to check whether it's still needed).
function moneypatch_broadcast()
    if "CAT_DISABLE_HACKS" in keys(ENV)
        return
    end
    for m in [
        methods(Base.Broadcast._broadcast_getindex_evalf)...,
        methods(Base.Broadcast._broadcast_getindex)...,
        methods(Base.Broadcast.materialize)...,
        methods(Base.Broadcast.materialize!)...,
        methods(Base.copy)...,
        methods(Base.copyto!)...,
        methods(Base.getindex)...
    ]
        m.recursion_relation = function (method1, method2, parent_sig, new_sig)
            return true
        end
    end
end

function __init__()
    moneypatch_broadcast()
end
