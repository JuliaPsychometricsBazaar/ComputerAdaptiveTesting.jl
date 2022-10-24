module MGKT

import JSON

using ..Utils
using ...Wrap.Mirt
using Serialization
using DataFrames
using CSV

codebook_json = """
{
'Q1' : {'Q': 1, 'text': 'Who of these were famous poets?', 'A1': 'Robert Frost', 'A0': 'Emily Dickinson', 'A3': 'Maya Angelou', 'A2': 'Sylvia Plath', 'A5': 'Elizabeth Cady Stanton', 'A4': 'Langston Hughes', 'A7': 'Marcel Cordoba', 'A6': 'Abigail Adams', 'A9': 'Trent Moseson', 'A8': 'Sun Tzu'},
'Q2' : {'Q': 2, 'text': 'Which of these are Broadway musicals?', 'A1': 'The Lion King', 'A0': 'Cats', 'A3': 'Wicked', 'A2': 'Hamilton', 'A5': 'Casablanca', 'A4': 'Kinky Boots', 'A7': 'Blue Swede Shoes', 'A6': 'The Tin Man', 'A9': 'Amandine', 'A8': 'Common Projects'},
'Q3' : {'Q': 3, 'text': 'Which of these are religious holidays?', 'A1': 'Christmas', 'A0': 'Kwanzaa', 'A3': 'Yom Kippur', 'A2': 'Ramadan', 'A5': 'Mirch Masala', 'A4': 'Hanukkah', 'A7': 'Amadar', 'A6': 'Reconciliation', 'A9': 'Viveza', 'A8': 'Durest'},
'Q4' : {'Q': 4, 'text': 'Which of these are brands of makeup?', 'A1': 'Sephora', 'A0': 'CoverGirl', 'A3': 'Dior', 'A2': 'Maybelline', 'A5': 'ThriftyGal', 'A4': 'Shiseido', 'A7': 'Reis', 'A6': 'Allenda', 'A9': 'Aejeong', 'A8': 'NewBeautyTruth'},
'Q5' : {'Q': 5, 'text': 'Which of these drugs are painkillers?', 'A1': 'Ibuprofen', 'A0': 'Oxycodone', 'A3': 'Morphine', 'A2': 'Codeine', 'A5': 'Modafinil', 'A4': 'Asprin', 'A7': 'Alemtuzumab', 'A6': 'Creatine', 'A9': 'Carboplatin', 'A8': 'Semtex'},
'Q6' : {'Q': 6, 'text': 'Which of these diseases are sexually transmitted?', 'A1': 'Herpes', 'A0': 'AIDS', 'A3': 'Human Papillomavirus', 'A2': 'Chlamydia', 'A5': 'Botulism', 'A4': 'Trichomoniasis', 'A7': 'Pneumonia', 'A6': 'Shingles', 'A9': 'Pertusis', 'A8': 'Tuberculosis'},
'Q7' : {'Q': 7, 'text': 'Which of these are brands of cigarettes?', 'A1': 'Marlboro', 'A0': 'Camel', 'A3': 'Pall Mall Box', 'A2': 'Newport', 'A5': 'Seagram&#x27;s', 'A4': 'Pyramid', 'A7': 'Windsor', 'A6': 'Black Velvet', 'A9': 'Solo', 'A8': 'Black Turkey'},
'Q8' : {'Q': 8, 'text': 'Which of these are slang terms for marijuana?', 'A1': '420', 'A0': 'weed', 'A3': 'chronic', 'A2': 'ganja', 'A5': 'smack', 'A4': 'reefer', 'A7': 'DnB', 'A6': 'tilt', 'A9': 'heavenly green', 'A8': 'Jos&#xE9; Garcia'},
'Q9' : {'Q': 9, 'text': 'Which of these were ever colonies of France?', 'A1': 'Ivory Coast', 'A0': 'Senegal', 'A3': 'Morocco', 'A2': 'Quebec', 'A5': 'India', 'A4': 'Vietnam', 'A7': 'Brazil', 'A6': 'Florida', 'A9': 'Egypt', 'A8': 'South Africa'},
'Q10' : {'Q': 10, 'text': 'Which of these countries still have a monarchy (may only be ceremonial)?', 'A1': 'Japan', 'A0': 'United Kingdom', 'A3': 'Thailand', 'A2': 'Sweden', 'A5': 'France', 'A4': 'Saudi Arabia', 'A7': 'Russia', 'A6': 'Germany', 'A9': 'Brazil', 'A8': 'China'},
'Q11' : {'Q': 11, 'text': 'Which of these countries produce a lot of oil?', 'A1': 'Venezuela', 'A0': 'Saudi Arabia', 'A3': 'Norway', 'A2': 'Nigeria', 'A5': ' Zimbabwe', 'A4': 'Quatar', 'A7': 'Singapore', 'A6': ' Sweden', 'A9': 'Japan', 'A8': 'Panama'}, 'Q12' : {'Q': 12, 'text': 'Which of these countries possess nuclear weapons?', 'A1': 'France', 'A0': 'Russia', 'A3': 'China', 'A2': 'Israel', 'A5': 'Germany', 'A4': 'Pakistan', 'A7': 'Nigeria', 'A6': 'Saudi Arabia', 'A9': 'Spain', 'A8': 'Mexico'},'Q13' : {'Q': 13, 'text': 'Which of these file types are video?', 'A1': '.mkv', 'A0': '.mp4', 'A3': '.wmv', 'A2': '.avi', 'A5': '.csv', 'A4': '.mov', 'A7': '.flac', 'A6': '.xls', 'A9': '.mp3', 'A8': '.msi'},
'Q14' : {'Q': 14, 'text': 'Which of these are web browsers?', 'A1': 'Firefox', 'A0': 'Internet Explorer', 'A3': 'Opera', 'A2': 'Safari', 'A5': 'Slate', 'A4': 'Chrome', 'A7': 'Pipes', 'A6': 'Expedition', 'A9': 'Telegram', 'A8': 'Adele'},
'Q15' : {'Q': 15, 'text': 'Which of these are versions of the Linux operating system?', 'A1': 'Debian', 'A0': 'Ubuntu', 'A3': 'RHEL', 'A2': 'Fedora', 'A5': 'IIS', 'A4': 'Slackware', 'A7': 'Technitium', 'A6': 'Kodiak', 'A9': 'Go', 'A8': 'Oracle'},
'Q16' : {'Q': 16, 'text': 'Which of these are HTTP status codes?', 'A1': '500 Internal Server Error', 'A0': '100 Continue', 'A3': '404 Not Found', 'A2': '301 Moved Permanently', 'A5': '500 Deleted', 'A4': '502 Bad Gateway', 'A7': '303 Payment Processing', 'A6': '600 Encrypted', 'A9': '101 Use Proxy', 'A8': '209 Download Complete'},
'Q17' : {'Q': 17, 'text': 'Which of these are garments (pieces of clothing)?', 'A1': 'Tunic', 'A0': 'Shirt', 'A3': 'Shawl', 'A2': 'Sarong', 'A5': 'Jayanti', 'A4': 'Camisole', 'A7': 'Cornik', 'A6': 'Wristlings', 'A9': 'Frutiger', 'A8': 'Cheapnik'},
'Q18' : {'Q': 18, 'text': 'Which of these are craftsman&rsquo;s tools?', 'A1': 'Chisel', 'A0': 'Saw', 'A3': 'Caliper', 'A2': 'Bevel', 'A5': 'Skree', 'A4': 'Awl', 'A7': 'Whisket', 'A6': 'Wry', 'A9': 'Brutch', 'A8': 'Skane'},
'Q19' : {'Q': 19, 'text': 'Which of these are red wines?', 'A1': 'Cabernet sauvignon', 'A0': 'Merlot', 'A3': 'Sangiovese', 'A2': 'Malbec', 'A5': 'Chardonnay', 'A4': 'Pinot noir', 'A7': 'Moscato', 'A6': 'Semillon', 'A9': 'Riesling', 'A8': 'Gew&uuml;rztraminer'},
'Q20' : {'Q': 20, 'text': 'Which of these are card games?', 'A1': 'Hearts', 'A0': 'Rummy', 'A3': 'Bridge', 'A2': 'Poker', 'A5': 'Yatzhe ', 'A4': 'Cribbidge', 'A7': 'Bocce', 'A6': 'Croquet', 'A9': 'Manhattan', 'A8': 'Black 2s'},
'Q21' : {'Q': 21, 'text': 'Which of these are electronic components that might be found in an electrical circut?', 'A1': 'Inductor', 'A0': 'Resistor', 'A3': 'Transistor', 'A2': 'Capacitor', 'A5': 'Signer', 'A4': 'Diode', 'A7': 'Annulus', 'A6': 'Subductor', 'A9': 'Zenoid', 'A8': 'Boson'},
'Q22' : {'Q': 22, 'text': 'Which of these are cryptocurrencies?', 'A1': 'Litecoin', 'A0': 'Bitcoin', 'A3': 'Monero', 'A2': 'Etherium', 'A5': 'AlphaBay', 'A4': 'Ripple', 'A7': 'PayPal', 'A6': 'DCA', 'A9': 'Dwork', 'A8': 'Liberty Ledger'},
'Q23' : {'Q': 23, 'text': 'Which of these countries contain many ancient pyramids?', 'A1': 'Egypt', 'A0': 'Mexico', 'A3': 'Sudan', 'A2': 'India', 'A5': 'Greece', 'A4': 'Indonesia', 'A7': 'Congo', 'A6': 'Turkey', 'A9': 'Japan', 'A8': 'Mongolia'},
'Q24' : {'Q': 24, 'text': 'Who of these are famous criminals?', 'A1': 'Ted Kaczynski', 'A0': 'Al Capone', 'A3': 'Timothy McVeigh', 'A2': 'Pablo Escobar', 'A5': 'Harvey Parnell', 'A4': 'Jim Jones', 'A7': 'John Goodman', 'A6': 'Sid McMath', 'A9': 'Pavel Tikhonov', 'A8': 'Buster Keaton'},
'Q25' : {'Q': 25, 'text': 'Which of these books have more than 1,000 pages?', 'A1': 'Les Miserables', 'A0': 'Infinite Jest', 'A3': 'War and Peace', 'A2': 'Atlas Shrugged', 'A5': 'Pride and Prejudice', 'A4': 'Cryptonomicon', 'A7': 'Fahrenheit 451', 'A6': 'Harry Potter and the Prisoner of Azkaban', 'A9': 'Science, and its Antecedents', 'A8': 'To Kill a Mockingbird'},
'Q26' : {'Q': 26, 'text': 'Which of these are units of distance?', 'A1': 'Meter', 'A0': 'Mile', 'A3': 'Parsec', 'A2': 'Furlong', 'A5': 'Newton', 'A4': 'Angstrom', 'A7': 'Pitch', 'A6': 'Pascal', 'A9': 'Annum', 'A8': 'Hertz'},
'Q27' : {'Q': 27, 'text': 'Which of these are exercise programs?', 'A1': 'Zumba', 'A0': 'CrossFit', 'A3': 'Pilates', 'A2': 'Barre', 'A5': 'Shiatsu', 'A4': 'Tabata', 'A7': 'Gooba', 'A6': 'Reflexology', 'A9': 'NTP', 'A8': 'UltraMaxFit'},
'Q28' : {'Q': 28, 'text': 'Which of these are internet abbreviations?', 'A1': 'ROFL', 'A0': 'LOL', 'A3': 'GG', 'A2': 'BRB', 'A5': 'QTY', 'A4': 'DM', 'A7': 'AET', 'A6': 'FUM', 'A9': 'MRLO', 'A8': 'TT'},
'Q29' : {'Q': 29, 'text': 'Which of these words have similar meaning to the word &ldquo;fancy&rdquo;?', 'A1': 'adorned', 'A0': 'ornate', 'A3': 'resplendent', 'A2': 'cushy', 'A5': 'effective', 'A4': 'spiffy', 'A7': 'esulent', 'A6': 'virile', 'A9': 'thalassic', 'A8': 'adscititious'},
'Q30' : {'Q': 30, 'text': 'Which of these are types of computer cables?', 'A1': 'USB', 'A0': 'HDMI', 'A3': 'SATA', 'A2': 'Ethernet', 'A5': 'WiFi', 'A4': 'FireWire', 'A7': '2Interlink', 'A6': 'D-High', 'A9': 'HDD', 'A8': 'RTC'},
'Q31' : {'Q': 31, 'text': 'Which of these are types of cancer?', 'A1': 'Lymphoma', 'A0': 'Lukemia', 'A3': 'Mesothelioma', 'A2': 'Melanoma', 'A5': 'Lymnoma', 'A4': 'Sarcoma', 'A7': 'Vitisus', 'A6': 'Colerectia', 'A9': 'Cellenia', 'A8': 'Tradoma'},
'Q32' : {'Q': 32, 'text': 'Which  of these are fabric patterns?', 'A1': 'Paisley', 'A0': 'Calico', 'A3': 'Plaid', 'A2': 'Pinstripe', 'A5': 'Periwinkle', 'A4': 'Tartan', 'A7': 'Stilted', 'A6': 'Snapdragon', 'A9': 'Tahoma', 'A8': 'Arvo'}
}
"""

struct Question
    text::String
    correct::Vector{String}
    incorrect::Vector{String}
end

function answers(question)
    return shuffle(question.correct + question.incorrect)
end

function process_codebook()
    codebook = JSON.parse(replace(codebook_json, "'" => "\""))
    results = []
    for q_idx in 1:32
        d = codebook["Q" + string(q_idx )]
        correct = []
        incorrect = []
        for a_idx in 0:9
            a = d["A" + string(a_idx)]
            if a_idx <= 4
                push!(correct, a)
            else
                push!(incorrect, a)
            end
        end
        push!(results, Question(text=d["text"], correct=correct, incorrect=incorrect))
    end
end

function get_mgkt()
    get_single_csv_zip("http://openpsychometrics.org/_rawdata/MGKT_data.zip")
end

function get_summary_df()
    mgkt = get_mgkt()
    mgkt = select(mgkt, r"Q[0-9]+S")
    for col in names(mgkt)
        vals = Int.(mgkt[!, col])
        vals[vals .< 0] .= 0
        mgkt[!, col] = vals
    end
    mgkt
end

get_summary_df_cached = file_cache("mgkt/summary.csv", get_summary_df, x -> CSV.read(x, DataFrame), CSV.write)

function get_item_bank()
    fit_gpcm(get_summary_df_cached(); TOL=1e-2)
end

get_item_bank_cached = file_cache("mgkt/item_bank_gpcm.jls", get_item_bank, Serialization.deserialize, Serialization.serialize)

function prompt_response(response_idx)
    codebook["Q" + string(response_idx)]
end

end