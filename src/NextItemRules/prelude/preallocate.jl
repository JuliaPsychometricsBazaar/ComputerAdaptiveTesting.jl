preallocate(obj) = obj
preallocate(obj::Integrator) = PsychometricsBazaarBase.preallocate(obj)
preallocate(obj::Optimizer) = PsychometricsBazaarBase.preallocate(obj)
# Log-grid reductions have no numerical scratch buffers. Preserve the shared
# tracker when preallocating an entire configuration tree.
preallocate(obj::Union{LogGridIntegrator, LogGridAbilityTracker}) = obj

# A generated function can only call helpers defined before it (Julia 1.12).
function preallocate_impl(obj)
    recursives = []
    for fieldname in fieldnames(obj)
        push!(recursives, :($fieldname = preallocate(obj.$fieldname)))
    end
    # Reconstruct with the type's wrapper instead of `ConstructionBase.constructorof`:
    # in ConstructionBase < 1.6 the latter is itself a generated function, and
    # calling it from this generator resolves the type's binding in the world
    # where `preallocate` was defined. Julia 1.12 rejects that for types defined
    # later (e.g. test-local configs), so go straight to the wrapper.
    return :($(Base.typename(obj).wrapper)($(recursives...)))
end

@generated function preallocate(obj::CatConfigBase)
    # TODO: Ideally when the same object is referenced multiple times in the
    #       object graph, it should only be preallocated once.
    #
    #       Here's how that would look if it didn't have to be a generated
    #       function:
    #=
    function preallocate(obj)
        preallocatables = IdDict()
        walk(obj) do item, lens
            if isa(item, Integrator)
                if !haskey(preallocatables, item)
                    preallocatables[item] = []
                end
                push!(preallocatables[item], lens)
            end
        end
        for (preallocatable, lenses) in preallocatables
            preallocated = Integrators.preallocate(preallocatable)
            for lens in lenses
                obj = set(obj, lens, preallocated)
            end
        end
        return obj
    end
    =#

    # TODO: It might also be nice to avoid reconstructing bits of the object graph
    #       which are not affected by the preallocation.
    return preallocate_impl(obj)
end
