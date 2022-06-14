## Using the MarketLists package, get all symbols from the NASDAQ, NYSE, and AMEX exchanges.
## Filter the data for symbols that have a dollarVolume > dollarVolumeFilter, closingPrice > priceFilter, and are not Chinese companies.
function getExchangeUniverse(;dollarVolumeFilter::Int64 = minDollarVolFilter, priceFilter::Int64 = minPriceFilter)
    ## Reset StockList
    empty!(stockList)

    println("Getting Universe of Stocks from the 3 Exchanges.  Filtering list where dollarVolume > ", dollarVolumeFilter, " and closingPrice > \$", priceFilter )

    ## Get all NASDAQ Stocks
    nq             = getExchangeMembers("NASDAQ");
    nq_df          = parseExchangeResponseToDataFrame(nq, "NASDAQ");
    nq_df_filtered = @rsubset nq_df (:lastsale * :volume) > dollarVolumeFilter && :lastsale > priceFilter && :country != "China" && occursin(r"^[A-Z0-9]*$", :symbol);

    @threads for row in 1:size(nq_df_filtered)[1]
        stockList[nq_df_filtered[row, :symbol]] = FinTwitFilters.Stock(ticker = nq_df_filtered[row, :symbol], company = nq_df_filtered[row, :name], exchange = "NASDAQ", 
                                                                       marketCap = isnothing(nq_df_filtered[row, :marketCap]) ? 0.0 : nq_df_filtered[row, :marketCap], 
                                                                       sector = nq_df_filtered[row, :sector], industry = nq_df_filtered[row, :industry], country = nq_df_filtered[row, :country])
    end

    nyse             = getExchangeMembers("NYSE");
    nyse_df          = parseExchangeResponseToDataFrame(nyse, "NYSE");
    nyse_df_filtered = @rsubset nyse_df (:lastsale * :volume) > dollarVolumeFilter && :lastsale > priceFilter && :country != "China" && occursin(r"^[A-Z0-9]*$", :symbol);

    @threads for row in 1:size(nyse_df_filtered)[1]
        stockList[nyse_df_filtered[row, :symbol]] = FinTwitFilters.Stock(ticker = nyse_df_filtered[row, :symbol], company = nyse_df_filtered[row, :name], exchange = "NYSE",  
                                                                         marketCap = isnothing(nyse_df_filtered[row, :marketCap]) ? 0.0 : nyse_df_filtered[row, :marketCap], 
                                                                         sector = nyse_df_filtered[row, :sector], industry = nyse_df_filtered[row, :industry], country = nyse_df_filtered[row, :country])
    end

    amex             = getExchangeMembers("AMEX");
    amex_df          = parseExchangeResponseToDataFrame(amex, "AMEX");
    amex_df_filtered = @rsubset amex_df (:lastsale * :volume) > dollarVolumeFilter && :lastsale > priceFilter && :country != "China" && occursin(r"^[A-Z0-9]*$", :symbol);

    @threads for row in 1:size(amex_df_filtered)[1]
        stockList[amex_df_filtered[row, :symbol]] = FinTwitFilters.Stock(ticker = amex_df_filtered[row, :symbol], company = amex_df_filtered[row, :name], exchange = "AMEX", 
                                                                         marketCap = isnothing(amex_df_filtered[row, :marketCap]) ? 0.0 : amex_df_filtered[row, :marketCap], 
                                                                         sector = amex_df_filtered[row, :sector], industry = amex_df_filtered[row, :industry], country = amex_df_filtered[row, :country])
    end
end

## Define the Actor behavior for the PriceHistory API fetch Actor
function actorFetchPriceHistory(ticker, apiKey)
    ##println("Fetching ", ticker, " on thread ", threadid());
    ohlc = TDAmeritradeAPI.api_getPriceHistoryRaw(ticker, apiKey, periodType = "year", numPeriods = 10, frequencyType = "daily", frequency = 1);

    if ohlc[:code] == 200
        stockList[ticker].ohlc = ohlc
        stockList[ticker].status = "OHLC_RAW";

        send(whereis(:parse), ticker);
    else
        println("api_getPriceHistoryRaw for ", ticker, " returned HTTP Status: ", ohlc[:code])
        stockList[ticker].status = "OHLC_FAILED";   
    end

    loadingStatus["fetch"] = loadingStatus["fetch"] - 1
end

function actorFetchFundamental(ticker, apiKey)
	fun = TDAmeritradeAPI.api_searchInstrumentsRaw(ticker, "fundamental", apiKey)

	if fun[:code] == 200
        	stockList[ticker].fundamentals = fun

		send(whereis(:parseFun), ticker)
	end
end

## Define the Actor behavior for parsing the OHLCV JSON data
function actorParsePriceHistory(ticker) 
    ##println("Parsing OHLC data for ", ticker.ticker, " on ", threadid());
    if stockList[ticker].ohlc[:body] isa String && length(stockList[ticker].ohlc[:body]) > 10
        stockList[ticker].ohlc = TDAmeritradeAPI.parseRawPriceHistoryToTemporalTS(stockList[ticker].ohlc, ticker);
        stockList[ticker].status = "OHLC_PARSED";

        if stockList[ticker].ohlc isa Temporal.TS
            send(whereis(:collect), ticker);
        else 
            println("parseRawPriceHistoryToTemporalTS for ", ticker, " returned: ", stockList[ticker].ohlc);   
            stockList[ticker].status = "OHLC_PARSE_FAILED";   
    
            loadingStatus["collect"] = loadingStatus["collect"] - 1
            loadingStatus["augment"] = loadingStatus["augment"] - 1
        end
    else
        println("api_getPriceHistoryRaw for ", ticker, " returned", stockList[ticker].ohlc);   
        stockList[ticker].status = "OHLC_PARSE_FAILED"; 

        loadingStatus["collect"] = loadingStatus["collect"] - 1
        loadingStatus["augment"] = loadingStatus["augment"] - 1
    end

    loadingStatus["parse"] = loadingStatus["parse"] - 1
end

function actorParseFundamental(ticker)
	if stockList[ticker].fundamentals[:body] isa String && length(stockList[ticker].fundamentals[:body]) > 10
		stockList[ticker].fundamentals = TDAmeritradeAPI.parseRawInstrumentToDataFrame(stockList[ticker].fundamentals, "fundamental");
	end
end

## Define the Actor behavior for collecting the daily OHLCV data into weekly, monthly, quarterly, and yearly OHLCVs
function actorCollectPriceHistory(ticker)
    firstCandle = getFirstCandleDate(stockList[ticker].ohlc)

    if round(Dates.now() - firstCandle, Day).value > (2 * tradingDaysInWeek)
        stockList[ticker].wkohlc  = toWeeklyOHLC(stockList[ticker].ohlc);
    end
    
    if round(Dates.now() - firstCandle, Day).value > (tradingDaysInWeek + tradingDaysInMonth)
        stockList[ticker].mthohlc = toMonthlyOHLC(stockList[ticker].ohlc);
    end
    
    if round(Dates.now() - firstCandle, Day).value > (tradingDaysInMonth + tradingDaysInQtr)
        stockList[ticker].qtrohlc = toQuarterlyOHLC(stockList[ticker].ohlc);
    end
    
    if round(Dates.now() - firstCandle, Day).value > (tradingDaysInQtr + tradingDaysInYear)
        stockList[ticker].yrohlc  = toYearlyOHLC(stockList[ticker].ohlc);
    end

    stockList[ticker].status = "OHLC_COLLAPSED"
    loadingStatus["collect"] = loadingStatus["collect"] - 1

    send(whereis(:augment), ticker);
end

## Define the Actor behavior for augmenting the OHLCV data with FinTwit favorite Indicators
function actorAugmentPriceHistory(ticker)
    ## Add Candle Type
    addCandleType!(stockList[ticker].ohlc);

    ## Add Wick Play Identifiers
    addWickPlayFlag!(stockList[ticker].ohlc);

    ## Add Closing range
    stockList[ticker].ohlc[:closingRange] = (stockList[ticker].ohlc[:Close] .- stockList[ticker].ohlc[:Low]) ./ (stockList[ticker].ohlc[:High] .- stockList[ticker].ohlc[:Low])

    ## Add Simple Moving Averages
    addSMA!(stockList[ticker].ohlc, :Volume, 50, :VolSMA50);
    addSMA!(stockList[ticker].ohlc, :Close, 200, :CloseSMA200);
    addSMA!(stockList[ticker].ohlc, :Close, 150, :CloseSMA150);
    addSMA!(stockList[ticker].ohlc, :Close,  50, :CloseSMA50);
    addSMA!(stockList[ticker].ohlc, :Close,  20, :CloseSMA20);
    addSMA!(stockList[ticker].ohlc, :Close,  10, :CloseSMA10);

    ## Add Exponetial Moving Averages
    addEMA!(stockList[ticker].ohlc, :Close,  5, :CloseEMA5);
    addEMA!(stockList[ticker].ohlc, :Close,  8, :CloseEMA8);
    addEMA!(stockList[ticker].ohlc, :Close,  13, :CloseEMA13);
    addEMA!(stockList[ticker].ohlc, :Close,  21, :CloseEMA21);
    addEMA!(stockList[ticker].ohlc, :Close,  34, :CloseEMA34);
    addEMA!(stockList[ticker].ohlc, :Close,  55, :CloseEMA55);
    addEMA!(stockList[ticker].ohlc, :Close,  89, :CloseEMA89);

    ## Add rates of Change
    addROC!(stockList[ticker].ohlc, :Volume,  1, :VolumePctChangeDay);
    addROC!(stockList[ticker].ohlc, :Close,  1, :ClosePctChangeDay);
    addROC!(stockList[ticker].ohlc, :Low,  1, :LowPctChangeDay);
    addROC!(stockList[ticker].ohlc, :High,  1, :HighPctChangeDay);
    addROC!(stockList[ticker].ohlc, :Close,  FinTwitFilters.tradingDaysInWeek, :ClosePctChangeWeek);
    addROC!(stockList[ticker].ohlc, :Close,  FinTwitFilters.tradingDaysInQtr, :ClosePctChangeQtr);
    addROC!(stockList[ticker].ohlc, :Close,  FinTwitFilters.tradingDaysInYear, :ClosePctChangeYear);

    ## Add GapUp and GapDown flags
    addGaps!(stockList[ticker].ohlc, 200, 10);

    stockList[ticker].status = "OHLC_AUGMENTED"
    loadingStatus["augment"] = loadingStatus["augment"] - 1

    if (Sys.free_memory() / Sys.total_memory() < 0.2)
        GC.gc()
    end
end

## Prepare the symbol data
## 1. Fetch Daily Candle data for all symbols in stockList
## 2. Parse the returned JSON
## 3. Enrich the timeseries data 
##
## Do all of this with Actors passing off the work to eachother on independant threads
function fetchSymbolData(apiKey::apiKeys; sampleData::Bool = false, sampleSize::Int64 = 25)

    if sampleData == true
        dat = Dict{String, Stock}(rand(stockList, sampleSize))

        for s in values(dat)
            s.status = "SAMPLED"
        end
    else
        dat = stockList
    end

    println("Total Symbols: ", length(dat))
    loadingStatus["fetch"] = loadingStatus["parse"] = loadingStatus["collect"] = loadingStatus["augment"] = length(dat)

    ## Spawn the Actors
    fetcher   = spawn(actorFetchPriceHistory, thrd = 2)
    parser    = spawn(actorParsePriceHistory, thrd = 3)
    parseFun  = spawn(actorParseFundamental, thrd = 3)
    collector = spawn(actorCollectPriceHistory, thrd = 4)
    augmenter = spawn(actorAugmentPriceHistory, thrd = 3)

    register(:fetch, fetcher)
    register(:parse, parser)
    register(:parseFun, parseFun)
    register(:collect, collector)
    register(:augment, augmenter)
    
    for s in keys(dat)
        send(whereis(:fetch), s, apiKey);
    end

end
