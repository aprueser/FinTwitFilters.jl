stockList = Dict{String, FinTwitFilters.Stock}()

## Using the MarketLists package, get all symbols from the NASDAQ, NYSE, and AMEX exchanges that have a marketCap > marketCapFilter
## This defaults to SmallCap and above.
function getExchangeUniverse(;marketCapFilter::Int64 = minMarketCapFilter)
    ## Reset StockList
    empty!(stockList)

    ## Get all NASDAQ Stocks
    nq    = getExchangeMembers("NASDAQ");
    nq_df = parseExchangeResponseToDataFrame(nq, "NASDAQ");

    @threads for row in 1:size(nq_df)[1]
        if !isnothing(nq_df[row, :marketCap]) && nq_df[row, :marketCap] > marketCapFilter
            stockList[nq_df[row, :symbol]] = FinTwitFilters.Stock(ticker = nq_df[row, :symbol], company = nq_df[row, :name], exchange = "NASDAQ", 
                                                                  marketCap = isnothing(nq_df[row, :marketCap]) ? 0.0 : nq_df[row, :marketCap], 
                                                                  sector = nq_df[row, :sector], industry = nq_df[row, :industry], country = nq_df[row, :country])
        end
    end

    nyse    = getExchangeMembers("NYSE");
    nyse_df = parseExchangeResponseToDataFrame(nyse, "NYSE");

    @threads for row in 1:size(nyse_df)[1]
        if !isnothing(nyse_df[row, :marketCap]) && nyse_df[row, :marketCap] > marketCapFilter
            stockList[nyse_df[row, :symbol]] = FinTwitFilters.Stock(ticker = nyse_df[row, :symbol], company = nyse_df[row, :name], exchange = "NYSE",  
                                                                    marketCap = isnothing(nyse_df[row, :marketCap]) ? 0.0 : nyse_df[row, :marketCap], 
                                                                    sector = nyse_df[row, :sector], industry = nyse_df[row, :industry], country = nyse_df[row, :country])
        end
    end

    amex    = getExchangeMembers("AMEX");
    amex_df = parseExchangeResponseToDataFrame(amex, "AMEX");

    @threads for row in 1:size(amex_df)[1]
        if !isnothing(amex_df[row, :marketCap]) && amex_df[row, :marketCap] > marketCapFilter
            stockList[amex_df[row, :symbol]] = FinTwitFilters.Stock(ticker = amex_df[row, :symbol], company = amex_df[row, :name], exchange = "AMEX", 
                                                                    marketCap = isnothing(amex_df[row, :marketCap]) ? 0.0 : amex_df[row, :marketCap], 
                                                                    sector = amex_df[row, :sector], industry = amex_df[row, :industry], country = amex_df[row, :country])
        end
    end
end


function fetchSymbolData(custKey::String; sampleData::Bool = false, sampleSize::Int64 = 25)

    apiKey = TDAmeritradeAPI.apiKeys(custKey, "", now(), "", now(), now() - Minute(30), "unauthorized");

    if sampleData == true
        dat = Dict{String, Stock}(rand(FinTwitFilters.stockList, sampleSize))
    else
        dat = stockList
    end
    
    for s in keys(dat)
        hist_raw = TDAmeritradeAPI.api_getPriceHistoryRaw(s, apiKey, periodType = "year", numPeriods = 10, frequencyType = "daily", frequency = 1);
        hist     = TDAmeritradeAPI.parseRawPriceHistoryToTemporalTS(hist_raw, s);

        ## Add Simple Moving Averages
        addSMA!(hist, :Volume, 50, :VolSMA50)
        addSMA!(hist, :Close, 200, :CloseSMA200)
        addSMA!(hist, :Close, 150, :CloseSMA150)
        addSMA!(hist, :Close,  50, :CloseSMA50)
        addSMA!(hist, :Close,  20, :CloseSMA20)
        addSMA!(hist, :Close,  10, :CloseSMA10)

        ## Add Exponetial Moving Averages
        addEMA!(hist, :Close,  5, :CloseEMA5)
        addEMA!(hist, :Close,  8, :CloseEMA8)
        addEMA!(hist, :Close,  13, :CloseEMA13)
        addEMA!(hist, :Close,  21, :CloseEMA21)
        addEMA!(hist, :Close,  34, :CloseEMA34)
        addEMA!(hist, :Close,  55, :CloseEMA55)
        addEMA!(hist, :Close,  89, :CloseEMA89)

        ## Add rates of Change
        addROC!(hist, :Volume,  1, :VolumePctChangeDay)
        addROC!(hist, :Close,  1, :ClosePctChangeDay)
        addROC!(hist, :Close,  tradingDaysInWeek, :ClosePctChangeWeek)
        addROC!(hist, :Close,  tradingDaysInMonth, :ClosePctChangeMonth)
        addROC!(hist, :Close,  tradingDaysInQtr, :ClosePctChangeQtr)
        addROC!(hist, :Close,  tradingDaysInYear, :ClosePctChangeYear)

        stockList[s].ohlc = hist
    end

end