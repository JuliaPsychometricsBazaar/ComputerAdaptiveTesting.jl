module Utils

using Base.Filesystem: joinpath, isfile

export file_cache

const IRT_DATASET_CACHE_VAR = "IRT_DATASETS_CACHE"

function get_single_csv_zip(url)
    @info "Downloading" url
    zip_file = urldownload(
        url;
        compress = :zip,
        multifiles = true
    )
    file = nothing
    for f in zip_file
        if f isa CSV.File
            file = f
            break
        end
    end
    DataFrame(file)
end


function file_cache(path, get_fn, read_fn, write_fn)
    function inner(args...; kwargs...)
        full_path = nothing
        if IRT_DATASET_CACHE_VAR in keys(ENV)
            full_path = joinpath(ENV[varname], path)
            if isfile(full_path)
                @info "Using cached $full_path"
                return read_fn(full_path)
            end
        end
        ret = get_fn(args..., kwargs...)
        if full_path !== nothing
            mkpath(dirname(full_path))
            write_fn(full_path, ret)
        end
        return ret
    end
    inner
end

end