function preallocate(obj)
    obj
end

function preallocate(obj::Integrator)
    Integrators.preallocate(obj)
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

function preallocate_impl(obj)
    recursives = []
    for fieldname in fieldnames(obj)
        push!(recursives, :($fieldname = preallocate(obj.$fieldname)))
    end
    return :($(constructorof(obj))($(recursives...)))
end
