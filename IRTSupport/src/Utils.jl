module Utils

export env_cache

function env_cache(varname, get_fn, read_fn, write_fn)
    function inner(args...; kwargs...)
        if varname in keys(ENV) && isfile(ENV[varname])
            @info "Using cached $varname"
            return read_fn(ENV[varname])
        end
        ret = get_fn(args..., kwargs...)
        if varname in keys(ENV)
            write_fn(ENV[varname], ret)
        end
        return ret
    end
    inner
end

end