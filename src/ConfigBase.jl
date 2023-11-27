module ConfigBase

using Accessors
using DocStringExtensions

export CatConfigBase, walk

"""
$(TYPEDEF)
"""
abstract type CatConfigBase end

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
