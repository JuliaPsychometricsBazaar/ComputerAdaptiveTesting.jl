import Base.Broadcast

function moneypatch_broadcast()
    if "CAT_DISABLE_HACKS" in keys(ENV)
        return
    end
    for m in [
        methods(Base.Broadcast._broadcast_getindex_evalf)...,
        methods(Base.Broadcast._broadcast_getindex)...,
        methods(Base.Broadcast.materialize)...,
        methods(Base.Broadcast.materialize!)...,
        methods(Base.Broadcast.copy)...,
        methods(Base.Broadcast.copyto!)...,
        methods(Base.getindex)...
    ]
        m.recursion_relation = function(method1, method2, parent_sig, new_sig)
            return true
        end
    end
end

function __init__()
    moneypatch_broadcast()
end
