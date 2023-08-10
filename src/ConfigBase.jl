module ConfigBase

using Accessors

export CatConfigBase, walk

abstract type CatConfigBase end

function walk(f, x::CatConfigBase, lens=identity)
    @info "Walking" x lens
    f(x, lens)
    for fieldname in fieldnames(typeof(x))
        walk(f, getfield(x, fieldname), opcompose(lens, PropertyLens{fieldname}()))
    end
end

function walk(f, x, lens=identity)
    @info "Walking term" x lens
    f(x, lens)
end

end