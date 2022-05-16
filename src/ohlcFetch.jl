global stockList = Dict{String, FinTwitFilters.Stock}()

function getExchangeUniverse(;marketCapFilter = 300000000)
    ## Get all NASDAQ Stocks
    nq    = getExchangeMembers("NASDAQ");
    nq_df = parseExchangeResponseToDataFrame(nq, "NASDAQ");

    for row in 1:size(nq_df)[1]
        if nq_df[row, :marketCap] > marketCapFilter
            stockList[nq_df[row, :symbol]] = FinTwitFilters.Stock(ticker = nq_df[row, :symbol], company = nq_df[row, :name], marketCap = isnothing(nq_df[row, :marketCap]) ? 0.0 : nq_df[row, :marketCap], 
                                                                  sector = nq_df[row, :sector], industry = nq_df[row, :industry], country = nq_df[row, :country])
        end
    end

    nyse    = getExchangeMembers("NYSE");
    nyse_df = parseExchangeResponseToDataFrame(nyse, "NYSE");

    for row in 1:size(nyse_df)[1]
        if nyse_df[row, :marketCap] > marketCapFilter
            stockList[nyse_df[row, :symbol]] = FinTwitFilters.Stock(ticker = nyse_df[row, :symbol], company = nyse_df[row, :name], marketCap = isnothing(nyse_df[row, :marketCap]) ? 0.0 : nyse_df[row, :marketCap], 
                                                                    sector = nyse_df[row, :sector], industry = nyse_df[row, :industry], country = nyse_df[row, :country])
        end
    end

    amex    = getExchangeMembers("AMEX");
    amex_df = parseExchangeResponseToDataFrame(amex, "AMEX");

    for row in 1:size(amex_df)[1]
        if nyse_df[row, :marketCap] > marketCapFilter
            stockList[amex_df[row, :symbol]] = FinTwitFilters.Stock(ticker = amex_df[row, :symbol], company = amex_df[row, :name], marketCap = isnothing(amex_df[row, :marketCap]) ? 0.0 : amex_df[row, :marketCap], 
                                                                    sector = amex_df[row, :sector], industry = amex_df[row, :industry], country = amex_df[row, :country])
        end
    end

end