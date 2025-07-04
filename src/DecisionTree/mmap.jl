function save_mmap(io::IOStream, arr::Array)
    write(io, length(arr))
    write(io, arr)
end

function save_mmap(path::String, name, arr::Array)
    open(path * "/" * name * ".mmap", "w+") do io
        save_mmap(io, arr)
    end
end

function save_mmap(path::String, dt::DefaultMaterializedDecisionTree)
    mkpath(path)
    save_mmap(path, "questions", dt.questions)
    save_mmap(path, "ability_estimates", dt.ability_estimates)
end

function load_mmap(::Type{C}, io::IOStream) where {T, C <: AbstractVector{T}}
    l = read(io, Int)
    mmap(io, Vector{T}, (l,))
end

function load_mmap(t::Type, path::String, name)
    open(path * "/" * name * ".mmap") do io
        load_mmap(t, io)
    end
end

function load_mmap(path::String)
    MaterializedDecisionTree(questions = load_mmap(Vector{UInt32}, path, "questions"),
        ability_estimates = load_mmap(Vector{Float64}, path, "ability_estimates"))
end
