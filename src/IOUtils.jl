module IOUtils

# TODO: Possibly remove this module

function get_word_list_idxs(word_list, labels)
    word_set = Set(word_list)
    idxs = []
    sizehint!(idxs, length(word_list))
    for (idx, word) in enumerate(labels)
        if !(word in word_set)
            continue
        end
        push!(idxs, idx)
        delete!(word_set, word)
    end
    if length(word_set) > 0
        @warn "Could not find these words in IRF: " * join(word_set, ", ")
    end
    idxs
end

function prepare_responses(item_bank, response_data)
    responses_df = DataFrame(read_parquet(response_data))
    item_bank = subset_item_bank(item_bank, responses_df[!, :word])
    responses_df[!, :knows] = responses_df[!, :score] .>= 5
    (item_bank, responses_df)
end

function get_response(df, idx, word)
    knows = df[df[!, :word] .== word, :knows][1]
    Response(idx, knows)
end

function get_full_responses(item_bank, df)
    responses = Response[]
    sizehint!(responses, length(item_bank.labels))
    for (idx, word) in enumerate(item_bank.labels)
        knows = df[df[!, :word] .== word, :knows][1]
        push!(responses, Response(idx, knows))
    end
    responses
end

end