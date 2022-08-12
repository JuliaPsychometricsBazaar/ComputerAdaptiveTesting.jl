#md # How abilities converge on simulated 3PL data

# # Running a CAT based based on real reponse data
#
# This example shows how to run a CAT end-to-end on real data.
#
# First a 1-dimensional IRT model is fitted based on open response data to the
# vocabulary IQ test with the `mirt` R package. Next, the model is used to
# administer the test interactively.

ENV["R_HOME"] = "*"

answers_txt = """
Q1 	24 	tiny faded new large big 
Q2 	3 	shovel spade needle oak club 
Q3 	10 	walk rob juggle steal discover 
Q4 	5 	finish embellish cap squeak talk 
Q5 	9 	recall flex efface remember divest 
Q6 	9 	implore fancy recant beg answer 
Q7 	17 	deal claim plea recoup sale 
Q8 	10 	mindful negligent neurotic lax delectable 
Q9 	17 	quash evade enumerate assist defeat 
Q10 	10 	entrapment partner fool companion mirror 
Q11 	5 	junk squeeze trash punch crack 
Q12 	17 	trivial crude presidential flow minor 
Q13 	9 	prattle siren couch chatter good 
Q14 	5 	above slow over pierce what 
Q15 	18 	assail designate arcane capitulate specify 
Q16 	18 	succeed drop squeal spit fall 
Q17 	3 	fly soar drink peer hop 
Q18 	12 	disburse perplex muster convene feign 
Q19 	18 	cistern crimp bastion leeway pleat 
Q20 	18 	solder beguile distant reveal seduce 
Q21 	3 	dowager matron spank fiend sire 
Q22 	18 	worldly solo inverted drunk alone 
Q23 	6 	protracted standard normal florid unbalanced 
Q24 	12 	admissible barbaric lackluster drab spiffy 
Q25 	17 	related intrinsic alien steadfast pertinent 
Q26 	10 	facile annoying clicker obnoxious counter 
Q27 	10 	capricious incipient galling nascent chromatic 
Q28 	9 	noted subsidiary culinary illustrious begrudge 
Q29 	9 	breach harmony vehement rupture acquiesce 
Q30 	3 	influence power cauterize bizarre regular 
Q31 	6 	silence rage anger victory love 
Q32 	10 	sector mean light harsh predator 
Q33 	17 	house carnival yeast economy domicile 
Q34 	3 	depression despondency forswear hysteria integrity 
Q35 	17 	memorandum catalogue bourgeois trigger note 
Q36 	24 	fulminant doohickey ligature epistle letter 
Q37 	17 	titanic equestrian niggardly promiscuous gargantuan 
Q38 	5 	stanchion strumpet pole pale forstall 
Q39 	5 	yearn reject hanker despair indolence 
Q40 	24 	introduce terminate shatter bifurcate fork 
Q41 	5 	omen opulence harbinger mystic demand 
Q42 	5 	hightail report abscond perturb surmise 
Q43 	12 	fugacious vapid fractious querulous extemporaneous 
Q44 	10 	cardinal pilot full trial inkling 
Q45 	9 	fixed rotund stagnant permanent shifty 
"""

using Serialization
using DataFrames
using CSV
using UrlDownload
using Conda
using RCall
using Base.Filesystem
using ComputerAdaptiveTesting
using ComputerAdaptiveTesting.DummyData: std_normal
using ComputerAdaptiveTesting.ExtraDistributions
using ComputerAdaptiveTesting.Sim
using ComputerAdaptiveTesting.NextItemRules
using ComputerAdaptiveTesting.TerminationConditions
using ComputerAdaptiveTesting.Aggregators
using ComputerAdaptiveTesting.ItemBanks
using ComputerAdaptiveTesting.Integrators
using ComputerAdaptiveTesting.Optimizers
import ComputerAdaptiveTesting.IntegralCoeffs

function parse_coding()
    lines = split(strip(answers_txt), "\n")
    ans_dict = Dict()
    potential_answers = Array{String}(undef, (length(lines), 5)) 
    gold_answers = Array{String}(undef, (length(lines), 2)) 
    for (idx, line) in enumerate(lines)
        l = split(line)
        true_answer = parse(Int, l[2])
        bv = BitVector(undef, 5)
        bv.chunks[1] = true_answer
        words = l[3:end]
        true_answer 
        ans_dict[l[1]] = true_answer 
        potential_answers[idx, :] = words
        gold_answers[idx, :] = words[bv]
    end
    ans_dict, potential_answers, gold_answers 
end

function get_viqt()
    @info "Downloading VIQT"
    viqt = urldownload(
        "http://openpsychometrics.org/_rawdata/VIQT_data.zip";
        compress = :zip,
        multifiles = true
    )
    file = nothing
    for f in viqt
        if f isa CSV.File
            file = f
            break
        end
    end
    DataFrame(file)
end

function get_marked_df(answers)
    viqt = get_viqt()
    viqt = select(viqt, r"^Q")
    for col in names(viqt)
        viqt[!, col] = Int.(viqt[!, col] .== answers[col])
    end
    viqt
end

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

get_marked_df_cached = env_cache("VIQT_PATH", get_marked_df, x -> CSV.read(x, DataFrame), CSV.write)
#=
function get_marked_df_cached(answers)
    if "VIQT_PATH" in keys(ENV) && isfile(ENV["VIQT_PATH"])
        @info "Using cached VIQT"
        return CSV.read(ENV["VIQT_PATH"], DataFrame)
    end
    df = get_marked_df(answers)
    if "VIQT_PATH" in keys(ENV)
        CSV.write(ENV["VIQT_PATH"], df)
    end
    return df
end
=#

function fit_mirt(df)
    @info "Fitting IRT model"
    Conda.add("r-mirt"; channel="conda-forge")
    params = R"""
    library(mirt)
    irt_model = mirt($df, model=1, itemtype='4PL', TOL=1e-2)
    do.call(rbind, head(coef(irt_model), -1))
    """
    params
end

answers, potential_answers, gold_answers = parse_coding()

function get_item_bank(answers)
    params = fit_mirt(get_marked_df_cached(answers))
    arr = copy(RCall.unsafe_array(params))
    display("text/plain", arr)
    println()
    ItemBank4PL(arr[:, 2], arr[:, 1], arr[:, 3], 1.0 .- arr[:, 4])
end

get_item_bank_cached = env_cache("ITEM_BANK_PATH", get_item_bank, Serialization.deserialize, Serialization.serialize)

function run_vocab_iq_cat()
    item_bank = get_item_bank_cached(answers)
    integrator = FixedGKIntegrator(-6, 6, 61)
    ability_integrator = AbilityIntegrator(integrator)
    dist_ability_est = PriorAbilityEstimator(std_normal)
    optimizer = AbilityOptimizer(OneDimOptimOptimizer(-6.0, 6.0, NelderMead()))
    ability_estimator = ModeAbilityEstimator(dist_ability_est, optimizer)
    @info "run_cat" ability_estimator 
    rules = CatRules(
        ability_estimator,
        AbilityVarianceStateCriterion(dist_ability_est, ability_integrator),
        FixedItemsTerminationCondition(45)
    )
    function get_response(response_idx, response_name)
        params = item_params(item_bank, response_idx)
        println("Parameters for next question: $params")
        options = potential_answers[response_idx, :]
        options_fmt = join(options, "/")

        function get_word(idx)
            while true
                print("Which two of $options_fmt have the same meaning $idx/2 (blank = do not know) > ")
                word = readline()
                if strip(word) == ""
                    return nothing
                end
                if word in options
                    return word
                end
                println("Could not find $word in $options_fmt")
            end
        end
        word1 = get_word(1)
        word2 = get_word(2)
        if word1 === nothing || word2 === nothing
            return 0
        end
        return Set([word1, word2]) == Set(gold_answers[response_idx, :]) ? 1 : 0
    end
    function new_response_callback(tracked_responses, terminating)
        if tracked_responses.responses.values[end] > 0
            println("Correct")
        else
            println("Wrong")
        end
        ability = ability_estimator(tracked_responses)
        var = variance_given_mean(ability_integrator, dist_ability_est, tracked_responses, ability)
        println("Got ability estimate: $ability ± $var")
        println("")
    end
    loop_config = CatLoopConfig(
        rules=rules,
        get_response=get_response,
        new_response_callback=new_response_callback
    )
    run_cat(loop_config, item_bank)
end

run_vocab_iq_cat()
