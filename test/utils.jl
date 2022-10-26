module CATTestUtils

export @namedtestset, set_test_args

using Test: @testset

global test_args::Vector{String} = copy(ARGS)
global should_run_set::Union{Set{Tuple{String}}, Nothing} = nothing
global macro_named_testset_stack::Vector{String} = []
global runtime_named_testset_stack::Vector{String} = []
global known_testsets_names::Vector{Tuple{String}} = []

function is_prefix(needle, haystack)
    if length(needle) > length(haystack)
        return false
    end
    haystack[1:length(needle)] == needle
end

function match_names(cb, prefix...)
    prefix_len = length(prefix)
    for testset_name in known_testsets_names
        if length(testset_name) < prefix_len 
            continue
        end
        if testset_name[1:prefix_len] == prefix
            cb(testset_name)
        end
    end
end

function parse_args()
    start_universe = false
    included = []
    excluded = []
    if length(test_args) == 0
        start_universe = true
    end
    for arg in test_args
        if arg == "+all"
            start_universe = true
        end
        if startswith(arg, "-")
            push!(excluded, tuple(split(arg[2:end], "/")...))
        else
            push!(included, tuple(split(arg, "/")...))
        end
    end
    start_universe, included, excluded
end

function should_run(should_run_name)
    # XXX/TODO: This will not really work as desired for the nested case since
    # any excluded testset will not run so its children cannot be run
    name = Tuple(should_run_name)
    start_universe, included, excluded = parse_args()
    max_prefix_length(spec) = maximum(length, filter(needle -> is_prefix(needle, name), spec); init=0)
    max_included_length = max_prefix_length(included)
    max_excluded_length = max_prefix_length(excluded)
    if max_included_length > max_excluded_length
        return true
    elseif max_included_length < max_excluded_length
        return false
    else
        return start_universe
    end
end

function with_testset_name(inner, name)
    push!(macro_named_testset_stack, name)
    push!(known_testsets_names, tuple(macro_named_testset_stack...))
    ret = nothing
    try
        ret = inner()
    finally
        pop!(macro_named_testset_stack)
    end
    ret
end

macro namedtestset(name, args...)
    # XXX/TODO: This seems to have problems with `using` statements, unless the
    # tests are put inside
    name_str = String(name)
    with_testset_name(name_str) do
        quote
            push!($runtime_named_testset_stack, $(esc(name_str)))
            ret = nothing
            run = should_run($runtime_named_testset_stack)
            if run
                ret = @testset$(args...)
            end
            pop!($runtime_named_testset_stack)
            ret
        end
    end
end

function set_test_args(new_test_args)
    global test_args
    test_args = new_test_args
end

end
