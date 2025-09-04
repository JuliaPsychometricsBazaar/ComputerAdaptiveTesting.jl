module ConfigBase

using Accessors: PropertyLens, opcompose
using DocStringExtensions: TYPEDEF

export CatConfigBase, walk

"""
$(TYPEDEF)
"""
abstract type CatConfigBase end

show(io::IO, ::MIME"text/plain", obj::CatConfigBase) = power_summary(io, obj)

function walk(f, x::CatConfigBase, lens = identity)
    f(x, lens)
    for fieldname in fieldnames(typeof(x))
        walk(f, getfield(x, fieldname), opcompose(lens, PropertyLens{fieldname}()))
    end
end

function walk(f, x, lens = identity)
    f(x, lens)
end

end
