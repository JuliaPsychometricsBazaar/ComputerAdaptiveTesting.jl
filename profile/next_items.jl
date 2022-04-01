using ComputerAdaptiveTesting.DummyData: dummy_3pl, std_normal
using ComputerAdaptiveTesting.ItemBanks: iter_item_idxs
using ComputerAdaptiveTesting.Responses
using ComputerAdaptiveTesting.Aggregators
using ComputerAdaptiveTesting.NextItemRules
import Profile
import PProf
using Distributions: Normal
using ArgParse
using StatProfilerHTML

const ability_estimator = PriorAbilityEstimator(Normal())

function profile_objective(run_profile::RunProfile, objective::Objective) where {RunProfile, Objective}
    (item_bank, question_labels_, abilities_, responses) = dummy_3pl(;num_questions=100, num_testees=1)
    function run()
        responses = TrackedResponses(
            BareResponses(),
            item_bank,
            NullAbilityTracker(),
            ability_estimator
        )
        criterion_state = init_thread(objective, responses)
        for item_idx in iter_item_idxs(item_bank)
            objective(criterion_state, responses, item_idx)
        end
    end
    @info "init run"
    run()
    @info "benchmark run"
    run_profile(run)
end

if isdefined(Profile, :Allocs)
    function run_pprof_allocs(run::F) where {F}
        Profile.Allocs.@profile run()
        prof = Profile.Allocs.fetch()
        PProf.Allocs.pprof(prof)
    end
end

function get_cmdline()
    if Sys.iswindows()
        String.(split(unsafe_string(ccall(:GetCommandLineA, Cstring, ())), " "))
    elseif Sys.isapple()
        String.(split(strip(read(`/bin/ps -p $(getpid()) -o command=`, String)), " "))
    elseif Sys.isunix()
        String.(split(read(joinpath("/", "proc", string(getpid()), "cmdline"), String), "\x00"; keepempty=false))
    else
        j_cmd = String.(split(Base.julia_cmd(), " "))
        args_joined = join(ARGS, " ")
        [j_cmd..., PROGRAM_FILE, args_joined...]
    end
end

function run_track_allocs(run_bench::F) where {F}
    Profile.clear_malloc_data() 
    run_bench()
end

function run_profile(run::F) where {F}
    Profile.@profile run()
    prof = Profile.fetch()
    PProf.pprof(prof)
end

function run_time(run::F) where {F}
    @time run()
end

function run_statprofilerhtml(run::F) where {F}
    @profilehtml run()
end

PROFILERS = Dict(
    "pprof_allocs" => run_pprof_allocs,
    "track_allocs" => run_track_allocs,
    "profile" => run_profile,
    "time" => run_time,
    "profilehtml" => run_statprofilerhtml
)

function objective(next_item_rule::ItemStrategyNextItemRule)
    next_item_rule.criterion
end

function main()
    settings = ArgParseSettings()
    @add_arg_table settings begin
        "profiling_mode"
            help = "The profiling mode to use. Can be 'pprof_allocs', 'track_allocs', 'profile', or 'time'."
            required = true
        "next_item_rule"
            help = "The next item rule to use"
            required = true
    end
    args = parse_args(settings)
    next_item_rule = NEXT_ITEM_ALIASES[args["next_item_rule"]](ability_estimator)
    if args["profiling_mode"] == "track_allocs" && !haskey(ENV, "TRACK_ALLOCS")
        cmdline = get_cmdline()
        insert!(cmdline, findfirst(x -> endswith(x, ".jl"), cmdline), "--track-allocation=all")
        cmd = Cmd(Cmd(cmdline), env=("TRACK_ALLOCS" => "TRUE",))
        @info "Running subprocess to track allocs" cmd
        Base.run(cmd)
        return
    end
    profile_objective(PROFILERS[args["profiling_mode"]], objective(next_item_rule))
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end