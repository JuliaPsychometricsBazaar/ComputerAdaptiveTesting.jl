@precompile_setup begin
    const response_types = (BooleanResponse(), MultinomialResponse())
    const domains = (OneDimContinuousDomain(), VectorContinuousDomain())
    const item_banks = Dict(
        (OneDimContinuousDomain(), BooleanResponse()) => [],
        (OneDimContinuousDomain(), MultinomialResponse()) => [],
        (VectorContinuousDomain(), BooleanResponse()) => [],
        (VectorContinuousDomain(), MultinomialResponse()) => []
    )

    #struct BareResponses{ResponseTypeT <: ResponseType, ConcreteResponseTypeT, IndicesVecT <: AbstractVector}
    @precompile_all_calls begin
        for response_type in response_types
            concrete_type = concrete_response_type(response)
            single_response = Response(response_type, 1, zero(concrete_type))
            bare_responses = BareResponses(response_type, [1], [zero(concrete_type)])
        end
        Response{ResponseTypeT <: ResponseType, ConcreteResponseTypeT}
    end
end
