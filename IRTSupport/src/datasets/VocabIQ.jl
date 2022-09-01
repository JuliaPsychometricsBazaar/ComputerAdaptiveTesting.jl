module VocabIQ

using IRTSupport
using ..Utils
using ...Wrap.Mirt
using Serialization
using DataFrames
using CSV
using ZipFile
using UrlDownload
using Conda
using RCall
using Base.Filesystem

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
    get_single_csv_zip("http://openpsychometrics.org/_rawdata/VIQT_data.zip")
end

function get_marked_df(answers)
    viqt = get_viqt()
    viqt = select(viqt, r"^Q")
    for col in names(viqt)
        viqt[!, col] = Int.(viqt[!, col] .== answers[col])
    end
    viqt
end

get_marked_df_cached = file_cache("viqt/marked.csv", get_marked_df, x -> CSV.read(x, DataFrame), CSV.write)

answers, potential_answers, gold_answers = parse_coding()

function get_item_bank()
    fit_4pl(get_marked_df_cached(answers); TOL=1e-2)
end

get_item_bank_cached = file_cache("viqt/item_bank_4pl.jls", get_item_bank, Serialization.deserialize, Serialization.serialize)

function get_item_bank_3pl()
    fit_3pl(get_marked_df_cached(answers); TOL=1e-2)
end

function prompt_response(response_idx)
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

export get_viqt, get_marked_df, get_marked_df_cached, get_item_bank, get_item_bank_cached,
    get_item_bank_3pl, answers, potential_answers, gold_answers, prompt_response

end
