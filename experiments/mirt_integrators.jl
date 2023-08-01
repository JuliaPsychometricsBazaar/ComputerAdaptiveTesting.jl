using StatsBase: rle
import Random
import JSON3
import Measurements
using UUIDs: uuid4
using Base64: base64encode
using Base.Threads: nthreads
using Base.Filesystem: mkpath
using ComputerAdaptiveTesting.Aggregators: TrackedResponses, NullAbilityTracker, PriorAbilityEstimator, MeanAbilityEstimator
using FittedItemBanks.DummyData: dummy_full, std_mv_normal, SimpleItemBankSpec, StdModel4PL, VectorContinuousDomain, BooleanResponse
using ComputerAdaptiveTesting.Responses: BareResponses
using PsychometricsBazaarBase.Integrators
using FittedItemBanks

const total_num_questions = 50
const total_num_item_banks = 3
const total_num_respondents = 3
const trials_per_config = 3
const spec = SimpleItemBankSpec(StdModel4PL(), VectorContinuousDomain(), BooleanResponse())

function build_cat_states(rng, dims, num_item_banks, num_respondents)
    #abilities = randn(dims, num_respondents)
    num_questions_answered = round.(Int, clamp.(50.0 .+ 30.0 .* randn(num_respondents), 0.0, float(total_num_questions)))
    question_answered_idxs = Matrix{Int}(undef, (total_num_questions, num_respondents))
    for respi in 1:num_respondents
        question_answered_idxs[:, respi] = Random.randperm(total_num_questions)
    end
    all_responses::Dict{Int, Array{TrackedResponses}} = Dict()
    for dim in dims
        all_responses[dim] = Array{TrackedResponses}(undef, (num_item_banks, num_respondents))
        for item_bank_i in 1:num_item_banks
            (item_bank, abilities_, actual_responses) = dummy_full(
                rng,
                spec,
                dim;
                num_questions=total_num_questions,
                num_testees=total_num_respondents
            )
            for respondent_i in 1:num_respondents
                question_idxs = question_answered_idxs[1:num_questions_answered[respondent_i], respondent_i]

                response_values = actual_responses[question_idxs]
                all_responses[dim][item_bank_i, respondent_i] = TrackedResponses(
                    BareResponses(ResponseType(item_bank), question_idxs, response_values),
                    item_bank,
                    NullAbilityTracker()
                )
            end
        end
    end
    all_responses
end

function uniq(x)
    rle(x)[1]
end

const all_dims = 1:10

function build_cubish!(integrator, tab)
    function hcub(dim, rtol)
        push!(tab, Dict(
            :integrator => integrator,
            :dim => dim,
            :rtol => rtol
        ))
    end
    for rtol in exp10.(range(-1, stop=-4, length=7))
        for dim in (1, 2)
            hcub(dim, rtol)
        end
    end
    for rtol in exp10.(range(-1, stop=-3, length=5))
        hcub(3, rtol)
    end
    for rtol in exp10.(range(-1, stop=-2, length=3))
        hcub(4, rtol)
    end
    hcub(5, 0.1)
end

function build_cub!(tab)
    build_cubish!(:CubatureIntegrator, tab)
end

function build_hcub!(tab)
    build_cubish!(:HCubatureIntegrator, tab)
end

function build_mdfgk!(tab)
    function mdfgk(dim, order)
        push!(tab, Dict(
            :integrator => :MultiDimFixedGKIntegrator,
            :dim => dim,
            :order => order
        ))
    end
    for dim in (1, 2, 3)
        for order in Int.(round.(exp10.(range(0, 2, length=9))))
            mdfgk(dim, order)
        end
    end
    for dim in (4, 5)
        for order in Int.(round.(exp10.(range(0, 1, length=5))))
            mdfgk(dim, order)
        end
    end
end

function build_cuba!(tab)
    function cuba(integrator, dim, rtol)
        push!(tab, Dict(
            :integrator => Dict(
                :Vegas => :CubaVegasIntegrator,
                :Suave => :CubaSuaveIntegrator,
                :Divonne => :CubaDivonneIntegrator,
                :Cuhre => :CubaCuhreIntegrator,
            )[integrator],
            :dim => dim,
            :rtol => rtol
        ))
    end
    function cuba_all(integrator, startdim)
        for rtol in exp10.(range(-1, stop=-4, length=7))
            for dim in startdim:2
                cuba(integrator, dim, rtol)
            end
        end
        for rtol in exp10.(range(-1, stop=-3, length=5))
            cuba(integrator, 3, rtol)
        end
        for rtol in exp10.(range(-1, stop=-2, length=3))
            cuba(integrator, 4, rtol)
        end
        cuba(integrator, 4, 0.1)
    end
    cuba_all(:Vegas, 1)
    cuba_all(:Suave, 2)
    cuba_all(:Divonne, 2)
    cuba_all(:Cuhre, 2)
end

function build_combtab()
    tab = []
    #=
    for dim in 1:7
        for order in orders
            push!(tab, Dict(
                :integrator => :MultiDimFixedGKIntegrator,
                :dim => dim,
                :order => order
            ))
        end
    end
    =#
    #build_cub!(tab)
    #build_hcub!(tab)
    #build_mdfgk!(tab)
    build_cuba!(tab)
    tab
end

function tuplify(strukt)
  ntuple(i -> getfield(strukt, i), fieldcount(typeof(strukt))) 
end

function run_and_save(config, run_func)
    open(ARGS[1] * "/" * string(uuid4()) * ".jsonl", "w") do f
        for trial in 1:trials_per_config
            Random.seed!(42)
            result = copy(config)
            result[:trial] = trial
            timing = @timed run_func()
            val = timing[:value]
            result[:value] = Measurements.value.(val)
            result[:err] = Measurements.uncertainty.(val)
            result[:gcstats] = tuplify(timing[:gcstats])
            for fieldname in keys(timing)
                if fieldname in (:value, :gcstats)
                    continue
                end
                result[fieldname] = timing[fieldname]
            end
            @info "result" result
            JSON3.write(f, result)
            write(f, b"\n")
        end
    end
end

function mk_ability_estimator(integrator_constructor, config, args...; kwargs...)
    dim = config[:dim]
    lo = repeat([-6.0], dim)
    hi = repeat([6.0], dim)
    integrator = integrator_constructor(lo, hi, args...; kwargs...)
    MeanAbilityEstimator(PriorAbilityEstimator(std_mv_normal(dim)), integrator)
end

AnyCubaIntegrator = Union{Val{:CubaVegasIntegrator}, Val{:CubaSuaveIntegrator}, Val{:CubaDivonneIntegrator}, Val{:CubaCuhreIntegrator}}

function run_integrator(integrator::Type{<: Integrator}, responses::TrackedResponses, config, args...; kwargs...)
    ability_estimator = mk_ability_estimator(integrator, config, args...; kwargs...) 
    run_and_save(config, () -> ability_estimator(IntMeasurement(), responses))
end

function run_integrator(responses::TrackedResponses, config, args...; kwargs...)
    run_integrator(eval(config[:integrator]), responses, config, args...; kwargs...)
end

function run_one(::AnyCubaIntegrator, responses, config)
    algorithm = Dict(
        :CubaVegasIntegrator => CubaVegas,
        :CubaSuaveIntegrator => CubaSuave,
        :CubaDivonneIntegrator => CubaDivonne,
        :CubaCuhreIntegrator => CubaCuhre,
    )[config[:integrator]]()
    run_integrator(CubaIntegrator, responses, config, algorithm; rtol=config[:rtol])
end

function run_one(::Union{Val{:CubatureIntegrator}, Val{:HCubatureIntegrator}}, responses, config)
    run_integrator(responses, config, rtol=config[:rtol])
end

function run_one(::Val{:MultiDimFixedGKIntegrator}, responses, config)
    run_integrator(responses, config, config[:order])
end

function main()
    mkpath(ARGS[1])
    combtab = build_combtab()
    configs = []
    for comb in combtab
        for item_bank_i in 1:total_num_item_banks
            for response_i in 1:total_num_respondents
                config = deepcopy(comb)
                config[:item_bank] = item_bank_i
                config[:response] = response_i
                push!(configs, config)
            end
        end
    end
    rng = Random.Xoshiro()
    Random.seed!(rng, 42)
    Random.shuffle!(configs)
    chan = Channel(Inf)
    for config in configs
        #@info "put config" config
        put!(chan, config)
    end
    for _ in 1:nthreads()
        #@info "put done"
        put!(chan, :done)
    end
    @info "spawning threads"
    Threads.@threads :static for thread_id in 1:nthreads()
        println("Hello!")
        @info "started thread" thread_id
        rng = Random.Xoshiro()
        Random.seed!(rng, 42)
        all_responses = build_cat_states(rng, all_dims, total_num_item_banks, total_num_respondents)
        while true
            # Deepcopy just to try and put things in thread local memory
            config = deepcopy(take!(chan))
            @info "executing config" config
            if config == :done
                break
            end
            responses = all_responses[config[:dim]][config[:item_bank], config[:response]]
            run_one(Val(config[:integrator]), responses, config)
        end
        @info "finished thread" thread_id
    end
end


main()